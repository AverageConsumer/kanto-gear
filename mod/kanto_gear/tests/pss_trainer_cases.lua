return function(T, display)
  local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
  local avatars=require("src.online.union.Avatars")
  local GameVersion=require("src.core.GameVersion")
  local CacheFs=require("src.import.CacheFs")
  local version,prefix=GameVersion.get(),CacheFs.prefix
  local draw=display.pss.drawTrainer
  local cache=up(up(draw,"drawImported"),"importedTrainers")
  local G=up(up(draw,"drawCropped"),"G")
  local saved={resolve=avatars.resolve,image=avatars.image,quads=avatars.quads,imageData=avatars.imageData}
  local oldDraw,oldQuad=G.draw,G.newQuad
  local resolves,images,calls=0,0,{}
  G.newQuad=function(x,y,w,h) return {getViewport=function() return x,y,w,h end} end
  G.draw=function(...) calls[#calls+1]={...} end
  local made={}
  avatars.resolve=function(peer)
    resolves=resolves+1
    if peer.gender==0 then
      if peer.game=="yellow" then error("damaged import") end
      return {standin=peer.game=="red",hostStandin=peer.game=="blue"}
    end
    local gen=GameVersion.generation(peer.game)
    local h=gen==3 and 32 or 16
    local data={keyed=false}
    function data:getPixel(x,y)
      local visible=x>=1 and x<15 and y>=(gen==3 and 10 or 1) and y<h-1
      return visible and .5 or 1, .5, .5, (gen==3 or self.keyed) and (visible and 1 or 0) or 1
    end
    function data:clone()
      local copy={keyed=false,getPixel=self.getPixel}
      function copy:mapPixel(fn)
        local _,_,_,alpha=fn(0,0,1,1,1,1)
        T.eq(alpha,0,"GB OBJ background becomes transparent")
        self.keyed=true
      end
      return copy
    end
    local entry={layout=gen==3 and "gba" or "gb",frames=6,data=data,
      image={getDimensions=function() return 16,h end},quads={[0]=G.newQuad(0,0,16,h)}}
    made[peer.game]=entry
    return entry
  end
  avatars.image=function(entry) images=images+1;return entry.image end
  avatars.quads=function(entry) return entry.quads end
  avatars.imageData=function(entry) return entry.data end
  for _,ed in ipairs({"red","blue","yellow","gold","silver","crystal","firered","leafgreen","ruby","sapphire","emerald"}) do
    local before=resolves
    T.check(draw({version=ed,gender=1},26,59,21),ed.." imported female/default avatar renders in the active engine")
    T.eq(resolves,before+1,"one native lookup per edition and gender")
    T.check(not made[ed].data.keyed,"shared native ImageData remains unchanged")
    T.check(draw({version=ed,gender="female"},120,134,21),"different peer with same avatar reuses the cache")
    T.eq(resolves,before+1,"repeated draws do not resolve or reread imports")
    local call=calls[#calls]
    T.eq(call[3],113,"visible trainer centered at the requested position")
    T.eq(call[4],GameVersion.generation(ed)==3 and 113 or 116,"transparent padding removed across generations")
    T.eq(GameVersion.get(),version,"foreign avatar never changes the active edition")
    T.eq(CacheFs.prefix,prefix,"foreign avatar never changes the active cache prefix")
  end
  T.eq(images,11,"textures uploaded only once per avatar")
  for _,ed in ipairs({"red","blue","yellow"}) do
    local before=resolves
    T.eq(draw({version=ed},26,59,21),false,"missing, substituted or damaged import uses theme fallback")
    T.eq(draw({version=ed},26,59,21),false,"unavailable result is cached")
    T.eq(resolves,before+1,"unavailable import is not retried every frame")
  end
  local before=resolves
  T.eq(draw({version="../emerald"},26,59,21),false,"unrecognized remote version cannot select a cache path")
  T.eq(resolves,before,"invalid remote version never reaches the loader")
  for key in pairs(cache) do cache[key]=nil end
  for key,value in pairs(saved) do avatars[key]=value end
  G.draw,G.newQuad=oldDraw,oldQuad
  local Pss=display.Pss
  local model=Pss.new({identity=function() return {name="ME"} end})
  model.client={state=function() return "online" end,you=function() return {id="me"} end,
    lobby=function() return {
      {id="a",name="A",version="emerald",avatar={gender=1}},
      {id="b",name="B",version="crystal"},
      {id="c",name="C",version="firered",avatar={gender=0}},
    } end}
  model.session={tick=function() end,blocked=function() return false end,
    peerReady=function() return false end,canInvite=function() return false end,
    ownsPlaza=function() return true end,revision=1,peers={
      b={name="B",game="crystal",gender=1},
      c={name="C",game="firered",gender=1},
      d={name="D",game="leafgreen",gender=1},
    }}
  model:refresh()
  T.eq(model.rows[1].gender,1,"lobby avatar gender survives projection")
  T.eq(model.rows[2].gender,1,"plaza metadata enriches a lobby entry without gender")
  T.eq(model.rows[3].gender,0,"explicit male lobby avatar is retained")
  T.eq(model.rows[4].gender,1,"plaza-only trainer retains gender")
  local H=up(display.drawContents,"THEME").hgss
  local oldTrainer=H.pssDrawTrainer
  local figures={}
  local peer={version="emerald",gender=1}
  H.pssDrawTrainer=function(row,x,y,maxH,facing)
    figures[#figures+1]={row=row,facing=facing};return true
  end
  H:v4PssCard("PEER","EMERALD","READY","ready",nil,170,false,peer)
  T.eq(figures[#figures-1].row,nil,"link stage uses your trainer on the left")
  T.eq(figures[#figures-1].facing,"right","your trainer faces the peer")
  T.eq(figures[#figures].row,peer,"link stage uses the remote trainer on the right")
  T.eq(figures[#figures].facing,"left","peer faces your trainer")
  H.pssDrawTrainer=oldTrainer
end
