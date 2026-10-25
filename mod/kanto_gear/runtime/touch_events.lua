return function(
  HEIGHT, THEME, WIDTH, battleState, compat, currentBattleUIMode,
  dialogueChoice, displayRuntime, hgssRuntime, holdTextSpeed, mod, pageSwipeAllowed,
  pcSession, refreshBattle, screenContract, screenState, session, swipe,
  swipeVertical, tap, textTouch
)
  function displayRuntime.updateHomeLongPress(now)
    local down = session.touchDown
    if not down or down.blockedUntilRelease or not down.homeTile
        or THEME.style ~= "hgss" or session.page ~= "HOME"
        or displayRuntime.home.editing
        or displayRuntime.homeHelpActive() then return false end
    local dx = ((down.currentX or down.x) - down.x) * THEME.hgssScale
    local dy = ((down.currentY or down.y) - down.y) * THEME.hgssScale
    if not displayRuntime.Home.longPress(now - down.at, dx, dy) then
      return false
    end
    displayRuntime.home.editing = true
    displayRuntime.home.swapSource = nil
    down.blockedUntilRelease = true
    displayRuntime.haptic("hold")
    session.dirty = true
    return true
  end

  function displayRuntime.syncTouchGuard()
    local mode, top = screenState()
    local raw = battleState()
    local text = textTouch(top) ~= nil or raw and top == raw
      and raw.phase ~= "menu" and raw.phase ~= "moves" and raw.phase ~= "moveSelect"
      and raw.phase ~= "choose-forget" and raw.phase ~= "stats-box"
      and raw.phase ~= "mimicSelect"
      and (raw.phase == "messages" or raw.message ~= nil) or false
    local nativeMenu = displayRuntime.startMenu()
    local key = table.concat({ tostring(top), text and "text" or tostring(top and top.phase),
      tostring(top and top.submenu), tostring(top and top.page),
      tostring(top and top.lower),
      tostring(mod.options:get("keyboard_layout")),
      tostring(top and top.kind), tostring(top and top.mode),
      tostring(top and top.activeBattler), tostring(nativeMenu and nativeMenu.nativeKey),
      tostring(top and top.picking), tostring(top and top.qtyState),
      tostring(top and top.confirm), tostring(top and top.selecting),
      tostring(not text and top and top.message ~= nil),
      tostring(session.moveInfo), tostring(session.fieldChoice), tostring(session.pendingFly), tostring(session.battleInfoDetail), tostring(displayRuntime.enemyInfoSelection),
      tostring(session.partyActionSlot), tostring(displayRuntime.localSummary),
      tostring(displayRuntime.localSummary and displayRuntime.localSummary.page),
      tostring(displayRuntime.nativeSummary and displayRuntime.nativeSummary.page), tostring(session.page), tostring(mode),
      tostring(session.page == "MAP" and displayRuntime.regionCursor.fly), tostring(session.page == "MAP" and session.mapId),
      tostring(displayRuntime.touchChoice and displayRuntime.touchChoice.page),
      tostring(session.page == "PSS" and (displayRuntime.pss.state .. ":"
        .. tostring(displayRuntime.pss.inUse) .. ":" .. tostring(displayRuntime.pss.selected)
        .. ":" .. displayRuntime.pss.page)),
      tostring(displayRuntime.StartMenu.window(nativeMenu or top)),
      tostring(displayRuntime.autoBattle.shown) }, ":")
    if session.battle and currentBattleUIMode() == "info" then
      key = "battle-info:" .. tostring(raw) .. ":" .. tostring(displayRuntime.enemyInfoSelection)
        .. ":" .. tostring(session.battleInfoDetail)
      text = false
    end
    displayRuntime.touchGuard:sync(key, text, love.timer.getTime())
    local animation = hgssRuntime.animation
    if not text and animation then
      displayRuntime.touchGuard.readyAt = math.max(displayRuntime.touchGuard.readyAt,
        (animation.started or animation.queued or love.timer.getTime()) + animation.duration)
    end
    if not text and session.textSpeedToken then
      session.textSpeedReleasePending = false
      holdTextSpeed(false)
    end
    return displayRuntime.touchGuard
  end

  function displayRuntime.dispatchTouchTap(fn, x, y)
    -- Pointer hooks can run between the regular 50ms snapshots. Never send
    -- an old "advance" action to a battle that has already reached its menu.
    if battleState() then displayRuntime.perf:call("battle_snapshot", refreshBattle) end
    displayRuntime.motion.started, displayRuntime.motion.cached = nil, nil
    displayRuntime.touchDispatch = true
    fn(x, y)
    displayRuntime.touchDispatch = false
    displayRuntime.syncCompanionDetails()
    displayRuntime.syncTouchGuard()
  end

  local function touchEvent(value, sourceWidth, sourceHeight)
    if displayRuntime.gearModules.anyShown()
        and not (displayRuntime.noticeOwnsTouch and displayRuntime.noticeOwnsTouch("canvas")) then return end
    local action, sx, sy = value:match("^(%a+),(%d+),(%d+)$")
    local x, y = tonumber(sx), tonumber(sy)
    if not action then
      sx, sy = value:match("^(%d+),(%d+)$")
      x, y, action = tonumber(sx), tonumber(sy), "tap"
    end
    -- The topmost card owns its whole gesture before page controls, Notes,
    -- long-press detection or legacy coordinate quantization can see it.
    local noticeX = x and x * 240 / (sourceWidth or WIDTH)
    local noticeY = y and y * 216 / (sourceHeight or HEIGHT)
    if displayRuntime.noticeCanvasTouch and displayRuntime.noticeCanvasTouch(action, noticeX, noticeY) then
      return
    end
    -- Notes consumes continuous input before the legacy 160x144 quantization
    -- and before swipe recognition. All other Gear pages keep their contract.
    if displayRuntime.notesShown() then
      if x then
        x = x * 240 / (sourceWidth or WIDTH)
        y = y * 216 / (sourceHeight or HEIGHT)
      end
      displayRuntime.notesPointer(action, x, y)
      session.touchDown = nil
      return
    end
    local mapX, mapY = x and x * 240 / (sourceWidth or WIDTH), y and y * 216 / (sourceHeight or HEIGHT)
    if x and sourceWidth and sourceHeight then
      x = math.max(0, math.min(WIDTH - 1,
        math.floor(x * WIDTH / sourceWidth)))
      y = math.max(0, math.min(HEIGHT - 1,
        math.floor(y * HEIGHT / sourceHeight)))
    end
    local guard = displayRuntime.syncTouchGuard()
    if session.touchDown and session.touchDown.blockedUntilRelease then
      if action == "up" or action == "cancel" then
        session.touchDown = nil
        session.dirty = true
      end
      return
    end
    if action == "down" and x then
      session.textSpeedReleasePending = false
      holdTextSpeed(false)
      if not guard:allow(love.timer.getTime()) then
        session.touchDown = { blockedUntilRelease = true }
        return
      end
      local mode, top = screenState()
      local speed = not (session.battle and currentBattleUIMode() == "info") and textTouch(top) == "speed"
      session.touchDown = { x = x, y = y,
        epoch = guard.epoch,
        at = love.timer.getTime(),
        pageSwipe = displayRuntime.pageChoice() or pageSwipeAllowed(mode, session.battle)
          or THEME.style == "hgss" and not session.moveInfo
            and compat.isScreen(top, "summary"),
        textSpeed = speed,
        input = mode == "title" or mode == "active" or mode == "textbox" or session.battle
          or screenContract(top, "naming")
          or dialogueChoice() or displayRuntime.startMenu() or compat.isScreen(top, "summary")
          or displayRuntime.moveLearnScreen()
          or displayRuntime.fieldPpMoveScreen()
          or displayRuntime.fieldBagParty()
          or compat.levelUpMon(top) or displayRuntime.levelUp:fieldMon(top)
          or pcSession() }
      if mode == "active" and THEME.style == "hgss" and session.page == "HOME"
          and not displayRuntime.home.library
          and not displayRuntime.homeHelpActive() then
        local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
        local tile = displayRuntime.homeTileAt(hx, hy)
        local emptyHome = #(displayRuntime.home.layout.tiles or {}) == 0
        session.touchDown.homeTile = tile and tile.id
          or (emptyHome and hy >= 30 and "__empty" or nil)
      end
      session.touchDown.homeHelp = displayRuntime.homeHelpActive()
      if mode == "active" and not session.battle and session.page == "STORE" and THEME.style == "hgss"
          and displayRuntime.home.storeView == "apps" and not displayRuntime.home.storeConfirm
          and not displayRuntime.home.storeReceived then
        local _, _, current, pages = displayRuntime.storeSelection("apps")
        if pages > 1 then
          local _, _, _, _, thumbY, thumbH = THEME.hgss:storeScrollGeometry(current, pages)
          if THEME.hgss:storeScrollHit(mapX, mapY, pages) then
            session.touchDown.storeView, session.touchDown.storePages = "apps", pages
            session.touchDown.storeGrab = mapY >= thumbY and mapY < thumbY + thumbH and mapY - thumbY or thumbH / 2
            displayRuntime.dragStoreScroll(session.touchDown, mapY)
          end
        end
      end
      if mode == "active" and not session.battle and session.page == "MAP" and THEME.style == "hgss"
          and not session.pendingFly and not session.pendingAction and not session.fieldChoice then
        local model = displayRuntime.regionMapModel()
        if model.pick and displayRuntime.RegionPage.inside(model, mapX, mapY) then
          session.touchDown.mapModel, session.touchDown.mapX, session.touchDown.mapY = model, mapX, mapY
          displayRuntime.RegionPage.select(displayRuntime.regionCursor, model, mapX, mapY)
        elseif model.pick and displayRuntime.RegionPage.confirmHit(mapX, mapY) then
          session.touchDown.mapConfirm = true
        end
      end
      if speed then holdTextSpeed(true) end
      session.dirty = true
    elseif (action == "move" or action == "moved") and x and session.touchDown then
      session.touchDown.currentX, session.touchDown.currentY = x, y
      if session.touchDown.storeView and guard:allow(love.timer.getTime(), session.touchDown.epoch) then
        displayRuntime.dragStoreScroll(session.touchDown, mapY)
      end
      if session.touchDown.mapModel then
        session.touchDown.mapPointerX, session.touchDown.mapPointerY = mapX, mapY
        displayRuntime.RegionPage.select(displayRuntime.regionCursor, session.touchDown.mapModel, mapX, mapY)
        session.dirty = true
      end
    elseif action == "cancel" then
      session.textSpeedReleasePending = false
      holdTextSpeed(false)
      session.touchDown = nil
      displayRuntime.regionCursor.selected = false
      session.dirty = true
    elseif action == "tap" and x then
      -- Some hosts report down/tap/up for one gesture. Only its up may commit.
      if session.touchDown or not guard:allow(love.timer.getTime()) then return end
      local mode, top = screenState()
      if not (session.battle and currentBattleUIMode() == "info") and textTouch(top) == "speed" then
        holdTextSpeed(true)
        session.textSpeedReleasePending = true
      else
        displayRuntime.dispatchTouchTap(tap, x, y)
      end
    elseif action == "up" and x and session.touchDown then
      local down = session.touchDown
      local dx, dy = x - down.x, y - down.y
      session.touchDown = nil
      session.dirty = true
      if not guard:allow(love.timer.getTime(), down.epoch) then
        session.textSpeedReleasePending = false
        holdTextSpeed(false)
        return
      end
      if down.storeView then
        displayRuntime.dragStoreScroll(down, mapY)
        return
      end
      if down.mapModel then
        local state, Page = displayRuntime.regionCursor, displayRuntime.RegionPage
        Page.select(state, down.mapModel, mapX, mapY)
        return
      end
      if down.mapConfirm or session.page == "MAP" and THEME.style == "hgss"
          and displayRuntime.RegionPage.confirmHit(mapX, mapY) then
        if session.page == "MAP" and down.mapConfirm and displayRuntime.RegionPage.confirmHit(mapX, mapY)
            and math.abs(dx) < 12 and math.abs(dy) < 12 then
          displayRuntime.dispatchTouchTap(tap, x, y)
        end
        return
      end
      if down.homeHelp then
        if displayRuntime.homeHelpActive()
            and math.abs(dx) < 12 and math.abs(dy) < 12
            and THEME.hgss:homeHelpHit(down.x * THEME.hgssScale,
              down.y * THEME.hgssScale, displayRuntime.homePageElements()) then
          displayRuntime.tapHomeHelp(x * THEME.hgssScale, y * THEME.hgssScale)
        end
        return
      end
      if down.textSpeed then
        session.textSpeedReleasePending = true
        return
      end
      if math.abs(dx) >= 24 and math.abs(dx) > math.abs(dy) * 1.25 then
        if down.pageSwipe then
          displayRuntime.touchDispatch = true
          swipe(dx, down)
          displayRuntime.touchDispatch = false
          displayRuntime.syncTouchGuard()
        end
      elseif math.abs(dy) >= 24 and math.abs(dy) > math.abs(dx) * 1.25 then
        displayRuntime.touchDispatch = true
        swipeVertical(dy, down)
        displayRuntime.touchDispatch = false
        displayRuntime.syncTouchGuard()
      elseif (dialogueChoice() or displayRuntime.startMenu())
          and (math.abs(dx) >= 12 or math.abs(dy) >= 12) then
        return
      elseif down.input then
        displayRuntime.dispatchTouchTap(tap, x, y)
      end
      mod.log:info("touch up x=%d y=%d", x, y)
    end
  end

  return touchEvent
end
