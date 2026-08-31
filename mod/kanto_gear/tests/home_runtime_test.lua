package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local run = T.sdk.loadMod(path, {
  generation = 2,
  data = T.fixtures.load(),
})

T.eq(run.mod and run.mod.state, "loaded", "Kanto Gear loads")
T.eq(#run.errors, 0, "Kanto Gear boots without errors")

local world = { map = { id = "PALLET_TOWN" } }
local game = {
  data = run.data,
  save = {
    generation = 2,
    player = { name = "RED", id = 7, map = "PALLET_TOWN" },
    party = {}, inventory = {}, boxes = {}, currentBox = 1,
    pokedex = { seen = {}, caught = {} },
  },
  world = world,
  stack = { states = { world }, top = function(self)
    return self.states[#self.states]
  end },
}
run.loader.events:emit("game.ready", { game = game })
run.loader.modOptions.kanto_gear = { theme = "hgss" }
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "theme" })

local function upvalue(fn, target)
  for index = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, index)
    if name == target then return value end
  end
end

local inputHook
for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
  if entry.owner == "kanto_gear" then inputHook = entry.callback end
end
local display = upvalue(inputHook, "displayRuntime")
T.check(type(display) == "table", "Home runtime is reachable")
local composeHook
for _, entry in ipairs(run.loader.hooks.chains["render.compose"] or {}) do
  if entry.owner == "kanto_gear" then composeHook = entry.callback end
end
local touchEvent = upvalue(composeHook, "touchEvent")
local tap = upvalue(touchEvent, "tap")
local function page()
  return upvalue(display.openHomeApp, "page")
end

local home, catalog, store = display.home, display.homeCatalog,
  display.storeById
home.layout = { tiles = {
  { id = "tools_app", page = 1, column = 1, row = 1 },
  { id = "party_app", page = 1, column = 4, row = 1 },
} }

T.eq(display.storeEntry(store.tools).state, "open",
  "bundled installed apps open without a fake update state")
T.eq(display.storeEntry(store.party).reason, "TEAM STATUS",
  "Store recommendations receive their runtime reason text")
T.check(display.setPackageInstalled("tools", false),
  "removable bundled apps can be disabled")
T.eq(display.storeEntry(store.tools).state, "get",
  "disabled bundled apps return to GET")
T.eq(display.Home.find(home.layout, "tools_app"), nil,
  "removing an app also removes its Home surfaces")
T.check(not display.setPackageInstalled("party", false),
  "fixed system apps cannot be removed")
T.check(not display.setPackageInstalled("notes", true),
  "unfinished apps cannot be enabled")
T.eq(display.storeEntry(store.notes).state, "soon",
  "unfinished apps stay marked SOON")
T.check(display.setPackageInstalled("tools", true),
  "removed bundled apps can be enabled again")
T.eq(display.storeEntry(store.tools).state, "open",
  "enabled bundled apps return to OPEN")

home.storeView, home.storeDetail = "apps", nil
display.setPackageInstalled("tools", false)
display.tapStore(160, 170)
T.eq(display.storeEntry(store.tools).state, "open",
  "the visible GET button enables its matching app")
home.storeDetail = "tools"
display.tapStore(180, 65)
T.eq(display.storeEntry(store.tools).state, "get",
  "the detail REMOVE button disables its matching app")
display.setPackageInstalled("tools", true)
T.check(display.Home.place(home.layout, catalog, "tools_app", 2, 1, 1),
  "an enabled app can be added to a later Home page")
display.saveHome()
catalog.packages.tools.installed, home.layout = false, { tiles = {} }
display.loadHome()
local savedTools = display.Home.find(home.layout, "tools_app")
T.check(catalog.packages.tools.installed,
  "enabled app state survives a save reload")
T.check(savedTools and savedTools.page == 2,
  "Home placement survives a save reload")

tap(60, 49)
T.eq(page(), "PARTY", "tapping a Home icon opens its installed app")
tap(80, 80)
T.eq(page(), "PARTY", "touching app content does not close the app")
T.eq(home.activeApp, "party", "app ownership survives content touches")
tap(5, 5)
T.eq(page(), "HOME", "the app header back button returns Home")
T.eq(home.activeApp, nil, "returning Home clears app ownership")

T.check(display.openHomeApp("explorer"), "Explorer opens from Home")
display.explorer.view = "wild"
tap(5, 5)
T.eq(page(), "LOCAL", "Explorer back closes its internal view first")
T.eq(display.explorer.view, nil, "Explorer internal view closes")
T.eq(home.activeApp, "explorer", "Explorer remains open after internal back")
tap(5, 5)
T.eq(page(), "HOME", "Explorer root back returns Home")

home.layout = { tiles = {
  { id = "explorer_widget", page = 1, column = 1, row = 1 },
} }
home.page, home.editing, home.library, home.swapSource = 1, true, false, nil
display.tapHome(180, 60)
T.eq(home.addSlot.column, 8, "the editor exposes the space beside Explorer")
local apps = display.Home.library(home.layout, catalog, 1,
  home.addSlot.column, home.addSlot.row, "app")
local toolsIndex
for index, item in ipairs(apps) do
  if item.id == "tools_app" then toolsIndex = index end
end
T.check(toolsIndex and toolsIndex <= 6, "Tools is visible in Add to Home")
local visible = toolsIndex - 1
display.tapHome(15 + visible % 2 * 111,
  54 + math.floor(visible / 2) * 48)
local centeredTools = display.Home.find(home.layout, "tools_app")
T.eq(centeredTools.column, 9,
  "a three-column app is centered inside Explorer's five-column gap")

home.layout = { tiles = {
  { id = "tools_app", page = 1, column = 1, row = 1 },
  { id = "trainer_app", page = 2, column = 1, row = 1 },
} }
home.page, home.editing, home.library, home.swapSource = 1, true, false, nil
display.tapHome(30, 70)
T.eq(home.swapSource, "tools_app", "tapping an app selects it for swapping")
touchEvent("down,140,100")
touchEvent("up,20,100")
T.eq(home.page, 2, "the selected app survives a swipe to the next Home page")
display.tapHome(30, 70)
T.eq(display.Home.find(home.layout, "tools_app").page, 2,
  "tapping an app on another page swaps it with the selection")
T.eq(display.Home.find(home.layout, "trainer_app").page, 1,
  "the cross-page swap returns the other app to the source position")
T.eq(home.swapSource, nil, "a completed swap clears the selection")
display.tapHome(30, 70)
touchEvent("down,140,100")
touchEvent("up,20,100")
display.tapHome(120, 70)
local movedTools = display.Home.find(home.layout, "tools_app")
T.eq(home.page, 3, "swiping reaches a new empty Home page")
T.eq(movedTools.page, 3, "an empty region accepts the selected app")
T.eq(movedTools.column, 5,
  "an app moved to an empty row snaps to its centered position")

local api = upvalue(display.saveHome, "mod")
api.device = api.device or {
  powerInfo = function() return "battery", 80 end,
}
display.openHomeApp("store")
T.check(pcall(display.drawContents),
  "the real Store runtime model renders without an exception")
local theme = upvalue(display.drawContents, "THEME")
touchEvent("down,20,30")
T.check(pcall(display.drawContents),
  "an active touch renders through the shared HGSS pressed layer")
T.eq(theme.hgss.touchX, 20, "touch-down reaches the HGSS renderer immediately")
touchEvent("cancel,0,0")
T.check(pcall(display.drawContents), "touch cancel redraws safely")
T.eq(theme.hgss.touchX, nil, "touch cancel clears the pressed state")

run.release()
T.finish("Kanto Gear Home runtime")
