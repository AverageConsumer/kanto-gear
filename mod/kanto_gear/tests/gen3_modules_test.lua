local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  dofile(path .. "/tests/third_party_modules_cases.lua")(T, run, display, game, 3)
end
dofile(path .. "/tests/gen3_fixture.lua")
