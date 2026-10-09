-- Read the imported NPC scripts; collection always comes from the live save.
local M = {}
local calls = { scall = true, farscall = true, callstd = true }
local jumps = { sjump = true, farsjump = true, stopandsjump = true, jumpstd = true }
local branches = { iftrue = true, iffalse = true, ifequal = true,
  ifnotequal = true, ifgreater = true, ifless = true }
local endings = { ["end"] = true, endcallback = true, reloadend = true,
  jumptext = true, farjumptext = true, jumptextfaceplayer = true }
local gifts = { giveitem = true, verbosegiveitem = true }

local function list(data, key)
  return type(key) == "table" and key or (data.gen2Scripts or {})[key]
end

-- Follow real call/return edges: Gen 2's `end` returns from a scall, while
-- an iftrue/iffalse is a tail jump, not a call that resumes the next command.
local function reaches(data, key, gift, event, value, proof, checkpoint)
  local pending, seen, count = { { key = key, index = 1, value = value } }, {}, 0
  while #pending > 0 do
    local at = table.remove(pending)
    local signature = table.concat({ tostring(at.key), at.index, at.value,
      at.given and 1 or 0, at.stack and at.stack.signature or "" }, ":")
    if not seen[signature] then
      seen[signature], count = true, count + 1
      if count > 4096 then return nil end
      if checkpoint and count % 32 == 0 then checkpoint() end
      local commands = list(data, at.key)
      if type(commands) ~= "table" then return nil end
      local row = commands[at.index]
      if row == gift then
        if not proof then return true end
        at.given = true
      end
      if row and row.op == "setevent" and row.event == event and at.given then return true end
      local valueNow = at.value
      if row and row.event == event and (row.op == "setevent" or row.op == "clearevent") then
        valueNow = row.op == "setevent" and 1 or 0
      end
      local function push(target, index, stack)
        pending[#pending + 1] = { key = target, index = index, stack = stack,
          value = valueNow, given = at.given }
      end
      local op = row and row.op
      if not row or endings[op] then
        if at.stack then push(at.stack.key, at.stack.index, at.stack.parent) end
      elseif op == "endall" then -- Ends the whole script rather than a subroutine.
      elseif jumps[op] then push(row.script, 1, at.stack)
      elseif calls[op] then
        local depth = at.stack and at.stack.depth + 1 or 1
        if depth > 20 then return nil end
        push(row.script, 1, { key = at.key, index = at.index + 1,
          parent = at.stack, depth = depth, signature = signature })
      elseif branches[op] then
        local take, previous = nil, commands[at.index - 1]
        if previous and previous.op == "checkevent" and previous.event == event then
          if op == "iftrue" then take = valueNow ~= 0
          elseif op == "iffalse" then take = valueNow == 0
          elseif op == "ifequal" then take = valueNow == row.value
          elseif op == "ifnotequal" then take = valueNow ~= row.value
          elseif op == "ifgreater" then take = valueNow > row.value
          elseif op == "ifless" then take = valueNow < row.value end
        end
        if take ~= false then push(row.script, 1, at.stack) end
        if take ~= true then push(at.key, at.index + 1, at.stack) end
      elseif op == nil or op == "unknown" or op == "truncated" or row.opaque
          or op == "memcall" or op == "memjump" or op == "sdefer" then
        return nil -- A dynamic or mod-defined script cannot prove this receipt.
      else push(at.key, at.index + 1, at.stack) end
    end
  end
  return false
end

function M.new(data, checkpoint)
  local initial, cleared, seen = {}, {}, {}
  for _, event in ipairs((data.gen2InitialEvents or {}).flags or {}) do initial[event] = true end
  local function scan(commands)
    if type(commands) ~= "table" or seen[commands] then return end
    seen[commands] = true
    for i, row in ipairs(commands) do
      if row.op == "clearevent" and row.event ~= nil then cleared[row.event] = true end
      if checkpoint and i % 32 == 0 then checkpoint() end
    end
  end
  for _, commands in pairs(data.gen2Scripts or {}) do scan(commands) end
  for _, map in pairs(data.gen2Maps or {}) do
    for _, obj in ipairs(map.objects or {}) do scan(obj.scriptKey) end
    for _, callback in ipairs(map.callbacks or {}) do scan(callback.scriptKey) end
  end
  local cache = {}
  return { catalog = function(_, key, yield)
    if key == nil then return {} end
    if cache[key] then return cache[key] end
    local commands, visited, checked, written, reset, rewards = {}, {}, {}, {}, {}, {}
    local function walk(at)
      local rows = list(data, at)
      if type(rows) ~= "table" or visited[rows] then return end
      visited[rows] = true
      for i, row in ipairs(rows) do
        commands[#commands + 1] = row
        if row.event ~= nil then
          if row.op == "checkevent" then checked[row.event] = true
          elseif row.op == "setevent" then written[row.event] = true
          elseif row.op == "clearevent" then reset[row.event] = true end
        end
        if (calls[row.op] or jumps[row.op] or branches[row.op]) and row.script then walk(row.script) end
        if yield and i % 32 == 0 then yield() end
      end
    end
    walk(key)
    local candidates = {}
    for event in pairs(checked) do
      if type(event) == "number" and event >= 8 and event ~= 65535
          and written[event] and not reset[event] and not initial[event] then
        candidates[#candidates + 1] = event
      end
    end
    table.sort(candidates)
    local added = {}
    -- shortcut: only literal items with a provable receipt event; memory-based
    -- prizes and gifts using engine flags need a separate durable proof.
    for _, command in ipairs(commands) do
      local item = gifts[command.op] and (command.item or (command.args or {})[1])
      if type(item) == "number" and item > 0 and item < 255 then
        for _, event in ipairs(candidates) do
          local id = event .. ":" .. item
          if not added[id] and reaches(data, key, command, event, 1, false, yield) == false
              and reaches(data, key, command, event, 0, true, yield) == true then
            rewards[#rewards + 1] = { itemId = item, event = event, repeatable = cleared[event] or nil }
            added[id] = true
            break
          end
        end
      end
    end
    cache[key] = rewards
    return rewards
  end }
end

return M
