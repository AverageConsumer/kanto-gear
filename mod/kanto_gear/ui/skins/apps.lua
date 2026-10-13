-- Kanto Gear v4: bespoke app screens (Pokédex, Trainer Card, Step Counter).
return function(H, ui, K, read)
  local floor, max, min = math.floor, math.max, math.min
  local R, P, RR, RRrows, CH, CHrows = K.R, K.P, K.RR, K.RRrows, K.CH, K.CHrows
  local CIRC, CIRCrows, RING, ART = K.CIRC, K.CIRCrows, K.RING, K.ART
  local mix, hex = K.mix, K.hex
  local base, cg, WHITE = K.base, K.cg, K.WHITE
  local translate = function(value) return ui.translate and ui.translate(value) or value end
  local Dex = ui.pokedexPage

  local function box(self, x, y, w, h, fill, edge, radius)
    return self:v4Window(x, y, w, h, { fill = fill, edge = edge, radius = radius })
  end

  ---------------------------------------------------------------------------
  -- Pokédex
  ---------------------------------------------------------------------------
  local function install(name, ...)
    local path = "ui/skins/apps/" .. name .. ".lua"
    return assert(load(assert(read(path)), "@kanto_gear/" .. path))()(...)
  end
  local CARD_COLORS = install("dex", ART, CH, CIRC, CIRCrows, Dex, H, R, RR, WHITE, base, box, cg, floor, hex, max, min, mix, translate)
  install("trainer", ART, CARD_COLORS, CIRC, CIRCrows, H, K, P, R, RR, RRrows, WHITE, base, floor, hex, max, min, mix, translate, ui)
  local KEY_G, SILPH_LOGO, SILPH_RED = install("bag", CH, CIRC, H, K, R, RR, WHITE, cg, floor, hex, max, min, mix, translate, ui)
  local CAT_GLYPH = install("store", ART, CH, CIRC, H, K, KEY_G, R, RING, RR, SILPH_LOGO, SILPH_RED, WHITE, cg, floor, hex, max, min, mix, translate, ui)
  install("settings", ART, CAT_GLYPH, CH, CIRC, H, K, R, RR, RRrows, WHITE, base, cg, floor, hex, max, min, mix, translate, ui)
end
