-- Day-Care model: fees, compatibility bands, move shifts and disclosure.
local root = os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local D = assert(loadfile(root .. "/features/daycare.lua"))()
local passed, failed = 0, 0
local function check(condition, label)
  if condition then passed = passed + 1 else failed = failed + 1; io.stderr:write("FAIL " .. label .. "\n") end
end

check(D.fee(0) == 100 and D.fee(5) == 600, "fee is 100 plus 100 per level")

-- Gen 2 wBreedingCompatibility values and their egg-roll percentages.
local function gen2(value) return D.compatibility(2, value) end
check(gen2(254).tier == 3 and gen2(254).chance == 31, "same species, other trainer: 80/256")
check(gen2(177).tier == 2 and gen2(177).chance == 16, "same species, same trainer: 40/256")
check(gen2(128).tier == 2 and gen2(128).chance == 12, "other species, other trainer: 30/256")
check(gen2(51).tier == 1 and gen2(51).chance == 4, "other species, same trainer: 10/256")
check(gen2(0).tier == 0 and gen2(255).tier == 0, "no eggs and matching DVs both breed nothing")
check(D.compatibility(3, 70).tier == 3 and D.compatibility(3, 50).tier == 2
  and D.compatibility(3, 20).tier == 1 and D.compatibility(3, 0).tier == 0
  and D.compatibility(3, 50).chance == 50, "Gen 3 scores are the percent per check")

-- Moves: appended until four, then the oldest shifts out.
local learned, forgotten, now = D.learnedMoves({ "A", "B", "C" }, {
  { level = 10, move = "B" }, { level = 12, move = "D" }, { level = 15, move = "E" },
  { level = 20, move = "F" }, { level = 30, move = "G" } }, 10, 20)
check(#learned == 3 and learned[1] == "D" and learned[3] == "F", "learns new moves in (from, to]")
check(#forgotten == 2 and forgotten[1] == "A" and forgotten[2] == "B", "oldest moves are pushed out")
check(#now == 4 and now[4] == "F", "four moves stay")
learned, forgotten = D.learnedMoves({ "A", "B", "C", "D" }, {
  { level = 11, move = "E" }, { level = 12, move = "F" }, { level = 13, move = "G" },
  { level = 14, move = "H" }, { level = 15, move = "I" } }, 10, 15)
check(#learned == 4 and learned[1] == "F", "a move learned and pushed out in one stay is not listed")
check(#forgotten == 4, "every original move is reported once")

check(D.gen3StepsToCheck(0) == 255 and D.gen3StepsToCheck(254) == 1
  and D.gen3StepsToCheck(255) == 256 and D.gen3StepsToCheck(510) == 1, "Gen 3 egg roll on the 255th step byte")
check(D.gen2StepsToCheck(98) == 98 and D.gen2StepsToCheck(0) == 256, "Gen 2 countdown byte")
check(D.stage(5) == 1 and D.stage(6) == 2 and D.stage(10) == 2 and D.stage(11) == 3
  and D.stage(40) == 3 and D.stage(41) == 4, "hatch bands follow the summary texts")

local input = {
  generation = 2, partyCount = 6, partyMax = 6,
  parents = { { key = "man", name = "MARILL", levelFrom = 19, levelNow = 25 },
    { key = "lady", name = "TOTODILE", levelFrom = 22, levelNow = 27 } },
  compatibilityValue = 128, breeding = true, stepsToCheck = 98,
  egg = { species = 158, speciesName = "TOTODILE", moves = { "SURF" } },
  eggs = { { slot = 6, cycles = 3, steps = 700, speciesName = "TOGEPI" } },
}
local open = D.build(input, { odds = true, eggSpecies = true, eggProgress = true })
check(open.fees == 1300 and open.parents[1].grown == 6, "fees add up over both boarders")
check(open.compatibility.chance == 12 and open.compatibility.tip, "odds show the percent and the tip")
check(open.egg.stepsToCheck == 98 and open.egg.speciesName == "TOTODILE" and open.egg.moves[1] == "SURF",
  "the prepared egg is shown with its moves")
check(open.partyFull, "a full party is reported")
check(open.eggs[1].steps == 700 and open.eggs[1].speciesName == "TOGEPI", "egg progress and contents")
local closed = D.build(input, {})
check(closed.compatibility.chance == nil and closed.compatibility.label == "GET ALONG",
  "without odds only the Day-Care Man's verdict remains")
check(closed.egg.stepsToCheck == nil and closed.egg.speciesName == nil and closed.egg.moves == nil,
  "egg timing and contents stay hidden")
check(closed.eggs[1].steps == nil and closed.eggs[1].stageLabel == "HATCHES SOON",
  "hatch progress falls back to the summary band")
input.eggWaiting = true
check(D.build(input, {}).egg.waiting, "a waiting egg is always news")
check(D.headline(D.build(input, {})).kind == "egg_waiting", "the widget leads with the waiting egg")
input.eggWaiting, input.compatibilityValue = false, 0
local none = D.build(input, { odds = true })
check(none.compatibility.tier == 0 and none.egg == nil, "an incompatible pair has no egg countdown")
check(D.headline(none).kind == "hatching", "the next hatch leads when no egg is coming")

local gen1 = D.build({ generation = 1, parents = { { name = "PIKACHU", levelFrom = 12, levelNow = 15,
  learned = { "THUNDER WAVE" }, forgotten = { "GROWL" } } } }, {})
check(gen1.compatibility == nil and gen1.egg == nil and gen1.fees == 400, "Gen 1 boards one Pokemon")
check(gen1.parents[1].forgotten[1] == "GROWL", "Gen 1 reports the move it will forget")
check(D.build({ generation = 2 }, {}).empty and D.headline(D.build({}, {})).kind == "empty", "empty Day-Care")

io.write(string.format("%d/%d checks passed  (day-care model)\n", passed, passed + failed))
if failed > 0 then os.exit(1) end
