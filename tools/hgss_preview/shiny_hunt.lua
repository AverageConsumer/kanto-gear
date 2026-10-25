-- Illustrative Shiny Hunt states; the preview draws the shipped renderer
-- with view models built by the shipped model code.
return function(theme, screen, gen1, translate, format, root, drawPortrait, modelOnly)
  local S = assert(loadfile(root .. "/mod/kanto_gear/features/shiny_hunt.lua"))()
  local slots = { PIDGEY = 3, ABRA = 6, SENTRET = 5, TOGEPI = 4, MARILL = 1, ZUBAT = 2 }
  local state = S.normalize(nil)
  local t = 100000
  local function at(seconds) t = t + seconds; return t end
  if screen == "home-shiny-lucky" then
    S.observe(state, { via = "battle", species = "ZUBAT", name = "ZUBAT", shiny = true, place = "UNION CAVE" }, at(0))
  elseif screen ~= "shiny_idle" and screen ~= "home-shiny-idle" then
    local target = (screen == "shiny_eggs" or screen == "shiny_eggs_odds") and "TOGEPI" or "ABRA"
    S.setTarget(state, target, target, at(0))
    if target == "TOGEPI" then
      for index = 1, 214 do S.observe(state, { via = "egg", species = "TOGEPI", boosted = index > 120 }, at(40)) end
    else
      for index = 1, 3486 do
        S.observe(state, { via = "battle", species = index % 5 == 0 and "PIDGEY" or "ABRA" }, at(9))
      end
    end
    S.setTarget(state, "MARILL", "MARILL", at(5))
    S.adjust(state, 912, at(5))
    S.setTarget(state, target, nil, at(5))
    S.observe(state, { via = "battle", species = "SENTRET", name = "SENTRET", shiny = true, place = "ROUTE 29" }, at(9))
    S.observe(state, { via = "battle", species = "PIDGEY", name = "PIDGEY" }, at(9))
    if screen:find("found") then
      S.observe(state, { via = "battle", species = "ABRA", name = "ABRA", shiny = true }, at(9))
    end
    if screen == "shiny_log" then
      state.log[#state.log + 1] = { species = "ZUBAT", name = "ZUBAT", kind = "lucky", count = 0, via = "battle",
        place = "UNION CAVE" }
      state.log[#state.log + 1] = { species = "TOGEPI", name = "TOGEPI", kind = "target", count = 1288, via = "egg" }
    end
  end
  if screen == "shiny_paused" then S.setAuto(state, false) end
  if screen == "shiny_found_exact" then
    S.setTarget(state, "ABRA", "ABRA", at(1))
    S.restart(state, at(1))
    S.adjust(state, 8191, at(1))
    S.observe(state, { via = "battle", species = "ABRA", name = "ABRA", shiny = true }, at(9))
  end
  local view = S.view(state)
  if screen == "home-shiny-lucky" then view.lucky = view.log[1] end
  view.generation = gen1 and 2 or 2
  view.headline = S.headline(view)
  view.group, view.percent, view.duration = S.group, S.percent, S.duration
  view.milestones = {}
  for _, share in ipairs(S.MILESTONES) do view.milestones[#view.milestones + 1] = { share = share, need = S.milestone(share) } end
  view.drawPokemon = function(species, x, y, size)
    drawPortrait(slots[species] or 1, x, y, size, false)
  end
  view.last = view.last and { species = view.last.species, name = view.last.name or view.last.species, shiny = view.last.shiny }
  view.here = { now = true, methods = { { name = "WALK", chance = 15 } } }
  if screen == "shiny_eggs_odds" or screen == "shiny_eggs" then
    view.here = nil
    view.boost = { species = "DITTO", name = "DITTO", ditto = true }
  end
  if view.hunt and view.hunt.any then view.hunt.name = translate("ANY POKEMON") end
  if screen == "shiny_pick" then
    view.view = "pick"
    view.pick = { page = 1, rows = {
      { any = true, species = "*", name = translate("ANY POKEMON"), section = "ANYTHING" },
      { species = "PIDGEY", name = "PIDGEY", section = "LAST MET" },
      { species = "ABRA", name = "ABRA", section = "THIS AREA", method = "WALK", chance = 15, count = 3486, active = true },
      { species = "SENTRET", name = "SENTRET", section = "THIS AREA", method = "WALK", chance = 30 },
      { species = "ZUBAT", name = "ZUBAT", section = "THIS AREA", method = "WALK", chance = 10 },
      { species = "MARILL", name = "MARILL", section = "YOUR PARTY", count = 912 },
      { species = "TOGEPI", name = "TOGEPI", section = "YOUR PARTY" },
    } }
  elseif screen == "shiny_odds" or screen == "shiny_eggs_odds" then view.view = "odds"
  elseif screen == "shiny_log" then view.view = "log" end
  if modelOnly then return view end
  theme:headerBar(translate(view.view == "pick" and "PICK A TARGET" or "SHINY HUNT"), true, false)
  theme:headerClock("20:04", "NITE", 139, 72, 6)
  theme:battery(214, 8, 4, nil, true, theme.colors.ink, theme.colors.greenLight)
  theme:shinyHunt(view)
  return view
end
