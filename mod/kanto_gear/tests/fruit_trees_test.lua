package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local run = T.sdk.loadMod(path, { generation = generation, data = T.fixtures.load() })
local world = { isOverworld = true, map = { id = "FIX_ROUTE" }, daytime = "DAY",
  player = { cellX = 2, cellY = 3, px = 36, py = 52, facing = "down" } }
local game = { data = run.data, world = world,
  save = { generation = generation, version = generation == 2 and "crystal" or "red",
    player = { name = "RED", map = "FIX_ROUTE", badges = {} },
    party = {}, inventory = {}, boxes = {},
    pokedex = { seen = {}, caught = {} } },
  stack = { states = { world }, top = function(self) return self.states[#self.states] end } }
run.loader.events:emit("game.ready", { game = game })
local function value(fn, key, replacement, set)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, current = debug.getupvalue(fn, i)
    if name == key then
      if set then debug.setupvalue(fn, i, replacement) end
      return current
    end
  end
  error("missing upvalue: " .. key)
end
local hook
for _, entry in ipairs(run.loader.hooks.chains["input.step"]) do
  if entry.owner == "kanto_gear" then hook = entry.callback end
end
local display = value(hook, "displayRuntime")
local api = value(display.localMapPosition, "mod")
api.world = require(generation == 2 and "src.world.gen2.WorldAPI"
  or "src.world.WorldAPI").new(game, "kanto_gear")
local theme = value(display.drawContents, "THEME")
value(display.updateMapRefresh, "page", "LOCAL", true)
local time = T.love.timer.getTime
local now = 0
T.love.timer.getTime = function() return now end
local pos = display.localMapPosition()
T.eq(pos.x, 2.25, "map uses the engine's intermediate horizontal pixel position")
T.eq(pos.y, 3.25, "map uses the engine's intermediate vertical pixel position")
T.eq(world.player.cellX, 2, "rendering does not move the logical player")
T.eq(display.localMapPosition("OTHER_MAP"), nil, "visual position never leaks onto a different map")
world.player.px, world.player.py = nil, nil
T.eq(display.localMapPosition().x, 2, "older hosts fall back to logical cells")
world.player.px, world.player.py = 36, 52
local rows = {} for i = 1, 36 do rows[i] = string.rep(" ", 40) end
local overview = { mapId = "FIX_ROUTE", width = 40, height = 36, rows = rows, markers = {} }

local fruits = require("src.core.gen2.Apricorns")
local function marker(model, tree)
  for _, entry in ipairs(model.markers) do
    if entry.kind == "fruit" and entry.source.tree == tree then return entry end
  end
end
run.data.gen2Maps = run.data.gen2Maps or {}
run.data.gen2Scripts = run.data.gen2Scripts or {}
run.data.items = run.data.items or {}
run.data.items.PSNCUREBERRY = { name = "GIFTBEERE", index = 9 }
run.data.items.RED_APRICORN = { name = "ROTE APRIKOKO", index = 10 }
run.data.gen2Maps.FIX_ROUTE = { objects = {
  { x = 4, y = 5, scriptKey = "BERRY" },
  { x = 7, y = 6, scriptKey = { { op = "fruittree", args = { 17 } } } },
  { x = 8, y = 6, scriptKey = "INVALID" },
} }
run.data.gen2Scripts.BERRY = { { op = "fruittree", args = { 5 } } }
run.data.gen2Scripts.INVALID = { { op = "fruittree", args = { 255 } } }
api.options:set("info_level", "enhanced")
local model = display.explorerModel(overview)
if generation == 1 then
  T.eq(marker(model, 5), nil, "Gen 1 never exposes Gen 2 fruit trees")
else
  local berry = marker(model, 5)
  T.check(berry ~= nil, "script-defined berry tree appears on the map")
  T.eq(berry.source.label, "GIFTBEERE", "tree name uses the live translated item")
  T.eq(berry.x, 4, "tree uses the map object's horizontal coordinate")
  T.eq(berry.y, 5, "tree uses the map object's vertical coordinate")
  T.eq(berry.picked, false, "fresh save trees are ready")
  T.eq(game.save.engineFlags, nil, "reading trees never initializes or mutates save flags")
  T.eq(game.save.fruitTrees, nil, "reading trees never initializes the picked table")
  T.eq(marker(model, 17).source.label, "ROTE APRIKOKO", "inline scripts also expose apricorns")
  T.eq(marker(model, 255), nil, "unknown tree ids are omitted")
  local items, trainers, image = model.itemsText, model.trainersText, model.image
  local composeHook
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner == "kanto_gear" then composeHook = entry.callback end
  end
  local tap = value(value(composeHook, "touchEvent"), "tap")
  local loadMap = value(tap, "loadLocalMap")
  value(loadMap, "localMap", overview, true)
  local hitX, hitY
  for y = 36, 90 do
    for x = 5, 155 do
      local action, slot = theme.hgss:explorerHit(x, y, model)
      if action == "marker" and model.markers[slot] == berry then
        hitX, hitY = x, y
        break
      end
    end
    if hitX then break end
  end
  T.check(hitX ~= nil, "fruit marker has a reachable touch target")
  tap(hitX, hitY)
  T.eq(display.explorer.view, "fruit", "touch opens the dedicated fruit view")
  T.eq(display.explorer.selected, berry.source.key, "touch selects the exact tree")
  model = display.explorerModel(overview)
  T.eq(model.selected.label, "GIFTBEERE", "marker selection resolves its fruit detail")
  T.eq(model.selectedMarker.source, model.selected, "selected marker is linked to detail")
  fruits.tryResetFruitTrees(game.save)
  fruits.pickTree(game.save, 5)
  local picked = display.explorerModel(overview)
  T.check(picked ~= model, "picking refreshes markers immediately inside the snapshot interval")
  T.eq(picked.selected.picked, true, "detail shows actual harvested state")
  T.eq(marker(picked, 17).picked, false, "other tree remains ready")
  T.eq(picked.image, image, "harvesting preserves the terrain image")
  T.eq(picked.itemsText, items, "renewable trees do not affect permanent item totals")
  T.eq(picked.trainersText, trainers, "tree status does not affect trainer totals")
  T.eq(display.explorerModel(overview), picked, "unchanged tree state reuses the render model")
  fruits.dailyReset(game.save)
  T.eq(game.save.fruitTrees[5], true, "host daily reset intentionally leaves stale picked bits")
  local ready = display.explorerModel(overview)
  T.eq(ready.selected.picked, false, "daily gate makes fruit ready before any tree interaction")
  T.eq(game.save.fruitTrees[5], true, "Gear does not clear the host's stale picked bits")
  T.eq(ready.image, image, "daily reset preserves the terrain image")
  fruits.tryResetFruitTrees(game.save)
  fruits.pickTree(game.save, 17)
  T.eq(marker(display.explorerModel(overview), 17).picked, true, "apricorn harvesting uses the same daily state")
  now = 0.6
  run.data.items.PSNCUREBERRY.name = "どくけしのみ"
  T.eq(display.explorerModel(overview).selected.label, "どくけしのみ", "content language changes reach tree details")
  game.save = { generation = 2 }
  T.eq(marker(display.explorerModel(overview), 17).picked, false, "loading a fresh save cannot retain harvested state")
end
T.love.timer.getTime = time
T.finish("Explorer fruit trees Gen " .. generation)
