-- Native menu integration: real handlers own every inventory/party mutation.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, raw, maps)
  local Stack = require("src.ui.game3.stack")
  local session = raw.session
  local function input(key)
    return { wasPressed = function(_, k) return key == k end, isDown = function() return false end }
  end
  local function menu()
    local layer = Stack.top()
    if layer and layer.id == "box_storage" then
      local frames = 0
      while layer.mod.isPresentationBusy() and frames < 240 do
        layer.mod.update(1 / 60)
        frames = frames + 1
      end
      T.check(not layer.mod.isPresentationBusy(), "native storage transition finishes before the next gesture")
    end
    local m = display.startMenu()
    T.check(m and display.StartMenu.cursor(m, true), "native menu has valid mirrored cursor")
    if m then
      display.gen3.syncScreens()
      display.drawContents()
    end
    return assert(m)
  end
  local Pc = require("src.ui.game3.pc_menu")
  Pc.show({ session = session })
  for _, mode in ipairs({ "root", "player_pc", "item_storage", "storage_menu" }) do
    Pc.mode, Pc.cursor = mode, 1
    local m = menu()
    display.StartMenu.select(m, #m.items)
    T.eq(Pc.cursor, #m.items, "PC focus matches native " .. mode)
  end
  local stale = menu()
  Pc.close()
  T.check(not display.StartMenu.select(stale, 1), "closed PC rejects queued touches")

  local ItemPc = require("src.ui.game3.item_pc")
  local Bag = require("src.core.game3.bag")
  local savedItems, savedBag = session.storage.items, session.bag
  session.storage.items, session.bag = {}, Bag.new()
  for i = 1, 9 do session.storage.items[i] = { id = i + 12, qty = 3 } end
  ItemPc.show({ session = session }); ItemPc._fx = nil
  local m = menu()
  display.StartMenu.select(m, 8)
  T.eq(ItemPc.scroll + ItemPc.row, 7, "PC item selection retains absolute slot after scrolling")
  ItemPc.handleInput(input("a"))
  m = menu(); display.StartMenu.select(m, 1)
  ItemPc.handleInput(input("a"))
  T.eq(menu().quantity.qty, 1, "withdrawal shows native quantity")
  ItemPc.handleInput(input("up"))
  T.eq(menu().quantity.qty, 2, "D-pad quantity stays mirrored")
  ItemPc.handleInput(input("a"))
  T.eq(Bag.get(session.bag, 20), 2, "native handler adds withdrawn quantity")
  T.check(menu().notice ~= nil, "withdrawal result mirrored before acknowledgement")
  ItemPc.handleInput(input("a"))
  T.eq(session.storage.items[8].qty, 1, "native acknowledgement debits PC once")
  ItemPc.open = false; Stack.clear()
  session.storage.items, session.bag = savedItems, savedBag

  local Summary = require("src.ui.game3.summary_menu")
  local mon = session.party[1]
  local savedMoves = mon.moves
  mon.moves = { 15, 33, 45, 0 }
  local result = false
  Summary.openMenu({ mon }, 1, { session = session, mode = "select_move", moveToLearn = 22,
    onSelectMove = function(slot) result = slot end })
  Summary._slide.active = false
  m = menu(); T.eq(#m.items, 4, "sparse moves keep native slots and cancel")
  display.StartMenu.select(m, 1); Summary.handleInput(input("a"))
  T.eq(result, false, "HM refusal remains native")
  T.check(Summary._hmNotice, "HM rejection is visible")
  m = menu()
  display.StartMenu.select(m, 2); Summary.handleInput(input("a"))
  T.eq(result, 1, "native move replacement callback uses zero-based slot")
  T.check(not display.StartMenu.select(m, 1), "closed move chooser rejects stale input")
  mon.moves = savedMoves
  Stack.clear(); display.gen3:refresh()

  local Naming = require("src.ui.game3.naming")
  local named
  Naming.open({ title = "NAME", maxLen = 7, onDone = function(value) named = value end })
  for page = 1, 3 do
    Naming._state.page = page
    Naming._state.row, Naming._state.col = 1, 1
    m = menu()
    for i, entry in ipairs(m.items) do
      if entry.row then
        local r = entry.rect
        T.eq(display.StartMenu.hit(m,r[1]+r[3]/2,r[2]+r[4]/2),i,"keyboard touch geometry matches native cell")
        Naming._state.name = ""
        T.check(display.StartMenu.select(m, i), "keyboard cell selectable")
        T.eq(m.index, i, "keyboard focus maps back to selected cell")
        Naming.handleInput(input("a"))
        T.eq(Naming._state.name, entry.label == "_" and " " or entry.label, "native keyboard character agrees")
      end
    end
  end
  Naming._state.name = "TEST"
  m = menu(); display.StartMenu.select(m, #m.items - 1)
  Naming.handleInput(input("a")); T.eq(Naming._state.name, "TES", "native keyboard backspace")
  display.StartMenu.select(m, #m.items); Naming.handleInput(input("a"))
  T.eq(named, "TES", "native naming callback only on confirmation")
  T.check(not display.StartMenu.select(m, 1), "closed keyboard rejects stale touch")

  local Box = require("src.ui.game3.box_storage_ui")
  local savedBox, savedCurrent = session.storage.boxes[1].mons, session.storage.currentBox
  session.storage.boxes[1].mons, session.storage.currentBox = { [8] = mon }, 1
  Box.show({ session = session, subMode = "move" })
  local opening = assert(display.startMenu())
  T.check(Box.isPresentationBusy(), "native storage starts with its opening animation")
  T.check(not display.StartMenu.select(opening, 11), "storage rejects touches during its opening animation")
  m = menu(); T.eq(#m.items, 33, "box keeps all thirty slots, party, close and title")
  for i,entry in ipairs(m.items) do
    local r=entry.rect
    local expected = not entry.inert and i or nil
    T.eq(display.StartMenu.hit(m,r[1]+r[3]/2,r[2]+r[4]/2),expected,"only active native box targets accept touch")
    if entry.inert then T.check(not display.StartMenu.select(m,i),"empty browsing cells cannot send a native action") end
  end
  display.StartMenu.select(m, 11); T.eq(Box.cursorSlot, 8, "sparse box slot is not compacted")
  Box.handleInput(input("a")); m = menu()
  T.eq(m.partyActions,display.gen3:mon(mon),"box action hero identifies the actual selected partner")
  for index,entry in ipairs(m.items) do
    T.same(entry.rect,{display.gen3Ui.layout:partyActionRow(index,#m.items)},"all storage actions share common hero controls")
  end
  display.StartMenu.select(m, 1); Box.handleInput(input("a"))
  T.eq(Box.holdingMon, mon, "native move picks up original mon")
  m = menu(); display.StartMenu.select(m, 20); Box.handleInput(input("a"))
  T.eq(session.storage.boxes[1].mons[17], mon, "native move places mon into selected empty slot")
  T.eq(session.storage.boxes[1].mons[8], nil, "native move clears source once")
  m = menu(); display.StartMenu.select(m, 1); Box.handleInput(input("a"))
  m = menu(); T.eq(#m.items, 7, "party drawer retains six slots and cancel")
  for slot=1,6 do
    local x,y=display.gen3Ui.layout:partyPosition(slot)
    T.same(m.items[slot].rect,{x,y,112,56},"PC drawer shares fixed team card "..slot)
    local expected=session.party[slot] and slot or nil
    T.eq(display.StartMenu.hit(m,x+56,y+28),expected,"empty PC team slots stay inactive without a held partner")
    if not expected then T.check(not display.StartMenu.select(m,slot),"inactive PC slot cannot queue native input") end
  end
  T.eq(display.StartMenu.hit(m,12,12),"back","PC drawer uses the same header Back control")
  display.StartMenu.select(m, 7); Box.handleInput(input("a"))
  T.eq(Box.mode, "browse", "party cancellation returns to box")
  -- The actual host still owns a box-to-party move through a common empty card.
  local scratch=require("src.core.game3.save_schema_firered").newGame({version=os.getenv("POKEPORT_VERSION"),name="TEST",rngSeed=481})
  local P=require("src.core.game3.pokemon")
  require("src.core.game3.party").giveMon(scratch,P.speciesFromNational(25),10)
  local incoming=scratch.party[1]
  local count=#session.party
  session.storage.boxes[1].mons[17]=incoming
  m=menu();display.StartMenu.select(m,20);Box.handleInput(input("a"))
  m=menu();display.StartMenu.select(m,1);Box.handleInput(input("a"))
  T.eq(Box.holdingMon,incoming,"native pickup supplies the real incoming partner")
  m=menu();display.StartMenu.select(m,1);Box.handleInput(input("a"))
  m=menu();T.check(m.emptyTargets,"holding a boxed partner enables the empty cards")
  local rect=m.items[count+1].rect
  T.eq(display.StartMenu.hit(m,rect[1]+56,rect[2]+28),count+1,"the next empty card is a native move target")
  T.check(display.StartMenu.select(m,count+1),"touch can select the actual empty party slot")
  Box.handleInput(input("a"))
  T.eq(session.party[count+1],incoming,"native placement fills the intended common team slot")
  T.eq(#session.party,count+1,"native placement adds exactly one partner")
  T.eq(session.storage.boxes[1].mons[17],nil,"native pickup clears the original box slot")
  T.eq(Box.holdingMon,nil,"native placement finishes holding the partner")
  session.party[count+1]=nil
  Box.close()
  session.storage.boxes[1].mons, session.storage.currentBox = savedBox, savedCurrent

  local Release = require("src.ui.game3.release_seq")
  Box.show({ session = session })
  local boxView, released = menu(), nil
  Release.start({ session = session, mon = mon, onComplete = function(value) released = value end })
  m = menu(); T.eq(m.index, 2, "release preserves native default NO")
  T.check(not display.StartMenu.select(boxView, 1), "release overlay locks background box")
  Release.handleInput(input("a"))
  T.eq(released, false, "release confirmation does not accidentally discard a mon")
  T.check(not display.StartMenu.select(m, 1), "closed release rejects stale confirmation")
  Box.close()

  local Shop = require("src.ui.game3.shop_menu")
  local savedMoney = session.money
  savedBag, session.bag = session.bag, Bag.new()
  session.money = 10000
  Shop.show({ session = session, items = { 13, 14 } })
  menu(); Shop.mode = "buy" -- Skip only the native field-camera fade in this headless fixture.
  m = menu(); display.StartMenu.select(m, 1); Shop.handleInput(input("a"))
  T.eq(menu().quantity.qty, 1, "shop quantity mirrors native amount")
  Shop.handleInput(input("up")); T.eq(menu().quantity.qty, 2, "shop amount increments natively")
  Shop.handleInput(input("a")); m = menu()
  T.check(m.prompt and m.prompt:find("2"), "shop confirmation includes amount")
  display.StartMenu.select(m, 1); Shop.handleInput(input("a"))
  T.eq(Bag.get(session.bag, 13), 2, "purchase handled once by native shop")
  T.eq(session.money, 10000 - 2 * display.gen3.Items.info(13).price, "native shop charges exact price")
  T.check(menu().notice ~= nil, "purchase result mirrored")
  Shop.handleInput(input("a")); session.money = 0
  Shop.handleInput(input("a")); T.check(menu().notice ~= nil, "insufficient money notice mirrored")
  Shop.close(); session.money, session.bag = savedMoney, savedBag

  local NativeBag = require("src.ui.game3.bag_menu")
  savedItems, savedBag, savedMoney = session.storage.items, session.bag, session.money
  session.storage.items, session.bag, session.money = {}, Bag.new(), 0
  Bag.add(session.bag,13,5)
  NativeBag.show(session.bag,{session=session,pocket="ITEMS",location="itempc"}); NativeBag.settle()
  m=menu(); display.StartMenu.select(m,1); NativeBag.handleInput(input("a"))
  T.eq(menu().quantity.qty,1,"PC deposit begins at native quantity")
  NativeBag.handleInput(input("up")); NativeBag.handleInput(input("a"))
  T.check(menu().notice ~= nil,"PC deposit result is mirrored")
  T.eq(session.storage.items[1].qty,2,"native PC receives selected amount")
  NativeBag.handleInput(input("a"))
  T.eq(Bag.get(session.bag,13),3,"PC deposit acknowledgement debits bag exactly once")
  NativeBag.close(); Stack.clear()
  NativeBag.show(session.bag,{session=session,pocket="ITEMS",location="shop"}); NativeBag.settle()
  m=menu(); display.StartMenu.select(m,1); NativeBag.handleInput(input("a"))
  T.eq(menu().quantity.qty,1,"sale uses native sell-flow quantity")
  NativeBag.handleInput(input("up")); NativeBag.handleInput(input("a"))
  m=menu(); T.check(m.prompt ~= nil,"sale confirmation shows native price")
  display.StartMenu.select(m,1); NativeBag.handleInput(input("a"))
  T.check(menu().notice ~= nil,"sale result remains visible")
  T.eq(Bag.get(session.bag,13),1,"native sale removes selected amount once")
  T.eq(session.money,math.floor(display.gen3.Items.info(13).price/2)*2,"native sale credits half price")
  NativeBag.close(); Stack.clear()
  session.storage.items,session.bag,session.money=savedItems,savedBag,savedMoney

  local Growth = require("src.ui.game3.stat_growth")
  local completed = 0
  Growth.open(mon, { maxHp=20, atk=10, def=10, spa=10, spd=10, spe=10 },
    { maxHp=22, atk=11, def=12, spa=10, spd=11, spe=11 }, function() completed = completed + 1 end)
  m = menu(); T.eq(m.nativeStats._page, 1, "level-up deltas page mirrored")
  Growth.handleInput(input("a")); T.eq(menu().nativeStats._page, 2, "level-up totals page mirrored")
  T.check(not display.StartMenu.select(m, 1), "old level-up page rejects queued input")
  Growth.handleInput(input("a")); T.eq(completed, 1, "level-up completes exactly once")
  if _G.KANTO_GEAR_CONTROLS_CAPTURE then _G.KANTO_GEAR_CONTROLS_CAPTURE(run, display, raw, maps) end
end
dofile(path .. "/tests/gen3_runtime_test.lua")
