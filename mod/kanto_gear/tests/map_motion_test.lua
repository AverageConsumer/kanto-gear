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
T.love.timer.getTime = time
run.release()
T.finish("Kanto Gear map motion")
