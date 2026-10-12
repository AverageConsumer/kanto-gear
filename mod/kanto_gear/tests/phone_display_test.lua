-- Protocol, pairing, bounded transport and disconnect behavior without a ROM.
local root = os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local Phone = assert(loadfile(root .. "/phone_display.lua"))()
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
  assert(name == "phone.html" or name == "phone.js")
  return name == "phone.html" and "<html>Gear</html>" or "/* phone controller */"
end }
local unique = 0
local function new()
  local queued
  local pairing = {
    request = function(_, url)
      unique = unique + 1
      queued = { pin = string.format("%08d", 12345678 + unique), secret = string.format("%032x", unique),
        size = 21, runs = { { 0, 0, 7 } } }
    end,
    pop = function() local value = queued; queued = nil; return value end,
    stop = function() queued = nil end,
  }
  return assert(Phone.new(mod, runtime, sockets, pairing))
end
local labels, box = {}, nil
local graphics = {
  push = function() end, pop = function() end, origin = function() end,
  setScissor = function() end, setShader = function() end, setColor = function() end,
  newFont = function() return { getWidth = function(_, s) return #s * 6 end } end,
  setFont = function() end, getDimensions = function() return 1240, 1080 end,
  setCanvas = function() error("pairing HUD must preserve the host render target") end,
  rectangle = function(_, x, y, w, h) if not box then box = { x = x, y = y, w = w, h = h } end end,
  printf = function(s, x, y, w, align)
    assert(align == "center"); labels[#labels + 1] = { s = s, x = x, y = y, w = w }
  end,
}
local status = new()
Phone.drawStatus(status, graphics, { width = 640, height = 576 })
assert(#labels == 5 and labels[2].s == status.url and labels[3].s:find(status.pin, 1, true))
assert(box.x * 2 + box.w == 640 and box.y + box.h == 568,
  "pairing HUD is centered in the current viewport with an eight-pixel bottom gap")
labels = {}; Phone.drawStatus({ ready = function() return true end }, graphics)
assert(#labels == 0, "an acknowledged viewer hides the pairing HUD")
labels = {}; Phone.drawStatus({ error = "no socket" }, graphics)
assert(labels[1].s == "PHONE DISPLAY UNAVAILABLE", "server failures remain visible")
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
message(phone, c, "a,999"); assert(#phone.viewer.pending == 1, "forged acknowledgement cannot clear backpressure")
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
phone:push(image, 240, 216); phone:poll(); now = now + 1.01; phone:poll()
assert(c.closed and not phone:detected(), "a browser that stops displaying frames is disconnected")
phone = new(); c = connect(phone)
phone:push(image, 240, 216); phone:poll()
now = now + 1 / 60
assert(phone:canCapture(), "the second frame does not wait for the first display acknowledgement")
phone:push(image, 240, 216); phone:poll()
now = now + 1 / 60
assert(not phone:canCapture() and #phone.viewer.pending == 2, "a stalled browser is bounded to two frames")
message(phone, c, "a,2")
assert(phone.viewer.ack == 2 and #phone.viewer.pending == 0, "displaying the newest frame also retires skipped older frames")
message(phone, c, "a,1"); assert(phone.viewer.ack == 2, "late acknowledgements cannot roll input back")
for _ = 1, 60 do
  assert(phone:reserveCapture(), "60 Hz capture reservation must keep pace")
  now = now + 1 / 60
  phone:push(image, 240, 216); phone:poll(); message(phone, c, "a," .. phone.sequence)
end
assert(phone.sequence == 62, "asynchronous readback sustains sixty new frames per second")
for _ = 1, 60 do
  local captureAt = now
  now = now + .009
  assert(phone:reserveCapture(captureAt), "drawing time must not shift capture onto every other host frame")
  phone:push(image, 240, 216); phone:poll(); message(phone, c, "a," .. phone.sequence)
  now = captureAt + 1 / 60
end
assert(phone.sequence == 122, "a nine-millisecond draw still leaves sixty capture slots per second")
runtime.data.compress = function() return "compressed" end
c.limit = 0
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
phone = assert(Phone.new(mod,runtime,sockets,async))
assert(not phone.pin and connect(phone,"12345678").closed, "pending entropy never falls back to a guessed code")
produced = { error = "No secure entropy" }; phone:poll()
assert(phone.error and not phone.listener and not phone:detected(), "entropy failure shuts the server down")
print("PASS phone pairing, WebSocket framing, input validation, flow control, heartbeat and cleanup")
