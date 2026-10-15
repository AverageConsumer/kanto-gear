-- Game path [Gen 2 / Gen 3]: build the Calendar's environment from the live
-- save and world, run features/calendar.lua (Gen 2) or the Gen 3 readers, and
-- name every row for the screen. Read only.
return function(
  THEME, assist, compat, displayRuntime, header, locationEntry, mod, render,
  session
)
  local Calendar = displayRuntime.Calendar

  local function hostModule(name)
    local ok, value = pcall(require, name)
    return ok and value or nil
  end
  local function mapName(id)
    local entry = id and locationEntry(id)
    local name = entry and (entry.name or entry.label)
    return name and tostring(name):gsub("<LF>", " "):gsub("\n", " ") or tostring(id or ""):gsub("_", " ")
  end
  local function definition(list, index)
    local direct = list and list[index]
    if type(direct) == "table" then return direct, direct.id or index end
    for id, def in pairs(list or {}) do
      if type(def) == "table" and def.index == index then return def, id end
    end
  end

  -- Engine flags through the world when it has one: badges and the contest
  -- timer live outside the flag table there.
  local function engineReader(save, world)
    return function(id)
      if id == nil then return false end
      if world and world.engineFlag then
        local ok, value = pcall(world.engineFlag, world, id)
        if ok then return value == true end
      end
      return (save.engineFlags or {})[id] == true
    end
  end
  local function engineId(data, world, name, goldId)
    if world and world.engineFlagId then
      local ok, id = pcall(world.engineFlagId, world, name, goldId)
      if ok and id then return id end
    end
    for index, flag in ipairs(data.gen2Constants and data.gen2Constants.engineFlagOrder or {}) do
      if flag == name then return index - 1 end
    end
    return goldId
  end

  local DAILY = { "ENGINE_KURT_MAKING_BALLS", "ENGINE_DAILY_BUG_CONTEST", "ENGINE_SWARM",
    "ENGINE_QWILFISH_SWARM", "ENGINE_TIME_CAPSULE", "ENGINE_ALL_FRUIT_TREES", "ENGINE_GOT_SHUCKIE_TODAY",
    "ENGINE_GOLDENROD_UNDERGROUND_MERCHANT_CLOSED", "ENGINE_FOUGHT_IN_TRAINER_HALL_TODAY",
    "ENGINE_MT_MOON_SQUARE_CLEFAIRY", "ENGINE_UNION_CAVE_LAPRAS", "ENGINE_GOLDENROD_UNDERGROUND_GOT_HAIRCUT",
    "ENGINE_GOLDENROD_DEPT_STORE_TM27_RETURN", "ENGINE_DAISYS_GROOMING", "ENGINE_INDIGO_PLATEAU_RIVAL_FIGHT",
    "ENGINE_DAILY_MOVE_TUTOR", "ENGINE_BUENAS_PASSWORD" }

  local weeklyCache = setmetatable({}, { __mode = "k" })
  local function gen2Env()
    local game = session.game
    local save, data, world = game.save or {}, game.data or {}, game.world
    local flag = engineReader(save, world)
    local function event(id)
      if world and world.events and world.events.get then
        local ok, value = pcall(world.events.get, world.events, id)
        if ok then return value == true end
      end
      if mod.world and mod.world.getFlag then
        local ok, value = pcall(mod.world.getFlag, mod.world, id)
        if ok and value ~= nil then return value == true end
      end
      return false
    end
    local weekday, hour = 0, 12
    if world and world.weekday then
      local ok, value = pcall(world.weekday, world)
      if ok and tonumber(value) then weekday = value % 7 end
    else
      local Clock = hostModule("src.core.gen2.Clock")
      if Clock and Clock.weekday then weekday = (Clock.weekday(save) or 0) % 7 end
    end
    if world and world.hour then
      local ok, value = pcall(world.hour, world)
      if ok and tonumber(value) then hour = value end
    end
    local period = compat.timePeriod(world)
      or (hour >= 4 and hour < 10 and "MORN" or hour >= 10 and hour < 18 and "DAY" or "NITE")
    local daily = {}
    for _, name in ipairs(DAILY) do
      local id = engineId(data, world, name, nil)
      if id then daily[id] = true end
    end
    local registered = {}
    for _, id in ipairs(save.phone and save.phone.list or {}) do
      if tonumber(id) and id ~= 0 then registered[id] = true end
    end
    for id in pairs(save.phoneContacts or {}) do
      if tonumber(id) then registered[tonumber(id)] = true end
    end
    local order = data.gen2Constants and data.gen2Constants.engineFlagOrder
    local eventNames
    if save.version ~= "crystal" then
      local FlagNames = hostModule("src.core.gen2.FlagNames")
      eventNames = {}
      for name, id in pairs(FlagNames and FlagNames.events or {}) do eventNames[id] = name end
    end
    local inventory = save.inventory or {}
    local env = {
      data = data, save = save, weekday = weekday, hour = hour, period = period,
      event = event, flag = flag, daily = daily, registered = registered,
      item = function(index)
        local _, id = definition(data.items, index)
        return id ~= nil and (tonumber(inventory[id]) or 0) > 0
      end,
      engineName = function(id) return order and order[id + 1] or nil end,
      eventName = eventNames and function(id) return eventNames[id] end or nil,
      knownMap = function(id) return displayRuntime.knownMap(id) end,
      policy = { schedule = assist("event_calendar"), gifts = assist("gifts"), berries = assist("berries"),
        species = assist("unknown_species") },
      done = {
        contest = flag(engineId(data, world, "ENGINE_DAILY_BUG_CONTEST", 80)),
        haircut = flag(engineId(data, world, "ENGINE_GOLDENROD_UNDERGROUND_GOT_HAIRCUT", 89)),
        shop = flag(engineId(data, world, "ENGINE_GOLDENROD_UNDERGROUND_MERCHANT_CLOSED", 85)),
        tutor = flag(engineId(data, world, "ENGINE_DAILY_MOVE_TUTOR", nil)),
      },
    }
    -- The weekly scan reruns only when a flag it can read may have changed:
    -- keyed by the weekday and the save, refreshed every few seconds.
    local cache = weeklyCache[data]
    local now = love.timer.getTime()
    if not cache or cache.save ~= save or cache.weekday ~= weekday or cache.period ~= period
        or now - cache.at > 4 then
      cache = { save = save, weekday = weekday, period = period, at = now, weekly = Calendar.weekly(env) }
      weeklyCache[data] = cache
    end
    env.weekly = cache.weekly
    env.contacts = Calendar.contacts(env)
    -- Daily extras: Kurt's balls, Buena's Password (Crystal) and fruit trees.
    local extras = {}
    local Apricorns = hostModule("src.core.gen2.Apricorns")
    if Apricorns and Apricorns.BALLS then
      local balls = {}
      for _, ball in ipairs(Apricorns.BALLS) do
        if event(ball.event) then balls[#balls + 1] = ball.ball end
      end
      if #balls > 0 then
        local making = flag(engineId(data, world, "ENGINE_KURT_MAKING_BALLS", Apricorns.ENGINE_KURT_MAKING_BALLS))
        extras[#extras + 1] = { kind = "kurt", key = "kurt", mapId = "KURTS_HOUSE", items = balls,
          state = making and "later" or "open", now = not making }
      end
    end
    if save.version == "crystal" and flag(engineId(data, world, "ENGINE_RADIO_CARD", 0)) then
      local given = flag(engineId(data, world, "ENGINE_BUENAS_PASSWORD_2", 96))
      local onAir = hour >= 18
      extras[#extras + 1] = { kind = "buena", key = "buena", mapId = "RADIO_TOWER_2F",
        state = given and "done" or onAir and "open" or "later", now = onAir and not given }
    end
    if env.policy.berries and displayRuntime.fruitTrees then
      local ready, places = 0, {}
      local ids = {}
      for id in pairs(data.gen2Maps or {}) do ids[#ids + 1] = id end
      table.sort(ids)
      local trees = weeklyCache[data].trees
      if not trees then
        trees = {}
        for _, id in ipairs(ids) do
          local rows = displayRuntime.fruitTrees.rows(data, id)
          if #rows > 0 then trees[#trees + 1] = { mapId = id, rows = rows } end
        end
        weeklyCache[data].trees = trees
      end
      for _, place in ipairs(trees) do
        if displayRuntime.knownMap(place.mapId) then
          local count = 0
          for _, row in ipairs(place.rows) do
            if not displayRuntime.fruitTrees.picked(save, row.tree) then count = count + 1 end
          end
          if count > 0 then
            ready = ready + count
            places[#places + 1] = place.mapId
          end
        end
      end
      if ready > 0 then
        extras[#extras + 1] = { kind = "berries", key = "berries", count = ready, places = places,
          mapId = places[1], state = "open", now = true }
      end
    end
    env.extras = extras
    return env
  end

  -- Words for one row, from the game's own names wherever it has them.
  local DAY_TIME = { [1] = "MORNING", [2] = "AFTERNOON", [4] = "NIGHT" }
  local function itemNames(data, items, policy, state)
    local names = {}
    for _, item in ipairs(items or {}) do
      local def = type(item) == "number" and definition(data.items, item) or data.items and data.items[item]
      names[#names + 1] = def and def.name or tostring(item):gsub("_", " ")
    end
    return names
  end
  local function trainerNames(data, row)
    local class = definition(data.gen2Trainers and data.gen2Trainers.classes, row.class)
    local member = class and class.trainers and class.trainers[row.member]
    return member and member.name or THEME:translate("TRAINER"), class and class.name or nil
  end
  local TAGS = { gift = "GIFT", wild = "WILD", contest = "EVENT", tutor = "TUTOR", haircut = "SERVICE",
    shop = "SHOP", rematch = "BATTLE", phone_gift = "GIFT", call = "CALL", kurt = "BALLS",
    buena = "RADIO", berries = "BERRIES" }
  function displayRuntime.nameCalendarRow(row, env)
    local data, policy = env.data or {}, env.policy or {}
    row.tag = TAGS[row.kind] or "EVENT"
    row.place = row.mapId and mapName(row.mapId) or nil
    if row.kind == "gift" then
      local shown = policy.gifts or row.state == "done"
      row.title = shown and table.concat(itemNames(data, row.items), " / ") or THEME:translate("A GIFT")
    elseif row.kind == "wild" then
      local def = definition(data.pokemon, row.species)
      local seen = def and session.game.save.pokedex and session.game.save.pokedex.seen
        and session.game.save.pokedex.seen[def.id or row.species]
      row.title = (policy.species or seen) and def and def.name or THEME:translate("RARE POKEMON")
    elseif row.kind == "contest" then row.title = THEME:translate("BUG-CATCHING CONTEST")
    elseif row.kind == "tutor" then row.title = THEME:translate("MOVE TUTOR")
    elseif row.kind == "haircut" then row.title = THEME:translate("HAIRCUT BROTHERS")
    elseif row.kind == "shop" then row.title = THEME:translate("MERCHANT")
    elseif row.kind == "rematch" or row.kind == "call" or row.kind == "phone_gift" then
      row.trainer, row.trainerClass = trainerNames(data, row)
      if row.kind == "phone_gift" then
        row.title = table.concat(itemNames(data, { row.item }), "")
        if row.item == "ITEM" then row.title = THEME:translate("A GIFT") end
      else
        row.title = row.trainer
      end
    elseif row.kind == "kurt" then
      row.title = THEME:translate(row.state == "later" and "BALLS READY TOMORROW" or "BALLS ARE READY")
      row.detailItems = itemNames(data, row.items)
    elseif row.kind == "buena" then
      row.title = THEME:translate("BUENA'S PASSWORD")
    elseif row.kind == "berries" then
      row.title = row.count == 1 and THEME:translate("1 TREE READY") or THEME:format("%d TREES READY", row.count)
      local names = {}
      for index, id in ipairs(row.places or {}) do if index <= 3 then names[#names + 1] = mapName(id) end end
      row.placeList = names
    end
    if row.mask and row.mask ~= 7 then
      row.when = {}
      for _, bit in ipairs({ 1, 2, 4 }) do
        if Calendar.band(row.mask, bit) ~= 0 then row.when[#row.when + 1] = DAY_TIME[bit] end
      end
    end
    return row
  end

  displayRuntime.calendar = displayRuntime.calendar or {}
  function displayRuntime.calendarSupported()
    if displayRuntime.gen3 then return displayRuntime.gen3Calendar ~= nil and displayRuntime.gen3Calendar.supported() end
    return session.game and session.game.save and session.game.save.generation == 2 or false
  end
  function displayRuntime.applyCalendarSupport()
    local supported = displayRuntime.calendarSupported()
    local entry = displayRuntime.storeById.calendar
    if entry then entry.hidden = not supported end
    for _, id in ipairs({ "calendar_widget", "calendar_small_widget", "calendar_app" }) do
      local surface = displayRuntime.homeCatalog.surfaces[id]
      if surface then surface.hidden = not supported end
    end
  end

  local modelCache
  function displayRuntime.invalidateCalendar() modelCache = nil end
  function displayRuntime.calendarModel()
    if not (session.game and session.game.save) or not displayRuntime.calendarSupported() then
      return { unsupported = true, now = {}, today = {}, days = {} }
    end
    local now = love.timer.getTime()
    if modelCache and modelCache.save == session.game.save and now - modelCache.at < 0.5
        and modelCache.signature == session.discoveryPolicy.signature then return modelCache.model end
    local model
    if displayRuntime.gen3 then
      model = displayRuntime.gen3Calendar.build()
    else
      local env = gen2Env()
      model = Calendar.build(env)
      local named = {}
      local function name(row)
        if not named[row] then named[row] = true; displayRuntime.nameCalendarRow(row, env) end
      end
      for _, list in ipairs({ model.now, model.today }) do for _, row in ipairs(list) do name(row) end end
      for day = 0, 6 do for _, row in ipairs(model.days[day]) do name(row) end end
    end
    model.dayNames, model.shortNames = Calendar.DAYS, Calendar.SHORT
    modelCache = { save = session.game.save, at = now, model = model,
      signature = session.discoveryPolicy.signature }
    return model
  end

  function displayRuntime.drawCalendar()
    local state = displayRuntime.calendar
    local model = displayRuntime.calendarModel()
    model.view, model.day, model.selected, model.page = state.view, state.day, state.selected, state.page or 1
    local title = THEME:translate("CALENDAR")
    if state.view == "detail" and state.selected then
      model.entry = nil
      for _, list in ipairs({ model.now, model.today, model.days[state.day or model.weekday] or {} }) do
        for _, row in ipairs(list) do
          if row.key == state.selected then model.entry = row end
        end
      end
      if not model.entry then state.view, state.selected, model.view = nil, nil, nil
      else title = model.entry.title or title end
    end
    header(title, true, false)
    render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    THEME.hgss:calendar(model)
    state.page = model.page or 1
    render.G.pop()
  end

  function displayRuntime.tapCalendar(x, y)
    local state = displayRuntime.calendar
    if y < 30 and x < 35 then
      if state.view == "detail" then state.view, state.selected = state.parent, nil
      else session.page, displayRuntime.home.activeApp = "HOME", nil end
      session.dirty = true
      return
    end
    local action, value = THEME.hgss:calendarHit(x, y)
    if action == "day" then
      local model = displayRuntime.calendarModel()
      state.day, state.page = value ~= model.weekday and value or nil, 1
      state.view = nil
    elseif action == "entry" then
      state.parent, state.view, state.selected = state.view, "detail", value
    elseif action == "page" then
      state.page = math.max(1, (state.page or 1) + value)
    end
    if action then displayRuntime.haptic(); session.dirty = true end
  end
end
