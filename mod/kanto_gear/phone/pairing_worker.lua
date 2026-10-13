-- Runs only with the explicit compute permission; no network, file or game access.
-- Both sources passed to this worker are bundled mod source, never browser data.
local requests, results, qrSource = ...
local ok, random = pcall(function()
  local ffi = require("ffi")
  if ffi.os == "Windows" then
    ffi.cdef[[long __stdcall BCryptGenRandom(void *, unsigned char *, unsigned int, unsigned int);]]
    local bcrypt = ffi.load("bcrypt")
    return function(n)
      local buf = ffi.new("unsigned char[?]", n)
      assert(bcrypt.BCryptGenRandom(nil, buf, n, 2) == 0, "System random unavailable")
      return ffi.string(buf, n)
    end
  end
  ffi.cdef[[int getentropy(void *, size_t);]]
  return function(n)
    local buf = ffi.new("unsigned char[?]", n)
    assert(ffi.C.getentropy(buf, n) == 0, "System random unavailable")
    return ffi.string(buf, n)
  end
end)
if not ok then results:push({ error = "Secure pairing is unavailable on this host." }); return end
local qr = assert(loadstring(qrSource, "@kanto_gear/vendor/qrencode.lua"))()
while true do
  local url = requests:demand()
  if url == false then return end
  local success, result = pcall(function()
    local value
    repeat
      local a,b,c,d = random(4):byte(1,4)
      value = ((a * 256 + b) * 256 + c) * 256 + d
    until value < 4200000000 -- rejection sampling: uniform eight-digit PIN
    local pin = string.format("%08d", value % 100000000)
    local secret = random(16):gsub(".", function(c) return string.format("%02x", c:byte()) end)
    local valid, matrix = qr.qrcode(url .. "/#pair=" .. secret, 2)
    assert(valid, "QR generation failed")
    -- Cache horizontal runs; the main renderer never rebuilds the QR matrix.
    local runs, size = {}, #matrix
    for y = 1, size do
      local x = 1
      while x <= size do
        if matrix[x][y] > 0 then
          local first = x
          repeat x = x + 1 until x > size or matrix[x][y] <= 0
          runs[#runs + 1] = { first - 1, y - 1, x - first }
        else x = x + 1 end
      end
    end
    return { url = url, pin = pin, secret = secret, size = size, runs = runs }
  end)
  results:push(success and result or { error = "Secure pairing is unavailable on this host." })
end
