-- Gear notices: one short message at a time, shown when the screen is free.
-- Pure timing and queue rules; the runtime decides when the screen is free,
-- draws the card and plays the chime. Nothing here touches the game.
local M = {}

M.ENTER, M.SHOW, M.EXIT = 0.18, 3.5, 0.18
M.LIMIT = 6

function M.new() return { queue = {}, unread = {}, serial = 0 } end

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
  if not app or not state.unread[app] then return false end
  state.unread[app] = nil
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
