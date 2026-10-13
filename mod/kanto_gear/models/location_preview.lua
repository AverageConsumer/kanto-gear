-- Resolve a find back to the outdoor doorway that leads to its actual map.
-- Read incoming warps: Gen 1's LAST_MAP exits and dynamic elevators are not
-- fixed destinations. Never resolve them using the player's current save.
local M = {}

function M.floor(id)
  return tostring(id):match("_(B?%d+F)$") or tostring(id):match("_(B?%d+F)_")
    or tostring(id):find("_ROOF", 1, true) and "ROOF" or nil
end

-- Game path [Gen 1/2/3]: outdoor status comes from tilesets, environments or native mapType respectively; explicit custom metadata wins.
function M.outdoor(def, generation)
  if def.outdoor ~= nil then return def.outdoor end
  if generation == 1 then return def.tileset == "OVERWORLD" or def.tileset == "PLATEAU" end
  if generation == 3 and def.mapType and def.mapType ~= 0 then
    local t = def.mapType
    return t == 1 or t == 2 or t == 3 or t == 5 or t == 6
  end
  return def.environment == "TOWN" or def.environment == "ROUTE"
    or generation == 3 and def.environment == "UNDERWATER" or false
end

local function position(map, point, generation)
  local x, y = point.x, point.y
  if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y
      or x < 0 or y < 0 or x % 1 ~= 0 or y % 1 ~= 0 then return false end
  -- Game path [Gen 1/2 vs Gen 3]: old map dimensions are 32px blocks (two cells); GBA maps already report 16px cells.
  local cells = generation == 3 and 1 or 2
  return map.width and map.height and x < map.width * cells and y < map.height * cells
end

-- Index fixed incoming warps once per Explorer visit; find previews can also
-- request a fresh resolver to respect registered or replaced map definitions.
function M.resolver(maps, generation)
  local incoming = {}
  for id, map in pairs(maps or {}) do
    for _, warp in ipairs(map.warps or {}) do
      if maps[warp.destMap] and warp.destMap ~= id and warp.destWarp ~= 255
          and warp.destWarp ~= -1 and position(map, warp, generation) then
        local list = incoming[warp.destMap] or {}
        incoming[warp.destMap] = list
        list[#list + 1] = { mapId = id, x = warp.x, y = warp.y }
      end
    end
  end
  return function(target, current)
    local def = maps and maps[target.mapId]
    if not def or M.outdoor(def, generation) then return nil end
    local queue, seen, doors = { { id = target.mapId, depth = 0 } }, { [target.mapId] = true }, {}
    local index = 1
    while index <= #queue do
      local at = queue[index]; index = index + 1
      for _, entry in ipairs(incoming[at.id] or {}) do
        if M.outdoor(maps[entry.mapId], generation) then
          doors[#doors + 1] = { mapId = entry.mapId, x = entry.x, y = entry.y, depth = at.depth + 1 }
        elseif not seen[entry.mapId] then
          seen[entry.mapId] = true
          queue[#queue + 1] = { id = entry.mapId, depth = at.depth + 1 }
        end
      end
    end
    table.sort(doors, function(a, b)
      if (a.mapId == current) ~= (b.mapId == current) then return a.mapId == current end
      if a.depth ~= b.depth then return a.depth < b.depth end
      if a.mapId ~= b.mapId then return tostring(a.mapId) < tostring(b.mapId) end
      if a.y ~= b.y then return a.y < b.y end
      return a.x < b.x
    end)
    local first = doors[1]
    if not first then return nil end
    first.points = {}
    local added = {}
    for _, door in ipairs(doors) do
      local key = door.x .. ":" .. door.y
      if door.mapId == first.mapId and not added[key] then
        first.points[#first.points + 1] = { x = door.x, y = door.y }
        added[key] = true
      end
    end
    return first
  end
end

function M.entrance(maps, target, generation, current)
  return M.resolver(maps, generation)(target, current)
end

return M
