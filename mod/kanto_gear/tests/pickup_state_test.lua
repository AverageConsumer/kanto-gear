local Pickups = assert(loadfile("mod/kanto_gear/pickup_state.lua"))()
local Progress = assert(loadfile("mod/kanto_gear/achievements.lua"))()
local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
-- These are deliberately not the ROM's IDs or map/item names.
local ITEM, GATE, ROCKET, MOON = 900, 901, 902, 903
local data = { gen2InitialEvents = {flags = {ITEM}}, gen2Maps = {},
  gen2Scripts = { manager = {
    {op="checkevent", event=GATE}, {op="iftrue", script="already_met"},
    {op="writetext"}, {op="waitbutton"}, {op="closetext"},
    {op="setevent", event=GATE}, {op="clearevent", event=ROCKET},
    {op="clearevent", event=ITEM}, {op="end"},
  }, moon_entry = {{op="setevent",event=MOON},{op="endcallback"}},
  moon_dance = {{op="clearevent",event=MOON},{op="setflag",flag=50}},
} }
local flags = {}
local world = {getFlag=function(_,event) return flags[event] == true end}
local policy = Pickups.new(data)
local function state(event, done, available, status, label)
  local d,a,s = policy:state(world,event)
  eq(d,done,label.." collection"); eq(a,available,label.." availability")
  eq(s,status,label.." status")
  return {event=event,done=d,available=a,status=s,untracked=s=="NOT TRACKED",mapId="GYM"}
end
flags[ITEM] = true
local locked = state(ITEM,false,false,"LATER","new game")
local function area(row, visited)
  return Progress.build({{id="CITY",maps={"GYM"}}}, function()
    return {sections={{rows={}},{rows={}},{rows={row}}}}
  end, {gen2=true,save={},mapId="START",visited=visited and {GYM=true} or {},
    flag=function(event) return world:getFlag(event) end}).areas[1]
end
eq(area(locked).tier,"none","locked flag cannot grant visit credit")
eq(#Progress.visibleRows(area(locked),3,"vanilla"),0,"no hidden spoiler from initial flag")
eq(area(locked,true).tier,"bronze","visiting does not collect a locked item")
flags[GATE],flags[ITEM] = true,false
state(ITEM,false,true,nil,"manager unlock / full bag")
flags[ITEM] = true
local found = state(ITEM,true,false,nil,"successful pickup / handed in")
eq(area(found).tier,"gold","genuine pickup remains proof without visit history")
flags = {[ITEM]=true}
state(ITEM,false,false,"LATER","older pre-quest save, same policy cache")
flags = {[MOON]=true}
local moon = state(MOON,false,false,"NOT TRACKED","map-entry Moon Stone reset")
eq(area(moon).tier,"none","resettable flag cannot grant a stamp")
eq(area(moon,true).tier,"bronze","ambiguous pickup cannot complete an area")
flags[MOON]=false
state(MOON,false,true,"NOT TRACKED","Moon Stone spawned by dance")
flags[MOON]=true
state(MOON,false,false,"NOT TRACKED","Moon Stone pickup indistinguishable from later map entry")
state(950,false,true,nil,"ordinary unfound item")
flags[950]=true
state(950,true,false,nil,"ordinary collected item")
state(0,false,true,"NOT TRACKED","temporary flag")
state(65535,false,true,"NOT TRACKED","sentinel flag")
state(nil,false,false,"NOT TRACKED","absent flag")
local d,a,s=policy:state({getFlag=function() return nil end},ITEM)
eq(d,false,"unavailable host flag is not completion");eq(a,false,"unavailable host flag is not usable")
eq(s,"NOT TRACKED","unavailable host flag remains unknown")
-- Missing scripts must never make a seeded flag sufficient proof.
policy=Pickups.new({gen2InitialEvents={flags={ITEM}}})
flags={[ITEM]=true}
state(ITEM,false,false,"NOT TRACKED","unknown seeded pickup")
-- Unknown additional paths or resetting the gate invalidate the inference.
for _, change in ipairs({
  {{op="clearevent",event=GATE}},
  {{op="clearevent",event=ITEM}},
  {{op="setevent",event=ITEM}},
}) do
  data.gen2Scripts.modification=change
  policy=Pickups.new(data); flags={[ITEM]=true,[GATE]=true}
  state(ITEM,false,false,"NOT TRACKED","modified script no longer proves pickup")
end
data.gen2Scripts.modification=nil
-- Inline map scripts use the same rules; script names and table order do not matter.
data.gen2Maps={CUSTOM={objects={{scriptKey=data.gen2Scripts.manager}},
  callbacks={{scriptKey=data.gen2Scripts.moon_entry}}}}
data.gen2Scripts={}
policy=Pickups.new(data);flags={[ITEM]=true}
state(ITEM,false,false,"LATER","inline unlock")
flags[MOON]=true
state(MOON,false,false,"NOT TRACKED","inline callback")
print(checks .. " checks passed (pickup collection versus availability)")
