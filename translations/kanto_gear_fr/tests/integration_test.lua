package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_ROOT")):gsub("\\", "/")
local run = T.sdk.loadMods({
  "mod/kanto_gear",
  "translations/kanto_gear_fr",
}, { root = root, data = T.fixtures.load(), generation = 2 })

T.eq(#run.errors, 0,
  "Kanto Gear and the French companion mod load together under Gold")
T.eq(run.data.strings["START GAME"], "COMMENCER",
  "companion mod registers Kanto Gear text")
T.eq(run.data.strings["DEALS %d FIXED DAMAGE"],
  "DÉGÂTS FIXES : %d",
  "companion mod registers formatted move details")
T.eq(run.data.strings["CANCEL"], "ANNULER",
  "companion mod translates Gold menu actions")
T.eq(run.data.strings["JOHTO MAP"], "CARTE DE JOHTO",
  "companion mod translates Gold map headings")
T.eq(run.data.strings["BATTLE VIEW"], "VUE COMBAT",
  "companion mod translates Kanto Gear settings")
T.eq(run.data.strings["CLOCK"], "HORLOGE",
  "companion mod translates the clock source")
T.eq(run.data.strings["ENEMY INFO"], "INFOS ENNEMI",
  "companion mod translates enemy information")
T.eq(run.data.strings["WEIGHT %.1f KG"], "POIDS %.1f KG",
  "companion mod translates Pokedex details")
T.eq(run.data.strings["DISPLAY LAYOUT"], "DISPOSITION DES ÉCRANS",
  "companion mod translates the single-window layout")
T.eq(run.data.strings["SCREEN SWAP (Y)"], "ÉCHANGE ÉCRANS (Y)",
  "companion mod translates optional screen swapping")

run.release()
T.finish("Kanto Gear French integration")
