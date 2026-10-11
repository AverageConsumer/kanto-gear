-- Battle-only ownership: field UI, Info input and other mods remain authoritative.
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
local run = T.sdk.loadMod(path, { generation = gen, data = T.fixtures.load() })
T.eq(run.mod.state, "loaded", "battle modes load")
local function hook(name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
  error("missing hook " .. name)
end
local step, compose = hook("input.step"), hook("render.compose")
local display, runtime = up(step, "displayRuntime"), up(step, "hgssRuntime")
local refresh = up(compose, "refreshBattle")
local theme = up(display.drawContents, "THEME")
local api = up(display.saveHome, "mod")
local world = { map = { id = "FIX_ROUTE", def = {} } }
local raw = { isBattleState = true, screenId = gen == 2 and "Gen2BattleState" or "BattleState",
  menuIndex = 1, moveIndex = 1 }
local mon = { species = "FIXMON_A", name = "PARTNER", level = 10, hp = 20,
  maxHp = 30, stats = { hp = 30 }, moves = {} }
local stack = { states = { world, raw }, top = function(self) return self.states[#self.states] end }
local game = { data = run.data, world = world, overworld = world, stack = stack,
  input = { pressQueue = {} }, save = { generation = gen,
    player = { name = "RED", id = 7 }, party = { mon }, inventory = {}, boxes = {},
    pokedex = { seen = {}, caught = {} } } }
run.loader.events:emit("game.ready", { game = game })
local snapshot = { prompt = "menu", kind = "wild", revision = 1, party = { mon },
  player = mon, enemy = mon, moves = { { id = "FIX_MOVE_A", pp = 10, maxPp = 10 } } }
api.battle = api.battle or {}
api.battle.snapshot = function() return snapshot end
run.loader.modOptions.kanto_gear = run.loader.modOptions.kanto_gear or {}
local options = run.loader.modOptions.kanto_gear
options.ui_motion = false
up(hook("battle.bottom_ui_visible"), "hasDisplay", function() return true end, true)
up(hook("battle.bottom_ui_visible"), "displayReady", true, true)
local function call(name, state, previous)
  local calls = 0
  local result = hook(name)(function(received)
    calls = calls + 1
    T.eq(received, state, "hook preserves state identity")
    return previous
  end, state)
  T.eq(calls, 1, "previous hook runs exactly once")
  return result
end
local party = { screenId = gen == 2 and "Gen2PartyMenu" or "PartyMenu", index = 1 }
if gen == 1 then party.party = game.save.party end
local choice = { onChoose = function() end, index = 1, labels = { "YES", "NO" } }
for _, style in ipairs({ "hgss", "hgss_dark" }) do
  options.theme_v3 = style
  run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
  for _, mode in ipairs({ "standard", "info", "gear", "full" }) do
    options.battle_view = mode
    local owns = mode == "gear" or mode == "full"
    stack.states = { world, raw }; snapshot.prompt = "menu"; refresh()
    T.eq(call("battle.bottom_ui_visible", raw, true), not owns, mode .. " command visibility")
    T.eq(call("battle.status_hud_visible", raw, true), mode ~= "full", mode .. " HUD visibility")
    T.eq(call("battle.bottom_ui_visible", raw, false), false, "respect another mod's hidden commands")
    T.eq(call("battle.status_hud_visible", raw, false), false, "respect another mod's hidden HUD")
    T.eq(call("screen.render_visible", {}, true), true, "unknown menus always stay native")
    T.eq(call("screen.render_visible", party, true), not owns, mode .. " team menu visibility")
    T.eq(call("screen.render_visible", party, false), false, "respect other menu suppression")
    T.eq(call("ui.party.grid_navigation", party, true), true, "respect another mod's party navigation")
    raw.menuIndex, snapshot.menuIndex = 1, 1
    game.input.pressQueue = { "down", "a" }
    local before = game.input.pressQueue
    step(function(received)
      T.eq(received.input.pressQueue, before, "same input queue reaches the host")
      T.eq(table.concat(before, ","), owns and "" or "down,a", mode .. " hardware ownership")
    end, game, .016)
    T.eq(raw.menuIndex, owns and (mode == "full" and 3 or 4) or 1,
      mode .. " cursor follows the visible lower geometry only when owned")
    snapshot.prompt = "moves"; raw.phase = "moves"; refresh()
    T.eq(call("battle.move_grid_navigation", raw, false), owns, mode .. " move navigation")
    raw.phase = nil
    T.check(pcall(display.drawContents), mode .. " move page renders")
    -- The same mode contract must survive native party/text/learning overlays.
    local H=theme.hgss
    local info,drawInfo=0,H.enemyInfoHero
    H.enemyInfoHero=function(self,...) info=info+1;return drawInfo(self,...) end
    local panels,drawMessage,drawFull=0,H.battleMessage,H.battleFullMessage
    H.battleMessage=function(self,...) panels=panels+1;return drawMessage(self,...) end
    H.battleFullMessage=function(self,...) panels=panels+1;return drawFull(self,...) end
    game.input.pressQueue={}
    snapshot.message={"THE ACTUAL BATTLE TEXT"};snapshot.prompt="advance"
    stack.states={world,raw,{isTextBox=true}}
    T.check(pcall(display.drawContents),mode.." native text overlay renders")
    T.eq(panels,mode=="info" and 0 or 1,mode.." lower text follows the mode contract")
    if mode=="info" then
      T.eq(info,1,"Info stays visible during native text")
      stack.states={world,raw,party};display.drawContents()
      T.eq(info,2,"Info stays visible during native party selection")
      local tap=up(up(compose,"touchEvent"),"tap")
      tap(5,5)
      T.eq(#game.input.pressQueue,0,"Info back cannot cancel the original party menu")
    end
    H.enemyInfoHero,H.battleMessage,H.battleFullMessage=drawInfo,drawMessage,drawFull
    snapshot.message=nil;snapshot.prompt="locked"
    raw.pendingLearn={index=1,move="FIX_MOVE_A"};raw.battle={party={mon}}
    raw.phase="ask-forget";choice.index=1;raw.forgetChoice=1
    local learner={screenId="MoveLearnMenu",mon=mon,newMoveId="FIX_MOVE_A",index=1}
    if gen==1 then stack.states={world,raw,learner,choice}
    else stack.states={world,raw} end
    refresh()
    game.input.pressQueue={"right","a"}
    step(function() end,game,.016)
    T.eq(gen==1 and choice.index or raw.forgetChoice,owns and 2 or 1,mode.." learning answers follow the lower horizontal layout only when owned")
    T.eq(table.concat(game.input.pressQueue,","),owns and "" or "right,a",mode.." learning input retains one authority")
    game.input.pressQueue={};raw.pendingLearn,raw.battle,raw.phase=nil,nil,nil
    -- No lower presentation suppresses original menus outside battle.
    stack.states = { world, party }
    T.eq(call("screen.render_visible", party, true), true, mode .. " field party is visible")
    raw.kind = "link"; stack.states = { world, raw }; refresh()
    T.eq(call("battle.bottom_ui_visible", raw, true), true, "unsupported link battles remain native")
    raw.kind = nil
    up(hook("battle.bottom_ui_visible"), "displayReady", false, true)
    T.eq(call("battle.bottom_ui_visible", raw, true), true, "display loss immediately restores native commands")
    up(hook("battle.bottom_ui_visible"), "displayReady", true, true)
    display.autoBattle.shown = false
    T.eq(call("battle.bottom_ui_visible", raw, true), true, "swapping away from Gear restores native commands")
    T.eq(call("battle.status_hud_visible", raw, true), true, "swapping away from Gear restores native HP")
    display.autoBattle.shown = nil
  end
end
run.release()
T.finish("Battle modes Gen " .. gen)
