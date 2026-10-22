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

  function H:battleFightAction(mon, drawPortrait, selected, offsetX, offsetY, enabled)
    local G, colors = ui.graphics, self.colors
    offsetX, offsetY = offsetX or 0, offsetY or 0
    local pressed = self:beginPress(22 + offsetX, 32 + offsetY, 196, 122, enabled)
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
  local function messageKey(value)
    return tostring(value or ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
  end
  local function messageText(value)
    return value ~= "" and value ~= "…" and not value:match("^%.+$")
  end
  local function sameMessageProgress(a, b)
    return a:sub(1, #b) == b or b:sub(1, #a) == a
  end
  function H:v4AdvanceArrow(x, y)
    local bob = floor(self:clock() / 0.4) % 2
    self:wantAmbient(0.4)
    local c = cg(self) and self.tok.acc.M or self.colors.red
    ART({ "ooooooooo", ".o#####o.", "..o###o..", "...o#o...", "....o...." }, x, y + bob,
      { o = self.colors.outline, ["#"] = c })
  end

  -- The window hugs its text and sits on the embossed ball's centre band, so
  -- the backdrop ball frames it above and below like the HGSS touch screen.
  function H:battleMessage(lines, canAdvance, playerTeam, enemyTeam, title, now)
    local colors = self.colors
    lines = lines or {}
    if #lines == 0 then lines = { "..." } end
    self:battleBackdrop()
    self:battleTeamStrip(playerTeam, enemyTeam)
    -- The whole area stays one tap target; only the window hugs its text.
    local pressed = self:beginPress(MESSAGE_X, 38, MESSAGE_WIDTH, 165, canAdvance)
    local lineHeight = 18
    local blockHeight = 11 + (#lines - 1) * lineHeight
    local titleHeight = title and 23 or 0
    local h = min(165, max(60, 18 + titleHeight + blockHeight + 26))
    h = h + h % 2
    local wy = min(203 - h, 121 - h / 2)
    -- each new message pops up a few pixels, like a DS text window opening
    local enter = self:v4Enter("battle_message", table.concat(lines, "\n") .. tostring(title), 0.2)
    local G = ui.graphics
    -- Battle log: the last two lines the game said stay readable above the
    -- window, faded, so a message that flew by can still be read.
    local log = self.v4BattleLog or { entries = {} }
    self.v4BattleLog = log
    local key = messageKey(table.concat(lines, " "))
    if messageText(key) then
      local previous = messageKey(log.last)
      if messageText(previous) and not sameMessageProgress(previous, key) then
        table.insert(log.entries, 1, previous)
      end
      -- The native printer reveals lines progressively. Keep the fullest
      -- version across partial redraws and blank capture-animation frames.
      if #key >= #previous or not sameMessageProgress(previous, key) then log.last = key end
    end
    local current = messageKey(log.last)
    for index = #log.entries, 1, -1 do
      local entry = messageKey(log.entries[index])
      if not messageText(entry) or messageText(current) and sameMessageProgress(entry, current) then
        table.remove(log.entries, index)
      end
    end
    while #log.entries > 2 do table.remove(log.entries) end
    local slot = wy - 6
    for index, entry in ipairs(log.entries) do
      local top = slot - index * 17
      if top >= 34 then
        local fade = index == 1 and 0.55 or 0.3
        local fill = mix(colors.bandLight, colors.surface, 0.4)
        if cg(self) then CH(MESSAGE_X + 8, top, MESSAGE_WIDTH - 16, 15, 3, mix(fill, colors.outline, 0.25)); CH(MESSAGE_X + 9, top + 1, MESSAGE_WIDTH - 18, 13, 2, fill)
        else RR(MESSAGE_X + 8, top, MESSAGE_WIDTH - 16, 15, 4, mix(fill, colors.outline, 0.25)); RR(MESSAGE_X + 9, top + 1, MESSAGE_WIDTH - 18, 13, 3, fill) end
        local ink = mix(fill, colors.ink, 1 - fade * 0.6)
        self:v4Caps(function()
          self:withoutShadow(self.partyInfo, self, self:fitPartyInfo(entry, MESSAGE_WIDTH - 32),
            MESSAGE_X + 16, top + 2, ink, MESSAGE_WIDTH - 32, "center")
        end)
      end
    end
    local lift = enter < 1 and floor((1 - K.easeBack(enter)) * 10 + 0.5) or 0
    if lift ~= 0 then G.push(); G.translate(0, lift) end
    self:v4MessageWindow(MESSAGE_X, wy, MESSAGE_WIDTH, h)
    local contentTop = wy + 13
    if title then
      local shown = self:fitPartyInfo(title, 190)
      self:partyInfo(shown, 25, contentTop, colors.green, 190, "center")
      R(25, contentTop + 15, 190, 1, colors.band)
      contentTop = contentTop + titleHeight
    end
    local contentHeight = wy + h - 22 - contentTop
    local y = contentTop + floor((contentHeight - blockHeight) / 2)
    for _, line in ipairs(lines) do
      local shown = self:fitLabel(line, 192)
      self:label(shown, 24, y, colors.ink, 192, "center")
      y = y + lineHeight
    end
    if canAdvance then self:v4AdvanceArrow(116, wy + h - 19) end
    if lift ~= 0 then G.pop() end
    self:endPress(pressed)
  end

  ---------------------------------------------------------------------------
  -- Move cards: type-coloured lipped buttons
  ---------------------------------------------------------------------------
  local UP2 = { "..#....#..", ".###..###.", "#####.####", "..#....#.." }
  local DOWN = { "#####", ".###.", "..#.." }
  local CROSS = { "#...#", ".#.#.", "..#..", ".#.#.", "#...#" }
  local STAR = { "...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", ".#...#." }

  -- Battle back affordances: a small key with the return glyph instead of a
  -- bare left arrow, so "back" never reads like the pocket arrows beside it.
  local BACK_GLYPH = { "..o....", ".oo....", "ooooooo", ".oo...o", "..o...o", "......o", "..oooo." }
  function H:v4BackKey(x, y, w, h)
    local pressed = self:beginPress(x, y, w, h)
    local off = 0
    self:v4Key(x, y, w, h)
    ART(BACK_GLYPH, x + floor((w - 7) / 2), y + floor((h - 3 - 7) / 2) + off,
      { o = self.dark and self.tok.acc.L or cg(self) and self.tok.acc.M or self.tok.acc.D })
    self:endPress(pressed)
  end
  local function withBackKey(self, fn, ...)
    local chevron = self.chevron
    self.chevron = function(me, x, y, right)
      if right then return chevron(me, x, y, right) end
      return me:v4BackKey(x - 8, y - 9, 18, 19)
    end
    local ok, err = pcall(fn, self, ...)
    self.chevron = chevron
    if not ok then error(err, 0) end
  end
  local baseTeamStrip, baseBagHeader = H.battleTeamStrip, H.battleBagHeader
  function H:battleTeamStrip(...) return withBackKey(self, baseTeamStrip, ...) end
  function H:battleBagHeader(...) return withBackKey(self, baseBagHeader, ...) end

  -- One matchup language on every battle surface: the red family for super
  -- effective (the type-chart convention of the enemy info pages), blue for
  -- resisted, grey for no effect and a quiet neutral otherwise.
  function H:matchupStyle(effectiveness)
    if effectiveness == nil then return nil end
    if effectiveness == 0 then
      return { bg = hex("c8ccd0"), fg = hex("3a3a40"), pill = hex("808890"), icon = CROSS }
    elseif effectiveness > 10 then
      return { bg = hex("f8d8d0"), fg = hex("a82818"), icon = UP2, strong = true,
        pill = effectiveness >= 40 and hex("c02818") or hex("e05040") }
    elseif effectiveness < 10 then
      return { bg = hex("d4e2f4"), fg = hex("204a90"), icon = DOWN, weak = true,
        pill = effectiveness <= 2.5 and hex("2850a0") or hex("3878d0") }
    end
    return { bg = hex("e8eef0"), fg = hex("2a3640"), pill = hex("8890a0") }
  end

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
    -- labels follow the summary rows: dark on light types, pale on dark ones,
    -- and power/accuracy sit in a recessed well that reads on every colour
    local lum = a.L[1] * 0.3 + a.L[2] * 0.59 + a.L[3] * 0.11
    local label = lum > 0.45 and mix(a.D, { 0, 0, 0, 1 }, 0.15) or mix(a.Hi, WHITE, 0.2)
    local wellLabel = mix(a.Hi, WHITE, 0.2)
    RR(x + 7, y + 20, 44, 10, 3, mix(a.D, { 0, 0, 0, 1 }, 0.25))
    RR(x + 8, y + 21, 42, 8, 2, a.D)
    local typeText = self:fitPartyInfo(move.typeLabel or move.type or "---", 40)
    self:partyInfo(typeText, x + 7 + floor((44 - self:partyInfoWidth(typeText)) / 2) + 1, y + 18, WHITE)
    self:withoutShadow(self.partyInfo, self, move.ppLabel or translate("PP"), x + 55, y + 19, label)
    local ppLow = move.pp and move.maxPp and move.maxPp > 0 and move.pp / move.maxPp <= 0.25
    self:partyInfo(move.ppText or "--", x + 70, y + 19,
      disabled and colors.redLight or (ppLow and hex("f8e070") or ink), 35, "right")
    RR(x + 5, y + 37, 102, 14, 3, mix(a.D, { 0, 0, 0, 1 }, 0.2))
    RR(x + 6, y + 38, 100, 12, 2, mix(a.D, a.M, 0.25))
    self:withoutShadow(function()
      self:partyInfo(move.powerLabel or translate("PWR"), x + 10, y + 38, wellLabel)
      self:partyInfo(move.accuracyLabel or translate("ACC"), x + 59, y + 38, wellLabel)
    end)
    self:partyInfo(move.powerText or "--", x + 30, y + 38, ink, 22, "right")
    self:partyInfo(move.accuracyText or "--", x + 80, y + 38, ink, 23, "right")
    local cy = y + 56
    if disabled then
      RR(x + 9, cy, 94, 12, 3, colors.outline)
      RR(x + 10, cy + 1, 92, 10, 2, colors.red)
      self:partyInfoCentered(move.disabledLabel or translate("DISABLED"), x + 9, cy, 94, 12, WHITE)
    else
      local effectLabel, effectiveness = self:battleEffectLabel(move)
      local style = self:matchupStyle(effectiveness) or self:matchupStyle(10)
      local icon, bg, fg = style.icon, style.bg, style.fg
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

  ---------------------------------------------------------------------------
  -- Full Gear message, battle bag rows, PC quantity
  ---------------------------------------------------------------------------
  function H:battleFullMessage(lines, canAdvance, title, now)
    local c = self.colors
    local pressed = self:beginPress(6, 117, 228, 93, canAdvance)
    self:v4MessageWindow(6, 117, 228, 93)
    if title then self:partyInfo(self:fitPartyInfo(title, 200), 16, 124, c.green, 208, "center") end
    lines = #lines > 0 and lines or { "..." }
    local top, height = title and 138 or 125, title and 65 or 78
    if canAdvance then height = height - 14 end
    local step = title and 9 or 10
    local y = top + floor((height - (8 + (#lines - 1) * step)) / 2)
    self:v4Caps(function()
      for _, line in ipairs(lines) do
        self:partyInfo(self:fitPartyInfo(line, 200), 16, y, c.ink, 208, "center")
        y = y + step
      end
    end)
    if canAdvance then self:v4AdvanceArrow(116, 194) end
    self:endPress(pressed)
  end

  function H:battleBagRow(item, index, y, selected, offsetX)
    local G, colors = ui.graphics, self.colors
    local disabled = item.disabled
    local ink = disabled and colors.disabledInk or colors.ink
    local tint = disabled and colors.silverDark or self:itemAccent(item.icon)
    local pressed = self:beginPress(7 + (offsetX or 0), y, 226, 31, not disabled)
    G.push()
    G.translate(offsetX or 0, 0)
    self:v4Window(7, y, 226, 31, { radius = 4,
      fill = selected and not disabled and mix(colors.surface, tint, 0.25) or colors.surface })
    if selected and not disabled then R(8, y + 4, 2, 23, tint) end
    CIRC(12, y + 1, 29, colors.outline)
    CIRC(13, y + 2, 27, mix(colors.surface, tint, self.dark and 0.3 or 0.22))
    K.CIRCrows(13, y + 2, 27, 14, 27, mix(colors.surface, tint, self.dark and 0.42 or 0.32))
    self:v4ItemInSeat(item, 26, y + 15, 26, tint)
    local chance = self:battleCatchLabel(item.catchChance)
    local labelY = (chance or disabled) and y + 3 or y + 9
    local right = item.right and tostring(item.right) or ""
    local rightWidth = right ~= "" and min(110, max(12, self:partyInfoWidth(right))) or 0
    local labelWidth = 178 - rightWidth - (rightWidth > 0 and 6 or 0)
    self:partyName(item.label or tostring(index), 44, labelY, ink, labelWidth)
    if right ~= "" then
      self:partyInfo(self:fitPartyInfo(right, rightWidth), 224 - rightWidth, labelY, ink, rightWidth, "right")
    end
    if chance then
      -- catch odds as a gauge
      self:partyInfo(item.catchLabel or translate("CATCH"), 44, y + 17, colors.green, 37)
      local pct = tonumber(tostring(chance):match("(%d+)")) or 0
      local bx, bw = 84, 80
      R(bx, y + 19, bw, 7, colors.outline)
      R(bx + 1, y + 20, bw - 2, 5, self.dark and hex("2a3542") or hex("dfe6e1"))
      local fill = pct >= 60 and colors.hp or pct >= 25 and colors.hpMid or colors.hpLow
      local f = floor((bw - 2) * min(1, pct / 100))
      R(bx + 1, y + 20, f, 5, fill); R(bx + 1, y + 20, f, 2, mix(fill, WHITE, 0.45))
      self:partyInfo(chance, bx + bw + 4, y + 16, colors.ink)
    elseif disabled then
      self:partyInfo(item.disabledLabel or translate("UNUSABLE"), 44, y + 17, colors.disabledInk)
    end
    if selected and not disabled then self:focusFrame(7, y, 226, 31) end
    G.pop()
    self:endPress(pressed)
  end

  function H:pcQuantity(model)
    local colors = self.colors
    self:v4Window(7, 34, 226, 50)
    R(9, 36, 222, 2, colors.amberLight)
    CIRC(15, 42, 34, colors.outline)
    CIRC(16, 43, 32, mix(colors.surface, colors.amberLight, self.dark and 0.3 or 0.25))
    K.CIRCrows(16, 43, 32, 16, 32, mix(colors.surface, colors.amberLight, self.dark and 0.42 or 0.4))
    self:v4ItemInSeat({ icon = model.icon or "item", itemSprite = model.itemSprite, label = model.label }, 32, 59, 30, colors.amberLight)
    self:partyInfoCentered(self:fitPartyInfo(model.label or translate("ITEM"), 161), 64, 44, 161, 16, colors.ink)
    self:partyInfoCentered(model.total ~= nil and "¥" .. model.total or translate("QUANTITY"), 64, 61, 161, 16, colors.green)
    -- counter well
    self:v4MessageWindow(83, 91, 74, 48)
    local qty = tostring(model.qty or 1)
    local font = ui.largeFont
    local G = ui.graphics
    if font and (not font.hasGlyphs or font:hasGlyphs(qty)) then
      local prev = G.getFont(); G.setFont(font); K.setc(colors.ink)
      G.print(qty, 120 - floor(font:getWidth(qty) / 2), 98)
      if prev then G.setFont(prev) end
    else
      self:partyInfoCentered(qty, 83, 91, 74, 48, colors.ink)
    end
    for _, control in ipairs({ { x = 7, label = "-", action = "minus" }, { x = 159, label = "+", action = "plus" } }) do
      local interactive = self:pcQuantityEnabled(model, control.action)
      local pressed = self:beginPress(control.x, 91, 74, 48, interactive)
      self:v4Key(control.x, 91, 74, 48, not interactive and
        { cap = colors.bandLight, lip = colors.band, hi = colors.bandLight } or nil)
      local ink = interactive and self.tok.acc.M or colors.disabledInk
      R(control.x + 30, 112, 14, 4, ink)
      if control.action == "plus" then R(control.x + 35, 107, 4, 14, ink) end
      self:endPress(pressed)
    end
    local buttons = {
      { x = 7, label = translate("CONFIRM"), ramp = K.rampOf(cg(self) and hex("1ea5d8") or hex("3ea04c")) },
      { x = 123, label = translate("CANCEL"), ramp = K.rampOf(hex("5a6c88")) },
    }
    for _, action in ipairs(buttons) do
      local pressed = self:beginPress(action.x, 146, 110, 64)
      local off = self:v4Button(action.x, 146, 110, 64, action.ramp, { radius = 7, lip = 5, chamfer = 8 })
      local glyph = action.x == 7 and { "......#", ".....##", "#...##.", "##.##..", ".###...", "..#...." }
        or { "#...#", ".#.#.", "..#..", ".#.#.", "#...#" }
      local G = ui.graphics
      G.push(); G.translate(action.x + 55 - #glyph[1], 158 + off); G.scale(2, 2)
      ART(glyph, 0, 0, { ["#"] = WHITE })
      G.pop()
      self:partyInfoCentered(action.label, action.x, 160 + off, 110, 40, WHITE)
      self:endPress(pressed)
    end
  end

  -- Party action rows (switch, stats, item...) as lipped buttons with icon seats.
  local baseActionRow = base.actionRow
  function H:actionRow(x, y, w, h, label, kind, offset, selected, subText, enabled)
    local colors = self.colors
    local accentName = (kind == "swap" or kind == "switch") and "amber" or kind == "release" and "red"
      or kind == "cancel" and "slate" or (kind == "item" or kind == "mail" or kind == "item_none") and "green" or "blue"
    local ramps = { amber = hex("e09a20"), red = hex("e04838"), slate = hex("5a6c88"), blue = hex("3878d0"),
      green = hex("3f9a58") }
    local a = K.rampOf(enabled == false and hex("8a909c") or ramps[accentName])
    y = y + (offset or 0)
    local pressed = self:beginPress(x, y, w, h, enabled ~= false)
    self:v4Window(x, y, w, h, { radius = 5, fill = enabled == false and colors.bandLight or nil })
    local d = min(h - 8, 30)
    local sx, sy = x + 9, y + floor((h - d) / 2)
    CIRC(sx, sy, d, colors.outline)
    CIRC(sx + 1, sy + 1, d - 2, a.L)
    K.CIRCrows(sx + 1, sy + 1, d - 2, floor(d / 2), d, a.M)
    local cx, cy = sx + floor(d / 2), sy + floor(d / 2)
    local GLY = {
      swap = { "...#...", "..###..", ".#####.", "...#...", "...#...", ".#####.", "..###..", "...#..." },
      cancel = { "#...#", ".#.#.", "..#..", ".#.#.", "#...#" },
      release = { ".##.##.", "#######", "#######", ".#####.", "..###..", "...#..." },
      stats = { ".....##", ".....##", "..##.##", "..##.##", "##.#.##", "##.#.##", "#######" },
      item = { "..###..", ".#...#.", "#######", "#.....#", "#.###.#", "#.....#", "#######" },
      mail = { "#######", "##...##", "#.#.#.#", "#..#..#", "#.....#", "#######" },
    }
    local g = GLY[(kind == "switch" and "swap") or (kind == "item_none" and "item") or kind] or GLY.stats
    if kind == "switch" then
      g = { "...#.....", "..##.....", ".########", "..##.....", ".....##..", "########.", ".....##..", ".....#..." }
    end
    local G = ui.graphics
    local sc = d >= 26 and 2 or 1
    G.push(); G.translate(cx - floor(#g[1] * sc / 2), cy - floor(#g * sc / 2)); G.scale(sc, sc)
    ART(g, 0, 0, { ["#"] = WHITE })
    G.pop()
    local sub = subText or ({ swap = "CHANGE ORDER", switch = "SEND INTO BATTLE", stats = "VIEW SUMMARY",
      release = "SAY GOODBYE", cancel = "GO BACK" })[kind or "stats"]
    local tx, tw = sx + d + 8, w - (sx + d + 8 - x) - 24
    if sub and h >= 30 then
      self:partyName(self:fitPartyInfo(label, tw), tx, y + floor(h / 2) - 12, colors.ink, tw)
      self:partyInfo(self:fitPartyInfo(subText and sub or translate(sub), tw), tx, y + floor(h / 2) + 1,
        subText and enabled ~= false and kind ~= "item_none" and (self.dark and a.L or a.D) or colors.mutedInk)
    else
      self:partyInfo(self:fitPartyInfo(label, tw), tx, y + floor((h - 9) / 2) - 1, colors.ink)
    end
    self:detailChevron(x + w - 25, y + floor((h - 8) / 2), colors.mutedInk, true)
    if selected then self:focusFrame(x, y, w, h) end
    self:endPress(pressed)
  end

  ---------------------------------------------------------------------------
  -- Safari actions: same panels, proper pixel props.
  ---------------------------------------------------------------------------
  local SAFARI = {
    bait = { art = { "....gg....", "...g.g....", ".oooooooo.", "o########o", "o#yy##yy#o", "o##yyyy##o",
      "o#yy##yy#o", "o########o", ".oooooooo." }, pal = { ["#"] = "d89848", y = "f8d878", g = "58b848" } },
    rock = { art = { "...oooo...", "..o####o..", ".o##ww##o.", "o###w####o", "o########o", "o#######do",
      ".o#####ddo", "..ooooooo." }, pal = { ["#"] = "a8a8a0", w = "e8e8e0", d = "707068" } },
    pokeblock = { art = { ".oooooooo.", "o#ww#####o", "o#w######o", "o######yyo", "o######yyo", "o##yy###do",
      "o##yy##ddo", ".oooooooo." }, pal = { ["#"] = "e86070", w = "f8b0b8", y = "f8d040", d = "a83848" } },
  }
  local safariBase = H.battleSafariAction
  function H:battleSafariAction(action, index, selected)
    local spec = SAFARI[action.kind]
    if not spec then return safariBase(self, action, index, selected) end
    local colors = self.colors
    local column, row = (index - 1) % 2, floor((index - 1) / 2)
    local x, y = 6 + column * 116, 33 + row * 91
    if ui.safariPage then x, y = ui.safariPage.rect(index) end
    local pressed = self:beginPress(x, y, 112, 86, action.enabled ~= false)
    self:battleActionPanel(x, y, 112, 86, action.color, selected)
    local pal = { o = colors.outline }
    for k, v in pairs(spec.pal) do pal[k] = hex(v) end
    local w, h = #spec.art[1], #spec.art
    local total = 12 + 6 + h * 2 + (action.detail and 16 or 0)
    local top = y + floor((86 - total) / 2)
    self:partyInfoCentered(self:fitPartyInfo(translate(action.label), 96), x + 8, top, 96, 12, WHITE)
    local G = ui.graphics
    G.push(); G.translate(x + 56 - w, top + 18); G.scale(2, 2)
    ART(spec.art, 0, 0, pal)
    G.pop()
    if action.detail then
      self:partyInfoCentered(action.detail, x + 8, top + 18 + h * 2 + 4, 96, 12, WHITE)
    end
    self:endPress(pressed)
  end

  ---------------------------------------------------------------------------
  -- Full Gear battle: status cards, move keys, Safari keys; double-battle
  -- opponent picker reuses the status card.
  ---------------------------------------------------------------------------
  function H:battleStatusCard(mon, x, y, w, player, drawPortrait)
    if not mon then return end
    local colors = self.colors
    local accent = player and hex("3ea04c") or hex("d84838")
    if cg(self) then accent = player and hex("1ea5d8") or hex("e05a48") end
    local fainted = mon.statusId == "FNT" or (mon.hp or 0) <= 0
    self:v4Window(x, y, w, 78)
    -- header plate
    local a = K.rampOf(accent)
    if cg(self) then CH(x + 2, y + 2, w - 4, 16, 3, a.M); CHrows(x + 2, y + 2, w - 4, 16, 3, 0, 7, a.L)
    else RR(x + 2, y + 2, w - 4, 16, 3, a.D); RR(x + 2, y + 2, w - 4, 14, 3, a.M)
      RRrows(x + 2, y + 2, w - 4, 14, 3, 0, 6, a.L); R(x + 5, y + 2, w - 10, 1, a.Hi) end
    local level = mon.levelText or "L--"
    local levelWidth = self:partyInfoWidth(level)
    local nameWidth = w - levelWidth - 19 - (mon.caught and 10 or 0)
    self:partyName(mon.name or translate("POKEMON"), x + 7, y + 4, WHITE, nameWidth)
    if mon.caught then self:v4MiniBall(x + w - levelWidth - 17, y + 6, "ok") end
    self:partyInfo(level, x + w - levelWidth - 7, y + 4, WHITE)
    self:v4Seat(x + 4, y + 21, 52, fainted)
    drawPortrait(mon, x + 5, y + 22, 50, fainted)
    local infoX, infoW = x + 62, w - 69
    if mon.statusId then self:v4StatusPill(mon.statusId, infoX, y + 24) end
    if not player and not mon.statusId and mon.statusLabel and mon.statusLabel ~= "" then
      self:partyInfo(mon.statusLabel, infoX + 26, y + 22, colors.mutedInk, max(0, infoW - 26), "right")
    end
    self:v4HpBar(infoX, y + 44, infoW, mon.hp, mon.maxHp)
    if player then self:partyInfo(mon.hpText or "--/--", infoX, y + 56, colors.ink, infoW, "right") end
    if player and mon.expProgress then self:expBar(infoX, y + 69, infoW, mon.expProgress) end
  end

  -- Double-battle card (112×37): the singles card in miniature. Seat and
  -- portrait, name and level, the tagged HP bar with EXP welded under it on
  -- your side, then status and HP numbers. The active battler is lit.
  function H:battleCompactStatus(mon, x, y, drawPortrait)
    local colors, player = self.colors, mon.side == "player"
    local accent = player and hex("3ea04c") or hex("d84838")
    if cg(self) then accent = player and hex("1ea5d8") or hex("e05a48") end
    local lit = mon.active and not mon.absent
    self:v4Window(x, y, 112, 37, { fill = mon.absent and colors.bandLight
      or lit and mix(colors.surface, accent, self.dark and 0.22 or 0.14) or nil,
      edge = lit and K.rampOf(accent).D or nil })
    if mon.absent then
      self:partyInfo("--", x, y + 13, colors.disabledInk, 112, "center")
      return
    end
    R(x + 1, y + 4, 2, 29, lit and accent or mix(colors.surface, accent, 0.55))
    local fainted = mon.statusId == "FNT" or (mon.hp or 0) <= 0
    self:v4Seat(x + 5, y + 6, 26, fainted)
    drawPortrait(mon, x + 6, y + 7, 24, fainted)
    local level = mon.levelText or "L--"
    local lw = self:partyInfoWidth(level)
    self:partyInfo(self:fitPartyInfo(mon.name or translate("POKEMON"), 72 - lw), x + 35, y + 1, colors.ink, 72 - lw)
    self:partyInfo(level, x + 107 - lw, y + 1, player and colors.green or colors.mutedInk)
    self:v4HpBar(x + 35, y + 14, 72, mon.hp, mon.maxHp)
    -- EXP shares the HP bar's bottom outline, under the bar (not the tag)
    local tag = cg(self) and 12 or 14
    if player and mon.expProgress then self:expBar(x + 35 + tag, y + 20, 72 - tag, mon.expProgress) end
    if mon.statusId then self:v4StatusPill(mon.statusId, x + 35, y + 27) end
    if player then self:partyInfo(mon.hpText or "--/--", x + 58, y + 24, colors.ink, 49, "right") end
  end

  -- What the picker is opened for: the foe's types beside its status, and
  -- the strongest types against it under the HP bar.
  function H:opponentFacts(mon, x, y)
    local colors = self.colors
    if not mon.type then return end
    local fainted = mon.statusId == "FNT" or (mon.hp or 0) <= 0
    local tx = x + (mon.statusId and 26 or 0)
    local dual = mon.type2 and mon.type2 ~= mon.type
    self:v4TypePill(mon.type, mon.typeLabel, tx, y + 24, 30, fainted)
    if dual then self:v4TypePill(mon.type2, mon.type2Label, tx + 32, y + 24, 30, fainted) end
    local weak = mon.weak or {}
    if #weak == 0 then return end
    local label = translate("WEAK")
    self:partyInfo(label, x, y + 57, colors.mutedInk)
    local px = x + self:partyInfoWidth(label) + 6
    for _, row in ipairs(weak) do
      local style = self:matchupStyle(row.multiplier or 20)
      local ew = self:partyInfoWidth(row.effectLabel or "")
      if px + 28 + ew + 2 > 214 then break end
      self:v4TypePill(row.type, row.typeLabel, px, y + 60, 26, fainted)
      self:partyInfo(row.effectLabel or "", px + 28, y + 57, style.pill)
      px = px + 28 + ew + 7
    end
  end

  function H:enemyInfoOpponents(battlers, drawPortrait)
    for _, mon in ipairs(battlers or {}) do
      if mon.side == "enemy" then
        local y = mon.id == 1 and 40 or 125
        local pressed = self:beginPress(6, y, 228, 78, not mon.absent)
        if mon.absent then
          self:v4Window(6, y, 228, 78, { fill = self.colors.bandLight })
          self:partyInfo("--", 6, y + 33, self.colors.disabledInk, 228, "center")
        else
          self:battleStatusCard(mon, 6, y, 228, false, drawPortrait)
          self:opponentFacts(mon, 68, y)
          ART({ "#..", "##.", "###", "##.", "#.." }, 222, y + 64, { ["#"] = self.colors.mutedInk })
        end
        self:endPress(pressed)
      end
    end
  end

  -- The gear card's matchup chip, condensed to the gap between the type pill
  -- and PP. Hidden when the matchup is unknown (assist off, status moves).
  function H:fullMoveMatchup(move, x, y, a)
    local label, effectiveness = self:battleEffectLabel(move)
    if effectiveness == nil then return end
    local strong, weak = effectiveness > 10, effectiveness < 10
    local style = self:matchupStyle(effectiveness)
    local plain = not strong and not weak and effectiveness ~= 0
    local bg, fg = plain and a.D or style.bg, plain and WHITE or style.fg
    local cw = max(18, self:partyInfoWidth(label) + 8)
    if not plain then RR(x, y + 1, cw, 11, 2, { 0, 0, 0, 0.3 }) end
    RR(x, y, cw, 11, 2, bg)
    if not plain then
      self:withoutShadow(function() self:partyInfo(label, x, y - 2, fg, cw, "center") end)
    else
      self:partyInfo(label, x, y - 2, fg, cw, "center")
    end
  end

  -- Target picker badge: side on top, the matchup as the shared chip below.
  function H:battleTargetLabels(entry, x, y, w, h)
    local colors = self.colors
    local side = self:fitPartyInfo(translate(entry.right), w - 8)
    if entry.effectiveness == nil then
      self:partyInfoCentered(side, x, y, w, h, colors.ink)
      return
    end
    local label, effectiveness = self:battleEffectLabel(entry)
    local style = self:matchupStyle(effectiveness) or self:matchupStyle(10)
    local top = y + floor((h - 23) / 2)
    self:partyInfoCentered(side, x, top, w, 9, colors.ink)
    local cw = max(22, self:partyInfoWidth(label) + 10)
    local cx = x + floor((w - cw) / 2)
    RR(cx, top + 12, cw, 11, 2, { 0, 0, 0, 0.25 })
    RR(cx, top + 11, cw, 11, 2, style.pill)
    self:partyInfo(label, cx, top + 9, WHITE, cw, "center")
  end

  function H:battleFullMoves(mon)
    local c = self.colors
    for slot, rect in ipairs(self.fullBattleActions) do
      local move = mon.moves[slot]
      if move and move.available then
        local x, y, w, h = rect.x, rect.y, rect.w, rect.h
        local pressed = self:beginPress(x, y, w, h, not move.disabled)
        local tone = move.disabled and c.silverDark or self:typeColor(move.type)
        local a = K.rampOf(tone)
        self:v4Button(x, y, w, h, a, { radius = 5, lip = 4, chamfer = 5 })
        local ink = move.disabled and c.disabledInk or WHITE
        local stab = mon.typeHints ~= false and not move.disabled and self:moveHasStab(mon, move)
        local starX = x + w - (mon.details and 26 or 15)
        self:partyName(move.name, x + 7, y + 4, ink, stab and starX - x - 10 or w - 29)
        if stab then ART(STAR, starX, y + 6, { ["#"] = hex("f8e070") }) end
        if move.disabled then
          self:partyInfo(move.disabledLabel or "", x + 7, y + 22, WHITE)
        else
          RR(x + 6, y + 23, 44, 11, 2, a.D)
          self:partyInfo(self:fitPartyInfo(move.typeLabel or move.type or "", 40), x + 6, y + 21, WHITE, 44, "center")
          self:fullMoveMatchup(move, x + 52, y + 23, a)
        end
        self:partyInfo(move.ppText or "", x + w - 49, y + 21, ink, 42, "right")
        if self.nativeFocus and mon.moveIndex == slot and not move.disabled then self:focusFrame(x, y, w, h) end
        self:endPress(pressed)
        if mon.details then
          local infoPressed = self:beginPress(x + w - 20, y, 20, 22)
          ART({ "#..", "##.", "###", "##.", "#.." }, x + w - 12, y + 7, { ["#"] = WHITE })
          self:endPress(infoPressed)
        end
      end
    end
  end

  function H:battleFullSafari(model)
    local c = self.colors
    for index, action in ipairs(model.actions) do
      local rect = self.fullBattleActions[index]
      local pressed = self:beginPress(rect.x, rect.y, rect.w, rect.h, action.enabled)
      self:battleActionPanel(rect.x, rect.y, rect.w, rect.h, action.color,
        self.nativeFocus and model.index == index)
      local spec = SAFARI[action.kind]
      local label = translate(action.label) .. (action.detail and " " .. action.detail or "")
      local G = ui.graphics
      -- round seat with a 2x prop, like the Safari keys on the full screen
      local d = min(28, rect.h - 8)
      local sx, sy = rect.x + 7, rect.y + floor((rect.h - 4 - d) / 2)
      CIRC(sx, sy, d, c.outline)
      CIRC(sx + 1, sy + 1, d - 2, WHITE)
      K.CIRCrows(sx + 1, sy + 1, d - 2, floor(d / 2), d - 2, hex("e8eef0"))
      local cx, cy = sx + floor(d / 2), sy + floor(d / 2)
      if spec then
        local pal = { o = c.outline }
        for k, v in pairs(spec.pal) do pal[k] = hex(v) end
        G.push(); G.translate(cx - #spec.art[1], cy - #spec.art); G.scale(2, 2)
        ART(spec.art, 0, 0, pal)
        G.pop()
      elseif action.kind == "ball" then
        G.push(); G.translate(cx, cy); G.scale(2, 2)
        self:battleTeamBall(0, 0, true)
        G.pop()
      elseif self.battleRunnerIcon then
        CIRC(sx + 1, sy + 1, d - 2, hex("3a8a4a"))
        G.push(); G.translate(cx, cy); G.scale(0.5, 0.5)
        self:battleRunnerIcon(0, 0)
        G.pop()
      end
      local lx = sx + d + 2
      self:partyInfoCentered(self:fitPartyInfo(label, rect.w - 12 - (lx - rect.x)),
        lx, rect.y, rect.w - (lx - rect.x), rect.h - 4, action.enabled and WHITE or c.disabledInk)
      self:endPress(pressed)
    end
  end
end
