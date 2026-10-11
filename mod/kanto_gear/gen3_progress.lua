-- Native Gen 3 route objectives. Read the imported event graph, never execute
-- scripts or infer victory/collection from an NPC simply being hidden.
local M = {}
M.__index = M

local function copy(t)
  local out = {}
  for k, v in pairs(t or {}) do out[k] = v end
  return out
end

local function sortedKeys(t)
  local out = {}
  for k in pairs(t or {}) do out[#out + 1] = k end
  table.sort(out)
  return out
end

function M.new(adapter)
  local renewable, initiallyHidden = {}, {}
  local emerald = adapter.profile.id == "emerald"
  local hoenn = adapter.hoenn
  if not hoenn then
    for _, flag in ipairs(adapter.Flags.NEW_GAME_HIDE_FLAGS or {}) do initiallyHidden[flag] = true end
  end
  for _, zone in ipairs(not hoenn and require("src.core.game3.renewable_hidden_items").ZONES or {}) do
    for _, tier in ipairs({ "rare", "uncommon", "common" }) do
      for _, flag in ipairs(zone[tier]) do renewable[flag] = true end
    end
  end
  return setmetatable({ adapter = adapter, maps = {}, renewable = renewable, initiallyHidden = initiallyHidden,
    emerald = emerald, hoenn = hoenn, rs = adapter.rs,
    constants = hoenn and require("src.core.game3.constants").of(adapter.profile.id),
    Trainers = require("src.core.game3.scripting.trainers"), builds = 0 }, M)
end

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

-- A read-only path check for native Pokemon rewards. VAR_RESULT matters: a full
-- party may send a gift to the PC, while a failed delivery must never earn a stamp.
local giftPresentation = {}
for op in ("lock lockall release releaseall faceplayer showmonpic hidemonpic applymovement waitmovement "
    .. "removeobject showmoneybox hidemoneybox updatemoneybox showcoinsbox hidecoinsbox updatecoinsbox playfanfare waitfanfare message "
    .. "waitmessage loadword fadescreen waitstate textcolor bufferspeciesname bufferboxname"):gmatch("%S+") do
  giftPresentation[op] = true
end
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
          if options.firered and id == 391 then at.vars[dest] = 0 -- not Quest Log playback
          elseif options.firered and id == 392 then -- stop recording; no result
          elseif options.firered and id == 230 then at.vars[dest] = options.friendship or 6
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

function M:bundle()
  -- The field engine owns/loads the bundle. Boot and missing extraction must
  -- yield unknown objectives, not a permanently cached empty catalogue.
  local bundle = self.adapter.Space.bundle
  if bundle ~= self.source then
    self.maps, self.source = {}, bundle
    self.unusedHideout = nil
    if self.hoenn and bundle then
      self.initiallyHidden = {}
      for _, row in ipairs(M.scan(bundle.scripts, "EventScript_ResetAllMapFlags")) do
        if row.op == "setflag" then self.initiallyHidden[row.flag or row[1]] = true end
      end
    end
    if self.rs and bundle then
      -- RS ships both Lilycove hideouts. Terrain/load scripts wall off the
      -- unused entrance. Require that native proof so a custom map which
      -- opens it can still supply objectives instead of being filtered by ID.
      local prefix = self.adapter.profile.map.enginePrefix
      local unused = prefix .. (self.adapter.profile.id == "ruby" and "AQUA" or "MAGMA") .. "_HIDEOUT_"
      local city = self.adapter.data.maps[prefix .. "LILYCOVE_CITY"]
      local event = bundle.events[prefix .. "LILYCOVE_CITY"]
      local key = event and event.mapScripts and event.mapScripts.onLoad
      for _, warp in ipairs(city and city.warps or {}) do
        if warp.destMap == unused .. "1F" then
          local layout = city.midLayout
          local blocked = layout and layout:collAt(warp.x, warp.y) ~= 0 or false
          local opened = false
          for _, row in ipairs(bundle.scripts[key] or {}) do
            if row.op ~= "setmetatile" then break end
            if row[1] == warp.x and row[2] == warp.y and row[4] == 1 then blocked = true end
          end
          for _, row in ipairs(M.scan(bundle.scripts, key)) do
            if row.op == "setmetatile" and row[1] == warp.x and row[2] == warp.y and row[4] == 0 then opened = true end
          end
          if blocked and not opened then self.unusedHideout = unused end
        end
      end
    end
  end
  return bundle
end

function M:catalog(mapId, checkpoint)
  local bundle = self:bundle()
  if self.maps[mapId] then return self.maps[mapId] end
  if self.unusedHideout and mapId:sub(1, #self.unusedHideout) == self.unusedHideout then
    self.maps[mapId] = { {}, {}, {}, {} }
    return self.maps[mapId]
  end
  local event = bundle and bundle.events and bundle.events[mapId]
  if not event or not bundle.scripts then
    return { { { label = "NOT TRACKED", mapId = mapId, untracked = true } }, {}, {}, {} }
  end
  local out, trainers, pokemon, gifts = { {}, {}, {}, {} }, {}, {}, {}
  local function base(obj)
    return { mapId = mapId, x = obj.x, y = obj.y, index = obj.localId,
      id = mapId .. "_obj_" .. tostring(obj.localId), spriteId = obj.sprite,
      graphicsId = obj.graphicsId or obj.graphics, graphicsVar = obj.graphicsVar,
      facing = obj.facing, hideEvent = obj.flag }
  end
  local function mon(species, obj, giftCommand, missable)
    if mapId == "FR_POKEMON_TOWER_6F" and species == 105 then return end -- uncatchable ghost
    if not self.adapter.data.pokemon[species] then
      out[1][#out[1] + 1] = { label = "POKEMON", mapId = mapId, untracked = true }
      return
    end
    if pokemon[species] then
      if not giftCommand then pokemon[species].giftCommand = nil end
      return
    end
    local row = base(obj)
    row.species, row.giftCommand = species, giftCommand
    row.missable = missable or nil
    pokemon[species], out[4][#out[4] + 1] = row, row
  end
  local function scan(obj, objectSource)
    if checkpoint then checkpoint() end
    local rows, vars, missing = M.scan(bundle.scripts, obj.scriptKey, checkpoint)
    local hasTrainer, hasMon, hasItem = false, false, false
    local proven = {}
    for _, offer in ipairs(objectSource and self:pokemonGifts(bundle.scripts, obj.scriptKey, rows, vars, obj, checkpoint, mapId) or {}) do
      local receipt = offer.catchGoal and "caught" or offer.event or ("var:" .. offer.receiptVar .. ":" .. offer.receiptValue)
      local key = tostring(receipt) .. ":pokemon:" .. offer.species
      proven[offer.command] = true
      if not gifts[key] then
        local row = base(obj)
        for k, v in pairs(offer) do row[k] = v end
        row.id, row.kind, row.gift = mapId .. "_gift_" .. key, "pokemon", true
        if mapId == "FR_CINNABAR_ISLAND_POKEMON_LAB_EXPERIMENT_ROOM" then
          if row.species == 138 and row.event == 749 then row.alternative, row.choiceEvent = 626, 627
          elseif row.species == 140 and row.event == 748 then row.alternative, row.choiceEvent = 627, 626 end
        end
        gifts[key], out[4][#out[4] + 1] = row, row
      end
    end
    if objectSource then
      local offers, unknown = self:trades(bundle.scripts, obj.scriptKey, rows, vars, checkpoint)
      missing = missing or unknown
      for _, offer in ipairs(offers) do
        local row = base(obj)
        for k, v in pairs(offer) do row[k] = v end
        row.id = mapId .. "_trade_" .. offer.tradeId
        row.kind, row.gift, row.trade = "pokemon", true, true
        out[4][#out[4] + 1] = row
      end
    end
    for _, gift in ipairs(objectSource
        and M.gifts(bundle.scripts, obj.scriptKey, rows, self.initiallyHidden, checkpoint) or {}) do
      local key = tostring(gift.event) .. ":" .. gift.itemId
      if not gifts[key] and self.adapter.data.items[gift.itemId] then
        local row = base(obj)
        row.kind, row.gift, row.itemId, row.event = "item", true, gift.itemId, gift.event
        local daily = self.hoenn and self.constants:flag("DAILY_FLAGS_START")
        row.repeatable = daily and gift.event >= daily
          and gift.event <= (self.constants:flag("DAILY_FLAGS_END") or daily + 63) or nil
        row.id = mapId .. "_gift_" .. key
        gifts[key], out[2][#out[2] + 1] = row, row
      end
    end
    for _, command in ipairs(rows) do
      if command.op == "trainerbattle" then
        hasTrainer = true
        local id, typ = command.trainer or command[1], command.type
        local def = self.Trainers.get(id)
        if typ ~= 5 and typ ~= 7 and not (self.emerald and (typ == 9 or typ == 12)) then -- rematch op points at the same base trainer
          local rival = def and (self.hoenn and def.class == self.constants:id("trainer_classes",
              self.rs and "TRAINER_CLASS_POKEMON_TRAINER_3" or "TRAINER_CLASS_RIVAL")
            or not self.hoenn and (def.class == 81 or def.class == 89 or def.class == 90))
          local league = mapId:match("^FR_POKEMON_LEAGUE_") ~= nil
            or self.hoenn and mapId:match("_EVER_GRANDE_CITY_.*ROOM$") ~= nil
          local key = rival and ("rival:" .. tostring(def.class) .. ":" .. tostring(typ == 9))
            or league and def and ("league:" .. def.class .. ":" .. def.name) or tostring(id)
          local row = trainers[key]
          if not row then
            row = base(obj)
            row.id = mapId .. "_trainer_" .. key
            row.label = def and ((def.className or "") .. " " .. (def.name or "")):gsub("^%s+", "") or "TRAINERS"
            row.rival, row.league, row.optional = rival, league, not self.hoenn and typ == 9
            row.required = not row.optional and (rival or league or def and (not self.hoenn and def.class == 83
              or self.hoenn and (def.class == self.constants:id("trainer_classes", "TRAINER_CLASS_AQUA_LEADER")
                or def.class == self.constants:id("trainer_classes", "TRAINER_CLASS_MAGMA_LEADER")))) or nil
            row.flags, row.untracked = {}, not def or type(id) ~= "number"
            trainers[key], out[1][#out[1] + 1] = row, row
          end
          if type(id) == "number" then row.flags[self.adapter.Flags.trainerFlagId(id)] = true end
        end
      elseif command.op == "setwildbattle" or command.op == "givemon" or command.op == "giveegg" then
        hasMon = true
        local species = command[1]
        if proven[command] then -- receipt-based objective above
        elseif type(species) == "number" and species < 0x4000 then
          mon(species, obj, command.op ~= "setwildbattle" and command or nil, command.op == "setwildbattle")
        elseif vars[species] then
          for _, candidate in ipairs(sortedKeys(vars[species])) do
            mon(candidate, obj, command.op ~= "setwildbattle" and command or nil, command.op == "setwildbattle")
          end
        else
          out[1][#out[1] + 1] = { label = "POKEMON", mapId = mapId, untracked = true }
        end
      elseif not self.hoenn and command.op == "special" and command.id == 443 then
        -- CreateEventLegalEnemyMon uses the immediately preceding three vars.
        local species
        for _, r in ipairs(rows) do
          if r == command then break end
          if r.op == "setvar" and (r.var or r[1]) == 0x8004 then species = r.value or r[2] end
        end
        hasMon = true
        mon(species, obj, nil, true)
      elseif self.hoenn and command.op == "special" and command.id == self.constants:special(
          self.rs and "ScrSpecial_ChooseStarter" or "ChooseStarter") then
        hasMon = true
        for _, nat in ipairs({ 252, 255, 258 }) do mon(self.adapter.Pokemon.speciesFromNational(nat), obj) end
      elseif command.op == "specialvar" and command[2] == (self.hoenn
          and self.constants:special("GetInGameTradeSpeciesInfo") or 252) then
        hasMon = true -- The proven offer is a separate receipt-based objective above.
      end
    end
    -- Ground pickups use Std_FindItem and their object's durable flag.
    if objectSource then
      local value
      for _, command in ipairs(bundle.scripts[obj.scriptKey] or {}) do
        if (command.op == "setvar" or command.op == "setorcopyvar") and (command.var or command[1]) == 0x8000 then
          value = command.value or command[2]
        elseif (command.op == "callstd" or command.op == "gotostd") and command.std == 1 then
          local row = base(obj)
          row.kind, row.itemId, row.event = "item", value, obj.flag
          row.unknown = not self.adapter.data.items[value]
          row.untracked = row.unknown or not obj.flag or obj.flag < 0x20 or obj.flag == 65535
          if self.emerald and mapId:match("^EM_BATTLE_PYRAMID_SQUARE") then
            -- These templates receive random items for each challenge and have
            -- no permanent collection flag. Never count them as route pickups.
            row.itemId, row.event, row.untracked, row.repeatable = nil, nil, nil, true
            row.label = "ITEMS"
          end
          out[2][#out[2] + 1], hasItem = row, true
        end
      end
      -- These balls start hidden. Ownership of a non-consumable key item is
      -- evidence; the initial hide flag on its own is not.
      if mapId == "FR_ROCKET_HIDEOUT_B4F" and (obj.flag == 54 or obj.flag == 55) then
        local row = base(obj)
        row.kind, row.itemId, row.ownedKey = "item", value, true
        out[2][#out[2] + 1], hasItem = row, true
      elseif mapId == "FR_MT_MOON_B2F" and (obj.flag == 47 or obj.flag == 48) then
        local row = base(obj)
        row.kind, row.itemId = "item", obj.flag == 47 and 358 or 357
        row.event, row.alternative = obj.flag == 47 and 626 or 627, obj.flag == 47 and 627 or 626
        out[2][#out[2] + 1], hasItem = row, true
      end
      if self.rs and mapId:match("_ROUTE111$") and (obj.flag == self.constants:flag("FLAG_HIDE_ROOT_FOSSIL")
          or obj.flag == self.constants:flag("FLAG_HIDE_CLAW_FOSSIL")) then
        -- RS hides both fossils after either choice, without recording which one.
        -- Represent the single durable choice, never claim both items were received.
        if obj.flag == self.constants:flag("FLAG_HIDE_ROOT_FOSSIL") then
          local row = base(obj)
          row.kind, row.event = "item", obj.flag
          row.label = self.adapter.data.items[286].name .. " / " .. self.adapter.data.items[287].name
          out[2][#out[2] + 1] = row
        end
        hasItem = true
      end
      if self.emerald then
        local C = self.constants
        local root, claw = C:flag("FLAG_CHOSE_ROOT_FOSSIL"), C:flag("FLAG_CHOSE_CLAW_FOSSIL")
        local items = vars[0x8000] or {}
        -- The collapse hides both fossils. Their individual choice flags,
        -- rather than the hide flags, prove which reward was selected.
        if mapId == "EM_MIRAGE_TOWER_4F" and (
            obj.flag == C:flag("FLAG_HIDE_MIRAGE_TOWER_ROOT_FOSSIL") and items[286]
            or obj.flag == C:flag("FLAG_HIDE_MIRAGE_TOWER_CLAW_FOSSIL") and items[287]) then
          local isRoot = items[286] == true
          local row = base(obj)
          row.kind, row.itemId = "item", isRoot and 286 or 287
          row.event, row.alternative = isRoot and root or claw, isRoot and claw or root
          out[2][#out[2] + 1], hasItem = row, true
        elseif mapId == "EM_DESERT_UNDERPASS" and obj.flag == C:flag("FLAG_HIDE_DESERT_UNDERPASS_FOSSIL")
            and items[286] and items[287] then
          for _, item in ipairs({ 286, 287 }) do
            local row = base(obj)
            row.id, row.kind, row.itemId, row.event = row.id .. "_" .. item, "item", item, obj.flag
            row.needsChoice, row.otherChoice = item == 286 and claw or root, item == 286 and root or claw
            row.unlockVar, row.unlockValue = C:var("VAR_MIRAGE_TOWER_STATE"), 2
            row.choiceGroup = mapId .. ":remaining-fossil"
            out[2][#out[2] + 1] = row
          end
          hasItem = true
        end
      end
      local decorativeBall = self.rs and obj.flag == self.constants:flag("FLAG_LINK_CONTEST_ROOM_POKEBALL")
        or self.emerald and (
        obj.flag == self.constants:flag("FLAG_HIDE_CONTEST_POKE_BALL")
        or obj.flag == self.constants:flag("FLAG_HIDE_LITTLEROOT_TOWN_BRENDANS_HOUSE_2F_POKE_BALL")
        or obj.flag == self.constants:flag("FLAG_HIDE_LITTLEROOT_TOWN_MAYS_HOUSE_2F_POKE_BALL"))
      if not hasTrainer and (obj.trainerType == 1 or obj.trainerType == 3)
          or obj.graphicsId == (self.hoenn and self.constants:id("event_objects", "OBJ_EVENT_GFX_ITEM_BALL") or 92)
            and not hasItem and not hasMon and not decorativeBall then
        local row = base(obj)
        row.label, row.untracked = "NOT TRACKED", true
        out[1][#out[1] + 1] = row
      end
    end
    if missing then
      local row = base(obj)
      row.label, row.untracked = "NOT TRACKED", true
      out[1][#out[1] + 1] = row
    end
  end
  for _, obj in ipairs(event.objects or {}) do
    if not obj.cloneTarget then scan(obj, true) end
  end
  for _, obj in ipairs(event.coordEvents or {}) do scan(obj) end
  for _, key in ipairs(sortedKeys(event.mapScripts)) do
    local entry = event.mapScripts[key]
    if type(entry) == "string" then scan({ scriptKey = entry })
    elseif type(entry) == "table" then
      for _, trigger in ipairs(entry) do scan({ scriptKey = trigger.script }) end
    end
  end
  for _, bg in ipairs(event.bgEvents or {}) do
    if bg.type == "hidden_item" then
      local row = base(bg)
      row.kind, row.itemId, row.event = "hidden", bg.item, bg.flag
      row.underfoot = bg.underfoot
      row.repeatable = self.renewable[bg.flag] == true
      row.unknown = not self.adapter.data.items[bg.item]
      row.untracked = row.unknown or not bg.flag or bg.flag < 0x20
      out[3][#out[3] + 1] = row
    elseif bg.scriptKey then scan(bg) end
  end
  if self.hoenn then
    for _, row in ipairs(out[1]) do
      local name = (self.constants.flags.byId.FLAG_ or {})[row.hideEvent] or ""
      if row.flags and not row.required and (name:find("AQUA") or name:find("MAGMA")) then row.missable = true end
    end
  end
  if mapId:match("^FR_TRAINER_TOWER_%dF$") or mapId:match("^EM_TRAINER_HILL_")
      or mapId:match("^EM_BATTLE_FRONTIER_BATTLE_") or mapId:match("^EM_BATTLE_PYRAMID_SQUARE") then
    -- Tower opponents are generated per challenge, without route defeat flags.
    out[1][#out[1] + 1] = { label = "TRAINERS", mapId = mapId, repeatable = true }
  end
  -- A battle callback and its retry NPC can reference the same gift command.
  for i = #out[4], 1, -1 do
    local row = out[4][i]
    if row.giftCommand then
      for _, reward in ipairs(out[4]) do
        if reward.command == row.giftCommand then table.remove(out[4], i); break end
      end
    end
  end
  table.sort(out[4], function(a, b) return a.species < b.species end)
  self.maps[mapId], self.builds = out, self.builds + 1
  return out
end

function M:ownsKey(id)
  local session = self.adapter.session
  for _, pocket in pairs(session and session.bag and session.bag.pockets or {}) do
    for _, item in ipairs(pocket) do
      if item.id == id and (item.qty or 0) > 0 then return true end
    end
  end
  for _, item in ipairs(session and session.storage and session.storage.items or {}) do
    if item.id == id and (item.qty or 0) > 0 then return true end
  end
  return false
end

function M:completionKey()
  -- Native variable and Bag/PC writes need not emit flag.changed.
  if self.emerald then
    local function reached(name, value)
      return self.adapter.Flags.getVar(self.adapter:flagStore(), nil, self.constants:var(name)) >= value
    end
    return (reached("VAR_DEX_UPGRADE_JOHTO_STARTER_STATE", 6) and 1 or 0)
      + (reached("VAR_MIRAGE_TOWER_STATE", 2) and 2 or 0)
  end
  if self.rs then return 0 end
  -- These hidden, non-consumable keys require actual ownership.
  return (self:ownsKey(356) and 1 or 0) + (self:ownsKey(359) and 2 or 0)
end

function M:rows(mapIds, checkpoint)
  local out, adapter = { {}, {}, {}, {} }, self.adapter
  local store, Flags = adapter:flagStore(), adapter.Flags
  local function flag(id)
    if self.hoenn and type(id) == "string" then id = self.constants:flag(id) end
    return id ~= nil and Flags.getFlag(store, nil, id) == true
  end
  for _, id in ipairs(mapIds) do
    local catalog = self:catalog(id, checkpoint)
    for category = 1, 4 do
      for _, source in ipairs(catalog[category]) do
        if category ~= 4 or source.gift then
          local row = copy(source)
          if id:match("^FR_SSANNE_") and row.itemId == 339 then row.required = true end -- HM01 is needed before departure.
          if not row.required and (id:match("^FR_SSANNE_")
              or category == 1 and id:match("^FR_SILPH_CO_")) then row.missable = true end
          row.done = row.event and flag(row.event) or false
          if row.receiptVar then row.done = Flags.getVar(store, nil, row.receiptVar) >= row.receiptValue end
          if row.catchGoal then row.done = adapter.save.pokedex.caught[row.species] == true end
          if row.flags then
            for event in pairs(row.flags) do row.done = row.done or flag(event) end
            if row.league then row.done = row.done or flag("FLAG_SYS_GAME_CLEAR") end
            if row.rival then row.label = adapter.session and adapter.session.rivalName or row.label end
          elseif row.ownedKey then
            row.done = self:ownsKey(row.itemId)
          end
          if row.itemId then row.label = (adapter.data.items[row.itemId] or {}).name or "ITEMS" end
          row.excluded = row.alternative and not row.done and flag(row.alternative)
            and not (row.choiceEvent and flag(row.choiceEvent)) or nil
          if row.needsChoice then
            local unlocked = Flags.getVar(store, nil, row.unlockVar) >= row.unlockValue
            row.done = row.done and unlocked and flag(row.needsChoice)
            row.excluded = flag(row.otherChoice)
            if not unlocked or not flag(row.needsChoice) then row.available, row.status = false, "LATER" end
          end
          if row.repeatable then
            row.available, row.done = not flag(row.event), false
            row.status = (category == 1 or not row.event) and "REPEATABLE" or row.available and "READY" or "RENEWABLE"
          elseif row.untracked then row.status = "NOT TRACKED"
          elseif row.excluded then row.status = "ALTERNATIVE CHOICE"
          elseif not row.done and id:match("^FR_SSANNE_") and flag("FLAG_HIDE_SS_ANNE") then
            row.missed, row.available, row.status = true, false, "MISSED"
          elseif not row.done and row.hideEvent and row.hideEvent >= 0x20 and flag(row.hideEvent) then
            row.available = false
            if row.flags and not self.initiallyHidden[row.hideEvent] then
              row.missed, row.status = true, "MISSED"
            else row.status = "LATER" end
          end
          if row.trade then
            row.label = adapter.data.pokemon[row.species].name
            row.order = adapter.data.pokemon[row.species].dex
            local partner
            for _, mon in ipairs(adapter.session and adapter.session.party or {}) do
              if not adapter.Pokemon.isEgg(mon) and adapter.Pokemon.speciesOf(mon) == row.needsSpecies then
                partner = mon; break
              end
            end
            row.available = not row.done and row.available ~= false and partner ~= nil
              and reaches(self.source.scripts, row.scriptKey, row.command, row.event, 0, false, checkpoint, flag) == true
            row.status = row.done and "RECORDED" or row.available and "READY" or "LATER"
          end
          if category == 4 and row.gift and not row.trade then
            local session = adapter.session or {}
            local party = #(session.party or {})
            row.label = row.isEgg and "EGG" or adapter.data.pokemon[row.species].name
            row.order = row.isEgg and 0 or adapter.data.pokemon[row.species].dex
            row.noRoom = party >= 6 and (not row.toPC
              or not require("src.core.game3.storage").findOpenSlot(session.storage)) or nil
            local lead
            for _, mon in ipairs(session.party or {}) do if not adapter.Pokemon.isEgg(mon) then lead = mon; break end end
            local friendship = lead and adapter.Pokemon.friendshipOf(lead) or 0
            local score = friendship == 255 and 6 or friendship >= 200 and 5 or friendship >= 150 and 4
              or friendship >= 100 and 3 or friendship >= 50 and 2 or friendship > 0 and 1 or 0
            row.available = not row.done and not row.excluded and row.available ~= false and not row.noRoom
              and pokemonPath(self.source.scripts, row.scriptKey, row.command,
                row.event or row.deliveryFlag or (row.receiptVar and { var = row.receiptVar, value = row.receiptValue }) or 0,
                { live = true, party = party, money = session.money or 0, gender = session.gender,
                  choice = row.choice, coins = session.coins or 0, species = row.species,
                  friendship = score, flag = flag, var = function(v) return Flags.getVar(store, nil, v) end,
                  firered = not self.hoenn, rs = self.rs }, checkpoint) == true
            row.status = row.done and (row.catchGoal and "CAUGHT" or "RECORDED") or row.available and "READY" or "LATER"
          end
          out[category][#out[category] + 1] = row
        end
      end
    end
  end
  return out
end

function M:pokemon(mapIds, checkpoint, rewards)
  local adapter, bySpecies = self.adapter, {}
  rewards = rewards or self:rows(mapIds, checkpoint)[4]
  for _, id in ipairs(mapIds) do
    for _, row in ipairs(adapter:encounters(id)) do
      bySpecies[row.species] = { species = row.species, mapId = id, wild = true }
    end
    for _, row in ipairs(self:catalog(id, checkpoint)[4]) do
      if not row.gift and not (bySpecies[row.species] and bySpecies[row.species].wild) then bySpecies[row.species] = row end
    end
  end
  for _, row in ipairs(rewards) do if row.catchGoal then bySpecies[row.species] = row end end
  local caught, out = adapter.save and adapter.save.pokedex.caught or {}, {}
  local function goal(ids)
    local row, names, done = nil, {}, false
    for _, species in ipairs(ids) do
      if bySpecies[species] then
        row = row or copy(bySpecies[species])
        names[#names + 1] = adapter.data.pokemon[species].name
        if caught[species] then row.species, done = species, true end
        bySpecies[species] = nil
      end
    end
    if row then
      row.label, row.done = table.concat(names, " / "), done
      row.order = adapter.data.pokemon[row.species].dex
      out[#out + 1] = row
    end
  end
  for _, id in ipairs(mapIds) do
    if self.hoenn and id:match("_ROUTE101$") then
      goal({ adapter.Pokemon.speciesFromNational(252), adapter.Pokemon.speciesFromNational(255),
        adapter.Pokemon.speciesFromNational(258) })
    elseif self.rs and id:match("_RUSTBORO_CITY_DEVON_CORP_2F$") then
      goal({ adapter.Pokemon.speciesFromNational(345), adapter.Pokemon.speciesFromNational(347) })
    elseif id == "FR_OAKS_LAB" then
      -- One starter is obtainable, even before the player chooses it.
      local starter = adapter.Flags.getVar(adapter:flagStore(), nil, "VAR_STARTER_MON")
      if adapter.Flags.getFlag(adapter:flagStore(), nil, "FLAG_SYS_POKEMON_GET") then
        local selected = ({ [0] = 1, [1] = 7, [2] = 4 })[starter]
        for _, sp in ipairs({ 1, 4, 7 }) do if sp ~= selected then bySpecies[sp] = nil end end
      end
      goal({ 1, 4, 7 })
    elseif id == "FR_SAFFRON_CITY_DOJO" then goal({ 106, 107 })
    elseif id == "FR_CINNABAR_ISLAND_POKEMON_LAB_EXPERIMENT_ROOM" then
      if adapter.Flags.getFlag(adapter:flagStore(), nil, "FLAG_GOT_DOME_FOSSIL") then bySpecies[138] = nil
      elseif adapter.Flags.getFlag(adapter:flagStore(), nil, "FLAG_GOT_HELIX_FOSSIL") then bySpecies[140] = nil end
      goal({ 138, 140 })
    end
  end
  for _, species in ipairs(sortedKeys(bySpecies)) do goal({ species }) end
  local choices = {}
  for _, row in ipairs(rewards) do
    local receipt = row.event or (row.receiptVar and "var:" .. row.receiptVar .. ":" .. row.receiptValue)
    if row.alternative and not (adapter.Flags.getFlag(adapter:flagStore(), nil, 626)
        and adapter.Flags.getFlag(adapter:flagStore(), nil, 627)) then receipt = "fossil-choice" end
    local existing = not row.trade and choices[receipt]
    if row.catchGoal or row.excluded then -- Caught goals are already included above; unchosen fossils are unobtainable.
    elseif existing then
      existing.label = existing.label .. " / " .. row.label
      existing.done = existing.done or row.done
    else
      out[#out + 1] = row
      if not row.trade then choices[receipt] = row end
    end
  end
  table.sort(out, function(a, b) return a.order < b.order end)
  return out
end

return M
