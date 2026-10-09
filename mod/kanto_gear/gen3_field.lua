-- Use native field-move eligibility and effects. WorldAPI's Gen 3 context is
-- incomplete (mapType, escape flags, waterfall facing); fishing is absent.
local Field = {}
Field.__index = Field
local moves = { cut = "CUT", surf = "SURF", strength = "STRENGTH", flash = "FLASH",
  rock_smash = "ROCK_SMASH", waterfall = "WATERFALL", dig = "DIG", teleport = "TELEPORT",
  sweet_scent = "SWEET_SCENT", fly = "FLY", dive = "DIVE", secret_power = "SECRET_POWER" }
local rods = { "OLD_ROD", "GOOD_ROD", "SUPER_ROD" }
local delta = { up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }

function Field.new(adapter, world)
  return setmetatable({ adapter = adapter, world = world,
    Player = require("src.core.game3.player"), Map = require("src.core.game3.map"),
    Collision = require("src.core.game3.collision"), Objects = require("src.core.game3.objects"),
    ItemUse = require("src.core.game3.item_use"), Bag = require("src.core.game3.bag"),
    Compat = require("src.mods.Gen3Compat") }, Field)
end

function Field:busy()
  local a = self.adapter
  if not a.session or a.game.phase ~= "field" then return true end
  return self.Compat.worldBusy()
end

function Field:context()
  local a, p, c = self.adapter, self.Player, self.Collision
  local d = delta[p.facing] or delta.down
  local fx, fy = p.cellX + d[1], p.cellY + d[2]
  local map = self.Map.currentDef() or {}
  local grass = false
  for y = p.cellY - 1, p.cellY + 1 do
    for x = p.cellX - 1, p.cellX + 1 do
      local elevation = c.elevationAt and c.elevationAt(x, y)
      if (p.elevation == nil or elevation == p.elevation) and c.isGrass and c.isGrass(x, y) then grass = true end
    end
  end
  return {
    party = a.session.party, store = a:flagStore(), session = a.session,
    facingObject = self.Objects.at(fx, fy), facing = p.facing,
    isFacingWater = c.isWater and c.isWater(fx, fy),
    isFacingWaterfall = a.FieldMoves.isWaterfallBehavior(c.behavior and c.behavior(fx, fy)),
    isSurfing = p.surfing == true, hasCuttableGrass = grass, mapType = map.mapType,
    isCave = (tonumber(map.cave) or 0) ~= 0,
    canEscapeRope = (tonumber(map.allowEscaping) or 0) ~= 0, escapeWarp = a.session.escapeWarp,
  }
end

function Field:result(move, context)
  local a = self.adapter
  local mon = a.FieldMoves.partyMoveUser(a.session.party, move)
  if not mon then return nil end
  context = context or self:context()
  context.mon = mon
  local result = a.FieldMoves.fromMenu(move, context)
  return result and result.ok and result or nil
end

function Field:availableFieldActions()
  if self:busy() then return {}, "world is busy" end
  local out = {}
  -- Keep the host's heal/other actions; replace only the incomplete queries.
  for _, action in ipairs(self.world and self.world.availableFieldActions and self.world:availableFieldActions() or {}) do
    if not moves[action.id] and action.id ~= "fish" then out[#out + 1] = action end
  end
  local context = self:context()
  for _, move in ipairs(self.adapter.FieldMoves.menuOrder() or {
      "CUT", "SURF", "STRENGTH", "FLASH", "ROCK_SMASH", "WATERFALL", "DIG", "TELEPORT", "SWEET_SCENT", "FLY" }) do
    local id = move:lower()
    if moves[id] and self:result(move, context) then out[#out + 1] = { id = id, label = move:gsub("_", " ") } end
  end
  if self.ItemUse.canFish() then
    local owned = {}
    for _, id in ipairs(rods) do
      if self.Bag.has(self.adapter.session.bag, id, 1) then
        owned[#owned + 1] = { id = id, label = self.adapter.data.items[id].name }
      end
    end
    if #owned > 0 then out[#out + 1] = { id = "fish", label = "FISH", rods = owned } end
  end
  return out
end

function Field:useFieldAction(id, opts)
  if self:busy() then return nil, "world is busy" end
  if moves[id] then
    local result = self:result(moves[id])
    if not result then return nil, "field action unavailable" end
    self.adapter.Field.executeFieldMove(result)
    return true
  elseif id == "fish" then
    local rod = opts and opts.rod
    for _, allowed in ipairs(rods) do
      if rod == allowed and self.Bag.has(self.adapter.session.bag, rod, 1) then
        local ok, _, reason = self.ItemUse.useRod(self.adapter.session, rod)
        return ok, reason
      end
    end
    return nil, "rod unavailable"
  end
  if self.world and self.world.useFieldAction then return self.world:useFieldAction(id, opts) end
  return nil, "field action unavailable"
end

function Field:flyTo(target, region)
  if self:busy() then return nil, "world is busy" end
  local result = self:result("FLY")
  local fresh = region and region:resolve(target)
  if not result or not fresh then return nil, "destination unavailable" end
  self.adapter.Field.flyTo(fresh.id, result.mon, { dest = fresh.dest,
    posWithinMapSec = fresh.pos })
  return true
end

return Field
