-- Kanto Gear v4: native menu companions — start menu with real icons,
-- choice prompts as Gen 4 touch buttons. Loaded after v4_menus.
return function(H, ui, K, read)
  local floor, max, min = math.floor, math.max, math.min
  local R, P, RR, RRrows, CH, CHrows = K.R, K.P, K.RR, K.RRrows, K.CH, K.CHrows
  local CIRC, RING, ART = K.CIRC, K.RING, K.ART
  local mix, hex = K.mix, K.hex
  local cg, WHITE = K.cg, K.WHITE
  local translate = function(value) return ui.translate and ui.translate(value) or value end

  ---------------------------------------------------------------------------
  -- Start menu icons (≤ 15×13, o = outline)
  ---------------------------------------------------------------------------
  local function install(name, ...)
    local path = "ui/skins/native/" .. name .. ".lua"
    return assert(load(assert(read(path)), "@kanto_gear/" .. path))()(...)
  end
  local TONES = install("menus", ART, CH, CIRC, H, K, P, R, RR, WHITE, cg, floor, hex, min, mix, translate, ui)
  local BOOK_G, FLAG_G = install("notes", ART, CH, CIRC, H, K, R, RING, RR, TONES, WHITE, cg, floor, hex, mix, translate, ui)
  install("social", ART, BOOK_G, CH, CIRC, FLAG_G, H, K, R, RING, RR, TONES, WHITE, cg, floor, hex, max, min, mix, translate, ui)
  local DOWN, PG_TINT, UP, wrapLabel = install("items", ART, CIRC, H, K, WHITE, cg, floor, hex, min, mix, translate, ui)
  install("pokegear", ART, CH, CIRC, DOWN, H, K, PG_TINT, R, RR, UP, WHITE, cg, floor, hex, max, min, mix, translate, ui, wrapLabel)
end
