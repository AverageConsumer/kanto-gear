package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_ROOT")):gsub("\\", "/")
local run = T.sdk.loadMods({
  "mod/kanto_gear",
  "translations/kanto_gear_de",
}, { root = root, data = T.fixtures.load(), generation = 2 })
local function kg(source)
  return run.data.strings["kanto_gear|" .. source]
end

T.eq(#run.errors, 0,
  "Kanto Gear und deutsche Begleitmod laden gemeinsam unter Gold")
T.eq(kg("START GAME"), "SPIEL STARTEN",
  "Begleitmod registriert eigene Kanto-Gear-Texte")
T.eq(kg("NEW GAME"), "NEUES SPIEL",
  "Begleitmod übersetzt das gespiegelte Titelmenü")
T.eq(kg("OPTION"), "OPTIONEN",
  "Begleitmod übersetzt die Titeloptionen")
T.eq(kg("EXIT GAME"), "SPIEL BEENDEN",
  "Begleitmod übersetzt das Beenden im Titelmenü")
T.eq(run.data.strings["START GAME"], nil,
  "Begleitmod verändert gleich benannten Host-Text nicht")
T.eq(kg("DEALS %d FIXED DAMAGE"),
  "MACHT %d FESTSCHADEN",
  "Begleitmod registriert formatierte Attackendetails")
T.eq(kg("CANCEL"), "ABBRUCH",
  "Begleitmod übersetzt Gold-Menüaktionen")
T.eq(kg("JOHTO MAP"), "JOHTO",
  "Begleitmod übersetzt Gold-Kartenüberschriften")
T.eq(kg("BATTLE VIEW"), "KAMPFANSICHT",
  "Begleitmod übersetzt Kanto-Gear-Einstellungen")
T.eq(kg("CLOCK"), "UHR",
  "Begleitmod übersetzt die Zeitquelle")
T.eq(kg("CLOCK SOURCE"), "UHRQUELLE",
  "Begleitmod benennt die Zeitquelle eindeutig")
T.eq(kg("TRANSITIONS"), "ÜBERGÄNGE",
  "Begleitmod benennt die HGSS-Übergänge eindeutig")
T.eq(kg("HGSS AUTO"), "HGSS AUTO",
  "automatisches HGSS-Theme bleibt kompakt")
T.eq(kg("ENEMY INFO"), "GEGNER-INFO",
  "Begleitmod übersetzt die Gegnerinformation")
T.eq(kg("WEIGHT %.1f KG"), "GEWICHT %.1f KG",
  "Begleitmod übersetzt die Pokédex-Details")
T.eq(kg("DISPLAY LAYOUT"), "ANZEIGELAYOUT",
  "Begleitmod übersetzt das Ein-Fenster-Layout")

T.eq(kg("SCREEN SWAP (Y)"), "SCREEN-TAUSCH (Y)",
  "Begleitmod übersetzt den optionalen Bildschirmtausch")
T.eq(kg("TAP ANYWHERE / A"), "ÜBERALL TIPPEN / A",
  "Begleitmod übersetzt den HGSS-Kampfhinweis")

run.release()
T.finish("Kanto Gear Deutsch integration")
