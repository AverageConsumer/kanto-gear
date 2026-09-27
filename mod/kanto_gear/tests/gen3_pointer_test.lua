local T = require("tests.modkit")
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local Pointer = assert(loadfile(path .. "/gen3_pointer.lua"))()
local Game3 = os.getenv("KANTO_GEAR_TEST_GAME3_SOURCE")
  and assert(loadfile(os.getenv("KANTO_GEAR_TEST_GAME3_SOURCE")))()
  or require("src.core.Game3")
local calls, native, enabled = {}, 0, true
local game = setmetatable({ touchControls = {
  touchpressed = function() native=native+1; return true end,
  touchmoved = function() native=native+1 end,
  touchreleased = function() native=native+1 end,
  reset = function() end,
}}, {__index=Game3})
local originals={game.mousepressed,game.touchpressed,game.focus}
local bridge=Pointer.new(game,function(action,x,y)
  if not enabled or x<240 then return false end
  calls[#calls+1]={action,x,y}
  return true
end)
game:mousepressed(300,100,1,false)
game:mousemoved(310,110,10,10,false)
game:mousereleased(310,110,1,false)
T.eq(#calls,3,"real FRLG mouse handlers deliver down, move and up")
T.eq(calls[1][1],"down","mouse press opens the gesture")
T.eq(calls[2][1],"move","drag remains continuous")
T.eq(calls[3][1],"up","mouse release commits the gesture")
T.eq(native,0,"Gear contact does not also press native touch controls")
T.eq(calls[2][2],310,"window coordinates remain unscaled for the layout mapper")
game:mousepressed(300,100,1,true);game:mousereleased(300,100,1,true)
T.eq(#calls,3,"synthetic mouse twin is ignored")
game:mousepressed(300,100,2,false);game:mousereleased(300,100,2,false)
T.eq(#calls,3,"secondary mouse button does not trigger Gear")
game:touchpressed("finger",300,100,0,0,0.7)
game:touchmoved("other-finger",320,100,20,0,0.7)
game:touchreleased("other-finger",320,100,0,0,0.7)
T.eq(#calls,4,"another finger cannot move or release the captured contact")
game:touchmoved("finger",315,110,15,10,0.7)
game:touchreleased("finger",315,110,0,0,0.7)
T.eq(#calls,6,"physical touch gets exactly one complete gesture")
local previous=native
game:touchpressed("outside",100,100,0,0,1)
game:touchreleased("outside",100,100,0,0,1)
T.eq(native,previous+2,"native touch controls outside Gear stay usable")
T.eq(#calls,6,"outside contact never reaches Gear")
game:mousepressed(300,100,1,false);game:focus(false)
T.eq(calls[#calls][1],"cancel","focus loss cancels instead of activating")
local count=#calls
game:mousereleased(300,100,1,false)
T.eq(#calls,count,"late release after focus loss cannot click")
game:touchpressed("finger",300,100);game:visible(false)
T.eq(calls[#calls][1],"cancel","minimizing cancels a held finger")
enabled=false;count=#calls
game:mousepressed(300,100,1,false);game:mousereleased(300,100,1,false)
T.eq(#calls,count,"disabled or hidden Gear gets no pointer input")
enabled=true
game:mousepressed(300,100,1,false)
local wrapped=game.mousepressed
game.mousepressed=function(...) return wrapped(...) end
bridge:release()
T.eq(calls[#calls][1],"cancel","bridge removal cancels a held pointer")
T.eq(game.touchpressed,originals[2],"release restores inherited native methods")
T.eq(game.focus,originals[3],"release restores native lifecycle method")
count=#calls;game:mousepressed(300,100,1,false)
T.eq(#calls,count,"later mod wrappers retain inert original bridge after release")
local upgraded=setmetatable({pointerEvent=function() end},{__index=Game3})
local fixed=Pointer.new(upgraded,function() error("duplicate input") end)
T.eq(rawget(upgraded,"mousepressed"),nil,"host pointer support disables the fallback")
T.eq(rawget(upgraded,"touchpressed"),nil,"native touch hook is not wrapped twice")
fixed:release()
T.finish("FRLG host pointer compatibility")
