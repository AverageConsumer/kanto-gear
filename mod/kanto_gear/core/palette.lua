return function(THEME, render)
local RADAR_RED = { 220 / 255, 38 / 255, 28 / 255, 1 }

local MAP_EXIT = { 0.20, 0.65, 1, 1 }

local MAP_ITEM = { 1, 0.72, 0.10, 1 }

local MAP_HIDDEN = { 0.90, 0.30, 0.85, 1 }

THEME.localMap = {
  [" "] = {
    { 0.81, 0.84, 0.82, 1 }, { 0.56, 0.61, 0.60, 1 },
    { 0.27, 0.32, 0.35, 1 }, { 0.09, 0.14, 0.18, 1 },
  },
  ["."] = {
    { 0.90, 0.96, 0.72, 1 }, { 0.65, 0.84, 0.42, 1 },
    { 0.30, 0.54, 0.28, 1 }, { 0.11, 0.25, 0.22, 1 },
  },
  ["~"] = {
    { 0.84, 0.96, 0.95, 1 }, { 0.47, 0.81, 0.84, 1 },
    { 0.21, 0.51, 0.72, 1 }, { 0.10, 0.24, 0.44, 1 },
  },
  ["+"] = {
    { 0.98, 0.91, 0.64, 1 }, { 0.94, 0.78, 0.36, 1 },
    { 0.69, 0.43, 0.20, 1 }, { 0.35, 0.23, 0.16, 1 },
  },
  border = { 0.06, 0.10, 0.14, 1 },
  player = { 0.91, 0.14, 0.12, 1 },
  playerCore = { 1, 0.96, 0.76, 1 },
}

local CHOICE_QUIET = 0.32

render.SECONDARY_BACKGROUND = nil

local PC_LIST_KINDS = {
  pc_box_withdraw = true, pc_box_deposit = true,
  pc_box_release = true, pc_box_change = true,
  pc_item_withdraw = true, pc_item_deposit = true, pc_item_toss = true,
}

local function rowsContract(rows)
  if type(rows) ~= "table" then return false end
  for _, row in ipairs(rows) do
    if type(row) ~= "table" then return false end
  end
  return true
end

local function validPalette(palette)
  if type(palette) ~= "table" then return false end
  for i = 1, 4 do
    local color = palette[i]
    if type(color) ~= "table" or type(color[1]) ~= "number"
        or type(color[2]) ~= "number" or type(color[3]) ~= "number" then
      return false
    end
  end
  return true
end

local function inverted(palette)
  return { palette[4], palette[3], palette[2], palette[1] }
end

local function luma(color)
  return color[1] * 0.2126 + color[2] * 0.7152 + color[3] * 0.0722
end

local function rgba(color)
  return { color[1] / 255, color[2] / 255, color[3] / 255, 1 }
end

local function rgb24(color)
  return math.floor(color[1]) * 0x10000
       + math.floor(color[2]) * 0x100
       + math.floor(color[3])
end

local function fillerColor(palette)
  if luma(palette[1]) < luma(palette[4]) then return palette[2] end
  local darkest = palette[4]
  return math.max(darkest[1], darkest[2], darkest[3]) < 48
    and palette[3] or darkest
end

local function usePalette(palette, normalizedBackground)
  palette = validPalette(palette) and palette or THEME.classic
  render.PAPER, render.MID, render.DARK, render.INK = rgba(palette[1]), rgba(palette[2]),
                           rgba(palette[3]), rgba(palette[4])
  local background = normalizedBackground and {
    normalizedBackground[1] * 255 + 0.5,
    normalizedBackground[2] * 255 + 0.5,
    normalizedBackground[3] * 255 + 0.5,
  } or fillerColor(palette)
  render.SECONDARY_BACKGROUND = rgb24(background)
end

usePalette(THEME.classic)
  return CHOICE_QUIET, MAP_EXIT, MAP_HIDDEN, MAP_ITEM, PC_LIST_KINDS, RADAR_RED, fillerColor, inverted, rgb24, rowsContract, usePalette, validPalette
end
