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
local Fs = require("tests.fs_io").new(path)
local fs, writes = {}, {}
local function resolve(file)
  return file:gsub("^mods/kanto_gear/?", "")
end
function fs.read(file)
  local bytes = writes[file] or Fs.read(resolve(file))
  if file == "mods/kanto_gear/manifest.json" then
    bytes = bytes:gsub('"gen1", "gen2"', '"gen1", "gen2", "gen3"')
  end
  return bytes
end
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
local Start = require("src.ui.game3.start_menu")
Start.show({ session = session, game = raw })
local menu = display.startMenu()
T.check(menu and #menu.items == #Start.ENTRIES, "native start order is mirrored")
T.check(display.StartMenu.select(menu, #menu.items), "touch selection accepts native start entry")
T.eq(Start.cursor, #Start.ENTRIES, "touch cursor reaches the actual native menu")
Start.close(true)
T.check(not display.StartMenu.select(menu, 1), "stale menu cannot move a different native screen")
local NativeParty = require("src.ui.game3.party_menu")
NativeParty.show(session.party, { session = session })
menu = display.startMenu()
T.check(menu and #menu.items == #session.party + 1, "native party plus cancel is mirrored")
display.StartMenu.select(menu, #menu.items)
T.eq(NativeParty.cursor, 7, "party cancel retains reserved native slot seven")
NativeParty.mode = "message"
T.check(display.startMenu() == nil, "party message cannot accept stale party selection")
NativeParty.close()
local NativeBag = require("src.ui.game3.bag_menu")
NativeBag.show(session.bag, { session = session, pocket = "POKE_BALLS" })
T.check(display.startMenu() == nil, "opening bag cannot accept touch before native transition")
NativeBag.settle()
menu = display.startMenu()
T.eq(menu and menu.items[1].itemId, 4, "native ball pocket rows are mirrored without reordering")
T.eq(menu and menu.items[1].right, "x35", "native quantity is shown")
NativeBag.close()
local NativeSummary = require("src.ui.game3.summary_menu")
T.check(display.openPartySummary(1), "Gear opens the actual native summary")
for page = 0, 2 do
  NativeSummary._page = page
  display.gen3.syncScreens()
  local view = display.gen3:gameView().stack:top()
  T.eq(view.screenId, "Gen3SummaryMenu", "native summary owns its projection")
  local ok, err = pcall(display.drawContents)
  T.check(ok, "native summary page renders: " .. tostring(err))
end
NativeSummary.close()
local Battle = require("src.core.game3.battle")
local Ui = require("src.core.game3.battle.ui")
local State = require("src.core.game3.battle.state")
local Api = require("src.battle.game3.BattleAPI").new(raw)
local Party = require("src.core.game3.party")
Party.giveMon(session, 4, 20)
local foes = Schema.newGame({ version = os.getenv("POKEPORT_VERSION"), name = "FOE", rngSeed = 3000 })
Party.giveMon(foes, 16, 15); Party.giveMon(foes, 19, 15)
local st = State.new({ playerParty = session.party, foeParty = foes.party, wild = true })
Battle._active, Battle._auto, Battle._phase, Battle._st = true, false, "command", st
Ui.reset({ headless = true }); Ui.bindState(st, session); Ui.openMenu(0)
local compose
for _, entry in ipairs(run.loader.hooks.chains["render.compose"] or {}) do
  if entry.owner == "kanto_gear" then compose = entry.callback end
end
local refreshBattle = assert(upvalue(compose, "refreshBattle"))
local intentId = 0
local function submit(kind, fields)
  fields = fields or {}
  intentId = intentId + 1
  fields.id, fields.revision, fields.kind = intentId, Api:snapshot().revision, kind
  local ok, err = Api:submit(fields)
  T.check(ok, "native battle accepts " .. kind .. ": " .. tostring(err))
end
local function paintBattle(label)
  display.gen3.syncScreens(); refreshBattle()
  local state = display.gen3:battleState()
  T.check(state and state.nativeGen3 and state.battle == st, label .. " has the live native battle")
  local snapshot = upvalue(refreshBattle, "battle")
  T.check(snapshot and snapshot.player and snapshot.player.source, label .. " uses the projected native Pokemon")
  local ok, err = pcall(display.drawContents)
  T.check(ok, label .. " renders: " .. tostring(err))
end
paintBattle("native battle commands")
submit("menu", { choice = "fight" })
T.eq(Ui._mode, "moves", "FIGHT opens the actual native move menu")
paintBattle("native move selection")
submit("back")
submit("menu", { choice = "party" })
paintBattle("native battle party")
T.check(display.startMenu() ~= nil, "battle party uses its actual display order")
NativeParty.close(); Ui.openMenu(0)
submit("menu", { choice = "item" })
NativeBag.settle(); paintBattle("native battle bag")
T.check(display.startMenu() ~= nil, "battle Bag uses native pocket data")
NativeBag.close()
session.party[2].moves[1], session.party[2].pp[1] = 33, 35
st = State.new({ playerParty = session.party, foeParty = foes.party, double = true })
Battle._st = st
Ui.reset({ headless = true }); Ui.bindState(st, session); Ui.openMenu(2)
T.check(Ui.chooseTarget(st, 2, 1), "native double battle asks for a target")
paintBattle("native doubles targets")
local targets = display.startMenu()

T.check(targets and #targets.items == 3, "target list excludes the user for an opponent-selected move")
T.eq(targets and targets.battleTargets[1], 0, "ally retains native battler ID zero")
submit("target", { target = 3 })
T.eq(Ui._pendingCommand and Ui._pendingCommand.target, 3, "target command reaches right-hand opponent")
Battle._active, Battle._st = false, nil
Ui.reset({ headless = true }); Stack.clear(); display.gen3.syncScreens(); refreshBattle()
display.gen3:refresh()
if type(_G.KANTO_GEAR_RENDER_CAPTURE) == "function" then
  _G.KANTO_GEAR_RENDER_CAPTURE(run, display, raw, maps)
end
T.eq(#run.errors, 0, "runtime event paths contain no errors")
run.release()
T.finish("Kanto Gear native Gen3 runtime")
