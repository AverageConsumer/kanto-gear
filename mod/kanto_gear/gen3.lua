-- Read models for the native FR/LG engine. Never write presentation data back
-- to Game3.save: it is a serialization snapshot, not the running session.
local Gen3 = {}
Gen3.__index = Gen3

local function copy(source)
  local out = {}
  for key, value in pairs(source or {}) do out[key] = value end
  return out
end

local function clear(t)
  for key in pairs(t) do t[key] = nil end
end

local pockets = { ITEMS = "ITEM", KEY_ITEMS = "KEY_ITEM",
  POKE_BALLS = "BALL", TM_CASE = "TM_HM", BERRY_POUCH = "BERRY" }
local statFields = { hp = "maxHp", attack = "attack", defense = "defense",
  speed = "speed", specialAttack = "spAtk", specialDefense = "spDef" }
local geneticFields = { "hp", "atk", "def", "spe", "spa", "spd" }

function Gen3.new(game)
  assert(game.generation == 3, "native Gen 3 game required")
  local self = setmetatable({ game = game, mons = setmetatable({}, { __mode = "k" }) }, Gen3)
  self.Pokemon = require("src.core.game3.pokemon")
  self.Moves = require("src.core.game3.battle.moves")
  self.Items = require("src.core.game3.items_data")
  self.Dex = require("src.core.game3.dex")
  self.Flags = require("src.core.game3.scripting.flags")
  self.FieldMoves = require("src.core.game3.field_moves")
  self.Summary = require("src.core.game3.summary_data")
  self.typeNames = {}
  for name, id in pairs(require("src.core.game3.battle.types").ID) do
    self.typeNames[id] = name
  end
  self:refreshDefinitions()
  self:refresh()
  return self
end

function Gen3:types(source)
  local out = {}
  for _, id in ipairs(source or {}) do
    local name = type(id) == "number" and self.typeNames[id] or id
    if name and name ~= out[1] then out[#out + 1] = name end
  end
  return out
end

function Gen3:refreshDefinitions()
  local Compat = require("src.mods.Gen3Compat")
  local source = Compat.dataView(self.game.data or {})
  local P, M, I = self.Pokemon, self.Moves, self.Items
  local data = { pokemon = {}, moves = {}, items = {}, maps = self.game.data and self.game.data.maps or {} }
  -- Iterate National IDs, not the native table length (which includes holes
  -- and special sprite IDs). Keep internal IDs as keys everywhere else.
  for dex = 1, self.Dex.NATIONAL_MAX do
    local id = P.speciesFromNational(dex)
    if id then
      local row = copy(source.pokemon[id])
      row.index, row.dex, row.national = id, dex, dex
      row.types = self:types(row.types)
      row.learnset = {}
      for _, learn in ipairs(P.learnset(id) or {}) do
        row.learnset[#row.learnset + 1] = {
          level = learn.level or learn[1], move = M.constName(learn.move or learn.id or learn[2]),
        }
      end
      row.tmhm = {}
      for itemId = I.FIRST_TM, I.LAST_HM do
        if P.canLearnTmItem(id, itemId) then
          row.tmhm[#row.tmhm + 1] = M.constName(P.moveFromTmItem(itemId))
        end
      end
      data.pokemon[id] = row
    end
  end
  for id = 1, require("src.import.gba.versions").MOVES_COUNT - 1 do
    local row = copy(source.moves[id])
    row.index, row.id = id, M.constName(id)
    row.type = self.typeNames[row.type] or row.type
    row.name = row.name or M.displayName(id)
    data.moves[row.id] = row
  end
  setmetatable(data.moves, { __index = function(t, id)
    if type(id) == "number" and id > 0 then return rawget(t, M.constName(id)) end
  end })
  I.ensureLoaded()
  for id in pairs(I._byId or {}) do
    local row = copy(source.items[id])
    row.index, row.nativePocket = id, row.pocket
    row.pocket = pockets[row.pocket]
    row.kind = I.medicineKind(id)
    row.ball = row.pocket == "BALL"
    local taught = P.moveFromTmItem(id)
    row.teaches = taught and M.constName(taught)
    data.items[id] = row
  end
  setmetatable(data.items, { __index = function(t, id)
    local num = I.toNumericId(id)
    return num and rawget(t, num)
  end })
  self.data = data
end

function Gen3:mon(source)
  if type(source) ~= "table" then return nil end
  local out = self.mons[source]
  if not out then
    out = { moves = {}, stats = {}, ivs = {}, evs = {} }
    self.mons[source] = out
  end
  local P = self.Pokemon
  out.species, out.level = P.speciesOf(source), source.level
  out.speciesNumbering = P.NUMBERING_INTERNAL
  out.nickname = source.nickname ~= "" and source.nickname or nil
  out.hp, out.maxHp = source.hp, source.maxHp
  out.status = source.status
  out.isEgg = P.isEgg(source)
  out.personality = source.personality
  out.gender = self.Summary.gender(source)
  out.shiny = P.isShiny(source)
  out.nature = P.natureId(source.personality)
  out.ability = source.ability or source.abilityId or P.abilityId(out.species, source.personality)
  out.types = self:types(P.types(out.species))
  out.ot, out.otId, out.otSecretId = source.otName or source.ot, source.otId, source.otSecretId
  out.exp, out.experience = source.exp or source.experience, source.exp or source.experience
  out.item = source.heldItem or source.item
  for key, field in pairs(statFields) do out.stats[key] = source[field] end
  for _, key in ipairs(geneticFields) do
    out.ivs[key] = source.ivs and source.ivs[key]
    out.evs[key] = source.evs and source.evs[key]
  end
  for slot = 1, 4 do
    local id = source.moves and source.moves[slot]
    if id and id ~= 0 then
      local move = out.moves[slot] or {}
      move.id, move.index = self.Moves.constName(id), id
      move.pp = source.pp and source.pp[slot]
      move.maxPp = source.maxPp and source.maxPp[slot]
      move.ppUps = source.ppUps and source.ppUps[slot] or 0
      out.moves[slot] = move
    else out.moves[slot] = nil end
  end
  return out
end

function Gen3:refresh()
  local session = self.game.session
  if session ~= self.session then
    self.session = session
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
  clear(save.inventory)
  clear(save.bagOrder)
  -- bag.stacks contains duplicate numeric/string aliases. The native pockets
  -- are authoritative; do not call Bag.listPocket, which sanitizes on read.
  for _, pocket in ipairs(self.Items.POCKET_ORDER) do
    for _, slot in ipairs(session.bag and session.bag.pockets[pocket] or {}) do
      local id, qty = self.Items.toNumericId(slot.id), tonumber(slot.qty) or 0
      if id and qty > 0 then
        if save.inventory[id] == nil then save.bagOrder[#save.bagOrder + 1] = id end
        save.inventory[id] = (save.inventory[id] or 0) + qty
      end
    end
  end
  local dex = session.dex or {}
  clear(save.pokedex.seen)
  clear(save.pokedex.caught)
  for id in pairs(self.data.pokemon) do
    save.pokedex.seen[id] = self.Dex.isSeen(dex, id) or nil
    save.pokedex.caught[id] = self.Dex.isCaught(dex, id) or nil
  end
  save.pokedex.national = dex.national == true
  save.pokedex.limit = save.pokedex.national and self.Dex.NATIONAL_MAX or self.Dex.KANTO_MAX
  return save
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

function Gen3:badge(index)
  return self.session ~= nil and index >= 1 and index <= 8
    and self.Flags.getFlag(self.session, nil, 0x81f + index) == true
end

function Gen3:methods()
  local session, inventory = self.session, self.save and self.save.inventory or {}
  local out = { WALK = true }
  for _, rod in ipairs({ "OLD", "GOOD", "SUPER" }) do
    out[rod] = (inventory[rod .. "_ROD"] or 0) > 0
  end
  for method, move in pairs({ SURF = "SURF", ["ROCK SMASH"] = "ROCK_SMASH" }) do
    local mon = self.FieldMoves.partyMoveUser(session and session.party or {}, move)
    out[method] = mon ~= nil and self.FieldMoves.hasBadge(session, move) == true
  end
  return out
end

function Gen3:habitatMethods()
  local methods = self:methods()
  local available = {}
  local function learn(mon)
    if not mon or self.Pokemon.isEgg(mon) then return end
    for _, id in ipairs(mon.moves or {}) do available[id] = true end
  end
  for _, mon in ipairs(self.session and self.session.party or {}) do learn(mon) end
  for _, box in ipairs(self.session and self.session.storage and self.session.storage.boxes or {}) do
    for slot = 1, 30 do learn(box.mons and box.mons[slot]) end
  end
  for id, count in pairs(self.save and self.save.inventory or {}) do
    local move = self.Pokemon.moveFromTmItem(id)
    if move and count > 0 then available[move] = true end
  end
  local reasons = {}
  for _, rod in ipairs({ "OLD", "GOOD", "SUPER" }) do
    if not methods[rod] then reasons[rod] = "NEED " .. rod .. " ROD" end
  end
  for method, move in pairs({ SURF = "SURF", ["ROCK SMASH"] = "ROCK_SMASH" }) do
    if not available[self.FieldMoves.MOVES[move]] then
      reasons[method] = "NEED " .. method
    elseif not self.FieldMoves.hasBadge(self.session, move) then
      reasons[method] = "NEED BADGE"
    end
  end
  return reasons
end

-- Slot odds are conditional on this encounter method, not the step encounter
-- rate. Each rod has its own 100% pool; map aliases must not duplicate areas.
local pools = {
  { key = "land", method = "WALK", first = 1, weights = { 20,20,10,10,10,10,5,5,4,4,1,1 } },
  { key = "water", method = "SURF", first = 1, weights = { 60,30,5,4,1 } },
  { key = "rocks", method = "ROCK SMASH", first = 1, weights = { 60,30,5,4,1 } },
  { key = "fishing", method = "OLD", first = 1, weights = { 70,30 } },
  { key = "fishing", method = "GOOD", first = 3, weights = { 60,20,20 } },
  { key = "fishing", method = "SUPER", first = 6, weights = { 40,40,15,4,1 } },
}

function Gen3:encounters(mapId)
  local source = self.game.data and self.game.data.gen3Encounters or {}
  local area, rows = source[mapId], {}
  if not self.data.maps[mapId] then return rows end
  for _, pool in ipairs(pools) do
    local encounter = area and area[pool.key]
    if encounter and (pool.key == "fishing" or (tonumber(encounter.rate) or 0) > 0) then
      local bySpecies = {}
      for index, chance in ipairs(pool.weights) do
        local slot = encounter.slots and encounter.slots[pool.first + index - 1]
        if slot and self.data.pokemon[slot.species] then
          local row = bySpecies[slot.species]
          if not row then
            row = { species = slot.species, mapId = mapId, method = pool.method,
              chance = 0, minLevel = slot.minLevel, maxLevel = slot.maxLevel }
            bySpecies[slot.species] = row
            rows[#rows + 1] = row
          end
          row.chance = row.chance + chance
          row.minLevel = math.min(row.minLevel, slot.minLevel)
          row.maxLevel = math.max(row.maxLevel, slot.maxLevel)
        end
      end
    end
  end
  return rows
end

return Gen3
