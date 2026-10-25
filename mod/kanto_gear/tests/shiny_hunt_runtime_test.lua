package.path = "./?.lua;./?/init.lua;" .. package.path

-- Shiny Hunt runtime: Gen 1 hides the app; Gen 2 counts wild battles and
-- hatches from the host's own events, reads shininess from DVs, survives a
-- rebind from durable storage, and draws and routes every page.
local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 1
local run = T.sdk.loadMod(path, { generation = generation, data = T.fixtures.load() })
T.eq(run.mod and run.mod.state, "loaded", "Kanto Gear loads")
T.eq(#run.errors, 0, "Kanto Gear boots without errors")

local native = generation == 2 and os.getenv("KANTO_GEAR_NATIVE_GEN2") or nil
local data = run.data
if native then
  data = setmetatable({ pokemon = dofile(native .. "/pokemon.lua"), moves = dofile(native .. "/moves.lua") },
    { __index = run.data })
end

local world = { map = { id = "ROUTE_29" } }
local game = {
  data = data,
  save = {
    generation = generation, version = generation == 2 and "crystal" or "red",
    meta = { playthroughId = "shiny-test" },
    player = { name = "GOLD", id = 7, map = "ROUTE_29", money = 5000 },
    party = {}, inventory = {}, boxes = {}, currentBox = 1,
    pokedex = { seen = {}, caught = {} },
  },
  world = world,
  stack = { states = { world }, top = function(self) return self.states[#self.states] end },
}
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", display_mode = "separate", display_target = "secondary" }

local upvalue = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local inputHook
for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
  if entry.owner == "kanto_gear" then inputHook = entry.callback end
end
local display = upvalue(inputHook, "displayRuntime")
T.check(type(display) == "table" and type(display.shinyHuntModel) == "function", "Shiny Hunt runtime is reachable")

-- Durable storage stands in for the host's playthrough storage.
local stored, writes = {}, 0
local mod = upvalue(display.bindShinyHunt, "mod")
mod.storage = {
  read = function(_, _, key) return stored[key] end,
  write = function(_, _, key, value) stored[key] = value; writes = writes + 1; return true end,
}
run.loader.events:emit("game.ready", { game = game })

local catalog, store = display.homeCatalog, display.storeById
if generation == 1 then
  T.check(not display.shinyHuntSupported(), "Gen 1 has no shiny Pokemon")
  T.check(store.shiny.hidden == true and store.shiny.available == false, "the Store hides Shiny Hunt in Gen 1")
  T.check(display.storeWidgetSummary().label ~= "SHINY HUNT", "Gen 1 never promotes Shiny Hunt")
  T.check(catalog.surfaces.shiny_widget.hidden and catalog.surfaces.shiny_small_widget.hidden
    and catalog.surfaces.shiny_app.hidden, "Home offers no Shiny Hunt surfaces in Gen 1")
  local before = writes
  run.loader.events:emit("battle.started", { kind = "wild",
    battle = { enemy = { species = "PIDGEY", dvs = { attack = 10, defense = 10, speed = 10, special = 10 } } } })
  T.eq(writes, before, "Gen 1 battles are not observed")
  T.finish("Shiny Hunt runtime")
  return
end

T.check(display.shinyHuntSupported(), "Gen 2 supports Shiny Hunt")
T.check(not store.shiny.hidden and store.shiny.available ~= false, "the Store lists Shiny Hunt")
T.eq(display.storeWidgetSummary().label, "SHINY HUNT", "the Store widget promotes the new app")
T.check(display.setPackageInstalled("shiny", true), "Shiny Hunt installs from the Store")

-- Opening without a hunt goes straight to the picker.
T.check(display.openHomeApp("shiny"), "the installed app opens")
T.eq(display.session.page, "SHINY", "the Shiny Hunt page is shown")
T.eq(display.shinyHunt.view, "pick", "a first visit starts by picking a target")
local ok, err = pcall(display.drawShinyHunt)
T.check(ok, "the picker draws: " .. tostring(err))
local pick = display.shinyHunt.pick
T.check(pick and pick.rows[1] and pick.rows[1].any, "Any Pokemon leads the picker")

local function dvs(attack, defense, speed, special)
  return { attack = attack, defense = defense, speed = speed, special = special }
end
local function wild(species, shiny, extra)
  local mon = { species = species, level = 3, dvs = shiny and dvs(10, 10, 10, 10) or dvs(1, 2, 3, 4) }
  for k, v in pairs(extra or {}) do mon[k] = v end
  return mon
end
local function battle(mon, kind)
  run.loader.events:emit("battle.started", { kind = kind or "wild", battle = { enemy = mon } })
  run.loader.events:emit("battle.ended", { battle = { enemy = mon }, result = "run" })
end

-- Start hunting Pidgey from the picker's "last met" row after one battle.
battle(wild("PIDGEY"))
T.eq(display.shinyHunt.data.last and display.shinyHunt.data.last.species, "PIDGEY", "the last wild Pokemon is remembered")
display.shinyHuntAction("view", "pick")
display.drawShinyHunt()
local lastRow
for index, row in ipairs(display.shinyHunt.pick.rows) do
  if row.section == "LAST MET" then lastRow = index end
end
T.check(lastRow ~= nil, "the picker offers the last Pokemon met")
T.check(display.shinyHuntAction("target", lastRow), "picking a row starts its hunt")
T.eq(display.shinyHunt.data.active, "PIDGEY", "Pidgey is the target")
T.eq(display.shinyHunt.view, nil, "the hunt page returns after picking")

local mon = wild("PIDGEY")
run.loader.events:emit("battle.started", { kind = "wild", battle = { enemy = mon } })
-- Gen 2 raises the start from the engine and from its screen: one battle.
run.loader.events:emit("battle.started", { kind = "wild", battle = { battle = { enemy = mon } } })
run.loader.events:emit("battle.started", { kind = "wild", battle = { enemy = wild("PIDGEY") } })
local model = display.shinyHuntModel()
T.eq(model.hunt.count, 1, "one wild battle is one encounter")
run.loader.events:emit("battle.ended", { battle = { enemy = mon }, result = "run" })
run.loader.events:emit("battle.started", { kind = "wild", battle = { enemy = mon } })
T.eq(display.shinyHuntModel().hunt.count, 2, "a later battle counts even if the native enemy table is reused")
run.loader.events:emit("battle.ended", { battle = { enemy = mon }, result = "run" })
display.ShinyHunt.active(display.shinyHunt.data).battles = 1
battle(wild("RATTATA"))
model = display.shinyHuntModel()
T.eq(model.hunt.count, 1, "another species does not count for the target")
T.eq(model.hunt.others, 1, "it is kept as another encounter")
battle(wild("PIDGEY"), "trainer")
T.eq(display.shinyHuntModel().hunt.count, 1, "trainer battles are not counted")

-- Pending fallback: a start without an enemy resolves from the snapshot.
run.loader.events:emit("battle.started", { kind = "wild", battle = {} })
display.shinyObserveSnapshot({ kind = "wild", enemy = wild("PIDGEY") })
T.eq(display.shinyHuntModel().hunt.count, 2, "a late snapshot resolves the encounter")
display.shinyObserveSnapshot({ kind = "wild", enemy = wild("PIDGEY") })
T.eq(display.shinyHuntModel().hunt.count, 2, "a resolved encounter is not counted again")

-- Draw and route the main page: +1, -1 and the auto switch.
display.shinyHuntAction("view", "hunt")
ok, err = pcall(display.drawShinyHunt)
T.check(ok, "the hunt page draws: " .. tostring(err))
local theme = upvalue(display.drawShinyHunt, "THEME").hgss
T.eq(theme:shinyHuntHit(120, 150), "plus", "the wide key is +1")
T.eq(theme:shinyHuntHit(20, 150), "minus", "the left key is -1")
T.eq(theme:shinyHuntHit(210, 150), "auto", "the right key switches automatic counting")
T.eq(theme:shinyHuntHit(120, 90), "pick", "the target card changes the target")
display.tapShinyHunt(120, 150)
T.eq(display.shinyHuntModel().hunt.count, 3, "+1 adds a manual roll")
display.drawShinyHunt()
display.tapShinyHunt(20, 150)
T.eq(display.shinyHuntModel().hunt.count, 2, "-1 takes it back")
display.drawShinyHunt()
display.tapShinyHunt(210, 150)
T.check(display.shinyHuntModel().auto == false, "automatic counting pauses")
battle(wild("PIDGEY"))
T.eq(display.shinyHuntModel().hunt.count, 2, "a paused hunt does not count")
display.drawShinyHunt()
display.tapShinyHunt(210, 150)
T.check(display.shinyHuntModel().auto == true, "automatic counting resumes")

-- Tabs: Odds and Log draw.
display.drawShinyHunt()
display.tapShinyHunt(120, 40)
T.eq(display.shinyHunt.view, "odds", "the Odds tab opens")
ok, err = pcall(display.drawShinyHunt)
T.check(ok, "the odds page draws: " .. tostring(err))
display.tapShinyHunt(200, 40)
T.eq(display.shinyHunt.view, "log", "the Log tab opens")
ok, err = pcall(display.drawShinyHunt)
T.check(ok, "the log page draws: " .. tostring(err))

-- A phase, then the find (Gen 2 DV pattern without a host flag).
battle(wild("SENTRET", true))
model = display.shinyHuntModel()
T.eq(model.hunt.phases, 1, "an off-target shiny is a phase")
T.eq(model.log[1].kind, "phase", "the phase is logged")
battle(wild("PIDGEY", true))
model = display.shinyHuntModel()
T.check(model.hunt.found ~= nil, "a shiny Pidgey ends the hunt")
T.eq(model.hunt.found.count, 3, "the find counts its own encounter")
T.eq(model.headline.kind, "found", "the widgets lead with the find")
battle(wild("PIDGEY", false, { shiny = true }))
T.eq(display.shinyHuntModel().hunt.count, 3, "a finished hunt stops counting")
display.shinyHuntAction("view", "hunt")
ok, err = pcall(display.drawShinyHunt)
T.check(ok, "the find draws: " .. tostring(err))
T.eq(theme:shinyHuntHit(60, 186), "again", "Hunt again is offered")
T.eq(theme:shinyHuntHit(180, 186), "pick", "a new target is offered")
display.tapShinyHunt(60, 186)
T.eq(display.shinyHuntModel().hunt.count, 0, "Hunt again starts from zero")

-- Eggs: a shiny Ditto at the Day-Care boosts the hatch to 1 in 64.
display.shinyHuntAction("view", "pick")
display.drawShinyHunt()
local Hunt = display.ShinyHunt
Hunt.setTarget(display.shinyHunt.data, "TOGEPI", "TOGEPI", os.time())
game.save.dayCare = { man = { mon = { species = "DITTO", level = 20, dvs = dvs(10, 10, 10, 10) } },
  lady = { mon = { species = "TOGETIC", level = 20, dvs = dvs(4, 4, 4, 4) } } }
game.save.party = { { species = "TOGEPI", level = 5, dvs = dvs(7, 3, 9, 1) } }
run.loader.events:emit("egg.hatched", { slot = 1, species = "TOGEPI" })
local hunt = Hunt.active(display.shinyHunt.data)
T.eq(hunt.boosted, 1, "a hatch beside a shiny Ditto rolls at 1 in 64")
T.check(display.shinyBreedingBoost() and display.shinyBreedingBoost().ditto, "the Odds page names the shiny Ditto")
game.save.dayCare = nil
run.loader.events:emit("egg.hatched", { slot = 1, species = "TOGEPI" })
T.eq(hunt.hatches, 1, "a plain hatch rolls at full odds")
game.save.party[1].dvs = dvs(10, 10, 10, 10)
run.loader.events:emit("egg.hatched", { slot = 1, species = "TOGEPI" })
T.check(hunt.found ~= nil and display.shinyHuntModel().hunt.method == "EGGS", "a shiny hatchling ends an egg hunt")
display.shinyHuntAction("view", "odds")
ok, err = pcall(display.drawShinyHunt)
T.check(ok, "an egg hunt's odds draw: " .. tostring(err))

-- Durable storage: a rebind (title screen, soft reset) restores everything.
local before = Hunt.normalize(display.shinyHunt.data)
display.bindShinyHunt()
local after = display.shinyHunt.data
T.eq(after.active, before.active, "the active hunt survives a rebind")
T.eq(Hunt.count(after.hunts.PIDGEY), 0, "Pidgey's restarted counter survives")
T.eq(#after.log, #before.log, "the shiny log survives")
T.check(stored["shiny/state"] ~= nil, "the hunt lives in playthrough storage")

-- The log lists finds and lets a shelved hunt with a count resume.
display.shinyHunt.data.hunts.PIDGEY.manual = 4
display.shinyHuntAction("view", "log")
display.drawShinyHunt()
local resumed = false
for _, hit in ipairs(theme.shinyHits or {}) do
  if hit.action == "resume" and hit.value == "PIDGEY" then resumed = display.shinyHuntAction("resume", hit.value) end
end
T.check(resumed and display.shinyHunt.data.active == "PIDGEY", "a shelved hunt resumes from the log")

-- Home widgets draw in every state.
local tile = { id = "shiny_widget", kind = "widget", widget = "shiny", column = 1, row = 1, columns = 12 }
local smallTile = { id = "shiny_small_widget", kind = "widget", widget = "shiny_small", column = 1, row = 2, columns = 5 }
for _, label in ipairs({ "hunting", "found", "idle" }) do
  if label == "found" then battle(wild("PIDGEY", true)) end
  if label == "idle" then Hunt.clearTarget(display.shinyHunt.data) end
  local homeModel = { shiny = display.shinyHuntModel() }
  ok, err = pcall(theme.homeShinyHunt, theme, homeModel, tile, false)
  T.check(ok, "the wide widget draws while " .. label .. ": " .. tostring(err))
  ok, err = pcall(theme.homeShinyHuntSmall, theme, homeModel, smallTile, false)
  T.check(ok, "the small widget draws while " .. label .. ": " .. tostring(err))
end

-- A lucky shiny without a hunt remembers its place and greets the idle widget.
Hunt.clearTarget(display.shinyHunt.data)
display.session.mapId = "ROUTE_29"
battle(wild("HOOTHOOT", true))
local luckyView = display.shinyHuntModel()
T.eq(luckyView.log[1].kind, "lucky", "a shiny without a hunt is luck")
T.check(type(luckyView.log[1].place) == "string" and luckyView.log[1].place ~= "", "the lucky shiny remembers the place")
T.check(luckyView.lucky ~= nil, "the idle widget shows the lucky shiny")
ok, err = pcall(theme.homeShinyHunt, theme, { shiny = luckyView }, tile, false)
T.check(ok, "the lucky wide widget draws: " .. tostring(err))
ok, err = pcall(theme.homeShinyHuntSmall, theme, { shiny = luckyView }, smallTile, false)
T.check(ok, "the lucky small widget draws: " .. tostring(err))
local firsts = 0
for _, entry in ipairs(luckyView.log) do if entry.first then firsts = firsts + 1 end end
T.eq(firsts, 1, "exactly one shiny is the first")

-- Back returns Home.
display.shinyHuntAction("view", "hunt")
display.tapShinyHunt(10, 10)
T.eq(display.session.page, "HOME", "Back from the app returns Home")

T.finish("Shiny Hunt runtime")
