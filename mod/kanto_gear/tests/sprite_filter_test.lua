local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local Filter = assert(loadfile(root .. "/sprite_filter.lua"))()
local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
local shader, previous = { uniforms = {} }, {}
function shader:send(key, value) self.uniforms[key] = value end
local current, draws, compiles, factor = previous, {}, 0, 1
local G = {
  newShader = function() compiles = compiles + 1; return shader end,
  getShader = function() return current end,
  setShader = function(value) current = value end,
  transformPoint = function(x, y) return x * factor, y * factor end,
  draw = function(image, x, y, rotation, sx, sy)
    draws[#draws + 1] = { image, x, y, sx, sy, current }
  end,
}
local image = { getDimensions = function() return 64, 56 end }
local filter = Filter.new(G)
check(not filter:draw(image, 8, 9, 1), "native-size pixels stay unchanged")
check(compiles == 0, "no shader compilation for unfiltered sprites")
check(filter:draw(image, 8, 9, 0.5), "small portraits use coverage filtering")
check(current == previous, "caller shader is restored")
check(draws[1][2] == 8 and draws[1][3] == 9 and draws[1][4] == 0.5,
  "filter keeps the exact portrait size and position")
check(shader.uniforms.footprint[1] == 2 and shader.uniforms.sourceSize[2] == 56,
  "sample footprint matches source and target pixels")
check(shader.uniforms.paletted == false, "full-color art is not palette remapped")
local colors = { { 255, 255, 255 }, { 240, 16, 32 }, { 64, 128, 192 }, { 0, 0, 0 } }
check(filter:draw(image, 8, 9, 0.5, colors), "palette art is filtered separately")
check(shader.uniforms.paletted == true and shader.uniforms.pal1[2] == 16 / 255,
  "palette lookup happens before averaging")
check(compiles == 1, "draws reuse the shader")
factor = 2
check(not filter:draw(image, 8, 9, 0.5), "an existing 2x render retains all native pixels")
factor = 1
local unavailable = Filter.new({ newShader = function() error("no shaders") end })
check(not unavailable:draw(image, 0, 0, 0.5), "unsupported GPU falls back to native rendering")
check(not unavailable:draw(image, 0, 0, 0.5), "unsupported GPU is not retried every frame")
print("PASS sprite coverage filter: " .. checks .. " checks")
