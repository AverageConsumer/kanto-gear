local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
-- Shiny Hunt on a native Gen 3 session: shininess from TID/SID/PID, wild
-- battles from the host's battle payload, hatches from the native party.
love.graphics.arc = love.graphics.arc or function() end
local edition = assert(os.getenv("POKEPORT_VERSION"))
local rs = edition == "ruby" or edition == "sapphire"
local emerald = edition == "emerald"
local hoenn = rs or emerald
dofile(path .. "/tests/" .. (rs and "rs_native_test" or emerald and "emerald_native_test" or "gen3_native_test") .. ".lua")
if rs and love == require("tests.love_stub") then
  local nativeFs = require("tests.fs_io").new(assert(os.getenv("POKEPORT_GBA_CACHE")))
  for _, method in ipairs({ "read", "load", "getInfo" }) do
    local fallback = love.filesystem[method]
    love.filesystem[method] = function(file, ...)
      local relative = file:match("^data/generated/gba/(.*)$")
      if relative then return nativeFs[method](relative, ...) end
      return fallback(file, ...)
    end
  end
end
local Dataset = require("src.core.game3.dataset")
local Schema = require("src.core.game3.save_schema_firered")
local maps = Dataset.buildMaps()
Dataset.attachMidLayouts(maps, Dataset.cache())
local data = { maps = maps,
  gen3Pokemon = require("src.core.game3.pokemon"),
  gen3Moves = require("src.core.game3.battle.moves"),
  gen3Items = require("src.core.game3.items_data"),
  gen3Encounters = assert(loadfile(os.getenv("POKEPORT_GBA_CACHE") .. "/encounters.lua"))() }
local Fs = require("tests.fs_io").new(path)
local fs, writes = {}, {}
local function resolve(file) return file:gsub("^mods/kanto_gear/?", "") end
function fs.read(file) return writes[file] or Fs.read(resolve(file)) end
function fs.load(file)
  local bytes = fs.read(file)
  return bytes and load(bytes, "@" .. file)
end
function fs.write(file, bytes) writes[file] = bytes; return true end
function fs.createDirectory() return true end
function fs.remove(file) writes[file] = nil; return true end
function fs.rename(a, b) writes[b], writes[a] = writes[a], nil; return true end
function fs.getInfo(file)
  if writes[file] then return { type = "file", size = #writes[file] } end
  if file == "mods" then return { type = "directory" } end
  return Fs.getInfo(resolve(file))
end
function fs.getDirectoryItems(file)
  if file == "mods" then return { "kanto_gear" } end
  return Fs.getDirectoryItems(resolve(file))
end
local run = T.sdk.loadMod(path, { generation = 3, data = data, fs = fs })
T.eq(run.mod and run.mod.state, "loaded", "Kanto Gear loads on Gen 3")
local raw = setmetatable({ generation = 3, data = data, phase = "boot" }, { __index = require("src.core.Game3") })
run.loader.game = raw
run.loader.events:emit("game.ready", { game = raw })
local upvalue = assert(loadfile(path .. "/tests/support/runtime.lua"))().get
local hook
for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
  if entry.owner == "kanto_gear" then hook = entry.callback end
end
local display = assert(upvalue(hook, "displayRuntime"))
T.check(display.shinyHuntSupported(), "Shiny Hunt support is known before a save is loaded")
T.check(not display.storeById.shiny.hidden and not display.homeCatalog.surfaces.shiny_app.hidden
  and not display.homeCatalog.surfaces.shiny_widget.hidden, "the Store and Home offer Shiny Hunt on Gen 3")
local session = Schema.newGame({ version = edition, name = "HUNTER", rngSeed = 77 })
local Json = require("src.import.canonical_json")
local Party = require("src.core.game3.party")
Party.giveMon(session, 132, 20) -- Ditto
Party.giveMon(session, 25, 18) -- Pikachu
Party.giveMon(session, 19, 9) -- Rattata
raw.session, raw.save, raw.phase = session, Schema.toSaveTable(session), "field"
require("src.core.game3.runtime").session = session
run.loader.events:emit("map.entered", { mapId = session.map, game = raw })
T.check(display.gen3 and display.gen3.session == session, "the native session is adopted")


local P = require("src.core.game3.pokemon")
local Hunt = display.ShinyHunt
local function shinyMon(mon, shiny)
  mon.isShiny = nil
  mon.otId, mon.otSecretId = 0x00030002, nil
  -- tid 2 ^ sid 3 ^ high ^ low < 8 is shiny.
  mon.personality = shiny and 0x00010000 or 0x12345678
  return mon
end
T.check(P.isShiny(shinyMon({ species = 19, level = 5 }, true)), "the fixture builds a native shiny")
T.check(not P.isShiny(shinyMon({ species = 19, level = 5 }, false)), "the fixture builds a native plain Pokemon")

display.homeCatalog.packages.shiny.installed = true
T.check(display.openHomeApp("shiny"), "Shiny Hunt opens on Gen 3")
T.check(pcall(display.drawShinyHunt), "the Gen 3 picker draws")
Hunt.setTarget(display.shinyHunt.data, 19, nil, os.time())

-- Wild battles: the host's payload carries the battle state with its enemy.
local function battle(mon, kind)
  local st = { enemy = { mon = mon } }
  run.loader.events:emit("battle.started", { kind = kind or "wild", battle = st, species = mon.species })
  run.loader.events:emit("battle.ended", { battle = st, result = "run" })
end
battle(shinyMon({ species = 19, level = 3 }, false))
battle(shinyMon({ species = 16, level = 3 }, false))
battle(shinyMon({ species = 19, level = 3 }, false), "trainer")
local model = display.shinyHuntModel()
T.eq(model.hunt.count, 1, "one wild Rattata is one encounter")
T.eq(model.hunt.others, 1, "another species is kept apart")
T.check(model.hunt.name and model.hunt.name ~= "19", "the target is named by the game: " .. tostring(model.hunt.name))
battle(shinyMon({ species = 16, level = 3 }, true))
T.eq(display.shinyHuntModel().hunt.phases, 1, "an off-target native shiny is a phase")
battle(shinyMon({ species = 19, level = 3 }, true))
model = display.shinyHuntModel()
T.check(model.hunt.found ~= nil and model.hunt.found.count == 2, "a native shiny Rattata ends the hunt")
T.check(pcall(display.drawShinyHunt), "the Gen 3 find draws")

-- Hatches read the native party slot the host names.
Hunt.setTarget(display.shinyHunt.data, 25, nil, os.time())
shinyMon(session.party[2], false)
run.loader.events:emit("egg.hatched", { slot = 2, species = 25 })
local hunt = Hunt.active(display.shinyHunt.data)
T.eq(hunt.hatches, 1, "a Gen 3 hatch counts at full odds")
T.eq(hunt.boosted, 0, "Gen 3 has no shiny-parent boost")
T.eq(display.shinyBreedingBoost(), nil, "the Odds page shows no Gen 2 breeding rule on Gen 3")
display.shinyHuntAction("view", "odds")
T.check(pcall(display.drawShinyHunt), "the Gen 3 odds page draws")
display.shinyHuntAction("view", "log")
T.check(pcall(display.drawShinyHunt), "the Gen 3 log draws")
local tile = { id = "shiny_widget", kind = "widget", widget = "shiny", column = 1, row = 1, columns = 12 }
local theme = upvalue(display.drawShinyHunt, "THEME").hgss
T.check(pcall(theme.homeShinyHunt, theme, { shiny = display.shinyHuntModel() }, tile, false), "the Gen 3 widget draws")

T.finish("Gen 3 Shiny Hunt")
