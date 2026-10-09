return function(T, display, game, generation)
  local savedStates, savedInput, pending = game.stack.states, game.input, display.bag.pending
  local mon = { species = "FIXMON_A", nickname = "TESTMON", moves = {
    { id = "FIX_MOVE_A", pp = 0, ppUps = 0 }, { id = "PP_FIX", pp = 1, ppUps = 3, maxPp = 40 } } }
  local savedA, savedB = game.data.moves.FIX_MOVE_A, game.data.moves.PP_FIX
  game.data.moves.FIX_MOVE_A = { name = "TACKLE", type = "NORMAL", power = 35, accuracy = 95, pp = 35 }
  game.data.moves.PP_FIX = { name = "GROWL", type = "NORMAL", power = 0, accuracy = 100, pp = 40 }
  local function up(fn,key)
    for i=1,debug.getinfo(fn,"u").nups do local k,v=debug.getupvalue(fn,i);if k==key then return v end end
  end
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
  api.input.tap, game.input, game.stack.states, display.bag.pending = oldTap, savedInput, savedStates, pending
  game.data.moves.FIX_MOVE_A, game.data.moves.PP_FIX = savedA,savedB
end
