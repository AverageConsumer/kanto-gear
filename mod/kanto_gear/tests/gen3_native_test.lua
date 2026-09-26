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
local function count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end
local function clone(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[k] = clone(v) end
  return out
end
local function equal(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
local adapter = Gen3.new(raw)
local Summary = dofile(root .. "/summary.lua")
local natureFixture = Schema.newGame({ version=edition, name="NATURE", rngSeed=2 })
Party.giveMon(natureFixture, 1, 15)
local natureMon = natureFixture.party[1]
for personality = 0, 24 do
  natureMon.personality = personality
  local projected = adapter:mon(natureMon)
  local view = Summary.view({ screenId="Gen3SummaryMenu", mon=projected, page=1 }, adapter:gameView())
  check(view.nature == select(2, adapter.Summary.nature(natureMon)), "nature matches native personality")
  check(view.ability == P.abilityName(P.abilityId(1,personality)), "ability matches native species/personality")
end
local abilityId = adapter:mon(natureMon).ability
local originalName = P._abilityNames[abilityId]
P._abilityNames[abilityId] = "Translated ability"
local translated = Summary.view({ screenId="Gen3SummaryMenu", mon=adapter:mon(natureMon), page=1 }, adapter:gameView())
check(translated.ability == "Translated ability", "summary respects live ability name translations")
check(translated.abilityDescription == adapter.Summary.abilityDescription(abilityId,originalName),
  "translated ability name does not change description identity")
P._abilityNames[abilityId] = originalName
check(count(adapter.data.pokemon) == 386, "386 unique National Dex entries, no internal holes")
check(adapter.data.pokemon[410].dex == 386, "Deoxys internal ID retained")
check(adapter.data.pokemon[410].baseStats.attack == (edition == "firered" and 180 or 70), "edition-specific Deoxys")
check(adapter.data.pokemon[1].types[1] == "GRASS", "numeric type normalized")
check(adapter.data.pokemon[1].learnset[1].move == "TACKLE", "packed learnset normalized")
check(adapter.data.moves.TACKLE.name == "TACKLE", "native move display name")
check(adapter.data.items[341].teaches == "SURF", "TM/HM field method from native machine table")

Bag.add(s.bag, 4, 35)
Bag.add(s.bag, 2, 7)
Bag.add(s.bag, 13, 9)
Bag.add(s.bag, 139, 2)
Bag.add(s.bag, 341, 1) -- HM03 Surf
Party.giveMon(s, 1, 15)
local mon = s.party[1]
mon.ivs.spa, mon.evs.spa = 31, 252
P.applyStats(mon)
s.money = 123456
local before = clone(s)
local save = adapter:refresh()
check(save.money == 123456 and raw.save.money ~= save.money, "live money, not last serialization")
check(save.inventory.POKE_BALL == 35 and save.inventory[4] == 35, "numeric and named bag lookup")
local total = 0
for id, qty in pairs(save.inventory) do
  if adapter.data.items[id].pocket == "BALL" then total = total + qty end
end
check(total == 42, "42 balls, no alias double count")
check(adapter.data.items[139].pocket == "BERRY", "berries retain their own pocket")
local view = save.party[1]
check(type(view.moves[1]) == "table" and view.moves[1].pp == mon.pp[1], "native PP arrays normalized")
check(view.stats.specialAttack == mon.spAtk and view.stats.specialDefense == mon.spDef, "separate special stats")
check(view.ivs.spa == 31 and view.evs.spa == 252 and view.dvs == nil, "Gen3 IVs and EVs are not Gen2 DVs")
check(view.gender == P.gender(mon.species, mon.personality), "native gender rules")
check(view.ability == P.abilityId(mon.species, mon.personality), "native ability rules")
check(view.shiny == P.isShiny(mon), "native shiny rules")
local Summary = assert(loadfile(root .. "/summary.lua"))()
check(Summary.view({ mon = view, page = 1 }, { save = save, data = adapter.data }) ~= nil, "normalized mon accepted by shared summary")
local Habitats = assert(loadfile(root .. "/habitats.lua"))()
check(type(Habitats.methods(save, adapter.data.items, false)) == "table", "normalized mon accepted by habitat helper")

s.storage.boxes[14].mons[30] = mon
local boxes = adapter:boxes()
check(#boxes == 14 and boxes[14].entries[1].slot == 30, "sparse final PC slot preserved")
check(boxes[14].entries[1].mon == view, "stable mon view in party and box")
s.storage.boxes[14].mons[30] = nil
check(equal(s, before), "all read models leave native session unchanged")
mon.pp[1], mon.hp = 0, 1
adapter:refresh()
check(save == adapter.save and save.party[1] == view and view.hp == 1 and view.moves[1].pp == 0, "stable identity with live HP and PP")
Bag.set(s.bag, 4, 0)
adapter:refresh()
check(save.inventory[4] == nil and save.inventory.POKE_BALL == nil, "removed stack disappears")

local Dex = require("src.core.game3.dex")
Dex.setCaught(s.dex, 410)
adapter:refresh()
check(save.pokedex.caught[410] and not save.pokedex.caught[386], "catch internal ID is not National ID")
check(not adapter:methods().SURF, "HM ownership is not immediate field usability")
check(adapter:habitatMethods().SURF == "NEED BADGE", "planning knows owned HM but requires badge")
mon.moves[1] = 57
check(not adapter:methods().SURF, "Surf needs badge")
Flags.setFlag(s, nil, 0x824, true)
check(adapter:methods().SURF and adapter:badge(5), "Soul badge permits Surf")
check(adapter:habitatMethods().SURF == nil, "planning permits usable HM")
mon.isEgg = true
check(not adapter:methods().SURF, "egg cannot supply field move")
mon.isEgg = nil
mon.moves[1] = 33
Bag.set(s.bag, 341, 0)
adapter:refresh()
check(adapter:habitatMethods().SURF == "NEED SURF", "planning drops unavailable move")
s.storage.boxes[14].mons[30] = clone(mon)
s.storage.boxes[14].mons[30].moves[1] = 57
check(not adapter:methods().SURF and adapter:habitatMethods().SURF == nil, "boxed Surf affects planning only, including sparse final slot")
s.storage.boxes[14].mons[30] = nil
Bag.add(s.bag, "OLD_ROD", 1)
adapter:refresh()
check(adapter:methods().OLD, "rod in bag usable")
Bag.set(s.bag, "OLD_ROD", 0)
adapter:refresh()
check(not adapter:methods().OLD, "rod absent from bag unavailable")

local mapCount, rowCount = 0, 0
for id in pairs(maps) do
  local totals = {}
  for _, row in ipairs(adapter:encounters(id)) do
    check(row.mapId == id and row.minLevel <= row.maxLevel and adapter.data.pokemon[row.species], "valid encounter location, level and species")
    totals[row.method] = (totals[row.method] or 0) + row.chance
    rowCount = rowCount + 1
  end
  for method, totalOdds in pairs(totals) do check(totalOdds == 100, id .. " " .. method .. " totals 100%") end
  mapCount = mapCount + 1
end
local wanted, excluded = edition == "firered" and 43 or 69, edition == "firered" and 69 or 43
local found = false
for _, row in ipairs(adapter:encounters("FR_ROUTE_24")) do
  if row.species == wanted then found = true end
  check(row.species ~= excluded, "other edition's Route 24 exclusive absent")
end
check(found, "Route 24 edition exclusive present")
check(#adapter:encounters("3:19") == 0, "numeric map alias cannot create a duplicate habitat")
raw.session = nil
check(adapter:refresh() == nil and adapter.save == nil, "return to title releases save view")
raw.session = Schema.newGame({ version = edition, name = "NEW", rngSeed = 6789 })
adapter:refresh()
check(adapter.save ~= save and adapter.save.player.name == "NEW" and #adapter.save.party == 0, "new game resets old party and identity")
print(string.format("Gen3 native %s: %d checks passed; %d maps, %d encounter rows", edition, checks, mapCount, rowCount))
