local root = os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local Map = assert(loadfile(root .. "/gen3_map.lua"))()
local builds, releases, draws, flushes = 0, 0, 0, 0
local texture = { name = "under" }
local atlas = { image = texture, overImage = { name = "over" }, layered = true }
local graphics = {
  newSpriteBatch = function(image, capacity, usage)
    builds = builds + 1
    assert(usage == "static")
    return { image = image, capacity = capacity, rows = {}, add = function(self, q, x, y)
      self.rows[#self.rows + 1] = { q, x, y }
    end, flush = function() flushes = flushes + 1 end,
    release = function() releases = releases + 1 end }
  end,
  draw = function(batch, x, y, _, sx, sy)
    draws = draws + 1
    assert(sx == sy and x == 7 and y == 53)
    assert(batch.image == atlas.image or batch.image == atlas.overImage)
  end,
}
local tilesets = { get = function() return atlas end,
  hasMid = function(_, mid) return mid >= 0 and mid < 20 end,
  slotFor = function(_, mid) return mid end,
  quad = function(_, slot) return slot end,
  overQuad = function(_, slot) return slot end }
local calls = 0
local layout = { width = 3, height = 2, trueWidth = 2, trueHeight = 2,
  cells = { 1, 2, 19, 3, 4, 19 }, overrides = {},
  midAt = function(self, x, y)
    calls = calls + 1
    local ov = self.overrides[y * 1024 + x]
    return ov and ov.mid or self.cells[y * self.width + x + 1]
  end }
local def = { pair = "test", midLayout = layout }
local renderer = Map.new(graphics, tilesets)
assert(renderer:prepare(def))
assert(calls == 4 and builds == 2 and flushes == 2)
assert(renderer.under.rows[4][1] == 4 and renderer.under.rows[4][2] == 16)
-- Player movement / scale changes cost two GPU draws, no tile scan or rebuild.
for i = 1, 120 do assert(renderer:prepare(def)); assert(renderer:draw(7, 53, i % 4 + 1)) end
assert(calls == 4 and builds == 2 and flushes == 2 and draws == 240)
layout.overrides[0] = { mid = 7 }
assert(renderer:prepare(def) and renderer.under.rows[1][1] == 7)
assert(releases == 2 and calls == 8)
layout.overrides[0].mid = 8
assert(renderer:prepare(def) and renderer.under.rows[1][1] == 8)
layout.overrides = {}
assert(renderer:prepare(def) and renderer.under.rows[1][1] == 1)
atlas.image = { name = "replacement" }
assert(renderer:prepare(def) and renderer.under.image == atlas.image)
-- A reloaded layout of the same size and a replaced cells buffer both rebuild.
layout.cells = { 5, 6, 19, 7, 8, 19 }
assert(renderer:prepare(def) and renderer.under.rows[1][1] == 5)
assert(layout.overrides[0] == nil and layout.cells[1] == 5)
layout.overrides[0] = { mid = 999 }
local ok, err = renderer:prepare(def)
assert(not ok and err:find("metatile missing") and not renderer:draw(7, 53, 4))
assert(builds == releases, "failure releases owned batches only")
assert(not renderer:prepare({}))
renderer:release()
renderer:release()
assert(builds == releases, "release is idempotent")
print("Gen3 map: geometry reuse, overrides, atlas replacement and resource lifetime passed")
