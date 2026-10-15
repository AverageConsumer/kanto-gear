return function(
  Area, Discovery, HEIGHT, SettingsInfo, THEME, WIDTH,
  box, color, fit, glyphList, mod, render,
  session, text
)
  local displayRuntime, compat = {}, {}
  session.discoveryPolicy = Discovery.resolve(function(key) return mod.options:get(key) end)
  Discovery.updating = false
  local function assist(key)
    Discovery.current()
    if key == "spoilers" then return session.discoveryPolicy.future_tasks end
    if key == "guide" then return session.discoveryPolicy.wild end
    if key == "area" then return session.discoveryPolicy.trainers or session.discoveryPolicy.items end
    if key == "item_radar" then return session.discoveryPolicy.items end
    if session.discoveryPolicy[key] ~= nil then return session.discoveryPolicy[key] == true end
    return true
  end
  function Discovery.changed(key, value)
    if Discovery.updating then return false end
    Discovery.updating = true
    local feature = Discovery.byKey[key]
    if (feature and value ~= session.discoveryPolicy[feature[1]] and mod.options:get("info_level") ~= "custom")
        or key == "info_level" and value == "custom" and session.discoveryPolicy.preset ~= "custom" then
      local previous = session.discoveryPolicy
      mod.options:set("info_level", "custom")
      for _, row in ipairs(Discovery.options) do
        local option, selected = Discovery.key(row[1]), previous[row[1]]
        if feature and option == key then selected = value end
        mod.options:set(option, selected)
      end
    end
    session.discoveryPolicy = Discovery.resolve(function(option) return mod.options:get(option) end)
    if key == "info_level" and value ~= "custom" then
      for _, row in ipairs(Discovery.options) do
        mod.options:set(Discovery.key(row[1]), session.discoveryPolicy[row[1]])
      end
    end
    Discovery.updating = false
    return key == "info_level" or feature ~= nil
  end
  function Discovery.current()
    local preset = mod.options:get("info_level")
    if not Discovery.updating and preset ~= session.discoveryPolicy.preset then Discovery.changed("info_level", preset) end
    return session.discoveryPolicy
  end

  local function currentBattleUIMode()
    return mod.options:get("battle_view") or "standard"
  end
  local function fullBottomBattleUI()
    if displayRuntime.autoBattle and displayRuntime.autoBattle.shown == false then return false end
    return currentBattleUIMode() == "full"
  end
  local function bottomBattleHud()
    return fullBottomBattleUI()
  end
  local function customBattleLayout()
    if displayRuntime.autoBattle and displayRuntime.autoBattle.shown == false then return false end
    local mode = currentBattleUIMode()
    return mode == "gear" or mode == "full"
  end
  do local initial = {
    explorer = {
      page = 1, mapFull = false, mapZoom = 1,
      filters = { wildScope = "HERE" },
      scanRevealed = {},
    },
    pokedex = { view = "index", page = 1, habitatPage = 1 },
    bag = { pocket = 1, page = 1, pending = nil },
  }; for key, value in pairs(initial) do displayRuntime[key] = value end end
  displayRuntime.recentItem = assert(load(mod:read("core/recent_item.lua"),
    "@kanto_gear/core/recent_item.lua"))().new(mod.save)

  function displayRuntime.pcStateKey(state)
    if not state then return "" end
    local qty, confirm, pack, message = state.qtyState, state.confirm,
      state.pack, state.message
    return table.concat({
      tostring(state.index), tostring(state.pickIndex),
      tostring(state.listIndex), tostring(state.boxIndex),
      tostring(state.scroll), tostring(state.phase), tostring(state.mode),
      tostring(state.pocketIndex), tostring(state.__gen3uiBagPocketIndex),
      tostring(state.picking), tostring(state.savePhase),
      tostring(state.saveChoice), tostring(state.submenuIndex),
      tostring(state.submenu), tostring(type(state.submenu) == "table" and state.submenu.index),
      tostring(state.message), tostring(state.messagePage),
      tostring(type(message) == "table" and message.page),
      tostring(qty and qty.qty), tostring(qty and qty.max),
      tostring(confirm and confirm.choice),
      tostring(pack and pack.index), tostring(pack and pack.pocketIndex),
      tostring(pack and pack.__gen3uiBagPocketIndex),
    }, ":")
  end
  assert(displayRuntime.pcStateKey({ pickIndex = 2 })
      ~= displayRuntime.pcStateKey({ pickIndex = 3 })
      and displayRuntime.pcStateKey({ listIndex = 1 })
        ~= displayRuntime.pcStateKey({ listIndex = 2 })
      and displayRuntime.pcStateKey({ qtyState = { qty = 1 } })
        ~= displayRuntime.pcStateKey({ qtyState = { qty = 2 } })
      and displayRuntime.pcStateKey({ message = { page = 1 } })
        ~= displayRuntime.pcStateKey({ message = { page = 2 } }),
    "PC redraw key follows every native cursor")
  function displayRuntime.adjustExplorerZoom(direction)
    local explorer = displayRuntime.explorer
    local current = math.max(1, math.min(3, explorer.mapZoom or 1))
    explorer.mapZoom = math.max(1, math.min(3, current + direction))
    return explorer.mapZoom ~= current
  end
  assert(not displayRuntime.adjustExplorerZoom(-1)
      and displayRuntime.adjustExplorerZoom(1)
      and displayRuntime.explorer.mapZoom == 2,
    "Explorer fullscreen zoom clamps and advances")
  displayRuntime.explorer.mapZoom = 1
  displayRuntime.autoBattle = {}
  function displayRuntime.gearPrimary()
    if displayRuntime.autoBattle.shown ~= nil then return displayRuntime.autoBattle.shown end
    return THEME:gearPrimary(mod.options, displayRuntime.swapped)
  end

  local function inlineDisplay()
    local mode = THEME:displayMode(mod.options)
    return mode == "fullscreen" or mode == "combined"
  end
  local function bottomOnHandheld()
    if THEME:displayMode(mod.options) == "phone" then return false end
    local handheld = mod.options:get("display_target") == "handheld"
    if displayRuntime.swapped then return not handheld end
    return handheld
  end
  local function displayPreference()
    if displayRuntime.swapped then
      return bottomOnHandheld() and "handheld" or "secondary"
    end
    return mod.options:get("display_target")
  end

  render.G = rawget(_G, "love") and rawget(_G, "love").graphics
  if not render.G then
    mod.log:warn("host has no graphics runtime; mod stays inactive")
    return
  end

  if rawget(_G, "love").filesystem
      and rawget(_G, "love").filesystem.newFileData then
    local L = rawget(_G, "love")
    if L.image and L.image.newImageData and render.G.newImageFont then
      local fontGlyphs = assert(load(mod:read("ui/fonts/glyphs.lua"),
        "@kanto_gear/ui/fonts/glyphs.lua"))()
      local function imageFont(name)
        local data = L.filesystem.newFileData(mod:read(name), name)
        local image = L.image.newImageData(data)
        local metrics
        if name == "ui/fonts/hgss_small_font.png" then
          metrics = assert(load(mod:read("ui/fonts/metrics.lua"), "@kanto_gear/ui/fonts/metrics.lua"))()(image, glyphList(fontGlyphs))
        end
        return render.G.newImageFont(image, fontGlyphs), metrics
      end
      THEME.hgssFont = imageFont("ui/fonts/hgss_font.png")
      THEME.hgssSmallFont, THEME.hgssSmallMetrics = imageFont("ui/fonts/hgss_small_font.png")
      THEME.hgssLargeFont = imageFont("ui/fonts/hgss_large_font.png")
    end
  end
  THEME.translationFonts = assert(load(mod:read("i18n/fonts.lua"),
    "@kanto_gear/i18n/fonts.lua"))().new(render.G, function(message) mod.log:warn(message) end,
      function(name)
        return rawget(_G, "love").filesystem.newFileData(mod:read(name), name)
      end)
  function displayRuntime.dimBackground(alpha)
    displayRuntime.backgroundDim = 1
      - (1 - (displayRuntime.backgroundDim or 0)) * (1 - alpha)
  end

  function displayRuntime.backgroundColor()
    local factor = 1 - (displayRuntime.backgroundDim or 0)
    local packed = render.SECONDARY_BACKGROUND
    return math.floor(math.floor(packed / 0x10000) * factor + 0.5) * 0x10000
      + math.floor(math.floor(packed / 0x100) % 0x100 * factor + 0.5) * 0x100
      + math.floor(packed % 0x100 * factor + 0.5)
  end

  displayRuntime.ChoicePage = assert(load(mod:read("ui/pages/choice.lua"),
    "@kanto_gear/ui/pages/choice.lua"))()
  displayRuntime.NamingPage = assert(load(mod:read("ui/pages/naming.lua"),
    "@kanto_gear/ui/pages/naming.lua"))()
  displayRuntime.PartyPage = assert(load(mod:read("ui/pages/party.lua"),
    "@kanto_gear/ui/pages/party.lua"))()
  displayRuntime.MovePage = assert(load(mod:read("ui/pages/move.lua"), "@kanto_gear/ui/pages/move.lua"))()
  displayRuntime.ItemPage = assert(load(mod:read("ui/pages/item.lua"), "@kanto_gear/ui/pages/item.lua"))()
  displayRuntime.PokedexPage = assert(load(mod:read("ui/pages/pokedex.lua"), "@kanto_gear/ui/pages/pokedex.lua"))()
  displayRuntime.Evolutions = assert(load(mod:read("models/evolutions.lua"), "@kanto_gear/models/evolutions.lua"))()
  displayRuntime.NativeDex = assert(load(mod:read("adapters/native_dex.lua"), "@kanto_gear/adapters/native_dex.lua"))()
  displayRuntime.NativeDex.describe3 = assert(load(mod:read("adapters/native_dex3.lua"), "@kanto_gear/adapters/native_dex3.lua"))()
  displayRuntime.SafariPage = assert(load(mod:read("ui/pages/safari.lua"), "@kanto_gear/ui/pages/safari.lua"))()
  local hgssUi = {
    graphics = render.G, box = box, text = text, fit = fit,
    glyphs = glyphList, color = color, font = THEME.hgssFont,
    nativeFocus = false, partyPage = displayRuntime.PartyPage, itemPage = displayRuntime.ItemPage,
    safariPage = displayRuntime.SafariPage, pokedexPage = displayRuntime.PokedexPage,
    smallFont = THEME.hgssSmallFont,
    smallFontMetrics = THEME.hgssSmallMetrics,
    largeFont = THEME.hgssLargeFont,
    translationFonts = THEME.translationFonts,
    translate = function(value) return THEME:translate(value) end,
    format = function(value, ...) return THEME:format(value, ...) end,
    dimBackground = displayRuntime.dimBackground,
  }
  THEME.hgss, displayRuntime.v4 = assert(load(mod:read("ui/init.lua"), "@kanto_gear/ui/init.lua"))()(
    hgssUi, function(name) return mod:read(name) end)

  assert(THEME.hgss:battleChoice(120, 80) == 1
      and THEME.hgss:battleChoice(200, 170) == 2
      and THEME.hgss:battleChoice(40, 170) == 3
      and THEME.hgss:battleChoice(120, 185) == 4,
    "HGSS battle action hitboxes")
  assert(THEME.hgss.battleActions[2].w == THEME.hgss.battleActions[3].w
      and THEME.hgss.battleActions[3].w == THEME.hgss.battleActions[4].w
      and THEME.hgss.battleActions[2].h == THEME.hgss.battleActions[3].h
      and THEME.hgss.battleActions[3].h == THEME.hgss.battleActions[4].h,
    "HGSS secondary battle actions share one size")
  assert(THEME.hgss:partySlot(4, 22, 6) == 1
      and THEME.hgss:partySlot(82, 25, 6) == 2
      and THEME.hgss:partySlot(4, 60, 6) == 3
      and THEME.hgss:partySlot(82, 101, 5) == nil,
    "HGSS party hitboxes follow staggered cards")

  -- Public builds keep optional wall-time diagnostics disabled.
  displayRuntime.perf = assert(load(mod:read("core/performance.lua"),
    "@kanto_gear/core/performance.lua"))().new(
      function() return love.timer.getTime() end,
      function(line) mod.log:info("%s", line) end, false)
  if displayRuntime.perf.enabled then
    mod.log:info("KGPROF v=1 kind=build version=%s units=ms timing=wall nested=true", mod.version or "unknown")
  end
  displayRuntime.LevelUp = assert(load(mod:read("core/level_up.lua"),
    "@kanto_gear/core/level_up.lua"))()
  displayRuntime.levelUp = displayRuntime.LevelUp.new()
  displayRuntime.fruitTrees = assert(load(mod:read("features/fruit_trees.lua"),
    "@kanto_gear/features/fruit_trees.lua"))()
  displayRuntime.touchGuard = assert(load(mod:read("core/touch_guard.lua"),
    "@kanto_gear/core/touch_guard.lua"))().new()
  displayRuntime.StartMenu = assert(load(mod:read("adapters/start_menu.lua"),
    "@kanto_gear/adapters/start_menu.lua"))()
  displayRuntime.TrainerPage = assert(load(mod:read("ui/pages/trainer.lua"),
    "@kanto_gear/ui/pages/trainer.lua"))()
  displayRuntime.trainerPage = 1
  displayRuntime.NativeOptions = assert(load(mod:read("core/native_options.lua"),
    "@kanto_gear/core/native_options.lua"))()
  displayRuntime.PokegearPage = assert(load(mod:read("ui/pages/pokegear.lua"),
    "@kanto_gear/ui/pages/pokegear.lua"))()
  -- Game path [Gen 1/2]: Legacy* here names the active GB/GBC adapters, not retired code; Gen 3 installs its separate native adapters.
  displayRuntime.LegacyPC = assert(load(mod:read("adapters/gen1_2/pc.lua"),
    "@kanto_gear/adapters/gen1_2/pc.lua"))()
  displayRuntime.StoragePage = assert(load(mod:read("ui/pages/storage.lua"),
    "@kanto_gear/ui/pages/storage.lua"))()
  displayRuntime.LegacyStorage = assert(load(mod:read("adapters/gen1_2/storage.lua"),
    "@kanto_gear/adapters/gen1_2/storage.lua"))()
  displayRuntime.LegacyShop = assert(load(mod:read("adapters/gen1_2/shop.lua"),
    "@kanto_gear/adapters/gen1_2/shop.lua"))()
  displayRuntime.LegacyParty = assert(load(mod:read("adapters/gen1_2/party.lua"),
    "@kanto_gear/adapters/gen1_2/party.lua"))()
  displayRuntime.LegacyBag = assert(load(mod:read("adapters/gen1_2/bag.lua"),
    "@kanto_gear/adapters/gen1_2/bag.lua"))()
  displayRuntime.RegionPage = assert(load(mod:read("ui/pages/region_map.lua"),
    "@kanto_gear/ui/pages/region_map.lua"))()
  displayRuntime.LegacyRegion = assert(load(mod:read("adapters/gen1_2/region.lua"),
    "@kanto_gear/adapters/gen1_2/region.lua"))()
  displayRuntime.regionCursor = {}
  displayRuntime.Home = assert(load(mod:read("core/home_layout.lua"),
    "@kanto_gear/core/home_layout.lua"))()
  displayRuntime.Achievements = assert(load(mod:read("features/achievements.lua"),
    "@kanto_gear/features/achievements.lua"))()
  displayRuntime.LocationPreview = assert(load(mod:read("models/location_preview.lua"),
    "@kanto_gear/models/location_preview.lua"))()
  Area.Pickups = assert(load(mod:read("core/pickup_state.lua"),
    "@kanto_gear/core/pickup_state.lua"))()
  Area.pickupData = nil
  Area.Gifts = assert(load(mod:read("features/gen2_gifts.lua"), "@kanto_gear/features/gen2_gifts.lua"))()
  Area.giftData = nil
  Area.Gifts1 = assert(load(mod:read("features/gen1_gifts.lua"), "@kanto_gear/features/gen1_gifts.lua"))()
  Area.gift1Data = nil
  displayRuntime.Habitats = assert(load(mod:read("models/habitats.lua"),
    "@kanto_gear/models/habitats.lua"))()
  assert(load(mod:read("ui/features/achievements.lua"), "@kanto_gear/ui/features/achievements.lua"))()(
    THEME.hgss, render.G, function(value) return THEME:translate(value) end,
    function(value, ...) return THEME:format(value, ...) end)
  displayRuntime.Daycare = assert(load(mod:read("features/daycare.lua"), "@kanto_gear/features/daycare.lua"))()
  displayRuntime.Calendar = assert(load(mod:read("features/calendar.lua"), "@kanto_gear/features/calendar.lua"))()
  assert(load(mod:read("ui/features/calendar.lua"), "@kanto_gear/ui/features/calendar.lua"))()(
    THEME.hgss, render.G, function(value) return THEME:translate(value) end,
    function(value, ...) return THEME:format(value, ...) end)
  assert(load(mod:read("ui/features/daycare.lua"), "@kanto_gear/ui/features/daycare.lua"))()(
    THEME.hgss, render.G, function(value) return THEME:translate(value) end,
    function(value, ...) return THEME:format(value, ...) end)
  displayRuntime.Notes = assert(load(mod:read("features/notes.lua"), "@kanto_gear/features/notes.lua"))()
  displayRuntime.Pss = assert(load(mod:read("features/pss.lua"), "@kanto_gear/features/pss.lua"))()
  assert(load(mod:read("ui/features/pss.lua"), "@kanto_gear/ui/features/pss.lua"))()(
    THEME.hgss, render.G, function(value) return THEME:translate(value) end,
    function(value, ...) return THEME:format(value, ...) end)
  assert(load(mod:read("ui/features/notes.lua"), "@kanto_gear/ui/features/notes.lua"))()(
    THEME.hgss, render.G, function(value) return THEME:translate(value) end)
  displayRuntime.achievements = { view = "goals", page = 1, stale = true }
  function displayRuntime.resetAchievements()
    local image = displayRuntime.achievements.locationImage
    if image and image.release then image:release() end
    local renderer = displayRuntime.achievements.locationRenderer
    if renderer then renderer:release() end
    displayRuntime.achievements = { view = "goals", page = 1, stale = true }
  end
  displayRuntime.homeCatalog = {
    packages = {
      explorer = { installed = true, fixed = true },
      map = { installed = true, fixed = true },
      party = { installed = true, fixed = true },
      trainer = { installed = true, fixed = true },
      steps = { installed = true, defaultInstalled = true },
      tools = { installed = true, defaultInstalled = true },
      store = { installed = true, fixed = true },
      settings = { installed = true, fixed = true },
      bag = { installed = false },
      pokedex = { installed = false },
      achievements = { installed = false },
      notes = { installed = false },
      pss = { installed = false },
      daycare = { installed = false },
      calendar = { installed = false },
    },
    surfaces = {
      explorer_widget = { package = "explorer", kind = "widget",
        widget = "explorer", columns = 7, label = "EXPLORER" },
      party_widget = { package = "party", kind = "widget",
        widget = "party", columns = 5, label = "PARTY" },
      party_team_widget = { package = "party", kind = "widget",
        widget = "team", columns = 12, label = "TEAM VIEW" },
      pokedex_widget = { package = "pokedex", kind = "widget",
        widget = "pokedex", columns = 5, label = "POKEDEX" },
      trainer_widget = { package = "trainer", kind = "widget",
        widget = "trainer", columns = 5, label = "TRAINER" },
      map_widget = { package = "map", kind = "widget",
        widget = "map", columns = 7, label = "MAP" },
      bag_widget = { package = "bag", kind = "widget",
        widget = "bag", columns = 5, label = "BAG" },
      store_widget = { package = "store", kind = "widget",
        widget = "store", columns = 5, label = "STORE" },
      explorer_app = { package = "explorer", kind = "app", columns = 3,
        icon = "explorer", accent = "green", label = "EXPLORER" },
      map_app = { package = "map", kind = "app", columns = 3,
        icon = "map", accent = "blue", label = "MAP" },
      party_app = { package = "party", kind = "app", columns = 3,
        icon = "party", accent = "green", label = "PARTY" },
      trainer_app = { package = "trainer", kind = "app", columns = 3,
        icon = "trainer", accent = "blue", label = "TRAINER" },
      steps_widget = { package = "steps", kind = "widget",
        widget = "steps", columns = 5, label = "STEPS" },
      steps_app = { package = "steps", kind = "app", columns = 3,
        icon = "steps", accent = "green", label = "STEPS" },
      tools_app = { package = "tools", kind = "app", columns = 3,
        icon = "tools", accent = "green", label = "TOOLS" },
      store_app = { package = "store", kind = "app", columns = 3,
        icon = "store", accent = "green", label = "STORE" },
      bag_app = { package = "bag", kind = "app", columns = 3,
        icon = "bag", accent = "amber", label = "BAG" },
      pokedex_app = { package = "pokedex", kind = "app", columns = 3,
        icon = "pokedex", accent = "red", label = "POKEDEX" },
      achievements_widget = { package = "achievements", kind = "widget",
        widget = "achievements", columns = 12, label = "STAMPS" },
      achievements_app = { package = "achievements", kind = "app", columns = 3,
        icon = "achievements", accent = "amber", label = "STAMPS" },
      notes_app = { package = "notes", kind = "app", columns = 3,
        icon = "notes", accent = "amber", label = "NOTES" },
      pss_app = { package = "pss", kind = "app", columns = 3,
        icon = "pss", accent = "blue", label = "SILPH CONNECT" },
      pss_widget = { package = "pss", kind = "widget", columns = 12,
        widget = "pss", label = "SILPH CONNECT" },
      settings_app = { package = "settings", kind = "app", columns = 3,
        icon = "settings", accent = "blue", label = "OPTIONS" },
      daycare_widget = { package = "daycare", kind = "widget",
        widget = "daycare", columns = 12, label = "DAY-CARE" },
      daycare_small_widget = { package = "daycare", kind = "widget",
        widget = "daycare_small", columns = 5, label = "EGGS" },
      daycare_app = { package = "daycare", kind = "app", columns = 3,
        icon = "daycare", accent = "red", label = "DAY-CARE" },
      calendar_widget = { package = "calendar", kind = "widget",
        widget = "calendar", columns = 12, label = "CALENDAR" },
      calendar_small_widget = { package = "calendar", kind = "widget",
        widget = "calendar_small", columns = 5, label = "TODAY" },
      calendar_app = { package = "calendar", kind = "app", columns = 3,
        icon = "calendar", accent = "blue", label = "CALENDAR" },
    },
  }
  for _, def in ipairs(THEME.fieldTools.widgets) do
    displayRuntime.homeCatalog.surfaces["tool_widget_" .. def.key] = {
      package = "tools", kind = "widget", widget = "tool", columns = 3,
      label = def.key:upper():gsub("_", " "), icon = def.icon,
      actionId = def.action, rodId = def.rod, toolKey = def.key,
      hidden = true, ready = false,
    }
  end
  displayRuntime.storeCatalog = {
    { id = "pss", icon = "pss", label = "SILPH CONNECT",
      category = "ONLINE", target = "PSS", featured = true,
      description = { "ONLINE PLAYER DISPLAY.",
        "SEE WHO IS ONLINE AND PLAYING.", "INVITES REQUIRE RECOMP SUPPORT." } },
    { id = "notes", icon = "notes", label = "NOTES",
      category = "TRAINER TOOL", target = "NOTES", featured = true,
      description = { "PLAN ROUTES AND REMINDERS.",
        "WRITE, CHECK TASKS AND DRAW.", "KEEP CLUES CLOSE AT HAND." } },
    { id = "daycare", icon = "daycare", label = "DAY-CARE",
      category = "BREEDING", target = "DAYCARE",
      description = { "SEE WHO IS AT THE DAY-CARE.",
        "LEVELS, FEES AND MOVES AT PICKUP.", "TRACK THE NEXT EGG AND HATCHING." } },
    { id = "calendar", icon = "calendar", label = "CALENDAR",
      category = "SCHEDULE", target = "CALENDAR",
      description = { "WEEKDAY VISITORS AND EVENTS.",
        "REMATCHES, GIFTS AND BERRIES.", "WHAT YOU CAN DO TODAY." } },
    { id = "achievements", icon = "achievements", label = "ACHIEVEMENTS",
      category = "ADVENTURE", target = "ACHIEVEMENTS",
      description = { "COLLECT STAMPS FOR YOUR JOURNEY.",
        "REVISIT AREAS AND FINISH EXPLORING.", "BONUSES DO NOT BLOCK GOLD." } },
    { id = "explorer", icon = "explorer", label = "EXPLORER",
      category = "ADVENTURE", target = "LOCAL", fixed = true,
      description = { "EXPLORE THE AREA AROUND YOU.",
        "FIND POKEMON, ITEMS AND TRAINERS.", "YOUR ROUTE, IN ONE PLACE." } },
    { id = "map", icon = "map", label = "MAP",
      category = "NAVIGATION", reason = "REGION MAP",
      target = "MAP", fixed = true,
      description = { "VIEW THE REGION MAP.",
        "SEE WHERE YOUR JOURNEY HAS LED.", "YOUR POSITION, AT A GLANCE." } },
    { id = "party", icon = "party", label = "PARTY",
      category = "TEAM", reason = "TEAM STATUS",
      target = "PARTY", fixed = true,
      description = { "CHECK YOUR TEAM AT A GLANCE.",
        "VIEW STATS, MOVES AND STATUS.", "KEEP EVERY PARTNER READY." } },
    { id = "pokedex", icon = "pokedex", label = "POKEDEX",
      category = "RESEARCH", reason = "DEX RESEARCH", target = "POKEDEX",
      description = { "RESEARCH EVERY SPECIES.",
        "CHECK STATS, MOVES AND HABITATS.", "YOUR FIELD ENCYCLOPEDIA." } },
    { id = "bag", icon = "bag", label = "BAG",
      category = "ITEMS", reason = "ITEM POCKETS", target = "BAG",
      description = { "BROWSE EVERY ITEM BELOW.",
        "USE THE ORIGINAL GAME EFFECTS.", "NO MIRRORED BAG REQUIRED." } },
    { id = "trainer", icon = "trainer", label = "TRAINER CARD",
      category = "PROFILE", target = "TRAINER", fixed = true,
      description = { "REVIEW YOUR TRAINER JOURNEY.",
        "BADGES, PLAY TIME AND PROGRESS.", "YOUR ADVENTURE, AT A GLANCE." } },
    { id = "steps", icon = "steps", label = "STEP COUNTER",
      category = "TRAINER TOOL", target = "STEPS",
      description = { "COUNT EVERY STEP OF YOUR JOURNEY.",
        "KEEP THE TOTAL ON YOUR HOME SCREEN.", "ONE SMALL STEP AT A TIME." } },
    { id = "tools", icon = "tools", label = "TOOLS",
      category = "FIELD KIT", target = "TOOLS",
      description = { "USE FIELD MOVES AND GEAR.",
        "KEEP UNLOCKED TOOLS CLOSE.", "READY WHEN THE ROUTE NEEDS IT." } },
  }
  displayRuntime.storeById = {}
  for _, app in ipairs(displayRuntime.storeCatalog) do
    displayRuntime.storeById[app.id] = app
  end
  displayRuntime.home = {
    page = 1, storeView = "apps", storePages = {}, libraryKind = "app",
  }
  displayRuntime.settings = { page = 1 }
  displayRuntime.settingsCategories = {
    { id = "appearance", label = "APPEARANCE",
      detail = "LANGUAGE, THEME AND CLOCK",
      accent = "blue", keys = {
        "language", "theme_v3", "clock_source", "clock_format", "map_motion", "ui_motion" } },
    { id = "display", label = "DISPLAY", detail = "SCREENS AND LAYOUT",
      accent = "green", keys = { "display_mode", "fullscreen_start",
        "combined_layout", "combined_primary", "secondary_size",
        "bottom_safe_area", "overlay_corner", "overlay_button",
        "display_target", "screen_swap" } },
    { id = "battle", label = "BATTLE", detail = "BATTLE VIEW AND CONTROLS",
      accent = "red", keys = { "battle_view", "auto_battle_screen", "caught_icon" } },
    { id = "research", label = "DISCOVERY", detail = "CHOOSE WHAT GEAR REVEALS",
      accent = "amber", keys = { "info_level", "discovery_section" } },
    { id = "controls", label = "CONTROLS", detail = "OPTIONAL SHORTCUTS",
      accent = "blue", keys = { "ui_haptics", "keyboard_layout" } },
    { id = "system", label = "SYSTEM", detail = "HELP AND RESET",
      accent = "green", actions = { "home_help", "reset_home", "reset_options" } },
  }
  for _, row in ipairs(Discovery.options) do
    table.insert(displayRuntime.settingsCategories[4].keys, Discovery.key(row[1]))
  end
  displayRuntime.defaultHomeTiles = {
    { id = "explorer_widget", page = 1, column = 1, row = 1 },
    { id = "party_widget", page = 1, column = 8, row = 1 },
    { id = "map_app", page = 1, column = 1, row = 2 },
    { id = "tools_app", page = 1, column = 4, row = 2 },
    { id = "store_app", page = 1, column = 7, row = 2 },
    { id = "settings_app", page = 1, column = 10, row = 2 },
  }

  function displayRuntime.optionRow(key)
    for _, row in ipairs(THEME.optionSchema or {}) do
      if row.key == key then return row end
    end
  end

  function displayRuntime.optionVisible(row)
    if row and row.discoveryGroup and row.discoveryGroup ~= mod.options:get("discovery_section") then return false end
    if row and row.key == "ui_motion" and mod.options:get("map_motion") == "performance" then return false end
    if row and (row.key == "overlay_corner" or row.key == "overlay_button")
        and mod.options:get("combined_layout") ~= "overlay" then return false end
    local condition = row and row.visible_if
    if not condition then return true end
    local value = mod.options:get(condition.key)
    if condition.equals ~= nil then return value == condition.equals end
    if condition.not_equals ~= nil then return value ~= condition.not_equals end
    if condition.one_of then
      for _, candidate in ipairs(condition.one_of) do
        if value == candidate then return true end
      end
      return false
    end
    if condition.not_one_of then
      for _, candidate in ipairs(condition.not_one_of) do
        if value == candidate then return false end
      end
      return true
    end
    return true
  end

  function displayRuntime.optionChoices(row)
    if row and row.key == "theme_v3" then
      return { { "POKEGEAR LIGHT", "hgss" }, { "POKEGEAR DARK", "hgss_dark" },
        { "POKEGEAR AUTO", "hgss_auto" }, { "C-GEAR LIGHT", "cgear" },
        { "C-GEAR DARK", "cgear_dark" }, { "C-GEAR AUTO", "cgear_auto" } }
    end
    return row and row.choices or {}
  end

  function displayRuntime.optionValueLabel(row)
    local value = mod.options:get(row.key)
    if row.type == "toggle" then return value == true and "ON" or "OFF" end
    for _, choice in ipairs(displayRuntime.optionChoices(row)) do
      if choice[2] == value then return choice[1] end
    end
    return tostring(value or row.default or "--"):upper()
  end

  function displayRuntime.settingsModel()
    local state = displayRuntime.settings
    if state.option then
      local row = displayRuntime.optionRow(state.option)
      if not row and SettingsInfo.help[state.option] then
        row = { key = state.option, type = "action", label = state.option == "home_help" and "CUSTOMIZE HOME"
          or state.option == "reset_home" and "RESET HOME" or "RESET OPTIONS" }
      end
      if row and displayRuntime.optionVisible(row) then
        local choices = row.type == "action" and {
          { row.key == "home_help" and "SHOW ME" or state.confirm == row.key and "TAP AGAIN" or "RESET", true } }
          or row.type == "toggle" and { { "OFF", false }, { "ON", true } }
          or displayRuntime.optionChoices(row)
        local perPage = row.key == "theme_v3" and 3 or 4
        local pages = math.max(1, math.ceil(#choices / perPage))
        state.choicePage = math.max(1, math.min(pages, state.choicePage or 1))
        return { category = "option", option = row.key, label = row.label,
          accent = displayRuntime.settingsCategories[state.category].accent,
          description = SettingsInfo.description(row.key, mod.options:get(row.key)),
          choices = choices, value = mod.options:get(row.key), source = row,
          page = state.choicePage, pages = pages, perPage = perPage }
      end
      state.option = nil
    end
    local tabs = THEME.style == "hgss" and THEME.hgss.v4SettingsTabs == true
    if not state.category and tabs then state.category = 1 end
    if not state.category then
      return { categories = displayRuntime.settingsCategories }
    end
    local category = displayRuntime.settingsCategories[state.category]
    local rows = {}
    for _, key in ipairs(category.keys or {}) do
      local row = displayRuntime.optionRow(key)
      if row and displayRuntime.optionVisible(row) then
        rows[#rows + 1] = { key = key, label = row.label,
          value = displayRuntime.optionValueLabel(row), source = row,
          raw = mod.options:get(key),
          choices = row.type == "toggle" and { { "OFF", false }, { "ON", true } }
            or displayRuntime.optionChoices(row),
          enabled = type(mod.options.set) == "function", description = SettingsInfo.help[key],
          info = SettingsInfo.description(key, mod.options:get(key)) }
      end
    end
    for _, action in ipairs(category.actions or {}) do
      rows[#rows + 1] = { action = action,
        label = action == "home_help" and "CUSTOMIZE HOME"
          or action == "reset_home" and "RESET HOME" or "RESET OPTIONS",
        description = SettingsInfo.help[action],
        value = action == "home_help" and "SHOW ME"
          or state.confirm == action and "TAP AGAIN" or "RESET" }
    end
    local pages = math.max(1, math.ceil(#rows / 4))
    state.page = math.max(1, math.min(pages, state.page or 1))
    local detail = category.detail
    if state.category == 4 and mod.options:get("info_level") == "custom" then
      for _, group in ipairs(Discovery.groups) do
        if group[2] == mod.options:get("discovery_section") then detail = group[1]; break end
      end
    end
    return { category = category.id, label = state.category == 4 and mod.options:get("info_level") == "custom" and detail or category.label, detail = detail,
      accent = category.accent, rows = rows, page = state.page, pages = pages,
      tabs = tabs and displayRuntime.settingsCategories or nil, tab = state.category,
      selected = state.selected, confirm = state.confirm }
  end

  function displayRuntime.cycleSettingsPage(direction)
    displayRuntime.requestPageMotion(direction)
    local state, model = displayRuntime.settings, displayRuntime.settingsModel()
    if not model.category or model.pages <= 1 then return false end
    if model.option then state.choicePage = ((state.choicePage - 1 + direction) % model.pages) + 1
    else state.page = ((state.page - 1 + direction) % model.pages) + 1 end
    state.confirm, session.dirty = nil, true
    return true
  end

  function displayRuntime.cycleSetting(row, direction)
    if not (row and row.source and mod.options.set) then return false end
    local source, value = row.source, mod.options:get(row.key)
    if source.type == "toggle" then
      return mod.options:set(row.key, value ~= true)
    end
    local choices = displayRuntime.optionChoices(source)
    for index, choice in ipairs(choices) do
      if choice[2] == value then
        return mod.options:set(row.key,
          choices[((index - 1 + direction) % #choices) + 1][2])
      end
    end
    return choices[1] and mod.options:set(row.key, choices[1][2]) or false
  end

  function displayRuntime.resetHome()
    for _, package in pairs(displayRuntime.homeCatalog.packages) do
      package.installed = package.fixed == true or package.defaultInstalled == true
    end
    local layout = { tiles = {} }
    for _, tile in ipairs(displayRuntime.defaultHomeTiles) do
      displayRuntime.Home.place(layout, displayRuntime.homeCatalog,
        tile.id, tile.page, tile.column, tile.row)
    end
    displayRuntime.Home.compactRows(layout, displayRuntime.homeCatalog)
    displayRuntime.home.layout, displayRuntime.home.page = layout, 1
    displayRuntime.saveHome()
  end

  function displayRuntime.runSettingsAction(action)
    local state = displayRuntime.settings
    if action == "home_help" then
      state.confirm = nil
      displayRuntime.showHomeHelp()
      return
    end
    if state.confirm ~= action then state.confirm, session.dirty = action, true; return end
    state.confirm = nil
    if action == "reset_home" then
      displayRuntime.resetHome()
      displayRuntime.haptic("confirm")
    elseif action == "reset_options" and mod.options.set then
      displayRuntime.haptic("confirm")
      for _, row in ipairs(THEME.optionSchema or {}) do
        local value = row.reset_default
        if value == nil then value = row.default end
        mod.options:set(row.key, value)
      end
    end
    session.dirty = true
  end

  local PaletteFX = require("src.render.PaletteFX")
  local PokemonSprites = require("src.pokemon.Sprites")
  local EngineFont = mod.ui.Font

  session.canvas = render.G.newCanvas(WIDTH, HEIGHT, { dpiscale = 1 })
  session.canvas:setFilter("nearest", "nearest")
  session.game = nil
  function displayRuntime.lastBagItem()
    local id = displayRuntime.recentItem:available(session.game and session.game.save)
    if not id then return end
    local def = session.game.data and session.game.data.items and session.game.data.items[id] or {}
    return { id = id, label = def.name or tostring(id):gsub("_", " "),
      count = session.game.save.inventory[id], icon = displayRuntime.bagItemKind(id, def),
      itemSprite = displayRuntime.gen3 and displayRuntime.gen3:itemIcon(id) }
  end

  session.companion = nil
  session.active = false
  session.dirty = true
  session.readbackPending = false
  session.gameReadbackPending = false
  session.gameReadbackCanvas = nil
  session.gameCaptureCanvas = nil
  session.nextGameCapture = 0
  session.primaryBottomRect = nil
  THEME.nativeWindowLayout = nil
  session.page = "MAP"
  session.trainerStepsOpen = false
  session.localMapZoom = 1
  session.guidePage = 1
  session.areaPage = 1
  session.radarOpen = false
  session.radarFrame = 0
  session.radarStarted = 0
  session.tools = {}
  session.toolsKey = ""
  session.steps = 0
  session.mapId = nil
  session.mapAsset = nil
  session.localMap = nil
  session.localMapImage = nil
  session.spriteCache = {}
  displayRuntime.spriteFilter = assert(load(mod:read("core/sprite_filter.lua"),
    "@kanto_gear/core/sprite_filter.lua"))().new(render.G)
  session.touchDown = nil
  session.textSpeedToken = nil
  session.textSpeedReleasePending = false
  session.battle = nil
  session.moveInfo = nil
  session.battleInfoDetail = nil
  session.intentId = 0
  session.nextPoll = 0
  session.nextClock = 0
  session.batteryAnimated = false
  session.lastScreenKey = nil
  session.worldStarted = false
  session.externalLoading = false
  session.pendingFly = nil
  session.pendingAction = nil
  session.fieldChoice = nil
  session.partyMoveFrom = nil
  session.partyActionSlot = nil
  local hgssRuntime = {}
  displayRuntime.motion = { duration = 0.16 }
  displayRuntime.stepRefreshDelay = 0.4
  displayRuntime.mapRefresh = { nextAt = 0 }
  assert(1.39 - 1 < displayRuntime.stepRefreshDelay
      and 1.41 - 1 >= displayRuntime.stepRefreshDelay,
    "step-driven companion updates wait for movement to settle")
  session.choiceTop = nil
  session.choiceReadyAt = 0
  session.choiceNudgeUntil = 0
  session.choiceCommitted = nil
  session.loggedTick = false
  session.loggedPresent = false
  session.bridgeWarned = false
  session.displayReady = false
  session.nextPresentAttempt = 0
  session.themeKey = nil

  return EngineFont, PaletteFX, PokemonSprites, assist, bottomBattleHud, bottomOnHandheld, compat, currentBattleUIMode, customBattleLayout, displayPreference, displayRuntime, fullBottomBattleUI, hgssRuntime, inlineDisplay
end
