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
  self.Space = require("src.core.game3.scripting.space")
  self.FieldMoves = require("src.core.game3.field_moves")
  self.Summary = require("src.core.game3.summary_data")
  self.Types = require("src.core.game3.battle.types")
  self.Battle = require("src.core.game3.battle")
  self.BattleUI = require("src.core.game3.battle.ui")
  self.Anim = require("src.core.game3.battle.anim")
  self.Field = require("src.core.game3.field")
  self.Warp = require("src.core.game3.warp")
  self.Runtime = require("src.core.game3.runtime")
  self.Message = require("src.ui.game3.message")
  self.Font = require("src.ui.game3.frlg_font")
  self.TextIR = require("src.core.game3.scripting.text_ir")
  self.Choice = require("src.ui.game3.choice")
  self.typeNames = {}
  for name, id in pairs(self.Types.ID) do
    self.typeNames[id] = name
  end
  self:refreshDefinitions()
  self:refresh()
  return self
end

function Gen3:drawPlayer(g, x, y, scale, feet, facing)
  local sprites = require("src.core.game3.ow_sprites")
  local spr = sprites.getDraw(sprites.playerGraphicsId(self.game))
  if not spr then return false end
  local frame, flip = sprites.pose(spr, facing or "down", false, false)
  local quad = spr.quads[frame]
  if not quad then return false end
  scale = scale or 1
  g.setColor(1, 1, 1, 1)
  g.draw(spr.image, quad, x + (flip and 0.5 or -0.5) * spr.width * scale,
    y - (feet and spr.height or spr.height / 2) * scale,
    0, flip and -scale or scale, scale)
  return true
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
  local dexData = require("src.core.game3.pokedex_data")
  local data = { pokemon = {}, moves = {}, items = {}, maps = self.game.data and self.game.data.maps or {} }
  -- Iterate National IDs, not the native table length (which includes holes
  -- and special sprite IDs). Keep internal IDs as keys everywhere else.
  for dex = 1, self.Dex.NATIONAL_MAX do
    local id = P.speciesFromNational(dex)
    if id then
      local row = copy(source.pokemon[id])
      row.index, row.dex, row.national = id, dex, dex
      local entry = dexData.getEntry(dex)
      row.dexEntry = { kind = entry.category, heightM = entry.heightDm / 10,
        weightKg = entry.weightHg / 10, text = entry.description }
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
    row.nativeGen3 = true
    row.description = self.Summary.moveDescription(id, row.name)
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
  data.type_chart = { matchups = {} }
  for name, id in pairs(self.Types.ID) do
    for other, target in pairs(self.Types.ID) do
      local multiplier = self.Types.effectiveness(id, target) * 10
      if multiplier ~= 10 then
        data.type_chart.matchups[#data.type_chart.matchups + 1] = {
          attacker = name, defender = other, multiplier = multiplier,
        }
      end
    end
  end
  self.data = data
  setmetatable(data.pokemon, { __index = function(t, id)
    if type(id) == "string" then
      local numeric = P.speciesFromName(id)
      return numeric and rawget(t, numeric)
    end
  end })
  setmetatable(data, { __index = self.game.data })
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
  out.status = ({ "PSN", "PAR", "SLP", "FRZ", "BRN", "PKRS", "FNT" })[
    self.Summary.statusAilment(source)]
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

function Gen3:itemfinderSignals()
  if not self.session or (self.save.inventory.ITEMFINDER or 0) < 1 then return {} end
  local Map = require("src.core.game3.map")
  local Player = require("src.core.game3.player")
  local id, store = self.session.map, self:flagStore()
  local function events(map)
    local def = self.data.maps[map]
    local bundle = self.Space.bundle and self.Space.bundle.events and self.Space.bundle.events[map]
    return def and def.bgEvents or bundle and bundle.bgEvents or {}
  end
  local current = Map.current == id
  local layout = self.data.maps[id] and self.data.maps[id].midLayout
  local result = require("src.core.game3.itemfinder").scan({
    px = current and Player.cellX or self.session.x,
    py = current and Player.cellY or self.session.y,
    events = events(id), width = layout and layout.width, height = layout and layout.height,
    neighborList = current and Map.neighborList or {},
    neighbors = current and Map.neighbors or {}, eventsFor = events,
    flagSet = function(ev)
      local flag = ev.flag or ev.hiddenItemId and (0x3E8 + ev.hiddenItemId)
      return not flag or self.Flags.getFlag(store, nil, flag)
    end,
  })
  -- A read-only scan: no native animation, flag writes or underfoot pickup.
  return result and { { dx = result.itemX, dy = result.itemY } } or {}
end

function Gen3:itemfinderReached(px, py, row, progress)
  if row.done or row.available == false or row.untracked then return false end
  local result = require("src.core.game3.itemfinder").scan({ px = px, py = py,
    events = { { type = "hidden_item", x = row.x, y = row.y, underfoot = row.underfoot } },
    flagSet = function() return false end })
  if not result then return false end
  return (row.x - px)^2 + (row.y - py)^2 <= 74 * math.max(0, math.min(1, progress or 0))^2
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
  local dexChanged = save.pokedex.national ~= (dex.national == true)
  for id in pairs(self.data.pokemon) do
    local seen, caught = self.Dex.isSeen(dex, id) or nil, self.Dex.isCaught(dex, id) or nil
    dexChanged = dexChanged or seen ~= save.pokedex.seen[id] or caught ~= save.pokedex.caught[id]
    save.pokedex.seen[id], save.pokedex.caught[id] = seen, caught
  end
  if dexChanged then self.dexRevision = (self.dexRevision or 0) + 1 end
  save.pokedex.national = dex.national == true
  save.pokedex.limit = save.pokedex.national and self.Dex.NATIONAL_MAX or self.Dex.KANTO_MAX
  return save
end

-- Storage allocates an opaque identity on the serialized save. Call this
-- after binding mod.storage so a subsequent native save retains that identity.
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

function Gen3:badge(index)
  return self.session ~= nil and index >= 1 and index <= 8
    and self.Flags.getFlag(self:flagStore(), nil, 0x81f + index) == true
end

function Gen3:locations()
  if self.locationCache then return self.locationCache end
  local sections = require("src.import.gba.map_sections_extract")
  local out = {}
  for id, def in pairs(self.data.maps) do
    local info = sections.getInfo(def.regionMapSectionId, id, def.floorNum)
    out[id] = { name = info and info.resolved and info.rawName
      or id:gsub("^FR_", ""):gsub("_", " "), section = def.regionMapSectionId }
    -- Localized names are labels, never progress identity. Keep gyms/dojo
    -- separate from city houses; combine dungeon floors and route segments.
    local facility = id:match("_GYM$") and "GYM" or id:match("_DOJO$") and "DOJO"
    out[id].progressGroup = facility and id or "gen3:" .. tostring(def.regionMapSectionId or id)
    out[id].progressKind = id:match("FOREST$") and "forest"
      or def.mapType == 4 and "cave" or "route"
    if facility then out[id].name = out[id].name .. " " .. facility end
  end
  self.locationCache = out
  return out
end

function Gen3:areaMaps(id)
  local locations = self:locations()
  local group = locations[id] and locations[id].progressGroup
  if not group then return { id } end
  local out = {}
  for other, location in pairs(locations) do
    if location.progressGroup == group then out[#out + 1] = other end
  end
  table.sort(out)
  return out
end

-- Legacy renderers receive a projection, while input hooks, storage and all
-- commands retain self.game. Unknown native modal screens deliberately do not
-- claim a legacy screenId: only explicitly adapted screens may own input.
function Gen3:gameView()
  if self.view then return self.view end
  local world = { player = require("src.core.game3.player"), map = {} }
  local methods = {}
  local stack = { states = {} }
  local layers = setmetatable({}, { __mode = "k" })
  local locked = { screenId = "Gen3:busy" }
  local text = { screenId = "Gen3:message", isTextBox = true }
  function stack:top() return self.states[#self.states] end
  self.syncScreens = function()
    clear(stack.states)
    if self.session and self.game.phase == "field" then
      local maps = require("src.core.game3.map")
      world.map.id = maps.current or self.session.map
      stack.states[1] = world
      local battle = self:battleState()
      if battle then stack.states[#stack.states + 1] = battle end
      for _, layer in ipairs(require("src.ui.game3.stack")._layers) do
        local state = layers[layer]
        if not state then
          state = { screenId = "Gen3:" .. tostring(layer.id), nativeModal = true }
          layers[layer] = state
        end
        if layer.id == "summary" and layer.mod then
          local native = layer.mod
          state.screenId, state.native = "Gen3SummaryMenu", native
          state.mon = self:mon(native._party and native._party[native._cursor])
          state.page = (native._page or 0) + 1
          state.moveDetail = native._mode == "select_move" or state.page > 3 or false
        end
        state.phase = layer.mod and layer.mod.mode
        state.index = layer.mod and (layer.mod.mode == "action" and layer.mod.actionCursor
          or layer.mod.mode == "item_action" and layer.mod.itemActionCursor
          or layer.mod.cursor or layer.mod._cursor)
        state.pocketIndex = layer.mod and layer.mod.pocketIdx
        stack.states[#stack.states + 1] = state
      end
      if self.Message.isOpen() and not self.Choice.active then
        text.page = self.Message._page
        text.choice = self.Message._stay or self.Message._choice or self.Message._held
        text.waiting = self.Message.isWaiting() and not text.choice
        text.done = not self.Message.isTyping()
        stack.states[#stack.states + 1] = text
      end
      -- Native scripts, transitions and battles need not push a UI layer.
      -- Walking alone is not a modal state and must not dim the live map.
      local Field, Warp, Runtime, Battle = self.Field, self.Warp, self.Runtime, self.Battle
      if #stack.states == 1 and (Field and Field.locked
          or Warp and Warp.isBusy() or Runtime and Runtime.uiBusy()
          or Battle and Battle.isActive()) then
        stack.states[2] = locked
      end
    end
  end
  self.view = setmetatable({}, { __index = function(_, key)
    if key == "save" then return self.save end
    if key == "data" then return self.data end
    if key == "stack" then return stack end
    if key == "world" or key == "overworld" then
      return self.session and self.game.phase == "field" and world or nil
    end
    local value = self.game[key]
    if type(value) == "function" then
      if not methods[key] then methods[key] = function(_, ...) return value(self.game, ...) end end
      return methods[key]
    end
    return value
  end })
  self.syncScreens()
  return self.view
end

-- A presentation state for native battles, which do not live on Game.stack.
-- It deliberately cannot claim the legacy upper-screen visibility contract.
function Gen3:battleState()
  local B = self.Battle
  if not B or not B.isActive() then return nil end
  local st, U = B.getState(), self.BattleUI
  if not st then return nil end
  if not self.battleView or self.battleSource ~= st then
    self.battleSource = st
    self.battleView = { isBattleState = true, nativeGen3 = true }
    local order = st.safari and { 1, 2, 3, 4 } or { 1, 3, 2, 4 }
    setmetatable(self.battleView, {
      __index = function(_, key)
        if key == "menuIndex" then return U and order[U._menuIndex] end
        if key == "moveIndex" then return U and U._moveIndex end
      end,
      __newindex = function(t, key, value)
        if key == "menuIndex" then if U then U._menuIndex = order[value] end
        elseif key == "moveIndex" then if U then U._moveIndex = value end
        else rawset(t, key, value) end
      end,
    })
  end
  local view = self.battleView
  view.phase = B._phase == "command" and U and U._mode or B._phase
  view.kind, view.battle = st.kind or (st.wild and "wild" or "trainer"), st
  view.player, view.enemy = st.player, st.enemy
  view.tutorial, view.demo = st.oldManTutorial or B._auto, st.pokedude
  view.activeBattler = U and U._active
  view.draining = self.Anim.busy() and (not self.Message.isOpen()
    or self.Message._held or self.Message._stay) or false
  return view
end

-- Message.currentPage is a single visible page, not a history of messages.
-- Read the native printer's tokens so color/spacing codes never become text.
function Gen3:messageText()
  if not self.Message.isOpen() then return nil end
  return self:plainText(self.Message.currentPage())
end

function Gen3:plainText(text)
  local out = {}
  local glyphs = { [0x53] = "PK", [0x54] = "MN", [0x34] = "Lv",
    [0x2C] = "er", [0x84] = "e", [0xA0] = "re" }
  for kind, value in self.Font.scanTokens(text) do
    if kind == "char" or kind == "nl" then out[#out + 1] = value
    elseif kind == "glyph" then
      out[#out + 1] = glyphs[value] or self.TextIR.CHARMAP[value]
        or self.TextIR.EXTRA_SYMBOL[value - 0x100] or "?"
    elseif kind == "icon" then
      out[#out + 1] = ({ "A", "B", "L", "R", "START", "SELECT",
        "UP", "DOWN", "LEFT", "RIGHT", "UP/DOWN", "LEFT/RIGHT", "DPAD" })[value + 1] or "?"
    end
  end
  return table.concat(out)
end

function Gen3:battleSnapshot(snapshot)
  if not snapshot then return nil end
  local state = self:battleState()
  local st = state and state.battle
  if not st then return nil end
  snapshot.menuIndex, snapshot.moveIndex = state.menuIndex, state.moveIndex
  snapshot.nativeUnsupported = state.tutorial or state.demo or st.link
  snapshot.nativeMessage = self:messageText()
  if snapshot.nativeMessage then
    snapshot.message = { snapshot.nativeMessage }
    -- An Oak voiceover or an item notice can cover a still-open command menu.
    -- Held/timed pages must not advertise a continue action they cannot take.
    local M = self.Message
    snapshot.nativeCanReveal = M.isTyping() and not M._choice
    snapshot.prompt = M.isWaiting() and not M._stay and not M._held
      and not M._choice and "advance" or "locked"
  end
  if st.safari and snapshot.prompt == "menu" then
    snapshot.prompt, snapshot.safariBalls = "safari", st.safariState and st.safariState.balls or 0
  end
  local function enrich(out, source)
    if not out or not source then return end
    local view = self:mon(source)
    out.source, out.species, out.types = view, view.species, view.types
    out.gender, out.shiny, out.isEgg = view.gender, view.shiny, view.isEgg
    out.name = view.nickname or self.Pokemon.name(view.species)
    out.level, out.status = view.level, view.status
  end
  for i, mon in ipairs(st.playerParty or {}) do enrich(snapshot.party[i], mon) end
  local owner = snapshot.active == 2 and st.battlers and st.battlers[2] or st.player
  enrich(snapshot.player, owner and owner.mon)
  enrich(snapshot.enemy, st.enemy and st.enemy.mon)
  for _, side in ipairs({ "player", "enemy" }) do
    local out, source = snapshot[side], side == "player" and owner or st.enemy
    if out and source then
      local key = st.double and (side == "player" and snapshot.active or 1) or side
      local shown = self.Anim.shownBattler(key, source)
      enrich(out, shown and shown.mon)
      local _, hp, maxHp = self.Anim.displayHpRatio(key, shown)
      out.hp, out.maxHp = math.floor(hp), maxHp
      out.nativeShownHp = out.hp
    end
  end
  for _, move in ipairs(snapshot.moves or {}) do
    move.id = self.Moves.constName(move.id)
    move.type = self.typeNames[move.type] or move.type
  end
  return snapshot
end

function Gen3:toolUnlocked(def)
  if def.item then return (self.save and self.save.inventory[def.item] or 0) > 0 end
  if def.move == "HEADBUTT" or def.move == "WHIRLPOOL" then return false end
  if not self.FieldMoves.MOVES[def.move] then return false end
  return self.FieldMoves.partyMoveUser(self.session and self.session.party, def.move) ~= nil
    and self.FieldMoves.hasBadge(self:flagStore(), def.move) == true
end

function Gen3:methods()
  local session, inventory = self.session, self.save and self.save.inventory or {}
  local out = { WALK = true }
  for _, rod in ipairs({ "OLD", "GOOD", "SUPER" }) do
    out[rod] = (inventory[rod .. "_ROD"] or 0) > 0
  end
  for method, move in pairs({ SURF = "SURF", ["ROCK SMASH"] = "ROCK_SMASH" }) do
    local mon = self.FieldMoves.partyMoveUser(session and session.party or {}, move)
    out[method] = mon ~= nil and self.FieldMoves.hasBadge(self:flagStore(), move) == true
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
    elseif not self.FieldMoves.hasBadge(self:flagStore(), move) then
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
