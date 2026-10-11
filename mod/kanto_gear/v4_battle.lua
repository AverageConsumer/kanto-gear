-- Kanto Gear v4: battle surfaces (root actions, moves, messages, team strip).
return function(H, ui, K)
  local floor, max, min = math.floor, math.max, math.min
  local R, P, RR, RRrows, CH, CHrows = K.R, K.P, K.RR, K.RRrows, K.CH, K.CHrows
  local CIRC, CIRCrows, RING, ELL, ART = K.CIRC, K.CIRCrows, K.RING, K.ELL, K.ART
  local mix, hex, setc = K.mix, K.hex, K.setc
  local base, cg, WHITE = K.base, K.cg, K.WHITE
  local translate = function(value) return ui.translate and ui.translate(value) or value end

  local function ramp(self, name)
    local c = self.colors[name] or self.colors.red
    local named = {
      red = hex("e04838"), amber = hex("e09a20"), blue = hex("3878d0"), green = hex("3ea04c"),
    }
    if cg(self) then
      named = { red = hex("e8483c"), amber = hex("f0a020"), blue = hex("3878e0"), green = hex("38b058") }
    end
    return K.rampOf(named[name] or c)
  end
  H.v4BattleRamp = ramp

  ---------------------------------------------------------------------------
  -- Team strip balls (9×9, centred on x, y)
  ---------------------------------------------------------------------------
  local BALL9 = {
    "..ooooo..", ".orrrrro.", "orrrrrrro", "orrrrrrro", "oooowoooo",
    "owwwwwwwo", "owwwwwwwo", ".owwwwwo.", "..ooooo..",
  }
  local EMPTY9 = {
    "..ooooo..", ".o.....o.", "o.......o", "o.......o", "o.......o",
    "o.......o", "o.......o", ".o.....o.", "..ooooo..",
  }
  function H:battleTeamBall(x, y, state)
    local alive = state
    if type(state) == "table" then alive = state.alive end
    local left, top = x - 4, y - 4
    if state == nil then
      ART(EMPTY9, left, top, { o = self.colors.silverDark })
      return
    end
    local statusId = type(state) == "table" and tostring(state.status or ""):upper() or ""
    local hasStatus = alive and statusId ~= "" and statusId ~= "FNT"
    local pal = { o = hex("141414"), r = hex("f05040"), w = hex("f8f8f8") }
    if hasStatus then pal.r, pal.w = hex("e8b818"), hex("f8f0c0") end
    if not alive then pal.r, pal.w = hex("505860"), hex("8890a0") end
    ART(BALL9, left, top, pal)
    if alive then P(left + 2, top + 2, hex("f8b0a0")); P(left + 3, top + 1, hex("f8b0a0")) end
  end

  ---------------------------------------------------------------------------
  -- Lipped action buttons
  ---------------------------------------------------------------------------
  function H:battleActionPanel(x, y, w, h, colorName, selected)
    local a = ramp(self, colorName)
    self:v4Button(x, y, w, h, a, { radius = h > 80 and 8 or 6, lip = 5 })
    if selected then self:focusFrame(x, y, w, h) end
  end

  function H:battleFightAction(mon, drawPortrait, selected, offsetX, offsetY)
    local G, colors = ui.graphics, self.colors
    offsetX, offsetY = offsetX or 0, offsetY or 0
    local pressed = self:beginPress(22 + offsetX, 32 + offsetY, 196, 122)
    G.push()
    G.translate(offsetX, offsetY)
    self:battleActionPanel(22, 32, 196, 122, "red", selected)
    local a = ramp(self, "red")
    -- Poké Ball seam across the button
    local seam = cg(self) and colors.outline or mix(a.D, { 0, 0, 0, 1 }, 0.35)
    R(24, 81, 192, 5, seam)
    if not cg(self) then R(24, 82, 192, 3, mix(a.D, a.M, 0.2)) end
    -- window
    local d, wx, wy = 74, 83, 46
    CIRC(wx - 3, wy - 3, d + 6, seam)
    CIRC(wx - 1, wy - 1, d + 2, cg(self) and self.tok.acc.M or hex("f8d0c0"))
    CIRC(wx, wy, d, cg(self) and hex("121820") or hex("1c1012"))
    if cg(self) then
      local grid = hex("18212c")
      for j = 6, d - 6, 6 do
        local l = floor(d / 2 - math.sqrt(max(0, (d / 2) ^ 2 - (j - d / 2) ^ 2)) + 0.5)
        R(wx + l, wy + j, d - 2 * l, 1, grid)
      end
      for i = 6, d - 6, 6 do
        local l = floor(d / 2 - math.sqrt(max(0, (d / 2) ^ 2 - (i - d / 2) ^ 2)) + 0.5)
        R(wx + i, wy + l, 1, d - 2 * l, grid)
      end
      ELL(wx + 10, wy + 51, 54, 15, self.tok.acc.M)
      ELL(wx + 11, wy + 52, 52, 13, hex("0f3c4e"))
      ELL(wx + 16, wy + 54, 42, 7, hex("16506a"))
    else
      CIRCrows(wx, wy, d, floor(d * 0.62), d, hex("3a1e1c"))
      ELL(wx + 8, wy + 52, 58, 14, hex("2a1a10"))
      ELL(wx + 9, wy + 53, 56, 12, hex("8a6a40"))
      ELL(wx + 13, wy + 53, 48, 7, hex("b8945c"))
      ELL(wx + 21, wy + 54, 32, 3, hex("d8b880"))
    end
    drawPortrait(mon, 92, 47, 56, false)
    -- gloss sweep
    local t = self:clock()
    local k = (t % 4.2) / 4.2
    self:wantAmbient(0.25)
    if k < 0.22 and self.motionEnabled ~= false then
      local sx = floor(22 - 40 + k / 0.22 * 276)
      setc({ 1, 1, 1, 0.14 })
      for j = 0, 112 do
        local px = sx - floor(j / 2)
        local l, r = 22 + 2, 22 + 196 - 8
        if px + 6 > l and px < r then
          G.rectangle("fill", max(px, l), 33 + j, min(px + 6, r) - max(px, l), 1)
        end
      end
    end
    local label = mon.fightLabel or translate("FIGHT")
    local large = ui.largeFont
    if large and large.hasGlyphs and large:hasGlyphs(label) and large:getWidth(label) <= 180 then
      local previous = G.getFont()
      G.setFont(large)
      setc(WHITE)
      G.print(label, 120 - floor(large:getWidth(label) / 2), 118)
      if previous then G.setFont(previous) end
    else
      local fight = self:fitLabel(label, 96)
      self:label(fight, 120 - floor(self:labelWidth(fight) / 2), 126, WHITE)
    end
    G.pop()
    self:endPress(pressed)
  end

  ---------------------------------------------------------------------------
  -- Gen 4 message window
  ---------------------------------------------------------------------------
  function H:v4MessageWindow(x, y, w, h)
    local colors, tok = self.colors, self.tok
    if cg(self) then
      if self:shadowVisible() then CH(x + 2, y + 2, w, h, 6, colors.shadow) end
      CH(x, y, w, h, 6, colors.outline)
      CH(x + 1, y + 1, w - 2, h - 2, 5, colors.surface)
      R(x + 8, y + 3, 30, 2, tok.acc.M); R(x + w - 38, y + h - 5, 30, 2, tok.acc.M)
      return
    end
    if self:shadowVisible() then RR(x + 2, y + 2, w, h, 5, colors.shadow) end
    RR(x, y, w, h, 5, colors.outline)
    RR(x + 1, y + 1, w - 2, h - 2, 4, self.dark and hex("5c6c84") or hex("f8f8f8"))
    RR(x + 3, y + 3, w - 6, h - 6, 3, tok.acc.M)
    RR(x + 4, y + 4, w - 8, h - 8, 2, colors.surface)
    for _, p in ipairs({ { x + 6, y + 6 }, { x + w - 8, y + 6 }, { x + 6, y + h - 8 }, { x + w - 8, y + h - 8 } }) do
      R(p[1], p[2], 2, 2, tok.acc.L)
    end
  end

  local MESSAGE_X, MESSAGE_WIDTH = 10, 220
  function H:v4AdvanceArrow(x, y)
    local bob = floor(self:clock() / 0.4) % 2
    self:wantAmbient(0.4)
    local c = cg(self) and self.tok.acc.M or self.colors.red
    ART({ "ooooooooo", ".o#####o.", "..o###o..", "...o#o...", "....o...." }, x, y + bob,
      { o = self.colors.outline, ["#"] = c })
  end

  function H:battleMessage(lines, canAdvance, playerTeam, enemyTeam, title, now)
    local colors = self.colors
    lines = lines or {}
    self:battleBackdrop()
    self:battleTeamStrip(playerTeam, enemyTeam)
    local pressed = self:beginPress(MESSAGE_X, 38, MESSAGE_WIDTH, 165, canAdvance)
    self:v4MessageWindow(MESSAGE_X, 38, MESSAGE_WIDTH, 165)
    local contentTop, contentHeight = 53, 105
    if title then
      local shown = self:fitPartyInfo(title, 190)
      self:partyInfo(shown, 25, 53, colors.green, 190, "center")
      R(25, 68, 190, 1, colors.band)
      contentTop, contentHeight = 76, 82
    end
    if #lines == 0 then lines = { "..." } end
    local lineHeight = 18
    local blockHeight = 11 + (#lines - 1) * lineHeight
    local y = contentTop + floor((contentHeight - blockHeight) / 2)
    for _, line in ipairs(lines) do
      local shown = self:fitLabel(line, 192)
      self:label(shown, 24, y, colors.ink, 192, "center")
      y = y + lineHeight
    end
    if canAdvance then self:v4AdvanceArrow(116, 180) end
    self:endPress(pressed)
  end

  ---------------------------------------------------------------------------
  -- Move cards: type-coloured lipped buttons
  ---------------------------------------------------------------------------
  local UP2 = { "..#....#..", ".###..###.", "#####.####", "..#....#.." }
  local DOWN = { "#####", ".###.", "..#.." }
  local CROSS = { "#...#", ".#.#.", "..#..", ".#.#.", "#...#" }
  local STAR = { "...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", ".#...#." }

  function H:battleMoveCard(move, x, y, selected, stab)
    if not move or move.available == false then return end
    local colors = self.colors
    local disabled = move.disabled
    local pressed = self:beginPress(x, y, 112, 80, not disabled)
    local tc = self:typeColor(move.type)
    local a = K.rampOf(disabled and mix(tc, hex("808890"), 0.75) or tc)
    self:v4Button(x, y, 112, 80, a, { radius = 6, lip = 5 })
    local ink = WHITE
    local shade = a.D
    self:partyName(move.name or "-", x + 7, y + 4, ink, 88)
    if stab and not disabled then ART(STAR, x + 98, y + 6, { ["#"] = hex("f8e070") })
    else self:detailChevron(x + 101, y + 8, ink) end
    local label = a.D
    RR(x + 7, y + 20, 44, 10, 3, mix(a.D, { 0, 0, 0, 1 }, 0.25))
    RR(x + 8, y + 21, 42, 8, 2, a.D)
    local typeText = self:fitPartyInfo(move.typeLabel or move.type or "---", 40)
    self:partyInfo(typeText, x + 7 + floor((44 - self:partyInfoWidth(typeText)) / 2) + 1, y + 18, WHITE)
    self:partyInfo(move.ppLabel or translate("PP"), x + 55, y + 19, label)
    local ppLow = move.pp and move.maxPp and move.maxPp > 0 and move.pp / move.maxPp <= 0.25
    self:partyInfo(move.ppText or "--", x + 70, y + 19,
      disabled and colors.redLight or (ppLow and hex("f8e070") or ink), 35, "right")
    R(x + 7, y + 34, 98, 1, mix(a.D, a.M, 0.4))
    self:partyInfo(move.powerLabel or translate("PWR"), x + 7, y + 38, label)
    self:partyInfo(move.powerText or "--", x + 30, y + 38, ink, 22, "right")
    self:partyInfo(move.accuracyLabel or translate("ACC"), x + 58, y + 38, label)
    self:partyInfo(move.accuracyText or "--", x + 82, y + 38, ink, 23, "right")
    local cy = y + 56
    if disabled then
      RR(x + 9, cy, 94, 12, 3, colors.outline)
      RR(x + 10, cy + 1, 92, 10, 2, colors.red)
      self:partyInfoCentered(move.disabledLabel or translate("DISABLED"), x + 9, cy, 94, 12, WHITE)
    else
      local effectLabel, effectiveness = self:battleEffectLabel(move)
      local icon = effectiveness == 0 and CROSS
        or effectiveness and effectiveness > 10 and UP2
        or effectiveness and effectiveness < 10 and DOWN or nil
      local bg = effectiveness == 0 and hex("c8ccd0")
        or effectiveness and effectiveness > 10 and hex("f8f0b0")
        or effectiveness and effectiveness < 10 and hex("f0d8c8") or hex("e8eef0")
      local fg = effectiveness and effectiveness > 10 and hex("8a4a00")
        or effectiveness == 0 and hex("3a3a40") or hex("2a3640")
      local tw = self:partyInfoWidth(effectLabel)
      local iw = icon and (#icon[1] + 3) or 0
      local cw = tw + iw + 12
      local cx = x + floor((112 - cw) / 2)
      RR(cx, cy + 1, cw, 12, 3, { 0, 0, 0, 0.3 })
      RR(cx, cy, cw, 12, 3, bg)
      if icon then
        local bob = (effectiveness and effectiveness > 10) and floor(self:clock() / 0.3) % 2 or 0
        if bob ~= 0 or effectiveness and effectiveness > 10 then self:wantAmbient(0.3) end
        ART(icon, cx + 6, cy + floor((12 - #icon) / 2) - bob, { ["#"] = fg })
      end
      self:withoutShadow(function()
        self:partyInfo(effectLabel, cx + 6 + iw, cy, fg)
      end)
    end
    if selected and not disabled then self:focusFrame(x, y, 112, 80) end
    self:endPress(pressed)
  end

  function H:moveTypeBadge(move, x, y)
    self:v4TypePill(move.type, move.typeLabel or move.type, x, y, 46)
  end
end
