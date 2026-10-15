package.path = "./?.lua;./?/init.lua;" .. package.path

-- Day-Care runtime: the Gen 1 boarder and the Gen 2 pair read from a live
-- save through the host's own Day-Care rules, and the app draws and routes.
local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 1
local run = T.sdk.loadMod(path, { generation = generation, data = T.fixtures.load() })
T.eq(run.mod and run.mod.state, "loaded", "Kanto Gear loads")
T.eq(#run.errors, 0, "Kanto Gear boots without errors")

local native = generation == 1 and os.getenv("KANTO_GEAR_NATIVE_GEN1")
  or generation == 2 and os.getenv("KANTO_GEAR_NATIVE_GEN2") or nil
local data = run.data
if native then
  data = setmetatable({ pokemon = dofile(native .. "/pokemon.lua"), moves = dofile(native .. "/moves.lua") },
    { __index = run.data })
end

local world = { map = { id = "ROUTE_34" } }
local game = {
  data = data,
  save = {
    generation = generation,
    player = { name = "GOLD", id = 7, map = "ROUTE_34", money = 5000 },
    party = {}, inventory = {}, boxes = {}, currentBox = 1,
    pokedex = { seen = {}, caught = {} },
  },
  world = world,
  stack = { states = { world }, top = function(self) return self.states[#self.states] end },
}
run.loader.events:emit("game.ready", { game = game })

local upvalue = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local inputHook
for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
  if entry.owner == "kanto_gear" then inputHook = entry.callback end
end
local display = upvalue(inputHook, "displayRuntime")
T.check(type(display) == "table" and type(display.daycareModel) == "function", "Day-Care runtime is reachable")

local empty = display.daycareModel()
T.check(empty.empty == true and #empty.parents == 0, "an empty Day-Care reads as empty")
T.eq(empty.headline.kind, "empty", "the widget headline knows nothing is boarding")

local function names(list) return table.concat(list or {}, "|") end

if generation == 1 then
  -- Pokemon left at L12 with 15955 steps: MEDIUM_FAST L12 is 1728 EXP, L27 19683.
  game.save.daycare = { steps = 17955, depositLevel = 12, mon = { species = "PIKACHU", level = 12, exp = 1728,
    moves = { { id = "THUNDERSHOCK" }, { id = "GROWL" }, { id = "THUNDER_WAVE" } } } }
  local model = display.daycareModel()
  local parent = model.parents[1]
  T.eq(model.generation, 1, "Gen 1 boards on Route 5")
  T.eq(parent and parent.levelNow, 27, "steps are folded into the level the man would report")
  T.eq(parent and parent.fee, 1600, "the fee is 100 plus 100 per level grown")
  T.check(model.compatibility == nil and model.egg == nil, "Gen 1 makes no eggs")
  if native then
    T.eq(names(parent.learned), data.moves.QUICK_ATTACK.name .. "|" .. data.moves.SWIFT.name,
      "Quick Attack and Swift are learned at pickup")
    T.eq(names(parent.forgotten), data.moves.THUNDERSHOCK.name, "the oldest move is overwritten")
    T.eq(#parent.after, 4, "four moves come back")
  end
  T.eq(model.headline.kind, "boarding", "a boarder without eggs is the headline")
end

if generation == 2 then
  local marill = { species = "MARILL", level = 19, experience = 6859 + 4000, otId = 12345,
    dvs = { attack = 15, defense = 9, speed = 12, special = 5 }, moves = { { id = "TACKLE" } } }
  local totodile = { species = "TOTODILE", level = 22, experience = 9000, otId = 7,
    dvs = { attack = 0, defense = 4, speed = 3, special = 2 }, moves = { { id = "SCRATCH" } } }
  game.save.dayCare = { man = { mon = marill }, lady = { mon = totodile }, compatible = true,
    stepsToEgg = 98, hasEgg = false,
    egg = { species = "TOTODILE", isEgg = true, moves = { { id = "SCRATCH" }, { id = "LEER" }, { id = "SURF" } } } }
  game.save.party = { { species = "TOGEPI", isEgg = true, eggSteps = 3, level = 5 } }
  game.save.stepCount = 100
  local model = display.daycareModel()
  T.eq(#model.parents, 2, "both boarders are listed")
  T.eq(model.parents[1].key, "man", "the man's boarder comes first")
  T.check(model.parents[1].levelNow >= model.parents[1].levelFrom, "a boarder never loses levels")
  T.eq(model.fees, model.parents[1].fee + model.parents[2].fee, "fees add up")
  T.eq(#model.eggs, 1, "party eggs are listed")
  T.eq(model.eggs[1].stageLabel, "HATCHES SOON", "a three-cycle egg is about to hatch")
  if native then
    T.eq(model.parents[1].gender, "male", "Marill's attack DV makes it male")
    T.eq(model.parents[2].gender, "female", "Totodile's attack DV makes it female")
    T.eq(model.compatibility and model.compatibility.tier, 2, "different species from different trainers get along")
    local policy = display.discoveryPolicy()
    if policy.daycare_odds then
      T.eq(model.compatibility.chance, 12, "30/256 is shown as 12%")
      T.eq(model.egg and model.egg.stepsToCheck, 98, "the countdown byte is the next egg check")
    end
  end
  T.eq(model.headline.kind, "hatching", "a hatching egg leads the widget")
  game.save.dayCare.hasEgg, game.save.party = true, {}
  T.eq(display.daycareModel().headline.kind, "egg_waiting", "a waiting egg leads the widget")
end

-- The app opens, draws and routes its tabs without errors.
local catalog = display.homeCatalog
catalog.packages.daycare.installed = true
T.check(display.openHomeApp("daycare"), "the installed Day-Care app opens")
local ok, err = pcall(display.drawDaycare)
T.check(ok, "the Day-Care page draws: " .. tostring(err))
if generation == 2 then
  display.tapDaycare(180, 40)
  T.eq(display.daycare.view, "eggs", "the Eggs tab opens the party eggs")
  display.drawDaycare()
  display.tapDaycare(60, 40)
  T.eq(display.daycare.view, nil, "the Day-Care tab returns to the pair")
  display.drawDaycare()
  display.tapDaycare(60, 70)
  T.eq(display.daycare.view, "parent", "a boarder card opens its moves")
  display.drawDaycare()
  display.tapDaycare(10, 10)
  T.eq(display.daycare.view, nil, "Back from a boarder returns to the pair")
  display.tapDaycare(10, 10)
  T.eq(display.session.page, "HOME", "Back from the app returns Home")
end

-- Six eggs are a valid party; the final egg must not disappear below the screen.
local theme = upvalue(display.drawDaycare, "THEME").hgss
local eggModel = { generation = 2, view = "eggs", parents = {}, eggs = {} }
for i = 1, 6 do eggModel.eggs[i] = { slot = i, mon = { slot = i }, stage = 2 } end
local drawn = {}
eggModel.drawPokemon = function(mon, x, y, size)
  T.check(y >= 56 and y + size <= 212, "egg icon stays inside the screen")
  drawn[mon.slot] = true
end
theme:daycare(eggModel)
for i = 1, 6 do T.check(drawn[i], "party egg is visible: " .. i) end

T.finish("Day-Care runtime")
