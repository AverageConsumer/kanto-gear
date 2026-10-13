package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
love.graphics.arc = love.graphics.arc or function() end
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local run = T.sdk.loadMod(path, {
  generation = generation,
  data = T.fixtures.load(),
})

T.eq(run.mod and run.mod.state, "loaded", "Kanto Gear loads")
T.eq(#run.errors, 0, "Kanto Gear boots without errors")

local worldUses = 0
local world = {
  map = { id = "PALLET_TOWN", def = {} },
  useFieldItem = function()
    worldUses = worldUses + 1
    return "nowhere"
  end,
}
local stack = { states = {} }
function stack:top() return self.states[#self.states] end
function stack:push(state) self.states[#self.states + 1] = state end
function stack:pop() return table.remove(self.states) end
function stack:clear() self.states = {} end

local itemId = generation == 1 and "FIX_BALL" or "FIX_POTION"
local save = {
  generation = generation,
  player = { name = "RED", id = 7, map = "PALLET_TOWN" },
  party = {}, inventory = { [itemId] = 2 }, boxes = {}, currentBox = 1,
  pokedex = { seen = {}, caught = {} }, money = 3000,
}
local game = {
  data = run.data, save = save, world = world, overworld = world, stack = stack,
}
if generation == 1 then stack:push(world) end
run.loader.events:emit("game.ready", { game = game })
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss" }
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "theme_v3" })

local upvalue = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local inputHook
for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
  if entry.owner == "kanto_gear" then inputHook = entry.callback end
end
local display = upvalue(inputHook, "displayRuntime")
T.check(type(display) == "table", "Bag runtime is reachable")
local rawPartyView = display.partyView({ species = "FIXMON_A", hp = 5,
  stats = { hp = 12 } })
T.eq(rawPartyView.maxHp, 12,
  "native party records expose their calculated maximum HP")
T.eq(rawPartyView.hpText, "5/12",
  "contextual party screens never render current HP over zero")
T.eq(display.storeEntry(display.storeById.bag).state, "get",
  "the optional Bag app is available from Silph Store")
T.check(display.setPackageInstalled("bag", false),
  "Bag can be removed from the customizable Home")
T.check(display.setPackageInstalled("bag", true), "Bag installs from the Store")
T.eq(display.storeEntry(display.storeById.bag).state, "open",
  "the installed Bag app is ready to open")
T.check(display.openHomeApp("bag"), "Bag opens from Home")
local model = display.bagModel()
T.eq(model.total, 1, "Bag reads the live inventory")
T.eq(model.entries[1].id, itemId, "Bag preserves the real item id")
T.check(model.canUse, "Bag enables USE only on the idle overworld")
local summary = display.bagSummary()
T.eq(summary.item + summary.medicine + summary.ball + summary.machine, 2,
  "Bag widget counts only the real ordered Bag contents")

local before = #stack.states
T.check(display.useBagItem(itemId),
  "Bag delegates USE to the original generation path")
if generation == 1 then
  T.check(#stack.states == before + 1 and stack:top().isTextBox,
    "Gen 1 skips the native Bag submenu and opens only the official result")
else
  T.eq(worldUses, 1, "Gen 2 runs the original field-item dispatch exactly once")
  T.eq(#stack.states, before, "Gen 2 does not push a mirrored Pack screen")
end
T.eq(save.inventory[itemId], 2,
  "a refused field use does not consume the item")

if generation == 1 then
  stack:clear()
  stack:push(world)
  run.data.items.FIX_POTION.needsTarget = true
  save.inventory.FIX_POTION = 1
  save.party = { { species = "FIXMON_A", nickname = "TESTMON",
    hp = 5, moves = { { id = "FIX_MOVE_A", pp = 4 } } } }
  T.check(display.useBagItem("FIX_POTION"),
    "Gen 1 field medicine opens through the original Bag path")
  local picker, party, title = display.fieldBagParty()
  T.check(picker and picker.screenId == "PartyMenu",
    "Gen 1 field medicine gives the bottom screen its native party picker")
  T.eq(party[1], save.party[1], "Gen 1 field picker keeps live party data")
  T.eq(title, "USE ITEM ON", "Gen 1 field picker explains its action below")

  display.bag.pending = { itemId = "ETHER", mon = save.party[1] }
  local ppPicker = { kind = "Which move?", title = "Which move?", index = 1,
    items = { { label = "FIX CUT", right = "4" } } }
  stack:push(ppPicker)
  local pp = display.fieldPpMoveScreen()
  T.check(pp and pp.native == ppPicker and pp.cursor == "index",
    "Gen 1 PP items give the bottom screen their native move picker")
  T.check(pp.items[1].right:find("/", 1, true),
    "Gen 1 PP item rows include current and maximum PP")
end

-- ROM item definitions do not carry the BattleAPI's synthetic `ball` flag.
local cases = {
  { "POKE_BALL", 20, "BALL" }, { "GREAT_BALL", 11, "BALL" }, { "ULTRA_BALL", 5, "BALL" },
  { "POTION", 3, "ITEM" }, { "FULL_RESTORE", 2, "ITEM" }, { "FRESH_WATER", 4, "ITEM" },
  { "ETHER", 2, "ITEM" }, { "FULL_HEAL", 1, "ITEM" },
  { "ESCAPE_ROPE", 5, "ITEM" }, { "RARE_CANDY", 2, "ITEM" }, { "PROTEIN", 1, "ITEM" },
  { "PP_UP", 1, "ITEM" }, { "BICYCLE", 1, "KEY_ITEM" },
  { "TM01", 3, "TM_HM" }, { "HM03", 1, "TM_HM" },
}
save.inventory, save.bagOrder = { FIX_BADGE_1 = 1, EMPTY = 0 }, { "FIX_BADGE_1", "POKE_BALL", "POKE_BALL", "STALE" }
save.pcItems = { POKE_BALL = 99 }
for _, row in ipairs(cases) do
  save.inventory[row[1]] = row[2]
  run.data.items[row[1]] = { name = "Translated item", pocket = generation == 2 and row[3] or nil }
end
T.same(display.bagSummary(), { item = 10, medicine = 12, ball = 36, machine = 4 },
  "widget counts quantities by actual item type, excluding badges, stale rows and PC storage")
T.eq(#save.bagOrder, 4, "reading widget totals never edits the save's acquisition order")
for _, id in ipairs({ "RARE_CANDY", "PROTEIN", "PP_UP" }) do
  run.data.items[id].needsTarget = true
  T.eq(display.bagItemKind(id, run.data.items[id]), "item", "target selection does not make " .. id .. " a healing item")
end
if generation == 2 then
  local balls = { "MASTER_BALL", "LURE_BALL", "FAST_BALL", "LEVEL_BALL", "HEAVY_BALL", "LOVE_BALL", "FRIEND_BALL", "MOON_BALL", "PARK_BALL" }
  for _, id in ipairs(balls) do
    run.data.items[id] = { name = "Translated ball", pocket = "BALL" }
    save.inventory[id] = 2
    T.eq(display.bagItemKind(id, run.data.items[id]), "ball", id .. " uses its native pocket")
  end
  T.eq(display.bagSummary().ball, 54, "all Gen 2 ball stacks count toward the same total")
  local effects = require("src.core.gen2.ItemEffects")
  for _, family in ipairs({ "HEAL_HP", "HEAL_STATUS", "REVIVE", "RESTORE_PP" }) do
    for id in pairs(effects[family]) do
      local kind = display.bagItemKind(id, { pocket = "ITEM" })
      T.check(kind == "medicine" or kind == "status", id .. " follows its healing effect")
    end
  end
  run.data.gen2ItemEffects = { CUSTOM_CURE = { action = "heal" } }
  T.eq(display.bagItemKind("CUSTOM_CURE", { pocket = "ITEM" }), "medicine", "registered custom healing effects count too")
end
local previous = display.bagSummary().ball
save.inventory.POKE_BALL = save.inventory.POKE_BALL - 1
T.eq(display.bagSummary().ball, previous - 1, "using one ball updates the next widget snapshot")
save.inventory.GREAT_BALL = nil
T.eq(display.bagSummary().ball, previous - 12, "depositing or removing a stack removes its full quantity")
T.eq(display.bagItemKind("CUSTOM_ORB", { ball = true }), "ball", "explicit mod ball metadata remains supported")
T.eq(display.bagItemKind("LIGHT_BALL", { pocket = "ITEM" }), "item", "a held Light Ball is not a capture ball")

-- Pocket mods filter the shared Bag.order while their native menu is open.
-- Gear's independent inventory must not inherit that temporary view.
local Bag = require("src.inventory.Bag")
local originalOrder = Bag.order
local originalInventory, originalBagOrder = save.inventory, save.bagOrder
save.inventory = { POTION = 3, POKE_BALL = 8, TM01 = 1,
  FIX_BADGE_1 = 1, EMPTY = 0 }
save.bagOrder = { "POTION", "POKE_BALL", "POKE_BALL", "STALE", "FIX_BADGE_1" }
local savedOrder = table.concat(save.bagOrder, ",")
local orderCalls = 0
Bag.order = function()
  orderCalls = orderCalls + 1
  return { "POTION" }
end
local function allBagIds()
  local ids = {}
  for pocket = 1, generation == 2 and 4 or 1 do
    display.bag.pocket, display.bag.page = pocket, 1
    for page = 1, display.bagModel().pages do
      display.bag.page = page
      for _, entry in ipairs(display.bagModel().entries) do
        ids[#ids + 1] = entry.id
      end
    end
  end
  table.sort(ids)
  return ids
end
T.same(allBagIds(), { "POKE_BALL", "POTION", "TM01" },
  "all owned items remain visible despite another mod's pocket filter")
T.eq(orderCalls, 0, "reading Gear's inventory never invokes the mutable pocket filter")
T.eq(table.concat(save.bagOrder, ","), savedOrder,
  "Gear leaves the native acquisition order untouched")
T.eq(save.inventory.POKE_BALL, 8, "reading hidden balls preserves their quantity")
save.bagOrder = nil
T.same(allBagIds(), { "POKE_BALL", "POTION", "TM01" },
  "legacy saves without acquisition order still expose the full inventory")
T.eq(save.bagOrder, nil, "reading a legacy save does not create acquisition order")
save.inventory.POKE_BALL = nil
T.same(allBagIds(), { "POTION", "TM01" },
  "removed stacks disappear even while the native pocket filter is active")
Bag.order = originalOrder
save.inventory, save.bagOrder = originalInventory, originalBagOrder
-- The real native field-item dispatch, not a synthetic decrement.
stack:clear();stack:push(world)
save.inventory,save.bagOrder={ POTION=3, FULL_RESTORE=2 }, { "POTION", "FULL_RESTORE" }
run.data.items.POTION={ name="POTION", pocket="ITEM", needsTarget=true }
run.data.items.FULL_RESTORE={ name="FULL RESTORE", pocket="ITEM", needsTarget=true }
save.party={ { species="FIXMON_A",name="PARTNER",hp=1,
  stats={hp=30},moves={} } }
world.useFieldItem=function() return nil end
game.say=function() end
if generation==2 then
  local Game2=require("src.core.Game2")
  game.useFieldItem,game.usePartyItem,game.consumeItem=Game2.useFieldItem,Game2.usePartyItem,Game2.consumeItem
end
display.bag.pocket=1
display.recentItem:bind(save)
T.check(display.useBagItem("POTION"),"companion opens the real potion target picker")
local picker=stack:top()
if generation==1 then picker.onSwitch(save.party[1],picker)
else picker.onChoose(1,save.party[1]) end
display.recentItem:poll(save)
T.eq(save.inventory.POTION,2,"native successful use consumes exactly one potion")
T.eq(display.lastBagItem().id,"POTION","successful native effect enables the shortcut")
T.eq(display.lastBagItem().count,2,"shortcut shows the live remaining quantity")
stack:clear();stack:push(world);save.party[1].hp=30
T.check(display.useBagItem("FULL_RESTORE"),"another native medicine can be attempted")
picker=stack:top()
if generation==1 then picker.onSwitch(save.party[1],picker)
else picker.onChoose(1,save.party[1]) end
display.recentItem:poll(save)
T.eq(save.inventory.FULL_RESTORE,2,"native no-effect use consumes nothing")
T.eq(display.lastBagItem().id,"POTION","no-effect use does not replace the last successful item")
stack:clear();stack:push(world);display.bag.detail=nil;display.bag.message=nil
local H=upvalue(display.drawBag,"THEME").hgss
local model=display.bagModel()
T.eq(H:bagHit(120,88,model),"recent","visible quick-access row is touch reachable")
T.eq(H:bagHit(20,120,model),"item","ordinary cards stay touch reachable below it")
T.eq(H:bagHit(20,106,model),nil,"the gap between shortcut and cards is inactive")
save.inventory.POTION=nil
T.eq(display.bagModel().recent,nil,"an empty stack removes the shortcut from the model")
-- Companion actions must preserve the native safety prompts and ownership.
stack:clear();stack:push(world)
save.inventory.POTION=3
local function actionIds(id)
  local out={};for _, row in ipairs(display.bagActions(id)) do out[#out+1]=row.id end;return out
end
T.same(actionIds("POTION"),generation==1 and {"use","toss"} or {"use","give","toss"},
  "item actions follow the generation's actual capabilities")
run.data.items.SAFE_KEY={name="SAFE KEY",pocket="KEY_ITEM",keyItem=true,canToss=false,canSelect=true}
save.inventory.SAFE_KEY=1
T.same(actionIds("SAFE_KEY"),generation==1 and {"use"} or {"use","register"},"key items never offer toss/give")
T.eq(display.performBagAction("SAFE_KEY","toss"),false,"important item cannot bypass the native permissions")
T.eq(#stack.states,1,"rejected item action creates no screen")
T.check(display.performBagAction("POTION","toss"),"discard reaches the native quantity flow")
T.eq(save.inventory.POTION,3,"opening discard never removes inventory")
T.eq(display.recentItem.pending,nil,"discard cannot be observed as successful use")
local quantityView=display.startMenu()
T.check(quantityView and quantityView.quantity,"native bag quantity uses the shared companion page")
T.eq(quantityView.quantity.max,3,"shared page exposes the native Gen1/2 stack limit")
T.eq(quantityView.quantity.label,run.data.items.POTION.name,"quantity keeps the actual selected item name")
T.eq(quantityView.quantity.wrap,true,"legacy native quantity preserves wrap at its ends")
T.eq(H:pcQuantityHit(190,110,quantityView.quantity),"plus","native quantity has a lower-screen plus target")
T.check(pcall(display.drawContents),"native bag quantity renders without a handoff")
T.eq(display.nativeHandoff,false,"quantity stays usable on the companion screen")
if generation==1 then
  local quantity=stack:top()
  T.eq(quantity.max,3,"native toss quantity uses the real stack")
  T.check(type(quantity.onDone)=="function","native quantity owns continuation/confirmation")
  quantity.onDone(nil)
  T.eq(save.inventory.POTION,3,"cancelled native quantity preserves every item")
else
  local pack=stack:top()
  T.eq(pack.qtyState.max,3,"native toss quantity uses the real stack")
  pack.qtyState.qty=2;pack:confirmToss()
  T.eq(save.inventory.POTION,3,"quantity selection still requires native confirmation")
  pack.confirm.onYes()
  T.eq(save.inventory.POTION,1,"native confirmation discards exactly two items")
end
stack:clear();stack:push(world)
T.eq(display.StartMenu.cursor(quantityView),nil,"a dismissed quantity page rejects stale touches")
if generation==2 then
  T.check(display.performBagAction("POTION","give"),"give enters the original held-item flow")
  T.eq(stack:top().screenId,"Gen2PartyMenu","give opens the native Pokemon selection")
  local targets=display.startMenu()
  T.check(targets and targets.party,"give exposes the native party on the shared lower-screen page")
  T.eq(targets.title,"GIVE ITEM TO","give keeps its distinct purpose on the target page")
  T.eq(display.StartMenu.select(targets,1),true,"give target is touch-selectable")
  T.eq(save.inventory.POTION,1,"opening give preserves the unselected item")
  stack:clear();stack:push(world)
end
for _, dark in ipairs({false,true}) do
  H:setVariant(dark)
  for _, wrap in ipairs({false,true}) do
    local q={label="POTION",qty=1,max=1,wrap=wrap}
    T.eq(H:pcQuantityHit(40,110,q),nil,"single-item minus never has an action")
    T.eq(H:pcQuantityHit(190,110,q),nil,"single-item plus never has an action")
    T.eq(H:pcQuantityHit(40,170,q),"confirm","single-item confirm remains usable")
  end
  for count=1,5 do
    local actions={};for i=1,count do actions[i]={id=tostring(i),label="ACTION "..i} end
    local detail={detail={label="POTION",count=3,icon="medicine",lines={"LINE ONE","LINE TWO","LINE THREE"}},actions=actions,canUse=true}
    T.check(pcall(H.bagDetail,H,detail),"item actions draw in both themes")
    for i=1,count do
      local x,y,w,h=H:bagActionRect(i,count)
      T.check(y>=148 and y+h<=210,"all action rows fit below the description")
      local hit,index=H:bagHit(x+w/2,y+h/2,detail)
      T.eq(hit,"action","button and tap geometry agree")
      T.eq(index,i,"touch identifies the exact semantic item action")
      detail.canUse=false
      T.eq(H:bagHit(x+w/2,y+h/2,detail),nil,"blocked context cannot invoke an item action")
      detail.canUse=true
      actions[i].enabled=false
      T.eq(H:bagHit(x+w/2,y+h/2,detail),nil,"unavailable item action has no touch target")
      actions[i].enabled=true
    end
  end
end
assert(loadfile(path .. "/tests/item_page_cases.lua"))()(T,display,H)
assert(loadfile(path .. "/tests/safari_cases.lua"))()(T,display,H)
assert(loadfile(path .. "/tests/move_page_cases.lua"))()(T,display,H)
assert(loadfile(path .. "/tests/pp_legacy_cases.lua"))()(T,display,game,generation,run)
assert(loadfile(path .. "/tests/recent_item_cases.lua"))()(T,path)
T.finish("Kanto Gear HGSS Bag runtime")
