-- Exercise the real Silph draw callback with padded native overworld frames.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display)
  local sprites = require("src.core.game3.ow_sprites")
  local draw = display.pss.drawTrainer
  local G = up(up(draw, "drawCropped"), "G")
  local saved = { getDraw=sprites.getDraw, pose=sprites.pose,
    playerGraphicsId=sprites.playerGraphicsId, avatarGraphicsId=sprites.avatarGraphicsId,
    draw=G.draw, newQuad=G.newQuad }
  local reads, uploads, calls = 0, 0, {}
  local function quad(x,y,w,h)
    return { getViewport=function() return x,y,w,h end }
  end
  local source = quad(0,32,16,32)
  local spr = { image={getDimensions=function() return 16,96 end}, quads={[0]=source},
    imageData={getPixel=function(_,x,y)
      reads=reads+1
      -- Native frame has ten transparent rows above a 12x22 trainer.
      return 1,1,1,(x>=2 and x<14 and y>=42 and y<64) and 1 or 0
    end} }
  local flip = false
  sprites.playerGraphicsId=function() return 1 end
  sprites.avatarGraphicsId=function() return 1 end
  sprites.getDraw=function() return spr end
  sprites.pose=function() return 0,flip end
  G.newQuad=function(x,y,w,h,iw,ih)
    uploads=uploads+1
    T.eq(iw,16,"crop retains sheet width")
    T.eq(ih,96,"crop retains sheet height")
    return quad(x,y,w,h)
  end
  G.draw=function(...) calls[#calls+1]={...} end
  T.check(draw(nil,26,59,21),"own trainer renders")
  local call=calls[#calls]
  local x,y,w,h=call[2]:getViewport()
  T.eq(x,2,"horizontal transparent padding removed")
  T.eq(y,42,"bust starts at visible head in the correct sheet frame")
  T.eq(w,12,"crop uses visible width")
  T.eq(h,21,"bust fits the small avatar seat")
  T.eq(call[3],20,"visible trainer centered horizontally")
  T.eq(call[4],38,"visible trainer fills seat vertically")
  T.eq(reads,512,"bounds read once from existing CPU image data")
  T.check(draw(nil,120,134,21),"sonar reuses the trainer")
  T.eq(reads,512,"repeated draws never rescan pixels")
  T.eq(uploads,1,"same crop reuses its quad")
  flip=true
  T.check(draw(nil,36,80,38),"own trainer fits the large seat")
  call=calls[#calls]
  T.eq(call[3],42,"mirrored trainer remains centered")
  T.eq(call[4],50,"full trainer centered vertically in larger seat")
  T.eq(call[6],-1,"mirror preserves integer scaling")
  T.eq(call[7],1,"large seat preserves native pixel grid")
  local _,_,_,fullHeight=call[2]:getViewport()
  T.eq(fullHeight,22,"larger seat retains the whole visible trainer")
  spr.quads[0]=quad(0,32,16,32)
  T.check(draw(nil,26,59,21),"replacement native frame renders")
  T.eq(reads,1024,"replacement frame gets fresh bounds")
  spr.quads[0]=quad(0,0,16,32)
  T.eq(draw(nil,26,59,21),false,"empty frame falls back to the theme glyph")
  local emptyReads=reads
  T.eq(draw(nil,26,59,21),false,"empty-frame fallback is cached")
  T.eq(reads,emptyReads,"empty frame is not rescanned")
  spr.quads[0]=quad(0,32,16,32); spr.imageData=nil
  T.eq(draw(nil,26,59,21),false,"missing CPU pixels never trigger GPU readback")
  for name,value in pairs(saved) do
    if name=="draw" or name=="newQuad" then G[name]=value else sprites[name]=value end
  end
end
dofile(path .. "/tests/gen3_fixture.lua")
