-- Read-only Gen 1/2 terrain. Gen 2 already owns a fully colored map canvas;
-- Gen 1 lends its atlas/quads to Gear's independent static geometry. Never
-- call the host renderer's draw/rebuild: its camera window belongs to the game.
local Map = {}
Map.__index = Map

function Map.new(graphics)
  return setmetatable({ graphics = graphics, builds = 0,
    Palette = require("src.render.PaletteFX"),
    Gbc = require("src.render.GbcPalette") }, Map)
end

function Map:release()
  if self.batch then self.batch:release() end
  self.batch, self.source, self.quads, self.texture, self.map = nil, nil, nil, nil, nil
end

function Map:prepare(world, data, gen2)
  local map = world and world.map
  if not (map and map.widthCells and map.heightCells) then self:release(); return false end
  self.world, self.data, self.gen2 = world, data, gen2
  if gen2 then
    if self.batch then self:release() end
    self.map = map
    -- This is the host's current bake, including roofs, Crystal attributes,
    -- darkness, custom palettes and block changes. No second bake or readback.
    return world.mapImage ~= nil and world.mapImage ~= false
  end
  local source = map.renderer
  local texture = source and (source.baseImage or source.image)
  if not (texture and source.quads and map.blockAt and map.tileset) then
    self:release(); return false
  end
  if self.map == map and self.source == source and self.texture == texture
      and self.quads == source.quads and self.batch then return true end
  self:release()
  local batch
  local ok = pcall(function()
    batch = self.graphics.newSpriteBatch(texture, map.widthCells * map.heightCells * 4, "static")
    for ty = 0, map.heightCells * 2 - 1 do
      for tx = 0, map.widthCells * 2 - 1 do
        local blockId = map:blockAt(math.floor(tx / 4), math.floor(ty / 4))
        local block = map.tileset.blocks[blockId + 1]
        if block then
          local cell = (ty % 4) * 4 + tx % 4
          local tile = block[cell + 1]
          local aliases = source.aliasMap and source.aliasMap[blockId]
          tile = aliases and aliases[cell] or tile
          local quad = source.quads[tile]
          if quad then batch:add(quad, tx * 8, ty * 8) end
        end
      end
    end
    batch:flush()
  end)
  if not ok then if batch then batch:release() end; return false end
  self.batch, self.source, self.texture, self.quads, self.map = batch, source, texture, source.quads, map
  self.builds = self.builds + 1
  return true
end

-- A texture/palette replacement must refresh even when the player stands still.
function Map:revision()
  local world = self.world
  if not world then return "" end
  if self.gen2 then return tostring(world.mapImage) end
  local source = world.map and world.map.renderer
  return table.concat({ tostring(source), tostring(source and source.quads),
    tostring(source and (source.baseImage or source.image)), tostring(self.Palette.mode),
    tostring(self.Palette.customRamp), tostring(self.Palette.darkWorld()) }, ":")
end

function Map:draw(x, y, cellSize)
  if not self:prepare(self.world, self.data, self.gen2) then return false end
  local g, scale = self.graphics, cellSize / 16
  local image = self.gen2 and self.world.mapImage or self.batch
  local function paint()
    g.setColor(1, 1, 1, 1)
    g.draw(image, x, y, 0, scale, scale)
  end
  if not self.gen2 and not self.source.gbcAtlas and not self.source.trueColor then
    local name = self.world.paletteNameFor and self.world:paletteNameFor(self.map)
    local colors = self.Palette.pal(self.data, name) or self.Palette.GRAYS
    colors = self.Palette.effectiveColors(colors)
    self.Gbc.withRaw(colors, paint)
  else paint() end
  return true
end

return Map
