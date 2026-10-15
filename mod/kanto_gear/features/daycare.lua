-- Day-Care facts for one screen and its widgets. The runtime adapters read the
-- live save (Gen 1 route 5 boarder, Gen 2 man/lady pair, Gen 3 pair) into one
-- neutral input; this module only decides what the player may see and how the
-- numbers read. It never writes to the save.
local M = {}

-- Hatch flavour bands shared by Gen 2 (EggStatsScreen: cp $6 / $b / $29) and
-- Gen 3 (sEggHatchTimeTexts: <=5 / <=10 / <=40 cycles).
M.STAGES = { "HATCHES SOON", "CLOSE TO HATCHING", "NEEDS MORE TIME", "NEEDS A LOT MORE TIME" }
function M.stage(cycles)
  cycles = tonumber(cycles)
  if not cycles then return nil end
  if cycles <= 5 then return 1 end
  if cycles <= 10 then return 2 end
  if cycles <= 40 then return 3 end
  return 4
end

-- Verbal compatibility in four bands, the same split the Day-Care Man speaks.
M.TIERS = { [0] = "NO EGGS", "NOT VERY CLOSE", "GET ALONG", "GET ALONG VERY WELL" }

-- Gen 2: wBreedingCompatibility (0, 51, 128, 177, 254, 255) and the egg roll
-- happiness_egg.asm compares a random byte against (80/40/30/10 of 256).
-- Gen 3: GetDaycareCompatibilityScore already is the percent per 256 steps.
function M.compatibility(generation, value)
  value = tonumber(value)
  if not value then return nil end
  if generation == 2 then
    if value == 0 or value == 255 then return { tier = 0, chance = 0 } end
    local byte = value >= 230 and 80 or value >= 170 and 40 or value >= 110 and 30 or 10
    local tier = value >= 230 and 3 or value >= 70 and 2 or 1
    return { tier = tier, chance = math.floor(byte * 100 / 256 + 0.5) }
  end
  if value <= 0 then return { tier = 0, chance = 0 } end
  return { tier = value >= 70 and 3 or value >= 50 and 2 or 1, chance = math.floor(value) }
end

-- Withdrawal fee in every generation: 100 plus 100 per level grown.
function M.fee(grown)
  return 100 + 100 * math.max(0, tonumber(grown) or 0)
end

-- Level-up moves learned in (from, to], appended or shifted over the oldest
-- slot once four are known (Gen 1 WriteMonMoves, Gen 2 FillMoves with
-- wSkipMovesBeforeLevelUp, Gen 3 DeleteFirstMoveAndGiveMoveToMon). `learnset`
-- rows are { level = n, move = id }; `moves` are the current move ids.
function M.learnedMoves(moves, learnset, from, to)
  local current, learned, forgotten = {}, {}, {}
  for _, id in ipairs(moves or {}) do current[#current + 1] = id end
  for _, row in ipairs(learnset or {}) do
    if row.level > from and row.level <= to then
      local known = false
      for _, id in ipairs(current) do if id == row.move then known = true break end end
      if not known then
        if #current >= 4 then
          local dropped = table.remove(current, 1)
          -- A move learned and pushed out again in the same stay was never kept.
          local wasLearned = false
          for index, id in ipairs(learned) do
            if id == dropped then table.remove(learned, index); wasLearned = true break end
          end
          if not wasLearned then forgotten[#forgotten + 1] = dropped end
        end
        current[#current + 1] = row.move
        learned[#learned + 1] = row.move
      end
    end
  end
  return learned, forgotten, current
end

-- Steps until the next Gen 3 egg roll: it fires when the second boarder's
-- step byte reaches $FF after its increment.
function M.gen3StepsToCheck(steps)
  local byte = (tonumber(steps) or 0) % 256
  local left = (255 - byte) % 256
  return left == 0 and 256 or left
end

-- Gen 2 wStepsToEgg: `dec [hl] / ret nz` on a byte, so a 0 waits 256 steps.
function M.gen2StepsToCheck(counter)
  counter = (tonumber(counter) or 0) % 256
  return counter == 0 and 256 or counter
end

-- input = {
--   generation, place, partyCount, partyMax,
--   parents = { { key, mon, name, gender, levelFrom, levelNow, learned, forgotten } },
--   compatibilityValue, breeding (false once the pair stops counting),
--   eggWaiting, stepsToCheck, egg = { species, speciesName, moves },
--   eggs = { { slot, mon, cycles, steps } }, hatchBoost = partner name or nil,
-- }
-- policy = { odds, eggSpecies, eggProgress } from Discovery.
function M.build(input, policy)
  input, policy = input or {}, policy or {}
  local out = {
    generation = input.generation, place = input.place,
    parents = {}, eggs = {}, odds = policy.odds == true,
    partyFull = (input.partyCount or 0) >= (input.partyMax or 6),
  }
  local fees = 0
  for _, parent in ipairs(input.parents or {}) do
    local from = tonumber(parent.levelFrom) or 1
    local now = math.max(from, tonumber(parent.levelNow) or from)
    local row = {
      key = parent.key, mon = parent.mon, name = parent.name, gender = parent.gender,
      levelFrom = from, levelNow = now, grown = now - from, fee = M.fee(now - from),
      learned = parent.learned or {}, forgotten = parent.forgotten or {},
      after = parent.after or {},
    }
    fees = fees + row.fee
    out.parents[#out.parents + 1] = row
  end
  out.fees = #out.parents > 0 and fees or nil
  if input.generation ~= 1 and #out.parents == 2 then
    local compat = M.compatibility(input.generation, input.compatibilityValue)
    if compat then
      out.compatibility = { tier = compat.tier, label = M.TIERS[compat.tier],
        chance = out.odds and compat.chance or nil,
        tip = compat.tier > 0 and compat.tier < 3 }
    end
    local counting = input.breeding ~= false and compat and compat.tier > 0
    if input.eggWaiting then
      out.egg = { waiting = true }
    elseif counting then
      out.egg = { waiting = false, stepsToCheck = out.odds and input.stepsToCheck or nil }
    end
    if out.egg and policy.eggSpecies and input.egg then
      out.egg.species, out.egg.speciesName = input.egg.species, input.egg.speciesName
      out.egg.moves = input.egg.moves or {}
    end
  elseif input.eggWaiting then
    out.egg = { waiting = true }
  end
  for _, egg in ipairs(input.eggs or {}) do
    local stage = M.stage(egg.cycles)
    out.eggs[#out.eggs + 1] = {
      slot = egg.slot, mon = egg.mon, stage = stage, stageLabel = stage and M.STAGES[stage],
      steps = policy.eggProgress and egg.steps or nil,
      cycles = egg.cycles, total = egg.total,
      speciesName = policy.eggSpecies and egg.speciesName or nil,
    }
  end
  out.hatchBoost = input.hatchBoost
  out.empty = #out.parents == 0 and #out.eggs == 0 and not input.eggWaiting
  return out
end

-- What the Home widgets lead with, most urgent first.
function M.headline(model)
  if not model or model.empty then return { kind = "empty" } end
  if model.egg and model.egg.waiting then return { kind = "egg_waiting" } end
  local soonest
  for _, egg in ipairs(model.eggs or {}) do
    if egg.stage and (not soonest or egg.stage < soonest.stage
        or egg.stage == soonest.stage and (egg.steps or math.huge) < (soonest.steps or math.huge)) then
      soonest = egg
    end
  end
  if soonest and soonest.stage <= 2 then return { kind = "hatching", egg = soonest } end
  if model.egg and model.egg.stepsToCheck then return { kind = "egg_check", steps = model.egg.stepsToCheck } end
  if soonest then return { kind = "hatching", egg = soonest } end
  if #model.parents > 0 or model.boarder then return { kind = "boarding" } end
  return { kind = "empty" }
end

return M
