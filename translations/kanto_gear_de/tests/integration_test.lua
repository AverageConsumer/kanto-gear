package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_ROOT"))
local run = T.sdk.loadMods({
  root .. "/mod/kanto_gear",
  root .. "/translations/kanto_gear_de",
}, { data = T.fixtures.load() })

T.eq(#run.errors, 0,
  "Kanto Gear und deutsche Begleitmod laden gemeinsam")
T.eq(run.data.strings["START GAME ABOVE"], "SPIEL OBEN STARTEN",
  "Begleitmod registriert eigene Kanto-Gear-Texte")
T.eq(run.data.strings["DEALS %d FIXED DAMAGE"],
  "MACHT %d FESTSCHADEN",
  "Begleitmod registriert formatierte Attackendetails")

run.release()
T.finish("Kanto Gear Deutsch integration")
