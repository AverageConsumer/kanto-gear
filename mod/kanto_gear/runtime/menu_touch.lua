return function(
  CHOICE_QUIET, HEADER, THEME, choiceReady, choiceWindow, compat,
  displayRuntime, inside, namingCell, pcList, press, session,
  submit, trackChoice
)
  local function tapPc(kind, root, top, x, y)
    local list = pcList()
    if displayRuntime.pcNotice(kind, root, top) then
      press("a")
      session.dirty = true
      return
    end
    -- Game path [Gen 2 vs Gen 1]: use the same embedded Item PC quantity state or standalone QuantityBox as the rendered page.
    local nativeQuantity = root.screenId == "Gen2ItemPcMenu"
      and root.qtyState or nil
    local quantity = nativeQuantity or (kind == "items" and list and top
      and type(top.qty) == "number" and type(top.max) == "number"
      and type(top.onDone) == "function" and top)
    if quantity then
      if THEME.style == "hgss" then
        local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
        local action = THEME.hgss:pcQuantityHit(hx, hy,
          { qty = quantity.qty, max = quantity.max, wrap = true })
        if hy < 30 and hx < 27 then press("b")
        elseif action == "minus" then press("down")
        elseif action == "plus" then press("up")
        elseif action == "confirm" then press("a")
        elseif action == "cancel" then press("b") end
        session.dirty = true
        return
      end
      if y < HEADER and x < 24 then
        press("b")
      elseif inside(x, y, 8, 51, 43, 38) then
        press("down")
      elseif inside(x, y, 109, 51, 43, 38) then
        press("up")
      elseif inside(x, y, 8, 104, 90, 29) then
        press("a")
      elseif inside(x, y, 102, 104, 50, 29) then
        press("b")
      end
      session.dirty = true
      return
    end

    -- Known PC pages use the common projection above. Never leave old,
    -- differently positioned hit targets alive on an unsupported overlay.
    if y < HEADER and x < 24 then press("b"); session.dirty = true end
  end

  function displayRuntime.tapStartMenu(top, x, y)
    if not displayRuntime.StartMenu.cursor(top) then return end
    if top.dexModel and THEME.style == "hgss" then
      local action, index = displayRuntime.PokedexPage.hit(top.dexModel, x * THEME.hgssScale, y * THEME.hgssScale)
      if action == "back" then press("b")
      elseif action == "tool" then press(top.dexModel.tools[index].key)
      elseif action == "action" and displayRuntime.StartMenu.select(top, index) then press(top.actionKey(index))
      elseif action == "species" and displayRuntime.StartMenu.select(top, top.dexModel.entries[index].index) then
        if not top.dexModel.forms then press("a") end
      elseif action == "prev" or action == "next" then
        displayRuntime.NativeDex.page(top, action == "next" and 1 or -1)
      elseif action == "description_prev" or action == "description_next" then
        displayRuntime.PokedexPage.cycleDescription(top, top.dexModel, action == "description_next" and 1 or -1)
      end
      if action then session.dirty = true end
      return
    end
    if top.trainer and THEME.style == "hgss" then
      local action = displayRuntime.TrainerPage.hit(x * THEME.hgssScale, y * THEME.hgssScale, top.trainer.pages)
      local key = action == "back" and "b" or type(action) == "number" and top.nextKey(action)
      if key then press(key); session.dirty = true end
      return
    end
    if top.pokegearModel and THEME.style == "hgss" then
      local action, arg = displayRuntime.PokegearPage.hit(top.pokegearModel, x * THEME.hgssScale, y * THEME.hgssScale)
      if action and displayRuntime.PokegearPage.apply(top, action, arg, press) then session.dirty = true end
      return
    end
    if top.optionsModel and THEME.style == "hgss" then
      local action, key = displayRuntime.NativeOptions.hit(top.optionsModel, x * THEME.hgssScale, y * THEME.hgssScale)
      if action == "back" then press("b")
      elseif action == "previous" or action == "next" then
        displayRuntime.StartMenu.select(top, top.optionsModel.first + (action == "next" and 4 or -4))
      elseif type(action) == "number" and displayRuntime.StartMenu.select(top, action) then press(key) end
      session.dirty = true
      return
    end
    if top.recentBag and THEME.style == "hgss"
        and inside(x * THEME.hgssScale, y * THEME.hgssScale, 6, 33, 228, 33) then
      displayRuntime.selectRecentBagItem(top)
      return
    end
    if top.namingModel and not top.notice and THEME.style == "hgss" then
      local index = displayRuntime.NamingPage.hit(top.namingModel, x * THEME.hgssScale, y * THEME.hgssScale)
      if index and displayRuntime.StartMenu.select(top, index) then press("a"); session.dirty = true end
      return
    end
    if top.learningPrompt and THEME.style == "hgss" then
      local labels = {}
      for index, row in ipairs(top.items) do labels[index] = row.label end
      local action = displayRuntime.MovePage.promptHit(
        displayRuntime.learningPromptModel(top.learningPrompt, top, labels, top.prompt),
        x * THEME.hgssScale, y * THEME.hgssScale)
      if action == "new" then session.moveInfo, session.dirty = compat.moveInfoEntry(top.learningPrompt.newMoveId), true
      elseif type(action) == "number" and displayRuntime.StartMenu.select(top, action) then press("a"); session.dirty = true end
      return
    end
    if top.moveSelection and THEME.style == "hgss" then
      local model = displayRuntime.moveSelectionModel(top.moveSelection)
      local action, slot = displayRuntime.MovePage.hit(model,
        x * THEME.hgssScale, y * THEME.hgssScale)
      if action == "back" then press("b")
      elseif action == "previous" or action == "next" then
        displayRuntime.StartMenu.select(top, model.first + (action == "next" and 4 or -4))
      elseif action == "new" then session.moveInfo = compat.moveInfoEntry(top.moveSelection.newMoveId)
      elseif action == "info" then
        if top.moveSelection.catalogue then slot = model.first + slot - 1 end
        for index, row in ipairs(top.items) do
          if (top.nativeSlots and top.nativeSlots[index] or index) == slot then session.moveInfo = compat.moveInfoEntry(row.move); break end
        end
      elseif type(action) == "number" then
        if top.moveSelection.catalogue then action = model.first + action - 1 end
        for index in ipairs(top.items) do
          if (top.nativeSlots and top.nativeSlots[index] or index) == action
              and displayRuntime.StartMenu.select(top, index) then press("a"); break end
        end
      end
      if action then session.dirty = true end
      return
    end
    if top.choiceState and THEME.style == "hgss" then
      local labels = {}
      for index, item in ipairs(top.items) do labels[index] = item.label end
      local model = displayRuntime.choiceModel(top, labels, top.prompt)
      local action = displayRuntime.ChoicePage.hit(model, x * THEME.hgssScale, y * THEME.hgssScale)
      if y < HEADER and x < 27 / THEME.hgssScale then press("b")
      elseif action == "previous" or action == "next" then
        displayRuntime.ChoicePage.step(top.choiceState, action == "next" and 1 or -1, #labels)
      elseif type(action) == "number" and displayRuntime.StartMenu.select(top, action) then press("a") end
      session.dirty = true
      return
    end
    if top.nativeStats then
      local hit = THEME.style == "hgss" and THEME.hgss:levelUpHit(x * THEME.hgssScale, y * THEME.hgssScale)
        or THEME.style ~= "hgss" and y >= HEADER
      if hit then press("a"); session.dirty = true end
      return
    end
    if top.quantity then
      local action
      if THEME.style == "hgss" then action = THEME.hgss:pcQuantityHit(x * 1.5, y * 1.5, top.quantity)
      else action = inside(x, y, 7, 61, 42, 28) and "minus" or inside(x, y, 111, 61, 42, 28) and "plus"
        or inside(x, y, 7, 99, 70, 37) and "confirm" or inside(x, y, 83, 99, 70, 37) and "cancel" end
      if y < HEADER and x < 24 then action = "cancel" end
      local key = ({ minus = "down", plus = "up", confirm = "a", cancel = "b" })[action]
      if key then press(key); session.dirty = true end
      return
    end
    if top.notice then
      if y >= HEADER then press("a"); session.dirty = true end
      return
    end
    if top.nativePocket and y < HEADER and x >= 27 / 1.5 and x < 139 / 1.5 then
      press(x < 83 / 1.5 and "left" or "right")
      session.dirty = true
      return
    end
    local menu = displayRuntime.StartMenu
    local action = menu.hit(top, x * 1.5, y * 1.5)
    if action == "back" then
      press("b")
    elseif action == "previous" or action == "next" then
      local first = menu.window(top)
      local visible = top.recentBag and 4 or menu.visible
      local index = action == "next" and first + visible or first - visible
      menu.select(top, index)
    elseif type(action) == "number" and top.battleTargets then
      submit("target", { target = top.battleTargets[action] })
    elseif type(action) == "number" and menu.select(top, action) then
      if top.party and displayRuntime.bag.pending and top.items[action].mon then
        displayRuntime.bag.pending.mon = top.items[action].mon
      end
      if top.confirmSelection then top.confirmSelection(function() press("a") end)
      else press(top.items[action].inputKey or "a") end
    end
    if action then session.dirty = true end
  end

  function displayRuntime.commitDialogueChoice(top, field, selected)
    local now = love.timer.getTime()
    if trackChoice(top, now) then session.dirty = true end
    if session.choiceCommitted == top then return false end
    if not choiceReady(now, session.choiceReadyAt) then
      session.choiceReadyAt = now + CHOICE_QUIET
      session.choiceNudgeUntil = now + 0.55
      session.dirty = true
      return false
    end
    compat.choiceIndex(top, field, selected)
    if type(top.clampScroll) == "function" then
      pcall(top.clampScroll, top)
    end
    session.choiceCommitted = top
    press("a")
    return true
  end

  local function tapDialogueChoice(top, labels, x, y, field)
    if THEME.style == "hgss" then
      local model = displayRuntime.choiceModel(top, labels, nil, field)
      local action = displayRuntime.ChoicePage.hit(model, x * THEME.hgssScale, y * THEME.hgssScale)
      if action == "previous" or action == "next" then
        displayRuntime.ChoicePage.step(displayRuntime.choiceState(top, field, labels),
          action == "next" and 1 or -1, #labels)
        session.dirty = true
      elseif type(action) == "number" then
        displayRuntime.commitDialogueChoice(top, field, action)
      end
      return
    end
    local selected
    local rows, cols, left, topY, cellW, cellH, gap =
      compat.choiceGrid(top, field, #labels)
    if rows then
      for row = 1, rows do
        for col = 1, cols do
          if inside(x, y, left + (col - 1) * (cellW + gap),
              topY + (row - 1) * (cellH + gap), cellW, cellH) then
            selected = (row - 1) * cols + col
            break
          end
        end
        if selected then break end
      end
    elseif #labels == 2 then
      if inside(x, y, 24, 54, 112, 32) then selected = 1 end
      if inside(x, y, 24, 90, 112, 32) then selected = 2 end
    else
      local start, count = choiceWindow(labels,
        compat.choiceIndex(top, field))
      for row = 1, count do
        if inside(x, y, 8, 24 + (row - 1) * 27, 144, 24) then
          selected = start + row - 1
          break
        end
      end
    end
    if not selected then return end
    displayRuntime.commitDialogueChoice(top, field, selected)
  end

  -- Game path [Gen 1/2]: Gen 2 uses zero-based keys and confirms at END; Gen 1 uses one-based keys and Start confirmation.
  local function tapNaming(top, grid, x, y)
    if THEME.style == "hgss" then
      local model, items = displayRuntime.namingModel(top, grid)
      local index = displayRuntime.NamingPage.hit(model, x * THEME.hgssScale, y * THEME.hgssScale)
      local item = index and items[index]
      if not item then return end
      if item.action == "case" then press("select")
      elseif item.action == "delete" then press("b")
      elseif item.action == "confirm" then
        if top.screenId == "Gen2NamingScreen" then
          top.row, top.col = #grid - 1, 6
          press("a")
        else press("start") end
      else
        local offset = top.screenId == "Gen2NamingScreen" and 1 or 0
        top.row, top.col = item.nativeRow - offset, item.col - offset
        press("a")
      end
      session.dirty = true
      return
    end
    local row, col = namingCell(x, y, grid)
    if not row then return end
    if top.screenId == "Gen2NamingScreen" then
      top.row = row - 1
      top.col = row == #grid and (col - 1) * 3 or col - 1
    else
      top.row, top.col = row, col
    end
    press("a")
    session.dirty = true
  end

  return tapDialogueChoice, tapNaming, tapPc
end
