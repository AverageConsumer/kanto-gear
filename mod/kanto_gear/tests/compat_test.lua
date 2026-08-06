package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local newCanvas = T.love.graphics.newCanvas
T.love.graphics.newCanvas = function(...)
  local canvas = newCanvas(...)
  function canvas:requestImageData() return true end
  function canvas:pollImageData() return nil end
  return canvas
end
local run = T.sdk.loadMod(path, { data = T.fixtures.load() })
T.love.graphics.newCanvas = newCanvas

T.eq(#run.errors, 0,
  "Kanto Gear loads clean: " .. table.concat(run.errors, "; "))
T.check(run.loader.exports.kanto_gear ~= nil, "Kanto Gear registers")
local options = run.loader.optionSchemas.kanto_gear
T.eq(#options, 6, "Kanto Gear keeps its settings compact")
T.eq(options[1].label, "THEME", "theme setting is device-neutral")
T.eq(options[2].label, "INFO", "assist features use one preset")
T.eq(options[4].label, "GEAR SCREEN", "display setting is device-neutral")
T.eq(options[5].label, "BATTLE VIEW", "battle layout uses one setting")
T.eq(#options[5].choices, 3, "battle view exposes three clear layouts")
T.eq(options[6].label, "CAUGHT ICON", "caught marker has one clear toggle")
local hooks = T.record.hooks(run.loader)
T.eq(hooks:depth("render.compose"), 1,
  "Kanto Gear uses the upstream composition seam")
T.eq(hooks:depth("render.output"), 1,
  "Kanto Gear owns final output only for a live screen swap")
T.eq(hooks:depth("input.touchpressed"), 1,
  "Kanto Gear can own primary touch while swapped")
T.eq(hooks:depth("render.letterbox"), 0,
  "Kanto Gear no longer borrows the letterbox hook as a frame tick")
local composed = run.loader.hooks:call("render.compose",
  function() return "upstream" end, {}, {
    secondScreen = { detected = function() return false end,
                     pollTouch = function() return nil end },
  })
T.eq(composed, "upstream", "Kanto Gear preserves the upstream compositor result")

local displayDetected = true
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = { detected = function() return displayDetected end,
                   pollTouch = function() return nil end },
})
local swapPressed = true
local game = {
  data = run.data,
  save = { player = {} },
  input = { wasPressed = function(_, action)
    return action == "screen_swap" and swapPressed
  end },
}
run.loader.events:emit("game.ready", { game = game })
T.eq(run.loader.hooks:call("battle.caught_marker_visible",
  function() return false end, {}), true,
  "Kanto Gear shows its caught icon by default")
run.loader.modOptions.kanto_gear = { caught_icon = false }
T.eq(run.loader.hooks:call("battle.caught_marker_visible",
  function() return true end, {}), true,
  "disabling Kanto's icon preserves another mod's marker")
T.eq(run.loader.hooks:call("battle.caught_marker_visible",
  function() return false end, {}), false,
  "disabling Kanto's icon does not force the native marker")
run.loader.modOptions.kanto_gear.caught_icon = true
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
swapPressed = false
T.eq(run.loader.hooks:call("render.output_enabled",
  function() return false end), true,
  "the screen-swap action enables swapped output while connected")
displayDetected = false
T.eq(run.loader.hooks:call("render.output_enabled",
  function() return false end), false,
  "disconnect bypasses swapped output immediately")

local Input = require("src.core.Input")
Input:init()
Input:keypressed("f6")
Input:step()
T.check(Input:wasPressed("screen_swap"), "F6 maps to screen swap")

run.release()
T.finish("Kanto Gear compatibility")
