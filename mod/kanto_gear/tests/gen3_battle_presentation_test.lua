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
  local Stack = require("src.ui.game3.stack")
  local Message = require("src.ui.game3.message")
  local Choice = require("src.ui.game3.choice")
  local Battle = require("src.core.game3.battle")
  local Ui = require("src.core.game3.battle.ui")
  local Learn = require("src.core.game3.battle.learn_move")
  T.check(display.gen3Presentation.bottomHook and display.gen3Presentation.hudHook,
    "the real API 3 host provides both native visibility hooks")
  T.eq(rawget(game, "mousepressed"), nil, "Gear uses native pointer dispatch without patching window handlers")
  local State = require("src.core.game3.battle.state")
  local Pokemon = require("src.core.game3.pokemon")
  local mon = game.session.party[1]
  local savedMoves, savedPp, savedMax, savedBonus = mon.moves, mon.pp, mon.maxPp, mon.ppBonusesPacked
  local now = 100
  love.timer.getTime = function() now = now + 0.06; return now end
  up(compose, "nextClock", math.huge)
  local canvas = up(up(compose, "pumpDisplay"), "canvas")
  canvas.requestImageData, canvas.pollImageData = nil, nil
  canvas.newImageData = function() return {} end
  local context = { secondScreen = {
    detected = function() return true end, pollTouch = function() end,
    push = function() return true end,
  } }
  local function input(key)
    return { wasPressed = function(_, k) return k == key end, isDown = function() return false end }
  end
  local function sync()
    display.gen3.syncScreens(); refresh()
    compose(function() end, {}, context)
  end
  local options = run.loader.modOptions.kanto_gear
  options.display_mode, options.display_target = "separate", "secondary"
  options.ui_motion = false
  local inputHook
  for _,entry in ipairs(run.loader.hooks.chains["input.step"]) do
    if entry.owner=="kanto_gear" then inputHook=entry.callback end
  end
  local runtime=up(inputHook,"hgssRuntime")
  for _, style in ipairs({ "hgss", "hgss_dark", "cgear", "cgear_dark" }) do
    options.theme_v3 = style
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
    for _, mode in ipairs({ "standard", "gear", "full" }) do
      options.battle_view = mode
      Stack.clear(); Message.reset(); Learn.reset(); Choice.active = false
      mon.moves, mon.pp = { 15, 33, 45, 10 }, { 30, 35, 40, 35 }
      mon.maxPp, mon.ppBonusesPacked = {30,35,40,35}, 0
      local st = State.new({playerParty=game.session.party,foeParty={mon},wild=true})
      Battle._active, Battle._auto, Battle._phase, Battle._st = true, false, "awarding", st
      Ui.reset({headless=false}); Ui.bindState(st,game.session)
      local done
      Learn.begin({mon=mon,moveId=22,battleText=true,pushMsg=Ui.push,
        askYesNo=Ui.askYesNo,askForget=Ui.askForget,onDone=function(value) done=value end})
      for _=1,40 do
        Ui.pump()
        if Choice.active then break end
        if Message.isOpen() then Message.skipReveal(); Message.advance() end
      end
      T.check(Choice.active,"native learning question opens")
      sync()
      local view=assert(display.startMenu())
      local model,draw= nil,display.MovePage.drawPrompt
      display.MovePage.drawPrompt=function(H,value) model=value;return draw(H,value) end
      Ui.handleInput(input("right")); sync(); display.drawContents()
      T.eq(view.index,mode=="standard" and 1 or 2,mode.." right changes the real answer")
      T.eq(model.selection,view.index,style.." visible answer follows native D-pad cursor")
      Ui.handleInput(input("left"));sync();display.drawContents()
      T.eq(view.index,1,mode.." left selects YES")
      T.eq(model.selection,1,"YES focus matches the native answer")
      -- A confirms the focused answer through the host's normal learning flow.
      if mode~="standard" then
        Ui.handleInput(input("right"));Ui.handleInput(input("a"));sync()
        T.check(not require("src.ui.game3.summary_menu").isOpen(),"NO does not open replacement slots")
      else
        Ui.handleInput(input("a"));sync()
        T.check(require("src.ui.game3.summary_menu").isOpen(),"native YES opens replacement slots")
      end
      display.MovePage.drawPrompt=draw
      require("src.ui.game3.summary_menu").close()
    end
  end
  Stack.clear(); Message.reset(); Learn.reset(); Choice.active=false
  mon.moves,mon.pp,mon.maxPp,mon.ppBonusesPacked=savedMoves,savedPp,savedMax,savedBonus
  -- Damage is already committed while the native HP bar is still full.
  local Anim=require("src.core.game3.battle.anim")
  local Schema=require("src.core.game3.save_schema_firered")
  local Party=require("src.core.game3.party")
  local foes=Schema.newGame({version=os.getenv("POKEPORT_VERSION"),name="FOE",rngSeed=4080})
  for _=1,3 do Party.giveMon(foes,Pokemon.speciesFromNational(19),20) end
  while #game.session.party<2 do Party.giveMon(game.session,Pokemon.speciesFromNational(25),20) end
  options.battle_view="full"
  for _,doubles in ipairs({false,true}) do
    for _,party in ipairs({game.session.party,foes.party}) do
      for _,mon in ipairs(party) do mon.hp=mon.maxHp end
    end
    local st=State.new({playerParty=game.session.party,foeParty=foes.party,double=doubles})
    Battle._active,Battle._auto,Battle._phase,Battle._st=true,false,"actions",st
    Ui.reset({headless=true});Ui.bindState(st,game.session)
    local keys={}
    for id=0,doubles and 3 or 1 do
      local b=st.battlers[id]
      local key=doubles and id or b.side
      -- Native singles battlers use parity rather than a side field.
      if not doubles then key=id==0 and "player" or "enemy" end
      keys[#keys+1]=key
      b.mon.hp=0
      Anim.present(key).displayHp=12
    end
    sync()
    local players,enemies=runtime.battleTeams()
    T.check(runtime.battleStatus("player").statusId~="FNT","player portrait does not reveal final faint status")
    T.check(runtime.battleStatus("enemy").statusId~="FNT","enemy portrait does not reveal final faint status")
    local xpKey=doubles and 0 or "player"
    for _,ratio in ipairs({0.2,0.8,1,0,0.35}) do
      Anim.present(xpKey).displayExp=ratio
      sync()
      T.eq(runtime.battleStatus("player").expProgress,ratio,"single and double active HUD follows displayed EXP")
    end
    Anim.present(xpKey).displayExp=nil
    for slot=1,doubles and 2 or 1 do
      T.eq(players[slot].alive,true,"player team ball waits for displayed HP")
      T.eq(enemies[slot].alive,true,"foe team ball waits for displayed HP")
      T.eq(players[slot].status,nil,"player team ball does not leak final faint status")
      T.eq(enemies[slot].status,nil,"foe team ball does not leak final faint status")
    end
    if not doubles then
      local outgoing=st.enemy
      st.enemy=State.makeBattler(foes.party[3],"enemy",{id=1,partyIndex=3})
      Anim.present("enemy").shown=outgoing
      sync();players,enemies=runtime.battleTeams()
      T.eq(enemies[1].alive,true,"same-species replacement retains the outgoing foe's shown HP")
      T.eq(enemies[3].alive,true,"incoming reserve does not borrow outgoing HP")
      Anim.present("enemy").shown=nil;Anim.present("enemy").displayHp=foes.party[3].hp
      sync();players,enemies=runtime.battleTeams()
      T.eq(enemies[1].alive,false,"outgoing foe settles once the native switch appears")
      T.eq(enemies[3].alive,true,"incoming foe keeps its own team slot")
      st.enemy=outgoing
    end
    for _,key in ipairs(keys) do Anim.present(key).displayHp=0 end
    sync();players,enemies=runtime.battleTeams()
    for slot=1,doubles and 2 or 1 do
      T.eq(players[slot].alive,false,"player team ball faints at displayed zero HP")
      T.eq(enemies[slot].alive,false,"foe team ball faints at displayed zero HP")
    end
    for _,key in ipairs(keys) do Anim.present(key).displayHp=nil end
  end
  Battle._active,Battle._st=false,nil;Ui.reset({headless=true})
end
dofile(path .. "/tests/gen3_fixture.lua")
