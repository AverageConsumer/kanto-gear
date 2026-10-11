-- Kanto Gear v4: Home, app buttons, widgets and the C-Gear glyph icon set.
return function(H, ui, K)
  local floor, max, min = math.floor, math.max, math.min
  local R, P, RR, RRrows, CH, CHrows = K.R, K.P, K.RR, K.RRrows, K.CH, K.CHrows
  local CIRC, CIRCrows, RING, ART = K.CIRC, K.CIRCrows, K.RING, K.ART
  local mix, hex, setc = K.mix, K.hex, K.setc
  local base, cg, WHITE = K.base, K.cg, K.WHITE
  local translate = function(value)
    return ui.translate and ui.translate(value) or value
  end

  ---------------------------------------------------------------------------
  -- Icon identity: hgss.lua hands homeAppButton an icon object; its bounds
  -- identify which app it is. Unknown icons simply keep their own drawing.
  ---------------------------------------------------------------------------
  local SIGNATURES = {
    ["1,1,24,25"] = "bag", ["2,1,24,25"] = "pokedex", ["1,3,25,24"] = "trainer",
    ["2,3,25,24"] = "steps", ["1,1,26,27"] = "achievements", ["2,3,26,22"] = "party",
    ["1,1,26,26"] = "tools", ["1,1,25,25"] = "explorer", ["2,2,24,25"] = "map",
    ["1,5,25,24"] = "store", ["2,1,23,26"] = "notes", ["2,2,24,24"] = "pss",
    ["2,1,26,26"] = "settings",
  }
  local function iconId(icon)
    if type(icon) ~= "table" then return nil end
    return SIGNATURES[table.concat({ icon.left or 0, icon.top or 0,
      icon.right or 0, icon.bottom or 0 }, ",")]
  end
  K.iconId = iconId

  ---------------------------------------------------------------------------
  -- C-Gear glyphs: flat 2-tone line icons on a 20×20 grid.
  ---------------------------------------------------------------------------
  local GLYPH = {}
  GLYPH.map = function(x, y, c, d)
    -- tri-fold map with a location pin
    for i = 0, 2 do
      local px = x + 1 + i * 6
      R(px, y + 4 + (i % 2 == 1 and -1 or 0), 1, 13, c)
      R(px + 6, y + 3 + (i % 2 == 1 and 0 or -1), 1, 13, c)
    end
    for i = 0, 5 do P(x + 1 + i, y + 4 - floor(i / 2), c); P(x + 7 + i, y + 2 + floor(i / 2), c); P(x + 13 + i, y + 4 - floor(i / 2), c) end
    for i = 0, 5 do P(x + 1 + i, y + 17 - floor(i / 2), c); P(x + 7 + i, y + 15 + floor(i / 2), c); P(x + 13 + i, y + 17 - floor(i / 2), c) end
    CIRC(x + 8, y + 5, 5, d); P(x + 10, y + 7, c); R(x + 10, y + 10, 1, 3, d)
  end
  GLYPH.tools = function(x, y, c, d)
    RING(x + 3, y + 3, 14, 2, c)
    R(x + 9, y, 2, 4, c); R(x + 9, y + 16, 2, 4, c); R(x, y + 9, 4, 2, c); R(x + 16, y + 9, 4, 2, c)
    R(x + 3, y + 3, 2, 2, c); R(x + 15, y + 3, 2, 2, c); R(x + 3, y + 15, 2, 2, c); R(x + 15, y + 15, 2, 2, c)
    CIRC(x + 7, y + 7, 6, d)
  end
  GLYPH.settings = function(x, y, c, d)
    for i, k in ipairs({ 12, 4, 9 }) do
      local yy = y + 2 + (i - 1) * 7
      R(x + 1, yy + 2, 18, 1, d)
      R(x + k, yy, 4, 5, c)
    end
  end
  GLYPH.store = function(x, y, c, d)
    R(x + 1, y + 2, 18, 1, c)
    for i = 0, 5 do R(x + 1 + i * 3, y + 3, 1, 4, c); P(x + 2 + i * 3, y + 6, c) end
    R(x + 19, y + 3, 1, 4, c)
    R(x + 2, y + 7, 1, 11, c); R(x + 17, y + 7, 1, 11, c); R(x + 1, y + 18, 18, 1, c)
    R(x + 5, y + 11, 4, 7, d); R(x + 11, y + 10, 4, 4, d)
  end
  GLYPH.bag = function(x, y, c, d)
    R(x + 7, y + 1, 6, 1, c); R(x + 6, y + 2, 1, 3, c); R(x + 13, y + 2, 1, 3, c)
    R(x + 3, y + 5, 14, 1, c); R(x + 2, y + 6, 1, 12, c); R(x + 17, y + 6, 1, 12, c); R(x + 3, y + 18, 14, 1, c)
    R(x + 3, y + 10, 14, 1, d); R(x + 8, y + 9, 4, 3, c)
    R(x + 6, y + 13, 8, 1, d); R(x + 6, y + 13, 1, 3, d); R(x + 13, y + 13, 1, 3, d)
  end
  GLYPH.pokedex = function(x, y, c, d)
    R(x + 3, y + 1, 14, 1, c); R(x + 3, y + 18, 14, 1, c); R(x + 2, y + 2, 1, 16, c); R(x + 17, y + 2, 1, 16, c)
    R(x + 5, y + 4, 10, 7, d); R(x + 6, y + 5, 8, 5, c)
    CIRC(x + 5, y + 13, 4, c); R(x + 11, y + 14, 4, 1, d); R(x + 11, y + 16, 3, 1, d)
  end
  GLYPH.trainer = function(x, y, c, d)
    RING(x + 6, y + 1, 8, 1, c)
    R(x + 5, y + 2, 10, 2, d)
    R(x + 3, y + 12, 14, 1, c); R(x + 2, y + 13, 1, 6, c); R(x + 17, y + 13, 1, 6, c)
    R(x + 4, y + 11, 12, 1, c); R(x + 9, y + 13, 2, 6, d)
  end
  GLYPH.steps = function(x, y, c, d)
    RR(x + 2, y + 2, 6, 9, 2, c); RR(x + 3, y + 12, 4, 3, 1, c)
    RR(x + 11, y + 6, 6, 9, 2, d); RR(x + 12, y + 16, 4, 3, 1, d)
  end
  GLYPH.achievements = function(x, y, c, d)
    RING(x + 3, y + 1, 14, 2, c)
    CIRC(x + 7, y + 5, 6, d)
    R(x + 4, y + 13, 3, 6, c); R(x + 13, y + 13, 3, 6, c)
    P(x + 5, y + 19, c); P(x + 14, y + 19, c)
  end
  GLYPH.party = function(x, y, c, d)
    for _, p in ipairs({ { 6, 1 }, { 1, 10 }, { 11, 10 } }) do
      RING(x + p[1], y + p[2], 9, 1, c)
      R(x + p[1], y + p[2] + 4, 9, 1, c)
      P(x + p[1] + 4, y + p[2] + 4, d)
    end
  end
  GLYPH.explorer = function(x, y, c, d)
    RING(x + 1, y + 1, 18, 2, c)
    for i = 0, 4 do R(x + 10 - floor(i / 2), y + 5 + i, 1 + floor(i / 2) * 2, 1, d) end
    for i = 0, 4 do R(x + 10 - floor((4 - i) / 2), y + 10 + i, 1 + floor((4 - i) / 2) * 2, 1, c) end
  end
  GLYPH.notes = function(x, y, c, d)
    R(x + 3, y + 1, 11, 1, c); R(x + 3, y + 18, 14, 1, c); R(x + 3, y + 1, 1, 18, c); R(x + 16, y + 5, 1, 14, c)
    for i = 0, 3 do P(x + 13 + i, y + 1 + i, c) end
    for i = 0, 3 do R(x + 6, y + 6 + i * 3, 8, 1, d) end
  end
  GLYPH.pss = function(x, y, c, d)
    R(x + 9, y + 5, 2, 10, d); R(x + 4, y + 13, 12, 2, d)
    for _, p in ipairs({ { 7, 1 }, { 1, 12 }, { 13, 12 } }) do RR(x + p[1], y + p[2], 6, 6, 2, c) end
  end
  K.GLYPH = GLYPH
  function H:v4Glyph(id, x, y, c, d)
    local glyph = GLYPH[id or ""]
    if glyph then glyph(x, y, c, d or mix(c, self.colors.surface, 0.45)); return true end
    return false
  end

  ---------------------------------------------------------------------------
  -- App buttons
  ---------------------------------------------------------------------------
  local function drawIcon(icon, x, y, size)
    local width = icon.right - icon.left + 1
    local height = icon.bottom - icon.top + 1
    icon.draw(x + floor((size - width) / 2) - icon.left,
      y + floor((size - height) / 2) - icon.top)
  end

  local function caption(self, label, x, y, w, ink)
    local text = translate(label)
    local shown = self:fitPartyType(text, w)
    local first, second = text:match("^(%S+)%s+(.+)$")
    if shown ~= text and first and self:fitPartyType(first, w) == first
        and self:fitPartyType(second, w) == second then
      self:partyType(first, x, y - 5, ink, w)
      self:partyType(second, x, y + 5, ink, w)
    else
      self:partyType(shown, x, y, ink, w)
    end
  end

  local APP_ACCENT = {
    map = "blue", tools = "amber", store = "red", settings = "slate", bag = "amber",
    pokedex = "red", trainer = "blue", steps = "green", achievements = "amber",
    party = "red", explorer = "green", notes = "amber", pss = "blue",
  }
  local ACCENTS = {
    pokegear = { blue = hex("3878d0"), amber = hex("e09a20"), red = hex("e04838"),
      green = hex("3ea04c"), slate = hex("5a6c88") },
    cgear = { blue = hex("3a8ee8"), amber = hex("f09030"), red = hex("e04868"),
      green = hex("40c070"), slate = hex("1ea5d8") },
  }
  function H:v4AppAccent(id)
    local key = APP_ACCENT[id or ""]
    return key and ACCENTS[cg(self) and "cgear" or "pokegear"][key]
  end

  function H:homeAppButton(x, y, w, h, accent, label, icon, selected)
    local colors = self.colors
    local id = iconId(icon)
    local a = K.rampOf(self:v4AppAccent(id) or accent or colors.green)
    local text = translate(label)
    local twoLines = self:fitPartyType(text, w - 10) ~= text and text:find("%s") ~= nil
    local plateH = twoLines and 25 or 16
    local d = min(40, w - 13, h - 40)
    local bx = x + floor((w - d) / 2)
    local by = y + max(6, floor((h - d - 30) / 2))
    if cg(self) then
      self:v4Window(x, y, w, h, { radius = 6 })
      CIRC(bx - 1, by + 1, d + 2, colors.shadow)
      CIRC(bx, by, d, colors.outline)
      CIRC(bx + 1, by + 1, d - 2, a.M)
      CIRCrows(bx + 1, by + 1, d - 2, 0, floor(d / 2) - 2, a.L)
      CIRC(bx + 5, by + 5, d - 10, colors.outline)
      CIRC(bx + 6, by + 6, d - 12, self.dark and hex("26313c") or hex("f4f8fa"))
      CIRCrows(bx + 6, by + 6, d - 12, floor((d - 12) / 2), d, self.dark and hex("212a34") or hex("e8eff3"))
      -- one tick orbits the ring
      local t = self:clock()
      local ang = (t / 1.6) % (math.pi * 2)
      local r = d / 2 - 3
      R(floor(bx + d / 2 + math.cos(ang) * r) - 1, floor(by + d / 2 + math.sin(ang) * r) - 1, 2, 2, WHITE)
      self:wantAmbient(0.3)
      local gx, gy = bx + floor((d - 20) / 2), by + floor((d - 20) / 2)
      if not self:v4Glyph(id, gx, gy, a.M, mix(a.M, colors.surface, 0.5)) and icon then
        drawIcon(icon, bx + floor((d - 26) / 2), by + floor((d - 26) / 2), 26)
      end
      local ly = by + d + 4
      R(x + 8, ly, w - 16, 1, self.tok.line)
      caption(self, label, x + 3, ly + floor((y + h - ly - 11) / 2), w - 6, colors.ink)
      if selected then self:focusFrame(x, y, w, h) end
      return
    end
    -- Pokégear: paper tile, round rimmed button, accent label plate.
    self:v4Window(x, y, w, h, { radius = 4 })
    RR(x + 3, y + 3, w - 6, h - 8 - plateH, 3, self.tok.paper2)
    CIRC(bx - 1, by + 1, d + 2, colors.shadow)
    CIRC(bx, by + 2, d, a.D)
    CIRC(bx, by, d, colors.outline)
    CIRC(bx + 1, by + 1, d - 2, a.L)
    CIRCrows(bx + 1, by + 1, d - 2, floor(d / 2), d, a.M)
    CIRC(bx + 5, by + 5, d - 10, a.D)
    CIRC(bx + 6, by + 6, d - 12, hex("fbfbf4"))
    CIRCrows(bx + 6, by + 6, d - 12, floor((d - 12) / 2) + 2, d, hex("eceee6"))
    R(bx + 9, by + 2, 8, 1, a.Hi); R(bx + 7, by + 3, 3, 1, a.Hi)
    if icon then drawIcon(icon, bx + 6, by + 6, d - 12) end
    local py = y + h - 5 - plateH
    RR(x + 4, py, w - 8, plateH, 3, colors.outline)
    RR(x + 5, py + 1, w - 10, plateH - 2, 2, a.D)
    RR(x + 5, py + 1, w - 10, plateH - 4, 2, a.M)
    RRrows(x + 5, py + 1, w - 10, plateH - 4, 2, 0, 5, a.L)
    R(x + 7, py + 1, w - 14, 1, a.Hi)
    caption(self, label, x + 5, py + 1 + floor((plateH - 16) / 2), w - 10, WHITE)
    if selected then self:focusFrame(x, y, w, h) end
  end

  ---------------------------------------------------------------------------
  -- Pager
  ---------------------------------------------------------------------------
  function H:homePager(page, pages)
    pages = max(1, tonumber(pages) or 1)
    if pages < 2 then return end
    page = max(1, min(pages, tonumber(page) or 1))
    local colors = self.colors
    if pages > 7 then return base.homePager(self, page, pages) end
    local gap, center = 10, 120
    local left = center - floor((pages - 1) * gap / 2)
    self:pageChevron(left - 13, 207, false, false)
    self:pageChevron(left + (pages - 1) * gap + 13, 207, true, false)
    for index = 1, pages do
      local x, y = left + (index - 1) * gap - 3, 204
      if cg(self) then
        ART({ "..#..", ".###.", "#####", ".###.", "..#.." }, x + 1, y + 1,
          { ["#"] = index == page and self.tok.acc.M or self.tok.border })
      elseif index == page then
        local bob = floor(self:clock() / 0.5) % 2
        self:wantAmbient(0.5)
        self:v4MiniBall(x, y - bob, "ok")
      else
        ART(K.BALL_EMPTY, x, y, { o = colors.silverDark })
      end
    end
  end

  ---------------------------------------------------------------------------
  -- Seats (Poké Ball / C-Gear ring) for portraits
  ---------------------------------------------------------------------------
  function H:v4Seat(x, y, d, fainted, selected)
    local colors = self.colors
    if cg(self) then
      CIRC(x, y, d, colors.outline)
      CIRC(x + 1, y + 1, d - 2, fainted and (self.dark and hex("3a2a30") or hex("eadada"))
        or (self.dark and hex("141b22") or hex("e9f1f6")))
      RING(x + 1, y + 1, d - 2, 2, fainted and hex("c05050") or (selected and self.tok.acc.L or self.tok.acc.M))
      local inner = self.dark and hex("1f3a48") or hex("c6e4f0")
      if d >= 20 then RING(x + 6, y + 6, d - 12, 1, inner) end
      R(x + 3, y + floor(d / 2), 3, 1, inner); R(x + d - 6, y + floor(d / 2), 3, 1, inner)
      return
    end
    local top = fainted and hex("b8a8a8") or (self.dark and hex("8a4a50") or hex("f4c4bc"))
    local bottom = fainted and hex("d8d0d0") or (self.dark and hex("cfd6e0") or hex("fbfbf6"))
    local half = floor(d / 2)
    CIRC(x, y, d, colors.outline)
    CIRCrows(x + 1, y + 1, d - 2, 0, half - 1, top)
    CIRCrows(x + 1, y + 1, d - 2, half - 1, d, bottom)
    R(x + 1, y + half - 1, d - 2, 2, colors.outline)
    local b = d >= 30 and 10 or 6
    local bx, by = x + floor((d - b) / 2), y + floor((d - b) / 2)
    CIRC(bx, by, b, colors.outline); CIRC(bx + 2, by + 2, b - 4, bottom)
    R(x + floor(d * 0.25), y + 3, 3, 1, { 1, 1, 1, 0.7 })
    R(x + floor(d * 0.25) - 1, y + 4, 1, 2, { 1, 1, 1, 0.6 })
  end
  -- hgss contract: a 34px seat centred on (x + 17, y + 20).
  function H:partyPortrait(x, y, selected, fainted)
    self:v4Seat(x, y + 3, 35, fainted, selected)
  end

  ---------------------------------------------------------------------------
  -- Widgets
  ---------------------------------------------------------------------------
  function H:homeExplorer(model, tile, selected)
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, self.colors.greenLight, selected)
    self:v4CardHeader(x, y, w, "EXPLORER", model.route, model.editing)
    self:homeExplorerMap(model, tile)
  end

  -- Accent band with a right-aligned detail (route name, counts).
  function H:v4CardHeader(x, y, w, label, detail, editing, accent)
    local tok, colors = self.tok, self.colors
    self:homeWidgetHeader(x, y, w, label, accent and accent.M or nil,
      accent and accent.L or nil, editing or detail ~= nil)
    if not detail then return end
    local title = self:partyInfoWidth(translate(label))
    local room = w - (cg(self) and 13 or 7) - title - 14
    local shown = self:fitPartyType(translate(detail), room)
    local sw = self:partyInfoWidth(shown)
    local dx = x + w - 7 - sw
    self:partyType(shown, dx, y + (cg(self) and 2 or 3),
      cg(self) and tok.acc.M or (accent and accent.Hi or tok.acc.Hi), sw)
  end

  function H:homeExplorerMap(model, tile, retained)
    local x, y, w, h = self:homeRect(tile)
    local mx, my, mw, mh = x + 5, y + 22, w - 10, h - 27
    -- Movement-only repaints keep the frame pixels from the last full paint;
    -- redrawing chrome (or its translucent shade) here made the edge flicker.
    if retained then
      self:mapOverview(model.overview, mx, my, mw, mh, {
        retainFrame = true,
        image = model.image, player = model.player, markers = model.markers,
        drawPlayer = model.drawPlayer, drawTrainer = model.drawTrainer,
      })
      return
    end
    if cg(self) then
      CH(mx - 1, my - 1, mw + 2, mh + 2, 2, self.tok.border)
    else
      RR(mx - 1, my - 1, mw + 2, mh + 2, 2, self.colors.outline)
    end
    self:mapOverview(model.overview, mx, my, mw, mh, {
      retainFrame = retained,
      image = model.image, player = model.player, markers = model.markers,
      drawPlayer = model.drawPlayer, drawTrainer = model.drawTrainer,
    })
    R(mx, my, mw, 1, { 0, 0, 0, 0.28 }); R(mx, my, 1, mh, { 0, 0, 0, 0.2 })
  end

  function H:homeParty(model, tile, selected)
    local colors = self.colors
    local x, y, w, h = self:homeRect(tile)
    local lead = model.lead
    self:homeTile(x, y, w, h, colors.partyLight, selected)
    self:homeWidgetHeader(x, y, w, "PARTY", nil, nil, model.editing)
    local fainted = lead and (lead.hp or 1) <= 0
    local seat = 36
    local sx, sy = x + 5, y + 20
    self:v4Seat(sx, sy, seat, fainted)
    if model.drawPokemon and lead then
      model.drawPokemon(lead, sx + 2, sy + 2, seat - 4, fainted)
    end
    local ix, iw = sx + seat + 4, x + w - 5 - (sx + seat + 4)
    if lead then
      self:partyInfo(lead.levelText or "--", ix, y + 18, colors.ink)
      if lead.gender == "male" or lead.gender == "female" then
        self:genderIcon(lead.gender, x + w - 12, y + 21)
      end
      if lead.statusId then self:v4StatusPill(lead.statusId, ix, y + 32) end
      self:partyInfo(lead.hpText or "--/--", ix - 4, y + 43, colors.ink, iw + 4, "right")
    end
    local name = self:fitPartyInfo(lead and lead.name or "---", w - 10)
    self:partyInfo(name, x + 5, y + 55, colors.ink, w - 10, "center")
    self:v4HpBar(x + 6, y + 70, w - 12, lead and lead.hp or 0, lead and lead.maxHp or 1)
  end

  ---------------------------------------------------------------------------
  -- Home: keep the stock layout pass, give empty states the new chrome.
  ---------------------------------------------------------------------------
  function H:homePlus(tile)
    local x, y, w, h = self:homeRect(tile)
    local pressed = self:beginPress(x, y, w, h)
    local colors = self.colors
    local c = cg(self) and self.tok.acc.M or colors.silverDark
    -- an empty slot is a dashed outline on a translucent tray, not a card
    K.setc({ colors.surface[1], colors.surface[2], colors.surface[3], 0.35 })
    ui.graphics.rectangle("fill", x + 1, y + 1, w - 2, h - 2)
    for dx = x + 3, x + w - 5, 6 do R(dx, y, 3, 1, c); R(dx, y + h - 1, 3, 1, c) end
    for dy = y + 3, y + h - 5, 6 do R(x, dy, 1, 3, c); R(x + w - 1, dy, 1, 3, c) end
    R(x, y, 2, 1, c); R(x, y, 1, 2, c); R(x + w - 2, y, 2, 1, c); R(x + w - 1, y, 1, 2, c)
    R(x, y + h - 1, 2, 1, c); R(x, y + h - 2, 1, 2, c); R(x + w - 2, y + h - 1, 2, 1, c); R(x + w - 1, y + h - 2, 1, 2, c)
    local cx, cy = x + floor(w / 2), y + floor(h / 2)
    CIRC(cx - 9, cy - 9, 19, c)
    CIRC(cx - 8, cy - 8, 17, colors.surface)
    R(cx - 4, cy - 1, 9, 3, c); R(cx - 1, cy - 4, 3, 9, c)
    self:endPress(pressed)
  end

  ---------------------------------------------------------------------------
  -- Header variants used while editing Home
  ---------------------------------------------------------------------------
  local function headerSlice(self, x, w)
    local tok = self.tok
    if cg(self) then
      R(x, 0, w, 21, tok.head)
      for y = 1, 20, 2 do R(x, y, w, 1, tok.headLine) end
      return
    end
    for y = 1, 20 do R(x, y, w, 1, y % 2 == 1 and tok.acc.M or tok.accS) end
  end
  function H:homeEditDone()
    local pressed = self:beginPress(158, 6, 57, 15)
    headerSlice(self, 139, 101)
    local a = { M = self.tok.acc.L, L = mix(self.tok.acc.L, WHITE, 0.3),
      D = self.tok.acc.D, Hi = self.tok.acc.Hi }
    local off = self:v4Button(158, 4, 57, 17, a, { radius = 3, lip = 3, chamfer = 4 })
    self:partyType(translate("DONE"), 161, 6 + off, WHITE, 51)
    self:endPress(pressed)
  end
  function H:homeAddHeader(title)
    headerSlice(self, 26, 214)
    local shown = self:fitLabel(translate(title), 190)
    if cg(self) then
      local acc, tw = self.tok.acc, 180
      for y = 0, 20 do
        R(26, y, tw + (20 - y), 1, y < 1 and acc.L or (y % 2 == 1 and acc.M or self.tok.accS))
        R(26 + tw + (20 - y), y, 2, 1, acc.Hi)
      end
      self:label(shown, 26 + floor((tw - self:labelWidth(shown)) / 2), 3, WHITE)
      return
    end
    RR(28, 3, 208, 17, 3, self.tok.acc.D)
    RR(29, 4, 206, 15, 2, self.tok.well)
    self:label(shown, 132 - floor(self:labelWidth(shown) / 2), 3, WHITE)
  end
end
