-- Run from the host SDK checkout, with argument 1 or 2. No ROM/device needed.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local generation = assert(tonumber(arg[1]), "choose generation 1 or 2")
local run = T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")), {
  generation = generation, data = T.fixtures.load(),
})
assert(run.mod, run.error or run.reason or "mod load failed")
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
local stack = { states = { world } }
function stack:top() return self.states[#self.states] end
function stack:push(state) self.states[#self.states + 1] = state end
function stack:pop() return table.remove(self.states) end
local pressed, keys = {}, {}
local game = { data = run.data, world = world, overworld = world, stack = stack,
  input = { wasPressed = function(_, key) return pressed[key] end },
  save = { generation = generation, player = { name = "RED" }, party = {},
    inventory = {}, pokedex = { seen = {}, caught = {} }, boxes = {}, options = {} } }
run.loader.events:emit("game.ready", { game = game })
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", ui_motion = true }
run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
love.graphics.arc = love.graphics.arc or function() end
love.graphics.polygon = love.graphics.polygon or function() end
love.graphics.transformPoint = love.graphics.transformPoint or function(x, y) return x, y end
local now = 10
love.timer.getTime = function() return now end
api.input.tap = function(_, target, key)
  T.eq(target, game, "native game receives input")
  keys[#keys + 1] = key
end
local function sync() display.syncTouchGuard() end
local touch = upvalue(hook("render.compose"), "touchEvent")
local function hit(x, y) touch(("tap,%d,%d"):format(x, y), 240, 216) end
local function step(key)
  input(function()
    pressed = { [key or keys[#keys] or "none"] = true }
    stack:top():update(1/60)
    pressed = {}
  end, game, 1/60)
end
sync() -- establish the initial overworld before opening Gen 1 menus
local chosen, count = nil, 0
local rows = {}
for i = 1, 12 do
  rows[i] = { label = "MOD ROW " .. i, keepOpen = true,
    onSelect = function() chosen = i; count = count + 1 end }
end
local native
if generation == 1 then
  native = require("src.ui.Menu").new(game, rows, { startCloses = true, noSound = true, maxVisible = 8 })
  native.screenId = "StartMenu"
else
  native = require("src.ui.gen2.StartMenu").new(game,
    { unlocked = { pack = true }, onClose = function() stack:pop() end })
  native.screenId = "Gen2StartMenu"
  native.items, native.list.items = rows, rows
end
stack:push(native); sync(); now = now + .4
T.eq(display.startMenu(), native, "only the active native start menu is mirrored")
local cursor = display.StartMenu.cursor(native)
cursor.index = 9
local model = display.startMenuModel(native)
T.eq(model.first, 6, "visible window follows native focus")
T.eq(model.entries[4].selected, true, "same highlighted row as the top screen")
T.eq(model.entries[4].label, rows[9].label, "mod label retained")
display.drawContents()
T.eq(display.backgroundDim, 0, "start menu is not covered by the locked-screen dim")
display.prepareMotion()
T.eq(display.motion.started, nil, "native menu does not slide the previous app")
cursor.index = 1; sync(); now = now + .4
hit(100, 75)
T.eq(keys[#keys], "a", "row tap queues native A")
T.eq(cursor.index, 2, "tap sets native focus before A")
T.eq(count, 0, "callbacks wait for native update")
hit(100, 75)
T.eq(#keys, 1, "duplicate synthetic tap is blocked")
step()
T.eq(chosen, 2, "native callback activates the touched row")
T.eq(count, 1, "one gesture activates once")
now = now + .4; hit(100, 75); step()
T.eq(count, 2, "keepOpen entries can be selected again")
now = now + .4; hit(200, 200)
T.eq(cursor.index, 6, "touch paging moves the actual native cursor")
T.eq(count, 2, "paging never activates a row")
T.eq(display.startMenuModel(native).first, 6, "top and bottom remain synchronized")
-- A native page change during a held gesture must not retarget its release.
now = now + .4; touch("down,100,75", 240, 216)
cursor.index = 11; sync(); now = now + .4
touch("up,100,75", 240, 216)
T.eq(count, 2, "held gesture cannot select the replacement page")
local before = #keys
now = now + .4; hit(100, 180)
T.eq(#keys, before, "empty last-page rows are not actionable")
-- The same object can become a confirmation; the menu must disappear.
if generation == 2 then
  native.phase, native.confirmChoice = "confirmContest", 1
  sync()
  T.eq(display.startMenu(), nil, "contest confirmation replaces the list")
  local choice = upvalue(display.drawContents, "dialogueChoice")
  local top, labels, field = choice()
  T.eq(top, native, "contest confirmation is touch enabled")
  T.eq(field, "confirmChoice", "confirmation uses its own cursor")
  T.eq(#labels, 2, "confirmation has two choices")
  native.phase = nil; sync()
end
now = now + .4; hit(10, 12)
T.eq(keys[#keys], "b", "header closes through native B")
step()
T.eq(stack:top(), world, "native menu returns to the world")
T.eq(display.startMenu(), nil, "mirror vanishes on close")
-- Both directions and wrap use the native menu's navigation, not a second focus.
stack:push(native)
for _, key in ipairs({ "up", "down", "down", "up" }) do
  local previous = cursor.index
  step(key)
  local wanted = ((previous - 1 + (key == "down" and 1 or -1)) % #rows) + 1
  T.eq(cursor.index, wanted, "native D-pad " .. key .. " keeps its ordering")
  local mirrored = display.startMenuModel(native)
  T.eq(mirrored.entries[wanted - mirrored.first + 1].selected, true,
    "mirrored focus follows actual native update")
end
display.StartMenu.select(native, #rows)
T.check(cursor.index > cursor.scroll and cursor.index <= cursor.scroll +
  (generation == 2 and cursor.rows or cursor.maxVisible), "touch focus is visible on TOP too")
if generation == 2 then
  local old = #keys
  native.items[12].disabled = true
  now = now + .4; sync(); now = now + .4; hit(100, 75); step()
  T.eq(count, 2, "native disabled mod entry does not activate")
  native.items[12].disabled = nil
end
-- Closing a native menu never rewrites the companion's saved page or subpage.
upvalue(display.updateMapRefresh, "page", "BAG", true)
display.bag.page = 3
now = now + .4; hit(10, 12); step()
T.eq(upvalue(display.updateMapRefresh, "page"), "BAG", "previous Gear app survives")
T.eq(display.bag.page, 3, "previous Gear subpage survives")
-- Inspect the actual built-in menu constructors and their unlock/contest gates.
if generation == 1 then
  local Start = require("src.ui.StartMenu")
  game.save.flags = {}
  local early = Start.new(game); early.screenId = "StartMenu"
  local before = #early.items
  game.save.flags.EVENT_GOT_POKEDEX = true
  local full = Start.new(game); full.screenId = "StartMenu"
  T.eq(#full.items, before + 1, "Gen 1 native Pokedex unlock is preserved")
  T.eq(display.StartMenu.model(full).total, #full.items, "all actual Gen 1 rows mirrored")
  game.save.safari = { steps = 420, balls = 22 }
  world.inSafariStepZone = function() return true end
  local safari = Start.new(game); safari.screenId = "StartMenu"
  T.eq(display.StartMenu.model(safari).total, #safari.items, "Safari menu uses its live rows")
else
  local Start = require("src.ui.gen2.StartMenu")
  local early = Start.new(game, { unlocked = { pack = true } })
  early.screenId = "Gen2StartMenu"
  local full = Start.new(game, { unlocked = { pack = true, party = true,
    pokedex = true, pokegear = true, mods = true } })
  full.screenId = "Gen2StartMenu"
  T.eq(#full.items, #early.items + 4, "Gen 2 native unlocks are preserved")
  game.save.bugContest = { active = true }
  local contest = Start.new(game); contest.screenId = "Gen2StartMenu"
  local quitIndex
  for index, item in ipairs(contest.items) do
    T.check(item.value ~= "pack" and item.value ~= "save" and item.value ~= "quit",
      "contest restrictions are preserved")
    if item.value == "quitContest" then quitIndex = index end
  end
  T.check(quitIndex ~= nil, "native contest Quit replaces Save")
  display.StartMenu.select(contest, quitIndex)
  pressed = { a = true }; contest:update(1/60); pressed = {}
  T.eq(contest.phase, "confirmContest", "native contest action opens confirmation")
  T.eq(display.StartMenu.model(contest), nil, "no list during native confirmation")
end
T.finish()
