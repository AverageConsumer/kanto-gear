-- Protocol, pairing, bounded transport and disconnect behavior without a ROM.
local root = os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local Phone = assert(loadfile(root .. "/phone/display.lua"))()
local bit = require("bit")
local now, incoming = 0, {}
local function sock()
  return { input = "", output = "", limit = math.huge,
    settimeout = function() end, setoption = function() end,
    getpeername = function() return "192.168.1.42" end,
    bind = function() return true end, listen = function() return true end,
    accept = function() return table.remove(incoming, 1) end,
    close = function(self) self.closed = true end,
    receive = function(self, size)
      local part = self.input:sub(1, size); self.input = self.input:sub(size + 1)
      return nil, "timeout", part
    end,
    send = function(self, bytes, first, last)
      last = math.min(last, first + self.limit - 1)
      self.output = self.output .. bytes:sub(first, last)
      if last < #bytes then return nil, "timeout", last end
      return last
    end,
  }
end
local sockets = { tcp4 = sock, udp = function() end }
local hashInput, encodeInput
local runtime = { timer = { getTime = function() return now end },
  math = { random = function() return 12345678 end }, data = {
    compress = function(container, format, value, level)
      assert(container == "string" and format == "zlib" and level == 1)
      return value
    end,
    hash = function(kind, value) assert(kind == "sha1"); hashInput = value; return "hash" end,
    encode = function(container, encoding, value)
      assert(container == "string" and encoding == "base64"); encodeInput = value
      return "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
    end,
  } }
local mod = { read = function(_, name)
  assert(name == "phone/phone.html" or name == "phone/phone.js" or name == "phone/phone_decoder.js")
  return name == "phone/phone.html" and "<html>Gear</html>" or "/* phone controller */"
end }
local unique = 0
local function new(perf)
  local queued
  local pairing = {
    request = function(_, url)
      unique = unique + 1
      queued = { url = url, pin = string.format("%08d", 12345678 + unique), secret = string.format("%032x", unique),
        size = 21, runs = { { 0, 0, 7 } } }
    end,
    pop = function() local value = queued; queued = nil; return value end,
    stop = function() queued = nil end,
  }
  local encoded
  local video = {
    request = function(_, job)
      local function u16(n) return string.char(math.floor(n / 256) % 256, n % 256) end
      local payload = runtime.data.compress("string", "zlib", job.rgba, 1)
      local compressed = #payload < #job.rgba
      encoded = { epoch = job.epoch, id = job.id, body = (compressed and "KG02" or "KG01")
        .. u16(job.w) .. u16(job.h) .. u16(math.floor(job.id / 65536)) .. u16(job.id % 65536)
        .. (compressed and payload or job.rgba) }
    end,
    pop = function() local result = encoded; encoded = nil; return result end,
    stop = function() encoded = nil end,
  }
  return assert(Phone.new(mod, runtime, sockets, pairing, video, perf))
end
local labels, boxes = {}, {}
local graphics = {
  push = function() end, pop = function() end, origin = function() end,
  setScissor = function() end, setShader = function() end, setColor = function() end,
  newFont = function() return { getWidth = function(_, s) return #s * 6 end, getHeight = function() return 12 end } end,
  setFont = function() end, getDimensions = function() return 1240, 1080 end,
  setCanvas = function() error("pairing HUD must preserve the host render target") end,
  rectangle = function(_, x, y, w, h) boxes[#boxes + 1] = { x = x, y = y, w = w, h = h } end,
  polygon = function() end,
  print = function(s, x, y) labels[#labels + 1] = { s = s, x = x, y = y } end,
}
local function shown(text)
  for _, label in ipairs(labels) do if label.s:find(text, 1, true) then return true end end
end
local status = new()
local recovery = Phone.drawStatus(status, graphics, { width = 640, height = 576 })
assert(recovery and shown("USE ONE SCREEN"), "unpaired phone mode always offers a local exit")
local card = boxes[3] -- shadow, rim, then the card body
assert(shown((status.url:gsub("^http://", ""))) and shown(status.pin:sub(1, 4)) and shown(status.pin:sub(5, 8)),
  "pairing card shows the address and the eight-digit code")
assert(card.x > 320 and card.x + card.w <= 640 - 8 and card.y >= 0 and card.y + card.h <= 576,
  "pairing card is docked to the right edge inside the current viewport")
labels = {}; Phone.drawStatus({ ready = function() return true end }, graphics)
assert(#labels == 0, "an acknowledged viewer hides the pairing HUD")
labels = {}; Phone.drawStatus({ error = "no socket" }, graphics)
assert(shown("PHONE DISPLAY UNAVAILABLE") and shown("no socket"), "server failures remain visible")
local function pixelFont(width, height)
  return { getWidth = function(_, s) return #s * width end, getHeight = function() return height end }
end
local preview = { url = status.url, pin = status.pin, expires = 300, now = function() return 0 end,
  qr = { size = 37, runs = { { 0, 0, 37 } } } }
for _, size in ipairs({ {320,288}, {320,568}, {393,852}, {402,874}, {640,576},
    {942,2048}, {1206,2622}, {1280,720}, {1920,1080} }) do
  for _, skin in ipairs({ "pokegear", "cgear" }) do for _, dark in ipairs({ false, true }) do
    boxes, labels = {}, {}
    local layout = Phone.drawStatus(preview, graphics, { width = size[1], height = size[2] },
      { skin = skin, dark = dark, font = pixelFont(6,7), small = pixelFont(5,7), large = pixelFont(12,14) })
    local body = boxes[3]
    assert(body.x >= 0 and body.y >= 0 and body.x + body.w <= size[1] and body.y + body.h <= size[2],
      "pairing card fits small and large viewports in every skin")
    for _, box in ipairs(boxes) do assert(box.w >= 0 and box.h >= 0, "pixel icons never have negative dimensions") end
    assert(shown("expires in 5:00"), "expiry stays visible alongside the QR and PIN")
    local exit = layout.exit
    assert(shown("USE ONE SCREEN") and exit.x >= body.x and exit.x + exit.w <= body.x + body.w
      and exit.y >= body.y and exit.y + exit.h <= body.y + body.h,
      "portrait and landscape recovery controls stay inside the visible card")
    assert(exit.y + exit.h < size[2] * .7, "local exit stays above the lower touch controls")
  end end
end
status:stop()
local function request(path, origin)
  return "GET " .. path .. " HTTP/1.1\r\nHost: 127.0.0.1:8765\r\n"
    .. "Origin: " .. (origin or "http://127.0.0.1:8765") .. "\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
    .. "Sec-WebSocket-Version: 13\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n"
end
local function masked(text, op)
  local chars = {}
  for i = 1, #text do chars[i] = string.char(bit.bxor(text:byte(i), (i - 1) % 4 + 1)) end
  return string.char(128 + (op or 1), 128 + #text, 1, 2, 3, 4) .. table.concat(chars)
end
local function message(phone, c, text) c.input = c.input .. masked(text); phone:poll() end
local function connect(phone, pin, origin, noAuth)
  local c = sock(); c.input = request("/gear", origin)
  incoming[#incoming + 1] = c; phone:poll()
  if not c.closed and not noAuth then message(phone, c, "auth," .. (pin or phone.pin)) end
  return c
end
local image = { getString = function() return string.rep("\255\0\0\255", 240 * 216) end }

local phone = new()
local http = sock(); http.input = request("/")
incoming[1] = http; phone:poll()
assert(http.closed and http.output:find("200 OK", 1, true) and http.output:find("<html>", 1, true))
assert(not phone:detected() and not phone:canCapture())
local script = sock(); script.input = request("/phone.js")
incoming[1] = script; phone:poll()
assert(script.closed and script.output:find("text/javascript", 1, true)
  and script.output:find("/* phone controller */", 1, true), "browser logic is served locally")
local bad = connect(phone, "00000000")
assert(bad.closed and not phone:detected())
local cross = connect(phone, nil, "http://evil.example")
assert(cross.closed and not phone:detected())
local rebinding = sock(); rebinding.input = request("/"):gsub("Host: 127.0.0.1", "Host: attacker.example")
incoming[1] = rebinding; phone:poll(); assert(rebinding.closed)
local c = connect(phone)
assert(c.output:find("101 Switching Protocols", 1, true))
assert(hashInput == "dGhlIHNhbXBsZSBub25jZQ==258EAFA5-E914-47DA-95CA-C5AB0DC85B11" and encodeInput == "hash")
phone:poll()
assert(phone:detected() and not phone:ready())
local other = connect(phone)
assert(other.closed and other.output:find("409 Conflict", 1, true))
c.limit = 0
assert(phone:canCapture() and not phone:push(image, 240, 216))
assert(not phone:canCapture(), "a partially written frame prevents another capture")
c.output = ""; c.limit = 1000; phone:poll()
assert(#c.output == 1000 and phone.viewer.sent == 1000, "short socket writes keep absolute progress")
local bytes = phone.viewer.out
assert(bytes:byte(1) == 130 and bytes:byte(2) == 127 and bytes:sub(11, 14) == "KG01")
assert(bytes:sub(15, 18) == string.char(0, 240, 0, 216))
assert(#bytes == 10 + 12 + 240 * 216 * 4)
for _ = 1, 4 do phone:push(image, 240, 216) end
assert(phone.viewer.out == bytes and phone.sequence == 1, "slow clients never accumulate frames")
c.limit = math.huge; phone:poll()
assert(not phone.viewer.out)
message(phone, c, "a,1"); assert(phone:ready())
assert(not phone:canCapture(), "frame rate is bounded")
now = .034; assert(phone:canCapture())
message(phone, c, "down,239,215,1")
message(phone, c, "move,120,108,1")
message(phone, c, "move,121,109,1")
message(phone, c, "up,121,109,1")
assert(phone.bridge.pollTouch() == "down,239,215")
assert(phone.bridge.pollTouch() == "move,121,109")
assert(phone.bridge.pollTouch() == "up,121,109" and not phone.bridge.pollTouch())
message(phone, c, "down,1,1,1"); assert(phone.bridge.pollTouch() == "down,1,1")
assert(phone:push(image, 240, 216)); phone:poll()
message(phone, c, "up,1,1,1")
assert(phone.bridge.pollTouch() == "up,1,1", "a frame in flight cannot cancel an ordinary tap")
message(phone, c, "down,120,108,1")
message(phone, c, "move,140,108,1")
message(phone, c, "up,140,108,1")
assert(phone.bridge.pollTouch() == "down,120,108"
  and phone.bridge.pollTouch() == "move,140,108"
  and phone.bridge.pollTouch() == "up,140,108", "the displayed frame stays touchable during transmission")
message(phone, c, "a,999"); assert(#phone.viewer.pending == 2 and phone.viewer.ack == 1, "forged acknowledgement cannot select a displayed frame")
message(phone, c, "a,2")
message(phone, c, "down,10,20,2"); assert(phone.bridge.pollTouch() == "down,10,20")
now = .068; assert(phone:push(image, 240, 216)); phone:poll(); message(phone, c, "a,3")
message(phone, c, "move,30,20,3"); message(phone, c, "up,30,20,3")
assert(phone.bridge.pollTouch() == "move,30,20" and phone.bridge.pollTouch() == "up,30,20",
  "a gesture can finish on the next displayed frame")
message(phone, c, "down,10,20,2"); assert(not phone.bridge.pollTouch(), "superseded frame IDs remain invalid")
message(phone, c, "down,10,20,3"); assert(phone.bridge.pollTouch() == "down,10,20")
message(phone, c, "up,10,20,2")
assert(phone.bridge.pollTouch() == "cancel,0,0", "an invalid release still clears held controls")
for i = 1, 10 do now = i * .2; message(phone, c, "h,3") end
assert(phone:detected() and not phone.viewer.out, "idle clients stay alive without new images")
now = 3.6; phone:poll()
assert(c.closed and not phone:detected() and phone.bridge.pollTouch() == "cancel,0,0")

phone = new(); c = connect(phone)
phone:push(image, 240, 216); phone:poll(); now = now + 1.51; phone:poll()
assert(c.closed and not phone:detected(), "a browser that stops sending heartbeats is disconnected")
phone = new(); c = connect(phone)
phone:push(image, 240, 216); phone:poll()
now = now + 1 / 30
assert(phone:canCapture(), "the second frame does not wait for the first display acknowledgement")
phone:push(image, 240, 216); phone:poll()
now = now + 1 / 30
assert(phone:canCapture(), "ordinary Wi-Fi latency does not stop a two-frame pipeline")
phone:push(image, 240, 216); phone:poll(); now = now + 1 / 30
phone:push(image, 240, 216); phone:poll(); now = now + 1 / 30
assert(phone:canCapture() and #phone.viewer.pending == 4, "delayed display acknowledgements do not stall capture")
message(phone, c, "a,4")
assert(phone.viewer.ack == 4 and #phone.viewer.pending == 1, "displaying the newest frame also retires skipped older frames")
message(phone, c, "a,1"); assert(phone.viewer.ack == 4, "late acknowledgements cannot roll input back")
for _ = 1, 30 do
  assert(phone:reserveCapture(), "30 Hz capture reservation must keep pace")
  now = now + 1 / 30
  phone:push(image, 240, 216); phone:poll(); message(phone, c, "a," .. phone.sequence)
end
assert(phone.sequence == 34, "asynchronous readback sustains thirty new frames per second")
for _ = 1, 30 do
  local captureAt = now
  now = now + .009
  assert(phone:reserveCapture(captureAt), "drawing time must not consume the next capture slot")
  phone:push(image, 240, 216); phone:poll(); message(phone, c, "a," .. phone.sequence)
  now = captureAt + 1 / 30
end
assert(phone.sequence == 64, "a nine-millisecond draw still leaves thirty capture slots per second")
for i = 1, 60 do
  now = now + 1 / 30 + (i % 2 == 0 and .002 or -.002)
  assert(phone:reserveCapture(), "normal host scheduling jitter must not halve the stream cadence")
  phone:push(image,240,216);phone:poll();message(phone,c,"a,"..phone.sequence)
end
assert(phone.sequence == 124, "capture keeps thirty Hz despite alternating early and late host ticks")
runtime.data.compress = function() return "compressed" end
c.limit = 0
now = now + 1 / 30
assert(phone:push(image, 240, 216))
assert(phone.viewer.out:find("KG02", 1, true) and phone.viewer.out:sub(-10) == "compressed",
  "compressible pixels use the lossless wire format")
runtime.data.compress = function(_, _, value) return value end
phone = new(); c = connect(phone)
c.input = string.char(129, 4) .. "h,0"; phone:poll()
assert(c.closed, "unmasked WebSocket traffic is refused")
phone = new(); c = connect(phone)
c.input = masked("down,240,0,1"); phone:poll()
assert(not c.closed, "unacknowledged touches are ignored")
phone:push(image, 240, 216); phone:poll(); message(phone, c, "a,1")
message(phone, c, "down,240,0,1"); assert(c.closed, "coordinates must be inside the actual Gear frame")
phone = new()
for _ = 1, 6 do assert(connect(phone, "00000000").closed) end
local blocked = connect(phone)
assert(blocked.closed and blocked.output:find("429 Too Many Requests", 1, true))
now = now + 61; c = connect(phone); assert(phone:detected())
local old = phone; phone = new()
assert(c.closed and not old.listener, "restarting the mod closes its previous listener")
phone:stop(); assert(not phone.listener)
-- Game buttons have their own held sources, independent of video and Gear touch.
local function game(generation)
  local input = { sources = {}, presses = 0 }
  function input:sourcePress(button, source)
    self.sources[button] = self.sources[button] or {}
    self.sources[button][source] = true
    self.presses = self.presses + 1
  end
  function input:sourceRelease(button, source)
    self.sources[button][source] = nil
  end
  function input:down(button) return self.sources[button] and next(self.sources[button]) ~= nil end
  return { generation = generation, input = input }
end
mod.input = {
  press = function(_, game, button)
    assert(button ~= "l" and button ~= "r", "the public API only accepts GB buttons")
    local token = { input = game.input, button = button }
    game.input:sourcePress(button, token)
    return token
  end,
  release = function(_, token) token.input:sourceRelease(token.button, token) end,
}
phone = new(); local g = game(3); phone:setGame(g); c = connect(phone)
phone:poll()
assert(c.output:find("c,gba", 1, true), "the browser learns which buttons are supported")
message(phone, c, "b,left,1"); message(phone, c, "b,b,1")
assert(g.input:down("left") and g.input:down("b") and not phone:ready(),
  "walking and running do not wait for the first video acknowledgement")
message(phone, c, "b,left,1")
assert(g.input.presses == 2, "duplicate downs never accumulate input tokens")
g.input:sourcePress("left", "keyboard")
message(phone, c, "b,left,0")
assert(g.input:down("left") and not phone.buttons.left, "remote release preserves physical input")
message(phone, c, "b,l,1"); message(phone, c, "b,r,1")
assert(g.input:down("l") and g.input:down("r"), "GBA shoulders use independent engine sources")
message(phone, c, "release")
assert(not g.input:down("b") and not g.input:down("l") and not g.input:down("r")
  and g.input:down("left"), "opening settings releases only the phone's holds")
message(phone, c, "b,a,1"); message(phone, c, "b,a,0")
assert(not g.input:down("a"), "a fast tap is released even without a rendered frame")
message(phone, c, "b,down,1")
local g2 = game(2); phone:setGame(g2); phone:poll()
assert(not g.input:down("down") and c.output:find("c,gb", 1, true), "changing games clears holds and capabilities")
message(phone, c, "b,l,1"); assert(not g2.input:down("l"), "GB games cannot receive GBA-only shoulders")
message(phone, c, "b,a,1"); now = now + 1.51; phone:poll()
assert(c.closed and not g2.input:down("a"), "heartbeat timeout releases every game button")
phone = new(); phone:setGame(g2); c = connect(phone)
message(phone, c, "b,a,1"); message(phone, c, "b,execute,1")
assert(c.closed and not g2.input:down("a"), "invalid input disconnects and releases held buttons")
phone = new(); phone:setGame(g2); c = connect(phone)
message(phone, c, "b,start,1"); phone:stop()
assert(not g2.input:down("start"), "mode changes and shutdown cannot leave Start held")
phone = new(); phone:setGame(g2); c = connect(phone)
message(phone, c, "b,select,1"); local old = phone; phone = new()
assert(not g2.input:down("select") and not old.listener, "reloading releases the previous mod's holds")
mod.input = nil
phone:setGame({ generation = 1, input = {} }); c = connect(phone); phone:poll()
assert(c.output:find("c,none", 1, true), "an older host without safe input keeps display-only mode")
message(phone, c, "b,a,1"); assert(not c.closed and not next(phone.buttons))
phone:stop()
phone = new()
local pin, secret = phone.pin, phone.secret
c = connect(phone, nil, nil, true)
assert(not phone:detected() and not phone:canCapture() and not c.output:find("c,",1,true),
  "an HTTP upgrade alone never grants frames, inputs or capabilities")
message(phone, c, "b,a,1"); assert(c.closed and not phone:detected(), "input before authentication is rejected")
c = connect(phone, secret); assert(phone:detected(), "QR keys authenticate without appearing in the HTTP path")
phone:updatePairing()
assert(phone.pin ~= pin and phone.secret ~= secret, "successful auth consumes both credentials")
message(phone,c,"release"); phone:drop(phone.viewer); phone.clients = {}
assert(connect(phone, secret).closed and connect(phone, pin).closed, "used keys and PINs cannot reconnect")
phone = new(); pin = phone.pin; now = now + 300
assert(connect(phone,pin).closed and not phone:detected(), "expired codes cannot authenticate")
phone = new(); c = connect(phone,nil,nil,true); now = now + 3.01; phone:poll()
assert(c.closed, "unauthenticated sockets have a fixed deadline")
phone = new()
local public = sock(); public.getpeername = function() return "8.8.8.8" end
incoming[1] = public; phone:poll(); assert(public.closed, "nonlocal peers cannot reach the server")
http = sock(); http.input = request("/"); incoming[1] = http; phone:poll()
assert(http.output:find("Referrer-Policy: no-referrer",1,true)
  and http.output:find("script-src 'self';",1,true)
  and http.output:find("Cache-Control: no-store",1,true), "pages refuse caching, referrers and inline scripts")
local query = sock(); query.input = request("/gear?pin=" .. phone.pin); incoming[1] = query; phone:poll()
assert(query.closed and query.output:find("404 Not Found",1,true), "query-string credentials are not accepted")
phone:stop()
assert(not phone.pin and not phone.secret and not phone.qr, "shutdown clears pairing material")
local produced
local async = { request=function() end, pop=function() local p=produced;produced=nil;return p end, stop=function() end }
phone = assert(Phone.new(mod,runtime,sockets,async,
  { request=function() error("no unauthenticated video") end, pop=function() end, stop=function() end }))
assert(not phone.pin and connect(phone,"12345678").closed, "pending entropy never falls back to a guessed code")
produced = { error = "No secure entropy" }; phone:poll()
assert(phone.error and not phone.listener and not phone:detected(), "entropy failure shuts the server down")
local oldUdp, address, probes, routeCloses = sockets.udp, "192.168.1.135", 0, 0
sockets.udp = function()
  probes = probes + 1
  return { settimeout=function() end, setpeername=function() return address ~= nil end,
    getsockname=function() return address end, close=function() routeCloses=routeCloses+1 end }
end
phone = new(); phone:setGame(g2); c=connect(phone);phone:poll()
local oldUrl, oldPin, listener, epoch = phone.url, phone.pin, phone.listener, phone.epoch
assert(oldUrl == "http://192.168.1.135:8765")
for _=1,30 do now=now+.01;phone:poll() end
assert(probes==1, "address detection never opens a socket per frame")
message(phone,c,"b,start,1");phone:push(image,240,216)
local pairedPop=phone.pairing.pop
phone.pairing.pop=function(self)
  self.pop=pairedPop
  return { url=oldUrl, pin="00000000", secret=string.rep("0",32), size=21, runs={} }
end
address="192.168.1.133";now=now+1;phone:poll()
assert(c.closed and not phone.viewer and not g2.input:down("start"), "an address change releases old sockets and held buttons")
assert(phone.listener==listener and not listener.closed and phone.epoch>epoch and not phone.queuedImage,
  "a WLAN change keeps the server alive and discards old video jobs")
assert(phone.url=="http://192.168.1.133:8765" and not phone.pin and not phone.qr,
  "a late QR result for the previous address cannot replace the current pairing card")
phone:poll()
assert(phone.pin and phone.pin~=oldPin and phone.qr.url==phone.url, "the replacement QR and code use the new address")
oldPin=phone.pin;address=nil;now=now+1;phone:poll()
assert(phone.pin==oldPin and phone.url=="http://192.168.1.133:8765", "temporary route loss does not churn pairing credentials")
address="192.168.1.133";now=now+1;phone:poll()
assert(phone.pin==oldPin and routeCloses==probes, "an unchanged address preserves pairing and closes every route probe")
local workingUdp=sockets.udp;sockets.udp=function() return nil,"socket unavailable" end
now=now+1;phone:poll();sockets.udp=workingUdp
assert(phone.pin==oldPin and phone.url=="http://192.168.1.133:8765", "a route socket error cannot become a pairing address")
c=connect(phone);assert(phone:detected() and not c.closed, "pairing resumes after a WLAN switch without restarting the game")
phone:stop();sockets.udp=oldUdp
phone = new(); c = connect(phone); phone:poll()
local job, completed
local request, pop = phone.video.request, phone.video.pop
phone.video.request = function(_, value) job = value end
phone.video.pop = function() local result = completed; completed = nil; return result end
now = now + .02
phone:push(image,240,216)
assert(job and not phone.viewer.out and #phone.viewer.pending == 0, "compression never runs on the game thread")
now = now + 1 / 30
assert(phone:canCapture(), "GPU readback overlaps encoding the preceding image")
phone:push(image,240,216)
assert(phone.queuedImage, "one retained capture bounds a slow encoder")
request(phone.video,job); completed = pop(phone.video)
local marker = "heartbeat partly written"
phone.viewer.out, phone.viewer.sent, c.limit = marker, 0, 0
phone:poll()
assert(phone.viewer.out == marker and #phone.viewer.videoQueue == 1 and phone.sequence == 1, "encoding completion cannot corrupt a partially written control packet")
c.limit = math.huge; phone:poll(); phone:poll()
assert(phone.sequence == 1 and job.id == 2, "after the socket drains the next dependent image is encoded")
local oldEpoch = job.epoch
phone:drop(phone.viewer); phone.clients = {}
completed = { epoch = oldEpoch, id = 2, body = "stale" }
phone:poll(); c = connect(phone); phone:poll()
assert(not c.output:find("stale",1,true) and not phone.encoding, "reconnection discards old worker results")
phone:stop()
phone = new(); c = connect(phone); phone:poll()
phone:push(image,240,216);now=now+.12;message(phone,c,"r,1")
assert(phone.viewer.rtt >= .12 and not phone.viewer.ack, "decode receipt measures RTT without changing the displayed touch frame")
message(phone,c,"a,999")
assert(not phone.viewer.ack, "forged acknowledgements cannot select an unknown touch frame")
message(phone,c,"a,1");assert(phone:ready())
for _ = 1, 200 do
  now = now + 1 / 30
  assert(phone:canCapture(), "missing display acknowledgements must not block a healthy transport")
  phone:push(image,240,216);phone:poll();message(phone,c,"h,1")
end
assert(#phone.viewer.pending <= 128, "acknowledgement metadata remains bounded")
phone:stop()
phone = new(); c = connect(phone); phone:poll();phone:step(1/60)
assert(phone:reserveCapture())
phone:push(image,240,216);phone:poll()
now = now + .5
assert(not phone:canCapture(), "wall time cannot create an extra game-frame capture")
phone:step(1/60);assert(phone:canCapture(), "a produced game frame opens the next capture immediately")
phone:stop()
-- The radio may stop accepting writes; capture/encoding must stay bounded and resume at the newest image.
phone = new(); c = connect(phone);phone:poll();c.limit = 0
local captures = 0
for i = 1, 40 do
  now = now + 1/60;phone:step(1/60)
  if phone:canCapture() then captures = captures + 1;phone:push(image,240,216) end
  phone:poll()
end
assert(captures > 1 and captures <= 5 and #phone.viewer.videoQueue <= 3,
  "a partial socket write allows overlap but bounds the video backlog")
local queuedBytes = phone.viewer.videoBytes
assert(queuedBytes <= 512*1024 + 240*216*4+64, "a single final worker result is the only byte-budget overshoot")
c.limit=math.huge;phone:poll();phone:poll()
now=now+1/60;phone:step(1/60)
assert(phone:canCapture(), "draining the socket immediately opens the next game frame")
phone:stop()
-- The wall-clock cap also applies to high-refresh hosts and fast-forward input.
for _, hostRate in ipairs({60,144}) do for _, sourceRate in ipairs({60,120}) do
  phone = new();c=connect(phone);phone:poll()
  phone.game = { _frameSpeed = sourceRate/60 }
  local logical, count = 0, 0
  for host = 1, hostRate*2 do
    now=now+1/hostRate
    local target=math.floor(host*sourceRate/hostRate)
    while logical<target do logical=logical+1;phone:step(1/60) end
    if phone.sourceFrame and phone:canCapture() then
      count=count+1;phone:push(image,240,216);phone:poll();message(phone,c,"h,0")
    end
  end
  assert(count==60, "two seconds produce thirty-FPS capture on normal, high-refresh and fast-forward hosts")
  now = now + 1
  phone:step(1/60);assert(phone:canCapture())
  phone:push(image,240,216)
  now = now + 1/60;phone:step(1/60)
  assert(not phone:canCapture(), "resuming after a stall cannot create a catch-up capture burst")
  phone:stop()
end end
local pairingStopped = false
local Performance = assert(loadfile(root .. "/core/performance.lua"))()
local profileLines = {}
local profile = Performance.new(function() return now end, function(line) profileLines[#profileLines+1]=line end, true)
phone = new(profile); c = connect(phone); phone:poll()
assert(c.output:find("p,1",1,true), "only diagnostic servers enable browser timing")
assert(profile.counters.phone_wire_bytes == #c.output, "wire bytes count actual socket writes including control framing")
phone:push(image,240,216); phone:poll()
now = now + .04; message(phone,c,"r,1")
now = now + .03; message(phone,c,"a,1")
message(phone,c,"p,1,1.000,60.000,0.200,16.667")
message(phone,c,"p,1,1.000,60.000,0.200,16.667")
message(phone,c,"a,1")
assert(profile.metrics.phone_decode_ack.n == 1 and profile.metrics.phone_paint_ack.n == 1,
  "replayed acknowledgements cannot distort timings")
assert(profile.metrics.phone_browser_decode.n == 1 and profile.metrics.phone_browser_interval.total == 16.667,
  "browser timing records the acknowledged image exactly once")
assert(profile.counters.phone_captured == 1 and profile.counters.phone_source_bytes == 240*216*4,
  "capture volume stays separate from actual wire bytes")
assert(not phone:message(phone.viewer,"p,1,1.000,10001.000,0.200,16.667"),
  "unbounded browser timings are rejected")
for _, invalid in ipairs({"p,1,1.000,,0.200,16.667", "p,1,1.000,2.000,3.000,4.000,5.000", "x,unknown"}) do
  assert(not phone:message(phone.viewer,invalid), "diagnostic extensions preserve validation")
end
now=now+.04;phone:step(1/60);phone:push(image,240,216);phone:poll();message(phone,c,"a,2")
message(phone,c,"p,2,2.000,60.000,0.100,33.333,33.333,1.000,0.000,33.000,16.667,0.000")
now=now+.04;phone:step(1/60);phone:push(image,240,216);phone:poll();message(phone,c,"a,3")
message(phone,c,"p,3,2.000,180.000,0.100,400.000,180.000,1.000,110.000,33.000,16.667,2.000")
assert(profile.metrics.phone_browser_interval.max==400 and profile.metrics.phone_browser_dispatch.n==2,
  "long gaps and worker dispatch delays are recorded separately")
assert(profile.counters.phone_browser_dropped==2 and profile.metrics.phone_send_gap.n==1,
  "skipped presentations stay distinguishable from producer gaps")
local traces=0
for _, line in ipairs(profileLines) do if line:find("kind=stutter",1,true) then
  traces=traces+1;assert(line:find("interval=400.000",1,true) and line:find("dropped=2",1,true))
end end
assert(traces==1, "a correlated stutter trace includes source, transport and browser timings")
message(phone,c,"x,contact_timeout")
assert(phone.viewer.browserStop=="contact_timeout", "browser timeout reasons reach the diagnostic server")
phone:stop()
phone = new(profile); c = connect(phone); phone:poll()
local burst = masked("h,0") .. masked("r,0") .. masked("a,0")
  .. masked("p,0,0.100,60.000,0.100,16.667")
c.input = string.rep(burst,60)
for _ = 1, 40 do
  phone:poll()
  assert(not c.closed and phone.viewer, "a valid coalesced input burst must not disconnect the viewer")
  assert(#phone.viewer.input <= 2048, "coalesced input still respects the bounded parser buffer")
end
assert(c.input == "" and phone.viewer.input == "", "a valid burst is completely drained")
phone:stop()
phone = new(profile); c = connect(phone); phone:poll()
local closed = profile.counters.phone_disconnect_peer_closed or 0
c.input = masked("",8); phone:poll()
assert(c.closed and profile.counters.phone_disconnect_peer_closed == closed + 1,
  "diagnostics distinguish a browser close from a parser failure")
phone:stop()
phone = new(profile); c = connect(phone); phone:poll()
local invalid = profile.counters.phone_disconnect_client_message or 0
message(phone,c,"bad")
assert(c.closed and profile.counters.phone_disconnect_client_message == invalid + 1,
  "diagnostics record rejected input without logging the message contents")
phone:stop()
local noWorker = Phone.new(mod,runtime,sockets,
  { request=function()end,pop=function()end,stop=function()pairingStopped=true end })
assert(not noWorker and pairingStopped, "an unavailable video worker cleans up the pairing worker")
print("PASS phone pairing, WebSocket framing, input validation, flow control, heartbeat and cleanup")
