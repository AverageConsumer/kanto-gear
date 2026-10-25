-- Notice sources beyond Shiny Hunt and Moments: the Day-Care (an egg is
-- waiting, a boarder grew), the Calendar (something is open right now) and
-- the Stamp Book (a silver or gold stamp in the current area). Each follows
-- its own switch in the Notifications settings. Read only: everything comes
-- from the same models the apps draw, polled gently while the field is free.
return function(THEME, compat, displayRuntime, mod, session)
  local state = { save = nil }
  displayRuntime.noticeSources = state
  local DAYCARE_EVERY, CALENDAR_EVERY, STAMPS_EVERY = 5, 8, 4
  local RANK = { none = 0, bronze = 1, silver = 2, gold = 3 }

  local function notify(notice)
    if displayRuntime.notify then return displayRuntime.notify(notice) end
  end

  local function reset(save)
    state.save = save
    state.boarders, state.calendar, state.weekday, state.stamps = {}, nil, nil, {}
    state.nextDaycare, state.nextCalendar, state.nextStamps = 0, 0, 0
  end
  reset(nil)

  ----------------------------------------------------------------------------
  -- Day-Care
  ----------------------------------------------------------------------------
  local function daycarePlace()
    if not displayRuntime.daycareInput then return nil end
    local ok, input = pcall(displayRuntime.daycareInput)
    return ok and type(input) == "table" and input.place or nil
  end

  mod.events:on("breeding.egg_created", function()
    if not session.active then return end
    notify({ key = "daycare:egg", app = "daycare", page = "DAYCARE", area = "daycare",
      title = THEME:translate("AN EGG IS WAITING"), detail = daycarePlace() or THEME:translate("DAY-CARE"),
      icon = "daycare" })
  end)

  -- Boarders grow while you walk: one card per level, merged per boarder.
  local function pollDaycare()
    if not displayRuntime.daycareInput then return end
    local ok, input = pcall(displayRuntime.daycareInput)
    if not ok or type(input) ~= "table" then return end
    local seen = {}
    for _, parent in ipairs(input.parents or {}) do
      local key = tostring(parent.key)
      local level = tonumber(parent.levelNow)
      seen[key] = true
      local before = state.boarders[key]
      if level and before and before.name == parent.name and level > before.level then
        notify({ key = "daycare:level:" .. key, app = "daycare", page = "DAYCARE", area = "daycare",
          title = THEME:translate("DAY-CARE"),
          detail = THEME:format("%s GREW TO LV. %d", tostring(parent.name or "?"), level), icon = "daycare" })
      end
      if level then state.boarders[key] = { level = level, name = parent.name } end
    end
    for key in pairs(state.boarders) do if not seen[key] then state.boarders[key] = nil end end
  end

  ----------------------------------------------------------------------------
  -- Calendar: what opens now. The first look of a session sums up the day.
  ----------------------------------------------------------------------------
  local function rowText(row)
    local title = tostring(row.title or THEME:translate(row.tag or "EVENT"))
    if row.place and row.place ~= "" and row.place ~= title then return title .. " - " .. row.place end
    return title
  end

  local function pollCalendar()
    if not (displayRuntime.calendarSupported and displayRuntime.calendarSupported()) then return end
    local ok, model = pcall(displayRuntime.calendarModel)
    if not ok or type(model) ~= "table" or model.unsupported then return end
    local open = {}
    for _, row in ipairs(model.now or {}) do
      if row.state == nil or row.state == "open" then open[#open + 1] = row end
    end
    local first = state.calendar == nil
    if state.weekday ~= model.weekday then
      -- A new day brings its own news; the very first look only sums up.
      if not first then state.calendar = {} end
      state.weekday = model.weekday
    end
    if first then
      state.calendar = {}
      for _, row in ipairs(open) do state.calendar[row.key] = true end
      if #open > 0 then
        notify({ key = "calendar:today", app = "calendar", page = "CALENDAR", area = "calendar",
          title = THEME:translate(#open > 1 and "OPEN RIGHT NOW" or "NOW OPEN"),
          detail = #open > 1 and THEME:format("%s +%d", rowText(open[1]), #open - 1) or rowText(open[1]),
          icon = "calendar" })
      end
      return
    end
    for _, row in ipairs(open) do
      if row.key and not state.calendar[row.key] then
        state.calendar[row.key] = true
        notify({ key = "calendar:" .. tostring(row.key), app = "calendar", page = "CALENDAR", area = "calendar",
          title = THEME:format("NOW: %s", THEME:translate(row.tag or "EVENT")), detail = rowText(row),
          icon = "calendar" })
      end
    end
  end

  ----------------------------------------------------------------------------
  -- Stamps: a silver or gold stamp earned where you stand.
  ----------------------------------------------------------------------------
  local function pollStamps()
    local package = displayRuntime.homeCatalog and displayRuntime.homeCatalog.packages.achievements
    if not (package and package.installed) or not session.mapId then return end
    if displayRuntime.discoveryMode and displayRuntime.discoveryMode() == "vanilla" then return end
    local ok, data = pcall(displayRuntime.achievementData, true)
    if not ok or type(data) ~= "table" then return end
    for _, area in ipairs(data.areas or {}) do
      local before = state.stamps[area.id]
      local tier = area.tier or "none"
      if before and (RANK[tier] or 0) > (RANK[before] or 0) and (tier == "silver" or tier == "gold") then
        local id, kind = area.id, area.kind
        notify({ key = "stamp:" .. tostring(id), app = "achievements", page = "ACHIEVEMENTS", area = "stamps",
          title = THEME:translate(tier == "gold" and "GOLD STAMP!" or "SILVER STAMP!"),
          detail = area.name, tone = tier == "gold" and "special" or nil,
          drawIcon = function(x, y, size)
            local r = math.floor(size / 2) - 1
            THEME.hgss:achievementSeal(x + r + 1, y + r + 1, r, kind, tier)
          end,
          onOpen = function()
            local view = displayRuntime.achievements
            if view then view.view, view.selected, view.page, view.parent = "detail", id, 1, "goals" end
          end })
      end
      state.stamps[area.id] = tier
    end
  end

  ----------------------------------------------------------------------------
  -- Gentle polling from the notice tick, only while the field is free.
  ----------------------------------------------------------------------------
  function displayRuntime.pollNoticeSources(now)
    local game = session.game
    if not session.active or not game or not game.save then return end
    if state.save ~= game.save then reset(game.save) end
    if session.battle then return end
    if displayRuntime.noticeLevel and displayRuntime.noticeLevel("daycare") ~= "off" and now >= state.nextDaycare then
      state.nextDaycare = now + DAYCARE_EVERY
      pollDaycare()
    end
    if displayRuntime.noticeLevel and displayRuntime.noticeLevel("calendar") ~= "off" and now >= state.nextCalendar then
      state.nextCalendar = now + CALENDAR_EVERY
      pollCalendar()
    end
    if displayRuntime.noticeLevel and displayRuntime.noticeLevel("stamps") ~= "off" and now >= state.nextStamps then
      state.nextStamps = now + STAMPS_EVERY
      pollStamps()
    end
  end
end
