-- Run against both locally imported editions from the exact host checkout.
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local cacheRoot = assert(os.getenv("POKEPORT_GBA_CACHE"))
local edition = assert(os.getenv("POKEPORT_VERSION"))
require("src.core.GameVersion").set(edition)
require("src.import.gba.versions").select(edition)
local Dataset = require("src.core.game3.dataset")
Dataset.cacheRootOverride = cacheRoot
Dataset.mountExtractRoots()
require("src.core.game3.pokemon").install(Dataset.cache())
require("src.core.game3.items_data").install(Dataset.cache())
local Schema = require("src.core.game3.save_schema_firered")
local session = Schema.newGame({ version = edition, name = "PROGRESS", rngSeed = 12345 })
local raw = { generation = 3, phase = "field", session = session, data = {
  maps = Dataset.buildMaps(), gen3Encounters = dofile(cacheRoot .. "/encounters.lua") } }
raw.save = Schema.toSaveTable(session)
require("src.core.game3.runtime").session = session
require("src.mods.Gen3Compat").bind(function() return raw end)
local adapter = dofile(root .. "/gen3.lua").new(raw)
local Space, Flags = adapter.Space, adapter.Flags
Space.bundle = { scripts = dofile(cacheRoot .. "/scripts/scripts.lua"), events = dofile(cacheRoot .. "/scripts/events.lua"),
  text = dofile(cacheRoot .. "/scripts/text.lua") }
Space.active = false
local Model = dofile(root .. "/gen3_progress.lua")
local model = Model.new(adapter)
local Progress = dofile(root .. "/achievements.lua")
local Json = require("src.import.canonical_json")
local before = Json.encode(Schema.toSaveTable(session))
local checks = 0
local function check(ok, why) assert(ok, why); checks = checks + 1 end
local function rows(id, category) return model:rows({ id })[category] end
local function find(list, pred) for _, row in ipairs(list) do if pred(row) then return row end end end
local function flag(id, value) Flags.setFlag(session, nil, id, value ~= false) end
local function stamp(ids)
  local group = { id = ids[1], name = ids[1], maps = ids }
  return Progress.build({ group }, function(maps)
    local r = model:rows(maps)
    return { sections = { { rows = r[1] }, { rows = r[2] }, { rows = r[3] } }, pokemon = model:pokemon(maps) }
  end, { save = adapter.save, gen3 = true, mapId = ids[1] }).areas[1]
end
local count, totals, unknown = 0, { 0, 0, 0, 0 }, {}
local started = os.clock()
for id in pairs(raw.data.maps) do
  local catalog = model:catalog(id)
  for category = 1, 4 do
    totals[category] = totals[category] + #catalog[category]
    for _, row in ipairs(catalog[category]) do
      if row.untracked then unknown[#unknown + 1] = id .. ":" .. tostring(row.index) .. ":" .. tostring(row.label) end
      if category ~= 1 or not row.untracked then
        check(not row.itemId or adapter.data.items[row.itemId] ~= nil, "valid item in " .. id)
        check(not row.species or adapter.data.pokemon[row.species] ~= nil, "valid species in " .. id)
      end
    end
  end
  count = count + 1
end
local seconds = os.clock() - started
print(string.format("Catalogue %s: %d maps, %d trainers/%d items/%d hidden/%d scripted species, %.3fs cold",
  edition, count, totals[1], totals[2], totals[3], totals[4], seconds))
for _, row in ipairs(unknown) do print("UNTRACKED " .. row) end
if os.getenv("KANTO_GEAR_PROGRESS_REPORT") then
  for id, catalog in pairs(model.maps) do
    if #catalog[4] > 0 then
      local ids = {}; for _, r in ipairs(catalog[4]) do ids[#ids + 1] = r.species end
      print(id .. " scripted: " .. table.concat(ids, ","))
    end
  end
end
check(Json.encode(Schema.toSaveTable(session)) == before, "catalogue does not mutate session")
check(#unknown == 0, "all imported objectives classified")
local builds = model.builds
for id in pairs(raw.data.maps) do model:rows({ id }); model:pokemon({ id }) end
check(model.builds == builds, "warm reads never traverse scripts again")
check(Json.encode(Schema.toSaveTable(session)) == before, "live read models leave the session unchanged")

-- Exhaust every imported ground/hidden pickup, not just representative routes.
-- One changed flag must affect exactly its source, and clearing it restores it.
for id, catalog in pairs(model.maps) do
  for category = 2, 3 do
    for _, source in ipairs(catalog[category]) do
      if source.event and not source.repeatable then
        local previous = Flags.getFlag(session, nil, source.event)
        flag(source.event)
        local found = find(rows(id, category), function(r) return r.event == source.event end)
        check(found and found.done, "pickup proof " .. id .. ":" .. source.event)
        flag(source.event, false)
        found = find(rows(id, category), function(r) return r.event == source.event end)
        check(found and not found.done, "pickup rollback " .. id .. ":" .. source.event)
        flag(source.event, previous)
      end
    end
  end
end
-- A source change cannot leave a partial old catalogue cached.
local original = Space.bundle
Space.bundle = { scripts = {}, events = { FR_ROUTE_1 = { objects = {
  { localId = 99, trainerType = 1, scriptKey = "missing", x = 1, y = 1 } } } } }
check(stamp({ "FR_ROUTE_1" }).tier ~= "gold" and stamp({ "FR_ROUTE_1" }).untracked > 0,
  "unknown custom script blocks completion instead of disappearing")
Space.bundle = original

check(#rows("FR_PEWTER_CITY_GYM", 1) == 2, "Brock and bypassable trainer both required")
for _, row in ipairs(rows("FR_PEWTER_CITY_GYM", 1)) do check(not row.optional and not row.done, "new gym not complete") end
flag(Flags.trainerFlagId(142))
check(find(rows("FR_PEWTER_CITY_GYM", 1), function(r) return r.flags[Flags.trainerFlagId(142)] end).done, "trainer flag proves defeat")
flag(Flags.trainerFlagId(142), false)
check(#rows("FR_ROUTE_12", 1) == 8, "doubles partners and rematches counted once")
-- Exercise the host's real battle-result writer with both outcomes.
local Vm = require("src.core.game3.scripting.vm")
for _, result in ipairs({ "lose", "win" }) do
  flag(Flags.trainerFlagId(142), false)
  local vm = Vm.new({ store = session, scripts = { main = {
    { op = "trainerbattle", type = 0, trainer = 142, localId = 0 }, { op = "end" } } }, adapters = {
    startTrainerBattle = function(_, finish) finish(result) end,
  } })
  vm:start("main")
  check(find(rows("FR_PEWTER_CITY_GYM", 1), function(r) return r.flags[Flags.trainerFlagId(142)] end).done == (result == "win"),
    "native battle " .. result .. " reflected correctly")
end
flag(Flags.trainerFlagId(142), false)
check(#rows("FR_ROUTE_22", 1) == 2, "early and late rivals are separate; starter variants are not")
check(find(rows("FR_ROUTE_22", 1), function(r) return r.optional end) ~= nil, "one-shot early rival optional")
check(#rows("FR_OAKS_LAB", 1) == 1 and rows("FR_OAKS_LAB", 1)[1].optional, "tutorial rival optional once")
check(#rows("FR_POKEMON_LEAGUE_CHAMPIONS_ROOM", 1) == 1, "champion variants/rematch share one objective")
flag("FLAG_SYS_GAME_CLEAR")
check(rows("FR_POKEMON_LEAGUE_CHAMPIONS_ROOM", 1)[1].done, "past champion win survives native rematch reset")
flag("FLAG_SYS_GAME_CLEAR", false)

local fossil = rows("FR_MT_MOON_B2F", 2)
check(#fossil == 6, "four item balls plus both fossil choices")
flag(626)
fossil = rows("FR_MT_MOON_B2F", 2)
check(find(fossil, function(r) return r.itemId == 358 end).done, "chosen dome fossil complete")
check(find(fossil, function(r) return r.itemId == 357 end).excluded, "unchosen helix is excluded")
flag(626, false)
for _, row in ipairs(rows("FR_ROCKET_HIDEOUT_B4F", 2)) do
  if row.ownedKey then check(not row.done, "initially hidden key item not falsely collected") end
end
require("src.core.game3.bag").add(session.bag, 356, 1)
check(find(rows("FR_ROCKET_HIDEOUT_B4F", 2), function(r) return r.itemId == 356 end).done, "owned lift key is proof")
require("src.core.game3.bag").set(session.bag, 356, 0)
session.storage.items[#session.storage.items + 1] = { id = 356, qty = 1 }
check(find(rows("FR_ROCKET_HIDEOUT_B4F", 2), function(r) return r.itemId == 356 end).done, "PC-held key still counts")
table.remove(session.storage.items)
local pickup = rows("FR_ROUTE_2", 2)[1]
check(not pickup.done, "uncollected item starts open")
flag(pickup.event)
check(rows("FR_ROUTE_2", 2)[1].done, "collection flag sets completion")
flag(pickup.event, false)
check(not rows("FR_ROUTE_2", 2)[1].done, "loading older flag state reverses collection")
-- Execute the imported pickup script. Only presentation is stubbed; inventory,
-- object removal and flag writes use the host's real adapters.
do
  local Bag = require("src.core.game3.bag")
  local Adapters = require("src.core.game3.scripting.adapters")
  local Objects = require("src.core.game3.objects")
  local previousBag = session.bag
  Space.store, Space.active = session, true
  local event = Space.bundle.events.FR_ROUTE_2
  local object = find(event.objects, function(o) return o.localId == pickup.index end)
  for _, full in ipairs({ true, false }) do
    session.bag = Bag.new()
    if full then assert(Bag.add(session.bag, pickup.itemId, 999)) end
    flag(pickup.event, false)
    Objects.loadMap(nil, "FR_ROUTE_2", event)
    local native, presentation = Adapters.host(nil, nil, nil), Adapters.stub()
    presentation.playSe = function() end
    presentation.waitFanfare = function(done) done() end
    for _, key in ipairs({ "checkItemSpace", "checkItemType", "modifyItem", "removeObject" }) do
      presentation[key] = native[key]
    end
    local vm = Vm.new({ store = session, scripts = Space.bundle.scripts, text = Space.bundle.text, adapters = presentation })
    vm:startTalk(object.scriptKey, object.localId, 1)
    for _ = 1, 200 do if not vm:isRunning() then break end; vm:tick() end
    check(not vm:isRunning(), "imported pickup script finishes: " .. Json.encode(vm.ctx.pc))
    check(rows("FR_ROUTE_2", 2)[1].done == not full, "full bag cannot complete a pickup")
    check(Bag.get(session.bag, pickup.itemId) == (full and 999 or 1), "native pickup inventory agrees")
  end
  session.bag, Space.active = previousBag, false
  flag(pickup.event, false)
end
flag("FLAG_HIDE_SS_ANNE")
check(rows("FR_SSANNE_1F_ROOM2", 2)[1].missed, "departed ship preserves missed objectives")
flag("FLAG_HIDE_SS_ANNE", false)

local beach = "SEVII_ONE_ISLAND_TREASURE_BEACH"
local a = stamp({ beach })
for _, row in ipairs(rows(beach, 3)) do
  check(row.repeatable, "Treasure Beach hidden items renewable")
  flag(row.event)
end
local b = stamp({ beach })
check(a.fieldTotal == b.fieldTotal and a.fieldDone == b.fieldDone, "respawn selection cannot award/remove progress")
check(a.sections[3].total == 0 and a.sections[3].repeatable > 0, "renewable finds are shown outside gold requirements")

local mons = model:pokemon({ "FR_OAKS_LAB" })
check(#mons == 1, "one starter goal before choice")
flag("FLAG_SYS_POKEMON_GET")
Flags.setVar(session, nil, "VAR_STARTER_MON", 2)
require("src.core.game3.dex").setCaught(session.dex, 4)
adapter:refresh()
mons = model:pokemon({ "FR_OAKS_LAB" })
check(#mons == 1 and mons[1].species == 4 and mons[1].done, "chosen starter only, live global dex")
check(#model:pokemon({ "FR_SAFFRON_CITY_DOJO" }) == 1, "one dojo reward, no mandatory trade for alternative")
check(find(model:pokemon({ "FR_POWER_PLANT" }), function(r) return r.species == 145 end) ~= nil, "Zapdos included")
check(find(model:pokemon({ "FR_CELADON_CITY_CONDOMINIUMS_ROOF_ROOM" }), function(r) return r.species == 133 end) ~= nil, "gift Eevee included")
check(#model:pokemon({ "FR_CELADON_CITY_GAME_CORNER_PRIZE_ROOM" }) == 5, "all five edition-specific casino rewards included")
local reward = edition == "firered" and 123 or 127
check(find(model:pokemon({ "FR_CELADON_CITY_GAME_CORNER_PRIZE_ROOM" }), function(r) return r.species == reward end) ~= nil,
  "casino species follows this ROM's edition")
check(find(model:pokemon({ "FR_ROUTE_2_HOUSE" }), function(r) return r.species == 122 end) ~= nil, "NPC trade included")
check(find(model:pokemon({ "FR_NAVEL_ROCK_SUMMIT" }), function(r) return r.species == 250 end) ~= nil, "event Ho-Oh included")
check(find(model:pokemon({ "FR_BIRTH_ISLAND_EXTERIOR" }), function(r) return r.species == 410 end) ~= nil, "Deoxys retains internal species ID")
check(rows("FR_TRAINER_TOWER_1F", 1)[1].repeatable, "generated tower challenge is not a permanent route trainer")
check(find(model:pokemon({ "FR_POKEMON_TOWER_6F" }), function(r) return r.species == 105 end) == nil, "uncatchable ghost not a catch goal")
local groups = Progress.groups(adapter.data.maps, adapter:locations())
local groupOf = {}
for _, g in ipairs(groups) do for _, id in ipairs(g.maps) do groupOf[id] = g end end
check(groupOf.FR_MT_MOON_1F == groupOf.FR_MT_MOON_B2F, "cave floors grouped")
check(groupOf.FR_PEWTER_CITY ~= groupOf.FR_PEWTER_CITY_GYM, "gym distinct from city")
check(groupOf.FR_ROUTE_21_NORTH == groupOf.FR_ROUTE_21_SOUTH, "route segments grouped")
check(groupOf.FR_ROUTE_2.kind == "route", "forest gate does not change route stamp kind")
check(groupOf.FR_VIRIDIAN_FOREST.kind == "forest", "forest has its own stamp kind")
-- Real new/mid/complete/older-save transitions, including global catch proof.
local gym = "FR_PEWTER_CITY_GYM"
check(stamp({ gym }).tier == "bronze", "unbeaten visited gym bronze")
for _, r in ipairs(rows(gym, 1)) do for fid in pairs(r.flags) do flag(fid) end end
check(stamp({ gym }).tier == "gold", "all required gym trainers give gold")
local saved = Schema.toSaveTable(session)
raw.session = Schema.newGame({ version = edition, name = "NEW", rngSeed = 7 })
adapter:refresh()
check(stamp({ gym }).tier == "bronze", "new playthrough does not inherit gold")
raw.session = Schema.fromSaveTable(saved)
adapter:refresh()
check(stamp({ gym }).tier == "gold", "serialized progress restores gold")
raw.session = session; adapter:refresh()
local route = "FR_ROUTE_1"
check(stamp({ route }).tier == "silver", "no field goals but missing species gives silver")
for _, r in ipairs(model:pokemon({ route })) do require("src.core.game3.dex").setCaught(session.dex, r.species) end
adapter:refresh()
check(stamp({ route }).tier == "gold", "global dex completes all route species")
local savedBundle = Space.bundle
Space.bundle = nil
check(stamp({ "FR_ROUTE_1" }).untracked > 0, "missing bundle cannot produce a gold stamp")
Space.bundle = savedBundle
check(not model:rows({ "FR_ROUTE_1" })[1][1], "late bundle arrival replaces unknown catalogue")
-- Detection range and underfoot items must agree for every imported hidden item.
local radarChecks = 0
for id in pairs(raw.data.maps) do
  for _, row in ipairs(model:catalog(id)[3]) do
    for dx = -8, 8 do for dy = -6, 6 do
      local expected = row.underfoot and dx == 0 and dy == 0
        or not row.underfoot and math.abs(dx) <= 7 and math.abs(dy) <= 5
      check(adapter:itemfinderReached(row.x - dx, row.y - dy, row, 1) == expected,
        "native hidden-item range in " .. id)
      radarChecks = radarChecks + 1
    end end
  end
end
local Bag = require("src.core.game3.bag")
local Map, Player = require("src.core.game3.map"), require("src.core.game3.player")
local probe = { type="hidden_item", x=12, y=12, item=13, flag=0x3e8, underfoot=true }
raw.data.maps.RADAR_FIXTURE = { bgEvents={probe} }
session.map, session.x, session.y = "RADAR_FIXTURE", 12, 12
Map.current, Player.cellX, Player.cellY = session.map, 12, 12
Bag.set(session.bag, "ITEMFINDER", 1); flag(probe.flag, false); adapter:refresh()
local readBefore = Json.encode(Schema.toSaveTable(session))
local signals = adapter:itemfinderSignals()
check(#signals == 1 and signals[1].dx == 0 and signals[1].dy == 0, "underfoot item responds only on its tile")
check(Json.encode(Schema.toSaveTable(session)) == readBefore, "radar never picks up underfoot items or changes the save")
Player.cellX = 11
check(#adapter:itemfinderSignals() == 0, "underfoot item does not respond nearby")
probe.underfoot = false
check(#adapter:itemfinderSignals() == 1, "ordinary item responds nearby")
flag(probe.flag)
check(#adapter:itemfinderSignals() == 0, "taken item disappears immediately")
flag(probe.flag,false); Bag.set(session.bag,"ITEMFINDER",0); adapter:refresh()
session.storage.items = { {id=adapter.Items.toNumericId("ITEMFINDER"),qty=1} }
check(#adapter:itemfinderSignals() == 0, "itemfinder in PC does not enable radar")
check(not adapter:itemfinderReached(0,0,{x=1,y=1,done=true},1), "collected locations never reveal again")
check(not adapter:itemfinderReached(0,0,{x=7,y=5},0.5), "sweep does not reveal a distant signal early")
print(string.format("Gen3 progress %s: %d checks passed (%d radar positions)", edition, checks, radarChecks))
