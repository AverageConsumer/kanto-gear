-- Calendar facts for Gen 2 (Gold/Silver/Crystal). Everything weekly is read
-- from the imported map scripts: a map's object callback is run for each
-- weekday against the live flags, so siblings, Lapras, the Bug-Catching
-- Contest, Goldenrod's merchants and tutors come from the cartridge itself
-- rather than from a hand-kept table. Phone rematches come from the contact
-- table and each contact's own callee script. Read only.
local M = {}

M.DAYS = { "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY" }
M.SHORT = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" }
M.TIME_BITS = { MORN = 1, DAY = 2, NITE = 4 }
M.PERIODS = { { "MORN", 1 }, { "DAY", 2 }, { "NITE", 4 } }
local VAR_WEEKDAY = 11

local function band(a, b)
  local out, bit = 0, 1
  a, b = math.floor(tonumber(a) or 0), math.floor(tonumber(b) or 0)
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then out = out + bit end
    a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
  end
  return out
end
M.band = band

-- Does a script (or anything it jumps to) read the weekday?
function M.readsWeekday(scripts, key, seen)
  seen = seen or {}
  if not key or seen[key] then return false end
  seen[key] = true
  for _, command in ipairs(scripts[key] or {}) do
    if command.op == "readvar" and command.var == VAR_WEEKDAY then return true end
    if command.script and M.readsWeekday(scripts, command.script, seen) then return true end
  end
  return false
end

-- A small interpreter for map callbacks: conditions, jumps, calls and the
-- appear/disappear writes. Unknown commands are skipped; reads come from env.
-- Returns { [objectIndex] = visible } for every object the callback touched.
function M.runCallback(scripts, key, env)
  local events, flags, touched = {}, {}, {}
  local stack, value, cond = {}, 0, false
  local list, at, steps = scripts[key], 1, 0
  local function jump(target, call)
    if call then stack[#stack + 1] = { list, at } end
    list, at = scripts[target], 1
  end
  while list and steps < 2048 do
    steps = steps + 1
    local c = list[at]
    at = at + 1
    if not c then
      local frame = table.remove(stack)
      if not frame then break end
      list, at = frame[1], frame[2]
    else
      local op = c.op
      if op == "readvar" then
        value = c.var == VAR_WEEKDAY and env.weekday or (env.var and env.var(c.var)) or 0
      elseif op == "ifequal" then if value == c.value then jump(c.script) end
      elseif op == "ifnotequal" then if value ~= c.value then jump(c.script) end
      elseif op == "ifgreater" then if value > (c.value or 0) then jump(c.script) end
      elseif op == "ifless" then if value < (c.value or 0) then jump(c.script) end
      elseif op == "iftrue" then if cond then jump(c.script) end
      elseif op == "iffalse" then if not cond then jump(c.script) end
      elseif op == "checkevent" then
        if events[c.event] ~= nil then cond = events[c.event] else cond = env.event(c.event) == true end
      elseif op == "checkflag" then
        if flags[c.flag] ~= nil then cond = flags[c.flag] else cond = env.flag(c.flag) == true end
      elseif op == "checkitem" then
        cond = env.item ~= nil and env.item((c.args or {})[1] or c.item) == true
      elseif op == "checktime" then
        cond = band((c.args or {})[1] or c.time or 0, M.TIME_BITS[env.period or "DAY"] or 2) ~= 0
      elseif op == "setevent" then events[c.event] = true
      elseif op == "clearevent" then events[c.event] = false
      elseif op == "setflag" then flags[c.flag] = true
      elseif op == "clearflag" then flags[c.flag] = false
      elseif op == "appear" or op == "disappear" then
        local object = (c.args or {})[1] or c.object
        if object then touched[object - 1] = op == "appear" end
      elseif op == "sjump" or op == "farsjump" then jump(c.script)
      elseif op == "scall" or op == "farscall" then jump(c.script, true)
      elseif op == "end" or op == "endcallback" or op == "return" then
        local frame = table.remove(stack)
        if not frame then break end
        list, at = frame[1], frame[2]
      end
    end
  end
  return touched
end

-- What an object does, read from everything its script can reach.
local function walk(scripts, key, visit, seen, depth)
  seen, depth = seen or {}, depth or 0
  if not key or seen[key] or depth > 8 then return end
  seen[key] = true
  local commands = scripts[key] or {}
  for index, command in ipairs(commands) do
    visit(command, commands, index)
    if command.script then walk(scripts, command.script, visit, seen, depth + 1) end
  end
end

function M.classify(data, object)
  local scripts = data.gen2Scripts or {}
  local specials = data.gen2Constants and data.gen2Constants.specialOrder or {}
  local found = { items = {}, specials = {} }
  walk(scripts, object.scriptKey, function(command, commands, index)
    if command.op == "special" then
      found.specials[tostring(specials[(command.id or -1) + 1])] = true
    elseif (command.op == "verbosegiveitem" or command.op == "giveitem") and command.item then
      local known = false
      for _, item in ipairs(found.items) do if item == command.item then known = true end end
      if not known then found.items[#found.items + 1] = command.item end
      for after = index + 1, #commands do
        local next = commands[after]
        if next.op == "setevent" and not found.gotEvent then found.gotEvent = next.event end
        if next.op == "setflag" and not found.gotFlag then found.gotFlag = next.flag end
        if next.op == "end" or next.op == "sjump" then break end
      end
    elseif command.op == "loadwildmon" then found.species = command.species or (command.args or {})[1]
    elseif command.op == "pokemart" then found.shop = true
    end
  end)
  local s = found.specials
  if s.SelectRandomBugContestContestants or s.BugContest or s.GiveParkBalls then
    found.kind = "contest"
  elseif s.MoveTutor then found.kind = "tutor"
  elseif s.OlderHaircutBrother or s.YoungerHaircutBrother then found.kind = "haircut"
  elseif #found.items > 0 then found.kind = "gift"
  elseif found.species then found.kind = "wild"
  elseif found.shop then found.kind = "shop"
  end
  return found
end

-- Weekly visitors: every object whose presence a weekday callback decides.
-- `days` uses today's flags; `possible` treats the daily flags as reset, so
-- a visitor present on its day but already met today reads as done.
function M.weekly(env)
  local data = env.data
  local maps, scripts = data.gen2Maps or {}, data.gen2Scripts or {}
  local ids = {}
  for id in pairs(maps) do ids[#ids + 1] = id end
  table.sort(ids)
  local resetEnv = setmetatable({ flag = function(id)
    if env.daily and env.daily[id] then return false end
    return env.flag(id)
  end }, { __index = env })
  local out = {}
  for _, mapId in ipairs(ids) do
    local map = maps[mapId]
    local callbacks = {}
    for _, callback in ipairs(map.callbacks or {}) do
      if (callback.callback == "MAPCALLBACK_OBJECTS" or callback.callback == "MAPCALLBACK_NEWMAP")
          and M.readsWeekday(scripts, callback.scriptKey) then
        callbacks[#callbacks + 1] = callback.scriptKey
      end
    end
    if #callbacks > 0 then
      local seenDays, masks = {}, {}
      for day = 0, 6 do
        local visible = {}
        local todayEnv = setmetatable({ weekday = day }, { __index = env })
        for _, key in ipairs(callbacks) do
          for object, shown in pairs(M.runCallback(scripts, key, todayEnv)) do visible[object] = shown end
        end
        seenDays[day] = visible
        masks[day] = {}
        for _, period in ipairs(M.PERIODS) do
          local visible = {}
          local runEnv = setmetatable({ weekday = day, period = period[1] }, { __index = resetEnv })
          for _, key in ipairs(callbacks) do
            for object, shown in pairs(M.runCallback(scripts, key, runEnv)) do visible[object] = shown end
          end
          for object, shown in pairs(visible) do
            if shown then masks[day][object] = (masks[day][object] or 0) + period[2] end
          end
        end
      end
      local found = {}
      for index, object in ipairs(map.objects or {}) do
        local varies = false
        for day = 1, 6 do
          if masks[day][index] ~= masks[0][index] then varies = true end
        end
        if varies then
          local info = M.classify(data, object)
          if info.kind then
            local days, possible, periods = {}, {}, {}
            for day = 0, 6 do
              if seenDays[day][index] == true then days[day] = true end
              if masks[day][index] then possible[day] = true end
              periods[day] = masks[day][index]
            end
            found[#found + 1] = { mapId = mapId, object = index, x = object.x, y = object.y,
              kind = info.kind, items = info.items, species = info.species,
              gotEvent = info.gotEvent, gotFlag = info.gotFlag, days = days, possible = possible,
              masks = periods }
          end
        end
      end
      -- A contest gate's off-day officer only hands back earlier prizes.
      local contest = false
      for _, entry in ipairs(found) do contest = contest or entry.kind == "contest" end
      for _, entry in ipairs(found) do
        if not (contest and entry.kind == "gift") then out[#out + 1] = entry end
      end
    end
  end
  return out
end

-- Phone contacts: who the player has registered, where they stand, whether
-- they already want a rematch or hold a gift, and (Crystal) the one day and
-- time of day a call arranges their rematch.
function M.contacts(env)
  local data = env.data
  local rows = data.gen2EventTables and data.gen2EventTables.phone or {}
  local scripts = data.gen2Scripts or {}
  local out = {}
  for _, row in ipairs(rows) do
    local trainer = (row.trainerClass or 0) ~= 0
    if trainer and env.registered[row.id] then
      local contact = { id = row.id, map = row.map, class = row.trainerClass, member = row.number }
      local commands = scripts[row.callee] or {}
      local day
      for index, command in ipairs(commands) do
        if command.op == "checkflag" or command.op == "checkevent" then
          local name = command.op == "checkflag" and env.engineName and env.engineName(command.flag)
            or command.op == "checkevent" and env.eventName and env.eventName(command.event) or ""
          local read = command.op == "checkflag" and env.flag(command.flag) or command.op == "checkevent" and env.event(command.event)
          if name:find("_READY_FOR_REMATCH$") then
            contact.ready = read == true
          elseif name:find("_HAS_") then
            contact.gift = contact.gift or {}
            if read == true then
              contact.gift[#contact.gift + 1] = name:gsub("^ENGINE_", ""):gsub("^EVENT_", ""):gsub("^[A-Z]+_HAS_", "")
            end
          else
            local dayName, period = name:match("^ENGINE_[A-Z]+_([A-Z]+DAY)_([A-Z]+)$")
            if dayName then contact.windowFlag, contact.windowDone = command.flag, read == true end
          end
        elseif command.op == "readvar" and command.var == VAR_WEEKDAY then
          local test = commands[index + 1]
          if test and test.op == "ifnotequal" then day = test.value end
        elseif command.op == "checktime" and day then
          contact.window = { day = day, mask = (command.args or {})[1] or 0 }
        end
      end
      out[#out + 1] = contact
    end
  end
  return out
end

-- Today in one place: what can be done right now, the rest of today, and
-- the week ahead. Entries carry plain ids and keys; the runtime names them.
function M.build(env)
  local weekday, period = env.weekday, env.period or "DAY"
  local bit = M.TIME_BITS[period] or 2
  local model = { weekday = weekday, period = period, now = {}, today = {}, days = {} }
  for day = 0, 6 do model.days[day] = {} end
  local schedule = env.policy.schedule
  -- One row per service and day: two contest gates, two barber brothers.
  local single = { contest = true, haircut = true, shop = true, tutor = true }
  local placed = {}
  for _, entry in ipairs(env.weekly or M.weekly(env)) do
    local known = env.knownMap(entry.mapId)
    local gotForever = entry.gotEvent and env.event(entry.gotEvent)
    if (schedule or known) and not gotForever then
      for day = 0, 6 do
        local slot = entry.kind .. ":" .. day
        if entry.possible[day] and not (single[entry.kind] and placed[slot]) then
          placed[slot] = true
          local row = { kind = entry.kind, key = entry.kind .. ":" .. entry.mapId .. ":" .. entry.object,
            mapId = entry.mapId, x = entry.x, y = entry.y, items = entry.items, species = entry.species,
            day = day, mask = entry.masks and entry.masks[day] }
          if day == weekday then
            row.state = entry.days[day] and "open" or "done"
            if row.mask and band(row.mask, bit) == 0 then
              local later = false
              for _, slot in ipairs(M.PERIODS) do
                if slot[2] > bit and band(row.mask, slot[2]) ~= 0 then later = true end
              end
              row.state = later and "later" or "missed"
            end
            if entry.gotFlag and env.flag(entry.gotFlag) then row.state = "done" end
            if env.done and env.done[entry.kind] then row.state = "done" end
            model.today[#model.today + 1] = row
          end
          model.days[day][#model.days[day] + 1] = row
        end
      end
    end
  end
  for _, contact in ipairs(env.contacts or M.contacts(env)) do
    local base = { mapId = contact.map, class = contact.class, member = contact.member, contact = contact.id }
    if contact.ready then
      local row = setmetatable({ kind = "rematch", key = "rematch:" .. contact.id, state = "open" }, { __index = base })
      model.now[#model.now + 1] = row
    end
    for _, item in ipairs(contact.gift or {}) do
      local row = setmetatable({ kind = "phone_gift", key = "gift:" .. contact.id .. ":" .. item,
        item = item, state = "open" }, { __index = base })
      model.now[#model.now + 1] = row
    end
    local window = contact.window
    if window and schedule and not contact.ready then
      local row = setmetatable({ kind = "call", key = "call:" .. contact.id, day = window.day,
        mask = window.mask }, { __index = base })
      if window.day == weekday then
        -- The window may still come today, be open now, or have passed.
        local later = false
        for _, slot in ipairs(M.PERIODS) do
          if slot[2] > bit and band(window.mask, slot[2]) ~= 0 then later = true end
        end
        row.state = contact.windowDone and "done" or band(window.mask, bit) ~= 0 and "open"
          or later and "later" or "missed"
        model.today[#model.today + 1] = row
        if row.state == "open" then model.now[#model.now + 1] = row end
      end
      model.days[window.day][#model.days[window.day] + 1] = row
    end
  end
  -- Visitors here today and open at this hour lead "now" with the calls.
  for _, row in ipairs(model.today) do
    if row.kind ~= "call" and row.state == "open" then model.now[#model.now + 1] = row end
  end
  for _, extra in ipairs(env.extras or {}) do
    if extra.now then model.now[#model.now + 1] = extra else model.today[#model.today + 1] = extra end
  end
  local order = { rematch = 1, phone_gift = 2, call = 3, gift = 4, wild = 5, contest = 6,
    tutor = 7, haircut = 8, shop = 9, kurt = 10, buena = 11, berries = 12 }
  local function sort(list)
    table.sort(list, function(a, b)
      local sa, sb = a.state == "done" and 1 or 0, b.state == "done" and 1 or 0
      if sa ~= sb then return sa < sb end
      local oa, ob = order[a.kind] or 99, order[b.kind] or 99
      if oa ~= ob then return oa < ob end
      return tostring(a.key) < tostring(b.key)
    end)
  end
  sort(model.now); sort(model.today)
  for day = 0, 6 do sort(model.days[day]) end
  return model
end

return M
