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
local data = T.fixtures.load()
if gen == 2 then
  -- The generic SDK fixture omits Gen 2's extracted growth coefficients.
  data.pokemon.growthRates = {
    MEDIUM_FAST = { numerator = 1, denominator = 1 },
    MEDIUM_SLOW = { numerator = 6, denominator = 5, squared = -15, linear = 100, constant = 140 },
    FAST = { numerator = 4, denominator = 5 }, SLOW = { numerator = 5, denominator = 4 },
  }
end
local run = T.sdk.loadMod(path, { generation = gen, data = data })
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
-- Real Input.step polls pads AFTER input.step hooks. Keyboard and pad edges
-- must still select the same semantic command without a second native move.
do
  local Input = require("src.core.Input")
  local input = setmetatable({}, { __index = Input })
  input:reset()
  local lateKey
  input.pollPads = function(self)
    if lateKey then self.pressQueue[#self.pressQueue + 1] = lateKey; lateKey = nil end
  end
  local originalPoll = input.pollPads
  game.input = input
  stack.states = { world, raw }; raw.phase = "menu"; raw.kind = nil
  snapshot.prompt = "menu"
  for _, mode in ipairs({ "standard", "info", "gear", "full" }) do
    options.battle_view = mode
    local owns = mode == "gear" or mode == "full"
    for index = 1, 4 do
      for _, key in ipairs({ "left", "right", "up", "down" }) do
        for _, source in ipairs({ "keyboard", "controller" }) do
          raw.menuIndex = index; refresh()
          input:reset()
          if source == "keyboard" then input.pressQueue = { key } else lateKey = key end
          step(function() end, game, .016)
          input:step()
          local expected = owns and (mode == "full" and runtime.fullRootDirection(index, key)
            or runtime.rootDirection(index, key)) or index
          T.eq(raw.menuIndex, expected, mode .. " " .. source .. " follows the visible root")
          T.eq(input:wasPressed(key), not owns, mode .. " has one navigation authority")
        end
      end
    end
  end
  stack.states = { world, raw }; raw.phase = "mimicSelect"
  raw.mimicMoves = { "FIX_MOVE_A", "FIX_MOVE_A", "FIX_MOVE_A", "FIX_MOVE_A" }
  snapshot.prompt = "mimic"
  for _, mode in ipairs({ "standard", "info", "gear", "full" }) do
    options.battle_view = mode
    local owns = mode == "gear" or mode == "full"
    for _, key in ipairs({ "left", "right", "up", "down" }) do
      raw.mimicIndex = 1; refresh(); input:reset(); lateKey = key
      step(function() end, game, .016); input:step()
      local expected = key == "down" and 2 or key == "up" and 4 or 1
      T.eq(raw.mimicIndex, owns and expected or 1, mode .. " Mimic follows its visible vertical list")
      T.eq(input:wasPressed(key), not owns, "Mimic has one input authority")
    end
  end
  raw.mimicMoves, raw.phase, snapshot.prompt = nil, "menu", "menu"
  mon.moves = { { id = "FIX_MOVE_A", pp = 10 }, { id = "FIX_MOVE_A", pp = 5 } }
  local summary = { screenId = gen == 2 and "Gen2SummaryMenu" or "SummaryMenu",
    mon = mon, page = 1, expToNext = function() return 100 end,
    itemName = function() end, otName = function() return "RED" end,
    otId = function() return 7 end }
  local function edge(key)
    input:reset(); lateKey = key
    step(function() end, game, .016); input:step()
  end
  for _, mode in ipairs({ "standard", "info", "gear", "full" }) do
    options.battle_view = mode
    options.info_level = "enhanced"
    stack.states = { world, raw, summary }; refresh()
    display.nativeSummary = nil
    local state = display.summaryContext()
    local owns = mode == "gear" or mode == "full"
    edge("right")
    T.eq(state.page, owns and 2 or 1, mode .. " controller turns the visible summary tab")
    T.eq(input:wasPressed("right"), not owns, mode .. " summary retains one input authority")
    if owns then
      edge("down")
      T.eq(state.moveIndex, 2, "summary D-pad selects a real move")
      edge("a")
      T.check(up(display.filterBattleDetailsInput, "moveInfo") ~= nil, "A opens the selected move details")
      T.check(not input:wasPressed("a"), "details do not open the native move editor")
      edge("b")
      T.eq(up(display.filterBattleDetailsInput, "moveInfo"), nil, "controller B closes only the details")
      T.check(not input:wasPressed("b"), "detail close never dismisses the team summary")
      T.eq(state.page, 2, "detail return retains the visible tab")
      edge("left"); edge("left")
      T.eq(state.page, state.pages, "summary tabs wrap backwards")
      edge("right")
      T.eq(state.page, 1, "summary tabs wrap forwards")
      edge("b")
      T.check(input:wasPressed("b"), "summary close goes to the native owner")
      if gen == 1 then T.eq(summary.page, 2, "Gen 1 B closes instead of changing the hidden page") end
    end
  end
  stack.states = { world, raw }
  local patchedPoll = input.pollPads
  display.bindBattleInput({ input = {}, generation = gen })
  T.eq(input.pollPads, originalPoll, "rebinding restores the previous input object")
  T.check(patchedPoll ~= originalPoll, "real controller polling was wrapped")
end

-- Legacy battle snapshots omit EXP; recover it from the current save slot,
-- use each species' growth curve, and invalidate a cached team when EXP changes.
do
  local def = game.data.pokemon[mon.species]
  local savedGrowth = def.growthRate
  for _, growthId in ipairs({ "MEDIUM_FAST", "MEDIUM_SLOW", "FAST", "SLOW" }) do
    def.growthRate = growthId
    local growth = api.content.growth_rates:get(growthId)
    T.check(growth and growth.expForLevel, growthId .. " is available")
    if growth and growth.expForLevel then
      local first, last = growth.expForLevel(10), growth.expForLevel(11)
      mon.level = 10
      mon.exp, mon.experience = math.floor((first + last) / 2), math.floor((first + last) / 2)
      snapshot.party = { { slot = 1, species = mon.species, level = 10, hp = 20, maxHp = 30 } }
      refresh()
      local card = display.partyView(up(refresh, "battle").party[1])
      local expected = (mon.exp - first) / (last - first)
      T.eq(card.expProgress, expected, growthId .. " battle party uses the real accumulated EXP")
      T.eq(display.partyExpProgress(mon), expected, "field and battle EXP agree")
    end
  end
  mon.level = 100
  T.eq(display.partyExpProgress(mon), 1, "level 100 has a full EXP bar")
  mon.level, mon.isEgg = 10, true
  T.eq(display.partyExpProgress(mon), 0, "eggs never expose hatchling EXP")
  mon.isEgg, def.growthRate = nil, "MEDIUM_FAST"
  mon.exp, mon.experience = 1100, 1100
  local originalSnapshot = api.battle.snapshot
  api.battle.snapshot = function()
    return { prompt = "party", revision = 17, party = {
      { slot = 1, species = mon.species, level = mon.level, hp = mon.hp, maxHp = mon.maxHp } } }
  end
  refresh()
  up(refresh, "dirty", false, true)
  mon.exp, mon.experience = mon.exp + 10, mon.experience + 10
  refresh()
  T.check(up(refresh, "dirty"), "EXP gain redraws a cached party even without a battle revision")
  def.growthRate = savedGrowth
  api.battle.snapshot = originalSnapshot
end
run.release()
T.finish("Battle modes Gen " .. gen)
