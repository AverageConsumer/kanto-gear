-- Native Emerald ownership, cursor animations and consumption through shared touch pages.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local a, ui, session = display.gen3, display.gen3Ui, game.session
  local Stack, Message = require("src.ui.game3.stack"), require("src.ui.game3.message")
  local Choice = require("src.ui.game3.choice")
  local Blocks = require("src.core.game3.rse.pokeblock")
  local Case = require("src.ui.game3.rse.pokeblock_case")
  local Use = require("src.ui.game3.rse.use_pokeblock")
  local Feed = require("src.ui.game3.rse.pokeblock_feed")
  local Party, Pokemon = require("src.core.game3.party"), require("src.core.game3.pokemon")
  local originalParty, originalBlocks = session.party, session.pokeblocks
  session.party = {}
  Party.giveMon(session, 277, 15); Party.giveMon(session, 278, 16); Party.giveMon(session, 279, 17)
  session.party[2].isEgg = true
  local api = up(display.saveHome, "mod")
  local oldTap, queued, submitted = api.input.tap, nil, 0
  api.input.tap = function(_, target, key)
    T.eq(target, game, "touch input belongs to the actual game")
    queued, submitted = key, submitted + 1
  end
  local function tick(key)
    local layer = Stack.top()
    assert(layer, "native layer exists")
    layer.mod.handleInput({ wasPressed = function(_, k) return k == key end,
      isDown = function(_, k) return k == key end })
    layer.mod.update()
  end
  local function poll()
    local view = display.startMenu()
    if queued then local key = queued; queued = nil; tick(key) end
    return view
  end
  local function waitFor(predicate, description)
    for _ = 1, 1500 do
      if predicate() then return end
      local printer = Feed.open and Feed._st.printer
      tick(printer and (printer.state == "wait" or printer.state == "clear" or printer.state == "scroll_start") and "a" or nil)
      poll()
    end
    error("native transition did not finish: " .. description)
  end
  local function click(view, index)
    local entry = assert(display.StartMenu.model(view)).entries[index]
    assert(entry, "touch entry exists")
    queued = nil
    display.tapStartMenu(view, (entry.x + entry.w / 2) / 1.5, (entry.y + entry.h / 2) / 1.5)
    if queued then local key = queued; queued = nil; tick(key) end
  end
  local function back(view)
    queued = nil; display.tapStartMenu(view, 12 / 1.5, 12 / 1.5)
    if queued then local key = queued; queued = nil; tick(key) end
  end
  local function open(caseId, opts)
    Use.reset(); Feed.reset(); Case.reset(); Stack.clear(); Message.reset(); Choice.reset()
    ui.pokeblockSelection = nil; queued = nil
    Blocks.clearAll(session)
    for i = 1, 3 do Blocks.add(session, { color = i, spicy = 10 + i, dry = 12, feel = 20 }) end
    Case.saved.row, Case.saved.scroll = 0, 0
    opts = opts or {}; opts.session, opts.caseId = session, caseId or Blocks.CASE.FIELD
    local skin = a.rs and require("src.ui.game3.rs.pokeblock_case") or Case
    skin.show(opts)
    waitFor(function() return Case._st.fadeDir == 0 end, "case entry")
    a:refresh(); a.syncScreens()
    return assert(display.startMenu())
  end
  local function feedPage()
    local list = open()
    click(list, 1); click(assert(poll()), 1)
    waitFor(function() return Use.open and Use._st.state == "input" and Use._st.fadeDir == 0 end, "feeding chooser")
    return assert(poll())
  end
  for _, style in ipairs({ "hgss", "hgss_dark" }) do
    run.loader.modOptions.kanto_gear.theme_v3 = style
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = style })
    for _, yes in ipairs({ false, true }) do
      local list = open(); click(list, 1)
      local actions = assert(poll())
      T.eq(#actions.items, 3, "field case offers actual Use, Toss, Cancel")
      click(actions, 2)
      waitFor(function() return Case._st.phase == "toss_yesno" end, "discard question")
      local question = assert(poll())
      T.eq(question.prompt, a:plainText(table.concat(Case._st.printer.lines, "\n")), "question uses actual native text")
      T.check(pcall(display.drawContents), "discard question uses shared choice rendering")
      click(question, yes and 1 or 2)
      T.eq(Blocks.count(session), 3, "question alone never consumes a block")
      T.check(not question.valid(), "old discard question cannot be submitted twice")
      if yes then
        waitFor(function() return Case._st.printer and not Case._st.printer:isActive() end, "discard result printer")
        local notice = assert(poll())
        T.check(notice.canAdvance, "native completed notice accepts continuation")
        click(notice, 1)
        T.eq(Blocks.count(session), 2, "native final acknowledgement discards exactly one block")
        T.eq(Blocks.get(session, 0).color, 2, "native compaction retains remaining blocks")
      else T.eq(Case._st.phase, "list", "No returns to the actual case") end
    end
    for _, id in ipairs(a.rs and { Blocks.CASE.FEEDER } or { Blocks.CASE.FEEDER, Blocks.CASE.GIVE }) do
      local uses, closes, chosen = 0, 0, nil
      local list = open(id, { onUse = function(index) uses = uses + 1; return index end,
        onClose = function(index) closes = closes + 1; chosen = index end })
      click(list, 3); local actions = assert(poll())
      T.eq(#actions.items, 2, "context-specific case keeps native action count")
      click(actions, 1)
      T.eq(uses, 1, "context action calls native handler once")
      waitFor(function() return not Case.open end, "context exit")
      T.eq(closes, 1, "context exit callback runs once")
      T.eq(chosen, 2, "context callback receives selected zero-based native block")
      T.eq(Blocks.count(session), 3, "companion does not invent context-specific consumption")
    end
    local list = open()
    tick("select")
    T.eq(Case._st.phase, "swap", "native Select starts reordering")
    click(assert(poll()), 3)
    T.eq(Case._st.phase, "list", "touch confirms native reordering")
    T.eq(Blocks.get(session, 0).color, a.rs and 3 or 2, "native order changed without replacing blocks")
    list = assert(poll()); tick("select"); back(assert(poll()))
    T.eq(Blocks.get(session, 0).color, a.rs and 3 or 2, "cancelled reorder preserves native order")

    local chooser = feedPage()
    T.eq(#chooser.items, 3, "feeding excludes eggs and includes Cancel")
    T.eq(Use._st.party[2], 3, "filtered row maps to actual third party slot")
    T.check(pcall(display.drawContents), "filtered chooser uses common Pokemon cards")
    local before = submitted
    click(chooser, 2)
    T.eq(submitted, before, "choosing a different Pokemon does not send A before native cursor animation")
    T.eq(Use._st.state, "loading", "native portrait and condition graph transition normally")
    T.eq(display.StartMenu.cursor(assert(poll())), nil, "animation blocks additional touches")
    waitFor(function() return Use._st.state == "confirm" end, "deferred selected Pokemon confirmation")
    T.eq(submitted, before + 1, "finished native selection confirms exactly once")
    T.eq(Use._st.nameInfo.name, Pokemon.displayMonName(session.party[3]), "native portrait text belongs to selected party member")
    local question = assert(poll())
    T.eq(question.prompt, a:plainText(Use._st.message), "feeding confirmation uses actual game text")
    click(question, 2)
    T.eq(Use._st.state, "input", "No returns to selected Pokemon")
    T.eq(Blocks.count(session), 3, "cancelled feeding preserves blocks")

    Blocks.contest(session.party[3]).sheen = 255
    click(assert(poll()), 2); click(assert(poll()), 1)
    T.eq(Use._st.state, "wont_eat", "native maximum sheen refusal is respected")
    T.eq(Blocks.count(session), 3, "refused block is not consumed")
    click(assert(poll()), 1)
    Blocks.contest(session.party[3]).sheen = 0
    local expected = {}; for k, v in pairs(Blocks.contest(session.party[3])) do expected[k] = v end
    local expectedMon = { personality = session.party[3].personality, contest = expected }
    local block = Blocks.get(session, 0)
    Blocks.feed(block, expectedMon, Blocks.gain(Blocks.natureOf(session.party[3]), block))
    click(assert(poll()), 2); click(assert(poll()), 1)
    waitFor(function() return Feed.open end, "native feeding animation")
    waitFor(function() return Feed._st.phase == "message" end, "native eating message")
    waitFor(function() return Use.open and Use._st.state == "results_wait" and Use._st.fadeDir == 0 end, "native feeding result")
    T.eq(Blocks.count(session), 3, "animation alone does not prematurely consume the block")
    click(assert(poll()), 1)
    waitFor(function() return Use._st.state == "results_text" end, "native condition graph")
    for k, v in pairs(expected) do T.eq(Blocks.contest(session.party[3])[k], v, "native feeding owns condition " .. k) end
    local oldNotice = assert(poll())
    click(oldNotice, 1)
    T.check(not oldNotice.valid(), "old result text cannot acknowledge the next native result")
    while Use._st.state == "results_text" do click(assert(poll()), 1) end
    waitFor(function() return Case.open and Case._st.fadeDir == 0 end, "return to case after feeding")
    T.eq(Blocks.count(session), 2, "complete feed consumes exactly one native block")

    chooser = feedPage(); click(chooser, 2)
    local pending = ui.pokeblockSelection
    T.check(pending ~= nil, "deferred selection exists only during native transition")
    Use.reset(); (a.rs and require("src.ui.game3.rs.use_pokeblock") or Use).show({ session = session, pokeblockId = 0 })
    poll()
    T.eq(ui.pokeblockSelection, nil, "reopened native chooser invalidates old pending confirmation")
    waitFor(function() return Use._st.state == "input" and Use._st.fadeDir == 0 end, "reopened chooser")
    T.eq(Use._st.state, "input", "no late confirmation leaks into a new chooser")
    chooser = assert(poll()); click(chooser, 2)
    Choice.active = true; poll(); Choice.active = false
    T.eq(ui.pokeblockSelection, nil, "covering modal cancels deferred confirmation")
    waitFor(function() return Use._st.state == "input" end, "cancelled selection animation")
    chooser = assert(poll()); Choice.active = true
    T.check(not chooser.valid(), "covered Pokemon cards cannot perform or animate a touch")
    Choice.active = false
    back(assert(poll()))
    waitFor(function() return not Use.open end, "chooser cancellation")
    T.eq(Blocks.count(session), 3, "closing chooser preserves blocks")

    Party.giveMon(session, 280, 18); Party.giveMon(session, 281, 19); Party.giveMon(session, 282, 20)
    chooser = feedPage()
    T.eq(#chooser.items, 6, "full party keeps every eligible Pokemon on the common page")
    click(chooser, 5)
    waitFor(function() return Use._st.state == "confirm" end, "last full-party card")
    T.eq(Use._st.party[Use._st.sel + 1], 6, "last card reaches exact native full-party slot")
    T.eq(Use._st.nameInfo.name, Pokemon.displayMonName(session.party[6]), "wrapped cursor updates native portrait information")
    click(assert(poll()), 2)
    chooser = assert(poll()); click(chooser, 1)
    T.check(ui.pokeblockSelection ~= nil, "another native selection is queued")
    for _ = 1, 100 do if Use._st.state == "input" then break end; tick() end
    tick("down"); poll()
    T.eq(ui.pokeblockSelection, nil, "hardware cursor interference cancels pending touch confirmation")
    waitFor(function() return Use._st.state == "input" end, "hardware selection")
    T.eq(Use._st.state, "input", "interference cannot auto-feed a different Pokemon")
    back(assert(poll())); waitFor(function() return not Use.open end, "full-party cancel")
    while #session.party > 3 do table.remove(session.party) end
  end
  api.input.tap, session.party, session.pokeblocks = oldTap, originalParty, originalBlocks
  ui.pokeblockSelection = nil
  Case.reset(); Use.reset(); Feed.reset(); Stack.clear(); Message.reset(); Choice.reset(); a:refresh(); a.syncScreens()
end
dofile(path .. "/tests/gen3_fixture.lua")
