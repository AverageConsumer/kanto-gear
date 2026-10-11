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

  -- With the field guide on, the widget's bottom edge becomes a "NOW" rail:
  -- the Pokémon that can appear on this map at this time, like the Pokétch
  -- dowsing/radar apps. The rail sits beside the map, never over it, so
  -- movement-only repaints (retained) never touch it.
  local NOW_H = 15
  function H:homeExplorerRect(model, tile)
    local x, y, w, h = self:homeRect(tile)
    local mx, my, mw, mh = x + 5, y + 22, w - 10, h - 27
    if model.nowRows and mh >= 44 then
      return mx, my, mw, mh - NOW_H - 2, true
    end
    return mx, my, mw, mh, false
  end

  function H:homeNowRail(model, x, y, w)
    local tok, colors = self.tok, self.colors
    local rows = model.nowRows or {}
    if cg(self) then
      CH(x - 1, y, w + 2, NOW_H, 2, tok.border)
      CH(x, y + 1, w, NOW_H - 2, 1, colors.surface)
    else
      RR(x - 1, y, w + 2, NOW_H, 3, colors.outline)
      RR(x, y + 1, w, NOW_H - 2, 2, colors.surface)
      R(x + 2, y + 1, w - 4, 1, mix(colors.surface, WHITE, 0.5))
    end
    local accent = cg(self) and tok.acc.M or colors.green
    local pw = self:v4Pill("NOW", x + 2, y + 2, accent)
    local left, right = x + 2 + pw + 3, x + w - 3
    if #rows == 0 then
      self:partyType(self:fitPartyType(translate("NONE HERE"), right - left),
        left, y + 2, colors.mutedInk or colors.silverDark, right - left)
      return
    end
    -- seats are spread across the free run so the group stays centred
    local seat, n = 16, #rows
    local gap = n > 1 and min(6, floor((right - left - n * seat) / (n - 1))) or 0
    local run = n * seat + (n - 1) * gap
    local sx = left + floor((right - left - run) / 2)
    for i, row in ipairs(rows) do
      local cx = sx + (i - 1) * (seat + gap)
      if model.drawNowIcon then
        model.drawNowIcon(row, cx, y - 1, seat, not row.caught)
      end
      if row.caught then
        ART(K.BALL, cx + seat - 5, y + NOW_H - 9, {
          o = hex("101010"), r = hex("f05040"), w = hex("f8f8f8") })
      end
    end
  end

  function H:homeExplorerMap(model, tile, retained)
    local mx, my, mw, mh, rail = self:homeExplorerRect(model, tile)
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
    if rail then self:homeNowRail(model, mx, my + mh + 2, mw) end
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
  -- Add to Home: a parts catalogue. Apps and widgets share one card: a round
  -- seat, the name, a footprint diagram for widgets and a state key.
  ---------------------------------------------------------------------------
  local CHECK = { "......#", ".....##", "#...##.", "##.##..", ".###...", "..#...." }
  local CROSS = { "#...#", ".#.#.", "..#..", ".#.#.", "#...#" }
  local PLUS = { "..#..", "..#..", "#####", "..#..", "..#.." }

  local function footprint(self, x, y, columns, rows, accent)
    -- one cell per Home column/row, like the edit-mode grid
    columns, rows = tonumber(columns) or 1, tonumber(rows) or 1
    local cw = columns > 6 and 2 or 3
    local w = columns * (cw + 1) - 1
    for r = 0, rows - 1 do
      for c = 0, columns - 1 do
        R(x + c * (cw + 1), y + r * 4, cw, 3, accent)
      end
    end
    return w
  end

  function H:homeLibraryCard(x, y, w, item, icons)
    local colors = self.colors
    local available = item.available
    local pressed = self:beginPress(x, y, w, 46, available)
    local icon = icons[item.icon or item.id]
    local id = iconId(icon) or item.widget
    local accent = self:v4AppAccent(id) or self:v4AppAccent(item.icon) or self.tok.acc.M
    local fill = available and nil or mix(colors.surface, colors.silverDark, self.dark and 0.3 or 0.18)
    self:v4Window(x, y, w, 46, { radius = 4, fill = fill })
    R(x + 1, y + 4, 2, 38, available and accent or colors.silverDark)
    -- seat
    CIRC(x + 5, y + 5, 33, colors.outline)
    CIRC(x + 6, y + 6, 31, mix(colors.surface, accent, self.dark and 0.3 or 0.2))
    K.CIRCrows(x + 6, y + 6, 31, 16, 31, mix(colors.surface, accent, self.dark and 0.42 or 0.32))
    if item.kind == "app" and cg(self) and id and GLYPH[id] then
      GLYPH[id](x + 12, y + 12, accent, mix(accent, colors.surface, 0.5))
    elseif item.kind == "app" and icon then drawIcon(icon, x + 7, y + 7, 29)
    else self:homeWidgetLibraryIcon(item.widget, x + 7, y + 7, item) end
    local tx, tw = x + 41, w - 44
    local label = self:fitPartyInfo(item.widget == "tool" and item.label or translate(item.label), tw)
    self:partyInfo(label, tx, y + 3, available and colors.ink or colors.mutedInk)
    -- kind: APP pill, or the widget's footprint on the Home grid
    if item.kind == "app" then
      self:v4Pill("APP", tx, y + 17, available and accent or colors.silverDark)
    else
      local fw = footprint(self, tx, y + 19, item.columns, item.rows, available and accent or colors.silverDark)
      self:partyInfo(("%dx%d"):format(tonumber(item.columns) or 1, tonumber(item.rows) or 1),
        tx + fw + 4, y + 14, colors.mutedInk)
    end
    -- state key
    if available then
      local a = K.rampOf(cg(self) and hex("1ea5d8") or hex("3ea04c"))
      local off = self:v4Button(tx, y + 30, tw, 13, a, { radius = 3, lip = 2, chamfer = 2 })
      local text = translate("ADD")
      local gw = 5 + 3 + self:partyInfoWidth(text)
      local gx = tx + floor((tw - gw) / 2)
      ART(PLUS, gx, y + 33 + off, { ["#"] = WHITE })
      self:partyInfo(text, gx + 8, y + 29 + off, WHITE)
    else
      local onHome = item.reason == "on_home"
      local text = translate(onHome and "ON HOME" or "NO SPACE")
      local glyph = onHome and CHECK or CROSS
      local tint = onHome and (cg(self) and self.tok.acc.M or colors.green) or colors.mutedInk
      local gw = #glyph[1] + 3 + self:partyInfoWidth(text)
      local gx = tx + floor((tw - gw) / 2)
      if cg(self) then CH(tx, y + 30, tw, 13, 2, mix(colors.surface, colors.outline, 0.12))
      else RR(tx, y + 30, tw, 13, 3, mix(colors.surface, colors.outline, self.dark and 0.25 or 0.1)) end
      ART(glyph, gx, y + 33 + (#glyph < 6 and 1 or 0), { ["#"] = tint })
      self:partyInfo(text, gx + #glyph[1] + 3, y + 29, tint)
    end
    self:endPress(pressed)
  end

  function H:homeCatalog(model)
    local colors = self.colors
    local icons = self.homeIconTable and self:homeIconTable() or {}
    self:v4Window(6, 31, 228, 168, { radius = 5 })
    -- APPS | WIDGETS: one control, the lit half glides across
    local accent = cg(self) and self.tok.acc.M or colors.green
    local a = K.rampOf(accent)
    if cg(self) then CH(9, 33, 222, 15, 3, colors.outline); CH(10, 34, 220, 13, 2, self.dark and hex("141b22") or hex("e4ebf0"))
    else RR(9, 33, 222, 15, 4, colors.outline); RR(10, 34, 220, 13, 3, self.dark and hex("1c2533") or hex("dfe8e1")) end
    local target = model.libraryKind == "widget" and 120 or 10
    local hx = self:v4Glide("home_catalog_tab", target)
    if cg(self) then CH(hx, 34, 110, 13, 2, a.M); CH(hx, 34, 110, 6, 2, a.L)
    else RR(hx, 34, 110, 13, 3, a.D); RR(hx, 34, 110, 11, 3, a.M); R(hx + 3, 34, 104, 1, a.Hi) end
    for index, tab in ipairs({ "app", "widget" }) do
      local x = index == 1 and 10 or 121
      local active = model.libraryKind == tab
      local pressed = self:beginPress(x, 34, 108, 13, not active or (model.libraryPage or 1) > 1)
      local lit = hx + 55 >= x and hx + 55 < x + 110
      self:partyType(translate(tab == "app" and "APPS" or "WIDGETS"), x + 2, 34, lit and WHITE or colors.mutedInk, 104)
      self:endPress(pressed)
    end
    local page = max(1, tonumber(model.libraryPage) or 1)
    local first = (page - 1) * 6 + 1
    local enter = self:v4Enter("home_catalog", tostring(model.libraryKind) .. ":" .. page, 0.26)
    local G = ui.graphics
    for index = first, min(first + 5, #(model.library or {})) do
      local item = model.library[index]
      local visible = index - first
      local column, row = visible % 2, floor(visible / 2)
      local _, dy = self:v4Stagger(enter, visible + 1, 0.06, 8, 6)
      if dy ~= 0 then G.push(); G.translate(0, dy) end
      self:homeLibraryCard(10 + column * 111, 49 + row * 48, 108, item, icons)
      if dy ~= 0 then G.pop() end
    end
    self:homePager(page, model.libraryPages)
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
