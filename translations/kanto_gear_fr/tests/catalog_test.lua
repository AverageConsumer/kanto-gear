local path = (...) or "translations/kanto_gear_fr/lang/fr.lua"
local catalog = assert(loadfile(path))()

local function formats(value)
  local out = {}
  for spec in value:gmatch("%%(.)") do
    if spec ~= "%" then out[#out + 1] = spec end
  end
  return table.concat(out, ",")
end

local count = 0
for source, translated in pairs(catalog) do
  assert(type(source) == "string" and source ~= "")
  assert(type(translated) == "string" and translated ~= "")
  assert(formats(source) == formats(translated),
    "Marqueurs incompatibles : " .. source)
  count = count + 1
end

assert(count == 315, "Le catalogue de traduction est incomplet")

local function glyphs(value)
  return select(2, value:gsub("[^\128-\193]", ""))
end

local layoutLimits = {
  ["LOADING AREA"] = 16,
  ["EXIT"] = 7,
  ["ITEM"] = 7,
  ["HIDDEN"] = 7,
  ["CAUGHT"] = 7,
  ["DONE"] = 5,
  ["OPEN"] = 5,
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
    source .. " ne tient pas dans l'interface : " .. translated)
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
  assert(theme, "Thème Kanto Gear introuvable")
  theme.strings = { get = function(_, source) return catalog[source] end }

  local overflow = {}
  local function checkLine(id, line)
    line = theme:translate(line)
    if glyphs(line) > 21 then
      overflow[#overflow + 1] = id .. " : " .. line
    end
  end

  for effect, lines in pairs(theme.moveEffects) do
    for _, line in ipairs(lines) do checkLine(effect, line) end
  end
  for move, lines in pairs(theme.moveSpecial) do
    for _, line in ipairs(lines) do checkLine(move, line) end
  end

  local function checkDescription(id, move, definition, ruleset)
    local lines = theme:moveDescription(move, definition, ruleset)
    for _, line in ipairs(lines) do checkLine(id, line) end
  end
  checkDescription("fixed number", { id = "TEST" }, { fixedDamage = 999 })
  checkDescription("fixed level", { id = "TEST" }, { fixedDamage = "level" })
  checkDescription("fixed custom", { id = "TEST" }, {
    fixedDamage = function() end,
  })
  checkDescription("multi hit", { id = "TEST" }, { multiHit = 5 })
  checkDescription("multi hit range", { id = "TEST" }, {
    multiHit = { 2, 3, 4, 5 },
  })
  checkDescription("high critical", { id = "TEST" }, { highCrit = true })
  checkDescription("Focus Energy fixed", { id = "TEST" }, {
    effect = "FOCUS_ENERGY_EFFECT",
  }, { focusEnergyBug = false })
  checkDescription("Focus Energy bug", { id = "TEST" }, {
    effect = "FOCUS_ENERGY_EFFECT",
  }, { focusEnergyBug = true })
  checkDescription("Hyper Beam fixed", { id = "TEST" }, {
    effect = "HYPER_BEAM_EFFECT",
  }, { hyperBeamSkipRechargeOnKO = false })
  checkDescription("Hyper Beam bug", { id = "TEST" }, {
    effect = "HYPER_BEAM_EFFECT",
  }, { hyperBeamSkipRechargeOnKO = true })
  checkDescription("special damage", { id = "TEST" }, {
    effect = "SPECIAL_DAMAGE_EFFECT",
  })
  for _, effect in ipairs({
    "SPECIAL_UP1_EFFECT", "SPECIAL_UP2_EFFECT",
    "SPECIAL_DOWN1_EFFECT", "SPECIAL_DOWN2_EFFECT",
    "SPECIAL_DOWN_SIDE_EFFECT", "NO_ADDITIONAL_EFFECT",
  }) do
    checkDescription(effect, { id = "TEST" }, { effect = effect })
  end

  for id, definition in pairs(assert(loadfile(movesPath))()) do
    local lines = theme:moveDescription({ id = id }, definition, {
      focusEnergyBug = true,
      hyperBeamSkipRechargeOnKO = true,
    })
    for _, line in ipairs(lines) do
      checkLine(id, line)
    end
  end
  assert(#overflow == 0,
    "Descriptions trop longues :\n" .. table.concat(overflow, "\n"))
end

print(('%d textes de Kanto Gear vérifiés'):format(count))
