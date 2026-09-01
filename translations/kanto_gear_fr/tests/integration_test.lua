package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_ROOT")):gsub("\\", "/")
local run = T.sdk.loadMods({
  "mod/kanto_gear",
  "translations/kanto_gear_fr",
}, { root = root, data = T.fixtures.load(), generation = 2 })
local function kg(source)
  return run.data.strings["kanto_gear|" .. source]
end

T.eq(#run.errors, 0,
  "Kanto Gear and the French companion mod load together under Gold")
T.eq(kg("START GAME"), "COMMENCER",
  "companion mod registers Kanto Gear text")
T.eq(kg("NEW GAME"), "NOUVELLE PARTIE",
  "companion mod translates the mirrored title menu")
T.eq(kg("OPTION"), "OPTIONS",
  "companion mod translates the title options row")
T.eq(kg("EXIT GAME"), "QUITTER LE JEU",
  "companion mod translates the title exit row")
T.eq(run.data.strings["START GAME"], nil,
  "companion mod does not translate matching host text")
T.eq(kg("DEALS %d FIXED DAMAGE"),
  "DÉGÂTS FIXES : %d",
  "companion mod registers formatted move details")
T.eq(kg("CANCEL"), "ANNULER",
  "companion mod translates Gold menu actions")
T.eq(kg("JOHTO MAP"), "JOHTO",
  "companion mod translates Gold map headings")
T.eq(kg("BATTLE VIEW"), "VUE COMBAT",
  "companion mod translates Kanto Gear settings")
T.eq(kg("CLOCK"), "HORLOGE",
  "companion mod translates the clock source")
T.eq(kg("CLOCK SOURCE"), "SOURCE HORLOGE",
  "companion mod labels the clock source unambiguously")
T.eq(kg("TRANSITIONS"), "TRANSITIONS",
  "companion mod labels HGSS transitions unambiguously")
T.eq(kg("HGSS AUTO"), "HGSS AUTO",
  "automatic HGSS theme stays compact")
T.eq(kg("ENEMY INFO"), "INFOS ENNEMI",
  "companion mod translates enemy information")
T.eq(kg("WEIGHT %.1f KG"), "POIDS %.1f KG",
  "companion mod translates Pokedex details")
T.eq(kg("DISPLAY LAYOUT"), "DISPOSITION DES ÉCRANS",
  "companion mod translates the single-window layout")
T.eq(kg("SCREEN SWAP (Y)"), "ÉCHANGE ÉCRANS (Y)",
  "companion mod translates optional screen swapping")
T.eq(kg("TAP ANYWHERE / A"), "TOUCHER PARTOUT / A",
  "companion mod translates the HGSS battle prompt")
T.eq(kg("TAP TO CONTINUE"), "TOUCHER POUR AVANCER",
  "companion mod keeps the legacy continue prompt concise")
T.eq(kg("NEED ITEMFINDER"), "CHERCH'OBJET REQUIS",
  "companion mod uses the game-faithful Itemfinder label")
T.eq(kg("NO %s"), "AUCUN %s",
  "companion mod keeps empty-section labels grammatical")
T.eq(kg("NO ITEMS"), "AUCUN OBJET",
  "empty item sections use a complete grammatical translation")
T.eq(kg("BOX %d"), "BOÎTE %d",
  "companion mod translates generated PC box names")
T.eq(kg("MOVE WITHOUT MAIL"), "DÉPLACER SANS LETTRE",
  "companion mod translates the full Gen 2 PC action")
T.eq(kg("DEPOSIT ITEM"), "DÉPOSER OBJET",
  "companion mod translates the Item PC deposit heading")
T.eq(kg("NO DETAILS AVAILABLE"), "AUCUN DÉTAIL DISPO",
  "companion mod keeps missing-detail text concise")

run.release()
T.finish("Kanto Gear French integration")
