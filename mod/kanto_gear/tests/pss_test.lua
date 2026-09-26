-- Run from the Recomp root. Exercises its real Client/Connect with a local relay.
package.path = "./?.lua;./?/init.lua;" .. package.path
love = require("tests.love_stub")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local Pss = assert(loadfile(path .. "/pss.lua"))()
local Client = require("src.online.Client")
local Connect = require("src.online.Connect")
local Relay = require("tests.support.fake_relay")
local passed = 0
local function check(value, message)
  assert(value, message); passed = passed + 1
end
-- Keep account/name storage in memory, never touch the user's account.
local stored = {}
package.loaded["src.sync.SyncState"] = {
  load = function() return stored end,
  update = function(fn) fn(stored) end,
  linked = function() return false end,
}
for _, identity in ipairs({
  {name="RED", version="red", generation=1},
  {name="BLUE", version="blue", generation=1},
  {name="YELLOW", version="yellow", generation=1},
  {name="GOLD", version="gold", generation=2},
  {name="SILVER", version="silver", generation=2},
  {name="GOLD", version="crystal", generation=2},
  {name="RED", version="firered", generation=3},
  {name="LEAF", version="leafgreen", generation=3},
}) do
  Client.reset(); Connect.reset()
  local relay = Relay.new()
  local seat = relay:seat("self", "ME")
  local connections = 0
  Client.configure({ relayAddress="local-test", connect=function()
    connections = connections + 1; return seat.transport
  end })
  local model = Pss.new({ resolve=function() return Client, Connect end,
    identity=function() return identity end })
  model:open()
  check(model.state=="offline" and connections==0, "opening never connects automatically")
  model:action("connect")
  model:action("connect")
  check(connections==1, "double tap creates one connection")
  relay:pump(); Client.update(0); model:refresh()
  check(model.state=="online", "real host handshake completes")
  check(#Client.profiles()==0, "passive app advertises no battle profile")
  check(Client.presence().version==identity.version, "presence has correct edition")
  check(Client.presence().engine==identity.generation, "presence has correct generation")
  local rows={{id="self",name="ME"}, {id="hidden",name="OFFLINE",online=false}}
  for i=1,8 do rows[#rows+1]={id="p"..i,name="TRAINER"..i,
    version=i==1 and "firered" or "crystal",where="game",status="busy"} end
  relay:to(seat,{type="lobby_list",online=25,entries=rows})
  Client.update(0); check(model:refresh(), "lobby event invalidates visible list")
  check(#model.rows==8 and model.pages==2, "list excludes self/offline and paginates")
  check(model.rows[1].version=="firered", "server edition reaches cards")
  local outCount=#seat.transport.outbox
  local idleUnchanged=true
  for _=1,100 do if model:refresh() then idleUnchanged=false end end
  check(idleUnchanged,"idle refresh reuses cached list")
  check(#seat.transport.outbox==outCount, "no polling network traffic")
  local snapshot, listener = model.rows, model.listener
  for _=1,100 do model:open() end
  check(model.rows==snapshot and model.listener==listener, "widget draws reuse one observer and snapshot")
  model:tick(1)
  relay:to(seat,{type="lobby_delta",changed={{id="p1",name="TRAINER1",
    version="firered",where="game",status="battling"}}})
  Client.update(0)
  check(not model:tick(1.1) and model.rows==snapshot,"background updates coalesce within one refresh interval")
  check(model:tick(1.25) and model.rows[1].status=="battling", "background tick receives changed player status")
  relay:to(seat,{type="lobby_delta",added={{id="new",name="AAA",where="launcher",status="busy"}},removed={"p2"}})
  Client.update(0); model:tick(1.5)
  check(#model.rows==8 and model.rows[1].id=="new", "background join and departure update count and names")
  check(connections==1 and #seat.transport.outbox==outCount, "background observation adds no connection or network polling")
  model:action("page",1); check(model.page==2,"second page reachable")
  model:action("player","p8"); check(model.selectedRow.id=="p8","detail follows stable player id")
  relay:to(seat,{type="lobby_delta",removed={"p7","p8"}})
  Client.update(0); model:refresh()
  check(model.page==1 and #model.rows==6,"departure clamps last page")
  check(model.selected=="p8" and not model.selectedRow,"departed player isn't silently replaced")
  model:action("back"); check(not model.selected,"detail back keeps list")
  Client.setProfiles({{engine=3,version="firered",fingerprint="kept"}})
  Client.setPresence({where="union",status="trading"})
  model:action("connect")
  check(connections==1 and Client.profiles()[1].fingerprint=="kept", "existing host profile survives connect tap")
  check(Client.presence().where=="union", "existing host presence survives")
  model:action("disconnect")
  check(Client.state()=="online" and model.inUse,"active activity blocks disconnection")
  model:close()
  model.stale=false
  relay:to(seat,{type="lobby_delta",removed={"p6"}}); Client.update(0)
  check(not model.stale,"closing removes listeners")
  check(not model:tick(10),"released observer does not perform background work")
  check(Client.state()=="online","closing keeps host connection")
  model:open(); check(#model.rows==5,"reopening reads latest host snapshot")
  Client.setPresence({where="game",status="busy"})
  model:action("disconnect")
  check(model.state=="offline" and #model.rows==0,"explicit disconnect clears visible list")
  model:close()
end
Client.reset(); Connect.reset()
local model=Pss.new({resolve=function() return Client,Connect end,
  identity=function() return {name="RED",version="red",generation=1} end})
Client.configure({relayAddress="local-test",connect=function() return nil,"no transport" end})
model:open(); model:action("connect")
check(model.error and model.state=="error","transport failure is visible")
local recovery=Relay.new()
local recovered=recovery:seat("self","ME")
Client.configure({connect=function() return recovered.transport end})
Connect.start({trainerName="RED"})
recovery:pump(); Client.update(0); model:refresh()
check(model.state=="online" and model.error==nil,"host recovery clears a previous app error")
model:close()
Connect.disconnect()
local probes=0
local missing=Pss.new({resolve=function() probes=probes+1; error("older host") end,identity=function() return {} end})
missing:open(); missing:action("connect")
check(missing.state=="unavailable","missing host API fails safely")
for _=1,100 do missing:open() end
check(probes==1,"unsupported widget does not repeatedly resolve missing host APIs")
print("PSS: "..passed.." checks passed")
