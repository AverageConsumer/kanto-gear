-- Run from the host SDK checkout, with argument 1 or 2. No ROM/device needed.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local generation = assert(tonumber(arg[1]), "choose generation 1 or 2")
local run = T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")), {
  generation = generation, data = T.fixtures.load(),
})
T.eq(run.mod.state, "loaded", "complete mod loads within LuaJIT's upvalue limit")
local function upvalue(fn, target, replacement, set)
  for i = 1, debug.getinfo(fn, "u").nups do
    local key, value = debug.getupvalue(fn, i)
    if key == target then
      if set then debug.setupvalue(fn, i, replacement) end
      return value
    end
  end
  error("missing upvalue " .. target)
end
local function hook(name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local input = hook("input.step")
local display, runtime = upvalue(input, "displayRuntime"), upvalue(input, "hgssRuntime")
local theme = upvalue(display.drawContents, "THEME")
local H = theme.hgss
local drawBattle = upvalue(display.drawContents, "drawBattle")
local refreshBattle = upvalue(hook("render.compose"), "refreshBattle")
local attachBattleArtSprites = upvalue(refreshBattle, "attachBattleArtSprites")
local tap = upvalue(upvalue(hook("render.compose"), "touchEvent"), "tap")
local tapBattle = upvalue(tap, "tapBattle")
local api = upvalue(display.saveHome, "mod")
local world = { map = { id = "PALLET_TOWN", def = {} } }
local raw = { isBattleState = true, screenId = generation == 2 and "Gen2BattleState" or "BattleState",
  menuIndex = 1, moveIndex = 1 }
local stack = { states = { world, raw } }
function stack:top() return self.states[#self.states] end
local party = {}
for slot = 1, 6 do
  party[slot] = { slot = slot, species = "FIXMON_A", name = "PARTNER" .. slot,
    hp = slot == 5 and 0 or 30, maxHp = 50, level = 30, expProgress = 0.4,
    gender = generation == 2 and "male" or nil,
    status = slot == 6 and "SLP" or slot == 1 and "PAR" or nil,
    stats = { hp = 50 }, moves = {} }
end
local game = { data = run.data, world = world, overworld = world, stack = stack,
  input = { pressQueue = {} }, save = { generation = generation,
    player = { name = "RED", id = 7 }, party = party,
    inventory = {}, pokedex = { seen = {}, caught = {} }, boxes = {} } }
run.loader.events:emit("game.ready", { game = game })
local options = { theme_v3 = "hgss", battle_view = "standard", move_details = true }
run.loader.modOptions.kanto_gear = options
run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
local battle = { prompt = "menu", menuIndex = 1, moveIndex = 1, revision = 1,
  party = party, player = party[1], enemy = party[2], kind = "trainer", moves = {} }
for slot = 1, 4 do
  battle.moves[slot] = { id = "FIX_MOVE_A", name = "MOVE " .. slot, pp = 10,
    maxPp = 15, type = "NORMAL", power = 35, accuracy = 95 }
end
local function snapshot()
  upvalue(input, "battle", battle, true)
end
snapshot()
local keys, intents = {}, {}
api.input.tap = function(_, received, key)
  T.eq(received, game, "touch delegates to the current native game")
  keys[#keys + 1] = key
end
api.battle = api.battle or {}
api.battle.submit = function(_, intent) intents[#intents + 1] = intent; return true end
api.battle.snapshot = function() return battle end
local function hit(x, y) tapBattle(x / 1.5, y / 1.5) end
love.graphics.arc = love.graphics.arc or function() end
love.graphics.polygon = love.graphics.polygon or function() end
love.graphics.transformPoint = love.graphics.transformPoint or function(x, y) return x, y end


local touch = upvalue(hook("render.compose"), "touchEvent")
local now = 1
love.timer.getTime = function() return now end
local function sync() display.syncTouchGuard() end
local function step(fn)
  input(function() if fn then fn() end end, game, 1/60)
end
local function set(key, value)
  options[key] = value
  run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = key, value = value })
end
local function phase(name)
  stack.states = { world, raw }
  raw.phase = name == "moves" and (generation == 1 and "moveSelect" or "moves") or name
  battle.prompt = name == "messages" and "advance" or name
  raw.message = name == "messages" and {} or nil
  display.updateAutoBattleScreen()
end
local function shown(want, label)
  T.eq(display.gearPrimary(), want, label)
  hook("render.viewport")(function() return nil end, { width = 960, height = 540 })
  T.eq(theme.nativeWindowLayout.showGear, want, label .. " (native viewport)")
  T.eq(theme.nativeWindowLayout.showGame, not want, label .. " (game visibility)")
end
set("display_mode", "fullscreen"); set("fullscreen_start", "game")
phase("menu"); shown(false, "disabled by default")
set("auto_battle_screen", true); shown(true, "enabling opens the current decision")
phase("moves"); shown(true, "move selection stays on Gear")
phase("messages"); shown(false, "battle text returns to the game")
phase("animation"); shown(false, "animations stay on the game")
phase("menu"); shown(true, "next turn opens Gear again")
local snapshotCalls = 0
local snapshotFn = api.battle.snapshot
api.battle.snapshot = function(...) snapshotCalls = snapshotCalls + 1; return snapshotFn(...) end
for i = 1, 120 do display.updateAutoBattleScreen() end
T.eq(snapshotCalls, 0, "stable decisions do not add per-frame snapshots")
-- Actual input hook uses the newly updated native state, not the old snapshot.
step(function() raw.phase = "messages"; battle.prompt = "advance" end)
shown(false, "decision commit returns to the game in the same input step")
step(function() raw.phase = "menu"; battle.prompt = "menu" end)
shown(true, "next decision is detected before drawing the next frame")
T.eq(display.motion.started, nil, "auto switch does not animate an old Gear screen")
-- Y/F6 can override the current decision segment without altering the saved layout.
local oldKeyboard = love.keyboard.isDown
local held = false
love.keyboard.isDown = function(key) return key == "f6" and held end
held = true; step(); held = false; step()
shown(false, "manual swap overrides the automatic choice")
phase("moves"); shown(false, "override persists within the decision flow")
phase("messages"); phase("menu"); shown(true, "next decision re-arms automatic selection")
love.keyboard.isDown = oldKeyboard
-- Menus above the battle remain selectable, including forced replacement.
local nativeParty = { screenId = generation == 1 and "PartyMenu" or "Gen2PartyMenu",
  isPartyMenu = true, index = 1, forceSwitch = true }
stack.states = { world, raw, nativeParty }; display.updateAutoBattleScreen()
shown(true, "party selection stays on Gear")
local nativeBag = generation == 1
  and { screenId = "BagMenu", items = { { label = "POTION" } }, index = 1 }
  or require("src.ui.gen2.PackMenu").new(game, {})
nativeBag.screenId = generation == 1 and "BagMenu" or "Gen2PackMenu"
stack.states = { world, raw, nativeBag }; display.updateAutoBattleScreen()
shown(true, "bag selection stays on Gear")
nativeBag.message = { "Cannot use that here." }; display.updateAutoBattleScreen()
shown(false, "bag messages are shown on the game")
stack.states = { world, raw, { screenId = "UnknownModMenu" } }; display.updateAutoBattleScreen()
shown(false, "unrecognized mod screens remain visible on the game")
phase("menu")
raw.tutorial = true; display.updateAutoBattleScreen(); shown(false, "tutorial is not interrupted")
raw.tutorial = nil; raw.kind = "link"; display.updateAutoBattleScreen()
shown(false, "unsupported linked battle is not taken over")
raw.kind = nil
set("battle_view", "info"); shown(false, "information-only Gear is not a menu replacement")
set("battle_view", "standard"); shown(true, "interactive view re-enables automatic selection")
-- Disabling or leaving a battle restores exactly the pre-battle choice.
set("auto_battle_screen", false); shown(false, "disabling restores game-first layout")
set("fullscreen_start", "gear"); set("auto_battle_screen", true)
phase("messages"); shown(false, "game-first action phase even with Gear-first preference")
stack.states = { world }; display.updateAutoBattleScreen(); shown(true, "battle end restores Gear-first preference")
T.eq(options.fullscreen_start, "gear", "automatic switching never rewrites settings")
set("display_mode", "combined"); phase("menu")
T.eq(display.autoBattle.shown, true, "combined layout gives selections to Gear")
set("display_mode", "separate"); phase("menu")
T.eq(display.autoBattle.shown, nil, "dual-screen layout is untouched")
set("display_mode", "fullscreen"); set("fullscreen_start", "game")
display.swapped = true
stack.states = { world }; display.updateAutoBattleScreen()
shown(true, "pre-battle manual selection is Gear")
phase("messages"); shown(false, "automatic action playback temporarily shows game")
stack.states = { world }; display.updateAutoBattleScreen()
shown(true, "battle end restores the pre-battle manual selection")
T.eq(display.swapped, true, "manual preference is never rewritten")
-- A finger held on Gear cannot commit on a later decision after auto-switching.
display.swapped = nil
phase("menu"); now = now + 1; sync()
touch("down,40,60")
step(function() raw.phase = "messages"; battle.prompt = "advance" end)
step(function() raw.phase = "menu"; battle.prompt = "menu" end)
now = now + 1
local count = #keys + #intents
touch("up,40,60")
T.eq(#keys + #intents, count, "held touch cannot cross an automatic screen switch")
-- Every combined arrangement retains its exact geometry and saved preferences.
local hideUpper = upvalue(input, "hideUpperBattleUI")
local fullBottom = upvalue(drawBattle, "fullBottomBattleUI")
set("display_mode", "combined"); set("screen_swap", true)
local function layout()
  hook("render.viewport")(function() return nil end, { width = 960, height = 540 })
  return theme.nativeWindowLayout
end
local function sameRect(a, b, label)
  for _, key in ipairs({ "x", "y", "w", "h" }) do T.eq(a[key], b[key], label .. " " .. key) end
end
for _, arrangement in ipairs({ "side", "stacked", "auto", "overlay" }) do
  for _, primary in ipairs({ "game", "gear" }) do
    for _, view in ipairs({ "standard", "gear", "full" }) do
      set("combined_layout", arrangement); set("combined_primary", primary)
      set("battle_view", view); set("secondary_size", 31)
      set("overlay_corner", "bottom_left"); set("bottom_safe_area", 7)
      display.swapped = true
      for _, hidden in ipairs({ false, true }) do
        display.overlayHidden = hidden
        stack.states = { world }; display.updateAutoBattleScreen()
        local baseline = layout()
        phase("menu")
        local selection = layout()
        T.eq(display.gearPrimary(), true, arrangement .. " selection puts Gear in primary slot")
        local expected = theme:windowLayout(arrangement, 960, 540, true,
          "bottom_left", hidden, 31, 7)
        sameRect(selection.gear, expected.gear, "Gear uses primary rectangle")
        T.eq(selection.showGear, true, "selection remains visible with hidden overlay")
        phase("messages")
        local playback = layout()
        expected = theme:windowLayout(arrangement, 960, 540, false,
          "bottom_left", hidden, 31, 7)
        sameRect(playback.game, expected.game, "game uses primary rectangle")
        T.eq(playback.showGame, true, "game playback is visible")
        T.eq(hideUpper(), false, "primary game keeps its native menus and text")
        T.eq(fullBottom(), false, "primary game keeps its battle visuals")
        phase("animation"); T.eq(display.gearPrimary(), false, "animations remain on primary game")
        stack.states = { world }; display.updateAutoBattleScreen()
        local restored = layout()
        sameRect(restored.game, baseline.game, "original game rectangle restored")
        sameRect(restored.gear, baseline.gear, "original Gear rectangle restored")
        T.eq(restored.showGame, baseline.showGame, "original game visibility restored")
        T.eq(restored.showGear, baseline.showGear, "original Gear visibility restored")
        T.eq(display.swapped, true, "manual swap preference unchanged")
        T.eq(display.overlayHidden, hidden, "overlay visibility preference unchanged")
        T.eq(options.secondary_size, 31, "secondary size unchanged")
        T.eq(options.overlay_corner, "bottom_left", "overlay corner unchanged")
      end
    end
  end
end
-- Manual swap still overrides the active selection in combined mode.
set("combined_layout", "overlay"); set("battle_view", "standard")
phase("menu")
local keyboard = love.keyboard.isDown
local down = true
love.keyboard.isDown = function(key) return key == "f6" and down end
step(); down = false; step()
T.eq(display.gearPrimary(), false, "manual combined swap takes precedence")
phase("moves"); T.eq(display.gearPrimary(), false, "manual override survives submenu navigation")
phase("messages"); phase("menu")
T.eq(display.gearPrimary(), true, "next turn resumes automatic combined swapping")
love.keyboard.isDown = keyboard
set("auto_battle_screen", false)
T.eq(display.autoBattle.shown, nil, "disabling restores ordinary combined behavior")
T.finish()
