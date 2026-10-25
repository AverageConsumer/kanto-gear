return function(
  THEME, changePage, compat, currentBattleUIMode, dialogueChoice, displayRuntime,
  loadLocalMap, pagedIndex, press, screenContract, session
)
  function displayRuntime.pageChoice(direction)
    if THEME.style ~= "hgss" then return false end
    local native = displayRuntime.startMenu()
    if native and not native.choiceState then
      local menu = displayRuntime.StartMenu
      if native.dexModel then
        if direction and native.valid() then
          local changed = native.dexModel.view == "profile"
            and displayRuntime.PokedexPage.cycleDescription(native, native.dexModel, direction)
            or displayRuntime.NativeDex.page(native, direction)
          if changed then session.dirty = true end
        end
        return true
      end
      if native.trainer then
        if direction and menu.cursor(native) then
          local key = native.nextKey(direction)
          if key then press(key); session.dirty = true end
        end
        return true
      end
      if native.optionsModel then
        local nextFirst = direction and native.optionsModel.first + direction * 4
        if nextFirst and nextFirst >= 1 and nextFirst < #native.items then menu.select(native, nextFirst); session.dirty = true end
        return true
      end
      if native.moveSelection and native.moveSelection.catalogue then
        local model = displayRuntime.moveSelectionModel(native.moveSelection)
        local nextFirst = direction and model.first + direction * 4
        if nextFirst and nextFirst >= 1 and nextFirst < #native.items then
          menu.select(native, nextFirst); session.dirty = true
        end
        return true
      end
      local first = not native.fixedLayout and not native.quantity and not native.notice and menu.window(native)
      if first and direction then
        local visible = native.recentBag and 4 or menu.visible
        local nextFirst = first + direction * visible
        if nextFirst >= 1 and nextFirst <= #native.items then
          menu.select(native, nextFirst)
          session.dirty = true
        end
      end
      return true
    end
    local top, labels, field = dialogueChoice()
    local state
    if native and native.choiceState then
      state, labels = native.choiceState, native.items
    elseif top then
      state = displayRuntime.choiceState(top, field, labels)
    else return false end
    if direction and #labels > 4 then
      displayRuntime.ChoicePage.step(state, direction, #labels)
      session.dirty = true
    end
    return true
  end

  local function swipe(dx, down)
    if displayRuntime.noticeSwipe and displayRuntime.noticeSwipe(down) then return end
    if session.battle and currentBattleUIMode() == "info" then return end
    if displayRuntime.pageChoice(dx < 0 and 1 or -1) then return end
    if THEME.style == "hgss" and not session.moveInfo then
      local summary = displayRuntime.summaryContext()
      if summary then
        displayRuntime.summaryInput(summary, dx < 0 and "right" or "left")
        session.dirty = true
        return
      end
    end
    if THEME.style == "hgss" and session.page == "TOOLS" then
      local pages = displayRuntime.toolsView().pages
      if pages > 1 then
        session.toolArmed = nil
        local direction = dx < 0 and 1 or -1
        displayRuntime.requestPageMotion(direction)
        session.tools.page = ((session.tools.page or 1) - 1 + direction) % pages + 1
        session.dirty = true
      end
      return
    end
    if THEME.style == "hgss" and session.page == "POKEDEX" then
      local direction, Page = dx < 0 and 1 or -1, displayRuntime.PokedexPage
      local model = displayRuntime.pokedexModel()
      if Page.inDescription(model, (down.x or 0) * THEME.hgssScale,
          (down.y or 0) * THEME.hgssScale) then
        if Page.cycleDescription(displayRuntime.pokedex, model, direction) then session.dirty = true end
      else displayRuntime.cyclePokedex(direction) end
      return
    end
    if THEME.style == "hgss" and session.page == "ACHIEVEMENTS" then
      local state = displayRuntime.achievements
      if (down.y or 0) * THEME.hgssScale < 53
          and (state.view == "album" or state.view == "goals" or state.view == "moments") then
        -- Goals, Stamp Book and Moments, in tab order.
        if displayRuntime.cycleAchievementTabs then displayRuntime.cycleAchievementTabs(dx < 0 and 1 or -1)
        else
          state.view, state.page = state.view == "album" and "goals" or "album", 1
          session.dirty = true
        end
      else displayRuntime.cycleAchievements(dx < 0 and 1 or -1) end
      return
    end
    if THEME.style == "hgss" and session.page == "TRAINER" then
      displayRuntime.cycleTrainer(dx < 0 and 1 or -1)
      return
    end
    if THEME.style == "hgss" and session.page == "BAG" then
      if displayRuntime.bag.detail then return end
      local y = (down.y or 0) * THEME.hgssScale
      if y < 70 and displayRuntime.bagModel().pockets > 1 then
        displayRuntime.cycleBagPocket(dx < 0 and 1 or -1)
      else
        displayRuntime.cycleBagPage(dx < 0 and 1 or -1)
      end
      return
    end
    if THEME.style == "hgss" and session.page == "STORE" then
      local home, direction = displayRuntime.home, dx < 0 and 1 or -1
      local view = home.storeView
      local entries = view == "library" and displayRuntime.storeEntries(true)
        or view == "apps" and displayRuntime.storeEntries()
      local pages = entries and select(3,
        displayRuntime.storePage(view, entries)) or 1
      if not home.storeConfirm and not home.storeReceived and displayRuntime.storeSwipeTarget(view,
          (down.y or 0) * THEME.hgssScale, pages) then
        displayRuntime.cycleStorePage(view, direction)
        session.dirty = true
      else
        changePage(direction)
      end
      return
    end
    if THEME.style == "hgss" and session.page ~= "HOME"
        and session.page ~= "STORE" and session.page ~= "LOCAL"
        and session.page ~= "SETTINGS" then return end
    if session.page ~= "LOCAL" or THEME.style ~= "hgss" then
      changePage(dx < 0 and 1 or -1)
      return
    end
    if displayRuntime.explorer.locationPreview then return end
    local overview = loadLocalMap()
    local model = overview and displayRuntime.explorerModel(overview)
    if model and not model.mapFull then
      local target = displayRuntime.explorerSwipeTarget(model.view,
        model.selected, (down.y or 0) * 1.5, model.pages)
      local direction = dx < 0 and 1 or -1
      if target == "scope" then
        model.filters.wildScope = direction > 0 and "ROUTE" or "HERE"
        displayRuntime.explorer.page, displayRuntime.explorer.selected = 1, nil
        session.dirty = true
      elseif target == "page" and model.pages > 1 then
        displayRuntime.requestPageMotion(direction)
        displayRuntime.explorer.page = ((displayRuntime.explorer.page - 1
          + direction) % model.pages) + 1
        displayRuntime.explorer.selected = nil
        session.dirty = true
      elseif target == "detail" and model.detailPages > 1 then
        displayRuntime.requestPageMotion(direction)
        displayRuntime.explorer.detailPage =
          ((displayRuntime.explorer.detailPage - 1 + direction)
            % model.detailPages) + 1
        session.dirty = true
      end
    end
  end

  local function swipeVertical(dy, down)
    if displayRuntime.noticeSwipe and displayRuntime.noticeSwipe(down) then return end
    if session.battle and currentBattleUIMode() == "info" then return end
    if displayRuntime.pageChoice(dy < 0 and 1 or -1) then return end
    if displayRuntime.startMenu() then return end
    if session.radarOpen then return end
    if THEME.style == "hgss" and session.page == "STORE" then
      local home, view = displayRuntime.home, displayRuntime.home.storeView
      if not home.storeConfirm and not home.storeReceived and (view == "apps" or view == "library") then
        local _, _, current, pages = displayRuntime.storeSelection(view)
        local x, y = (down.x or 0) * THEME.hgssScale, (down.y or 0) * THEME.hgssScale
        if x >= 7 and x < (view == "apps" and 150 or 233)
            and displayRuntime.storeSwipeTarget(view, y, pages) then
          displayRuntime.setStorePage(view, current + (dy < 0 and 1 or -1))
        end
      end
      return
    end
    if session.page == "LOCAL" and THEME.style == "hgss" then return end
    if THEME.style ~= "hgss" and session.page == "TOOLS" and #session.tools > 6 then
      local pages = math.ceil(#session.tools / 6)
      local direction = dy < 0 and 1 or -1
      displayRuntime.requestPageMotion(direction)
      session.tools.page = ((session.tools.page or 1) - 1 + direction) % pages + 1
      session.dirty = true
      return
    end
    local top = session.game and session.game.stack and session.game.stack:top()
    -- Game path [Gen 1]: long bag lists accept the legacy swipe paging contract; Gen 2 PackMenu owns its pocket scrolling.
    if not compat.isGen2() and screenContract(top, "bag")
        and #top.items > 4 then
      top.index = pagedIndex(top.index, #top.items, dy < 0 and 1 or -1)
      session.dirty = true
      return
    end
    local choice, labels, field = dialogueChoice()
    if choice and #labels > 4 then
      local _, cols = compat.choiceGrid(choice, field, #labels)
      local current = compat.choiceIndex(choice, field)
      local nextIndex
      if cols then
        nextIndex = math.max(1, math.min(#labels,
          current + (dy < 0 and cols or -cols)))
      else
        nextIndex = pagedIndex(current, #labels, dy < 0 and 1 or -1)
      end
      compat.choiceIndex(choice, field, nextIndex)
      if type(choice.clampScroll) == "function" then
        pcall(choice.clampScroll, choice)
      end
      session.dirty = true
      return
    end
  end

  return swipe, swipeVertical
end
