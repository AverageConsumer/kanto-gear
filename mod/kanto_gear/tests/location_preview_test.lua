local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local Location = assert(loadfile(root .. "/models/location_preview.lua"))()
for generation = 1, 3 do
  local maps = { CITY = { width = 20, height = 20, outdoor = true, warps = {
    { x = 7, y = 9, destMap = "FLOOR_1" }, { x = 8, y = 9, destMap = "FLOOR_1" },
    { x = 7, y = 9, destMap = "FLOOR_1" }, { x = 15, y = 9, destMap = "OTHER_HOUSE" },
    { x = -1, y = 0, destMap = "FLOOR_5" }, { x = 1000, y = 0, destMap = "FLOOR_5" },
    { x = 0 / 0, y = 0, destMap = "FLOOR_5" },
    { x = 0, y = 0, destMap = "FLOOR_5", destWarp = 255 } } },
    OTHER_HOUSE = { width = 10, height = 10 },
    DISCONNECTED = { width = 10, height = 10, warps = { { x = 0, y = 0, destMap = "LAST_MAP" } } } }
  for floor = 1, 5 do
    maps["FLOOR_" .. floor] = { width = 10, height = 10, warps = {
      { x = 1, y = 1, destMap = floor == 5 and "FLOOR_1" or "FLOOR_" .. (floor + 1) },
      { x = 2, y = 2, destMap = "LAST_MAP" } } }
  end
  local target = { mapId = "FLOOR_5", x = 3, y = 4, gift = true }
  local door = Location.entrance(maps, target, generation, "CITY")
  T.eq(door.mapId, "CITY", "Gen " .. generation .. " five floors resolve to outdoor map")
  T.eq(door.x, 7, "building doorway, not NPC coordinates")
  T.eq(door.y, 9, "building doorway y")
  T.eq(door.depth, 5, "full floor chain is followed")
  T.eq(#door.points, 2, "two-tile entrance is marked once per door cell")
  T.eq(target.x, 3, "exact indoor position is retained")
  T.eq(target.points, nil, "source row is never modified")
  T.eq(maps.CITY.warps[1].points, nil, "warp definitions stay untouched")
  T.eq(Location.entrance(maps, { mapId = "CITY" }, generation), nil, "outdoor finds stay on their own map")
  T.eq(Location.entrance(maps, { mapId = "DISCONNECTED" }, generation), nil, "dynamic exit never borrows the player's last map")
  T.eq(Location.entrance(maps, { mapId = "MISSING" }, generation), nil, "missing mod map has no invented doorway")
  maps.OTHER_CITY = { width = 20, height = 20, outdoor = true,
    warps = { { x = 3, y = 5, destMap = "FLOOR_5" } } }
  T.eq(Location.entrance(maps, target, generation, "CITY").mapId, "CITY", "prefer valid entrance on current outdoor map")
  T.eq(Location.entrance(maps, target, generation, "UNKNOWN").mapId, "OTHER_CITY", "otherwise choose shortest map chain")
  maps.OTHER_CITY.warps[1].destMap = "OTHER_HOUSE"
  T.eq(Location.entrance(maps, target, generation, "UNKNOWN").mapId, "CITY", "new lookup respects changed map links")
end
T.check(Location.outdoor({ tileset = "OVERWORLD" }, 1), "Gen1 native outdoor tileset")
T.check(not Location.outdoor({ tileset = "MART" }, 1), "Gen1 department store roof still resolves through its building")
T.check(Location.outdoor({ environment = "ROUTE" }, 2), "Gen2 native route environment")
T.check(not Location.outdoor({ environment = "CAVE" }, 2), "Gen2 caves resolve to their entrance")
T.check(not Location.outdoor({ mapType = 4, environment = "TOWN" }, 3), "Gen3 native cave type overrides generic environment")
T.check(not Location.outdoor({ mapType = 8 }, 3), "Gen3 indoor type")
T.check(Location.outdoor({ mapType = 3 }, 3), "Gen3 native route type")
T.check(not Location.outdoor({ outdoor = false, tileset = "OVERWORLD" }, 1), "authored map property wins")
T.eq(Location.floor("SILPH_CO_7F"), "7F", "upper floor caption")
T.eq(Location.floor("ROCKET_HIDEOUT_B2F"), "B2F", "basement caption")
T.eq(Location.floor("FR_CELADON_CITY_CONDOMINIUMS_ROOF_ROOM"), "ROOF", "roof room caption")
T.eq(Location.floor("ROUTE_1"), nil, "route number is never a floor")
for _, native in ipairs({ { env = "KANTO_GEAR_NATIVE_GEN1", gen = 1, cases = {
  { "COPYCATS_HOUSE_2F", "SAFFRON_CITY" }, { "CELADON_MART_ROOF", "CELADON_CITY" },
  { "SILPH_CO_7F", "SAFFRON_CITY" }, { "VERMILION_OLD_ROD_HOUSE", "VERMILION_CITY" } } },
  { env = "KANTO_GEAR_NATIVE_GEN2", gen = 2, cases = {
  { "GOLDENROD_DEPT_STORE_5F", "GOLDENROD_CITY" },
  { "OLIVINE_LIGHTHOUSE_6F", "OLIVINE_CITY" }, { "BILLS_FAMILYS_HOUSE", "GOLDENROD_CITY" } } } }) do
  local directory = os.getenv(native.env)
  if directory then
    local maps = dofile(directory .. "/maps.lua")
    for _, case in ipairs(native.cases) do
      local entrance = Location.entrance(maps, { mapId = case[1], x = 1, y = 1 }, native.gen)
      T.eq(entrance and entrance.mapId, case[2], "native entrance: " .. case[1])
    end
  end
end
T.finish("Kanto Gear building entrance previews")
