return function(
  HEADER, THEME, assist, displayRuntime, mod, session
)
  function displayRuntime.activateStoreEntry(entry)
    if not entry or entry.state == "soon" then return end
    if entry.state == "get" then
      if displayRuntime.setPackageInstalled(entry.id, true) then
        displayRuntime.haptic("confirm")
      end
    elseif displayRuntime.openHomeApp(entry.id) then
      displayRuntime.haptic("open")
    end
  end

  function displayRuntime.tapStore(x, y)
    local home = displayRuntime.home
    if y < 30 and x < 22 then
      if home.storeConfirm then home.storeConfirm = nil
      elseif home.storeReceived then home.storeReceived = nil
      else session.page, home.activeApp = "HOME", nil end
      session.dirty = true
      return
    end
    local view = home.storeReceived and "received" or home.storeView
    local selected, _, _, pages = nil, nil, nil, 1
    if view == "apps" or view == "library" then
      selected, _, _, pages = displayRuntime.storeSelection(view)
    end
    local action, index = THEME.hgss:storeHit(x, y, view,
      { pages = pages, confirm = home.storeConfirm })
    if not action then return end
    if view == "received" then
      local id = home.storeReceived
      home.storeReceived = nil
      if action == "open" and displayRuntime.openHomeApp(id) then
        displayRuntime.haptic("open")
      end
      session.dirty = true
      return
    end
    if home.storeConfirm then
      local id, kind = home.storeConfirm, home.storeConfirmKind
      home.storeConfirm, home.storeConfirmKind = nil, nil
      if action == "yes" then
        if kind == "remove" then
          if displayRuntime.setPackageInstalled(id, false) then displayRuntime.haptic("confirm") end
        elseif displayRuntime.setPackageInstalled(id, true) then
          home.storeReceived = id
          displayRuntime.haptic("confirm")
        end
      end
      session.dirty = true
      return
    end
    if action == "prev" or action == "next" then
      local direction = action == "next" and 1 or -1
      displayRuntime.requestPageMotion(direction)
      displayRuntime.cycleStoreView(direction)
    elseif action == "tab" then
      local target = ({ "apps", "library", "today" })[index]
      if target ~= view then
        local order = { apps = 1, library = 2, today = 3 }
        displayRuntime.requestPageMotion(order[target] > (order[view] or 1) and 1 or -1)
        home.storeView = target
      end
    elseif action == "scroll" then
      displayRuntime.setStorePage(view, index)
    elseif action == "page_prev" or action == "page_next" then
      displayRuntime.cycleStorePage(view, action == "page_next" and 1 or -1)
      home[view == "library" and "storeGearSel" or "storeSel"] = nil
    elseif action == "row" or action == "slot" then
      local _, shown = displayRuntime.storeSelection(view)
      local entry = shown[index]
      if not entry then return end
      home[view == "library" and "storeGearSel" or "storeSel"] = entry.id
      displayRuntime.haptic()
    elseif view == "apps" and action == "action" and selected then
      if selected.state == "get" then
        home.storeConfirm, home.storeConfirmKind = selected.id, "install"
      elseif selected.state == "open" and displayRuntime.openHomeApp(selected.id) then
        displayRuntime.haptic("open")
      end
    elseif view == "library" and selected then
      if action == "open" then
        if displayRuntime.openHomeApp(selected.id) then displayRuntime.haptic("open") end
      elseif action == "home" and not displayRuntime.storeOnHome(selected.id) then
        local surface, homePage, column, row = displayRuntime.storeHomeSpot(selected.id)
        if surface and displayRuntime.Home.place(displayRuntime.home.layout,
            displayRuntime.homeCatalog, surface, homePage, column, row) then
          displayRuntime.saveHome()
          displayRuntime.haptic("confirm")
        end
      elseif action == "remove" and selected.removable then
        home.storeConfirm, home.storeConfirmKind = selected.id, "remove"
      end
    elseif view == "today" and action == "note" then
      local featured, pick, second = displayRuntime.storeNewsEntries()
      local entry = ({ featured, pick, second })[index]
      if entry then
        displayRuntime.requestPageMotion(-1)
        displayRuntime.storeShow(entry.id)
      end
    end
    session.dirty = true
  end

  function displayRuntime.tapPokedex(x, y)
    local state, model = displayRuntime.pokedex, displayRuntime.pokedexModel()
    local action, index = displayRuntime.PokedexPage.hit(model, x * THEME.hgssScale, y * THEME.hgssScale)
    if action == "back" then
      if state.view == "index" then session.page, displayRuntime.home.activeApp = "HOME", nil
      elseif state.view == "profile" then state.view = "index"
      else state.view = "profile" end
      session.dirty = true
    elseif action == "description_prev" or action == "description_next" then
      if displayRuntime.PokedexPage.cycleDescription(state, model, action == "description_next" and 1 or -1) then session.dirty = true end
    elseif action == "prev" or action == "next" then
      displayRuntime.cyclePokedex(action == "next" and 1 or -1)
    elseif action == "species" then
      displayRuntime.selectPokedexSpecies(model.entries[index].index)
    elseif action == "stats" or action == "habitat" or action == "moves" or action == "evolutions" then
      local permission = ({ stats = "dex_stats", habitat = "habitats", moves = "dex_moves", evolutions = "dex_evolutions" })[action]
      if assist(permission) then state.view, state.habitatPage, state.movePage, state.evolutionPage, session.dirty = action, 1, 1, 1, true end
    end
  end

  function displayRuntime.tapBag(x, y)
    local state = displayRuntime.bag
    if y < HEADER and x < 22 then
      if state.detail then
        state.detail, state.message = nil, nil
      else
        session.page, displayRuntime.home.activeApp = "HOME", nil
      end
      session.dirty = true
      return
    end
    local model = displayRuntime.bagModel()
    local action, value = THEME.hgss:bagHit(
      x * THEME.hgssScale, y * THEME.hgssScale, model)
    if action == "pocket" then
      displayRuntime.cycleBagPocket(value)
    elseif action == "page" then
      displayRuntime.cycleBagPage(value)
    elseif action == "item" and model.entries[value] then
      state.detail, state.message = model.entries[value].id, nil
      session.dirty = true
    elseif action == "recent" and model.recent then
      local canUse = false
      for _, row in ipairs(displayRuntime.bagActions(model.recent.id)) do
        if row.id == "use" and row.enabled ~= false then canUse = true break end
      end
      if canUse then displayRuntime.useBagItem(model.recent.id)
      else state.detail, state.message, session.dirty = model.recent.id, nil, true end
    elseif action == "action" and model.detail and model.actions[value] then
      displayRuntime.performBagAction(model.detail.id, model.actions[value].id)
    end
  end

  function displayRuntime.tapSettings(x, y)
    local state = displayRuntime.settings
    local model = displayRuntime.settingsModel()
    local action, index, extra = THEME.hgss:settingsHit(x, y, model)
    local function open(row)
      state.option, state.choicePage = row.action or row.key, 1
      if not row.action then
        for i, choice in ipairs(displayRuntime.optionChoices(row.source)) do
          if choice[2] == mod.options:get(row.key) then
            state.choicePage = math.ceil(i / (row.key == "theme_v3" and 3 or 4))
          end
        end
      end
    end
    local row = model.rows and index and model.rows[index]
    if action == "tab" then
      if state.category ~= index then displayRuntime.requestPageMotion(index > (state.category or 1) and 1 or -1) end
      state.category, state.page, state.confirm, state.selected = index, 1, nil, nil
    elseif action == "select" and row then
      state.selected, state.confirm = row.key or row.action, nil
    elseif action == "set" and row and row.choices and row.choices[extra] and mod.options.set then
      mod.options:set(row.key, row.choices[extra][2])
      displayRuntime.haptic("confirm")
    elseif action == "cycle" and row then
      displayRuntime.cycleSetting(row, extra)
      displayRuntime.haptic("confirm")
    elseif action == "more" and row then
      open(row)
    elseif action == "action" and row and row.action then
      displayRuntime.runSettingsAction(row.action)
    elseif action == "back" then
      if state.option then
        state.option, state.confirm = nil, nil
        if state.direct then state.category, state.direct, state.page = nil, nil, 1 end
      elseif state.category and model.tabs then
        state.category, state.page, state.confirm, state.selected = nil, 1, nil, nil
        session.page, displayRuntime.home.activeApp = "HOME", nil
      elseif state.category then
        state.category, state.page, state.confirm = nil, 1, nil
      else session.page, displayRuntime.home.activeApp = "HOME", nil end
    elseif action == "category" then
      state.category, state.page, state.confirm = index, 1, nil
      local rows = displayRuntime.settingsModel().rows
      if #rows == 1 and not rows[1].action then open(rows[1]); state.direct = true end
    elseif action == "prev" or action == "next" then
      state.selected = nil
      displayRuntime.cycleSettingsPage(action == "next" and 1 or -1)
    elseif action == "choice" then
      local choice = model.choices[index]
      if model.source.type == "action" then displayRuntime.runSettingsAction(model.option)
      elseif choice and mod.options.set then mod.options:set(model.option, choice[2]) end
    elseif action == "row" then
      open(model.rows[index])
    end
    session.dirty = true
  end

end
