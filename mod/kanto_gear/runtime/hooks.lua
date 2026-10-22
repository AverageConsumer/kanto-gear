return function(
  HEIGHT, RADAR_FRAMES, THEME, WIDTH, battleState, bottomOnHandheld,
  bottomOwnsBattleUI, companionMoveGrid, compat, customBattleLayout, dialogueChoice, displayRuntime,
  draw, fullBottomBattleUI, hasDisplay, hgssRuntime, holdTextSpeed, inlineDisplay,
  invalidateLocalMap, mod, pcList, pollScreenSwap, pumpDisplay, refreshBattle,
  refreshTheme, refreshTools, render, resetSwapState, screenContract, screenState,
  session, touchEvent, trackChoice
)
  local function moduleShown()
    local shown = session.active and displayRuntime.gearModules.anyShown() or false
    if shown ~= (displayRuntime.gearModules.shown == true) then
      displayRuntime.gearModules.shown = shown
      resetSwapState()
      THEME.nativeWindowLayout = nil
      session.nextPoll = 0
      if session.readbackPending then displayRuntime.moduleReadbackPending = true end
      displayRuntime.displayBridge.checkedAt = nil
      hgssRuntime.animation = nil
      displayRuntime.motion.started, displayRuntime.motion.cached = nil, nil
      if displayRuntime.phone then displayRuntime.phone.touches = {} end
      if shown and displayRuntime.nativePhoneOwner then
        local owner = displayRuntime.nativePhoneOwner
        if owner.setEnabled then owner.setEnabled(true) end
        displayRuntime.nativePhoneOwner = nil
      end
    end
    return shown
  end

  mod.hooks:wrap("input.step", function(next, stepGame, dt)
    local measured = displayRuntime.perf:start()
    if stepGame == displayRuntime.sourceGame and displayRuntime.phone then displayRuntime.phone:step(dt) end
    if moduleShown() then return next(stepGame, dt) end
    if stepGame == displayRuntime.sourceGame then displayRuntime.syncCompanionDetails() end
    if stepGame == displayRuntime.sourceGame and displayRuntime.levelUp:scan(session.game.save,
        session.game.stack and session.game.stack:top()) then session.dirty = true end
    if stepGame == displayRuntime.sourceGame then displayRuntime.bindBattleInput(stepGame) end
    if not displayRuntime.battleInput then
      if not displayRuntime.filterBattleDetailsInput(stepGame) then
        displayRuntime.remapBattleSummaryInput(stepGame)
        hgssRuntime.remapBattleRootInput(stepGame)
        hgssRuntime.remapLearningInput(stepGame)
      end
    end
    local openingPanel = hgssRuntime.openingBattlePanel(stepGame)
    local closingPanel = hgssRuntime.closingBattlePanel(stepGame)
    local swapPressed, overlayPressed = pollScreenSwap()
    if session.active and (inlineDisplay() or hasDisplay()) and swapPressed then
      if displayRuntime.autoBattle.wanted ~= nil then
        displayRuntime.autoBattle.shown = not displayRuntime.gearPrimary()
      else
        displayRuntime.swapped = not displayRuntime.swapped
      end
      resetSwapState()
      mod.log:info("screen swap: gear=%s", inlineDisplay()
        and (displayRuntime.gearPrimary()
            and "primary" or "secondary")
          or (bottomOnHandheld() and "handheld" or "external"))
    end
    if session.active and inlineDisplay() and overlayPressed then
      displayRuntime.overlayHidden = not displayRuntime.overlayHidden
      resetSwapState()
      mod.log:info("overlay %s",
        displayRuntime.overlayHidden and "hidden" or "shown")
    end
    if closingPanel then hgssRuntime.beginAnimation(closingPanel) end
    if stepGame == displayRuntime.sourceGame then displayRuntime.observeBagInput() end
    local downstream = displayRuntime.perf:start()
    local result = next(stepGame, dt)
    local excluded = displayRuntime.perf:elapsed(downstream)
    displayRuntime.stepDeviceApps(stepGame, dt)
    if moduleShown() then
      displayRuntime.perf:finish("gear_input", measured, excluded)
      return result
    end
    if stepGame == displayRuntime.sourceGame then
      displayRuntime.pss:step()
      if displayRuntime.recentItem:poll(session.game.save) then session.dirty = true end
      displayRuntime.syncCompanionDetails()
      displayRuntime.updateAutoBattleScreen()
      local pending = displayRuntime.touchGuard.pending
      displayRuntime.touchGuard.pending = false
      if pending or session.touchDown then displayRuntime.syncTouchGuard() end
    end
    if openingPanel then
      hgssRuntime.beginAnimation(openingPanel,
        openingPanel == "battle_party" and { duration = 0.28 } or nil)
    end
    if openingPanel or closingPanel then
      -- Commit both the stack and snapshot before capturing the destination.
      -- Otherwise the next 50ms poll can restart the same transition.
      displayRuntime.perf:call("battle_snapshot", refreshBattle)
    end
    displayRuntime.perf:finish("gear_input", measured, excluded)
    return result
  end, 1000)

  mod.hooks:wrap("render.viewport", function(next, context)
    local available = next(context)
    THEME.nativeWindowLayout = nil
    -- the module gets the whole window: no viewport carved out for the phone
    if moduleShown() then return available end
    if not (session.active and inlineDisplay() and context) then return available end
    local base = type(available) == "table" and available or {
      x = 0, y = 0, width = context.width, height = context.height,
    }
    local layout = THEME:windowLayout(THEME:windowMode(mod.options),
      base.width, base.height,
      displayRuntime.gearPrimary(),
      mod.options:get("overlay_corner"), displayRuntime.overlayHidden,
      mod.options:get("secondary_size"),
      mod.options:get("bottom_safe_area"))
    if not layout then return available end
    for _, rect in ipairs({ layout.game, layout.gear }) do
      rect.x = rect.x + (base.x or 0)
      rect.y = rect.y + (base.y or 0)
    end
    THEME.nativeWindowLayout = layout
    return {
      x = layout.game.x, y = layout.game.y,
      width = layout.game.w, height = layout.game.h,
      capture = layout.showGear,
    }
  end, 1000)

  mod.hooks:wrap("render.output_enabled", function(next)
    if moduleShown() then return next() end
    if session.active and inlineDisplay() then
      return not THEME.nativeWindowLayout
    end
    if session.active and bottomOnHandheld() and hasDisplay() then return true end
    return next()
  end, 1000)


  mod.hooks:wrap("render.output", function(next, context)
    if session.active and moduleShown() then
      session.primaryBottomRect = nil
      session.displayReady = false
      return next(context)
    end
    if session.active and inlineDisplay() and not THEME.nativeWindowLayout
        and context and context.canvas then
      if next(context) == true then
        session.primaryBottomRect = nil
        session.displayReady = false
        return true
      end
      local fallbackWidth, fallbackHeight = render.G.getDimensions()
      local ww = math.max(1, context.width or fallbackWidth)
      local wh = math.max(1, context.height or fallbackHeight)
      local layout = THEME:windowLayout(THEME:windowMode(mod.options), ww, wh,
        displayRuntime.gearPrimary(),
        mod.options:get("overlay_corner"), displayRuntime.overlayHidden,
        mod.options:get("secondary_size"),
        mod.options:get("bottom_safe_area"))
      if not layout then return false end
      if layout.showGear and session.dirty then draw(); session.dirty = false end
      render.G.push("all")
      render.G.setCanvas()
      render.G.origin()
      render.G.setScissor()
      render.G.setShader()
      render.G.setBlendMode("alpha")
      render.G.clear(0, 0, 0, 1)
      render.G.setColor(1, 1, 1, 1)
      if layout.gameOnTop then
        session.primaryBottomRect = THEME:drawCanvas(session.canvas, layout.gear)
        THEME:drawCanvas(context.canvas, layout.game)
      else
        if layout.showGame then THEME:drawCanvas(context.canvas, layout.game) end
        session.primaryBottomRect = layout.showGear
          and THEME:drawCanvas(session.canvas, layout.gear) or nil
      end
      render.G.setScissor()
      render.G.pop()
      session.displayReady = layout.showGear
      return true
    end
    if session.active and inlineDisplay() then return next(context) end
    if not (session.active and bottomOnHandheld() and hasDisplay()
        and context and context.canvas) then
      session.primaryBottomRect = nil
      return next(context)
    end

    local now = love.timer.getTime()
    if session.gameReadbackPending and session.gameReadbackCanvas
        and now >= session.nextPresentAttempt then
      local image = displayRuntime.perf:call("readback_poll", session.gameReadbackCanvas.pollImageData, session.gameReadbackCanvas)
      if image then
        local shown = displayRuntime.perf:present(session.companion.push, image, image:getWidth(), image:getHeight(),
          render.SECONDARY_BACKGROUND, "secondary:cover")
        session.gameReadbackPending = false
        session.gameReadbackCanvas = nil
        if shown == true and not session.displayReady then
          mod.log:info("screen swap: game frame submitted")
        end
        session.displayReady = shown == true
        if not session.displayReady then session.nextPresentAttempt = now + 0.25 end
      end
    end

    if not session.gameReadbackPending and now >= session.nextGameCapture then
      local measured = displayRuntime.perf:start()
      local ww = math.max(1, context.width or render.G.getWidth())
      local wh = math.max(1, context.height or render.G.getHeight())
      local captureScale = math.min(960 / ww, 540 / wh)
      local cw = math.max(1, math.floor(ww * captureScale + 0.5))
      local ch = math.max(1, math.floor(wh * captureScale + 0.5))
      if not session.gameCaptureCanvas or session.gameCaptureCanvas:getWidth() ~= cw
          or session.gameCaptureCanvas:getHeight() ~= ch then
        session.gameCaptureCanvas = render.G.newCanvas(cw, ch, { dpiscale = 1 })
        session.gameCaptureCanvas:setFilter("linear", "linear")
      end
      render.G.push("all")
      render.G.setCanvas(session.gameCaptureCanvas)
      render.G.origin()
      render.G.setScissor()
      render.G.setShader()
      render.G.setBlendMode("alpha")
      render.G.clear(0, 0, 0, 1)
      render.G.setColor(1, 1, 1, 1)
      render.G.draw(context.canvas, 0, 0, 0, cw / ww, ch / wh)
      render.G.pop()
      displayRuntime.perf:finish("game_capture", measured)
      if session.gameCaptureCanvas.requestImageData
          and session.gameCaptureCanvas.pollImageData
          and displayRuntime.perf:call("readback_request", session.gameCaptureCanvas.requestImageData, session.gameCaptureCanvas) then
        session.gameReadbackPending = true
        session.gameReadbackCanvas = session.gameCaptureCanvas
        session.nextGameCapture = now + 1 / 60
      elseif session.gameCaptureCanvas.newImageData then
        local ok, image = pcall(displayRuntime.perf.call, displayRuntime.perf,
          "readback_sync", session.gameCaptureCanvas.newImageData, session.gameCaptureCanvas)
        if ok and image then
          local shown = displayRuntime.perf:present(session.companion.push, image, image:getWidth(), image:getHeight(),
            render.SECONDARY_BACKGROUND, "secondary:cover")
          session.displayReady = shown == true
          if not session.displayReady then session.nextPresentAttempt = now + 0.25 end
        end
        session.nextGameCapture = now + 1 / 60
      end
    end

    if session.dirty then draw(); session.dirty = false end
    local ww = math.max(1, context.width or render.G.getWidth())
    local wh = math.max(1, context.height or render.G.getHeight())
    local scale = math.min(ww / session.canvas:getWidth(), wh / session.canvas:getHeight())
    local dw, dh = session.canvas:getWidth() * scale, session.canvas:getHeight() * scale
    local dx, dy = math.floor((ww - dw) / 2), math.floor((wh - dh) / 2)
    session.primaryBottomRect = { x = dx, y = dy, w = dw, h = dh }

    render.G.push("all")
    render.G.setCanvas()
    render.G.origin()
    render.G.setScissor()
    render.G.setShader()
    render.G.setBlendMode("alpha")
    local brightness = 1 - (displayRuntime.backgroundDim or 0)
    render.G.clear(render.PAPER[1] * brightness, render.PAPER[2] * brightness,
      render.PAPER[3] * brightness, 1)
    render.G.setColor(1, 1, 1, 1)
    render.G.draw(session.canvas, dx, dy, 0, scale, scale)
    render.G.pop()
    session.displayReady = true
    return true
  end, 1000)

  mod.hooks:wrap("render.window", function(next, windowGame, context)
    if session.active and moduleShown() then
      -- the module's surface is up: the Gear stands down here too (the native
      -- window layout draws through this wrap, not render.output)
      session.primaryBottomRect = nil
      session.displayReady = false
      return next(windowGame, context)
    end
    if not (session.active and inlineDisplay() and THEME.nativeWindowLayout
        and context and context.canvas) then
      return next(windowGame, context)
    end
    if THEME.nativeWindowLayout.showGame then next(windowGame, context) end
    if not THEME.nativeWindowLayout.showGear then
      session.primaryBottomRect = nil
      session.displayReady = false
      return true
    end
    if session.dirty then draw(); session.dirty = false end
    render.G.push("all")
    render.G.origin()
    render.G.setCanvas()
    render.G.setScissor()
    render.G.setShader()
    render.G.setBlendMode("alpha")
    render.G.setColor(1, 1, 1, 1)
    session.primaryBottomRect = THEME:drawCanvas(session.canvas, THEME.nativeWindowLayout.gear)
    if THEME.nativeWindowLayout.gameOnTop then
      THEME:drawCanvas(context.canvas, THEME.nativeWindowLayout.game)
    end
    render.G.setScissor()
    render.G.pop()
    session.displayReady = true
    return true
  end, 1000)

  local function primaryTouch(action, x, y)
    if moduleShown() then return false end
    local inline = inlineDisplay()
    if not (session.active and hasDisplay()
        and (inline or bottomOnHandheld())) then return false end
    local layout = THEME.nativeWindowLayout
    if inline and layout and layout.gameOnTop
        and not (displayRuntime.notesShown() and displayRuntime.notes.down) then
      local gameRect = layout.game
      if x >= gameRect.x and x < gameRect.x + gameRect.w
          and y >= gameRect.y and y < gameRect.y + gameRect.h then
        session.touchDown = nil
        return false
      end
    end
    local rect = session.primaryBottomRect
    if not rect then return not inline end
    local insideRect = x >= rect.x and x < rect.x + rect.w
      and y >= rect.y and y < rect.y + rect.h
    if action == "down" and not insideRect then
      session.touchDown = nil
      return not inline
    end
    if displayRuntime.notesShown() then
      if action == "down" and not insideRect then return not inline end
      if action ~= "down" and not displayRuntime.notes.down then return not inline end
      displayRuntime.notesPointer(action, (x - rect.x) * 240 / rect.w,
        (y - rect.y) * 216 / rect.h)
      return true
    end
    if inline and action ~= "down" and not session.touchDown then return false end
    local tx = math.max(0, math.min(WIDTH - 1,
      math.floor((x - rect.x) * WIDTH / rect.w)))
    local ty = math.max(0, math.min(HEIGHT - 1,
      math.floor((y - rect.y) * HEIGHT / rect.h)))
    if action == "down" or action == "up" or action == "move"
        or action == "cancel" then
      touchEvent(string.format("%s,%d,%d", action, tx, ty))
    end
    return true
  end

  displayRuntime.primaryTouch = primaryTouch

  mod.hooks:wrap("input.pointer", function(next, pointerGame, event)
    if moduleShown() then return next(pointerGame, event) end
    local action = ({ pressed = "down", released = "up", moved = "move",
                      cancelled = "cancel" })[event.phase]
    if action and primaryTouch(action, event.x, event.y) then return true end
    if event.phase == "moved" and session.active and hasDisplay()
        and ((inlineDisplay() and session.touchDown) or (not inlineDisplay()
          and bottomOnHandheld())) then return true end
    return next(pointerGame, event)
  end, 1000)

  for _, event in ipairs({ "flag.changed", "world.interacted", "world.object_toggled", "battle.ended", "pokemon.caught" }) do
    mod.events:on(event, function(payload)
      -- All three engines report an A press into empty space as "none".
      -- No interaction occurred, so neither progress nor map rows changed.
      if event == "world.interacted" and payload and payload.kind == "none" then return end
      displayRuntime.explorer.data = nil
      displayRuntime.invalidateAchievements(event == "pokemon.caught" and "dex" or nil)
      local home = displayRuntime.home
      if home and home.widgetCache and home.widgetCache.model.stamps then
        home.widgetCache = nil
        if session.page == "HOME" then session.dirty = true end
      end
      if session.page == "ACHIEVEMENTS" then session.dirty = true end
    end)
  end

  mod.events:on("world.stepped", function(payload)
    -- Walking can change poison HP, eggs, tools and step/progress widgets.
    -- A map-only Home must not rebuild unrelated widgets on every cell.
    local cache = displayRuntime.home.widgetCache
    if cache and cache.stepSensitive then displayRuntime.home.widgetCache = nil end
    session.steps = session.steps + 1
    mod.save:set("steps", session.steps)
    session.mapId = payload.mapId or session.mapId
    if session.radarOpen then session.radarOpen, session.dirty = false, true end
    if session.page == "TRAINER" or session.page == "STEPS" or session.page == "HOME"
        or session.page == "LOCAL" then
      displayRuntime.lastStepAt = love.timer.getTime()
    end
  end)

  for _, event in ipairs({ "world.block_replaced", "map.reloaded" }) do
    mod.events:on(event, function(payload)
      if not payload or not payload.mapId or payload.mapId == session.mapId then
        invalidateLocalMap(true)
        session.dirty = true
      end
    end)
  end

  mod.events:on("screen.pushed", function()
    -- Menus, dialogue and hatching change the screen stack, not map terrain.
    -- Refresh live rows without releasing the map image or resetting its view.
    displayRuntime.explorer.data, displayRuntime.explorer.renderModel = nil, nil
    displayRuntime.home.widgetCache = nil
    session.dirty = true
  end)

  mod.hooks:wrap("battle.caught_marker_visible", function(next, state)
    if mod.options:get("caught_icon") ~= false and session.active then return true end
    return next(state)
  end)

  mod.hooks:wrap("battle.bottom_ui_visible", function(next, state)
    if next(state) == false then return false end
    local presentation = displayRuntime.gen3Presentation
    if displayRuntime.gen3 and presentation then
      return not (presentation.owns and presentation.owns("panel"))
    end
    local raw = battleState()
    local top = session.game and session.game.stack and session.game.stack:top()
    local owned = bottomOwnsBattleUI(
      customBattleLayout(), session.active,
      hasDisplay(), session.displayReady, raw, session.battle)
    return not (owned
      and (state == raw or (state == top and top.isTextBox)))
  end)

  -- Game path [Gen 1/2]: the legacy navigation hook remaps their menu grid; native Gen 3 navigation is handled by its presentation adapter.
  mod.hooks:wrap("battle.move_grid_navigation", function(next, state)
    if next(state) == true then return true end
    return not displayRuntime.gen3 and companionMoveGrid(state)
  end)

  mod.hooks:wrap("ui.party.grid_navigation", function(next, state)
    if next(state) == true then return true end
    return screenContract(state, "party") ~= nil and bottomOwnsBattleUI(
      customBattleLayout(), session.active,
      hasDisplay(), session.displayReady, battleState(), session.battle)
  end)

  mod.hooks:wrap("battle.status_hud_visible", function(next, state)
    if next(state) == false then return false end
    local presentation = displayRuntime.gen3Presentation
    if displayRuntime.gen3 and presentation then
      return not (presentation.owns and presentation.owns("hud"))
    end
    return not bottomOwnsBattleUI(
      fullBottomBattleUI(), session.active, hasDisplay(),
      session.displayReady, state, session.battle)
  end)

  mod.hooks:wrap("screen.render_visible", function(next, state)
    if next(state) == false then return false end
    -- Standard/Info never replace native screens, including every stats page.
    if not customBattleLayout() then return true end
    if compat.isScreen(state, "summary")
        and compat.summary.supports(state, session.game) then
      return not bottomOwnsBattleUI(customBattleLayout(), session.active,
        hasDisplay(), session.displayReady, battleState(), session.battle)
    end
    local owned = bottomOwnsBattleUI(
      customBattleLayout(), session.active,
      hasDisplay(), session.displayReady, battleState(), session.battle)
    return not (owned and (screenContract(state) or screenContract(state, "moveLearn")
      or screenContract(state, "naming")))
  end)

  mod.events:on("battle.started", function()
    if THEME.hgss then THEME.hgss.v4BattleLog = nil end
    session.dirty = true
  end)

  mod.events:on("battle.ended", function(payload)
    if THEME.hgss then THEME.hgss.v4BattleLog = nil end
    session.dirty = true
    session.battleInfoDetail = nil; displayRuntime.enemyInfoSelection = nil
    local state = payload and payload.battle
    local result = payload and payload.result
    if session.mapId == "OAKS_LAB" and state and state.oppClass == "OPP_RIVAL1"
        and (result == "win" or result == "lose") then
      mod.save:set("oak_lab_rival_result", result)
    end
  end)

  mod.events:on("screen.popped", function(payload)
    displayRuntime.home.widgetCache = nil
    if compat.isBattleScreen(payload and payload.state) then
      session.battle = nil
      session.moveInfo = nil
      session.battleInfoDetail = nil; displayRuntime.enemyInfoSelection = nil
      session.dirty = true
    elseif payload and payload.state
        and (payload.state.screenId == "MoveLearnMenu"
          or payload.state.screenId == "Gen2MoveDeleter") then
      session.moveInfo = nil
      session.dirty = true
    end
  end)

  for _, event in ipairs({
    "battle.turn_started", "battle.move_used",
    "battle.damage_dealt", "battle.status_inflicted",
    "battle.battler_switched", "battle.turn_ended",
    "pokemon.caught",
  }) do
    mod.events:on(event, function() session.dirty = true end)
  end

  mod.events:on("pokemon.level_up", function()
    -- Gen 1 commits individual levels; Gen 2 emits several events after a
    -- single final stat write. Unchanged snapshots keep that full jump intact.
    -- API 3 event records are detached. Read the live party so identity-based
    -- stat baselines and native Rare Candy result ownership stay intact.
    local game = session.game
    if game and displayRuntime.levelUp:scan(game.save,
        game.stack and game.stack:top()) then session.dirty = true end
  end)

  -- Upstream owns the display seam; this mod only supplies its companion frame.
  mod.hooks:wrap("render.compose", function(next, renderer, context)
    if moduleShown() then
      return next(renderer, context)
    end
    local measured = displayRuntime.perf:start()
    displayRuntime.perf:frame()
    -- Game path [Gen 3]: save/session replacement can become live after save events; bind stored UI only once the native field session is active.
    if displayRuntime.gen3 and displayRuntime.sourceGame.phase == "field"
        and displayRuntime.gen3BoundSession ~= displayRuntime.sourceGame.session then
      displayRuntime.reloadSavedUi()
    end
    -- Game path [Gen 3]: cached read models poll native in-place writes at 50ms intervals and resync the projected UI stack.
    if displayRuntime.gen3 then
      local now = love.timer.getTime()
      if now >= (displayRuntime.gen3PollAt or 0) then
        displayRuntime.perf:call("gen3_refresh", displayRuntime.gen3.refresh, displayRuntime.gen3)
        displayRuntime.gen3PollAt = now + 0.05
      end
      displayRuntime.gen3.syncScreens()
    end
    if session.game and displayRuntime.levelUp:scan(session.game.save,
        session.game.stack and session.game.stack:top()) then session.dirty = true end
    if session.game and displayRuntime.recentItem:poll(session.game.save) then session.dirty = true end
    if displayRuntime.recentItem.pending then
      local top = session.game and session.game.stack and session.game.stack:top()
      local raw = battleState()
      if displayRuntime.gen3 then
        if not displayRuntime.gen3Ui.Stack.top() and not displayRuntime.gen3Ui.Message.isOpen()
            and (not displayRuntime.gen3.Battle.isActive()
              or displayRuntime.gen3.Battle._phase == "command") then displayRuntime.recentItem.pending = nil end
      elseif top == session.game.world or top == session.game.overworld or top == nil
          or top.screenId == "BagMenu"
          or top.screenId == "Gen2PackMenu" and not top.submenu and not top.message
            and not top.qtyState and not top.confirm
          or top == raw and session.battle and session.battle.prompt == "menu" then
        displayRuntime.recentItem.pending = nil
      end
    end
    local inline = inlineDisplay()
    session.companion = context and context.secondScreen
    if THEME:displayMode(mod.options) == "phone" then
      if session.companion and session.companion.setEnabled and displayRuntime.nativePhoneOwner ~= session.companion then
        session.companion.setEnabled(false)
        displayRuntime.nativePhoneOwner = session.companion
      end
      session.companion = displayRuntime.phone and displayRuntime.phone.bridge
      session.displayReady = displayRuntime.phone ~= nil and displayRuntime.phone:ready()
    end
    displayRuntime.syncDisplayBridge(love.timer.getTime(), inline)
    local downstream = displayRuntime.perf:start()
    local handled = next(renderer, context)
    local excluded = displayRuntime.perf:elapsed(downstream)
    if moduleShown() then
      displayRuntime.perf:finish("gear_compose", measured, excluded)
      return handled
    end
    if session.textSpeedReleasePending then
      session.textSpeedReleasePending = false
      holdTextSpeed(false)
    end
    if displayRuntime.pss:tick(love.timer.getTime()) and THEME.style == "hgss" then
      if session.page == "PSS" then session.dirty = true
      elseif session.page == "HOME" then
        for _, tile in ipairs((displayRuntime.home.layout or {}).tiles or {}) do
          if tile.id == "pss_widget" and tile.page == displayRuntime.home.page then
            session.dirty = true; break
          end
        end
      end
    end
    if not inline and (not session.companion or not session.companion.detected
        or not session.companion.pollTouch) then
      if not session.bridgeWarned then
        session.bridgeWarned = true
        mod.log:warn("host SecondScreen bridge has no companion touch support")
      end
      displayRuntime.perf:finish("gear_compose", measured, excluded); return handled
    end
    if not session.active then displayRuntime.perf:finish("gear_compose", measured, excluded); return handled end
    if not session.loggedTick then
      session.loggedTick = true
      mod.log:info("display available=%s", tostring(hasDisplay()))
    end

    local now = love.timer.getTime()
    -- Phone input and Notes run every rendered frame; game snapshots keep their 50ms tick.
    local notesActive = displayRuntime.notesShown()
    local phoneMode = THEME:displayMode(mod.options) == "phone"
    if notesActive or phoneMode then
      if not inline and not bottomOnHandheld() then
        for _ = 1, 128 do
          local event = session.companion.pollTouch()
          if not event then break end
          touchEvent(event, session.canvas:getWidth(), session.canvas:getHeight())
          if moduleShown() then break end
          if notesActive and not displayRuntime.notesShown() then break end
        end
      end
    end
    if not displayRuntime.notesShown() then displayRuntime.notes:suspend() end
    displayRuntime.perf:call("notes_flush", displayRuntime.notes.flush, displayRuntime.notes)
    if displayRuntime.notes:takeChanged() then session.dirty = true end
    displayRuntime.updateHomeLongPress(now)
    -- Installed Stamps prepares in short, throttled slices during normal play.
    -- Menus, battles and loading retain priority over album preparation.
    local stamps = displayRuntime.achievements
    if THEME.style == "hgss" and not session.battle and not session.externalLoading
        and displayRuntime.homeCatalog.packages.achievements.installed
        and (stamps.job or stamps.stale) and hasDisplay() and screenState() == "active" then
      displayRuntime.perf:call("stamps_album", displayRuntime.updateAchievements, now)
    end
    if now >= session.nextPoll then
      local pollStarted = displayRuntime.perf:start()
      session.nextPoll = now + 0.05
      refreshTheme()
      displayRuntime.perf:call("battle_snapshot", refreshBattle)
      displayRuntime.syncTouchGuard()
      if not inline and not phoneMode and not displayRuntime.notesShown() then
        for _ = 1, 32 do
          local event = session.companion.pollTouch()
          if not event then break end
          if not bottomOnHandheld() then
            touchEvent(event, session.canvas:getWidth(), session.canvas:getHeight())
          end
          if moduleShown() then break end
        end
      end
      if session.toolArmed and session.page ~= "TOOLS" then session.toolArmed = nil end
      if displayRuntime.needsTools() then displayRuntime.perf:call("tools", refreshTools) end
      local mode, top = screenState()
      if session.page == "POKEDEX" and displayRuntime.pokedex.view == "habitat"
          and not session.battle and mode == "active" then
        local selected = displayRuntime.pokedexData().bySpecies[displayRuntime.pokedex.selected]
        if selected then displayRuntime.pokedexHabitatPlan(selected) end
      elseif session.page == "ACHIEVEMENTS" and displayRuntime.achievements.view == "habitat"
          and displayRuntime.achievements.habitat and not session.battle and mode == "active" then
        displayRuntime.pokedexHabitatPlan(displayRuntime.achievements.habitat)
      end
      if displayRuntime.perf.enabled then
        displayRuntime.perf:setContext(string.format(
          "gen%d/%s/%s/%s/%s/%s/%s", displayRuntime.sourceGame.generation or (compat.isGen2() and 2 or 1),
          session.page, top and (top.screenId or (top.isTextBox and "text")) or mode,
          mod.options:get("theme_v3") or THEME.style,
          THEME:displayMode(mod.options) == "phone"
            and (displayRuntime.phone and displayRuntime.phone:detected() and "phone-connected" or "phone-waiting")
            or inline and "inline" or bottomOnHandheld() and "game-transfer" or "gear-transfer",
          mod.options:get("map_motion") or "quality", session.mapId or "unknown"))
      end
      if session.partyMoveFrom and (session.page ~= "PARTY" or not mod.world
          or not mod.world.canReorderParty or not mod.world:canReorderParty()) then
        session.partyMoveFrom, session.dirty = nil, true
      end
      if session.partyActionSlot and (session.page ~= "PARTY" or mode ~= "active"
          or not (session.game.save.party or {})[session.partyActionSlot]) then
        session.partyActionSlot, session.dirty = nil, true
      end
      if session.partyActionSlot and THEME.style == "hgss"
          and THEME.hgss:partyActionClosed(now) then
        session.partyActionSlot, session.dirty = nil, true
      end
      if displayRuntime.bag.pending and mode == "active" then
        displayRuntime.bag.pending, session.dirty = nil, true
      end
      local learn = displayRuntime.moveLearnScreen()
      local currentPcList = pcList()
      local currentChoice, _, currentChoiceField = dialogueChoice()
      if trackChoice(currentChoice, now) then session.dirty = true end
      if session.choiceNudgeUntil > 0 and now >= session.choiceNudgeUntil then
        session.choiceNudgeUntil = 0
        session.dirty = true
      end
      if session.radarOpen and session.radarFrame < RADAR_FRAMES then
        local frame = math.min(RADAR_FRAMES,
          math.floor(math.max(0, now - session.radarStarted) / 0.05))
        if frame ~= session.radarFrame then session.radarFrame, session.dirty = frame, true end
      end
      displayRuntime.advanceExplorerScan(now)
      if displayRuntime.pendingPartyItem then displayRuntime.stepPartyItem() end
      local nativeMenu = displayRuntime.startMenu()
      local startCursor = displayRuntime.StartMenu.cursor(nativeMenu or top)
      displayRuntime.startMenuIndex = startCursor and startCursor.index or nil
      local screenKey = table.concat({ mode, tostring(top),
        tostring(session.page), tostring(session.guidePage), tostring(session.areaPage),
        session.page == "BAG" and tostring(displayRuntime.recentItem.id) or "",
        session.page == "BAG" and tostring((session.game.save.inventory or {})[displayRuntime.recentItem.id]) or "",
        compat.summary.redrawKey(displayRuntime.summaryContext(), session.game, displayRuntime.gen3),
         tostring(displayRuntime.explorer.view),
         tostring(displayRuntime.explorer.selected),
         tostring(displayRuntime.explorer.page),
         tostring(displayRuntime.explorer.detailPage),
         tostring(displayRuntime.explorer.mapFull),
         tostring(displayRuntime.explorer.mapZoom),
        tostring(displayRuntime.explorer.filters.wildScope),
        tostring(displayRuntime.explorer.scanFrame),
        tostring(displayRuntime.pokedex.view),
        tostring(displayRuntime.pokedex.selected),
        tostring(displayRuntime.pokedex.page),
        tostring(displayRuntime.pokedex.habitatPage),
        tostring(displayRuntime.pokedex.movePage),
        tostring(displayRuntime.pokedex.descriptionPage),
        tostring(session.radarOpen),
         tostring(top and top.waiting), tostring(top and top.done), tostring(top and top.ready),
         tostring(top and top.index), tostring(top and top.kind),
         tostring(displayRuntime.startMenuIndex),
         displayRuntime.StartMenu.redrawKey(nativeMenu or top),
         tostring(currentChoice and compat.choiceIndex(
           currentChoice, currentChoiceField)),
         tostring(top and top.row), tostring(top and top.col), tostring(top and top.lower),
         tostring(top and type(top.glyphs) == "table"
           and table.concat(top.glyphs)),
         tostring(top and top.qty), tostring(top and top.page),
         tostring(top and top.moveDetail), tostring(top and top.moveIndex),
         tostring(top and top.mon),
        tostring(currentPcList), displayRuntime.pcStateKey(currentPcList),
        displayRuntime.pcStateKey(top),
        tostring(learn and learn.selecting),
        tostring(learn and learn.index), tostring(session.externalLoading),
        tostring(displayRuntime.bag.pending
          and displayRuntime.bag.pending.itemId),
        tostring(displayRuntime.bag.pending
          and displayRuntime.bag.pending.mon),
        tostring(session.pendingFly and session.pendingFly.id),
        tostring(session.pendingAction and session.pendingAction.id),
        tostring(session.partyActionSlot), tostring(session.partyMoveFrom),
        tostring(session.trainerStepsOpen), tostring(session.battleInfoDetail), tostring(displayRuntime.enemyInfoSelection),
        tostring(displayRuntime.guideDetail
          and displayRuntime.guideDetail.species),
        tostring(displayRuntime.guideDetail and displayRuntime.guideDetail.page),
        tostring(session.game.world and (session.game.world.tod or session.game.world.daytime)),
        tostring(session.fieldChoice and session.fieldChoice.kind),
        tostring(session.fieldChoice and session.fieldChoice.source
          and session.fieldChoice.source.slot) }, ":")
      if session.battle and customBattleLayout() and session.battle.prompt == "advance" then
        screenKey = screenKey .. ":" .. tostring(math.floor(now * 4))
      end
      if session.page == "LOCAL" and mod.world and mod.world.current then
        if THEME.style ~= "hgss" then
          local pos = mod.world:current()
          screenKey = screenKey .. ":" .. tostring(pos and pos.facing)
        end
        screenKey = screenKey .. ":" .. displayRuntime.fruitTrees.stateKey(session.game.save,
            displayRuntime.explorer.data and displayRuntime.explorer.data.fruits)
      end
      if session.page == "PARTY" or session.page == "HOME" then
        local pokerus = {}
        for _, mon in ipairs(session.game.save.party or {}) do pokerus[#pokerus + 1] = tostring(mon.pokerus) end
        local key = table.concat(pokerus, ":")
        if key ~= displayRuntime.partyPokerusKey then
          displayRuntime.partyPokerusKey, displayRuntime.home.widgetCache = key, nil
          session.dirty = true
        end
      end
      if screenKey ~= session.lastScreenKey or mode == "transition" then
        session.lastScreenKey, session.dirty = screenKey, true
      end
      displayRuntime.perf:finish("screen_poll", pollStarted)
    end
    if THEME.style == "hgss"
        and THEME.hgss:partyActionAnimating(now) then session.dirty = true end
    if hgssRuntime.animation then
      local started = hgssRuntime.animation.started
      local queued = hgssRuntime.animation.queued or now
      if started and now - started < hgssRuntime.animation.duration
          or not started and now - queued
            < hgssRuntime.animation.duration + 0.5 then
        session.dirty = true
      else
        hgssRuntime.animation, session.dirty = nil, true
      end
    end
    if displayRuntime.motion.started then session.dirty = true end
    -- Asset readiness must repaint even with animations disabled. Retry only
    -- while a visible portrait is waiting for the provider's background bake.
    if displayRuntime.frontArtRetryAt and now >= displayRuntime.frontArtRetryAt then
      displayRuntime.frontArtRetryAt, session.dirty = nil, true
    end
    if THEME.style == "hgss" and THEME.hgss.ambientDue
        and THEME.hgss:ambientDue(now) then session.dirty = true end
    if not displayRuntime.bootWarm.finished and screenState() == "title"
        and displayRuntime.bootWarmStep() then session.dirty = true end
    displayRuntime.updateStepRefresh(now)
    if now >= session.nextClock then
      local title = screenState() == "title"
      session.nextClock = now + (title and 0.5
        or session.batteryAnimated and 1 or 5)
      session.dirty = true
    end
    local displayAvailable = hasDisplay()
    if not displayAvailable then
      displayRuntime.notes:suspend()
      displayRuntime.perf:call("notes_flush", displayRuntime.notes.flush, displayRuntime.notes, true)
      if not inline and displayRuntime.swapped ~= nil then
        displayRuntime.swapped = nil
        resetSwapState()
        mod.log:info("screen disconnected: restored saved layout")
      end
      if session.gameReadbackPending and session.gameReadbackCanvas
          and displayRuntime.perf:call("readback_poll", session.gameReadbackCanvas.pollImageData, session.gameReadbackCanvas) then
        session.gameReadbackPending = false
        session.gameReadbackCanvas = nil
      end
      session.displayReady = false
      session.touchDown = nil
      session.textSpeedReleasePending = false
      holdTextSpeed(false)
    end
    if displayAvailable and not session.displayReady then session.dirty = true end
    local fullPaint = session.dirty
    displayRuntime.mapRefresh.only = displayRuntime.perf:call(
      "map_refresh", displayRuntime.updateMapRefresh, now) and not fullPaint
    if moduleShown() then
      displayRuntime.perf:finish("gear_compose", measured, excluded)
      return handled
    end
    if inline and displayRuntime.mapRefresh.only then
      -- The window was already composed by next(). Update its retained texture
      -- now, before another input tick can invalidate this movement-only hint.
      draw()
      session.dirty = false
    elseif not inline and bottomOnHandheld() then
      if session.dirty or session.readbackPending then pumpDisplay() end
    elseif not inline and (session.dirty or session.readbackPending)
        and (session.readbackPending or displayAvailable
        or now >= session.nextPresentAttempt) then
      local shown = pumpDisplay()
      if shown and not session.loggedPresent then
        session.loggedPresent = true
        mod.log:info("first frame submitted=true")
      end
    end
    displayRuntime.perf:finish("gear_compose", measured, excluded); return handled
  end, -1000)
end
