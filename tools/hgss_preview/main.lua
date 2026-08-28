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
    hpText = "92/117", status = "PAR", gender = "male", type = "WATER",
    type2 = "WATER",
    expProgress = 0.72 },
  { name = "JUMPLUFF", levelText = "L28", hp = 90, maxHp = 90,
    hpText = "90/90", gender = "female", type = "GRASS", type2 = "FLYING",
    expProgress = 0.18 },
  { name = "PIDGEOTTO", levelText = "L28", hp = 81, maxHp = 81,
    hpText = "81/81", gender = "male", type = "NORMAL", type2 = "FLYING",
    expProgress = 0.91 },
  { name = "SANDSLASH", levelText = "L25", hp = 67, maxHp = 80,
    hpText = "67/80", gender = "male", type = "GROUND", type2 = "GROUND",
    expProgress = 0.47 },
  { name = "DROWZEE", levelText = "L16", hp = 0, maxHp = 49,
    hpText = "0/49", status = "FNT", gender = "female", type = "PSYCHIC",
    type2 = "PSYCHIC",
    expProgress = 0.33 },
  { name = "TAUROS", levelText = "L16", hp = 17, maxHp = 51,
    hpText = "17/51", status = "SLP", gender = "male", type = "NORMAL",
    type2 = "NORMAL",
    expProgress = 0.62 },
}

local species = { 160, 189, 17, 28, 96, 128 }

local function fileData(path, name)
  local file = assert(io.open(path, "rb"))
  local bytes = file:read("*a")
  file:close()
  return love.filesystem.newFileData(bytes, name)
end

local function spriteView(data)
  local width, height = data:getDimensions()
  local left, top, right, bottom = width, height, 0, 0
  for y = 0, height - 1 do
    for x = 0, width - 1 do
      local _, _, _, alpha = data:getPixel(x, y)
      if alpha > 0.05 then
        left, top = math.min(left, x), math.min(top, y)
        right, bottom = math.max(right, x), math.max(bottom, y)
      end
    end
  end
  return love.graphics.newQuad(left, top, right - left + 1, bottom - top + 1,
    width, height), right - left + 1, bottom - top + 1
end

function love.load()
  local chunk = assert(loadfile(root .. "/mod/kanto_gear/hgss.lua"))
  local fontPath = os.getenv("KANTO_GEAR_PREVIEW_FONT")
    or root .. "/mod/kanto_gear/rounded_mplus.ttf"
  local font = fileData(fontPath, "preview.ttf")
  local theme = chunk()({
    graphics = love.graphics, box = box, text = text,
    fit = fit, glyphs = glyphs, color = color, font = font,
  })
  assert(theme:statusColor("FNT") ~= theme:statusColor("SLP"),
    "fainted and sleep status colors must stay distinct")
  local sprites = {}
  for slot, id in ipairs(species) do
    local data = love.image.newImageData("local/" .. id .. ".png")
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    local quad, width, height = spriteView(data)
    sprites[slot] = { image = image, quad = quad, width = width, height = height }
  end
  local canvas = love.graphics.newCanvas(240, 216, { dpiscale = 1 })
  canvas:setFilter("nearest", "nearest")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(theme.colors.bg)
  love.graphics.push()
  love.graphics.scale(1.5, 1.5)
  box("fill", 0, 0, 160, 20, theme.colors.surface)
  box("fill", 0, 18, 160, 1, theme.colors.silver)
  box("fill", 0, 19, 160, 1, theme.colors.ink)
  love.graphics.pop()
  theme:label("<", 6, 6, theme.colors.ink)
  local title = "PARTY"
  theme:label(title, 72 - math.floor(theme:labelWidth(title) / 2), 6,
    theme.colors.ink)
  theme:label(">", 127.5, 6, theme.colors.ink)
  theme:headerClock("20:04", os.getenv("KANTO_GEAR_PREVIEW_PERIOD") or "NITE",
    141, 67.5, 6)
  theme:battery(215, 9, 3, true, theme.colors.ink)
  theme:partyBackdrop()
  for slot, mon in ipairs(party) do
    local x, y = theme:partyPosition(slot)
    theme:partyCard(mon, x, y, slot == 1, true,
      function(_, portraitX, portraitY, size, fainted)
        local sprite = sprites[slot]
        local scale = size / math.max(sprite.width, sprite.height)
        local brightness = fainted and 0.48 or 1
        love.graphics.setColor(brightness, brightness, brightness, 1)
        love.graphics.draw(sprite.image, sprite.quad,
          portraitX + (size - sprite.width * scale) / 2,
          portraitY + (size - sprite.height * scale) / 2, 0, scale, scale)
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
