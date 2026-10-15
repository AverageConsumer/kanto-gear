-- Illustrative Day-Care and Calendar data; the preview draws the shipped
-- renderers with models built by the shipped model code.
return function(theme, screen, gen1, translate, format, root, drawPokemon, modelOnly)
  local function module(path) return assert(loadfile(root .. "/mod/kanto_gear/" .. path))() end
  local function frame(title)
    theme:headerBar(title, true, false)
    theme:headerClock("20:04", "NITE", 139, 72, 6)
    theme:battery(214, 8, 4, nil, true, theme.colors.ink, theme.colors.greenLight)
  end
  local mode = os.getenv("KANTO_GEAR_PREVIEW_STAMP_MODE") or "spoiler"
  local open = mode ~= "vanilla"
  if screen:sub(1, 7) == "daycare" then
    local Daycare = module("features/daycare.lua")
    local policy = { odds = open, eggSpecies = mode == "spoiler", eggProgress = mode == "spoiler" }
    local input
    if gen1 or screen == "daycare_gen1" then
      local learned, forgotten, after = Daycare.learnedMoves({ "THUNDERSHOCK", "GROWL", "TAIL WHIP", "QUICK ATTACK" },
        { { level = 16, move = "THUNDER WAVE" }, { level = 26, move = "SWIFT" } }, 12, 27)
      input = { generation = 1, place = "ROUTE 5", parents = { { key = "boarder", mon = { slot = 1 },
        name = "PIKACHU", levelFrom = 12, levelNow = 27, learned = learned, forgotten = forgotten, after = after } } }
    else
      input = {
        generation = screen == "daycare_frlg" and 3 or 2, place = screen == "daycare_frlg" and "FOUR ISLAND" or "ROUTE 34",
        partyCount = screen == "daycare_waiting" and 6 or 4, partyMax = 6,
        parents = {
          { key = "man", mon = { slot = 2 }, name = "MARILL", gender = "male", levelFrom = 19, levelNow = 25,
            learned = { "RAIN DANCE" }, forgotten = {}, after = { "TACKLE", "DEFENSE CURL", "TAIL WHIP", "RAIN DANCE" } },
          { key = "lady", mon = { slot = 1 }, name = "TOTODILE", gender = "female", levelFrom = 22, levelNow = 27,
            learned = {}, forgotten = {}, after = { "SCRATCH", "LEER", "RAGE", "WATER GUN" } },
        },
        compatibilityValue = screen == "daycare_frlg" and 50 or 128, breeding = true, stepsToCheck = 98,
        eggWaiting = screen == "daycare_waiting",
        egg = { species = 158, speciesName = "TOTODILE", moves = { "SURF", "ICE PUNCH" } },
        eggs = {
          { slot = 3, mon = { isEgg = true }, cycles = 1, steps = 260, total = 5120, speciesName = "TOGEPI" },
          { slot = 4, mon = { isEgg = true }, cycles = 19, steps = 4860, total = 5120, speciesName = "TOTODILE" },
        },
        hatchBoost = screen == "daycare_eggs" and nil or nil,
      }
      if screen == "daycare_empty" then input.parents, input.eggs = {}, {} end
      if screen == "daycare_single" then input.parents = { input.parents[2] } end
      if screen == "daycare_none" then input.compatibilityValue = 0 end
    end
    local model = Daycare.build(input, policy)
    model.place = input.place
    model.headline = Daycare.headline(model)
    model.drawPokemon = drawPokemon
    if screen == "daycare_frlg" then
      local extra = Daycare.build({ generation = 1, parents = { { key = "route5", mon = { slot = 3 },
        name = "ODDISH", levelFrom = 14, levelNow = 18, learned = { "STUN SPORE" }, forgotten = { "ABSORB" },
        after = { "SWEET SCENT", "POISONPOWDER", "STUN SPORE", "ACID" } } } }, {})
      model.boarder = extra.parents[1]; model.boarder.place = "ROUTE 5"
    end
    model.view = screen:sub(1, 12) == "daycare_eggs" and "eggs" or screen == "daycare_parent" and "parent"
      or screen == "daycare_route5" and "boarder" or nil
    if screen == "daycare_eggs_six" then
      for slot = 3, 6 do
        model.eggs[slot] = { slot = slot, mon = { isEgg = true }, stage = 2, steps = 3000, speciesName = "TOGEPI" }
      end
    end
    if screen == "daycare_route5" then
      local extra = Daycare.build({ generation = 1, parents = { { key = "route5", mon = { slot = 3 },
        name = "ODDISH", levelFrom = 14, levelNow = 18, learned = { "STUN SPORE" }, forgotten = { "ABSORB" },
        after = { "SWEET SCENT", "POISONPOWDER", "STUN SPORE", "ACID" } } } }, {})
      model.generation, model.boarder = 3, extra.parents[1]; model.boarder.place = "ROUTE 5"
    end
    model.selected = "man"
    if modelOnly then return model end
    frame(translate(model.view == "parent" and "MARILL" or "DAY-CARE"))
    theme:daycare(model)
    return model
  end
  if screen:sub(1, 8) == "calendar" then
    local C = module("features/calendar.lua")
    local function row(kind, tag, title, place, state, extra)
      local out = { kind = kind, tag = tag, title = (extra or {}).raw and title or translate(title), place = place,
        state = state,
        key = kind .. ":" .. title }
      for k, v in pairs(extra or {}) do out[k] = v end
      return out
    end
    local joey = row("rematch", "BATTLE", "JOEY", "ROUTE 30", "open", { trainerClass = "YOUNGSTER" })
    local gina = row("phone_gift", "GIFT", "LEAF STONE", "ROUTE 34", "open", { trainerClass = "PICNICKER", trainer = "GINA" })
    local buena = row("buena", "RADIO", "BUENA'S PASSWORD", "RADIO TOWER", "open")
    local berries = row("berries", "BERRIES", format("%d TREES READY", 3), "ROUTE 30", "open",
      { raw = true, placeList = { "ROUTE 30", "ROUTE 31", "VIOLET CITY" } })
    local arthur = row("gift", "GIFT", "HARD STONE", "ROUTE 36", "open", { day = 4 })
    local contest = row("contest", "EVENT", "BUG-CATCHING CONTEST", "NATIONAL PARK", "done", { day = 4 })
    local liz = row("call", "CALL", "LIZ", "ROUTE 32", "missed", { day = 4, when = { "AFTERNOON" }, trainerClass = "PICNICKER" })
    local haircut = row("haircut", "SERVICE", "HAIRCUT BROTHERS", "GOLDENROD CITY", "open", { day = 4 })
    local days = { [0] = { row("call", "CALL", "GINA", "ROUTE 34", nil, { day = 0, when = { "AFTERNOON" } }),
        row("gift", "GIFT", "MAGNET", "ROUTE 37", nil, { day = 0 }),
        row("gift", "GIFT", "TM27 / TM21", "GOLDENROD DEPT. STORE", nil, { day = 0 }) },
      { row("call", "CALL", "JOEY", "ROUTE 30", nil, { day = 1, when = { "AFTERNOON" } }),
        row("gift", "GIFT", "SHARP BEAK", "ROUTE 40", nil, { day = 1 }) },
      { row("contest", "EVENT", "BUG-CATCHING CONTEST", "NATIONAL PARK", nil, { day = 2 }),
        row("call", "CALL", "WADE", "ROUTE 31", nil, { day = 2, when = { "NIGHT" } }) },
      { row("gift", "GIFT", "BLACKBELT", "LAKE OF RAGE", nil, { day = 3 }),
        row("tutor", "TUTOR", "MOVE TUTOR", "GOLDENROD CITY", nil, { day = 3 }) },
      { arthur, contest, liz, haircut },
      { row("wild", "WILD", "LAPRAS", "UNION CAVE", nil, { day = 5 }),
        row("gift", "GIFT", "POISON BARB", "ROUTE 32", nil, { day = 5 }) },
      { row("gift", "GIFT", "SPELL TAG", "BLACKTHORN CITY", nil, { day = 6 }),
        row("contest", "EVENT", "BUG-CATCHING CONTEST", "NATIONAL PARK", nil, { day = 6 }),
        row("tutor", "TUTOR", "MOVE TUTOR", "GOLDENROD CITY", nil, { day = 6 }) } }
    if screen:sub(1, 14) == "calendar_hoenn" or screen:sub(1, 13) == "calendar_frlg" then
      -- Gen 3: no weekdays; rows arrive named and timed by runtime/calendar_gen3.lua.
      local function gen3(kind, tag, title, place, state, extra)
        local out = { kind = kind, tag = tag, title = title, place = place, state = state, key = kind .. ":" .. title,
          now = state == "open" }
        for k, v in pairs(extra or {}) do out[k] = v end
        return out
      end
      local model = { gen3 = true, noWeek = true, now = {}, today = {}, days = {}, dayNames = C.DAYS,
        shortNames = C.SHORT }
      for day = 0, 6 do model.days[day] = {} end
      local rows
      if screen:sub(1, 13) == "calendar_frlg" then
        model.badge = { "60%", translate("CHARGE") }
        model.comingUp = true
        model.hero = { kind = "seeker", charge = 60, max = 100, title = "VS SEEKER",
          status = format("%d STEPS TO GO", 40) }
        rows = screen == "calendar_frlg_empty" and {} or {
          gen3("rematch", "BATTLE", translate("1 TRAINER IS READY"), "ROUTE 24", "open",
            { status = translate("WANTS A REMATCH") }),
          gen3("seeker", "BATTLE", "VS SEEKER", nil, "later", { right = format("%d STEPS", 40),
            facts = { { "BATTERY", format("%d/%d STEPS", 60, 100) } }, status = translate("WALK TO CHARGE IT") }) }
        if screen == "calendar_frlg_empty" then model.badge, model.hero = { "-", translate("CHARGE") }, nil end
        if screen == "calendar_frlg_full" then
          model.hero.charge, model.hero.status = 100, translate("READY TO USE")

        end
      else
        model.badge = { "16:42", translate("TODAY") }
        model.hero = { kind = "day", minutes = 16 * 60 + 42, clock = "16:42", tide = true, low = true,
          status = format("LOW TIDE UNTIL %s", "21:00"), marks = { { at = 22 * 60 + 30, tag = "BERRIES" } } }
        local tide = gen3("tide", "TIDE", translate("LOW TIDE"), "SHOAL CAVE", "open", {
          right = format("UNTIL %s", "21:00"), facts = { { "LOW TIDE", "3:00 - 9:00, 15:00 - 21:00" } },
          detailItems = { format("%s: %d LEFT", "SHOAL SALT", 4), format("%s: %d LEFT", "SHOAL SHELL", 2) },
          status = translate("THE INNER CAVE IS OPEN") })
        rows = {
          gen3("rematch", "BATTLE", "ROSE", "ROUTE 118", "open", { trainerClass = "AROMA LADY",
            status = translate("WANTS A REMATCH") }),
          gen3("gift", "GIFT", "RAZZ BERRY", "ROUTE 111", "open", { status = translate("ONCE A DAY") }),
          gen3("gift", "GIFT", translate("BERRY"), "ROUTE 123", "open", { trainerClass = translate("BERRY MASTER'S WIFE"),
            status = translate("ONCE A DAY") }),
          gen3("berries", "BERRIES", format("%d TREES READY", 3), "ROUTE 104", "open",
            { placeList = { "ROUTE 104", "ROUTE 111", "ROUTE 123" }, status = translate("PICK THEM UP") }),
          gen3("water", "BERRIES", format("%d TREES NEED WATER", 2), "ROUTE 102", "open",
            { placeList = { "ROUTE 102" }, status = translate("WATER THEM FOR MORE BERRIES") }),
          tide,
          gen3("ripening", "BERRIES", translate("NEXT HARVEST"), "ROUTE 102", "later",
            { right = format("IN %d H", 9), status = format("RIPE %s", format("IN %d H", 9)) }),
          gen3("lottery", "EVENT", translate("LOTTERY CORNER"), "LILYCOVE CITY", "done"),
        }
        if screen == "calendar_hoenn_quiet" then
          rows = { rows[7], rows[8] }; rows[1].now = false
          model.hero.tide, model.hero.low, model.hero.status = false, false, format("NEW DAY IN %d H", 8)
        end
        if screen == "calendar_hoenn_detail" then model.view, model.entry = "detail", tide end
        if screen == "calendar_hoenn_detail_gift" then model.view, model.entry = "detail", rows[3] end
      end
      if model.hero and model.hero.kind == "seeker" and screen ~= "calendar_frlg_detail" then rows[2] = nil end
      for _, row in ipairs(rows) do
        if row.now then model.now[#model.now + 1] = row else model.today[#model.today + 1] = row end
      end
      if screen == "calendar_frlg_detail" then model.view, model.entry = "detail", rows[2] end
      if modelOnly then return model end
      frame(model.entry and model.entry.title or translate("CALENDAR"))
      theme:calendar(model)
      return model
    end
    local model = { weekday = 4, period = "NITE", dayNames = C.DAYS, shortNames = C.SHORT,
      now = { joey, gina, arthur, haircut, buena, berries }, today = { arthur, haircut, liz, contest }, days = days }
    if screen == "calendar_quiet" then model.now, model.today = {}, { contest } end
    if screen == "calendar_day" then model.day = 5 end
    if screen == "calendar_page2" then model.page = 2 end
    if screen:sub(1, 15) == "calendar_detail" then
      model.view = "detail"
      model.entry = screen == "calendar_detail_call" and liz or screen == "calendar_detail_gift" and arthur
        or screen == "calendar_detail_phone_gift" and gina
        or screen == "calendar_detail_berries" and berries or joey
    end
    if modelOnly then return model end
    frame(model.entry and model.entry.title or translate("CALENDAR"))
    theme:calendar(model)
    return model
  end
end
