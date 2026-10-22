local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local get = assert(loadfile(path .. "/tests/support/runtime.lua"))().get
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local Stack = require("src.ui.game3.stack")
  Stack.clear()
  require("src.ui.game3.message").reset()
  require("src.ui.game3.choice").reset()
  local inputHook
  for _, entry in ipairs(run.loader.hooks.chains["input.step"]) do
    if entry.owner == "kanto_gear" then inputHook = entry.callback end
  end
  local a = display.gen3
  a.Battle._active, a.Battle._st = false, nil
  a:refresh(); a.syncScreens()
  display.session.battle = nil
  local expected = a.hoenn == true
  T.eq(not display.storeById.pokenav.hidden, expected, "only Hoenn offers the PokéNav app")
  T.eq(display.storeById.pokegear.hidden, true, "Gen 3 never offers Pokégear")
  if not expected then
    T.check(not display.openHomeApp("pokenav"), "FRLG cannot open a stored PokéNav app")
    return
  end
  -- The SDK fixture's filesystem belongs to the mod. Resolve native PokéNav
  -- manifests from the explicitly configured, actual imported game cache.
  local Kit = require("src.ui.game3.rse.scene_kit")
  local loadNative = Kit.loadLua
  Kit.loadLua = function(name)
    local relative = name:match("^data/generated/gba/(.*)$")
    local chunk = loadfile(name) or relative and loadfile(assert(os.getenv("POKEPORT_GBA_CACHE")) .. "/" .. relative)
    if chunk then return chunk() end
    return loadNative(name)
  end
  Kit.resetCaches()
  local Nav = require("src.ui.game3.screens").get("pokenav", game.session)
  Nav.reset(); Stack.clear(); a.syncScreens()
  local flag = assert(a.flagDefinitions.IDS.FLAG_SYS_POKENAV_GET)
  a.Flags.setFlag(a:flagStore(), nil, flag, false)
  T.check(display.setPackageInstalled("pokenav", true), "PokéNav can be installed")
  T.check(not display.openHomeApp("pokenav"), "app respects the native device unlock")
  a.Flags.setFlag(a:flagStore(), nil, flag, true)
  T.check(display.openHomeApp("pokenav"), "unlocked PokéNav queues")
  display.stepDeviceApps(game, 1/60)
  local app = assert(display.deviceApp, "detached PokéNav opened")
  T.eq(app.native, Nav.active(), "app uses the actual host PokéNav shell")
  T.eq(Stack.depth(), 0, "app never occupies the native input/modal stack")
  local reads, moves = 0, 0
  local nativeInput = game.input
  game.input = { wasPressed = function(_, key) reads=reads+1; return key=="right" end }
  local function step() display.stepDeviceApps(game, 1/60) end
  for _ = 1, 300 do step() end
  T.eq(reads, 0, "device frames never read physical game input")
  T.check(app.view and app.view.pokenav, "detached device exposes existing touch menus")
  local view = app.view
  local index = view.index
  inputHook(function()
    if game.input:wasPressed("right") then moves=moves+1 end
  end, game, 1/60)
  T.eq(moves, 1, "physical D-pad reaches the native field through the complete hook")
  T.eq(app.view.index, index, "physical D-pad cannot navigate the bottom device")
  T.eq(Stack.depth(), 0, "physical movement does not create a native device menu")
  local function touchRow(index)
    local r = app.view.items[index].rect
    display.tapDeviceApp(r[1]+5,r[2]+5)
    for _=1,180 do step() end
  end
  touchRow(2)
  T.check(app.view and #app.view.items==3, "touch opens the real Condition submenu")
  touchRow(1)
  T.eq(app.view,nil,"native graph renders below when no touch projection exists")
  local before=reads
  display.tapDeviceApp(10,10)
  for _=1,180 do step() end
  T.eq(reads,before,"native feature touch buttons never leak to game input")
  T.eq(Stack.depth(),0,"feature navigation keeps the overworld unpaused")
  T.check(app.view and app.view.pokenav,"touch B returns from the graph to Condition")
  display.drawDeviceApp()
  display.closeDeviceApp()
  T.eq(Nav.active(),nil,"closing releases the detached native shell")
  T.eq(Stack.depth(),0,"closing never pops a game screen")
  T.eq(display.session.page,"HOME","closing returns Gear to Home")
  local native = Nav.show({session=game.session,game=game})
  T.eq(Stack.top().mod,Nav.Host,"native-menu opening still owns normal hardware input")
  Nav.reset(); Stack.clear(); a.syncScreens()
  game.input = nativeInput
end
dofile(path .. "/tests/gen3_fixture.lua")
