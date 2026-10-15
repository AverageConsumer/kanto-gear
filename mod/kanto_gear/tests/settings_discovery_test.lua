local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local Policy = assert(loadfile(root .. "/core/discovery.lua"))()
local Progress = assert(loadfile(root .. "/features/achievements.lua"))()
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local function hook(run, name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end

T.eq(Policy.mode("legacy", "enhanced"), "spoiler", "old explicitly revealing custom setting survives")
T.eq(Policy.mode("legacy", true), "vanilla", "other saved custom modes migrate conservatively")
T.check(not Policy.map("enhanced", nil, nil, {}, {}), "absent map IDs are not proof of a visit")
T.check(not Policy.map("enhanced", "FUTURE", "HERE", 42, { visited = false }),
  "old invalid visit metadata cannot expose or crash an undiscovered map")
local rows = {
  { id = "visible", mapId = "HERE", kind = "item" },
  { id = "found", mapId = "HERE", kind = "hidden", done = true },
  { id = "secret", mapId = "HERE", kind = "hidden" },
  { id = "future", mapId = "HERE", available = false, status = "LATER" },
  { id = "remote", mapId = "FUTURE", kind = "item" },
}
for _, mode in ipairs({ "vanilla", "enhanced", "spoiler" }) do
  local visible = Policy.filter(rows, function(row)
    return Policy.row(mode, row, row.kind == "hidden" and 3 or 2,
      Policy.map(mode, row.mapId, "HERE", {}, {}))
  end)
  T.eq(#visible, mode == "spoiler" and 5 or mode == "enhanced" and 2 or 1,
    mode .. " enforces hidden, future and unvisited boundaries")
end
T.check(Policy.row("vanilla", { scanned = true }, 3, true), "an actual Itemfinder scan reveals a hidden find")
local area = { tier = "bronze", complete = false, sections = { { rows = {
  { state = "done", done = true }, { state = "open" } } } } }
local presented = Progress.presentArea(area, "vanilla", function(row) return row.done end)
T.eq(presented.sections[1].total, 1, "disclosed stamp counts exclude unknown tasks")
T.eq(presented.tier, "bronze", "filtering cannot award a false gold stamp")
T.eq(#area.sections[1].rows, 2, "presentation never changes completion evidence")

-- Every preset and every independent switch share a single permission model.
for _, preset in ipairs({ "purist", "enhanced", "spoiler" }) do
  local policy = Policy.resolve(function(k) if k == "info_level" then return preset end end)
  for _, row in ipairs(Policy.options) do
    T.eq(policy[row[1]], preset == "spoiler" or preset == "enhanced" and row[4] or false,
      preset .. " controls " .. row[1])
  end
end
for _, selected in ipairs(Policy.options) do
  local policy = Policy.resolve(function(k)
    if k == "info_level" then return "custom" end
    return k == Policy.key(selected[1])
  end)
  for _, row in ipairs(Policy.options) do
    T.eq(policy[row[1]], row == selected, "Custom does not couple " .. selected[1] .. " to " .. row[1])
  end
end
local vanilla = Policy.resolve(function(k) if k == "info_level" then return "purist" end end)
local guidePolicy = Policy.resolve(function(k) if k == "info_level" then return "enhanced" end end)
local function enemy(policy, caught)
  return Policy.enemy({ caught = caught, types = { "FIRE" }, kind = "SECRET", height = "10",
    descriptionText = "SECRET", description = { "SECRET" }, dvs = {}, weak = { {} }, resist = { {} } }, policy)
end
local foe = enemy(vanilla, false)
T.eq(foe.kind, nil, "Vanilla redacts uncaught opponent facts")
T.eq(#foe.types, 0, "Vanilla redacts opponent types")
T.eq(foe.dvs, nil, "Vanilla redacts opponent genes")
T.eq(foe.profileAvailable, false, "redacted profile cannot react to a tap")
T.eq(foe.matchupsAvailable, false, "redacted matchups cannot react to a tap")
T.eq(enemy(vanilla, true).kind, "SECRET", "caught native Dex facts remain available")
guidePolicy.enemy_details = false
T.eq(enemy(guidePolicy, false).kind, nil, "uncaught Dex permission does not override opponent-data permission")

local function exercise(run, display)
  local api = up(display.saveHome, "mod")
  local theme = up(display.drawContents, "THEME")
  local game = up(display.pokedexData, "game")
  local id = up(display.homeRegionMap, "mapId") or "HERE"
  up(display.homeRegionMap, "mapId", id, true)
  api.options:set("info_level", "enhanced")
  display.settings.category, display.settings.option, display.settings.selected = nil, nil, nil
  T.eq(display.settingsModel().tab, 1, "Settings opens on its first tab instead of a submenu list")
  display.tapSettings(7 + 3 * 38 + 18, 42)
  T.eq(display.settings.category, 4, "the Exploration tab opens with one tap")
  display.tapSettings(30, 80)
  T.eq(display.settingsModel().selected, "info_level", "the first tap selects and explains the setting")
  display.tapSettings(10, 10)
  T.eq(display.settings.category, nil, "Back from the tabs returns Home")
  for category, group in ipairs(display.settingsCategories) do
    display.settings.category, display.settings.option = category, nil
    local model = display.settingsModel()
    for _, row in ipairs(model.rows) do
      T.check(type(row.description) == "string" and #row.description > 0,
        "every visible setting/action explains its effect: " .. (row.key or row.action))
      display.settings.option = row.key or row.action
      local detail = display.settingsModel()
      T.check(detail.option and detail.description and #detail.choices > 0, "detail provides help and explicit choices")
      for _, language in ipairs({ "en", "de", "es", "fr", "ja", "it" }) do
        api.options:set("language", language)
        local lines = theme.hgss:settingsHelpLines(theme:translate(detail.description))
        T.check(#lines <= 6, "complete help fits its panel in " .. language .. ": " .. detail.option)
        for _, line in ipairs(lines) do
          T.eq(theme.hgss:fitPartyType(line, 210), line, "help never needs clipping")
        end
      end
      api.options:set("language", "en")
      for page = 1, detail.pages do
        display.settings.choicePage = page; detail = display.settingsModel()
        for i = 0, 3 do
          local index = (page - 1) * detail.perPage + i + 1
          local choice = i < detail.perPage and detail.choices[index]
          local top = theme.hgss:settingsChoiceTop(detail)
          local action, hit = theme.hgss:settingsHit(120, top + 11 + i * 25, detail)
          T.eq(action, choice and "choice" or nil, "only actual option rows accept touches")
          if choice then T.eq(hit, index, "choice hit matches its visible page") end
          T.eq(theme.hgss:settingsHit(120, top + 23 + i * 25, detail), nil, "gaps cannot select a neighboring choice")
        end
        T.eq(theme.hgss:settingsHit(120, 180, detail), nil, "explanation text cannot change a setting")
      end
      display.settings.option = nil
    end
  end
  display.settings.category, display.settings.page, display.settings.option = 4, 1, nil
  display.settings.selected = nil
  local before = api.options:get("info_level")
  display.tapSettings(170, 80)
  T.eq(api.options:get("info_level"), before, "the first tap on a control only selects its row")
  T.eq(display.settingsModel().selected, "info_level", "touch selects the discovery explanation")
  local model = display.settingsModel()
  local tapped
  for x = 114, 226 do
    local action, index, extra = theme.hgss:settingsHit(x, 80, model)
    if action == "set" and model.rows[index].choices[extra][2] == "purist" then
      display.tapSettings(x, 80); tapped = true; break
    elseif action == "more" then
      display.tapSettings(x, 80)
      display.tapSettings(120, theme.hgss:settingsChoiceTop(display.settingsModel()) + 11)
      display.tapSettings(10, 10); tapped = true; break
    end
  end
  T.check(tapped, "a selected row exposes an explicit control")
  T.eq(api.options:get("info_level"), "purist", "explicit choice selects Vanilla")
  T.check(display.settingsModel().rows[1].info:find("Original-game information only", 1, true), "explanation follows the selected mode")
  T.eq(display.settings.category, 4, "the category stays open after changing a value")

  api.options:set("info_level", "purist")
  local projected = { screenId = "Gen3Menu", update = function() end, valid = function() return true end,
    index = 1, items = { { label = "TARGET", effectiveness = 20, catchChance = 75 } } }
  local entry = display.startMenuModel(projected).entries[1]
  T.eq(entry.effectiveness, nil, "Vanilla hides native target effectiveness")
  T.eq(entry.catchChance, nil, "Vanilla hides native target catch odds")
  api.options:set("type_hints", true)
  entry = display.startMenuModel(projected).entries[1]
  T.eq(entry.effectiveness, 20, "independent type hints restore native effectiveness")
  T.eq(entry.catchChance, nil, "type hints do not restore catch odds")
  api.options:set("type_hints", false); api.options:set("catch_odds", true)
  entry = display.startMenuModel(projected).entries[1]
  T.eq(entry.effectiveness, nil, "catch odds do not restore effectiveness")
  T.eq(entry.catchChance, 75, "independent catch odds restore native target estimate")
  T.eq(projected.items[1].catchChance, 75, "redaction never mutates the host menu")
  api.options:set("info_level", "purist")
  api.options:set("info_level", "custom")
  for _, group in ipairs(Policy.groups) do
    api.options:set("discovery_section", group[2])
    display.settings.category, display.settings.page, display.settings.option = 4, 1, nil
    local custom = display.settingsModel()
    T.eq(custom.detail, group[1], "the current information group remains visible on every page")
    for _, option in ipairs(custom.rows) do
      T.check(not option.source.discoveryGroup or option.source.discoveryGroup == group[2],
        "custom categories never mix unrelated switches")
      for _, language in ipairs({ "en", "de", "es", "fr", "ja", "it" }) do
        api.options:set("language", language)
        local lines = theme.hgss:settingsHelpLines(theme:translate(option.info or option.description))
        T.check(#lines <= 3, "custom help fits: " .. option.key .. " in " .. language)
        for _, line in ipairs(lines) do T.eq(theme.hgss:fitPartyType(line, 210), line, "custom help is not clipped") end
      end
      api.options:set("language", "en")
    end
  end
  for _, flag in ipairs(Policy.options) do
    api.options:set("info_level", "purist")
    api.options:set(Policy.key(flag[1]), true)
    T.eq(api.options:get("info_level"), "custom", "a single override enters Custom: " .. flag[1])
    local current = display.discoveryPolicy()
    for _, other in ipairs(Policy.options) do
      T.eq(current[other[1]], other == flag, "runtime keeps independent permissions: " .. other[1])
    end
    T.eq(display.pokedex.data, nil, "disclosure changes invalidate Dex snapshots")
    T.eq(display.home.widgetCache, nil, "disclosure changes invalidate Home widgets")
  end
  api.options:set("info_level", "enhanced")
  -- All generation adapters pass through the same final presentation boundary.
  local guide = up(display.explorerModel, "guideData")
  local areaData = up(display.explorerModel, "areaData")
  local originalEntries = display.pokedexData().entries
  local first, second = originalEntries[1].species, originalEntries[2].species
  local oldDex = game.save.pokedex
  game.save.pokedex = { seen = { [first] = true }, caught = {}, owned = {} }
  up(display.explorerModel, "guideData", function()
    return { rows = { { species = first, name = "KNOWN", appearances = {
      { mapId = id, method = "WALK", chance = 50, minLevel = 2, maxLevel = 3 },
      { mapId = "FUTURE_HABITAT", method = "WALK", chance = 50, minLevel = 2, maxLevel = 3 },
    } }, { species = second, name = "UNKNOWN", appearances = {} } }, time = "DAY", caught = 0 }
  end, true)
  local dexGuide = up(display.pokedexData, "guideData", up(display.explorerModel, "guideData"), true)
  up(display.explorerModel, "areaData", function()
    return { sections = {
      { rows = { { id = "trainer", label = "TRAINER", mapId = id, x = 1, y = 1 } } },
      { rows = { { label = "POTION", mapId = id, kind = "item", x = 2, y = 2 } } },
      { rows = { { label = "RARE CANDY", mapId = id, kind = "hidden", x = 3, y = 3 } } },
    } }
  end, true)
  local overview = { mapId = id, rows = { "    ", "    ", "    ", "    " }, width = 4, height = 4 }
  local readAchievements = display.achievementData
  local stamp = { id = id, name = "CURRENT", evidence = true, current = true,
    maps = { id }, tier = "bronze", complete = false, remaining = 4,
    availableRemaining = 4, total = 4, untracked = 0, sections = {} }
  for category, row in ipairs({
    { label = "TRAINER", mapId = id, state = "open" },
    { label = "POTION", mapId = id, state = "open" },
    { label = "RARE CANDY", kind = "hidden", mapId = id, state = "open" },
    { label = "UNKNOWN", species = second, mapId = id, state = "open", order = 1 },
  }) do
    stamp.sections[category] = { rows = { row }, total = 1, done = 0,
      untracked = 0, optional = 0, unavailable = 0 }
  end
  local stamps = { areas = { stamp }, byId = { [id] = stamp }, goals = { stamp }, earned = { stamp } }
  display.achievementData = function() return stamps end
  local hidden = 0
  for _, mode in ipairs({ "spoiler", "enhanced", "purist" }) do
    api.options:set("info_level", mode)
    display.explorer.view = "items"
    local model = display.explorerModel(overview)
    hidden = 0
    for _, marker in ipairs(model.markers) do if marker.kind == "hidden" then hidden = hidden + 1 end end
    T.eq(hidden, mode == "spoiler" and 1 or 0, "app and widget map omit undiscovered hidden markers")
    T.eq(model.total, mode == "spoiler" and 2 or mode == "enhanced" and 1 or 0,
      "hidden-item existence cannot leak via list names or totals")
    local widget = display.currentAchievement()
    T.eq(widget.area.sections[3].total, mode == "spoiler" and 1 or 0,
      "stamp widget does not leak hidden-item totals")
    if mode == "purist" then T.eq(widget.area.tier, nil, "Vanilla hides completion tiers")
    else T.eq(widget.area.tier, "bronze", "guides retain the true completion tier") end
    display.achievements.selected, display.achievements.view, display.achievements.category = id, "finds", 3
    local album = display.achievementModel()
    T.eq(#album.entries, mode == "spoiler" and 1 or 0, "stamp detail does not expose hidden item names")
    display.achievements.category = 1
    album = display.achievementModel()
    T.eq(#album.entries, mode == "purist" and 0 or 1, "stamp trainer checklist follows discovery mode")
    display.pokedex.data = nil
    local dex = display.pokedexData()
    T.check(dex.bySpecies[first] and dex.bySpecies[second], "fixture includes seen and unseen valid dex species")
    if dex.bySpecies[first] and dex.bySpecies[second] then
      display.pokedex.selected, display.pokedex.view = first, "habitat"
      local habitat = display.pokedexModel()
      if mode == "purist" then
        T.eq(habitat.view, "profile", "Vanilla cannot keep a detailed habitat page open")
        T.eq(#(habitat.cards or {}), 0, "Vanilla hides research pages")
        T.eq(habitat.pokemon.type, nil, "seen but uncaught species do not acquire a fake Normal type")
      else
        T.eq(habitat.summary, theme:format("%d AREAS", mode == "spoiler" and 2 or 1),
          "habitat counts do not disclose unvisited areas")
        T.eq(#habitat.rows, mode == "spoiler" and 2 or 1, "habitat names and rows obey the same boundary")
      end
      T.check(dex.bySpecies[first].revealed, "seen species remains accessible")
      T.eq(dex.bySpecies[second].revealed, mode ~= "purist", "unknown species honors discovery mode")
      if mode == "purist" then
        T.eq(dex.bySpecies[second].name, "???", "unknown species has no leaked name")
        T.check(not display.selectPokedexSpecies(dex.bySpecies[second].index), "unknown species cannot open a profile")
        display.pokedex.selected, display.pokedex.view = second, "moves"
        T.eq(display.pokedexModel().view, "index", "stale unknown details return to index")
      end
    end
  end
  api.options:set("type_hints", false); api.options:set("catch_odds", false)
  api.options:set("info_level", "spoiler")
  T.eq(api.options:get("type_hints"), true, "Everything includes battle helpers")
  api.options:set("info_level", "purist")
  api.options:set("move_details", true)
  T.eq(api.options:get("move_details"), true, "individual attack details can be enabled")
  T.eq(api.options:get("info_level"), "custom", "individual changes switch to Custom")
  T.eq(display.discoveryPolicy().area_map, false, "Custom starts with the previous Vanilla map boundary")
  display.explorer.selected, display.explorer.scanRevealed = "old-secret", { secret = true }
  display.pokedex.habitatPlan = { rows = { "old-secret" } }
  api.options:set("info_level", "enhanced")
  T.eq(display.explorer.selected, nil, "stricter/mutated policy clears an open map detail")
  T.eq(next(display.explorer.scanRevealed), nil, "old scan state cannot leak after mode changes")
  T.eq(display.pokedex.habitatPlan, nil, "old habitat cache is discarded immediately")
  up(display.pokedexData, "guideData", dexGuide, true)
  up(display.explorerModel, "guideData", guide, true)
  up(display.explorerModel, "areaData", areaData, true)
  display.achievementData = readAchievements
  game.save.pokedex = oldDex
  T.eq(#run.errors, 0, "setting changes contain no event errors")
end

if os.getenv("KANTO_GEAR_TEST_GEN") == "3" then
  _G.KANTO_GEAR_RENDER_CAPTURE = function(run, display) exercise(run, display) end
  dofile(root .. "/tests/gen3_fixture.lua")
else
  local gen = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
  local run = T.sdk.loadMod(root, { generation = gen, data = T.fixtures.load() })
  local display = up(hook(run, "input.step"), "displayRuntime")
  local world = { isOverworld = true, map = { id = "PALLET_TOWN", def = {} } }
  local game = { data = run.data, world = world, overworld = world,
    stack = { states = { world }, top = function(self) return self.states[#self.states] end },
    save = { generation = gen, player = { name = "RED" }, party = {}, inventory = {},
      visited = {}, pokedex = { seen = {}, caught = {} }, boxes = {}, options = {} } }
  run.loader.events:emit("game.ready", { game = game })
  exercise(run, display)
  T.finish("Settings and disclosure boundary")
end
