package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
-- The headless SDK stub has no transform stack; real LÖVE supplies this.
love.graphics.transformPoint = love.graphics.transformPoint or function(x, y) return x, y end
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local function upvalue(fn, target)
  for i = 1, debug.getinfo(fn, "u").nups do
    local key, value = debug.getupvalue(fn, i)
    if key == target then return value end
  end
end
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
  for i = 1, 20 do run.loader.events:emit("world.stepped", { mapId = "ROUTE_2" }) end
  T.eq(album(), result, version .. " walking does not rebuild all areas")
  T.eq(display.achievementModel().goal.id, "ROUTE_2", version .. " recommends current almost-finished area")
  display.drawAchievements()
  local action, value = theme.hgss:achievementsHit(120, 100)
  T.eq(action, "area", version .. " hero tap shares rendered bounds")
  T.eq(value, "ROUTE_2", version .. " hero targets the real area")
  display.tapAchievements(120, 100)
  display.drawAchievements()
  T.eq(display.achievements.view, "detail", version .. " area detail opens")
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
  display.achievements.view, display.achievements.selected = "detail", "ROUTE_2"
  display.drawAchievements()
  display.tapAchievements(120, 195)
  display.drawAchievements()
  T.eq(display.achievements.category, 4, version .. " fourth category opens Pokemon progress")
  T.eq(display.achievementModel().entries[1].state, "open", version .. " uncaught Pokemon is an open goal")
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
    local drawText = theme.hgss.partyType
    for _, mode in ipairs({ "spoiler", "enhanced", "vanilla" }) do
      run.loader.modOptions.kanto_gear.info_level = mode
      local model = display.currentAchievement()
      T.eq(model.mode, mode, version .. " widget follows " .. mode .. " setting")
      local counts = {}
      theme.hgss.partyType = function(self, text, tx, ty, ...)
        if ty == y + 42 or ty == y + 64 then counts[tx .. ":" .. ty] = text end
        return drawText(self, text, tx, ty, ...)
      end
      theme.hgss:homeAchievements({ stamps = model }, tile, false)
      local hidden = counts[(x + 66) .. ":" .. (y + 64)]
      local trainers = counts[(x + 66) .. ":" .. (y + 42)]
      T.eq(hidden, mode == "spoiler" and "0/1" or "0 RECORDED",
        version .. " " .. mode .. " does not leak hidden totals")
      T.eq(trainers, mode == "vanilla" and "1 RECORDED" or "1/1",
        version .. " " .. mode .. " preserves recorded-only progress")
    end
    theme.hgss.partyType = drawText
    run.loader.modOptions.kanto_gear.info_level = "spoiler"
    home.widgetCache = nil
    display.homeWidgetData({ achievements = true })
    for i = 1, debug.getinfo(display.openHomeApp, "u").nups do
      if debug.getupvalue(display.openHomeApp, i) == "dirty" then
        debug.setupvalue(display.openHomeApp, i, false)
      end
    end
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

end

local Progress = assert(loadfile(path .. "/achievements.lua"))()
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
T.eq(Progress.rowState({ event = 55, hideEvent = 99 }, 1, context), "unavailable", "disappeared regular trainer stays missed")
T.eq(Progress.rowState({ event = 55, scripted = true }, 1, context), "open", "scripted gym leader counts normally")
T.eq(Progress.rowState({ event = 55, done = true, scripted = true }, 1, context), "done", "gym leader's durable flag is authoritative")
T.eq(Progress.rowState({ event = 55, done = true, hideEvent = 99 }, 1, context), "done", "automatic gym trainer completion remains valid")
T.eq(Progress.rowState({ event = 65535 }, 2, context), "untracked", "unknown item state stays explicit")
T.eq(Progress.rowState({ optional = true, status = "LOST" }, 1, context), "optional", "one-shot loss cannot block a stamp")
local function progressFor(row)
  return Progress.build({ { id = "TEST", name = "TEST", maps = { "TEST" } } }, function()
    return { sections = { { rows = { row } }, { rows = {} }, { rows = {} } },
      pokemon = { { species = "A", done = true, order = 1 } } }
  end, { gen2 = true, mapId = "TEST", save = {}, flag = function() return false end })
end
local missed = progressFor({ event = 55, missed = true })
T.eq(missed.byId.TEST.tier, "bronze", "missed required trainer cannot silently award gold")
T.eq(#missed.goals, 0, "permanently missed goals do not send the player back")
T.eq(progressFor({ event = 55, optional = true, status = "LOST" }).byId.TEST.tier,
  "gold", "optional one-shot losses do not block gold")
T.eq(progressFor({ event = 2, done = true }).byId.TEST.tier,
  "bronze", "unreliable completion cannot falsely award gold")
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
local frozen = Progress.begin(groups, read, ctx, function() return 0 end)
reads = 0
T.eq(frozen:step(0.001), nil, "checkpoint cap prevents an unbounded slice with a coarse clock")
T.eq(reads, 32, "coarse clock still yields after a fixed number of groups")
T.finish("Kanto Gear achievements RBY/GSC")
