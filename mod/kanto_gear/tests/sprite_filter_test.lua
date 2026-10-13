local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local Filter = assert(loadfile(root .. "/core/sprite_filter.lua"))()
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
check(filter:draw(image, 8, 9, 0.5), "small portraits use sharp texel sampling")
check(current == previous, "caller shader is restored")
check(draws[1][2] == 8 and draws[1][3] == 9 and draws[1][4] == 0.5,
  "filter keeps the exact portrait size and position")
check(shader.uniforms.sourceSize[1] == 64 and shader.uniforms.sourceSize[2] == 56,
  "texel sampling uses the native image dimensions")
check(shader.uniforms.paletted == false, "full-color art is not palette remapped")
local colors = { { 255, 255, 255 }, { 240, 16, 32 }, { 64, 128, 192 }, { 0, 0, 0 } }
check(filter:draw(image, 8, 9, 0.5, colors), "palette art uses its own colors")
check(shader.uniforms.paletted == true and shader.uniforms.pal1[2] == 16 / 255,
  "palette lookup keeps the supplied normal or shiny colors")
check(compiles == 1, "draws reuse the shader")
factor = 2
check(not filter:draw(image, 8, 9, 0.5), "an existing 2x render retains all native pixels")
factor = 1
local unavailable = Filter.new({ newShader = function() error("no shaders") end })
check(not unavailable:draw(image, 0, 0, 0.5), "unsupported GPU falls back to native rendering")
check(not unavailable:draw(image, 0, 0, 0.5), "unsupported GPU is not retried every frame")

-- Run with LÖVE as well: mocks cannot detect softened outlines or blended colors.
if love and love.getVersion then
  local gpu = love.graphics
  local sharp = Filter.new(gpu)
  local shiny = { { 255, 255, 255 }, { 16, 240, 32 }, { 192, 64, 128 }, { 0, 0, 0 } }
  for _, palette in ipairs({ false, colors, shiny }) do
    local data = love.image.newImageData(8, 8)
    for y = 0, 7 do
      for x = 0, 7 do
        local shade = (x + y * 2) % 4
        local c = colors[shade + 1]
        if palette then data:setPixel(x, y, 1 - shade / 3, 1 - shade / 3, 1 - shade / 3, (x + y) % 5 == 0 and 0 or 1)
        else data:setPixel(x, y, c[1] / 255, c[2] / 255, c[3] / 255, (x + y) % 5 == 0 and 0 or 1) end
      end
    end
    local portrait = gpu.newImage(data)
    portrait:setFilter("linear", "linear")
    for _, zoom in ipairs({ 1, 1.5 }) do
      for _, scale in ipairs({ 3 / 8, 4 / 8, 5 / 8, 7 / 8 }) do
        local physical = zoom * scale
        if physical < 1 then
          local ox, oy = 2.21, 3.17
          local target = gpu.newCanvas(16, 16, { msaa = 0 })
          gpu.push("all")
          gpu.setCanvas(target); gpu.origin(); gpu.setShader()
          gpu.clear(0, 0, 0, 0); gpu.setColor(1, 1, 1, 1)
          gpu.setBlendMode("replace"); gpu.scale(zoom)
          check(sharp:draw(portrait, ox, oy, scale, palette or nil), "GPU uses sharp minification")
          gpu.pop()
          local pixels = target:newImageData()
          local opaque, transparent = 0, 0
          for y = 0, 15 do
            for x = 0, 15 do
              local u, v = (x + 0.5 - ox * zoom) / physical, (y + 0.5 - oy * zoom) / physical
              if u >= 0 and u < 8 and v >= 0 and v < 8 then
                local ix, iy = math.floor(u), math.floor(v)
                local r, g, b, a = pixels:getPixel(x, y)
                local expectedAlpha = (ix + iy) % 5 == 0 and 0 or 1
                check(math.abs(a - expectedAlpha) < 1 / 255, string.format(
                  "small sprite keeps hard alpha edges: target %d,%d source %.6f,%.6f zoom %g scale %g alpha %g expected %g",
                  x, y, u, v, zoom, scale, a, expectedAlpha))
                if expectedAlpha == 1 then
                  opaque = opaque + 1
                  local c = (palette or colors)[(ix + iy * 2) % 4 + 1]
                  check(math.abs(r - c[1] / 255) < 1 / 255 and math.abs(g - c[2] / 255) < 1 / 255
                    and math.abs(b - c[3] / 255) < 1 / 255, "small sprite retains exact native or palette colors")
                else transparent = transparent + 1 end
              end
            end
          end
          check(opaque > 0 and transparent > 0, "GPU case covers both visible and transparent texels")
          pixels:release(); target:release()
        end
      end
    end
    portrait:release(); data:release()
  end
end
print("PASS sharp sprite sampling: " .. checks .. " checks")
