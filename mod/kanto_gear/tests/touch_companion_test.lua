-- Experimental companion contract: native UI and hardware input stay intact.
local T = require("tests.modkit")
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local gen = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local function up(fn, key, value, set)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, current = debug.getupvalue(fn, i)
    if name == key then
      if set then debug.setupvalue(fn, i, value) end
      return current
    end
  end
  error("missing upvalue " .. key)
end
local function hook(run, name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local function preservedHooks(run, states)
  for _, name in ipairs({ "battle.bottom_ui_visible", "battle.status_hud_visible",
      "screen.render_visible", "battle.move_grid_navigation", "ui.party.grid_navigation" }) do
    T.eq(hook(run, name), nil, "Gear does not intercept " .. name)
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
      T.eq(ref[1][ref[2]], ref[3], "native function remains unwrapped: " .. ref[2])
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
      hardware(run, display, game, scenes)
    end
    preservedHooks(run, { display.gen3:battleState(), Stack.top() or {} })
    for _, ref in ipairs(refs) do T.eq(ref[1][ref[2]], ref[3], "native handler remains intact after transitions") end
    Summary.close(); Party.close(); Bag.close(); Stack.clear(); Message.reset()
    Battle._active, Battle._st = false, nil; Ui.reset({ headless = true })
  end
  dofile(path .. (os.getenv("POKEPORT_VERSION") == "emerald"
    and "/tests/emerald_runtime_test.lua" or "/tests/gen3_runtime_test.lua"))
else
  local run = T.sdk.loadMod(path, { generation = gen, data = T.fixtures.load() })
  T.eq(run.mod.state, "loaded", "companion loads")
  local input = assert(hook(run, "input.step"))
  local display = up(input, "displayRuntime")
  local theme = up(display.drawContents, "THEME")
  local refresh = up(hook(run, "render.compose"), "refreshBattle")
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
  local tapped = {}
  api.input.tap = function(_, target, key) T.eq(target, game, "touch targets native game"); tapped[#tapped + 1] = key end
  for _, style in ipairs({ "hgss", "hgss_dark" }) do
    run.loader.modOptions.kanto_gear = { theme_v3 = style, info_level = "enhanced", ui_motion = false }
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
    for _, saved in ipairs({ "standard", "gear", "full", "info" }) do
      run.loader.modOptions.kanto_gear.battle_view = saved
      hardware(run, display, game, {
        function() stack.states = { world, raw }; state.prompt = "menu"; refresh() end,
        function() state.prompt = "moves"; raw.moveIndex = 1; refresh() end,
        function() stack.states[3] = { isTextBox = true }; state.prompt = "locked"; refresh() end,
      })
      T.eq(raw.moveIndex, 1, "snapshot never skips the original zero-PP cursor")
      preservedHooks(run, { raw, stack:top() })
      stack.states = { world, raw }; state.prompt = "menu"; refresh()
      for index, action in ipairs(theme.hgss.fullBattleActions) do
        tapBattle((action.x + action.w / 2) / 1.5, (action.y + action.h / 2) / 1.5)
        T.eq(raw.menuIndex, index, "touch chooses its semantic action without D-pad navigation")
        T.eq(tapped[#tapped], "a", "explicit touch delegates native confirmation")
      end
      state.prompt = "moves"; raw.moveIndex = 2; refresh()
      local before = #tapped
      display.dispatchTouchTap(tapBattle, 110 / 1.5, 40 / 1.5)
      T.check(up(display.syncCompanionDetails, "moveInfo") ~= nil, "touch opens local attack details")
      T.eq(raw.moveIndex, 2, "inspecting another attack never changes the original cursor")
      T.eq(#tapped, before, "opening Gear details sends no native input")
      local originalInfo, rendered = theme.hgss.battleMoveInfo
      theme.hgss.battleMoveInfo = function(_, info) rendered = info end
      display.drawContents()
      T.eq(rendered.ppText, "0/10", "details show the inspected move, independently of native focus")
      theme.hgss.battleMoveInfo = originalInfo
      hardware(run, display, game, { function() end })
      T.check(up(display.syncCompanionDetails, "moveInfo") ~= nil, "hardware does not dismiss details in an unchanged context")
      state.prompt = "menu"; refresh()
      T.eq(up(display.syncCompanionDetails, "moveInfo"), nil, "native progression dismisses stale details")
    end
  end
  for _, option in ipairs(theme.optionSchema) do
    T.check(option.key ~= "battle_view" and option.key ~= "trigger_tabs", "test exposes no legacy takeover options")
  end
  run.release()
  T.finish("Touch companion Gen " .. gen)
end
