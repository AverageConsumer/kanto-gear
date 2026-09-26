-- Passive lobby browser over Recomp's shared online client. The host pumps it.
local Pss = {}
Pss.__index = Pss
local events = { "state", "lobby", "room", "plaza", "upgrade_required" }
local function clean(value)
  return tostring(value or ""):gsub("[%z\1-\31\127]", " ")
end
local function call(obj, key, ...)
  if not obj or type(obj[key]) ~= "function" then return nil end
  local ok, a, b = pcall(obj[key], ...)
  if ok then return a, b end
  return nil, tostring(a)
end
function Pss.new(ctx)
  return setmetatable({ ctx = ctx, page = 1, rows = {}, state = "offline", stale = true }, Pss)
end
function Pss:open()
  if not self.client then
    local ok, client, connect = pcall(self.ctx.resolve)
    if not ok or type(client) ~= "table" or type(connect) ~= "table"
        or type(client.lobby) ~= "function" or type(client.on) ~= "function"
        or type(client.off) ~= "function" or type(connect.start) ~= "function"
        or type(connect.state) ~= "function" or type(connect.disconnect) ~= "function" then
      self.state = "unavailable"; return
    end
    self.client, self.connect = client, connect
  end
  if not self.listener then
    self.listener = function() self.stale = true end
    for _, event in ipairs(events) do self.client.on(event, self.listener) end
  end
  self.stale = true
  self:refresh()
end
function Pss:close()
  if self.listener then
    for _, event in ipairs(events) do self.client.off(event, self.listener) end
    self.listener = nil
  end
end
function Pss:busy()
  local c = self.client
  local presence = call(c, "presence") or {}
  return call(c, "room") ~= nil or call(c, "tournament") ~= nil
    or call(c, "group") ~= nil or call(c, "direct") ~= nil
    or call(c, "plaza") ~= nil or presence.where == "union" or presence.where == "direct"
end
function Pss:refresh()
  if not self.client then return end
  local state = call(self.connect, "state") or call(self.client, "state") or "offline"
  if state == "online" then self.localError = nil end
  local err = self.localError or call(self.connect, "error")
  local busy = self:busy() and true or false
  if state ~= self.state or err ~= self.error or busy ~= self.inUse then self.stale = true end
  if not self.stale then return false end
  self.stale, self.state, self.error, self.inUse = false, state, err, busy
  local me = call(self.client, "you") or {}
  self.name = clean(me.name or call(self.connect, "name")
    or call(self.connect, "storedName") or self.ctx.identity().name)
  local rows, seen = {}, {}
  if state == "online" then
    for _, entry in ipairs(call(self.client, "lobby") or {}) do
      if type(entry) == "table" and entry.id and entry.id ~= me.id
          and entry.online ~= false and not seen[entry.id] then
        seen[entry.id] = true
        rows[#rows + 1] = { id = entry.id, name = clean(entry.name),
          version = clean(entry.version or (entry.profile or {}).version),
          where = clean(entry.where), status = clean(entry.status) }
      end
    end
  end
  table.sort(rows, function(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return tostring(a.id) < tostring(b.id)
  end)
  self.rows = rows
  self.pages = math.max(1, math.ceil(#rows / 6))
  self.page = math.max(1, math.min(self.pages, self.page))
  self.selectedRow = nil
  for _, row in ipairs(rows) do if row.id == self.selected then self.selectedRow = row end end
  return true
end
function Pss:action(action, value)
  self:refresh()
  if action == "connect" and self.client and self.state ~= "online"
      and self.state ~= "connecting" and self.state ~= "reconnecting" and self.state ~= "ticket" then
    local identity = self.ctx.identity()
    -- No battle profile is advertised by a read-only browser. Preserve any
    -- existing host connection instead of replacing its profiles or presence.
    local ok, err = call(self.connect, "start", { source = "game",
      trainerName = identity.name, version = identity.version,
      presence = { where = "game", status = "busy",
        engine = identity.generation, version = identity.version } })
    self.localError = not ok and (err or "CONNECTION FAILED") or nil
  elseif action == "disconnect" and self.client and not self:busy() then
    call(self.connect, "disconnect"); self.localError = nil
  elseif action == "page" then
    self.page = math.max(1, math.min(self.pages or 1, self.page + value))
  elseif action == "player" then self.selected = value
  elseif action == "back" then self.selected = nil
  end
  self.stale = true
  self:refresh()
end
function Pss:hit(x, y)
  for _, hit in ipairs(self.hits or {}) do
    if x >= hit.x and x < hit.x + hit.w and y >= hit.y and y < hit.y + hit.h then
      self:action(hit.action, hit.value); return true
    end
  end
end
return Pss
