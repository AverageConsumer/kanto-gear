return function(
  Discovery, THEME, compat, displayRuntime, hgssRuntime, inside,
  mod, refreshTools, screenState, session
)
  function displayRuntime.openHomeApp(id, deviceTarget)
    local home = displayRuntime.home
    if id == "pokegear" or id == "pokenav" then
      local package = displayRuntime.homeCatalog.packages[id]
      if not package.installed or package.available == false
          or not displayRuntime.queueDeviceApp(id, deviceTarget) then return false end
    elseif displayRuntime.deviceApp then
      displayRuntime.closeDeviceApp()
    end
    if displayRuntime.gearModules.specs[id] then
      -- a third-party module: no Gear page of ours; the mod's own surface takes
      -- the Gear's place. The Gear falls back to its home screen first, so
      -- closing the module lands there, wherever it was opened from.
      local opened = displayRuntime.gearModules.open(id)
      if not opened then return false end
      home.editing, home.library, home.addSlot = false, false, nil
      home.swapSource, home.activeApp = nil, nil
      session.page, session.dirty = "HOME", true
      return true
    end
    session.toolArmed = nil
    displayRuntime.clearExplorerSnapshot()
    home.editing, home.library, home.addSlot = false, false, nil
    home.swapSource = nil
    home.activeApp = id
    if id == "store" then
      home.storeView, session.page = "apps", "STORE"
      home.storeDetail, home.storeConfirm, home.storeReceived = nil, nil, nil
      session.dirty = true
      return true
    end
    if id == "settings" then
      displayRuntime.settings.category, displayRuntime.settings.page,
        displayRuntime.settings.confirm = nil, 1, nil
      displayRuntime.settings.option, displayRuntime.settings.direct,
        displayRuntime.settings.choicePage = nil, nil, 1
      displayRuntime.settings.selected = nil
      session.page, session.dirty = "SETTINGS", true
      return true
    end
    local app = displayRuntime.storeById[id]
    local package = displayRuntime.homeCatalog.packages[id]
    if not app or not app.target or not package or not package.installed then
      return false
    end
    if id == "tools" then
      displayRuntime.perf:call("tools", refreshTools)
    elseif id == "pss" then
      displayRuntime.pss.selected, displayRuntime.pss.page = nil, 1
      displayRuntime.pss:open()
    elseif id == "notes" then
      displayRuntime.notes:open()
    elseif id == "daycare" then
      displayRuntime.daycare.view, displayRuntime.daycare.selected = nil, nil
    elseif id == "calendar" then
      local state = displayRuntime.calendar
      state.view, state.day, state.selected, state.page = nil, nil, nil, 1
    elseif id == "achievements" then
      local state = displayRuntime.achievements
      state.view, state.page, state.selected = "goals", 1, nil
    elseif id == "pokedex" then
      displayRuntime.pokedex.view, displayRuntime.pokedex.page = "index", 1
      displayRuntime.pokedex.habitatPage = 1
      displayRuntime.pokedex.movePage = 1
      displayRuntime.pokedex.descriptionPage = 1
      displayRuntime.pokedex.data = nil
    elseif id == "trainer" then
      displayRuntime.trainerPage = 1
    elseif id == "bag" then
      displayRuntime.bag.page, displayRuntime.bag.detail = 1, nil
      displayRuntime.bag.message = nil
    end
    displayRuntime.localSummary = nil
    session.page, session.dirty = app.target, true
    return true
  end
  function displayRuntime.homeTileAt(x, y)
    local tiles = displayRuntime.homePageElements()
    for _, tile in ipairs(tiles) do
      local left, top, width, height = THEME.hgss:homeRect(tile)
      if inside(x, y, left, top, width, height) then return tile end
    end
  end

  -- The item a party Pokemon holds, as the native party screens mark it.
  -- Game path [Gen 2/3]: held items and mail have generation-specific native readers; Gen 1 has neither system.
  function displayRuntime.heldItem(mon)
    if not displayRuntime.gen3 and not compat.isGen2() then return nil end
    local source = type(mon) == "table" and (mon.source or mon) or nil
    local id = source and (source.item or source.heldItem)
    if id == nil or id == 0 or id == "" or id == "NO_ITEM" or id == "NONE" then return nil end
    local name
    if displayRuntime.gen3 then
      local ok, Items = pcall(require, "src.core.game3.items_data")
      name = ok and Items.displayName and Items.displayName(id) or nil
    else
      local def = session.game.data and session.game.data.items and session.game.data.items[id]
      name = def and def.name
    end
    name = tostring(name or id)
    local mail
    if compat.isGen2() then
      local ok, Mail = pcall(require, "src.core.gen2.Mail")
      mail = ok and Mail.monHoldsMail(source) or false
    else
      local ok, Mail = pcall(require, "src.core.game3.mail")
      mail = ok and Mail.isMailItem(id) or false
    end
    return { id = id, name = name, mail = mail }
  end

  -- Rows the party app offers for one Pokemon; drawing and taps share them.
  function displayRuntime.partyActionRows(slot)
    local mon = session.game.save.party and session.game.save.party[slot]
    local rows = { { id = "stats", kind = "stats", label = THEME:translate("STATS") } }
    if mon and #(session.game.save.party or {}) > 1 and mod.world and mod.world.canReorderParty
        and mod.world:canReorderParty() then
      rows[#rows + 1] = { id = "swap", kind = "swap", label = THEME:translate("SWAP") }
    end
    if mon and (compat.isGen2() or displayRuntime.gen3) and not compat.partyEgg(mon) then
      local held = displayRuntime.heldItem(mon)
      rows[#rows + 1] = { id = "item", kind = held and (held.mail and "mail" or "item") or "item_none",
        label = THEME:translate("ITEM"), sub = held and held.name or THEME:translate("NO ITEM"),
        enabled = displayRuntime.canOpenHeldItem() }
    end
    return rows
  end

  function displayRuntime.canOpenHeldItem()
    if session.battle or screenState() ~= "active" then return false end
    if displayRuntime.gen3 then
      local ui = displayRuntime.gen3Ui
      return not (ui.Stack.top() or ui.Message.isOpen() or ui.Choice.active)
    end
    local world = mod.world and mod.world.overworld and mod.world:overworld()
    return world ~= nil and (not world.acceptsMenuInput or world:acceptsMenuInput())
  end

  -- ITEM opens the game's own GIVE / TAKE for that Pokemon; the native menu
  -- (projected on this screen) owns bag choice, swaps, mail and messages.
  -- Game path [Gen 2 vs Gen 3]: Gen 2 opens HeldItemMenu; Gen 3 waits for its Party menu before entering the item action.
  function displayRuntime.openHeldItem(slot)
    local mon = session.game.save.party and session.game.save.party[slot]
    if not mon or compat.partyEgg(mon) or not (compat.isGen2() or displayRuntime.gen3)
        or not displayRuntime.canOpenHeldItem() then return false end
    if displayRuntime.gen3 then
      local session = displayRuntime.gen3.session
      local Party = require("src.ui.game3.screens").get("party", session)
      Party.show(session and session.party, session and (session.move_overlay or session.moveOverlay),
        { session = session })
      Party.cursor = slot
      displayRuntime.pendingPartyItem = { slot = slot, menu = Party, session = session,
        layer = displayRuntime.gen3Ui.Stack.top(), tries = 0 }
      displayRuntime.stepPartyItem()
      return true
    end
    require("src.ui.Screens").push(session.game, "Gen2HeldItemMenu", {
      save = session.game.save, slot = slot,
      onClose = function() session.game.stack:pop() end,
    })
    return true
  end

  -- Gen 3: walk the open party menu to ITEM the way its buttons do, waiting
  -- out opening fades instead of forcing its state.
  -- Game path [Gen 3]: wait for native party opening phases and cancel on changed session/layer/slot instead of forcing state.
  function displayRuntime.stepPartyItem()
    local pending = displayRuntime.pendingPartyItem
    if not pending then return end
    local Party = pending.menu
    pending.tries = pending.tries + 1
    if not displayRuntime.gen3 or displayRuntime.gen3.session ~= pending.session
        or displayRuntime.gen3Ui.Stack.top() ~= pending.layer or Party.cursor ~= pending.slot
        or not Party.isOpen() or pending.tries > 40
        or Party.mode ~= "list" and Party.mode ~= "action" then
      displayRuntime.pendingPartyItem = nil
      return
    end
    local confirm = { wasPressed = function(_, key) return key == "a" end,
      isDown = function() return false end }
    if Party.mode == "list" and Party.cursor == pending.slot then
      Party.handleInput(confirm)
    elseif Party.mode == "action" then
      local found = false
      for index, name in ipairs(Party.ACTIONS or {}) do
        if name == "ITEM" or name == "MAIL" then
          found = true
          Party.actionCursor = index
          Party.handleInput(confirm)
          break
        end
      end
      if not found then displayRuntime.pendingPartyItem = nil end
    end
    session.dirty = true
  end

  -- Game path [Gen 1/2/3]: native Summary constructors differ; local Gear inspection adds contest pages only for Hoenn editions.
  function displayRuntime.openPartySummary(slot)
    local mon = session.game.save.party and session.game.save.party[slot]
    if not mon or compat.summary.details.isEgg(mon) and THEME.style ~= "hgss" then return false end
    session.partyActionSlot, session.partyMoveFrom = nil, nil
    if THEME.style ~= "hgss" then
      if displayRuntime.gen3 then
        require("src.ui.game3.summary_menu").openMenu(displayRuntime.gen3.session.party, slot,
          { session = displayRuntime.gen3.session })
        displayRuntime.gen3.syncScreens()
      elseif compat.isGen2() then
        mod.ui.push(session.game, compat.screenName("summary", true), {
          mon = mon, party = session.game.save.party, index = slot,
          onClose = function() session.game.stack:pop() end,
        })
      else mod.ui.push(session.game, compat.screenName("summary", false), mon) end
      session.dirty = true
      return true
    end
    local state = compat.summary.inspection(mon, session.game, displayRuntime.gen3 and 3
      or compat.isGen2() and 2 or 1, displayRuntime.gen3 and displayRuntime.gen3.hoenn)
    compat.summary.configure(state, Discovery.current())
    state.slot = slot
    displayRuntime.localSummary, session.moveInfo, hgssRuntime.animation, session.dirty = state, nil, nil, true
    return true
  end

end
