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
local Gen3 = assert(loadfile(root .. "/gen3.lua"))()
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
for i = 1, 8 do
  local badge = adapter.flagDefinitions.BADGES[i]
  check(not adapter:badge(i), "unearned badge")
  s.flags[badge.flag] = true; check(adapter:badge(i), "Hoenn badge flag " .. i); s.flags[badge.flag] = nil
end
s.dex.national = true; adapter:refresh()
check(adapter:dexNumber(1) == 1 and adapter:dexNumber(410) == 386, "National unlock changes numbering")
s.dex.national = nil; adapter:refresh()
before = Json.encode(Schema.toSaveTable(s))
local Progress = dofile(root .. "/gen3_progress.lua").new(adapter)
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
      if row.untracked then unknown[#unknown+1] = id .. ":" .. tostring(row.label) end
      check(not row.species or adapter.data.pokemon[row.species] ~= nil, "known scripted species " .. id)
      check(not row.itemId or row.untracked or adapter.data.items[row.itemId] ~= nil, "known item " .. id)
    end
  end
  Progress:rows({id}); Progress:pokemon({id})
end
check(total == 518, "full imported map catalogue")
check(#unknown == 0, "all imported objective types classified")
check(#adapter:encounters("EM_ROUTE101") == 3, "Route 101 encounter catalogue")
check(#Progress:pokemon({"EM_ROUTE101"}) == 4, "one starter choice, three wild species")
for _,row in ipairs(Progress:rows({"EM_RUSTBORO_CITY_GYM"})[1]) do
  check(not row.optional and not row.done, "gym trainers are required and unearned")
end
for _,row in ipairs(Progress:rows({"EM_BATTLE_PYRAMID_SQUARE01"})[2]) do
  check(row.repeatable and not row.untracked and not row.done, "Pyramid pickups are repeatable")
end
check(Json.encode(Schema.toSaveTable(s)) == before, "read models leave native save unchanged")
local pickup = assert(Progress:rows({"EM_ROUTE102"})[2][1])
check(not pickup.done and pickup.event >= 0x20, "real route pickup flag")
s.flags[pickup.event] = true
check(Progress:rows({"EM_ROUTE102"})[2][1].done, "pickup reads current native flag")
s.flags[pickup.event] = nil
check(not Progress:rows({"EM_ROUTE102"})[2][1].done, "loading an older save reverses completion")
print("Emerald catalogue",total,table.concat(objectives,"/"),"unknown",#unknown)
for _,row in ipairs(unknown) do print("UNTRACKED",row) end
print("Emerald native checks",checks)
