package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local run = T.sdk.loadMod(path, { generation = generation, data = T.fixtures.load() })
local world = { isOverworld = true, map = { id = "FIX_ROUTE" }, daytime = "DAY",
  player = { cellX = 2, cellY = 3, px = 36, py = 52, facing = "down" } }
local game = { data = run.data, world = world,
  save = { generation = generation, version = generation == 2 and "crystal" or "red",
    player = { name = "RED", map = "FIX_ROUTE", badges = {} },
    party = {}, inventory = {}, boxes = {},
    pokedex = { seen = {}, caught = {} } },
  stack = { states = { world }, top = function(self) return self.states[#self.states] end } }
run.loader.events:emit("game.ready", { game = game })
local function value(fn, key, replacement, set)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, current = debug.getupvalue(fn, i)
    if name == key then
      if set then debug.setupvalue(fn, i, replacement) end
      return current
    end
  end
  error("missing upvalue: " .. key)
end
local hook
for _, entry in ipairs(run.loader.hooks.chains["input.step"]) do
  if entry.owner == "kanto_gear" then hook = entry.callback end
end
local display = value(hook, "displayRuntime")
local api = value(display.localMapPosition, "mod")
api.world = require(generation == 2 and "src.world.gen2.WorldAPI"
  or "src.world.WorldAPI").new(game, "kanto_gear")
local theme = value(display.drawContents, "THEME")
-- Replacement sheets may use HD frame coordinates while the map still uses
-- 16px logical markers. Exercise the real host SpriteRenderer and Gear draw.
do
  local compat = value(display.bagModel, "compat")
  local registry = generation == 2 and "gen2Sprites" or "sprites"
  local savedSprites = run.data[registry]
  run.data[registry] = {}
  for index, size in ipairs({
    { 16, 16, 8, 8 }, { 32, 32, 8, 8 }, { 256, 256, 8, 8 },
    { 32, 64, 4, 8 }, { 64, 32, 8, 4 }, { 8, 8, 4, 4 },
  }) do
    local id, image = "MARKER_" .. index, "marker-" .. index .. ".png"
    local width, height, shownW, shownH = unpack(size)
    run.data[registry][id] = { image = image, frameWidth = width,
      frameHeight = height, frames = 6, walker = true, trueColor = true,
      anchorX = width / 2, anchorY = height * 0.75 }
    for _, facing in ipairs({ "down", "up", "left", "right" }) do
      for _, feet in ipairs({ false, true }) do
        local draws = T.record.draw()
        T.check(compat.drawMapSprite(id, "marker-test", nil,
          100, 80, 0.5, feet, facing), "replacement marker draws")
        draws:stop()
        local draw = assert(draws:fromPath(image)[1], "marker draw recorded").args
        T.eq(math.abs(draw[5]) * width, shownW, "marker fits the logical width")
        T.eq(draw[6] * height, shownH, "marker fits the logical height")
        T.eq(draw[5] < 0, facing == "right", "right-facing marker is mirrored")
        T.eq(draw[2] + width * draw[5] / 2, 100, "marker stays horizontally centered")
        T.eq(draw[3] + shownH * (feet and 0.75 or 0.5), 80,
          "marker preserves its foot or center anchor")
      end
    end
    local cached = compat.mapSprite(id, "marker-test")
    T.eq(compat.mapSprite(id, "marker-test"), cached, "fitting reuses the cached renderer")
    T.eq(cached.frameWidth, width, "fitting does not resize the source frame")
  end
  run.data[registry] = savedSprites
end
value(display.updateMapRefresh, "page", "LOCAL", true)
local time = T.love.timer.getTime
local now = 0
T.love.timer.getTime = function() return now end
local pos = display.localMapPosition()
T.eq(pos.x, 2.25, "map uses the engine's intermediate horizontal pixel position")
T.eq(pos.y, 3.25, "map uses the engine's intermediate vertical pixel position")
T.eq(world.player.cellX, 2, "rendering does not move the logical player")
T.eq(display.localMapPosition("OTHER_MAP"), nil, "visual position never leaks onto a different map")
world.player.px, world.player.py = nil, nil
T.eq(display.localMapPosition().x, 2, "older hosts fall back to logical cells")
world.player.px, world.player.py = 36, 52
local rows = {} for i = 1, 36 do rows[i] = string.rep(" ", 40) end
local overview = { mapId = "FIX_ROUTE", width = 40, height = 36, rows = rows, markers = {} }
local model = display.explorerModel(overview)
now = 0.1
world.player.px = 40
T.eq(display.explorerModel(overview), model, "motion reuses the entire Explorer data model")
T.eq(model.player.x, 2.5, "cached data still receives the latest visual position")
display.explorer.filters.wildScope = "ROUTE"
T.check(display.explorerModel(overview) ~= model, "changing scope invalidates the model immediately")
model = display.explorer.renderModel
now = 0.51
T.check(display.explorerModel(overview) ~= model, "encounter and progress snapshots refresh after half a second")
model = display.explorer.renderModel
display.explorer.scanFrame = 1
T.check(display.explorerModel(overview) ~= model, "scanning bypasses the motion cache")
display.explorer.scanFrame = nil
model = display.explorer.renderModel
T.check(display.explorerModel(overview) ~= model, "ending a scan clears its cached overlay")
model = display.explorer.renderModel
local state = display.mapRefresh
state.nextAt, state.key = 0, nil
local frames = 0
for frame = 0, 599 do
  now = frame / 60
  world.player.px = 32 + frame
  if display.updateMapRefresh(now) then
    frames = frames + 1
    state.key = theme.hgss:explorerMotionKey(model, display.localMapPosition())
  end
end
T.eq(frames, 300, "ten seconds of continuous walking produce 30 updates per second without debounce starvation")
world.player.px = 631
state.key = theme.hgss:explorerMotionKey(model, display.localMapPosition())
T.eq(display.updateMapRefresh(10), false, "standing still requests no render")
world.player.px = 631.01
T.eq(display.updateMapRefresh(10.1), false, "subpixel changes that render identically request no render")
world.player.facing = "left"
T.eq(display.updateMapRefresh(10.2), true, "turning in place refreshes the marker")
value(display.updateMapRefresh, "readbackPending", true, true)
world.player.px = 640
T.eq(display.updateMapRefresh(11), false, "slow readback cannot queue another map frame")
value(display.updateMapRefresh, "readbackPending", false, true)
T.eq(display.updateMapRefresh(11.1), true, "readback completion allows the latest position")
state.key = theme.hgss:explorerMotionKey(model, display.localMapPosition())
T.eq(display.updateMapRefresh(100), false, "a long pause causes no catch-up renders")
world.player.px = 650
game.stack.states[2] = { isTextBox = true }
T.eq(display.updateMapRefresh(101), false, "dialogue suppresses motion-only updates")
game.stack.states[2] = nil
display.overlayHidden = true
T.eq(display.updateMapRefresh(102), false, "hidden Gear suppresses motion updates")
display.overlayHidden = nil
value(display.updateMapRefresh, "page", "HOME", true)
T.eq(display.updateMapRefresh(103), false, "other apps do not run the map refresh")
value(display.updateMapRefresh, "page", "LOCAL", true)
world.map.id = "NEXT_MAP"
T.eq(display.updateMapRefresh(104), false, "a map transition never animates against the old map")
world.map.id = "FIX_ROUTE"
model.mapFull, model.mapZoom = true, 3
T.check(theme.hgss:explorerMotionKey(model, display.localMapPosition()) ~= state.key,
  "motion sampling follows fullscreen zoom geometry")
local homeModel = { page = 1, overview = overview,
  tiles = { { widget = "explorer", column = 1, row = 1, columns = 7 } } }
display.home.page, state.homeModel = 1, homeModel
value(display.updateMapRefresh, "page", "HOME", true)
for _, mode in ipairs({ "quality", "performance" }) do
  run.loader.modOptions.kanto_gear = run.loader.modOptions.kanto_gear or {}
  run.loader.modOptions.kanto_gear.map_motion = mode
  display.optionsChanged({ mod = "kanto_gear", key = "map_motion", value = mode })
  state.nextAt, state.key = 0, nil
  local count = 0
  for frame = 0, 599 do
    world.player.px = 32 + frame
    if display.updateMapRefresh(frame / 60) then
      count = count + 1
      state.key = theme.hgss:homeMotionKey(homeModel, display.localMapPosition())
    end
  end
  T.eq(count, mode == "quality" and 300 or 50,
    mode .. " mode applies the selected update budget to Home widgets")
end
world.player.px = 700
display.home.editing = true
T.eq(display.updateMapRefresh(11), false, "Home editing suspends map animation")
display.home.editing, display.home.library = false, true
T.eq(display.updateMapRefresh(12), false, "the widget picker suspends map animation")
display.home.library, display.home.page = false, 2
T.eq(display.updateMapRefresh(13), false, "an off-page widget cannot trigger Home redraws")
display.home.page = 1
homeModel.tiles = { { widget = "party" } }
T.eq(display.updateMapRefresh(14), false, "Home without an Explorer widget stays idle")
value(display.updateMapRefresh, "page", "LOCAL", true)
state.nextAt, state.key = 0, nil
local performanceFrames = 0
for frame = 0, 599 do
  world.player.px = 32 + frame
  if display.updateMapRefresh(frame / 60) then
    performanceFrames = performanceFrames + 1
    state.key = theme.hgss:explorerMotionKey(model, display.localMapPosition())
  end
end
T.eq(performanceFrames, 50, "Explorer shares the five-Hz performance mode")
now = 200
local widgets = display.homeWidgetData({ party = true })
T.eq(display.homeWidgetData({ party = true }), widgets,
  "Home movement reuses widget data instead of recalculating the party")
T.check(display.homeWidgetData({ team = true }) ~= widgets,
  "changing the visible widget set refreshes its data immediately")
widgets = display.homeWidgetData({ party = true })
now = 200.6
T.check(display.homeWidgetData({ party = true }) ~= widgets,
  "Home widget data refreshes on the slow snapshot cadence")
api.world.mapOverview = function() return overview end
display.home.layout = { tiles = { { id = "explorer_widget", page = 1, column = 1, row = 1 } } }
display.home.page, display.home.editing, display.home.library = 1, false, false
world.player.px, world.player.py = 36, 52
value(display.updateMapRefresh, "page", "HOME", true)
T.check(pcall(display.drawHome), "the real Home draw path renders the moving widget")
T.eq(state.homeModel.player.x, 2.25, "Home renders intermediate positions from the shared Explorer model")
T.eq(state.key, theme.hgss:homeMotionKey(state.homeModel, state.homeModel.player),
  "Home records the actual widget geometry after drawing")
world.player.px, state.nextAt = 48, 0
T.eq(display.updateMapRefresh(201), true, "the real Home widget requests its next movement frame")
widgets = display.home.widgetCache
run.loader.events:emit("world.stepped", { mapId = "FIX_ROUTE" })
T.eq(display.home.widgetCache, nil, "step-driven HP and party changes invalidate the widget snapshot")
-- Exercise the shipped draw path and host stack events: overlays must not
-- allocate a new terrain image or unexpectedly close the user's map view.
local loadMap = value(display.drawHome, "loadLocalMap")
local imageBefore = display.explorer.renderModel.image
local overviewBefore = loadMap()
local overviewCalls = 0
api.world.mapOverview = function() overviewCalls = overviewCalls + 1; return overview end
local stack = setmetatable({}, { __index = require("src.core.StateStack") })
stack:init()
for _, screen in ipairs({ { screenId = "OptionsMenu" }, { isTextBox = true },
    { screenId = "Gen2EggHatchAnim" } }) do
  display.explorer.mapFull, display.explorer.mapZoom = true, 3
  display.explorer.selected, display.explorer.page = "selected-row", 2
  local snapshot = display.explorer.data
  stack:push(screen)
  T.eq(display.explorer.data, nil, "native screen push refreshes live encounter and progress rows")
  T.eq(display.explorer.mapFull, true, "overlay preserves expanded map")
  T.eq(display.explorer.mapZoom, 3, "overlay preserves map zoom")
  T.eq(display.explorer.selected, "selected-row", "overlay does not reset selection")
  T.eq(display.explorer.page, 2, "overlay does not reset pagination")
  T.eq(loadMap(), overviewBefore, "overlay keeps the same terrain overview")
  stack:pop()
  display.drawHome()
  T.eq(display.explorer.renderModel.image, imageBefore, "overlay reuses the same rendered terrain image")
  T.check(display.explorer.data ~= snapshot, "live rows are refreshed while terrain is reused")
end
T.eq(overviewCalls, 0, "three native screen changes cause no map readback/rebuild")
for _, event in ipairs({ "world.block_replaced", "map.reloaded" }) do
  run.loader.events:emit(event, { mapId = "OTHER_MAP" })
  T.eq(loadMap(), overviewBefore, "remote terrain changes preserve the current map")
  local before = overviewCalls
  run.loader.events:emit(event, { mapId = "FIX_ROUTE" })
  loadMap()
  T.eq(overviewCalls, before + 1, "current terrain change rebuilds the overview")
  display.drawHome()
  local rebuilt = display.explorer.renderModel.image
  T.check(rebuilt ~= imageBefore, "current terrain change rebuilds the map image")
  imageBefore = rebuilt
end
local before = overviewCalls
run.loader.events:emit("map.entered", { mapId = "FIX_ROUTE" })
loadMap()
T.eq(overviewCalls, before + 1, "map entry still rebuilds terrain")
run.loader.events:emit("save.loaded", {})
loadMap()
T.eq(overviewCalls, before + 2, "save load still rebuilds terrain")
-- The native path must reach the actual widget, not only a standalone renderer.
local G = love.graphics
local originalBatch = G.newSpriteBatch
G.newSpriteBatch = function()
  return { __path = "native-batch", add = function() end,
    flush = function() end, release = function() end }
end
world.map.widthCells, world.map.heightCells = 40, 36
world.map.tileset = { blocks = { {} } }
for i = 1, 16 do world.map.tileset.blocks[1][i] = 0 end
world.map.blockAt = function() return 0 end
world.map.renderer = { image = { __path = "native-atlas" }, quads = { [0] = {} }, trueColor = true }
world.mapImage = { __path = "native-map-canvas" }
display.home.layout = { tiles = { { id = "explorer_widget", page = 1, column = 1, row = 1 } } }
display.home.page, display.home.editing, display.home.library = 1, false, false
run.loader.events:emit("map.reloaded", { mapId = "FIX_ROUTE" })
T.check(type(loadMap().drawTerrain) == "function", "real runtime attaches native terrain to the overview")
display.drawHome()
T.eq(display.explorer.renderModel.image, nil, "native widget skips the second CPU raster and GPU upload")
local builds = display.nativeMap.builds
display.drawHome()
T.eq(display.nativeMap.builds, builds, "repeated Home draws share native terrain geometry")
if generation == 2 then world.mapImage = { __path = "new-native-colors" }
else world.map.renderer.quads = { [0] = {} } end
state.nextAt = 0
T.eq(display.updateMapRefresh(400), true, "native texture replacement refreshes a stationary widget")
display.drawHome(); state.nextAt = 0
T.eq(display.updateMapRefresh(401), false, "unchanged native terrain does not request endless redraws")
if generation == 2 then world.mapImage = nil else world.map.renderer = nil end
T.eq(loadMap().drawTerrain, nil, "missing host terrain keeps the established map fallback")
G.newSpriteBatch = originalBatch
T.love.timer.getTime = time
run.release()
T.finish("Kanto Gear map motion")
