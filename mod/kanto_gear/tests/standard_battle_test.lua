-- Run from the host SDK checkout, with argument 1 or 2. No ROM/device needed.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local generation = assert(tonumber(arg[1]), "choose generation 1 or 2")
local run = T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")), {
  generation = generation, data = T.fixtures.load(),
})
T.eq(run.mod.state, "loaded", "complete mod loads within LuaJIT's upvalue limit")
local upvalue = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local function hook(name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local input = hook("input.step")
local display, runtime = upvalue(input, "displayRuntime"), upvalue(input, "hgssRuntime")
local theme = upvalue(display.drawContents, "THEME")
local H = theme.hgss
local drawBattle = display.drawContents
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
local options = { theme_v3 = "hgss", battle_view = "standard", info_level = "spoiler", ui_motion = false }
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

-- Battle Art owns live battler images separately from pokemon.sprite's normal
-- summary path. Its public stage contract gates reuse of those images so a
-- disabled provider and Gen 2 retain Kanto Gear's regular front portraits.
local liveArt = { getDimensions = function() return 64, 64 end }
raw.player = { mon = party[1], sprite = liveArt }
raw.enemy = { mon = party[2], sprite = liveArt }
run.loader.mods.BATTLE_ART_VOXEL_FORK = {
  enabled = true, manifest = { version = "1.10.2" },
}
run.loader.exports.BATTLE_ART_VOXEL_FORK = { battleStage = {
  state = function(expected)
    if expected ~= raw then return nil end
    return { staged = true, ownership = { battlers = true } }
  end,
} }
local staged = { player = {}, enemy = {} }
attachBattleArtSprites(raw, staged)
if generation == 1 then
  T.eq(staged.player.presentationSprite, liveArt,
    "Battle Art's staged player image reaches the companion battle portrait")
  T.eq(staged.enemy.presentationSprite, liveArt,
    "Battle Art's staged enemy image reaches the companion battle portrait")
  local nativeDraw, drewLiveArt = love.graphics.draw, false
  love.graphics.draw = function(image, ...)
    if image == liveArt then drewLiveArt = true end
    return nativeDraw(image, ...)
  end
  runtime.battlePortrait({ species = "FIXMON_A", source = staged.player },
    10, 10, 64, false)
  love.graphics.draw = nativeDraw
  T.check(drewLiveArt,
    "the companion portrait draws Battle Art's live image instead of ROM art")
else
  T.eq(staged.player.presentationSprite, nil,
    "Gen 2 ignores the Gen 1-only Battle Art provider")
end

-- Companion keeps status/text upstairs and native D-pad ownership.
upvalue(input, "companion", { detected = function() return true end }, true)
upvalue(input, "displayReady", true, true)
local rendered = {}
for _, method in ipairs({ "battleRoot", "battleFullRoot", "battleMoves", "battleFullMoves",
    "battleFullStatuses", "battleTeamStrip", "systemOverlay", "v4AdvanceArrow",
    "battleBag", "battleSafari", "battleFullSafari", "battleMimic", "pcList", "partyCard" }) do
  local original = assert(H[method], method)
  H[method] = function(self, ...)
    rendered[method] = rendered[method] or {}
    rendered[method][#rendered[method] + 1] = { ... }
    return original(self, ...)
  end
end
local function moveRect(mode, slot)
  if mode == "full" then
    local r = H.fullBattleActions[slot]
    return r.x, r.y, r.w, r.h
  end
  return 6 + (slot - 1) % 2 * 116, 33 + math.floor((slot - 1) / 2) * 85, 112, 80
end
for _, mode in ipairs({ "standard", "gear", "full" }) do
  options.battle_view, rendered = mode, {}
  battle.prompt = "menu"; snapshot(); drawBattle()
  local root = mode == "full" and "battleFullRoot" or "battleRoot"
  T.check(rendered[root] ~= nil, mode .. " draws its current command page")
  T.eq(rendered.battleFullStatuses ~= nil, mode == "full", "only Full Gear repeats the native HP HUD")
  if mode == "standard" then
    T.eq(#rendered.battleTeamStrip, 1, "Companion retains the You/VS/Foe team strip")
    T.eq(rendered[root][1][6], true, "Companion commands are enabled at the native menu")
    T.eq(rendered.systemOverlay, nil, "usable Companion commands are not dimmed")
  end
  local actions = mode == "full" and H.fullBattleActions or H.battleActions
  for slot, rect in ipairs(actions) do
    hit(rect.x + rect.w / 2, rect.y + rect.h / 2)
    T.eq(raw.menuIndex, slot, mode .. " rendered command targets the original native action")
    T.eq(keys[#keys], "a", "command confirmation goes through native input")
  end
  local before = #keys
  hit(120, mode == "full" and 164 or 156); hit(235, 200)
  T.eq(#keys, before, "command gaps and outside edges are inert")

  battle.prompt, rendered = "moves", {}
  snapshot(); drawBattle()
  local moves = mode == "full" and "battleFullMoves" or "battleMoves"
  T.check(rendered[moves] ~= nil, mode .. " draws the shared move cards")
  T.eq(rendered.battleFullStatuses ~= nil, mode == "full", "Companion move selection has no duplicate HP HUD")
  local mon = rendered[moves][1][1]
  T.eq(mon.moveIndex ~= nil, mode ~= "standard", "only owned move pages display controller focus")
  for slot = 1, 4 do
    local x, y, w, h = moveRect(mode, slot)
    hit(x + 20, y + h / 2)
    T.eq(intents[#intents].slot, slot, "card submits its exact native move slot")
    snapshot()
    hit(x + w - 12, y + 10)
    T.eq(upvalue(input, "moveInfo"), battle.moves[slot], "card details inspect the touched move")
    upvalue(input, "moveInfo", nil, true)
  end
  before = #intents
  local x, y, w, h = moveRect(mode, 1)
  hit(x - 1, y + 20); hit(x + w, y + 20); hit(x + 20, y + h)
  T.eq(#intents, before, "move card margins and gaps cannot issue an intent")
  local saved = battle.moves[4]
  battle.moves[4] = nil
  x, y = moveRect(mode, 4); hit(x + 20, y + 25)
  T.eq(#intents, before, "missing move slots are inert")
  battle.moves[4] = saved
  saved = battle.moves[3].pp; battle.moves[3].pp = 0
  x, y, w = moveRect(mode, 3); hit(x + 20, y + 25)
  T.eq(#intents, before, "empty-PP moves cannot be used")
  hit(x + w - 12, y + 10)
  T.eq(upvalue(input, "moveInfo"), battle.moves[3], "unusable moves retain readable details")
  upvalue(input, "moveInfo", nil, true); battle.moves[3].pp = saved
end
options.battle_view, battle.prompt, battle.kind, rendered = "standard", "menu", "wild", {}
snapshot(); drawBattle()
T.eq(rendered.battleTeamStrip[1][2].wild, true, "Companion wild battles retain the Wild strip")
battle.kind = "trainer"
options.ui_motion = true
runtime.beginAnimation("battle_moves")
T.check(runtime.animation ~= nil, "shared Gear geometry supports its move transition")
display.optionsChanged({ mod = "kanto_gear", key = "battle_view" })
T.eq(runtime.animation, nil, "switching battle mode clears the old transition")
options.ui_motion = false

options.battle_view, battle.prompt = "standard", "menu"
game.input.pressQueue = { "down", "right", "a", "b" }
runtime.remapBattleRootInput(game)
T.eq(table.concat(game.input.pressQueue, ","), "down,right,a,b", "Companion retains all native root input")
T.eq(run.loader.hooks:call("battle.move_grid_navigation", function() return false end, raw),
  false, "Companion retains native vertical move navigation")
options.battle_view = "gear"
local expectedGear = {
  {left=3,right=2,up=1,down=4}, {left=4,right=2,up=1,down=2},
  {left=3,right=4,up=1,down=3}, {left=3,right=2,up=1,down=4},
}
snapshot()
for slot, directions in ipairs(expectedGear) do
  for direction, target in pairs(directions) do
    raw.menuIndex, battle.menuIndex = slot, slot
    game.input.pressQueue = { direction }
    runtime.remapBattleRootInput(game)
    T.eq(raw.menuIndex, target, "Gear D-pad follows the visible hero geometry")
    T.eq(#game.input.pressQueue, 0, "owned directions are consumed exactly once")
  end
end
upvalue(input, "displayReady", false, true)
raw.menuIndex, game.input.pressQueue = 1, { "down" }
runtime.remapBattleRootInput(game)
T.eq(raw.menuIndex, 1, "unavailable Gear cannot move native focus")
T.eq(#game.input.pressQueue, 1, "unavailable Gear preserves native input")
upvalue(input, "displayReady", true, true)

local NativeParty = require(generation == 2 and "src.ui.gen2.PartyMenu" or "src.ui.PartyMenu")
local menu = setmetatable({ screenId = generation == 2 and "Gen2PartyMenu" or "PartyMenu",
  index = 1, party = party, game = game, battle = true }, { __index = NativeParty })
stack.states = { world, raw, menu }
for _, mode in ipairs({ "standard", "gear", "full" }) do
  options.battle_view = mode
  for slot = 1, 6 do
    menu.index, rendered = slot, {}
    drawBattle()
    local cards = assert(rendered.partyCard)
    T.eq(#cards, 6, "party page keeps all six fixed member cards")
    T.eq(cards[slot][1].maxHp, 50, "party cards retain native maximum HP")
    T.eq(cards[6][1].statusId, "SLP", "party cards retain sleep status")
    T.eq(cards[slot][4] == true, mode ~= "standard", "only owned party pages highlight the native cursor")
    local x, y = H:partyPosition(slot)
    hit(x + 40, y + 25)
    T.eq(menu.index, slot, "shared party card targets the same native member")
  end
  local before, index = #keys, menu.index
  hit(5, 5)
  T.eq(#keys, before + 1, "header Back sends exactly one native input")
  T.eq(keys[#keys], "b", "party cancellation uses native Back")
  T.eq(menu.index, index, "Back never invents a party member")
end
local entries = { { label = "SWITCH", id = "SWITCH" },
  { label = "STATS", id = "STATS" }, { label = "CANCEL", id = "CANCEL" } }
if generation == 2 then menu.submenu = { items = entries, index = 1 }
else menu.submenu, menu.subItems, menu.subIndex = true, entries, 1 end
for slot = 1, 3 do
  local actions, submenu = runtime.partySubmenuActions(menu)
  T.eq(#actions, 3, "every native context action including Cancel remains visible")
  local x, y, w, h = H:partyActionRow(slot, #actions)
  T.check(y + h <= 210, "native context actions fit the content area")
  hit(x + w / 2, y + h / 2)
  T.eq(submenu and submenu.index or menu.subIndex, slot, "context touch selects the original native action")
end
menu.submenu = nil

local bag = { screenId = generation == 2 and "Gen2PackMenu" or "BagMenu",
  index = 6, battle = true, pocketIndex = 1, rows = {}, items = {},
  pocket = function() return { id = "ITEM" } end }
for slot = 1, 5 do
  bag.rows[slot] = { id = "FIX_POTION", name = "POTION " .. slot, count = slot, showCount = true }
  bag.items[slot] = { value = "FIX_POTION", label = "POTION " .. slot, right = "x" .. slot }
end
bag.items[6] = { label = "CANCEL", cancel = true }
stack.states, rendered = { world, raw, bag }, {}
drawBattle()
local view = assert(rendered.battleBag)[1][1]
T.eq(view.index, 6, "Bag tracks the native cursor after scrolling")
T.eq(#view.items, 6, "Bag retains all items and native Cancel")
local first, visible = H:battleBagWindow(view)
T.check(first <= 6 and first + visible - 1 >= 6, "Bag keeps Cancel on screen")
for row = 1, visible do
  bag.index = 6
  hit(120, 66 + (H.battleBagOffsetY or 0) + (row - 1) * 33 + 10)
  T.eq(bag.index, first + row - 1, "Bag touch selects the visible native row")
end

local summary = { screenId = generation == 2 and "Gen2SummaryMenu" or "SummaryMenu",
  mon = party[1], page = 1, moveIndex = 1,
  expToNext = function() return 100 end, itemName = function() return "--" end,
  otName = function() return "RED" end, otId = function() return 7 end }
summary.mon.moves = { battle.moves[1], battle.moves[2] }
local nativeScreens = { raw, menu, bag, { isTextBox = true }, { screenId = "UnrecognizedModMenu" } }
for _, mode in ipairs({ "standard", "info", "gear", "full" }) do
  options.battle_view, battle.prompt = mode, "menu"
  snapshot(); stack.states = { world, raw, summary }
  local owns = mode == "gear" or mode == "full"
  local state = display.summaryContext(summary)
  state.page, state.moveIndex = 2, 1
  T.eq(run.loader.hooks:call("screen.render_visible", function() return true end, summary),
    not owns, mode .. " gives the native summary the correct visibility")
  T.eq(run.loader.hooks:call("screen.render_visible", function() return false end, summary),
    false, "another renderer's explicit suppression is respected")
  game.input.pressQueue = { "down" }
  display.remapBattleSummaryInput(game)
  T.eq(state.moveIndex, owns and 2 or 1, "only owned Gear summaries move their own cursor")
  T.eq(#game.input.pressQueue, owns and 0 or 1, "summary navigation has one input authority")
  T.eq(summary.moveIndex, 1, "Gear navigation does not mutate the hidden native move cursor")
  if not owns then
    for _, screen in ipairs(nativeScreens) do
      stack.states = { world, raw, screen }
      T.eq(run.loader.hooks:call("screen.render_visible", function() return true end, screen),
        true, "mirrored battle modes preserve native menus")
    end
  end
end
options.battle_view = "gear"
stack.states = { world, raw, summary }
upvalue(input, "displayReady", false, true)
T.eq(run.loader.hooks:call("screen.render_visible", function() return true end, summary),
  true, "unavailable Gear cannot hide the native summary")
upvalue(input, "displayReady", true, true)
stack.states = { world, summary }; upvalue(input, "battle", nil, true)
T.eq(run.loader.hooks:call("screen.render_visible", function() return true end, summary),
  true, "field summaries keep native rendering")

stack.states = { world, raw }
local statusCard, fullMessage, message = H.battleStatusCard, H.battleFullMessage, H.battleMessage
local cards, compact, large = 0, 0, 0
H.battleStatusCard = function(self, ...) cards = cards + 1; return statusCard(self, ...) end
H.battleFullMessage = function(self, lines, advance, ...)
  compact = compact + 1
  T.eq(advance, battle.prompt == "advance", "Continue follows the native prompt")
  return fullMessage(self, lines, advance, ...)
end
H.battleMessage = function(self, ...) large = large + 1; return message(self, ...) end
for _, dark in ipairs({ false, true }) do
  H:setVariant(dark)
  for _, prompt in ipairs({ "advance", "locked" }) do
    for _, draining in ipairs({ false, true }) do
      for _, mode in ipairs({ "standard", "gear", "full" }) do
        options.battle_view = mode
        battle.prompt, battle.message, raw.draining = prompt, { "TESTMON used a move!" }, draining
        snapshot(); cards, compact, large, rendered = 0, 0, 0, {}
        drawBattle()
        T.eq(cards, mode == "full" and 2 or 0, "only Full Gear repeats status cards during text")
        T.eq(compact, mode == "full" and 1 or 0, "only Full Gear repeats compact battle text")
        T.eq(large, mode == "gear" and 1 or 0, "Gear retains its full message page")
        if mode == "standard" then
          T.eq(rendered.battleRoot[1][6], false, "Companion commands stay visible and disabled during text")
          T.eq(#rendered.battleTeamStrip, 1, "Companion retains its team strip during text")
          T.eq(rendered.systemOverlay[1][1], 0.48, "Companion dims its controls during native battle text")
          T.eq(rendered.systemOverlay[1][2], prompt == "advance", "Companion offers Continue only when the native text can advance")
          T.eq(rendered.v4AdvanceArrow and #rendered.v4AdvanceArrow or 0, prompt == "advance" and 1 or 0,
            "Companion draws the small shared Continue arrow only while waiting")
          local rect = H.battleActions[1]
          H:setTouch((rect.x + 30) / 1.5, (rect.y + 30) / 1.5)
          local presses, beginPress = 0, H.beginPress
          H.beginPress = function(self, ...)
            local pressed = beginPress(self, ...)
            if pressed then presses = presses + 1 end
            return pressed
          end
          drawBattle()
          H.beginPress = beginPress; H:setTouch(nil, nil)
          T.eq(presses, 0, "locked Companion commands never animate on touch")
          if prompt == "locked" then
            local before = #keys
            hit(rect.x + 30, rect.y + 30)
            T.eq(#keys, before, "locked Companion commands send no native input")
          end
        end
      end
    end
  end
end
H.battleStatusCard, H.battleFullMessage, H.battleMessage = statusCard, fullMessage, message
local partyInfo = H.partyInfo
H.partyInfo = function(self, value, x, y, ...)
  T.check(y >= 117 and y + 8 < 210, "six-line battle text fits the action area")
  return partyInfo(self, value, x, y, ...)
end
for _, title in ipairs({ false, "NEW MOVE" }) do
  H:battleFullMessage({ "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX" }, true, title or nil, 0)
end
H.partyInfo = partyInfo
local rectangle, frozen, motion, ambient = love.graphics.rectangle, H.frozenTime, H.motionEnabled, H.ambientEnabled
local untilTime, last = H.ambientUntil, H.ambientLast
H.motionEnabled, H.ambientEnabled, H.ambientLast = true, true, nil
local function arrowFrame(now, prompt)
  local top
  H.frozenTime, H.ambientUntil = now, nil
  love.graphics.rectangle = function(mode, x, y, w, h, ...)
    if x >= 116 and x < 125 and w < 10 and h < 10 then top = math.min(top or y, y) end
    return rectangle(mode, x, y, w, h, ...)
  end
  H:systemOverlay(0.48, prompt, now)
  love.graphics.rectangle = rectangle
  return top
end
local first = arrowFrame(0, true)
T.check(first ~= nil, "waiting overlay draws visible arrow pixels")
T.eq(arrowFrame(0.4, true), first + 1, "shared Continue arrow animates between redraws")
T.check(H.ambientUntil >= 0.8 and H:ambientDue(0.65), "Continue requests repainting while the native text waits")
T.eq(arrowFrame(0.4, false), nil, "busy overlay has no misleading Continue arrow")
H.frozenTime, H.motionEnabled, H.ambientEnabled = frozen, motion, ambient
H.ambientUntil, H.ambientLast = untilTime, last
T.eq(#run.errors, 0, "complete companion battle paths report no runtime errors")
run.release()
T.finish("Companion battle contracts Gen " .. generation)
