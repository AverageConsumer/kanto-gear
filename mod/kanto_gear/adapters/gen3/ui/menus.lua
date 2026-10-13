return function(UI, labels)
  local function nativeMode(layer)
    local native = layer.mod
    if layer.id == "summary" and type(native._mode) == "number" then
      return (native._mode == 2 or native._mode == 3) and "select_move" or native._state
    end
    -- Emerald retains mode=buy throughout list, quantity, confirmation and receipt.
    -- Game path [Ruby/Sapphire/Emerald]: shop mode stays buy while state advances through list, quantity, confirmation and receipt.
    if layer.id == "shop" and native._rse then return native.state end
    if layer.id == "save" then return native._phase end
    return native.mode or native.state or native._mode
  end
  function UI:notice(layer, projection)
    local native, mode = projection.native, projection.mode
    local sale, saleState, RomText = projection.sale, projection.saleState, projection.RomText
    local function noticeText()
      if sale and (sale.state == "cant" or sale.state == "done") then return sale.text end
      if native.mode == "oak" and layer.id == "party" then
        return native._oakPages and native._oakPages[native._oakPage]
      end
      if native.mode == "message" and layer.id == "party" then return native._messageText end
      if native.mode == "message" and native.messageText then return native.messageText end
      if layer.id == "pc_menu" and (mode == "msg" or mode == "rse_msg") then return native._status end
      if layer.id == "rse_item_storage" and (mode == "remove" or mode == "error") then return native._message end
      if layer.id == "shop" and (mode == "buy_msg" or mode == "msg") then return native._status end
      if layer.id == "box_storage" and mode == "message" then return native._status end
      if layer.id == "item_pc" then
        if mode == "result" then return native.resultText end
        if mode == "msg" then return native.msgText end
      end
      if layer.id == "move_relearner" and mode == "message" then return native.prompt end
      if layer.id == "bag" and mode == "deposit_done" then return native._depositText end
      if layer.id == "bag" and mode == "toss_done" then
        local row = native.list()[native.cursor]
        -- Game path [FireRed/LeafGreen vs Hoenn]: toss receipts have different extracted text symbols and must use the active ROM table.
        return row and RomText.box(self.adapter.hoenn
          and "gText_ThrewAwayVar2Var1s" or "gText_ThrewAwayStrVar2StrVar1s",
          { stringVars = { self.adapter.Items.displayName(row.id), tostring(native.tossQty) } })
      end
    end
    local notice = noticeText()
    if notice then
      local noticeMode = mode
      local function ready()
        return not native._hpAnim and not native._pokedude and not native._statBoost
          and (mode ~= "oak" or native._oakFx and native._oakFx.phase == "text")
      end
      local key = tostring(layer) .. ":" .. mode .. ":" .. tostring(ready()) .. ":" .. notice
      local view = self.noticeView
      if not view or view.nativeKey ~= key then
        view = { screenId = "Gen3Menu", nativeKey = key, notice = notice, canAdvance = ready(),
          title = ({ party = "PARTY", pc_menu = "PC", box_storage = "PC",
            item_pc = "ITEMS", rse_item_storage = "ITEMS", shop = "BUY", move_relearner = "MOVES" })[layer.id] or "BAG", index = 1,
          items = { { label = "CONTINUE" } }, update = function() end,
          valid = function(preview) return self.Stack.top() == layer and native.open
            and nativeMode(layer) == noticeMode
            and (not sale or native._sell == sale and sale.state == saleState)
            and (preview or ready()) and noticeText() == notice end }
        self.noticeView = view
      end
      return view
    end
  end
  function UI:menuModel(layer, projection, battle)
    local native, mode, sale = projection.native, projection.mode, projection.sale
    if sale then
      return self:saleMenu(layer, projection, battle)
    elseif layer.id == "box_storage" then
      return self:storageMenu(layer, projection, battle)
    elseif layer.id == "shop" then
      return self:shopMenu(layer, projection, battle)
    elseif layer.id == "save" and (mode == "confirm" or mode == "overwrite") then
      return self:saveMenu(layer, projection, battle)
    elseif layer.id == "pc_menu" then
      return self:pcMenu(layer, projection, battle)
    elseif layer.id == "item_pc" or layer.id == "rse_item_storage" then
      return self:itemStorageMenu(layer, projection, battle)
    elseif layer.id == "move_relearner" then
      return self:relearnerMenu(layer, projection, battle)
    elseif layer.id == "summary" and mode == "select_move" then
      return self:forgetMenu(layer, projection, battle)
    elseif (layer.id == "bag" or layer.id == "berry_pouch") and
            (mode == "toss" or mode == "toss_select" or mode == "deposit" or mode == "toss_confirm") then
      return self:itemQuantityMenu(layer, projection, battle)
    elseif layer.id == "start" then
      return self:startMenu(layer, projection, battle)
    elseif layer.id == "party" then
      return self:partyMenu(layer, projection, battle)
    elseif (layer.id == "tm_case" or layer.id == "berry_pouch")
            and not native._fromBerryCrush then
      return self:subcontainerMenu(layer, projection, battle)
    elseif layer.id == "bag" then
      return self:bagMenu(layer, projection, battle)
    end
  end
  function UI:menu(layer, battle)
    local native = layer.mod
    local mode = nativeMode(layer)
    local sale = mode == "sell" and native._sell
    local saleState = sale and sale.state
    -- Game path [Ruby/Sapphire]: summary detail phases use _state and a zero-based _selected cursor rather than the shared mode field.
    local rsSummaryState = self.adapter.rs and layer.id == "summary" and native._state
    local RomText = require("src.core.game3.rom_text")
    local projection = { native = native, mode = mode, sale = sale, saleState = saleState,
      rsSummaryState = rsSummaryState, RomText = RomText, pocket = false, partyLayout = false }
    local notice = self:notice(layer, projection)
    if notice then return notice end
    if not self:menuModel(layer, projection, battle) then return nil end
    local itemActionId, itemActionCount, actionOrder
    if projection.items and mode == "action" and (layer.id == "bag" or layer.id == "tm_case" or layer.id == "berry_pouch") then
      local row = native.list()[native.cursor]
      itemActionId = row and self.adapter.Items.toNumericId(row.id)
      if not itemActionId then return nil end
      itemActionCount, projection.title = row.qty, self.adapter.Items.displayName(itemActionId)
      if layer.id == "bag" then actionOrder = table.concat(native.ACTIONS, "\31") end
      -- Game path [Emerald]: the native action grid must exist before exposing its touch projection; RS initializes its own grid.
      if layer.id == "bag" and self.adapter.hoenn and not self.adapter.rs
          and not require("src.ui.game3.rse.bag_menu")._st.grid then return nil end
    end
    if projection.quantity then projection.items, projection.field = { { label = "CONFIRM" } }, nil end
    if not projection.items or #projection.items == 0 or not projection.quantity and type((sale or native)[projection.field]) ~= "number" then return nil end
    local yesNoCallback = mode == "yesno" and (native._yesNoCallback or native._yesNoCb)
    local yesNoPrompt = mode == "yesno" and (native._yesNoPrompt or native.prompt)
    local key = tostring(layer) .. ":" .. tostring(mode) .. ":" .. tostring(native.pocketIdx)
      .. ":" .. tostring(native.holdingMon)
      .. ":" .. tostring(saleState) .. ":" .. tostring(itemActionId) .. ":" .. tostring(actionOrder)
      .. ":" .. tostring(native._forgetMoves) .. ":" .. tostring(native._forgetCallback)
      .. ":" .. tostring(yesNoCallback) .. ":" .. tostring(yesNoPrompt)
      .. ":" .. tostring(native._hmNotice) .. ":" .. tostring(native._confirmExit)
      .. ":" .. tostring(rsSummaryState)
      .. ":" .. tostring(layer.id == "box_storage" and native._session.storage.currentBox)
      .. ":" .. tostring(projection.relearnKey) .. ":" .. tostring(projection.relearnMon) .. ":" .. tostring(projection.relearnFirst)
    local learningPrompt = (layer.id == "party" or layer.id == "move_relearner") and mode == "yesno"
      and self:learningPrompt() or nil
    local view = self.view
    if not view or view.nativeKey ~= key then
      local owner = self
      view = { screenId = "Gen3Menu", nativeKey = key, native = native, update = function() end }
      local pocketIdx = native.pocketIdx
      local holding = native.holdingMon
      local storageBox = layer.id == "box_storage" and native._session.storage.currentBox
      local hmNotice, confirmExit = native._hmNotice, native._confirmExit
      local forgetMoves, forgetCallback, forgetMon = native._forgetMoves, native._forgetCallback,
        projection.moveSelection and not projection.relearnMoves and native._party[native.cursor or native._cursor]
      function view.valid(preview)
        return owner.Stack.top() == layer and native.open == true
          and nativeMode(layer) == mode and native.pocketIdx == pocketIdx
          and (not rsSummaryState or native._state == rsSummaryState)
          and (not itemActionId or native.list()[native.cursor]
            and owner.adapter.Items.toNumericId(native.list()[native.cursor].id) == itemActionId)
          and (not actionOrder or table.concat(native.ACTIONS, "\31") == actionOrder)
          and native.holdingMon == holding
          and (not storageBox or mode == "pick_box" or native._session.storage.currentBox == storageBox)
          and native._forgetMoves == forgetMoves and native._forgetCallback == forgetCallback
          and (not forgetMon or native._party[native.cursor or native._cursor] == forgetMon)
          and (not projection.relearnMoves or native._mon == projection.relearnMon and table.concat(native.moves(), "\31") == projection.relearnKey
            and owner.movePage.window(#native.moves(), native.cursor) == projection.relearnFirst)
          and native._hmNotice == hmNotice and native._confirmExit == confirmExit
          and (mode ~= "yesno" or (native._yesNoCallback or native._yesNoCb) == yesNoCallback
            and (native._yesNoPrompt or native.prompt) == yesNoPrompt)
          and (not learningPrompt or learningPrompt.valid())
          and (not sale or native._sell == sale and sale.state == saleState)
          and (layer.id ~= "box_storage" or not require("src.ui.game3.release_seq").isActive())
          and (preview or not native._hpAnim and not native._pokedude and not native._statBoost)
          and (preview or not owner.Message.isOpen() and not owner.Choice.active)
          and (preview or not native._fx and not (native._slide and native._slide.active))
          and (preview or not native._fading)
          and (preview or not native.isPresentationBusy or not native.isPresentationBusy())
          -- Game path [Ruby/Sapphire]: the native party policy must permit input; a visible menu can still be in a locked presentation phase.
          and (preview or layer.id ~= "party" or not owner.adapter.rs
            or owner.adapter.profile.ui.party.inputAllowed(native))
          and (preview or rsSummaryState and not native._fade and not native._pageTask and not native._reload
            and native._selectSetup == nil and (native._noticeDelay or 0) == 0
            or not rsSummaryState and not native._switch and not native._exit and not native._open)
      end
      setmetatable(view, {
        __index = function(t, k)
          if k ~= "index" then return nil end
          if projection.quantity then return 1 end
          if sale then return sale[projection.field] end
          if layer.id == "box_storage" and mode == "pick_box" then return native._session.storage.currentBox end
          if projection.field == "row" then return native.scroll + native.row + 1 end
          local value = native[projection.field]
          if rsSummaryState and projection.field == "_selected" then value = value + 1 end
          if not t.nativeSlots then return value end
          for i, slot in ipairs(t.nativeSlots) do if slot == value then return i end end
        end,
        __newindex = function(t, k, v)
          if k == "index" then
            if t.valid() and projection.field then
              if sale then sale[projection.field] = v
              elseif layer.id == "box_storage" and mode == "pick_box" then native._session.storage.currentBox = v
              elseif projection.field == "row" then
                local visible = (layer.id == "shop" or layer.id == "rse_item_storage") and 8 or 6
                native.scroll = math.max(0, math.min(v - 1, #t.items - visible))
                native.row = v - 1 - native.scroll
              else
                if rsSummaryState == "notice" then
                  native.handleInput({ wasPressed = function(_, key) return key == "down" end })
                end
                native[projection.field] = t.nativeSlots and t.nativeSlots[v] or v
                if rsSummaryState and projection.field == "_selected" then native[projection.field] = native[projection.field] - 1 end
                if projection.relearnMoves then native.scroll = math.max(0, v - 1) end
                if layer.id == "bag" and mode == "action" then owner:selectBagAction(native, native[projection.field]) end
              end
            end
          else rawset(t, k, v) end
        end,
      })
      self.view = view
    end
    view.items, view.nativeSlots, view.title, view.nativePocket = projection.items, projection.slots, projection.title, projection.pocket
    view.bagContainer, view.itemActionId, view.itemActionCount = layer.id, itemActionId, itemActionCount
    view.bagList = not projection.quantity and mode == "list" and not native._sellMode
      and (layer.id == "bag" or layer.id == "berry_pouch" or layer.id == "tm_case")
      and not native._fromBerryCrush and not native.holdingMon
      and native._location ~= "shop" and native._location ~= "itempc"
      and native._location ~= "berry_tree" and native._location ~= "blender"
    if projection.quantity and projection.quantity.itemId then projection.quantity.itemSprite = self.adapter:itemIcon(projection.quantity.itemId) end
    view.moveSelection = projection.moveSelection
    if projection.moveSelection then projection.moveSelection.valid, projection.moveSelection.message = view.valid, projection.prompt end
    view.quantity = projection.quantity
    view.prompt = projection.prompt
    view.learningPrompt = learningPrompt
    if view.learningPrompt then view.title = "NEW MOVE" end
    view.nativeGrid, view.boxParty = projection.grid, projection.boxParty
    view.emptyTargets = projection.boxParty and native.holdingMon ~= nil
    view.partyActions = layer.id == "party" and (native.mode == "action" or native.mode == "item_action")
      and #projection.items <= 3 and self.adapter:mon(native._party and native._party[native.cursor]) or nil
    if layer.id == "box_storage" and mode == "action_menu" then
      view.partyActions = self.adapter:mon(native._actionTarget and native._actionTarget.mon)
    end
    view.fixedLayout, view.party = projection.grid or projection.moveSelection ~= nil or itemActionId ~= nil or projection.prompt ~= nil or projection.partyLayout or view.partyActions ~= nil, projection.partyLayout and native or nil
    -- Every projection (including upper-screen ownership checks) retains the
    -- exact same draw/hit geometry; never leave a cached view with fresh bare rows.
    if not projection.prompt or projection.moveSelection then view.choiceState, view.touchWindow = nil, nil end
    if view.learningPrompt then
      self.movePage.promptLayout(projection.items)
    elseif projection.moveSelection then
      if projection.moveSelection.catalogue then
        local first, count = self.movePage.listLayout(projection.items, native.cursor)
        view.touchWindow = { first = first, count = count }
      else self.movePage.layout(projection.items, projection.slots) end
    elseif projection.prompt then
      view.choiceState = view.choiceState or { page = 1 }
      local names = {}
      for index, item in ipairs(projection.items) do names[index] = item.label end
      local model = self.choicePage.model(view.choiceState, names, nil, view.index)
      view.touchWindow = { first = model.first, count = #model.entries }
      for _, entry in ipairs(model.entries) do
        projection.items[entry.index].rect = { entry.x, entry.y, entry.w, entry.h }
      end
    elseif itemActionId then
      self.itemPage.layout(projection.items)
    elseif projection.partyLayout then
      for slot, item in ipairs(projection.items) do
        item.rect = { self.layout:partySelectionRect(slot, #projection.items - 1, true) }
      end
    elseif view.partyActions then
      self.storagePage.actions(self.layout, projection.items)
    end
    return view
  end
  function UI:list(battle)
    self:pumpPokeblockSelection()
    if self.Stats.isOpen() then return self:stats() end
    if self.Choice.active and self.Choice.options then return self:choice() end
    if self.Message.isOpen() then return nil end
    local layer = self.Stack.top()
    if not layer and battle and battle.prompt == "target" then return self:target(battle) end
    if layer and layer.id == "naming" then return self:naming(layer) end
    if layer and layer.id == "rse_pokeblock_case" then return self:pokeblocks(layer) end
    if layer and layer.id == "rse_use_pokeblock" then return self:usePokeblock(layer) end
    if layer and (layer.id == "rse_pokenav" or layer.id == "rs_pokenav") then return self:pokenav(layer) end
    if layer and layer.id == "box_storage" then
      local release = self:release(layer)
      if release then return release end
    end
    if not layer or not layer.mod or layer.mod.open ~= true then return nil end
    -- Game path [Ruby/Sapphire/Emerald]: contest-summary detail input stays native; RS and Emerald expose different page readers.
    if layer.id == "summary" and nativeMode(layer) ~= "select_move" and self.adapter.hoenn
        and (self.adapter.rs and layer.mod._page == 3
          or not self.adapter.rs and require("src.ui.game3.rse.summary_menu").page(layer.mod) == 3) then return nil end
    return self:menu(layer, battle)
  end
end
