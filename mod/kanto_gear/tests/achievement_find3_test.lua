local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local function up(fn, key)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, i)
    if name == key then return value end
  end
end
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local emerald = os.getenv("POKEPORT_VERSION") == "emerald"
  local id = emerald and "EM_ROUTE102" or "FR_ROUTE_3"
  game.session.map = id
  run.loader.events:emit("map.entered", { game = game, mapId = id })
  run.loader.modOptions.kanto_gear.info_level = "spoiler"
  T.check(display.setPackageInstalled("achievements", true), "native Stamps installed")
  T.check(display.openHomeApp("achievements"), "native Stamps opens")
  local album
  for _ = 1, 10000 do
    album = display.achievementData(false, true)
    if album then break end
  end
  assert(album, "native album completes")
  local area = display.currentAchievement().area
  local state, theme = display.achievements, up(display.drawContents, "THEME")
  state.view, state.selected, state.category, state.page = "finds", area.id, 1, 1
  display.drawAchievements()
  local trainer = display.achievementModel().entries[1]
  T.check(trainer.x ~= nil and trainer.y ~= nil, "native route trainer has coordinates")
  display.tapAchievements(120, 70)
  T.eq(state.view, "location", "native trainer tap opens position")
  T.eq(state.location.mapId, id, "native trainer belongs to selected route")
  display.drawAchievements()
  display.tapAchievements(12, 12)
  if display.achievementModel().pages > 1 then
    display.cycleAchievements(1)
    display.drawAchievements()
    display.tapAchievements(120, 70)
    display.drawAchievements()
    display.tapAchievements(12, 12)
    T.eq(state.page, 2, "native trainer position preserves list page two")
  end
  state.category, state.page = 4, 1
  display.drawAchievements()
  local species = display.achievementModel().entries[1].species
  T.eq(theme.hgss:achievementsHit(120, 70), "habitat", "native wild row is actionable")
  display.tapAchievements(120, 70)
  local habitat = display.achievementModel().habitat
  T.eq(state.view, "habitat", "native wild row opens direct details")
  T.eq(habitat.pokemon.species, species, "native details use selected species")
  T.check(#habitat.rows > 0, "native details contain real encounters")
  for _, row in ipairs(habitat.rows) do
    T.check(row.method ~= nil and row.chance > 0, "native details include method and odds")
  end
  display.drawAchievements()
  display.tapAchievements(12, 12)
  T.eq(state.view, "finds", "native habitat back returns to list")
  local remoteId = emerald and "EM_ROUTE101" or "FR_ROUTE_1"
  for _, candidate in ipairs(album.areas) do
    for _, map in ipairs(candidate.maps) do
      if map == remoteId then state.selected = candidate.id end
    end
  end
  display.drawAchievements()
  display.tapAchievements(120, 70)
  T.eq(state.view, "habitat", "remote stamp opens its own species details")
  for _, appearance in ipairs(state.habitat.habitat.appearances) do
    T.eq(appearance.mapId, remoteId, "remote stamp never falls back to the current route")
  end
  display.drawAchievements()
  display.tapAchievements(12, 12)
  for _, status in ipairs({ "open", "done", "later", "unavailable" }) do
    theme.hgss:achievements({ view = "finds", mode = "spoiler", category = 1,
      entries = { { label = "TRAINER", mapId = id, x = 2, y = 3, state = status } } })
    T.eq(theme.hgss:achievementsHit(120, 70), "locate", "known position remains readable: " .. status)
  end
  for _, mode in ipairs({ "vanilla", "enhanced", "spoiler" }) do
    theme.hgss:achievements({ view = "finds", mode = mode, category = 1,
      entries = { { label = "DYNAMIC TRAINER", mapId = id, state = "repeatable" } } })
    T.eq(theme.hgss:achievementsHit(120, 70), nil, "no fabricated position or feedback: " .. mode)
  end
end
dofile(path .. (os.getenv("POKEPORT_VERSION") == "emerald"
  and "/tests/emerald_runtime_test.lua" or "/tests/gen3_runtime_test.lua"))
