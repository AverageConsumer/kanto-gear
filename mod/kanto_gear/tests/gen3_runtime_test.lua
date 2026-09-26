local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
-- LÖVE provides this primitive; the SDK's lightweight stub predates its use.
love.graphics.arc = love.graphics.arc or function() end
-- Reuse the real-ROM fixture setup and invariants in a separate Lua process.
dofile(path .. "/tests/gen3_native_test.lua")
local Dataset = require("src.core.game3.dataset")
local Schema = require("src.core.game3.save_schema_firered")
local maps = Dataset.buildMaps()
Dataset.attachMidLayouts(maps, Dataset.cache())
local data = { maps = maps,
  gen3Encounters = assert(loadfile(os.getenv("POKEPORT_GBA_CACHE") .. "/encounters.lua"))() }
-- Enable Gen 3 only for this test. The release manifest remains conservative
-- while native screen/input ownership is still being ported.
local Fs = require("tests.fs_io").new(".")
local fs = {}
local function resolve(file)
  return file:gsub("^mods/kanto_gear", function() return path end)
end
function fs.read(file)
  local bytes = Fs.read(resolve(file))
  if file == "mods/kanto_gear/manifest.json" then
    bytes = bytes:gsub('"gen1", "gen2"', '"gen1", "gen2", "gen3"')
  end
  return bytes
end
function fs.load(file)
  local bytes = fs.read(file)
  return bytes and load(bytes, "@" .. file)
end
function fs.write(file, bytes) return Fs.write(resolve(file), bytes) end
function fs.getInfo(file)
  if file == "mods" then return { type = "directory" } end
  return Fs.getInfo(resolve(file))
end
function fs.getDirectoryItems(file)
  if file == "mods" then return { "kanto_gear" } end
  return Fs.getDirectoryItems(resolve(file))
end
local run = T.sdk.loadMod(path, { generation = 3, data = data, fs = fs })
T.eq(run.mod and run.mod.state, "loaded", "native Gen3 test build loads")
for _, err in ipairs(run.errors) do print(err.message or err.error or tostring(err)) end
local raw = { generation = 3, data = data, phase = "boot" }
run.loader.game = raw
run.loader.events:emit("game.ready", { game = raw })
local function upvalue(fn, target)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, i)
    if name == target then return value end
  end
end
local hook
for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
  if entry.owner == "kanto_gear" then hook = entry.callback end
end
local display = assert(upvalue(hook, "displayRuntime"))
T.check(display.gen3 ~= nil, "native adapter selected")
T.check(display.sourceGame == raw, "host input keeps original identity")
local session = Schema.newGame({ version = os.getenv("POKEPORT_VERSION"), name = "RUNTIME", rngSeed = 2000 })
require("src.core.game3.party").giveMon(session, 1, 15)
local Bag = require("src.core.game3.bag")
Bag.add(session.bag, 4, 35)
raw.session, raw.save, raw.phase = session, Schema.toSaveTable(session), "field"
require("src.core.game3.runtime").session = session
run.loader.events:emit("save.created", { game = raw })
T.eq(display.gen3.save.player.name, "RUNTIME", "new-game event refreshes live projection")
T.eq(display.bagSummary().ball, 35, "existing Bag widget reads native ball quantity")
T.eq(display.pokedexData().total, 151, "Dex respects the Kanto unlock limit")
session.dex.national = true
display.gen3:refresh()
T.eq(display.pokedexData().total, 386, "National Dex unlock expands the catalogue")
T.eq(display.bagModel().pockets, 5, "native bag retains all five pockets")
T.eq(display.gen3:gameView().stack:top(), display.gen3:gameView().world, "native field has an active presentation state")
session.money = 9999
display.gen3:refresh()
T.eq(display.trainerSummary().money, "¥9999", "existing trainer model reads unsaved native money")
require("src.core.game3.scripting.flags").setFlag(session, nil, 0x820, true)
display.gen3:refresh()
T.eq(display.trainerSummary().badgeCount, 1, "trainer uses native badge flags")
T.eq(display.trainerSummary().badgeTotal, 8, "FRLG has eight badges")
local Stack = require("src.ui.game3.stack")
Stack.push("test-native-modal", {})
display.gen3.syncScreens()
T.eq(display.gen3:gameView().stack:top().screenId, "Gen3:test-native-modal", "unknown native modal cannot masquerade as legacy input owner")
Stack.clear()
-- Exercise all independent read screens through the real Gear draw dispatcher.
for _, id in ipairs({ "party", "trainer", "bag", "pokedex", "settings", "notes" }) do
  display.setPackageInstalled(id, true)
  local opened = display.openHomeApp(id)
  local ok, err = pcall(display.drawContents)
  T.check(opened and ok, id .. " renders from the native session: " .. tostring(err))
end
T.eq(#run.errors, 0, "runtime event paths contain no errors")
run.release()
T.finish("Kanto Gear native Gen3 runtime")
