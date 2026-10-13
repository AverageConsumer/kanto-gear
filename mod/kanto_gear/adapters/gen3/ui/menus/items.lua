return function(UI, labels)
  function UI:saleMenu(layer, projection, battle)
    local RomText = projection.RomText
    local mode = projection.mode
    local native = projection.native
    local rsSummaryState = projection.rsSummaryState
    local sale = projection.sale
    projection.title = "SELL"
    if sale.state == "qty" then projection.quantity = { label = sale.name, qty = sale.qty,
        itemId = sale.itemId, max = sale.owned, wrap = true, total = sale:total() }
    elseif sale.state == "confirm" then
      projection.items, projection.field, projection.prompt = labels({ "YES", "NO" }), "yesNo", sale.name .. "\n" .. sale.text
    end
    return true
  end
  function UI:itemQuantityMenu(layer, projection, battle)
    local RomText = projection.RomText
    local mode = projection.mode
    local native = projection.native
    projection.title = mode == "deposit" and "DEPOSIT" or "TOSS"
    local row = native.list()[native.cursor]
    if mode == "toss_confirm" then
      projection.items, projection.field = labels({ "YES", "NO" }), "yesNoCursor"
      projection.prompt = row and self.adapter.Items.displayName(row.id) .. "\n" ..
        RomText.box(self.adapter.hoenn and "gText_ConfirmTossItems"
          or "gText_ThrowAwayStrVar2OfThisItemQM", {
          stringVars = { self.adapter.Items.displayName(row.id), tostring(native.tossQty) } })
    else projection.quantity = row and { label = self.adapter.Items.displayName(row.id), qty = native.tossQty,
      itemId = row.id, max = mode == "deposit" and math.min(999, row.qty or 1) or row.qty,
      wrap = mode == "deposit" or layer.id == "berry_pouch" } end
    return true
  end
  function UI:subcontainerMenu(layer, projection, battle)
    local native = projection.native
    projection.title = layer.id == "tm_case" and "TM/HM" or "BERRIES"
    if native.mode == "list" then
      projection.items, projection.field = {}, "cursor"
      for _, row in ipairs(native.list()) do
        projection.items[#projection.items + 1] = { label = row.name or self.adapter.Items.displayName(row.id),
          right = "x" .. tostring(row.qty or 0), itemId = self.adapter.Items.toNumericId(row.id) }
      end
      projection.items[#projection.items + 1] = { label = "CANCEL" }
    elseif native.mode == "action" and not native._sellMode then
      -- Native subcontainers use these fixed action orders (not Bag ACTIONS).
      projection.items = labels(layer.id == "tm_case" and { "USE", "GIVE", "EXIT" }
        or { "USE", "GIVE", "TOSS", "EXIT" })
      projection.field = "actionCursor"
    end
    return true
  end
  function UI:bagMenu(layer, projection, battle)
    local native = projection.native
    projection.title = "BAG"
    if native.mode == "list" then
      projection.items, projection.field, projection.pocket = {}, "cursor", true
      local id = native.currentPocket()
      projection.title = ({ ITEMS = "ITEMS", KEY_ITEMS = "KEY ITEMS", POKE_BALLS = "BALLS",
        TM_CASE = "TM/HM", BERRY_POUCH = "BERRIES" })[id] or "BAG"
      for _, item in ipairs(native.list()) do
        projection.items[#projection.items + 1] = { label = item.name or self.adapter.Items.displayName(item.id),
          right = "x" .. tostring(item.qty or 0), itemId = item.id,
          catchChance = battle and self.adapter:catchChance(item.id, self.adapter.Battle.getState()) }
      end
      projection.items[#projection.items + 1] = { label = "CANCEL" }
    elseif native.mode == "action" then
      projection.items, projection.field = labels(native.ACTIONS), "actionCursor"
    end
    return true
  end
end
