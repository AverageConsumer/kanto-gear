-- Run from an engine checkout with an unpacked generated translation mod.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local pack = os.getenv("KANTO_TRANSLATION_MOD")
if not pack then print("Translation integration: set KANTO_TRANSLATION_MOD to a generated mod"); return end
local version = os.getenv("KANTO_GEAR_TEST_VERSION") or "red"
local generation = (version == "red" or version == "blue" or version == "yellow") and 1 or 2
require("src.core.GameVersion").set(version)
local run = T.sdk.loadMods({ path, pack }, { generation = generation })
T.eq(#run.errors, 0, "Gear and translation load together")
T.eq(run.mods.kanto_gear.state, "loaded", "Gear stays enabled")
local function up(fn, target)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, i)
    if name == target then return value end
  end
  error("Missing upvalue " .. target)
end
local input
for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
  if entry.owner == "kanto_gear" then input = entry.callback end
end
local display = up(input, "displayRuntime")
local hgssRuntime = up(input, "hgssRuntime")
local theme = up(display.drawContents, "THEME")
local world = { map = { id = "PALLET_TOWN", def = {} } }
local game = { data = run.data, world = world, overworld = world,
  save = { generation = generation, version = version, player = { name = "RED", id = 7, map = "PALLET_TOWN" },
    party = {}, inventory = {}, boxes = {}, pokedex = { seen = {}, caught = {} } },
  stack = { states = { world }, top = function() return world end } }
-- The headless graphics stub opens io paths, while the real runtime resolves
-- this virtual mod asset path through love.filesystem.
local newFont = love.graphics.newFont
love.graphics.newFont = function(file, ...)
  if type(file) == "string" then file = file:gsub("^mods/[^/]+/", pack .. "/") end
  return newFont(file, ...)
end
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss" }
run.loader.events:emit("game.ready", { game = game })
T.eq(theme.translationFonts.file, run.data.font.ttf.file, "Gear binds the merged game font")
local names = assert(loadfile(pack .. "/lang/species_names.lua"))()
local items = assert(loadfile(pack .. "/lang/item_names.lua"))()
if version == "crystal" then
  local extra = loadfile(pack .. "/lang/crystal_item_names.lua")
  for id, name in pairs(extra and extra() or {}) do items[id] = name end
end
game.save.party = { { species = "PIKACHU", hp = 5, stats = { hp = 12 } } }
local partyData = up(display.drawHome, "partyData")
T.eq(display.partyView(partyData()[1]).name,
  names.PIKACHU, "Party reads translated species names")
game.save.inventory.POTION = 2
T.check(display.setPackageInstalled("bag", true), "Bag is available")
local model = display.bagModel()
T.eq(model.entries[1].label, items.POTION, "Bag reads translated item names")
for id, expected in pairs(names) do
  game.save.party = { { species = id, hp = 5, stats = { hp = 12 } } }
  T.eq(display.partyView(partyData()[1]).name, expected, "Party species " .. id)
  game.save.party[1].nickname = "Lestat / " .. expected
  T.eq(display.partyView(partyData()[1]).name, "Lestat / " .. expected, "nickname " .. id)
end
game.save.inventory = {}
for id in pairs(items) do game.save.inventory[id] = 1 end
local seenItems = {}
for pocket = 1, generation == 2 and 4 or 1 do
  display.bag.pocket, display.bag.page = pocket, 1
  for page = 1, display.bagModel().pages do
    display.bag.page = page
    for _, item in ipairs(display.bagModel().entries) do
      seenItems[item.id] = true
      T.eq(item.label, items[item.id], "Bag item " .. item.id)
    end
  end
end
for id, expected in pairs(items) do
  if require("src.inventory.Bag").isBadge(id) then
    -- The engine stores badges in inventory but deliberately excludes them
    -- from Bag.order; they must not appear as usable item cards.
    T.check(not seenItems[id], "Bag excludes badge " .. id)
    T.eq(run.data.items[id].name, expected, "translated badge registry " .. id)
  else
    T.check(seenItems[id], "Bag can reach " .. id)
  end
end
local moves = assert(loadfile(pack .. "/lang/move_names.lua"))()
for id, expected in pairs(moves) do
  T.eq(hgssRuntime.moveView({ id = id }).name, expected,
    "move detail name " .. id)
end
local compat = up(display.bagModel, "compat")
local function catalog(name)
  local chunk = loadfile(pack .. "/lang/" .. name .. ".lua")
  return chunk and chunk() or {}
end
local kinds = catalog("species_kinds")
for id, expected in pairs(catalog("type_names")) do
  T.eq(theme:typeName(id, up(display.saveHome, "mod").content), expected,
    "localized type display " .. id)
  game.save.party = { { species = "PIKACHU", hp = 5, stats = { hp = 12 } } }
  local types = run.data.pokemon.PIKACHU.types
  run.data.pokemon.PIKACHU.types = { id }
  local view = display.partyView(partyData()[1])
  T.eq(view.typeLabel, expected, "Party uses translated type " .. id)
  T.eq(view.type, id, "Party preserves semantic type ID " .. id)
  if generation == 1 then
    T.eq(run.data.type_chart.types[id].name, id == "PSYCHIC_TYPE" and "PSYCHIC" or id,
      "translation preserves canonical type registry " .. id)
  end
  run.data.pokemon.PIKACHU.types = types
end
if generation == 2 then
  -- Reproduce Game2's separate native Pokedex table and post-merge projection,
  -- rather than relying only on the SDK's pokemon registry fixture.
  run.data.gen2Pokedex = { entries = {} }
  for id in pairs(names) do run.data.gen2Pokedex.entries[id] = {} end
  require("src.core.gen2.PokedexText").apply(run.data)
end
local dexText = catalog("species_dex_text")
local dexText2 = catalog("species_dex_text2")
if version == "silver" or version == "crystal" then
  for id, value in pairs(catalog("species_dex_text_" .. version)) do dexText[id] = value end
  for id, value in pairs(catalog("species_dex_text2_" .. version)) do dexText2[id] = value end
end
for id in pairs(names) do
  local info = compat.enemyInfo({ species = id }, run.data, game.save)
  if kinds[id] then T.eq(info.kind, kinds[id], "Pokedex kind " .. id) end
  if dexText[id] then
    T.eq(info.descriptionText, dexText[id] .. " " .. (dexText2[id] or ""),
      "edition-specific Pokedex description " .. id)
  end
end
if generation == 1 then
  local dialogue = catalog("dialogue")
  if version == "yellow" then
    for id, value in pairs(catalog("dialogue_yellow")) do dialogue[id] = value end
  end
  for id, expected in pairs(dialogue) do
    if id:find("DexEntry") then
      local data = { pokemon = { TEST = { dexEntry = { text = id } } }, text = run.data.text }
      T.eq(compat.enemyInfo({ species = "TEST" }, data, game.save).descriptionText,
        expected, "Pokedex text pointer " .. id)
    end
  end
end
if generation == 2 then
  local landmarks = catalog("landmarks")
  if version == "crystal" then
    for id, value in pairs(catalog("crystal_landmarks")) do landmarks[id] = value end
  end
  for id, expected in pairs(landmarks) do
    T.eq(run.data.gen2Landmarks.landmarks[id].name, expected, "map landmark " .. id)
  end
end
local text = "ピカチュウ"
local lines = theme:messageLines({ text }, 23)
T.eq(lines[1], text, "normalization preserves Japanese")
local message = string.rep(text, 12)
lines = theme:messageLines({ message }, 22, 20)
T.eq(table.concat(lines), message, "unspaced Japanese wraps without losing characters")
for _, line in ipairs(lines) do T.check(theme:textWidth(line) <= 132, "wrapped line fits in pixels") end
T.eq(theme:messageLines({ "POKé BALL" }, 22)[1], "POKÉ BALL", "European normalization is preserved")
local description = string.rep(names.PIKACHU, 8)
local detailLines = display.bagWords(description, 31, 20)
T.eq(table.concat(detailLines), description:upper(),
  "unspaced item descriptions wrap without losing text")
if generation == 2 then
  local shortDescription = string.rep(names.PIKACHU, 5)
  local moveLines = compat.moveInfoLines({}, { description = shortDescription }, {})
  T.eq(table.concat(moveLines), shortDescription:upper(),
    "translated move description uses both available lines")
end
local data = { pokemon = { TEST = { dexEntry = { text = description }, types = {} } }, type_chart = {} }
local info = compat.enemyInfo({ species = "TEST" }, data, {})
T.eq(table.concat(info.description), description:upper(),
  "unspaced Pokedex descriptions wrap without losing text")
local oldFont = theme.translationFonts.file
game.data = T.fixtures.fresh()
run.loader.events:emit("game.ready", { game = game })
T.eq(theme.translationFonts.file, nil, "switching to an untranslated game clears its font")
T.check(next(theme.translationFonts.variants) == nil, "switching clears cached variants")
game.data = run.data
run.loader.events:emit("game.ready", { game = game })
T.eq(theme.translationFonts.file, oldFont, "translated game can be loaded again")
love.graphics.newFont = newFont
run.release()
T.finish("generated translation + Gear (" .. version .. ")")
