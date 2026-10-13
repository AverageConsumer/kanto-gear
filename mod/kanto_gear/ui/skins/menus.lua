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
      self:v4Caps(function()
        for index, line in ipairs(lines) do
          self:partyInfo(self:fitPartyInfo(line, 200), 15, firstY + (index - 1) * 11,
            model.nudge and colors.amber or colors.ink, 210, "center")
        end
      end)
    end
    for _, entry in ipairs(model.entries or {}) do
      local x, y, w, h = entry.x, entry.y, entry.w, entry.h
      local pressed = self:beginPress(x, y, w, h)
      local focused = self.nativeFocus and entry.selected
      self:v4Window(x, y, w, h, { radius = 4 })
      if focused then R(x + 1, y + 4, 2, h - 8, colors.selected) end
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
    -- the same lit pager keys as every other list, pointing up and down
    for _, control in ipairs(controls) do
      local pressed = control.enabled and self:beginPress(control.x, 190, 56, 23)
      local ramp = K.rampOf(control.enabled and (cg(self) and self.tok.acc.M or c.green) or c.silverDark)
      self:v4Button(control.x, 190, 56, 23, ramp, { radius = 5, lip = 3, chamfer = 4 })
      local tint = control.enabled and WHITE or c.band
      for line = 0, 3 do
        local width = 1 + line * 2
        R(control.x + 28 - floor(width / 2), 197 + (control.up and line or 3 - line), width, 1, tint)
      end
      if pressed then self:endPress(pressed) end
    end
    self:partyInfoCentered(model.first .. "-" .. model.last .. " / " .. model.total, 63, 190, 114, 20, c.ink)
  end

  function H:startMenu(model)
    local c = self.colors
    for _, entry in ipairs(model.entries) do
      local x, y, w, h = entry.x, entry.y, entry.w, entry.h
      local pressed = self:beginPress(x, y, w, h, not entry.disabled)
      local focused = self.nativeFocus and entry.selected
      local target = entry.targetSide and (entry.targetSide == "player" and c.blue or c.red)
      self:v4Window(x, y, w, h, { radius = 4, fill = entry.disabled and c.bandLight or c.surface })
      if target or focused then R(x + 1, y + 4, 2, h - 8, target or c.selected) end
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
    -- The Silph emblem is the spinner: its three link nodes light in turn
    -- while the track runs underneath, like the boot screen in miniature.
    local colors = self.colors
    self:systemOverlay(0.58, false)
    self:v4MessageWindow(40, 58, 160, 96)
    local tt = self.motionEnabled == false and 0 or (tonumber(now) or self:clock())
    local active = self.motionEnabled == false and 0 or floor(tt / 0.3) % 3
    self:silphEmblem(120, 92, 44, { active = active })
    self:partyInfo(translate(label or "LOADING AREA"), 50, 119, colors.ink, 140, "center")
    -- indeterminate progress track
    local hot = cg(self) and self.tok.acc.M or colors.green
    R(70, 135, 100, 4, colors.outline); R(71, 136, 98, 2, colors.bandLight)
    local sx = 71 + floor(((tt / 1.2) % 1) * 128) - 30
    local l, r = math.max(71, sx), math.min(169, sx + 30)
    if r > l then R(l, 136, r - l, 2, hot) end
    self:wantAmbient(0.2, 1 / 15)
  end

  -- Prompts pop in: the dim fades up while the window grows from 90% with a
  -- small overshoot. Touch targets stay where the settled window draws them.
  local promptBody
  function H:toolPrompt(action)
    local p = self:v4Enter("tool_prompt", tostring(action.label) .. ":" .. tostring(action.prompt), 0.2)
    self:systemOverlay((self.dark and 0.62 or 0.48) * min(1, p * 2), false)
    if p >= 1 then return promptBody(self, action) end
    local G = ui.graphics
    local k = 0.9 + 0.1 * K.easeBack(p)
    G.push(); G.translate(120, 108); G.scale(k, k); G.translate(-120, -108)
    promptBody(self, action)
    G.pop()
  end
  function promptBody(self, action)
    local colors = self.colors
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

  local ROD_TIER = { OLD_ROD = { "a07040", 1 }, GOOD_ROD = { "3878d0", 2 }, SUPER_ROD = { "e04838", 3 } }
  local STAR = { "..#..", ".###.", "#####", ".###.", ".#.#." }
  function H:rodPicker(rods)
    local colors = self.colors
    local G = ui.graphics
    local enter = self:v4Enter("rod_picker", #(rods or {}), 0.24)
    for index, rod in ipairs(rods or {}) do
      -- a lit card is the action: name and pull strength, nothing to read twice
      local y = 40 + (index - 1) * 58
      local tier = ROD_TIER[tostring(rod.id)] or { "3878d0", index }
      local tint = hex(tier[1])
      local _, dx = self:v4Stagger(enter, index, 0.1, 16, #rods)
      if dx ~= 0 then G.push(); G.translate(dx, 0) end
      local pressed = self:beginPress(12, y, 216, 52)
      self:v4Window(12, y, 216, 52, { radius = 5 })
      R(13, y + 5, 3, 42, tint)
      CIRC(21, y + 6, 40, colors.outline)
      CIRC(22, y + 7, 38, mix(colors.surface, tint, self.dark and 0.3 or 0.18))
      K.CIRCrows(22, y + 7, 38, 19, 38, mix(colors.surface, tint, self.dark and 0.42 or 0.28))
      self:toolIcon("fish", 29, y + 14, mix(tint, WHITE, 0.25))
      self:partyName(self:fitPartyInfo(rod.label, 120), 70, y + 11, colors.ink, 120)
      for st = 1, 3 do
        ART(STAR, 70 + (st - 1) * 9, y + 31, { ["#"] = st <= tier[2] and hex("f8c838") or colors.band })
      end
      local b = (self.motionEnabled ~= false and floor(self:clock() / 0.4) % 2 == 0) and 1 or 0
      self:wantAmbient(0.4)
      ART(K.CHEV_R, 212 + b, y + 23, { ["#"] = tint })
      self:endPress(pressed)
      if dx ~= 0 then G.pop() end
    end
  end

  function H:rodHit(x, y, rods)
    for index = 1, #(rods or {}) do
      local top = 40 + (index - 1) * 58
      if x >= 12 and x < 228 and y >= top - 3 and y < top + 55 then return index end
    end
  end

  ---------------------------------------------------------------------------
  -- Silph Link identity: the emblem is three link arcs (Silph red, blue,
  -- green) around an "S" core. Pokégear draws a round ring, C-Gear a
  -- hexagon. Pixels are cached once per shape and drawn as runs when idle.
  ---------------------------------------------------------------------------
  local SILPH = { hex("e04838"), hex("3878d0"), hex("3ea04c") }
  local SILPH_CG = { hex("f0604c"), hex("1ea5d8"), hex("3cc07c") }
  local GAP = 0.075
  local emblemCache = {}
  local function emblemPixels(d, t, hexShape)
    local key = d .. ":" .. t .. ":" .. tostring(hexShape)
    if emblemCache[key] then return emblemCache[key] end
    local r = d / 2
    -- A flat-topped hexagon is wider than its height. Include both tips and
    -- retain a final sentinel column so the cached pixel runs close fully.
    local pad = hexShape and math.ceil(r / 0.866 - r) or 0
    local px, runs = { {}, {}, {} }, { {}, {}, {} }
    for y = 0, d - 1 do
      local open = {}
      for x = -pad, d + pad do
        local seg, kind, u
        if x < d + pad then
          local dx, dy = x + 0.5 - r, y + 0.5 - r
          local dist = hexShape and math.max(math.abs(dx) * 0.866 + math.abs(dy) * 0.5, math.abs(dy))
            or math.sqrt(dx * dx + dy * dy)
          if dist <= r and dist >= r - t - 2 then
            local f = (math.atan2(dx, -dy) / (2 * math.pi)) % 1
            local s = floor(f * 3)
            u = f * 3 - s
            if u >= GAP and u <= 1 - GAP then
              seg = s + 1
              local edge = dist > r - 1 or dist < r - t - 1
                or u < GAP + 0.025 or u > 1 - GAP - 0.025
              kind = edge and 1 or dist > r - 2.5 and 3 or 2
              local list = px[seg]
              list[#list + 1] = { x, y, kind, (u - GAP) / (1 - 2 * GAP) }
            end
          end
        end
        -- run-length per segment and kind for the settled emblem
        for s2 = 1, 3 do
          local want = seg == s2 and kind or nil
          local o = open[s2]
          if o and o[1] ~= want then
            local list = runs[s2]
            list[#list + 1] = { o[1], o[2], y, x - o[2] }
            open[s2] = nil
          end
          if want and not open[s2] then open[s2] = { want, x } end
        end
      end
    end
    emblemCache[key] = { px = px, runs = runs }
    return emblemCache[key]
  end
  K.emblemPixels = emblemPixels

  -- "S" monogram; the outline is derived so the glyph stays one source.
  local S_GLYPH = (function()
    local fill = {
      ".######.", "##....##", "##......", "##......", ".######.",
      "......##", "......##", "##....##", ".######.",
    }
    local h, w = #fill + 2, #fill[1] + 2
    local function at(x, y)
      local row = fill[y]
      return row ~= nil and x >= 1 and x <= #row and row:sub(x, x) == "#"
    end
    local rows = {}
    for y = 0, h - 1 do
      local line = {}
      for x = 0, w - 1 do
        local ch = "."
        if at(x, y) then ch = "#"
        else
          for dy = -1, 1 do for dx = -1, 1 do
            if at(x + dx, y + dy) then ch = "o" end
          end end
        end
        line[#line + 1] = ch
      end
      rows[#rows + 1] = table.concat(line)
    end
    return rows
  end)()

  local function easeOut(p) p = math.max(0, math.min(1, p)); return 1 - (1 - p) * (1 - p) end

  -- progress: per-arc sweep 0..1 (nil = settled); core: 0..1 pop-in.
  function H:silphEmblem(cx, cy, d, opts)
    opts = opts or {}
    local colors = self.colors
    local hexShape = cg(self)
    local t = 4
    local data = emblemPixels(d, t, hexShape)
    local tints = hexShape and SILPH_CG or SILPH
    local ox, oy = cx - floor(d / 2), cy - floor(d / 2)
    for seg = 1, 3 do
      local c = tints[seg]
      local pal = { colors.outline, c, mix(c, WHITE, 0.42) }
      local p = opts.sweep and opts.sweep[seg] or 1
      if p >= 1 then
        for _, run in ipairs(data.runs[seg]) do R(ox + run[2], oy + run[3], run[4], 1, pal[run[1]]) end
      elseif p > 0 then
        for _, q in ipairs(data.px[seg]) do
          if q[4] <= p then
            local head = q[4] > p - 0.06
            R(ox + q[1], oy + q[2], 1, 1, head and q[3] ~= 1 and WHITE or pal[q[3]])
          end
        end
      end
    end
    -- link nodes sit in the three gaps
    local nodeR = d / 2 - t / 2 - 1
    for k = 0, 2 do
      local shown = not opts.sweep or (opts.sweep[k == 0 and 3 or k] or 0) >= 1
      if shown then
        local a = k / 3 * 2 * math.pi
        local nx, ny = floor(cx + math.sin(a) * nodeR + 0.5), floor(cy - math.cos(a) * nodeR + 0.5)
        local lit = opts.active == k
        if hexShape then
          CH(nx - 4, ny - 4, 9, 9, 3, colors.outline)
          CH(nx - 3, ny - 3, 7, 7, 2, lit and hex("f8d048") or WHITE)
        else
          CIRC(nx - 4, ny - 4, 9, colors.outline)
          CIRC(nx - 3, ny - 3, 7, lit and hex("f8d048") or WHITE)
          R(nx - 1, ny - 2, 2, 1, lit and hex("fff4c0") or colors.silver)
        end
      end
    end
    -- core
    local pop = opts.core == nil and 1 or opts.core
    if pop > 0 then
      local s = pop < 1 and floor((26 + 6 * math.sin(pop * math.pi)) * easeOut(pop) + 0.5) or 26
      s = s - s % 2
      if s >= 4 then
        local x, y = cx - s / 2, cy - s / 2
        if hexShape then
          CH(x, y, s, s, floor(s / 3), colors.outline)
          CH(x + 1, y + 1, s - 2, s - 2, floor(s / 3) - 1, colors.surface)
          K.CHrows(x + 1, y + 1, s - 2, s - 2, floor(s / 3) - 1, floor(s / 2), s - 2, colors.band)
        else
          CIRC(x, y, s, colors.outline)
          CIRC(x + 1, y + 1, s - 2, colors.surface)
          K.CIRCrows(x + 1, y + 1, s - 2, floor(s / 2), s - 2, colors.band)
        end
        if pop >= 1 then
          local ink = hexShape and self.tok.acc.D or colors.ink
          ART(S_GLYPH, cx - 5, cy - 5, { o = colors.surface, ["#"] = ink })
        end
      end
    end
  end

  -- Kept for feature modules that still ask for the old emblem.
  function H:silphLinkIcon(cx, cy, phase)
    self:silphEmblem(cx, cy, 64, { active = phase })
  end

  local function utf8Chars(value)
    local list = {}
    for ch in tostring(value):gmatch("[%z\1-\127\194-\244][\128-\191]*") do list[#list + 1] = ch end
    return list
  end

  -- 4-point twinkle, the classic title-screen glint.
  local function glint(x, y, size, c)
    R(x, y - size, 1, size * 2 + 1, c); R(x - size, y, size * 2 + 1, 1, c)
    R(x - 1, y - 1, 3, 3, c)
  end

  -- Boot timeline (seconds since the title appeared):
  --   0.10-0.85 arcs sweep in one after another, nodes click on
  --   0.80-1.10 core pops, "S" lands
  --   1.05-1.55 wordmark types in letter by letter
  --   1.30+     boot log: real warm-up jobs report OK as they finish
  --   ready     LINK ONLINE + TAP ANYWHERE / A
  local BOOT = { arc = 0.10, arcStep = 0.16, arcLen = 0.42, core = 0.80, coreLen = 0.30,
    word = 1.05, wordLen = 0.50, log = 1.30, logStep = 0.30, settle = 0.35 }

  function H:titleBoot(model, now)
    model = model or {}
    local colors = self.colors
    local G = ui.graphics
    local motion = self.motionEnabled ~= false
    local t
    if self.frozenTime then
      t = self.frozenTime
    else
      now = tonumber(now) or self:clock()
      if not self.v4BootSeen or now - self.v4BootSeen > 1.5 or now < self.v4BootSeen then
        self.v4BootAt = now
      end
      self.v4BootSeen = now
      t = motion and (now - self.v4BootAt) or 99
    end
    local pressed = self:beginPress(0, 0, 240, 216)

    -- Emblem window
    self:v4Window(8, 6, 224, 136)
    local tints = cg(self) and SILPH_CG or SILPH
    for i, c in ipairs(tints) do
      local p = easeOut((t - BOOT.arc - (i - 1) * BOOT.arcStep) / BOOT.arcLen)
      local w = floor(70 * p)
      if w > 0 then R(15 + (i - 1) * 70, 10, w, 3, c) end
    end
    local sweep = {}
    for i = 1, 3 do
      sweep[i] = math.max(0, math.min(1, (t - BOOT.arc - (i - 1) * BOOT.arcStep) / BOOT.arcLen))
    end
    local core = math.max(0, math.min(1, (t - BOOT.core) / BOOT.coreLen))
    local idle = core >= 1 and sweep[3] >= 1
    local active = idle and floor(t / 0.6) % 3 or nil
    self:silphEmblem(120, 50, 64, { sweep = sweep, core = core, active = active })
    -- core flash ring when the "S" lands
    local flash = t - (BOOT.core + BOOT.coreLen)
    if flash >= 0 and flash < 0.25 then
      local d = 30 + floor(flash / 0.25 * 30)
      d = d - d % 2
      K.RING(120 - d / 2, 50 - d / 2, d, 1, WHITE)
    end
    -- signal pulse orbiting the ring once settled
    if idle then
      local nodeR = 64 / 2 - 3
      for k = 0, 2 do
        local f = (t * 0.32 - k * 0.012) % 1
        local a = f * 2 * math.pi
        local x, y = floor(120 + math.sin(a) * nodeR + 0.5), floor(50 - math.cos(a) * nodeR + 0.5)
        R(x - (k == 0 and 1 or 0), y - (k == 0 and 1 or 0), k == 0 and 2 or 1, k == 0 and 2 or 1,
          k == 0 and WHITE or mix(WHITE, colors.silver, 0.5))
      end
    end

    -- Wordmark, typed in letter by letter
    local title = translate("SILPH LINK")
    local font = ui.largeFont
    local wordP = math.max(0, math.min(1, (t - BOOT.word) / BOOT.wordLen))
    local useLarge = font and (not font.hasGlyphs or font:hasGlyphs(title)) and font:getWidth(title) <= 200
    local wordRight = 196
    if useLarge then
      local chars = utf8Chars(title)
      local total = font:getWidth(title)
      local x0 = 120 - floor(total / 2)
      wordRight = x0 + total
      local shown = wordP >= 1 and #chars or floor(wordP * #chars + 0.0001)
      local prev = G.getFont()
      G.setFont(font)
      local x = x0
      for i = 1, shown do
        local ch = chars[i]
        local lift = 0
        if wordP < 1 then
          local born = BOOT.word + (i - 1) / #chars * BOOT.wordLen
          lift = (t - born) < 0.07 and 2 or 0
        end
        K.setc(colors.ink)
        G.print(ch, x, 84 - lift)
        x = x + font:getWidth(ch)
      end
      if prev then G.setFont(prev) end
    elseif wordP > 0 then
      self:label(title, 28, 92, colors.ink, 184, "center")
    end
    -- Glint: once when the wordmark completes, then every few seconds.
    local since = t - (BOOT.word + BOOT.wordLen)
    local cycle = since >= 0 and since % 5.5 or -1
    if cycle >= 0 and cycle < 0.36 then
      local size = cycle < 0.12 and 1 or cycle < 0.24 and 3 or 2
      glint(wordRight + 2, 89, size, WHITE)
      glint(wordRight + 2, 89, math.max(0, size - 2), hex("f8e070"))
    end

    -- Kanto Gear line with version chip
    if t >= BOOT.word + BOOT.wordLen * 0.6 then
      local gear = translate("KANTO GEAR")
      local version = tostring(model.version or "4.0")
      local gw = self:partyInfoWidth(gear)
      local vw = self:partyInfoWidth(version)
      local total = gw + 6 + vw + 8
      local x = 120 - floor(total / 2)
      self:partyInfo(gear, x, 115, colors.mutedInk)
      local chip = cg(self) and self.tok.acc.M or colors.red
      if cg(self) then CH(x + gw + 6, 115, vw + 8, 13, 3, chip)
      else RR(x + gw + 6, 115, vw + 8, 13, 3, chip) end
      self:withoutShadow(self.partyInfo, self, version, x + gw + 10, 115, WHITE)
    end

    -- Boot log in the Gen 4 textbox
    self:v4MessageWindow(6, 148, 228, 62)
    local jobs = model.warm or { { label = "THEME", done = true }, { label = "MAP", done = true },
      { label = "SYSTEM", done = true } }
    local allDone, lastTyped = true, 0
    for index, job in ipairs(jobs) do
      local typedAt = BOOT.log + (index - 1) * BOOT.logStep
      if t < typedAt + 0.12 or not job.done then allDone = false end
      lastTyped = typedAt + 0.12
    end
    local ready = allDone and t >= lastTyped + BOOT.settle
    if not ready then
      if t < BOOT.log and t > 0.2 and floor(t / 0.25) % 2 == 0 then
        R(18, 158, 6, 10, colors.ink)
      end
      for index, job in ipairs(jobs) do
        local typedAt = BOOT.log + (index - 1) * BOOT.logStep
        if t >= typedAt then
          local y = 156 + (index - 1) * 15
          local label = self:fitPartyType(translate(job.label), 110)
          local lw = self:partyInfoWidth(label)
          self:partyInfo(label, 18, y, colors.ink)
          local ok = job.done and t >= typedAt + 0.12
          local okLabel = translate("OK")
          local okW = self:partyInfoWidth(okLabel)
          local right = 218
          for dx = 18 + lw + 4, right - (ok and okW or 18) - 5, 3 do R(dx, y + 9, 1, 1, colors.mutedInk) end
          if ok then
            self:partyInfo(okLabel, right - okW, y, colors.green)
          else
            local spin = floor(t / 0.12) % 3
            for k = 0, 2 do
              R(right - 14 + k * 5, y + 7, 3, 3, k == spin and colors.ink or colors.silverDark)
            end
          end
        end
      end
      self:wantAmbient(0.3, 1 / 20)
    else
      -- LINK ONLINE status line with the system id on the right
      local status = self:fitPartyType(translate("LINK ONLINE"), 104)
      local on = floor(t / 0.5) % 2 == 0
      CIRC(18, 160, 9, colors.outline)
      CIRC(19, 161, 7, on and colors.hp or colors.silverDark)
      if on then R(20, 162, 2, 1, WHITE) end
      self:partyInfo(status, 32, 157, colors.green, 104)
      local id = self:fitPartyInfo(model.systemId or "SLS-DEV", 84)
      self:partyInfo(id, 134, 157, colors.mutedInk, 84, "right")
      R(16, 175, 208, 1, colors.silver)
      local hint = translate("TAP ANYWHERE / A")
      if floor(t / 0.8) % 2 == 0 or not motion then
        self:partyInfo(hint, 18, 182, colors.ink, 186)
      end
      self:v4AdvanceArrow(212, 186)
      self:wantAmbient(0.5, 1 / 10)
    end
    if not idle or wordP < 1 then self:wantAmbient(0.3, 1 / 30) end
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
