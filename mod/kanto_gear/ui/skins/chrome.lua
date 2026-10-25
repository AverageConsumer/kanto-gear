-- Kanto Gear v4: shared chrome (backdrops, header, windows, controls, bars).
return function(H, ui, K)
  local floor, max, min = math.floor, math.max, math.min
  local R, P, RR, RRrows, CH, CHrows = K.R, K.P, K.RR, K.RRrows, K.CH, K.CHrows
  local CIRC, CIRCrows, RING, ART = K.CIRC, K.CIRCrows, K.RING, K.ART
  local mix, alpha, hex, setc, inset = K.mix, K.alpha, K.hex, K.setc, K.inset
  local base, graphics = K.base, K.graphics
  local WHITE = { 1, 1, 1, 1 }
  local function cg(self) return self.skinName == "cgear" end
  K.cg = cg

  ---------------------------------------------------------------------------
  -- Backdrops
  ---------------------------------------------------------------------------
  local cache = {}
  local function canImage()
    return love and love.image and love.image.newImageData
      and love.graphics and love.graphics.newImage
  end
  local function hashRand(n)
    local s = math.sin(n * 127.1 + 311.7) * 43758.5453
    return s - floor(s)
  end
  K.hashRand = hashRand

  local buildStripe, buildHex
  local function stripeImage(self)
    local key = "stripe:" .. tostring(self.tok)
    if cache[key] ~= nil then return cache[key] end
    if not canImage() then cache[key] = false; return false end
    local ok, value = pcall(buildStripe, self)
    cache[key] = ok and value or false
    return cache[key]
  end
  function buildStripe(self)
    local a, b = self.tok.bgA, self.tok.bgB
    local data = love.image.newImageData(8, 8)
    for y = 0, 7 do for x = 0, 7 do
      local c = ((x + y) % 8) < 4 and b or a
      data:setPixel(x, y, c[1], c[2], c[3], 1)
    end end
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    image:setWrap("repeat", "repeat")
    local quad = love.graphics.newQuad(0, 0, 240, 216, 8, 8)
    assert(quad.setViewport, "quad viewport")
    return { image = image, quad = quad }
  end

  local function hexField(self)
    local key = "hex:" .. tostring(self.tok)
    if cache[key] ~= nil then return cache[key] end
    if not canImage() then cache[key] = false; return false end
    local ok, value = pcall(buildHex, self)
    cache[key] = ok and value or false
    return cache[key]
  end
  -- Boot warm-up: build the expensive backdrop image of one variant of the
  -- active skin ahead of time, so Auto theme switches never stall a frame.
  function H:v4PrewarmBackdrop(dark)
    local skin = K.SKINS[self.skinName or "pokegear"]
    local variant = skin and skin[dark and "dark" or "light"]
    if not variant then return false end
    local probe = { tok = variant.tokens }
    local built = self.skinName == "cgear" and hexField(probe) or stripeImage(probe)
    return built ~= false
  end

  function buildHex(self)
    local t = self.tok
    local s = 9
    local W, Hh = 240, 216
    local ids = {}
    local function hexAt(px, py)
      local q = (math.sqrt(3) / 3 * px - py / 3) / s
      local r = (2 / 3 * py) / s
      local x, z = q, r
      local y = -x - z
      local rx, ry, rz = floor(x + 0.5), floor(y + 0.5), floor(z + 0.5)
      local dx, dy, dz = math.abs(rx - x), math.abs(ry - y), math.abs(rz - z)
      if dx > dy and dx > dz then rx = -ry - rz
      elseif dy > dz then ry = -rx - rz
      else rz = -rx - ry end
      return (rx + 100) * 1000 + (rz + 100)
    end
    for y = 0, Hh - 1 do
      for x = 0, W - 1 do ids[y * W + x] = hexAt(x + 0.5, y + 0.5) end
    end
    local data = love.image.newImageData(W, Hh)
    local cells = {}
    for y = 0, Hh - 1 do
      for x = 0, W - 1 do
        local i = y * W + x
        local id = ids[i]
        local edge = (x + 1 < W and ids[i + 1] ~= id) or (y + 1 < Hh and ids[i + W] ~= id)
        local c = edge and t.edge or t.bg
        data:setPixel(x, y, c[1], c[2], c[3], 1)
        if not edge then
          local cell = cells[id]
          if not cell then cell = { x0 = x, y0 = y, x1 = x, y1 = y, px = {} }; cells[id] = cell end
          cell.x0, cell.y0 = min(cell.x0, x), min(cell.y0, y)
          cell.x1, cell.y1 = max(cell.x1, x), max(cell.y1, y)
          cell.px[#cell.px + 1] = { x, y }
        end
      end
    end
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    -- A handful of cells glow in turn, like the C-Gear's idle shimmer.
    local glows = {}
    for id, cell in pairs(cells) do
      if hashRand(id % 6007) > 0.74 and #cell.px > 120 then
        local w, h = cell.x1 - cell.x0 + 1, cell.y1 - cell.y0 + 1
        local d = love.image.newImageData(w, h)
        for _, p in ipairs(cell.px) do
          d:setPixel(p[1] - cell.x0, p[2] - cell.y0, 1, 1, 1, 1)
        end
        local img = love.graphics.newImage(d)
        img:setFilter("nearest", "nearest")
        glows[#glows + 1] = { image = img, x = cell.x0, y = cell.y0,
          phase = hashRand(id % 9973) * 7, period = 7 + hashRand(id % 7919) * 5 }
      end
    end
    local quad = love.graphics.newQuad(0, 0, 240, 216, 240, 216)
    assert(quad.setViewport, "quad viewport")
    return { image = image, glows = glows, quad = quad }
  end

  local function nightSky(self, t, top)
    for i = 0, 33 do
      local x = floor(hashRand(i) * 236) + 2
      local y = floor(hashRand(i + 50) * 210) + 3
      if y < top + 2 then y = y + top end
      local ph = (t + hashRand(i + 9) * 6) % 6
      local c = ph < 0.5 and { 1, 1, 1, 1 } or ph < 3 and hex("9fb2d8") or hex("5e719a")
      P(x, y, c)
      if hashRand(i + 3) > 0.82 and ph < 0.5 then
        local d = hex("5e719a")
        P(x - 1, y, d); P(x + 1, y, d); P(x, y - 1, d); P(x, y + 1, d)
      end
    end
    local k = (t % 9) / 9
    if k < 0.06 then
      local p = k / 0.06
      local sx, sy = 200 - p * 90, 30 + p * 40
      for i = 0, 8 do
        P(floor(sx + i), floor(sy - floor(i * 0.45)),
          i < 2 and WHITE or i < 5 and hex("b8c8ff") or hex("5e719a"))
      end
    end
  end

  -- Draws in native 240×216 pixels regardless of the caller's transform.
  function H:v4Backdrop(callerScale, top)
    top = top or 0
    local G = graphics()
    G.push()
    if callerScale and callerScale ~= 1 then G.scale(1 / callerScale, 1 / callerScale) end
    local t = self:clock()
    if cg(self) then
      local field = hexField(self)
      if field then
        field.quad:setViewport(0, top, 240, 216 - top, 240, 216)
        setc(WHITE); G.draw(field.image, field.quad, 0, top)
        local glow = self.tok.glow
        local any = false
        for _, cell in ipairs(field.glows) do
          local u = ((t + cell.phase) % cell.period) / 1.1
          if u < 1 and cell.y >= top then
            any = true
            local a = math.sin(u * math.pi) * 0.55
            G.setColor(glow[1], glow[2], glow[3], a)
            G.draw(cell.image, cell.x, cell.y)
          end
        end
        self:wantAmbient(0.6)
      else
        R(0, top, 240, 216 - top, self.tok.bg)
      end
    else
      local stripe = stripeImage(self)
      if stripe then
        local offset = floor(t / 0.25) % 8
        stripe.quad:setViewport(offset, top, 240, 216 - top, 8, 8)
        setc(WHITE); G.draw(stripe.image, stripe.quad, 0, top)
        self:wantAmbient(0.2)
      else
        R(0, top, 240, 216 - top, self.tok.bgA)
      end
      local e = self.tok.emboss
      RING(28, 29, 184, 3, e)
      R(28, 119, 70, 3, e); R(142, 119, 70, 3, e)
      RING(98, 99, 44, 3, e); RING(110, 111, 20, 2, e)
      if self.tok.stars then nightSky(self, t, top); self:wantAmbient(0.6) end
    end
    G.pop()
  end
  function H:backdrop() self:v4Backdrop(1.5) end
  function H:battleBackdrop() self:v4Backdrop(1) end
  function H:partyBackdrop() self:v4Backdrop(1, 28) end

  ---------------------------------------------------------------------------
  -- Header plate
  ---------------------------------------------------------------------------
  local CHEV_L = { "..#", ".##", "###", ".##", "..#" }
  local CHEV_R = { "#..", "##.", "###", "##.", "#.." }
  local BACK = { "...#", "..##", ".###", "####", ".###", "..##", "...#" }
  K.CHEV_L, K.CHEV_R = CHEV_L, CHEV_R

  local PAGE_TINT = {
    POKEDEX = "e04838", TRAINER = "3878d0", STEPS = "3ea04c", BAG = "d88a18",
    STORE = "d84860", NOTES = "c88a20", ACHIEVEMENTS = "c89a18", SETTINGS = "5a6c88",
    TOOLS = "d88a18", MAP = "3878d0", LOCAL = "3878d0", PSS = "4a68c8",
    DAYCARE = "d85878", CALENDAR = "3878d0", SHINY = "e0a020",
  }
  local tintCache = {}
  -- Every app wears its own colour on the header plate; Home keeps the theme.
  function H:v4HeaderAccent()
    local tok = self.tok
    local key = self.v4Page and PAGE_TINT[self.v4Page]
    if not key then return tok.acc, tok.accS, tok.well end
    local cacheKey = key .. (self.dark and ":d" or ":l") .. self.skinName
    local entry = tintCache[cacheKey]
    if not entry then
      local base = hex(key)
      if self.dark then base = mix(base, { 0, 0, 0, 1 }, 0.18) end
      local r = K.rampOf(base)
      entry = { r, mix(r.M, r.L, 0.35), mix(r.D, { 0, 0, 0, 1 }, 0.45) }
      tintCache[cacheKey] = entry
    end
    return entry[1], entry[2], entry[3]
  end

  function H:headerBar(title, back, paged, contentOffsetY)
    contentOffsetY = contentOffsetY or 0
    local tok, colors = self.tok, self.colors
    local acc, accS, well = self:v4HeaderAccent()
    local pulse = floor(self:clock() / 0.4) % 2
    if paged then self:wantAmbient(0.4) end
    local left = 0
    if cg(self) then
      R(0, 0, 240, 22, tok.head)
      for y = 1, 20, 2 do R(0, y, 240, 1, tok.headLine) end
      R(0, 21, 240, 1, acc.M)
      R(0, 22, 240, 1, self.dark and hex("0f3c4e") or acc.Hi)
      if back then
        CH(3, 3, 20, 16, 4, self.dark and hex("26313c") or hex("d9e2e8"))
        ART(BACK, 10, 7, { ["#"] = acc.M })
        left = 26
      end
      local tabW = (back and 138 or 112) - left
      for y = 0, 20 do
        R(left, y, tabW + (20 - y), 1, y < 1 and acc.L or (y % 2 == 1 and acc.M or accS))
        R(left + tabW + (20 - y), y, 2, 1, acc.Hi)
      end
      local shown = self:fitLabel(title, paged and tabW - 22 or tabW - 14)
      if paged or back then
        if paged then ART(CHEV_L, left + 5 - pulse, 8, { ["#"] = WHITE }) end
        if paged then ART(CHEV_R, left + tabW - 6 + pulse, 8, { ["#"] = WHITE }) end
        local w = self:labelWidth(shown)
        local tx = left + floor((tabW - w) / 2)
        self:label(shown, tx, 3 + contentOffsetY, WHITE)
        return tx, w
      else
        R(left + 5, 5, 3, 11, WHITE)
        self:label(shown, left + 12, 3 + contentOffsetY, WHITE)
      end
      return left, self:labelWidth(shown)
    end
    -- Pokégear plate
    R(0, 0, 240, 23, acc.D)
    for y = 1, 20 do R(0, y, 240, 1, y % 2 == 1 and acc.M or accS) end
    R(0, 0, 240, 1, acc.Hi)
    R(0, 21, 240, 1, acc.D); R(0, 22, 240, 1, colors.outline)
    for x = 0, 239, 6 do
      R(x + 1, 23, 4, 1, colors.outline); R(x + 2, 24, 2, 1, colors.outline)
      R(x + 1, 24, 1, 1, colors.shadow); R(x + 4, 24, 1, 1, colors.shadow)
      R(x + 2, 25, 2, 1, colors.shadow)
    end
    if back then
      RR(3, 3, 20, 16, 4, colors.outline)
      RR(4, 4, 18, 14, 3, acc.L)
      RRrows(4, 4, 18, 14, 3, 0, 7, acc.Hi)
      R(4, 15, 18, 2, acc.D)
      ART(BACK, 10, 7, { ["#"] = acc.D })
      ART(BACK, 9, 6, { ["#"] = WHITE })
      left = 26
    else
      left = 4
    end
    local wellW = 138 - left
    RR(left, 3, wellW, 17, 3, acc.D)
    RR(left + 1, 4, wellW - 2, 15, 2, well)
    R(left + 3, 18, wellW - 6, 1, acc.M)
    local inner = paged and wellW - 22 or wellW - 8
    local shown = self:fitLabel(title, inner)
    if paged then
      ART(CHEV_L, left + 5 - pulse, 9, { ["#"] = acc.Hi })
      ART(CHEV_R, left + wellW - 8 + pulse, 9, { ["#"] = acc.Hi })
    end
    local w = self:labelWidth(shown)
    local x = left + floor((wellW - w) / 2)
    self:label(shown, x, 3 + contentOffsetY, WHITE)
    return x, w
  end

  -- Seven-segment LCD digits (Pokégear) with faintly lit "ghost" segments.
  local SEG = {
    a = { 1, 0, 3, 1 }, b = { 4, 1, 1, 3 }, c = { 4, 5, 1, 3 }, d = { 1, 8, 3, 1 },
    e = { 0, 5, 1, 3 }, f = { 0, 1, 1, 3 }, g = { 1, 4, 3, 1 },
  }
  local DIG = { ["0"] = "abcdef", ["1"] = "bc", ["2"] = "abged", ["3"] = "abgcd",
    ["4"] = "fgbc", ["5"] = "afgcd", ["6"] = "afgedc", ["7"] = "abc",
    ["8"] = "abcdefg", ["9"] = "abcdfg" }
  local function lcdWidth(value)
    local w = 0
    for ch in value:gmatch(".") do
      if ch == ":" then w = w + 3 elseif DIG[ch] then w = w + 6 end
    end
    return w
  end
  local function lcd(value, x, y, on, ghost, colon)
    for ch in value:gmatch(".") do
      if ch == ":" then
        local c = colon and on or ghost
        R(x + 1, y + 2, 1, 1, c); R(x + 1, y + 6, 1, 1, c)
        x = x + 3
      elseif DIG[ch] then
        for name, s in pairs(SEG) do
          R(x + s[1], y + s[2], s[3], s[4], DIG[ch]:find(name, 1, true) and on or ghost)
        end
        x = x + 6
      end
    end
  end
  K.lcd, K.lcdWidth = lcd, lcdWidth
  local MOON = { "..##", ".##.", "##..", "##..", "##..", ".##.", "..##" }
  local SUN = { "...#...", ".#...#.", "..###..", "#.###.#", "..###..", ".#...#.", "...#..." }
  local MORN = { "...#...", ".#...#.", "..###..", "#######", "......." }
  local function periodIcon(period, x, y, c)
    period = tostring(period or ""):upper()
    if period == "NITE" then ART(MOON, x, y, { ["#"] = c }); P(x + 6, y + 1, c); return true end
    if period == "MORN" then ART(MORN, x, y + 1, { ["#"] = c }); return true end
    if period == "DAY" then ART(SUN, x, y, { ["#"] = c }); return true end
    return false
  end
  K.periodIcon = periodIcon

  function H:headerClock(value, period, left, width, y)
    value = tostring(value or "")
    local tok = self.tok
    local digits, suffix = value:match("^([%d:]+)%s*(.*)$")
    digits = digits or value
    -- Cached frames can outlive a blink phase; keep the time readable at rest.
    if cg(self) then
      local w = self:labelWidth(value)
      local iconW = period and 10 or 0
      local x = left + floor((width - w - iconW) / 2) + 6
      self:label(value, x, y - 3, self.colors.ink)
      if period then
        periodIcon(period, x + w + 4, y + 1,
          tostring(period):upper() == "NITE" and tok.acc.M or hex("f0a020"))
      end
      return x
    end
    local lx, lw = 145, 63
    RR(lx, 3, lw, 17, 3, tok.lcdFrame)
    RR(lx + 1, 4, lw - 2, 15, 2, tok.lcd)
    R(lx + 2, 5, lw - 4, 1, { 1, 1, 1, 0.08 })
    local dw = lcdWidth(digits)
    local sw = suffix ~= "" and self:partyInfoWidth(suffix) + 2 or 0
    local iw = period and 9 or 0
    local total = dw + sw + (iw > 0 and iw + 3 or 0)
    local x = lx + floor((lw - total) / 2)
    lcd(digits, x, 7, tok.lcdOn, tok.lcdGhost, true)
    if sw > 0 then
      self:withoutShadow(function()
        self:partyInfo(suffix, x + dw + 2, 5, tok.lcdOn)
      end)
    end
    if period then periodIcon(period, x + dw + sw + 3, 8, tok.lcdOn) end
    return x
  end

  function H:battery(x, y, segments, blinkSegment, blinkVisible, tint, fill)
    x, y = floor(x + 0.5), floor(y + 0.5) - 1
    local colors = self.colors
    if cg(self) then
      local frame = self.dark and hex("c8d4dc") or colors.mutedInk
      R(x, y, 18, 10, frame); R(x + 1, y + 1, 16, 8, self.tok.head); R(x + 18, y + 3, 2, 4, frame)
      for s = 1, 3 do
        local on = s <= math.ceil((segments or 0) * 3 / 4)
          or (blinkSegment and blinkVisible and s == math.ceil(blinkSegment * 3 / 4))
        if on then R(x + 2 + (s - 1) * 5, y + 2, 4, 6, fill or self.tok.acc.M) end
      end
      return
    end
    local o = colors.outline
    R(x + 1, y, 16, 1, o); R(x + 1, y + 9, 16, 1, o)
    R(x, y + 1, 1, 8, o); R(x + 17, y + 1, 1, 8, o); R(x + 18, y + 3, 2, 4, o)
    R(x + 1, y + 1, 16, 8, hex("e8f0e8"))
    for s = 1, 4 do
      local on = s <= (segments or 0) or (s == blinkSegment and blinkVisible)
      R(x + 2 + (s - 1) * 4, y + 2, 3, 6, on and (fill or colors.hp) or hex("c0ccc4"))
      if on then R(x + 2 + (s - 1) * 4, y + 2, 3, 1, { 1, 1, 1, 0.45 }) end
    end
  end

  ---------------------------------------------------------------------------
  -- Windows
  ---------------------------------------------------------------------------
  -- Window in the active skin. opts: fill, edge, radius, shadow.
  function H:v4Window(x, y, w, h, opts)
    opts = opts or {}
    local colors = self.colors
    if cg(self) then
      local k = opts.radius or (h < 16 and 2 or (h < 30 and 3 or 5))
      if opts.shadow ~= false and self:shadowVisible() then CH(x + 2, y + 2, w, h, k, colors.shadow) end
      CH(x, y, w, h, k, opts.edge or self.tok.border)
      CH(x + 1, y + 1, w - 2, h - 2, max(0, k - 1), opts.fill or colors.surface)
      return k
    end
    local r = opts.radius or (h < 16 and 2 or (h < 30 and 3 or 4))
    if opts.shadow ~= false and self:shadowVisible() then RR(x + 2, y + 2, w, h, r, colors.shadow) end
    RR(x, y, w, h, r, opts.edge or colors.outline)
    RR(x + 1, y + 1, w - 2, h - 2, max(0, r - 1), opts.fill or colors.surface)
    return r
  end

  function H:panel(x, y, w, h, selected, focusAccent, baseAccent, edge)
    local colors = self.colors
    local fill = colors.surface
    if baseAccent then fill = mix(colors.surface, baseAccent, self.dark and 0.14 or 0.09) end
    fill = self:focusSurface(selected, fill, focusAccent)
    local r = self:v4Window(x, y, w, h, { fill = fill, edge = edge })
    if baseAccent and h >= 14 then
      if cg(self) then
        R(x + 1, y + r + 1, 2, h - 2 * r - 2, baseAccent)
      else
        R(x + r + 1, y + 1, w - 2 * r - 2, 1, mix(colors.highlight, baseAccent, 0.35))
      end
    end
    if selected then self:focusFrame(x, y, w, h) end
  end

  function H:homeTile(x, y, w, h, accent, selected)
    self:v4Window(x, y, w, h, { radius = cg(self) and 6 or 4 })
    if selected then self:roundedFocusFrame(x, y, w, h, 5) end
  end

  -- Accent title band of a widget/card.
  function H:homeWidgetHeader(x, y, w, label, accent, accentLight, editing, translated)
    local tok, colors = self.tok, self.colors
    local text = translated and label or ui.translate(label)
    if cg(self) then
      R(x + 6, y + 4, 4, 7, tok.acc.M); R(x + 6, y + 4, 4, 1, tok.acc.L)
      -- in Edit Home the remove badge owns the corner: the title steps aside
      local nudge = self.v4HomeEditing and 6 or 0
      local shown = self:fitPartyInfo(text, w - 34 - nudge)
      self:partyInfo(shown, x + 13 + nudge, y + 2, colors.ink)
      R(x + 5, y + 14, w - 10, 1, self.dark and tok.acc.D or tok.acc.L)
      if not editing then
        for i = 0, 3 do for j = 0, 5 do
          P(x + w - 16 - i * 4 - j, y + 4 + j, self.dark and tok.acc.D or tok.acc.L)
        end end
        ART(K.CHEV_R, x + w - 9 + floor(self:clock() / 0.5) % 2, y + 5, { ["#"] = tok.acc.M })
        self:wantAmbient(0.5)
      end
      return
    end
    local r = 3
    local a = { M = accent or tok.acc.M, L = accentLight or tok.acc.L }
    a.D = mix(a.M, { 0, 0, 0, 1 }, 0.42); a.S = mix(a.M, a.L, 0.35)
    a.Hi = mix(a.L, { 1, 1, 1, 1 }, 0.5)
    RRrows(x + 1, y + 1, w - 2, 30, r, 0, 15, a.M)
    for j = 2, 13, 2 do
      local n = inset(r, 30, j)
      R(x + 1 + n, y + 1 + j, w - 2 - 2 * n, 1, a.S)
    end
    R(x + 3, y + 1, w - 6, 1, a.Hi)
    R(x + 1, y + 15, w - 2, 1, a.D)
    R(x + 1, y + 16, w - 2, 1, self.tok.line)
    local nudge = self.v4HomeEditing and 8 or 0
    local shown = self:fitPartyInfo(text, w - 22 - nudge)
    self:partyInfo(shown, x + 7 + nudge, y + 3, WHITE)
    if not editing then
      ART(K.CHEV_R, x + w - 10 + floor(self:clock() / 0.5) % 2, y + 5, { ["#"] = WHITE })
      self:wantAmbient(0.5)
    end
  end

  function H:tab(x, y, w, h, label, active, arrow, enabled)
    local colors, tok = self.colors, self.tok
    if enabled == nil then enabled = not active end
    local pressed = self:beginPress(x, y, w, h, enabled)
    if cg(self) then
      CH(x, y, w, h, 3, active and tok.acc.M or tok.border)
      CH(x + 1, y + 1, w - 2, h - 2, 2, active and tok.acc.M or colors.surface)
      if active then CHrows(x + 1, y + 1, w - 2, h - 2, 2, 0, floor((h - 2) / 2), tok.acc.L) end
    else
      RR(x, y, w, h, 3, colors.outline)
      if active then
        RR(x + 1, y + 1, w - 2, h - 2, 2, tok.acc.D)
        RR(x + 1, y + 1, w - 2, h - 4, 2, tok.acc.M)
        RRrows(x + 1, y + 1, w - 2, h - 4, 2, 0, floor((h - 4) / 2), tok.acc.L)
        R(x + 3, y + 1, w - 6, 1, tok.acc.Hi)
      else
        RR(x + 1, y + 1, w - 2, h - 2, 2, tok.paper2)
        R(x + 3, y + 1, w - 6, 1, self.dark and tok.line or WHITE)
      end
    end
    local tint = active and WHITE or colors.mutedInk
    local arrowWidth, gap = arrow and 4 or 0, arrow and 3 or 0
    local shown = self:fitPartyType(label, w - 8 - arrowWidth - gap)
    local textWidth = self:partyInfoWidth(shown)
    local left = x + floor((w - textWidth - gap - arrowWidth) / 2)
    local top = y + floor((h - 11) / 2) - 1
    self:partyType(shown, left, top, tint, textWidth)
    if arrow then self:detailChevron(left + textWidth + gap, y + floor((h - 4) / 2), tint) end
    self:endPress(pressed)
  end

  -- Native focus: a pulsing frame (Pokégear) or breathing corner brackets (C-Gear).
  -- The D-pad focus glides from the previous item to the next one like the
  -- DS cursor. It only glides between same-sized items it was just drawn on;
  -- a new screen, a page slide or a second frame in one paint snaps it.
  local focusGlide = {}
  local function glideFocus(self, x, y, w, h)
    if self:v4MotionOff() then return x, y end
    local t = self:clock()
    local g = focusGlide
    local recent = g.seen and t - g.seen < 0.3 and g.seen ~= t
    local sliding = self.v4SlideAt and t - self.v4SlideAt < 0.06
    if g.tx ~= x or g.ty ~= y or g.w ~= w or g.h ~= h then
      if recent and not sliding and g.w == w and g.h == h then
        local p = min(1, (t - (g.t0 or -1e9)) / 0.12)
        local e = K.easeOut(p)
        g.fx = floor((g.fx or g.tx) + (g.tx - (g.fx or g.tx)) * e + 0.5)
        g.fy = floor((g.fy or g.ty) + (g.ty - (g.fy or g.ty)) * e + 0.5)
        g.t0 = t
      else
        g.fx, g.fy, g.t0 = x, y, -1e9
      end
      g.tx, g.ty, g.w, g.h = x, y, w, h
    end
    g.seen = t
    local p = (t - (g.t0 or -1e9)) / 0.12
    if p >= 1 then return x, y end
    self:wantAmbient(0.14, 1 / 60)
    local e = K.easeOut(max(0, p))
    return floor(g.fx + (x - g.fx) * e + 0.5), floor(g.fy + (y - g.fy) * e + 0.5)
  end

  function H:focusFrame(x, y, w, h)
    x, y = glideFocus(self, x, y, w, h)
    local on = K.blink(self, 0.26)
    local colors = self.colors
    if cg(self) then
      local k = floor(self:clock() / 0.3) % 2
      local c = on and self.tok.acc.M or self.tok.acc.L
      local L = min(8, floor(min(w, h) / 2))
      local x0, y0, x1, y1 = x - 1 - k, y - 1 - k, x + w + k, y + h + k
      R(x0, y0, L, 2, c); R(x0, y0, 2, L, c)
      R(x1 - L + 1, y0, L, 2, c); R(x1 - 1, y0, 2, L, c)
      R(x0, y1 - 1, L, 2, c); R(x0, y1 - L + 1, 2, L, c)
      R(x1 - L + 1, y1 - 1, L, 2, c); R(x1 - 1, y1 - L + 1, 2, L, c)
      return
    end
    local c = on and colors.selected or colors.amberLight
    R(x - 1, y - 2, w + 2, 2, c); R(x - 1, y + h, w + 2, 2, c)
    R(x - 2, y - 1, 2, h + 2, c); R(x + w, y - 1, 2, h + 2, c)
  end
  function H:roundedFocusFrame(x, y, w, h) self:focusFrame(x, y, w, h) end

  ---------------------------------------------------------------------------
  -- Chevrons (keep hit rectangles)
  ---------------------------------------------------------------------------
  function H:chevron(x, y, right)
    local pressed = self:beginPress(x - 9, y - 10, 18, 20)
    local c = cg(self) and self.tok.acc.M or self.tok.acc.M
    ART(right and CHEV_R or CHEV_L, right and x - 1 or x - 1, y - 2, { ["#"] = c })
    self:endPress(pressed)
  end
  function H:pageChevron(x, y, right, interactive)
    local pressed = self:beginPress(x - 8, y - 9, 16, 18, interactive ~= false)
    local c = interactive == false and self.colors.disabledInk or self.tok.acc.M
    ART(right and CHEV_R or CHEV_L, x - 1, y - 2, { ["#"] = c })
    self:endPress(pressed)
  end
  function H:detailChevron(x, y, tint, large)
    if large then
      ART({ "##...", ".##..", "..##.", "...##", "..##.", ".##..", "##..." }, x, y, { ["#"] = tint })
    else
      ART({ "#..", "##.", "###", "##.", "#.." }, x, y, { ["#"] = tint })
    end
  end

  ---------------------------------------------------------------------------
  -- Bars, badges, icons
  ---------------------------------------------------------------------------
  local HP_TAG = { "#.#.##", "#.#.#.#", "###.##", "#.#.#", "#.#.#" }
  local HP_TAGS = {
    PS = { "##...##", "#.#.#..", "##...#.", "#.....#", "#...##." },
    PV = { "##..#.#", "#.#.#.#", "##..#.#", "#...#.#", "#....#." },
    KP = { "#.#.##.", "#.#.#.#", "##..##.", "#.#.#..", "#.#.#.." },
  }
  local function hpColors(self, ratio)
    local c = self.colors
    local fill = ratio > 0.5 and c.hp or ratio > 0.2 and c.hpMid or c.hpLow
    return fill, mix(fill, WHITE, 0.5)
  end
  K.hpColors = hpColors

  -- Signature kept: hpBar(x, y, w, hp, maxHp). Height 5 as before.
  function H:hpBar(x, y, w, hp, maxHp)
    local ratio = max(0, min(1, (hp or 0) / max(1, maxHp or 1)))
    local fill, hi = hpColors(self, ratio)
    local colors = self.colors
    if cg(self) then
      -- segmented C-Gear bar
      R(x, y, w, 5, colors.outline)
      R(x + 1, y + 1, w - 2, 3, self.dark and hex("33404c") or hex("c4d0d8"))
      local f = floor((w - 2) * ratio)
      R(x + 1, y + 1, f, 3, fill); R(x + 1, y + 1, f, 1, hi)
      for s = x + 6, x + w - 3, 6 do R(s, y + 1, 1, 3, colors.outline) end
      return
    end
    R(x, y, w, 5, colors.outline)
    R(x + 1, y + 1, w - 2, 3, self.dark and hex("3a4652") or hex("506058"))
    local f = floor((w - 2) * ratio)
    R(x + 1, y + 1, f, 3, fill); R(x + 1, y + 1, f, 1, hi)
  end
  -- Gen 4 "HP" tag welded to a bar; total height 7.
  function H:v4HpBar(x, y, w, hp, maxHp)
    local label = ui.translate and ui.translate("HP") or "HP"
    local ratio = max(0, min(1, (hp or 0) / max(1, maxHp or 1)))
    local fill, hi = hpColors(self, ratio)
    local colors = self.colors
    local low = ratio > 0 and ratio <= 0.2 and K.blink(self, 0.35)
    if cg(self) then
      self:withoutShadow(function()
        self:partyInfo(label, x, y - 3, self.tok.acc.M)
      end)
      local bx = x + 12
      R(bx, y, w - 12, 7, colors.outline)
      R(bx + 1, y + 1, w - 14, 5, self.dark and hex("33404c") or hex("c4d0d8"))
      local f = floor((w - 14) * ratio)
      R(bx + 1, y + 1, f, 5, low and hi or fill); R(bx + 1, y + 1, f, 2, hi)
      for s = bx + 7, bx + w - 15, 7 do R(s, y + 1, 1, 5, colors.outline) end
      return
    end
    RR(x, y, 15, 7, 1, colors.outline)
    R(x + 1, y + 1, 13, 5, colors.amberLight); R(x + 1, y + 3, 13, 3, colors.amber)
    ART(HP_TAGS[label] or HP_TAG, x + 4, y + 1, { ["#"] = hex("5a3008") })
    R(x + 14, y, w - 14, 7, colors.outline)
    R(x + 15, y + 1, w - 16, 5, self.dark and hex("3a4652") or hex("506058"))
    local f = floor((w - 16) * ratio)
    R(x + 15, y + 1, f, 5, low and hi or fill); R(x + 15, y + 1, f, 2, hi)
    R(x + 15, y + 5, f, 1, { 0, 0, 0, 0.18 })
  end

  function H:expBar(x, y, w, ratio)
    ratio = max(0, min(1, ratio or 0))
    local colors = self.colors
    R(x, y, w, 4, colors.outline)
    R(x + 1, y + 1, w - 2, 2, self.dark and hex("2a3542") or hex("3a4652"))
    local f = floor((w - 2) * ratio)
    R(x + 1, y + 1, f, 2, colors.exp); R(x + 1, y + 1, f, 1, mix(colors.exp, WHITE, 0.55))
  end

  -- Status as a Gen 4 pill (21×9). Signature: statusIcon(id, x, y) for a 7×7 slot;
  -- pills are drawn by v4StatusPill where layouts have room.
  local STATUS = {
    PAR = { "e8b818", "f8e070", "6a4a00" }, SLP = { "8c8ca0", "c8c8d8", "303040" },
    PSN = { "b050c0", "e090e8", "401848" }, TOX = { "8a30a0", "c070d8", "300c40" },
    BRN = { "e86030", "f8a070", "601c08" }, FRZ = { "58b8e8", "b0e8f8", "103c58" },
    FNT = { "d04040", "f08080", "4a0c0c" },
  }
  for key, value in pairs(STATUS) do STATUS[key] = { hex(value[1]), hex(value[2]), hex(value[3]) } end
  function H:v4StatusPill(id, x, y)
    id = tostring(id or ""):upper()
    local s = STATUS[id]
    if not s then return 0 end
    local by = y - 1
    if cg(self) then
      CH(x, by, 21, 11, 2, s[3]); CH(x + 1, by + 1, 19, 9, 1, s[1])
      R(x + 2, by + 1, 17, 4, s[2])
    else
      RR(x, by, 21, 11, 3, s[3]); RR(x + 1, by + 1, 19, 9, 2, s[1]); R(x + 2, by + 1, 17, 4, s[2])
    end
    local w = self:partyInfoWidth(id)
    local c = s[1]
    local lum = c[1] * 0.3 + c[2] * 0.59 + c[3] * 0.11
    self:withoutShadow(self.partyInfo, self, id, x + floor((21 - w) / 2) + 1, y - 2,
      lum > 0.62 and s[3] or WHITE)
    return 21
  end

  local POKERUS = {
    active = { "..#.#..", ".#####.", "##.#.##", ".#####.", "##.#.##", ".#####.", "..#.#.." },
    cured = { ".#####.", "#.....#", "#.#.#.#", "#.....#", "#.#.#.#", "#..#..#", ".#####." },
  }
  function H:pokerusMark(state, x, y)
    local art = POKERUS[state]
    if art then ART(art, x, y, { ["#"] = state == "active" and hex("d850a8") or self.colors.mutedInk }) end
  end

  function H:pokerusBadge(state, x, y)
    if not POKERUS[state] then return end
    local fill = state == "active" and hex("a83880") or self.colors.silverDark
    local shape = cg(self) and CH or RR
    shape(x, y, 27, 11, 2, self.colors.outline)
    shape(x + 1, y + 1, 25, 9, 1, fill)
    self:partyInfoCentered("PKRS", x + 1, y + 1, 25, 9, WHITE)
    self:pokerusMark(state, x + 30, y + 2)
  end
  local baseStatusIcon = base.statusIcon
  function H:statusIcon(statusId, x, y)
    return baseStatusIcon(self, statusId, x, y)
  end

  function H:genderIcon(gender, x, y)
    local c = gender == "male" and self.colors.male or self.colors.female
    local o = self.colors.outline
    if gender == "male" then
      ART({ "..oooo", "..ommo", ".oomoo", "omoomo", "omoom.", "oomoo.", ".ooo.." }, x, y, {})
      ART({ "...###", "....##", "..##.#", ".#..#.", ".#..#.", "..##.." }, x, y, { ["#"] = c })
    elseif gender == "female" then
      ART({ ".##.", "#..#", "#..#", ".##.", ".#..", "###.", ".#.." }, x + 1, y, { ["#"] = c })
    end
  end

  local TYPE = {
    NORMAL = "a8a878", FIRE = "f08030", WATER = "5890f0", ELECTRIC = "f0c020",
    GRASS = "70c048", ICE = "68c8d0", FIGHTING = "c03028", POISON = "a040a0",
    GROUND = "d8b058", FLYING = "a890f0", PSYCHIC = "f85888", BUG = "a8b820",
    ROCK = "b8a038", GHOST = "705898", DRAGON = "7038f8", DARK = "705848",
    STEEL = "b8b8d0", FAIRY = "ee99ac",
  }
  for key, value in pairs(TYPE) do TYPE[key] = hex(value) end
  function H:typeColor(typeId)
    return TYPE[tostring(typeId or "NORMAL"):upper()] or TYPE.NORMAL
  end
  function H:v4TypePill(typeId, label, x, y, w, fainted)
    local c = self:typeColor(typeId)
    if fainted then c = mix(c, hex("707070"), 0.6) end
    local d = mix(c, { 0, 0, 0, 1 }, 0.45)
    -- the badge is tall enough to hold its letters, which are printed flat
    -- (no drop shadow) so nothing spills over the rim
    local by = y - 1
    if cg(self) then
      CH(x, by, w, 11, 2, d); CH(x + 1, by + 1, w - 2, 9, 1, c)
      R(x + 2, by + 1, w - 4, 1, mix(c, WHITE, 0.4))
    else
      RR(x, by, w, 11, 3, d); RR(x + 1, by + 1, w - 2, 9, 2, c)
      R(x + 2, by + 1, w - 4, 1, mix(c, WHITE, 0.35)); R(x + 2, by + 9, w - 4, 1, mix(c, d, 0.4))
    end
    local chars = {}
    for ch in tostring(label or typeId or "---"):gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
    local limit = w >= 30 and 99 or 3
    while #chars > limit or (#chars > 1 and self:partyInfoWidth(table.concat(chars)) > w - 3) do table.remove(chars) end
    local shown = table.concat(chars)
    local tw = self:partyInfoWidth(shown)
    local lum = c[1] * 0.3 + c[2] * 0.59 + c[3] * 0.11
    self:withoutShadow(self.partyInfo, self, shown, x + floor((w - tw) / 2) + 1, y - 2,
      lum > 0.62 and mix(c, { 0, 0, 0, 1 }, 0.62) or WHITE)
  end
  function H:typeBadges(mon, x, y, fainted)
    local dual = mon.type2 and mon.type2 ~= mon.type
    if not dual then
      self:v4TypePill(mon.type, mon.typeLabel, x + 11, y, 22, fainted)
      return
    end
    self:v4TypePill(mon.type, mon.typeLabel, x, y, 21, fainted)
    self:v4TypePill(mon.type2, mon.type2Label, x + 22, y, 21, fainted)
  end

  -- Mini Poké Ball used for markers and team strips (7×7).
  local BALL = { "..ooo..", ".orrro.", "orrrrro", "ooowooo", "owwwwwo", ".owwwo.", "..ooo.." }
  local BALL_EMPTY = { "..ooo..", ".o...o.", "o.....o", "o.....o", "o.....o", ".o...o.", "..ooo.." }
  K.BALL, K.BALL_EMPTY = BALL, BALL_EMPTY
  function H:v4MiniBall(x, y, state)
    if state == "none" then ART(BALL_EMPTY, x, y, { o = self.colors.silverDark }); return end
    local pal = { o = hex("101010"), r = hex("f05040"), w = hex("f8f8f8") }
    if state == "status" then pal.r, pal.w = hex("e8b818"), hex("f8f0c0") end
    if state == "fainted" then pal.r, pal.w = hex("505860"), hex("8890a0") end
    ART(BALL, x, y, pal)
    if state ~= "fainted" then P(x + 2, y + 1, hex("f8a090")) end
  end

  ---------------------------------------------------------------------------
  -- Lipped buttons
  ---------------------------------------------------------------------------
  -- ramp: { M, L, D, Hi }. Returns the press offset (0 or 2).
  function H:v4Button(x, y, w, h, a, opts)
    opts = opts or {}
    local colors = self.colors
    local off = opts.pressed and 2 or 0
    local r = opts.radius or 6
    if cg(self) then
      local k = opts.chamfer or min(8, floor(h / 4))
      if self:shadowVisible() then CH(x + 1, y + 3, w, h, k, colors.shadow) end
      CH(x, y + off, w, h - off, k, colors.outline)
      CH(x + 1, y + 1 + off, w - 2, h - 2 - off, k - 1, self.dark and hex("e8f0f4") or WHITE)
      CH(x + 2, y + 2 + off, w - 4, h - 4 - off, max(0, k - 2), a.D)
      local hh = h - 7 - off + (opts.pressed and 2 or 0)
      CH(x + 2, y + 2 + off, w - 4, hh, max(0, k - 2), a.M)
      CHrows(x + 2, y + 2 + off, w - 4, hh, max(0, k - 2), 0, floor(hh / 2), a.L)
      -- diagonal speed lines, Gen 5 battle-menu style
      local G = graphics()
      setc({ 1, 1, 1, 0.10 })
      for i = 0, 2 do
        local sx = x + w - 30 + i * 7
        for j = 0, 9 do G.rectangle("fill", sx - j, y + 4 + off + j, 3, 1) end
      end
      return off
    end
    local lip = opts.lip or 4
    if self:shadowVisible() then RR(x + 1, y + 2, w, h, r, colors.shadow) end
    RR(x, y + off, w, h - off, r, colors.outline)
    RR(x + 1, y + 1 + off, w - 2, h - 2 - off, r - 1, a.D)
    local hh = h - 2 - lip + (opts.pressed and 2 or 0) - off
    RR(x + 1, y + 1 + off, w - 2, hh, r - 1, a.M)
    RRrows(x + 1, y + 1 + off, w - 2, hh, r - 1, 0, floor(hh * 0.45), a.L)
    R(x + r, y + 2 + off, w - 2 * r, 1, a.Hi)
    return off
  end

  ---------------------------------------------------------------------------
  -- Large counter digits (the quantity well's face); the regular face stands
  -- in when the large one lacks a glyph.
  ---------------------------------------------------------------------------
  local function largeFace(value)
    local font = ui.largeFont
    if font and (not font.hasGlyphs or font:hasGlyphs(value)) then return font end
  end
  function H:v4LargeWidth(value)
    value = tostring(value or "")
    local font = largeFace(value)
    if font then return font:getWidth(value) end
    return self:partyInfoWidth(value)
  end
  function H:v4LargeHeight()
    local font = ui.largeFont
    return font and font:getHeight() or 10
  end
  function H:v4LargeFits(value, width)
    return largeFace(tostring(value or "")) ~= nil and self:v4LargeWidth(value) <= width
  end
  function H:v4Large(value, x, y, tint, width, align)
    value = tostring(value or "")
    local font = largeFace(value)
    local w = self:v4LargeWidth(value)
    if width and align == "center" then x = x + floor((width - w) / 2)
    elseif width and align == "right" then x = x + width - w end
    if not font then
      self:partyInfo(value, x, y + floor((self:v4LargeHeight() - 10) / 2), tint)
      return w
    end
    local G = graphics()
    local previous = G.getFont()
    G.setFont(font); setc(tint); G.print(value, floor(x), floor(y))
    if previous then G.setFont(previous) end
    return w
  end

  K.WHITE = WHITE
end
