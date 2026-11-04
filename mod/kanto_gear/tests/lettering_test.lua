local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local function read(name)
  local file = assert(io.open(root .. "/" .. name, "rb"))
  local source = file:read("*a"); file:close(); return source
end
local function module(name) return assert(load(read(name), "@" .. name))() end
local H = {}
module("ui/skins/case.lua")(H, {}, {}, read)
local core = module("tests/support/core.lua")
local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
for _, row in ipairs({
  { "FERRÃO VENENOSO", "Ferrão Venenoso" },
  { "Ferrão Venenoso", "Ferrão Venenoso" },
  { "CANÇÕES E AÇÕES", "Canções e Ações" },
  { "DADOS DO PARCEIRO", "Dados do Parceiro" },
  { "PORTUGUÊS (BR)", "Português (BR)" },
  { "HÁ UM OVO ESPERANDO", "Há um Ovo Esperando" },
  { "ÃÕ", "Ãõ" }, -- no ASCII uppercase character in this word
  { "ÄÖÜ ÃÕ", "Äöü Ãõ" },
  { "ÄRGER ÜBER GRÖSSE", "Ärger Über Grösse" },
  { "POKéMON ÉLECTRIQUE", "Pokémon Électrique" },
  { "CAÑÓN ÁCIDO", "Cañón Ácido" },
  { "SÌ PUÒ PIÙ PERCHÉ", "Sì Può Più Perché" },
  { "CŒUR D’OR", "Cœur D’or" },
  { "ŁÓDŹ ŘEKA ȘARPE", "Łódź Řeka Șarpe" },
  { "HP PP TM01 ID 123", "HP PP TM01 ID 123" },
  { "ATTACK OF THE POKéMON", "Attack of the Pokémon" },
  { "ピカチュウ", "ピカチュウ" }, { "피카츄", "피카츄" },
  { "ПИКАЧУ", "ПИКАЧУ" }, { "皮卡丘", "皮卡丘" },
}) do
  eq(H.v4Title(row[1]), row[2], "title " .. row[1])
end
eq(core.normalize("Ferrão Venenoso / canções"), "FERRÃO VENENOSO / CANÇÕES", "classic PT-BR")
eq(core.THEME.bitmapFont:hasGlyphs("FERRÃO VENENOSO ÕÃ ÄÖÜ Ñ Ç"), true, "classic glyph coverage")
eq(core.normalize("sì può più perché / Ärger über Größe"), "SÌ PUÒ PIÙ PERCHÉ / ÄRGER ÜBER GRÖSSE", "classic accents")
eq(H.v4Sentence("THE FERRÃO HITS. AÇÕES!", true), "The ferrão hits. Ações!", "sentence accents")
H:v4Caps(function() eq(H:v4Cased("FERRÃO VENENOSO"), "FERRÃO VENENOSO", "caps scope") end)
local atlas = module("ui/fonts/glyphs.lua")
for _, ch in ipairs({ "Ã", "Õ", "ã", "õ", "Ä", "Ö", "ä", "ö", "Œ", "œ", "Ł", "ł", "Ș", "ș" }) do
  eq(atlas:find(ch, 1, true) ~= nil, true, "atlas includes " .. ch)
end
local latinCase = module("i18n/latin_case.lua")()
for up, low in pairs(latinCase.lower) do
  -- One complete run, including characters not present in the bundled fonts.
  eq(H.v4Title("A" .. up .. "Z"), "A" .. low .. "z", "Latin lower " .. up)
end
for low, up in pairs(latinCase.upper) do
  eq(core.normalize(low), up, "Latin upper " .. low)
  if low ~= "é" then eq(H.v4Title("A" .. low .. "Z"), "A" .. low .. "Z", "mixed case " .. low) end
end
for _, code in ipairs({ "de", "es", "fr", "it", "ja", "pt-BR" }) do
  for _, value in pairs(module("i18n/catalogs/" .. code .. ".lua")) do
    if type(value) == "string" then
      local title = H.v4Title(value)
      eq(H.v4Title(title), title, code .. " case is stable")
      eq(#core.glyphList(title), #core.glyphList(value), code .. " retains every character")
    end
  end
end
print(checks .. " checks passed (multilingual lettering)")
