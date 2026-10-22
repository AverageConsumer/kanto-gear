local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local Gifts = assert(loadfile(root .. "/features/gen1_gifts.lua"))()
local Progress = assert(loadfile(root .. "/features/achievements.lua"))()
require("data.scripts.init")
local scripts = require("src.script.MapScripts")
local policy = Gifts.new()
local data = { items = { POTION = { name = "POTION" }, TOWN_MAP = { name = "TOWN MAP" } } }
local save = { flags = {}, inventory = {}, pokedex = {} }
local map = { objects = { { index = 1, name = "GIVER", text = "GIFT", x = 2, y = 3, sprite = "FISHER" } } }
local function reward(event)
  return { { "face_player" }, { "check_flag", event }, { "jump_if_true", "end" },
    { "give_item", "POTION", 1 }, { "set_flag", event } }
end
local handler = reward("RECEIVED")
local talkScript = scripts.talkScript
scripts.talkScript = function(id, text)
  if id == "TEST" then return handler end
  return talkScript(id, text)
end
local function rows() return policy:rows(data, save, "TEST", map) end
T.eq(#rows(), 1, "no-argument native commands do not hide a proven gift")
T.eq(rows()[1].actorId, "TEST_obj_1", "gift retains its source NPC ID")
T.eq(rows()[1].available, true, "gift is available before receipt, including full-bag refusal")
T.eq(save.flags.RECEIVED, nil, "reading gifts never writes to the save")
save.inventory.POTION = 99
T.eq(rows()[1].done, false, "bag ownership alone never proves NPC receipt")
save.flags.RECEIVED = true
save.inventory.POTION = nil
T.eq(rows()[1].done, true, "consumed gift remains completed by its receipt")
save.flags.RECEIVED = nil
T.eq(rows()[1].done, false, "loading an older save restores the objective")
local context = { save = save, mapId = "TEST" }
local function album()
  return Progress.build({ { id = "TEST", maps = { "TEST" } } }, function()
    return { sections = { { rows = {} }, { rows = rows() }, { rows = {} } } }
  end, context).byId.TEST
end
T.eq(album().sections[2].total, 1, "gift contributes once to item completion")
T.eq(album().complete, false, "unreceived gift prevents gold")
save.flags.RECEIVED = true
T.eq(album().complete, true, "receipt completes the area without retaining the item")
save.flags.RECEIVED = nil
map.objects[1].hidden = true
T.eq(rows()[1].status, "LATER", "hidden giver remains a future objective")
save.objectToggles = { TEST = { GIVER = true } }
T.eq(rows()[1].available, true, "live visibility toggle overrides imported hidden state")
map.objects[2] = { index = 2, name = "ALTERNATE", text = "GIFT", x = 4, y = 5 }
save.objectToggles.TEST.GIVER = false
T.eq(#rows(), 1, "alternate NPC objects do not duplicate the same receipt")
T.eq(rows()[1].index, 2, "visible alternate supplies the marker")
map.objects[2] = nil
map.objects[1].hidden, save.objectToggles = nil, nil

handler = { { "check_flag", "RECEIVED" }, { "jump_if_true", "done" },
  { "give_item", "POTION" }, { "set_flag", "RECEIVED" }, { "label", "done" } }
T.eq(#rows(), 1, "named labels resolve guarded receipt writes")
handler = { { "check_flag", "RECEIVED" }, { "jump_if_true", 5 },
  { "give_item", "POTION" }, { "set_flag", "RECEIVED" } }
T.eq(#rows(), 1, "native numeric exit targets resolve")
handler = { { "check_flag", "RECEIVED" }, { "jump_if_true", "end" },
  { "set_flag", "RECEIVED" }, { "give_item", "POTION" } }
T.eq(#rows(), 0, "flag burned before a full-bag refusal cannot prove receipt")
handler[#handler + 1] = { "set_flag", "RECEIVED" }
T.eq(#rows(), 0, "writing the receipt again after giving cannot repair an earlier flag burn")
handler = { { "check_flag", "RECEIVED" }, { "jump_if_true", "flag" },
  { "give_item", "POTION" }, { "jump", "end" }, { "label", "flag" }, { "set_flag", "RECEIVED" } }
T.eq(#rows(), 0, "unrelated branch's flag cannot prove receipt")
handler = reward("RECEIVED")
table.insert(handler, 4, { "clear_flag", "RECEIVED" })
T.eq(#rows(), 0, "repeatable local reset is excluded from permanent completion")
handler = reward("RECEIVED")
handler[3][2] = "MISSING"
T.eq(#rows(), 0, "missing branch cannot establish proof")
handler = reward("RECEIVED")
table.insert(handler, 4, { "mod:opaque" })
T.eq(#rows(), 0, "mod-defined control flow is never executed or guessed")
handler = reward("RECEIVED")
table.insert(handler, 4, { "opaque_control" })
T.eq(#rows(), 0, "unknown commands without a namespace are also excluded")
handler = reward("RECEIVED")
table.insert(handler, 4, { "jump", 4 })
T.eq(#rows(), 0, "cyclic control flow terminates without inventing a reachable gift")
handler = { { "check_flag" }, { "give_item", "POTION" } }
T.eq(#rows(), 0, "malformed receipt commands cannot crash the catalogue")
handler = reward("RECEIVED")
table.insert(handler, 4, { "check_dex_owned" })
table.insert(handler, 5, { "jump_if_false", "end" })
T.eq(#rows(), 0, "malformed availability gates cannot crash live evaluation")
handler = reward("RECEIVED")
handler[4][3] = 0
T.eq(#rows(), 0, "zero-quantity command is not a gift")
handler = function() error("opaque NPC must never execute") end
T.eq(#rows(), 0, "unknown Lua handlers are not executed")
handler = false
T.eq(#rows(), 0, "suppressed talk handler adds no gifts")
handler = reward("RECEIVED")
table.insert(handler, 4, { "check_flag", "READY" })
table.insert(handler, 5, { "jump_if_false", "end" })
T.eq(rows()[1].status, "LATER", "live known story gate delays the reward")
save.flags.READY = true
T.eq(rows()[1].available, true, "story progress unlocks the same cached reward")
scripts.talkScript = talkScript

local importedItems = { HM_FLASH = {}, ITEMFINDER = {}, EXP_ALL = {}, TM_MIMIC = {},
  TM_PSYCHIC_M = {}, TM_BIDE = {}, BICYCLE = {}, OLD_AMBER = {},
  TM_ICE_BEAM = {}, TM_ROCK_SLIDE = {}, TM_TRI_ATTACK = {}, BIKE_VOUCHER = {} }
local function nativeRow(id, text)
  return policy:rows({ items = importedItems }, save, id,
    { objects = { { index = 1, text = text, x = 2, y = 3 } } })
end
local function owned(count)
  save.pokedex.owned = {}
  for i = 1, count do save.pokedex.owned[i] = true end
end
owned(9)
T.eq(nativeRow("ROUTE_2_GATE", "TEXT_ROUTE2GATE_OAKS_AIDE")[1].status, "LATER", "Flash requires ten caught species")
owned(10)
T.eq(nativeRow("ROUTE_2_GATE", "TEXT_ROUTE2GATE_OAKS_AIDE")[1].available, true, "Flash threshold uses owned, not seen")
save.flags.EVENT_GOT_HM_FLASH = true
T.eq(nativeRow("ROUTE_2_GATE", "TEXT_ROUTE2GATE_OAKS_AIDE")[1].done, true, "legacy Flash receipt alias is respected")
T.eq(nativeRow("COPYCATS_HOUSE_2F", "TEXT_COPYCATSHOUSE2F_COPYCAT")[1].status, "LATER", "Copycat needs a doll in the bag")
save.inventory.POKE_DOLL = 1
T.eq(nativeRow("COPYCATS_HOUSE_2F", "TEXT_COPYCATSHOUSE2F_COPYCAT")[1].available, true, "doll exchange becomes available without mutating inventory")
T.eq(save.inventory.POKE_DOLL, 1, "reward reader never consumes an exchange item")
T.eq(#nativeRow("CELADON_MART_ROOF", "TEXT_CELADONMARTROOF_LITTLE_GIRL"), 3, "one NPC can supply three distinct TM receipts")
save.inventory.SODA_POP = 1
local roof = nativeRow("CELADON_MART_ROOF", "TEXT_CELADONMARTROOF_LITTLE_GIRL")
T.eq(roof[1].available, false, "each drink unlocks only its own TM")
T.eq(roof[2].available, true, "Soda Pop unlocks Rock Slide")
T.eq(nativeRow("PEWTER_GYM", "TEXT_PEWTERGYM_BROCK")[1].done, false, "gym reward uses TM receipt rather than badge")
save.flags.EVENT_BEAT_BROCK = true
T.eq(nativeRow("PEWTER_GYM", "TEXT_PEWTERGYM_BROCK")[1].available, true, "beaten leader can retry a full-bag TM")
save.flags.EVENT_GOT_TM34 = true
T.eq(nativeRow("PEWTER_GYM", "TEXT_PEWTERGYM_BROCK")[1].done, true, "received gym TM remains done after use")
T.eq(nativeRow("MUSEUM_1F", "TEXT_MUSEUM1F_SCIENTIST2")[1].itemId, "OLD_AMBER", "native scientist gift is included")
T.eq(nativeRow("POKEMON_FAN_CLUB", "TEXT_POKEMONFANCLUB_CHAIRMAN")[1].itemId,
  "BIKE_VOUCHER", "the native chairman retains its gift through Yellow's printer wrapper")
T.eq(nativeRow("POKEMON_FAN_CLUB", "TEXT_POKEMONFANCLUB_CHAIRMAN")[1].event,
  "EVENT_RECEIVED_BIKE_VOUCHER", "the chairman uses the native receipt flag")
scripts.talkScript = function() return function() error("replacement must not execute") end end
T.eq(#nativeRow("MUSEUM_1F", "TEXT_MUSEUM1F_SCIENTIST2"), 0, "another mod's replacement does not inherit native gift metadata")
scripts.talkScript = talkScript

local run = T.sdk.loadMod(root, { generation = 1, data = T.fixtures.fresh() })
T.eq(run.mod and run.mod.state, "loaded", "Gen1 companion loads the gift reader")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local input
for _, entry in ipairs(run.loader.hooks.chains["input.step"]) do
  if entry.owner == "kanto_gear" then input = entry.callback end
end
local display = up(input, "displayRuntime")
local Area = up(up(display.achievementData, "areaData"), "Area")
T.eq(Area.gen1Gifts({ items = importedItems }, save, "PEWTER_GYM",
  { objects = { { index = 1, text = "TEXT_PEWTERGYM_BROCK" } } })[1].done, true,
  "area model shares the live Gen1 receipt policy")

-- A Dex-only album refresh must also reconsider Oak's item rewards, even
-- though this location has no Pokemon objectives of its own.
run.data.items = importedItems
run.data.maps = { ROUTE_2_GATE = { id = "ROUTE_2_GATE", width = 8, height = 6,
  objects = { { index = 1, text = "TEXT_ROUTE2GATE_OAKS_AIDE", x = 2, y = 3 } } } }
local world = { map = { id = "ROUTE_2_GATE" } }
local progressSave = { generation = 1, player = { name = "RED", map = "ROUTE_2_GATE" },
  flags = {}, party = {}, inventory = {}, boxes = {}, pokedex = { caught = {}, owned = {} } }
for i = 1, 9 do progressSave.pokedex.caught[i], progressSave.pokedex.owned[i] = true, true end
local game = { data = run.data, save = progressSave, world = world,
  stack = { top = function() return world end } }
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", info_level = "spoiler" }
run.loader.events:emit("game.ready", { game = game })
local function album()
  for _ = 1, 1000 do
    local result = display.achievementData(false, true)
    if result then return result end
  end
  error("Gen1 gift album did not complete")
end
local before = album().byId.ROUTE_2_GATE.sections[2].rows[1]
T.eq(before.available, false, "nine caught species keep the aide's gift locked")
progressSave.pokedex.caught[10], progressSave.pokedex.owned[10] = true, true
run.loader.events:emit("pokemon.caught", { species = 10 })
T.eq(album().byId.ROUTE_2_GATE.sections[2].rows[1].available, true,
  "Dex-only refresh unlocks Flash at ten species without a story flag change")

local native = os.getenv("KANTO_GEAR_NATIVE_GEN1")
if native then
  local imported = { maps = dofile(native .. "/maps.lua"), items = dofile(native .. "/items.lua") }
  local counts, events = 0, {}
  for id, nativeMap in pairs(imported.maps) do
    for _, row in ipairs(policy:rows(imported, save, id, nativeMap)) do
      counts = counts + 1
      events[id .. ":" .. row.itemId] = row.event
    end
  end
  T.eq(events["PEWTER_GYM:TM_BIDE"], "EVENT_GOT_TM34", "native Brock object exposes the TM receipt")
  T.eq(events["VERMILION_OLD_ROD_HOUSE:OLD_ROD"], "EVENT_GOT_OLD_ROD", "native Old Rod command table is readable")
  T.eq(events["ROUTE_1:POTION"], "EVENT_GOT_POTION_SAMPLE", "native Route1 opaque gift is covered")
  T.eq(events["BLUES_HOUSE:TOWN_MAP"], "EVENT_GOT_TOWN_MAP", "native Daisy gift is tracked")
  T.eq(events["CELADON_GAME_CORNER:TM_DRAGON_RAGE"], nil, "paid repeatable prizes do not block stamps")
  T.eq(counts, 41, "complete native map catalogue has 41 deduplicated item gifts")
  print("GEN1_NATIVE_GIFTS", counts)
end
T.finish("Kanto Gear Gen1 NPC gifts")
