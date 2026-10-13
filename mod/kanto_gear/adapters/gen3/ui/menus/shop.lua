return function(UI, labels)
  function UI:shopMenu(layer, projection, battle)
    local RomText = projection.RomText
    local mode = projection.mode
    local native = projection.native
    projection.title = "BUY"
    -- Game path [Ruby/Sapphire/Emerald]: Hoenn marts include decoration shops and phased row cursors; Kanto uses buy_* phases.
    local rse = native._rse
    local decoration = rse and native._martType ~= require("src.ui.game3.rse.shop_menu").MART_NORMAL
    if mode == "root" then
      projection.items, projection.field = {}, "cursor"
      if rse then
        local keys = decoration and { "gText_ShopBuy", "gText_ShopQuit" }
          or { "gText_ShopBuy", "gText_ShopSell", "gText_ShopQuit" }
        for i, key in ipairs(keys) do
          projection.items[i] = { label = self.adapter.rs and rse.plain(key) or RomText.plain(key) }
        end
      else
        for i in ipairs(native.ROOT) do projection.items[i] = { label = RomText.at("sShopMenuActions_BuySellQuit", i - 1) } end
      end
    elseif mode == "buy" or rse and mode == "list" then
      projection.items, projection.field = {}, rse and "row" or "cursor"
      local discounted = false
      -- Game path [Ruby/Sapphire/Emerald]: Slateport TV discounts apply only when the native PokeNews hook enables the sale.
      if rse and not decoration then
        local Tv, Rse = require("src.core.game3.rse.tv"), require("src.core.game3.rse.init")
        -- The native mart applies Slateport's TV sale only when its hook permits it.
        discounted = Tv.isPokeNewsActive(native._session, 1, function(kind)
          return Rse.call("tv", "shouldApplyPokeNews", "ShouldApplyPokeNewsEffect", nil, kind) == true
        end)
      end
      for _, id in ipairs(native._items) do
        if decoration then
          local info = require("src.core.game3.rse.decoration_inventory").info(id)
          projection.items[#projection.items + 1] = { label = info and info.name or tostring(id), right = "¥" .. (info and info.price or 0) }
        else
          local price = math.max(0, math.floor(tonumber(self.adapter.Items.info(id).price) or 0))
          projection.items[#projection.items + 1] = { label = self.adapter.Items.displayName(id),
            right = "¥" .. (discounted and math.floor(price / 2) or price), itemId = id }
        end
      end
      projection.items[#projection.items + 1] = { label = "CANCEL" }
    elseif rse and mode == "qty" then
      projection.quantity = { label = self.adapter.Items.displayName(native._itemId), qty = native.qty,
        itemId = native._itemId, max = math.max(1, native._maxQty or 1), wrap = true, total = native._totalCost }
    elseif rse and mode == "confirm" then
      projection.items, projection.field, projection.prompt = labels({ "YES", "NO" }), "yesCursor", native._status
    elseif mode == "buy_qty" then
      local pending = native._pending
      projection.quantity = { label = pending.name, qty = native.qty, itemId = pending.id,
        total = (pending.price or 0) * native.qty,
        max = math.max(1, math.min(99, math.floor((tonumber(native._session.money) or 0)
          / math.max(1, pending.price or 0)))) }
    elseif mode == "buy_confirm" then projection.items, projection.field, projection.prompt = labels({ "YES", "NO" }), "yesNoCursor", native._status end
    return true
  end
end
