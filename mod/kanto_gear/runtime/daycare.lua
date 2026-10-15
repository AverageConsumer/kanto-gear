-- Game path [Gen 1/2/3]: read the Day-Care boarders, the pending egg and the
-- party eggs into the neutral model in features/daycare.lua. Read only: the
-- host helpers used here are the pure lookups, never the ones that create or
-- advance Day-Care state.
return function(
  THEME, assist, compat, displayRuntime, drawSprite, header, locationEntry,
  mod, render, session
)
  local Daycare = displayRuntime.Daycare

  local function placeName(id, fallback)
    local entry = id and locationEntry(id)
    local name = entry and (entry.name or entry.label)
    name = name and tostring(name):gsub("<LF>", " "):gsub("\n", " ") or nil
    return name or THEME:translate(fallback or "DAY-CARE")
  end

  local function hostModule(name)
    local ok, value = pcall(require, name)
    return ok and value or nil
  end

  -- Gen 1/2 growth curves come from the shared content registry so a mod's
  -- custom curve reads the same here as in the party screen.
  local function levelForExp(growthRate, experience)
    local growth = mod.content.growth_rates:get(growthRate or "MEDIUM_FAST")
    if not (growth and growth.expForLevel) then return nil end
    local level = 1
    while level < 100 and growth.expForLevel(level + 1) <= experience do level = level + 1 end
    return level
  end

  local function moveName(data, id)
    local def = data and data.moves and data.moves[id]
    return def and def.name or tostring(id or "-"):gsub("_", " ")
  end
  local function moveNames(data, ids)
    local out = {}
    for index, id in ipairs(ids or {}) do out[index] = moveName(data, id) end
    return out
  end
  local function moveIds(mon)
    local out = {}
    for _, move in ipairs(mon and mon.moves or {}) do
      local id = type(move) == "table" and (move.id or move.move) or move
      if id and id ~= 0 then out[#out + 1] = id end
    end
    return out
  end
  local function speciesName(data, species)
    local def = data and data.pokemon and data.pokemon[species]
    return def and def.name or tostring(species or "?")
  end
  local function genderOf(value)
    value = tostring(value or ""):lower()
    if value == "male" or value == "m" then return "male" end
    if value == "female" or value == "f" then return "female" end
  end

  local function partyEggs(data, save, generation, native)
    local eggs = {}
    for slot, mon in ipairs(save and save.party or {}) do
      if compat.partyEgg(mon) then
        local details = compat.summary.details.egg(mon, generation, save, native) or {}
        local species = mon.species
        eggs[#eggs + 1] = { slot = slot, mon = mon, cycles = details.cycles, steps = details.steps,
          speciesName = species and speciesName(data, species) or nil }
      end
    end
    return eggs
  end

  -- Gen 1: one boarder on Route 5, 1 EXP per step, folded in only at pickup.
  local function gen1(game)
    local save, data = game.save or {}, game.data or {}
    local dc = save.daycare
    local input = { generation = 1, place = placeName("ROUTE_5"), parents = {},
      partyCount = #(save.party or {}), partyMax = 6, eggs = {} }
    local mon = type(dc) == "table" and dc.mon or nil
    if mon then
      local def = data.pokemon and data.pokemon[mon.species] or {}
      local from = tonumber(dc.depositLevel) or tonumber(mon.level) or 1
      local now = levelForExp(def.growthRate, (tonumber(mon.exp) or 0) + (tonumber(dc.steps) or 0)) or from
      local learned, forgotten, after = Daycare.learnedMoves(moveIds(mon), def.learnset, from, now)
      input.parents[1] = { key = "boarder", mon = mon, name = mon.nickname or def.name or mon.species,
        levelFrom = from, levelNow = math.min(100, now), after = moveNames(data, after),
        learned = moveNames(data, learned), forgotten = moveNames(data, forgotten) }
    end
    return input
  end

  -- Gen 2: the man and the lady each keep one boarder; the egg itself is
  -- built when the pair turns compatible (Breeding.initBreeding), so its
  -- species and inherited moves are already decided while it waits.
  local function gen2(game)
    local save, data = game.save or {}, game.data or {}
    local dc = type(save.dayCare) == "table" and save.dayCare or {}
    local Breeding = hostModule("src.core.gen2.Breeding")
    local input = { generation = 2, place = placeName("ROUTE_34"), parents = {},
      partyCount = #(save.party or {}), partyMax = 6,
      eggs = partyEggs(data, save, 2) }
    for _, key in ipairs({ "man", "lady" }) do
      local slot = type(dc[key]) == "table" and dc[key] or nil
      local mon = slot and slot.mon
      if mon then
        local def = data.pokemon and data.pokemon[mon.species] or {}
        local from, now = tonumber(mon.level) or 1, nil
        if Breeding and Breeding.levelGrowth then
          local ok, stored, grown = pcall(Breeding.levelGrowth, data, slot)
          if ok then from, now = stored, grown end
        end
        now = now or levelForExp(def.growthRate, tonumber(mon.experience) or 0) or from
        local learned, forgotten, after = Daycare.learnedMoves(moveIds(mon), def.levelMoves, from, now)
        local gender
        if Breeding and Breeding.genderOf then
          local ok, value = pcall(Breeding.genderOf, data, mon)
          gender = ok and genderOf(value) or nil
        end
        input.parents[#input.parents + 1] = { key = key, mon = mon,
          name = mon.nickname or def.name or mon.species, gender = gender,
          levelFrom = from, levelNow = now, after = moveNames(data, after),
          learned = moveNames(data, learned), forgotten = moveNames(data, forgotten) }
      end
    end
    if #input.parents == 2 and Breeding and Breeding.compatibility then
      local ok, value = pcall(Breeding.compatibility, data, dc.man.mon, dc.lady.mon, { dayCare = true })
      input.compatibilityValue = ok and value or nil
    end
    input.breeding = dc.compatible == true
    input.eggWaiting = dc.hasEgg == true
    input.stepsToCheck = dc.compatible and Daycare.gen2StepsToCheck(dc.stepsToEgg) or nil
    if type(dc.egg) == "table" then
      input.egg = { species = dc.egg.species, speciesName = speciesName(data, dc.egg.species),
        moves = moveNames(data, moveIds(dc.egg)) }
    end
    return input
  end

  -- Gen 3 map ids differ per edition (FR_ROUTE_5, SEVII_FOUR_ISLAND, ...);
  -- the native map-section name is what the game itself shows.
  local function gen3Place(adapter, pattern)
    local ids = {}
    for id in pairs(adapter:locations() or {}) do
      if tostring(id):match(pattern) then ids[#ids + 1] = id end
    end
    table.sort(ids)
    local entry = ids[1] and adapter:locations()[ids[1]]
    return entry and entry.name or THEME:translate("DAY-CARE")
  end

  -- Gen 3: Four Island / Route 117 keep a breeding pair; FireRed/LeafGreen
  -- also board a single Pokemon on Route 5. Experience is applied at pickup
  -- (ApplyDaycareExperience), so the stored mon still shows its old level.
  local function gen3(game)
    local adapter = displayRuntime.gen3
    local native = adapter and adapter.session
    local input = { generation = 3, parents = {}, partyCount = 0, partyMax = 6, eggs = {} }
    if not native then return input end
    local Host = hostModule("src.core.game3.daycare")
    local HostBreeding = hostModule("src.core.game3.breeding")
    local profile = adapter.profile or {}
    local key = profile.family == "rse" and tostring(profile.id) .. "_daycare" or "firered_daycare"
    local root = type(native.modData) == "table" and native.modData[key] or nil
    local dc = rawget(native, "daycare") or root and root.daycare
    local data = adapter.data or {}
    input.place = gen3Place(adapter, profile.family == "rse" and "ROUTE_?117$" or "FOUR_ISLAND$")
    input.partyCount = #(native.party or {})
    local function boarder(mon, steps, slotKey)
      local view = adapter:mon(mon)
      local def = data.pokemon and data.pokemon[view.species] or {}
      local from = tonumber(mon.level) or 1
      local now = from
      if Host and Host.levelAfterSteps then
        local ok, value = pcall(Host.levelAfterSteps, mon, steps)
        if ok and tonumber(value) then now = math.min(100, value) end
      end
      local learned, forgotten, after = Daycare.learnedMoves(moveIds(view), def.learnset, from, now)
      return { key = slotKey, mon = view, name = view.nickname or def.name or speciesName(data, view.species),
        gender = genderOf(view.gender), levelFrom = from, levelNow = now, after = moveNames(data, after),
        learned = moveNames(data, learned), forgotten = moveNames(data, forgotten) }
    end
    if type(dc) == "table" then
      for index = 1, 2 do
        local mon = dc[index] or dc.mons and dc.mons[index]
        if type(mon) == "table" and (tonumber(mon.species or mon.speciesId) or 0) ~= 0 then
          input.parents[#input.parents + 1] = boarder(mon, dc.steps and dc.steps[index] or 0, index)
        end
      end
      if #input.parents == 2 and HostBreeding and HostBreeding.compatibility then
        local ok, value = pcall(HostBreeding.compatibility, dc, native)
        input.compatibilityValue = ok and value or nil
      end
      input.breeding = true
      input.eggWaiting = Host and Host.isEggPending and Host.isEggPending(dc) or false
      input.stepsToCheck = #input.parents == 2 and Daycare.gen3StepsToCheck(dc.steps and dc.steps[2]) or nil
      if #input.parents == 2 and (input.compatibilityValue or 0) > 0 and HostBreeding
          and HostBreeding.parentSlots then
        -- DetermineEggSpeciesAndParentSlots plus the incense rule, both pure.
        local ok, species = pcall(HostBreeding.parentSlots, dc)
        if ok and HostBreeding.alterEggSpeciesWithIncenseItem then
          local altered, value = pcall(HostBreeding.alterEggSpeciesWithIncenseItem, species, dc)
          if altered then species = value end
        end
        if ok and tonumber(species) and species ~= 0 then
          local name = speciesName(data, species)
          -- Nidoran and Volbeat/Illumise pick their line from the egg's own
          -- personality, which does not exist until the egg is laid.
          local partner = ({ [29] = 32, [387] = 386 })[species]
          if partner and not input.eggWaiting then name = name .. " / " .. speciesName(data, partner) end
          input.egg = { species = species, speciesName = name, moves = {} }
        end
      end
    end
    -- FireRed/LeafGreen's second Day-Care keeps one Pokemon on Route 5.
    local route5 = root and root.route5Daycare or rawget(native, "route5Daycare")
    if profile.family ~= "rse" and type(route5) == "table" and type(route5.mon) == "table"
        and (tonumber(route5.mon.species or route5.mon.speciesId) or 0) ~= 0 then
      input.boarder = boarder(route5.mon, route5.steps or 0, "route5")
      input.boarder.place = gen3Place(adapter, "ROUTE_?5$")
    end
    local save = game.save or adapter.save
    input.eggs = partyEggs(data, save, 3, adapter)
    -- Emerald's Magma Armor / Flame Body partners halve hatching (the same
    -- rule the egg-step estimate in the summary already applies).
    if profile.id == "emerald" and Host and Host.eggCyclesToSubtract and #input.eggs > 0 then
      local ok, rate = pcall(Host.eggCyclesToSubtract, native)
      if ok and rate == 2 then input.hatchBoost = true end
    end
    return input
  end

  function displayRuntime.daycareInput()
    local game = session.game
    if not (game and game.save) then return { parents = {}, eggs = {} } end
    if displayRuntime.gen3 then return gen3(game) end
    if compat.isGen2() then return gen2(game) end
    return gen1(game)
  end

  function displayRuntime.daycarePolicy()
    return { odds = assist("daycare_odds"), eggSpecies = assist("egg_species"),
      eggProgress = assist("egg_progress") }
  end

  function displayRuntime.daycareModel()
    local input = displayRuntime.daycareInput()
    local model = Daycare.build(input, displayRuntime.daycarePolicy())
    model.place = input.place
    if input.boarder then
      local extra = Daycare.build({ generation = 1, parents = { input.boarder } }, {})
      model.boarder = extra.parents[1]
      model.boarder.place = input.boarder.place
      model.empty = model.empty and false
    end
    model.headline = Daycare.headline(model)
    model.drawPokemon = displayRuntime.daycareDrawPokemon
    return model
  end

  -- Boarders are not party members: draw them from their own record, eggs
  -- with the game's egg icon.
  function displayRuntime.daycareDrawPokemon(mon, x, y, size)
    if not mon then return end
    if compat.partyEgg(mon) then compat.drawPokemonIcon(mon, x, y, size); return end
    if not drawSprite(mon.species, "front", x, y, size, size, nil, mon, true) then
      compat.drawPokemonIcon(mon, x, y, size)
    end
  end

  displayRuntime.daycare = displayRuntime.daycare or {}
  function displayRuntime.drawDaycare()
    local state = displayRuntime.daycare
    local model = displayRuntime.daycareModel()
    -- A view that no longer exists (the boarder was picked up) falls back.
    local tabs = THEME.hgss:daycareTabs(model)
    local valid = state.view == nil or state.view == "parent"
    for _, tab in ipairs(tabs) do valid = valid or tab[2] == state.view end
    if not valid or state.view == "boarder" and model.generation ~= 1 and not model.boarder then state.view = nil end
    local parent
    if state.view == "parent" then
      for _, row in ipairs(model.parents) do if row.key == state.selected then parent = row end end
      if not parent then state.view, state.selected = nil, nil end
    end
    model.view, model.selected = state.view, state.selected
    model.drawPokemon = displayRuntime.daycareDrawPokemon
    header(parent and parent.name or THEME:translate("DAY-CARE"), true, false)
    render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    THEME.hgss:daycare(model)
    render.G.pop()
  end

  function displayRuntime.tapDaycare(x, y)
    local state = displayRuntime.daycare
    if y < 30 and x < 35 then
      if state.view == "parent" then state.view, state.selected = nil, nil
      else session.page, displayRuntime.home.activeApp = "HOME", nil end
      session.dirty = true
      return
    end
    local action, value = THEME.hgss:daycareHit(x, y)
    if action == "view" then
      state.view, state.selected = value ~= "main" and value or nil, nil
      displayRuntime.haptic()
    elseif action == "parent" then
      state.view, state.selected = "parent", value
      displayRuntime.haptic()
    end
    session.dirty = action ~= nil or session.dirty
  end
end
