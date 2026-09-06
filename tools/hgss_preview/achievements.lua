-- Illustrative data; this preview uses the exact shipped app renderer.
return function(theme, screen, gen1, translate)
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
  local view = screen:find("detail", 1, true) and "detail"
    or screen == "achievements_stamps" and "album"
    or (screen == "achievements_finds" or screen:find("pokemon", 1, true)) and "finds"
    or screen == "achievements_empty" and "album" or "goals"
  local entries = screen == "achievements_empty" and {} or areas
  if view == "finds" then
    entries = { { label = "POKEFAN JAIME", state = "open", x = 2, y = 4 },
      { label = "SUPER POTION", state = "done", x = 5, y = 1 },
      { label = "RIVAL", state = "unavailable" },
      { label = "ARENA LEADER", state = "open", x = 7, y = 7 } }
  end
  if screen:find("pokemon", 1, true) then
    entries = { { label = "SLOWPOKE", species = "SLOWPOKE", state = "open" },
      { label = "MAGIKARP", species = "MAGIKARP", state = "done", done = true },
      { label = "GYARADOS", species = "GYARADOS", state = "done", done = true } }
  end
  if screen == "achievements_detail_bronze" then
    areas[2].tier, areas[2].sections[3].done = "bronze", 0
  elseif screen == "achievements_detail_gold" then
    areas[2].tier, areas[2].complete, areas[2].remaining = "gold", true, 0
    areas[2].sections[4].done = 6
  elseif screen == "achievements_detail_unknown" then
    areas[2].tier, areas[2].sections[1].untracked = "bronze", 2
  end
  theme:headerBar(view == "detail" and areas[2].name or translate("ACHIEVEMENTS"), true, false)
  theme:headerClock("20:04", "NITE", 139, 72, 6)
  theme:battery(214, 8, 4, nil, true, theme.colors.ink, theme.colors.greenLight)
  theme:achievements({ loading = screen == "achievements_loading", view = view, mode = "spoiler", goal = areas[2], area = areas[2],
    entries = entries, earned = { areas[1], areas[4] }, page = 1,
    category = screen:find("pokemon", 1, true) and 4 or 1,
    canExplore = screen == "achievements_pokemon",
    pages = view == "album" and #entries > 0 and 3 or 1 })
end
