-- Real LÖVE font coverage, measurement and raster checks. No game is opened.
return function(root, fonts, faces, atlas, H)
  local function module(name, ...)
    return assert(loadfile(root .. "/mod/kanto_gear/" .. name .. ".lua"))()(...)
  end
  local core = module("core/init", module)
  local checks = 0
  local G, original = love.graphics, H.partyInfo
  local canvas = G.newCanvas(112, 80, { dpiscale = 1 })
  local function statBounds(power, accuracy)
    local spans = {}
    H.partyInfo = function(self, value, x, y, tint, width, align)
      if y == 38 then
        local size = self:partyInfoWidth(value)
        local left = x + (align == "right" and width - size or 0)
        spans[#spans + 1] = { left, left + size, value }
      end
      return original(self, value, x, y, tint, width, align)
    end
    G.push("all"); G.setCanvas(canvas); G.origin(); G.clear()
    H:battleMoveCard({ name = "FERRÃO VENENOSO", type = "NORMAL", ppText = "35/35",
      powerLabel = power, accuracyLabel = accuracy, powerText = "999", accuracyText = "100" }, 0, 0, false, false)
    G.pop(); H.partyInfo = original
    assert(#spans == 4, "stat row records both labels and values")
    if H:partyInfoWidth(power) <= 25 then
      assert(H:v4Cased(spans[1][3]) == H:v4Cased(power), "fitting lost power label: " .. spans[1][3])
    end
    if H:partyInfoWidth(accuracy) <= 27 then
      assert(H:v4Cased(spans[2][3]) == H:v4Cased(accuracy), "fitting lost accuracy label: " .. spans[2][3])
    end
    assert(spans[1][1] >= 10 and spans[1][2] <= spans[3][1] - 2 and spans[3][2] == 52,
      "power label must leave its value and two-pixel gap clear")
    assert(spans[2][1] >= 59 and spans[2][2] <= spans[4][1] - 2 and spans[4][2] == 103,
      "accuracy label must leave its value and two-pixel gap clear")
    checks = checks + 2
  end
  local function covered(value)
    for _, face in ipairs(faces) do
      local selected = fonts:select(face, value)
      assert(selected:hasGlyphs((value:gsub("%c", ""))), "missing rendered glyph: " .. value)
      assert(fonts:width(face, value) == selected:getWidth(value), "measurement uses another font")
      checks = checks + 1
    end
  end
  for _, face in ipairs(faces) do assert(face:hasGlyphs(atlas), "atlas and glyph map disagree") end
  for _, code in ipairs({ "de", "es", "fr", "it", "ja" }) do
    local catalog = assert(loadfile(root .. "/mod/kanto_gear/i18n/catalogs/" .. code .. ".lua"))()
    assert(fonts:width(faces[2], H.v4Title(catalog.ACC)) <= 27,
      code .. " accuracy abbreviation overlaps three-digit values")
    statBounds(catalog.PWR, catalog.ACC)
    for key, value in pairs(catalog) do
      covered(key) -- English, including explicit translation fallbacks
      if type(value) == "string" then
        covered(value)
        covered(H.v4Title(value))
        covered(core.normalize(value))
      end
    end
  end
  statBounds("EXTERNAL TRANSLATION POWER", "めいちゅうりつ")
  canvas:release()
  for _, value in ipairs({ "ÃÕãõ ÄÖäö", "FERRÃO VENENOSO", "Ferrão Venenoso",
      "CANÇÕES E AÇÕES", "CŒUR D’OR", "ŁÓDŹ ŘEKA ȘARPE", "피카츄", "皮卡丘", "ПИКАЧУ" }) do
    covered(value); covered(H.v4Title(value)); covered(core.normalize(value))
  end
  print(checks .. " real font coverage/measurement checks passed")
end
