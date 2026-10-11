return function(T, display, raw)
  local a, session = display.gen3, raw.session
  local Shop = require("src.ui.game3.shop_menu")
  local Fade = require("src.ui.game3.fade")
  local Stack = require("src.ui.game3.stack")
  local Bag, Items = require("src.core.game3.bag"), a.Items
  local emerald = a.hoenn
  local money = session.money
  local function input(key) return { wasPressed = function(_, k) return k == key end, isDown = function() return false end } end
  local function view() return display.gen3Ui:list() end
  local function key(k) Shop.handleInput(input(k)) end
  local function settle() Fade.tick(1); Fade.tick(1) end
  local function open(stock, cash, kind)
    Shop.close(); Stack.clear(); session.money = cash
    Shop.show({ session = session, items = stock, martType = kind })
  end
  local function choose(index)
    local page = view()
    T.check(display.StartMenu.select(page, index), "shop touch selects the native absolute row")
    local model = display.StartMenu.model(page)
    local rect
    for row, entry in ipairs(model.entries) do if model.first + row - 1 == index then rect = entry end end
    assert(rect, "selected shop row has shared touch geometry")
    raw.input.pressQueue = {}
    display.tapStartMenu(page, (rect.x + rect.w / 2) / 1.5, (rect.y + rect.h / 2) / 1.5)
    T.same(raw.input.pressQueue, { "a" }, "one shop row touch queues one native confirmation")
    key(raw.input.pressQueue[1])
    settle()
    return page
  end
  local potion, ball = Items.toNumericId("POTION"), Items.toNumericId("POKE_BALL")
  local price = Items.info(potion).price
  open({ potion }, price * 2)
  T.eq(#view().items, 3, "normal mart offers buy, sell and quit")
  choose(1)
  local list = view()
  T.eq(list.items[1].itemId, potion, "stock supplies native item art identity")
  T.eq(list.items[1].right, "¥" .. price, "normal stock shows the native unit price")
  local owned = Bag.get(session.bag, potion)
  choose(1)
  local quantity = view()
  T.check(not list.valid(), "stock touches expire when native quantity takes over")
  T.eq(quantity.quantity.itemId, potion, "purchase quantity retains its native item")
  T.eq(quantity.quantity.max, 2, "purchase limit agrees with available money")
  T.eq(quantity.quantity.total, price, "initial total is the native one-item price")
  T.eq(quantity.quantity.wrap == true, emerald, "quantity preserves the edition's native wrap rule")
  key("down")
  T.eq(Shop.qty, emerald and 2 or 1, "native quantity agrees at the lower boundary")
  key("up"); key("up")
  T.eq(Shop.qty, 2, "quantity remains within the native affordable range")
  T.eq(view().quantity.total, price * 2, "shared total updates with the native quantity")
  key("b")
  T.check(not quantity.valid(), "cancelled quantity rejects late taps")
  T.eq(Bag.get(session.bag, potion), owned, "cancelled quantity preserves inventory")
  T.eq(session.money, price * 2, "cancelled quantity preserves money")
  choose(1); key("up"); key("a")
  local confirmation = view()
  T.eq(confirmation.prompt, Shop._status, "purchase confirmation uses the actual native prompt")
  T.check(confirmation.choiceState ~= nil, "mart reuses the common confirmation page")
  T.check(display.StartMenu.select(confirmation, 2), "NO maps to the native confirmation cursor")
  key("a")
  T.eq(Bag.get(session.bag, potion), owned, "NO does not purchase anything")
  T.eq(session.money, price * 2, "NO does not charge money")
  T.check(not confirmation.valid(), "old confirmation cannot confirm a different phase")
  choose(1); key("up"); key("a"); key("a")
  local receipt = view()
  T.eq(receipt.notice, Shop._status, "receipt remains the game's native notice")
  T.eq(Bag.get(session.bag, potion), owned + 2, "native purchase adds exactly the chosen amount")
  T.eq(session.money, 0, "native purchase charges exactly its total")
  key("a")
  T.check(not receipt.valid(), "acknowledged receipt cannot act on stock")
  choose(1)
  T.eq(view().notice, Shop._status, "unaffordable stock shows native refusal, not a quantity picker")
  key("b")
  T.eq(view().items[1].itemId, potion, "refusal returns to the same stock")
  Bag.remove(session.bag, potion, 2)

  if emerald then
    local stock = {}
    for _, name in ipairs({ "POTION", "SUPER_POTION", "HYPER_POTION", "ANTIDOTE", "BURN_HEAL",
        "ICE_HEAL", "AWAKENING", "PARLYZ_HEAL", "FULL_HEAL", "POKE_BALL" }) do
      stock[#stock + 1] = assert(Items.toNumericId(name), name)
    end
    open(stock, 99999); choose(1)
    choose(9)
    T.eq(Shop._itemId, stock[9], "paged stock touch selects scroll+row rather than obsolete cursor")
    T.check(Shop.row >= 0 and Shop.row < 8, "native stock row stays within its eight-row viewport")
    key("b")
    choose(#stock + 1)
    T.eq(Shop.state, "root", "paged cancel row returns to the native mart root")

    local premier = Items.toNumericId("PREMIER_BALL")
    local balls, premiers = Bag.get(session.bag, ball), Bag.get(session.bag, premier)
    open({ ball }, Items.info(ball).price * 10); choose(1); choose(1)
    key("right"); key("a"); key("a")
    T.eq(Bag.get(session.bag, ball), balls + 10, "native ten-ball purchase survives the shared quantity page")
    T.eq(Bag.get(session.bag, premier), premiers, "bonus is not awarded prematurely by Gear")
    key("a")
    T.eq(Bag.get(session.bag, premier), premiers + 1, "native receipt acknowledgement grants the Premier Ball")
    T.eq(view().notice, Shop._status, "bonus keeps its own native notice phase")
    key("a")
    T.eq(Shop.state, "list", "bonus acknowledgement returns to stock")
    Bag.remove(session.bag, ball, 10); Bag.remove(session.bag, premier, 1)

    local Tv, Rse = require("src.core.game3.rse.tv"), require("src.core.game3.rse.init")
    local news = Tv.state(session).pokeNews
    local oldNews, oldCall = news[0], Rse.call
    news[0] = { kind = 1, state = Tv.POKENEWS_STATE_ACTIVE }
    Rse.call = function(domain, method, ...)
      if domain == "tv" and method == "shouldApplyPokeNews" then return true end
      return oldCall(domain, method, ...)
    end
    open({ potion }, price); choose(1)
    T.eq(view().items[1].right, "¥" .. math.floor(price / 2), "TV sale stock price matches native discount")
    choose(1)
    T.eq(Shop._totalCost, math.floor(price / 2), "native selection confirms the displayed discounted price")
    T.eq(view().quantity.total, Shop._totalCost, "shared total preserves the native TV discount")
    T.eq(view().quantity.max, 2, "discounted affordability comes from the native quantity limit")
    key("b"); Shop.close()
    Rse.call, news[0] = oldCall, oldNews

    local Decor = require("src.core.game3.rse.decoration_inventory")
    for _, kind in ipairs({ "DECOR", "DECOR2" }) do
      local id, info = 1, Decor.info(1)
      open({ id }, info.price, kind)
      T.eq(#view().items, 2, "decoration shop never advertises unsupported SELL")
      choose(1)
      local decoration = view().items[1]
      T.eq(decoration.label, info.name, "decoration uses its own extracted name")
      T.eq(decoration.right, "¥" .. info.price, "decoration uses its own price")
      T.eq(decoration.itemId, nil, "overlapping decoration ID never selects normal item art")
      local had = Decor.has(id, session)
      choose(1)
      T.eq(view().prompt, Shop._status, "decoration goes directly to its native confirmation")
      T.eq(view().quantity, nil, "decoration does not invent a multi-buy phase")
      key("b")
      T.eq(Decor.has(id, session), had, "cancelled decoration purchase preserves ownership")
      T.eq(session.money, info.price, "cancelled decoration purchase preserves money")
    end
  end
  Shop.close(); Stack.clear(); session.money = money
  a:refresh(); a.syncScreens()
end
