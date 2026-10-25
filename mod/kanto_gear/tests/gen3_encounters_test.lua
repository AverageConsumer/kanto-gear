-- Compare the read model to the real host's weighted slot picker, using an
-- isolated RNG. No game, save or live encounter hook is executed.
local root=assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local edition=assert(os.getenv("POKEPORT_VERSION"))
local hoenn=edition=="ruby" or edition=="sapphire" or edition=="emerald"
local Gen3={}
assert(loadfile(root.."/adapters/gen3/models/world.lua"))()(Gen3)
local rng=require("src.core.game3.rng")
local Native=require("src.core.game3.encounters")
local originalRandom=rng.Random
local roll=0
rng.Random=function() return roll end
local map="MODDED_ROUTE"
local data={maps={[map]={}},pokemon={}}
for id=1,100 do data.pokemon[id]={name="SPECIES_"..id} end
local area={}
local adapter=setmetatable({hoenn=hoenn,data=data,game={data={gen3Encounters={[map]=area}}}},{__index=Gen3})
local function slots(n)
  local out={}
  for i=1,n do out[i]={species=i%2==1 and 16 or 19,minLevel=2,maxLevel=5} end
  return out
end
local function rows(method)
  local out={}
  for _,row in ipairs(adapter:encounters(map)) do if row.method==method then out[#out+1]=row end end
  return out
end
local function parity(list,weights,method)
  local count=hoenn and #weights or #list
  local total=0
  for i=1,count do total=total+(weights[i] or 1) end
  local actual={}
  for i=0,total-1 do
    roll=i
    local slot=hoenn and list[Native._h.pick_slot_index(weights)] or Native._h.pick_slot(list,weights)
    if slot then actual[slot.species]=(actual[slot.species] or 0)+1 end
  end
  local seen,totalOdds=0,0
  for _,row in ipairs(rows(method)) do
    assert(actual[row.species],"reader includes a species absent from the native pool")
    assert(math.abs(row.chance-actual[row.species]*100/total)<1e-9,"reader odds differ from the native picker")
    seen=seen+1;totalOdds=totalOdds+row.chance
  end
  local wanted=0;for _ in pairs(actual) do wanted=wanted+1 end
  assert(seen==wanted,"native-selectable species must not be truncated")
  assert(math.abs(totalOdds-100)<1e-9,"method odds must total 100 percent")
end
area.land={rate=20,slots=slots(12)}
assert(#rows("WALK")==2)
parity(area.land.slots,Native._h.LAND_WEIGHTS,"WALK")
area.land.slots[3].species=1
area.land.slots[5].species=4
area.land.slots[7].species=7
assert(#rows("WALK")==5,"there is no official Route 1 two-species expectation")
parity(area.land.slots,Native._h.LAND_WEIGHTS,"WALK")
area.land.slots=slots(12)
for _,id in ipairs({1,4,7}) do area.land.slots[#area.land.slots+1]={species=id,minLevel=3,maxLevel=8} end
assert(#rows("WALK")== (hoenn and 2 or 5),"extra slots follow the edition's native rules")
parity(area.land.slots,Native._h.LAND_WEIGHTS,"WALK")
if not hoenn then
  area.land.slots={ {species=1,minLevel=2,maxLevel=2},{species=4,minLevel=3,maxLevel=4},{species=7,minLevel=5,maxLevel=5} }
  parity(area.land.slots,Native._h.LAND_WEIGHTS,"WALK")
end
for _,pool in ipairs({{"water","SURF"},{"rocks","ROCK SMASH"}}) do
  local list=slots(5);list[6]={species=25,minLevel=6,maxLevel=9}
  area[pool[1]]={rate=15,slots=list}
  assert(#rows(pool[2])==(hoenn and 2 or 3),"extended water/rock pools use the correct native rule")
  parity(list,Native._h.WATER_WEIGHTS,pool[2])
end
area.fishing={slots={}}
for i=1,11 do area.fishing.slots[i]={species=i+30,minLevel=5,maxLevel=8} end
assert(#rows("OLD")==2 and #rows("GOOD")==3 and #rows("SUPER")==5,"rod windows remain separate")
for _,row in ipairs(adapter:encounters(map)) do assert(row.species~=41,"an extra fishing slot must not leak into a different rod window") end
area.land={rate=20,slots=slots(12)}
assert(#rows("WALK")==2,"live table replacement is read without a stale species count")
area.land.slots[1].species=25
assert(#rows("WALK")==3,"in-place encounter edits are read on the next snapshot")
assert(#area.land.slots==12 and area.land.slots[1].species==25,"reading never modifies mod encounter data")
rng.Random=originalRandom
print("PASS native encounter-picker parity, modded slot counts, rod isolation and live edits: "..edition)
