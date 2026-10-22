-- Read-only adventure progress. Never persist earned stamps separately from
-- the save: loading an older save must also restore its actual progress.
local M = {}

function M.groups(maps, locations)
  local byKey, out = {}, {}
  for id, map in pairs(maps or {}) do
    local place = locations[id] or {}
    local name = tostring(place.name or place.label or id):gsub("<LF>", " "):gsub("\n", " ")
    local xy = place.coords or place
    local key = place.progressGroup or (name .. ":" .. tostring(xy.x or xy.col or id)
      .. ":" .. tostring(xy.y or xy.row or id))
    local group = byKey[key]
    if not group then
      group = { id = id, name = name, maps = {}, kind = "route" }
      byKey[key], out[#out + 1] = group, group
    end
    group.maps[#group.maps + 1] = id
    if id < group.id then group.id = id end
    local tileset = tostring(map.tileset or "")
    if place.progressKind then
      if place.progressKind == "forest" or group.kind == "route" then group.kind = place.progressKind end
    elseif tileset:find("FOREST") or id:find("FOREST") then group.kind = "forest"
    elseif tileset:find("CAVE") or tileset:find("CAVERN") then group.kind = "cave" end
  end
  for _, group in ipairs(out) do table.sort(group.maps) end
  table.sort(out, function(a, b)
    -- Natural route ordering without sorting translated UI strings.
    local function key(name)
      return name:gsub("%d+", function(n) return string.format("%05d", n) end)
    end
    if a.name == b.name then return a.id < b.id end
    return key(a.name) < key(b.name)
  end)
  return out
end

function M.rowState(row, category, context)
  if row.untracked then return "untracked" end
  if row.repeatable then return "repeatable" end
  if row.excluded then return "excluded" end
  if row.missed or row.status == "MISSED" then return "unavailable" end
  if row.status == "LOST" then return "unavailable" end
  -- A temporary or missing flag is not durable proof, even while it is set.
  -- Game path [Gen 2]: temporary flags, sentinel 65535 and missing events cannot prove a permanent stamp objective.
  if context.gen2 and (category ~= 4 or row.gift) and not row.catchGoal and row.tradeId == nil and (row.event == nil or row.event == 65535
      or type(row.event) == "number" and row.event < 8) then return "untracked" end
  if row.done then return "done" end
  local id, flags = row.mapId or "", context.save.flags or {}
  -- Game path [Gen 1]: ship departure removes remaining finds; choosing one Mt Moon fossil permanently excludes the other.
  if not context.gen2 and not context.gen3 then
    if id:match("^SS_ANNE_") and flags.EVENT_SS_ANNE_LEFT then return "unavailable" end
    -- Taking one fossil permanently removes the alternative, not a second find.
    if category == 2 and id == "MT_MOON_B2F"
        and (row.itemId == "DOME_FOSSIL" or row.itemId == "HELIX_FOSSIL")
        and (flags.EVENT_GOT_DOME_FOSSIL or flags.EVENT_GOT_HELIX_FOSSIL) then
      if flags["EVENT_GOT_" .. row.itemId] then return "done" end
      return "excluded"
    end
  -- Game path [Gen 2]: a hidden story trainer may be gone permanently or only gated; preserve the adapters missable/missedAfter proof.
  elseif context.gen2 and category == 1 then
    if row.hideEvent and row.hideEvent ~= 65535 and context.flag(row.hideEvent) then
      return row.missable and (not row.missedAfter or context.flag(row.missedAfter)) and "unavailable" or "later"
    end
  end
  return row.status == "LATER" and "later" or "open"
end

-- Outcome and obligation are independent: a missed bonus is never a win.
-- Keep every source row (and its location), but count an either/or reward once.
local function prepare(source, category, context)
  local row = {}
  for key, value in pairs(source) do row[key] = value end
  row.state = M.rowState(row, category, context)
  row.done = row.state == "done"
  row.bonus = row.optional or row.missable or row.state == "unavailable" or false
  local id = row.mapId or ""
  if row.gift and not row.trade and not row.catchGoal and row.event ~= nil then
    row.choiceGroup = row.choiceGroup or (id .. ":receipt:" .. tostring(row.event))
  end
  -- Game path [Gen 1/2 vs Gen 3]: item alternatives share one receipt group; Gen 3 Pokemon rewards retain their adapter-proven choice rules.
  if row.alternative and row.event and (category == 2 or not context.gen3) then
    local a, b = tostring(row.event), tostring(row.alternative)
    if b < a then a, b = b, a end
    row.choiceGroup = id .. ":choice:" .. a .. ":" .. b
  end
  -- Game path [Gen 1]: missable SS Anne/Silph bonuses and the shared Mt Moon fossil choice must not become duplicate mandatory goals.
  if not context.gen2 and not context.gen3 then
    if not row.required and (id:match("^SS_ANNE_")
        or category == 1 and id:match("^SILPH_CO_")) then row.bonus = true end
    if category == 2 and id == "MT_MOON_B2F"
        and (row.itemId == "DOME_FOSSIL" or row.itemId == "HELIX_FOSSIL") then
      row.choiceGroup = id .. ":fossil"
    end
  end
  return row
end

local function count(section, category)
  local choices = {}
  for _, row in ipairs(section.rows) do
    local state = row.state
    if row.unknown or category == 1 and state == "untracked" and not row.bonus then section.unknown = section.unknown + 1 end
    if state == "untracked" or state == "repeatable" or state == "excluded" then
      section[state] = section[state] + 1
    elseif row.bonus then
      section.optional = section.optional + 1
      if state == "done" then section.bonusDone = section.bonusDone + 1 end
      if state == "unavailable" then section.bonusMissed = section.bonusMissed + 1 end
    else
      local key = row.choiceGroup
      if not key then
        section.total = section.total + 1
        if state == "done" then section.done = section.done + 1 end
      else
        if choices[key] == nil then section.total, choices[key] = section.total + 1, false end
        if state == "done" and not choices[key] then section.done, choices[key] = section.done + 1, true end
      end
    end
  end
end

local function section(rows)
  return { rows = rows or {}, done = 0, total = 0, unavailable = 0, optional = 0,
    bonusDone = 0, bonusMissed = 0, untracked = 0, excluded = 0, repeatable = 0, unknown = 0 }
end

-- Explorer uses the same obligations, either/or groups and bonuses as Stamps.
function M.section(rows, category, context)
  local result = section()
  for _, row in ipairs(rows or {}) do
    result.rows[#result.rows + 1] = prepare(row, category, context)
  end
  count(result, category)
  return result
end

local function tier(area)
  local fieldComplete = area.fieldDone == area.fieldTotal and area.unknown == 0
  area.tier = area.evidence and "bronze" or "none"
  if area.evidence and fieldComplete then
    local pokemon = area.sections[4]
    area.tier = pokemon.done == pokemon.total and "gold" or "silver"
  end
  area.complete = area.tier == "gold"
end

local function include(result, area)
  if area.total > 0 or #area.sections[1].rows > 0 or #area.sections[2].rows > 0
      or #area.sections[3].rows > 0 or area.evidence then
    result.areas[#result.areas + 1], result.byId[area.id] = area, area
    result.total = result.total + 1
    if area.tier ~= "none" then result.earned[#result.earned + 1] = area end
    if area.complete then result.done = result.done + 1
    elseif area.evidence and area.availableRemaining > 0 then result.goals[#result.goals + 1] = area end
  end
end

local function sortGoals(result)
  table.sort(result.goals, function(a, b)
    if a.remaining ~= b.remaining then return a.remaining < b.remaining end
    if a.current ~= b.current then return a.current == true end
    return a.id < b.id
  end)
  return result
end

function M.build(groups, read, context, checkpoint)
  local result = { areas = {}, allAreas = {}, byId = {}, goals = {}, earned = {}, total = 0, done = 0 }
  for _, group in ipairs(groups) do
    local area = context.reuse and context.reuse(group)
    if not area then
      area = { id = group.id, name = group.name, kind = group.kind,
        maps = group.maps, sections = {}, done = 0, total = 0,
        evidence = false, progressEvidence = false, unknown = 0 }
      for _, id in ipairs(group.maps) do
        area.current = area.current or id == context.mapId
        area.evidence = area.evidence or id == context.mapId
          or (context.visited or {})[id] == true
          or (context.save.visited or {})[id] == true
      end
      local sourceData = read(group.maps, checkpoint)
      local sections = sourceData.sections
      for category = 1, 3 do
        local section = section()
        for _, source in ipairs(sections[category].rows) do
          local row = prepare(source, category, context)
          area.progressEvidence = area.progressEvidence or row.state == "done"
          area.evidence = area.evidence or row.state == "done"
          section.rows[#section.rows + 1] = row
        end
        count(section, category)
        area.sections[category] = section
        area.unknown = area.unknown + section.unknown
        area.done, area.total = area.done + section.done, area.total + section.total
      end
      area.fieldTotal, area.fieldDone = area.total, area.done
      local pokemon = section()
      for _, source in ipairs(sourceData.pokemon or {}) do
        local row = prepare(source, 4, context)
        pokemon.rows[#pokemon.rows + 1] = row
        area.progressEvidence = area.progressEvidence or row.gift == true and row.state == "done"
        area.evidence = area.evidence or row.gift == true and row.state == "done"
      end
      count(pokemon, 4)
      area.unknown = area.unknown + pokemon.unknown
      area.sections[4] = pokemon
      area.total, area.done = area.total + pokemon.total, area.done + pokemon.done
      area.remaining = area.total - area.done
      area.availableRemaining = area.remaining - pokemon.unavailable
      local unknown = 0
      for i = 1, 3 do
        unknown = unknown + area.sections[i].untracked
        area.availableRemaining = area.availableRemaining - area.sections[i].unavailable
      end
      area.untracked = unknown
      tier(area)
    end
    result.allAreas[#result.allAreas + 1] = area
    include(result, area)
    if checkpoint then checkpoint() end
  end
  return sortGoals(result)
end

-- Location/visit changes do not change collected items, trainers or the Dex.
-- Keep those evaluated rows, including empty places first visited after loading.
function M.relocate(data, context)
  local result = { areas = {}, allAreas = data.allAreas, byId = {}, goals = {}, earned = {}, total = 0, done = 0 }
  for _, area in ipairs(data.allAreas) do
    area.current, area.evidence = false, area.progressEvidence == true
    for _, id in ipairs(area.maps) do
      area.current = area.current or id == context.mapId
      area.evidence = area.evidence or id == context.mapId
        or (context.visited or {})[id] == true or (context.save.visited or {})[id] == true
    end
    tier(area)
    include(result, area)
  end
  return sortGoals(result)
end

-- Keep the same completion rules for synchronous callers and the staged album.
-- Only a finished result escapes the coroutine; partial totals cannot earn stamps.
function M.begin(groups, read, context, clock)
  local deadline, checkpoints
  local function checkpoint()
    checkpoints = checkpoints + 1
    -- The time budget is primary. This cap only guards a stalled/coarse clock;
    -- cheap script checkpoints must not turn milliseconds into seconds of waiting.
    if checkpoints >= 256 or clock() >= deadline then coroutine.yield() end
  end
  local worker = coroutine.create(function()
    return M.build(groups, read, context, checkpoint)
  end)
  local result
  return { step = function(_, budget)
    if result then return result end
    deadline, checkpoints = clock() + budget, 0
    local ok, value = coroutine.resume(worker)
    if not ok then error(value, 0) end
    if coroutine.status(worker) == "dead" then result = value end
    return result
  end }
end

-- Present only disclosed tasks; keep the original tier earned from the complete
-- save data. Filtering must never accidentally award a gold stamp.
function M.presentArea(area, mode, visible)
  if mode == "spoiler" then return area end
  local out = {}
  for key, value in pairs(area) do out[key] = value end
  out.sections = {}
  for category, source in ipairs(area.sections) do
    local section = section()
    for _, row in ipairs(source.rows) do
      if visible(row, category) then
        section.rows[#section.rows + 1] = row
      end
    end
    count(section, category)
    out.sections[category] = section
  end
  if type(mode) == "table" and not mode.stamp_totals then
    out.tier, out.complete, out.remaining, out.availableRemaining = nil, false, nil, nil
    out.total, out.unknown, out.untracked = nil, nil, nil
  end
  return out
end

function M.visible(result, mode, policy)
  local areas, goals, earned = {}, {}, {}
  for _, area in ipairs(result.areas) do
    if (policy and policy.unvisited_maps or not policy and mode == "spoiler") or area.evidence then areas[#areas + 1] = area end
  end
  for _, area in ipairs(result.goals) do
    local open = area.sections[1].total - area.sections[1].done
      + area.sections[2].total - area.sections[2].done
      + area.sections[4].total - area.sections[4].done
      - area.sections[1].unavailable - area.sections[2].unavailable - (area.sections[4].unavailable or 0)
    -- Do not advertise an undiscovered hidden item's existence outside Spoiler.
    if mode == "spoiler" or mode ~= "vanilla" and open > 0 then goals[#goals + 1] = area end
  end
  for _, area in ipairs(result.earned) do earned[#earned + 1] = area end
  return areas, goals, earned
end

function M.visibleRows(area, category, mode)
  local rows = {}
  for _, row in ipairs(area.sections[category].rows) do
    if mode ~= "vanilla" or row.state == "done" then rows[#rows + 1] = row end
  end
  table.sort(rows, function(a, b)
    local order = { open = 1, later = 2, optional = 3, done = 4,
      unavailable = 5, untracked = 6, excluded = 7, repeatable = 8 }
    if order[a.state] ~= order[b.state] then return order[a.state] < order[b.state] end
    if category == 4 then
      if (a.order or 0) ~= (b.order or 0) then return (a.order or 0) < (b.order or 0) end
      return tostring(a.id or a.species) < tostring(b.id or b.species)
    end
    return (a.mapId .. ":" .. tostring(a.y) .. ":" .. tostring(a.x))
      < (b.mapId .. ":" .. tostring(b.y) .. ":" .. tostring(b.x))
  end)
  return rows
end

-- What the next stamp still needs, limited to what the discovery mode may show.
-- Bronze -> Silver needs the field tasks; Silver -> Gold needs the local Pokemon.
-- Vanilla presentation has no tier, so it has no next step either.
function M.nextStep(area, mode)
  if mode == "vanilla" or not area or area.evidence == false or area.complete or not area.sections then return nil end
  local current = area.tier
  if current ~= "bronze" and current ~= "silver" then return nil end
  local function open(category)
    local section = area.sections[category] or {}
    -- Missed obligations can no longer be done; they never count as "left".
    return math.max(0, (section.total or 0) - (section.done or 0) - (section.unavailable or 0))
  end
  local step = { target = current == "silver" and "gold" or "silver",
    trainers = 0, items = 0, hidden = 0, pokemon = 0, untracked = (area.unknown or 0) > 0 }
  if step.target == "silver" then
    step.trainers, step.items = open(1), open(2)
    -- Do not advertise an undiscovered hidden item's existence outside Spoiler.
    if mode == "spoiler" then step.hidden = open(3) end
  else step.pokemon = open(4) end
  step.count = step.trainers + step.items + step.hidden + step.pokemon
  return step
end

-- The few areas closest to their next stamp; the current area wins ties.
function M.nextGoals(goals, mode, limit)
  local out = {}
  for _, area in ipairs(goals or {}) do
    local step = M.nextStep(area, mode)
    if step and step.count > 0 then out[#out + 1] = { area = area, step = step } end
  end
  table.sort(out, function(a, b)
    if a.step.count ~= b.step.count then return a.step.count < b.step.count end
    if (a.area.current == true) ~= (b.area.current == true) then return a.area.current == true end
    return tostring(a.area.id) < tostring(b.area.id)
  end)
  for i = #out, (limit or 3) + 1, -1 do out[i] = nil end
  return out
end

return M
