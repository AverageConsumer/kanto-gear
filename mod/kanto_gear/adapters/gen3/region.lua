-- Borrow the host's ROM-derived region textures; never open or move its map UI.
local Region = {}
Region.__index = Region
local names = { [0] = "KANTO", "SEVII 1-3", "SEVII 4-5", "SEVII 6-7" }
local images = { [0] = "kanto_map", "sevii123_map", "sevii45_map", "sevii67_map" }

function Region.new(adapter, graphics)
  -- Game path [Ruby/Sapphire/Emerald]: Hoenn uses its native region-map model; FireRed/LeafGreen below includes Kanto/Sevii destinations.
  if adapter.hoenn then
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
  model.width, model.height = 192, 144
  model.key = "gen3:" .. region
  model.playerX, model.playerY = px and px * 8 + 12, py and py * 8 + 20
  model.pick = function(x, y, fly) return self:pick(region, x, y, fly) end
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
  model.width, model.height, model.key = 224, 120, "gen3:hoenn"
  model.playerX = ok and state.showPlayerIcon and state.playerIconX * 8 - 4 or nil
  model.playerY = ok and state.showPlayerIcon and state.playerIconY * 8 - 12 or nil
  model.pick = function(x, y, fly) return self:pick("hoenn", x, y, fly) end
  return model
end

function Region:flag(name)
  local a = self.adapter
  local id = a.Flags.IDS[name]
  return id and a.Flags.getFlag(a:flagStore(), nil, id) == true or false
end

function Region:pick(region, x, y, fly)
  local a = self.adapter
  if not a.session then return nil end
  if self.Hoenn then
    local r = self.Hoenn
    -- The host exposes its cursor update on an independent state: it also
    -- resolves the two distinct Ever Grande landing points correctly.
    local s = { session = a.session, cursorX = math.floor(x / 8) + 1,
      cursorY = math.floor(y / 8) + 2, mapSecId = -1,
      inputFn = "move", moveCounter = 0, dx = 0, dy = 0 }
    r.inputCallback(s, {})
    if s.mapSecType == r.TYPE.NONE then return nil end
    r.updateFlyText(s)
    local dest = r.flyWarpDestination(a.session, s.mapSecId, s.posWithinMapSec)
      or a.Field.flyDestination(s.mapSecId)
    local visited = s.mapSecType == r.TYPE.CITY_CANFLY or s.mapSecType == r.TYPE.BATTLE_FRONTIER
    return { id = s.mapSecId, region = region, x = x, y = y,
      name = fly and s.flyText and s.flyText.sub and s.flyText.sub ~= "" and s.flyText.sub or s.mapSecName,
      pos = s.posWithinMapSec,
      flyPoint = dest ~= nil, flyable = dest ~= nil and visited, dest = dest }
  end
  local cx, cy = math.floor((x - 8) / 8), math.floor((y - 16) / 8)
  local layout = self.Extract.LAYOUTS[region]
  if not layout or cx < 0 or cx >= 22 or cy < 0 or cy >= 15 then return nil end
  local sections = require("src.import.gba.map_sections_extract")
  local id = layout.map[cy][cx]
  local section = sections.SECTIONS[id]
  if not section or id == self.Extract.MAPSEC_NONE then return nil end
  local symbol = section.id
  if (symbol == "MAPSEC_NAVEL_ROCK" and not self:flag("FLAG_WORLD_MAP_NAVEL_ROCK_EXTERIOR"))
      or (symbol == "MAPSEC_BIRTH_ISLAND" and not self:flag("FLAG_WORLD_MAP_BIRTH_ISLAND_EXTERIOR")) then return nil end
  local exceptions = { MAPSEC_INDIGO_PLATEAU = "FLAG_WORLD_MAP_INDIGO_PLATEAU_EXTERIOR",
    MAPSEC_ROUTE_4_POKECENTER = "FLAG_WORLD_MAP_ROUTE4_POKEMON_CENTER_1F",
    MAPSEC_ROUTE_10_POKECENTER = "FLAG_WORLD_MAP_ROUTE10_POKEMON_CENTER_1F" }
  local flag = exceptions[symbol] or ("FLAG_WORLD_MAP_" .. symbol:gsub("^MAPSEC_", ""))
  local dest = a.Field.flyDestination(id)
  local name = self.Extract.SECTION_NAMES[symbol]
  if not fly then
    local dungeon = sections.SECTIONS[layout.dungeon[cy][cx]]
    if dungeon and dungeon.id ~= "MAPSEC_NONE"
        and (dungeon.id ~= "MAPSEC_CERULEAN_CAVE" or self:flag("FLAG_SYS_CAN_LINK_WITH_RS")) then
      name = self.Extract.SECTION_NAMES[dungeon.id] or name
    end
  end
  return { id = id, region = region, x = x, y = y, name = name and require("src.core.Strings")(name) or "",
    flyPoint = dest ~= nil, flyable = dest ~= nil and self:flag(flag), dest = dest }
end

function Region:resolve(target)
  local current = self.Hoenn and "hoenn" or self:position()
  if not target or current ~= target.region then return nil end
  local fresh = self:pick(current, target.x, target.y, true)
  if not fresh or fresh.id ~= target.id or fresh.pos ~= target.pos or not fresh.flyable then return nil end
  return fresh
end

function Region:points(model)
  -- Cache geometry only; native flags and landing variants remain live.
  local region = self.Hoenn and "hoenn" or self:position()
  self.pointCells = self.pointCells or {}
  local cells = self.pointCells[model.key]
  if not cells then
    cells = {}
    for y = 4, model.height - 1, 8 do
      for x = 4, model.width - 1, 8 do
        local id
        if self.Hoenn then id = self.Hoenn.mapSecAt(math.floor(x / 8) + 1, math.floor(y / 8) + 2)
        else
          local cx, cy = math.floor((x - 8) / 8), math.floor((y - 16) / 8)
          local layout = self.Extract.LAYOUTS[region]
          id = layout and cx >= 0 and cx < 22 and cy >= 0 and cy < 15 and layout.map[cy][cx] or nil
        end
        if id and (self.adapter.Field.flyDestination(id)
            or self.Hoenn and self.Hoenn.flyWarpDestination(self.adapter.session, id, 0)) then
          cells[#cells + 1] = { x = x, y = y }
        end
      end
    end
    self.pointCells[model.key] = cells
  end
  local points = {}
  for _, cell in ipairs(cells) do
    local target = self:pick(region, cell.x, cell.y, true)
    if target and target.flyPoint then points[#points + 1] = target end
  end
  return points
end

function Region:release()
  if self.quad and self.quad.release then self.quad:release() end
  self.quad = nil
  self.pointCells = nil
end
return Region
