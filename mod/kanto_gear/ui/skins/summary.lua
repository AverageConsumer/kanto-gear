-- Kanto Gear v4: Pokémon summary pages (hero, stats, moves, memo).
return function(H, ui, K)
  local floor, max, min = math.floor, math.max, math.min
  local R, RR, RRrows, CH, CHrows, ART = K.R, K.RR, K.RRrows, K.CH, K.CHrows, K.ART
  local mix, hex = K.mix, K.hex
  local cg, WHITE = K.cg, K.WHITE
  local translate = function(value) return ui.translate and ui.translate(value) or value end

  local function window(self, x, y, w, h, accent)
    self:v4Window(x, y, w, h)
    if accent then
      -- type-tinted diagonal band in the top-right corner (Gen 5 summary)
      local c = mix(self.colors.surface, accent, self.dark and 0.35 or 0.28)
      local band = min(70, w - 20)
      for j = 0, min(13, h - 4) do
        R(x + w - band - 2 + j, y + 2 + j, band - j, 1, c)
      end
    end
  end
  H.v4SummaryWindow = window

  function H:summaryBall(cx, cy, radius)
    self:v4Seat(cx - radius, cy - radius, radius * 2 + 1)
  end

  function H:summaryTop(mon, drawPortrait)
    local colors = self.colors
    local accent = self:typeColor(mon.types and mon.types[1] or mon.type)
    window(self, 6, 34, 228, 80, accent)
    self:v4Seat(9, 38, 62)
    drawPortrait(mon, 12, 41, 56, false)
    local ink, quiet = colors.ink, colors.green
    self:partyName(mon.name, 76, 36, ink, 104)
    if mon.gender == "male" or mon.gender == "female" then
      self:genderIcon(mon.gender, 183, 40)
    end
    self:partyInfo(mon.levelText, 190, 37, ink, 37, "right")
    self:partyInfo(mon.dexText, 76, 50, quiet)
    self:typeBadges(mon, 124, 52, false)
    if mon.statusId then self:v4StatusPill(mon.statusId, 206, 52) end
    if mon.info2Label then
      self:partyInfo(mon.infoLabel, 76, 63, quiet)
      self:partyInfo(self:fitPartyInfo(mon.infoText, 34), 108, 63, ink, 34, "right")
      self:partyInfo(mon.info2Label, 150, 63, quiet)
      self:partyInfo(self:fitPartyInfo(mon.info2Text, 46), 181, 63, ink, 46, "right")
    else
      local label = mon.infoLabel or translate("ITEM")
      local lw = self:partyInfoWidth(label)
      self:partyInfo(label, 76, 63, quiet)
      self:partyInfo(self:fitPartyInfo(mon.infoText or "---", 147 - lw),
        80 + lw, 63, ink, 147 - lw, "right")
    end
    R(76, 75, 151, 1, self.tok.line)
    self:v4HpBar(76, 80, 96, mon.hp, mon.maxHp)
    self:partyInfo(mon.hpText, 176, 77, ink, 51, "right")
    self:summaryExperience(mon)
  end

  function H:summaryExperience(mon)
    local colors, barWidth = self.colors, 120
    self:partyInfo(mon.expLabel or translate("EXP"), 76, 96, colors.green)
    local left = 227
    if mon.nextValue then
      local valueWidth = self:partyInfoWidth(mon.nextValue)
      local label = self:fitPartyInfo(mon.nextLabel or translate("NEXT"), 90 - valueWidth)
      local groupWidth = self:partyInfoWidth(label) + 4 + valueWidth
      left = 227 - groupWidth
      self:partyInfo(label, left, 96, colors.green)
      self:partyInfo(mon.nextValue, 227 - valueWidth, 96, colors.ink)
    end
    barWidth = left - 102 - 5
    if mon.expProgress then
      self:expBar(102, 101, barWidth, mon.expProgress)
    elseif mon.expText then
      self:partyInfo(mon.expText, 102, 96, colors.ink, barWidth, "right")
    end
  end

  ---------------------------------------------------------------------------
  -- Stats: one row per stat with a coloured gauge, best stat flagged
  ---------------------------------------------------------------------------
  local STAT_COLORS = {
    hp = hex("58c060"), attack = hex("f05848"), defense = hex("f0a020"),
    spatk = hex("5890f0"), spdef = hex("40b8b0"), speed = hex("f070b0"),
    special = hex("8070e0"),
  }
  -- summary_model order → canonical display order
  local ORDER6 = { { 6, "hp" }, { 1, "attack" }, { 2, "defense" }, { 4, "spatk" }, { 5, "spdef" }, { 3, "speed" } }
  local ORDER4 = { { 1, "attack" }, { 3, "defense" }, { 4, "special" }, { 2, "speed" } }
  local UP = { "..#..", ".###.", "#####" }

  function H:summaryStats(mon)
    local colors = self.colors
    local stats = mon.stats or {}
    window(self, 6, 118, 228, 92)
    local title = mon.statsTitle or translate("BATTLE STATS")
    self:partyInfo(self:fitPartyInfo(title, 140), 13, 119, colors.green)
    local order = #stats == 6 and ORDER6 or #stats == 4 and ORDER4 or nil
    local rows = {}
    if order then
      for _, entry in ipairs(order) do
        local stat = stats[entry[1]]
        if stat then rows[#rows + 1] = { stat = stat, key = entry[2] } end
      end
    else
      for _, stat in ipairs(stats) do rows[#rows + 1] = { stat = stat, key = "special" } end
    end
    local total, best, bestValue = 0, nil, -1
    for i, row in ipairs(rows) do
      local value = tonumber(row.stat.value) or 0
      if row.key ~= "hp" then
        total = total + value
        if value > bestValue then best, bestValue = i, value end
      end
    end
    local totalText = tostring(total)
    self:partyInfo(totalText, 150, 119, colors.ink, 77, "right")
    R(11, 133, 218, 1, colors.band)
    -- gauges grow in when a new partner opens
    local key = tostring(mon.name) .. ":" .. tostring(mon.levelText) .. ":" .. totalText
    local now = self:clock()
    if self.v4StatsKey ~= key then self.v4StatsKey, self.v4StatsAt = key, now end
    local grow = (self.motionEnabled == false or self.frozenTime) and 1
      or min(1, (now - (self.v4StatsAt or now)) / 0.45)
    if grow < 1 then self:wantAmbient(0.1, 1 / 30) end
    grow = grow * grow * (3 - 2 * grow)
    local scale = max(1, bestValue) * 1.12
    for _, row in ipairs(rows) do
      if row.key == "hp" then scale = max(scale, (tonumber(row.stat.value) or 0) * 1.05) end
    end
    local step = #rows >= 6 and 12 or 18
    local top = 137 + floor((72 - step * #rows) / 2)
    for i, row in ipairs(rows) do
      local y = top + (i - 1) * step
      if i % 2 == 0 then R(9, y - 1, 222, step, colors.bandLight) end
      local value = tonumber(row.stat.value) or 0
      self:partyInfo(self:fitPartyInfo(row.stat.label, 50), 13, y - 1, colors.mutedInk)
      self:partyInfo(tostring(row.stat.value or "--"), 62, y - 1, colors.ink, 30, "right")
      local bx, bw = 104, 122
      local by = y + floor((step - 7) / 2) - 1
      R(bx, by, bw, 7, colors.outline)
      R(bx + 1, by + 1, bw - 2, 5, self.dark and hex("2a3542") or hex("dfe6e1"))
      local c = STAT_COLORS[row.key] or colors.blue
      local f = floor((bw - 2) * min(1, value / scale) * grow)
      R(bx + 1, by + 1, f, 5, c); R(bx + 1, by + 1, f, 2, mix(c, WHITE, 0.45))
      for s = 1, 3 do R(bx + floor(bw * s / 4), by + 1, 1, 5, { 0, 0, 0, 0.18 }) end
      if i == best then ART(UP, 96, by + 2, { ["#"] = colors.red }) end
    end
  end

  ---------------------------------------------------------------------------
  -- Compact identity strip for the moves and memo pages
  ---------------------------------------------------------------------------
  function H:summaryIdentity(mon, drawPortrait)
    local colors = self.colors
    local accent = self:typeColor(mon.types and mon.types[1] or mon.type)
    window(self, 6, 34, 228, 25, accent)
    self:v4Seat(9, 36, 21)
    drawPortrait(mon, 10, 37, 19, false)
    self:partyName(mon.name, 36, 34, colors.ink, 100)
    if mon.gender == "male" or mon.gender == "female" then
      self:genderIcon(mon.gender, 140, 38)
    end
    self:partyInfo(mon.levelText, 150, 35, colors.ink)
    if mon.statusId then self:v4StatusPill(mon.statusId, 177, 37) end
    self:v4HpBar(36, 48, 112, mon.hp, mon.maxHp)
    self:partyInfo(mon.hpText, 152, 45, colors.ink, 75, "right")
  end

  ---------------------------------------------------------------------------
  -- Move rows: lipped type-coloured strips
  ---------------------------------------------------------------------------
  function H:summaryMoveRow(move, x, y, selected, interactive, showChevron)
    local colors = self.colors
    if showChevron == nil then showChevron = interactive end
    local pressed = self:beginPress(x, y, 228, 34, interactive)
    if not move.available and not move.name then
      self:v4Window(x, y, 228, 34, { fill = colors.bandLight })
      R(x + 108, y + 16, 12, 1, colors.disabledInk)
      self:endPress(pressed)
      return
    end
    local a = K.rampOf(move.type and self:typeColor(move.type) or colors.silverDark)
    self:v4Button(x, y, 228, 34, a, { radius = 5, lip = 4, chamfer = 5 })
    -- type plate
    RR(x + 5, y + 5, 50, 21, 3, mix(a.D, { 0, 0, 0, 1 }, 0.25))
    RR(x + 6, y + 6, 48, 19, 2, a.D)
    local typeText = self:fitPartyInfo(move.typeLabel or move.type or "---", 44)
    self:partyInfo(typeText, x + 6 + floor((48 - self:partyInfoWidth(typeText)) / 2) + 1, y + 9, WHITE)
    self:partyName(move.name or "-", x + 62, y + 3, WHITE, 92)
    local lum = a.M[1] * 0.3 + a.M[2] * 0.59 + a.M[3] * 0.11
    self:withoutShadow(self.partyInfo, self, move.ppLabel or translate("PP"), x + 158, y + 3,
      lum > 0.55 and a.D or mix(a.Hi, WHITE, 0.2))
    self:partyInfo(move.ppText or "--", x + 174, y + 3, WHITE, 36, "right")
    if showChevron then self:detailChevron(x + 217, y + 7, WHITE) end
    -- power and accuracy sit in a recessed well so their labels read on
    -- every type colour, light (Ice) or dark (Dark)
    local well = mix(a.D, a.M, 0.25)
    RR(x + 59, y + 16, 160, 13, 3, mix(a.D, { 0, 0, 0, 1 }, 0.2))
    RR(x + 60, y + 17, 158, 11, 2, well)
    local label = mix(a.Hi, WHITE, 0.2)
    self:withoutShadow(function()
      self:partyInfo(move.powerLabel or translate("PWR"), x + 65, y + 16, label)
      self:partyInfo(move.accuracyLabel or translate("ACC"), x + 127, y + 16, label)
    end)
    self:partyInfo(move.powerText or "--", x + 86, y + 16, WHITE, 28, "right")
    self:partyInfo(move.accuracyText or "--", x + 148, y + 16, WHITE, 30, "right")
    if interactive and selected then self:focusFrame(x, y, 228, 34) end
    self:endPress(pressed)
  end

  ---------------------------------------------------------------------------
  -- Memo pages: a ruled notebook card and a growth record
  ---------------------------------------------------------------------------
  local function ruled(self, x, y, w, h, from)
    for ry = y + (from or 14), y + h - 6, 13 do
      R(x + 8, ry, w - 16, 1, mix(self.colors.surface, self.colors.blue, self.dark and 0.25 or 0.16))
    end
    R(x + 18, y + 3, 1, h - 6, mix(self.colors.surface, self.colors.red, self.dark and 0.35 or 0.25))
  end

  function H:summaryTrainerMemo(mon)
    local colors = self.colors
    window(self, 6, 63, 228, 62, colors.blueLight)
    ruled(self, 6, 63, 228, 62, 26)
    self:partyInfo(mon.memoTitle or translate("TRAINER MEMO"), 24, 66, colors.green)
    -- text sits on the notebook rules (rules at 89, 102, 115)
    self:partyInfo(mon.otLabel or translate("ORIGINAL TRAINER"), 24, 80, colors.mutedInk)
    self:partyName(mon.otText or "---", 24, 92, colors.ink, 104)
    R(136, 80, 1, 34, colors.band)
    self:partyInfo(mon.idLabel or translate("ID NO."), 144, 80, colors.mutedInk)
    self:partyName(mon.idText or "00000", 144, 92, colors.ink, 80)
    -- a little OT stamp in the corner
    -- an inked Poké Ball stamp, slightly worn, in the corner
    local ink = mix(colors.surface, colors.red, self.dark and 0.6 or 0.5)
    local sx, sy = 203, 96
    K.RING(sx, sy, 23, 2, ink)
    R(sx + 2, sy + 10, 19, 2, ink)
    K.CIRC(sx + 8, sy + 8, 7, ink)
    K.CIRC(sx + 10, sy + 10, 3, colors.surface)
    R(sx + 5, sy + 4, 3, 1, colors.surface); R(sx + 15, sy + 18, 2, 1, colors.surface)
  end

  function H:summaryGrowthMemo(mon)
    local colors = self.colors
    window(self, 6, 130, 228, 80, colors.exp)
    self:partyInfo(mon.growthTitle or translate("GROWTH RECORD"), 14, 132, colors.green)
    R(11, 146, 218, 1, colors.band)
    self:partyInfo(mon.totalExpLabel or translate("TOTAL EXP"), 14, 150, colors.mutedInk)
    self:label(mon.experienceText or "0", 14, 161, colors.ink)
    R(122, 150, 1, 30, colors.band)
    self:partyInfo(mon.nextLevelLabel or translate("NEXT LEVEL"), 130, 150, colors.mutedInk)
    self:label(mon.nextLevelText or "MAX", 130, 161, colors.ink)
    self:partyInfo(mon.nextExpLabel or translate("TO NEXT"), 14, 186, colors.mutedInk)
    self:partyInfo(mon.nextValue or "0", 66, 186, colors.ink, 160, "right")
    self:expBar(14, 200, 212, mon.expProgress or 0)
  end
end
