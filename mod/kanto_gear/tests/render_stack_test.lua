package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local gen = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local run = T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")),
  { generation = gen, data = T.fixtures.load() })
local function hook(name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
  error("missing hook " .. name)
end
local function up(fn, key, replacement)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, i)
    if name == key then
      if replacement ~= nil then debug.setupvalue(fn, i, replacement) end
      return value
    end
  end
  error("missing upvalue " .. key)
end
local display = up(hook("input.step"), "displayRuntime")
local draw = up(hook("render.output"), "draw")
local G = love.graphics
local push, pop, getDepth = G.push, G.pop, G.getStackDepth
local depth, peak = 3, 3 -- unrelated host/mod scopes must survive our cleanup
G.getStackDepth = function() return depth end
G.push = function()
  assert(depth < 128, "Maximum stack depth reached")
  depth = depth + 1; peak = math.max(peak, depth)
end
G.pop = function() assert(depth > 3, "popped caller scope"); depth = depth - 1 end
local sentinel = "injected sprite draw failure"
display.prepareMotion, display.applyMotion = function() end, function() end
display.drawContents = function()
  G.push(); G.push(); error(sentinel, 0)
end
local balanced, originalErrors = true, true
for _ = 1, 300 do
  local ok, err = pcall(draw)
  balanced = balanced and depth == 3
  originalErrors = originalErrors and not ok and err == sentinel
end
T.check(balanced, "300 failed nested draws preserve the caller's stack depth")
T.check(originalErrors, "the initial drawing error remains visible instead of a later overflow")
T.eq(peak, 6, "failed frames do not accumulate graphics stack entries")

-- Both combined-screen seams use the same protected draw, before presentation.
run.loader.modOptions.kanto_gear = { display_mode = "combined" }
up(hook("render.output"), "active", true)
local theme = up(hook("render.viewport"), "THEME")
local surface = G.newCanvas(640, 480)
for _, seam in ipairs({ "render.output", "render.window" }) do
  theme.nativeWindowLayout = seam == "render.window"
    and { showGame = true, showGear = true, gear = {x=0,y=0,w=240,h=216} } or nil
  up(hook("render.output"), "dirty", true)
  local calls = 0
  local function next() calls = calls + 1; return false end
  local context = { canvas = surface, width = 640, height = 480 }
  local ok, err
  if seam == "render.window" then ok, err = pcall(hook(seam), next, {}, context)
  else ok, err = pcall(hook(seam), next, context) end
  T.check(not ok and err == sentinel, seam .. " preserves the original failure")
  T.eq(depth, 3, seam .. " restores the graphics stack on failure")
  T.eq(calls, 1, seam .. " calls the downstream renderer once")
end
display.drawContents = function() G.push(); G.pop() end
T.check(pcall(draw), "a healthy frame can render after a failed frame")
T.eq(depth, 3, "successful frames also preserve caller scopes")
display.drawContents = function() G.push() end
T.check(pcall(draw), "an accidentally unclosed draw scope is contained")
T.eq(depth, 3, "unclosed scopes cannot leak even without an exception")
G.push, G.pop, G.getStackDepth = push, pop, getDepth
run.release()
T.finish("Kanto Gear render stack Gen " .. gen)
