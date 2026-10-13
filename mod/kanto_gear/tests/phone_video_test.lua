local root = os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local Video = assert(loadfile(root .. "/phone/video.lua"))()
local function u16(s, at) local a,b = s:byte(at, at + 1); return a * 256 + b end
local function u32(s, at) return u16(s, at) * 65536 + u16(s, at + 2) end
local function decode(body, previous)
  local magic, w, h, id = body:sub(1,4), u16(body,5), u16(body,7), u32(body,9)
  local pixels = body:sub(13)
  if magic == "KG04" or magic == "KG06" then
    assert(previous and previous.id == u32(body,13) and previous.w == w and previous.h == h)
    local result, at, stride = previous.rgba, 19, w * 4
    for _ = 1, u16(body,17) do
      local y,x,n = u16(body,at), u16(body,at+2), u16(body,at+4); at = at + 6
      local sy,sx = 65535,0
      if magic == "KG06" then sy,sx=u16(body,at),u16(body,at+2);at=at+4 end
      assert(y < h and x + n <= w and n > 0)
      local offset = y * stride + x * 4
      local bytes
      if sy == 65535 then bytes=body:sub(at,at+n*4-1);at=at+n*4
      else bytes=previous.rgba:sub(sy*stride+sx*4+1,sy*stride+(sx+n)*4) end
      result = result:sub(1,offset) .. bytes .. result:sub(offset+n*4+1)
    end
    assert(at == #body + 1); pixels = result
  else assert(magic == "KG01") end
  assert(#pixels == w * h * 4)
  return { rgba = pixels, w = w, h = h, id = id }
end
local function identity(s) return s end
local previous, shown, full, delta = nil, nil, 0, 0
math.randomseed(421)
for i = 1, 180 do
  local w,h = i < 121 and 240 or 160, i < 121 and 216 or 144
  local rgba = previous and previous.w == w and previous.rgba or string.rep("\10\20\30\255",w*h)
  if i % 19 == 0 then
    rgba = string.rep(string.char(i % 256, 42, 53, 255),w*h)
  else
    for _ = 1, 9 do
      local offset = math.random(0,w*h-1)*4
      rgba = rgba:sub(1,offset) .. string.char(math.random(0,255),math.random(0,255),math.random(0,255),math.random(0,255)) .. rgba:sub(offset+5)
    end
  end
  local body, nextImage = Video.encode(rgba,w,h,i,previous,identity)
  assert(body)
  if body:sub(1,4) == "KG04" or body:sub(1,4) == "KG06" then delta = delta + 1 else full = full + 1 end
  shown = decode(body,shown); assert(shown.rgba == rgba and shown.id == i, "every RGBA byte survives incremental video")
  local unchanged, same = Video.encode(rgba,w,h,i+1,nextImage,identity)
  assert(not unchanged and same == nextImage, "duplicate images need no network payload or new dependency")
  previous = nextImage
end
assert(full > 2 and delta > 150, "scene changes and sparse motion exercise both wire formats")
assert(not pcall(Video.encode,previous.rgba,241,216,1,nil,identity), "invalid dimensions are rejected before encoding")
local compressed = Video.encode(string.rep("\0",16),2,2,1,nil,function() return "z" end)
assert(compressed:sub(1,4) == "KG02")
local rgba = {}
for i=1,240*216 do rgba[i]=string.char(i%251,math.floor(i/240)%251,i%127,255) end
rgba=table.concat(rgba)
local body, base = Video.encode(rgba,240,216,1,nil,identity)
shown=decode(body)
for i=2,80 do
  local rows={}
  for y=0,215 do
    local sy=math.max(0,math.min(215,y+(i%2==0 and 1 or -1)))
    local row=base.rgba:sub(sy*960+1,sy*960+960)
    rows[y+1]=row:sub(5)..row:sub(1,4)
  end
  local moved=table.concat(rows)
  body,base=Video.encode(moved,240,216,i,base,identity)
  assert(body:sub(1,4)=="KG06" and #body<8000, "scrolling reuses exact previous image spans")
  shown=decode(body,shown);assert(shown.rgba==moved, "horizontal and vertical copies read the untouched previous image")
end
print("PASS lossless row patches, alpha, scene changes, resolution changes and duplicate suppression")
local clock = 0
local profile = { clock = function() clock = clock + .001; return clock end }
local measured, measuredBase = Video.encode(rgba,240,216,90,nil,identity,nil,profile)
local ordinary = Video.encode(rgba,240,216,90,nil,identity)
assert(measured == ordinary and profile.diff > 0 and profile.compress > 0,
  "diagnostics preserve wire bytes while isolating diff and compression")
local duplicate = { clock = profile.clock }
local unchanged = Video.encode(rgba,240,216,91,measuredBase,identity,nil,duplicate)
assert(not unchanged and duplicate.diff > 0 and not duplicate.compress,
  "duplicate detection never attributes time to compression")

-- Changing both edges around a repeated middle must not trigger exhaustive scans.
for _, middle in ipairs({ string.rep("\230\230\230\255",224),
    string.rep("\230\230\230\255\80\80\80\255",112) }) do
  local function edges(pixel)
    return string.rep(string.rep(pixel,8) .. middle .. string.rep(pixel,8),216)
  end
  local before, after = edges("\0\0\0\255"), edges("\40\40\40\255")
  local first, base = Video.encode(before,240,216,1,nil,identity)
  local byte, reads = string.byte, 0
  string.byte = function(...)
    reads = reads + 1
    assert(reads < 2000000, "repeated backgrounds exhaust the pixel comparison budget")
    return byte(...)
  end
  local ok, second = pcall(Video.encode,after,240,216,2,base,identity)
  string.byte = byte
  assert(ok, second)
  assert(decode(second,decode(first)).rgba == after,
    "bounded search falls back without losing edge changes or repeated pixels")
end
print("PASS repeated-background comparison budget and exact fallback pixels")
