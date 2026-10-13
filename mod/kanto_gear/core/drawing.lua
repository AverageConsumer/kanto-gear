return function(FONT, THEME, WIDTH, box, clean, color, fit, glyphList, progressRatio, render)
local function text(value, x, y, c, scale)
  value, scale = clean(value), scale or 1
  color(c)
  if THEME.translationFonts then
    local font, offset = THEME.translationFonts:select(THEME.bitmapFont, value)
    if font ~= THEME.bitmapFont then
      local previous = render.G.getFont()
      render.G.setFont(font)
      render.G.print(value, x, y + offset * scale, 0, scale, scale)
      if previous then render.G.setFont(previous) end
      return
    end
  end
  local cursor = x
  for _, character in ipairs(glyphList(value)) do
    local glyph = FONT[character]
    if glyph then
      for row = 0, 6 do
        for column = 0, 4 do
          if glyph:sub(row * 5 + column + 1, row * 5 + column + 1) == "1" then
            render.G.rectangle("fill", cursor + column * scale, y + row * scale,
                        scale, scale)
          end
        end
      end
    end
    cursor = cursor + 6 * scale
  end
end

local function centered(value, y, c, scale)
  value, scale = clean(value), scale or 1
  text(value, math.floor((WIDTH - THEME:textWidth(value) * scale) / 2),
       y, c, scale)
end

local function outline(x, y, w, h, c)
  c = c or render.INK
  if THEME.style == "classic" or w < 5 or h < 5 then
    box("line", x + 0.5, y + 0.5, w - 1, h - 1, c)
    return
  end
  box("fill", x + 2, y, w - 4, 1, c)
  box("fill", x + 2, y + h - 1, w - 4, 1, c)
  box("fill", x, y + 2, 1, h - 4, c)
  box("fill", x + w - 1, y + 2, 1, h - 4, c)
  box("fill", x + 1, y + 1, 1, 1, c)
  box("fill", x + w - 2, y + 1, 1, 1, c)
  box("fill", x + 1, y + h - 2, 1, 1, c)
  box("fill", x + w - 2, y + h - 2, 1, 1, c)
end

function THEME:drawMapMarker(x, y)
  x, y = math.floor(x + 0.5), math.floor(y + 0.5)
  box("fill", x - 3, y - 3, 7, 7, render.INK)
  box("fill", x - 2, y - 2, 5, 5, render.PAPER)
  box("fill", x - 1, y - 1, 3, 3, self.red)
end

local function hpBar(x, y, w, hp, maxHp)
  local ratio = progressRatio(hp, 0, math.max(1, maxHp or 1))
  box("fill", x, y, w, 4, render.DARK)
  box("fill", x + 1, y + 1, math.floor((w - 2) * ratio), 2,
      ratio > 0.5 and render.PAPER or ratio > 0.2 and render.MID or render.INK)
end

local function expBar(x, y, w, ratio, selected)
  box("fill", x, y, w, 3, render.DARK)
  box("fill", x + 1, y + 1, math.floor((w - 2) * ratio), 1,
      selected and render.MID or render.PAPER)
end

local function button(x, y, w, h, label, selected)
  selected = selected and THEME.nativeFocus ~= false
  if THEME.style == "hgss" then
    THEME.hgss:button(x, y, w, h, label, selected, 1, 4 / 3)
    return
  end
  local modern = THEME.style ~= "classic"
  box("fill", x, y, w, h, modern and selected and THEME.red
    or selected and render.DARK or render.MID)
  outline(x, y, w, h, modern and THEME.blue or render.INK)
  if modern and selected then
    box("fill", x + 2, y + 2, 2, math.max(1, h - 4), THEME.white)
  end
  local c = modern and selected and THEME.white
    or selected and render.PAPER or render.INK
  local shown = fit(label, math.floor((w - 8) / 6))
  text(shown, x + math.max(4,
       math.floor((w - #glyphList(shown) * 6) / 2)),
       y + math.floor((h - 7) / 2), c)
end

local function inside(x, y, left, top, width, height)
  return x >= left and x < left + width and y >= top and y < top + height
end

THEME.gen2Badges = {
  johto = { "ZEPHYR", "HIVE", "PLAIN", "FOG", "STORM", "MINERAL",
    "GLACIER", "RISING" },
  kanto = { "BOULDER", "CASCADE", "THUNDER", "RAINBOW", "SOUL", "MARSH",
    "VOLCANO", "EARTH" },
  oam = { ZEPHYR = 1, HIVE = 2, PLAIN = 3, FOG = 4, MINERAL = 5,
    STORM = 6, GLACIER = 7, RISING = 8 },
}
  return button, centered, expBar, hpBar, inside, outline, text
end
