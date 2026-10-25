return function(
  Discovery, addEncounters, compat, displayRuntime, fit, session
)
  -- Game path [Gen 1/2/3]: TownMap locations, Gen 2 landmark indices and Gen 3 section groups are distinct map identity formats.
  local function locationEntries()
    if displayRuntime.gen3 then return displayRuntime.gen3:locations() end
    if compat.isGen2() then
      local source = session.game and session.game.data and session.game.data.gen2Landmarks
      local landmarks = source and source.landmarks or {}
      local byIndex, out = {}, {}
      for _, entry in pairs(landmarks) do
        if entry.index ~= nil then byIndex[entry.index] = entry end
      end
      for id, def in pairs(session.game.data.gen2Maps or {}) do
        local index = def.landmark
        local key = type(index) == "string" and index
          or type(index) == "number" and source and source.order
            and source.order[index + 1]
        local record = key and landmarks[key]
        out[id] = record and (type(index) == "string" or record.index == index)
          and record or byIndex[index]
      end
      return out
    end
    local townMap = session.game and session.game.data and session.game.data.field
      and session.game.data.field.townMap
    return townMap and (townMap.locations or townMap) or {}
  end

  -- Host path [Gen 2]: imported numeric landmarks use the order table; symbolic/custom IDs and older datasets need live-record lookup.
  local function locationEntry(id)
    if not id then return nil end
    if compat.isGen2() then
      local data = session.game and session.game.data
      local def = data and data.gen2Maps and data.gen2Maps[id]
      local index = def and def.landmark
      if index == nil then return nil end
      local source = data.gen2Landmarks or {}
      local records = source.landmarks or {}
      -- Content mods can register symbolic landmark IDs instead of ROM indices.
      if type(index) == "string" then return records[index] end
      if type(index) ~= "number" then return nil end
      -- The extractor already supplies the index -> landmark ID lookup.
      -- Read the live record so translated/replaced names need no cache expiry.
      local key = source.order and source.order[index + 1]
      local record = key and records[key]
      if record and record.index == index then return record end
      -- Registered/moved landmarks and older datasets may have no order entry.
      local found
      for _, entry in pairs(records) do
        if entry.index == index then found = entry end
      end
      return found
    end
    return locationEntries()[id]
  end

  local function areaName(id)
    local entry = locationEntry(id)
    local name = (entry and (entry.name or entry.label)) or id or "KANTO"
    name = tostring(name):gsub("<LF>", " "):gsub("\n", " ")
    return fit(name, 23)
  end

  function displayRuntime.sectionName(id, fallback)
    local section = tostring(id or "OTHER AREA"):gsub("^%u%u_", ""):gsub("_", " ")
    local entry = locationEntry(id)
    local name = entry and tostring(entry.name or entry.label or "") or ""
    for word in name:upper():gmatch("[%w]+") do
      section = section:gsub("^" .. word .. " ?", "")
    end
    return section ~= "" and section or fallback
      or name ~= "" and name or "OTHER AREA"
  end

  local function areaMaps(id)
    if displayRuntime.gen3 then return displayRuntime.gen3:areaMaps(id) end
    local entry = locationEntry(id)
    if not entry then return { id } end
    local c = entry.coords or entry
    local name = entry.name or entry.label
    local x, y = tonumber(c.x or c.col), tonumber(c.y or c.row)
    if not name or not x or not y then return { id } end
    local out = {}
    for candidate, other in pairs(locationEntries()) do
      local oc = other.coords or other
      if (other.name or other.label) == name
         and tonumber(oc.x or oc.col) == x and tonumber(oc.y or oc.row) == y then
        out[#out + 1] = candidate
      end
    end
    if #out == 0 then out[1] = id end
    table.sort(out)
    return out
  end

  -- Game path [Gen 2]: fish groups can also appear on maps without a reachable shore; inspect detached native collision data before listing them.
  function displayRuntime.gen2HasFishingShore(id)
    local data = session.game.data
    local def = data.gen2Maps and data.gen2Maps[id]
    local tileset = def and data.gen2Tilesets and data.gen2Tilesets[def.tileset]
    -- Host path [Gen 2]: missing terrain is unknown, not proof of a dry map; preserve encounters when collision data is unavailable.
    -- Older hosts/mods may not expose terrain. Keep their encounters rather
    -- than interpreting unavailable data as a dry map.
    if not (def and def.width and def.height and def.blocks
        and tileset and tileset.collision) then return true end
    local cache = displayRuntime.fishingTerrain or {}
    displayRuntime.fishingTerrain = cache
    local cached = cache[id]
    if cached and cached.def == def and cached.blocks == def.blocks
        and cached.collision == tileset.collision
        and cached.width == def.width and cached.height == def.height then
      return cached.hasShore
    end
    local Map = require("src.world.gen2.Map")
    -- Detached map: inspecting a remote habitat must not load the live world
    -- or let Map.new normalize the source map's connections in place.
    local copy = {}
    for key, value in pairs(def) do copy[key] = value end
    copy.id, copy.connections = id, {}
    local map, hasShore = Map.new(copy, tileset), false
    for y = 0, map.heightCells - 1 do
      for x = 0, map.widthCells - 1 do
        if map:isWaterCell(x, y) and (map:isWalkableCell(x - 1, y)
            or map:isWalkableCell(x + 1, y) or map:isWalkableCell(x, y - 1)
            or map:isWalkableCell(x, y + 1)) then
          hasShore = true
          break
        end
      end
      if hasShore then break end
    end
    cache[id] = { def = def, blocks = def.blocks,
      collision = tileset.collision, width = def.width, height = def.height,
      hasShore = hasShore }
    return hasShore
  end

  local function guideData(mapIds, completion, checkpoint)
    local rows, bySpecies = {}, {}
    local data, field = session.game.data, session.game.data.field or {}
    local fishing = field.fishing or {}
    local gen2 = compat.isGen2()
    local modules = displayRuntime.gen2GuideModules
    if gen2 and not modules then
      modules = {
        encounter = select(2, pcall(require, "src.battle.gen2.Encounter")),
        roamers = select(2, pcall(require, "src.core.gen2.Roamers")),
        contest = select(2, pcall(require, "src.core.gen2.BugContest")),
      }
      for key, value in pairs(modules) do
        if type(value) ~= "table" then modules[key] = nil end
      end
      displayRuntime.gen2GuideModules = modules
    end
    local Gen2Encounter = modules and modules.encounter
    local Roamers = modules and modules.roamers
    local BugContest = modules and modules.contest
    local function addWeighted(slots, method, context)
      local selected, cumulative, total = {}, {}, 0
      for _, slot in ipairs(slots or {}) do
        local chance = math.max(0, tonumber(slot.chance) or 0)
        chance = math.min(chance, math.max(0, 100 - total))
        if chance > 0 then
          selected[#selected + 1], total = slot, total + chance
          cumulative[#cumulative + 1] = total
        end
        if total >= 100 then break end
      end
      addEncounters(rows, bySpecies, selected, method, cumulative, context)
    end
    local maps = mapIds or areaMaps(session.mapId)
    if not completion then maps = Discovery.filter(maps, displayRuntime.knownMap) end
    for _, id in ipairs(maps) do
      if checkpoint then checkpoint() end
      local encounter = data.encounters and data.encounters[id]
      local buckets = data.constants and data.constants.encounterBuckets
      if displayRuntime.gen3 then
        local pools = {}
        for _, row in ipairs(displayRuntime.gen3:encounters(id)) do
          local pool = pools[row.method]
          if not pool then pool = { slots = {}, weights = {}, total = 0 }; pools[row.method] = pool end
          pool.slots[#pool.slots + 1] = { species = row.species, min = row.minLevel, max = row.maxLevel }
          pool.total = pool.total + row.chance
          pool.weights[#pool.weights + 1] = pool.total
        end
        for _, method in ipairs({ "WALK", "SURF", "OLD", "GOOD", "SUPER", "ROCK SMASH" }) do
          local pool = pools[method]
          if pool then addEncounters(rows, bySpecies, pool.slots, method, pool.weights,
            { mapId = id, section = displayRuntime.sectionName(id) }) end
        end
      -- Game path [Gen 2]: time periods, swarms, Bug Contest, Headbutt, Rock Smash and roaming encounters require separate native pools.
      elseif gen2 then
        local encounters = data.gen2Encounters or {}
        local active = encounters
        if not completion and Roamers and Roamers.Swarm then
          active = Roamers.Swarm.tables(session.game.save, encounters, id)
        end
        local function addGold(entry, method, weights)
          local slots = entry and entry.slots or {}
          if slots.MORN or slots.DAY or slots.NITE then
            for _, time in ipairs({ "MORN", "DAY", "NITE" }) do
              addEncounters(rows, bySpecies, slots[time], method, weights,
                { time = time, mapId = id,
                  section = displayRuntime.sectionName(id) })
            end
          else
            addEncounters(rows, bySpecies, slots, method, weights,
              { mapId = id, section = displayRuntime.sectionName(id) })
          end
        end
        local contest = not completion and id == session.mapId and session.game.save.bugContest
          and session.game.save.bugContest.active == true
        if contest then
          addWeighted(encounters.bugContest or (BugContest and BugContest.MONS),
            "CONTEST",
            { mapId = id, section = displayRuntime.sectionName(id) })
        else
          addGold(active.grass and active.grass[id], "WALK",
            { 30, 60, 80, 90, 95, 99, 100 })
          addGold(active.water and active.water[id], "SURF",
            { 60, 90, 100 })
        end
        local map = data.gen2Maps and data.gen2Maps[id]
        local groupId = map and map.fishGroup
        if groupId and not displayRuntime.gen2HasFishingShore(id) then
          groupId = nil
        end
        -- Game path [Gen 2]: completion includes possible swarm/contest pools, while the live guide follows the current native event state.
        if completion then
          addGold(encounters.swarmGrass and encounters.swarmGrass[id], "WALK",
            { 30, 60, 80, 90, 95, 99, 100 })
          addGold(encounters.swarmWater and encounters.swarmWater[id], "SURF",
            { 60, 90, 100 })
          if id == "NATIONAL_PARK_BUG_CONTEST" then
            addWeighted(encounters.bugContest or (BugContest and BugContest.MONS),
              "CONTEST", { mapId = id, section = displayRuntime.sectionName(id) })
          end
        end
        if not completion and groupId and Gen2Encounter and Roamers and Roamers.Swarm then
          groupId = Gen2Encounter.fishGroupFor(encounters, groupId,
            Roamers.Swarm.fishing(session.game.save))
        end
        local groupIds = { groupId }
        if completion and groupId and Gen2Encounter then
          for swarm = 1, 2 do
            local extra = Gen2Encounter.fishGroupFor(encounters, groupId, swarm)
            if extra ~= groupId then groupIds[#groupIds + 1] = extra end
          end
        end
        for _, fishingGroup in ipairs(groupIds) do
          local group = fishingGroup and encounters.fishGroups
            and encounters.fishGroups[fishingGroup]
          for _, rod in ipairs({ { "old", "OLD" }, { "good", "GOOD" },
                                 { "super", "SUPER" } }) do
            local source = group and group[rod[1]] or {}
            local timed = false
            for _, slot in ipairs(source) do
              timed = timed or slot.day ~= nil or slot.nite ~= nil
                or slot.timeGroup ~= nil
            end
            local periods = timed and { "MORN", "DAY", "NITE" } or { false }
            for _, time in ipairs(periods) do
              local slots, weights = {}, {}
              for _, row in ipairs(source) do
                local slot = row
                if time then
                  local key = time == "NITE" and "nite" or "day"
                  local timeGroup = encounters.timeFishGroups
                    and encounters.timeFishGroups[row.timeGroup]
                  slot = row[key] or (timeGroup and timeGroup[key]) or row
                end
                slots[#slots + 1], weights[#weights + 1] = slot, row.chance
              end
              addEncounters(rows, bySpecies, slots, rod[2], weights,
                { time = time or nil, mapId = id,
                  section = displayRuntime.sectionName(id) })
            end
          end
        end
        local treeSet = encounters.treeSets
          and encounters.treeSets[encounters.trees and encounters.trees[id]]
        if treeSet then
          addWeighted(treeSet.common, "HEADBUTT",
            { mapId = id, section = displayRuntime.sectionName(id) })
          addWeighted(treeSet.rare, "RARE TREE",
            { mapId = id, section = displayRuntime.sectionName(id) })
        end
        local rockSet = encounters.treeSets
          and encounters.treeSets[encounters.rocks and encounters.rocks[id]]
        if rockSet then
          addWeighted(rockSet.common, "ROCK SMASH",
            { mapId = id, section = displayRuntime.sectionName(id) })
        end
        -- Game path [Gen 2]: roamers appear only at their live map with a separate encounter weight; do not turn them into permanent local pools.
        for _, roamer in ipairs(not completion and session.game.save.roamers or {}) do
          if roamer.species and roamer.map == id then
            addEncounters(rows, bySpecies, {
              { species = roamer.species, level = roamer.level or 40 },
              { species = 0, level = roamer.level or 40 },
            }, "ROAMING", { 10, 100 },
              { mapId = id, section = displayRuntime.sectionName(id) })
          end
        end
      else
        addEncounters(rows, bySpecies,
          encounter and encounter.grass and encounter.grass.slots, "WALK",
          encounter and encounter.grass and (encounter.grass.buckets or buckets),
          { mapId = id, section = displayRuntime.sectionName(id) })
        addEncounters(rows, bySpecies,
          encounter and encounter.water and encounter.water.slots, "SURF",
          encounter and encounter.water and (encounter.water.buckets or buckets),
          { mapId = id, section = displayRuntime.sectionName(id) })
      end
      local super = field.superRod and field.superRod[id]
      -- Game path [Gen 1]: rod-specific global/per-map fishing tables supplement water encounters; later engines already provide their own pools.
      if not gen2 and not displayRuntime.gen3 and ((encounter and encounter.water) or super) then
        for _, rod in ipairs({ "OLD_ROD", "GOOD_ROD", "SUPER_ROD" }) do
          local def = fishing[rod] or {}
          local slots = def.always and { def.always } or def.pool
          if def.perMap then slots = field[def.perMap] and field[def.perMap][id] end
          addEncounters(rows, bySpecies, slots,
            ({ OLD_ROD = "OLD", GOOD_ROD = "GOOD", SUPER_ROD = "SUPER" })[rod],
            nil, { mapId = id, section = displayRuntime.sectionName(id) })
        end
      end
    end

    if not completion then
      rows = Discovery.filter(rows, function(row) return displayRuntime.knownSpecies(row.species) end)
    end
    local ownedDex = compat.caughtDex(session.game.save)
    local areaCaught, currentTime = 0, compat.timePeriod(session.game.world) or "DAY"
    for order, row in ipairs(rows) do
      local def = data.pokemon[row.species] or {}
      row.name, row.caught = def.name or row.species, ownedDex[row.species] == true
      if row.caught then areaCaught = areaCaught + 1 end
      row.order, row.currentMethods, row.mapTimes = order, {}, {}
      local currentSet, sameMap = {}, false
      for _, appearance in ipairs(row.appearances) do
        local here = appearance.mapId == session.mapId
        local now = here and (not appearance.time or appearance.time == currentTime)
        appearance.rank = now and 1 or here and 2 or 3
        sameMap = sameMap or here
        if here then
          if appearance.time then row.mapTimes[appearance.time] = true
          else row.mapAllTimes = true end
        end
        if now then
          if not appearance.minLevel or not appearance.maxLevel then
            row.currentLevelsUnknown, row.currentMinLevel, row.currentMaxLevel = true, nil, nil
          elseif not row.currentLevelsUnknown then
            row.currentMinLevel = math.min(row.currentMinLevel or appearance.minLevel,
              appearance.minLevel)
            row.currentMaxLevel = math.max(row.currentMaxLevel or appearance.maxLevel,
              appearance.maxLevel)
          end
          local odds = currentSet[appearance.method]
          if not odds then
            odds = { name = appearance.method, min = appearance.chance,
              max = appearance.chance }
            currentSet[appearance.method] = odds
            row.currentMethods[#row.currentMethods + 1] = odds
          else
            odds.min, odds.max = math.min(odds.min, appearance.chance),
              math.max(odds.max, appearance.chance)
          end
        end
      end
      table.sort(row.appearances, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.section ~= b.section then return a.section < b.section end
        if (a.time or "") ~= (b.time or "") then
          return (a.time or "") < (b.time or "")
        end
        return a.method < b.method
      end)
      row.availability = #row.currentMethods > 0 and "now"
        or sameMap and "time" or "area"
      row.detailPages = math.max(1, math.ceil(#row.appearances / 3))
    end
    table.sort(rows, function(a, b)
      local rank = { now = 1, time = 2, area = 3 }
      if rank[a.availability] ~= rank[b.availability] then
        return rank[a.availability] < rank[b.availability]
      end
      return a.order < b.order
    end)
    return { name = areaName(session.mapId), rows = rows, caught = areaCaught,
      complete = #rows > 0 and areaCaught == #rows,
      pages = math.max(1, math.ceil(#rows / 3)), timed = compat.isGen2(),
      time = currentTime, section = displayRuntime.sectionName(session.mapId) }
  end

  return areaMaps, areaName, guideData, locationEntries, locationEntry
end
