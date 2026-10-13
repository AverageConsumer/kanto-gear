local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
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
  do
    local Menu=assert(loadfile(path.."/adapters/start_menu.lua"))()
    local saved, hints={},options.type_hints
    for id=0,3 do
      local b=st.battlers[id]
      saved[id]={b.type1,b.type2,b.mon.moves[1]}
    end
    local function setHints(value)
      options.type_hints=value
      run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="type_hints",value=value})
    end
    setHints(true)
    -- Fire versus Grass/Steel, Water and a neutral ally. Deliberately use
    -- live types different from the fixture's species, as after Conversion.
    st.battlers[0].mon.moves[1]=53
    st.battlers[1].type1,st.battlers[1].type2=12,8
    st.battlers[3].type1,st.battlers[3].type2=11,11
    st.battlers[2].type1,st.battlers[2].type2=0,0
    T.check(Ui.chooseTarget(st,0,1),"matchup preview opens native doubles targets")
    local function targets()
      refresh()
      local view=assert(display.startMenu())
      return view,display.startMenuModel(view)
    end
    local view,model=targets()
    local expected={[1]=40,[3]=5,[2]=10}
    for i,row in ipairs(model.entries) do
      T.eq(row.effectiveness,expected[view.battleTargets[i]],"each target has its own live type matchup")
      T.eq(row.right,view.battleTargets[i]%2==0 and "YOUR SIDE" or "FOE","matchups preserve friend/foe labels")
      T.eq(Menu.hit(view,row.x+10,row.y+row.h-1),i,"the complete taller target row accepts touch")
      T.eq(Menu.hit(view,row.x+10,row.y+row.h),nil,"target row gaps do not select adjacent targets")
    end
    local key=Menu.redrawKey(view)
    st.battlers[1].type1,st.battlers[1].type2=10,5
    view,model=targets()
    T.check(Menu.redrawKey(view)~=key,"changed defensive types invalidate the target canvas")
    for i,row in ipairs(model.entries) do
      if view.battleTargets[i]==1 then
        T.eq(row.effectiveness,2.5,"dual resistance is a quarter, not a half")
        T.eq(theme.hgss:battleEffectLabel(row),"1/4","quarter resistance has the correct label")
      end
    end
    st.battlers[0].mon.moves[1]=85
    st.battlers[1].type1,st.battlers[1].type2=4,4
    view,model=targets()
    for i,row in ipairs(model.entries) do
      if view.battleTargets[i]==1 then
        T.eq(row.effectiveness,0,"target immunity stays visible as zero")
        T.eq(theme.hgss:battleEffectLabel(row),"0X","immunity uses the existing move-card label")
      end
    end
    setHints(false)
    view,model=targets()
    for _,row in ipairs(model.entries) do T.eq(row.effectiveness,nil,"disabled type hints hide all target factors") end
    setHints(true)
    for _,move in ipairs({86,237,311}) do
      st.battlers[0].mon.moves[1]=move
      view,model=targets()
      for _,row in ipairs(model.entries) do T.eq(row.effectiveness,nil,"status and unresolved variable-type moves have no damage factor") end
    end
    Ui.openMenu(2)
    st.battlers[2].mon.moves[1]=53
    st.battlers[0].type1,st.battlers[0].type2=11,11
    T.check(Ui.chooseTarget(st,2,1),"second partner opens its own move targets")
    view,model=targets()
    for i,row in ipairs(model.entries) do
      if view.battleTargets[i]==0 then T.eq(row.effectiveness,5,"second partner previews its move against the first partner") end
    end
    local presence={}
    for id=0,3 do
      local b=st.battlers[id]
      presence[id]={hp=b.mon.hp,fainted=b.fainted,absent=st.absent[id]}
    end
    for _,active in ipairs({0,2}) do
      for _,foe in ipairs({1,3}) do
        for id=0,3 do
          local b=st.battlers[id]
          local alive=id==active or id==foe
          st.absent[id],b.fainted,b.mon.hp=not alive,not alive,alive and 20 or 0
        end
        st.battlers[active].mon.moves[1]=53
        st.battlers[foe].type1,st.battlers[foe].type2=12,8
        local otherFoe=foe==1 and 3 or 1
        st.battlers[otherFoe].type1,st.battlers[otherFoe].type2=11,11
        Ui.openMenu(active);Ui._openMoveMenu();refresh()
        T.eq(up(refresh,"battle").target,nil,"one-versus-one preview does not invent a selected cursor")
        T.eq(up(refresh,"battle").moves[1].effectiveness,40,"either survivor pair shows its live foe's matchup on move cards")
        local partner=(active+2)%4
        st.absent[partner],st.battlers[partner].fainted,st.battlers[partner].mon.hp=false,false,20
        refresh()
        T.eq(up(refresh,"battle").moves[1].effectiveness,nil,"a returning partner makes the move-card target ambiguous again")
        st.absent[partner],st.battlers[partner].fainted,st.battlers[partner].mon.hp=true,true,0
        st.absent[otherFoe],st.battlers[otherFoe].fainted,st.battlers[otherFoe].mon.hp=false,false,20
        refresh()
        T.eq(up(refresh,"battle").moves[1].effectiveness,nil,"a second living foe restores per-target matchup selection")
      end
    end
    for id=0,3 do
      local b=st.battlers[id]
      b.type1,b.type2,b.mon.moves[1]=unpack(saved[id])
      b.mon.hp,b.fainted,st.absent[id]=presence[id].hp,presence[id].fainted,presence[id].absent
    end
    setHints(hints)
    Ui.openMenu(0);refresh()
  end
  local H=theme.hgss
  local drawCard,drawMessage,gearMessage=H.battleCompactStatus,H.battleFullMessage,H.battleMessage
  local opponents,drawOpponents=nil,H.enemyInfoOpponents
  H.enemyInfoOpponents=function(self,rows,...)
    opponents={}
    for _,row in ipairs(rows) do if row.side=="enemy" then opponents[row.id]=row end end
    return drawOpponents(self,rows,...)
  end
  local cards,compact={},nil
  H.battleCompactStatus=function(self,mon,x,y,...)
    cards[mon.id]={hp=mon.hp,expProgress=mon.expProgress,name=mon.name,active=mon.active,absent=mon.absent,x=x,y=y}
    return drawCard(self,mon,x,y,...)
  end
  H.battleFullMessage=function(self,lines,advance,...)
    compact={lines=lines,advance=advance}
    return drawMessage(self,lines,advance,...)
  end
  H.battleMessage=function(self,lines,advance,...)
    compact={lines=lines,advance=advance}
    return gearMessage(self,lines,advance,...)
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
  -- The final experience is already saved; the lower bar follows each native
  -- fill/reset segment and remains cached between actual changes.
  for _,id in ipairs({0,2}) do
    local savedExp=nativePresent[id].displayExp
    for _,ratio in ipairs({0.2,0.6,1,0,0.4}) do
      before,revision=draws,up(refresh,"battle").revision
      nativePresent[id].displayExp=ratio;tick()
      T.eq(up(refresh,"battle").revision,revision,"EXP crawl does not require a native revision")
      T.eq(cards[id].expProgress,ratio,"Full Gear shows the native EXP fill/reset")
      T.check(draws>before,"EXP crawl invalidates its cached HUD")
      before=draws;tick();T.eq(draws,before,"unchanged EXP keeps the HUD cached")
    end
    nativePresent[id].displayExp=savedExp;tick()
  end
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
  local companionEnabled
  H.battleRoot=function(self,mon,portrait,players,enemies,selected,enabled)
    selectedCommand,companionEnabled=selected,enabled
    return gearRoot(self,mon,portrait,players,enemies,selected,enabled)
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
    if mode=="standard" then
      T.eq(next(cards),nil,"Companion keeps all native HP cards upstairs")
      T.eq(companionEnabled,true,"Companion shows four usable commands at the native menu")
      T.eq(selectedCommand,nil,"Companion never presents lower D-pad command focus")
      for index, rect in ipairs(H.battleActions) do
        Stack.clear();Message.reset();Ui.openMenu(0);refresh()
        tapBattle((rect.x+rect.w/2)/1.5,(rect.y+rect.h/2)/1.5)
        T.eq(Ui._mode,({"moves","party","bag","none"})[index],"Companion touch reaches the matching native command")
        Bag.close();require("src.ui.game3.party_menu").close()
      end
      Stack.clear();Message.reset();Ui.openMenu(0);refresh()
    end
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
      -- Info is independent of the original menu stack, including transitions
      -- into and out of every built-in battle overlay.
      local Team=require("src.ui.game3.party_menu")
      local Summary=require("src.ui.game3.summary_menu")
      local Growth=require("src.ui.game3.stat_growth")
      local Choice=require("src.ui.game3.choice")
      local scenes={
        function() Team.show(game.session.party,{session=game.session,battle=st,mode="battle_switch"}) end,
        function() Bag.show(game.session.bag,{session=game.session,battle=st});Bag.settle() end,
        function() Summary.openMenu(game.session.party,1,{session=game.session}) end,
        function() Growth.open(game.session.party[1],{},{}) end,
        function() Choice.yesNo(function() error("Info answered a native choice") end) end,
        function() Message.show("A native battle message",{frame="battle",speed=1}) end,
      }
      for _,open in ipairs(scenes) do
        Team.close();Bag.close();Summary.close();Growth.close({silent=true})
        Stack.clear();Message.reset();Choice.active=false;Ui.openMenu(0)
        display.enemyInfoSelection=nil;open();opponents=nil;tick()
        T.check(opponents and opponents[1] and opponents[3],"Info keeps both foes while the upper menu changes")
        T.check(not display.gen3Presentation.owns("menu"),"Info retains every original upper overlay")
        local guard=display.syncTouchGuard();guard.readyAt=0
        tap(80,145/1.5)
        T.eq(display.enemyInfoSelection,3,"Info touch selects a foe instead of the covered original menu")
        local key=display.motionKey()
        T.check(key:find("battle%-info:")~=nil,"Info animation identity excludes the original menu")
      end
      Team.close();Bag.close();Summary.close();Growth.close({silent=true})
      Stack.clear();Message.reset();Choice.active=false;Ui.openMenu(0)
      display.enemyInfoSelection=nil;tick()
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
      local focus, drawTeamCard = nil, H.partyCard
      H.partyCard = function(self, mon, x, y, selected, details, portrait, focused, ...)
        T.check(not selected or focused, "Gen 3 card highlight belongs only to the D-pad selection")
        if focused then
          T.eq(focus, nil, "Gen 3 team has only one focused card")
          for slot = 1, 6 do
            local sx, sy = self:partyPosition(slot)
            if x == sx and y == sy then focus = slot end
          end
        end
        return drawTeamCard(self, mon, x, y, selected, details, portrait, focused, ...)
      end
      Party.cursor=1
      Party.handleInput({wasPressed=function(_,key) return key=="down" end})
      T.eq(Party.cursor,3,"owned team navigation follows the six-card grid")
      focus=nil;tick()
      T.eq(focus,3,"Gen 3 visible team focus follows down into the next row")
      Party.cursor=1
      Party.handleInput({wasPressed=function(_,key) return key=="right" end})
      T.eq(Party.cursor,2,"owned team navigation reaches the adjacent card")
      focus=nil;tick()
      T.eq(focus,2,"Gen 3 visible team focus reaches the adjacent card")
      H.partyCard=drawTeamCard
      Party.close();Stack.clear();Ui.openMenu(0)
      -- Shared summary tabs and read-only move details belong to the lower
      -- screen, even when a controller supplies its edge during pollPads.
      local Summary=require("src.ui.game3.summary_menu")
      Summary.openMenu(game.session.party,1,{session=game.session})
      for _=1,120 do Summary.update(1/60) end
      display.gen3.syncScreens();refresh()
      local oldInput=game.input
      local Input=require("src.core.Input")
      local input=setmetatable({}, {__index=Input})
      input:reset()
      local key
      input.pollPads=function(self)
        if key then self.pressQueue[#self.pressQueue+1]=key;key=nil end
      end
      game.input=input
      local state=display.summaryContext()
      T.check(state~=nil,"native battle summary has a shared lower projection")
      T.check(state.hardwareFocus,"native battle summary owns hardware focus")
      T.eq(display.sourceGame,game,"summary test uses the source game's input")
      local function summaryEdge(pressed)
        input:reset();key=pressed
        inputHook(function() end,game,.016);input:step()
      end
      state.page=1;summaryEdge("right")
      T.eq(state.page,2,"Gen3 controller changes the visible summary tab")
      T.check(not input:wasPressed("right"),"summary navigation never also changes the native tab")
      local first=state.moveIndex or 1
      summaryEdge("down")
      T.check(state.mon.moves[state.moveIndex]~=nil,"summary cursor selects an existing move")
      options.info_level="enhanced"
      summaryEdge("a")
      T.check(up(tap,"moveInfo")~=nil,"summary A opens read-only move details")
      summaryEdge("b")
      T.eq(up(tap,"moveInfo"),nil,"controller B closes only the lower details")
      T.check(not input:wasPressed("b"),"controller B does not leak through the details")
      state.page=1;summaryEdge("left")
      T.eq(state.page,state.pages,"Gen3 summary wraps backwards across all supported tabs")
      summaryEdge("right")
      T.eq(state.page,1,"Gen3 summary wraps forwards")
      summaryEdge("b")
      T.check(input:wasPressed("b"),"closing the summary reaches its native owner")
      game.input=oldInput;display.bindBattleInput(game)
      Summary.close();Stack.clear();Ui.openMenu(0);display.gen3.syncScreens();refresh()
      -- The original action list is vertical; the lower item card has two
      -- columns. Navigate and confirm the actual native cursor, not a copy.
      local NativeBag=require("src.core.game3.bag")
      NativeBag.add(game.session.bag,13,1)
      Bag.show(game.session.bag,{session=game.session,battle=st,pocket="ITEMS"});Bag.settle()
      local Hud=require("src.ui.game3.hud")
      local nativeMenuInput=up(Hud.update,"update_top_menu")
      local function bagInput(key)
        nativeMenuInput({wasPressed=function(_,pressed) return pressed==key end,isDown=function() return false end})
      end
      bagInput(nil)
      for index,row in ipairs(Bag.list()) do if row.id==13 then Bag.cursor=index end end
      bagInput("a")
      tick()
      local actions=display.startMenu()
      if actions and actions.itemActionId then
        Bag.actionCursor=1
        bagInput("right")
        T.eq(Bag.actionCursor,2,"owned item actions follow the lower columns")
        bagInput("left")
        T.eq(Bag.actionCursor,1,"owned item actions return to the lower left button")
      else T.check(false,"battle item opens its shared action card") end
      Bag.close();Stack.clear();Ui.openMenu(0)
      T.check(Ui.chooseTarget(st,0,1),"owned doubles open native target selection")
      refresh()
      local targets=display.startMenu()
      targets.target.cursor=targets.battleTargets[1];refresh()
      Ui.handleInput({wasPressed=function(_,key) return key=="down" end})
      targets=display.startMenu()
      T.eq(targets.target.cursor,targets.battleTargets[2],"owned target selection follows the lower list")
      Ui.openMenu(0)
    end
    Ui._openMoveMenu();cards={};tick()
    if mode=="full" then
      T.check(cards[0] and cards[1] and cards[2] and cards[3],"Full Gear keeps four HP cards while selecting moves")
    elseif mode=="standard" then
      T.eq(next(cards),nil,"Companion attack selection keeps the native HP cards upstairs")
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
    -- Demonstrations keep their native automation, but use the same display
    -- contract. No hidden, interactive-looking command screen below.
    Stack.clear();Message.reset();Ui.openMenu(0)
    Battle._auto=true
    Message.show("Watch carefully!",{frame="battle",speed=0,stay=true})
    cards,compact,opponents={},nil,nil;tick()
    T.check(up(refresh,"battle").nativeInputLocked,"scripted battle retains native input authority")
    T.eq(not not display.gen3Presentation.owns("panel"),mode=="gear" or mode=="full",
      mode.." keeps its display contract during demonstrations")
    T.eq(not not display.gen3Presentation.owns("hud"),mode=="full",
      mode.." keeps its HP contract during demonstrations")
    T.check(not display.gen3Presentation.owns("menuNavigation"),"scripted battle never remaps automated choices")
    if mode=="standard" then
      T.eq(compact,nil,"Companion keeps scripted battle text upstairs")
      T.eq(companionEnabled,false,"scripted Companion commands stay disabled")
      T.eq(next(cards),nil,"scripted Companion battles have no duplicate HP cards")
    elseif mode=="info" then T.check(opponents and opponents[1] and opponents[3],"Info keeps both scripted opponents")
    else T.check(compact~=nil,"scripted battle text is mirrored below") end
    Battle._auto=false;Message.reset();Ui.openMenu(0);tick()
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
  H.battleMessage=gearMessage
  H.enemyInfoOpponents=drawOpponents
  display.drawContents=originalDraw
  for id=0,3 do nativePresent[id].displayHp=nil end
  Message.reset();Battle._active,Battle._st=false,nil;Ui.reset({headless=true})
end
dofile(path .. "/tests/gen3_fixture.lua")
