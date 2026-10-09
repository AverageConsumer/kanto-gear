return function(T, run, display, raw)
  local a, session = display.gen3, raw.session
  local Bag, Items = require("src.core.game3.bag"), a.Items
  local Menu, Party = require("src.ui.game3.bag_menu"), require("src.ui.game3.party_menu")
  local Stack, Message = require("src.ui.game3.stack"), require("src.ui.game3.message")
  local function clear()
    Party.close(); Menu.close(); Stack.clear(); Message.reset()
    if a.profile.id == "emerald" then require("src.ui.game3.rse.bag_menu").reset() end
    display.gen3:refresh(); display.gen3.syncScreens()
    -- Standalone fixtures do not run the host's normal compose/update tick.
    for _, entry in ipairs(run.loader.hooks.chains["render.compose"] or {}) do
      if entry.owner == "kanto_gear" then
        for i=1,debug.getinfo(entry.callback,"u").nups do
          local name, value=debug.getupvalue(entry.callback,i)
          if name=="refreshBattle" then value() break end
        end
      end
    end
  end
  local function input(key) return {wasPressed=function(_, k) return k == key end,isDown=function() return false end} end
  local function ids(item)
    local out = {}; for _, row in ipairs(display.bagActions(item)) do out[#out+1]=row.id end; return out
  end
  clear()
  local potion, ball, rod = Items.toNumericId("POTION"), Items.toNumericId("POKE_BALL"), Items.toNumericId("OLD_ROD")
  Bag.add(session.bag, potion, 3); Bag.add(session.bag, ball, 3); Bag.add(session.bag, rod, 1)
  a:refresh()
  T.same(ids(potion), {"use","give","toss"}, "medicine exposes all native field actions")
  T.same(ids(ball), {"give","toss"}, "balls do not offer meaningless field use")
  T.same(ids(rod), {"use","register"}, "key items expose use/registration and no destructive action")
  local nativeTm = Items.toNumericId("TM01")
  T.same(ids(nativeTm), {"use"}, "unsupported native TM giving is not advertised")
  local before, last = Bag.get(session.bag,potion), display.lastBagItem().id
  T.eq(display.performBagAction(rod,"toss"), false, "important items cannot bypass the action whitelist")
  T.eq(display.performBagAction(ball,"use"), false, "unavailable field use does not open a stray native menu")
  T.eq(Stack.top(), nil, "rejected actions leave the native screen alone")
  T.check(display.performBagAction(potion,"toss"), "discard opens through the actual native handler")
  T.eq(Menu.mode,"toss", "discard reaches quantity without an extra bag/action tap")
  local quantityView = display.gen3Ui:list()
  T.eq(quantityView.quantity.itemId,potion,"quantity retains the exact selected item")
  T.eq(quantityView.quantity.max,before,"quantity reflects the native stack limit")
  T.eq(quantityView.quantity.wrap,false,"native discard clamps rather than wrapping")
  T.eq(quantityView.quantity.qty,1,"quantity begins with the native amount")
  Menu.tossQty=before
  quantityView=display.gen3Ui:list()
  T.eq(quantityView.quantity.qty,before,"cached native screen refreshes its amount")
  T.eq(quantityView.quantity.max,before,"cached quantity keeps its actual maximum")
  Menu.handleInput(input("up"))
  T.eq(Menu.tossQty,before,"native discard agrees with the upper boundary")
  T.eq(Bag.get(session.bag,potion),before,"opening discard does not consume inventory")
  Menu.handleInput(input("b")); clear()
  T.eq(Bag.get(session.bag,potion),before,"cancelling quantity preserves the stack")
  T.check(display.performBagAction(potion,"toss"),"discard can be reopened")
  Menu.tossQty=2; Menu.handleInput(input("a"))
  T.eq(Menu.mode,"toss_confirm","discard requires the native confirmation")
  T.eq(Bag.get(session.bag,potion),before,"quantity alone never discards items")
  Menu.handleInput(input("a"))
  T.eq(Menu.mode,"toss_done","native confirmed discard still shows its result")
  Menu.handleInput(input("a")); a:refresh()
  T.eq(Bag.get(session.bag,potion),before-2,"native confirmation discards exactly the selected quantity")
  display.recentItem:poll(a.save)
  T.eq(display.lastBagItem().id,last,"discard does not replace last successful use")
  clear()
  before=Bag.get(session.bag,ball)
  T.check(display.performBagAction(ball,"give"),"give delegates to native held-item handling")
  Menu.settle()
  T.eq(Stack.top() and Stack.top().id,"party","give opens the native Pokemon chooser")
  T.eq(Party.mode,"give","chooser carries the give intent, not healing")
  T.eq(Party._item,ball,"chooser retains the exact selected item")
  T.eq(Bag.get(session.bag,ball),before,"opening give never removes an item")
  Party.close(); clear()
  T.eq(Bag.get(session.bag,ball),before,"cancelled give preserves the item")
  local mon=session.party[1]
  local hp=mon.hp;mon.hp=1
  T.check(display.performBagAction(potion,"use"),"use enters the native target flow directly")
  Menu.settle()
  T.eq(Stack.top() and Stack.top().id,"party","use opens the real party chooser")
  T.eq(Party.mode,"use","use and give retain separate native purposes")
  T.eq(Party._item,potion,"use targets the exact chosen item")
  clear();mon.hp=hp
  local registered = session.registeredItem
  T.check(display.performBagAction(rod,"register"),"registration delegates to the native handler")
  T.eq(session.registeredItem,rod,"native registered item is updated")
  clear()
  T.eq(display.bagActions(rod)[2].label, "UNREGISTER", "registered item offers the inverse action")
  T.check(display.performBagAction(rod,"register"),"unregister delegates to the same native toggle")
  T.eq(session.registeredItem,nil,"unregister removes the native shortcut")
  clear();session.registeredItem=registered
  local Sell=require("src.ui.game3.sell_flow")
  Menu.show(session.bag,{session=session,location="shop"});Menu.settle()
  local sale=Sell.start({session=session,bag=session.bag,itemId=potion,owned=3})
  Menu.mode,Menu._sell="sell",sale
  quantityView=display.gen3Ui:list()
  T.eq(quantityView.quantity.itemId,potion,"sale quantity retains the original item")
  T.eq(quantityView.quantity.max,3,"sale exposes its native owned limit")
  T.eq(quantityView.quantity.wrap,true,"sale preserves native quantity wrap")
  sale:handleInput(input("down"))
  T.eq(sale.qty,3,"native sale wraps from one to its maximum")
  sale:handleInput(input("b"));Menu._sell=nil;clear()
  if a.profile.id~="emerald" then
    local Shop=require("src.ui.game3.shop_menu")
    local money=session.money;session.money=600
    Shop.show({session=session,items={potion}})
    Shop.handleInput(input("a"))
    local Fade=require("src.ui.game3.fade")
    Fade.tick(1);Fade.tick(1)
    Shop.handleInput(input("a"))
    quantityView=display.gen3Ui:list()
    T.eq(quantityView.quantity.itemId,potion,"mart quantity identifies its native item")
    T.eq(quantityView.quantity.max,2,"mart maximum uses native price and available money")
    T.eq(quantityView.quantity.wrap,nil,"FRLG purchases clamp at their boundaries")
    Shop.handleInput(input("up"));Shop.handleInput(input("up"))
    T.eq(Shop.qty,2,"native mart agrees with the affordable upper bound")
    Shop.close();session.money=money;clear()
  end
  if a.profile.id == "emerald" then
    local berry=Items.toNumericId("CHERI_BERRY")
    Bag.add(session.bag,berry,1);a:refresh()
    T.same(ids(berry),{"check_tag","use","give","toss"},"Emerald berries retain their additional tag action")
    T.check(display.performBagAction(berry,"check_tag"),"berry tag opens through native input")
    T.eq(Stack.top() and Stack.top().id,"rse_berry_tag","native berry information is displayed")
    clear()
  end
  -- Icon sources and quad reuse, independent of a headless GPU stub.
  local icon={}; local original
  if a.profile.id == "emerald" then
    local Kit=require("src.ui.game3.rse.scene_kit")
    local manifest,rgba=Kit.manifest,Kit.rgbaImage
    Kit.manifest=function() return {icons={rgba="fixture",w=24,h=24000,count=1000}} end
    Kit.rgbaImage=function() return icon end
    a.itemIcons=nil
    local first=a:itemIcon(potion)
    T.eq(first.image,icon,"Emerald uses its own imported item atlas")
    T.check(first.quad~=nil,"Emerald selects the exact item from the atlas")
    T.eq(a:itemIcon(potion),first,"unchanged icons reuse their quad instead of allocating every draw")
    Kit.manifest,Kit.rgbaImage=manifest,rgba
  else
    local Chrome=require("src.ui.game3.bag_chrome")
    original=Chrome.iconImage;Chrome.iconImage=function(id) T.eq(id,potion,"FRLG icon uses numeric item ID");return icon end
    a.itemIcons=nil
    local first=a:itemIcon(potion)
    T.eq(first.image,icon,"FRLG uses the native imported item image")
    T.eq(a:itemIcon(potion),first,"FRLG images reuse the presentation record")
    Chrome.iconImage=original
  end
  a.itemIcons=nil
end
