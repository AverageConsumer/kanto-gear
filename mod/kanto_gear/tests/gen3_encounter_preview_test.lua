local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local Gen3 = {}
for _, name in ipairs({ "world", "encounter_preview" }) do
  assert(loadfile(root .. "/adapters/gen3/models/" .. name .. ".lua"))()(Gen3)
end
local clock, calls, preview = 0, 0, nil
local pokemon = {}
for id = 1, 100 do pokemon[id] = { index = id, name = "SPECIES_" .. id } end
setmetatable(pokemon, { __index = function(t, id)
  return type(id) == "string" and rawget(t, tonumber(id:match("^SPECIES_(%d+)$"))) or nil
end })
local land = { rate = 20, slots = {} }
for i = 1, 12 do land.slots[i] = { species = i % 2 == 1 and 16 or 19, minLevel = 2, maxLevel = 5 } end
local area = { land = land, fishing = { slots = {
  {species=1,minLevel=5,maxLevel=5}, {species=4,minLevel=6,maxLevel=8} } } }
local adapter = setmetatable({ data = { pokemon = pokemon, maps = { ROUTE = {} } },
  game = { session = {}, data = { gen3Encounters = { ROUTE = area } } },
  encounterClock = function() return clock end }, { __index = Gen3 })
local function method(rows, name)
  local out = {}; for _, row in ipairs(rows) do if row.method == name then out[#out + 1] = row end end
  return out
end
local function read() return method(adapter:encounters("ROUTE"), "WALK") end
assert(#read() == 2, "standalone native readers retain their original fallback")
adapter.encounterWorld = { effectiveEncounters = function(_, map, terrain)
  calls = calls + 1
  assert(map == "ROUTE" and (terrain == "grass" or terrain == "water"))
  if terrain == "water" then return { chance = 0, dist = {} } end
  return preview
end }
local function set(value)
  preview = value; adapter:clearEncounterPreviews()
end
set({ chance = .2, dist = { SPECIES_16 = 50, SPECIES_19 = 50 } })
local native = read()
assert(#native == 2 and native[1].minLevel == 2 and native[2].maxLevel == 5,
  "an unchanged public distribution retains native level ranges")
local dist = {}; for i = 1, 15 do dist["SPECIES_" .. i] = i end
set({ chance = .2, dist = dist })
local rows = read()
assert(#rows == 15, "arbitrary providers can report more species than physical slots")
local sum = 0
for _, row in ipairs(rows) do
  sum = sum + row.chance
  assert(math.abs(row.chance - row.species * 100 / 120) < 1e-8)
  assert(row.minLevel == nil and row.maxLevel == nil, "flat preview weights cannot invent level mappings")
end
assert(math.abs(sum - 100) < 1e-8 and #land.slots == 12 and land.slots[1].species == 16)
local before = calls
for _ = 1, 100 do read() end
assert(calls == before, "repeated renders reuse a bounded preview cache")
clock = .5; read()
assert(calls == before + 2, "time expiry observes arbitrary providers without private events")
adapter.game.session = {}; read()
assert(calls == before + 4, "loading a different native session discards cached previews")
set({ chance = 0, dist = {} }); assert(#read() == 0, "valid empty preview is not a fallback request")
set({ chance = .2, dist = { SPECIES_3 = 10, SPECIES_4 = 0 } })
assert(#read() == 1 and read()[1].species == 3 and read()[1].chance == 100)
for _, value in ipairs({ false, {}, {chance=.2,dist={SPECIES_1=-1}},
  {chance=.2,dist={SPECIES_1=0/0}}, {chance=.2,dist={SPECIES_1=math.huge}},
  {chance=.2,dist={SPECIES_1="50"}}, {chance=.2,dist={UNREGISTERED=50}},
  {chance=2,dist={SPECIES_1=1}} }) do
  set(value); assert(#read() == 2, "invalid or unsupported previews retain native data")
end
adapter.encounterWorld = { effectiveEncounters = function() error("provider failure") end }
assert(#read() == 2, "a failed query cannot crash the guide")
adapter.encounterWorld = { effectiveEncounters = function(_, _, terrain)
  return { chance = terrain == "water" and .5 or 0, dist = terrain == "water" and {SPECIES_25=1} or {} }
end }
local all = adapter:encounters("ROUTE")
assert(#method(all, "SURF") == 1, "the public contract can add an encounter method absent from raw data")
assert(#method(all, "OLD") == 2, "unsupported rod previews leave the native rod reader intact")
local add = assert(loadfile(root .. "/core/encounters.lua"))()()
local merged, bySpecies = {}, {}
add(merged, bySpecies, {{species=3,min=2,max=5},{species=3}}, "WALK", {50,100}, {mapId="ROUTE"})
add(merged, bySpecies, {{species=3,min=7,max=8}}, "SURF", {100}, {mapId="ROUTE"})
assert(#merged == 1 and merged[1].minLevel == nil and merged[1].maxLevel == nil)
assert(merged[1].appearances[1].minLevel == nil and merged[1].appearances[2].minLevel == 7,
  "unknown preview levels survive aggregation while other appearances keep their own ranges")
print("PASS generic encounter preview: providers, odds, unknown levels, caching, failures and native fallback")
