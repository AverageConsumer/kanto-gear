-- One paired browser, independent lossless frames, and a two-frame transport window.
local bit = require("bit")
local Phone = {}
Phone.__index = Phone
local HOLDER = "__kanto_gear_phone_display"
local PORT, MAX_HTTP, MAX_INPUT = 8765, 4096, 128
local function u16(n) return string.char(math.floor(n / 256) % 256, n % 256) end
local function u32(n) return u16(math.floor(n / 65536)) .. u16(n % 65536) end
local function packet(op, body)
  local n = #body
  return string.char(128 + op) .. (n < 126 and string.char(n)
    or n < 65536 and (string.char(126) .. u16(n))
    or (string.char(127) .. u32(0) .. u32(n))) .. body
end
local function reply(status, body, kind)
  return "HTTP/1.1 " .. status .. "\r\nContent-Type: " .. (kind or "text/plain")
    .. "\r\nContent-Length: " .. #body
    .. "\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff"
    .. "\r\nContent-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; "
    .. "style-src 'self' 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'"
    .. "\r\nConnection: close\r\n\r\n" .. body
end

function Phone.new(mod, runtime, socket)
  socket = socket or require("socket")
  local previous = rawget(socket, HOLDER)
  if previous then previous:stop() end
  local self = setmetatable({ runtime = runtime, socket = socket, clients = {}, touches = {},
    sequence = 0, pin = string.format("%08d", runtime.math.random(0, 99999999)),
    page = assert(mod:read("phone.html")), nextFrame = 0, attempts = 0 }, Phone)
  local listener, err = (socket.tcp4 or socket.tcp)()
  if not listener then return nil, err end
  listener:settimeout(0)
  -- Windows SO_REUSEADDR would allow another game instance to steal connections.
  if not (jit and jit.os == "Windows") then listener:setoption("reuseaddr", true) end
  local ok
  ok, err = listener:bind("0.0.0.0", PORT)
  if ok then ok, err = listener:listen(4) end
  if not ok then listener:close(); return nil, err end
  self.listener = listener
  -- UDP connect chooses the local route without sending a packet or doing DNS.
  local route = socket.udp()
  local ip
  if route then
    route:settimeout(0)
    if route:setpeername("192.0.2.1", 9) then ip = route:getsockname() end
    route:close()
  end
  self.url = "http://" .. (ip and ip ~= "0.0.0.0" and ip or "127.0.0.1") .. ":" .. PORT
  self.bridge = {
    detected = function() return self:detected() end,
    pollTouch = function() return table.remove(self.touches, 1) end,
    setEnabled = function() end,
    push = function(image, w, h) return self:push(image, w, h) end,
  }
  rawset(socket, HOLDER, self)
  return self
end

function Phone:now() return self.runtime.timer.getTime() end
function Phone:detected()
  local c = self.viewer
  return c ~= nil and self:now() - c.alive < 1.5
end
function Phone:ready() return self:detected() and self.viewer.ack ~= nil end
function Phone:canCapture()
  return self:detected() and not self.captureReserved and not self.viewer.out
    and #self.viewer.pending < 2 and self:now() + .0001 >= self.nextFrame
end
function Phone:reserveCapture(at)
  if not self:canCapture() then return false end
  -- Reserve at GPU request time so completing readback can start the next 60 Hz capture.
  self.nextFrame = math.max(self.nextFrame + 1 / 60, at or self:now())
  self.captureReserved = true
  return true
end
function Phone:push(image, w, h)
  if not self.captureReserved and not self:reserveCapture() then return false end
  self.captureReserved = nil
  if not self:detected() or self.viewer.out or #self.viewer.pending >= 2 then return false end
  if w < 1 or h < 1 or w > 240 or h > 216 then return false end
  local rgba = image:getString()
  if #rgba ~= w * h * 4 then return false end
  local payload, magic = self.runtime.data.compress("string", "zlib", rgba, 1), "KG02"
  if #payload >= #rgba then payload, magic = rgba, "KG01" end
  local c = self.viewer
  self.sequence = self.sequence % 4294967295 + 1
  self.width, self.height = w, h
  c.frame = self.sequence
  c.out = packet(2, magic .. u16(w) .. u16(h) .. u32(c.frame) .. payload)
  c.sent = 0
  c.pending[#c.pending + 1] = { id = c.frame, at = self:now() }
  self:poll()
  return self:ready()
end
function Phone:drop(c)
  c.sock:close()
  if self.viewer == c then
    self.viewer, self.touches = nil, { "cancel,0,0" }
    self.captureReserved = nil
  end
end
function Phone:stop()
  for _, c in ipairs(self.clients) do self:drop(c) end
  self.clients = {}
  if self.listener then self.listener:close(); self.listener = nil end
  if rawget(self.socket, HOLDER) == self then rawset(self.socket, HOLDER, nil) end
end

function Phone:request(c, header)
  local method, path = header:match("^(%u+) (%S+) HTTP/1%.[01]\r\n")
  local headers = {}
  for name, value in header:gmatch("\r\n([%w%-]+):[ \t]*([^\r\n]*)") do
    name = name:lower()
    if headers[name] then return false end
    headers[name] = value
  end
  local host = headers.host or ""
  if method ~= "GET" or not host:match("^%d+%.%d+%.%d+%.%d+:8765$") then return false end
  if path == "/" then
    c.out = reply("200 OK", self.page, "text/html; charset=utf-8")
  elseif path:match("^/gear%?pin=%d%d%d%d%d%d%d%d$") then
    if headers.origin ~= "http://" .. host then return false end
    local now = self:now()
    if now >= (self.attemptReset or 0) then self.attempts, self.attemptReset = 0, now + 60 end
    if self.attempts >= 6 then c.out = reply("429 Too Many Requests", "Wait one minute.")
    elseif path ~= "/gear?pin=" .. self.pin then
      self.attempts = self.attempts + 1
      c.out = reply("403 Forbidden", "Incorrect pairing code.")
    elseif self.viewer then c.out = reply("409 Conflict", "One browser is already connected.")
    elseif (headers.upgrade or ""):lower() ~= "websocket"
        or not (headers.connection or ""):lower():match("upgrade")
        or headers["sec-websocket-version"] ~= "13"
        or not (headers["sec-websocket-key"] or ""):match("^[%w+/]+==$" )
        or #headers["sec-websocket-key"] ~= 24 then return false
    else
      local accept = self.runtime.data.encode("string", "base64",
        self.runtime.data.hash("sha1", headers["sec-websocket-key"] .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
      c.out = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade"
        .. "\r\nSec-WebSocket-Accept: " .. accept .. "\r\n\r\n"
      c.ws, c.alive, c.pending, self.viewer = true, now, {}, c
    end
  else c.out = reply("404 Not Found", "Not found.") end
  c.sent = 0
  return true
end

function Phone:message(c, text)
  local kind, id = text:match("^([ha]),(%d+)$")
  if kind then
    id = tonumber(id)
    if kind == "a" then
      for i, frame in ipairs(c.pending) do
        if id == frame.id then
          c.ack, c.alive = id, self:now()
          for _ = 1, i do table.remove(c.pending, 1) end
          break
        end
      end
    end
    if kind == "h" and (id == c.ack or id == 0 and not c.ack) then
      c.alive, c.heartbeat = self:now(), true
    end
    return true
  end
  local action, sx, sy, frame = text:match("^(%a+),(%d+),(%d+),(%d+)$")
  local x, y = tonumber(sx), tonumber(sy)
  if not ({ down = true, up = true, move = true, cancel = true })[action] then return false end
  -- The browser still displays its acknowledged frame while the next one is in flight.
  if tonumber(frame) ~= c.ack or not self:ready() then
    if c.touch and (action == "up" or action == "cancel") then
      c.touch = false
      self.touches = { "cancel,0,0" }
    end
    return true
  end
  if x >= self.width or y >= self.height then return false end
  if action == "down" then c.touch = true
  elseif not c.touch then return true end
  if action == "up" or action == "cancel" then c.touch = false end
  local event = action .. "," .. sx .. "," .. sy
  local n = #self.touches
  if action == "move" and n > 0 and self.touches[n]:match("^move,") then self.touches[n] = event
  elseif n < 32 then self.touches[n + 1] = event
  else return false end
  return true
end

function Phone:read(c)
  local data, err, partial = c.sock:receive(c.ws and 1024 or MAX_HTTP)
  c.input = c.input .. (data or partial or "")
  if err and err ~= "timeout" then return false end
  if not c.ws then
    local last = c.input:find("\r\n\r\n", 1, true)
    if #c.input > MAX_HTTP then return false end
    if last then
      local header = c.input:sub(1, last + 3)
      c.input = c.input:sub(last + 4)
      return self:request(c, header)
    end
    return true
  end
  -- Client messages are small, unfragmented, masked text/control frames only.
  if #c.input > 2048 then return false end
  for _ = 1, 16 do
    if #c.input < 2 then break end
    local a, b = c.input:byte(1, 2)
    local op, n = a % 16, b % 128
    if a < 128 or bit.band(a, 112) ~= 0 or b < 128 or n > MAX_INPUT
        or n >= 126 or (op ~= 1 and op ~= 8 and op ~= 9 and op ~= 10) then return false end
    if #c.input < n + 6 then break end
    local key, chars = { c.input:byte(3, 6) }, {}
    for i = 1, n do chars[i] = string.char(bit.bxor(c.input:byte(i + 6), key[(i - 1) % 4 + 1])) end
    local text = table.concat(chars)
    c.input = c.input:sub(n + 7)
    if op == 8 then return false
    elseif op == 9 then
      -- Never insert control bytes halfway through a partially sent frame.
      if c.out then return false end
      c.out, c.sent = packet(10, text), 0
    elseif op == 1 and not self:message(c, text) then return false end
  end
  return true
end

function Phone:poll()
  if not self.listener then return end
  local now = self:now()
  for _ = 1, 2 do
    if #self.clients >= 4 then break end
    local sock = self.listener:accept()
    if not sock then break end
    sock:settimeout(0)
    sock:setoption("tcp-nodelay", true)
    self.clients[#self.clients + 1] = { sock = sock, input = "", opened = now }
  end
  for i = #self.clients, 1, -1 do
    local c = self.clients[i]
    local ok = now - (c.alive or c.opened) < (c.ws and 1.5 or 3)
      and not (c.pending and c.pending[1] and now - c.pending[1].at > 1)
    if ok and (c.ws or not c.out) then ok = self:read(c) end
    if ok and c.heartbeat and not c.out then c.out, c.sent, c.heartbeat = packet(1, "h"), 0, nil end
    if ok and c.out then
      local last, err, partial = c.sock:send(c.out, c.sent + 1, math.min(#c.out, c.sent + 262144))
      c.sent = last or partial or c.sent
      if err and err ~= "timeout" then ok = false end
      if c.sent == #c.out then
        c.out = nil
        if not c.ws then ok = false end
      end
    end
    if not ok then self:drop(c); table.remove(self.clients, i) end
  end
end

function Phone.drawStatus(state, graphics, viewport)
  if state.ready and state:ready() then return end
  graphics.push("all")
  graphics.origin(); graphics.setScissor(); graphics.setShader()
  state.font = state.font or graphics.newFont(12)
  graphics.setFont(state.font)
  local lines = state.error and { "PHONE DISPLAY UNAVAILABLE", "Check Wi-Fi and port 8765.", "Switch display mode to try again." }
    or { "PHONE / BROWSER PROTOTYPE", state.url, "PAIRING CODE: " .. state.pin }
  local width, height = graphics.getDimensions()
  if viewport then width, height = viewport.width, viewport.height end
  local boxWidth = math.max(1, math.min(width - 16, math.max(260, state.font:getWidth(lines[2]) + 24)))
  local boxHeight = #lines * 17 + 16
  local x, y = math.floor((width - boxWidth) / 2), math.max(0, height - boxHeight - 8)
  graphics.setColor(0.035, 0.05, 0.075, 0.94)
  graphics.rectangle("fill", x, y, boxWidth, boxHeight)
  graphics.setColor(1, 1, 1, 1)
  for i, line in ipairs(lines) do graphics.printf(line, x, y + 8 + (i - 1) * 17, boxWidth, "center") end
  graphics.pop()
end
return Phone
