return function(H, ui, draw)
  local box = draw.box
  local translate =
    draw.translate
  function H:battleEffectLabel(move)
    local effectiveness = move.effectiveness
    if move.power == 0 or move.powerText == "--" then effectiveness = nil end
    local effectLabel = effectiveness == nil and "--"
      or effectiveness == 0 and "0X"
      or effectiveness >= 40 and "4X"
      or effectiveness > 10 and "2X"
      or effectiveness <= 2.5 and "1/4"
      or effectiveness < 10 and "1/2"
      or "1X"
    return effectLabel, effectiveness
  end

  function H:moveHasStab(mon, move)
    if mon and mon.typeHints == false then return false end
    if not (mon and move and move.type)
        or move.power == 0 or move.powerText == "--" then return false end
    local moveType = tostring(move.type):upper()
    for _, monType in ipairs(mon.types or { mon.type, mon.type2 }) do
      if tostring(monType):upper() == moveType then return true end
    end
    return false
  end

  function H:battleMoves(mon, playerTeam, enemyTeam)
    self:battleTeamStrip(playerTeam, enemyTeam, true)
    for slot = 1, 4 do
      local column, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
      local move = mon.moves[slot]
      self:battleMoveCard(move, 6 + column * 116,
        33 + row * 85, mon.moveIndex == slot, self:moveHasStab(mon, move))
    end
  end

  function H:battleFullMoveHit(x, y)
    for slot, rect in ipairs(self.fullBattleActions) do
      if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
        return slot, x >= rect.x + rect.w - 20 and y < rect.y + 22
      end
    end
  end

  function H:battleMoveInfoStat(x, label, value)
    local colors = self.colors
    self:partyInfo(label, x + 1, 76, colors.mutedInk, 66, "center")
    self:partyInfo(value, x + 1, 91, colors.ink, 66, "center")
  end

  function H:battleMoveInfo(move, stab, playerTeam, enemyTeam)
    self:battleMoveInfoBody(move, stab)
    self:battleTeamStrip(playerTeam, enemyTeam, true)
  end

  function H:battleMoveInfoTransition(mon, playerTeam, enemyTeam, progress)
    local G = ui.graphics
    progress = math.max(0, math.min(1, progress or 0))
    local cardsProgress = math.min(1, progress / 0.85)
    cardsProgress = cardsProgress * cardsProgress * (3 - 2 * cardsProgress)
    for slot = 1, 4 do
      local column, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
      local direction = column == 0 and -1 or 1
      local move = mon.moves[slot]
      local x = 6 + column * 116
        + math.floor(direction * 122 * cardsProgress + 0.5)
      self:battleMoveCard(move, x, 33 + row * 85,
        mon.moveIndex == slot, self:moveHasStab(mon, move))
    end

    local infoProgress = math.max(0, math.min(1, (progress - 0.10) / 0.90))
    infoProgress = infoProgress * infoProgress * (3 - 2 * infoProgress)
    local move = mon.moves[mon.moveIndex or 1] or {}
    G.push()
    G.translate(math.floor(240 * (1 - infoProgress) + 0.5), 0)
    self:battleMoveInfoBody(move, self:moveHasStab(mon, move))
    G.pop()
    self:battleTeamStrip(playerTeam, enemyTeam, true)
  end

  function H:battleMovesTransition(mon, drawPortrait, playerTeam, enemyTeam,
      progress)
    local G = ui.graphics
    progress = math.max(0, math.min(1, progress or 0))
    -- Spread the exit over enough frames to avoid a fast, seven-frame fling.
    local rootProgress = math.min(1, progress / 0.85)
    rootProgress = rootProgress * rootProgress * (3 - 2 * rootProgress)

    local oldX, oldY, oldW, oldH = G.getScissor()
    local x, y = G.transformPoint(0, 28)
    local right, bottom = G.transformPoint(240, 216)
    G.setScissor(x, y, right - x, bottom - y)
    -- The entire 122px card, its 32px starting Y and its shadow must leave.
    -- The old 116px travel left the lower edge hanging below the team strip.
    self:battleFightAction(mon, drawPortrait, true, 0,
      math.floor(-(32 + 122 + 6) * rootProgress + 0.5))
    self:battleBagAction(mon, false,
      math.floor(-76 * rootProgress + 0.5), 0)
    self:battlePartyAction(mon, false,
      math.floor(76 * rootProgress + 0.5), 0)
    self:battleRunAction(mon, false, 0,
      math.floor(68 * rootProgress + 0.5))

    for slot = 1, 4 do
      local start = slot <= 2 and 0.10 or 0.16
      local cardProgress = math.max(0, math.min(1,
        (progress - start) / (1 - start)))
      cardProgress = cardProgress * cardProgress * (3 - 2 * cardProgress)
      local column, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
      local direction = column == 0 and -1 or 1
      local x = 6 + column * 116
        + math.floor(direction * 122 * (1 - cardProgress) + 0.5)
      local move = mon.moves[slot]
      self:battleMoveCard(move, x, 33 + row * 85,
        mon.moveIndex == slot, self:moveHasStab(mon, move))
    end
    if oldX then G.setScissor(oldX, oldY, oldW, oldH) else G.setScissor() end
    self:battleTeamStrip(playerTeam, enemyTeam, true)
  end

  function H:battlePartyTransition(mon, drawPortrait, playerTeam, enemyTeam,
      drawPartyCard, progress, title, clock, period)
    local G = ui.graphics
    progress = math.max(0, math.min(1, progress or 0))
    local pageProgress = progress
    pageProgress = pageProgress * pageProgress * (3 - 2 * pageProgress)

    G.push()
    G.translate(math.floor(-240 * pageProgress + 0.5), 0)
      self:battleRoot(mon, drawPortrait, playerTeam, enemyTeam, 2)
    G.pop()

    G.push()
    G.translate(math.floor(240 * (1 - pageProgress) + 0.5), 0)
    box("fill", 0, 0, 240, 216, self.colors.partyBg)
    self:partyBackdrop()
    self:headerBar(title or translate("PARTY"), true, false)
    self:headerClock(clock or "20:04", period, 139, 72, 6)
    self:battery(214, 8, 4, nil, true, self.colors.ink,
      self.colors.greenLight)
    for slot = 1, 6 do
      local start = (slot - 1) * 0.025
      local cardProgress = math.max(0, math.min(1,
        (pageProgress - start) / (1 - start)))
      cardProgress = 1 - (1 - cardProgress) ^ 3
      local x, y = self:partyPosition(slot)
      drawPartyCard(slot, x + math.floor(14 * (1 - cardProgress) + 0.5),
        y, slot == 1, false)
    end
    G.pop()
  end

end
