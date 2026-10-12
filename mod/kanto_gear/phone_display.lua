-- One paired browser, independent lossless frames, and a two-frame transport window.
local bit = require("bit")
local Phone = {}
Phone.__index = Phone
local HOLDER = "__kanto_gear_phone_display"
local PORT, MAX_HTTP, MAX_INPUT = 8765, 4096, 128
local BUTTONS = { up = true, down = true, left = true, right = true,
  a = true, b = true, start = true, select = true, l = true, r = true }
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
    .. "\r\nReferrer-Policy: no-referrer\r\nX-Frame-Options: DENY"
    .. "\r\nPermissions-Policy: camera=(), microphone=(), geolocation=()"
    .. "\r\nContent-Security-Policy: default-src 'none'; script-src 'self'; "
    .. "style-src 'self' 'unsafe-inline'; connect-src 'self'; base-uri 'none'; "
    .. "form-action 'self'; object-src 'none'; frame-ancestors 'none'"
    .. "\r\nConnection: close\r\n\r\n" .. body
end

function Phone.new(mod, runtime, socket, pairing)
  socket = socket or require("socket")
  local previous = rawget(socket, HOLDER)
  if previous then previous:stop() end
  local self = setmetatable({ mod = mod, runtime = runtime, socket = socket,
    clients = {}, touches = {}, buttons = {},
    sequence = 0,
    page = assert(mod:read("phone.html")), script = assert(mod:read("phone.js")),
    nextFrame = 0, attempts = 0 }, Phone)
  if not pairing then
    local ok, result = pcall(function()
      local Pairing = assert(load(mod:read("phone_pairing.lua"), "@kanto_gear/phone_pairing.lua"))()
      return Pairing.new(mod, runtime)
    end)
    if not ok then return nil, "Secure pairing needs this host's background-compute support." end
    pairing = result
  end
  self.pairing = pairing
  local listener, err = (socket.tcp4 or socket.tcp)()
  if not listener then pairing:stop(); return nil, err end
  listener:settimeout(0)
  -- Windows SO_REUSEADDR would allow another game instance to steal connections.
  if not (jit and jit.os == "Windows") then listener:setoption("reuseaddr", true) end
  local ok
  ok, err = listener:bind("0.0.0.0", PORT)
  if ok then ok, err = listener:listen(4) end
  if not ok then listener:close(); pairing:stop(); return nil, err end
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
  self:rotatePairing()
  self:updatePairing()
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
function Phone:rotatePairing()
  self.pin, self.secret, self.qr, self.expires = nil, nil, nil, nil
  self.pairing:request(self.url)
end
function Phone:updatePairing()
  local result = self.pairing:pop()
  if result then
    if result.error then self.error = result.error; self:stop(); return end
    self.pin, self.secret, self.qr = result.pin, result.secret, result
    self.expires = self:now() + 300
  end
  if self.expires and self:now() >= self.expires and not self.viewer then self:rotatePairing() end
end
-- Accept only loopback/private/link-local IPv4 peers and Host values. No DNS,
-- port forwarding or router discovery; a LAN proxy still needs a pairing key.
local function localIp(ip)
  local a,b,c,d = (ip or ""):match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  a,b,c,d = tonumber(a),tonumber(b),tonumber(c),tonumber(d)
  if not d or a > 255 or b > 255 or c > 255 or d > 255 then return false end
  return a == 127 or a == 10 or a == 192 and b == 168
    or a == 172 and b >= 16 and b <= 31 or a == 169 and b == 254
end
function Phone:controls()
  local input = self.game and self.game.input
  local scripted = self.mod.input
  local direct = input and input.sourcePress and input.sourceRelease
  if not input or not (direct or scripted and scripted.press and scripted.release) then return "none" end
  -- The current public mod.input API accepts eight GB buttons. GBA shoulders
  -- use the same source bookkeeping directly until that whitelist expands.
  return self.game.generation == 3 and direct and "gba" or "gb"
end
function Phone:releaseControls()
  for button, held in pairs(self.buttons) do
    if held.input then held.input:sourceRelease(button, held.source)
    else self.mod.input:release(held.token) end
    self.buttons[button] = nil
  end
end
function Phone:setGame(game)
  if self.game == game then return end
  self:releaseControls()
  self.game = game
  if self.viewer then self.viewer.controls = self:controls() end
end
function Phone:button(button, down)
  if down == (self.buttons[button] ~= nil) then return end
  if not down then
    local held = self.buttons[button]
    if held.input then held.input:sourceRelease(button, held.source)
    else self.mod.input:release(held.token) end
    self.buttons[button] = nil
  elseif button ~= "l" and button ~= "r" and self.mod.input and self.mod.input.press and self.mod.input.release then
    self.buttons[button] = { token = self.mod.input:press(self.game, button) }
  else
    local input, source = self.game.input, "kanto_gear:phone:" .. button
    input:sourcePress(button, source)
    self.buttons[button] = { input = input, source = source }
  end
end
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
    self:releaseControls()
    self.viewer, self.touches = nil, { "cancel,0,0" }
    self.captureReserved = nil
  end
end
function Phone:stop()
  if self.pairing then self.pairing:stop() end
  self.pin, self.secret, self.qr, self.expires = nil, nil, nil, nil
  self:releaseControls()
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
  if method ~= "GET" or not localIp(host:match("^(.-):8765$")) then return false end
  if path == "/" then
    c.out = reply("200 OK", self.page, "text/html; charset=utf-8")
  elseif path == "/phone.js" then
    c.out = reply("200 OK", self.script, "text/javascript; charset=utf-8")
  elseif path == "/gear" then
    if headers.origin ~= "http://" .. host then return false end
    local now = self:now()
    if now >= (self.attemptReset or 0) then self.attempts, self.attemptReset = 0, now + 60 end
    if self.attempts >= 6 then c.out = reply("429 Too Many Requests", "Wait one minute.")
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
      c.ws, c.opened = true, now
    end
  else c.out = reply("404 Not Found", "Not found.") end
  c.sent = 0
  return true
end

function Phone:message(c, text)
  if self.viewer ~= c then
    local credential = text:match("^auth,(%x+)$")
    local now = self:now()
    if now >= (self.attemptReset or 0) then self.attempts, self.attemptReset = 0, now + 60 end
    if self.attempts >= 6 then return false end
    if self.viewer or not credential or not self.expires or now >= self.expires
        or not (credential == self.pin or credential == self.secret) then
      self.attempts = self.attempts + 1
      return false
    end
    c.alive, c.pending, self.viewer = now, {}, c
    c.controls = self:controls()
    -- The HTTP upgrade has already been fully written before auth is read.
    c.out, c.sent = packet(1, "ok"), 0
    self:rotatePairing() -- consume both the QR key and the manual code together
    return true
  end
  if text == "release" then
    self:releaseControls()
    c.touch, self.touches = false, { "cancel,0,0" }
    return true
  end
  local button, down = text:match("^b,(%a+),([01])$")
  if button then
    if not BUTTONS[button] then return false end
    local controls = self:controls()
    if self.viewer == c and self:detected() and controls ~= "none"
        and (button ~= "l" and button ~= "r" or controls == "gba") then
      -- Game input never waits for a Gear repaint or a frame acknowledgement.
      self:button(button, down == "1")
    end
    return true
  end
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
  self:updatePairing()
  if not self.listener then return end
  local now = self:now()
  for _ = 1, 2 do
    if #self.clients >= 4 then break end
    local sock = self.listener:accept()
    if not sock then break end
    sock:settimeout(0)
    sock:setoption("tcp-nodelay", true)
    if localIp(sock:getpeername()) then
      self.clients[#self.clients + 1] = { sock = sock, input = "", opened = now }
    else sock:close() end
  end
  for i = #self.clients, 1, -1 do
    local c = self.clients[i]
    local ok = now - (c.alive or c.opened) < (self.viewer == c and 1.5 or 3)
      and not (c.pending and c.pending[1] and now - c.pending[1].at > 1)
    if ok and (self.viewer == c or not c.out) then ok = self:read(c) end
    if ok and c.controls and not c.out then
      c.out, c.sent, c.controls = packet(1, "c," .. c.controls), 0, nil
    end
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
  local lines = state.error and { "PHONE DISPLAY UNAVAILABLE", state.error, "Switch display mode to try again." }
    or { "SCAN TO PAIR", state.url, state.pin and "CODE: " .. state.pin or "Preparing secure pairing...",
      "Private Wi-Fi only / unencrypted", "Code valid for 5 minutes / one use" }
  local width, height = graphics.getDimensions()
  if viewport then width, height = viewport.width, viewport.height end
  local qr = not state.error and state.qr
  local scale = qr and math.min(4, math.floor((height - #lines * 17 - 40) / (qr.size + 8)),
    math.floor((width - 32) / (qr.size + 8))) or 0
  if scale < 2 then scale = 0 end
  local qrWidth = scale > 0 and (qr.size + 8) * scale or 0
  local boxWidth = math.max(1, math.min(width - 16, math.max(300, qrWidth + 24, state.font:getWidth(lines[2]) + 24)))
  local boxHeight = #lines * 17 + 16 + (qrWidth > 0 and qrWidth + 8 or 0)
  local x, y = math.floor((width - boxWidth) / 2), math.max(0, height - boxHeight - 8)
  graphics.setColor(0.035, 0.05, 0.075, 0.97)
  graphics.rectangle("fill", x, y, boxWidth, boxHeight)
  graphics.setColor(1, 1, 1, 1)
  graphics.printf(lines[1], x, y + 8, boxWidth, "center")
  if qrWidth > 0 then
    local qx, qy = math.floor((width - qrWidth) / 2), y + 29
    graphics.rectangle("fill", qx, qy, qrWidth, qrWidth)
    graphics.setColor(0, 0, 0, 1)
    for _, run in ipairs(qr.runs) do
      graphics.rectangle("fill", qx + (run[1] + 4) * scale, qy + (run[2] + 4) * scale, run[3] * scale, scale)
    end
    graphics.setColor(1, 1, 1, 1)
  end
  for i = 2, #lines do
    graphics.printf(lines[i], x, y + 8 + (i - 1) * 17 + (qrWidth > 0 and qrWidth + 8 or 0), boxWidth, "center")
  end
  graphics.pop()
end
return Phone
