package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local LevelUp = assert(loadfile(path .. "/level_up.lua"))()
local tracker = LevelUp.new()
local mon = { species = "FIXMON_A", level = 5, hp = 1,
  stats = { hp = 20, attack = 10, defense = 9, speed = 8, special = 12 } }
local save = { party = { mon } }
tracker:scan(save)
T.eq(tracker:get(mon), nil, "initial load never invents prior stats")
local initial = tracker.snapshots[mon]
for _ = 1, 100 do tracker:scan(save) end
T.eq(tracker.snapshots[mon], initial, "unchanged frames reuse snapshots without allocation")
mon.hp, mon.status = 0, "PARALYSIS"
tracker:scan(save)
T.eq(tracker.snapshots[mon], initial, "damage and status do not change the maximum-stat baseline")
mon.stats.attack = 11
tracker:scan(save)
T.eq(tracker:get(mon), nil, "same-level stat changes are not level ups")
mon.level = 6
mon.stats.hp, mon.stats.attack, mon.stats.defense = 23, 13, 9
tracker:scan(save)
local gain = tracker:get(mon)
T.eq(gain.from, 5, "records the actual previous level")
T.eq(gain.to, 6, "records the actual new level")
T.eq(gain.deltas.hp, 3, "HP gain compares maxima even when fainted")
T.eq(gain.deltas.attack, 2, "a vitamin's earlier gain is not counted twice")
T.eq(gain.deltas.defense, 0, "zero gains remain explicitly available")
tracker:observe(mon)
T.eq(tracker:get(mon), gain, "duplicate events preserve the gain")
mon.level, mon.stats.attack = 7, 15
tracker:observe(mon)
T.eq(tracker:get(mon).from, 6, "sequential level ups use the preceding level")
T.eq(tracker:get(mon).deltas.attack, 2, "sequential gains are not cumulative")
local other = { species = mon.species, level = mon.level, stats = { hp = 25 } }
save.party = { other, mon }
tracker:scan(save)
T.eq(tracker:get(other), nil, "same-species team members have independent baselines")
T.eq(tracker:get(mon).from, 6, "reordering the team preserves identity")
mon.species, mon.stats.attack = "FIXMON_B", 23
tracker:scan(save)
T.eq(tracker:get(mon), nil, "evolution does not masquerade as a level gain")
mon.level = 8
mon.stats.attack = 25
tracker:scan(save)
T.eq(tracker:get(mon).deltas.attack, 2, "the next level uses post-evolution stats")
mon.stats.attack = 24
tracker:scan(save)
T.eq(tracker:get(mon), nil, "later recalculation invalidates an outdated result")
mon.level, mon.stats.attack = 9, 23
tracker:scan(save)
T.eq(tracker:get(mon).deltas.attack, -1, "modified-game negative deltas are not falsely clamped")
tracker:scan({ party = { mon } })
T.eq(tracker:get(mon), nil, "switching saves drops old comparisons")
mon.level = 10
mon.stats.special = nil
tracker:scan(tracker.save)
T.eq(tracker:get(mon).deltas.special, nil, "missing values never become made-up gains")

local restoredStats = mon.stats
mon.stats = nil
tracker:scan(tracker.save)
mon.stats, mon.level = restoredStats, 11
tracker:scan(tracker.save)
T.eq(tracker:get(mon), nil, "an unavailable stat block breaks the comparison baseline")

-- Exercise the pinned engine's calculations and event timing, not duplicate
-- formulas. The first game's commits are deferred; the second writes once.
local Runtime = require("src.mods.Runtime")
Runtime.install({ listeners = { ["pokemon.level_up"] = {} }, emit = function(_, event, payload)
  if event == "pokemon.level_up" then tracker:observe(payload.mon) end
end }, { chains = {} })
local data = T.fixtures.fresh()
local Stats = require("src.pokemon.Stats")
local Experience = require("src.battle.Experience")
local def = data.pokemon.FIXMON_A
local dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 }
mon = { species = "FIXMON_A", level = 5, dvs = dvs, statExp = {}, exp = 135,
  moves = {}, stats = Stats.calc(def, 5, dvs, {}) }
mon.hp = mon.stats.hp
save = { party = { mon }, player = {} }
tracker:scan(save)
local levels, _, steps = Experience.apply(data, mon, data.pokemon.FIXMON_B,
  50, true, 1, false, { defer = true })
T.check(#levels > 1, "fixture earns several deferred Gen 1 levels")
T.eq(tracker:get(mon), nil, "awarding deferred EXP does not report future stats")
for _, step in ipairs(steps) do
  local before, level = tracker.snapshots[mon], mon.level
  Experience.commit(data, mon, step)
  local actual = tracker:get(mon)
  T.eq(actual and actual.from, level, "real Gen 1 commit captures each previous level")
  for _, key in ipairs(Stats.ORDER) do
    T.eq(actual and actual.deltas[key], mon.stats[key] - before[key],
      "real Gen 1 commit gain: " .. key)
  end
end
local previous = tracker.snapshots[mon]
local used = require("src.inventory.ItemEffects").use(data, save, "RARE_CANDY", mon)
T.eq(used, "consumed", "real Gen 1 Rare Candy succeeds")
tracker:scan(save)
T.eq(tracker:get(mon).from, previous.level, "event-free Gen 1 Candy is captured")
T.eq(tracker:get(mon).deltas.hp, mon.stats.hp - previous.hp, "Gen 1 Candy maximum HP is exact")

local Mon = require("src.battle.gen2.Mon")
def.baseStats.specialAttack, def.baseStats.specialDefense = 65, 50
def.levelMoves = {}
mon = { species = "FIXMON_A", level = 5, dvs = dvs, statExp = {},
  experience = Mon.experienceForLevel(Mon.growthFor(data, def.growthRate), 5),
  stats = Mon.stats(def.baseStats, dvs, 5, {}), moves = {} }
mon.maxHp, mon.hp = mon.stats.hp, 1
save = { party = { mon } }
tracker:scan(save)
previous = tracker.snapshots[mon]
local result = Mon.gainExperience(mon, 3000, data)
gain = tracker:get(mon)
T.check(result.levels > 1, "real Gen 2 awards a multi-level jump")
T.eq(gain and gain.from, 5, "repeated Gen 2 events retain the original baseline")
T.eq(gain and gain.to, mon.level, "Gen 2 records the final displayed level")
for key, value in pairs(mon.stats) do
  T.eq(gain and gain.deltas[key], value - previous[key], "real Gen 2 full jump: " .. key)
end
previous = tracker.snapshots[mon]
local candy = require("src.core.gen2.ItemEffects").useOnMon("RARE_CANDY", mon, data)
T.check(candy.used, "real Gen 2 Rare Candy succeeds")
local menu = { screenId = "Gen2PartyMenu", party = save.party,
  itemResult = { slot = 1, text = candy.text } }
tracker:scan(save, menu)
T.eq(tracker:fieldMon(menu), mon, "Gen 2 Candy binds to the native result")
T.eq(tracker:get(mon).deltas.hp, mon.stats.hp - previous.hp, "Gen 2 Candy gain is exact")
menu.itemResult = { slot = 1, text = "Potion result" }
T.eq(tracker:fieldMon(menu), nil, "a later item result cannot show stale gains")
menu.itemResult = nil
T.eq(tracker:fieldMon(menu), nil, "closing the result removes the Candy panel")
Runtime.reset()
T.finish("Kanto Gear level-up tracking")
