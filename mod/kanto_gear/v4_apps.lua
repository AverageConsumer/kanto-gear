-- Kanto Gear v4: bespoke app screens (Pokédex, Trainer Card, Step Counter).
return function(H, ui, K)
  local floor, max, min = math.floor, math.max, math.min
  local R, P, RR, RRrows, CH, CHrows = K.R, K.P, K.RR, K.RRrows, K.CH, K.CHrows
  local CIRC, CIRCrows, RING, ART = K.CIRC, K.CIRCrows, K.RING, K.ART
  local mix, hex = K.mix, K.hex
  local base, cg, WHITE = K.base, K.cg, K.WHITE
  local translate = function(value) return ui.translate and ui.translate(value) or value end
  local Dex = ui.pokedexPage

  local function box(self, x, y, w, h, fill, edge, radius)
    return self:v4Window(x, y, w, h, { fill = fill, edge = edge, radius = radius })
  end

  ---------------------------------------------------------------------------
  -- Pokédex
  ---------------------------------------------------------------------------
  -- The device's signature lens and status lights.
  function H:v4DexLens(x, y)
    CIRC(x, y, 18, self.colors.outline)
    CIRC(x + 1, y + 1, 16, hex("f8f8f8"))
    CIRC(x + 3, y + 3, 12, hex("2868c8"))
    CIRCrows(x + 3, y + 3, 12, 0, 5, hex("58a0f0"))
    R(x + 6, y + 5, 3, 2, WHITE)
    local t = self:clock()
    local lit = floor(t / 0.6) % 3
    self:wantAmbient(0.6)
    for i, c in ipairs({ "f04838", "f8c830", "48c058" }) do
      local col = hex(c)
      if i - 1 ~= lit then col = mix(col, { 0, 0, 0, 1 }, 0.45) end
      CIRC(x + 20 + (i - 1) * 7, y + 1, 6, self.colors.outline)
      CIRC(x + 21 + (i - 1) * 7, y + 2, 4, col)
    end
  end

  function H:pokedexIndex(model)
    local colors = self.colors
    local red = hex("e04838")
    -- device strip
    box(self, 7, 34, 226, 30)
    RR(9, 36, 222, 4, 1, mix(red, colors.surface, 0.15))
    self:v4DexLens(12, 41)
    local region = self:fitPartyType(translate(model.region or "NATIONAL DEX"), 80)
    self:partyInfo(region, 58, 40, colors.mutedInk)
    local count = tostring(model.caught or 0) .. " / " .. tostring(model.total or 0)
    self:partyInfo(count, 140, 40, colors.ink, 86, "right")
    local fraction = max(0, min(1, (tonumber(model.caught) or 0) / max(1, tonumber(model.total) or 1)))
    if model.tools then
      for index, tool in ipairs(model.tools) do
        local x, y, w, h = Dex.toolRect(index)
        local pressed = self:beginPress(x, y, w, h, model.canUse ~= false)
        self:panel(x, y, w, h, false, nil, colors.redLight)
        self:partyInfoCentered(self:fitPartyInfo(translate(tool.label), w - 8), x + 4, y, w - 8, h, colors.ink)
        self:endPress(pressed)
      end
    else
      R(58, 53, 168, 6, colors.outline)
      R(59, 54, 166, 4, self.dark and hex("2a3542") or hex("e6dcd8"))
      local f = floor(166 * fraction + 0.5)
      R(59, 54, f, 4, red); R(59, 54, f, 1, mix(red, WHITE, 0.5))
    end
    for index, entry in ipairs(model.entries or {}) do
      local left, top, width, height = Dex.entryRect(index, #model.entries)
      local enabled = entry.revealed ~= false and model.canUse ~= false
        and not (model.forms and entry.selected)
      local pressed = self:beginPress(left, top, width, height, enabled)
      local fill = entry.caught and colors.surface
        or entry.seen and mix(colors.surface, colors.band, 0.5) or colors.bandLight
      self:v4Window(left, top, width, height, { fill = fill, radius = 3 })
      -- number tab
      local number = entry.letter and string.char(64 + entry.letter)
        or ("%03d"):format(tonumber(entry.dex) or 0)
      local tw = self:partyInfoWidth(number) + 6
      if cg(self) then
        CH(left + 1, top + 1, tw, 9, 2, entry.caught and self.tok.acc.M or colors.silverDark)
      else
        RR(left + 1, top + 1, tw, 9, 2, entry.caught and red or colors.silverDark)
      end
      self:partyInfo(number, left + 4, top - 1, WHITE)
      -- screen
      local sx, sy = left + 24, top + 4
      self:v4Seat(sx, sy, 24, not entry.caught and not model.forms)
      if model.drawPokemon then
        model.drawPokemon(entry, sx + 2, sy + 2, 20, not entry.caught)
      end
      if entry.caught then self:v4MiniBall(left + width - 10, top + 3, "ok") end
      local name = self:fitPartyInfo(entry.revealed == false and "???" or entry.name or "---", width - 6)
      self:partyInfoCentered(name, left + 3, top + 29, width - 6, 9,
        entry.caught and colors.ink or colors.mutedInk)
      if entry.selected then self:focusFrame(left, top, width, height) end
      self:endPress(pressed)
    end
    -- pager
    local page, pages = model.page or 1, model.pages or 1
    self:v4Window(82, 199, 76, 12, { radius = 2, shadow = false })
    if pages > 1 then
      for _, direction in ipairs({ -1, 1 }) do
        local x, y, w, h = Dex.pagerRect(direction, false)
        local pressed = self:beginPress(x, y, w, h, model.canUse ~= false)
        self:pageChevron(x + w / 2, y + floor(h / 2), direction > 0, false)
        self:endPress(pressed)
      end
    end
    self:partyInfoCentered(tostring(page) .. "/" .. tostring(pages), 100, 199, 40, 12, colors.green)
  end

  local STAT_KEYS = {
    { "SP%.?%s*ATK", "spatk" }, { "SP%.?%s*DEF", "spdef" }, { "SPC", "special" },
    { "SPECIAL", "special" }, { "SPE", "speed" }, { "SPD", "speed" },
    { "ATK", "attack" }, { "ATTACK", "attack" }, { "DEF", "defense" }, { "HP", "hp" },
  }
  local STAT_COLORS = {
    hp = hex("58c060"), attack = hex("f05848"), defense = hex("f0a020"),
    spatk = hex("5890f0"), spdef = hex("40b8b0"), speed = hex("f070b0"),
    special = hex("8070e0"),
  }
  local ORDER = { "hp", "attack", "defense", "spatk", "spdef", "speed" }
  local function statKey(label, index, count)
    label = tostring(label or ""):upper()
    for _, pair in ipairs(STAT_KEYS) do
      if label:find(pair[1]) then return pair[2] end
    end
    return count == 6 and ORDER[index] or "special"
  end

  function H:pokedexStats(model)
    local colors = self.colors
    local rows = model.stats or {}
    model.stats = {}
    base.pokedexStats(self, model)
    model.stats = rows
    local count = #rows
    local step = count > 5 and 21 or 25
    local top = 76
    self:v4Window(7, top - 2, 226, step * count + 4)
    local best, bestValue = nil, -1
    for i, row in ipairs(rows) do
      local v = tonumber(row.value) or 0
      if v > bestValue then best, bestValue = i, v end
    end
    for i, row in ipairs(rows) do
      local y = top + (i - 1) * step
      if i % 2 == 0 then R(9, y, 222, step, colors.bandLight) end
      local key = statKey(row.label, i, count)
      local c = STAT_COLORS[key] or colors.blue
      R(10, y + 4, 3, step - 8, c)
      self:partyType(translate(row.label or "STAT"), 16, y + floor((step - 11) / 2), colors.mutedInk, 52)
      local v = tonumber(row.value) or 0
      local bx, bw, by = 72, 119, y + floor((step - 8) / 2)
      R(bx, by, bw, 8, colors.outline)
      R(bx + 1, by + 1, bw - 2, 6, self.dark and hex("2a3542") or hex("dfe6e1"))
      local f = floor((bw - 2) * min(1, v / 180) + 0.5)
      R(bx + 1, by + 1, f, 6, c); R(bx + 1, by + 1, f, 2, mix(c, WHITE, 0.45))
      for s = 1, 3 do R(bx + floor(bw * s / 4), by + 1, 1, 6, { 0, 0, 0, 0.16 }) end
      self:partyInfo(tostring(row.value or 0), 194, y + floor((step - 11) / 2) - 1,
        colors.ink, 27, "right")
      if i == best then ART({ "..#..", ".###.", "#####" }, 224, by + 2, { ["#"] = colors.red }) end
    end
  end

  ---------------------------------------------------------------------------
  -- Trainer Card: the card's colour follows the badge count, like Gen 4.
  ---------------------------------------------------------------------------
  local CARD_TIERS = {
    { "4f9a6c", "8cd0a4" }, { "b0703a", "e0a46c" }, { "8a8f9c", "d0d6e0" },
    { "c8a020", "f8e070" }, { "3a6ad0", "90b8f8" },
  }
  local function cardTier(model)
    local owned = 0
    for _, has in ipairs(model.badgeOwned or {}) do if has then owned = owned + 1 end end
    local tier = owned >= 8 and 4 or owned >= 6 and 3 or owned >= 3 and 2 or owned >= 1 and 1 or 0
    return tier, owned
  end

  local function badgeSocket(self, model, index, cx, cy, r)
    local owned = model.badgeOwned and model.badgeOwned[index]
    CIRC(cx - r, cy - r, r * 2 + 1, self.colors.outline)
    CIRC(cx - r + 1, cy - r + 1, r * 2 - 1, owned and hex("3c2a48") or hex("2a2030"))
    CIRCrows(cx - r + 1, cy - r + 1, r * 2 - 1, r + 1, r * 2, owned and hex("4a3458") or hex("342a3c"))
    local drawn = model.drawBadge and model.drawBadge(index, cx, cy, owned)
    if not drawn then
      if owned then
        CIRC(cx - 4, cy - 4, 9, self.colors.outline)
        CIRC(cx - 3, cy - 3, 7, hex("f8c848")); P(cx - 1, cy - 2, WHITE)
      else
        CIRC(cx - 2, cy - 2, 5, hex("4a3e54"))
      end
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
    local tier = cardTier(model)
    local frame = CARD_TIERS[tier + 1]
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
    -- stars for tiers
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
      self:partyInfo(self:fitPartyInfo(translate("TOTAL STEPS"), w - 30), x + 15, y + 74, LCD_DARK, w - 30, "center")
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
  local function qtyPill(self, text, x, y)
    local w = self:partyInfoWidth(text) + 8
    if cg(self) then CH(x - w, y, w, 11, 2, self.colors.outline); CH(x - w + 1, y + 1, w - 2, 9, 1, self.colors.bandLight)
    else RR(x - w, y, w, 11, 3, self.colors.outline); RR(x - w + 1, y + 1, w - 2, 9, 2, self.colors.bandLight) end
    self:partyInfo(text, x - w + 4, y - 1, self.colors.ink)
    return w
  end

  function H:bagCard(item, x, y)
    local colors = self.colors
    local accent = self:itemAccent(item.icon)
    local pressed = self:beginPress(x, y, 112, 43)
    self:v4Window(x, y, 112, 43, { radius = 4 })
    R(x + 1, y + 4, 2, 35, accent)
    -- round item slot
    CIRC(x + 6, y + 6, 31, colors.outline)
    CIRC(x + 7, y + 7, 29, mix(colors.surface, accent, self.dark and 0.3 or 0.22))
    K.CIRCrows(x + 7, y + 7, 29, 15, 29, mix(colors.surface, accent, self.dark and 0.42 or 0.34))
    self:battleItemIcon(item, x + 13, y + 13, accent)
    self:partyName(item.label or translate("ITEM"), x + 41, y + 5, colors.ink, 62)
    local count = ("×%d"):format(tonumber(item.count) or 0)
    if item.detail then
      self:partyInfo(self:fitPartyInfo(item.detail, 62), x + 41, y + 17, colors.green, 62)
    end
    qtyPill(self, count, x + 106, y + 28)
    self:detailChevron(x + 104, y + 7, colors.mutedInk, false)
    self:endPress(pressed)
  end

  function H:bagOverview(model)
    local colors = self.colors
    local amber = hex("e0a020")
    self:v4Window(6, 34, 228, 34)
    R(8, 36, 224, 3, mix(colors.surface, amber, 0.5))
    self:battleBagIcon(13, 38)
    local pockets = model.pockets or 1
    if pockets > 1 then
      self:pageChevron(58, 51, false)
      self:pageChevron(166, 51, true)
    end
    -- pocket name on a tab
    local labelX, labelW = pockets > 1 and 68 or 53, pockets > 1 and 88 or 118
    local name = self:fitPartyInfo(model.pocket or translate("ITEMS"), labelW - 8)
    if cg(self) then CH(labelX, 41, labelW, 18, 4, self.tok.acc.M)
    else
      RR(labelX, 41, labelW, 18, 4, colors.outline)
      RR(labelX + 1, 42, labelW - 2, 16, 3, hex("c07a10"))
      RR(labelX + 1, 42, labelW - 2, 13, 3, amber)
      R(labelX + 4, 42, labelW - 8, 1, hex("f8d878"))
    end
    self:partyInfo(name, labelX, 43, WHITE, labelW, "center")
    -- pocket dots
    if pockets > 1 and pockets <= 8 then
      local current = model.pocketIndex or 1
      for i = 1, pockets do
        local dx = labelX + floor(labelW / 2) - floor((pockets * 6 - 2) / 2) + (i - 1) * 6
        R(dx, 61, 4, 2, i == current and amber or colors.band)
      end
    end
    local page = ("%d/%d"):format(model.page or 1, model.pages or 1)
    self:v4Window(184, 42, 43, 18, { radius = 3, fill = colors.bandLight, shadow = false })
    self:pageChevron(190, 51, false, (model.pages or 1) > 1)
    self:partyInfo(page, 197, 45, colors.ink, 23, "center")
    self:pageChevron(222, 51, true, (model.pages or 1) > 1)
    if model.recent then self:recentBagItem(model.recent, 72, model.canUse) end
    if #(model.entries or {}) == 0 then
      local top = model.recent and 115 or 91
      self:v4MessageWindow(24, top, 192, 70)
      self:partyInfo(translate("THIS POCKET IS EMPTY."), 24, top + 29, colors.mutedInk, 192, "center")
      return
    end
    for index, item in ipairs(model.entries or {}) do
      local col, row = (index - 1) % 2, floor((index - 1) / 2)
      self:bagCard(item, 6 + col * 116, (model.recent and 109 or 72) + row * 47)
    end
  end

  function H:bagDetail(model)
    local item, colors = model.detail, self.colors
    local accent = self:itemAccent(item.icon)
    self:v4Window(6, 34, 228, 62)
    R(8, 36, 224, 3, accent)
    CIRC(14, 41, 50, colors.outline)
    CIRC(15, 42, 48, mix(colors.surface, accent, self.dark and 0.3 or 0.22))
    K.CIRCrows(15, 42, 48, 24, 48, mix(colors.surface, accent, self.dark and 0.42 or 0.34))
    ui.graphics.push()
    ui.graphics.translate(22, 49)
    ui.graphics.scale(2, 2)
    self:battleItemIcon(item, 0, 0, accent)
    ui.graphics.pop()
    self:partyName(item.label or translate("ITEM"), 72, 44, colors.ink, 150)
    if item.detail then
      self:partyInfo(self:fitPartyInfo(item.detail, 150), 72, 58, colors.green)
    end
    qtyPill(self, ("×%d"):format(tonumber(item.count) or 0), 226, 80)
    local lines = model.message or item.lines or {}
    self:v4MessageWindow(6, 100, 228, 44)
    for index = 1, min(2, #lines) do
      self:partyInfo(self:fitPartyInfo(lines[index], 196), 22, 107 + (index - 1) * 14, colors.ink, 196, "center")
    end
    if #lines > 2 then
      self:partyInfo(self:fitPartyInfo(lines[3], 196), 22, 128, colors.ink, 196, "center")
    end
    local a = K.rampOf(hex("e0a020"))
    for index, action in ipairs(model.actions or {}) do
      local enabled = model.canUse ~= false and action.enabled ~= false
      local x, y, w, h = self:bagActionRect(index, #model.actions)
      local pressed = self:beginPress(x, y, w, h, enabled)
      local cancel = action.label == translate("CANCEL")
      local ramp = not enabled and K.rampOf(colors.silverDark)
        or cancel and K.rampOf(hex("5a6c88")) or a
      local off = self:v4Button(x, y, w, h, ramp, { radius = 5, lip = 4, chamfer = 5 })
      self:partyInfoCentered(action.label, x, y + off - 2, w, h, WHITE)
      self:endPress(pressed)
    end
  end

  ---------------------------------------------------------------------------
  -- Silph Store: lipped pills, app tiles, segmented nav
  ---------------------------------------------------------------------------
  local function stateRamp(self, state)
    if state == "soon" then return K.rampOf(self.colors.silverDark) end
    if state == "open" then return K.rampOf(cg(self) and hex("3a8ee8") or hex("3878d0")) end
    return K.rampOf(cg(self) and hex("1ea5d8") or hex("3ea04c"))
  end
  function H:storeAction(x, y, w, label, state)
    local pressed = self:beginPress(x, y, w, 15, state ~= "soon")
    local off = self:v4Button(x, y, w, 15, stateRamp(self, state), { radius = 4, lip = 3, chamfer = 3 })
    self:partyType(translate(label), x + 2, y + 1 + off, WHITE, w - 4)
    self:endPress(pressed)
  end
  function H:storeMiniAction(x, y, w, label, state, enabled)
    local pressed = self:beginPress(x, y, w, 11, enabled == true or state ~= "soon")
    local off = self:v4Button(x, y, w, 11, stateRamp(self, state), { radius = 3, lip = 2, chamfer = 2 })
    self:partyType(translate(label), x + 1, y - 1 + off, WHITE, w - 2)
    self:endPress(pressed)
  end
  function H:storeNewBadge(x, y, w)
    local red = hex("e04838")
    if cg(self) then CH(x, y, w, 10, 2, self.colors.outline); CH(x + 1, y + 1, w - 2, 8, 1, red)
    else RR(x, y, w, 10, 3, self.colors.outline); RR(x + 1, y + 1, w - 2, 8, 2, red); R(x + 3, y + 1, w - 6, 1, hex("f8a090")) end
    local on = floor(self:clock() / 0.6) % 2 == 0
    self:wantAmbient(0.6)
    self:partyType(translate("NEW"), x + 1, y - 1, on and WHITE or hex("f8e070"), w - 2)
  end
  local function storeIcon(self, app, icons, x, y, size)
    local icon = icons and icons[app.icon or app.id]
    local id = K.iconId and K.iconId(icon)
    if cg(self) and id and K.GLYPH[id] then
      CIRC(x, y, size, self.colors.outline)
      CIRC(x + 1, y + 1, size - 2, self.dark and hex("26313c") or hex("f4f8fa"))
      local accent = self:v4AppAccent(id) or self.tok.acc.M
      RING(x + 1, y + 1, size - 2, 2, accent)
      K.GLYPH[id](x + floor((size - 20) / 2), y + floor((size - 20) / 2), accent, mix(accent, self.colors.surface, 0.5))
      return
    end
    if icon then
      local width = icon.right - icon.left + 1
      local height = icon.bottom - icon.top + 1
      icon.draw(x + floor((size - width) / 2) - icon.left, y + floor((size - height) / 2) - icon.top)
    end
  end
  function H:storeAppCard(x, y, w, app, icons)
    local colors = self.colors
    local blocked = app.state == "soon" and self:isPressed(x + 36, y + 28, 43, 11)
    local pressed = self:beginPress(x, y, w, 42, not blocked)
    self:v4Window(x, y, w, 42, { radius = 4 })
    local accent = self:v4AppAccent(K.iconId and K.iconId(icons[app.icon or app.id])) or self.tok.acc.M
    R(x + 1, y + 4, 2, 34, accent)
    storeIcon(self, app, icons, x + 4, y + 6, 29)
    local separateBadge = app.new and self:partyInfoWidth(translate(app.label)) > w - 39 - 29
    self:storeTitle(app.label, x + 36, y + 4, w - 39, app.new and not separateBadge)
    if separateBadge then
      self:storeNewBadge(x + 36 + floor((w - 39 - 25) / 2), y + 15, 25)
    else
      self:partyType(self:fitPartyType(translate(app.category), w - 39), x + 36, y + 16, colors.green, w - 39)
    end
    self:storeMiniAction(x + 36, y + 28, 43, app.action or (app.state == "open" and "OPEN" or "GET"), app.state)
    self:detailChevron(x + w - 9, y + 30, colors.green)
    self:endPress(pressed)
  end
  function H:storeInstalledRow(x, y, w, app, icons)
    local colors = self.colors
    local blocked = app.state == "soon" and self:isPressed(x + w - 54, y + 9, 44, 11)
    local pressed = self:beginPress(x, y, w, 30, not blocked)
    self:v4Window(x, y, w, 30, { radius = 3 })
    storeIcon(self, app, icons, x + 4, y + 2, 26)
    self:storeTitle(app.label, x + 34, y + 3, 91, app.new)
    self:partyType(self:fitPartyType(translate(app.category), 91), x + 34, y + 15, colors.green, 91)
    self:storeMiniAction(x + w - 54, y + 9, 44, app.action or "OPEN", app.state)
    self:endPress(pressed)
  end
  function H:storeNav(active)
    local items = { { "today", "TODAY" }, { "apps", "APPS" }, { "library", "MY APPS" } }
    for index, item in ipairs(items) do
      local x, selected = 7 + (index - 1) * 76, active == item[1]
      local pressed = self:beginPress(x, 195, 73, 18, not selected)
      self:tab(x, 195, 73, 18, translate(item[2]), selected, false, false)
      self:endPress(pressed)
    end
  end

  ---------------------------------------------------------------------------
  -- Options: Gen 4 style ◀ value ▶ selectors (left half lowers, right raises)
  ---------------------------------------------------------------------------
  local CAT_GLYPH = {
    APPEARANCE = function(x, y, c, d)
      K.CIRC(x + 1, y + 1, 18, c); K.CIRC(x + 3, y + 3, 14, WHITE)
      K.CIRC(x + 5, y + 5, 4, hex("f05848")); K.CIRC(x + 11, y + 5, 4, hex("48a8f0"))
      K.CIRC(x + 5, y + 11, 4, hex("f8c838")); K.CIRC(x + 12, y + 12, 4, d)
    end,
    DISPLAY = function(x, y, c, d)
      R(x + 1, y + 2, 18, 13, c); R(x + 3, y + 4, 14, 9, d); R(x + 3, y + 4, 14, 2, WHITE)
      R(x + 8, y + 15, 4, 2, c); R(x + 5, y + 17, 10, 2, c)
    end,
    BATTLE = function(x, y, c, d)
      for i = 0, 11 do R(x + 3 + i, y + 3 + i, 3, 2, c) end
      R(x + 12, y + 14, 6, 2, d); R(x + 14, y + 12, 2, 6, d)
      R(x + 3, y + 3, 2, 2, WHITE)
    end,
    RESEARCH = function(x, y, c, d)
      K.RING(x + 1, y + 1, 13, 2, c); K.CIRC(x + 4, y + 4, 7, d)
      for i = 0, 5 do R(x + 12 + i, y + 12 + i, 3, 3, c) end
    end,
    CONTROLS = function(x, y, c, d)
      RR(x, y + 4, 20, 12, 4, c)
      R(x + 4, y + 7, 2, 6, WHITE); R(x + 2, y + 9, 6, 2, WHITE)
      K.CIRC(x + 12, y + 7, 3, d); K.CIRC(x + 15, y + 10, 3, d)
    end,
    SYSTEM = function(x, y, c, d)
      K.RING(x + 3, y + 3, 14, 2, c)
      R(x + 9, y, 2, 4, c); R(x + 9, y + 16, 2, 4, c); R(x, y + 9, 4, 2, c); R(x + 16, y + 9, 4, 2, c)
      K.CIRC(x + 7, y + 7, 6, d)
    end,
  }
  CAT_GLYPH.EXPLORATION = CAT_GLYPH.RESEARCH
  local function accentOf(self, name)
    local map = { blue = hex("3878d0"), green = hex("3ea04c"), red = hex("e04838"), amber = hex("e09a20") }
    return map[name or ""] or self.tok.acc.M
  end

  function H:settings(model)
    local colors = self.colors
    model = model or {}
    if not model.category then
      for index, category in ipairs(model.categories or {}) do
        local y = 34 + (index - 1) * 30
        local pressed = self:beginPress(7, y, 226, 26)
        local accent = accentOf(self, category.accent)
        self:v4Key(7, y, 226, 27)
        if cg(self) then R(8, y + 4, 2, 17, accent) end
        -- glyph seat
        CIRC(11, y + 2, 22, colors.outline)
        CIRC(12, y + 3, 20, mix(colors.surface, accent, self.dark and 0.35 or 0.22))
        local glyph = CAT_GLYPH[tostring(category.label)]
        if glyph then glyph(12, y + 3, accent, mix(accent, colors.surface, 0.45)) end
        self:partyInfo(self:fitPartyInfo(translate(category.label), 170), 39, y + 2, colors.ink)
        self:partyInfo(self:fitPartyInfo(translate(category.detail), 170), 39, y + 12, colors.mutedInk)
        ART({ "#..", "##.", "###", "##.", "#.." }, 219, y + 10, { ["#"] = colors.mutedInk })
        self:endPress(pressed)
      end
      return
    end

    if model.option then
      local first = (model.page - 1) * 4 + 1
      for visible = 0, 3 do
        local choice = model.choices[first + visible]
        if choice then
          local y, selected = self:settingsChoiceTop(model) + visible * 25, choice[2] == model.value
          local pressed = self:beginPress(7, y, 226, 22, not selected)
          self:v4Choice(7, y, 226, 22, selected, true)
          self:partyInfoCentered(self:fitPartyInfo(translate(choice[1]), 190), 7, y, 226, 19,
            selected and WHITE or colors.ink)
          self:endPress(pressed)
          if selected then
            local b = floor(self:clock() / 0.4) % 2
            self:wantAmbient(0.4)
            ART(K.CHEV_R, 14 + b, y + 8, { ["#"] = WHITE })
          end
        end
      end
      if model.pages > 1 then
        self:v4Window(72, 135, 96, 12, { radius = 2, shadow = false })
        self:pageChevron(88, 141, false)
        self:partyType(model.page .. "/" .. model.pages, 104, 136, colors.ink, 32)
        self:pageChevron(152, 141, true)
      end
      -- Gen 4 text box with typewriter help and the blinking advance mark
      self:v4MessageWindow(6, 150, 228, 62)
      local lines = self:settingsHelpLines(translate(model.description or ""))
      local key = tostring(model.option) .. ":" .. tostring(model.value)
      local now = self:clock()
      if self.v4HelpKey ~= key then self.v4HelpKey, self.v4HelpAt = key, now end
      local shown = (self.motionEnabled == false or self.frozenTime) and math.huge
        or floor((now - (self.v4HelpAt or now)) * 70)
      local total, left, characters = 0, shown, {}
      for index, line in ipairs(lines) do
        characters[index] = ui.glyphs(line)
        total = total + #characters[index]
      end
      local top = 150 + floor((62 - #lines * 9) / 2) - 1
      for index, line in ipairs(lines) do
        local chars = characters[index]
        local part = left >= #chars and line
          or table.concat(chars, "", 1, math.max(0, left))
        left = left - #chars
        if #part > 0 then self:partyInfo(part, 16, top + (index - 1) * 9 - 1, colors.ink) end
      end
      if shown < total then self:wantAmbient(0.05, 1 / 30)
      else self:v4AdvanceArrow(214, 199) end
      return
    end

    if model.tabs then return self:v4SettingsTabbed(model) end
    local accent = accentOf(self, model.accent)
    local first = (model.page - 1) * 4 + 1
    for visible = 0, 3 do
      local row = model.rows[first + visible]
      if row then
        local y = 36 + visible * 40
        local enabled = row.enabled ~= false
        local pressed = self:beginPress(7, y, 226, 35, enabled)
        self:v4Window(7, y, 226, 35, { radius = 4 })
        R(8, y + 4, 2, 27, accent)
        local ink = enabled and colors.ink or colors.disabledInk
        self:partyInfo(self:fitPartyInfo(translate(row.label), 200), 15, y + 1, ink)
        local value = translate(row.value)
        if row.action then
          local warn = value == translate("TAP AGAIN")
          local a = K.rampOf(not enabled and colors.silverDark or warn and hex("e04838") or accent)
          local off = self:v4Button(60, y + 16, 120, 15, a, { radius = 4, lip = 3, chamfer = 3 })
          self:partyType(self:fitPartyType(value, 112), 64, y + 16 + off, WHITE, 112)
        else
          local choices = row.choices or {}
          local fits = #choices >= 2 and #choices <= 3
          if fits then
            local segW = floor(210 / #choices)
            for _, choice in ipairs(choices) do
              if self:partyInfoWidth(translate(choice[1])) > segW - 6 then fits = false end
            end
          end
          if fits then
            self:v4Segments(15, y + 15, 210, choices, row.raw, enabled, accent)
          else
            local well = mix(colors.surface, accent, self.dark and 0.22 or 0.12)
            if cg(self) then CH(15, y + 15, 210, 17, 3, colors.outline); CH(16, y + 16, 208, 15, 2, well)
            else RR(15, y + 15, 210, 17, 4, colors.outline); RR(16, y + 16, 208, 15, 3, well)
              R(18, y + 16, 204, 1, { 0, 0, 0, 0.12 }) end
            local valueInk = enabled and colors.ink or colors.disabledInk
            local firstLine, secondLine
            if self:partyInfoWidth(value) > 176 then firstLine, secondLine = self:splitPartyInfo(value, 176) end
            if secondLine then
              self:partyType(firstLine, 24, y + 14, valueInk, 176)
              self:partyType(secondLine, 24, y + 22, valueInk, 176)
            else
              self:partyType(self:fitPartyType(value, 176), 24, y + 18, valueInk, 176)
            end
            self:detailChevron(214, y + 21, enabled and accent or colors.disabledInk)
          end
        end
        self:endPress(pressed)
      end
    end
    if (model.pages or 1) > 1 then
      self:v4Window(72, 194, 96, 17, { radius = 3, shadow = false })
      self:pageChevron(88, 202, false)
      self:partyInfo(model.page .. "/" .. model.pages, 105, 197, colors.ink, 32, "center")
      self:pageChevron(152, 202, true)
    end
  end

  ---------------------------------------------------------------------------
  -- Field Kit cards
  ---------------------------------------------------------------------------
  function H:toolCard(action, x, y)
    local colors = self.colors
    local accent = self:toolAccent(action.icon)
    local ready = action.ready
    local pressed = self:beginPress(x, y, 109, 76, ready)
    self:v4Window(x, y, 109, 76, { radius = 5, fill = ready and colors.surface or colors.bandLight })
    R(x + 5, y + 2, 99, 2, ready and accent or colors.silverDark)
    CIRC(x + 6, y + 8, 38, colors.outline)
    CIRC(x + 7, y + 9, 36, ready and mix(colors.surface, accent, self.dark and 0.3 or 0.2) or colors.band)
    K.CIRCrows(x + 7, y + 9, 36, 18, 36, ready and mix(colors.surface, accent, self.dark and 0.42 or 0.32) or colors.band)
    self:toolIcon(action.icon, x + 12, y + 14, ready and accent or colors.silver)
    local infoLeft = x + 48
    local label = tostring(action.label or "")
    if self:partyInfoWidth(label) <= 56 then
      self:partyInfo(label, infoLeft, y + 8, colors.ink, 56, "center")
    else
      local a, b = self:splitPartyInfo(label, 56)
      if b then
        self:partyType(a, infoLeft, y + 5, colors.ink, 56)
        self:partyType(b, infoLeft, y + 15, colors.ink, 56)
      else
        self:partyType(self:fitPartyType(label, 56), infoLeft, y + 10, colors.ink, 56)
      end
    end
    local status = translate(ready and "READY" or "NOT HERE")
    local ramp = K.rampOf(ready and colors.hp or colors.silverDark)
    if cg(self) then CH(infoLeft, y + 28, 56, 13, 3, colors.outline); CH(infoLeft + 1, y + 29, 54, 11, 2, ramp.M)
    else RR(infoLeft, y + 28, 56, 13, 4, colors.outline); RR(infoLeft + 1, y + 29, 54, 11, 3, ramp.M)
      R(infoLeft + 3, y + 29, 50, 1, ramp.Hi) end
    self:partyType(self:fitPartyType(status, 52), infoLeft + 2, y + 29, WHITE, 52)
    R(x + 8, y + 52, 93, 1, colors.band)
    self:partyType(self:fitPartyType(translate(ready and "TAP TO USE" or "CONTEXT REQUIRED"), 93),
      x + 8, y + 57, ready and colors.green or colors.mutedInk, 93)
    if ready and floor(self:clock() / 0.5) % 2 == 0 then
      self:wantAmbient(0.5)
      ART(K.CHEV_R, x + 98, y + 59, { ["#"] = colors.green })
    end
    self:endPress(pressed)
  end

  -- Segmented strip; the active segment is a lipped key in the row accent.
  function H:v4Segments(x, y, w, choices, value, enabled, accent)
    local colors = self.colors
    local n = #choices
    local segW = floor(w / n)
    if cg(self) then CH(x, y, w, 17, 3, colors.outline); CH(x + 1, y + 1, w - 2, 15, 2, self.dark and hex("141b22") or hex("e4ebf0"))
    else RR(x, y, w, 17, 4, colors.outline); RR(x + 1, y + 1, w - 2, 15, 3, self.dark and hex("1c2533") or hex("dfe8e1"))
      R(x + 3, y + 1, w - 6, 1, { 0, 0, 0, 0.15 }) end
    local a = K.rampOf(enabled and (accent or self.tok.acc.M) or colors.silverDark)
    for i, choice in ipairs(choices) do
      local sx = x + (i - 1) * segW
      local sw = i == n and w - segW * (n - 1) or segW
      local active = choice[2] == value
      local label = translate(choice[1])
      if active then
        if cg(self) then CH(sx + 1, y + 1, sw - 2, 15, 2, a.M); CH(sx + 1, y + 1, sw - 2, 7, 2, a.L)
        else RR(sx + 1, y + 1, sw - 2, 15, 3, a.D); RR(sx + 1, y + 1, sw - 2, 13, 3, a.M)
          RRrows(sx + 1, y + 1, sw - 2, 13, 3, 0, 6, a.L); R(sx + 4, y + 1, sw - 8, 1, a.Hi) end
        self:partyType(label, sx, y + 2, WHITE, sw)
      else
        if i > 1 and choices[i - 1][2] ~= value then R(sx, y + 4, 1, 9, colors.band) end
        self:partyType(label, sx, y + 3, enabled and colors.mutedInk or colors.disabledInk, sw)
      end
    end
  end

  -- Page swipes move only the choices; the help textbox stays put.
  function H:settingsMotionRegion(option, first, last)
    if option then return 34, 134 end
    if self.v4SettingsTabs then return 70, 166 end
    return first, last
  end

  function H:settingsChoiceTop(model)
    local count = min(4, #(model.choices or {}) - ((model.page or 1) - 1) * 4)
    local height = max(0, count * 25 - 3)
    return 36 + floor((97 - height) / 2)
  end

  ---------------------------------------------------------------------------
  -- Tabbed settings: category tabs, inline controls, help textbox.
  -- Touch-only safety: the first tap selects a row (and explains it),
  -- only a selected row changes its value.
  ---------------------------------------------------------------------------
  H.v4SettingsTabs = true
  local TAB_Y, TAB_H, TAB_STEP = 32, 22, 38
  local ROW_Y, ROW_H, ROW_STEP, CTRL_X, CTRL_W = 71, 22, 24, 114, 113

  local function rowKey(row) return row.key or row.action end
  local function segmentFits(self, row)
    local choices = row.choices or {}
    if #choices < 2 or #choices > 3 then return false end
    local segW = floor(CTRL_W / #choices)
    for _, choice in ipairs(choices) do
      if self:partyInfoWidth(translate(choice[1])) > segW - 5 then return false end
    end
    return true
  end

  local function typewriter(self, text, key, x, y, w, h)
    local colors = self.colors
    local lines = self:settingsHelpLines(text)
    while #lines > 3 do table.remove(lines) end
    local now = self:clock()
    if self.v4HelpKey ~= key then self.v4HelpKey, self.v4HelpAt = key, now end
    local shown = (self.motionEnabled == false or self.frozenTime) and math.huge
      or floor((now - (self.v4HelpAt or now)) * 70)
    local total, left, characters = 0, shown, {}
    for index, line in ipairs(lines) do
      characters[index] = ui.glyphs(line)
      total = total + #characters[index]
    end
    local top = y + floor((h - #lines * 11) / 2)
    for index, line in ipairs(lines) do
      local chars = characters[index]
      local part = left >= #chars and line
        or table.concat(chars, "", 1, math.max(0, left))
      left = left - #chars
      if #part > 0 then self:partyInfo(part, x + 10, top + (index - 1) * 11 - 1, colors.ink) end
    end
    if shown < total then self:wantAmbient(0.05, 1 / 30)
    else self:v4AdvanceArrow(x + w - 22, y + h - 12) end
  end

  function H:v4SettingsTabbed(model)
    local colors = self.colors
    -- category tabs
    for i, cat in ipairs(model.tabs) do
      local x = 7 + (i - 1) * TAB_STEP
      local active = i == model.tab
      local accent = accentOf(self, cat.accent)
      local pressed = self:beginPress(x, TAB_Y, TAB_STEP - 2, TAB_H, not active)
      if active then self:v4Button(x, TAB_Y, TAB_STEP - 2, TAB_H, K.rampOf(accent), { radius = 4, lip = 3, chamfer = 4 })
      else self:v4Key(x, TAB_Y, TAB_STEP - 2, TAB_H) end
      local glyph = CAT_GLYPH[tostring(cat.label)] or CAT_GLYPH[tostring(cat.id):upper()]
      if glyph then
        local G = ui.graphics
        G.push(); G.translate(x + 9, TAB_Y + 2); G.scale(0.9, 0.9)
        glyph(0, 0, active and WHITE or accent, active and mix(accent, WHITE, 0.5) or mix(accent, colors.surface, 0.45))
        G.pop()
      end
      self:endPress(pressed)
    end
    -- section line + pager
    local accent = accentOf(self, model.accent)
    R(9, 59, 3, 8, accent)
    self:partyInfo(self:fitPartyInfo(translate(model.label or ""), 140), 15, 56, colors.ink)
    if model.pages > 1 then
      local cx = 176
      self:v4Window(cx, 56, 57, 13, { fill = colors.bandLight, shadow = false })
      local p = self:beginPress(cx, 55, 20, 14); ART({ "..#", ".##", "###", ".##", "..#" }, cx + 6, 60, { ["#"] = colors.ink }); self:endPress(p)
      local n = self:beginPress(cx + 37, 55, 20, 14); ART({ "#..", "##.", "###", "##.", "#.." }, cx + 48, 60, { ["#"] = colors.ink }); self:endPress(n)
      self:partyInfo(model.page .. "/" .. model.pages, cx + 18, 56, colors.green, 21, "center")
    end
    -- rows
    local first = (model.page - 1) * 4 + 1
    local selectedRow
    for visible = 0, 3 do
      local index = first + visible
      local row = model.rows[index]
      if row then
        local y = ROW_Y + visible * ROW_STEP
        local enabled = row.enabled ~= false
        local selected = model.selected ~= nil and rowKey(row) == model.selected
        if selected then selectedRow = row end
        local pressed = self:beginPress(7, y, 226, ROW_H, enabled and not selected)
        self:v4Window(7, y, 226, ROW_H, { radius = 3, shadow = false,
          fill = selected and mix(colors.surface, accent, self.dark and 0.2 or 0.12) or nil })
        if selected then R(8, y + 3, 2, ROW_H - 6, accent) end
        self:endPress(pressed)
        self:partyInfo(self:fitPartyInfo(translate(row.label), 96), 13, y + 5,
          enabled and colors.ink or colors.disabledInk)
        local live = enabled and selected
        if row.action then
          local warn = model.confirm == row.action
          local a = K.rampOf(not live and colors.silverDark or warn and hex("e04838") or accent)
          local bp = self:beginPress(CTRL_X, y + 3, CTRL_W, 16, live)
          local off = self:v4Button(CTRL_X, y + 3, CTRL_W, 16, a, { radius = 4, lip = 3, chamfer = 3 })
          self:partyType(self:fitPartyType(translate(row.value), CTRL_W - 8), CTRL_X + 4, y + 4 + off, WHITE, CTRL_W - 8)
          self:endPress(bp)
        elseif segmentFits(self, row) then
          local action, touched = self:v4SettingsTabbedHit(
            (self.touchX or -1) * 1.5, (self.touchY or -1) * 1.5, model)
          local sp = self:beginPress(CTRL_X, y + 2, CTRL_W, 17,
            live and action == "set" and touched == index)
          self:v4Segments(CTRL_X, y + 2, CTRL_W, row.choices, row.raw, live, accent)
          self:endPress(sp)
        else
          local well = live and mix(colors.surface, accent, self.dark and 0.22 or 0.12) or colors.bandLight
          if cg(self) then CH(CTRL_X, y + 2, CTRL_W, 17, 3, colors.outline); CH(CTRL_X + 1, y + 3, CTRL_W - 2, 15, 2, well)
          else RR(CTRL_X, y + 2, CTRL_W, 17, 4, colors.outline); RR(CTRL_X + 1, y + 3, CTRL_W - 2, 15, 3, well) end
          local ink = live and colors.ink or colors.mutedInk
          local arrows = live and accent or colors.disabledInk
          local lp = self:beginPress(CTRL_X, y + 2, 18, 17, live)
          ART({ "..#", ".##", "###", ".##", "..#" }, CTRL_X + 6, y + 8, { ["#"] = arrows }); self:endPress(lp)
          local rp = self:beginPress(CTRL_X + CTRL_W - 18, y + 2, 18, 17, live)
          ART({ "#..", "##.", "###", "##.", "#.." }, CTRL_X + CTRL_W - 9, y + 8, { ["#"] = arrows }); self:endPress(rp)
          local mp = self:beginPress(CTRL_X + 18, y + 2, CTRL_W - 36, 17, live)
          self:partyInfo(self:fitPartyInfo(translate(row.value or ""), CTRL_W - 40), CTRL_X + 18, y + 5, ink, CTRL_W - 36, "center")
          self:endPress(mp)
        end
      end
    end
    -- help textbox
    self:v4MessageWindow(6, 168, 228, 44)
    local text, key
    if selectedRow then
      text = translate(selectedRow.info or selectedRow.description or "")
      key = tostring(rowKey(selectedRow)) .. ":" .. tostring(selectedRow.raw) .. ":" .. tostring(model.confirm)
    else
      text = translate(model.detail or "")
      key = "cat:" .. tostring(model.tab)
    end
    typewriter(self, text, key, 6, 168, 228, 44)
  end

  function H:v4SettingsTabbedHit(x, y, model)
    if y < 29 and x < 27 then return "back" end
    if y >= TAB_Y and y < TAB_Y + TAB_H then
      local i = floor((x - 7) / TAB_STEP) + 1
      if i >= 1 and i <= #model.tabs and x < 7 + i * TAB_STEP - 2 and i ~= model.tab then return "tab", i end
      return nil
    end
    if model.pages > 1 and y >= 55 and y < 69 then
      if x >= 176 and x < 196 then return "prev" end
      if x >= 213 and x < 233 then return "next" end
      return nil
    end
    local first = (model.page - 1) * 4 + 1
    for visible = 0, 3 do
      local index = first + visible
      local row = model.rows[index]
      local ry = ROW_Y + visible * ROW_STEP
      if row and x >= 7 and x < 233 and y >= ry and y < ry + ROW_H then
        if row.enabled == false then return nil end
        local selected = model.selected ~= nil and rowKey(row) == model.selected
        if not selected then return "select", index end
        if x < CTRL_X or x >= CTRL_X + CTRL_W then return nil end
        if row.action then return "action", index end
        if segmentFits(self, row) then
          local segW = floor(CTRL_W / #row.choices)
          local j = math.min(#row.choices, floor((x - CTRL_X) / segW) + 1)
          if row.choices[j][2] == row.raw then return nil end
          return "set", index, j
        end
        if x < CTRL_X + 18 then return "cycle", index, -1 end
        if x >= CTRL_X + CTRL_W - 18 then return "cycle", index, 1 end
        return "more", index
      end
    end
    return nil
  end

  function H:settingsHit(x, y, model)
    if model and model.tabs and not model.option then return self:v4SettingsTabbedHit(x, y, model) end
    if not (model and model.option) then return base.settingsHit(self, x, y, model) end
    if y < 29 and x < 27 then return "back" end
    if model.pages > 1 and y >= 135 and y < 147 then
      if x >= 72 and x < 104 then return "prev" end
      if x >= 136 and x < 168 then return "next" end
    end
    local top = self:settingsChoiceTop(model)
    local visible = floor((y - top) / 25)
    local index = (model.page - 1) * 4 + visible + 1
    if x >= 7 and x < 233 and visible >= 0 and visible < 4 and y >= top
        and y < top + 22 + visible * 25 and model.choices[index] then return "choice", index end
  end
end
