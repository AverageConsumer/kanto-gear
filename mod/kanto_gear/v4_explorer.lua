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

  ---------------------------------------------------------------------------
  -- Route header + map tools
  ---------------------------------------------------------------------------
  local PIN = { ".ooo.", "o###o", "o#w#o", "o###o", ".o#o.", "..o.." }
  local EXPAND = { "##..##", "#....#", "......", "......", "#....#", "##..##" }
  local COLLAPSE = { "#....#", ".#..#.", "......", "......", ".#..#.", "#....#" }

  function H:v4RouteHeader(model)
    local colors, tok = self.colors, self.tok
    local accent = cg(self) and tok.acc.M or colors.green
    self:v4Window(7, 32, 226, 18, { fill = mix(colors.surface, accent, self.dark and 0.12 or 0.07) })
    ART(PIN, 12, 38, { o = colors.outline, ["#"] = hex("e05848"), w = WHITE })
    local route = self:fitPartyInfo(model.route or translate("UNKNOWN AREA"), 80)
    self:partyInfo(route, 20, 35, colors.ink)
    local rw = self:partyInfoWidth(route)
    local sub = self:fitPartyType(model.subarea or translate("OUTDOORS"), 160 - rw - 40)
    local region = self:fitPartyType(model.region or "KANTO", 44)
    local x = 20 + rw + 6
    R(x, 38, 1, 7, colors.band)
    self:partyInfo(sub, x + 4, 36, colors.green)
    local regW = self:partyInfoWidth(region)
    self:partyInfo(region, 199 - regW, 36, colors.mutedInk)
    -- map toggle (hit 202..232 × 32..50)
    local pressed = self:beginPress(206, 34, 21, 14)
    self:v4Key(206, 34, 21, 14)
    ART(model.mapFull and COLLAPSE or EXPAND, 213, 37, { ["#"] = colors.ink })
    self:endPress(pressed)
  end

  local function zoomBar(self, model)
    local colors = self.colors
    self:v4Window(7, 53, 226, 16)
    local zoom = model.mapZoom or 1
    local minus = self:beginPress(11, 54, 18, 14, zoom > 1)
    self:v4Key(11, 55, 18, 12, zoom > 1 and nil or { cap = colors.bandLight, lip = colors.band, hi = colors.bandLight })
    R(17, 60, 6, 2, zoom > 1 and colors.ink or colors.disabledInk)
    self:endPress(minus)
    -- zoom pips
    for i = 1, 3 do
      local on = i <= zoom
      local px = 36 + (i - 1) * 8
      R(px, 58, 6, 6, colors.outline)
      R(px + 1, 59, 4, 4, on and (cg(self) and self.tok.acc.M or colors.green) or colors.bandLight)
    end
    local plus = self:beginPress(64, 54, 18, 14, zoom < 3)
    self:v4Key(64, 55, 18, 12, zoom < 3 and nil or { cap = colors.bandLight, lip = colors.band, hi = colors.bandLight })
    local c = zoom < 3 and colors.ink or colors.disabledInk
    R(70, 60, 6, 2, c); R(72, 58, 2, 6, c)
    self:endPress(plus)
    if not model.showMapStats then return end
    R(85, 56, 1, 10, colors.band)
    R(157, 56, 1, 10, colors.band)
    -- items
    local itemsText = tostring(model.itemsText or "--")
    local iw = self:partyInfoWidth(itemsText)
    local left = 86 + floor((71 - 12 - iw) / 2)
    ART({ "..ooo..", ".o...o.", "ooooooo", "o#####o", "o##o##o", "o#####o", "ooooooo" }, left, 57,
      { o = colors.outline, ["#"] = colors.amberLight })
    self:partyInfo(itemsText, left + 11, 55, colors.ink)
    local trainersText = tostring(model.trainersText or "--")
    local tw = self:partyInfoWidth(trainersText)
    local hasTrainer = model.drawActor and model.trainerIcon
    local tl = 158 + floor((71 - (hasTrainer and 11 or 0) - tw) / 2)
    if hasTrainer then model.drawActor(model.trainerIcon, tl + 4, 61, 0.5, false) end
    self:partyInfo(trainersText, tl + (hasTrainer and 11 or 0), 55, colors.ink)
  end

  ---------------------------------------------------------------------------
  -- Encounter cards (overview)
  ---------------------------------------------------------------------------
  local CARD_W, CARD_GAP, CARD_Y, CARD_H = 54, 3, 162, 48
  local function cardX(index) return 7 + (index - 1) * (CARD_W + CARD_GAP) end

  function H:v4EncounterCard(row, x, y, model)
    local colors = self.colors
    local accent = self:typeColor(row.type)
    local pressed = self:beginPress(x, y, CARD_W, CARD_H)
    local here = row.best and row.best.current
    self:v4Window(x, y, CARD_W, CARD_H, { fill = mix(colors.surface, accent, self.dark and 0.16 or 0.1) })
    -- type lip
    if cg(self) then R(x + 1, y + 3, 2, CARD_H - 6, accent)
    else R(x + 4, y + 1, CARD_W - 8, 2, accent) end
    local uncaught = not row.caught
    self:v4Seat(x + 12, y + 3, 30, false, here)
    if model.drawPokemon then model.drawPokemon(row, x + 13, y + 4, 28, uncaught) end
    if row.caught then self:v4MiniBall(x + CARD_W - 10, y + 4, "ok")
    elseif not row.gift then self:v4MiniBall(x + CARD_W - 10, y + 4, "none") end
    if here then
      local t = self:clock()
      local c = hex("f8d048")
      if floor(t / 0.5) % 2 == 0 then P(x + 5, y + 5, c); R(x + 4, y + 6, 3, 1, c); P(x + 5, y + 7, c) end
      self:wantAmbient(0.5)
    end
    if row.gift then
      local label = row.trade and "TRADE" or row.loan and "LOAN" or (row.cost or row.coinCost) and "OFFER" or "GIFT"
      self:v4MethodGlyph("GIFT", x + 5, y + 35)
      self:partyInfo(self:fitPartyType(translate(label), CARD_W - 16), x + 14, y + 33,
        row.available and colors.ink or colors.mutedInk)
    elseif row.best then
      self:v4MethodGlyph(row.best.method, x + 5, y + 35)
      local odds = tostring(row.best.chance or 0) .. "%"
      self:partyInfo(odds, x + 14, y + 33, here and colors.ink or colors.mutedInk)
      if row.best.time and K.periodIcon then
        K.periodIcon(row.best.time, x + CARD_W - 12, y + 35, colors.mutedInk)
      end
      self:v4ChanceBar(x + 5, y + CARD_H - 6, CARD_W - 10, row.best.chance)
    end
    self:endPress(pressed)
  end

  ---------------------------------------------------------------------------
  -- Detail cards
  ---------------------------------------------------------------------------
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

  -- Item / trainer / fruit cards share one layout: seat · name · status | kind · where
  local function infoCard(self, accent, seatDraw, name, status, kind, where, kindGlyph)
    local colors = self.colors
    self:v4Window(7, 140, 226, 70, { fill = mix(colors.surface, accent, self.dark and 0.12 or 0.07) })
    if cg(self) then R(8, 144, 2, 62, accent) else R(11, 141, 218, 2, accent) end
    CIRC(13, 149, 40, colors.outline)
    CIRC(14, 150, 38, mix(colors.surface, accent, self.dark and 0.3 or 0.22))
    K.CIRCrows(14, 150, 38, 19, 38, mix(colors.surface, accent, self.dark and 0.42 or 0.34))
    R(20, 153, 4, 1, { 1, 1, 1, 0.6 })
    seatDraw(33, 169)
    local line1, line2 = self:splitPartyInfo(name, 70)
    local nameY = line2 and 146 or 152
    self:partyInfo(line1, 58, nameY, colors.ink)
    if line2 then self:partyInfo(line2, 58, nameY + 12, colors.ink) end
    self:v4Pill(status, 58, 180, statusColor(self, status), { maxW = 72 })
    R(134, 148, 1, 54, colors.band)
    local kx = 140
    if kindGlyph then kindGlyph(kx, 157); kx = kx + 11 end
    self:partyInfo(self:fitPartyType(translate(kind), 225 - kx), kx, 155, colors.green)
    local lines = { self:splitPartyInfo(translate(where), 86) }
    for i, line in ipairs(lines) do self:partyInfo(line, 140, 172 + (i - 1) * 12, colors.ink) end
  end

  local HIDDEN = { "..#..", ".#.#.", "#.#.#", ".#.#.", "..#.." }

  ---------------------------------------------------------------------------
  -- Explorer page
  ---------------------------------------------------------------------------
  function H:explorer(model)
    local colors, view, selected = self.colors, model.view, model.selected
    self:v4RouteHeader(model)
    if model.mapFull then zoomBar(self, model) end
    self:explorerMap(model)
    if model.mapFull then return end

    if selected and view == "wild" then
      wildDetail(self, model, selected)
      return
    elseif selected and view == "fruit" then
      local status = selected.picked and "PICKED TODAY" or "READY TO PICK"
      infoCard(self, colors.green, function(cx, cy)
        self:fruitIcon(cx - 8, cy - 8, 2, selected.picked)
      end, selected.label or "", status, "BERRY TREE", "REGROWS DAILY")
      return
    elseif selected and view == "items" then
      local status = selected.done and "FOUND" or selected.status == "NOT TRACKED" and "UNKNOWN"
        or selected.status or "OPEN"
      local kind = selected.gift and "NPC GIFT" or selected.kind == "hidden" and "HIDDEN" or "VISIBLE"
      infoCard(self, colors.amberLight, function(cx, cy)
        self:battleItemIcon({ icon = selected.kind == "hidden" and "item" or selected.icon or "item" },
          cx - 10, cy - 3, colors.amberLight)
      end, selected.displayLabel or selected.label or "", status, kind,
        selected.location or "ON THIS MAP", selected.kind == "hidden" and function(x, y)
          ART(HIDDEN, x, y, { ["#"] = colors.green })
        end or nil)
      return
    elseif selected and view == "trainers" then
      local status = selected.missed and "MISSED" or selected.done and "BEATEN" or selected.status or "OPEN"
      local where = selected.missed and "UNAVAILABLE" or selected.status == "LATER" and "STORY EVENT"
        or selected.status or "ON THIS MAP"
      infoCard(self, colors.blueLight, function(cx, cy)
        if model.drawActor then model.drawActor(selected, cx, cy + 9, 1, false) end
      end, selected.label or "", status, "TRAINER", where)
      return
    end

    if view == "wild" then
      -- filter bar
      local scope = model.wildScope == "ROUTE" and "ROUTE" or "HERE"
      local here = self:beginPress(12, 142, 76, 16, scope ~= "HERE")
      self:endPress(here)
      local route = self:beginPress(89, 142, 76, 16, scope ~= "ROUTE")
      self:endPress(route)
      self:v4Segments(10, 141, 155, { { "HERE NOW", "HERE" }, { "WHOLE ROUTE", "ROUTE" } }, scope, true)
      if model.pages > 1 then
        local pressed = self:beginPress(168, 142, 58, 16)
        self:v4Key(168, 141, 62, 17)
        self:partyType(model.page .. "/" .. model.pages, 168, 143, colors.ink, 62)
        ART({ "..#", ".##", "###", ".##", "..#" }, 174, 147, { ["#"] = colors.mutedInk })
        ART({ "#..", "##.", "###", "##.", "#.." }, 221, 147, { ["#"] = colors.mutedInk })
        self:endPress(pressed)
      else
        local label = tostring(model.total) .. " " .. translate("PKMN")
        self:v4Window(168, 141, 62, 17, { fill = colors.bandLight })
        self:partyType(label, 168, 143, colors.mutedInk, 62)
      end
      if #model.rows == 0 then
        self:v4Window(7, CARD_Y, 226, CARD_H, { fill = colors.bandLight })
        self:partyInfo(translate(model.emptyHint or (scope == "ROUTE"
          and "NO WILD ENCOUNTERS" or "NOTHING HERE NOW")), 7, CARD_Y + 18, colors.mutedInk, 226, "center")
        return
      end
      for index, row in ipairs(model.rows) do
        self:v4EncounterCard(row, cardX(index), CARD_Y, model)
      end
    end
  end

  local base = H.explorerHit
  function H:explorerHit(x, y, model)
    local action, slot = base(self, x, y, model)
    if action == "row" or (model and not model.mapFull and not model.selected and model.view == "wild") then
      local px, py = x * 1.5, y * 1.5
      if py >= CARD_Y and py < CARD_Y + CARD_H then
        for index = 1, #(model.rows or {}) do
          local cx = cardX(index)
          if px >= cx and px < cx + CARD_W then return "row", index end
        end
        return nil
      end
    end
    return action, slot
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
