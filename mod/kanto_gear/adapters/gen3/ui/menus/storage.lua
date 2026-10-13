return function(UI, labels)
  function UI:storageMenu(layer, projection, battle)
    local RomText = projection.RomText
    local mode = projection.mode
    local native = projection.native
    projection.title = "PC"
    -- The release overlay temporarily owns input, even while the box says browse.
    if require("src.ui.game3.release_seq").isActive() then return nil end
    local storage = native._session.storage
    local box = storage.boxes[storage.currentBox]
    if mode == "browse" then
      projection.field, projection.grid = "cursorSlot", true
      local function monAt(slot)
        local picked = native.holdingSource and native.holdingSource.loc == "box"
          and native.holdingSource.boxId == storage.currentBox and native.holdingSource.slot == slot
        return not picked and box.mons[slot] or nil
      end
      projection.items, projection.slots = self.storagePage.box({ capacity = 30, name = box.name,
        primary = { label = "PARTY", value = -10 }, cancel = { label = "CLOSE", value = -20 },
        monAt = monAt, enabled = function(slot) return native.holdingMon ~= nil or monAt(slot) ~= nil end })
      local selected = native.holdingMon or box.mons[native.cursorSlot]
      projection.title = selected and self.adapter.Pokemon.displayMonName(selected) or box.name
    elseif mode == "party_drawer" then
      projection.field, projection.grid, projection.boxParty = "partyCursor", true, true
      -- The common team page keeps native slot identity, including empty targets.
      local function monAt(slot)
        local source = native._session.party[slot]
        local picked = source and source == native.holdingMon and native.holdingSource
          and native.holdingSource.loc == "party" and native.holdingSource.slot == slot
        return not picked and source or nil
      end
      projection.items, projection.slots = self.storagePage.party(self.layout, { monAt = monAt,
        monView = function(mon) return self.adapter:mon(mon) end,
        enabled = function(slot) return monAt(slot) ~= nil or native.holdingMon ~= nil end })
    elseif mode == "action_menu" then projection.items, projection.field = labels(native._activeActions), "actionCursor"
    elseif mode == "box_menu" then projection.items, projection.field = labels({ "SWITCH BOX", "WALLPAPER", "CANCEL" }), "boxMenuCursor"
    elseif mode == "pick_box" then
      projection.items, projection.field = {}, "cursorSlot"
      for _, b in ipairs(storage.boxes) do projection.items[#projection.items + 1] = { label = b.name } end
    elseif mode == "pick_wallpaper" then
      projection.items, projection.field = {}, "wallpaperCursor"
      for i = 1, 16 do projection.items[i] = { label = RomText.at("sMenuTexts", 21 + i) } end
    end
    return true
  end
  function UI:pcMenu(layer, projection, battle)
    local RomText = projection.RomText
    local mode = projection.mode
    local native = projection.native
    projection.title, projection.field = "PC", "cursor"
    if mode == "root" then projection.items = labels(native._rootEntries())
    elseif mode == "storage_menu" then projection.items = labels(native._storageOptions())
    -- Game path [Ruby/Sapphire/Emerald]: Player PC order includes mail/decorations and ROM-specific exit text; Kanto uses native action arrays.
    elseif self.adapter.hoenn and (mode == "player_pc" or mode == "item_storage") then
      local rows = mode == "player_pc" and require("src.ui.game3.rse.player_pc").topOrder(native)
        or { "withdraw", "deposit", "toss", "exit" }
      local keys = { item_storage = "gText_ItemStorage", mailbox = "gText_Mailbox",
        decoration = "gText_Decoration", turn_off = "gText_TurnOff",
        withdraw = "gText_WithdrawItem", deposit = "gText_DepositItem",
        toss = "gText_TossItem", exit = self.adapter.rs and "gOtherText_Exit" or "gText_Cancel" }
      projection.items = {}
      for _, id in ipairs(rows) do projection.items[#projection.items + 1] = { label = RomText.plain(keys[id]) } end
    elseif mode == "player_pc" then projection.items = labels(native.TOP_ACTIONS)
    elseif mode == "item_storage" then projection.items = labels(native.ITEM_STORAGE_ACTIONS) end
    return true
  end
  function UI:itemStorageMenu(layer, projection, battle)
    local RomText = projection.RomText
    local mode = projection.mode
    local native = projection.native
    -- Game path [Ruby/Sapphire/Emerald vs FireRed/LeafGreen]: item storage differs in phase names, toss mode and quantity field.
    local rse = layer.id == "rse_item_storage"
    projection.title = (mode == "swap" or mode == "move") and "MOVE"
      or rse and (native._toss and "TOSS" or "WITHDRAW") or "ITEMS"
    local rows = native._session.storage.items
    if mode == "list" or mode == "move" or mode == "swap" then
      projection.items, projection.field = {}, "row"
      for _, row in ipairs(rows) do
        projection.items[#projection.items + 1] = { label = self.adapter.Items.displayName(row.id),
          right = "x" .. row.qty, itemId = row.id }
      end
      projection.items[#projection.items + 1] = { label = "CANCEL" }
    elseif mode == "qty" or mode == "quantity" then
      local row = rows[native.scroll + native.row + 1]
      projection.quantity = row and { label = self.adapter.Items.displayName(row.id), qty = rse and native.quantity or native.qty,
        itemId = row.id, max = row.qty, wrap = true }
    elseif mode == "yesno" then
      projection.items, projection.field, projection.prompt = labels({ "YES", "NO" }), "yesCursor", native._message
    elseif mode == "submenu" then
      projection.items, projection.field = labels({ RomText.plain("gText_Withdraw"), RomText.plain("gOtherText_Give"),
        RomText.plain("gFameCheckerText_Cancel") }), "subCursor"
    end
    return true
  end
end
