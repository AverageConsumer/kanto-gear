local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local Filter = assert(loadfile(path .. "/core/image_filter.lua"))()
for _, scale in ipairs({ 1, 2, 3, 5, 8 }) do assert(Filter.resolve("auto", scale, scale) == "nearest") end
for _, scale in ipairs({ 1.00001, 1.25, 1.5, 2.222222, 4.5, 4.99999 }) do
  assert(Filter.resolve("auto", scale, scale) == "sharp")
end
for _, scale in ipairs({ .25, .75, .99999 }) do assert(Filter.resolve("auto", scale, scale) == "bilinear") end
for _, choice in ipairs({ "nearest", "bilinear", "sharp" }) do
  for _, scale in ipairs({ .75, 1, 4.5, 5 }) do assert(Filter.resolve(choice, scale, scale) == choice) end
end
assert(Filter.resolve("auto", 5, 4.5) == "sharp")
assert(Filter.resolve("auto", .75, 1) == "bilinear")
local log, filter, shader = {}, { "nearest", "nearest" }, "previous"
local image = {
  getWidth = function() return 240 end, getHeight = function() return 216 end,
  getFilter = function() return unpack(filter) end,
  setFilter = function(_, a, b) filter = { a, b } end,
}
local made = 0
local G = {
  newShader = function() made = made + 1; return { send = function() end } end,
  getShader = function() return shader end, setShader = function(value) shader = value end,
  draw = function() log[#log + 1] = { shader = shader, min = filter[1] } end,
}
Filter.draw(G, image, 0, 0, 5, 5, "auto")
assert(log[1].shader == nil and log[1].min == "nearest" and made == 0)
Filter.draw(G, image, 0, 0, 4.5, 4.5, "auto")
Filter.draw(G, image, 0, 0, 2.5, 2.5, "sharp")
assert(made == 1 and log[2].min == "linear" and log[2].shader ~= nil)
Filter.draw(G, image, 0, 0, .75, .75, "auto")
assert(log[4].shader == nil and log[4].min == "linear")
assert(shader == "previous" and filter[1] == "nearest" and filter[2] == "nearest")
print("image filters: actual-scale Auto, manual overrides, retained shader and state restoration passed")
