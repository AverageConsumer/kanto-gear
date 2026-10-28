-- Gear notices: one short message at a time, shown when the screen is free.
-- Pure timing and queue rules; the runtime decides when the screen is free,
-- draws the card and plays the chime. Nothing here touches the game.
local M = {}

M.ENTER, M.SHOW, M.EXIT = 0.18, 3.5, 0.18
M.LIMIT = 6
M.HISTORY_LIMIT = 100

function M.new() return { queue = {}, unread = {}, unreadOnly = {}, serial = 0, history = {}, historyPage = 1 } end

-- Persist only presentation values. Native objects, callbacks and transient
-- gesture/timing state must never survive a save/session replacement.
local function historyTimestamp(value)
  local timestamp = tonumber(value)
  if timestamp and timestamp >= 0 and timestamp < 253402300800 then return math.floor(timestamp) end
end

local function historyEntry(value)
  if type(value) ~= "table" or type(value.title) ~= "string" then return end
  local out = {}
  for _, key in ipairs({ "title", "detail", "app", "page", "icon", "tone" }) do
    if type(value[key]) == "string" then out[key] = value[key]:sub(1, 512) end
  end
  if type(value.species) == "string" or type(value.species) == "number" then out.species = value.species end
  out.shiny = value.shiny == true
  out.read = value.read == true
  out.timestamp = historyTimestamp(value.timestamp)
  return out
end

function M.history(values)
  local out = {}
  if type(values) ~= "table" then return out end
  for index = math.max(1, #values - M.HISTORY_LIMIT + 1), #values do
    local entry = historyEntry(values[index])
    if entry then out[#out + 1] = entry end
  end
  return out
end

-- Called on first display, not on post: queued/merged/dropped cards have not
-- appeared yet. Array order remains authoritative even if the clock changes.
function M.remember(state, card, timestamp)
  if card.recorded then return false end
  local entry = historyEntry(card)
  if not entry then return false end
  card.recorded = true
  card.historyEntry = entry
  entry.timestamp = historyTimestamp(timestamp)
  state.history[#state.history + 1] = entry
  while #state.history > M.HISTORY_LIMIT do table.remove(state.history, 1) end
  return true
end

local function copy(notice)
  local out = {}
  for key, value in pairs(notice) do out[key] = value end
  return out
end

-- notice = { key, app, page, title, detail, species, icon, tone, urgent, show }
-- show: seconds the card stays fully in (M.SHOW when absent).
-- The same key merges into the waiting or showing card instead of stacking.
function M.post(state, notice, now)
  if type(notice) ~= "table" or not notice.title then return nil end
  local key = notice.key or notice.title
  local current = state.current
  if current and current.key == key then
    for field, value in pairs(notice) do current[field] = value end
    current.key = key
    -- A refreshed card stays up for its full time again.
    local t = now - current.shownAt
    if t > M.ENTER then current.shownAt = now - M.ENTER end
    return current
  end
  for _, waiting in ipairs(state.queue) do
    if waiting.key == key then
      for field, value in pairs(notice) do waiting[field] = value end
      waiting.key = key
      return waiting
    end
  end
  local entry = copy(notice)
  entry.key = key
  state.serial = state.serial + 1
  entry.id = state.serial
  state.queue[#state.queue + 1] = entry
  while #state.queue > M.LIMIT do table.remove(state.queue, 1) end
  return entry
end

function M.markUnread(state, app) if app then state.unread[app] = true end end
function M.markRead(state, app)
  if not app then return false end
  local changed = state.unread[app] == true
  for _, entry in ipairs(state.history) do
    if entry.app == app and not entry.read then entry.read, changed = true, true end
  end
  for _, card in ipairs(state.queue) do if card.app == app then card.read = true end end
  if state.current and state.current.app == app then state.current.read = true end
  state.unread[app] = nil
  state.unreadOnly[app] = nil
  return changed
end

-- Identity, not visible position: rows can move when the last page shrinks.
-- A read card cannot reappear behind the drawer when it closes.
function M.readHistory(state, entry)
  local found
  for index, candidate in ipairs(state.history) do
    if candidate == entry then table.remove(state.history, index); found = true; break end
  end
  if not found then return false end
  entry.read = true
  if state.current and state.current.historyEntry == entry then state.current = nil end
  local app = entry.app
  if app then
    local pending = state.unreadOnly[app] == true
    if state.current and state.current.app == app and not state.current.read then pending = true end
    for _, card in ipairs(state.queue) do if card.app == app and not card.read then pending = true end end
    for _, other in ipairs(state.history) do if other.app == app and not other.read then pending = true end end
    if not pending then state.unread[app] = nil end
  end
  return true
end

-- Ends the showing card and lets the next one in; `free` says whether the
-- screen can take a card now. Returns the showing card, if any.
function M.advance(state, now, free)
  local current = state.current
  if current and not current.heldAt and now - current.shownAt >= M.ENTER + (current.show or M.SHOW) + M.EXIT then
    state.current, current = nil, nil
  end
  if not current and free and #state.queue > 0 then
    current = table.remove(state.queue, 1)
    current.shownAt, current.fresh = now, true
    state.current = current
  end
  return current
end

-- 0 (hidden) .. 1 (fully in), for the slide and fade.
function M.presence(card, now)
  if not card then return 0 end
  now = card.heldAt or now
  local t = now - card.shownAt
  if t < 0 then return 0 end
  if t < M.ENTER then return t / M.ENTER end
  local show = card.show or M.SHOW
  if t < M.ENTER + show then return 1 end
  return math.max(0, 1 - (t - M.ENTER - show) / M.EXIT)
end

-- Tapped or swiped away: the card leaves now.
function M.dismiss(state, now, dx, dy)
  local current = state.current
  if not current then return false end
  local t = now - current.shownAt
  local show = current.show or M.SHOW
  if t < M.ENTER + show then current.shownAt = now - M.ENTER - show end
  current.closing = true
  if dx or dy then
    current.departure = { at = now, x = current.dragX or 0, y = current.dragY or 0,
      dx = dx or 0, dy = dy or 0 }
  end
  current.dragX, current.dragY, current.returning = nil, nil, nil
  return true
end

-- One geometry contract for drawing and hit testing. A swipe continues from
-- the finger's last position; an incomplete drag returns without snapping.
function M.offset(card, now, width, height, below, motion)
  if not card or motion == false then return 0, 0 end
  local function ease(t) return 1 - (1 - math.max(0, math.min(1, t))) ^ 3 end
  local leave = card.departure
  if leave then
    local p = ease((now - leave.at) / M.EXIT)
    local tx, ty = leave.x, leave.y
    if math.abs(leave.dx) >= math.abs(leave.dy) then
      tx = (leave.dx < 0 and -1 or 1) * (width + 12)
    else
      ty = leave.dy < 0 and -(height + 8) or below
    end
    return leave.x + (tx - leave.x) * p, leave.y + (ty - leave.y) * p
  end
  if card.dragX or card.dragY then return card.dragX or 0, card.dragY or 0 end
  if card.returning and now - card.returning.at < 0.12 then
    local p = 1 - ease((now - card.returning.at) / 0.12)
    return card.returning.x * p, card.returning.y * p
  end
  local p = M.presence(card, now)
  return 0, -(1 - p) ^ 2 * (height + 4)
end

function M.pending(state) return state.current ~= nil or #state.queue > 0 end

return M
