package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local newCanvas = T.love.graphics.newCanvas
local rectangle = T.love.graphics.rectangle
local getTime = T.love.timer.getTime
local now = 0
local rectangles = {}
T.love.timer.getTime = function() return now end
T.love.graphics.rectangle = function(...)
  rectangles[#rectangles + 1] = { ... }
  return rectangle(...)
end
T.love.graphics.newCanvas = function(...)
  local canvas = newCanvas(...)
  function canvas:requestImageData() return true end
  function canvas:pollImageData() return {} end
  return canvas
end
local run = T.sdk.loadMod(path, {
  generation = 2,
  data = T.fixtures.load(),
})
T.love.system.getPowerInfo = function() return "battery", 80 end

T.eq(run.mod and run.mod.state, "loaded",
  "Kanto Gear manifest and entry load for Gen 2")
T.eq(#run.errors, 0, "Kanto Gear has no Gen 2 boot errors")

run.data.gen2Landmarks = { landmarks = {
  LANDMARK_FIX_ROUTE = { index = 2, name = "FIX ROUTE", x = 40, y = 56 },
} }
run.data.gen2Maps = { FIX_ROUTE = {
  landmark = 2,
  fishGroup = "FISHGROUP_POND",
  objects = {
    { eventFlag = 12, itemball = { item = 1 } },
    { trainer = { class = 3, member = 1, event = 11 } },
  },
  bgEvents = { { x = 3, y = 4,
    hiddenItem = { item = 1, event = 13 } } },
} }
run.data.gen2Trainers = { classes = { YOUNGSTER = {
  index = 3, name = "YOUNGSTER",
  trainers = { { name = "JOEY" } },
} } }
run.data.gen2Encounters = { grass = { FIX_ROUTE = { slots = {
  MORN = { { species = "FIXMON_A", level = 2 } },
  DAY = { { species = "FIXMON_A", level = 3 } },
  NITE = { { species = "FIXMON_B", level = 4 } },
} } }, water = {}, fishGroups = { FISHGROUP_POND = {
  old = {
    { chance = 179, species = "FIXMON_A", level = 10 },
    { chance = 255, species = "FIXMON_B", level = 10 },
  },
  good = {
    { chance = 255, species = 0, level = 1, timeGroup = 1 },
  },
  super = {
    { chance = 255, species = "FIXMON_B", level = 20 },
  },
} }, timeFishGroups = { [1] = {
  day = { species = "FIXMON_A", level = 20 },
  nite = { species = "FIXMON_B", level = 20 },
} } }
local johtoMap = {}
for i = 1, 20 * 18 do johtoMap[i] = 0 end
local mapColors = {
  { 255, 255, 255 }, { 104, 208, 88 }, { 32, 120, 64 }, { 0, 0, 0 },
}
run.data.gen2MenuGfx = { pokegear = {
  tiles = "gold-map.png", tilesWide = 1,
  maps = { johto = johtoMap, kanto = johtoMap },
  palettes = { mapColors }, palMap = { [1] = 1 },
} }
run.data.gen2Sprites = { SPRITE_CHRIS = {
  image = "gold-player.png", frames = 1, trueColor = true, paletteId = 0,
} }
local playerColors = {
  { 255, 255, 255 }, { 248, 80, 56 }, { 200, 32, 24 }, { 0, 0, 0 },
}
run.data.gen2Palettes = { objects = { DAY = { playerColors } } }

local game = {
  data = run.data,
  save = {
    generation = 2,
    version = "silver",
    player = {
      name = "SILVER", id = 25, money = 1234, map = "FIX_ROUTE",
      badges = { ZEPHYR = true }, kantoBadges = {},
    },
    party = { {
      species = "FIXMON_A", nickname = "CYNDA", level = 5,
      hp = 20, stats = { hp = 20 }, exp = 0,
    } },
    pokedex = { seen = { FIXMON_A = true }, caught = { FIXMON_A = true } },
    playTime = { hours = 1, minutes = 2, seconds = 3 },
    inventory = {}, boxes = {}, currentBox = 1,
  },
  world = {
    map = { id = "FIX_ROUTE" },
    player = { cellX = 2, cellY = 3, facing = "down" },
    daytime = "DAY",
    acceptsMenuInput = function() return false end,
  },
  stack = { states = {}, top = function(self)
    return self.states[#self.states]
  end },
}
run.loader.events:emit("game.ready", { game = game })
run.loader.modOptions.kanto_gear = { theme_v3 = "kanto", trigger_tabs = true }
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "theme_v3", value = "kanto" })
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "trigger_tabs" })

do
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
  local guideData = upvalue(upvalue(upvalue(inputHook,
    "pollTriggerTabs"), "changePage"), "guideData")
  T.check(guideData ~= nil, "Guide data remains reachable from navigation")

  local changePage = upvalue(upvalue(inputHook, "pollTriggerTabs"),
    "changePage")
  local displayRuntime = upvalue(changePage, "displayRuntime")
  local dex = displayRuntime.pokedexData()
  T.check(dex.bySpecies.FIXMON_A
      and dex.bySpecies.FIXMON_A.habitat
      and #dex.bySpecies.FIXMON_A.habitat.appearances > 0,
    "Pokedex reuses the full Gen 2 encounter source for habitats")

  local guide = guideData()
  local fish = {}
  for _, row in ipairs(guide.rows) do fish[row.species] = row end
  local function method(row, name)
    if not row then return nil end
    for _, entry in ipairs(row.currentMethods) do
      if entry.name == name then return entry end
    end
  end
  T.check(method(fish.FIXMON_A, "GOOD") ~= nil,
    "Gen 2 Guide includes the current daytime fishing table")
  T.eq(method(fish.FIXMON_A, "OLD").min, 70,
    "Gen 2 Guide derives Old Rod odds from cumulative slots")
  T.check(method(fish.FIXMON_B, "OLD") ~= nil,
    "Gen 2 Guide includes every species in a fishing group")
  T.check(method(fish.FIXMON_B, "SUPER") ~= nil,
    "Gen 2 Guide includes all three rod tables")

  local encounters = run.data.gen2Encounters
  encounters.swarmGrass = { FIX_ROUTE = { slots = {
    MORN = {}, DAY = {}, NITE = {},
  } } }
  for _, time in ipairs({ "MORN", "DAY", "NITE" }) do
    local slots = encounters.swarmGrass.FIX_ROUTE.slots[time]
    for _ = 1, 7 do
      slots[#slots + 1] = { species = "FIXMON_B", level = 8 }
    end
  end
  encounters.fishGroups.FISHGROUP_QWILFISH = {
    old = { { chance = 255, species = "FIXMON_A", level = 10 } },
    good = {}, super = {},
  }
  encounters.fishGroups.FISHGROUP_QWILFISH_SWARM = {
    old = { { chance = 255, species = "FIXMON_B", level = 10 } },
    good = {}, super = {},
  }
  run.data.gen2Maps.FIX_ROUTE.fishGroup = "FISHGROUP_QWILFISH"
  game.save.dailyFlags = { swarm = true, fishingSwarm = 1 }
  game.save.swarmMap = "FIX_ROUTE"
  guide = guideData()
  fish = {}
  for _, row in ipairs(guide.rows) do fish[row.species] = row end
  T.check(method(fish.FIXMON_B, "WALK") ~= nil
      and method(fish.FIXMON_A, "WALK") == nil,
    "Guide replaces ordinary grass with the active swarm table")
  T.check(method(fish.FIXMON_B, "OLD") ~= nil
      and method(fish.FIXMON_A, "OLD") == nil,
    "Guide uses the active fishing swarm group")

  game.save.dailyFlags, game.save.swarmMap = nil, nil
  run.data.gen2Maps.FIX_ROUTE.fishGroup = "FISHGROUP_POND"
  encounters.trees = { FIX_ROUTE = "TREE_SET" }
  encounters.rocks = { FIX_ROUTE = "ROCK_SET" }
  encounters.treeSets = {
    TREE_SET = {
      common = {
        { chance = 80, species = "FIXMON_A", level = 6 },
        { chance = 20, species = "FIXMON_B", level = 7 },
      },
      rare = { { chance = 100, species = "FIXMON_B", level = 9 } },
    },
    ROCK_SET = {
      common = {
        { chance = 90, species = "FIXMON_B", level = 12 },
        { chance = 10, species = "FIXMON_A", level = 12 },
      },
      rare = {},
    },
  }
  game.save.roamers = {
    { species = "REMOTE", map = "FIX_ROUTE", level = 40 },
  }
  guide = guideData()
  fish = {}
  for _, row in ipairs(guide.rows) do fish[row.species] = row end
  T.eq(method(fish.FIXMON_A, "HEADBUTT").min, 80,
    "Guide includes common Headbutt trees")
  T.eq(method(fish.FIXMON_B, "RARE TREE").min, 100,
    "Guide distinguishes rare Headbutt trees")
  T.eq(method(fish.FIXMON_B, "ROCK SMASH").min, 90,
    "Guide includes Rock Smash encounters")
  T.eq(method(fish.REMOTE, "ROAMING").min, 10,
    "Guide reports an active roamer on its current map")

  encounters.bugContest = {
    { chance = 60, species = "FIXMON_A", min = 7, max = 18 },
    { chance = 40, species = "FIXMON_B", min = 9, max = 14 },
    { chance = 255, species = "REMOTE", min = 30, max = 40 },
  }
  game.save.bugContest = { active = true }
  guide = guideData()
  fish = {}
  for _, row in ipairs(guide.rows) do fish[row.species] = row end
  T.check(method(fish.FIXMON_A, "CONTEST") ~= nil
      and method(fish.FIXMON_A, "WALK") == nil,
    "an active Bug Contest replaces the ordinary walking table")
  local contestAppearance
  for _, appearance in ipairs(fish.FIXMON_A.appearances) do
    if appearance.method == "CONTEST" then contestAppearance = appearance end
  end
  T.check(contestAppearance and contestAppearance.minLevel == 7
      and contestAppearance.maxLevel == 18,
    "Guide preserves Bug Contest level ranges")
  T.check(fish.REMOTE and method(fish.REMOTE, "CONTEST") == nil,
    "the unreachable Bug Contest fallback row stays hidden")
  game.save.bugContest, game.save.roamers = nil, nil

  local landmarks, maps, savedEncounters = run.data.gen2Landmarks,
    run.data.gen2Maps, run.data.gen2Encounters
  run.data.gen2Landmarks = { landmarks = { DARK_CAVE = {
    index = 9, name = "DARK CAVE", x = 20, y = 20,
  } } }
  run.data.gen2Maps = {
    DARK_CAVE_BLACKTHORN_ENTRANCE = { landmark = 9 },
    DARK_CAVE_VIOLET_ENTRANCE = { landmark = 9 },
  }
  local other = { species = "FIXMON_A", level = 4 }
  local wob = { species = "FIXMON_B", level = 5 }
  local remote = { species = "REMOTE", level = 6 }
  run.data.gen2Encounters = { grass = {
    DARK_CAVE_BLACKTHORN_ENTRANCE = { slots = {
      MORN = { other, other, other, wob, wob, other, other },
      DAY = { other, other, other, wob, wob, other, other },
      NITE = { other, other, other, wob, wob, other, other },
    } },
    DARK_CAVE_VIOLET_ENTRANCE = { slots = {
      MORN = { wob, other, other, other, other, other, other },
      DAY = { other, other, other, other, other, other, remote },
      NITE = { wob, other, other, other, other, other, other },
    } },
  }, water = {} }
  game.world.daytime = "DAY"
  run.loader.events:emit("map.entered",
    { mapId = "DARK_CAVE_BLACKTHORN_ENTRANCE" })
  guide = guideData()
  local wobbuffet, remoteOnly
  for _, row in ipairs(guide.rows) do
    if row.species == "FIXMON_B" then wobbuffet = row end
    if row.species == "REMOTE" then remoteOnly = row end
  end
  T.eq(wobbuffet.availability, "now",
    "current Dark Cave section is available now")
  T.eq(wobbuffet.currentMethods[1].min, 15,
    "Guide uses Gold's 10% + 5% weighted Wobbuffet slots")
  T.eq(guide.section, "BLACKTHORN ENTRANCE",
    "Guide exposes the current internal map section")
  T.eq(wobbuffet.appearances[1].section, "BLACKTHORN ENTRANCE",
    "encounter details name the current section instead of only saying here")
  T.eq(remoteOnly.availability, "area",
    "encounters from another internal section stay visible but unavailable")

  run.loader.events:emit("map.entered", { mapId = "DARK_CAVE_VIOLET_ENTRANCE" })
  guide = guideData()
  for _, row in ipairs(guide.rows) do
    if row.species == "FIXMON_B" then wobbuffet = row end
  end
  T.eq(wobbuffet.availability, "time",
    "same section at another time is distinguished from another area")
  T.eq(#wobbuffet.currentMethods, 0,
    "unavailable current-time encounters do not show a misleading rate")

  run.data.gen2Landmarks, run.data.gen2Maps, run.data.gen2Encounters =
    landmarks, maps, savedEncounters
  game.world.daytime = "DAY"
  run.loader.events:emit("map.entered", { mapId = "FIX_ROUTE" })
end

local trigger = 0
T.love.joystick = { getJoysticks = function()
  return { {
    isGamepadDown = function() return false end,
    getGamepadAxis = function(_, axis)
      return axis == "triggerright" and trigger or 0
    end,
  } }
end }
local touchEvents = {}
local companion = {
  detected = function() return true end,
  pollTouch = function() return table.remove(touchEvents, 1) end,
  push = function() return true end,
}
do
  local function upvalue(fn, target)
    for index = 1, debug.getinfo(fn, "u").nups do
      local name, value = debug.getupvalue(fn, index)
      if name == target then return value end
    end
  end
  local function setUpvalue(fn, target, value)
    for index = 1, debug.getinfo(fn, "u").nups do
      if debug.getupvalue(fn, index) == target then
        debug.setupvalue(fn, index, value)
        return true
      end
    end
  end
  local inputHook
  for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
    if entry.owner == "kanto_gear" then inputHook = entry.callback end
  end
  local changePage = upvalue(upvalue(inputHook, "pollTriggerTabs"),
    "changePage")

  local composeHook
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"] or {}) do
    if entry.owner == "kanto_gear" then composeHook = entry.callback end
  end
  local touchEvent = upvalue(composeHook, "touchEvent")
  local tap = upvalue(touchEvent, "tap")
  local displayRuntime = upvalue(changePage, "displayRuntime")
  local guideData = upvalue(changePage, "guideData")
  T.check(setUpvalue(changePage, "page", "GUIDE"),
    "Guide regression can select the GUIDE tab")
  T.check(guideData().rows[1].detailPages > 1,
    "Guide regression fixture has multiple detail pages")
  tap(10, 50)
  T.eq(displayRuntime.guideDetail.page, 1,
    "tapping a Guide row opens its first detail page")
  changePage(-1)
  T.eq(displayRuntime.guideDetail.page, 1,
    "swiping back at the first detail boundary keeps a valid page")
  tap(30, 10)
  T.eq(displayRuntime.guideDetail.page, 1,
    "tapping back at the first detail boundary keeps a valid page")
  local lastDetailPage = guideData().rows[1].detailPages
  displayRuntime.guideDetail.page = lastDetailPage
  tap(90, 10)
  T.eq(displayRuntime.guideDetail.page, lastDetailPage,
    "tapping forward at the last detail boundary keeps a valid page")
  displayRuntime.guideDetail = nil
  setUpvalue(changePage, "page", "MAP")
  tap(85, 10)
  T.check(upvalue(changePage, "page") ~= "MAP",
    "the visible top-right page arrow owns its centered touch target")
  setUpvalue(changePage, "page", "MAP")
  tap(100, 10)
  T.eq(upvalue(changePage, "page"), "MAP",
    "the old right-shifted page-arrow target is inactive")

  local pumpDisplay = upvalue(composeHook, "pumpDisplay")
  local draw = upvalue(pumpDisplay, "draw")
  local drawContents = displayRuntime.drawContents
  local push, pop = T.love.graphics.push, T.love.graphics.pop
  local graphicsDepth = 0
  T.love.graphics.push = function(...)
    graphicsDepth = graphicsDepth + 1
    return push(...)
  end
  T.love.graphics.pop = function(...)
    graphicsDepth = graphicsDepth - 1
    return pop(...)
  end
  displayRuntime.drawContents = function() error("expected draw failure") end
  local ok = pcall(draw)
  displayRuntime.drawContents = drawContents
  T.love.graphics.push, T.love.graphics.pop = push, pop
  T.check(not ok, "companion draw failures remain observable")
  T.eq(graphicsDepth, 0,
    "companion draw failures restore the graphics stack")

  local naming = require("src.ui.gen2.NamingScreen").new(game, {
    type = "nickname",
  })
  naming.screenId, naming.text = "Gen2NamingScreen", "AB"
  local screenContract = upvalue(displayRuntime.drawContents, "screenContract")
  local keyboard = screenContract and screenContract(naming, "naming")
  T.eq(keyboard and #keyboard, 5,
    "Gold naming adds CASE, DEL, and END to the mirrored keyboard")
  T.eq(keyboard and keyboard[5][2], "DEL",
    "Gold naming preserves the native delete target")
  T.eq(screenContract({
    screenId = "Gen2NamingScreen", text = "", row = 0, col = 0,
    rows = function() return { { "A" } } end,
  }, "naming"), nil, "foreign Gold naming layouts fall back safely")
  local previousStack = game.stack.states
  game.stack.states = { naming }
  T.check(pcall(displayRuntime.drawContents),
    "Gold naming renders on the companion screen")
  local pressed
  local previousInput = game.input
  game.input = {}
  game.input.sourcePress = function(_, button) pressed = button end
  game.input.sourceRelease = function() end
  tap(30, 40)
  T.eq(naming.row, 0, "Gold naming touch selects the native letter row")
  T.eq(naming.col, 1, "Gold naming touch selects the native letter column")
  T.eq(pressed, "a", "Gold naming touch confirms through native input")
  pressed = nil
  tap(80, 110)
  T.eq(naming.row, 4, "Gold naming touch reaches the native action row")
  T.eq(naming.col, 3, "Gold naming touch selects the native DEL target")
  T.eq(pressed, "a", "Gold naming actions confirm through native input")
  game.input = previousInput
  game.stack.states = previousStack

  for _ = 1, 6 do changePage(1) end

  local previousParty, previousIcons = game.save.party, run.data.gen2Icons
  local egg = { species = "FIXMON_B", nickname = "EGG", isEgg = true }
  game.save.party = { egg }
  run.data.gen2Icons = { species = {}, icons = {
    ICON_EGG = { image = "native-egg.png" },
  } }
  local PokemonSprites = require("src.pokemon.Sprites")
  local iconPath, iconHookCalls = PokemonSprites.iconPath, 0
  PokemonSprites.iconPath = function(...)
    iconHookCalls = iconHookCalls + 1
    return "revealed-hatchling.png"
  end
  local eggDraws = T.record.draw()
  run.loader.hooks:call("render.compose", function() return false end, {}, {
    secondScreen = companion,
  })
  eggDraws:stop()
  PokemonSprites.iconPath = iconPath
  game.save.party, run.data.gen2Icons = previousParty, previousIcons
  for _ = 1, 6 do changePage(-1) end

  T.eq(iconHookCalls, 0, "party eggs bypass species icon replacements")
  T.check(#eggDraws:fromPath("native-egg.png") > 0,
    "party eggs render the native egg icon")
  T.eq(#eggDraws:fromPath("revealed-hatchling.png"), 0,
    "party eggs never reveal the hidden hatchling")
end
local SpriteRenderer = require("src.render.SpriteRenderer")
local GbcPalette = require("src.render.GbcPalette")
local rendererNew = SpriteRenderer.new
local paletteWith = GbcPalette.with
local paletteAvailable = GbcPalette.available
local markerPalette
local mapPaletteUsed = false
SpriteRenderer.new = function(def, seed)
  local renderer = rendererNew(def, seed)
  if seed == "kanto-gear-map" then
    local setObjPalette = renderer.setObjPalette
    renderer.setObjPalette = function(self, colors, group)
      markerPalette = { colors = colors, group = group }
      return setObjPalette(self, colors, group)
    end
  end
  return renderer
end
GbcPalette.with = function(colors, body)
  if colors == mapColors then mapPaletteUsed = true end
  return body()
end
GbcPalette.available = function() return true end
local mapDraws = T.record.draw()
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
SpriteRenderer.new = rendererNew
GbcPalette.with, GbcPalette.available = paletteWith, paletteAvailable
T.check(#mapDraws:fromPath("gold-map.png") > 0,
  "Gold map renders the extracted Pokegear town-map tiles")
T.check(mapPaletteUsed,
  "Gold map applies its extracted per-tile town-map palettes")
local playerMarker = mapDraws:fromPath("gold-player.png")[1]
T.check(playerMarker and playerMarker.args[2] == 44
    and playerMarker.args[3] == 56 and playerMarker.args[5] == 0.75,
  "Gold map uses the native player sprite at the scaled landmark")
T.check(markerPalette and markerPalette.colors == playerColors
    and markerPalette.group == "gen2:DAY:0",
  "Gold map applies the native daytime player palette")
for _ = 1, 10 do
  trigger = 0.8
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  trigger = 0
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  run.loader.hooks:call("render.compose", function() return false end, {}, {
    secondScreen = companion,
  })
  run.loader.hooks:call("render.compose", function() return false end, {}, {
    secondScreen = companion,
  })
end
mapDraws:stop()
T.check(true, "Silver-shaped save and world render every companion tab")
local firstBadge, lastBadge = false, false
for _, call in ipairs(rectangles) do
  local _, x, y, w, h = unpack(call)
  if y == 57 and w == 12 and h == 12 then
    firstBadge = firstBadge or x == 11
    lastBadge = lastBadge or x == 137
  end
end
T.check(firstBadge and lastBadge,
  "Gold badges use smaller icons with equal outer margins")

local enemy = { species = "FIXMON_B", level = 4, hp = 11, maxHp = 12,
  status = "PAR",
  moves = {} }
run.data.gen2Pokedex = { entries = { FIXMON_B = {
  dex = 2, kind = "FLAME", height = 204, weight = 190,
  text = "A small flame stays warm.", text2 = "It glows at night.",
} } }
local battle = { player = game.save.party[1], enemy = enemy,
  party = game.save.party, wild = true, turn = 0 }
function battle:moveDisabled() return false end
local screen = { screenId = "Gen2BattleState", battle = battle,
  phase = "menu", menuIndex = 1, moveIndex = 1,
  shownHp = { player = 19, enemy = 10 } }
game.stack.states = { screen }
run.loader.game = game
now = now + 1
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.check(true, "Gold battle state and direct mon HP shape render safely")

run.loader.modOptions.kanto_gear.battle_view = "gear"
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "battle_view" })
T.eq(run.loader.hooks:call("battle.bottom_ui_visible",
    function() return true end, screen), false,
  "GEAR gives Gold battle text and menus to the companion screen")
T.eq(run.loader.hooks:call("battle.status_hud_visible",
    function() return true end, screen), true,
  "GEAR leaves Gold's native status HUD visible")
do
  local previousInput = game.input
  local previousTheme = run.loader.modOptions.kanto_gear.theme_v3
  local inputHook
  for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
    if entry.owner == "kanto_gear" then inputHook = entry.callback end
  end
  local runtime
  local moveInfoIndex
  for i = 1, debug.getinfo(inputHook, "u").nups do
    local name, value = debug.getupvalue(inputHook, i)
    if name == "hgssRuntime" then runtime = value break end
  end
  for i = 1, debug.getinfo(inputHook, "u").nups do
    local name = debug.getupvalue(inputHook, i)
    if name == "moveInfo" then moveInfoIndex = i break end
  end
  local playerTeam, wildTeam = runtime.battleTeams()
  T.check(type(playerTeam[1]) == "table"
      and playerTeam[1].alive == true,
    "HGSS battle team balls receive live party state")
  T.check(wildTeam.wild and type(wildTeam.name) == "string"
      and wildTeam.name ~= "" and wildTeam.level == 4
      and wildTeam[1].alive == true and wildTeam[1].status == "PAR",
    "HGSS labels a wild opponent without inventing a trainer party")
  local readyUpvalue
  for i = 1, debug.getinfo(runtime.remapBattleRootInput, "u").nups do
    local name = debug.getupvalue(runtime.remapBattleRootInput, i)
    if name == "displayReady" then readyUpvalue = i break end
  end
  T.check(readyUpvalue ~= nil,
    "HGSS battle navigation observes companion readiness")
  run.loader.modOptions.kanto_gear.theme_v3 = "hgss"
  run.loader.events:emit("mod.options_changed",
    { mod = "kanto_gear", key = "theme_v3", value = "hgss" })
  debug.setupvalue(runtime.remapBattleRootInput, readyUpvalue, true)
  screen.menuIndex = 1
  game.input = { pressQueue = { "down" } }
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  T.eq(screen.menuIndex, 4,
    "owned HGSS battle root maps DOWN from FIGHT to RUN")
  game.input.pressQueue = { "right" }
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  T.eq(screen.menuIndex, 2,
    "owned HGSS battle root maps RIGHT from RUN to POKEMON")
  run.loader.modOptions.kanto_gear.battle_view = "standard"
  run.loader.events:emit("mod.options_changed",
    { mod = "kanto_gear", key = "battle_view" })
  screen.menuIndex = 1
  game.input.pressQueue = { "down" }
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  T.eq(screen.menuIndex, 1,
    "STANDARD leaves the native 2x2 battle cursor untouched")
  T.eq(game.input.pressQueue[1], "down",
    "STANDARD leaves native directional input in the queue")
  run.loader.modOptions.kanto_gear.battle_view = "full"
  run.loader.events:emit("mod.options_changed",
    { mod = "kanto_gear", key = "battle_view" })
  screen.menuIndex = 1
  game.input.pressQueue = { "left" }
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  T.eq(screen.menuIndex, 2,
    "FULL GEAR maps LEFT from FIGHT to POKEMON in its two-by-two grid")
  local partyMenu = {
    screenId = "Gen2PartyMenu", index = 1,
    submenu = { index = 3, items = {
      { label = "SWITCH" }, { label = "STATS" }, { label = "CANCEL" },
    } },
  }
  screen.menuIndex = 2
  game.input.pressQueue = { "a" }
  run.loader.hooks:call("input.step", function()
    game.stack.states = { screen, partyMenu }
  end, game, 1 / 60)
  T.eq(runtime.animation and runtime.animation.kind, "battle_party",
    "HGSS starts the party transition in the input frame")
  T.eq(runtime.animation and runtime.animation.started, nil,
    "HGSS preserves the first rendered party transition frame")
  runtime.animation = nil
  screen.menuIndex = 3
  local bagMenu = {
    screenId = "Gen2PackMenu", rows = {}, index = 1,
    pocket = function() return { label = "ITEMS" } end,
  }
  game.stack.states = { screen }
  game.input.pressQueue = { "a" }
  run.loader.hooks:call("input.step", function()
    game.stack.states = { screen, bagMenu }
  end, game, 1 / 60)
  T.eq(runtime.animation and runtime.animation.kind, "battle_bag",
    "HGSS starts the Bag transition in the input frame")
  runtime.animation = nil
  game.input.pressQueue = { "b" }
  local closeStartedBeforeNative
  run.loader.hooks:call("input.step", function()
    closeStartedBeforeNative = runtime.animation
      and runtime.animation.kind == "battle_bag_close"
    game.stack.states = { screen }
  end, game, 1 / 60)
  T.check(closeStartedBeforeNative,
    "HGSS arms the Bag close before the native screen is removed")
  T.eq(runtime.animation and runtime.animation.kind, "battle_bag_close",
    "HGSS starts the Bag close transition in the input frame")
  runtime.animation = nil
  game.stack.states = { screen, partyMenu }
  game.input.pressQueue = { "down" }
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  T.eq(partyMenu.submenu.index, 2,
    "owned HGSS battle party menu maps DOWN to visible STATS")
  T.eq(#game.input.pressQueue, 0,
    "owned HGSS battle party menu consumes remapped direction")
  game.input.pressQueue = { "up" }
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  T.eq(partyMenu.submenu.index, 1,
    "owned HGSS battle party menu maps UP to visible SWITCH")

  local summaryMon = game.save.party[1]
  local summaryState = {
    screenId = "Gen2SummaryMenu", page = 2, moveIndex = 1,
    mon = summaryMon,
    itemName = function() return "BERRY" end,
    expToNext = function() return 20 end,
    otName = function() return "GOLD" end,
    otId = function() return 25 end,
  }
  local previousMoves = summaryMon.moves
  local previousFirst = run.data.moves.FIX_SUMMARY_1
  local previousSecond = run.data.moves.FIX_SUMMARY_2
  local previousMoveDetails = run.loader.modOptions.kanto_gear.move_details
  summaryMon.moves = {
    { id = "FIX_SUMMARY_1", pp = 20 },
    { id = "FIX_SUMMARY_2", pp = 10 },
  }
  run.data.moves.FIX_SUMMARY_1 = {
    name = "FIRST MOVE", type = "NORMAL", pp = 35,
    power = 40, accuracy = 100, description = "FIRST MOVE DESCRIPTION",
  }
  run.data.moves.FIX_SUMMARY_2 = {
    name = "SECOND MOVE", type = "FIRE", pp = 15,
    power = 60, accuracy = 95, description = "SECOND MOVE DESCRIPTION",
  }
  run.loader.modOptions.kanto_gear.move_details = true
  game.stack.states = { screen, partyMenu, summaryState }
  game.input.pressQueue = { "down" }
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  T.eq(summaryState.moveIndex, 2,
    "owned HGSS battle summary moves focus with the D-pad")
  T.eq(#game.input.pressQueue, 0,
    "owned HGSS battle summary consumes remapped direction")
  game.input.pressQueue = { "a" }
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  local _, selectedMove = debug.getupvalue(inputHook, moveInfoIndex)
  T.eq(selectedMove and selectedMove.id, "FIX_SUMMARY_2",
    "A opens the focused battle summary move description")
  T.eq(#game.input.pressQueue, 0,
    "battle summary move descriptions consume confirm input")
  game.input.pressQueue = { "b" }
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  _, selectedMove = debug.getupvalue(inputHook, moveInfoIndex)
  T.eq(selectedMove, nil,
    "B closes move details without leaving the battle summary")
  local composeHook
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"] or {}) do
    if entry.owner == "kanto_gear" then composeHook = entry.callback end
  end
  local function upvalue(fn, target)
    for index = 1, debug.getinfo(fn, "u").nups do
      local name, value = debug.getupvalue(fn, index)
      if name == target then return value end
    end
  end
  local touchEvent = upvalue(composeHook, "touchEvent")
  local tap = upvalue(touchEvent, "tap")
  local swiped
  game.input.sourcePress = function(_, button) swiped = button end
  game.input.sourceRelease = function() end
  summaryState.page = 1
  touchEvent("down,130,100")
  touchEvent("up,70,100")
  T.eq(swiped, "right",
    "left swipe follows the visible next Summary arrow in battle")
  swiped = nil
  touchEvent("down,70,100")
  touchEvent("up,130,100")
  T.eq(swiped, "left",
    "right swipe follows the visible previous Summary arrow in battle")
  summaryState.page = 2
  tap(80, 50)
  _, selectedMove = debug.getupvalue(inputHook, moveInfoIndex)
  T.eq(selectedMove and selectedMove.id, "FIX_SUMMARY_1",
    "touch opens the tapped battle summary move description")
  debug.setupvalue(inputHook, moveInfoIndex, nil)
  summaryMon.moves = previousMoves
  run.data.moves.FIX_SUMMARY_1 = previousFirst
  run.data.moves.FIX_SUMMARY_2 = previousSecond
  run.loader.modOptions.kanto_gear.move_details = previousMoveDetails
  game.stack.states = { screen }
  game.input = previousInput
  run.loader.modOptions.kanto_gear.theme_v3 = previousTheme
  run.loader.events:emit("mod.options_changed",
    { mod = "kanto_gear", key = "theme_v3", value = previousTheme })
  debug.setupvalue(runtime.remapBattleRootInput, readyUpvalue, true)
end
run.loader.modOptions.kanto_gear.battle_view = "full"
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "battle_view" })
T.eq(run.loader.hooks:call("battle.status_hud_visible",
    function() return true end, screen), false,
  "FULL GEAR gives Gold's status HUD to the companion screen too")
run.loader.modOptions.kanto_gear.battle_view = "info"
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "battle_view" })
T.eq(run.loader.hooks:call("battle.bottom_ui_visible",
    function() return true end, screen), true,
  "INFO leaves Gold's native battle menu visible")
T.eq(run.loader.hooks:call("battle.status_hud_visible",
    function() return true end, screen), true,
  "INFO leaves Gold's native status HUD visible")
local infoDraws = T.record.draw()
now = now + 1
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
infoDraws:stop()
T.check(#infoDraws:fromPath(
    "tests/fixture_data/assets/fixmon_b_front.png") > 0,
  "Gold INFO draws the active enemy species on the companion screen")
touchEvents[1] = "tap,40,40"
local profileDraws = T.record.draw()
now = now + 1
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
profileDraws:stop()
T.eq(#profileDraws:fromPath(
    "tests/fixture_data/assets/fixmon_b_front.png"), 0,
  "tapping INFO identity opens the Gold Pokedex detail page")
game.input = { pressQueue = { "b" } }
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
T.eq(#game.input.pressQueue, 0,
  "Pokedex detail consumes B without backing out of the battle")
local profileBackDraws = T.record.draw()
now = now + 1
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
profileBackDraws:stop()
T.check(#profileBackDraws:fromPath(
    "tests/fixture_data/assets/fixmon_b_front.png") > 0,
  "B returns from Pokedex detail to the compact INFO card")
touchEvents[1] = "tap,20,110"
local matchupDraws = T.record.draw()
now = now + 1
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
matchupDraws:stop()
T.eq(#matchupDraws:fromPath(
    "tests/fixture_data/assets/fixmon_b_front.png"), 0,
  "tapping a matchup column opens its complete focused table")
run.loader.modOptions.kanto_gear.battle_view = "full"
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "battle_view" })

do
  local mon = game.save.party[1]
  local previousMoves = mon.moves
  mon.moves = {
    { id = "FIX_HM" }, { id = "FIX_OLD_2" },
    { id = "FIX_OLD_3" }, { id = "FIX_OLD_4" },
  }
  for _, id in ipairs({ "FIX_HM", "FIX_OLD_2", "FIX_OLD_3",
                         "FIX_OLD_4", "FIX_NEW" }) do
    run.data.moves[id] = { id = id, name = id, type = "NORMAL" }
  end
  screen.phase = "choose-forget"
  screen.message = "Which move should\nbe forgotten?"
  screen.messageTimer = 0
  screen.forgetIndex = 1
  screen.pendingLearn = {
    index = 1, move = { id = "FIX_NEW" }, moveName = "FIX_NEW",
  }
  now = now + 1
  run.loader.hooks:call("render.compose", function() return false end, {}, {
    secondScreen = companion,
  })
  local pressed
  game.input.sourcePress = function(_, button) pressed = button end
  game.input.sourceRelease = function() end
  touchEvents[1] = "tap,20,95"
  now = now + 1
  run.loader.hooks:call("render.compose", function() return false end, {}, {
    secondScreen = companion,
  })
  T.eq(screen.forgetIndex, 3,
    "Gold move learning exposes every forget slot on the companion")
  T.eq(pressed, "a",
    "tapping a visible forget row confirms that exact native slot")
  screen.phase, screen.message, screen.messageTimer = "menu", nil, nil
  screen.pendingLearn, screen.forgetIndex = nil, nil
  mon.moves = previousMoves
end

-- Gold resolves the turn before its native HP bar finishes chasing the new
-- value.  The companion must follow screen.shownHp, not jump straight to the
-- already-final battle mon HP.
local main = assert(io.open(path .. "/main.lua", "rb"))
local source = main:read("*a")
main:close()
T.check(source:find("raw%.battle and raw%.battle%[side%]", 1) ~= nil,
  "Gold FULL GEAR reads chased HP from the nested battle state")

run.loader.game = game
screen.phase = "anim"
screen.message = "FIXMON_A used TACKLE!"
screen.hpAnim = { side = "enemy", to = 7 }
screen.shownHp.enemy = 9
screen.battle.enemy.hp = 7
rectangles = {}
now = now + 1
run.loader.events:emit("battle.damage_dealt", {})
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
local sawEnemyPanel, sawChasedHp = false, false
for _, call in ipairs(rectangles) do
  local _, x, y, w, h = unpack(call)
  if x == 4 and y == 3 and w == 152 and h == 40 then
    sawEnemyPanel = true
  elseif x == 29 and y == 28 and w == 49 and h == 5 then
    sawChasedHp = true
  end
end
T.check(sawEnemyPanel,
  "Gold HP animation keeps FULL GEAR status panels visible")
T.check(sawChasedHp,
  "Gold HP animation draws the chased intermediate enemy HP")
screen.phase, screen.message, screen.hpAnim = "menu", nil, nil

screen.statsBoxMon = game.save.party[1]
screen.statsBoxMon.stats = { hp = 22, attack = 12, defense = 11,
  specialAttack = 13, specialDefense = 14, speed = 15 }
screen.phase = "stats-box"
rectangles = {}
now = now + 1
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
local sawLevelContinue = false
for _, call in ipairs(rectangles) do
  local _, x, y, w, h = unpack(call)
  if x == 24 and y == 111 and w == 112 and h == 27 then
    sawLevelContinue = true
  end
end
T.check(sawLevelContinue,
  "Gold level-up stats render on the companion screen")
T.eq(run.loader.hooks:call("screen.render_visible",
  function() return true end, screen), true,
  "Gold level-up keeps the native battle scene visible")

screen.phase, screen.statsBoxMon = "resolving", nil
screen.message = "FIXMON_A gained 12 EXP. Points!"
now = now + 1
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
game.stack.states = {}
run.loader.events:emit("screen.popped", { state = screen })
rectangles = {}
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
local staleBattlePanel = false
for _, call in ipairs(rectangles) do
  local _, x, y, w, h = unpack(call)
  if x == 4 and y == 3 and w == 152 and h == 40 then
    staleBattlePanel = true
  end
end
T.check(not staleBattlePanel,
  "popping Gold's battle screen clears the cached EXP view immediately")
screen.phase, screen.message = "menu", nil

local pack = {
  screenId = "Gen2PackMenu", battle = true, pocketIndex = 1, index = 1,
  rows = { { id = "POTION", name = "POTION", count = 2,
    showCount = true } },
  pocket = function() return { id = "ITEM", label = "ITEMS" } end,
}
game.stack.states = { screen, pack }
now = now + 1
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.check(true, "Gold battle PACK rows render on the companion screen")

local party = {
  screenId = "Gen2PartyMenu", index = #game.save.party + 1,
  isCancel = function(self) return self.index > #game.save.party end,
}
game.stack.states = { screen, party }
now = now + 1
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.check(true, "Gold party CANCEL renders as navigation instead of a Pokemon")
do
  local previousView = run.loader.modOptions.kanto_gear.battle_view
  run.loader.modOptions.kanto_gear.battle_view = "standard"
  T.eq(run.loader.hooks:call("screen.render_visible",
    function() return true end, pack), false,
    "Gold STANDARD keeps the native battle PACK off the top screen")
  T.eq(run.loader.hooks:call("screen.render_visible",
    function() return true end, party), false,
    "Gold STANDARD keeps the native battle party off the top screen")
  T.eq(run.loader.hooks:call("ui.party.grid_navigation",
    function() return false end, party), true,
    "Gold STANDARD party navigation follows the companion grid")
  run.loader.modOptions.kanto_gear.battle_view = previousView
end

do
  local previousParty, previousBattleParty, previousPlayer =
    game.save.party, battle.party, battle.player
  local previousIcons = run.data.gen2Icons
  local egg = { species = "FIXMON_B", nickname = "EGG", isEgg = true,
    level = 5, hp = 0, stats = { hp = 18 }, exp = 0 }
  game.save.party, battle.party, battle.player = { egg }, { egg }, egg
  party.index = 1
  run.data.gen2Icons = { species = {}, icons = {
    ICON_EGG = { image = "native-egg.png" },
  } }
  game.stack.states = { screen, party }
  now = now + 1
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  local battleEggDraws = T.record.draw()
  run.loader.hooks:call("render.compose", function() return false end, {}, {
    secondScreen = companion,
  })
  battleEggDraws:stop()
  T.check(#battleEggDraws:fromPath("native-egg.png") > 0,
    "Gold battle party restores egg identity from the live party slot")
  game.save.party, battle.party, battle.player =
    previousParty, previousBattleParty, previousPlayer
  run.data.gen2Icons = previousIcons
  party.index = #game.save.party + 1
end

local summary = {
  screenId = "Gen2SummaryMenu", page = 3, mon = game.save.party[1],
  itemName = function() return "BERRY" end,
  expToNext = function() return 20 end,
  otName = function() return "GOLD" end,
  otId = function() return 25 end,
}
summary.mon.experience = 12
summary.mon.maxHp = 20
summary.mon.stats.attack = 9
summary.mon.stats.defense = 10
summary.mon.stats.specialAttack = 11
summary.mon.stats.specialDefense = 12
summary.mon.stats.speed = 13
game.stack.states = { screen, party, summary }
now = now + 1
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.eq(run.loader.hooks:call("screen.render_visible",
  function() return true end, summary), false,
  "Gold battle summaries render only on the companion screen")
game.stack.states = { summary }
T.eq(run.loader.hooks:call("screen.render_visible",
  function() return true end, summary), true,
  "Gold field summaries keep their native top-screen rendering")
game.stack.states = { screen, party, summary }
summary.moveDetail = true
T.eq(run.loader.hooks:call("screen.render_visible",
  function() return true end, summary), true,
  "unsupported Gold summary subviews safely keep native rendering")
summary.moveDetail = false

local scriptChoice = {
  screenId = "Gen2ScriptMenu", items = { "ONE", "TWO", "THREE" },
  style = "vertical", row = 2, col = 1, rows = 3, cols = 1,
}
game.stack.states = { scriptChoice }
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.eq(scriptChoice.row, 2,
  "Gold script choices share the companion choice renderer")

local blackboard = {
  screenId = "Gen2ScriptMenu", style = "2d",
  items = { "PSN", "PAR", "SLP", "BRN", "FRZ", "QUIT" },
  row = 1, col = 1, rows = 3, cols = 2,
}
game.stack.states = { blackboard }
rectangles = {}
now = now + 1
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
local cells = {}
for _, call in ipairs(rectangles) do
  local mode, x, y, w, h = unpack(call)
  if mode == "fill" and w == 72 and h == 32 then
    cells[x .. ":" .. y] = true
  end
end
T.check(cells["6:28"] and cells["82:28"]
    and cells["6:64"] and cells["82:64"]
    and cells["6:100"] and cells["82:100"],
  "Gold 2D choices mirror the native three-by-two grid")
game.input.sourcePress = function() end
game.input.sourceRelease = function() end
touchEvents[1] = "tap,120,115"
now = now + 1
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.eq(blackboard.row, 3, "Gold 2D touch selects the matching row")
T.eq(blackboard.col, 2, "Gold 2D touch selects the matching column")

local nestedChoice = { screenId = "Gen2PackMenu",
  confirm = { choice = 2 } }
game.stack.states = { nestedChoice }
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.eq(nestedChoice.confirm.choice, 2,
  "Gold nested confirmations share the companion choice renderer")

local presses = 0
game.input.sourcePress = function(_, button)
  if button == "a" then presses = presses + 1 end
end
local saveChoice = { screenId = "Gen2SaveMenu", phase = "confirm", choice = 1 }
game.stack.states = { saveChoice }
now = now + 1
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
now = now + 1
touchEvents[1] = "tap,80,70"
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
saveChoice.phase = "overwrite"
now = now + 1
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
now = now + 1
touchEvents[1] = "tap,80,70"
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.eq(presses, 2,
  "Gold save overwrite accepts touch after the prompt changes in place")

local nameChoice = { screenId = "Gen2NamePick",
  items = { "NEW NAME", "GOLD" }, cursor = 2 }
game.stack.states = { nameChoice }
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.eq(nameChoice.cursor, 2,
  "Gold name choices share the companion choice renderer")

do
  local function upvalue(fn, target)
    for index = 1, debug.getinfo(fn, "u").nups do
      local name, value = debug.getupvalue(fn, index)
      if name == target then return value end
    end
  end
  local composeHook
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"] or {}) do
    if entry.owner == "kanto_gear" then composeHook = entry.callback end
  end
  local touchEvent = upvalue(composeHook, "touchEvent")
  local displayRuntime = upvalue(touchEvent, "displayRuntime")
  local previousStates, previousInput = game.stack.states, game.input
  local previousBoxes, previousBox, previousParty = game.save.boxes,
    game.save.currentBox, game.save.party
  local pressed
  game.input = {
    sourcePress = function(_, button) pressed = button end,
    sourceRelease = function() end,
  }
  game.save.currentBox = 1
  game.save.party = {
    { species = "FIXMON_A", nickname = "PARTY ONE", level = 5 },
    { species = "FIXMON_B", nickname = "PARTY TWO", level = 6 },
  }
  game.save.boxes = { {
    { species = "FIXMON_A", nickname = "BOX ONE", level = 7 },
    { species = "FIXMON_B", nickname = "BOX TWO", level = 8 },
  } }

  T.check(displayRuntime.pcStateKey({ pickIndex = 2 })
      ~= displayRuntime.pcStateKey({ pickIndex = 3 })
      and displayRuntime.pcStateKey({ listIndex = 1 })
        ~= displayRuntime.pcStateKey({ listIndex = 2 })
      and displayRuntime.pcStateKey({ message = { page = 1 } })
        ~= displayRuntime.pcStateKey({ message = { page = 2 } }),
    "Gold PC redraws immediately for every native cursor field")

  displayRuntime.bag.pending = { itemId = "TM_FIX", moveId = "FIX_MOVE_A" }
  local fieldParty = { screenId = "Gen2PartyMenu", index = 2,
    party = game.save.party, prompt = "Use on which <PK><MN>?" }
  game.stack.states = { fieldParty }
  local partyMenu, partyRows, partyTitle = displayRuntime.fieldBagParty()
  T.eq(partyMenu, fieldParty, "field Bag owns the native party picker below")
  T.eq(partyRows[2], game.save.party[2],
    "field Bag party picker keeps the native party data")
  T.eq(partyTitle, "TEACH MOVE TO",
    "TM use explains the party selection on the bottom screen")

  displayRuntime.bag.pending = { itemId = "POTION" }
  fieldParty.index, pressed = 1, nil
  touchEvent("down,82,25")
  touchEvent("up,82,25")
  T.eq(fieldParty.index, 2,
    "field item party touch owns the bottom screen while native UI is locked")
  T.eq(pressed, "a", "field item party touch reaches native input")

  local textBox = { isTextBox = true }
  local yesNo = { index = 1, onChoose = function() end }
  game.stack.states = { textBox, yesNo }
  displayRuntime.bag.pending = { itemId = "TM_FIX", moveId = "FIX_MOVE_A" }
  displayRuntime.bag.pending.mon = game.save.party[2]
  local fieldLearn = displayRuntime.moveLearnScreen()
  T.check(fieldLearn and fieldLearn.field
      and fieldLearn.newMoveId == "FIX_MOVE_A",
    "field TM questions retain the move and Pokemon information below")

  displayRuntime.bag.pending = { itemId = "PP_UP", mon = game.save.party[1] }
  game.save.party[1].moves = {
    { id = "FIX_MOVE_A", pp = 5, maxPp = 10 },
  }
  local ppPicker = { screenId = "Gen2MoveDeleter", mon = game.save.party[1],
    list = game.save.party[1].moves, row = 1 }
  game.stack.states = { ppPicker }
  T.check(displayRuntime.fieldPpMoveScreen(),
    "field PP items mirror their native move picker below")
  displayRuntime.bag.pending = nil

  local root = { screenId = "Gen2PcMenu", index = 1, entries = {
    { label = "WITHDRAW <PK><MN>" }, { label = "DEPOSIT <PK><MN>" },
    { label = "CHANGE BOX" }, { label = "MOVE <PK><MN> W/O MAIL" },
    { label = "SEE YA!" },
  } }
  game.stack.states = { root }
  T.check(pcall(function()
    run.loader.hooks:call("render.compose", function() return false end, {}, {
      secondScreen = companion,
    })
  end), "Gold PC root mirrors its native entry contract")
  touchEvent("tap,120,25")
  T.eq(root.index, 1, "Gold PC root touch keeps the native vertical row")
  T.eq(pressed, "a", "Gold PC root touch confirms through native input")

  local box = { screenId = "Gen2BoxMenu", mode = "withdraw",
    boxIndex = 1, index = 1 }
  game.stack.states = { root, box }
  pressed = nil
  touchEvent("tap,120,64")
  T.eq(box.index, 2, "Gold box touch follows the native up/down list")
  T.eq(pressed, "a", "Gold box touch confirms through native input")

  box.mode, box.boxIndex, box.index = "move", 0, 1
  touchEvent("tap,120,88")
  T.eq(box.index, 3,
    "Gold MOVE includes the native PARTY cancel row in cursor order")

  root.picking, root.pickIndex = true, 5
  game.stack.states = { root }
  touchEvent("tap,120,35")
  T.eq(root.pickIndex, 5,
    "Gold change-box touch stays on the first visible box row")

  local itemPc = { screenId = "Gen2ItemPcMenu", index = 1,
    entries = { { label = "WITHDRAW ITEM" }, { label = "TOSS ITEM" } },
    phase = "withdraw", listIndex = 1,
    rows = { { name = "POTION", count = 2 },
      { name = "ANTIDOTE", count = 1 } },
  }
  game.stack.states = { itemPc }
  touchEvent("tap,120,51")
  T.eq(itemPc.listIndex, 2,
    "Gold item PC touch follows the native vertical item list")

  itemPc.qtyState = { qty = 2, max = 5 }
  game.stack.states = { itemPc }
  pressed = nil
  touchEvent("tap,10,70")
  T.eq(pressed, "down",
    "Gold item PC quantity controls remain mirrored below")
  itemPc.qtyState = nil

  itemPc.message = { pages = { { "THE ITEM STORAGE", "IS COMPLETELY FULL.",
    "CHOOSE ANOTHER ITEM", "OR GO BACK." } }, page = 1 }
  game.stack.states = { itemPc }
  local notice = displayRuntime.pcNotice("items", itemPc, itemPc)
  T.check(notice and #notice.lines == 4,
    "Gold item PC keeps four-line storage and mail notices visible below")
  pressed = nil
  touchEvent("tap,120,100")
  T.eq(pressed, "a", "Gold item PC notice advances from the bottom screen")
  itemPc.message = nil

  local pack = { screenId = "Gen2PackMenu", index = 1, pocketIndex = 1,
    rows = { { id = "POTION", name = "POTION", count = 2,
      showCount = true } },
    pocket = function() return { label = "ITEMS" } end }
  itemPc.phase, itemPc.pack = "deposit", pack
  game.stack.states = { itemPc }
  pressed = nil
  touchEvent("tap,120,50")
  T.eq(pack.index, 1,
    "Gold item PC deposit keeps the native Pack cursor")
  T.eq(pressed, "a", "Gold item PC deposit confirms through native input")
  itemPc.pack = nil

  box.phase, box.index, box.submenuIndex = "submenu", 1, 1
  game.stack.states = { root, box }
  pressed = nil
  touchEvent("tap,120,70")
  T.eq(box.submenuIndex, 2,
    "Gold PC submenu touch follows the native action cursor")
  T.eq(pressed, "a", "Gold PC submenu touch confirms through native input")

  game.stack.states, game.input = previousStates, previousInput
  game.save.boxes, game.save.currentBox, game.save.party =
    previousBoxes, previousBox, previousParty
end

run.release()
T.love.graphics.newCanvas = newCanvas
T.love.graphics.rectangle = rectangle
T.love.timer.getTime = getTime
T.finish("Kanto Gear Gen 2 compatibility")
