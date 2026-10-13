-- Kanto Gear v4: Pokédex research pages (profile, habitat, learnset,
-- evolutions, area, cry, size). Geometry follows ui/pages/pokedex.lua.
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

  -- Finger-sized pager keys: the arrows are wide keys of their own, the page
  -- count sits between them. The hit rects live in ui/pages/pokedex.lua, so the
  -- touch targets grow with the drawing.
  local basePagerRect = Dex.pagerRect
  function Dex.pagerRect(direction, description)
    if description then return direction < 0 and 66 or 140, 138, 34, 14 end
    return direction < 0 and 56 or 142, 197, 42, 16
  end
  H.v4DexBasePagerRect = basePagerRect

  local function pagerKey(self, x, y, w, h, left, on, enabled)
    local colors = self.colors
    local pressed = self:beginPress(x, y, w, h, enabled and on)
    local ramp = K.rampOf(on and (cg(self) and self.tok.acc.M or colors.green) or colors.silverDark)
    self:v4Button(x, y, w, h, ramp, { radius = 4, lip = 2, chamfer = 3 })
    local ax = x + floor((w - 3) / 2)
    local ay = y + floor((h - 2 - 5) / 2)
    ART(left and { "..#", ".##", "###", ".##", "..#" } or { "#..", "##.", "###", "##.", "#.." }, ax, ay,
      { ["#"] = on and WHITE or colors.band })
    self:endPress(pressed)
  end
  H.v4PagerKey = pagerKey

  local function pager(self, page, pages, canUse, description)
    if (pages or 1) <= 1 then return end
    local colors = self.colors
    local px, py, pw, ph = Dex.pagerRect(-1, description)
    local nx = Dex.pagerRect(1, description)
    local enabled = canUse ~= false
    pagerKey(self, px, py, pw, ph, true, page > 1, enabled)
    pagerKey(self, nx, py, pw, ph, false, page < pages, enabled)
    self:partyInfoCentered(page .. "/" .. pages, px + pw, py, nx - px - pw, ph - 2, colors.ink)
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
    local visible = min(2, #lines)
    local paged = (model.descriptionPages or 1) > 1
    -- Keep the text inside the inset frame, above the description pager.
    local firstY = 112 + floor(((paged and 24 or 34) - visible * 11) / 2)
    self:v4Prose(function()
      for index = 1, visible do
        self:partyInfoCentered(lines[index], 18, firstY + (index - 1) * 11, 204, 11, colors.ink)
      end
    end)
    if paged then
      pager(self, model.descriptionPage or 1, model.descriptionPages, model.canUse, true)
    end
    if model.actions then
      self:pokedexActions(model)
      return
    end
    local cards = {
      { "STATS", model.statsText or translate("BASE POWER") },
      { "HABITAT", model.habitatText or translate("WHERE TO FIND") },
      { "MOVES", model.movesText or translate("LEARNSET") },
      { "EVOLUTIONS", model.evolutionsText or translate("HOW IT EVOLVES") },
    }
    if model.cards then
      local allowed, byName = {}, {}
      for _, card in ipairs(cards) do byName[card[1]:lower()] = card end
      for _, key in ipairs(model.cards) do allowed[#allowed + 1] = byName[key] end
      cards = allowed
    end
    for index, card in ipairs(cards) do
      local left, top, width, height = Dex.cardRect(index, #cards)
      local spec = CARD[card[1]]
      local tint = hex(spec.tint)
      local pressed = self:beginPress(left, top, width, height, model.canUse ~= false)
      self:v4Key(left, top, width, height)
      -- icon badge
      local d = min(height - 5, 21)
      local title = self:fitPartyInfo(translate(card[1]), width - d - 12)
      local subtitle = self:fitPartyInfo(card[2], width - d - 12)
      local tw = max(self:partyInfoWidth(title), self:partyInfoWidth(subtitle))
      local bx = left + floor((width - d - 6 - tw) / 2)
      local by = top + floor((height - d) / 2)
      CIRC(bx, by, d, colors.outline)
      CIRC(bx + 1, by + 1, d - 2, mix(colors.surface, tint, self.dark and 0.35 or 0.22))
      -- the glyph at 2x so the four research doors read at a glance
      local art = spec.art
      local G = ui.graphics
      G.push()
      G.translate(bx + floor((d - #art[1] * 2) / 2), by + floor((d - #art * 2) / 2))
      G.scale(2, 2)
      ART(art, 0, 0, { ["#"] = mix(tint, { 0, 0, 0, 1 }, self.dark and 0 or 0.12) })
      G.pop()
      local tx, ty = bx + d + 6, top + floor((height - 21) / 2)
      self:partyInfoCentered(title, tx, ty, tw, 10, colors.ink)
      self:partyInfoCentered(subtitle, tx, ty + 11, tw, 10, colors.mutedInk)
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
    local G = ui.graphics
    local enter = self:v4Enter("dex_moves", tostring(model.page), 0.24)
    for index, row in ipairs(model.rows or {}) do
      local top = 76 + (index - 1) * 28
      local _, sdx = self:v4Stagger(enter, index, 0.08, 14, #(model.rows or {}))
      if sdx ~= 0 then G.push(); G.translate(sdx, 0) end
      local tc = self:typeColor(row.type or row.types and row.types[1])
      self:v4Window(7, top, 226, 25, { fill = mix(colors.surface, tc, self.dark and 0.16 or 0.1) })
      -- method chip
      local method = tostring(row.method or "--")
      local mc = method:match("^L%d") and hex("48a858") or method:find("TM") and hex("4888e0") or hex("8890a0")
      self:v4Pill(method, 12, top + 7, mc, { raw = true, w = 40, maxW = 40 })
      local mon = model.pokemon or {}
      local stab = row.type and (row.type == mon.type or row.type == mon.type2
        or (mon.types and (mon.types[1] == row.type or mon.types[2] == row.type)))
      self:partyInfo(self:fitPartyInfo(row.name or translate("MOVE"), stab and 90 or 110), 58, top + 6, colors.ink)
      if stab then
        -- same-type moves hit harder: mark them like the battle cards do
        ART({ "...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", ".#...#." }, 160, top + 9,
          { ["#"] = hex("f0b020") })
      end
      self:v4TypePill(row.type, row.typeLabel or row.type, 186, top + 8, 40)
      if sdx ~= 0 then G.pop() end
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
      if row.details ~= false then
      local x = 13
      if row.time and K.periodIcon and K.periodIcon(row.time, x, top + 18, colors.mutedInk) then x = x + 10 end
      self:v4MethodGlyph(row.method, x, top + 18)
      local cond = self:fitPartyInfo(translate(row.method or "WILD") .. "  " .. tostring(row.chance or "--") .. "%", 90)
      self:partyInfo(cond, x + 10, top + 16, colors.green)
      self:v4ChanceBar(118, top + 21, 40, row.chance)
      self:partyInfo(row.levels or "L--", 168, top + 2, colors.ink, 56, "right")
      end
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

  ---------------------------------------------------------------------------
  -- Area / Cry / Size: the native Pokédex pages as Pokégear instruments.
  -- Content geometry (viewport, silhouettes, wave) comes from the model, so
  -- every frame and marker here sits around what the game positioned.
  ---------------------------------------------------------------------------
  local PIN = { ".ooo.", "o###o", "o#w#o", "o###o", ".o#o.", "..o.." }
  local SPEAKER = { "...o....", "..oo..o.", "oo#o.o..", "o##o.o.o", "oo#o.o..", "..oo..o.", "...o...." }
  local RULER = { "ooooooooo", "o#o#o#o#o", "o#######o", "ooooooooo" }
  local BACKA = { "..o....", ".oo....", "ooooooo", ".oo...o", "..o...o", "......o", "..oooo." }
  local function actionGlyph(label)
    local l = tostring(label or ""):upper()
    if l:find("CRY") or l:find("RUF") or l:find("CRI") then return SPEAKER, hex("4888e0") end
    if l:find("SIZE") or l:find("GR") or l:find("TAIL") then return RULER, hex("e8a030") end
    if l:find("AREA") or l:find("GEBIET") or l:find("ZONE") or l:find("HABIT") then return PIN, hex("e05848") end
    if l:find("BACK") or l:find("ZUR") or l:find("RETO") or l:find("VOLV") then return BACKA, nil end
    return nil
  end
  -- Keys for the native research pages carry a glyph like the DS buttons.
  function H:pokedexActions(model)
    local colors = self.colors
    for index, action in ipairs(model.actions or {}) do
      local x, y, w, h = Dex.actionRect(index, #model.actions, model.compactActions)
      local enabled = model.canUse ~= false and not action.inert
      local pressed = self:beginPress(x, y, w, h, enabled)
      self:v4Key(x, y, w, h, not enabled and { cap = colors.bandLight, lip = colors.band, hi = colors.bandLight } or nil)
      local label = self:fitPartyInfo(translate(action.label), w - 22)
      local glyph, tint = actionGlyph(action.label)
      if glyph and h >= 30 then
        -- tall keys: glyph above the label
        local G = ui.graphics
        local gw, gh = #glyph[1] * 2, #glyph * 2
        local block = gh + 4 + 11
        local top = y + floor((h - 3 - block) / 2)
        G.push(); G.translate(x + floor((w - gw) / 2), top); G.scale(2, 2)
        ART(glyph, 0, 0, { o = enabled and colors.outline or colors.disabledInk,
          ["#"] = enabled and (tint or colors.ink) or colors.disabledInk, w = WHITE })
        G.pop()
        self:partyInfoCentered(label, x + 5, top + gh + 2, w - 10, 12,
          enabled and colors.ink or colors.disabledInk)
      elseif glyph then
        local lw = self:partyInfoWidth(label)
        local gw = #glyph[1]
        local gx = x + floor((w - (gw + 4 + lw)) / 2)
        ART(glyph, gx, y + floor((h - 3 - #glyph) / 2), { o = enabled and colors.outline or colors.disabledInk,
          ["#"] = enabled and (tint or colors.ink) or colors.disabledInk, w = WHITE })
        self:partyInfo(label, gx + gw + 4, y + floor((h - 3) / 2) - 6, enabled and colors.ink or colors.disabledInk)
      else
        self:partyInfoCentered(label, x + 5, y, w - 10, h - 3, enabled and colors.ink or colors.disabledInk)
      end
      self:endPress(pressed)
    end
  end

  local function screenWell(self, x, y, w, h, tint)
    local colors = self.colors
    local body = bezel(self, x, y, w, h)
    R(x + 3, y + 3, w - 6, h - 6, colors.outline)
    R(x + 4, y + 4, w - 8, h - 8, tint or mix(colors.surface, colors.blueLight, self.dark and 0.18 or 0.12))
    return body
  end

  local function pulse(self, period)
    if self.motionEnabled == false then return 0.5 end
    self:wantAmbient(period / 4)
    return (math.sin(self:clock() * math.pi * 2 / period) + 1) / 2
  end

  local function nestMarker(self, x, y, k)
    local colors = self.colors
    local r = 4 + floor(k * 2 + 0.5)
    local halo = { 0.95, 0.35, 0.3, 0.18 + 0.2 * (1 - k) }
    R(x - r, y - 1, r * 2 + 1, 3, halo); R(x - 1, y - r, 3, r * 2 + 1, halo)
    R(x - 3, y - 3, 7, 7, colors.outline)
    R(x - 2, y - 2, 5, 5, hex("f05848"))
    R(x - 2, y - 2, 2, 1, hex("f8b0a0"))
  end

  local function drawArea(self, model, frame)
    local G, colors = ui.graphics, self.colors
    local area = model.area
    if not (area and area.available) then return false end
    local t = Dex.areaTransform(area, model.areaViewport)
    local cx, cy = t.x + area.x * t.scale, t.y + area.y * t.scale
    local cw, ch = area.width * t.scale, area.height * t.scale
    G.setScissor(cx, cy, cw, ch)
    G.push(); G.translate(t.x, t.y); G.scale(t.scale, t.scale)
    area.draw()
    local k = pulse(self, 1.6)
    G.setColor(0.94, 0.33, 0.28, 0.42 + 0.18 * k)
    for _, cell in ipairs(area.coverage or {}) do G.rectangle("fill", cell.x, cell.y, cell.width, cell.height) end
    G.pop()
    -- faint LCD scanlines over the atlas
    for ly = floor(cy), floor(cy + ch) - 1, 2 do R(floor(cx), ly, math.ceil(cw), 1, { 0, 0, 0, 0.04 }) end
    for _, mark in ipairs(area.markers or {}) do
      nestMarker(self, floor(t.x + mark.x * t.scale + 0.5), floor(t.y + mark.y * t.scale + 0.5), k)
    end
    if area.player then
      local x, y = floor(t.x + area.player.x * t.scale + 0.5), floor(t.y + area.player.y * t.scale + 0.5)
      local bob = (self.motionEnabled ~= false and floor(self:clock() / 0.4) % 2 == 0) and 1 or 0
      self:wantAmbient(0.4)
      ART({ ".ooo.", "o###o", "o#w#o", "o###o", ".o#o.", "..o.." }, x - 2, y - 6 - bob,
        { o = colors.outline, ["#"] = hex("3878d0"), w = WHITE })
      R(x - 1, y, 3, 1, { 0, 0, 0, 0.3 })
    end
    G.setScissor()
    return true
  end

  local function legend(self, x, y)
    local colors = self.colors
    local nest, you = translate("NEST"), translate("YOU")
    local w = 7 + self:partyInfoWidth(nest) + 10 + 7 + self:partyInfoWidth(you) + 8
    x = x - w
    RR(x, y, w, 13, 3, colors.outline)
    RR(x + 1, y + 1, w - 2, 11, 2, colors.surface)
    R(x + 4, y + 4, 5, 5, colors.outline); R(x + 5, y + 5, 3, 3, hex("f05848"))
    self:partyInfo(nest, x + 11, y, colors.ink)
    local yx = x + 11 + self:partyInfoWidth(nest) + 6
    R(yx, y + 4, 5, 5, colors.outline); R(yx + 1, y + 5, 3, 3, hex("3878d0"))
    self:partyInfo(you, yx + 7, y, colors.ink)
  end

  local function unknownArea(self, x, y, w)
    local colors = self.colors
    self:v4Window(x, y, w, 26, { radius = 4 })
    local label = self:fitPartyInfo(translate("UNKNOWN AREA"), w - 26)
    local lw = self:partyInfoWidth(label)
    local gx = x + floor((w - (lw + 12)) / 2)
    ART({ ".ooo.", "o...o", "...o.", "..o..", ".....", "..o.." }, gx, y + 10, { o = colors.mutedInk })
    self:partyInfo(label, gx + 12, y + 6, colors.mutedInk)
  end

  function H:pokedexArea(model)
    local colors = self.colors
    hero(self, model, hex("48a858"), translate(model.region or "AREA"), translate("AREA"))
    local area = model.area
    local known = area and area.available and not area.unknown
    if model.combined then
      -- two instruments side by side: area atlas and the size silhouettes
      screenWell(self, 7, 76, 110, 105, mix(colors.surface, colors.greenLight, self.dark and 0.2 or 0.18))
      screenWell(self, 123, 76, 110, 105, mix(colors.surface, colors.blueLight, self.dark and 0.18 or 0.14))
      self:v4Pill("AREA", 12, 80, hex("48a858"))
      self:v4Pill("SIZE", 128, 80, hex("4888e0"))
      drawArea(self, model)
      for gx = 131, 225, 8 do R(gx, 96, 1, 64, { 0, 0, 0, 0.05 }) end
      R(130, 158, 96, 1, mix(colors.surface, colors.outline, 0.45))
      self:pokedexComparison(model)
      local h = model.pokemon and model.pokemon.caught and (model.pokemon.height or "--") or "--"
      self:partyInfo(h, 128, 163, colors.ink, 100, "center")
      if not known then unknownArea(self, 14, 122, 96) end
    else
      local tint = mix(colors.surface, colors.greenLight, self.dark and 0.2 or 0.18)
      screenWell(self, 7, 76, 226, 104, tint)
      if drawArea(self, model) and known then legend(self, 226, 164) end
      if not known then unknownArea(self, 39, 115, 162) end
    end
    self:pokedexActions(model)
  end

  -- Cry: an oscilloscope on a Pokétch LCD with a speaker that pulses while
  -- the cry plays and a sweep that follows the waveform.
  local LCD_BG, LCD_INK, LCD_MID = hex("b4cc98"), hex("2c3c24"), hex("8aa474")
  function H:pokedexCry(model)
    local G = ui.graphics
    hero(self, model, hex("4888e0"), translate("CRY"), translate(model.playing and "PLAYING" or "READY"))
    local tall = model.compactActions and 29 or 0
    screenWell(self, 7, 76, 226, 75 + tall, LCD_BG)
    local x0, y0, w0, h0 = 36, 82, 190, 62 + tall
    for gx = x0, x0 + w0, 10 do R(gx, y0, 1, h0, mix(LCD_BG, LCD_MID, 0.35)) end
    for gy = y0, y0 + h0, 10 do R(x0, gy, w0 + 1, 1, mix(LCD_BG, LCD_MID, 0.35)) end
    local mid = y0 + floor(h0 / 2)
    R(x0, mid, w0 + 1, 1, LCD_MID)
    for sy = 81, 146 + tall, 2 do R(11, sy, 218, 1, { 0, 0, 0, 0.03 }) end
    -- speaker with sound arcs
    local playing = model.playing
    local beat = playing and floor(self:clock() / 0.15) % 3 or -1
    if playing then self:wantAmbient(0.15) end
    ART({ "....##", "...###", "######", "######", "######", "...###", "....##" }, 13, mid - 3, { ["#"] = LCD_INK })
    for i = 0, 2 do
      local on = beat >= i
      local c = on and LCD_INK or mix(LCD_BG, LCD_MID, 0.6)
      R(21 + i * 3, mid - 2 - i * 2, 1, 5 + i * 4, c)
    end
    -- waveform: 2px trace through the sixteen samples
    local px, py
    local points = {}
    for i = 0, 15 do
      local v = model.wave and (model.wave[i] or 0) % 256 or 0
      if v >= 128 then v = v - 256 end
      local y = mid - floor(max(-60, min(60, v)) * (28 + floor(tall / 2)) / 60 + 0.5)
      local x = x0 + floor(i * w0 / 15 + 0.5)
      points[#points + 1] = { x, y }
    end
    -- body of the wave: columns filled from the zero line, so the
    -- cry reads as a sound shape, not just a trace
    local fill = mix(LCD_BG, LCD_INK, 0.24)
    for i = 2, #points do
      local ax, ay, bx, by = points[i - 1][1], points[i - 1][2], points[i][1], points[i][2]
      for x = ax, bx - 1 do
        if x % 3 ~= 2 then
          local y = floor(ay + (by - ay) * (x - ax) / max(1, bx - ax) + 0.5)
          if y < mid then R(x, y, 1, mid - y, fill) elseif y > mid then R(x, mid + 1, 1, y - mid, fill) end
        end
      end
    end
    G.setLineStyle("rough")
    G.setLineWidth(2)
    G.setColor(LCD_INK[1], LCD_INK[2], LCD_INK[3], 1)
    for i = 2, #points do
      G.line(points[i - 1][1], points[i - 1][2], points[i][1], points[i][2])
    end
    G.setLineWidth(1)
    for _, p in ipairs(points) do R(p[1] - 1, p[2] - 1, 3, 3, LCD_INK) end
    if playing and self.motionEnabled ~= false then
      local sweep = x0 + floor(((self:clock() / 1.2) % 1) * w0)
      self:wantAmbient(0.1, 1 / 20)
      R(sweep, y0, 2, h0, { LCD_INK[1], LCD_INK[2], LCD_INK[3], 0.35 })
    end
    self:pokedexActions(model)
  end

  -- Size: a measuring wall with a ruler, floor line and the caption plate.
  function H:pokedexSize(model)
    local colors = self.colors
    local mon = model.pokemon or {}
    hero(self, model, hex("e8a030"), translate("SIZE"), mon.height or "--")
    local wall = mix(colors.surface, hex("e8c890"), self.dark and 0.12 or 0.22)
    local tall = model.compactActions and 29 or 0
    local floorY = 133 + tall
    screenWell(self, 7, 76, 226, 75 + tall, wall)
    for gx = 19, 225, 8 do R(gx, 80, 1, floorY - 80, mix(wall, colors.outline, 0.08)) end
    for gy = 80, floorY - 1, 8 do R(19, gy, 207, 1, mix(wall, colors.outline, 0.08)) end
    -- ruler down the left edge
    R(11, 80, 7, floorY - 80, mix(wall, hex("e8a030"), 0.5))
    for i = 0, floor((floorY - 81) / 7) do
      local ty = floorY - 1 - i * 7
      R(11, ty, i % 2 == 0 and 6 or 3, 1, colors.outline)
    end
    R(18, 80, 1, floorY - 80, colors.outline)
    -- floor the silhouettes stand on, and a caption plate with room to breathe
    R(11, floorY, 218, 1, colors.outline)
    R(11, floorY + 1, 218, 13, mix(wall, colors.outline, self.dark and 0.3 or 0.12))
    self:pokedexComparison(model)
    self:v4Prose(function()
      self:partyInfoCentered(self:fitPartyInfo(model.caption or "", 206), 17, floorY + 2, 206, 11, colors.ink)
    end)
    self:pokedexActions(model)
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
