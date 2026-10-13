-- Read the imported NPC scripts; collection always comes from the live save.
local M = {}
local calls = { scall = true, farscall = true, callstd = true }
local jumps = { sjump = true, farsjump = true, stopandsjump = true, jumpstd = true }
local branches = { iftrue = true, iffalse = true, ifequal = true,
  ifnotequal = true, ifgreater = true, ifless = true }
local endings = { ["end"] = true, endcallback = true, reloadend = true,
  jumptext = true, farjumptext = true, jumptextfaceplayer = true }
local gifts = { giveitem = true, verbosegiveitem = true }
-- Game path [Gen 2 / Crystal]: Shuckle is a native loan special; Crystal adds Odd Egg, whose species is intentionally undisclosed.
local specialGifts = {
  GiveShuckle = { species = 213, level = 15, loan = true, result = 1 },
  GiveOddEgg = { isEgg = true, level = 5 },
}

local function specialGift(data, row)
  local order = data.gen2Constants and data.gen2Constants.specialOrder
  return row and row.op == "special" and order and specialGifts[order[(row.id or -1) + 1]] or nil
end

local function list(data, key)
  return type(key) == "table" and key or (data.gen2Scripts or {})[key]
end

local function sameGift(row, gift)
  -- Native NPCs duplicate a reward in the first visit and later retry branches.
  if row == gift then return true end
  if not row or row.op ~= gift.op or (gift.op ~= "givepoke" and gift.op ~= "giveegg") then return false end
  return (row.species or (row.args or {})[1]) == (gift.species or (gift.args or {})[1])
    and (row.level or (row.args or {})[2]) == (gift.level or (gift.args or {})[2])
end

-- Follow real call/return edges: Gen 2's `end` returns from a scall, while
-- an iftrue/iffalse is a tail jump, not a call that resumes the next command.
local function reaches(data, key, gift, event, value, proof, checkpoint, partyCount, failed, save, world)
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
      if sameGift(row, gift) then
        if not proof then return true end
        at.given = true
      end
      if row and row.op == "setevent" and row.event == event and proof then
        if not at.given then return nil end
        return true
      end
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
      elseif op == "endall" or save and op == "startbattle" then
      elseif jumps[op] then push(row.script, 1, at.stack)
      elseif calls[op] then
        local depth = at.stack and at.stack.depth + 1 or 1
        if depth > 20 then return nil end
        push(row.script, 1, { key = at.key, index = at.index + 1,
          parent = at.stack, depth = depth, signature = signature })
      elseif branches[op] then
        local take, previous = nil, commands[at.index - 1]
        local variable
        if previous and previous.op == "checkevent" then
          if previous.event == event then variable = valueNow
          elseif world and world.getFlag then
            local set = world:getFlag(previous.event)
            if set ~= nil then variable = set and 1 or 0 end
            if set == nil and save then return nil end
          elseif save then return nil
          end
        elseif previous and previous.op == "readvar" and (previous.var or (previous.args or {})[1]) == 1 then
          variable = partyCount
        elseif sameGift(previous, gift) and gift.op == "giveegg" and failed ~= nil then
          variable = failed and 0 or 2
        elseif sameGift(previous, gift) and specialGift(data, gift) and failed ~= nil then
          local reward = specialGift(data, gift)
          if reward.result then variable = failed and 0 or reward.result end
        -- Game path [Gold/Silver/Crystal]: native checkver returns 1 only for Silver; preserve the edition-dependent prize branch.
        elseif previous and previous.op == "checkver" then
          variable = require("src.core.GameVersion").get() == "silver" and 1 or 0
        elseif save and previous and previous.op == "checkitem" then
          local id = previous.item or (previous.args or {})[1]
          for name, def in pairs(data.items or {}) do
            if type(def) == "table" and def.index == id then variable = ((save.inventory or {})[name] or 0) > 0 and 1 or 0; break end
          end
          if variable == nil then return nil end
        elseif save and previous and previous.op == "checkcoins" then
          local args = previous.args or {}
          local price, have = (args[1] or 0) + 256 * (args[2] or 0), (save.player or {}).coins or 0
          variable = have < price and 2 or have == price and 1 or 0
        elseif save and previous and previous.op == "checkpoke" then
          variable = 0
          local species = previous.species or (previous.args or {})[1]
          for _, mon in ipairs(save.party or {}) do
            local def = data.pokemon and data.pokemon[mon.species]
            if not mon.isEgg and def and def.index == species then variable = 1; break end
          end
        elseif save and previous and previous.op == "yesorno" then variable = 1 end
        if variable ~= nil then
          if op == "iftrue" then take = variable ~= 0
          elseif op == "iffalse" then take = variable == 0
          elseif op == "ifequal" then take = variable == row.value
          elseif op == "ifnotequal" then take = variable ~= row.value
          elseif op == "ifgreater" then take = variable > row.value
          elseif op == "ifless" then take = variable < row.value end
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
  return { catalog = function(_, key, yield, mapId)
    if key == nil then return {} end
    local cacheKey = type(key) == "string" and tostring(mapId) .. ":" .. key or key
    if cache[cacheKey] then return cache[cacheKey] end
    -- Game path [Gen 2]: Goldenrod/Celadon Pokemon prizes are repeatable; matched coin checks/debits prove an offer, not a unique receipt.
    local casino = mapId == "GOLDENROD_GAME_CORNER" or mapId == "CELADON_GAME_CORNER_PRIZE_ROOM"
    local commands, visited, checked, written, reset, rewards, prices = {}, {}, {}, {}, {}, {}, {}
    local function walk(at)
      local rows = list(data, at)
      if type(rows) ~= "table" or visited[rows] then return end
      visited[rows] = true
      for i, row in ipairs(rows) do
        commands[#commands + 1] = row
        if casino and row.op == "givepoke" then
          local price
          for n = 1, i - 1 do
            if rows[n].op == "checkcoins" then
              local args = rows[n].args or {}
              price = (args[1] or 0) + 256 * (args[2] or 0)
            end
          end
          for n = i + 1, #rows do
            local args = rows[n].args or {}
            if rows[n].op == "takecoins" and price == (args[1] or 0) + 256 * (args[2] or 0) then prices[row] = price; break end
          end
        end
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
    for event in pairs(written) do
      if type(event) == "number" and event >= 8 and event ~= 65535
          and not reset[event] and not initial[event] then
        candidates[#candidates + 1] = event
      end
    end
    table.sort(candidates)
    local added = {}
    -- shortcut: other opaque specials still need a proven acquisition contract.
    for _, command in ipairs(commands) do
      local item = gifts[command.op] and (command.item or (command.args or {})[1])
      local special = specialGift(data, command)
      local pokemon = command.op == "givepoke" or command.op == "giveegg" or special ~= nil
      local species, level
      if special then species, level = special.species, special.level
      elseif pokemon then species, level = command.species or (command.args or {})[1], command.level or (command.args or {})[2] end
      local egg = command.op == "giveegg" or special and special.isEgg
      local literal = pokemon and species or item
      if (special and special.isEgg or type(literal) == "number" and literal % 1 == 0 and literal > 0 and literal < 255)
          and (not pokemon or type(level) == "number" and level % 1 == 0 and level >= 1 and level <= 100) then
        for _, event in ipairs(candidates) do
          local id = event .. ":" .. (pokemon and "pokemon:" or "item:") .. tostring(literal or "egg")
          if not added[id] and (pokemon or checked[event])
              and (pokemon or reaches(data, key, command, event, 1, false, yield) == false)
              and reaches(data, key, command, event, 0, true, yield, pokemon and 0 or nil, false) == true
              and (not pokemon or reaches(data, key, command, event, 0, true, yield, 6, true) == false) then
            rewards[#rewards + 1] = { itemId = item or nil, speciesIndex = species or nil, level = level or nil,
              isEgg = egg or nil, loan = special and special.loan, event = event, repeatable = cleared[event] or nil,
              command = pokemon and command or nil, key = pokemon and key or nil }
            added[id] = true
            break
          end
        end
        local price = prices[command]
        local id = "caught:" .. tostring(species)
        if casino and command.op == "givepoke" and price and price > 0 and not added[id]
            and reaches(data, key, command, nil, 0, false, yield, 0, false,
              { party = {}, inventory = { COIN_CASE = 1 }, player = { coins = 9999 } }) == true then
          rewards[#rewards + 1] = { speciesIndex = species, level = level, coinCost = price,
            catchGoal = true, command = command, key = key }
          added[id] = true
        end
      elseif command.op == "trade" then
        local id = command.trade or (command.args or {})[1]
        if type(id) == "number" and id % 1 == 0 and id >= 0 and id < 255 and not added["trade:" .. id]
            and reaches(data, key, command, nil, 0, false, yield) == true then
          rewards[#rewards + 1] = { tradeId = id, command = command, key = key }
          added["trade:" .. id] = true
        end
      end
    end
    cache[cacheKey] = rewards
    return rewards
  end, available = function(_, gift, save, world, yield)
    if (gift.speciesIndex or gift.isEgg) and #(save.party or {}) >= 6 then return false end
    return reaches(data, gift.key, gift.command, gift.event, 0, false, yield,
      #(save.party or {}), false, save, world) == true
  end }
end

return M
