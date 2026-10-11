return function(T, display, raw)
  if not display.gen3.hoenn then return end
  local session, a = raw.session, display.gen3
  local Pc = require("src.ui.game3.pc_menu")
  local Store = require("src.ui.game3.rse.item_storage")
  local Stack = require("src.ui.game3.stack")
  local Bag, Items = require("src.core.game3.bag"), a.Items
  local savedItems, savedBag = session.storage.items, session.bag
  session.bag = Bag.new()
  local potion, rod = Items.toNumericId("POTION"), Items.toNumericId("OLD_ROD")
  local function input(key) return { wasPressed = function(_, k) return k == key end, isDown = function() return false end } end
  local function view()
    a:refresh(); a.syncScreens()
    local page = assert(display.startMenu(), "native PC phase has a companion projection")
    T.check(pcall(display.drawContents), "native PC phase renders through the shared page")
    return page
  end
  local function key(k)
    (Stack.top().mod).handleInput(input(k))
  end
  local function choose(index)
    local page = view()
    T.check(display.StartMenu.select(page, index), "PC touch selects its actual native entry")
    local model, rect = display.StartMenu.model(page)
    for row, entry in ipairs(model.entries) do if model.first + row - 1 == index then rect = entry end end
    assert(rect, "PC entry has common draw/hit geometry")
    raw.input.pressQueue = {}
    display.tapStartMenu(page, (rect.x + rect.w / 2) / 1.5, (rect.y + rect.h / 2) / 1.5)
    T.same(raw.input.pressQueue, { "a" }, "one PC touch queues one native confirmation")
    key("a")
    return page
  end
  local function open(toss, rows)
    Store.close(); Pc.close(); Stack.clear()
    session.storage.items = rows
    Pc.show({ session = session, startMode = "player_pc" })
    choose(1)
    T.eq(Pc.mode, "item_storage", "real player PC opens its native storage actions")
    choose(toss and 3 or 1)
  end
  open(false, {})
  T.eq(Pc.mode, "rse_msg", "empty storage reaches the native refusal")
  local notice = view()
  T.eq(notice.notice, Pc._status, "empty-PC notice is projected instead of leaving a dead screen")
  key("a")
  T.eq(Pc.mode, "item_storage", "notice acknowledgement returns to storage actions")
  T.check(not notice.valid(), "old empty-PC notice cannot operate the returned menu")

  open(false, { { id = potion, qty = 5 } })
  T.eq(Stack.top().id, "rse_item_storage", "withdraw opens the real Emerald storage child")
  local list = choose(1)
  T.check(not list.valid(), "stock touches expire when native quantity takes over")
  local quantity = view()
  T.eq(quantity.quantity.itemId, potion, "stored quantity supplies native item art identity")
  T.eq(quantity.quantity.qty, 1, "withdraw quantity begins at the native amount")
  T.eq(quantity.quantity.max, 5, "withdraw limit is the actual stored stack")
  T.eq(quantity.quantity.wrap, true, "withdraw preserves native quantity wrapping")
  key("down")
  T.eq(Store.quantity, 5, "native quantity wraps to the actual maximum")
  key("b")
  T.check(not quantity.valid(), "cancelled quantity rejects queued taps")
  T.eq(session.storage.items[1].qty, 5, "cancel leaves storage unchanged")
  T.eq(Bag.get(session.bag, potion), 0, "cancel adds nothing to the bag")
  choose(1); key("up"); key("a")
  T.eq(Store.state, "remove", "withdraw keeps the native result phase")
  T.eq(Bag.get(session.bag, potion), 2, "native withdraw adds exactly the selected amount")
  T.eq(session.storage.items[1].qty, 5, "Gear does not remove the stored stack ahead of native acknowledgement")
  notice = view()
  T.eq(notice.notice, Store._message, "withdraw result uses the native message")
  key("a")
  T.eq(session.storage.items[1].qty, 3, "native acknowledgement removes exactly the transferred amount")
  T.check(not notice.valid(), "acknowledged withdrawal cannot execute a stale touch")
  choose(2)
  T.eq(Pc.mode, "item_storage", "child cancel calls the native parent callback")
  T.eq(Pc.cursor, 1, "withdraw returns to its original parent action")

  open(true, { { id = potion, qty = 3 } })
  choose(1); key("up"); key("a")
  local confirmation = view()
  T.eq(confirmation.prompt, Store._message, "discard confirmation uses the game's actual question")
  T.check(confirmation.choiceState ~= nil, "discard reuses the common choice page")
  choose(2)
  T.eq(session.storage.items[1].qty, 3, "NO preserves the stored stack")
  T.eq(Store.state, "list", "NO returns to storage rows")
  T.check(not confirmation.valid(), "old discard question cannot discard after cancellation")
  choose(1); key("up"); key("a"); choose(1)
  T.eq(Store.state, "remove", "confirmed discard retains its native receipt")
  T.eq(session.storage.items[1].qty, 3, "confirmed discard is finalized by native acknowledgement")
  key("b")
  T.eq(session.storage.items[1].qty, 1, "native discard removes exactly two stored items")
  choose(1)
  T.eq(Store.state, "yesno", "one stored item skips unnecessary quantity selection")
  choose(1); key("a")
  T.eq(#session.storage.items, 0, "native discard compacts an exhausted row")
  T.eq(#view().items, 1, "empty list exposes only the native cancel row")
  choose(1)
  T.eq(Pc.cursor, 3, "discard returns to its actual parent action")

  open(true, { { id = rod, qty = 1 } })
  choose(1)
  T.eq(Store.state, "error", "important stored items retain the native protection")
  T.eq(view().notice, Store._message, "protected item refusal remains readable and advanceable")
  key("a")
  T.eq(session.storage.items[1].id, rod, "protected item remains in storage")
  T.eq(session.storage.items[1].qty, 1, "protected item quantity is unchanged")

  session.bag = Bag.new()
  local capacity = Items.CAPACITY.ITEMS
  for id = 1, 1000 do
    if id ~= potion and Items.info(id) and Items.pocketOf(id) == "ITEMS" then
      Bag.add(session.bag, id, 1)
      if #session.bag.pockets.ITEMS == capacity then break end
    end
  end
  T.eq(#session.bag.pockets.ITEMS, capacity, "fixture fills the bag through native inventory rules")
  T.eq(Bag.canAdd(session.bag, potion, 1), false, "fixture actually refuses an additional item")
  open(false, { { id = potion, qty = 1 } })
  choose(1)
  T.eq(Store.state, "error", "full bag reaches the native withdrawal error")
  T.eq(view().notice, Store._message, "full bag error reuses the shared notice state")
  key("a")
  T.eq(session.storage.items[1].qty, 1, "failed withdrawal does not lose the stored item")
  T.eq(Bag.get(session.bag, potion), 0, "failed withdrawal adds no phantom item")

  local rows = {}
  for _, name in ipairs({ "POTION", "SUPER_POTION", "HYPER_POTION", "ANTIDOTE", "BURN_HEAL",
      "ICE_HEAL", "AWAKENING", "PARLYZ_HEAL", "FULL_HEAL", "POKE_BALL" }) do
    rows[#rows + 1] = { id = assert(Items.toNumericId(name)), qty = 3 }
  end
  open(false, rows)
  choose(9)
  T.eq(view().quantity.itemId, rows[9].id, "paged storage touch selects the absolute native stack")
  T.check(Store.row >= 0 and Store.row < 8, "paged storage preserves the native eight-row viewport")
  key("b")
  display.StartMenu.select(view(), 1); key("select")
  T.eq(Store.state, "swap", "native reorder preserves its own state")
  T.eq(view().title, "MOVE", "reorder has a common context label")
  local moved = rows[1]
  choose(4)
  T.eq(rows[3], moved, "shared row selection preserves native insertion semantics")
  T.eq(Store.state, "list", "native reorder returns to normal rows")
  choose(#rows + 1)
  T.eq(Pc.mode, "item_storage", "paged cancel returns to the same PC parent")

  Store.close(); Pc.close(); Stack.clear()
  session.storage.items, session.bag = savedItems, savedBag
  a:refresh(); a.syncScreens()
end
