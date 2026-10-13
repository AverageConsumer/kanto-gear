-- Experimental companion contract: native UI and hardware input stay intact.
local T = require("tests.modkit")
love.graphics.arc = love.graphics.arc or function() end
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local gen = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local function hook(run, name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local function battleLog(run, theme)
  local H = theme.hgss
  H.v4BattleLog = { entries = { "Previous encounter" }, last = "Last encounter ended" }
  run.loader.events:emit("battle.started", {})
  H:battleMessage({ "New encounter" }, true)
  T.eq(#H.v4BattleLog.entries, 0, "every encounter starts with an empty battle log")
  T.eq(H.v4BattleLog.last, "New encounter", "new encounter owns its first message")
  H:battleMessage({ "First attack" }, true)
  H:battleMessage({ "Second attack" }, true)
  local log = H.v4BattleLog
  T.eq(log.entries[1], "First attack", "current encounter retains its last message")
  T.eq(log.entries[2], "New encounter", "history only includes this encounter")
  local clock, now = H.clock, H:clock()
  H.clock = function() return now + 30 end
  H:battleMessage({ "Second attack" }, true)
  T.eq(log.entries[2], "New encounter", "a long pause inside the fight does not erase its history")
  H.clock = clock
  for _, event in ipairs({ "battle.turn_started", "battle.battler_switched", "battle.turn_ended" }) do
    run.loader.events:emit(event, {})
    T.eq(H.v4BattleLog, log, "turns and Pokemon switches preserve the current log")
  end
  run.loader.events:emit("battle.ended", {})
  T.eq(H.v4BattleLog, nil, "ending a fight discards its battle log")
  run.loader.events:emit("battle.started", {})
  H:battleMessage({ "Second attack" }, true)
  T.eq(#H.v4BattleLog.entries, 0, "identical text in an immediate rematch cannot restore old history")
  run.loader.events:emit("battle.ended", {})
end
local function preservedHooks(run, states)
  for _, name in ipairs({ "battle.bottom_ui_visible", "battle.status_hud_visible",
      "screen.render_visible", "battle.move_grid_navigation", "ui.party.grid_navigation" }) do
    T.check(hook(run, name) ~= nil, "battle modes expose a guarded hook for " .. name)
    for _, state in ipairs(states) do
      for _, answer in ipairs({ false, true }) do
        T.eq(run.loader.hooks:call(name, function() return answer end, state), answer,
          "other mods retain their native visibility/navigation decision")
      end
    end
  end
end
local function hardware(run, display, game, scenes)
  local step = assert(hook(run, "input.step"))
  local original = game.input
  for _, scene in ipairs(scenes) do
    scene()
    for _, keys in ipairs({ { "up" }, { "down" }, { "left" }, { "right" },
        { "a" }, { "b" }, { "start", "select" }, { "x" }, { "left", "a" } }) do
      local queue = {}; for i, key in ipairs(keys) do queue[i] = key end
      game.input = { pressQueue = queue }
      local calls = 0
      local result = step(function(received, dt)
        calls = calls + 1
        T.eq(received, game, "hardware reaches the original game")
        T.eq(dt, .016, "hardware preserves the original timestep")
        T.eq(received.input.pressQueue, queue, "Gear does not substitute a navigation queue")
        T.eq(table.concat(queue, ","), table.concat(keys, ","),
          "hardware keys pass through unchanged, including simultaneous presses")
        return "native-result"
      end, game, .016)
      T.eq(calls, 1, "native input handler runs exactly once")
      T.eq(result, "native-result", "native handler result is preserved")
    end
  end
  game.input = original
end

local function nativeCursorPresentation(theme, display)
  local H=theme.hgss
  T.eq(H.nativeFocus,false,"companion presentation does not inherit hardware focus")
  local frame,rounded=H.focusFrame,H.roundedFocusFrame
  local frames=0
  H.focusFrame=function() frames=frames+1 end
  H.roundedFocusFrame=function() frames=frames+1 end
  local entry={x=8,y=50,w=144,h=25,label="CHOICE",selected=true}
  local move={name="TACKLE",type="NORMAL",available=true,ppText="10/10",powerText="40",accuracyText="100"}
  for _,draw in ipairs({
    function() H:startMenu({entries={entry},fixedLayout=true}) end,
    function() H:choiceScreen({entries={entry}}) end,
    function() H:naming({name="RED",entries={entry}}) end,
    function() H:nativeGrid({entries={entry}}) end,
    function() H:actionRow(18, 104, 204, 32, "WITHDRAW", "switch", 0, H.nativeFocus and entry.selected) end,
    function() H:pcList({entries={entry}}) end,
    function() H:battleMimic({moves={move},index=1}) end,
    function() display.MovePage.draw(H,{moves={move},newMove=move,details=true}) end,
    function() display.MovePage.drawPrompt(H,{choices={"YES","NO"},mon={}}) end,
    function() H:battleBag({title="BAG",items={{label="POTION",right="x2"}},index=1},{},{}) end,
  }) do
    local ok,err=pcall(draw)
    T.check(ok,"native touch menu renders: "..tostring(err))
  end
  T.eq(frames,0,"native cursor markers never appear on the touch pages")
  T.eq(entry.selected,true,"presentation leaves the original selection facts intact")
  H:panel(8,50,144,25,true)
  T.eq(frames,1,"Gear-owned selections still have their visual feedback")
  H.focusFrame,H.roundedFocusFrame=frame,rounded
end

if gen == 3 then
  local refs = {}
  _G.KANTO_GEAR_BEFORE_LOAD = function()
    for module, names in pairs({
      ["src.core.game3.battle.ui"] = { "draw", "handleInput" },
      ["src.core.game3.battle.healthbox"] = { "draw" },
      ["src.ui.game3.battle_chrome"] = { "drawPanel", "drawMenuFrames", "drawTerrain" },
      ["src.ui.game3.party_menu"] = { "draw", "handleInput" },
      ["src.core.game3.oam"] = { "buildOamBuffer" },
      ["src.ui.game3.frlg_font"] = { "draw" },
      ["src.ui.game3.screens"] = { "draw" },
    }) do
      local target = require(module)
      for _, name in ipairs(names) do refs[#refs + 1] = { target, name, target[name] } end
    end
  end
  _G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
    for _, ref in ipairs(refs) do
      T.check(type(ref[1][ref[2]]) == "function", "native function remains callable: " .. ref[2])
    end
    local Ui = require("src.core.game3.battle.ui")
    local Battle = require("src.core.game3.battle")
    local Stack = require("src.ui.game3.stack")
    local Message = require("src.ui.game3.message")
    local Bag = require("src.ui.game3.bag_menu")
    local Party = require("src.ui.game3.party_menu")
    local Summary = require("src.ui.game3.summary_menu")
    local Pokemon = require("src.core.game3.pokemon")
    local foes = require("src.core.game3.save_schema_firered").newGame({
      version = os.getenv("POKEPORT_VERSION"), name = "FOE", rngSeed = 4100 })
    require("src.core.game3.party").giveMon(foes, Pokemon.speciesFromNational(19), 10)
    local st = require("src.core.game3.battle.state").new({
      playerParty = game.session.party, foeParty = foes.party, wild = true })
    Battle._active, Battle._auto, Battle._phase, Battle._st = true, false, "command", st
    Ui.reset({ headless = true }); Ui.bindState(st, game.session); Ui.openMenu(0)
    local refresh = up(hook(run, "render.compose"), "refreshBattle")
    local function scene(fn)
      return function()
        Summary.close(); Party.close(); Bag.close(); Stack.clear(); Message.reset(); Ui.openMenu(0)
        fn(); display.gen3.syncScreens(); refresh()
        T.check(pcall(display.drawContents), "companion renders alongside the native screen")
      end
    end
    local scenes = {
      scene(function() end),
      scene(function() Ui._mode = "moves" end),
      scene(function() Party.show(game.session.party, { session = game.session, battle = st }) end),
      scene(function() Bag.show(game.session.bag, { session = game.session, battle = st }); Bag.settle() end),
      scene(function() Summary.openMenu(game.session.party, 1, { session = game.session }) end),
      scene(function() Message.show("A native battle message", { frame = "battle", speed = 0 }) end),
    }
    for _, style in ipairs({ "hgss", "hgss_dark" }) do
      run.loader.modOptions.kanto_gear.theme_v3 = style
      run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
      nativeCursorPresentation(up(display.drawContents,"THEME"), display)
      battleLog(run, up(display.drawContents, "THEME"))
      hardware(run, display, game, scenes)
      assert(loadfile(path .. "/tests/press_feedback_cases.lua"))()(T,display,up(display.drawContents,"THEME").hgss)
      assert(loadfile(path .. "/tests/sprite_runtime_cases.lua"))()(T,display,up(hook(run,"input.step"),"hgssRuntime"),gen,up)
      assert(loadfile(path .. "/tests/trainer_markers_cases.lua"))()(T,display,up(hook(run,"input.step"),"hgssRuntime"),gen,up)
      scenes[#scenes]()
      local guard=display.syncTouchGuard(); guard.readyAt=0
      up(display.drawContents,"touchDown",{x=80,y=60,epoch=guard.epoch},true)
      display.drawContents()
      T.eq(up(display.drawContents,"THEME").hgss.touchX,nil,
        "native battle text never animates the commands beneath it")
      up(display.drawContents,"touchDown",nil,true)
      scenes[1]()
      guard=display.syncTouchGuard();guard.readyAt=0
      up(display.drawContents,"touchDown",{x=80,y=60,epoch=guard.epoch},true)
      display.drawContents()
      T.eq(up(display.drawContents,"THEME").hgss.touchX,80,
        "native Gen3 command selection retains press feedback")
      up(display.drawContents,"touchDown",nil,true)
    end
    preservedHooks(run, { display.gen3:battleState(), Stack.top() or {} })
    for _, ref in ipairs(refs) do T.check(type(ref[1][ref[2]]) == "function", "native handler remains callable after transitions") end
    Summary.close(); Party.close(); Bag.close(); Stack.clear(); Message.reset()
    Battle._active, Battle._st = false, nil; Ui.reset({ headless = true })
  end
  dofile(path .. "/tests/gen3_fixture.lua")
else
  local run = T.sdk.loadMod(path, { generation = gen, data = T.fixtures.load() })
  T.eq(run.mod.state, "loaded", "companion loads")
  local input = assert(hook(run, "input.step"))
  local display = up(input, "displayRuntime")
  local theme = up(display.drawContents, "THEME")
  local refresh = up(hook(run, "render.compose"), "refreshBattle")
  local prepare = up(refresh, "prepareBattleSnapshot")
  T.eq(theme:moveUnavailableReason({pp=0,disabled=true}),"NO PP","zero PP takes priority over other locks")
  T.check(prepare({moves={{pp=10}}},{moves={{pp=10,disabled=true}}}),"new lock invalidates cached battle cards")
  T.check(prepare({moves={{pp=10,disabled=true,disabledReason="A"}}},
    {moves={{pp=10,disabled=true,disabledReason="B"}}}),"changed lock reason invalidates cached details")
  T.check(not prepare({moves={{pp=10}}},{moves={{pp=10}}}),"unchanged move availability keeps the cached frame")
  local tap = up(up(hook(run, "render.compose"), "touchEvent"), "tap")
  local tapBattle = up(tap, "tapBattle")
  local api = up(display.saveHome, "mod")
  local world = { map = { id = "FIX_ROUTE", def = {} } }
  local raw = { isBattleState = true, screenId = gen == 2 and "Gen2BattleState" or "BattleState",
    menuIndex = 1, moveIndex = 1 }
  local party = { { species = "FIXMON_A", name = "PARTNER", level = 10,
    hp = 20, maxHp = 30, stats = { hp = 30 }, moves = {} } }
  local stack = { states = { world, raw }, top = function(self) return self.states[#self.states] end }
  local game = { data = run.data, world = world, overworld = world, stack = stack,
    input = { pressQueue = {} }, save = { generation = gen,
      player = { name = "RED", id = 7 }, party = party, inventory = {}, boxes = {},
      pokedex = { seen = {}, caught = {} } } }
  run.loader.events:emit("game.ready", { game = game })
  local state = { prompt = "menu", kind = "wild", revision = 1, party = party,
    player = party[1], enemy = party[1], moves = {
      { id = "FIX_MOVE_A", name = "EMPTY PP", type = "NORMAL", pp = 0, maxPp = 10 },
      { id = "FIX_MOVE_A", name = "MOVE", type = "NORMAL", pp = 10, maxPp = 10 },
    } }
  api.battle = api.battle or {}
  api.battle.snapshot = function() return state end
  do
    local snapshot=api.battle.snapshot
    raw.battle={player=party[1],enemy=party[1]}
    api.battle.snapshot=function()
      local out={}
      for key,value in pairs(state) do out[key]=value end
      out.player={}
      for key,value in pairs(party[1]) do out.player[key]=value end
      return out
    end
    for level=7,10 do
      raw.shownLevel=level
      refresh()
      T.eq(up(refresh,"battle").player.level,gen==2 and level or 10,"lower HUD follows native Gen 2 level presentation")
      T.eq(party[1].level,10,"displayed level never mutates actual party progress")
    end
    api.battle.snapshot=snapshot
    raw.battle,raw.shownLevel=nil,nil
    refresh()
  end
  local tapped = {}
  api.input.tap = function(_, target, key) T.eq(target, game, "touch targets native game"); tapped[#tapped + 1] = key end
  for _, style in ipairs({ "hgss", "hgss_dark" }) do
    run.loader.modOptions.kanto_gear = { theme_v3 = style, info_level = "enhanced", ui_motion = false }
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
    nativeCursorPresentation(theme, display)
    battleLog(run, theme)
    assert(loadfile(path .. "/tests/press_feedback_cases.lua"))()(T,display,theme.hgss)
    assert(loadfile(path .. "/tests/sprite_runtime_cases.lua"))()(T,display,up(hook(run,"input.step"),"hgssRuntime"),gen,up)
    for _, saved in ipairs({ "standard" }) do
      run.loader.modOptions.kanto_gear.battle_view = saved
      hardware(run, display, game, {
        function() stack.states = { world, raw }; state.prompt = "menu"; refresh() end,
        function() state.prompt = "moves"; raw.moveIndex = 1; refresh() end,
        function() stack.states[3] = { isTextBox = true }; state.prompt = "locked"; refresh() end,
      })
      T.eq(raw.moveIndex, 1, "snapshot never skips the original zero-PP cursor")
      preservedHooks(run, { raw, stack:top() })
      stack.states = { world, raw }; state.prompt = "menu"; refresh()
      for index, action in ipairs(theme.hgss.battleActions) do
        tapBattle((action.x + action.w / 2) / 1.5, (action.y + action.h / 2) / 1.5)
        T.eq(raw.menuIndex, index, "touch chooses its semantic action without D-pad navigation")
        T.eq(tapped[#tapped], "a", "explicit touch delegates native confirmation")
      end
      state.prompt = "moves"; raw.moveIndex = 2; refresh()
      local before = #tapped
      display.dispatchTouchTap(tapBattle, 110 / 1.5, 38 / 1.5)
      T.check(up(display.syncCompanionDetails, "moveInfo") ~= nil, "touch opens local attack details")
      T.eq(raw.moveIndex, 2, "inspecting another attack never changes the original cursor")
      T.eq(#tapped, before, "opening Gear details sends no native input")
      local originalInfo, rendered = theme.hgss.battleMoveInfo
      theme.hgss.battleMoveInfo = function(_, info) rendered = info end
      display.drawContents()
      T.eq(rendered.ppText, "0/10", "details show the inspected move, independently of native focus")
      T.eq(rendered.disabledLabel,theme:translate("NO PP"),"empty PP has a clear card status")
      T.eq(rendered.disabledLines[1],theme:translate("NO PP"),"empty PP details explain their restriction")
      theme.hgss.battleMoveInfo = originalInfo
      hardware(run, display, game, { function() end })
      T.check(up(display.syncCompanionDetails, "moveInfo") ~= nil, "hardware does not dismiss details in an unchanged context")
      state.prompt = "menu"; refresh()
      T.eq(up(display.syncCompanionDetails, "moveInfo"), nil, "native progression dismisses stale details")
      -- Real PP move pickers remain touchable over a native battle in every saved style.
      local selected, cancelled = nil, 0
      party[1].moves = state.moves
      local picker
      local function choose(index) selected=index;table.remove(stack.states) end
      local function cancel() cancelled=cancelled+1;table.remove(stack.states) end
      if gen==1 then
        picker=require("src.ui.MoveSelectMenu").new(game,party[1],"CHOOSE MOVE",choose,cancel)
        picker.screenId,picker.ready,picker.boxShown="MoveSelectMenu",true,true
      else
        picker=require("src.ui.gen2.MoveDeleter").new(game,{mon=party[1],onChoose=choose,onCancel=cancel})
        picker.screenId="Gen2MoveDeleter"
      end
      stack.states={world,raw,picker};state.prompt="locked";refresh()
      T.check(display.fieldPpMoveScreen(),"native battle PP chooser uses the shared page")
      T.check(pcall(display.drawContents),"native battle PP page renders")
      T.eq(display.nativeHandoff,false,"native battle PP selection remains available below")
      local x,y,w,h=display.MovePage.rect(2)
      local before=#tapped
      tap((x+w/2)/1.5,(y+h/2)/1.5)
      T.eq(tapped[#tapped],"a","native battle PP touch sends confirm")
      T.eq(#tapped,before+1,"native battle PP touch sends no cursor navigation")
      game.input={wasPressed=function(_,key) return key=="a" end,isDown=function() return false end}
      picker:update()
      T.eq(selected,2,"battle PP touch selects the native second move")
      T.eq(cancelled,0,"move selection never invokes cancellation")
      local old=display.fieldPpMoveScreen()
      T.eq(old,nil,"completed battle PP chooser no longer owns the companion")
      -- Older host contracts use an explicit PP list rather than MoveSelectMenu.
      local legacy={kind="pp_item_move",index=1,items={{label="FIRST",right="0/10"},{label="SECOND",right="5/10"}}}
      stack.states={world,raw,legacy};refresh()
      T.check(pcall(display.drawContents),"legacy battle PP contract draws the same move cards")
      tapBattle((x+w/2)/1.5,(y+h/2)/1.5)
      T.eq(legacy.index,2,"legacy PP contract shares the current page's touch geometry")
      T.eq(tapped[#tapped],"a","legacy PP contract also confirms through native input")
      stack.states={world,raw};state.prompt="menu";refresh()

    end
  end
  for _, option in ipairs(theme.optionSchema) do
    T.check(option.key ~= "trigger_tabs", "retired field shortcuts stay removed")
  end
  stack.states={world,raw};state.prompt="advance";refresh()
  local guard=display.syncTouchGuard();guard.readyAt=0
  up(display.drawContents,"touchDown",{x=80,y=60,epoch=guard.epoch},true)
  display.drawContents()
  T.eq(theme.hgss.touchX,nil,"battle advance leaves the covered commands still")
  state.prompt="menu";refresh();guard=display.syncTouchGuard();guard.readyAt=0
  up(display.drawContents,"touchDown",{x=80,y=60,epoch=guard.epoch},true)
  display.drawContents()
  T.eq(theme.hgss.touchX,80,"live battle commands retain touch feedback")
  up(display.drawContents,"touchDown",nil,true)
  run.release()
  T.finish("Touch companion Gen " .. gen)
end
