return function(THEME, render)
local FONT = {
  A="01110100011000111111100011000110001", B="11110100011000111110100011000111110",
  C="01111100001000010000100001000001111", D="11110100011000110001100011000111110",
  E="11111100001000011110100001000011111", F="11111100001000011110100001000010000",
  G="01111100001000010111100011000101110", H="10001100011000111111100011000110001",
  I="11111001000010000100001000010011111", J="00111000100001000010100101001001100",
  K="10001100101010011000101001001010001", L="10000100001000010000100001000011111",
  M="10001110111010110101100011000110001", N="10001110011010110011100011000110001",
  O="01110100011000110001100011000101110", P="11110100011000111110100001000010000",
  Q="01110100011000110001101011001001101", R="11110100011000111110101001001010001",
  S="01111100001000001110000010000111110", T="11111001000010000100001000010000100",
  U="10001100011000110001100011000101110", V="10001100011000110001100010101000100",
  W="10001100011000110101101011101110001", X="10001100010101000100010101000110001",
  Y="10001100010101000100001000010000100", Z="11111000010001000100010001000011111",
  ["0"]="01110100011001110101110011000101110",
  ["1"]="00100011000010000100001000010001110",
  ["2"]="01110100010000100010001000100011111",
  ["3"]="11110000010000101110000010000111110",
  ["4"]="00010001100101010010111110001000010",
  ["5"]="11111100001000011110000010000111110",
  ["6"]="01110100001000011110100011000101110",
  ["7"]="11111000010001000100010000100001000",
  ["8"]="01110100011000101110100011000101110",
  ["9"]="01110100011000101111000010000101110",
  [":"]="00000001000010000000001000010000000",
  ["."]="00000000000000000000000000000000100",
  [","]="00000000000000000000000000010001000",
  ["'"]="00100001000000000000000000000000000",
  ["("]="00010001000100001000010000010000010",
  [")"]="01000001000001000010000100010001000",
  ["-"]="00000000000000011111000000000000000",
  ["/"]="00001000100010001000100001000000000",
  ["+"]="00000001000010011111001000010000000",
  ["%"]="11001110100010001000101101100100000",
  ["?"]="01110100010001000100001000000000100",
  ["<"]="00010001000100010000010000010000010",
  [">"]="01000001000001000001000100010001000",
  ["!"]="00100001000010000100001000000000100",
  ["Ä"]="10001000000111010001111111000110001",
  ["Ö"]="10001000000111010001100011000101110",
  ["Ü"]="10001000001000110001100011000101110",
  ["À"]="01000001000111010001111111000110001",
  ["Â"]="00100010100111010001111111000110001",
  ["Ç"]="01111100001000010000100000111000100",
  ["Á"]="00010001000111010001111111000110001",
  ["È"]="01000001001111110000111101000011111",
  ["É"]="00010001001111110000111101000011111",
  ["Ê"]="00100010101111110000111101000011111",
  ["Ë"]="01010000001111110000111101000011111",
  ["Í"]="00010001001111100100001000010011111",
  ["Ì"]="01000001001111100100001000010011111",
  ["Î"]="00100010101111100100001000010011111",
  ["Ï"]="01010000001111100100001000010011111",
  ["Ó"]="00010001000111010001100011000101110",
  ["Ò"]="01000001000111010001100011000101110",
  ["Ô"]="00100010100111010001100011000101110",
  ["Ú"]="00010001001000110001100011000101110",
  ["Ù"]="01000001001000110001100011000101110",
  ["Û"]="00100010101000110001100011000101110",
  ["Ÿ"]="01010000001000101010001000010000100",
  ["Ñ"]="01010101001000111001101011001110001",
  ["¿"]="00100000000010000100010001000101110",
  ["¡"]="00100000000010000100001000010000100",
  ["="]="00000000001111100000111110000000000",
  ["°"]="01100100101001001100000000000000000",
  ["º"]="01100100101001001100000000111100000",
  ["¥"]="10001010100010011111001001111100100",
}

local function color(c) render.G.setColor(c[1], c[2], c[3], c[4]) end

local function box(mode, x, y, w, h, c)
  color(c)
  render.G.rectangle(mode, x, y, w, h)
end

local function glyphList(value)
  local out, index = {}, 1
  while index <= #value do
    local first = value:byte(index)
    local size = first < 0x80 and 1 or first < 0xE0 and 2
      or first < 0xF0 and 3 or 4
    out[#out + 1] = value:sub(index, index + size - 1)
    index = index + size
  end
  return out
end

local function normalize(value)
  value = value:upper()
    :gsub("ä", "Ä"):gsub("ö", "Ö"):gsub("ü", "Ü")
    :gsub("ẞ", "SS"):gsub("ß", "SS")
    :gsub("à", "À"):gsub("â", "Â"):gsub("ç", "Ç")
    :gsub("è", "È"):gsub("ê", "Ê"):gsub("ë", "Ë")
    :gsub("ì", "Ì"):gsub("ò", "Ò")
    :gsub("î", "Î"):gsub("ï", "Ï"):gsub("ô", "Ô")
    :gsub("ù", "Ù"):gsub("û", "Û"):gsub("ÿ", "Ÿ")
    :gsub("á", "Á"):gsub("é", "É"):gsub("í", "Í")
    :gsub("ó", "Ó"):gsub("ú", "Ú"):gsub("ñ", "Ñ")
    :gsub("_", " ")
  local out = {}
  for _, glyph in ipairs(glyphList(value)) do
    if glyph == " " or FONT[glyph] or #glyph > 1 then out[#out + 1] = glyph end
  end
  return table.concat(out)
end

local function clean(value)
  value = tostring(value or ""):gsub("<PK><MN>", "PKMN")
  return normalize(value)
end

THEME.bitmapFont = {
  hasGlyphs = function(_, value)
    for _, glyph in ipairs(glyphList(value)) do
      if glyph ~= " " and not FONT[glyph] then return false end
    end
    return true
  end,
  getHeight = function() return 7 end,
  getWidth = function(_, value) return #glyphList(value) * 6 end,
}

function THEME:textWidth(value)
  if self.translationFonts then return self.translationFonts:width(self.bitmapFont, value) end
  return self.bitmapFont:getWidth(value)
end

local function fit(value, chars, ellipsis)
  value = clean(value)
  local width = math.max(0, chars) * 6
  if THEME:textWidth(value) <= width then return value end
  local glyphs, suffix = glyphList(value), ellipsis == false and "" or "."
  while #glyphs > 0 do
    table.remove(glyphs)
    local shown = table.concat(glyphs) .. suffix
    if THEME:textWidth(shown) <= width then return shown end
  end
  return ""
end

function THEME:wrapText(message, width, limit, measure)
  measure = measure or function(value) return self:textWidth(value) end
  local lines, current = {}, ""
  local source = clean(tostring(message or ""):gsub("[\r\n\t]", " "))
  for word in source:gmatch("%S+") do
    local joined = current == "" and word or current .. " " .. word
    if measure(joined) <= width then current = joined
    else
      if current ~= "" then lines[#lines + 1] = current end
      current = ""
      for _, glyph in ipairs(glyphList(word)) do
        if current ~= "" and measure(current .. glyph) > width then
          lines[#lines + 1], current = current, ""
        end
        current = current .. glyph
      end
    end
  end
  if current ~= "" then lines[#lines + 1] = current end
  if limit and #lines > limit then
    local chars = glyphList(lines[limit])
    while #chars > 0 and measure(table.concat(chars) .. ".") > width do table.remove(chars) end
    lines[limit] = table.concat(chars) .. "."
    for i = #lines, limit + 1, -1 do lines[i] = nil end
  end
  return lines
end

function THEME:descriptionLines(source, chars, limit, hgssWidth)
  source = tostring(source or ""):gsub("<PK><MN>", "PKMN")
    :gsub("<[^>]+>", " "):gsub("[%s@]+", " ")
  if self.style == "hgss" and hgssWidth then
    return self:wrapText(source, hgssWidth, limit,
      function(value) return self.hgss:partyInfoWidth(value) end)
  end
  return self:wrapText(source, chars * 6, limit)
end

function THEME:pokedexDescriptionLines(source)
  local function wrap() return self:descriptionLines(source, 24, nil, 204) end
  if self.style == "hgss" and self.hgss.v4Prose then
    return self.hgss:v4Prose(wrap)
  end
  return wrap()
end

function THEME:messageLines(messages, chars, limit)
  limit = limit or 2
  local count, out = #(messages or {}), {}
  local latest = self:wrapText(messages and messages[count], chars * 6)
  if #latest > 1 then
    for index = 1, math.min(#latest, limit) do out[index] = latest[index] end
    if latest[limit + 1] then
      out[limit] = fit(out[limit] .. " " .. latest[limit + 1], chars)
    end
    return out
  end
  for index = math.max(1, count - limit + 1), count do
    local lines = self:wrapText(messages[index], chars * 6)
    out[#out + 1] = fit(lines[#lines] or "", chars)
  end
  return out
end

local function methodLines(methods)
  local lines = { "" }
  for _, odds in ipairs(methods) do
    local chance = odds.min == odds.max and tostring(odds.min)
      or (odds.min .. "-" .. odds.max)
    local label = THEME:translate(odds.name)
    local chanceText = chance .. "%"
    local method = THEME:format("%s %s", label, chanceText)
    local joined = lines[#lines] == "" and method
      or lines[#lines] .. "/" .. method
    if #glyphList(clean(joined)) <= 14 then
      lines[#lines] = joined
    elseif lines[#lines] == "" then
      lines[#lines] = fit(label, 14)
      lines[#lines + 1] = chanceText
    elseif #lines < 2 then
      if #glyphList(clean(method)) <= 14 then
        lines[#lines + 1] = method
      else
        local labelChars = 13 - #glyphList(chanceText)
        lines[#lines + 1] = fit(label, labelChars) .. " " .. chanceText
      end
    end
  end
  return lines[1] or "", lines[2] or ""
end
  return FONT, box, clean, color, fit, glyphList, methodLines, normalize
end
