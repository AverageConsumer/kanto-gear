-- Gen 1 map IDs and Gen 2 spawn IDs are different flight protocols.
local Region = {}
Region.__index = Region

function Region.new(game, worldApi, generation)
  return setmetatable({ game = game, worldApi = worldApi, generation = generation,
    Moves = generation == 2 and require("src.world.gen2.FieldMoves") or nil }, Region)
end

-- Game path [Gen 1/2]: Gen 1 flies to map IDs via worldApi; Gen 2 requires FieldMoves checks and visited spawn IDs.
function Region:canFly()
  if self.generation ~= 2 then
    return self.worldApi and self.worldApi.canFly and self.worldApi:canFly() or false
  end
  local w = self.game.world
  if not (w and w.acceptsMenuInput and w:acceptsMenuInput()
      and self.game.stack:top() == w and w.map and w.map.def) then return false end
  local ctx = { save = self.game.save, party = self.game.save.party,
    environment = w.map.def.environment }
  local mon = self.Moves.partyMoveUser(ctx.party, "FLY", ctx)
  return mon and self.Moves.flyFromMenu(ctx).ok == true or false
end

function Region:points(region)
  if self.generation ~= 2 then return nil, region end
  local points, shown = self.Moves.flyPoints(self.game.save, self.game.data.gen2Landmarks, region)
  -- Host path [Gen 2]: older flyPoints omits the shown region; retain the same Indigo visitation gate when reconstructing it.
  -- Earlier hosts return only the points, but apply the same Indigo gate.
  shown = shown or (region == "kanto" and self.Moves.hasVisitedSpawn(self.game.save, "SPAWN_INDIGO")
    and "kanto" or "johto")
  return points, shown
end

function Region:fly(target)
  if not self:canFly() then return nil, "fly unavailable" end
  if self.generation ~= 2 then return self.worldApi:flyTo(target.id) end
  local w = self.game.world
  local points, shown = self:points(w:region())
  if target.region ~= shown then return nil, "destination unavailable" end
  for _, row in ipairs(points) do
    if row.spawn == target.id then
      local mon = self.Moves.partyMoveUser(self.game.save.party, "FLY",
        { save = self.game.save, environment = w.map.def.environment })
      return w:flyTo(row.spawn, mon)
    end
  end
  return nil, "destination unavailable"
end

-- Landmarks are points in the ROM map, not geographic polygons. Only label
-- their immediate neighborhood; open sea must never become the nearest town.
function Region.pick(points, x, y)
  local best, distance
  for _, point in ipairs(points) do
    local d = (x - point.x) ^ 2 + (y - point.y) ^ 2
    if d <= 64 and (not distance or d < distance
        or d == distance and point.flyPoint and not best.flyPoint
        or d == distance and point.flyPoint == best.flyPoint and tostring(point.id) < tostring(best.id)) then
      best, distance = point, d
    end
  end
  return best
end

return Region
