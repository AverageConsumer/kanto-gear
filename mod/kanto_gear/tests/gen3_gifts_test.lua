-- Native, edition-specific Pokemon gift receipts, without running a game scene.
local root, cacheRoot = assert(os.getenv("KANTO_GEAR_MOD_PATH")), assert(os.getenv("POKEPORT_GBA_CACHE"))
local edition = assert(os.getenv("POKEPORT_VERSION"))
require("src.core.GameVersion").set(edition)
require("src.import.gba.versions").select(edition)
local Dataset = require("src.core.game3.dataset")
Dataset.cacheRootOverride = cacheRoot
Dataset.mountExtractRoots()
local P = require("src.core.game3.pokemon")
P.install(Dataset.cache())
require("src.core.game3.items_data").install(Dataset.cache())
local Schema = require("src.core.game3.save_schema_firered")
local session = Schema.newGame({ version = edition, name = "GIFTS", rngSeed = 12345 })
local raw = { generation = 3, phase = "field", session = session,
  save = Schema.toSaveTable(session), data = { maps = Dataset.buildMaps(),
    gen3Encounters = dofile(cacheRoot .. "/encounters.lua") } }
require("src.core.game3.runtime").session = session
require("src.mods.Gen3Compat").bind(function() return raw end)
local adapter = assert(loadfile(root .. "/tests/support/module.lua"))()(root, "adapters/gen3/init").new(raw)
local Space, Flags = adapter.Space, adapter.Flags
Space.bundle = { scripts = dofile(cacheRoot .. "/scripts/scripts.lua"),
  events = dofile(cacheRoot .. "/scripts/events.lua"), text = dofile(cacheRoot .. "/scripts/text.lua") }
Space.active = false
local Model = assert(loadfile(root .. "/tests/support/module.lua"))()(root, "adapters/gen3/progress")
local model = Model.new(adapter)
local Progress = dofile(root .. "/features/achievements.lua")
local Json = require("src.import.canonical_json")
local checks = 0
local function check(ok, why) assert(ok, why); checks = checks + 1 end
local function flag(id, v) Flags.setFlag(session, nil, id, v == true) end
local function same(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~="table" then return a==b end
  for key,value in pairs(a) do if not same(value,b[key]) then return false end end
  for key in pairs(b) do if a[key]==nil then return false end end
  return true
end
local function reward(map, receipt)
  for _, r in ipairs(model:rows({ map })[4]) do if r.event == receipt then return r end end
  error("missing reward " .. map .. ":" .. receipt)
end
local expected = edition == "emerald" and {
  { "EM_LAVARIDGE_TOWN", 266, 360, true },
  { "EM_MOSSDEEP_CITY_STEVENS_HOUSE", 298, 398 },
  { "EM_ROUTE119_WEATHER_INSTITUTE_2F", 151, 385 },
} or {
  { "FR_CELADON_CITY_CONDOMINIUMS_ROOF_ROOM", 611, 133 },
  { "FR_SILPH_CO_7F", 582, 131 },
  { "FR_ROUTE_4_POKEMON_CENTER_1F", 585, 129 },
  { "FR_FIVE_ISLAND_WATER_LABYRINTH", 730, 175, true },
  { "FR_SAFFRON_CITY_DOJO", 632, 106 },
}
local before = Json.encode(Schema.toSaveTable(session))
local all = 0
for id in pairs(raw.data.maps) do
  for _, r in ipairs(model:catalog(id)[4]) do if r.gift and not r.trade then all = all + 1 end end
end
check(Json.encode(Schema.toSaveTable(session)) == before, "catalogue cannot give Pokemon or advance RNG")
check(all == (edition == "emerald" and 8 or 17), "all proven gifts and current fossil offers: " .. all)
for _, e in ipairs(expected) do
  local map, receipt, species, egg = unpack(e)
  flag(receipt, false)
  local r = reward(map, receipt)
  check(r.species == species and (r.isEgg == true) == (egg == true), "native species and egg identity")
  if r.hideEvent and r.hideEvent >= 0x20 then flag(r.hideEvent, false) end
  session.party = { { species = 1, level = 5, friendship = 255 } }
  session.money = 500
  adapter:refresh()
  adapter.save.pokedex.caught[species] = true
  r = reward(map, receipt)
  check(not r.done, "caught elsewhere cannot complete NPC receipt")
  check(r.available, "actual native gift is ready with all requirements: " .. map)
  check(not egg or r.label == "EGG" and not r.level, "egg hides its contents and level")
  if receipt == 585 then
    session.money = 499
    check(not reward(map, receipt).available, "500 money purchase cannot be offered with 499")
    session.money = 500
    check(reward(map, receipt).cost == 500, "price comes from native money guard")
    session.gender = 1
    check(reward(map, receipt).available, "female player follows the other native dialogue branch")
  elseif receipt == 730 then
    session.party[1].friendship = 254
    check(not reward(map, receipt).available, "egg requires full friendship, not almost full")
    flag(731, true)
    check(reward(map, receipt).available, "native retry remembers the accepted friendship check")
    flag(731, false)
    session.party[1].friendship = 255
  end
  for i = 2, 6 do session.party[i] = { species = 1, level = 5 } end
  r = reward(map, receipt)
  check(r.available == not egg, "only normal gifts can go to the PC with a full party")
  check((r.noRoom == true) == (egg == true), "egg explains full party")
  for _, box in ipairs(session.storage.boxes) do for slot = 1, 30 do box.mons[slot] = { species = 1 } end end
  check(not reward(map, receipt).available, "full party plus full PC cannot accept any gift")
  session.storage.boxes[14].mons[30] = nil
  check(reward(map, receipt).available == not egg, "last slot of last PC box is usable for normal gifts")
  for _, box in ipairs(session.storage.boxes) do box.mons = {} end
  flag(receipt, true)
  session.party = {}
  r = reward(map, receipt)
  check(r.done and not r.available, "receipt persists after releasing or hatching Pokemon")
  local goals = model:pokemon({ map })
  local goal
  for _, g in ipairs(goals) do if g.event == receipt then check(not goal, "one goal for alternative rewards"); goal = g end end
  check(goal and goal.done, "Stamps and Explorer share durable receipt")
  flag(receipt, false)
  check(not reward(map, receipt).done, "older save resets receipt without inheriting caught status")
  before = Json.encode(Schema.toSaveTable(session))
  model:rows({ map }); model:pokemon({ map })
  check(Json.encode(Schema.toSaveTable(session)) == before, "live reads do not generate, give, charge or change flags")
end
if edition ~= "emerald" then
  local dojo = model:pokemon({ "FR_SAFFRON_CITY_DOJO" })
  check(#dojo == 1 and dojo[1].label:find("/", 1, true), "both dojo choices form one receipt goal")
end
local johto, fossils, offers = {}, {}, {}
if edition == "emerald" then
  local map = "EM_LITTLEROOT_TOWN_PROFESSOR_BIRCHS_LAB"
  local var = model.constants:var("VAR_DEX_UPGRADE_JOHTO_STARTER_STATE")
  local function state(value) Flags.setVar(session, nil, var, value) end
  local function gifts() return model:rows({ map })[4] end
  local species = { [152] = true, [155] = true, [158] = true }
  state(5)
  session.party = { { species = 1, level = 5 } }
  for _, row in ipairs(gifts()) do
    check(species[row.species] and row.receiptVar == var and row.receiptValue == 6,
      "each Johto choice uses the native shared permanent receipt")
    check(row.level == 5 and row.toPC, "Johto starters have native level and PC delivery")
    species[row.species] = nil
    flag(row.hideEvent, true)
    johto[#johto + 1] = row
  end
  check(#johto == 3 and not next(species), "all three Johto choices are catalogued once")
  for _, row in ipairs(gifts()) do check(not row.available, "hidden starter balls are unavailable") end
  for _, row in ipairs(johto) do flag(row.hideEvent, false); adapter.save.pokedex.caught[row.species] = true end
  for _, row in ipairs(gifts()) do check(row.available and not row.done, "caught elsewhere is not a starter receipt") end
  local goals = model:pokemon({ map })
  check(#goals == 1 and not goals[1].done, "three alternative starters form one Stamps goal")
  check(model:completionKey() == 0, "unfinished starter state has the old cache key")
  state(6)
  session.party = {}
  for _, row in ipairs(gifts()) do check(row.done and not row.available, "receipt persists after releasing starter") end
  check(model:pokemon({ map })[1].done and model:completionKey() == 1, "variable-only receipt refreshes Stamps")
  local restored = Schema.fromSaveTable(Schema.toSaveTable(session))
  check(Flags.getVar(restored, nil, var) == 6, "receipt survives a native save roundtrip")
  state(7)
  check(model:pokemon({ map })[1].done, "later native state preserves receipt")
  state(5)
  check(not model:pokemon({ map })[1].done and model:completionKey() == 0, "loading older state restores unfinished goal")
  before = Json.encode(Schema.toSaveTable(session))
  gifts(); model:pokemon({ map })
  check(Json.encode(Schema.toSaveTable(session)) == before, "Johto queries cannot alter native state or RNG")
end
if edition ~= "emerald" then
  local map = "FR_CINNABAR_ISLAND_POKEMON_LAB_EXPERIMENT_ROOM"
  local function state(stage, kind)
    Flags.setVar(session, nil, 0x406A, stage)
    Flags.setVar(session, nil, 0x4069, kind)
  end
  local function goals()
    local out = {}
    for _, row in ipairs(model:pokemon({ map })) do if not row.trade then out[#out + 1] = row end end
    return out
  end
  local function stamp()
    return Progress.build({ { id = map, name = map, maps = { map } } }, function(ids)
      local r = model:rows(ids)
      return { sections = { { rows = r[1] }, { rows = r[2] }, { rows = r[3] } }, pokemon = model:pokemon(ids) }
    end, { save = adapter.save, gen3 = true, mapId = map }).areas[1]
  end
  session.party = { { species = 1, level = 5 } }
  for _, entry in ipairs({ { 749, 138 }, { 748, 140 }, { 750, 142 } }) do
    local row = reward(map, entry[1])
    check(row.species == entry[2] and row.level == 5 and row.toPC, "fossil has native species, level and PC contract")
    fossils[#fossils + 1] = row
    adapter.save.pokedex.caught[row.species] = true
    check(not row.done, "a fossil caught elsewhere cannot prove laboratory receipt")
  end
  check(#goals() == 2, "before choice one Mt Moon fossil and Amber are required, separately from the Seel trade")
  check(stamp().sections[4].total == 3 and stamp().sections[4].done == 0,
    "Stamps counts two fossil goals and the separate Seel trade, without caught-dex shortcuts")
  for stage = 0, 2 do
    for kind = 1, 3 do
      state(stage, kind)
      local ready = 0
      for _, row in ipairs(model:rows({ map })[4]) do
        if row.available then
          ready = ready + 1
          check(row.species == ({ 138, 140, 142 })[kind], "only the fossil currently being revived is ready")
        end
      end
      check(ready == (stage == 2 and 1 or 0), "idle and unfinished revival are not immediate offers")
    end
  end
  for _, choice in ipairs({ { 627, 626, 749, 138 }, { 626, 627, 748, 140 } }) do
    flag(choice[1], true); flag(choice[2], false)
    check(#goals() == 2, "selected fossil and Amber remain two goals")
    local selected = reward(map, choice[3])
    check(not selected.excluded, "own fossil choice stays required")
    for _, row in ipairs(model:rows({ map })[4]) do
      if row.choiceEvent == choice[2] then check(row.excluded and not row.available, "unchosen fossil is excluded") end
    end
    flag(choice[3], true); flag(750, true)
    session.party = {}
    for _, goal in ipairs(goals()) do check(goal.done, "receipts survive release and complete native fossil goals") end
    check(stamp().tier == "silver", "completed fossils cannot waive the independent Seel trade")
    flag(630, true)
    check(stamp().tier == "gold", "received fossils and Seel trade complete the actual laboratory stamp")
    flag(630, false)
    local restored = Schema.fromSaveTable(Schema.toSaveTable(session))
    check(Flags.getFlag(restored, nil, choice[3]), "revival receipt survives save roundtrip")
    flag(choice[3], false); flag(750, false)
    for _, goal in ipairs(goals()) do check(not goal.done, "older save restores unreceived fossils despite caught dex") end
    flag(choice[1], false)
  end
  flag(626, true); flag(627, true)
  check(#goals() == 3, "a modified save with both fossils retains both real receipt goals")
  for _, row in ipairs(model:rows({ map })[4]) do check(not row.excluded, "own choice flags prevent false exclusion when both exist") end
  flag(626, false); flag(627, false)
  state(0, 0)
  before = Json.encode(Schema.toSaveTable(session))
  model:rows({ map }); model:pokemon({ map })
  check(Json.encode(Schema.toSaveTable(session)) == before, "fossil queries cannot hand in items or change revival state")
else
  local map = "EM_RUSTBORO_CITY_DEVON_CORP_2F"
  check(#model:pokemon({ map }) == 2, "Emerald keeps both fossil species as separate catch goals")
  for _, row in ipairs(model:rows({ map })[4]) do
    check(row.catchGoal and row.deliveryFlag == 267 and not row.event and not row.receiptVar,
      "shared fossil flag proves delivery contract, never a unique receipt")
    check(row.level == 20 and row.toPC, "Emerald fossils retain native level and PC delivery")
    fossils[#fossils + 1] = row
  end
  check(#fossils == 2, "both native fossil offers are catalogued")
  session.party = { { species = 1, level = 5 } }
  for stage = 0, 2 do
    for kind = 1, 2 do
      Flags.setVar(session, nil, 0x40C4, stage)
      Flags.setVar(session, nil, 0x40C5, kind)
      local ready = 0
      for _, row in ipairs(model:rows({ map })[4]) do
        if row.available then
          ready = ready + 1
          check(row.species == ({ 388, 390 })[kind], "only the currently revived Emerald species is ready")
        end
      end
      check(ready == (stage == 2 and 1 or 0), "idle or working Emerald fossil is not ready")
    end
  end
  flag(267, true)
  for _, goal in ipairs(model:pokemon({ map })) do check(not goal.done, "one shared receipt cannot complete both Emerald species") end
  adapter.save.pokedex.caught[388] = true
  for _, goal in ipairs(model:pokemon({ map })) do check(goal.done == (goal.species == 388), "Emerald fossils retain separate honest caught goals") end
  adapter.save.pokedex.caught[388] = nil
  flag(267, false)
end
if edition ~= "emerald" then
  local map = "FR_CELADON_CITY_GAME_CORNER_PRIZE_ROOM"
  local oracle = edition == "firered" and { {63,180,9}, {35,500,8}, {147,2800,18}, {123,5500,25}, {137,9999,26} }
    or { {63,120,7}, {35,750,12}, {127,2500,18}, {147,4600,24}, {137,6500,18} }
  session.party = { { species = 1, level = 5 } }
  flag(579, true)
  for _, row in ipairs(model:rows({ map })[4]) do
    local e = oracle[row.choice + 1]
    check(row.catchGoal and not row.event and row.species == e[1] and row.coinCost == e[2] and row.level == e[3],
      "edition-specific prize species, level and price come from the actual choice branch")
    session.coins = row.coinCost - 1
    for _, live in ipairs(model:rows({ map })[4]) do if live.id == row.id then check(not live.available, "one coin short cannot unlock a prize") end end
    session.coins = row.coinCost
    for _, live in ipairs(model:rows({ map })[4]) do if live.id == row.id then check(live.available, "exact coin price unlocks the prize") end end
    offers[#offers + 1] = row
  end
  check(#offers == 5 and #model:pokemon({ map }) == 5, "repeatable prize counter has five separate caught goals")
  flag(579, false)
  for _, row in ipairs(model:rows({ map })[4]) do check(not row.available, "coins without a Coin Case cannot unlock the counter") end
  session.coins = 9999
  for _, stage in ipairs({ 0, 2, 3 }) do
    Flags.setVar(session, nil, 0x4055, stage)
    local count = 0
    for _, row in ipairs(model:rows({ "FR_OAKS_LAB" })[4]) do
      check(row.catchGoal and row.initialStarter and not row.event and row.level == 5, "initial starter is honestly a caught goal")
      flag(row.hideEvent, false)
      if row.available then count = count + 1 end
      if stage == 2 then offers[#offers + 1] = row end
    end
    check(count == (stage == 2 and 3 or 0), "starter offer follows native laboratory story state")
  end
  check(#offers == 8, "five prizes and three starter alternatives are classified")
  flag(2088, false)
  check(#model:pokemon({ "FR_OAKS_LAB" }) == 1, "initial starters remain one alternative goal")
else
  local Field = require("src.core.game3.scripting.natives_field_rse")
  local Choose = require("src.ui.game3.rse.starter_choose")
  local manifest = Choose.manifest
  Choose.manifest = function() return dofile(cacheRoot .. "/starter_choose/manifest.lua") end
  for selection = 0, 2 do
    session.party = {}
    for _, nat in ipairs({252,255,258}) do session.dex.caught[P.speciesFromNational(nat)] = nil end
    local species, code = Field.giveStarter({}, selection, session)
    adapter:refresh()
    check(code == 0 and species == P.speciesFromNational(({252,255,258})[selection+1]), "native Emerald starter selection gives the correct internal species")
    local function starterGoal()
      local goal, count = nil, 0
      for _, row in ipairs(model:pokemon({ "EM_ROUTE101" })) do
        if row.species == P.speciesFromNational(252) or row.species == P.speciesFromNational(255)
            or row.species == P.speciesFromNational(258) then goal, count = row, count + 1 end
      end
      check(count == 1, "all Emerald starter alternatives form one goal alongside independent Route 101 wild encounters")
      return goal
    end
    check(starterGoal().done, "each native Emerald starter completes one alternative catch goal")
    session.party = {}; adapter:refresh()
    check(starterGoal().done, "starter caught goal survives release without inventing a receipt")
  end
  Choose.manifest = manifest
end
-- A failed delivery must never be mistaken for a valid receipt.
local function giftGraph(bad, mutate)
  local scripts = { main = { { op = "checkflag", flag = 700 },
    { op = "goto_if", cond = 1, target = "done" }, { op = "givemon", 1, 5 },
    { op = "compare_var_to_value", var = 0x800D, value = 2 },
    { op = "goto_if", cond = 1, target = "failed" }, { op = "setflag", flag = 700 }, { op = "end" } },
    failed = bad and { { op = "setflag", flag = 700 }, { op = "end" } } or { { op = "end" } },
    done = { { op = "end" } } }
  if mutate then mutate(scripts) end
  local rows, vars = Model.scan(scripts, "main")
  return model:pokemonGifts(scripts, "main", rows, vars, { localId = 1 })
end
check(#giftGraph(false) == 1, "success-only receipt is proven")
check(#giftGraph(true) == 0, "receipt also written on failure is rejected")
check(#giftGraph(false, function(s) s.main[3].opaque = true; s.main[3].op = "unknown" end) == 0,
  "opaque commands cannot establish receipt proof")
check(#giftGraph(false, function(s) table.insert(s.main, 3, { op = "multichoice", 0, 0, 1 }) end) == 0,
  "unsupported choice operations cannot reuse stale VAR_RESULT")
check(#giftGraph(false, function(s) table.insert(s.main, 3, { op = "clearflag", flag = 700 }) end) == 0,
  "cleared receipt is not durable")
check(#giftGraph(false, function(s)
  s.helper = { s.main[3], { op = "end" } }; s.main[3] = { op = "call", target = "helper" }
end) == 0, "ending helper never returns to the caller's receipt")
check(#giftGraph(false, function(s) s.main[6].flag = 701 end) == 0,
  "unrelated story flag is not a gift receipt")
check(#giftGraph(false, function(s)
  s.main[4] = { op = "checkflag", flag = 701 }
  s.main[5] = { op = "goto_if", cond = 1, target = "loop" }
  s.loop = { { op = "goto", target = "loop" } }
end) == 0, "a gift path looping before its receipt cannot prove completion")
local function separateDelivery(s)
  s.delivery = { s.main[3], s.main[4], s.main[5], s.main[6], s.main[7] }
  s.main[3] = { op = "multichoice", 0, 0, 1 }
  s.main[4] = { op = "goto", target = "delivery" }
  for i = #s.main, 5, -1 do s.main[i] = nil end
end
check(#giftGraph(false, separateDelivery) == 1, "a unique receipt is provable inside its own delivery block")
check(#giftGraph(false, function(s)
  separateDelivery(s); table.insert(s.main, 3, { op = "setflag", flag = 700 })
end) == 0, "a second writer outside delivery invalidates local receipt proof")
check(#giftGraph(false, function(s)
  separateDelivery(s)
  s.writer = { s.delivery[4], { op = "return" } }
  s.delivery[4] = { op = "call", target = "writer" }
end) == 0, "a shared external writer cannot be proven from a delivery block")
check(#giftGraph(false, function(s)
  separateDelivery(s); s.main[3] = { op = "goto", target = "done" }
end) == 0, "known unreachable reward cannot become a mandatory receipt goal")
check(#giftGraph(false, function(s)
  separateDelivery(s); s.loop = { { op = "goto", target = "loop" } }
  s.main[3] = { op = "goto", target = "loop" }
end) == 0, "unreachable reward behind an unconditional loop cannot become a receipt goal")
if edition == "emerald" then
  local var = model.constants:var("VAR_DEX_UPGRADE_JOHTO_STARTER_STATE")
  local function variableReceipt(s)
    s.main[1] = { op = "compare_var_to_value", var = var, value = 6 }
    s.main[2].cond = 4
    s.main[6] = { op = "setvar", var = var, value = 6 }
  end
  check(#giftGraph(false, variableReceipt) == 1, "successful variable receipt is proven")
  check(#giftGraph(true, function(s)
    variableReceipt(s); s.failed[1] = { op = "setvar", var = var, value = 6 }
  end) == 0, "variable receipt written on failed delivery is rejected")
  check(#giftGraph(false, function(s)
    variableReceipt(s); table.insert(s.main, 7, { op = "setvar", var = var, value = 5 })
  end) == 0, "cleared variable receipt is rejected")
  check(#giftGraph(false, function(s)
    variableReceipt(s); s.main[1].var = var + 1; s.main[6].var = var + 1
  end) == 0, "unrelated progress variable cannot become a permanent gift receipt")
end

-- Shared battle/retry gift commands deduplicate; independent wild encounters do not.
do
  local original = Space.bundle
  local scripts = { gift = { { op = "checkflag", flag = 700 },
    { op = "goto_if", cond = 1, target = "done" }, { op = "givemon", 1, 5 },
    { op = "compare_var_to_value", var = 0x800D, value = 2 },
    { op = "goto_if", cond = 1, target = "done" }, { op = "setflag", flag = 700 }, { op = "end" } },
    wild = { { op = "setwildbattle", 1, 5 }, { op = "end" } },
    battle = { { op = "trainerbattle", type = 0, trainer = 1, eventScript = "gift" }, { op = "end" } },
    done = { { op = "end" } } }
  for _, reverse in ipairs({ false, true }) do
    local objects = { { localId = 1, flag = 0, scriptKey = "gift" },
      { localId = 2, flag = 0, scriptKey = "battle" } }
    Space.bundle = { scripts = scripts, events = { TEST = { objects = objects } } }
    check(#model:catalog("TEST")[4] == 1, "battle callback and retry share one gift receipt")
    table.insert(objects, reverse and 1 or #objects + 1, { localId = 3, flag = 0, scriptKey = "wild" })
    Space.bundle = { scripts = scripts, events = { TEST = { objects = objects } } }
    local rows, gifts, wild = model:catalog("TEST")[4], 0, 0
    for _, r in ipairs(rows) do if r.gift then gifts = gifts + 1 else wild = wild + 1 end end
    check(gifts == 1 and wild == 1, "wild encounter survives matching gift regardless of NPC order")
  end
  Space.bundle = original
end

-- Run the real imported scripts and delivery/flag operations, stubbing only presentation.
do
  local Vm = require("src.core.game3.scripting.vm")
  local Adapters = require("src.core.game3.scripting.adapters")
  local Objects = require("src.core.game3.objects")
  local Party = require("src.core.game3.party")
  local sources = {}
  for _, e in ipairs(expected) do sources[#sources + 1] = reward(e[1], e[2]) end
  for _, source in ipairs(johto) do sources[#sources + 1] = source end
  for _, source in ipairs(fossils) do sources[#sources + 1] = source end
  for _, source in ipairs(offers) do sources[#sources + 1] = source end
  for _, source in ipairs(sources) do
    local map, receipt, egg = source.mapId, source.event, source.isEgg
    local event, object = Space.bundle.events[map]
    for _, o in ipairs(event.objects) do if o.localId == source.index then object = o end end
    check(object ~= nil, "gift is attached to its actual native NPC")
    for scenario = 1, (source.deliveryFlag and 6 or 3) do
      local capacity = (scenario - 1) % 3 + 1
      if map == "FR_CINNABAR_ISLAND_POKEMON_LAB_EXPERIMENT_ROOM" then
        for _, id in ipairs({ 748, 749, 750, 626, 627 }) do flag(id, false) end
        Flags.setVar(session, nil, 0x406A, 2)
        Flags.setVar(session, nil, 0x4069, ({ [138] = 1, [140] = 2, [142] = 3 })[source.species])
        if source.choiceEvent then flag(source.choiceEvent, true) end
      end
      if source.catchGoal then session.dex.caught[source.species], session.dex.owned[source.species] = nil, nil end
      if source.coinCost then session.coins = source.coinCost; flag(579, true) end
      if source.initialStarter then Flags.setVar(session, nil, 0x4055, 2); flag(2088, false); flag(657, false) end
      if source.deliveryFlag then
        Flags.setVar(session, nil, 0x40C4, 2)
        Flags.setVar(session, nil, 0x40C5, source.species == 388 and 1 or 2)
        flag(source.deliveryFlag, scenario > 3)
        session.dex.caught[source.species], session.dex.owned[source.species] = nil, nil
      end
      if source.receiptVar then Flags.setVar(session, nil, source.receiptVar, source.receiptValue - 1)
      elseif receipt then flag(receipt, false) end
      if source.hideEvent and source.hideEvent >= 0x20 then flag(source.hideEvent, false) end
      if receipt == 730 then flag(731, false) end
      session.party = { { species = 1, level = 5, friendship = 255 } }
      if capacity > 1 then for i = 2, 6 do session.party[i] = { species = 1, level = 5 } end end
      for _, box in ipairs(session.storage.boxes) do
        box.mons = {}
        if capacity == 3 then for slot = 1, 30 do box.mons[slot] = { species = 1 } end end
      end
      session.money = 500
      adapter:refresh()
      local expectedDone = capacity == 1 or capacity == 2 and not egg
      for _, row in ipairs(model:rows({ map })[4]) do
        if row.id == source.id then check(row.available == expectedDone, "availability predicts native capacity result") end
      end
      Space.store, Space.active = session, true
      Objects.loadMap(nil, map, event)
      local native = Adapters.host(nil, nil, nil)
      local deliveries, received = 0, nil
      local presentation = Adapters.stub({
        askYesNo = function(done) done(false) end, -- accept gift below, decline nickname afterwards
        waitFanfare = function(done) done() end, playSe = function() end,
        showMonPic = function() end, hideMonPic = function() end,
        applyMovement = function() return true end, pollMovement = function() return true end,
        removeObject = native.removeObject,
        giveMonToPlayer = function(sp, lv, item)
          check(lv == source.level, "native gift level agrees with the projected offer")
          received = sp; local code = Party.giveMonToPlayer(session, sp, lv)
          if code ~= 2 then deliveries = deliveries + 1 end
          return code
        end,
        giveEggToPlayer = function(sp)
          received = sp; local code = Party.giveEggToPlayer(session, sp)
          if code ~= 2 then deliveries = deliveries + 1 end
          return code
        end,
      })
      local asked = 0
      presentation.askYesNo = function(done)
        asked = asked + 1
        done(asked == 1 and (source.receiptVar ~= nil or source.coinCost ~= nil or source.initialStarter or receipt == 585 or receipt == 632 or receipt == 266 or receipt == 298))
      end
      local Prize = require("src.ui.game3.prize_corner")
      local show = Prize.show
      Prize.show = function(opts) opts.onChoose(source.choice or 0); return true end
      local vm = Vm.new({ store = session, scripts = Space.bundle.scripts, text = Space.bundle.text, adapters = presentation })
      vm:startTalk(object.scriptKey, object.localId, 1)
      for _ = 1, 500 do if not vm:isRunning() then break end; vm:tick() end
      Prize.show = show
      check(not vm:isRunning(), "native gift script finishes: " .. map .. " " .. Json.encode(vm.ctx.pc))
      check((deliveries == 1) == expectedDone, "native delivery agrees with capacity contract")
      adapter:refresh()
      local actualDone = source.catchGoal and adapter.save.pokedex.caught[source.species]
        or source.receiptVar and Flags.getVar(session, nil, source.receiptVar) >= source.receiptValue
        or receipt and Flags.getFlag(session, nil, receipt) or false
      check((actualDone == true) == expectedDone, "native receipt written only on successful delivery")
      local projected
      for _, row in ipairs(model:rows({ map })[4]) do if row.id == source.id then projected = row end end
      check(projected and projected.done == expectedDone, "model agrees with actual native VM outcome")
      if expectedDone then check(received == source.species, "native VM gives the catalogued species") end
      if source.coinCost then check(session.coins == (expectedDone and 0 or source.coinCost), "only successful native prize delivery charges coins") end
      if source.deliveryFlag then
        check(Flags.getFlag(session, nil, source.deliveryFlag) == (scenario > 3 or expectedDone),
          "second fossil delivery does not require a fresh shared flag; failure preserves existing flag")
        check(Flags.getVar(session, nil, 0x40C4) == (expectedDone and 0 or 2), "only successful revival resets native stage")
        check(projected.status == (expectedDone and "CAUGHT" or "LATER"), "fossil status never claims a unique receipt")
        local restored = Schema.fromSaveTable(Schema.toSaveTable(session))
        check((restored.dex.caught[source.species] == true) == expectedDone, "fossil caught goal survives native save roundtrip")
      end
    end
  end
  Space.active = false
  for _, box in ipairs(session.storage.boxes) do box.mons = {} end
  for _, e in ipairs(expected) do flag(e[2], false) end
  for _, source in ipairs(fossils) do
    if source.event then flag(source.event, false)
    else session.dex.caught[source.species], session.dex.owned[source.species] = nil, nil end
  end
  if edition ~= "emerald" and #fossils > 0 then
    flag(626, false); flag(627, false)
    Flags.setVar(session, nil, 0x406A, 0)
  end
  if #johto > 0 then Flags.setVar(session, nil, johto[1].receiptVar, 5) end
end

local T = require("tests.modkit")
love.graphics.arc = love.graphics.arc or function() end
local run = T.sdk.loadMod(root, { generation = 3, data = raw.data })
check(run.mod and run.mod.state == "loaded", "native companion loads gift integration")
setmetatable(raw, { __index = require("src.core.Game3") })
run.loader.game = raw
run.loader.events:emit("game.ready", { game = raw })
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local display
for _, hook in ipairs(run.loader.hooks.chains["input.step"]) do
  if hook.owner == "kanto_gear" then display = up(hook.callback, "displayRuntime") end
end
run.loader.modOptions.kanto_gear = { info_level = "spoiler", theme_v3 = "hgss" }
local e = expected[1]
local offer = { map = e[1], source = reward(e[1], e[2]) }
session.map = offer.map
session.party = { { species = 1, level = 20, friendship = 255 } }; session.money = 500
display.gen3:refresh()
display.gen3Progress.adapter.Space.bundle = Space.bundle
local area = up(display.achievementData, "areaData")({ offer.map }, true)
local ready
for _, r in ipairs(area.pokemon) do if r.event == offer.source.event then ready = r.available end end
check(ready, "shared area forwards ready native gifts to Explorer")
display.knownMap = function() return true end
display.explorerMethods = function() return {} end
display.explorerWildRows = function() return {} end
local explorer = display.explorer
explorer.view, explorer.filters.wildScope = "wild", "HERE"
local overview = { mapId = offer.map, width = 16, height = 16, rows = {}, markers = {} }
for y = 1, 16 do overview.rows[y] = string.rep(".", 16) end
local function explorerModel()
  explorer.data, explorer.renderModel = nil, nil
  return display.explorerModel(overview)
end
local function offersOnMap(mapId)
  local rows, previous = {}, explorer.page
  explorer.page = 1
  local pages = explorerModel().pages
  for page = 1, pages do
    explorer.page = page
    for _, row in ipairs(explorerModel().rows) do
      if row.mapId == mapId then rows[#rows + 1] = row end
    end
  end
  explorer.page = previous
  return rows
end
local function find(rows, receipt) for _, r in ipairs(rows) do if r.event == receipt then return r end end end
local presented = assert(find(explorerModel().rows, offer.source.event))
check(presented.method == "NPC GIFT", "Explorer presents a ready native gift")
if presented.isEgg then
  check(presented.name == "EGG", "Explorer egg name does not disclose hatch species")
  local calls, originalIcon = 0, P.frontPic
  P.frontPic = function(species, ...) check(species == P.SPECIES_EGG, "renderer receives egg identity"); calls = calls + 1; return originalIcon(species, ...) end
  explorerModel().drawPokemon(presented, 0, 0, 32)
  P.frontPic = originalIcon
  check(calls == 1, "Gen3 egg uses native egg portrait without revealing hatch species")
end
for i = 2, 6 do session.party[i] = { species = 1, level = 5 } end
display.gen3:refresh()
check((find(explorerModel().rows, offer.source.event) ~= nil) == not offer.source.isEgg,
  "HERE NOW respects native full-party delivery contract")
explorer.filters.wildScope = "ROUTE"
check(find(explorerModel().rows, offer.source.event), "WHOLE ROUTE retains unavailable egg in Spoiler mode")
session.party = { { species = 1, level = 20, friendship = 255 } }; display.gen3:refresh()
if #johto > 0 then
  local original = offer
  offer = { map = johto[1].mapId, source = johto[1] }
  session.map, overview.mapId = offer.map, offer.map
  for _, row in ipairs(johto) do flag(row.hideEvent, false) end
  Flags.setVar(session, nil, johto[1].receiptVar, 5)
  display.gen3:refresh()
  explorer.filters.wildScope = "HERE"
  check(#explorerModel().rows == 3, "HERE NOW presents all three ready native Johto choices")
  display.achievementData(true)
  check(display.achievements.progressKeys == 0, "live Stamps caches unfinished Johto state")
  Flags.setVar(session, nil, johto[1].receiptVar, 6)
  check(#explorerModel().rows == 0, "choosing one removes all alternatives from HERE NOW")
  display.achievementData(true)
  check(display.achievements.progressKeys == 1, "native variable write invalidates Stamps without a flag event")
  Flags.setVar(session, nil, johto[1].receiptVar, 5)
  if os.getenv("KANTO_GEAR_PREVIEW_JOHTO") ~= "1" then offer = original; session.map = offer.map end
  display.gen3:refresh()
end
if edition ~= "emerald" and #fossils > 0 then
  local original = offer
  offer = { map = fossils[1].mapId, source = fossils[1] }
  session.map, overview.mapId = offer.map, offer.map
  explorer.filters.wildScope = "HERE"
  flag(627, true); flag(626, false)
  Flags.setVar(session, nil, 0x4069, 1)
  for stage = 0, 2 do
    Flags.setVar(session, nil, 0x406A, stage)
    display.gen3:refresh()
    local rows = explorerModel().rows
    check(#rows == (stage == 2 and 1 or 0), "HERE NOW shows only completed native fossil revival")
    if stage == 2 then check(rows[1].id == fossils[1].id and rows[1].method == "NPC GIFT", "Explorer points to the right laboratory reward") end
  end
  flag(fossils[1].event, true)
  check(#explorerModel().rows == 0, "recorded laboratory receipt leaves HERE NOW")
  flag(fossils[1].event, false)
  if os.getenv("KANTO_GEAR_PREVIEW_FOSSIL") ~= "1" then offer = original; session.map = offer.map end
  display.gen3:refresh()
end
if edition == "emerald" then
  local original = offer
  offer = { map = fossils[1].mapId, source = fossils[1] }
  session.map, overview.mapId = offer.map, offer.map
  explorer.filters.wildScope = "HERE"
  for _, source in ipairs(fossils) do session.dex.caught[source.species], session.dex.owned[source.species] = nil, nil end
  for _, shared in ipairs({ false, true }) do
    flag(267, shared)
    for kind = 1, 2 do
      Flags.setVar(session, nil, 0x40C5, kind)
      for stage = 0, 2 do
        Flags.setVar(session, nil, 0x40C4, stage)
        display.gen3:refresh()
        local rows = explorerModel().rows
        check(#rows == (stage == 2 and 1 or 0), "Emerald HERE NOW respects revival stage even after first shared receipt")
        if stage == 2 then check(rows[1].species == ({ 388, 390 })[kind] and rows[1].catchGoal,
          "Explorer presents the actual ready fossil as a caught goal") end
      end
    end
  end
  require("src.core.game3.dex").setCaught(session.dex, 390)
  display.gen3:refresh()
  check(#explorerModel().rows == 0, "caught fossil leaves immediate hunting offers")
  explorer.filters.wildScope = "ROUTE"
  local rows = offersOnMap(offer.map)
  check(#rows == 2, "WHOLE ROUTE retains both separate Emerald fossil goals")
  for _, row in ipairs(rows) do check(row.done == (row.species == 390), "catching one fossil does not complete the other") end
  session.dex.caught[390], session.dex.owned[390] = nil, nil
  if os.getenv("KANTO_GEAR_PREVIEW_FOSSIL") == "1" then
    for _, source in ipairs(fossils) do if source.species == 390 then offer.source = source end end
  else offer = original; session.map = offer.map end
  display.gen3:refresh()
end
if edition ~= "emerald" then
  local original = offer
  offer = { map = "FR_CELADON_CITY_GAME_CORNER_PRIZE_ROOM", source = offers[1] }
  for _, source in ipairs(offers) do if (source.coinCost or 0) > (offer.source.coinCost or 0) then offer.source = source end end
  session.map, overview.mapId = offer.map, offer.map
  for _, source in ipairs(offers) do session.dex.caught[source.species], session.dex.owned[source.species] = nil, nil end
  flag(579, true); session.coins = 9999
  explorer.filters.wildScope = "HERE"
  display.gen3:refresh()
  check(#explorerModel().rows == 4 and explorerModel().total == 5 and explorerModel().pages == 2, "HERE NOW presents all affordable uncaught native prizes")
  for _, row in ipairs(explorerModel().rows) do check(row.method == "NPC OFFER" and row.coinCost > 0, "prize presentation includes coin price") end
  session.coins = 0
  check(#explorerModel().rows == 0, "HERE NOW hides prizes without enough coins")
  explorer.filters.wildScope = "ROUTE"
  local prizes = offersOnMap(offer.map)
  check(#prizes == 5, "WHOLE ROUTE retains five unavailable prize catch goals within the whole city")
  for _, row in ipairs(prizes) do
    check(row.method == "NPC OFFER" and row.coinCost > 0 and not row.available,
      "whole-city prize rows retain their method, price and unavailable state")
  end
  session.coins = 9999
  explorer.filters.wildScope = "HERE"
  if os.getenv("KANTO_GEAR_PREVIEW_CASINO") ~= "1" then offer = original; session.map = offer.map end
  display.gen3:refresh()
end
-- Reusing the already-read rewards must preserve every completion field,
-- including starters, fossils, trade offers and alternative gift receipts.
for mapId in pairs(adapter.data.maps) do
  local rewards = model:rows({mapId})[4]
  check(same(model:pokemon({mapId},nil,rewards),model:pokemon({mapId})),
    "reused reward rows exactly match a fresh native read in "..mapId)
end
if _G.KANTO_GEAR_RENDER_CAPTURE then _G.KANTO_GEAR_RENDER_CAPTURE(run, display, raw, offer) end
print("GEN3_NATIVE_GIFTS", edition, all)
print(checks .. " checks passed")
