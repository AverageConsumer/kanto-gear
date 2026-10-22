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
  local theme = get(display.drawContents,"THEME")
  display.refreshDeviceSurfaces()
  T.eq(display.homeCatalog.surfaces.pokenav_contacts_widget.label,
    a.rs and "TRAINER'S EYES" or "MATCH CALL","contact widget uses the edition's native name")
  T.check(not display.openHomeApp("pokenav","unknown"),"unknown PokéNav targets are rejected")
  -- Both a feature screen and a projected submenu must be entered exactly
  -- once, after the original shell has finished its opening animation.
  for index,target in ipairs({ "map", "condition" }) do
    local id = "pokenav_"..target.."_widget"
    T.check(display.Home.place(display.home.layout,display.homeCatalog,id,6,(index-1)*4+1,1),
      "PokéNav shortcut can be placed on Home")
  end
  display.home.page, display.home.help = 6, false
  local shortcuts = display.homePageElements()
  for index,target in ipairs({ "map", "condition" }) do
    local x,y,w,h = theme.hgss:homeRect(shortcuts[index])
    display.tapHome(x+w/2,y+h/2)
    for _=1,300 do step() end
    local direct = assert(display.deviceApp)
    T.eq(direct.target,nil,"shortcut confirmation is consumed once")
    if target == "condition" then
      T.check(direct.view and #direct.view.items==3,"widget opens Condition directly")
      T.eq(direct.native.menu or direct.native.screen.menuType,a.rs and "condition" or 3,
        "shortcut does not confirm twice into a Condition subpage")
    else
      T.eq(direct.view,nil,"map widget opens the native map directly")
      T.check(a.rs and direct.native.menu=="map" or not a.rs and direct.native.screen,
        "original map screen exists")
    end
    T.eq(Stack.depth(),0,"widget navigation keeps the field unpaused")
    T.eq(reads,before,"widget never reads or queues physical input")
    display.closeDeviceApp()
  end
  local Rematch = require("src.core.game3.rse.rematch")
  if not a.rs then
    Rematch.setFlag(a.session,"FLAG_ADDED_MATCH_CALL_TO_POKENAV",false)
    display.refreshDeviceSurfaces()
    T.check(display.homeCatalog.surfaces.pokenav_contacts_widget.hidden,"locked Match Call is hidden")
    T.check(not display.openHomeApp("pokenav","contacts"),"shortcut cannot bypass Match Call unlock")
    Rematch.setFlag(a.session,"FLAG_ADDED_MATCH_CALL_TO_POKENAV",true)
    T.check(display.deviceTargetUnlocked("pokenav","contacts"),"native Match Call flag enables its shortcut")
  end
  Rematch.setFlag(a.session,"FLAG_SYS_RIBBON_GET",false)
  display.refreshDeviceSurfaces()
  T.check(display.homeCatalog.surfaces.pokenav_ribbons_widget.hidden,"locked ribbons are hidden")
  T.check(not display.openHomeApp("pokenav","ribbons"),"shortcut cannot bypass ribbon unlock")
  Rematch.setFlag(a.session,"FLAG_SYS_RIBBON_GET",true)
  T.check(display.deviceTargetUnlocked("pokenav","ribbons"),"native ribbon flag enables its shortcut")
  require("src.core.game3.rse.ribbons").set(a.session.party[1],"cool",1)
  for _,target in ipairs({"contacts","ribbons"}) do
    T.check(display.openHomeApp("pokenav",target),"unlocked native feature shortcut opens")
    for _=1,300 do step() end
    local direct=assert(display.deviceApp)
    if a.rs and target=="contacts" and direct.native.helpOverride==7 then
      T.eq(direct.native.cursor,2,"empty Trainer's Eyes uses its original native refusal")
    else
      T.eq(direct.view,nil,"feature shortcut leaves the main menu")
    end
    T.eq(Stack.depth(),0,"contacts and ribbons shortcuts leave the world in control")
    T.eq(reads,before,"feature shortcuts never consume physical input")
    display.closeDeviceApp()
  end
  local native = Nav.show({session=game.session,game=game})
  T.eq(Stack.top().mod,Nav.Host,"native-menu opening still owns normal hardware input")
  Nav.reset(); Stack.clear(); a.syncScreens()
  game.input = nativeInput
end
dofile(path .. "/tests/gen3_fixture.lua")
