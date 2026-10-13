return function(M, copy, giftPresentation, reaches, sortedKeys)
  local giftFlow = { ["return"] = true, ["end"] = true, goto_if = true, ["goto"] = true, call = true, call_if = true }
  local function pokemonPath(scripts, key, gift, receipt, options, checkpoint)
    local variable = type(receipt) == "table" and receipt.var
    local pending = { { key = key, index = 1,
      vars = variable and { [variable] = receipt.value - 1 } or {},
      flags = not variable and { [receipt] = 0 } or {} } }
    if variable and options.var then pending[1].vars[variable] = options.var(variable) end
    if not variable and options.live and options.flag then pending[1].flags[receipt] = options.flag(receipt) and 1 or 0 end
    local seen, count, found = {}, 0, false
    while #pending > 0 do
      local at = table.remove(pending)
      local parts = { tostring(at.key), at.index, at.given and 1 or 0, tostring(at.compare),
        at.stack and at.stack.signature or "" }
      for _, field in ipairs({ "vars", "flags" }) do
        for _, id in ipairs(sortedKeys(at[field])) do parts[#parts + 1] = field .. id .. "=" .. at[field][id] end
      end
      local signature = table.concat(parts, ":")
      local ancestor = at.path
      while ancestor do
        if ancestor.signature == signature then return nil end
        ancestor = ancestor.parent
      end
      if not seen[signature] then
        seen[signature], count = true, count + 1
        if count > 4096 then return nil end
        if checkpoint and count % 32 == 0 then checkpoint() end
        local list = scripts[at.key]
        if not list then return nil end
        local row = list[at.index]
        local function push(target, index, stack)
          pending[#pending + 1] = { key = target, index = index, stack = stack,
            vars = copy(at.vars), flags = copy(at.flags), given = at.given, compare = at.compare,
            path = { signature = signature, parent = at.path } }
        end
        local function terminal()
          local written = variable and (at.vars[variable] or 0) >= receipt.value or at.flags[receipt] == 1
          if written ~= (at.given == true) then return false end
          found = found or written
          return true
        end
        if not row then
          if not terminal() then return nil end
        else
          local op, a, b = row.op, row.var or row.flag or row[1], row.value or row[2]
          if row.opaque or op == "unknown" then return nil end
          local function value(id)
            if type(id) ~= "number" then return nil end
            if id < 0x4000 then return id end
            if at.vars[id] ~= nil then return at.vars[id] end
            if options.var and id >= 0x4010 and id < 0x8000 then return options.var(id) end
          end
          local again = false
          if row == gift then
            if options.live then
              local species = value(a)
              if options.species and species ~= options.species then return false end
              return true, { species = species, level = row[2], coinCost = options.choice and at.vars[0x4002] }
            end
            at.given, at.vars[0x800D] = options.result ~= 2, options.result
          elseif op == "givemon" or op == "giveegg" then return nil
          elseif op == "setvar" then at.vars[a] = b
          elseif op == "setorcopyvar" or op == "copyvar" then at.vars[a] = value(b)
          elseif op == "addvar" or op == "subvar" then
            at.vars[a] = at.vars[a] and b and (at.vars[a] + (op == "addvar" and b or -b)) % 65536
          elseif op == "getpartysize" then at.vars[0x800D] = options.party
          elseif op == "multichoice" and options.choice ~= nil then at.vars[0x800D] = options.choice
          elseif op == "checkcoins" and options.choice ~= nil then at.vars[a] = options.coins or 0
          elseif op == "checkplayergender" then at.vars[0x800D] = options.gender or 0
          elseif op == "checkmoney" then
            at.vars[0x800D] = (options.money or math.huge) >= (row[1] or 0) and 1 or 0
          elseif op == "compare_var_to_value" or op == "compare_var_to_var" then
            local lhs, rhs = value(a), op == "compare_var_to_var" and value(b) or b
            at.compare = lhs and rhs and (lhs < rhs and 0 or lhs == rhs and 1 or 2) or nil
          elseif op == "checkflag" then
            local v = at.flags[a]
            if v == nil and options.flag then v = options.flag(a) and 1 or 0 end
            if v == nil then
              -- Keep repeated checks of an unknown flag consistent on each path.
              at.flags[a], at.compare = 0, 0; push(at.key, at.index + 1, at.stack)
              at.flags[a], at.compare = 1, 1; push(at.key, at.index + 1, at.stack)
              again = true
            else at.compare = v end
          elseif op == "setflag" or op == "clearflag" then at.flags[a] = op == "setflag" and 1 or 0
          elseif op == "callstd" and (row.std or row[1]) == 5 then
            at.vars[0x800D] = 0; push(at.key, at.index + 1, at.stack)
            at.vars[0x800D] = 1; push(at.key, at.index + 1, at.stack)
            again = true
          elseif op == "special" or op == "specialvar" then
            local id = op == "specialvar" and row[2] or row.id or row[1]
            local dest = op == "specialvar" and row[1] or 0x800D
            -- Game path [FireRed/LeafGreen]: Quest Log playback/recording and friendship specials must be modeled without executing native side effects.
            if options.firered and id == 391 then at.vars[dest] = 0 -- not Quest Log playback
            elseif options.firered and id == 392 then -- stop recording; no result
            elseif options.firered and id == 230 then at.vars[dest] = options.friendship or 6
            -- Game path [RS/FRLG/Emerald]: audited post-gift naming/PC-text specials have different IDs and cannot write the reward receipt.
            elseif at.given and (options.rs and id == 158
                or options.firered and (id == 158 or id == 358 or id == 357
                or id == 394 or id == 436 or id == 371)
                or not options.firered and not options.rs and (id == 161 or id == 486 or id == 488 or id == 487)) then
              at.vars[dest] = nil -- naming/PC text/post-gift friendship; no receipt writes
            else return nil end
          elseif op == "trainerbattle" then
            -- Receiving a reward after an unfinished battle is not a ready NPC offer.
            if not terminal() then return nil end
            again = true
          elseif op == "removemoney" and at.given then
          elseif (op == "callstd" or op == "gotostd") and (row.std or row[1]) == 4 then
          elseif row.opaque or not (giftPresentation[op] or giftFlow[op]) then return nil end
          if not again then
            local branch, c = nil, at.compare
            if c ~= nil then
              local cond = row.cond or row[1]
              if cond == 0 then branch = c == 0 elseif cond == 1 then branch = c == 1
              elseif cond == 2 then branch = c == 2 elseif cond == 3 then branch = c <= 1
              elseif cond == 4 then branch = c >= 1 elseif cond == 5 then branch = c ~= 1 end
            end
            if options.live and (op == "goto_if" or op == "call_if") and branch == nil then return nil end
            if op == "return" then
              if at.stack then push(at.stack.key, at.stack.index, at.stack.parent)
              elseif not terminal() then return nil end
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
            elseif op == "end" or op == "gotostd" then
              if not terminal() then return nil end
            else push(at.key, at.index + 1, at.stack) end
          end
        end
      end
    end
    return found
  end
  function M:pokemonGifts(scripts, key, rows, vars, obj, checkpoint, mapId)
    local written, checked, cleared, commands, removed, out = {}, {}, {}, {}, false, {}
    -- Game path [Emerald]: Birch records the Johto-starter delivery in a permanent variable rather than a unique receipt flag.
    local starterVar = self.emerald and self.constants:var("VAR_DEX_UPGRADE_JOHTO_STARTER_STATE")
    local starterChecked, starterWritten = false, false
    for _, row in ipairs(rows) do
      if row.op == "compare_var_to_value" and (row.var or row[1]) == starterVar
          and (row.value or row[2]) == 6 then starterChecked = true end
      if row.op == "setvar" and (row.var or row[1]) == starterVar
          and (row.value or row[2]) == 6 then starterWritten = true end
      local flag = row.flag or row[1]
      if row.op == "setflag" then written[flag] = (written[flag] or 0) + 1
      elseif row.op == "checkflag" then checked[flag] = true
      elseif row.op == "clearflag" then cleared[flag] = true
      elseif row.op == "removeobject" and (row.localId or row[1]) == obj.localId
          and obj.flag and obj.flag >= 0x20 then removed = true
      elseif row.op == "givemon" or row.op == "giveegg" then commands[#commands + 1] = row end
    end
    local receipts = {}
    for _, receipt in ipairs(sortedKeys(written)) do
      if type(receipt) == "number" and receipt >= 0x20 and receipt ~= 65535 and not cleared[receipt]
          and not self.initiallyHidden[receipt] and (checked[receipt] or removed) then
        receipts[#receipts + 1] = receipt
      end
    end
    -- This native state is permanent after a successful Johto starter delivery.
    if starterChecked and starterWritten then receipts[#receipts + 1] = { var = starterVar, value = 6 } end
    -- Game path [Emerald]: Devon fossil revivals share one delivery flag; prove availability separately and keep species-based caught goals.
    local fossilFlag = self.emerald and mapId == "EM_RUSTBORO_CITY_DEVON_CORP_2F"
      and self.constants:flag("FLAG_RECEIVED_REVIVED_FOSSIL_MON")
    -- shortcut: rewards without a distinct receipt retain caught goals; temporary
    -- variables are never receipts. Add receipt types only when persistence is proven.
    local keys = { key }
    for _, row in ipairs(rows) do
      if row.target then keys[#keys + 1] = row.target end
      if row.eventScript then keys[#keys + 1] = row.eventScript end
    end
    for _, command in ipairs(commands) do
      local localKey
      -- A single receipt writer in this delivery block cannot belong to another
      -- reward. This also proves branches selected by a persistent native variable.
      for _, entry in ipairs(keys) do
        for _, row in ipairs(scripts[entry] or {}) do if row == command then localKey = entry; break end end
        if localKey then break end
      end
      local species = type(command[1]) == "number" and command[1] or nil
      if species and species >= 0x4000 then
        local choices = sortedKeys(vars[species]); species = #choices == 1 and choices[1] or nil
      end
      if species and self.adapter.data.pokemon[species] then
        local previous = #out
        local success = { party = 1, result = 0, firered = not self.hoenn, rs = self.rs }
        local failure = { party = 6, result = 2, firered = not self.hoenn, rs = self.rs }
        local pc = { party = 6, result = 1, firered = not self.hoenn, rs = self.rs }
        for _, receipt in ipairs(receipts) do
          local proofKey = key
          local proof = pokemonPath(scripts, key, command, receipt, success, checkpoint)
          if proof == nil and written[receipt] == 1 and localKey
              and reaches(scripts, key, command, receipt, 0, false, checkpoint) == true then
            for _, row in ipairs(scripts[localKey]) do
              if row.op == "setflag" and (row.flag or row[1]) == receipt then
                proofKey = localKey
                proof = pokemonPath(scripts, proofKey, command, receipt, success, checkpoint)
                break
              end
            end
          end
          if proof == true
              and pokemonPath(scripts, proofKey, command, receipt, failure, checkpoint) == false then
            local isEgg = command.op == "giveegg"
            local box = not isEgg and pokemonPath(scripts, proofKey, command, receipt, pc, checkpoint) == true
            local cost
            for _, r in ipairs(rows) do if r.op == "checkmoney" then cost = r[1] end end
            out[#out + 1] = { species = species, level = not isEgg and command[2] or nil,
              event = type(receipt) == "number" and receipt or nil,
              receiptVar = type(receipt) == "table" and receipt.var or nil,
              receiptValue = type(receipt) == "table" and receipt.value or nil,
              isEgg = isEgg or nil, toPC = box or nil, cost = cost,
              command = command, scriptKey = key }
            break
          end
        end
        -- Emerald only records a shared delivery flag; completion stays a caught goal.
        if #out == previous and fossilFlag and localKey and command.op == "givemon"
            and (species == self.adapter.Pokemon.speciesFromNational(345)
              or species == self.adapter.Pokemon.speciesFromNational(347))
            and reaches(scripts, key, command, fossilFlag, 0, false, checkpoint) == true
            and pokemonPath(scripts, localKey, command, fossilFlag, success, checkpoint) == true
            and pokemonPath(scripts, localKey, command, fossilFlag, failure, checkpoint) == false then
          out[#out + 1] = { species = species, level = command[2], catchGoal = true,
            deliveryFlag = fossilFlag, toPC = pokemonPath(scripts, localKey, command, fossilFlag, pc, checkpoint) == true,
            command = command, scriptKey = key }
        end
      end
    end
    -- Repeatable prizes and story-gated starters have no unique receipt. Read the
    -- actual offer branch, but retain a caught goal instead of a story-flag goal.
    -- Game path [FireRed/LeafGreen]: repeatable Game Corner prizes and Oak starters lack unique receipts; inspect offers but use caught goals.
    local corner = not self.emerald and mapId == "FR_CELADON_CITY_GAME_CORNER_PRIZE_ROOM"
    local starter = not self.emerald and mapId == "FR_OAKS_LAB" and obj.localId >= 5 and obj.localId <= 7
    if corner or starter then
      for choice = 0, corner and 4 or 0 do
        for _, command in ipairs(commands) do
          if command.op == "givemon" then
            local ok, offer = pokemonPath(scripts, key, command, 0, {
              live = true, party = 1, choice = corner and choice or nil, coins = 9999, firered = true,
              flag = function(id) return corner and id == 579 end,
              var = function(id) return starter and id == 0x4055 and 2 or 0 end }, checkpoint)
            if ok and offer and self.adapter.data.pokemon[offer.species]
                and type(offer.level) == "number" and offer.level >= 1 and offer.level <= 100
                and (not corner or type(offer.coinCost) == "number" and offer.coinCost > 0) then
              offer.catchGoal, offer.toPC, offer.choice = true, true, corner and choice or nil
              offer.initialStarter = starter or nil
              offer.command, offer.scriptKey = command, key
              out[#out + 1] = offer
              break
            end
          end
        end
      end
    end
    return out
  end
  return pokemonPath
end
