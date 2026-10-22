package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local get = assert(loadfile(root .. "/tests/support/runtime.lua"))().get
local run = T.sdk.loadMod(root, { generation = 2, data = T.fixtures.load() })
T.eq(run.mod and run.mod.state, "loaded", "complete mod loads")
local hooks = run.loader.hooks
local function hook(name, priority)
  for _, entry in ipairs(hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" and entry.priority == priority then return entry.callback end
  end
end
local display = get(hook("input.step", 1000), "displayRuntime")
local theme = get(display.drawContents, "THEME")
local session = display.session
local Stack = require("src.core.StateStack")
Stack:init()
local world = { map = { id = "NEW_BARK_TOWN", def = {} } }
local save = require("src.core.gen2.Save").newGame()
local game = { data = run.data, save = save, world = world, overworld = world, stack = Stack,
  input = { wasPressed = function() return false end } }
Stack:push(world)
run.loader.events:emit("game.ready", { game = game })
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", display_mode = "combined" }
run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
display.home.help = false
T.check(not display.storeById.pokegear.hidden, "Gen 2 Store offers the native device app")
T.check(display.setPackageInstalled("pokegear", true), "app can be installed")
T.check(not display.openHomeApp("pokegear"), "app cannot bypass Mom's unlock")
T.eq(display.storeEntry(display.storeById.pokegear).state, "soon", "locked open button is inactive")
save.pokegearReceived = true
save.pokegearFlags = { map = true, phone = true, radio = true }
T.check(display.Home.place(display.home.layout, display.homeCatalog, "pokegear_app", 5, 1, 1),
  "installed app can be placed on Home")
display.home.page = 5
local tiles = display.homePageElements()
T.eq(tiles[1].disabled, false, "received device has an actionable tile")
save.pokegearReceived = nil
tiles = display.homePageElements()
T.eq(tiles[1].disabled, true, "unreceived device tile stays inactive")
save.pokegearReceived = true
local previous = Stack:top()
T.check(display.openHomeApp("pokegear"), "app queues the device")
T.eq(Stack:top(), previous, "render/touch callback does not push native screens")
local nativeStep = display.stepDeviceApps
nativeStep(game, 1/60)
local app = assert(display.deviceApp)
local native = app.native
T.eq(Stack:top(), previous, "device app never takes the native game stack")
T.check(app.view and app.view.pokegearModel, "existing touch UI mirrors the detached device")
T.eq(#app.view.pokegearModel.cards, 4, "owned native cards remain available")
local reads, moves = 0, 0
game.input.wasPressed = function(_, key) reads=reads+1; return key=="right" end
nativeStep(game,1/60)
T.eq(reads,0,"device update never reads physical game input")
local card = native.cardIndex
hook("input.step",1000)(function()
  if game.input:wasPressed("right") then moves=moves+1 end
end,game,1/60)
T.eq(moves,1,"D-pad still reaches the native world through the full hook")
T.eq(native.cardIndex,card,"physical D-pad does not navigate the device")
local rect = display.PokegearPage.tiles(#app.view.pokegearModel.cards)[1]
display.tapDeviceApp(rect[1]+5,rect[2]+5)
nativeStep(game,1/60)
T.eq(native.mode,"card","bottom touch opens the actual clock card")
T.eq(Stack:top(),world,"touch leaves the world on top")
local before=reads
display.tapDeviceApp(10,10);nativeStep(game,1/60)
T.eq(native.mode,"strip","touch back returns to the device card strip")
T.eq(reads,before,"touch back never sends B to the game")
display.tapDeviceApp(10,10);nativeStep(game,1/60)
T.eq(display.deviceApp,nil,"second touch back closes the app")
T.eq(session.page,"HOME","closing returns the companion to Home")
T.eq(Stack:top(),world,"closing never pops the game's world")
-- Installed-device widgets are independent Home surfaces and open a card,
-- rather than the device strip. They never take physical game input.
for index, target in ipairs({ "clock", "map", "phone", "radio" }) do
  local id = "pokegear_" .. target .. "_widget"
  T.check(display.Home.place(display.home.layout, display.homeCatalog, id, 6,
    (index-1)%3*4+1, math.floor((index-1)/3)+1),
    "device shortcut can be placed alongside the app")
end
display.home.page = 6
local shortcuts = display.homePageElements()
T.eq(#shortcuts,4,"all four owned Pokégear card shortcuts are available")
for index, target in ipairs({ "clock", "map", "phone", "radio" }) do
  local tile = shortcuts[index]
  local x,y,w,h = theme.hgss:homeRect(tile)
  display.tapHome(x+w/2,y+h/2)
  nativeStep(game,1/60)
  local device = assert(display.deviceApp).native
  T.eq(device:card().id,target,"widget opens its own native card")
  T.eq(device.mode,"card","widget skips the device strip")
  T.eq(Stack:top(),world,"card shortcut keeps the overworld in control")
  local before = reads
  nativeStep(game,1/60)
  T.eq(reads,before,"shortcut update never reads physical input")
  display.closeDeviceApp()
end
save.pokegearFlags.map = nil
display.refreshDeviceSurfaces()
T.eq(display.homeCatalog.surfaces.pokegear_map_widget.hidden,true,"unowned card is hidden from widget library")
T.check(display.homePageElements()[2].disabled,"a previously placed unowned card is inactive")
T.check(not display.openHomeApp("pokegear","map"),"direct launch cannot bypass a card unlock")
T.check(not display.openHomeApp("pokegear","unknown"),"unknown card targets are rejected")
save.pokegearFlags.map = true
local Pokegear = require("src.ui.gen2.Pokegear")
local menuDevice = Pokegear.new(game)
Stack:push(menuDevice)
T.check(display.startMenu().pokegearModel,"native opening still mirrors both screens")
T.eq(menuDevice.game,game,"native opening retains actual hardware input")
Stack:pop()
-- A queued app must not open over a newly appeared native modal.
T.check(display.openHomeApp("pokegear"),"second opening queues")
local modal={};Stack:push(modal)
nativeStep(game,1/60)
T.eq(Stack:top(),modal,"changed native context cancels the opening")
T.eq(display.deviceApp,nil,"cancelled opening creates no hidden device")
Stack:pop()
-- Other generations never advertise or launch the app, even with stored enablement.
save.generation = 1
display.applyDeviceSupport()
T.eq(display.storeById.pokegear.hidden, true, "Gen 1 hides the Store entry")
T.eq(display.homeCatalog.surfaces.pokegear_app.hidden, true, "Gen 1 hides the Home library entry")
T.check(not display.openHomeApp("pokegear"), "unsupported game cannot launch a stored app")
T.finish("native Pokégear app routing")
