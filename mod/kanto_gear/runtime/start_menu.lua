return function(
  RADAR_FRAMES, THEME, assist, battleChoice, button, centered,
  compat, displayRuntime, drawSprite, header, hgssRuntime, pcList,
  pcListKind, render, screenById, session
)
  function displayRuntime.advanceExplorerScan(now)
    local explorer = displayRuntime.explorer
    if not explorer.scanFrame or explorer.scanFrame >= RADAR_FRAMES then return end
    local frame = not displayRuntime.motionEnabled() and RADAR_FRAMES or math.min(RADAR_FRAMES,
      math.floor(math.max(0, now - explorer.scanStarted) / 0.05))
    if frame == explorer.scanFrame then return end
    explorer.scanFrame, session.dirty = frame, true
    -- Never deliver an old confirmation after a pause or a stalled frame.
    if frame == RADAR_FRAMES and now - explorer.scanStarted <= 1.3 then
      displayRuntime.finishScanFeedback()
    end
  end

  -- Game path [Gen 1/2/3]: recent-item shortcuts must match the native pocket/container, including FRLGs separate TM Case and Berry Pouch.
  function displayRuntime.decorateBagList(top)
    if not top then return end
    top.recentBag, top.itemModel = nil, nil
    if top.itemActionId then
      local detail = displayRuntime.bagItem(top.itemActionId, top.itemActionCount, top.title)
      if displayRuntime.gen3 then detail.itemSprite = displayRuntime.gen3:itemIcon(top.itemActionId) end
      top.itemModel = displayRuntime.ItemPage.model(detail, top.items,
        displayRuntime.StartMenu.cursor(top) ~= nil, nil, function(label)
          if label == "REGISTER" and displayRuntime.gen3
              and displayRuntime.gen3.session.registeredItem == top.itemActionId then label = "UNREGISTER" end
          return THEME:translate(label)
        end)
      top.fixedLayout = true
      displayRuntime.ItemPage.layout(top.items)
    end
    local recent = top.bagList and displayRuntime.lastBagItem()
    if recent then
      if displayRuntime.gen3 and top.bagContainer == "bag" then
        local def = session.game.data.items[recent.id] or {}
        for _, pocket in ipairs(displayRuntime.gen3.Items.BAG_POCKET_ORDER) do
          if def.nativePocket == pocket then top.recentBag = recent break end
        end
      elseif compat.isGen2() then
        local def = session.game.data.items[recent.id] or {}
        for _, pocket in ipairs(displayRuntime.bagPockets) do
          if (def.pocket or "ITEM") == pocket.id then top.recentBag = recent break end
        end
      else
        for _, row in ipairs(top.items) do
          if row.itemId == recent.id then top.recentBag = recent break end
        end
      end
    end
    return top
  end

  function displayRuntime.startMenu()
    local nativeTop = displayRuntime.gen3Ui and displayRuntime.gen3Ui.Stack.top()
      or session.game and session.game.stack and session.game.stack:top()
    displayRuntime.nativeDexView = THEME.style == "hgss" and displayRuntime.NativeDex.project(nativeTop, session.game,
      displayRuntime.gen3Ui and 3 or compat.isGen2() and 2 or 1, displayRuntime.nativeDexView)
    if displayRuntime.nativeDexView then
      local view = displayRuntime.nativeDexView
      view.dexModel = displayRuntime.NativeDex.model(view, displayRuntime.PokedexPage,
        displayRuntime.pokedexPokemon, function(row, x, y, size)
          if row.revealed == false then return false end
          local native, portrait = view.owner, { spriteKind = "dex" }
          if view.dex.portrait then
            portrait.presentationSprite, portrait.presentationTrueColor = view.dex.portrait(row.species, row.letter)
            if portrait.presentationTrueColor == nil then portrait.presentationTrueColor = true end
            if row.letter and not portrait.presentationSprite then return false end
          elseif native.picFor then
            portrait.presentationSprite, portrait.presentationTrueColor = native:picFor(row.species)
          elseif native.species == row.species and native.sprite then
            portrait.presentationSprite, portrait.presentationTrueColor = native.sprite, native.spriteTrueColor == true
          end
          return drawSprite(row.species, "front", x, y, size, size, nil, portrait, true)
        end, function(value) return THEME:pokedexDescriptionLines(value) end)
      if view.dexModel then view.items[1].right = displayRuntime.NativeDex.redrawKey(view.dexModel)
      elseif view.dex.uiLabels then
        for _, row in ipairs(view.items) do row.label = THEME:translate(row.label) end
      end
      return view
    end
    displayRuntime.nativeTrainerView = THEME.style == "hgss" and displayRuntime.TrainerPage.project(nativeTop, session.game,
      displayRuntime.gen3Ui and 3 or compat.isGen2() and 2 or 1, displayRuntime.nativeTrainerView)
    if displayRuntime.nativeTrainerView then
      local view = displayRuntime.nativeTrainerView
      view.trainerModel = displayRuntime.trainerModel(view.trainer)
      view.items[1].right = displayRuntime.TrainerPage.key(view.trainerModel)
      return view
    end
    displayRuntime.nativeOptionsView = THEME.style == "hgss" and displayRuntime.NativeOptions.project(nativeTop, session.game,
      displayRuntime.gen3Ui and 3 or compat.isGen2() and 2 or 1, displayRuntime.nativeOptionsView)
    if displayRuntime.nativeOptionsView then return displayRuntime.nativeOptionsView end
    displayRuntime.nativePokegearView = THEME.style == "hgss" and THEME.hgss.pokegearScreen
      and not displayRuntime.gen3Ui and compat.isGen2()
      and displayRuntime.PokegearPage.project(nativeTop, session.game, displayRuntime.nativePokegearView) or nil
    if displayRuntime.nativePokegearView then return displayRuntime.nativePokegearView end
    if displayRuntime.gen3Ui then
      return displayRuntime.decorateBagList(displayRuntime.gen3Ui:list(session.battle))
    end
    local top = session.game and session.game.stack and session.game.stack:top()
    -- Game path [Gen 1/2]: Gen 2 embeds qtyState in Pack/Item PC; Gen 1 can push a standalone QuantityBox.
    local quantity = top and (top.screenId == "Gen2PackMenu"
      or top.screenId == "Gen2ItemPcMenu" or compat.isGen2()
        and getmetatable(top) == require("src.ui.gen2.PackMenu")) and top.qtyState
    if not quantity and top and getmetatable(top) == require("src.ui.QuantityBox") then quantity = top end
    if quantity and type(quantity.qty) == "number" and type(quantity.max) == "number" then
      local view = displayRuntime.legacyQuantityView
      if not view or view.owner ~= top or view.state ~= quantity then
        view = { screenId = "CompanionMenu", owner = top, state = quantity,
          nativeKey = tostring(top) .. ":quantity:" .. tostring(quantity),
          title = displayRuntime.LegacyShop.quantityTitle(session.game) or "QUANTITY",
          index = 1, items = { { label = "CONFIRM" } }, update = function() end,
          valid = function() return session.game.stack:top() == top
            and (quantity == top or top.qtyState == quantity) end }
        displayRuntime.legacyQuantityView = view
      end
      local parent = screenById("BagMenu") or pcList()
      if not parent then
        for index = #(session.game.stack.states or {}), 1, -1 do
          local candidate = session.game.stack.states[index]
          if (candidate.kind == "bag" or candidate.itemBox
              and getmetatable(candidate) == require("src.ui.ListMenu")) and type(candidate.items) == "table"
              and type(candidate.index) == "number" then parent = candidate break end
        end
      end
      local row = quantity.row or displayRuntime.LegacyPC.quantityRow(top)
        or top.rows and top.rows[top.listIndex]
        or parent and parent.items and parent.items[parent.index]
      view.quantity = { label = row and (row.name or row.label),
        qty = quantity.qty, max = quantity.max, wrap = true,
        total = quantity.unitPrice and quantity.qty * quantity.unitPrice }
      return view
    end
    displayRuntime.legacyQuantityView = nil
    displayRuntime.legacyPartyView = not session.battle and displayRuntime.LegacyParty.project(top, session.game, compat.isGen2(),
      displayRuntime.StoragePage, THEME.hgss, displayRuntime.legacyPartyView) or nil
    if displayRuntime.legacyPartyView then return displayRuntime.legacyPartyView end
    displayRuntime.legacyBagView = not session.battle and displayRuntime.LegacyBag.project(top, session.game, compat.isGen2(),
      displayRuntime.legacyBagView) or nil
    if displayRuntime.legacyBagView then return displayRuntime.decorateBagList(displayRuntime.legacyBagView) end
    displayRuntime.legacyShopView = displayRuntime.LegacyShop.project(top, session.game,
      function(label) return THEME:translate(label) end, displayRuntime.legacyShopView)
    if displayRuntime.legacyShopView then return displayRuntime.legacyShopView end
    displayRuntime.legacyPcView = displayRuntime.LegacyPC.project(top,
      function(owner) return session.game.stack:top() == owner end,
      function(label) return THEME:translate(label) end, displayRuntime.legacyPcView)
    if displayRuntime.legacyPcView then return displayRuntime.legacyPcView end
    displayRuntime.legacyStorageView = displayRuntime.LegacyStorage.project(top, session.game,
      displayRuntime.StoragePage, THEME.hgss, displayRuntime.legacyStorageView)
    if displayRuntime.legacyStorageView then return displayRuntime.legacyStorageView end
    return displayRuntime.StartMenu.cursor(top) and top or nil
  end

  function displayRuntime.startMenuModel(top)
    local model = displayRuntime.StartMenu.model(top)
    if model then
      local hints, odds = assist("type_hints"), assist("catch_odds")
      for _, entry in ipairs(model.entries) do
        if not hints then entry.effectiveness = nil end
        if not odds then entry.catchChance = nil end
      end
    end
    return model
  end

  function displayRuntime.startMenuPartyViews(top)
    local views, native = {}, top.party
    local rows = top.notice and top.partyMons or top.items
    for slot, item in ipairs(rows or {}) do
      local source = top.notice and item or item.mon
      if source then
        local view = displayRuntime.partyView(source)
        view.species, view.source = source.species, source
        local anim, heal = native._hpAnim, native.heal
        local shown = native.shownHpFor and native:shownHpFor(slot, source)
          or heal and heal.mon == source and heal.shown
          or anim and anim.slot == slot and anim.current
        if shown then view.hp = math.floor(shown + 0.5); view.hpText = view.hp .. "/" .. view.maxHp end
        views[slot] = view
      end
    end
    return views
  end

  function displayRuntime.drawStartMenu(top)
    if session.battle and top.notice then
      displayRuntime.drawOwnedBattleMessage(top.notice, top.canAdvance)
      return
    end
    header(THEME:translate(top.title or "CHOOSE ACTION"), not top.namingModel and not top.learningPrompt and not top.nativeStats and top.back ~= false,
      top.nativePocket or top.trainer and top.trainer.pages > 1 or top.dexModel and top.dexModel.canCycle)
    local model = displayRuntime.startMenuModel(top)
    if session.battle and assist("catch_odds") then
      for _, entry in ipairs(model.entries) do
        local chance = THEME.hgss:battleCatchLabel(entry.catchChance)
        if chance then entry.right = (entry.right or "") .. " " .. chance end
      end
    end
    if THEME.style == "hgss" then
      render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      if top.dexModel then
        THEME.hgss:pokedex(top.dexModel)
      elseif top.trainerModel then
        THEME.hgss:trainer(top.trainerModel)
      elseif top.pokegearModel then
        THEME.hgss:pokegearScreen(top.pokegearModel, displayRuntime.PokegearPage)
      elseif top.optionsModel then
        displayRuntime.NativeOptions.draw(THEME.hgss, top.optionsModel)
      elseif top.nativeStats then
        local result = top.levelStats
        THEME.hgss:levelUp(displayRuntime.levelUpModel(result.mon, result.gain, result.stats, result.source))
      elseif top.namingModel and not top.notice then
        THEME.hgss:naming(top.namingModel)
      elseif top.learningPrompt then
        local labels = {}
        for index, row in ipairs(top.items) do labels[index] = THEME:menuActionLabel(row.label) end
        displayRuntime.MovePage.drawPrompt(THEME.hgss,
          displayRuntime.learningPromptModel(top.learningPrompt, top, labels, top.prompt))
      elseif top.moveSelection then
        local selection = displayRuntime.moveSelectionModel(top.moveSelection)
        selection.selection = top.nativeSlots and top.nativeSlots[top.index] or top.index
        displayRuntime.MovePage.draw(THEME.hgss, selection)
      elseif top.choiceState then
        local labels = {}
        for index, item in ipairs(top.items) do labels[index] = THEME:menuActionLabel(item.label) end
        THEME.hgss:choiceScreen(displayRuntime.choiceModel(top, labels, top.prompt))
      elseif top.quantity then
        THEME.hgss:pcQuantity(top.quantity)
      elseif top.itemModel then
        THEME.hgss:bagDetail(top.itemModel)
      elseif top.notice then
        if top.party then
          THEME.hgss:partyBackdrop()
          THEME.hgss:partySelection(displayRuntime.startMenuPartyViews(top), hgssRuntime.summaryPortrait)
        elseif session.battle then
          local mon = hgssRuntime.battleMon()
          local playerTeam, enemyTeam = hgssRuntime.battleTeams()
          THEME.hgss:battleRoot(mon, hgssRuntime.battlePortrait, playerTeam, enemyTeam)
        end
        THEME.hgss:systemOverlay(0.55)
      elseif top.boxParty then
        local views = {}
        for slot, item in ipairs(top.items) do
          if item.mon then
            local view = displayRuntime.partyView(item.mon)
            view.species, view.source = item.mon.species, item.mon
            views[slot] = view
          end
        end
        THEME.hgss:partyBackdrop()
        THEME.hgss:partySelection(views, hgssRuntime.summaryPortrait, top.emptyTargets)
      elseif top.nativeGrid then
        model.name = top.name
        for _, e in ipairs(model.entries) do
          if not top.name then e.label = THEME:menuActionLabel(e.label) end
        end
        THEME.hgss:nativeGrid(model, function(mon, x, y, size)
          if not displayRuntime.gen3 then return compat.drawPokemonIcon(mon, x, y, size) end
          local icon = displayRuntime.gen3.Pokemon.monIcon(mon)
          if icon and icon.image then
            local quad = icon.quads and icon.quads[0]
            render.G.setColor(1, 1, 1, 1)
            if quad then render.G.draw(icon.image, quad, x, y, 0, size / 32, size / 32)
            else render.G.draw(icon.image, x, y, 0, size / 32, size / 32) end
          end
        end)
      elseif top.partyActions then
        local mon = displayRuntime.partyView(top.partyActions)
        mon.species, mon.source = top.partyActions.species, top.partyActions
        THEME.hgss:partyBackdrop()
        THEME.hgss:partyCard(mon, 64, THEME.hgss:partyActionHeroY(#top.items), true, false,
          hgssRuntime.summaryPortrait, false, nil, false)
        for slot, entry in ipairs(model.entries) do
          local label = THEME:menuActionLabel(({ SHIFT = "SWITCH", SUMMARY = "STATS" })[entry.label]
            or entry.label)
          local kind = (entry.label == "SUMMARY" or entry.label == "STATS") and "stats"
            or entry.label == "RELEASE" and "release"
            or (entry.label == "CANCEL" or entry.label == "EXIT") and "cancel" or "switch"
          THEME.hgss:actionRow(entry.x, entry.y, entry.w, entry.h, label, kind, 0,
            THEME.hgss.nativeFocus and entry.selected)
        end
      elseif top.pokenav and THEME.hgss.pokenavMenu then
        THEME.hgss:pokenavMenu(model, top.pokenavHelp, top.pokenavRs)
      elseif top.party then
        THEME.hgss:partyBackdrop()
        THEME.hgss:partySelection(displayRuntime.startMenuPartyViews(top), hgssRuntime.summaryPortrait,
          nil, top.index)
      else
        if top.recentBag then THEME.hgss:recentBagItem(top.recentBag, 33) end
        for _, entry in ipairs(model.entries) do
          if entry.itemId and displayRuntime.gen3 then entry.itemSprite = displayRuntime.gen3:itemIcon(entry.itemId) end
        end
        THEME.hgss:startMenu(model)
        if top.prompt then
          local tall = #top.items <= 2
          local lines = THEME:wrapText(displayRuntime.gen3:plainText(top.prompt), 204, tall and 5 or 3,
            function(value) return THEME.hgss:labelWidth(value) end)
          THEME.hgss:panel(7, 34, 226, tall and 76 or 46, false)
          for i, line in ipairs(lines) do
            THEME.hgss:partyInfo(line, 18, (tall and 72 or 57) - math.floor((#lines * 12 - 3) / 2) + (i - 1) * 12,
              THEME.hgss.colors.ink, 204, "center")
          end
        end
      end
      render.G.pop()
    else
      if top.nativeStats then
        local native = top.nativeStats
        local fields = { { "MAX HP", "maxHp" }, { "ATTACK", "atk" }, { "DEFENSE", "def" },
          { "SP. ATK", "spa" }, { "SP. DEF", "spd" }, { "SPEED", "spe" } }
        for i, f in ipairs(fields) do
          local value, old = native._newStats[f[2]] or 0, native._oldStats[f[2]] or 0
          centered(THEME:translate(f[1]) .. " " .. value
            .. (native._page == 1 and string.format(" (%+d)", value - old) or ""), 30 + (i - 1) * 13, render.INK)
        end
        button(20, 113, 120, 24, THEME:translate("CONTINUE"))
        return
      end
      if top.quantity then
        centered(top.quantity.label, 35, render.INK)
        centered(tostring(top.quantity.qty), 68, render.INK)
        button(7, 61, 42, 28, "-"); button(111, 61, 42, 28, "+")
        button(7, 99, 70, 37, THEME:translate("CONFIRM"))
        button(83, 99, 70, 37, THEME:translate("CANCEL"))
        return
      end
      if top.notice then
        local lines = THEME:wrapText(displayRuntime.gen3:plainText(top.notice), 138, 6)
        for i, line in ipairs(lines) do centered(line, 45 + (i - 1) * 11, render.INK) end
        button(20, 113, 120, 24, THEME:translate("CONTINUE"))
        return
      end
      if top.name then centered(top.name, 29, render.INK) end
      if top.prompt then
        local lines = THEME:wrapText(displayRuntime.gen3:plainText(top.prompt), 138, #top.items <= 2 and 4 or 2)
        for i, line in ipairs(lines) do centered(line, 25 + (i - 1) * 10, render.INK) end
      end
      for _, entry in ipairs(model.entries) do
        button(entry.x / 1.5, entry.y / 1.5, entry.w / 1.5, entry.h / 1.5,
          entry.targetSide and (entry.label .. " / " .. THEME:translate(entry.right)
            .. (entry.effectiveness ~= nil and " / " .. THEME.hgss:battleEffectLabel(entry) or "")) or entry.label,
          entry.selected, not entry.disabled)
        if entry.rawMon and entry.label == "" then
          local icon = displayRuntime.gen3.Pokemon.monIcon(entry.rawMon)
          if icon and icon.image and icon.quads and icon.quads[0] then
            local size = math.min(entry.h - 2, 32)
            render.G.setColor(1, 1, 1, 1)
            render.G.draw(icon.image, icon.quads[0], (entry.x + math.floor((entry.w - size) / 2)) / 1.5,
              (entry.y + math.floor((entry.h - size) / 2)) / 1.5, 0, size / 48, size / 48)
          end
        end
      end
      if model.fixedLayout or model.total <= 5 then return end
      button(7 / 1.5, 190 / 1.5, 56 / 1.5, 23 / 1.5, "^", false, model.first > 1)
      button(177 / 1.5, 190 / 1.5, 56 / 1.5, 23 / 1.5, "v", false, model.last < model.total)
      centered(model.first .. "-" .. model.last .. "/" .. model.total, 131, render.DARK)
    end
  end

  local function dialogueChoice()
    local top = session.game and session.game.stack and session.game.stack:top()
    if not top then return end
    local field
    top, field = compat.choiceView(top)
    if type(top) ~= "table" then return end
    if field ~= "index" and field ~= "script" and field ~= "cursor" then
      if type(top[field]) == "number" then
        return top, { THEME:translate("YES"), THEME:translate("NO") }, field
      end
      return
    end
    if battleChoice(top) then
      return top, { THEME:translate("YES"), THEME:translate("NO") }, field
    end
    -- Game path [Gen 2]: elevator rows contain floor IDs whose native floorName reader supplies labels, not ordinary item text.
    if top.screenId == "Gen2ElevatorMenu" then
      if type(top.floors) ~= "table" or type(top.index) ~= "number" then
        return
      end
      local labels = {}
      for i, row in ipairs(top.floors) do
        if type(row) ~= "table" then return end
        local label
        if type(top.floorName) == "function" then
          local ok
          ok, label = pcall(top.floorName, top.floorNames, row.floorId)
          if not ok then return end
        end
        labels[i] = label or row.label or tostring(row.floorId or i)
      end
      if #labels > 0 then return top, labels, field end
    end
    if type(top.items) == "table" and (field == "script" or field == "cursor"
        or not top.screenId)
        and not pcListKind(top) then
      if field == "script" and (type(top.row) ~= "number"
          or type(top.col) ~= "number" or type(top.cols) ~= "number"
          or top.cols < 1) then return end
      if field ~= "script" and type(top[field]) ~= "number" then return end
      local labels = {}
      for i, item in ipairs(top.items) do
        labels[i] = type(item) == "table" and (item.label or tostring(i))
          or tostring(item)
      end
      if #labels > 0 then return top, labels, field end
    end
  end

  return dialogueChoice
end
