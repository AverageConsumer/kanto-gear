local T = require("tests.modkit")
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local run = T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")),
  { generation = generation, data = T.fixtures.fresh() })
T.eq(run.mod and run.mod.state, "loaded", "phone prototype loads as a complete mod")
local function hook(name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local world = { map = { id = "PALLET_TOWN" } }
local game = { mods = run.loader, data = run.data, world = world, overworld = world,
  input = { pressQueue = {}, held = {} },
  save = { generation = generation, player = { name = "RED", id = 7, map = "PALLET_TOWN" },
    party = {}, inventory = {}, boxes = {}, pokedex = { seen = {}, caught = {} } },
  stack = { states = { world }, top = function(self) return self.states[#self.states] end } }
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", display_mode = "phone",
  display_target = "handheld", screen_swap = true, ui_motion = false }
run.loader.events:emit("game.ready", { game = game })
local compose, update = hook("render.compose"), hook("core.update")
local display = up(compose, "displayRuntime")
local available, acknowledged, capture, pushed, stopped, now = false, false, true, 0, 0, 1
love.timer.getTime = function() return now end
local queue = {}
local phone = {
  setGame = function(_, bound) T.eq(bound, game, "phone controls bind the real game input") end,
  step = function() end, poll = function() end, detected = function() return available end,
  ready = function() return available and acknowledged end,
  canCapture = function() return available and capture end,
  reserveCapture = function() return available and capture end,
  stop = function() stopped = stopped + 1 end,
}
phone.bridge = {
  detected = phone.detected, setEnabled = function() end,
  pollTouch = function() return table.remove(queue, 1) end,
  push = function() pushed = pushed + 1; return phone.ready() end,
}
display.phone, display.phoneStatus = phone, phone
up(compose, "page", "NOTES", true)
local sourceSteps = 0
phone.step = function(_, dt) sourceSteps = sourceSteps + 1; T.eq(dt,1/60,"source timestamp uses Recomp's fixed step") end
hook("input.step")(function() end, game, 1/60)
T.eq(sourceSteps,1,"phone capture clock advances once per game input step")
local canvas = up(up(compose, "pumpDisplay"), "canvas")
canvas.requestImageData, canvas.pollImageData = nil, nil
local captures = 0
canvas.newImageData = function() captures = captures + 1; return {} end
local enabled, nativePush, nativeTouch = {}, 0, 0
local native = { detected = function() return true end,
  setEnabled = function(value) enabled[#enabled + 1] = value end,
  push = function() nativePush = nativePush + 1; return true end,
  pollTouch = function() nativeTouch = nativeTouch + 1 end }
local context = { secondScreen = native }
local sentinel = {}
local function next() return sentinel end
local statusDraws, viewport = 0, { width = 640, height = 576 }
display.Phone = { drawStatus = function(state, graphics, context)
  T.eq(state, phone, "HUD receives the live phone status")
  T.eq(graphics, love.graphics, "HUD uses the host graphics context")
  T.eq(context, viewport, "HUD keeps the host viewport geometry")
  statusDraws = statusDraws + 1
end }
T.eq(hook("render.hud")(next, game, viewport), sentinel,
  "pairing HUD preserves the host return value")
T.eq(statusDraws, 1, "pairing status is drawn without a render.window capture")
local function frame()
  T.eq(update(next, game, 1 / 60), sentinel, "phone update preserves the host return value")
  T.eq(compose(next, {}, context), sentinel, "phone composition preserves the host return value")
  now = now + .06
end
frame()
T.eq(enabled[1], false, "phone mode disables the physical companion display")
T.eq(captures, 0, "no viewer means no image readback")
T.check(not up(compose, "hasDisplay")(), "a physical display cannot masquerade as the phone")
T.check(not up(compose, "inlineDisplay")(), "phone mode keeps the game viewport intact")
T.check(not up(compose, "bottomOnHandheld")(), "saved handheld preference cannot move Gear onto the game screen")
available = true; frame()
T.check(pushed > 0, "Gear's existing canvas reaches the phone transport")
T.eq(up(compose, "displayReady"), false, "native UI stays present until the browser acknowledges its frame")
acknowledged = true; frame()
T.eq(up(compose, "displayReady"), true, "an acknowledged browser becomes a usable display")
T.eq(nativePush, 0, "phone frames never reach the native companion")
T.eq(nativeTouch, 0, "phone mode never consumes physical display touches")
local before = captures
capture = false; up(compose, "dirty", true, true); frame()
T.eq(captures, before, "backpressure prevents readback work before it happens")
T.eq(up(compose, "dirty"), true, "the newest dirty frame remains available")
local pending, requests = false, 0
canvas.requestImageData = function() pending = true; requests = requests + 1; return true end
canvas.pollImageData = function() if pending then pending = false; return {} end end
phone.bridge.push = function() capture = false; return true end
capture = true
up(compose, "nextPresentAttempt", 0, true)
local pump = up(compose, "pumpDisplay")
pump()
T.eq(requests, 1, "the async path requests one allowed frame")
up(compose, "dirty", true, true)
pump()
T.eq(requests, 1, "a full transport window prevents another GPU request")
T.eq(up(compose, "dirty"), true, "async backpressure also retains the latest scene change")
capture = true
phone.bridge.push = function() pushed = pushed + 1; return true end
local beforeRequests = requests
for _ = 1, 60 do
  up(compose, "dirty", true, true)
  pump()
  now = now + 1 / 60
end
T.eq(requests - beforeRequests, 60, "readback completion can reserve the next capture on the same host frame")
up(compose, "page", "HOME", true)
up(compose, "nextPoll", now + 1, true)
queue[#queue + 1] = "cancel,0,0"
frame()
T.eq(#queue, 0, "phone input is drained between the slower game snapshot ticks")
display.mapRefresh.nextAt = now
up(pump, "readbackPending", true, true)
display.updateMapRefresh(now)
T.check(math.abs(display.mapRefresh.nextAt - now - 1 / 60) < .000001,
  "phone map movement refreshes at sixty Hz even during a pending GPU readback")
display.mapRefresh.nextAt = now + .002
display.updateMapRefresh(now)
T.check(math.abs(display.mapRefresh.nextAt - now - .002 - 1 / 60) < .000001,
  "a slightly early host tick cannot skip a phone map refresh")
phone.bridge.push = function() return phone.ready() end
available = false; frame()
T.eq(up(compose, "displayReady"), false, "disconnect immediately restores native menu eligibility")
T.eq(up(compose, "touchDown"), nil, "disconnect clears held touch state")
run.loader.modOptions.kanto_gear.display_mode = "combined"; frame()
T.eq(stopped, 1, "changing display mode closes the phone server")
T.eq(display.phone, nil, "changing mode removes the phone bridge")
local Manager = require("src.mods.ManagerState")
game.save.options = { modOptions = run.loader.modOptions }
local manager = Manager.new(game)
manager.notify = function() end
local api = up(display.saveHome, "mod")
for _, mode in ipairs({ "fullscreen", "combined", "separate" }) do
  api.options:set("display_mode", "phone")
  display.phone, display.phoneStatus = phone, phone
  local previous = stopped
  manager:setOption("kanto_gear", "display_mode", mode)
  display.updatePhone()
  T.eq(stopped, previous + 1, "native recovery to " .. mode .. " closes the server without a phone")
  T.eq(display.phoneStatus, nil, "native recovery clears pairing UI")
end
api.options:set("display_mode", "phone")
display.phone, display.phoneStatus = phone, phone
local previous = stopped
for _, row in ipairs(manager:buildOptionRows({ id = "kanto_gear" }, run.loader.optionSchemas.kanto_gear)) do
  if row.id == "__reset" then row.activate() end
end
display.updatePhone()
T.eq(stopped, previous + 1, "native Reset Defaults shuts down the wireless server")
T.eq(api.options:get("display_mode"), "separate", "native reset restores local Gear output")
previous = stopped
display.phone, display.phoneStatus = phone, phone
T.eq(hook("core.quit_to_launcher")(next), sentinel, "returning to the launcher preserves its result")
T.eq(stopped, previous + 1, "returning to the launcher closes the listening socket")
T.eq(#run.errors, 0, "phone lifecycle leaves no loader errors")
run.release()
T.finish("Kanto Gear phone runtime Gen " .. generation)
