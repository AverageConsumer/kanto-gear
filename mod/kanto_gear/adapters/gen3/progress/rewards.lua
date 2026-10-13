return function(M, sortedKeys)
  -- Walk references once per source. All story branches belong in the catalogue;
  -- live flags decide completion, not whether an objective happens to be visible.
  -- Variable sets are only used to resolve finite gift-species alternatives.
  function M.scan(scripts, key, checkpoint)
    local rows, seen, vars, missing = {}, {}, {}, false
    local function walk(at)
      if not at or seen[at] then return end
      seen[at] = true
      local list = scripts[at]
      if not list then missing = true; return end
      for _, row in ipairs(list) do
        rows[#rows + 1] = row
        if checkpoint and #rows % 32 == 0 then checkpoint() end
        if row.op == "setvar" or row.op == "setorcopyvar" then
          local dest, value = row.var or row[1], row.value or row[2]
          if type(value) == "number" and value < 0x4000 then
            vars[dest] = vars[dest] or {}; vars[dest][value] = true
          end
        end
        if row.op == "call" or row.op == "call_if" or row.op == "goto" or row.op == "goto_if" then
          walk(row.target)
        end
        if row.eventScript then walk(row.eventScript) end
        if row.op == "unknown" or row.opaque then missing = true end
      end
    end
    walk(key)
    return rows, vars, missing
  end
  -- Prove a one-time reward from its control flow. A story flag elsewhere in an
  -- NPC's script is not evidence that this particular item was received.
  local function reaches(scripts, key, gift, flag, value, requireProof, checkpoint, liveFlag)
    local pending, seen, count = { { key = key, index = 1, value = value } }, {}, 0
    while #pending > 0 do
      local at = table.remove(pending)
      local signature = table.concat({ tostring(at.key), at.index, at.value,
        at.given and 1 or 0, at.stack and at.stack.signature or "" }, ":")
      if not seen[signature] then
        seen[signature], count = true, count + 1
        if count > 4096 then return nil end -- Cannot prove an opaque or unbounded graph.
        if checkpoint and count % 32 == 0 then checkpoint() end
        local list = scripts[at.key]
        if not list then return nil end
        local row = list[at.index]
        if row then
          if row == gift then
            if not requireProof then return true end
            at.given = true
          end
          if row.op == "setflag" and (row.flag or row[1]) == flag and at.given then return true end
          local valueNow = at.value
          if (row.op == "setflag" or row.op == "clearflag") and (row.flag or row[1]) == flag then
            valueNow = row.op == "setflag" and 1 or 0
          end
          local function push(target, index, stack)
            pending[#pending + 1] = { key = target, index = index, stack = stack,
              value = valueNow, given = at.given }
          end
          local op, branch = row.op, nil
          local previous = list[at.index - 1]
          if previous and previous.op == "checkflag" then
            local checked = previous.flag or previous[1]
            local result = checked == flag and valueNow or liveFlag and (liveFlag(checked) and 1 or 0)
            local cond = row.cond or row[1]
            if result ~= nil then
              if cond == 0 then branch = result == 0
              elseif cond == 1 then branch = result == 1
              elseif cond == 2 then branch = false
              elseif cond == 3 then branch = true
              elseif cond == 4 then branch = result ~= 0
              elseif cond == 5 then branch = result ~= 1 end
            end
          end
          if op == "return" then
            if at.stack then push(at.stack.key, at.stack.index, at.stack.parent) end
          elseif op == "goto" then push(row.target, 1, at.stack)
          elseif op == "goto_if" then
            if branch ~= false then push(row.target, 1, at.stack) end
            if branch ~= true then push(at.key, at.index + 1, at.stack) end
          elseif op == "call" or op == "call_if" then
            if op == "call_if" and branch ~= true then push(at.key, at.index + 1, at.stack) end
            if op == "call" or branch ~= false then
              local depth = at.stack and at.stack.depth + 1 or 1
              if depth > 20 then return nil end
              push(row.target, 1, { key = at.key, index = at.index + 1, parent = at.stack,
                depth = depth, signature = signature })
            end
          elseif op ~= "end" and op ~= "gotostd" then
            if row.opaque or op == "unknown" then return nil end
            push(at.key, at.index + 1, at.stack)
          end
        end
      end
    end
    return false
  end
  -- shortcut: literal items with a checked, subsequently written receipt flag;
  -- variable-based rewards need their own durable proof before joining this list.
  function M.gifts(scripts, key, rows, initiallyHidden, checkpoint)
    local checked, written, cleared, candidates, out = {}, {}, {}, {}, {}
    local keys, seen = { key }, {}
    for _, row in ipairs(rows) do
      local flag = row.flag or row[1]
      if row.op == "checkflag" then checked[flag] = true
      elseif row.op == "setflag" then written[flag] = true
      elseif row.op == "clearflag" then cleared[flag] = true end
      if row.target then keys[#keys + 1] = row.target end
      if row.eventScript then keys[#keys + 1] = row.eventScript end
    end
    for flag in pairs(checked) do
      if type(flag) == "number" and flag >= 0x20 and flag ~= 65535
          and written[flag] and not cleared[flag] and not initiallyHidden[flag] then
        candidates[#candidates + 1] = flag
      end
    end
    table.sort(candidates)
    if #candidates == 0 then return out end
    for _, scriptKey in ipairs(keys) do
      if not seen[scriptKey] then
        seen[scriptKey] = true
        local vars = {}
        for _, command in ipairs(scripts[scriptKey] or {}) do
          if command.op == "setvar" or command.op == "setorcopyvar" then
            local value = command.value or command[2]
            vars[command.var or command[1]] = type(value) == "number" and value < 0x4000 and value or vars[value]
          elseif command.op == "copyvar" then vars[command[1]] = vars[command[2]]
          elseif command.op == "call" or command.op == "call_if" or command.op == "special"
              or command.op == "specialvar" then vars = {} end
          local item = command.op == "additem" and command[1]
            or (command.op == "callstd" or command.op == "gotostd") and command.std == 0 and vars[0x8000]
          if type(item) == "number" and item > 0 and item < 0x4000 then
            for _, flag in ipairs(candidates) do
              if reaches(scripts, key, command, flag, 1, false, checkpoint) == false
                  and reaches(scripts, key, command, flag, 0, true, checkpoint) == true then
                out[#out + 1] = { itemId = item, event = flag }
                break
              end
            end
          end
        end
      end
    end
    return out
  end
  -- Identify the actual trade scene and its receipt, not the species-info helper.
  function M:trades(scripts, key, rows, vars, checkpoint)
    local ids, scenes, checked, written, cleared = sortedKeys(vars[0x8008]), {}, {}, {}, {}
    -- Game path [FireRed/LeafGreen vs Hoenn]: native in-game trade delivery has different special IDs; use the active edition constants.
    local sceneId = self.hoenn and self.constants:special("DoInGameTradeScene") or 254
    for _, row in ipairs(rows) do
      local flag = row.flag or row[1]
      if row.op == "checkflag" then checked[flag] = true
      elseif row.op == "setflag" then written[flag] = true
      elseif row.op == "clearflag" then cleared[flag] = true
      elseif row.op == "special" and (row.id or row[1]) == sceneId then scenes[#scenes + 1] = row end
    end
    if #scenes == 0 then return {} end
    -- Multiple IDs through one opaque helper cannot establish which receipt belongs to which offer.
    if #ids ~= 1 then return {}, true end
    local entry = require("src.core.game3.scripting.natives_trade").entry(ids[1])
    if not entry or not self.adapter.data.pokemon[entry.species]
        or not self.adapter.data.pokemon[entry.requestedSpecies] then return {}, true end
    local candidates = {}
    for flag in pairs(checked) do
      if type(flag) == "number" and flag >= 0x20 and flag ~= 65535 and written[flag]
          and not cleared[flag] and not self.initiallyHidden[flag] then candidates[#candidates + 1] = flag end
    end
    table.sort(candidates)
    for _, flag in ipairs(candidates) do
      for _, scene in ipairs(scenes) do
        if reaches(scripts, key, scene, flag, 1, false, checkpoint) == false
            and reaches(scripts, key, scene, flag, 0, true, checkpoint) == true then
          return { { tradeId = ids[1], species = entry.species, needsSpecies = entry.requestedSpecies,
            event = flag, command = scene, scriptKey = key } }
        end
      end
    end
    return {}, true
  end
  return reaches
end
