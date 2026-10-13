return function(ART, CARD_COLORS, CIRC, CIRCrows, H, K, P, R, RR, RRrows, WHITE, base, floor, hex, max, min, mix, translate, ui)
  local function cardTier(model)
    if model.stars == nil then return 0, CARD_COLORS.plain[1] end
    local stars = max(0, min(4, model.stars))
    local set = CARD_COLORS[model.cardFamily] or CARD_COLORS.hoenn
    return stars, set[stars + 1]
  end

  local MEDALS = {
    { c = "a8b0b8", art = { "...ooo...", "..o###o..", ".o#w###o.", "o#w#####o", "o#######o", "o######do", ".o####do.", "..oddd o.", "...ooo..." } },
    { c = "e86890", art = { "....o....", "...o#o...", "..o#w#o..", ".o#w###o.", "o#######o", ".o####do.", "..o##do..", "...odo...", "....o...." } },
    { c = "f8c848", art = { "....o....", "...o#o...", "oooo#oooo", "o#w#####o", ".o#####o.", "..o###o..", ".o##o##o.", ".oo...oo.", "........." } },
    { c = "7a68d0", art = { ".ooooooo.", "o#w#####o", "o#w#####o", "o#######o", "o######do", ".o####do.", "..o##do..", "...odo...", "....o...." } },
    { c = "58b848", art = { "......oo.", "....oo#o.", "...o#w#o.", "..o#w##o.", ".o####do.", ".o###do..", "o##ddo...", "oooo.....", "........." } },
    { c = "68b8e8", art = { "....o....", "...o#o...", "..o#w#o..", ".o#w###o.", ".o#####o.", "o#######o", "o######do", ".o###ddo.", "..ooooo.." } },
    { c = "e85838", art = { "...ooo...", "..o###o..", ".o#w#o#o.", ".o#####o.", "o###o###o", "o#######o", ".o#####o.", "..o###o..", "...ooo..." } },
    { c = "40c0a0", art = { ".ooo.ooo.", "o#w#o###o", "o#w#####o", "o#######o", ".o#####o.", "..o###o..", "...o#o...", "....o....", "........." } },
  }
  for _, m in ipairs(MEDALS) do for i, row in ipairs(m.art) do m.art[i] = row:gsub(" ", ".") end end
  local function badgeSocket(self, model, index, cx, cy, r)
    local owned = model.badgeOwned and model.badgeOwned[index]
    CIRC(cx - r, cy - r, r * 2 + 1, self.colors.outline)
    CIRC(cx - r + 1, cy - r + 1, r * 2 - 1, owned and hex("3c2a48") or hex("2a2030"))
    CIRCrows(cx - r + 1, cy - r + 1, r * 2 - 1, r + 1, r * 2, owned and hex("4a3458") or hex("342a3c"))
    local drawn = model.drawBadge and model.drawBadge(index, cx, cy, owned)
    if not drawn then
      -- eight original medal cuts, one per slot
      local m = MEDALS[((index - 1) % #MEDALS) + 1]
      local pal = owned and { o = self.colors.outline, ["#"] = hex(m.c), w = mix(hex(m.c), WHITE, 0.6), d = mix(hex(m.c), hex("000000"), 0.35) }
        or { o = hex("4a3e54"), ["#"] = hex("3a3044"), w = hex("3a3044"), d = hex("3a3044") }
      local G = ui.graphics
      G.push(); G.translate(cx - #m.art[1], cy - #m.art); G.scale(2, 2)
      ART(m.art, 0, 0, pal)
      G.pop()
    end
    if owned and (self:clock() + index * 0.37) % 3.2 < 0.15 then
      self:wantAmbient(0.2)
      P(cx + r - 3, cy - r + 2, WHITE); P(cx + r - 4, cy - r + 2, hex("f8f0a0"))
      P(cx + r - 2, cy - r + 2, hex("f8f0a0")); P(cx + r - 3, cy - r + 1, hex("f8f0a0"))
      P(cx + r - 3, cy - r + 3, hex("f8f0a0"))
    end
  end

  function H:trainer(model)
    local colors = self.colors
    if model.kind == "records" or model.kind == "badges" then
      return base.trainer(self, model)
    end
    local tier, frame = cardTier(model)
    local dark, light = hex(frame[1]), hex(frame[2])
    -- card body
    local x, y, w, h = 7, 32, 226, 98
    if self:shadowVisible() then RR(x + 2, y + 2, w, h, 6, colors.shadow) end
    RR(x, y, w, h, 6, colors.outline)
    RR(x + 1, y + 1, w - 2, h - 2, 5, dark)
    RR(x + 1, y + 1, w - 2, 14, 5, light)
    R(x + 1, y + 13, w - 2, 2, dark)
    -- card face
    RR(x + 5, y + 17, w - 10, h - 22, 3, mix(colors.surface, light, self.dark and 0.08 or 0.12))
    for ry = y + 32, y + h - 10, 14 do R(x + 9, ry, 140, 1, mix(colors.surface, dark, 0.18)) end
    -- the stars the game awarded
    for s = 1, tier do
      ART({ "....o....", "...o#o...", "ooo###ooo", "o#######o", ".o#####o.", ".o##o##o.", ".oo...oo." },
        x + w - 14 - (s - 1) * 10, y + 3, { o = colors.outline, ["#"] = hex("f8e070") })
    end
    self:partyInfo(self:fitPartyInfo(model.idText or "ID -----", 120), x + 8, y + 2, WHITE)
    -- portrait window
    local px, py = x + w - 62, y + 22
    RR(px, py, 54, 66, 3, colors.outline)
    RR(px + 1, py + 1, 52, 64, 2, mix(colors.surface, light, 0.35))
    RRrows(px + 1, py + 1, 52, 64, 2, 44, 64, mix(light, dark, 0.3))
    if model.drawPlayer then model.drawPlayer(px + 27, py + 44, 2) end
    -- name + facts
    local name = self:fitLabel(model.name or "---", 130)
    self:label(name, x + 10, y + 18, colors.ink)
    self:partyInfo(self:fitPartyInfo(model.region or "KANTO", 60), x + 92, y + 20, colors.green, 54, "right")
    local rows = {
      { translate("MONEY"), model.money },
      { translate("POKEDEX"), model.pokedex },
      { translate("TIME"), model.time },
    }
    for i, row in ipairs(rows) do
      local ry = y + 35 + (i - 1) * 14
      self:partyInfo(self:fitPartyInfo(row[1], 60), x + 10, ry, colors.mutedInk)
      self:partyInfo(self:fitPartyInfo(tostring(row[2] or "--"), 76), x + 70, ry, colors.ink, 76, "right")
    end
    -- badge case
    local cy = 135
    if self:shadowVisible() then RR(9, cy + 2, 226, 76, 5, colors.shadow) end
    RR(7, cy, 226, 76, 5, colors.outline)
    RR(8, cy + 1, 224, 74, 4, hex("5a2f38"))
    RR(11, cy + 11, 218, 61, 3, hex("2a1820"))
    self:withoutShadow(function()
      local label = self:fitPartyInfo(translate("BADGES"), 70)
      self:partyInfo(label, 13, cy - 1, hex("f0c8a8"))
      self:partyInfo(model.badgeText or "", 19 + self:partyInfoWidth(label), cy - 1, WHITE)
      self:partyInfo(self:fitPartyInfo(model.badgeRegion or model.region or "", 100),
        124, cy - 1, hex("f8d870"), 104, "right")
    end)
    for index = 1, 8 do
      local col, row = (index - 1) % 4, floor((index - 1) / 4)
      badgeSocket(self, model, index, 40 + col * 53, cy + 26 + row * 29, 11)
    end
  end

  ---------------------------------------------------------------------------
  -- Step Counter: a Pokétch-style LCD app
  ---------------------------------------------------------------------------
  local LCD_BG, LCD_DARK, LCD_MID = hex("b4cc98"), hex("2c3c24"), hex("8aa474")
  function H:steps(model)
    local colors = self.colors
    -- device bezel
    local x, y, w, h = 12, 38, 216, 112
    if self:shadowVisible() then RR(x + 2, y + 3, w, h, 10, colors.shadow) end
    RR(x, y, w, h, 10, colors.outline)
    RR(x + 1, y + 1, w - 2, h - 2, 9, hex("4a5058"))
    RRrows(x + 1, y + 1, w - 2, h - 2, 9, 0, 8, hex("646c76"))
    -- screen
    RR(x + 10, y + 10, w - 20, h - 20, 4, hex("1e2418"))
    RR(x + 12, y + 12, w - 24, h - 24, 3, LCD_BG)
    for sy = y + 13, y + h - 13, 2 do R(x + 13, sy, w - 26, 1, mix(LCD_BG, LCD_MID, 0.18)) end
    self:withoutShadow(function()
      self:partyInfo(self:fitPartyInfo(translate("STEP COUNTER"), 150), x + 18, y + 13, LCD_DARK)
      -- walking feet animate
      local step = floor(self:clock() / 0.45) % 2
      self:wantAmbient(0.45)
      local fx, fy = x + w - 42, y + 15
      local FOOT_L = { ".##.", "####", "####", "####", ".##.", "....", ".##.", ".##." }
      local FOOT_R = FOOT_L
      ART(FOOT_L, fx, fy + (step == 0 and 0 or 3), { ["#"] = step == 0 and LCD_DARK or LCD_MID })
      ART(FOOT_R, fx + 7, fy + (step == 0 and 3 or 0), { ["#"] = step == 0 and LCD_MID or LCD_DARK })
      local font = ui.largeFont
      local value = tostring(model.steps or "0")
      local G = ui.graphics
      if font and (not font.hasGlyphs or font:hasGlyphs(value)) and font:getWidth(value) <= w - 40 then
        local prev = G.getFont()
        G.setFont(font)
        local tw = font:getWidth(value)
        K.setc(mix(LCD_BG, LCD_DARK, 0.15))
        G.print(("8"):rep(#value), x + floor((w - font:getWidth(("8"):rep(#value))) / 2), y + 36)
        K.setc(LCD_DARK)
        G.print(value, x + floor((w - tw) / 2), y + 36)
        if prev then G.setFont(prev) end
      else
        self:label(value, x + 12, y + 44, LCD_DARK, w - 24, "center")
      end
      self:partyInfo(self:fitPartyInfo(translate("TOTAL STEPS"), w - 30), x + 15, y + 70, LCD_DARK, w - 30, "center")
      -- road to the next ten thousand: a segmented LCD track with a flag
      local total = tonumber(model.steps) or 0
      local goal = (floor(total / 10000) + 1) * 10000
      local frac = (total % 10000) / 10000
      local goalText = tostring(goal):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
      local segs = 14
      local groupW = segs * 8 + 8 + self:partyInfoWidth(goalText)
      local tx, ty = x + floor((w - groupW) / 2), y + 86
      for i = 0, segs - 1 do
        local on = i < floor(frac * segs + 0.5)
        R(tx + i * 8, ty, 6, 5, on and LCD_DARK or mix(LCD_BG, LCD_MID, 0.45))
      end
      local fx2 = tx + segs * 8
      ART({ "#...", "###.", "####", "#...", "#...", "#..." }, fx2, ty - 1, { ["#"] = LCD_DARK })
      self:partyInfo(goalText, fx2 + 8, ty - 3, LCD_DARK)
    end)
    -- Pokétch-style reset key (same hit rectangle)
    local pressed = self:beginPress(54, 165, 132, 38, true)
    local a = K.rampOf(hex("e04838"))
    local off = self:v4Button(54, 165, 132, 38, a, { radius = 8, lip = 5, chamfer = 7 })
    self:label(self:fitLabel(translate("RESET"), 112), 64, 172 + off, WHITE, 112, "center")
    self:endPress(pressed)
  end

  ---------------------------------------------------------------------------
  -- Bag: pocket plate, item slots with quantity pills, lipped actions
  ---------------------------------------------------------------------------
end
