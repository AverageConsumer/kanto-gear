local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
-- LÖVE provides this primitive; the SDK's lightweight stub predates its use.
love.graphics.arc = love.graphics.arc or function() end
-- Reuse the real-ROM fixture setup and invariants in a separate Lua process.
dofile(path .. "/tests/rs_native_test.lua")
-- Native RS skins read their manifests through LÖVE's mounted cache. Mirror
-- that mount in the headless stub; production still uses the real filesystem.
if love == require("tests.love_stub") then
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
if _G.KANTO_GEAR_BEFORE_LOAD then _G.KANTO_GEAR_BEFORE_LOAD() end
local run = T.sdk.loadMod(path, { generation = 3, data = data, fs = fs })
T.eq(run.mod and run.mod.state, "loaded", "native Gen3 test build loads")
run.loader.modOptions.kanto_gear = run.loader.modOptions.kanto_gear or {}
for _, err in ipairs(run.errors) do print(err.message or err.error or tostring(err)) end
local raw = setmetatable({ generation = 3, data = data, phase = "boot" },
  { __index = require("src.core.Game3") })
run.loader.game = raw
run.loader.events:emit("game.ready", { game = raw })
local upvalue = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local hook
for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
  if entry.owner == "kanto_gear" then hook = entry.callback end
end
local display = assert(upvalue(hook, "displayRuntime"))
T.check(display.gen3 ~= nil, "native adapter selected")
T.check(display.sourceGame == raw, "host input keeps original identity")
local titleCompat = assert(upvalue(assert(upvalue(display.drawContents, "drawTitle")), "compat"))
local editionCode = os.getenv("POKEPORT_VERSION") == "ruby" and "RU" or "SA"
T.eq(titleCompat.systemId(nil, "3.3.0"), "SLS-" .. editionCode .. "-3.3.0",
  "title identifier works before a save exists")
local session = Schema.newGame({ version = os.getenv("POKEPORT_VERSION"), name = "RUNTIME", rngSeed = 2000 })
require("src.core.game3.party").giveMon(session, 277, 15)
require("src.core.game3.party").giveMon(session, 25, 20)
local Bag = require("src.core.game3.bag")
Bag.add(session.bag, 4, 35)
run.loader.events:emit("save.created", { save = session })
T.eq(display.gen3.session, nil, "created event does not adopt the old host session")
raw.session, raw.save, raw.phase = session, Schema.toSaveTable(session), "field"
require("src.core.game3.runtime").session = session
run.loader.events:emit("map.entered", { mapId = session.map, game = raw })
T.eq(display.gen3.save.player.name, "RUNTIME", "new-game event refreshes live projection")

local C = require("src.core.game3.constants").of(session.version)
local P = require("src.core.game3.pokemon")
local Stack = require("src.ui.game3.stack")
local Screens = require("src.ui.game3.screens")
local function input(key)
  return { wasPressed = function(_, k) return key == k end, isDown = function() return false end }
end
T.eq(display.pokedexData().total, 202, "Hoenn regional catalogue")
T.eq(display.pokedexData().entries[1].species, P.speciesFromNational(252), "Treecko first")
T.eq(display.trainerSummary().region, "HOENN", "trainer region")
T.eq(display.bagSummary().ball, 35, "ball totals")
session.flags[C:flag("FLAG_BADGE01_GET")] = true
display.gen3:refresh()
T.eq(display.trainerSummary().badgeCount, 1, "native Stone Badge flag")
local NativeBag = require("src.ui.game3.bag_menu")
for _, name in ipairs({"ITEM_POTION", "ITEM_POKE_BALL", "ITEM_TM01_FOCUS_PUNCH", "ITEM_CHERI_BERRY", "ITEM_OLD_ROD"}) do
  local id = C:require("items", name)
  Bag.add(session.bag, id, 2); display.gen3:refresh()
  T.check(display.gen3Ui:openBagItem(id), "open " .. name)
  NativeBag.settle()
  T.eq(Stack.top().id, "bag", "RS keeps all five pockets in the native bag")
  Screens.handleInput("bag", NativeBag, input("a"), session)
  local menu = display.startMenu()
  T.check(menu and menu.itemActionId == id and menu.itemModel, "native item action projection " .. name)
  for index in ipairs(menu and menu.items or {}) do
    menu.index = index
    T.eq(NativeBag.actionCursor, index, "companion selection retains native action index")
    local grid = require("src.ui.game3.rs.bag_menu").grid(NativeBag, NativeBag.list()[NativeBag.cursor])
    local count = 0
    for cell, action in ipairs(grid.cells) do
      if action then count = count + 1 end
      if cell == NativeBag._rsBag.gridPos then T.eq(count, index, "RS grid follows selected touch action"); break end
    end
  end
  T.check(pcall(display.drawContents), "item action renders " .. name)
  NativeBag.close(); Stack.clear()
end
local Summary = require("src.ui.game3.summary_menu")
Summary.openMenu(session.party, 1, { session = session })
local rsSummary = require("src.ui.game3.rs.summary_menu")
for page = 0, 3 do
  rsSummary._page = page
  display.gen3.syncScreens()
  local top = display.gen3:gameView().stack:top()
  T.eq(top.page, page + 1, "RS native status page")
  T.eq(top.pages, 4, "RS has a contest page")
  T.check(pcall(display.drawContents), "RS status page renders " .. page)
end
rsSummary.reset(); Stack.clear()
local mon = session.party[1]
mon.moves, mon.pp = {15, 33, 45, 10}, {30, 35, 40, 35}
for _, selected in ipairs({2, 5}) do
  local calls, result = 0, nil
  Summary.openMenu(session.party, 1, { session = session, mode = "select_move", moveToLearn = 22,
    onSelectMove = function(slot) calls, result = calls + 1, slot end })
  T.check(not display.startMenu().valid(), "loading RS chooser rejects touch")
  for _ = 1, 120 do rsSummary.update() end
  local view = assert(display.startMenu())
  T.check(view.valid(), "settled RS chooser is actionable")
  T.eq(view.moveSelection.newMoveId, display.gen3.Moves.constName(22), "new move identity")
  T.check(display.StartMenu.select(view, 1), "native HM can be inspected for replacement")
  Screens.handleInput("summary", Summary, input("a"), session)
  T.eq(rsSummary._state, "notice", "RS refuses to forget an HM")
  T.check(not view.valid(), "HM notice invalidates old touch controls")
  for _ = 1, 4 do rsSummary.update() end
  view = assert(display.startMenu())
  T.check(view.prompt and #view.prompt > 0, "native HM refusal has an explanation")
  T.check(display.StartMenu.select(view, selected), "touch chooses another move or cancel after refusal")
  Screens.handleInput("summary", Summary, input(selected == 5 and "b" or "a"), session)
  for _ = 1, 120 do rsSummary.update() end
  T.eq(calls, 1, "native replacement callback runs once")
  T.eq(result, ({[2] = 1})[selected], "shared wrapper returns zero-based move slots")
  T.check(not view.valid(), "closed chooser rejects stale touch")
  rsSummary.reset(); Stack.clear()
end
local records = display.trainerModel({kind = "records"}).records
T.eq(#records, 0, "empty RS trainer records")
session.gameStats = {[21] = 12, [34] = 7, [35] = 3}
records = display.trainerModel({kind = "records"}).records
T.eq(#records, 3, "native RS records include trades, blending and contests")
T.eq(records[1].value, "12", "native trade count")
T.eq(records[2].value, "7", "native blending count")
T.eq(records[3].value, "3", "native contest count")
local Card = Screens.get("trainer_card", session)
Card.show({session = session})
T.check(not display.startMenu().valid(), "RS trainer setup rejects touch")
for _ = 1, 120 do Card.update(1 / 60) end
local card = assert(display.startMenu())
T.check(card.valid(), "settled RS trainer card accepts touch")
T.eq(card.trainerModel.stars, Card._card.stars, "RS companion uses the game's actual card rank")
T.eq(display.trainerModel().stars, Card._card.stars, "RS Trainer app uses the game's actual card rank")
T.eq(card.trainerModel.cardFamily, "hoenn", "RS rank uses the Hoenn card colours")
Card.handleInput(input("a")); Card.update(1 / 60); Card.update(1 / 60)
T.check(not card.valid(), "native card flip blocks repeated touch")
for _ = 1, 120 do Card.update(1 / 60) end
card = assert(display.startMenu())
T.eq(card.trainer.number, 2, "native RS records page")
T.eq(#card.trainerModel.records, 3, "native and companion records agree")
T.check(pcall(display.drawContents), "RS trainer records render")
Card.close(); Stack.clear()
if _G.KANTO_GEAR_RENDER_CAPTURE then _G.KANTO_GEAR_RENDER_CAPTURE(run, display, raw, maps) end
if not _G.KANTO_GEAR_RENDER_CAPTURE then
  assert(loadfile(path .. "/tests/recent_item_gen3_cases.lua"))()(T, run, display, raw)
end
T.finish("Ruby/Sapphire runtime")
