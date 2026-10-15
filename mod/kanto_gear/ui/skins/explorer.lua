-- Kanto Gear v4: Explorer (route header, encounter cards, habitat details,
-- item/trainer/fruit cards, full-map tools and the radar).
-- Geometry contract with ui/base/init.lua/explorerHit: header 32..50, toggle 202..232,
-- map 53..137 (wild detail 53..95), filters 142..158, cards 162..210.
return function(H, ui, K)
  local floor, max, min = math.floor, math.max, math.min
  local R, P, RR, RRrows, CH, CHrows = K.R, K.P, K.RR, K.RRrows, K.CH, K.CHrows
  local CIRC, RING, ART = K.CIRC, K.RING, K.ART
  local mix, hex = K.mix, K.hex
  local cg, WHITE = K.cg, K.WHITE
  local translate = function(value) return ui.translate and ui.translate(value) or value end

  ---------------------------------------------------------------------------
  -- Shared bits: status pill, method glyphs, chance meter
  ---------------------------------------------------------------------------
  -- Small capsule with white text; returns its width.
  function H:v4Pill(label, x, y, color, opts)
    opts = opts or {}
    local text = opts.raw and label or translate(label)
    if opts.maxW then text = self:fitPartyType(text, opts.maxW - 8) end
    local w = opts.w or (self:partyInfoWidth(text) + 9)
    if opts.right then x = x - w end
    local d = mix(color, { 0, 0, 0, 1 }, 0.38)
    if cg(self) then
      CH(x, y, w, 11, 2, d); CH(x + 1, y + 1, w - 2, 9, 1, color)
      R(x + 2, y + 1, w - 4, 1, mix(color, WHITE, 0.35))
    else
      RR(x, y, w, 11, 4, d); RR(x + 1, y + 1, w - 2, 9, 3, color)
      R(x + 3, y + 1, w - 6, 1, mix(color, WHITE, 0.4))
    end
    self:withoutShadow(self.partyType, self, text, x, y, WHITE, w)
    return w
  end

  local GLYPHS = {
    grass = { "...#...", ".#.#.#.", ".#.#.#.", "##.#.##", "#######" },
    water = { ".##...#", "#..###.", ".......", ".##...#", "#..###." },
    rod = { "......#", ".....##", "....#.#", "...#..#", "..#...#", ".#....o", "#.....o" },
    tree = { "..###..", ".#####.", "#######", ".#####.", "...#...", "..###.." },
    rock = { "..###..", ".##.##.", "##.####", "#######", ".#####." },
    gift = { "..#.#..", "#######", "#..#..#", "#######", "#..#..#", "#######" },
    cave = { "..###..", ".#####.", "##...##", "#.....#", "#.....#" },
  }
  local function methodKind(method)
    local m = tostring(method or ""):upper()
    if m:find("ROD") or m:find("OLD") or m:find("GOOD") or m:find("SUPER") or m:find("FISH") then return "rod" end
    if m:find("SURF") or m:find("WATER") then return "water" end
    if m:find("HEAD") or m:find("TREE") then return "tree" end
    if m:find("ROCK") or m:find("SMASH") then return "rock" end
    if m:find("GIFT") or m:find("TRADE") or m:find("OFFER") or m:find("LOAN") then return "gift" end
    if m:find("CAVE") then return "cave" end
    return "grass"
  end
  local METHOD_TINT = { grass = "48a048", water = "3878d0", rod = "3878d0", tree = "6a8a38",
    rock = "8a7058", gift = "d05878", cave = "7a6a58" }
  function H:v4MethodGlyph(method, x, y, color)
    local kind = methodKind(method)
    local c = color or hex(METHOD_TINT[kind])
    ART(GLYPHS[kind], x, y + (#GLYPHS[kind] < 7 and floor((7 - #GLYPHS[kind]) / 2) or 0),
      { ["#"] = c, o = self.colors.outline })
    return kind
  end
  K.methodKind = methodKind

  local function chanceTint(self, chance)
    chance = tonumber(chance) or 0
    if chance >= 25 then return self.colors.hp end
    if chance >= 10 then return hex("e8b020") end
    return hex("e05848")
  end
  -- Thin chance meter (0..100 maps to the full width; ≤ 1% still shows a pip).
  function H:v4ChanceBar(x, y, w, chance)
    local colors = self.colors
    R(x, y, w, 3, colors.outline)
    R(x + 1, y + 1, w - 2, 1, self.dark and hex("2a3340") or hex("d8dcd4"))
    local p = max(0, min(1, (tonumber(chance) or 0) / 60))
    local fill = max((tonumber(chance) or 0) > 0 and 1 or 0, floor((w - 2) * p + 0.5))
    if fill > 0 then R(x + 1, y + 1, fill, 1, chanceTint(self, chance)) end
  end

  local function levels(a)
    if not a or not a.minLevel then return "--" end
    return a.minLevel == a.maxLevel and "L" .. tostring(a.minLevel)
      or "L" .. tostring(a.minLevel) .. "-" .. tostring(a.maxLevel)
  end
  local function statusColor(self, key)
    local colors = self.colors
    if key == "CAUGHT" or key == "FOUND" or key == "BEATEN" or key == "RECORDED"
        or key == "HERE NOW" or key == "READY TO PICK" then return colors.hp end
    if key == "REMATCH" or key == "OPEN" then return cg(self) and self.tok.acc.M or hex("3878d0") end
    if key == "NEEDS TOOL" or key == "NEED SPACE" or key == "MISSED" then return hex("d05040") end
    return colors.silverDark
  end

  local function heroSeat(self, x, y)
    self:v4Seat(x, y, 36)
  end

  local function wildDetail(self, model, selected)
    local colors = self.colors
    local accent = self:typeColor(selected.type)
    self.v4SummaryWindow(self, 7, 99, 226, 46, accent)
    heroSeat(self, 12, 104)
    if model.drawPokemon then model.drawPokemon(selected, 14, 106, 32, not selected.caught and not selected.gift) end
    local status = selected.gift and (selected.excluded and "ALTERNATIVE CHOICE"
      or selected.done and (selected.catchGoal and "CAUGHT" or "RECORDED")
      or selected.noRoom and "NEED SPACE" or selected.status or "OPEN")
      or selected.caught and "CAUGHT" or "NOT CAUGHT"
    self:partyName(self:fitPartyInfo(selected.name, 104), 52, 102, colors.ink, 104)
    self:v4Pill(status, 52, 117, statusColor(self, status), { maxW = 104 })
    if not selected.isEgg then self:typeBadges(selected, 52, 132, false) end
    if selected.gift then
      self:v4Window(7, 149, 226, 61)
      self:v4MethodGlyph(selected.trade and "TRADE" or "GIFT", 16, 156)
      self:partyInfo(self:fitPartyType(translate(selected.method), 190), 27, 154, colors.green)
      local requirement = selected.needsSpeciesName and string.format(translate("BRING %s"), selected.needsSpeciesName)
        or selected.coinCost and string.format(translate("%d COINS"), selected.coinCost)
        or selected.cost and "$" .. tostring(selected.cost) or translate("TALK TO NPC")
      local gender = selected.needsGender == "TRADE_GENDER_FEMALE" and "female"
        or selected.needsGender == "TRADE_GENDER_MALE" and "male"
      requirement = self:fitPartyInfo(requirement, gender and 188 or 202)
      local width = self:partyInfoWidth(requirement)
      local left = 15 + floor((210 - width - (gender and 14 or 0)) / 2)
      self:partyInfo(requirement, left, 171, colors.ink)
      if gender then self:genderIcon(gender, left + width + 4, 172) end
      R(15, 186, 210, 1, colors.band)
      local lv = selected.isEgg and translate("EGG") or selected.level and "L" .. tostring(selected.level) or translate("TALK TO NPC")
      self:partyType(lv, 15, 192, colors.green, 210)
      return
    end
    if model.encounterDetails == false then return end
    -- habitats: a label, and page keys only when there is more than one page
    if model.detailPages > 1 then
      self:v4PageKeys(226, 105, model.detailPage, model.detailPages)
      self:partyType(translate("HABITAT"), 156, 124, colors.mutedInk, 70, "right")
    else
      self:partyType(translate("HABITAT"), 166, 110, colors.mutedInk, 58)
    end
    local rows = model.detailRows or {}
    if #rows == 1 then
      local a = rows[1]
      local st = a.blocked and "NEEDS TOOL" or a.current and "HERE NOW"
      self:v4Window(7, 149, 226, 61, a.current and { fill = mix(colors.surface, colors.hp, self.dark and 0.14 or 0.1) } or nil)
      self:partyInfo(self:fitPartyInfo(a.section or model.route, st and 130 or 206), 14, 152, colors.ink)
      if st then self:v4Pill(st, 225, 153, statusColor(self, st), { right = true, maxW = 84 }) end
      R(14, 167, 212, 1, colors.band)
      local cells = { "TIME", "METHOD", "CHANCE", "LEVEL" }
      for i, key in ipairs(cells) do
        local x = 10 + (i - 1) * 55
        if i > 1 then R(x - 2, 171, 1, 34, colors.band) end
        self:partyType(self:fitPartyType(translate(key), 51), x, 170, colors.mutedInk, 51)
        if key == "TIME" then
          local label = self:fitPartyInfo(translate(a.time or "ANY TIME"), 40)
          local lw = self:partyInfoWidth(label)
          local has = a.time and K.periodIcon
          local lx = x + floor((51 - lw - (has and 10 or 0)) / 2)
          if has then K.periodIcon(a.time, lx, 189, colors.ink) end
          self:partyInfo(label, lx + (has and 10 or 0), 187, colors.ink)
        elseif key == "METHOD" then
          local label = self:fitPartyInfo(translate(a.method or "--"), 40)
          local lw = self:partyInfoWidth(label)
          local lx = x + floor((51 - lw - 10) / 2)
          self:v4MethodGlyph(a.method, lx, 189)
          self:partyInfo(label, lx + 10, 187, colors.ink)
        elseif key == "CHANCE" then
          self:partyInfo(tostring(a.chance or "--") .. "%", x, 184, colors.ink, 51, "center")
          self:v4ChanceBar(x + 6, 199, 39, a.chance)
        else
          self:partyInfo(levels(a), x, 187, colors.ink, 51, "center")
        end
      end
    else
      for index, a in ipairs(rows) do
        local y = 149 + (index - 1) * 31
        local st = a.blocked and "NEEDS TOOL" or a.current and "HERE NOW"
        self:v4Window(7, y, 226, 29, a.current and { fill = mix(colors.surface, colors.hp, self.dark and 0.14 or 0.1) } or nil)
        self:partyInfo(self:fitPartyInfo(a.section or model.route, st and 120 or 150), 13, y + 2, colors.ink)
        if st then self:v4Pill(st, 226, y + 3, statusColor(self, st), { right = true, maxW = 90 }) end
        local x = 13
        if a.time and K.periodIcon and K.periodIcon(a.time, x, y + 18, colors.mutedInk) then x = x + 10 end
        self:v4MethodGlyph(a.method, x, y + 18)
        local method = self:fitPartyType(translate(tostring(a.method or "--")), 60)
        self:partyInfo(method, x + 10, y + 16, colors.green)
        local cx = 108
        self:partyInfo(tostring(a.chance or "--") .. "%", cx, y + 16, colors.ink, 26, "right")
        self:v4ChanceBar(cx + 30, y + 21, 40, a.chance)
        self:partyInfo(levels(a), 178, y + 15, colors.ink, 48, "right")
      end
    end
  end

  ---------------------------------------------------------------------------
  -- Geometry. Share the HGSS map helpers explicitly: debug introspection is
  -- unavailable in the mod sandbox. Drawing, marker hits and motion must agree.
  ---------------------------------------------------------------------------
  local HEADER_Y, HEADER_H = 32, 20
  local MAP_X, MAP_W = 7, 226
  local MAP_Y, MAP_H = 54, 64          -- overview
  local DETAIL_MAP_H = 40              -- any selection
  local FULL_Y, FULL_H = 74, 136       -- expanded map
  -- Bottom half: three folder tabs with progress counts, one paper panel
  -- with a quiet control strip (HERE / ALL on the left, the page keys on the
  -- right), then always four calm 109×26 cards. Paging never takes a card slot.
  local TAB_Y, TAB_H = 120, 18
  local PANEL_Y, PANEL_B = 137, 214
  local STRIP_Y, STRIP_H = 140, 14
  local CARD_W, CARD_H = 109, 26
  local CARD_POS = { { 9, 157 }, { 122, 157 }, { 9, 186 }, { 122, 186 } }
  -- page keys: [<]  dots  [>]
  local PAGER_W, PAGER_KEY = 70, 17
  local function pagerRects(right, y)
    local x = right - PAGER_W
    return x, x + PAGER_W - PAGER_KEY, y
  end
  local function tabRect(i)
    local tw = floor(MAP_W / 3)
    local x = MAP_X + (i - 1) * tw
    local w = i == 3 and MAP_W - tw * 2 or tw - 1
    return x, w
  end

  local stockLayout, stockMotionKey = K.base.mapLayout, K.base.mapMotionKey

  local function mapFrame(model)
    if model.mapFull then return MAP_X, FULL_Y, MAP_W, FULL_H end
    if model.selected then return MAP_X, MAP_Y, MAP_W, DETAIL_MAP_H end
    return MAP_X, MAP_Y, MAP_W, MAP_H
  end
  local function focusOf(model)
    local marker = model.selectedMarker
    return marker and (marker.kind == "trainer" or marker.kind == "fruit" or marker.gift or marker.entrance) and marker or model.player
  end
  local function layoutOf(model, player)
    if not stockLayout then return nil end
    local x, y, w, h = mapFrame(model)
    local ok, layout = pcall(stockLayout, model.overview, x, y, w, h, {
      player = player or model.player, focus = focusOf(model), full = model.mapFull, zoom = model.mapZoom })
    return ok and layout or nil
  end

  -- Only take over when the stock helpers were found; otherwise the stock
  -- Explorer keeps working unchanged.
  local OWN = stockLayout ~= nil and stockMotionKey ~= nil

  ---------------------------------------------------------------------------
  -- Pieces
  ---------------------------------------------------------------------------
  local PIN = { ".ooo.", "o###o", "o#w#o", "o###o", ".o#o.", "..o.." }
  local EXPAND = { "##..##", "#....#", "......", "......", "#....#", "##..##" }
  local COLLAPSE = { "#....#", ".#..#.", "......", "......", ".#..#.", "#....#" }
  local CHEV_L = { "..#", ".##", "###", ".##", "..#" }
  local CHEV_R = { "#..", "##.", "###", "##.", "#.." }
  local TAB_ICON = {
    wild = { art = { "..#.#..", ".#.#.#.", "##.#.##", "#######" }, tint = "48a858" },
    trainers = { art = { ".ooo.", "o###o", "oowoo", ".o#o.", "o###o", "ooooo" }, tint = "e05848" },
    items = { art = { ".ooo.", "o###o", "ooooo", "owwwo", ".ooo." }, tint = "e05848" },
  }
  local PERIOD_ORDER = { "MORN", "DAY", "NITE" }
  local MINI_PERIOD = {
    MORN = { ".....", "..#..", "#####", ".###.", "....." },
    DAY = { "#.#.#", ".###.", "#####", ".###.", "#.#.#" },
    NITE = { ".##..", "##...", "##...", "##...", ".##.." },
  }
  local PERIOD_TINT = { MORN = "f0a050", DAY = "e8b820", NITE = "5878d8" }
  -- Shared with the stamp book's missing-Pokemon hints.
  function H:v4PeriodIcon(period, x, y)
    local c = PERIOD_TINT[period]
    return c and K.periodIcon and K.periodIcon(period, x, y, mix(hex(c), { 0, 0, 0, 1 }, 0.15)) or false
  end

  local function periodChip(self, period, right, y)
    if not period then return right end
    local colors = self.colors
    local label = translate(period)
    local w = self:partyInfoWidth(label) + 20
    local x = right - w
    local c = hex(PERIOD_TINT[period] or "e8b820")
    local fill = mix(colors.surface, c, self.dark and 0.35 or 0.28)
    if cg(self) then CH(x, y, w, 14, 3, mix(c, { 0, 0, 0, 1 }, 0.3)); CH(x + 1, y + 1, w - 2, 12, 2, fill)
    else RR(x, y, w, 14, 5, mix(c, { 0, 0, 0, 1 }, 0.3)); RR(x + 1, y + 1, w - 2, 12, 4, fill) end
    if K.periodIcon then K.periodIcon(period, x + 5, y + 4, mix(c, { 0, 0, 0, 1 }, 0.15)) end
    self:partyInfo(label, x + 14, y + 1, colors.ink)
    return x - 4
  end

  function H:v4RouteHeader(model)
    local colors, tok = self.colors, self.tok
    self:v4Window(MAP_X, HEADER_Y, MAP_W, HEADER_H)
    ART(PIN, 12, HEADER_Y + 7, { o = colors.outline, ["#"] = hex("e05848"), w = WHITE })
    -- expand / collapse key (hit 202..232)
    local pressed = self:beginPress(208, HEADER_Y + 3, 21, 14, not (model.overview and model.overview.disabled))
    self:v4Key(208, HEADER_Y + 3, 21, 14)
    ART(model.mapFull and COLLAPSE or EXPAND, 215, HEADER_Y + 6, { ["#"] = colors.ink })
    self:endPress(pressed)
    local right = periodChip(self, model.period, 204, HEADER_Y + 3)
    local route = self:fitPartyInfo(model.route or translate("UNKNOWN AREA"), right - 22 - 10)
    self:partyName(route, 20, HEADER_Y + 3, colors.ink, right - 22)
    local rw = self:partyInfoWidth(route)
    local where = translate(model.region or "KANTO")
    if model.subarea and model.subarea ~= "" then where = where .. " · " .. translate(model.subarea) end
    local room = right - (20 + rw + 8)
    if room > 24 then
      self:partyInfo(self:fitPartyInfo(where, room), 20 + rw + 8, HEADER_Y + 4, colors.mutedInk)
    end
  end

  local function zoomBar(self, model)
    local colors = self.colors
    local y = 54
    self:v4Window(MAP_X, y, MAP_W, 17)
    local zoom = model.mapZoom or 1
    local off = { cap = colors.bandLight, lip = colors.band, hi = colors.bandLight }
    local minus = self:beginPress(11, y + 1, 18, 15, zoom > 1)
    self:v4Key(11, y + 2, 18, 13, zoom > 1 and nil or off)
    R(17, y + 7, 6, 2, zoom > 1 and colors.ink or colors.disabledInk)
    self:endPress(minus)
    for i = 1, 3 do
      local px = 36 + (i - 1) * 8
      R(px, y + 5, 6, 6, colors.outline)
      R(px + 1, y + 6, 4, 4, i <= zoom and (cg(self) and self.tok.acc.M or colors.green) or colors.bandLight)
    end
    local plus = self:beginPress(64, y + 1, 18, 15, zoom < 3)
    self:v4Key(64, y + 2, 18, 13, zoom < 3 and nil or off)
    local c = zoom < 3 and colors.ink or colors.disabledInk
    R(70, y + 7, 6, 2, c); R(72, y + 5, 2, 6, c)
    self:endPress(plus)
    if not model.showMapStats then return end
    R(86, y + 3, 1, 11, colors.band); R(158, y + 3, 1, 11, colors.band)
    local itemsText = tostring(model.itemsText or "--")
    local iw = self:partyInfoWidth(itemsText)
    local left = 87 + floor((71 - 10 - iw) / 2)
    ART(TAB_ICON.items.art, left, y + 6, { o = colors.outline, ["#"] = hex("e05848"), w = WHITE })
    self:partyInfo(itemsText, left + 9, y + 2, colors.ink)
    local trainersText = tostring(model.trainersText or "--")
    local tw = self:partyInfoWidth(trainersText)
    local tl = 159 + floor((71 - 10 - tw) / 2)
    ART(TAB_ICON.trainers.art, tl, y + 5, { o = colors.outline, ["#"] = hex("e05848"), w = hex("f8c8a0") })
    self:partyInfo(trainersText, tl + 9, y + 2, colors.ink)
  end

  -- Two small keys with page dots between them. Keys at the ends wrap, so
  -- both stay lit; the dots say where you are.
  function H:v4PageKeys(right, y, page, pages)
    local colors = self.colors
    local x, rx = pagerRects(right, y)
    local accent = cg(self) and self.tok.acc.M or colors.green
    for i, kx in ipairs({ x, rx }) do
      local pressed = self:beginPress(kx, y, PAGER_KEY, 15, true)
      self:v4Key(kx, y, PAGER_KEY, 15)
      ART(i == 1 and CHEV_L or CHEV_R, kx + 7, y + 4, { ["#"] = accent })
      self:endPress(pressed)
    end
    if pages > 5 then
      self:partyInfoCentered(page .. "/" .. pages, x + PAGER_KEY, y + 1,
        PAGER_W - 2 * PAGER_KEY, 12, colors.ink)
      return
    end
    local n = pages
    local dw = n * 6 - 2
    local dx = x + PAGER_KEY + floor((PAGER_W - 2 * PAGER_KEY - dw) / 2)
    local current = min(n, page)
    for i = 1, n do
      local on = i == current
      R(dx + (i - 1) * 6, y + 5, 4, 4, on and accent or colors.silver)
      if on then R(dx + (i - 1) * 6 + 1, y + 6, 2, 1, mix(accent, WHITE, 0.5)) end
    end
  end

  -- HERE / ALL for wild encounters: a two-segment switch in the strip.
  local function scopeSwitch(self, model)
    local colors, tok = self.colors, self.tok
    local labels = { { "HERE", "HERE" }, { "ALL", "ROUTE" } }
    local x = MAP_X + 5
    for i, seg in ipairs(labels) do
      local w = 38
      local sx = x + (i - 1) * (w + 2)
      local on = (model.wildScope == "ROUTE") == (seg[2] == "ROUTE")
      local pressed = self:beginPress(sx, STRIP_Y, w, STRIP_H, not on)
      if on then
        if cg(self) then CH(sx, STRIP_Y, w, STRIP_H, 3, tok.acc.D); CH(sx + 1, STRIP_Y + 1, w - 2, STRIP_H - 2, 2, tok.acc.M)
        else RR(sx, STRIP_Y, w, STRIP_H, 4, colors.outline); RR(sx + 1, STRIP_Y + 1, w - 2, STRIP_H - 2, 3, tok.acc.M) end
      else
        if cg(self) then CH(sx, STRIP_Y, w, STRIP_H, 3, tok.border); CH(sx + 1, STRIP_Y + 1, w - 2, STRIP_H - 2, 2, tok.paper)
        else RR(sx, STRIP_Y, w, STRIP_H, 4, mix(colors.outline, tok.paper2, 0.5)); RR(sx + 1, STRIP_Y + 1, w - 2, STRIP_H - 2, 3, tok.paper) end
      end
      local label = self:fitPartyInfo(translate(seg[1]), w - 6)
      self:withoutShadow(self.partyInfoCentered, self, label, sx, STRIP_Y, w, STRIP_H,
        on and WHITE or colors.mutedInk)
      self:endPress(pressed)
    end
  end

  -- Folder tabs joined to the list panel below.
  local SWAP = { ".#....", "######", ".#....", "....#.", "######", "....#." }
  local function tabs(self, model)
    local colors, tok = self.colors, self.tok
    local labels = { wild = "WILD", trainers = "TRAINERS", items = "ITEMS" }
    local counts = { wild = model.wildText, trainers = model.trainersText, items = model.itemsText }
    local active = model.view
    for i, view in ipairs({ "wild", "trainers", "items" }) do
      local x, w = tabRect(i)
      local on = view == active
      local pressable = not on
      local pressed = self:beginPress(x, TAB_Y, w, TAB_H, pressable)
      if cg(self) then
        CH(x, TAB_Y + 1, w, 16, 3, on and tok.acc.M or tok.paper2)
        if on then CH(x + 1, TAB_Y + 2, w - 2, 7, 2, tok.acc.L); R(x + 3, TAB_Y + 16, w - 6, 1, tok.acc.D)
        else R(x + 3, TAB_Y + 16, w - 6, 1, tok.line) end
      elseif on then
        RR(x, TAB_Y, w, 18, 3, colors.outline)
        RR(x + 1, TAB_Y + 1, w - 2, 17, 2, tok.acc.M)
        RRrows(x + 1, TAB_Y + 1, w - 2, 17, 2, 0, 7, tok.acc.L)
        R(x + 3, TAB_Y + 1, w - 6, 1, tok.acc.Hi)
      else
        RR(x, TAB_Y + 2, w, 16, 3, colors.outline)
        RR(x + 1, TAB_Y + 3, w - 2, 15, 2, tok.paper2)
        R(x + 3, TAB_Y + 3, w - 6, 1, self.dark and hex("3a4659") or WHITE)
      end
      local icon = TAB_ICON[view]
      local label = translate(labels[view])
      local count = counts[view] and tostring(counts[view]) or nil
      local swapW = 0
      local iconW = #icon.art[1] + 2
      local room = w - 6 - iconW - swapW
      local cw = count and (self:partyInfoWidth(" " .. count)) or 0
      if self:partyInfoWidth(label) + cw > room then cw = 0; count = nil end
      label = self:fitPartyInfo(label, room - cw)
      local total = iconW + self:partyInfoWidth(label) + cw + swapW
      local lx = x + floor((w - total) / 2)
      local ty = TAB_Y + (on and 2 or 3)
      local ink = on and WHITE or colors.mutedInk
      ART(icon.art, lx, ty + floor((13 - #icon.art) / 2), { o = colors.outline, ["#"] = hex(icon.tint), w = WHITE })
      lx = lx + iconW
      self:withoutShadow(self.partyInfo, self, label, lx, ty - 1, ink)
      lx = lx + self:partyInfoWidth(label)
      if count then
        self:withoutShadow(self.partyInfo, self, " " .. count, lx, ty - 1, on and WHITE or colors.mutedInk)
        lx = lx + cw
      end
      if swapW > 0 then ART(SWAP, lx + 3, ty + 3, { ["#"] = on and WHITE or colors.mutedInk }) end
      self:endPress(pressed)
    end
  end

  local function panel(self)
    local colors, tok = self.colors, self.tok
    if cg(self) then
      CH(MAP_X, PANEL_Y, MAP_W, PANEL_B - PANEL_Y, 4, tok.border)
      CH(MAP_X + 1, PANEL_Y + 1, MAP_W - 2, PANEL_B - PANEL_Y - 2, 3, tok.paper2)
    else
      RR(MAP_X, PANEL_Y, MAP_W, PANEL_B - PANEL_Y, 3, colors.outline)
      RR(MAP_X + 1, PANEL_Y + 1, MAP_W - 2, PANEL_B - PANEL_Y - 2, 2, tok.paper2)
      R(MAP_X + 1, PANEL_Y, 74, 1, tok.acc.M)
    end
  end


  ---------------------------------------------------------------------------
  -- Cards
  ---------------------------------------------------------------------------
  local function cardFrame(self, x, y, accent, now)
    local colors, tok = self.colors, self.tok
    if cg(self) then
      CH(x + 1, y + 2, CARD_W, CARD_H, 3, colors.shadow)
      CH(x, y, CARD_W, CARD_H, 3, now and tok.acc.M or tok.border)
      CH(x + 1, y + 1, CARD_W - 2, CARD_H - 2, 2, tok.paper)
    else
      RR(x + 1, y + 2, CARD_W, CARD_H, 3, colors.shadow)
      RR(x, y, CARD_W, CARD_H, 3, colors.outline)
      RR(x + 1, y + 1, CARD_W - 2, CARD_H - 2, 2, tok.paper)
      if now then R(x + 1, y + 3, 2, CARD_H - 6, accent or tok.acc.M) end
    end
  end
  -- "not now" cards fade back like the mock's dim overlay
  local function dimCard(self, x, y)
    local tok = self.tok
    local c = cg(self) and (self.dark and hex("1b232c") or hex("e2e9ee")) or (self.dark and hex("2d3748") or hex("eef2ec"))
    local veil = { c[1], c[2], c[3], 0.55 }
    if cg(self) then CH(x + 1, y + 1, CARD_W - 2, CARD_H - 2, 3, veil) else RR(x + 1, y + 1, CARD_W - 2, CARD_H - 2, 3, veil) end
  end
  local function periodsFor(row)
    local on = {}
    for _, m in ipairs(row.matches or {}) do
      if m.current ~= nil and (m.mapId == nil or m.rank ~= 4) then
        if m.time then on[m.time] = true else on.MORN, on.DAY, on.NITE = true, true, true end
      end
    end
    return on
  end

  local function encounterCard(self, row, x, y, model)
    local colors, tok = self.colors, self.tok
    local best = row.best or {}
    local now = row.gift and row.available ~= false or best.current
    local pressed = self:beginPress(x, y, CARD_W, CARD_H)
    cardFrame(self, x, y, tok.acc.M, now and not best.blocked)
    self:v4Seat(x + 2, y + 1, 24, false, false)
    if model.drawPokemon then model.drawPokemon(row, x + 4, y + 3, 20, not row.caught and not row.gift) end
    local nameW = CARD_W - 40
    self:partyInfo(self:fitPartyInfo(row.isEgg and translate("EGG") or row.name or "???", nameW), x + 29, y + 1, colors.ink)
    if row.caught then self:v4MiniBall(x + CARD_W - 10, y + 4, "ok")
    elseif not row.gift then self:v4MiniBall(x + CARD_W - 10, y + 4, "none") end
    if row.gift then
      local label = row.trade and "TRADE" or row.loan and "LOAN" or (row.cost or row.coinCost) and "OFFER" or "GIFT"
      self:v4Pill(label, x + 29, y + 13, hex("d05878"), { maxW = 60 })
      return self:endPress(pressed)
    end
    if model.encounterDetails == false then return self:endPress(pressed) end
    -- one quiet line: levels on the left, the odds on the right
    self:partyInfo(levels(best), x + 29, y + 12, colors.mutedInk)
    if best.blocked then
      self:v4Pill("TOOL", x + CARD_W - 4, y + 13, hex("e09a20"), { right = true, maxW = 40 })
    else
      local chance = tonumber(best.chance) or 0
      self:partyInfo(tostring(chance) .. "%", x + CARD_W - 32, y + 12, colors.ink, 28, "right")
      -- a hairline under the card shows the odds at a glance
      local f = max(1, floor((CARD_W - 32) * min(1, chance / 50) + 0.5))
      local cc = chance >= 25 and colors.hp or chance >= 10 and colors.hpMid or hex("c070f0")
      R(x + 29, y + CARD_H - 3, CARD_W - 33, 1, self.dark and hex("3a4652") or hex("d4ddd6"))
      R(x + 29, y + CARD_H - 3, f, 1, cc)
      -- rare finds twinkle while they can appear
      if now and chance > 0 and chance <= 5 and self.motionEnabled ~= false then
        self:wantAmbient(0.3)
        if (self:clock() % 1.8) < 0.7 then
          local sx, sy = x + 5, y + 4
          P(sx, sy, WHITE); P(sx - 1, sy, hex("f8e070")); P(sx + 1, sy, hex("f8e070"))
          P(sx, sy - 1, hex("f8e070")); P(sx, sy + 1, hex("f8e070"))
        end
      end
    end
    if not now and not best.blocked then dimCard(self, x, y) end
    self:endPress(pressed)
  end

  local function statusOf(row, kind)
    if kind == "trainers" then
      return row.missed and "MISSED" or row.done and "BEATEN" or row.status or "OPEN"
    end
    if row.bonus then return "BONUS" end
    return row.done and "FOUND" or row.status == "NOT TRACKED" and "UNKNOWN" or row.status or "OPEN"
  end

  local function listCard(self, row, x, y, model, kind, statusColor)
    local colors = self.colors
    local accent = kind == "trainers" and hex("e05848") or hex("e8a030")
    local status = statusOf(row, kind)
    local done = row.done
    local pressed = self:beginPress(x, y, CARD_W, CARD_H)
    cardFrame(self, x, y, accent, not done)
    CIRC(x + 3, y + 2, 22, colors.outline)
    CIRC(x + 4, y + 3, 20, mix(colors.surface, accent, self.dark and 0.3 or 0.2))
    K.CIRCrows(x + 4, y + 3, 20, 10, 20, mix(colors.surface, accent, self.dark and 0.42 or 0.32))
    if kind == "trainers" then
      if model.drawActor then model.drawActor(row, x + 14, y + 13, 1, false, 20) end
    else
      self:v4ItemInSeat({ icon = row.kind == "hidden" and "item" or row.icon or "item",
        label = row.displayLabel or row.label }, x + 14, y + 13, 22, colors.amberLight)
    end
    local name = row.kind == "hidden" and not done and translate("HIDDEN") or row.displayLabel or row.label or ""
    self:partyInfo(self:fitPartyInfo(name, CARD_W - 33), x + 29, y + 1, done and colors.mutedInk or colors.ink)
    self:v4Pill(status, x + 29, y + 13, statusColor(self, status), { maxW = CARD_W - 33 })
    if done then dimCard(self, x, y) end
    self:endPress(pressed)
  end

  -- Four cards a page; the page keys live in the strip above them.
  function H:explorerPerPage(view, total)
    if view == "fruit" then return math.max(1, total) end
    return 4
  end

  function H:explorerMotionRegion(view, selected, full, page, detailPage)
    if full then return nil end
    if selected then return 97, 210, detailPage end
    return CARD_POS[1][2] - 1, PANEL_B, page
  end

  ---------------------------------------------------------------------------
  -- Map
  ---------------------------------------------------------------------------
  local baseMap = H.explorerMap
  function H:explorerMap(model, retained)
    if not OWN then return baseMap(self, model, retained) end
    local colors = self.colors
    local x, y, w, h = mapFrame(model)
    local focus = focusOf(model)
    local layout = self:mapOverview(model.overview, x, y, w, h, {
      retainFrame = retained, snapshot = model.mapSnapshot, cacheKey = model.mapCacheKey,
      image = model.image, player = model.player, markers = model.markers, focus = focus,
      selected = model.selectedMarker, drawPlayer = model.drawPlayer,
      drawTrainer = model.drawTrainer, full = model.mapFull, zoom = model.mapZoom,
    })
    if model.canScan and model.player and focus == model.player and layout then
      local G = ui.graphics
      local px = layout.left + (model.player.x + 0.5) * layout.tileSize
      local py = layout.top + (model.player.y + 0.5) * layout.tileSize
      local cue = max(6, floor(layout.tileSize * 0.75))
      G.setScissor(layout.innerX, layout.innerY, layout.innerW, layout.innerH)
      K.setc(colors.greenLight)
      G.circle("line", px, py, cue)
      if model.scanProgress and model.scanProgress < 1 then
        G.circle("line", px, py, max(cue + 2, layout.tileSize * math.sqrt(41) * model.scanProgress))
      elseif model.scanHint then
        local label = translate("SCAN")
        local lw = max(24, self:partyInfoWidth(label) + 8)
        local left = max(layout.innerX + 2, min(layout.innerX + layout.innerW - lw - 2, floor(px - lw / 2)))
        local top = max(layout.innerY + 2, floor(py - cue - 13))
        self:v4Pill(label, left, top, cg(self) and self.tok.acc.M or colors.green, { w = lw, raw = true })
        R(floor(px) - 1, top + 11, 3, 2, colors.outline)
      end
      G.setScissor()
    end
  end

  local baseMotion = H.explorerMotionKey
  function H:explorerMotionKey(model, player)
    if not OWN then return baseMotion(self, model, player) end
    return stockMotionKey(layoutOf(model, player), player)
  end

  ---------------------------------------------------------------------------
  -- Detail card for items / trainers / fruit (map 54..94, card 97..210)
  ---------------------------------------------------------------------------
  local HIDDEN_G = { "..#..", ".#.#.", "#.#.#", ".#.#.", "..#.." }
  -- Compass chip: which way and how many steps from the player.
  local function compass(self, x, y, player, target, accent)
    if not (player and target and player.x and player.y and target.x and target.y) then return end
    local colors = self.colors
    local dx, dy = target.x - player.x, target.y - player.y
    local steps = floor(math.abs(dx) + math.abs(dy) + 0.5)
    local d = 30
    CIRC(x, y, d, colors.outline)
    CIRC(x + 1, y + 1, d - 2, colors.surface)
    K.RING(x + 3, y + 3, d - 6, 1, mix(colors.surface, colors.outline, 0.2))
    for _, t in ipairs({ { 14, 2 }, { 14, 26 }, { 2, 14 }, { 26, 14 } }) do R(x + t[1], y + t[2], 2, 2, colors.band) end
    local cx, cy = x + 15, y + 15
    if steps == 0 then
      K.CIRC(cx - 3, cy - 3, 7, accent)
    else
      local len = math.sqrt(dx * dx + dy * dy)
      local ux, uy = dx / len, dy / len
      for k = 0, 9 do
        local px, py = floor(cx + ux * k + 0.5), floor(cy + uy * k + 0.5)
        R(px - 1, py - 1, 2, 2, accent)
      end
      local hx, hy = floor(cx + ux * 10 + 0.5), floor(cy + uy * 10 + 0.5)
      R(hx - 2, hy - 2, 4, 4, accent)
      R(cx - 1, cy - 1, 3, 3, colors.outline)
    end
    local text = steps <= 1 and translate("HERE") or (steps .. " " .. translate("STEPS"))
    self:partyInfo(self:fitPartyInfo(text, 50), x - 10, y + d + 1, colors.mutedInk, d + 20, "center")
  end

  local function infoCard(self, accent, seatDraw, name, status, statusTint, kind, where, kindGlyph, player, target)
    local colors = self.colors
    self.v4SummaryWindow(self, MAP_X, 97, MAP_W, 113, accent)
    CIRC(13, 103, 46, colors.outline)
    CIRC(14, 104, 44, mix(colors.surface, accent, self.dark and 0.3 or 0.2))
    K.CIRCrows(14, 104, 44, 22, 44, mix(colors.surface, accent, self.dark and 0.42 or 0.32))
    R(21, 108, 5, 1, { 1, 1, 1, 0.6 })
    seatDraw(36, 126)
    local nameW = (player and target and target.x) and 112 or 160
    local a, b = self:splitPartyInfo(name, nameW)
    self:partyName(a, 66, 102, colors.ink, nameW)
    if b and #b > 0 then self:partyName(b, 66, 115, colors.ink, nameW) end
    self:v4Pill(status, 66, b and 131 or 120, statusTint, { maxW = 150 })
    compass(self, 186, 108, player, target, accent)
    -- "marked on the map" note under the name, tied to the map above
    local my = b and 145 or 135
    ART({ ".ooo.", "o###o", "o#w#o", "o###o", ".o#o.", "..o.." }, 66, my + 2,
      { o = colors.outline, ["#"] = accent, w = WHITE })
    self:partyInfo(self:fitPartyInfo(translate("MARKED ON MAP"), 150), 74, my, colors.mutedInk)
    -- two fact tiles: what it is, where it is
    local function tile(x, w, label, value, glyph, tint)
      local fill = mix(colors.surface, tint, self.dark and 0.16 or 0.1)
      if cg(self) then CH(x, 158, w, 46, 3, mix(fill, colors.outline, 0.3)); CH(x + 1, 159, w - 2, 44, 2, fill)
      else RR(x, 158, w, 46, 4, mix(fill, colors.outline, 0.3)); RR(x + 1, 159, w - 2, 44, 3, fill) end
      R(x + 4, 159, w - 8, 2, tint)
      self:partyInfo(self:fitPartyInfo(translate(label), w - 10), x, 162, colors.mutedInk, w, "center")
      local a, b2 = self:splitPartyInfo(translate(value), w - 22)
      local gw = glyph and 10 or 0
      local lines = (b2 and #b2 > 0) and { a, b2 } or { a }
      local top = #lines == 2 and 174 or 180
      for i, line in ipairs(lines) do
        local lw = self:partyInfoWidth(line) + (i == 1 and gw or 0)
        local lx = x + floor((w - lw) / 2)
        if i == 1 and glyph then glyph(lx, top + 3); lx = lx + gw end
        self:partyInfo(line, lx, top + (i - 1) * 11, colors.ink)
      end
    end
    tile(13, 104, "KIND", kind, kindGlyph, accent)
    tile(123, 104, "WHERE", where, function(x, y)
      ART({ ".ooo.", "o###o", "o#w#o", "o###o", ".o#o.", "..o.." }, x, y - 1,
        { o = colors.outline, ["#"] = hex("e05848"), w = WHITE })
    end, hex("4888e0"))
  end

  ---------------------------------------------------------------------------
  -- Explorer page
  ---------------------------------------------------------------------------
  local baseExplorer = H.explorer
  function H:explorer(model)
    if not OWN then return baseExplorer(self, model) end
    local colors, view, selected = self.colors, model.view, model.selected
    self:v4RouteHeader(model)
    if model.mapFull then zoomBar(self, model) end
    self:explorerMap(model)
    if model.mapFull then return end

    -- details rise into place; lists cascade card by card (in-place only)
    local G = ui.graphics
    if selected then
      local e = self:v4Enter("explorer_detail", tostring(view) .. ":" .. tostring(selected.key or selected.label or selected.species), 0.2)
      local lift = e < 1 and floor((1 - K.easeOut(e)) * 12 + 0.5) or 0
      if lift ~= 0 then G.push(); G.translate(0, lift) end
      local drawn = self:v4ExplorerDetail(model, selected, view)
      if lift ~= 0 then G.pop() end
      if drawn then return end
    end

    -- list: tabs + panel + control strip + cards
    panel(self)
    tabs(self, model)
    if view == "wild" then scopeSwitch(self, model) end
    if view == "items" and model.itemProgress and model.itemProgress.optional > 0 then
      local bonus = ui.format and ui.format("%d/%d BONUS", model.itemProgress.bonusDone, model.itemProgress.optional)
        or (model.itemProgress.bonusDone .. "/" .. model.itemProgress.optional .. " " .. translate("BONUS"))
      self:partyInfoCentered(self:fitPartyInfo(bonus, 130), MAP_X + 5, STRIP_Y, 130, STRIP_H, colors.mutedInk)
    end
    if model.pages > 1 then self:v4PageKeys(MAP_X + MAP_W - 5, STRIP_Y - 1, model.page, model.pages) end
    local rows = model.rows or {}
    if #rows == 0 then
      local text = view == "wild" and (model.emptyHint or (model.wildScope == "ROUTE"
        and "NO WILD ENCOUNTERS" or "NOTHING HERE NOW")) or "NOTHING HERE"
      self:partyInfo(translate(text), MAP_X, 178, colors.mutedInk, MAP_W, "center")
      return
    end
    local enter = self:v4Enter("explorer_cards", table.concat({ tostring(view),
      tostring(model.wildScope), tostring(model.page) }, ":"), 0.28)
    for index, row in ipairs(rows) do
      local pos = CARD_POS[index]
      if pos then
        local _, dy = self:v4Stagger(enter, index, 0.08, 6)
        if dy ~= 0 then G.push(); G.translate(0, dy) end
        if view == "wild" then encounterCard(self, row, pos[1], pos[2], model)
        else listCard(self, row, pos[1], pos[2], model, view, statusColor) end
        if dy ~= 0 then G.pop() end
      end
    end
  end

  -- Returns true when a detail view was drawn.
  function H:v4ExplorerDetail(model, selected, view)
    local colors = self.colors
    if view == "wild" then
      wildDetail(self, model, selected)
      return true
    elseif view == "fruit" then
      local status = selected.picked and "PICKED TODAY" or "READY TO PICK"
      infoCard(self, colors.green, function(cx, cy) self:fruitIcon(cx - 8, cy - 8, 2, selected.picked) end,
        selected.label or "", status, selected.picked and colors.silverDark or colors.hp,
        "BERRY TREE", "REGROWS DAILY", nil, model.player, selected)
      return true
    elseif view == "items" then
      local status = statusOf(selected, "items")
      local kind = selected.gift and "NPC GIFT" or selected.kind == "hidden" and "HIDDEN" or "VISIBLE"
      infoCard(self, hex("e8a030"), function(cx, cy)
        self:v4ItemInSeat({ icon = selected.kind == "hidden" and "item" or selected.icon or "item",
          label = selected.displayLabel or selected.label }, cx, cy, 42, colors.amberLight)
      end, selected.displayLabel or selected.label or "", status, statusColor(self, status), kind,
        (selected.location and selected.location ~= "MARKED ON MAP") and selected.location or "ON THIS MAP",
        selected.kind == "hidden" and function(x, y)
          ART(HIDDEN_G, x, y, { ["#"] = colors.green })
        end or function(x, y)
          ART({ ".ooo.", "o.#.o", "o###o", "o.#.o", ".ooo." }, x, y, { o = colors.outline, ["#"] = hex("4888e0") })
        end, model.player, selected.remote and model.selectedMarker or not selected.remote and selected)
      if selected.remote and not selected.outsideMap and selected.x ~= nil and selected.y ~= nil then
        local pressed = self:beginPress(123, 158, 104, 46, true)
        self:v4Key(123, 158, 104, 46)
        local label = self:fitPartyInfo(translate(selected.indoor and "SHOW INSIDE" or "MAP"), 92)
        self:partyInfoCentered(label, 129, 159, 92, 44, cg(self) and self.tok.acc.M or colors.green)
        self:endPress(pressed)
      end
      return true
    elseif view == "trainers" then
      local status = statusOf(selected, "trainers")
      local where = selected.missed and "UNAVAILABLE" or selected.status == "LATER" and "STORY EVENT"
        or selected.location or "ON THIS MAP"
      infoCard(self, hex("e05848"), function(cx, cy)
        if model.drawActor then model.drawActor(selected, cx, cy, 2, false, 40) end
      end, selected.label or "", status, statusColor(self, status), "TRAINER", where, function(x, y)
        ART({ ".ooo.", "o###o", ".ooo.", "o###o", "o###o" }, x, y - 1, { o = colors.outline, ["#"] = hex("e05848") })
      end, model.player, selected)
      return true
    end

    return false
  end

  local baseHit = H.explorerHit
  function H:explorerHit(x, y, model)
    if not OWN then return baseHit(self, x, y, model) end
    x, y = x * 1.5, y * 1.5
    if not model.overview.disabled and x >= 202 and x < 233 and y >= HEADER_Y and y < HEADER_Y + HEADER_H then return "map_toggle" end
    if model.mapFull and y >= 54 and y < 71 then
      if x >= 11 and x < 29 and (model.mapZoom or 1) > 1 then return "zoom_out" end
      if x >= 64 and x < 82 and (model.mapZoom or 1) < 3 then return "zoom_in" end
      return nil
    end
    local mx, my, mw, mh = mapFrame(model)
    local focus = focusOf(model)
    if model.canScan and model.player and focus == model.player then
      local layout = layoutOf(model)
      if layout then
        local px = layout.left + (model.player.x + 0.5) * layout.tileSize
        local py = layout.top + (model.player.y + 0.5) * layout.tileSize
        local radius = max(12, layout.tileSize)
        if (x - px) ^ 2 + (y - py) ^ 2 <= radius ^ 2 then return "player_scan" end
      end
    end
    local marker = self:mapMarkerAt(x, y, model.overview, { x = mx, y = my, w = mw, h = mh }, {
      player = model.player, focus = focus, markers = model.markers, full = model.mapFull, zoom = model.mapZoom })
    if marker then return "marker", marker end
    if model.mapFull then return nil end
    if model.selected then
      if not model.overview.disabled and model.view == "items" and model.selected.remote and not model.selected.outsideMap
          and model.selected.x ~= nil and model.selected.y ~= nil
          and x >= 123 and x < 227 and y >= 158 and y < 204 then return "locate" end
      if model.view == "wild" and (model.detailPages or 1) > 1 and y >= 103 and y < 123 then
        local px, rx = pagerRects(226, 105)
        if x >= px - 2 and x < px + PAGER_KEY + 2 then return "detail_prev" end
        if x >= rx - 2 and x < rx + PAGER_KEY + 2 then return "detail_next" end
      end
      return nil
    end
    if y >= TAB_Y and y < TAB_Y + TAB_H then
      for i, view in ipairs({ "wild", "trainers", "items" }) do
        local tx, tw = tabRect(i)
        if x >= tx and x < tx + tw then
          if view ~= model.view then return view end
          return nil
        end
      end
      return nil
    end
    if y >= STRIP_Y - 2 and y < STRIP_Y + STRIP_H + 1 then
      if model.view == "wild" and x >= MAP_X + 5 and x < MAP_X + 83 then
        local route = x >= MAP_X + 45
        if route ~= (model.wildScope == "ROUTE") then return route and "wild_route" or "wild_here" end
        return nil
      end
      if model.pages > 1 then
        local px, rx = pagerRects(MAP_X + MAP_W - 5, STRIP_Y - 1)
        if x >= px - 2 and x < px + PAGER_KEY + 2 then return "prev" end
        if x >= rx - 2 and x < rx + PAGER_KEY + 2 then return "next" end
      end
      return nil
    end
    for index, pos in ipairs(CARD_POS) do
      if x >= pos[1] and x < pos[1] + CARD_W and y >= pos[2] - 1 and y < pos[2] + CARD_H + 1 then
        if model.rows and model.rows[index] then return "row", index end
      end
    end
    return nil
  end

  ---------------------------------------------------------------------------
  -- Item radar: a Pokétch-style LCD with a rotating sweep.
  ---------------------------------------------------------------------------
  function H:explorerRadar(model)
    local G, colors = ui.graphics, self.colors
    local pressed = self:beginPress(7, 32, 226, 178)
    local tok = self.tok
    local lcdBg = cg(self) and (self.dark and hex("7fa8b8") or hex("a8d0dc")) or (self.dark and hex("8aa878") or hex("b0d098"))
    local lcdOn = cg(self) and hex("16303c") or hex("203820")
    local lcdOff = mix(lcdBg, lcdOn, 0.16)
    -- device body
    if cg(self) then CH(7, 32, 226, 178, 8, colors.outline); CH(8, 33, 224, 176, 7, self.dark and hex("2a3440") or hex("5a6878"))
    else RR(7, 32, 226, 178, 8, colors.outline); RR(8, 33, 224, 176, 7, self.dark and hex("3a4250") or hex("68707c"))
      R(14, 34, 212, 1, { 1, 1, 1, 0.25 }) end
    -- LCD
    local lx, ly, lw, lh = 16, 40, 208, 132
    RR(lx - 1, ly - 1, lw + 2, lh + 2, 3, colors.outline)
    RR(lx, ly, lw, lh, 2, lcdBg)
    for x = lx + 8, lx + lw - 2, 8 do R(x, ly + 2, 1, lh - 4, lcdOff) end
    for y = ly + 6, ly + lh - 2, 8 do R(lx + 2, y, lw - 4, 1, lcdOff) end
    local cx, cy = 120, 106
    local progress = max(0, min(1, model.progress or 0))
    -- Game path [Gen 3 vs Gen 1/2]: scanner radius and grid aspect mirror different native scan reach; keep drawing aligned with hit/proof geometry.
    local radius = floor((model.gen3 and 78 or 70) * progress)
    G.setScissor(lx + 1, ly + 1, lw - 2, lh - 2)
    -- concentric rings
    for r = 20, 80, 20 do
      local d = r * 2
      RING(cx - r, cy - r, d, 1, lcdOff)
    end
    if radius > 0 and not model.ready then RING(cx - radius, cy - radius, radius * 2, 1, lcdOn) end
    -- rotating sweep once ready
    local t = self:clock()
    if model.ready and self.motionEnabled ~= false then
      local a = (t * 1.6) % (2 * math.pi)
      for k = 0, 9 do
        local aa = a - k * 0.035
        for s = 6, 82, 2 do
          local px, py = floor(cx + math.cos(aa) * s + 0.5), floor(cy + math.sin(aa) * s + 0.5)
          if k == 0 then P(px, py, lcdOn) elseif k < 4 then P(px, py, mix(lcdBg, lcdOn, 0.45)) else
            if s % 4 == 0 then P(px, py, mix(lcdBg, lcdOn, 0.25)) end end
        end
      end
      self:wantAmbient(0.4, 1 / 15)
    end
    for i, signal in ipairs(model.signals or {}) do
      local cell, reachY = model.gen3 and 9 or 11, model.gen3 and 5 or 4
      local sx = cx + max(-7, min(7, signal.dx or 0)) * cell
      local sy = cy + max(-reachY, min(reachY, signal.dy or 0)) * cell
      local distance = math.sqrt((sx - cx) ^ 2 + (sy - cy) ^ 2)
      if distance <= radius or model.ready then
        local blink = model.ready and floor(t / 0.35 + i) % 2 == 0
        R(sx - 4, sy - 4, 9, 9, lcdOn)
        R(sx - 3, sy - 3, 7, 7, blink and lcdOn or lcdBg)
        R(sx - 1, sy - 1, 3, 3, lcdOn)
      end
    end
    G.setScissor()
    -- you
    R(cx - 4, cy - 4, 9, 9, lcdOn); R(cx - 2, cy - 2, 5, 5, lcdBg); P(cx, cy, lcdOn)
    -- LCD captions
    self:withoutShadow(function()
      self:partyInfo(self:fitPartyType(model.route or translate("UNKNOWN AREA"), 120), lx + 4, ly + 2, lcdOn)
      local state = translate(model.ready and "SCAN COMPLETE" or "SCANNING")
      self:partyInfo(state, lx + lw - 4 - self:partyInfoWidth(state), ly + 2, lcdOn)
    end)
    -- LCD readout: how many signals, as the Pokétch dowsing app shows it
    local count = #(model.signals or {})
    self:withoutShadow(function()
      local bx, by = lx + 5, ly + lh - 14
      R(bx, by + 2, 9, 9, lcdOn); R(bx + 1, by + 3, 7, 7, lcdBg); R(bx + 3, by + 5, 3, 3, lcdOn)
      local status = not model.ready and translate("SEARCHING...")
        or count == 0 and translate("NO SIGNAL") or ("× " .. count)
      self:partyInfo(self:fitPartyInfo(status, 150), bx + 13, by, lcdOn)
    end)
    -- the whole device rescans; the key under the screen says so
    local key = K.rampOf(cg(self) and tok.acc.M or hex("3ea04c"))
    local kx, ky, kw, kh = 50, 178, 140, 26
    local off = self:v4Button(kx, ky, kw, kh, key, { radius = 6, lip = 3, chamfer = 5 })
    local label = self:fitPartyInfo(translate("TAP TO SCAN AGAIN"), kw - 30)
    local tw = self:partyInfoWidth(label)
    local gx = kx + floor((kw - tw - 14) / 2)
    RING(gx, ky + 6 + off, 10, 1, WHITE); P(gx + 4, ky + 10 + off, WHITE); P(gx + 5, ky + 10 + off, WHITE)
    R(gx + 5, ky + 7 + off, 1, 4, WHITE)
    self:partyInfo(label, gx + 14, ky + 6 + off, WHITE)
    if not model.ready then self:wantAmbient(0.3, 1 / 20) end
    self:endPress(pressed)
  end
end
