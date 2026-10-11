-- Kanto Gear v4: Explorer (route header, encounter cards, habitat details,
-- item/trainer/fruit cards, full-map tools and the radar).
-- Geometry contract with hgss.lua/explorerHit: header 32..50, toggle 202..232,
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
    -- pager (hit 166..224 × 106..122)
    if model.detailPages > 1 then
      local pressed = self:beginPress(166, 106, 58, 16)
      self:v4Key(166, 106, 58, 15)
      self:partyType(model.detailPage .. "/" .. model.detailPages, 166, 108, colors.ink, 58)
      ART({ "#..", "##.", "###", "##.", "#.." }, 216, 111, { ["#"] = colors.mutedInk })
      ART({ "..#", ".##", "###", ".##", "..#" }, 171, 111, { ["#"] = colors.mutedInk })
      self:endPress(pressed)
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
  -- Geometry. Explorer owns its map frame: the hgss map layout helper is
  -- reached through the stock motion-key closure so movement repaints,
  -- marker hits and scan cues all agree with what is drawn.
  ---------------------------------------------------------------------------
  local HEADER_Y, HEADER_H = 32, 20
  local MAP_X, MAP_W = 7, 226
  local MAP_Y, MAP_H = 54, 64          -- overview
  local DETAIL_MAP_H = 40              -- any selection
  local FULL_Y, FULL_H = 74, 136       -- expanded map
  local TAB_Y, TAB_H, TAB_W, TAB_STEP = 121, 17, 54, 56
  local PANEL_Y = 137
  local CARD_W, CARD_H = 109, 33
  local CARD_POS = { { 10, 141 }, { 121, 141 }, { 10, 176 }, { 121, 176 } }

  local stockLayout, stockMotionKey
  do
    local motion = K.base.explorerMotionKey
    if motion and debug and debug.getupvalue then
      for i = 1, 40 do
        local name, value = debug.getupvalue(motion, i)
        if not name then break end
        if name == "mapLayout" then stockLayout = value end
        if name == "mapMotionKey" then stockMotionKey = value end
      end
    end
  end

  local function mapFrame(model)
    if model.mapFull then return MAP_X, FULL_Y, MAP_W, FULL_H end
    if model.selected then return MAP_X, MAP_Y, MAP_W, DETAIL_MAP_H end
    return MAP_X, MAP_Y, MAP_W, MAP_H
  end
  local function focusOf(model)
    local marker = model.selectedMarker
    return marker and (marker.kind == "trainer" or marker.kind == "fruit" or marker.gift) and marker or model.player
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
    local pressed = self:beginPress(208, HEADER_Y + 3, 21, 14)
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

  -- Folder tabs joined to the list panel below.
  local function tabs(self, model)
    local colors = self.colors
    local counts = { wild = tostring(model.wildCount or model.total or 0),
      trainers = tostring(model.trainersText or "0"), items = tostring(model.itemsText or "0") }
    local labels = { wild = "WILD", trainers = "TRAINERS", items = "ITEMS" }
    local active = model.view
    for i, view in ipairs({ "wild", "trainers", "items" }) do
      local x = MAP_X + (i - 1) * TAB_STEP
      local on = view == active
      local pressed = self:beginPress(x, TAB_Y, TAB_W, TAB_H, not on)
      local fill = on and colors.surface or (self.dark and mix(colors.surface, colors.outline, 0.35) or colors.bandLight)
      if cg(self) then
        CH(x, TAB_Y, TAB_W, TAB_H + (on and 3 or 0), 3, on and self.tok.border or colors.outline)
        CH(x + 1, TAB_Y + 1, TAB_W - 2, TAB_H + (on and 3 or -2), 2, fill)
        if on then R(x + 3, TAB_Y + 1, TAB_W - 6, 2, self.tok.acc.M) end
      else
        RR(x, TAB_Y, TAB_W, TAB_H + (on and 4 or 0), 4, colors.outline)
        RR(x + 1, TAB_Y + 1, TAB_W - 2, TAB_H + (on and 4 or -2), 3, fill)
        if on then R(x + 4, TAB_Y + 1, TAB_W - 8, 1, WHITE) end
      end
      local icon = TAB_ICON[view]
      local tint = hex(icon.tint)
      if not on then tint = mix(tint, colors.surface, 0.35) end
      local label = self:fitPartyInfo(translate(labels[view]), TAB_W - 14)
      local count = counts[view]
      local lw = self:partyInfoWidth(label)
      local iconW = #icon.art[1]
      local total = iconW + 3 + lw
      local lx = x + floor((TAB_W - total) / 2)
      ART(icon.art, lx, TAB_Y + floor((TAB_H - #icon.art) / 2), { o = colors.outline, ["#"] = tint, w = on and hex("f8c8a0") or colors.surface })
      self:partyInfo(label, lx + iconW + 3, TAB_Y + 2, on and colors.ink or colors.mutedInk)
      self:endPress(pressed)
      model.tabCounts = model.tabCounts or {}
      model.tabCounts[view] = count
    end
  end

  local function panel(self)
    local colors = self.colors
    self:v4Window(MAP_X, PANEL_Y, MAP_W, 210 - PANEL_Y)
  end

  local function scopeSwitch(self, model)
    -- HERE | ALL lives in the free tab-row space to the right.
    local x, y, w = MAP_X + 3 * TAB_STEP + 2, TAB_Y + 1, MAP_W - 3 * TAB_STEP - 2
    local scope = model.wildScope == "ROUTE" and "ROUTE" or "HERE"
    self:v4Segments(x, y - 1, w, { { "HERE", "HERE" }, { "ALL", "ROUTE" } }, scope, true)
  end

  ---------------------------------------------------------------------------
  -- Cards
  ---------------------------------------------------------------------------
  local function cardFrame(self, x, y, accent, dim)
    local colors = self.colors
    local fill = dim and (self.dark and mix(colors.surface, colors.outline, 0.25) or colors.bandLight)
      or mix(colors.surface, accent, self.dark and 0.14 or 0.08)
    if cg(self) then
      CH(x, y, CARD_W, CARD_H, 4, colors.outline); CH(x + 1, y + 1, CARD_W - 2, CARD_H - 2, 3, fill)
      R(x + 1, y + 5, 2, CARD_H - 10, accent)
    else
      RR(x, y, CARD_W, CARD_H, 4, colors.outline); RR(x + 1, y + 1, CARD_W - 2, CARD_H - 2, 3, fill)
      R(x + 4, y + 1, CARD_W - 8, 1, self.dark and mix(fill, WHITE, 0.1) or WHITE)
    end
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
    local colors = self.colors
    local typeId = row.type or row.types and row.types[1]
    local accent = self:typeColor(typeId)
    local best = row.best or {}
    local now = row.gift and row.available ~= false or best.current
    local dim = not now
    local pressed = self:beginPress(x, y, CARD_W, CARD_H)
    cardFrame(self, x, y, accent, dim)
    self:v4Seat(x + 3, y + 2, 29, false, now)
    if model.drawPokemon then model.drawPokemon(row, x + 4, y + 3, 27, not row.caught and not row.gift) end
    local ink, quiet = dim and colors.mutedInk or colors.ink, colors.mutedInk
    self:partyInfo(self:fitPartyInfo(row.isEgg and translate("EGG") or row.name or "???", 60), x + 35, y + 1, ink)
    if row.caught then self:v4MiniBall(x + CARD_W - 10, y + 3, "ok")
    elseif not row.gift then self:v4MiniBall(x + CARD_W - 10, y + 3, "none") end
    if row.gift then
      local label = row.trade and "TRADE" or row.loan and "LOAN" or (row.cost or row.coinCost) and "OFFER" or "GIFT"
      self:v4MethodGlyph("GIFT", x + 35, y + 13)
      self:v4Pill(label, x + 45, y + 12, hex("d05878"), { maxW = 56 })
      return self:endPress(pressed)
    end
    self:v4MethodGlyph(best.method, x + 35, y + 13, dim and colors.silverDark or nil)
    self:partyInfo(levels(best), x + 45, y + 11, quiet)
    if best.blocked then
      self:v4Pill("TOOL", x + CARD_W - 4, y + 12, hex("d89020"), { right = true })
    elseif model.period then
      local on = periodsFor(row)
      for i, p in ipairs(PERIOD_ORDER) do
        local px = x + CARD_W - 22 + (i - 1) * 6
        local c = on[p] and hex(PERIOD_TINT[p]) or (self.dark and hex("3a4450") or hex("d0d6cc"))
        ART(MINI_PERIOD[p], px, y + 13, { ["#"] = c })
        if p == model.period then R(px, y + 19, 5, 1, on[p] and c or colors.silver) end
      end
    end
    -- chance bar + percentage
    local pct = tostring(best.chance or 0) .. "%"
    local pw = self:partyInfoWidth(pct)
    self:v4ChanceBar(x + 35, y + 25, CARD_W - 41 - pw, dim and 0 or best.chance)
    if dim then R(x + 36, y + 26, floor((CARD_W - 43 - pw) * math.min(1, (best.chance or 0) / 60)), 1, colors.silverDark) end
    self:partyInfo(pct, x + CARD_W - 4 - pw, y + 21, ink)
    self:endPress(pressed)
  end

  local function statusOf(row, kind)
    if kind == "trainers" then
      return row.missed and "MISSED" or row.done and "BEATEN" or row.status or "OPEN"
    end
    return row.done and "FOUND" or row.status == "NOT TRACKED" and "UNKNOWN" or row.status or "OPEN"
  end

  local function listCard(self, row, x, y, model, kind, statusColor)
    local colors = self.colors
    local accent = kind == "trainers" and hex("e05848") or hex("e8a030")
    local status = statusOf(row, kind)
    local done = row.done
    local pressed = self:beginPress(x, y, CARD_W, CARD_H)
    cardFrame(self, x, y, accent, done)
    CIRC(x + 3, y + 2, 29, colors.outline)
    CIRC(x + 4, y + 3, 27, mix(colors.surface, accent, self.dark and 0.3 or 0.2))
    K.CIRCrows(x + 4, y + 3, 27, 14, 27, mix(colors.surface, accent, self.dark and 0.42 or 0.32))
    if kind == "trainers" then
      if model.drawActor then model.drawActor(row, x + 17, y + 25, 1, false) end
    else
      self:battleItemIcon({ icon = row.kind == "hidden" and "item" or row.icon or "item" }, x + 8, y + 8, colors.amberLight)
    end
    local name = row.kind == "hidden" and not done and translate("HIDDEN") or row.displayLabel or row.label or ""
    local a, b = self:splitPartyInfo(name, CARD_W - 40)
    if b and #b > 0 then
      self:partyInfo(a, x + 35, y + 0, done and colors.mutedInk or colors.ink)
      self:partyInfo(self:fitPartyInfo(b, CARD_W - 40), x + 35, y + 10, done and colors.mutedInk or colors.ink)
    else
      self:partyInfo(self:fitPartyInfo(name, CARD_W - 40), x + 35, y + 3, done and colors.mutedInk or colors.ink)
    end
    self:v4Pill(status, x + 35, y + 20, statusColor(self, status), { maxW = CARD_W - 40 })
    self:endPress(pressed)
  end

  local function pagerCard(self, x, y, model)
    local colors = self.colors
    local enabled = model.pages > 1
    self:v4Window(x, y, CARD_W, CARD_H, { fill = colors.bandLight, shadow = false })
    local half = floor(CARD_W / 2)
    local p1 = self:beginPress(x, y, half, CARD_H, enabled)
    ART(CHEV_L, x + 10, y + 14, { ["#"] = colors.ink }); self:endPress(p1)
    local p2 = self:beginPress(x + half, y, CARD_W - half, CARD_H, enabled)
    ART(CHEV_R, x + CARD_W - 13, y + 14, { ["#"] = colors.ink }); self:endPress(p2)
    self:partyInfo(model.page .. "/" .. model.pages, x + 16, y + 6, colors.ink, CARD_W - 32, "center")
    for i = 1, min(model.pages, 6) do
      local dx = x + floor(CARD_W / 2) - min(model.pages, 6) * 3 + (i - 1) * 6
      R(dx, y + 22, 4, 4, i == model.page and (cg(self) and self.tok.acc.M or colors.green) or colors.silver)
    end
  end

  -- Main shows ≤4 rows when they all fit, otherwise 3 rows + a pager card.
  function H:explorerPerPage(view, total)
    if view == "fruit" then return math.max(1, total) end
    return total <= 4 and 4 or 3
  end

  function H:explorerMotionRegion(view, selected, full, page, detailPage)
    if full then return nil end
    if selected then return 97, 210, detailPage end
    return PANEL_Y + 2, 210, page
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
    local steps = math.abs(dx) + math.abs(dy)
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

    -- list: tabs + panel + cards
    panel(self)
    tabs(self, model)
    if view == "wild" then scopeSwitch(self, model) end
    local rows = model.rows or {}
    if #rows == 0 then
      local text = view == "wild" and (model.emptyHint or (model.wildScope == "ROUTE"
        and "NO WILD ENCOUNTERS" or "NOTHING HERE NOW")) or "NOTHING HERE"
      self:partyInfo(translate(text), MAP_X, 166, colors.mutedInk, MAP_W, "center")
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
    if model.pages > 1 then
      local _, dy = self:v4Stagger(enter, 4, 0.08, 6)
      if dy ~= 0 then G.push(); G.translate(0, dy) end
      pagerCard(self, CARD_POS[4][1], CARD_POS[4][2], model)
      if dy ~= 0 then G.pop() end
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
        end, model.player, selected)
      return true
    elseif view == "trainers" then
      local status = statusOf(selected, "trainers")
      local where = selected.missed and "UNAVAILABLE" or selected.status == "LATER" and "STORY EVENT"
        or selected.location or "ON THIS MAP"
      infoCard(self, hex("e05848"), function(cx, cy)
        if model.drawActor then model.drawActor(selected, cx, cy + 8, 2, false) end
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
    if x >= 202 and x < 233 and y >= HEADER_Y and y < HEADER_Y + HEADER_H then return "map_toggle" end
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
      if model.view == "wild" and x >= 166 and x < 224 and y >= 106 and y < 122 and (model.detailPages or 1) > 1 then
        return x < 195 and "detail_prev" or "detail_next"
      end
      return nil
    end
    if y >= TAB_Y and y < TAB_Y + TAB_H then
      for i, view in ipairs({ "wild", "trainers", "items" }) do
        local tx = MAP_X + (i - 1) * TAB_STEP
        if x >= tx and x < tx + TAB_W then return view ~= model.view and view or nil end
      end
      if model.view == "wild" and x >= MAP_X + 3 * TAB_STEP + 2 then
        local sx = MAP_X + 3 * TAB_STEP + 2
        local half = floor((MAP_W - 3 * TAB_STEP - 2) / 2)
        if x < sx + half then return model.wildScope ~= "ROUTE" and nil or "wild_here" end
        return model.wildScope == "ROUTE" and nil or "wild_route"
      end
      return nil
    end
    for index, pos in ipairs(CARD_POS) do
      if x >= pos[1] and x < pos[1] + CARD_W and y >= pos[2] and y < pos[2] + CARD_H then
        if model.pages > 1 and index == 4 then
          return x < pos[1] + floor(CARD_W / 2) and "prev" or "next"
        end
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
    local count = #(model.signals or {})
    local status = not model.ready and translate("SEARCHING...")
      or count == 0 and translate("NO SIGNAL") or string.format("SIGNALS %d", count)
    self:partyInfo(self:fitPartyInfo(status, 200), 20, 176, WHITE, 200, "center")
    self:partyType(self:fitPartyType(translate("TAP TO SCAN AGAIN"), 200), 20, 192,
      self.dark and colors.silver or hex("e0e8f0"), 200)
    if not model.ready then self:wantAmbient(0.3, 1 / 20) end
    self:endPress(pressed)
  end
end
