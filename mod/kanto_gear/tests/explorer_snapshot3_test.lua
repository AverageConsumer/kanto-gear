local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local id = display.gen3.hoenn and display.gen3.profile.map.enginePrefix .. "ROUTE102" or "FR_ROUTE_3"
  game.session.map = id
  run.loader.events:emit("map.entered", { game = game, mapId = id })
  run.loader.modOptions.kanto_gear.info_level = "spoiler"
  display.setPackageInstalled("explorer", true)
  T.check(display.openHomeApp("explorer"), "Explorer opens")
  local objects = require("src.core.game3.objects")
  local oldFind, oldMap = objects.find, objects._mapId
  local calls = 0
  local live = { cellX = 4, cellY = 6, graphicsId = 66, facing = "right", visible = true }
  objects._mapId, objects.find = id, function() calls = calls + 1; return live end
  local oldPosition = display.localMapPosition
  local x = 2
  display.localMapPosition = function() return { mapId = id, x = x, y = 3, facing = "down" } end
  display.knownMap = function() return true end
  display.explorerWildRows = function() return {} end
  local assist = up(display.explorerModel, "assist")
  local overview = { mapId = id, width = 20, height = 20, rows = {}, markers = {} }
  for i = 1, 20 do overview.rows[i] = string.rep(".", 20) end
  local function rows()
    display.explorer.data = { mapId = id, at = love.timer.getTime(),
      guideEnabled = assist("guide"), areaEnabled = assist("area"), fruits = {},
      guide = { rows = {}, caught = 0 }, area = { sections = {
        { rows = { { id = "trainer:123", index = 2, mapId = id, x = 1, y = 2,
          graphicsId = 66, label = "TRAINER" } } },
        { rows = { { id = "gift:123", actorId = "npc:2", index = 2, mapId = id,
          x = 1, y = 2, graphicsId = 66, gift = true, kind = "item", label = "POTION" } } },
        { rows = {} } } } }
    display.explorer.renderModel = nil
  end
  rows()
  local model = display.explorerModel(overview)
  local snapshot, firstCalls = model.mapSnapshot, calls
  local theme = up(display.drawContents, "THEME").hgss
  local hitX, hitY, hitKey
  for py = 54, 136 do
    for px = 8, 232 do
      local action, slot = theme:explorerHit(px / 1.5, py / 1.5, model)
      if action == "marker" then hitX, hitY, hitKey = px, py, model.markers[slot].source.key; break end
    end
    if hitX then break end
  end
  T.check(hitX ~= nil, "snapshot marker has an actual touch target")
  T.eq(model.player.x, 2, "snapshot captures player")
  T.eq(#model.markers, 2, "snapshot includes trainer and gift NPC")
  for _, marker in ipairs(model.markers) do T.eq(marker.x, 4, "snapshot captures live NPC") end
  x, live.cellX, live.cellY, live.facing = 2.5, 17, 18, "left"
  rows() -- Simulate progress-data expiry with brand new source rows.
  model = display.explorerModel(overview)
  T.eq(model.mapSnapshot, snapshot, "data refresh retains spatial snapshot")
  T.eq(model.player.x, 2.5, "player follows gameplay while NPC positions remain fixed")
  for _, marker in ipairs(model.markers) do
    T.eq(marker.x, 4, "moving NPC keeps its captured hit position")
    T.eq(marker.actor.facing, "right", "NPC direction is frozen too")
  end
  T.eq(calls, firstCalls, "snapshot rebuilds do not query live native actors")
  local action, slot = theme:explorerHit(hitX / 1.5, hitY / 1.5, model)
  T.eq(action, "marker", "stationary touch target still responds after NPC movement")
  T.eq(model.markers[slot].source.key, hitKey, "same touch target selects the same NPC")
  local mapKey = model.mapCacheKey
  display.explorer.filters.wildScope = "ROUTE"
  model = display.explorerModel(overview)
  T.eq(model.mapCacheKey, mapKey, "list scope changes reuse the unchanged map image")
  run.loader.modOptions.kanto_gear.info_level = "vanilla"
  local private = display.explorerModel(overview)
  T.eq(#private.markers, 0, "privacy changes remove spoiler markers immediately")
  T.eq(private.mapSnapshot, snapshot, "privacy changes retain spatial snapshot")
  T.check(private.mapCacheKey ~= model.mapCacheKey, "privacy changes invalidate the rendered viewport")
  run.loader.modOptions.kanto_gear.info_level = "spoiler"
  rows() -- Restore the same fixture after Discovery discarded its cached data.
  model = display.explorerModel(overview)
  T.eq(model.markers[2].x, 4, "restoring spoilers does not recapture moving NPCs")
  run.loader.events:emit("map.reloaded", { mapId = id })
  rows()
  T.eq(display.explorerModel(overview).mapSnapshot, snapshot, "same-area terrain reload retains spatial snapshot")
  display.explorer.view, display.explorer.selected = "trainers", model.markers[2].source.key
  model = display.explorerModel(overview)
  T.check(model.selected ~= nil, "captured trainer opens its details")
  T.eq(model.selected.x, 4, "detail focus uses captured coordinates")
  theme:explorer(model)
  local canvas = snapshot.canvas
  theme:explorer(model)
  T.eq(snapshot.canvas, canvas, "actual Explorer reuses its viewport cache")
  display.openHomeApp("explorer")
  T.check(canvas.released, "reopening releases previous viewport")
  rows()
  model = display.explorerModel(overview)
  T.eq(model.player.x, 2.5, "reopening keeps the current player")
  T.eq(model.markers[2].x, 17, "reopening captures current NPC")
  display.openHomeApp("settings")
  display.drawContents()
  T.eq(display.explorer.mapSnapshot, nil, "leaving Explorer discards snapshot")
  rows()
  T.eq(display.explorerModel(overview).mapSnapshot, nil, "widget models stay live outside Explorer")
  T.eq(display.explorerModel(overview).player.x, 2.5, "widget uses current player")
  display.localMapPosition = oldPosition
  objects.find, objects._mapId = oldFind, oldMap
end
dofile(path .. "/tests/gen3_fixture.lua")
