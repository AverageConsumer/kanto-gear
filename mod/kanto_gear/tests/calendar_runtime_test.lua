package.path = "./?.lua;./?/init.lua;" .. package.path

-- Calendar runtime: Gen 2 weekly visitors, phone rematches and daily extras
-- read from the imported scripts and the live flags; Gen 1 has no calendar.
local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 1
local run = T.sdk.loadMod(path, { generation = generation, data = T.fixtures.load() })
T.eq(run.mod and run.mod.state, "loaded", "Kanto Gear loads")
T.eq(#run.errors, 0, "Kanto Gear boots without errors")

local native = generation == 2 and os.getenv("KANTO_GEAR_NATIVE_GEN2") or nil
local data = run.data
if native then
  data = setmetatable({ gen2Maps = dofile(native .. "/maps.lua"), gen2Scripts = dofile(native .. "/scripts.lua"),
    gen2Constants = dofile(native .. "/constants.lua"), gen2EventTables = dofile(native .. "/events.lua"),
    items = dofile(native .. "/items.lua"), pokemon = dofile(native .. "/pokemon.lua"),
    gen2Trainers = dofile(native .. "/trainers.lua") }, { __index = run.data })
end
local events, flags = {}, {}
local world = { map = { id = "ROUTE_36" }, tod = "NITE",
  weekday = function() return 4 end, hour = function() return 21 end,
  engineFlag = function(_, id) return flags[id] == true end,
  events = { get = function(_, id) return events[id] == true end } }
local game = {
  data = data,
  save = { generation = generation, version = "crystal",
    player = { name = "KRIS", id = 7, map = "ROUTE_36", money = 5000 },
    party = {}, inventory = {}, boxes = {}, currentBox = 1, engineFlags = {},
    pokedex = { seen = {}, caught = {} }, phoneContacts = {} },
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
T.check(type(display) == "table" and type(display.calendarModel) == "function", "Calendar runtime is reachable")

if generation == 1 then
  T.check(display.calendarModel().unsupported, "Gen 1 has no calendar")
  T.check(display.storeById.calendar.hidden == true, "the Store does not offer it in Gen 1")
end

if generation == 2 and native then
  T.check(not display.storeById.calendar.hidden, "Gen 2 offers the calendar")
  local function find(list, kind, title)
    for _, row in ipairs(list) do
      if row.kind == kind and (not title or row.title == title) then return row end
    end
  end
  local model = display.calendarModel()
  T.eq(model.weekday, 4, "the game's weekday is used")
  local arthur = find(model.today, "gift")
  T.check(arthur ~= nil and arthur.mapId == "ROUTE_36", "Thursday's sibling stands on Route 36")
  T.eq(arthur and arthur.title, data.items.HARD_STONE.name, "Arthur's gift is read from his script")
  T.check(find(model.days[5], "wild") ~= nil, "Lapras surfaces in Union Cave on Fridays")
  T.check(find(model.days[2], "contest") and find(model.days[4], "contest") and find(model.days[6], "contest"),
    "the Bug-Catching Contest runs Tuesday, Thursday and Saturday")
  T.check(not find(model.days[1], "contest"), "no contest on Mondays")
  T.check(find(model.days[1], "shop") ~= nil, "Monday's morning merchant remains scheduled when viewed at night")
  local sundayGift
  for _, row in ipairs(model.days[0]) do if row.mapId == "GOLDENROD_DEPT_STORE_5F" then sundayGift = row end end
  T.check(sundayGift ~= nil, "the Sunday TM receptionist is listed")
  -- Tuscany waits for the Zephyr Badge (her callback checks it).
  T.check(not find(model.days[2], "gift"), "Tuscany stays away before the Zephyr Badge")

  -- Joey registered: Monday afternoon is his call window; ready flags lead.
  game.save.phoneContacts = { [15] = true }
  display.invalidateCalendar()
  local order = data.gen2Constants.engineFlagOrder
  local function engine(name)
    for index, flag in ipairs(order) do if flag == name then return index - 1 end end
  end
  model = display.calendarModel()
  local call
  for _, row in ipairs(model.days[1]) do if row.kind == "call" then call = row end end
  T.check(call ~= nil and call.title == "JOEY", "Joey's call window is on Monday")
  T.eq(call and call.when and call.when[1], "AFTERNOON", "Joey answers for a rematch in the afternoon")
  flags[engine("ENGINE_JOEY_READY_FOR_REMATCH")] = true
  game.save.engineFlags[engine("ENGINE_JOEY_READY_FOR_REMATCH")] = true
  display.invalidateCalendar()
  model = display.calendarModel()
  T.check(find(model.now, "rematch", "JOEY") ~= nil, "a ready rematch is listed under now")
  T.check(find(model.now, "gift") ~= nil, "Arthur is open tonight")

  game.save.phoneContacts[21] = true
  flags[engine("ENGINE_GINA_HAS_LEAF_STONE")] = true
  display.invalidateCalendar()
  local gift = find(display.calendarModel().now, "phone_gift")
  T.check(gift and gift.title == data.items.LEAF_STONE.name and gift.trainer == "GINA",
    "Gina's waiting gift is separate from a rematch")
  flags[engine("ENGINE_GOLDENROD_UNDERGROUND_GOT_HAIRCUT")] = true
  display.invalidateCalendar()
  T.eq(find(display.calendarModel().today, "haircut").state, "done", "a haircut already used today is complete")
  T.eq(find(display.calendarModel().now, "haircut"), nil, "a used daily service is not ready again")

  -- Policy: without the schedule, unvisited places stay out.
  display.storeById.calendar.hidden = false
end

display.homeCatalog.packages.calendar.installed = true
if generation == 2 then
  T.check(display.openHomeApp("calendar"), "the installed Calendar opens")
  local ok, err = pcall(display.drawCalendar)
  T.check(ok, "the Calendar page draws: " .. tostring(err))
  display.tapCalendar(6 + 5 * 33 + 10, 40)
  T.eq(display.calendar.day, 5, "tapping Friday opens Friday")
  display.drawCalendar()
  display.tapCalendar(60, 75)
  T.eq(display.calendar.view, "detail", "a row opens its details")
  ok, err = pcall(display.drawCalendar)
  T.check(ok, "the detail draws: " .. tostring(err))
  display.tapCalendar(10, 10)
  T.eq(display.calendar.view, nil, "Back returns to the day")
end

-- A morning-only weekly service is scheduled at night, with an honest status.
local C = display.Calendar
local env = { weekday = 1, period = "NITE", policy = { schedule = true },
  knownMap = function() return true end, flag = function() return false end,
  event = function() return false end, registered = {}, data = {
    gen2Maps = { SHOP = { callbacks = { { callback = "MAPCALLBACK_OBJECTS", scriptKey = "week" } },
      objects = { { scriptKey = "shop" } } } },
    gen2Scripts = {
      week = { { op = "readvar", var = 11 }, { op = "ifnotequal", value = 1, script = "closed" },
        { op = "checktime", args = { 1 } }, { op = "iffalse", script = "closed" },
        { op = "appear", args = { 2 } }, { op = "endcallback" } },
      closed = { { op = "disappear", args = { 2 } }, { op = "endcallback" } },
      shop = { { op = "pokemart" } },
    } } }
local scheduled = C.build(env)
T.eq(#scheduled.days[1], 1, "the morning shop stays in the week's schedule")
T.eq(scheduled.today[1].state, "missed", "a morning service has passed by night")
T.eq(#scheduled.now, 0, "a closed service never appears as ready")
env.period = "MORN"
T.eq(C.build(env).now[1].kind, "shop", "the same service is open in the morning")
env.weekday, env.period = 0, "NITE"
T.eq(#C.build(env).days[1], 1, "tomorrow's morning service is visible tonight")

-- Crowded pages leave room for the pager, including the final page.
local theme = upvalue(display.drawCalendar, "THEME").hgss
local crowded = { noWeek = true, now = {}, today = {}, days = {} }
for i = 1, 20 do crowded.now[i] = { key = tostring(i), title = "TRAINER", tag = "BATTLE" } end
theme:calendar(crowded)
local pages, seen = crowded.pages, {}
for page = 1, pages do
  crowded.page = page; theme:calendar(crowded)
  for _, hit in ipairs(theme.calendarHits) do
    if hit.action == "entry" then
      T.check(hit.y + hit.h <= 192, "entry stays above the pager on page " .. page)
      T.check(not seen[hit.value], "each crowded entry appears once")
      seen[hit.value] = true
    end
  end
end
for i = 1, 20 do T.check(seen[tostring(i)], "crowded entry remains reachable: " .. i) end
crowded.page = 99; theme:calendar(crowded)
T.eq(crowded.page, pages, "a shrinking list clamps the actual page")
T.finish("Calendar runtime")
