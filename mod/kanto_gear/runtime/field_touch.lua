return function(
  HEADER, THEME, assist, compat, displayRuntime, inside,
  press, session, useTool
)
  local function tapFieldChoice(x, y)
    if y < HEADER and x < 24 then
      if session.fieldChoice.kind == "soft_target"
          and #(session.fieldChoice.action.sources or {}) > 1 then
        session.fieldChoice = { kind = "soft_source", action = session.fieldChoice.action }
      else
        session.fieldChoice = nil
      end
      session.dirty = true
      return
    end
    if session.fieldChoice.kind == "fish" then
      if THEME.style == "hgss" then
        local index = THEME.hgss:rodHit(x * THEME.hgssScale,
          y * THEME.hgssScale, session.fieldChoice.action.rods)
        local rod = index and session.fieldChoice.action.rods[index]
        if rod then
          local action = session.fieldChoice.action
          session.fieldChoice = nil
          useTool(action, { rod = rod.id })
        end
        return
      end
      for i, rod in ipairs(session.fieldChoice.action.rods or {}) do
        if inside(x, y, 14, 30 + (i - 1) * 37, 132, 32) then
          local action = session.fieldChoice.action
          session.fieldChoice = nil
          useTool(action, { rod = rod.id })
          return
        end
      end
      return
    end
    local choices = session.fieldChoice.kind == "soft_source"
      and session.fieldChoice.action.sources or session.fieldChoice.source.targets
    if y < 23 then return end
    local col, row = x >= 81 and 1 or 0, math.floor((y - 23) / 39)
    local selected = choices[row * 2 + col + 1]
    if not selected then return end
    if session.fieldChoice.kind == "soft_source" then
      session.fieldChoice = { kind = "soft_target", action = session.fieldChoice.action,
                      source = selected }
      session.dirty = true
    else
      local action, source = session.fieldChoice.action, session.fieldChoice.source
      session.fieldChoice = nil
      useTool(action, { sourceSlot = source.slot, targetSlot = selected.slot })
    end
  end

  local function tapLearn(learn, top, x, y)
    if THEME.style == "hgss" then
      local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
      if learn.selecting and hy < 30 and hx < 27 then
        press("b")
        return
      end
      local action, slot
      if learn.selecting then
        action, slot = displayRuntime.MovePage.hit(displayRuntime.learningMoveModel(learn), hx, hy)
        if type(action) == "number" then slot, action = action, "move" end
      end
      local details = assist("move_details")
      if action == "new" and details then
        session.moveInfo = compat.moveInfoEntry(learn.newMoveId)
        session.dirty = session.moveInfo ~= nil or session.dirty
        return
      elseif learn.selecting and action then
        if action == "info" and not details then action = "move" end
        local source = learn.mon.moves[slot]
        if not source then return end
        if action == "info" then
          session.moveInfo = compat.moveInfoEntry(source)
          session.dirty = session.moveInfo ~= nil or session.dirty
        else
          learn.index = slot
          if learn.native then learn.native.row = slot end
          press("a")
        end
        return
      elseif top and top.isTextBox then
        if top.waiting or (top.done and not top.choice) then press("a") end
        return
      end
      return
    end
    if assist("move_details") then
      if learn.selecting and inside(x, y, 137, 22, 17, 15) then
        session.moveInfo = compat.moveInfoEntry(learn.newMoveId)
        session.dirty = session.moveInfo ~= nil or session.dirty
        return
      elseif not learn.selecting and inside(x, y, 143, 39, 15, 15) then
        session.moveInfo = compat.moveInfoEntry(learn.newMoveId)
        session.dirty = session.moveInfo ~= nil or session.dirty
        return
      end
    end
    if top and top.isTextBox then
      if top.waiting or (top.done and not top.choice) then press("a") end
      return
    end
    if learn.selecting and top == (learn.native or learn) then
      if x >= 8 and x < 152 and y >= 38
          and y < 38 + #learn.mon.moves * 25 then
        local slot = math.floor((y - 38) / 25) + 1
        learn.index = slot
        if learn.native then learn.native.row = slot end
        if assist("move_details") and x >= 137 then
          session.moveInfo = compat.moveInfoEntry(learn.mon.moves[slot])
          session.dirty = session.moveInfo ~= nil or session.dirty
        else
          press("a")
        end
      end
      return
    end
    if top and top.onChoose and (top.index == 1 or top.index == 2) then
      if inside(x, y, 18, 106, 58, 27) then
        top.index = 1
        press("a")
      elseif inside(x, y, 84, 106, 58, 27) then
        top.index = 2
        press("a")
      end
    end
  end

  -- Game path [Gen 1/2/3]: selecting a recent item must first restore the native bag pocket, container and cursor before sending A.
  function displayRuntime.selectRecentBagItem(top)
    local item = displayRuntime.lastBagItem()
    if not item then return false end
    if displayRuntime.gen3Ui then
      local layer = displayRuntime.gen3Ui.Stack.top()
      if not layer or not (layer.id == "bag" or layer.id == "berry_pouch" or layer.id == "tm_case")
          or layer.mod.mode ~= "list" then return false end
      local native = layer.mod
      if layer.id == "bag" then
        local def = session.game.data.items[item.id]
        for index, pocket in ipairs(displayRuntime.gen3.Items.BAG_POCKET_ORDER) do
          if def and def.nativePocket == pocket then native.pocketIdx = index break end
        end
      end
      for index, row in ipairs(native.list()) do
        if displayRuntime.gen3.Items.toNumericId(row.id) == item.id then
          native.cursor, native.scroll = index, math.max(0, index - 1)
          displayRuntime.recentItem:watch(session.game.save, item.id)
          displayRuntime.gen3.syncScreens()
          press("a"); session.dirty = true
          return true
        end
      end
      return false
    end
    top = top.owner or top
    if top.screenId == "Gen2PackMenu" then
      local def = session.game.data.items[item.id] or {}
      for index, pocket in ipairs(displayRuntime.bagPockets) do
        if pocket.id == (def.pocket or "ITEM") then
          top.pocketIndex = index
          if top.restoreCursor then top:restoreCursor() end
          top:rebuild()
          break
        end
      end
    end
    local menu = compat.battleBagMenu(top)
    for index, row in ipairs(menu and menu.items or {}) do
      if row.value == item.id then
        compat.selectBattleBagItem(top, index)
        displayRuntime.recentItem:watch(session.game.save, item.id)
        press("a"); session.dirty = true
        return true
      end
    end
    return false
  end

  return tapFieldChoice, tapLearn
end
