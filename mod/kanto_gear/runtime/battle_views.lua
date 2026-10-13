return function(
  THEME, assist, battleState, bottomBattleHud, box, button,
  companionMoveGrid, customBattleLayout, displayRuntime, fit, header, hgssRuntime,
  mod, outline, render, session, text
)
  local function drawBattleRoot()
    if THEME.style == "hgss" then
      local mon = hgssRuntime.battleMon()
      local playerTeam, enemyTeam = hgssRuntime.battleTeams()
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      local selected = customBattleLayout() and session.battle.menuIndex or nil
      if bottomBattleHud() then
        THEME.hgss:battleFullRoot(mon, hgssRuntime.battleStatus("player"),
          hgssRuntime.battleStatus("enemy"), hgssRuntime.battlePortrait,
          playerTeam, enemyTeam, selected, hgssRuntime.battleStatuses())
      else
        THEME.hgss:battleRoot(mon, hgssRuntime.battlePortrait, playerTeam, enemyTeam, selected,
          session.battle.prompt == "menu" and not session.battle.nativeInputLocked)
      end
      render.G.pop()
      return
    end
    header(THEME:translate(session.battle.kind == "wild" and "Wild battle"
      or session.battle.kind == "trainer" and "Trainer battle" or "BATTLE"))
    button(3, 24, 76, 54, THEME:translate("FIGHT"), session.battle.menuIndex == 1)
    button(81, 24, 76, 54, THEME:translate(displayRuntime.gen3 and "ITEM" or "PKMN"),
      session.battle.menuIndex == (displayRuntime.gen3 and 3 or 2))
    button(3, 81, 76, 56, THEME:translate(displayRuntime.gen3 and "PKMN" or "ITEM"),
      session.battle.menuIndex == (displayRuntime.gen3 and 2 or 3))
    button(81, 81, 76, 56, THEME:translate("RUN"), session.battle.menuIndex == 4)
  end

  local function drawSafari()
    if THEME.style == "hgss" then
      local playerTeam, enemyTeam = hgssRuntime.battleTeams()
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      local model = displayRuntime.SafariPage.model(session.battle)
      model.index = customBattleLayout() and session.battle.menuIndex or nil
      if bottomBattleHud() then
        THEME.hgss:battleTeamStrip(playerTeam, enemyTeam)
        THEME.hgss:battleStatusCard(hgssRuntime.battleStatus("enemy"),
          6, 33, 228, false, hgssRuntime.battlePortrait)
        THEME.hgss:battleFullSafari(model)
      else
        THEME.hgss:battleSafari(model, playerTeam, enemyTeam)
      end
      render.G.pop()
      return
    end
    header(THEME:translate("SAFARI"))
    button(3, 24, 76, 54,
           THEME:format("BALL x%d", session.battle.safariBalls or 0),
           session.battle.menuIndex == 1)
    local actions = displayRuntime.SafariPage.model(session.battle).actions
    button(81, 24, 76, 54, THEME:translate(actions[2].label), session.battle.menuIndex == 2)
    button(3, 81, 76, 56, THEME:translate(actions[3].label),
      session.battle.menuIndex == 3)
    button(81, 81, 76, 56, THEME:translate("RUN"), session.battle.menuIndex == 4)
  end

  local function drawMimic()
    if THEME.style == "hgss" then
      local moves = {}
      for slot, move in ipairs(session.battle.mimicMoves or {}) do
        moves[slot] = hgssRuntime.moveView(move)
      end
      local playerTeam, enemyTeam = hgssRuntime.battleTeams()
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:battleMimic({ moves = moves,
        title = THEME:moveName({ id = "MIMIC" }, session.game and session.game.data),
        index = session.battle.mimicIndex or 1 }, playerTeam, enemyTeam)
      render.G.pop()
      return
    end
    header(THEME:moveName({ id = "MIMIC" }, session.game and session.game.data))
    for i, move in ipairs(session.battle.mimicMoves or {}) do
      button(8, 25 + (i - 1) * 28, 144, 25,
             THEME:moveName(move, session.game and session.game.data), session.battle.mimicIndex == i,
             true)
    end
  end

  local function effectLabel(mult)
    if mult == nil then return "--" end
    if mult == 0 then return "0X" end
    if mult > 10 then return mult >= 40 and "4X" or "2X" end
    if mult < 10 then return mult <= 2 and "1/4" or "1/2" end
    return "1X"
  end

  local function chanceLabel(chance)
    if chance == nil then return "--" end
    if chance == math.floor(chance) then return ("%d%%"):format(chance) end
    return ("%.1f%%"):format(chance)
  end

  displayRuntime.moveInfoBadge = function(x, y, dark)
    outline(x, y, 11, 11, dark and render.PAPER or render.INK)
    text("X", x + 3, y + 2, dark and render.PAPER or render.INK)
  end

  local function moveCard(move, x, y, selected)
    selected = selected and customBattleLayout()
    local unavailable = THEME:moveUnavailableReason(move)
    local disabled = unavailable ~= nil
    local dark = selected and not disabled
    box("fill", x, y, 76, 53, disabled and render.PAPER or dark and render.DARK or render.MID)
    outline(x, y, 76, 53, disabled and render.DARK or render.INK)
    text(fit(THEME:moveName(move, session.game and session.game.data), 10),
         x + 4, y + 4, dark and render.PAPER or render.INK)
    text(unavailable and fit(THEME:translate(unavailable), 10, false)
         or THEME:format("PP %d/%d", move.pp or 0, move.maxPp or 0),
         x + 4, y + 19, dark and render.PAPER or render.DARK)
    text(fit(THEME:typeName(move.type, mod.content), 7), x + 4, y + 34,
         dark and render.PAPER or render.DARK)
    if assist("type_hints") then
      text(effectLabel(move.effectiveness), x + 56, y + 34,
           dark and render.PAPER or render.INK)
    end
    if assist("move_details") then
      displayRuntime.moveInfoBadge(x + 63, y + 2, dark)
    end
  end

  local function moveRow(move, y, selected)
    selected = selected and customBattleLayout()
    local unavailable = THEME:moveUnavailableReason(move)
    local disabled = unavailable ~= nil
    local dark = selected and not disabled
    box("fill", 8, y, 144, 27, disabled and render.PAPER or dark and render.DARK or render.MID)
    outline(8, y, 144, 27, disabled and render.DARK or render.INK)
    text(fit(THEME:moveName(move, session.game and session.game.data), 11),
         12, y + 3, dark and render.PAPER or render.INK)
    text(unavailable and fit(THEME:translate(unavailable), 8, false)
         or THEME:format("PP %d/%d", move.pp or 0, move.maxPp or 0),
         88, y + 3, dark and render.PAPER or render.DARK)
    text(fit(THEME:typeName(move.type, mod.content), 7), 12, y + 15,
         dark and render.PAPER or render.DARK)
    if assist("type_hints") then
      text(effectLabel(move.effectiveness), 110, y + 15,
           dark and render.PAPER or render.INK)
    end
    if assist("move_details") then
      displayRuntime.moveInfoBadge(139, y + 14, dark)
    end
  end

  local function drawMoves()
    if THEME.style == "hgss" then
      local mon = hgssRuntime.battleMon()
      local playerTeam, enemyTeam = hgssRuntime.battleTeams()
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      if bottomBattleHud() then
        THEME.hgss:battleFullStatuses(hgssRuntime.battleStatus("player"),
          hgssRuntime.battleStatus("enemy"), hgssRuntime.battlePortrait,
          playerTeam, enemyTeam, nil, hgssRuntime.battleStatuses())
        THEME.hgss:battleFullMoves(mon)
      else
        THEME.hgss:battleMoves(mon, playerTeam, enemyTeam)
      end
      render.G.pop()
      return
    end
    header(THEME:translate("MOVES"), true)
    local grid = companionMoveGrid(battleState())
    for i = 1, 4 do
      local move = session.battle.moves[i]
      if move then
        if grid then
          local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
          moveCard(move, 3 + col * 78, 24 + row * 56,
                   session.battle.moveIndex == i)
        else
          moveRow(move, 24 + (i - 1) * 28, session.battle.moveIndex == i)
        end
      end
    end
  end

  return chanceLabel, drawBattleRoot, drawMimic, drawMoves, drawSafari, effectLabel
end
