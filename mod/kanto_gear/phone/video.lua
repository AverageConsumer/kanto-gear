-- Lossless row patches. WebSocket ordering lets each image reuse its predecessor.
local Video = {}
local function u16(n) return string.char(math.floor(n / 256) % 256, n % 256) end
local function u32(n) return u16(math.floor(n / 65536)) .. u16(n % 65536) end
local COPY_ROWS = {0,-1,1,-2,2,-4,4}
local function copyRun(row, old, y, w, h, left, right)
  if right - left < 64 then return end
  local middle = math.floor((left + right - 16) / 8) * 4
  local needle, best = row:sub(middle + 1, middle + 16), nil
  -- Flat spans compress cheaply and cannot identify a useful motion match.
  if needle == string.rep(needle:sub(1,4),4) then return end
  local remaining = 4
  for _, dy in ipairs(COPY_ROWS) do
    local sy = y + dy
    if sy >= 0 and sy < h then
      local offset = sy * w * 4
      local from, to = math.max(0,middle-16), math.min(w*4,middle+32)
      local sample = old:sub(offset+from+1,offset+to)
      local found = sample:find(needle,1,true)
      while found do
        local source = from + found - 1
        if source % 4 == 0 then
          remaining = remaining - 1
          local shift, a, b = source-middle, middle, middle+16
          while a > left and a+shift > 0 and row:byte(a) == old:byte(offset+a+shift) do a=a-1 end
          while b < right and b+shift < w*4 and row:byte(b+1) == old:byte(offset+b+shift+1) do b=b+1 end
          a,b = math.ceil(a/4)*4,math.floor(b/4)*4
          if b-a >= 64 and (not best or b-a > best.last-best.first) then
            best = {first=a,last=b,sy=sy,sx=(a+shift)/4}
            if b-a >= right-left-16 then return best end
          end
          -- Repeated patterns must not expand every possible match in every row.
          if remaining == 0 then return best end
        end
        found = sample:find(needle,found+1,true)
      end
    end
  end
  return best
end

function Video.encode(rgba, w, h, id, previous, compress, at, profile)
  assert(w >= 1 and h >= 1 and w <= 240 and h <= 216 and #rgba == w * h * 4)
  local started = profile and profile.clock()
  local body, delta = rgba, false
  if previous and previous.w == w and previous.h == h then
    if rgba == previous.rgba then
      if profile then profile.diff = (profile.clock() - started) * 1000 end
      return nil, previous
    end
    local rows, copies, stride = {}, false, w * 4
    local function raw(y,left,right,row)
      if right > left then rows[#rows+1] = {y=y,x=left/4,n=(right-left)/4,bytes=row:sub(left+1,right)} end
    end
    for y = 0, h - 1 do
      local first = y * stride + 1
      local row, old = rgba:sub(first, first + stride - 1), previous.rgba:sub(first, first + stride - 1)
      if row ~= old then
        local left, right = 1, stride
        while row:byte(left) == old:byte(left) do left = left + 1 end
        while row:byte(right) == old:byte(right) do right = right - 1 end
        left, right = math.floor((left - 1) / 4) * 4, math.ceil(right / 4) * 4
        local copy = copyRun(row,previous.rgba,y,w,h,left,right)
        if copy then
          copies = true
          raw(y,left,copy.first,row)
          rows[#rows+1] = {y=y,x=copy.first/4,n=(copy.last-copy.first)/4,sy=copy.sy,sx=copy.sx}
          raw(y,copy.last,right,row)
        else raw(y,left,right,row) end
      end
    end
    local commands = {}
    for i,row in ipairs(rows) do
      commands[i] = u16(row.y) .. u16(row.x) .. u16(row.n)
        .. (copies and (u16(row.sy or 65535)..u16(row.sx or 0)) or "") .. (row.bytes or "")
    end
    local patch = u16(#rows) .. table.concat(commands)
    -- A scene change should use a self-contained image, not a larger patch list.
    if #patch < #rgba * .75 then body, delta = patch, copies and "copy" or true end
  end
  local compressAt = profile and profile.clock()
  if profile then profile.diff, profile.patchBytes = (compressAt - started) * 1000, #body end
  local payload = compress(body)
  if profile then profile.compress = (profile.clock() - compressAt) * 1000 end
  local compressed = #payload < #body
  if not compressed then payload = body end
  local magic = delta == "copy" and (compressed and "KG05" or "KG06")
    or delta and (compressed and "KG03" or "KG04") or (compressed and "KG02" or "KG01")
  local header = magic .. u16(w) .. u16(h) .. u32(id)
  if at then header = "KG1" .. magic:sub(4) .. u16(w) .. u16(h) .. u32(id) .. u32(at) end
  if delta then header = header .. u32(previous.id) end
  return header .. payload, { rgba = rgba, w = w, h = h, id = id }
end

return Video
