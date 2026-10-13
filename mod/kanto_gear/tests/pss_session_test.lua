-- Offline integration: real host Client / Room / relay / protocol / native Flow.
-- Imported datasets and the native permission gate are checked separately by
-- runtime tests. Here only profiles and interactive presenters are fixtures.
package.path = "./?.lua;./?/init.lua;" .. package.path
love = require("tests.love_stub")
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local Session = assert(loadfile(path .. "/features/pss_session.lua"))()
local Relay = require("tests.support.fake_relay")
local Caps = require("src.online.union.Caps")
local Pss = assert(loadfile(path .. "/features/pss.lua"))()
local passed = 0
local function check(v, msg) assert(v, msg); passed = passed + 1 end
local clock = 0
love.timer.getTime = function() return clock end
local function world()
  local relay, clients, sessions = Relay.new({clock=function() return clock end}), {}, {}
  local w = { relay=relay, clients=clients, sessions=sessions }
  function w:pump()
    for _=1,6 do
      relay:pump()
      for _, c in ipairs(clients) do c.update(0) end
      for _, s in ipairs(sessions) do s:tick() end
    end
  end
  function w:add(version, gen)
    package.loaded["src.online.Client"] = nil
    local c = require("src.online.Client")
    c.reset()
    local id = ("%08x"):format(#clients+1)
    local seat = relay:seat(id, version:upper())
    c.configure({relayAddress="offline-fixture",connect=function() return seat.transport end})
    c.connect({name=version:upper(), profiles={}})
    clients[#clients+1] = c
    local game = {generation=gen, data={}, save={player={name=version:upper()},party={{}}}}
    local ow = {player={moving=false},scriptMoves={},pendingScripts={}}
    game.stack = {top=function() return gen==1 and ow or nil end}
    game.overworld, game.world = ow, ow
    function ow:busy() return self.locked end
    if gen==3 then
      game.phase,game.session="field",{name=version:upper(),party={{}}}
      package.loaded["src.ui.game3.stack"] = {busy=function() return game.modal end}
      package.loaded["src.core.game3.field"] = {isLocked=function() return game.locked end}
      package.loaded["src.core.game3.player"] = ow.player
    end
    local identity=function() return {name=version:upper(),version=version,generation=gen} end
    local s = Session.new(game, identity, c)
    local fp="1234567890abcdef"
    function s:context()
      return {game=game,version=version,name=version:upper(),gen=gen,
        profile={engine=gen,version=version,engineVersion="0.0.0-dev",apiVersion=2,
          fingerprint=fp,rulesetId=gen==3 and "g3_single" or "union",kind="vanilla"},
        vanillaFingerprint=fp,gameplayMods=game.blocked==true}
    end
    sessions[#sessions+1]=s
    return s,c,seat,id
  end
  return w
end
local originalOpen,originalTrade = package.loaded["src.ui.union.prep.Open"],package.loaded["src.ui.union.prep.OpenTrade"]
local opened = {}
package.loaded["src.ui.union.prep.Open"]={screen=function(act) opened[#opened+1]=act end}
package.loaded["src.ui.union.prep.OpenTrade"]={trade=function(act) opened[#opened+1]=act end}
for _,pair in ipairs({{"red",1,"crystal",2},{"gold",2,"firered",3},{"emerald",3,"blue",1}}) do
  local w=world()
  local a,ca,sa,aid=w:add(pair[1],pair[2])
  local b,cb,sb,bid=w:add(pair[3],pair[4])
  w:pump()
  check(not ca.plaza() and not cb.plaza(),"viewing does not join or advertise readiness")
  a:enable(true);b:enable(true);w:pump()
  check(a.ready and b.ready,"both generations join remotely and become ready")
  check(a:canInvite(bid) and b:canInvite(aid),"shared room members are inviteable")
  check(not ca.room() and not cb.room(),"joining never starts an activity or changes map")
  local count=#w.relay.log
  for _=1,100 do a:tick();b:tick() end
  w:pump()
  check(#w.relay.log==count,"unchanged snapshots generate no network polling")
  a.game.overworld.player.moving=true;a:tick();w:pump()
  check(not a.ready and not b:canInvite(aid),"unsafe movement is not advertised ready")
  a.game.overworld.player.moving=false;w:pump()
  check(a.ready,"stopping restores ready without reconnect")
  check(a:invite(bid,"battle"),"battle invite uses the host relay")
  check(not a:invite(bid,"trade"),"double tap cannot create a second invite")
  w:pump()
  check(b.incoming and b.incoming.mode=="battle" and b.incoming.fromId==aid,"peer receives native invitation")
  check(not b:reply("not-the-invite",true),"stale accept cannot accept another invitation")
  if pair[4]==3 then b.game.locked=true
  else b.game.overworld.locked=true;b.game.overworld.player.moving=true end
  check(not b:reply(b.incoming.id,true),"accept is revalidated against current game state")
  b.game.locked=false;b.game.overworld.locked=false;b.game.overworld.player.moving=false
  check(b:reply(b.incoming.id,true),"accept succeeds when safely idle")
  w:pump()
  check(a.pending.room and a.pending.room==b.pending.room,"both own the accepted room id")
  local before=#opened
  a:tick();b:tick()
  check(#opened==before,"render refresh never opens native menus")
  a:step();b:step()
  check(#opened==before+2 and a.activity and b.activity,"update hands both seats to native battle prep")
  a:step();b:step()
  check(#opened==before+2,"handoff is exactly once")
  check(a:blocked() and not a.ready,"active prep blocks disconnect and availability")
  -- Native Flow constructs the real negotiated session, with the same room and transport.
  local Flow=require("src.ui.union.Flow")
  Flow.seams.client=ca
  a.activity.battlePrep={ruleset={id="g3u",gen=3},records={},team={}}
  local flow=assert(Flow.session(a.activity,pair[2]))
  check(flow.net==ca.roomSession() and flow.roomId==ca.room().room,"native Flow receives the existing room/transport")
  a.activity:finish("cancel");b.activity:finish("cancel");w:pump()
  check(not ca.room() and not cb.room() and a.ready and b.ready,"cancellation returns both seats to remote availability")
  check(a:invite(bid,"trade"),"trade invitation reachable after battle prep")
  w:pump();check(b:reply(b.incoming.id,false),"decline uses native reply")
  w:pump();check(not a.pending and not b.pending and not ca.room(),"decline creates no room")
  check(a:invite(bid,"trade"),"trade can be invited again")
  w:pump();b:reply(b.incoming.id,true);w:pump();a:step();b:step()
  check(a.activity.mode=="trade" and b.activity.mode=="trade","trade is delegated to native controller")
  a.activity:finish("cancel");b.activity:finish("cancel");w:pump()
  local beforeProfiles=ca.profiles()
  a:close();w:pump()
  check(ca.state()=="online" and not ca.plaza(),"teardown leaves owned plaza but preserves host connection")
  check(ca.profiles()==beforeProfiles,"remote membership never replaces existing host profiles")
  b:close();ca.disconnect();cb.disconnect()
end
do
  local w=world();local a,c,seat=w:add("red",1);w:pump()
  a.game.blocked=true;a:enable(true);w:pump()
  check(not a.ready and not c.plazaJoinInfo("union"),"gameplay blockers are never bypassed")
  check(a.notice=="ONLINE PLAY UNAVAILABLE","unsupported play has visible reason")
  a.game.blocked=false
  local foreign={engine=1,version="red",fingerprint="1234567890abcdef",rulesetId="union"}
  c.joinPlaza("union",foreign,{name="RED",version="red"},40)
  local join=c.plazaJoinInfo("union")
  check(not a:enable(true),"existing physical session cannot be stolen")
  a:close()
  check(c.plazaJoinInfo("union")==join,"teardown preserves foreign plaza membership")
end
do
  local w=world();local a,c=w:add("red",1);local b,cb,_,bid=w:add("crystal",2);w:pump()
  a:enable(true);b:enable(true);w:pump()
  a:invite(bid,"trade");w:pump()
  for _,inv in pairs(w.relay.invites) do w.relay:closeInvite(inv,"expired") end
  w:pump()
  check(not a.pending,"expired invitations unlock actions")
  -- A native room may replace our join while we are in the background.
  c.joinPlaza("union",a.room.profile,a.room.avatar,40,{xgen=1,caps=a.room.caps})
  local native=c.plazaJoinInfo("union");a:tick();a:close()
  check(c.plazaJoinInfo("union")==native,"foreign replacement is never left or overwritten")
end
do
  local w=world();local a,ca,sa,aid=w:add("red",1);local b,cb,sb,bid=w:add("crystal",2);w:pump()
  a:enable(true);b:enable(true);w:pump()
  check(a:invite(bid,"battle") and b:invite(aid,"battle"),"simultaneous invitations can cross in flight")
  -- Interleave both requests before either subsequent busy presence packet.
  for _,seat in ipairs({sa,sb}) do
    for i,msg in ipairs(seat.transport.outbox) do
      if msg.type=="invite" then
        table.remove(seat.transport.outbox,i);w.relay:handle(seat,msg);break
      end
    end
  end
  w:pump()
  a:step();b:step()
  check(a.activity and b.activity and a.activity.roomId==b.activity.roomId,"crossed invitations open one shared native session")
  a.activity:finish("cancel");b.activity:finish("cancel");w:pump()
end
do
  local w=world();local a,ca,_,aid=w:add("red",1);local b,cb,_,bid=w:add("crystal",2);w:pump()
  a:enable(true);b:enable(true);w:pump()
  a:invite(bid,"trade");w:pump()
  b:reply(b.incoming.id,true)
  -- Accept has reached the relay, but neither Client has consumed its reply.
  w.relay:pump();a:close();w:pump()
  check(not ca.room() and not a.activity,"late acceptance after uninstall cannot orphan or open a session")
  check(ca.state()=="online","late acceptance cleanup preserves shared connection")
  b:close()
end
do
  local w=world();local a,ca,_,aid=w:add("red",1);local b,cb,_,bid=w:add("crystal",2);w:pump()
  a:enable(true);b:enable(true);w:pump()
  a:invite(bid,"trade");w:pump();b:reply(b.incoming.id,true)
  b:close();w:pump()
  check(not cb.room() and not b.activity,"late room after accepting then uninstalling is safely left")
  a:close()
end
do
  local w=world();local a,ca,_,aid=w:add("red",1);local b,cb,_,bid=w:add("crystal",2);w:pump()
  a:enable(true);b:enable(true);w:pump()
  a:invite(bid,"trade");w:pump();b:reply(b.incoming.id,true);w:pump();a:step();b:step()
  local act=a.activity;a:close()
  check(ca.room()~=nil and a.activity==act,"teardown does not interrupt an active native trade")
  act:finish("traded");w:pump()
  check(not ca.room() and not ca.plaza() and ca.state()=="online","native completion releases retired service membership")
  b.activity:finish("cancel");b:close()
end
package.loaded["src.ui.union.prep.Open"],package.loaded["src.ui.union.prep.OpenTrade"]=originalOpen,originalTrade
print("Silph Connect sessions: "..passed.." checks passed")
