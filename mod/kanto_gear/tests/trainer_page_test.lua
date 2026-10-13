local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local Stack = generation == 3 and require("src.ui.game3.stack") or game.stack
  local Native = generation == 3 and require("src.ui.game3.screens").get("trainer_card", game.session)
    or require(generation == 2 and "src.ui.gen2.TrainerCard" or "src.ui.TrainerCard")
  local api, theme = up(display.saveHome, "mod"), up(display.drawContents, "THEME")
  local oldTap, oldInput = api.input.tap, game.input
  -- The host SDK stub omits Quad:getViewport; real LÖVE supplies it.
  local newQuad = love.graphics.newQuad
  love.graphics.newQuad = function(x, y, w, h, ...)
    local quad = newQuad(x, y, w, h, ...)
    if not quad.getViewport then quad.getViewport = function() return x, y, w, h end end
    return quad
  end
  local queued, closed, owner = nil, 0, nil
  api.input.tap = function(_, target, key) T.eq(target, game, "trainer input keeps original game identity"); queued = key end
  local function tick(key)
    game.input = { wasPressed = function(_, k) return k == key end, isDown = function() return false end }
    if generation == 3 then Native.handleInput(game.input) else Stack:top():update(1 / 60) end
  end
  local function view()
    if generation == 3 then display.gen3.syncScreens() end
    return assert(display.startMenu(), "trainer card has a common projection")
  end
  local function click(x, y)
    queued = nil; display.tapStartMenu(view(), x / 1.5, y / 1.5)
    if queued then tick(queued) end
    return queued
  end
  local function flipDone()
    for _ = 1, 40 do if Native._flip then Native.update(1 / 60) end end
    T.eq(Native._flip, nil, "native flip finishes")
  end
  local function open()
    if generation == 3 then
      Native.close(); Stack.clear(); require("src.ui.game3.message").reset(); require("src.ui.game3.choice").reset()
      Native.show({ session = game.session, onClose = function() closed = closed + 1 end }); owner = Native
    else
      Stack.states = { game.world }
      owner = Native.new(game, { onCancel = function() closed = closed + 1 end,
        onClose = function() Stack:pop(); closed = closed + 1 end })
      Stack:push(owner)
    end
    return view()
  end
  if generation == 3 then
    local session = game.session
    session.gameStats = { [21] = 47, [23] = 12, [24] = 3, [34] = 9, [35] = 5, [50] = 17, [51] = 31 }
    session.hofDebutHours, session.hofDebutMinutes, session.hofDebutSeconds = 23, 45, 6
    session.frontier = { cardBattlePoints = 71 }
    display.gen3:refresh()
  else
    game.save.player.id = 12345
    if generation == 2 then
      game.save.player.badges, game.save.player.kantoBadges = { ZEPHYR = true }, { BOULDER = true, CASCADE = true }
    end
  end
  for _, style in ipairs({ "hgss", "hgss_dark" }) do
    run.loader.modOptions.kanto_gear.theme_v3 = style
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = style })
    local initial = open()
    local done = closed
    T.check(initial.trainerModel and initial.fixedLayout, "native cards use the shared trainer model")
    T.eq(initial.trainerModel.kind, "front", "card opens on summary")
    local drawn, err = xpcall(display.drawContents, debug.traceback)
    T.check(drawn, "native trainer front renders: " .. tostring(err))
    local app = display.trainerModel()
    if generation == 3 then
      T.eq(initial.trainerModel.stars, Native._card.stars, "native companion uses the game's actual card rank")
      T.eq(app.stars, Native._card.stars, "Trainer app uses the game's actual card rank")
      T.eq(app.cardFamily, display.gen3.hoenn and "hoenn" or "kanto", "card colour uses the edition family")
    else
      T.eq(app.stars, nil, "Gen 1/2 do not invent a trainer-card rank from badges")
    end
    for _, key in ipairs({ "name", "region", "idText", "money", "time", "pokedex", "badgeText" }) do
      T.eq(initial.trainerModel[key], app[key], "native and app trainer share " .. key)
    end
    local redraw = display.StartMenu.redrawKey(view())
    T.eq(display.StartMenu.redrawKey(view()), redraw, "unchanged trainer reuses its canvas")
    T.eq(click(120, 128), nil, "badge and record cards are static")
    if generation == 1 then
      T.eq(display.TrainerPage.hit(130, 13, 1), nil, "one-page card has no next target")
      display.pageChoice(1)
      T.eq(queued, nil, "Gen1 swipe never sends an accidental close")
    else
      T.eq(click(130, 13), generation == 3 and "a" or "right", "next uses the actual native page action")
      if generation == 3 then
        T.check(Native._flip ~= nil, "native flip starts")
        local turning = view()
        T.eq(display.StartMenu.cursor(turning), nil, "touch is locked while native card turns")
        T.check(display.StartMenu.cursor(turning, true) ~= nil, "card remains drawable during flip")
        T.eq(click(130, 13), nil, "repeated tap cannot queue a second flip")
        T.check(not initial.valid(), "pre-flip targets stop accepting input")
        flipDone()
      end
      local second = view()
      T.eq(second.trainer.number, 2, "next displays native page two")
      T.check(not initial.valid(), "prior page rejects delayed touches")
      T.check(display.StartMenu.redrawKey(second) ~= redraw, "page changes invalidate cached content")
      T.check(pcall(display.drawContents), "trainer second page renders")
      if generation == 2 then
        T.eq(second.trainerModel.kind, "badges", "Gen2 native badge pages use the badge grid")
        T.eq(second.trainerModel.badgeRegion, "JOHTO", "first badge page is Johto")
        T.eq(second.trainerModel.badgeText, "3/16", "overall count includes both real regions")
        T.check(second.trainerModel.badgeOwned[1] and not second.trainerModel.badgeOwned[2], "Johto reads its own flags")
        click(130, 13)
        local kanto = view().trainerModel
        T.eq(kanto.badgeRegion, "KANTO", "third native page selects Kanto")
        T.check(kanto.badgeOwned[1] and kanto.badgeOwned[2] and not kanto.badgeOwned[3], "Kanto uses actual Kanto flags, not the native reused Johto art")
        T.eq(click(34, 13), "left", "reverse page uses native Left")
      else
        T.eq(second.trainerModel.kind, "records", "Gen3 reverse uses common records")
        local records = second.trainerModel.records
        local expected = Native._rse and 6 or 5
        T.eq(#records, expected, "all real native records appear")
        T.eq(records[1].value:gsub("%s", ""), "23:45:06", "Hall of Fame time is preserved")
        T.check(records[2].value:find("12", 1, true) and records[2].value:find("3", 1, true), "link wins and losses both remain visible")
        T.eq(records[3].value, "47", "trades retain their exact count")
        local appRecords = display.trainerModel({ kind = "records" }).records
        T.same(appRecords, records, "trainer app shows exactly the same records as the native card")
        local current = view(); require("src.ui.game3.message").show("Covered trainer")
        T.check(not current.valid(), "covered trainer never accepts touch")
        require("src.ui.game3.message").reset()
        T.eq(click(34, 13), "b", "reverse flip uses native B")
        flipDone()
      end
      display.pageChoice(-1)
      if generation == 3 then flipDone() end
      T.check(pcall(display.drawContents), "reverse and wrapping pages render")
    end
    -- Exit from the front in Gen3; B on its reverse deliberately flips first.
    if generation == 3 and Native.side == "back" then tick("b"); flipDone() end
    T.eq(click(14, 13), "b", "back follows the actual native cancel path")
    T.eq(display.startMenu(), nil, "closing restores the previous companion")
    T.eq(closed, done + 1, "native close callback runs once")
    local stale = open(); open()
    T.check(not stale.valid(), "a reopened trainer rejects the earlier opening")
    tick("b")
    if generation == 2 then
      game.save.player.kantoBadges = {}
      local gated = open()
      T.eq(gated.trainer.pages, 2, "Kanto page is not fabricated before native unlock")
      game.save.player.kantoBadges = { BOULDER = true }
      T.check(not gated.valid(), "changed page availability invalidates old targets")
      T.check(display.StartMenu.cursor(view()) ~= nil, "changed page count constructs a usable fresh view")
      game.save.player.kantoBadges = {}
      click(34, 13)
      T.eq(view().trainer.number, 2, "reverse wraps only through the available native pages")
      tick("b"); game.save.player.kantoBadges = { BOULDER = true, CASCADE = true }
    end
  end
  -- Exercise the actual companion-app dispatcher, including the arrow/back boundary.
  local compose
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner == "kanto_gear" then compose = entry.callback end
  end
  local event = up(compose, "touchEvent")
  local tap, swipe = up(event, "tap"), up(event, "swipe")
  if generation == 3 then display.gen3.syncScreens(); up(compose, "refreshBattle")() end
  T.check(display.openHomeApp("trainer"), "Trainer app opens independently of the native card")
  display.trainerPage = 1
  local pages = generation == 1 and 1 or generation == 2 and 3 or 2
  T.eq(display.trainerContext().pages, pages, "app offers the appropriate generation pages")
  T.check(pcall(display.drawContents), "Trainer app uses the shared renderer")
  if pages > 1 then
    tap(28 / 1.5, 13 / 1.5)
    T.eq(display.home.activeApp, "trainer", "left arrow edge never overlaps the app back target")
    T.eq(display.trainerContext().number, pages, "app reverse wraps to its own last page")
    tap(130 / 1.5, 13 / 1.5)
    T.eq(display.trainerContext().number, 1, "app forward wraps back to the summary")
    swipe(-30, { y = 90 })
    T.eq(display.trainerContext().number, 2, "app swipe advances its common page")
    swipe(30, { y = 90 })
    T.eq(display.trainerContext().number, 1, "app reverse swipe restores summary")
  end
  local H, presses = theme.hgss, 0
  local begin = H.beginPress
  H.beginPress = function(self, ...)
    local pressed = begin(self, ...)
    if pressed then presses = presses + 1 end
    return pressed
  end
  H:setTouch(80, 85, true)
  H:trainer(display.trainerModel(display.trainerContext()))
  H.beginPress = begin; H:setTouch(nil, nil, true)
  T.eq(presses, 0, "static trainer information never animates on touch")
  tap(14 / 1.5, 13 / 1.5)
  T.eq(display.home.activeApp, nil, "app back returns Home without touching native stacks")
  if generation == 3 then
    local session = game.session
    session.gameStats = {}; session.hofDebutHours, session.hofDebutMinutes, session.hofDebutSeconds = 0, 0, 0
    session.frontier = {}; open(); tick("a"); flipDone()
    T.eq(#view().trainerModel.records, 0, "empty record page invents no achievements")
    T.check(pcall(display.drawContents), "empty records render cleanly")
    tick("a")
    local Kit = require("src.ui.game3.rse.scene_kit")
    local manifest, image, rgba = Kit.manifest, Kit.image, Kit.rgbaImage
    local atlas = { getDimensions = function() return 128, 16 end }
    Kit.manifest = function() return { badges = { png = "ROM_BADGES" } } end
    Kit.image, Kit.rgbaImage = function() return atlas end, function() return atlas end
    local draws = 0
    local graphics = { setColor = function() end, draw = function(_, quad, x, y)
      T.eq(x, 33, "badge art centers on the requested x"); T.eq(y, 43, "badge art centers on the requested y"); draws = draws + 1 end }
    T.check(display.gen3:drawBadge(graphics, 1, 40, 50, true), "native extracted badge art is used")
    local cache = display.gen3.badgeAtlas
    display.gen3:drawBadge(graphics, 2, 40, 50, false)
    T.eq(display.gen3.badgeAtlas, cache, "badge quads are reused on unchanged atlas")
    T.eq(draws, 2, "earned and unearned badges use real atlas art")
    Kit.manifest, Kit.image, Kit.rgbaImage = manifest, image, rgba; display.gen3.badgeAtlas = nil
  end
  if generation == 3 then
    open()
    local session = Native._session
    Native._session = {}
    T.eq(display.startMenu(), nil, "foreign trainer card is never mislabeled as the local player")
    Native._session = session; tick("b")
  end
  love.graphics.newQuad = newQuad
  api.input.tap, game.input = oldTap, oldInput
end
if generation == 3 then
  dofile(path .. (os.getenv("POKEPORT_VERSION") == "emerald" and "/tests/emerald_runtime_test.lua" or "/tests/gen3_runtime_test.lua"))
else dofile(path .. "/tests/legacy_bag_test.lua") end
