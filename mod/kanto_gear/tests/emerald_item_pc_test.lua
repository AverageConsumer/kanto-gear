local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
_G.KANTO_GEAR_RENDER_CAPTURE = function(_, display, raw)
  local Runtime = require("src.core.game3.runtime")
  local game, originalInput = Runtime._game, raw.input
  Runtime._game = raw
  raw.input = { pressQueue = {}, sourcePress = function(self, key) self.pressQueue[#self.pressQueue + 1] = key end,
    sourceRelease = function() end }
  assert(loadfile(path .. "/tests/pc_items_gen3_cases.lua"))()(T, display, raw)
  Runtime._game, raw.input = game, originalInput
end
dofile(path .. "/tests/gen3_fixture.lua")
