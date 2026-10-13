return function(
  THEME, color, compat, currentBattleUIMode, dialogueChoice, displayRuntime,
  hgssRuntime, pcList, pcListKind, pcSession, render, screenState,
  session
)
  function displayRuntime.motionKey()
    if THEME.style ~= "hgss" then return nil end
    if session.battle and currentBattleUIMode() == "info" then
      return "battle-info:" .. tostring(displayRuntime.enemyInfoSelection) .. ":" .. tostring(session.battleInfoDetail)
    end
    local mode, top = screenState()
    local home, explorer = displayRuntime.home, displayRuntime.explorer
    local topId = top and (top.screenId or top.kind or top.phase) or ""
    local summary = compat.isScreen(top, "summary") and top or nil
    local learn = displayRuntime.moveLearnScreen()
    local pcKind = pcSession()
    local listKind = pcListKind(pcList())
    local choice = dialogueChoice()
    return table.concat({
      mode or "", tostring(topId),
      not session.battle and tostring(top and top.phase or "") or "",
      not session.battle and tostring(top and top.savePhase or "") or "",
      not session.battle and top and top.qtyState and "quantity" or "",
      not session.battle and top and top.confirm and "confirm" or "",
      session.moveInfo and "move-info" or "",
      learn and (learn.selecting and "learn-select" or "learn") or "",
      choice and "choice" or "", pcKind or "", listKind or "",
      summary and ("summary-" .. tostring(summary.page or 1)) or "",
      summary and tostring(summary.mon) or "",
      summary and tostring(summary.moveIndex) or "",
      summary and tostring(summary.moveDetail) or "",
      session.battle and ("battle-" .. tostring(session.battle.prompt)) or "",
      session.battle and session.battle.itemIndex ~= nil and ("bag-" .. tostring(session.battle.itemIndex)) or "",
      session.battle and session.battle.partyIndex ~= nil and ("battle-party-" .. tostring(session.battle.partyIndex)) or "",
      session.battle and tostring(session.battle.moveIndex) or "",
      top and top.submenu and "submenu" or "",
      top and tostring(top.pocketIndex
        or top.__gen3uiBagPocketIndex or "") or "",
      session.page or "", home.activeApp or "",
      home.editing and "edit" or "",
      home.library and ("library-" .. tostring(home.libraryKind)
        .. "-" .. tostring(home.libraryPage)) or "",
      session.page == "HOME" and tostring(home.page) or "",
      session.page == "STORE" and table.concat({ tostring(home.storeView), tostring(home.storeSel),
        tostring(home.storeGearSel), tostring(home.storeConfirm), tostring(home.storeReceived) }, ":") or "",
      session.page == "STORE" and tostring((home.storePages or {})[home.storeView or "today"]) or "",
      session.page == "SETTINGS" and tostring(displayRuntime.settings.category) or "",
      session.page == "SETTINGS" and tostring(displayRuntime.settings.page) or "",
      session.page == "SETTINGS" and tostring(displayRuntime.settings.option) or "",
      session.page == "SETTINGS" and tostring(displayRuntime.settings.choicePage) or "",
      session.page == "SETTINGS" and tostring(displayRuntime.settings.confirm) or "",
      session.page == "NOTES" and tostring(displayRuntime.notes.view) or "",
      session.page == "NOTES" and tostring(displayRuntime.notes.selected) or "",
      session.page == "NOTES" and tostring(displayRuntime.notes.page) or "",
      session.page == "POKEDEX" and tostring(displayRuntime.pokedex.view) or "",
      session.page == "POKEDEX" and tostring(displayRuntime.pokedex.selected) or "",
      session.page == "POKEDEX" and tostring(displayRuntime.pokedex.page) or "",
      session.page == "POKEDEX" and tostring(displayRuntime.pokedex.habitatPage) or "",
      session.page == "POKEDEX" and tostring(displayRuntime.pokedex.movePage) or "",
      session.page == "ACHIEVEMENTS" and tostring(displayRuntime.achievements.view) or "",
      session.page == "ACHIEVEMENTS" and tostring(displayRuntime.achievements.selected) or "",
      session.page == "ACHIEVEMENTS" and tostring(displayRuntime.achievements.page) or "",
      session.page == "ACHIEVEMENTS" and tostring(displayRuntime.achievements.habitatPage) or "",
      session.page == "BAG" and tostring(displayRuntime.bag.pocket) or "",
      session.page == "BAG" and tostring(displayRuntime.bag.page) or "",
      session.page == "BAG" and tostring(displayRuntime.bag.detail) or "",
      session.page == "BAG" and tostring(displayRuntime.bag.message) or "",
      tostring(explorer.view or ""), tostring(explorer.selected or ""),
      explorer.mapFull and "map-full" or "",
      tostring(explorer.page or ""), tostring(explorer.detailPage or ""),
      session.page == "TOOLS" and tostring(session.tools.page or 1) or "",
      session.page == "GUIDE" and tostring(session.guidePage or 1) or "",
      session.page == "AREA" and tostring(session.areaPage or 1) or "",
      session.partyActionSlot and "party-action" or "",
      session.partyMoveFrom and "party-swap" or "",
      session.trainerStepsOpen and "trainer-steps" or "",
      session.radarOpen and "radar" or "", session.fieldChoice and session.fieldChoice.kind or "",
      session.pendingFly and "fly-prompt" or "",
      session.pendingAction and "tool-prompt" or "",
      displayRuntime.guideDetail and ("guide-detail-"
        .. tostring(displayRuntime.guideDetail.page or 1)) or "",
    }, "|")
  end

  function displayRuntime.navigationState()
    local mode, top = screenState()
    if mode ~= "active" or session.battle or session.moveInfo or session.fieldChoice
        or session.partyActionSlot or session.partyMoveFrom or session.radarOpen or session.pendingAction
        or session.pendingFly or top and (top.confirm or top.qtyState) then return nil end
    local state = { page = session.page, host = top, context = session.page, index = 1 }
    local function region(context, index, first, last)
      state.context, state.index = context, index or 1
      state.top, state.bottom = first, last
    end
    if session.page == "HOME" then
      local home = displayRuntime.home
      if home.library then
        region("library:" .. tostring(home.libraryKind), home.libraryPage, 49, 195)
      elseif not home.editing then region("home", home.page, 30, 199) end
    elseif session.page == "SETTINGS" then
      local settings = displayRuntime.settings
      if settings.category and not settings.confirm then
        local first, last = settings.option and 101 or 34, settings.option and 201 or 193
        if THEME.style == "hgss" and THEME.hgss.settingsMotionRegion then
          first, last = THEME.hgss:settingsMotionRegion(settings.option ~= nil, first, last)
        end
        region(tostring(settings.category) .. ":" .. tostring(settings.option),
          settings.option and settings.choicePage or settings.page, first, last)
      end
    elseif session.page == "NOTES" then
      local notes = displayRuntime.notes
      if notes.view == "draw" or notes.view == "edit" then return nil end
      local context = table.concat({ notes.view or "list", tostring(notes.selected),
        tostring(notes.filter) }, ":")
      if not notes.confirm and not notes.colorOpen then
        if notes.view == "list" then region(context, notes.page, 57, 149)
        elseif notes.view == "text" or notes.view == "tasks" then
          region(context, notes.page, 89, 172)
        end
      end
    elseif session.page == "BAG" then
      local bag = displayRuntime.bag
      if not bag.detail then
        region(tostring(bag.pocket), bag.page, displayRuntime.lastBagItem() and 109 or 70, 214)
      end
    elseif session.page == "POKEDEX" then
      local dex = displayRuntime.pokedex
      if dex.view == "index" then region("index", dex.page, 66, 197)
      elseif dex.view == "moves" or dex.view == "habitat" then
        region(dex.view .. ":" .. tostring(dex.selected),
          dex.view == "moves" and dex.movePage or dex.habitatPage,
          dex.view == "moves" and 74 or 86, 197)
      end
    elseif session.page == "ACHIEVEMENTS" then
      local stamps = displayRuntime.achievements
      if stamps.view == "album" then region("album", stamps.page, 77, 209)
      elseif stamps.view == "finds" then
        region(tostring(stamps.selected) .. ":" .. tostring(stamps.category),
          stamps.page, 56, stamps.category == 4 and 189 or 211)
      elseif stamps.view == "habitat" then
        region("habitat:" .. tostring(stamps.selected) .. ":" .. tostring(stamps.habitat.species),
          stamps.habitatPage, 86, 197)
      end
    elseif session.page == "LOCAL" then
      local explorer = displayRuntime.explorer
      local view = explorer.view or "wild"
      local context = table.concat({ view, tostring(explorer.selected),
        explorer.filters.wildScope or "HERE" }, ":")
      if THEME.style == "hgss" and THEME.hgss.explorerMotionRegion then
        local first, last, index = THEME.hgss:explorerMotionRegion(view, explorer.selected ~= nil,
          explorer.mapFull, explorer.page, explorer.detailPage)
        if first then region(context, index, first, last) end
      elseif view == "wild" and not explorer.mapFull then
        if explorer.selected then region(context, explorer.detailPage, 148, 205)
        else region(context, explorer.page, 162, 212) end
      end
    elseif session.page == "STORE" then
      local home = displayRuntime.home
      local view = home.storeView or "today"
      if not home.storeConfirm and not home.storeReceived and (view == "apps" or view == "library") then
        region(view, (home.storePages or {})[view], 58, view == "apps" and 164 or 170)
      end
    elseif session.page == "TOOLS" then region("tools", session.tools.page, 30, 199)
    end
    return state
  end

  -- Only a pager action requests motion. A reset/clamp is a data update.
  function displayRuntime.requestPageMotion(direction)
    displayRuntime.motion.pageDirection = direction
  end

  function displayRuntime.battlePanel()
    if not session.battle then return nil end
    local _, top = screenState()
    if session.moveInfo and session.battle.prompt == "moves" then return "detail" end
    local panel = displayRuntime.gen3Ui and displayRuntime.gen3Ui:panel()
    if panel == "party" or compat.isScreen(top, "party") then return "party" end
    if panel == "bag" or compat.isScreen(top, "bag") then return "bag" end
    if session.battle.prompt == "menu" then return "root" end
    if session.battle.prompt == "moves" then return "moves" end
  end

  function displayRuntime.prepareMotion()
    local motion, key = displayRuntime.motion, displayRuntime.motionKey()
    local navigation = displayRuntime.navigationState()
    local previousNavigation = motion.navigation
    local previousPanel, panel = motion.battlePanel, displayRuntime.battlePanel()
    motion.battlePanel = panel
    local pageDirection = motion.pageDirection
    motion.pageDirection = nil
    motion.navigation = navigation
    local direct = session.page == "NOTES" and (displayRuntime.notes.view == "draw"
      or displayRuntime.notes.view == "edit")
    if not key or not displayRuntime.motionEnabled() or direct then
      motion.key, motion.started, motion.cached = nil, nil, nil
      return
    end
    local kind = hgssRuntime.animation and hgssRuntime.animation.kind
    local battleSlide = (kind == "battle_party" or kind == "battle_bag_close"
      or kind == "battle_moves" or kind == "battle_move_info") and 1
      or (kind == "battle_party_close" or kind == "battle_bag"
      or kind == "battle_moves_close" or kind == "battle_move_info_close") and -1 or nil
    if panel and previousPanel and panel ~= previousPanel then
      local forward = previousPanel == "root" and (panel == "moves" or panel == "party")
        or previousPanel == "bag" and panel == "root"
        or previousPanel == "moves" and panel == "detail"
      local back = panel == "root" and (previousPanel == "moves" or previousPanel == "party")
        or previousPanel == "root" and panel == "bag"
        or previousPanel == "detail" and panel == "moves"
      battleSlide = forward and 1 or back and -1 or battleSlide
    end
    if battleSlide then hgssRuntime.animation = nil end
    local changed = motion.key and motion.key ~= key
    motion.key = key
    if not changed then
      if navigation and previousNavigation
          and navigation.context ~= previousNavigation.context then
        motion.started, motion.cached = nil, nil
      end
      return
    end
    local now = love.timer.getTime()
    if hgssRuntime.animation
        or THEME.hgss:partyActionAnimating(now) then
      motion.started = nil
      return
    end
    motion.direction, motion.top, motion.bottom = battleSlide, 28, 216
    if not battleSlide and navigation and previousNavigation
        and navigation.host == previousNavigation.host then
      if navigation.page ~= previousNavigation.page then
        motion.direction = navigation.page == "HOME" and -1 or 1
        motion.top = 28
      elseif pageDirection and navigation.context == previousNavigation.context
          and navigation.top and navigation.top == previousNavigation.top
          and navigation.bottom == previousNavigation.bottom
          and navigation.index ~= previousNavigation.index then
        motion.direction, motion.top, motion.bottom = pageDirection,
          navigation.top, navigation.bottom
      end
    end
    -- Filters, tabs, details, prompts and native screen changes redraw in place.
    -- Never infer a whole-screen slide or fade from an unrelated state key.
    if not motion.direction then
      motion.started, motion.cached = nil, nil
      return
    end
    motion.duration = battleSlide and 0.24 or 0.20
    motion.cached = nil
    if not motion.canvas
        or motion.canvas:getWidth() ~= session.canvas:getWidth()
        or motion.canvas:getHeight() ~= session.canvas:getHeight() then
      if motion.canvas and motion.canvas.release then motion.canvas:release() end
      motion.canvas = render.G.newCanvas(session.canvas:getWidth(), session.canvas:getHeight(),
        { dpiscale = 1 })
      motion.canvas:setFilter("nearest", "nearest")
    end
    local previous = render.G.getCanvas()
    render.G.setCanvas(motion.canvas)
    render.G.origin()
    render.G.setScissor()
    render.G.setShader()
    render.G.setBlendMode("alpha")
    render.G.clear(0, 0, 0, 0)
    color({ 1, 1, 1, 1 })
    render.G.draw(session.canvas)
    render.G.setCanvas(previous)
    motion.backgroundDim = displayRuntime.backgroundDim or 0
    motion.started = now
    -- In-place entrances settle at once in the frame the slide captures.
    if THEME.hgss then THEME.hgss.v4SlideAt = THEME.hgss.clock and THEME.hgss:clock() or now end
  end

  function displayRuntime.applyMotion()
    local motion = displayRuntime.motion
    if not (motion.started and motion.canvas) then return end
    local progress = math.min(1,
      (love.timer.getTime() - motion.started) / motion.duration)
    if progress >= 1 then
      motion.started = nil
      return
    end
    -- DS menus decelerate into place rather than easing both ways.
    progress = 1 - (1 - progress) ^ 3
    local previous = render.G.getCanvas()
    render.G.setCanvas(session.canvas)
    render.G.origin()
    render.G.setScissor()
    render.G.setShader()
    render.G.setBlendMode("alpha")
    if motion.direction then
      local width, height = session.canvas:getWidth(), session.canvas:getHeight()
      if not motion.target or motion.target:getWidth() ~= width
          or motion.target:getHeight() ~= height then
        if motion.target and motion.target.release then motion.target:release() end
        motion.target = render.G.newCanvas(width, height, { dpiscale = 1 })
        motion.target:setFilter("nearest", "nearest")
      end
      if not motion.cached then
        motion.targetBackgroundDim = displayRuntime.backgroundDim or 0
        render.G.setCanvas(motion.target)
        render.G.clear(0, 0, 0, 0)
        color({ 1, 1, 1, 1 }); render.G.draw(session.canvas)
        render.G.setCanvas(session.canvas)
        motion.cached = true
      end
      color({ 1, 1, 1, 1 })
      render.G.draw(motion.target)
      -- Keep the destination stationary outside the changing content region.
      local top = motion.top or 28
      render.G.setScissor(0, top * height / 216, width,
        height * ((motion.bottom or 216) - top) / 216)
      local offset = math.floor(width * progress + 0.5) * motion.direction
      render.G.draw(motion.canvas, -offset, 0)
      render.G.draw(motion.target, width * motion.direction - offset, 0)
      render.G.setScissor()
    else
      color({ 1, 1, 1, 1 - progress })
      render.G.draw(motion.canvas)
    end
    render.G.setCanvas(previous)
    local targetDim = motion.direction and motion.targetBackgroundDim
      or displayRuntime.backgroundDim or 0
    displayRuntime.backgroundDim = targetDim * progress
      + (motion.backgroundDim or 0) * (1 - progress)
  end

end
