return function(
  Area, Discovery, THEME, areaMaps, areaName, assist,
  checklistPages, compat, displayRuntime, guideData, locationEntries, mod,
  oneShotTrainerStatus, session
)
  -- Game path [Gen 1/2/3]: Gen 3 delegates to script proofs, Gen 2 to event tables, while Gen 1 below reads native pickup/trainer sets.
  local function areaData(mapIds, completion, checkpoint)
    local sections = { { name = "TRAINERS", rows = {} },
      { name = "ITEMS", rows = {} }, { name = "HIDDEN", rows = {},
        perPage = assist("item_radar") and 3 or 4 } }
    local data, save = session.game.data, session.game.save
    local field = data.field or {}
    local maps = mapIds or areaMaps(session.mapId)
    if displayRuntime.gen3 then
      local rows = displayRuntime.gen3Progress:rows(maps, checkpoint)
      for index = 1, 3 do sections[index].rows = rows[index] end
      if not completion then displayRuntime.visibleAreaSections(sections) end
      local screens = checklistPages(sections)
      return { name = areaName(session.mapId), screens = screens, pages = #screens,
        sections = sections, pokemon = rows[4], remaining = Area.remaining(sections) }
    end
    if compat.isGen2() then
      local rows = Area.gen2Rows(data, save, mod.world, maps, checkpoint)
      for index = 1, 3 do sections[index].rows = rows[index] end
      if not completion then displayRuntime.visibleAreaSections(sections) end
      local screens = checklistPages(sections)
      return { name = areaName(session.mapId), screens = screens, pages = #screens,
        sections = sections, pokemon = rows[4], remaining = Area.remaining(sections) }
    end
    local pokemon = {}
    local showFuture = completion or assist("future_tasks")
    for _, id in ipairs(maps) do
      if checkpoint then checkpoint() end
      local map = data.maps and data.maps[id]
      if not map then
        sections[1].rows[#sections[1].rows + 1] = {
          mapId = id, label = "NOT TRACKED", untracked = true, unknown = true,
        }
      end
      for _, obj in ipairs(map and map.objects or {}) do
        local key = id .. "_obj_" .. tostring(obj.index)
        local scripted = Area.gen1ScriptTrainer(id, obj)
        local trainerClass = scripted and scripted.class or obj.trainerClass
        if trainerClass then
          local trainer = data.trainers and data.trainers[trainerClass]
          local label = scripted and scripted.label or trainer and trainer.name
            or tostring(trainerClass):gsub("^OPP_", "")
          if tostring(trainerClass):match("^OPP_RIVAL") then
            label = (save.player and save.player.rival)
              or (save.rival and save.rival.name) or label
          end
          local done = save.defeatedTrainers
            and save.defeatedTrainers[key] == true or false
          if not done and map.label and data.trainerHeader then
            local header_ = data:trainerHeader(map.label, obj.index)
            done = header_ and header_.event and save.flags
              and save.flags[header_.event] == true or false
          end
          local status, missed, available
          if scripted then
            local state = Area.gen1TrainerState(save, scripted)
            done, missed, available, status = done or state.done,
              state.missed, state.available, state.status
          end
          -- Game path [Gen 1]: the one-shot lab rival can be lost; its completion flag alone must not be reported as a battle win.
          if id == "OAKS_LAB" and obj.index == 1
              and obj.trainerClass == "OPP_RIVAL1" then
            done, status = oneShotTrainerStatus(done,
              save.flags and save.flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB == true,
              mod.save:get("oak_lab_rival_result"))
          end
          if Area.gen1TrainerMissed(save, id, done) then
            done, missed, available, status = true, true, false, "MISSED"
          end
          if not scripted or available or done or showFuture then
            sections[1].rows[#sections[1].rows + 1] = {
              label = label, done = done, missed = missed,
              available = available, status = status,
              id = key, mapId = id, index = obj.index,
              x = obj.x, y = obj.y,
              spriteId = obj.sprite,
              required = scripted and not scripted.optional or obj.trainerClass == "OPP_GIOVANNI",
              optional = scripted and scripted.optional or id == "OAKS_LAB"
                and obj.index == 1 and obj.trainerClass == "OPP_RIVAL1",
            }
          end
        elseif obj.item and obj.item ~= "0" and obj.item ~= 0 then
          local item = data.items and data.items[obj.item]
          sections[2].rows[#sections[2].rows + 1] = Area.pickupBounds({
            label = item and item.name or obj.item,
            done = save.itemsTaken and save.itemsTaken[key] == true or false,
            mapId = id, x = obj.x, y = obj.y, kind = "item", itemId = obj.item,
          }, map)
        end
      end
      for _, gift in ipairs(Area.gen1Gifts(data, save, id, map, checkpoint)) do
        local rows = gift.species and pokemon or sections[2].rows
        rows[#rows + 1] = Area.pickupBounds(gift, map)
      end
      for _, hidden in ipairs(field.hiddenItems and field.hiddenItems[id] or {}) do
        local item = data.items and data.items[hidden.item]
        local key = id .. "_" .. hidden.x .. "_" .. hidden.y
        sections[3].rows[#sections[3].rows + 1] = Area.pickupBounds({
          label = item and item.name or hidden.item,
          done = save.hiddenTaken and save.hiddenTaken[key] == true or false,
          mapId = id, x = hidden.x, y = hidden.y, kind = "hidden",
        }, map)
      end
      for _, hidden in ipairs(field.hiddenCoins and field.hiddenCoins[id] or {}) do
        local key = id .. "_" .. hidden.x .. "_" .. hidden.y
        sections[3].rows[#sections[3].rows + 1] = Area.pickupBounds({
          label = THEME:format("%d COINS", hidden.coins),
          done = save.hiddenTaken and save.hiddenTaken[key] == true or false,
          mapId = id, x = hidden.x, y = hidden.y, kind = "hidden",
        }, map)
      end
    end
    if not completion then displayRuntime.visibleAreaSections(sections) end
    local screens = checklistPages(sections)
    return { name = areaName(session.mapId), screens = screens, pages = #screens,
      sections = sections, pokemon = pokemon, remaining = Area.remaining(sections) }
  end

  function displayRuntime.achievementData(currentOnly, advance)
    local state, Progress = displayRuntime.achievements, displayRuntime.Achievements
    if displayRuntime.gen3Progress then
      local source = displayRuntime.gen3Progress:bundle()
      local keys = displayRuntime.gen3Progress:completionKey()
      if state.source ~= source or state.dexRevision ~= displayRuntime.gen3.dexRevision
          or state.progressKeys ~= keys then
        state.source, state.dexRevision = source, displayRuntime.gen3.dexRevision
        state.progressKeys = keys
        state.stale, state.currentData, state.job = true, nil, nil
      end
    end
    -- Game path [Gen 1]: itemsTaken/hiddenTaken may change without flag events, so cached progress also checks their contents.
    -- Gen 1 pickups update these sets without a flag event. Compare only when
    -- the app or cached Home data is refreshed, and between active album slices.
    local pickups = 0
    for _, field in ipairs({ "itemsTaken", "hiddenTaken" }) do
      for _, taken in pairs(session.game.save[field] or {}) do if taken then pickups = pickups + 1 end end
    end
    if pickups ~= state.pickups then
      state.pickups, state.stale, state.currentData, state.job = pickups, true, nil, nil
    end
    local caught, caughtCount = compat.caughtDex(session.game.save), 0
    for _, owned in pairs(caught) do if owned then caughtCount = caughtCount + 1 end end
    if caughtCount ~= state.caughtCount then
      state.caughtCount, state.stale, state.currentData, state.job = caughtCount, true, nil, nil
    end
    if state.job and (state.jobMap ~= session.mapId or state.jobSave ~= session.game.save) then
      state.job, state.stale = nil, true
    end
    if not currentOnly and state.contextDirty and state.data and not state.stale then
      local visited = mod.save:get("achievement_visits", {})
      state.data = Progress.relocate(state.data, { mapId = session.mapId, save = session.game.save,
        visited = type(visited) == "table" and visited or {} })
      state.contextDirty = false
    end
    local current = state.currentData
    if currentOnly and current and current.mapId == session.mapId and current.save == session.game.save then
      return current.data
    end
    if currentOnly or not state.job and (not state.data or state.stale) then
      local gen2 = compat.isGen2()
      local visited = mod.save:get("achievement_visits", {})
      if type(visited) ~= "table" then visited = {} end
      state.groups = state.groups or Progress.groups(gen2 and session.game.data.gen2Maps
        or session.game.data.maps, locationEntries())
      state.species = state.species or {}
      -- Home needs one location only. Never rebuild the complete stamp book
      -- in the map animation path; encounters are cached per location as well.
      local groups = state.groups
      if currentOnly then
        groups = {}
        for _, group in ipairs(state.groups) do
          for _, id in ipairs(group.maps) do
            if id == session.mapId then groups[1] = group; break end
          end
          if groups[1] then break end
        end
      end
      local build = currentOnly and Progress.build or Progress.begin
      local result = build(groups, function(maps, checkpoint)
        local result = areaData(maps, true, checkpoint)
        if checkpoint then checkpoint() end
        if displayRuntime.gen3Progress then
          result.pokemon = displayRuntime.gen3Progress:pokemon(maps, checkpoint, result.pokemon)
          return result
        end
        local species = state.species[maps[1]]
        if not species then
          species = guideData(maps, true, checkpoint).rows
          state.species[maps[1]] = species
        end
        result.pokemon = result.pokemon or {}
        for _, row in ipairs(species) do
          result.pokemon[#result.pokemon + 1] = { species = row.species,
            label = (session.game.data.pokemon[row.species] or {}).name or row.name,
            order = row.order, done = caught[row.species] == true, wild = true,
            mapId = row.appearances[1] and row.appearances[1].mapId,
            -- Kept for the next-stamp hints (time of day, rod, Headbutt...).
            appearances = row.appearances,
          }
        end
        return result
      end, {
        gen2 = gen2, gen3 = displayRuntime.gen3 ~= nil, save = session.game.save, mapId = session.mapId,
        visited = visited,
        flag = function(id) return mod.world and mod.world.getFlag
          and mod.world:getFlag(id) == true or false end,
      }, not currentOnly and love.timer.getTime or nil)
      if currentOnly then
        state.currentData = { mapId = session.mapId, save = session.game.save, data = result }
        return result
      end
      state.job, state.jobMap, state.jobSave = result, session.mapId, session.game.save
    end
    if not currentOnly and advance and state.job then
      local result = state.job:step(0.001)
      if result then
        state.data, state.stale, state.job = result, false, nil
        state.contextDirty = false
        session.dirty = true
      end
    end
    -- Hide invalidated results until the replacement is complete.
    return not state.stale and state.data or nil
  end

  -- Whether a still-missing local Pokemon can appear here right now with the
  -- player's current tools. Shared by the stamp widget and the Goals list.
  function displayRuntime.stampCatchableNow(area, methods)
    if not area or not assist("habitats") or not assist("encounter_details") then return false end
    local period = compat.timePeriod(session.game.world) or "DAY"
    methods = methods or displayRuntime.habitatMethods()
    local inArea = {}
    for _, id in ipairs(area.maps or {}) do inArea[id] = true end
    for _, row in ipairs(area.sections[4] and area.sections[4].rows or {}) do
      if row.wild and row.state == "open" then
        for _, appearance in ipairs(row.appearances or {}) do
          if inArea[appearance.mapId] and displayRuntime.knownMap(appearance.mapId)
              and (not appearance.time or appearance.time == period)
              and not methods[appearance.method] then return true end
        end
      end
    end
    return false
  end

  function displayRuntime.currentAchievement()
    local mode = displayRuntime.discoveryMode()
    local area = displayRuntime.perf:call("stamps_current", displayRuntime.achievementData, true).areas[1]
    area = area and displayRuntime.presentAchievement(area)
    local step = area and displayRuntime.Achievements.nextStep(area, mode)
    return { area = area, mode = mode, step = step,
      now = step ~= nil and step.target == "gold" and displayRuntime.stampCatchableNow(area) }
  end

  function displayRuntime.presentAchievement(area)
    Discovery.current()
    return displayRuntime.Achievements.presentArea(area, session.discoveryPolicy, function(row, category)
      if category == 4 then
        if row.gift then
          return Discovery.row(session.discoveryPolicy, row, category, displayRuntime.knownMap(row.mapId))
        end
        return (assist("wild") or row.done) and displayRuntime.knownMap(row.mapId) and displayRuntime.knownSpecies(row.species)
      end
      return Discovery.row(session.discoveryPolicy, row, category, displayRuntime.knownMap(row.mapId))
    end)
  end

  function displayRuntime.achievementModel()
    local state, Progress = displayRuntime.achievements, displayRuntime.Achievements
    local mode = displayRuntime.discoveryMode()
    local data = displayRuntime.achievementData()
    if not data then return { loading = true, view = state.view, mode = mode, pages = 1 } end
    if state.presentSource ~= data or state.presentMode ~= session.discoveryPolicy.signature then
      local presented = { areas = {}, goals = {}, earned = {}, byId = {} }
      for _, area in ipairs(data.areas) do presented.byId[area.id] = displayRuntime.presentAchievement(area) end
      for _, key in ipairs({ "areas", "goals", "earned" }) do
        for _, area in ipairs(data[key]) do presented[key][#presented[key] + 1] = presented.byId[area.id] end
      end
      state.presentSource, state.presentMode, state.presented = data, session.discoveryPolicy.signature, presented
    end
    local presented = state.presented
    local areas, goals, earned = Progress.visible(presented, mode, session.discoveryPolicy)
    local area = state.selected and presented.byId[state.selected]
    if area and not assist("unvisited_maps") and not area.evidence then area = nil end
    if not area and state.view ~= "album" and state.view ~= "goals" then state.view = "album" end
    if state.view == "location" and (not assist("area_map") or not state.location
        or not Discovery.row(session.discoveryPolicy, state.location, state.category,
          displayRuntime.knownMap(state.location.mapId))) then
      state.view, state.location, state.locationEntrance, state.locationPoint = "detail", nil, nil, nil
    end
    if state.view == "location" and state.location then
      displayRuntime.loadAchievementLocation(state.locationPoint or state.location)
    end
    if state.view == "habitat" and state.habitat then
      if not assist("habitats") or not displayRuntime.knownSpecies(state.habitat.species) then
        state.view, state.habitat = "finds", nil
      else
        local plan = displayRuntime.pokedexHabitatPlan(state.habitat)
        local rows, current, pages = displayRuntime.PokedexPage.window(plan.rows, state.habitatPage, 3)
        state.habitatPage = current
        local info = displayRuntime.pokedexPokemon(state.habitat.species, state.habitat.label)
        return { view = "habitat", area = area, mode = mode, pages = pages,
          habitat = { pokemon = info, page = current, pages = pages,
            summary = THEME:format("NO.%03d", tonumber(info.dex) or 0),
            matchText = area.name, rows = displayRuntime.habitatRows(rows),
            drawPokemon = displayRuntime.drawAchievementPokemon } }
      end
    end
    local entries = (state.view == "finds" or state.view == "location") and area
      and Progress.visibleRows(area, state.category, "filtered") or areas
    local size = (state.view == "finds" or state.view == "location")
      and (state.category == 4 and 3 or 4) or 6
    local pages = math.max(1, math.ceil(#entries / size))
    state.page = math.max(1, math.min(state.page or 1, pages))
    local shown = {}
    for index = (state.page - 1) * size + 1, math.min(#entries, state.page * size) do
      local entry = entries[index]
      if entry.appearances then
        local copy = {}
        for key, value in pairs(entry) do copy[key] = value end
        copy.appearances = Discovery.filter(entry.appearances, function(appearance)
          return displayRuntime.knownMap(appearance.mapId)
        end)
        entry = copy
      end
      shown[#shown + 1] = entry
    end
    -- Next-stamp guidance: the closest goals, what the stamp book holds, and
    -- whether a still-missing local Pokemon can appear at the current time.
    local period = compat.timePeriod(session.game.world) or "DAY"
    local nextGoals = Progress.nextGoals(goals, mode, 3)
    local methods
    for _, goal in ipairs(nextGoals) do
      if goal.step.target == "gold" and assist("habitats") and assist("encounter_details") then
        methods = methods or displayRuntime.habitatMethods()
      end
      goal.now = goal.step.target == "gold" and displayRuntime.stampCatchableNow(goal.area, methods)
    end
    local summary = { gold = 0, silver = 0, bronze = 0, total = #areas }
    for _, entry in ipairs(areas) do
      if summary[entry.tier] then summary[entry.tier] = summary[entry.tier] + 1 end
    end
    return { view = state.view, page = state.page, pages = pages, area = area,
      goal = goals[1], goals = nextGoals, summary = summary, period = period,
      step = area and Progress.nextStep(area, mode), areaMaps = area and area.maps,
      earned = earned, entries = shown, mode = mode,
      category = state.category, canHabitat = assist("habitats"), canLocate = assist("area_map"), canExplore = area and area.current and assist("guide"),
      canEncounterDetails = assist("encounter_details"),
      location = state.location,
      locationPoint = state.locationPoint or state.location,
      entrance = state.locationEntrance,
      inside = state.locationPoint == state.location,
      locationFloor = state.location and displayRuntime.LocationPreview.floor((state.locationPoint or state.location).mapId),
      section = state.location and displayRuntime.sectionName((state.locationPoint or state.location).mapId) or "",
      drawLocation = state.location and (state.locationImage or state.locationRenderer)
        and function(x, y, w, h) displayRuntime.drawAchievementLocation(x, y, w, h) end or nil }
  end

  function displayRuntime.cycleAchievements(direction)
    local state, model = displayRuntime.achievements, displayRuntime.achievementModel()
    if state.view ~= "goals" and (model.pages <= 1
        or state.view ~= "habitat" and state.view ~= "album" and state.view ~= "finds") then return end
    displayRuntime.requestPageMotion(direction)
    if state.view == "habitat" then
      state.habitatPage = (state.habitatPage - 1 + direction) % model.pages + 1
    elseif state.view == "album" or state.view == "finds" then
      state.page = (state.page - 1 + direction) % model.pages + 1
    elseif state.view == "goals" then state.view, state.page = "album", 1 end
    session.dirty = true
  end

  function displayRuntime.tapAchievements(x, y)
    local state = displayRuntime.achievements
    if y < 30 and x < 35 then
      if state.view == "habitat" then state.view, state.habitat = "finds", nil
      elseif state.view == "location" then
        if state.locationEntrance and state.locationPoint == state.location then
          state.locationPoint = state.locationEntrance
        else state.view, state.location, state.locationEntrance, state.locationPoint = "finds", nil, nil, nil end
      elseif state.view == "finds" then state.view, state.page = "detail", 1
      elseif state.view == "detail" then
        state.view, state.selected, state.page = state.parent or "album", nil, state.parentPage or 1
      else session.page, displayRuntime.home.activeApp = "HOME", nil end
      session.dirty = true
      return
    end
    if displayRuntime.achievements.stale then return end
    if state.view == "habitat" then
      local model = displayRuntime.achievementModel().habitat
      if model then
        model.view, model.canCycle = "habitat", model.pages > 1
        local action = displayRuntime.PokedexPage.hit(model, x, y)
        if action == "prev" or action == "next" then
          displayRuntime.cycleAchievements(action == "next" and 1 or -1)
        end
      end
      return
    end
    local action, value = THEME.hgss:achievementsHit(x, y)
    if action == "view" then state.view, state.page, state.selected = value, 1, nil
    elseif action == "area" then
      state.parent, state.parentPage = state.view, state.page
      state.selected, state.view, state.page = value, "detail", 1
    elseif action == "category" then state.category, state.view, state.page = value, "finds", 1
    elseif action == "explore" then
      local model = displayRuntime.achievementModel()
      if model.area and model.area.current and assist("guide") then
        displayRuntime.openHomeApp("explorer")
        local explorer = displayRuntime.explorer
        explorer.view, explorer.page, explorer.selected = "wild", 1, nil
        explorer.filters.wildScope = "ROUTE"
        explorer.data = nil
      end
    elseif action == "page" then displayRuntime.cycleAchievements(value)
    elseif action == "locate" and assist("area_map") then
      state.location, state.view = value, "location"
      state.locationEntrance = displayRuntime.LocationPreview.entrance(
        compat.isGen2() and session.game.data.gen2Maps or session.game.data.maps, value,
        displayRuntime.gen3 and 3 or compat.isGen2() and 2 or 1, session.mapId)
      state.locationPoint = state.locationEntrance or value
      displayRuntime.loadAchievementLocation(state.locationPoint)
    elseif action == "location_scope" and state.view == "location" and state.locationEntrance
        and assist("area_map") then
      state.locationPoint = state.locationPoint == state.location and state.locationEntrance or state.location
      displayRuntime.loadAchievementLocation(state.locationPoint)
    elseif action == "habitat" and assist("habitats") and displayRuntime.knownSpecies(value.species) then
      local area = displayRuntime.achievementModel().area
      if area then
        for _, row in ipairs(guideData(area.maps, true).rows) do
          if row.species == value.species then
            state.habitat = { species = value.species, label = value.label, habitat = row }
            state.view, state.habitatPage = "habitat", 1
            break
          end
        end
      end
    end
    session.dirty = true
  end

  return areaData
end
