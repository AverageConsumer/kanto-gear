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
local nativeStep = display.stepPokegear
nativeStep(game)
local native = Stack:top()
T.eq(native.screenId, "Gen2Pokegear", "input step opens the actual host screen")
T.eq(display.appPokegear, native, "only this instance belongs to the app")
local view = display.startMenu()
T.check(view and view.pokegearModel, "existing touch UI mirrors the actual device")
T.eq(#view.pokegearModel.cards, 4, "only the owned native cards are projected")
local visible = hook("screen.render_visible", 1100)
local function shown(state) return visible(function() return true end, state) end
session.companion = { detected = function() return true end }
session.displayReady = true
T.eq(shown(native), false, "app opening hides the native device on top")
session.displayReady = false
T.eq(shown(native), true, "failed companion presentation restores the native device")
session.displayReady = true
Stack:push({ isTextBox = true })
T.eq(shown(native), true, "native phone dialogue retains its native backdrop")
Stack:pop()
T.eq(visible(function() return false end, world), false, "other mods can still hide their screen")
local called
game.runPokegearCall = function(_, call) called = call; return true end
local call = { kind = "call" }
T.check(native.onCall(call) and called == call, "phone calls use the host's actual script handler")
native.onClose()
T.eq(Stack:top(), world, "closing returns to the unchanged native world")
T.eq(session.page, "HOME", "closing returns the companion to Home")
T.eq(display.home.activeApp, nil, "closing clears the active app")
local Pokegear = require("src.ui.gen2.Pokegear")
local menuDevice = Pokegear.new(game)
Stack:push(menuDevice)
T.check(display.startMenu().pokegearModel, "native menu still has the bottom mirror")
T.eq(shown(menuDevice), true, "native-menu opening keeps Pokégear on the top screen")
Stack:pop()
-- A queued handoff must not open over a newly appeared native modal.
T.check(display.openHomeApp("pokegear"), "second handoff queues")
local modal = {}; Stack:push(modal)
nativeStep(game)
T.eq(Stack:top(), modal, "changed native context cancels the handoff")
Stack:pop()
-- Other generations never advertise or launch the app, even with stored enablement.
save.generation = 1
display.applyPokegearSupport()
T.eq(display.storeById.pokegear.hidden, true, "Gen 1 hides the Store entry")
T.eq(display.homeCatalog.surfaces.pokegear_app.hidden, true, "Gen 1 hides the Home library entry")
T.check(not display.openHomeApp("pokegear"), "unsupported game cannot launch a stored app")
T.finish("native Pokégear app routing")
