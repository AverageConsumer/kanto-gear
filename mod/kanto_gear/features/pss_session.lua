-- Remote Union Room membership, using the host's connection and native prep.
-- No map warp, transport pump, battle engine or save/trade implementation here.
local Room = require("src.online.union.Room")
local Caps = require("src.online.union.Caps")
local Participant = require("src.online.union.Participant")
local Policy = require("src.online.xgen.Policy")
local Session = {}
Session.__index = Session

local function running(vm)
  return vm and vm.isRunning and vm:isRunning()
end
local function acceptedRoom(pending, current)
  if not pending then return nil end
  local h = pending.handle
  local id = pending.room or h and h.room
  if not id and h and h.state == "accepted" and h.why == "crossed" and current
      and current.intent == "xg" and (current.mode or current.xg and current.xg.mode) == pending.mode then
    for _, peer in ipairs(current.players or {}) do
      if pending.peer and peer.id == pending.peer.id then return current.room end
    end
  end
  return id
end
function Session.safe(game, gen)
  if not game or game.transitioning or game.battle or game.linkSession then return false end
  -- Game path [Gen 1/2/3]: online entry needs each engines own idle proof; Gen 3 has a global UI stack and field/script locks.
  if gen == 3 then
    if game.phase ~= "field" or not game.session then return false end
    local loaded = package.loaded
    local stack = loaded["src.ui.game3.stack"]
    local field = loaded["src.core.game3.field"]
    local player = loaded["src.core.game3.player"]
    local space = loaded["src.core.game3.scripting.space"]
    local warp = loaded["src.core.game3.warp"]
    local battle = loaded["src.core.game3.battle"]
    if not stack or not field or not player then return false end
    return not stack.busy() and not field.isLocked() and not player.moving
      and not (space and (running(space.vm) or running(space._immediateVm)))
      and not (warp and warp.isBusy()) and not (battle and battle.isActive())
  end
  if not game.stack then return false end
  local top = game.stack:top()
  -- Game path [Gen 2 vs Gen 1]: an empty menu stack is idle in Gen 2; Gen 1 requires its overworld on top and no pending scripts.
  if gen == 2 then
    local world = game.world
    return world ~= nil and top == nil and not world:busy()
      and world.player ~= nil and not world.player.moving
  end
  local ow = game.overworld
  return ow ~= nil and top == ow and not ow.transitioning
    and not running(ow.runner) and not next(ow.scriptMoves or {})
    and not next(ow.pendingScripts or {}) and ow.player ~= nil and not ow.player.moving
end

function Session.new(game, identity, client)
  assert(game and type(client) == "table")
  for _, name in ipairs({"invite", "plazaJoinInfo", "state", "room", "roomSession",
      "leaveRoom", "tournament", "group", "direct", "on", "off"}) do
    assert(type(client[name]) == "function", "missing online host interface: " .. name)
  end
  return setmetatable({ game = game, identity = identity, client = client,
    room = Room.new({client = client}), enabled = false, peers = {}, revision = 0 }, Session)
end
function Session:context()
  local id = self.identity()
  local player = self.game.session or self.game.save and self.game.save.player or {}
  return { game = self.game, data = self.game.data, version = id.version,
    name = id.name, trainerId = player.trainerId or player.id,
    gender = player.gender, gen = id.generation }
end
function Session:foreign()
  local c, game = self.client, self.game
  local union = package.loaded["src.core.game3.link.union_room"]
  local link = package.loaded["src.core.game3.link"]
  -- Game path [Gen 3]: a native Union Room/link session already owns the connection; Gear must not start a competing activity.
  if game.unionPresence or (self.identity().generation == 3
      and ((union and union.isActive()) or (link and link.link))) then return true end
  if c.tournament() or c.group() or c.direct() then return true end
  local join = c.plazaJoinInfo("union")
  if join and join ~= self.join then return true end
  local r = c.room()
  local pendingRoom = acceptedRoom(self.pending, r)
  return r ~= nil and r.room ~= pendingRoom
    and (not self.activity or r.room ~= self.activity.roomId)
end
function Session:ownsPlaza()
  return self.join ~= nil and self.client.plazaJoinInfo("union") == self.join
end
function Session:blocked()
  return self.activity ~= nil or self:foreign()
end
function Session:profileValid()
  local ctx = self:context()
  local profile, why = Room.buildProfile(ctx)
  local caps = Caps.compute(ctx)
  if not profile or Caps.empty(caps) then
    self.unavailable = true
    self.notice = (why == "mods" or Caps.gameplayMods(self.game))
      and "RECOMP BLOCKS UI MODS" or "ONLINE PLAY UNAVAILABLE"
    return false, why or "mods"
  end
  self.unavailable = false
  return true
end
function Session:enable(value)
  if self.activity or self.pending then return false end
  if value and self:foreign() then return false end
  self.enabled = value == true
  self.closed = false
  self.notice = nil
  self:tick()
  return true
end
function Session:status(status)
  if self:ownsPlaza() and self.sentStatus ~= status then
    self.room:setStatus(status)
    self.sentStatus = status
  end
end
function Session:hook()
  if self.closedListener then return end
  self.closedListener = function(msg)
    local p = self.pending
    if p and msg.id and msg.id == (p.id or p.handle and p.handle.id) then
      if msg.why == "accepted" or msg.why == "crossed" then p.room = msg.room
      else self.pending = nil; self.notice = "INVITATION CLOSED" end
    end
    if self.closed then self:cleanup() end
  end
  self.client.on("invite_closed", self.closedListener)
  self.roomListener = function() if self.closed then self:cleanup() end end
  self.client.on("room", self.roomListener)
  self.client.on("state", self.roomListener)
end
function Session:tick()
  if self.closed then return end
  local c = self.client
  local pending, current = self.pending, c.room()
  if pending and current then
    local h = pending.handle
    -- Simultaneous invitations are coalesced by the relay. Its "crossed"
    -- response precedes room_state and does not itself carry the room id.
    pending.room = acceptedRoom(pending, current)
    if current.room == (pending.room or h and h.room) then pending.seenRoom = true end
  elseif pending and pending.seenRoom then
    self.pending = nil; self.notice = "INVITATION CLOSED"
  end
  local before = table.concat({tostring(self.ready), tostring(self.room.state),
    tostring(self.notice), tostring(self.pending), tostring(self.activity),
    tostring(self.incoming and self.incoming.id), tostring(self:blocked())}, "|")
  if c.state() ~= "online" then
    self.ready, self.incoming, self.peers = false, nil, {}
    -- The host resends owned plaza membership on reconnect. Do not rejoin it.
    if c.state() ~= "reconnecting" then
      self.join, self.pending = nil, nil
      self.room:unhook(); self.room.state = "idle"
    end
  elseif self:foreign() then
    self.ready, self.incoming, self.peers = false, nil, {}
    if self.join and not self:ownsPlaza() then
      self.room:unhook(); self.room.state = "idle"; self.join = nil
      self.enabled = false
    end
  else
    if self.enabled and not self.join then
      local valid = self:profileValid()
      if valid then
        self:hook()
        local ok = self.room:join(self:context())
        if ok then self.join = c.plazaJoinInfo("union"); self.sentStatus = "idle" end
      end
      if not self.join then self.enabled = false; self.notice = self.notice or "ONLINE PLAY UNAVAILABLE" end
    end
    if self:ownsPlaza() then
      local diff = self.room:poll()
      self.peers = self.room.byId
      if diff.error then
        self.ready = false; self.notice = "ONLINE PLAY UNAVAILABLE"
      else
        self.ready = self.enabled and self.room.state == "joined" and not self.pending
          and not self.activity and Session.safe(self.game, self.identity().generation) or false
      end
      local incoming = not self.pending and not self.activity and self.room:incoming() or {}
      self.incoming = incoming[1]
      if self.pending and self.pending.handle then
        local h = self.pending.handle
        if h.state == "accepted" then self.pending.room = h.room or self.pending.room
        elseif h.state == "closed" then self.pending = nil; self.notice = "INVITATION CLOSED" end
      end
      self:status(self.activity and (self.activity.mode == "trade" and "trading" or "battling")
        or self.ready and "idle" or "busy")
    else self.ready, self.incoming = false, nil end
  end
  local after = table.concat({tostring(self.ready), tostring(self.room.state),
    tostring(self.notice), tostring(self.pending), tostring(self.activity),
    tostring(self.incoming and self.incoming.id), tostring(self:blocked())}, "|")
  if before ~= after then self.revision = self.revision + 1 end
end
function Session:peerCapable(id)
  local p = self.peers[id]
  local caps = p and p.caps
  return p ~= nil and p.online ~= false and not p.legacy and not p.group
    and caps ~= nil and caps.proto == Policy.PROTO and caps.policy == Policy.VERSION
    and not Caps.empty(caps) or false
end
function Session:peerReady(id)
  return self:peerCapable(id) and not Participant.busy(self.peers[id])
end
function Session:canInvite(id)
  return self.ready and not self.incoming and self:peerReady(id)
end
function Session:invite(id, mode)
  self:tick()
  if not self:canInvite(id) or (mode ~= "battle" and mode ~= "trade") then return false end
  if not self:profileValid() then return false end
  local handle = self.room:invite(id, "xg_" .. mode)
  if not handle then self.notice = "INVITATION CLOSED"; return false end
  self.pending = { handle = handle, peer = self.peers[id], mode = mode }
  self:tick()
  return true
end
function Session:reply(id, accept)
  self:tick()
  local incoming = self.incoming
  if not incoming or incoming.id ~= id then return false end
  if accept and (not self.ready or not self:peerCapable(incoming.fromId)
      or not self:profileValid()) then return false end
  if not self.room:reply(id, accept) then return false end
  if accept then
    self.pending = { id = id, peer = incoming.from, mode = incoming.mode }
  end
  self.incoming = nil
  self:tick()
  return true
end
function Session:finish(act, notice)
  if self.activity ~= act then return end
  local r = self.client.room()
  if r and r.room == act.roomId then act.prep:leave() end
  self.room:dropPrep()
  self.activity = nil
  self.notice = notice
  if self.closed then return self:cleanup() end
  self:tick()
end
-- Called from input.step, never from the renderer or a network callback.
function Session:step()
  local p = self.pending
  if not p or not p.room or self.activity then return end
  local r = self.client.room()
  if not r or r.room ~= p.room or r.intent ~= "xg" then return end
  local mode = r.mode or r.xg and r.xg.mode
  local matched = false
  for _, peer in ipairs(r.players or {}) do
    if p.peer and peer.id == p.peer.id then matched = true end
  end
  if not matched or mode ~= p.mode or not Session.safe(self.game, self.identity().generation) then return end
  local prep = self.room:prep()
  if not prep then return end
  local act = { game = self.game, room = self.room, roomId = r.room, prep = prep,
    peer = p.peer, mode = mode }
  local service, gen = self, self.identity().generation
  function act:finish(reason)
    if reason == "go" then
      local ok = require("src.ui.union.Flow").launch(self, gen)
      if ok then return end
      return service:finish(self, "ONLINE PLAY UNAVAILABLE")
    end
    service:finish(self, reason == "traded" and "TRADE COMPLETE" or nil)
  end
  self.pending, self.activity = nil, act
  self:status(mode == "trade" and "trading" or "battling")
  local ok, err = pcall(function()
    if mode == "trade" then require("src.ui.union.prep.OpenTrade").trade(act)
    else require("src.ui.union.prep.Open").screen(act) end
  end)
  if not ok then
    print("[kanto_gear] online handoff failed: " .. tostring(err))
    self:finish(act, "ONLINE PLAY UNAVAILABLE")
  end
  self.revision = self.revision + 1
end
function Session:cleanup()
  if self.activity then return end -- Native trade owns its journal until done.
  local r, p = self.client.room(), self.pending
  if r and r.room == acceptedRoom(p, r) then
    self.pending = nil
    self.client.leaveRoom()
  end
  if self:ownsPlaza() then self.room:leave() else self.room:unhook() end
  self.join = nil
  local h = p and p.handle
  -- An acceptance can be in flight when the app is uninstalled. Retain only
  -- teardown listeners until that specific invite settles; never touch another room.
  if p and self.client.state() == "online" and (p.id or p.room or h and h.state ~= "closed")
      and self.pending then return end
  if self.closedListener then self.client.off("invite_closed", self.closedListener) end
  if self.roomListener then
    self.client.off("room", self.roomListener); self.client.off("state", self.roomListener)
  end
  self.closedListener, self.roomListener, self.pending = nil, nil, nil
end
function Session:close()
  self.closed = true
  self.enabled, self.ready, self.incoming, self.peers = false, false, nil, {}
  self:cleanup()
end
return Session
