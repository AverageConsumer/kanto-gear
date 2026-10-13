return function(ART, CH, CIRC, CIRCrows, Dex, H, R, RR, WHITE, base, box, cg, floor, hex, max, min, mix, translate)
  -- Native search/options share the device strip with the lens. Keep their
  -- drawing and touch bounds to its right, below the region and counters.
  if Dex then
    function Dex.toolRect(index)
      return 58 + (index - 1) * 86, 49, 82, 15
    end
  end
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
    local stripY = model.tools and 29 or 34
    local statusY = model.tools and 36 or 40
    box(self, 7, stripY, 226, 64 - stripY)
    RR(9, stripY + 2, 222, 4, 1, mix(red, colors.surface, 0.15))
    self:v4DexLens(12, model.tools and 37 or 41)
    local region = self:fitPartyType(translate(model.region or "NATIONAL DEX"), 80)
    self:partyInfo(region, 58, statusY, colors.mutedInk)
    local count = tostring(model.caught or 0) .. " / " .. tostring(model.total or 0)
    self:partyInfo(count, 140, statusY, colors.ink, 86, "right")
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
    -- pager: two finger-sized keys around the page count
    local page, pages = model.page or 1, model.pages or 1
    if pages > 1 and H.v4PagerKey then
      local px, py, pw, ph = Dex.pagerRect(-1, false)
      local nx = Dex.pagerRect(1, false)
      local cu = model.canUse ~= false
      H.v4PagerKey(self, px, py, pw, ph, true, page > 1, cu)
      H.v4PagerKey(self, nx, py, pw, ph, false, page < pages, cu)
      self:partyInfoCentered(tostring(page) .. "/" .. tostring(pages), px + pw, py, nx - px - pw, ph - 2, colors.ink)
    elseif pages > 1 then
      self:partyInfoCentered(tostring(page) .. "/" .. tostring(pages), 100, 199, 40, 12, colors.green)
    end
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
  -- Trainer Card. Gen 3 cards change colour with the stars the game awards
  -- (trainer_card.c sHoennTrainerCardPals / sKantoTrainerCardPals); Gen 1 and
  -- 2 have no such rank, so their card stays plain and starless.
  ---------------------------------------------------------------------------
  local CARD_COLORS = {
    hoenn = { { "3f8a58", "88cc9c" }, { "9a6030", "d8a068" }, { "b0583c", "e89a7c" },
      { "8a8f9c", "d0d6e0" }, { "c8a020", "f8e070" } },
    kanto = { { "3a6ad0", "90b8f8" }, { "3f8a58", "88cc9c" }, { "9a6030", "d8a068" },
      { "8a8f9c", "d0d6e0" }, { "c8a020", "f8e070" } },
    plain = { { "4f9a6c", "8cd0a4" } },
  }
  return CARD_COLORS
end
