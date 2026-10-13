return function(ART, CH, CIRC, DOWN, H, K, PG_TINT, R, RR, UP, WHITE, cg, floor, hex, max, min, mix, translate, ui, wrapLabel)
  local function pgAccent(self, id)
    if cg(self) then return self.tok.acc.M end
    return hex(PG_TINT[id] or "48a858")
  end
  local function lcdColors(self)
    local tok = self.tok
    if tok.lcd then return tok.lcdFrame, tok.lcd, tok.lcdOn, tok.lcdGhost end
    local bg = self.dark and hex("0b1620") or hex("12212e")
    local on = tok.acc.Hi or tok.acc.L
    return self.colors.outline, bg, on, mix(bg, on, 0.14)
  end
  local function lcdPanel(self, x, y, w, h)
    local frame, bg = lcdColors(self)
    if cg(self) then
      CH(x, y, w, h, 4, frame); CH(x + 1, y + 1, w - 2, h - 2, 3, bg)
    else
      RR(x, y, w, h, 4, frame); RR(x + 1, y + 1, w - 2, h - 2, 3, bg)
    end
    R(x + 3, y + 2, w - 6, 1, { 1, 1, 1, 0.07 })
  end
  -- big seven-segment readout, scaled from the header clock's digits
  local function bigLcd(self, value, cx, y, scale, colon)
    local _, _, on, ghost = lcdColors(self)
    local G = ui.graphics
    local w = K.lcdWidth(value) * scale
    G.push(); G.translate(cx - floor(w / 2), y); G.scale(scale, scale)
    K.lcd(value, 0, 0, on, ghost, colon)
    G.pop()
    return w
  end
  local pgIconBounds = {}
  local function pgIcon(self, icon, x, y, w, h)
    local bounds = pgIconBounds[icon]
    if not bounds then
      local spec = K.iconArt[icon]
      if not spec then return end
      local left, top, right, bottom = 24, 24, -1, -1
      for j, row in ipairs(spec.rows) do
        for i = 1, #row do
          if row:sub(i, i) ~= "." then
            left, top, right, bottom = min(left, i - 1), min(top, j - 1), max(right, i - 1), max(bottom, j - 1)
          end
        end
      end
      bounds = { left, top, right - left + 1, bottom - top + 1 }
      pgIconBounds[icon] = bounds
    end
    self:v4Icon(icon, x + floor((w - bounds[3]) / 2) - bounds[1], y + floor((h - bounds[4]) / 2) - bounds[2])
  end
  local function seatIcon(self, icon, x, y, d, accent, lit)
    local c = self.colors
    CIRC(x, y, d, c.outline)
    CIRC(x + 1, y + 1, d - 2, lit and mix(WHITE, accent, 0.18) or mix(c.surface, accent, self.dark and 0.3 or 0.16))
    K.CIRCrows(x + 1, y + 1, d - 2, floor((d - 2) / 2), d - 2,
      lit and mix(WHITE, accent, 0.3) or mix(c.surface, accent, self.dark and 0.42 or 0.26))
    pgIcon(self, icon, x, y, d, d)
  end
  local function litText(self, lit, value, x, y, ink, w, align)
    if lit then self:withoutShadow(self.partyInfo, self, value, x, y, WHITE, w, align)
    else self:partyInfo(value, x, y, ink, w, align) end
  end
  local function arrowKey(self, x, y, w, h, art, enabled)
    local pressed = self:beginPress(x, y, w, h, enabled ~= false)
    self:v4Key(x, y, w, h)
    ART(art, x + floor((w - 11) / 2), y + floor((h - 6) / 2) - 1, { ["#"] = self.tok.acc.M })
    self:endPress(pressed)
  end

  -- GSC splits the day in three: MORN 4-10, DAY 10-18, NITE 18-4. A 24h
  -- LCD track shows the bands with the current one lit and a marker on now.
  local PERIODS = { { "NITE", 0, 4 }, { "MORN", 4, 10 }, { "DAY", 10, 18 }, { "NITE", 18, 24 } }
  local MARK = { "#####", ".###.", "..#.." }
  function H:pokegearDayTrack(clock, x, y, w, h)
    lcdPanel(self, x, y, w, h)
    local _, bg, on, ghost = lcdColors(self)
    local hour = (clock.hour or 0) + (clock.minute or 0) / 60
    local current
    for _, band in ipairs(PERIODS) do
      if hour >= band[2] and hour < band[3] then current = band[1] end
    end
    local tx, tw, ty = x + 10, w - 20, y + 10
    local function at(t) return tx + floor(tw * t / 24 + 0.5) end
    for _, band in ipairs(PERIODS) do
      local lit = band[1] == current
      local bx0, bx1 = at(band[2]), at(band[3])
      R(bx0, ty, bx1 - bx0 - (band[3] < 24 and 1 or 0), 4, lit and on or mix(bg, on, 0.3))
    end
    local mx = at(hour)
    ART(MARK, mx - 2, ty - 5, { ["#"] = on })
    self:withoutShadow(function()
      for i = 2, 4 do
        local band = PERIODS[i]
        local lit = band[1] == current
        local cx = floor((at(band[2]) + at(band[3])) / 2)
        local label = translate(band[1])
        local lw = self:partyInfoWidth(label)
        local gx = cx - floor((lw + 11) / 2)
        K.periodIcon(band[1], gx, ty + 10, lit and on or ghost)
        self:partyInfo(label, gx + 11, ty + 7, lit and on or mix(bg, on, 0.45))
      end
    end)
  end

  function H:pokegearScreen(m, Page)
    local c = self.colors
    local G = ui.graphics
    if m.mode == "strip" then
      local enter = self:v4Enter("pokegear", "strip:" .. #m.cards, 0.24)
      for i, r in ipairs(Page.tiles(#m.cards)) do
        local card = m.cards[i]
        local _, dy = self:v4Stagger(enter, i, 0.07, 10, #m.cards)
        if dy ~= 0 then G.push(); G.translate(0, dy) end
        local x, y, w, h = r[1], r[2], r[3], r[4]
        local accent = pgAccent(self, card.id)
        local lit = card.index == m.cardIndex
        local pressed = self:beginPress(x, y, w, h, true)
        local off = 0
        if lit then off = self:v4Button(x, y, w, h, K.rampOf(accent), { radius = 6, lip = 3, chamfer = 5 })
        else self:v4Window(x, y, w, h, { radius = 5 }) end
        -- icon and name sit together in the middle, whatever the tile height
        local d = h >= 100 and 46 or 34
        local top = y + floor((h - (d + 16)) / 2) - 1
        seatIcon(self, card.icon, x + floor((w - d) / 2), top + off, d, accent, lit)
        litText(self, lit, self:fitPartyInfo(card.label, w - 8), x + 4, top + d + 3 + off, c.ink, w - 8, "center")
        if self.nativeFocus and lit then self:focusFrame(x, y, w, h) end
        self:endPress(pressed)
        if dy ~= 0 then G.pop() end
      end
      -- the device's clock, always at hand under the cards
      local clock = m.clock
      if clock then
        lcdPanel(self, 7, 172, 226, 38)
        local _, _, on = lcdColors(self)
        local colon = floor(self:clock()) % 2 == 0
        self:wantAmbient(1)
        local time = string.format("%d:%02d", clock.h12, clock.minute)
        bigLcd(self, time, 120, 182, 2, colon)
        self:withoutShadow(function()
          self:partyInfo(clock.day, 16, 185, on, 70)
          self:partyInfo(clock.pm and "PM" or "AM", 196, 185, on, 30)
        end)
      end
      return
    end

    -- tab rail: switch cards in place
    local current = m.card
    for i, r in ipairs(Page.tabs(#m.cards)) do
      local card = m.cards[i]
      local x, y, w, h = r[1], r[2], r[3], r[4]
      local accent = pgAccent(self, card.id)
      local lit = card.id == current
      local pressed = self:beginPress(x, y, w, h, not lit and not m.busy)
      local off = 0
      if lit then off = self:v4Button(x, y, w, h, K.rampOf(accent), { radius = 5, lip = 3, chamfer = 4 })
      else self:v4Window(x, y, w, h, { radius = 4, fill = m.busy and c.bandLight or nil }) end
      local faceH = h - (lit and 3 or 0)
      if w >= 100 then
        pgIcon(self, card.icon, x + 6, y + off, 28, faceH)
        litText(self, lit, self:fitPartyInfo(card.label, w - 42), x + 36, y + 6 + off, c.ink, w - 42)
      else
        pgIcon(self, card.icon, x, y + off, w, faceH)
      end
      self:endPress(pressed)
    end

    local accent = pgAccent(self, current)
    local enter = self:v4Enter("pokegear_card", tostring(current), 0.18)
    local _, dy = self:v4Stagger(enter, 1, 0, 8, 1)
    if dy ~= 0 then G.push(); G.translate(0, dy) end
    if m.clock then
      local clock = m.clock
      lcdPanel(self, 7, 62, 226, 104)
      local _, _, on = lcdColors(self)
      self:withoutShadow(function() self:partyInfo(clock.day, 7, 72, on, 226, "center") end)
      local colon = floor(self:clock()) % 2 == 0
      self:wantAmbient(1)
      bigLcd(self, string.format("%d:%02d", clock.h12, clock.minute), 120, 94, 5, colon)
      self:withoutShadow(function() self:partyInfo(clock.pm and "PM" or "AM", 7, 146, on, 226, "center") end)
      self:pokegearDayTrack(clock, 7, 172, 226, 38)
    elseif m.phone then
      local p = m.phone
      if p.call then
        self:v4MessageWindow(7, 62, 226, 104)
        seatIcon(self, "pg_phone", 104, 70, 32, accent, true)
        local lines = wrapLabel(self, p.call.text, 200, 4)
        for i, line in ipairs(lines) do self:label(line, 20, 106 + (i - 1) * 13, c.ink, 200, "center") end
        local pressed = self:beginPress(64, 172, 112, 32, true)
        local off = self:v4Button(64, 172, 112, 32, K.rampOf(hex("e05040")), { radius = 6, lip = 3, chamfer = 5 })
        self:withoutShadow(self.partyInfoCentered, self, translate("END"), 64, 172 + off, 112, 28, WHITE)
        self:endPress(pressed)
      else
        local page = m.phonePage or 1
        for i = 1, Page.PHONE_PAGE do
          local row = p.rows[(page - 1) * Page.PHONE_PAGE + i]
          if row then
            local x, y, w, h = Page.phoneRow(i)
            local lit = row.selected
            local pressed = self:beginPress(x, y, w, h, not p.submenu)
            local off = 0
            if lit then off = self:v4Button(x, y, w, h, K.rampOf(accent), { radius = 5, lip = 3, chamfer = 4 })
            else self:v4Window(x, y, w, h, { radius = 4 }) end
            pgIcon(self, "pg_phone", x + 2, y + off, 28, h - (lit and 3 or 0))
            local nameW = row.class and 104 or 186
            litText(self, lit, self:fitPartyInfo(row.name, nameW), x + 32, y + 6 + off, c.ink, nameW)
            if row.class then
              local ink = lit and WHITE or c.mutedInk
              self:withoutShadow(self.partyInfo, self, self:fitPartyInfo(row.class, 84), x + 138, y + 6 + off, ink, 84, "right")
            end
            self:endPress(pressed)
          end
        end
        if #p.rows == 0 then
          self:v4Window(7, 62, 226, 40, { radius = 4 })
          self:partyInfo("----------", 7, 76, c.mutedInk, 226, "center")
        end
        if (m.phonePages or 1) > 1 and not p.submenu then
          self:pageChevron(22, 193, false, true)
          self:partyInfoCentered(page .. "/" .. m.phonePages, 30, 186, 64, 14, c.ink)
          self:pageChevron(102, 193, true, true)
        end
        if not p.signal then
          self:v4Pill("NO SIGNAL", 233, 186, hex("e05040"), { right = true })
        end
        if p.submenu then
          self:systemOverlay(0.45)
          local n = #p.submenu.entries
          local w = floor((226 - (n - 1) * 6) / n)
          for i, label in ipairs(p.submenu.entries) do
            local x = 7 + (i - 1) * (w + 6)
            local lit = i == p.submenu.cursor
            local by, bh = Page.SUBMENU_Y, Page.SUBMENU_H
            local pressed = self:beginPress(x, by, w, bh, true)
            local off = 0
            if lit then off = self:v4Button(x, by, w, bh, K.rampOf(accent), { radius = 6, lip = 3, chamfer = 5 })
            else self:v4Key(x, by, w, bh) end
            local shown = self:fitPartyInfo(label, w - 8)
            if lit then self:withoutShadow(self.partyInfoCentered, self, shown, x, by + off, w, bh - 4, WHITE)
            else self:partyInfoCentered(shown, x, by, w, bh - 4, c.ink) end
            self:endPress(pressed)
          end
        end
      end
    elseif m.radio then
      local radio = m.radio
      lcdPanel(self, 45, 62, 150, 44)
      local _, _, on, ghost = lcdColors(self)
      local digits = radio.frequency:gsub("%.", "")
      local whole, frac = radio.frequency:match("^(%d+)%.(%d)$")
      if whole then
        -- whole and tenth apart, with the decimal point lit between them
        local ww, fw = K.lcdWidth(whole) * 2, K.lcdWidth(frac) * 2
        local x0 = 120 - floor((ww + 6 + fw) / 2)
        bigLcd(self, whole, x0 + floor(ww / 2), 68, 2, false)
        R(x0 + ww + 1, 84, 2, 2, on)
        bigLcd(self, frac, x0 + ww + 6 + floor(fw / 2), 68, 2, false)
      else
        bigLcd(self, digits, 120, 68, 2, false)
      end
      self:withoutShadow(function()
        self:partyInfo(self:fitPartyInfo(radio.name or "- - -", 140), 50, 89, radio.name and on or ghost, 140, "center")
      end)
      arrowKey(self, 7, 62, 34, 44, DOWN, radio.canTuneDown)
      arrowKey(self, 199, 62, 34, 44, UP, radio.canTuneUp)
      for i, row in ipairs(radio.stations) do
        local x, y, w, h = Page.stationRect(i)
        if y + h <= 214 then
          local lit = row.current
          local pressed = self:beginPress(x, y, w, h, true)
          local off = 0
          if lit then off = self:v4Button(x, y, w, h, K.rampOf(accent), { radius = 4, lip = 2, chamfer = 3 })
          else self:v4Window(x, y, w, h, { radius = 3 }) end
          -- the show's name owns the tile; the frequency (already on the dial
          -- above) rides along only when the whole name still fits
          local ink = lit and WHITE or c.mutedInk
          local nameW = self:partyInfoWidth(row.name)
          local freqW = self:partyInfoWidth(row.frequency)
          if nameW + freqW + 8 <= w - 10 then
            litText(self, lit, row.name, x + 5, y + 4 + off, c.ink, w - 10)
            self:withoutShadow(self.partyInfo, self, row.frequency, x + w - 5 - freqW, y + 4 + off, ink)
          else
            litText(self, lit, self:fitPartyInfo(row.name, w - 10), x + 5, y + 4 + off, c.ink, w - 10)
          end
          self:endPress(pressed)
        end
      end
    elseif m.map then
      local map = m.map
      self:v4Window(7, 62, 226, 82, { radius = 5 })
      self:v4Pill(map.region, 15, 70, accent)
      if map.here then self:v4Pill("HERE", 225, 70, hex("e05040"), { right = true }) end
      self:partyName(self:fitPartyInfo(map.landmark, 200), 20, 96, c.ink, 200)
      if not map.here and map.player ~= "" then
        self:v4Icon("map", 18, 116)
        self:partyInfo(self:fitPartyInfo(map.player, 170), 46, 122, c.mutedInk, 170)
      end
      local function mapKey(x, art, label, enabled)
        local pressed = self:beginPress(x, 150, 110, 40, enabled ~= false)
        self:v4Key(x, 150, 110, 40)
        local tw = self:partyInfoWidth(label)
        local gx = x + floor((110 - (11 + 6 + tw)) / 2)
        ART(art, gx, 166, { ["#"] = accent })
        self:partyInfo(label, gx + 17, 160, c.ink)
        self:endPress(pressed)
      end
      mapKey(7, DOWN, translate("PREV"))
      mapKey(123, UP, translate("NEXT"))
    end
    if dy ~= 0 then G.pop() end
  end

end
