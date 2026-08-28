package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_ROOT")):gsub("\\", "/")
local run = T.sdk.loadMods({
  "mod/kanto_gear",
  "translations/kanto_gear_es",
}, { root = root, data = T.fixtures.load(), generation = 2 })
local function kg(source)
  return run.data.strings["kanto_gear|" .. source]
end

T.eq(#run.errors, 0,
  "Kanto Gear and the Spanish companion mod load together under Gold")
T.eq(kg("START GAME"), "INICIAR JUEGO",
  "companion mod registers Kanto Gear text")
T.eq(kg("NEW GAME"), "NUEVA PARTIDA",
  "companion mod translates the mirrored title menu")
T.eq(kg("OPTION"), "OPCIONES",
  "companion mod translates the title options row")
T.eq(kg("EXIT GAME"), "SALIR DEL JUEGO",
  "companion mod translates the title exit row")
T.eq(run.data.strings["START GAME"], nil,
  "companion mod does not translate matching host text")
T.eq(kg("DEALS %d FIXED DAMAGE"),
  "CAUSA %d DE DAÑO FIJO",
  "companion mod registers formatted move details")
T.eq(kg("CANCEL"), "CANCELAR",
  "companion mod translates Gold menu actions")
T.eq(kg("JOHTO MAP"), "JOHTO",
  "companion mod translates Gold map headings")
T.eq(kg("BATTLE VIEW"), "VISTA DE COMBATE",
  "companion mod translates Kanto Gear settings")
T.eq(kg("CLOCK"), "RELOJ",
  "companion mod translates the clock source")
T.eq(kg("ENEMY INFO"), "INFO. RIVAL",
  "companion mod translates enemy information")
T.eq(kg("WEIGHT %.1f KG"), "PESO %.1f KG",
  "companion mod translates Pokedex details")
T.eq(kg("DISPLAY LAYOUT"), "DISEÑO DE PANTALLA",
  "companion mod translates the single-window layout")
T.eq(kg("SCREEN SWAP (Y)"), "INTERCAMBIAR PANT. (Y)",
  "companion mod translates optional screen swapping")

run.release()
T.finish("Kanto Gear Spanish integration")
