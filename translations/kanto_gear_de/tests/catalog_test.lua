local path = (...) or "translations/kanto_gear_de/lang/de.lua"
local catalog = assert(loadfile(path))()

local function countFormats(value)
  local count = 0
  for spec in value:gmatch("%%(.)") do
    if spec ~= "%" then count = count + 1 end
  end
  return count
end

local count = 0
for source, translated in pairs(catalog) do
  assert(type(source) == "string" and source ~= "")
  assert(type(translated) == "string" and translated ~= "")
  if countFormats(source) > 0 then
    assert(countFormats(source) == countFormats(translated),
      "Formatanzahl stimmt nicht: " .. source)
  end
  count = count + 1
end

assert(count == 404, "Übersetzungskatalog ist unvollständig")

for _, source in ipairs({
  "NEW GAME", "OPTION", "EXIT GAME", "INPUT STAYS ON TOP",
  "TAP ANYWHERE / A", "USE ITEM ON", "STEP COUNTER", "FIELD KIT",
  "READY", "NOT HERE", "TAP TO USE", "USE NOW?", "FISH",
  "BAG", "POKE BALLS", "KEY ITEMS", "USE AGAIN",
  "TOOLS %d/%d", "ITM%d", "HID%d", "%s  L%d", "L%d", "L%d-%d",
  "LV.%d", "EXP", "EXP %d", "NO.%03d %s", "NO.%03d LV.%d", "OT %s",
  "ID %05d", "MIMIC", "DVS >", "NEW %s", "PC BOX %d %d/20",
  "PARTY %d/6  %d/%d", "BOX %d  %d/20  %d/%d",
}) do
  assert(catalog[source], "Fehlender UI-Text: " .. source)
end

local function glyphs(value)
  return select(2, value:gsub("[^\128-\193]", ""))
end

-- These labels are drawn into fixed-width fields instead of buttons or headers.
-- Keep deliberate translations within the actual renderer budgets so they do
-- not fall back to automatic dot truncation.
local layoutLimits = {
  ["USE ITEM ON"] = 14,
  ["LOADING AREA"] = 16,
  ["MAP + FLY"] = 10,
  ["JOHTO MAP"] = 10,
  ["JOHTO FLY"] = 10,
  ["KANTO MAP"] = 10,
  ["KANTO FLY"] = 10,
  ["EXIT"] = 7,
  ["ITEM"] = 7,
  ["HIDDEN"] = 7,
  ["CAUGHT"] = 7,
  ["DONE"] = 5,
  ["OPEN"] = 5,
  ["MISSED"] = 5,
  ["LATER"] = 5,
  ["MONEY"] = 11,
  ["TIME"] = 11,
  ["POKEDEX"] = 11,
  ["STEPS"] = 11,
  ["POWER"] = 7,
  ["HIT"] = 8,
  ["PP"] = 4,
  ["DISABLED"] = 8,
  ["NO PP"] = 8,
  ["MATCHUP"] = 13,
  ["SEEN"] = 7,
  ["WEAK"] = 7,
  ["RESIST"] = 7,
}

for source, limit in pairs(layoutLimits) do
  local translated = catalog[source] or source
  assert(glyphs(translated) <= limit,
    source .. " passt nicht ins Layout: " .. translated)
end

local kantoPath = os.getenv("KANTO_GEAR_MAIN")
local movesPath = os.getenv("KANTO_GEAR_MOVES")
if kantoPath and movesPath then
  local entry = assert(loadfile(kantoPath))()
  local theme
  for index = 1, debug.getinfo(entry, "u").nups do
    local name, value = debug.getupvalue(entry, index)
    if name == "THEME" then theme = value break end
  end
  assert(theme, "Kanto-Gear-Theme nicht gefunden")
  theme.strings = { get = function(_, source) return catalog[source] end }

  for id, definition in pairs(assert(loadfile(movesPath))()) do
    local lines = theme:moveDescription({ id = id }, definition, {
      focusEnergyBug = true,
      hyperBeamSkipRechargeOnKO = true,
    })
    for _, line in ipairs(lines) do
      line = theme:translate(line)
      assert(glyphs(line) <= 21, id .. " ist zu lang: " .. line)
    end
  end
end

print(('%d Kanto-Gear-Texte geprüft'):format(count))
