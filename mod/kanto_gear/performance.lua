-- Diagnostic test-build recorder. Times are wall time spent in Lua/native
-- calls, not GPU execution time. Nested scopes must never be added together.
local Performance = {}
Performance.__index = Performance
local bounds = { 0.01, 0.025, 0.05, 0.1, 0.2, 0.4, 0.8, 1, 2, 4, 8,
  12, 16.7, 20, 25, 33.4, 50, 100, 250, 500, 1000, math.huge }
local names = { "frame_interval", "gear_compose", "gear_draw", "battle_snapshot",
  "tools", "home_data", "home_map", "home_explorer", "home_paint", "stamps_current", "stamps_album", "notes_flush",
  "readback_request", "readback_poll", "readback_sync", "present", "game_capture",
  "profile_log" }

local function reset(metric)
  metric.n, metric.total, metric.max = 0, 0, 0
  metric.over20, metric.over34, metric.over250 = 0, 0, 0
  for i = 1, #bounds do metric.bins[i] = 0 end
end

function Performance.new(clock, log, enabled)
  local self = setmetatable({ clock = clock, log = log, enabled = enabled == true,
    metrics = {}, pending = {}, nextLine = 1, sequence = 0,
    context = "startup", mixed = false, bytes = 0, presented = 0 }, Performance)
  for _, name in ipairs(names) do
    self.metrics[name] = { bins = {} }; reset(self.metrics[name])
  end
  return self
end

function Performance:start()
  if self.enabled then return self.clock() end
end

function Performance:elapsed(started)
  return started and math.max(0, self.clock() - started) or 0
end

function Performance:sample(name, milliseconds)
  if not self.enabled then return end
  local m = self.metrics[name]
  if not m or milliseconds < 0 or milliseconds ~= milliseconds then return end
  m.n, m.total = m.n + 1, m.total + milliseconds
  if milliseconds >= m.max then m.max, m.peakContext = milliseconds, self.context end
  if milliseconds > 20 then m.over20 = m.over20 + 1 end
  if milliseconds > 33.4 then m.over34 = m.over34 + 1 end
  if milliseconds > 250 then m.over250 = m.over250 + 1 end
  for i, bound in ipairs(bounds) do
    if milliseconds <= bound then m.bins[i] = m.bins[i] + 1; break end
  end
end

function Performance:finish(name, started, excluded)
  if started then self:sample(name, math.max(0, self.clock() - started - (excluded or 0)) * 1000) end
end

-- Only used for APIs with a single result. Disabled measurement preserves the
-- complete original return list and does not read the timer.
function Performance:call(name, fn, ...)
  if not self.enabled then return fn(...) end
  local started = self.clock()
  local result = fn(...)
  self:finish(name, started)
  return result
end

function Performance:present(fn, image, width, height, ...)
  local result = self:call("present", fn, image, width, height, ...)
  if self.enabled and result == true then
    self.presented = self.presented + 1
    self.bytes = self.bytes + width * height * 4
  end
  return result
end

function Performance:setContext(context)
  if context ~= self.context then
    if self.since then self.mixed = true end
    self.context = context
  end
end

local function percentile(m, fraction)
  local count, target = 0, math.ceil(m.n * fraction)
  for i, bound in ipairs(bounds) do
    count = count + m.bins[i]
    if count >= target then return bound == math.huge and m.max or bound end
  end
end

function Performance:report(now)
  if not self.enabled or not self.since then return end
  -- At most one bounded report can be queued. Never accumulate stale reports
  -- if drawing is suspended, the app loses focus, or logging becomes slow.
  if self.nextLine <= #self.pending then return end
  self.sequence = self.sequence + 1
  local prefix = "KGPROF v=1 seq=" .. self.sequence
  local lines = { string.format(
    "%s kind=window at=%.3f seconds=%.3f mixed=%s frames=%d bytes=%.0f context=%s",
    prefix, now, now - self.since, tostring(self.mixed), self.presented, self.bytes, self.context) }
  for _, name in ipairs(names) do
    local m = self.metrics[name]
    if m.n > 0 then
      lines[#lines + 1] = string.format(
        "%s kind=metric name=%s n=%d mean=%.4f p95le=%.4f p99le=%.4f max=%.4f over20=%d over34=%d over250=%d peak=%s",
        prefix, name, m.n, m.total / m.n, percentile(m, 0.95), percentile(m, 0.99),
        m.max, m.over20, m.over34, m.over250, m.peakContext)
    end
    reset(m)
  end
  lines[1] = lines[1] .. " metrics=" .. (#lines - 1)
  lines[#lines + 1] = prefix .. " kind=end"
  self.pending, self.nextLine = lines, 1
  self.since, self.mixed, self.bytes, self.presented = now, false, 0, 0
end

function Performance:frame()
  if not self.enabled then return end
  local now = self.clock()
  if self.lastFrame then self:sample("frame_interval", math.max(0, now - self.lastFrame) * 1000) end
  self.lastFrame, self.since = now, self.since or now
  if now - self.since >= 10 then self:report(now) end
  -- One short log line per rendered frame, with its own cost recorded. No
  -- sorting, per-frame strings, file writes, or forced GPU/GC synchronization.
  local line = self.pending[self.nextLine]
  if line then
    self.nextLine = self.nextLine + 1
    local started = self.clock()
    self.log(line)
    self:finish("profile_log", started)
  end
end

return Performance
