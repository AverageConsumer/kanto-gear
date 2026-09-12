-- Pickup flags also hide story-locked and recurring items. Only the live
-- save supplies progress; never remember a pickup across save loads here.
local M = {}

function M.new(data)
  local initial, written, cleared, guards, unsafeClear = {}, {}, {}, {}, {}
  for _, event in ipairs((data.gen2InitialEvents or {}).flags or {}) do
    initial[event] = true
  end
  local seen = {}
  local function scan(commands)
    if type(commands) ~= "table" or seen[commands] then return end
    seen[commands] = true
    local checked = {}
    for i, command in ipairs(commands) do
      local event = command.event
      if command.op == "checkevent" and event ~= nil
          and commands[i + 1] and commands[i + 1].op == "iftrue" then
        checked[event] = true
      elseif command.op == "setevent" and event ~= nil then
        written[event] = true
      elseif command.op == "clearevent" and event ~= nil then
        cleared[event] = true
        -- Power Plant's one-time unlock: check the manager-meeting flag,
        -- set it, then clear the Rocket and hidden-item flags. Read the
        -- actual IDs, not map names, translated item names or ROM offsets.
        local j = i - 1
        while j > 0 and commands[j].op == "clearevent" do j = j - 1 end
        local previous = commands[j]
        local gate = previous and previous.op == "setevent" and previous.event
        if gate and checked[gate] and gate ~= event then
          if guards[event] == nil then guards[event] = gate
          elseif guards[event] ~= gate then guards[event] = false end
        else
          unsafeClear[event] = true
        end
      end
    end
  end
  for _, commands in pairs(data.gen2Scripts or {}) do scan(commands) end
  -- Mods can supply inline scripts instead of generated script keys.
  for _, map in pairs(data.gen2Maps or {}) do
    if type(map) == "table" then
      for _, object in ipairs(map.objects or {}) do scan(object.scriptKey) end
      for _, callback in ipairs(map.callbacks or {}) do scan(callback.scriptKey) end
    end
  end
  for event, gate in pairs(guards) do
    -- A resettable/already-seeded gate cannot prove this unlock happened.
    if not gate or initial[gate] or cleared[gate] or written[event]
        or unsafeClear[event] then guards[event] = false end
  end
  return { state = function(_, world, event)
    local value
    if event ~= nil and world and world.getFlag then value = world:getFlag(event) end
    local available = value == false
    if event == nil or event == 65535 or type(event) == "number" and event < 8
        or value == nil then return false, available, "NOT TRACKED" end
    local gate = guards[event]
    if gate then
      local unlocked = world:getFlag(gate)
      if unlocked == nil then return false, false, "NOT TRACKED" end
      if not unlocked then return false, false, "LATER" end
    elseif initial[event] or written[event] or cleared[event] then
      -- Includes Moon Square: entering the map sets its flag even without
      -- a pickup. Availability is known, historical collection is not.
      return false, available, "NOT TRACKED"
    end
    return value == true, available, nil
  end }
end

return M
