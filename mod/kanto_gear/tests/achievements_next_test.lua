-- Next-stamp guidance: what the following tier needs, per discovery mode.
local root = os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local A = assert(loadfile(root .. "/features/achievements.lua"))()
local passed, failed = 0, 0
local function check(condition, label)
  if condition then passed = passed + 1 else failed = failed + 1; io.stderr:write("FAIL " .. label .. "\n") end
end
local function area(id, tier, counts, extra)
  local a = { id = id, tier = tier, evidence = true, complete = tier == "gold", sections = {} }
  for i, pair in ipairs(counts) do a.sections[i] = { done = pair[1], total = pair[2] } end
  for k, v in pairs(extra or {}) do a[k] = v end
  return a
end

local bronze = area("ROUTE_31", "bronze", { { 1, 3 }, { 1, 2 }, { 0, 1 }, { 3, 6 } })
local step = A.nextStep(bronze, "spoiler")
check(A.nextStep(bronze, "vanilla") == nil, "vanilla never guides even an unfiltered tier")
check(step.target == "silver" and step.trainers == 2 and step.items == 1 and step.hidden == 1
  and step.pokemon == 0 and step.count == 4, "bronze needs only field tasks for silver")
step = A.nextStep(bronze, "enhanced")
check(step.hidden == 0 and step.count == 3, "enhanced mode never advertises hidden finds")

local silver = area("ROUTE_30", "silver", { { 3, 3 }, { 2, 2 }, { 2, 2 }, { 4, 8 } })
step = A.nextStep(silver, "enhanced")
check(step.target == "gold" and step.pokemon == 4 and step.trainers == 0 and step.count == 4,
  "silver needs only the local Pokemon for gold")

check(A.nextStep(area("ROUTE_29", "gold", { { 2, 2 }, { 1, 1 }, { 1, 1 }, { 5, 5 } }), "spoiler") == nil,
  "a gold stamp has no next step")
check(A.nextStep(area("ROUTE_32", nil, { { 0, 3 }, { 0, 1 }, { 0, 1 }, { 0, 4 } }), "vanilla") == nil,
  "vanilla presentation (no tier) has no next step")
check(A.nextStep(area("ROUTE_33", "none", { { 0, 1 }, { 0, 1 }, { 0, 0 }, { 0, 2 } }, { evidence = false }), "spoiler") == nil,
  "an unvisited area has no next step")
check(A.nextStep(area("ROUTE_34", "bronze", { { 1, 1 }, { 1, 1 }, { 0, 0 }, { 0, 3 } }, { unknown = 1 }), "spoiler").untracked,
  "untracked rows are reported instead of hidden")

local missed = area("ROUTE_37", "bronze", { { 2, 3 }, { 1, 1 }, { 1, 1 }, { 2, 4 } })
missed.sections[1].unavailable = 1
check(A.nextStep(missed, "spoiler").count == 0, "a missed obligation is never reported as left")

local hiddenOnly = area("ROUTE_35", "bronze", { { 2, 2 }, { 1, 1 }, { 0, 2 }, { 1, 1 } })
local union = area("UNION_CAVE", "bronze", { { 2, 5 }, { 3, 6 }, { 1, 4 }, { 4, 7 } })
local here = area("ROUTE_36", "silver", { { 1, 1 }, { 0, 0 }, { 0, 0 }, { 2, 6 } }, { current = true })
local goals = A.nextGoals({ union, silver, bronze, hiddenOnly, here }, "enhanced", 3)
check(#goals == 3, "the goal list is limited")
check(goals[1].area == bronze and goals[1].step.count == 3, "closest next stamp comes first")
check(goals[2].area == here and goals[3].area == silver, "the current area wins a tie")
for _, goal in ipairs(goals) do
  check(goal.area ~= hiddenOnly, "an area waiting only on hidden finds is not suggested outside Spoiler")
end
check(A.nextGoals({ hiddenOnly }, "spoiler", 3)[1].step.hidden == 2, "Spoiler suggests remaining hidden finds")

io.write(string.format("%d/%d checks passed  (next stamp guidance)\n", passed, passed + failed))
if failed > 0 then os.exit(1) end
