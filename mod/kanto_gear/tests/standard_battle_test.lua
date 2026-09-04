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

-- Rendering dispatch, not just disconnected layout helpers.
local rendered = {}
for _, method in ipairs({ "battleStandardRoot", "battleRoot", "battleFullRoot",
    "battleStandardMoves", "battleMoves", "battleStandardParty", "battleBag",
    "battleMimic", "battleSafari", "pcList" }) do
  local original = H[method]
  H[method] = function(self, ...)
    rendered[method] = { ... }
    return original(self, ...)
  end
end
for _, mode in ipairs({ "standard", "gear", "full" }) do
  options.battle_view = mode
  battle.prompt = "menu"
  snapshot()
  drawBattle()
  T.check(rendered[mode == "standard" and "battleStandardRoot"
    or mode == "gear" and "battleRoot" or "battleFullRoot"], mode .. " chooses its own root")
  battle.prompt = "moves"
  drawBattle()
  T.check(rendered[mode == "standard" and "battleStandardMoves" or "battleMoves"],
    mode .. " chooses its own move layout")
  runtime.beginAnimation("battle_moves")
  T.eq(runtime.animation ~= nil, mode ~= "standard", "only Gear uses the grid hero animation")
  runtime.animation = nil
end
options.battle_view = "standard"
runtime.animation = { kind = "battle_bag", started = 1 }
display.optionsChanged({ mod = "kanto_gear", key = "battle_view" })
T.eq(runtime.animation, nil, "switching layout clears an in-flight Gear transition")
battle.prompt = "menu"
for slot = 1, 4 do
  local x = 62 + (slot - 1) % 2 * 116
  local y = 76 + math.floor((slot - 1) / 2) * 91
  T.eq(H:safariHit(x, y), slot, "root geometry matches native 2x2 order")
  hit(x, y)
  T.eq(raw.menuIndex, slot, "root touch selects the native row/column")
  T.eq(keys[#keys], "a", "root confirms through native A")
end
local presses = #keys
hit(120, 70); hit(60, 121); hit(235, 100)
T.eq(#keys, presses, "root gaps and outside edges are not buttons")
game.input.pressQueue = { "down", "right", "a", "b" }
runtime.remapBattleRootInput(game)
T.eq(table.concat(game.input.pressQueue, ","), "down,right,a,b", "Standard never remaps native input")
T.eq(run.loader.hooks:call("battle.move_grid_navigation", function() return false end, raw),
  false, "Standard retains the native vertical move cursor")
T.eq(run.loader.hooks:call("ui.party.grid_navigation", function() return false end,
  { screenId = "PartyMenu", index = 1 }), false, "Standard retains native vertical party input")

battle.prompt = "moves"
for slot = 1, 4 do
  local x, y, w, h = H:battleStandardMoveRect(slot)
  T.eq(H:battleStandardMoveHit(x + w / 2, y + h / 2), slot, "move touch matches rendered row")
  T.eq(H:battleStandardMoveHit(x + w / 2, y + h), nil, "move gaps do nothing")
  hit(x + 70, y + 10)
  T.eq(intents[#intents].slot, slot, "row sends the exact native move slot")
  snapshot()
  hit(x + w - 12, y + 12)
  T.eq(upvalue(input, "moveInfo"), battle.moves[slot], "row chevron opens that move's details")
  T.eq(runtime.animation, nil, "details cannot start a grid-shaped transition in Standard")
  upvalue(input, "moveInfo", nil, true)
end
battle.moves[4] = nil
local count = #intents
hit(80, 180)
T.eq(#intents, count, "missing move slot cannot issue an intent")
battle.moves[3].pp = 0
hit(80, 130)
T.eq(#intents, count, "empty-PP move cannot be used")
hit(220, 130)
T.eq(upvalue(input, "moveInfo"), battle.moves[3], "empty-PP move still has readable details")
upvalue(input, "moveInfo", nil, true)

-- Actual native PartyMenu instances: cancel availability and submenu cursor.
local NativeParty = require(generation == 2 and "src.ui.gen2.PartyMenu" or "src.ui.PartyMenu")
local menu = setmetatable({ screenId = generation == 2 and "Gen2PartyMenu" or "PartyMenu",
  index = 1, party = party, game = game, battle = true }, { __index = NativeParty })
stack.states[3] = menu
T.eq(runtime.partyHasCancel(menu, #party), generation == 2, "only native selectable cancel gets a row")
for slot = 1, 6 do
  menu.index = slot
  drawBattle()
  local model = rendered.battleStandardParty
  T.eq(model[2], slot, "rendered focus follows the current native party cursor")
  T.eq(model[1][slot].maxHp, 50, "every party row keeps its real max HP")
  T.eq(model[1][6].statusId, "SLP", "sleep status is preserved in the list")
  local x, y, w, h = H:battleStandardPartyRect(slot, 6, generation == 2)
  T.check(y >= 33 and y + h <= 210, "all six rows fit the content area")
  T.eq(H:battleStandardPartyHit(x - 1, y + 5, 6, generation == 2), nil, "party left margin is inert")
  hit(x + w / 2, y + h / 2)
  T.eq(menu.index, slot, "party touch targets the same native slot")
end
if generation == 2 then
  local x, y, w, h = H:battleStandardPartyRect(7, 6, true)
  hit(x + w / 2, y + h / 2)
  T.eq(menu.index, 7, "native cancel is reachable below member six")
  T.check(menu:isCancel(), "cancel touch matches the real native cancel state")
  menu.switchFrom = 1
  T.eq(runtime.partyHasCancel(menu, 6), false, "native no-cancel mode adds no fake row")
  menu.switchFrom = nil
end
menu.index, menu.itemUse = 1, true
drawBattle()
T.eq(rendered.battleStandardParty[2], 1, "item target selection uses the same vertical renderer")
menu.itemUse = nil
local entries = { { label = "SWITCH", id = "SWITCH", action = "battle_switch" },
  { label = "STATS", id = "STATS", action = "stats" },
  { label = "CANCEL", id = "CANCEL", action = "cancel" } }
if generation == 2 then menu.submenu = { items = entries, index = 1 }
else menu.submenu, menu.subItems, menu.subIndex = true, entries, 1 end
for slot = 1, 3 do
  local actions, submenu = runtime.partySubmenuActions(menu)
  T.eq(#actions, 3, "Standard shows the complete native context menu")
  local x, y, w, h = H:partyActionRow(slot, #actions)
  T.check(y + h <= 210, "context actions stay inside the screen")
  hit(x + w / 2, y + h / 2)
  T.eq(submenu and submenu.index or menu.subIndex, slot, "context touch selects native action including cancel")
  drawBattle()
end
if generation == 2 then
  menu.submenu.index = 1
  menu:updateSubmenu({ wasPressed = function(_, key) return key == "up" end })
  T.eq(menu.submenu.index, 3, "native Up wraps onto visible CANCEL, not an invisible focus")
  drawBattle()
end
options.battle_view = "gear"
T.eq(#runtime.partySubmenuActions(menu), 2, "Gear keeps its existing two-action context menu")
options.battle_view = "standard"
stack.states[3] = nil
for _, prompt in ipairs({ "safari", "mimic" }) do
  battle.prompt = prompt
  battle.mimicMoves, battle.mimicIndex = { battle.moves[1], battle.moves[2] }, 2
  drawBattle()
  T.check(rendered[prompt == "safari" and "battleSafari" or "battleMimic"],
    prompt .. " retains its matching native layout")
end
stack.states[3] = { kind = "pp_item_move", index = 2,
  items = { { label = "FIRST", right = "1/10" }, { label = "SECOND", right = "2/15" } } }
drawBattle()
T.check(rendered.pcList, "PP item selection retains the shared vertical list")

local bag = { screenId = generation == 2 and "Gen2PackMenu" or "BagMenu",
  index = 6, battle = true, pocketIndex = 1, rows = {}, items = {},
  pocket = function() return { id = "ITEM" } end }
for slot = 1, 5 do
  bag.rows[slot] = { id = "FIX_POTION", name = "POTION " .. slot, count = slot, showCount = true }
  bag.items[slot] = { value = "FIX_POTION", label = "POTION " .. slot, right = "x" .. slot }
end
bag.items[6] = { label = "CANCEL", cancel = true }
stack.states[3] = bag
drawBattle()
local view = rendered.battleBag[1]
T.eq(view.index, 6, "Bag focus tracks the real native cursor after scrolling")
T.eq(#view.items, 6, "Bag keeps all items plus native cancel")
local first, visible = H:battleBagWindow(view)
T.check(first <= 6 and first + visible - 1 >= 6, "Bag scroll window keeps Cancel on screen")
local bottom = 66 + (H.battleBagOffsetY or 0)
for row = 1, visible do
  bag.index = 6
  hit(120, bottom + (row - 1) * 33 + 10)
  T.eq(bag.index, first + row - 1, "Bag touch selects the visible native item row")
end
if generation == 2 then
  local NativePack = require("src.ui.gen2.PackMenu")
  local native = setmetatable({ battle = true }, { __index = NativePack })
  T.eq(native:hasSubmenu(), false, "current Gen 2 battle Pack has no hidden USE submenu")
end
local drawChoice = upvalue(display.drawContents, "drawDialogueChoice")
local originalChoice = H.choiceScreen
local choiceView
H.choiceScreen = function(_, model) choiceView = model end
drawChoice({ index = 2 }, { "YES", "NO" }, "CHANGE POKEMON?", "index")
H.choiceScreen = originalChoice
T.eq(choiceView.entries[1].x, choiceView.entries[2].x, "battle Yes/No stays in one native column")
T.check(choiceView.entries[2].y > choiceView.entries[1].y, "NO sits below YES")
T.check(choiceView.entries[2].selected, "native NO focus appears on the lower button")

-- Shared geometry stays centered and fits for small teams as well as six.
for members = 1, 6 do
  for _, cancel in ipairs({ false, true }) do
    local _, top = H:battleStandardPartyRect(1, members, cancel)
    local _, bottomY, _, bottomH = H:battleStandardPartyRect(members + (cancel and 1 or 0), members, cancel)
    T.check(math.abs(top - 33 - (210 - bottomY - bottomH)) <= 1,
      "party content group has equal top/bottom breathing room")
  end
end
-- Standard mirrors native screens; only Gear/Full Gear may hide them.
local visibility = hook("screen.render_visible")
local oldDisplay = upvalue(visibility, "hasDisplay", function() return true end, true)
local oldReady = upvalue(visibility, "displayReady", true, true)
local oldActive = upvalue(visibility, "active", true, true)
local summary = { screenId = generation == 2 and "Gen2SummaryMenu" or "SummaryMenu",
  mon = party[1], page = 1, moveIndex = 1,
  expToNext = function() return 100 end, itemName = function() return "--" end,
  otName = function() return "RED" end, otId = function() return 7 end }
summary.mon.moves = { battle.moves[1], battle.moves[2] }
local nativeScreens = { raw, menu, bag,
  { kind = "pp_item_move", index = 1, items = { { label = "MOVE" } } },
  { isTextBox = true }, { screenId = "MoveLearnMenu" },
  { screenId = "Gen2ScriptMenu" }, { screenId = "UnrecognizedModMenu" } }
for _, mode in ipairs({ "standard", "info", "gear", "full" }) do
  options.battle_view = mode
  local mirrored = mode == "standard" or mode == "info"
  stack.states = { world, raw, summary }
  for page = 1, generation == 2 and 3 or 2 do
    summary.page = page
    T.eq(run.loader.hooks:call("screen.render_visible", function() return true end, summary),
      mirrored, mode .. " has correct native summary visibility on page " .. page)
    T.eq(run.loader.hooks:call("screen.render_visible", function() return false end, summary),
      false, "another renderer's explicit suppression is respected")
  end
  summary.page, summary.moveIndex = 2, 1
  game.input.pressQueue = { "down" }
  runtime.remapSummaryMovesInput(game)
  T.eq(#game.input.pressQueue, mirrored and 1 or 0,
    mode .. " only intercepts summary navigation when it owns the screen")
  T.eq(runtime.summaryView(summary).moveIndex ~= nil, not mirrored,
    mode .. " shows move focus only when D-pad actually controls it")
  if mirrored then
    game.input.pressQueue = { "a", "b", "up", "down", "left", "right" }
    runtime.remapSummaryMovesInput(game)
    T.eq(table.concat(game.input.pressQueue, ","), "a,b,up,down,left,right",
      "mirrored summaries retain the original page/close/Pokemon controls")
    for _, screen in ipairs(nativeScreens) do
      stack.states = { world, raw, screen }
      T.eq(run.loader.hooks:call("screen.render_visible", function() return true end, screen),
        true, mode .. " never hides a native battle submenu")
      T.eq(run.loader.hooks:call("battle.bottom_ui_visible", function() return true end, screen),
        true, mode .. " preserves native battle commands and dialogue")
    end
    T.eq(run.loader.hooks:call("battle.status_hud_visible", function() return true end, raw),
      true, mode .. " preserves the native battle status HUD")
  end
end
options.battle_view = "gear"
stack.states = { world, summary }
T.eq(run.loader.hooks:call("screen.render_visible", function() return true end, summary),
  true, "field summaries still render above")
stack.states = { world, raw, summary }
upvalue(visibility, "displayReady", false, true)
T.eq(run.loader.hooks:call("screen.render_visible", function() return true end, summary),
  true, "Gear cannot hide a summary when the companion display is unavailable")
upvalue(visibility, "hasDisplay", oldDisplay, true)
upvalue(visibility, "displayReady", oldReady, true)
upvalue(visibility, "active", oldActive, true)
T.eq(#run.errors, 0, "no runtime errors during the battle screen audit")
T.finish("Standard battle layouts Gen " .. generation)
