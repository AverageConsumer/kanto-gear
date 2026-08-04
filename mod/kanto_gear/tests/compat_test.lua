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
local hooks = T.record.hooks(run.loader)
T.eq(hooks:depth("render.compose"), 1,
  "Kanto Gear uses the upstream composition seam")
T.eq(hooks:depth("render.letterbox"), 0,
  "Kanto Gear no longer borrows the letterbox hook as a frame tick")
local composed = run.loader.hooks:call("render.compose",
  function() return "upstream" end, {}, {
    secondScreen = { detected = function() return false end,
                     pollTouch = function() return nil end },
  })
T.eq(composed, "upstream", "Kanto Gear preserves the upstream compositor result")

run.release()
T.finish("Kanto Gear compatibility")
