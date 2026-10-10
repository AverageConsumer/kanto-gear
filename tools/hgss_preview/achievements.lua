-- Illustrative data; this preview uses the exact shipped app renderer.
return function(theme, screen, gen1, translate, drawPokemon)
  local names = gen1 and { "ROUTE 1", "ROUTE 2", "ROUTE 3", "VIRIDIAN FOREST", "ROUTE 4", "MT. MOON" }
    or { "ROUTE 38", "ROUTE 39", "ROUTE 40", "ILEX FOREST", "ROUTE 37", "UNION CAVE" }
  local areas = {}
  for i, name in ipairs(names) do
    areas[i] = { id = name, name = name, kind = i == 4 and "forest" or i == 6 and "cave" or "route",
      complete = i == 1 or i == 4, remaining = i == 2 and 1 or 4,
      tier = ({ "gold", "silver", "bronze", "gold", "none", "bronze" })[i],
      sections = { { done = 3, total = 3 }, { done = 2, total = 2 },
        { done = 1, total = 1 }, { done = 5, total = 6 } } }
  end
  local view = screen == "achievements_habitat" and "habitat"
    or screen:find("detail", 1, true) and "detail"
    or screen == "achievements_stamps" and "album"
    or (screen == "achievements_finds" or screen == "achievements_bonus" or screen:find("pokemon", 1, true)) and "finds"
    or screen == "achievements_empty" and "album" or "goals"
  local entries = screen == "achievements_empty" and {} or areas
  if view == "finds" then
    entries = { { label = "POKEFAN JAIME", state = "open", mapId = names[2], x = 2, y = 4 },
      { label = "SUPER POTION", state = "done", mapId = names[2], x = 5, y = 1 },
      { label = "RIVAL", state = "unavailable" },
      { label = "ARENA LEADER", state = "later", mapId = names[2], x = 7, y = 7 } }
  end
  if screen:find("pokemon", 1, true) then
    entries = { { label = "SLOWPOKE", species = "SLOWPOKE", state = "open", wild = true },
      { label = "MAGIKARP", species = "MAGIKARP", state = "done", done = true, wild = true },
      { label = "GYARADOS", species = "GYARADOS", state = "done", done = true, wild = true } }
  end
  if screen == "achievements_bonus" then
    entries = { { label = "RIVAL", state = "done", done = true, bonus = true },
      { label = "ROCKET GRUNT", state = "unavailable", bonus = true },
      { label = "SUPER POTION", state = "open", bonus = true, mapId = names[2], x = 5, y = 1 },
      { label = "HYPER POTION", state = "excluded" } }
  elseif screen == "achievements_detail_bonus" then
    areas[2].sections[1].optional, areas[2].sections[1].bonusDone = 12, 8
    areas[2].sections[2].optional, areas[2].sections[2].bonusDone = 3, 0
    areas[2].sections[4].optional, areas[2].sections[4].bonusDone = 2, 1
  end
  if screen == "achievements_detail_bronze" then
    areas[2].tier, areas[2].sections[3].done = "bronze", 0
  elseif screen == "achievements_detail_gold" then
    areas[2].tier, areas[2].complete, areas[2].remaining = "gold", true, 0
    areas[2].sections[4].done = 6
  elseif screen == "achievements_detail_unknown" then
    areas[2].tier, areas[2].sections[1].untracked = "bronze", 2
    areas[2].unknown, areas[2].sections[1].unknown = 2, 2
  elseif screen == "achievements_detail_untracked" then
    areas[2].tier, areas[2].complete, areas[2].remaining = "gold", true, 0
    areas[2].untracked, areas[2].unknown = 1, 0
    areas[2].sections[3].done, areas[2].sections[3].total = 0, 0
    areas[2].sections[3].untracked = 1
    areas[2].sections[4].done = 6
  end
  theme:headerBar(view == "detail" and areas[2].name or translate("ACHIEVEMENTS"), true, false)
  theme:headerClock("20:04", "NITE", 139, 72, 6)
  theme:battery(214, 8, 4, nil, true, theme.colors.ink, theme.colors.greenLight)
  theme:achievements({ loading = screen == "achievements_loading", view = view, mode = "spoiler", goal = areas[2], area = areas[2],
    entries = entries, earned = { areas[1], areas[4] }, page = 1,
    category = screen:find("pokemon", 1, true) and 4 or 1,
    habitat = { pokemon = { name = "SLOWPOKE", type = "WATER", type2 = "PSYCHIC" },
      drawPokemon = drawPokemon, summary = "NO.079", matchText = names[2], page = 1, pages = 2,
      rows = { { area = names[2], method = "WALK", chance = 20, levels = "L5-10", current = true,
          matches = true, status = translate("HERE NOW") },
        { area = names[2], method = "SURF", chance = 60, levels = "L10-15", status = translate("NEED SURF") },
        { area = names[2], method = "SUPER", chance = 40, levels = "L20", status = translate("NEED SUPER ROD") } } },
    canExplore = screen == "achievements_pokemon",
    pages = view == "album" and #entries > 0 and 3 or 1 })
end
