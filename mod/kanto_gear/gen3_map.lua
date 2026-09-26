-- A detached native-metatile renderer. The same geometry can draw at widget,
-- Explorer and fullscreen scales. It shares the host's animated atlases and
-- never changes the active map, collision grid or visible animation pairs.
local Map = {}
Map.__index = Map

local function release(batch)
  if batch and batch.release then batch:release() end
end

local function overridesEqual(a, b)
  for key, cell in pairs(a) do
    local other = b[key]
    if not other or cell.mid ~= other.mid then return false end
  end
  for key in pairs(b) do if not a[key] then return false end end
  return true
end

function Map.new(graphics, tilesets)
  return setmetatable({ graphics = graphics, tilesets = tilesets, builds = 0 }, Map)
end

function Map:release()
  release(self.under)
  release(self.over)
  self.under, self.over, self.layout, self.atlas, self.overrides = nil, nil, nil, nil, nil
end

function Map:prepare(def)
  local layout = def and def.midLayout
  if not layout then self:release(); return nil, "native layout unavailable" end
  local width, height = layout.trueWidth or layout.width, layout.trueHeight or layout.height
  if not width or not height or width <= 0 or height <= 0 then
    self:release()
    return nil, "empty native layout"
  end
  local atlas = self.tilesets.get(def.pair or layout.pair)
  if not atlas or not atlas.image then self:release(); return nil, "native atlas unavailable" end
  local overrides = layout.overrides or {}
  if self.layout == layout and self.cells == layout.cells and self.atlas == atlas
      and self.texture == atlas.image and self.overTexture == atlas.overImage
      and self.layered == atlas.layered
      and self.width == width and self.height == height
      and overridesEqual(self.overrides, overrides) then return self end

  -- Allocate replacement geometry before releasing the last valid geometry.
  -- Atlas textures belong to Recomp; only these batches belong to Gear.
  local under, over
  local ok, err = pcall(function()
    under = self.graphics.newSpriteBatch(atlas.image, width * height, "static")
    if atlas.layered and atlas.overImage then
      over = self.graphics.newSpriteBatch(atlas.overImage, width * height, "static")
    end
    for y = 0, height - 1 do
      for x = 0, width - 1 do
        local mid = layout:midAt(x, y)
        if not self.tilesets.hasMid(atlas, mid) then
          error("native metatile missing from atlas: " .. tostring(mid))
        end
        local slot = self.tilesets.slotFor(atlas, mid)
        under:add(assert(self.tilesets.quad(atlas, slot)), x * 16, y * 16)
        if over then over:add(assert(self.tilesets.overQuad(atlas, slot)), x * 16, y * 16) end
      end
    end
    under:flush()
    if over then over:flush() end
  end)
  if not ok then
    release(under)
    release(over)
    self:release()
    return nil, err
  end
  self:release()
  self.layout, self.cells, self.atlas = layout, layout.cells, atlas
  self.texture, self.overTexture = atlas.image, atlas.overImage
  self.layered = atlas.layered
  self.under, self.over = under, over
  self.width, self.height = width, height
  self.overrides = {}
  for key, cell in pairs(overrides) do self.overrides[key] = { mid = cell.mid } end
  self.builds = self.builds + 1
  return self
end

-- x/y are the upper-left of cell (0,0); cellSize is display pixels per cell.
-- The caller owns clipping, tint and markers. No canvas/readback per frame.
function Map:draw(x, y, cellSize)
  if not self.under then return false end
  local scale = cellSize / 16
  self.graphics.draw(self.under, x, y, 0, scale, scale)
  if self.over then self.graphics.draw(self.over, x, y, 0, scale, scale) end
  return true
end

return Map
