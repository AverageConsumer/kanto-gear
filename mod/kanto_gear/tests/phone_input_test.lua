-- Exercise remote holds against the host's actual Input and public mod API.
local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local run = T.sdk.loadMod(root, { generation = 2, data = T.fixtures.fresh() })
T.eq(run.mod and run.mod.state, "loaded", "controller build loads")
local api = run.loader:_api(assert(run.mod))
local Phone = assert(loadfile(root .. "/phone/display.lua"))()
local Input = require("src.core.Input")
for generation = 1, 3 do
  local input = setmetatable({}, { __index = Input })
  input:init(generation == 3)
  local game = { generation = generation, input = input }
  local phone = setmetatable({ mod = api, buttons = {}, touches = {}, epoch = 0,
    runtime = { timer = { getTime = function() return 0 end } } }, Phone)
  phone:setGame(game)
  local c = { alive = 0, sock = { close = function() end } }; phone.viewer = c
  phone:message(c, "b,right,1"); phone:message(c, "b,b,1"); input:step()
  T.check(input:isDown("right") and input:isDown("b"), "Gen " .. generation .. " simultaneous running holds")
  T.check(input:wasPressed("right"), "remote input reaches the next fixed input step")
  input:keypressed("right")
  phone:message(c, "b,right,0"); input:step()
  T.check(input:isDown("right"), "phone release preserves a real keyboard hold")
  phone:message(c, "release"); input:step()
  T.check(not input:isDown("b") and input:isDown("right"), "reset releases only remote input")
  input:keyreleased("right"); input:step()
  phone:message(c, "b,a,1"); phone:message(c, "b,a,0"); input:step()
  T.check(input:wasPressed("a") and not input:isDown("a"), "a quick press/release produces one tap without sticking")
  input:step(); T.check(not input:wasPressed("a"), "the tap does not repeat")
  if generation == 3 then
    phone:message(c, "b,l,1"); phone:message(c, "b,r,1"); input:step()
    T.check(input:isDown("l") and input:isDown("r"), "GBA shoulders enter the real input system")
    input:keypressed("q"); phone:message(c, "b,l,0"); input:step()
    T.check(input:isDown("l"), "remote shoulder release preserves keyboard shoulder")
    input:keyreleased("q")
  end
  phone:drop(c); input:step()
  for _, button in ipairs({"up","down","left","right","a","b","start","select","l","r"}) do
    T.check(not input:isDown(button), "disconnect leaves " .. button .. " released")
  end
end
run.release()
T.finish("phone controls with real Recomp Input in all three generations")
