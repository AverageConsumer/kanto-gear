return function(
  THEME, assist, back, battleState, bottomOwnsBattleUI, compat,
  customBattleLayout, dialogueChoice, displayRuntime, fullBottomBattleUI, hasDisplay, hgssRuntime,
  mod, screenContract, session
)
  function displayRuntime.bindBattleInput(sourceGame)
    local previous = displayRuntime.battleInput
    local input = sourceGame.input
    if previous and previous.input == input and previous.game == sourceGame then return end
    if previous then
      previous.enabled = false
      if previous.input.pollPads == previous.fn then previous.input.pollPads = previous.original end
    end
    displayRuntime.battleInput = nil
    if not input or type(input.pollPads) ~= "function" then return end
    local patch = { input = input, game = sourceGame, original = input.pollPads, enabled = true }
    patch.fn = function(self, ...)
      local result = patch.original(self, ...)
      if patch.enabled and self == sourceGame.input then
        if not displayRuntime.filterBattleDetailsInput(sourceGame) then
          displayRuntime.remapBattleSummaryInput(sourceGame)
          hgssRuntime.remapBattleRootInput(sourceGame)
          hgssRuntime.remapLearningInput(sourceGame)
        end
      end
      return result
    end
    input.pollPads = patch.fn
    displayRuntime.battleInput = patch
  end

  function hgssRuntime.remapBattleRootInput(stepGame)
    if stepGame ~= displayRuntime.sourceGame or THEME.style ~= "hgss"
        or displayRuntime.gen3 or not customBattleLayout() or not session.battle then return end
    local raw = battleState()
    local top = session.game.stack:top()
    local queue = stepGame and stepGame.input and stepGame.input.pressQueue
    if not raw or type(queue) ~= "table"
        or not bottomOwnsBattleUI(customBattleLayout(), session.active,
          hasDisplay(), session.displayReady, raw, session.battle) then return end
    local mimic = session.battle.prompt == "mimic"
    if not (session.battle.prompt == "menu" or mimic) or top ~= raw or raw.tutorial or raw.demo then return end
    for i = 1, #queue do
      local current = mimic and (raw.mimicIndex or 1) or raw.menuIndex or session.battle.menuIndex or 1
      local target
      if mimic then
        local count = #(raw.mimicMoves or session.battle.mimicMoves or {})
        if count > 0 then
          if queue[i] == "up" or queue[i] == "down" then
            target = (current - 1 + (queue[i] == "up" and -1 or 1)) % count + 1
          elseif queue[i] == "left" or queue[i] == "right" then target = current end
        end
      elseif fullBottomBattleUI() then
        target = hgssRuntime.fullRootDirection(current, queue[i])
      else
        target = hgssRuntime.rootDirection(current, queue[i])
      end
      if target then
        for key = #queue, 1, -1 do
          if queue[key] == "a" or hgssRuntime.rootDirection(current, queue[key]) then
            table.remove(queue, key)
          end
        end
        if mimic then raw.mimicIndex, session.battle.mimicIndex = target, target
        else raw.menuIndex, session.battle.menuIndex = target, target end
        session.dirty = true
        return true
      end
    end
  end

  -- Game path [Gen 1/2]: remap owned legacy learning prompts only; Gen 3s native adapter already owns its choice navigation.
  function hgssRuntime.remapLearningInput(stepGame)
    if stepGame ~= displayRuntime.sourceGame or displayRuntime.gen3
        or THEME.style ~= "hgss" or not session.battle or not customBattleLayout()
        or not bottomOwnsBattleUI(true, session.active, hasDisplay(), session.displayReady, battleState(), session.battle) then return end
    local queue = stepGame.input and stepGame.input.pressQueue
    if type(queue) ~= "table" then return end
    for _, key in ipairs(queue) do
      if key == "left" or key == "right" or key == "up" or key == "down" then
        local choice, labels, field = dialogueChoice()
        if not choice or #labels ~= 2 or not displayRuntime.learningChoiceContext(choice) then return end
        local index = key == "left" and 1 or key == "right" and 2 or compat.choiceIndex(choice, field)
        compat.choiceIndex(choice, field, index)
        for i = #queue, 1, -1 do
          if queue[i] == "a" or queue[i] == "left" or queue[i] == "right"
              or queue[i] == "up" or queue[i] == "down" then table.remove(queue, i) end
        end
        session.dirty = true
        return true
      end
    end
  end

  function hgssRuntime.openingBattlePanel(stepGame)
    if stepGame ~= displayRuntime.sourceGame or THEME.style ~= "hgss"
        or not session.battle or session.battle.prompt ~= "menu" then return false end
    local raw = battleState()
    local queue = stepGame and stepGame.input and stepGame.input.pressQueue
    if not raw or session.game.stack:top() ~= raw or type(queue) ~= "table"
        or not bottomOwnsBattleUI(customBattleLayout(), session.active,
          hasDisplay(), session.displayReady, raw, session.battle) then return false end
    local index = raw.menuIndex or session.battle.menuIndex or 1
    local kind = index == 1 and "battle_moves"
      or index == 2 and "battle_party"
      or index == 3 and "battle_bag" or nil
    if not kind then return false end
    for i = 1, #queue do
      if queue[i] == "a" then return kind end
    end
    return false
  end

  function hgssRuntime.closingBattlePanel(stepGame)
    if stepGame ~= displayRuntime.sourceGame or THEME.style ~= "hgss" or not session.battle then return end
    local raw, top = battleState(), session.game.stack:top()
    local queue = stepGame and stepGame.input and stepGame.input.pressQueue
    if not raw or type(queue) ~= "table"
        or not bottomOwnsBattleUI(customBattleLayout(), session.active,
          hasDisplay(), session.displayReady, raw, session.battle) then return end
    local kind
    if compat.battleBagMenu(top) then kind = "battle_bag_close"
    else
      local party = screenContract(top, "party")
      if party and not party.submenu then kind = "battle_party_close"
      elseif top == raw and session.battle.prompt == "moves" then
        kind = "battle_moves_close"
      end
    end
    if not kind then return end
    for i = 1, #queue do
      if queue[i] == "b" then return kind end
    end
  end

  mod.hooks:wrap("item.use", function(next, useGame, ...)
    local id = select(2, ...)
    local ours = useGame == displayRuntime.sourceGame or useGame == session.game
    if ours then
      if displayRuntime.gen3 then
        id = displayRuntime.gen3.Items.toNumericId(id)
        displayRuntime.gen3:refresh()
      end
      displayRuntime.recentItem:watch(session.game.save, id)
    end
    local function capture(...) return { n = select("#", ...), ... } end
    local result = capture(next(useGame, ...))
    local a, b = result[1], result[2]
    if ours then
      if displayRuntime.gen3 then displayRuntime.gen3:refresh() end
      if displayRuntime.recentItem:poll(session.game.save) then session.dirty = true end
      -- Game path [Gen 3]: reusable tools report success directly; merely opening TM/berry containers or target prompts is not completed use.
      -- Reusable Gen3 field tools report success directly; opening a
      -- container or a target/teaching prompt is not successful use.
      if displayRuntime.gen3 and a == true and b ~= "tm" and b ~= "tm_case"
          and b ~= "berry_pouch" then
        if displayRuntime.recentItem:remember(session.game.save, id) then session.dirty = true end
      end
    end
    return unpack(result, 1, result.n)
  end)

  -- Game path [Gen 1/2/3]: observe each native bags USE context; deposits, shops, berry actions and giving items cannot become recent successful uses.
  function displayRuntime.observeBagInput()
    local queue = displayRuntime.sourceGame and displayRuntime.sourceGame.input
      and displayRuntime.sourceGame.input.pressQueue or {}
    local confirms = false
    for _, key in ipairs(queue) do if key == "a" then confirms = true end end
    if not confirms then return end
    local top = session.game and session.game.stack and session.game.stack:top()
    if top and top.screenId == "Gen2PackMenu" then
      if not top.submenu then displayRuntime.recentItem.pending = nil end
      local submenu = top.submenu
      local row = submenu and submenu.row or (top.rows or {})[top.index]
      local action = submenu and submenu.rows and submenu.rows[submenu.index]
      if action and action ~= "use" then displayRuntime.recentItem.pending = nil
      elseif not top.give and not top.qtyState and not top.confirm then
        displayRuntime.recentItem:watch(session.game.save, row and row.id)
      end
    elseif displayRuntime.gen3Ui then
      local layer = displayRuntime.gen3Ui.Stack.top()
      if layer and (layer.id == "bag" or layer.id == "berry_pouch" or layer.id == "tm_case") then
        local native = layer.mod
        if native._location == "shop" or native._location == "itempc"
            or native._location == "berry_tree" or native._location == "blender"
            or native._fromBerryCrush or native.holdingMon then
          displayRuntime.recentItem.pending = nil
          return
        end
        if native.mode == "list" then displayRuntime.recentItem.pending = nil end
        if native.mode == "action" and native.ACTIONS
            and native.ACTIONS[native.actionCursor] ~= "USE" then
          displayRuntime.recentItem.pending = nil
        elseif native.mode == "list" or native.mode == "action" then
          local row = native.list()[native.cursor]
          displayRuntime.recentItem:watch(session.game.save,
            row and displayRuntime.gen3.Items.toNumericId(row.id))
        end
      end
    elseif session.battle then
      local menu = compat.battleBagMenu(top)
      local row = menu and (menu.items or {})[menu.index]
      if menu then displayRuntime.recentItem.pending = nil end
      displayRuntime.recentItem:watch(session.game.save, row and row.value)
    end
  end

  function displayRuntime.filterBattleDetailsInput(stepGame)
    if stepGame ~= displayRuntime.sourceGame or not session.moveInfo
        or not session.active or not hasDisplay() or not session.displayReady then return false end
    if session.battle and (not battleState() or session.battle.nativeUnsupported) then return false end
    local queue = stepGame.input and stepGame.input.pressQueue
    local cancel = false
    for _, key in ipairs(queue or {}) do cancel = cancel or key == "b" end
    if not cancel and not (session.battle and customBattleLayout()) then return false end
    for i = queue and #queue or 0, 1, -1 do table.remove(queue, i) end
    if cancel then back() end
    return true
  end

  function displayRuntime.remapBattleSummaryInput(stepGame)
    if stepGame ~= displayRuntime.sourceGame or not session.battle or not customBattleLayout()
        or THEME.style ~= "hgss" then return end
    local state = displayRuntime.summaryContext()
    local queue = stepGame.input and stepGame.input.pressQueue
    if not state or not state.hardwareFocus or type(queue) ~= "table" then return end
    -- B still closes the real summary. Gen 1 otherwise advances to page two.
    for _, key in ipairs(queue) do
      if key == "b" then
        if state.owner.screenId == "SummaryMenu" then state.owner.page = 2 end
        return
      end
    end
    local key
    for _, candidate in ipairs(queue) do
      if candidate == "left" or candidate == "right" or candidate == "up"
          or candidate == "down" then key = candidate; break end
      if candidate == "a" then key = candidate end
    end
    if not key then return end
    local moves = state.page ~= state.hiddenPage and (state.page == 2 or state.page == 4)
    if key == "left" or key == "right" then
      displayRuntime.SummaryPage.turn(state, key == "left" and -1 or 1)
    elseif moves and (key == "up" or key == "down") then
      local current = state.moveIndex or 1
      for offset = 1, 4 do
        local index = (current - 1 + offset * (key == "up" and -1 or 1)) % 4 + 1
        if hgssRuntime.summaryMove(state, index) then state.moveIndex = index; break end
      end
    elseif moves and key == "a" and (assist("move_details") or state.page == 4) then
      session.moveInfo = hgssRuntime.summaryMove(state, state.moveIndex or 1)
    end
    for i = #queue, 1, -1 do
      local button = queue[i]
      if button == "a" or button == "left" or button == "right"
          or button == "up" or button == "down" then table.remove(queue, i) end
    end
    session.dirty = true
    return true
  end

end
