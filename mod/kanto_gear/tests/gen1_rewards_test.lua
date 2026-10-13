local T = require("tests.modkit")
love.graphics.arc = love.graphics.arc or function() end
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local Gifts = dofile(root .. "/features/gen1_gifts.lua")
local Progress = dofile(root .. "/features/achievements.lua")
require("data.scripts.init")
local scripts = require("src.script.MapScripts")
local version = require("src.core.GameVersion").get()
local policy = Gifts.new()
local data = { pokemon = { EEVEE = { name = "EEVEE", index = 133 }, LAPRAS = { name = "LAPRAS", index = 131 },
  HITMONLEE = { name = "HITMONLEE" }, HITMONCHAN = { name = "HITMONCHAN" },
  BULBASAUR = { name = "BULBASAUR" }, SQUIRTLE = { name = "SQUIRTLE" } },
  field = { trades = { { give = "EEVEE", get = "LAPRAS" } } } }
local save = { flags = {}, party = {}, inventory = {}, pokedex = { owned = { EEVEE = true } } }
local map = { objects = { { index = 1, name = "GIVER", text = "GIFT", x = 2, y = 3 } } }
local handler = { { "check_flag", "RECEIVED" }, { "jump_if_true", "end" },
  { "give_pokemon", "EEVEE", 25 }, { "jump_if_false", "end" }, { "set_flag", "RECEIVED" } }
local original = scripts.talkScript
scripts.talkScript = function(id, text) if id == "TEST" then return handler end; return original(id, text) end
local function rows() return policy:rows(data, save, "TEST", map) end
T.eq(#rows(), 1, "gift requires a successful give-pokemon path")
T.eq(rows()[1].species, "EEVEE", "gift preserves the literal species")
T.eq(rows()[1].level, 25, "gift preserves its actual level")
T.eq(rows()[1].done, false, "owning the species elsewhere does not complete this gift")
save.flags.RECEIVED = true
save.party, save.pokedex.owned = {}, {}
T.eq(rows()[1].done, true, "released gift remains completed by its receipt flag")
save.flags.RECEIVED = nil
T.eq(rows()[1].done, false, "older save restores the unreceived gift")
local Boxes = require("src.pokemon.Boxes")
save.party, save.boxes = {}, {}
for i = 1, 6 do save.party[i] = {} end
for i = 1, Boxes.COUNT do
  save.boxes[i] = {}
  for j = 1, Boxes.CAPACITY do save.boxes[i][j] = {} end
end
T.eq(rows()[1].noRoom, true, "full party and all full boxes delay the gift")
T.eq(rows()[1].done, false, "lack of space cannot mark a gift received")
T.eq(save.currentBox, nil, "capacity check never migrates or changes the active box")
table.remove(save.boxes[Boxes.COUNT])
T.eq(rows()[1].available, true, "space in any native overflow box allows the gift")
save.party, save.boxes = {}, nil
handler = { { "check_flag", "RECEIVED" }, { "jump_if_true", "end" },
  { "give_pokemon", "EEVEE", 25 }, { "set_flag", "RECEIVED" } }
T.eq(#rows(), 0, "flag written even when party and box are full is not trusted")
handler = { { "check_flag", "RECEIVED" }, { "jump_if_true", "end" },
  { "give_pokemon", "EEVEE", 25 }, { "jump_if_true", "end" }, { "set_flag", "RECEIVED" } }
T.eq(#rows(), 0, "receipt on the failure branch cannot prove acquisition")
handler = { { "check_flag", "RECEIVED" }, { "jump_if_true", "end" },
  { "give_pokemon", "EEVEE", 25 }, { "jump_if_false", "end" }, { "set_flag", "RECEIVED" } }
handler[3][3] = nil
T.eq(#rows(), 0, "malformed Pokémon level cannot create a reward")
handler = { { "face_player" }, { "trade", 1, "TRADED" } }
T.eq(rows()[1].species, "LAPRAS", "trade reads received species from live data")
T.eq(rows()[1].needsSpecies, "EEVEE", "trade reads requested species from live data")
T.eq(rows()[1].available, false, "PC-only or absent partner is not immediately tradable")
save.party[1] = { species = "EEVEE" }
T.eq(rows()[1].available, true, "matching partner in the current party unlocks the trade")
T.eq(save.party[1].species, "EEVEE", "catalogue never performs a trade")
data.field.trades[1] = { give = "LAPRAS", get = "EEVEE" }
T.eq(rows()[1].species, "EEVEE", "cached script analysis still follows replacement trade data")
T.eq(rows()[1].available, false, "replacement requested species updates availability")
save.flags.TRADED = true
T.eq(rows()[1].done, true, "trade remains complete after releasing the received Pokémon")
save.flags.TRADED = nil
handler = { { "jump", "end" }, { "trade", 1, "TRADED" } }
T.eq(#rows(), 0, "unreachable trade is not a checklist objective")
handler = { { "clear_flag", "TRADED" }, { "trade", 1, "TRADED" } }
T.eq(#rows(), 0, "repeatable trade reset is excluded from permanent completion")
handler = { { "trade", 1 } }
T.eq(#rows(), 0, "trade without durable receipt is not guessed")
scripts.talkScript = original

local function nativeRow(id, text)
  return policy:rows(data, save, id, { objects = { { index = 1, text = text, x = 2, y = 3 } } })
end
local dojo = { objects = { { index = 1, text = "TEXT_FIGHTINGDOJO_HITMONLEE_POKE_BALL" },
  { index = 2, text = "TEXT_FIGHTINGDOJO_HITMONCHAN_POKE_BALL" } } }
local function dojoRows() return policy:rows(data, save, "FIGHTING_DOJO", dojo) end
T.eq(#dojoRows(), 2, "both Dojo choices are documented before selection")
T.eq(dojoRows()[1].status, "LATER", "Dojo prize needs the Karate Master's defeat")
save.flags.EVENT_BEAT_KARATE_MASTER = true
T.eq(dojoRows()[1].available, true, "defeated Master unlocks the prize")
save.flags.EVENT_GOT_HITMONLEE = true
T.eq(dojoRows()[1].done, true, "chosen Dojo prize is received")
T.eq(dojoRows()[2].excluded, true, "unchosen Dojo prize cannot block completion")
local function album(pokemon)
  return Progress.build({ { id = "TEST", maps = { "TEST" } } }, function()
    return { sections = { { rows = {} }, { rows = {} }, { rows = {} } }, pokemon = pokemon }
  end, { save = save, mapId = "TEST" }).byId.TEST
end
T.eq(album(dojoRows()).sections[4].total, 1, "exclusive alternative is removed from the Pokémon objective total")
T.eq(album(dojoRows()).sections[4].excluded, 1, "alternative remains documented separately")
T.eq(album(dojoRows()).tier, "gold", "chosen Dojo prize allows gold without collecting both")
save.flags.EVENT_GOT_HITMONLEE = nil
T.eq(album(dojoRows()).tier, "silver", "unreceived gifts prevent gold even without wild encounters")
T.eq(album(dojoRows()).sections[4].total, 1, "Dojo requires one reward even before making the choice")
local states = { { species = "EEVEE", gift = true, order = 133, mapId = "TEST", status = "LATER" },
  { species = "EEVEE", gift = true, order = 133, mapId = "TEST", excluded = true },
  { species = "EEVEE", done = true, order = 133, mapId = "TEST" } }
T.eq(album(states).sections[4].rows[1].state, "later", "gift state is not flattened to uncaught")
T.eq(album(states).sections[4].done, 1, "ordinary wild completion retains its caught semantics")
T.eq(#Progress.visibleRows(album(states), 4, "spoiler"), 3, "same-species objectives sort deterministically")
T.eq(nativeRow("CELADON_MANSION_ROOF_HOUSE", "TEXT_CELADONMANSION_ROOF_HOUSE_EEVEE_POKEBALL")[1].species,
  "EEVEE", "native Eevee ball is tracked as a Pokémon rather than an item")
T.eq(nativeRow("SILPH_CO_7F", "TEXT_SILPHCO7F_SILPH_WORKER_M1")[1].species, "LAPRAS", "native Lapras gift is included")
if version == "yellow" then
  save.pikachuHappiness = 146
  T.eq(nativeRow("CERULEAN_MELANIES_HOUSE", "TEXT_CERULEANMELANIESHOUSE_MELANIE")[1].available,
    false, "Melanie requires actual starter Pikachu happiness")
  save.pikachuHappiness = 147
  T.eq(nativeRow("CERULEAN_MELANIES_HOUSE", "TEXT_CERULEANMELANIESHOUSE_MELANIE")[1].available,
    true, "happiness threshold unlocks Bulbasaur")
  T.eq(nativeRow("VERMILION_CITY", "TEXT_VERMILIONCITY_OFFICER_JENNY")[1].available,
    false, "Jenny requires the Thunder Badge")
  save.inventory.THUNDERBADGE = 1
  T.eq(nativeRow("VERMILION_CITY", "TEXT_VERMILIONCITY_OFFICER_JENNY")[1].available,
    true, "badge unlocks Squirtle")
else
  T.eq(#nativeRow("CERULEAN_MELANIES_HOUSE", "TEXT_CERULEANMELANIESHOUSE_MELANIE"), 0,
    "Yellow-only gifts never leak into Red or Blue")
end

local run = T.sdk.loadMod(root, { generation = 1, data = T.fixtures.fresh() })
T.eq(run.mod and run.mod.state, "loaded", "Gen1 companion loads Pokémon rewards")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local input
for _, entry in ipairs(run.loader.hooks.chains["input.step"]) do
  if entry.owner == "kanto_gear" then input = entry.callback end
end
local display = up(input, "displayRuntime")
local game = { data = run.data, save = { generation = 1, version = version, player = {}, party = {},
  inventory = {}, pokedex = {}, flags = {} } }
game.data.pokemon.EEVEE, game.data.pokemon.LAPRAS = data.pokemon.EEVEE, data.pokemon.LAPRAS
run.loader.events:emit("game.ready", { game = game })
run.loader.modOptions.kanto_gear = { info_level = "spoiler", theme_v3 = "hgss" }
local api = up(display.saveHome, "mod")
local actor = { id = "TEST_obj_1", x = 7, y = 8, visible = true }
api.world = { current = function() return { mapId = "TEST", x = 1, y = 1 } end,
  mapActors = function() return { actor } end }
display.knownMap = function() return true end
display.explorerMethods = function() return {} end
display.explorerWildRows = function() return {} end
local explorer = display.explorer
local assist = up(display.explorerModel, "assist")
local gift = { id = "TEST_gift", actorId = actor.id, mapId = "TEST", index = 1, x = 2, y = 3,
  label = "EEVEE", species = "EEVEE", level = 25, kind = "pokemon", gift = true, available = true }
explorer.data = { mapId = "TEST", at = love.timer.getTime(), guideEnabled = assist("guide"),
  areaEnabled = assist("area"), fruits = {}, guide = { rows = {}, caught = 0 },
  area = { pokemon = { gift }, sections = { { rows = {} }, { rows = {} }, { rows = {} } } } }
local overview = { mapId = "TEST", width = 12, height = 12, rows = {}, markers = {} }
for i = 1, 12 do overview.rows[i] = string.rep(".", 12) end
local function model() explorer.renderModel = nil; return display.explorerModel(overview) end
local m = model()
T.eq(m.rows[1].species, "EEVEE", "HERE NOW gallery includes immediately available NPC Pokémon")
T.eq(m.rows[1].method, "NPC GIFT", "gift has a distinct method rather than a fake encounter chance")
T.eq(m.itemsText, "0/0", "Pokémon gifts never inflate item counts")
T.eq(m.markers[1].kind, "pokemon", "gift marker opens Pokémon rather than item details")
T.eq(m.markers[1].x, 7, "gift marker follows the source NPC's live position")
gift.available, gift.status = false, "LATER"
T.eq(#model().rows, 0, "HERE NOW hides unavailable Pokémon offers")
T.eq(#model().markers, 0, "hidden offer has no orphan touch target")
explorer.filters.wildScope = "ROUTE"
T.eq(#model().rows, 1, "WHOLE ROUTE keeps future gifts in Spoiler mode")
gift.excluded = true
T.eq(#model().markers, 0, "unchosen alternative has no impossible map target")
gift.excluded, gift.status, gift.available, gift.trade, gift.needsSpecies = nil, nil, true, true, "LAPRAS"
T.eq(model().rows[1].needsSpeciesName, "LAPRAS", "trade details resolve the actual requested species name")
explorer.selected = gift.id
T.eq(model().selectedMarker.kind, "pokemon", "gallery selection selects the same NPC marker")
T.eq(model().detailPages, 1, "NPC offer has no misleading habitat pagination")
local H = up(display.drawContents, "THEME").hgss
H:explorer(model())
T.eq(H:explorerHit(195, 112, model()), nil, "static NPC detail cannot act as a habitat page button")
actor.visible = false
T.eq(#model().markers, 0, "live hidden NPC is removed from the map")
explorer.filters.wildScope = "HERE"
T.eq(#model().rows, 0, "live hidden giver is not advertised as immediately available")

-- Gen1 counters are opaque native handlers: validate their audited metadata
-- against the actual handler's menu, without opening an app or changing a save.
do
  local mapId = "GAME_CORNER_PRIZE_ROOM"
  local source = { objects = {}, signs = {
    { text = "TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_1", x = 2, y = 2 },
    { text = "TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_2", x = 4, y = 2 } } }
  local record = { flags = {}, inventory = { COIN_CASE = 1 }, party = {}, coins = 9999, pokedex = { caught = {} } }
  local prizeData = { pokemon = {}, items = {}, text = {} }
  for name in ("ABRA CLEFAIRY NIDORINA NIDORINO DRATINI SCYTHER PINSIR PORYGON VULPIX WIGGLYTUFF"):gmatch("%S+") do
    prizeData.pokemon[name] = { name = name }
  end
  local function prizes() return policy:rows(prizeData, record, mapId, source) end
  T.eq(#prizes(), 6, "native Gen1 prize counters expose six edition-specific caught goals")
  local TextBox, Counter = require("src.render.TextBox"), require("src.ui.PrizeCounter")
  local textNew, counterNew = TextBox.new, Counter.new
  TextBox.new = function(_, text, done, opts) return { text = text, onDone = done, opts = opts } end
  Counter.new = function(_, rows, opts) return { prizes = rows, opts = opts } end
  local nativeRows = {}
  for _, sign in ipairs(source.signs) do
    local game = { data = prizeData, save = record, stack = { states = {},
      push = function(self, value) self.states[#self.states+1] = value end,
      pop = function(self) return table.remove(self.states) end,
      top = function(self) return self.states[#self.states] end } }
    local emitted
    local ow = { runner = { run = function(_, rows) emitted = rows end } }
    scripts.talkScript(mapId, sign.text)(game, ow, nil, function() end)
    game.stack:pop().onDone()
    game.stack:top().opts.stay.onShown()
    local menu = game.stack:top()
    for _, row in ipairs(menu.prizes) do nativeRows[row.prize.species] = row end
    menu.opts.onPick(menu.prizes[1], 1)
    game.stack:pop().opts.choice(true)
    T.eq(emitted[1][1], "give_pokemon", "native transaction gives Pokemon before charging")
    T.eq(emitted[2][1], "jump_if_false", "native delivery failure skips coin charge")
    T.eq(emitted[3][2], menu.prizes[1].cost, "native transaction charges its displayed price")
  end
  TextBox.new, Counter.new = textNew, counterNew
  for _, row in ipairs(prizes()) do
    local actual = assert(nativeRows[row.species], "catalogue invented a prize species")
    T.eq(row.level, actual.prize.level, "catalogue level matches actual edition's native menu")
    T.eq(row.coinCost, actual.cost, "catalogue coin price matches actual edition's native menu")
    T.eq(row.index, nil, "background counter does not impersonate an NPC actor")
    T.eq(row.catchGoal, true, "repeatable native prize has a caught goal")
    T.eq(row.event, nil, "repeatable native prize has no invented receipt")
    record.coins = row.coinCost - 1
    for _, offer in ipairs(prizes()) do if offer.id == row.id then T.eq(offer.available, false, "one coin short blocks immediate prize") end end
    record.coins = row.coinCost
    for _, offer in ipairs(prizes()) do if offer.id == row.id then T.eq(offer.available, true, "exact coins unlock immediate prize") end end
    record.coins = 9999
  end
  record.inventory = {}
  for _, row in ipairs(prizes()) do T.eq(row.available, false, "no Coin Case blocks every prize") end
  record.inventory = { COIN_CASE = 1 }
  record.party, record.boxes = { {}, {}, {}, {}, {}, {} }, {}
  for i=1,Boxes.COUNT do record.boxes[i] = {}; for j=1,Boxes.CAPACITY do record.boxes[i][j] = {} end end
  for _, row in ipairs(prizes()) do T.eq(row.noRoom, true, "full party and storage blocks every prize") end
  record.boxes[Boxes.COUNT] = {}
  for _, row in ipairs(prizes()) do T.eq(row.available, true, "Gen1 prize can overflow into available PC space") end
  record.party = {}
  for _, row in ipairs(prizes()) do record.pokedex.caught[row.species] = true end
  for _, row in ipairs(prizes()) do
    T.eq(row.done, true, "native caught dex completes prize after release")
    T.eq(row.status, "CAUGHT", "prize completion never claims unique receipt")
  end
  T.eq(album(prizes()).tier, "gold", "all caught prize species allow gold")
  local nativeTalk = scripts.talkScript
  scripts.talkScript = function(id, text) if id == mapId then return function() end end; return nativeTalk(id,text) end
  T.eq(#prizes(), 0, "replacement mod handler never inherits unproven native prize metadata")
  scripts.talkScript = nativeTalk
end

local native = os.getenv("KANTO_GEAR_NATIVE_GEN1")
if native then
  local imported = { maps = dofile(native .. "/maps.lua"), items = dofile(native .. "/items.lua"),
    pokemon = dofile(native .. "/pokemon.lua"), field = dofile(native .. "/field.lua") }
  require("src.core.Data").applyVersionedFieldData(imported, version)
  local gifts, trades, events = 0, 0, {}
  for id, source in pairs(imported.maps) do
    for _, row in ipairs(policy:rows(imported, save, id, source)) do
      if row.species then
        if row.trade then trades = trades + 1 else gifts = gifts + 1 end
        events[id .. ":" .. row.species] = row.event
      end
    end
  end
  T.eq(events["CELADON_MANSION_ROOF_HOUSE:EEVEE"], "EVENT_GOT_EEVEE", "native imported Eevee object is tracked")
  T.eq(events["SILPH_CO_7F:LAPRAS"], "EVENT_GOT_LAPRAS", "native imported Lapras NPC is tracked")
  T.eq(events["FIGHTING_DOJO:HITMONLEE"], "EVENT_GOT_HITMONLEE", "native imported Dojo choice is tracked")
  T.eq(events["CINNABAR_LAB_FOSSIL_ROOM:AERODACTYL"], nil, "resetting fossil revival is not guessed as a permanent receipt")
  T.eq(events["ROUTE_18_GATE_2F:" .. imported.field.trades[6].get], "EVENT_TRADED_SLOWBRO_FOR_LICKITUNG",
    "trade slot uses edition-correct species despite its legacy event name")
  print("GEN1_NATIVE_REWARDS", version, gifts, trades)
end
T.finish("Kanto Gear Gen1 Pokémon gifts and trades")
