-- Read-only adventure progress. Never persist earned stamps separately from
-- the save: loading an older save must also restore its actual progress.
local M = {}

function M.groups(maps, locations)
  local byKey, out = {}, {}
  for id, map in pairs(maps or {}) do
    local place = locations[id] or {}
    local name = tostring(place.name or place.label or id):gsub("<LF>", " "):gsub("\n", " ")
    local xy = place.coords or place
    local key = name .. ":" .. tostring(xy.x or xy.col or id)
      .. ":" .. tostring(xy.y or xy.row or id)
    local group = byKey[key]
    if not group then
      group = { id = id, name = name, maps = {}, kind = "route" }
      byKey[key], out[#out + 1] = group, group
    end
    group.maps[#group.maps + 1] = id
    if id < group.id then group.id = id end
    local tileset = tostring(map.tileset or "")
    if tileset:find("FOREST") or id:find("FOREST") then group.kind = "forest"
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
  if row.optional then return "optional" end
  if row.missed or row.status == "MISSED" then return "unavailable" end
  if row.status == "LOST" then return "unavailable" end
  -- A temporary or missing flag is not durable proof, even while it is set.
  if context.gen2 and (row.event == nil or row.event == 65535
      or type(row.event) == "number" and row.event < 8) then return "untracked" end
  if row.done then return "done" end
  local id, flags = row.mapId or "", context.save.flags or {}
  if not context.gen2 then
    if id:match("^SS_ANNE_") and flags.EVENT_SS_ANNE_LEFT then return "unavailable" end
    -- Taking one fossil permanently removes the alternative, not a second find.
    if category == 2 and id == "MT_MOON_B2F"
        and (row.itemId == "DOME_FOSSIL" or row.itemId == "HELIX_FOSSIL")
        and (flags.EVENT_GOT_DOME_FOSSIL or flags.EVENT_GOT_HELIX_FOSSIL) then
      if flags["EVENT_GOT_" .. row.itemId] then return "done" end
      return "excluded"
    end
  elseif category == 1 then
    if row.hideEvent and row.hideEvent ~= 65535 and context.flag(row.hideEvent) then
      return "unavailable"
    end
  end
  return row.status == "LATER" and "later" or "open"
end

function M.build(groups, read, context)
  local result = { areas = {}, byId = {}, goals = {}, earned = {}, total = 0, done = 0 }
  for _, group in ipairs(groups) do
    local area = { id = group.id, name = group.name, kind = group.kind,
      maps = group.maps, sections = {}, done = 0, total = 0, evidence = false }
    for _, id in ipairs(group.maps) do
      area.current = area.current or id == context.mapId
      area.evidence = area.evidence or id == context.mapId
        or (context.visited or {})[id] == true
        or (context.save.visited or {})[id] == true
    end
    local sourceData = read(group.maps)
    local sections = sourceData.sections
    for category = 1, 3 do
      local section = { rows = {}, done = 0, total = 0, unavailable = 0,
        optional = 0, untracked = 0, excluded = 0 }
      for _, source in ipairs(sections[category].rows) do
        local row = {}
        for key, value in pairs(source) do row[key] = value end
        row.state = M.rowState(row, category, context)
        area.evidence = area.evidence or row.state == "done"
        if row.state == "excluded" or row.state == "optional" or row.state == "untracked" then
          section[row.state] = section[row.state] + 1
        else
          section.total = section.total + 1
          if row.state == "done" then section.done = section.done + 1 end
          if row.state == "unavailable" then section.unavailable = section.unavailable + 1 end
        end
        section.rows[#section.rows + 1] = row
      end
      area.sections[category] = section
      area.done, area.total = area.done + section.done, area.total + section.total
    end
    area.fieldTotal, area.fieldDone = area.total, area.done
    local pokemon = { rows = {}, total = 0, done = 0 }
    for _, source in ipairs(sourceData.pokemon or {}) do
      local row = {}
      for key, value in pairs(source) do row[key] = value end
      row.state = row.done and "done" or "open"
      pokemon.rows[#pokemon.rows + 1] = row
      pokemon.total = pokemon.total + 1
      if row.done then pokemon.done = pokemon.done + 1 end
    end
    area.sections[4] = pokemon
    area.total, area.done = area.total + pokemon.total, area.done + pokemon.done
    area.remaining = area.total - area.done
    area.availableRemaining = area.remaining
    local unknown = 0
    for i = 1, 3 do
      unknown = unknown + area.sections[i].untracked
      area.availableRemaining = area.availableRemaining - area.sections[i].unavailable
    end
    local fieldComplete = area.fieldDone == area.fieldTotal and unknown == 0
    area.untracked = unknown
    area.tier = area.evidence and "bronze" or "none"
    if area.evidence and fieldComplete and area.total > 0 then
      area.tier = pokemon.done == pokemon.total and "gold" or "silver"
    end
    area.complete = area.tier == "gold"
    if area.total > 0 or #area.sections[1].rows > 0 or #area.sections[2].rows > 0
        or #area.sections[3].rows > 0 or area.evidence then
      result.areas[#result.areas + 1], result.byId[area.id] = area, area
      result.total = result.total + 1
      if area.tier ~= "none" then
        result.earned[#result.earned + 1] = area
      end
      if area.complete then
        result.done = result.done + 1
      elseif area.evidence and area.availableRemaining > 0 then
        result.goals[#result.goals + 1] = area
      end
    end
  end
  table.sort(result.goals, function(a, b)
    if a.remaining ~= b.remaining then return a.remaining < b.remaining end
    if a.current ~= b.current then return a.current == true end
    return a.id < b.id
  end)
  return result
end

function M.visible(result, mode)
  local areas, goals, earned = {}, {}, {}
  for _, area in ipairs(result.areas) do
    if mode == "spoiler" or area.evidence then areas[#areas + 1] = area end
  end
  for _, area in ipairs(result.goals) do
    local open = area.sections[1].total - area.sections[1].done
      + area.sections[2].total - area.sections[2].done
      + area.sections[4].total - area.sections[4].done
      - area.sections[1].unavailable - area.sections[2].unavailable
    -- Do not advertise an undiscovered hidden item's existence outside Spoiler.
    if mode == "spoiler" or mode ~= "vanilla" and open > 0 then goals[#goals + 1] = area end
  end
  for _, area in ipairs(result.earned) do earned[#earned + 1] = area end
  return areas, goals, earned
end

function M.visibleRows(area, category, mode)
  local rows = {}
  for _, row in ipairs(area.sections[category].rows) do
    if mode == "spoiler" or row.state == "done" then rows[#rows + 1] = row end
  end
  table.sort(rows, function(a, b)
    local order = { open = 1, later = 2, optional = 3, done = 4,
      unavailable = 5, untracked = 6, excluded = 7 }
    if order[a.state] ~= order[b.state] then return order[a.state] < order[b.state] end
    if category == 4 then return a.order < b.order end
    return (a.mapId .. ":" .. tostring(a.y) .. ":" .. tostring(a.x))
      < (b.mapId .. ":" .. tostring(b.y) .. ":" .. tostring(b.x))
  end)
  return rows
end

return M
