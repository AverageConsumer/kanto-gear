return function(
  THEME, assist, button, categorizedBag, caughtWild, chanceLabel,
  choiceWindow, compat, displayRuntime, drawParty, fit, header,
  hgssRuntime, partyCard, render, screenContract, session
)
  function compat.battlePartyTitle(menu, cancel)
    if cancel then return "CANCEL" end
    if menu and (menu.itemUse == true
        or menu.prompt == "Use on which <PK><MN>?") then
      return "USE ITEM ON"
    end
    return "PARTY"
  end
  assert(compat.battlePartyTitle({ itemUse = true }) == "USE ITEM ON"
      and compat.battlePartyTitle({ prompt = "Use on which <PK><MN>?" })
        == "USE ITEM ON"
      and compat.battlePartyTitle({ battle = true }) == "PARTY",
    "battle party title follows the native selection context")

  local function drawBattleParty(menu)
    if menu.submenu then
      if THEME.style == "hgss" then
        local mon = (session.battle.party or {})[menu.index]
        if not mon then return end
        local actions, submenu = hgssRuntime.partySubmenuActions(menu)
        local selected = menu.subIndex or (submenu and submenu.index)
          or (actions[1] and actions[1].index)
        header(THEME:translate("PARTY"), true, false, -1)
        render.G.push()
        render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        THEME.hgss:partyBackdrop()
        partyCard(mon, 64, THEME.hgss:partyActionHeroY(#actions), true, false,
          false, false)
        for row, action in ipairs(actions) do
          local x, y, w, h = THEME.hgss:partyActionRow(row, #actions)
          local label = THEME:menuActionLabel(action.item.label or tostring(action.index))
          THEME.hgss:actionRow(x, y, w, h, label,
            row == 1 and "switch" or row == 2 and "stats" or "cancel", 0,
            THEME.hgss.nativeFocus and selected == action.index)
        end
        render.G.pop()
        return
      end
      header(fit(((session.battle.party or {})[menu.index] or {}).name or "POKEMON", 12),
        true)
      local submenu = type(menu.submenu) == "table" and menu.submenu or nil
      local items = menu.subItems or (submenu and submenu.items) or {}
      local index = menu.subIndex or (submenu and submenu.index)
      for i, item in ipairs(items) do
        button(14, 29 + (i - 1) * 35, 132, 30,
               THEME:menuActionLabel(item.label or tostring(i)), index == i, true)
      end
      return
    end
    local cancel
    if menu.isCancel then
      local ok
      ok, cancel = pcall(menu.isCancel, menu)
      if not ok then return end
    end
    local selected = (THEME.style ~= "hgss" or THEME.hgss.nativeFocus)
      and not cancel and menu.index or nil
    local title = compat.battlePartyTitle(menu, cancel)
    drawParty(session.battle.party or {}, title, true, nil, selected)
  end

  function compat.battleBagMenu(menu)
    if not screenContract(menu, "bag") then return nil end
    -- Mod path [Gen 1 + Gen3 UI 1.4]: the external UI mod keeps categorized bag rows/cursors beside native BagMenu; this is not native Gen 3.
    -- Gen 3 UI 1.4 keeps its categorized cursor beside the native BagMenu.
    local rows = menu and menu.__gen3uiBagViewRows
    local viewIndex = menu and menu.__gen3uiBagViewIndex
    if menu and menu.screenId == "BagMenu" and type(rows) == "table"
        and type(viewIndex) == "number" then
      local nativeIndex = menu.index
      local previous = compat.bagViews[menu]
      local mode = previous and previous.mode or "view"
      if previous then
        local nativeMoved = nativeIndex ~= previous.native
        local viewMoved = viewIndex ~= previous.view
        local nativeRow = (menu.items or {})[nativeIndex]
        local viewRow = rows[viewIndex]
        local aligned = nativeRow and viewRow
          and nativeRow.value == viewRow.value
        if viewMoved and not nativeMoved then
          mode = "view"
        elseif nativeMoved and not viewMoved and not aligned then
          mode = "native"
        end
      end
      compat.bagViews[menu] = {
        native = nativeIndex, view = viewIndex, mode = mode,
      }
      if mode == "native" then return menu end

      local items = {}
      for i, row in ipairs(rows) do
        items[i] = { value = row.value, label = row.label, right = row.right }
      end
      local pocketIndex = menu.__gen3uiBagPocketIndex or 1
      return {
        screenId = menu.screenId,
        items = items,
        index = viewIndex,
        title = THEME:translate(compat.bagLabels[pocketIndex] or "ITEMS"),
        pocketIndex = pocketIndex,
      }
    end
    -- Game path [Gen 2]: battle PackMenu rows and pocket labels need projection; Gen 1 already exposes native items/index.
    if not (menu and menu.screenId == "Gen2PackMenu") then return menu end
    local items = {}
    for i, row in ipairs(menu.rows or {}) do
      items[i] = {
        value = row.id,
        label = row.name or row.id,
        right = row.teaches or (row.showCount and ("x" .. tostring(row.count)))
          or "",
      }
    end
    items[#items + 1] = { label = THEME:translate("CANCEL"), cancel = true }
    local ok, pocket = pcall(menu.pocket, menu)
    if not ok or type(pocket) ~= "table" then return nil end
    return {
      screenId = menu.screenId,
      items = items,
      index = menu.index or 1,
      title = THEME:translate(({ ITEM = "ITEMS", BALL = "BALLS",
        KEY_ITEM = "KEY ITEMS", TM_HM = "TM/HM" })[pocket.id] or "ITEMS"),
      pocketIndex = menu.pocketIndex,
    }
  end

  function compat.selectBattleBagItem(menu, index)
    menu.index = index
    local rows = menu.__gen3uiBagViewRows
    local row = type(rows) == "table" and rows[index] or nil
    if not row then return end
    menu.__gen3uiBagViewIndex = index
    for nativeIndex, nativeRow in ipairs(menu.items or {}) do
      if nativeRow and nativeRow.value == row.value then
        menu.index = nativeIndex
        return
      end
    end
  end

  -- Game path [Gen 2]: a battle item can open a USE-first submenu; advance only that native action and retain all other submenu behavior.
  function compat.useBattleBagItemDirectly(menu, queue)
    if not (menu and menu.screenId == "Gen2PackMenu" and menu.battle
        and not menu.submenu and type(queue) == "table"
        and type(menu.hasSubmenu) == "function"
        and type(menu.submenuRows) == "function"
        and type(menu.useSelected) == "function") then return false end
    local row = menu.rows and menu.rows[menu.index]
    if not row then return false end
    local ok, hasSubmenu = pcall(menu.hasSubmenu, menu)
    if not ok or not hasSubmenu then return false end
    local rowsOk, rows = pcall(menu.submenuRows, menu, row.id)
    if not rowsOk or type(rows) ~= "table" or rows[1] ~= "use" then
      return false
    end
    for i, key in ipairs(queue) do
      if key == "a" then
        local used = pcall(menu.useSelected, menu)
        if not used then return false end
        table.remove(queue, i)
        return true
      end
    end
    return false
  end

  local function drawBattleItems(menu)
    if THEME.style == "hgss" then
      local view = hgssRuntime.bagView(menu)
      local playerTeam, enemyTeam = hgssRuntime.battleTeams()
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:battleBag(view, playerTeam, enemyTeam)
      render.G.pop()
      return
    end
    header(menu.title or THEME:translate("ITEMS"), true, categorizedBag(menu))
    local odds = {}
    if assist("catch_odds")
        and (caughtWild(session.battle.kind, true) or session.battle.wild == true) then
      for _, item in ipairs(session.battle.items or {}) do
        odds[item.id] = item.catchChance
      end
    end
    local first, count = choiceWindow(menu.items or {}, menu.index)
    for row = 1, count do
      local index, item = first + row - 1, menu.items[first + row - 1]
      local right = item.right or ""
      if odds[item.value] ~= nil then
        right = right .. " " .. chanceLabel(odds[item.value])
      end
      button(8, 25 + (row - 1) * 28, 144, 25,
             THEME:format("%s %s", item.cancel and THEME:translate("CANCEL")
               or item.label or tostring(index), right),
             menu.index == index, true)
    end
  end

  function displayRuntime.moveSelectionModel(menu)
    local moves = {}
    local first, count, currentPage, pages = 1, 4
    if menu.catalogue then first, count, currentPage, pages = displayRuntime.MovePage.window(#menu.items - 1, menu.cursor) end
    for index, row in ipairs(menu.items or {}) do
      local slot = menu.catalogue and index - first + 1 or menu.slots and menu.slots[index] or index
      if slot >= 1 and slot <= count then
        local move = hgssRuntime.moveView(row.move)
        move.name, move.ppText = row.label, row.right or move.ppText
        move.available = not row.inert and row.enabled ~= false
        moves[slot] = move
      end
    end
    local mon = menu.mon
    local def = mon and session.game.data.pokemon[mon.species] or {}
    return { moves = moves, name = mon and (mon.nickname or mon.name or def.name or mon.species) or "",
      prompt = menu.itemName or menu.itemId and (session.game.data.items[menu.itemId] or {}).name
        or THEME:translate("CHOOSE MOVE"), enabled = menu.enabled ~= false
        and (not menu.valid or menu.valid()),
      newMove = menu.newMoveId and hgssRuntime.moveView(menu.newMoveId),
      newLabel = THEME:translate("NEW"), details = (menu.learning or menu.catalogue) and assist("move_details"),
      message = menu.message, first = first, page = currentPage, pages = pages,
      selection = type(menu.cursor) == "number" and menu.cursor - first + 1
        or type(menu.cursor) == "string" and (menu.native or menu)[menu.cursor] or menu.index }
  end

  function displayRuntime.learningMoveModel(learn)
    local menu = { mon = learn.mon, newMoveId = learn.newMoveId, index = learn.index,
      learning = true, items = {}, slots = {} }
    for slot = 1, 4 do
      local source = learn.mon and learn.mon.moves and learn.mon.moves[slot]
      if source then
        menu.items[#menu.items + 1], menu.slots[#menu.slots + 1] = displayRuntime.moveChoiceRow(source), slot
      end
    end
    return displayRuntime.moveSelectionModel(menu)
  end

  local function drawPpItemMoves(menu)
    header(THEME:translate("CHOOSE MOVE"), true)
    if THEME.style == "hgss" then
      render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      displayRuntime.MovePage.draw(THEME.hgss, displayRuntime.moveSelectionModel(menu))
      render.G.pop()
      return
    end
    for i, item in ipairs(menu.items or {}) do
      button(8, 25 + (i - 1) * 28, 144, 25,
             THEME:format("%s  PP %s", item.label or tostring(i), item.right or "--"), menu.index == i, true)
    end
  end


  return drawBattleItems, drawBattleParty, drawPpItemMoves
end
