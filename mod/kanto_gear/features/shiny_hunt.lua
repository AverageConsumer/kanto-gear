-- Shiny Hunt: one counter per target species, the odds that the count has
-- already bought, and a log of every shiny met. Pure data: the runtime feeds
-- it encounters and hatches it observed and stores what this returns in
-- playthrough storage, which a soft reset does not rewind. Nothing here
-- reads or writes the game.
local M = {}

M.FORMAT = 1
-- Gen 2 (four DVs in one pattern) and Gen 3 (TID ^ SID ^ PID < 8) share
-- the same full odds; Gen 2 eggs whose DV donor is shiny roll 1 in 64.
M.FULL_ODDS = 8192
M.BOOSTED_ODDS = 64
M.ANY = "*"
M.LOG_LIMIT = 60
M.HUNT_LIMIT = 24
-- Gaps longer than this between counted events are breaks, not hunting.
M.IDLE_GAP = 300

local floor, max, min, log = math.floor, math.max, math.min, math.log

local function key(species)
  if species == nil then return nil end
  return tostring(species)
end
M.key = key

local function int(value, fallback)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge or value == -math.huge then return fallback end
  return floor(value)
end

-- Gen 2 shininess: Defense, Speed and Special 10, Attack 2/3/6/7/10/11/14/15.
function M.gen2Shiny(dvs)
  if type(dvs) ~= "table" then return false end
  if dvs.defense ~= 10 or dvs.speed ~= 10 or dvs.special ~= 10 then return false end
  local attack = tonumber(dvs.attack) or 0
  return attack % 4 == 2 or attack % 4 == 3
end

local function newHunt(species, name, now)
  return {
    species = species, name = name, any = species == M.ANY or nil,
    battles = 0, hatches = 0, boosted = 0, manual = 0, others = 0, phases = 0,
    time = 0, startedAt = now, lastAt = nil,
  }
end

-- Encounters bought at full odds and at the boosted egg rate.
function M.count(hunt)
  if not hunt then return 0 end
  return max(0, (hunt.battles or 0) + (hunt.hatches or 0) + (hunt.boosted or 0) + (hunt.manual or 0))
end
local function fullRolls(hunt)
  return max(0, M.count(hunt) - (hunt and hunt.boosted or 0))
end

-- Probability that at least one roll so far was shiny.
function M.chance(hunt)
  if not hunt then return 0 end
  local miss = (1 - 1 / M.FULL_ODDS) ^ fullRolls(hunt) * (1 - 1 / M.BOOSTED_ODDS) ^ (hunt.boosted or 0)
  return max(0, min(1, 1 - miss))
end

-- Expected shinies so far; hunters call 8192 full-odds rolls "1x odds".
function M.oddsMultiple(hunt)
  if not hunt then return 0 end
  return fullRolls(hunt) / M.FULL_ODDS + (hunt.boosted or 0) / M.BOOSTED_ODDS
end

-- Rolls at full odds until the chance of having met one reaches `share`.
function M.milestone(share)
  return math.ceil(log(1 - share) / log(1 - 1 / M.FULL_ODDS))
end
M.MILESTONES = { 0.5, 0.75, 0.9, 0.95, 0.99 }

-- Counted rolls per hour of active hunting, once there is enough to tell.
function M.pace(hunt)
  if not hunt or (hunt.time or 0) < 60 or M.count(hunt) < 3 then return nil end
  return floor(M.count(hunt) * 3600 / hunt.time + 0.5)
end

function M.group(value)
  local text = tostring(int(value, 0))
  local sign, digits = text:match("^(-?)(%d+)$")
  if not digits then return text end
  local out = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return sign .. out:gsub("^,", "")
end

-- "0.04%", "2.5%", "63%"; never rounds a miss up to a certainty.
function M.percent(share)
  share = max(0, min(1, tonumber(share) or 0))
  local value = share * 100
  if value >= 99.95 and share < 1 then return "99.9%" end
  if value >= 10 then return tostring(floor(value + 0.5)) .. "%" end
  if value >= 1 then return string.format("%.1f%%", floor(value * 10 + 0.5) / 10) end
  return string.format("%.2f%%", floor(value * 100 + 0.5) / 100)
end

function M.multipleLabel(value)
  value = max(0, tonumber(value) or 0)
  if value >= 10 then return tostring(floor(value + 0.5)) end
  return string.format("%.2f", floor(value * 100 + 0.5) / 100)
end

function M.duration(seconds)
  seconds = max(0, int(seconds, 0))
  local hours, minutes = floor(seconds / 3600), floor(seconds % 3600 / 60)
  return hours, minutes
end

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------
local function cleanHunt(raw)
  if type(raw) ~= "table" or raw.species == nil then return nil end
  local hunt = newHunt(raw.species, type(raw.name) == "string" and raw.name or nil, int(raw.startedAt, nil))
  for _, field in ipairs({ "battles", "hatches", "boosted", "manual", "others", "phases", "time" }) do
    hunt[field] = int(raw[field], 0)
  end
  for _, field in ipairs({ "battles", "hatches", "boosted", "others", "phases", "time" }) do
    hunt[field] = max(0, hunt[field])
  end
  hunt.lastAt = int(raw.lastAt, nil)
  if type(raw.found) == "table" then
    hunt.found = { species = raw.found.species, name = raw.found.name,
      count = int(raw.found.count, 0), at = int(raw.found.at, nil) }
  end
  return hunt
end

local function cleanEntry(raw)
  if type(raw) ~= "table" or raw.species == nil then return nil end
  local kind = raw.kind
  if kind ~= "target" and kind ~= "phase" and kind ~= "lucky" then kind = "lucky" end
  return { species = raw.species, name = type(raw.name) == "string" and raw.name or nil, kind = kind,
    count = int(raw.count, 0), at = int(raw.at, nil), via = raw.via == "egg" and "egg" or "battle",
    target = raw.target, targetName = type(raw.targetName) == "string" and raw.targetName or nil,
    place = type(raw.place) == "string" and raw.place or nil, first = raw.first == true or nil }
end

-- Stored state is validated field by field; anything unknown is dropped.
function M.normalize(raw)
  raw = type(raw) == "table" and raw or {}
  local state = { format = M.FORMAT, auto = raw.auto ~= false, hunts = {}, log = {} }
  local count, hunts = 0, type(raw.hunts) == "table" and raw.hunts or {}
  local function take(id, hunt)
    local clean = cleanHunt(hunt)
    if clean and key(clean.species) == tostring(id) and count < M.HUNT_LIMIT and not state.hunts[tostring(id)] then
      state.hunts[tostring(id)], count = clean, count + 1
    end
  end
  -- The active hunt is read first so a full shelf can never drop it.
  if type(raw.active) == "string" and hunts[raw.active] then take(raw.active, hunts[raw.active]) end
  for id, hunt in pairs(hunts) do take(id, hunt) end
  for _, entry in ipairs(type(raw.log) == "table" and raw.log or {}) do
    local clean = cleanEntry(entry)
    if clean and #state.log < M.LOG_LIMIT then state.log[#state.log + 1] = clean end
  end
  if type(raw.active) == "string" and state.hunts[raw.active] then state.active = raw.active end
  if type(raw.last) == "table" and raw.last.species ~= nil then
    state.last = { species = raw.last.species, name = type(raw.last.name) == "string" and raw.last.name or nil,
      shiny = raw.last.shiny == true, via = raw.last.via == "egg" and "egg" or "battle", at = int(raw.last.at, nil) }
  end
  state.encounters = max(0, int(raw.encounters, 0))
  -- Every shiny ever met in this playthrough; the log itself keeps 60.
  state.met = max(#state.log, int(raw.met, 0))
  return state
end

function M.active(state)
  return state and state.active and state.hunts[state.active] or nil
end

-- Oldest idle hunts make room once the shelf is full; the active one stays.
local function trimHunts(state)
  local ids, total = {}, 0
  for id in pairs(state.hunts) do
    total = total + 1
    if id ~= state.active then ids[#ids + 1] = id end
  end
  if total < M.HUNT_LIMIT then return end
  table.sort(ids, function(a, b)
    local ta = state.hunts[a].lastAt or state.hunts[a].startedAt or 0
    local tb = state.hunts[b].lastAt or state.hunts[b].startedAt or 0
    if ta ~= tb then return ta < tb end
    return a < b
  end)
  for index = 1, math.min(#ids, total - M.HUNT_LIMIT + 1) do state.hunts[ids[index]] = nil end
end

-- Choosing a species resumes its shelved counter; nothing is discarded.
function M.setTarget(state, species, name, now)
  local id = key(species)
  if not id then return nil end
  local hunt = state.hunts[id]
  if not hunt then
    trimHunts(state)
    hunt = newHunt(species, name, now)
    state.hunts[id] = hunt
  elseif name then
    hunt.name = name
  end
  state.active = id
  return hunt
end

function M.clearTarget(state) state.active = nil end

function M.remove(state, id)
  id = key(id)
  if not id or not state.hunts[id] then return false end
  state.hunts[id] = nil
  if state.active == id then state.active = nil end
  return true
end

-- After a find: the same target from zero, the find stays in the log.
function M.restart(state, now)
  local hunt = M.active(state)
  if not hunt then return nil end
  local fresh = newHunt(hunt.species, hunt.name, now)
  state.hunts[state.active] = fresh
  return fresh
end

local function addLog(state, entry)
  table.insert(state.log, 1, entry)
  while #state.log > M.LOG_LIMIT do table.remove(state.log) end
end

local function touch(hunt, now)
  if not now then return end
  local gap = hunt.lastAt and now - hunt.lastAt
  if gap and gap > 0 and gap <= M.IDLE_GAP then hunt.time = (hunt.time or 0) + gap end
  hunt.lastAt = now
end

local function matches(hunt, species)
  return hunt.any or key(hunt.species) == key(species)
end

-- event = { via = "battle" | "egg", species, name, shiny, boosted }
-- Returns what changed so the runtime can redraw and celebrate.
function M.observe(state, event, now)
  local out = { counted = false }
  if type(event) ~= "table" or event.species == nil then return out end
  local via = event.via == "egg" and "egg" or "battle"
  state.last = { species = event.species, name = event.name, shiny = event.shiny == true, via = via, at = now }
  if via == "battle" then state.encounters = (state.encounters or 0) + 1 end
  local hunt = M.active(state)
  if hunt and hunt.found then hunt = nil end
  local target = hunt and matches(hunt, event.species)
  if hunt and state.auto ~= false then
    if target then
      if via == "egg" then
        if event.boosted then hunt.boosted = hunt.boosted + 1 else hunt.hatches = hunt.hatches + 1 end
      else
        hunt.battles = hunt.battles + 1
      end
      out.counted = true
    elseif via == "battle" then
      hunt.others = hunt.others + 1
    end
    touch(hunt, now)
  end
  if event.shiny == true then
    -- Where it happened, and whether it is the first one of the playthrough:
    -- small things worth remembering.
    local entry = { species = event.species, name = event.name, at = now, via = via,
      place = type(event.place) == "string" and event.place ~= "" and event.place or nil,
      first = (state.met or 0) == 0 or nil }
    state.met = (state.met or 0) + 1
    if hunt and target then
      -- A find ends the hunt even while auto counting is paused.
      entry.kind, entry.count = "target", M.count(hunt)
      hunt.found = { species = event.species, name = event.name, count = entry.count, at = now }
      out.found = hunt
    elseif hunt then
      hunt.phases = hunt.phases + 1
      entry.kind, entry.count = "phase", M.count(hunt)
      entry.target, entry.targetName = hunt.species, hunt.name
      out.phase = entry
    else
      entry.kind, entry.count = "lucky", 0
      out.lucky = entry
    end
    addLog(state, entry)
    out.shiny = entry
  end
  return out
end

-- Manual +1 / -1 for what cannot be observed (gift Pokemon, a reset before
-- a battle). The count never drops below zero.
function M.adjust(state, delta, now)
  local hunt = M.active(state)
  if not hunt or hunt.found then return false end
  delta = int(delta, 0)
  if delta < 0 then delta = max(delta, -M.count(hunt)) end
  if delta == 0 then return false end
  hunt.manual = hunt.manual + delta
  if delta > 0 then touch(hunt, now) end
  return true
end

function M.setAuto(state, value) state.auto = value ~= false end

------------------------------------------------------------------------------
-- What the screens read
------------------------------------------------------------------------------
function M.method(hunt)
  if not hunt then return nil end
  local eggs = (hunt.hatches or 0) + (hunt.boosted or 0)
  local battles, manual = hunt.battles or 0, max(0, hunt.manual or 0)
  if eggs == 0 and battles == 0 and manual == 0 then return nil end
  if eggs >= battles and eggs >= manual then return "EGGS" end
  if battles >= manual then return "ENCOUNTERS" end
  return "MANUAL"
end

-- Full-odds rolls worth the same chance (boosted eggs weigh more).
function M.equivalent(hunt)
  local chance = M.chance(hunt)
  if chance <= 0 then return 0 end
  if chance >= 1 then return math.huge end
  return log(1 - chance) / log(1 - 1 / M.FULL_ODDS)
end

function M.nextMilestone(hunt)
  local chance = M.chance(hunt)
  for _, share in ipairs(M.MILESTONES) do
    if chance < share then return share, M.milestone(share) end
  end
end

function M.huntView(hunt)
  if not hunt then return nil end
  local chance = M.chance(hunt)
  local share, need = M.nextMilestone(hunt)
  return {
    species = hunt.species, name = hunt.name, any = hunt.any == true,
    count = M.count(hunt), countText = M.group(M.count(hunt)),
    battles = hunt.battles, hatches = hunt.hatches + hunt.boosted, boosted = hunt.boosted,
    manual = hunt.manual, others = hunt.others, phases = hunt.phases,
    all = hunt.battles + hunt.others,
    chance = chance, chanceText = M.percent(chance),
    multiple = M.oddsMultiple(hunt), multipleText = M.multipleLabel(M.oddsMultiple(hunt)),
    pace = M.pace(hunt), time = hunt.time or 0,
    method = M.method(hunt), found = hunt.found,
    nextShare = share, nextNeed = need, equivalent = M.equivalent(hunt),
    lastAt = hunt.lastAt, startedAt = hunt.startedAt,
  }
end

-- ctx: { now, boost (Gen 2 shiny parent text or nil), here (rate rows) }
function M.view(state, ctx)
  ctx = ctx or {}
  local active = M.active(state)
  local shelf = {}
  for id, hunt in pairs(state.hunts) do
    if id ~= state.active and (M.count(hunt) > 0 or hunt.found) then shelf[#shelf + 1] = M.huntView(hunt) end
  end
  table.sort(shelf, function(a, b)
    if (a.lastAt or 0) ~= (b.lastAt or 0) then return (a.lastAt or 0) > (b.lastAt or 0) end
    return tostring(a.species) < tostring(b.species)
  end)
  return {
    hunt = M.huntView(active), auto = state.auto ~= false, last = state.last,
    log = state.log, shelf = shelf, shinies = state.met or #state.log, encounters = state.encounters or 0,
    fullOdds = M.FULL_ODDS, boostedOdds = M.BOOSTED_ODDS,
  }
end

-- What the Home widgets lead with.
function M.headline(view)
  if not view or not view.hunt then return { kind = "idle" } end
  if view.hunt.found then return { kind = "found" } end
  if not view.auto then return { kind = "paused" } end
  return { kind = "hunting" }
end

return M
