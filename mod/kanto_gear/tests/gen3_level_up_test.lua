-- Native growth snapshots and callbacks, shared presentation and touch geometry.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
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
  -- Real ROM growth calculations mutate the mon to its final level before
  -- ExpSeq presents each intermediate level and its captured stats.
  local Schema=require("src.core.game3.save_schema_firered")
  local Party=require("src.core.game3.party")
  local P=require("src.core.game3.pokemon")
  local Experience=require("src.core.game3.battle.experience")
  local ExpSeq=require("src.core.game3.battle.exp_seq")
  local Battle=require("src.core.game3.battle")
  local State=require("src.core.game3.battle.state")
  local Anim=require("src.core.game3.battle.anim")
  local Ui=require("src.core.game3.battle.ui")
  for _,active in ipairs({0,2,"bench"}) do
    local session=Schema.newGame({version=os.getenv("POKEPORT_VERSION"),name="GROWTH",rngSeed=701})
    local foes=Schema.newGame({version=os.getenv("POKEPORT_VERSION"),name="FOE",rngSeed=702})
    for _,s in ipairs({session,foes}) do
      for _,dex in ipairs({4,25}) do Party.giveMon(s,P.speciesFromNational(dex),5) end
    end
    local st=State.new({playerParty=session.party,foeParty=foes.party,double=active==2})
    local battler=st.battlers[active]
    local growing=battler and battler.mon or session.party[2]
    Battle._active,Battle._phase,Battle._st=true,"exp",st
    Ui.reset({headless=true});Ui.bindState(st,session);Ui.openMenu(active=="bench" and 0 or active)
    Anim.reset({headless=true});Anim.syncDisplayFromState(st)
    local result=Experience.apply(growing,Experience.expForLevel(Experience.growthRate(growing),8)-growing.exp)
    T.eq(result.toLevel,8,"real award calculates three levels before presentation")
    ExpSeq.begin({{mon=growing,battler=battler,partyIndex=active==0 and 1 or 2,result=result}},function() end,{}, {double=st.double})
    refresh()
    T.eq(up(refresh,"battle").player.level,5,"battle HUD retains the pre-award displayed level")
    local count=0
    for index,step in ipairs(ExpSeq._steps) do
      if step.kind=="level" then
        count=count+1
        ExpSeq._i=index
        local d=step.data
        if battler then
          local present=Anim.present(st.double and active or "player")
          present.displayLevel,present.displayMaxHp,present.displayHp=d.level,d.maxHp,d.hp
        end
        Growth.open(growing,d.oldStats,d.newStats,function() end)
        for page=1,2 do
          display.gen3.syncScreens();refresh()
          local view=assert(display.startMenu())
          T.eq(view.levelStats.mon.level,d.level,"growth heading follows its current native step")
          T.eq(view.levelStats.gain.from,d.level-1,"growth heading starts at the preceding displayed level")
          T.eq(view.levelStats.stats.hp,d.newStats.maxHp,"growth totals belong to this step, not the final mon")
          T.eq(view.levelStats.gain.deltas.hp,d.newStats.maxHp-d.oldStats.maxHp,"growth delta covers only this step")
          local snap=up(refresh,"battle")
          T.eq(snap.player.level,battler and d.level or 5,"active HUD follows the native displayed level")
          T.eq(snap.player.maxHp,battler and d.maxHp or st.player.mon.maxHp,"active HUD follows the native intermediate HP maximum")
          for _,shown in ipairs(snap.battlers) do
            if shown.id==active then T.eq(shown.level,d.level,"double-battle card uses the same displayed level") end
          end
          T.eq(growing.level,8,"presentation never rewinds actual game progress")
          Growth.handleInput(input("a"))
        end
      end
    end
    T.eq(count,3,"every real intermediate level is presented separately")
    ExpSeq.reset();Anim.reset({headless=true})
    Battle._active,Battle._st=false,nil;Ui.reset({headless=true})
  end
end
dofile(path .. "/tests/gen3_fixture.lua")
