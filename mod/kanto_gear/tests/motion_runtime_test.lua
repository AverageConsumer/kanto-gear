package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
love.graphics.transformPoint = love.graphics.transformPoint or function(x, y) return x, y end
local gen = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local run = T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")),
  { generation = gen, data = T.fixtures.load() })
local function hook(name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local function up(fn, key, replacement)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, i)
    if name == key then
      if replacement ~= nil then debug.setupvalue(fn, i, replacement) end
      return value
    end
  end
  error("missing " .. key)
end
local world = { map = { id = "PALLET_TOWN" } }
local game = { data = run.data, world = world, overworld = world,
  save = { generation = gen, player = { name = "RED", map = "PALLET_TOWN" },
    party = {}, inventory = {}, boxes = {}, pokedex = { seen = {}, caught = {} } },
  stack = { states = { world }, top = function(self) return self.states[#self.states] end } }
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", ui_motion = true }
run.loader.events:emit("game.ready", { game = game })
local display = up(hook("input.step"), "displayRuntime")
local theme = up(display.drawContents, "THEME").hgss
local draw = up(hook("render.output"), "draw")
local runtime = up(hook("input.step"), "hgssRuntime")
local now, paints, allocations = 10, 0, 0
love.timer.getTime = function() return now end
local G = love.graphics
local newCanvas, drawImage, scissor = G.newCanvas, G.draw, G.setScissor
G.newCanvas = function(...) allocations = allocations + 1; return newCanvas(...) end
local draws, clips = {}, {}
G.draw = function(image, x, y, ...) draws[#draws + 1] = { image, x, y }; return drawImage(image, x, y, ...) end
G.setScissor = function(...) clips[#clips + 1] = {...}; return scissor(...) end
display.drawContents = function() paints = paints + 1 end
local function page(value) up(display.updateMapRefresh, "page", value) end
page("HOME"); draw()
T.eq(display.motion.started, nil, "initial view is immediately visible")
page("BAG"); now = 11; draw()
T.eq(display.motion.direction, 1, "opening an app travels forward")
T.eq(display.motion.duration, .20, "ordinary navigation uses a short shared duration")
local initialPaints, initialAllocations = paints, allocations
for i = 1, 10 do now = 11 + i / 60; draw() end
T.eq(paints, initialPaints, "intermediate frames reuse the rendered destination")
T.eq(allocations, initialAllocations, "intermediate frames allocate no canvases")
local contentClip = false
for _, rect in ipairs(clips) do if rect[2] == 28 and rect[4] == 188 then contentClip = true end end
T.check(contentClip, "page movement is restricted below the fixed header")
now = 11.25; draw()
T.eq(display.motion.started, nil, "the animation stops at its duration")
T.eq(paints, initialPaints + 1, "completion redraws fresh live data")
display.bag.detail = 1; now = 12; draw()
T.eq(display.motion.direction, 1, "opening item details travels forward")
display.bag.detail = nil; now = 12.05; draw()
T.eq(display.motion.direction, -1, "back replaces an in-flight transition")
T.eq(display.motion.started, now, "interrupted navigation starts from the currently visible frame")
page("HOME"); now = 13; draw()
T.eq(display.motion.direction, -1, "returning home travels back")
page("SETTINGS"); now = 14; draw()
local key = display.motionKey()
display.settings.category = "display"; now = 15; draw()
T.check(display.motionKey() ~= key, "settings categories are separate navigation states")
key = display.motionKey(); display.settings.page = 2; now = 16; draw()
T.check(display.motionKey() ~= key, "settings pages are separate navigation states")
display.settings.page = 1; now = 17; draw()
T.eq(display.motion.direction, -1, "previous settings page travels back")
page("STORE"); display.home.storeView = "apps"; display.home.storePages = { apps = 1 }
key = display.motionKey(); display.home.storePages.apps = 2
T.check(display.motionKey() ~= key, "store pagination participates in navigation")
page("POKEDEX"); display.pokedex.view, display.pokedex.selected = "index", 1
T.eq(display.navigationState().depth, 1, "returning to the dex index ignores retained selection")
page("ACHIEVEMENTS"); display.achievements.view = "location"
T.eq(display.navigationState().depth, 4, "stamp locations are deeper than finds and details")
page("LOCAL"); key = display.motionKey()
display.explorer.filters.wildScope = "ROUTE"
T.eq(display.motionKey(), key, "encounter filters do not become page transitions")
page("NOTES"); display.notes.view = "list"; now = 18; draw()
key = display.motionKey(); display.notes.view = "tasks"; now = 19; draw()
T.check(display.motionKey() ~= key, "Notes tabs have their own navigation state")
display.notes.view = "draw"; now = 19.01; draw()
T.eq(display.motion.started, nil, "drawing interrupts navigation immediately")
display.notes.view = "edit"; draw()
T.eq(display.motion.started, nil, "typing never waits for navigation")
page("HOME"); now = 20; draw(); page("BAG"); now = 21; draw()
display.dispatchTouchTap(function() end, 0, 0)
T.eq(display.motion.started, nil, "accepted direct actions interrupt cached presentation")
run.loader.modOptions.kanto_gear.ui_motion = false
page("HOME"); now = 22; draw()
T.eq(display.motion.started, nil, "disabled transitions show the destination directly")
theme.motionEnabled = false; theme:endPartyAction(22)
T.check(theme:partyActionClosed(22), "disabled transitions also close party actions immediately")
theme.motionEnabled = true
local cards = {}
theme:partySwapCommitTransition(function(slot, x, y) cards[slot] = { x, y } end, 1, 6, 1)
local x, y = theme:partyPosition(6)
T.same(cards[1], {x, y}, "source card reaches the target slot")
x, y = theme:partyPosition(1)
T.same(cards[6], {x, y}, "target card reaches the source slot")
local scale, scaled = G.scale, false
G.scale = function() scaled = true end
theme:partySwapCommitTransition(function(_, px, py)
  T.check(px == math.floor(px) and py == math.floor(py), "moving cards stay on whole pixels")
end, 1, 6, .5)
T.check(not scaled, "party swaps never squash text or sprites")
for source = 1, 6 do
  for target = 1, 6 do
    theme:partySwapCommitTransition(function(_, px, py)
      assert(px >= 5 and px <= 123 and py >= 32 and py <= 152,
        "swap escaped content area")
    end, source, target, .5)
  end
end
T.check(true, "all swap pairs stay below the header and above the bottom edge")
G.scale = scale
local pages = {}
theme.summaryPage = function() pages[#pages + 1] = 1 end
theme.summaryMemo = function() pages[#pages + 1] = 3 end
theme:summaryPageTransition({}, function() end, .5, 3, 1)
T.same(pages, {3, 1}, "summary wrap renders both adjacent states")
local translate = G.translate
local shifts = {}
G.translate = function(x, y) shifts[#shifts + 1] = x end
theme.summaryMoves = function() pages[#pages + 1] = 2 end
for _, pair in ipairs({ {1,2,1}, {2,3,1}, {3,1,1}, {2,1,-1}, {3,2,-1}, {1,3,-1} }) do
  pages, shifts = {}, {}
  theme:summaryPageTransition({}, function() end, .5, pair[1], pair[2])
  T.same(pages, {pair[1], pair[2]}, "summary renders the correct two pages " .. pair[1] .. " to " .. pair[2])
  T.same(shifts, {-120 * pair[3], 120 * pair[3]}, "summary carousel direction " .. pair[1] .. " to " .. pair[2])
end
G.translate = translate
run.loader.modOptions.kanto_gear.ui_motion = true
runtime.beginAnimation("summary_open")
T.eq(runtime.animation.duration, .24, "hero transitions share the shorter duration")
run.loader.modOptions.kanto_gear.battle_view = "gear"
runtime.beginAnimation("battle_moves")
local battleDuration = runtime.animation.duration
T.eq(battleDuration, .28, "battle movement gets enough frames within a short transition")
local fightY, stripClip, clip = nil, nil, nil
local getScissor = G.getScissor
G.getScissor = function() if clip then return unpack(clip) end end
G.setScissor = function(...) clip = select("#", ...) > 0 and {...} or nil end
theme.battleFightAction = function(_, _, _, _, _, offsetY)
  fightY = offsetY
  assert(clip and clip[2] == 28, "outgoing controls must pass behind the header")
end
theme.battleBagAction, theme.battlePartyAction, theme.battleRunAction =
  function() end, function() end, function() end
theme.battleMoveCard, theme.moveHasStab = function() end, function() return false end
theme.battleTeamStrip = function() stripClip = clip end
local last, leavesCompletely = 0, true
for i = 0, 100 do
  theme:battleMovesTransition({ moves = {} }, function() end, {}, {}, i / 100)
  assert(fightY <= last, "fight exit reversed direction")
  last = fightY
  if i >= 85 then leavesCompletely = leavesCompletely and 32 + 122 + 3 + fightY < 0 end
end
T.check(leavesCompletely, "fight card and shadow are fully offscreen before its exit finishes")
T.eq(stripClip, nil, "the stationary team strip is drawn outside the content clip")
theme:battleMovesTransition({ moves = {} }, function() end, {}, {}, 0)
T.eq(fightY, 0, "the reverse transition returns the fight card to its exact resting position")
local maxJump, visibleFrames = 0, 0
last = 0
for frame = 1, math.ceil(battleDuration * 60) do
  theme:battleMovesTransition({ moves = {} }, function() end, {}, {}, frame / 60 / battleDuration)
  maxJump = math.max(maxJump, math.abs(fightY - last)); last = fightY
  if 32 + 122 + 3 + fightY > 28 then visibleFrames = visibleFrames + 1 end
end
T.check(maxJump <= 18, "fight movement has no large position jumps at 60 Hz")
T.check(visibleFrames >= 9, "fight exit has enough visible intermediate frames")
G.getScissor = getScissor
G.newCanvas, G.draw, G.setScissor = newCanvas, drawImage, scissor
run.release()
T.finish("Kanto Gear motion Gen " .. gen)
