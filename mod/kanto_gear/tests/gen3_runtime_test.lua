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
local six = {}
for i = 1, 6 do six[i] = session.party[1] end
NativeParty.show(six, { session = session })
for slot = 1, 7 do
  NativeParty.cursor = slot
  local projected = display.startMenu()
  local model = display.startMenuModel(projected)
  T.eq(#model.entries, 7, "all native party slots and cancel remain visible")
  local row = model.entries[slot]
  T.check(row.selected, "party highlight follows native slot " .. slot)
  T.eq(display.StartMenu.hit(projected, row.x + row.w / 2, row.y + row.h / 2), slot,
    "party touch geometry selects native slot " .. slot)
end
NativeParty.cursor = 5
NativeParty.handleInput({ wasPressed = function(_, key) return key == "left" end,
  isDown = function() return false end })
T.eq(NativeParty.cursor, 1, "native Left reaches the separately displayed lead")
NativeParty.handleInput({ wasPressed = function(_, key) return key == "right" end,
  isDown = function() return false end })
T.eq(NativeParty.cursor, 5, "native Right returns to the last selected right-column member")
NativeParty.close()
local NativeBag = require("src.ui.game3.bag_menu")
NativeBag.show(session.bag, { session = session, pocket = "POKE_BALLS" })
menu = display.startMenu()
T.check(menu and display.startMenuModel(menu), "opening bag previews its list instead of a handoff")
T.check(not display.StartMenu.cursor(menu), "opening bag cannot accept touch before native transition")
local openingBag = NativeBag._open
for _, phase in ipairs({ "_open", "_switch", "_exit" }) do
  NativeBag._open, NativeBag._switch, NativeBag._exit = nil, nil, nil
  NativeBag[phase] = {}
  local preview = display.startMenu()
  T.check(preview and display.startMenuModel(preview), phase .. " retains the native bag rows")
  T.check(not display.StartMenu.select(preview, 2), phase .. " cannot change native focus")
  T.eq(display.StartMenu.hit(preview, 10, 10), nil, phase .. " blocks back navigation")
end
NativeBag._open, NativeBag._switch, NativeBag._exit = openingBag, nil, nil
NativeBag.settle()
menu = display.startMenu()
T.eq(menu and menu.items[1].itemId, 4, "native ball pocket rows are mirrored without reordering")
T.eq(menu and menu.items[1].right, "x35", "native quantity is shown")
NativeBag.showMessage("It won't have any effect.")
local fieldNotice = display.startMenu()
T.check(fieldNotice and fieldNotice.notice, "field Bag notices are also projected")
local noticeDrawn, noticeError = pcall(display.drawContents)
T.check(noticeDrawn, "field notice renders without a battle: " .. tostring(noticeError))
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
T.check(display.homeCatalog.packages.achievements.available == true,
  "native progress enables the stamp app and widget")
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
  T.eq(owns("navigation"), mode == "full", mode .. " command navigation authority")
  for index = 1, 4 do
    for _, direction in ipairs({ "up", "down", "left", "right" }) do
      Ui._menuIndex = index
      local semantic = ({ 1, 3, 2, 4 })[index]
      local columnChange = direction == "left" or direction == "right"
      local expected = columnChange and (index % 2 == 1 and index + 1 or index - 1)
        or (index <= 2 and index + 2 or index - 2)
      if mode == "full" then
        local nextSemantic = columnChange and (semantic % 2 == 1 and semantic + 1 or semantic - 1)
          or (semantic <= 2 and semantic + 2 or semantic - 2)
        expected = ({ 1, 3, 2, 4 })[nextSemantic]
      end
      Ui.handleInput({ wasPressed = function(_, key) return key == direction end })
      T.eq(Ui._menuIndex, expected, mode .. " native command " .. index .. " " .. direction)
    end
  end
end
Ui._menuIndex = 1; refreshBattle()
local runtime = assert(upvalue(hook, "hgssRuntime"))
local P = display.gen3.Pokemon
local nativeFront, captured = P.frontPic
P.frontPic = function(id, form, shiny, personality)
  captured = { id = id, shiny = shiny, personality = personality }
  return nil
end
runtime.battlePortrait(runtime.battleMon(), 0, 0, 64, false)
T.eq(captured.shiny, P.isShiny(session.party[1]), "battle portrait retains the real shiny flag")
T.eq(captured.personality, session.party[1].personality, "battle portrait retains the real personality")
local normalPersonality = session.party[1].personality
session.party[1].personality = require("bit").bxor(session.party[1].otId or 0, session.party[1].otSecretId or 0)
refreshBattle()
runtime.battlePortrait(runtime.battleMon(), 0, 0, 64, false)
T.eq(captured.shiny, true, "a real shiny keeps its shiny portrait")
session.party[1].personality = normalPersonality
refreshBattle()
P.frontPic = nativeFront
local originalMoves = session.party[1].moves
for _, mode in ipairs({ "standard", "gear", "full" }) do
  run.loader.modOptions.kanto_gear.battle_view = mode
  for count = 1, 4 do
    session.party[1].moves = {}
    for i = 1, count do session.party[1].moves[i] = 33 end
    Ui._mode = "moves"; refreshBattle()
    for slot = 1, count do
      for _, direction in ipairs({ "up", "down", "left", "right" }) do
        Ui._moveIndex = slot
        local horizontal = direction == "left" or direction == "right"
        local expected = horizontal and (slot % 2 == 1 and slot + 1 or slot - 1)
          or (slot <= 2 and slot + 2 or slot - 2)
        if expected > count then expected = slot end
        Ui.handleInput({ wasPressed = function(_, key) return key == direction end })
        T.eq(Ui._moveIndex, expected, mode .. " " .. count .. " moves: " .. slot .. " " .. direction)
      end
    end
  end
end
session.party[1].moves = originalMoves
run.loader.modOptions.kanto_gear.battle_view = "full"
Ui._mode, Ui._menuIndex = "menu", 1; refreshBattle()
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
-- Live transitions must not briefly give native menu rendering back to the host.
for _, mode in ipairs({ "gear", "full" }) do
  run.loader.modOptions.kanto_gear.battle_view = mode
  for count = 1, 6 do
    local party = {}
    for i = 1, count do party[i] = session.party[(i - 1) % #session.party + 1] end
    NativeParty.show(party, { session = session, mode = "battle_switch" })
    T.check(owns("menu"), mode .. " owns the opening party before the next snapshot")
    local projected = display.startMenu()
    local model = display.startMenuModel(projected)
    for slot = 1, count do
      T.eq(model.entries[slot].h, model.entries[1].h, "all team cards have equal height")
      T.eq(model.entries[slot].w, model.entries[1].w, "all team cards have equal width")
      T.check(model.entries[slot].h <= 50, "small teams never get an oversized hero card")
    end
    NativeParty.cursor = count
    NativeParty.handleInput({ wasPressed = function(_, key) return key == "left" end })
    T.eq(NativeParty.cursor, mode == "full" and count or 1,
      mode .. " applies only its own party navigation contract")
    NativeParty.cursor = 1
    NativeParty.handleInput({ wasPressed = function(_, key) return key == "up" end })
    T.eq(NativeParty.cursor, 7, "Up from the first row reaches visible Cancel")
    NativeParty.cursor = 1
    local view = display.partyView(projected.items[1].mon)
    T.eq(view.name, display.gen3.Pokemon.displayName(party[1]), "party cards retain the actual name")
    T.check(type(view.expProgress) == "number", "party cards retain native experience progress")
    NativeParty.mode, NativeParty.ACTIONS = "action", { "SHIFT", "SUMMARY", "CANCEL" }
    local actions = display.startMenu()
    T.check(actions.partyActions ~= nil and owns("menu"), "party actions use the Gear detail card")
    for index, entry in ipairs(display.startMenuModel(actions).entries) do
      T.eq(display.StartMenu.hit(actions, entry.x + entry.w / 2, entry.y + entry.h / 2), index,
        "action touch matches its visible row")
    end
    NativeParty.mode = "battle_switch"
    NativeParty.startHpAnim(1, 1, 10, 20, function() end)
    T.check(owns("menu"), mode .. " keeps healing on Gear")
    T.check(display.startMenuModel(display.startMenu()) ~= nil, "healing retains party rendering")
    T.check(not display.StartMenu.cursor(display.startMenu()), "healing cannot select another Pokemon")
    NativeParty._hpAnim = nil
    NativeParty.showMessage("Already in battle!", function() NativeParty.mode = "battle_switch" end)
    projected = display.startMenu()
    T.eq(projected.notice, "Already in battle!", "native switch refusal is readable below")
    T.check(owns("menu"), "party refusal never flashes the upper menu")
    NativeParty.handleInput({ wasPressed = function(_, key) return key == "a" end })
    T.check(owns("menu") and display.startMenu().party ~= nil, "dismissal returns straight to party")
    T.check(not projected.valid(), "dismissed notice cannot accept a second tap")
    local Summary = require("src.ui.game3.summary_menu")
    Summary.openMenu(party, 1, { session = session })
    Summary.handleInput({ wasPressed = function(_, key) return key == "right" end })
    T.check(Summary._slide.active, "fixture enters the real native summary slide")
    T.check(owns("menu"), "summary slides do not hand rendering back to the upper screen")
    Summary.close(); NativeParty.close()
  end
  NativeParty.show(session.party, { session = session, mode = "battle_switch" })
  NativeParty.mode, NativeParty._oakPage = "oak", 1
  NativeParty._oakPages = { "OAK: These are your POKEMON.", "Check their HP before switching." }
  NativeParty._oakFx = { phase = "darken", slot = 0, y = 0, counter = 0 }
  T.check(owns("menu") and not display.StartMenu.cursor(display.startMenu()),
    "Oak's opening party tutorial stays below while its native reveal is busy")
  NativeParty._oakFx.phase = "text"
  T.check(display.startMenu().canAdvance, "Oak tutorial advertises Continue only when native input accepts it")
  NativeParty.handleInput({ wasPressed = function(_, key) return key == "a" end })
  T.eq(display.startMenu().notice, NativeParty._oakPages[2], "Oak party tutorial advances to the actual next page")
  T.check(owns("menu"), "Oak's next page does not expose the party menu")
  NativeParty.close()
  NativeBag.show(session.bag, { session = session }); NativeBag.settle()
  NativeBag.showMessage("It won't have any effect.")
  T.eq(display.startMenu().notice, "It won't have any effect.", "native Bag refusal is mirrored")
  T.check(owns("menu"), "Bag notice never exposes the native menu")
  NativeBag.handleInput({ wasPressed = function(_, key) return key == "a" end })
  T.check(owns("menu") and not display.startMenu().notice, "Bag notice returns directly to its rows")
  NativeBag.close()
end
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
tapBattle(62 / 1.5, 167 / 1.5)
paintBattle("native battle party")
T.check(display.startMenu() ~= nil, "battle party uses its actual display order")
NativeParty.close(); Ui.openMenu(0); display.gen3.syncScreens(); refreshBattle()
tapBattle(178 / 1.5, 76 / 1.5)
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
T.eq(targets.battleTargets[2], 3, "target rows follow the native target cycle")
Ui.handleInput({ wasPressed = function(_, key) return key == "down" end })
local afterTarget = display.startMenu()
local nativeTarget = Ui._target.cursor
T.eq(afterTarget.battleTargets[afterTarget.index], nativeTarget, "native target highlight matches the displayed row")
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
-- Use the same event/coroutine/UI paths as the installed app and widget.
do
  local Flags = require("src.core.game3.scripting.flags")
  local oldMap, oldFlag = session.map, Flags.getFlag(session, nil, 340)
  session.map = "FR_ROUTE_2"
  run.loader.events:emit("map.entered", { game = raw, mapId = session.map })
  run.loader.modOptions.kanto_gear.info_level = "spoiler"
  T.check(display.setPackageInstalled("achievements", true), "native stamps install through Store")
  T.check(display.openHomeApp("achievements"), "native stamps app opens")
  local function album()
    for _ = 1, 2000 do
      local result = display.achievementData(false, true)
      if result then return result end
    end
    error("native stamp album never completed")
  end
  local function changed()
    run.loader.events:emit("flag.changed", {})
    T.eq(display.achievements.currentData, nil, "native flag clears widget snapshot")
    T.eq(display.achievements.job, nil, "native flag cancels old album job")
  end
  Flags.setFlag(session, nil, 340, false); changed()
  local current = display.currentAchievement().area
  T.eq(current.sections[2].done, 0, "current widget reads fresh route pickup state")
  T.check(display.achievementData() == nil, "album defers work until budgeted step")
  T.check(display.achievementModel().loading, "unfinished native totals are hidden")
  Flags.setFlag(session, nil, 340, true); changed()
  current = display.currentAchievement().area
  T.eq(current.sections[2].done, 1, "current widget updates immediately after pickup")
  local result = album()
  T.eq(result.byId[current.id].sections[2].done, 1, "album agrees with current widget")
  local theme = upvalue(display.drawContents, "THEME")
  for _, variant in ipairs({ "hgss", "hgss_dark" }) do
    run.loader.modOptions.kanto_gear.theme_v3 = variant
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = variant })
    for _, view in ipairs({ "album", "goals", "detail", "finds" }) do
      display.achievements.view, display.achievements.selected = view, current.id
      display.achievements.category, display.achievements.page = 2, 1
      local ok, err = pcall(function() theme.hgss:achievements(display.achievementModel()) end)
      T.check(ok, "native " .. variant .. " " .. view .. " renders: " .. tostring(err))
    end
  end
  -- Change the real serialization snapshot, then deliver the host load event.
  local saved = Schema.toSaveTable(session)
  local reloaded = Schema.fromSaveTable(saved)
  Flags.setFlag(reloaded, nil, 340, false)
  raw.session, raw.save = reloaded, Schema.toSaveTable(reloaded)
  require("src.core.game3.runtime").session = reloaded
  run.loader.events:emit("save.loaded", { save = reloaded })
  T.eq(display.currentAchievement().area.sections[2].done, 0, "older native save reverses widget pickup")
  T.eq(album().byId[current.id].sections[2].done, 0, "older native save reverses album pickup")
  raw.session, raw.save = session, saved
  require("src.core.game3.runtime").session = session
  Flags.setFlag(session, nil, 340, oldFlag)
  session.map = oldMap
  run.loader.events:emit("save.loaded", { save = session })
  run.loader.events:emit("map.entered", { game = raw, mapId = session.map })
end
if type(_G.KANTO_GEAR_RENDER_CAPTURE) == "function" then
  _G.KANTO_GEAR_RENDER_CAPTURE(run, display, raw, maps)
end
T.eq(#run.errors, 0, "runtime event paths contain no errors")
run.release()
T.finish("Kanto Gear native Gen3 runtime")
