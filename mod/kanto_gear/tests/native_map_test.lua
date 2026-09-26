-- Run from the host checkout; no extracted assets are required.
local T = require("tests.modkit")
local Map = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/native_map.lua"))()
local built, released, draws = 0, 0, {}
local G = { setColor = function() end }
function G.newSpriteBatch(image, capacity)
  built = built + 1
  local b = { image = image, entries = {}, capacity = capacity }
  function b:add(...) self.entries[#self.entries + 1] = {...} end
  function b:flush() end
  function b:release() released = released + 1 end
  return b
end
function G.draw(...) draws[#draws + 1] = {...} end
local q0, q1, q2, atlas = {}, {}, {}, {}
local source = { image = atlas, quads = { [0] = q0, q1, q2 },
  aliasMap = { [0] = { [0] = 2 } }, trueColor = true,
  win = { untouched = true } }
local blocks = { [1] = {} }
for i = 1, 16 do blocks[1][i] = (i - 1) % 2 end
local map = { id = "TEST", widthCells = 2, heightCells = 2,
  tileset = { blocks = blocks }, renderer = source, blockAt = function() return 0 end }
local world = { map = map }
local r = Map.new(G)
T.check(r:prepare(world, {}, false), "native Gen1 geometry is available")
T.eq(#r.batch.entries, 16, "each original tile is retained")
T.eq(r.batch.entries[1][1], q2, "host palette alias geometry is preserved")
T.eq(r.batch.entries[16][2], 24, "last tile x position")
T.eq(r.batch.entries[16][3], 24, "last tile y position")
local window = source.win
for i = 1, 300 do r:draw(i / 4, -i / 8, 4) end
T.eq(built, 1, "movement never rebuilds terrain")
T.eq(source.win, window, "Gear never changes the host camera window")
T.eq(draws[#draws][5], 0.25, "draw scale uses 16px walking cells")
local oldRevision = r:revision()
source.quads = { [0] = q0, q1, q2 }
T.check(r:revision() ~= oldRevision, "host resource replacement is observable at rest")
r:prepare(world, {}, false)
T.eq(built, 2, "replacement quads rebuild owned geometry")
r:release(); blocks[1][2] = 2
r:prepare(world, {}, false)
T.eq(r.batch.entries[2][1], q2, "block invalidation reads the new terrain")
local canvas, nextCanvas = {}, {}
world.mapImage = canvas
T.check(r:prepare(world, {}, true), "Gen2 borrows the current map canvas")
local oldBuilt = built
r:draw(1, 2, 8)
T.eq(draws[#draws][1], canvas, "Gen2 draws the host canvas directly")
oldRevision = r:revision()
world.mapImage = nextCanvas
T.check(r:revision() ~= oldRevision, "palette/daytime/cut canvas replacement is observable")
r:draw(1, 2, 8)
T.eq(draws[#draws][1], nextCanvas, "Gen2 does not hold a stale map canvas")
T.eq(built, oldBuilt, "Gen2 adds no map geometry or texture allocation")
r:release()
T.eq(released, built, "only Gear batches are released exactly once")
T.check(not r:prepare({ map = {} }, {}, false), "incomplete/custom worlds retain legacy fallback")
T.check(not r:prepare({ map = map }, {}, true), "missing Gen2 canvas retains fallback")
T.finish("Native Gen1/2 minimap resources")
