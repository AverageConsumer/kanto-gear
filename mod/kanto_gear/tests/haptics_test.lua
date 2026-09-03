-- Run from the host SDK with generation 1 or 2. No device vibration in tests.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local generation = assert(tonumber(arg[1]))
local Loader = require("src.mods.Loader")
local nativeApi = Loader._api
Loader._api = function(self, loadedMod)
  local api = nativeApi(self, loadedMod)
  -- Older headless SDKs lack the native setter; the fallback has its own suite.
  api.options.set = api.options.set or function(_, key, value)
    self.modOptions[api.id] = self.modOptions[api.id] or {}
    self.modOptions[api.id][key] = value
    self.events:emit("mod.options_changed", { mod = api.id, key = key, value = value })
    return true
  end
  return api
end
local run = T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")), {
  generation = generation, data = T.fixtures.fresh(),
})
Loader._api = nativeApi
T.eq(run.mod.state, "loaded", "complete mod loads with haptics")
local function upvalue(fn, target, replacement, set)
  for index = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, index)
    if name == target then
      if set then debug.setupvalue(fn, index, replacement) end
      return value
    end
  end
  error("missing upvalue " .. target)
end
local function hook(name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local display = upvalue(hook("input.step"), "displayRuntime")
local theme = upvalue(display.drawContents, "THEME")
local api = upvalue(display.saveHome, "mod")
local touch = upvalue(hook("render.compose"), "touchEvent")
local world = { map = { id = "ROUTE_1" }, player = { cellX = 10, cellY = 10 } }
local game = { data = run.data, world = world,
  input = { sourcePress = function() end, sourceRelease = function() end },
  save = { generation = generation, player = { name = "RED", map = "ROUTE_1" },
    inventory = { ITEMFINDER = 1 }, party = {}, boxes = {},
    hiddenTaken = {}, pokedex = { seen = {}, caught = {} },
    options = { haptics = "off" } },
  stack = { states = { world }, top = function(self) return self.states[#self.states] end } }
run.loader.events:emit("game.ready", { game = game })
local home = display.home
home.help, home.helpSeen = false, true
local pulses, now = {}, 10
local oldTime, oldSystem = love.timer.getTime, love.system
local oldVibrate = oldSystem and oldSystem.vibrate
love.timer.getTime = function() return now end
love.system = love.system or {}
love.system.vibrate = function(seconds) pulses[#pulses + 1] = seconds end
local function homePage()
  upvalue(display.openHomeApp, "page", "HOME", true)
  home.page, home.editing, home.library, home.swapSource = 1, false, false, nil
  home.layout = { tiles = {
    { id = "map_app", page = 1, column = 1, row = 1 },
    { id = "store_app", page = 1, column = 4, row = 1 },
  } }
end
local function coords(id)
  for _, tile in ipairs(display.homePageElements()) do
    if tile.id == id then
      local x, y, w, h = theme.hgss:homeRect(tile)
      return x + math.floor(w / 2), y + math.floor(h / 2)
    end
  end
  error("missing tile " .. id)
end
local function event(action, x, y)
  touch(string.format("%s,%d,%d", action,
    math.floor(x / theme.hgssScale), math.floor(y / theme.hgssScale)))
end
homePage()
local x, y = coords("map_app")
event("tap", x, y)
T.eq(#pulses, 0, "default OFF does not vibrate when opening an app")
local schema = display.optionRow("ui_haptics")
T.eq(schema.default, false, "native mod option explicitly defaults OFF")
display.openHomeApp("settings")
display.settings.category = 5
local row = display.settingsModel().rows[2]
T.eq(row.key, "ui_haptics", "touch Controls exposes the same setting")
T.check(display.cycleSetting(row, 1), "touch enables the option")
T.eq(api.options:get("ui_haptics"), true, "touch option takes effect immediately")
T.eq(pulses[1], 0.012, "enabling previews one short pulse")
T.eq(game.save.options.haptics, "off", "Recomp touchpad preference is untouched")
T.eq(display.haptic(), false, "duplicate pulse is rate limited")
T.eq(#pulses, 1, "rate limiter never queues a delayed pulse")
now = now + 1
homePage()
x, y = coords("map_app")
event("down", x, y)
T.eq(#pulses, 1, "pointer down alone is silent")
event("cancel", x, y)
T.eq(#pulses, 1, "cancelled touch is silent")
event("down", x, y)
event("up", x, y)
T.eq(#pulses, 2, "accepted app opening pulses once on release")
T.eq(upvalue(display.openHomeApp, "page"), "MAP", "normal app action still works")
now = now + 1
homePage()
x, y = coords("map_app")
event("down", x, y)
event("up", x + 35, y)
T.eq(#pulses, 2, "horizontal swipe is silent")
homePage()
event("down", x, y)
now = now + 1
display.updateHomeLongPress(now)
T.eq(home.editing, true, "long hold still enters edit mode")
event("up", x, y)
T.eq(#pulses, 2, "hold and swallowed release are silent")
homePage()
game.stack.states[2] = { screenId = "BlockedMenu" }
event("tap", x, y)
T.eq(#pulses, 2, "dimmed locked screen does not vibrate")
game.stack.states[2] = { isTextBox = true }
event("tap", x, y)
T.eq(#pulses, 2, "dialogue tap cannot buzz the app underneath")
game.stack.states[2] = nil
homePage()
home.editing = true
display.tapHome(coords("map_app"))
T.eq(#pulses, 2, "selecting a swap source is silent")
display.tapHome(coords("store_app"))
T.eq(#pulses, 3, "successful Home swap confirms once")
now = now + 1
homePage()
home.editing = true
display.tapHome(coords("map_app"))
local swap = display.Home.swap
display.Home.swap = function() return false end
display.tapHome(coords("store_app"))
display.Home.swap = swap
T.eq(#pulses, 3, "rejected swap does not confirm success")
home.swapSource = "map_app"
home.page = 2
local _, slots = display.homePageElements()
local sx, sy, sw, sh = theme.hgss:homeRect(slots[1])
display.tapHome(sx + sw / 2, sy + sh / 2)
T.eq(#pulses, 4, "drop onto empty space on another page confirms")
now = now + 1
home.swapSource, home.page = nil, 3
local empty = display.Home.plusSlots(home.layout, display.homeCatalog, 3)[1]
home.library, home.addSlot, home.libraryKind, home.libraryPage = true, empty, "app", 1
local library = display.Home.library(home.layout, display.homeCatalog, 3,
  empty.column, empty.row, "app")
local chosen
for index, item in ipairs(library) do
  if item.available and index <= 6 then chosen = index break end
end
assert(chosen, "available app fixture")
display.tapHome(20 + ((chosen - 1) % 2) * 111, 60 + math.floor((chosen - 1) / 2) * 48)
T.eq(#pulses, 5, "adding a Home card confirms its placement")
now = now + 1
api.options:set("ui_haptics", false)
T.eq(#pulses, 5, "turning feedback off is silent")
T.eq(display.haptic(), false, "disabled setting suppresses all callers")
run.loader.modOptions.kanto_gear = run.loader.modOptions.kanto_gear or {}
run.loader.modOptions.kanto_gear.ui_haptics = true
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "ui_haptics", value = true })
T.eq(api.options:get("ui_haptics"), true, "native menu synchronizes the touch setting")
T.eq(#pulses, 6, "native menu enable also previews feedback")
now = now + 1
love.system.vibrate = function() error("unsupported backend") end
T.eq(display.haptic(), false, "backend error cannot break the UI")
now = now + 1
love.system = nil
T.eq(display.haptic(), false, "missing host vibrator is safe")
love.system = oldSystem or {}
love.system.vibrate = function(seconds) pulses[#pulses + 1] = seconds end
now = now + 1
local style = theme.style
theme.style = "og"
T.eq(display.haptic(), false, "legacy themes remain silent")
theme.style = style

local taken = false
api.world = api.world or {}
api.world.getFlag = function() return taken end
run.data.field = { hiddenItems = { ROUTE_1 = {
  { x = 11, y = 10, item = "POTION" }, { x = 12, y = 10, item = "POTION" },
} } }
run.data.gen2Maps = { ROUTE_1 = { bgEvents = {
  { x = 11, y = 10, hiddenItem = { item = 1, event = 100 } },
  { x = 12, y = 10, hiddenItem = { item = 1, event = 101 } },
} } }
local function scan(expected, label)
  now = now + 2
  local before = #pulses
  display.explorer.scanFrame, display.explorer.scanStarted = 0, now
  display.advanceExplorerScan(now + 0.3)
  T.eq(#pulses, before, label .. ": no pulse during sweep")
  now = now + 1
  display.advanceExplorerScan(now)
  T.eq(#pulses - before, expected, label)
  now = now + 1
  display.advanceExplorerScan(now)
  T.eq(#pulses - before, expected, label .. ": no repeated completion")
end
display.openHomeApp("explorer")
display.explorer.scanMapId = "ROUTE_1"
api.options:set("info_level", "enhanced")
scan(1, "two nearby hidden items produce only one confirmation")
T.eq(pulses[#pulses], 0.025, "scanner success is distinct but still short")
local beforePause = #pulses
display.explorer.scanFrame, display.explorer.scanStarted = 0, now
now = now + 10
display.advanceExplorerScan(now)
T.eq(#pulses, beforePause, "resuming after a pause cannot deliver stale feedback")
world.player.cellX = 40
scan(0, "empty radius is silent")
world.player.cellX = 10
taken = true
game.save.hiddenTaken = { ROUTE_1_11_10 = true, ROUTE_1_12_10 = true }
scan(0, "collected hidden items do not trigger")
taken, game.save.hiddenTaken = false, {}
game.save.inventory.ITEMFINDER = 0
scan(0, "no Itemfinder means no success feedback")
game.save.inventory.ITEMFINDER = 1
api.options:set("info_level", "purist")
scan(0, "Vanilla does not reveal signals through vibration")
api.options:set("info_level", "spoiler")
scan(0, "Spoiler has no active scanner feedback")
api.options:set("info_level", "enhanced")
game.stack.states[2] = { isTextBox = true }
scan(0, "dialogue suppresses pending scan feedback")
game.stack.states[2] = nil
display.overlayHidden = true
scan(0, "hidden overlay suppresses pending scan feedback")
display.overlayHidden = false
display.openHomeApp("settings")
scan(0, "leaving Explorer suppresses pending scan feedback")
display.openHomeApp("explorer")
display.explorer.scanMapId = "OTHER_MAP"
scan(0, "map change suppresses old scan feedback")
display.explorer.scanMapId = "ROUTE_1"
api.options:set("ui_haptics", false)
scan(0, "disabled mod setting also silences successful scans")
love.timer.getTime, love.system = oldTime, oldSystem
if oldSystem then oldSystem.vibrate = oldVibrate end
T.eq(#run.errors, 0, "no mod errors while testing feedback")
T.finish("Kanto Gear haptics Gen " .. generation)
