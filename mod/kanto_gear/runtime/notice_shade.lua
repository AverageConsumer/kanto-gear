-- The notification drawer owns one continuous gesture above the current app.
-- It never changes game input or replaces the app's navigation state.
return function(THEME, display, header, render, screenState, session)
  local state = display.notices
  local G, HEIGHT = render.G, 216
  local function now() return love.timer.getTime() end
  local function motion() return not display.motionEnabled or display.motionEnabled() end
  local function allowed()
    local home = display.home
    return THEME.style == "hgss" and session.active and session.game and not session.battle
      and screenState() == "active" and not display.displaySetupModal
      and not display.gearModules.anyShown() and not display.homeHelpActive()
      and not session.moveInfo and not session.pendingFly and not session.pendingAction
      and not session.fieldChoice and not session.radarOpen and not session.partyActionSlot
      and not session.partyMoveFrom and not display.localSummary
      and not (session.page == "NOTES" and (display.notes.down or display.notes.colorOpen
        or display.notes.view == "edit" or display.notes.view == "draw"))
      and not home.editing and not home.library and not home.storeConfirm and not home.storeReceived
      and not (display.pss and (display.pss.incoming or display.pss.pending or display.pss.activity))
  end
  display.noticeShadeAllowed = allowed

  function display.noticeShadeActive() return state.shade ~= nil end
  function display.noticeShadeOwnsTouch() return state.shadeGesture ~= nil end

  local function settle(target)
    local shade = state.shade
    if not shade then return end
    shade.from, shade.target, shade.at = shade.height, target, now()
    if not motion() or shade.height == target then
      shade.height, shade.at = target, nil
      if target == 0 then state.shade, state.clearPending = nil, true end
    end
    session.dirty = true
  end

  local function releaseRow(gesture, dx, commit)
    local shade = state.shade
    if not shade then return end
    local removed = commit and math.abs(dx) >= 54 and display.readNoticeHistory(gesture.entry)
    if not motion() then return end
    local offset = gesture.offset or 0
    if removed or offset ~= 0 then
      shade.rowMotion = { model = gesture.model, index = gesture.row, at = now(),
        duration = removed and 0.16 or 0.12, from = offset, offset = offset,
        target = removed and (dx < 0 and -246 or 246) or 0 }
    end
  end

  function display.openNoticeShade()
    if not allowed() then return false end
    local shade = { height = 0, page = session.page }
    state.shade = shade
    state.historyPage = math.max(1, math.ceil(#state.history / 3))
    display.motion.started, display.motion.cached = nil, nil
    settle(HEIGHT)
    return true
  end

  function display.tickNoticeShade(time)
    local shade = state.shade
    if not shade then return false end
    if not allowed() or shade.page ~= session.page then
      state.shade, state.clearPending = nil, true
      if state.shadeGesture then state.shadeGesture.cancelled = true end
      session.dirty = true
      return true
    end
    local changed, row = false, shade.rowMotion
    if row then
      local p = motion() and math.min(1, math.max(0, (time - row.at) / row.duration)) or 1
      row.offset = row.from + (row.target - row.from) * (1 - (1 - p) ^ 3)
      if p == 1 then shade.rowMotion = nil end
      changed = true
    end
    if not shade.at then return changed end
    local p = motion() and math.min(1, math.max(0, (time - shade.at) / 0.18)) or 1
    shade.height = shade.from + (shade.target - shade.from) * (1 - (1 - p) ^ 3)
    if p == 1 then
      shade.at = nil
      if shade.target == 0 then state.shade, state.clearPending = nil, true end
    end
    return true
  end

  function display.noticeShadeTouch(action, x, y)
    local gesture, shade = state.shadeGesture, state.shade
    if gesture then
      if not allowed() or shade and shade.page ~= session.page then
        gesture.cancelled, state.shade, state.clearPending = true, nil, true
      end
      local dx, dy = (x or gesture.x) - gesture.x, (y or gesture.y) - gesture.y
      if not gesture.cancelled and shade and (action == "move" or action == "moved" or action == "up") then
        gesture.distance = math.max(gesture.distance or 0, math.abs(dx), math.abs(dy))
        if not gesture.axis and gesture.distance > 6 then
          gesture.axis = math.abs(dy) > math.abs(dx) * 1.25 and "y" or "x"
        end
        if gesture.axis == "y" then
          shade.at = nil
          if motion() then shade.height = math.max(0, math.min(HEIGHT, gesture.height + dy)) end
        elseif gesture.axis == "x" and gesture.entry and motion() then
          gesture.offset = math.max(-240, math.min(240, dx))
        end
      end
      if action == "up" or action == "cancel" then
        state.shadeGesture = nil
        if not gesture.cancelled and shade then
          if action == "cancel" and gesture.entry and gesture.axis == "x" then releaseRow(gesture, dx, false)
          elseif action == "cancel" then settle(gesture.open and HEIGHT or 0)
          elseif gesture.axis == "y" then
            local distance = math.max(0, math.min(HEIGHT, gesture.height + dy))
            settle(gesture.open and (distance < HEIGHT - 36 and 0 or HEIGHT)
              or (distance >= 36 and HEIGHT or 0))
          elseif not gesture.open then
            settle(0)
            if action == "up" and gesture.axis == "x" and math.abs(dx) >= 24 then
              display.noticeShadeHeaderSwipe(dx, gesture.x, gesture.y)
            elseif action == "up" and (gesture.distance or 0) <= 6 and x and y then
              display.noticeShadeHeaderTap(x, y)
            end
          elseif gesture.axis == "x" and gesture.entry then
            releaseRow(gesture, dx, true)
          elseif gesture.axis == "x" and math.abs(dx) >= 24 then
            display.cycleNoticeHistory(dx < 0 and 1 or -1)
          elseif (gesture.distance or 0) <= 6 and x and y then
            local model = display.noticeHistoryModel(); model.shade = true
            local action, index = THEME.hgss:noticeHistoryHit(x, y, model)
            if action == "back" or y >= 205 then settle(0)
            elseif action == "prev" or action == "next" then
              display.cycleNoticeHistory(action == "next" and 1 or -1)
            elseif action == "row" then
              if display.openHomeApp(model.rows[index].entry.app) then
                state.shade, state.clearPending = nil, true
                display.markNoticeRead(model.rows[index].entry.app)
              end
            end
          end
        end
      end
      session.dirty = true
      return true
    end
    if shade then
      if action == "down" and x and y then
        local open = shade.height == HEIGHT and not shade.at and not shade.rowMotion
        local model = open and display.noticeHistoryModel() or nil
        if model then model.shade = true end
        local index = model and THEME.hgss:noticeHistoryRowAt(x, y, model)
        state.shadeGesture = { x = x, y = y, height = shade.height, open = open,
          cancelled = shade.at ~= nil or shade.rowMotion ~= nil,
          model = model, row = index, entry = index and model.rows[index].entry }
      elseif action == "tap" and x and y and not shade.at then
        display.noticeShadeTouch("down", x, y)
        display.noticeShadeTouch("up", x, y)
      end
      return true
    end
    if action ~= "down" or not x or not y or x < 27 or y >= 29 or not allowed()
        or session.touchDown or display.noticeOwnsTouch("canvas") then return false end
    local guard = display.syncTouchGuard()
    if not guard:allow(now()) then return false end
    state.shade = { height = 0, page = session.page }
    state.historyPage = math.max(1, math.ceil(#state.history / 3))
    state.shadeGesture = { x = x, y = y, height = 0, open = false }
    display.motion.started, display.motion.cached = nil, nil
    session.dirty = true
    return true
  end

  -- Drawn after the app and notice card, in the 240x216 Gear coordinate space.
  function display.drawNoticeShade()
    local shade = state.shade
    if not shade then
      if allowed() then THEME.hgss:noticeShadeHandle(27, false) end
      return
    end
    if shade.height <= 0 then return end
    local gesture, row = state.shadeGesture, shade.rowMotion
    local dragging = gesture and gesture.entry and gesture.axis == "x" and not gesture.cancelled
    local model = row and row.model or dragging and gesture.model or display.noticeHistoryModel()
    model.shade = true
    model.rowOffsets = row and { [row.index] = row.offset }
      or dragging and { [gesture.row] = gesture.offset or 0 } or nil
    local theme = THEME.hgss
    local tx, ty, enabled = theme.touchX, theme.touchY, theme.touchEnabled
    local pressed = gesture and gesture.open and not gesture.axis and not gesture.cancelled
    theme:setTouch(pressed and gesture.x, pressed and gesture.y, pressed or false)
    G.push("all")
    G.setColor(0, 0, 0, 0.35 * shade.height / HEIGHT); G.rectangle("fill", 0, 0, 240, HEIGHT)
    G.push("all")
    if G.transformPoint and G.intersectScissor then
      local x, y = G.transformPoint(0, 0)
      local right, bottom = G.transformPoint(240, math.floor(shade.height + 0.5))
      G.intersectScissor(x, y, right - x, bottom - y)
    end
    G.setColor(theme.colors.surface); G.rectangle("fill", 0, 0, 240, HEIGHT)
    theme:v4Backdrop(1)
    G.push(); G.scale(THEME.hgssScale, THEME.hgssScale)
    header(THEME:translate("NOTIFICATIONS"), true, false)
    G.pop()
    theme:noticeHistory(model)
    local edge = math.floor(shade.height + 0.5)
    G.setColor(theme.colors.surface); G.rectangle("fill", 0, edge - 9, 240, 9)
    theme:noticeShadeHandle(edge - 7, true)
    G.pop()
    G.pop()
    theme:setTouch(tx, ty, enabled)
  end
end
