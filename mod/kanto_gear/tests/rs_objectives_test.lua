local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local fixture = dofile(path .. "/tests/rs_native_test.lua")
local a, session, model, C = fixture.adapter, fixture.session, fixture.progress, fixture.constants
local T = require("tests.modkit")
local prefix, Flags = a.profile.map.enginePrefix, a.Flags
local Schema = require("src.core.game3.save_schema_firered")
local Json = require("src.import.canonical_json")
local function flag(id, value) Flags.setFlag(session, nil, id, value == true) end
local function reward(map, receipt)
  for _, row in ipairs(model:rows({ prefix .. map })[4]) do
    if row.event == receipt then return row end
  end
  error("missing native gift " .. map .. ":" .. receipt)
end
for _, expected in ipairs({
  { "LAVARIDGE_TOWN", 266, 360, true },
  { "MOSSDEEP_CITY_STEVENS_HOUSE", 298, 398 },
  { "ROUTE119_WEATHER_INSTITUTE_2F", 151, 385 },
}) do
  local map, receipt, species, egg = unpack(expected)
  local row = reward(map, receipt)
  T.eq(row.species, species, "native gift species")
  T.eq(row.isEgg == true, egg == true, "native egg identity")
  if row.hideEvent and row.hideEvent >= 0x20 then flag(row.hideEvent, false) end
  session.party = { { species = 277, level = 5 } }
  a:refresh()
  a.save.pokedex.caught[species] = true
  T.check(not reward(map, receipt).done, "caught elsewhere does not forge an NPC receipt")
  T.check(reward(map, receipt).available, "native gift ready with party space")
  for i = 2, 6 do session.party[i] = { species = 277, level = 5 } end
  T.check(not reward(map, receipt).available, "RS gift refuses a full party")
  T.check(reward(map, receipt).noRoom, "full party has an explicit explanation")
  flag(receipt, true); session.party = {}
  T.check(reward(map, receipt).done, "receipt survives release or hatching")
  local restored = Schema.fromSaveTable(Schema.toSaveTable(session))
  T.check(Flags.getFlag(restored, nil, receipt), "receipt survives native save roundtrip")
  flag(receipt, false)
  T.check(not reward(map, receipt).done, "older save restores incomplete receipt")
end
-- Each native trade has its own receipt and requires the requested partner.
for id in pairs(a.data.maps) do
  for _, source in ipairs(model:catalog(id)[4]) do
    if source.trade then
      session.party = {}; a:refresh()
      local map = id:sub(#prefix + 1)
      T.check(not reward(map, source.event).available, "trade without partner is unavailable")
      session.party = { { species = source.needsSpecies, level = 5 } }; a:refresh()
      T.check(reward(map, source.event).available, "trade with exact native partner is ready")
      flag(source.event, true); session.party = {}; a:refresh()
      T.check(reward(map, source.event).done, "trade receipt survives releasing partner")
      flag(source.event, false)
    end
  end
end
local route, rootFlag = prefix .. "ROUTE111", C:flag("FLAG_HIDE_ROOT_FOSSIL")
local fossilRows = {}
for _, row in ipairs(model:rows({route})[2]) do
  if row.event == rootFlag then fossilRows[#fossilRows + 1] = row end
end
T.eq(#fossilRows, 1, "one fossil choice, never two required pickups")
T.eq(fossilRows[1].itemId, nil, "shared receipt cannot pretend to identify the chosen fossil")
flag(rootFlag, true); flag(C:flag("FLAG_HIDE_CLAW_FOSSIL"), true)
for _, row in ipairs(model:rows({route})[2]) do
  if row.event == rootFlag then T.check(row.done, "either native fossil choice completes the goal") end
end
for _, dex in ipairs({252, 255, 258}) do
  a.save.pokedex.caught = { [a.Pokemon.speciesFromNational(dex)] = true }
  local starters = 0
  for _, row in ipairs(model:pokemon({prefix .. "ROUTE101"})) do
    if row.label:find(" / ", 1, true) then starters = starters + 1; T.check(row.done, "either starter completes its choice") end
  end
  T.eq(starters, 1, "only one required starter choice")
end
local before = Json.encode(Schema.toSaveTable(session))
model:rows({route}); model:pokemon({route})
T.eq(Json.encode(Schema.toSaveTable(session)), before, "objective queries never alter the save")
T.finish("Ruby/Sapphire objective receipts")
