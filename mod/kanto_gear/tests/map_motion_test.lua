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
local value = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
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
T.eq(model.player.x, 2.5, "Explorer player follows the latest rendered position")
display.explorer.filters.wildScope = "ROUTE"
T.check(display.explorerModel(overview) ~= model, "changing scope invalidates the model immediately")
model = display.explorer.renderModel
now = 0.51
T.check(display.explorerModel(overview) ~= model, "encounter and progress snapshots refresh after half a second")
model = display.explorer.renderModel
display.explorer.scanFrame = 1
T.check(display.explorerModel(overview) ~= model, "scanning bypasses the motion cache")

display.explorer.scanFrame = value(display.advanceExplorerScan, "RADAR_FRAMES")
model = display.explorerModel(overview)
T.eq(display.explorerModel(overview), model, "completed scans reuse the model instead of rebuilding every map frame")
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
T.eq(frames, 300, "Explorer follows walking smoothly at 30 Hz")
world.player.px = 631
state.key = theme.hgss:explorerMotionKey(model, display.localMapPosition())
T.eq(display.updateMapRefresh(10), false, "standing still requests no render")
world.player.px = 631.01
T.eq(display.updateMapRefresh(10.1), false, "subpixel changes that render identically request no render")
world.player.facing = "left"
T.eq(display.updateMapRefresh(10.2), true, "turning refreshes the live player marker")
value(display.updateMapRefresh, "readbackPending", true, true)
world.player.px = 640
T.eq(display.updateMapRefresh(11), false, "slow readback cannot queue another map frame")
value(display.updateMapRefresh, "readbackPending", false, true)
T.eq(display.updateMapRefresh(11.1), true, "readback completion shows the latest player position")
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
local snapshot = display.explorer.mapSnapshot
T.eq(display.explorerModel(overview).player.x, world.player.px / 16, "model rebuilds use the current camera/player")
display.clearExplorerSnapshot()
T.eq(display.explorerModel(overview).player.x, world.player.px / 16, "reopening takes a fresh position")
T.check(display.explorer.mapSnapshot ~= snapshot, "reopening replaces the snapshot")
local nextMap = { mapId = "NEXT_MAP", width = 40, height = 36, rows = rows, markers = {} }
world.map.id = "NEXT_MAP"
T.eq(display.explorerModel(nextMap).player.mapId, "NEXT_MAP", "area change takes a fresh snapshot")
world.map.id = "FIX_ROUTE"
display.clearExplorerSnapshot()
do
  local oldActors = api.world.mapActors
  local actor = { id = "TRAINER", x = 4, y = 6, facing = "right", visible = true }
  api.world.mapActors = function() return { actor } end
  local options = run.loader.modOptions.kanto_gear or {}
  run.loader.modOptions.kanto_gear = options
  local oldMode = options.info_level
  options.info_level = "spoiler"
  local assist = value(display.explorerModel, "assist")
  display.explorer.data = { mapId = overview.mapId, at = now,
    guideEnabled = assist("guide"), areaEnabled = assist("area"), fruits = {},
    guide = { rows = {}, caught = 0 }, area = { sections = {
      { rows = { { id = actor.id, index = 1, mapId = overview.mapId, x = 1, y = 2 } } },
      { rows = {} }, { rows = {} } } } }
  display.explorer.renderModel = nil
  local captured = display.explorerModel(overview)
  T.eq(captured.markers[1].x, 4, "legacy trainer captures live position")
  actor.x, actor.y, actor.facing = 9, 10, "left"
  display.explorer.renderModel = nil
  local rebuilt = display.explorerModel(overview)
  T.eq(rebuilt.markers[1].x, 4, "legacy moving trainer keeps its captured position")
  T.eq(rebuilt.markers[1].actor.facing, "right", "legacy actor direction is copied, not shared")
  display.clearExplorerSnapshot()
  T.eq(display.explorerModel(overview).markers[1].x, 9, "legacy trainer refreshes on reopening")
  api.world.mapActors, options.info_level = oldActors, oldMode
  display.clearExplorerSnapshot()
  display.explorer.data = nil
end
local homeModel = { page = 1, overview = overview,
  tiles = { { widget = "explorer", column = 1, row = 1, columns = 7 } } }
-- The NOW window sits on the map; redraw sampling must use the exact layout
-- that is painted, including at fractional player positions, and a
-- movement-only repaint must put the window back on top of the map.
do
  local h = theme.hgss
  local drawMap, drawCorner = h.mapOverview, h.homeNowCorner
  local cornerDraws, layout = 0, nil
  h.mapOverview = function(self, ...)
    layout = drawMap(self, ...)
    return layout
  end
  h.homeNowCorner = function(self, ...)
    cornerDraws = cornerDraws + 1
    return drawCorner(self, ...)
  end
  for _, skin in ipairs({ "pokegear", "cgear" }) do
    h:setSkin(skin)
    for _, rail in ipairs({ false, true }) do
      homeModel.nowRows = rail and {} or nil
      homeModel.player = { mapId = "FIX_ROUTE", x = 12.375, y = 15.125, facing = "down" }
      h:homeExplorerMap(homeModel, homeModel.tiles[1])
      local pos = homeModel.player
      local expected = "HOME:" .. table.concat({ pos.mapId, layout.left, layout.top,
        math.floor(layout.left + pos.x * layout.tileSize + 0.5),
        math.floor(layout.top + pos.y * layout.tileSize + 0.5), pos.facing }, ":")
      T.eq(h:homeMotionKey(homeModel, pos), expected,
        skin .. " movement key matches the painted viewport with NOW=" .. tostring(rail))
      local before = cornerDraws
      h:homeExplorerMap(homeModel, homeModel.tiles[1], true)
      T.eq(cornerDraws, before + (rail and 1 or 0), "movement-only repaint keeps the NOW window on top")
    end
  end
  h.mapOverview, h.homeNowCorner = drawMap, drawCorner
  h:setSkin("pokegear")
  homeModel.nowRows, homeModel.player = nil, nil
end

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
  T.eq(count, 300, mode .. " keeps Home widgets smooth at 30 Hz")
  display.updateMapRefresh(10) -- Finish the player's final movement sample.
  state.key = theme.hgss:homeMotionKey(homeModel, display.localMapPosition())
  T.eq(display.updateMapRefresh(10.1), false, mode .. " widget requests no redraw while stationary")
end
world.player.facing = "up"
state.nextAt = 0
T.eq(display.updateMapRefresh(10.2), true, "live widget still refreshes turns")
value(display.updateMapRefresh, "readbackPending", true, true)
world.player.px = 640
T.eq(display.updateMapRefresh(11), false, "live widget respects pending readback")
value(display.updateMapRefresh, "readbackPending", false, true)
T.eq(display.updateMapRefresh(11.1), true, "live widget resumes with latest position")
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
model = display.explorerModel(overview)
local performanceFrames = 0
for frame = 0, 599 do
  world.player.px = 32 + frame
  if display.updateMapRefresh(frame / 60) then
    performanceFrames = performanceFrames + 1
    state.key = theme.hgss:explorerMotionKey(model, display.localMapPosition())
  end
end
T.eq(performanceFrames, 300, "Explorer also follows walking smoothly in performance mode")
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
T.eq(display.home.widgetCache, widgets, "walking retains a map-only Home snapshot")
display.homeWidgetData({ explorer = true, party = true })
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

-- Zoom is about walking-cell context, independent of terrain resolution.
-- Cover the room/route shapes that previously made all three levels useless.
for _, dark in ipairs({ false, true }) do
  theme.hgss:setVariant(dark)
  for _, dimensions in ipairs({ { 6, 6 }, { 10, 8 }, { 20, 12 }, { 28, 16 }, { 42, 18 },
      { 10, 100 }, { 100, 10 }, { 120, 120 }, { 512, 512 } }) do
    local w, h = unpack(dimensions)
    local camera = { mapId = "ZOOM", x = (w - 1) / 2, y = (h - 1) / 2 }
    local marker = { kind = "hidden", x = camera.x, y = camera.y }
    local terrainCalls, playerDraw = 0
    local map = { width = w, height = h, rows = {}, markers = { marker },
      drawTerrain = function() terrainCalls = terrainCalls + 1 end }
    for y = 1, h do map.rows[y] = string.rep(" ", w) end
    local scales = {}
    for _, density in ipairs({ 1, 2, 4 }) do
      map.tileRows, map.tileDetailRows = nil, nil
      if density == 2 then
        map.tileRows, map.tileWidth, map.tileHeight = {}, w * 2, h * 2
      elseif density == 4 then
        map.tileDetailRows, map.tileDetailWidth, map.tileDetailHeight = {}, w * 4, h * 4
      end
      for zoom = 1, 3 do
        local opts = { full = true, zoom = zoom, player = camera,
          drawPlayer = function(_, x, y) playerDraw = { x, y } end }
        local frame = { x = 7, y = 72, w = 226, h = 138 }
        local before = terrainCalls
        local layout = theme.hgss:mapOverview(map, frame.x, frame.y, frame.w, frame.h, opts)
        local size = layout.tileSize
        T.eq(terrainCalls, before + 1, "zoom draws cached native terrain once")
        if density == 1 then scales[zoom] = size end
        T.eq(size, scales[zoom], "source terrain resolution never changes zoom")
        if zoom == 1 then
          T.check(w * size <= layout.innerW + 1e-9 and h * size <= layout.innerH + 1e-9,
            "overview includes the entire area, even beyond 222 walking cells")
          T.check(math.abs(w * size - layout.innerW) < 1e-9
              or math.abs(h * size - layout.innerH) < 1e-9,
            "overview fills at least one viewport axis without a size cap or rounding loss")
        else
          T.check(size >= 6, "intermediate view keeps item markers readable")
          local detail = math.max(12, scales[1] * 1.5)
          if zoom == 2 then
            T.check(size > scales[1] and size < detail,
              "intermediate view stays between overview and detail on every map shape")
            T.check(detail / size >= math.sqrt(1.5) - 1e-9,
              "intermediate view shows meaningfully more area than detail")
            if scales[1] <= 6 then
              T.check(layout.innerW / size >= 24 and layout.innerW / size <= 37,
                "route overview shows a broad readable neighborhood")
            end
          else
            T.eq(size, detail, "detail preserves beta 57's useful second zoom level")
          end
        end
        T.check(math.abs(layout.left + w * size / 2 - (frame.x + frame.w / 2)) <= 0.5
            and math.abs(layout.top + h * size / 2 - (frame.y + frame.h / 2)) <= 0.5,
          "centered terrain has equal visible margins within one pixel")
        T.eq(theme.hgss:mapMarkerAt(layout.left + (marker.x + .5) * size,
            layout.top + (marker.y + .5) * size, map, frame, opts), 1,
          "touch selects the marker at its drawn position at every zoom")
        T.check(math.abs(playerDraw[1] - (layout.left + (camera.x + .5) * size)) <= 0.5 + 1e-9,
          "player anchor remains aligned with terrain")
        for _, edge in ipairs({ { 0, 0 }, { w - 1, h - 1 } }) do
          camera.x, camera.y = unpack(edge)
          local atEdge = theme.hgss:mapOverview(map, frame.x, frame.y, frame.w, frame.h, opts)
          T.check(playerDraw[1] >= atEdge.innerX and playerDraw[1] < atEdge.innerX + atEdge.innerW
              and playerDraw[2] > atEdge.innerY and playerDraw[2] <= atEdge.innerY + atEdge.innerH + 1,
            "camera keeps the player visible at either map corner")
          if w * size > atEdge.innerW then
            T.check(atEdge.left <= atEdge.innerX
                and atEdge.left + w * size >= atEdge.innerX + atEdge.innerW,
              "cropped camera exposes no empty horizontal border")
          end
          if h * size > atEdge.innerH then
            T.check(atEdge.top <= atEdge.innerY
                and atEdge.top + h * size >= atEdge.innerY + atEdge.innerH,
              "cropped camera exposes no empty vertical border")
          end
        end
        camera.x, camera.y = (w - 1) / 2, (h - 1) / 2
      end
      for _, viewport in ipairs({ { 226, 84 }, { 226, 42 }, { 110, 75 } }) do
        local layout = theme.hgss:mapOverview(map, 7, 53, viewport[1], viewport[2], { player = camera })
        T.eq(layout.tileSize, 8, "widget and compact/detail panel retain the same readable scale")
      end
    end
  end
end
-- A frozen viewport is rasterized once; unrelated redraws only blit it.
do
  local draws = 0
  local map = { mapId = "CACHE", width = 40, height = 36, rows = rows,
    drawTerrain = function() draws = draws + 1 end }
  local snapshot = {}
  local playerDraws, playerX = 0, nil
  local opts = { snapshot = snapshot, cacheKey = "initial", player = { x = 2, y = 3 }, zoom = 2,
    drawPlayer = function(_, x) playerDraws, playerX = playerDraws + 1, x end }
  local target = love.graphics.newCanvas(240, 216)
  love.graphics.setCanvas(target)
  theme.hgss:mapOverview(map, 7, 53, 226, 84, opts)
  local canvas = snapshot.canvas
  for _ = 1, 30 do theme.hgss:mapOverview(map, 7, 53, 226, 84, opts) end
  T.eq(draws, 1, "unchanged snapshot renders terrain once across 31 redraws")
  T.eq(snapshot.canvas, canvas, "snapshot reuses its small viewport canvas")
  T.eq(canvas:getWidth(), 227, "cache allocates viewport plus shadow, never world width")
  T.eq(love.graphics.getCanvas(), target, "snapshot rendering restores the host target")
  T.eq(playerDraws, 31, "live player is composited on each frame")
  local previousX = playerX
  opts.player.x = 2.5
  theme.hgss:mapOverview(map, 7, 53, 226, 84, opts)
  T.eq(draws, 1, "player moves over cached terrain when camera stays still")
  T.check(playerX ~= previousX, "cached terrain never freezes the live player")
  opts.player.x, opts.player.y = 25, 20
  theme.hgss:mapOverview(map, 7, 53, 226, 84, opts)
  T.eq(draws, 2, "camera follows player and refreshes its visible terrain")
  T.eq(snapshot.canvas, canvas, "camera movement reuses the allocated viewport")
  opts.cacheKey, opts.zoom = "zoom", 3
  theme.hgss:mapOverview(map, 7, 53, 226, 84, opts)
  T.eq(draws, 3, "intentional zoom change redraws the map once")
  T.eq(snapshot.canvas, canvas, "zoom reuses the same viewport allocation")
  theme.hgss:mapOverview(map, 7, 53, 226, 138, opts)
  T.check(canvas.released, "resizing the viewport releases its old allocation")
  display.explorer.mapSnapshot = snapshot
  display.clearExplorerSnapshot()
  T.check(snapshot.canvas.released, "closing/reopening releases the viewport cache")
  love.graphics.setCanvas()
end
-- The corner portrait clips in physical pixels and preserves its parent clip.
do
  local G = love.graphics
  local saved = { push = G.push, pop = G.pop, transformPoint = G.transformPoint,
    intersectScissor = G.intersectScissor }
  local parent, current, stack, clipped = { 0, 0, 400, 300 }, nil, {}, nil
  current = parent
  G.push = function(mode)
    T.eq(mode, "all", "corner saves all graphics state")
    stack[#stack + 1] = current
  end
  G.pop = function() current = table.remove(stack) end
  G.transformPoint = function(x, y) return 11 + x * 3, 17 + y * 3 end
  G.intersectScissor = function(x, y, w, h)
    clipped = { x, y, w, h }; current = clipped
  end
  local drawn = 0
  theme.hgss:homeNowCorner({ nowRows = { {}, {} }, drawNowIcon = function()
    drawn = drawn + 1
    T.eq(current, clipped, "portrait draws inside the corner clip")
  end }, 10, 20, 80, 60)
  T.eq(drawn, 1, "corner draws one portrait")
  -- the portrait now sits in a rail right of the map (map 10,20,80,60):
  -- a 26px window at (95,31) in Gear pixels
  T.eq(clipped[1], 296, "corner clip follows horizontal display transform")
  T.eq(clipped[2], 110, "corner clip follows vertical display transform")
  T.eq(clipped[3], 78, "corner clip scales its width")
  T.eq(clipped[4], 78, "corner clip scales its height")
  T.eq(current, parent, "corner restores the surrounding map clip")
  T.eq(#stack, 0, "corner balances graphics pushes")
  for name, fn in pairs(saved) do G[name] = fn end
  G.transformPoint, G.intersectScissor = saved.transformPoint, saved.intersectScissor
end
run.release()
T.finish("Kanto Gear map motion")
