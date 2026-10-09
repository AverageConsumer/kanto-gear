return function(T, display, runtime, gen, up)
  if gen ~= 3 then return end
  local adapter = display.gen3
  local sprites = require("src.core.game3.ow_sprites")
  local objects = require("src.core.game3.objects")
  local oldDraw, oldPose = sprites.getDraw, sprites.pose
  local oldFind, oldMap = objects.find, objects._mapId
  local oldResolve, oldStore = adapter.Space.resolveObjectGraphicsId, adapter.flagStore
  local oldKnown, oldMethods, oldWild = display.knownMap, display.explorerMethods, display.explorerWildRows
  local hidden, resolved = false, 66
  adapter.flagStore = function() return { flags = { [50] = hidden, [0] = true, [0xFFFF] = true } } end
  adapter.Space.resolveObjectGraphicsId = function(row)
    return row.graphicsVar and resolved or row.graphicsId
  end
  local live = { cellX = 4, cellY = 6, graphicsId = 106, facing = "right", visible = true }
  objects._mapId = "TRAINER_TEST"
  objects.find = function(id) T.eq(id, 2, "native lookup uses local object ID, not trainer ID"); return live end
  local row = { id = "trainer:123", index = 2, mapId = "TRAINER_TEST", x = 1, y = 2,
    graphicsId = 66, hideEvent = 50 }
  local actor = adapter:mapActor(row)
  T.eq(actor.graphicsId, 106, "live graphics override the original event template")
  T.eq(actor.x, 4, "marker follows the live trainer tile")
  T.eq(actor.y, 6, "marker follows both live coordinates")
  T.eq(actor.facing, "right", "marker retains the current trainer direction")
  T.eq(actor.visible, true, "visible native trainer stays visible")
  live.hidden = true
  T.eq(adapter:mapActor(row).visible, false, "removed native objects do not remain map targets")
  live.hidden = nil; live.invisible = true
  T.eq(adapter:mapActor(row).visible, false, "script-invisible trainers are hidden on the map")
  live.invisible = nil
  objects._mapId = "ANOTHER_MAP"
  actor = adapter:mapActor(row)
  T.eq(actor.graphicsId, 66, "another map's identical local ID cannot replace the trainer")
  T.eq(actor.x, 1, "off-map object cannot move the template marker")
  hidden = true
  T.eq(adapter:mapActor(row).visible, false, "hidden flags work even without a live object")
  row.hideEvent = 0
  T.eq(adapter:mapActor(row).visible, true, "zero hide flag means always visible")
  row.hideEvent = 0xFFFF
  T.eq(adapter:mapActor(row).visible, true, "native no-hide sentinel means always visible")
  row.hideEvent = 50
  hidden = false; row.graphicsVar = 0x4010; resolved = 59
  T.eq(adapter:mapActor(row).graphicsId, 59, "variable graphics are resolved by the native field engine")
  row.graphicsVar = nil
  local image, quad = {}, {}
  local fetched, facing, drawn, tint
  sprites.getDraw = function(id)
    fetched = id
    return { image = image, quads = { [2] = quad }, width = 16, height = 32 }
  end
  sprites.pose = function(_, direction, walking, running)
    facing = direction
    T.eq(walking or running, false, "map trainer stands instead of borrowing player walk animation")
    return 2, direction == "right"
  end
  local g = { setColor = function(...) tint = { ... } end,
    draw = function(...) drawn = { ... } end }
  actor.graphicsId, actor.facing = 106, "right"
  T.eq(adapter:drawActor(g, actor, 50, 80, .5, true, { .45, .45, .45, 1 }), true,
    "native sprite draws successfully")
  T.eq(fetched, 106, "renderer uses native numeric graphics instead of legacy sprite names")
  T.eq(facing, "right", "native pose receives trainer facing")
  T.eq(drawn[1], image, "renderer uses native runtime-palette image")
  T.eq(drawn[2], quad, "renderer uses the correct direction frame")
  T.eq(drawn[3], 54, "mirrored sprite centers on the tile")
  T.eq(drawn[4], 64, "32px NPC feet align with the player and map cell")
  T.eq(drawn[6], -.5, "right-facing pose mirrors around its centered anchor")
  T.eq(drawn[7], .5, "sprite retains native aspect ratio")
  T.eq(tint[1], .45, "beaten trainer remains visibly dimmed")
  sprites.getDraw = function() return nil end
  T.eq(adapter:drawActor(g, actor, 0, 0, 1, true), false, "pending native texture does not crash rendering")
  sprites.getDraw = function(id) fetched = id; return {image=image,quads={[2]=quad},width=16,height=32} end

  -- Exercise the shared model and draw callback used by Explorer and Home.
  local explorer, saved = display.explorer, {}
  for key, value in pairs(explorer) do saved[key] = value end
  local assist = up(display.explorerModel, "assist")
  local overview = { mapId = row.mapId, width = 12, height = 12, rows = {}, markers = {} }
  for i = 1, 12 do overview.rows[i] = string.rep(".", 12) end
  explorer.data = { mapId = row.mapId, at = love.timer.getTime(),
    guideEnabled = assist("guide"), areaEnabled = assist("area"), fruits = {},
    guide = { rows = {}, caught = 0 }, area = { sections = { { rows = { row } }, {rows={}}, {rows={}} } } }
  explorer.renderModel, explorer.renderData = nil, nil
  display.knownMap = function() return true end
  display.explorerMethods = function() return {} end
  display.explorerWildRows = function() return {} end
  objects._mapId = row.mapId
  local model = display.explorerModel(overview)
  T.eq(#model.markers, 1, "visible trainer reaches the shared Explorer/widget model")
  T.eq(model.markers[1].x, 4, "model uses the running NPC position")
  T.eq(model.drawTrainer(model.markers[1], 50, 80, 8), true, "shared callback draws a native trainer")
  T.eq(fetched, 106, "compat renderer delegates Gen 3 trainer graphics")
  live.hidden = true; explorer.renderModel = nil
  T.eq(#display.explorerModel(overview).markers, 0, "hidden trainers have neither visible markers nor map hit targets")
  live.hidden = nil
  explorer.data.area.sections[1].rows = {}
  row.gift, row.kind, row.itemId, row.label, row.done = true, "item", 13, "POTION", false
  explorer.data.area.sections[2].rows = {row}
  explorer.renderModel = nil
  model = display.explorerModel(overview)
  T.eq(#model.markers, 1, "NPC gift reaches Explorer and its widget")
  T.eq(model.markers[1].gift, true, "NPC marker is not rendered as a ground pickup")
  T.eq(model.markers[1].x, 4, "gift marker follows the running NPC")
  T.eq(row.location, "TALK TO NPC", "gift detail explains how to collect the reward")
  T.eq(model.drawTrainer(model.markers[1],50,80,8),true,"gift uses the native NPC sprite")
  live.hidden = true; explorer.renderModel = nil
  T.eq(#display.explorerModel(overview).markers,0,"hidden gift NPC has no map marker or hit target")
  for key in pairs(explorer) do explorer[key] = nil end
  for key, value in pairs(saved) do explorer[key] = value end
  display.knownMap, display.explorerMethods, display.explorerWildRows = oldKnown, oldMethods, oldWild
  sprites.getDraw, sprites.pose = oldDraw, oldPose
  objects.find, objects._mapId = oldFind, oldMap
  adapter.Space.resolveObjectGraphicsId, adapter.flagStore = oldResolve, oldStore
end
