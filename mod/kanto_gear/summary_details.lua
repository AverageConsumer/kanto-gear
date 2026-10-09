-- Read-only hidden partner facts. Never normalize the host's Pokemon or save.
local Details = {}
local types = { "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BUG", "GHOST", "STEEL",
  "FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC_TYPE", "ICE", "DRAGON", "DARK" }
local legacy = { { "HP", "hp" }, { "ATTACK", "attack" }, { "DEFENSE", "defense" },
  { "SPEED", "speed" }, { "SPECIAL", "special" } }
local modern = { { "HP", "hp" }, { "ATTACK", "atk" }, { "DEFENSE", "def" },
  { "SPEED", "spe" }, { "SP. ATK", "spa" }, { "SP. DEF", "spd" } }

function Details.isEgg(mon)
  return mon and (mon.isEgg == true or mon.egg == true) or false
end

function Details.read(mon, generation)
  local genes, effort = generation == 3 and mon.ivs or mon.dvs,
    generation == 3 and mon.evs or mon.statExp
  local out = { rows = {}, geneLabel = generation == 3 and "IV /31" or "DV /15",
    effortLabel = generation == 3 and "EV /255" or "EXP /65535" }
  if generation > 1 and not Details.isEgg(mon) then
    out.friendship = tonumber(generation == 3 and (mon.friendship or mon.happiness) or mon.happiness)
  end
  local complete, total, bitType, bitPower = true, 0, 0, 0
  for i, row in ipairs(generation == 3 and modern or legacy) do
    local gene, training = genes and tonumber(genes[row[2]]), effort and tonumber(effort[row[2]])
    if generation < 3 and row[2] == "hp" and genes then
      local a, d, s, p = tonumber(genes.attack), tonumber(genes.defense), tonumber(genes.speed), tonumber(genes.special)
      gene = a and d and s and p and (a % 2 * 8 + d % 2 * 4 + s % 2 * 2 + p % 2) or nil
    end
    out.rows[i] = { label = row[1], gene = gene, effort = training }
    complete = complete and gene ~= nil
    if training == nil then total = nil elseif total then total = total + training end
    if generation == 3 and gene then
      bitType = bitType + gene % 2 * 2 ^ (i - 1)
      bitPower = bitPower + math.floor(gene / 2) % 2 * 2 ^ (i - 1)
    end
  end
  out.total = generation == 3 and total or nil
  if complete and generation == 3 then
    out.power, out.type = math.floor(bitPower * 40 / 63) + 30, types[math.floor(bitType * 15 / 63) + 1]
  elseif complete and generation == 2 then
    local function high(v) return math.floor(v / 8) % 2 end
    local bits = high(genes.attack) * 8 + high(genes.defense) * 4 + high(genes.speed) * 2 + high(genes.special)
    out.power = math.floor((bits * 5 + genes.special % 4) / 2) + 31
    out.type = types[genes.attack % 4 * 4 + genes.defense % 4 + 1]
  end
  return out
end

function Details.egg(mon, generation, save, native)
  if not Details.isEgg(mon) then return nil end
  local cycles = tonumber(generation == 3 and (mon.friendship or mon.eggCycles or mon.cycles) or mon.eggSteps)
  local out = { cycles = cycles }
  if not cycles or mon.isBadEgg then return out end
  local phase, tick, rate = save and tonumber(save.stepCount), 128, 1
  if generation == 3 then
    local session = native and native.session
    local id = native and native.profile and native.profile.id
    local store = session and session.modData and session.modData[tostring(id) .. "_daycare"]
    local daycare = session and (session.daycare or store and store.daycare)
    phase, tick = daycare and tonumber(daycare.stepCounter), 255
    if id == "emerald" and session then
      rate = require("src.core.game3.daycare").eggCyclesToSubtract(session)
    end
  end
  if generation == 2 and cycles == 0 then out.steps = 0; return out end
  if phase == nil then return out end
  local first = (tick - phase) % 256
  if first == 0 then first = 256 end
  local ticks = generation == 3 and math.ceil(cycles / rate) + 1 or cycles
  out.steps = first + math.max(0, ticks - 1) * 256
  return out
end

return Details
