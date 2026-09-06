-- Keep Gear's image fonts for covered text; translated scripts use the font
-- registered by the active game. ImageFont/TrueType cannot use setFallbacks.
local Fonts = {}
Fonts.__index = Fonts

function Fonts.new(graphics, warn)
  return setmetatable({ graphics = graphics, warn = warn, variants = {} }, Fonts)
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

function Fonts:select(base, value)
  value = tostring(value or "")
  if not self.file or value == "" or not base.hasGlyphs or base:hasGlyphs(value) then return base, 0 end
  local multiplier = base:getHeight() >= 20 and 2 or 1
  local font = self.variants[multiplier]
  if not font and not self.failed then
    local ok, result = pcall(self.graphics.newFont, self.file, self.size * multiplier, "mono", 1)
    if ok then
      font = result; font:setFilter("nearest", "nearest"); self.variants[multiplier] = font
    else
      self.failed = true
      if self.warn then self.warn("Translation font could not be loaded: " .. tostring(result)) end
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
