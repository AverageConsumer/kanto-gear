-- Visual study only: illustrative progress, no runtime app or save changes.
return function(theme, screen, gen1, fontData)
  local G, c = love.graphics, theme.colors
  local quiet = theme.dark and c.silver or c.silverDark
  local detail = screen == "achievements_detail"
  local album = screen == "achievements_stamps"
  local places = gen1 and { "ROUTE 1", "ROUTE 2", "ROUTE 3", "VIRIDIAN FOREST",
    "ROUTE 4", "MT. MOON" } or { "ROUTE 38", "ROUTE 39", "ROUTE 40",
    "ILEX FOREST", "ROUTE 37", "UNION CAVE" }
  local fonts, ink = {}, {}
  for name, size in pairs({ small = 8, body = 9, title = 11 }) do
    fonts[name] = G.newFont(fontData, size)
    fonts[name]:setFilter("linear", "linear")
  end
  local function rect(x, y, w, h, tint)
    G.setColor(tint); G.rectangle("fill", x, y, w, h)
  end
  -- Measure actual glyph ink in the preview, including bearings, before placing
  -- text. A one-pixel parity difference is the only allowed asymmetric gap.
  local function label(value, x, y, w, h, tint, size, align)
    size, value = size or "body", tostring(value)
    local key, font = size .. value, fonts[size]
    local bounds = ink[key]
    if not bounds then
      local target = G.getCanvas()
      local canvas = G.newCanvas(math.ceil(font:getWidth(value)) + 8, 24)
      G.push("all"); G.setCanvas(canvas); G.origin(); G.setScissor(); G.setShader()
      G.clear(0, 0, 0, 0); G.setColor(1, 1, 1, 1); G.setFont(font)
      G.print(value, 4, 0); G.setCanvas(target); G.pop()
      local data = canvas:newImageData()
      local l, t, r, b = data:getWidth(), 24, -1, -1
      for py = 0, 23 do for px = 0, data:getWidth() - 1 do
        local _, _, _, a = data:getPixel(px, py)
        if a > 0.1 then l, t, r, b = math.min(l, px), math.min(t, py),
          math.max(r, px), math.max(b, py) end
      end end
      bounds = { x = l - 4, y = t, w = r - l + 1, h = b - t + 1 }
      ink[key] = bounds; data:release(); canvas:release()
    end
    assert(bounds.w <= w and bounds.h <= h, "clipped achievement label: " .. value)
    local dx = align == "left" and 0 or math.floor((w - bounds.w) / 2)
    local dy = math.floor((h - bounds.h) / 2)
    assert(math.abs(h - bounds.h - 2 * dy) <= 1, "vertical ink centering")
    if align ~= "left" then
      assert(math.abs(w - bounds.w - 2 * dx) <= 1, "horizontal ink centering")
    end
    if theme.dark and tint == c.green then tint = c.greenLight end
    if tint == c.silverDark then tint = quiet end
    G.setColor(tint or c.ink); G.setFont(font)
    G.print(value, x + dx - bounds.x, y + dy - bounds.y)
  end
  local function disc(cx, cy, radius, tint)
    for y = -radius, radius do
      local half = math.floor(math.sqrt(radius * radius - y * y))
      rect(cx - half, cy + y, half * 2 + 1, 1, tint)
    end
  end
  local stampInk = { 0.08, 0.21, 0.20, 1 }
  local stampGold = { 0.83, 0.57, 0.18, 1 }
  local stampLight = { 1.0, 0.85, 0.44, 1 }
  local stampPaper = { 0.92, 0.96, 0.85, 1 }
  local function seal(cx, cy, r, kind, complete)
    local edge = complete and stampGold or c.band
    disc(cx + 1, cy + 2, r, c.shadow)
    disc(cx, cy, r, complete and stampInk or quiet)
    disc(cx, cy, r - 1, edge)
    disc(cx, cy, r - 3, complete and stampLight or c.surface)
    disc(cx, cy, r - 4, complete and stampInk or c.band)
    disc(cx, cy, r - 5, complete and stampPaper or c.surface)
    G.push(); G.translate(cx, cy); G.scale(r / 24, r / 24)
    local tint = complete and stampInk or quiet
    if kind == "forest" then
      for _, tree in ipairs({ { -8, 1 }, { 8, 1 }, { 0, -7 } }) do
        local x, y = tree[1], tree[2]
        rect(x - 1, y + 5, 3, 6, tint)
        for row = 0, 4 do rect(x - row - 1, y + row * 2 - 5, row * 2 + 3, 2, tint) end
      end
    elseif kind == "cave" then
      for row = 0, 10 do rect(-row - 2, row - 8, row * 2 + 5, 2, tint) end
      rect(-4, -1, 9, 8, complete and stampPaper or c.surface)
    else
      for row = -12, 10 do
        local x = row < -6 and 4 or row > 4 and -4 or 4 - math.floor((row + 6) * 0.8)
        rect(x - 4, row, 9, 1, tint)
        if (row + 12) % 6 < 3 then
          rect(x, row, 1, 1, complete and stampPaper or c.surface)
        end
      end
      rect(-11, -6, 4, 5, tint); rect(-12, -4, 6, 1, tint)
      rect(9, 6, 4, 5, tint); rect(8, 8, 6, 1, tint)
    end
    G.pop()
    if complete and r >= 20 then
      rect(cx - 26, cy + 11, 53, 12, stampInk)
      rect(cx - 25, cy + 12, 51, 1, stampLight)
      label("ERKUNDET", cx - 25, cy + 14, 51, 7, stampPaper, "small")
    end
  end
  local function check(cx, cy)
    disc(cx, cy, 8, c.green)
    rect(cx - 4, cy, 2, 2, c.white); rect(cx - 2, cy + 2, 2, 2, c.white)
    rect(cx, cy, 2, 2, c.white); rect(cx + 2, cy - 2, 2, 2, c.white)
  end
  local function card(x, y, w, h)
    assert(x >= 6 and x + w <= 234 and y >= 34 and y + h <= 210,
      "achievement card keeps the common screen margins")
    theme:panel(x, y, w, h, false)
  end
  local function button(value, x, y, w, h)
    card(x, y, w, h)
    local span = theme:partyInfoWidth(value) + 11
    local left = x + math.floor((w - span) / 2)
    label(value, left, y + 1, span - 11, h - 2, c.green, "body")
    theme:detailChevron(left + span - 4, y + math.floor((h - 5) / 2), c.green)
  end

  theme:headerBar(detail and places[2] or "ERFOLGE", true, false)
  theme:headerClock("20:04", "NITE", 139, 72, 6)
  theme:battery(214, 8, 4, nil, true, c.ink, c.greenLight)
  if not detail then
    local tabs = { "ZIELE", "STEMPELPASS" }
    local active = album and 2 or 1
    for i, value in ipairs(tabs) do
      local x = 6 + (i - 1) * 117
      if i == active then
        card(x, 34, 111, 18)
        rect(x + 5, 49, 101, 2, c.green)
      end
      label(value, x, 35, 111, 12, i == active and c.green or c.silverDark, "small")
    end
  end

  if detail then
    card(6, 34, 228, 55)
    seal(37, 61, 22, "route", false)
    label("FAST ERKUNDET", 70, 41, 150, 13, c.green, "title", "left")
    label("NUR EIN FUND FEHLT NOCH", 70, 59, 150, 10, c.ink, "small", "left")
    for i = 1, 6 do
      rect(70 + (i - 1) * 25, 77, 21, 4, i < 6 and c.greenLight or c.band)
    end
    card(6, 98, 228, 31)
    theme:homeTrainerIcon(13, 100)
    label("ALLE TRAINER BESIEGT", 49, 102, 150, 11, c.ink, "body", "left")
    label("3 VON 3", 49, 116, 150, 8, c.green, "small", "left")
    check(215, 113)
    card(6, 137, 228, 31)
    theme:battleTeamBall(27, 152, true)
    label("ALLE ITEMS GEFUNDEN", 49, 141, 150, 11, c.ink, "body", "left")
    label("2 VON 2", 49, 155, 150, 8, c.green, "small", "left")
    check(215, 152)
    card(6, 176, 228, 34)
    -- A magnifier marks the still-hidden find; do not use an unsupported tool
    -- key (which silently renders the generic Tools gear).
    for i = 0, 5 do rect(29 + i, 194 + i, 4, 4, stampInk) end
    disc(25, 189, 9, stampInk)
    disc(25, 189, 7, { 0.45, 0.75, 0.90, 1 })
    disc(25, 189, 5, stampPaper)
    rect(21, 186, 2, 3, c.white)
    label("EIN VERSTECKTER FUND", 49, 180, 160, 11, c.ink, "body", "left")
    label("FUNDORT ANSEHEN", 49, 195, 152, 9, c.green, "small", "left")
    theme:detailChevron(214, 192, c.green, true)
  elseif album then
    label((gen1 and "KANTO" or "JOHTO") .. "  2 / 6 ERKUNDET",
      6, 59, 228, 11, c.green, "body")
    card(6, 76, 228, 134)
    for i, place in ipairs(places) do
      local column, row = (i - 1) % 3, math.floor((i - 1) / 3)
      local x, y = 8 + column * 76, 78 + row * 65
      local complete = i == 1 or i == 4
      local kind = i == 4 and "forest" or i == 6 and "cave" or "route"
      seal(x + 35, y + 24, 22, kind, complete)
      label(place, x, y + 50, 72, 10, complete and c.ink or c.silverDark, "small")
    end
  else
    card(6, 61, 228, 91)
    seal(49, 102, 27, "route", false)
    label("FAST GESCHAFFT", 95, 69, 127, 10, c.green, "small", "left")
    label(places[2], 95, 83, 127, 15, c.ink, "title", "left")
    label("NOCH 1 GEHEIMER FUND", 95, 103, 127, 10, c.ink, "small", "left")
    button("ANSEHEN", 95, 122, 127, 22)
    label("DEIN STEMPELPASS", 6, 159, 228, 11, c.green, "body")
    for i, place in ipairs({ places[1], places[4] }) do
      local x = i == 1 and 6 or 123
      card(x, 177, 111, 33)
      seal(x + 18, 193, 12, i == 2 and "forest" or "route", true)
      label(place, x + 35, 182, 70, 10, c.ink, "small")
      label("ERKUNDET", x + 35, 197, 70, 7, c.green, "small")
    end
  end
end
