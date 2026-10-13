return function(T, run, display, raw)
  local a, session = display.gen3, raw.session
  local Bag, Items = require("src.core.game3.bag"), a.Items
  local Menu, Party = require("src.ui.game3.bag_menu"), require("src.ui.game3.party_menu")
  local Stack, Message = require("src.ui.game3.stack"), require("src.ui.game3.message")
  local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
  local function clear()
    Party.close(); Menu.close(); Stack.clear(); Message.reset()
    if a.profile.id == "emerald" then require("src.ui.game3.rse.bag_menu").reset() end
    if a.rs then require("src.ui.game3.rs.bag_menu").reset() end
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
  assert(loadfile(os.getenv("KANTO_GEAR_MOD_PATH") .. "/tests/move_page_cases.lua"))()(T, display, up(display.drawContents,"THEME").hgss)
  local potion, ball, rod = Items.toNumericId("POTION"), Items.toNumericId("POKE_BALL"), Items.toNumericId("OLD_ROD")
  Bag.add(session.bag, potion, 3); Bag.add(session.bag, ball, 3); Bag.add(session.bag, rod, 1)
  a:refresh()
  T.same(ids(potion), {"use","give","toss"}, "medicine exposes all native field actions")
  T.same(ids(ball), {"give","toss"}, "balls do not offer meaningless field use")
  T.same(ids(rod), {"use","register"}, "key items expose use/registration and no destructive action")
  local nativeTm = Items.toNumericId("TM01")
  T.same(ids(nativeTm), a.rs and {"use","give"} or {"use"}, "only editions supporting native TM giving advertise it")
  Bag.add(session.bag,nativeTm,1);a:refresh()
  assert(loadfile(os.getenv("KANTO_GEAR_MOD_PATH") .. "/tests/item_page_cases.lua"))()(T, display,
    up(display.drawContents,"THEME").hgss)
  local Screens=require("src.ui.game3.screens")
  for _,id in ipairs({potion,ball,rod,nativeTm}) do
    T.check(display.gen3Ui:openBagItem(id),"open native item detail test")
    local layer=Stack.top()
    local native=layer.mod
    if native.settle then native.settle() end
    Screens.handleInput(layer.id,native,input("a"),session)
    -- Emerald constructs the spatial grid on its first presentation tick.
    Screens.handleInput(layer.id,native,input("none"),session)
    local page=assert(display.startMenu())
    T.eq(page.itemActionId,id,"all native containers retain the selected item ID")
    T.eq(page.itemModel.detail.id,id,"native item page uses the companion detail model")
    T.eq(page.itemModel.detail.count,Bag.get(session.bag,id),"native item detail keeps the live stack")
    T.check(page.fixedLayout and not page.nativeGrid,"native containers share one item action layout")
    T.check(pcall(display.drawContents),"native item detail renders without a handoff")
    for i,row in ipairs(page.items) do
      local x,y,w,h=unpack(row.rect)
      T.same(row.rect,{display.ItemPage.rect(i,#page.items)},"Gen3 actions use the same targets as Gen1/2")
      T.eq(display.StartMenu.hit(page,x+w/2,y+h/2),i,"item detail tap maps to its native index")
      T.check(display.StartMenu.select(page,i),"each native item action remains selectable")
      T.eq(native.actionCursor,i,"native action order remains authoritative")
      if a.profile.id=="emerald" then
        local st=require("src.ui.game3.rse.bag_menu")._st
        T.eq(st.grid.cells[st.gridPos+1].idx,i,"common touch preserves Emerald's spatial cursor")
      end
    end
    -- Touching the visible cancel executes the actual native cancel handler.
    local cancel=#page.items
    local queued={}
    local mod=up(display.saveHome,"mod")
    local oldTap=mod.input.tap
    mod.input.tap=function(_,target,key) queued[#queued+1]=key end
    local row=page.items[cancel].rect
    display.tapStartMenu(page,(row[1]+row[3]/2)/1.5,(row[2]+row[4]/2)/1.5)
    T.same(queued,{"a"},"one touch confirms exactly the native cancel action")
    mod.input.tap=oldTap
    Screens.handleInput(layer.id,native,input(queued[1]),session)
    T.check(not page.valid(),"dismissed item detail rejects old touch targets")
    T.eq(Bag.get(session.bag,id),page.itemModel.detail.count,"cancel leaves inventory unchanged")
    clear()
  end
  -- A stale action map cannot activate a different command after native rows change.
  T.check(display.gen3Ui:openBagItem(potion),"open item to verify action invalidation")
  Menu.settle();Screens.handleInput("bag",Menu,input("a"),session)
  Screens.handleInput("bag",Menu,input("none"),session)
  local previous=assert(display.startMenu())
  local actions=Menu.ACTIONS
  Menu.ACTIONS={"CANCEL","USE"}
  T.check(not previous.valid(),"changed native actions invalidate old touch indices")
  Menu.ACTIONS=actions
  clear()
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
  -- Actual item confirmation, including compacted sparse move slots.
  local mon = session.party[1]
  local savedMoves, savedPp, savedMax, savedBonus = mon.moves, mon.pp, mon.maxPp, mon.ppBonusesPacked
  mon.moves, mon.pp, mon.maxPp, mon.ppBonusesPacked = {33,0,45,0}, {0,0,1,0}, {35,0,40,0}, 0
  local ether, ppup = Items.toNumericId("ETHER"), Items.toNumericId("PP_UP")
  Bag.add(session.bag,ether,3); Bag.add(session.bag,ppup,2)
  local function ppChooser(id)
    clear(); a:refresh()
    T.check(display.performBagAction(id,"use"),"PP item opens the real party picker")
    Menu.settle()
    if a.rs then
      T.check(not display.startMenu().valid(), "RS party fade rejects touch before native input is ready")
      for _ = 1, 120 do Party.update(1 / 60) end
      T.check(display.startMenu().valid(), "settled RS party allows PP target selection")
    end
    Screens.handleInput("party",Party,input("a"),session)
    T.eq(Party.mode,"forget","native PP selector is open")
    a:refresh(); a.syncScreens()
    local view = assert(display.startMenu(),"PP selector has a common touch page")
    T.check(view.moveSelection and view.fixedLayout,"PP uses attack cards instead of generic choices")
    T.eq(#view.items,2,"empty native move slots never become fake actions")
    T.eq(view.items[2].move.id,a.Moves.constName(45),"compacted second row retains native third move")
    T.check(pcall(display.drawContents),"PP page draws without a handoff")
    return view
  end
  local view = ppChooser(ether)
  local beforeEther = Bag.get(session.bag,ether)
  display.StartMenu.select(view,2)
  T.eq(Party._forgetCursor,2,"touch updates native compact cursor rather than raw move slot")
  Screens.handleInput("party",Party,input("b"),session)
  T.eq(Bag.get(session.bag,ether),beforeEther,"cancel consumes no PP item")
  T.eq(Party.mode,"use","cancel returns to the native party target page")
  T.check(not view.valid(),"cancelled PP page rejects delayed taps")
  view = ppChooser(ether)
  local keys = {}; local mod = up(display.saveHome,"mod"); local savedTap = mod.input.tap
  mod.input.tap = function(_,target,key) keys[#keys+1] = key end
  local x,y,w,h = unpack(view.items[2].rect)
  display.tapStartMenu(view,(x+w/2)/1.5,(y+h/2)/1.5)
  mod.input.tap = savedTap
  T.same(keys,{"a"},"one attack card tap confirms exactly once")
  Screens.handleInput("party",Party,input(keys[1]),session)
  T.eq(mon.pp[1],0,"choosing compact row two leaves the first move untouched")
  T.check(mon.pp[3]>1,"actual host restores the native third move")
  T.eq(Bag.get(session.bag,ether),beforeEther-1,"successful PP restoration consumes exactly one item")
  T.check(not view.valid(),"completed PP page expires")
  view = ppChooser(ppup)
  display.StartMenu.select(view,1)
  local beforeUp = Bag.get(session.bag,ppup)
  Screens.handleInput("party",Party,input("a"),session)
  T.eq(mon.maxPp[1],42,"native PP Up raises the actual maximum")
  T.eq(Bag.get(session.bag,ppup),beforeUp-1,"PP Up consumes exactly one item")
  view = ppChooser(ether)
  T.eq(view.items[1].right,"7/42","common page shows PP bonuses from the live native mon")
  -- A complete move still goes through the host's no-effect result.
  mon.pp[1]=42
  view=ppChooser(ether)
  display.StartMenu.select(view,1)
  local untouched=Bag.get(session.bag,ether)
  Screens.handleInput("party",Party,input("a"),session)
  T.eq(Bag.get(session.bag,ether),untouched,"full PP refuses without spending an Ether")
  T.eq(mon.pp[1],42,"no-effect result preserves the actual PP")
  view=ppChooser(ether)
  -- Imported native saves may carry packed bonuses ahead of maxPp normalization.
  mon.ppBonusesPacked,mon.maxPp[1]=2,35
  view=assert(display.startMenu())
  T.eq(view.items[1].right,"42/49","packed PP bonuses are authoritative like the native item handler")
  T.eq(view.items[1].move.maxPp,49,"inspection and the card share the authoritative PP maximum")
  T.eq(view.items[1].move.ppUps,2,"normalized move data retains imported PP bonuses")
  local old = view
  Party._forgetMoves = {"different"}
  T.check(not old.valid(),"replaced chooser rows invalidate stale touch indices")
  clear()
  mon.moves, mon.pp, mon.maxPp, mon.ppBonusesPacked = savedMoves, savedPp, savedMax, savedBonus
  a:refresh()
  local registered = session.registeredItem
  T.check(display.performBagAction(rod,"register"),"registration delegates to the native handler")
  T.eq(session.registeredItem,rod,"native registered item is updated")
  clear()
  T.eq(display.bagActions(rod)[2].label, "UNREGISTER", "registered item offers the inverse action")
  T.check(display.performBagAction(rod,"register"),"unregister delegates to the same native toggle")
  T.eq(session.registeredItem,a.rs and 0 or nil,"unregister removes the native shortcut")
  clear();session.registeredItem=registered
  local Sell=require("src.ui.game3.sell_flow")
  Menu.show(session.bag,{session=session,location="shop"});Menu.settle()
  local sale=Sell.start({session=session,bag=session.bag,itemId=potion,owned=3})
  Menu.mode,Menu._sell="sell",sale
  quantityView=display.gen3Ui:list()
  T.eq(quantityView.quantity.itemId,potion,"sale quantity retains the original item")
  T.eq(quantityView.quantity.max,3,"sale exposes its native owned limit")
  T.eq(quantityView.quantity.total,sale:total(),"sale displays the native total")
  T.eq(quantityView.quantity.wrap,true,"sale preserves native quantity wrap")
  sale:handleInput(input("down"))
  T.eq(sale.qty,3,"native sale wraps from one to its maximum")
  T.eq(display.gen3Ui:list().quantity.total,sale:total(),"sale total follows native quantity changes")
  sale:handleInput(input("b"));Menu._sell=nil;clear()
  if not a.hoenn then
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
  if a.hoenn then
    local berry=Items.toNumericId("CHERI_BERRY")
    Bag.add(session.bag,berry,1);a:refresh()
    T.same(ids(berry),{"check_tag","use","give","toss"},"Emerald berries retain their additional tag action")
    T.check(display.performBagAction(berry,"check_tag"),"berry tag opens through native input")
    T.eq(Stack.top() and Stack.top().id,a.rs and "rs_berry_tag" or "rse_berry_tag","native berry information is displayed")
    clear()
  end
  -- Icon sources and quad reuse, independent of a headless GPU stub.
  local icon={}; local original
  if a.rs then
    T.eq(a:itemIcon(potion), nil, "RS has no native item icon pack and keeps the generic symbol")
  elseif a.hoenn then
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
