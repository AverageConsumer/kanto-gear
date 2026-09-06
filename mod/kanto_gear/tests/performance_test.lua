package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local Performance = assert(loadfile(path .. "/performance.lua"))()
local now, reads, lines = 0, 0, {}
local function clock() reads = reads + 1; return now end
local p = Performance.new(clock, function(line) lines[#lines + 1] = line end, false)
local result, second = p:call("tools", function(a) return a, 2 end, 1)
T.eq(result, 1, "disabled recording preserves the first return value")
T.eq(second, 2, "disabled recording preserves additional return values")
p:frame(); p:finish("tools", p:start())
T.eq(reads, 0, "disabled diagnostics never query the clock")
T.eq(#lines, 0, "disabled diagnostics never log")
p.enabled = true
p:setContext("gen2/HOME/world/hgss/gear-transfer/quality/ROUTE_30")
p:frame()
local m, bins = p.metrics.tools, p.metrics.tools.bins
result = p:call("tools", function(a) now = now + 0.004; return a end, 7)
T.eq(result, 7, "recording preserves API results")
T.eq(m.n, 1, "records one invocation")
T.check(math.abs(m.total - 4) < 0.00001, "records milliseconds rather than seconds")
local started = p:start()
now = now + 0.015
p:finish("gear_compose", started, 0.010)
T.check(math.abs(p.metrics.gear_compose.total - 5) < 0.00001,
  "downstream host time is excluded from Gear composition")
local ok = pcall(function() p:call("tools", function() error("expected") end) end)
T.eq(ok, false, "profiling never swallows an application failure")
T.eq(p:present(function() return false end, {}, 240, 216), false, "failed presentation stays failed")
T.eq(p.bytes, 0, "failed frames do not count as transferred")
T.eq(p:present(function(_, w, h, bg, mode)
  T.eq(bg, 42, "presentation preserves background")
  T.eq(mode, "secondary", "presentation preserves target")
  return w == 240 and h == 216
end, {}, 240, 216, 42, "secondary"), true, "presentation preserves the result")
T.eq(p.bytes, 240 * 216 * 4, "counts successful RGBA bytes")
T.eq(p.presented, 1, "counts successfully presented frames")
for _ = 1, 98 do p:sample("tools", 0.1) end
p:sample("tools", 37)
p:sample("tools", 400)
p:sample("tools", -1)
p:sample("tools", 0 / 0)
T.eq(m.n, 101, "invalid measurements do not contaminate statistics")
T.eq(m.over34, 2, "counts slow calls")
T.eq(m.over250, 1, "long stalls remain visible")
T.eq(p.metrics.tools, m, "sampling reuses metric storage")
T.eq(m.bins, bins, "sampling reuses histogram storage")
now = 10
p:frame()
T.eq(#lines, 1, "reporting emits only one log line per frame")
T.check(lines[1]:find("bytes=207360", 1, true), "window includes real transfer volume")
local queued = p.pending
p:report(20)
T.eq(p.pending, queued, "unfinished report cannot create an unbounded queue")
for _ = 1, #queued do now = now + 1 / 60; p:frame() end
local metric
for _, line in ipairs(lines) do if line:find("name=tools ", 1, true) then metric = line end end
T.check(metric and metric:find("p95le=0.1000", 1, true), "percentile is a documented bucket upper bound")
T.check(metric and metric:find("p99le=50.0000", 1, true), "tail quantile uses the correct rank")
T.check(metric and metric:find("max=400.0000", 1, true), "maximum is exact rather than bucketed")
T.eq(m.n, 0, "window resets measurement counts")
T.eq(m.bins, bins, "window resets bins in place")
T.check(p.metrics.profile_log.n > 0, "logging overhead is measured separately")
p:setContext("gen2/ACHIEVEMENTS/world/hgss/gear-transfer/quality/ROUTE_30")
T.eq(p.mixed, true, "mixed screen windows are explicitly marked")
T.finish("Kanto Gear performance recorder")
