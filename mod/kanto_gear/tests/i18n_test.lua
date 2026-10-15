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
for _, language in ipairs({ "de", "es", "fr", "ja", "it" }) do
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

for _, language in ipairs({ "de", "es", "fr", "ja", "it" }) do
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

-- Literal callsites are a release gate; dynamic screen models are additionally
-- exercised by the preview matrix. Game-provided values never enter this API.
local requested = {}
local mainSource
for _, filename in ipairs({ "main.lua", "ui/base/init.lua", "ui/features/achievements.lua", "ui/features/notes.lua", "features/notes.lua", "ui/features/pss.lua",
    "features/daycare.lua", "ui/features/daycare.lua", "runtime/daycare.lua", "features/calendar.lua",
    "ui/features/calendar.lua", "runtime/calendar.lua", "runtime/calendar_gen3.lua" }) do
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

-- Shared dynamic arrays are not visible to the literal-callsite scan.
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
