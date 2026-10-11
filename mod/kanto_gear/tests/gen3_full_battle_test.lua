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
  local opponents,drawOpponents=nil,H.enemyInfoOpponents
  H.enemyInfoOpponents=function(self,rows,...)
    opponents={}
    for _,row in ipairs(rows) do if row.side=="enemy" then opponents[row.id]=row end end
    return drawOpponents(self,rows,...)
  end
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
      T.eq(#cards,3,"Full Gear draws all four native battlefield slots, including ID zero")
      T.check(cards[0] ~= nil,"first partner has a lower HP card")
      local snap=up(refresh,"battle")
      for id=0,3 do
        T.eq(snap.battlers[id+1].hp,10+id,"native double-battle presentation remains readable")
      end
      T.check(display.gen3Presentation ~= nil,"Gen3 presentation follows battle ownership")
      T.check(display.gen3Presentation.owns("hud"),"Full Gear relocates the native HUD")
      for _,stay in ipairs({false,true}) do
        Message.show("The attack hits both opposing POKéMON!",{frame="battle",speed=0,stay=stay})
        cards,compact={},nil;tick()
        T.check(compact ~= nil,"Full Gear renders battle text below")
        T.check(cards[0] and cards[1] and cards[2] and cards[3],"Full Gear keeps all four health cards during battle text")
        Message.reset()
      end
    end
  end
  Message.reset()
  local Bag=require("src.ui.game3.bag_menu")
  Bag.show(game.session.bag,{session=game.session,battle=st});Bag.settle()
  Bag.showMessage("The item restored health.")
  cards,compact={},nil;tick()
  T.check(compact ~= nil,"Full Gear renders item results below")
  T.check(cards[0] and cards[3],"Full Gear item results retain partner and opponent HP")
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
  T.eq(cards[2].name,cards[0].name,"Full Gear replacement uses native displayed Pokemon")
  nativePresent[2].shown=shown
  local tap = up(up(compose,"touchEvent"),"tap")
  local tapBattle = up(tap,"tapBattle")
  local inputHook
  for _,entry in ipairs(run.loader.hooks.chains["input.step"]) do
    if entry.owner=="kanto_gear" then inputHook=entry.callback end
  end
  local runtime=up(inputHook,"hgssRuntime")
  local selectedCommand
  local gearRoot,fullRoot=H.battleRoot,H.battleFullRoot
  H.battleRoot=function(self,mon,portrait,players,enemies,selected,...)
    selectedCommand=selected
    return gearRoot(self,mon,portrait,players,enemies,selected,...)
  end
  H.battleFullRoot=function(self,mon,player,enemy,portrait,players,enemies,selected,...)
    selectedCommand=selected
    return fullRoot(self,mon,player,enemy,portrait,players,enemies,selected,...)
  end
  for _, mode in ipairs({"standard","info","gear","full"}) do
    options.battle_view=mode
    run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="battle_view"})
    Stack.clear();Message.reset();Ui.openMenu(0);cards={};tick()
    T.eq(not not display.gen3Presentation.owns("panel"),mode=="gear" or mode=="full",mode.." controls native command visibility")
    T.eq(not not display.gen3Presentation.owns("hud"),mode=="full",mode.." controls native HP visibility")
    if mode=="standard" then T.eq(next(cards),nil,"Companion does not duplicate HP cards") end
    if mode=="info" then
      T.check(opponents and opponents[1] and opponents[3],"Info shows both opponents")
      T.eq(opponents[0],nil,"Info never offers a partner as opponent")
      tapBattle(80,145/1.5)
      T.eq(display.enemyInfoSelection,3,"second opponent is independently selectable")
      T.eq(display.enemyInfo().source.id,3,"selected info comes from the second foe")
      tapBattle(120/1.5,120/1.5)
      tapBattle(5,5)
      T.eq(display.enemyInfoSelection,3,"detail back retains the selected opponent")
      tapBattle(5,5)
      T.eq(display.enemyInfoSelection,nil,"back returns to the two-opponent list")
      st.absent[3]=true;tick()
      tapBattle(80,145/1.5)
      T.eq(display.enemyInfoSelection,nil,"an absent opponent cannot open unrelated info")
      st.absent[3]=nil
    end
    for _,doubles in ipairs({false,true}) do
      st.double=doubles
      for index=1,4 do
        for _,direction in ipairs({"up","down","left","right"}) do
          Message.reset();Stack.clear();Ui.openMenu(0);Ui._menuIndex=index;Ui._actionCursor[0]=index;refresh()
          local semantic=({1,3,2,4})[index]
          local expected
          if mode=="gear" then expected=({1,3,2,4})[runtime.rootDirection(semantic,direction)]
          elseif mode=="full" then expected=({1,3,2,4})[runtime.fullRootDirection(semantic,direction)]
          else expected=(direction=="left" or direction=="right")
            and (index%2==1 and index+1 or index-1) or (index<=2 and index+2 or index-2) end
          if doubles and mode~="gear" then
            local nativeDirection=mode=="full" and
              ({left="up",right="down",up="left",down="right"})[direction] or direction
            if nativeDirection=="left" and index%2==1
                or nativeDirection=="right" and index%2==0
                or nativeDirection=="up" and index<=2
                or nativeDirection=="down" and index>2 then expected=index end
          end
          Ui.handleInput({wasPressed=function(_,key) return key==direction end})
          T.eq(Ui._menuIndex,expected,mode.." native input follows its visible command geometry")
          T.eq(Ui._actionCursor[0],expected,mode.." retains the native action cursor")
          tick()
          if mode=="gear" or mode=="full" then
            T.eq(selectedCommand,({1,3,2,4})[expected],
              mode.." highlights the command actually selected by the native handler")
          end
        end
      end
    end
    if mode=="gear" or mode=="full" then
      for _,destination in ipairs({
        {direction=mode=="gear" and "left" or "down",kind="bag"},
        {direction="right",kind="party"},
      }) do
        Message.reset();Stack.clear();Ui._actionCursor[0]=1;Ui.openMenu(0);refresh()
        Ui.handleInput({wasPressed=function(_,key) return key==destination.direction end})
        tick()
        Ui.handleInput({wasPressed=function(_,key) return key=="a" end})
        T.eq(Ui._mode,destination.kind,mode.." confirms the visibly selected "..destination.kind)
        if destination.kind=="bag" then Bag.close()
        else require("src.ui.game3.party_menu").close() end
      end
    end
    st.double=true
    if mode=="full" or mode=="gear" then
      local Party=require("src.ui.game3.party_menu")
      local six={}
      for i=1,6 do six[i]=game.session.party[(i-1)%#game.session.party+1] end
      Party.show(six,{session=game.session,battle=st,mode="battle_switch"})
      for _=1,120 do Party.update() end
      display.gen3.syncScreens();refresh()
      Party.cursor=1
      Party.handleInput({wasPressed=function(_,key) return key=="down" end})
      T.eq(Party.cursor,3,"owned team navigation follows the six-card grid")
      Party.cursor=1
      Party.handleInput({wasPressed=function(_,key) return key=="right" end})
      T.eq(Party.cursor,2,"owned team navigation reaches the adjacent card")
      Party.close();Stack.clear();Ui.openMenu(0)
    end
    Ui._openMoveMenu();cards={};tick()
    if mode=="full" then
      T.check(cards[0] and cards[1] and cards[2] and cards[3],"Full Gear keeps four HP cards while selecting moves")
    end
    local moveCount=0
    for slot=1,4 do
      local move=st.battlers[0].mon.moves[slot]
      if move and move~=0 and move~="" then moveCount=moveCount+1 end
    end
    for _,direction in ipairs({"right","left","down","up"}) do
      Ui._moveIndex=1
      Ui.handleInput({wasPressed=function(_,key) return key==direction end})
      local target=(direction=="left" or direction=="right") and 2 or 3
      T.eq(Ui._moveIndex,(direction=="right" or direction=="down") and moveCount>=target and target or 1,
        mode.." move navigation keeps the native two-column geometry")
    end
    Ui.handleInput({wasPressed=function(_,key) return key=="b" end})
    T.eq(Ui._mode,"menu",mode.." returns from moves to commands")
    Battle._active=false
    T.check(not display.gen3Presentation.owns("menu"),mode.." never suppresses field menus")
    Battle._active=true
  end
  H.battleRoot,H.battleFullRoot=gearRoot,fullRoot
  options.battle_view="full"
  run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="battle_view"})
  Stack.clear();Message.reset();Ui.openMenu(0);tick()
  local draw=up(up(compose,"pumpDisplay"),"draw")
  local rootDraw=H.battleFullRoot
  H.battleFullRoot=function() error("intentional lower render failure") end
  T.check(not pcall(draw),"lower render errors still reach the host")
  T.check(not display.gen3Presentation.owns("panel"),"failed lower rendering restores native battle controls")
  T.eq(H.nativeFocus,false,"failed rendering releases the temporary lower focus")
  H.battleFullRoot=rootDraw
  tick()
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
  H.enemyInfoOpponents=drawOpponents
  display.drawContents=originalDraw
  for id=0,3 do nativePresent[id].displayHp=nil end
  Message.reset();Battle._active,Battle._st=false,nil;Ui.reset({headless=true})
end
dofile(path .. "/tests/gen3_fixture.lua")
