package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_ROOT")):gsub("\\", "/")
local run = T.sdk.loadMods({
  "mod/kanto_gear",
  "translations/kanto_gear_de",
}, { root = root, data = T.fixtures.load(), generation = 2 })

T.eq(#run.errors, 0,
  "Kanto Gear und deutsche Begleitmod laden gemeinsam unter Gold")
T.eq(run.data.strings["START GAME ABOVE"], "SPIEL OBEN STARTEN",
  "Begleitmod registriert eigene Kanto-Gear-Texte")
T.eq(run.data.strings["DEALS %d FIXED DAMAGE"],
  "MACHT %d FESTSCHADEN",
  "Begleitmod registriert formatierte Attackendetails")
T.eq(run.data.strings["CANCEL"], "ABBRUCH",
  "Begleitmod übersetzt Gold-Menüaktionen")
T.eq(run.data.strings["JOHTO MAP"], "JOHTO-KARTE",
  "Begleitmod übersetzt Gold-Kartenüberschriften")
T.eq(run.data.strings["BATTLE VIEW"], "KAMPFANSICHT",
  "Begleitmod übersetzt Kanto-Gear-Einstellungen")

T.eq(run.data.strings["SCREEN SWAP (Y)"], "SCREEN-TAUSCH (Y)",
  "Begleitmod übersetzt den optionalen Bildschirmtausch")

run.release()
T.finish("Kanto Gear Deutsch integration")
