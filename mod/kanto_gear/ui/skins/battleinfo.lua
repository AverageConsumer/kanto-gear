-- Kanto Gear v4: battle intel — enemy overview, Pokédex profile, DVs,
-- type matchups and the move info card shared by battle/summary/learning.
-- Hit geometry (enemyInfoHit / tap handlers) is unchanged.
return function(H, ui, K)
  local floor, max, min = math.floor, math.max, math.min
  local R, P, RR, RRrows, CH, CHrows = K.R, K.P, K.RR, K.RRrows, K.CH, K.CHrows
  local CIRC, RING, ART = K.CIRC, K.RING, K.ART
  local mix, hex = K.mix, K.hex
  local cg, WHITE = K.cg, K.WHITE
  local translate = function(value) return ui.translate and ui.translate(value) or value end

  local RED, GREEN, BLUE, GREY = hex("e05040"), hex("48a858"), hex("3878d0"), hex("808890")
  local ARROW_UP = { "..#..", ".###.", "#####" }
  local ARROW_DN = { "#####", ".###.", "..#.." }
  local SHIELD = { "#######", "#.....#", "#.....#", ".#...#.", "..#.#..", "...#..." }
  local STAR = { "...#...", "..###..", "#######", ".#####.", ".##.##.", "##...##" }
  local CROSS = { "#...#", ".#.#.", "..#..", ".#.#.", "#...#" }

  local function effectColor(label)
    label = tostring(label or "")
    if label == "4X" then return hex("c02818") end
    if label == "2X" then return RED end
    if label == "1/2" then return BLUE end
    if label == "1/4" then return hex("2850a0") end
    if label == "0X" then return GREY end
    return hex("8890a0")
  end

  -- Thin gauge with a darker rim; fraction 0..1.
  local function gauge(self, x, y, w, frac, color)
    local colors = self.colors
    R(x, y, w, 5, colors.outline)
    R(x + 1, y + 1, w - 2, 3, self.dark and hex("26303c") or hex("dfe3db"))
    local fill = floor((w - 2) * max(0, min(1, frac or 0)) + 0.5)
    if fill > 0 then
      R(x + 1, y + 1, fill, 3, color)
      R(x + 1, y + 1, fill, 1, mix(color, WHITE, 0.45))
    end
  end
  K.gauge = gauge

  ---------------------------------------------------------------------------
  -- Hero strip used by DVs and matchups (portrait · name · context)
  ---------------------------------------------------------------------------
  local function heroStrip(self, model, accent, label)
    local colors = self.colors
    local mon = model.pokemon or {}
    self.v4SummaryWindow(self, 7, 34, 226, 37, accent)
    self:v4Seat(11, 36, 33)
    if model.drawPokemon then model.drawPokemon(mon, 12, 37, 31, false) end
    self:partyName(self:fitPartyInfo(mon.name or translate("POKEMON"), 100), 49, 37, colors.ink, 100)
    self:typeBadges(mon, 49, 55, false)
    if label then
      local text = self:fitPartyInfo(translate(label), 80)
      self:partyInfo(text, 226 - self:partyInfoWidth(text), 38, colors.mutedInk)
    end
  end

  ---------------------------------------------------------------------------
  -- Overview
  ---------------------------------------------------------------------------
  local function miniMatchups(self, rows, x, y, w)
    local colors = self.colors
    if #rows == 0 then
      self:partyInfo("--", x, y + 10, colors.mutedInk, w, "center")
      return
    end
    local shown = min(4, #rows)
    for i = 1, shown do
      local row = rows[i]
      local col, line = (i - 1) % 2, floor((i - 1) / 2)
      local px, py = x + col * 50, y + line * 13
      self:v4TypePill(row.type, row.typeLabel or row.type, px, py, 30)
      self:partyInfo(row.effectLabel or "", px + 32, py - 2, effectColor(row.effectLabel))
    end
    if #rows > 4 then self:partyInfo("+" .. tostring(#rows - 4), x + w - 14, y + 26, colors.mutedInk) end
  end

  function H:enemyInfoOverview(model)
    local colors = self.colors
    local mon = model.pokemon or {}
    self:enemyInfoHero(model, 66)
    -- DVs key (151..224 × 72..93)
    local has = mon.dvs ~= nil
    local pressed = self:beginPress(151, 72, 73, 21, has)
    self:v4Key(151, 73, 73, 19, not has and { cap = colors.bandLight, lip = colors.band, hi = colors.bandLight } or nil)
    if has then
      local total = (mon.dvs.attack or 0) + (mon.dvs.defense or 0) + (mon.dvs.speed or 0) + (mon.dvs.special or 0)
      self:partyInfo("DV", 158, 77, colors.ink)
      gauge(self, 175, 81, 34, total / 60, cg(self) and self.tok.acc.M or colors.green)
      ART({ "#..", "##.", "###", "##.", "#.." }, 214, 80, { ["#"] = colors.mutedInk })
    else
      self:partyInfo("DV --", 151, 77, colors.disabledInk, 73, "center")
    end
    self:endPress(pressed)
    -- Pokédex card (7..233 × 105..144)
    local profile = self:beginPress(7, 105, 226, 39, mon.profileAvailable ~= false)
    local dexAccent = hex("d04838")
    self:v4Window(7, 105, 226, 39, { fill = mix(colors.surface, dexAccent, self.dark and 0.12 or 0.06) })
    if cg(self) then R(8, 109, 2, 31, dexAccent) else R(11, 106, 218, 2, dexAccent) end
    -- tiny dex device glyph
    ART({ "oooooooo", "o######o", "o#wwww#o", "o#wwww#o", "o######o", "o#o##o#o", "oooooooo" }, 15, 117,
      { o = colors.outline, ["#"] = dexAccent, w = hex("a8d8f0") })
    self:partyInfo(translate("POKEDEX"), 28, 110, colors.mutedInk)
    local dex = mon.dex and string.format("No.%03d", mon.dex) or "No.---"
    self:partyName(dex, 28, 123, colors.ink, 60)
    local kind = mon.kind and self:fitPartyInfo(translate(mon.kind), 104)
    if kind then self:partyInfo(kind, 100, 110, colors.green, 110, "right") end
    if mon.height then self:partyInfo(self:fitPartyInfo(mon.height, 104), 100, 126, colors.mutedInk, 110, "right") end
    ART({ "#..", "##.", "###", "##.", "#.." }, 220, 121, { ["#"] = colors.mutedInk })
    self:endPress(profile)
    -- Weak / resist cards (149..210)
    for _, card in ipairs({
      { key = "WEAK", rows = mon.weak or {}, x = 7, accent = RED, icon = ARROW_DN },
      { key = "RESIST", rows = mon.resist or {}, x = 123, accent = BLUE, icon = SHIELD },
    }) do
      local p = self:beginPress(card.x, 149, 110, 61, mon.matchupsAvailable ~= false)
      self:v4Window(card.x, 149, 110, 61, { fill = mix(colors.surface, card.accent, self.dark and 0.12 or 0.06) })
      if cg(self) then R(card.x + 1, 153, 2, 53, card.accent) else R(card.x + 4, 150, 102, 2, card.accent) end
      ART(card.icon, card.x + 7, 156, { ["#"] = card.accent })
      self:partyInfo(translate(card.key), card.x + 16, 153, colors.ink)
      local count = mon.matchupsAvailable == false and "--" or tostring(#card.rows)
      self:partyInfo(count, card.x + 90 - self:partyInfoWidth(count), 153, colors.mutedInk)
      ART({ "#..", "##.", "###", "##.", "#.." }, card.x + 99, 156, { ["#"] = colors.mutedInk })
      miniMatchups(self, card.rows, card.x + 7, 172, 98)
      self:endPress(p)
    end
  end

  ---------------------------------------------------------------------------
  -- Pokédex profile
  ---------------------------------------------------------------------------
  function H:enemyInfoProfile(model)
    local colors = self.colors
    local mon = model.pokemon or {}
    self:enemyInfoHero(model, 74)
    -- the entry's facts live in the hero card, like a Pokédex page:
    -- category in the accent, height and weight underneath
    self:partyInfo(self:fitPartyInfo(translate(mon.kind or "UNKNOWN"), 150), 73, 70, colors.green)
    self:partyInfo(self:fitPartyInfo(mon.height or translate("HEIGHT --"), 150), 73, 82, colors.mutedInk)
    self:partyInfo(self:fitPartyInfo(mon.weight or translate("WEIGHT --"), 150), 73, 93, colors.mutedInk)
    self:v4MessageWindow(7, 113, 226, 97)
    local lines = mon.description or {}
    if #lines == 0 then lines = { translate("NO DETAILS AVAILABLE") } end
    local visible = min(5, #lines)
    local top = 113 + floor((97 - 6 - visible * 15) / 2)
    self:v4Prose(function()
      for i = 1, visible do
        self:partyInfo(self:fitPartyInfo(lines[i], 202), 17, top + (i - 1) * 15, colors.ink, 206, "center")
      end
    end)
  end

  ---------------------------------------------------------------------------
  -- DVs: 16-cell gauges, best stat star, Gen 2 shiny pattern
  ---------------------------------------------------------------------------
  local DV_COLOR = { HP = "48b858", ATTACK = "e05848", DEFENSE = "e8a030", SPEED = "e868a8", SPECIAL = "4888e0" }
  local SHINY_ATTACK = { [2] = true, [3] = true, [6] = true, [7] = true, [10] = true, [11] = true, [14] = true, [15] = true }

  function H:enemyInfoDvs(model)
    local colors = self.colors
    local mon, rows = model.pokemon or {}, model.rows or {}
    heroStrip(self, model, cg(self) and self.tok.acc.M or colors.blueLight, nil)
    if #rows == 0 then
      self:v4Window(24, 82, 192, 90, { fill = colors.bandLight })
      self:partyInfo(translate("NO DETAILS AVAILABLE"), 32, 121, colors.mutedInk, 176, "center")
      return
    end
    local byLabel, best = {}, -1
    for _, row in ipairs(rows) do
      byLabel[row.label] = tonumber(row.value) or 0
      if row.label ~= "HP" then best = max(best, tonumber(row.value) or 0) end
    end
    self:v4Window(7, 75, 226, 135)
    for i, row in ipairs(rows) do
      local y = 81 + (i - 1) * 21
      local value = tonumber(row.value) or 0
      if i % 2 == 0 then R(9, y - 2, 222, 20, self.dark and { 1, 1, 1, 0.03 } or { 0, 0, 0, 0.03 }) end
      local c = hex(DV_COLOR[row.label] or "8890a0")
      self:partyInfo(self:fitPartyInfo(translate(row.label), 56), 14, y + 2, colors.ink)
      -- 16 cells
      for k = 0, 15 do
        local cx = 74 + k * 8
        R(cx, y + 3, 7, 9, colors.outline)
        local on = k < value
        R(cx + 1, y + 4, 5, 7, on and c or (self.dark and hex("26303c") or hex("e2e6de")))
        if on then R(cx + 1, y + 4, 5, 2, mix(c, WHITE, 0.45)) end
      end
      local text = tostring(value)
      self:partyInfo(text, 218 - self:partyInfoWidth(text), y + 2, colors.ink)
      if value == 15 or (row.label ~= "HP" and value == best and best > 0) then
        ART(STAR, 220, y + 4, { ["#"] = value == 15 and hex("f0c020") or colors.silverDark })
      end
    end
    -- footer: total + Gen 2 shiny DV pattern
    local a, d, s, sp = byLabel.ATTACK, byLabel.DEFENSE, byLabel.SPEED, byLabel.SPECIAL
    R(14, 186, 212, 1, colors.band)
    if a and d and s and sp then
      local total = tostring(a + d + s + sp) .. "/60"
      self:partyInfo(translate("TOTAL"), 14, 192, colors.mutedInk)
      self:partyInfo(total, 14 + self:partyInfoWidth(translate("TOTAL")) + 6, 192, colors.ink)
      -- Game path [Gen 2]: shininess follows the native DV pattern; Gen 1 DVs must not acquire a shiny indicator.
      if mon.gen2 ~= false and d == 10 and s == 10 and sp == 10 and SHINY_ATTACK[a] then
        local t = self:clock()
        local c = floor(t / 0.3) % 2 == 0 and hex("f8d048") or WHITE
        ART(STAR, 206, 193, { ["#"] = c }); self:wantAmbient(0.3)
      end
    end
    self:partyInfo(translate("RANGE 0-15"), 120, 192, colors.mutedInk, 100, "right")
  end

  ---------------------------------------------------------------------------
  -- Matchups grouped by multiplier
  ---------------------------------------------------------------------------
  local ORDER = { ["4X"] = 1, ["2X"] = 2, ["1/2"] = 3, ["1/4"] = 4, ["0X"] = 5 }
  function H:enemyInfoMatchup(model)
    local colors = self.colors
    local rows = model.rows or {}
    local weak = model.kind == "weak"
    heroStrip(self, model, weak and RED or BLUE, "BASE MATCHUP")
    if #rows == 0 then
      self:v4Window(24, 92, 192, 70, { fill = colors.bandLight })
      self:partyInfo("--", 32, 122, colors.mutedInk, 176, "center")
      return
    end
    local groups, keys = {}, {}
    for _, row in ipairs(rows) do
      local key = row.effectLabel or "--"
      if not groups[key] then groups[key] = {}; keys[#keys + 1] = key end
      local list = groups[key]
      list[#list + 1] = row
    end
    table.sort(keys, function(x, y) return (ORDER[x] or 9) < (ORDER[y] or 9) end)
    -- measure: each group = ceil(n/3) lines of 14px + 8px padding
    local heights, total = {}, 0
    for i, key in ipairs(keys) do
      local lines = math.ceil(#groups[key] / 2)
      heights[i] = max(28, lines * 17 + 9)
      total = total + heights[i] + (i > 1 and 4 or 0)
    end
    local y = 77
    for i, key in ipairs(keys) do
      local h = heights[i]
      local c = effectColor(key)
      self:v4Window(7, y, 226, h, { fill = mix(colors.surface, c, self.dark and 0.12 or 0.07) })
      -- multiplier badge
      if cg(self) then CH(11, y + 3, 36, h - 6, 3, mix(c, { 0, 0, 0, 1 }, 0.35)); CH(12, y + 4, 34, h - 8, 2, c)
      else RR(11, y + 3, 36, h - 6, 4, mix(c, { 0, 0, 0, 1 }, 0.35)); RR(12, y + 4, 34, h - 8, 3, c)
        R(14, y + 4, 30, 1, mix(c, WHITE, 0.4)) end
      local label = key == "0X" and "×0" or key:gsub("X", "×")
      if key == "0X" then
        ART(CROSS, 27, y + floor(h / 2) - 2, { ["#"] = WHITE })
      else
        self:withoutShadow(self.partyInfo, self, label, 11, y + floor((h - 11) / 2), WHITE, 36, "center")
      end
      for j, row in ipairs(groups[key]) do
        local col, line = (j - 1) % 2, floor((j - 1) / 2)
        local px, py = 54 + col * 88, y + 5 + line * 17 + floor((h - 9 - math.ceil(#groups[key] / 2) * 17) / 2) + 4
        self:v4TypePill(row.type, row.typeLabel or row.type, px, py, 84)
      end
      y = y + h + 4
    end
    -- the opposite side, compact, so one page reads as a full matchup sheet
    local mon = model.pokemon or {}
    local other = weak and (mon.resist or {}) or (mon.weak or {})
    if #other > 0 then
      local lines = math.ceil(min(#other, 8) / 4)
      local h = 17 + lines * 13
      local top = y + 4
      if top + h <= 211 then
        local oc = weak and BLUE or RED
        self:v4Window(7, top, 226, h, { fill = colors.bandLight })
        ART(weak and SHIELD or ARROW_DN, 13, top + 5, { ["#"] = oc })
        self:partyInfo(translate(weak and "RESIST" or "WEAK"), 22, top + 2, colors.mutedInk)
        for j = 1, min(#other, 8) do
          local row = other[j]
          local col, line = (j - 1) % 4, floor((j - 1) / 4)
          local px, py = 13 + col * 54, top + 16 + line * 13
          self:v4TypePill(row.type, row.typeLabel or row.type, px, py, 30)
          self:partyInfo(row.effectLabel or "", px + 32, py - 2, effectColor(row.effectLabel))
        end
        y = top + h
      end
    end
    -- battle tip in the message window: what to use, what to avoid
    local bottom = 210
    if bottom - (y + 6) >= 30 then
      local names = {}
      local source = weak and rows or rows
      for i = 1, min(3, #source) do names[#names + 1] = tostring(source[i].type or source[i].typeLabel or "") end
      local list = table.concat(names, ", ")
      local text = weak and (translate("TRY") .. " " .. list .. " " .. translate("MOVES"))
        or (translate("AVOID") .. " " .. list .. " " .. translate("MOVES"))
      local top = y + 6
      local h = min(44, bottom - top)
      self:v4MessageWindow(7, top, 226, h)
      local icon = weak and STAR or SHIELD
      local a, b = self:splitPartyInfo(text, 180)
      local lines = (b and #b > 0) and { a, b } or { a }
      local ty = top + floor((h - #lines * 11) / 2) - 1
      ART(icon, 18, top + floor((h - #icon) / 2) - 1, { ["#"] = weak and hex("e8a030") or BLUE })
      for i, line in ipairs(lines) do self:partyInfo(line, 32, ty + (i - 1) * 11, colors.ink, 188, "center") end
    end
  end

  ---------------------------------------------------------------------------
  -- Move info card
  ---------------------------------------------------------------------------
  function H:battleMoveInfoBody(move, stab)
    local colors = self.colors
    local accent = self:typeColor(move.type)
    self.v4SummaryWindow(self, 6, 33, 228, 169, accent)
    self:partyName(self:fitPartyInfo(move.name or "-", 150), 16, 40, colors.ink, 150)
    self:moveTypeBadge(move, 178, 42)
    R(14, 58, 212, 1, colors.band)
    -- three stat cells
    local power = tonumber(move.power) or tonumber(move.powerText)
    local accuracy = tostring(move.accuracyText or "--")
    local accNum = tonumber((accuracy:gsub("%%", "")))
    if accuracy ~= "--" and not accuracy:find("%%") then accuracy = accuracy .. "%" end
    local pp = tostring(move.ppText or "--")
    local ppNow, ppMax = pp:match("(%d+)%s*/%s*(%d+)")
    local cells = {
      { move.powerLabel or translate("PWR"), tostring(move.powerText or "--"), power and power / 150 or 0, hex("e05848") },
      { move.accuracyLabel or translate("ACC"), accuracy, accNum and accNum / 100 or 0, hex("4888e0") },
      { move.ppLabel or translate("PP"), pp, ppNow and tonumber(ppNow) / max(1, tonumber(ppMax)) or 0,
        ppNow and tonumber(ppNow) / max(1, tonumber(ppMax)) <= 0.25 and hex("e8a030") or hex("48b858") },
    }
    for i, cell in ipairs(cells) do
      local x = 14 + (i - 1) * 71
      self:v4Window(x, 63, 66, 42, { fill = colors.bandLight, shadow = false })
      self:partyInfo(cell[1], x, 66, colors.mutedInk, 66, "center")
      self:partyName(cell[2], x + floor((66 - self:partyInfoWidth(cell[2])) / 2), 78, colors.ink, 64)
      gauge(self, x + 6, 95, 54, cell[3], cell[4])
    end
    if move.disabled then
      local lines = move.disabledLines or { move.disabledLabel or translate("DISABLED") }
      self:v4Window(14, 111, 212, 38, { fill = mix(colors.surface, RED, 0.35) })
      local top = 111 + floor((38 - #lines * 10) / 2)
      for index, line in ipairs(lines) do
        self:partyInfo(self:fitPartyInfo(line, 196), 22, top + (index - 1) * 10, colors.ink, 196, "center")
      end
    else
      local label, eff = self:battleEffectLabel(move)
      local stabX = eff ~= nil and 14 or 68
      local stabCenter = stabX + 52
      -- STAB
      self:v4Window(stabX, 111, 104, 38, { fill = colors.bandLight, shadow = false })
      self:partyInfo(move.stabLabel or translate("STAB"), stabX, 114, colors.mutedInk, 104, "center")
      local sc = stab and accent or colors.silverDark
      self:v4Pill(stab and "1.5×" or "--", stabCenter - (stab and 14 or 20), 131, sc, { raw = true, w = 40 })
      if stab then ART(STAR, stabCenter - 26, 133, { ["#"] = hex("f0c020") }) end
      -- MATCHUP
      if eff ~= nil then
        self:v4Window(122, 111, 104, 38, { fill = colors.bandLight, shadow = false })
        self:partyInfo(move.matchupLabel or translate("MATCHUP"), 122, 114, colors.mutedInk, 104, "center")
        local ec = self:matchupStyle(eff).pill
        self:v4Pill(label:gsub("X", "×"), 154, 131, ec, { raw = true, w = 40 })
        if eff > 10 then ART(ARROW_UP, 142, 134, { ["#"] = ec }); if eff >= 40 then ART(ARROW_UP, 142, 138, { ["#"] = ec }) end
        elseif eff > 0 and eff < 10 then ART(ARROW_DN, 142, 135, { ["#"] = ec })
        elseif eff == 0 then ART(CROSS, 142, 134, { ["#"] = GREY }) end
      end
    end
    -- description
    local lines = move.descriptionLines or { move.description or "--" }
    if cg(self) then CH(14, 154, 212, 42, 3, colors.outline); CH(15, 155, 210, 40, 2, self.dark and hex("1a222c") or hex("fbfcfd"))
    else RR(14, 154, 212, 42, 4, colors.outline); RR(15, 155, 210, 40, 3, self.dark and hex("26303e") or hex("fbfbf6"))
      for ly = 168, 192, 12 do R(20, ly, 200, 1, self.dark and { 1, 1, 1, 0.05 } or { 0, 0, 0, 0.05 }) end end
    self:v4Prose(function()
      if lines[2] then
        self:partyInfo(self:fitPartyInfo(lines[1], 196), 22, 158, colors.ink, 196, "center")
        self:partyInfo(self:fitPartyInfo(lines[2], 196), 22, 171, colors.ink, 196, "center")
        if lines[3] then self:partyInfo(self:fitPartyInfo(lines[3], 196), 22, 184, colors.ink, 196, "center") end
      else
        self:partyInfo(self:fitPartyInfo(lines[1], 196), 22, 169, colors.ink, 196, "center")
      end
    end)
  end
end
