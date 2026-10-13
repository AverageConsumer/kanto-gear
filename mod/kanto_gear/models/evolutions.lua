-- Describe the active game's evolution rows without running evolution hooks.
local Evolutions = {}
local methods = { "FRIENDSHIP", "FRIENDSHIP_DAY", "FRIENDSHIP_NIGHT", "LEVEL", "TRADE",
  "TRADE_ITEM", "ITEM", "ATK_GT_DEF", "ATK_EQ_DEF", "ATK_LT_DEF", "SILCOON", "CASCOON",
  "NINJASK", "SHEDINJA", "BEAUTY" }

-- Game path [Gen 3 vs Gen 1/2]: GBA evolution rows use numeric method/parameter/target triples; older models expose named fields.
function Evolutions.rows(def, generation, options)
  local out = {}
  for _, evo in ipairs(def.evolutions or {}) do
    local species = generation == 3 and (evo.target or evo[3]) or evo.into or evo.species
    if species and species ~= 0 then
      local method = generation == 3 and methods[tonumber(evo.method or evo[1])] or evo.method
      method = type(method) == "string" and method:gsub("^EVOLVE_", "") or method
      local param = generation == 3 and (evo.param or evo[2]) or evo.level
      local lines, blocked, known = {}, false, true
      local function add(key, ...) lines[#lines + 1] = options.format(key, ...) end
      local function level() add("LEVEL UP: LV.%d+", tonumber(param) or 0) end
      local function item() return options.itemName(generation == 3 and param or evo.item) end
      if method == "LEVEL" or method == "NINJASK" then level()
      elseif method == "ITEM" then add("USE %s", item())
      elseif method == "TRADE" or method == "TRADE_ITEM" then
        add("TRADE")
        if method == "TRADE_ITEM" or evo.item then add("HOLDING %s", item()) end
      -- Game path [Gen 2/3]: friendship time gates use their native clocks; FireRed/LeafGreen cannot satisfy day/night evolution conditions.
      elseif method == "HAPPINESS" or method == "FRIENDSHIP" or method == "FRIENDSHIP_DAY" or method == "FRIENDSHIP_NIGHT" then
        add("LEVEL UP: FRIENDSHIP %d+", 220)
        if method == "FRIENDSHIP_DAY" then add("GAME CLOCK: 12:00-23:59")
        elseif method == "FRIENDSHIP_NIGHT" then add("GAME CLOCK: 00:00-11:59")
        elseif evo.time == "MORNDAY" then add("MORNING / DAY")
        elseif evo.time == "NITE" then add("NIGHT") end
        if (method == "FRIENDSHIP_DAY" or method == "FRIENDSHIP_NIGHT") and options.noClock then
          add("NO DAY/NIGHT CLOCK IN THIS GAME"); blocked = true
        end
      elseif method == "STAT" or method == "ATK_GT_DEF" or method == "ATK_EQ_DEF" or method == "ATK_LT_DEF" then
        level()
        local comparison = method == "STAT" and evo.comparison or method
        local labels = { ATK_GT_DEF = "ATTACK > DEFENSE", ATK_EQ_DEF = "ATTACK = DEFENSE", ATK_LT_DEF = "ATTACK < DEFENSE" }
        add(labels[comparison] or "CONDITION NOT AVAILABLE")
      elseif method == "SILCOON" or method == "CASCOON" then
        level(); add("FORM FIXED BY PERSONALITY")
      elseif method == "SHEDINJA" then
        level(); add("EXTRA POKEMON AFTER EVOLVING"); add("EMPTY PARTY SLOT REQUIRED")
      elseif method == "BEAUTY" then
        add("LEVEL UP: BEAUTY %d+", tonumber(param) or 0)
      else add("CONDITION NOT AVAILABLE"); known = false end
      -- Game path [Gen 2 vs Gen 3]: Everstone blocks different evolution methods; retain the existing item/trade exceptions of each engine.
      if known and generation > 1 and (method ~= "ITEM" or generation == 3)
          and method ~= "TRADE_ITEM" and not (method == "TRADE" and evo.item) then
        add("NOT HOLDING EVERSTONE")
      end
      if options.nationalAllows and not options.nationalAllows(species) then
        add("NATIONAL DEX REQUIRED"); blocked = true
      end
      out[#out + 1] = { species = species, conditions = lines, blocked = blocked,
        revealed = options.knownSpecies(species) }
    end
  end
  return out, def.evolutions ~= nil
end

return Evolutions
