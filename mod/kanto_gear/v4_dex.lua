-- Kanto Gear v4: Pokédex research pages (profile, habitat, learnset,
-- evolutions, area, cry, size). Geometry follows pokedex_page.lua.
return function(H, ui, K)
  local floor, max, min = math.floor, math.max, math.min
  local R, P, RR, RRrows, CH, CHrows = K.R, K.P, K.RR, K.RRrows, K.CH, K.CHrows
  local CIRC, CIRCrows, RING, ART = K.CIRC, K.CIRCrows, K.RING, K.ART
  local mix, hex = K.mix, K.hex
  local cg, WHITE = K.cg, K.WHITE
  local translate = function(value) return ui.translate and ui.translate(value) or value end
  local Dex = ui.pokedexPage
  if not Dex then return end

  local DEX_RED = hex("e04838")
  local CARD = {
    STATS = { tint = "4888e0", art = { "......#", "....#.#", "..#.#.#", "#.#.#.#", "#.#.#.#", "#######" } },
    HABITAT = { tint = "48a858", art = { ".###.", "#####", "##.##", "#####", ".###.", "..#..", "..#.." } },
    MOVES = { tint = "e8a030", art = { "..###..", ".#...#.", "#..#..#", "#.###.#", "#..#..#", ".#...#.", "..###.." } },
    EVOLUTIONS = { tint = "d05878", art = { "..#....", "..##...", "######.", "#######", "######.", "..##...", "..#...." } },
  }

  local function hero(self, model, accent, summary, facts)
    local colors = self.colors
    local mon = model.pokemon or {}
    self.v4SummaryWindow(self, 7, 34, 226, 37, accent)
    self:v4Seat(11, 36, 33)
    if model.drawPokemon then model.drawPokemon(mon, 12, 37, 31, false) end
    self:partyName(self:fitPartyInfo(mon.name or translate("POKEMON"), 100), 49, 37, colors.ink, 100)
    self:typeBadges(mon, 49, 55, false)
    if summary and summary ~= "" then
      local s = self:fitPartyInfo(summary, 80)
      self:partyInfo(s, 226 - self:partyInfoWidth(s), 38, colors.ink)
    end
    if facts and facts ~= "" then
      local f = self:fitPartyInfo(facts, 90)
      self:partyInfo(f, 226 - self:partyInfoWidth(f), 54, colors.green)
    end
  end
  H.v4DexHero = hero

  local function pager(self, page, pages, canUse, description)
    if (pages or 1) <= 1 then return end
    local colors = self.colors
    local px, py = Dex.pagerRect(-1, description)
    local nx = Dex.pagerRect(1, description)
    local y = py - 2
    self:v4Window(px - 4, y, nx + 22 - (px - 4), 16, { fill = colors.bandLight })
    local enabled = canUse ~= false
    local prev = self:beginPress(px, py, 18, 12, enabled and page > 1)
    ART({ "..#", ".##", "###", ".##", "..#" }, px + 7, py + 3, { ["#"] = page > 1 and colors.ink or colors.disabledInk })
    self:endPress(prev)
    local nextP = self:beginPress(nx, py, 18, 12, enabled and page < pages)
    ART({ "#..", "##.", "###", "##.", "#.." }, nx + 8, py + 3, { ["#"] = page < pages and colors.ink or colors.disabledInk })
    self:endPress(nextP)
    self:partyInfo(page .. "/" .. pages, px + 18, py, colors.green, nx - px - 18, "center")
  end
  H.v4DexPager = pager

  ---------------------------------------------------------------------------
  -- Profile
  ---------------------------------------------------------------------------
  function H:pokedexProfile(model)
    local colors = self.colors
    local mon = model.pokemon or {}
    local accent = self:typeColor(mon.types and mon.types[1] or mon.type)
    self.v4SummaryWindow(self, 7, 34, 226, 70, accent)
    self:v4Seat(12, 39, 60)
    if model.drawPokemon then model.drawPokemon(mon, 15, 42, 54, false) end
    self:partyName(self:fitPartyInfo(mon.name or translate("POKEMON"), 120), 78, 37, colors.ink, 120)
    if mon.caught then self:v4MiniBall(215, 40, "ok") else self:v4MiniBall(215, 40, "none") end
    self:typeBadges(mon, 78, 52, false)
    local kind = self:fitPartyInfo(translate(mon.kind or "UNKNOWN"), 80)
    self:partyInfo(kind, 226 - self:partyInfoWidth(kind), 52, colors.mutedInk)
    R(78, 66, 148, 1, colors.band)
    -- height / weight with glyphs
    ART({ "###", ".#.", ".#.", ".#.", ".#.", "###" }, 79, 72, { ["#"] = colors.green })
    self:partyInfo(self:fitPartyInfo(mon.height or translate("HEIGHT --"), 62), 85, 70, colors.ink)
    ART({ ".###.", "#...#", "#####", "#####", "#####" }, 152, 73, { ["#"] = colors.green })
    self:partyInfo(self:fitPartyInfo(mon.weight or translate("WEIGHT --"), 64), 160, 70, colors.ink)
    local status = mon.caught and "CAUGHT" or "NOT CAUGHT"
    self:v4Pill(status, 78, 86, mon.caught and colors.hp or hex("d05040"))
    -- description
    self:v4MessageWindow(7, 108, 226, 44)
    local lines = mon.description or { translate("NO DETAILS AVAILABLE") }
    local visible = min(3, #lines)
    local paged = (model.descriptionPages or 1) > 1
    local firstY = 110 + floor(((paged and 29 or 40) - visible * 10) / 2)
    for index = 1, visible do
      self:partyInfoCentered(self:fitPartyInfo(lines[index], 204), 18, firstY + (index - 1) * 10, 204, 10, colors.ink)
    end
    if paged then
      local cu = model.canUse ~= false
      local p1 = self:beginPress(82, 140, 18, 11, cu)
      ART({ "..#", ".##", "###", ".##", "..#" }, 88, 143, { ["#"] = colors.mutedInk })
      self:endPress(p1)
      local p2 = self:beginPress(140, 140, 18, 11, cu)
      ART({ "#..", "##.", "###", "##.", "#.." }, 148, 143, { ["#"] = colors.mutedInk })
      self:endPress(p2)
      self:partyInfoCentered(model.descriptionPage .. "/" .. model.descriptionPages, 100, 141, 40, 8, colors.green)
    end
    if model.actions then
      self:pokedexActions(model)
      return
    end
    local cards = {
      { "STATS", model.statsText or translate("BASE POWER") },
      { "HABITAT", model.habitatText or translate("WHERE TO FIND") },
      { "MOVES", model.movesText or translate("LEARNSET") },
      { "EVOLUTIONS", translate("METHOD + CONDITIONS") },
    }
    for index, card in ipairs(cards) do
      local left, top, width, height = Dex.cardRect(index)
      local spec = CARD[card[1]]
      local tint = hex(spec.tint)
      local pressed = self:beginPress(left, top, width, height, model.canUse ~= false)
      self:v4Key(left, top, width, height)
      -- icon badge
      local d = min(height - 5, 21)
      local bx, by = left + 4, top + floor((height - 2 - d) / 2)
      CIRC(bx, by, d, colors.outline)
      CIRC(bx + 1, by + 1, d - 2, mix(colors.surface, tint, self.dark and 0.35 or 0.22))
      local art = spec.art
      ART(art, bx + floor((d - #art[1]) / 2), by + floor((d - #art) / 2), { ["#"] = tint })
      local tx, tw = left + d + 8, width - d - 12
      self:partyInfo(self:fitPartyInfo(translate(card[1]), tw), tx, top + 1, colors.ink)
      self:partyInfo(self:fitPartyInfo(card[2], tw), tx, top + 11, colors.mutedInk)
      self:endPress(pressed)
    end
  end

  function H:pokedexActions(model)
    local colors = self.colors
    for index, action in ipairs(model.actions or {}) do
      local x, y, w, h = Dex.actionRect(index, #model.actions, model.compactActions)
      local enabled = model.canUse ~= false and not action.inert
      local pressed = self:beginPress(x, y, w, h, enabled)
      self:v4Key(x, y, w, h, not enabled and { cap = colors.bandLight, lip = colors.band, hi = colors.bandLight } or nil)
      self:partyInfoCentered(self:fitPartyInfo(translate(action.label), w - 10), x + 5, y, w - 10, h - 3,
        enabled and colors.ink or colors.disabledInk)
      self:endPress(pressed)
    end
  end

  ---------------------------------------------------------------------------
  -- Learnset
  ---------------------------------------------------------------------------
  function H:pokedexMoves(model)
    local colors = self.colors
    hero(self, model, hex("e8a030"), translate("LEARNSET"), translate("LEVEL + TM/HM"))
    for index, row in ipairs(model.rows or {}) do
      local top = 76 + (index - 1) * 28
      local tc = self:typeColor(row.type or row.types and row.types[1])
      self:v4Window(7, top, 226, 25, { fill = mix(colors.surface, tc, self.dark and 0.16 or 0.1) })
      -- method chip
      local method = tostring(row.method or "--")
      local mc = method:match("^L%d") and hex("48a858") or method:find("TM") and hex("4888e0") or hex("8890a0")
      self:v4Pill(method, 12, top + 7, mc, { raw = true, w = 40, maxW = 40 })
      self:partyInfo(self:fitPartyInfo(row.name or translate("MOVE"), 110), 58, top + 6, colors.ink)
      self:v4TypePill(row.type, row.typeLabel or row.type, 186, top + 8, 40)
    end
    pager(self, model.page or 1, model.pages or 1, model.canUse)
  end

  ---------------------------------------------------------------------------
  -- Evolutions
  ---------------------------------------------------------------------------
  function H:pokedexEvolutions(model)
    local colors = self.colors
    local mon = model.pokemon or {}
    hero(self, model, hex("d05878"), translate("EVOLUTION"), "")
    self:v4Window(7, 76, 226, 119)
    local row = (model.rows or {})[1]
    if not row then
      self:partyInfoCentered(self:fitPartyInfo(model.emptyText or translate("NO FURTHER EVOLUTION"), 210),
        15, 77, 210, 117, colors.mutedInk)
      pager(self, model.page or 1, model.pages or 1, model.canUse)
      return
    end
    -- from → to with an animated arrow
    self:v4Seat(28, 88, 44)
    if model.drawPokemon then model.drawPokemon(mon, 32, 92, 36, false) end
    self:v4Seat(168, 88, 44)
    if row.revealed ~= false and model.drawPokemon then model.drawPokemon(row, 172, 92, 36, false)
    else self:partyInfoCentered("?", 168, 88, 44, 44, colors.mutedInk) end
    local t = self:clock()
    local shift = self.motionEnabled == false and 0 or floor(t / 0.15) % 6
    for k = 0, 5 do
      local on = (k + 6 - shift) % 6 < 2
      R(82 + k * 13, 108, 9, 4, on and hex("d05878") or colors.bandLight)
    end
    ART({ "#..", "##.", "###", "##.", "#.." }, 160, 107, { ["#"] = hex("d05878") })
    self:wantAmbient(0.3, 0.15)
    self:partyInfo(self:fitPartyInfo(mon.name or "", 60), 20, 135, colors.mutedInk, 60, "center")
    self:partyInfo(self:fitPartyInfo(row.name or "???", 70), 155, 135, colors.ink, 70, "center")
    R(15, 150, 210, 1, colors.band)
    local lines = row.lines or row.conditions or {}
    local top = 156 + floor((36 - #lines * 10) / 2)
    for index, line in ipairs(lines) do
      self:partyInfoCentered(self:fitPartyInfo(line, 206), 17, top + (index - 1) * 10, 206, 10,
        row.blocked and (self.dark and colors.redLight or colors.red) or colors.green)
    end
    pager(self, model.page or 1, model.pages or 1, model.canUse)
  end

  ---------------------------------------------------------------------------
  -- Habitat
  ---------------------------------------------------------------------------
  function H:pokedexHabitat(model)
    local colors = self.colors
    local mon = model.pokemon or {}
    self.v4SummaryWindow(self, 7, 34, 226, 49, hex("48a858"))
    self:v4Seat(11, 36, 33)
    if model.drawPokemon then model.drawPokemon(mon, 12, 37, 31, false) end
    self:partyName(self:fitPartyInfo(mon.name or translate("POKEMON"), 100), 49, 37, colors.ink, 100)
    self:typeBadges(mon, 49, 55, false)
    local s = self:fitPartyInfo(model.summary or "", 80)
    self:partyInfo(s, 226 - self:partyInfoWidth(s), 38, colors.ink)
    self:partyInfo(self:fitPartyType(model.matchText or "", 212), 14, 70, colors.green, 212, "center")
    for index, row in ipairs(model.rows or {}) do
      local top = 88 + (index - 1) * 35
      local here = row.current
      local fill = here and mix(colors.surface, colors.hp, self.dark and 0.18 or 0.14)
        or row.matches and colors.surface or colors.bandLight
      self:v4Window(7, top, 226, 33, { fill = fill })
      if here then self:focusFrame(7, top, 226, 33) end
      self:partyInfo(self:fitPartyInfo(row.area or translate("UNKNOWN AREA"), 150), 13, top + 2,
        row.matches == false and colors.mutedInk or colors.ink)
      local x = 13
      if row.time and K.periodIcon and K.periodIcon(row.time, x, top + 18, colors.mutedInk) then x = x + 10 end
      self:v4MethodGlyph(row.method, x, top + 18)
      local cond = self:fitPartyInfo(translate(row.method or "WILD") .. "  " .. tostring(row.chance or "--") .. "%", 90)
      self:partyInfo(cond, x + 10, top + 16, colors.green)
      self:v4ChanceBar(118, top + 21, 40, row.chance)
      self:partyInfo(row.levels or "L--", 168, top + 2, colors.ink, 56, "right")
      if row.status then
        self:v4Pill(self:fitPartyType(row.status, 64), 226, top + 18,
          here and colors.hp or row.matches and hex("4888e0") or colors.silverDark, { right = true, raw = true })
      end
    end
    if #(model.rows or {}) == 0 then
      self:partyInfo(translate("NO WILD ENCOUNTERS"), 14, 124, colors.mutedInk, 212, "center")
    end
    pager(self, model.page or 1, model.pages or 1, model.canUse)
  end

  ---------------------------------------------------------------------------
  -- Area / Cry / Size reuse the base content inside the new hero + frames
  ---------------------------------------------------------------------------
  local base = K.base
  for _, name in ipairs({ "pokedexArea", "pokedexCry", "pokedexSize" }) do
    local original = base[name] or H[name]
    H[name] = function(self, model)
      original(self, model)
      local accent = name == "pokedexArea" and hex("48a858") or hex("4888e0")
      local label = name == "pokedexArea" and translate(model.region or "AREA")
        or name == "pokedexCry" and translate("CRY") or translate("SIZE")
      local facts = name == "pokedexArea" and translate("AREA")
        or name == "pokedexCry" and translate(model.playing and "PLAYING" or "READY")
        or (model.pokemon and model.pokemon.height or "--")
      hero(self, model, accent, label, facts)
    end
  end

  -- Stats keeps its v4 gauges; only the hero is swapped for the shared one.
  local stats = H.pokedexStats
  function H:pokedexStats(model)
    stats(self, model)
    hero(self, model, hex("4888e0"), model.summary or translate("BASE STATS"), nil)
    local colors = self.colors
    local catch = self:fitPartyInfo(model.catchText or translate("CATCH --"), 56)
    local xp = self:fitPartyInfo(model.expText or translate("XP --"), 56)
    self:partyInfo(xp, 226 - self:partyInfoWidth(xp), 54, colors.green)
    self:partyInfo(catch, 226 - self:partyInfoWidth(xp) - 10 - self:partyInfoWidth(catch), 54, colors.green)
  end

  ---------------------------------------------------------------------------
  -- Region map: Pokégear map app — device bezel, inset screen, pulsing
  -- fly points, bracket cursor, area plate and MAP | FLY segments.
  ---------------------------------------------------------------------------
  local function bezel(self, x, y, w, h)
    local colors = self.colors
    local body = cg(self) and (self.dark and hex("1b2733") or hex("2d4458")) or (self.dark and hex("1d3a46") or hex("2f6f78"))
    if cg(self) then CH(x, y, w, h, 6, colors.outline); CH(x + 1, y + 1, w - 2, h - 2, 5, body)
    else RR(x, y, w, h, 6, colors.outline); RR(x + 1, y + 1, w - 2, h - 2, 5, body)
      R(x + 6, y + 1, w - 12, 1, mix(body, WHITE, 0.3)) end
    -- screws
    for _, p in ipairs({ { x + 4, y + 4 }, { x + w - 6, y + 4 }, { x + 4, y + h - 6 }, { x + w - 6, y + h - 6 } }) do
      R(p[1], p[2], 2, 2, mix(body, WHITE, 0.25))
    end
    return body
  end

  local function bracket(self, x, y)
    local colors = self.colors
    x, y = floor(x + 0.5), floor(y + 0.5)
    local t = self:clock()
    local o = (self.motionEnabled ~= false and floor(t / 0.4) % 2 == 0) and 1 or 0
    self:wantAmbient(0.4)
    local hot = cg(self) and hex("40d8ff") or hex("f8d048")
    for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
      local sx, sy = c[1], c[2]
      local cx, cy = x + sx * (5 + o), y + sy * (5 + o)
      R(cx + (sx < 0 and 0 or -3), cy, 4, 1, colors.outline)
      R(cx, cy + (sy < 0 and 0 or -3), 1, 4, colors.outline)
      R(cx + (sx < 0 and 1 or -3), cy + (sy < 0 and 1 or -1), 3, 1, hot)
      R(cx + (sx < 0 and 1 or -1), cy + (sy < 0 and 1 or -3), 1, 3, hot)
    end
  end

  function H:regionMap(model)
    local G, colors = ui.graphics, self.colors
    bezel(self, 7, 32, 226, 178)
    local screenH = model.interactive and 116 or 142
    R(11, 36, 218, screenH + 2, colors.outline)
    R(12, 37, 216, screenH, mix(colors.surface, colors.blueLight, self.dark and 0.18 or 0.12))
    G.setScissor(14, 39, 212, screenH - 4)
    if model.drawMap then model.drawMap(14, 39, 212, screenH - 4) end
    -- scanlines for the LCD feel
    for ly = 39, 37 + screenH - 3, 2 do R(14, ly, 212, 1, { 0, 0, 0, 0.035 }) end
    G.setScissor()
    if not model.interactive then
      -- area plate
      local accent = cg(self) and self.tok.acc.M or colors.green
      self:v4Window(12, 183, 216, 22)
      ART({ ".ooo.", "o###o", "o#w#o", "o###o", ".o#o.", "..o.." }, 18, 190,
        { o = colors.outline, ["#"] = hex("e05848"), w = WHITE })
      self:partyInfo(translate("AREA"), 27, 188, accent)
      R(27 + self:partyInfoWidth(translate("AREA")) + 5, 187, 1, 13, colors.band)
      local area = self:fitPartyInfo(model.area or translate("UNKNOWN AREA"), 150)
      self:partyInfo(area, 222 - self:partyInfoWidth(area), 188, colors.ink)
      return
    end
    local scale = math.min(212 / model.width, 112 / model.height)
    local left = floor(14 + (212 - model.width * scale) / 2 + 0.5)
    local top = floor(39 + (112 - model.height * scale) / 2 + 0.5)
    G.setScissor(14, 39, 212, 112)
    if model.fly and model.flyPoints then
      local t = self:clock()
      for i, point in ipairs(model.flyPoints) do
        local x, y = floor(left + point.x * scale + 0.5), floor(top + point.y * scale + 0.5)
        local pulse = point.flyable and self.motionEnabled ~= false and floor(t / 0.5 + i * 0.3) % 2 == 0
        R(x - 3, y - 3, 7, 7, colors.outline)
        R(x - 2, y - 2, 5, 5, point.flyable and (pulse and hex("f8e070") or hex("f0a830")) or colors.silver)
        P(x - 1, y - 1, WHITE)
      end
      self:wantAmbient(0.5)
    end
    bracket(self, model.cursorX, model.cursorY)
    G.setScissor()
    if model.fly and model.preview then
      local x, y, w, h = unpack(model.preview)
      self:v4Window(x, y, w, h)
      G.setScissor(x + 2, y + 2, w - 4, h - 4)
      local ax, ay = (model.cursorX - left) / scale, (model.cursorY - top) / scale
      model.drawMap(x + w / 2 - ax * 2, y + h / 2 - ay * 2, model.width * 2, model.height * 2)
      bracket(self, x + w / 2, y + h / 2)
      G.setScissor()
    end
    -- area / fly plate (12..228 × 157..186)
    local pressed = self:beginPress(12, 157, 216, 29, model.canFly == true)
    if model.canFly then
      self:v4Button(12, 157, 216, 29, K.rampOf(cg(self) and hex("1ea5d8") or hex("3878d0")), { radius = 5, lip = 3, chamfer = 5 })
    else
      self:v4Window(12, 157, 216, 29)
    end
    local ink = model.canFly and WHITE or colors.ink
    self:partyInfoCentered(self:fitPartyInfo(model.area or "", 196), 18, 158, 204, 13, ink)
    self:partyInfoCentered(self:fitPartyInfo(translate(model.status or ""), 196), 18, 170, 204, 13,
      model.canFly and WHITE or colors.green)
    self:endPress(pressed)
    -- MAP | FLY
    local mapP = self:beginPress(12, 190, 104, 18, model.fly == true)
    self:endPress(mapP)
    local flyP = self:beginPress(124, 190, 104, 18, model.fly ~= true)
    self:endPress(flyP)
    self:v4Segments(12, 190, 216, { { "MAP", false }, { "FLY", true } }, model.fly == true, true)
  end
end
