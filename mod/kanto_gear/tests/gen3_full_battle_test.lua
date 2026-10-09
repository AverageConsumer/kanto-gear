local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local function up(fn, key, replacement)
  for i=1,debug.getinfo(fn,"u").nups do
    local name,value=debug.getupvalue(fn,i)
    if name==key then
      if replacement~=nil then debug.setupvalue(fn,i,replacement) end
      return value
    end
  end
  error("missing upvalue "..key)
end
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local compose
  for _,entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner=="kanto_gear" then compose=entry.callback end
  end
  local refresh=up(compose,"refreshBattle")
  local theme=up(display.drawContents,"THEME")
  local Battle=require("src.core.game3.battle")
  local Ui=require("src.core.game3.battle.ui")
  local State=require("src.core.game3.battle.state")
  local Anim=require("src.core.game3.battle.anim")
  local Stack=require("src.ui.game3.stack")
  local Message=require("src.ui.game3.message")
  local Schema=require("src.core.game3.save_schema_firered")
  local Party=require("src.core.game3.party")
  local P=require("src.core.game3.pokemon")
  local foes=Schema.newGame({version=os.getenv("POKEPORT_VERSION"),name="FOE",rngSeed=4080})
  for _,dex in ipairs({19,16}) do Party.giveMon(foes,P.speciesFromNational(dex),20) end
  while #game.session.party<2 do Party.giveMon(game.session,P.speciesFromNational(25),20) end
  local options=run.loader.modOptions.kanto_gear
  options.battle_view,options.ui_motion="full",false
  options.display_mode,options.display_target="separate","secondary"
  run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="ui_motion"})
  local now=100
  love.timer.getTime=function() return now end
  up(compose,"nextClock",math.huge)
  local canvas=up(up(compose,"pumpDisplay"),"canvas")
  canvas.requestImageData,canvas.pollImageData=nil,nil
  canvas.newImageData=function() return {} end
  local context={secondScreen={detected=function() return true end,pollTouch=function() end,push=function() return true end}}
  local function tick() now=now+0.06;compose(function() end,{},context) end
  local originalDraw,draws=display.drawContents,0
  display.drawContents=function(...) draws=draws+1;return originalDraw(...) end
  Stack.clear();Message.reset()
  local st=State.new({playerParty=game.session.party,foeParty=foes.party,double=true})
  Battle._active,Battle._auto,Battle._phase,Battle._st=true,false,"command",st
  Ui.reset({headless=true});Ui.bindState(st,game.session);Ui.openMenu(0)
  local nativePresent={}
  for id=0,3 do
    nativePresent[id]=Anim.present(id)
    nativePresent[id].displayHp=10+id+0.8
  end
  local H=theme.hgss
  local drawCard,drawMessage=H.battleCompactStatus,H.battleFullMessage
  local cards,compact={},nil
  H.battleCompactStatus=function(self,mon,x,y,...)
    cards[mon.id]={hp=mon.hp,name=mon.name,active=mon.active,absent=mon.absent,x=x,y=y}
    return drawCard(self,mon,x,y,...)
  end
  H.battleFullMessage=function(self,lines,advance,...)
    compact={lines=lines,advance=advance}
    return drawMessage(self,lines,advance,...)
  end
  for _,style in ipairs({"hgss","hgss_dark"}) do
    options.theme_v3=style;run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3"})
    H=theme.hgss
    for _,active in ipairs({0,2}) do
      Ui.openMenu(active);Message.reset();cards={};tick()
      T.eq(next(cards),nil,"companion commands never duplicate native HP cards")
      local snap=up(refresh,"battle")
      for id=0,3 do
        T.eq(snap.battlers[id+1].hp,10+id,"native double-battle presentation remains readable")
      end
      T.eq(display.gen3Presentation,nil,"all four native healthboxes stay above")
      for _,stay in ipairs({false,true}) do
        Message.show("The attack hits both opposing POKéMON!",{frame="battle",speed=0,stay=stay})
        cards,compact={},nil;tick()
        T.eq(compact,nil,"native battle text is not mirrored downstairs")
        T.eq(next(cards),nil,"native battle text does not add duplicate HP cards")
        Message.reset()
      end
    end
  end
  Message.reset()
  local Bag=require("src.ui.game3.bag_menu")
  Bag.show(game.session.bag,{session=game.session,battle=st});Bag.settle()
  Bag.showMessage("The item restored health.")
  cards,compact={},nil;tick()
  T.eq(compact,nil,"native item results stay upstairs")
  T.eq(next(cards),nil,"native item results do not duplicate HP cards")
  Bag.close();Stack.clear()
  -- A partner's displayed HP can change without the native battle revision.
  Message.reset();Ui.openMenu(0);tick();tick()
  local before,revision=draws,up(refresh,"battle").revision
  nativePresent[3].displayHp=4.4;tick()
  T.eq(up(refresh,"battle").revision,revision,"animation alone does not change battle revision")
  T.check(draws>before,"partner HP animation invalidates the cached frame")
  T.eq(up(refresh,"battle").battlers[4].hp,4,"native second foe HP remains correct")
  before=draws;tick();tick();T.eq(draws,before,"unchanged doubles HUD stays cached")
  st.absent[3]=true;tick();T.check(up(refresh,"battle").battlers[4].absent,"native absent opponent remains represented")
  st.absent[3]=nil
  local shown=nativePresent[2].shown
  nativePresent[2].shown=st.battlers[0];tick()
  local replaced=up(refresh,"battle").battlers
  T.eq(replaced[3].name,replaced[1].name,"partner replacement follows native displayed Pokemon")
  T.eq(next(cards),nil,"replacement never adds a duplicate lower healthbox")
  nativePresent[2].shown=shown
  -- Native Gen3 transitions use the same actual-page compositor as Gen1/2.
  local Team=require("src.ui.game3.party_menu")
  options.ui_motion=true
  run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="ui_motion"})
  local scenes = {
      {"moves",1,function() Ui._openMoveMenu() end},
      {"commands after moves",-1,function() Ui.openMenu(0) end},
      {"party",1,function() Team.show(game.session.party,{session=game.session,battle=st}) end},
      {"commands after party",-1,function() Team.close();Stack.clear();Ui.openMenu(0) end},
      {"bag",-1,function() Bag.show(game.session.bag,{session=game.session,battle=st});Bag.settle() end},
      {"commands after bag",1,function() Bag.close();Stack.clear();Ui.openMenu(0) end},
  }
  for _,style in ipairs({"hgss","hgss_dark"}) do
    options.theme_v3=style
    run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3"})
    Ui.openMenu(0);Stack.clear();Message.reset();tick();tick()
    for _,scene in ipairs(scenes) do
      scene[3]();tick()
      T.eq(display.motion.direction,scene[2],style.." "..scene[1].." uses common navigation direction")
      T.check(display.motion.started~=nil,scene[1].." starts from the actual previous frame")
      T.eq(display.motion.top,28,scene[1].." keeps the header stationary")
      T.eq(display.motion.duration,.24,scene[1].." shares the same short duration")
      local paints=draws
      tick();tick()
      T.eq(draws,paints,scene[1].." reuses the rendered destination between frames")
      for _=1,5 do tick() end
      T.eq(display.motion.started,nil,scene[1].." finishes without repeating")
    end
    options.map_motion="performance"
    run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="map_motion"})
    T.eq(H.motionEnabled,false,style.." performance disables presentation motion")
    for _,scene in ipairs(scenes) do
      scene[3]();tick()
      T.eq(display.motion.started,nil,style.." performance shows "..scene[1].." immediately")
    end
    T.eq(options.ui_motion,true,"performance retains the quality animation preference")
    options.map_motion="quality"
    run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="map_motion"})
  end
  H.battleCompactStatus,H.battleFullMessage=drawCard,drawMessage
  display.drawContents=originalDraw
  for id=0,3 do nativePresent[id].displayHp=nil end
  Message.reset();Battle._active,Battle._st=false,nil;Ui.reset({headless=true})
end
dofile(path .. (os.getenv("POKEPORT_VERSION")=="emerald" and "/tests/emerald_runtime_test.lua" or "/tests/gen3_runtime_test.lua"))
