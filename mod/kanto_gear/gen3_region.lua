-- Borrow the host's ROM-derived region textures; never open or move its map UI.
local Region = {}
Region.__index = Region
local names = { [0] = "KANTO", "SEVII 1-3", "SEVII 4-5", "SEVII 6-7" }
local images = { [0] = "kanto_map", "sevii123_map", "sevii45_map", "sevii67_map" }

function Region.new(adapter, graphics)
  if adapter.profile.id == "emerald" then
    return setmetatable({ adapter = adapter, graphics = graphics,
      Hoenn = require("src.ui.game3.rse.region_map"),
      Kit = require("src.ui.game3.rse.scene_kit") }, Region)
  end
  local Extract = require("src.import.gba.region_map_extract")
  Extract.ensureGenerated()
  return setmetatable({ adapter = adapter, graphics = graphics, Extract = Extract,
    Position = require("src.ui.game3.region_map_position"),
    Gpu = require("src.ui.game3.region_map_gpu") }, Region)
end

function Region:position()
  local session = self.adapter.session
  if not session then return nil end
  local maps = self.adapter.data.maps
  local def = maps[session.map]
  if not def or not def.regionMapSectionId then return nil end
  -- Unknown/custom sections must not crash Gear or claim a vanilla location.
  local ok, region = pcall(self.Position.regionFor, def.regionMapSectionId, self.Extract.LAYOUTS)
  if not ok then return nil end
  local found, x, y = pcall(self.Position.playerCell, {
    map = session.map, x = session.x, y = session.y,
    escapeWarp = session.escapeWarp, dynamicWarp = session.dynamicWarp,
    def = function(id) return maps[id] end,
  }, self.Extract.GEOMETRY)
  return region, found and x or nil, found and y or nil
end

function Region:model(area, marker)
  if self.Hoenn then return self:hoennModel(area, marker) end
  local region, px, py = self:position()
  local model = { area = area, region = names[region] or "MAP" }
  if region == nil then return model end
  local g, img = self.graphics, self.Gpu.image(images[region])
  -- The native map has a 24/16-pixel UI margin; Gear supplies its own frame.
  self.quad = self.quad or g.newQuad(24, 16, 192, 144, img:getDimensions())
  model.drawMap = function(x, y, w, h)
    local scale = math.min(w / 192, h / 144)
    local left = math.floor(x + (w - 192 * scale) / 2 + 0.5)
    local top = math.floor(y + (h - 144 * scale) / 2 + 0.5)
    g.setColor(1, 1, 1, 1)
    g.draw(img, self.quad, left, top, 0, scale, scale)
    if px and py and marker then
      marker(left + (px * 8 + 12) * scale, top + (py * 8 + 20) * scale, 1)
    end
  end
  return model
end

function Region:hoennModel(area, marker)
  local model = { area = area, region = "HOENN" }
  local session = self.adapter.session
  local def = session and self.adapter.data.maps[session.map]
  if not def then return model end
  local entry = self.Hoenn.manifest().layers.map
  local img = self.Kit.image(type(entry) == "table" and entry.png or entry)
  if not img then return model end
  -- Use an independent read model; never open or alter the host's map screen.
  local ok, state = pcall(self.Hoenn.newState, { session = session, mapDef = def })
  local g = self.graphics
  self.quad = self.quad or g.newQuad(8, 16, 224, 120, img:getDimensions())
  model.drawMap = function(x, y, w, h)
    local scale = math.min(w / 224, h / 120)
    local left = math.floor(x + (w - 224 * scale) / 2 + 0.5)
    local top = math.floor(y + (h - 120 * scale) / 2 + 0.5)
    g.setColor(1, 1, 1, 1)
    g.draw(img, self.quad, left, top, 0, scale, scale)
    if ok and state.showPlayerIcon and marker then
      local px, py = state.playerIconX * 8 - 4, state.playerIconY * 8 - 12
      if px >= 0 and px < 224 and py >= 0 and py < 120 then
        marker(left + px * scale, top + py * scale, 1)
      end
    end
  end
  return model
end

function Region:release()
  if self.quad and self.quad.release then self.quad:release() end
  self.quad = nil
end
return Region
