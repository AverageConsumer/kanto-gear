return function(
  HEADER, THEME, assist, back, battleState, bottomBattleHud,
  categorizedBag, choiceWindow, companionMoveGrid, compat, currentBattleUIMode, displayRuntime,
  hgssRuntime, inside, moveSlotAt, press, screenContract, session,
  submit
)
  local function fullBattleChoice(x, y)
    for i = 1, 4 do
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
      if inside(x, y, 3 + col * 78, 94 + row * 24, 76, 22) then
        return i
      end
    end
  end

  local function tapBattle(x, y)
    if session.battle.nativeUnsupported then return end
    if currentBattleUIMode() == "info" then
      if y < HEADER and x < 24 and (session.battleInfoDetail or displayRuntime.enemyInfoSelection ~= nil) then
        back(); return
      end
      if session.battle.double and displayRuntime.enemyInfoSelection == nil then
        local slot = THEME.style == "hgss"
          and THEME.hgss:enemyInfoOpponentHit(x * THEME.hgssScale, y * THEME.hgssScale)
          or THEME.style ~= "hgss" and x >= 6 and x < 154 and y >= 26 and y < 136
            and (y < 84 and 1 or 3)
        for _, mon in ipairs(session.battle.battlers or {}) do
          if mon.id == slot and mon.side == "enemy" and not mon.absent then
            displayRuntime.enemyInfoSelection, session.dirty = mon.id, true
            break
          end
        end
        return
      end
      if THEME.style == "hgss" then
        local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
        if session.battleInfoDetail then
          if hy < 30 and hx < 27 then session.battleInfoDetail, session.dirty = nil, true end
        else
          local info = displayRuntime.enemyInfo()
          local action = THEME.hgss:enemyInfoHit(hx, hy, info.dvs ~= nil, info)
          if action then session.battleInfoDetail, session.dirty = action, true end
        end
        return
      end
      if session.battleInfoDetail then
        if y < HEADER and x < 22 then session.battleInfoDetail, session.dirty = nil, true end
      elseif y >= 52 and y < 72 and x >= 118 and displayRuntime.enemyInfo().dvs then
        session.battleInfoDetail, session.dirty = "dvs", true
      elseif y >= HEADER and y < 79 and displayRuntime.enemyInfo().profileAvailable then
        session.battleInfoDetail, session.dirty = "profile", true
      elseif y >= 90 and assist("type_hints") then
        session.battleInfoDetail, session.dirty = x < 80 and "weak" or "resist", true
      end
      return
    end
    local top = session.game and session.game.stack and session.game.stack:top()
    local ppMoves = screenContract(top, "pp")
    if ppMoves then
      displayRuntime.tapPpItemMoves(ppMoves, x, y)
      return
    end
    if compat.isScreen(top, "summary") then
      if THEME.style == "hgss" then displayRuntime.tapSummary(top, x, y)
      elseif y < HEADER and x < 24 then displayRuntime.summaryInput(top, "b")
      elseif inside(x, y, 103, 125, 53, 15) then press("a") end
      return
    end
    local party = screenContract(top, "party")
    if party then
      if y < HEADER and x < 24 then
        press("b")
      elseif party.submenu then
        if THEME.style == "hgss" then
          local actions, submenu = hgssRuntime.partySubmenuActions(party)
          local row = THEME.hgss:partyActionAt(
            x * THEME.hgssScale, y * THEME.hgssScale, #actions)
          local action = row and actions[row]
          if action then
            if submenu then submenu.index = action.index
            else party.subIndex = action.index end
            press("a")
          end
        else
          local submenu = type(party.submenu) == "table" and party.submenu or nil
          local items = party.subItems or (submenu and submenu.items) or {}
          local index = math.floor((y - 29) / 35) + 1
          if x >= 14 and x < 146 and index >= 1
              and index <= #items then
            if submenu then submenu.index = index else party.subIndex = index end
            press("a")
          end
        end
      elseif y >= 23 then
        local slot
        if THEME.style == "hgss" then
          slot = THEME.hgss:partySlot(x, y, #(session.battle.party or {}))
        else
          local col, row = x >= 81 and 1 or 0, math.floor((y - 23) / 39)
          slot = row * 2 + col + 1
        end
        if (session.battle.party or {})[slot] then
          party.index = slot
          press("a")
        end
      end
      return
    end
    local menu = compat.battleBagMenu(top)
    if menu then
      if THEME.style == "hgss" then
        local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
        local bagY = THEME.hgss.battleBagOffsetY or 0
        if hy < 63 + bagY then
          if hx < 29 then
            press("b")
          elseif categorizedBag(top) and hx >= 62 and hx < 92 then
            press("left")
          elseif categorizedBag(top) and hx >= 158 and hx < 187 then
            press("right")
          end
        else
          local view = hgssRuntime.bagView(menu)
          local index = THEME.hgss:battleBagHit(hx, hy, view)
          if index == "recent" then displayRuntime.selectRecentBagItem(top)
          elseif index then
            compat.selectBattleBagItem(top, index)
            displayRuntime.recentItem:watch(session.game.save, menu.items[index].value)
            press("a")
          end
        end
        return
      end
      if y < HEADER then
        if categorizedBag(top) then
          if x < 18 then
            press("b")
          elseif x < 40 then
            press("left")
          elseif x >= 86 and x < 108 then
            press("right")
          end
        elseif x < 24 then
          press("b")
        end
      else
        local first, count = choiceWindow(menu.items or {}, menu.index)
        local row = math.floor((y - 25) / 28) + 1
        if x >= 8 and x < 152 and row >= 1 and row <= count then
          compat.selectBattleBagItem(top, first + row - 1)
          press("a")
        end
      end
      return
    end
    local raw = battleState()
    if top and top ~= raw and not top.isTextBox then
      return
    end
    if session.battle.prompt == "safari" then
      local choice
      if THEME.style == "hgss" then
        if bottomBattleHud() then
          choice = THEME.hgss:battleFullMoveHit(x * THEME.hgssScale, y * THEME.hgssScale)
        else
          choice = THEME.hgss:safariHit(x * THEME.hgssScale, y * THEME.hgssScale)
        end
      elseif bottomBattleHud() then
        choice = fullBattleChoice(x, y)
      elseif y >= 24 then
        local col, row = x >= 81 and 1 or 0, y >= 81 and 1 or 0
        choice = row * 2 + col + 1
      end
      local action = displayRuntime.SafariPage.action(displayRuntime.SafariPage.model(session.battle), choice)
      if not action then return end
      submit("safari", { action = action })
      return
    end
    if session.battle.prompt == "mimic" then
      local index
      if THEME.style == "hgss" then
        index = THEME.hgss:mimicHit(x * THEME.hgssScale,
          y * THEME.hgssScale, #(session.battle.mimicMoves or {}))
      elseif x >= 8 and x < 152 then
        index = math.floor((y - 25) / 28) + 1
      end
      if index and index >= 1 and index <= #(session.battle.mimicMoves or {}) then
        submit("mimic", { index = index })
      end
      return
    end
    if session.battle.prompt == "forget" then
      local mon = raw and screenContract(raw, "forget")
      if THEME.style == "hgss" then
        local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
        if hy < 30 and hx < 27 then
          press("b")
          return
        end
        local action, slot = displayRuntime.MovePage.hit(displayRuntime.learningMoveModel({
          mon = mon or {}, newMoveId = raw.pendingLearn and raw.pendingLearn.move }), hx, hy)
        if type(action) == "number" then slot, action = action, "move" end
        local details = assist("move_details")
        if action == "new" and details then
          session.moveInfo = compat.moveInfoEntry(
            raw.pendingLearn and raw.pendingLearn.move)
        elseif action and mon and mon.moves[slot] then
          if action == "info" and not details then action = "move" end
          if action == "info" then
            session.moveInfo = compat.moveInfoEntry(mon.moves[slot])
          else
            raw.forgetIndex, session.battle.forgetIndex = slot, slot
            press("a")
          end
        end
        session.dirty = session.moveInfo ~= nil or session.dirty
        return
      end
      if y < HEADER and x < 24 then
        press("b")
      elseif raw and assist("move_details")
          and inside(x, y, 137, 22, 17, 15) then
        session.moveInfo = compat.moveInfoEntry(raw.pendingLearn and raw.pendingLearn.move)
      elseif mon and x >= 8 and x < 152 and y >= 38
          and y < 38 + #mon.moves * 25 then
        raw.forgetIndex = math.floor((y - 38) / 25) + 1
        if assist("move_details") and x >= 137 then
          session.moveInfo = compat.moveInfoEntry(mon.moves[raw.forgetIndex])
        else
          press("a")
        end
      end
      session.dirty = true
      return
    end
    if y < HEADER and x < 24
       and (session.moveInfo or session.battle.prompt == "moves") then
      back()
      return
    end
    if not session.moveInfo and session.battle.nativeCanReveal then press("a"); return end
    if session.moveInfo or session.battle.prompt == "locked" then return end
    if session.battle.prompt == "advance" then
      press("a")
      return
    end
    if session.battle.prompt == "moves" then
      if THEME.style == "hgss" then
        local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
        if hy < 30 and hx < 28 then back(); return end
        local slot, info
        if bottomBattleHud() then
          slot, info = THEME.hgss:battleFullMoveHit(hx, hy)
          if not slot then return end
        else
          if hy < 33 or hy >= 198 then return end
          local column = hx >= 120 and 1 or 0
          local row = hy >= 118 and 1 or 0
          slot = row * 2 + column + 1
          local cardX, cardY = 6 + column * 116, 33 + row * 85
          if hx < cardX or hx >= cardX + 112 or hy < cardY or hy >= cardY + 80 then return end
          info = hx >= cardX + 94 and hx < cardX + 112
            and hy >= cardY and hy < cardY + 24
        end
        local move = session.battle.moves[slot]
        if not move then return end
        local disabled = THEME:moveUnavailableReason(move) ~= nil
        if assist("move_details") and info then
          move.battleSlot = slot
          session.moveInfo = move
          hgssRuntime.beginAnimation("battle_move_info")
          session.dirty = true
        elseif not disabled then
          submit("move", { slot = slot })
        end
        return
      end
      local grid = companionMoveGrid(battleState())
      local slot, cardX, cardY = moveSlotAt(
        x, y, #(session.battle.moves or {}), grid)
      local move = session.battle.moves[slot]
      if not move then return end
      local disabled = THEME:moveUnavailableReason(move) ~= nil
      if assist("move_details")
          and inside(x, y, cardX + (grid and 62 or 130),
                     cardY + (grid and 0 or 13), 14, 14) then
        move.battleSlot = slot
        session.moveInfo = move
        hgssRuntime.beginAnimation("battle_move_info")
        session.dirty = true
      elseif not disabled then
        submit("move", { slot = slot })
      end
      return
    end
    if session.battle.prompt ~= "menu" then return end
    local choice
    if THEME.style == "hgss" then
      if bottomBattleHud() then
        choice = THEME.hgss:battleFullMoveHit(x * THEME.hgssScale, y * THEME.hgssScale)
      else
        choice = THEME.hgss:battleChoice(
          x * THEME.hgssScale, y * THEME.hgssScale)
      end
    elseif bottomBattleHud() then
      choice = fullBattleChoice(x, y)
    elseif y >= 24 then
      local col, row = x >= 81 and 1 or 0, y >= 81 and 1 or 0
      choice = row * 2 + col + 1
      -- Game path [Gen 3]: classic native root order is fight/item/party/run; common touch actions use fight/party/item/run.
      if displayRuntime.gen3 then choice = ({ 1, 3, 2, 4 })[choice] end
    end
    if not choice then return end
    if displayRuntime.gen3 then
      submit("menu", { choice = ({ "fight", "party", "item", "run" })[choice] })
      return
    end
    local raw = battleState()
    if raw and session.game.stack:top() == raw then
      raw.menuIndex = choice
      press("a")
    end
    session.dirty = true
  end

  return tapBattle
end
