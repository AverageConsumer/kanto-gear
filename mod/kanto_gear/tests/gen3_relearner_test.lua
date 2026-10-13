-- Real ROM learnsets and native relearning callbacks behind the shared move cards.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local emerald = display.gen3.hoenn
  local Native = require(emerald and "src.ui.game3.rse.move_relearner" or "src.ui.game3.move_relearner")
  local show = display.gen3.rs and require("src.ui.game3.rs.move_relearner").show or Native.show
  local Stack, Message, Choice = require("src.ui.game3.stack"), require("src.ui.game3.message"), require("src.ui.game3.choice")
  local Summary, Hud = require("src.ui.game3.summary_menu"), require("src.ui.game3.hud")
  local Learn, Party = require("src.core.game3.battle.learn_move"), require("src.core.game3.party")
  local Pokemon, api = display.gen3.Pokemon, up(display.saveHome, "mod")
  local _, _, mon = Party.giveMon(game.session, Pokemon.speciesFromNational(6), 70)
  assert(mon)
  local tap
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner == "kanto_gear" then tap = up(up(entry.callback, "touchEvent"), "tap") end
  end
  local originalTap, originalInput, queued, done, learned = api.input.tap, game.input, nil, 0, nil
  api.input.tap = function(_, target, key) T.eq(target, game, "relearner targets actual game"); queued = key end
  local function tick(key)
    game.input = { wasPressed = function(_, k) return k == key end, isDown = function() return false end }
    Hud.update(game, 1 / 60)
  end
  local function view()
    display.gen3:refresh(); display.gen3.syncScreens()
    return assert(display.startMenu())
  end
  local function click(x, y)
    local current = view()
    queued = nil; display.tapStartMenu(current, x / 1.5, y / 1.5)
    if queued then local key = queued; queued = nil; tick(key) end
    return current
  end
  local function answer(index)
    local current = view()
    local row = assert(display.StartMenu.model(current)).entries[index]
    click(row.x + row.w / 2, row.y + row.h / 2)
  end
  local function open()
    Native.finish(false); Summary.close(); Stack.clear(); Message.reset(); Choice.reset(); Learn.reset()
    done, learned = 0, nil
    show(mon, { session = game.session, onDone = function(value) done, learned = done + 1, value end })
    return view()
  end
  local function inspect(index, nativeId)
    local current, cursor = view(), Native.cursor
    local _, y = display.MovePage.rect(index)
    queued = nil; display.tapStartMenu(current, 220 / 1.5, (y + 12) / 1.5)
    local info = up(display.syncCompanionDetails, "moveInfo")
    T.eq(info and info.id, display.gen3.Moves.constName(nativeId), "inspection keeps the original native move ID")
    T.eq(Native.cursor, cursor, "inspection never selects a move")
    T.eq(queued, nil, "inspection never begins learning")
    display.syncCompanionDetails(); display.drawContents()
    tap(10, 10)
    T.eq(up(display.syncCompanionDetails, "moveInfo"), nil, "back dismisses only local move details")
    T.eq(queued, nil, "dismissing details sends no native input")
  end
  local function waitFor(predicate)
    for _ = 1, 100 do
      if predicate() then return end
      if Native.state == "message" then tick("a") else tick() end
    end
    error("native relearner did not reach expected screen")
  end
  local options = run.loader.modOptions.kanto_gear
  options.move_details = true
  for _, style in ipairs({ "hgss", "hgss_dark" }) do
    options.theme_v3 = style
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = style })
    local current = open()
    local ids = Native.moves()
    T.check(#ids > 4, "actual ROM learnset exercises more than one move page")
    T.check(current.moveSelection and current.moveSelection.catalogue, "relearner reuses the common attack page")
    local model = display.moveSelectionModel(current.moveSelection)
    T.eq(model.page, 1, "native first cursor selects first page")
    for i = 1, 4 do
      T.eq(model.moves[i].id, display.gen3.Moves.constName(ids[i]), "card retains native learnset order")
      T.eq(model.moves[i].ppText, Pokemon.movePp(ids[i]) .. "/" .. Pokemon.movePp(ids[i]), "unlearned attack shows base PP")
      T.eq(model.moves[i].type, display.gen3.data.moves[model.moves[i].id].type, "card uses real type")
    end
    T.check(pcall(display.drawContents), "common relearner cards render")
    inspect(1, ids[1])
    local stale = click(220, 50)
    T.eq(Native.cursor, 5, "page touch selects the next native list window")
    T.eq(Native.state, "list", "turning a page never begins learning")
    T.check(not stale.valid(), "previous page rejects late touches")
    current = view(); model = display.moveSelectionModel(current.moveSelection)
    T.eq(model.first, 5, "second page retains its absolute list origin")
    T.eq(model.moves[1].id, display.gen3.Moves.constName(ids[5]), "second page card maps to native move five")
    inspect(1, ids[5])
    click(20, 50); T.eq(Native.cursor, 1, "previous arrow returns without confirming")
    T.check(display.pageChoice(1), "horizontal swipe belongs to the attack catalogue")
    T.eq(Native.cursor, 5, "swipe shares the same native page mapping")
    local before = { unpack(mon.moves) }
    click(120, 85)
    T.eq(Native.state, "yesno", "one move touch opens the actual native confirmation")
    T.same(mon.moves, before, "selecting a move does not teach it")
    answer(2)
    T.eq(Native.state, "list", "No returns to the native catalogue")
    T.same(mon.moves, before, "declining teaching preserves all moves")
    click(120, 85); answer(1)
    waitFor(function() return Native.state == "yesno" end)
    answer(1)
    waitFor(function() return Summary.isOpen() end)
    T.check(Summary.isOpen(), "native teaching opens the common replacement chooser")
    waitFor(function() local current = display.startMenu(); return current and current.valid() end)
    current = view()
    T.check(current.moveSelection and not current.moveSelection.catalogue, "replacement keeps the shared four-slot page")
    click(120, 120)
    waitFor(function() return not Native.open end)
    T.eq(done, 1, "successful native learning completes exactly once")
    T.eq(learned, true, "native completion reports actual success")
    T.eq(mon.moves[2], ids[5], "native handler replaces exactly the selected slot with the selected catalogue move")
    T.eq(mon.pp[2], Pokemon.movePp(ids[5]), "new attack receives native base PP")
    mon.moves = before
    current = open()
    while display.moveSelectionModel(view().moveSelection).page < display.moveSelectionModel(view().moveSelection).pages do
      display.pageChoice(1)
    end
    model = display.moveSelectionModel(view().moveSelection)
    local cursor = Native.cursor
    click(220, 50)
    T.eq(Native.cursor, cursor, "inactive last-page arrow has no effect")
    current = view()
    Choice.active = true
    T.check(not current.valid(), "covered catalogue never animates or accepts a touch")
    Choice.active = false
    local moves = Native.moves()
    moves[1], moves[2] = moves[2], moves[1]
    T.check(not current.valid(), "in-place native learnset changes invalidate old move cards")
    moves[1], moves[2] = moves[2], moves[1]
    current = view(); show(mon, { session = game.session })
    T.check(not current.valid(), "reopened native singleton rejects previous cards")
    Native.finish(false)
    current = open(); before = { unpack(mon.moves) }
    click(15, 15); T.eq(Native.state, "yesno", "back opens the native give-up question")
    answer(2); T.eq(Native.state, "list", "No on give-up returns normally")
    click(15, 15); answer(1)
    T.eq(done, 1, "cancel runs the native callback once")
    T.eq(learned, false, "cancel reports no learned attack")
    T.same(mon.moves, before, "cancelling never edits attacks")
    local originalMon = mon
    local _, _, starter = Party.giveMon(game.session, Pokemon.speciesFromNational(4), 1)
    mon = assert(starter)
    current = open()
    T.eq(#Native.moves(), 0, "native low-level fixture has no forgotten attacks")
    model = display.moveSelectionModel(current.moveSelection)
    T.eq(next(model.moves), nil, "empty catalogue has no invented moves")
    T.eq(display.MovePage.hit(model, 120, 85), nil, "empty card has no touch action")
    T.check(pcall(display.drawContents), "empty catalogue renders safely")
    click(15, 15); answer(1)
    T.eq(learned, false, "empty catalogue still supports native cancellation")
    table.remove(game.session.party)
    mon = originalMon
  end
  Native.finish(false); Summary.close(); Stack.clear(); Learn.reset(); Message.reset(); Choice.reset()
  table.remove(game.session.party)
  api.input.tap, game.input = originalTap, originalInput
end
dofile(path .. "/tests/gen3_fixture.lua")
