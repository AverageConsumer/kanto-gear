-- One paired browser, lossless incremental video, and bounded transport queues.
local bit = require("bit")
local Phone = {}
Phone.__index = Phone
local HOLDER = "__kanto_gear_phone_display"
local PORT, MAX_HTTP, MAX_INPUT = 8765, 4096, 128
local VIDEO_QUEUE, VIDEO_BYTES, HISTORY = 3, 512 * 1024, 128
local BUTTONS = { up = true, down = true, left = true, right = true,
  a = true, b = true, start = true, select = true, l = true, r = true }
local PROFILE = { "decode", "wait", "paint", "interval", "arrival", "dispatch", "late", "source", "raf" }
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
    .. "style-src 'self' 'unsafe-inline'; connect-src 'self'; worker-src 'self'; base-uri 'none'; "
    .. "form-action 'self'; object-src 'none'; frame-ancestors 'none'"
    .. "\r\nConnection: close\r\n\r\n" .. body
end

function Phone.new(mod, runtime, socket, pairing, video, perf)
  socket = socket or require("socket")
  local previous = rawget(socket, HOLDER)
  if previous then previous:stop() end
  local self = setmetatable({ mod = mod, runtime = runtime, socket = socket,
    perf = perf and perf.enabled and perf or nil,
    clients = {}, touches = {}, buttons = {},
    sequence = 0, epoch = 0,
    page = assert(mod:read("phone/phone.html")), script = assert(mod:read("phone/phone.js")),
    decoder = assert(mod:read("phone/phone_decoder.js")),
    nextFrame = 0, attempts = 0 }, Phone)
  if not pairing then
    local ok, result = pcall(function()
      local Pairing = assert(load(mod:read("phone/pairing.lua"), "@kanto_gear/phone/pairing.lua"))()
      return Pairing.new(mod, runtime)
    end)
    if not ok then return nil, "Secure pairing needs this host's background-compute support." end
    pairing = result
  end
  self.pairing = pairing
  if not video then
    local started, result = pcall(function()
      local requests, results = runtime.thread.newChannel(), runtime.thread.newChannel()
      local worker = runtime.thread.newThread(assert(mod:read("phone/video_worker.lua")))
      worker:start(requests, results, assert(mod:read("phone/video.lua")))
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
  self:refreshAddress()
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
function Phone:refreshAddress()
  local now = self:now()
  if now < (self.nextAddressCheck or 0) then return end
  self.nextAddressCheck = now + 1
  -- UDP connect reads the current route without sending packets or doing DNS.
  local route = self.socket.udp()
  local ip
  if route then
    route:settimeout(0)
    if route:setpeername("192.0.2.1", 9) then ip = route:getsockname() end
    route:close()
  end
  local url = ip and ip ~= "0.0.0.0" and ("http://" .. ip .. ":" .. PORT)
    or self.url or "http://127.0.0.1:8765"
  if url == self.url then return end
  for _, client in ipairs(self.clients) do self:drop(client, "network_change") end
  self.clients = {}
  self.url = url
  self:rotatePairing()
end
function Phone:rotatePairing()
  self.pin, self.secret, self.qr, self.expires = nil, nil, nil, nil
  self.pairing:request(self.url)
end
function Phone:updatePairing()
  local result = self.pairing:pop()
  if result then
    if result.error then self.error = result.error; self:stop(); return end
    if result.url == self.url then
      self.pin, self.secret, self.qr = result.pin, result.secret, result
      self.expires = self:now() + 300
    end
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
-- Host path [Gen 3 vs Gen 1/2]: GBA shoulder buttons require direct source input; the public scripted API only supports eight GB buttons.
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
  self.sourceFrame, self.capturedFrame = nil, nil
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
-- input.step follows the same fixed-step clock as all three generations.
function Phone:step(dt)
  self.sourceFrame = (self.sourceFrame or 0) + 1
  self.sourceTime = (self.sourceTime or self:now()) + (dt or 1 / 60) / math.max(1, self.game and self.game._frameSpeed or 1)
end
local function transportRoom(c)
  return #(c.videoQueue or {}) < VIDEO_QUEUE and (c.videoBytes or 0) < VIDEO_BYTES
end
function Phone:canCapture()
  if not self:detected() or self.captureReserved or not transportRoom(self.viewer) then return false end
  if self.sourceFrame and self.sourceFrame == self.capturedFrame then return false end
  -- Limit capture work to 30 Hz independently of input speed and host refresh.
  return self:now() + .003 >= self.nextFrame
end
function Phone:reserveCapture(at)
  if not self:canCapture() then return false end
  local capturedAt, scheduled = at or self:now(), self.nextFrame + 1 / 30
  self.nextFrame = scheduled > capturedAt and scheduled or capturedAt + 1 / 30
  self.capturedFrame = self.sourceFrame
  self.captureReserved, self.captureAt = true, self.sourceTime or at or self:now()
  self.capturedAt = self.perf and self.perf:start()
  return true
end
function Phone:push(image, w, h)
  if not self.captureReserved and not self:reserveCapture() then return false end
  self.captureReserved = nil
  if not self:detected() then return false end
  if w < 1 or h < 1 or w > 240 or h > 216 then return false end
  local measured = self.perf and self.perf:start()
  local rgba = image:getString()
  if self.perf then
    self.perf:finish("phone_pixels", measured)
    self.perf:count("phone_captured")
    self.perf:count("phone_source_bytes", #rgba)
    if self.queuedImage then self.perf:count("phone_replaced") end
  end
  if #rgba ~= w * h * 4 then return false end
  -- An unscheduled capture has no delta dependants: retain the newest one only.
  self.queuedImage = { rgba = rgba, w = w, h = h, capturedAt = self.capturedAt,
    at = math.floor((self.captureAt or self:now()) * 1000) % 4294967296 }
  self:poll()
  return self:ready()
end
function Phone:encodeQueued()
  local c, image = self.viewer, self.queuedImage
  if not image or self.encoding or not c or not transportRoom(c) then return end
  image.id, image.epoch = self.sequence % 4294967295 + 1, self.epoch
  image.profile = self.perf and self.perf.enabled or nil
  image.queuedAt = image.profile and self:now() or nil
  self.encoding = { id = image.id, epoch = image.epoch, w = image.w, h = image.h,
    queuedAt = image.queuedAt, capturedAt = image.capturedAt }
  self.queuedImage = nil
  self.video:request(image)
end
function Phone:pollVideo()
  self:encodeQueued()
  local result = self.video:pop()
  if not result then self:encodeQueued(); return end
  local image = self.encoding
  self.encoding = nil
  if result.error then self.error = result.error; self:stop(); return end
  if image and result.epoch == self.epoch and self.perf then
    self.perf:finish("phone_worker_roundtrip", image.queuedAt)
    local profile = result.profile
    if profile then
      self.perf:sample("phone_encode", profile.encode)
      self.perf:sample("phone_diff", profile.diff)
      self.perf:sample("phone_worker_wait", profile.wait)
      if profile.compress then self.perf:sample("phone_compress", profile.compress) end
      if profile.patchBytes then self.perf:count("phone_patch_bytes", profile.patchBytes) end
    end
    self.perf:count(result.body and "phone_encoded" or "phone_duplicate")
    if result.body then self.perf:count("phone_payload_bytes", #result.body) end
  end
  if image and result.epoch == self.epoch and self.viewer and result.body then
    local c = self.viewer
    self.sequence, self.width, self.height = result.id, image.w, image.h
    local value = { id = result.id, bytes = packet(2, result.body), w = image.w, h = image.h,
      capturedAt = image.capturedAt }
    c.videoQueue = c.videoQueue or {}
    c.videoQueue[#c.videoQueue + 1] = value
    c.videoBytes = (c.videoBytes or 0) + #value.bytes
  end
  self:encodeQueued()
end
function Phone:drop(c, reason)
  c.sock:close()
  if self.viewer == c then
    if self.perf then
      self.perf:count("phone_disconnect_" .. (reason or "cleanup"))
      self.perf.log(string.format("KGPROF v=1 kind=disconnect reason=%s browser=%s idle=%.3f poll=%.3f buffered=%d unsent=%d",
        reason or "cleanup", c.browserStop or "unknown", (self:now() - (c.alive or c.opened)) * 1000,
        (self.pollGap or 0) * 1000, #c.input, c.out and #c.out - c.sent or 0))
      if self.mod.log then self.mod.log:warn("phone disconnected: %s", reason or "cleanup") end
    end
    self:releaseControls()
    self.viewer, self.touches = nil, { "cancel,0,0" }
    self.captureReserved, self.queuedImage = nil, nil
    self.epoch = self.epoch + 1
  end
end
function Phone:stop()
  if self.pairing then self.pairing:stop() end
  if self.video then self.video:stop() end
  self.pin, self.secret, self.qr, self.expires = nil, nil, nil, nil
  self:releaseControls()
  for _, c in ipairs(self.clients) do self:drop(c, "server_stop") end
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
  elseif path == "/phone.js" or path == "/phone_decoder.js" then
    c.out = reply("200 OK", path == "/phone.js" and self.script or self.decoder, "text/javascript; charset=utf-8")
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
    c.profilePending = self.perf ~= nil
    self:rotatePairing() -- consume both the QR key and the manual code together
    return true
  end
  if text == "release" then
    self:releaseControls()
    c.touch, self.touches = false, { "cancel,0,0" }
    return true
  end
  local stopped, received, painted, decoding, queued = text:match("^x,([a-z_]+),(%d+%.%d+),(%d+%.%d+),(%d+),(%d+)$")
  stopped = stopped or text:match("^x,([a-z_]+)$")
  if stopped then
    if not self.perf or not ({client_stop=true, decoder_error=true, contact_timeout=true,
      decoder_queue=true, page_hidden=true, page_closed=true})[stopped] then return false end
    if received and (tonumber(received)>10000 or tonumber(painted)>10000 or tonumber(decoding)>32 or tonumber(queued)>8) then return false end
    c.browserStop = stopped
    self.perf.log(string.format("KGPROF v=1 kind=browser_stop reason=%s received=%s painted=%s decoding=%s queued=%s",
      stopped, received or "unknown", painted or "unknown", decoding or "unknown", queued or "unknown"))
    return true
  end
  local profileId, timings = text:match("^p,(%d+),([%d%.,]+)$")
  if profileId then
    if not self.perf or #text >= 126 then return false end
    local values = {}
    for value in (timings .. ","):gmatch("(.-),") do
      if not value:match("^%d+%.%d+$") or tonumber(value) > 10000 then return false end
      values[#values + 1] = tonumber(value)
    end
    if #values ~= 4 and #values ~= 10 then return false end
    if tonumber(profileId) ~= c.ack or c.profileAck == c.ack then return true end
    c.profileAck = c.ack
    for i, name in ipairs(PROFILE) do
      if values[i] and (i < 4 or values[i] > 0) then self.perf:sample("phone_browser_" .. name, values[i]) end
    end
    if #values == 10 then
      self.perf:count("phone_browser_dropped", values[10])
      local frame = c.pending[1]
      if frame and frame.id == c.ack and frame.capturedAt then
        local previous, now = c.profileFrame, self:now()
        local captureGap = previous and (frame.capturedAt - previous.capturedAt) * 1000 or 0
        local sendGap = previous and (frame.at - previous.at) * 1000 or 0
        local age = (frame.at - frame.capturedAt) * 1000
        if previous then
          self.perf:sample("phone_capture_gap", captureGap)
          self.perf:sample("phone_send_gap", sendGap)
        end
        self.perf:sample("phone_capture_send", age)
        -- Compare gaps on each clock; no synchronized host/browser clocks are needed.
        if previous and now >= (c.nextStutter or 0) and
            (values[4] > 70 and values[8] <= 70 or values[5] - sendGap > 50
              or values[6] > 30 or values[7] > 40 or values[10] > 0) then
          c.nextStutter = now + 1
          self.perf.log(string.format("KGPROF v=1 kind=stutter id=%d at=%.3f capture=%.3f send=%.3f age=%.3f rtt=%.3f decode=%.3f wait=%.3f paint=%.3f interval=%.3f arrival=%.3f dispatch=%.3f late=%.3f source=%.3f raf=%.3f dropped=%.0f",
            frame.id, now, captureGap, sendGap, age, (now - frame.at) * 1000, unpack(values)))
        end
        c.profileFrame = frame
      end
    end
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
  local kind, id = text:match("^([hra]),(%d+)$")
  if kind then
    id = tonumber(id)
    if kind == "a" or kind == "r" then
      for i, frame in ipairs(c.pending) do
        if id == frame.id then
          c.alive = self:now()
          if self.perf and not frame[kind .. "Profiled"] then
            self.perf:finish(kind == "r" and "phone_decode_ack" or "phone_paint_ack", frame.at)
            if kind == "a" then
              self.perf:finish("phone_capture_ack", frame.capturedAt)
              self.perf:count("phone_acked")
            end
            frame[kind .. "Profiled"] = true
          end
          if kind == "r" then c.rtt = c.alive - frame.at
          elseif not c.ack or id == c.ack or (id - c.ack + 4294967295) % 4294967295 < 2147483647 then
            c.ack, c.ackWidth, c.ackHeight = id, frame.w, frame.h
            for _ = 1, i - 1 do table.remove(c.pending, 1) end
          end
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
  if x >= (c.ackWidth or self.width) or y >= (c.ackHeight or self.height) then return false end
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
  -- Drain coalesced messages across polls without overflowing the parser buffer.
  local size = c.ws and math.min(1024, math.max(0, 2048 - #c.input)) or MAX_HTTP
  local data, err, partial = c.sock:receive(size)
  c.input = c.input .. (data or partial or "")
  if err and err ~= "timeout" then return false, "read_error" end
  if not c.ws then
    local last = c.input:find("\r\n\r\n", 1, true)
    if #c.input > MAX_HTTP then return false, "http_buffer" end
    if last then
      local header = c.input:sub(1, last + 3)
      c.input = c.input:sub(last + 4)
      return self:request(c, header)
    end
    return true
  end
  -- Client messages are small, unfragmented, masked text/control frames only.
  if #c.input > 2048 then return false, "websocket_buffer" end
  for _ = 1, 16 do
    if #c.input < 2 then break end
    local a, b = c.input:byte(1, 2)
    local op, n = a % 16, b % 128
    if a < 128 or bit.band(a, 112) ~= 0 or b < 128 or n > MAX_INPUT
        or n >= 126 or (op ~= 1 and op ~= 8 and op ~= 9 and op ~= 10) then return false, "websocket_header" end
    if #c.input < n + 6 then break end
    local key, chars = { c.input:byte(3, 6) }, {}
    for i = 1, n do chars[i] = string.char(bit.bxor(c.input:byte(i + 6), key[(i - 1) % 4 + 1])) end
    local text = table.concat(chars)
    c.input = c.input:sub(n + 7)
    if op == 8 then return false, "peer_closed"
    elseif op == 9 then
      -- Never insert control bytes halfway through a partially sent frame.
      if c.out then return false, "ping_during_write" end
      c.out, c.sent = packet(10, text), 0
    elseif op == 1 and not self:message(c, text) then return false, "client_message" end
  end
  return true
end

function Phone:poll()
  if not self.listener then return end
  self:refreshAddress()
  self:updatePairing()
  if not self.listener then return end
  self:pollVideo()
  if not self.listener then return end
  local now = self:now()
  if self.perf then
    self.pollGap = self.lastPoll and now - self.lastPoll or 0
    self.lastPoll = now
    self.perf:sample("phone_poll_gap", self.pollGap * 1000)
  end
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
    local reason = not ok and "timeout" or nil
    if ok and (self.viewer == c or not c.out) then ok, reason = self:read(c) end
    if ok and c.profilePending and not c.out then
      c.out, c.sent, c.profilePending = packet(1, "p,1"), 0, nil
    end
    if ok and c.controls and not c.out then
      c.out, c.sent, c.controls = packet(1, "c," .. c.controls), 0, nil
    end
    if ok and c.heartbeat and not c.out then c.out, c.sent, c.heartbeat = packet(1, "h"), 0, nil end
    -- Drain completed packets in this poll; partial writes always retain ownership.
    for _ = 1, VIDEO_QUEUE + 1 do
      if not ok then break end
      if not c.out and c.videoQueue and #c.videoQueue > 0 then
        local value = table.remove(c.videoQueue, 1)
        c.videoBytes = c.videoBytes - #value.bytes
        c.out, c.sent, c.frame = value.bytes, 0, value.id
        c.pending[#c.pending + 1] = { id = value.id, at = now, w = value.w, h = value.h,
          capturedAt = value.capturedAt }
        if #c.pending > HISTORY then table.remove(c.pending, 1) end
      end
      if not c.out then break end
      local measured, before = self.perf and self.perf:start(), c.sent
      local last, err, partial = c.sock:send(c.out, c.sent + 1, math.min(#c.out, c.sent + 262144))
      c.sent = last or partial or c.sent
      if self.perf then
        self.perf:finish("phone_send", measured)
        self.perf:count("phone_wire_bytes", c.sent - before)
        if err == "timeout" then self.perf:count("phone_partial_writes") end
      end
      if err and err ~= "timeout" then ok, reason = false, "write_error" end
      if c.sent == #c.out then
        c.out = nil
        if not c.ws then ok = false end
      else break end
    end
    if not ok then self:drop(c, reason); table.remove(self.clients, i) end
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
