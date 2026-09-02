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
  mod.world = mod.world or {}
  mod.world.getFlag = function(_, id) return flags[id] == true end
  local theme = assert(upvalue(display.drawContents, "THEME"))
  local home = display.home
  home.help, home.helpSeen = false, true
  local originalTiles = #home.layout.tiles
  T.eq(display.homeCatalog.packages.achievements.installed, false, version .. " opt-in Store install")
  T.check(not display.openHomeApp("achievements"), version .. " uninstalled app cannot open")
  T.check(display.setPackageInstalled("achievements", true), version .. " installs through existing Store")
  T.check(display.openHomeApp("achievements"), version .. " opens without changing the top screen")
  T.eq(#home.layout.tiles, originalTiles, version .. " preserves Home layout")
  T.eq(game.stack:top(), world, version .. " no game screen push")
  local result = display.achievementData()
  local area = assert(result.byId.ROUTE_2)
  T.eq(area.sections[1].done, 1, version .. " reads trainer completion")
  T.eq(area.sections[2].done, 1, version .. " reads pickup completion")
  T.eq(area.sections[3].done, 0, version .. " does not invent hidden progress")
  T.eq(area.remaining, 1, version .. " exactly one remaining find")
  T.eq(area.sections[2].rows[1].label, "POTION " .. version:upper(), version .. " retains game item names")
  T.eq(display.achievementData(), result, version .. " idle redraw reuses progress snapshot")
  for i = 1, 20 do run.loader.events:emit("world.stepped", { mapId = "ROUTE_2" }) end
  T.eq(display.achievementData(), result, version .. " walking does not rebuild all areas")
  T.eq(display.achievementModel().goal.id, "ROUTE_2", version .. " recommends current almost-finished area")
  display.drawAchievements()
  local action, value = theme.hgss:achievementsHit(120, 100)
  T.eq(action, "area", version .. " hero tap shares rendered bounds")
  T.eq(value, "ROUTE_2", version .. " hero targets the real area")
  display.tapAchievements(120, 100)
  display.drawAchievements()
  T.eq(display.achievements.view, "detail", version .. " area detail opens")
  display.tapAchievements(120, 190)
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
  T.eq(display.achievementData().byId.ROUTE_2.complete, true, version .. " awards stamp from real completion")
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
  T.eq(display.achievementData().byId.ROUTE_2.complete, false, version .. " older save removes future stamp")
  T.check(display.setPackageInstalled("achievements", false), version .. " Store removal works")
  T.eq(#run.errors, 0, version .. " runtime stays error-free")
  run.release()
end

local Progress = assert(loadfile(path .. "/achievements.lua"))()
local context = { save = { flags = { EVENT_SS_ANNE_LEFT = true,
  EVENT_GOT_HELIX_FOSSIL = true } }, flag = function(id) return id == 99 end }
T.eq(Progress.rowState({ mapId = "SS_ANNE_1F" }, 2, context), "unavailable", "departed ship items are not impossible goals")
T.eq(Progress.rowState({ mapId = "SS_ANNE_1F" }, 3, context), "unavailable", "departed ship hidden finds are not goals")
T.eq(Progress.rowState({ mapId = "MT_MOON_B2F", itemId = "DOME_FOSSIL" }, 2, context), "unavailable", "unchosen fossil is not falsely marked found")
T.eq(Progress.rowState({ mapId = "MT_MOON_B2F", itemId = "HELIX_FOSSIL" }, 2, context), "done", "chosen fossil accepts its canonical event flag")
T.eq(Progress.rowState({ missed = true, done = true }, 1, context), "unavailable", "missed rival is not falsely marked beaten")
T.eq(Progress.rowState({ status = "LOST", done = true }, 1, context), "unavailable", "lost one-shot rival is not marked beaten")
T.eq(Progress.rowState({ status = "LATER" }, 1, context), "later", "future story encounters remain pending")
context.gen2 = true
T.eq(Progress.rowState({ event = 2 }, 1, context), "optional", "temporary battle flags cannot be required")
T.eq(Progress.rowState({ event = 2, done = true }, 1, context), "optional", "set temporary flags cannot award durable progress")
T.eq(Progress.rowState({ event = 55, hideEvent = 99 }, 1, context), "optional", "hidden story trainer never becomes an impossible requirement")
T.eq(Progress.rowState({ event = 55, scripted = true }, 1, context), "optional", "unknown script conditions stay explicitly optional")
T.eq(Progress.rowState({ event = 65535 }, 2, context), "optional", "untracked item cannot block a stamp")
T.finish("Kanto Gear achievements RBY/GSC")
