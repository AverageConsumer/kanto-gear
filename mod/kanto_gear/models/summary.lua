local Summary = {}

function Summary.isEgg(mon)
  return mon and (mon.isEgg == true or mon.egg == true) or false
end

local function invoke(state, name)
  local fn = state and state[name]
  if type(fn) ~= "function" then return nil end
  local ok, first, second = pcall(fn, state)
  if ok then return first, second end
end

local function definition(game, kind, id)
  local rows = game and game.data and game.data[kind]
  return rows and id and rows[id] or nil
end

local function moveRows(game, mon, generation)
  local rows = {}
  for slot = 1, 4 do
    local move = mon.moves and mon.moves[slot]
    local def = move and definition(game, "moves", move.id)
    local maxPp = 0
    if move then
      maxPp = move.maxPp or (def and def.pp) or move.pp or 0
      -- Game path [Gen 1/2/3]: Gen 1 derives PP Ups from base PP, Gen 2 has its native maxPp reader, Gen 3 supplies projected maxPp.
      if generation == 1 and def and tonumber(def.pp) then
        maxPp = def.pp + (move.ppUps or 0) * math.floor(def.pp / 5)
      elseif generation == 2 then
        maxPp = require("src.battle.gen2.Mon").maxPpOf(move, game.data)
      end
    end
    rows[slot] = {
      name = def and def.name or move and (move.name or move.id) or "-",
      pp = move and move.pp,
      maxPp = maxPp,
    }
  end
  return rows
end

-- Read-only inspection uses the same facts as native summaries without opening
-- a game menu. The page state below belongs entirely to the companion.
function Summary.inspection(mon, game, generation, contests)
  local state = { screenId = "GearSummaryMenu", generation = generation,
    mon = mon, page = 1, pages = contests and 4 or 3,
    basePages = contests and 4 or 3 }
  function state:itemName()
    local item = definition(game, "items", self.mon.item)
    return item and item.name or self.mon.item
  end
  function state:otName() return self.mon.otName or self.mon.ot end
  function state:otId() return self.mon.otId end
  return state
end

function Summary.configure(state, spoilers)
  state.disclosure = type(spoilers) == "table" and spoilers or nil
  state.spoilers = spoilers == true or state.disclosure ~= nil and
    (spoilers.friendship or spoilers.genes or spoilers.training or spoilers.egg_progress or spoilers.egg_species)
  state.hiddenPage = state.spoilers and (not state.disclosure or state.generation > 1 and spoilers.friendship or spoilers.genes or spoilers.training) and not Summary.isEgg(state.mon)
    and state.basePages + 1 or nil
  state.pages = Summary.isEgg(state.mon) and 1 or state.hiddenPage or state.basePages
  state.page = math.min(state.page or 1, state.pages)
  return state
end

-- Cheap invalidation uses visible facts only, never an extra host snapshot.
function Summary.redrawKey(state, game, native)
  if not state then return "" end
  local mon, parts = state.mon or {}, { tostring(state), tostring(state.page) }
  for _, key in ipairs({ "species", "nickname", "level", "hp", "maxHp", "status",
      "experience", "exp", "item", "ot", "otName", "otId", "nature", "ability",
      "isEgg", "egg", "isBadEgg" }) do
    parts[#parts + 1] = tostring(mon[key])
  end
  if state.spoilers and (state.page == state.hiddenPage or Summary.isEgg(mon)) then
    for _, key in ipairs({ "friendship", "happiness", "eggSteps", "eggCycles" }) do
      parts[#parts + 1] = tostring(mon[key])
    end
    for _, field in ipairs({ "dvs", "ivs", "statExp", "evs" }) do
      for _, key in ipairs({ "hp", "attack", "defense", "speed", "special", "atk", "def", "spe", "spa", "spd" }) do
        parts[#parts + 1] = tostring(mon[field] and mon[field][key])
      end
    end
    if Summary.isEgg(mon) then
      local egg = Summary.details.egg(mon, state.generation, game and game.save, native)
      parts[#parts + 1] = tostring(egg.steps)
    end
  end
  for _, key in ipairs({ "hp", "attack", "defense", "speed", "special", "specialAttack", "specialDefense" }) do
    parts[#parts + 1] = tostring(mon.stats and mon.stats[key])
  end
  for slot = 1, 4 do
    local move = mon.moves and mon.moves[slot] or {}
    parts[#parts + 1] = tostring(move.id)
    parts[#parts + 1] = tostring(move.pp)
    parts[#parts + 1] = tostring(move.maxPp)
    parts[#parts + 1] = tostring(move.ppUps)
  end
  return table.concat(parts, "\31")
end

-- Game path [Gen 1/2/3]: native page counts and move-detail ownership differ; reject a screen until its required readers are available.
function Summary.supports(state)
  if type(state) ~= "table" then return false end
  local id = state and state.screenId
  local gen2, gen3 = id == "Gen2SummaryMenu" or state.generation == 2, id == "Gen3SummaryMenu" or state.generation == 3
  local mon = state and state.mon
  if type(mon) ~= "table" or (Summary.isEgg(mon) and id ~= "GearSummaryMenu")
      or ((gen2 or gen3) and state.moveDetail) then
    return false
  end
  if gen2 and id ~= "GearSummaryMenu" and (type(state.expToNext) ~= "function"
      or type(state.itemName) ~= "function"
      or type(state.otName) ~= "function"
      or type(state.otId) ~= "function") then return false end
  local pages = state.screenId == "GearSummaryMenu" and state.pages or (gen3 and (state.pages or 3) or (gen2 and 3 or 2))
  local page = tonumber(state.page) or 1
  return page >= 1 and page <= pages
end

function Summary.view(state, game)
  if not Summary.supports(state) then return nil end
  local gen2, gen3 = state.screenId == "Gen2SummaryMenu" or state.generation == 2, state.screenId == "Gen3SummaryMenu" or state.generation == 3
  local mon = state.mon
  local pages = state.screenId == "GearSummaryMenu" and state.pages or (gen3 and (state.pages or 3) or (gen2 and 3 or 2))
  local page = tonumber(state.page) or 1

  local def = definition(game, "pokemon", mon.species) or {}
  if Summary.isEgg(mon) then
    return { mon = mon, def = def, egg = true, page = page, pages = pages,
      generation = state.generation, spoilers = state.spoilers, disclosure = state.disclosure }
  end
  local save = game and game.save or {}
  local player = save.player or {}
  local stats = mon.stats or {}
  local item = gen2 and invoke(state, "itemName") or nil
  local nextExp = gen2 and invoke(state, "expToNext") or nil
  local ot = gen2 and invoke(state, "otName") or mon.ot
  local otId = gen2 and invoke(state, "otId") or mon.otId

  local nature, ability, abilityDescription
  -- Game path [Gen 3]: use native nature/ability/item readers; Gen 1/2 use legacy item names and have no natures or abilities.
  if gen3 then
    local Items = require("src.core.game3.items_data")
    item = mon.item and mon.item ~= 0 and Items.displayName(mon.item) or "---"
    local Native = require("src.core.game3.summary_data")
    local Pokemon = require("src.core.game3.pokemon")
    local abilityId = mon.ability or Pokemon.abilityId(mon.species, mon.personality)
    nature = select(2, Native.nature(mon))
    ability = Pokemon.abilityName(abilityId)
    abilityDescription = Native.abilityDescription(abilityId, ability)
  end
  local contest
  -- Game path [Ruby/Sapphire/Emerald]: the fourth native page shows contest move data; FireRed/LeafGreen has no contest page.
  if gen3 and page == 4 and state.hiddenPage ~= 4 then
    local native = require("src.core.game3.rse.contest")
    local data = native.data()
    contest = {}
    for slot = 1, 4 do
      local move = mon.moves and mon.moves[slot]
      local entry = data and data.moves and move and data.moves[move.index]
      local effect = entry and data.effects and data.effects[entry.effect]
      if entry and effect then
        contest[slot] = {
          category = native.CATEGORY_NAMES[entry.category]:upper(),
          appeal = effect.appeal == 255 and "--" or tostring(math.floor(effect.appeal / 10)),
          jam = effect.jam == 255 and "--" or tostring(math.floor(effect.jam / 10)),
          description = effect.description or "",
        }
      end
    end
  end
  return {
    -- Game path [Gen 2/3]: the historical view.gen2 flag means held-item/split-Special capability and also includes Gen 3.
    gen2 = gen2 or gen3, gen3 = gen3,
    capabilities = { heldItems = gen2 or gen3, splitSpecial = gen2 or gen3,
      abilities = gen3, contests = gen3 and (state.basePages or pages) == 4 },
    -- Game path [Gen 3]: native info/stats/moves order differs from the common Gear page order; remap only native summaries.
    layoutPage = state.screenId == "GearSummaryMenu" and page or (gen3 and ({ 3, 1, 2, 4 })[page] or page),
    contest = contest,
    page = page,
    pages = pages,
    mon = mon,
    def = def,
    name = mon.nickname or def.name or mon.species or "POKEMON",
    dex = def.dex or 0,
    level = mon.level or 0,
    hp = mon.hp or 0,
    maxHp = mon.maxHp or stats.hp or mon.hp or 0,
    status = mon.status,
    types = mon.types or def.types or {},
    experience = gen2 and (mon.experience or 0) or (mon.exp or 0),
    nextExp = nextExp,
    item = item,
    nature = nature, ability = ability, abilityDescription = abilityDescription,
    ot = ot or player.name or (gen2 and "GOLD" or "RED"),
    otId = otId or player.id or 0,
    stats = stats,
    moves = moveRows(game, mon, gen3 and 3 or gen2 and 2 or 1),
  }
end

return Summary
