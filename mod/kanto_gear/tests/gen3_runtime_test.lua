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
-- Isolate tool storage while loading the actual packaged manifest.
local Fs = require("tests.fs_io").new(path)
local fs, writes = {}, {}
local function resolve(file)
  return file:gsub("^mods/kanto_gear/?", "")
end
function fs.read(file)
  local bytes = writes[file] or Fs.read(resolve(file))
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
run.loader.events:emit("save.created", { save = session })
T.eq(display.gen3.session, nil, "created event does not adopt the old host session")
raw.session, raw.save, raw.phase = session, Schema.toSaveTable(session), "field"
require("src.core.game3.runtime").session = session
run.loader.events:emit("map.entered", { mapId = session.map, game = raw })
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
local Space = require("src.core.game3.scripting.space")
local oldActive, oldStore = Space.active, Space.store
Space.active, Space.store = true, { flags = { [0x824] = true }, vars = {} }
T.check(display.gen3:badge(5) and not session.flags[0x824], "fresh unsaved badge comes from the running script store")
Space.active, Space.store = oldActive, oldStore
local Notes = display.notes
Notes:action("new"); Notes:type("FRLG persistence"); Notes:action("finish"); Notes:flush(true)
T.check(not Notes.error and raw.save.meta == session.meta, "Notes storage identity is attached to the live session")
local reloaded = { generation = 3, save = Schema.toSaveTable(Schema.fromSaveTable(Schema.toSaveTable(session))) }
Notes:bind(reloaded, upvalue(display.saveHome, "mod").storage)
T.eq(Notes.records[1] and Notes.records[1].title, "FRLG persistence", "Notes survive native save serialization and reload")
local another = Schema.newGame({ version = session.version, name = "OTHER", rngSeed = 9000 })
run.loader.events:emit("save.created", { save = another })
T.eq(Notes.records[1] and Notes.records[1].title, "FRLG persistence", "pre-field event cannot rebind the old playthrough")
T.check(another.meta.playthroughId ~= session.meta.playthroughId, "new game receives its own tool identity")
local fresh = { save = Schema.toSaveTable(another) }
raw.session, raw.save = another, fresh.save
require("src.core.game3.runtime").session = another
run.loader.events:emit("map.entered", { mapId = another.map, game = raw })
T.eq(#Notes.records, 0, "another native playthrough cannot inherit Notes")
T.eq(display.gen3BoundSession, another, "new field binds storage to the new session")
raw.session, raw.phase = session, "quest_log"
run.loader.events:emit("save.loaded", { save = session })
display.gen3:refresh()
T.eq(display.gen3BoundSession, another, "quest log reads cannot prematurely rebind tool storage")
raw.save, raw.phase = Schema.toSaveTable(session), "field"
require("src.core.game3.runtime").session = session
run.loader.events:emit("map.entered", { mapId = session.map, game = raw })
T.eq(Notes.records[1] and Notes.records[1].title, "FRLG persistence", "field entry restores the continued playthrough's Notes")
local Stack = require("src.ui.game3.stack")
Stack.push("test-native-modal", {})
display.gen3.syncScreens()
T.eq(display.gen3:gameView().stack:top().screenId, "Gen3:test-native-modal", "unknown native modal cannot masquerade as legacy input owner")
Stack.clear()
local Field = require("src.core.game3.field")
local originalLocked, handoffs, fallbackIndex, fallback = Field.locked, 0
for i = 1, debug.getinfo(display.drawContents, "u").nups do
  local name, value = debug.getupvalue(display.drawContents, i)
  if name == "drawTopSummaryControls" then fallbackIndex, fallback = i, value end
end
debug.setupvalue(display.drawContents, assert(fallbackIndex), function(...)
  handoffs = handoffs + 1
  return fallback(...)
end)
Field.locked = true
display.gen3.syncScreens(); display.drawContents()
T.eq(handoffs, 0, "field script/warp lock retains the companion page instead of flashing a handoff")
T.check(display.backgroundDim > 0, "field script still dims and locks the companion controls")
local fieldMessage = require("src.ui.game3.message")
fieldMessage.show("A field conversation.", { speed = 0 })
display.gen3.syncScreens(); display.drawContents()
T.eq(handoffs, 0, "ordinary field dialogue retains the companion rather than a menu handoff")
fieldMessage.reset()
Stack.push("test-native-modal", {})
display.gen3.syncScreens(); display.drawContents()
T.eq(handoffs, 1, "unadapted native menus still show the handoff controls")
Stack.clear(); Field.locked = originalLocked
display.gen3.syncScreens()
debug.setupvalue(display.drawContents, fallbackIndex, fallback)
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
NativeParty.mode = "choose_multi"
menu = display.startMenu()
display.StartMenu.select(menu, #menu.items - 1)
T.eq(NativeParty.cursor, 7, "multi-party confirmation retains native slot seven")
display.StartMenu.select(menu, #menu.items)
T.eq(NativeParty.cursor, 8, "multi-party cancellation retains native slot eight")
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
display.gen3.syncScreens()
T.check(display.useBagItem(4), "Gear Bag hands the selected item to the native bag")
T.eq(NativeBag.currentPocket(), "POKE_BALLS", "handoff uses the actual pocket")
T.eq(NativeBag.list()[NativeBag.cursor].id, 4, "handoff retains the chosen item")
NativeBag.close()
for _, container in ipairs({ { 341, "tm_case" }, { 139, "berry_pouch" } }) do
  Bag.add(session.bag, container[1], 1); display.gen3:refresh()
  display.gen3.syncScreens()
  T.check(display.useBagItem(container[1]), "Gear opens native " .. container[2])
  local menu = display.startMenu()
  T.check(menu and #menu.items == 2, "subcontainer mirrors item and cancel")
  local native = require("src.ui.game3." .. container[2])
  native.mode = "action"
  T.check(display.startMenu() ~= nil, "subcontainer action menu is mirrored")
  native.mode = "message"
  T.check(display.startMenu() == nil, "subcontainer message retains native ownership")
  native.close()
end
local Choice = require("src.ui.game3.choice")
local picked
Choice.multi({ "FIRST", "SECOND", "THIRD" }, 0, function(value) picked = value end)
local choiceMenu = display.startMenu()
T.check(choiceMenu and display.StartMenu.select(choiceMenu, 3), "native multichoice accepts the mirrored cursor")
Choice.confirm()
T.eq(picked, 2, "native multichoice preserves zero-based script result")
T.check(not display.StartMenu.select(choiceMenu, 1), "dismissed choice cannot change a later cursor")
T.check(display.homeCatalog.packages.achievements.available == false,
  "unported native completion cannot issue false gold stamps")
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
local tap = upvalue(upvalue(compose, "touchEvent"), "tap")
local tapBattle = upvalue(tap, "tapBattle")
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
run.loader.modOptions.kanto_gear = run.loader.modOptions.kanto_gear or {}
run.loader.modOptions.kanto_gear.battle_view = "standard"
run.loader.modOptions.kanto_gear.theme_v3 = "hgss"
run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
paintBattle("native battle commands")
-- Every real Oak page, including the voiceovers which leave the command
-- cursor open underneath. Never treat the second source line as a new log item.
local Message = require("src.ui.game3.message")
local Oak = require("src.core.game3.battle.oak_advice")
local theme = upvalue(display.drawContents, "THEME")
for key in pairs(Oak.TEXT) do
  for _, text in ipairs(Oak.pages({ playerName = "RED" }, key) or {}) do
    Message.show(text, { frame = "voiceover", speed = 0 })
    for pageIndex = 1, #Message._pages do
      Message._page = pageIndex; Message.skipReveal()
      display.gen3.syncScreens(); refreshBattle()
      local snap = upvalue(refreshBattle, "battle")
      local plain = display.gen3:messageText()
      T.eq(snap.prompt, "advance", "Oak page covers the command menu: " .. key)
      T.eq(snap.message[1], plain, "Oak page retains both native lines: " .. key)
      local lines = theme:wrapText(plain, 192, nil, function(s) return theme.hgss:labelWidth(s) end)
      T.check(#lines <= 6, "complete Oak page fits without dropping words: " .. key)
      T.check(pcall(display.drawContents), "Oak page renders: " .. key)
    end
    Message.reset()
  end
end
Message.show("FIRST LINE\nA LONG SECOND LINE THAT MUST NOT ERASE THE FIRST", { frame = "battle", speed = 1 })
refreshBattle()
local typing = upvalue(refreshBattle, "battle")
T.check(typing.nativeCanReveal and typing.prompt == "locked", "typing can be completed without submitting a command")
Message.skipReveal(); refreshBattle()
T.eq(upvalue(refreshBattle, "battle").prompt, "advance", "finished printer refreshes continue even on the same page")
Message.show("{COLOR RED}POKEMON {PK}{MN}", { frame = "battle", speed = 0, stay = true })
refreshBattle()
T.eq(display.gen3:messageText(), "POKEMON PKMN", "printer controls are removed and ligatures retained")
T.eq(upvalue(refreshBattle, "battle").prompt, "locked", "timed stay pages do not promise a continue action")
Message.reset(); display.gen3.syncScreens(); refreshBattle()
local owns = display.gen3Presentation.owns
local restore = {}
for i = 1, debug.getinfo(owns, "u").nups do
  local name, value = debug.getupvalue(owns, i)
  if name == "active" or name == "displayReady" or name == "hasDisplay" then
    restore[#restore + 1] = { i, value }
    debug.setupvalue(owns, i, name == "hasDisplay" and function() return true end or true)
  end
end
for _, mode in ipairs({ "standard", "info", "gear", "full" }) do
  run.loader.modOptions.kanto_gear.battle_view = mode
  T.eq(owns("panel"), mode == "gear" or mode == "full", mode .. " native panel ownership")
  T.eq(owns("hud"), mode == "full", mode .. " native healthbox ownership")
end
Stack.push("unknown-battle-modal", {})
T.check(not owns("panel") and not owns("hud"), "unadapted windows keep native presentation")
Stack.clear()
local Growth = require("src.ui.game3.stat_growth")
Growth.open(session.party[1], {}, {})
T.check(not owns("panel"), "unadapted native stat window is not hidden")
Growth.close({ silent = true })
st.double = true
T.check(not owns("hud"), "doubles retain all four native healthboxes")
st.double = nil
local Anim = require("src.core.game3.battle.anim")
local present = Anim.present("player")
local previousHp = present.displayHp
local busy = Anim.busy
Anim.busy = function() return true end
Message.show("CHARMANDER used\nSCRATCH!", { frame = "battle", speed = 0, stay = true })
display.gen3.syncScreens(); refreshBattle()
local oldStatuses, displayed = theme.hgss.battleFullStatuses
theme.hgss.battleFullStatuses = function(self, player, enemy, portrait, playerTeam, enemyTeam, lines)
  displayed = lines
  return oldStatuses(self, player, enemy, portrait, playerTeam, enemyTeam, lines)
end
display.drawContents()
T.check(displayed and table.concat(displayed, " "):find("SCRATCH!", 1, true),
  "Full Gear retains native move text alongside draining HP")
theme.hgss.battleFullStatuses = oldStatuses
Message.reset(); Anim.busy = busy
present.displayHp = 7.9; refreshBattle()
T.eq(upvalue(refreshBattle, "battle").player.hp, 7, "Gear follows animated HP rather than jumping to the result")
present.displayHp = previousHp
local previousStatus = session.party[1].status
session.party[1].status = 0; display.gen3:refresh(); refreshBattle()
T.eq(upvalue(refreshBattle, "battle").player.status, nil, "healthy native bitfield is not printed as zero")
session.party[1].status = 0x40; display.gen3:refresh(); refreshBattle()
T.eq(upvalue(refreshBattle, "battle").player.status, "PAR", "native status bitfield becomes a readable condition")
session.party[1].status = previousStatus
for _, row in ipairs(restore) do debug.setupvalue(owns, row[1], row[2]) end
run.loader.modOptions.kanto_gear.battle_view = "standard"
display.gen3:refresh(); display.gen3.syncScreens(); refreshBattle()
tapBattle(62 / 1.5, 76 / 1.5)
T.eq(Ui._mode, "moves", "FIGHT opens the actual native move menu")
paintBattle("native move selection")
for _, move in ipairs(upvalue(refreshBattle, "battle").moves) do
  T.eq(move.type, display.gen3.data.moves[move.id].type, "battle move retains its native type: " .. move.id)
end
submit("back"); refreshBattle()
tapBattle(178 / 1.5, 76 / 1.5)
paintBattle("native battle party")
T.check(display.startMenu() ~= nil, "battle party uses its actual display order")
NativeParty.close(); Ui.openMenu(0); display.gen3.syncScreens(); refreshBattle()
tapBattle(62 / 1.5, 167 / 1.5)
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
st = State.new({ playerParty = session.party, foeParty = foes.party, wild = true })
st.safari, st.safariState = true, { balls = 23 }
Battle._st = st
for i, action in ipairs({ "ball", "bait", "rock", "run" }) do
  Ui.reset({ headless = true }); Ui.bindState(st, session); Ui.openMenu(0)
  paintBattle("native safari " .. action)
  local snapshot = upvalue(refreshBattle, "battle")
  T.eq(snapshot.prompt, "safari", "native Safari uses four Safari actions")
  T.eq(snapshot.safariBalls, 23, "Safari ball count comes from the native battle")
  local submitGear = upvalue(tapBattle, "submit")
  submitGear("safari", { action = action })
  local command = Ui._pendingCommand
  T.check(command and (action == "run" and command.safariRun
    or command.kind == "safari" and command.action == action), "Gear Safari submits native " .. action)
end
Battle._active, Battle._st = false, nil
T.eq(display.gen3:battleSnapshot({ prompt = "locked" }), nil,
  "inactive battle cannot leak a stale snapshot into a field transition")
Ui.reset({ headless = true }); Stack.clear(); display.gen3.syncScreens(); refreshBattle()
T.check(not display.gen3:gameView().stack:top().nativeModal, "field has no modal handoff marker")
display.gen3:refresh()
if type(_G.KANTO_GEAR_RENDER_CAPTURE) == "function" then
  _G.KANTO_GEAR_RENDER_CAPTURE(run, display, raw, maps)
end
T.eq(#run.errors, 0, "runtime event paths contain no errors")
run.release()
T.finish("Kanto Gear native Gen3 runtime")
