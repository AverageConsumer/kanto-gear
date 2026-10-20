local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
-- Day-Care and Calendar on a native Gen 3 session: the host's own Day-Care
-- storage, berry trees, daily flags, Match Call rematches and the VS Seeker.
love.graphics.arc = love.graphics.arc or function() end
local edition = assert(os.getenv("POKEPORT_VERSION"))
local rs = edition == "ruby" or edition == "sapphire"
local emerald = edition == "emerald"
local hoenn = rs or emerald
dofile(path .. "/tests/" .. (rs and "rs_native_test" or emerald and "emerald_native_test" or "gen3_native_test") .. ".lua")
if rs and love == require("tests.love_stub") then
  local nativeFs = require("tests.fs_io").new(assert(os.getenv("POKEPORT_GBA_CACHE")))
  for _, method in ipairs({ "read", "load", "getInfo" }) do
    local fallback = love.filesystem[method]
    love.filesystem[method] = function(file, ...)
      local relative = file:match("^data/generated/gba/(.*)$")
      if relative then return nativeFs[method](relative, ...) end
      return fallback(file, ...)
    end
  end
end
local Dataset = require("src.core.game3.dataset")
local Schema = require("src.core.game3.save_schema_firered")
local maps = Dataset.buildMaps()
Dataset.attachMidLayouts(maps, Dataset.cache())
local data = { maps = maps,
  gen3Pokemon = require("src.core.game3.pokemon"),
  gen3Moves = require("src.core.game3.battle.moves"),
  gen3Items = require("src.core.game3.items_data"),
  gen3Encounters = assert(loadfile(os.getenv("POKEPORT_GBA_CACHE") .. "/encounters.lua"))() }
local Fs = require("tests.fs_io").new(path)
local fs, writes = {}, {}
local function resolve(file) return file:gsub("^mods/kanto_gear/?", "") end
function fs.read(file) return writes[file] or Fs.read(resolve(file)) end
function fs.load(file)
  local bytes = fs.read(file)
  return bytes and load(bytes, "@" .. file)
end
function fs.write(file, bytes) writes[file] = bytes; return true end
function fs.createDirectory() return true end
function fs.remove(file) writes[file] = nil; return true end
function fs.rename(a, b) writes[b], writes[a] = writes[a], nil; return true end
function fs.getInfo(file)
  if writes[file] then return { type = "file", size = #writes[file] } end
  if file == "mods" then return { type = "directory" } end
  return Fs.getInfo(resolve(file))
end
function fs.getDirectoryItems(file)
  if file == "mods" then return { "kanto_gear" } end
  return Fs.getDirectoryItems(resolve(file))
end
local run = T.sdk.loadMod(path, { generation = 3, data = data, fs = fs })
T.eq(run.mod and run.mod.state, "loaded", "Kanto Gear loads on Gen 3")
local raw = setmetatable({ generation = 3, data = data, phase = "boot" }, { __index = require("src.core.Game3") })
run.loader.game = raw
run.loader.events:emit("game.ready", { game = raw })
local upvalue = assert(loadfile(path .. "/tests/support/runtime.lua"))().get
local hook
for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
  if entry.owner == "kanto_gear" then hook = entry.callback end
end
local display = assert(upvalue(hook, "displayRuntime"))
T.check(display.calendarSupported(), "Calendar support is known before a save is loaded")
T.check(not display.storeById.calendar.hidden, "the boot-time support check keeps the Calendar in the store")
T.check(not display.homeCatalog.surfaces.calendar_app.hidden
  and not display.homeCatalog.surfaces.calendar_widget.hidden
  and not display.homeCatalog.surfaces.calendar_small_widget.hidden,
  "Calendar shortcuts and both widgets are available before loading")
T.check(display.calendarModel().unsupported, "Calendar content safely waits for a loaded save")
local session = Schema.newGame({ version = edition, name = "BREEDER", rngSeed = 77 })
local Json = require("src.import.canonical_json")
local Party = require("src.core.game3.party")
Party.giveMon(session, 132, 20) -- Ditto
Party.giveMon(session, 25, 18) -- Pikachu
Party.giveMon(session, 19, 9) -- Rattata
raw.session, raw.save, raw.phase = session, Schema.toSaveTable(session), "field"
require("src.core.game3.runtime").session = session
run.loader.events:emit("map.entered", { mapId = session.map, game = raw })
T.check(display.gen3 and display.gen3.session == session, "the native session is adopted")

-- Day-Care: an empty yard, then Ditto and Pikachu dropped off.
local Host = require("src.core.game3.daycare")
local empty = display.daycareModel()
T.check(empty.empty == true and #empty.parents == 0, "an empty Day-Care reads as empty")
Host.deposit(session, 1)
Host.deposit(session, 1)
display.gen3:refresh()
local model = display.daycareModel()
T.eq(#model.parents, 2, "both boarders are listed")
T.check(model.compatibility and model.compatibility.tier >= 1, "Ditto and Pikachu can breed")
T.eq(model.compatibility.chance, 20, "same trainer, different species: 20% per check")
if display.discoveryPolicy().egg_species then
  T.check(model.egg and tostring(model.egg.speciesName):upper():find("PICHU") ~= nil, "a Pikachu pair lays Pichu eggs")
else
  T.eq(model.egg and model.egg.speciesName, nil, "the egg species stays hidden by the spoiler setting")
end
T.eq(model.headline.kind, "egg_check", "the next egg check leads the widget")
T.check(model.place and model.place ~= "", "the Day-Care is named after its route")
if not hoenn then
  Host.depositRoute5(session, 1)
  display.gen3:refresh()
  local boarded = display.daycareModel()
  T.check(boarded.boarder and boarded.boarder.place ~= nil, "the Route 5 boarder is listed with its place")
  local solo = display.Daycare.build({ generation = 3 }, {})
  solo.boarder, solo.empty = boarded.boarder, false
  T.eq(display.Daycare.headline(solo).kind, "boarding", "Route 5 alone is an occupied Day-Care")
end
local catalog = display.homeCatalog
catalog.packages.daycare.installed = true
T.check(display.openHomeApp("daycare"), "the Day-Care app opens")
T.check(pcall(display.drawDaycare), "the Day-Care page draws")

-- Calendar.
T.check(display.calendarSupported(), "Gen 3 has a Calendar")
T.check(not display.storeById.calendar.hidden, "the Calendar is offered in the store")
local Constants = require("src.core.game3.constants").of(edition)
local store = display.gen3:flagStore()
local Flags = require("src.core.game3.scripting.flags")
local function flag(name, on) Flags.setFlag(store, nil, Constants.flags.byName[name], on) end
local function rows(kind)
  display.invalidateCalendar()
  local out = {}
  local calendar = display.calendarModel()
  for _, list in ipairs({ calendar.now, calendar.today }) do
    for _, row in ipairs(list) do if row.kind == kind then out[#out + 1] = row end end
  end
  return out, calendar
end
local _, calendar = rows("none")
T.check(calendar.noWeek == true and calendar.badge ~= nil, "Gen 3 has no week strip, only a badge")
T.check(calendar.relativeDays == nil and calendar.weekday == nil, "Gen 3 has no upcoming-day tabs")
for day = 0, 6 do T.eq(#calendar.days[day], 0, "Gen 3 does not populate artificial calendar days") end
if hoenn then
  local lottery = rows("lottery")
  T.eq(#lottery, 1, "the Lottery Corner is on the Calendar")
  T.eq(lottery[1] and lottery[1].state, "open", "a ticket can be drawn today")
  flag(rs and "FLAG_DAILY_PICKED_LOTTO_TICKET" or "FLAG_DAILY_PICKED_LOTO_TICKET", true)
  T.eq(rows("lottery")[1].state, "done", "a drawn ticket is done for today")
  local gifts = rows("gift")
  T.check(#gifts >= 8, "daily berry givers are listed: " .. #gifts)
  local master
  for _, row in ipairs(gifts) do if row.trainerClass then master = row end end
  T.check(master ~= nil, "the Berry Master's house is named")
  -- Berry trees: one ripe, one sprouting and dry.
  local BerryTrees = require("src.core.game3.rse.berry_trees")
  local facts = upvalue(upvalue(display.gen3Calendar.build, "scan"), "scans")
  T.check(facts ~= nil, "the Gen 3 scan cache is reachable")
  local trees = {}
  for _, scan in pairs(facts) do trees = scan.trees end
  T.check(#trees >= 40, "the scan finds the berry trees: " .. #trees)
  BerryTrees.clear(session)
  BerryTrees.plant(trees[1].tree, 1, BerryTrees.STAGE_BERRIES, true, session)
  BerryTrees.plant(trees[2].tree, 1, BerryTrees.STAGE_SPROUTED, true, session)
  local ripe = rows("berries")
  T.eq(ripe[1] and ripe[1].title, "1 TREE READY", "a ripe tree is ready")
  T.eq(rows("water")[1] and rows("water")[1].title, "1 TREE NEEDS WATER", "a dry sprout needs water")
  local next = rows("ripening")[1]
  T.check(next and next.right and next.right:find("IN %d+ H") ~= nil, "the next harvest has a time")
  BerryTrees.water(trees[2].tree, session)
  T.eq(#rows("water"), 0, "watering clears the reminder")
  -- Shoal Cave tides follow the game's clock.
  local tide = rows("tide")[1]
  T.check(tide ~= nil, "Shoal Cave's tide is on the Calendar")
  local Rtc = require("src.core.game3.rtc")
  local now = Rtc.calcTimeDifferenceRtc(Rtc.getInfo(session), session.localTimeOffset)
  local low = now.hours >= 3 and now.hours < 9 or now.hours >= 15 and now.hours < 21
  T.eq(tide.title, low and "LOW TIDE" or "HIGH TIDE", "the tide matches the hour")
  local day = display.calendarModel().hero
  T.check(day and day.kind == "day" and day.tide == true and day.minutes == now.hours * 60 + now.minutes,
    "the day card follows the game clock and shows the tides")
  T.eq(#tide.detailItems, 2, "Shoal Salt and Shoal Shell are counted")
  Rtc.setFixed("2026-10-16T12:00:00")
  local growing = session.berryTrees[trees[2].tree]
  growing.stage, growing.minutesUntilNextStage = BerryTrees.STAGE_FLOWERING, 60
  Rtc.calcLocalTimeOffset(session, 0, 22, 0, 0)
  local _, late = rows("none")
  T.eq(late.hero.status, "LOW TIDE FROM 3:00", "the late-night tide points to the next low tide")
  T.eq(late.hero.marks[1].at, 23 * 60, "today's next harvest gets a correctly timed marker")
  Rtc.calcLocalTimeOffset(session, 0, 23, 30, 0)
  local _, midnight = rows("none")
  T.eq(#midnight.hero.marks, 0, "tomorrow's harvest is never drawn on today's bar")
  T.eq(rows("ripening")[1].inMinutes, 60, "the upcoming harvest keeps its countdown without future-day tabs")
  -- Match Call: a registered trainer who wants a rematch.
  local Rematch = require(rs and "src.core.game3.rs.rematch" or "src.core.game3.rse.rematch")
  T.eq(#rows("rematch"), 0, "nobody wants a rematch yet")
  Rematch.set(session, 0, 1)
  T.eq(#rows("rematch"), 0, "an unmet trainer stays hidden")
  local entry = rs and Rematch.table()[0] or Rematch.entry(0)
  local registered = rs and Flags.trainerFlagId(entry.trainers[1]) or Rematch.registeredFlagId(session, 0)
  Flags.setFlag(store, nil, registered, true)
  local rematch = rows("rematch")[1]
  local pack = require("src.core.game3.scripting.trainers").pack()
  T.eq(rematch and rematch.title, pack.trainers[entry.trainers[1]].name, "the trainer is named")
  T.check(rematch and rematch.place ~= nil, "the trainer's route is named")
  Rematch.set(session, 0, 0)
else
  local function hero() display.invalidateCalendar(); return display.calendarModel().hero end
  T.eq(hero(), nil, "no VS Seeker, no battery card")
  local Bag = require("src.core.game3.bag")
  local VsSeeker = require("src.core.game3.vs_seeker")
  Bag.add(session.bag, VsSeeker.ITEM_VS_SEEKER, 1)
  VsSeeker.setBattery(session, 40)
  local battery = hero()
  T.eq(battery and battery.charge, 40, "the battery card shows the charge")
  T.eq(battery and battery.status, "60 STEPS TO GO", "the steps left are shown")
  T.eq(#rows("seeker"), 0, "the battery card replaces the VS Seeker row")
  VsSeeker.setBattery(session, 100)
  T.eq(hero().status, "READY TO USE", "a full battery is ready")
  local theme = upvalue(display.drawCalendar, "THEME").hgss
  local painted, printInfo = {}, theme.partyInfo
  theme.partyInfo = function(self, value, ...)
    painted[tostring(value)] = true
    return printInfo(self, value, ...)
  end
  theme:homeCalendar({ calendar = display.calendarModel() }, { column = 1, row = 1, columns = 12 })
  theme.partyInfo = printInfo
  T.check(painted[hero().title] and painted["READY TO USE"],
    "the Home widget retains the VS Seeker's title and readiness without a duplicate list row")
  VsSeeker.state(session).rematches[3] = 1
  T.eq(rows("rematch")[1] and rows("rematch")[1].title, "1 TRAINER IS READY", "answered trainers are listed")
end
-- A read must not initialize rematch/VS Seeker state or apply pending plants.
session.trainerRematches = nil
if not hoenn then session.vsSeeker = nil end
local BerryTrees = hoenn and require("src.core.game3.rse.berry_trees") or nil
if BerryTrees then BerryTrees._pending = { { 1, 1, BerryTrees.STAGE_BERRIES, true } } end
local before = Json.encode(Schema.toSaveTable(session))
rows("none")
display.daycareModel()
T.eq(Json.encode(Schema.toSaveTable(session)), before, "Calendar and Day-Care leave save data and RNG unchanged")
T.eq(session.trainerRematches, nil, "reading does not create rematch state")
if not hoenn then T.eq(session.vsSeeker, nil, "reading does not create VS Seeker state") end
if BerryTrees then
  T.check(BerryTrees._pending ~= nil, "reading leaves queued plantings to the game")
  BerryTrees._pending = nil
end
-- Predict the same level and moves the real pickup applies, using a clone.
local function clone(value)
  if type(value) ~= "table" then return value end
  local out = {}; for key, item in pairs(value) do out[key] = clone(item) end; return out
end
Host.stateOf(session).steps[2] = 100000
local predicted = display.daycareModel().parents[2]
local picked = clone(Host.mon(Host.stateOf(session), 2))
Host.applyExperience(picked, 100000)
T.eq(predicted.levelNow, picked.level, "pickup level matches the native engine")
local Moves = require("src.core.game3.battle.moves")
local actual = {}
for _, move in ipairs(picked.moves) do if move ~= 0 then actual[#actual + 1] = Moves.displayName(move) end end
T.eq(table.concat(predicted.after, "|"), table.concat(actual, "|"), "pickup moves match the native engine")
if not hoenn then session.vsSeeker = { steps = 50, charging = 0, rematches = { [3] = 1 } } end
catalog.packages.calendar.installed = true
T.check(display.openHomeApp("calendar"), "the Calendar app opens")
display.invalidateCalendar()
local ok, err = pcall(display.drawCalendar)
T.check(ok, "the Calendar draws: " .. tostring(err))
local theme = upvalue(display.drawCalendar, "THEME").hgss
T.eq(theme:calendarHit(120, 54), nil, "the day/battery overview has no inactive touch action")
display.tapCalendar(60, 100)
T.eq(display.calendar.view, "detail", "the first row opens its details")
ok, err = pcall(display.drawCalendar)
T.check(ok, "the detail page draws: " .. tostring(err))
display.tapCalendar(10, 10)
T.eq(display.calendar.view, nil, "Back returns to the list")
T.finish("Gen 3 Day-Care and Calendar")
