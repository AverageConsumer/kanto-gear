-- Exercise the native learning flow through Gear's shared attack cards.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local compose
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner == "kanto_gear" then compose = entry.callback end
  end
  local refresh = up(compose, "refreshBattle")
  local tap = up(up(compose, "touchEvent"), "tap")
  local H = up(display.drawContents, "THEME").hgss
  local api = up(display.saveHome, "mod")
  local Summary = require("src.ui.game3.summary_menu")
  local Screens = require("src.ui.game3.screens")
  local Stack = require("src.ui.game3.stack")
  local Message = require("src.ui.game3.message")
  local Choice = require("src.ui.game3.choice")
  local Battle = require("src.core.game3.battle")
  local Ui = require("src.core.game3.battle.ui")
  local Learn = require("src.core.game3.battle.learn_move")
  local State = require("src.core.game3.battle.state")
  local Pokemon = require("src.core.game3.pokemon")
  local mon = game.session.party[1]
  local savedMoves, savedPp, savedMax, savedBonus = mon.moves, mon.pp, mon.maxPp, mon.ppBonusesPacked
  local queued
  api.input.tap = function(_, target, key)
    T.eq(target, game, "move learning forwards input to original game")
    queued = key
  end
  local function input(key)
    return { wasPressed = function(_, k) return k == key end, isDown = function() return false end }
  end
  local function sync()
    display.gen3.syncScreens(); refresh()
  end
  local function advanceUntil(predicate)
    for _ = 1, 40 do
      Ui.pump()
      if predicate() then sync(); return end
      if Message.isOpen() then Message.skipReveal(); Message.advance() end
    end
    error("native learning flow did not reach expected screen")
  end
  local function touchPrompt(index, consume)
    sync()
    local view = assert(display.startMenu(), "native learning question has a touch view")
    T.check(view.learningPrompt ~= nil, "learning question carries Pokemon and new move")
    T.eq(view.learningPrompt.newMoveId, display.gen3.Moves.constName(Learn._moveId), "prompt retains the native new move")
    local model
    local draw = display.MovePage.drawPrompt
    display.MovePage.drawPrompt = function(H, value) model=value;return draw(H,value) end
    display.drawContents(); display.MovePage.drawPrompt=draw
    T.check(model and #model.prompt > 0, "learning question renders the native prompt")
    local cursor=view.index
    queued=nil
    display.tapStartMenu(view,120/1.5,105/1.5)
    T.check(up(display.syncCompanionDetails,"moveInfo")~=nil,"question opens local new-move details")
    T.eq(view.index,cursor,"new-move inspection never changes the answer")
    T.eq(queued,nil,"new-move inspection never confirms learning")
    display.syncCompanionDetails();display.drawContents()
    tap(10,10)
    T.eq(up(display.syncCompanionDetails,"moveInfo"),nil,"back closes question details locally")
    T.eq(queued,nil,"closing details never answers the question")
    T.check(view.valid(),"question remains current after inspection")
    local x,y,w,h=display.MovePage.promptRect(index)
    queued=nil
    display.tapStartMenu(view,(x+w/2)/1.5,(y+h/2)/1.5)
    T.eq(queued,"a","learning answer forwards native confirm")
    T.eq(view.index,index,"learning answer selects the matching native row")
    consume(input(queued))
    T.check(not view.valid(),"answered question invalidates its old touch targets")
    queued=nil
    display.tapStartMenu(view,(x+w/2)/1.5,(y+h/2)/1.5)
    T.eq(queued,nil,"stale question cannot confirm a subsequent prompt")
    return view
  end
  local function touchRow(index)
    sync()
    local menu = display.startMenu()
    T.check(menu ~= nil, "move chooser remains mirrored on either Emerald move tab")
    assert(menu, "missing mirrored move chooser")
    while menu.touchWindow and (index < menu.touchWindow.first or index >= menu.touchWindow.first + menu.touchWindow.count) do
      display.pageChoice(index > menu.touchWindow.first and 1 or -1)
      menu = display.startMenu()
    end
    local row = assert(display.StartMenu.model(menu).entries[index - (menu.touchWindow and menu.touchWindow.first or 1) + 1])
    queued = nil
    display.tapStartMenu(menu, (row.x + row.w / 2) / 1.5, (row.y + row.h / 2) / 1.5)
    T.eq(queued, index == 5 and "b" or "a", "touch uses the matching native move/cancel input")
    Screens.handleInput("summary", Summary, input(queued), game.session)
    return menu
  end
  local options = run.loader.modOptions.kanto_gear
  local emerald = os.getenv("POKEPORT_VERSION") == "emerald"
  options.info_level = "spoiler"
  for _, style in ipairs({ "hgss", "hgss_dark" }) do
    options.theme_v3 = style
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = style })
    for _, mode in ipairs({ "standard", "gear", "full" }) do
      options.battle_view = mode
      for _, outcome in ipairs({ "replace", "cancel", "retry" }) do
        Stack.clear(); Message.reset(); Learn.reset(); Choice.active = false
        mon.moves, mon.pp = { 15, 33, 45, 10 }, { 30, 35, 40, 35 }
        mon.maxPp,mon.ppBonusesPacked={30,35,40,35},0
        local st = State.new({ playerParty = game.session.party, foeParty = { mon }, wild = true })
        Battle._active, Battle._auto, Battle._phase, Battle._st = true, false, "awards", st
        Ui.reset({ headless = false }); Ui.bindState(st, game.session)
        local completed, learned = 0, nil
        Learn.begin({ mon = mon, moveId = 22, battleText = true,
          pushMsg = Ui.push, askYesNo = Ui.askYesNo, askForget = Ui.askForget,
          onDone = function(value) completed, learned = completed + 1, value end })
        advanceUntil(function() return Choice.active end)
        touchPrompt(1, Ui.handleInput)
        T.check(Summary.isOpen(), "native learning prompt opens replacement menu")
        if emerald then
          Screens.handleInput("summary", Summary, input(outcome == "retry" and "left" or "right"), game.session)
        end
        sync(); display.drawContents()
        local view=assert(display.startMenu())
        T.check(view.moveSelection and not view.choiceState,"learning uses the common four-card page")
        T.eq(view.moveSelection.newMoveId,display.gen3.Moves.constName(22),"new move keeps its native identity")
        T.eq(view.moveSelection.items[2].right,"35/35","learning cards show real PP")
        T.same(view.items[5].rect,{0,0,27,28},"native cancel is the shared back arrow")
        local cursor=Summary._moveCursor
        for _,point in ipairs({{220,115},{120,40}}) do
          queued=nil
          tap(point[1]/1.5,point[2]/1.5)
          T.check(up(display.syncCompanionDetails,"moveInfo")~=nil,"touch opens learning attack details")
          T.eq(Summary._moveCursor,cursor,"inspection never moves the native replacement cursor")
          T.eq(queued,nil,"inspection sends no native input")
          display.syncCompanionDetails()
          local original,rendered=H.battleMoveInfoBody,nil
          H.battleMoveInfoBody=function(_,info) rendered=info end
          display.drawContents();H.battleMoveInfoBody=original
          T.check(rendered~=nil,"local details render above the native chooser")
          tap(120/1.5,80/1.5)
          T.eq(queued,nil,"details block the covered replacement buttons")
          tap(10,10)
          T.eq(up(display.syncCompanionDetails,"moveInfo"),nil,"back closes local details")
          T.eq(queued,nil,"closing local details never cancels native learning")
          T.check(view.valid(),"inspection leaves the native chooser intact")
        end
        local old = touchRow(1)
        T.check(Summary._hmNotice, "touching an HM shows native refusal")
        T.eq(mon.moves[1], 15, "HM is never replaced")
        T.eq(completed, 0, "HM refusal does not finish learning")
        T.check(not display.StartMenu.select(old, 2), "HM notice invalidates previous touch rows")
        sync(); display.drawContents()
        T.check(display.startMenu().moveSelection and not display.startMenu().choiceState,
          "native HM warning keeps the common attack layout")
        T.eq(display.startMenu().prompt, require("src.core.game3.rom_text").plain(
          require("src.core.game3.battle.profile").get(game.session).strings.hmCantForget),
          "HM warning uses this edition's ROM text")
        if outcome ~= "replace" then
          touchRow(5)
          advanceUntil(function() return Choice.active end)
          touchPrompt(outcome == "cancel" and 1 or 2, Ui.handleInput)
          if outcome == "retry" then
            advanceUntil(function() return Choice.active end)
            touchPrompt(1, Ui.handleInput)
            T.check(Summary.isOpen(), "declining stop reopens native learning flow")
          end
        end
        if outcome ~= "cancel" then
          old = touchRow(2)
          T.eq(mon.moves[2], 22, "touch replaces exactly the chosen move slot")
          T.eq(mon.moves[3], 45, "neighboring move remains unchanged")
          T.eq(mon.pp[2], Pokemon.movePp(22), "native replacement restores new move PP")
          T.check(not display.StartMenu.select(old, 1), "closed chooser rejects stale touch")
        end
        advanceUntil(function() return completed > 0 end)
        T.eq(completed, 1, "learning finishes exactly once")
        T.eq(learned, outcome ~= "cancel", "native learning result matches choice")
        if outcome == "cancel" then T.eq(mon.moves[2], 33, "cancellation preserves moves") end
      end
    end
  end
  -- Field TMs use PartyMenu's private yes/no callback, not global Choice.
  local Party, Bag = require("src.ui.game3.party_menu"), require("src.core.game3.bag")
  local Items = display.gen3.Items
  local tm = Items.toNumericId("TM45")
  local beforeTm = Bag.get(game.session.bag,tm)
  Bag.add(game.session.bag,tm,3)
  local function partyInput(key) Screens.handleInput("party",Party,key,game.session) end
  local function fieldUntil(predicate)
    for _=1,40 do
      if predicate() then sync();return end
      if Party.mode=="message" then partyInput(input("a")) end
    end
    error("native field learning did not reach expected screen: "..tostring(Party.mode))
  end
  for _,style in ipairs({"hgss","hgss_dark"}) do
    options.theme_v3=style
    run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3",value=style})
    for _,outcome in ipairs({"cancel","replace"}) do
      Stack.clear(); Message.reset(); Learn.reset(); Choice.active=false
      Battle._active, Battle._st=false,nil; Ui.reset({headless=true})
      mon.moves,mon.pp,mon.maxPp,mon.ppBonusesPacked={15,33,45,10},{30,35,40,35},{30,35,40,35},0
      local count=Bag.get(game.session.bag,tm)
      display.gen3:refresh()
      T.check(display.gen3Ui:openBagItem(tm,"USE"),"TM enters the real native target flow")
      require("src.ui.game3.bag_menu").settle()
      partyInput(input("a"))
      fieldUntil(function() return Party.mode=="yesno" end)
      local first=touchPrompt(2,partyInput)
      T.eq(Party.mode,"yesno","declining learning opens stop question in the same native mode")
      T.check(not first.valid(),"same-mode question change invalidates the previous callback")
      T.eq(Bag.get(game.session.bag,tm),count,"declining the first prompt never consumes a TM")
      if outcome=="cancel" then
        touchPrompt(1,partyInput)
        fieldUntil(function() return not Learn.busy() end)
        T.eq(mon.moves[2],33,"cancelled field learning preserves moves")
        T.eq(Bag.get(game.session.bag,tm),count,"cancelled field learning preserves the TM")
      else
        touchPrompt(2,partyInput)
        touchPrompt(1,partyInput)
        T.check(Summary.isOpen(),"field retry opens the same shared replacement page")
        touchRow(2)
        fieldUntil(function() return not Learn.busy() end)
        T.eq(mon.moves[2],213,"native field replacement teaches Attract")
        T.eq(Bag.get(game.session.bag,tm),count-1,"successful field learning consumes exactly one TM")
      end
      Party.close(); Summary.close(); require("src.ui.game3.bag_menu").close()
    end
  end
  local Relearner=require("src.ui.game3.move_relearner")
  -- Older Emerald caches lack native relearner dialogue; do not invent ROM text.
  local relearnerText=require("src.core.game3.rom_text").has("gText_MonIsTryingToLearnMove")
  for _,style in ipairs(relearnerText and {"hgss","hgss_dark"} or {}) do
    options.theme_v3=style
    run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3",value=style})
    Stack.clear(); Message.reset(); Learn.reset()
    mon.moves,mon.pp,mon.maxPp,mon.ppBonusesPacked={15,33,45,10},{30,35,40,35},{30,35,40,35},0
    Relearner.show(mon,{session=game.session})
    T.check(#Relearner.moves()>0,"native relearner fixture offers a real move")
    Relearner.handleInput(input("a")); Relearner.handleInput(input("a"))
    local function relearnUntil(predicate)
      for _=1,40 do
        if predicate() then sync();return end
        if Relearner.state=="message" then Relearner.handleInput(input("a")) end
      end
      error("native relearning did not reach expected screen")
    end
    relearnUntil(function() return Relearner.state=="yesno" end)
    touchPrompt(2,Relearner.handleInput)
    relearnUntil(function() return Relearner.state=="yesno" end)
    touchPrompt(1,Relearner.handleInput)
    relearnUntil(function() return not Learn.busy() end)
    T.eq(mon.moves[2],33,"cancelled relearning preserves moves")
    Relearner.finish(false)
  end
  local remaining=Bag.get(game.session.bag,tm)
  if remaining>beforeTm then Bag.remove(game.session.bag,tm,remaining-beforeTm) end
  mon.moves, mon.pp, mon.maxPp, mon.ppBonusesPacked = savedMoves, savedPp, savedMax, savedBonus
  Stack.clear(); Message.reset(); Learn.reset(); Ui.reset({ headless = true })
  Battle._active, Battle._st = false, nil
end
dofile(path .. "/tests/gen3_fixture.lua")
