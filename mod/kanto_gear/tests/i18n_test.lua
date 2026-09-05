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
for _, language in ipairs({ "de", "es", "fr" }) do
  catalogs[language] = loadModule("lang/" .. language .. ".lua")
end

local I18N = loadModule("i18n.lua")
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
selected = "invalid"
check(i18n:language() == "en", "invalid selection falls back to English")
selected = "en"
check(i18n:text("PIKACHU") == "PIKACHU",
  "English UI keys are identity values")

selected = "de"
check(i18n:text("UNTRANSLATED UI") == "UNTRANSLATED UI", "missing UI falls back to English")
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
    if signature(key) ~= "" then
      check(signature(key) == signature(value), code .. " format signature: " .. key)
    end
  end
end

local reference, referenceCount = catalogs.de, 0
for key in pairs(reference) do referenceCount = referenceCount + 1 end
for _, language in ipairs({ "es", "fr" }) do
  local count = 0
  for key, value in pairs(catalogs[language]) do
    count = count + 1
    check(reference[key] ~= nil, language .. " has no extra key: " .. key)
    check(type(value) == "string" and value ~= "",
      language .. " has a non-empty value: " .. key)
  end
  check(count == referenceCount, language .. " catalog key count matches")
  for key in pairs(reference) do
    check(catalogs[language][key] ~= nil,
      language .. " contains key: " .. key)
  end
end

for key, value in pairs(reference) do
  check(type(value) == "string" and value ~= "",
    "de has a non-empty value: " .. key)
end

-- Literal callsites are a release gate; dynamic screen models are additionally
-- exercised by the preview matrix. Game-provided values never enter this API.
local requested = {}
local mainSource
for _, filename in ipairs({ "main.lua", "hgss.lua", "achievements_ui.lua", "notes_ui.lua", "notes.lua" }) do
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
local font = assert(loadstring("return " .. assert(mainSource:match("local FONT = (%b{})"))))()
for code, catalog in pairs(catalogs) do
  local characters = {}
  for _, value in pairs(catalog) do
    for glyph in value:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
      characters[glyph] = true
    end
  end
  for glyph in pairs(characters) do
    check(glyph == " " or font[glyph:upper()] ~= nil,
      code .. " bitmap font covers " .. glyph)
  end
end

-- Shared dynamic arrays are not visible to the literal-callsite scan.
local entry = assert(loadfile(root .. "/main.lua"))()
local theme
for index = 1, debug.getinfo(entry, "u").nups do
  local name, value = debug.getupvalue(entry, index)
  if name == "THEME" then theme = value break end
end
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
