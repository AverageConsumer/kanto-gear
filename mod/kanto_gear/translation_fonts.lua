-- Keep Gear's image fonts for covered text; translated scripts use the font
-- registered by the active game, then Gear's bundled Japanese/Korean fonts.
-- ImageFont/TrueType cannot use setFallbacks; measure and draw the same font.
local Fonts = {}
Fonts.__index = Fonts

function Fonts.new(graphics, warn, readBundled)
  return setmetatable({ graphics = graphics, warn = warn, variants = {},
    readBundled = readBundled,
    bundled = {
      ja = { file = "fonts/ja/fusion-pixel-8px-proportional-ja.ttf", size = 8, variants = {} },
      ko = { file = "fonts/ko/fusion-pixel-10px-proportional-ko.ttf", size = 10, variants = {} },
    },
  }, Fonts)
end

function Fonts:bind(def)
  local file = type(def) == "table" and def.file or nil
  local size = type(def) == "table" and tonumber(def.size) or nil
  size = math.max(1, math.min(64, size or 15))
  if self.file == file and self.size == size then return false end
  for _, font in pairs(self.variants) do if font.release then font:release() end end
  self.file, self.size, self.variants, self.failed = file, size, {}, false
  return true
end

-- Hangul syllables and Jamo are three-byte UTF-8 sequences. Choose the
-- Korean pixel grid for the bundled fallback when a game font cannot cover them.
local function hasHangul(value)
  for a, b, c in value:gmatch("([\224-\239])([\128-\191])([\128-\191])") do
    local code = (a:byte() - 224) * 4096 + (b:byte() - 128) * 64 + c:byte() - 128
    if code >= 0xAC00 and code <= 0xD7AF or code >= 0x1100 and code <= 0x11FF
        or code >= 0x3130 and code <= 0x318F or code >= 0xA960 and code <= 0xA97F
        or code >= 0xD7B0 and code <= 0xD7FF then return true end
  end
  return false
end

function Fonts:loadFont(source, multiplier)
  local font = source.variants[multiplier]
  if not font and source.file and not source.failed then
    local ok, result = pcall(function()
      local file = source == self and source.file or self.readBundled(source.file)
      return self.graphics.newFont(file, source.size * multiplier, "mono", 1)
    end)
    if ok then
      font = result; font:setFilter("nearest", "nearest"); source.variants[multiplier] = font
    else
      source.failed = true
      if self.warn then self.warn("Translation font could not be loaded: " .. tostring(result)) end
    end
  end
  return font
end

function Fonts:select(base, value)
  value = tostring(value or "")
  -- Line breaks are layout commands, not missing font glyphs.
  local glyphs = value:gsub("%c", "")
  if glyphs == "" or not base.hasGlyphs or base:hasGlyphs(glyphs) then return base, 0 end
  local multiplier = base:getHeight() >= 20 and 2 or 1
  local font = self:loadFont(self, multiplier)
  if self.readBundled and (not font or not font:hasGlyphs(glyphs)) then
    local first, second = "ja", "ko"
    if hasHangul(value) then first, second = second, first end
    for _, language in ipairs({ first, second }) do
      local candidate = self:loadFont(self.bundled[language], multiplier)
      if candidate and candidate:hasGlyphs(glyphs) then font = candidate; break end
    end
  end
  if not font then return base, 0 end
  return font, math.floor((base:getHeight() - font:getHeight()) / 2)
end

function Fonts:width(base, value)
  local font = self:select(base, value)
  return font:getWidth(tostring(value or ""))
end

function Fonts:print(base, value, x, y, width, align)
  local font, offset = self:select(base, value)
  local G, previous = self.graphics, self.graphics.getFont()
  G.setFont(font)
  if width then G.printf(tostring(value or ""), x, y + offset, width, align or "left")
  else G.print(tostring(value or ""), x, y + offset) end
  if previous then G.setFont(previous) end
end

return Fonts
