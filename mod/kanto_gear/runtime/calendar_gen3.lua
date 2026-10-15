-- Game path [Gen 3]: the Calendar for Hoenn and Kanto. Gen 3 has no weekdays:
-- Ruby/Sapphire/Emerald run on a real-time clock with daily resets, berry
-- growth and Shoal Cave tides; FireRed/LeafGreen have no clock at all and
-- keep only the VS Seeker. Rows come out already named. Read only.
return function(THEME, assist, displayRuntime, session)
  local floor = math.floor
  local MT_BERRY_TREE = 0x0C
  local GIVE_ITEM = 0x8000

  local function hostModule(name)
    local ok, value = pcall(require, name)
    return ok and value or nil
  end
  local function adapter() return displayRuntime.gen3 end
  local function constants(gen3)
    local C = hostModule("src.core.game3.constants")
    local ok, set = pcall(function() return C.of(gen3.profile.id) end)
    return ok and set or nil
  end
  local function flagId(gen3, name)
    local C = constants(gen3)
    local ok, id = pcall(function() return C.flags.byName[name] end)
    return ok and id or nil
  end
  local function readFlag(gen3, id)
    if not id then return false end
    local ok, value = pcall(gen3.Flags.getFlag, gen3:flagStore(), nil, id)
    return ok and value == true
  end
  local function placeName(id)
    local gen3 = adapter()
    local entry = gen3 and id and gen3:locations()[id]
    return entry and entry.name or tostring(id or ""):gsub("^%u%u_", ""):gsub("_", " ")
  end
  local function itemName(id)
    local Items = hostModule("src.core.game3.items_data")
    local ok, name = pcall(function() return Items.displayName(id) end)
    return ok and type(name) == "string" and name ~= "" and name or nil
  end

  -- Static facts per edition, scanned once from the game's own scripts:
  -- who hands out something once a day, where the berry trees stand and
  -- which map each Match Call trainer lives on.
  local scans = setmetatable({}, { __mode = "k" })
  local function scan(gen3)
    local Space = gen3.Space
    local bundle = Space and Space.bundle
    if not (bundle and bundle.scripts and bundle.events) then return nil end
    local cached = scans[bundle]
    if cached then return cached end
    local C = constants(gen3)
    local names = C and C.flags and C.flags.byId and (C.flags.byId.FLAG_ or C.flags.byId) or {}
    local lo = flagId(gen3, "DAILY_FLAGS_START")
    local out = { gifts = {}, trees = {}, maps = {} }
    local function walk(key, seen, found)
      if not key or seen[key] then return end
      seen[key] = true
      local list = bundle.scripts[key]
      if type(list) ~= "table" then return end
      for _, op in ipairs(list) do
        if op.flag and lo and op.flag >= lo and op.flag < lo + 64 and op.op == "setflag" then
          found.flag = found.flag or op.flag
        end
        -- A giver with one fixed item names it; random or phrase-based
        -- rewards (several literals or a variable) stay a plain "berry".
        if op.op == "setorcopyvar" and op[1] == GIVE_ITEM and tonumber(op[2]) then
          if op[2] >= 0x4000 or found.item and found.item ~= op[2] then found.mixed = true end
          found.item = found.item or op[2]
        end
        if op.target then walk(op.target, seen, found) end
      end
    end
    local ids = {}
    for id in pairs(bundle.events) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
      for _, object in ipairs(bundle.events[id].objects or {}) do
        if tonumber(object.movementType) == MT_BERRY_TREE then
          local tree = tonumber(object.berryTreeId or object.trainerRange)
          if tree and tree > 0 then out.trees[#out.trees + 1] = { mapId = id, tree = tree } end
        elseif object.scriptKey then
          local found = {}
          walk(object.scriptKey, {}, found)
          local name = found.flag and names[found.flag] or ""
          -- Berry givers and the Lottery Corner; link-only and story flags stay out.
          local kind = name:find("LOTT?O") and "lottery" or name:find("BERRY") and "gift" or nil
          if kind and not name:find("CONTEST_LOBBY") then
            out.gifts[#out.gifts + 1] = { kind = kind, mapId = id, flag = found.flag, name = name,
              item = kind == "gift" and not found.mixed and found.item or nil, key = "daily:" .. id .. ":" .. tostring(object.localId) }
          end
        end
      end
    end
    -- MAP_ROUTE_114 / MAP_ROUTE114 -> this edition's map id (EM_ROUTE114, ...).
    local suffix = {}
    for id in pairs(gen3.data.maps or {}) do suffix[tostring(id):gsub("^%u%u_", "")] = id end
    for name, def in pairs(C and C.map_groups and C.map_groups.byName or {}) do
      local id = suffix[name:gsub("^MAP_", "")]
      if id and def.group and def.num then out.maps[def.group * 256 + def.num] = id end
    end
    scans[bundle] = out
    return out
  end

  -- The clock the game itself uses: real time minus the save's offset.
  local function localTime(gen3)
    local Rtc = hostModule("src.core.game3.rtc")
    local ok, time = pcall(function()
      return Rtc.calcTimeDifferenceRtc(Rtc.getInfo(gen3.session), gen3.session.localTimeOffset)
    end)
    if ok and type(time) == "table" then return time.hours or 0, time.minutes or 0 end
    return 12, 0
  end
  local function clock(hour, minute)
    return string.format("%d:%02d", hour % 24, minute or 0)
  end
  local function duration(minutes)
    if minutes < 60 then return THEME:format("IN %d MIN", math.max(1, minutes)) end
    return THEME:format("IN %d H", floor((minutes + 59) / 60))
  end

  -- pokeemerald/src/field_specials.c (UpdateShoalTideFlag): low tide 3-9, 15-21.
  local function lowTide(hour) return hour >= 3 and hour < 9 or hour >= 15 and hour < 21 end
  local function tideRow(gen3, hour, minute, policy)
    local known = false
    for id in pairs(gen3.data.maps or {}) do
      if tostring(id):find("SHOAL_CAVE") and displayRuntime.knownMap(id) then known = true end
    end
    if not (known or policy.schedule) then return nil end
    local low = lowTide(hour)
    local turn = low and (hour < 9 and 9 or 21) or (hour < 3 and 3 or hour < 15 and 15 or 27)
    local row = { kind = "tide", key = "tide", tag = "TIDE", state = low and "open" or "later", now = low,
      title = THEME:translate(low and "LOW TIDE" or "HIGH TIDE"),
      place = placeName((function()
        for id in pairs(gen3.data.maps) do if tostring(id):find("SHOAL_CAVE_LOW_TIDE_ENTRANCE") then return id end end
      end)() or "SHOAL CAVE") }
    row.right = THEME:format(low and "UNTIL %s" or "FROM %s", clock(turn, 0))
    row.facts = { { "LOW TIDE", "3:00 - 9:00, 15:00 - 21:00" } }
    -- A new day refills both: the cave resets the flags on the next visit.
    local refill = readFlag(gen3, flagId(gen3, "FLAG_SYS_SHOAL_ITEM"))
    local salt, shell = 0, 0
    for index = 1, 4 do
      if refill or not readFlag(gen3, flagId(gen3, "FLAG_RECEIVED_SHOAL_SALT_" .. index)) then salt = salt + 1 end
      if refill or not readFlag(gen3, flagId(gen3, "FLAG_RECEIVED_SHOAL_SHELL_" .. index)) then shell = shell + 1 end
    end
    local C = constants(gen3)
    local function constantItem(name)
      local ok, id = pcall(function() return C.items.byName[name] end)
      return ok and id and itemName(id) or nil
    end
    local saltName = constantItem("ITEM_SHOAL_SALT") or THEME:translate("SHOAL SALT")
    local shellName = constantItem("ITEM_SHOAL_SHELL") or THEME:translate("SHOAL SHELL")
    row.detailItems = { THEME:format("%s: %d LEFT", saltName, salt), THEME:format("%s: %d LEFT", shellName, shell) }
    row.status = THEME:translate(low and "THE INNER CAVE IS OPEN" or "WAIT FOR LOW TIDE")
    return row
  end

  local function berryRows(gen3, facts, policy)
    local BerryTrees = hostModule("src.core.game3.rse.berry_trees")
    if not BerryTrees then return {} end
    local ready, thirsty, readyPlaces, thirstyPlaces = 0, 0, {}, {}
    local next
    local function add(list, id)
      for _, other in ipairs(list) do if other == id then return end end
      list[#list + 1] = id
    end
    for _, spot in ipairs(facts.trees) do
      if policy.berries or displayRuntime.knownMap(spot.mapId) then
        -- peek() can apply pending plantings; the calendar only reads stored trees.
        local tree = (gen3.session.berryTrees or {})[spot.tree]
        local stage = tree and tonumber(tree.stage) or 0
        if tree and (tonumber(tree.berry) or 0) ~= 0 and stage ~= 0 then
          if stage == BerryTrees.STAGE_BERRIES then
            ready = ready + 1; add(readyPlaces, spot.mapId)
          elseif stage >= 1 and stage <= 4 then
            if not tree["watered" .. stage] then thirsty = thirsty + 1; add(thirstyPlaces, spot.mapId) end
            if not tree.stopGrowth then
              local okD, step = pcall(BerryTrees.stageDuration, tree.berry, gen3.session)
              if okD and tonumber(step) and step > 0 then
                local minutes = math.max(0, tonumber(tree.minutesUntilNextStage) or 0)
                  + (BerryTrees.STAGE_BERRIES - 1 - stage) * step
                if not next or minutes < next.minutes then next = { minutes = minutes, mapId = spot.mapId } end
              end
            end
          end
        end
      end
    end
    local function names(list)
      local out = {}
      for index, id in ipairs(list) do if index <= 6 then out[#out + 1] = placeName(id) end end
      return out
    end
    local rows = {}
    if ready > 0 then
      rows[#rows + 1] = { kind = "berries", key = "berries", tag = "BERRIES", state = "open", now = true,
        title = ready == 1 and THEME:translate("1 TREE READY") or THEME:format("%d TREES READY", ready),
        place = placeName(readyPlaces[1]), placeList = names(readyPlaces),
        status = THEME:translate("PICK THEM UP") }
    end
    if thirsty > 0 then
      rows[#rows + 1] = { kind = "water", key = "water", tag = "BERRIES", state = "open", now = true,
        title = thirsty == 1 and THEME:translate("1 TREE NEEDS WATER")
          or THEME:format("%d TREES NEED WATER", thirsty),
        place = placeName(thirstyPlaces[1]), placeList = names(thirstyPlaces),
        status = THEME:translate("WATER THEM FOR MORE BERRIES") }
    end
    if next then
      rows[#rows + 1] = { kind = "ripening", key = "ripening", tag = "BERRIES", state = "later", inMinutes = next.minutes,
        title = THEME:translate("NEXT HARVEST"), place = placeName(next.mapId), right = duration(next.minutes),
        status = THEME:format("RIPE %s", duration(next.minutes)) }
    end
    return rows
  end

  local function giftRows(gen3, facts, policy)
    local rows = {}
    for _, gift in ipairs(facts.gifts) do
      if policy.schedule or displayRuntime.knownMap(gift.mapId) then
        local done = readFlag(gen3, gift.flag)
        local row = { kind = gift.kind, key = gift.key, mapId = gift.mapId, place = placeName(gift.mapId),
          tag = gift.kind == "lottery" and "EVENT" or "GIFT", state = done and "done" or "open", now = not done }
        if gift.kind == "lottery" then
          row.title = THEME:translate("LOTTERY CORNER")
          row.status = THEME:translate(done and "DONE FOR TODAY" or "DRAW A TICKET TODAY")
        else
          local item = gift.item and itemName(gift.item)
          row.title = (policy.gifts or done) and item or THEME:translate(policy.gifts and "BERRY" or "A GIFT")
          if gift.name:find("WIFE") then row.trainerClass = THEME:translate("BERRY MASTER'S WIFE")
          elseif gift.name:find("BERRY_?MASTER") then row.trainerClass = THEME:translate("BERRY MASTER") end
          row.status = THEME:translate(done and "DONE FOR TODAY" or "ONCE A DAY")
        end
        rows[#rows + 1] = row
      end
    end
    return rows
  end

  local function rematchRows(gen3, facts)
    local rs = gen3.profile.id == "ruby" or gen3.profile.id == "sapphire"
    local Rematch = hostModule("src.core.game3.rse.rematch")
    local Trainers = hostModule("src.core.game3.scripting.trainers")
    if not (Rematch and Trainers) then return {} end
    local okP, pack = pcall(Trainers.pack)
    local rows = {}
    local okC, count = pcall(Rematch.count)
    for tableId = 0, (okC and count or 0) - 1 do
      local entry = Rematch.entry(tableId)
      local wants = tonumber((gen3.session.trainerRematches or {})[tableId]) or 0
      local okF, registered = pcall(function()
        -- Game path [Ruby/Sapphire]: Trainer's Eyes uses fought flags, not Emerald's contact registration flags.
        if rs then return readFlag(gen3, gen3.Flags.trainerFlagId(entry.trainers[1])) end
        return readFlag(gen3, Rematch.registeredFlagId(gen3.session, tableId))
      end)
      if entry and wants ~= 0 and okF and registered then
        local trainer = okP and pack and pack.trainers and pack.trainers[entry.trainers[1]] or {}
        local mapId = facts.maps[(entry.mapGroup or 0) * 256 + (entry.mapNum or 0)]
        rows[#rows + 1] = { kind = "rematch", key = "rematch:" .. tableId, tag = "BATTLE", state = "open",
          now = true, title = trainer.name or THEME:translate("TRAINER"), trainerClass = trainer.className,
          mapId = mapId, place = mapId and placeName(mapId) or nil,
          status = THEME:translate("WANTS A REMATCH") }
      end
    end
    return rows
  end

  -- FireRed/LeafGreen: the VS Seeker charges over 100 steps; after a use the
  -- trainers on that map who answered wait for their rematch.
  local function seekerRows(gen3)
    local VsSeeker = hostModule("src.core.game3.vs_seeker")
    local Bag = hostModule("src.core.game3.bag")
    if not (VsSeeker and Bag) then return {}, nil end
    local okH, owned = pcall(Bag.has, gen3.session.bag, VsSeeker.ITEM_VS_SEEKER, 1)
    if not (okH and owned) then return {}, nil end
    -- state() initializes save fields; opening Gear must not do that.
    local state = gen3.session.vsSeeker or {}
    local charge = math.min(VsSeeker.MAX_CHARGE, tonumber(state.steps) or 0)
    local rows = {}
    local waiting = 0
    for _, value in pairs(state.rematches or {}) do if tonumber(value) and value ~= 0 then waiting = waiting + 1 end end
    local here = session.mapId and placeName(session.mapId) or nil
    if waiting > 0 then
      rows[#rows + 1] = { kind = "rematch", key = "seeker:ready", tag = "BATTLE", state = "open", now = true,
        title = waiting == 1 and THEME:translate("1 TRAINER IS READY")
          or THEME:format("%d TRAINERS ARE READY", waiting),
        place = here, status = THEME:translate("WANTS A REMATCH") }
    end
    local full = charge >= VsSeeker.MAX_CHARGE
    rows[#rows + 1] = { kind = "seeker", key = "seeker", tag = "BATTLE", state = full and "open" or "later",
      now = full, title = itemName(VsSeeker.ITEM_VS_SEEKER) or THEME:translate("VS SEEKER"),
      right = full and THEME:translate("CHARGED") or THEME:format("%d STEPS", VsSeeker.MAX_CHARGE - charge),
      facts = { { "BATTERY", THEME:format("%d/%d STEPS", charge, VsSeeker.MAX_CHARGE) } },
      status = THEME:translate(full and "READY TO USE" or "WALK TO CHARGE IT") }
    return rows, charge
  end

  displayRuntime.gen3Calendar = {}
  function displayRuntime.gen3Calendar.supported()
    -- Game path [Gen 3]: game.ready precedes loading a save; app availability belongs to the edition, not the live session.
    return adapter() ~= nil
  end
  function displayRuntime.gen3Calendar.build()
    local gen3 = adapter()
    local model = { gen3 = true, noWeek = true, now = {}, today = {}, days = {} }
    for day = 0, 6 do model.days[day] = {} end
    if not (gen3 and gen3.session) then return model end
    local policy = { schedule = assist("event_calendar"), gifts = assist("gifts"), berries = assist("berries") }
    local rows = {}
    local function take(list) for _, row in ipairs(list) do rows[#rows + 1] = row end end
    if gen3.hoenn then
      local hour, minute = localTime(gen3)
      model.badge = { clock(hour, minute), THEME:translate("TODAY") }
      local facts = scan(gen3)
      if facts then
        take(rematchRows(gen3, facts))
        take(giftRows(gen3, facts, policy))
        take(berryRows(gen3, facts, policy))
      end
      local tide = tideRow(gen3, hour, minute, policy)
      if tide then rows[#rows + 1] = tide end
      -- The day at a glance: the clock against 24 hours, Shoal Cave's low
      -- tides once the cave is known, and the next berry harvest today.
      local now = hour * 60 + minute
      local hero = { kind = "day", minutes = now, clock = clock(hour, minute), tide = tide ~= nil, marks = {} }
      if tide then
        local low = tide.state == "open"
        local turn = low and (hour < 9 and 9 or 21) or (hour < 3 and 3 or hour < 15 and 15 or 3)
        hero.low = low
        hero.status = THEME:format(low and "LOW TIDE UNTIL %s" or "LOW TIDE FROM %s", clock(turn, 0))
      else
        hero.status = THEME:format("NEW DAY IN %d H", floor((1440 - now + 59) / 60))
      end
      for _, row in ipairs(rows) do
        if row.kind == "ripening" and row.inMinutes and now + row.inMinutes < 1440 then
          hero.marks[#hero.marks + 1] = { at = now + row.inMinutes, tag = "BERRIES" }
        end
      end
      model.hero = hero
    else
      local list, charge = seekerRows(gen3)
      model.comingUp = true
      -- The battery card above the list replaces the VS Seeker's own row.
      for _, row in ipairs(list) do if row.kind ~= "seeker" then rows[#rows + 1] = row end end
      if charge then
        local VsSeeker = hostModule("src.core.game3.vs_seeker")
        local max = VsSeeker and VsSeeker.MAX_CHARGE or 100
        model.hero = { kind = "seeker", charge = charge, max = max,
          title = itemName(VsSeeker and VsSeeker.ITEM_VS_SEEKER) or THEME:translate("VS SEEKER"),
          status = charge >= max and THEME:translate("READY TO USE")
            or THEME:format("%d STEPS TO GO", max - charge) }
      end
      model.badge = { charge and THEME:format("%d%%", charge) or "-", THEME:translate("CHARGE") }
    end
    local order = { rematch = 1, seeker = 2, gift = 3, lottery = 4, berries = 5, water = 6, tide = 7, ripening = 8 }
    table.sort(rows, function(a, b)
      local sa, sb = a.state == "done" and 1 or 0, b.state == "done" and 1 or 0
      if sa ~= sb then return sa < sb end
      local oa, ob = order[a.kind] or 99, order[b.kind] or 99
      if oa ~= ob then return oa < ob end
      return tostring(a.key) < tostring(b.key)
    end)
    for _, row in ipairs(rows) do
      if row.now then model.now[#model.now + 1] = row else model.today[#model.today + 1] = row end
    end
    return model
  end
end
