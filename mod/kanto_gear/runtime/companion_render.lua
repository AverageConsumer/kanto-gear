return function(
  HEIGHT, THEME, WIDTH, assist, battleState, box,
  button, centered, compat, currentBattleUIMode, customBattleLayout, dialogueChoice,
  displayRuntime, drawActionPrompt, drawArea, drawBattle, drawBattleLocked, drawBattleSummary,
  drawDialogueChoice, drawDim, drawFieldChoice, drawFlyPrompt, drawGuide, drawLevelUpStats,
  drawLocalMap, drawMap, drawMoveInfo, drawNaming, drawNormalParty, drawParty,
  drawPartyAction, drawPc, drawPpItemMoves, drawRadar, drawSprite, drawStepsDetail,
  drawTitle, drawTools, drawTrainer, drawUnavailableMenu, fit, header,
  hgssRuntime, mod, outline, pcSession, render, screenById,
  screenContract, screenState, session, text, textPrompt
)
  local function moveDef(id)
    return session.game and session.game.data and session.game.data.moves and session.game.data.moves[id]
  end

  displayRuntime.learningMoveInfo = function()
    local learn = displayRuntime.moveLearnScreen()
    if learn then
      local moves = learn.mon.moves or {}
      if learn.selecting and learn.index <= #moves then
        return compat.moveInfoEntry(moves[learn.index])
      end
      return compat.moveInfoEntry(learn.newMoveId)
    end

    local raw = battleState()
    local pending = raw and raw.pendingLearn
    if not pending then return nil end
    if raw.phase == "choose-forget" then
      local party = raw.battle and raw.battle.party
      local mon = party and party[pending.index]
      local moves = mon and mon.moves or {}
      return compat.moveInfoEntry(moves[raw.forgetIndex or 1])
    end
    return compat.moveInfoEntry(pending.move)
  end

  local function drawLearnMove(learn, top, choice, choiceField)
    local newDef = moveDef(learn.newMoveId) or {}
    local newName = newDef.name or learn.newMoveId or "MOVE"
    if session.battle and top and top.isTextBox and customBattleLayout() then
      drawBattleLocked("NEW MOVE")
      return
    end
    if THEME.style == "hgss" then
      local newMove = hgssRuntime.moveView(learn.newMoveId)
      if learn.selecting and top == (learn.native or learn) then
        header(THEME:translate("FORGET MOVE"), true)
        render.G.push()
        render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        displayRuntime.MovePage.draw(THEME.hgss, displayRuntime.learningMoveModel(learn))
        render.G.pop()
        return
      end

      header(THEME:translate("NEW MOVE"))
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      displayRuntime.MovePage.drawPrompt(THEME.hgss,
        displayRuntime.learningPromptModel(learn, choice, { "YES", "NO" }, nil, choiceField))
      render.G.pop()
      return
    end
    if learn.selecting and top == (learn.native or learn) then
      header(THEME:translate("FORGET MOVE"))
      text(fit(newName, 13), 5, 25, render.INK)
      text(fit(THEME:typeName(newDef.type, mod.content), 7), 95, 25, render.DARK)
      if assist("move_details") then
        displayRuntime.moveInfoBadge(139, 24, false)
      end
      for i = 1, 4 do
        local mv = learn.mon.moves[i]
        local def = mv and moveDef(mv.id) or {}
        local selected = learn.index == i
        local y = 38 + (i - 1) * 25
        button(8, y, 144, 22, "", selected)
        text(fit(def.name or (mv and mv.id) or "-", 17), 14, y + 8,
             selected and (THEME.style ~= "classic" and THEME.white or render.PAPER)
               or render.INK)
        if mv and assist("move_details") then
          displayRuntime.moveInfoBadge(139, y + 2, selected)
        end
      end
      return
    end

    header(THEME:translate("NEW MOVE"))
    drawSprite(learn.mon.species, "front", 5, 25, 42, 42,
               nil, learn.mon.source or learn.mon)
    local monDef = session.game.data.pokemon[learn.mon.species] or {}
    text(fit(learn.mon.nickname or monDef.name or learn.mon.species, 16),
         51, 27, render.DARK)
    text(fit(newName, 14), 51, 42, render.INK)
    if assist("move_details") then
      text(fit(THEME:typeName(newDef.type, mod.content), 9), 51, 56, render.DARK)
      text(THEME:format("PP %d", newDef.pp or 0), 112, 56, render.DARK)
      displayRuntime.moveInfoBadge(145, 41, false)
    end
    box("fill", 7, 75, 146, 1, render.DARK)
    if top and top.onChoose and (top.index == 1 or top.index == 2) then
      button(18, 106, 58, 27, THEME:translate("YES"), top.index == 1)
      button(84, 106, 58, 27, THEME:translate("NO"), top.index == 2)
    else
      drawDim(0.48, top and top.isTextBox and textPrompt(top))
    end
  end

  function displayRuntime.pressTouch(mode, choice, touch, owned, blocked)
    if blocked or mode == "loading"
        or (mode == "textbox" and not choice and not owned)
        or (mode == "locked" and not owned) then
      return nil
    end
    return touch
  end
  assert(displayRuntime.pressTouch("textbox", nil, true) == nil
      and displayRuntime.pressTouch("loading", nil, true) == nil
      and displayRuntime.pressTouch("textbox", {}, true) == true
      and displayRuntime.pressTouch("locked", nil, true) == nil
      and displayRuntime.pressTouch("locked", nil, true, true) == true
      and displayRuntime.pressTouch("active", nil, true) == true,
    "modal text and loading overlays capture HGSS press animation")

  function displayRuntime.drawCompanionPage()
    THEME.hgss.v4Page = (not session.fieldChoice and not session.radarOpen) and session.page or nil
    if session.fieldChoice then
      drawFieldChoice()
      return
    end
    if session.radarOpen then
      drawRadar()
    elseif THEME.style == "hgss" and session.page == "HOME" then
      displayRuntime.drawHome()
    elseif THEME.style == "hgss" and session.page == "STORE" then
      displayRuntime.drawStore()
    elseif THEME.style == "hgss" and session.page == "POKEDEX" then
      displayRuntime.drawPokedex()
    elseif THEME.style == "hgss" and session.page == "ACHIEVEMENTS" then
      displayRuntime.drawAchievements()
    elseif THEME.style == "hgss" and session.page == "NOTES" then
      displayRuntime.drawNotes()
    elseif THEME.style == "hgss" and session.page == "DAYCARE" then
      displayRuntime.drawDaycare()
    elseif THEME.style == "hgss" and session.page == "CALENDAR" and displayRuntime.drawCalendar then
      displayRuntime.drawCalendar()
    elseif THEME.style == "hgss" and session.page == "PSS" then
      displayRuntime.drawPss()
    elseif THEME.style == "hgss" and session.page == "BAG" then
      displayRuntime.drawBag()
    elseif THEME.style == "hgss" and session.page == "SETTINGS" then
      displayRuntime.drawSettings()
    elseif session.page == "MAP" then
      drawMap()
    elseif session.page == "LOCAL" then
      drawLocalMap()
    elseif session.page == "GUIDE" then
      if displayRuntime.guideDetail then
        displayRuntime.drawGuideDetail()
      else
        drawGuide()
      end
    elseif session.page == "AREA" then
      drawArea()
    elseif session.page == "TRAINER" then
      if session.trainerStepsOpen then drawStepsDetail() else drawTrainer() end
    elseif THEME.style == "hgss" and session.page == "STEPS" then
      drawStepsDetail()
    elseif session.page == "PARTY" then
      if session.partyActionSlot then drawPartyAction() else drawNormalParty() end
    else
      drawTools()
    end
  end

  displayRuntime.drawContents = function()
    displayRuntime.mapRefresh.paintedPage = nil
    displayRuntime.mapRefresh.only = false
    if session.page ~= "LOCAL" then displayRuntime.clearExplorerSnapshot() end
    displayRuntime.backgroundDim = 0
    displayRuntime.nativeHandoff = false
    render.G.setCanvas(session.canvas)
    render.G.origin()
    render.G.setScissor()
    render.G.setShader()
    render.G.setBlendMode("alpha")
    render.G.clear(render.PAPER[1], render.PAPER[2], render.PAPER[3], render.PAPER[4])
    render.G.setLineWidth(1)
    local highResolution = THEME.style == "hgss"
    if highResolution then
      render.G.push(); render.G.scale(THEME.hgssScale, THEME.hgssScale)
    end
    local mode, top, fade = screenState()
    THEME.nativeFocus = not session.battle or customBattleLayout()
    local summary = displayRuntime.summaryContext(compat.isScreen(top, "summary") and top or nil)
    local hgssSummary = THEME.style == "hgss" and summary
      and compat.summary.supports(summary, session.game)
    local learnScreen = screenById("MoveLearnMenu")
      or screenById("Gen2MoveDeleter")
    local learn = displayRuntime.moveLearnScreen()
    local fieldParty, fieldPartyData, fieldPartyTitle =
      displayRuntime.fieldBagParty()
    local fieldPp = displayRuntime.fieldPpMoveScreen()
    local pcKind, pcRoot = pcSession()
    local choice, labels, choiceField = dialogueChoice()
    local startMenu = displayRuntime.startMenu()
    local namingKeys = screenContract(top, "naming")
    local naming = namingKeys and top or nil
    local unsupportedSpecial = (learnScreen and not learn and not fieldPp)
      or (compat.isScreen(top, "naming") and not naming)
    local levelStats = compat.levelUpMon(top)
      or displayRuntime.levelUp:fieldMon(top)
    local pressTouch
    if THEME.style == "hgss" then
      THEME.hgss.nativeFocus = session.battle ~= nil and customBattleLayout() and not session.battle.nativeUnsupported
      local owned = learn or naming or levelStats or session.battle or fieldPp
        or fieldParty or hgssSummary or pcKind or startMenu
      local battlePanel = screenContract(top, "party") or compat.battleBagMenu(top)
        or screenContract(top, "pp") or hgssSummary
      local battleLocked = session.battle and not startMenu and not session.moveInfo and not learn
        and not choice and not battlePanel
        and session.battle.prompt ~= "menu" and session.battle.prompt ~= "moves"
        and session.battle.prompt ~= "safari" and session.battle.prompt ~= "mimic"
        and session.battle.prompt ~= "forget"
      local blocked = unsupportedSpecial or battleLocked or session.battle and (session.battle.nativeUnsupported or session.battle.nativeInputLocked)
        or session.battle and top and top.isTextBox and not choice
        or session.battle and top and top ~= battleState() and not top.isTextBox
          and not startMenu and not battlePanel and not learn and not choice and not levelStats
        or startMenu and (startMenu.notice or not displayRuntime.StartMenu.cursor(startMenu))
        or learn and top and top.isTextBox and not choice
        or session.partyActionSlot and THEME.hgss.partyActionClosing
        or session.touchDown and not displayRuntime.touchGuard:allow(love.timer.getTime(), session.touchDown.epoch)
      if session.battle and currentBattleUIMode() == "info" then
        blocked = session.touchDown and not displayRuntime.touchGuard:allow(love.timer.getTime(), session.touchDown.epoch)
      end
      pressTouch = displayRuntime.pressTouch(mode, choice, session.touchDown, owned, blocked)
      THEME.hgss:setTouch(pressTouch and pressTouch.x,
        pressTouch and pressTouch.y, not session.pendingFly and not session.pendingAction)
      THEME.hgss.v4Page = nil
      THEME.hgss:backdrop()
    end
    if session.battle and currentBattleUIMode() == "info" then
      drawBattle()
    elseif session.moveInfo then
      drawMoveInfo(session.moveInfo)
    elseif startMenu then
      displayRuntime.drawStartMenu(startMenu)
    elseif learn and (not choice or learn.field) then
      drawLearnMove(learn, top, choice, choiceField)
    elseif naming then
      drawNaming(naming, namingKeys)
    elseif unsupportedSpecial then
      drawUnavailableMenu()
    elseif levelStats then
      drawLevelUpStats(levelStats)
    elseif fieldPp then
      drawPpItemMoves(fieldPp)
    elseif choice then
      drawDialogueChoice(choice, labels, session.battle and session.battle.message, choiceField)
    elseif session.battle then
      drawBattle()
    elseif hgssSummary then
      drawBattleSummary(summary)
    elseif fieldParty then
      drawParty(fieldPartyData, fieldPartyTitle, true, nil,
        (THEME.style ~= "hgss" or THEME.hgss.nativeFocus) and fieldParty.index or nil, false)
    -- Game path [Gen 3]: unknown native modal layers keep the companion visible but inactive so their controls remain native.
    elseif displayRuntime.gen3 and mode == "locked"
        and top and top.nativeModal then
      -- Unknown native menus leave the companion visible but inactive.
      drawUnavailableMenu()
    elseif pcKind then
      drawPc(pcKind, pcRoot, top)
    elseif mode == "title" then
      drawTitle()
    else
      displayRuntime.drawCompanionPage()
    end
    if not displayRuntime.nativeHandoff and not startMenu and not learn and not naming and not session.battle and not choice and not levelStats
        and not fieldPp and not fieldParty and not hgssSummary
        and not (pcKind and mode == "locked")
        and mode ~= "title" and mode ~= "active" then
      if THEME.style == "hgss" and mode == "loading" then
        render.G.push()
        render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        THEME.hgss:loadingOverlay("LOADING AREA", love.timer.getTime())
        render.G.pop()
      else
        drawDim(fade, mode == "textbox" and textPrompt(top))
        if mode == "loading" then
          box("fill", 27, 57, 106, 30, render.DARK)
          outline(27, 57, 106, 30, render.PAPER)
          centered(fit(THEME:translate("LOADING AREA"), 16), 69, render.PAPER)
        end
      end
    end
    if not learn and not session.battle and mode == "active" then
      if THEME.style == "hgss" then
        THEME.hgss:setTouch(pressTouch and pressTouch.x, pressTouch and pressTouch.y)
      end
      if session.pendingFly then drawFlyPrompt()
      elseif session.pendingAction then drawActionPrompt() end
    end
    if THEME.style ~= "hgss" and THEME.style ~= "classic" then
      outline(1, 1, WIDTH - 2, HEIGHT - 2, THEME.blue)
      box("fill", 3, 1, 16, 1, THEME.red)
      box("fill", WIDTH - 19, HEIGHT - 2, 16, 1, THEME.red)
    elseif THEME.style == "classic" then
      outline(1, 1, WIDTH - 2, HEIGHT - 2, render.INK)
    end
    if THEME.style == "hgss" then THEME.hgss.nativeFocus = false end
    THEME.nativeFocus = nil
    if highResolution then render.G.pop() end
    render.G.setCanvas()
  end

end
