-- One paired browser, lossless incremental video, and a bounded transport window.
local bit = require("bit")
local Phone = {}
Phone.__index = Phone
local HOLDER = "__kanto_gear_phone_display"
local PORT, MAX_HTTP, MAX_INPUT = 8765, 4096, 128
local VIDEO_WINDOW, MAX_VIDEO_WINDOW = 4, 8
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

function Phone.new(mod, runtime, socket, pairing, video)
  socket = socket or require("socket")
  local previous = rawget(socket, HOLDER)
  if previous then previous:stop() end
  local self = setmetatable({ mod = mod, runtime = runtime, socket = socket,
    clients = {}, touches = {}, buttons = {},
    sequence = 0, epoch = 0,
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
  if not video then
    local started, result = pcall(function()
      local requests, results = runtime.thread.newChannel(), runtime.thread.newChannel()
      local worker = runtime.thread.newThread(assert(mod:read("phone_video_worker.lua")))
      worker:start(requests, results, assert(mod:read("phone_video.lua")))
      return {
        request = function(_, job) requests:push(job) end,
        pop = function()
          local result = results:pop()
          if result then return result end
          if worker:getError() then return { error = "Phone video encoding failed." } end
        end,
        stop = function() requests:clear(); requests:push(false); results:clear() end,
      }
    end)
    if not started then pairing:stop(); return nil, "Phone video background worker is unavailable." end
    video = result
  end
  self.video = video
  local listener, err = (socket.tcp4 or socket.tcp)()
  if not listener then pairing:stop(); video:stop(); return nil, err end
  listener:settimeout(0)
  -- Windows SO_REUSEADDR would allow another game instance to steal connections.
  if not (jit and jit.os == "Windows") then listener:setoption("reuseaddr", true) end
  local ok
  ok, err = listener:bind("0.0.0.0", PORT)
  if ok then ok, err = listener:listen(4) end
  if not ok then listener:close(); pairing:stop(); video:stop(); return nil, err end
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
    and not self.queuedImage and #self.viewer.pending + ((self.encoding or self.encoded) and 1 or 0) < (self.viewer.window or VIDEO_WINDOW)
    -- Host frames are not exact clock ticks. Keep their phase through small jitter.
    and self:now() + .003 >= self.nextFrame
end
function Phone:reserveCapture(at)
  if not self:canCapture() then return false end
  -- Reserve at GPU request time so completing readback can start the next 60 Hz capture.
  self.nextFrame = math.max(self.nextFrame + 1 / 60, at or self:now())
  self.captureReserved, self.captureAt = true, at or self:now()
  return true
end
function Phone:push(image, w, h)
  if not self.captureReserved and not self:reserveCapture() then return false end
  self.captureReserved = nil
  if not self:detected() or self.queuedImage then return false end
  if w < 1 or h < 1 or w > 240 or h > 216 then return false end
  local rgba = image:getString()
  if #rgba ~= w * h * 4 then return false end
  self.queuedImage = { rgba = rgba, w = w, h = h, at = math.floor((self.captureAt or self:now()) * 1000) % 4294967296 }
  self:poll()
  return self:ready()
end
function Phone:encodeQueued()
  local c, image = self.viewer, self.queuedImage
  if not image or self.encoding or self.encoded or not c or c.out or #c.pending >= (c.window or VIDEO_WINDOW) then return end
  image.id, image.epoch = self.sequence % 4294967295 + 1, self.epoch
  self.encoding = { id = image.id, epoch = image.epoch, w = image.w, h = image.h }
  self.queuedImage = nil
  self.video:request(image)
end
function Phone:pollVideo()
  self:encodeQueued()
  local result = self.encoded or self.video:pop()
  if not result then return end
  local image = result.image or self.encoding
  self.encoding, self.encoded = nil, nil
  if result.error then self.error = result.error; self:stop(); return end
  if not image or result.epoch ~= self.epoch or not self.viewer or not result.body then return end
  local c = self.viewer
  if c.out then result.image = image; self.encoded = result; return end
  self.sequence, self.width, self.height = result.id, image.w, image.h
  c.frame, c.out, c.sent = result.id, packet(2, result.body), 0
  c.pending[#c.pending + 1] = { id = c.frame, at = self:now() }
end
function Phone:drop(c)
  c.sock:close()
  if self.viewer == c then
    self:releaseControls()
    self.viewer, self.touches = nil, { "cancel,0,0" }
    self.captureReserved, self.queuedImage, self.encoded = nil, nil, nil
    self.epoch = self.epoch + 1
  end
end
function Phone:stop()
  if self.pairing then self.pairing:stop() end
  if self.video then self.video:stop() end
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
    self.epoch = self.epoch + 1
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
          c.roundTrips = c.roundTrips or {}
          c.roundTrips[#c.roundTrips + 1] = c.alive - frame.at
          if #c.roundTrips > 32 then table.remove(c.roundTrips,1) end
          local floor = math.huge
          for _, elapsed in ipairs(c.roundTrips) do floor = math.min(floor,elapsed) end
          -- Cover latency, not an unbounded playback queue. Slow links still stop capture.
          c.window = math.max(VIDEO_WINDOW,math.min(MAX_VIDEO_WINDOW,math.ceil(floor*60)+2))
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
  self:pollVideo()
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
  self:encodeQueued()
end

-- Pairing card on the main screen: a docked Silph Link panel in the active Gear skin.
-- Drawn in whole "units" so every edge stays on the pixel grid at any window size.
local SKINS = {
  pokegear = {
    light = { rim = "14483c", body = "f8f8f0", body2 = "e8efe6", band = "3a9780", band2 = "14483c",
      bandInk = "f8f8f0", ink = "283036", muted = "55675d", line = "9abaa7", accent = "2f8c76", plate = "ffffff" },
    dark = { rim = "0b0f17", body = "2d3748", body2 = "273041", band = "2c7f8f", band2 = "0f3640",
      bandInk = "e8f4ef", ink = "e6edf2", muted = "9aa8b8", line = "3c4b5d", accent = "73c5a5", plate = "ffffff" },
  },
  cgear = {
    light = { rim = "9fb1bf", body = "fbfcfd", body2 = "eef3f6", band = "1ea5d8", band2 = "f4f7f9",
      bandInk = "ffffff", ink = "2a3640", muted = "5f6f7c", line = "cfd9e1", accent = "1894c4", plate = "ffffff" },
    dark = { rim = "0d1116", body = "212a33", body2 = "1b232c", band = "36b4e0", band2 = "0d1116",
      bandInk = "ffffff", ink = "e2edf4", muted = "8a9aa8", line = "3c4b59", accent = "4cc8f0", plate = "ffffff" },
  },
}
local ERROR = "e05a74"
local function rgb(hex, a)
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, a or 1
end

function Phone.drawStatus(state, graphics, viewport, theme)
  if state.ready and state:ready() then return end
  theme = theme or {}
  local G = graphics
  G.push("all")
  G.origin(); G.setScissor(); G.setShader()
  local width, height = G.getDimensions()
  if viewport then width, height = viewport.width, viewport.height end
  local skinName = theme.skin == "cgear" and "cgear" or "pokegear"
  local c = SKINS[skinName][theme.dark == false and "light" or "dark"]
  local cg = skinName == "cgear"
  local now = state.now and state:now() or 0
  local timer = rawget(_G, "love") and love.timer and love.timer.getTime() or now

  -- Fonts: the Gear's own pixel fonts when the host provides them.
  state.fallbackFont = state.fallbackFont or G.newFont(12)
  local font = theme.font or state.fallbackFont
  local small = theme.small or font
  local large = theme.large or font
  local u = math.max(1, math.floor(height / 270))         -- one panel pixel
  local fs = math.max(1, math.floor(u / 2))               -- font scale (integer, crisp)
  local function textW(f, s) return f:getWidth(s) * fs end
  local function textH(f) return f:getHeight() * fs end
  local function text(f, s, x, y, col, a)
    G.setFont(f); G.setColor(rgb(col, a)); G.print(s, math.floor(x), math.floor(y), 0, fs, fs)
  end
  local function rect(col, x, y, w, h, r, a)
    G.setColor(rgb(col, a)); G.rectangle("fill", x, y, w, h, r or 0, r or 0)
  end

  local failed = state.error ~= nil
  local connecting = not failed and state.detected and state:detected()
  local qr = not failed and not connecting and state.qr or nil
  local title = failed and "PHONE DISPLAY UNAVAILABLE" or connecting and "Phone found" or "Waiting for your phone"
  local hint = failed and tostring(state.error) or connecting and "Starting the Gear on your phone"
    or qr and "Scan with the phone camera" or "Preparing secure pairing"
  local code = not failed and not connecting and state.pin
    and (state.pin:sub(1, 4) .. " " .. state.pin:sub(5, 8)) or nil
  local remaining = state.expires and math.max(0, math.floor(state.expires - now)) or nil
  local footer = failed and "Switch display mode to try again" or connecting and "Keep this game open"
    or "Same Wi-Fi as this device"
  local footer2 = not failed and not connecting and remaining and string.format("One-time code · expires in %d:%02d", math.floor(remaining / 60), remaining % 60) or nil

  -- Size the QR as large as the side column allows, then fit the card to it.
  local pad = 6 * u
  local m, qrSide = 0, 0
  local function measure()
    qrSide = qr and (qr.size + 8) * m or 0
    local inner = math.max(qrSide, textW(font, title .. "...") + 10 * u, textW(small, hint), textW(small, footer), footer2 and textW(small, footer2) or 0,
      code and textW(large, code) or 0, textW(small, state.url or ""), 96 * u)
    local h = textH(font) + 8 * u + pad                     -- header + top padding
      + math.max(textH(font), 7 * u) + 2 * u + textH(small) + 6 * u -- title + hint
      + (qr and qrSide + 6 * u or 0)
      + (code and textH(small) + u + textH(large) + 4 * u or 0)
      + (state.url and not failed and not connecting and textH(small) + 4 * u or 0)
      + textH(small) * (footer2 and 2 or 1) + 3 * u + pad
    return inner + 2 * pad, h
  end
  if qr then
    m = math.max(3, math.floor(height * .36 / (qr.size + 8)))
    while m > 2 do
      local w, h = measure()
      if h <= height - 12 * u and w <= (width >= 640 and width * .42 or width - 16 * u) then break end
      m = m - 1
    end
  end
  local cardW, cardH = measure()
  cardW = math.min(cardW, width - 8 * u)
  local x = math.floor(width - cardW - 8 * u)
  local y = math.floor(math.max(6 * u, (height - cardH) / 2))
  local r = cg and u or 3 * u

  -- Shell: soft drop shadow, dark rim, body.
  rect("000000", x + 2 * u, y + 3 * u, cardW, cardH, r, .28)
  rect(c.rim, x - u, y - u, cardW + 2 * u, cardH + 2 * u, r + u)
  rect(c.body, x, y, cardW, cardH, r)
  rect(c.body2, x, y + cardH - 4 * u, cardW, 4 * u, r)

  -- Header band.
  local hh = textH(font) + 8 * u
  local accent = failed and ERROR or c.accent
  if cg then
    rect(c.band2, x, y, cardW, hh, r)
    local slash = textW(font, "SILPH LINK") + 14 * u
    G.setColor(rgb(failed and ERROR or c.band))
    G.polygon("fill", x, y, x + slash, y, x + slash - 4 * u, y + hh, x, y + hh)
    G.setColor(rgb(failed and ERROR or c.band, .45))
    G.polygon("fill", x + slash + 2 * u, y, x + slash + 5 * u, y, x + slash + u, y + hh, x + slash - 2 * u, y + hh)
    rect(failed and ERROR or c.band, x, y + hh - u, cardW, u)
    rect(c.bandInk, x + 4 * u, y + 4 * u, u, hh - 8 * u)
    text(font, "SILPH LINK", x + 7 * u, y + 4 * u, c.bandInk)
  else
    rect(failed and ERROR or c.band, x, y, cardW, hh, r)
    rect(failed and ERROR or c.band2, x, y + math.floor(hh / 2), cardW, math.ceil(hh / 2))
    G.setColor(rgb(failed and ERROR or c.band2))
    local tooth = 4 * u
    for i = 0, math.floor(cardW / tooth) - 1 do
      local tx = x + i * tooth
      G.polygon("fill", tx, y + hh, tx + tooth, y + hh, tx + tooth / 2, y + hh + 2 * u)
    end
    rect("ffffff", x + 5 * u, y + math.floor(hh / 2) - u, 2 * u, 2 * u, u, .55)
    text(font, "SILPH LINK", x + 10 * u, y + 4 * u, c.bandInk)
  end
  -- Signal bars, top right: they fill in turn while waiting (cheap, one cycle per second).
  local step = failed and 0 or connecting and 3 or math.floor(timer * 3) % 4
  for i = 1, 3 do
    local bh = (i + 1) * u
    local bx, by = x + cardW - (5 + (4 - i) * 3) * u, y + 4 * u + (4 * u - bh) + math.floor((textH(font) - 4 * u) / 2)
    rect(cg and (failed and ERROR or c.accent) or c.bandInk, bx, by, 2 * u, bh, 0, i <= step and 1 or .3)
  end

  -- Body.
  local cy = y + hh + pad
  local cx = x + pad
  local innerW = cardW - 2 * pad
  -- Little phone next to the title: body, screen, speaker slit.
  local ph = math.max(textH(font), 7 * u)
  rect(c.ink, cx, cy, 7 * u, ph, u)
  rect(accent, cx + u, cy + 2 * u, 5 * u, ph - 5 * u)
  rect(c.body, cx + 2 * u, cy + ph - 2 * u, 3 * u, u)
  local dots = (failed or connecting) and "" or string.rep(".", math.floor(timer * 2) % 4)
  text(font, title .. dots, cx + 10 * u, cy + (ph - textH(font)) / 2, failed and ERROR or c.ink)
  cy = cy + ph + 2 * u
  text(small, hint, cx, cy, c.muted)
  cy = cy + textH(small) + 6 * u

  if qr then
    local qx = math.floor(x + (cardW - qrSide) / 2)
    rect(cg and accent or c.line, qx - u, cy - u, qrSide + 2 * u, qrSide + 2 * u, cg and 0 or 2 * u)
    rect(c.plate, qx, cy, qrSide, qrSide, cg and 0 or u)
    G.setColor(0, 0, 0, 1)
    for _, run in ipairs(qr.runs) do
      G.rectangle("fill", qx + (run[1] + 4) * m, cy + (run[2] + 4) * m, run[3] * m, m)
    end
    cy = cy + qrSide + 6 * u
  end
  if code then
    text(small, "OR ENTER CODE", cx, cy, c.muted)
    cy = cy + textH(small) + u
    text(large, code, x + (cardW - textW(large, code)) / 2, cy, c.ink)
    cy = cy + textH(large) + 4 * u
  end
  if state.url and not failed and not connecting then
    local url = state.url:gsub("^http://", "")
    text(small, url, x + (cardW - textW(small, url)) / 2, cy, accent)
    cy = cy + textH(small) + 4 * u
  end
  local fy = y + cardH - pad - textH(small) * (footer2 and 2 or 1)
  rect(c.line, cx, fy - 3 * u, innerW, math.max(1, math.floor(u / 2)))
  text(small, footer, x + (cardW - textW(small, footer)) / 2, fy, failed and ERROR or c.muted)
  if footer2 then text(small, footer2, x + (cardW - textW(small, footer2)) / 2, fy + textH(small), c.muted) end

  if cg then -- corner brackets
    local L, T = 6 * u, u
    for _, p in ipairs({ { x - 2 * u, y + cardH + u, 1, -1 }, { x + cardW + 2 * u, y + cardH + u, -1, -1 } }) do
      rect(c.band, p[3] > 0 and p[1] or p[1] - L, p[2] - T, L, T)
      rect(c.band, p[3] > 0 and p[1] or p[1] - T, p[2] - L, T, L)
    end
  end
  G.pop()
end
return Phone
