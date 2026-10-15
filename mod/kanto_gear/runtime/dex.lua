return function(
  Discovery, THEME, areaName, assist, compat, displayRuntime,
  drawSprite, guideData, mod, session
)
  function compat.typeEffectiveness(moveType, defenderTypes, chart)
    if not (moveType and defenderTypes and defenderTypes[1] and chart) then
      return nil
    end
    local multiplier = 10
    for _, row in ipairs(chart.matchups or {}) do
      if row.attacker == moveType then
        for _, defenderType in ipairs(defenderTypes) do
          if row.defender == defenderType then
            multiplier = math.floor(multiplier * row.multiplier / 10)
            break
          end
        end
      end
    end
    return multiplier
  end

  function compat.enemyDvs(mon)
    local source = type(mon) == "table" and mon.dvs
    if type(source) ~= "table" then return nil end
    local out = {}
    for _, key in ipairs({ "attack", "defense", "speed", "special" }) do
      local value = tonumber(source[key])
      if not value or value % 1 ~= 0 or value < 0 or value > 15 then return nil end
      out[key] = value
    end
    local hp = tonumber(source.hp)
    if hp == nil then
      hp = (out.attack % 2) * 8 + (out.defense % 2) * 4
        + (out.speed % 2) * 2 + (out.special % 2)
    end
    if hp % 1 ~= 0 or hp < 0 or hp > 15 then return nil end
    out.hp = hp
    return out
  end

  -- Game path [Gen 1/2/3]: Dex entries use Gen 1 text keys, Gen 2 two-part text/encoded imperial units, or projected Gen 3 metric fields.
  function compat.enemyInfo(enemy, data, save, mon)
    enemy, data = enemy or {}, data or {}
    local species = enemy.species
    local def = species and data.pokemon and data.pokemon[species] or {}
    local entry = compat.isGen2()
      and data.gen2Pokedex and data.gen2Pokedex.entries
      and data.gen2Pokedex.entries[species] or def.dexEntry
    local dex = save and save.pokedex or {}
    local seen, caught = dex.seen or {}, compat.caughtDex(save)
    local info = {
      species = species,
      name = enemy.name or def.name or species or "-",
      level = enemy.level,
      dex = entry and entry.dex or def.dex,
      types = {},
      seen = species and not not seen[species] or false,
      caught = species and not not caught[species] or false,
      dvs = compat.enemyDvs(mon or enemy),
      weak = {}, resist = {},
      kind = entry and entry.kind,
      description = {},
    }
    for _, typeId in ipairs(def.types or {}) do
      if typeId ~= info.types[#info.types] then
        info.types[#info.types + 1] = typeId
      end
    end
    if entry then
      local heightM, height = tonumber(entry.heightM), tonumber(entry.height)
      if heightM then
        info.heightValue = ("%.1f M"):format(heightM)
        info.weightValue = ("%.1f KG"):format(tonumber(entry.weightKg) or 0)
        info.height = THEME:format("HEIGHT %.1f M", heightM)
        info.weight = THEME:format("WEIGHT %.1f KG",
          tonumber(entry.weightKg) or 0)
      elseif compat.isGen2() and height then
        info.heightValue = ("%d FT %d IN"):format(math.floor(height / 100), height % 100)
        info.weightValue = ("%.1f LB"):format((tonumber(entry.weight) or 0) / 10)
        info.height = THEME:format("HEIGHT %d FT %d IN",
          math.floor(height / 100), height % 100)
        info.weight = THEME:format("WEIGHT %.1f LB",
          (tonumber(entry.weight) or 0) / 10)
      elseif entry.heightFt then
        info.heightValue = ("%d FT %d IN"):format(tonumber(entry.heightFt) or 0,
          tonumber(entry.heightIn) or 0)
        info.weightValue = ("%.1f LB"):format((tonumber(entry.weight) or 0) / 10)
        info.height = THEME:format("HEIGHT %d FT %d IN",
          tonumber(entry.heightFt) or 0, tonumber(entry.heightIn) or 0)
        info.weight = THEME:format("WEIGHT %.1f LB",
          (tonumber(entry.weight) or 0) / 10)
      end
      local source = compat.isGen2()
        and table.concat({ entry.text or "", entry.text2 or "" }, " ")
        or (data.text and data.text[entry.text]) or entry.text or ""
      info.descriptionText = source
      info.description = THEME:descriptionLines(source, 24, nil, 206)
    end
    local attackers = {}
    for _, row in ipairs((data.type_chart or {}).matchups or {}) do
      attackers[row.attacker] = true
    end
    for typeId in pairs(attackers) do
      local multiplier = compat.typeEffectiveness(
        typeId, info.types, data.type_chart)
      local list = multiplier and multiplier > 10 and info.weak
        or multiplier and multiplier < 10 and info.resist
      if list then
        list[#list + 1] = { type = typeId, multiplier = multiplier }
      end
    end
    table.sort(info.weak, function(a, b)
      if a.multiplier ~= b.multiplier then return a.multiplier > b.multiplier end
      return tostring(a.type) < tostring(b.type)
    end)
    table.sort(info.resist, function(a, b)
      if a.multiplier ~= b.multiplier then return a.multiplier < b.multiplier end
      return tostring(a.type) < tostring(b.type)
    end)
    return info
  end

  -- Game path [Gen 2 vs Gen 1]: grass/water/tree/rock tables and fish groups are separate in Gen 2; Gen 1 uses encounters and superRod maps.
  function displayRuntime.pokedexMapIds()
    local data, found = session.game.data or {}, {}
    local function add(source)
      for id in pairs(source or {}) do found[id] = true end
    end
    if compat.isGen2() then
      local encounters = data.gen2Encounters or {}
      add(encounters.grass)
      add(encounters.water)
      add(encounters.trees)
      add(encounters.rocks)
      for id, def in pairs(data.gen2Maps or {}) do
        if def.fishGroup then found[id] = true end
      end
    else
      add(data.encounters)
      add(data.field and data.field.superRod)
    end
    local ids = {}
    for id in pairs(found) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
    return ids
  end

  -- Game path [Gen 3]: native Dex revision and regional/national numbering control invalidation and which species are listed.
  function displayRuntime.pokedexData()
    local state = displayRuntime.pokedex
    if displayRuntime.gen3 and state.nativeRevision ~= displayRuntime.gen3.dexRevision then
      state.data, state.nativeRevision = nil, displayRuntime.gen3.dexRevision
    end
    if state.data then return state.data end
    local save, data = session.game.save or {}, session.game.data or {}
    local seen = save.pokedex and save.pokedex.seen or {}
    local caught = compat.caughtDex(save)
    local habitats = {}
    for _, row in ipairs(guideData(displayRuntime.pokedexMapIds()).rows) do
      habitats[row.species] = row
    end
    local entries, caughtCount = {}, 0
    for species, def in pairs(data.pokemon or {}) do
      if tonumber(def.dex) and (not displayRuntime.gen3
          or displayRuntime.gen3:dexNumber(species) ~= nil) then
        local owned = caught[species] == true
        entries[#entries + 1] = {
          species = species, dex = displayRuntime.gen3 and displayRuntime.gen3:dexNumber(species) or tonumber(def.dex),
          name = displayRuntime.knownSpecies(species)
            and (def.name or tostring(species):gsub("_", " ")) or "???",
          seen = owned or seen[species] == true, caught = owned,
          revealed = displayRuntime.knownSpecies(species),
          habitat = habitats[species],
        }
        if owned then caughtCount = caughtCount + 1 end
      end
    end
    table.sort(entries, function(a, b)
      if a.dex ~= b.dex then return a.dex < b.dex end
      return tostring(a.species) < tostring(b.species)
    end)
    local bySpecies = {}
    for index, entry in ipairs(entries) do
      entry.index, bySpecies[entry.species] = index, entry
    end
    state.data = { entries = entries, bySpecies = bySpecies,
      caught = caughtCount, total = #entries }
    return state.data
  end

  function displayRuntime.pokedexMoveRows(def)
    local rows = {}
    local function add(moveId, method)
      local move = session.game.data.moves and session.game.data.moves[moveId] or {}
      local typeId = move.type or "NORMAL"
      rows[#rows + 1] = {
        id = moveId, name = move.name or tostring(moveId):gsub("_", " "),
        method = method, type = typeId, type2 = typeId,
        typeLabel = THEME:typeName(typeId, mod.content),
        type2Label = THEME:typeName(typeId, mod.content),
      }
    end
    for _, moveId in ipairs(def.level1Moves or {}) do
      add(moveId, THEME:translate("START"))
    end
    for _, row in ipairs(def.learnset or def.levelMoves or {}) do
      add(row.move or row.id, THEME:format("L%d", row.level or 1))
    end
    for _, moveId in ipairs(def.tmhm or {}) do add(moveId, THEME:translate("TM/HM")) end
    return rows
  end

  function displayRuntime.habitatMethods()
    local save = session.game.save or {}
    -- Game path [Gen 1/2/3]: Surf uses each generation's badge and field-move requirements.
    local surfBadge = compat.isGen2() and THEME.fieldTools.gen2Badge(save, "FOG")
      or not compat.isGen2() and (tonumber((save.inventory or {}).SOULBADGE) or 0) > 0
    return displayRuntime.gen3 and displayRuntime.gen3:habitatMethods()
      or displayRuntime.Habitats.methods(save, session.game.data.items or {}, surfBadge)
  end

  function displayRuntime.pokedexHabitatPlan(selected)
    Discovery.current()
    local state, now = displayRuntime.pokedex, love.timer.getTime()
    local mode = Discovery.current().signature
    local period = compat.timePeriod(session.game.world) or "DAY"
    local cached = state.habitatPlan
    if cached and cached.source == selected and cached.map == session.mapId and cached.mode == mode
        and cached.period == period and now < cached.refreshAt then return cached end
    local visited = mod.save:get("achievement_visits", {})
    if type(visited) ~= "table" then visited = {} end
    local methods = displayRuntime.habitatMethods()
    local plan = displayRuntime.Habitats.plan(
      Discovery.filter(selected.habitat and selected.habitat.appearances, function(row)
        return displayRuntime.knownMap(row.mapId)
      end), session.mapId, period, visited, methods)
    plan.source, plan.map, plan.period, plan.refreshAt, plan.mode = selected, session.mapId, period, now + 0.5, mode
    state.habitatPlan = plan
    if not cached or cached.signature ~= plan.signature then session.dirty = true end
    return plan
  end

  function displayRuntime.drawAchievementPokemon(mon, x, y, size)
    return drawSprite(mon.species, "front", x, y, size, size, nil, nil, true)
  end

  function displayRuntime.pokedexPokemon(species, name)
    local info = Discovery.dex(compat.enemyInfo({ species = species, name = name }, session.game.data, session.game.save), session.discoveryPolicy)
    info.type = info.types[1]
    info.type2 = info.types[2] or info.type
    info.typeLabel = info.type and THEME:typeName(info.type, mod.content)
    info.type2Label = info.type2 and THEME:typeName(info.type2, mod.content)
    info.kind = info.kind or THEME:translate("UNKNOWN")
    info.height, info.weight = info.heightValue or "--", info.weightValue or "--"
    if info.descriptionText then info.description = THEME:pokedexDescriptionLines(info.descriptionText) end
    if #info.description == 0 then info.description = { THEME:translate("NO RESEARCH DATA AVAILABLE.") } end
    return info
  end

  function displayRuntime.pokedexModel()
    local state, dex = displayRuntime.pokedex, displayRuntime.pokedexData()
    if not state.selected and dex.entries[1] then
      state.selected = dex.entries[1].species
    end
    local selected = dex.bySpecies[state.selected] or dex.entries[1]
    if selected then state.selected = selected.species end
    local function drawPokemon(row, x, y, size)
      if row.revealed == false then return false end
      local tint
      if not row.caught then
        tint = row.seen and THEME.hgss.colors.silver
          or THEME.hgss.colors.shadow
      end
      return drawSprite(row.species, "front", x, y, size, size,
        tint, nil, true)
    end
    if state.view == "index" then
      local region = displayRuntime.gen3 and
          ((session.game.save.pokedex.national and "NATIONAL" or compat.currentRegion():upper()) .. " DEX")
          or (compat.isGen2() and "NATIONAL DEX" or "KANTO DEX")
      return displayRuntime.PokedexPage.index(state, dex, region, drawPokemon)
    end
    if not selected or selected.revealed == false then
      state.view = "index"
      return displayRuntime.pokedexModel()
    end
    local permitted = { stats = assist("dex_stats"), habitat = assist("habitats"),
      moves = assist("dex_moves"), evolutions = assist("dex_evolutions") }
    if permitted[state.view] == false then state.view = "profile" end
    local def = session.game.data.pokemon[selected.species] or {}
    local info = displayRuntime.pokedexPokemon(selected.species, selected.name)
    info.index = selected.index
    -- Game path [Gen 1 vs Gen 2/3]: base-stat totals use one Special stat in Gen 1 and split Special Attack/Defense thereafter.
    local stats, bst = displayRuntime.PokedexPage.stats(def.baseStats or {}, compat.isGen2() or displayRuntime.gen3 ~= nil)
    local moves = displayRuntime.pokedexMoveRows(def)
    local habitat = Discovery.filter(selected.habitat and selected.habitat.appearances, function(row)
      return displayRuntime.knownMap(row.mapId)
    end)
    local areas = {}
    for _, appearance in ipairs(habitat) do areas[appearance.mapId] = true end
    local areaCount = 0
    for _ in pairs(areas) do areaCount = areaCount + 1 end
    local common = {
      pokemon = info, drawPokemon = drawPokemon,
      statsText = assist("dex_stats") and THEME:format("BST %d", bst) or nil,
      habitatText = assist("habitats") and THEME:format("%d AREAS", areaCount) or nil,
      movesText = assist("dex_moves") and THEME:format("%d MOVES", #moves) or nil, cards = {},
    }
    for _, card in ipairs(displayRuntime.PokedexPage.cards) do
      if permitted[card] then common.cards[#common.cards + 1] = card end
    end
    if state.view == "profile" then
      common.view = "profile"
      displayRuntime.PokedexPage.description(state, common)
      return displayRuntime.PokedexPage.controls(common, dex)
    elseif state.view == "stats" then
      common.view, common.stats = "stats", stats
      common.summary = THEME:format("BST %d", bst)
      common.catchText = THEME:format("CATCH %d",
        tonumber(def.catchRate) or 0)
      common.expText = THEME:format("XP %d", tonumber(def.baseExp) or 0)
      return displayRuntime.PokedexPage.controls(common, dex)
    elseif state.view == "moves" then
      common.view = "moves"
      common.rows, common.page, common.pages = displayRuntime.PokedexPage.window(moves, state.movePage, 4)
      state.movePage = common.page
      return displayRuntime.PokedexPage.controls(common, dex)
    elseif state.view == "evolutions" then
      local native = displayRuntime.gen3
      local evolution = native and require("src.core.game3.evolution")
      local rows, available = displayRuntime.Evolutions.rows(def, native and 3 or compat.isGen2() and 2 or 1, {
        format = function(key, ...) return THEME:format(key, ...) end,
        itemName = function(id)
          local item = id and session.game.data.items[id]
          return item and item.name or THEME:translate("UNKNOWN ITEM")
        end,
        knownSpecies = displayRuntime.knownSpecies,
        -- Game path [FireRed/LeafGreen]: absent RTC and native national-Dex evolution gates must be shown as restrictions, not guessed availability.
        noClock = native and not (native.profile.clock and native.profile.clock.rtc),
        nationalAllows = native and function(id) return evolution.nationalAllows(id, native.session) end,
      })
      common.rows, common.page, common.pages = displayRuntime.PokedexPage.window(rows, state.evolutionPage, 1)
      state.evolutionPage, common.view = common.page, "evolutions"
      common.emptyText = THEME:translate(available and "NO FURTHER EVOLUTION" or "NO EVOLUTION DATA AVAILABLE")
      for _, row in ipairs(common.rows) do
        local entry = dex.bySpecies[row.species] or {}
        row.seen, row.caught = entry.seen, entry.caught
        row.name = row.revealed and (session.game.data.pokemon[row.species] or {}).name or "???"
        row.lines = {}
        for _, condition in ipairs(row.conditions) do
          for _, line in ipairs(THEME:descriptionLines(condition, 34, nil, 210)) do
            row.lines[#row.lines + 1] = line
          end
        end
      end
      return displayRuntime.PokedexPage.controls(common, dex)
    end
    local plan = displayRuntime.pokedexHabitatPlan(selected)
    local plannedRows
    plannedRows, common.page, common.pages = displayRuntime.PokedexPage.window(plan.rows, state.habitatPage, 3)
    state.habitatPage, common.view = common.page, "habitat"
    common.summary = areaCount > 0
      and THEME:format("%d AREAS", areaCount) or THEME:translate("NO WILD AREA")
    common.matchText = plan.count > 0 and THEME:format("%d MATCHING AREAS", plan.count)
      or THEME:translate("NO MATCHING AREA KNOWN")
    common.rows = displayRuntime.habitatRows(plannedRows)
    return displayRuntime.PokedexPage.controls(common, dex)
  end

  function displayRuntime.habitatRows(plannedRows)
    local rows = {}
    for _, planned in ipairs(plannedRows) do
      local appearance = planned.appearance
      local area = areaName(appearance.mapId)
      local section = appearance.section
      if section and section ~= "" and section ~= "OTHER AREA"
          and not area:upper():find(section:upper(), 1, true) then
        area = area .. " - " .. section
      end
      rows[#rows + 1] = {
        details = assist("encounter_details"),
        area = area, current = planned.current, matches = planned.matches,
        status = planned.status == "ONLY %s"
          and THEME:format("ONLY %s", THEME:translate(planned.period))
          or planned.status and THEME:translate(planned.status),
        time = appearance.time or "ANY TIME", method = appearance.method,
        chance = math.floor((tonumber(appearance.chance) or 0) + 0.5),
        levels = appearance.minLevel == appearance.maxLevel
          and THEME:format("L%d", appearance.minLevel or 0)
          or THEME:format("L%d-%d", appearance.minLevel or 0,
            appearance.maxLevel or 0),
      }
    end
    return rows
  end

  function displayRuntime.selectPokedexSpecies(index)
    local changed = displayRuntime.PokedexPage.select(displayRuntime.pokedex, displayRuntime.pokedexData(), index)
    if changed then session.dirty = true end
    return changed
  end

  function displayRuntime.cyclePokedex(direction)
    local changed = displayRuntime.PokedexPage.cycle(displayRuntime.pokedex, displayRuntime.pokedexData(),
      displayRuntime.pokedexModel(), direction)
    if changed then displayRuntime.requestPageMotion(direction); session.dirty = true end
    return changed
  end

  displayRuntime.bagPockets = {
    { id = "ITEM", label = "ITEMS" },
    { id = "BALL", label = "POKE BALLS" },
    { id = "KEY_ITEM", label = "KEY ITEMS" },
    { id = "TM_HM", label = "TM/HM" },
  }

end
