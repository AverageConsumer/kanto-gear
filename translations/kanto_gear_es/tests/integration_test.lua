package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_ROOT")):gsub("\\", "/")
local run = T.sdk.loadMods({
  "mod/kanto_gear",
  "translations/kanto_gear_es",
}, { root = root, data = T.fixtures.load(), generation = 2 })

T.eq(#run.errors, 0,
  "Kanto Gear and the Spanish companion mod load together under Gold")
T.eq(run.data.strings["START GAME"], "INICIAR JUEGO",
  "companion mod registers Kanto Gear text")
T.eq(run.data.strings["DEALS %d FIXED DAMAGE"],
  "CAUSA %d DE DAÑO FIJO",
  "companion mod registers formatted move details")
T.eq(run.data.strings["CANCEL"], "CANCELAR",
  "companion mod translates Gold menu actions")
T.eq(run.data.strings["JOHTO MAP"], "JOHTO",
  "companion mod translates Gold map headings")
T.eq(run.data.strings["BATTLE VIEW"], "VISTA DE COMBATE",
  "companion mod translates Kanto Gear settings")
T.eq(run.data.strings["CLOCK"], "RELOJ",
  "companion mod translates the clock source")
T.eq(run.data.strings["ENEMY INFO"], "INFO. RIVAL",
  "companion mod translates enemy information")
T.eq(run.data.strings["WEIGHT %.1f KG"], "PESO %.1f KG",
  "companion mod translates Pokedex details")
T.eq(run.data.strings["DISPLAY LAYOUT"], "DISEÑO DE PANTALLA",
  "companion mod translates the single-window layout")
T.eq(run.data.strings["SCREEN SWAP (Y)"], "INTERCAMBIAR PANT. (Y)",
  "companion mod translates optional screen swapping")

run.release()
T.finish("Kanto Gear Spanish integration")
