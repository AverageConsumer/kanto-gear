package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
-- This suite exercises the native setter contract. Older SDK fixtures omit
-- it; the cache-only host path is covered by settings_fallback_test.lua.
local Loader = require("src.mods.Loader")
local nativeApi = Loader._api
Loader._api = function(self, loadedMod)
  local api = nativeApi(self, loadedMod)
  api.options.set = api.options.set or function(_, key, value)
    self.modOptions[api.id] = self.modOptions[api.id] or {}
    self.modOptions[api.id][key] = value
    self.events:emit("mod.options_changed",
      { mod = api.id, key = key, value = value })
    return true
  end
  return api
end
local run = T.sdk.loadMod(path, {
  generation = 2,
  data = T.fixtures.load(),
})
Loader._api = nativeApi

T.eq(run.mod and run.mod.state, "loaded", "Kanto Gear loads")
T.eq(#run.errors, 0, "Kanto Gear boots without errors")

local optionRows = run.loader.optionSchemas.kanto_gear
local optionByKey = {}
for _, row in ipairs(optionRows or {}) do optionByKey[row.key] = row end
T.eq(optionByKey.theme_v3 and optionByKey.theme_v3.default, "hgss",
  "a fresh 3.0 install starts in the Silph Link HGSS theme")
T.eq(optionByKey.theme_v3 and optionByKey.theme_v3.choices[5][2], "hgss_auto",
  "HGSS Auto is the third Silph Link theme choice")
T.eq(optionByKey.ui_motion and optionByKey.ui_motion.default, true,
  "Silph Link motion is an explicit opt-out setting")
T.eq(optionByKey.info_level and optionByKey.info_level.reset_default, "enhanced",
  "research resets to the canonical 3.0 default")
T.eq(optionByKey.battle_view.default, "standard",
  "the optional battle modes preserve Companion as the default")
T.eq(#optionByKey.battle_view.choices, 4,
  "all four battle views remain available alongside the v4 themes")
T.check(optionByKey.ui_motion.visible_if == nil
    and optionByKey.local_map.visible_if == nil,
  "native menus keep options reachable without unsupported list conditions")
run.loader.modOptions.kanto_gear = { theme = "kanto", display_mode = "separate" }

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

local upvalue = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get

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
local theme = upvalue(display.drawContents, "THEME")
local gearOptions = {}
for _, row in ipairs(theme.optionSchema) do gearOptions[row.key] = row end
T.check(gearOptions.ui_motion.visible_if.one_of
    and gearOptions.local_map.visible_if.not_one_of,
  "Gear keeps contextual filtering for transitions and the legacy area map")
do
  local pixels = upvalue(theme.hgss.silphEmblem, "emblemPixels")
  for _, hexShape in ipairs({ false, true }) do
    for _, size in ipairs({ 32, 64, 65 }) do
      local data, left, right = pixels(size, 4, hexShape), math.huge, -math.huge
      local swept, settled = {}, {}
      for segment = 1, 3 do
        for _, point in ipairs(data.px[segment]) do
          left, right = math.min(left, point[1]), math.max(right, point[1])
          -- LuaJIT can retain -0 at the first column; integer pixel keys must normalize it.
          swept[string.format("%d:%d", point[1], point[2])] = point[3]
        end
        for _, run in ipairs(data.runs[segment]) do
          for x = run[2], run[2] + run[4] - 1 do settled[string.format("%d:%d", x, run[3])] = run[1] end
        end
      end
      T.eq(left + right, size - 1, "both emblem tips have symmetric pixel bounds")
      T.check(not hexShape or left < 0 and right >= size,
        "hexagonal emblem includes the tips outside its height-sized square")
      T.eq(next(swept) ~= nil, true, "the emblem has visible pixels")
      local same = true
      for key, kind in pairs(swept) do if settled[key] ~= kind then same = false end end
      for key, kind in pairs(settled) do if swept[key] ~= kind then same = false end end
      T.check(same, "cached runs exactly match the animated emblem pixels")
      T.eq(pixels(size, 4, hexShape), data, "settled emblems reuse the geometry cache")
    end
  end
end
T.eq(display.storeEntries()[1].id, "pss", "PSS is visible on the first Apps page")
T.eq(display.storeTodayEntries()[1].id, "pss", "PSS is featured when the Store opens")
T.eq(display.storeWidgetSummary().label, "SHINY HUNT", "Store widget promotes the new Shiny Hunt until it is installed")
T.check(display.setPackageInstalled("shiny", true), "Shiny Hunt installs")
T.eq(display.storeWidgetSummary().label, "APPS", "Store widget shows the catalogue when no app is new")
T.check(display.setPackageInstalled("shiny", false), "Shiny Hunt uninstalls")
do
  local renderer = theme.hgss
  local originalText, originalBar = renderer.partyInfo, renderer.expBar
  for _, code in ipairs({ "de", "es", "fr", "it" }) do
    local labels = assert(loadfile(path .. "/i18n/catalogs/" .. code .. ".lua"))()
    local nextLabel, value = labels.NEXT, "999999"
    local positions, bar = {}, {}
    renderer.partyInfo = function(_, text, x) positions[text] = x end
    renderer.expBar = function(_, x, _, width) bar.x, bar.width = x, width end
    renderer:summaryExperience({ expLabel = "EXP", expProgress = 0.5,
      nextLabel = nextLabel, nextValue = value })
    T.check(positions[nextLabel] ~= nil and positions[value] ~= nil,
      code .. " summary preserves both translated label and full EXP value")
    T.eq(positions[value] - positions[nextLabel]
      - renderer:partyInfoWidth(nextLabel), 4,
      code .. " summary label and value retain four pixels of separation")
    T.eq(positions[nextLabel] - bar.x - bar.width, 5,
      code .. " EXP bar stays separate from the translated next-value group")
  end
  renderer.partyInfo, renderer.expBar = originalText, originalBar
end
T.eq(theme.storedTheme, "hgss",
  "3.0 ignores the old theme key and starts existing users in HGSS")
run.loader.modOptions.kanto_gear.theme_v3 = "kanto"
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "theme_v3", value = "kanto" })
run.loader.events:emit("game.ready", { game = game })
T.eq(theme.storedTheme, "kanto",
  "a Legacy choice made in 3.0 survives the next start")
world.hour, world.minute, world.tod = function() return 21 end,
  function() return 5 end, "NITE"
run.loader.modOptions.kanto_gear.theme_v3 = "hgss_auto"
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "theme_v3", value = "hgss_auto" })
T.eq(theme.hgss.dark, true,
  "HGSS Auto follows the Gen 2 night period")
world.hour, world.tod = function() return 12 end, "DAY"
local refreshTheme = upvalue(composeHook, "refreshTheme")
T.check(type(refreshTheme) == "function", "automatic theme refresh is reachable")
refreshTheme()
T.eq(theme.hgss.dark, false,
  "HGSS Auto returns to Light when the Gen 2 day period begins")
run.loader.modOptions.kanto_gear.theme_v3 = "hgss"
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "theme_v3", value = "hgss" })
world.hour, world.minute, world.tod = nil, nil, nil
local function homeTile(id)
  local tiles = display.homePageElements()
  for _, tile in ipairs(tiles) do
    if tile.id == id then return tile end
  end
end
local function tapHomeTile(id, routed)
  local tile = assert(homeTile(id), "missing Home tile " .. id)
  local x, y, w, h = theme.hgss:homeRect(tile)
  x, y = x + math.floor(w / 2), y + math.floor(h / 2)
  if routed then
    tap(math.floor(x / theme.hgssScale), math.floor(y / theme.hgssScale))
  else
    display.tapHome(x, y)
  end
end
local function tapStoreAppAction(id)
  local entries, absolute = display.storeEntries()
  for index, entry in ipairs(entries) do
    if entry.id == id then absolute = index break end
  end
  assert(type(absolute) == "number", "missing Store app " .. id)
  local size = display.storePageSizes.apps
  home.storeView, home.storeConfirm = "apps", nil
  home.storePages.apps = math.ceil(absolute / size)
  local visible = (absolute - 1) % size
  -- touch the app's row, its key on the picked pak, then YES
  display.tapStore(60, 62 + visible * 25 + 8)
  display.tapStore(198, 140)
  display.tapStore(60, 188)
  home.storeReceived = nil
end
local appWidgets = {
  pokedex = { id = "pokedex_widget", columns = 5 },
  trainer = { id = "trainer_widget", columns = 5 },
  bag = { id = "bag_widget", columns = 5 },
  map = { id = "map_widget", columns = 7 },
  store = { id = "store_widget", columns = 5 },
}
for packageId, expected in pairs(appWidgets) do
  local surface = catalog.surfaces[expected.id]
  T.check(surface and surface.package == packageId
      and surface.kind == "widget" and surface.widget == packageId,
    packageId .. " exposes an app-owned Home widget")
  T.eq(surface and surface.columns, expected.columns,
    packageId .. " widget keeps its grid contract")
  T.check(catalog.surfaces[packageId .. "_app"] ~= nil,
    packageId .. " can coexist as an app icon and widget")
end
local installedBefore = {}
for packageId in pairs(appWidgets) do
  installedBefore[packageId] = catalog.packages[packageId].installed
  catalog.packages[packageId].installed = true
end
local widgetLibrary = display.Home.library({ tiles = {} }, catalog,
  1, 1, 1, "widget")
local offered = {}
for _, item in ipairs(widgetLibrary) do offered[item.id] = item.available end
for _, expected in pairs(appWidgets) do
  T.check(offered[expected.id], expected.id .. " appears in Add to Home")
end
for packageId, installed in pairs(installedBefore) do
  catalog.packages[packageId].installed = installed
end
local removalAudit = { tiles = {
  { id = "bag_app", page = 1, column = 1, row = 1 },
  { id = "bag_widget", page = 1, column = 4, row = 2 },
} }
T.eq(display.Home.removePackage(removalAudit, catalog, "bag"), 2,
  "removing an app removes both its icon and widgets")
T.eq(#removalAudit.tiles, 0,
  "no orphaned app surface remains after package removal")
local api = upvalue(display.saveHome, "mod")
do
  local options = run.loader.modOptions.kanto_gear
  local oldLevel, oldInventory = options.info_level, game.save.inventory
  local function radar()
    for _, row in ipairs(display.toolModels()) do if row.radar then return row end end
  end
  options.info_level, game.save.inventory = "enhanced", { ITEMFINDER = 1 }
  T.check(radar() and radar().ready, "owned Itemfinder exposes the radar in Field Kit")
  game.save.inventory = {}
  T.eq(radar(), nil, "missing Itemfinder cannot expose a radar action")
  game.save.inventory, options.info_level = { ITEMFINDER = 1 }, "spoiler"
  T.eq(radar(), nil, "spoiler mode does not offer the redundant radar")
  options.info_level, game.save.inventory = oldLevel, oldInventory
end
local durableHome
local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, entry in pairs(value) do result[copy(key)] = copy(entry) end
  return result
end
api.storage = {
  write = function(_, _, key, value)
    if key == "home/state" then durableHome = copy(value) end
    return true
  end,
  read = function(_, _, key)
    if key == "home/state" and durableHome then return copy(durableHome) end
    return nil, "not_found"
  end,
}
do
  api.device = api.device or { powerInfo = function() return "battery", 80 end }
  -- Complete the headless drawing stubs for existing Home portraits and icons.
  love.graphics.arc = love.graphics.arc or function() end
  love.graphics.polygon = love.graphics.polygon or function() end
  T.check(home.help and display.homeHelpActive(),
    "a fresh install introduces Home customization")
  durableHome = display.homeSnapshot()
  durableHome.helpSeen = nil
  display.loadHome()
  T.check(display.homeHelpActive(),
    "existing layouts without the acknowledgement also receive the hint")
  local initialTiles = #home.layout.tiles
  local scale = theme.hgssScale
  local _, panelY = theme.hgss:homeHelpLayout(display.homePageElements())
  local acceptX, acceptY = math.floor(120 / scale), math.floor((panelY + 70) / scale)
  local acceptDown = ("down,%d,%d"):format(acceptX, acceptY)
  local acceptUp = ("up,%d,%d"):format(acceptX, acceptY)
  touchEvent("down,20,35")
  T.check(not display.updateHomeLongPress(love.timer.getTime() + 2)
      and not home.editing, "the hint blocks long presses on the highlighted widget")
  T.check(pcall(display.drawContents), "the first-run hint renders in the real Home")
  local pressCalls, originalBeginPress = 0, theme.hgss.beginPress
  theme.hgss.beginPress = function(self, left, top, width, height, ...)
    local pressed = originalBeginPress(self, left, top, width, height, ...)
    if pressed and top < panelY then pressCalls = pressCalls + 1 end
    return pressed
  end
  display.drawContents()
  theme.hgss.beginPress = originalBeginPress
  T.eq(pressCalls, 0, "background widgets cannot animate beneath the hint")
  touchEvent("up,20,35")
  T.check(home.help and page() == "HOME", "tapping the spotlight cannot open an app")
  touchEvent("down,140,100")
  touchEvent("up,20,100")
  T.check(home.help and home.page == 1, "a swipe cannot dismiss or page behind the hint")
  touchEvent(acceptDown)
  touchEvent("cancel,0,0")
  T.check(home.help and not home.helpSeen, "a cancelled confirmation is not remembered")
  world.isTextBox = true
  T.check(not display.homeHelpActive(), "game dialogue takes priority over Home help")
  world.isTextBox = nil
  theme.style = "classic"
  T.check(not display.homeHelpActive(), "Legacy themes never show the Home hint")
  theme.style = "hgss"
  touchEvent(acceptDown)
  touchEvent(acceptUp)
  T.check(not home.help and home.helpSeen,
    "only confirming Got it dismisses the automatic hint")
  T.check(durableHome.helpSeen, "confirmation is written without an in-game save")
  T.eq(#home.layout.tiles, initialTiles, "confirmation preserves the Home layout")
  api.save:set("home_help_seen", false)
  home.help, home.helpSeen = nil, nil
  display.loadHome()
  T.check(not home.help, "durable acknowledgement survives a stale game-save reload")
  display.openHomeApp("settings")
  -- System is the last settings tab.
  display.settings.category = #display.settingsCategories
  T.eq(display.settingsModel().rows[1].action, "home_help",
    "System settings exposes the explanation above the reset actions")
  display.tapSettings(30, 80)
  T.eq(display.settingsModel().selected, "home_help",
    "Home help is selected and explained before the explicit action")
  T.check(page() == "SETTINGS" and not home.help, "selecting the row alone performs no action")
  display.tapSettings(170, 80)
  T.check(page() == "HOME" and home.help and not home.editing,
    "Show me reopens the hint with one tap without resetting Home")
  T.eq(#home.layout.tiles, initialTiles, "replaying help preserves every Home tile")
  local _, top = theme.hgss:homeHelpLayout(display.homePageElements())
  display.tapHome(120, top + 70)
  for _, tiles in ipairs({ {}, { { kind = "app", row = 1 } },
      { { kind = "widget", row = 2 } } }) do
    local target, helpTop = theme.hgss:homeHelpLayout(tiles)
    T.check(theme.hgss:homeHelpHit(120, helpTop + 70, tiles)
        and not theme.hgss:homeHelpHit(20, helpTop + 70, tiles),
      "empty and rearranged layouts share the visible confirmation hitbox")
    if target then
      local _, tileY, _, tileH = theme.hgss:homeRect(target)
      T.check(helpTop + 84 <= tileY or helpTop >= tileY + tileH,
        "help stays in the opposite row without covering the spotlight")
    end
  end
end
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
T.check(display.setPackageInstalled("notes", true),
  "Notes can be enabled through the existing Store")
T.eq(display.storeEntry(store.notes).state, "open",
  "installed Notes replaces its SOON placeholder")
T.check(display.setPackageInstalled("tools", true),
  "removed bundled apps can be enabled again")
T.eq(display.storeEntry(store.tools).state, "open",
  "enabled bundled apps return to OPEN")

home.storeView, home.storeDetail = "apps", nil
display.tapStore(34, 13)
T.eq(home.storeView, "today",
  "the Store header's left arrow matches a right swipe")
display.tapStore(130, 13)
T.eq(home.storeView, "apps",
  "the Store header's right arrow matches a left swipe")
display.setPackageInstalled("tools", false)
tapStoreAppAction("tools")
T.eq(display.storeEntry(store.tools).state, "open",
  "the visible GET button enables its matching app")
home.storeView, home.storeGearSel = "library", "tools"
display.tapStore(196, 190)
display.tapStore(60, 188)
T.eq(display.storeEntry(store.tools).state, "get",
  "the detail REMOVE button disables its matching app")
display.setPackageInstalled("tools", true)
T.check(display.Home.place(home.layout, catalog, "tools_app", 2, 1, 1),
  "an enabled app can be added to a later Home page")
display.saveHome()
api.save:set("home_packages", { tools = false })
api.save:set("home_layout", { tiles = {} })
catalog.packages.tools.installed, home.layout = false, { tiles = {} }
display.loadHome()
local savedTools = display.Home.find(home.layout, "tools_app")
T.check(catalog.packages.tools.installed,
  "enabled app state survives a save reload")
T.check(savedTools and savedTools.page == 2,
  "Home placement survives a process-style durable reload")
T.eq(savedTools and savedTools.column, 1,
  "durable Home state is a serialized snapshot, not a live table alias")
local legacyState = copy(durableHome)
durableHome = nil
api.save:set("home_packages", copy(legacyState.packages))
api.save:set("home_layout", copy(legacyState.layout))
home.layout = { tiles = {} }
display.loadHome()
T.check(durableHome and durableHome.format == 1,
  "a pre-durable Home save migrates to restart-safe storage")
T.check(display.Home.find(home.layout, "party_app") ~= nil
    and display.Home.find(home.layout, "tools_app") ~= nil,
  "Home migration preserves existing app placement")

tapHomeTile("party_app", true)
T.eq(page(), "PARTY", "tapping a Home icon opens its installed app")
tap(80, 80)
T.eq(page(), "PARTY", "touching app content does not close the app")
T.eq(home.activeApp, "party", "app ownership survives content touches")
tap(5, 5)
T.eq(page(), "HOME", "the app header back button returns Home")
T.eq(home.activeApp, nil, "returning Home clears app ownership")

T.check(display.openHomeApp("map"), "Map opens from Home")
T.eq(page(), "MAP", "Map app reuses the existing region map")
tap(5, 5)
T.eq(page(), "HOME", "Map header back returns Home")

T.check(display.openHomeApp("explorer"), "Explorer opens from Home")
display.explorer.view = "wild"
tap(5, 5)
T.eq(page(), "LOCAL", "Explorer back closes its internal view first")
T.eq(display.explorer.view, nil, "Explorer internal view closes")
T.eq(home.activeApp, "explorer", "Explorer remains open after internal back")
tap(5, 5)
T.eq(page(), "HOME", "Explorer root back returns Home")

T.eq(display.storeEntry(store.pokedex).state, "get",
  "the new Pokedex waits for an explicit Store install")
T.check(display.setPackageInstalled("pokedex", true),
  "the finished Pokedex installs from Silph Store")
T.eq(display.storeEntry(store.pokedex).state, "open",
  "the installed Pokedex is available in Silph Store")
T.check(display.openHomeApp("pokedex"), "Pokedex opens from Home")
T.eq(page(), "POKEDEX", "Pokedex owns an independent bottom-screen app")
local dexModel = display.pokedexModel()
T.check(dexModel.view == "index" and #dexModel.entries > 0,
  "Pokedex index is populated from the live generation data")
display.tapPokedex(20, 50)
T.eq(display.pokedex.view, "profile",
  "tapping a species opens its encyclopedia profile")
local dx,dy,dw,dh=display.PokedexPage.cardRect(2)
display.tapPokedex((dx+dw/2)/1.5,(dy+dh/2)/1.5)
T.eq(display.pokedex.view, "habitat",
  "the profile habitat card opens real encounter research")
display.tapPokedex(5, 5)
T.eq(display.pokedex.view, "profile",
  "Pokedex detail back returns to the species profile")
dx,dy,dw,dh=display.PokedexPage.cardRect(1)
display.tapPokedex((dx+dw/2)/1.5,(dy+dh/2)/1.5)
T.eq(display.pokedex.view, "stats",
  "the profile stats card opens base-stat research")
api.device = api.device or {
  powerInfo = function() return "battery", 80 end,
}
T.check(pcall(display.drawContents),
  "the wired Pokedex renders its live runtime model")
display.tapPokedex(5, 5)
display.tapPokedex(5, 5)
display.tapPokedex(5, 5)
T.eq(page(), "HOME", "Pokedex back navigation returns Home")

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
T.check(toolsIndex ~= nil, "Tools is available in Add to Home")
home.libraryPage = math.ceil(toolsIndex / 6)
local visible = (toolsIndex - 1) % 6
display.tapHome(15 + visible % 2 * 111,
  54 + math.floor(visible / 2) * 48)
local centeredTools = display.Home.find(home.layout, "tools_app")
T.eq(centeredTools.column, 8,
  "Home storage keeps Explorer and Tools in stable row order")
local explorerTile, toolsTile = homeTile("explorer_widget"), homeTile("tools_app")
local explorerX, _, explorerW = theme.hgss:homeRect(explorerTile)
local toolsX, _, toolsW = theme.hgss:homeRect(toolsTile)
T.eq(explorerX - 7, toolsX - explorerX - explorerW,
  "Explorer and Tools keep equal left and inner visual gaps")
T.eq(toolsX - explorerX - explorerW, 233 - toolsX - toolsW,
  "Explorer and Tools keep equal inner and right visual gaps")

home.layout = { tiles = {
  { id = "tools_app", page = 1, column = 1, row = 1 },
  { id = "trainer_app", page = 2, column = 1, row = 1 },
} }
home.page, home.editing, home.library, home.swapSource = 1, true, false, nil
tapHomeTile("tools_app")
T.eq(home.swapSource, "tools_app", "tapping an app selects it for swapping")
touchEvent("down,140,100")
touchEvent("up,20,100")
T.eq(home.page, 2, "the selected app survives a swipe to the next Home page")
tapHomeTile("trainer_app")
T.eq(display.Home.find(home.layout, "tools_app").page, 2,
  "tapping an app on another page swaps it with the selection")
T.eq(display.Home.find(home.layout, "trainer_app").page, 1,
  "the cross-page swap returns the other app to the source position")
T.eq(home.swapSource, nil, "a completed swap clears the selection")
tapHomeTile("tools_app")
touchEvent("down,140,100")
touchEvent("up,20,100")
local _, emptySlots = display.homePageElements()
local empty = assert(emptySlots and emptySlots[1], "missing empty Home row")
local emptyX, emptyY, emptyW, emptyH = theme.hgss:homeRect(empty)
display.tapHome(emptyX + math.floor(emptyW / 2),
  emptyY + math.floor(emptyH / 2))
local movedTools = display.Home.find(home.layout, "tools_app")
T.eq(home.page, 3, "swiping reaches a new empty Home page")
T.eq(movedTools.page, 3, "an empty region accepts the selected app")
T.eq(movedTools.column, 1,
  "an app moved to an empty row keeps canonical storage coordinates")
home.editing = false
local movedTile = homeTile("tools_app")
local movedX, _, movedW = theme.hgss:homeRect(movedTile)
T.eq(movedX - 7, 233 - movedX - movedW,
  "an app moved to an empty row is visually centered")

home.layout = { tiles = {} }
home.page, home.editing, home.library, home.addSlot = 1, false, false, nil
T.check(pcall(display.drawContents),
  "an empty Home renders a recoverable Add to Home state")
local emptyHomeX, emptyHomeY, emptyHomeW, emptyHomeH =
  theme.hgss:homeEmptyRect()
display.tapHome(emptyHomeX + math.floor(emptyHomeW / 2),
  emptyHomeY + math.floor(emptyHomeH / 2))
T.check(home.editing and home.library and home.addSlot ~= nil,
  "tapping the empty Home opens the existing app and widget library")
T.eq(home.addSlot.row, 1,
  "the empty Home starts additions in the first centered row")

api.device = api.device or {
  powerInfo = function() return "battery", 80 end,
}
display.openHomeApp("store")
T.check(pcall(display.drawContents),
  "the real Store runtime model renders without an exception")
display.prepareMotion()
local storeMotionKey = display.motionKey()
home.storeView = "library"
T.check(display.motionKey() ~= storeMotionKey,
  "Store subviews receive distinct redraw identities")
display.prepareMotion()
T.eq(display.motion.started, nil,
  "changing a Store tab preserves its stationary navigation")
T.check(pcall(display.applyMotion),
  "an immediate tab change safely skips composition")
display.applyMotion()
T.eq(display.motion.started, nil,
  "an immediate tab change schedules no animation frames")
home.storeView = "today"
world.screenId, world.phase, world.index = "MotionFixture", "menu", 1
local phaseKey = display.motionKey()
world.index = 2
T.eq(display.motionKey(), phaseKey,
  "ordinary cursor movement does not animate the whole screen")
world.phase = "quantity"
T.check(display.motionKey() ~= phaseKey,
  "an in-place context phase change receives a distinct redraw identity")
world.screenId, world.phase, world.index = nil, nil, nil
do
  local clock, oldTime = 1, love.timer.getTime
  local savedGuard = {}; for k,v in pairs(display.touchGuard) do savedGuard[k]=v end
  love.timer.getTime = function() return clock end
  home.storeView, home.storeConfirm, home.storeReceived = "apps", nil, nil
  home.storePages.apps = 1
  local _, _, _, pages = display.storeSelection("apps")
  T.check(pages > 1, "Store fixture has multiple catalog pages")
  local function pointer(action, x, y)
    touchEvent(("%s,%d,%d"):format(action,x,y),240,216)
  end
  local function ready()
    display.syncTouchGuard(); clock = clock + 1
  end
  local function swipe(x, from, to)
    ready(); pointer("down",x,from); pointer("up",x,to)
  end
  swipe(80,145,75)
  T.eq(home.storePages.apps,2,"upward content swipe advances BUY")
  T.eq(home.storeConfirm,nil,"content swipe never purchases an app")
  swipe(80,75,145)
  T.eq(home.storePages.apps,1,"downward content swipe returns BUY")
  swipe(80,75,145)
  T.eq(home.storePages.apps,1,"scrolling before the beginning does not wrap")
  home.storePages.apps=pages; swipe(80,145,75)
  T.eq(home.storePages.apps,pages,"scrolling past the end does not wrap")
  swipe(195,145,75)
  T.eq(home.storePages.apps,pages,"the app preview is not a list swipe target")
  home.storeConfirm="notes"; swipe(80,75,145)
  T.eq(home.storePages.apps,pages,"confirmation blocks list swipes")
  T.eq(home.storeConfirm,"notes","swiping does not dismiss confirmation")
  home.storeConfirm=nil; home.storePages.apps=1; ready()
  local _,_,_,_,thumbY,thumbH=theme.hgss:storeScrollGeometry(1,pages)
  pointer("down",154,thumbY+math.floor(thumbH/2))
  T.eq(home.storePages.apps,1,"grabbing the thumb does not jump pages")
  pointer("move",154,159)
  T.eq(home.storePages.apps,pages,"dragging the rail updates before release")
  pointer("up",154,159)
  T.eq(home.storePages.apps,pages,"release does not cycle an extra page")
  T.eq(home.storeView,"apps","rail dragging never switches Store tabs")
  T.eq(home.storeReceived,nil,"rail dragging never installs an app")
  ready(); pointer("down",154,159); pointer("move",154,0); pointer("up",154,0)
  T.eq(home.storePages.apps,1,"dragging above the rail clamps to the first page")
  ready(); pointer("tap",154,159)
  T.eq(home.storePages.apps,pages,"tap-only input jumps to the touched rail position")
  ready(); pointer("tap",154,62)
  T.eq(home.storePages.apps,1,"tap-only input can return to the first page")
  local entries=display.storeEntries
  display.storeEntries=function() return {entries()[1]} end
  swipe(80,145,75)
  T.eq(home.storePages.apps,1,"a single-page catalog ignores scrolling")
  T.check(theme.hgss:storeHit(154,100,"apps",{pages=1})~="scroll","a single-page catalog has no rail hit target")
  T.eq(theme.hgss:storeScrollPage(100,1),1,"a single-page rail has no invalid division")
  display.storeEntries=entries; love.timer.getTime=oldTime
  for k in pairs(display.touchGuard) do display.touchGuard[k]=nil end
  for k,v in pairs(savedGuard) do display.touchGuard[k]=v end
  home.storeView="today"
end
local oldRodSurface = catalog.surfaces.tool_widget_old_rod
display.refreshToolSurfaces({})
T.check(oldRodSurface.hidden,
  "locked field gear stays out of the Home widget library")
game.save.inventory.OLD_ROD = 1
local fishAction = { id = "fish", label = "FISH",
  rods = { { id = "OLD_ROD", label = "OLD ROD" } } }
local usedTool
api.world = {
  availableFieldActions = function() return { fishAction } end,
  useFieldAction = function(_, id, opts)
    usedTool = { id = id, rod = opts and opts.rod }
    return true
  end,
}
display.refreshToolSurfaces({ fishAction })
T.check(not oldRodSurface.hidden and oldRodSurface.ready,
  "owned and currently usable field gear becomes a ready widget")
home.layout = { tiles = {
  { id = "tool_widget_old_rod", page = 1, column = 1, row = 1 },
} }
display.saveHome()
home.layout = { tiles = {} }
display.loadHome()
T.check(display.Home.find(home.layout, "tool_widget_old_rod") ~= nil,
  "the selected tool-widget configuration survives a durable reload")
home.page, home.editing, home.library = 1, false, false
local toolTile = display.Home.tiles(home.layout, catalog, 1)[1]
local toolX, toolY, toolW, toolH = theme.hgss:homeRect(toolTile)
display.tapHome(toolX + math.floor(toolW / 2),
  toolY + math.floor(toolH / 2))
T.eq(usedTool and usedTool.id, "fish",
  "tapping a ready field widget uses its action directly")
T.eq(usedTool and usedTool.rod, "OLD_ROD",
  "rod widgets preserve the configured rod")
display.refreshToolSurfaces({})
display.tapHome(toolX + math.floor(toolW / 2),
  toolY + math.floor(toolH / 2))
T.eq(page(), "TOOLS",
  "a field widget that is not usable here opens its Field Kit")
tap(5, 5)
T.eq(page(), "HOME", "Field Kit back returns Home")
do
  local inventory, party, badges = game.save.inventory, game.save.party, game.save.player.badges
  local availableTool = display.availableTool
  game.save.inventory = { BICYCLE = 1, OLD_ROD = 1, GOOD_ROD = 1 }
  game.save.party = { { moves = { { id = "CUT" }, { id = "TELEPORT" } } } }
  game.save.player.badges = { HIVE = true }
  local usable = { cut = { id = "cut" }, teleport = { id = "teleport" } }
  display.availableTool = function(_, id) return usable[id] end
  local actions = display.toolModels()
  T.eq(#actions, 4, "Tools groups multiple rods into one fishing card")
  for index, id in ipairs({ "cut", "teleport", "bicycle", "fish" }) do
    T.eq(actions[index].id, id, "usable tools come first with stable order within each group")
    T.eq(actions[index].ready, index <= 2, "the sorted card keeps its current availability")
  end
  local action, index = theme.hgss:toolsHit(20, 50, { actions = actions, page = 1 })
  T.eq(action, "action", "the first sorted card remains tappable")
  T.eq(index and actions[index].action, usable.cut, "touch resolves the sorted card's actual field action")
  local view = display.toolsView()
  T.eq(view.pages, 1, "a small Field Kit fits on one page")
  action, index = theme.hgss:toolsHit(130, 50, view)
  T.eq(index and actions[index].id, "teleport", "the second ready card sits beside the first")
  T.eq(theme.hgss:toolsHit(20, 90, view), nil, "unlocked tools that do nothing here stay inert")
  local crowded = { { ready = true, rods = { {}, {}, {} } } }
  for i = 1, 22 do crowded[#crowded + 1] = { ready = i <= 10 } end
  local layout, seen = theme.hgss:toolsLayout(crowded), {}
  T.check(layout.pages > 1, "overflowing Field Kit creates additional pages")
  for _, item in ipairs(layout.items) do
    T.check(not seen[item.index], "each Field Kit action appears exactly once")
    seen[item.index] = true
    T.check(item.y >= 34 and item.y + item.h <= 199, "paged tools leave the pager clear")
    local model = { actions = crowded, layout = layout, page = item.page }
    local hit, index = theme.hgss:toolsHit(item.x + item.w / 2, item.y + item.h / 2, model)
    if item.kind == "chip" then T.eq(hit, nil, "idle overflow chips remain inert")
    else T.eq(index, item.index, "overflow card resolves its original action") end
    for _, other in ipairs(layout.items) do
      if item ~= other and item.page == other.page then
        T.check(item.x + item.w <= other.x or other.x + other.w <= item.x
          or item.y + item.h <= other.y or other.y + other.h <= item.y,
          "Field Kit controls never overlap")
      end
    end
    if item.kind == "rods" then
      for rod = 1, 3 do
        local rx, ry, rw, rh = theme.hgss:toolRodRect(item, rod, 3)
        local kind, owner, slot = theme.hgss:toolsHit(rx + rw / 2, ry + rh / 2, model)
        T.check(kind == "rod" and owner == item.index and slot == rod,
          "each inline rod resolves independently")
      end
    end
  end
  T.eq(#layout.items, #crowded, "pagination retains every unlocked tool")
  local availableActions = api.world.availableFieldActions
  api.world.availableFieldActions = function() return { usable.cut, usable.teleport } end
  display.openHomeApp("tools")
  usedTool = nil
  tap(90, 33)
  T.eq(display.toolsView().armed, "teleport", "first Teleport tap arms the visible card")
  T.eq(usedTool, nil, "first Teleport tap does not change location")
  tap(90, 33)
  T.eq(usedTool and usedTool.id, "teleport", "second Teleport tap executes the field action")
  T.eq(display.toolsView().armed, nil, "executed location action is disarmed")
  tap(90, 33)
  run.loader.events:emit("map.entered", { mapId = "ROUTE_1" })
  T.eq(display.toolsView().armed, nil, "map changes invalidate confirmation even with identical tools")
  run.loader.events:emit("map.entered", { mapId = "PALLET_TOWN" })
  tap(90, 33)
  run.loader.events:emit("save.loaded", {})
  T.eq(display.toolsView().armed, nil, "loading a save invalidates the waiting confirmation")
  display.openHomeApp("tools")
  tap(90, 33)
  display.openHomeApp("map")
  T.eq(display.toolsView().armed, nil, "opening another app cancels the waiting confirmation")
  tap(5, 5)
  display.openHomeApp("tools")
  tap(90, 33)
  api.world.availableFieldActions = function() return {}, "world is busy" end
  upvalue(upvalue(display.activateTool, "useTool"), "refreshTools")()
  T.eq(display.toolsView().armed, nil, "native busy state cancels the waiting confirmation")
  tap(5, 5)
  api.world.availableFieldActions = availableActions
  usable = { bicycle = { id = "bicycle" }, fish = { id = "fish" } }
  actions = display.toolModels()
  for index, id in ipairs({ "bicycle", "fish", "cut", "teleport" }) do
    T.eq(actions[index].id, id, "Tools reorders when the current context changes")
  end
  usable.fish.rods = { { id = "OLD_ROD" }, { id = "GOOD_ROD" }, { id = "SUPER_ROD" } }
  display.openHomeApp("tools")
  local fishingView = display.toolsView()
  local fishingCard = fishingView.layout.items[1]
  local rx, ry, rw, rh = theme.hgss:toolRodRect(fishingCard, 3, 3)
  usedTool = nil
  tap((rx + rw / 2) / theme.hgssScale, (ry + rh / 2) / theme.hgssScale)
  T.eq(usedTool and usedTool.id, "fish", "inline rod selection starts the native fishing action")
  T.eq(usedTool and usedTool.rod, "SUPER_ROD", "inline rod selection preserves the tapped rod ID")
  tap(5, 5)
  game.save.inventory, game.save.party, game.save.player.badges = inventory, party, badges
  display.availableTool = availableTool
end
home.layout = { tiles = {
  { id = "map_app", page = 1, column = 1, row = 1 },
} }
home.page, home.editing, home.library = 1, false, false
local mapTile = display.Home.tiles(home.layout, catalog, 1)[1]
local mapX, mapY, mapW, mapH = theme.hgss:homeRect(mapTile)
local scale = theme.hgssScale
local downX = math.floor((mapX + mapW / 2) / scale)
local downY = math.floor((mapY + mapH / 2) / scale)
local realTime = love.timer.getTime
local fakeTime = 100
love.timer.getTime = function() return fakeTime end
touchEvent(("down,%d,%d"):format(downX, downY))
fakeTime = fakeTime + display.Home.holdSeconds + 0.01
T.check(display.updateHomeLongPress(fakeTime),
  "holding Map enters Home edit mode before finger release")
T.check(home.editing, "Home editor is visible while the finger remains down")
touchEvent(("tap,%d,%d"):format(downX, downY))
T.eq(page(), "HOME", "the held touch cannot also open Map")
touchEvent(("up,%d,%d"):format(downX, downY))
home.editing = false
fakeTime = fakeTime + 1
touchEvent(("down,%d,%d"):format(downX, downY))
fakeTime = fakeTime + display.Home.holdSeconds + 0.01
T.check(display.updateHomeLongPress(fakeTime),
  "Home touch input resumes after the long-press finger is released")
touchEvent(("up,%d,%d"):format(downX, downY))
home.layout = { tiles = {} }
home.page, home.editing, home.library, home.addSlot = 1, false, false, nil
fakeTime = fakeTime + 1
local emptyDownX = math.floor((emptyHomeX + emptyHomeW / 2) / scale)
local emptyDownY = math.floor((emptyHomeY + emptyHomeH / 2) / scale)
touchEvent(("down,%d,%d"):format(emptyDownX, emptyDownY))
fakeTime = fakeTime + display.Home.holdSeconds + 0.01
T.check(display.updateHomeLongPress(fakeTime) and home.editing,
  "holding an empty Home still enters edit mode")
touchEvent(("up,%d,%d"):format(emptyDownX, emptyDownY))
display.openHomeApp("store")
display.syncTouchGuard()
fakeTime = fakeTime + 0.3

touchEvent("down,20,30")
T.check(pcall(display.drawContents),
  "an active touch renders through the shared HGSS pressed layer")
T.eq(theme.hgss.touchX, 20, "touch-down reaches the HGSS renderer immediately")
touchEvent("cancel,0,0")
T.check(pcall(display.drawContents), "touch cancel redraws safely")
T.eq(theme.hgss.touchX, nil, "touch cancel clears the pressed state")
love.timer.getTime = realTime

T.check(catalog.packages.settings.fixed
    and catalog.surfaces.settings_app.package == "settings",
  "Silph Link Settings is a fixed OS app with its own Home icon")
display.settings.direct, display.settings.choicePage = true, 2
T.check(display.openHomeApp("settings"), "Settings opens from Home")
T.eq(page(), "SETTINGS", "Settings owns a real Silph Link page")
T.eq(display.settings.option, nil, "reopening Settings clears its previous explanation")
T.eq(display.settings.direct, nil, "reopening Settings clears direct-navigation state")
T.eq(display.settings.choicePage, 1, "reopening Settings resets its choice pager")
local settings = display.settingsModel()
T.eq(#(settings.tabs or settings.categories), 7,
  "Settings groups the existing options into seven readable sections")
T.eq((settings.tabs or settings.categories)[6].id, "notifications", "Notifications have their own section")
display.settings.category, display.settings.page = 5, 1
settings = display.settingsModel()
local keyboardRow
for _, row in ipairs(settings.rows) do
  if row.key == "keyboard_layout" then keyboardRow = row end
end
T.check(keyboardRow ~= nil, "Controls exposes the touch keyboard layout")
T.eq(keyboardRow.value, "QWERTY", "Controls shows the QWERTY default")
T.check(display.cycleSetting(keyboardRow, 1), "touch settings select QWERTZ")
T.eq(run.loader.modOptions.kanto_gear.keyboard_layout, "qwertz", "layout uses the shared option store")
T.check(display.cycleSetting(keyboardRow, 1), "touch settings cycle back to QWERTY")
T.eq(run.loader.modOptions.kanto_gear.keyboard_layout, "qwerty", "both layout choices are reachable")
display.settings.category, display.settings.page = 3, 1
settings = display.settingsModel()
local caughtRow
for _, row in ipairs(settings.rows) do
  if row.key == "caught_icon" then caughtRow = row end
end
T.check(caughtRow ~= nil, "Battle settings exposes the caught marker")
T.check(display.cycleSetting(caughtRow, 1),
  "an in-app setting writes through the public option API")
T.eq(run.loader.modOptions.kanto_gear.caught_icon, false,
  "the Settings app and classic mod menu share one live option value")
display.settings.category, display.settings.page = 2, 1
run.loader.modOptions.kanto_gear.display_mode = "fullscreen"
settings = display.settingsModel()
T.eq(#settings.rows, 2,
  "Display settings only shows controls relevant to fullscreen mode")
run.loader.modOptions.kanto_gear.display_mode = "combined"
settings = display.settingsModel()
T.check(#settings.rows >= 6,
  "Display settings reveals the combined-layout controls when relevant")
T.check(display.cycleSettingsPage(1) and display.settings.page == 2,
  "Settings arrows, swipes and trigger navigation share the category pager")
T.check(display.cycleSettingsPage(1) and display.settings.page == 1,
  "Settings category paging wraps consistently")
display.settings.category, display.settings.page = 1, 1
settings = display.settingsModel()
local mapMotionRow
for _, row in ipairs(settings.rows) do
  if row.key == "map_motion" then mapMotionRow = row end
end
T.check(mapMotionRow ~= nil, "Appearance exposes the shared map movement preference")
T.eq(mapMotionRow.source.default, "quality", "existing smooth movement remains the default")
T.check(display.cycleSetting(mapMotionRow, 1), "map movement mode can be changed through Settings")
T.eq(run.loader.modOptions.kanto_gear.map_motion, "performance", "Settings saves the performance mode")
display.cycleSetting(mapMotionRow, 1)
T.eq(run.loader.modOptions.kanto_gear.map_motion, "quality", "Settings can restore quality mode")
api.options:set("language", "en")
display.tapSettings(30, 80)
T.eq(display.settingsModel().selected, "language",
  "the first tap selects the visible setting and explains it")
display.tapSettings(170, 80)
T.eq(display.settingsModel().option, "language",
  "the selected row's value opens its full list of choices")
T.eq(run.loader.modOptions.kanto_gear.language, "en",
  "opening an explanation does not change the setting")
display.tapSettings(120, 180)
T.eq(run.loader.modOptions.kanto_gear.language, "en",
  "the explanation itself cannot change the setting")
local choiceTop = theme.hgss:settingsChoiceTop(display.settingsModel())
display.tapSettings(120, choiceTop + 36)
T.eq(run.loader.modOptions.kanto_gear.language, "de",
  "an explicit language choice changes the live setting")
display.tapSettings(120, choiceTop + 11)
T.eq(run.loader.modOptions.kanto_gear.language, "en",
  "the English choice restores the original language")
display.tapSettings(10, 10)
T.eq(display.settings.option, nil,
  "Back from an explanation returns to the category")
display.tapSettings(223, 62)
T.eq(display.settings.page, 2, "the section next arrow opens the second Settings page")
display.tapSettings(186, 62)
T.eq(display.settings.page, 1, "the section previous arrow returns to the first page")
T.eq(theme.hgss:settingsHit(120, 200, settings), nil,
  "the page counter does not change a setting or page")
T.eq(theme.hgss:settingsHit(37, 15, settings), nil,
  "the unmarked Settings header no longer hides a page action")
local disabledSettings = { category = "test", page = 1, pages = 1,
  rows = { { label = "LANGUAGE", value = "ENGLISH", enabled = false } } }
T.eq(theme.hgss:settingsHit(20, 62, disabledSettings), nil,
  "disabled Settings rows ignore the left value area")
T.eq(theme.hgss:settingsHit(220, 62, disabledSettings), nil,
  "disabled Settings rows ignore the right value area")
T.eq(theme.hgss:settingsHit(152, 200, disabledSettings), nil,
  "a single Settings page has no invisible pager")
local motionRow
for _, row in ipairs(settings.rows) do
  if row.key == "ui_motion" then motionRow = row end
end
T.check(motionRow ~= nil, "Appearance settings exposes reduced UI motion")
T.check(display.cycleSetting(motionRow, 1),
  "UI motion can be disabled from Silph Link Settings")
T.eq(theme.hgss.motionEnabled, false,
  "the HGSS renderer receives the reduced-motion setting immediately")
display.motion.key, display.motion.started = "old", nil
display.prepareMotion()
T.eq(display.motion.started, nil,
  "reduced motion suppresses shared page transitions")
theme.hgss:beginPartyAction(love.timer.getTime())
T.eq(theme.hgss.partyActionStarted, nil,
  "reduced motion suppresses Party context entrance movement")
T.check(display.cycleSetting(motionRow, 1),
  "UI motion can be restored without restarting")
run.loader.modOptions.kanto_gear.info_level = "spoiler"
run.loader.modOptions.kanto_gear.ui_motion = false
run.loader.modOptions.kanto_gear.display_mode = "combined"
run.loader.modOptions.kanto_gear.combined_layout = "side"
display.runSettingsAction("reset_options")
T.eq(run.loader.modOptions.kanto_gear.caught_icon, false,
  "the first reset tap only arms the destructive action")
display.runSettingsAction("reset_options")
T.eq(run.loader.modOptions.kanto_gear.caught_icon, true,
  "the confirmed options reset restores the 3.0 defaults")
  T.eq(run.loader.modOptions.kanto_gear.theme_v3, "hgss",
  "resetting options returns to the Silph Link default theme")
T.eq(run.loader.modOptions.kanto_gear.info_level, "enhanced",
  "resetting options does not preserve a migrated research mode")
T.eq(run.loader.modOptions.kanto_gear.ui_motion, true,
  "resetting options restores UI motion")
T.eq(run.loader.modOptions.kanto_gear.display_mode, "combined",
  "resetting options restores the canonical display mode")
T.eq(run.loader.modOptions.kanto_gear.combined_layout, "auto",
  "resetting options restores the canonical combined layout")
-- The remaining fixtures exercise the physical companion's retained frames.
run.loader.modOptions.kanto_gear.display_mode = "separate"
home.layout = { tiles = {
  { id = "map_app", page = 1, column = 1, row = 1 },
} }
display.runSettingsAction("reset_home")
T.eq(#home.layout.tiles, 1,
  "the first Home reset tap preserves the custom layout")
display.runSettingsAction("reset_home")
T.check(display.Home.find(home.layout, "explorer_widget") ~= nil
    and display.Home.find(home.layout, "party_widget") ~= nil
    and display.Home.find(home.layout, "map_app") ~= nil
    and display.Home.find(home.layout, "tools_app") ~= nil
    and display.Home.find(home.layout, "store_app") ~= nil
    and display.Home.find(home.layout, "settings_app") ~= nil
    and display.Home.find(home.layout, "trainer_app") == nil
    and display.Home.find(home.layout, "party_app") == nil
    and display.Home.pageCount(home.layout) == 1,
  "the confirmed Home reset restores the complete default layout")

local originalTime = love.timer.getTime
local habitatNow = 10
love.timer.getTime = function() return habitatNow end
game.save.inventory.TM_TEST = 1
game.data.items.TM_TEST = { teaches = "HEADBUTT" }
local selected = { habitat = { appearances = {
  { mapId = "PALLET_TOWN", method = "HEADBUTT", chance = 50 },
  { mapId = "UNVISITED_BASEMENT", method = "WALK", chance = 90 },
} } }
local plan = display.pokedexHabitatPlan(selected)
T.eq(plan.count, 1, "runtime planning uses available machines without teaching them")
for _ = 1, 60 do
  T.eq(display.pokedexHabitatPlan(selected), plan,
    "rendering reuses the planning result instead of scanning storage each frame")
end
game.save.inventory.TM_TEST = nil
habitatNow = 10.6
local updated = display.pokedexHabitatPlan(selected)
T.eq(updated.count, 0, "inventory changes refresh suitability without reopening the app")
T.check(updated.signature ~= plan.signature, "changed suitability invalidates the visible result")
local otherSave = { habitat = { appearances = selected.habitat.appearances } }
T.check(display.pokedexHabitatPlan(otherSave) ~= updated,
  "a rebuilt dex never reuses a previous save's cached plan")
love.timer.getTime = originalTime
assert(loadfile(path .. "/tests/pss_runtime_cases.lua"))()(T, display, tap)
display.pss:open()
local priorMods = game.mods
game.mods = run.loader
if display.pss.session then
  T.eq(display.pss.session:profileValid(), false, "Gen 2 respects the real online permission gate")
  T.eq(display.pss.session.notice, "RECOMP BLOCKS UI MODS", "Gen 2 explains restricted online actions")
else T.check(not pcall(require,"src.online.union.Room"),"older host has a read-only online browser") end
game.mods = priorMods
display.pss:close()
do
  -- Actual compose hook, local relay, and hidden Gear: no public connection.
  local Client, Connect = require("src.online.Client"), require("src.online.Connect")
  local savedSync = package.loaded["src.sync.SyncState"]
  local stored = {}
  package.loaded["src.sync.SyncState"] = {
    load=function() return stored end, update=function(fn) fn(stored) end,
    linked=function() return false end,
  }
  Client.reset(); Connect.reset()
  local relay = require("tests.support.fake_relay").new()
  local seat = relay:seat("self", "ME")
  Client.configure({relayAddress="local-test",connect=function() return seat.transport end})
  display.setPackageInstalled("pss",true)
  home.widgetCache=nil
  local widget=display.homeWidgetData({pss=true})
  display.pss:action("connect")
  relay:pump(); Client.update(0)
  local clock=20
  love.timer.getTime=function() return clock end
  local function setCompose(name,value)
    assert(loadfile(path .. "/tests/support/runtime.lua"))().set(composeHook,name,value)
  end
  local function frame()
    setCompose("dirty",false)
    composeHook(function() end, {}, {})
    clock=clock+0.3
  end
  display.openHomeApp("party")
  frame()
  T.eq(widget.pss.state,"online","hidden Gear compose retains online connection")
  relay:to(seat,{type="lobby_list",entries={{id="a",name="ALICE",where="game",status="idle"}}})
  Client.update(0); frame()
  T.eq(#widget.pss.rows,1,"another app receives joins without reopening Silph Connect")
  relay:to(seat,{type="lobby_delta",changed={{id="a",name="ALICE",where="game",status="trading"}}})
  Client.update(0); frame()
  T.eq(widget.pss.rows[1].status,"trading","background presence refreshes the shared widget snapshot")
  T.eq(upvalue(composeHook,"dirty"),false,"presence changes do not redraw unrelated apps")
  home.layout={tiles={{id="pss_widget",page=1,column=1,row=1}}}
  home.page=1
  setCompose("page","HOME")
  relay:to(seat,{type="lobby_delta",changed={{id="a",name="ALICE",where="game",status="idle"}}})
  Client.update(0); frame()
  T.eq(upvalue(composeHook,"dirty"),true,"visible online widget redraws on a presence change")
  local snapshot=widget.pss.rows
  for _=1,5 do frame() end
  T.eq(widget.pss.rows,snapshot,"idle background frames reuse the list")
  T.eq(upvalue(composeHook,"dirty"),false,"unchanged online widget requests no redraw")
  home.page=2
  relay:to(seat,{type="lobby_delta",removed={"a"}})
  Client.update(0); frame()
  T.eq(#widget.pss.rows,0,"background departures clear the widget")
  T.eq(upvalue(composeHook,"dirty"),false,"widget on another Home page requests no redraw")
  display.pss:action("disconnect"); frame()
  T.eq(widget.pss.state,"offline","explicit disconnect is reflected outside the app")
  display.setPackageInstalled("pss",false)
  T.check(not display.pss.listener,"uninstall stops background observation")
  love.timer.getTime=originalTime
  package.loaded["src.sync.SyncState"]=savedSync
  Client.reset(); Connect.reset()
end
run.release()
T.finish("Kanto Gear Home runtime")
