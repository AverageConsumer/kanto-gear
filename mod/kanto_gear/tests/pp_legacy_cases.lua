return function(T, display, game, generation, run)
  local savedStates, savedInput, pending = game.stack.states, game.input, display.bag.pending
  local mon = { species = "FIXMON_A", nickname = "TESTMON", moves = {
    { id = "FIX_MOVE_A", pp = 0, ppUps = 0 }, { id = "PP_FIX", pp = 1, ppUps = 3, maxPp = 40 } } }
  local savedA, savedB = game.data.moves.FIX_MOVE_A, game.data.moves.PP_FIX
  game.data.moves.FIX_MOVE_A = { name = "TACKLE", type = "NORMAL", power = 35, accuracy = 95, pp = 35 }
  game.data.moves.PP_FIX = { name = "GROWL", type = "NORMAL", power = 0, accuracy = 100, pp = 40 }
  local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
  local api = up(display.saveHome,"mod")
  local oldTap, keys = api.input.tap, {}
  api.input.tap = function(_,target,key) T.eq(target,game,"move touch targets the original game");keys[#keys+1]=key end
  local pressed
  game.input = { wasPressed = function(_,key) return key == pressed end, isDown = function() return false end }
  display.bag.pending = nil
  local selected, cancelled = 0, 0
  local function open()
    local picker
    local function choose(index)
      selected = index
      local effect
      if generation == 1 then
        effect = require("src.inventory.ItemEffects").use(game.data,game.save,"ETHER",mon,nil,index)
        T.eq(effect,"consumed","native Gen1 item effect accepts the selected move")
      else
        effect = require("src.core.gen2.ItemEffects").usePpItem("ETHER",mon,index,game.data)
        T.check(effect.used,"native Gen2 item effect accepts the selected move")
      end
      if game.stack:top() == picker then game.stack:pop() end
    end
    if generation == 1 then
      picker = require("src.ui.MoveSelectMenu").new(game,mon,"CHOOSE MOVE",choose,function() cancelled=cancelled+1 end)
      picker.screenId, picker.ready, picker.boxShown = "MoveSelectMenu", true, true
    else
      picker = require("src.ui.gen2.MoveDeleter").new(game,{mon=mon,onChoose=choose,onCancel=function() cancelled=cancelled+1;game.stack:pop() end})
      picker.screenId = "Gen2MoveDeleter"
    end
    game.stack.states = { game.world, picker }
    return picker, assert(display.fieldPpMoveScreen(),"native move picker works without companion pending state")
  end
  local picker, page = open()
  T.eq(page.items[1].right,"0/35","empty PP stays zero in the common page")
  T.eq(page.items[2].right,generation==2 and "1/61" or "1/64","maximum PP follows native bonuses even when a cached maximum is stale")
  T.check(pcall(display.MovePage.draw,up(display.drawContents,"THEME").hgss,display.moveSelectionModel(page)),"actual native move model renders")
  local x,y,w,h = display.MovePage.rect(2)
  display.tapPpItemMoves(page,(x+w/2)/1.5,(y+h/2)/1.5)
  T.eq(keys[#keys],"a","one move touch forwards native confirm")
  pressed = "a";picker:update();pressed=nil
  T.eq(selected,2,"native callback receives the exact move slot")
  T.eq(mon.moves[1].pp,0,"restoration never affects a different move")
  T.eq(mon.moves[2].pp,11,"native Ether restores the selected move")
  T.check(not page.valid(),"finished move picker rejects stale touches")
  local count = #keys
  display.tapPpItemMoves(page,(x+w/2)/1.5,(y+h/2)/1.5)
  T.eq(#keys,count,"stale tap cannot send another confirm")
  picker,page = open()
  display.tapPpItemMoves(page,10,10)
  pressed = keys[#keys];picker:update();pressed=nil
  T.eq(cancelled,1,"back executes the native cancel callback once")
  T.eq(mon.moves[2].pp,11,"cancelling leaves PP untouched")
  picker,page = open()
  game.stack:push({isTextBox=true})
  T.eq(display.fieldPpMoveScreen(),nil,"overlay never exposes the chooser below it")
  T.check(not page.valid(),"overlay invalidates old touch targets")
  if generation == 1 then
    game.stack:pop();picker.ready=false
    page=assert(display.fieldPpMoveScreen())
    count=#keys;display.tapPpItemMoves(page,80,60)
    T.eq(#keys,count,"native prompt readiness also locks touch input")
  end
  if generation == 2 then
    local original = mon.moves
    mon.volatile = { preTransform = { moves = original } }
    mon.moves = { { id="PP_WATER", pp=5 } }
    picker,page = open()
    T.eq(#page.items,2,"transformed Pokemon retain the native original move list for PP items")
    T.eq(page.items[2].label,"GROWL","transformed display follows the picker's original moves")
    mon.moves,mon.volatile=original,nil
  end
  local compose
  for _,entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner=="kanto_gear" then compose=entry.callback end
  end
  local tap=up(up(compose,"touchEvent"),"tap")
  local newId="PP_FIX_NEW"
  local oldDef=game.data.moves[newId]
  game.data.moves[newId]={name="EMBER",type="FIRE",power=40,accuracy=100,pp=25}
  run.loader.modOptions.kanto_gear.info_level="spoiler"
  for _,style in ipairs({"hgss","hgss_dark"}) do
    run.loader.modOptions.kanto_gear.theme_v3=style
    run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3",value=style})
    mon.moves={{id="FIX_MOVE_A",pp=0},{id="PP_FIX",pp=1}}
    local chosen,cancel=0,0
    if generation==1 then
      picker=require("src.ui.MoveLearnMenu").new(game,mon,newId,function() end)
      picker.screenId,picker.selecting="MoveLearnMenu",true
    else
      picker=require("src.ui.gen2.MoveDeleter").new(game,{mon=mon,layout="forget",
        onChoose=function(slot) chosen=slot end,onCancel=function() cancel=cancel+1 end})
      picker.screenId="Gen2MoveDeleter"
    end
    game.stack.states={game.world,picker}
    display.bag.pending={moveId=newId,mon=mon}
    local learning=assert(display.moveLearnScreen(),"real legacy learning menu has a companion page")
    T.eq(learning.newMoveId,newId,"common learning model keeps the native move identity")
    T.check(pcall(display.drawContents),"legacy learning renders using the shared attack page")
    local before=#keys
    local cursor=picker.index or picker.row
    tap(220/1.5,115/1.5)
    T.check(up(display.syncCompanionDetails,"moveInfo")~=nil,"legacy learning opens attack information")
    T.eq(picker.index or picker.row,cursor,"inspection does not change the native learning cursor")
    T.eq(#keys,before,"legacy inspection sends no confirm")
    tap(10,10)
    T.eq(up(display.syncCompanionDetails,"moveInfo"),nil,"local back closes legacy move information")
    T.eq(#keys,before,"closing details does not cancel learning")
    tap(120/1.5,115/1.5)
    T.eq(keys[#keys],"a","selecting a replacement sends native confirmation")
    pressed="a";picker:update();pressed=nil
    if generation==1 then
      T.eq(mon.moves[2].id,newId,"native Gen1 learning replaces the exact selected move")
      T.eq(mon.moves[2].pp,25,"native Gen1 learning supplies the new move's PP")
      T.eq(mon.moves[1].id,"FIX_MOVE_A","native Gen1 learning preserves other moves")
    else
      T.eq(chosen,2,"native Gen2 callback receives the exact selected replacement")
      T.eq(cancel,0,"native Gen2 replacement never calls cancellation")
    end
  end
  -- Real TextBox/ChoiceBox callbacks for learn, stop, and retry prompts.
  local savedSay, clock=game.say,love.timer.getTime
  local now=100
  love.timer.getTime=function() return now end
  if generation==2 then game.say=require("src.core.Game2").say end
  for _,style in ipairs({"hgss","hgss_dark"}) do
    run.loader.modOptions.kanto_gear.theme_v3=style
    run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3",value=style})
    mon.moves={{id="FIX_MOVE_A",pp=0},{id="PP_FIX",pp=1},{id="FIX_MOVE_A",pp=5},{id="PP_FIX",pp=5}}
    display.bag.pending={mon=mon,moveId=newId}
    game.stack.states={game.world}
    local completed,learned=0,nil
    local function done(value) completed,learned=completed+1,value end
    if generation==1 then
      picker=require("src.ui.MoveLearnMenu").new(game,mon,newId,done)
      picker.screenId="MoveLearnMenu";game.stack:push(picker);picker:enter()
    else require("src.core.Game2").learnMoveOn(game,mon,newId,done) end
    local function answer(index)
      local box=game.stack:top()
      T.check(box.isTextBox,"learning question is a real native TextBox")
      box.done,box.pageIndex=true,#box.pages
      box:update(1/60)
      local choice=game.stack:top()
      choice.screenId="ChoiceBox"
      local learn=assert(display.learningChoiceContext(choice),"native prompt exposes the learning context")
      local model=display.learningPromptModel(learn,choice,{"YES","NO"},nil,"index")
      T.eq(model.newMove.name,"EMBER","prompt describes the actual new move")
      T.check(#model.prompt>0,"prompt preserves the native question")
      local ok,err=pcall(display.drawContents)
      T.check(ok,"real legacy prompt renders in the shared page: "..tostring(err))
      local x,y,w,h=display.MovePage.promptRect(index)
      local before=#keys
      display.tapLearningPrompt(learn,choice,{"YES","NO"},nil,"index",(x+w/2)/1.5,(y+h/2)/1.5)
      T.eq(#keys,before,"new question initially blocks rapid confirmation")
      now=now+1
      display.tapLearningPrompt(learn,choice,{"YES","NO"},nil,"index",(x+w/2)/1.5,(y+h/2)/1.5)
      T.eq(#keys,before+1,"ready learning question sends exactly one native input")
      T.eq(choice.index,index,"touch selects the intended native answer")
      display.tapLearningPrompt(learn,choice,{"YES","NO"},nil,"index",(x+w/2)/1.5,(y+h/2)/1.5)
      T.eq(#keys,before+1,"repeated touch cannot confirm a question twice")
      pressed="a";choice:update();pressed=nil
      for _=1,30 do if game.stack:top()==choice then choice:update() end end
    end
    answer(2);answer(2);answer(2);answer(1)
    T.eq(mon.moves[2].id,"PP_FIX","cancel and retry never replace a move")
    local box=game.stack:top()
    box.done=true;pressed="a";box:update();pressed=nil
    T.eq(completed,1,"native cancelled learning finishes once")
    T.eq(learned,false,"native cancelled learning reports false")
  end
  if generation==2 then
    display.bag.pending=nil
    local raw=require("src.ui.gen2.BattleState").new(game,{battle={party={mon}}})
    raw.screenId,raw.slideFrame,raw.lowHealthAlarmDisabled="Gen2BattleState",1000,true
    raw.pendingLearn={index=1,move=newId,moveName="EMBER"}
    game.stack.states={game.world,raw}
    raw:askStopLearning();raw.messageTimer=0
    local learn=assert(display.learningChoiceContext(raw),"native Gen2 battle stop question has learning context")
    T.eq(learn.mon,mon,"battle prompt uses the actual learning party member")
    local model=display.learningPromptModel(learn,raw,{"YES","NO"},raw.message,"forgetChoice")
    T.check(table.concat(model.prompt," "):lower():find("stop learning",1,true)~=nil,"battle stop question retains its native meaning")
    local x,y,w,h=display.MovePage.promptRect(2)
    display.tapLearningPrompt(learn,raw,{"YES","NO"},raw.message,"forgetChoice",(x+w/2)/1.5,(y+h/2)/1.5)
    now=now+1
    display.tapLearningPrompt(learn,raw,{"YES","NO"},raw.message,"forgetChoice",(x+w/2)/1.5,(y+h/2)/1.5)
    T.eq(raw.forgetChoice,2,"battle touch selects NO in the native learning field")
    pressed="a"
    local phase=raw.phase
    for _=1,180 do if raw.phase==phase then raw:update() end end
    pressed=nil
    T.check(raw.phase=="ask-forget" or raw.phase=="learn-intro","native battle NO retries learning")
    raw.phase,raw.messageTimer,raw.messagePages="ask-forget",0,nil
    learn=assert(display.learningChoiceContext(raw))
    x,y,w,h=display.MovePage.promptRect(1)
    display.tapLearningPrompt(learn,raw,{"YES","NO"},raw.message,"forgetChoice",(x+w/2)/1.5,(y+h/2)/1.5)
    now=now+1
    display.tapLearningPrompt(learn,raw,{"YES","NO"},raw.message,"forgetChoice",(x+w/2)/1.5,(y+h/2)/1.5)
    pressed="a";phase=raw.phase
    for _=1,180 do if raw.phase==phase then raw:update() end end
    pressed=nil
    T.eq(raw.phase,"choose-forget","native Gen2 battle YES opens replacement selection")
  end
  game.say,love.timer.getTime=savedSay,clock
  game.data.moves[newId]=oldDef
  api.input.tap, game.input, game.stack.states, display.bag.pending = oldTap, savedInput, savedStates, pending
  game.data.moves.FIX_MOVE_A, game.data.moves.PP_FIX = savedA,savedB
end
