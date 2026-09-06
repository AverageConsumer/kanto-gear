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
game.save.party = { { species = "PIKACHU", hp = 5, stats = { hp = 12 } } }
local partyData = up(display.drawHome, "partyData")
T.eq(display.partyView(partyData()[1]).name,
  names.PIKACHU, "Party reads translated species names")
game.save.inventory.POTION = 2
T.check(display.setPackageInstalled("bag", true), "Bag is available")
local model = display.bagModel()
T.eq(model.entries[1].label, items.POTION, "Bag reads translated item names")
local text = "ピカチュウ"
local lines = theme:messageLines({ text }, 23)
T.eq(lines[1], text, "normalization preserves Japanese")
local message = string.rep(text, 12)
lines = theme:messageLines({ message }, 22, 20)
T.eq(table.concat(lines), message, "unspaced Japanese wraps without losing characters")
for _, line in ipairs(lines) do T.check(theme:textWidth(line) <= 132, "wrapped line fits in pixels") end
T.eq(theme:messageLines({ "POKé BALL" }, 22)[1], "POKÉ BALL", "European normalization is preserved")
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
