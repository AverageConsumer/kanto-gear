-- Real mod/SDK hooks; the bridge counts expensive host crossings, not GPU time.
local T = require("tests.modkit")
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local run = T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")),
  { generation = generation, data = T.fixtures.fresh() })
T.eq(run.mod and run.mod.state, "loaded", "idle test loads the complete mod")
local function hook(name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local world = { map = { id = "PALLET_TOWN" } }
local game = { data = run.data, world = world, overworld = world,
  input = { pressQueue = {}, held = {} },
  save = { generation = generation, player = { name = "RED", id = 7, map = "PALLET_TOWN" },
    party = {}, inventory = {}, boxes = {}, pokedex = { seen = {}, caught = {} } },
  stack = { states = { world }, top = function(self) return self.states[#self.states] end } }
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", display_mode = "separate",
  display_target = "secondary", ui_motion = false }
run.loader.events:emit("game.ready", { game = game })
local compose, input = hook("render.compose"), hook("input.step")
local display = up(input, "displayRuntime")
display.home.help = false
up(compose, "page", "NOTES")
local now, connected = 1, true
T.love.timer.getTime = function() return now end
local enabledCalls, detects, presents, draws = 0, 0, 0, 0
local bridge = {
  setEnabled = function() enabledCalls = enabledCalls + 1 end,
  detected = function() detects = detects + 1; return connected end,
  pollTouch = function() end,
  push = function() presents = presents + 1; return true end,
}
local canvas = up(up(compose, "pumpDisplay"), "canvas")
canvas.requestImageData, canvas.pollImageData = nil, nil
canvas.newImageData = function() draws = draws + 1; return {} end
local context = { secondScreen = bridge }
local sentinel = {}
local function downstream() return sentinel end
local function frame()
  input(downstream, game, 1 / 60)
  T.eq(compose(downstream, {}, context), sentinel, "idle composition preserves host result")
end
frame()
local started = os.clock()
for i = 1, 600 do now = 1 + i / 60; frame() end
print(string.format("IDLE gen=%d frames=601 enable=%d detect=%d readbacks=%d presents=%d hook_cpu_ms=%.3f",
  generation, enabledCalls, detects, draws, presents, (os.clock() - started) * 1000))
if os.getenv("KANTO_GEAR_BENCH_ONLY") == "1" then
  T.eq(#run.errors, 0, "baseline loop runs without errors")
  T.finish("idle baseline")
  return
end
T.eq(enabledCalls, 1, "unchanged enabled display does not enqueue UI-thread work every frame")
T.check(detects <= 201, "hardware discovery is bounded to 20 Hz across every hook")
T.check(draws < 10, "unchanged page does not read back every frame")
local before = enabledCalls
connected = false
now = 12; frame()
for i = 1, 120 do now = 12 + i / 60; frame() end
T.check(enabledCalls - before <= 3, "missing display retries at most once per second")
connected = true
now = 15; frame()
T.check(up(compose, "hasDisplay")(), "hotplug is discovered without navigating")
before = enabledCalls
for i = 1, 120 do now = 15 + i / 60; frame() end
T.eq(enabledCalls, before, "successful hotplug stops retries")
-- Inline output disables the external bridge once, including on Android.
run.loader.modOptions.kanto_gear.display_mode = "combined"
before = enabledCalls
for i = 1, 60 do now = 18 + i / 60; frame() end
T.eq(enabledCalls - before, 1, "inline mode disables the native bridge only once")
run.loader.modOptions.kanto_gear.display_mode = "separate"
now = 20; frame()
T.eq(enabledCalls - before, 2, "returning to separate mode re-enables the bridge immediately")
local secondCalls = 0
context.secondScreen = { setEnabled = function() secondCalls = secondCalls + 1 end,
  detected = function() return true end, pollTouch = function() end, push = bridge.push }
now = 21; frame()
T.eq(secondCalls, 1, "a replacement bridge receives its own initial enable")
context.secondScreen.push = function() return false end
up(compose, "dirty", true)
before = secondCalls
for i = 1, 120 do now = 22 + i / 60; frame() end
T.check(secondCalls - before >= 1 and secondCalls - before <= 3,
  "candidate display with a failed presentation retains bounded recovery")
context.secondScreen.push = bridge.push
now = 25; frame()
before = secondCalls
for i = 1, 120 do now = 25 + i / 60; frame() end
T.eq(secondCalls, before, "successful presentation stops recovery without lowering frame rates")
T.eq(#run.errors, 0, "lifecycle changes leave no mod errors")
run.release()
T.finish("Kanto Gear idle bridge Gen " .. generation)
