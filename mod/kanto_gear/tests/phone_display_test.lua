-- Protocol, pairing, bounded transport and disconnect behavior without a ROM.
local root = os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local Phone = assert(loadfile(root .. "/phone_display.lua"))()
local bit = require("bit")
local now, incoming = 0, {}
local function sock()
  return { input = "", output = "", limit = math.huge,
    settimeout = function() end, setoption = function() end,
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
    hash = function(kind, value) assert(kind == "sha1"); hashInput = value; return "hash" end,
    encode = function(container, encoding, value)
      assert(container == "string" and encoding == "base64"); encodeInput = value
      return "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
    end,
  } }
local mod = { read = function(_, name) assert(name == "phone.html"); return "<html>Gear</html>" end }
local function new() return assert(Phone.new(mod, runtime, sockets)) end
local labels, box = {}, nil
local graphics = {
  push = function() end, pop = function() end, origin = function() end,
  setScissor = function() end, setShader = function() end, setColor = function() end,
  newFont = function() return { getWidth = function(_, s) return #s * 6 end } end,
  setFont = function() end, getDimensions = function() return 1240, 1080 end,
  setCanvas = function() error("pairing HUD must preserve the host render target") end,
  rectangle = function(_, x, y, w, h) box = { x = x, y = y, w = w, h = h } end,
  printf = function(s, x, y, w, align)
    assert(align == "center"); labels[#labels + 1] = { s = s, x = x, y = y, w = w }
  end,
}
local status = new()
Phone.drawStatus(status, graphics, { width = 640, height = 576 })
assert(#labels == 3 and labels[2].s == status.url and labels[3].s:find(status.pin, 1, true))
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
local function connect(phone, pin, origin)
  local c = sock(); c.input = request("/gear?pin=" .. (pin or phone.pin), origin)
  incoming[#incoming + 1] = c; phone:poll(); return c
end
local function masked(text, op)
  local chars = {}
  for i = 1, #text do chars[i] = string.char(bit.bxor(text:byte(i), (i - 1) % 4 + 1)) end
  return string.char(128 + (op or 1), 128 + #text, 1, 2, 3, 4) .. table.concat(chars)
end
local function message(phone, c, text) c.input = c.input .. masked(text); phone:poll() end
local image = { getString = function() return string.rep("\255\0\0\255", 240 * 216) end }

local phone = new()
local http = sock(); http.input = request("/")
incoming[1] = http; phone:poll()
assert(http.closed and http.output:find("200 OK", 1, true) and http.output:find("<html>", 1, true))
assert(not phone:detected() and not phone:canCapture())
local bad = connect(phone, "00000000")
assert(bad.closed and bad.output:find("403 Forbidden", 1, true) and not phone:detected())
local cross = connect(phone, nil, "http://evil.example")
assert(cross.closed and not phone:detected())
local rebinding = sock(); rebinding.input = request("/"):gsub("Host: 127.0.0.1", "Host: attacker.example")
incoming[1] = rebinding; phone:poll(); assert(rebinding.closed)
local c = connect(phone)
assert(c.output:find("101 Switching Protocols", 1, true))
assert(hashInput == "dGhlIHNhbXBsZSBub25jZQ==258EAFA5-E914-47DA-95CA-C5AB0DC85B11" and encodeInput == "hash")
assert(phone:detected() and not phone:ready())
local other = connect(phone)
assert(other.closed and other.output:find("409 Conflict", 1, true))
assert(phone:canCapture() and not phone:push(image, 240, 216))
assert(not phone:canCapture(), "no second frame before browser acknowledgement")
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
message(phone, c, "a,999"); assert(phone.viewer.awaiting, "forged acknowledgement cannot clear backpressure")
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
print("PASS phone pairing, WebSocket framing, input validation, flow control, heartbeat and cleanup")
