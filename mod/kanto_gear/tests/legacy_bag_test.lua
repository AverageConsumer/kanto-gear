-- Real native field-bag loops. Shared touch pages may move cursors, never money or items.
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
local world = { map = { id = "PALLET_TOWN", def = {} }, useFieldItem = function() return "nowhere" end,
  registerItem = function() return true end }
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
  T.eq(target, game, "bag touch targets the original game")
  queued[#queued + 1] = key
end
local function step(key)
  pressed = { [key or "none"] = true }; stack:top():update(1 / 60); pressed = {}
end
local function untilReady(predicate, key)
  for _ = 1, 1200 do if predicate() then return end; step(key) end
  error("native bag did not reach its expected state")
end
local function view()
  local page = assert(display.startMenu(), "native bag has a shared projection")
  T.eq(page.screenId, "CompanionMenu", "legacy bag uses the common companion page")
  local ok, err = pcall(display.drawContents)
  T.check(ok, "shared bag renders: " .. tostring(err))
  T.eq(display.nativeHandoff, false, "mart controls stay available below")
  return page
end
local function tap(x, y)
  local before = #queued
  display.tapStartMenu(view(), x / 1.5, y / 1.5)
  T.eq(#queued, before + 1, "one bag touch queues exactly one key")
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
local function open()
  stack.states={world}
  save.inventory,save.bagOrder,save.bagStacks={POTION=4,OLD_ROD=1},{"POTION","OLD_ROD"},nil
  for i=2,10 do save.inventory[stock[i]]=i;save.bagOrder[#save.bagOrder+1]=stock[i] end
  save.inventory.FIX_BALL=2
  run.data.items.FIX_BALL.pocket="BALL"
  save.bagOrder[#save.bagOrder+1]="FIX_BALL"
  game.bagSavedMenuItem,game.bagListScrollOffset=2,0
  game.gen2PackCursor=nil
  display.recentItem.id,display.recentItem.pending=nil,nil
  return require("src.ui.Screens").push(game,generation==1 and "BagMenu" or "Gen2PackMenu",
    generation==1 and {} or {pocket="ITEM",onClose=function() stack:pop() end})
end
local function action(name)
  for i,row in ipairs(view().items) do if row.label==name then return i end end
  error("missing bag action "..name)
end
local function settle()
  untilReady(function() return not stack:top().repeatSfx end)
end
for _,style in ipairs({"hgss","hgss_dark"}) do
  run.loader.modOptions.kanto_gear.theme_v3=style
  run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3"})
  local native=open()
  local selected=native.index
  local root=view()
  T.eq(native.index,selected,"projecting bag preserves the original cursor")
  T.eq(root.title,"BAG","every field bag uses the common title")
  T.check(root.bagList,"ordinary field bag exposes the common list capabilities")
  T.eq(root.items[1].itemId,"POTION","native bag preserves exact inventory order")
  local model=display.startMenuModel(root)
  T.eq(model.visible,5,"all native bags use the common five-row layout")
  T.check(display.StartMenu.select(root,1),"paging test begins at the first native row")
  local queuedBefore=#queued
  display.tapStartMenu(root,205/1.5,201/1.5)
  T.eq(#queued,queuedBefore,"paging selects a window without confirming an item")
  T.eq(native.index,6,"next page selects the actual first row on that page")
  T.eq(display.startMenuModel(view()).first,6,"bag page advances through the shared window")
  T.check(pcall(display.drawContents),"second bag page renders")
  native.index=1
  choose(1)
  local actions=view()
  T.check(not root.valid(),"opening item actions expires old list touches")
  T.eq(actions.title,"POTION","item action page identifies its selected item")
  T.eq(actions.itemModel.detail.id,"POTION","native item actions use the shared detail card")
  T.eq(actions.itemModel.detail.count,4,"item card shows the real native stack")
  T.check(#actions.itemModel.detail.lines>0,"native item card uses the shared description")
  T.eq(actions.nativeGrid,nil,"item actions no longer copy a generation-specific native grid")
  T.check(actions.fixedLayout,"native actions keep all controls on the shared card")
  local appDetail=display.bagItem("POTION")
  T.same(actions.itemModel.detail,appDetail,"native and companion item cards use identical data")
  local itemModel=display.startMenuModel(actions)
  T.eq(#itemModel.entries,#actions.items,"all native actions, including cancel, remain visible")
  for i,row in ipairs(itemModel.entries) do
    T.same({row.x,row.y,row.w,row.h},{theme.hgss:bagActionRect(i,#actions.items)},"native bag action has the common item target")
    T.eq(display.StartMenu.hit(actions,row.x+row.w/2,row.y+row.h/2),i,"native item touch preserves row identity")
  end
  local queuedBefore=#queued
  display.tapStartMenu(actions,120/1.5,100/1.5)
  T.eq(#queued,queuedBefore,"item description cannot activate the old list underneath")
  T.eq(native.index,1,"item submenu preserves parent cursor")
  choose(action("TOSS"))
  T.check(not actions.valid(),"opening quantity expires item action touches")
  local quantity=view()
  T.eq(quantity.quantity.max,4,"discard quantity uses the actual owned stack")
  tap(220,110)
  T.eq(view().quantity.qty,2,"quantity plus delegates to native increment")
  tap(180,176)
  T.eq(save.inventory.POTION,4,"cancelled discard never changes inventory")
  if generation==1 then T.eq(stack:top(),native,"Gen1 quantity cancel returns to its original list")
  else T.check(not native.qtyState and not native.message,"Gen2 quantity cancel clears both native overlays") end
  T.check(not quantity.valid(),"cancelled quantity rejects delayed touches")

  choose(1);choose(action("TOSS"));tap(220,110);tap(60,176)
  T.eq(save.inventory.POTION,4,"choosing a quantity still requires safety confirmation")
  if generation==2 then
    local confirm=view()
    T.check(confirm.choiceState,"native toss confirmation uses the shared choice page")
    T.check(confirm.prompt,"toss confirmation retains the real native question")
    T.eq(confirm.index,1,"confirmation keeps the native default selection")
    local m=display.choiceModel(confirm,{"YES","NO"},confirm.prompt)
    local no=m.entries[2]
    tap(no.x+no.w/2,no.y+no.h/2)
    T.eq(save.inventory.POTION,4,"NO preserves the whole native stack")
    T.check(not confirm.valid(),"answered NO expires its confirmation")
    choose(1);choose(action("TOSS"));tap(220,110);tap(60,176)
    confirm=view();m=display.choiceModel(confirm,{"YES","NO"},confirm.prompt)
    local yes=m.entries[1];tap(yes.x+yes.w/2,yes.y+yes.h/2)
    T.eq(save.inventory.POTION,2,"YES discards exactly the selected quantity once")
    local notice=view()
    T.check(notice.notice,"native result dims the shared page")
    T.check(not confirm.valid(),"answered YES expires its confirmation")
    untilReady(function() return not native.message end,"a")
    T.eq(view().items[1].right,"x2","bag refreshes the native post-discard count")
    T.check(not notice.valid(),"dismissed result rejects stale continue taps")
  else
    untilReady(function() return getmetatable(stack:top())==require("src.ui.ChoiceBox") end,"a")
    T.check(pcall(display.drawContents),"Gen1 native safety choice renders on the common choice page")
    local m=display.choiceModel(stack:top(),{"YES","NO"})
    T.check(table.concat(m.prompt," "):find("POTION",1,true),"Gen1 choice shows the real item question instead of a generic placeholder")
    step("b");for _=1,20 do step() end
    T.eq(save.inventory.POTION,4,"native Gen1 NO preserves inventory")
    T.eq(stack:top(),native,"Gen1 declined toss restores the original bag")
  end

  native=open()
  local beforeFirst=view().items[1].itemId
  native.index=1;step("select")
  local moving=view()
  T.check(not moving.bagList,"item reordering never offers quick-use over its target list")
  T.eq(moving.nativePocket,nil,"a pocket that cannot change does not animate arrows")
  choose(generation==1 and 3 or 2)
  settle()
  T.eq(save.inventory.POTION,4,"native reorder does not consume its selected stack")
  local reordered=view()
  T.check(reordered.items[1].itemId~=beforeFirst,"native item reorder is reflected by the common list")
  T.check(not moving.valid(),"finishing reorder expires its old target list")

  native=open()
  display.recentItem:remember(save,"POTION")
  local quick=view()
  T.eq(quick.recentBag.id,"POTION","native bags share the last-used shortcut")
  T.eq(display.startMenuModel(quick).visible,4,"shortcut reserves the same four-row list region as Gen3")
  if generation==2 then
    local old=quick
    tap(110,14)
    T.check(not old.valid(),"changing native pockets expires old list touches")
    T.eq(view().items[1].itemId,"FIX_BALL","pocket arrows show the actual ball pocket")
    T.eq(view().recentBag.id,"POTION","last-used item stays reachable across native pockets")
    T.check(display.selectRecentBagItem(view()),"recent shortcut selects its native pocket and row")
    step(queued[#queued])
    T.eq(native:pocket().id,"ITEM","recent shortcut restores the item's real native pocket")
    T.eq(native.submenu.row.id,"POTION","recent shortcut opens the correct native item actions")
  else
    native.index=5
    T.check(display.selectRecentBagItem(view()),"recent shortcut selects the original Gen1 row")
    step(queued[#queued])
    T.eq(view().title,"POTION","Gen1 recent shortcut opens the correct item actions")
  end
  T.eq(save.inventory.POTION,4,"opening recent actions does not consume the item")
  native=open()
  local old=view()
  choose(#old.items)
  T.eq(stack:top(),world,"the list's CANCEL returns to the original game")
  T.check(not old.valid(),"closed native bag rejects stale touch events")

  native=open()
  if generation==2 then
    native.tutorial=true
    T.eq(display.startMenu(),nil,"scripted catch tutorial cannot be overridden by a field bag page")
    native.tutorial=false;native.battle=true
    T.eq(display.startMenu(),nil,"battle pack stays with its battle-specific controls")
    native.battle=false
  else
    native.script=function() end
    T.eq(display.startMenu(),nil,"scripted catch tutorial keeps its original input owner")
    native.script=nil
  end
  stack:push(require("src.ui.Menu").new(game,{{label="UNRELATED"}}))
  T.eq(display.startMenu(),nil,"unowned menu over the bag retains its own controls")
  stack.states={world}
  stack:push(require("src.ui.Menu").new(game,{{label="UNRELATED"}}))
  T.eq(display.startMenu(),nil,"unrelated menus are never mistaken for a bag")
end
if _G.KANTO_GEAR_RENDER_CAPTURE then _G.KANTO_GEAR_RENDER_CAPTURE(run,display,game) end
T.finish("Kanto Gear shared native field bags")
