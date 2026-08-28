local root = assert(os.getenv("KANTO_GEAR_ROOT"), "KANTO_GEAR_ROOT is missing")
local output = assert(os.getenv("KANTO_GEAR_PREVIEW_OUT"),
  "KANTO_GEAR_PREVIEW_OUT is missing")

function love.errorhandler(message)
  local file = io.open(output .. ".error.txt", "wb")
  if file then
    file:write(debug.traceback(tostring(message), 2))
    file:close()
  end
  love.event.quit(1)
  return function() return 1 end
end

local function color(value) love.graphics.setColor(value) end
local function box(mode, x, y, w, h, tint)
  color(tint)
  love.graphics.rectangle(mode, x, y, w, h)
end
local function glyphs(value)
  local out = {}
  for char in tostring(value):gmatch(".") do out[#out + 1] = char end
  return out
end
local function fit(value, limit)
  value = tostring(value or "")
  if #glyphs(value) <= limit then return value end
  return value:sub(1, math.max(1, limit - 1)) .. "~"
end
local function text(value, x, y, tint)
  color(tint)
  love.graphics.print(value, x, y)
end

local party = {
  { name = "FERALIGATR", levelText = "L35", hp = 92, maxHp = 117,
    hpText = "92/117", status = "PAR", gender = "male" },
  { name = "JUMPLUFF", levelText = "L28", hp = 90, maxHp = 90,
    hpText = "90/90", gender = "female" },
  { name = "PIDGEOTTO", levelText = "L28", hp = 81, maxHp = 81,
    hpText = "81/81", gender = "male" },
  { name = "SANDSLASH", levelText = "L25", hp = 67, maxHp = 80,
    hpText = "67/80", gender = "male" },
  { name = "DROWZEE", levelText = "L16", hp = 0, maxHp = 49,
    hpText = "0/49", status = "FNT", gender = "female" },
  { name = "TAUROS", levelText = "L16", hp = 17, maxHp = 51,
    hpText = "17/51", status = "SLP", gender = "male" },
}

local crops = {
  { 70, 195 }, { 665, 235 }, { 70, 455 },
  { 660, 495 }, { 70, 720 }, { 665, 755 },
}

function love.load()
  local chunk = assert(loadfile(root .. "/mod/kanto_gear/hgss.lua"))
  local theme = chunk()({
    graphics = love.graphics, box = box, text = text,
    fit = fit, glyphs = glyphs, color = color,
  })
  local source = love.graphics.newImage("local/party-source.png")
  source:setFilter("nearest", "nearest")
  local canvas = love.graphics.newCanvas(240, 216, { dpiscale = 1 })
  canvas:setFilter("nearest", "nearest")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(theme.colors.bg)
  box("fill", 0, 0, 240, 27, theme.colors.surface)
  box("fill", 0, 26, 240, 2, theme.colors.ink)
  theme:label("<", 6, 7, theme.colors.ink)
  theme:label("PARTY", 51, 7, theme.colors.ink)
  theme:label("> 20:04 N", 127, 7, theme.colors.ink)
  for slot, mon in ipairs(party) do
    local x, y = theme:partyPosition(slot)
    theme:partyCard(mon, x, y, slot == 1, true,
      function(_, portraitX, portraitY, size)
        local crop = crops[slot]
        local quad = love.graphics.newQuad(crop[1], crop[2], 150, 150,
          source:getDimensions())
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(source, quad, portraitX, portraitY, 0,
          size / 150, size / 150)
      end)
  end
  love.graphics.setCanvas()
  local preview = love.graphics.newCanvas(960, 864, { dpiscale = 1 })
  preview:setFilter("nearest", "nearest")
  love.graphics.setCanvas(preview)
  love.graphics.clear(0.05, 0.06, 0.07, 1)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, 0, 0, 0, 4, 4)
  love.graphics.setCanvas()
  local data = preview:newImageData():encode("png")
  local file = assert(io.open(output, "wb"))
  file:write(data:getString())
  file:close()
  love.event.quit()
end
