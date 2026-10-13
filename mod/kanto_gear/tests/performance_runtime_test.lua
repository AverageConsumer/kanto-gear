package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
T.love.graphics.arc = T.love.graphics.arc or function() end
T.love.graphics.polygon = T.love.graphics.polygon or function() end
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local run = T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")),
  { generation = generation, data = T.fixtures.fresh() })
T.eq(run.mod and run.mod.state, "loaded", "diagnostic mod loads")
local function hook(name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local world = { map = { id = "PALLET_TOWN" } }
local game = { data = run.data, world = world, overworld = world,
  save = { generation = generation, player = { name = "RED", id = 7, map = "PALLET_TOWN" },
    party = {}, inventory = {}, boxes = {}, pokedex = { seen = {}, caught = {} } },
  stack = { states = { world }, top = function(self) return self.states[#self.states] end } }
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", display_mode = "separate",
  display_target = "secondary", ui_motion = false }
run.loader.events:emit("game.ready", { game = game })
local display = up(hook("input.step"), "displayRuntime")
T.eq(display.perf.enabled, false, "public releases disable diagnostic recording")
display.perf.enabled = true -- Exercise the optional recorder explicitly.
display.home.help = false
local now = 1
T.love.timer.getTime = function() return now end
local compose, pump = hook("render.compose"), up(hook("render.compose"), "pumpDisplay")
local canvas = up(pump, "canvas")
local pending, presented = false, 0
canvas.requestImageData = function() now = now + 0.002; pending = true; return true end
canvas.pollImageData = function()
  now = now + 0.003
  if pending then pending = false; return {} end
end
up(compose, "companion", { push = function(_, width, height)
  now = now + 0.004; presented = presented + 1
  T.eq(width, 240, "diagnostics preserve native Gear width")
  T.eq(height, 216, "diagnostics preserve native Gear height")
  return true
end })
up(pump, "dirty", true)
pump()
T.eq(presented, 0, "async request does not prematurely present")
pump()
T.eq(presented, 1, "ready frame is presented once")
local metrics = display.perf.metrics
T.eq(metrics.gear_draw.n, 1, "draw work is recorded only when drawing")
T.check(math.abs(metrics.readback_request.total - 2) < 0.0001, "request timing is isolated")
T.check(math.abs(metrics.readback_poll.total - 3) < 0.0001, "poll timing is isolated")
T.check(math.abs(metrics.present.total - 4) < 0.0001, "Android bridge timing is isolated")
T.eq(display.perf.bytes, 240 * 216 * 4, "transport counter matches submitted dimensions")
canvas.requestImageData, canvas.pollImageData = nil, nil
canvas.newImageData = function() now = now + 0.007; return {} end
up(pump, "dirty", true)
pump()
T.check(math.abs(metrics.readback_sync.total - 7) < 0.0001, "legacy synchronous fallback is measured separately")
local before = now
local sentinel = {}
T.eq(compose(function() now = now + 0.010; return sentinel end, {}, {}), sentinel,
  "composition preserves downstream return value")
T.check(now - before >= 0.010, "downstream host work was executed")
T.check(metrics.gear_compose.max < 0.0001, "downstream time is not blamed on Gear")
T.eq(#run.errors, 0, "diagnostics produce no runtime errors")
-- The compose hook, not redraws or touch calls, owns album scheduling.
display.achievementData()
local advances = 0
display.achievements.job.step = function() advances = advances + 1 end
local connected = true
local context = { secondScreen = { detected = function() return connected end,
  pollTouch = function() end, push = function() return true end } }
up(compose, "nextPoll", math.huge)
up(compose, "page", "ACHIEVEMENTS")
compose(function() end, {}, context)
T.eq(advances, 1, "visible album receives one work slice per compose")
compose(function() end, {}, context)
T.eq(advances, 2, "album advances independently of a redraw request")
up(compose, "page", "HOME")
compose(function() end, {}, context)
T.eq(advances, 2, "leaving Stamps pauses album work")
up(compose, "page", "ACHIEVEMENTS")
connected = false
now = now + 0.051 -- Hardware discovery has a shared 50ms cache.
compose(function() end, {}, context)
T.eq(advances, 2, "disconnected display pauses album work")
connected = true
now = now + 0.051
game.stack.states[2] = { isTextBox = true }
compose(function() end, {}, context)
T.eq(advances, 2, "game dialogue pauses hidden album work")
game.stack.states[2] = nil
compose(function() end, {}, context)
T.eq(advances, 3, "returning to visible Stamps resumes the same job")
local input = hook("input.step")
input(function() now = now + 0.010; return sentinel end, game, 1 / 60)
T.check(metrics.gear_input.n > 0, "diagnostics include work in the input hook")
T.check(metrics.gear_input.max < 0.0001, "host simulation time is excluded from Gear input")
do
  local api = up(input, "mod")
  local originalWorld, calls, available = api.world, 0, {}
  api.world = { current = function() end, availableFieldActions = function()
    calls = calls + 1
    return available
  end }
  local home = display.home
  home.layout = { tiles = {
    { id = "explorer_widget", page = 1, column = 1, row = 1 },
    { id = "tool_widget_old_rod", page = 2, column = 1, row = 1 },
  } }
  home.page, home.editing, home.library = 1, false, false
  game.stack.states = { world }
  up(compose, "page", "HOME")
  local function poll()
    now = now + 0.06
    up(compose, "nextPoll", 0)
    compose(function() end, {}, context)
  end
  for _ = 1, 3 do poll() end
  T.eq(calls, 0, "Home does not query field actions for an off-page tool widget")
  home.page = 2
  game.save.inventory.OLD_ROD = 1
  available = { { id = "fish", label = "FISH", rods = { { id = "OLD_ROD" } } } }
  poll()
  local surface = display.homeCatalog.surfaces.tool_widget_old_rod
  T.eq(calls, 1, "a visible tool widget retains the normal poll cadence")
  T.check(surface.ready, "the visible rod becomes ready in the same poll")
  available = {}
  poll()
  T.check(not surface.ready, "the visible rod stops being ready as soon as context changes")
  home.page, home.library = 1, true
  T.check(display.needsTools(), "the widget library still refreshes field unlocks")
  home.library, home.editing = false, true
  T.check(display.needsTools(), "editing still refreshes field unlocks")
  home.editing = false
  local before = calls
  display.openHomeApp("tools")
  T.eq(calls, before + 1, "opening Field Kit refreshes before its first paint")
  poll()
  T.eq(calls, before + 2, "Field Kit retains its normal live updates")
  api.world = originalWorld
end
T.finish("Kanto Gear performance runtime Gen " .. generation)
