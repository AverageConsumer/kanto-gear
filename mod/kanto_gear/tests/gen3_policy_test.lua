local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local Rules = assert(loadfile(root .. "/tests/support/module.lua"))()(root, "adapters/gen3/progress/policies")
local flags = { FLAG_HIDE_ROOT_FOSSIL = 501, FLAG_HIDE_CLAW_FOSSIL = 502,
  FLAG_CHOSE_ROOT_FOSSIL = 511, FLAG_CHOSE_CLAW_FOSSIL = 512,
  FLAG_HIDE_MIRAGE_TOWER_ROOT_FOSSIL = 521, FLAG_HIDE_MIRAGE_TOWER_CLAW_FOSSIL = 522,
  FLAG_HIDE_DESERT_UNDERPASS_FOSSIL = 531, FLAG_LINK_CONTEST_ROOM_POKEBALL = 541,
  FLAG_HIDE_CONTEST_POKE_BALL = 542, FLAG_HIDE_LITTLEROOT_TOWN_BRENDANS_HOUSE_2F_POKE_BALL = 543,
  FLAG_HIDE_LITTLEROOT_TOWN_MAYS_HOUSE_2F_POKE_BALL = 544 }
local progress = { constants = { flag = function(_, name) return flags[name] end,
  var = function(_, name) return name == "VAR_MIRAGE_TOWER_STATE" and 551 end },
  adapter = { data = { items = { [286] = { name = "ROOT FOSSIL" }, [287] = { name = "CLAW FOSSIL" } } } } }
local function items(map, flag, vars, value)
  local out = { {}, {}, {}, {} }
  local obj = { flag = flag, localId = 7 }
  local handled = Rules.items(progress, map, obj, { [0x8000] = vars or {} }, value, out,
    function() return { id = "object", index = obj.localId } end)
  return out[2], handled
end
for _, flag in ipairs({ 54, 55 }) do
  local rows, handled = items("FR_ROCKET_HIDEOUT_B4F", flag, nil, 369)
  T.check(handled and #rows == 1 and rows[1].ownedKey, "initial hide flags require key-item ownership")
  T.eq(rows[1].event, nil, "initial hide flags cannot prove key-item collection")
end
for _, flag in ipairs({ 47, 48 }) do
  local rows, handled = items("FR_MT_MOON_B2F", flag)
  T.check(handled and #rows == 1, "Mt Moon keeps one selectable fossil objective")
  T.eq(rows[1].itemId, flag == 47 and 358 or 357, "fossil item identity is retained")
  T.eq(rows[1].event, flag == 47 and 626 or 627, "fossil choice has its own receipt")
  T.eq(rows[1].alternative, flag == 47 and 627 or 626, "unchosen fossil stays an alternative")
end
for _, pair in ipairs({ {138,749,626,627}, {140,748,627,626} }) do
  local row = { species = pair[1], event = pair[2] }
  Rules.revivedFossil("FR_CINNABAR_ISLAND_POKEMON_LAB_EXPERIMENT_ROOM", row)
  T.eq(row.alternative, pair[3], "revived fossil keeps its selected-item relationship")
  T.eq(row.choiceEvent, pair[4], "revived fossil keeps its excluded choice")
end
local wrongReceipt = { species = 138, event = 748 }
Rules.revivedFossil("FR_CINNABAR_ISLAND_POKEMON_LAB_EXPERIMENT_ROOM", wrongReceipt)
T.eq(wrongReceipt.alternative, nil, "another reward's receipt is not accepted")
local rows, handled = items("CUSTOM_ROUTE", 47)
T.check(not handled and #rows == 0, "custom maps do not inherit story objectives by flag alone")
progress.rs = true
rows, handled = items("RU_ROUTE111", 501)
T.check(handled and #rows == 1, "RS represents the durable fossil choice once")
T.eq(rows[1].itemId, nil, "RS does not invent which fossil was chosen")
T.eq(rows[1].label, "ROOT FOSSIL / CLAW FOSSIL", "RS choice names both possible rewards")
rows, handled = items("SA_ROUTE111", 502)
T.check(handled and #rows == 0, "the second RS hide flag adds no duplicate objective")
T.check(Rules.decorativeBall(progress, { flag = 541 }), "RS contest display balls are decorative")
progress.rs, progress.emerald = false, true
for _, flag in ipairs({ 521, 522 }) do
  local item = flag == 521 and 286 or 287
  rows, handled = items("EM_MIRAGE_TOWER_4F", flag, { [item] = true })
  T.check(handled and #rows == 1, "Emerald tower tracks the actually offered fossil")
  T.eq(rows[1].event, item == 286 and 511 or 512, "collapse hide flags are not fossil receipts")
end
rows, handled = items("EM_DESERT_UNDERPASS", 531, { [286] = true, [287] = true })
T.check(handled and #rows == 2, "remaining-fossil script preserves its two alternatives")
T.eq(rows[1].needsChoice, 512, "Root reward requires the prior Claw choice")
T.eq(rows[2].needsChoice, 511, "Claw reward requires the prior Root choice")
T.eq(rows[1].choiceGroup, rows[2].choiceGroup, "remaining fossil is one exclusive choice group")
T.eq(rows[1].unlockVar, 551, "remaining fossil retains its story unlock variable")
for _, flag in ipairs({ 542, 543, 544 }) do
  T.check(Rules.decorativeBall(progress, { flag = flag }), "Emerald display balls are not collectible goals")
end
T.check(not Rules.decorativeBall(progress, { flag = 999 }), "ordinary balls remain eligible objectives")
T.check(Rules.uncatchable("FR_POKEMON_TOWER_6F", 105), "Marowak ghost is not a catch objective")
T.check(not Rules.uncatchable("CUSTOM_ROUTE", 105), "catchable Marowak elsewhere is retained")
T.finish("Gen3 edition objective policies")
