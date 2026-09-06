local Fonts = assert(loadfile("mod/kanto_gear/translation_fonts.lua"))()
local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local calls, reads, warnings = {}, 0, 0
local function font(kind, size)
  return {
    kind = kind, size = size,
    setFilter = function() end,
    release = function(self) self.released = true end,
    getHeight = function(self) return self.size end,
    getWidth = function(self, value) return #value * self.size end,
    hasGlyphs = function(self, value)
      if value == "☄" or value:find("%c") then return false end
      if self.kind == "base" then return not value:find("[\128-\255]") end
      if self.kind == "game" then return value == "MOD TEXT é" end
      if self.kind == "ja" then return not value:find("№", 1, true) end
      return true
    end,
  }
end
local G = {
  newFont = function(file, size)
    calls[#calls + 1] = { file = file, size = size }
    if file == "broken" then error("missing font") end
    return font(file:find("fonts/ja/", 1, true) and "ja"
      or file:find("fonts/ko/", 1, true) and "ko" or "game", size)
  end,
}
local base = font("base", 12)
local fonts = Fonts.new(G, function() warnings = warnings + 1 end, function(name)
  reads = reads + 1
  return name
end)
eq(#calls, 0, "constructor does not load font files")
eq(fonts:select(base, "PARTY 123"), base, "Latin keeps the image font")
eq(fonts:select(base, "PARTY\nHP 123\t"), base, "line breaks never trigger a font fallback")
eq(reads, 0, "Latin does not read bundled assets")
local japanese = fonts:select(base, "漢字")
eq(japanese.kind, "ja", "Japanese works without a translation mod")
eq(japanese.size, 8, "Japanese keeps its native pixel grid")
eq(fonts:select(base, "漢字\n図鑑"), japanese, "Japanese multiline text uses the same font")
eq(reads, 1, "first Japanese text reads one font")
for i = 1, 100 do eq(fonts:select(base, "漢字"), japanese, "repeated text reuses font") end
eq(reads, 1, "repeated drawing never reads the asset again")
local korean = fonts:select(base, "한국어")
eq(korean.kind, "ko", "Hangul selects Korean even though Japanese also has Hangul glyphs")
eq(korean.size, 10, "Korean keeps its native pixel grid")
eq(fonts:select(base, "ㄱㅏ").kind, "ko", "compatibility Jamo selects Korean")
eq(fonts:select(base, "가").kind, "ko", "decomposed Jamo selects Korean")
eq(fonts:select(base, "ID№123"), korean, "missing Japanese symbol uses a covering font")
eq(fonts:select(base, "漢字 ID№123"), korean, "mixed text stays in a font covering the whole string")
eq(fonts:select(base, "☄"), base, "unsupported characters fail safely")
eq(fonts:select(font("base", 24), "漢字").size, 16, "large Japanese labels use integer scaling")
eq(fonts:select(font("base", 24), "한국어").size, 20, "large Korean labels use integer scaling")
eq(fonts:bind({ file = "game", size = 10 }), true, "a game font can be bound")
local gameFont = fonts:select(base, "MOD TEXT é")
eq(gameFont.kind, "game", "game font retains priority when it covers the text")
eq(fonts:select(base, "漢字"), japanese, "a Latin game font cannot block Japanese")
eq(fonts:select(base, "한국어"), korean, "a Latin game font cannot block Korean")
eq(fonts:bind({ file = "game", size = 10 }), false, "unchanged game font does not reset caches")
eq(fonts:bind(nil), true, "switching games clears the registered font")
eq(gameFont.released, true, "old game font is released")
eq(fonts:select(base, "漢字"), japanese, "bundled font survives game switches")
eq(japanese.released, nil, "bundled cache is independent of game fonts")
eq(next(fonts.variants), nil, "old game cache is empty")
fonts:bind({ file = "broken", size = 10 })
eq(fonts:select(base, "漢字"), japanese, "broken game font still permits bundled fallback")
eq(fonts:select(base, "漢字"), japanese, "broken file is not retried on each draw")
eq(warnings, 1, "broken game font warns once")
local selected, printed = base, nil
G.getFont = function() return selected end
G.setFont = function(value) selected = value end
G.printf = function(value, x, y, width, align)
  printed = { font = selected, value = value, y = y, width = width, align = align }
end
fonts:print(base, "漢字", 0, 10, 100, "center")
eq(printed.font, japanese, "drawing uses the same covering font")
eq(fonts:width(base, "漢字"), japanese:getWidth("漢字"), "measurement matches drawing")
eq(printed.value, "漢字", "rendering never rewrites translated text")
eq(printed.y, 12, "font height is centered against the base font")
eq(printed.width, 100, "wrapping retains the container width")
eq(selected, base, "printing restores the previous graphics font")
print(checks .. " checks passed (bundled translation fonts)")
