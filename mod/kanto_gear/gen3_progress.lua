-- Native FR/LG route objectives. Read the imported event graph, never execute
-- scripts or infer victory/collection from an NPC simply being hidden.
local M = {}
M.__index = M

local function copy(t)
  local out = {}
  for k, v in pairs(t or {}) do out[k] = v end
  return out
end

local function sortedKeys(t)
  local out = {}
  for k in pairs(t or {}) do out[#out + 1] = k end
  table.sort(out)
  return out
end

function M.new(adapter)
  local renewable, initiallyHidden = {}, {}
  for _, flag in ipairs(adapter.Flags.NEW_GAME_HIDE_FLAGS or {}) do initiallyHidden[flag] = true end
  for _, zone in ipairs(require("src.core.game3.renewable_hidden_items").ZONES) do
    for _, tier in ipairs({ "rare", "uncommon", "common" }) do
      for _, flag in ipairs(zone[tier]) do renewable[flag] = true end
    end
  end
  return setmetatable({ adapter = adapter, maps = {}, renewable = renewable, initiallyHidden = initiallyHidden,
    Trainers = require("src.core.game3.scripting.trainers"), builds = 0 }, M)
end

-- Walk references once per source. All story branches belong in the catalogue;
-- live flags decide completion, not whether an objective happens to be visible.
-- Variable sets are only used to resolve finite gift-species alternatives.
function M.scan(scripts, key, checkpoint)
  local rows, seen, vars, missing = {}, {}, {}, false
  local function walk(at)
    if not at or seen[at] then return end
    seen[at] = true
    local list = scripts[at]
    if not list then missing = true; return end
    for _, row in ipairs(list) do
      rows[#rows + 1] = row
      if checkpoint and #rows % 32 == 0 then checkpoint() end
      if row.op == "setvar" or row.op == "setorcopyvar" then
        local dest, value = row.var or row[1], row.value or row[2]
        if type(value) == "number" and value < 0x4000 then
          vars[dest] = vars[dest] or {}; vars[dest][value] = true
        end
      end
      if row.op == "call" or row.op == "call_if" or row.op == "goto" or row.op == "goto_if" then
        walk(row.target)
      end
      if row.eventScript then walk(row.eventScript) end
      if row.op == "unknown" or row.opaque then missing = true end
    end
  end
  walk(key)
  return rows, vars, missing
end

function M:bundle()
  -- The field engine owns/loads the bundle. Boot and missing extraction must
  -- yield unknown objectives, not a permanently cached empty catalogue.
  local bundle = self.adapter.Space.bundle
  if bundle ~= self.source then self.maps, self.source = {}, bundle end
  return bundle
end

function M:catalog(mapId, checkpoint)
  local bundle = self:bundle()
  if self.maps[mapId] then return self.maps[mapId] end
  local event = bundle and bundle.events and bundle.events[mapId]
  if not event or not bundle.scripts then
    return { { { label = "NOT TRACKED", mapId = mapId, untracked = true } }, {}, {}, {} }
  end
  local out, trainers, pokemon = { {}, {}, {}, {} }, {}, {}
  local function base(obj)
    return { mapId = mapId, x = obj.x, y = obj.y, index = obj.localId,
      id = mapId .. "_obj_" .. tostring(obj.localId), spriteId = obj.sprite,
      hideEvent = obj.flag }
  end
  local function mon(species, obj)
    if mapId == "FR_POKEMON_TOWER_6F" and species == 105 then return end -- uncatchable ghost
    if not self.adapter.data.pokemon[species] then
      out[1][#out[1] + 1] = { label = "POKEMON", mapId = mapId, untracked = true }
      return
    end
    if pokemon[species] then return end
    local row = base(obj)
    row.species = species
    pokemon[species], out[4][#out[4] + 1] = row, row
  end
  local function scan(obj, objectSource)
    if checkpoint then checkpoint() end
    local rows, vars, missing = M.scan(bundle.scripts, obj.scriptKey, checkpoint)
    local hasTrainer, hasMon, hasItem = false, false, false
    for _, command in ipairs(rows) do
      if command.op == "trainerbattle" then
        hasTrainer = true
        local id, typ = command.trainer or command[1], command.type
        local def = self.Trainers.get(id)
        if typ ~= 5 and typ ~= 7 then -- rematch op points at the same base trainer
          local rival = def and (def.class == 81 or def.class == 89 or def.class == 90)
          local league = mapId:match("^FR_POKEMON_LEAGUE_") ~= nil
          local key = rival and ("rival:" .. tostring(def.class) .. ":" .. tostring(typ == 9))
            or league and def and ("league:" .. def.class .. ":" .. def.name) or tostring(id)
          local row = trainers[key]
          if not row then
            row = base(obj)
            row.id = mapId .. "_trainer_" .. key
            row.label = def and ((def.className or "") .. " " .. (def.name or "")):gsub("^%s+", "") or "TRAINERS"
            row.rival, row.league, row.optional = rival, league, typ == 9
            row.flags, row.untracked = {}, not def or type(id) ~= "number"
            trainers[key], out[1][#out[1] + 1] = row, row
          end
          if type(id) == "number" then row.flags[self.adapter.Flags.trainerFlagId(id)] = true end
        end
      elseif command.op == "setwildbattle" or command.op == "givemon" or command.op == "giveegg" then
        hasMon = true
        local species = command[1]
        if type(species) == "number" and species < 0x4000 then mon(species, obj)
        elseif vars[species] then
          for _, candidate in ipairs(sortedKeys(vars[species])) do mon(candidate, obj) end
        else
          out[1][#out[1] + 1] = { label = "POKEMON", mapId = mapId, untracked = true }
        end
      elseif command.op == "special" and command.id == 443 then
        -- CreateEventLegalEnemyMon uses the immediately preceding three vars.
        local species
        for _, r in ipairs(rows) do
          if r == command then break end
          if r.op == "setvar" and (r.var or r[1]) == 0x8004 then species = r.value or r[2] end
        end
        hasMon = true
        mon(species, obj)
      elseif command.op == "specialvar" and command[2] == 252 then
        -- FRLG's trade helper copies the selected trade (VAR_0x8008) into
        -- VAR_0x8004 before GetInGameTradeSpeciesInfo overwrites VAR_RESULT.
        local Trade = require("src.core.game3.scripting.natives_trade")
        for _, id in ipairs(sortedKeys(vars[0x8008])) do
          local entry = Trade.entry(id)
          if entry then mon(entry.species, obj); hasMon = true end
        end
        if not hasMon then missing = true end
      end
    end
    -- Ground pickups use Std_FindItem and their object's durable flag. NPC
    -- gifts/shops are not ground pickups (same scope as the Gen 1/2 checklist).
    if objectSource then
      local value
      for _, command in ipairs(bundle.scripts[obj.scriptKey] or {}) do
        if (command.op == "setvar" or command.op == "setorcopyvar") and (command.var or command[1]) == 0x8000 then
          value = command.value or command[2]
        elseif (command.op == "callstd" or command.op == "gotostd") and command.std == 1 then
          local row = base(obj)
          row.kind, row.itemId, row.event = "item", value, obj.flag
          row.untracked = not self.adapter.data.items[value] or not obj.flag or obj.flag < 0x20 or obj.flag == 65535
          out[2][#out[2] + 1], hasItem = row, true
        end
      end
      -- These balls start hidden. Ownership of a non-consumable key item is
      -- evidence; the initial hide flag on its own is not.
      if mapId == "FR_ROCKET_HIDEOUT_B4F" and (obj.flag == 54 or obj.flag == 55) then
        local row = base(obj)
        row.kind, row.itemId, row.ownedKey = "item", value, true
        out[2][#out[2] + 1], hasItem = row, true
      elseif mapId == "FR_MT_MOON_B2F" and (obj.flag == 47 or obj.flag == 48) then
        local row = base(obj)
        row.kind, row.itemId = "item", obj.flag == 47 and 358 or 357
        row.event, row.alternative = obj.flag == 47 and 626 or 627, obj.flag == 47 and 627 or 626
        out[2][#out[2] + 1], hasItem = row, true
      end
      if not hasTrainer and (obj.trainerType == 1 or obj.trainerType == 3)
          or obj.graphicsId == 92 and not hasItem and not hasMon then
        local row = base(obj)
        row.label, row.untracked = "NOT TRACKED", true
        out[1][#out[1] + 1] = row
      end
    end
    if missing then
      local row = base(obj)
      row.label, row.untracked = "NOT TRACKED", true
      out[1][#out[1] + 1] = row
    end
  end
  for _, obj in ipairs(event.objects or {}) do
    if not obj.cloneTarget then scan(obj, true) end
  end
  for _, obj in ipairs(event.coordEvents or {}) do scan(obj) end
  for _, key in ipairs(sortedKeys(event.mapScripts)) do
    local entry = event.mapScripts[key]
    if type(entry) == "string" then scan({ scriptKey = entry })
    elseif type(entry) == "table" then
      for _, trigger in ipairs(entry) do scan({ scriptKey = trigger.script }) end
    end
  end
  for _, bg in ipairs(event.bgEvents or {}) do
    if bg.type == "hidden_item" then
      local row = base(bg)
      row.kind, row.itemId, row.event = "hidden", bg.item, bg.flag
      row.underfoot = bg.underfoot
      row.repeatable = self.renewable[bg.flag] == true
      row.untracked = not self.adapter.data.items[bg.item] or not bg.flag or bg.flag < 0x20
      out[3][#out[3] + 1] = row
    elseif bg.scriptKey then scan(bg) end
  end
  if mapId:match("^FR_TRAINER_TOWER_%dF$") then
    -- Tower opponents are generated per challenge, without route defeat flags.
    out[1][#out[1] + 1] = { label = "TRAINERS", mapId = mapId, repeatable = true }
  end
  table.sort(out[4], function(a, b) return a.species < b.species end)
  self.maps[mapId], self.builds = out, self.builds + 1
  return out
end

function M:ownsKey(id)
  local session = self.adapter.session
  for _, pocket in pairs(session and session.bag and session.bag.pockets or {}) do
    for _, item in ipairs(pocket) do
      if item.id == id and (item.qty or 0) > 0 then return true end
    end
  end
  for _, item in ipairs(session and session.storage and session.storage.items or {}) do
    if item.id == id and (item.qty or 0) > 0 then return true end
  end
  return false
end

function M:completionKey()
  -- These two non-consumable keys start as hidden objects and require actual
  -- ownership. Bag/PC writes need not emit flag.changed in the native host.
  return (self:ownsKey(356) and 1 or 0) + (self:ownsKey(359) and 2 or 0)
end

function M:rows(mapIds, checkpoint)
  local out, adapter = { {}, {}, {} }, self.adapter
  local store, Flags = adapter:flagStore(), adapter.Flags
  local function flag(id) return Flags.getFlag(store, nil, id) == true end
  for _, id in ipairs(mapIds) do
    local catalog = self:catalog(id, checkpoint)
    for category = 1, 3 do
      for _, source in ipairs(catalog[category]) do
        local row = copy(source)
        row.done = row.event and flag(row.event) or false
        if row.flags then
          for event in pairs(row.flags) do row.done = row.done or flag(event) end
          if row.league then row.done = row.done or flag("FLAG_SYS_GAME_CLEAR") end
          if row.rival then row.label = adapter.session and adapter.session.rivalName or row.label end
        elseif row.ownedKey then
          row.done = self:ownsKey(row.itemId)
        end
        if row.itemId then row.label = (adapter.data.items[row.itemId] or {}).name or "ITEMS" end
        row.excluded = row.alternative and not row.done and flag(row.alternative) or nil
        if row.repeatable then
          row.available, row.done = not flag(row.event), false
          row.status = category == 1 and "REPEATABLE" or row.available and "READY" or "RENEWABLE"
        elseif row.untracked then row.status = "NOT TRACKED"
        elseif row.excluded then row.status = "ALTERNATIVE CHOICE"
        elseif not row.done and id:match("^FR_SSANNE_") and flag("FLAG_HIDE_SS_ANNE") then
          row.missed, row.available, row.status = true, false, "MISSED"
        elseif not row.done and row.hideEvent and row.hideEvent >= 0x20 and flag(row.hideEvent) then
          row.available = false
          if row.flags and not self.initiallyHidden[row.hideEvent] then
            row.missed, row.status = true, "MISSED"
          else row.status = "LATER" end
        end
        out[category][#out[category] + 1] = row
      end
    end
  end
  return out
end

function M:pokemon(mapIds, checkpoint)
  local adapter, bySpecies = self.adapter, {}
  for _, id in ipairs(mapIds) do
    for _, row in ipairs(adapter:encounters(id)) do bySpecies[row.species] = { species = row.species, mapId = id } end
    for _, row in ipairs(self:catalog(id, checkpoint)[4]) do bySpecies[row.species] = row end
  end
  local caught, out = adapter.save and adapter.save.pokedex.caught or {}, {}
  local function goal(ids)
    local row, names, done = nil, {}, false
    for _, species in ipairs(ids) do
      if bySpecies[species] then
        row = row or copy(bySpecies[species])
        names[#names + 1] = adapter.data.pokemon[species].name
        if caught[species] then row.species, done = species, true end
        bySpecies[species] = nil
      end
    end
    if row then
      row.label, row.done = table.concat(names, " / "), done
      row.order = adapter.data.pokemon[row.species].dex
      out[#out + 1] = row
    end
  end
  for _, id in ipairs(mapIds) do
    if id == "FR_OAKS_LAB" then
      -- One starter is obtainable, even before the player chooses it.
      local starter = adapter.Flags.getVar(adapter:flagStore(), nil, "VAR_STARTER_MON")
      if adapter.Flags.getFlag(adapter:flagStore(), nil, "FLAG_SYS_POKEMON_GET") then
        local selected = ({ [0] = 1, [1] = 7, [2] = 4 })[starter]
        for _, sp in ipairs({ 1, 4, 7 }) do if sp ~= selected then bySpecies[sp] = nil end end
      end
      goal({ 1, 4, 7 })
    elseif id == "FR_SAFFRON_CITY_DOJO" then goal({ 106, 107 })
    elseif id == "FR_CINNABAR_ISLAND_POKEMON_LAB_EXPERIMENT_ROOM" then
      if adapter.Flags.getFlag(adapter:flagStore(), nil, "FLAG_GOT_DOME_FOSSIL") then bySpecies[138] = nil
      elseif adapter.Flags.getFlag(adapter:flagStore(), nil, "FLAG_GOT_HELIX_FOSSIL") then bySpecies[140] = nil end
      goal({ 138, 140 })
    end
  end
  for _, species in ipairs(sortedKeys(bySpecies)) do goal({ species }) end
  table.sort(out, function(a, b) return a.order < b.order end)
  return out
end

return M
