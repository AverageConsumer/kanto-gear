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
  -- Distinct progress per stamp so the four-part rings read differently.
  areas[2].current = true
  areas[3].sections = { { done = 1, total = 3 }, { done = 1, total = 2 }, { done = 0, total = 1 }, { done = 3, total = 6 } }
  areas[5].evidence = false
  areas[6].sections = { { done = 2, total = 5 }, { done = 3, total = 6 }, { done = 1, total = 4 }, { done = 4, total = 7 } }
  areas[4].sections[4] = { done = 9, total = 9 }
  local view = screen == "achievements_habitat" and "habitat"
    or screen:find("location", 1, true) and "location"
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
    entries = { { label = "SLOWPOKE", species = "SLOWPOKE", state = "open", wild = true,
        appearances = { { mapId = names[2], method = "SURF" }, { mapId = names[2], method = "WALK", time = "MORN" },
          { mapId = names[2], method = "OLD" } } },
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
  if screen == "achievements_detail_unvisited" then
    areas[2].tier, areas[2].evidence, areas[2].remaining = "none", false, 0
    areas[2].sections = { { done = 0, total = 0 }, { done = 0, total = 0 },
      { done = 0, total = 0 }, { done = 1, total = 1 } }
  elseif screen == "achievements_detail_bronze" then
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
  -- Moments tab: illustrative records through the shipped catalog.
  if screen:find("achievements_moment", 1, true) then
    local Moments = assert(loadfile(os.getenv("KANTO_GEAR_ROOT") .. "/mod/kanto_gear/features/moments.lua"))()
    local function shown(id, info)
      local entry = Moments.byId[id]
      return { id = id, title = translate(entry.title), line = translate(entry.line), glyph = entry.glyph,
        tone = entry.tone, species = info.species, shiny = info.shiny, name = info.name, place = info.place,
        foe = info.foe, date = info.date, play = info.play }
    end
    local list = {
      shown("last_hp", { species = "CYNDAQUIL", name = "EMBER", place = gen1 and "ROUTE 3" or "ROUTE 32",
        date = "24 OCT 2026", play = "4:12", foe = "BUG CATCHER" }),
      shown("first_shiny", { species = "ZUBAT", shiny = true, name = "ZUBAT", place = "UNION CAVE",
        date = "19 OCT 2026" }),
      shown("rematch", { species = "CYNDAQUIL", name = "EMBER", place = "VIOLET CITY", date = "18 OCT 2026",
        play = "2:40", foe = "FALKNER" }) }
    local view = screen == "achievements_moment" and "moment" or "moments"
    if screen == "achievements_moments_empty" then list = {} end
    local model = { view = view, page = 1, pages = screen == "achievements_moments_pages" and 4 or 1,
      moments = list, moment = list[1], drawPokemon = drawPokemon,
      momentsUnseen = screen == "achievements_moments_unseen" }
    if screen == "achievements_moments_unseen" then model.view, model.goals, model.mode = "goals", {}, "spoiler" end
    theme:headerBar(translate("ACHIEVEMENTS"), true, false)
    theme:headerClock("20:04", "NITE", 139, 72, 6)
    theme:battery(214, 8, 4, nil, true, theme.colors.ink, theme.colors.greenLight)
    theme:achievements(model)
    return
  end
  local inside = screen == "achievements_location_inside"
  local entrance = screen ~= "achievements_location_outdoor" and { mapId = "CITY", x = 7, y = 9 } or nil
  local location = { label = "NPC TRADE", mapId = "HOUSE_5F", x = 3, y = 4 }
  theme:headerBar(view == "detail" and areas[2].name or translate("ACHIEVEMENTS"), true, false)
  theme:headerClock("20:04", "NITE", 139, 72, 6)
  theme:battery(214, 8, 4, nil, true, theme.colors.ink, theme.colors.greenLight)
  local mode = os.getenv("KANTO_GEAR_PREVIEW_STAMP_MODE") or "spoiler"
  local Progress = assert(loadfile(os.getenv("KANTO_GEAR_ROOT") .. "/mod/kanto_gear/features/achievements.lua"))()
  local goals = Progress.nextGoals({ areas[2], areas[3], areas[6] }, mode, 3)
  for _, goal in ipairs(goals) do goal.now = goal.step.target == "gold" end
  local summary = { gold = 0, silver = 0, bronze = 0, total = #areas }
  for _, area in ipairs(areas) do if summary[area.tier] then summary[area.tier] = summary[area.tier] + 1 end end
  if mode == "vanilla" then
    for _, area in ipairs(areas) do area.tier = nil end
    goals, summary = {}, nil
  end
  theme:achievements({ loading = screen == "achievements_loading", view = view, mode = mode, goal = areas[2], area = areas[2],
    goals = goals, summary = summary, step = Progress.nextStep(areas[2], mode), areaMaps = { names[2] },
    location = location, locationPoint = inside and location or entrance or location,
    entrance = entrance, inside = inside, locationFloor = inside and "5F" or nil,
    section = gen1 and "CELADON CITY" or "GOLDENROD CITY",
    drawLocation = function(x, y, w, h)
      love.graphics.setScissor(x, y, w, h)
      love.graphics.setColor(unpack(theme.colors.surface)); love.graphics.rectangle("fill", x, y, w, h)
      local left, top = math.floor(x + w / 2), math.floor(y + h / 2)
      love.graphics.setColor(unpack(theme.colors.green)); love.graphics.rectangle("fill", left - 52, top - 35, 104, 70)
      love.graphics.setColor(unpack(theme.colors.band)); love.graphics.rectangle("fill", left - 48, top - 31, 96, 62)
      love.graphics.setColor(unpack(theme.colors.amber)); love.graphics.rectangle("fill", left - 3, top - 3, 7, 7)
      love.graphics.setColor(unpack(theme.colors.ink)); love.graphics.rectangle("fill", left - 1, top - 1, 3, 3)
      love.graphics.setScissor()
    end,
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
