return function(ART, CAT_GLYPH, CH, CIRC, H, K, R, RR, RRrows, WHITE, base, cg, floor, hex, max, min, mix, translate, ui)
  local function accentOf(self, name)
    local map = { blue = hex("3878d0"), green = hex("3ea04c"), red = hex("e04838"), amber = hex("e09a20") }
    return map[name or ""] or self.tok.acc.M
  end

  function H:settings(model)
    local colors = self.colors
    model = model or {}
    if not model.category then
      local count = #(model.categories or {})
      local spacing = count > 6 and floor(178 / count) or 30
      for index, category in ipairs(model.categories or {}) do
        local y = 34 + (index - 1) * spacing
        local pressed = self:beginPress(7, y, 226, min(26, spacing - 2))
        local accent = accentOf(self, category.accent)
        self:v4Key(7, y, 226, min(27, spacing - 1))
        if cg(self) then R(8, y + 4, 2, min(17, spacing - 11), accent) end
        -- glyph seat
        CIRC(11, y + 2, 22, colors.outline)
        CIRC(12, y + 3, 20, mix(colors.surface, accent, self.dark and 0.35 or 0.22))
        local glyph = CAT_GLYPH[tostring(category.label)]
        local artName = "c_" .. tostring(category.label):lower()
        if artName == "c_exploration" then artName = "c_research" end
        if self.v4HasIcon and self:v4HasIcon(artName) then self:v4Icon(artName, 14, y + 5)
        elseif glyph then glyph(12, y + 3, accent, mix(accent, colors.surface, 0.45)) end
        self:partyInfo(self:fitPartyInfo(translate(category.label), 170), 39, y + 2, colors.ink)
        self:partyInfo(self:fitPartyInfo(translate(category.detail), 170), 39, y + 12, colors.mutedInk)
        ART({ "#..", "##.", "###", "##.", "#.." }, 219, y + 10, { ["#"] = colors.mutedInk })
        self:endPress(pressed)
      end
      return
    end

    if model.option then
      local perPage = model.perPage or 4
      local first = (model.page - 1) * perPage + 1
      local G = ui.graphics
      local enter = self:v4Enter("settings_option", tostring(model.option) .. ":" .. model.page, 0.24)
      local count = min(perPage, #model.choices - first + 1)
      for visible = 0, perPage - 1 do
        local choice = model.choices[first + visible]
        if choice then
          local y, selected = self:settingsChoiceTop(model) + visible * 25, choice[2] == model.value
          local _, dx = self:v4Stagger(enter, visible + 1, 0.09, 16, count)
          if dx ~= 0 then G.push(); G.translate(dx, 0) end
          local pressed = self:beginPress(7, y, 226, 22, not selected)
          local off = self:v4Choice(7, y, 226, 22, selected, true) or 0
          -- radio mark
          local ink = selected and WHITE or colors.ink
          CIRC(14, y + 5 + off, 11, selected and WHITE or colors.outline)
          CIRC(15, y + 6 + off, 9, selected and (cg(self) and self.tok.acc.D or hex("1b5a4c")) or colors.surface)
          if selected then CIRC(17, y + 8 + off, 5, WHITE) end
          local label = translate(choice[1])
          local swatch = self.v4ThemeSwatch and self:v4ThemeSwatch(tostring(choice[2]), 196, y + 4 + off)
          self:partyInfo(self:fitPartyInfo(label, swatch and 160 or 190), 31, y + 4 + off, ink)
          self:endPress(pressed)
          if dx ~= 0 then G.pop() end
        end
      end
      if model.pages > 1 then
        H.v4PagerKey(self, 72, 133, 32, 14, true, model.page > 1, true)
        H.v4PagerKey(self, 136, 133, 32, 14, false, model.page < model.pages, true)
        self:partyInfoCentered(model.page .. "/" .. model.pages, 104, 133, 32, 12, colors.ink)
      end
      -- Gen 4 text box with typewriter help and the blinking advance mark
      self:v4MessageWindow(6, 150, 228, 62)
      local lines = self:settingsHelpLines(translate(model.description or ""))
      local key = tostring(model.option) .. ":" .. tostring(model.value)
      local now = self:clock()
      if self.v4HelpKey ~= key then self.v4HelpKey, self.v4HelpAt = key, now end
      local shown = (self.motionEnabled == false or self.frozenTime) and math.huge
        or floor((now - (self.v4HelpAt or now)) * 70)
      local total, left, characters = 0, shown, {}
      for index, line in ipairs(lines) do
        characters[index] = ui.glyphs(line)
        total = total + #characters[index]
      end
      local top = 150 + floor((62 - #lines * 9) / 2) - 1
      for index, line in ipairs(lines) do
        local chars = characters[index]
        local part = left >= #chars and line
          or table.concat(chars, "", 1, math.max(0, left))
        left = left - #chars
        if #part > 0 then self:partyInfo(part, 16, top + (index - 1) * 9 - 1, colors.ink) end
      end
      -- help text types itself out; no advance arrow, there is nothing to advance
      if shown < total then self:wantAmbient(0.05, 1 / 30) end
      return
    end

    if model.tabs then return self:v4SettingsTabbed(model) end
    local accent = accentOf(self, model.accent)
    local first = (model.page - 1) * 4 + 1
    for visible = 0, 3 do
      local row = model.rows[first + visible]
      if row then
        local y = 36 + visible * 40
        local enabled = row.enabled ~= false
        local pressed = self:beginPress(7, y, 226, 35, enabled)
        self:v4Window(7, y, 226, 35, { radius = 4 })
        R(8, y + 4, 2, 27, accent)
        local ink = enabled and colors.ink or colors.disabledInk
        self:partyInfo(self:fitPartyInfo(translate(row.label), 200), 15, y + 1, ink)
        local value = translate(row.value)
        if row.action then
          local warn = value == translate("TAP AGAIN")
          local a = K.rampOf(not enabled and colors.silverDark or warn and hex("e04838") or accent)
          local off = self:v4Button(60, y + 16, 120, 15, a, { radius = 4, lip = 3, chamfer = 3 })
          self:partyType(self:fitPartyType(value, 112), 64, y + 16 + off, WHITE, 112)
        else
          local choices = row.choices or {}
          local fits = #choices >= 2 and #choices <= 3
          if fits then
            local segW = floor(210 / #choices)
            for _, choice in ipairs(choices) do
              if self:partyInfoWidth(translate(choice[1])) > segW - 6 then fits = false end
            end
          end
          if fits then
            self:v4Segments(15, y + 15, 210, choices, row.raw, enabled, accent)
          else
            local well = mix(colors.surface, accent, self.dark and 0.22 or 0.12)
            if cg(self) then CH(15, y + 15, 210, 17, 3, colors.outline); CH(16, y + 16, 208, 15, 2, well)
            else RR(15, y + 15, 210, 17, 4, colors.outline); RR(16, y + 16, 208, 15, 3, well)
              R(18, y + 16, 204, 1, { 0, 0, 0, 0.12 }) end
            local valueInk = enabled and colors.ink or colors.disabledInk
            local firstLine, secondLine
            if self:partyInfoWidth(value) > 176 then firstLine, secondLine = self:splitPartyInfo(value, 176) end
            if secondLine then
              self:partyType(firstLine, 24, y + 14, valueInk, 176)
              self:partyType(secondLine, 24, y + 22, valueInk, 176)
            else
              self:partyType(self:fitPartyType(value, 176), 24, y + 18, valueInk, 176)
            end
            self:detailChevron(214, y + 21, enabled and accent or colors.disabledInk)
          end
        end
        self:endPress(pressed)
      end
    end
    if (model.pages or 1) > 1 then
      H.v4PagerKey(self, 72, 195, 32, 15, true, model.page > 1, true)
      H.v4PagerKey(self, 136, 195, 32, 15, false, model.page < model.pages, true)
      self:partyInfoCentered(model.page .. "/" .. model.pages, 104, 195, 32, 13, colors.ink)
    end
  end

  ---------------------------------------------------------------------------
  -- Field Kit cards
  ---------------------------------------------------------------------------
  -- Shared label: one line when it fits, else two (one long word breaks with
  -- a hyphen and keeps its own lettering: "Buscaob-/jetos", not "Buscao/Bjetos").
  local function toolLabel(self, label, x, y, w, h, ink)
    label = tostring(label or "")
    local a, b = label, nil
    if self:partyInfoWidth(label) > w then a, b = self:splitPartyInfo(label, w) end
    local top = y + floor((h - (b and 22 or 11)) / 2) - 1
    if b and not label:find("%s") and self.v4Cased then
      local word = self:v4Cased(label)
      self:v4Caps(function()
        local first, rest = self:splitPartyInfo(word, w - 4)
        if rest and not first:find("%-$") then first = first .. "-" end
        self:partyInfo(first, x, top, ink, w, "center")
        self:partyInfo(self:fitPartyInfo(rest or "", w), x, top + 11, ink, w, "center")
      end)
    elseif b then
      self:partyInfo(a, x, top, ink, w, "center")
      self:partyInfo(self:fitPartyInfo(b, w), x, top + 11, ink, w, "center")
    else
      self:partyInfo(self:fitPartyInfo(a, w), x, top, ink, w, "center")
    end
  end

  local function toolSeat(self, icon, x, y, accent)
    local seat = mix(self.colors.surface, accent, self.dark and 0.3 or 0.2)
    if cg(self) then CH(x, y, 28, 28, 4, seat) else RR(x, y, 28, 28, 5, seat) end
    self:toolIcon(icon, x, y, accent)
  end

  local function chevron(self, x, y, tint)
    local bob = (self.motionEnabled ~= false and floor(self:clock() / 0.5) % 2 == 0) and 1 or 0
    self:wantAmbient(0.5)
    ART(K.CHEV_R, x + bob, y, { ["#"] = tint })
  end

  ---------------------------------------------------------------------------
  -- Field Kit: a lit card is usable right here (tap it); location-changing
  -- moves arm first and ask for a second tap in place; the grey grid below
  -- lists what is unlocked but has nothing to act on here.
  ---------------------------------------------------------------------------
  local WARN = hex("e04838")
  function H:toolCard(action, item, armed)
    local colors = self.colors
    local x, y, w, h = item.x, item.y, item.w, item.h
    local accent = armed and WARN or self:toolAccent(action.icon)
    local pressed = self:beginPress(x, y, w, h)
    self:v4Window(x, y, w, h, { radius = 5,
      fill = armed and mix(colors.surface, WARN, self.dark and 0.3 or 0.14) or nil })
    R(x + 2, y + 6, 2, h - 12, accent)
    toolSeat(self, action.icon, x + 7, y + 2, accent)
    if armed then
      -- the icon still names the move; the text asks for the second tap
      toolLabel(self, translate("TAP AGAIN"), x + 37, y, w - 50, h,
        self.dark and mix(WARN, WHITE, 0.45) or WARN)
    else
      toolLabel(self, action.label, x + 37, y, w - 50, h, colors.ink)
    end
    chevron(self, x + w - 10, y + 13, accent)
    self:endPress(pressed)
  end

  local ROD_TIER = { OLD_ROD = { "a07040", 1 }, GOOD_ROD = { "3878d0", 2 }, SUPER_ROD = { "e04838", 3 } }
  local STAR = { "...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", ".#...#." }
  function H:toolRodCard(action, item)
    local colors = self.colors
    local x, y, w, h = item.x, item.y, item.w, item.h
    local accent = self:toolAccent(action.icon)
    self:v4Window(x, y, w, h, { radius = 5 })
    R(x + 2, y + 6, 2, h - 12, accent)
    toolSeat(self, action.icon, x + 7, y + 2, accent)
    toolLabel(self, action.label, x + 35, y, 37, h, colors.ink)
    local rods = action.rods or {}
    for index, rod in ipairs(rods) do
      local rx, ry, rw, rh = self:toolRodRect(item, index, #rods)
      local tier = ROD_TIER[tostring(rod.id)] or { "3878d0", index }
      local pressed = self:beginPress(rx, ry, rw, rh)
      local off = self:v4Button(rx, ry, rw, rh, K.rampOf(hex(tier[1])), { radius = 4, lip = 3, chamfer = 3 }) or 0
      local sw = tier[2] * 9 - 2
      local sx, sy = rx + floor((rw - sw) / 2), ry + floor((rh - 3 - 7) / 2) + off
      for star = 1, tier[2] do
        ART(STAR, sx + (star - 1) * 9, sy, { ["#"] = hex("f8d848") })
      end
      self:endPress(pressed)
    end
  end

  function H:toolChip(action, item)
    local colors = self.colors
    local x, y, w, h = item.x, item.y, item.w, item.h
    if cg(self) then CH(x, y, w, h, 3, colors.band); CH(x + 1, y + 1, w - 2, h - 2, 2, colors.bandLight)
    else RR(x, y, w, h, 4, colors.band); RR(x + 1, y + 1, w - 2, h - 2, 3, colors.bandLight) end
    self:toolIcon(action.icon, x + 1, y, colors.silver)
    toolLabel(self, action.label, x + 28, y, w - 31, h, colors.mutedInk)
  end

  function H:toolSectionLabel(text, y)
    local colors = self.colors
    local tw = self:partyInfoWidth(text)
    self:partyInfo(text, 9, y - 2, colors.mutedInk)
    R(9 + tw + 5, y + 4, 224 - tw - 5, 1, colors.band)
  end

  -- Segmented strip; the active segment is a lipped key in the row accent.
  function H:v4Segments(x, y, w, choices, value, enabled, accent)
    local colors = self.colors
    local n = #choices
    local segW = floor(w / n)
    if cg(self) then CH(x, y, w, 17, 3, colors.outline); CH(x + 1, y + 1, w - 2, 15, 2, self.dark and hex("141b22") or hex("e4ebf0"))
    else RR(x, y, w, 17, 4, colors.outline); RR(x + 1, y + 1, w - 2, 15, 3, self.dark and hex("1c2533") or hex("dfe8e1"))
      R(x + 3, y + 1, w - 6, 1, { 0, 0, 0, 0.15 }) end
    local a = K.rampOf(enabled and (accent or self.tok.acc.M) or colors.silverDark)
    local activeIndex
    for i, choice in ipairs(choices) do if choice[2] == value then activeIndex = i end end
    -- the lit pill glides between segments instead of jumping
    local hx, hw
    if activeIndex then
      hw = activeIndex == n and w - segW * (n - 1) or segW
      hx = self:v4Glide("seg:" .. x .. ":" .. y .. ":" .. w, x + (activeIndex - 1) * segW)
      if cg(self) then CH(hx + 1, y + 1, hw - 2, 15, 2, a.M); CH(hx + 1, y + 1, hw - 2, 7, 2, a.L)
      else RR(hx + 1, y + 1, hw - 2, 15, 3, a.D); RR(hx + 1, y + 1, hw - 2, 13, 3, a.M)
        RRrows(hx + 1, y + 1, hw - 2, 13, 3, 0, 6, a.L); R(hx + 4, y + 1, hw - 8, 1, a.Hi) end
    end
    for i, choice in ipairs(choices) do
      local sx = x + (i - 1) * segW
      local sw = i == n and w - segW * (n - 1) or segW
      local label = translate(choice[1])
      local centre = sx + floor(sw / 2)
      local lit = hx and centre >= hx and centre < hx + hw
      if lit then
        self:partyType(label, sx, y + 2, WHITE, sw)
      else
        local prevLit = hx and i > 1 and (sx - floor(segW / 2)) >= hx and (sx - floor(segW / 2)) < hx + hw
        if i > 1 and not prevLit and not (hx and sx >= hx and sx <= hx + hw) then
          R(sx, y + 4, 1, 9, colors.band)
        end
        self:partyType(label, sx, y + 3, enabled and colors.mutedInk or colors.disabledInk, sw)
      end
    end
  end

  -- Theme choices preview their own colours as a tiny screen.
  function H:v4ThemeSwatch(value, x, y)
    local skin = value:find("cgear") and "cgear" or (value:find("pokegear") or value:find("^hgss")) and "pokegear"
    if not skin then return false end
    local K2 = K.SKINS[skin]
    if not K2 then return false end
    local auto = value:find("auto")
    local parts = auto and { "light", "dark" } or { value:find("dark") and "dark" or "light" }
    R(x - 1, y - 1, 30, 16, self.colors.outline)
    for i, v in ipairs(parts) do
      local tok = K2[v].tokens
      local w = auto and 14 or 28
      local sx = x + (i - 1) * 14
      R(sx, y, w, 14, tok.bgA or tok.bg)
      R(sx, y, w, 4, tok.acc.M)
      R(sx + 2, y + 6, w - 4, 6, tok.paper)
      R(sx + 3, y + 8, floor((w - 6) / 2), 2, tok.acc.L)
    end
    return true
  end

  -- Page swipes move only the choices; the help textbox stays put.
  function H:settingsMotionRegion(option, first, last)
    if option then return 34, 134 end
    if self.v4SettingsTabs then return 70, 166 end
    return first, last
  end

  function H:settingsChoiceTop(model)
    local perPage = model.perPage or 4
    local count = min(perPage, #(model.choices or {}) - ((model.page or 1) - 1) * perPage)
    local height = max(0, count * 25 - 3)
    return 36 + floor((97 - height) / 2)
  end

  ---------------------------------------------------------------------------
  -- Tabbed settings: category tabs, inline controls, help textbox.
  -- Touch-only safety: the first tap selects a row (and explains it),
  -- only a selected row changes its value.
  ---------------------------------------------------------------------------
  H.v4SettingsTabs = true
  local TAB_Y, TAB_H, TAB_STEP = 32, 22, 38
  -- Six tabs fill the 226 px row at 38 px; more tabs share it evenly and
  -- the row stays centred.
  local function tabStep(count) return count > 6 and floor(228 / count) or TAB_STEP end
  local function tabLeft(count) return 7 + floor((226 - (count * tabStep(count) - 2)) / 2) end
  local ROW_Y, ROW_H, ROW_STEP, CTRL_X, CTRL_W = 71, 22, 24, 114, 113

  local function rowKey(row) return row.key or row.action end
  local function segmentFits(self, row)
    local choices = row.choices or {}
    if #choices < 2 or #choices > 3 then return false end
    local segW = floor(CTRL_W / #choices)
    for _, choice in ipairs(choices) do
      if self:partyInfoWidth(translate(choice[1])) > segW - 5 then return false end
    end
    return true
  end

  local function typewriter(self, text, key, x, y, w, h, maxLines)
    local colors = self.colors
    local lines = self:settingsHelpLines(text)
    while #lines > (maxLines or 3) do table.remove(lines) end
    local now = self:clock()
    if self.v4HelpKey ~= key then self.v4HelpKey, self.v4HelpAt = key, now end
    local shown = (self.motionEnabled == false or self.frozenTime) and math.huge
      or floor((now - (self.v4HelpAt or now)) * 70)
    local total, left, characters = 0, shown, {}
    for index, line in ipairs(lines) do
      characters[index] = ui.glyphs(line)
      total = total + #characters[index]
    end
    -- a tall help panel reads from the top like a message window
    local top = (maxLines or 3) > 3 and y + 9 or y + floor((h - #lines * 11) / 2)
    for index, line in ipairs(lines) do
      local chars = characters[index]
      local part = left >= #chars and line
        or table.concat(chars, "", 1, math.max(0, left))
      left = left - #chars
      if #part > 0 then self:partyInfo(part, x + 10, top + (index - 1) * 11 - 1, colors.ink) end
    end
    if shown < total then self:wantAmbient(0.05, 1 / 30) end
  end

  function H:v4SettingsTabbed(model)
    local colors = self.colors
    -- category tabs
    local step, left = tabStep(#model.tabs), tabLeft(#model.tabs)
    for i, cat in ipairs(model.tabs) do
      local x = left + (i - 1) * step
      local active = i == model.tab
      local accent = accentOf(self, cat.accent)
      local pressed = self:beginPress(x, TAB_Y, step - 2, TAB_H, not active)
      if active then self:v4Button(x, TAB_Y, step - 2, TAB_H, K.rampOf(accent), { radius = 4, lip = 3, chamfer = 4 })
      else self:v4Key(x, TAB_Y, step - 2, TAB_H) end
      local glyph = CAT_GLYPH[tostring(cat.label)] or CAT_GLYPH[tostring(cat.id):upper()]
      local artName = "c_" .. tostring(cat.label):lower()
      if artName == "c_exploration" then artName = "c_research" end
      if self.v4HasIcon and not self:v4HasIcon(artName) then artName = "c_" .. tostring(cat.id):lower() end
      if self.v4HasIcon and self:v4HasIcon(artName) then
        local hop = 0
        if active then
          local e = self:v4Enter("settings_tab", i, 0.24)
          if e < 1 then hop = -floor(math.sin(e * math.pi) * 3 + 0.5) end
        end
        self:v4Icon(artName, x + floor((step - 2 - 16) / 2), TAB_Y + floor((TAB_H - 16) / 2) - (active and 1 or 0) + hop)
      elseif glyph then
        local G = ui.graphics
        local hop = 0
        if active then
          local e = self:v4Enter("settings_tab", i, 0.24)
          if e < 1 then hop = -floor(math.sin(e * math.pi) * 3 + 0.5) end
        end
        G.push(); G.translate(x + floor((step - 2 - 18) / 2), TAB_Y + 2 + hop); G.scale(0.9, 0.9)
        glyph(0, 0, active and WHITE or accent, active and mix(accent, WHITE, 0.5) or mix(accent, colors.surface, 0.45))
        G.pop()
      end
      self:endPress(pressed)
    end
    -- section line + pager
    local accent = accentOf(self, model.accent)
    R(9, 59, 3, 8, accent)
    self:partyInfo(self:fitPartyInfo(translate(model.label or ""), 140), 15, 56, colors.ink)
    if model.pages > 1 then
      local cx = 176
      self:v4Window(cx, 56, 57, 13, { fill = colors.bandLight, shadow = false })
      local p = self:beginPress(cx, 55, 20, 14); ART({ "..#", ".##", "###", ".##", "..#" }, cx + 6, 60, { ["#"] = colors.ink }); self:endPress(p)
      local n = self:beginPress(cx + 37, 55, 20, 14); ART({ "#..", "##.", "###", "##.", "#.." }, cx + 48, 60, { ["#"] = colors.ink }); self:endPress(n)
      self:partyInfo(model.page .. "/" .. model.pages, cx + 18, 56, colors.green, 21, "center")
    end
    -- rows
    local first = (model.page - 1) * 4 + 1
    local selectedRow
    -- switching category cascades the rows in from the right
    local enter = self:v4Enter("settings_rows", tostring(model.tab) .. ":" .. tostring(model.page), 0.26)
    local G = ui.graphics
    for visible = 0, 3 do
      local index = first + visible
      local row = model.rows[index]
      local _, dx = self:v4Stagger(enter, visible + 1, 0.09, 18)
      if row and dx ~= 0 then G.push(); G.translate(dx, 0) end
      if row then
        local y = ROW_Y + visible * ROW_STEP
        local enabled = row.enabled ~= false
        local selected = model.selected ~= nil and rowKey(row) == model.selected
        if selected then selectedRow = row end
        local pressed = self:beginPress(7, y, 226, ROW_H, enabled and not selected)
        self:v4Window(7, y, 226, ROW_H, { radius = 3, shadow = false,
          fill = selected and mix(colors.surface, accent, self.dark and 0.2 or 0.12) or nil })
        if selected then R(8, y + 3, 2, ROW_H - 6, accent) end
        self:endPress(pressed)
        self:partyInfo(self:fitPartyInfo(translate(row.label), 96), 13, y + 5,
          enabled and colors.ink or colors.disabledInk)
        local live = enabled and selected
        if row.action then
          local warn = model.confirm == row.action
          local a = K.rampOf(not live and colors.silverDark or warn and hex("e04838") or accent)
          local bp = self:beginPress(CTRL_X, y + 3, CTRL_W, 16, live)
          local off = self:v4Button(CTRL_X, y + 3, CTRL_W, 16, a, { radius = 4, lip = 3, chamfer = 3 })
          self:partyType(self:fitPartyType(translate(row.value), CTRL_W - 8), CTRL_X + 4, y + 4 + off, WHITE, CTRL_W - 8)
          self:endPress(bp)
        elseif segmentFits(self, row) then
          local action, touched = self:v4SettingsTabbedHit(
            (self.touchX or -1) * 1.5, (self.touchY or -1) * 1.5, model)
          local sp = self:beginPress(CTRL_X, y + 2, CTRL_W, 17,
            live and action == "set" and touched == index)
          self:v4Segments(CTRL_X, y + 2, CTRL_W, row.choices, row.raw, live, accent)
          self:endPress(sp)
        else
          local well = live and mix(colors.surface, accent, self.dark and 0.22 or 0.12) or colors.bandLight
          if cg(self) then CH(CTRL_X, y + 2, CTRL_W, 17, 3, colors.outline); CH(CTRL_X + 1, y + 3, CTRL_W - 2, 15, 2, well)
          else RR(CTRL_X, y + 2, CTRL_W, 17, 4, colors.outline); RR(CTRL_X + 1, y + 3, CTRL_W - 2, 15, 3, well) end
          local ink = live and colors.ink or colors.mutedInk
          local arrows = live and accent or colors.disabledInk
          local lp = self:beginPress(CTRL_X, y + 2, 18, 17, live)
          ART({ "..#", ".##", "###", ".##", "..#" }, CTRL_X + 6, y + 8, { ["#"] = arrows }); self:endPress(lp)
          local rp = self:beginPress(CTRL_X + CTRL_W - 18, y + 2, 18, 17, live)
          ART({ "#..", "##.", "###", "##.", "#.." }, CTRL_X + CTRL_W - 9, y + 8, { ["#"] = arrows }); self:endPress(rp)
          local mp = self:beginPress(CTRL_X + 18, y + 2, CTRL_W - 36, 17, live)
          self:partyInfo(self:fitPartyInfo(translate(row.value or ""), CTRL_W - 40), CTRL_X + 18, y + 5, ink, CTRL_W - 36, "center")
          self:endPress(mp)
        end
      end
      if row and dx ~= 0 then G.pop() end
    end
    -- help panel: it rises to meet the last row, so a short category
    -- (Exploration, Controls, System) gets a full explainer, not a gap
    local shownRows = 0
    for visible = 0, 3 do if model.rows[first + visible] then shownRows = visible + 1 end end
    local helpY = shownRows < 4 and ROW_Y + shownRows * ROW_STEP + 4 or 168
    local helpH = 212 - helpY
    self:v4MessageWindow(6, helpY, 228, helpH)
    local text, key
    if selectedRow then
      text = translate(selectedRow.info or selectedRow.description or "")
      key = tostring(rowKey(selectedRow)) .. ":" .. tostring(selectedRow.raw) .. ":" .. tostring(model.confirm)
    else
      text = translate(model.detail or "")
      local only = shownRows == 1 and model.rows[first]
      local about = only and (only.info or only.description)
      if helpH >= 70 and about and about ~= "" then
        -- a one-setting category explains that setting straight away
        text = text .. "\n" .. translate(about)
      elseif helpH >= 70 then
        text = text .. "\n" .. translate("TAP A SETTING TO SEE WHAT IT DOES.")
      end
      key = "cat:" .. tostring(model.tab)
    end
    typewriter(self, text, key, 6, helpY, 228, helpH, max(3, floor((helpH - 10) / 11)))
  end

  function H:v4SettingsTabbedHit(x, y, model)
    if y < 29 and x < 27 then return "back" end
    if y >= TAB_Y and y < TAB_Y + TAB_H then
      local step, left = tabStep(#model.tabs), tabLeft(#model.tabs)
      local i = floor((x - left) / step) + 1
      if x >= left and i >= 1 and i <= #model.tabs and x < left + i * step - 2 and i ~= model.tab then return "tab", i end
      return nil
    end
    if model.pages > 1 and y >= 55 and y < 69 then
      if x >= 176 and x < 196 then return "prev" end
      if x >= 213 and x < 233 then return "next" end
      return nil
    end
    local first = (model.page - 1) * 4 + 1
    for visible = 0, 3 do
      local index = first + visible
      local row = model.rows[index]
      local ry = ROW_Y + visible * ROW_STEP
      if row and x >= 7 and x < 233 and y >= ry and y < ry + ROW_H then
        if row.enabled == false then return nil end
        local selected = model.selected ~= nil and rowKey(row) == model.selected
        if not selected then return "select", index end
        if x < CTRL_X or x >= CTRL_X + CTRL_W then return nil end
        if row.action then return "action", index end
        if segmentFits(self, row) then
          local segW = floor(CTRL_W / #row.choices)
          local j = math.min(#row.choices, floor((x - CTRL_X) / segW) + 1)
          if row.choices[j][2] == row.raw then return nil end
          return "set", index, j
        end
        if x < CTRL_X + 18 then return "cycle", index, -1 end
        if x >= CTRL_X + CTRL_W - 18 then return "cycle", index, 1 end
        return "more", index
      end
    end
    return nil
  end

  function H:settingsHit(x, y, model)
    if model and model.tabs and not model.option then return self:v4SettingsTabbedHit(x, y, model) end
    if not (model and model.option) then return base.settingsHit(self, x, y, model) end
    if y < 29 and x < 27 then return "back" end
    if model.pages > 1 and y >= 133 and y < 148 then
      if x >= 72 and x < 104 then return "prev" end
      if x >= 136 and x < 168 then return "next" end
    end
    local top = self:settingsChoiceTop(model)
    local perPage = model.perPage or 4
    local visible = floor((y - top) / 25)
    local index = (model.page - 1) * perPage + visible + 1
    if x >= 7 and x < 233 and visible >= 0 and visible < perPage and y >= top
        and y < top + 22 + visible * 25 and model.choices[index] then return "choice", index end
  end
end
