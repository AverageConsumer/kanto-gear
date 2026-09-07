local H = assert(loadfile("mod/kanto_gear/habitats.lua"))()
local checks = 0
local function eq(a, b, label)
  checks = checks + 1
  assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
local items = { TM02 = { teaches = "HEADBUTT" }, HM03 = { machine = { move = "SURF" } },
  MOD_TM = { teaches = "ROCK_SMASH" } }
local save = { inventory = {}, party = {}, boxes = {} }
local methods = H.methods(save, items, false)
eq(methods.OLD, "NEED OLD ROD", "missing rod")
eq(methods.HEADBUTT, "NEED HEADBUTT", "missing Headbutt")
save.inventory = { TM02 = 1, HM03 = 1, MOD_TM = 1, OLD_ROD = 1 }
methods = H.methods(save, items, false)
eq(methods.HEADBUTT, nil, "an unlearned TM is usable for planning")
eq(methods["RARE TREE"], nil, "rare trees use the same Headbutt unlock")
eq(methods["ROCK SMASH"], nil, "machine definitions work with custom item IDs")
eq(methods.OLD, nil, "owned rod")
eq(methods.GOOD, "NEED GOOD ROD", "a better rod is a separate requirement")
eq(methods.SURF, "NEED BADGE", "owning an HM cannot bypass its badge")
eq(H.methods(save, items, true).SURF, nil, "HM plus badge needs no taught party move")
save.inventory.TM02 = 0
eq(H.methods(save, items, true).HEADBUTT, "NEED HEADBUTT", "a spent or sold TM alone is not available")
save.boxes[8] = { { moves = { {}, { id = "HEADBUTT" } } } }
eq(H.methods(save, items, true).HEADBUTT, nil, "a boxed partner counts even in a sparse box list")
save.party = { { moves = { { id = "SURF" } } } }; save.inventory.HM03 = nil
eq(H.methods(save, items, false).SURF, "NEED BADGE", "a learned move still needs its badge")

local appearances = {
  { mapId = "CAVE_B1F", method = "WALK", chance = 90 },
  { mapId = "ROUTE_2", method = "HEADBUTT", chance = 90 },
  { mapId = "ROUTE_2", method = "WALK", chance = 10 },
  { mapId = "CAVE_1F", method = "WALK", time = "NITE", chance = 30 },
  { mapId = "CAVE_1F", method = "SUPER", chance = 80 },
  { mapId = "CURRENT", method = "WALK", chance = 5 },
  { mapId = "ROUTE_2", method = "WALK", chance = 30 },
  { mapId = "CAVE_1F", method = "WALK", time = "DAY", chance = 20 },
}
local visited = { ROUTE_2 = true, CAVE_1F = true }
local plan = H.plan(appearances, "CURRENT", "DAY", visited, H.methods(save, items, true))
eq(plan.rows[1].appearance.mapId, "CURRENT", "current map first, even without stored visit")
eq(plan.rows[1].current, true, "current badge requires method and time")
eq(plan.rows[2].appearance.chance, 30, "easier visited walks sort by chance")
eq(plan.rows[5].appearance.method, "HEADBUTT", "walking comes before higher-chance trees")
eq(plan.rows[6].status, "ONLY %s", "visited wrong-time habitat has a concrete reason")
eq(plan.rows[7].status, "NEED SUPER ROD", "missing tool follows known time-only restrictions")
eq(plan.rows[8].status, "NOT VISITED", "visiting a cave floor does not visit its basement")
eq(plan.count, 3, "matching areas are distinct maps across every result page")
eq(appearances[1].mapId, "CAVE_B1F", "sorting leaves shared encounter tables untouched")
eq(appearances[1].rank, nil, "planning never annotates shared encounter rows")
local signature = plan.signature
for _ = 1, 50 do
  eq(H.plan(appearances, "CURRENT", "DAY", visited, H.methods(save, items, true)).signature,
    signature, "equal inputs keep a deterministic order")
end
local none = H.plan({ appearances[1], appearances[4], appearances[5] }, "ELSEWHERE", "DAY", visited,
  H.methods(save, items, true))
eq(none.count, 0, "no known matching area is explicit")
local night = H.plan({ appearances[4] }, "ELSEWHERE", "NITE", visited, {})
eq(night.count, 1, "a time change updates suitability")
eq(H.plan({ appearances[5] }, "CAVE_1F", "DAY", {}, methods).rows[1].current,
  false, "being on a map cannot bypass the required rod")
eq(H.plan({}, "CURRENT", "DAY", {}, {}).count, 0, "no wild habitats")
eq(H.plan({ { mapId = "CUSTOM_BASEMENT", method = "WALK" } }, "CUSTOM_BASEMENT", "DAY", {}, {}).count,
  1, "custom map IDs require no special-case list")
print(checks .. "/" .. checks .. " habitat planning checks passed")
