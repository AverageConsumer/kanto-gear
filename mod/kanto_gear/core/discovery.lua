-- One disclosure boundary for every companion surface. Native game UI is unchanged.
local Discovery = {}

Discovery.groups = {
  { "EXPLORATION", "exploration" }, { "POKEDEX", "pokedex" },
  { "BATTLE", "battle" }, { "PARTNER DATA", "partner" },
  { "STAMPS", "stamps" },
}
-- Each fact has one permission, shared by apps, widgets and battle companions.
Discovery.options = {
  { "area_map", "LIVE AREA MAP", "exploration", true, "Show the surrounding area, including terrain beyond the game's camera." },
  { "wild", "WILD ENCOUNTERS", "exploration", true, "List wild Pokemon and locations. Unseen species and encounter details are separate options." },
  { "encounter_details", "ENCOUNTER DETAILS", "exploration", true, "Show encounter levels, chances, methods and time or tool requirements." },
  { "trainers", "TRAINER CHECKLIST", "exploration", true, "Show trainer names, checklist entries and map markers before defeating them." },
  { "items", "ITEM CHECKLIST", "exploration", true, "Show item names, checklist entries and map markers before collecting them." },
  { "item_details", "EXTRA ITEM DATA", "exploration", true, "Add item descriptions where the game has none. Native descriptions remain available." },
  { "gifts", "GIFTS AND TRADES", "exploration", true, "Reveal NPC gifts, trades and their requirements before receiving them." },
  { "hidden_items", "HIDDEN ITEMS", "exploration", false, "Reveal hidden items without a scan or collection. Requires Item Checklist." },
  { "berries", "BERRY INFORMATION", "exploration", true, "Show berry locations, contents and readiness on the area map." },
  { "event_calendar", "EVENT SCHEDULE", "exploration", true, "Show weekday visitors, rematch times and events before you meet them." },
  { "unvisited_maps", "UNVISITED LOCATIONS", "exploration", false, "Include unvisited places in habitats and checklists. Does not unlock game access." },
  { "future_tasks", "FUTURE TASKS", "exploration", false, "Include story-locked, unavailable and missed tasks. Their category must also be enabled." },
  { "unknown_species", "UNSEEN SPECIES", "pokedex", true, "Reveal Pokemon you have not seen in the Dex, encounter lists and evolution targets." },
  { "dex_description", "UNCAUGHT DEX DATA", "pokedex", true, "Reveal category, height, weight and Dex text before catching. Caught entries stay visible." },
  { "dex_types", "SPECIES TYPES", "pokedex", true, "Show species types before catching them. Your own Pokemon and caught Dex entries keep their native types." },
  { "dex_stats", "SPECIES NUMBERS", "pokedex", true, "Show base stats, their total, catch rate and base experience in the Dex." },
  { "dex_moves", "LEARNSETS", "pokedex", true, "Show future level-up moves and the full TM/HM learnset in the Dex." },
  { "dex_evolutions", "EVOLUTION CONDITIONS", "pokedex", true, "Show evolution targets and requirements. Unseen target names still follow Unseen Species." },
  { "habitats", "DETAILED HABITATS", "pokedex", true, "Show exact habitats and access requirements. New places need Unvisited Locations enabled." },
  { "enemy_details", "OPPONENT DATA", "battle", true, "Show opponent types and Dex facts in Info mode. Matchups and enemy genes have separate switches." },
  { "enemy_genes", "OPPONENT GENES", "battle", false, "Reveal opponent DVs when the host provides them. Requires Opponent Data." },
  { "type_hints", "TYPE MATCHUPS", "battle", true, "Show attack effectiveness, weaknesses, resistances and STAB hints." },
  { "move_details", "EXTRA MOVE DATA", "battle", true, "Show extra attack power, accuracy and effects. Native summary data stays available." },
  { "catch_odds", "CATCH CHANCES", "battle", true, "Show estimated catch chances for Poke Balls. Estimates are not a guarantee." },
  { "friendship", "EXACT FRIENDSHIP", "partner", false, "Show your Pokemon's exact friendship value instead of the game's verbal hints." },
  { "genes", "PARTNER GENES", "partner", false, "Show your Pokemon's IVs or DVs and calculated Hidden Power." },
  { "training", "PARTNER TRAINING", "partner", false, "Show your Pokemon's EVs or stat experience. Does not change training in the game." },
  { "egg_progress", "EGG PROGRESS", "partner", false, "Show remaining hatch cycles and estimated steps. Hatchling identity has a separate switch." },
  { "egg_species", "EGG CONTENTS", "partner", false, "Reveal which Pokemon is inside an egg before it hatches." },
  { "daycare_odds", "DAY-CARE ODDS", "partner", true, "Show egg chances and the steps to the next egg check." },
  { "stamp_totals", "COMPLETION TOTALS", "stamps", true, "Show stamp tiers, missing-goal counts and completion totals. Task names and locations follow their own switches." },
  { "journey_stats", "JOURNEY COUNTERS", "stamps", true, "Show Gear's step counter and derived journey totals. Your own notes stay available when off." },
}
Discovery.byKey = {}
function Discovery.key(name)
  return (name == "type_hints" or name == "move_details" or name == "catch_odds")
    and name or "reveal_" .. name
end
for _, row in ipairs(Discovery.options) do Discovery.byKey[Discovery.key(row[1])] = row end

function Discovery.resolve(get)
  local preset = get("info_level")
  local mode = Discovery.mode(preset, get("local_map"))
  local policy = { preset = preset, mode = mode }
  local signature = { tostring(preset) }
  for _, row in ipairs(Discovery.options) do
    local value = mode == "spoiler" or mode == "enhanced" and row[4] or false
    if preset == "custom" then
      local saved = get(Discovery.key(row[1]))
      value = saved == true
    end
    policy[row[1]] = value
    signature[#signature + 1] = value and "1" or "0"
  end
  policy.signature = table.concat(signature, ":")
  return policy
end

function Discovery.define(schema, policy)
  schema[#schema + 1] = { key = "discovery_section", label = "INFO CATEGORY", type = "choice",
    default = "exploration", choices = Discovery.groups,
    visible_if = { key = "info_level", equals = "custom" } }
  for _, row in ipairs(Discovery.options) do
    schema[#schema + 1] = { key = Discovery.key(row[1]), label = row[2], type = "toggle",
      default = policy[row[1]], reset_default = row[4], discoveryGroup = row[3],
      visible_if = { key = "info_level", equals = "custom" } }
  end
  return schema
end

function Discovery.allows(policy, name)
  if type(policy) == "table" then return policy[name] == true end
  return policy == "spoiler" or policy ~= "vanilla" and name ~= "hidden_items"
    and name ~= "unvisited_maps" and name ~= "future_tasks"
end

-- Host path [all games]: older legacy/vanilla/profile values must resolve to the existing disclosure mode when loading saved options.
function Discovery.mode(value, localMap)
  if value == "spoiler" or value == "legacy" and localMap == "enhanced" then
    return "spoiler"
  end
  if value == "purist" or value == "vanilla" or value == "legacy" then
    return "vanilla"
  end
  return "enhanced"
end

function Discovery.map(mode, id, current, visited, save)
  if id == nil then return false end
  if Discovery.allows(mode, "unvisited_maps") then return true end
  return id == current or type(visited) == "table" and visited[id] == true
    or save ~= nil and type(save.visited) == "table" and save.visited[id] == true
end

function Discovery.species(mode, species, seen, caught)
  return Discovery.allows(mode, "unknown_species") or (seen or {})[species] == true
    or (caught or {})[species] == true
end

function Discovery.row(mode, row, category, knownMap)
  if row.done or row.state == "done" then return true end
  if not knownMap then return false end
  if category == 3 and row.scanned == true then return true end
  if not Discovery.allows(mode, category == 1 and "trainers" or category == 4 and "gifts" or "items") then return false end
  if not Discovery.allows(mode, "future_tasks") and (row.available == false or row.excluded or row.missed
      or row.status == "LATER" or row.status == "MISSED" or row.status == "LOST"
      or row.state == "later" or row.state == "unavailable") then return false end
  if category == 3 then return Discovery.allows(mode, "hidden_items") end
  return true
end

function Discovery.filter(rows, predicate)
  local out = {}
  for _, row in ipairs(rows or {}) do
    if predicate(row) then out[#out + 1] = row end
  end
  return out
end

function Discovery.dex(info, policy)
  if not policy.dex_description and not info.caught then
    info.kind, info.height, info.weight, info.heightValue, info.weightValue = nil, nil, nil, nil, nil
    info.descriptionText, info.description = nil, {}
  end
  -- Seeing a Pokemon does not reveal its types in the original Dex.
  if not policy.dex_types and not info.caught then info.types = {} end
  return info
end

function Discovery.enemy(info, policy)
  if not policy.enemy_genes or not policy.enemy_details then info.dvs = nil end
  if not policy.enemy_details then
    info.types = {}
    if not info.caught then
      info.kind, info.height, info.weight, info.heightValue, info.weightValue = nil, nil, nil, nil, nil
      info.descriptionText, info.description = nil, {}
    end
  end
  if not policy.type_hints then info.weak, info.resist = {}, {} end
  info.profileAvailable = policy.enemy_details or info.caught == true
  info.matchupsAvailable = policy.type_hints
  return info
end

return Discovery
