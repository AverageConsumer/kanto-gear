-- Sample one native texel so small portraits keep sharp colors and outlines.
local Filter = {}
local SOURCE = [[
extern vec2 sourceSize;
extern bool paletted;
extern vec3 pal0;
extern vec3 pal1;
extern vec3 pal2;
extern vec3 pal3;

vec4 effect(vec4 tint, Image image, vec2 uv, vec2 screen) {
  uv = (clamp(floor(uv * sourceSize), vec2(0.0), sourceSize - 1.0) + 0.5) / sourceSize;
  vec4 px = Texel(image, uv);
  if (paletted) {
    float shade = floor((1.0 - px.r) * 3.0 + 0.5);
    px.rgb = shade > 2.5 ? pal3 : shade > 1.5 ? pal2 : shade > 0.5 ? pal1 : pal0;
  }
  return px * tint;
}
]]

function Filter.new(graphics)
  local self = { graphics = graphics, uniforms = {} }
  return setmetatable(self, { __index = Filter })
end

local function vector(self, key, a, b, c)
  local value = self.uniforms[key]
  if not value then value = {}; self.uniforms[key] = value end
  if value[1] ~= a or value[2] ~= b or value[3] ~= c then
    value[1], value[2], value[3] = a, b, c
    self.shader:send(key, value)
  end
end

local PALETTE_NAMES = { "pal0", "pal1", "pal2", "pal3" }
function Filter:draw(image, x, y, scale, colors)
  local G = self.graphics
  local sx, sy = scale, scale
  if G.transformPoint then
    local ax, ay = G.transformPoint(0, 0)
    local bx, by = G.transformPoint(scale, 0)
    local cx, cy = G.transformPoint(0, scale)
    sx, sy = math.sqrt((bx - ax)^2 + (by - ay)^2), math.sqrt((cx - ax)^2 + (cy - ay)^2)
  end
  -- Keep native pixels untouched when there is no minification.
  if sx >= 1 and sy >= 1 or sx <= 0 or sy <= 0 then return false end
  if self.shader == nil then
    local ok, shader = pcall(G.newShader, SOURCE)
    self.shader = ok and shader or false
  end
  local shader = self.shader
  if not shader then return false end
  local iw, ih = image:getDimensions()
  vector(self, "sourceSize", iw, ih)
  if self.paletted ~= (colors ~= nil) then
    self.paletted = colors ~= nil
    shader:send("paletted", self.paletted)
  end
  if colors then
    for i = 1, 4 do
      local c = colors[i]
      vector(self, PALETTE_NAMES[i], c[1] / 255, c[2] / 255, c[3] / 255)
    end
  end
  local previous = G.getShader()
  G.setShader(shader)
  G.draw(image, x, y, 0, scale, scale)
  G.setShader(previous)
  return true
end

return Filter
