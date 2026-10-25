package.path = "./?.lua;./?/init.lua;" .. package.path

-- Notification settings and the extra notice sources: each area can sound,
-- stay silent, leave only a dot or stay off; shiny chimes can wait for the
-- card; cards can last longer or wait for a hidden Gear. The Day-Care,
-- Calendar and Stamp Book report what changed, once.
local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local run = T.sdk.loadMod(path, { generation = 2, data = T.fixtures.load() })
T.eq(#run.errors, 0, "Kanto Gear boots without errors")

local now = 100
love.timer.getTime = function() return now end
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
  function source:play() played[#played + 1] = true end
  return source
end }

local world = { map = { id = "ROUTE_29" } }
local game = { data = run.data, world = world,
  save = { generation = 2, version = "crystal", meta = { playthroughId = "notice-settings" },
    options = { sfxVol = 7 }, player = { name = "GOLD", id = 7, map = "ROUTE_29" }, party = {},
    inventory = {}, boxes = {}, pokedex = { seen = {}, caught = {} } },
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
local session, events = display.session, run.loader.events
session.page = "HOME"
display.home.help, display.home.helpSeen = nil, true
local function clear() display.notices.current, display.notices.queue = nil, {} end
local function find(key)
  local n = display.notices
  if n.current and n.current.key == key then return n.current end
  for _, card in ipairs(n.queue) do if card.key == key then return card end end
end

-- The settings: their own tab, every area switch and the timing rows.
local tab
for index, category in ipairs(display.settingsCategories) do
  if category.id == "notifications" then tab = index end
end
T.check(tab ~= nil, "Notifications have their own settings tab")
for _, key in ipairs({ "notice_shiny", "notice_moments", "notice_daycare", "notice_calendar", "notice_stamps",
    "notice_shiny_timing", "notice_duration", "notice_where" }) do
  T.check(display.optionRow(key) ~= nil, "option exists: " .. key)
end
T.eq(display.optionRow("notice_calendar").default, "silent", "the Calendar is quiet by default")
display.settings.category = tab
local model = display.settingsModel()
T.check(model.rows and #model.rows == 10 and model.pages == 3, "ten rows over three pages")

-- Levels per area.
display.setPackageInstalled("shiny", true)
clear()
mod.options:set("notice_shiny", "off")
T.eq(display.notify({ key = "a", app = "shiny", page = "SHINY", area = "shiny", title = "A" }), nil, "off posts nothing")
T.check(not display.noticeUnread("shiny"), "and leaves no dot")
mod.options:set("notice_shiny", "dot")
T.eq(display.notify({ key = "b", app = "shiny", page = "SHINY", area = "shiny", title = "B", urgent = true }), nil,
  "dot only posts no card")
T.check(display.noticeUnread("shiny") and #played == 0, "but marks the app, without a sound")
display.markNoticeRead("shiny")
mod.options:set("notice_shiny", "silent")
local card = display.notify({ key = "c", app = "shiny", page = "SHINY", area = "shiny", title = "C", urgent = true })
T.check(card ~= nil and card.silent and #played == 0, "silent shows a card without a chime")
clear()
mod.options:set("notice_shiny", "full")
mod.options:set("notice_shiny_timing", "after")
card = display.notify({ key = "d", app = "shiny", page = "SHINY", area = "shiny", title = "D", urgent = true })
T.eq(#played, 0, "a shiny chime can wait for its card")
display.noticeCard(now)
T.eq(#played, 1, "and sounds when the card shows")
mod.options:set("notice_shiny_timing", "now")

-- Duration and a hidden Gear.
clear()
mod.options:set("notice_duration", "long")
card = display.notify({ key = "e", title = "E" })
T.eq(card.show, 6, "long cards stay six seconds")
mod.options:set("notice_duration", "short")
clear()
card = display.notify({ key = "f", title = "F" })
T.eq(card.show, 2, "short cards two seconds")
mod.options:set("notice_duration", "normal")
clear()
mod.options:set("notice_where", "wait")
display.notify({ key = "g", title = "G" })
display.drawNoticeOverGame({ x = 0, y = 0, w = 640, h = 576 })
T.eq(display.notices.overRect, nil, "waiting cards are not drawn over the game")
T.eq(display.noticeCard(now), nil, "nor shown while the Gear is hidden")
now = now + 1
T.check(display.noticeCard(now) ~= nil, "they show once the Gear is back in view")
mod.options:set("notice_where", "over")

-- Day-Care: a waiting egg and a growing boarder.
clear()
events:emit("breeding.egg_created", {})
local egg = find("daycare:egg")
T.check(egg ~= nil and egg.app == "daycare" and egg.area == "daycare", "an egg waiting at the Day-Care")
local boarder = { key = "man", name = "ABRA", levelNow = 10 }
display.daycareInput = function() return { place = "ROUTE 34", parents = { boarder } } end
display.calendarSupported = function() return false end
now = now + 10; display.pollNoticeSources(now)
T.eq(find("daycare:level:man"), nil, "a boarder seen for the first time is no news")
boarder.levelNow = 11
now = now + 10; display.pollNoticeSources(now)
local grew = find("daycare:level:man")
T.check(grew ~= nil and tostring(grew.detail):find("11", 1, true), "a boarder that grew is reported")
mod.options:set("notice_daycare", "off")
boarder.levelNow = 12
clear()
now = now + 10; display.pollNoticeSources(now)
T.eq(find("daycare:level:man"), nil, "the Day-Care switch silences it")
mod.options:set("notice_daycare", "full")

-- Calendar: one summary on the first look, then each new thing once.
clear()
local rows = { { key = "contest:1", tag = "EVENT", title = "BUG-CATCHING CONTEST", place = "NATIONAL PARK", state = "open" } }
display.calendarSupported = function() return true end
display.calendarModel = function() return { weekday = 2, now = rows, today = {}, days = {} } end
now = now + 10; display.pollNoticeSources(now)
T.check(find("calendar:today") ~= nil, "the first look sums up what is open")
rows[2] = { key = "rematch:joey", tag = "BATTLE", title = "JOEY", state = "open" }
now = now + 10; display.pollNoticeSources(now)
T.check(find("calendar:rematch:joey") ~= nil, "a rematch that opens is reported")
clear()
now = now + 10; display.pollNoticeSources(now)
T.eq(#display.notices.queue, 0, "each only once")

-- Stamps: a silver stamp where you stand, with the app installed.
clear()
display.setPackageInstalled("achievements", true)
session.mapId = "ROUTE_29"
local area = { id = "R29", name = "ROUTE 29", kind = "route", tier = "bronze" }
display.achievementData = function() return { areas = { area } } end
now = now + 10; display.pollNoticeSources(now)
T.eq(#display.notices.queue, 0, "a stamp seen first is no news")
area.tier = "silver"
now = now + 10; display.pollNoticeSources(now)
local stamp = find("stamp:R29")
T.check(stamp ~= nil and stamp.drawIcon and stamp.onOpen, "a new silver stamp is reported with its seal")
local ok, err = pcall(stamp.drawIcon, 13, 35, 28)
T.check(ok, "its seal draws: " .. tostring(err))

-- Swiping a card away, on the Gear and over the game.
clear()
session.page = "HOME"
display.notify({ key = "swipe", title = "SWIPE" })
now = now + 10; display.noticeCard(now)
now = now + 0.3
T.check(not display.noticeSwipe({ x = 120 / 1.5, y = 120 / 1.5 }), "a swipe elsewhere is not for the card")
T.check(display.noticeSwipe({ x = 120 / 1.5, y = 48 / 1.5 }), "a swipe on the card is taken")
T.check(display.notices.current and display.notices.current.closing, "and sends the card away")
T.eq(session.page, "HOME", "without opening anything")
clear()
display.notify({ key = "drag", app = "shiny", page = "SHINY", title = "DRAG" })
now = now + 10; display.noticeCard(now)
now = now + 0.3
display.drawNoticeOverGame({ x = 0, y = 0, w = 640, h = 576 })
local rect = display.notices.overRect
T.check(rect ~= nil, "the card shows over the game")
if rect then
  display.noticePointer({ phase = "pressed", x = rect.x + 20, y = rect.y + 5 })
  display.noticePointer({ phase = "released", x = rect.x + 20 + rect.w / 2, y = rect.y + 5 })
  T.check(display.notices.current and display.notices.current.closing, "a drag over the game dismisses it")
  T.eq(session.page, "HOME", "and opens nothing")
end

T.finish("Notification settings")
