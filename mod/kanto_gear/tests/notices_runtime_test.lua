package.path = "./?.lua;./?/init.lua;" .. package.path

-- Gear notices on a live Gen 2 session: a shiny chimes at once, its card
-- waits for a free screen, draws, opens the app on a tap and leaves a dot
-- until then; the options switch both off; the game's effect volume rules.
local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local run = T.sdk.loadMod(path, { generation = 2, data = T.fixtures.load() })
T.eq(#run.errors, 0, "Kanto Gear boots without errors")

local now = 100
love.timer.getTime = function() return now end
-- A recording audio stand-in: the chime is generated, then played.
local played = {}
love.sound = { newSoundData = function(samples)
  local data = { samples = samples }
  function data:setSample() end
  return data
end }
love.audio = { newSource = function(data)
  local source = { data = data }
  function source:stop() end
  function source:setVolume(v) self.volume = v end
  function source:play() played[#played + 1] = { samples = self.data.samples, volume = self.volume } end
  return source
end }

local world = { map = { id = "ROUTE_29" } }
local game = { data = run.data, world = world,
  save = { generation = 2, version = "crystal", meta = { playthroughId = "notices-test" },
    options = { sfxVol = 7 },
    player = { name = "GOLD", id = 7, map = "ROUTE_29" }, party = {}, inventory = {}, boxes = {},
    pokedex = { seen = {}, caught = {} } },
  stack = { states = { world }, top = function(self) return self.states[#self.states] end } }
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", display_mode = "separate", display_target = "secondary" }
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local inputHook
for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
  if entry.owner == "kanto_gear" then inputHook = entry.callback end
end
local display = up(inputHook, "displayRuntime")
local mod = up(display.bindShinyHunt, "mod")
mod.storage = { read = function() return nil end, write = function() return true end }
run.loader.events:emit("game.ready", { game = game })
local session = display.session
local theme = up(display.drawShinyHunt, "THEME").hgss
T.check(type(display.notify) == "function", "the notice runtime is reachable")
T.eq(display.optionRow("notifications").default, true, "notices are on by default")
T.eq(display.optionRow("notification_sound").default, true, "the chime is on by default")

display.setPackageInstalled("shiny", true)
session.page = "HOME"
display.home.help, display.home.helpSeen = nil, true

-- A shiny in battle: chime now, card later.
session.battle = { kind = "wild" }
local mon = { species = "ZUBAT", level = 5, dvs = { attack = 10, defense = 10, speed = 10, special = 10 } }
run.loader.events:emit("battle.started", { kind = "wild", battle = { enemy = mon } })
T.eq(#played, 1, "a shiny chimes at once, even mid-battle")
T.check(played[1] and played[1].volume == 1 and played[1].samples > 0, "the chime is generated and plays at full effects volume")
T.check(display.noticeUnread("shiny"), "Shiny Hunt carries a dot")
T.eq(display.noticeCard(now), nil, "the card waits while the battle owns the screen")
session.battle = nil
local card = display.noticeCard(now)
T.check(card ~= nil and card.title ~= nil and card.species == "ZUBAT", "the card shows once the battle is over")
T.eq(#played, 1, "an announced card does not chime twice")
T.check(display.tickNotices(now), "a showing card repaints")
local shownAt = card.shownAt
session.battle = {kind="wild"}
T.eq(display.noticeCard(now), nil, "a visible card pauses when a battle begins")
now = now + 20
T.eq(display.noticeCard(now), nil, "blocked time cannot expire or expose the card")
T.check(not display.noticeTap(120 / 1.5, 48 / 1.5), "a card covered by battle cannot accept touches")
session.battle = nil
T.eq(display.noticeCard(now), card, "the same card resumes after battle")
T.eq(card.shownAt, shownAt + 20, "paused time does not consume the card's display duration")

-- It draws on the canvas and over a hidden Gear's game picture.
now = now + 0.1
local ok, err = pcall(theme.noticeBanner, theme, { title = "SHINY FOUND!", detail = "ZUBAT", species = "ZUBAT",
  tone = "special", presence = 0.5, drawPokemon = display.shinyDrawPokemon }, 6, 33, 228, 32)
T.check(ok, "the card draws mid-slide: " .. tostring(err))
ok, err = pcall(display.drawNoticeLayer)
T.check(ok, "the notice layer draws: " .. tostring(err))
ok, err = pcall(display.drawNoticeOverGame, { x = 0, y = 0, w = 960, h = 864 })
T.check(ok, "the card draws over the game: " .. tostring(err))
T.check(display.notices.overRect and display.notices.overRect.w <= 480, "over the game it stays within half the width")

-- The home tile shows the dot; a tap on the card opens the app and clears it.
local tiles = { { id = "shiny_app", kind = "app", icon = "shiny", accent = "amber", label = "SHINY HUNT",
  column = 1, row = 2, columns = 3 } }
ok, err = pcall(theme.home, theme, { tiles = tiles, unreadTiles = { shiny_app = true }, page = 1, pages = 1 })
T.check(ok, "Home draws an unread dot: " .. tostring(err))
now = now + 0.3
T.check(display.noticeTap(120 / 1.5, 48 / 1.5), "a tap on the card is taken")
T.eq(session.page, "SHINY", "the card opens Shiny Hunt")
T.check(not display.noticeUnread("shiny"), "opening the app clears its dot")
display.noticeTap(120 / 1.5, 48 / 1.5)
T.eq(session.page, "SHINY", "a closing card consumes touches without opening twice")

-- A pointer on the card over the game is taken and opens the app too.
session.page = "HOME"
-- The first shiny is also a Stamp Book moment: its card waits in the queue.
local queued = display.notices.queue[1]
T.check(queued ~= nil and queued.key == "moment:first_shiny" and queued.app == "achievements",
  "the first shiny queues a moment card for the Stamp Book")
display.notices.queue, display.notices.current = {}, nil
display.notify({ key = "test", app = "shiny", page = "SHINY", title = "TEST" })
now = now + 10
display.noticeCard(now)
now = now + 0.3
display.drawNoticeOverGame({ x = 0, y = 0, w = 640, h = 576 })
local rect = display.notices.overRect
T.check(rect ~= nil, "the over-game card has a hit area")
if rect then
  T.check(display.noticePointer({ phase = "pressed", x = rect.x + 5, y = rect.y + 5 }), "pressing the card is taken")
  T.check(display.noticePointer({ phase = "released", x = rect.x + 5, y = rect.y + 5 }), "releasing it is taken")
  T.eq(session.page, "SHINY", "it opens Shiny Hunt")
  T.check(not display.noticePointer({ phase = "pressed", x = rect.x + rect.w + 20, y = rect.y }), "the game keeps other touches")
end

-- After the card leaves, one more repaint wipes it.
now = now + 10
display.tickNotices(now)
T.check(display.noticeShowing(), "the leaving card asks for a whole repaint")
T.check(not display.noticeShowing(), "only once")

-- Sound follows the game's effect volume; muted effects mute the chime.
game.save.options.sfxVol = 0
T.check(not display.playNoticeChime("notice"), "muted effects mute the chime")
game.save.options.sfxVol = 4
T.check(display.playNoticeChime("notice") and math.abs(played[#played].volume - 4 / 7) < 1e-6, "the chime follows SFX VOL")

-- Options: no chime, then no cards at all (the dot stays).
mod.options:set("notification_sound", false)
local before = #played
T.check(not display.playNoticeChime("special"), "the chime can be switched off")
mod.options:set("notifications", false)
session.page = "HOME"
T.eq(display.notify({ key = "off", app = "shiny", page = "SHINY", title = "OFF", urgent = true }), nil,
  "switched-off notices post no card")
T.eq(#played, before, "and play nothing")
T.check(display.noticeUnread("shiny"), "the quiet dot still marks the app")

-- Display chronology and durable history use detached presentation records.
mod.options:set("notifications", true)
local stored = {}
mod.storage = {
  read = function(_, target, key) return stored[target.save] and stored[target.save][key] end,
  write = function(_, target, key, value)
    stored[target.save] = stored[target.save] or {}
    stored[target.save][key] = display.Notices.history(value)
    return true
  end,
}
session.page, session.battle = "HOME", {kind="wild"}
display.resetNotices(); display.bindNoticeHistory()
display.notify({key="history-a",title="FIRST",detail="ORIGINAL",app="shiny",onOpen=function() end})
display.notify({key="history-b",title="SECOND"})
T.eq(display.noticeCard(now), nil, "queued cards wait for battle")
T.eq(#display.notices.history, 0, "unseen queued cards are absent from history")
session.battle = nil
display.noticeCard(now)
T.eq(#display.notices.history, 1, "first display records a message")
display.notify({key="history-a",title="FIRST",detail="UPDATED"})
display.noticeCard(now)
T.eq(#display.notices.history, 1, "refreshing a displayed card does not duplicate history")
now = now + 10; display.noticeCard(now)
T.eq(display.notices.history[2].title, "SECOND", "history follows display order")
T.eq(display.notices.history[1].detail, "ORIGINAL", "the original displayed message remains readable")
display.resetNotices(); display.bindNoticeHistory()
T.eq(#display.notices.history, 2, "save reload restores history")
T.eq(#display.notices.queue, 0, "restoring history does not replay cards")
T.eq(display.notices.history[1].onOpen, nil, "persisted history carries no stale callback")
local originalSave = game.save
game.save = {inventory={},party={},pokedex={}}
display.resetNotices(); display.bindNoticeHistory()
T.eq(#display.notices.history, 0, "another save has its own history")
game.save = originalSave
display.bindNoticeHistory()
mod.options:set("ui_motion", false)
display.openNoticeHistory()
T.eq(session.page, "HOME", "opening history preserves the current app")
T.check(display.noticeShadeActive(), "the settings shortcut opens the notification drawer")
T.check(not display.cycleNoticeHistory(1), "a single history page cannot turn")
local historyModel = display.noticeHistoryModel()
T.check(historyModel.rows[1].enabled and not historyModel.rows[2].enabled,
  "only entries with an installed destination are actionable")
T.eq(theme:noticeHistoryHit(220, 204, historyModel), nil, "disabled paging has no action")
local presses, beginPress = {}, theme.beginPress
theme.beginPress = function(self, x, y, w, h, enabled)
  presses[y] = enabled
  return beginPress(self, x, y, w, h, enabled)
end
local okHistory, historyError = pcall(display.drawContents)
theme.beginPress = beginPress
T.check(okHistory, "the history page renders: " .. tostring(historyError))
T.eq(presses[91], false, "a static history row cannot animate")
T.eq(presses[188], false, "disabled history paging cannot animate")
display.Notices.remember(display.notices, {title="THIRD"}, 3)
display.Notices.remember(display.notices, {title="FOURTH"}, 4)
T.check(display.cycleNoticeHistory(1), "history can reach older overflow pages")
T.eq(display.noticeHistoryModel().rows[1].entry.title, "FOURTH", "paging reaches the correct chronological entry")
T.check(not display.cycleNoticeHistory(1), "last history page cannot turn forward")
T.check(display.cycleNoticeHistory(-1), "history can return to the first page")
display.noticeShadeTouch("tap", 70, 100)
T.eq(session.page, "HOME", "static history rows do not open anything")
T.check(display.noticeShadeActive(), "static rows keep the drawer open")
display.noticeShadeTouch("tap", 70, 60)
T.eq(session.page, "SHINY", "a history entry opens its installed app")
T.check(not display.noticeShadeActive(), "opening a destination closes the drawer")
display.openNoticeHistory(); display.noticeShadeTouch("tap", 10, 10)
T.eq(session.page, "SHINY", "closing the drawer returns to the same app")
session.page = "HOME"

-- Exercise the actual 240x216 input stream, not only the drawer's callbacks.
local compose, pointer
for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
  if entry.owner == "kanto_gear" then compose = entry.callback end
end
for _, entry in ipairs(run.loader.hooks.chains["input.pointer"]) do
  if entry.owner == "kanto_gear" then pointer = entry.callback end
end
local touch = up(compose, "touchEvent")
local function drawerReady(motion)
  display.resetNotices(); display.bindNoticeHistory()
  session.page, session.battle, session.touchDown = "HOME", nil, nil
  mod.options:set("ui_motion", motion)
  display.touchGuard.key, display.touchGuard.pending = nil, false
  display.touchGuard.readyAt = 0
  now = now + 1
end
local function send(action, x, y) touch(action .. "," .. x .. "," .. y, 240, 216) end
local function settleDrawer() now = now + 0.3; display.tickNotices(now) end
drawerReady(true)
send("down", 120, 10); send("move", 120, 110)
T.eq(display.notices.shade.height, 100, "the drawer follows the finger before release")
send("up", 120, 110)
T.eq(display.notices.shade.target, 216, "a deliberate pull settles open")
settleDrawer()
T.eq(display.notices.shade.height, 216, "opening finishes at the exact screen edge")
T.eq(session.page, "HOME", "a pull never navigates the underlying app")
send("down", 120, 200); send("move", 120, 145); send("up", 120, 145)
T.eq(display.notices.shade.target, 0, "an upward drag settles closed")
settleDrawer()
T.check(not display.noticeShadeActive(), "closing clears the overlay")
T.check(display.noticeShowing(), "closing forces a whole repaint instead of leaving drawer pixels in a map refresh")
T.check(not display.noticeShowing(), "the drawer clearing repaint is requested only once")
drawerReady(true)
send("down", 120, 10); send("move", 120, 30); send("up", 120, 30)
settleDrawer()
T.check(not display.noticeShadeActive(), "an incomplete pull returns without opening")
local tapFallback, swipeFallback = 0, 0
local oldTap, oldSwipe = display.noticeShadeHeaderTap, display.noticeShadeHeaderSwipe
display.noticeShadeHeaderTap = function() tapFallback = tapFallback + 1 end
display.noticeShadeHeaderSwipe = function() swipeFallback = swipeFallback + 1 end
drawerReady(true)
send("down", 120, 10); send("up", 120, 10)
T.eq(tapFallback, 1, "an ordinary header tap still reaches its original control")
drawerReady(true)
send("down", 180, 10); send("move", 110, 10); send("up", 110, 10)
T.eq(swipeFallback, 1, "horizontal header swipes retain their original paging")
T.eq(tapFallback, 1, "a header swipe cannot become a tap")
display.noticeShadeHeaderTap, display.noticeShadeHeaderSwipe = oldTap, oldSwipe
drawerReady(false)
send("down", 120, 10); send("move", 120, 100)
T.eq(display.notices.shade.height, 0, "reduced motion does not animate the drag")
send("up", 120, 100)
T.eq(display.notices.shade.height, 216, "reduced motion opens immediately on release")
drawerReady(true)
display.home.storeConfirm = "shiny"
T.check(not display.noticeShadeTouch("down", 120, 10), "a modal blocks drawer gestures")
display.home.storeConfirm = nil
session.battle = {kind="wild"}
T.check(not display.noticeShadeTouch("down", 120, 10), "battle controls cannot pull open the drawer")
session.battle = nil
send("down", 120, 10); send("move", 120, 100)
session.battle = {kind="wild"}
send("up", 120, 100)
T.check(not display.noticeShadeActive() and not display.noticeShadeOwnsTouch(),
  "a battle interruption consumes the captured release without opening")
drawerReady(true)
send("down", 120, 10); display.resetNotices(); send("up", 120, 110)
T.check(not display.noticeShadeActive() and session.touchDown == nil,
  "save replacement cannot release a captured pull onto an app control")
drawerReady(true)
send("down", 120, 10); send("move", 120, 100)
session.primaryBottomRect = nil
local leaked = 0
pointer(function() leaked = leaked + 1 end, game, {phase="released",x=800,y=800})
T.eq(leaked, 0, "changing outputs cannot leak a drawer release to the game")
settleDrawer()
T.check(not display.noticeShadeActive(), "losing the output cancels an unfinished pull")
drawerReady(true)

assert(loadfile(path .. "/tests/support/notice_gestures.lua"))()(T,run,display)
T.finish("Gear notices runtime")
