return function(H, ui, draw)
  local box = draw.box
  function H:ball(x, y, selected)
    local G, colors = ui.graphics, self.colors
    ui.color(colors.outline)
    G.circle("fill", x, y, 8)
    ui.color(selected and colors.redLight or colors.silverDark)
    G.circle("fill", x, y, 7)
    box("fill", x - 7, y, 14, 6, colors.white)
    box("fill", x - 7, y - 1, 14, 2, colors.outline)
    ui.color(colors.white)
    G.circle("fill", x, y, 3)
    ui.color(colors.outline)
    G.circle("line", x, y, 3)
  end

  function H:statusColor(statusId)
    statusId = tostring(statusId or ""):upper()
    return statusId == "FNT" and self.colors.silver
      or statusId == "SLP" and self.colors.blueLight
      or statusId == "PAR" and self.colors.amberLight
      or (statusId == "PSN" or statusId == "TOX")
        and self:typeColor("POISON")
      or statusId == "BRN" and self.colors.redLight
      or statusId == "FRZ" and self:typeColor("ICE")
      or self.colors.white
  end

  local statusPatterns = {
    PAR = { "...##..", "..##...", ".#####.", "...##..", "..##...",
      ".##....", "##....." },
    SLP = { ".......", "######.", "....##.", "...##..", "..##...",
      ".##....", "######." },
    PSN = { ".#...#.", ".......", "...#...", "..###..", ".#####.",
      "#######", ".#####." },
    TOX = { ".#...#.", ".......", "...#...", "..###..", ".#####.",
      "#######", ".#####." },
    BRN = { "...#...", "..##...", ".####..", ".#####.", "#######",
      ".#####.", "..###.." },
    FRZ = { "...#...", "#..#..#", ".#.#.#.", "..###..", ".#.#.#.",
      "#..#..#", "...#..." },
    FNT = { "#.....#", ".#...#.", "..#.#..", "...#...", "..#.#..",
      ".#...#.", "#.....#" },
  }

  function H:statusIcon(statusId, x, y)
    statusId = tostring(statusId or ""):upper()
    local pattern = statusPatterns[statusId]
    if not pattern then return end
    for row, pixels in ipairs(pattern) do
      for column = 1, #pixels do
        if pixels:sub(column, column) == "#" then
          local px, py = x + column - 1, y + row - 1
          box("fill", px + 1, py + 1, 1, 1, self.colors.outline)
        end
      end
    end
    for row, pixels in ipairs(pattern) do
      for column = 1, #pixels do
        if pixels:sub(column, column) == "#" then
          box("fill", x + column - 1, y + row - 1, 1, 1,
            self:statusColor(statusId))
        end
      end
    end
  end

  function H:partySwap(drawPartyCard, source, target)
    for slot = 1, 6 do
      local x, y = self:partyPosition(slot)
      drawPartyCard(slot, x, y, slot == target, false)
    end
  end

  function H:partySwapTransition(drawPartyCard, source, target, progress,
      actionCount, statsLabel, swapLabel)
    progress = math.max(0, math.min(1, progress or 0))
    local eased = 1 - (1 - progress) ^ 3
    local sourceX, sourceY = self:partyPosition(source)
    local heroY = self:partyActionHeroY(actionCount)
    drawPartyCard(source,
      64 + (sourceX - 64) * eased,
      heroY + (sourceY - heroY) * eased,
      progress < 0.45, false)

    for slot = 1, 6 do
      if slot ~= source then
        local start = 0.18 + math.max(0, slot - 2) * 0.025
        local cardProgress = math.max(0, math.min(1,
          (progress - start) / (1 - start)))
        cardProgress = 1 - (1 - cardProgress) ^ 3
        local x, y = self:partyPosition(slot)
        local column = (slot - 1) % 2
        local direction = column == 0 and -1 or 1
        drawPartyCard(slot,
          x + direction * 122 * (1 - cardProgress), y,
          slot == target and cardProgress > 0.62, false)
      end
    end

    local actionOffset = math.floor(230 * eased + 0.5)
    local x, y, w, h = self:partyActionRow(1, actionCount)
    self:actionRow(x + actionOffset, y, w, h, statsLabel, "stats", 0)
    if actionCount > 1 then
      x, y, w, h = self:partyActionRow(2, actionCount)
      self:actionRow(x + actionOffset, y, w, h, swapLabel, "swap", 0)
    end
  end

  function H:partySwapCommitTransition(drawPartyCard, source, target,
      progress)
    progress = math.max(0, math.min(1, progress or 0))
    local eased = progress * progress * (3 - 2 * progress)
    for slot = 1, 6 do
      if slot ~= source and slot ~= target then
        local x, y = self:partyPosition(slot)
        drawPartyCard(slot, x, y, false, false)
      end
    end
    local sx, sy = self:partyPosition(source)
    local tx, ty = self:partyPosition(target)
    local bend = math.sin(progress * math.pi) * 8
    local function moving(slot, x, y, dx, dy, side)
      drawPartyCard(slot, math.floor(x + (dx - x) * eased + 0.5),
        math.floor(math.max(32, math.min(152,
          y + (dy - y) * eased + side * bend)) + 0.5),
        slot == source, false)
    end
    moving(target, tx, ty, sx, sy, 1)
    moving(source, sx, sy, tx, ty, -1)
  end

  function H:summaryPage(mon, drawPortrait)
    self:summaryTop(mon, drawPortrait)
    self:summaryStats(mon)
  end

  function H:summaryMoves(mon, drawPortrait)
    self:summaryIdentity(mon, drawPortrait)
    for slot = 1, 4 do
      local move = mon.moves[slot] or {}
      local interactive = mon.moveDetails and move.available
      self:summaryMoveRow(move, 6, 63 + (slot - 1) * 37,
        interactive and mon.moveIndex == slot, interactive)
    end
  end

  function H:summaryContest(mon, drawPortrait)
    self:summaryIdentity(mon, drawPortrait)
    local c = self.colors
    for slot = 1, 4 do
      local move, y = mon.moves[slot], 63 + (slot - 1) * 37
      local pressed = self:beginPress(6, y, 228, 34, move.available)
      self:panel(6, y, 228, 34, false, self:typeColor(move.type), self:typeColor(move.type))
      self:moveTypeBadge(move, 14, y + 12)
      self:partyName(move.name, 70, y + 4, c.ink, 88)
      if move.available then
        self:partyInfo(move.ppLabel, 163, y + 4, c.green)
        self:partyInfo(move.ppText, 183, y + 4, c.ink, 35, "right")
        self:detailChevron(223, y + 8, c.ink)
        for column, pair in ipairs({ { move.powerLabel, move.powerText }, { move.accuracyLabel, move.accuracyText } }) do
          local x = 70 + (column - 1) * 77
          local label = self:fitPartyInfo(pair[1], 56)
          local width = self:partyInfoWidth(label) + 4 + self:partyInfoWidth(pair[2])
          local left = x + math.floor((70 - width) / 2)
          self:partyInfo(label, left, y + 19, c.green)
          self:partyInfo(pair[2], left + self:partyInfoWidth(label) + 4, y + 19, c.ink)
        end
      end
      self:endPress(pressed)
    end
  end

  function H:summaryContestInfo(move)
    local c = self.colors
    self:panel(6, 34, 228, 51, false, nil, self:typeColor(move.type))
    self:partyInfo(self:fitPartyInfo(move.name, 208), 16, 41, c.ink, 208, "center")
    self:moveTypeBadge(move, 96, 63)
    self:panel(6, 90, 228, 120, false, nil, c.blueLight)
    for column, pair in ipairs({ { move.powerLabel, move.powerText }, { move.accuracyLabel, move.accuracyText } }) do
      local x = 16 + (column - 1) * 108
      self:partyInfo(self:fitPartyInfo(pair[1], 100), x, 97, c.green, 100, "center")
      self:partyInfo(pair[2], x, 111, c.ink, 100, "center")
    end
    box("fill", 120, 96, 1, 27, c.band)
    box("fill", 16, 128, 208, 1, c.band)
    local lines = move.descriptionLines or {}
    local top = 135 + math.floor((66 - #lines * 11) / 2)
    for i, line in ipairs(lines) do
      self:partyInfo(line, 20, top + (i - 1) * 11, c.ink, 200, "center")
    end
  end

  function H:summaryMemo(mon, drawPortrait)
    self:summaryIdentity(mon, drawPortrait)
    if mon.abilityText then
      local c = self.colors
      self:panel(6, 63, 228, 68, false, nil, c.blueLight)
      self:partyInfo(mon.otLabel, 17, 69, c.green)
      self:partyName(mon.otText or "---", 17, 82, c.ink, 109)
      box("fill", 136, 68, 1, 27, c.bandLight)
      self:partyInfo(mon.idLabel, 146, 69, c.green)
      self:partyName(mon.idText, 146, 82, c.ink, 77)
      box("fill", 16, 101, 208, 1, c.band)
      self:partyInfo(mon.natureLabel, 17, 112, c.green, 76)
      self:partyInfo(self:fitPartyInfo(mon.natureText, 125), 98, 112, c.ink, 125, "right")
      self:panel(6, 136, 228, 74, false, nil, c.exp)
      self:partyInfo(mon.abilityLabel, 17, 142, c.green, 76)
      self:partyInfo(self:fitPartyInfo(mon.abilityText, 125), 98, 142, c.ink, 125, "right")
      box("fill", 16, 156, 208, 1, c.band)
      for i, line in ipairs(mon.abilityLines or {}) do self:partyInfo(line, 18, 162+(i-1)*11, c.ink, 204) end
      self:partyType(mon.totalExpLabel, 17, 199, c.green, 98)
      self:partyType(mon.experienceText, 126, 199, c.ink, 97)
      return
    end
    self:summaryTrainerMemo(mon)
    self:summaryGrowthMemo(mon)
  end

  function H:summaryPageTransition(mon, drawPortrait, progress, from, to)
    local G = ui.graphics
    progress = math.max(0, math.min(1, progress))
    local eased = progress * progress * (3 - 2 * progress)
    local direction = (to - from + 3) % 3 == 1 and 1 or -1
    local oldX, oldY, oldW, oldH = G.getScissor()
    local contentTop = from ~= 1 and to ~= 1 and 61 or 28
    if contentTop == 61 then self:summaryIdentity(mon, drawPortrait) end
    local x, y = G.transformPoint(0, contentTop)
    local right, bottom = G.transformPoint(240, 216)
    G.setScissor(x, y, right - x, bottom - y)
    local function draw(which, offset)
      G.push(); G.translate(offset, 0)
      box("fill", 0, contentTop, 240, 216 - contentTop, self.colors.partyBg)
      if which == 1 then self:summaryPage(mon, drawPortrait)
      elseif which == 2 then self:summaryMoves(mon, drawPortrait)
      else self:summaryMemo(mon, drawPortrait) end
      G.pop()
    end
    local offset = math.floor(240 * eased + 0.5) * direction
    draw(from, -offset); draw(to, 240 * direction - offset)
    if oldX then G.setScissor(oldX, oldY, oldW, oldH) else G.setScissor() end
  end

  function H:summaryTransition(mon, drawPortrait, progress, actionCount,
      statsLabel, swapLabel)
    local G = ui.graphics
    progress = math.max(0, math.min(1, progress or 0))
    local eased = 1 - (1 - progress) ^ 3
    local heroY = self:partyActionHeroY(actionCount)
    local actionOffset = math.floor(132 * eased + 0.5)

    local anchorProgress = math.min(1, progress / 0.12)
    local anchorX = 64 - 12 * anchorProgress
    local anchorY = heroY + (42 - heroY) * anchorProgress
    if progress < 0.12 then
      self:partyCard(mon, anchorX, anchorY, true, false, drawPortrait)
    else
      local panelProgress = math.min(1, (progress - 0.12) / 0.50)
      panelProgress = 1 - (1 - panelProgress) ^ 3
      local x = 52 + (6 - 52) * panelProgress
      local y = 42 + (34 - 42) * panelProgress
      local width = 112 + (228 - 112) * panelProgress
      local height = 56 + (80 - 56) * panelProgress
      if panelProgress >= 1 then
        self:summaryTop(mon, drawPortrait)
      else
        x, y = math.floor(x + 0.5), math.floor(y + 0.5)
        self:panel(x, y, math.floor(width + 0.5), math.floor(height + 0.5), false)
        -- Keep the portrait identifiable while the panel grows. Text appears
        -- at its final position instead of being cut by a moving scissor.
        self:summaryBall(x + 32, y + 35, math.floor(math.min(29, (height - 10) / 2)))
        drawPortrait(mon, x + 8, y + 10, 48, false)
        self:partyName(mon.name, x + 66, y + 8, self.colors.ink,
          math.floor(width - 74))
      end
    end

    local left, top, width, height = self:partyActionRow(1, actionCount)
    self:actionRow(left, top, width, height, statsLabel, "stats", actionOffset)
    if actionCount > 1 then
      left, top, width, height = self:partyActionRow(2, actionCount)
      self:actionRow(left, top, width, height, swapLabel, "swap", actionOffset)
    end

    local statsProgress = math.max(0, math.min(1,
      (progress - 0.28) / 0.72))
    statsProgress = 1 - (1 - statsProgress) ^ 3
    G.push()
    G.translate(0, math.floor(98 * (1 - statsProgress) + 0.5))
    self:summaryStats(mon)
    G.pop()
  end

  function H:partySlot(x, y, count)
    return ui.partyPage.hit(self, x * 1.5, y * 1.5, count, false)
  end

end
