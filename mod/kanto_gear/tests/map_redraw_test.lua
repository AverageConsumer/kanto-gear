-- Real mod/SDK hooks; the bridge counts expensive host crossings, not GPU time.
local T = require("tests.modkit")
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local run = T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")),
  { generation = generation, data = T.fixtures.fresh() })
T.eq(run.mod and run.mod.state, "loaded", "idle test loads the complete mod")
local function hook(name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local world = { isOverworld = true, map = { id = "PALLET_TOWN" }, player = { cellX = 2, cellY = 3, px = 36, py = 52, facing = "down" } }
local game = { data = run.data, world = world, overworld = world,
  input = { pressQueue = {}, held = {} },
  save = { generation = generation, player = { name = "RED", id = 7, map = "PALLET_TOWN" },
    party = {}, inventory = {}, boxes = {}, pokedex = { seen = {}, caught = {} } },
  stack = { states = { world }, top = function(self) return self.states[#self.states] end } }
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", display_mode = "separate",
  display_target = "secondary", ui_motion = false }
run.loader.events:emit("game.ready", { game = game })
local compose, input = hook("render.compose"), hook("input.step")
local display = up(input, "displayRuntime")
local api = up(display.localMapPosition, "mod")
api.world = require(generation == 2 and "src.world.gen2.WorldAPI" or "src.world.WorldAPI").new(game, "kanto_gear")
local rows = {} for i = 1, 36 do rows[i] = string.rep(" ", 40) end
local overview = { mapId = "PALLET_TOWN", width = 40, height = 36, rows = rows, markers = {} }
api.world.mapOverview = function() return overview end
api.world.availableFieldActions = function() return {} end
local now, padCalls, padDown = 1, 0, false
T.love.timer.getTime = function() return now end
T.love.joystick = { getJoysticks = function()
  padCalls = padCalls + 1
  return { { isGamepadDown = function() return padDown end } }
end }
local bridge = { setEnabled = function() end, detected = function() return true end,
  pollTouch = function() end, push = function() return true end }
local canvas = up(up(compose, "pumpDisplay"), "canvas")
canvas.requestImageData, canvas.pollImageData = nil, nil
canvas.newImageData = function() return {} end
local full, partial = 0, 0
local drawContents, drawMap = display.drawContents, display.drawMapRefresh
display.drawContents = function() full = full + 1; return drawContents() end
display.drawMapRefresh = function()
  local drawn = drawMap(); if drawn then partial = partial + 1 end; return drawn
end
local function frame()
  input(function() end, game, 1 / 60)
  compose(function()
    if run.loader.modOptions.kanto_gear.display_mode == "combined" then
      run.loader.hooks:call("render.output", function() return false end,
        { canvas = canvas, width = 640, height = 480 })
    end
  end, {}, { secondScreen = bridge })
end
-- Camera and marker rounding can produce an identical image on a due tick.
-- Count those verified skips separately from missed movement updates.
local unchangedPixels = 0
local updateMapRefresh = display.updateMapRefresh
local theme = up(drawContents, "THEME").hgss
display.updateMapRefresh = function(time)
  local due = time + .000001 >= display.mapRefresh.nextAt
  local pos = due and display.localMapPosition()
  local model = display.explorer.renderModel
  local samePixels = due and up(compose, "page") == "LOCAL" and model and pos
    and theme:explorerMotionKey(model, pos) == display.mapRefresh.key
  local changed = updateMapRefresh(time)
  if samePixels and not changed then unchangedPixels = unchangedPixels + 1 end
  return changed
end
local function walk(page)
  up(compose, "page", page); up(compose, "dirty", true)
  world.player.px = 36
  display.mapRefresh.nextAt = now
  frame()
  local beforeFull, beforePartial = full, partial
  local beforeUnchanged = unchangedPixels
  for i = 1, 600 do
    now = now + 1 / 60; world.player.px = 36 + i
    if page == "HOME" and i % 12 == 0 then
      run.loader.events:emit("world.stepped", { mapId = "PALLET_TOWN" })
    end
    frame()
  end
  local painted = full - beforeFull + partial - beforePartial
  local updated = painted + unchangedPixels - beforeUnchanged
  T.check(updated >= 299 and updated <= 302, page .. " keeps 30 Hz movement without identical repaints")
  T.check(partial - beforePartial >= 270, page .. " skips static UI on most moving frames")
  T.check(full - beforeFull <= 25, page .. " refreshes data without painting every map frame")
  print(string.format("MAP_PAINT %s full=%d partial=%d total=%d", page,
    full - beforeFull, partial - beforePartial, painted))
end
walk("LOCAL")
T.eq(padCalls, 0, "disabled shortcuts enumerate no controllers over 600 frames")
local opts = run.loader.modOptions.kanto_gear
local poll = up(input, "pollScreenSwap")
opts.screen_swap = true; padDown = true
T.eq(poll(), true, "enabled controller shortcut still responds")
T.eq(poll(), false, "held controller fires once")
opts.screen_swap = false
T.eq(poll(), false, "disabling clears the held shortcut")
opts.screen_swap = true
T.eq(poll(), true, "re-enabling does not leave a stuck held state")
opts.screen_swap = false; opts.display_mode = "combined"; opts.combined_layout = "overlay"
opts.overlay_button = "f7"
local beforePads = padCalls
poll()
T.eq(padCalls, beforePads, "keyboard-only overlay shortcut skips controller discovery")
opts.overlay_button = "rightstick"; padDown = false; poll(); padDown = true
local _, overlayPressed = poll()
T.eq(overlayPressed, true, "controller overlay shortcut still responds")
opts.display_mode, opts.overlay_button = "separate", "off"; padDown = false
local function fullNext(label)
  local before = full
  up(compose, "dirty", true); now = now + .04; frame()
  T.eq(full, before + 1, label)
end
fullNext("ordinary invalidation redraws the whole page")
local state = display.mapRefresh
state.only = true; display.backgroundDim = .5
T.eq(drawMap(), false, "dimmed screens cannot retain old page pixels")
display.backgroundDim = 0
state.only = true
up(drawMap, "touchDown", { x = 1, y = 1 })
T.eq(drawMap(), false, "touch feedback always uses the complete painter")
display.session.touchDown = nil
display.motion.started = now
state.only = true
T.eq(drawMap(), false, "page transitions cannot reuse a partial frame")
display.motion.started = nil
game.stack.states[2] = { isTextBox = true }
state.only = true
T.eq(drawMap(), false, "dialogue cannot repaint an undimmed map")
game.stack.states[2] = nil
now = now + .51
state.only = true
T.eq(drawMap(), false, "expired models return to the complete painter")
do
  local model = display.explorerModel
  local oldGuide, oldArea = up(model, "guideData"), up(model, "areaData")
  local oldWild, oldMethods, oldKnown = display.explorerWildRows, display.explorerMethods, display.knownMap
  local guideCalls, wildCalls, methodCalls = 0, 0, 0
  up(model, "guideData", function() guideCalls = guideCalls + 1; return {rows={},caught=0} end)
  up(model, "areaData", function()
    return { sections = {
      { rows = { {id="trainer",label="TRAINER",x=2,y=3,done=false} } },
      { rows = { {id="item",kind="item",label="POTION",x=4,y=5,done=true},
        {id="gift",kind="item",gift=true,label="GIFT",x=6,y=7,available=true} } },
      { rows = { {id="hidden",kind="hidden",label="HIDDEN",x=8,y=9,done=false} } },
    }, pokemon = { {id="pokemon",kind="pokemon",gift=true,species=1,
      label="BULBASAUR",x=10,y=11,available=true} } }
  end)
  display.explorerWildRows = function() wildCalls = wildCalls + 1; return {} end
  display.explorerMethods = function() methodCalls = methodCalls + 1; return {} end
  display.knownMap = function() return true end
  opts.info_level = "spoiler"
  up(compose, "page", "HOME")
  display.explorer.data, display.explorer.renderModel = nil, nil
  local fullModel = model(overview)
  local beforeGuide, beforeWild, beforeMethods = guideCalls, wildCalls, methodCalls
  display.explorer.selected = "keep-my-selection"
  local mapModel = model(overview, true)
  T.eq(guideCalls, beforeGuide, "Home skips encounter-table construction")
  T.eq(wildCalls, beforeWild, "Home skips encounter sorting and filtering")
  T.eq(methodCalls, beforeMethods, "Home skips unused field-tool availability queries")
  T.eq(display.explorer.selected, "keep-my-selection", "Home preserves the Explorer selection")
  T.eq(#mapModel.markers, 5, "Home retains trainers, ground/hidden items and both gift kinds")
  T.eq(#mapModel.markers, #fullModel.markers, "Home and Explorer expose the same markers")
  for index, marker in ipairs(fullModel.markers) do
    local actual = mapModel.markers[index]
    for _, key in ipairs({"kind", "x", "y", "found", "state", "gift", "scanned"}) do
      T.eq(actual[key], marker[key], "Home preserves marker " .. index .. " " .. key)
    end
  end
  model(overview)
  T.eq(guideCalls, beforeGuide + 1, "opening Explorer reconstructs its full encounter data immediately")
  T.eq(wildCalls, beforeWild + 1, "opening Explorer restores its encounter list")
  up(model, "guideData", oldGuide); up(model, "areaData", oldArea)
  display.explorerWildRows, display.explorerMethods, display.knownMap = oldWild, oldMethods, oldKnown
  display.explorer.data, display.explorer.renderModel, display.explorer.selected = nil, nil, nil
end
display.home.layout = { tiles = { { id = "explorer_widget", page = 1, column = 1, row = 1 } } }
display.home.page, display.home.helpSeen, display.home.help = 1, true, false
walk("HOME")
local before = full
run.loader.events:emit("world.stepped", { mapId = "PALLET_TOWN" })
world.player.px = world.player.px + 8; now = now + .04; frame()
T.eq(full, before, "walking does not invalidate step-independent Home widgets")
for _, widget in ipairs({ "party", "team", "steps", "trainer", "achievements", "tool" }) do
  display.homeWidgetData({ explorer = true, [widget] = true })
  run.loader.events:emit("world.stepped", { mapId = "PALLET_TOWN" })
  T.eq(display.home.widgetCache, nil, widget .. " still invalidates after a step")
end
now = now + .04; world.player.px = world.player.px + 8; frame()
T.eq(full, before + 1, "step-sensitive widgets still trigger a complete refresh")
run.loader.events:emit("screen.pushed", {})
fullNext("native screen invalidation clears retained pixels")
opts.display_mode, opts.combined_layout = "combined", "side"
walk("LOCAL")
T.eq(state.only, false, "inline updates consume their hint before the next input tick")
fullNext("inline input invalidation cannot reuse an earlier movement hint")
opts.display_mode = "separate"
-- A slow native display must coalesce walking into the latest position.
local requests, inFlight, maximum, readyAt = 0, 0, 0, 0
canvas.requestImageData = function()
  requests, inFlight, readyAt = requests + 1, inFlight + 1, now + .1
  maximum = math.max(maximum, inFlight)
  return true
end
canvas.pollImageData = function()
  if inFlight > 0 and now >= readyAt then inFlight = inFlight - 1; return {} end
end
up(compose, "page", "LOCAL"); up(compose, "dirty", true)
for i = 1, 120 do
  now = now + 1 / 60; world.player.px = 100 + i; frame()
end
for _ = 1, 60 do now = now + 1 / 60; frame() end
T.eq(maximum, 1, "slow readback keeps exactly one frame in flight")
T.check(requests <= 22, "slow readback cannot accumulate historical movement frames")
T.eq(display.explorer.renderModel.player.x, world.player.px / 16,
  "readback completion paints the latest position without replaying a path")
run.release()
T.finish("Kanto Gear retained map painting")
