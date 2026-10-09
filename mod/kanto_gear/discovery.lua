-- One disclosure boundary for every companion surface. Native game UI is unchanged.
local Discovery = {}

function Discovery.mode(value, localMap)
  if value == "spoiler" or value == "legacy" and localMap == "enhanced" then
    return "spoiler"
  end
  if value == "purist" or value == "vanilla" or value == "legacy" then
    return "vanilla"
  end
  return "enhanced"
end

function Discovery.map(mode, id, current, visited, save)
  if mode == "spoiler" then return true end
  if id == nil then return false end
  return id == current or type(visited) == "table" and visited[id] == true
    or save ~= nil and type(save.visited) == "table" and save.visited[id] == true
end

function Discovery.species(mode, species, seen, caught)
  return mode ~= "vanilla" or (seen or {})[species] == true
    or (caught or {})[species] == true
end

function Discovery.row(mode, row, category, knownMap)
  if mode == "spoiler" then return true end
  if row.done or row.state == "done" then return true end
  if not knownMap or row.available == false or row.excluded or row.missed
      or row.status == "LATER" or row.status == "MISSED" or row.status == "LOST"
      or row.state == "later" or row.state == "unavailable" then return false end
  if category == 3 then return row.scanned == true end
  return mode ~= "vanilla"
end

function Discovery.filter(rows, predicate)
  local out = {}
  for _, row in ipairs(rows or {}) do
    if predicate(row) then out[#out + 1] = row end
  end
  return out
end

return Discovery
