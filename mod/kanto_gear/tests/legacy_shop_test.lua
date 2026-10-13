-- Real native mart loops. Shared touch pages may move cursors, never money or items.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
love.graphics.arc = love.graphics.arc or function() end
local generation = assert(tonumber(arg[1]))
local run = T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")), {
  generation = generation, data = T.fixtures.load() })
assert(run.mod, run.error or run.reason)
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local input
for _, entry in ipairs(run.loader.hooks.chains["input.step"]) do
  if entry.owner == "kanto_gear" then input = entry.callback end
end
local display = up(input, "displayRuntime")
local world = { map = { id = "PALLET_TOWN", def = {} } }
local stack = { states = { world } }
function stack:top() return self.states[#self.states] end
function stack:push(state) self.states[#self.states + 1] = state end
function stack:pop() return table.remove(self.states) end
local pressed, queued = {}, {}
local save = { generation = generation, player = { name = "RED", money = 3000 }, money = 3000,
  party = {}, boxes = {}, inventory = {}, pokedex = { seen = {}, caught = {} }, options = { textSpeed = "FAST" } }
local game = { data = run.data, save = save, world = world, overworld = world, stack = stack,
  input = { wasPressed = function(_, key) return pressed[key] end, isDown = function() return false end } }
run.data.items.POTION = { name = "POTION", price = 301, pocket = "ITEM", canToss = true }
run.data.items.OLD_ROD = { name = "OLD ROD", price = 0, pocket = "KEY_ITEM", keyItem = true, canToss = false }
local stock = { "POTION" }
for i = 2, 10 do
  local id = "SHOP_FIX_" .. i
  run.data.items[id] = { name = "ITEM " .. i, price = i * 100, pocket = "ITEM", canToss = true }
  stock[i] = id
end
run.loader.events:emit("game.ready", { game = game })
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", ui_motion = false }
run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
local theme = up(display.drawContents, "THEME")
up(display.saveHome, "mod").input.tap = function(_, target, key)
  T.eq(target, game, "mart touch targets the original game")
  queued[#queued + 1] = key
end
local function step(key)
  pressed = { [key or "none"] = true }; stack:top():update(1 / 60); pressed = {}
end
local function untilReady(predicate, key)
  for _ = 1, 1200 do if predicate() then return end; step(key) end
  error("native mart did not reach its expected state")
end
local function view()
  local page = assert(display.startMenu(), "native mart has a shared projection")
  T.eq(page.screenId, "CompanionMenu", "legacy mart uses the common companion page")
  local ok, err = pcall(display.drawContents)
  T.check(ok, "shared mart renders: " .. tostring(err))
  T.eq(display.nativeHandoff, false, "mart controls stay available below")
  return page
end
local function tap(x, y)
  local before = #queued
  display.tapStartMenu(view(), x / 1.5, y / 1.5)
  T.eq(#queued, before + 1, "one mart touch queues exactly one key")
  step(queued[#queued])
end
local function choose(index)
  local page = view()
  T.check(display.StartMenu.select(page, index), "shared list selects the exact native row")
  local model = display.startMenuModel(page)
  local rect = assert(model.entries[index - model.first + 1])
  tap(rect.x + rect.w / 2, rect.y + rect.h / 2)
  return page
end
local shop
local function cash() return generation == 1 and save.money or save.player.money end
local function open(kind)
  stack.states = { world }
  save.money, save.player.money, save.inventory, save.bagOrder = 3000, 3000, { POTION = 4, OLD_ROD = 1 }, { "POTION", "OLD_ROD" }
  shop = require("src.ui.Screens").push(game, generation == 1 and "ShopMenu" or "Gen2MartMenu",
    generation == 1 and stock or { marts = { lists = { stock }, bargain = { { item = "POTION", price = 73 } } },
      martType = kind, onClose = function() stack:pop() end })
  if generation == 1 then shop:enter() end
  untilReady(function() return stack:top() == shop and not shop.message end, "a")
end
local function stockReady()
  untilReady(function()
    local page = display.startMenu()
    return page and page.title == "BUY" and not page.notice and not page.quantity and not page.choiceState
  end, "a")
end
local function confirmation()
  if generation == 1 then
    untilReady(function() return getmetatable(stack:top()) == require("src.ui.ChoiceBox") end)
    for _ = 1, 20 do step() end
  else
    for _ = 1, 1200 do
      if shop:yesNoVisible() then break end
      local c = assert(shop.confirm, "native confirmation remains pending")
      step(not require("src.ui.gen2.Typer").typing(shop) and c.page < #c.pages and "a" or nil)
    end
    local page = view()
    T.check(page.choiceState ~= nil, "Gen 2 mart uses the common YES/NO layout")
    T.same(page.prompt, shop.confirm.pages[shop.confirm.page], "confirmation retains the actual native page")
  end
end
local function receiptReady()
  untilReady(function()
    local page = display.startMenu()
    return page and not page.notice and not page.quantity and not page.choiceState
  end, "a")
end
for _, dark in ipairs({ false, true }) do
  theme.hgss:setVariant(dark)
  open()
  local root = view()
  T.eq(#root.items, 3, "standard mart retains BUY/SELL/QUIT")
  choose(1); stockReady()
  T.check(not root.valid(), "root touches expire when native stock takes over")
  local list = view()
  T.eq(#list.items, 11, "all native stock rows plus one cancel are present")
  T.eq(list.items[1].right, "¥301", "stock displays native unit price")
  local count = #queued
  display.tapStartMenu(list, 200 / 1.5, 200 / 1.5)
  T.eq(#queued, count, "paging stock never queues an activation")
  T.eq(display.StartMenu.window(view()), 6, "common stock pages have five rows")
  T.eq(stack:top().index, 6, "paging synchronizes the native absolute cursor")
  choose(9)
  local quantity = view()
  T.eq(quantity.quantity.label, "ITEM 9", "paged purchase retains its original item")
  T.eq(quantity.title, "BUY", "purchase title is shared across generations")
  T.eq(quantity.quantity.total, 900, "quantity exposes the actual running total")
  T.check(not list.valid(), "stock touches expire during quantity selection")
  tap(200, 170)
  T.eq(save.inventory.SHOP_FIX_9, nil, "quantity cancel never purchases")
  T.eq(cash(), 3000, "quantity cancel never charges")
  choose(1)
  quantity = view()
  T.eq(quantity.quantity.max, 99, "legacy purchase retains its native 99 ceiling")
  tap(190, 115)
  T.eq(view().quantity.qty, 2, "plus uses the native quantity handler")
  T.eq(view().quantity.total, 602, "running price updates with quantity")
  tap(60, 170); confirmation()
  T.eq(cash(), 3000, "quantity alone never spends money")
  if generation == 2 then
    local confirm = view()
    T.check(display.StartMenu.select(confirm, 2), "NO selects the native confirmation cursor")
  end
  step("b"); stockReady()
  T.eq(save.inventory.POTION, 4, "declining purchase preserves inventory")
  choose(1); tap(190, 115); tap(60, 170); confirmation(); step("a")
  untilReady(function() return save.inventory.POTION == 6 end)
  T.eq(cash(), 2398, "native purchase charges exactly two unit prices")
  receiptReady(); step("b")
  untilReady(function() return stack:top() == shop and not shop.message end, "a")
  choose(2)
  untilReady(function()
    local page = display.startMenu(); return page and page.title == "SELL" and not page.notice
  end, "a")
  list = view()
  T.eq(list.items[1].right, "x6", "sell list shows actual bag stack")
  choose(1)
  T.eq(view().quantity.max, 6, "sale cannot exceed the selected native stack")
  T.eq(view().title, "SELL", "sale title is shared across generations")
  tap(190, 115)
  T.eq(view().quantity.total, generation == 1 and 300 or 301,
    "sale rounding matches each edition, including odd unit prices")
  tap(60, 170); confirmation(); step("a")
  untilReady(function() return save.inventory.POTION == 4 end)
  T.eq(cash(), generation == 1 and 2698 or 2699, "native sale credits the exact edition-specific amount")
  receiptReady()
  T.check(not list.valid(), "native sale expires the old inventory projection")
end
if generation == 2 then
  open("BARGAIN"); stockReady()
  choose(1)
  T.eq(shop.qty, 1, "bargain shop skips quantity and buys one")
  confirmation(); step("a"); receiptReady()
  local page = view()
  T.eq(cash(), 2927, "bargain uses its special shelf price, not item price")
  T.eq(page.items[1].right, "SOLD OUT", "sold stock explains why it is inactive")
  T.eq(display.StartMenu.select(page, 1), false, "sold-out stock cannot animate or queue a dead purchase")
  T.eq(display.StartMenu.hit(page, 100, 45), nil, "sold-out stock is inert for touch")
  step("b")
  T.check(not page.valid(), "leaving bargain stock expires late touches")
  open("BITTER"); stockReady()
  T.eq(view().items[1].label, "POTION", "special shop intro reaches common stock without inventing a root menu")
  choose(1); tap(200, 170)
  T.eq(view().title, "BUY", "special-shop quantity cancellation returns to its stock")
  open(); choose(2)
  local old = view(); step("right")
  T.check(not old.valid(), "native sale pocket switch expires prior rows")
  T.check(view().nativePocket ~= old.nativePocket, "sale keeps real pocket navigation")
  step("right")
  T.eq(view().items[1].label, "OLD ROD", "key-item pocket retains native item identity")
  choose(1)
  T.check(view().notice ~= nil, "unsellable item uses native refusal")
  T.eq(save.inventory.OLD_ROD, 1, "refusal preserves the key item")
end
if _G.KANTO_GEAR_RENDER_CAPTURE then _G.KANTO_GEAR_RENDER_CAPTURE(run, display, game) end
T.finish("Kanto Gear shared native legacy marts")
