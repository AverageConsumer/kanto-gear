-- Kanto Gear v4: native-menu companions (start menu, choices, keyboard, level up).
return function(H, ui, K)
  local floor, max, min = math.floor, math.max, math.min
  local R, RR, RRrows, CH, CHrows, CIRC, ART = K.R, K.RR, K.RRrows, K.CH, K.CHrows, K.CIRC, K.ART
  local mix, hex = K.mix, K.hex
  local cg, WHITE = K.cg, K.WHITE
  local translate = function(value) return ui.translate and ui.translate(value) or value end

  -- Gen 4 keycap: light cap, darker lip, pressed state drops the lip.
  function H:v4Key(x, y, w, h, opts)
    opts = opts or {}
    local colors = self.colors
    local cap = opts.cap or (self.dark and hex("4a5568") or hex("f4f6f0"))
    local lip = opts.lip or (self.dark and hex("2a3242") or hex("b8c4bc"))
    local hi = opts.hi or (self.dark and hex("5e6a80") or WHITE)
    local depth = h >= 18 and 3 or 2
    if cg(self) then
      local k = min(4, floor(h / 4))
      CH(x, y, w, h, k, colors.outline)
      CH(x + 1, y + 1, w - 2, h - 2, max(0, k - 1), lip)
      CH(x + 1, y + 1, w - 2, h - 2 - depth, max(0, k - 1), cap)
      R(x + 3, y + 1, w - 6, 1, hi)
      return
    end
    RR(x, y, w, h, 3, colors.outline)
    RR(x + 1, y + 1, w - 2, h - 2, 2, lip)
    RR(x + 1, y + 1, w - 2, h - 2 - depth, 2, cap)
    R(x + 3, y + 1, w - 6, 1, hi)
  end

  function H:button(x, y, w, h, label, selected, pressScale, pressOffset)
    local pressed = self:beginPress(x, y, w, h, true, pressScale, pressOffset)
    self:v4Key(x, y, w, h)
    local shown = ui.fit(label, floor((w - 8) / 6))
    self:partyInfoCentered(shown, x, y - 1, w, h - 2, self.colors.ink)
    if selected then self:focusFrame(x, y, w, h) end
    self:endPress(pressed)
  end

  ---------------------------------------------------------------------------
  -- Keyboard
  ---------------------------------------------------------------------------
  function H:naming(model)
    local colors = self.colors
    -- name field: a Gen 4 entry box with blinking cursor underscores
    self:v4MessageWindow(7, 34, 226, 29)
    local name = model.name or "-"
    local shown = self:fitPartyInfo(name, 190)
    local w = self:partyInfoWidth(shown)
    local nx = 120 - floor(w / 2)
    self:partyName(shown, nx, 40, colors.ink, 200)
    if floor(self:clock() / 0.5) % 2 == 0 then
      R(nx + w + 2, 51, 6, 2, self.tok.acc.M)
    end
    self:wantAmbient(0.5)
    for _, entry in ipairs(model.entries or {}) do
      local x, y, w2, h = entry.x, entry.y, entry.w, entry.h
      local pressed = self:beginPress(x, y, w2, h, not entry.disabled)
      local opts
      if entry.action == "confirm" then
        local r = K.rampOf(cg(self) and hex("1ea5d8") or hex("3ea04c"))
        opts = { cap = r.M, lip = r.D, hi = r.L }
      elseif entry.action == "delete" then
        local r = K.rampOf(hex("e09a20"))
        opts = { cap = r.M, lip = r.D, hi = r.L }
      elseif entry.action then
        local r = K.rampOf(hex("5a6c88"))
        opts = { cap = r.M, lip = r.D, hi = r.L }
      end
      if entry.disabled then
        opts = { cap = colors.bandLight, lip = colors.band, hi = colors.bandLight }
      end
      self:v4Key(x, y, w2, h, opts)
      local label = entry.action and translate(entry.label) or tostring(entry.label or "")
      local ink = entry.disabled and colors.disabledInk or (entry.action and WHITE or colors.ink)
      self:partyInfoCentered(self:fitPartyInfo(label, w2 - 6), x, y - 1, w2, h - 2, ink)
      if self.nativeFocus and entry.selected then self:focusFrame(x, y, w2, h) end
      self:endPress(pressed)
    end
  end

  ---------------------------------------------------------------------------
  -- Choices and start menu
  ---------------------------------------------------------------------------
  function H:choiceScreen(model)
    local colors = self.colors
    if #(model.prompt or {}) > 0 then
      self:v4MessageWindow(7, 34, 226, 46)
      local lines = model.nudge and { translate("PAUSE THEN CHOOSE") } or model.prompt
      local firstY = 33 + floor((46 - (9 + (#lines - 1) * 11)) / 2)
      for index, line in ipairs(lines) do
        self:partyInfo(self:fitPartyInfo(line, 200), 15, firstY + (index - 1) * 11,
          model.nudge and colors.amber or colors.ink, 210, "center")
      end
    end
    for _, entry in ipairs(model.entries or {}) do
      local x, y, w, h = entry.x, entry.y, entry.w, entry.h
      local pressed = self:beginPress(x, y, w, h)
      local focused = self.nativeFocus and entry.selected
      self:v4Window(x, y, w, h, { radius = 4 })
      R(x + 1, y + 4, 2, h - 8, focused and colors.selected or self.tok.acc.M)
      if focused then
        local b = floor(self:clock() / 0.3) % 2
        self:wantAmbient(0.3)
        ART(K.CHEV_R, x + 8 + b, y + floor((h - 5) / 2), { ["#"] = colors.selected })
      end
      self:partyInfo(self:fitPartyInfo(entry.label, w - 32), x + 16, y + floor((h - 9) / 2) - 1,
        colors.ink, w - 32, "center")
      if focused then self:focusFrame(x, y, w, h) end
      self:endPress(pressed)
    end
    if model.pages and model.pages > 1 then self:menuPager(model) end
  end

  function H:menuPager(model)
    local c = self.colors
    local controls = {
      { x = 7, up = true, enabled = model.first > 1 },
      { x = 177, enabled = model.last < model.total },
    }
    for _, control in ipairs(controls) do
      local pressed = control.enabled and self:beginPress(control.x, 190, 56, 23)
      self:v4Key(control.x, 190, 56, 23, not control.enabled and
        { cap = c.bandLight, lip = c.band, hi = c.bandLight } or nil)
      local tint = control.enabled and self.tok.acc.M or c.disabledInk
      for line = 0, 3 do
        local width = 1 + line * 2
        R(control.x + 28 - floor(width / 2), 198 + (control.up and line or 3 - line), width, 1, tint)
      end
      self:endPress(pressed)
    end
    self:partyInfo(model.first .. "-" .. model.last .. " / " .. model.total, 68, 196, c.ink, 104, "center")
  end

  function H:startMenu(model)
    local c = self.colors
    for _, entry in ipairs(model.entries) do
      local x, y, w, h = entry.x, entry.y, entry.w, entry.h
      local pressed = self:beginPress(x, y, w, h, not entry.disabled)
      local focused = self.nativeFocus and entry.selected
      local target = entry.targetSide and (entry.targetSide == "player" and c.blue or c.red)
      self:v4Window(x, y, w, h, { radius = 4, fill = entry.disabled and c.bandLight or c.surface })
      R(x + 1, y + 4, 2, h - 8, target or (focused and c.selected or self.tok.acc.M))
      -- icon seat
      local d = min(h - 6, 24)
      local sx, sy = x + 6, y + floor((h - d) / 2)
      CIRC(sx, sy, d, c.outline)
      CIRC(sx + 1, sy + 1, d - 2, mix(c.surface, self.tok.acc.L, self.dark and 0.3 or 0.25))
      if entry.itemSprite then
        self:battleItemIcon(entry, sx + floor((d - 17) / 2), sy + floor((d - 17) / 2), c.amberLight)
      else
        self:startMenuIcon(entry.kind, sx + floor((d - 15) / 2), sy + floor((d - 15) / 2))
      end
      local reserved = target and 94 or entry.right and 78 or 0
      self:partyInfoCentered(self:fitPartyInfo(entry.label, w - 52 - reserved), x + 40,
        y, w - 52 - reserved, h, entry.disabled and c.mutedInk or c.ink)
      if target then
        local bx, by, bw, bh = x + w - 94, y + 5, 86, h - 10
        local fill = mix(c.surface, target, self.dark and 0.32 or 0.2)
        if cg(self) then CH(bx, by, bw, bh, 3, target); CH(bx + 1, by + 1, bw - 2, bh - 2, 2, fill)
        else RR(bx, by, bw, bh, 3, target); RR(bx + 1, by + 1, bw - 2, bh - 2, 2, fill) end
        self:partyInfoCentered(self:fitPartyInfo(translate(entry.right), bw - 8), bx, by, bw, bh, c.ink)
      elseif entry.right then
        self:partyInfoCentered(self:fitPartyInfo(entry.right, 72), x + w - 80, y, 72, h, c.ink)
      end
      if focused then self:focusFrame(x, y, w, h) end
      self:endPress(pressed)
    end
    if not model.fixedLayout and model.total > (model.visible or 5) then self:menuPager(model) end
  end

  ---------------------------------------------------------------------------
  -- Level up: stat gains as tiles with +N pills
  ---------------------------------------------------------------------------
  function H:levelUp(model)
    local colors = self.colors
    local accent = self:typeColor(model.type)
    self:v4Window(6, 33, 228, 44)
    R(8, 35, 224, 2, accent)
    self:v4Seat(12, 37, 37)
    if model.drawPokemon then model.drawPokemon(14, 39, 34) end
    self:partyName(model.name or translate("POKEMON"), 56, 38, colors.ink, 120)
    -- level badge with sparkle
    local level = model.level or "L--"
    local lw = self:partyInfoWidth(level) + 12
    local lx = 226 - lw
    if cg(self) then CH(lx, 56, lw, 15, 3, self.tok.acc.M)
    else RR(lx, 56, lw, 15, 4, colors.outline); RR(lx + 1, 57, lw - 2, 13, 3, hex("e09a20")); R(lx + 3, 57, lw - 6, 1, hex("f8d878")) end
    self:partyInfo(level, lx + 6, 57, WHITE)
    self:partyType(translate("NEW LEVEL"), 56, 56, colors.green, 72)
    local t = self:clock() % 1.6
    if t < 0.3 and self.motionEnabled ~= false then
      local sx, sy = lx + lw - 3, 54
      R(sx, sy - 2, 1, 5, WHITE); R(sx - 2, sy, 5, 1, WHITE)
    end
    self:wantAmbient(0.3)
    local rows = model.rows or {}
    for index, row in ipairs(rows) do
      local line = floor((index - 1) / 3)
      local columns = min(3, #rows - line * 3)
      local width, gap = 70, 5
      local group = columns * width + (columns - 1) * gap
      local column = (index - 1) % 3
      local x = floor((240 - group) / 2) + column * (width + gap)
      local y = 84 + line * 39
      self:v4Window(x, y, width, 34, { radius = 3 })
      self:partyType(self:fitPartyType(translate(row.label), width - 8), x + 4, y + 1, colors.mutedInk, width - 8)
      local value = row.value == nil and "--" or tostring(row.value)
      local delta = row.delta ~= nil and string.format("%+d", row.delta) or nil
      local vw = self:partyInfoWidth(value)
      local dw = delta and self:partyInfoWidth(delta) + 6 or 0
      local gap2 = delta and 4 or 0
      local left = x + floor((width - vw - gap2 - dw) / 2)
      self:partyInfo(value, left, y + 16, colors.ink)
      if delta then
        local up = row.delta > 0
        local fill = up and colors.hp or colors.silverDark
        local px = left + vw + gap2
        RR(px, y + 17, dw, 11, 3, mix(fill, { 0, 0, 0, 1 }, 0.4))
        RR(px + 1, y + 18, dw - 2, 9, 2, fill)
        self:partyInfo(delta, px + 3, y + 16, WHITE)
      end
    end
    local pressed = self:beginPress(42, 170, 156, 34, model.enabled ~= false)
    local a = K.rampOf(model.enabled == false and colors.silverDark or (cg(self) and hex("1ea5d8") or hex("3ea04c")))
    local off = self:v4Button(42, 170, 156, 34, a, { radius = 6, lip = 4, chamfer = 6 })
    self:partyInfoCentered(translate("CONTINUE"), 50, 168 + off, 140, 34, WHITE)
    self:endPress(pressed)
  end

  ---------------------------------------------------------------------------
  -- Overlays, prompts and the boot screen
  ---------------------------------------------------------------------------
  function H:systemOverlay(alpha, prompt, now)
    if ui.dimBackground then ui.dimBackground(alpha or 0.5) end
    K.setc({ 0, 0, 0, alpha or 0.5 })
    ui.graphics.rectangle("fill", 0, 0, 240, 216)
    if prompt then self:v4AdvanceArrow(116, 180) end
  end

  function H:loadingOverlay(label, now)
    local colors = self.colors
    self:systemOverlay(0.58, false)
    self:v4MessageWindow(45, 72, 150, 72)
    self:partyInfo(translate(label or "LOADING AREA"), 55, 88, colors.ink, 130, "center")
    local t = self.motionEnabled == false and 0 or (tonumber(now) or self:clock())
    for index = 0, 2 do
      local hop = self.motionEnabled == false and 0
        or math.max(0, math.floor(math.sin((t * 6) - index * 0.9) * 4 + 0.5))
      self:v4MiniBall(106 + index * 11, 118 - hop, "ok")
    end
    self:wantAmbient(0.2, 1 / 15)
  end

  function H:toolPrompt(action)
    local colors = self.colors
    self:systemOverlay(self.dark and 0.62 or 0.48, false)
    local accent = self:toolAccent(action.icon)
    self:v4MessageWindow(25, 52, 190, 112)
    CIRC(37, 66, 44, colors.outline)
    CIRC(38, 67, 42, mix(colors.surface, accent, self.dark and 0.3 or 0.2))
    K.CIRCrows(38, 67, 42, 21, 42, mix(colors.surface, accent, self.dark and 0.42 or 0.32))
    self:toolIcon(action.icon, 45, 76, accent)
    self:partyInfo(self:fitPartyInfo(action.label, 116), 86, 72, colors.ink, 116, "center")
    self:partyType(translate(action.prompt or "USE NOW?"), 86, 94, colors.green, 116)
    for index, option in ipairs({ "YES", "NO" }) do
      local x = index == 1 and 39 or 126
      local pressed = self:beginPress(x, 124, 75, 27)
      local a = index == 1 and K.rampOf(cg(self) and hex("1ea5d8") or hex("3ea04c")) or K.rampOf(hex("5a6c88"))
      local off = self:v4Button(x, 124, 75, 27, a, { radius = 5, lip = 4, chamfer = 5 })
      self:partyInfo(translate(option), x + 4, 128 + off, WHITE, 67, "center")
      self:endPress(pressed)
    end
  end

  function H:rodPicker(rods)
    local colors = self.colors
    local blue = hex("3878d0")
    for index, rod in ipairs(rods or {}) do
      local y = 38 + (index - 1) * 54
      local pressed = self:beginPress(16, y, 208, 44)
      self:v4Window(16, y, 208, 44, { radius = 5 })
      R(17, y + 4, 2, 36, blue)
      CIRC(23, y + 5, 34, colors.outline)
      CIRC(24, y + 6, 32, mix(colors.surface, blue, self.dark and 0.3 or 0.18))
      K.CIRCrows(24, y + 6, 32, 16, 32, mix(colors.surface, blue, self.dark and 0.42 or 0.28))
      self:toolIcon("fish", 27, y + 9, colors.blueLight)
      self:partyInfo(self:fitPartyInfo(rod.label, 132), 65, y + 8, colors.ink, 132, "center")
      self:partyType(translate("TAP TO USE"), 65, y + 26, colors.green, 132)
      self:detailChevron(211, y + 18, colors.mutedInk, true)
      self:endPress(pressed)
    end
  end

  -- Pixel Silph Link emblem: Poké Ball seat inside a tri-colour link ring.
  local ringCache = {}
  local function ringRuns(d, t)
    local key = d .. ":" .. t
    if ringCache[key] then return ringCache[key] end
    local runs, r = {}, d / 2
    for y = 0, d - 1 do
      local current, start
      for x = 0, d do
        local idx
        if x < d then
          local dx, dy = x + 0.5 - r, y + 0.5 - r
          local dist = math.sqrt(dx * dx + dy * dy)
          if dist <= r and dist >= r - t then
            local a = math.atan2(dy, dx)
            idx = (a >= -math.pi / 3 and a < math.pi / 3) and 2 or (a >= math.pi / 3 and a < math.pi) and 3 or 1
          end
        end
        if idx ~= current then
          if current then runs[#runs + 1] = { current, start, y, x - start } end
          current, start = idx, x
        end
      end
    end
    ringCache[key] = runs
    return runs
  end
  function H:silphLinkIcon(cx, cy, phase)
    local colors = self.colors
    local d = 74
    local runs = ringRuns(d, 3)
    local tints = { colors.blueLight, colors.greenLight, colors.amberLight }
    for _, run in ipairs(runs) do R(cx - d / 2 + run[2], cy - d / 2 + run[3], run[4], 1, tints[run[1]]) end
    self:v4Seat(cx - 27, cy - 27, 55)
    for index, node in ipairs({ { -36, 0 }, { 18, -31 }, { 18, 31 } }) do
      local active = index - 1 == (phase or 0)
      CIRC(cx + node[1] - 5, cy + node[2] - 5, 11, colors.outline)
      CIRC(cx + node[1] - 3, cy + node[2] - 3, 7, active and colors.amberLight or colors.greenLight)
    end
  end

  function H:titleBoot(model, now)
    local colors = self.colors
    local phase = self.motionEnabled == false and 0 or floor((tonumber(now) or 0) * 2) % 3
    self:v4Window(10, 9, 220, 153)
    local tints = { hex("e04838"), hex("3878d0"), hex("3ea04c") }
    for i, c in ipairs(tints) do R(15 + (i - 1) * 70, 13, 70, 3, c) end
    self:partyType(translate("SILPH CO."), 15, 20, colors.green, 105)
    self:partyType("KANTO GEAR 4.0", 120, 20, colors.ink, 105)
    self:silphLinkIcon(120, 70, phase)
    local G = ui.graphics
    local font = ui.largeFont
    local title = translate("SILPH LINK")
    if font and (not font.hasGlyphs or font:hasGlyphs(title)) and font:getWidth(title) <= 200 then
      local prev = G.getFont()
      G.setFont(font)
      K.setc(colors.ink)
      G.print(title, 120 - floor(font:getWidth(title) / 2), 97)
      if prev then G.setFont(prev) end
    else
      self:label(title, 28, 109, colors.ink, 184, "center")
    end
    self:partyInfo(self:fitPartyInfo(model.systemId or "SLS-DEV", 102), 69, 124, colors.mutedInk, 102, "center")
    local status = self:fitPartyType(translate("LINK ONLINE"), 104)
    local sw = self:partyInfoWidth(status)
    local left = 120 - floor((sw + 14) / 2)
    if cg(self) then CH(left - 6, 141, sw + 26, 15, 3, self.tok.border); CH(left - 5, 142, sw + 24, 13, 2, colors.bandLight)
    else RR(left - 6, 141, sw + 26, 15, 4, colors.outline); RR(left - 5, 142, sw + 24, 13, 3, colors.bandLight) end
    local on = floor(self:clock() / 0.5) % 2 == 0
    self:wantAmbient(0.5)
    CIRC(left, 145, 7, colors.outline); CIRC(left + 1, 146, 5, on and colors.hp or colors.silverDark)
    self:partyType(status, left + 12, 143, colors.green, sw)
    local pressed = self:beginPress(0, 0, 240, 216)
    local a = K.rampOf(cg(self) and hex("1ea5d8") or hex("3ea04c"))
    local off = self:v4Button(26, 171, 188, 36, a, { radius = 7, lip = 5, chamfer = 7 })
    self:label(translate("START GAME"), 40, 178 + off, WHITE, 160, "center")
    self:detailChevron(195, 182 + off, WHITE, true)
    self:endPress(pressed)
  end

  -- Secondary action surface used by feature modules (Silph Connect, Stamps).
  function H:v4ActionPanel(x, y, w, h, enabled)
    local c = self.colors
    self:v4Key(x, y, w, h, enabled == false and { cap = c.bandLight, lip = c.band, hi = c.bandLight } or nil)
  end

  function H:enemyInfoHero(model, height)
    local colors = self.colors
    local mon = model.pokemon or {}
    height = height or 66
    local accent = self:typeColor(mon.types and mon.types[1] or mon.type)
    self:v4SummaryWindow(7, 34, 226, height, accent)
    local d = 52
    self:v4Seat(15, 34 + floor((height - d) / 2), d)
    if model.drawPokemon then
      model.drawPokemon(mon, 16, 34 + floor((height - 50) / 2), 50, false)
    end
    self:partyName(self:fitPartyInfo(mon.name or translate("POKEMON"), 104), 73, 40, colors.ink, 104)
    self:partyInfo(mon.levelText or "L--", 181, 40, colors.ink, 38, "right")
    self:typeBadges(mon, 73, 57, false)
    if mon.caught then
      self:v4MiniBall(214, 57, "ok")
    else
      self:partyType(translate("NOT CAUGHT"), 153, 58, colors.red, 70)
    end
  end
end
