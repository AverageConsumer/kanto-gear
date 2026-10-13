local Habitats = {}

-- Planning can include teaching a TM/HM or retrieving a boxed partner.
-- Actual field-tool actions still require the move in the current party.
function Habitats.methods(save, items, surfBadge)
  local moves, inventory = {}, save.inventory or {}
  local function learn(party)
    for _, mon in ipairs(party or {}) do
      for _, move in ipairs(mon.moves or {}) do
        if move.id then moves[move.id] = true end
      end
    end
  end
  learn(save.party)
  for _, box in pairs(save.boxes or {}) do learn(box) end
  for id, count in pairs(inventory) do
    local item = items[id]
    local move = item and (item.teaches or item.machine and item.machine.move)
    if move and type(count) == "number" and count > 0 then moves[move] = true end
  end
  local reasons = {}
  for _, rod in ipairs({ "OLD", "GOOD", "SUPER" }) do
    if (tonumber(inventory[rod .. "_ROD"]) or 0) <= 0 then
      reasons[rod] = "NEED " .. rod .. " ROD"
    end
  end
  reasons.SURF = not moves.SURF and "NEED SURF" or not surfBadge and "NEED BADGE" or nil
  reasons.HEADBUTT = not moves.HEADBUTT and "NEED HEADBUTT" or nil
  reasons["RARE TREE"] = reasons.HEADBUTT
  reasons["ROCK SMASH"] = not moves.ROCK_SMASH and "NEED ROCK SMASH" or nil
  return reasons
end

function Habitats.plan(appearances, currentMap, period, visited, methods)
  local rows, matching, signature = {}, {}, {}
  local effort = { WALK = 1, CONTEST = 1, SURF = 2, OLD = 3, GOOD = 3,
    SUPER = 3, HEADBUTT = 4, ["RARE TREE"] = 5, ["ROCK SMASH"] = 5, ROAMING = 6 }
  for index, appearance in ipairs(appearances) do
    local here = appearance.mapId == currentMap
    local known = here or visited[appearance.mapId] == true
    local inTime = not appearance.time or appearance.time == period
    local reason = methods[appearance.method]
    local matches = known and inTime and not reason
    local rank = matches and (here and 1 or 2) or known and (reason and 4 or 3) or 5
    local status = not known and "NOT VISITED" or reason
      or not inTime and "ONLY %s" or here and "HERE NOW" or nil
    rows[#rows + 1] = { appearance = appearance, index = index, rank = rank,
      current = matches and here or false, matches = not not matches,
      status = status, period = appearance.time }
    if matches then matching[appearance.mapId] = true end
  end
  table.sort(rows, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    local aa, bb = a.appearance, b.appearance
    local ae, be = effort[aa.method] or 7, effort[bb.method] or 7
    if ae ~= be then return ae < be end
    local ac, bc = tonumber(aa.chance) or 0, tonumber(bb.chance) or 0
    if ac ~= bc then return ac > bc end
    if aa.mapId ~= bb.mapId then return tostring(aa.mapId) < tostring(bb.mapId) end
    if aa.method ~= bb.method then return tostring(aa.method) < tostring(bb.method) end
    if aa.time ~= bb.time then return tostring(aa.time) < tostring(bb.time) end
    return a.index < b.index
  end)
  local count = 0
  for _ in pairs(matching) do count = count + 1 end
  for _, row in ipairs(rows) do
    signature[#signature + 1] = row.index .. ":" .. row.rank .. ":" .. (row.status or "")
  end
  return { rows = rows, count = count, signature = table.concat(signature, "|") }
end

return Habitats
