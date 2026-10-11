-- Verify the native eligibility results and the effect dispatched by Field Kit.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local bridge, a = display.gen3Field, display.gen3
  local F, FM = a.Field, a.FieldMoves
  local Bag = require("src.core.game3.bag")
  local Stack = require("src.ui.game3.stack")
  local p, c, maps = bridge.Player, bridge.Collision, bridge.Map
  local old = { busy = bridge.Compat.worldBusy, map = maps.currentDef, water = c.isWater,
    behavior = c.behavior, grass = c.isGrass, object = bridge.Objects.at,
    execute = F.executeFieldMove, fish = F.startFishing, moves = a.session.party[1].moves,
    x = p.cellX, y = p.cellY, facing = p.facing, surfing = p.surfing, escapeWarp = a.session.escapeWarp }
  local map, busy, wet, payload, fishing
  bridge.Compat.worldBusy = function() return busy == true end
  maps.currentDef = function() return map end
  c.isWater, c.behavior, c.isGrass = function() return wet == true end, function() return 0 end, function() return false end
  bridge.Objects.at = function() return nil end
  F.executeFieldMove = function(result) payload = result end
  F.startFishing = function(rod) fishing = rod end
  p.cellX, p.cellY, p.facing, p.surfing = 10, 10, "down", false
  Stack.clear(); a.Message.reset()
  local function listed(id)
    for _, action in ipairs(bridge:availableFieldActions()) do if action.id == id then return action end end
  end
  for _, def in pairs(a.data.maps) do
    if FM.isOutdoors(def.mapType) then map = def break end
  end
  T.check(map ~= nil, "native map catalogue supplies an outdoor test location")
  local outdoors = map
  a.session.escapeWarp = { map = a.session.healMap or a.session.map, x = 3, y = 4 }
  local mon = a.session.party[1]
  mon.moves = { FM.MOVES.TELEPORT, FM.MOVES.FLY, FM.MOVES.DIG }
  local flyFlag = FM.badgeFlag("FLY")
  a.Flags.setFlag(a:flagStore(), nil, flyFlag, false)
  T.check(listed("teleport") ~= nil, "Teleport is available on an actual native outdoor map")
  T.eq(listed("fly"), nil, "Fly remains unavailable without the native badge")
  a.Flags.setFlag(a:flagStore(), nil, flyFlag, true)
  T.check(listed("fly") ~= nil, "Fly becomes available with the real version-specific badge")
  T.check(bridge:useFieldAction("teleport"), "Teleport uses the native field effect")
  T.eq(payload.action, "teleport", "Teleport payload has the original native action")
  T.eq(payload.mon, mon, "field effect uses the actual party member")
  T.check(bridge:useFieldAction("fly"), "Fly opens the native destination selection")
  T.eq(payload.action, "fly", "Fly dispatches selection rather than an unsupported map warp")
  for _, def in pairs(a.data.maps) do
    if FM.isDungeon(def.mapType, (tonumber(def.cave) or 0) ~= 0) and tonumber(def.allowEscaping) == 1 then map = def break end
  end
  T.check(map ~= outdoors, "native catalogue supplies an escapable cave")
  T.eq(listed("teleport"), nil, "Teleport is unavailable inside a cave")
  T.eq(listed("fly"), nil, "Fly is unavailable inside a cave")
  T.check(listed("dig") ~= nil, "Dig receives the map's escape permission")
  T.check(bridge:useFieldAction("dig"), "Dig uses the native field effect")
  T.eq(payload.warp, a.session.escapeWarp, "Dig retains the actual recorded escape warp")
  map = outdoors; wet = true
  Bag.add(a.session.bag, "OLD_ROD", 1); Bag.add(a.session.bag, "GOOD_ROD", 1)
  local fish = listed("fish")
  T.check(fish and #fish.rods >= 2, "fishing offers the rods actually owned")
  T.check(bridge:useFieldAction("fish", { rod = "GOOD_ROD" }), "rod delegates to the original item-use handler")
  T.eq(fishing, tonumber(a.Items.info("GOOD_ROD").secondaryId) or 0, "native rod tier is retained")
  wet = false; fishing = nil
  T.eq(listed("fish"), nil, "fishing disappears when not facing fishable water")
  T.check(not bridge:useFieldAction("fish", { rod = "GOOD_ROD" }), "water eligibility is rechecked at activation")
  T.eq(fishing, nil, "stale fishing shortcut starts no fishing effect")
  mon.moves = {}; payload = nil
  T.check(not bridge:useFieldAction("teleport"), "removing the move invalidates an old shortcut")
  T.eq(payload, nil, "missing move starts no field effect")
  busy = true
  T.eq(#bridge:availableFieldActions(), 0, "busy native state offers no actions")
  T.check(not bridge:useFieldAction("fly"), "busy state rejects stale actions")
  bridge.Compat.worldBusy, maps.currentDef, c.isWater, c.behavior, c.isGrass = old.busy, old.map, old.water, old.behavior, old.grass
  bridge.Objects.at, F.executeFieldMove, F.startFishing, mon.moves = old.object, old.execute, old.fish, old.moves
  p.cellX, p.cellY, p.facing, p.surfing = old.x, old.y, old.facing, old.surfing
  a.session.escapeWarp = old.escapeWarp
end
dofile(path .. "/tests/gen3_fixture.lua")
