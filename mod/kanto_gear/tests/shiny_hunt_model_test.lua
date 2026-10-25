-- Shiny Hunt model: odds arithmetic, counters, finds, phases and storage.
local root = os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local S = assert(loadfile(root .. "/features/shiny_hunt.lua"))()
local passed, failed = 0, 0
local function check(condition, label)
  if condition then passed = passed + 1 else failed = failed + 1; io.stderr:write("FAIL " .. label .. "\n") end
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-9) end

-- Gen 2's DV pattern: Defense, Speed and Special 10, Attack 2/3/6/7/10/11/14/15.
check(S.gen2Shiny({ attack = 10, defense = 10, speed = 10, special = 10 }), "the classic all-10 spread is shiny")
for _, attack in ipairs({ 2, 3, 6, 7, 11, 14, 15 }) do
  check(S.gen2Shiny({ attack = attack, defense = 10, speed = 10, special = 10 }), "attack " .. attack .. " is shiny")
end
for _, attack in ipairs({ 0, 1, 4, 5, 8, 9, 12, 13 }) do
  check(not S.gen2Shiny({ attack = attack, defense = 10, speed = 10, special = 10 }), "attack " .. attack .. " is not")
end
check(not S.gen2Shiny({ attack = 10, defense = 10, speed = 9, special = 10 }), "speed must be 10")
check(not S.gen2Shiny(nil), "missing DVs are not shiny")

-- Full odds: the familiar milestones at 1/8192.
check(S.milestone(0.5) == 5678, "50% after 5,678 rolls")
check(S.milestone(0.9) == 18862, "90% after 18,862 rolls")
check(S.milestone(0.99) == 37724, "99% after 37,724 rolls")
check(near(S.chance({ battles = 8192, hatches = 0, boosted = 0, manual = 0 }), 1 - (1 - 1 / 8192) ^ 8192),
  "1x odds is about 63%")
check(S.percent(S.chance({ battles = 8192, hatches = 0, boosted = 0, manual = 0 })) == "63%", "1x odds reads 63%")
check(near(S.chance({ battles = 0, hatches = 0, boosted = 64, manual = 0 }), 1 - (63 / 64) ^ 64),
  "boosted Gen 2 eggs roll 1 in 64")
check(near(S.oddsMultiple({ battles = 4096, hatches = 0, boosted = 32, manual = 0 }), 1.0), "half odds plus half a boosted run")
check(S.percent(0) == "0.00%" and S.percent(1 / 8192) == "0.01%" and S.percent(0.025) == "2.5%",
  "small chances keep their precision")
check(S.percent(0.99996) == "99.9%", "a miss is never rounded to a certainty")
check(S.group(1234567) == "1,234,567" and S.group(12) == "12", "counts group by thousands")
check(S.multipleLabel(0.155) == "0.16" and S.multipleLabel(12.4) == "12", "odds multiples read as hunters say them")

-- A hunt: wild battles of the target count, others are kept apart.
local state = S.normalize(nil)
check(state.auto == true and next(state.hunts) == nil, "a fresh state counts automatically")
S.setTarget(state, "ABRA", "ABRA", 1000)
local out = S.observe(state, { via = "battle", species = "ABRA", name = "ABRA" }, 1000)
check(out.counted and S.count(S.active(state)) == 1, "the target's battle counts")
out = S.observe(state, { via = "battle", species = "PIDGEY", name = "PIDGEY" }, 1010)
check(not out.counted and S.active(state).others == 1, "another species is an encounter, not a roll for the target")
check(state.last.species == "PIDGEY", "the last Pokemon met is remembered")
check(S.active(state).time == 10, "short gaps count as hunting time")
S.observe(state, { via = "battle", species = "ABRA" }, 1010 + S.IDLE_GAP + 1)
check(S.active(state).time == 10, "a long break is not hunting time")
check(S.count(S.active(state)) == 2 and state.encounters == 3, "wild encounters are tallied")

-- Manual keys never take the count below zero.
check(S.adjust(state, 1, 2000) and S.count(S.active(state)) == 3, "+1 adds a manual roll")
check(S.adjust(state, -5, 2000) and S.count(S.active(state)) == 0, "-1 stops at zero")
check(not S.adjust(state, -1, 2000), "nothing to take away at zero")

-- Paused: no counting, but a shiny is still recorded.
S.setAuto(state, false)
out = S.observe(state, { via = "battle", species = "ABRA" }, 2100)
check(not out.counted and S.count(S.active(state)) == 0, "a paused hunt does not count")
S.setAuto(state, true)

-- A phase: another shiny while hunting.
S.adjust(state, 40, 2200)
out = S.observe(state, { via = "battle", species = "PIDGEY", name = "PIDGEY", shiny = true }, 2210)
check(out.phase and S.active(state).phases == 1 and state.log[1].kind == "phase", "an off-target shiny is a phase")
check(state.log[1].count == 40 and state.log[1].target == "ABRA", "the phase remembers the count and the target")
check(not S.active(state).found, "a phase does not end the hunt")

-- The find ends the hunt and stops counting.
out = S.observe(state, { via = "battle", species = "ABRA", name = "ABRA", shiny = true }, 2300)
check(out.found and S.active(state).found.count == 41, "the target shiny is found after its own roll")
check(state.log[1].kind == "target" and #state.log == 2, "the find is logged first")
out = S.observe(state, { via = "battle", species = "ABRA" }, 2310)
check(not out.counted and S.count(S.active(state)) == 41, "a finished hunt stops counting")
check(not S.adjust(state, 1, 2310), "a finished hunt takes no manual rolls")
check(S.headline(S.view(state)).kind == "found", "the widgets lead with the find")
S.restart(state, 2400)
check(S.count(S.active(state)) == 0 and not S.active(state).found and S.active(state).species == "ABRA",
  "Hunt again starts the same target from zero")
check(#state.log == 2, "the log keeps the find")

-- Switching keeps every counter; returning resumes it.
S.adjust(state, 7, 2500)
S.setTarget(state, "MAGIKARP", "MAGIKARP", 2600)
S.observe(state, { via = "battle", species = "MAGIKARP" }, 2600)
S.setTarget(state, "ABRA", nil, 2700)
check(S.count(S.active(state)) == 7, "a shelved hunt resumes its count")
local view = S.view(state)
check(#view.shelf == 1 and view.shelf[1].species == "MAGIKARP", "other hunts are listed")

-- Eggs: hatches count; Gen 2 boosted hatches roll at 1 in 64.
S.setTarget(state, "TOGEPI", "TOGEPI", 3000)
S.observe(state, { via = "egg", species = "TOGEPI" }, 3000)
S.observe(state, { via = "egg", species = "TOGEPI", boosted = true }, 3010)
local togepi = S.active(state)
check(togepi.hatches == 1 and togepi.boosted == 1 and S.count(togepi) == 2, "hatches and boosted hatches are kept apart")
check(near(S.chance(togepi), 1 - (8191 / 8192) * (63 / 64)), "each hatch rolls at its own odds")
check(S.method(togepi) == "EGGS" and state.encounters == 8, "an egg hunt reads as eggs; hatches are no encounters")

-- Any Pokemon: every wild encounter counts and any shiny is the find.
S.setTarget(state, S.ANY, nil, 4000)
S.observe(state, { via = "battle", species = "RATTATA" }, 4000)
out = S.observe(state, { via = "battle", species = "ZUBAT", name = "ZUBAT", shiny = true }, 4005)
check(out.found and S.active(state).found.species == "ZUBAT" and S.count(S.active(state)) == 2,
  "any shiny ends an any-Pokemon hunt")

-- No hunt: a shiny is still logged as luck.
S.clearTarget(state)
out = S.observe(state, { via = "battle", species = "GEODUDE", shiny = true }, 5000)
check(out.lucky and state.log[1].kind == "lucky", "a shiny without a hunt is logged")
check(S.headline(S.view(state)).kind == "idle", "without a target the widgets are idle")

-- Storage round trip, and hostile records are dropped.
local copy = S.normalize(state)
check(S.count(copy.hunts.ABRA) == 7 and copy.hunts.TOGEPI.boosted == 1 and #copy.log == #state.log,
  "a stored state reads back the same")
local hostile = S.normalize({ auto = false, active = "NOPE", hunts = { X = { species = "Y", battles = 5 },
  ABRA = { species = "ABRA", battles = -4, manual = "x", time = 1 / 0 } }, log = { "junk", { kind = "evil" } } })
check(hostile.auto == false and hostile.active == nil, "an unknown active hunt is cleared")
check(hostile.hunts.X == nil and hostile.hunts.ABRA.battles == 0 and hostile.hunts.ABRA.manual == 0
  and hostile.hunts.ABRA.time == 0, "malformed counters are reset")
check(#hostile.log == 0, "malformed log rows are dropped")
local numeric = S.normalize({ active = "25", hunts = { ["25"] = { species = 25, battles = 3 } } })
check(S.count(S.active(numeric)) == 3, "Gen 3's numeric species keep their counters")

-- Limits: the log and the shelf stay bounded.
local many = S.normalize(nil)
for index = 1, S.LOG_LIMIT + 10 do
  S.observe(many, { via = "battle", species = "S" .. index, shiny = true }, index)
end
check(#many.log == S.LOG_LIMIT and many.log[1].species == "S" .. (S.LOG_LIMIT + 10), "the log keeps the newest finds")
for index = 1, S.HUNT_LIMIT + 5 do S.setTarget(many, "T" .. index, nil, index) end
local count = 0
for _ in pairs(many.hunts) do count = count + 1 end
check(count <= S.HUNT_LIMIT and many.hunts["T" .. (S.HUNT_LIMIT + 5)] ~= nil, "the oldest idle hunts make room")

-- Memories: the first shiny of a playthrough is marked once, with its place.
local memory = S.normalize(nil)
S.observe(memory, { via = "battle", species = "ZUBAT", shiny = true, place = "UNION CAVE" }, 10)
S.observe(memory, { via = "battle", species = "GEODUDE", shiny = true }, 20)
check(memory.log[2].first == true and memory.log[2].place == "UNION CAVE", "the first shiny remembers where it was met")
check(memory.log[1].first == nil and memory.met == 2, "only the first one is the first")
local reread = S.normalize(memory)
check(reread.log[2].first == true and reread.log[2].place == "UNION CAVE" and reread.met == 2,
  "memories survive storage")
check(S.normalize({ log = { { species = "A", first = "yes", place = 4 } } }).log[1].place == nil,
  "malformed memories are dropped")

io.write(string.format("%d/%d checks passed  (shiny hunt model)\n", passed, passed + failed))
if failed > 0 then os.exit(1) end
