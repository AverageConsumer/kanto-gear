-- Kanto Gear v4 skin layer.
--
-- Two visual languages over the shared HGSS layout engine:
--   * Pokégear (Gen 4 inspired): rounded windows, scanline plates, LCD clock,
--     glossy lipped buttons, Poké Ball seats, striped backdrop.
--   * C-Gear (Gen 5 inspired): chamfered panels, slanted tabs, hex field,
--     ring buttons, flat cyan glyph icons, segmented bars.
-- Each comes in light and dark. Everything here is original pixel work drawn
-- from rectangle primitives; no game asset is loaded or bundled.
--
-- The skin overrides H methods in place and keeps every method's signature
-- and hit geometry contract, so ui/base/init.lua and main.lua stay the source of
-- truth for behaviour.
return function(H, ui, read)
  local floor, max, min, sqrt = math.floor, math.max, math.min, math.sqrt
  local base = {}
  for key, value in pairs(H) do
    if type(value) == "function" then base[key] = value end
  end
  H.v4base = base

  local function graphics() return ui.graphics end

  ---------------------------------------------------------------------------
  -- Colour helpers
  ---------------------------------------------------------------------------
  -- Colours are shared read-only tables, so a literal costs nothing per frame.
  local hexCache = {}
  local function hex(value, alpha)
    alpha = alpha or 1
    local byAlpha = hexCache[alpha]
    if not byAlpha then byAlpha = {}; hexCache[alpha] = byAlpha end
    local c = byAlpha[value]
    if c then return c end
    local v = value:gsub("#", "")
    c = { tonumber(v:sub(1, 2), 16) / 255,
      tonumber(v:sub(3, 4), 16) / 255,
      tonumber(v:sub(5, 6), 16) / 255, alpha }
    byAlpha[value] = c
    return c
  end
  local function mix(a, b, k)
    return { a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k,
      a[3] + (b[3] - a[3]) * k, a[4] or 1 }
  end
  local function alpha(c, a) return { c[1], c[2], c[3], a } end
  local function ramp(m, l, d, hi)
    return { M = hex(m), L = hex(l), D = hex(d), Hi = hex(hi) }
  end
  local function rampOf(c)
    return { M = c, L = mix(c, { 1, 1, 1, 1 }, 0.30),
      D = mix(c, { 0, 0, 0, 1 }, 0.42), Hi = mix(c, { 1, 1, 1, 1 }, 0.62) }
  end
  H.v4mix, H.v4hex, H.v4ramp = mix, hex, rampOf

  ---------------------------------------------------------------------------
  -- Palettes
  ---------------------------------------------------------------------------
  local SKINS = {}
  SKINS.pokegear = {
    light = {
      tokens = {
        bgA = hex("c3e6cf"), bgB = hex("b5dec5"), emboss = hex("a6d3b8"),
        paper = hex("f8f8f0"), paper2 = hex("e8efe6"), line = hex("cfdcd2"),
        acc = ramp("2f8c76", "4fae95", "1b5a4c", "9fe0cc"), accS = hex("3a9a82"),
        well = hex("14483c"), lcd = hex("1d3b2e"), lcdOn = hex("c4f5a6"),
        lcdGhost = hex("2b4d3b"), lcdFrame = hex("0f2219"),
        slot = ramp("4c9cc4", "68b8d8", "245a80", "b0e0f0"), slotLow = hex("3f8ab4"),
        stars = false,
      },
      colors = {
        bg = "c3e6cf", band = "cfdcd2", bandLight = "e8efe6", ink = "383c44",
        mutedInk = "5f7468", disabledInk = "8c9a92", outline = "283036",
        statusInk = "283036", frame = "283036", highlight = "ffffff",
        white = "f8f8f8", silver = "cdd6d0", silverDark = "6a7a72",
        surface = "f8f8f0", red = "c8382c", redLight = "f07860",
        green = "2f8c76", greenLight = "4fae95", amber = "c07a10",
        amberLight = "f8c048", focus = "fff0cc", blue = "2f6cc0",
        blueLight = "68a8f0", hp = "40d058", hpMid = "f8c030", hpLow = "f04838",
        exp = "38a0f0", party = "4c9cc4", partyLight = "68b8d8",
        partyDark = "245a80", male = "3880f0", female = "f05880",
        selected = "f09838", selectedDark = "985010", fainted = "a85e58",
        partyBg = "c3e6cf", partyBand = "b5dec5", partyEmboss = "a6d3b8",
      },
      shadow = { 0.09, 0.19, 0.16, 0.24 },
      textShadowDark = { 0.08, 0.14, 0.12, 0.16 },
      textShadowLight = { 0, 0, 0, 0.36 },
    },
    dark = {
      tokens = {
        bgA = hex("1f2b47"), bgB = hex("1b2640"), emboss = hex("26355a"),
        paper = hex("2d3748"), paper2 = hex("273041"), line = hex("3a4659"),
        acc = ramp("2c7f8f", "47a3b3", "164a56", "86d4e0"), accS = hex("348c9c"),
        well = hex("0f3640"), lcd = hex("12212e"), lcdOn = hex("9fe8ff"),
        lcdGhost = hex("1c3242"), lcdFrame = hex("070d13"),
        slot = ramp("2f7690", "3f8fa8", "163e52", "7cc4d8"), slotLow = hex("286882"),
        stars = true,
      },
      colors = {
        bg = "1f2b47", band = "3a4659", bandLight = "273041", ink = "eef1f6",
        mutedInk = "a9b6c8", disabledInk = "6d7a8c", outline = "0b0f17",
        statusInk = "0b0f17", frame = "0b0f17", highlight = "46536a",
        white = "f4f6fa", silver = "9aa6b8", silverDark = "4a5668",
        surface = "2d3748", red = "c03830", redLight = "f07c68",
        green = "47a3b3", greenLight = "62bccc", amber = "d08a18",
        amberLight = "f8c850", focus = "3a4a5e", blue = "3a7ad8",
        blueLight = "70b0f8", hp = "40d058", hpMid = "f8c030", hpLow = "f04838",
        exp = "38a0f0", party = "2f7690", partyLight = "3f8fa8",
        partyDark = "163e52", male = "58a0ff", female = "ff70a0",
        selected = "e08a30", selectedDark = "6a3808", fainted = "7a4a4c",
        partyBg = "1f2b47", partyBand = "1b2640", partyEmboss = "26355a",
      },
      shadow = { 0, 0, 0, 0.45 },
      textShadowDark = { 1, 1, 1, 0.07 },
      textShadowLight = { 0, 0, 0, 0.55 },
    },
  }
  SKINS.cgear = {
    light = {
      tokens = {
        bg = hex("e2e9ee"), edge = hex("cfd9e1"), glow = hex("9ed6ec"),
        paper = hex("fbfcfd"), paper2 = hex("eef3f6"), line = hex("c9d5dd"),
        border = hex("9fb1bf"), head = hex("f4f7f9"), headLine = hex("e3eaef"),
        acc = ramp("1ea5d8", "5fd0f4", "0f6688", "bdeefb"), accS = hex("1894c4"),
        slot = ramp("f2f6f9", "ffffff", "9fb1bf", "ffffff"), slotLow = hex("e6edf2"),
        stars = false,
      },
      colors = {
        bg = "e2e9ee", band = "c9d5dd", bandLight = "eef3f6", ink = "24303a",
        mutedInk = "5d7080", disabledInk = "98a8b4", outline = "2a3640",
        statusInk = "2a3640", frame = "9fb1bf", highlight = "ffffff",
        white = "ffffff", silver = "c4d0d8", silverDark = "6a7c8a",
        surface = "fbfcfd", red = "d03848", redLight = "f07888",
        green = "1894c4", greenLight = "5fd0f4", amber = "d07a10",
        amberLight = "f8b848", focus = "e4f6fc", blue = "2f78e0",
        blueLight = "68a8f8", hp = "38c860", hpMid = "f0b828", hpLow = "f04050",
        exp = "1ea5d8", party = "f2f6f9", partyLight = "ffffff",
        partyDark = "9fb1bf", male = "2f78e0", female = "e85090",
        selected = "1ea5d8", selectedDark = "0f6688", fainted = "f0dde0",
        partyBg = "e2e9ee", partyBand = "d4dde4", partyEmboss = "cfd9e1",
      },
      shadow = { 0.12, 0.2, 0.27, 0.22 },
      textShadowDark = { 0.14, 0.2, 0.25, 0.12 },
      textShadowLight = { 0, 0, 0, 0.32 },
    },
    dark = {
      tokens = {
        bg = hex("1b232c"), edge = hex("26313d"), glow = hex("2c627a"),
        paper = hex("212a33"), paper2 = hex("1a222a"), line = hex("33414e"),
        border = hex("3c4b59"), head = hex("0d1116"), headLine = hex("12181f"),
        acc = ramp("4cc8f0", "a8e8f8", "1a6a88", "d8f6fc"), accS = hex("36b4e0"),
        slot = ramp("232d37", "2a3540", "3c4b59", "33414e"), slotLow = hex("1f2831"),
        stars = false,
      },
      colors = {
        bg = "1b232c", band = "33414e", bandLight = "1a222a", ink = "f4f8fb",
        mutedInk = "9fb0bf", disabledInk = "5c6c7a", outline = "0d1116",
        statusInk = "0d1116", frame = "3c4b59", highlight = "33414e",
        white = "f4f8fb", silver = "8090a0", silverDark = "3c4b59",
        surface = "212a33", red = "d84050", redLight = "f88090",
        green = "4cc8f0", greenLight = "a8e8f8", amber = "e08a20",
        amberLight = "f8c050", focus = "1f3c4c", blue = "3a88f0",
        blueLight = "78b8ff", hp = "40d868", hpMid = "f8c030", hpLow = "f84858",
        exp = "4cc8f0", party = "232d37", partyLight = "2a3540",
        partyDark = "3c4b59", male = "58a8ff", female = "ff70a8",
        selected = "4cc8f0", selectedDark = "1a6a88", fainted = "33252b",
        partyBg = "1b232c", partyBand = "1f2831", partyEmboss = "26313d",
      },
      shadow = { 0, 0, 0, 0.45 },
      textShadowDark = { 1, 1, 1, 0.06 },
      textShadowLight = { 0, 0, 0, 0.6 },
    },
  }
  for _, skin in pairs(SKINS) do
    for _, variant in pairs(skin) do
      local colors = {}
      for key, value in pairs(variant.colors) do colors[key] = hex(value) end
      colors.shadow = variant.shadow
      variant.colors = colors
    end
  end

  H.skinName = "pokegear"
  function H:setSkin(name)
    self.skinName = SKINS[name] and name or "pokegear"
    self:setVariant(self.dark)
  end
  function H:isCGear() return self.skinName == "cgear" end

  function H:setVariant(dark)
    base.setVariant(self, dark)
    local variant = SKINS[self.skinName or "pokegear"][dark and "dark" or "light"]
    self.colors = variant.colors
    self.tok = variant.tokens
    self.skinVariant = variant
    local c = variant.colors
    self.palette = {
      { c.surface[1] * 255, c.surface[2] * 255, c.surface[3] * 255 },
      { c.bandLight[1] * 255, c.bandLight[2] * 255, c.bandLight[3] * 255 },
      { c.mutedInk[1] * 255, c.mutedInk[2] * 255, c.mutedInk[3] * 255 },
      { c.ink[1] * 255, c.ink[2] * 255, c.ink[3] * 255 },
    }
    if dark then
      self.palette = { self.palette[4], self.palette[3], self.palette[2], self.palette[1] }
    end
    self.patternKey = nil
  end

  ---------------------------------------------------------------------------
  -- Time for ambient motion
  ---------------------------------------------------------------------------
  H.ambientNow = 0
  function H:clock()
    if self.frozenTime then return self.frozenTime end
    local timer = love and love.timer
    return timer and timer.getTime() or 0
  end
  -- Ambient motion is a light, periodic repaint. It is requested only while
  -- something on screen actually animates.
  function H:wantAmbient(seconds, fastRate)
    if self.motionEnabled == false or self.ambientEnabled == false then return end
    local now = self:clock()
    self.ambientUntil = max(self.ambientUntil or 0, now + (seconds or 0.2))
    if fastRate then
      self.ambientFastUntil = max(self.ambientFastUntil or 0, now + (seconds or 0.2))
      self.ambientFastRate = fastRate
    end
  end
  function H:ambientDue(now)
    if self.motionEnabled == false or self.ambientEnabled == false then return false end
    if not self.ambientUntil or now > self.ambientUntil then return false end
    local rate = self.ambientRate or 0.25
    if self.ambientFastUntil and now <= self.ambientFastUntil then
      rate = self.ambientFastRate or rate
    end
    if not self.ambientLast or now - self.ambientLast >= rate then
      self.ambientLast = now
      return true
    end
    return false
  end
  ---------------------------------------------------------------------------
  -- DS-style in-place motion. Page slides are main.lua's job; these cover
  -- what changes inside a page (tabs, filters, prompts, a moving selector).
  -- Anything that appears in the same frame a page slide starts is shown
  -- settled, because the slide captures that frame once as its target.
  ---------------------------------------------------------------------------
  local function easeOut(p) p = 1 - p; return 1 - p * p * p end
  local function easeBack(p)
    local c = 1.6; p = p - 1
    return 1 + (c + 1) * p * p * p + c * p * p
  end
  H.v4EnterSlots = {}
  function H:v4MotionOff()
    return self.frozenTime ~= nil or self.motionEnabled == false or self.ambientEnabled == false
  end
  -- Raw progress 0..1 of the entrance of `key` in `slot`; 1 once settled.
  function H:v4Enter(slot, key, duration)
    if self.previewEnter then return self.previewEnter end
    if self:v4MotionOff() then return 1 end
    duration = duration or 0.18
    local t = self:clock()
    local st = self.v4EnterSlots[slot]
    if not st or st.key ~= key then
      local sliding = self.v4SlideAt and t - self.v4SlideAt < 0.06
      st = { key = key, t0 = sliding and -1e9 or t }
      self.v4EnterSlots[slot] = st
    end
    local p = (t - st.t0) / duration
    if p >= 1 then return 1 end
    self:wantAmbient(duration - (t - st.t0) + 0.02, 1 / 60)
    return max(0, p)
  end
  -- Staggered entrance for item `index`: returns an eased 0..1 and a pixel
  -- offset to draw at, so a list cascades in like the DS menus.
  function H:v4Stagger(p, index, step, travel, count)
    if p >= 1 then return 1, 0 end
    local span = max(0.3, 1 - (step or 0.12) * ((count or 4) - 1))
    local q = (p - (index - 1) * (step or 0.12)) / span
    q = min(1, max(0, q))
    local e = easeOut(q)
    return e, floor((1 - e) * (travel or 8) + 0.5)
  end
  -- A selector glides from where it was to where it is now.
  H.v4GlideSlots = {}
  function H:v4Glide(slot, target, duration)
    if self:v4MotionOff() then return target end
    local t = self:clock()
    local st = self.v4GlideSlots[slot]
    if not st then
      st = { from = target, to = target, t0 = -1e9 }
      self.v4GlideSlots[slot] = st
    elseif st.to ~= target then
      local d = duration or 0.16
      local cur = st.from + (st.to - st.from) * easeOut(min(1, (t - st.t0) / d))
      local sliding = self.v4SlideAt and t - self.v4SlideAt < 0.06
      st.from, st.to, st.t0 = sliding and target or cur, target, t
    end
    local d = duration or 0.16
    local p = (t - st.t0) / d
    if p >= 1 then return target end
    self:wantAmbient(d - (t - st.t0) + 0.02, 1 / 60)
    return floor(st.from + (target - st.from) * easeOut(p) + 0.5)
  end
  -- Draw `fn` shifted by (dx, dy); used for entrances without touching hits.
  function H:v4Shifted(dx, dy, fn, ...)
    if dx == 0 and dy == 0 then return fn(...) end
    local G = graphics()
    G.push(); G.translate(dx, dy)
    fn(...)
    G.pop()
  end

  local function now(self) return self:clock() end
  local function blink(self, period)
    self:wantAmbient(period)
    return floor(now(self) / period) % 2 == 0
  end
  H.v4blink = blink

  ---------------------------------------------------------------------------
  -- Pixel primitives
  ---------------------------------------------------------------------------
  local function setc(c) graphics().setColor(c[1], c[2], c[3], c[4] or 1) end

  -- Shape stamps. Every primitive below is pure 1px-row geometry, so each
  -- distinct shape is rasterised once into a white-on-clear atlas and then
  -- drawn as one tinted quad. The coverage is the same pixel set the row
  -- rectangles fill, so the picture is identical, but a 42px ball costs one
  -- call instead of 42, and plain rectangles share the atlas texture so the
  -- whole skin stays in one autobatch. Without a real love.graphics (tests,
  -- headless tools) or when the atlas is full, the row path is used instead.
  local STAMP = 1024
  local stamp = { ok = nil }
  local loveG = rawget(_G, "love") and love.graphics
  local loveI = rawget(_G, "love") and love.image
  local stampable = loveG ~= nil and ui.graphics == loveG
    and loveI ~= nil and loveI.newImageData ~= nil
  local function stampReady()
    local st = stamp
    if st.ok ~= nil then return st.ok end
    st.ok = false
    if not stampable then return false end
    local ok = pcall(function()
      local G = loveG
      local data = loveI.newImageData(STAMP, STAMP)
      for y = 0, 2 do for x = 0, 2 do data:setPixel(x, y, 1, 1, 1, 1) end end
      st.image = G.newImage(data)
      st.image:setFilter("nearest", "nearest")
      st.white = G.newQuad(1, 1, 1, 1, STAMP, STAMP)
      st.scratch = G.newQuad(0, 0, 1, 1, STAMP, STAMP)
      st.x, st.y, st.row = 4, 0, 4
    end)
    st.ok = ok
    return ok
  end
  H.v4StampReady = stampReady
  local function stampAlloc(w, h)
    local st = stamp
    if w + 1 > STAMP or h + 1 > STAMP then return nil end
    if st.x + w + 1 > STAMP then st.x, st.y, st.row = 0, st.y + st.row, 0 end
    if st.y + h + 1 > STAMP then st.full = true; return nil end
    local x, y = st.x, st.y
    st.x, st.row = st.x + w + 1, max(st.row, h + 1)
    return x, y
  end
  -- paint(fill) describes the shape as rectangles in its own 0,0 space.
  local function makeStamp(w, h, paint, a, b, c)
    if not stampReady() or stamp.full or w <= 0 or h <= 0 then return false end
    local ax, ay = stampAlloc(w, h)
    if not ax then return false end
    local ok, result = pcall(function()
      local data = loveI.newImageData(w, h)
      paint(function(x, y, rw, rh)
        for yy = y, y + rh - 1 do
          for xx = x, x + rw - 1 do data:setPixel(xx, yy, 1, 1, 1, 1) end
        end
      end, w, h, a, b, c)
      stamp.image:replacePixels(data, nil, nil, ax, ay)
      return { quad = loveG.newQuad(ax, ay, w, h, STAMP, STAMP),
        x = ax, y = ay, w = w, h = h }
    end)
    if not ok then stamp.ok = false; return false end
    return result
  end
  local function slot2(cache, a, b)
    local t = cache[a]
    if not t then t = {}; cache[a] = t end
    return t[b], t
  end
  local function slot3(cache, a, b, c)
    local t = cache[a]
    if not t then t = {}; cache[a] = t end
    return slot2(t, b, c)
  end
  local function stampDraw(st, x, y)
    graphics().draw(stamp.image, st.quad, x, y)
  end
  -- Rows [from, to) of a stamp, as the *rows primitives clip them.
  local function stampRows(st, x, y, from, to)
    from, to = max(0, from), min(st.h, to)
    if to <= from then return end
    local q = stamp.scratch
    q:setViewport(st.x, st.y + from, st.w, to - from, STAMP, STAMP)
    graphics().draw(stamp.image, q, x, y + from)
  end
  local SMALL = 4096

  local function R(x, y, w, h, c)
    if w <= 0 or h <= 0 then return end
    setc(c)
    if stamp.ok or stamp.ok == nil and stampReady() then
      graphics().draw(stamp.image, stamp.white, x, y, 0, w, h)
    else
      graphics().rectangle("fill", x, y, w, h)
    end
  end
  local function P(x, y, c) R(x, y, 1, 1, c) end
  local RAD = {
    [0] = {}, [1] = { 1 }, [2] = { 2, 1 }, [3] = { 3, 1, 1 }, [4] = { 4, 2, 1, 1 },
    [5] = { 5, 3, 2, 1, 1 }, [6] = { 6, 4, 3, 2, 1, 1 }, [7] = { 7, 5, 4, 3, 2, 1, 1 },
    [8] = { 8, 6, 4, 3, 2, 2, 1, 1 }, [9] = { 9, 6, 5, 4, 3, 2, 1, 1, 1 },
    [10] = { 10, 7, 5, 4, 3, 2, 2, 1, 1, 1 },
  }
  local function inset(r, h, i)
    local t = RAD[r] or RAD[10]
    if i < #t then return t[i + 1] end
    if h - 1 - i < #t then return t[h - i] end
    return 0
  end

  -- Shape painters: the exact row geometry, written against fill().
  local function paintRR(fill, w, h, r)
    local t = RAD[r] or RAD[10]
    local n = #t
    if h <= n * 2 then
      for i = 0, h - 1 do
        local k = inset(r, h, i)
        if w - 2 * k > 0 then fill(k, i, w - 2 * k, 1) end
      end
      return
    end
    for i = 0, n - 1 do
      local k = t[i + 1]
      fill(k, i, w - 2 * k, 1)
      fill(k, h - 1 - i, w - 2 * k, 1)
    end
    fill(0, n, w, h - 2 * n)
  end
  local function paintRRBand(fill, w, _, r)
    local t = RAD[r] or RAD[10]
    for i = 0, #t - 1 do fill(t[i + 1], i, w - 2 * t[i + 1], 1) end
  end
  local function paintCH(fill, w, h, k)
    for i = 0, k - 1 do
      local n = k - i
      fill(n, i, w - 2 * n, 1)
      fill(n, h - 1 - i, w - 2 * n, 1)
    end
    fill(0, k, w, h - 2 * k)
  end
  local function paintCHBand(fill, w, _, k)
    for i = 0, k - 1 do fill(k - i, i, w - 2 * (k - i), 1) end
  end
  local function span(d, i)
    local r = d / 2
    local yy = i + 0.5 - r
    return floor(r - sqrt(max(0, r * r - yy * yy)) + 0.5)
  end
  local function paintCIRC(fill, d)
    for i = 0, d - 1 do
      local l = span(d, i)
      fill(l, i, d - 2 * l, 1)
    end
  end
  local function paintRING(fill, d, _, t)
    for i = 0, d - 1 do
      local l = span(d, i)
      local j, di = i - t, d - 2 * t
      if j < 0 or j >= di then
        fill(l, i, d - 2 * l, 1)
      else
        local l2 = t + span(di, j)
        fill(l, i, l2 - l, 1)
        fill(d - l2, i, l2 - l, 1)
      end
    end
  end

  local rrFull, rrBand, chFull, chBand, circs, rings = {}, {}, {}, {}, {}, {}
  local function rrStamp(w, h, r)
    local st, t = slot3(rrFull, r, w, h)
    if st == nil then st = makeStamp(w, h, paintRR, r); t[h] = st end
    return st
  end
  local function chStamp(w, h, k)
    local st, t = slot3(chFull, k, w, h)
    if st == nil then st = makeStamp(w, h, paintCH, k); t[h] = st end
    return st
  end
  local function circStamp(d)
    local st = circs[d]
    if st == nil then st = makeStamp(d, d, paintCIRC); circs[d] = st end
    return st
  end

  -- Row fallbacks (no atlas).
  local function rowsRR(x, y, w, h, r, G)
    local t = RAD[r] or RAD[10]
    local n = #t
    if h <= n * 2 then
      for i = 0, h - 1 do
        local k = inset(r, h, i)
        if w - 2 * k > 0 then G.rectangle("fill", x + k, y + i, w - 2 * k, 1) end
      end
      return
    end
    for i = 0, n - 1 do
      local k = t[i + 1]
      G.rectangle("fill", x + k, y + i, w - 2 * k, 1)
      G.rectangle("fill", x + k, y + h - 1 - i, w - 2 * k, 1)
    end
    G.rectangle("fill", x, y + n, w, h - 2 * n)
  end

  -- Rounded rectangle: corner rows individually, the body as one rect.
  local function RR(x, y, w, h, r, c)
    if w <= 0 or h <= 0 then return end
    r = min(r, floor(min(w, h) / 2))
    setc(c)
    local G = graphics()
    if stamp.ok ~= false and stampReady() then
      if w * h <= SMALL then
        local st = rrStamp(w, h, r)
        if st then return stampDraw(st, x, y) end
      else
        local n = #(RAD[r] or RAD[10])
        if h > n * 2 then
          local st, t = slot2(rrBand, r, w)
          if st == nil then st = makeStamp(w, n, paintRRBand, r); t[w] = st end
          if st then
            G.draw(stamp.image, st.quad, x, y)
            G.draw(stamp.image, stamp.white, x, y + n, 0, w, h - 2 * n)
            G.draw(stamp.image, st.quad, x, y + h, 0, 1, -1)
            return
          end
        end
      end
    end
    rowsRR(x, y, w, h, r, G)
  end
  local function RRrows(x, y, w, h, r, from, to, c)
    r = min(r, floor(min(w, h) / 2))
    setc(c)
    local G = graphics()
    if w > 0 and h > 0 and w * h <= SMALL and stamp.ok ~= false and stampReady() then
      local st = rrStamp(w, h, r)
      if st then return stampRows(st, x, y, from, to) end
    end
    local n = #(RAD[r] or RAD[10])
    local i = max(0, from)
    to = min(h, to)
    while i < to do
      local k = inset(r, h, i)
      if i >= n and i < h - n then
        local stop = min(to, h - n)
        G.rectangle("fill", x, y + i, w, stop - i)
        i = stop
      else
        G.rectangle("fill", x + k, y + i, w - 2 * k, 1)
        i = i + 1
      end
    end
  end
  -- Chamfered rectangle (45° corners), the C-Gear silhouette.
  local function CH(x, y, w, h, k, c)
    if w <= 0 or h <= 0 then return end
    k = min(k, floor(min(w, h) / 2))
    setc(c)
    local G = graphics()
    if stamp.ok ~= false and stampReady() then
      if w * h <= SMALL then
        local st = chStamp(w, h, k)
        if st then return stampDraw(st, x, y) end
      elseif k > 0 then
        local st, t = slot2(chBand, k, w)
        if st == nil then st = makeStamp(w, k, paintCHBand, k); t[w] = st end
        if st then
          G.draw(stamp.image, st.quad, x, y)
          G.draw(stamp.image, stamp.white, x, y + k, 0, w, h - 2 * k)
          G.draw(stamp.image, st.quad, x, y + h, 0, 1, -1)
          return
        end
      end
    end
    for i = 0, k - 1 do
      local n = k - i
      G.rectangle("fill", x + n, y + i, w - 2 * n, 1)
      G.rectangle("fill", x + n, y + h - 1 - i, w - 2 * n, 1)
    end
    G.rectangle("fill", x, y + k, w, h - 2 * k)
  end
  local function CHrows(x, y, w, h, k, from, to, c)
    k = min(k, floor(min(w, h) / 2))
    setc(c)
    local G = graphics()
    if w > 0 and h > 0 and w * h <= SMALL and stamp.ok ~= false and stampReady() then
      local st = chStamp(w, h, k)
      if st then return stampRows(st, x, y, from, to) end
    end
    for i = max(0, from), min(h, to) - 1 do
      local n = i < k and k - i or (h - 1 - i < k and k - (h - 1 - i) or 0)
      G.rectangle("fill", x + n, y + i, w - 2 * n, 1)
    end
  end
  local function CIRC(x, y, d, c)
    setc(c)
    local G = graphics()
    if d > 0 and stamp.ok ~= false and stampReady() then
      local st = circStamp(d)
      if st then return stampDraw(st, x, y) end
    end
    for i = 0, d - 1 do
      local l = span(d, i)
      G.rectangle("fill", x + l, y + i, d - 2 * l, 1)
    end
  end
  local function CIRCrows(x, y, d, from, to, c)
    setc(c)
    local G = graphics()
    if d > 0 and stamp.ok ~= false and stampReady() then
      local st = circStamp(d)
      if st then return stampRows(st, x, y, from, to) end
    end
    for i = max(0, from), min(d, to) - 1 do
      local l = span(d, i)
      G.rectangle("fill", x + l, y + i, d - 2 * l, 1)
    end
  end
  local function RING(x, y, d, t, c)
    setc(c)
    local G = graphics()
    if d > 0 and stamp.ok ~= false and stampReady() then
      local st, tt = slot2(rings, d, t)
      if st == nil then st = makeStamp(d, d, paintRING, t); tt[t] = st end
      if st then return stampDraw(st, x, y) end
    end
    for i = 0, d - 1 do
      local l = span(d, i)
      local j, di = i - t, d - 2 * t
      if j < 0 or j >= di then
        G.rectangle("fill", x + l, y + i, d - 2 * l, 1)
      else
        local l2 = t + span(di, j)
        G.rectangle("fill", x + l, y + i, l2 - l, 1)
        G.rectangle("fill", x + d - l2, y + i, l2 - l, 1)
      end
    end
  end
  local function ELL(x, y, w, h, c)
    setc(c)
    local G = graphics()
    for i = 0, h - 1 do
      local yy = (i + 0.5 - h / 2) / (h / 2)
      local l = floor(w / 2 - (w / 2) * sqrt(max(0, 1 - yy * yy)) + 0.5)
      G.rectangle("fill", x + l, y + i, w - 2 * l, 1)
    end
  end
  -- Pixel art from strings; palette maps characters to colours. Call sites
  -- pass fresh literal tables, so the parsed art is keyed by its content.
  local artCache = setmetatable({}, { __mode = "k" })
  local artByText = {}
  local concat = table.concat
  local function parseArt(rows)
    local runs, chars, w = {}, {}, 0
    for j, row in ipairs(rows) do
      w = max(w, #row)
      local i = 1
      while i <= #row do
        local ch = row:sub(i, i)
        if ch ~= "." then
          local start = i
          while i + 1 <= #row and row:sub(i + 1, i + 1) == ch do i = i + 1 end
          runs[#runs + 1] = { ch, start - 1, j - 1, i - start + 1 }
          if not chars[ch] then chars[ch] = true; chars[#chars + 1] = ch end
        end
        i = i + 1
      end
    end
    return { runs = runs, chars = chars, w = w, h = #rows }
  end
  local function paintArtChar(fill, _, _, art, ch)
    for _, run in ipairs(art.runs) do
      if run[1] == ch then fill(run[2], run[3], run[4], 1) end
    end
  end
  local function ART(rows, x, y, pal)
    local art = artCache[rows]
    if not art then
      local text = concat(rows, "\n")
      art = artByText[text]
      if not art then art = parseArt(rows); artByText[text] = art end
      artCache[rows] = art
    end
    local G = graphics()
    if art.masks == nil and stamp.ok ~= false and stampReady() then
      local masks = {}
      for i, ch in ipairs(art.chars) do
        masks[i] = makeStamp(art.w, art.h, paintArtChar, art, ch)
        if not masks[i] then masks = false; break end
      end
      art.masks = masks
    end
    if art.masks then
      local image = stamp.image
      for i, ch in ipairs(art.chars) do
        local c = pal[ch]
        if c then setc(c); G.draw(image, art.masks[i].quad, x, y) end
      end
      return
    end
    for _, run in ipairs(art.runs) do
      local c = pal[run[1]]
      if c then setc(c); G.rectangle("fill", x + run[2], y + run[3], run[4], 1) end
    end
  end
  local function artWidth(rows)
    local w = 0
    for _, row in ipairs(rows) do w = max(w, #row) end
    return w
  end
  H.v4 = { R = R, P = P, RR = RR, RRrows = RRrows, CH = CH, CHrows = CHrows,
    CIRC = CIRC, CIRCrows = CIRCrows, RING = RING, ELL = ELL, ART = ART,
    setc = setc, inset = inset, artWidth = artWidth, hex = hex, mix = mix,
    alpha = alpha, rampOf = rampOf }

  ---------------------------------------------------------------------------
  -- Text: the DS drop shadow on every glyph
  ---------------------------------------------------------------------------
  -- Gen 4 and Gen 5 typography casts a one-pixel shadow right, down and
  -- diagonally. A thin proxy around the graphics module adds it to every
  -- print the HGSS layer issues, so all screens inherit it at once.
  local rawGraphics = ui.graphics
  H.textShadow = true
  local function shadowFor(r, g, b, a)
    local variant = H.skinVariant
    if not variant then return nil end
    local lum = 0.299 * r + 0.587 * g + 0.114 * b
    local s = lum > 0.55 and variant.textShadowLight or variant.textShadowDark
    return s[1], s[2], s[3], s[4] * (a or 1)
  end
  local function shadowed(draw)
    -- Fixed leading arguments, no per-call tables: text, x, y, then the rest.
    return function(text, x, y, ...)
      if H.textShadow and not H.shadowSuspended then
        local r, g, b, a = rawGraphics.getColor()
        local sr, sg, sb, sa = shadowFor(r, g, b, a)
        if sr then
          H.shadowSuspended = true
          rawGraphics.setColor(sr, sg, sb, sa)
          draw(text, x + 1, y + 1, ...)
          draw(text, x + 1, y, ...)
          draw(text, x, y + 1, ...)
          H.shadowSuspended = false
          rawGraphics.setColor(r, g, b, a)
        end
      end
      return draw(text, x, y, ...)
    end
  end
  local proxy = setmetatable({
    print = shadowed(function(...) return rawGraphics.print(...) end),
    printf = shadowed(function(...) return rawGraphics.printf(...) end),
    -- Plain fills join the stamp atlas so they batch with the shapes.
    rectangle = function(mode, x, y, w, h, ...)
      if mode == "fill" and select("#", ...) == 0
          and (stamp.ok or stamp.ok == nil and stampReady()) then
        return rawGraphics.draw(stamp.image, stamp.white, x, y, 0, w, h)
      end
      return rawGraphics.rectangle(mode, x, y, w, h, ...)
    end,
  }, { __index = rawGraphics })
  ui.graphics = proxy
  if ui.translationFonts then
    local fonts = ui.translationFonts
    local wrapped = setmetatable({}, { __index = function(_, key)
      local value = fonts[key]
      if type(value) == "function" then
        return function(_, ...) return value(fonts, ...) end
      end
      return value
    end })
    local plainPrint = fonts.print
    rawset(wrapped, "print", function(_, font, value, x, y, width, align)
      if H.textShadow and not H.shadowSuspended then
        local r, g, b, a = rawGraphics.getColor()
        local sr, sg, sb, sa = shadowFor(r, g, b, a)
        if sr then
          H.shadowSuspended = true
          rawGraphics.setColor(sr, sg, sb, sa)
          plainPrint(fonts, font, value, x + 1, y + 1, width, align)
          plainPrint(fonts, font, value, x + 1, y, width, align)
          plainPrint(fonts, font, value, x, y + 1, width, align)
          H.shadowSuspended = false
          rawGraphics.setColor(r, g, b, a)
        end
      end
      return plainPrint(fonts, font, value, x, y, width, align)
    end)
    ui.translationFonts = wrapped
  end
  function H:withoutShadow(fn, ...)
    local previous = self.textShadow
    self.textShadow = false
    local a, b, c, d = fn(...)
    self.textShadow = previous
    return a, b, c, d
  end

  local K = {
    SKINS = SKINS, R = R, P = P, RR = RR, RRrows = RRrows, CH = CH, CHrows = CHrows,
    CIRC = CIRC, CIRCrows = CIRCrows, RING = RING, ELL = ELL, ART = ART,
    setc = setc, inset = inset, hex = hex, mix = mix, alpha = alpha,
    rampOf = rampOf, base = base, blink = blink, graphics = graphics,
    easeOut = easeOut, easeBack = easeBack,
  }
  if read then
    local art = read("ui/skins/icon_art.lua")
    if art then K.iconArt = assert(load(art, "@kanto_gear/ui/skins/icon_art.lua"))() end
    for _, name in ipairs({ "ui/skins/chrome.lua", "ui/skins/home.lua", "ui/skins/party.lua",
        "ui/skins/battle.lua", "ui/skins/summary.lua", "ui/skins/apps.lua", "ui/skins/explorer.lua", "ui/skins/battleinfo.lua", "ui/skins/dex.lua", "ui/skins/pc.lua", "ui/skins/menus.lua", "ui/skins/native.lua", "ui/skins/icons.lua", "ui/skins/case.lua" }) do
      local source = read(name)
      if source then
        assert(load(source, "@kanto_gear/" .. name))()(H, ui, K, read)
      end
    end
  end
  H:setVariant(H.dark)
  return K
end
