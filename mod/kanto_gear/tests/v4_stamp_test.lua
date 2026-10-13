package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))

-- The skin rasterises each primitive once into an atlas and draws it as a
-- tinted quad. This software rasteriser compares that path, pixel for pixel,
-- with the plain row-rectangle path the shapes are defined by.
local floor = math.floor

local function canvas()
  local fb, color = {}, "none"
  local G = {}
  local function put(px, py) fb[py * 4096 + px] = color end
  function G.setColor(r, g, b, a) color = string.format("%.3f,%.3f,%.3f,%.3f", r, g, b, a or 1) end
  function G.getColor() return 1, 1, 1, 1 end
  -- a pixel is covered when its centre lies inside the area
  local function cover(x0, y0, x1, y1, fn)
    if x1 < x0 then x0, x1 = x1, x0 end
    if y1 < y0 then y0, y1 = y1, y0 end
    for py = floor(y0 - 0.5) + 1, math.ceil(y1 - 0.5) - 1 + 1 do
      for px = floor(x0 - 0.5) + 1, math.ceil(x1 - 0.5) - 1 + 1 do
        local cx, cy = px + 0.5, py + 0.5
        if cx >= x0 and cx < x1 and cy >= y0 and cy < y1 then fn(px, py, cx, cy) end
      end
    end
  end
  function G.rectangle(mode, x, y, w, h)
    assert(mode == "fill")
    cover(x, y, x + w, y + h, put)
  end
  function G.newQuad(x, y, w, h)
    local q = { x = x, y = y, w = w, h = h }
    function q:setViewport(nx, ny, nw, nh) self.x, self.y, self.w, self.h = nx, ny, nw, nh end
    return q
  end
  function G.newImage(data)
    local img = { pix = {} }
    for k, v in pairs(data.pix) do img.pix[k] = v end
    function img:setFilter() end
    function img:replacePixels(d, _, _, ox, oy)
      for yy = 0, d.h - 1 do for xx = 0, d.w - 1 do
        self.pix[(oy + yy) * 4096 + ox + xx] = d.pix[yy * 4096 + xx]
      end end
    end
    return img
  end
  function G.draw(img, q, x, y, r, sx, sy)
    sx, sy = sx or 1, sy or 1
    cover(x, y, x + q.w * sx, y + q.h * sy, function(px, py, cx, cy)
      local u, v = floor((cx - x) / sx), floor((cy - y) / sy)
      if img.pix[(q.y + v) * 4096 + q.x + u] then put(px, py) end
    end)
  end
  return G, fb
end

local function imageData(w, h)
  local d = { w = w, h = h, pix = {} }
  function d:setPixel(x, y, _, _, _, a) if a > 0 then self.pix[y * 4096 + x] = true end end
  return d
end

local function skin(stamped)
  local G, fb = canvas()
  love = { graphics = G, image = { newImageData = imageData } }
  local ui = { graphics = stamped and G or setmetatable({}, { __index = G }) }
  local H = { setVariant = function() end }
  local K = assert(loadfile(root .. "/ui/skins/init.lua"))()(H, ui, nil)
  return K, fb, H
end

local stampK, stampFb, stampH = skin(true)
local rowK, rowFb = skin(false)
T.check(stampH.v4StampReady(), "atlas is available with a real graphics module")

local function same(label)
  local diff = 0
  for k, v in pairs(stampFb) do if rowFb[k] ~= v then diff = diff + 1 end end
  for k, v in pairs(rowFb) do if stampFb[k] ~= v then diff = diff + 1 end end
  for k in pairs(stampFb) do stampFb[k] = nil end
  for k in pairs(rowFb) do rowFb[k] = nil end
  return diff == 0, label
end
local function both(name, ...)
  stampK[name](...); rowK[name](...)
end

local C = { 0.2, 0.4, 0.6, 1 }
local fails = 0
local function expect(label)
  local ok = same(label)
  if not ok then fails = fails + 1; T.check(false, label) end
end

for w = 1, 34, 3 do for h = 1, 34, 3 do for r = 0, 10, 2 do
  both("RR", 5, 7, w, h, r, C); expect(("RR %d %d %d"):format(w, h, r))
  both("CH", 5, 7, w, h, r, C); expect(("CH %d %d %d"):format(w, h, r))
  both("RRrows", 5, 7, w, h, r, 2, h - 3, C); expect(("RRrows %d %d %d"):format(w, h, r))
  both("CHrows", 5, 7, w, h, r, -1, floor(h / 2), C); expect(("CHrows %d %d %d"):format(w, h, r))
end end end
-- large shapes take the band path
for _, s in ipairs({ { 226, 41, 6 }, { 184, 97, 10 }, { 200, 30, 3 }, { 120, 60, 4 } }) do
  both("RR", 3, 2, s[1], s[2], s[3], C); expect("RR band " .. s[1])
  both("CH", 3, 2, s[1], s[2], s[3], C); expect("CH band " .. s[1])
  both("RRrows", 3, 2, s[1], s[2], s[3], 0, 9, C); expect("RRrows band " .. s[1])
end
for d = 1, 64 do
  both("CIRC", 4, 9, d, C); expect("CIRC " .. d)
  both("CIRCrows", 4, 9, d, 1, floor(d / 2) + 1, C); expect("CIRCrows " .. d)
  for t = 1, 3 do both("RING", 4, 9, d, t, C); expect(("RING %d %d"):format(d, t)) end
end
both("RING", 28, 29, 184, 3, C); expect("backdrop ring")
both("R", 3, 4, 17, 9, C); expect("R")
both("R", 3.5, 4, 2, 9, C); expect("R fractional")
local art = { "..oooo", "..ommo", ".oomoo", "omoomo", "omoom.", "oomoo.", ".ooo.." }
both("ART", art, 10, 12, { o = C, m = { 1, 0, 0, 1 } }); expect("ART two colours")
both("ART", { "..oooo", "..ommo", ".oomoo", "omoomo", "omoom.", "oomoo.", ".ooo.." }, 10, 12,
  { m = C }); expect("ART same art, fresh table, partial palette")
T.eq(fails, 0, "stamped primitives match the row geometry")

T.finish("v4 primitive stamps")
