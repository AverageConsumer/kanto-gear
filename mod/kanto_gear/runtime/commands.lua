return function(
  HEADER, THEME, displayRuntime, hgssRuntime, mod, refreshBattle,
  refreshTools, session
)
  local function submit(kind, fields)
    if not (session.battle and mod.battle) then return end
    if displayRuntime.touchDispatch then displayRuntime.touchGuard.pending = true end
    session.intentId = session.intentId + 1
    fields = fields or {}
    -- Game path [Gen 3]: Safari actions use the native command menu intent/order instead of the legacy safari submission kind.
    if displayRuntime.gen3 and kind == "safari" then
      local actions = displayRuntime.SafariPage.model(session.battle)
      for index = 1, #actions.actions do
        if displayRuntime.SafariPage.action(actions, index) == fields.action then
          fields.choice = ({ "fight", "item", "party", "run" })[index]
          break
        end
      end
      if not fields.choice then return end
      kind = "menu"
    end
    fields.id, fields.revision, fields.kind = session.intentId, session.battle.revision, kind
    local ok, err = mod.battle:submit(fields)
    if not ok then mod.log:warn("battle intent %s rejected: %s", kind, err) end
    if ok and kind ~= "back" then displayRuntime.haptic("confirm") end
    displayRuntime.perf:call("battle_snapshot", refreshBattle)
  end

  local function back()
    if displayRuntime.guideDetail then
      displayRuntime.guideDetail = nil
    elseif session.battleInfoDetail then
      session.battleInfoDetail = nil
    elseif displayRuntime.enemyInfoSelection ~= nil then
      displayRuntime.enemyInfoSelection = nil
    elseif session.moveInfo then
      if session.battle and session.battle.prompt == "moves" then
        hgssRuntime.beginAnimation("battle_move_info_close")
      end
      session.moveInfo = nil
    elseif session.battle and session.battle.prompt == "moves" then
      submit("back")
    end
    session.dirty = true
  end

  local function press(key)
    if displayRuntime.touchDispatch then displayRuntime.touchGuard.pending = true end
    mod.input:tap(displayRuntime.sourceGame or session.game, key)
  end

  function displayRuntime.tapPpItemMoves(menu, x, y)
    if menu.enabled == false or menu.valid and not menu.valid() then return end
    local action
    if THEME.style == "hgss" then
      action = displayRuntime.MovePage.hit(displayRuntime.moveSelectionModel(menu), x * THEME.hgssScale, y * THEME.hgssScale)
    elseif y < HEADER and x < 24 then action = "back"
    else
      local row = math.floor((y - 25) / 28) + 1
      if x >= 8 and x < 152 and row >= 1 and row <= #menu.items then action = row end
    end
    if action == "back" then press("b")
    elseif type(action) == "number" then
      (menu.native or menu)[menu.cursor or "index"] = action
      press("a")
    end
    if action then session.dirty = true end
  end


  function displayRuntime.summaryInput(summary, key)
    if THEME.style == "hgss" then
      local state = displayRuntime.summaryContext(summary)
      if not state then return end
      if key == "left" or key == "right" then
        displayRuntime.SummaryPage.turn(state, key == "left" and -1 or 1)
        session.moveInfo, hgssRuntime.animation, session.dirty = nil, nil, true
        return
      elseif key == "b" and state == displayRuntime.localSummary then
        displayRuntime.localSummary, session.moveInfo, session.dirty = nil, nil, true
        return
      end
    end
    -- Gen 1's original Back advances first; explicitly closing its native menu
    -- uses the existing second-page close path.
    local native = summary.owner or summary
    if native.screenId == "SummaryMenu" and key == "b" then native.page = 2 end
    press(key)
  end

  local function holdTextSpeed(held)
    if held == (session.textSpeedToken ~= nil) then return end
    if held then session.textSpeedToken = mod.input:press(displayRuntime.sourceGame or session.game, "a")
    else mod.input:release(session.textSpeedToken); session.textSpeedToken = nil end
  end

  local function useTool(action, opts)
    local world = displayRuntime.gen3Field or mod.world
    local ok, err = world:useFieldAction(action.id, opts)
    if not ok then mod.log:warn("field action %s rejected: %s",
      tostring(action.id), tostring(err)) end
    displayRuntime.perf:call("tools", refreshTools)
    session.dirty = true
  end

  -- `confirmed` skips the Dig/Teleport prompt once the Field Kit card has
  -- already taken its second tap.
  function displayRuntime.activateTool(action, rodId, confirmed)
    if not action then return false end
    if rodId then
      useTool(action, { rod = rodId })
    elseif action.id == "fly" and THEME.style == "hgss" then
      session.page, displayRuntime.regionCursor.fly, displayRuntime.regionCursor.selected = "MAP", true, false
    elseif (action.id == "dig" or action.id == "teleport") and not confirmed then
      session.pendingAction = action
    elseif action.id == "fish" and #(action.rods or {}) > 1 then
      session.fieldChoice = { kind = "fish", action = action }
    elseif action.id == "fish" then
      useTool(action, { rod = action.rods[1].id })
    elseif action.id == "softboiled" then
      if #(action.sources or {}) == 1 then
        session.fieldChoice = { kind = "soft_target", action = action,
          source = action.sources[1] }
      else
        session.fieldChoice = { kind = "soft_source", action = action }
      end
    else
      useTool(action)
    end
    session.dirty = true
    return true
  end

  return back, holdTextSpeed, press, submit, useTool
end
