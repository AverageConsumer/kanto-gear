return function(ART, CH, CIRC, H, K, KEY_G, R, RING, RR, SILPH_LOGO, SILPH_RED, WHITE, cg, floor, hex, max, min, mix, translate, ui)
  local function silphLogo(self, x, y)
    ART(SILPH_LOGO, x, y, { o = SILPH_RED, ["#"] = mix(SILPH_RED, { 0, 0, 0, 1 }, 0.3), w = WHITE })
  end
  H.v4SilphLogo = silphLogo
  local function stateRamp(self, state)
    if state == "soon" then return K.rampOf(self.colors.silverDark) end
    if state == "open" then return K.rampOf(cg(self) and hex("3a8ee8") or hex("3878d0")) end
    return K.rampOf(cg(self) and hex("1ea5d8") or hex("3ea04c"))
  end
  local function keyFace(self, x, y, w, h, label, state, off)
    local glyph = KEY_G[state == "soon" and "soon" or state == "open" and "open" or "get"]
    local text = self:fitPartyType(translate(label), w - 14)
    local tw = self:partyInfoWidth(text)
    local gx = x + floor((w - (#glyph[1] + 3 + tw)) / 2)
    ART(glyph, gx, y + floor((h - 3 - #glyph) / 2) + off, { o = WHITE })
    self:withoutShadow(self.partyType, self, text, gx + #glyph[1] + 3, y + floor((h - 3 - 9) / 2) - 1 + off, WHITE, tw)
  end
  function H:storeAction(x, y, w, label, state)
    local pressed = self:beginPress(x, y, w, 15, state ~= "soon")
    local off = self:v4Button(x, y, w, 15, stateRamp(self, state), { radius = 2, lip = 3, chamfer = 2 })
    keyFace(self, x, y + 1, w, 15, label, state, off)
    self:endPress(pressed)
  end
  function H:storeMiniAction(x, y, w, label, state, enabled)
    local pressed = self:beginPress(x, y, w, 11, enabled == true or state ~= "soon")
    local off = self:v4Button(x, y, w, 11, stateRamp(self, state), { radius = 2, lip = 2, chamfer = 2 })
    local text = self:fitPartyType(translate(label), w - 4)
    self:withoutShadow(self.partyType, self, text, x + 1, y - 1 + off, WHITE, w - 2)
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
  local function storeIcon(self, app, icons, x, y, size, seat)
    local icon = icons and icons[app.icon or app.id]
    local id = K.iconId and K.iconId(icon)
    if seat and not (cg(self) and id and K.GLYPH[id]) then
      -- round tinted seat behind the drawn icon
      local accent = self:v4AppAccent(id) or self.tok.acc.M
      local d = size + 4
      CIRC(x - 2, y - 2, d, self.colors.outline)
      CIRC(x - 1, y - 1, d - 2, mix(self.colors.surface, accent, self.dark and 0.3 or 0.2))
      K.CIRCrows(x - 1, y - 1, d - 2, floor(d / 2), d - 2, mix(self.colors.surface, accent, self.dark and 0.42 or 0.32))
    end
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
    local accent = self:v4AppAccent(K.iconId and K.iconId(icons[app.icon or app.id])) or self.tok.acc.M
    self:v4Window(x, y, w, 42, { radius = 4 })
    -- the Game Pak label: an accent panel holding the icon
    local lab = mix(colors.surface, accent, self.dark and 0.28 or 0.18)
    if cg(self) then CH(x + 3, y + 3, 30, 36, 2, mix(lab, colors.outline, 0.25)); CH(x + 4, y + 4, 28, 34, 1, lab)
    else RR(x + 3, y + 3, 30, 36, 2, mix(lab, colors.outline, 0.25)); RR(x + 4, y + 4, 28, 34, 1, lab) end
    R(x + 5, y + 5, 26, 1, mix(lab, WHITE, 0.5))
    storeIcon(self, app, icons, x + 5, y + 8, 26, false)
    local tw = w - 39
    self:partyInfo(self:fitPartyInfo(translate(app.label), tw), x + 37, y + 3, colors.ink)
    if app.new then
      self:storeNewBadge(x + 37, y + 15, 25)
    else
      self:partyInfo(self:fitPartyInfo(translate(app.category), tw), x + 37, y + 14, colors.mutedInk)
    end
    self:storeMiniAction(x + 36, y + 28, 43, app.action or (app.state == "open" and "OPEN APP" or "GET"), app.state)
    self:endPress(pressed)
  end
  H.v4StoreIcon = storeIcon

  -- App page: a product card like the DS Pokétch app list — accent band,
  -- round seat, name + NEW, category pill, publisher mark, lipped action.
  local SILPH = { "..o..", ".o#o.", "o###o", ".o#o.", "..o.." }
  function H:storeDetail(model)
    local colors = self.colors
    local icons = self.homeIconTable and self:homeIconTable() or {}
    local app = model.app or {}
    local id = K.iconId and K.iconId(icons[app.icon or app.id])
    local accent = self:v4AppAccent(id) or self.tok.acc.M
    local enter = self:v4Enter("store_detail", tostring(app.id), 0.22)
    local G = ui.graphics
    local lift = enter < 1 and floor((1 - K.easeOut(enter)) * 8 + 0.5) or 0
    self:v4Window(7, 32, 226, 54, { radius = 5 })
    R(9, 34, 222, 3, accent)
    if cg(self) and id and K.GLYPH and K.GLYPH[id] then
      storeIcon(self, app, icons, 11, 40, 41)
    else
      CIRC(11, 40, 41, colors.outline)
      CIRC(12, 41, 39, mix(colors.surface, accent, self.dark and 0.3 or 0.2))
      K.CIRCrows(12, 41, 39, 20, 39, mix(colors.surface, accent, self.dark and 0.42 or 0.32))
      R(20, 44, 8, 1, { 1, 1, 1, self.dark and 0.2 or 0.65 })
      storeIcon(self, app, icons, 17, 46, 29)
    end
    local name = self:fitPartyInfo(translate(app.label or "APP"), app.new and 76 or 106)
    self:partyName(name, 57, 39, colors.ink, 106)
    if app.new then self:storeNewBadge(57 + self:partyInfoWidth(name) + 4, 41, 25) end
    self:v4Pill(translate(app.category or "UTILITY"), 57, 55, accent, { raw = true, maxW = 106 })
    ART(SILPH, 57, 70, { o = colors.outline, ["#"] = hex("e04838") })
    self:partyInfo(self:fitPartyInfo(translate(app.publisher or "SILPH CO."), 98), 65, 67, colors.mutedInk)
    self:storeAction(171, 41, 51, app.action or "GET", app.state)
    if app.removable then self:storeMiniAction(175, 61, 43, "REMOVE", "soon", true) end
    -- preview keeps the base mock (its contents are laid out for this rect)
    if lift ~= 0 then G.push(); G.translate(0, lift) end
    self:storePreview(app, 7, 90, 226, 74, false)
    -- description in the message window
    local lines = app.description or {}
    self:v4MessageWindow(7, 168, 226, 40)
    local n = min(3, #lines)
    local top = 168 + floor((40 - (n * 10)) / 2) - 1
    self:v4Prose(function()
      for index = 1, n do
        self:partyInfo(self:fitPartyInfo(translate(lines[index]), 206), 17, top + (index - 1) * 10, colors.ink, 206, "center")
      end
    end)
    if lift ~= 0 then G.pop() end
  end

  -- Small party previews show the team as seats + HP, never cut names.
  local basePreview = H.storePreview
  function H:storePreview(app, x, y, w, h, interactive)
    app = type(app) == "table" and app or { id = app }
    if app.id ~= "party" or w >= 180 then return basePreview(self, app, x, y, w, h, interactive) end
    local colors = self.colors
    local preview = app.preview or {}
    local pressed = self:beginPress(x, y, w, h, interactive ~= false)
    self:v4Window(x, y, w, h, { radius = 4, fill = mix(colors.surface, colors.party, self.dark and 0.18 or 0.1) })
    local cw = floor((w - 8) / 3)
    for index = 0, 5 do
      local col, row = index % 3, floor(index / 3)
      local cx = x + 4 + col * cw + floor((cw - 22) / 2)
      local cy = y + 4 + row * floor((h - 6) / 2)
      CIRC(cx, cy, 22, colors.outline)
      CIRC(cx + 1, cy + 1, 20, mix(colors.surface, colors.party, self.dark and 0.3 or 0.2))
      local mon = preview.party and preview.party[index + 1]
      if mon and preview.drawPokemon then preview.drawPokemon(mon, cx + 2, cy + 1, 18)
      else self:battleTeamBall(cx + 11, cy + 11, mon ~= false) end
      local ratio = mon and tonumber(mon.hpRatio) or mon and (tonumber(mon.hp) or 0) / max(1, tonumber(mon.maxHp) or 1)
        or (index == 4 and 0 or index == 5 and 0.32 or 0.82)
      ratio = max(0, min(1, ratio))
      R(cx - 1, cy + 23, 24, 4, colors.outline)
      R(cx, cy + 24, 22, 2, self.dark and hex("26303c") or hex("dfe3db"))
      R(cx, cy + 24, floor(22 * ratio), 2, ratio == 0 and colors.mutedInk or ratio < 0.5 and colors.hpMid or colors.hp)
    end
    self:endPress(pressed)
  end

  -- Silph Store, touch only: the catalog is the start screen. Three tabs
  -- (BUY / MY GEAR / NEWS) sit on top; every action is a big key in the
  -- thumb zone; message windows are read-only speech, never "tap to go on".
  local STORE_TAB_G = {
    { "ooooooo", "o.o.o.o", "ooooooo", "o.....o", "o.ooo.o", "o.o.o.o", "ooooooo" },
    { ".ooooo.", "o.....o", "o.ooo.o", "o.ooo.o", "o.....o", "o.o.o.o", ".ooooo." },
    { "ooooooo", "o.....o", "o.ooo.o", "o.....o", "o.ooo.o", "o.....o", "ooooooo" },
  }
  local STORE_TABS = { "BUY", "MY GEAR", "NEWS" }
  local CHECK_G = { "......o", ".....oo", "o...oo.", "oo.oo..", ".ooo...", "..o...." }
  local HOME_G = { "...o...", "..ooo..", ".ooooo.", "ooooooo", ".o...o.", ".o.o.o.", ".ooooo." }
  local function tabAccent(index)
    return index == 1 and SILPH_RED or index == 2 and hex("3878d0") or hex("e09a20")
  end
  local function getAccent(self) return cg(self) and hex("1ea5d8") or hex("3ea04c") end
  local function openAccent(self) return cg(self) and hex("3a8ee8") or hex("3878d0") end

  -- A DS key: lit keys carry their colour, quiet keys are plain caps, a
  -- disabled key keeps its place but greys out and ignores presses.
  local function storeKey(self, x, y, w, h, label, accent, glyph, lit, enabled)
    enabled = enabled ~= false
    local colors = self.colors
    local pressed = self:beginPress(x, y, w, h, enabled)
    local off = 0
    if lit and enabled then
      off = self:v4Button(x, y, w, h, K.rampOf(accent), { radius = 4, lip = 3, chamfer = 3 })
    else
      self:v4Key(x, y, w, h)
    end
    local text = self:fitPartyInfo(translate(label), w - (glyph and 16 or 8))
    local lw = self:partyInfoWidth(text)
    local gw = glyph and #glyph[1] + 4 or 0
    local gx = x + floor((w - lw - gw) / 2)
    local ty = y + floor((h - 3 - 9) / 2) - 1 + off
    local ink = lit and enabled and WHITE or enabled and colors.ink or colors.mutedInk
    if glyph then
      ART(glyph, gx, y + floor((h - 3 - #glyph) / 2) + off,
        { o = lit and enabled and WHITE or enabled and accent or colors.mutedInk })
    end
    if lit and enabled then self:withoutShadow(self.partyInfo, self, text, gx + gw, ty, WHITE)
    else self:partyInfo(text, gx + gw, ty, ink) end
    self:endPress(pressed)
  end
  H.v4StoreKey = storeKey

  local function wrapStore(self, text, width, maxLines)
    local lines, current = {}, ""
    for word in tostring(text or ""):gmatch("%S+") do
      local try = current == "" and word or current .. " " .. word
      if self:partyInfoWidth(try) <= width or current == "" then current = try
      else lines[#lines + 1] = current; current = word end
    end
    if current ~= "" then lines[#lines + 1] = current end
    while #lines > maxLines do table.remove(lines) end
    return lines
  end

  H.STORE_TAB_Y, H.STORE_TAB_H = 32, 22
  function H.storeTabRect(index)
    return 7 + (index - 1) * 77, H.STORE_TAB_Y, 72, H.STORE_TAB_H
  end
  function H:storeTabs(active, enabled)
    for index, label in ipairs(STORE_TABS) do
      local x, y, w, h = H.storeTabRect(index)
      storeKey(self, x, y, w, h, label, tabAccent(index), STORE_TAB_G[index],
        index == active, enabled ~= false and index ~= active or index == active)
    end
  end

  -- Read-only speech: the store's message window, up to `n` lines.
  -- Each line reads as its own sentence; app names keep their capitals.
  local function storeSpeech(self, lines, y, h, names)
    self:v4MessageWindow(6, y, 228, h)
    local n = #lines
    local top = y + floor((h - n * 12) / 2) - 1
    for index, line in ipairs(lines) do
      self:v4Prose(function()
        self:partyInfo(self:fitPartyInfo(line, 208), 16, top + (index - 1) * 12, self.colors.ink)
      end, names)
    end
  end

  local function priceOf(self, app)
    if app.state == "soon" then return "SOON", self.colors.mutedInk end
    if app.state == "open" then return "OWNED", self.colors.mutedInk end
    return "FREE", cg(self) and self.tok.acc.M or self.colors.green
  end

  -- BUY: the catalog list on the left, the picked Game Pak with its one
  -- key on the right, its description in the message window below.
  H.STORE_ROWS, H.STORE_ROW_Y, H.STORE_ROW_STEP = 4, 62, 25
  function H:storeScrollGeometry(page, pages)
    local height = max(10, floor(98 / pages))
    return 150, 62, 11, 98, 62 + floor((98 - height) * (page - 1) / max(1, pages - 1)), height
  end
  function H:storeScrollPage(y, pages, grab)
    if pages <= 1 then return 1 end
    local _, top, _, height, _, thumb = self:storeScrollGeometry(1, pages)
    local ratio = (y - top - (grab or thumb / 2)) / (height - thumb)
    return max(1, min(pages, floor(ratio * (pages - 1) + 0.5) + 1))
  end
  function H:storeScrollHit(x, y, pages)
    return pages > 1 and x >= 150 and x < 161 and y >= 58 and y < 164
  end
  function H:storeBuy(model)
    local colors = self.colors
    local icons = self.homeIconTable and self:homeIconTable() or {}
    local G = ui.graphics
    local apps, selected = model.apps or {}, model.selected or {}
    local overlay = model.confirm ~= nil
    self:storeTabs(1, not overlay)
    self:v4Window(7, 58, 152, 106, { radius = 4 })
    local paged = (tonumber(model.pages) or 1) > 1
    local rowW = paged and 140 or 146
    local enter = self:v4Enter("store_buy", tostring(model.page), 0.24)
    for index, app in ipairs(apps) do
      local y = H.STORE_ROW_Y + (index - 1) * H.STORE_ROW_STEP
      local _, dy = self:v4Stagger(enter, index, 0.06, 6, #apps)
      if dy ~= 0 then G.push(); G.translate(0, dy) end
      local sel = app.id == selected.id
      local pressed = self:beginPress(9, y - 1, rowW, 24, not overlay and not sel)
      if sel then
        R(9, y - 1, rowW, 24, mix(colors.surface, SILPH_RED, self.dark and 0.22 or 0.12))
        R(9, y - 1, 3, 24, SILPH_RED)
      end
      storeIcon(self, app, icons, 17, y - 1, 24, false)
      local price, pcol = priceOf(self, app)
      price = translate(price)
      local pw = self:partyInfoWidth(price)
      local right = 9 + rowW - 4
      self:partyInfo(self:fitPartyInfo(translate(app.label), right - pw - 6 - 44), 44, y + 5, colors.ink)
      self:partyInfo(price, right - pw, y + 5, pcol)
      if index < #apps then R(16, y + 23, rowW - 10, 1, colors.band) end
      self:endPress(pressed)
      if dy ~= 0 then G.pop() end
    end
    if paged then
      -- a page rail: the thumb shows where this page sits in the catalog
      local x, y, _, height, thumbY, thumbH = self:storeScrollGeometry(tonumber(model.page) or 1, tonumber(model.pages))
      R(x + 2, y, 4, height, colors.bandLight)
      R(x + 2, thumbY, 4, thumbH, mix(colors.surface, SILPH_RED, 0.75))
    end
    -- the picked Game Pak
    local id = K.iconId and K.iconId(icons[selected.icon or selected.id])
    local accent = self:v4AppAccent(id) or self.tok.acc.M
    self:v4Window(163, 58, 70, 106, { radius = 4 })
    local lab = mix(colors.surface, accent, self.dark and 0.28 or 0.18)
    local pop = self:v4Enter("store_pick", tostring(selected.id), 0.18)
    local lift = pop < 1 and floor((1 - K.easeOut(pop)) * 4 + 0.5) or 0
    R(168, 63, 60, 46, mix(lab, colors.outline, 0.3)); R(169, 64, 58, 44, lab)
    R(170, 65, 56, 1, mix(lab, WHITE, 0.5))
    if selected.id then storeIcon(self, selected, icons, 182, 67 + lift, 32, true) end
    if selected.new and selected.state == "get" then self:storeNewBadge(170, 66, 25) end
    local cat = self:fitPartyType(translate(selected.category or "APP"), 54)
    self:v4Pill(cat, 198 - floor((self:partyInfoWidth(cat) + 9) / 2), 113, accent, { raw = true })
    local state = selected.state
    local label = selected.action or (state == "soon" and "SOON" or state == "open" and "OPEN APP" or "GET")
    storeKey(self, 167, 126, 62, 32, label,
      state == "open" and openAccent(self) or getAccent(self),
      state == "soon" and KEY_G.soon or state == "open" and KEY_G.open or KEY_G.get,
      true, not overlay and state ~= "soon")
    -- what it does, as speech
    local lines = {}
    for index = 1, 2 do
      local line = selected.description and selected.description[index]
      if line then lines[#lines + 1] = translate(line) end
    end
    if overlay then
      R(0, 29, 240, 187, { 0, 0, 0, self.dark and 0.45 or 0.32 })
      local p = self:v4Enter("store_confirm", tostring(model.confirmKind) .. tostring(selected.id), 0.16)
      local rise = p < 1 and floor((1 - K.easeOut(p)) * 10 + 0.5) or 0
      if rise ~= 0 then G.push(); G.translate(0, rise) end
      if model.confirmKind == "remove" then
        storeSpeech(self, { translate(selected.label or ""), translate("REMOVE IT FROM YOUR GEAR?") }, 127, 38,
        { translate(selected.label or "") })
      else
        storeSpeech(self, { translate("FREE FOR TRAINERS."), translate("INSTALL IT ON YOUR GEAR?") }, 127, 38)
      end
      storeKey(self, 7, 170, 110, 36, "YES", getAccent(self), CHECK_G, true)
      storeKey(self, 123, 170, 110, 36, "NO", colors.silverDark, nil, false)
      if rise ~= 0 then G.pop() end
    else
      storeSpeech(self, lines, 168, 44)
    end
  end

  -- Received: an item-get fanfare for the new app, then OPEN NOW / NOT NOW.
  function H:storeReceived(model)
    local colors = self.colors
    local icons = self.homeIconTable and self:homeIconTable() or {}
    local app = model.app or {}
    local id = K.iconId and K.iconId(icons[app.icon or app.id])
    local accent = self:v4AppAccent(id) or self.tok.acc.M
    local a = K.rampOf(accent)
    self:v4Window(7, 32, 226, 132, { radius = 5 })
    local p = self:v4Enter("store_received", tostring(app.id), 0.42)
    local motion = not self:v4MotionOff()
    local spin = motion and self:clock() * 0.5 or 0.4
    if motion then self:wantAmbient(1 / 20, 1 / 20) end
    local grow = K.easeOut(min(1, p * 1.6))
    for i = 0, 11 do
      local ang = i / 12 * math.pi * 2 + spin
      for r = 34, floor(34 + 24 * grow), 2 do
        R(floor(120 + math.cos(ang) * r), floor(92 + math.sin(ang) * r * 0.8), 2, 2,
          mix(colors.surface, accent, 0.35 * (1 - (r - 34) / 26)))
      end
    end
    local pop = p < 1 and K.easeBack(min(1, p * 1.3)) or 1
    local d = max(8, floor(62 * pop / 2) * 2)
    local cx, cy = 120 - d / 2, 92 - d / 2
    CIRC(cx, cy, d, colors.outline)
    CIRC(cx + 1, cy + 1, d - 2, a.L)
    if d > 14 then CIRC(cx + 6, cy + 6, d - 12, mix(colors.surface, accent, 0.2)) end
    if p >= 0.55 then storeIcon(self, app, icons, 100, 72, 40, false) end
    local star = hex("f8d048")
    local twinkle = motion and floor(self:clock() / 0.3) % 2 == 0
    ART({ "..o..", ".ooo.", "ooooo", ".ooo.", "..o.." }, 150, 62, { o = star })
    if not twinkle then ART({ "..o..", ".ooo.", "..o.." }, 86, 112, { o = star }) end
    self:partyInfo(translate(app.label or ""), 7, 132, colors.ink, 226, "center")
    self:partyInfo(translate("INSTALLED ON YOUR GEAR"), 7, 145, accent, 226, "center")
    storeKey(self, 7, 170, 110, 36, app.state == "soon" and app.action or "OPEN NOW",
      app.state == "soon" and colors.silverDark or openAccent(self), KEY_G.open, true, app.state ~= "soon")
    storeKey(self, 123, 170, 110, 36, "NOT NOW", colors.silverDark, nil, false)
  end

  -- MY GEAR: the Game Paks on your Gear as a 4x3 box; the picked one gets
  -- the three keys underneath.
  H.STORE_SLOT_COLS, H.STORE_SLOT_ROWS = 4, 3
  function H.storeSlotRect(index)
    local col, row = (index - 1) % 4, floor((index - 1) / 4)
    return 7 + col * 57, 58 + row * 38, 53, 36
  end
  function H:storeGear(model)
    local colors = self.colors
    local icons = self.homeIconTable and self:homeIconTable() or {}
    local G = ui.graphics
    local apps, selected = model.apps or {}, model.selected or {}
    local overlay = model.confirm ~= nil
    self:storeTabs(2, not overlay)
    local enter = self:v4Enter("store_gear", tostring(model.page), 0.24)
    for index = 1, 12 do
      local x, y, w, h = H.storeSlotRect(index)
      local app = apps[index]
      if app then
        local _, dy = self:v4Stagger(enter, index, 0.03, 6, #apps)
        if dy ~= 0 then G.push(); G.translate(0, dy) end
        local id = K.iconId and K.iconId(icons[app.icon or app.id])
        local accent = self:v4AppAccent(id) or self.tok.acc.M
        local sel = app.id == selected.id
        local pressed = self:beginPress(x, y, w, h, not overlay and not sel)
        if sel then
          -- the picked pak: an accent ring around a tinted slot
          local shape = cg(self) and CH or RR
          shape(x, y, w, h, cg(self) and 3 or 4, K.rampOf(accent).M)
          shape(x + 2, y + 2, w - 4, h - 4, cg(self) and 2 or 3,
            mix(colors.surface, accent, self.dark and 0.24 or 0.14))
        else
          self:v4Window(x, y, w, h, { radius = 4 })
        end
        storeIcon(self, app, icons, x + 15, y + 2, 22, false)
        self:partyInfo(self:fitPartyInfo(translate(app.label), w - 6), x + 3, y + 25, colors.ink, w - 6, "center")
        self:endPress(pressed)
        if dy ~= 0 then G.pop() end
      else
        self:v4Window(x, y, w, h, { radius = 4, fill = colors.bandLight })
      end
    end
    local onHome = model.onHome == true
    storeKey(self, 7, 174, 72, 34, "OPEN APP", openAccent(self), KEY_G.open, true, not overlay and selected.id ~= nil)
    storeKey(self, 84, 174, 72, 34, onHome and "ON HOME" or "TO HOME", getAccent(self), HOME_G,
      not onHome, not overlay and not onHome and model.canPlace == true)
    storeKey(self, 161, 174, 72, 34, "REMOVE", colors.silverDark, nil, false,
      not overlay and selected.removable == true)
    if overlay then
      R(0, 29, 240, 187, { 0, 0, 0, self.dark and 0.45 or 0.32 })
      local p = self:v4Enter("store_confirm", "remove" .. tostring(selected.id), 0.16)
      local rise = p < 1 and floor((1 - K.easeOut(p)) * 10 + 0.5) or 0
      if rise ~= 0 then G.push(); G.translate(0, rise) end
      storeSpeech(self, { translate(selected.label or ""), translate("REMOVE IT FROM YOUR GEAR?") }, 127, 38,
        { translate(selected.label or "") })
      storeKey(self, 7, 170, 110, 36, "YES", getAccent(self), CHECK_G, true)
      storeKey(self, 123, 170, 110, 36, "NO", colors.silverDark, nil, false)
      if rise ~= 0 then G.pop() end
    end
  end

  -- NEWS: Silph's cork board. Every note is a tap target that jumps to
  -- the app in BUY; the keys on the notes only label that.
  local PIN_G = { ".ooo.", "o###o", ".ooo.", "..o.." }
  H.STORE_NOTES = { { 14, 66, 140, 64 }, { 124, 132, 102, 70 }, { 16, 138, 100, 64 } }
  function H:storeNews(model)
    local colors = self.colors
    local icons = self.homeIconTable and self:homeIconTable() or {}
    local INK, MUTED = hex("2a3440"), hex("6a7480")
    self:storeTabs(3)
    local cork = self.dark and hex("5a4430") or hex("d8b080")
    self:v4Window(7, 58, 226, 150, { radius = 5 })
    R(9, 60, 222, 146, cork)
    for i = 0, 40 do R(9 + (i * 37) % 220, 62 + (i * 53) % 142, 1, 1, mix(cork, colors.outline, 0.25)) end
    local function note(x, y, w, h, tint, pin, interactive)
      local pressed = interactive and self:beginPress(x, y, w, h)
      R(x + 2, y + 2, w, h, { 0, 0, 0, 0.18 })
      R(x, y, w, h, colors.outline); R(x + 1, y + 1, w - 2, h - 2, tint)
      ART(PIN_G, x + floor(w / 2) - 2, y - 2, { o = colors.outline, ["#"] = pin })
      return pressed
    end
    local function line(text, x, y, col, w) self:withoutShadow(self.partyInfo, self, self:fitPartyInfo(translate(text), w), x, y, col) end
    local function chip(x, y, w, label, accent)
      self:v4Button(x, y, w, 16, K.rampOf(accent), { radius = 3, lip = 2, chamfer = 2 })
      local text = self:fitPartyInfo(translate(label), w - 6)
      self:withoutShadow(self.partyInfo, self, text, x + floor((w - self:partyInfoWidth(text)) / 2), y + 1, WHITE)
    end
    local featured, pick, second = model.featured or {}, model.pick or {}, model.second or {}
    -- headline: what's new at Silph
    local n = H.STORE_NOTES[1]
    local pressed = note(n[1], n[2], n[3], n[4], hex("fbfaf2"), SILPH_RED, true)
    ART(SILPH_LOGO, 20, 71, { o = SILPH_RED, ["#"] = mix(SILPH_RED, { 0, 0, 0, 1 }, 0.3), w = WHITE })
    line("NEW AT SILPH", 32, 70, SILPH_RED, 116)
    storeIcon(self, featured, icons, 20, 86, 32, true)
    line(featured.label or "", 58, 85, INK, 92)
    line(featured.reason or featured.category or "", 58, 97, MUTED, 92)
    chip(58, 110, 88, featured.state == "open" and "OPEN APP" or "TAKE A LOOK", SILPH_RED)
    self:endPress(pressed)
    -- a standing tip
    note(160, 70, 66, 56, hex("f8f0b8"), hex("3878d0"), false)
    line("TIP", 166, 73, hex("8a6a10"), 54)
    self:v4Prose(function()
      for index, text in ipairs(wrapStore(self, translate("HOLD AN APP ON HOME TO MOVE IT."), 56, 4)) do
        self:withoutShadow(self.partyInfo, self, text, 166, 74 + index * 10, INK)
      end
    end)
    -- staff pick
    n = H.STORE_NOTES[2]
    pressed = note(n[1], n[2], n[3], n[4], hex("fbfaf2"), hex("e09a20"), true)
    line("STAFF PICK", 130, 136, hex("b07010"), 90)
    storeIcon(self, pick, icons, 132, 150, 28, true)
    line(pick.label or "", 166, 152, INK, 56)
    local price, pcol = priceOf(self, pick)
    line(price, 166, 164, pick.state == "get" and hex("3a9048") or MUTED, 56)
    chip(130, 182, 90, "VIEW", hex("e09a20"))
    self:endPress(pressed)
    -- second pick
    n = H.STORE_NOTES[3]
    pressed = note(n[1], n[2], n[3], n[4], hex("e0f0e8"), hex("3ea04c"), true)
    storeIcon(self, second, icons, 22, 144, 24, true)
    line(second.label or "", 50, 150, INK, 62)
    self:v4Prose(function()
      for index, text in ipairs(wrapStore(self, translate(second.description and second.description[1] or ""), 88, 2)) do
        self:withoutShadow(self.partyInfo, self, text, 22, 164 + index * 11, MUTED)
      end
    end)
    self:endPress(pressed)
  end

  -- Touch geometry for every store screen; drawing above uses the same rects.
  function H:storeHit(x, y, view, model)
    model = model or {}
    local function inside(left, top, width, height)
      return x >= left and x < left + width and y >= top and y < top + height
    end
    if view == "received" then
      if model.openEnabled ~= false and inside(7, 170, 110, 36) then return "open" end
      if inside(123, 170, 110, 36) then return "later" end
      return nil
    end
    if model.confirm then
      if inside(7, 170, 110, 36) then return "yes" end
      if inside(123, 170, 110, 36) then return "no" end
      return nil
    end
    if y < 29 and x >= 27 and x < 50 then return "prev" end
    if y < 29 and x >= 116 and x < 139 then return "next" end
    for index = 1, 3 do
      if inside(H.storeTabRect(index)) then return "tab", index end
    end
    if view == "apps" then
      local paged = (tonumber(model.pages) or 1) > 1
      if paged and self:storeScrollHit(x, y, model.pages) then
        return "scroll", self:storeScrollPage(y, model.pages)
      end
      for index = 1, H.STORE_ROWS do
        local top = H.STORE_ROW_Y + (index - 1) * H.STORE_ROW_STEP - 1
        if inside(9, top, paged and 140 or 146, 24) then return "row", index end
      end
      if inside(167, 126, 62, 32) then return "action" end
      return nil
    end
    if view == "library" then
      for index = 1, 12 do
        if inside(H.storeSlotRect(index)) then return "slot", index end
      end
      if inside(7, 174, 72, 34) then return "open" end
      if inside(84, 174, 72, 34) then return "home" end
      if inside(161, 174, 72, 34) then return "remove" end
      return nil
    end
    for index, n in ipairs(H.STORE_NOTES) do
      if inside(n[1], n[2], n[3], n[4]) then return "note", index end
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
  CAT_GLYPH.DISCOVERY = CAT_GLYPH.RESEARCH
  return CAT_GLYPH
end
