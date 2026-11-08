local root = os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local function loadModule(path)
  return assert(loadfile(root .. "/" .. path))()
end

local passed, failed = 0, 0
local function check(condition, label)
  if condition then passed = passed + 1 return end
  failed = failed + 1
  io.stderr:write("FAIL " .. label .. "\n")
end

local catalogs = {}
for _, language in ipairs({ "de", "es", "fr", "ja", "it", "pt-BR" }) do
  catalogs[language] = loadModule("i18n/catalogs/" .. language .. ".lua")
end

local I18N = loadModule("i18n/init.lua")
local selected = "de"
local i18n = I18N.new(function(language) return catalogs[language] end,
  function() return selected end)

check(i18n:language() == "de", "explicit language is selected")
check(i18n:text("START GAME") == catalogs.de["START GAME"],
  "German catalog is used")
selected = "fr"
check(i18n:language() == "fr", "language changes without restarting")
check(i18n:format("SIGNALS %d", 3) == string.format(
  catalogs.fr["SIGNALS %d"], 3), "translated placeholders are formatted")
selected = "es"
check(i18n:language() == "es", "Spanish is supported")
selected = "it-IT"
check(i18n:language() == "it", "Italian locale resolves to its catalog")
check(i18n:text("HP") == "PS" and i18n:text("FIGHT") == "LOTTA"
  and i18n:text("BAG") == "BORSA" and i18n:text("RUN") == "FUGA",
  "Italian uses the familiar Pokemon battle terminology")
check(i18n:text("HIDDEN POWER") == "INTROFORZA"
  and i18n:text("TM/HM") == "MT/MN", "Italian move and machine names follow the games")
check(i18n:format("HP %d/%d", 12, 34) == "PS 12/34", "Italian format arguments survive")
check(i18n:text("OPEN APP") == "APRI" and i18n:text("OPEN") == "APERTO",
  "Italian distinguishes opening apps from unfinished tasks")
check(#i18n:coverage("it") == 0, "Italian battle labels have no fallback")
for _, locale in ipairs({ "pt-BR", "pt_br", "PT-br", "pt", "pt_BR.UTF-8" }) do
  selected = locale
  check(i18n:language() == "pt-BR", "Brazilian Portuguese locale resolves: " .. locale)
  check(i18n:text("LANGUAGE") == "IDIOMA" and i18n:text("BACK") == "VOLTAR",
    "Brazilian Portuguese UI uses the contributed catalog")
  check(i18n:format("HP %d/%d", 12, 34) == string.format(catalogs["pt-BR"]["HP %d/%d"], 12, 34),
    "Brazilian Portuguese format arguments survive")
end
selected = "pt-PT"
check(i18n:language() == "en", "European Portuguese does not select a different regional translation")
selected = "ja-JP"
check(i18n:language() == "ja", "Japanese locale resolves to its catalog")
check(i18n:text("START GAME") == catalogs.ja["START GAME"], "Japanese UI text comes from contributor catalog")
check(i18n:format("SIGNALS %d", 3) == string.format(catalogs.ja["SIGNALS %d"], 3), "Japanese format arguments survive")
check(i18n:text("NOTES") == "ノート", "Japanese Notes text comes from the completion contribution")
check(i18n:text("NEED HEADBUTT") == catalogs.ja["NEED HEADBUTT"], "Japanese habitat requirements use the completed catalog")
selected = "de"
check(i18n:text("START GAME") == catalogs.de["START GAME"], "switching back from Japanese restores German")
selected = "invalid"
check(i18n:language() == "en", "invalid selection falls back to English")
selected = "en"
check(i18n:text("PIKACHU") == "PIKACHU",
  "English UI keys are identity values")

local _, _, theme = loadModule("core/theme.lua")()
theme.i18n = i18n
local types = { "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BUG",
  "GHOST", "STEEL", "FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC", "ICE", "DRAGON", "DARK", "FAIRY" }
local statuses = { "SLP", "PAR", "PSN", "TOX", "BRN", "FRZ", "FNT" }
for locale, catalog in pairs(catalogs) do
  selected = locale
  for _, id in ipairs(types) do
    local name = theme:typeName(id)
    local short = theme:typeShortName(id, name)
    check(name == catalog["TYPE|" .. id] and short and short == catalog["TYPE SHORT|" .. id],
      locale .. " resolves both badge labels for " .. id)
  end
  for _, id in ipairs(statuses) do
    check(theme:statusName(id) == catalog["STATUS SHORT|" .. id],
      locale .. " resolves the status badge label for " .. id)
  end
end
selected = "pt-BR"
check(theme:typeName("PSYCHIC_TYPE") == "PSÍQUICO"
  and theme:typeShortName("PSYCHIC_TYPE", "PSÍQUICO") == "PSÍ",
  "legacy Psychic type ID resolves both translated labels")
check(theme:typeName("POISON") == "VENENO" and theme:typeShortName("BUG", "INSETO") == "INS",
  "the reported move and party badge types use Brazilian Portuguese")
local pack = { strings = { get = function(_, key)
  if key == "type|POISON" then return "GIFT" end
end } }
check(theme:typeName("POISON", pack) == "GIFT" and theme:typeShortName("POISON", "GIFT") == nil,
  "native contextual type translations keep their name and language")
local statusContent = { statuses = { get = function(_, id) return { label = id } end } }
check(theme:statusName("SLP", statusContent) == "DOR" and theme:statusName("FNT") == "DES",
  "default registry labels fall back to the selected Gear language")
statusContent.statuses.get = function() return { label = "SLP", hudLabel = "SOM" } end
check(theme:statusName("SLP", statusContent) == "SOM",
  "native status translations retain HUD label precedence")
local custom = { type_chart = { get = function() return { name = "SOUND" } end } }
check(theme:typeName("CUSTOM", custom) == "SOUND" and theme:typeShortName("CUSTOM", "SOUND") == nil,
  "custom types retain their registry labels")
selected = "en"
check(theme:typeName("PSYCHIC_TYPE") == "PSYCHIC" and theme:typeShortName("BUG", "BUG") == nil,
  "English uses the canonical names and existing compact fallback")
check(theme:statusName("SLP") == "SLP" and theme:statusName(nil) == nil,
  "English uses native status IDs and healthy Pokemon have no label")

selected = "de"
check(i18n:text("UNTRANSLATED UI") == "UNTRANSLATED UI", "missing UI falls back to English")
catalogs.de["PENDING TRANSLATION"] = false
catalogs.de["EMPTY TRANSLATION"] = ""
check(i18n:text("PENDING TRANSLATION") == "PENDING TRANSLATION", "false translation falls back to English")
check(i18n:text("EMPTY TRANSLATION") == "EMPTY TRANSLATION", "empty translation falls back to English")
local missing = table.concat(i18n:coverage("de"), "|")
check(missing:find("PENDING TRANSLATION", 1, true) and missing:find("EMPTY TRANSLATION", 1, true),
  "untranslated placeholders remain visible in coverage")
catalogs.de["PENDING TRANSLATION"], catalogs.de["EMPTY TRANSLATION"] = nil, nil
catalogs.de["%s %d"] = "%d %s"
check(i18n:format("%s %d", "25", 3) == "25 3", "reordered specifiers cannot silently corrupt values")
catalogs.de["%s %d"] = "%s"
check(i18n:format("%s %d", "VALUE", 3) == "VALUE 3", "missing argument falls back to English")
catalogs.de["%s %d"] = nil

local function signature(value)
  local parts = {}
  for spec in value:gsub("%%%%", ""):gmatch("%%[-+ #0]*%d*%.?%d*([cdiouxXeEfgGqs])") do
    parts[#parts + 1] = spec
  end
  return table.concat(parts)
end
for code, catalog in pairs(catalogs) do
  for key, value in pairs(catalog) do
    if type(value) == "string" and signature(key) ~= "" then
      check(signature(key) == signature(value), code .. " format signature: " .. key)
    end
  end
end

local reference, referenceCount = catalogs.de, 0
for key in pairs(reference) do referenceCount = referenceCount + 1 end

for _, language in ipairs({ "de", "es", "fr", "ja", "it", "pt-BR" }) do
  local count, expectedMissing = 0, {}
  local localized = I18N.new(function(code) return catalogs[code] end,
    function() return language end)
  for key, value in pairs(catalogs[language]) do
    count = count + 1
    check(reference[key] ~= nil, language .. " has no extra key: " .. key)
    check(value == false or type(value) == "string" and value ~= "",
      language .. " has a translation or an explicit fallback: " .. key)
    check(localized:text(key) == (value or key), language .. " resolves its translation or English fallback: " .. key)
    if value == false then expectedMissing[#expectedMissing + 1] = key end
  end
  check(count == referenceCount, language .. " catalog key count matches")
  for key in pairs(reference) do
    check(catalogs[language][key] ~= nil,
      language .. " contains key: " .. key)
  end
  table.sort(expectedMissing)
  check(table.concat(localized:coverage(language), "|") == table.concat(expectedMissing, "|"),
    language .. " missing translations come directly from its catalog")
end

for key, value in pairs(reference) do
  check(type(value) == "string" and value ~= "",
    "de has a non-empty value: " .. key)
end
for key, value in pairs(catalogs.it) do
  check(type(value) == "string" and value ~= "", "Italian has a complete translation: " .. key)
end
for key, value in pairs(catalogs["pt-BR"]) do
  check(type(value) == "string" and value ~= "", "Brazilian Portuguese has a complete translation: " .. key)
end

-- Literal callsites are a release gate; dynamic screen models are additionally
-- exercised by the preview matrix. Game-provided values never enter this API.
local requested = {}
local mainSource
for _, filename in ipairs({ "main.lua", "ui/base/init.lua", "ui/features/achievements.lua", "ui/features/notes.lua", "features/notes.lua", "ui/features/pss.lua",
    "features/daycare.lua", "ui/features/daycare.lua", "runtime/daycare.lua", "features/calendar.lua",
    "ui/features/calendar.lua", "runtime/calendar.lua", "runtime/calendar_gen3.lua",
    "features/shiny_hunt.lua", "ui/features/shiny_hunt.lua", "runtime/shiny_hunt.lua",
    "features/notices.lua", "ui/features/notices.lua", "runtime/notices.lua",
    "features/moments.lua", "ui/features/moments.lua", "runtime/moments.lua", "runtime/notice_sources.lua" }) do
  local file = assert(io.open(root .. "/" .. filename, "rb"))
  local source = file:read("*a")
  file:close()
  if filename == "main.lua" then mainSource = source end
  for _, draw in ipairs({ "text", "centered", "header", "partyInfo",
      "partyType", "partyName", "label" }) do
    for key in source:gmatch(draw .. '%(%s*"([A-Z][^"]*)"%s*,') do
      check(key == "X" or key == "KANTO GEAR 3.0",
        filename .. " marks literal UI text explicitly: " .. key)
    end
  end
  for _, call in ipairs({ "translate", "format" }) do
    for key in source:gmatch('[^%.%w_]' .. call .. '%(%s*"(.-)"') do
      if key ~= "" then requested[key] = true end
    end
  end
end

-- Every translated glyph must survive the classic renderer as well as HGSS.
local core = assert(loadfile(root .. "/tests/support/core.lua"))()
local font, normalize = core.FONT, core.normalize
check(normalize("sì può più perché") == "SÌ PUÒ PIÙ PERCHÉ", "Italian accents survive bitmap normalization")
local atlasGlyphs = loadModule("ui/fonts/glyphs.lua")
for _, glyph in ipairs({ "Ì", "Ò", "ì", "ò" }) do
  check(atlasGlyphs:find(glyph, 1, true) ~= nil, "image fonts include Italian glyph " .. glyph)
end
for code, catalog in pairs(catalogs) do
  local characters = {}
  for _, value in pairs(catalog) do
    if type(value) == "string" then
      for glyph in normalize(value):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        characters[glyph] = true
      end
    end
  end
  for glyph in pairs(characters) do
    -- Japanese uses the bundled TrueType fallback; its complete catalog is
    -- checked against the real font by the Japanese preview matrix.
    if code ~= "ja" then
      check(glyph == " " or font[glyph:upper()] ~= nil,
        code .. " bitmap font covers " .. glyph)
    end
  end
end

-- Conditional translation arguments are not visible to the literal-callsite scan.
requested["NO SPACE"] = true
for _, key in ipairs({ "AFTER %s EGGS", "AFTER %s ENCOUNTERS", "SHINY DITTO BOARDING: EGGS 1/%d",
    "SHINY PARENT BOARDING: EGGS 1/%d", "AUTO COUNT", "PAUSED", "EGGS", "RESETS", "ENCOUNTERS",
    "TARGET", "PHASE", "LUCKY", "HUNT", "ODDS", "LOG", "HUNT NOT SAVED", "ANYTHING", "LAST MET",
    "THIS AREA", "YOUR PARTY", "EGG", "SHINY HUNT", "SHINY", "COLLECTION",
    "COUNTS EVERY ENCOUNTER FOR YOU.", "LIVE ODDS, PHASES AND A SHINY LOG.",
    "SOFT RESETS KEEP YOUR COUNT.", "SHINY PHASE!", "NOTIFICATIONS", "NOTIFICATION SOUND",
    "HISTORY", "OLDEST FIRST", "NO NOTIFICATIONS YET", "READ",
    "OPEN RIGHT NOW", "NOW OPEN", "GOLD STAMP!", "SILVER STAMP!", "WITH SOUND", "SILENT", "DOT ONLY",
    "SHINY CHIME", "AT ONCE", "WITH CARD", "CARD TIME", "SHORT", "NORMAL", "LONG", "GEAR HIDDEN",
    "OVER GAME", "WAIT", "WHAT, HOW AND WHEN" }) do
  requested[key] = true
end

-- Moments catalog titles, lines, detail rows and months are looked up by value.
do
  local Moments = loadModule("features/moments.lua")
  for _, entry in ipairs(Moments.CATALOG) do requested[entry.title], requested[entry.line] = true, true end
  for _, key in ipairs({ "POKEMON", "OPPONENT", "PLACE", "DATE", "PLAY TIME", "JAN", "FEB", "MAR", "APR",
      "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }) do
    requested[key] = true
  end
end

-- Shared dynamic arrays are not visible to the literal-callsite scan.
local settingsInfo = loadModule("core/settings_info.lua")
for _, values in ipairs({ settingsInfo.help, settingsInfo.discovery }) do
  for _, key in pairs(values) do requested[key] = true end
end
for _, language in ipairs({ "es", "pt-BR" }) do
  for _, option in ipairs({ "display_mode", "battle_view", "display_setup" }) do
    check(type(catalogs[language][settingsInfo.help[option]]) == "string",
      language .. " translates current help: " .. option)
  end
end
local theme = assert(loadfile(root .. "/tests/support/core.lua"))().THEME
for _, effects in ipairs({ theme.moveEffects, theme.moveSpecial }) do
  for _, lines in pairs(effects) do
    for _, key in ipairs(lines) do requested[key] = true end
  end
end
for _, key in ipairs({ "EDIT", "DELETE", "RED", "BLUE", "GREEN", "GOLD", "ERASER", "REVERT",
    "TASK", "TASKS", "TITLE", "WRITE", "INK", "PEN", "COLOR", "THIN", "THICK", "PURPLE",
    "GENERAL", "NEW NOTE", "DRAW", "DRAWING", "SPACE", "NEW LINE", "UNDO", "HERE", "ALL NOTES",
    "EDIT DRAWING", "+ TASK", "NOTES STORAGE UNAVAILABLE", "NOTES COULD NOT BE LOADED",
    "NOT SAVED - TRY AGAIN", "TEXT LIMIT REACHED", "NOTE LIMIT REACHED", "TASK LIMIT REACHED",
    "DRAWING LIMIT REACHED", "HOST MISSING LIVE DRAWING INPUT", "WRITE, CHECK TASKS AND DRAW." }) do
  requested[key] = true
end
local keys = {}
for key in pairs(requested) do keys[#keys + 1] = key end
table.sort(keys)
for _, key in ipairs(keys) do
  check(reference[key] ~= nil, "literal UI key is catalogued: " .. key)
end

io.write(string.format("%d/%d checks passed  (Kanto Gear built-in i18n)\n",
  passed, passed + failed))
if failed > 0 then os.exit(1) end
