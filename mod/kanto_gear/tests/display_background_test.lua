package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
love.graphics.arc = love.graphics.arc or function() end
love.graphics.polygon = love.graphics.polygon or function() end
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GENERATION")) or 2
local run = T.sdk.loadMod(os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear",
  { generation = generation, data = T.fixtures.load() })
local function hook(id)
  for _, entry in ipairs(run.loader.hooks.chains[id] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local function up(fn, target, replacement)
  for index = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, index)
    if name == target then
      if replacement ~= nil then debug.setupvalue(fn, index, replacement) end
      return value
    end
  end
  error("Missing upvalue " .. target)
end
local world = { map = { id = "PALLET_TOWN" } }
local game = { data = run.data, world = world,
  save = { generation = generation,
    player = { name = "RED", id = 7, map = "PALLET_TOWN" },
    party = {}, inventory = {}, boxes = {}, pokedex = { seen = {}, caught = {} } },
  stack = { states = { world }, top = function(self) return self.states[#self.states] end } }
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", display_mode = "separate",
  display_target = "secondary", ui_motion = false }
run.loader.events:emit("game.ready", { game = game })
local compose = hook("render.compose")
local display = up(hook("input.step"), "displayRuntime")
local theme = up(display.drawContents, "THEME")
local function channels(packed)
  return { math.floor(packed / 65536), math.floor(packed / 256) % 256, packed % 256 }
end
local function checkShade(base, shaded, brightness, label)
  for i, value in ipairs(channels(base)) do
    T.check(math.abs(channels(shaded)[i] - value * brightness) <= 1, label)
  end
end
for _, style in ipairs({ "hgss", "hgss_dark", "classic" }) do
  run.loader.modOptions.kanto_gear.theme_v3 = style
  run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = style })
  display.home.help = false
  game.stack.states = { world }
  display.drawContents()
  local bright = display.backgroundColor()
  T.eq(display.backgroundDim, 0, style .. " active screen leaves borders bright")
  game.stack.states[2] = { screenId = "Gen2InitClock", mode = "day" }
  display.drawContents()
  checkShade(bright, display.backgroundColor(), 0.42, style .. " locked screen dims every border channel")
  game.stack.states[2] = { isTextBox = true }
  display.drawContents()
  checkShade(bright, display.backgroundColor(), 0.42, style .. " dialogue dims borders")
  game.stack.states = { world }
  display.drawContents()
  T.eq(display.backgroundColor(), bright, style .. " closing the dialog restores borders")
end

run.loader.modOptions.kanto_gear.theme_v3 = "hgss"
run.loader.modOptions.kanto_gear.ui_motion = true
run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = "hgss" })
run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "ui_motion", value = true })
display.home.help = false
local now = 10
love.timer.getTime = function() return now end
game.stack.states = { world }
display.prepareMotion(); display.drawContents()
local bright = display.backgroundColor()
game.stack.states[2] = { isTextBox = true }
display.prepareMotion(); display.drawContents(); display.applyMotion()
T.eq(display.backgroundColor(), bright, "fade begins with the previous frame's border")
now = now + display.motion.duration / 2
display.drawContents(); display.applyMotion()
checkShade(bright, display.backgroundColor(), 0.71, "border follows the half-faded frame")
now = now + display.motion.duration
display.drawContents(); display.applyMotion()
checkShade(bright, display.backgroundColor(), 0.42, "border reaches the fully dimmed frame")
run.loader.modOptions.kanto_gear.ui_motion = false

-- Delayed readback must present the border belonging to the captured image,
-- even when a newer frame has already changed the live drawing state.
local pump = up(compose, "pumpDisplay")
local canvas = up(pump, "canvas")
local pending, presented
canvas.requestImageData = function() pending = true; return true end
canvas.pollImageData = function() if pending then pending = false; return {} end end
up(compose, "companion", { push = function(_, _, _, background)
  presented = background; return true
end })
game.stack.states = { world, { isTextBox = true } }
up(pump, "dirty", true)
pump()
local captured = display.backgroundColor()
game.stack.states = { world }
display.drawContents()
T.check(display.backgroundColor() ~= captured, "newer active frame has brighter borders")
pump()
T.eq(presented, captured, "async border stays paired with the dimmed image")

-- The synchronous desktop transport uses the same rendered border.
canvas.requestImageData, canvas.pollImageData = nil, nil
canvas.newImageData = function() return {} end
game.stack.states = { world, { isTextBox = true } }
up(pump, "dirty", true)
pump()
T.eq(presented, display.backgroundColor(), "synchronous transport submits dimmed borders")

local output = hook("render.output")
up(output, "bottomOnHandheld", function() return true end)
up(output, "hasDisplay", function() return true end)
up(output, "nextGameCapture", now + 100)
up(output, "dirty", false)
local cleared, clear = nil, love.graphics.clear
love.graphics.clear = function(r, g, b) cleared = { r, g, b } end
T.eq(output(function() return false end,
  { canvas = canvas, width = 1240, height = 1080 }), true,
  "swapped handheld output presents the companion")
love.graphics.clear = clear
for i, value in ipairs(cleared or {}) do
  T.check(math.abs(value - up(output, "PAPER")[i] * 0.42) < 0.00001,
    "swapped handheld output dims the full window background")
end
T.eq(#run.errors, 0, "background rendering completes without mod errors")
run.release()
T.finish("Kanto Gear display borders Gen " .. generation)
