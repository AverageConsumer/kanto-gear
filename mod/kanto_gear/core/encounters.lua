return function()
local function addEncounters(rows, bySpecies, slots, method, buckets, context)
  slots = slots or {}
  if type(context) ~= "table" then context = context and { time = context } end
  local weights, levels, previous = {}, {}, 0
  for index, slot in ipairs(slots) do
    local threshold = buckets and buckets[index]
    local weight = threshold and threshold - previous or 1
    previous = threshold or previous
    local species = slot.species
    if species and species ~= 0 and species ~= "NO_ITEM" then
      local minLevel, maxLevel = slot.min or slot.level, slot.max or slot.level
      weights[species] = (weights[species] or 0) + weight
      local range = levels[species]
      if range then
        range.min, range.max = math.min(range.min, minLevel),
          math.max(range.max, maxLevel)
      else
        levels[species] = { min = minLevel, max = maxLevel }
      end
      local row = bySpecies[species]
      if not row then
        row = { species = species, minLevel = minLevel,
                maxLevel = maxLevel, methods = {}, methodSet = {},
                appearances = {} }
        rows[#rows + 1], bySpecies[species] = row, row
      else
        row.minLevel = math.min(row.minLevel, minLevel)
        row.maxLevel = math.max(row.maxLevel, maxLevel)
      end
      if context and context.time then
        row.times = row.times or {}
        row.times[context.time] = true
      else
        row.allTimes = true
      end
    end
  end
  local total, seen = buckets and buckets[#slots] or #slots, {}
  for _, slot in ipairs(slots) do
    local species = slot.species
    if species and species ~= 0 and species ~= "NO_ITEM"
        and not seen[species] then
      seen[species] = true
      local chance = math.floor(weights[species] * 100 / total + 0.5)
      local row, odds = bySpecies[species]
      odds = row.methodSet[method]
      if odds then
        odds.min, odds.max = math.min(odds.min, chance), math.max(odds.max, chance)
      else
        odds = { name = method, min = chance, max = chance }
        row.methodSet[method] = odds
        row.methods[#row.methods + 1] = odds
      end
      if context then
        local range = levels[species]
        row.appearances[#row.appearances + 1] = {
          method = method, chance = chance, time = context.time,
          mapId = context.mapId, section = context.section,
          minLevel = range.min, maxLevel = range.max,
        }
      end
    end
  end
end

-- Host path [all games]: saved legacyFull settings still select Full Gear when no explicit current battle_ui mode exists.
local function battleUIMode(value, legacyFull)
  if value == "standard" or value == "gear" or value == "full" then
    return value
  end
  if legacyFull == true then return "full" end
  if value == true then return "gear" end
  return "standard"
end

local function checklistPages(sections)
  local out = {}
  for _, section in ipairs(sections) do
    local done = 0
    for _, row in ipairs(section.rows) do
      if row.done then done = done + 1 end
    end
    local perPage = section.perPage or 4
    local count = math.max(1, math.ceil(#section.rows / perPage))
    for page = 1, count do
      out[#out + 1] = { name = section.name, rows = section.rows,
        done = done, total = #section.rows, page = page, pages = count,
        perPage = perPage }
    end
  end
  return out
end

local function oneShotTrainerStatus(defeated, battled, result)
  if defeated or result == "win" then return true end
  if result == "lose" then return true, "LOST" end
  return battled or false
end

local function compactClock(value)
  return ((value or "--:--"):gsub("^0", ""):gsub("%s+", ""))
end

local function clockText(timestamp, format, systemValue)
  if format == "24" then return os.date("%H:%M", timestamp) end
  if format == "12" then
    local current = os.date("*t", timestamp)
    local hour = current.hour % 12
    if hour == 0 then hour = 12 end
    return ("%d:%02d%s"):format(hour, current.min,
      current.hour < 12 and "AM" or "PM")
  end
  return compactClock(systemValue)
end
  return addEncounters, battleUIMode, checklistPages, clockText, compactClock, oneShotTrainerStatus
end
