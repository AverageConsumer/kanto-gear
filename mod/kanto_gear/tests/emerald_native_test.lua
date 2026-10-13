-- Run from an exact Recomp checkout. No ROM, save, or extracted assets are
-- distributed with this test; KANTO_GEAR_MOD_PATH and POKEPORT_GBA_CACHE point
-- at the local mod and the user's imported edition respectively.
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local cacheRoot = assert(os.getenv("POKEPORT_GBA_CACHE"))
local edition = assert(os.getenv("POKEPORT_VERSION"))
require("src.core.GameVersion").set(edition)
require("src.import.gba.versions").select(edition)
local Dataset = require("src.core.game3.dataset")
Dataset.cacheRootOverride = cacheRoot
Dataset.mountExtractRoots()
local cache = Dataset.cache()
local P = require("src.core.game3.pokemon")
local I = require("src.core.game3.items_data")
P.install(cache)
I.install(cache)
local Schema = require("src.core.game3.save_schema_firered")
local Bag = require("src.core.game3.bag")
local Party = require("src.core.game3.party")
local Flags = require("src.core.game3.scripting.flags")
local maps = Dataset.buildMaps()
Dataset.attachMidLayouts(maps, cache)
local encounters = assert(loadfile(cacheRoot .. "/encounters.lua"))()
local s = Schema.newGame({ version = edition, name = "TEST", rngSeed = 12345 })
local raw = { generation = 3, phase = "field", session = s,
  save = Schema.toSaveTable(s), data = { maps = maps, gen3Encounters = encounters } }
require("src.core.game3.runtime").session = s
require("src.mods.Gen3Compat").bind(function() return raw end)
local Gen3 = assert(loadfile(root .. "/tests/support/module.lua"))()(root, "adapters/gen3/init")
local checks = 0
local function check(ok, label)
  assert(ok, label)
  checks = checks + 1
end
local adapter = Gen3.new(raw)

check(edition == "emerald", "Emerald fixture required")
check(adapter.profile.id == "emerald", "edition profile")
local C = require("src.core.game3.constants").of(edition)
local Json = require("src.import.canonical_json")
local before
local regional, national = {}, 0
local rawEntries = require("src.ui.game3.rse.mapsec").readLua("pokemon/pokedex/entries.lua")
for id, def in pairs(adapter.data.pokemon) do
  national = national + 1
  local number = adapter:dexNumber(id)
  if number then check(not regional[number], "unique Hoenn number"); regional[number] = id end
  check(def.dexEntry.text == rawEntries[id].description, "internal-ID dex text: " .. id)
  check(def.dexEntry.heightM == rawEntries[id].height / 10, "height: " .. id)
end
check(national == 386 and #regional == 202, "386 National / 202 Hoenn species")
check(regional[1] == P.speciesFromNational(252) and regional[202] == P.speciesFromNational(386), "Hoenn endpoints")
check(adapter:dexNumber(1) == nil, "Bulbasaur is not in Hoenn Dex")
check(adapter.data.pokemon[410].baseStats.attack == 95, "Emerald Deoxys form")
check(adapter:locations().EM_LITTLEROOT_TOWN.name == "LITTLEROOT TOWN", "Hoenn location names")
local locations = adapter:locations()
for id, location in pairs(locations) do
  check(location.name:find("%S") ~= nil, "every Hoenn location has a visible name: " .. id)
end
check(locations.EM_SS_TIDAL_CORRIDOR.name == "SS TIDAL CORRIDOR", "unnamed sections use a readable map name")
check(locations.EM_SS_TIDAL_CORRIDOR.progressGroup ~= locations.EM_BATTLE_PYRAMID_SQUARE01.progressGroup,
  "shared unnamed section never merges unrelated locations")
check(locations.EM_AQUA_HIDEOUT_1F.progressGroup == locations.EM_AQUA_HIDEOUT_B1F.progressGroup,
  "named dungeon floors retain their shared stamp")
for i = 1, 8 do
  local badge = adapter.flagDefinitions.BADGES[i]
  check(not adapter:badge(i), "unearned badge")
  s.flags[badge.flag] = true; check(adapter:badge(i), "Hoenn badge flag " .. i); s.flags[badge.flag] = nil
end
s.dex.national = true; adapter:refresh()
check(adapter:dexNumber(1) == 1 and adapter:dexNumber(410) == 386, "National unlock changes numbering")
s.dex.national = nil; adapter:refresh()
before = Json.encode(Schema.toSaveTable(s))
local Progress = assert(loadfile(root .. "/tests/support/module.lua"))()(root, "adapters/gen3/progress").new(adapter)
local total, objectives, unknown = 0, {0,0,0,0}, {}
for id in pairs(maps) do
  total = total + 1
  local sums = {}
  for _, row in ipairs(adapter:encounters(id)) do
    check(adapter.data.pokemon[row.species] ~= nil, "known encounter " .. id)
    sums[row.method] = (sums[row.method] or 0) + row.chance
  end
  for method, chance in pairs(sums) do check(chance == 100, "conditional odds sum " .. id .. method) end
  local rows = Progress:catalog(id)
  for category = 1, 4 do
    objectives[category] = objectives[category] + #rows[category]
    for _, row in ipairs(rows[category]) do
      if category == 1 and row.index then
        local object
        for _, obj in ipairs(adapter.Space.bundle.events[id].objects or {}) do
          if obj.localId == row.index then object = obj break end
        end
        check(object ~= nil and row.graphicsId == (object.graphicsId or object.graphics),
          "trainer carries native object graphics " .. id)
      end
      if row.untracked then unknown[#unknown+1] = id .. ":" .. tostring(row.label) end
      check(not row.species or adapter.data.pokemon[row.species] ~= nil, "known scripted species " .. id)
      check(not row.itemId or row.untracked or adapter.data.items[row.itemId] ~= nil, "known item " .. id)
    end
  end
  Progress:rows({id}); Progress:pokemon({id})
end
check(total == 518, "full imported map catalogue")
check(#unknown == 0, "all imported objective types classified")
local gifts, daily = 0, 0
for id, catalog in pairs(Progress.maps) do
  for _, row in ipairs(catalog[2]) do
    if row.gift then
      gifts = gifts + 1
      check(not s.flags[row.event], "new save has not received NPC reward " .. id)
      if row.repeatable then
        daily = daily + 1
        check(row.event >= C:flag("DAILY_FLAGS_START") and row.event <= C:flag("DAILY_FLAGS_END"),
          "daily native reset range remains informational")
      else
        s.flags[row.event] = true
        local done
        for _, live in ipairs(Progress:rows({id})[2]) do if live.id == row.id then done = live.done end end
        check(done == true, "every native one-time gift reads its actual receipt flag " .. id)
        s.flags[row.event] = nil
        for _, live in ipairs(Progress:rows({id})[2]) do
          if live.id == row.id then check(not live.done, "older save reverses NPC gift " .. id) end
        end
      end
    end
  end
end
check(gifts == 78 and daily == 2, "78 supported NPC rewards, two daily rewards excluded from completion: " .. gifts .. "/" .. daily)
check(#adapter:encounters("EM_ROUTE101") == 3, "Route 101 encounter catalogue")
check(#Progress:pokemon({"EM_ROUTE101"}) == 4, "one starter choice, three wild species")
for _,row in ipairs(Progress:rows({"EM_RUSTBORO_CITY_GYM"})[1]) do
  check(not row.optional and not row.done, "gym trainers are required and unearned")
end
for _,row in ipairs(Progress:rows({"EM_BATTLE_PYRAMID_SQUARE01"})[2]) do
  check(row.repeatable and not row.untracked and not row.done, "Pyramid pickups are repeatable")
end
check(Json.encode(Schema.toSaveTable(s)) == before, "read models leave native save unchanged")
-- Local species goals accept acquisition anywhere, including evolution.
local Achievements = dofile(root .. "/features/achievements.lua")
local aqua = adapter:areaMaps("EM_AQUA_HIDEOUT_1F")
local function aquaTier()
  return Achievements.build({ { id = aqua[1], maps = aqua, name = "AQUA HIDEOUT" } }, function(ids)
    return { sections = { { rows = {} }, { rows = {} }, { rows = {} } }, pokemon = Progress:pokemon(ids) }
  end, { gen3 = true, save = adapter.save, mapId = aqua[1] }).areas[1].tier
end
local electrode = P.speciesFromNational(101)
local oldCaught = adapter.save.pokedex.caught[electrode]
check(aquaTier() == "gold", "missable Electrode encounter cannot lock Aqua Hideout below Gold")
local bonus = Progress:pokemon(aqua)[1]
check(bonus.species == electrode and bonus.missable and not bonus.done, "uncaught Aqua encounter stays an honest bonus")
adapter.save.pokedex.caught[electrode] = true
check(aquaTier() == "gold", "an Electrode obtained elsewhere completes Aqua Hideout species goal")
check(Progress:pokemon(aqua)[1].done, "global caught flag records the actual bonus completion")
adapter.save.pokedex.caught[electrode] = oldCaught
check(aquaTier() == "gold", "older dex restores the uncaught bonus without blocking Gold")
check(not Progress:pokemon(aqua)[1].done, "older dex also restores the unfinished bonus")
local voltorb = P.speciesFromNational(100)
for _, row in ipairs(Progress:pokemon({ "EM_NEW_MAUVILLE_INSIDE" })) do
  if row.species == voltorb then check(row.wild and not row.missable, "renewable local encounters override static bonus classification") end
end
local function itemSection(id)
  return Achievements.build({ { id = id, maps = { id } } }, function(ids)
    local rows = Progress:rows(ids)
    return { sections = { { rows = {} }, { rows = rows[2] }, { rows = {} } } }
  end, { gen3 = true, save = adapter.save, mapId = id }).areas[1].sections[2]
end
local eonTicket, ticketLocations = C:id("items", "ITEM_EON_TICKET"), 0
for id in pairs(maps) do
  for _, source in ipairs(Progress:catalog(id)[2]) do
    if source.itemId == eonTicket then
      ticketLocations = ticketLocations + 1
      check(source.optional == true, "externally distributed Eon Ticket is a bonus in " .. id)
      local oldFlag = s.flags[source.event]
      for _, received in ipairs({ false, true, false }) do
        Flags.setFlag(s, nil, source.event, received)
        local ticket
        for _, row in ipairs(Progress:rows({ id })[2]) do
          if row.itemId == eonTicket then ticket = row; break end
        end
        check(ticket and ticket.done == received, "Eon Ticket keeps its real receipt state in " .. id)
        local area = Achievements.build({ { id = id, maps = { id } } }, function()
          return { sections = { { rows = {} }, { rows = { ticket } }, { rows = {} } } }
        end, { gen3 = true, save = adapter.save, mapId = id }).areas[1]
        check(area.tier == "gold" and area.sections[2].total == 0,
          "Eon Ticket alone never blocks Gold in " .. id)
        check(area.sections[2].optional == 1 and area.sections[2].bonusDone == (received and 1 or 0),
          "Eon Ticket completion belongs only to the bonus counter in " .. id)
      end
      Flags.setFlag(s, nil, source.event, oldFlag == true)
    end
  end
end
check(ticketLocations > 1, "real shared Eon Ticket distribution appears in multiple locations")
local rootFlag, clawFlag = C:flag("FLAG_CHOSE_ROOT_FOSSIL"), C:flag("FLAG_CHOSE_CLAW_FOSSIL")
local underpass = C:flag("FLAG_HIDE_DESERT_UNDERPASS_FOSSIL")
local mirage = C:var("VAR_MIRAGE_TOWER_STATE")
check(itemSection("EM_MIRAGE_TOWER_4F").total == 1, "Trugturm's two fossils form one required choice")
check(itemSection("EM_MIRAGE_TOWER_4F").done == 0, "unmade fossil choice remains pending")
for _, selected in ipairs({ rootFlag, clawFlag }) do
  Flags.setFlag(s, nil, rootFlag, selected == rootFlag)
  Flags.setFlag(s, nil, clawFlag, selected == clawFlag)
  Flags.setFlag(s, nil, C:flag("FLAG_HIDE_MIRAGE_TOWER_ROOT_FOSSIL"), true)
  Flags.setFlag(s, nil, C:flag("FLAG_HIDE_MIRAGE_TOWER_CLAW_FOSSIL"), true)
  local tower = itemSection("EM_MIRAGE_TOWER_4F")
  check(tower.total == 1 and tower.done == 1 and tower.excluded == 1, "either fossil completes exactly one tower goal; both hide flags never prove both received")
  Flags.setFlag(s, nil, underpass, true)
  Flags.setVar(s, nil, mirage, 1)
  check(itemSection("EM_DESERT_UNDERPASS").done == 0, "seeded hide flag before collapse is not proof of receiving the second fossil")
  Flags.setVar(s, nil, mirage, 2)
  Flags.setFlag(s, nil, underpass, false)
  local second = itemSection("EM_DESERT_UNDERPASS")
  check(second.total == 1 and second.done == 0 and second.excluded == 1, "the other fossil is a separate obtainable postgame goal: " .. second.total .. "/" .. second.done .. "/" .. second.excluded .. "/" .. second.optional)
  Flags.setFlag(s, nil, underpass, true)
  check(itemSection("EM_DESERT_UNDERPASS").done == 1, "actual second pickup completes that independent goal")
  Flags.setFlag(s, nil, underpass, false)
  check(itemSection("EM_DESERT_UNDERPASS").done == 0, "older save reverses second fossil completion")
end
for _, flag in ipairs({rootFlag, clawFlag, underpass, C:flag("FLAG_HIDE_MIRAGE_TOWER_ROOT_FOSSIL"), C:flag("FLAG_HIDE_MIRAGE_TOWER_CLAW_FOSSIL")}) do
  Flags.setFlag(s, nil, flag, false)
end
Flags.setVar(s, nil, mirage, 0)
local pickup = assert(Progress:rows({"EM_ROUTE102"})[2][1])
check(not pickup.done and pickup.event >= 0x20, "real route pickup flag")
s.flags[pickup.event] = true
check(Progress:rows({"EM_ROUTE102"})[2][1].done, "pickup reads current native flag")
s.flags[pickup.event] = nil
check(not Progress:rows({"EM_ROUTE102"})[2][1].done, "loading an older save reverses completion")
print("Emerald catalogue",total,table.concat(objectives,"/"),"unknown",#unknown)
for _,row in ipairs(unknown) do print("UNTRACKED",row) end
print("Emerald native checks",checks)
