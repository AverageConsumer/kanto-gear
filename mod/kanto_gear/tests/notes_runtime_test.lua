package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local run = T.sdk.loadMod(path, { generation = 2, data = T.fixtures.load() })
T.eq(#run.errors, 0, "Notes package boots")
local function hook(id)
  for _, entry in ipairs(run.loader.hooks.chains[id] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local function up(fn, target, replacement)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, i)
    if name == target then
      if replacement ~= nil then debug.setupvalue(fn, i, replacement) end
      return value
    end
  end
  error("Missing upvalue " .. target)
end
local world = { map = { id = "ROUTE_32" } }
local game = { data = run.data, world = world,
  save = { generation = 2, version = "gold", meta = { playthroughId = "notes-test" },
    player = { name = "GOLD", id = 7, map = "ROUTE_32" }, party = {}, inventory = {}, boxes = {},
    pokedex = { seen = {}, caught = {} } },
  stack = { top = function() return world end, states = { world } } }
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", display_mode = "separate", display_target = "secondary" }
run.loader.events:emit("game.ready", { game = game })
local compose, pointer = hook("render.compose"), hook("input.pointer")
local display = up(hook("input.step"), "displayRuntime")
local theme = up(display.drawContents, "THEME")
local touch = up(compose, "touchEvent")
display.notes:bind(game, { read = function() return nil, "not_found" end, write = function() return true end })
T.check(display.setPackageInstalled("notes", true), "Notes installs from Silph Store")
T.check(display.openHomeApp("notes"), "Notes opens from Home")
T.check(display.notesShown(), "Notes owns active overworld Gear input")
local notes = display.notes
notes:action("new"); notes:type("Test"); notes:action("finish"); notes:action("view", "draw")
touch("down,101,201", 960, 864)
touch("move,181,241", 960, 864)
touch("up,221,281", 960, 864)
T.eq(notes:note().strokes[1].points[1], 15.25, "secondary scaling keeps subpixel points")
T.eq(#notes:note().strokes[1].points, 6, "secondary route forwards movement and release")

-- Freeze unrelated snapshot/clock work and the display transport. The real
-- compose hook must still drain motion every frame between its 50ms polls.
local now, queue, drained = 1, {}, 0
love.timer.getTime = function() return now end
local companion = { detected = function() return true end, setEnabled = function() end,
  pollTouch = function() local event = table.remove(queue, 1); if event then drained = drained + 1 end; return event end }
up(compose, "nextPoll", 10); up(compose, "nextClock", 10)
up(compose, "pumpDisplay", function() return true end)
display.updateStepRefresh = function() end
local canvas = up(compose, "canvas")
local w, h = canvas:getWidth(), canvas:getHeight()
local function event(action, x, y) return string.format("%s,%d,%d", action, x*w/240, y*h/216) end
queue = { event("down", 30, 70) }
compose(function() end, {}, { secondScreen = companion })
now = 1.016; queue = { event("move", 40, 75), event("move", 45, 78) }
compose(function() end, {}, { secondScreen = companion })
T.eq(drained, 3, "motion is drained before the next 50ms snapshot tick")
T.eq(#notes.stroke.points, 6, "both queued points reach the active stroke")
now = 1.032; queue = { event("up", 50, 80) }
compose(function() end, {}, { secondScreen = companion })
T.check(not notes.stroke, "release is handled in the next frame")
notes:takeChanged(); now = 1.040
compose(function() end, {}, { secondScreen = companion })
T.check(not notes:takeChanged(), "idle Notes does not request a redraw")

run.loader.modOptions.kanto_gear.display_mode = "combined"
local primary = up(pointer, "primaryTouch")
up(primary, "primaryBottomRect", { x = 100, y = 200, w = 480, h = 432 })
theme.nativeWindowLayout = { gameOnTop = true, game = { x = 0, y = 0, w = 100, h = 100 } }
local gameEvents = 0
local function nextPointer() gameEvents = gameEvents + 1 end
pointer(nextPointer, game, { phase = "pressed", x = 140.5, y = 300.5 })
pointer(nextPointer, game, { phase = "moved", x = 180.5, y = 340.5 })
T.eq(notes.stroke.points[1], 10.25, "primary mouse/stylus route preserves fractional coordinates")
pointer(nextPointer, game, { phase = "released", x = 50, y = 50 })
T.check(not notes.stroke, "release outside the drawing panel ends the captured stroke")
T.eq(gameEvents, 0, "captured drawing movement does not reach the game")
pointer(nextPointer, game, { phase = "pressed", x = 50, y = 50 })
T.eq(gameEvents, 1, "fresh top-screen input still reaches the game")
run.release()
T.finish("Notes touch integration")
