-- Illustrative data; this preview uses the exact shipped app renderer.
return function(theme, screen, gen1, translate)
  local names = gen1 and { "ROUTE 1", "ROUTE 2", "ROUTE 3", "VIRIDIAN FOREST", "ROUTE 4", "MT. MOON" }
    or { "ROUTE 38", "ROUTE 39", "ROUTE 40", "ILEX FOREST", "ROUTE 37", "UNION CAVE" }
  local areas = {}
  for i, name in ipairs(names) do
    areas[i] = { id = name, name = name, kind = i == 4 and "forest" or i == 6 and "cave" or "route",
      complete = i == 1 or i == 4, remaining = i == 2 and 1 or 4,
      sections = { { done = 3, total = 3 }, { done = 2, total = 2 }, { done = 0, total = 1 } } }
  end
  local view = screen == "achievements_detail" and "detail"
    or screen == "achievements_stamps" and "album"
    or screen == "achievements_finds" and "finds"
    or screen == "achievements_empty" and "album" or "goals"
  local entries = screen == "achievements_empty" and {} or areas
  if view == "finds" then
    entries = { { label = "POKEFAN JAIME", state = "open", x = 2, y = 4 },
      { label = "SUPER POTION", state = "done", x = 5, y = 1 },
      { label = "RIVAL", state = "unavailable" },
      { label = "ROCKET EXECUTIVE", state = "optional", x = 7, y = 7 } }
  end
  theme:headerBar(view == "detail" and areas[2].name or translate("ACHIEVEMENTS"), true, false)
  theme:headerClock("20:04", "NITE", 139, 72, 6)
  theme:battery(214, 8, 4, nil, true, theme.colors.ink, theme.colors.greenLight)
  theme:achievements({ view = view, mode = "spoiler", goal = areas[2], area = areas[2],
    entries = entries, earned = { areas[1], areas[4] }, page = 1,
    pages = view == "album" and #entries > 0 and 3 or 1 })
end
