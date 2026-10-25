package.path = "./?.lua;./?/init.lua;" .. package.path

-- Moments runtime: battles, catches and shinies become Stamp Book moments,
-- each once, kept in durable storage, announced with a notice that opens the
-- Moments tab; the shiny log is honoured retroactively with one notice.
local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 1
local run = T.sdk.loadMod(path, { generation = generation, data = T.fixtures.load() })
T.eq(#run.errors, 0, "Kanto Gear boots without errors")

local now = 100
love.timer.getTime = function() return now end
local world = { map = { id = "ROUTE_29" } }
local game = { data = run.data, world = world,
  save = { generation = generation, version = generation == 2 and "crystal" or "red",
    meta = { playthroughId = "moments-test" }, playTime = { hours = 3, minutes = 25, seconds = 9 },
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
local mod = up(display.bindMoments, "mod")
local stored, writes = {}, 0
mod.storage = {
  read = function(_, _, key) return stored[key] end,
  write = function(_, _, key, value) stored[key] = value; writes = writes + 1; return true end,
}
local current
mod.battle = { snapshot = function() return current end }
run.loader.events:emit("game.ready", { game = game })
local session, events = display.session, run.loader.events
display.home.help, display.home.helpSeen = nil, true
local theme = up(display.drawShinyHunt, "THEME").hgss
T.check(type(display.moments) == "table" and display.moments.data.retro == true, "Moments bind with the playthrough")
display.setPackageInstalled("achievements", true)
session.page = "HOME"

local function earned(id)
  for _, record in ipairs(display.moments.data.earned) do if record.id == id then return record end end
end
local function queued(key)
  local notices = display.notices
  if notices.current and notices.current.key == key then return notices.current end
  for _, card in ipairs(notices.queue) do if card.key == key then return card end end
end

-- A trainer battle won with 1 HP: Gen 2 announces the start twice.
local trainer = { id = 4, classId = "YOUNGSTER", memberId = "JOEY_1", name = "YOUNGSTER JOEY" }
local function party(...)
  local out = {}
  for index, hp in ipairs({ ... }) do out[index] = { species = "FIXMON_A", name = "MON" .. index, hp = hp, level = 12 } end
  return out
end
current = { kind = "trainer", turn = 2, player = { species = "FIXMON_A", name = "EMBER", level = 12, hp = 9 },
  enemy = { species = "FIXMON_B", level = 13, hp = 20 }, party = party(9, 0, 0), items = {} }
session.battle = current
events:emit("battle.started", { kind = "trainer", trainerId = 4, battle = { trainer = trainer } })
events:emit("battle.started", { kind = "trainer", battle = { battle = { trainer = trainer } } })
display.momentsObserveSnapshot(current)
current.player.hp, current.enemy.hp, current.turn = 1, 0, 3
current.party[1].hp = 1
events:emit("battle.ended", { result = "win" })
events:emit("battle.ended", { result = "win" })
local hp = earned("last_hp")
T.check(hp ~= nil and hp.name == "EMBER" and hp.play == 3 * 3600 + 25 * 60 + 9, "1 HP left is a moment with who and when")
T.check(earned("last_standing") ~= nil, "one Pokemon standing out of three")
T.eq(#display.moments.data.earned, 2, "the second end event adds nothing")
T.check(stored["moments/state"] ~= nil and #stored["moments/state"].earned == 2, "moments are kept in durable storage")
local card = queued("moment:last_hp")
T.check(card ~= nil and card.app == "achievements" and card.drawIcon and card.onOpen, "the moment is announced")
T.check(display.noticeUnread("achievements"), "the Stamps app carries a dot")
session.battle = nil

-- Losing, then beating the same trainer, is a rematch.
current = { kind = "trainer", turn = 1, player = { species = "FIXMON_A", level = 12, hp = 0 },
  enemy = { species = "FIXMON_B", level = 13, hp = 5 }, party = party(0), items = {} }
now = now + 10
events:emit("battle.started", { kind = "trainer", trainerId = 4, battle = { trainer = trainer } })
events:emit("battle.ended", { result = "lose" })
T.check(earned("rematch") == nil, "a loss is no moment")
now = now + 10
events:emit("battle.started", {kind="trainer",trainerId=4,
  battle={trainer={classId="YOUNGSTER",memberId="OTHER_1",name=trainer.name}}})
events:emit("battle.ended", {result="win"})
T.check(earned("rematch") == nil, "another member of the same named trainer class is not a rematch")
now = now + 10
current = { kind = "trainer", turn = 22, player = { species = "FIXMON_A", level = 12, hp = 30 },
  enemy = { species = "FIXMON_B", level = 13, hp = 0 }, party = party(30, 20), items = {} }
events:emit("battle.started", { kind = "trainer", trainerId = 4, battle = { trainer = trainer } })
events:emit("battle.ended", { result = "win" })
T.check(earned("rematch") ~= nil and earned("rematch").foe == "YOUNGSTER JOEY", "beating the same trainer is a rematch")
T.check(earned("marathon") ~= nil, "a 22-turn battle is a marathon")

-- The very last ball, on the first throw, for a legend.
now = now + 10
current = { kind = "wild", turn = 1, player = { species = "FIXMON_A", level = 40, hp = 30 },
  enemy = { species = "SUICUNE", level = 40, hp = 30 }, party = party(30),
  items = { { id = "POKE_BALL", ball = true, count = 1 } } }
events:emit("battle.started", { kind = "wild", species = "SUICUNE", battle = {} })
display.momentsObserveSnapshot(current)
events:emit("battle.ball_thrown", { ball = "POKE_BALL", caught = true })
current.items = {}
events:emit("pokemon.caught", { species = "SUICUNE", mon = { species = "SUICUNE" } })
events:emit("battle.ended", { result = "caught" })
T.check(earned("last_ball") ~= nil and earned("legend_first_ball") ~= nil, "the last ball caught a legend at once")
T.check(earned("stubborn") == nil, "one throw is not stubborn")

-- The Moments tab draws, opens a moment and walks back.
session.page = "ACHIEVEMENTS"
display.achievements.view = "moments"
local ok, err = pcall(display.drawAchievements)
T.check(ok, "the Moments tab draws: " .. tostring(err))
T.check(not display.moments.unseen, "seeing the tab clears its dot")
display.tapAchievements(120, 98)
T.eq(display.achievements.view, "moment", "a card opens its moment")
ok, err = pcall(display.drawAchievements)
T.check(ok, "a moment page draws: " .. tostring(err))
display.tapAchievements(10, 10)
T.eq(display.achievements.view, "moments", "back returns to the list")
pcall(display.drawAchievements)
display.tapAchievements(40, 42)
T.eq(display.achievements.view, "goals", "the Goals tab is one tap away")
T.check(display.cycleAchievementTabs(1) and display.achievements.view == "album", "swiping walks the tabs")
T.check(display.cycleAchievementTabs(1) and display.achievements.view == "moments", "to Moments")
T.check(not display.cycleAchievementTabs(1), "and stops at the last tab")
ok, err = pcall(theme.v4AchievementTabs, theme, "goals", true)
T.check(ok, "the tab bar draws with an unread dot: " .. tostring(err))

-- A tap on the notice opens that moment.
session.page = "HOME"
local marathon = queued("moment:marathon")
T.check(marathon ~= nil, "the marathon waits in the queue")
display.notices.current, display.notices.queue = nil, { marathon }
now = now + 1
display.noticeCard(now)
now = now + 0.3
T.check(display.noticeTap(120 / 1.5, 48 / 1.5), "the moment card takes a tap")
T.eq(session.page, "ACHIEVEMENTS", "it opens the Stamp Book")
T.eq(display.achievements.view, "moment", "on that moment's page")
T.eq(display.achievements.moment, "marathon", "the marathon")
T.check(not display.noticeUnread("achievements"), "and clears the dot")

-- Game packs: stories that belong to a family of games.
display.notices.current, display.notices.queue = nil, {}
events:emit("pokemon.evolved", { fromSpecies = "MAGIKARP", toSpecies = "GYARADOS", mon = { nickname = "KARPI" } })
T.check(earned("gyarados_rise") ~= nil and earned("gyarados_rise").name == "KARPI", "Magikarp into Gyarados, by name")
now = now + 10
current = { kind = "wild", turn = 4, player = { species = "FIXMON_A", level = 30, hp = 30 },
  enemy = { species = "SNORLAX", level = 30, hp = 0 }, party = party(30), items = {} }
events:emit("battle.started", { kind = "wild", species = "SNORLAX", battle = {} })
events:emit("battle.ended", { result = "win" })
T.check(earned("snorlax_awake") ~= nil, "the sleeping Snorlax was faced")
events:emit("unown.unlocked", { count = 26 })
events:emit("egg.hatched", { species = "FIXMON_A", slot = 1 })
events:emit("bug_contest.scored", { place = 1, mon = { species = "FIXMON_A" } })
events:emit("pokerus.infected", { source = "contracted", mon = { species = "FIXMON_A" } })
if generation == 2 then
  T.check(earned("unown_alphabet") and earned("first_hatch") and earned("bug_champion") and earned("pokerus"),
    "Johto keeps its Unown, eggs, contest and Pokerus moments")
  now = now + 10
  events:emit("roamer.encountered", { species = "RAIKOU" })
  current = { kind = "wild", turn = 1, player = { species = "FIXMON_A", level = 40, hp = 30 },
    enemy = { species = "RAIKOU", level = 40, hp = 30 }, party = party(30), items = {} }
  events:emit("battle.started", { kind = "wild", species = "RAIKOU", battle = {} })
  events:emit("battle.ball_thrown", { caught = true })
  events:emit("battle.ball_thrown", { caught = true })
  events:emit("pokemon.caught", { species = "RAIKOU", mon = { species = "RAIKOU" } })
  events:emit("battle.ended", { result = "caught" })
  T.check(earned("roamer_caught") ~= nil, "a roamer caught at last")
  now = now + 10
  local red = { species = "GYARADOS", level = 30, dvs = { attack = 10, defense = 10, speed = 10, special = 10 } }
  events:emit("battle.started", { kind = "wild", species = "GYARADOS", battle = { enemy = red } })
  T.check(earned("red_gyarados") ~= nil and earned("red_gyarados").shiny, "the red Gyarados of the lake")
  events:emit("battle.ended", { result = "run" })
else
  T.check(not earned("unown_alphabet") and not earned("first_hatch") and not earned("bug_champion")
    and not earned("pokerus"), "Red keeps Johto's stories out")
  now = now + 10
  events:emit("battle.started", { kind = "ghost", battle = {} })
  T.check(earned("tower_ghost") ~= nil, "the ghost of Pokemon Tower")
  events:emit("battle.ended", { result = "run" })
  now = now + 10
  current = { kind = "safari", turn = 1, player = nil, enemy = { species = "FIXMON_B", level = 20, hp = 30 },
    party = party(30), items = {} }
  events:emit("battle.started", { kind = "safari", species = "FIXMON_B", battle = {} })
  events:emit("pokemon.caught", { species = "FIXMON_B", mon = { species = "FIXMON_B" } })
  events:emit("battle.ended", { result = "caught" })
  T.check(earned("safari_catch") ~= nil, "a Safari Zone catch")
end
ok, err = pcall(display.drawAchievements)
T.check(ok, "the chronicle draws every game pack: " .. tostring(err))

-- Retroactive: a playthrough with shinies already in the log.
if generation == 2 then
  stored["moments/state"] = nil
  stored["shiny/state"] = { log = { { species = "ZUBAT", name = "ZUBAT", kind = "lucky", count = 0, at = 50,
      via = "battle", place = "UNION CAVE" },
    { species = "ABRA", name = "ABRA", kind = "target", count = 8192, at = 90, via = "battle" } }, met = 2 }
  display.notices.current, display.notices.queue = nil, {}
  display.bindShinyHunt()
  display.bindMoments()
  local first = earned("first_shiny")
  T.check(first ~= nil and first.name == "ZUBAT" and first.place == "UNION CAVE" and first.at == 50 and first.retro,
    "the first shiny of the log becomes a moment with its own place and date")
  T.check(earned("shiny_exact_odds") ~= nil, "exactly 1 in 8192 is honoured retroactively")
  T.eq(#display.notices.queue, 1, "one collective notice")
  T.eq(display.notices.queue[1] and display.notices.queue[1].key, "moments:retro", "for everything at once")
  display.bindMoments()
  T.eq(#display.notices.queue, 1, "and only once")

  -- Live: a shiny met in battle is the first-shiny moment of a fresh playthrough.
  stored = {}
  display.bindShinyHunt(); display.bindMoments()
  local mon = { species = "PIDGEY", level = 5, dvs = { attack = 10, defense = 10, speed = 10, special = 10 } }
  now = now + 10
  events:emit("battle.started", { kind = "wild", battle = { enemy = mon } })
  T.check(earned("first_shiny") ~= nil and earned("first_shiny").shiny, "a live first shiny is a moment")
  events:emit("battle.ended", { result = "run" })
else
  T.check(earned("first_shiny") == nil, "Gen 1 has no shiny moments")
end

T.finish("Moments runtime")
