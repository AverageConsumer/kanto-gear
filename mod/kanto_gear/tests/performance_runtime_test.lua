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
local function up(fn, key, replacement)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, i)
    if name == key then
      if replacement ~= nil then debug.setupvalue(fn, i, replacement) end
      return value
    end
  end
  error("Missing upvalue " .. key)
end
local world = { map = { id = "PALLET_TOWN" } }
local game = { data = run.data, world = world, overworld = world,
  save = { generation = generation, player = { name = "RED", id = 7, map = "PALLET_TOWN" },
    party = {}, inventory = {}, boxes = {}, pokedex = { seen = {}, caught = {} } },
  stack = { states = { world }, top = function(self) return self.states[#self.states] end } }
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", display_mode = "separate",
  display_target = "secondary", ui_motion = false }
run.loader.events:emit("game.ready", { game = game })
local display = up(hook("input.step"), "displayRuntime")
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
T.finish("Kanto Gear performance runtime Gen " .. generation)
