package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
-- The headless SDK stub has no transform stack; real LÖVE supplies this.
love.graphics.transformPoint = love.graphics.transformPoint or function(x, y) return x, y end
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local upvalue = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
for _, version in ipairs({ "red", "blue", "yellow", "gold", "silver", "crystal" }) do
  local gen2 = version == "gold" or version == "silver" or version == "crystal"
  local run = T.sdk.loadMod(path, { generation = gen2 and 2 or 1, data = T.fixtures.fresh() })
  T.eq(run.mod and run.mod.state, "loaded", version .. " loads the complete app module set")
  local data = run.data
  data.items = { POTION = { index = 1, name = "POTION " .. version:upper() } }
  local maps, locations = {}, {}
  for i = 1, 9 do
    local id = "ROUTE_" .. i
    maps[id] = { id = id, width = 10, height = 10, landmark = i,
      objects = gen2 and {
        { index = 1, x = 2, y = 3, trainer = { class = 3, member = 1, event = 100 + i } },
        { index = 2, x = 4, y = 5, itemball = { item = 1 }, eventFlag = 200 + i },
      } or {
        { index = 1, x = 2, y = 3, trainerClass = "OPP_YOUNGSTER" },
        { index = 2, x = 4, y = 5, item = "POTION" },
      }, bgEvents = { { x = 6, y = 7, hiddenItem = { item = 1, event = 300 + i } } } }
    locations[id] = { index = i, name = "ROUTE " .. i, x = i, y = 1 }
  end
  data.maps = maps
  data.field = { townMap = { locations = locations }, hiddenItems = {} }
  for id in pairs(maps) do data.field.hiddenItems[id] = { { x = 6, y = 7, item = "POTION" } } end
  data.trainers = { OPP_YOUNGSTER = { name = "YOUNGSTER" } }
  data.gen2Maps = maps
  local block = {}; for i = 1, 16 do block[i] = 0 end
  data.tilesets = { TEST = { blocks = { block, block }, walkable = { 0 },
    collision = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 } },
    image = "achievements-test-tiles.png", tilesPerRow = 1 } }
  data.gen2Tilesets = data.tilesets
  for _, def in pairs(maps) do
    def.tileset, def.blocks = "TEST", {}
    for i = 1, def.width * def.height do def.blocks[i] = 1 end
    def.connections = { north = { mapId = "ROUTE_1" } }
  end
  data.gen2Landmarks = { landmarks = locations }
  data.gen2Trainers = { classes = { YOUNGSTER = { index = 3, name = "YOUNGSTER",
    trainers = { { name = "JOEY" } } } } }
  local flags = { [102] = true, [202] = true }
  local world = { map = { id = "ROUTE_2" }, player = { cellX = 1, cellY = 1 } }
  local game = { data = data, world = world,
    save = { generation = gen2 and 2 or 1, version = version,
      player = { name = "RED", map = "ROUTE_2" }, party = {}, inventory = {},
      pokedex = { seen = {}, caught = {} }, flags = {}, boxes = {},
      defeatedTrainers = { ROUTE_2_obj_1 = true }, itemsTaken = { ROUTE_2_obj_2 = true }, hiddenTaken = {} },
    stack = { states = { world }, top = function(self) return self.states[#self.states] end } }
  run.loader.events:emit("game.ready", { game = game })
  run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", info_level = "spoiler", trigger_tabs = true }
  local input
  for _, hook in ipairs(run.loader.hooks.chains["input.step"]) do
    if hook.owner == "kanto_gear" then input = hook.callback end
  end
  local display = assert(upvalue(input, "displayRuntime"))
  local mod = assert(upvalue(display.achievementData, "mod"))
  if gen2 then
    local Area = assert(upvalue(upvalue(display.achievementData, "areaData"), "Area"))
    local gym = Area.gen2ScriptTrainer(data, { scriptKey = {
      { op = "loadtrainer", class = "FALKNER", member = 1 },
      { op = "startbattle" }, { op = "setevent", event = 900 },
      { op = "setevent", event = 901 },
    } })
    T.eq(gym.event, 900, version .. " leader uses the first post-battle completion flag")
    T.eq(gym.optional, false, version .. " scripted gym battle is required")
    local rival = Area.gen2ScriptTrainer(data, { scriptKey = {
      { op = "loadtrainer", class = "RIVAL1", member = 1 },
      { op = "loadvar", args = { 3, 1 } }, { op = "startbattle" },
    } })
    T.eq(rival.optional, true, version .. " CANLOSE battle is an optional bonus")
  end
  mod.world = mod.world or {}
  mod.world.getFlag = function(_, id) return flags[id] == true end
  local theme = assert(upvalue(display.drawContents, "THEME"))
  local lookup = assert(upvalue(display.sectionName, "locationEntry"))
  local entries = assert(upvalue(lookup, "locationEntries"))
  for id, entry in pairs(entries()) do
    T.eq(lookup(id), entry, version .. " individual lookup agrees with full area grouping " .. id)
  end
  T.eq(lookup(nil), nil, version .. " absent map remains unnamed")
  T.eq(lookup("NOT_A_MAP"), nil, version .. " unknown map remains unnamed")
  if gen2 then
    local landmarks = data.gen2Landmarks
    landmarks.order = {}
    for key, entry in pairs(landmarks.landmarks) do landmarks.order[entry.index + 1] = key end
    local key = landmarks.order[3]
    local original = landmarks.landmarks[key]
    T.eq(lookup("ROUTE_2"), original, version .. " generated order resolves live landmark")
    local translated = { index = 2, name = "TRANSLATED", x = 2, y = 1 }
    landmarks.landmarks[key] = translated
    T.eq(lookup("ROUTE_2"), translated, version .. " replaced translation is visible without cache invalidation")
    translated.index = 70
    T.eq(lookup("ROUTE_2"), nil, version .. " stale order cannot return a moved landmark")
    maps.ROUTE_2.landmark = 70
    T.eq(lookup("ROUTE_2"), translated, version .. " registered index absent from order is found")
    T.eq(entries().ROUTE_2, translated, version .. " full grouping agrees for registered index")
    landmarks.landmarks[key], maps.ROUTE_2.landmark = original, 2
    landmarks.landmarks.DUPLICATE = { index = 2, name = "SHADOW" }
    T.eq(lookup("ROUTE_2"), original, version .. " canonical landmark wins a duplicate index like the host")
    T.eq(entries().ROUTE_2, original, version .. " full grouping uses the same canonical landmark")
    landmarks.landmarks.DUPLICATE = nil
    maps.MOD_LAB = { landmark = key }
    T.eq(lookup("MOD_LAB"), original, version .. " mod landmark IDs resolve directly")
    T.eq(entries().MOD_LAB, original, version .. " symbolic mod maps do not break all area grouping")
    landmarks.landmarks[key] = translated
    T.eq(lookup("MOD_LAB"), translated, version .. " symbolic landmark translations remain live")
    T.eq(entries().MOD_LAB, translated, version .. " symbolic grouping follows replaced landmarks")
    landmarks.landmarks[key] = original
    maps.MOD_LAB.landmark = "MISSING_LANDMARK"
    T.eq(lookup("MOD_LAB"), nil, version .. " unknown symbolic landmark has no record")
    T.eq(entries().MOD_LAB, nil, version .. " unknown symbolic landmark does not break other areas")
    maps.MOD_LAB = nil
    maps.UNNAMED = {}
    T.eq(lookup("UNNAMED"), nil, version .. " map without landmark is supported")
    T.eq(entries().UNNAMED, nil, version .. " grouping omits maps without a landmark")
    maps.UNNAMED = nil
  end
  local home = display.home
  home.help, home.helpSeen = false, true
  local originalTiles = #home.layout.tiles
  T.eq(display.homeCatalog.packages.achievements.installed, false, version .. " opt-in Store install")
  T.check(not display.openHomeApp("achievements"), version .. " uninstalled app cannot open")
  T.check(display.setPackageInstalled("achievements", true), version .. " installs through existing Store")
  T.check(display.openHomeApp("achievements"), version .. " opens without changing the top screen")
  T.eq(#home.layout.tiles, originalTiles, version .. " preserves Home layout")
  T.eq(game.stack:top(), world, version .. " no game screen push")
  -- Runtime builds incrementally; completion assertions wait for publication.
  local function album()
    for _ = 1, 1000 do
      local result = display.achievementData(false, true)
      if result then return result end
    end
    error("album did not complete")
  end
  T.eq(display.achievementData(), nil, version .. " first open schedules, never builds synchronously")
  T.eq(display.achievementModel().loading, true, version .. " incomplete totals are hidden")
  local cancelled = display.achievements.job
  run.loader.events:emit("flag.changed", {})
  T.eq(display.achievements.job, nil, version .. " flag change cancels unfinished snapshot")
  local result = album()
  T.check(display.achievements.job ~= cancelled, version .. " cancelled snapshot is never published")
  local area = assert(result.byId.ROUTE_2)
  T.eq(area.sections[1].done, 1, version .. " reads trainer completion")
  T.eq(area.sections[2].done, 1, version .. " reads pickup completion")
  T.eq(area.sections[3].done, 0, version .. " does not invent hidden progress")
  T.eq(area.remaining, 1, version .. " exactly one remaining find")
  T.eq(area.tier, "bronze", version .. " visited area earns bronze")
  T.eq(area.sections[2].rows[1].label, "POTION " .. version:upper(), version .. " retains game item names")
  T.eq(album(), result, version .. " idle redraw reuses progress snapshot")
  run.loader.events:emit("world.interacted", {kind="none"})
  T.eq(display.achievementData(), result, version .. " empty A presses retain the completed album")
  for i = 1, 20 do run.loader.events:emit("world.stepped", { mapId = "ROUTE_2" }) end
  T.eq(album(), result, version .. " walking does not rebuild all areas")
  local oldVisits = {}
  for id, value in pairs(mod.save:get("achievement_visits", {})) do oldVisits[id] = value end
  run.loader.events:emit("map.entered", { mapId = "ROUTE_3" })
  T.eq(display.achievements.stale, false, version .. " a completed album survives a location change")
  local relocated = display.achievementData()
  T.eq(relocated.byId.ROUTE_2.sections, result.byId.ROUTE_2.sections,
    version .. " moving keeps evaluated progress rows")
  T.eq(relocated.byId.ROUTE_3.current, true, version .. " moving updates the current place immediately")
  T.eq(relocated.byId.ROUTE_2.current, false, version .. " the previous place is no longer current")
  mod.save:set("achievement_visits", oldVisits)
  run.loader.events:emit("map.entered", { mapId = "ROUTE_2" })
  result = display.achievementData()
  T.eq(display.achievements.job, nil, version .. " returning needs no album loading job")
  T.eq(display.achievementModel().goal.id, "ROUTE_2", version .. " recommends current almost-finished area")
  display.drawAchievements()
  local action, value = theme.hgss:achievementsHit(120, 100)
  T.eq(action, "area", version .. " hero tap shares rendered bounds")
  T.eq(value, "ROUTE_2", version .. " hero targets the real area")
  display.tapAchievements(120, 100)
  display.drawAchievements()
  T.eq(display.achievements.view, "detail", version .. " area detail opens")
  display.tapAchievements(120, 105)
  display.drawAchievements()
  T.eq(theme.hgss:achievementsHit(120, 70), "locate", version .. " trainer card offers its known position")
  display.tapAchievements(120, 70)
  T.eq(display.achievements.location.x, 2, version .. " trainer uses object x coordinate")
  T.eq(display.achievements.location.y, 3, version .. " trainer uses object y coordinate")
  display.drawAchievements()
  display.tapAchievements(12, 12)
  display.tapAchievements(12, 12)
  display.drawAchievements()
  display.tapAchievements(120, 166)
  display.drawAchievements()
  T.eq(display.achievements.view, "finds", version .. " hidden list opens")
  T.eq(display.achievementModel().entries[1].x, 6, version .. " exact hidden cell retained")
  display.tapAchievements(120, 70)
  T.eq(display.achievements.view, "location", version .. " find opens its precise map")
  T.check(display.achievements.locationImage ~= nil, version .. " native map overview renders")
  T.eq(display.achievements.locationDensity, 4, version .. " preserves four samples per cell")
  T.eq(maps.ROUTE_2.connections.north.map, nil, version .. " detached preview never mutates map connections")
  T.eq(game.stack:top(), world, version .. " location browsing leaves live world alone")
  local image = display.achievements.locationImage
  theme.hgss:setVariant("dark")
  display.achievementModel()
  T.check(display.achievements.locationImage ~= image, version .. " map palette follows theme changes")
  display.drawAchievements()
  display.tapAchievements(12, 12)
  T.eq(display.achievements.view, "finds", version .. " back returns to the find list")
  -- A remote five-floor gift/trade uses the building's outdoor doorway first.
  maps.ROUTE_2.outdoor, maps.ROUTE_2.warps = true, { { x = 7, y = 8, destMap = "FLOOR_1" } }
  for floor = 1, 5 do
    maps["FLOOR_" .. floor] = { id = "FLOOR_" .. floor, width = 10, height = 10,
      tileset = "TEST", blocks = maps.ROUTE_2.blocks,
      warps = { { x = 1, y = 1, destMap = floor < 5 and "FLOOR_" .. (floor + 1) or "LAST_MAP" } } }
  end
  local find = { label = "NPC TRADE", gift = true, trade = true, mapId = "FLOOR_5", x = 4, y = 5 }
  theme.hgss:achievements({ view = "finds", mode = "spoiler", entries = { find } })
  display.tapAchievements(120, 70)
  local state = display.achievements
  T.eq(state.location, find, version .. " selected source remains the exact indoor find")
  T.eq(state.locationPoint.mapId, "ROUTE_2", version .. " building entrance shown first")
  T.eq(state.locationPoint.x, 7, version .. " entrance uses warp coordinates")
  display.drawAchievements()
  T.eq(theme.hgss:achievementsHit(120, 155), "location_scope", version .. " entrance offers inside button")
  display.tapAchievements(120, 155)
  T.eq(state.locationPoint, find, version .. " inside button shows exact original find")
  T.eq(state.locationMap, "FLOOR_5", version .. " inside button loads correct floor")
  display.drawAchievements()
  display.tapAchievements(12, 12)
  T.eq(state.view, "location", version .. " back from inside returns to entrance")
  T.eq(state.locationPoint, state.locationEntrance, version .. " back restores outdoor door")
  display.drawAchievements()
  display.tapAchievements(12, 12)
  T.eq(state.view, "finds", version .. " second back restores original list")
  T.eq(state.locationEntrance, nil, version .. " leave clears old entrance")
  T.eq(game.stack:top(), world, version .. " floor preview never enters live maps")
  maps.ROUTE_2.outdoor, maps.ROUTE_2.warps = nil, nil
  for floor = 1, 5 do maps["FLOOR_" .. floor] = nil end
  for _, mode in ipairs({ "vanilla", "enhanced" }) do
    run.loader.modOptions.kanto_gear.info_level = mode
    T.eq(#display.achievementModel().entries, 0, version .. " " .. mode .. " hides unfound hidden items")
    display.achievements.view, display.achievements.location = "location", { x = 6, y = 7 }
    T.eq(display.achievementModel().view, "detail", version .. " mode switch closes spoiler location")
    display.achievements.view = "goals"
    T.eq(display.achievementModel().goal, nil, version .. " no hidden-only hint outside Spoiler")
    display.achievements.view, display.achievements.category = "finds", 3
  end
  run.loader.modOptions.kanto_gear.info_level = "spoiler"
  if gen2 then flags[302] = true; run.loader.events:emit("flag.changed", { name = 302, value = true })
  else game.save.hiddenTaken.ROUTE_2_6_7 = true end
  T.eq(album().byId.ROUTE_2.complete, true, version .. " awards stamp from real completion")
  T.eq(album().byId.ROUTE_2.tier, "gold", version .. " completed area without wild species earns gold")
  -- A species counts once across methods and times, and can be caught elsewhere.
  local slot = { species = "FIXMON_A", level = 3 }
  data.encounters = { ROUTE_2 = { grass = { slots = { slot, slot } } } }
  data.gen2Encounters = { grass = { ROUTE_2 = { slots = {
    MORN = { slot }, DAY = { slot }, NITE = { slot },
  } } } }
  display.achievements.species, display.achievements.stale = nil, true
  area = album().byId.ROUTE_2
  T.eq(area.sections[4].total, 1, version .. " duplicate encounter slots produce one species goal")
  T.eq(area.tier, "silver", version .. " missing local species leaves silver")
  T.eq(display.currentAchievement().step.target, "gold", version .. " widget shows the next stamp tier")
  T.eq(display.currentAchievement().now, true, version .. " widget recognizes the available walking encounter")
  local wild = area.sections[4].rows[1]
  local originalAppearances = wild.appearances
  local function nextNow(method, time, id)
    wild.appearances = { { mapId = id or "ROUTE_2", method = method, time = time } }
    display.achievements.presentSource = nil
    for _, goal in ipairs(display.achievementModel().goals) do
      if goal.area.id == "ROUTE_2" then return goal.now end
    end
  end
  world.tod = "DAY"
  T.eq(nextNow("OLD"), false, version .. " next stamp does not advertise fishing without a rod")
  game.save.inventory.OLD_ROD = 1
  T.eq(nextNow("OLD"), true, version .. " owned rod makes an untimed encounter available")
  T.eq(nextNow("OLD", "NITE"), false, version .. " next stamp respects the game time")
  game.save.pokedex.seen.FIXMON_A = true
  run.loader.modOptions.kanto_gear.info_level = "enhanced"
  T.eq(nextNow("WALK", nil, "UNVISITED_FIXTURE"), false, version .. " NOW does not reveal an unknown floor")
  run.loader.modOptions.kanto_gear.info_level = "custom"
  for _, key in ipairs({ "stamp_totals", "wild", "unknown_species", "habitats" }) do
    mod.options:set("reveal_" .. key, true)
  end
  mod.options:set("reveal_encounter_details", false)
  T.eq(nextNow("WALK"), false, version .. " NOW respects disabled encounter details")
  T.eq(display.achievementModel().canEncounterDetails, false, version .. " method icons respect encounter details")
  T.eq(display.currentAchievement().now, false, version .. " widget respects disabled encounter details")
  local renderer, hintCalls, reserved = theme.hgss, 0, nil
  local originalFind, originalMethod = renderer.v4FindRow, renderer.v4MethodGlyph
  renderer.v4FindRow = function(_, _, _, _, _, right) reserved = right end
  renderer.v4MethodGlyph = function() hintCalls = hintCalls + 1 end
  local hintModel = { view = "finds", mode = "spoiler", category = 4, areaMaps = { "ROUTE_2" },
    canHabitat = true, canEncounterDetails = false,
    entries = { { label = "LONG POKEMON NAME", wild = true, state = "open", appearances = {} } } }
  for _, method in ipairs({ "SURF", "OLD", "GOOD", "SUPER", "HEADBUTT" }) do
    hintModel.entries[1].appearances[#hintModel.entries[1].appearances + 1] = { mapId = "ROUTE_2", method = method }
  end
  renderer:achievements(hintModel)
  T.eq(hintCalls, 0, version .. " disabled encounter details draw no method hints")
  hintModel.canEncounterDetails = true
  renderer:achievements(hintModel)
  T.eq(hintCalls, 3, version .. " method hints stay within three icon slots")
  T.eq(reserved, 178, version .. " Pokemon name reserves the visible hint strip")
  renderer.v4FindRow, renderer.v4MethodGlyph = originalFind, originalMethod
  run.loader.modOptions.kanto_gear.info_level = "spoiler"
  wild.appearances = originalAppearances
  display.achievements.presentSource = nil
  game.save.inventory.OLD_ROD = nil
  game.save.pokedex.seen.FIXMON_A = nil
  display.achievements.view, display.achievements.selected = "detail", "ROUTE_2"
  display.drawAchievements()
  display.tapAchievements(120, 195)
  display.drawAchievements()
  T.eq(display.achievements.category, 4, version .. " fourth category opens Pokemon progress")
  T.eq(display.achievementModel().entries[1].state, "open", version .. " uncaught Pokemon is an open goal")
  T.eq(theme.hgss:achievementsHit(120, 70), "habitat", version .. " wild species card has direct details")
  display.tapAchievements(120, 70)
  local habitat = display.achievementModel().habitat
  T.eq(display.achievements.view, "habitat", version .. " species tap stays in Stamps")
  T.eq(habitat.pokemon.species, "FIXMON_A", version .. " opens the tapped species")
  T.eq(habitat.rows[1].area, "ROUTE 2", version .. " details stay within the selected area")
  T.eq(habitat.rows[1].method, "WALK", version .. " shows the encounter method")
  T.eq(habitat.rows[1].levels, "L3", version .. " shows encounter levels")
  T.check(habitat.rows[1].chance > 0, version .. " shows actual encounter odds")
  T.eq(game.stack:top(), world, version .. " habitat browsing leaves the game alone")
  -- More than three conditions must paginate independently from the find list.
  local appearances = display.achievements.habitat.habitat.appearances
  for _, method in ipairs({ "OLD", "GOOD", "SUPER" }) do
    appearances[#appearances + 1] = { mapId = "ROUTE_2", section = "ROUTE 2",
      method = method, chance = 10, minLevel = 5, maxLevel = 10 }
  end
  display.pokedex.habitatPlan = nil
  display.drawAchievements()
  display.tapAchievements(149, 205)
  T.eq(display.achievements.habitatPage, 2, version .. " habitat pager advances")
  T.eq(display.achievements.page, 1, version .. " habitat paging preserves the find page")
  appearances[#appearances + 1] = { mapId = "UNVISITED_FIXTURE", section = "SECRET FLOOR",
    method = "WALK", chance = 10, minLevel = 5, maxLevel = 10 }
  display.pokedex.habitatPlan = nil
  local all = display.pokedexHabitatPlan(display.achievements.habitat)
  run.loader.modOptions.kanto_gear.info_level = "enhanced"
  local known = display.pokedexHabitatPlan(display.achievements.habitat)
  T.eq(#known.rows, #all.rows - 1, version .. " reducing spoilers immediately filters cached unknown floors")
  run.loader.modOptions.kanto_gear.info_level = "vanilla"
  T.eq(display.achievementModel().view, "finds", version .. " reducing spoilers closes unknown species details")
  run.loader.modOptions.kanto_gear.info_level = "spoiler"
  display.drawAchievements()
  display.tapAchievements(120, 70)
  display.drawAchievements()
  display.tapAchievements(12, 12)
  T.eq(display.achievements.view, "finds", version .. " habitat back returns to the Pokemon list")
  display.drawAchievements()
  display.tapAchievements(120, 200)
  T.eq(display.home.activeApp, "explorer", version .. " Pokemon progress opens Explorer without game navigation")
  T.eq(display.explorer.filters.wildScope, "ROUTE", version .. " Explorer shows the whole area")
  game.save.pokedex.caught.FIXMON_A = true
  run.loader.events:emit("pokemon.caught", { species = "FIXMON_A" })
  area = album().byId.ROUTE_2
  T.eq(area.tier, "gold", version .. " registered species promotes silver to gold")
  T.eq(area.sections[4].done, 1, version .. " uses the global caught Dex")
  game.save.pokedex.caught.FIXMON_A = nil
  T.eq(album().byId.ROUTE_2.tier, "silver", version .. " caught Dex change invalidates progress without a battle")
  display.openHomeApp("achievements")
  display.achievements.view, display.achievements.selected = "album", nil
  display.drawAchievements()
  T.eq(display.achievementModel().pages, 2, version .. " all nine areas are paginated")
  display.cycleAchievements(1)
  T.eq(#display.achievementModel().entries, 3, version .. " last page remains reachable")
  T.eq(display.achievementModel().page, 2, version .. " page changed")
  display.cycleAchievements(1)
  T.eq(display.achievementModel().page, 1, version .. " pager wraps safely")
  local before = display.achievements.page
  input(function() end, game, { pressed = { right = true }, held = { right = true } })
  T.eq(display.achievements.page, before, version .. " D-pad never navigates achievements")
  flags[302], game.save.hiddenTaken.ROUTE_2_6_7 = false, nil
  run.loader.events:emit("save.loaded", {})
  T.eq(album().byId.ROUTE_2.complete, false, version .. " older save removes future stamp")
  if gen2 then
    maps.ROUTE_3.objects[#maps.ROUTE_3.objects + 1] = {
      index = 3, x = 1, y = 1, scriptKey = {
        { op = "loadtrainer", class = 3, member = 1 },
        { op = "startbattle" }, { op = "setevent", event = 900 },
        { op = "setevent", event = 103 },
      },
    }
    flags[103], flags[900] = true, true
  else
    maps.ROUTE_3.label = "Gym"
    maps.ROUTE_3.objects[#maps.ROUTE_3.objects + 1] = {
      index = 3, x = 1, y = 1, trainerClass = "OPP_BROCK",
    }
    data.trainerHeader = function(_, label, index)
      if label == "Gym" then return { event = index == 1 and "GYM_TRAINER" or "GYM_LEADER" } end
    end
    game.save.flags.GYM_TRAINER, game.save.flags.GYM_LEADER = true, true
  end
  run.loader.events:emit("flag.changed", {})
  local gymSection = album().byId.ROUTE_3.sections[1]
  T.eq(gymSection.total, 2, version .. " gym leader and trainer both count towards the stamp")
  T.eq(gymSection.done, 2, version .. " automatic gym flags count as defeated without a battle history")
  T.eq(gymSection.optional, 0, version .. " gym completion is never an optional bonus")
  -- The Home widget shares stamp rules but only evaluates the current group.
  do
    local home = display.home
    home.help, home.helpSeen = false, true
    local surface = display.homeCatalog.surfaces.achievements_widget
    T.eq(surface.package, "achievements", version .. " widget follows the Stamps install")
    T.eq(surface.columns, 12, version .. " widget uses one readable full-width row")
    local build, builds, groupCount = display.Achievements.build, 0, 0
    display.Achievements.build = function(groups, ...)
      builds, groupCount = builds + 1, #groups
      return build(groups, ...)
    end
    home.widgetCache = nil
    display.homeWidgetData({})
    T.eq(builds, 0, version .. " Home without Stamps does no progress work")
    display.achievements.currentData = nil
    local book = display.achievements.data
    local stamp = display.currentAchievement()
    T.eq(groupCount, 1, version .. " Home builds only the current area's progress")
    T.eq(display.achievements.data, book, version .. " widget does not replace the album snapshot")
    T.eq(stamp.area.id, "ROUTE_2", version .. " widget shows the current area")
    T.eq(stamp.area.tier, book.byId.ROUTE_2.tier, version .. " widget and album use identical tiers")
    for i = 1, 4 do
      T.eq(stamp.area.sections[i].done, book.byId.ROUTE_2.sections[i].done,
        version .. " widget category " .. i .. " matches album progress")
      T.eq(stamp.area.sections[i].total, book.byId.ROUTE_2.sections[i].total,
        version .. " widget category " .. i .. " matches album totals")
    end
    for i = 1, 120 do
      run.loader.events:emit("world.stepped", { mapId = "ROUTE_2" })
      display.homeWidgetData({ achievements = true })
    end
    T.eq(builds, 1, version .. " repeated walking and Home refreshes reuse current progress")
    home.layout = { tiles = { { id = "achievements_widget", page = 1, row = 1, column = 1 } } }
    home.page, home.editing, home.library = 1, false, false
    local tile = display.Home.tiles(home.layout, display.homeCatalog, 1)[1]
    display.openHomeApp("achievements")
    display.tapAchievements(12, 12)
    T.eq(upvalue(display.openHomeApp, "page"), "HOME", version .. " widget event fixture is on Home")
    local x, y, w, h = theme.hgss:homeRect(tile)
    local drawText, drawInfo = theme.hgss.partyType, theme.hgss.partyInfo
    for _, mode in ipairs({ "spoiler", "enhanced", "vanilla" }) do
      run.loader.modOptions.kanto_gear.info_level = mode
      local model = display.currentAchievement()
      T.eq(model.mode, mode, version .. " widget follows " .. mode .. " setting")
      -- a cell shows its count either on the label's row (short counts) or
      -- on its own row under the label (long ones); collect both places
      local drawn = {}
      local function spy(draw)
        return function(self, text, tx, ty, ...)
          if tx == x + 66 then drawn[ty] = drawn[ty] or {}; table.insert(drawn[ty], text) end
          return draw(self, text, tx, ty, ...)
        end
      end
      theme.hgss.partyType, theme.hgss.partyInfo = spy(drawText), spy(drawInfo)
      theme.hgss:homeAchievements({ stamps = model }, tile, false)
      theme.hgss.partyType, theme.hgss.partyInfo = drawText, drawInfo
      local function cell(row)
        for _, ty in ipairs(row == 1 and { y + 37, y + 42 } or { y + 59, y + 64 }) do
          for _, text in ipairs(drawn[ty] or {}) do
            if text:find("%d") then return text end
          end
        end
      end
      T.eq(cell(2), mode == "spoiler" and "0/1" or "0 RECORDED",
        version .. " " .. mode .. " does not leak hidden totals")
      T.eq(cell(1), mode == "vanilla" and "1 RECORDED" or "1/1",
        version .. " " .. mode .. " preserves recorded-only progress")
    end
    run.loader.modOptions.kanto_gear.info_level = "spoiler"
    home.widgetCache = nil
    display.homeWidgetData({ achievements = true })
    display.session.dirty = false
    run.loader.events:emit("flag.changed", {})
    T.eq(upvalue(display.openHomeApp, "dirty"), true, version .. " progress event requests a fresh Home frame")
    T.eq(home.widgetCache, nil, version .. " progress events invalidate the visible Home widget")
    T.eq(display.achievements.currentData, nil, version .. " progress events invalidate current stamp")
    display.tapHome(x + math.floor(w / 2), y + math.floor(h / 2))
    T.eq(display.achievements.view, "detail", version .. " widget tap opens area detail")
    T.eq(display.achievements.selected, "ROUTE_2", version .. " widget tap targets current area")
    T.eq(game.stack:top(), world, version .. " widget tap leaves the game controls alone")
    display.homeWidgetData({ achievements = true })
    run.loader.events:emit("world.interacted", {})
    T.eq(home.widgetCache, nil, version .. " offscreen stamp cache cannot outlive an interaction")
    run.loader.events:emit("map.entered", { mapId = "ROUTE_3" })
    T.eq(display.currentAchievement().area.id, "ROUTE_3", version .. " entering another area updates widget")
    T.eq(groupCount, 1, version .. " changing routes still builds only one area")
    run.loader.events:emit("map.entered", { mapId = "ROUTE_2" })
    local uncaught = display.currentAchievement().area
    game.save.pokedex.caught.FIXMON_A = true
    run.loader.events:emit("pokemon.caught", { species = "FIXMON_A" })
    T.eq(display.currentAchievement().area.sections[4].done, 1, version .. " a catch refreshes widget Dex count")
    if gen2 then flags[302] = true; run.loader.events:emit("flag.changed", {})
    else game.save.hiddenTaken.ROUTE_2_6_7 = true end
    T.eq(display.currentAchievement().area.tier, "gold", version .. " pickup promotes the live widget to gold")
    game.save.pokedex.caught.FIXMON_A = nil
    T.eq(display.currentAchievement().area.tier, "silver", version .. " silent Dex change also refreshes widget")
    flags[302], game.save.hiddenTaken.ROUTE_2_6_7 = false, nil
    run.loader.events:emit("save.loaded", {})
    T.eq(display.currentAchievement().area.tier, uncaught.tier, version .. " older save removes widget completion")
    run.loader.events:emit("map.entered", { mapId = "UNKNOWN_MAP" })
    T.eq(display.currentAchievement().area, nil, version .. " unknown area never reuses previous stamp")
    display.Achievements.build = build
  end
  T.check(display.setPackageInstalled("achievements", false), version .. " Store removal works")
  T.eq(#display.Home.tiles({ tiles = {
    { id = "achievements_widget", page = 1, row = 1, column = 1 },
  } }, display.homeCatalog, 1), 0, version .. " removing Stamps also hides its widget")
  T.eq(#run.errors, 0, version .. " runtime stays error-free")
  run.release()
  -- Force yields inside real runtime readers, then interrupt the partial build.
  local clock, now = love.timer.getTime, 0
  love.timer.getTime = function() now = now + 0.002; return now end
  run.loader.events:emit("flag.changed", {})
  T.eq(display.achievementData(false, true), nil, version .. " partial runtime build yields")
  local partial = display.achievements.job
  T.check(partial ~= nil, version .. " unfinished work remains resumable")
  run.loader.events:emit("world.interacted", {kind="none"})
  T.eq(display.achievements.job, partial, version .. " empty A presses cannot restart loading")
  T.eq(display.achievementModel().loading, true, version .. " old totals stay hidden during refresh")
  local oldView = display.achievements.view
  display.tapAchievements(120, 100)
  T.eq(display.achievements.view, oldView, version .. " old card hit regions cannot act during refresh")
  run.loader.events:emit("map.entered", { mapId = "ROUTE_3" })
  T.eq(display.achievements.job, nil, version .. " map transition discards partial results")
  display.achievementData(false, true)
  T.check(display.achievements.job ~= partial, version .. " next map receives a fresh job")
  run.loader.events:emit("save.loaded", {})
  T.eq(display.achievements.job, nil, version .. " save loading discards suspended job")
  T.eq(display.achievements.data, nil, version .. " save loading cannot keep future progress")
  love.timer.getTime = clock

  if not gen2 then
    -- The retail Safari gate's Nugget is at (10,1), beyond its 8x6 cells.
    -- Exercise the shared readers so it cannot become a radar/map target.
    local readArea = assert(upvalue(display.achievementData, "areaData"))
    maps.ROUTE_9.width, maps.ROUTE_9.height = 4, 3
    maps.ROUTE_9.objects = {}
    data.field.hiddenItems.ROUTE_9 = { { x = 10, y = 1, item = "POTION" } }
    local row = readArea({ "ROUTE_9" }, true).sections[3].rows[1]
    T.check(row.outsideMap and row.untracked and row.available == false and not row.done,
      version .. " off-map find is explicitly untracked, never collected")
    run.loader.events:emit("map.entered", { mapId = "ROUTE_9" })
    world.map.id, world.player.cellX, world.player.cellY = "ROUTE_9", 7, 1
    T.eq(album().byId.ROUTE_9.tier, "gold", version .. " unreachable find cannot prevent Gold")
    local signals = assert(upvalue(display.finishScanFeedback, "radarSignals"))
    T.eq(#signals(), 0, version .. " unreachable find cannot trigger Itemfinder")
    local overview = { mapId = "ROUTE_9", rows = { "        " }, width = 8, height = 6 }
    local explorer = display.explorerModel(overview)
    for _, marker in ipairs(explorer.markers) do
      T.check(marker.x ~= 10, version .. " no off-map marker")
    end
    maps.ROUTE_9.width = 6
    row = readArea({ "ROUTE_9" }, true).sections[3].rows[1]
    T.check(not row.outsideMap and not row.untracked,
      version .. " resized custom map restores a genuinely reachable find")
  end

  if gen2 then
    -- Issue 35: exercise the real readers, album and Itemfinder on each GSC
    -- adapter, using a different flag ID and item name than the retail Spule.
    local Area = assert(upvalue(upvalue(display.achievementData, "areaData"), "Area"))
    data.gen2InitialEvents = { flags = { 309 } }
    data.gen2Scripts = { unlock = {
      { op = "checkevent", event = 950 }, { op = "iftrue", script = "met" },
      { op = "setevent", event = 950 }, { op = "clearevent", event = 951 },
      { op = "clearevent", event = 309 }, { op = "end" },
    } }
    flags[309], flags[950] = true, false
    run.loader.events:emit("save.loaded", {})
    local locked = album().byId.ROUTE_9
    T.eq(locked.tier, "none", version .. " initial lock never grants an unvisited stamp")
    T.eq(locked.sections[3].done, 0, version .. " locked pickup is not collected")
    T.eq(locked.sections[3].rows[1].state, "later", version .. " quest-locked pickup is later")
    T.eq(#display.Achievements.visibleRows(locked, 3, "vanilla"), 0,
      version .. " initial lock cannot leak hidden item names")
    flags[950], flags[309] = true, false
    run.loader.events:emit("flag.changed", {})
    T.eq(album().byId.ROUTE_9.sections[3].done, 0, version .. " unlocking is not collecting")
    flags[309] = true
    run.loader.events:emit("flag.changed", {})
    T.eq(album().byId.ROUTE_9.sections[3].done, 1, version .. " actual pickup counts")
    T.eq(game.save.inventory.POTION, nil, version .. " pickup proof needs no item in bag after hand-in")
    flags[950] = false
    run.loader.events:emit("save.loaded", {})
    T.eq(album().byId.ROUTE_9.tier, "none", version .. " older save removes phantom evidence")
    run.loader.events:emit("map.entered", { mapId = "ROUTE_9" })
    world.map.id, world.player.cellX, world.player.cellY = "ROUTE_9", 6, 7
    local signals = assert(upvalue(display.finishScanFeedback, "radarSignals"))
    T.eq(#signals(), 0, version .. " Itemfinder ignores locked pickup")
    T.eq(album().byId.ROUTE_9.sections[3].done, 0, version .. " visiting locked area is not a pickup")
    flags[950], flags[309] = true, false
    run.loader.events:emit("flag.changed", {})
    T.eq(#signals(), 1, version .. " Itemfinder sees unlocked pickup / full-bag retry")
    flags[309] = true
    T.eq(#signals(), 0, version .. " Itemfinder ignores collected pickup")
    data.gen2Scripts = { callback = { { op = "setevent", event = 309 } } }
    run.loader.events:emit("save.loaded", {})
    T.eq(album().byId.ROUTE_9.sections[3].untracked, 1,
      version .. " map reset flag is not permanent collection proof")
    T.eq(#signals(), 0, version .. " reset Moon Stone is not currently available")
    flags[309] = false
    T.eq(#signals(), 1, version .. " spawned recurring item remains detectable")
    local row = Area.gen2Hidden(data, mod.world, "ROUTE_9")[1]
    T.eq(row.done, false, version .. " recurring item never receives a fabricated checkmark")
  end

end

local Progress = assert(loadfile(path .. "/features/achievements.lua"))()
local context = { save = { flags = { EVENT_SS_ANNE_LEFT = true,
  EVENT_GOT_HELIX_FOSSIL = true } }, flag = function(id) return id == 99 end }
T.eq(Progress.rowState({ mapId = "SS_ANNE_1F" }, 2, context), "unavailable", "departed ship items are not impossible goals")
T.eq(Progress.rowState({ mapId = "SS_ANNE_1F" }, 3, context), "unavailable", "departed ship hidden finds are not goals")
T.eq(Progress.rowState({ mapId = "MT_MOON_B2F", itemId = "DOME_FOSSIL" }, 2, context), "excluded", "mutually exclusive fossil does not block completion")
T.eq(Progress.rowState({ mapId = "MT_MOON_B2F", itemId = "HELIX_FOSSIL" }, 2, context), "done", "chosen fossil accepts its canonical event flag")
T.eq(Progress.rowState({ missed = true, done = true }, 1, context), "unavailable", "missed rival is not falsely marked beaten")
T.eq(Progress.rowState({ status = "LOST", done = true }, 1, context), "unavailable", "lost one-shot rival is not marked beaten")
T.eq(Progress.rowState({ status = "LATER" }, 1, context), "later", "future story encounters remain pending")
context.gen2 = true
T.eq(Progress.rowState({ event = 2 }, 1, context), "untracked", "temporary flag is not called optional")
T.eq(Progress.rowState({ event = 2, done = true }, 1, context), "untracked", "temporary flag cannot prove a win")
T.eq(Progress.rowState({ event = 55, hideEvent = 99 }, 1, context), "later", "hidden trainer may return on another day or story phase")
T.eq(Progress.rowState({ event = 55, hideEvent = 99, missable = true }, 1, context), "unavailable", "proven disappearing trainer stays missed")
T.eq(Progress.rowState({ event = 55, scripted = true }, 1, context), "open", "scripted gym leader counts normally")
T.eq(Progress.rowState({ event = 55, done = true, scripted = true }, 1, context), "done", "gym leader's durable flag is authoritative")
T.eq(Progress.rowState({ event = 55, done = true, hideEvent = 99 }, 1, context), "done", "automatic gym trainer completion remains valid")
T.eq(Progress.rowState({ event = 65535 }, 2, context), "untracked", "unknown item state stays explicit")
T.eq(Progress.rowState({ optional = true, status = "LOST" }, 1, context), "unavailable", "bonus loss retains its actual outcome")
local function progressFor(row)
  return Progress.build({ { id = "TEST", name = "TEST", maps = { "TEST" } } }, function()
    return { sections = { { rows = { row } }, { rows = {} }, { rows = {} } },
      pokemon = { { species = "A", done = true, order = 1 } } }
  end, { gen2 = true, mapId = "TEST", save = {}, flag = function() return false end })
end
local missed = progressFor({ event = 55, missed = true })
T.eq(missed.byId.TEST.tier, "gold", "permanently missed trainer is a bonus rather than a Gold lock")
T.eq(missed.byId.TEST.sections[1].rows[1].state, "unavailable", "Gold never fabricates a victory")
T.eq(missed.byId.TEST.sections[1].bonusMissed, 1, "missed bonus remains documented")
T.eq(#missed.goals, 0, "permanently missed goals do not send the player back")
T.eq(progressFor({ event = 55, optional = true, status = "LOST" }).byId.TEST.tier,
  "gold", "optional one-shot losses do not block gold")
T.eq(progressFor({ event = 2, done = true }).byId.TEST.tier,
  "bronze", "unreliable completion cannot falsely award gold")
T.eq(progressFor({ optional = true }).byId.TEST.tier,
  "gold", "CANLOSE bonus without a durable win flag cannot block Gold")

local function areaFor(sections, pokemon, visited)
  return Progress.build({ { id = "TEST", name = "TEST", maps = { "TEST" } } }, function()
    return { sections = sections, pokemon = pokemon or {} }
  end, { gen2 = true, mapId = visited and "TEST" or "ELSEWHERE", save = {},
    flag = function() return false end }).byId.TEST
end
local empty = { { rows = {} }, { rows = {} }, { rows = {} } }
T.eq(areaFor(empty, nil, true).tier, "gold", "visited area without objectives is complete")
T.eq(areaFor(empty, nil, false), nil, "empty unvisited area earns nothing")
local recurring = { { rows = {} }, { rows = {} },
  { rows = { { untracked = true, event = 309, status = "NOT TRACKED" } } } }
local finished = areaFor(recurring, nil, true)
T.eq(finished.tier, "gold", "Moon Square style non-durable find cannot block Gold")
T.eq(finished.sections[3].untracked, 1, "untracked find stays documented")
T.eq(finished.sections[3].done, 0, "non-durable find is never given a false checkmark")
T.eq(areaFor(recurring, { { species = "A", done = false } }, true).tier,
  "silver", "uncaught local Pokemon still prevents Gold")
T.eq(areaFor({ { rows = {} }, { rows = { { untracked = true, unknown = true } } },
  { rows = {} } }, nil, true).tier, "bronze", "unknown item metadata still blocks completion")
T.eq(areaFor({ { rows = { { untracked = true } } }, { rows = {} }, { rows = {} } },
  nil, true).tier, "bronze", "missing source catalogue cannot award Gold")
-- Obligations and actual outcomes must agree across every category/generation.
for _, gen in ipairs({ 1, 2, 3 }) do
  for category = 1, 4 do
    for _, outcome in ipairs({ "open", "done", "missed" }) do
      local source = { event = 55, mapId = "TEST", missable = true,
        done = outcome ~= "open", missed = outcome == "missed", gift = category == 4 }
      local rows = { { rows = {} }, { rows = {} }, { rows = {} } }
      local mons = {}
      if category == 4 then mons[1] = source else rows[category].rows[1] = source end
      local area = Progress.build({ { id = "TEST", maps = { "TEST" } } }, function()
        return { sections = rows, pokemon = mons }
      end, { gen2 = gen == 2, gen3 = gen == 3, save = {}, mapId = "TEST" }).byId.TEST
      local section = area.sections[category]
      T.eq(area.tier, "gold", "Gen " .. gen .. " bonus cannot lock category " .. category)
      T.eq(section.total, 0, "bonus excluded from required denominator")
      T.eq(section.optional, 1, "bonus remains in its own denominator")
      T.eq(section.bonusDone, outcome == "done" and 1 or 0, "only genuine completion earns a bonus check")
      T.eq(section.rows[1].state, outcome == "missed" and "unavailable" or outcome, "bonus preserves outcome")
      T.eq(section.rows[1].done, outcome == "done", "missed is never exposed as done to privacy/UI callers")
      local shown = Progress.presentArea(area, "enhanced", function() return true end).sections[category]
      T.eq(shown.total, section.total, "filtered denominator uses the same rules")
      T.eq(shown.bonusDone, section.bonusDone, "filtered bonus progress uses the same rules")
      T.eq(source.bonus, nil, "source catalogue remains read-only")
    end
  end
end
local function choiceArea(rows, gen)
  return Progress.build({ { id = "TEST", maps = { "TEST" } } }, function()
    return { sections = { { rows = {} }, { rows = rows }, { rows = {} } } }
  end, { gen2 = gen == 2, gen3 = gen == 3, save = {}, mapId = "TEST" }).byId.TEST
end
for _, gen in ipairs({ 1, 2, 3 }) do
  local choices = { { mapId = "TEST", gift = true, event = 55, itemId = "A" },
    { mapId = "TEST", gift = true, event = 55, itemId = "B" } }
  T.eq(choiceArea(choices, gen).sections[2].total, 1, "shared reward receipt requires one choice in Gen " .. gen)
  T.eq(choiceArea(choices, gen).tier, "bronze", "choice still must be made")
  choices[2].done = true
  T.eq(choiceArea(choices, gen).sections[2].done, 1, "either choice completes the shared goal")
  T.eq(choiceArea(choices, gen).tier, "gold", "unchosen alternative does not lock Gold")
  choices[1].done = true
  T.eq(choiceArea(choices, gen).sections[2].done, 1, "shared receipts never overcount")
  choices[2].event = 56
  T.eq(choiceArea(choices, gen).sections[2].total, 2, "independent receipts remain independent")
  choices[2].done = false
  T.eq(choiceArea(choices, gen).tier, "bronze", "normal unfinished reward still blocks Gold")
end
local ship = choiceArea({ { mapId = "SS_ANNE_1F", done = false } }, 1)
T.eq(ship.sections[2].optional, 1, "ship pickup is a bonus even before departure")
T.eq(ship.sections[2].rows[1].state, "open", "uncollected ship pickup is not prematurely missed")
T.eq(choiceArea({ { mapId = "SS_ANNE_1F", required = true } }, 1).tier,
  "bronze", "mandatory story reward on the ship remains required")
T.eq(Progress.rowState({ event = 55, hideEvent = 99, missable = true, missedAfter = 100 }, 1, context),
  "later", "initial story hiding is not proof of a missed battle")
-- Deterministic workload: verify both bounded progress and exact parity with
-- the existing synchronous rules, including goals ordering and every row.
local groups = {}
for i = 1, 100 do groups[i] = { id = tostring(i), name = tostring(i), maps = { tostring(i) } } end
local elapsed, reads = 0, 0
local function read(maps)
  elapsed, reads = elapsed + 0.0004, reads + 1
  return { sections = { { rows = { { mapId = maps[1], done = reads % 2 == 0 } } },
    { rows = {} }, { rows = {} } }, pokemon = {} }
end
local ctx = { save = {}, mapId = "1" }
local expected = Progress.build(groups, read, ctx)
elapsed, reads = 0, 0
local job = Progress.begin(groups, read, ctx, function() return elapsed end)
T.eq(reads, 0, "scheduling does no area work")
local actual, slices = nil, 0
repeat
  local before = elapsed
  actual = job:step(0.001)
  slices = slices + 1
  T.check(elapsed - before <= 0.00120001, "slice stops at first checkpoint after its budget")
  if not actual then T.check(reads < 101, "partial results remain private") end
until actual
local function same(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
T.check(same(expected, actual), "staged result exactly matches every synchronous field")
T.check(slices > 30, "work is spread across frames")
T.eq(job:step(0.001), actual, "finished job reuses its result")
T.eq(reads, 100, "no area is skipped or repeated")
local coarseGroups = {}
for i = 1, 400 do coarseGroups[i] = { id = tostring(i), name = tostring(i), maps = { tostring(i) } } end
local frozen = Progress.begin(coarseGroups, read, ctx, function() return 0 end)
reads = 0
T.eq(frozen:step(0.001), nil, "checkpoint cap prevents an unbounded slice with a coarse clock")
T.eq(reads, 256, "coarse clock still yields after a bounded number of checkpoints")
-- Relocation is exactly a fresh build for the same progress and new visits,
-- including empty places previously omitted from the album and goal tie-breaks.
local places = { {id="A", name="A", maps={"A"}}, {id="B",name="B",maps={"B"}},
  {id="EMPTY",name="EMPTY",maps={"EMPTY"}}, {id="DONE",name="DONE",maps={"DONE"}} }
local function placeRows(ids)
  return {sections={ {rows=ids[1]=="EMPTY" and {} or {{mapId=ids[1],done=ids[1]=="DONE"}}},
    {rows={}}, {rows={}} },pokemon={} }
end
local cached = Progress.build(places, placeRows, {save={},mapId="A",visited={A=true,B=true}})
T.eq(cached.byId.EMPTY, nil, "unvisited empty place is initially omitted")
for _, context in ipairs({ {save={},mapId="B",visited={A=true,B=true}},
    {save={},mapId="EMPTY",visited={A=true,B=true,EMPTY=true}},
    {save={},mapId="UNKNOWN",visited={}} }) do
  cached = Progress.relocate(cached,context)
  T.check(same(cached,Progress.build(places,placeRows,context)),
    "relocated album exactly matches a fresh build at "..context.mapId)
end
T.finish("Kanto Gear achievements RBY/GSC")
