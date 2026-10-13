return function(
  Discovery, THEME, assist, battleState, bottomBattleHud, box,
  button, caughtWild, centered, compat, currentBattleUIMode, displayRuntime,
  drawBattleItems, drawBattleParty, drawBattleRoot, drawBattleSummary, drawCaughtBall, drawDim,
  drawMimic, drawMoveInfo, drawMoves, drawPpItemMoves, drawSafari, drawSprite,
  effectLabel, fit, header, hgssRuntime, mod, outline,
  pcList, render, screenContract, session, text
)
  local function drawUnavailableMenu()
    displayRuntime.drawCompanionPage()
    drawDim(0.55)
    displayRuntime.nativeHandoff = true
  end

  local function drawPcQuantity(quantity, list)
    local item = list and ((list.items and list.items[list.index])
      or (list.rows and list.rows[list.listIndex]))
    header(THEME:translate("QUANTITY"), true)
    if THEME.style == "hgss" then
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:pcQuantity({ label = item
        and (item.label or item.name) or THEME:translate("ITEM"),
        qty = quantity.qty or 1, max = quantity.max, wrap = true, icon = "item" })
      render.G.pop()
      return
    end
    centered(fit(item and item.label or THEME:translate("ITEM"), 20),
      28, render.INK, nil, true)
    button(8, 51, 43, 38, "-", false)
    box("fill", 55, 51, 50, 38, render.PAPER)
    outline(55, 51, 50, 38, render.INK)
    centered(tostring(quantity.qty or 1), 63, render.INK, 2, true)
    button(109, 51, 43, 38, "+", false)
    button(8, 104, 90, 29, THEME:translate("CONFIRM"), false)
    button(102, 104, 50, 29, THEME:translate("CANCEL"), false)
  end

  -- Game path [Gen 2 vs Gen 1]: BoxMenu owns its message pages in Gen 2; legacy PC roots may hold raw message lines instead.
  function displayRuntime.pcNotice(kind, root, top)
    local source = top and top.screenId == "Gen2BoxMenu" and top.message
      or root and root.message
    if not source then return nil end
    local lines
    if type(source) == "table" and type(source.pages) == "table" then
      lines = source.pages[source.page or 1]
    elseif type(source) == "table" then
      lines = source
    else
      lines = THEME:messageLines({ tostring(source) }, 24, 4)
    end
    if type(lines) ~= "table" then lines = { tostring(lines or "...") } end
    return { kind = kind, lines = displayRuntime.bagMessage(lines) }
  end

  local function drawPc(kind, root, top)
    local list = pcList()
    -- Game path [Gen 2 vs Gen 1]: Item PC embeds qtyState; Gen 1 can push a separate QuantityBox with onDone.
    local nativeQuantity = root.screenId == "Gen2ItemPcMenu"
      and root.qtyState or nil
    local quantity = nativeQuantity or (kind == "items" and list and top
      and type(top.qty) == "number" and type(top.max) == "number"
      and type(top.onDone) == "function" and top)
    local notice = displayRuntime.pcNotice(kind, root, top)
    if notice then
      header(THEME:translate(kind == "items" and "ITEM PC" or "PC"), true)
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:pcNotice(notice)
      render.G.pop()
    elseif quantity then
      drawPcQuantity(quantity, nativeQuantity and root or list)

    else
      drawUnavailableMenu()
    end
  end

  function displayRuntime.drawOwnedBattleMessage(message, advance, title)
    local compact = bottomBattleHud()
    if THEME.style == "hgss" then
      local playerTeam, enemyTeam = hgssRuntime.battleTeams()
      local lines = type(message) == "string" and THEME:wrapText(message, compact and 208 or 192, 6,
        function(value) return compact and THEME.hgss:partyInfoWidth(value) or THEME.hgss:labelWidth(value) end)
        or THEME:messageLines(message or {}, compact and 34 or 24, compact and 6 or 4)
      render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      if compact then
        THEME.hgss:battleFullStatuses(hgssRuntime.battleStatus("player"),
          hgssRuntime.battleStatus("enemy"), hgssRuntime.battlePortrait,
          playerTeam, enemyTeam, nil, hgssRuntime.battleStatuses())
        THEME.hgss:battleFullMessage(lines, advance, title, love.timer.getTime())
      else
        THEME.hgss:battleMessage(lines, advance, playerTeam, enemyTeam, title, love.timer.getTime())
      end
      render.G.pop()
    elseif compact then
      displayRuntime.drawFullBattleMessage(message, advance)
    else
      header(THEME:translate(title or "BATTLE"))
      local lines = type(message) == "string" and THEME:wrapText(message, 132, 6)
        or THEME:messageLines(message or {}, 22, 4)
      for index, line in ipairs(lines) do text(line, 14, 36 + index * 12, render.INK) end
      if advance then displayRuntime.drawContinueArrow(75, 128) end
    end
  end

  local function drawBattleLocked(title)
    if currentBattleUIMode() == "standard" then
      drawBattleRoot()
      drawDim(0.48, session.battle.prompt == "advance" and not session.battle.nativeInputLocked)
    elseif currentBattleUIMode() ~= "info" then
      displayRuntime.drawOwnedBattleMessage(session.battle.nativeMessage or session.battle.message,
        session.battle.prompt == "advance", title and THEME:translate(title))
    elseif THEME.style == "hgss" then
      drawBattleRoot(); drawDim(0.55)
    else
      drawUnavailableMenu()
    end
  end

  local function drawFullBattleHpBar(x, y, w, hp, maxHp)
    local ratio = math.max(0,
      math.min(1, (hp or 0) / math.max(1, maxHp or 1)))
    box("fill", x, y, w, 7, render.DARK)
    box("fill", x + 1, y + 1, w - 2, 5, render.PAPER)
    box("fill", x + 1, y + 1, math.floor((w - 2) * ratio), 5,
        ratio <= 0.2 and THEME.red or ratio <= 0.5 and render.DARK or render.INK)
  end

  local function drawFullBattleStatus(mon, y, player)
    if not mon then return end
    local owned = mod.options:get("caught_icon") ~= false
      and not player and caughtWild(session.battle.kind,
      compat.caughtDex(session.game.save)[mon.species])
    box("fill", 4, y, 152, 40, render.MID)
    outline(4, y, 152, 40, render.DARK)
    local name = fit(mon.name or mon.species or "-", owned and 10 or 11)
    text(name, 9, y + 5, render.INK)
    if owned then drawCaughtBall(11 + THEME:textWidth(name), y + 5) end
    local status = (mon.hp or 0) <= 0 and "FNT"
      or THEME:statusName(mon.status, mod.content)
    if status then text(fit(status, 3), 100, y + 5, render.DARK) end
    text(fit(THEME:format("L%d", mon.level or 0), 4), 124, y + 5, render.DARK)
    text(THEME:translate("HP"), 9, y + 24, render.DARK)
    drawFullBattleHpBar(28, y + 24, 68, mon.hp, mon.maxHp)
    if player then
      text(fit(("%d/%d"):format(mon.hp or 0, mon.maxHp or 0), 7),
           100, y + 24, render.INK)
    end
  end

  local function drawFullBattleActions(labels)
    for i, label in ipairs(labels) do
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
      button(3 + col * 78, 94 + row * 24, 76, 22,
             THEME:translate(label), session.battle.menuIndex == i)
    end
  end

  local function drawFullBattleStatuses()
    if session.battle.double then
      for _, mon in ipairs(session.battle.battlers or {}) do
        local x, y = 4 + mon.id % 2 * 78, 3 + math.floor(mon.id / 2) * 45
        box("fill", x, y, 74, 40, render.MID)
        outline(x, y, 74, 40, render.DARK)
        text(fit(mon.absent and "--" or mon.name or mon.species, 11), x + 4, y + 4, render.INK)
        if not mon.absent then
          text(THEME:format("L%d", mon.level or 0), x + 4, y + 14, render.DARK)
          drawFullBattleHpBar(x + 4, y + 25, 66, mon.hp, mon.maxHp)
        end
      end
      return
    end
    drawFullBattleStatus(session.battle.enemy, 3, false)
    drawFullBattleStatus(session.battle.player, 48, true)
  end

  function displayRuntime.drawFullBattleMessage(message, advance)
    drawFullBattleStatuses()
    box("fill", 3, 94, 154, 46, render.MID)
    outline(3, 94, 154, 46, render.DARK)
    message = message or session.battle.nativeMessage or session.battle.message
    local lines = type(message) == "string" and THEME:wrapText(message, 132, 6)
      or THEME:messageLines(message or {}, 22, 6)
    local y = 96 + math.floor((42 - #lines * 7) / 2)
    for _, line in ipairs(lines) do
      text(line, 9, y, render.INK)
      y = y + 7
    end
    if advance or advance == nil and session.battle.prompt == "advance" then displayRuntime.drawContinueArrow(145, 128) end
  end

  local function drawFullBattleRoot()
    drawFullBattleStatuses()
    drawFullBattleActions({ "FIGHT", "PKMN", "ITEM", "RUN" })
  end

  local function drawFullSafari()
    drawFullBattleStatus(session.battle.enemy, 3, false)
    centered(THEME:format("SAFARI BALLS %d", session.battle.safariBalls or 0),
             64, render.DARK)
    local labels = {}
    for index, action in ipairs(displayRuntime.SafariPage.model(session.battle).actions) do labels[index] = action.label end
    drawFullBattleActions(labels)
  end

  displayRuntime.drawForgetMoves = function()
    header(THEME:translate("FORGET MOVE"), true)
    if THEME.style == "hgss" then
      local raw = battleState()
      local mon = raw and screenContract(raw, "forget")
      local pending = raw and raw.pendingLearn
      local model = displayRuntime.learningMoveModel({mon = mon or {}, newMoveId = pending and pending.move,
        index = raw and raw.forgetIndex})
      if session.battle.learningMove and model.newMove then model.newMove.name = session.battle.learningMove end
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      displayRuntime.MovePage.draw(THEME.hgss, model)
      render.G.pop()
      return
    end
    text(fit(THEME:format("NEW %s", session.battle.learningMove or "MOVE"), 18),
         8, 25, render.DARK)
    if assist("move_details") then displayRuntime.moveInfoBadge(139, 24, false) end
    for slot, name in ipairs(session.battle.forgetMoves or {}) do
      local selected = session.battle.forgetIndex == slot
      local y = 38 + (slot - 1) * 25
      button(8, y, 144, 22, "", selected)
      text(fit(name or "-", 17), 14, y + 8,
           selected and (THEME.style ~= "classic" and THEME.white or render.PAPER)
             or render.INK)
      if assist("move_details") then
        displayRuntime.moveInfoBadge(139, y + 2, selected)
      end
    end
  end

  displayRuntime.enemyInfo = function()
    local raw = battleState()
    local enemy = session.battle and session.battle.enemy
    local source = raw and (raw.enemy or (raw.battle and raw.battle.enemy))
    if session.battle and session.battle.double and displayRuntime.enemyInfoSelection ~= nil then
      for _, row in ipairs(session.battle.battlers or {}) do
        if row.id == displayRuntime.enemyInfoSelection and row.side == "enemy" and not row.absent then
          enemy = row
          source = raw and raw.battle and raw.battle.battlers[row.id] or row
          break
        end
      end
    end
    local mon = source and (source.mon or source)
    local info = Discovery.enemy(compat.enemyInfo(enemy, session.game.data, session.game.save, mon), session.discoveryPolicy)
    info.source = enemy
    return info
  end

  local function drawBattle()
    if session.battle.nativeUnsupported then drawUnavailableMenu(); return end
    if currentBattleUIMode() == "info" then
      if session.battle.double and displayRuntime.enemyInfoSelection == nil then
        header(THEME:translate("ENEMY INFO"))
        if THEME.style == "hgss" then
          render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
          -- each foe card also carries its types and what it is weak to,
          -- so the picker already answers the question it is opened for
          local rows = hgssRuntime.battleStatuses() or {}
          for _, row in ipairs(rows) do
            if row.side == "enemy" and not row.absent then
              local ok, info = pcall(compat.enemyInfo, row, session.game.data, session.game.save)
              if ok and info and info.types[1] and assist("enemy_details") then
                row.type, row.type2 = info.types[1], info.types[2] or info.types[1]
                row.typeLabel = THEME:typeName(row.type, mod.content)
                row.type2Label = THEME:typeName(row.type2, mod.content)
                row.weak = {}
                for index, weak in ipairs(assist("type_hints") and info.weak or {}) do
                  if index > 4 then break end
                  row.weak[index] = { type = weak.type, typeLabel = THEME:typeName(weak.type, mod.content),
                    effectLabel = effectLabel(weak.multiplier), multiplier = weak.multiplier }
                end
              end
            end
          end
          THEME.hgss:enemyInfoOpponents(rows, hgssRuntime.battlePortrait)
          render.G.pop()
        else
          for _, mon in ipairs(session.battle.battlers or {}) do
            if mon.side == "enemy" then
              button(6, 26 + math.floor(mon.id / 2) * 58, 148, 52,
                fit(mon.absent and "--" or mon.name or mon.species, 22), false)
            end
          end
        end
        return
      end
      local info = displayRuntime.enemyInfo()
      if THEME.style == "hgss" then
        local firstType = info.types[1]
        local secondType = info.types[2] or firstType
        info.type, info.type2 = firstType, secondType
        info.typeLabel = THEME:typeName(firstType, mod.content)
        info.type2Label = THEME:typeName(secondType, mod.content)
        info.levelText = info.level and THEME:format("L%d", info.level)
          or "L--"
        for _, list in ipairs({ info.weak or {}, info.resist or {} }) do
          for _, row in ipairs(list) do
            row.typeLabel = row.typeLabel or THEME:typeName(row.type, mod.content)
            row.effectLabel = row.effectLabel or effectLabel(row.multiplier)
          end
        end
        local model = {
          pokemon = info,
          drawPokemon = function(_, x, y, size)
            drawSprite(info.species, "front", x, y, size, size,
              nil, info.source)
          end,
        }
        local title = session.battleInfoDetail == "profile" and "POKEDEX"
          or session.battleInfoDetail == "dvs" and "ENEMY DVS"
          or session.battleInfoDetail == "weak" and "WEAK"
          or session.battleInfoDetail == "resist" and "RESIST"
          or "ENEMY INFO"
        header(THEME:translate(title), session.battleInfoDetail ~= nil or displayRuntime.enemyInfoSelection ~= nil)
        render.G.push()
        render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        if session.battleInfoDetail == "profile" then
          if info.descriptionText then
            info.description = THEME:descriptionLines(info.descriptionText, 24, 6, 206)
          end
          THEME.hgss:enemyInfoProfile(model)
        elseif session.battleInfoDetail == "dvs" then
          local dvs = info.dvs
          model.rows = dvs and {
            { label = "HP", value = dvs.hp },
            { label = "ATTACK", value = dvs.attack },
            { label = "DEFENSE", value = dvs.defense },
            { label = "SPEED", value = dvs.speed },
            { label = "SPECIAL", value = dvs.special },
          } or {}
          THEME.hgss:enemyInfoDvs(model)
        elseif session.battleInfoDetail == "weak" or session.battleInfoDetail == "resist" then
          model.kind, model.rows = session.battleInfoDetail, {}
          for _, row in ipairs(info[session.battleInfoDetail] or {}) do
            model.rows[#model.rows + 1] = {
              type = row.type,
              typeLabel = THEME:typeName(row.type, mod.content),
              effectLabel = effectLabel(row.multiplier),
            }
          end
          THEME.hgss:enemyInfoMatchup(model)
        else
          THEME.hgss:enemyInfoOverview(model)
        end
        render.G.pop()
        return
      end
      if session.battleInfoDetail == "profile" then
        header(THEME:translate("POKEDEX"), true)
        centered(fit(info.name, 24), 25, render.INK, nil, true)
        centered(fit(THEME:format("NO.%03d %s", info.dex or 0,
          info.kind or "--"), 24), 37, render.DARK)
        centered(fit(info.height or "--", 24), 50, render.INK, nil, true)
        centered(fit(info.weight or "--", 24), 61, render.INK, nil, true)
        box("fill", 4, 74, 152, 1, render.DARK)
        if #info.description == 0 then
          centered(THEME:translate("NO DETAILS AVAILABLE"), 103, render.DARK)
        else
          for i = 1, math.min(8, #info.description) do
            centered(info.description[i], 80 + (i - 1) * 8, render.INK, nil, true)
          end
        end
        return
      elseif session.battleInfoDetail == "dvs" then
        header(THEME:translate("ENEMY DVS"), true)
        centered(fit(info.name, 24), 25, render.INK, nil, true)
        box("fill", 4, 34, 152, 1, render.DARK)
        if not info.dvs then
          centered(THEME:translate("NO DETAILS AVAILABLE"), 80, render.DARK)
        else
          local rows = {
            { "HP", info.dvs.hp }, { "ATTACK", info.dvs.attack },
            { "DEFENSE", info.dvs.defense }, { "SPEED", info.dvs.speed },
            { "SPECIAL", info.dvs.special },
          }
          for i, row in ipairs(rows) do
            local y = 42 + (i - 1) * 17
            text(fit(THEME:translate(row[1]), 15), 18, y, render.INK)
            text(tostring(row[2]), 130, y, render.DARK)
          end
          centered(THEME:translate("RANGE 0-15"), 130, render.DARK)
        end
        return
      elseif session.battleInfoDetail == "weak" or session.battleInfoDetail == "resist" then
        local rows = info[session.battleInfoDetail]
        header(THEME:translate(session.battleInfoDetail == "weak"
          and "WEAK" or "RESIST"), true)
        centered(THEME:translate("BASE MATCHUP"), 23, render.DARK)
        box("fill", 4, 33, 152, 1, render.DARK)
        if #rows == 0 then
          centered("--", 76, render.INK)
        else
          for i, row in ipairs(rows) do
            local y = 37 + (i - 1) * 8
            text(fit(THEME:typeName(row.type, mod.content), 18), 8, y, render.INK)
            text(effectLabel(row.multiplier), 128, y, render.DARK)
          end
        end
        return
      end
      header(THEME:translate("ENEMY INFO"))
      drawSprite(info.species, "front", 4, 22, 44, 40, nil, session.battle.enemy)
      text(fit(info.name, 15) .. " >", 52, 24, render.INK)
      local identity = info.dex and info.level
        and THEME:format("NO.%03d LV.%d", info.dex, info.level)
        or info.level and THEME:format("LV.%d", info.level) or ""
      text(fit(identity, 17), 52, 35, render.DARK)
      local typeNames = {}
      for _, typeId in ipairs(info.types) do
        typeNames[#typeNames + 1] = THEME:typeName(typeId, mod.content)
      end
      text(fit(THEME:format("TYPE %s",
        #typeNames > 0 and table.concat(typeNames, "/") or "--"), 17),
        52, 46, render.DARK)
      text(THEME:translate("CAUGHT"), 52, 57, render.DARK)
      text(THEME:translate(info.caught and "YES" or "NO"), info.dvs and 96 or 112, 57, render.INK)
      if info.dvs then text(THEME:translate("DVS >"), 123, 57, render.DARK) end
      box("fill", 4, 78, 152, 1, render.DARK)
      centered(THEME:translate("BASE MATCHUP"), 81, render.DARK)
      box("fill", 79, 90, 1, 52, render.MID)
      text(fit(THEME:translate("WEAK"), 7), 5, 91, render.DARK)
      text(info.matchupsAvailable and tostring(#info.weak) or "--", 57, 91, render.DARK)
      text(">", 71, 91, render.DARK)
      text(fit(THEME:translate("RESIST"), 7), 84, 91, render.DARK)
      text(info.matchupsAvailable and tostring(#info.resist) or "--", 136, 91, render.DARK)
      text(">", 150, 91, render.DARK)
      for column, rows in ipairs({ info.weak, info.resist }) do
        local x = column == 1 and 5 or 84
        if #rows == 0 then text("--", x, 102, render.INK) end
        for i = 1, math.min(#rows, 4) do
          local row = rows[i]
          local label = fit(THEME:typeName(row.type, mod.content), 6)
            .. " " .. effectLabel(row.multiplier)
          text(fit(label, 11), x, 102 + (i - 1) * 10, render.INK)
        end
      end
      return
    end
    local top = session.game and session.game.stack and session.game.stack:top()
    local raw = battleState()
    local party = screenContract(top, "party")
    local bag = compat.battleBagMenu(top)
    local ppMoves = screenContract(top, "pp")
    local summary = compat.isScreen(top, "summary") and top
    if ppMoves then
      drawPpItemMoves(ppMoves)
    elseif party then
      drawBattleParty(party)
    elseif bag then
      drawBattleItems(bag)
    elseif summary and session.moveInfo then
      drawMoveInfo(session.moveInfo)
    elseif summary then
      if compat.summary.supports(summary, session.game) then drawBattleSummary(summary)
      else drawUnavailableMenu() end
    elseif top and top ~= raw and not top.isTextBox then
      drawUnavailableMenu()
    elseif session.battle.prompt == "safari" then
      if THEME.style == "hgss" then drawSafari()
      elseif bottomBattleHud() then drawFullSafari()
      else drawSafari() end
    elseif session.battle.prompt == "mimic" then
      drawMimic()
    elseif session.moveInfo then
      drawMoveInfo(session.moveInfo)
    elseif session.battle.prompt == "forget" then
      displayRuntime.drawForgetMoves()
    elseif session.battle.prompt == "moves" then
      drawMoves()
    elseif session.battle.prompt ~= "menu" then
      drawBattleLocked()
    else
      if THEME.style == "hgss" then drawBattleRoot()
      elseif bottomBattleHud() then drawFullBattleRoot()
      else drawBattleRoot() end
    end
  end

  return drawBattle, drawBattleLocked, drawPc, drawUnavailableMenu
end
