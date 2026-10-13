-- Actual native PC update loops, driven by companion taps; no inventory
-- callbacks are executed by the fixture or the projection.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local generation = assert(tonumber(arg[1]))
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local run = T.sdk.loadMod(path, { generation = generation, data = T.fixtures.load() })
assert(run.mod, run.error or run.reason or "mod load failed")
T.eq(run.mod.state, "loaded", "mod loads")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local function hook(name)
  for _, entry in ipairs(run.loader.hooks.chains[name]) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local input = hook("input.step")
local display = up(input, "displayRuntime")
local world = { map = { id = "PALLET_TOWN", def = {} } }
local stack = { states = { world } }
function stack:top() return self.states[#self.states] end
function stack:push(state) self.states[#self.states + 1] = state end
function stack:pop() return table.remove(self.states) end
local pressed, queued = {}, {}
local save = { generation = generation, player = { name = "RED" }, party = {},
  inventory = { POTION = 4 }, pcItems = { POTION = 5 }, pcOrder = { "POTION" },
  boxes = {}, currentBox = 1, pokedex = { seen = {}, caught = {} }, options = { textSpeed = "FAST" } }
local game = { data = run.data, save = save, world = world, overworld = world, stack = stack,
  input = { wasPressed = function(_, key) return pressed[key] end, isDown = function() return false end } }
run.data.items.POTION = { name = "POTION", pocket = "ITEM", canToss = true }
run.loader.events:emit("game.ready", { game = game })
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss" }
run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
local theme = up(display.drawContents, "THEME")
local api = up(display.saveHome, "mod")
api.input.tap = function(_, target, key)
  T.eq(target, game, "tap targets the actual game")
  queued[#queued + 1] = key
end
local function step(key)
  pressed = { [key or "none"] = true }
  stack:top():update(1 / 60)
  pressed = {}
end
local function view()
  local page = assert(display.startMenu(), "native item PC has a common projection")
  T.eq(page.screenId, "CompanionMenu", "legacy PC uses the generic common page")
  T.check(pcall(display.drawContents), "common PC page renders")
  T.eq(display.nativeHandoff, false, "common PC page does not hand off input")
  return page
end
local function choose(index)
  local page = view()
  T.check(display.StartMenu.select(page, index), "shared list selects a native row")
  local model = display.startMenuModel(page)
  local entry = model.entries[index - model.first + 1]
  local before = #queued
  display.tapStartMenu(page, (entry.x + entry.w / 2) / 1.5, (entry.y + entry.h / 2) / 1.5)
  T.eq(#queued, before + 1, "one row tap queues exactly one key")
  T.eq(queued[#queued], "a", "activation waits for native A")
  step(queued[#queued])
  return page
end
local function acknowledge()
  for _ = 1, 600 do
    local top = stack:top()
    if not top.message and not top.pcCompletion and not top.repeatSfx then return end
    step("a")
  end
  error("native receipt did not finish")
end
local function open()
  stack.states = { world }
  require("src.ui.Screens").push(game, generation == 1 and "PlayerPC" or "Gen2ItemPcMenu",
    { onClose = function() stack:pop() end })
  return stack:top()
end
local pc = open()
local root = choose(1)
T.check(not root.valid(), "root touch expires when the native list opens")
local list = view()
T.eq(list.title, "WITHDRAW", "withdraw uses the common list title")
T.eq(list.items[1].label, "POTION", "native item name is retained")
T.eq(list.items[1].right, "x5", "native storage count is visible")
T.eq(#list.items, 2, "native cancel row is present once")
if generation == 2 then
  pc.repeatSfx = {}
  local waiting = view()
  T.eq(display.StartMenu.cursor(waiting), nil, "native audio wait has no touch cursor")
  T.check(display.StartMenu.model(waiting) ~= nil, "native audio wait retains the list preview")
  local before = #queued
  display.tapStartMenu(waiting, 100 / 1.5, 47 / 1.5)
  T.eq(#queued, before, "native audio wait does not queue a dead button")
  pc.repeatSfx = nil
end
choose(1)
T.eq(save.inventory.POTION, 4, "choosing an item does not transfer it")
T.check(not list.valid(), "quantity invalidates the old item row")
local quantity = assert(display.startMenu()).quantity
T.eq(quantity.max, 5, "quantity uses the native PC stack")
step("b")
T.eq(save.pcItems.POTION, 5, "quantity cancel preserves storage")
choose(1); step("up"); step("a")
T.eq(save.inventory.POTION, 6, "withdraw adds exactly two through native update")
T.eq(save.pcItems.POTION, 3, "withdraw removes exactly two from native storage")
local notice = view()
T.check(notice.notice ~= nil, "native receipt dims the companion instead of showing another item list")
acknowledge()
T.check(not notice.valid(), "receipt acknowledgement expires old touch")
choose(2)
T.eq(stack:top(), pc, "native CANCEL returns to the PC root")
choose(2)
list = view()
T.eq(list.title, generation == 1 and "DEPOSIT" or "ITEMS",
  "deposit uses its action title or actual native pocket")
if generation == 2 then
  local pocketPage = list
  step("right")
  T.check(not pocketPage.valid(), "native pocket switch rejects the old item page")
  T.eq(view().title, "POKé BALLS", "deposit shows the actual selected pocket")
  step("left")
end
choose(1)
quantity = assert(display.startMenu()).quantity
T.eq(quantity.label, "POTION", "deposit quantity describes the selected bag item")
T.eq(quantity.max, 6, "deposit quantity uses the bag count, not the storage count")
step("up"); step("a")
T.eq(save.inventory.POTION, 4, "deposit removes exactly two from the bag")
T.eq(save.pcItems.POTION, 5, "deposit adds exactly two to storage")
acknowledge(); step("b")
T.eq(stack:top(), pc, "native B exits the deposit child")
choose(3); list = choose(1)
T.eq(save.pcItems.POTION, 5, "toss quantity does not discard yet")
step("a")
T.eq(save.pcItems.POTION, 5, "toss waits for a YES/NO confirmation")
T.check(not list.valid(), "confirmation rejects the old storage row")
step("b")
if generation == 1 then for _ = 1, 16 do step() end end
T.eq(save.pcItems.POTION, 5, "NO preserves every stored item")
choose(1); step("up"); step("a"); step("a")
if generation == 1 then for _ = 1, 16 do step() end end
T.eq(save.pcItems.POTION, 3, "YES discards exactly the native chosen quantity")
acknowledge(); step("b")
-- A long ordered list crosses a common five-row page without activation.
save.pcItems, save.pcOrder = {}, {}
for i = 1, 12 do
  local id = ("PC_FIX_%02d"):format(i)
  run.data.items[id] = { name = "STORED " .. i, pocket = "ITEM", canToss = true }
  save.pcItems[id], save.pcOrder[i] = i, id
end
choose(1); list = view()
T.eq(list.items[6].label, "STORED 6", "native storage order survives projection")
local n = #queued
display.tapStartMenu(list, 200 / 1.5, 200 / 1.5)
T.eq(#queued, n, "pager does not queue A")
T.eq(display.StartMenu.window(list), 6, "common pager starts at row six")
local native = stack:top()
local cursor = generation == 1 and native.index or native.listIndex
T.eq(cursor, 6, "common pager sets the native cursor")
T.check(cursor > native.scroll and cursor <= native.scroll + (native.cursorRows or 4),
  "selected row remains visible on the native top screen")
T.check(display.pageChoice(1), "swipe uses common menu paging")
T.eq(display.StartMenu.window(list), 11, "swipe advances to the last page")
display.pageChoice(1)
T.eq(display.StartMenu.window(list), 11, "swipe cannot advance beyond the last page")
local before = #queued
display.tapStartMenu(list, 100 / 1.5, 174 / 1.5)
T.eq(#queued, before, "empty last-page rows have no action")
choose(12)
quantity = assert(display.startMenu()).quantity
T.eq(quantity.label, "STORED 12", "paged tap retains the exact native item")
T.eq(quantity.max, 12, "paged tap retains the exact native quantity")
step("b")
if generation == 2 then
  -- SELECT's second A means reorder, never withdraw.
  display.StartMenu.select(view(), 1); step("select")
  list = view(); choose(3)
  T.eq(native.switching, nil, "native second selection finishes reordering")
  T.eq(native.qtyState, nil, "reorder does not enter withdrawal")
  T.eq(save.pcOrder[3], "PC_FIX_01", "native storage order owns the move")
  T.check(not list.valid(), "reorder invalidates the held-row projection")
end
step("b")
save.pcItems, save.pcOrder = {}, {}
choose(1)
if generation == 2 then
  T.eq(#view().items, 1, "empty Gen 2 storage retains only native cancel")
  choose(1)
else
  T.check(stack:top().isTextBox, "empty Gen 1 storage retains its native refusal")
  stack:pop()
end
for _, dark in ipairs({ false, true }) do
  theme.hgss:setVariant(dark)
  view()
end
local closing = view()
step("b")
T.eq(stack:top(), world, "native PC exit returns to the overworld")
T.check(not closing.valid(), "closed PC rejects stale taps")
if _G.KANTO_GEAR_RENDER_CAPTURE then _G.KANTO_GEAR_RENDER_CAPTURE(run, display, game) end
T.finish("Kanto Gear shared legacy item PC")
