-- Native, edition-specific NPC trade receipts, without running a game or trade scene.
local root, cacheRoot = assert(os.getenv("KANTO_GEAR_MOD_PATH")), assert(os.getenv("POKEPORT_GBA_CACHE"))
local edition = assert(os.getenv("POKEPORT_VERSION"))
require("src.core.GameVersion").set(edition)
require("src.import.gba.versions").select(edition)
local Dataset = require("src.core.game3.dataset")
Dataset.cacheRootOverride = cacheRoot
Dataset.mountExtractRoots()
local P = require("src.core.game3.pokemon")
P.install(Dataset.cache())
require("src.core.game3.items_data").install(Dataset.cache())
local Schema = require("src.core.game3.save_schema_firered")
local session = Schema.newGame({ version = edition, name = "TRADES", rngSeed = 12345 })
local raw = { generation = 3, phase = "field", session = session,
  save = Schema.toSaveTable(session), data = { maps = Dataset.buildMaps(),
    gen3Encounters = dofile(cacheRoot .. "/encounters.lua") } }
require("src.core.game3.runtime").session = session
require("src.mods.Gen3Compat").bind(function() return raw end)
local adapter = assert(loadfile(root .. "/tests/support/module.lua"))()(root, "adapters/gen3/init").new(raw)
local Space, Flags = adapter.Space, adapter.Flags
Space.bundle = { scripts = dofile(cacheRoot .. "/scripts/scripts.lua"),
  events = dofile(cacheRoot .. "/scripts/events.lua"), text = dofile(cacheRoot .. "/scripts/text.lua") }
Space.active = false
local Model = assert(loadfile(root .. "/tests/support/module.lua"))()(root, "adapters/gen3/progress")
local model = Model.new(adapter)
local Trade = require("src.core.game3.scripting.natives_trade")
local Progress = dofile(root .. "/features/achievements.lua")
local Json = require("src.import.canonical_json")
local checks = 0
local function check(ok, why) assert(ok, why); checks = checks + 1 end
local function find(rows, id) for _, row in ipairs(rows) do if row.tradeId == id then return row end end end
local function live(map, id) return assert(find(model:rows({ map })[4], id)) end
local function flag(id, value) Flags.setFlag(session, nil, id, value == true) end
local before = Json.encode(Schema.toSaveTable(session))
local offers, ids, receipts = {}, {}, {}
for map in pairs(raw.data.maps) do
  for _, source in ipairs(model:catalog(map)[4]) do
    if source.trade then
      local entry = Trade.entry(source.tradeId)
      check(not ids[source.tradeId] and not receipts[source.event], "one native NPC and receipt per offer")
      ids[source.tradeId], receipts[source.event] = true, true
      check(source.species == entry.species and source.needsSpecies == entry.requestedSpecies,
        "received and requested species match this edition's imported table")
      offers[#offers + 1] = { map = map, source = source }
    end
  end
end
check(#offers == (edition == "emerald" and 4 or 9), "all native NPC trades are proven")
check(Json.encode(Schema.toSaveTable(session)) == before, "catalogue never mutates save or RNG")
local builds = model.builds
for _, offer in ipairs(offers) do
  local map, source = offer.map, offer.source
  flag(source.event, false)
  session.party = {}
  session.storage.boxes[1].mons[1] = { species = source.needsSpecies, level = 20 }
  adapter:refresh()
  adapter.save.pokedex.caught[source.species] = true
  check(not live(map, source.tradeId).done, "caught elsewhere does not complete this NPC trade")
  check(not live(map, source.tradeId).available, "a partner stored in the PC does not unlock HERE NOW")
  session.storage.boxes[1].mons[1] = nil
  session.party = { { species = source.needsSpecies, isEgg = true, level = 20 } }
  check(not live(map, source.tradeId).available, "an egg cannot be offered as its hidden species")
  session.party = { { species = source.species, level = 20 } }
  check(not live(map, source.tradeId).available, "wrong species does not unlock trade")
  session.party = { { species = source.needsSpecies, level = 20 } }
  check(live(map, source.tradeId).available, "requested species in the party unlocks trade")
  for i = 2, 6 do session.party[i] = { species = 1, level = 5 } end
  check(live(map, source.tradeId).available, "full party is valid because the trade replaces its partner")
  flag(source.event, true)
  session.party = {}
  check(live(map, source.tradeId).done and not live(map, source.tradeId).available,
    "receipt remains complete after releasing or depositing the received Pokemon")
  local goals = model:pokemon({ map })
  check(find(goals, source.tradeId).done, "Stamps use the same receipt as Explorer")
  local area = Progress.build({ { id = map, name = map, maps = { map } } }, function(maps)
    local r = model:rows(maps)
    return { sections = { { rows = r[1] }, { rows = r[2] }, { rows = r[3] } }, pokemon = model:pokemon(maps) }
  end, { save = adapter.save, gen3 = true, mapId = map }).areas[1]
  check(find(area.sections[4].rows, source.tradeId).state == "done", "stamp classifies acquired trade as done")
  flag(source.event, false)
  check(not live(map, source.tradeId).done, "loading older progress restores the unfinished trade")
  before = Json.encode(Schema.toSaveTable(session))
  model:rows({ map }); model:pokemon({ map })
  check(Json.encode(Schema.toSaveTable(session)) == before, "live reads do not give, swap or generate Pokemon")
end
check(model.builds == builds, "warm trade reads never rebuild native catalogues")
local entry = Trade.entry(2)
if edition ~= "emerald" then
  check(entry.species == (edition == "firered" and 29 or 32), "FR/LG Nidoran offers differ correctly")
  check(Trade.entry(5).requestedSpecies == (edition == "firered" and 55 or 80), "FR/LG Lickitung partners differ correctly")
end

-- A helper that only describes an offer cannot prove the actual trade happened.
local sceneId = edition == "emerald" and model.constants:special("DoInGameTradeScene") or 254
local scripts = { main = { { op = "setvar", var = 0x8008, value = 0 },
  { op = "checkflag", flag = 700 }, { op = "goto_if", cond = 1, target = "done" },
  { op = "call", target = "scene" }, { op = "setflag", flag = 700 }, { op = "end" } },
  scene = { { op = "special", id = sceneId }, { op = "return" } }, done = { { op = "end" } } }
local function catalog()
  local rows, vars = Model.scan(scripts, "main")
  return model:trades(scripts, "main", rows, vars)
end
check(#catalog() == 1, "receipt follows a returning trade helper")
scripts.scene[2].op = "end"
check(#catalog() == 0, "ending helper cannot reach caller's receipt")
scripts.scene[2].op = "return"
scripts.main[5].flag = 701
check(#catalog() == 0, "unrelated story flag cannot stand in for trade receipt")
scripts.main[5].flag = 700
table.insert(scripts.main, 1, { op = "clearflag", flag = 700 })
check(#catalog() == 0, "resetting a receipt does not prove a one-time trade")
table.remove(scripts.main, 1)
table.insert(scripts.main, 1, { op = "setvar", var = 0x8008, value = 1 })
check(#catalog() == 0, "ambiguous trade IDs cannot be attached to one receipt")
table.remove(scripts.main, 1)
scripts.scene[1].id = sceneId - 2
check(#catalog() == 0, "species-info special is not a completed trade")
scripts.scene[1].id = sceneId
table.insert(scripts.main, 1, { op = "goto_if", cond = 0, target = "done" })
table.insert(scripts.main, 1, { op = "checkflag", flag = 710 })
local original = Space.bundle
Space.bundle = { scripts = scripts, events = { TEST = { objects = {
  { localId = 1, x = 2, y = 3, flag = 711, scriptKey = "main" } } } } }
session.party = { { species = Trade.entry(0).requestedSpecies, level = 20 } }
flag(700, false); flag(710, false); flag(711, false)
check(not live("TEST", 0).available, "other live story flags can block an otherwise valid trade")
flag(710, true)
check(live("TEST", 0).available, "satisfying the live story guard unlocks the offer")
flag(711, true)
check(not live("TEST", 0).available, "a hidden NPC cannot offer a trade HERE NOW")
flag(700, true)
check(live("TEST", 0).done, "hiding the NPC never undoes an actual trade receipt")
Space.bundle = original

local T = require("tests.modkit")
love.graphics.arc = love.graphics.arc or function() end
raw.data.gen3Pokemon = require("src.core.game3.pokemon")
raw.data.gen3Moves = require("src.core.game3.battle.moves")
raw.data.gen3Items = require("src.core.game3.items_data")
local run = T.sdk.loadMod(root, { generation = 3, data = raw.data })
check(run.mod and run.mod.state == "loaded", "native companion loads trade integration")
setmetatable(raw, { __index = require("src.core.Game3") })
run.loader.game = raw
run.loader.events:emit("game.ready", { game = raw })
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local display
for _, hook in ipairs(run.loader.hooks.chains["input.step"]) do
  if hook.owner == "kanto_gear" then display = up(hook.callback, "displayRuntime") end
end
run.loader.modOptions.kanto_gear = { info_level = "spoiler", theme_v3 = "hgss" }
for _, offer in ipairs(offers) do
  session.map = offer.map
  session.party = { { species = offer.source.needsSpecies, level = 20 } }
  display.gen3:refresh()
  display.gen3Progress.adapter.Space.bundle = Space.bundle
  local area = up(display.achievementData, "areaData")({ offer.map }, true)
  check(find(area.pokemon, offer.source.tradeId).available, "shared area forwards ready native trades to Explorer")
  display.knownMap = function() return true end
  display.explorerMethods = function() return {} end
  display.explorerWildRows = function() return {} end
  local explorer = display.explorer
  explorer.view, explorer.filters.wildScope = "wild", "HERE"
  local overview = { mapId = offer.map, width = 16, height = 16, rows = {}, markers = {} }
  for y = 1, 16 do overview.rows[y] = string.rep(".", 16) end
  local function explorerModel()
    explorer.data, explorer.renderModel = nil, nil
    return display.explorerModel(overview)
  end
  local function explorerTrade()
    local model = explorerModel()
    for page = 1, model.pages do
      explorer.page = page
      local row = find(explorerModel().rows, offer.source.tradeId)
      if row then return row end
    end
  end
  local presented = assert(explorerTrade())
  check(presented.method == "NPC TRADE" and presented.needsSpeciesName == adapter.data.pokemon[offer.source.needsSpecies].name,
    "Explorer presents the requested species and trade context")
  session.party = {}
  display.gen3:refresh()
  check(not explorerTrade(), "HERE NOW removes the offer after its partner leaves the party")
  explorer.filters.wildScope = "ROUTE"
  check(explorerTrade(), "WHOLE ROUTE retains unavailable trade in Spoiler mode, including later pages")
end
if _G.KANTO_GEAR_RENDER_CAPTURE then _G.KANTO_GEAR_RENDER_CAPTURE(run, display, raw, offers[1]) end
print("GEN3_NATIVE_TRADES", edition, #offers)
print(checks .. " checks passed")
