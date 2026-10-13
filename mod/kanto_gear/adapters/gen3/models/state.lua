return function(Gen3, clear, copy)
  local function sameEntries(source, snapshot)
    if type(source) ~= "table" then return snapshot == nil end
    -- Virtual flag tables can change without any raw entries changing.
    if not snapshot or getmetatable(source) then return false end
    local count = 0
    for key, value in pairs(source) do
      if snapshot.values[key] ~= value then return false end
      count = count + 1
    end
    return count == snapshot.count
  end
  local function snapshotEntries(source)
    if type(source) ~= "table" then return nil end
    local snapshot = { values = {}, count = 0 }
    for key, value in pairs(source) do
      snapshot.values[key], snapshot.count = value, snapshot.count + 1
    end
    return snapshot
  end
  local function refreshInventory(self)
    local items, cached = self.Items, self.inventorySource
    local unchanged = cached and cached.normalize == items.toNumericId
    local pockets = self.session.bag and self.session.bag.pockets or {}
    local count = 0
    for _, pocket in ipairs(items.POCKET_ORDER) do
      for _, slot in ipairs(pockets[pocket] or {}) do
        count = count + 1
        local old = cached and cached[count]
        if not old or old.rawId ~= slot.id or old.qty ~= slot.qty then
          unchanged = false
        -- Named IDs can be remapped in place by another mod. Numeric native
        -- stacks need no repeated string parsing while their reader is unchanged.
        elseif type(slot.id) ~= "number" and items.toNumericId(slot.id) ~= old.id then
          unchanged = false
        end
      end
    end
    if unchanged and count == #cached then return end

    local save = self.save
    clear(save.inventory)
    clear(save.bagOrder)
    cached = { normalize = items.toNumericId }
    -- Native pockets are authoritative. Bag.listPocket sanitizes on read;
    -- stacks contains duplicate numeric/string aliases and must not be summed.
    for _, pocket in ipairs(items.POCKET_ORDER) do
      for _, slot in ipairs(pockets[pocket] or {}) do
        local id, qty = items.toNumericId(slot.id), tonumber(slot.qty) or 0
        cached[#cached + 1] = { rawId = slot.id, qty = slot.qty, id = id }
        if id and qty > 0 then
          local previous = rawget(save.inventory, id)
          if previous == nil then save.bagOrder[#save.bagOrder + 1] = id end
          save.inventory[id] = (previous or 0) + qty
        end
      end
    end
    self.inventorySource = cached
  end
  function Gen3:refresh()
    local session = self.game.session
    if session ~= self.session then
      self.session = session
      self.dexSource = nil
      self.inventorySource = nil
      self.mons = setmetatable({}, { __mode = "k" })
      self.save = session and { generation = 3, player = {}, party = {},
        inventory = {}, bagOrder = {}, pokedex = { seen = {}, caught = {} } } or nil
      if self.save then
        setmetatable(self.save.inventory, { __index = function(t, id)
          local num = self.Items.toNumericId(id)
          return num and rawget(t, num)
        end })
      end
    end
    if not session then return nil end
    local save, player = self.save, self.save.player
    save.version, save.money = session.version, session.money
    save.playTime = copy(session.playtime or session.playTime)
    player.name, player.id = session.name, session.trainerId
    player.money, player.map = session.money, session.map
    player.x, player.y, player.facing = session.x, session.y, session.facing
    for slot = 1, math.max(#save.party, #(session.party or {})) do
      save.party[slot] = self:mon((session.party or {})[slot])
    end
    refreshInventory(self)
    local dex = session.dex or {}
    local dexChanged = save.pokedex.national ~= (dex.national == true)
    local cached = self.dexSource
    -- Compare contents, not table identities: native captures and other mods
    -- update flags in place. Keep the native readers authoritative on change.
    if not cached or cached.dex ~= dex or cached.species ~= self.data.pokemon
        or cached.isSeen ~= self.Dex.isSeen or cached.isCaught ~= self.Dex.isCaught
        or getmetatable(dex) or not sameEntries(dex.seen, cached.seen)
        or not sameEntries(dex.caught, cached.caught) or not sameEntries(dex.owned, cached.owned) then
      for id in pairs(self.data.pokemon) do
        local seen, caught = self.Dex.isSeen(dex, id) or nil, self.Dex.isCaught(dex, id) or nil
        dexChanged = dexChanged or seen ~= save.pokedex.seen[id] or caught ~= save.pokedex.caught[id]
        save.pokedex.seen[id], save.pokedex.caught[id] = seen, caught
      end
      self.dexSource = { dex = dex, species = self.data.pokemon,
        isSeen = self.Dex.isSeen, isCaught = self.Dex.isCaught,
        seen = snapshotEntries(dex.seen), caught = snapshotEntries(dex.caught), owned = snapshotEntries(dex.owned) }
    end
    if dexChanged then self.dexRevision = (self.dexRevision or 0) + 1 end
    save.pokedex.national = dex.national == true
    save.pokedex.limit = save.pokedex.national and self.Dex.NATIONAL_MAX or (self.Dex.regionalMax
      and self.Dex.regionalMax(self.profile.id) or self.Dex.KANTO_MAX)
    return save
  end
  -- Storage allocates an opaque identity on the serialized save. Call this
  -- after binding mod.storage so a subsequent native save retains that identity.
  -- Host path [Gen 3]: native Schema.newGame bypasses the legacy fresh-save marker; assign storage identity before another slot can be adopted.
  function Gen3:newPlaythrough(session)
    if not session then return end
    session.meta = session.meta or {}
    if not session.meta.playthroughId then
      -- Schema.newGame does not pass through SaveData's legacy fresh-save marker.
      -- A new native run must not adopt the previous slot's tool-storage identity.
      session.meta.playthroughId = require("src.core.SaveData").newPlaythroughId()
    end
  end
  function Gen3:syncStorageIdentity()
    local session, snapshot = self.game.session, self.game.save
    if session and snapshot and snapshot.meta and not session.meta then
      session.meta = snapshot.meta
    end
  end
  -- Storage is sparse. Return explicit native slot numbers with each occupied
  -- entry, so UI ordering never becomes a different withdrawal destination.
  function Gen3:boxes()
    local result = {}
    for index, box in ipairs(self.session and self.session.storage and self.session.storage.boxes or {}) do
      local row = { name = box.name, index = index, capacity = 30, entries = {} }
      for slot = 1, 30 do
        local mon = box.mons and box.mons[slot]
        if mon then row.entries[#row.entries + 1] = { slot = slot, mon = self:mon(mon) } end
      end
      result[index] = row
    end
    return result
  end
  function Gen3:flagStore()
    if self.Space.active and self.Runtime.getSession() == self.session then
      return self.Space.getStore() or self.session
    end
    return self.session
  end
  function Gen3:dexNumber(species)
    local def = self.data.pokemon[species]
    return def and (self.save and self.save.pokedex.national and def.dex or def.regionalDex)
  end
  function Gen3:badge(index)
    local badge = self.flagDefinitions.BADGES[index]
    return self.session ~= nil and badge ~= nil
      and self.Flags.getFlag(self:flagStore(), nil, badge.flag) == true
  end
end
