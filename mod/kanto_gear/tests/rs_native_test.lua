-- Native Ruby/Sapphire data checks; ROM-derived caches stay outside the mod.
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local cacheRoot = assert(os.getenv("POKEPORT_GBA_CACHE"))
local edition = assert(os.getenv("POKEPORT_VERSION"))
assert(edition == "ruby" or edition == "sapphire", "Ruby/Sapphire fixture required")
require("src.core.GameVersion").set(edition)
require("src.import.gba.versions").select(edition)
require("src.core.game3.se_ids").select(edition)
require("src.core.game3.song_ids").select(edition)
local Dataset = require("src.core.game3.dataset")
Dataset.cacheRootOverride = cacheRoot
Dataset.mountExtractRoots()
local cache = Dataset.cache()
local P = require("src.core.game3.pokemon")
P.install(cache)
require("src.core.game3.items_data").install(cache)
local Schema = require("src.core.game3.save_schema_firered")
local maps = Dataset.buildMaps()
Dataset.attachMidLayouts(maps, cache)
local session = Schema.newGame({ version = edition, name = "TEST", rngSeed = 12345 })
local raw = { generation = 3, phase = "field", session = session,
  save = Schema.toSaveTable(session), data = { maps = maps,
    gen3Encounters = assert(loadfile(cacheRoot .. "/encounters.lua"))() } }
require("src.core.game3.runtime").session = session
require("src.mods.Gen3Compat").bind(function() return raw end)
local adapter = assert(loadfile(root .. "/tests/support/module.lua"))()(root, "adapters/gen3/init").new(raw)
local C = require("src.core.game3.constants").of(edition)
local Json = require("src.import.canonical_json")
local before = Json.encode(Schema.toSaveTable(session))
local checks = 0
local function check(ok, label) assert(ok, label); checks = checks + 1 end
check(adapter.profile.id == edition and adapter.hoenn and adapter.rs, "native Hoenn profile")
check(adapter.flagDefinitions.game == "ruby", "RS flags, never Emerald or FRLG flags")
local national, regional = 0, {}
local entries = require("src.ui.game3.rse.mapsec").readLua("pokemon/pokedex/entries.lua")
for id, def in pairs(adapter.data.pokemon) do
  national = national + 1
  local number = adapter:dexNumber(id)
  if number then check(not regional[number], "unique regional number"); regional[number] = id end
  local entry = entries[id]
  check(def.dexEntry.text == entry.description .. (entry.description2 and "\n" .. entry.description2 or ""),
    "both edition-specific dex text pages " .. id)
end
check(national == 386 and #regional == 202, "386 National / 202 Hoenn species")
check(adapter:dexNumber(1) == nil, "Kanto species absent from regional dex")
local locations, prefix = adapter:locations(), adapter.profile.map.enginePrefix
check(locations[prefix .. "LITTLEROOT_TOWN"].name == "LITTLEROOT TOWN", "Hoenn location names")
for id, location in pairs(locations) do
  check(location.name:find("%S") ~= nil, "every location has a name " .. id)
end
for i = 1, 8 do
  local badge = C:flag(string.format("FLAG_BADGE0%d_GET", i))
  check(not adapter:badge(i), "badge initially absent")
  session.flags[badge] = true
  check(adapter:badge(i), "live native RS badge")
  session.flags[badge] = nil
end
local Progress = assert(loadfile(root .. "/tests/support/module.lua"))()(root, "adapters/gen3/progress").new(adapter)
local count, unknown, totals = 0, {}, {0, 0, 0, 0}
for id in pairs(maps) do
  count = count + 1
  local sums = {}
  for _, row in ipairs(adapter:encounters(id)) do
    check(adapter.data.pokemon[row.species] ~= nil, "known encounter " .. id)
    sums[row.method] = (sums[row.method] or 0) + row.chance
  end
  for method, chance in pairs(sums) do check(chance == 100, "encounter odds " .. id .. method) end
  local rows = Progress:catalog(id)
  for category = 1, 4 do
    totals[category] = totals[category] + #rows[category]
    for _, row in ipairs(rows[category]) do
      if row.untracked then unknown[#unknown + 1] = id .. ":" .. tostring(row.label) .. ":" .. tostring(row.index) end
      check(not row.species or adapter.data.pokemon[row.species], "known scripted species " .. id)
      check(not row.itemId or row.untracked or adapter.data.items[row.itemId], "known item " .. id)
    end
  end
  Progress:rows({id}); Progress:pokemon({id})
end
print(edition, "catalogue", count, table.concat(totals, "/"), "unknown", #unknown)
check(count == 394, "complete native map catalogue")
for _, row in ipairs(unknown) do print("UNTRACKED", row) end
check(#unknown == 0, "all imported objectives classified")
local unused = prefix .. (edition == "ruby" and "AQUA" or "MAGMA") .. "_HIDEOUT_"
check(Progress.unusedHideout == unused, "native load script proves unused edition hideout")
for _, floor in ipairs({ "1F", "B1F", "B2F" }) do
  for _, rows in ipairs(Progress:catalog(unused .. floor)) do
    check(#rows == 0, "unused rooms never become impossible stamp goals")
  end
end
local active = prefix .. (edition == "ruby" and "MAGMA" or "AQUA") .. "_HIDEOUT_B1F"
check(#Progress:catalog(active)[1] > 0, "active hideout still has trainer objectives")
local bundle = Progress:bundle()
local city = maps[prefix .. "LILYCOVE_CITY"]
local loadKey = bundle.events[prefix .. "LILYCOVE_CITY"].mapScripts.onLoad
local changed = {}
for i, row in ipairs(bundle.scripts[loadKey]) do changed[i] = row end
for _, warp in ipairs(city.warps) do
  if warp.destMap == unused .. "1F" then
    table.insert(changed, 1, {op = "setmetatile", warp.x, warp.y, 0, 0})
  end
end
local custom = setmetatable({Space = {bundle = {events = bundle.events,
  scripts = setmetatable({[loadKey] = changed}, {__index = bundle.scripts})}}}, {__index = adapter})
local customProgress = assert(loadfile(root .. "/tests/support/module.lua"))()(root, "adapters/gen3/progress").new(custom)
customProgress:bundle()
check(customProgress.unusedHideout == nil, "custom scripts reopening the unused hideout retain objectives")
check(Json.encode(Schema.toSaveTable(session)) == before, "read models leave native save unchanged")
print(edition, "native checks", checks)
return { adapter = adapter, session = session, progress = Progress, constants = C }
