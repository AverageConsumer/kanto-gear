-- Native growth snapshots and callbacks, shared presentation and touch geometry.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local function up(fn, key)
  for i=1,debug.getinfo(fn,"u").nups do
    local name,value=debug.getupvalue(fn,i)
    if name==key then return value end
  end
end
_G.KANTO_GEAR_RENDER_CAPTURE=function(run,display,game)
  local Growth=require("src.ui.game3.stat_growth")
  local H=up(display.drawContents,"THEME").hgss
  local api=up(display.saveHome,"mod")
  local refresh
  for _,entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner=="kanto_gear" then refresh=up(entry.callback,"refreshBattle") end
  end
  local queued
  api.input.tap=function(_,target,key) T.eq(target,game,"growth touch targets the real game");queued=key end
  local function input(key) return {wasPressed=function(_,k) return k==key end,isDown=function() return false end} end
  local mon=game.session.party[1]
  local nickname,name=mon.nickname,mon.name
  mon.nickname,mon.name="","NATIVE NAME"
  local old={maxHp=20,atk=10,def=10,spa=10,spd=10,spe=10}
  local new={maxHp=22,atk=11,def=12,spa=10,spd=11,spe=9}
  local completed=0
  local options=run.loader.modOptions.kanto_gear
  for _,style in ipairs({"hgss","hgss_dark"}) do
    options.theme_v3=style
    run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3",value=style})
    for _,mode in ipairs({"standard","info","gear","full"}) do
      options.battle_view=mode
      Growth.open(mon,old,new,function() completed=completed+1 end)
      local previous
      for page=1,2 do
        display.gen3.syncScreens();refresh()
        local view=assert(display.startMenu())
        T.eq(view.title,"LEVEL UP","growth uses the common heading")
        T.eq(Growth._page,page,"native growth keeps its normal page sequence")
        local model,draw= nil,H.levelUp
        H.levelUp=function(_,value) model=value;return draw(H,value) end
        display.drawContents();H.levelUp=draw
        T.eq(#model.rows,6,"Gen 3 uses the shared six-stat layout")
        T.eq(model.name,"NATIVE NAME","growth preserves the native displayed name")
        T.eq(model.rows[1].value,22,"native captured maximum HP overrides current Pokemon data")
        T.eq(model.rows[1].delta,2,"captured gains remain visible on both native pages")
        T.eq(model.rows[4].delta,0,"zero special-attack gain stays explicit")
        T.eq(model.rows[6].delta,-1,"modified-game negative gain is not clamped")
        for _,point in ipairs({{15,15},{120,50},{120,110},{120,160}}) do
          queued=nil;display.tapStartMenu(view,point[1]/1.5,point[2]/1.5)
          T.eq(queued,nil,"static growth information cannot advance the game")
        end
        if previous then
          queued=nil;display.tapStartMenu(previous,120/1.5,187/1.5)
          T.eq(queued,nil,"old growth page cannot confirm the next page")
        end
        queued=nil;display.tapStartMenu(view,120/1.5,187/1.5)
        T.eq(queued,"a","only common Continue sends native confirmation")
        Growth.handleInput(input(queued))
        T.check(not view.valid(),"native progression invalidates previous growth controls")
        previous=view
      end
      T.check(not Growth.isOpen(),"second native confirmation closes growth")
      Growth.open(mon,old,new,function() end)
      T.check(not previous.valid(),"reopened growth rejects the former callback")
      local first=assert(display.startMenu())
      Growth.open(mon,old,new,function() end)
      T.check(not first.valid(),"same Pokemon, stats and page still require the current callback")
      Growth.close({silent=true})
    end
  end
  T.eq(completed,8,"each native growth sequence completes exactly once")
  mon.nickname,mon.name=nickname,name
end
dofile(path .. "/tests/gen3_fixture.lua")
