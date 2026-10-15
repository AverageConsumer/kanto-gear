return function(
  THEME, areaData, carouselSubpage, dialogueChoice, displayRuntime, guideData,
  mod, pageNames, pageSwipeAllowed, refreshTools, screenState, session
)
  local function changePage(direction)
    if displayRuntime.homeHelpActive() then return end
    if session.pendingFly or session.pendingAction or session.fieldChoice or session.partyActionSlot
        or session.partyMoveFrom
        or displayRuntime.moveLearnScreen()
        or dialogueChoice() or session.radarOpen then return end
    if not pageSwipeAllowed(screenState(), session.battle) then return end
    if session.trainerStepsOpen then
      session.trainerStepsOpen, session.dirty = false, true
      return
    end
    if THEME.style == "hgss" and session.page == "HOME" then
      local home = displayRuntime.home
      if home.library and home.addSlot then
        local count = math.max(1, math.ceil(#displayRuntime.Home.library(
          home.layout, displayRuntime.homeCatalog, home.page,
          home.addSlot.column, home.addSlot.row, home.libraryKind) / 6))
        displayRuntime.requestPageMotion(direction)
        home.libraryPage = ((home.libraryPage or 1) - 1 + direction) % count + 1
      else
        local count = displayRuntime.Home.pageCount(home.layout)
          + (home.editing and 1 or 0)
        displayRuntime.requestPageMotion(direction)
        home.page = ((home.page or 1) - 1 + direction) % count + 1
      end
      if displayRuntime.needsTools() then displayRuntime.perf:call("tools", refreshTools) end
      session.dirty = true
      return
    elseif THEME.style == "hgss" and session.page == "STORE" then
      local home = displayRuntime.home
      if not home.storeConfirm and not home.storeReceived then
        displayRuntime.requestPageMotion(direction)
        displayRuntime.cycleStoreView(direction)
      end
      session.dirty = true
      return
    elseif THEME.style == "hgss" and session.page == "POKEDEX" then
      displayRuntime.cyclePokedex(direction)
      return
    elseif THEME.style == "hgss" and session.page == "ACHIEVEMENTS" then
      displayRuntime.cycleAchievements(direction)
      return
    elseif THEME.style == "hgss" and session.page == "PSS" then
      local pss = displayRuntime.pss
      if not (pss.selected or pss.incoming or pss.pending or pss.activity) then
        pss:action("page", direction)
      end
      session.dirty = true
      return
    elseif THEME.style == "hgss" and session.page == "BAG" then
      if displayRuntime.bag.detail then
        displayRuntime.bag.detail, displayRuntime.bag.message = nil, nil
        session.dirty = true
      else
        displayRuntime.cycleBagPage(direction)
      end
      return
    elseif THEME.style == "hgss" and session.page == "SETTINGS" then
      displayRuntime.cycleSettingsPage(direction)
      return
    elseif THEME.style == "hgss" and session.page == "TOOLS" then
      local pages = displayRuntime.toolsView().pages
      if pages > 1 then
        session.toolArmed = nil
        displayRuntime.requestPageMotion(direction)
        session.tools.page = ((session.tools.page or 1) - 1 + direction) % pages + 1
        session.dirty = true
      end
      return
    end
    if session.page == "LOCAL" and THEME.style == "hgss"
        and (displayRuntime.explorer.selected
          or displayRuntime.explorer.view
          or displayRuntime.explorer.mapFull) then
      local explorer = displayRuntime.explorer
      if explorer.locationPreview then
        local preview = explorer.locationPreview
        if preview.locationImage then preview.locationImage:release() end
        if preview.locationRenderer then preview.locationRenderer:release() end
        explorer.locationPreview = nil
      elseif explorer.mapFull then explorer.mapFull = false
      elseif explorer.selected then
        explorer.view, explorer.selected, explorer.detailPage = nil, nil, 1
      else explorer.view, explorer.page = nil, 1 end
      session.dirty = true
      return
    end
    if displayRuntime.guideDetail then
      local guide, row = guideData()
      for _, candidate in ipairs(guide.rows) do
        if candidate.species == displayRuntime.guideDetail.species then
          row = candidate break
        end
      end
      if row and row.detailPages > 1 then
        local nextPage = carouselSubpage(displayRuntime.guideDetail.page,
          row.detailPages, direction)
        if nextPage then
          displayRuntime.guideDetail.page, session.dirty = nextPage, true
        end
      end
      return
    end
    displayRuntime.perf:call("tools", refreshTools)
    local current, count
    if session.page == "GUIDE" then
      current, count = session.guidePage, guideData().pages
    elseif session.page == "AREA" then
      current, count = session.areaPage, areaData().pages
    end
    local subpage = current and carouselSubpage(current, count, direction)
    if subpage then
      if session.page == "GUIDE" then session.guidePage = subpage else session.areaPage = subpage end
      mod.log:info("page %s %d/%d", session.page, subpage, count)
      session.dirty = true
      return
    end
    local names = pageNames()
    local index = 1
    for i, name in ipairs(names) do
      if name == session.page then index = i break end
    end
    index = ((index - 1 + direction) % #names) + 1
    session.page = names[index]
    if session.page == "GUIDE" then
      session.guidePage = direction < 0 and guideData().pages or 1
    elseif session.page == "AREA" then
      session.areaPage = direction < 0 and areaData().pages or 1
    end
    mod.log:info("page %s", session.page)
    session.dirty = true
  end

  session.overlayHeld = false

  local function pollScreenSwap()
    local down, overlayDown = false, false
    local swapEnabled = THEME:displayMode(mod.options) ~= "phone"
      and (THEME:displayMode(mod.options) == "fullscreen"
        or mod.options:get("screen_swap") == true)
    local overlayButton = mod.options:get("overlay_button") or "off"
    local overlayEnabled = THEME:displayMode(mod.options) == "combined"
      and THEME:windowMode(mod.options) == "overlay"
      and overlayButton ~= "off"
    local keyboard = love and love.keyboard
    if keyboard and keyboard.isDown then
      if swapEnabled then
        local ok, pressed = pcall(keyboard.isDown, "f6")
        down = ok and pressed or false
      end
      if overlayEnabled and overlayButton == "f7" then
        local okOverlay, pressedOverlay = pcall(keyboard.isDown, "f7")
        overlayDown = okOverlay and pressedOverlay or false
      end
    end
    local js = love and love.joystick
    if (swapEnabled or overlayEnabled and overlayButton ~= "f7")
        and js and js.getJoysticks then
      local ok, pads = pcall(js.getJoysticks)
      if ok then
        for _, pad in ipairs(pads or {}) do
          if pad.isGamepadDown then
            if swapEnabled then
              local okDown, pressed = pcall(pad.isGamepadDown, pad, "y")
              if okDown and pressed then down = true end
            end
            if overlayEnabled and overlayButton ~= "f7" then
              local okOverlay, pressedOverlay = pcall(
                pad.isGamepadDown, pad, overlayButton)
              if okOverlay and pressedOverlay then overlayDown = true end
            end
          end
        end
      end
    end
    local pressed = down and not screenSwapHeld
    local overlayPressed = overlayDown and not session.overlayHeld
    screenSwapHeld = down
    session.overlayHeld = overlayDown
    return pressed, overlayPressed
  end

  return changePage, pollScreenSwap
end
