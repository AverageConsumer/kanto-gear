package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
love.graphics.transformPoint = love.graphics.transformPoint or function(x, y) return x, y end
local gen = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local run = T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")),
  { generation = gen, data = T.fixtures.load() })
assert(run.mod, run.error or run.reason)
local function hook(name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
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

local function settle(setup)
  if setup then setup() end
  now = now + 1; draw(); now = now + .3; draw()
end
local function still(label, action)
  action(); now = now + .01; draw()
  T.eq(display.motion.started, nil, label .. " updates in place")
end
local function flip(label, action, direction, top, bottom)
  action(); now = now + .01; clips = {}; draw()
  T.eq(display.motion.direction, direction, label .. " follows the pressed direction")
  T.check(display.motion.started ~= nil, label .. " starts a content transition")
  local found = false
  for _, rect in ipairs(clips) do
    if rect[2] == top and rect[4] == bottom - top then found = true end
  end
  T.check(found, label .. " keeps everything outside its content stationary")
  local count, allocated = paints, allocations
  for frame = 1, 8 do now = now + 1 / 60; draw() end
  T.eq(paints, count, label .. " reuses rendered content")
  T.eq(allocations, allocated, label .. " allocates no intermediate canvases")
end

-- Both directions, including wrapping from last to first and first to last.
local cases = {
  { "bag", "BAG", function() display.bag.detail = nil; display.bag.pocket = 1 end,
    display.bag, "page", 70, 214 },
  { "settings", "SETTINGS", function() display.settings.category = "display" end,
    display.settings, "page", 70, 166 },
  { "home", "HOME", function() display.home.library = false; display.home.editing = false end,
    display.home, "page", 30, 199 },
  { "catalog", "HOME", function() display.home.library = true; display.home.libraryKind = "app" end,
    display.home, "libraryPage", 49, 195 },
  { "dex index", "POKEDEX", function() display.pokedex.view = "index" end,
    display.pokedex, "page", 66, 197 },
  { "dex moves", "POKEDEX", function() display.pokedex.view = "moves"; display.pokedex.selected = 1 end,
    display.pokedex, "movePage", 74, 197 },
  { "dex habitats", "POKEDEX", function() display.pokedex.view = "habitat"; display.pokedex.selected = 1 end,
    display.pokedex, "habitatPage", 86, 197 },
  { "stamps", "ACHIEVEMENTS", function() display.achievements.view = "album" end,
    display.achievements, "page", 77, 209 },
  { "stamp finds", "ACHIEVEMENTS", function() display.achievements.view = "finds"; display.achievements.category = 1 end,
    display.achievements, "page", 56, 211 },
  { "stamp Pokemon", "ACHIEVEMENTS", function() display.achievements.view = "finds"; display.achievements.category = 4 end,
    display.achievements, "page", 56, 189 },
  { "explorer default", "LOCAL", function() display.explorer.view = nil; display.explorer.selected = nil end,
    display.explorer, "page", 156, 214 },
  { "explorer explicit", "LOCAL", function() display.explorer.view = "wild"; display.explorer.selected = nil end,
    display.explorer, "page", 156, 214 },
  { "explorer details", "LOCAL", function() display.explorer.selected = "mon" end,
    display.explorer, "detailPage", 97, 210 },
  { "store apps", "STORE", function() display.home.storeView = "apps"; display.home.storeConfirm = nil end,
    display.home.storePages or {}, "apps", 58, 164 },
  { "notes list", "NOTES", function() display.notes.view = "list" end,
    display.notes, "page", 57, 149 },
  { "notes text", "NOTES", function() display.notes.view = "text" end,
    display.notes, "page", 89, 172 },
  { "notes tasks", "NOTES", function() display.notes.view = "tasks" end,
    display.notes, "page", 89, 172 },
}
for _, case in ipairs(cases) do
  settle(function()
    page(case[2]); case[3](); case[4][case[5]] = 1
    if case[2] == "STORE" then display.home.storePages = case[4] end
  end)
  for _, pair in ipairs({ {2,1}, {1,-1}, {3,-1}, {1,1} }) do
    flip(case[1], function()
      display.requestPageMotion(pair[2]); case[4][case[5]] = pair[1]
    end, pair[2], case[6], case[7])
  end
  still(case[1] .. " automatic page correction", function() case[4][case[5]] = 2 end)
end

-- Exercise the actual Explorer tap handler, including its page reset.
local tap = up(up(hook("render.compose"), "touchEvent"), "tap")
local loadMap = up(tap, "loadLocalMap")
up(tap, "loadLocalMap", function() return { mapId = "PALLET_TOWN" } end)
local model, hit = display.explorerModel, theme.explorerHit
display.explorerModel = function()
  return { filters = display.explorer.filters, pages = 3, detailPages = 2 }
end
local action
theme.explorerHit = function() return action end
for _, view in ipairs({ false, "wild" }) do
  settle(function()
    page("LOCAL"); display.explorer.view = view or nil
    display.explorer.selected = nil; display.explorer.page = 2
    display.explorer.filters.wildScope = "HERE"
  end)
  still("Here Now page 2 to Whole Route", function() action = "wild_route"; tap(80, 100) end)
  T.eq(display.explorer.page, 1, "real filter handler resets page")
  flip("real Explorer pager", function() action = "next"; tap(80, 100) end, 1, 156, 214)
  still("in-flight Whole Route to Here Now", function() action = "wild_here"; tap(80, 100) end)
  flip("real Explorer reverse wrap", function() action = "prev"; tap(80, 100) end, -1, 156, 214)
  still("map expansion", function() action = "map_toggle"; tap(80, 100) end)
  still("map collapse", function() action = "map_toggle"; tap(80, 100) end)
end
display.explorerModel, theme.explorerHit = model, hit
up(tap, "loadLocalMap", loadMap)
settle(function() page("BAG"); display.bag.detail = nil; display.bag.page = 2 end)
still("bag pocket with page reset", function() display.bag.pocket = 2; display.bag.page = 1 end)
still("item details", function() display.bag.detail = 1 end)
still("item result message", function() display.bag.message = { "USED" } end)
still("back from item", function() display.bag.detail = nil; display.bag.message = nil end)
settle(function() page("SETTINGS"); display.settings.category = "display"; display.settings.page = 2 end)
still("settings category and page reset", function() display.settings.category = "audio"; display.settings.page = 1 end)
still("settings confirmation", function() display.settings.confirm = "reset" end)
still("confirmation dismissed", function() display.settings.confirm = nil end)
settle(function() page("HOME"); display.home.library = true; display.home.libraryKind = "app"; display.home.libraryPage = 2 end)
still("Apps to Widgets", function() display.home.libraryKind = "widget"; display.home.libraryPage = 1 end)
still("library closing", function() display.home.library = false end)
still("Home edit controls", function() display.home.editing = true end)
display.home.editing = false
settle(function() page("STORE"); display.home.storeView = "apps"; display.home.storePages.apps = 2 end)
still("Store tab", function() display.home.storeView = "today" end)
still("Store confirm", function() display.home.storeView = "apps"; display.home.storeConfirm = "notes" end)
still("Store confirm closed", function() display.home.storeConfirm = nil end)
settle(function() page("POKEDEX"); display.pokedex.view = "habitat"; display.pokedex.habitatPage = 2 end)
still("Dex tab resets pages", function() display.pokedex.view = "moves"; display.pokedex.movePage = 1 end)
still("Dex species selection", function() display.pokedex.selected = 2 end)
still("Dex back", function() display.pokedex.view = "profile" end)
still("Dex description paging", function() display.pokedex.descriptionPage = 2 end)
settle(function() page("NOTES"); display.notes.view = "list"; display.notes.page = 2; display.notes.filter = "here" end)
still("Notes filter", function() display.notes:action("filter", "all") end)
settle(function() display.notes.view = "text"; display.notes.page = 2 end)
still("Notes tab", function() display.notes.view = "tasks"; display.notes.page = 1 end)
-- No generic fade may reintroduce motion on native prompts/menus.
settle(function() page("PARTY") end)
still("native screen change", function() game.stack.states[2] = { screenId = "Quantity" } end)
still("native screen closes", function() game.stack.states[2] = nil end)
settle(function() page("HOME") end)
page("BAG"); now = now + .1; draw()
T.eq(display.motion.direction, 1, "whole-app opening still travels forward")
page("HOME"); now = now + .05; draw()
T.eq(display.motion.direction, -1, "whole-app back still travels back")


page("NOTES");
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
run.loader.modOptions.kanto_gear.ui_motion = true
display.optionsChanged({ mod = "kanto_gear", key = "ui_motion", value = true })
page("HOME"); now = 22.1; draw(); page("BAG"); now = 22.2; draw()
T.check(display.motion.started ~= nil, "quality permits transitions before profile changes")
runtime.beginAnimation("party_swap_commit")
theme:beginPartyAction(now)
theme:endPartyAction(now + .01)
run.loader.modOptions.kanto_gear.map_motion = "performance"
display.optionsChanged({ mod = "kanto_gear", key = "map_motion", value = "performance" })
T.eq(display.motion.started, nil, "performance cancels an already running page transition")
T.eq(runtime.animation, nil, "performance cancels an already queued special animation")
T.eq(theme.motionEnabled, false, "performance suppresses theme animation")
T.check(not theme:partyActionAnimating(now + .02), "performance immediately settles an in-flight party action")
T.check(theme:partyActionClosed(now + .02), "disabling animation cannot leave a closing action stuck")
T.eq(run.loader.modOptions.kanto_gear.ui_motion, true, "profile preserves the user's quality transition preference")
local before = allocations
page("PARTY"); now = 22.3; draw()
T.eq(display.motion.started, nil, "performance app navigation shows the destination immediately")
T.eq(allocations, before, "performance navigation allocates no transition canvases")
runtime.beginAnimation("battle_moves")
T.eq(runtime.animation, nil, "performance also suppresses battle animations")
T.same({ theme:battleContinueMotion(22.4) }, { theme:battleContinueMotion(23.4) },
  "continue arrow stays visible and stationary")
T.eq(display.optionVisible(display.optionRow("ui_motion")), false,
  "performance hides its overridden transition control")
run.loader.modOptions.kanto_gear.map_motion = "quality"
display.optionsChanged({ mod = "kanto_gear", key = "map_motion", value = "quality" })
T.eq(theme.motionEnabled, true, "returning to quality restores the saved preference")
T.eq(display.optionVisible(display.optionRow("ui_motion")), true, "quality restores the transition control")
run.loader.modOptions.kanto_gear.ui_motion = false
display.optionsChanged({ mod = "kanto_gear", key = "ui_motion", value = false })
run.loader.modOptions.kanto_gear.map_motion = "performance"
display.optionsChanged({ mod = "kanto_gear", key = "map_motion", value = "performance" })
run.loader.modOptions.kanto_gear.map_motion = "quality"
display.optionsChanged({ mod = "kanto_gear", key = "map_motion", value = "quality" })
T.eq(theme.motionEnabled, false, "an explicit Off preference also survives profile round trips")
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
run.loader.modOptions.kanto_gear.ui_motion = true
runtime.animation = nil
page("HOME"); now = 30; draw()
-- A replaced native owner must not inherit a cached app page.
page("BAG"); now = now + .01; draw()
game.stack.states[1] = { map = world.map }
now = now + .02; draw()
T.eq(display.motion.started, nil, "replacing the native owner cancels cached motion even with the same screen key")
game.stack.states[1] = world

-- Summary tabs belong to Gear; native page/cursor changes do not pan the screen.
local summary = { screenId = gen == 2 and "Gen2SummaryMenu" or "SummaryMenu", page = 1, mon = {} }
game.stack.states[2] = summary
settle()
for _,pair in ipairs({{1,2},{2,3},{3,1},{1,3},{3,2},{2,1}}) do
  still("native summary page " .. pair[1] .. " to " .. pair[2],function() summary.page=pair[2] end)
end
still("native summary selection",function() summary.moveIndex=2 end)
still("native summary partner",function() summary.mon={} end)

game.stack.states[2] = nil; runtime.animation = nil
settle()
for _, transition in ipairs({
  { "battle_party", 1 }, { "battle_party_close", -1 },
  { "battle_bag", -1 }, { "battle_bag_close", 1 },
  { "battle_moves", 1 }, { "battle_moves_close", -1 },
  { "battle_move_info", 1 }, { "battle_move_info_close", -1 },
}) do
  now = now + 1
  -- A native panel changes the screen key independently of app navigation.
  game.stack.states[2] = { screenId = transition[1] }
  runtime.beginAnimation(transition[1]); draw()
  T.eq(runtime.animation, nil, transition[1] .. " uses the live screen compositor")
  T.eq(display.motion.direction, transition[2], transition[1] .. " travels in the expected direction")
  T.eq(display.motion.top, 28, transition[1] .. " keeps the header area stationary")
  local startPaints, startAllocations = paints, allocations
  for frame = 1, 12 do now = now + 1 / 60; draw() end
  T.eq(paints, startPaints, transition[1] .. " never rebuilds cards during movement")
  T.eq(allocations, startAllocations, transition[1] .. " reuses its two canvases")
  now = now + .1; draw()
  T.eq(display.motion.started, nil, transition[1] .. " completes without restarting")
  T.eq(paints, startPaints + 1, transition[1] .. " returns to fresh live rendering")
end
game.stack.states[2] = nil
runtime.animation = nil
G.newCanvas, G.draw, G.setScissor = newCanvas, drawImage, scissor
run.release()
T.finish("Kanto Gear motion Gen " .. gen)
