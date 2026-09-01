local WIDTH, HEIGHT = 160, 144
local HEADER = 20
local STRING_PREFIX = "kanto_gear|"
local G

local INK, DARK, MID, PAPER
local THEME = {
  style = "classic",
  hgssScale = 1.5,
  classic = {
    { 155, 188, 15 }, { 139, 172, 15 }, { 48, 98, 48 }, { 15, 56, 15 },
  },
  light = {
    { 248, 249, 252 }, { 222, 226, 235 }, { 39, 45, 58 }, { 12, 15, 22 },
  },
  dark = {
    { 12, 15, 22 }, { 31, 37, 50 }, { 190, 198, 212 }, { 245, 247, 251 },
  },
  red = { 227 / 255, 27 / 255, 35 / 255, 1 },
  blue = { 52 / 255, 53 / 255, 143 / 255, 1 },
  white = { 248 / 255, 249 / 255, 252 / 255, 1 },
  batteryGreen = { 0.20, 0.72, 0.34, 1 },
  batteryAmber = { 0.96, 0.62, 0.12, 1 },
}

THEME.highCritMoves = {
  CRABHAMMER = true, KARATE_CHOP = true, RAZOR_LEAF = true, SLASH = true,
}

THEME.moveEffects = {
  ATTACK_TWICE_EFFECT = { "HITS TWICE" },
  BIDE_EFFECT = { "STORES DAMAGE 2-3", "TURNS THEN RETURNS 2X" },
  BURN_SIDE_EFFECT1 = { "10.2% CHANCE", "TO BURN TARGET" },
  BURN_SIDE_EFFECT2 = { "30.1% CHANCE", "TO BURN TARGET" },
  CHARGE_EFFECT = { "CHARGES THIS TURN", "ATTACKS NEXT TURN" },
  CONFUSION_EFFECT = { "CONFUSES THE TARGET" },
  CONFUSION_SIDE_EFFECT = { "9.8% CHANCE", "TO CONFUSE TARGET" },
  CONVERSION_EFFECT = { "COPIES TARGET TYPES" },
  DISABLE_EFFECT = { "DISABLES RANDOM MOVE", "FOR 1-8 TURNS" },
  DRAIN_HP_EFFECT = { "HEALS USER BY HALF", "OF DAMAGE DEALT" },
  DREAM_EATER_EFFECT = { "ONLY HITS SLEEPING", "DRAINS HALF DAMAGE" },
  EXPLODE_EFFECT = { "USER FAINTS AFTER", "THE ATTACK" },
  FLINCH_SIDE_EFFECT1 = { "10.2% CHANCE", "TO FLINCH TARGET" },
  FLINCH_SIDE_EFFECT2 = { "30.1% CHANCE", "TO FLINCH TARGET" },
  FLY_EFFECT = { "FLIES UP THIS TURN", "ATTACKS NEXT TURN" },
  FREEZE_SIDE_EFFECT1 = { "10.2% CHANCE", "TO FREEZE TARGET" },
  HAZE_EFFECT = { "CLEARS BOTH SIDES", "STATS AND CONDITIONS" },
  HEAL_EFFECT = { "RESTORES HALF OF", "USER MAX HP" },
  JUMP_KICK_EFFECT = { "USER LOSES 1 HP", "IF ATTACK MISSES" },
  LEECH_SEED_EFFECT = { "DRAINS TARGET HP", "EACH TURN" },
  LIGHT_SCREEN_EFFECT = { "DOUBLES USER SPECIAL", "DEFENSE UNTIL SWITCH" },
  METRONOME_EFFECT = { "USES A RANDOM MOVE" },
  MIMIC_EFFECT = { "COPIES A TARGET MOVE" },
  MIRROR_MOVE_EFFECT = { "REPEATS TARGET LAST", "MOVE" },
  MIST_EFFECT = { "PREVENTS ENEMY STAT", "REDUCTIONS" },
  OHKO_EFFECT = { "ONE-HIT KO", "FAILS IF USER SLOWER" },
  PARALYZE_EFFECT = { "PARALYZES THE TARGET" },
  PARALYZE_SIDE_EFFECT1 = { "10.2% CHANCE", "TO PARALYZE TARGET" },
  PARALYZE_SIDE_EFFECT2 = { "30.1% CHANCE", "TO PARALYZE TARGET" },
  PAY_DAY_EFFECT = { "SCATTERS 2X LEVEL", "COINS AFTER BATTLE" },
  POISON_EFFECT = { "POISONS THE TARGET" },
  POISON_SIDE_EFFECT1 = { "20.3% CHANCE", "TO POISON TARGET" },
  POISON_SIDE_EFFECT2 = { "40.2% CHANCE", "TO POISON TARGET" },
  RAGE_EFFECT = { "ATTACK RISES WHEN", "USER IS HIT" },
  RECOIL_EFFECT = { "USER TAKES 1/4", "OF DAMAGE DEALT" },
  REFLECT_EFFECT = { "DOUBLES USER DEFENSE", "UNTIL SWITCHING" },
  SLEEP_EFFECT = { "PUTS TARGET TO SLEEP" },
  SPLASH_EFFECT = { "DOES NOTHING" },
  SUBSTITUTE_EFFECT = { "USES 1/4 MAX HP", "TO CREATE A DECOY" },
  SUPER_FANG_EFFECT = { "HALVES TARGET", "CURRENT HP" },
  SWIFT_EFFECT = { "NEVER MISSES" },
  SWITCH_AND_TELEPORT_EFFECT = { "ENDS WILD BATTLE", "FAILS VS TRAINERS" },
  THRASH_PETAL_DANCE_EFFECT = { "ATTACKS 3-4 TURNS", "THEN CONFUSES USER" },
  TRANSFORM_EFFECT = { "COPIES TARGET STATS", "TYPES AND MOVES" },
  TRAPPING_EFFECT = { "TRAPS FOR 2-5 HITS", "TARGET CANNOT MOVE" },
  TWINEEDLE_EFFECT = { "HITS TWICE", "20.3% POISON CHANCE" },
  TWO_TO_FIVE_ATTACKS_EFFECT = { "HITS 2-5 TIMES" },
}

THEME.moveSpecial = {
  COUNTER = { "2X LAST NORMAL/FIGHT", "DAMAGE" },
  DIG = { "DIGS UNDERGROUND", "ATTACKS NEXT TURN" },
  DRAGON_RAGE = { "DEALS 40 FIXED DAMAGE" },
  NIGHT_SHADE = { "DAMAGE EQUALS", "USER LEVEL" },
  PSYWAVE = { "DEALS 1 TO 1.5X", "USER LEVEL DAMAGE" },
  REST = { "FULLY HEALS USER", "THEN SLEEPS 2 TURNS" },
  SEISMIC_TOSS = { "DAMAGE EQUALS", "USER LEVEL" },
  SONICBOOM = { "DEALS 20 FIXED DAMAGE" },
  STRUGGLE = { "USER TAKES HALF", "OF DAMAGE DEALT" },
  TELEPORT = { "ESCAPES WILD BATTLE", "FAILS VS TRAINERS" },
  TOXIC = { "BADLY POISONS TARGET", "DAMAGE GROWS PER TURN" },
}

function THEME:moveName(move, data)
  local def = data and data.moves and move and data.moves[move.id]
  return def and def.name or move and (move.name or move.id) or "MOVE"
end

function THEME:moveUnavailableReason(move)
  if move and move.disabled then return "DISABLED" end
  if not move or (move.pp or 0) <= 0 then return "NO PP" end
end

function THEME:translate(source)
  if not self.strings then return source end
  return self.strings:get(STRING_PREFIX .. source)
    or self.strings:get(source)
    or source
end

function THEME:batteryState(state, percent, tick)
  percent = math.max(0, math.min(100, tonumber(percent) or 100))
  tick = math.floor(tonumber(tick) or 0)
  if state == "charged" then return 4, nil, true, "green", false end
  if state == "charging" then
    local solid = math.min(4, math.floor(percent / 25))
    local blink = solid < 4 and solid + 1 or nil
    return solid, blink, tick % 2 == 0, "green", blink ~= nil
  end
  local level = math.max(1, math.ceil(percent / 25))
  local low = percent <= 10
  local tone = level >= 3 and "green" or level == 2 and "amber" or "red"
  return low and 0 or level, low and 1 or nil, tick % 2 == 0, tone, low
end

do
  local solid, blink, _, tone = THEME:batteryState("battery", 50, 0)
  assert(solid == 2 and blink == nil and tone == "amber",
    "battery quarter and color mapping")
  solid, blink, _, tone = THEME:batteryState("battery", 10, 0)
  assert(solid == 0 and blink == 1 and tone == "red",
    "critical battery blink")
  solid, blink, _, tone = THEME:batteryState("charging", 50, 0)
  assert(solid == 2 and blink == 3 and tone == "green",
    "charging previews the next quarter")
end

local function formatSpecifierCount(value)
  local count = 0
  for spec in value:gmatch("%%(.)") do
    if spec ~= "%" then count = count + 1 end
  end
  return count
end

function THEME:format(source, ...)
  local template = self:translate(source)
  if formatSpecifierCount(template) ~= formatSpecifierCount(source) then
    template = source
  end
  local ok, value = pcall(string.format, template, ...)
  return ok and value or string.format(source, ...)
end

function THEME:typeName(id, content)
  local registry = content and content.type_chart
  local record = id and registry and registry:get(id)
  return record and record.name or id or "STATUS"
end

function THEME:statusName(id, content)
  local registry = content and content.statuses
  local record = id and registry and registry:get(id)
  return record and (record.hudLabel or record.label) or id
end

function THEME:displayDefaults(get)
  local legacy = get("window_layout")
  local mode = get("display_mode")
  if mode == nil then
    mode = legacy and legacy ~= "off" and "combined" or "separate"
  end
  local layout = get("combined_layout")
  if layout == nil then
    layout = legacy == "large" and "overlay"
      or (legacy ~= "off" and legacy) or "auto"
  end
  return mode, layout
end

function THEME:displayMode(options)
  return options:get("display_mode") or self.displayModeDefault
end

function THEME:windowMode(options)
  local mode = self:displayMode(options)
  if mode == "fullscreen" then return "fullscreen" end
  if mode == "combined" then
    return options:get("combined_layout") or self.combinedLayoutDefault
  end
  return "off"
end

function THEME:gearPrimary(options, swapped)
  local primary = self:displayMode(options) == "fullscreen"
    and (options:get("fullscreen_start") or "game")
    or (options:get("combined_primary") or "game")
  local gear = primary == "gear"
  if swapped then return not gear end
  return gear
end

function THEME:fitRect(rect, width, height)
  local scale = math.min(rect.w / width, rect.h / height)
  local w, h = math.floor(width * scale), math.floor(height * scale)
  return {
    x = math.floor(rect.x + (rect.w - w) / 2),
    y = math.floor(rect.y + (rect.h - h) / 2),
    w = w, h = h,
  }
end

function THEME:windowLayout(mode, width, height, swapped, overlayCorner,
    overlayHidden, secondarySize)
  if not mode or mode == "off" then return nil end
  if mode == "auto" then
    mode = width >= height and "side" or "stacked"
  elseif mode == "large" then
    mode = "overlay"
  end
  local gap = math.max(2, math.floor(math.min(width, height) * 0.01))
  local requestedSize = tonumber(secondarySize)
  local function share(fallback)
    return math.max(20, math.min(80, requestedSize or fallback)) / 100
  end
  local game, gear
  local showGear = true
  local showGame = true
  local gameOnTop = false
  if mode == "fullscreen" then
    game = { x = 0, y = 0, w = width, h = height }
    gear = { x = 0, y = 0, w = width, h = height }
    showGear = swapped == true
    showGame = not showGear
    swapped = false
  elseif mode == "stacked" then
    local gearHeight = math.floor((height - gap) * share(36))
    game = { x = 0, y = 0, w = width, h = height - gearHeight - gap }
    gear = { x = 0, y = game.h + gap, w = width, h = gearHeight }
  elseif mode == "side" then
    local gearWidth = math.floor((width - gap) * share(34))
    game = { x = 0, y = 0, w = width - gearWidth - gap, h = height }
    gear = { x = game.w + gap, y = 0, w = gearWidth, h = height }
  elseif mode == "overlay" then
    local gearHeight = math.floor(height * share(42))
    local gearWidth = math.min(math.floor(width
      * (requestedSize and share(42) or 0.38)),
      math.floor(gearHeight * WIDTH / HEIGHT))
    local left = overlayCorner == "top_left"
      or overlayCorner == "bottom_left"
    local top = overlayCorner == "top_left"
      or overlayCorner == "top_right"
    game = { x = 0, y = 0, w = width, h = height }
    gear = { x = left and gap or width - gearWidth - gap,
      y = top and gap or height - gearHeight - gap,
      w = gearWidth, h = gearHeight }
  else
    return nil
  end
  if swapped then
    game, gear = gear, game
    gameOnTop = mode == "overlay"
  end
  if mode == "overlay" and overlayHidden then
    showGear = swapped == true
    showGame = swapped ~= true
    gameOnTop = false
  end
  return {
    game = game, gear = gear, showGame = showGame,
    showGear = showGear, gameOnTop = gameOnTop,
  }
end

function THEME:drawCanvas(canvas, rect)
  local fitted = self:fitRect(rect, canvas:getWidth(), canvas:getHeight())
  G.setScissor(rect.x, rect.y, rect.w, rect.h)
  G.draw(canvas, fitted.x, fitted.y, 0,
    fitted.w / canvas:getWidth(), fitted.h / canvas:getHeight())
  return fitted
end

function THEME:moveDescription(move, def, ruleset)
  def = def or {}
  local id = move and move.id or def.id
  local fixed = def.fixedDamage
  if type(fixed) == "number" then
    return { self:format("DEALS %d FIXED DAMAGE", fixed) }, true
  elseif fixed == "level" then
    return { "DAMAGE EQUALS", "USER LEVEL" }, true
  elseif type(fixed) == "function" then
    return { "DEALS CUSTOM", "FIXED DAMAGE" }, true
  end
  local hits = def.multiHit
  if type(hits) == "number" then
    return { self:format("HITS %d TIMES", hits) }, true
  elseif type(hits) == "table" and #hits > 0 then
    local low, high = hits[1], hits[1]
    for _, count in ipairs(hits) do
      low, high = math.min(low, count), math.max(high, count)
    end
    return { self:format("HITS %d-%d TIMES", low, high) }, true
  end
  local special = self.moveSpecial[id]
  if special then return special, true end
  if def.highCrit or self.highCritMoves[id] then
    return { "HIGH CRITICAL-HIT", "RATE" }, true
  end
  local effect = def.effect
  if effect == "FOCUS_ENERGY_EFFECT" then
    return ruleset and ruleset.focusEnergyBug == false
      and { "RAISES CRITICAL-HIT", "RATE" }
      or { "LOWERS CRITICAL-HIT", "RATE DUE TO GEN 1 BUG" }, true
  elseif effect == "HYPER_BEAM_EFFECT" then
    return ruleset and ruleset.hyperBeamSkipRechargeOnKO == false
      and { "USER MUST RECHARGE", "NEXT TURN" }
      or { "RECHARGES NEXT TURN", "UNLESS TARGET FAINTS" }, true
  elseif effect == "SPECIAL_DAMAGE_EFFECT" then
    return { "SPECIAL DAMAGE", "NO DETAILS AVAILABLE" }, false
  end
  local stat, stages = effect and effect:match("^([A-Z]+)_UP([12])_EFFECT$")
  if stat then
    return { self:format("RAISES USER %s", self:translate(stat)),
             stages == "2" and "BY TWO STAGES" or "BY ONE STAGE" }, true
  end
  stat, stages = effect and effect:match("^([A-Z]+)_DOWN([12])_EFFECT$")
  if stat then
    local amount = stages == "2" and "BY TWO STAGES" or "BY ONE STAGE"
    stat = self:translate(stat)
    local first = self:format("LOWERS TARGET %s", stat)
    return #first <= 21 and { first, amount }
      or { "LOWERS TARGET", self:format("%s %s", stat,
                                         self:translate(amount)) }, true
  end
  stat = effect and effect:match("^([A-Z]+)_DOWN_SIDE_EFFECT$")
  if stat then
    return { "33.2% CHANCE TO LOWER",
             self:format("TARGET %s", self:translate(stat)) }, true
  end
  local description = self.moveEffects[effect]
  if description then return description, true end
  if effect == "NO_ADDITIONAL_EFFECT" then
    return { "DEALS DAMAGE" }, true
  end
  return { "NO DETAILS AVAILABLE" }, false
end
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
local SECONDARY_BACKGROUND
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
  PAPER, MID, DARK, INK = rgba(palette[1]), rgba(palette[2]),
                           rgba(palette[3]), rgba(palette[4])
  local background = normalizedBackground and {
    normalizedBackground[1] * 255 + 0.5,
    normalizedBackground[2] * 255 + 0.5,
    normalizedBackground[3] * 255 + 0.5,
  } or fillerColor(palette)
  SECONDARY_BACKGROUND = rgb24(background)
end

usePalette(THEME.classic)
assert(validPalette(THEME.classic)
       and validPalette(THEME.light)
       and validPalette(THEME.dark)
       and inverted(THEME.classic)[1] == THEME.classic[4]
       and fillerColor({ { 255, 255, 255 }, { 200, 100, 100 },
                         { 120, 20, 80 }, { 0, 0, 0 } })[1] == 120
       and rgb24({ 0.90 * 255 + 0.5, 0.95 * 255 + 0.5,
                   0.91 * 255 + 0.5 }) == 0xE6F2E8
       and rgb24({ 0.035 * 255 + 0.5, 0.06 * 255 + 0.5,
                   0.06 * 255 + 0.5 }) == 0x090F0F
       and SECONDARY_BACKGROUND == 0x0F380F, "theme palette helpers")

local function choiceReady(now, readyAt)
  return now >= readyAt
end

local function textTouch(top)
  if not (top and top.isTextBox) then return nil end
  if top.waiting then return "advance" end
  if not top.done then return "speed" end
  if not top.choice then return "advance" end
end

local function textPrompt(top)
  return textTouch(top) == "advance"
end

local function namingCell(x, y, grid)
  if not grid or x < 3 or x >= 157 or y < 36 then return end
  local offset = y - 36
  local row = math.floor(offset / 17) + 1
  if offset % 17 >= 15 or not grid[row] or #grid[row] == 0 then return end
  local col = math.floor((x - 3) * #grid[row] / 154) + 1
  return row, col
end

local function pageSwipeAllowed(mode, battle)
  return mode == "active" and not battle
end

local function carouselSubpage(current, count, direction)
  local nextPage = math.max(1, math.min(count, current or 1)) + direction
  if nextPage >= 1 and nextPage <= count then return nextPage end
end

local function pagedIndex(index, count, direction)
  return math.max(1, math.min(count, index + direction * 4))
end

local function pageWindow(index, count)
  local first = math.floor((math.max(1, index or 1) - 1) / 4) * 4 + 1
  return first, math.min(4, math.max(0, count - first + 1))
end

local function partySlotAt(x, y, count)
  if y < 23 or y >= 140 then return nil end
  local col = x >= 81 and x < 156 and 1 or x >= 3 and x < 78 and 0 or nil
  if col == nil then return nil end
  local row = math.floor((y - 23) / 39)
  local slot = row * 2 + col + 1
  return slot <= (count or 0) and slot or nil
end

local function moveGridLayout(state, owned)
  if owned then return true end
  if not (state and type(state.wideLayout) == "function") then return false end
  local ok, wide = pcall(state.wideLayout, state)
  return ok and wide == true or false
end

local function moveSlotAt(x, y, count, grid)
  local col, row, left, top
  if grid then
    col = x >= 81 and x < 157 and 1 or x >= 3 and x < 79 and 0 or nil
    row = y >= 80 and y < 136 and 1 or y >= 24 and y < 78 and 0 or nil
    if col == nil or row == nil then return nil end
    left, top = 3 + col * 78, 24 + row * 56
  else
    if x < 8 or x >= 152 or y < 24 or y >= 135 then return nil end
    row = math.floor((y - 24) / 28)
    if (y - 24) % 28 >= 27 then return nil end
    left, top = 8, 24 + row * 28
  end
  local slot = row * (grid and 2 or 1) + (col or 0) + 1
  if slot > (count or 0) then return nil end
  return slot, left, top
end

local function progressRatio(value, first, last)
  if last <= first then return 1 end
  return math.max(0, math.min(1, ((value or first) - first) / (last - first)))
end

local function pcListKind(state)
  if not state then return nil end
  if PC_LIST_KINDS[state.kind] and rowsContract(state.items)
      and type(state.index) == "number" then return state.kind end
  if state.screenId == "Gen2PcMenu" and state.picking
      and not state.savePhase and type(state.pickIndex) == "number" then
    return "gen2_box_change"
  end
  if state.screenId == "Gen2BoxMenu"
      and (not state.phase or state.phase == "insert")
      and not state.message and type(state.index) == "number"
      and (state.mode == "withdraw" or state.mode == "deposit"
        or state.mode == "move") then
    return "gen2_box_" .. state.mode
  end
  if state.screenId == "Gen2ItemPcMenu" and not state.message
      and not state.qtyState and not state.confirm
      and (state.phase == "withdraw" or state.phase == "toss")
      and rowsContract(state.rows) and type(state.listIndex) == "number" then
    return "gen2_item_" .. state.phase
  end
end

local function assistEnabled(profile, custom)
  if profile == "purist" then return false end
  if profile == "enhanced" then return true end
  return custom == true
end

local function savedSteps(value)
  return math.max(0, math.floor(tonumber(value) or 0))
end

local FIELD_MOVES = {
  CUT = "CASCADEBADGE", SURF = "SOULBADGE",
  STRENGTH = "RAINBOWBADGE", FLASH = "BOULDERBADGE",
  FLY = "THUNDERBADGE", DIG = false, TELEPORT = false,
  SOFTBOILED = false,
}

THEME.fieldTools = { widgets = {
  { key = "bicycle", action = "bicycle", item = "BICYCLE", icon = "bicycle" },
  { key = "old_rod", action = "fish", item = "OLD_ROD", rod = "OLD_ROD",
    icon = "fish" },
  { key = "good_rod", action = "fish", item = "GOOD_ROD", rod = "GOOD_ROD",
    icon = "fish" },
  { key = "super_rod", action = "fish", item = "SUPER_ROD", rod = "SUPER_ROD",
    icon = "fish" },
  { key = "cut", action = "cut", move = "CUT", icon = "cut", gen = "both" },
  { key = "surf", action = "surf", move = "SURF", icon = "surf", gen = "both" },
  { key = "strength", action = "strength", move = "STRENGTH",
    icon = "strength", gen = "both" },
  { key = "flash", action = "flash", move = "FLASH", icon = "flash",
    gen = "both" },
  { key = "headbutt", action = "headbutt", move = "HEADBUTT",
    icon = "headbutt", gen = 2 },
  { key = "whirlpool", action = "whirlpool", move = "WHIRLPOOL",
    icon = "whirlpool", gen = 2 },
  { key = "waterfall", action = "waterfall", move = "WATERFALL",
    icon = "waterfall", gen = 2 },
  { key = "sweet_scent", action = "sweet_scent", move = "SWEET_SCENT",
    icon = "sweet_scent", gen = 2 },
  { key = "dig", action = "dig", move = "DIG", icon = "dig", gen = "both" },
  { key = "teleport", action = "teleport", move = "TELEPORT",
    icon = "teleport", gen = "both" },
  { key = "softboiled", action = "softboiled", move = "SOFTBOILED",
    icon = "softboiled", gen = 1 },
  { key = "squirtbottle", action = "squirtbottle", item = "SQUIRTBOTTLE",
    icon = "squirtbottle", gen = 2 },
} }

THEME.fieldTools.gen2Badges = {
  CUT = "HIVE", FLASH = "ZEPHYR", SURF = "FOG", STRENGTH = "PLAIN",
  WHIRLPOOL = "GLACIER", WATERFALL = "RISING",
}

THEME.fieldTools.badgeOrder = {
  "ZEPHYR", "HIVE", "PLAIN", "FOG", "STORM", "MINERAL", "GLACIER",
  "RISING",
}

function THEME.fieldTools.partyKnows(save, moveId)
  for _, mon in ipairs(save and save.party or {}) do
    for _, move in ipairs(mon.moves or {}) do
      if move.id == moveId then return true end
    end
  end
  return false
end

function THEME.fieldTools.gen2Badge(save, badge)
  if not badge then return true end
  local owned = save and save.player and save.player.badges
  if type(owned) ~= "table" then return false end
  if owned[badge] then return true end
  for index, name in ipairs(THEME.fieldTools.badgeOrder) do
    if name == badge then return owned[index] == true end
  end
  return false
end

function THEME.fieldTools.unlocked(def, save, gen2)
  if def.gen ~= nil and def.gen ~= "both" and def.gen ~= (gen2 and 2 or 1) then
    return false
  end
  local inventory = save and save.inventory or {}
  if def.item then return (inventory[def.item] or 0) > 0 end
  if not THEME.fieldTools.partyKnows(save, def.move) then return false end
  if gen2 then return THEME.fieldTools.gen2Badge(
    save, THEME.fieldTools.gen2Badges[def.move]) end
  local badge = FIELD_MOVES[def.move]
  return badge == false or badge ~= nil and (inventory[badge] or 0) > 0
end

local function hasUnlockedTool(save)
  local inv = save and save.inventory or {}
  for _, item in ipairs({ "BICYCLE", "OLD_ROD", "GOOD_ROD", "SUPER_ROD" }) do
    if (inv[item] or 0) > 0 then return true end
  end
  for _, mon in ipairs(save and save.party or {}) do
    for _, move in ipairs(mon.moves or {}) do
      local badge = FIELD_MOVES[move.id]
      if badge ~= nil and (badge == false or inv[badge]) then return true end
    end
  end
  return false
end

local function addEncounters(rows, bySpecies, slots, method, buckets, context)
  slots = slots or {}
  if type(context) ~= "table" then context = context and { time = context } end
  local weights, levels, previous = {}, {}, 0
  for index, slot in ipairs(slots) do
    local threshold = buckets and buckets[index]
    local weight = threshold and threshold - previous or 1
    previous = threshold or previous
    local species = slot.species
    if species and species ~= 0 and species ~= "NO_ITEM" then
      local minLevel, maxLevel = slot.min or slot.level, slot.max or slot.level
      weights[species] = (weights[species] or 0) + weight
      local range = levels[species]
      if range then
        range.min, range.max = math.min(range.min, minLevel),
          math.max(range.max, maxLevel)
      else
        levels[species] = { min = minLevel, max = maxLevel }
      end
      local row = bySpecies[species]
      if not row then
        row = { species = species, minLevel = minLevel,
                maxLevel = maxLevel, methods = {}, methodSet = {},
                appearances = {} }
        rows[#rows + 1], bySpecies[species] = row, row
      else
        row.minLevel = math.min(row.minLevel, minLevel)
        row.maxLevel = math.max(row.maxLevel, maxLevel)
      end
      if context and context.time then
        row.times = row.times or {}
        row.times[context.time] = true
      else
        row.allTimes = true
      end
    end
  end
  local total, seen = buckets and buckets[#slots] or #slots, {}
  for _, slot in ipairs(slots) do
    local species = slot.species
    if species and species ~= 0 and species ~= "NO_ITEM"
        and not seen[species] then
      seen[species] = true
      local chance = math.floor(weights[species] * 100 / total + 0.5)
      local row, odds = bySpecies[species]
      odds = row.methodSet[method]
      if odds then
        odds.min, odds.max = math.min(odds.min, chance), math.max(odds.max, chance)
      else
        odds = { name = method, min = chance, max = chance }
        row.methodSet[method] = odds
        row.methods[#row.methods + 1] = odds
      end
      if context then
        local range = levels[species]
        row.appearances[#row.appearances + 1] = {
          method = method, chance = chance, time = context.time,
          mapId = context.mapId, section = context.section,
          minLevel = range.min, maxLevel = range.max,
        }
      end
    end
  end
end

local function battleUIMode(value, legacyFull)
  if value == "standard" or value == "gear" or value == "full" then
    return value
  end
  if legacyFull == true then return "full" end
  if value == true then return "gear" end
  return "standard"
end

local function checklistPages(sections)
  local out = {}
  for _, section in ipairs(sections) do
    local done = 0
    for _, row in ipairs(section.rows) do
      if row.done then done = done + 1 end
    end
    local perPage = section.perPage or 4
    local count = math.max(1, math.ceil(#section.rows / perPage))
    for page = 1, count do
      out[#out + 1] = { name = section.name, rows = section.rows,
        done = done, total = #section.rows, page = page, pages = count,
        perPage = perPage }
    end
  end
  return out
end

local function oneShotTrainerStatus(defeated, battled, result)
  if defeated or result == "win" then return true end
  if result == "lose" then return true, "LOST" end
  return battled or false
end

local function compactClock(value)
  return THEME:format((value or "--:--"):gsub("^0", ""):gsub("%s+", ""))
end

local Area = {}

-- Gen 1 stores ordinary trainers on their object, but story encounters set
-- wCurOpponent from map script instead.  Keep the small exceptional set here;
-- object names are stable across Red, Blue, and Yellow manifests.
local GEN1_SCRIPT_TRAINERS = {
  ROUTE_22 = {
    ROUTE22_RIVAL1 = { class = "OPP_RIVAL1",
      event = "EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE",
      requires = { "EVENT_GOT_POKEDEX" }, missedAfter = "EVENT_BEAT_BROCK" },
    ROUTE22_RIVAL2 = { class = "OPP_RIVAL2",
      event = "EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE",
      requires = { "EVENT_BEAT_GIOVANNI" } },
  },
  CERULEAN_CITY = {
    CERULEANCITY_RIVAL = { class = "OPP_RIVAL1",
      event = "EVENT_BEAT_CERULEAN_RIVAL" },
    CERULEANCITY_ROCKET = { class = "OPP_ROCKET",
      event = "EVENT_BEAT_CERULEAN_ROCKET_THIEF" },
  },
  SS_ANNE_2F = {
    SSANNE2F_RIVAL = { class = "OPP_RIVAL2",
      event = "EVENT_BEAT_SS_ANNE_RIVAL" },
  },
  POKEMON_TOWER_2F = {
    POKEMONTOWER2F_RIVAL = { class = "OPP_RIVAL2",
      event = "EVENT_BEAT_POKEMON_TOWER_RIVAL" },
  },
  SILPH_CO_7F = {
    SILPHCO7F_RIVAL = { class = "OPP_RIVAL2",
      event = "EVENT_BEAT_SILPH_CO_RIVAL" },
  },
  CHAMPIONS_ROOM = {
    CHAMPIONSROOM_RIVAL = { class = "OPP_RIVAL3",
      event = "EVENT_BEAT_CHAMPION_RIVAL" },
  },
  MT_MOON_B2F = {
    MTMOONB2F_JESSIE = { class = "OPP_ROCKET", label = "JESSIE & JAMES",
      event = "EVENT_BEAT_MT_MOON_3_JESSIE_JAMES",
      requiresAny = { "EVENT_GOT_DOME_FOSSIL", "EVENT_GOT_HELIX_FOSSIL" } },
  },
  ROCKET_HIDEOUT_B4F = {
    ROCKETHIDEOUTB4F_JESSIE = { class = "OPP_ROCKET",
      label = "JESSIE & JAMES",
      event = "EVENT_BEAT_ROCKET_HIDEOUT_4_JESSIE_JAMES" },
  },
  POKEMON_TOWER_7F = {
    POKEMONTOWER7F_JESSIE = { class = "OPP_ROCKET",
      label = "JESSIE & JAMES",
      event = "EVENT_BEAT_POKEMONTOWER_7_JESSIE_JAMES" },
  },
  SILPH_CO_11F = {
    SILPHCO11F_JESSIE = { class = "OPP_ROCKET", label = "JESSIE & JAMES",
      event = "EVENT_BEAT_SILPH_CO_11F_JESSIE_JAMES" },
  },
  CELADON_CHIEF_HOUSE = {
    CELADONCHIEFHOUSE_CHIEF = { class = "OPP_CHIEF",
      event = "EVENT_BEAT_CELADON_CHIEF",
      requires = { "EVENT_BEAT_CHAMPION_RIVAL" } },
  },
}

function Area.gen1ScriptTrainer(mapId, obj)
  local map = GEN1_SCRIPT_TRAINERS[mapId]
  return map and obj and map[obj.name] or nil
end

function Area.gen1TrainerState(save, trainer)
  local flags = save and save.flags or {}
  local beaten = trainer and trainer.event and flags[trainer.event] == true
  local missed = not beaten and trainer and trainer.missedAfter
    and flags[trainer.missedAfter] == true or false
  local available = not beaten and not missed
  for _, event in ipairs(trainer and trainer.requires or {}) do
    available = available and flags[event] == true
  end
  if trainer and trainer.requiresAny then
    local any = false
    for _, event in ipairs(trainer.requiresAny) do
      any = any or flags[event] == true
    end
    available = available and any
  end
  return {
    beaten = beaten, missed = missed, done = beaten or missed,
    available = available,
    status = missed and "MISSED" or not available and not beaten and "LATER"
      or nil,
  }
end

function Area.gen1TrainerMissed(save, mapId, done)
  if done then return false end
  local event = tostring(mapId):match("^SS_ANNE_") and "EVENT_SS_ANNE_LEFT"
    or tostring(mapId):match("^SILPH_CO_")
      and "EVENT_BEAT_SILPH_CO_GIOVANNI"
  return event ~= nil and save and save.flags
    and save.flags[event] == true or false
end

function Area.itemfinderNear(px, py, x, y)
  local function near(origin, value, high)
    return value > math.max(origin - 5, 0) and value <= origin + high
  end
  return near(px, x, 5) and near(py, y, 4)
end

function Area.itemfinderScanReached(px, py, x, y, progress)
  if not Area.itemfinderNear(px, py, x, y) then return false end
  local dx, dy = x - px, y - py
  return math.sqrt(dx * dx + dy * dy) <= math.sqrt(41) * progress
end

local function gen2Definition(definitions, index)
  local direct = definitions and definitions[index]
  if type(direct) == "table" then return direct, direct.id or index end
  for id, def in pairs(definitions or {}) do
    if type(def) == "table" and def.index == index then return def, id end
  end
end

local function gen2FlagSet(world, event)
  return event ~= nil and world and world.getFlag
    and world:getFlag(event) == true or false
end

local function gen2ItemName(data, index)
  local def, id = gen2Definition(data and data.items, index)
  return def and def.name or id or tostring(index)
end

local function gen2TrainerName(data, save, trainer)
  local class, classId = gen2Definition(
    data and data.gen2Trainers and data.gen2Trainers.classes,
    trainer and trainer.class)
  if not class then return "TRAINER" end
  classId = class.id or classId
  if tostring(classId):match("^RIVAL") then
    return save and save.rival and save.rival.name or class.name or classId
  end
  local member = class.trainers and class.trainers[trainer.member]
  return member and member.name
    and tostring(class.name or classId) .. " " .. tostring(member.name)
    or class.name or classId
end

function Area.gen2Hidden(data, world, mapId)
  local map = data and data.gen2Maps and data.gen2Maps[mapId]
  local out = {}
  for _, event in ipairs(map and map.bgEvents or {}) do
    local hidden = event.hiddenItem
    if hidden then
      out[#out + 1] = {
        label = gen2ItemName(data, hidden.item),
        done = gen2FlagSet(world, hidden.event),
        x = event.x, y = event.y,
      }
    end
  end
  return out
end

function Area.gen2ScriptTrainer(data, obj)
  local scripts = data and data.gen2Scripts
  local commands = obj and obj.scriptKey
  commands = type(commands) == "table" and commands
    or scripts and scripts[commands]
  local trainer, started
  for _, command in ipairs(commands or {}) do
    if command.op == "loadtrainer" then
      trainer = { class = command.class, member = command.member }
    elseif command.op == "startbattle" and trainer then
      started = true
    elseif command.op == "setevent" and started and trainer.event == nil then
      trainer.event = command.event
    end
  end
  return started and trainer or nil
end

function Area.gen2Rows(data, save, world, mapIds)
  local rows = { {}, {}, {} }
  for _, mapId in ipairs(mapIds) do
    local map = data and data.gen2Maps and data.gen2Maps[mapId]
    for _, obj in ipairs(map and map.objects or {}) do
      local trainer = obj.trainer or Area.gen2ScriptTrainer(data, obj)
      if trainer then
        rows[1][#rows[1] + 1] = {
          label = gen2TrainerName(data, save, trainer),
          done = gen2FlagSet(world, trainer.event),
          id = string.format("%s_obj_%d", mapId, obj.index or 0),
          mapId = mapId, index = obj.index or 0, x = obj.x, y = obj.y,
          spriteId = obj.sprite, palette = obj.palette,
        }
      elseif obj.itemball and obj.itemball.item ~= 0 then
        rows[2][#rows[2] + 1] = {
          label = gen2ItemName(data, obj.itemball.item),
          done = gen2FlagSet(world, obj.eventFlag),
          mapId = mapId, x = obj.x, y = obj.y, kind = "item",
        }
      end
    end
    for _, hidden in ipairs(Area.gen2Hidden(data, world, mapId)) do
      hidden.mapId, hidden.kind = mapId, "hidden"
      rows[3][#rows[3] + 1] = hidden
    end
  end
  return rows
end

function Area.remaining(sections)
  local out = {}
  for index, section in ipairs(sections) do
    local remaining = 0
    for _, row in ipairs(section.rows) do
      if not row.done then remaining = remaining + 1 end
    end
    out[index] = remaining
  end
  return out
end

do
  local flags = { [11] = true, [13] = true, [14] = true }
  local data = {
    items = {
      POTION = { index = 7, name = "POTION" },
      BERRY = { index = 8, name = "BERRY" },
    },
    gen2Trainers = { classes = { YOUNGSTER = {
      index = 3, name = "YOUNGSTER",
      trainers = { [2] = { name = "JOEY" } },
    }, POKEFANF = { index = 4, name = "POKEFAN",
      trainers = { [1] = { name = "JAIME" } },
    } } },
    gen2Scripts = { JAIME = {
      { op = "setevent", event = 99 },
      { op = "loadtrainer", class = 4, member = 1 },
      { op = "startbattle" }, { op = "setevent", event = 14 },
    } },
    gen2Maps = { TEST = {
      objects = {
        { trainer = { class = 3, member = 2, event = 11 } },
        { eventFlag = 12, itemball = { item = 7 } },
        { index = 3, x = 6, y = 7, scriptKey = "JAIME" },
      },
      bgEvents = { { x = 4, y = 5,
        hiddenItem = { item = 8, event = 13 } } },
    } },
  }
  local world = { getFlag = function(_, id) return flags[id] end }
  local rows = Area.gen2Rows(data, {}, world, { "TEST" })
  local remaining = Area.remaining({
    { rows = rows[1] }, { rows = rows[2] }, { rows = rows[3] },
  })
  assert(rows[1][1].label == "YOUNGSTER JOEY" and rows[1][1].done
    and rows[1][2].label == "POKEFAN JAIME" and rows[1][2].done
    and rows[1][2].x == 6 and rows[1][2].y == 7
    and rows[2][1].label == "POTION" and not rows[2][1].done
    and rows[3][1].label == "BERRY" and rows[3][1].done
    and remaining[1] == 0 and remaining[2] == 1 and remaining[3] == 0,
    "Gen 2 area checklist data")

  local earlyRival = Area.gen1ScriptTrainer("ROUTE_22",
    { name = "ROUTE22_RIVAL1" })
  local open = Area.gen1TrainerState({ flags = {
    EVENT_GOT_POKEDEX = true,
  } }, earlyRival)
  local missed = Area.gen1TrainerState({ flags = {
    EVENT_GOT_POKEDEX = true, EVENT_BEAT_BROCK = true,
  } }, earlyRival)
  local beaten = Area.gen1TrainerState({ flags = {
    EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE = true,
    EVENT_BEAT_BROCK = true,
  } }, earlyRival)
  assert(earlyRival.class == "OPP_RIVAL1" and open.available
    and not open.done and missed.done and missed.missed
    and missed.status == "MISSED" and beaten.done and beaten.beaten
    and not beaten.missed,
    "Gen 1 scripted and missable trainer state")
  assert(Area.gen1ScriptTrainer("MT_MOON_B2F",
      { name = "MTMOONB2F_JESSIE" }).label == "JESSIE & JAMES"
    and Area.gen1ScriptTrainer("MT_MOON_B2F",
      { name = "MTMOONB2F_JAMES" }) == nil,
    "Gen 1 duo battle is one encounter")
  assert(Area.gen1TrainerMissed({ flags = {
      EVENT_SS_ANNE_LEFT = true,
    } }, "SS_ANNE_B1F", false)
    and Area.gen1TrainerMissed({ flags = {
      EVENT_BEAT_SILPH_CO_GIOVANNI = true,
    } }, "SILPH_CO_7F", false)
    and not Area.gen1TrainerMissed({ flags = {
      EVENT_BEAT_SILPH_CO_GIOVANNI = true,
    } }, "SILPH_CO_7F", true),
    "Gen 1 expired-area trainers are missed unless already beaten")
end

local function localMapLayout(width, height, zoom, focusX, focusY, density)
  width, height = math.max(1, width or 1), math.max(1, height or 1)
  zoom = tonumber(zoom) or 1
  density = math.max(1, tonumber(density) or 4)
  local scale = math.min(3, 148 / width, 98 / height)
  if scale >= 1 then scale = math.floor(scale) end
  local zoomScale = zoom == 2 and 1.5 or zoom == 3 and 2
  if zoom > 1 then
    scale = math.max(scale * zoomScale, zoomScale * 4 / density)
  end
  local left = 4 + (152 - width * scale) / 2
  local top = 22 + (102 - height * scale) / 2
  if zoom > 1 and focusX and focusY then
    left = 80 - focusX * scale
    top = 73 - focusY * scale
    if width * scale > 152 then
      left = math.max(156 - width * scale, math.min(4, left))
    end
    if height * scale > 102 then
      top = math.max(124 - height * scale, math.min(22, top))
    end
  end
  return scale, left, top
end

local function localMapMode(value)
  if value == "enhanced" then return "enhanced" end
  if value == true or value == "map" then return "map" end
  return "off"
end

local function localMapGrid(overview)
  if overview.tileDetailRows then
    return overview.tileDetailRows, overview.tileDetailWidth,
      overview.tileDetailHeight, 4
  end
  if overview.tileRows then
    return overview.tileRows, overview.tileWidth, overview.tileHeight, 2
  end
  return overview.rows, overview.width, overview.height, 1
end

function THEME:localMapColor(overview, x, y, density, shade)
  density = math.max(1, tonumber(density) or 1)
  local cellX = math.floor((x - 1) / density) + 1
  local cellY = math.floor((y - 1) / density) + 1
  local row = overview and overview.rows and overview.rows[cellY] or ""
  local ramp = self.localMap[row:sub(cellX, cellX)] or self.localMap[" "]
  local index = math.max(1, math.min(4, (tonumber(shade) or 3) + 1))
  return ramp[index]
end

local function prepareBattleSnapshot(a, b, state, data, ownsMoveFocus)
  if ownsMoveFocus and b and state and b.prompt == "moves" then
    local moves = b.moves or {}
    local current = math.max(1, math.min(#moves,
      tonumber(state.moveIndex) or 1))
    local move = moves[current]
    if THEME:moveUnavailableReason(move) then
      for offset = 1, #moves - 1 do
        local index = (current + offset - 1) % #moves + 1
        move = moves[index]
        if move and not THEME:moveUnavailableReason(move) then
          state.moveIndex, b.moveIndex = index, index
          break
        end
      end
    end
  end
  if b and state and state.phase == "choose-forget"
      and (state.messageTimer or 0) <= 0 then
    local pending = state.pendingLearn
    local party = state.battle and state.battle.party
    local mon = pending and party and party[pending.index]
    if mon and type(mon.moves) == "table" and #mon.moves > 0 then
      b.prompt = "forget"
      b.forgetIndex = math.max(1, math.min(#mon.moves,
        tonumber(state.forgetIndex) or 1))
      b.forgetMoves = {}
      for slot, move in ipairs(mon.moves) do
        local def = (data.moves or {})[move.id] or {}
        b.forgetMoves[slot] = def.name or move.id
      end
      local move = pending.move or {}
      local def = (data.moves or {})[move.id] or {}
      b.learningMove = pending.moveName or def.name or move.id
    end
  end
  return (a and a.menuIndex) ~= (b and b.menuIndex)
    or (a and a.moveIndex) ~= (b and b.moveIndex)
    or (a and a.partyIndex) ~= (b and b.partyIndex)
    or (a and a.subIndex) ~= (b and b.subIndex)
    or (a and a.itemIndex) ~= (b and b.itemIndex)
    or (a and a.itemPocket) ~= (b and b.itemPocket)
    or (a and a.itemTitle) ~= (b and b.itemTitle)
    or (a and a.summaryPage) ~= (b and b.summaryPage)
    or (a and a.mimicIndex) ~= (b and b.mimicIndex)
    or (a and a.forgetIndex) ~= (b and b.forgetIndex)
end

local function supportedBattleUI(state)
  if not state then return false end
  local kind = state.kind
  if state.battleKind ~= nil then
    if type(state.battleKind) ~= "function" then return false end
    local ok, value = pcall(state.battleKind, state)
    if not ok then return false end
    kind = value
  end
  return kind ~= "link" and kind ~= "oldman"
end

local function caughtWild(kind, owned)
  return (kind == "wild" or kind == "safari") and owned == true
end

local function bottomOwnsBattleUI(enabled, active, available, ready,
                                 battleState, snapshot)
  return enabled and active and available and ready
    and snapshot ~= nil and supportedBattleUI(battleState) or false
end

local function battleChoice(state)
  return state and type(state.onChoose) == "function"
    and type(state.index) == "number" and state.items == nil or false
end

local function categorizedBag(state)
  return state and (state.__pocketIndex ~= nil or state.pocketIndex ~= nil
    or state.modernBag ~= nil or state.__gen3uiBagPocketIndex ~= nil)
    or false
end

local function levelUpStatBox(state)
  return state and type(state.mon) == "table"
    and type(state.mon.stats) == "table" and not state.screenId or false
end

local PARTY_MENU_IDS = { PartyMenu = true, Gen2PartyMenu = true }
local BAG_MENU_IDS = { BagMenu = true, Gen2PackMenu = true }

local function battlePartyMenu(state)
  if not (state and (PARTY_MENU_IDS[state.screenId]
      or state.isPartyMenu == true))
      or type(state.index) ~= "number" then return nil end
  if state.isCancel ~= nil and type(state.isCancel) ~= "function" then
    return nil
  end
  if type(state.isCancel) == "function" then
    local ok = pcall(state.isCancel, state)
    if not ok then return nil end
  end
  if state.submenu then
    local submenu = type(state.submenu) == "table" and state.submenu or nil
    local items = state.subItems or (submenu and submenu.items)
    local index = state.subIndex or (submenu and submenu.index)
    if not rowsContract(items) or type(index) ~= "number" then return nil end
  end
  return state
end

local function battleBagContract(state)
  if not (state and BAG_MENU_IDS[state.screenId]) then return false end
  if state.screenId == "Gen2PackMenu" then
    if state.message ~= nil or not rowsContract(state.rows)
        or type(state.index) ~= "number"
        or type(state.pocket) ~= "function" then return false end
    local ok, pocket = pcall(state.pocket, state)
    return ok and type(pocket) == "table"
  end
  if not rowsContract(state.items) or type(state.index) ~= "number" then
    return false
  end
  if state.__gen3uiBagViewRows ~= nil then
    return rowsContract(state.__gen3uiBagViewRows)
      and type(state.__gen3uiBagViewIndex) == "number"
  end
  return true
end

local function ppItemMoveMenu(state)
  return state and state.kind == "pp_item_move"
    and rowsContract(state.items) and type(state.index) == "number"
    and state or nil
end

local function namingGrid(state)
  if not state or type(state.row) ~= "number"
      or type(state.col) ~= "number" then return nil end
  local grid
  if state.screenId == "NamingScreen" then
    if type(state.glyphs) ~= "table" or type(state.grid) ~= "function" then
      return nil
    end
    local ok
    ok, grid = pcall(state.grid, state)
    if not ok then return nil end
  elseif state.screenId == "Gen2NamingScreen" then
    if type(state.text) ~= "string" or type(state.rows) ~= "function" then
      return nil
    end
    local ok, rows = pcall(state.rows, state)
    if not ok or not rowsContract(rows) or #rows == 0 then return nil end
    grid = {}
    for index, row in ipairs(rows) do
      if #row ~= 9 then return nil end
      grid[index] = row
    end
    grid[#grid + 1] = {
      state.lower and "UPPER CASE" or "lower case", "DEL", "END",
    }
  else
    return nil
  end
  if not rowsContract(grid) or #grid == 0 then return nil end
  for _, row in ipairs(grid) do
    if #row == 0 then return nil end
  end
  return grid
end

local function moveLearnMenu(state)
  if not (state and state.screenId == "MoveLearnMenu")
      or type(state.mon) ~= "table"
      or type(state.mon.species) ~= "string" or state.newMoveId == nil
      or type(state.index) ~= "number" then return nil end
  if state.selecting and type(state.mon.moves) ~= "table" then return nil end
  return state
end

local function screenContract(state, kind)
  if kind == "party" then return battlePartyMenu(state) end
  if kind == "bag" then return battleBagContract(state) and state or nil end
  if kind == "pp" then return ppItemMoveMenu(state) end
  if kind == "naming" then return namingGrid(state) end
  if kind == "moveLearn" then return moveLearnMenu(state) end
  if kind == "forget" then
    local pending = state and state.phase == "choose-forget"
      and (state.messageTimer or 0) <= 0 and state.pendingLearn
    local party = state and state.battle and state.battle.party
    local mon = pending and party and party[pending.index]
    return mon and type(mon.moves) == "table" and #mon.moves > 0 and mon or nil
  end
  return state and (battlePartyMenu(state) or battleBagContract(state)
    or ppItemMoveMenu(state) or battleChoice(state) or levelUpStatBox(state))
    or false
end

assert(screenContract({ screenId = "Gen2PackMenu", rows = {}, index = 1,
                            pocket = function() return {} end })
       and screenContract({ screenId = "Gen2PartyMenu", index = 1 })
       and not screenContract({ screenId = "Gen2PackMenu", message = {} })
       and not screenContract({ screenId = "PartyMenu" })
       and not screenContract({ screenId = "BagMenu" }),
       "safe Gen 2 battle menu mirroring")
assert(not choiceReady(0.31, 0.32) and choiceReady(0.32, 0.32),
       "choice quiet gate")
assert(caughtWild("wild", true) and caughtWild("safari", true)
       and not caughtWild("trainer", true) and not caughtWild("wild", false),
       "caught wild marker")
assert(textTouch({ isTextBox = true }) == "speed"
       and textTouch({ isTextBox = true, waiting = true }) == "advance"
       and textTouch({ isTextBox = true, done = true }) == "advance"
       and textTouch({ isTextBox = true, waiting = true,
                       choice = function() end }) == "advance"
       and textTouch({ isTextBox = true, choice = function() end }) == "speed"
       and textTouch({ isTextBox = true, done = true,
                       choice = function() end }) == nil
       and textTouch({}) == nil,
       "safe text touch mode")
do
  local grid = { { "A", "B", "C" }, { "CASE" } }
  local r1, c1 = namingCell(55, 36, grid)
  local r2, c2 = namingCell(80, 53, grid)
  assert(r1 == 1 and c1 == 2 and r2 == 2 and c2 == 1
         and not namingCell(80, 51, grid), "naming touch grid")
end
assert(pageSwipeAllowed("active", nil)
       and not pageSwipeAllowed("transition", nil)
       and not pageSwipeAllowed("loading", nil)
       and not pageSwipeAllowed("active", {}), "disabled screen swipe gate")
assert(carouselSubpage(1, 3, 1) == 2
       and carouselSubpage(3, 3, -1) == 2
       and carouselSubpage(3, 3, 1) == nil,
       "horizontal carousel subpages")
assert(pagedIndex(1, 9, 1) == 5 and pagedIndex(9, 9, 1) == 9
       and pagedIndex(5, 9, -1) == 1, "touch list paging")
assert(partySlotAt(3, 23, 6) == 1 and partySlotAt(81, 23, 6) == 2
       and partySlotAt(81, 101, 5) == nil and partySlotAt(79, 23, 6) == nil,
       "party touch slots")
do
  local classic = { wideLayout = function() return false end }
  local wide = { wideLayout = function() return true end }
  assert(not moveGridLayout(classic, false) and moveGridLayout(classic, true)
         and moveGridLayout(wide, false), "move layout authority")
  assert(moveSlotAt(4, 25, 4, true) == 1
         and moveSlotAt(4, 81, 4, true) == 3
         and moveSlotAt(9, 81, 4, false) == 3
         and not moveSlotAt(81, 81, 3, true), "move touch layout")
end
assert(progressRatio(15, 10, 20) == 0.5
       and progressRatio(0, 10, 20) == 0
       and progressRatio(30, 10, 20) == 1,
       "progress ratio")
do
  local first, count = pageWindow(6, 9)
  assert(first == 5 and count == 4
    and pcListKind({ kind = "pc_box_withdraw", items = {}, index = 1 })
      == "pc_box_withdraw"
    and not pcListKind({ kind = "pc_box_withdraw" })
    and not pcListKind({ kind = "bag" }), "PC touch list identity")
end
assert(not assistEnabled("purist", true)
       and assistEnabled("enhanced", false)
       and assistEnabled("custom", true), "assist profiles")
assert(battleUIMode("standard", true) == "standard"
       and battleUIMode("gear", false) == "gear"
       and battleUIMode("full", false) == "full"
       and battleUIMode(true, false) == "gear"
       and battleUIMode(false, true) == "full", "battle UI settings")
do
  local pages = checklistPages({
    { name = "TRAINERS", rows = { { done = true }, { done = false } } },
    { name = "ITEMS", rows = {} },
    { name = "HIDDEN", perPage = 3, rows = { {}, {}, {}, {}, {} } },
  })
  assert(#pages == 4 and pages[1].name == "TRAINERS"
    and pages[2].name == "ITEMS" and pages[2].total == 0
    and pages[3].name == "HIDDEN" and pages[4].page == 2,
    "separate area checklist pages")
end
do
  local done, status = oneShotTrainerStatus(false, true, "lose")
  assert(done and status == "LOST"
    and oneShotTrainerStatus(false, true, nil)
    and not oneShotTrainerStatus(false, false, nil),
    "one-shot trainer outcomes")
end
do
  assert(compactClock("21:05") == "21:05"
    and compactClock("09:05 PM") == "9:05PM", "system clock format")
end
assert(Area.itemfinderNear(10, 10, 15, 14)
       and not Area.itemfinderNear(10, 10, 5, 10)
       and not Area.itemfinderNear(10, 10, 10, 15), "native itemfinder radius")
assert(not Area.itemfinderScanReached(10, 10, 15, 14, 0.5)
       and Area.itemfinderScanReached(10, 10, 15, 14, 1),
  "itemfinder map sweep reveals signals only after reaching them")
do
  local scale, x, y = localMapLayout(40, 36)
  assert(scale == 2 and x == 40 and y == 37,
         "local map fits the companion canvas")
  scale, x, y = localMapLayout(40, 36, 2, 20, 18)
  assert(scale == 3 and x == 20 and y == 19,
         "local map medium zoom follows the player")
  scale, x, y = localMapLayout(40, 36, 3, 20, 18)
  assert(scale == 4 and x == 0 and y == 1,
         "local map close zoom follows the player without empty edges")
  assert(localMapLayout(48, 196, 2, 24, 98, 4) == 1.5
    and localMapLayout(48, 196, 3, 24, 98, 4) == 2,
    "thin local maps keep useful medium and close zoom levels")
end
assert(localMapMode(false) == "off" and localMapMode(true) == "map"
       and localMapMode("enhanced") == "enhanced",
       "local map modes preserve the old toggle")
local _, gridWidth, gridHeight, gridDensity = localMapGrid({
  tileDetailRows = { "0" }, tileDetailWidth = 4, tileDetailHeight = 8,
})
local _, oldGridWidth, oldGridHeight, oldGridDensity = localMapGrid({
  tileRows = { "0" }, tileWidth = 2, tileHeight = 4,
})
assert(gridWidth == 4 and gridHeight == 8 and gridDensity == 4
       and oldGridWidth == 2 and oldGridHeight == 4 and oldGridDensity == 2,
       "local map grid compatibility")
assert(supportedBattleUI({ kind = "wild" })
       and supportedBattleUI({ battleKind = function() return "safari" end })
       and not supportedBattleUI({ kind = "link" })
       and not supportedBattleUI({ battleKind = function() return "oldman" end }),
       "safe battle UI ownership")
assert(savedSteps(nil) == 0 and savedSteps("42") == 42,
       "saved step counter")
assert(not hasUnlockedTool({})
       and hasUnlockedTool({ inventory = { BICYCLE = 1 } })
       and not hasUnlockedTool({ party = { { moves = { { id = "CUT" } } } } })
       and hasUnlockedTool({ inventory = { CASCADEBADGE = 1 },
         party = { { moves = { { id = "CUT" } } } } }), "tool unlock state")
assert(THEME.fieldTools.unlocked(THEME.fieldTools.widgets[5], {
         inventory = { CASCADEBADGE = 1 },
         party = { { moves = { { id = "CUT" } } } },
       }, false)
       and THEME.fieldTools.unlocked(THEME.fieldTools.widgets[5], {
         player = { badges = { HIVE = true } },
         party = { { moves = { { id = "CUT" } } } }, inventory = {},
       }, true)
       and not THEME.fieldTools.unlocked(THEME.fieldTools.widgets[5], {
         player = { badges = {} },
         party = { { moves = { { id = "CUT" } } } }, inventory = {},
       }, true), "quick tool widgets require the real move and badge unlock")
do
  local rows, by = {}, {}
  addEncounters(rows, by, { { species = "TEST", level = 3 },
    { species = "TEST", level = 5 } }, "WALK")
  addEncounters(rows, by, { { species = "TEST", level = 4 } }, "SURF")
  assert(#rows == 1 and rows[1].minLevel == 3 and rows[1].maxLevel == 5
    and #rows[1].methods == 2 and rows[1].methods[1].min == 100,
    "guide encounter merge")
end
do
  local rows, by = {}, {}
  addEncounters(rows, by, { { species = "TEST", level = 3 } },
    "WALK", nil, "MORN")
  addEncounters(rows, by, { { species = "TEST", level = 4 } },
    "WALK", nil, "DAY")
  assert(rows[1].times.MORN and rows[1].times.DAY
    and not rows[1].times.NITE and not rows[1].allTimes,
    "guide encounter time merge")
  addEncounters(rows, by, { { species = "TEST", level = 5 } }, "SURF")
  assert(rows[1].allTimes, "guide unrestricted encounter availability")
end
do
  local rows, by = {}, {}
  addEncounters(rows, by, {
    { species = "OTHER", level = 2 }, { species = "OTHER", level = 3 },
    { species = "OTHER", level = 4 }, { species = "WOBBUFFET", level = 5 },
    { species = "WOBBUFFET", level = 6 }, { species = "OTHER", level = 7 },
    { species = "OTHER", level = 8 },
  }, "WALK", { 30, 60, 80, 90, 95, 99, 100 },
    { time = "NITE", mapId = "DARK_CAVE_BLACKTHORN_ENTRANCE" })
  assert(by.WOBBUFFET.methods[1].min == 15
    and by.WOBBUFFET.appearances[1].chance == 15
    and by.WOBBUFFET.appearances[1].minLevel == 5
    and by.WOBBUFFET.appearances[1].maxLevel == 6,
    "Gen 2 guide uses native weighted encounter slots")
end
assert(not prepareBattleSnapshot({}, {})
       and prepareBattleSnapshot({ moveIndex = 1 }, { moveIndex = 2 })
       and prepareBattleSnapshot({ itemIndex = 1 }, { itemIndex = 2 })
       and prepareBattleSnapshot({ forgetIndex = 1 }, { forgetIndex = 2 })
       and prepareBattleSnapshot({ itemPocket = 1 }, { itemPocket = 2 })
       and prepareBattleSnapshot({ itemTitle = "MEDICINE" },
                              { itemTitle = "POKE BALLS" }),
       "battle focus sync")
assert(categorizedBag({ __pocketIndex = 1 })
       and categorizedBag({ modernBag = {} })
       and not categorizedBag({ screenId = "BagMenu" }),
       "categorized bag navigation")
do
  local state = {}
  assert(bottomOwnsBattleUI(true, true, true, true, state, {})
    and not bottomOwnsBattleUI(true, true, true, true, state, nil)
    and not bottomOwnsBattleUI(true, true, true, false, state, {})
    and not bottomOwnsBattleUI(true, true, false, true, state, {})
    and screenContract({ isPartyMenu = true, index = 1 })
    and screenContract({ screenId = "BagMenu", items = {}, index = 1 })
    and screenContract({ kind = "pp_item_move", items = {}, index = 1 })
    and screenContract({ onChoose = function() end, index = 1 })
    and screenContract({ mon = { stats = {} } })
    and not screenContract({ isPartyMenu = true })
    and not screenContract({ screenId = "BagMenu" })
    and not screenContract({ kind = "pp_item_move" })
    and not screenContract({ screenId = "TownMap" }),
    "stable upper battle UI ownership")
end

local FONT = {
  A="01110100011000111111100011000110001", B="11110100011000111110100011000111110",
  C="01111100001000010000100001000001111", D="11110100011000110001100011000111110",
  E="11111100001000011110100001000011111", F="11111100001000011110100001000010000",
  G="01111100001000010111100011000101110", H="10001100011000111111100011000110001",
  I="11111001000010000100001000010011111", J="00111000100001000010100101001001100",
  K="10001100101010011000101001001010001", L="10000100001000010000100001000011111",
  M="10001110111010110101100011000110001", N="10001110011010110011100011000110001",
  O="01110100011000110001100011000101110", P="11110100011000111110100001000010000",
  Q="01110100011000110001101011001001101", R="11110100011000111110101001001010001",
  S="01111100001000001110000010000111110", T="11111001000010000100001000010000100",
  U="10001100011000110001100011000101110", V="10001100011000110001100010101000100",
  W="10001100011000110101101011101110001", X="10001100010101000100010101000110001",
  Y="10001100010101000100001000010000100", Z="11111000010001000100010001000011111",
  ["0"]="01110100011001110101110011000101110",
  ["1"]="00100011000010000100001000010001110",
  ["2"]="01110100010000100010001000100011111",
  ["3"]="11110000010000101110000010000111110",
  ["4"]="00010001100101010010111110001000010",
  ["5"]="11111100001000011110000010000111110",
  ["6"]="01110100001000011110100011000101110",
  ["7"]="11111000010001000100010000100001000",
  ["8"]="01110100011000101110100011000101110",
  ["9"]="01110100011000101111000010000101110",
  [":"]="00000001000010000000001000010000000",
  ["."]="00000000000000000000000000000000100",
  [","]="00000000000000000000000000010001000",
  ["'"]="00100001000000000000000000000000000",
  ["("]="00010001000100001000010000010000010",
  [")"]="01000001000001000010000100010001000",
  ["-"]="00000000000000011111000000000000000",
  ["/"]="00001000100010001000100001000000000",
  ["+"]="00000001000010011111001000010000000",
  ["%"]="11001110100010001000101101100100000",
  ["?"]="01110100010001000100001000000000100",
  ["<"]="00010001000100010000010000010000010",
  [">"]="01000001000001000001000100010001000",
  ["!"]="00100001000010000100001000000000100",
  ["Ä"]="10001000000111010001111111000110001",
  ["Ö"]="10001000000111010001100011000101110",
  ["Ü"]="10001000001000110001100011000101110",
  ["À"]="01000001000111010001111111000110001",
  ["Â"]="00100010100111010001111111000110001",
  ["Ç"]="01111100001000010000100000111000100",
  ["Á"]="00010001000111010001111111000110001",
  ["È"]="01000001001111110000111101000011111",
  ["É"]="00010001001111110000111101000011111",
  ["Ê"]="00100010101111110000111101000011111",
  ["Ë"]="01010000001111110000111101000011111",
  ["Í"]="00010001001111100100001000010011111",
  ["Î"]="00100010101111100100001000010011111",
  ["Ï"]="01010000001111100100001000010011111",
  ["Ó"]="00010001000111010001100011000101110",
  ["Ô"]="00100010100111010001100011000101110",
  ["Ú"]="00010001001000110001100011000101110",
  ["Ù"]="01000001001000110001100011000101110",
  ["Û"]="00100010101000110001100011000101110",
  ["Ÿ"]="01010000001000101010001000010000100",
  ["Ñ"]="01010101001000111001101011001110001",
  ["¿"]="00100000000010000100010001000101110",
  ["¡"]="00100000000010000100001000010000100",
}

local function color(c) G.setColor(c[1], c[2], c[3], c[4]) end

local function box(mode, x, y, w, h, c)
  color(c)
  G.rectangle(mode, x, y, w, h)
end

local function glyphList(value)
  local out, index = {}, 1
  while index <= #value do
    local first = value:byte(index)
    local size = first < 0x80 and 1 or first < 0xE0 and 2
      or first < 0xF0 and 3 or 4
    out[#out + 1] = value:sub(index, index + size - 1)
    index = index + size
  end
  return out
end

local function normalize(value)
  value = value:upper()
    :gsub("ä", "Ä"):gsub("ö", "Ö"):gsub("ü", "Ü")
    :gsub("ẞ", "SS"):gsub("ß", "SS")
    :gsub("à", "À"):gsub("â", "Â"):gsub("ç", "Ç")
    :gsub("è", "È"):gsub("ê", "Ê"):gsub("ë", "Ë")
    :gsub("î", "Î"):gsub("ï", "Ï"):gsub("ô", "Ô")
    :gsub("ù", "Ù"):gsub("û", "Û"):gsub("ÿ", "Ÿ")
    :gsub("á", "Á"):gsub("é", "É"):gsub("í", "Í")
    :gsub("ó", "Ó"):gsub("ú", "Ú"):gsub("ñ", "Ñ")
    :gsub("_", " ")
  local out = {}
  for _, glyph in ipairs(glyphList(value)) do
    if glyph == " " or FONT[glyph] then out[#out + 1] = glyph end
  end
  return table.concat(out)
end

local function clean(value)
  value = THEME:translate(tostring(value or ""))
    :gsub("<PK><MN>", "PKMN")
  return normalize(value)
end

assert(normalize("40%") == "40%"
       and normalize("POKé BALL") == "POKÉ BALL",
       "text glyph normalization")
assert(normalize("Ärger über Größe") == "ÄRGER ÜBER GRÖSSE",
       "German glyph normalization")
assert(normalize("¿árbol, pingüino y niño? ¡Sí!")
       == "¿ÁRBOL, PINGÜINO Y NIÑO? ¡SÍ!"
       and normalize("áéíóúüñ") == "ÁÉÍÓÚÜÑ",
       "Spanish glyph normalization")
assert(normalize("ça coûte très cher à Noël, même au-delà du sûr")
       == "ÇA COÛTE TRÈS CHER À NOËL, MÊME AU-DELÀ DU SÛR",
       "French glyph normalization")

local function fit(value, chars, ellipsis)
  local glyphs = glyphList(clean(value))
  if #glyphs <= chars then return table.concat(glyphs) end
  if ellipsis == false then return table.concat(glyphs, "", 1, chars) end
  local out = {}
  for index = 1, math.max(0, chars - 1) do out[index] = glyphs[index] end
  out[#out + 1] = "."
  return table.concat(out)
end

function THEME:messageLines(messages, chars, limit)
  local function wrap(message)
    local lines, current = {}, ""
    for word in clean(message):gmatch("%S+") do
      local joined = current == "" and word or current .. " " .. word
      if #glyphList(joined) <= chars then current = joined
      else
        if current ~= "" then lines[#lines + 1] = current end
        local glyphs = glyphList(word)
        while #glyphs > chars do
          lines[#lines + 1] = table.concat(glyphs, "", 1, chars)
          for _ = 1, chars do table.remove(glyphs, 1) end
        end
        current = table.concat(glyphs)
      end
    end
    if current ~= "" then lines[#lines + 1] = current end
    return lines
  end

  limit = limit or 2
  local count, out = #(messages or {}), {}
  local latest = wrap(messages and messages[count])
  if #latest > 1 then
    for index = 1, math.min(#latest, limit) do out[index] = latest[index] end
    if latest[limit + 1] then
      out[limit] = fit(out[limit] .. " " .. latest[limit + 1], chars)
    end
    return out
  end
  for index = math.max(1, count - limit + 1), count do
    local lines = wrap(messages[index])
    out[#out + 1] = fit(lines[#lines] or "", chars)
  end
  return out
end

do
  local lines = THEME:messageLines(
    { "OLD", "GOTCHA! HOOTHOOT WAS CAUGHT!" }, 22)
  assert(lines[1] == "GOTCHA! HOOTHOOT WAS" and lines[2] == "CAUGHT!",
         "battle message word wrapping")
  lines = THEME:messageLines(
    { "OLD", "RATTATA USED", "TAIL WHIP!" }, 22)
  assert(lines[1] == "RATTATA USED" and lines[2] == "TAIL WHIP!",
         "battle message line preservation")
  lines = THEME:messageLines(
    { "THIS MESSAGE IS LONG ENOUGH TO REQUIRE THREE DISPLAY LINES" }, 22)
  assert(lines[1] == "THIS MESSAGE IS LONG"
         and lines[2] == "ENOUGH TO REQUIRE THR.",
         "battle message overflow")
  lines = THEME:messageLines({ "ABCDEFGHIJKLMNOPQRSTUVWXYZ" }, 10, 3)
  assert(lines[1] == "ABCDEFGHIJ" and lines[2] == "KLMNOPQRST"
         and lines[3] == "UVWXYZ", "battle message long-word wrapping")
end

local function methodLines(methods)
  local lines = { "" }
  for _, odds in ipairs(methods) do
    local chance = odds.min == odds.max and tostring(odds.min)
      or (odds.min .. "-" .. odds.max)
    local label = THEME:translate(odds.name)
    local chanceText = chance .. "%"
    local method = THEME:format("%s %s", label, chanceText)
    local joined = lines[#lines] == "" and method
      or lines[#lines] .. "/" .. method
    if #glyphList(clean(joined)) <= 14 then
      lines[#lines] = joined
    elseif lines[#lines] == "" then
      lines[#lines] = fit(label, 14)
      lines[#lines + 1] = chanceText
    elseif #lines < 2 then
      if #glyphList(clean(method)) <= 14 then
        lines[#lines + 1] = method
      else
        local labelChars = 13 - #glyphList(chanceText)
        lines[#lines + 1] = fit(label, labelChars) .. " " .. chanceText
      end
    end
  end
  return lines[1] or "", lines[2] or ""
end

local function text(value, x, y, c, scale)
  value, scale = clean(value), scale or 1
  color(c)
  local cursor = x
  for _, character in ipairs(glyphList(value)) do
    local glyph = FONT[character]
    if glyph then
      for row = 0, 6 do
        for column = 0, 4 do
          if glyph:sub(row * 5 + column + 1, row * 5 + column + 1) == "1" then
            G.rectangle("fill", cursor + column * scale, y + row * scale,
                        scale, scale)
          end
        end
      end
    end
    cursor = cursor + 6 * scale
  end
end

local function centered(value, y, c, scale)
  value, scale = clean(value), scale or 1
  text(value, math.floor((WIDTH - #glyphList(value) * 6 * scale) / 2),
       y, c, scale)
end

local function outline(x, y, w, h, c)
  c = c or INK
  if THEME.style == "classic" or w < 5 or h < 5 then
    box("line", x + 0.5, y + 0.5, w - 1, h - 1, c)
    return
  end
  box("fill", x + 2, y, w - 4, 1, c)
  box("fill", x + 2, y + h - 1, w - 4, 1, c)
  box("fill", x, y + 2, 1, h - 4, c)
  box("fill", x + w - 1, y + 2, 1, h - 4, c)
  box("fill", x + 1, y + 1, 1, 1, c)
  box("fill", x + w - 2, y + 1, 1, 1, c)
  box("fill", x + 1, y + h - 2, 1, 1, c)
  box("fill", x + w - 2, y + h - 2, 1, 1, c)
end

function THEME:drawMapMarker(x, y)
  x, y = math.floor(x + 0.5), math.floor(y + 0.5)
  box("fill", x - 3, y - 3, 7, 7, INK)
  box("fill", x - 2, y - 2, 5, 5, PAPER)
  box("fill", x - 1, y - 1, 3, 3, self.red)
end

local function hpBar(x, y, w, hp, maxHp)
  local ratio = progressRatio(hp, 0, math.max(1, maxHp or 1))
  box("fill", x, y, w, 4, DARK)
  box("fill", x + 1, y + 1, math.floor((w - 2) * ratio), 2,
      ratio > 0.5 and PAPER or ratio > 0.2 and MID or INK)
end

local function expBar(x, y, w, ratio, selected)
  box("fill", x, y, w, 3, DARK)
  box("fill", x + 1, y + 1, math.floor((w - 2) * ratio), 1,
      selected and MID or PAPER)
end

local function button(x, y, w, h, label, selected)
  if THEME.style == "hgss" then
    THEME.hgss:button(x, y, w, h, label, selected, 1, 4 / 3)
    return
  end
  local modern = THEME.style ~= "classic"
  box("fill", x, y, w, h, modern and selected and THEME.red
    or selected and DARK or MID)
  outline(x, y, w, h, modern and THEME.blue or INK)
  if modern and selected then
    box("fill", x + 2, y + 2, 2, math.max(1, h - 4), THEME.white)
  end
  local c = modern and selected and THEME.white
    or selected and PAPER or INK
  local shown = fit(label, math.floor((w - 8) / 6))
  text(shown, x + math.max(4,
       math.floor((w - #glyphList(shown) * 6) / 2)),
       y + math.floor((h - 7) / 2), c)
end

local function inside(x, y, left, top, width, height)
  return x >= left and x < left + width and y >= top and y < top + height
end

THEME.gen2Badges = {
  johto = { "ZEPHYR", "HIVE", "PLAIN", "FOG", "STORM", "MINERAL",
    "GLACIER", "RISING" },
  kanto = { "BOULDER", "CASCADE", "THUNDER", "RAINBOW", "SOUL", "MARSH",
    "VOLCANO", "EARTH" },
  oam = { ZEPHYR = 1, HIVE = 2, PLAIN = 3, FOG = 4, MINERAL = 5,
    STORM = 6, GLACIER = 7, RISING = 8 },
}

return function(mod)
  THEME.strings = mod.content.strings

  local RADAR_FRAMES = 16
  local function compactSteps(value)
    if value < 100000 then return tostring(value) end
    if value < 10000000 then
      return THEME:format("%dK", math.floor(value / 1000))
    end
    return THEME:format("%dM", math.floor(value / 1000000))
  end
  assert(compactSteps(99999) == "99999"
    and compactSteps(100000) == "100K"
    and compactSteps(10000000) == "10M", "compact step count")

  local infoDefault = mod.options:get("info_level")
  if infoDefault == nil then
    local legacyProfile = mod.options:get("profile")
    infoDefault = legacyProfile == "custom" and "legacy"
      or legacyProfile == "purist" and "purist" or "enhanced"
  end
  local infoChoices = {
    { "PURIST", "purist" }, { "ENHANCED", "enhanced" },
  }
  if infoDefault == "legacy" then
    infoChoices[#infoChoices + 1] = { "SAVED CUSTOM", "legacy" }
  end

  local battleDefault = mod.options:get("battle_view")
  if battleDefault == nil then
    battleDefault = battleUIMode(mod.options:get("hide_upper_battle_ui"),
                                 mod.options:get("full_bottom_battle_ui"))
  end

  THEME.displayModeDefault, THEME.combinedLayoutDefault = THEME:displayDefaults(
    function(key) return mod.options:get(key) end)

  mod.options:define({
    { key = "theme", label = "THEME", type = "choice",
      default = "kanto", choices = {
        { "KANTO GREEN", "kanto" }, { "MATCH GAME", "match" },
        { "HGSS LIGHT", "hgss" }, { "HGSS DARK", "hgss_dark" },
        { "MODERN LIGHT", "modern_light" },
        { "MODERN DARK", "modern_dark" },
        { "OG", "og" }, { "OG INVERTED", "og_inv" },
        { "SGB", "sgb" }, { "ADVANCED", "advanced" },
        { "VERSION COLOR", "version" },
      } },
    { key = "clock_source", label = "CLOCK", type = "choice",
      default = "game", choices = {
        { "GAME", "game" }, { "SYSTEM", "system" },
      } },
    { key = "info_level", label = "INFO", type = "choice",
      default = infoDefault, choices = infoChoices },
    { key = "local_map", label = "AREA MAP",
      type = "choice", default = false, choices = {
        { "OFF", false }, { "MAP", true }, { "ENHANCED", "enhanced" },
      } },
    { key = "display_mode", label = "DISPLAY MODE", type = "choice",
      default = THEME.displayModeDefault, choices = {
        { "FULLSCREEN SWAP", "fullscreen" },
        { "COMBINED SCREEN", "combined" },
        { "SEPARATE SCREENS", "separate" },
      } },
    { key = "fullscreen_start", label = "START SCREEN", type = "choice",
      default = "game", visible_if = {
        key = "display_mode", equals = "fullscreen",
      }, choices = {
        { "GAME", "game" }, { "GEAR", "gear" },
      } },
    { key = "combined_layout", label = "LAYOUT", type = "choice",
      default = THEME.combinedLayoutDefault, visible_if = {
        key = "display_mode", equals = "combined",
      }, choices = {
        { "AUTO", "auto" }, { "STACKED", "stacked" },
        { "SIDE BY SIDE", "side" }, { "OVERLAY", "overlay" },
      } },
    { key = "combined_primary", label = "PRIMARY VIEW", type = "choice",
      default = "game", visible_if = {
        key = "display_mode", equals = "combined",
      }, choices = {
        { "GAME", "game" }, { "GEAR", "gear" },
      } },
    { key = "secondary_size", label = "SECONDARY SIZE", type = "choice",
      default = "auto", visible_if = {
        key = "display_mode", equals = "combined",
      }, choices = {
        { "AUTO", "auto" }, { "20%", 20 }, { "25%", 25 },
        { "30%", 30 }, { "35%", 35 }, { "40%", 40 },
        { "45%", 45 }, { "50%", 50 }, { "55%", 55 },
        { "60%", 60 }, { "65%", 65 }, { "70%", 70 },
        { "75%", 75 }, { "80%", 80 },
      } },
    { key = "overlay_corner", label = "OVERLAY CORNER", type = "choice",
      default = "bottom_right", visible_if = {
        key = "display_mode", equals = "combined",
      }, choices = {
        { "TOP LEFT", "top_left" }, { "TOP RIGHT", "top_right" },
        { "BOTTOM LEFT", "bottom_left" },
        { "BOTTOM RIGHT", "bottom_right" },
      } },
    { key = "overlay_button", label = "OVERLAY BUTTON", type = "choice",
      default = "off", visible_if = {
        key = "display_mode", equals = "combined",
      }, choices = {
        { "OFF", "off" }, { "R3", "rightstick" },
        { "L3", "leftstick" }, { "F7", "f7" },
      } },
    { key = "display_target", label = "GEAR OUTPUT", type = "choice",
      default = "auto", choices = {
        { "AUTO", "auto" }, { "MAIN SCREEN", "handheld" },
        { "SECOND SCREEN", "secondary" },
      }, visible_if = {
        key = "display_mode", equals = "separate",
      } },
    { key = "screen_swap", label = "QUICK SWAP (Y)",
      type = "toggle", default = false, visible_if = {
        key = "display_mode", not_equals = "fullscreen",
      } },
    { key = "battle_view", label = "BATTLE VIEW",
      type = "choice", default = battleDefault, choices = {
        { "STANDARD", "standard" }, { "GEAR", "gear" },
        { "FULL GEAR", "full" }, { "INFO", "info" },
      } },
    { key = "caught_icon", label = "CAUGHT ICON",
      type = "toggle", default = true },
    { key = "trigger_tabs", label = "TRIGGER TABS",
      type = "toggle", default = false },
  })

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" or not mod.find("gen1_modern_ui") then return out end
    return mod.ui.insertBefore(out, "MODS", {
      id = mod.id .. ".options",
      label = "KANTO GEAR",
      onSelect = function()
        local manager = mod.ui.push(game, "ManagerState")
        local own = manager.byId and manager.byId[mod.id]
        if own and manager.openOptions then manager:openOptions(own) end
      end,
    })
  end)

  local function assist(key)
    local level = mod.options:get("info_level")
    if level == "legacy" then
      return assistEnabled("custom", mod.options:get(key))
    end
    return level ~= "purist"
  end
  local function currentBattleUIMode()
    return mod.options:get("battle_view") or "standard"
  end
  local function fullBottomBattleUI()
    return currentBattleUIMode() == "full"
  end
  local function hideUpperBattleUI()
    local mode = currentBattleUIMode()
    return mode == "gear" or mode == "full"
  end
  local displayRuntime = {
    explorer = {
      page = 1, mapFull = false, mapZoom = 1,
      filters = { wildScope = "HERE" },
      scanRevealed = {},
    },
    pokedex = { view = "index", page = 1, habitatPage = 1 },
    bag = { pocket = 1, page = 1, pending = nil },
  }
  function displayRuntime.pcStateKey(state)
    if not state then return "" end
    local qty, confirm, pack, message = state.qtyState, state.confirm,
      state.pack, state.message
    return table.concat({
      tostring(state.index), tostring(state.pickIndex),
      tostring(state.listIndex), tostring(state.boxIndex),
      tostring(state.scroll), tostring(state.phase), tostring(state.mode),
      tostring(state.picking), tostring(state.savePhase),
      tostring(state.saveChoice), tostring(state.submenuIndex),
      tostring(state.message), tostring(state.messagePage),
      tostring(type(message) == "table" and message.page),
      tostring(qty and qty.qty), tostring(qty and qty.max),
      tostring(confirm and confirm.choice),
      tostring(pack and pack.index), tostring(pack and pack.pocketIndex),
      tostring(pack and pack.__gen3uiBagPocketIndex),
    }, ":")
  end
  assert(displayRuntime.pcStateKey({ pickIndex = 2 })
      ~= displayRuntime.pcStateKey({ pickIndex = 3 })
      and displayRuntime.pcStateKey({ listIndex = 1 })
        ~= displayRuntime.pcStateKey({ listIndex = 2 })
      and displayRuntime.pcStateKey({ qtyState = { qty = 1 } })
        ~= displayRuntime.pcStateKey({ qtyState = { qty = 2 } })
      and displayRuntime.pcStateKey({ message = { page = 1 } })
        ~= displayRuntime.pcStateKey({ message = { page = 2 } }),
    "PC redraw key follows every native cursor")
  function displayRuntime.adjustExplorerZoom(direction)
    local explorer = displayRuntime.explorer
    local current = math.max(1, math.min(3, explorer.mapZoom or 1))
    explorer.mapZoom = math.max(1, math.min(3, current + direction))
    return explorer.mapZoom ~= current
  end
  assert(not displayRuntime.adjustExplorerZoom(-1)
      and displayRuntime.adjustExplorerZoom(1)
      and displayRuntime.explorer.mapZoom == 2,
    "Explorer fullscreen zoom clamps and advances")
  displayRuntime.explorer.mapZoom = 1
  local function inlineDisplay()
    return THEME:displayMode(mod.options) ~= "separate"
  end
  local function bottomOnHandheld()
    local handheld = mod.options:get("display_target") == "handheld"
    if displayRuntime.swapped then return not handheld end
    return handheld
  end
  local function displayPreference()
    if displayRuntime.swapped then
      return bottomOnHandheld() and "handheld" or "secondary"
    end
    return mod.options:get("display_target")
  end

  local runtime = rawget(_G, "love")
  G = runtime and runtime.graphics
  if not G then
    mod.log:warn("host has no graphics runtime; mod stays inactive")
    return
  end

  if runtime.filesystem and runtime.filesystem.newFileData then
    THEME.hgssFont = runtime.filesystem.newFileData(
      mod:read("rounded_mplus.ttf"), "rounded_mplus.ttf")
    THEME.hgssBagIcon = G.newImage(runtime.filesystem.newFileData(
      mod:read("kanto_bag.png"), "kanto_bag.png"))
    THEME.hgssBagIcon:setFilter("nearest", "nearest")
  end
  THEME.hgss = assert(load(mod:read("hgss.lua"), "@kanto_gear/hgss.lua"))()({
    graphics = G, box = box, text = text, fit = fit,
    glyphs = glyphList, color = color, font = THEME.hgssFont,
    bagIcon = THEME.hgssBagIcon,
    translate = function(value) return THEME:translate(value) end,
    format = function(value, ...) return THEME:format(value, ...) end,
  })
  assert(THEME.hgss:battleChoice(120, 80) == 1
      and THEME.hgss:battleChoice(200, 170) == 2
      and THEME.hgss:battleChoice(40, 170) == 3
      and THEME.hgss:battleChoice(120, 185) == 4,
    "HGSS battle action hitboxes")
  assert(THEME.hgss.battleActions[2].w == THEME.hgss.battleActions[3].w
      and THEME.hgss.battleActions[3].w == THEME.hgss.battleActions[4].w
      and THEME.hgss.battleActions[2].h == THEME.hgss.battleActions[3].h
      and THEME.hgss.battleActions[3].h == THEME.hgss.battleActions[4].h,
    "HGSS secondary battle actions share one size")
  assert(THEME.hgss:partySlot(4, 22, 6) == 1
      and THEME.hgss:partySlot(82, 25, 6) == 2
      and THEME.hgss:partySlot(4, 60, 6) == 3
      and THEME.hgss:partySlot(82, 101, 5) == nil,
    "HGSS party hitboxes follow staggered cards")

  displayRuntime.Home = assert(load(mod:read("home_layout.lua"),
    "@kanto_gear/home_layout.lua"))()
  displayRuntime.homeCatalog = {
    packages = {
      explorer = { installed = true, fixed = true },
      map = { installed = true, fixed = true },
      party = { installed = true, fixed = true },
      trainer = { installed = true, fixed = true },
      steps = { installed = true, defaultInstalled = true },
      tools = { installed = true, defaultInstalled = true },
      store = { installed = true, fixed = true },
      bag = { installed = false },
      pokedex = { installed = false },
      notes = { installed = false, available = false },
    },
    surfaces = {
      explorer_widget = { package = "explorer", kind = "widget",
        widget = "explorer", columns = 7, label = "EXPLORER" },
      party_widget = { package = "party", kind = "widget",
        widget = "party", columns = 5, label = "PARTY" },
      pokedex_widget = { package = "pokedex", kind = "widget",
        widget = "pokedex", columns = 5, label = "POKEDEX" },
      trainer_widget = { package = "trainer", kind = "widget",
        widget = "trainer", columns = 5, label = "TRAINER" },
      map_widget = { package = "map", kind = "widget",
        widget = "map", columns = 7, label = "MAP" },
      bag_widget = { package = "bag", kind = "widget",
        widget = "bag", columns = 5, label = "BAG" },
      store_widget = { package = "store", kind = "widget",
        widget = "store", columns = 5, label = "STORE" },
      explorer_app = { package = "explorer", kind = "app", columns = 3,
        icon = "explorer", accent = "green", label = "EXPLORER" },
      map_app = { package = "map", kind = "app", columns = 3,
        icon = "map", accent = "blue", label = "MAP" },
      party_app = { package = "party", kind = "app", columns = 3,
        icon = "party", accent = "green", label = "PARTY" },
      trainer_app = { package = "trainer", kind = "app", columns = 3,
        icon = "trainer", accent = "blue", label = "TRAINER" },
      steps_widget = { package = "steps", kind = "widget",
        widget = "steps", columns = 5, label = "STEPS" },
      steps_app = { package = "steps", kind = "app", columns = 3,
        icon = "steps", accent = "green", label = "STEPS" },
      tools_app = { package = "tools", kind = "app", columns = 3,
        icon = "tools", accent = "green", label = "TOOLS" },
      store_app = { package = "store", kind = "app", columns = 3,
        icon = "store", accent = "green", label = "STORE" },
      bag_app = { package = "bag", kind = "app", columns = 3,
        icon = "bag", accent = "amber", label = "BAG" },
      pokedex_app = { package = "pokedex", kind = "app", columns = 3,
        icon = "pokedex", accent = "red", label = "POKEDEX" },
      notes_app = { package = "notes", kind = "app", columns = 3,
        icon = "notes", accent = "amber", label = "NOTES" },
    },
  }
  for _, def in ipairs(THEME.fieldTools.widgets) do
    displayRuntime.homeCatalog.surfaces["tool_widget_" .. def.key] = {
      package = "tools", kind = "widget", widget = "tool", columns = 3,
      label = def.key:upper():gsub("_", " "), icon = def.icon,
      actionId = def.action, rodId = def.rod, toolKey = def.key,
      hidden = true, ready = false,
    }
  end
  displayRuntime.storeCatalog = {
    { id = "explorer", icon = "explorer", label = "EXPLORER",
      category = "ADVENTURE", target = "LOCAL", fixed = true,
      description = { "EXPLORE THE AREA AROUND YOU.",
        "FIND POKEMON, ITEMS AND TRAINERS.", "YOUR ROUTE, IN ONE PLACE." } },
    { id = "map", icon = "map", label = "MAP",
      category = "NAVIGATION", reason = "REGION MAP",
      target = "MAP", fixed = true,
      description = { "VIEW THE REGION MAP.",
        "SEE WHERE YOUR JOURNEY HAS LED.", "YOUR POSITION, AT A GLANCE." } },
    { id = "party", icon = "party", label = "PARTY",
      category = "TEAM", reason = "TEAM STATUS",
      target = "PARTY", fixed = true,
      description = { "CHECK YOUR TEAM AT A GLANCE.",
        "VIEW STATS, MOVES AND STATUS.", "KEEP EVERY PARTNER READY." } },
    { id = "pokedex", icon = "pokedex", label = "POKEDEX",
      category = "RESEARCH", reason = "DEX RESEARCH", target = "POKEDEX",
      featured = true, new = true,
      description = { "RESEARCH EVERY SPECIES.",
        "CHECK STATS, MOVES AND HABITATS.", "YOUR FIELD ENCYCLOPEDIA." } },
    { id = "bag", icon = "bag", label = "BAG",
      category = "ITEMS", reason = "ITEM POCKETS", target = "BAG",
      description = { "BROWSE EVERY ITEM BELOW.",
        "USE THE ORIGINAL GAME EFFECTS.", "NO MIRRORED BAG REQUIRED." } },
    { id = "trainer", icon = "trainer", label = "TRAINER CARD",
      category = "PROFILE", target = "TRAINER", fixed = true,
      description = { "REVIEW YOUR TRAINER JOURNEY.",
        "BADGES, PLAY TIME AND PROGRESS.", "YOUR ADVENTURE, AT A GLANCE." } },
    { id = "steps", icon = "steps", label = "STEP COUNTER",
      category = "TRAINER TOOL", target = "STEPS",
      description = { "COUNT EVERY STEP OF YOUR JOURNEY.",
        "KEEP THE TOTAL ON YOUR HOME SCREEN.", "ONE SMALL STEP AT A TIME." } },
    { id = "tools", icon = "tools", label = "TOOLS",
      category = "FIELD KIT", target = "TOOLS",
      description = { "USE FIELD MOVES AND GEAR.",
        "KEEP UNLOCKED TOOLS CLOSE.", "READY WHEN THE ROUTE NEEDS IT." } },
    { id = "notes", icon = "notes", label = "NOTES",
      category = "TRAINER TOOL", available = false,
      description = { "PLAN ROUTES AND REMINDERS.",
        "KEEP CLUES CLOSE AT HAND.", "COMING SOON FROM SILPH LABS." } },
  }
  displayRuntime.storeById = {}
  for _, app in ipairs(displayRuntime.storeCatalog) do
    displayRuntime.storeById[app.id] = app
  end
  displayRuntime.home = {
    page = 1, storeView = "today", storePages = {}, libraryKind = "app",
  }
  displayRuntime.defaultHomeTiles = {
    { id = "explorer_widget", page = 1, column = 1, row = 1 },
    { id = "party_widget", page = 1, column = 8, row = 1 },
    { id = "trainer_app", page = 1, column = 1, row = 2 },
    { id = "tools_app", page = 1, column = 4, row = 2 },
    { id = "store_app", page = 1, column = 7, row = 2 },
    { id = "party_app", page = 1, column = 10, row = 2 },
  }

  local PaletteFX = require("src.render.PaletteFX")
  local PokemonSprites = require("src.pokemon.Sprites")
  local EngineFont = mod.ui.Font

  local canvas = G.newCanvas(WIDTH, HEIGHT, { dpiscale = 1 })
  canvas:setFilter("nearest", "nearest")
  local game
  local companion
  local active = false
  local dirty = true
  local readbackPending = false
  local gameReadbackPending = false
  local gameReadbackCanvas
  local gameCaptureCanvas
  local nextGameCapture = 0
  local primaryBottomRect
  THEME.nativeWindowLayout = nil
  local page = "MAP"
  local trainerStepsOpen = false
  local localMapZoom = 1
  local guidePage = 1
  local areaPage = 1
  local radarOpen = false
  local radarFrame = 0
  local radarStarted = 0
  local tools = {}
  local toolsKey = ""
  local steps = 0
  local mapId = nil
  local mapAsset = nil
  local localMap = nil
  local localMapImage = nil
  local spriteCache = {}
  local touchDown = nil
  local textSpeedToken
  local textSpeedReleasePending = false
  local battle = nil
  local moveInfo = nil
  local battleInfoDetail = nil
  local intentId = 0
  local nextPoll = 0
  local nextClock = 0
  local batteryAnimated = false
  local lastScreenKey = nil
  local worldStarted = false
  local externalLoading = false
  local pendingFly = nil
  local pendingAction = nil
  local fieldChoice = nil
  local partyMoveFrom = nil
  local partyActionSlot = nil
  local hgssRuntime = {}
  displayRuntime.motion = { duration = 0.16 }
  local choiceTop = nil
  local choiceReadyAt = 0
  local choiceNudgeUntil = 0
  local choiceCommitted = nil
  local loggedTick = false
  local loggedPresent = false
  local bridgeWarned = false
  local displayReady = false
  local nextPresentAttempt = 0
  local themeKey = nil

  function hgssRuntime.beginAnimation(kind, data)
    if THEME.style ~= "hgss" then return end
    data = data or {}
    data.kind, data.queued = kind, love.timer.getTime()
    data.started = nil
    data.duration = data.duration or 0.34
    hgssRuntime.animation, dirty = data, true
  end

  function hgssRuntime.progress(kind)
    local animation = hgssRuntime.animation
    if not (animation and animation.kind == kind) then return nil end
    if not animation.started then
      animation.started = love.timer.getTime()
      return 0
    end
    return math.max(0, math.min(1,
      (love.timer.getTime() - animation.started) / animation.duration))
  end

  function hgssRuntime.partySubmenuActions(menu)
    local submenu = type(menu and menu.submenu) == "table" and menu.submenu
      or nil
    local items = menu and (menu.subItems or (submenu and submenu.items)) or {}
    local actions = {}
    for index = 1, math.min(2, #items) do
      actions[#actions + 1] = { index = index, item = items[index] }
    end
    return actions, submenu
  end

  function hgssRuntime.rootDirection(index, direction)
    local targets = {
      [1] = { left = 3, right = 2, up = 1, down = 4 },
      [2] = { left = 4, right = 2, up = 1, down = 2 },
      [3] = { left = 3, right = 4, up = 1, down = 3 },
      [4] = { left = 3, right = 2, up = 1, down = 4 },
    }
    return (targets[index] or targets[1])[direction]
  end

  assert(hgssRuntime.rootDirection(1, "left") == 3
      and hgssRuntime.rootDirection(1, "down") == 4
      and hgssRuntime.rootDirection(3, "right") == 4
      and hgssRuntime.rootDirection(4, "right") == 2
      and hgssRuntime.rootDirection(2, "up") == 1,
    "HGSS battle root navigation follows its visible geometry")

  local compat = { screens = {
    party = { PartyMenu = true, Gen2PartyMenu = true },
    summary = { SummaryMenu = true, Gen2SummaryMenu = true },
    bag = { BagMenu = true, Gen2PackMenu = true },
    naming = { NamingScreen = true, Gen2NamingScreen = true },
    pokemonPc = { BoxMenu = true, Gen2CenterPcMenu = true, Gen2PcMenu = true },
    itemPc = { PlayerPC = true, Gen2ItemPcMenu = true },
    trainerCard = { TrainerCard = true, Gen2TrainerCard = true },
  } }
  compat.bagViews = setmetatable({}, { __mode = "k" })
  compat.bagLabels = { "ITEMS", "BALLS", "KEY", "TM/HM" }

  function compat.levelUpMon(state)
    if state and type(state.mon) == "table"
        and type(state.mon.stats) == "table" and not state.screenId then
      return state.mon
    end
    if state and state.screenId == "Gen2BattleState"
        and state.phase == "stats-box" then
      local mon = state.statsBoxMon
      return type(mon) == "table" and type(mon.stats) == "table" and mon or nil
    end
  end

  function compat.isBattleScreen(state)
    return state and (state.isBattleState
      or state.screenId == "Gen2BattleState") or false
  end

  do
    local mon = { stats = {} }
    assert(compat.levelUpMon({ screenId = "Gen2BattleState",
                              phase = "stats-box", statsBoxMon = mon }) == mon
           and not compat.levelUpMon({ screenId = "Gen2BattleState",
                                       phase = "menu", statsBoxMon = mon })
           and compat.isBattleScreen({ screenId = "Gen2BattleState" }),
           "shared level-up and battle-screen detection")
  end
  compat.summary = assert(load(mod:read("summary.lua"),
    "@kanto_gear/summary.lua"))()

  function compat.isGen2()
    return game and game.save and game.save.generation == 2
  end

  function compat.timePeriod(world)
    local period = world and tostring(world.tod or world.daytime or ""):upper()
    if period == "DARK" then period = "NITE" end
    return (period == "MORN" or period == "DAY" or period == "NITE")
      and period or nil
  end
  assert(compat.timePeriod({ daytime = "day" }) == "DAY"
    and compat.timePeriod({ tod = "DARK" }) == "NITE"
    and compat.timePeriod({}) == nil, "Gen 2 time period labels")

  function compat.clockTimestamp(currentGame, source, now)
    if source ~= "game" or not (currentGame and currentGame.save
        and currentGame.save.generation == 2) then return now end
    local world = currentGame.world
    if not (world and type(world.hour) == "function"
        and type(world.minute) == "function") then return now end
    local okHour, hour = pcall(world.hour, world)
    local okMinute, minute = pcall(world.minute, world)
    local current = os.date("*t", now)
    if not (okHour and okMinute and type(hour) == "number"
        and type(minute) == "number" and type(current) == "table") then
      return now
    end
    current.hour, current.min, current.sec = hour % 24, minute % 60, 0
    local ok, timestamp = pcall(os.time, current)
    return ok and timestamp or now
  end
  assert(os.date("%H:%M", compat.clockTimestamp({
      save = { generation = 2 }, world = {
        hour = function() return 21 end,
        minute = function() return 5 end,
      } }, "game", os.time({ year = 2026, month = 1, day = 15,
        hour = 12, min = 34, sec = 56 }))) == "21:05"
    and compat.clockTimestamp({ save = { generation = 1 } }, "game", 123) == 123
    and compat.clockTimestamp({ save = { generation = 2 } }, "game", 123) == 123,
    "game clock source with safe fallback")

  compat.romCodes = {
    red = "RD", blue = "BL", yellow = "YL", gold = "GD", silver = "SV",
    crystal = "CR",
  }

  function compat.systemId(version, release)
    version = version or (game and game.save and game.save.version)
    local code = compat.romCodes[version]
      or (compat.isGen2() and "G2" or "G1")
    release = tostring(release or mod.version or "DEV")
      :gsub("%-rc%.", "-RC")
    return ("SLS-%s-%s"):format(code, release:upper())
  end
  assert(compat.systemId("gold", "1.8.0-rc.8") == "SLS-GD-1.8.0-RC8",
    "Silph Link system identifier")
  assert(compat.systemId("silver", "2.2.0") == "SLS-SV-2.2.0",
    "Silver Silph Link system identifier")
  assert(compat.systemId("crystal", "2.5.0") == "SLS-CR-2.5.0",
    "Crystal Silph Link system identifier")

  function compat.titleChoice(top)
    return top and top.screenId == "Gen2MainMenu" and top.phase == "menu"
      and top.list or nil
  end
  assert(compat.titleChoice({ screenId = "Gen2MainMenu", phase = "menu",
      list = {} })
    and not compat.titleChoice({ screenId = "Gen2MainMenu", phase = "confirm",
      list = {} }), "Gold title choice adapter")

  compat.yesNoFields = {
    Gen2SaveMenu = { confirm = "choice", overwrite = "choice" },
    Gen2StartMenu = { confirm = "confirmChoice" },
    Gen2BattleState = { ["ask-nickname"] = "nicknameIndex",
      ["ask-shift"] = "shiftIndex", ["ask-forget"] = "forgetChoice",
      ["stop-learning"] = "forgetChoice" },
  }

  function compat.yesNoField(top)
    if not top or (top.messageTimer or 0) > 0 then return nil end
    local phases = compat.yesNoFields[top.screenId]
    return phases and phases[top.phase] or nil
  end

  function compat.choiceView(top)
    local title = compat.titleChoice(top)
    if title then return title, "index" end
    if top and top.screenId == "Gen2ScriptMenu" then return top, "script" end
    if top and top.screenId == "Gen2NamePick" and not top.slide then
      return top, "cursor"
    end
    local confirm = top and top.confirm
    if type(confirm) == "table" and confirm.choice
        and (not confirm.pages or confirm.page >= #confirm.pages) then
      return confirm, "choice"
    end
    local field = compat.yesNoField(top)
    return top, field or "index"
  end

  function compat.choiceIndex(top, field, value)
    if field == "script" then
      if value then
        top.row = math.floor((value - 1) / top.cols) + 1
        top.col = (value - 1) % top.cols + 1
      end
      return (top.row - 1) * top.cols + top.col
    end
    if value then top[field] = value end
    return top[field]
  end
  assert(compat.choiceIndex({ row = 2, col = 1, cols = 1 }, "script") == 2,
    "Gold choice index adapter")

  function compat.choiceGrid(top, field, count)
    if field ~= "script" or top.style ~= "2d"
        or type(top.rows) ~= "number" or type(top.cols) ~= "number"
        or top.rows < 1 or top.cols < 2
        or top.rows * top.cols ~= count then return end
    local gap, left, topY, width, height = 4, 6, 28, 148, 104
    local cellW = math.floor((width - (top.cols - 1) * gap) / top.cols)
    local cellH = math.floor((height - (top.rows - 1) * gap) / top.rows)
    if cellW < 36 or cellH < 20 then return end
    return top.rows, top.cols, left, topY, cellW, cellH, gap
  end
  assert(compat.choiceGrid({ style = "2d", rows = 3, cols = 2 },
      "script", 6) == 3
    and not compat.choiceGrid({ style = "vertical", rows = 6, cols = 1 },
      "script", 6), "Gold 2D choice layout adapter")

  function compat.gen2PaletteModules()
    if not compat.isGen2() then return nil end
    if compat.gen2GbcPalette == nil then
      local okGbc, gbc = pcall(require, "src.render.GbcPalette")
      local okPal, palettes = pcall(require, "src.world.gen2.Palettes")
      compat.gen2GbcPalette = okGbc and gbc or false
      compat.gen2Palettes = okPal and palettes or false
    end
    return compat.gen2GbcPalette or nil, compat.gen2Palettes or nil
  end

  function compat.mapSprite(spriteId, seed, objDef)
    local data = game and game.data or {}
    local sprites = compat.isGen2() and data.gen2Sprites or data.sprites
    local def = sprites and sprites[spriteId]
    local daytime, colors
    if def and compat.isGen2() then
      local _, palettes = compat.gen2PaletteModules()
      local world = game and game.world
      daytime = world and world.daytime
      if not daytime and palettes and type(palettes.clockDaytime) == "function" then
        daytime = palettes.clockDaytime(world and world.hour)
      end
      colors = palettes and type(palettes.spritePalette) == "function"
        and palettes.spritePalette(data.gen2Palettes, daytime, def, objDef)
    end
    local key = def and table.concat({ tostring(seed), tostring(spriteId),
      tostring(def.image), tostring(daytime), tostring(objDef and objDef.palette) }, ":")
    compat.mapSprites = compat.mapSprites or {}
    if key and compat.mapSprites[key] == nil then
      local ok, renderer = pcall(function()
        local value = require("src.render.SpriteRenderer").new(def, seed)
        if colors and type(value.setObjPalette) == "function" then
          local _, palettes = compat.gen2PaletteModules()
          local paletteId = palettes and palettes.objectPaletteId
            and palettes.objectPaletteId(objDef) or def.paletteId or 0
          value:setObjPalette(colors, ("gen2:%s:%d"):format(
            tostring(daytime), paletteId))
        end
        return value
      end)
      compat.mapSprites[key] = ok and renderer or false
    end
    return key and compat.mapSprites[key] or nil
  end

  function compat.drawMapSprite(spriteId, seed, objDef, x, y, scale,
      feetAnchored, facing, tint)
    local renderer = compat.mapSprite(spriteId, seed, objDef)
    if not renderer then return false end
    local ok = pcall(function()
      local pose = renderer:getPoseGeometry(facing or "down", 0, false)
      scale = scale or 0.75
      local drawX = x - pose.anchorX * scale
      if pose.mirror then drawX = drawX + pose.width * scale end
      color(tint or { 1, 1, 1, 1 })
      G.draw(renderer:resolveImage(), pose.quad, drawX,
        y - (feetAnchored and pose.anchorY or pose.height / 2) * scale,
        0, pose.mirror and -scale or scale, scale)
    end)
    return ok
  end

  function compat.drawMapMarker(x, y, scale, feetAnchored, facing)
    local data = game and game.data or {}
    local playerSprites = data.field and data.field.playerSprites or {}
    local id = compat.isGen2() and "SPRITE_CHRIS"
      or playerSprites.walk or "SPRITE_RED"
    if compat.drawMapSprite(id, "kanto-gear-map", nil, x, y, scale,
        feetAnchored, facing or "down") then return end
    THEME:drawMapMarker(x, y)
  end

  function compat.drawMapActor(actor, x, y, scale, feetAnchored, tint)
    if not actor then return false end
    return compat.drawMapSprite(actor.spriteId,
      actor.id or "kanto-gear-actor", { palette = actor.palette },
      x, y, scale, feetAnchored, actor.facing, tint)
  end

  function compat.isScreen(state, kind)
    return state and compat.screens[kind]
      and compat.screens[kind][state.screenId] == true or false
  end

  function compat.screenName(kind, gen2)
    for id in pairs(compat.screens[kind] or {}) do
      if (id:sub(1, 4) == "Gen2") == gen2 then return id end
    end
  end

  function compat.caughtDex(save)
    local dex = save and save.pokedex or {}
    return dex.owned or dex.caught or {}
  end

  function compat.playSeconds(save)
    local value = save and save.playTime
    if type(value) ~= "table" then return tonumber(value) or 0 end
    return (tonumber(value.hours) or 0) * 3600
      + (tonumber(value.minutes) or 0) * 60
      + (tonumber(value.seconds) or 0)
  end

  local function invalidateLocalMap()
    if localMapImage and localMapImage.release then localMapImage:release() end
    localMap, localMapImage = nil, nil
    displayRuntime.explorer.selected, displayRuntime.explorer.page,
      displayRuntime.explorer.data, displayRuntime.explorer.mapFull,
      displayRuntime.explorer.mapZoom = nil, 1, nil, false, 1
  end

  local function hasDisplay()
    if inlineDisplay() then
      return THEME:displayMode(mod.options) ~= "fullscreen"
        or THEME:gearPrimary(mod.options, displayRuntime.swapped)
    end
    return (companion and companion.detected and companion.detected()) or false
  end

  local function companionMoveGrid(state)
    return moveGridLayout(state, bottomOwnsBattleUI(
      hideUpperBattleUI(), active, hasDisplay(), displayReady, state, battle))
  end

  local function romThemePalette(name)
    local palettes = game and game.data and game.data.palettes
    return palettes and ((palettes.cgbBase and palettes.cgbBase[name])
      or (palettes.palettes and palettes.palettes[name]))
  end

  local function themePalette(theme)
    if theme == "match" then
      theme = ({
        ogred = "version", gbc = "sgb", redpp = "advanced",
        og = "og", og_inv = "og_inv", gbc_inv = "sgb_inv",
        classic = "kanto",
      })[PaletteFX.mode] or "kanto"
    end
    if theme == "hgss" or theme == "hgss_dark" then
      return THEME.hgss.palette
    end
    if theme == "og" then return PaletteFX.GRAYS end
    if theme == "modern_light" then return THEME.light end
    if theme == "modern_dark" then return THEME.dark end
    if theme == "og_inv" then return inverted(PaletteFX.GRAYS) end
    if theme == "version" then return PaletteFX.ogBg() end
    if theme == "sgb" or theme == "sgb_inv" then
      local palette = romThemePalette("MEWMON")
      return theme == "sgb_inv" and palette and inverted(palette) or palette
    end
    if theme == "advanced" then
      local palettes = game and game.data and game.data.palettes
      local yellow = palettes and palettes.cgbBase
        and palettes.cgbBase.MEWMON
      local pack = PaletteFX.gbcPack()
      return yellow or (pack and pack.palettes and pack.palettes.MEWMON)
    end
    return THEME.classic
  end

  local function refreshTheme(force)
    local theme = mod.options:get("theme") or "kanto"
    local key = theme .. (theme == "match" and (":" .. PaletteFX.mode) or "")
    if not force and key == themeKey then return end
    local wasHgss = THEME.style == "hgss"
    local hgss = theme == "hgss" or theme == "hgss_dark"
    THEME.style = hgss and "hgss"
      or theme == "modern_light" and "modern_light"
      or theme == "modern_dark" and "modern_dark" or "classic"
    if hgss and not wasHgss then
      page, displayRuntime.home.activeApp = "HOME", nil
    elseif not hgss and (page == "HOME" or page == "STORE"
        or page == "STEPS" or page == "POKEDEX" or page == "BAG") then
      page = "MAP"
    elseif hgss and (page == "GUIDE" or page == "AREA") then
      page = "LOCAL"
    end
    THEME.hgss:setVariant(theme == "hgss_dark")
    if not hgss then hgssRuntime.animation = nil end
    local scale = THEME.style == "hgss" and THEME.hgssScale or 1
    local width, height = WIDTH * scale, HEIGHT * scale
    if canvas:getWidth() ~= width or canvas:getHeight() ~= height then
      canvas = G.newCanvas(width, height, { dpiscale = 1 })
      canvas:setFilter("nearest", "nearest")
      readbackPending, displayReady = false, false
    end
    usePalette(themePalette(theme), hgss and THEME.hgss.colors.partyBg)
    invalidateLocalMap()
    themeKey, dirty = key, true
  end

  local function reloadSteps()
    steps = savedSteps(mod.save:get("steps", 0))
    dirty = true
  end

  function displayRuntime.homeSnapshot()
    local installed = {}
    for id, package in pairs(displayRuntime.homeCatalog.packages) do
      installed[id] = package.installed == true
    end
    local layout = { tiles = {} }
    for _, tile in ipairs(displayRuntime.home.layout.tiles or {}) do
      layout.tiles[#layout.tiles + 1] = {
        id = tile.id, page = tile.page,
        column = tile.column, row = tile.row,
      }
    end
    return { format = 1, packages = installed, layout = layout }
  end

  function displayRuntime.saveHome()
    local state = displayRuntime.homeSnapshot()
    -- Keep the normal-save copy for backwards compatibility and recovery.
    mod.save:set("home_packages", state.packages)
    mod.save:set("home_layout", state.layout)
    -- Home customization is UI state: commit it immediately instead of
    -- requiring another in-game SAVE before the app may be restarted.
    if game and mod.storage and mod.storage.write then
      mod.storage:write(game, "home/state", state)
    end
  end

  function displayRuntime.packageInstalled(package, saved)
    if package.fixed then return true end
    if package.available == false then return false end
    if type(saved) == "boolean" then return saved end
    return package.defaultInstalled == true
  end
  assert(displayRuntime.packageInstalled({ fixed = true }, false)
      and displayRuntime.packageInstalled({ defaultInstalled = true }, nil)
      and not displayRuntime.packageInstalled({}, nil)
      and not displayRuntime.packageInstalled({ available = false }, true),
    "Store packages require an explicit default or user installation")

  function displayRuntime.loadHome()
    local durable
    if game and mod.storage and mod.storage.read then
      durable = mod.storage:read(game, "home/state")
      if type(durable) ~= "table" then durable = nil end
    end
    local installed = durable and durable.packages
      or mod.save:get("home_packages", {})
    if type(installed) ~= "table" then installed = {} end
    for id, package in pairs(displayRuntime.homeCatalog.packages) do
      package.installed = displayRuntime.packageInstalled(
        package, installed[id])
    end
    local saved = durable and durable.layout or mod.save:get("home_layout")
    local hasSaved = type(saved) == "table" and type(saved.tiles) == "table"
    local source = hasSaved and saved.tiles or displayRuntime.defaultHomeTiles
    local layout = { tiles = {} }
    for _, tile in ipairs(source) do
      if type(tile) == "table" then
        displayRuntime.Home.place(layout, displayRuntime.homeCatalog, tile.id,
          tonumber(tile.page), tonumber(tile.column), tonumber(tile.row))
      end
    end
    displayRuntime.Home.compactRows(layout, displayRuntime.homeCatalog)
    displayRuntime.home.layout = layout
    displayRuntime.home.page = math.max(1, math.min(
      displayRuntime.Home.pageCount(layout),
      tonumber(displayRuntime.home.page) or 1))
    displayRuntime.home.editing, displayRuntime.home.library = false, false
    displayRuntime.home.addSlot, displayRuntime.home.activeApp = nil, nil
    displayRuntime.home.swapSource = nil
    if not durable and hasSaved and game and mod.storage
        and mod.storage.write then
      mod.storage:write(game, "home/state", displayRuntime.homeSnapshot())
    end
    dirty = true
  end

  function displayRuntime.setPackageInstalled(id, installed)
    local package = displayRuntime.homeCatalog.packages[id]
    if not package or package.available == false
        or package.fixed and not installed then return false end
    package.installed = installed == true
    if not package.installed then
      displayRuntime.Home.removePackage(displayRuntime.home.layout,
        displayRuntime.homeCatalog, id)
    end
    displayRuntime.saveHome()
    dirty = true
    return true
  end
  function displayRuntime.storeEntry(app)
    local package = app and displayRuntime.homeCatalog.packages[app.id]
    local installed = package and package.installed == true
    local state = app and app.available == false and "soon"
      or installed and "open" or "get"
    return app and {
      id = app.id, icon = app.icon, label = app.label,
      category = app.category, publisher = "SILPH CO.",
      new = app.new == true,
      reason = app.reason or app.category,
      target = app.target, state = state,
      action = state == "soon" and "SOON"
        or state == "open" and "OPEN" or "GET",
      removable = installed and not package.fixed,
      description = app.description,
    }
  end

  function displayRuntime.trainerSummary()
    local save, player = game.save or {}, game.save and game.save.player or {}
    local elapsed = math.max(0, math.floor(compat.playSeconds(save)))
    local dex = displayRuntime.pokedexData()
    local region = (compat.currentRegion() or "kanto"):upper()
    local held, badges = player.badges or {}, {}
    if compat.isGen2() then
      if region == "KANTO" then held = player.kantoBadges or {} end
      for index, id in ipairs(THEME.gen2Badges[region:lower()] or {}) do
        badges[index] = not not (held[id] or held[index])
      end
    else
      local inventory = save.inventory or {}
      for index, badge in ipairs(game.data.constants
          and game.data.constants.badges or {}) do
        badges[index] = not not inventory[badge.item or badge.id]
      end
    end
    local badgeCount = 0
    for _, owned in ipairs(badges) do
      if owned then badgeCount = badgeCount + 1 end
    end
    local money = tonumber(player.money or save.money) or 0
    local moneyShort = money >= 1000000
      and THEME:format("¥%.1fM", money / 1000000)
      or money >= 1000 and THEME:format("¥%dK", math.floor(money / 1000))
      or THEME:format("¥%d", money)
    return {
      name = player.name or (compat.isGen2() and "GOLD" or "RED"),
      region = region,
      idText = THEME:format("ID %05d", player.id or 0),
      money = THEME:format("¥%d", money), moneyShort = moneyShort,
      time = ("%d:%02d"):format(math.floor(elapsed / 3600),
        math.floor(elapsed / 60) % 60),
      pokedex = THEME:format("%d/%d", dex.caught or 0, dex.total or 0),
      badgeOwned = badges, badgeCount = badgeCount,
      badgeTotal = #badges,
    }
  end

  function displayRuntime.bagSummary()
    local counts = { item = 0, medicine = 0, ball = 0, machine = 0 }
    local inventory = game.save and game.save.inventory or {}
    local ok, Bag = pcall(require, "src.inventory.Bag")
    local order = ok and Bag.order and Bag.order(game.save) or {}
    if #order == 0 then
      for id, value in pairs(inventory) do
        if tonumber(value) and tonumber(value) > 0 then
          order[#order + 1] = id
        end
      end
    end
    for _, id in ipairs(order) do
      local amount = tonumber(inventory[id]) or 0
      if amount > 0 then
        local def = game.data.items and game.data.items[id] or {}
        local kind = displayRuntime.bagItemKind(id, def)
        if kind == "status" then kind = "medicine" end
        if counts[kind] ~= nil then counts[kind] = counts[kind] + amount
        else counts.item = counts.item + amount end
      end
    end
    return counts
  end

  local function pageNames()
    if THEME.style == "hgss" then return { "HOME" } end
    local out = { "MAP" }
    if localMapMode(mod.options:get("local_map")) ~= "off" then
      out[#out + 1] = "LOCAL"
    end
    if THEME.style ~= "hgss" then
      if assist("guide") then out[#out + 1] = "GUIDE" end
      if assist("area") then out[#out + 1] = "AREA" end
    end
    out[#out + 1] = "TRAINER"
    out[#out + 1] = "PARTY"
    out[#out + 1] = "TOOLS"
    return out
  end

  function displayRuntime.toolName(def)
    local source = game and game.data
      and (def.item and game.data.items or game.data.moves)
    local entry = source and source[def.item or def.move]
    local name = entry and entry.name
      or def.item and def.item:gsub("_", " ")
      or def.move and def.move:gsub("_", " ")
      or def.key:upper():gsub("_", " ")
    if name == "SOFTBOILED" then return "SOFT BOILED" end
    if name == "SQUIRTBOTTLE" then return "SQUIRT BOTTLE" end
    return name
  end

  function displayRuntime.availableTool(actions, actionId, rodId)
    for _, action in ipairs(actions or tools) do
      if action.id == actionId then
        if not rodId then return action end
        for _, rod in ipairs(action.rods or {}) do
          if rod.id == rodId then return action end
        end
      end
    end
  end

  function displayRuntime.refreshToolSurfaces(actions)
    local save, gen2 = game and game.save, compat.isGen2()
    for _, def in ipairs(THEME.fieldTools.widgets) do
      local surface = displayRuntime.homeCatalog.surfaces[
        "tool_widget_" .. def.key]
      local unlocked = THEME.fieldTools.unlocked(def, save, gen2)
      local action = unlocked and displayRuntime.availableTool(
        actions, def.action, def.rod)
      local label = displayRuntime.toolName(def)
      local hidden, ready = not unlocked, action ~= nil
      if surface.hidden ~= hidden or surface.ready ~= ready
          or surface.label ~= label then dirty = true end
      surface.hidden, surface.ready = hidden, ready
      surface.label = label
      surface.action = action
    end
  end

  function displayRuntime.toolModels()
    local result, fishing
      = {}, nil
    local save, gen2 = game and game.save, compat.isGen2()
    for _, def in ipairs(THEME.fieldTools.widgets) do
      if THEME.fieldTools.unlocked(def, save, gen2) then
        if def.action == "fish" then
          if not fishing then
            local action = displayRuntime.availableTool(nil, "fish")
            fishing = {
              id = "fish", icon = "fish", label = THEME:translate("FISH"),
              ready = action ~= nil, action = action,
            }
            result[#result + 1] = fishing
          end
        else
          local action = displayRuntime.availableTool(nil, def.action)
          result[#result + 1] = {
            id = def.action, icon = def.icon, label = displayRuntime.toolName(def),
            ready = action ~= nil, action = action,
          }
        end
      end
    end
    return result
  end

  local function refreshTools()
    local nextTools, unavailable = {}, nil
    if mod.world and mod.world.availableFieldActions then
      nextTools, unavailable = mod.world:availableFieldActions()
    end
    if unavailable == "world is busy" then return end
    local keys = {}
    for i, action in ipairs(nextTools) do
      local key = action.id == "bicycle" and "BICYCLE"
        or tostring(action.id):upper()
      local defs = game and game.data
        and (action.id == "bicycle" and game.data.items or game.data.moves)
      local def = defs and defs[key]
      if action.label == key and def and def.name then action.label = def.name end
      local context = {}
      for _, rod in ipairs(action.rods or {}) do context[#context + 1] = rod.id end
      for _, source in ipairs(action.sources or {}) do
        context[#context + 1] = "s" .. source.slot
        for _, target in ipairs(source.targets or {}) do
          context[#context + 1] = "t" .. target.slot
        end
      end
      keys[i] = tostring(action.id) .. ":" .. tostring(action.label)
        .. ":" .. table.concat(context, ",")
    end
    local nextKey = table.concat(keys, "|")
    nextTools.page = tools.page or 1
    tools = nextTools
    displayRuntime.refreshToolSurfaces(tools)
    local count = THEME.style == "hgss" and #displayRuntime.toolModels() or #tools
    local pageSize = THEME.style == "hgss" and 4 or 6
    tools.page = math.max(1, math.min(
      math.max(1, math.ceil(count / pageSize)), tools.page or 1))
    if nextKey ~= toolsKey then
      toolsKey = nextKey
      pendingAction = nil
      fieldChoice = nil
      dirty = true
    end
  end

  local function locationEntries()
    if compat.isGen2() then
      local source = game and game.data and game.data.gen2Landmarks
      local landmarks = source and source.landmarks or {}
      local byIndex, out = {}, {}
      for _, entry in pairs(landmarks) do
        if entry.index ~= nil then byIndex[entry.index] = entry end
      end
      for id, def in pairs(game.data.gen2Maps or {}) do
        if byIndex[def.landmark] then out[id] = byIndex[def.landmark] end
      end
      return out
    end
    local townMap = game and game.data and game.data.field
      and game.data.field.townMap
    return townMap and (townMap.locations or townMap) or {}
  end

  local function locationEntry(id)
    return id and locationEntries()[id]
  end

  local function areaName(id)
    local entry = locationEntry(id)
    local name = (entry and (entry.name or entry.label)) or id or "KANTO"
    name = tostring(name):gsub("<LF>", " "):gsub("\n", " ")
    return fit(name, 23)
  end

  function displayRuntime.sectionName(id, fallback)
    local section = tostring(id or "OTHER AREA"):gsub("_", " ")
    local entry = locationEntry(id)
    local name = entry and tostring(entry.name or entry.label or "") or ""
    for word in name:upper():gmatch("[%w]+") do
      section = section:gsub("^" .. word .. " ?", "")
    end
    return section ~= "" and section or fallback
      or name ~= "" and name or "OTHER AREA"
  end

  local function areaMaps(id)
    local entry = locationEntry(id)
    if not entry then return { id } end
    local c = entry.coords or entry
    local name = entry.name or entry.label
    local x, y = tonumber(c.x or c.col), tonumber(c.y or c.row)
    if not name or not x or not y then return { id } end
    local out = {}
    for candidate, other in pairs(locationEntries()) do
      local oc = other.coords or other
      if (other.name or other.label) == name
         and tonumber(oc.x or oc.col) == x and tonumber(oc.y or oc.row) == y then
        out[#out + 1] = candidate
      end
    end
    if #out == 0 then out[1] = id end
    table.sort(out)
    return out
  end

  local function guideData(mapIds)
    local rows, bySpecies = {}, {}
    local data, field = game.data, game.data.field or {}
    local fishing = field.fishing or {}
    local gen2 = compat.isGen2()
    local modules = displayRuntime.gen2GuideModules
    if gen2 and not modules then
      modules = {
        encounter = select(2, pcall(require, "src.battle.gen2.Encounter")),
        roamers = select(2, pcall(require, "src.core.gen2.Roamers")),
        contest = select(2, pcall(require, "src.core.gen2.BugContest")),
      }
      for key, value in pairs(modules) do
        if type(value) ~= "table" then modules[key] = nil end
      end
      displayRuntime.gen2GuideModules = modules
    end
    local Gen2Encounter = modules and modules.encounter
    local Roamers = modules and modules.roamers
    local BugContest = modules and modules.contest
    local function addWeighted(slots, method, context)
      local selected, cumulative, total = {}, {}, 0
      for _, slot in ipairs(slots or {}) do
        local chance = math.max(0, tonumber(slot.chance) or 0)
        chance = math.min(chance, math.max(0, 100 - total))
        if chance > 0 then
          selected[#selected + 1], total = slot, total + chance
          cumulative[#cumulative + 1] = total
        end
        if total >= 100 then break end
      end
      addEncounters(rows, bySpecies, selected, method, cumulative, context)
    end
    for _, id in ipairs(mapIds or areaMaps(mapId)) do
      local encounter = data.encounters and data.encounters[id]
      local buckets = data.constants and data.constants.encounterBuckets
      if gen2 then
        local encounters = data.gen2Encounters or {}
        local active = encounters
        if Roamers and Roamers.Swarm then
          active = Roamers.Swarm.tables(game.save, encounters, id)
        end
        local function addGold(entry, method, weights)
          local slots = entry and entry.slots or {}
          if slots.MORN or slots.DAY or slots.NITE then
            for _, time in ipairs({ "MORN", "DAY", "NITE" }) do
              addEncounters(rows, bySpecies, slots[time], method, weights,
                { time = time, mapId = id,
                  section = displayRuntime.sectionName(id) })
            end
          else
            addEncounters(rows, bySpecies, slots, method, weights,
              { mapId = id, section = displayRuntime.sectionName(id) })
          end
        end
        local contest = id == mapId and game.save.bugContest
          and game.save.bugContest.active == true
        if contest then
          addWeighted(encounters.bugContest or (BugContest and BugContest.MONS),
            "CONTEST",
            { mapId = id, section = displayRuntime.sectionName(id) })
        else
          addGold(active.grass and active.grass[id], "WALK",
            { 30, 60, 80, 90, 95, 99, 100 })
          addGold(active.water and active.water[id], "SURF",
            { 60, 90, 100 })
        end
        local map = data.gen2Maps and data.gen2Maps[id]
        local groupId = map and map.fishGroup
        if groupId and Gen2Encounter and Roamers and Roamers.Swarm then
          groupId = Gen2Encounter.fishGroupFor(encounters, groupId,
            Roamers.Swarm.fishing(game.save))
        end
        local group = groupId and encounters.fishGroups
          and encounters.fishGroups[groupId]
        for _, rod in ipairs({ { "old", "OLD" }, { "good", "GOOD" },
                               { "super", "SUPER" } }) do
          local source = group and group[rod[1]] or {}
          local timed = false
          for _, slot in ipairs(source) do
            timed = timed or slot.day ~= nil or slot.nite ~= nil
              or slot.timeGroup ~= nil
          end
          local periods = timed and { "MORN", "DAY", "NITE" } or { false }
          for _, time in ipairs(periods) do
            local slots, weights = {}, {}
            for _, row in ipairs(source) do
              local slot = row
              if time then
                local key = time == "NITE" and "nite" or "day"
                local timeGroup = encounters.timeFishGroups
                  and encounters.timeFishGroups[row.timeGroup]
                slot = row[key] or (timeGroup and timeGroup[key]) or row
              end
              slots[#slots + 1], weights[#weights + 1] = slot, row.chance
            end
            addEncounters(rows, bySpecies, slots, rod[2], weights,
              { time = time or nil, mapId = id,
                section = displayRuntime.sectionName(id) })
          end
        end
        local treeSet = encounters.treeSets
          and encounters.treeSets[encounters.trees and encounters.trees[id]]
        if treeSet then
          addWeighted(treeSet.common, "HEADBUTT",
            { mapId = id, section = displayRuntime.sectionName(id) })
          addWeighted(treeSet.rare, "RARE TREE",
            { mapId = id, section = displayRuntime.sectionName(id) })
        end
        local rockSet = encounters.treeSets
          and encounters.treeSets[encounters.rocks and encounters.rocks[id]]
        if rockSet then
          addWeighted(rockSet.common, "ROCK SMASH",
            { mapId = id, section = displayRuntime.sectionName(id) })
        end
        for _, roamer in ipairs(game.save.roamers or {}) do
          if roamer.species and roamer.map == id then
            addEncounters(rows, bySpecies, {
              { species = roamer.species, level = roamer.level or 40 },
              { species = 0, level = roamer.level or 40 },
            }, "ROAMING", { 10, 100 },
              { mapId = id, section = displayRuntime.sectionName(id) })
          end
        end
      else
        addEncounters(rows, bySpecies,
          encounter and encounter.grass and encounter.grass.slots, "WALK",
          encounter and encounter.grass and (encounter.grass.buckets or buckets),
          { mapId = id, section = displayRuntime.sectionName(id) })
        addEncounters(rows, bySpecies,
          encounter and encounter.water and encounter.water.slots, "SURF",
          encounter and encounter.water and (encounter.water.buckets or buckets),
          { mapId = id, section = displayRuntime.sectionName(id) })
      end
      local super = field.superRod and field.superRod[id]
      if not gen2 and ((encounter and encounter.water) or super) then
        for _, rod in ipairs({ "OLD_ROD", "GOOD_ROD", "SUPER_ROD" }) do
          local def = fishing[rod] or {}
          local slots = def.always and { def.always } or def.pool
          if def.perMap then slots = field[def.perMap] and field[def.perMap][id] end
          addEncounters(rows, bySpecies, slots,
            ({ OLD_ROD = "OLD", GOOD_ROD = "GOOD", SUPER_ROD = "SUPER" })[rod],
            nil, { mapId = id, section = displayRuntime.sectionName(id) })
        end
      end
    end

    local ownedDex = compat.caughtDex(game.save)
    local areaCaught, currentTime = 0, compat.timePeriod(game.world) or "DAY"
    for order, row in ipairs(rows) do
      local def = data.pokemon[row.species] or {}
      row.name, row.caught = def.name or row.species, ownedDex[row.species] == true
      if row.caught then areaCaught = areaCaught + 1 end
      row.order, row.currentMethods, row.mapTimes = order, {}, {}
      local currentSet, sameMap = {}, false
      for _, appearance in ipairs(row.appearances) do
        local here = appearance.mapId == mapId
        local now = here and (not appearance.time or appearance.time == currentTime)
        appearance.rank = now and 1 or here and 2 or 3
        sameMap = sameMap or here
        if here then
          if appearance.time then row.mapTimes[appearance.time] = true
          else row.mapAllTimes = true end
        end
        if now then
          row.currentMinLevel = math.min(row.currentMinLevel or appearance.minLevel,
            appearance.minLevel)
          row.currentMaxLevel = math.max(row.currentMaxLevel or appearance.maxLevel,
            appearance.maxLevel)
          local odds = currentSet[appearance.method]
          if not odds then
            odds = { name = appearance.method, min = appearance.chance,
              max = appearance.chance }
            currentSet[appearance.method] = odds
            row.currentMethods[#row.currentMethods + 1] = odds
          else
            odds.min, odds.max = math.min(odds.min, appearance.chance),
              math.max(odds.max, appearance.chance)
          end
        end
      end
      table.sort(row.appearances, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.section ~= b.section then return a.section < b.section end
        if (a.time or "") ~= (b.time or "") then
          return (a.time or "") < (b.time or "")
        end
        return a.method < b.method
      end)
      row.availability = #row.currentMethods > 0 and "now"
        or sameMap and "time" or "area"
      row.detailPages = math.max(1, math.ceil(#row.appearances / 3))
    end
    table.sort(rows, function(a, b)
      local rank = { now = 1, time = 2, area = 3 }
      if rank[a.availability] ~= rank[b.availability] then
        return rank[a.availability] < rank[b.availability]
      end
      return a.order < b.order
    end)
    return { name = areaName(mapId), rows = rows, caught = areaCaught,
      complete = #rows > 0 and areaCaught == #rows,
      pages = math.max(1, math.ceil(#rows / 3)), timed = compat.isGen2(),
      time = currentTime, section = displayRuntime.sectionName(mapId) }
  end

  local function areaData(mapIds)
    local sections = { { name = "TRAINERS", rows = {} },
      { name = "ITEMS", rows = {} }, { name = "HIDDEN", rows = {},
        perPage = assist("item_radar") and 3 or 4 } }
    local data, save = game.data, game.save
    local field = data.field or {}
    local maps = mapIds or areaMaps(mapId)
    if compat.isGen2() then
      local rows = Area.gen2Rows(data, save, mod.world, maps)
      for index = 1, 3 do sections[index].rows = rows[index] end
      local screens = checklistPages(sections)
      return { name = areaName(mapId), screens = screens, pages = #screens,
        sections = sections, remaining = Area.remaining(sections) }
    end
    local showFuture = localMapMode(mod.options:get("local_map")) == "enhanced"
    for _, id in ipairs(maps) do
      local map = data.maps and data.maps[id]
      for _, obj in ipairs(map and map.objects or {}) do
        local key = id .. "_obj_" .. tostring(obj.index)
        local scripted = Area.gen1ScriptTrainer(id, obj)
        local trainerClass = scripted and scripted.class or obj.trainerClass
        if trainerClass then
          local trainer = data.trainers and data.trainers[trainerClass]
          local label = scripted and scripted.label or trainer and trainer.name
            or tostring(trainerClass):gsub("^OPP_", "")
          if tostring(trainerClass):match("^OPP_RIVAL") then
            label = (save.player and save.player.rival)
              or (save.rival and save.rival.name) or label
          end
          local done = save.defeatedTrainers
            and save.defeatedTrainers[key] == true or false
          if not done and map.label and data.trainerHeader then
            local header_ = data:trainerHeader(map.label, obj.index)
            done = header_ and header_.event and save.flags
              and save.flags[header_.event] == true or false
          end
          local status, missed, available
          if scripted then
            local state = Area.gen1TrainerState(save, scripted)
            done, missed, available, status = done or state.done,
              state.missed, state.available, state.status
          end
          if id == "OAKS_LAB" and obj.index == 1
              and obj.trainerClass == "OPP_RIVAL1" then
            done, status = oneShotTrainerStatus(done,
              save.flags and save.flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB == true,
              mod.save:get("oak_lab_rival_result"))
          end
          if Area.gen1TrainerMissed(save, id, done) then
            done, missed, available, status = true, true, false, "MISSED"
          end
          if not scripted or available or done or showFuture then
            sections[1].rows[#sections[1].rows + 1] = {
              label = label, done = done, missed = missed,
              available = available, status = status,
              id = key, mapId = id, index = obj.index,
              x = obj.x, y = obj.y,
              spriteId = obj.sprite,
            }
          end
        elseif obj.item and obj.item ~= "0" and obj.item ~= 0 then
          local item = data.items and data.items[obj.item]
          sections[2].rows[#sections[2].rows + 1] = {
            label = item and item.name or obj.item,
            done = save.itemsTaken and save.itemsTaken[key] == true or false,
            mapId = id, x = obj.x, y = obj.y, kind = "item",
          }
        end
      end
      for _, hidden in ipairs(field.hiddenItems and field.hiddenItems[id] or {}) do
        local item = data.items and data.items[hidden.item]
        local key = id .. "_" .. hidden.x .. "_" .. hidden.y
        sections[3].rows[#sections[3].rows + 1] = {
          label = item and item.name or hidden.item,
          done = save.hiddenTaken and save.hiddenTaken[key] == true or false,
          mapId = id, x = hidden.x, y = hidden.y, kind = "hidden",
        }
      end
      for _, hidden in ipairs(field.hiddenCoins and field.hiddenCoins[id] or {}) do
        local key = id .. "_" .. hidden.x .. "_" .. hidden.y
        sections[3].rows[#sections[3].rows + 1] = {
          label = THEME:format("%d COINS", hidden.coins),
          done = save.hiddenTaken and save.hiddenTaken[key] == true or false,
          mapId = id, x = hidden.x, y = hidden.y, kind = "hidden",
        }
      end
    end
    local screens = checklistPages(sections)
    return { name = areaName(mapId), screens = screens, pages = #screens,
      sections = sections, remaining = Area.remaining(sections) }
  end

  local function hasItemfinder()
    return ((game.save.inventory or {}).ITEMFINDER or 0) > 0
  end

  local function radarSignals()
    local world = game and (game.overworld or game.world)
    local player = world and world.player
    if not player then return {} end
    if compat.isGen2() then
      local out = {}
      for _, item in ipairs(Area.gen2Hidden(game.data, mod.world, mapId)) do
        if not item.done and item.x and item.y
            and Area.itemfinderNear(
              player.cellX, player.cellY, item.x, item.y) then
          out[#out + 1] = {
            dx = item.x - player.cellX, dy = item.y - player.cellY,
          }
        end
      end
      return out
    end
    local field = game.data.field or {}
    local hidden = field.hiddenItems and field.hiddenItems[mapId] or {}
    local taken, out = game.save.hiddenTaken or {}, {}
    for _, item in ipairs(hidden) do
      local key = mapId .. "_" .. item.x .. "_" .. item.y
      if not taken[key]
          and Area.itemfinderNear(
            player.cellX, player.cellY, item.x, item.y) then
        out[#out + 1] = {
          dx = item.x - player.cellX, dy = item.y - player.cellY,
        }
      end
    end
    return out
  end

  local function loadMap()
    if mapAsset ~= nil then return mapAsset or nil end
    if compat.isGen2() then
      local gfx = game and game.data and game.data.gen2MenuGfx
        and game.data.gen2MenuGfx.pokegear
      if not (gfx and gfx.tiles and gfx.maps) then
        mapAsset = false
        return nil
      end
      local ok, image = pcall(G.newImage, gfx.tiles)
      if not ok then
        mapAsset = false
        return nil
      end
      image:setFilter("nearest", "nearest")
      local iw, ih = image:getDimensions()
      local across = gfx.tilesWide or math.floor(iw / 8)
      local quads = {}
      for i = 0, across * math.floor(ih / 8) - 1 do
        quads[i] = G.newQuad((i % across) * 8, math.floor(i / across) * 8,
                             8, 8, iw, ih)
      end
      mapAsset = { image = image, quads = quads, maps = gfx.maps,
        palettes = gfx.palettes, palMap = gfx.palMap, gen2 = true }
      return mapAsset
    end
    local townMap = game and game.data and game.data.field
      and game.data.field.townMap
    local bg = townMap and townMap.background
    if not (bg and bg.map and bg.tiles and bg.tiles.path) then
      mapAsset = false
      return nil
    end
    local ok, image = pcall(G.newImage, bg.tiles.path)
    if not ok then
      mapAsset = false
      return nil
    end
    image:setFilter("nearest", "nearest")
    local iw, ih = image:getDimensions()
    local across = math.floor(iw / 8)
    local quads = {}
    for i = 0, across * math.floor(ih / 8) - 1 do
      quads[i] = G.newQuad((i % across) * 8, math.floor(i / across) * 8,
                           8, 8, iw, ih)
    end
    mapAsset = { image = image, quads = quads, map = bg.map }
    return mapAsset
  end

  local function sprite(species, side, mon)
    local path, trueColor = PokemonSprites.path(
      game and game.data, species, side,
      { kind = "summary", mon = mon })
    if not path then return nil end
    local key = side .. ":" .. path
    if spriteCache[key] == nil then
      local ok, image = pcall(G.newImage, path)
      if not (ok and image) then
        local dataOk, data = pcall(
          require("src.render.Assets").imageData, path)
        if dataOk and data then ok, image = pcall(G.newImage, data) end
      end
      if ok and image then image:setFilter("nearest", "nearest") end
      spriteCache[key] = ok and image or false
    end
    return spriteCache[key] or nil, trueColor
  end

  local function drawSprite(species, side, x, y, maxW, maxH, tint,
                            mon, quiet, brightness)
    local image, trueColor = sprite(species, side, mon)
    if not image then
      if not quiet then box("fill", x + 4, y + 4, maxW - 8, maxH - 8, DARK) end
      return false
    end
    local iw, ih = image:getDimensions()
    local scale = math.min(maxW / iw, maxH / ih)
    local function paint()
      color(tint or { brightness or 1, brightness or 1, brightness or 1, 1 })
      G.draw(image, x + (maxW - iw * scale) / 2,
             y + (maxH - ih * scale) / 2, 0, scale, scale)
    end
    local gbc = require("src.render.GbcPalette")
    local colors
    if not (tint or trueColor) then
      if compat.isGen2() then
        local _, palettes = compat.gen2PaletteModules()
        colors = palettes and palettes.monColors
          and palettes.monColors(game.data.gen2Palettes, species,
                                 mon and mon.shiny)
      else
        colors = PaletteFX.monPal(game.data, species,
          mon and mon.transformed)
      end
    end
    if colors and gbc.available() then gbc.with(colors, paint)
    else paint() end
    return true
  end

  function compat.partyEgg(mon)
    if not mon then return false end
    if mon.isEgg == true then return true end
    local live = mon.slot and game and game.save and game.save.party
      and game.save.party[mon.slot]
    return live and live.isEgg == true or false
  end

  function compat.drawPokemonIcon(mon, x, y, size, brightness)
    local data = game and game.data or {}
    local name, path, isEgg = nil, nil, compat.partyEgg(mon)
    size = size or 27
    if data.gen2Icons then
      name = isEgg and "ICON_EGG"
        or data.gen2Icons.species and data.gen2Icons.species[mon.species]
      local entry = name and data.gen2Icons.icons
        and data.gen2Icons.icons[name]
      path = entry and entry.image
    else
      local icons = data.icons or {}
      local def = data.pokemon and data.pokemon[mon.species]
      local entry = (icons.bySpecies and icons.bySpecies[mon.species])
        or (def and def.icon)
      if type(entry) == "string" then
        name, path = entry, icons.icons and icons.icons[entry]
      elseif type(entry) == "table" then
        path = entry.image
      end
      if not path then
        name = def and def.dex and icons.byDex and icons.byDex[def.dex]
        path = name and icons.icons and icons.icons[name]
      end
    end
    if not isEgg then
      path = PokemonSprites.iconPath(data, mon, path, { name = name })
    end
    if not path then return false end
    local key = "icon:" .. path
    if spriteCache[key] == nil then
      local ok, image = pcall(G.newImage, path)
      if not (ok and image) then
        local dataOk, imageData = pcall(
          require("src.render.Assets").imageData, path)
        if dataOk and imageData then ok, image = pcall(G.newImage, imageData) end
      end
      if ok and image then image:setFilter("nearest", "nearest") end
      spriteCache[key] = ok and image or false
    end
    local image = spriteCache[key]
    if not image then return false end
    local iw, ih = image:getDimensions()
    local fw, fh = math.min(16, iw), math.min(16, ih)
    local quad = G.newQuad(0, 0, fw, fh, iw, ih)
    local scale = math.min(size / fw, size / fh)
    local function paint()
      color({ brightness or 1, brightness or 1, brightness or 1, 1 })
      G.draw(image, quad, x + (size - fw * scale) / 2,
        y + (size - fh * scale) / 2, 0, scale, scale)
    end
    local gbc = compat.gen2PaletteModules()
    local colors = data.gen2Palettes and data.gen2Palettes.partyMenu
      and data.gen2Palettes.partyMenu[1]
    if colors and gbc and gbc.available() then gbc.with(colors, paint)
    else paint() end
    return true
  end

  local function battery(x, foreground)
    foreground = foreground or PAPER
    local state, percent = mod.device:powerInfo()
    local tick = math.floor(love.timer.getTime())
    local segments, blink, blinkVisible, tone, animated =
      THEME:batteryState(state, percent, tick)
    if animated ~= batteryAnimated then nextClock = 0 end
    batteryAnimated = animated
    if THEME.style == "hgss" then
      local colors = THEME.hgss.colors
      local fill = tone == "green" and colors.greenLight
        or tone == "amber" and colors.amberLight or colors.redLight
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:battery(214, 8, segments, blink, blinkVisible,
        foreground, fill)
      G.pop()
      return
    end
    local fill = tone == "green" and THEME.batteryGreen
      or tone == "amber" and THEME.batteryAmber or THEME.red
    box("line", x + 0.5, 6.5, 14, 7, foreground)
    box("fill", x + 14, 9, 2, 3, foreground)
    for segment = 1, 4 do
      if segment <= segments or segment == blink and blinkVisible then
        box("fill", x + 2 + (segment - 1) * 3, 8, 2, 4, fill)
      end
    end
  end

  local function header(title, back, paged, hgssContentOffsetY)
    title = THEME:translate(title)
    local modern = THEME.style ~= "classic"
    local hgss = THEME.style == "hgss"
    local background = hgss and THEME.hgss.colors.surface
      or modern and (THEME.style == "modern_dark" and MID or DARK)
      or DARK
    local foreground = hgss and THEME.hgss.colors.ink
      or modern and THEME.white or PAPER
    local function put(value, x, y)
      if hgss then
        G.push()
        G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        THEME.hgss:label(value, x * THEME.hgssScale,
          (y - 2) * THEME.hgssScale, foreground)
        G.pop()
      else
        text(value, x, y, foreground)
      end
    end
    local function halfWidth(value)
      return hgss and math.floor(THEME.hgss:labelWidth(value)
        / THEME.hgssScale / 2)
        or math.floor(#glyphList(value) * 3)
    end
    if hgss then
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:headerBar(title, back, paged, hgssContentOffsetY)
      G.pop()
    else
      box("fill", 0, 0, WIDTH, HEADER, background)
    end
    if modern and not hgss then
      box("fill", 0, HEADER - 2, WIDTH, 2, THEME.blue)
      box("fill", 0, HEADER - 2, 42, 2, THEME.red)
    end
    if back and not hgss then
      put("<", 4, 6)
      box("fill", 16, 4, 1, 12, foreground)
    end
    if paged and not hgss then
      local label = fit(title, back and 8 or 10)
      local left, center = back and 22 or 4, back and 57 or 48
      put("<", left, 6)
      put(label, center - halfWidth(label), 6)
      put(">", 85, 6)
    elseif back and not hgss then
      put(fit(title, 11), 22, 6)
    elseif not hgss then
      put(fit(title, 14), 5, 6)
    end
    local now = os.time()
    local clock = compactClock(mod.datetime:time(game,
      compat.clockTimestamp(game, mod.options:get("clock_source"), now)))
    local period = compat.isGen2() and compat.timePeriod(game.world)
    if hgss then
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:headerClock(clock, period, 139, 72, 6)
      G.pop()
    else
      if period then clock = clock .. " " .. period:sub(1, 1) end
      put(clock, 117 - halfWidth(clock), 6)
    end
    battery(143, foreground)
  end

  local function stackHas(target)
    for _, state in ipairs(game and game.stack and game.stack.states or {}) do
      if state == target then return true end
    end
    return false
  end

  local function screenById(id)
    local ids = compat.screens[id]
    local states = game and game.stack and game.stack.states or {}
    for i = #states, 1, -1 do
      if (ids and ids[states[i].screenId])
          or (not ids and states[i].screenId == id) then return states[i] end
    end
  end

  function displayRuntime.moveLearnScreen()
    local learn = screenContract(screenById("MoveLearnMenu"), "moveLearn")
    if learn then return learn end

    local picker = screenById("Gen2MoveDeleter")
    local pack = screenById("Gen2PackMenu")
    local pending = displayRuntime.bag.pending
    if picker and type(picker.mon) == "table"
        and type(picker.list) == "table" and picker.list == picker.mon.moves
        and type(picker.row) == "number" then
      local moveId = pending and pending.moveId
      if not moveId and pack and type(pack.rows) == "table"
          and type(pack.index) == "number" then
        local row = pack.rows[pack.index]
        local item = row and game and game.data and game.data.items
          and game.data.items[row.id]
        moveId = item and item.teaches
      end
      if moveId then
        return { native = picker, mon = picker.mon, newMoveId = moveId,
                 selecting = true, index = picker.row, field = pending ~= nil }
      end
    end

    local top = game and game.stack and game.stack:top()
    local textFlow = top and top.isTextBox
    for _, state in ipairs(game and game.stack and game.stack.states or {}) do
      if state.isTextBox then textFlow = true break end
    end
    if pending and pending.moveId and type(pending.mon) == "table"
        and textFlow and not screenContract(top, "party") then
      return { mon = pending.mon, newMoveId = pending.moveId,
               selecting = false, field = true }
    end
  end

  function displayRuntime.fieldBagParty()
    local pending = displayRuntime.bag.pending
    local top = game and game.stack and game.stack:top()
    local menu = not battle and pending and screenContract(top, "party")
    if not menu then return nil end
    local party = menu.party or (game.save and game.save.party) or {}
    if menu.index >= 1 and menu.index <= #party then
      pending.mon = party[menu.index]
    end
    local title = pending.moveId and "TEACH MOVE TO"
      or menu.prompt == "Give to which <PK><MN>?" and "GIVE ITEM TO"
      or "USE ITEM ON"
    return menu, party, title
  end

  function displayRuntime.fieldPpMoveScreen()
    local pending = displayRuntime.bag.pending
    local picker = screenById("Gen2MoveDeleter")
    if not (pending and not pending.moveId and picker
        and type(picker.mon) == "table" and type(picker.row) == "number"
        and type(picker.list) == "table" and picker.list == picker.mon.moves) then
      return nil
    end
    local items = {}
    for index, move in ipairs(picker.mon.moves or {}) do
      local def = game.data and game.data.moves and game.data.moves[move.id]
      items[index] = {
        label = def and def.name or move.id or "MOVE",
        right = THEME:format("%d/%d", move.pp or 0, move.maxPp or move.pp or 0),
      }
    end
    return { native = picker, items = items, index = picker.row }
  end

  local function pcSession()
    local root = screenById("itemPc")
    if root and type(root.items or root.entries) == "table"
        and type(root.index) == "number" then return "items", root end
    root = screenById("pokemonPc")
    if root and type(root.items or root.entries) == "table"
        and type(root.index) == "number" then return "pokemon", root end
  end

  local function pcList()
    local states = game and game.stack and game.stack.states or {}
    for i = #states, 1, -1 do
      if pcListKind(states[i]) then return states[i] end
    end
  end

  local function battleState()
    local states = game and game.stack and game.stack.states or {}
    for i = #states, 1, -1 do
      if compat.isBattleScreen(states[i]) then return states[i] end
    end
  end

  local function screenState()
    local top = game and game.stack and game.stack:top()
    local world = game and (game.overworld or game.world)
    if not (world and (compat.isGen2() and world.map or stackHas(world))) then
      worldStarted = false
      return "title", top, 0
    end
    if not worldStarted then
      if not compat.isGen2() and top ~= world then return "title", top, 0 end
      worldStarted = true
    end
    if not compat.isGen2() and world.transitioning then
      local alpha = math.min(1, (top and top.t or 0)
        / math.max(1, top and top.frames or 1))
      if top and top.phase == "in" then alpha = 1 - alpha end
      return "transition", top, alpha
    end
    if externalLoading then return "loading", top, 0.72 end
    if top and top.isTextBox then return "textbox", top, 0.58 end
    if world.flyAnim or world.teleportOut then return "locked", top, 0.58 end
    if (compat.isGen2() and not top) or top == world then return "active", top, 0 end
    return "locked", top, 0.58
  end

  local function dialogueChoice()
    local top = game and game.stack and game.stack:top()
    if not top then return end
    local field
    top, field = compat.choiceView(top)
    if type(top) ~= "table" then return end
    if field ~= "index" and field ~= "script" and field ~= "cursor" then
      if type(top[field]) == "number" then
        return top, { "YES", "NO" }, field
      end
      return
    end
    if battleChoice(top) then
      return top, { "YES", "NO" }, field
    end
    if top.screenId == "Gen2ElevatorMenu" then
      if type(top.floors) ~= "table" or type(top.index) ~= "number" then
        return
      end
      local labels = {}
      for i, row in ipairs(top.floors) do
        if type(row) ~= "table" then return end
        local label
        if type(top.floorName) == "function" then
          local ok
          ok, label = pcall(top.floorName, top.floorNames, row.floorId)
          if not ok then return end
        end
        labels[i] = label or row.label or tostring(row.floorId or i)
      end
      if #labels > 0 then return top, labels, field end
    end
    if type(top.items) == "table" and (field == "script" or field == "cursor"
        or not top.screenId)
        and not pcListKind(top) then
      if field == "script" and (type(top.row) ~= "number"
          or type(top.col) ~= "number" or type(top.cols) ~= "number"
          or top.cols < 1) then return end
      if field ~= "script" and type(top[field]) ~= "number" then return end
      local labels = {}
      for i, item in ipairs(top.items) do
        labels[i] = type(item) == "table" and (item.label or tostring(i))
          or tostring(item)
      end
      if #labels > 0 then return top, labels, field end
    end
  end

  function displayRuntime.motionKey()
    if THEME.style ~= "hgss" then return nil end
    local mode, top = screenState()
    local home, explorer = displayRuntime.home, displayRuntime.explorer
    local topId = top and (top.screenId or top.kind or top.phase) or ""
    local summary = compat.isScreen(top, "summary") and top or nil
    local learn = displayRuntime.moveLearnScreen()
    local pcKind = pcSession()
    local listKind = pcListKind(pcList())
    local choice = dialogueChoice()
    return table.concat({
      mode or "", tostring(topId),
      not battle and tostring(top and top.phase or "") or "",
      not battle and tostring(top and top.savePhase or "") or "",
      not battle and top and top.qtyState and "quantity" or "",
      not battle and top and top.confirm and "confirm" or "",
      moveInfo and "move-info" or "",
      learn and (learn.selecting and "learn-select" or "learn") or "",
      choice and "choice" or "", pcKind or "", listKind or "",
      summary and ("summary-" .. tostring(summary.page or 1)) or "",
      battle and ("battle-" .. tostring(battle.prompt)) or "",
      battle and battle.itemIndex ~= nil and "bag" or "",
      battle and battle.partyIndex ~= nil and "battle-party" or "",
      top and top.submenu and "submenu" or "",
      top and tostring(top.pocketIndex
        or top.__gen3uiBagPocketIndex or "") or "",
      page or "", home.activeApp or "",
      home.editing and "edit" or "",
      home.library and ("library-" .. tostring(home.libraryKind)
        .. "-" .. tostring(home.libraryPage)) or "",
      page == "HOME" and tostring(home.page) or "",
      page == "STORE" and tostring(home.storeDetail or home.storeView) or "",
      page == "POKEDEX" and tostring(displayRuntime.pokedex.view) or "",
      page == "POKEDEX" and tostring(displayRuntime.pokedex.selected) or "",
      page == "POKEDEX" and tostring(displayRuntime.pokedex.page) or "",
      page == "POKEDEX" and tostring(displayRuntime.pokedex.habitatPage) or "",
      page == "POKEDEX" and tostring(displayRuntime.pokedex.movePage) or "",
      page == "BAG" and tostring(displayRuntime.bag.pocket) or "",
      page == "BAG" and tostring(displayRuntime.bag.page) or "",
      page == "BAG" and tostring(displayRuntime.bag.detail) or "",
      page == "BAG" and tostring(displayRuntime.bag.message) or "",
      tostring(explorer.view or ""), tostring(explorer.selected or ""),
      explorer.mapFull and "map-full" or "",
      tostring(explorer.page or ""), tostring(explorer.detailPage or ""),
      page == "TOOLS" and tostring(tools.page or 1) or "",
      page == "GUIDE" and tostring(guidePage or 1) or "",
      page == "AREA" and tostring(areaPage or 1) or "",
      partyActionSlot and "party-action" or "",
      partyMoveFrom and "party-swap" or "",
      trainerStepsOpen and "trainer-steps" or "",
      radarOpen and "radar" or "", fieldChoice and fieldChoice.kind or "",
      pendingFly and "fly-prompt" or "",
      pendingAction and "tool-prompt" or "",
      displayRuntime.guideDetail and ("guide-detail-"
        .. tostring(displayRuntime.guideDetail.page or 1)) or "",
    }, "|")
  end

  function displayRuntime.prepareMotion()
    local motion, key = displayRuntime.motion, displayRuntime.motionKey()
    if not key then
      motion.key, motion.started = nil, nil
      return
    end
    local changed = motion.key and motion.key ~= key
    motion.key = key
    if not changed then return end
    local now = love.timer.getTime()
    if hgssRuntime.animation
        or THEME.hgss:partyActionAnimating(now) then
      motion.started = nil
      return
    end
    if not motion.canvas
        or motion.canvas:getWidth() ~= canvas:getWidth()
        or motion.canvas:getHeight() ~= canvas:getHeight() then
      motion.canvas = G.newCanvas(canvas:getWidth(), canvas:getHeight(),
        { dpiscale = 1 })
      motion.canvas:setFilter("nearest", "nearest")
    end
    local previous = G.getCanvas()
    G.setCanvas(motion.canvas)
    G.origin()
    G.setScissor()
    G.setShader()
    G.setBlendMode("alpha")
    G.clear(0, 0, 0, 0)
    color({ 1, 1, 1, 1 })
    G.draw(canvas)
    G.setCanvas(previous)
    motion.started = now
  end

  function displayRuntime.applyMotion()
    local motion = displayRuntime.motion
    if not (motion.started and motion.canvas) then return end
    local progress = math.min(1,
      (love.timer.getTime() - motion.started) / motion.duration)
    if progress >= 1 then
      motion.started = nil
      return
    end
    progress = progress * progress * (3 - 2 * progress)
    local previous = G.getCanvas()
    G.setCanvas(canvas)
    G.origin()
    G.setScissor()
    G.setShader()
    G.setBlendMode("alpha")
    color({ 1, 1, 1, 1 - progress })
    G.draw(motion.canvas)
    G.setCanvas(previous)
  end

  local function trackChoice(top, now)
    if not choiceTop and not top then return false end
    if choiceTop and choiceTop[1] == top
        and choiceTop[2] == (top and top.phase) then return false end
    choiceTop = top and { top, top.phase } or nil
    choiceCommitted = nil
    choiceNudgeUntil = 0
    choiceReadyAt = top and now + CHOICE_QUIET or 0
    return true
  end

  local function choiceWindow(labels, index)
    local count = math.min(4, #labels)
    local start = math.max(1, math.min((index or 1) - 1,
                                      #labels - count + 1))
    return start, count
  end

  local function drawTitle()
    if THEME.style == "hgss" then
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:titleBoot({ systemId = compat.systemId() },
        love.timer.getTime())
      G.pop()
      return
    end
    local modern = THEME.style ~= "classic"
    local foreground = modern and INK or PAPER
    local primary = modern and THEME.blue or PAPER
    local secondary = modern and THEME.red or MID
    local phase = math.floor(love.timer.getTime() * 2) % 3
    box("fill", 0, 0, WIDTH, HEIGHT, modern and PAPER or DARK)
    outline(3, 3, 154, 138, primary)
    box("fill", 3, 3, 28, 2, secondary)
    box("fill", 129, 139, 28, 2, secondary)

    centered("SILPH CO.", 9, secondary)
    outline(47, 24, 22, 18, foreground)
    outline(91, 24, 22, 18, foreground)
    box("fill", 51, 28, 14, 10, modern and MID or INK)
    box("fill", 95, 28, 14, 10, modern and MID or INK)
    box("fill", 69, 32, 22, 2, foreground)
    for i = 0, 2 do
      box("fill", 73 + i * 7, 31, 4, 4,
        i == phase and secondary or foreground)
    end

    centered("SILPH LINK", 50, foreground, 2)
    box("fill", 24, 67, 36, 1, secondary)
    box("fill", 100, 67, 36, 1, secondary)
    centered("SYSTEM", 65, primary)

    box("fill", 15, 81, 130, 21, modern and MID or INK)
    outline(15, 81, 130, 21, primary)
    centered(compat.systemId(), 88, foreground)

    local linkStatus = fit("LINK ONLINE", 18)
    local linkWidth = #glyphList(linkStatus) * 6
    local linkX = math.floor((WIDTH - linkWidth) / 2)
    box("fill", linkX - 12, 114, 4, 4, secondary)
    box("fill", linkX + linkWidth + 8, 114, 4, 4, secondary)
    text(linkStatus, linkX, 112, primary)
    if math.floor(love.timer.getTime() * 2) % 2 == 0 then
      centered("START GAME", 128, foreground)
    end
  end

  function displayRuntime.drawContinueArrow(x, y)
    box("fill", x + 2, y + 12, 6, 1, { 0, 0, 0, 0.38 })
    box("fill", x, y, 10, 2, PAPER)
    box("fill", x + 1, y + 2, 8, 2, PAPER)
    box("fill", x + 2, y + 4, 6, 2, PAPER)
    box("fill", x + 3, y + 6, 4, 2, PAPER)
    box("fill", x + 4, y + 8, 2, 2, PAPER)
    box("fill", x + 1, y + 1, 8, 1, MID)
    box("fill", x + 2, y + 2, 6, 2, MID)
    box("fill", x + 3, y + 4, 4, 2, MID)
    box("fill", x + 4, y + 6, 2, 2, MID)
  end

  local function drawDim(alpha, prompt)
    if THEME.style == "hgss" then
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:systemOverlay(alpha, prompt, love.timer.getTime())
      G.pop()
      return
    end
    color({ 0, 0, 0, alpha })
    G.rectangle("fill", 0, 0, WIDTH, HEIGHT)
    if prompt then displayRuntime.drawContinueArrow(75, 122) end
  end

  local function namingKey(x, y, w, label, selected, raw)
    local pressed = THEME.style == "hgss"
      and THEME.hgss:beginPress(x, y, w, 15, true, 1, 4 / 3)
    label = raw and tostring(label) or THEME:translate(label)
    local paperLuma = PAPER[1] * 0.2126
      + PAPER[2] * 0.7152 + PAPER[3] * 0.0722
    local inkLuma = INK[1] * 0.2126
      + INK[2] * 0.7152 + INK[3] * 0.0722
    local midLuma = MID[1] * 0.2126
      + MID[2] * 0.7152 + MID[3] * 0.0722
    local darkLuma = DARK[1] * 0.2126
      + DARK[2] * 0.7152 + DARK[3] * 0.0722
    local background = selected
      and (midLuma >= darkLuma and MID or DARK)
      or (paperLuma >= inkLuma and PAPER or INK)
    local foreground = paperLuma < inkLuma and PAPER or INK
    box("fill", x, y, w, 15, background)
    outline(x, y, w, 15, foreground)
    color(foreground)
    EngineFont.draw(label, x + math.floor((w - EngineFont.width(label)) / 2),
                    y + 3)
    if pressed then THEME.hgss:endPress(pressed) end
  end

  local function drawNaming(top, grid)
    header("NAME INPUT")
    local gen2 = top.screenId == "Gen2NamingScreen"
    local name = gen2 and top.text or table.concat(top.glyphs or {})
    name = name == "" and "-" or name
    if THEME.style == "hgss" then
      local entries = {}
      for row, cells in ipairs(grid) do
        local y = 36 + (row - 1) * 17
        for col, label in ipairs(cells) do
          local left = 3 + math.floor((col - 1) * 154 / #cells)
          local right = 3 + math.floor(col * 154 / #cells)
          local shown = label == "lower case" and "LOWER"
            or label == "UPPER CASE" and "UPPER" or label
          local selected = gen2 and top.row == row - 1
              and (row < #grid and top.col == col - 1
                or row == #grid and math.floor(top.col / 3) + 1 == col)
            or not gen2 and top.row == row and top.col == col
          entries[#entries + 1] = { x = left, y = y, w = right - left,
            h = 15, label = shown, selected = selected,
            action = row == #grid }
        end
      end
      G.push(); G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:naming({ name = name, entries = entries })
      G.pop()
      return
    end
    local nameWidth = math.max(24, EngineFont.width(name) + 8)
    namingKey(math.floor((WIDTH - nameWidth) / 2), 20, nameWidth,
      name, false, true)
    for row, cells in ipairs(grid) do
      local y = 36 + (row - 1) * 17
      for col, label in ipairs(cells) do
        local left = 3 + math.floor((col - 1) * 154 / #cells)
        local right = 3 + math.floor(col * 154 / #cells)
        local shown = label == "lower case" and "LOWER"
          or label == "UPPER CASE" and "UPPER" or label
        local selected
        if gen2 then
          selected = top.row == row - 1
            and (row < #grid and top.col == col - 1
              or row == #grid and math.floor(top.col / 3) + 1 == col)
        else
          selected = top.row == row and top.col == col
        end
        namingKey(left, y, right - left, shown, selected)
      end
    end
  end

  local function drawDialogueChoice(top, labels, prompt, field)
    header("CHOOSE")
    local selected = compat.choiceIndex(top, field)
    local rows, cols, left, topY, cellW, cellH, gap =
      compat.choiceGrid(top, field, #labels)
    if THEME.style == "hgss" then
      local entries = {}
      if rows then
        for row = 1, rows do
          for col = 1, cols do
            local index = (row - 1) * cols + col
            if labels[index] then
              entries[#entries + 1] = {
                x = left + (col - 1) * (cellW + gap),
                y = topY + (row - 1) * (cellH + gap),
                w = cellW, h = cellH, label = labels[index],
                selected = selected == index,
              }
            end
          end
        end
      elseif #labels == 2 then
        for index, y in ipairs({ 54, 90 }) do
          entries[#entries + 1] = { x = 24, y = y, w = 112, h = 32,
            label = labels[index], selected = selected == index }
        end
      else
        local start, count = choiceWindow(labels, selected)
        for row = 1, count do
          local index = start + row - 1
          entries[#entries + 1] = { x = 8,
            y = 24 + (row - 1) * 27, w = 144, h = 24,
            label = labels[index], selected = selected == index }
        end
      end
      G.push(); G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:choiceScreen({ entries = entries,
        prompt = THEME:messageLines(prompt, 24, 3),
        nudge = choiceNudgeUntil > love.timer.getTime() })
      G.pop()
      return
    end
    if rows then
      for row = 1, rows do
        for col = 1, cols do
          local index = (row - 1) * cols + col
          button(left + (col - 1) * (cellW + gap),
                 topY + (row - 1) * (cellH + gap), cellW, cellH,
                 labels[index], selected == index)
        end
      end
    elseif #labels == 2 then
      local lines = THEME:messageLines(prompt, 24, 3)
      if #lines > 0 then
        local y = 35 - (#lines - 1) * 6
        for _, line in ipairs(lines) do
          centered(line, y, DARK)
          y = y + 12
        end
      else
        centered("MAKE A CHOICE", 37, DARK)
      end
      button(24, 58, 112, 28, labels[1], selected == 1)
      button(24, 91, 112, 28, labels[2], selected == 2)
    else
      local start, count = choiceWindow(labels, selected)
      for row = 1, count do
        local index = start + row - 1
        button(8, 24 + (row - 1) * 27, 144, 24,
               labels[index], selected == index)
      end
    end
    if choiceNudgeUntil > love.timer.getTime() then
      centered("PAUSE THEN CHOOSE", 134, DARK)
    end
  end

  local function drawLevelUpStats(mon)
    local stats = mon.stats
    local def = game.data.pokemon[mon.species] or {}
    header("LEVEL UP")
    centered(fit(THEME:format("%s  L%d",
      mon.nickname or def.name or mon.species or "POKEMON",
      mon.level or 0), 24), 27, DARK)
    local splitSpecial = stats.specialAttack ~= nil
      or stats.specialDefense ~= nil
    local rows = splitSpecial and {
      { "ATTACK", stats.attack }, { "DEFENSE", stats.defense },
      { "SPCL.ATK", stats.specialAttack },
      { "SPCL.DEF", stats.specialDefense }, { "SPEED", stats.speed },
    } or {
      { "ATTACK", stats.attack }, { "DEFENSE", stats.defense },
      { "SPEED", stats.speed }, { "SPECIAL", stats.special },
    }
    if THEME.style == "hgss" then
      local modelRows = {}
      for _, row in ipairs(rows) do
        modelRows[#modelRows + 1] = { label = row[1], value = row[2] }
      end
      G.push(); G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:levelUp({
        name = mon.nickname or def.name or mon.species or "POKEMON",
        level = THEME:format("L%d", mon.level or 0),
        type = def.types and def.types[1], rows = modelRows,
        drawPokemon = function(x, y, size)
          drawSprite(mon.species, "front", x, y, size, size,
            nil, mon.source or mon)
        end,
      })
      G.pop()
      return
    end
    local firstY, step = splitSpecial and 39 or 44, splitSpecial and 13 or 15
    for i, row in ipairs(rows) do
      local y = firstY + (i - 1) * step
      text(row[1], 24, y, INK)
      text(tostring(row[2] or 0), 119, y, DARK)
    end
    button(24, splitSpecial and 111 or 108, 112, 27, "CONTINUE", false)
  end

  local function drawMapFallback()
    local townMap = game.data.field and game.data.field.townMap
    local locations = townMap and (townMap.locations or townMap) or {}
    local playerX, playerY
    for id, entry in pairs(locations) do
      local c = entry.coords or entry
      local x, y = tonumber(c.x or c.col), tonumber(c.y or c.row)
      if x and y then
        local px, py = 22 + x * 7, 24 + y * 6
        box("fill", px, py, 4, 4, DARK)
        if id == mapId then playerX, playerY = px + 2, py + 2 end
      end
    end
    if playerX then compat.drawMapMarker(playerX, playerY) end
  end

  local function entryCoords(entry)
    local c = entry and (entry.coords or entry)
    local x, y = c and tonumber(c.x or c.col), c and tonumber(c.y or c.row)
    if compat.isGen2() and entry and entry.index ~= nil then
      return x and x / 8, y and y / 8
    end
    return x, y
  end

  local function mapPoint(entry)
    if compat.isGen2() then
      local x, y = entry and tonumber(entry.x), entry and tonumber(entry.y)
      if not (x and y) then return nil end
      return 20 + x * 0.75, 20 + y * 0.75
    end
    local x, y = entryCoords(entry)
    if not (x and y) then return nil end
    return 20 + (x * 8 + 20) * 0.75,
           22 + (y * 8 + 4) * 0.75
  end

  function displayRuntime.homeRegionMap()
    local asset = loadMap()
    local region = compat.currentRegion() or "kanto"
    local cells = asset and (asset.gen2 and asset.maps[region] or asset.map)
    if not (asset and cells) then
      return { region = region:upper(), area = areaName(mapId) }
    end
    return {
      region = region:upper(), area = areaName(mapId),
      drawMap = function(x, y, w, h)
        local rows = math.max(1, math.ceil(#cells / 20)
          - (asset.gen2 and 0 or 1))
        local scale = w / 160
        local mapHeight = rows * 8 * scale
        local px, py = mapPoint(locationEntry(mapId))
        local oldTop = asset.gen2 and 20 or 22
        local sourceY = py and (py - oldTop) / 0.75 or rows * 4
        local top = y + math.floor((h - mapHeight) / 2 + 0.5)
        if mapHeight > h then
          top = math.floor(y + h / 2 - sourceY * scale + 0.5)
          top = math.max(math.floor(y + h - mapHeight), math.min(y, top))
        end
        local gbc = require("src.render.GbcPalette")
        local mapColors = not asset.gen2
          and PaletteFX.pal(game.data, "TOWNMAP") or nil
        for index, tile in ipairs(cells) do
          local quad = asset.quads[tile]
          if quad then
            local column, row = (index - 1) % 20,
              math.floor((index - 1) / 20)
            local visibleRow = asset.gen2 and row or row - 1
            if asset.gen2 or row > 0 then
              local palette = asset.gen2 and asset.palettes
                and asset.palettes[(asset.palMap
                  and asset.palMap[tile + 1]) or 1] or mapColors
              local function paint()
                G.setColor(1, 1, 1, 1)
                G.draw(asset.image, quad, x + column * 8 * scale,
                  top + visibleRow * 8 * scale, 0, scale, scale)
              end
              if palette and gbc.available() then gbc.with(palette, paint)
              else paint() end
            end
          end
        end
        if px then
          compat.drawMapMarker(x + (px - 20) / 0.75 * scale,
            top + sourceY * scale, 1)
        end
      end,
    }
  end

  function displayRuntime.hgssMapPoint(x, y, left, top, scale, oldTop)
    return (left + (x - 20) / 0.75 * scale) / THEME.hgssScale,
      (top + (y - oldTop) / 0.75 * scale) / THEME.hgssScale
  end
  do
    local x, y = displayRuntime.hgssMapPoint(20, 20, 30, 39, 1, 20)
    assert(x == 20 and y == 26,
      "HGSS region map touch targets follow the rendered map transform")
  end

  local function outside(map)
    local tileset = map and map.def and map.def.tileset
    for _, id in ipairs(game.data.field.outsideTilesets or {}) do
      if id == tileset then return true end
    end
    return false
  end

  local function flyTargets()
    local out, field = {}, game.data.field or {}
    for _, id in ipairs(field.flyOrder or {}) do
      local def = game.data.maps and game.data.maps[id]
      local x, y = mapPoint(locationEntry(id))
      if x and game.save.visited and game.save.visited[id]
          and field.flyWarps and field.flyWarps[id] and outside({ def = def }) then
        out[#out + 1] = { id = id, name = areaName(id), x = x, y = y }
      end
    end
    return out
  end

  local function canFly()
    return mod.world and mod.world.canFly and mod.world:canFly()
      and #flyTargets() > 0
  end

  function compat.currentRegion()
    if not compat.isGen2() then return nil end
    local entry = locationEntry(mapId)
    local index = tonumber(entry and entry.index) or 0
    return (index == 94 or index < 46) and "johto" or "kanto"
  end

  local function drawMap()
    local region = compat.currentRegion()
    local mapTitle = region and (region:upper() .. (canFly() and " FLY" or " MAP"))
      or (canFly() and "MAP + FLY" or "MAP")
    header(mapTitle, THEME.style == "hgss", THEME.style ~= "hgss")
    local asset = loadMap()
    if asset then
      local cells = asset.map
      local gbc = require("src.render.GbcPalette")
      local mapColors = not asset.gen2
        and PaletteFX.pal(game.data, "TOWNMAP") or nil
      if asset.gen2 then
        cells = asset.maps[region]
      end
      local function paintMap(left, top, tileScale, markerScale)
        for i, tile in ipairs(cells or {}) do
          local quad = asset.quads[tile]
          if quad then
            local col, row = (i - 1) % 20, math.floor((i - 1) / 20)
            local visibleRow = asset.gen2 and row or row - 1
            local colors = asset.gen2 and asset.palettes
              and asset.palettes[(asset.palMap and asset.palMap[tile + 1]) or 1]
              or mapColors
            local function paint()
              color(colors and { 1, 1, 1, 1 }
                or asset.gen2 and (THEME.style == "modern_dark" and INK or PAPER)
                or { 1, 1, 1, 1 })
              G.draw(asset.image, quad, left + col * 8 * tileScale,
                top + visibleRow * 8 * tileScale, 0, tileScale, tileScale)
            end
            if asset.gen2 or row > 0 then
              if colors and gbc.available() then gbc.with(colors, paint)
              else paint() end
            end
          end
        end
        local px, py = mapPoint(locationEntry(mapId))
        if px then
          local oldTop = asset.gen2 and 20 or 22
          compat.drawMapMarker(left + (px - 20) / 0.75 * tileScale,
            top + (py - oldTop) / 0.75 * tileScale, markerScale)
        end
      end
      if THEME.style == "hgss" then
        G.push(); G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        THEME.hgss:regionMap({ area = areaName(mapId),
          drawMap = function(x, y, w, h)
            local rows = math.max(1, math.ceil(#(cells or {}) / 20)
              - (asset.gen2 and 0 or 1))
            local scale = math.min(w / 160, h / (rows * 8))
            local mapWidth, mapHeight = 160 * scale, rows * 8 * scale
            local left = math.floor(x + (w - mapWidth) / 2 + 0.5)
            local top = math.floor(y + (h - mapHeight) / 2 + 0.5)
            paintMap(left, top, scale, 1.5)
            local oldTop = asset.gen2 and 20 or 22
            displayRuntime.regionMapTargets = {}
            for _, target in ipairs(flyTargets()) do
              local targetX, targetY = displayRuntime.hgssMapPoint(
                target.x, target.y, left, top, scale, oldTop)
              displayRuntime.regionMapTargets[#displayRuntime.regionMapTargets + 1] = {
                id = target.id, name = target.name,
                x = targetX, y = targetY,
              }
            end
          end })
        G.pop()
        return
      end
      paintMap(20, asset.gen2 and 20 or 22, 0.75)
    else
      if THEME.style == "hgss" then
        displayRuntime.regionMapTargets = {}
        G.push(); G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        THEME.hgss:regionMap({ area = areaName(mapId),
          drawMap = function(x, y, w, h)
            local townMap = game.data.field and game.data.field.townMap
            local locations = townMap and (townMap.locations or townMap) or {}
            local playerX, playerY
            for id, entry in pairs(locations) do
              local c = entry.coords or entry
              local cx, cy = tonumber(c.x or c.col), tonumber(c.y or c.row)
              if cx and cy then
                local px = math.floor(x + 12 + cx * 10)
                local py = math.floor(y + 8 + cy * 9)
                box("fill", px, py, 6, 6, DARK)
                if id == mapId then playerX, playerY = px + 3, py + 3 end
              end
            end
            if playerX then compat.drawMapMarker(playerX, playerY, 1.5) end
          end })
        G.pop()
        return
      end
      drawMapFallback()
    end
    box("fill", 4, 128, 152, 14, DARK)
    centered(areaName(mapId), 130, PAPER)
  end

  local function loadLocalMap()
    if localMap ~= nil then return localMap or nil end
    if not (mod.world and mod.world.mapOverview) then
      localMap = false
      return nil
    end
    local overview = mod.world:mapOverview()
    localMap = overview and overview.rows and overview or false
    return localMap or nil
  end

  local loadLocalMapImage

  function displayRuntime.explorerWildRows(guide, currentMapId, scope)
    local out, hereOnly = {}, scope ~= "ROUTE"
    for _, species in ipairs(guide.rows or {}) do
      local matches, availableHere = {}, false
      for _, appearance in ipairs(species.appearances or {}) do
        local sameArea = appearance.mapId == currentMapId
        local currentTime = not appearance.time
          or appearance.time == guide.time
        local current = sameArea and currentTime
        availableHere = availableHere or current
        matches[#matches + 1] = {
          method = appearance.method, chance = appearance.chance,
          time = appearance.time, mapId = appearance.mapId,
          section = appearance.section, minLevel = appearance.minLevel,
          maxLevel = appearance.maxLevel, current = current,
        }
      end
      if #matches > 0 and (availableHere or not hereOnly) then
        out[#out + 1] = {
          species = species.species, name = species.name,
          caught = species.caught, types = species.types,
          matches = matches,
          detailPages = math.max(1, math.ceil(#matches / 2)),
          key = table.concat({ "wild", scope, tostring(species.species) }, ":"),
        }
      end
    end
    return out
  end
  do
    local fixture = { time = "DAY", rows = { { species = 129,
      name = "MAGIKARP", appearances = {
        { mapId = 1, method = "OLD", chance = 85, minLevel = 10,
          maxLevel = 10 },
        { mapId = 1, method = "GOOD", chance = 35, minLevel = 20,
          maxLevel = 20 },
        { mapId = 2, section = "POND", time = "NITE", method = "SUPER",
          chance = 40, minLevel = 30, maxLevel = 30 },
      } }, { species = 163, name = "HOOTHOOT", appearances = {
        { mapId = 2, section = "NORTH FIELD", time = "NITE",
          method = "WALK", chance = 30, minLevel = 15, maxLevel = 15 },
      } } } }
    local here = displayRuntime.explorerWildRows(fixture, 1, "HERE")
    local route = displayRuntime.explorerWildRows(fixture, 1, "ROUTE")
    assert(#here == 1 and here[1].name == "MAGIKARP"
        and #here[1].matches == 3 and here[1].matches[1].current
        and not here[1].matches[3].current and #route == 2
        and route[2].name == "HOOTHOOT",
      "Explorer gallery groups species and retains exact habitat details")
  end

  function displayRuntime.explorerModel(overview)
    local explorer = displayRuntime.explorer
    local now, id = love.timer.getTime(), overview.mapId or mapId
    local guideEnabled, areaEnabled = assist("guide"), assist("area")
    local cached = explorer.data
    -- ponytail: a half-second snapshot avoids rebuilding encounter tables on
    -- every player step; invalidate immediately if live mutation needs it.
    if not cached or cached.mapId ~= id or now - cached.at >= 0.5
        or cached.guideEnabled ~= guideEnabled
        or cached.areaEnabled ~= areaEnabled then
      cached = { mapId = id, at = now,
        guideEnabled = guideEnabled, areaEnabled = areaEnabled,
        guide = guideEnabled and guideData()
          or { rows = {}, caught = 0, time = "DAY", timed = false },
        area = areaEnabled and areaData({ id })
          or { sections = { { rows = {} }, { rows = {} }, { rows = {} } } },
      }
      explorer.data = cached
    end
    local guide, area = cached.guide, cached.area
    local sections = area.sections or { { rows = {} }, { rows = {} },
      { rows = {} } }
    local allTrainers, allItems, wild = sections[1].rows, {}, {}
    for _, row in ipairs(sections[2].rows) do allItems[#allItems + 1] = row end
    for _, row in ipairs(sections[3].rows) do allItems[#allItems + 1] = row end

    local filters = explorer.filters
    filters.wildScope = filters.wildScope == "ROUTE" and "ROUTE" or "HERE"
    wild = displayRuntime.explorerWildRows(guide, id, filters.wildScope)

    local actors = mod.world and mod.world.mapActors
      and mod.world:mapActors() or {}
    local actorById = {}
    for _, actor in ipairs(actors or {}) do actorById[actor.id] = actor end
    for _, row in ipairs(allTrainers) do
      local actor = actorById[row.id]
      if actor then
        row.actor = actor
        row.x, row.y, row.facing = actor.x, actor.y, actor.facing
        row.spriteId, row.palette = actor.spriteId, actor.palette
      elseif mod.world and mod.world.npc and row.index ~= nil then
        local handle = mod.world:npc(row.mapId, row.index)
        if handle and type(handle.position) == "function" then
          local x, y = handle:position()
          if x ~= nil and y ~= nil then row.x, row.y = x, y end
        end
      end
      row.key = "trainer:" .. tostring(row.id or row.label)
    end
    local enhanced = localMapMode(mod.options:get("local_map")) == "enhanced"
    local canScan = not enhanced and assist("item_radar") and hasItemfinder()
    if explorer.scanMapId ~= id then
      explorer.scanMapId, explorer.scanFrame, explorer.scanRevealed =
        id, nil, {}
    end
    local pos = mod.world:current()
    local scanProgress = explorer.scanFrame
      and math.min(1, explorer.scanFrame / RADAR_FRAMES) or nil
    for _, row in ipairs(allItems) do
      row.key = table.concat({ "item", tostring(row.kind), tostring(row.x),
        tostring(row.y), tostring(row.label) }, ":")
      if canScan and scanProgress and row.kind == "hidden" and not row.done
          and row.x and row.y and pos and pos.mapId == id
          and Area.itemfinderScanReached(pos.x, pos.y, row.x, row.y,
            scanProgress) then
        explorer.scanRevealed[row.key] = true
      end
      row.scanned = canScan and explorer.scanRevealed[row.key] == true
      local upper = tostring(row.label or ""):upper()
      row.icon = (upper:match("^TM%d") or upper:match("^HM%d"))
        and "machine" or "item"
      row.displayLabel = row.kind == "hidden" and not enhanced and not row.done
          and not row.scanned
        and "HIDDEN SIGNAL" or row.label
      row.location = row.kind == "hidden" and not enhanced and not row.done
          and not row.scanned
        and "USE ITEMFINDER" or "MARKED ON MAP"
    end
    local mapItems = {}
    for _, row in ipairs(allItems) do
      if enhanced or row.kind ~= "hidden" or row.done or row.scanned then
        mapItems[#mapItems + 1] = row
      end
    end
    for _, row in ipairs(wild) do
      local def = game.data.pokemon and game.data.pokemon[row.species] or {}
      local types = row.types or def.types or {}
      local type1 = types[1] or def.type1 or "NORMAL"
      local type2 = types[2] or def.type2 or type1
      row.type, row.type2 = type1, type2
      row.typeLabel = THEME:typeName(type1, mod.content)
      row.type2Label = THEME:typeName(type2, mod.content)
    end

    local view = explorer.view or "wild"
    local source = view == "wild" and wild
      or view == "items" and allItems
      or view == "trainers" and allTrainers or {}
    local perPage = view == "wild" and 4 or math.max(1, #source)
    local pages = math.max(1, math.ceil(#source / perPage))
    explorer.page = math.max(1, math.min(explorer.page, pages))
    local first, rows = (explorer.page - 1) * perPage + 1, {}
    for index = first, math.min(#source, first + perPage - 1) do
      rows[#rows + 1] = source[index]
    end
    local selected
    for _, row in ipairs(source) do
      if row.key == explorer.selected then selected = row break end
    end
    if explorer.selected and not selected then explorer.selected = nil end

    local markers, selectedMarker = {}, nil
    for _, marker in ipairs(overview.markers or {}) do
      if marker.kind == "warp" then markers[#markers + 1] = marker end
    end
    for _, row in ipairs(mapItems) do
      if row.x ~= nil and row.y ~= nil then
        local marker = { kind = row.kind, x = row.x, y = row.y,
          found = row.done, scanned = row.scanned, source = row }
        markers[#markers + 1] = marker
        if row == selected then selectedMarker = marker end
      end
    end
    for _, row in ipairs(allTrainers) do
      if row.x ~= nil and row.y ~= nil then
        local marker = { kind = "trainer", x = row.x, y = row.y,
          actor = row.actor or row,
          state = row.missed and "missed" or row.done and "beaten" or "open",
          source = row }
        markers[#markers + 1] = marker
        if row == selected then selectedMarker = marker end
      end
    end

    local function progress(rows_)
      local done = 0
      for _, row in ipairs(rows_) do if row.done then done = done + 1 end end
      return THEME:format("%d/%d", done, #rows_)
    end
    local rows_, width, height, density = localMapGrid(overview)
    explorer.detailPage = math.max(1, math.min(explorer.detailPage or 1,
      selected and selected.detailPages or 1))
    local detailRows = {}
    if selected and view == "wild" then
      local firstDetail = (explorer.detailPage - 1) * 2 + 1
      for index = firstDetail,
          math.min(#selected.matches, firstDetail + 1) do
        detailRows[#detailRows + 1] = selected.matches[index]
      end
    end
    return {
      view = view, selected = selected, rows = rows,
      total = #source, page = explorer.page, pages = pages, perPage = perPage,
      route = areaName(overview.mapId or mapId),
      subarea = displayRuntime.sectionName(overview.mapId or mapId, "OUTDOORS"),
      region = (compat.currentRegion() or "kanto"):upper(),
      overview = overview,
      image = loadLocalMapImage(overview, rows_, width, height, density),
      player = pos and pos.mapId == overview.mapId and pos,
      markers = markers, selectedMarker = selectedMarker,
      mapFull = explorer.mapFull == true,
      mapZoom = explorer.mapZoom or 1,
      filters = filters,
      detailPage = explorer.detailPage, detailRows = detailRows,
      detailPages = selected and selected.detailPages or 1,
      enhanced = enhanced,
      canScan = canScan,
      scanHint = canScan and not explorer.scanHintSeen,
      scanProgress = scanProgress,
      showMapStats = areaEnabled,
      guideEnabled = guideEnabled, areaEnabled = areaEnabled,
      itemsText = progress(mapItems),
      trainersText = progress(allTrainers),
      wildScope = filters.wildScope,
      trainerIcon = allTrainers[1],
      drawPlayer = function(player, x, y, tileSize)
        compat.drawMapMarker(x, y, tileSize / 16, true, player.facing)
      end,
      drawTrainer = function(marker, x, y, tileSize)
        compat.drawMapActor(marker.actor, x, y, tileSize / 16, true,
          marker.state ~= "open" and { 0.45, 0.45, 0.45, 1 } or nil)
      end,
      drawActor = function(row, x, y, scale, feet)
        compat.drawMapActor(row.actor or row, x, y, scale, feet)
      end,
      drawPokemon = function(row, x, y, size, uncaught)
        drawSprite(row.species, "front", x, y, size, size,
          uncaught and { 0.52, 0.52, 0.52, 1 } or nil)
      end,
    }
  end

  function loadLocalMapImage(overview, rows, width, height, density)
    if localMapImage ~= nil then return localMapImage or nil end
    if not (love.image and love.image.newImageData) then
      localMapImage = false
      return nil
    end
    local ok, image = pcall(function()
      local pixels = love.image.newImageData(width, height)
      for y, row in ipairs(rows) do
        for x = 1, #row do
          local c = THEME.style == "hgss"
            and THEME.hgss:mapColor(
              overview, x, y, density, row:sub(x, x))
            or THEME:localMapColor(
              overview, x, y, density, row:sub(x, x))
          pixels:setPixel(x - 1, y - 1, c[1], c[2], c[3], c[4])
        end
      end
      local result = G.newImage(pixels)
      result:setFilter("nearest", "nearest")
      if pixels.release then pixels:release() end
      return result
    end)
    localMapImage = ok and image or false
    return localMapImage or nil
  end

  local function drawLocalMap()
    local enhanced = localMapMode(mod.options:get("local_map")) == "enhanced"
    local overview = loadLocalMap()
    if THEME.style == "hgss" then
      header(THEME:translate("EXPLORER"),
        displayRuntime.explorer.selected ~= nil
          or displayRuntime.explorer.mapFull
          or displayRuntime.home.activeApp ~= nil, false)
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      if not overview then
        THEME.hgss:panel(7, 32, 226, 178, false)
        THEME.hgss:partyInfo("HOST UPDATE REQUIRED", 31, 112,
          THEME.hgss.colors.ink, 178, "center")
      else
        THEME.hgss:explorer(displayRuntime.explorerModel(overview))
      end
      G.pop()
      return
    end
    header("LOCAL", false, true)
    if not overview then
      centered("HOST UPDATE REQUIRED", 62, DARK)
    else
      local rows, width, height, density = localMapGrid(overview)
      local pos = mod.world:current()
      local focusX = pos and pos.mapId == overview.mapId and pos.x
        and (pos.x + 0.5) * density
      local focusY = pos and pos.mapId == overview.mapId and pos.y
        and (pos.y + 0.5) * density
      local scale, left, top = localMapLayout(
        width, height, localMapZoom, focusX, focusY, density)
      G.setScissor(2, 20, 156, 106)
      box("fill", left - 2, top - 2, width * scale + 4,
          height * scale + 4, THEME.localMap.border)
      local image = density > 1
        and loadLocalMapImage(overview, rows, width, height, density)
      if image then
        G.setColor(1, 1, 1, 1)
        G.draw(image, left, top, 0, scale, scale)
      else
        for y, row in ipairs(rows) do
          for x = 1, #row do
            local cell = row:sub(x, x)
            local shade = density > 1 and cell or cell == " " and 2 or 1
            local c = THEME:localMapColor(
              overview, x, y, density, shade)
            box("fill", left + (x - 1) * scale, top + (y - 1) * scale,
                scale, scale, c)
            if cell == "+" then
              box("fill", left + (x - 0.75) * scale,
                  top + (y - 0.75) * scale,
                  math.max(1, scale / 2), math.max(1, scale / 2),
                  THEME.localMap.playerCore)
            end
          end
        end
      end
      if enhanced then
        for _, marker in ipairs(overview.markers or {}) do
          local x = math.floor(left + (marker.x + 0.5) * density * scale + 0.5)
          local y = math.floor(top + (marker.y + 0.5) * density * scale + 0.5)
          local c = marker.kind == "warp" and MAP_EXIT
            or marker.kind == "item" and MAP_ITEM or MAP_HIDDEN
          local size = density * scale
          box("fill", x - size / 2, y - size / 2, size, size, c)
        end
      end
      if pos and pos.mapId == overview.mapId and pos.x and pos.y then
        local px = left + (pos.x + 0.5) * density * scale
        local py = top + (pos.y + 0.5) * density * scale
        local direction = ({ up = { 0, -1 }, down = { 0, 1 },
          left = { -1, 0 }, right = { 1, 0 } })[pos.facing] or { 0, 1 }
        box("fill", px - 1, py - 1, 3, 3, THEME.localMap.player)
        box("fill", px, py, 1, 1, THEME.localMap.playerCore)
        box("fill", px + direction[1] * 2,
            py + direction[2] * 2, 1, 1, THEME.localMap.player)
      end
      G.setScissor()
      button(134, 22, 22, 16, localMapZoom .. "x", false)
    end
    box("fill", 4, 126, 152, 14, DARK)
    if enhanced then
      local remaining = areaData({ overview and overview.mapId or mapId }).remaining
      box("fill", 8, 132, 3, 3, MAP_EXIT)
      text(fit("EXIT", 7), 14, 130, PAPER)
      box("fill", 60, 132, 3, 3, MAP_ITEM)
      text(THEME:format("ITM%d", remaining[2] or 0), 66, 130, PAPER)
      box("fill", 111, 132, 3, 3, MAP_HIDDEN)
      text(THEME:format("HID%d", remaining[3] or 0), 117, 130, PAPER)
    else
      centered(areaName(mapId), 130, PAPER)
    end
  end

  local function drawFlyPrompt()
    if THEME.style == "hgss" then
      G.push(); G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:toolPrompt({ icon = "teleport", label = pendingFly.name })
      G.pop()
      return
    end
    drawDim(0.54, false)
    box("fill", 10, 38, 140, 91, MID)
    outline(10, 38, 140, 91, PAPER)
    centered("FLY TO", 49, DARK)
    centered(fit(pendingFly.name, 20), 66, INK)
    button(18, 91, 58, 27, "YES", true)
    button(84, 91, 58, 27, "NO", false)
  end

  function compat.gen2BadgeAsset()
    if spriteCache.__gen2Badges ~= nil then
      return spriteCache.__gen2Badges or nil
    end
    local gfx = game.data.gen2MenuGfx and game.data.gen2MenuGfx.trainerCard
    if not (gfx and gfx.badges and gfx.badgeOam) then
      spriteCache.__gen2Badges = false
      return nil
    end
    local ok, image = pcall(G.newImage, gfx.badges)
    if not (ok and image) then
      spriteCache.__gen2Badges = false
      return nil
    end
    image:setFilter("nearest", "nearest")
    local iw, ih = image:getDimensions()
    local wide = gfx.badgesWide or 2
    local quads = {}
    for tile = 0, wide * math.floor(ih / 8) - 1 do
      quads[tile] = G.newQuad((tile % wide) * 8,
        math.floor(tile / wide) * 8, 8, 8, iw, ih)
    end
    spriteCache.__gen2Badges = {
      image = image, quads = quads, oam = gfx.badgeOam,
      palette = gfx.badgePalette,
    }
    return spriteCache.__gen2Badges
  end

  function compat.drawGen2Badge(name, x, y, owned, scale)
    local asset = compat.gen2BadgeAsset()
    local obj = asset and asset.oam[THEME.gen2Badges.oam[name] or 0]
    local tile = obj and obj.frames and obj.frames[1]
    if tile == nil then return false end
    scale = scale or 1
    local flip = tile >= 0x80
    local base, sx = flip and tile - 0x80 or tile, flip and -1 or 1
    local function paint()
      color(owned and { 1, 1, 1, 1 } or { 0.35, 0.35, 0.35, 0.32 })
      for _, cell in ipairs({ { 0, 0, 0 }, { 1, 0, 1 },
          { 0, 1, 2 }, { 1, 1, 3 } }) do
        local quad = asset.quads[base + cell[3]]
        if quad then
          local px = (flip and (1 - cell[1]) or cell[1]) * 8 * scale
          G.draw(asset.image, quad, x + px + (flip and 8 * scale or 0),
            y + cell[2] * 8 * scale, 0, sx * scale, scale)
        end
      end
    end
    local gbc = compat.gen2PaletteModules()
    if asset.palette and gbc and gbc.available() then
      gbc.with(asset.palette, paint)
    else
      paint()
    end
    return true
  end

  local function drawTrainer()
    local save = game.save or {}
    local player = save.player or {}
    local ownedDex = compat.caughtDex(save)
    local owned = 0
    local dexTotal = 0
    for species, def in pairs(game.data.pokemon or {}) do
      if def.dex then
        dexTotal = dexTotal + 1
        if ownedDex[species] then owned = owned + 1 end
      end
    end
    local badges = game.data.constants and game.data.constants.badges or {}
    local shownBadges = badges
    if compat.isGen2() then
      badges = {}
      for _, id in ipairs(THEME.gen2Badges.johto) do
        badges[#badges + 1] = { id = id, region = "johto" }
      end
      for _, id in ipairs(THEME.gen2Badges.kanto) do
        badges[#badges + 1] = { id = id, region = "kanto" }
      end
      shownBadges = {}
      local region = compat.currentRegion()
      for _, id in ipairs(THEME.gen2Badges[region] or THEME.gen2Badges.johto) do
        shownBadges[#shownBadges + 1] = { id = id, region = region or "johto" }
      end
    end
    local inventory = save.inventory or {}
    local playerBadges = player.badges or {}
    local function ownsBadge(badge, index)
      if compat.isGen2() then
        local held = badge.region == "kanto" and (player.kantoBadges or {})
          or playerBadges
        return held[badge.id] or held[index]
      end
      return inventory[badge.item or badge.id]
    end
    local badgeCount = 0
    if compat.isGen2() then
      for _, region in ipairs({ "johto", "kanto" }) do
        for i, id in ipairs(THEME.gen2Badges[region]) do
          if ownsBadge({ id = id, region = region }, i) then
            badgeCount = badgeCount + 1
          end
        end
      end
    else
      for i, badge in ipairs(badges) do
        if ownsBadge(badge, i) then badgeCount = badgeCount + 1 end
      end
    end
    local elapsed = math.max(0, math.floor(compat.playSeconds(save)))

    if spriteCache.__badges == nil then
      local ok, card = false, nil
      if not compat.isGen2() then
        local screens = require("src.ui.Screens")
        ok, card = pcall(screens.build, game,
          compat.screenName("trainerCard", false))
      end
      spriteCache.__badges = ok and card and card.badges or false
    end
    local badgeAsset = spriteCache.__badges
    local gen1BadgeColors = not compat.isGen2()
      and PaletteFX.pal(game.data, "MEWMON") or nil

    header("TRAINER", THEME.style == "hgss"
      and displayRuntime.home.activeApp ~= nil,
      THEME.style ~= "hgss")
    if THEME.style == "hgss" then
      local badgeOwned = {}
      for index, badge in ipairs(shownBadges) do
        badgeOwned[index] = not not ownsBadge(badge, index)
      end
      local dexSize = game.data.constants and game.data.constants.dexSize
        or dexTotal
      local region = (compat.currentRegion() or "kanto"):upper()
      local model = {
        name = player.name or (compat.isGen2() and "GOLD" or "RED"),
        region = region,
        idText = THEME:format("ID %05d", player.id or 0),
        badgeText = THEME:format("%d/%d", badgeCount, #badges),
        badgeRegion = region,
        badgeOwned = badgeOwned,
        money = THEME:format("¥%d", player.money or save.money or 0),
        time = ("%d:%02d"):format(math.floor(elapsed / 3600),
          math.floor(elapsed / 60) % 60),
        pokedex = THEME:format("%d/%d", owned, dexSize),
        drawPlayer = function(x, y, scale)
          compat.drawMapMarker(x, y, scale, false, "down")
        end,
      }
      model.drawBadge = function(index, cx, cy, badgeOwned_)
        local badge = shownBadges[index]
        if compat.isGen2() then
          return badge and compat.drawGen2Badge(
            badge.id, cx - 6, cy - 6, badgeOwned_, 0.75) or false
        end
        local quad = badgeAsset and badgeAsset.quads
          and badgeAsset.quads[index - 1]
        if not quad then return false end
        local _, _, width, height = quad:getViewport()
        local scale = math.min(1, 14 / math.max(width, height))
        local function paint()
          if gen1BadgeColors then G.setColor(1, 1, 1, badgeOwned_ and 1 or 0.28)
          else
            local tint = badgeOwned_ and INK or DARK
            G.setColor(tint[1], tint[2], tint[3], badgeOwned_ and 1 or 0.25)
          end
          G.draw(badgeAsset.img, quad, cx - width * scale / 2,
            cy - height * scale / 2, 0, scale, scale)
        end
        local gbc = require("src.render.GbcPalette")
        if gen1BadgeColors and gbc.available() then
          gbc.with(gen1BadgeColors, paint)
        else paint() end
        return true
      end
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:trainer(model)
      G.pop()
      return
    end
    box("fill", 4, 22, 152, 50, MID)
    outline(4, 22, 152, 50, INK)
    text(fit(player.name or "RED", 12), 8, 27, INK)
    text(THEME:format("ID %05d", player.id or 0), 89, 27, DARK)
    box("fill", 8, 43, 144, 1, DARK)
    text(THEME:format("%s %d/%d", THEME:translate("BADGES"),
      badgeCount, #badges), 8, 48, DARK)
    for i, badge in ipairs(shownBadges) do
      local badgeOwned = ownsBadge(badge, i)
      local quad = badgeAsset and badgeAsset.quads and badgeAsset.quads[i - 1]
      if compat.isGen2() then
        local x, y = 11 + (i - 1) * 18, 57
        if not compat.drawGen2Badge(badge.id, x, y, badgeOwned, 0.75) then
          box("fill", x, y, 12, 12, badgeOwned and DARK or MID)
          outline(x, y, 12, 12, INK)
          text(badge.id:sub(1, 1), x + 2, y + 2,
            badgeOwned and PAPER or DARK)
        end
      elseif quad then
        local x = math.floor(5 + (i - 1) * 134
          / math.max(1, #badges - 1))
        local colors = badgeOwned and gen1BadgeColors
        local function paint()
          local tint = badgeOwned and INK or DARK
          if colors then G.setColor(1, 1, 1, 1)
          else G.setColor(tint[1], tint[2], tint[3], badgeOwned and 1 or 0.25) end
          G.draw(badgeAsset.img, quad, x, 56)
        end
        local gbc = require("src.render.GbcPalette")
        if colors and gbc.available() then gbc.with(colors, paint)
        else paint() end
      else
        local badgeGap = 152 / math.max(1, #badges)
        local x = math.floor(4 + (i - 1) * badgeGap)
        local nextX = math.floor(4 + i * badgeGap)
        box("fill", x + 4, 61, math.max(2, nextX - x - 7), 7,
          badgeOwned and DARK or MID)
        outline(x + 4, 61, math.max(2, nextX - x - 7), 7, INK)
      end
    end
    box("fill", 4, 76, 74, 29, PAPER)
    outline(4, 76, 74, 29, INK)
    text("MONEY", 8, 80, DARK)
    text(fit(THEME:format("¥%d", player.money or save.money or 0), 11), 8, 92, INK)
    box("fill", 82, 76, 74, 29, PAPER)
    outline(82, 76, 74, 29, INK)
    text("TIME", 86, 80, DARK)
    text(("%d:%02d"):format(math.floor(elapsed / 3600),
      math.floor(elapsed / 60) % 60), 86, 92, INK)
    box("fill", 4, 109, 74, 29, PAPER)
    outline(4, 109, 74, 29, INK)
    text("POKEDEX", 8, 113, DARK)
    text(("%d/%d"):format(owned,
      game.data.constants and game.data.constants.dexSize or dexTotal), 8, 125, INK)
    box("fill", 82, 109, 74, 29, PAPER)
    outline(82, 109, 74, 29, INK)
    text("STEPS", 86, 113, DARK)
    text(fit(compactSteps(steps), 8), 86, 125, INK)
    text(">", 146, 120, DARK)
  end

  local function drawStepsDetail()
    local exact = ("%.0f"):format(steps)
    header("STEPS", true)
    if THEME.style == "hgss" then
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:steps({ steps = exact })
      G.pop()
      return
    end
    box("fill", 76, 29, 7, 11, DARK)
    box("fill", 71, 37, 11, 9, DARK)
    box("fill", 69, 33, 3, 4, DARK)
    box("fill", 73, 30, 3, 4, DARK)
    centered(exact, 55, INK, #exact <= 12 and 2 or 1)
    centered("TOTAL", 82, DARK)
    button(34, 105, 92, 28, "RESET", false)
  end

  local function drawCaughtBall(x, y)
    if spriteCache.__caughtBall == nil then
      local data = game and game.data or {}
      local path, size
      if compat.isGen2() then
        local hud = data.gen2MenuGfx and data.gen2MenuGfx.battleHud
        path = hud and hud.balls
        size = 8
      else
        path = data.icons and data.icons.icons and data.icons.icons.BALL
        size = 16
      end
      local ok, asset = false, nil
      if path then
        ok, asset = pcall(function()
          local image = require("src.render.Assets").image(path)
          local width, height = image:getDimensions()
          size = math.min(size, width, height)
          return { image = image,
            quad = G.newQuad(0, 0, size, size, width, height), scale = 8 / size }
        end)
      end
      spriteCache.__caughtBall = ok and asset or false
    end
    local asset = spriteCache.__caughtBall
    if not asset then return false end
    G.setColor(1, 1, 1, 1)
    G.draw(asset.image, asset.quad, x, y, 0, asset.scale, asset.scale)
    return true
  end

  local function drawGuide()
    local guide = guideData()
    guidePage = math.max(1, math.min(guidePage, guide.pages))
    header(THEME:format("GUIDE %d/%d", guidePage, guide.pages), false, true)
    text(fit(guide.name, 15), 4, 23, DARK)
    local progress = THEME:format("%d/%d", guide.caught, #guide.rows)
    text(progress, 156 - #glyphList(progress) * 6, 23, INK)

    box("fill", 4, 34, 152, 12, guide.complete and DARK or MID)
    local status = #guide.rows > 0 and guide.section
      or "NO WILD ENCOUNTERS"
    centered(fit(status, 25), 37, guide.complete and PAPER or INK)

    for slot = 1, 3 do
      local row = guide.rows[(guidePage - 1) * 3 + slot]
      if row then
        local y = 48 + (slot - 1) * 31
        box("fill", 3, y, 154, 29, row.caught and MID or PAPER)
        outline(3, y, 154, 29, INK)
        local tint = not row.caught and DARK or nil
        drawSprite(row.species, "front", 5, y + 1, 27, 27, tint)
        text(fit(row.name, 11) .. ">", 35, y + 3, INK)
        local caughtBall = row.caught and drawCaughtBall(147, y + 2)
        if guide.timed and (not row.caught or caughtBall) then
          local times = {}
          for _, time in ipairs({ "MORN", "DAY", "NITE" }) do
            times[#times + 1] = (row.mapAllTimes or row.mapTimes[time])
              and fit(time, 1, false) or "-"
          end
          text(table.concat(times, " "), 112, y + 3, DARK)
        end
        if row.caught and not caughtBall then
          text(fit("CAUGHT", 7), 113, y + 3, DARK)
        end
        local minLevel = row.currentMinLevel or row.minLevel
        local maxLevel = row.currentMaxLevel or row.maxLevel
        local levels = minLevel == maxLevel and THEME:format("L%d", minLevel)
          or THEME:format("L%d-%d", minLevel, maxLevel)
        local methods1, methods2
        if row.availability == "now" then
          methods1, methods2 = methodLines(row.currentMethods)
        elseif row.availability == "time" then
          local shown, seen = {}, {}
          for _, appearance in ipairs(row.appearances) do
            if appearance.rank == 2 then
              local label = THEME:format("%s %d%%",
                appearance.time or "ALL", appearance.chance)
              if not seen[label] then shown[#shown + 1], seen[label] = label, true end
            end
          end
          methods1 = fit(shown[1] or THEME:translate("NOT NOW"), 14)
          methods2 = fit(shown[2] or "", 14)
        else
          methods1, methods2 = fit(THEME:translate("OTHER AREA"), 14), ""
        end
        text(methods1, 35, y + 13, DARK)
        text(methods2, 35, y + 21, DARK)
        text(levels, 156 - #glyphList(levels) * 6, y + 15, DARK)
      end
    end
  end

  displayRuntime.drawGuideDetail = function()
    local guide, row = guideData()
    for _, candidate in ipairs(guide.rows) do
      if candidate.species == displayRuntime.guideDetail.species then
        row = candidate break
      end
    end
    if not row then displayRuntime.guideDetail = nil; drawGuide(); return end
    local pages = math.max(1, tonumber(row.detailPages) or 1)
    local current = tonumber(displayRuntime.guideDetail.page) or 1
    displayRuntime.guideDetail.page = math.max(1, math.min(current, pages))
    header(THEME:format("WHERE %d/%d", displayRuntime.guideDetail.page,
      pages), true, pages > 1)
    text(fit(row.name, 17), 5, 24, INK)
    text(row.availability == "now" and THEME:translate("NOW")
      or row.availability == "time" and guide.time
      or THEME:translate("AREA"), 124, 24, DARK)
    for slot = 1, 3 do
      local appearance = row.appearances[
        (displayRuntime.guideDetail.page - 1) * 3 + slot]
      if appearance then
        local y = 36 + (slot - 1) * 33
        box("fill", 3, y, 154, 31, appearance.rank == 1 and MID or PAPER)
        outline(3, y, 154, 31, INK)
        text(fit(THEME:translate(appearance.section), 23), 7, y + 4, INK)
        local time = appearance.time or THEME:translate("ALL")
        local method = THEME:translate(appearance.method)
        text(fit(THEME:format("%s %s %d%%", time, method,
          appearance.chance), 18), 7, y + 15, DARK)
        local levels = appearance.minLevel == appearance.maxLevel
          and THEME:format("L%d", appearance.minLevel)
          or THEME:format("L%d-%d", appearance.minLevel, appearance.maxLevel)
        text(levels, 156 - #glyphList(levels) * 6, y + 15, DARK)
      end
    end
  end

  local function drawArea()
    local area = areaData()
    areaPage = math.max(1, math.min(areaPage, area.pages))
    local screen = area.screens[areaPage]
    header(THEME:format("AREA %d/%d", areaPage, area.pages), false, true)
    text(fit(area.name, 23), 5, 23, DARK)
    local complete = screen.total > 0 and screen.done == screen.total
    box("fill", 4, 34, 152, 12, complete and DARK or MID)
    local name = THEME:translate(screen.name)
    local status = screen.total == 0 and THEME:format("NO %s", name)
      or complete and THEME:format("+ %s CLEARED +", name)
      or THEME:format("%s %d/%d", name, screen.done, screen.total)
    centered(status, 37, complete and PAPER or INK)

    for slot = 1, screen.perPage do
      local row = screen.rows[(screen.page - 1) * screen.perPage + slot]
      if row then
        local y = 49 + (slot - 1) * 22
        box("fill", 3, y, 154, 20, row.done and MID or PAPER)
        outline(3, y, 154, 20, INK)
        text(fit(row.label, 18), 8, y + 7, INK)
        local status = fit(THEME:translate(
          row.status or (row.done and "DONE" or "OPEN")), 5)
        text(status, 156 - #glyphList(status) * 6, y + 7, DARK)
      end
    end
    if screen.name == "HIDDEN" and assist("item_radar") then
      button(20, 118, 120, 20,
        hasItemfinder() and "SCAN" or "NEED ITEMFINDER", false)
    end
  end

  local function drawRadar()
    header(THEME:translate("ITEM RADAR"), true)
    if THEME.style == "hgss" then
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:explorerRadar({
        route = areaName(mapId),
        progress = math.min(1, radarFrame / RADAR_FRAMES),
        ready = radarFrame >= RADAR_FRAMES,
        signals = radarSignals(),
      })
      G.pop()
      return
    end
    text(fit(areaName(mapId), 23), 5, 22, DARK)
    local gx, gy, cell, cols, rows = 25, 34, 10, 11, 9
    box("fill", gx, gy, cols * cell, rows * cell, PAPER)
    for col = 0, cols do
      box("fill", gx + col * cell, gy, 1, rows * cell, DARK)
    end
    for row = 0, rows do
      box("fill", gx, gy + row * cell, cols * cell, 1, DARK)
    end

    local cx, cy = gx + 5 * cell + cell / 2, gy + 4 * cell + cell / 2
    local progress = math.min(1, radarFrame / RADAR_FRAMES)
    local radius = math.sqrt((5 * cell) ^ 2 + (4 * cell) ^ 2) * progress
    if radius > 0 then
      G.setScissor(gx, gy, cols * cell, rows * cell)
      color(DARK)
      G.circle("line", cx, cy, radius)
      G.setScissor()
    end
    local signals = radarSignals()
    for _, signal in ipairs(signals) do
      local distance = math.sqrt((signal.dx * cell) ^ 2
        + (signal.dy * cell) ^ 2)
      if distance <= radius then
        box("fill", gx + (signal.dx + 5) * cell + 3,
          gy + (signal.dy + 4) * cell + 3, 5, 5, RADAR_RED)
      end
    end
    box("fill", cx - 3, cy - 3, 6, 6, INK)
    centered(radarFrame < RADAR_FRAMES and "SCANNING"
      or #signals == 0 and "NO SIGNAL"
      or THEME:format("SIGNALS %d", #signals), 132, DARK)
  end

  local function drawTools()
    if THEME.style == "hgss" then
      local actions = displayRuntime.toolModels()
      local pages = math.max(1, math.ceil(#actions / 4))
      tools.page = math.max(1, math.min(pages, tools.page or 1))
      header("FIELD KIT", true, pages > 1)
      G.push(); G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:tools({ actions = actions, page = tools.page, pages = pages })
      G.pop()
      return
    end
    local pages = math.max(1, math.ceil(#tools / 6))
    local current = math.max(1, math.min(pages, tools.page or 1))
    local first = (current - 1) * 6 + 1
    local count = math.min(6, math.max(0, #tools - first + 1))
    header(pages > 1 and THEME:format("TOOLS %d/%d", current, pages)
      or "TOOLS", THEME.style == "hgss"
        and displayRuntime.home.activeApp ~= nil,
      THEME.style ~= "hgss")
    if #tools == 0 then
      box("fill", 12, 42, 136, 58, MID)
      outline(12, 42, 136, 58, INK)
      if hasUnlockedTool(game and game.save) then
        centered("NO ACTION HERE", 59, INK)
        centered("CONTEXT REQUIRED", 76, DARK)
      else
        centered("NO TOOLS UNLOCKED", 59, INK)
        centered("KEEP EXPLORING", 76, DARK)
      end
      return
    end
    for slot = 1, count do
      local action = tools[first + slot - 1]
      local col, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
      button(3 + col * 78, 25 + row * 38, 76, 34, action.label, false)
    end
  end

  local function drawActionPrompt()
    if THEME.style == "hgss" then
      local icon = "tools"
      for _, model in ipairs(displayRuntime.toolModels()) do
        if model.id == pendingAction.id then icon = model.icon break end
      end
      G.push(); G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:toolPrompt({ label = pendingAction.label, icon = icon })
      G.pop()
      return
    end
    drawDim(0.54, false)
    box("fill", 10, 38, 140, 91, MID)
    outline(10, 38, 140, 91, PAPER)
    centered("USE", 49, DARK)
    centered(fit(pendingAction.label, 20), 66, INK)
    button(18, 91, 58, 27, "YES", true)
    button(84, 91, 58, 27, "NO", false)
  end

  local function partyData()
    local out = {}
    for i, mon in ipairs(game and game.save and game.save.party or {}) do
      local def = game.data.pokemon[mon.species] or {}
      local level = mon.level or 1
      local growth = def.growthRate
        and mod.content.growth_rates:get(def.growthRate)
        or mod.content.growth_rates:get("MEDIUM_FAST")
      local currentExp = growth and growth.expForLevel
        and math.max(0, growth.expForLevel(level)) or 0
      local nextExp = level < 100
        and growth and growth.expForLevel
        and math.max(0, growth.expForLevel(level + 1)) or currentExp
      out[i] = {
        slot = i, species = mon.species, source = mon,
        name = mon.nickname or (def and def.name) or mon.species,
        level = level, hp = mon.hp,
        maxHp = mon.stats and mon.stats.hp or mon.hp,
        status = mon.status, gender = mon.gender,
        expProgress = level >= 100 and 1
          or progressRatio(mon.exp, currentExp, nextExp),
      }
    end
    return out
  end

  function displayRuntime.partyView(mon)
    if not mon then return nil end
    local source = mon.source or mon
    local def = game.data.pokemon[mon.species] or {}
    local type1 = mon.types and mon.types[1] or def.types and def.types[1]
    local type2 = mon.types and (mon.types[2] or mon.types[1])
      or def.types and (def.types[2] or def.types[1])
    return {
      name = mon.name, egg = compat.partyEgg(source),
      gender = mon.gender, hp = mon.hp, maxHp = mon.maxHp,
      expProgress = mon.expProgress,
      statusId = (mon.hp or 0) <= 0 and "FNT"
        or THEME:statusName(mon.status, mod.content),
      type = type1, type2 = type2,
      typeLabel = THEME:typeName(type1, mod.content),
      type2Label = THEME:typeName(type2, mod.content),
      levelText = THEME:format("L%d", mon.level or 0),
      hpText = THEME:format("%d/%d", mon.hp or 0, mon.maxHp or 0),
      hpLabel = THEME:translate("HP"), expLabel = THEME:translate("EXP"),
    }
  end

  local function partyCard(mon, x, y, selected, details, focused)
    if THEME.style == "hgss" then
      local source = mon and (mon.source or mon)
      local view = displayRuntime.partyView(mon)
      THEME.hgss:partyCard(view, x, y, selected, details,
        function(_, portraitX, portraitY, size, fainted)
          if compat.partyEgg(source) then
            compat.drawPokemonIcon(source, portraitX, portraitY, size,
              fainted and 0.48 or nil)
          elseif not drawSprite(mon.species, "front", portraitX, portraitY,
              size, size, nil, source, true, fainted and 0.48 or nil) then
            compat.drawPokemonIcon(source, portraitX, portraitY, size,
              fainted and 0.48 or nil)
          end
        end, focused)
      return
    end
    box("fill", x, y, 75, 36, selected and DARK or MID)
    outline(x, y, 75, 36, INK)
    if not mon then
      text("-", x + 35, y + 14, DARK)
      return
    end
    local source = mon.source or mon
    local name = fit(mon.name, details and 6 or 7) .. (details and ">" or "")
    if compat.partyEgg(source) then
      compat.drawPokemonIcon(source, x + 2, y + 2)
      text(name, x + 29, y + 9, selected and PAPER or INK)
      return
    end
    if not drawSprite(mon.species, "front", x + 2, y + 4, 27, 27,
                      nil, source, true) then
      compat.drawPokemonIcon(source, x + 2, y + 2)
    end
    text(name, x + 29, y + 4, selected and PAPER or INK)
    text(THEME:format("L%d", mon.level or 0), x + 29, y + 14,
         selected and PAPER or DARK)
    hpBar(x + 29, y + 25, 41, mon.hp, mon.maxHp)
    expBar(x + 29, y + 30, 41, mon.expProgress or 0, selected)
    if (mon.hp or 0) <= 0 then
      text("FNT", x + 52, y + 14, selected and PAPER or INK)
    elseif mon.status then
      text(fit(THEME:statusName(mon.status, mod.content), 3),
           x + 52, y + 14, selected and PAPER or INK)
    end
  end

  function displayRuntime.homePageElements()
    local home = displayRuntime.home
    local tiles = displayRuntime.Home.tiles(home.layout,
      displayRuntime.homeCatalog, home.page)
    local slots = home.editing and displayRuntime.Home.plusSlots(
      home.layout, displayRuntime.homeCatalog, home.page, home.swapSource)
      or nil
    if slots then
      local rowItems = {}
      for _, tile in ipairs(tiles) do rowItems[#rowItems + 1] = tile end
      for _, slot in ipairs(slots) do rowItems[#rowItems + 1] = slot end
      displayRuntime.Home.spaceRows(rowItems)
    end
    return tiles, slots
  end

  function displayRuntime.drawHome()
    local home = displayRuntime.home
    local layout = home.layout or { tiles = {} }
    local pages = displayRuntime.Home.pageCount(layout)
      + (home.editing and 1 or 0)
    home.page = math.max(1, math.min(pages, home.page or 1))
    header(home.library and "ADD TO HOME"
      or home.editing and "EDIT HOME" or "SILPH LINK", home.library == true)
    local tiles, slots = displayRuntime.homePageElements()
    local needed = {}
    for _, tile in ipairs(tiles or {}) do
      if tile.widget then needed[tile.widget] = true end
    end
    local overview = needed.explorer and loadLocalMap() or nil
    local explorer = overview and displayRuntime.explorerModel(overview) or {}
    local party = needed.party and partyData() or {}
    local lead = party[1]
    local leadView = lead and displayRuntime.partyView(lead) or nil
    local dex = (needed.pokedex or needed.trainer)
      and displayRuntime.pokedexData() or { entries = {}, caught = 0, total = 0 }
    local dexSeen, dexLatest = 0, nil
    for _, entry in ipairs(dex.entries or {}) do
      if entry.seen then dexSeen = dexSeen + 1 end
      if entry.caught then dexLatest = entry end
    end
    local trainer = needed.trainer and displayRuntime.trainerSummary() or nil
    local model = {
      page = home.page, pages = pages,
      tiles = tiles,
      editing = home.editing,
      slots = slots,
      dragging = home.swapSource,
      route = explorer.route or "UNKNOWN AREA",
      overview = overview, image = explorer.image,
      player = explorer.player, markers = explorer.markers,
      lead = leadView,
      steps = compactSteps(steps),
      dexCaught = dex.caught, dexSeen = dexSeen, dexTotal = dex.total,
      dexLatest = dexLatest,
      trainer = trainer,
      bag = needed.bag and displayRuntime.bagSummary() or nil,
      regionMap = needed.map and displayRuntime.homeRegionMap() or nil,
      storePromo = needed.store and displayRuntime.storeWidgetSummary() or nil,
      drawPlayer = explorer.drawPlayer, drawTrainer = explorer.drawTrainer,
      drawPokemon = function(_, x, y, size)
        if not lead then return end
        local source = lead.source or lead
        if compat.partyEgg(source) then
          compat.drawPokemonIcon(source, x, y, size)
        elseif not drawSprite(lead.species, "front", x, y, size, size,
            nil, source, true) then
          compat.drawPokemonIcon(source, x, y, size)
        end
      end,
      drawDexPokemon = function(entry, x, y, size)
        if not entry then return end
        drawSprite(entry.species, "front", x, y, size, size,
          nil, nil, true)
      end,
    }
    if home.library and home.addSlot then
      model.tiles, model.slots = nil, nil
      model.libraryKind = home.libraryKind
      model.library = displayRuntime.Home.library(layout,
        displayRuntime.homeCatalog, home.page,
        home.addSlot.column, home.addSlot.row, home.libraryKind)
      model.libraryPages = math.max(1, math.ceil(#model.library / 6))
      model.libraryPage = math.max(1, math.min(model.libraryPages,
        home.libraryPage or 1))
    end
    G.push(); G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    THEME.hgss:home(model)
    if home.editing and not home.library then THEME.hgss:homeEditDone() end
    G.pop()
  end

  function displayRuntime.storeEntries(installedOnly)
    local apps = {}
    for _, app in ipairs(displayRuntime.storeCatalog) do
      local entry = displayRuntime.storeEntry(app)
      if not installedOnly or entry.state == "open" then
        apps[#apps + 1] = entry
      end
    end
    return apps
  end

  displayRuntime.storePageSizes = { apps = 6, library = 4 }
  function displayRuntime.storePageSlice(entries, page, size)
    local pages = math.max(1, math.ceil(#entries / size))
    page = math.max(1, math.min(pages, tonumber(page) or 1))
    local first, shown = (page - 1) * size + 1, {}
    for index = first, math.min(#entries, first + size - 1) do
      shown[#shown + 1] = entries[index]
    end
    return shown, page, pages, first - 1
  end
  do
    local shown, page, pages, offset = displayRuntime.storePageSlice(
      { "A", "B", "C", "D", "E", "F", "G" }, 2, 4)
    assert(#shown == 3 and shown[1] == "E" and shown[3] == "G"
        and page == 2 and pages == 2 and offset == 4,
      "Silph Store pagination exposes every catalog entry")
  end

  function displayRuntime.storePage(view, entries)
    local home = displayRuntime.home
    home.storePages = home.storePages or {}
    local shown, page, pages, offset = displayRuntime.storePageSlice(entries,
      home.storePages[view], displayRuntime.storePageSizes[view])
    home.storePages[view] = page
    return shown, page, pages, offset
  end

  function displayRuntime.cycleStorePage(view, direction)
    local entries = displayRuntime.storeEntries(view == "library")
    local _, page, pages = displayRuntime.storePage(view, entries)
    displayRuntime.home.storePages[view] =
      (page - 1 + direction) % pages + 1
  end

  function displayRuntime.storeSwipeTarget(view, y, pages)
    return (view == "apps" or view == "library")
      and (pages or 1) > 1 and y >= 53 and y < 195
  end
  assert(displayRuntime.storeSwipeTarget("apps", 53, 2)
      and displayRuntime.storeSwipeTarget("library", 194, 3)
      and not displayRuntime.storeSwipeTarget("apps", 52, 2)
      and not displayRuntime.storeSwipeTarget("apps", 195, 2)
      and not displayRuntime.storeSwipeTarget("apps", 100, 1)
      and not displayRuntime.storeSwipeTarget("today", 100, 2),
    "Silph Store app-grid swipes target paginated app lists")

  function displayRuntime.storeTodayEntries()
    local featured
    for _, app in ipairs(displayRuntime.storeCatalog) do
      if app.featured and app.available ~= false then
        featured = app
        break
      end
    end
    return {
      displayRuntime.storeEntry(featured or displayRuntime.storeById.tools),
      displayRuntime.storeEntry(displayRuntime.storeById.party),
      displayRuntime.storeEntry(displayRuntime.storeById.bag),
    }
  end

  function displayRuntime.storeWidgetSummary()
    local installed, available, promo = 0, 0, nil
    for _, app in ipairs(displayRuntime.storeCatalog) do
      local package = displayRuntime.homeCatalog.packages[app.id]
      if app.available ~= false then
        available = available + 1
        if package and package.installed then installed = installed + 1 end
        if not promo and app.new and package and not package.installed then
          promo = app
        end
      end
    end
    if promo then
      return { icon = promo.icon, label = promo.label,
        category = promo.category, new = true }
    end
    return { icon = "store", label = "APPS",
      installed = installed, available = available }
  end

  function displayRuntime.cycleStoreView(direction)
    local home = displayRuntime.home
    local views = { "today", "apps", "library" }
    local current = 1
    for index, view in ipairs(views) do
      if view == home.storeView then current = index break end
    end
    home.storeView = views[(current - 1 + direction) % #views + 1]
  end

  function displayRuntime.enrichStorePreview(entry)
    if not entry then return entry end
    if entry.id == "explorer" then
      local overview = loadLocalMap()
      if overview then entry.preview = displayRuntime.explorerModel(overview) end
    elseif entry.id == "map" then
      entry.preview = {
        region = (compat.currentRegion() or "kanto"):upper(),
        location = areaName(mapId),
      }
    elseif entry.id == "party" then
      local party = partyData()
      entry.preview = { party = party,
        drawPokemon = function(mon, x, y, size)
          local source = mon.source or mon
          if not drawSprite(mon.species, "front", x, y, size, size,
              nil, source, true) then
            compat.drawPokemonIcon(source, x, y, size)
          end
        end }
    elseif entry.id == "pokedex" then
      local dex, entries = displayRuntime.pokedexData(), {}
      for index = 1, math.min(6, #(dex.entries or {})) do
        entries[index] = dex.entries[index]
      end
      entry.preview = { entries = entries,
        page = 1,
        pages = math.max(1, math.ceil(#(dex.entries or {}) / 9)),
        progress = (tonumber(dex.caught) or 0)
          / math.max(1, tonumber(dex.total) or 1),
        drawPokemon = function(row, x, y, size)
          local tint = not row.caught and (row.seen
              and THEME.hgss.colors.silver or THEME.hgss.colors.shadow)
            or nil
          drawSprite(row.species, "front", x, y, size, size,
            tint, nil, true)
        end }
    elseif entry.id == "bag" then
      entry.preview = displayRuntime.bagModel()
    elseif entry.id == "trainer" then
      entry.preview = displayRuntime.trainerSummary()
    elseif entry.id == "steps" then
      entry.preview = { steps = compactSteps(steps) }
    end
    return entry
  end

  function displayRuntime.drawStore()
    local home, view = displayRuntime.home, displayRuntime.home.storeView
    local detail = home.storeDetail and displayRuntime.enrichStorePreview(
      displayRuntime.storeEntry(displayRuntime.storeById[home.storeDetail]))
    header(detail and detail.label or "SILPH STORE", true, not detail)
    G.push(); G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    if detail then
      THEME.hgss:storeDetail({ app = detail })
    elseif view == "apps" then
      local apps, page, pages = displayRuntime.storePage(
        view, displayRuntime.storeEntries())
      THEME.hgss:storeApps({ apps = apps, page = page, pages = pages })
    elseif view == "library" then
      local all = displayRuntime.storeEntries(true)
      local apps, page, pages = displayRuntime.storePage(view, all)
      THEME.hgss:storeMyApps({
        summary = THEME:format("%d APPS READY", #all), apps = apps,
        page = page, pages = pages,
      })
    else
      local today = displayRuntime.storeTodayEntries()
      displayRuntime.enrichStorePreview(today[1])
      THEME.hgss:storeToday({
        featured = today[1], recommended = { today[2], today[3] },
      })
    end
    G.pop()
  end

  local function drawParty(list, title, back, activeSpecies, selectedSlot,
                           paged)
    header(title or "PARTY", back or displayRuntime.home.activeApp ~= nil,
      paged and displayRuntime.home.activeApp == nil)
    if THEME.style == "hgss" then
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:partyBackdrop()
      for i = 1, 6 do
        local mon = list[i]
        local x, y = THEME.hgss:partyPosition(i)
        partyCard(mon, x, y,
          selectedSlot and selectedSlot == i
            or (not selectedSlot and mon and (mon.active
              or (activeSpecies and mon.species == activeSpecies))),
          paged and not back)
      end
      G.pop()
      return
    end
    for i = 1, 6 do
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
      local mon = list[i]
      partyCard(mon, 3 + col * 78, 23 + row * 39,
                selectedSlot and selectedSlot == i
                  or (not selectedSlot and mon and (mon.active
                    or (activeSpecies and mon.species == activeSpecies))),
                paged and not back)
    end
  end

  local function drawNormalParty()
    local swapCommit = THEME.style == "hgss"
      and hgssRuntime.animation
      and hgssRuntime.animation.kind == "party_swap_commit"
      and hgssRuntime.progress("party_swap_commit")
    if THEME.style == "hgss" and (partyMoveFrom or swapCommit) then
      local source = partyMoveFrom or hgssRuntime.animation.source
      local list = swapCommit and hgssRuntime.animation.party or partyData()
      header(THEME:translate("SWAP WITH?"), true)
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:partyBackdrop()
      local function drawSwapCard(slot, x, y, selected, details)
        partyCard(list[slot], x, y, selected, details)
      end
      local entering = hgssRuntime.progress("party_swap")
      if entering then
        THEME.hgss:partySwapTransition(drawSwapCard, source, source,
          entering, hgssRuntime.animation.actionCount or 2,
          THEME:translate("STATS"), THEME:translate("SWAP"))
      elseif swapCommit then
        THEME.hgss:partySwapCommitTransition(drawSwapCard,
          hgssRuntime.animation.source, hgssRuntime.animation.target, swapCommit)
      else
        THEME.hgss:partySwap(drawSwapCard, source, source)
      end
      G.pop()
      return
    end
    drawParty(partyData(), partyMoveFrom and "MOVE WHERE?" or "PARTY",
              partyMoveFrom ~= nil,
              nil, partyMoveFrom, partyMoveFrom == nil)
  end

  local function drawPartyAction()
    local mon = partyData()[partyActionSlot]
    if not mon then drawNormalParty(); return end
    if THEME.style == "hgss" then
      local canSwap = #(game.save.party or {}) > 1
        and mod.world and mod.world.canReorderParty
        and mod.world:canReorderParty()
      local count = canSwap and 2 or 1
      local offset = THEME.hgss:partyActionOffset(love.timer.getTime())
      header(THEME:translate("PARTY"), true)
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:partyBackdrop()
      partyCard(mon, 64, THEME.hgss:partyActionHeroY(count)
        + math.floor(offset / 2), true, false, false)
      local x, y, w, h = THEME.hgss:partyActionRow(1, count)
      THEME.hgss:actionRow(x, y, w, h, THEME:translate("STATS"),
        "stats", offset)
      if canSwap then
        x, y, w, h = THEME.hgss:partyActionRow(2, count)
        THEME.hgss:actionRow(x, y, w, h, THEME:translate("SWAP"),
          "swap", offset)
      end
      G.pop()
      return
    end
    header(fit(mon.name, 18), true)
    button(14, 37, 132, 38, "STATS", false)
    if #(game.save.party or {}) > 1 then
      button(14, 84, 132, 38, "SWAP", false)
    end
  end

  local function drawFieldChoice()
    if fieldChoice.kind == "fish" then
      header("CHOOSE ROD", true)
      if THEME.style == "hgss" then
        G.push(); G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        THEME.hgss:rodPicker(fieldChoice.action.rods)
        G.pop()
        return
      end
      for i, rod in ipairs(fieldChoice.action.rods or {}) do
        button(14, 30 + (i - 1) * 37, 132, 32, rod.label, false)
      end
      return
    end
    local choices = fieldChoice.kind == "soft_source"
      and fieldChoice.action.sources or fieldChoice.source.targets
    drawParty(choices, fieldChoice.kind == "soft_source"
      and "HEAL WITH" or "HEAL TARGET", true)
  end

  function hgssRuntime.numberLabel(value)
    value = tonumber(value)
    if not value then return "--" end
    if value == math.floor(value) then return tostring(value) end
    return ("%.1f"):format(value)
  end

  function hgssRuntime.moveView(move, enemyTypes)
    local source = compat.moveInfoEntry(move)
      or type(move) == "table" and move or {}
    local def = game.data.moves[source.id] or {}
    local moveType = source.type or def.type
    local power = source.displayPower
    if power == nil then power = source.power or def.power end
    if power == 0 then power = nil end
    local accuracy = source.hitChance
    if accuracy == nil then accuracy = source.accuracy or def.accuracy end
    local maxPp = source.maxPp or def.pp or source.pp or 0
    return {
      id = source.id,
      available = source.id ~= nil,
      name = THEME:moveName(source, game.data),
      type = moveType,
      typeLabel = THEME:typeName(moveType, mod.content),
      ppLabel = THEME:translate("PP"),
      ppText = THEME:format("%d/%d", source.pp or maxPp, maxPp),
      powerLabel = THEME:translate("PWR"),
      power = power or 0,
      powerText = hgssRuntime.numberLabel(power),
      accuracyLabel = THEME:translate("ACC"),
      accuracyText = hgssRuntime.numberLabel(accuracy),
      stabLabel = "STAB",
      matchupLabel = THEME:translate("MATCHUP"),
      effectiveness = source.effectiveness or enemyTypes
        and assist("type_hints") and compat.typeEffectiveness(
          moveType, enemyTypes, game.data.type_chart) or nil,
      disabled = THEME:moveUnavailableReason(source) ~= nil,
      descriptionLines = compat.moveInfoLines(source, def,
        battleState() and battleState().ruleset),
    }
  end

  function hgssRuntime.battleMon()
    local player = battle and battle.player or {}
    local def = game.data.pokemon[player.species] or {}
    local view = {
      species = player.species, source = player,
      name = player.name or def.name or player.species or "POKEMON",
      types = def.types or {},
      fightLabel = THEME:translate("FIGHT"),
      bagLabel = THEME:translate("BAG"),
      partyLabel = THEME:translate("POKEMON"),
      runLabel = THEME:translate("RUN"),
      moveIndex = battle.moveIndex or 1,
      moves = {},
    }
    for slot = 1, 4 do
      local move = (battle.moves or {})[slot] or {}
      view.moves[slot] = hgssRuntime.moveView(move)
    end
    return view
  end

  function hgssRuntime.battlePortrait(mon, x, y, size, fainted)
    if not drawSprite(mon.species, "front", x, y, size, size,
        nil, mon.source or mon, true, fainted and 0.48 or nil) then
      compat.drawPokemonIcon(mon.source or mon, x, y, size,
        fainted and 0.48 or nil)
    end
  end

  function hgssRuntime.battleTeams()
    local playerTeam, enemyTeam = {}, {}
    local function teamState(source)
      source = source or {}
      local mon = source.mon or source
      return {
        alive = (source.shownHP or mon.hp or 0) > 0,
        status = THEME:statusName(source.shownStatus or mon.status, mod.content),
      }
    end
    for slot, mon in ipairs(battle.party or {}) do
      playerTeam[slot] = teamState(mon)
    end
    local raw = battleState()
    local enemies = raw and (raw.enemyParty
      or raw.battle and raw.battle.enemyParty) or nil
    if enemies then
      for slot, mon in ipairs(enemies) do
        enemyTeam[slot] = teamState(mon)
      end
    elseif battle.enemy then
      enemyTeam[1] = teamState(battle.enemy)
    end
    if battle.kind == "wild" or battle.wild then
      local enemy = battle.enemy or {}
      local def = game.data.pokemon[enemy.species] or {}
      enemyTeam.wild = true
      enemyTeam.name = enemy.name or def.name or enemy.species or "POKEMON"
      enemyTeam.level = enemy.level
    end
    return playerTeam, enemyTeam
  end

  function hgssRuntime.clock()
    local now = os.time()
    return compactClock(mod.datetime:time(game,
      compat.clockTimestamp(game, mod.options:get("clock_source"), now))),
      compat.isGen2() and compat.timePeriod(game.world) or nil
  end

  function hgssRuntime.bagView(menu)
    local odds, kinds = {}, {}
    local showCatchOdds = assist("catch_odds")
      and (caughtWild(battle.kind, true) or battle.wild == true)
    for _, item in ipairs(battle.items or {}) do
      local id = tostring(item.id or ""):upper()
      local kind = item.ball and "ball"
        or (id:match("^TM%d") or id:match("^HM%d")) and "machine"
        or (id:find("HEAL", 1, true) or id == "ANTIDOTE"
          or id == "AWAKENING") and "status"
        or item.needsTarget and "medicine" or "item"
      odds[item.id], kinds[item.id] = item.catchChance, kind
    end
    local items = {}
    for index, item in ipairs(menu.items or {}) do
      local label = item.label or tostring(index)
      local icon = kinds[item.value]
      local upper = tostring(label):upper()
      if upper:match("^TM%d") or upper:match("^HM%d") then
        icon = "machine"
      end
      items[index] = {
        value = item.value, label = label,
        right = item.right, cancel = item.cancel,
        catchChance = showCatchOdds and odds[item.value] or nil,
        catchLabel = THEME:translate("CATCH"), icon = icon or "item",
      }
    end
    return {
      title = menu.title or "BAG", items = items,
      index = menu.index or 1, categorized = categorizedBag(menu),
    }
  end

  function hgssRuntime.summaryView(summary)
    local view = compat.summary.view(summary, game)
    if not view then return nil end
    local mon, def = view.mon, view.def
    local types = view.types or {}
    local level = view.level or 0
    local growth = def.growthRate
      and mod.content.growth_rates:get(def.growthRate)
      or mod.content.growth_rates:get("MEDIUM_FAST")
    local currentLevelExp = growth and growth.expForLevel
      and growth.expForLevel(level) or view.experience
    local nextLevelExp = level < 100 and growth and growth.expForLevel
      and growth.expForLevel(level + 1) or currentLevelExp
    local nextValue = level < 100 and (view.nextExp
      or math.max(0, nextLevelExp - view.experience)) or nil
    local out = {
      source = mon, species = mon.species, name = view.name,
      gender = mon.gender, statusId = THEME:statusName(view.status, mod.content),
      type = types[1], type2 = types[2] or types[1],
      typeLabel = THEME:typeName(types[1], mod.content),
      type2Label = THEME:typeName(types[2] or types[1], mod.content),
      dexText = THEME:format("NO.%03d", view.dex or 0),
      levelText = THEME:format("L%d", level),
      hp = view.hp, maxHp = view.maxHp,
      hpLabel = THEME:translate("HP"),
      hpText = THEME:format("%d/%d", view.hp, view.maxHp),
      expLabel = THEME:translate("EXP"),
      expProgress = level >= 100 and 1
        or progressRatio(view.experience, currentLevelExp, nextLevelExp),
      nextLabel = THEME:translate("NEXT"),
      nextValue = nextValue and tostring(nextValue) or nil,
      infoLabel = view.gen2 and THEME:translate("ITEM") or "OT",
      infoText = view.gen2 and (view.item or "---") or view.ot,
      info2Label = view.gen2 and nil or "ID",
      info2Text = view.gen2 and nil or ("%05d"):format(view.otId or 0),
      statsTitle = THEME:translate("BATTLE STATS"),
      moves = {}, stats = {},
      memoTitle = THEME:translate("TRAINER MEMO"),
      otLabel = THEME:translate("ORIGINAL TRAINER"),
      otText = view.ot,
      idLabel = THEME:translate("ID NO."),
      idText = ("%05d"):format(view.otId or 0),
      growthTitle = THEME:translate("GROWTH RECORD"),
      totalExpLabel = THEME:translate("TOTAL EXP"),
      experienceText = tostring(view.experience or 0),
      nextLevelLabel = THEME:translate("NEXT LEVEL"),
      nextLevelText = level < 100 and THEME:format("L%d", level + 1) or "MAX",
      nextExpLabel = THEME:translate("TO NEXT"),
      moveDetails = battle ~= nil and assist("move_details"),
    }
    local stats = view.stats or {}
    local rows = view.gen2 and {
      { "ATTACK", stats.attack }, { "DEFENSE", stats.defense },
      { "SPEED", stats.speed }, { "SP. ATK", stats.specialAttack },
      { "SP. DEF", stats.specialDefense }, { "MAX HP", view.maxHp },
    } or {
      { "ATTACK", stats.attack }, { "SPEED", stats.speed },
      { "DEFENSE", stats.defense }, { "SPECIAL", stats.special },
    }
    for _, row in ipairs(rows) do
      out.stats[#out.stats + 1] = {
        label = THEME:translate(row[1]), value = row[2] or 0,
      }
    end
    for slot = 1, 4 do
      local source = mon.moves and mon.moves[slot] or {}
      local move = game.data.moves[source.id] or {}
      out.moves[slot] = {
        available = source.id ~= nil,
        name = move.name or source.id or "-", type = move.type,
        typeLabel = THEME:typeName(move.type, mod.content),
        ppLabel = THEME:translate("PP"),
        ppText = source.id and THEME:format("%d/%d",
          source.pp or 0, view.moves[slot].maxPp or move.pp or 0) or "--",
        powerLabel = THEME:translate("PWR"),
        powerText = move.power and move.power > 0 and tostring(move.power) or "--",
        accuracyLabel = THEME:translate("ACC"),
        accuracyText = move.accuracy and tostring(move.accuracy) or "--",
      }
    end
    out.moveIndex = summary.moveIndex or 1
    return out, view
  end

  function hgssRuntime.summaryPortrait(mon, x, y, size, fainted)
    if not drawSprite(mon.species, "front", x, y, size, size,
        nil, mon.source or mon, true, fainted and 0.48 or nil) then
      compat.drawPokemonIcon(mon.source or mon, x, y, size,
        fainted and 0.48 or nil)
    end
  end

  local function drawBattleRoot()
    if THEME.style == "hgss" then
      local mon = hgssRuntime.battleMon()
      local playerTeam, enemyTeam = hgssRuntime.battleTeams()
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      local movesClose = hgssRuntime.progress("battle_moves_close")
      local bagClose = hgssRuntime.progress("battle_bag_close")
      local partyClose = hgssRuntime.progress("battle_party_close")
      if movesClose then
        THEME.hgss:battleMovesTransition(mon, hgssRuntime.battlePortrait,
          playerTeam, enemyTeam, 1 - movesClose)
      elseif bagClose and hgssRuntime.lastBag then
        THEME.hgss:battleBagTransition(mon, hgssRuntime.battlePortrait,
          playerTeam, enemyTeam, hgssRuntime.lastBag, 1 - bagClose)
      elseif partyClose then
        local list = battle.party or {}
        local clock, period = hgssRuntime.clock()
        THEME.hgss:battlePartyTransition(mon, hgssRuntime.battlePortrait,
          playerTeam, enemyTeam, function(slot, x, y, focused, details)
            partyCard(list[slot], x, y, focused, details)
          end, 1 - partyClose, THEME:translate("PARTY"), clock, period)
      else
        THEME.hgss:battleRoot(mon, hgssRuntime.battlePortrait,
          playerTeam, enemyTeam, battle.menuIndex)
      end
      G.pop()
      return
    end
    header(battle.kind == "wild" and "Wild battle"
      or battle.kind == "trainer" and "Trainer battle" or "BATTLE")
    button(3, 24, 76, 54, "FIGHT", battle.menuIndex == 1)
    button(81, 24, 76, 54, "PKMN", battle.menuIndex == 2)
    button(3, 81, 76, 56, "ITEM", battle.menuIndex == 3)
    button(81, 81, 76, 56, "RUN", battle.menuIndex == 4)
  end

  local function drawSafari()
    if THEME.style == "hgss" then
      local playerTeam, enemyTeam = hgssRuntime.battleTeams()
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:battleSafari({ balls = battle.safariBalls or 0,
        index = battle.menuIndex or 1 }, playerTeam, enemyTeam)
      G.pop()
      return
    end
    header("SAFARI")
    button(3, 24, 76, 54,
           THEME:format("BALL x%d", battle.safariBalls or 0),
           battle.menuIndex == 1)
    button(81, 24, 76, 54, "BAIT", battle.menuIndex == 2)
    button(3, 81, 76, 56, "THROW ROCK", battle.menuIndex == 3)
    button(81, 81, 76, 56, "RUN", battle.menuIndex == 4)
  end

  local function drawMimic()
    if THEME.style == "hgss" then
      local moves = {}
      for slot, move in ipairs(battle.mimicMoves or {}) do
        moves[slot] = hgssRuntime.moveView(move)
      end
      local playerTeam, enemyTeam = hgssRuntime.battleTeams()
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:battleMimic({ moves = moves,
        index = battle.mimicIndex or 1 }, playerTeam, enemyTeam)
      G.pop()
      return
    end
    header("MIMIC")
    for i, move in ipairs(battle.mimicMoves or {}) do
      button(8, 25 + (i - 1) * 28, 144, 25,
             THEME:moveName(move, game and game.data), battle.mimicIndex == i)
    end
  end

  local function effectLabel(mult)
    if mult == nil then return "--" end
    if mult == 0 then return "0X" end
    if mult > 10 then return mult >= 40 and "4X" or "2X" end
    if mult < 10 then return mult <= 2 and "1/4" or "1/2" end
    return "1X"
  end

  local function chanceLabel(chance)
    if chance == nil then return "--" end
    if chance == math.floor(chance) then return ("%d%%"):format(chance) end
    return ("%.1f%%"):format(chance)
  end

  displayRuntime.moveInfoBadge = function(x, y, dark)
    outline(x, y, 11, 11, dark and PAPER or INK)
    text("X", x + 3, y + 2, dark and PAPER or INK)
  end

  local function moveCard(move, x, y, selected)
    local unavailable = THEME:moveUnavailableReason(move)
    local disabled = unavailable ~= nil
    local dark = selected and not disabled
    box("fill", x, y, 76, 53, disabled and PAPER or dark and DARK or MID)
    outline(x, y, 76, 53, disabled and DARK or INK)
    text(fit(THEME:moveName(move, game and game.data), 10),
         x + 4, y + 4, dark and PAPER or INK)
    text(unavailable and fit(THEME:translate(unavailable), 10, false)
         or THEME:format("PP %d/%d", move.pp or 0, move.maxPp or 0),
         x + 4, y + 19, dark and PAPER or DARK)
    text(fit(THEME:typeName(move.type, mod.content), 7), x + 4, y + 34,
         dark and PAPER or DARK)
    if assist("type_hints") then
      text(effectLabel(move.effectiveness), x + 56, y + 34,
           dark and PAPER or INK)
    end
    if assist("move_details") then
      displayRuntime.moveInfoBadge(x + 63, y + 2, dark)
    end
  end

  local function moveRow(move, y, selected)
    local unavailable = THEME:moveUnavailableReason(move)
    local disabled = unavailable ~= nil
    local dark = selected and not disabled
    box("fill", 8, y, 144, 27, disabled and PAPER or dark and DARK or MID)
    outline(8, y, 144, 27, disabled and DARK or INK)
    text(fit(THEME:moveName(move, game and game.data), 11),
         12, y + 3, dark and PAPER or INK)
    text(unavailable and fit(THEME:translate(unavailable), 8, false)
         or THEME:format("PP %d/%d", move.pp or 0, move.maxPp or 0),
         88, y + 3, dark and PAPER or DARK)
    text(fit(THEME:typeName(move.type, mod.content), 7), 12, y + 15,
         dark and PAPER or DARK)
    if assist("type_hints") then
      text(effectLabel(move.effectiveness), 110, y + 15,
           dark and PAPER or INK)
    end
    if assist("move_details") then
      displayRuntime.moveInfoBadge(139, y + 14, dark)
    end
  end

  local function drawMoves()
    if THEME.style == "hgss" then
      local mon = hgssRuntime.battleMon()
      local playerTeam, enemyTeam = hgssRuntime.battleTeams()
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      local progress = hgssRuntime.progress("battle_moves")
      local closing = hgssRuntime.progress("battle_moves_close")
      local infoClose = hgssRuntime.progress("battle_move_info_close")
      if infoClose then
        THEME.hgss:battleMoveInfoTransition(mon, playerTeam, enemyTeam,
          1 - infoClose)
      elseif progress or closing then
        THEME.hgss:battleMovesTransition(mon, hgssRuntime.battlePortrait,
          playerTeam, enemyTeam, closing and 1 - closing or progress)
      else
        THEME.hgss:battleMoves(mon, playerTeam, enemyTeam)
      end
      G.pop()
      return
    end
    header("MOVES", true)
    local grid = companionMoveGrid(battleState())
    for i = 1, 4 do
      local move = battle.moves[i]
      if move then
        if grid then
          local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
          moveCard(move, 3 + col * 78, 24 + row * 56,
                   battle.moveIndex == i)
        else
          moveRow(move, 24 + (i - 1) * 28, battle.moveIndex == i)
        end
      end
    end
  end

  function compat.typeEffectiveness(moveType, defenderTypes, chart)
    if not (moveType and defenderTypes and defenderTypes[1] and chart) then
      return nil
    end
    local multiplier = 10
    for _, row in ipairs(chart.matchups or {}) do
      if row.attacker == moveType then
        for _, defenderType in ipairs(defenderTypes) do
          if row.defender == defenderType then
            multiplier = math.floor(multiplier * row.multiplier / 10)
            break
          end
        end
      end
    end
    return multiplier
  end

  function compat.enemyDvs(mon)
    local source = type(mon) == "table" and mon.dvs
    if type(source) ~= "table" then return nil end
    local out = {}
    for _, key in ipairs({ "attack", "defense", "speed", "special" }) do
      local value = tonumber(source[key])
      if not value or value % 1 ~= 0 or value < 0 or value > 15 then return nil end
      out[key] = value
    end
    local hp = tonumber(source.hp)
    if hp == nil then
      hp = (out.attack % 2) * 8 + (out.defense % 2) * 4
        + (out.speed % 2) * 2 + (out.special % 2)
    end
    if hp % 1 ~= 0 or hp < 0 or hp > 15 then return nil end
    out.hp = hp
    return out
  end

  function compat.enemyInfo(enemy, data, save, mon)
    enemy, data = enemy or {}, data or {}
    local species = enemy.species
    local def = species and data.pokemon and data.pokemon[species] or {}
    local entry = compat.isGen2()
      and data.gen2Pokedex and data.gen2Pokedex.entries
      and data.gen2Pokedex.entries[species] or def.dexEntry
    local dex = save and save.pokedex or {}
    local seen, caught = dex.seen or {}, compat.caughtDex(save)
    local info = {
      species = species,
      name = enemy.name or def.name or species or "-",
      level = enemy.level,
      dex = entry and entry.dex or def.dex,
      types = {},
      seen = species and not not seen[species] or false,
      caught = species and not not caught[species] or false,
      dvs = compat.enemyDvs(mon or enemy),
      weak = {}, resist = {},
      kind = entry and entry.kind,
      description = {},
    }
    for _, typeId in ipairs(def.types or {}) do
      if typeId ~= info.types[#info.types] then
        info.types[#info.types + 1] = typeId
      end
    end
    if entry then
      local heightM, height = tonumber(entry.heightM), tonumber(entry.height)
      if heightM then
        info.height = THEME:format("HEIGHT %.1f M", heightM)
        info.weight = THEME:format("WEIGHT %.1f KG",
          tonumber(entry.weightKg) or 0)
      elseif compat.isGen2() and height then
        info.height = THEME:format("HEIGHT %d FT %d IN",
          math.floor(height / 100), height % 100)
        info.weight = THEME:format("WEIGHT %.1f LB",
          (tonumber(entry.weight) or 0) / 10)
      elseif entry.heightFt then
        info.height = THEME:format("HEIGHT %d FT %d IN",
          tonumber(entry.heightFt) or 0, tonumber(entry.heightIn) or 0)
        info.weight = THEME:format("WEIGHT %.1f LB",
          (tonumber(entry.weight) or 0) / 10)
      end
      local source = compat.isGen2()
        and table.concat({ entry.text or "", entry.text2 or "" }, " ")
        or (data.text and data.text[entry.text]) or entry.text or ""
      source = tostring(source):gsub("<[^>]+>", " ")
        :gsub("[\r\n@]+", " "):gsub("%s+", " ")
      local current = ""
      for word in fit(source, 10000):gmatch("%S+") do
        local joined = current == "" and word or current .. " " .. word
        if #glyphList(joined) <= 24 then
          current = joined
        elseif current == "" then
          info.description[#info.description + 1] = fit(word, 24)
        else
          info.description[#info.description + 1] = fit(current, 24)
          current = word
        end
      end
      if current ~= "" then
        info.description[#info.description + 1] = fit(current, 24)
      end
    end
    local attackers = {}
    for _, row in ipairs((data.type_chart or {}).matchups or {}) do
      attackers[row.attacker] = true
    end
    for typeId in pairs(attackers) do
      local multiplier = compat.typeEffectiveness(
        typeId, info.types, data.type_chart)
      local list = multiplier and multiplier > 10 and info.weak
        or multiplier and multiplier < 10 and info.resist
      if list then
        list[#list + 1] = { type = typeId, multiplier = multiplier }
      end
    end
    table.sort(info.weak, function(a, b)
      if a.multiplier ~= b.multiplier then return a.multiplier > b.multiplier end
      return tostring(a.type) < tostring(b.type)
    end)
    table.sort(info.resist, function(a, b)
      if a.multiplier ~= b.multiplier then return a.multiplier < b.multiplier end
      return tostring(a.type) < tostring(b.type)
    end)
    return info
  end

  function displayRuntime.pokedexMapIds()
    local data, found = game.data or {}, {}
    local function add(source)
      for id in pairs(source or {}) do found[id] = true end
    end
    if compat.isGen2() then
      local encounters = data.gen2Encounters or {}
      add(encounters.grass)
      add(encounters.water)
      add(encounters.trees)
      add(encounters.rocks)
      for id, def in pairs(data.gen2Maps or {}) do
        if def.fishGroup then found[id] = true end
      end
    else
      add(data.encounters)
      add(data.field and data.field.superRod)
    end
    local ids = {}
    for id in pairs(found) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
    return ids
  end

  function displayRuntime.pokedexData()
    local state = displayRuntime.pokedex
    if state.data then return state.data end
    local save, data = game.save or {}, game.data or {}
    local seen = save.pokedex and save.pokedex.seen or {}
    local caught = compat.caughtDex(save)
    local habitats = {}
    for _, row in ipairs(guideData(displayRuntime.pokedexMapIds()).rows) do
      habitats[row.species] = row
    end
    local entries, caughtCount = {}, 0
    for species, def in pairs(data.pokemon or {}) do
      if tonumber(def.dex) then
        local owned = caught[species] == true
        entries[#entries + 1] = {
          species = species, dex = tonumber(def.dex),
          name = def.name or tostring(species):gsub("_", " "),
          seen = owned or seen[species] == true, caught = owned,
          habitat = habitats[species],
        }
        if owned then caughtCount = caughtCount + 1 end
      end
    end
    table.sort(entries, function(a, b)
      if a.dex ~= b.dex then return a.dex < b.dex end
      return tostring(a.species) < tostring(b.species)
    end)
    local bySpecies = {}
    for index, entry in ipairs(entries) do
      entry.index, bySpecies[entry.species] = index, entry
    end
    state.data = { entries = entries, bySpecies = bySpecies,
      caught = caughtCount, total = #entries }
    return state.data
  end

  function displayRuntime.pokedexStat(stats, ...)
    for index = 1, select("#", ...) do
      local value = tonumber(stats and stats[select(index, ...)])
      if value then return value end
    end
    return 0
  end

  function displayRuntime.pokedexMoveRows(def)
    local rows = {}
    local function add(moveId, method)
      local move = game.data.moves and game.data.moves[moveId] or {}
      local typeId = move.type or "NORMAL"
      rows[#rows + 1] = {
        id = moveId, name = move.name or tostring(moveId):gsub("_", " "),
        method = method, type = typeId, type2 = typeId,
        typeLabel = THEME:typeName(typeId, mod.content),
        type2Label = THEME:typeName(typeId, mod.content),
      }
    end
    for _, moveId in ipairs(def.level1Moves or {}) do add(moveId, "START") end
    for _, row in ipairs(def.learnset or def.levelMoves or {}) do
      add(row.move or row.id, THEME:format("L%d", row.level or 1))
    end
    for _, moveId in ipairs(def.tmhm or {}) do add(moveId, "TM/HM") end
    return rows
  end

  function displayRuntime.pokedexModel()
    local state, dex = displayRuntime.pokedex, displayRuntime.pokedexData()
    local pages = math.max(1, math.ceil(dex.total / 9))
    state.page = math.max(1, math.min(state.page or 1, pages))
    if not state.selected and dex.entries[1] then
      state.selected = dex.entries[1].species
    end
    local selected = dex.bySpecies[state.selected] or dex.entries[1]
    if selected then state.selected = selected.species end
    local function drawPokemon(row, x, y, size)
      local tint
      if not row.caught then
        tint = row.seen and THEME.hgss.colors.silver
          or THEME.hgss.colors.shadow
      end
      return drawSprite(row.species, "front", x, y, size, size,
        tint, nil, true)
    end
    if state.view == "index" then
      local entries, first = {}, (state.page - 1) * 9 + 1
      for index = first, math.min(dex.total, first + 8) do
        entries[#entries + 1] = dex.entries[index]
      end
      return { view = "index", region = compat.isGen2()
          and "NATIONAL DEX" or "KANTO DEX",
        caught = dex.caught, total = dex.total,
        page = state.page, pages = pages, entries = entries,
        drawPokemon = drawPokemon }
    end
    if not selected then
      return { view = "index", region = "POKEDEX", caught = 0,
        total = 0, page = 1, pages = 1, entries = {} }
    end
    local def = game.data.pokemon[selected.species] or {}
    local info = compat.enemyInfo({ species = selected.species,
      name = selected.name }, game.data, game.save)
    info.index, info.type = selected.index, info.types[1] or "NORMAL"
    info.type2 = info.types[2] or info.type
    info.typeLabel = THEME:typeName(info.type, mod.content)
    info.type2Label = THEME:typeName(info.type2, mod.content)
    info.kind = info.kind or "UNKNOWN"
    info.height = tostring(info.height or "--"):gsub("^HEIGHT%s+", "")
    info.weight = tostring(info.weight or "--"):gsub("^WEIGHT%s+", "")
    if #info.description == 0 then
      info.description = { "NO RESEARCH DATA AVAILABLE." }
    end
    local base, stats, bst = def.baseStats or {}, {}, 0
    local definitions = compat.isGen2() and {
      { "HP", "hp" }, { "ATK", "attack" }, { "DEF", "defense" },
      { "SP.ATK", "specialAttack", "spAttack", "special" },
      { "SP.DEF", "specialDefense", "spDefense", "special" },
      { "SPEED", "speed" },
    } or {
      { "HP", "hp" }, { "ATK", "attack" }, { "DEF", "defense" },
      { "SPECIAL", "special" }, { "SPEED", "speed" },
    }
    for _, keys in ipairs(definitions) do
      local value = displayRuntime.pokedexStat(base, unpack(keys, 2))
      stats[#stats + 1], bst = { label = keys[1], value = value }, bst + value
    end
    local moves = displayRuntime.pokedexMoveRows(def)
    local habitat = selected.habitat and selected.habitat.appearances or {}
    local areas = {}
    for _, appearance in ipairs(habitat) do areas[appearance.mapId] = true end
    local areaCount = 0
    for _ in pairs(areas) do areaCount = areaCount + 1 end
    local common = {
      pokemon = info, drawPokemon = drawPokemon,
      statsText = THEME:format("BST %d", bst),
      habitatText = THEME:format("%d AREAS", areaCount),
      movesText = THEME:format("%d MOVES", #moves),
    }
    if state.view == "profile" then
      common.view = "profile"
      return common
    elseif state.view == "stats" then
      common.view, common.stats = "stats", stats
      common.summary = THEME:format("BST %d", bst)
      common.catchText = THEME:format("CATCH %d",
        tonumber(def.catchRate) or 0)
      common.expText = THEME:format("XP %d", tonumber(def.baseExp) or 0)
      return common
    elseif state.view == "moves" then
      local movePages = math.max(1, math.ceil(#moves / 4))
      state.movePage = math.max(1, math.min(state.movePage or 1, movePages))
      common.view, common.page, common.pages = "moves", state.movePage, movePages
      common.rows = {}
      local first = (state.movePage - 1) * 4 + 1
      for index = first, math.min(#moves, first + 3) do
        common.rows[#common.rows + 1] = moves[index]
      end
      return common
    end
    local habitatPages = math.max(1, math.ceil(#habitat / 3))
    state.habitatPage = math.max(1,
      math.min(state.habitatPage or 1, habitatPages))
    common.view, common.page, common.pages = "habitat",
      state.habitatPage, habitatPages
    common.summary = areaCount > 0
      and THEME:format("%d AREAS", areaCount) or "NO WILD AREA"
    common.status, common.current = "NOT HERE", false
    common.rows = {}
    local currentTime = compat.timePeriod(game.world) or "DAY"
    local first = (state.habitatPage - 1) * 3 + 1
    for index = first, math.min(#habitat, first + 2) do
      local appearance = habitat[index]
      local current = appearance.mapId == mapId
        and (not appearance.time or appearance.time == currentTime)
      local area = areaName(appearance.mapId)
      local section = appearance.section
      if section and section ~= "" and section ~= "OTHER AREA"
          and not area:upper():find(section:upper(), 1, true) then
        area = area .. " - " .. section
      end
      common.rows[#common.rows + 1] = {
        area = area, current = current,
        time = appearance.time or "ANY TIME", method = appearance.method,
        chance = math.floor((tonumber(appearance.chance) or 0) + 0.5),
        levels = appearance.minLevel == appearance.maxLevel
          and THEME:format("L%d", appearance.minLevel or 0)
          or THEME:format("L%d-%d", appearance.minLevel or 0,
            appearance.maxLevel or 0),
      }
      if current then common.current, common.status = true, "HERE NOW" end
    end
    return common
  end

  function displayRuntime.selectPokedexSpecies(index)
    local entries = displayRuntime.pokedexData().entries
    if #entries == 0 then return false end
    index = (index - 1) % #entries + 1
    displayRuntime.pokedex.selected = entries[index].species
    displayRuntime.pokedex.view = "profile"
    displayRuntime.pokedex.habitatPage = 1
    displayRuntime.pokedex.movePage = 1
    dirty = true
    return true
  end

  function displayRuntime.cyclePokedex(direction)
    local state, model = displayRuntime.pokedex, displayRuntime.pokedexModel()
    if state.view == "index" then
      state.page = (state.page - 1 + direction) % model.pages + 1
    elseif state.view == "profile" or state.view == "stats" then
      local view = state.view
      local selected = displayRuntime.pokedexData().bySpecies[state.selected]
      displayRuntime.selectPokedexSpecies((selected and selected.index or 1)
        + direction)
      state.view = view
    elseif state.view == "moves" then
      state.movePage = (state.movePage - 1 + direction) % model.pages + 1
    else
      state.habitatPage = (state.habitatPage - 1 + direction)
        % model.pages + 1
    end
    dirty = true
  end

  displayRuntime.bagPockets = {
    { id = "ITEM", label = "ITEMS" },
    { id = "BALL", label = "POKE BALLS" },
    { id = "KEY_ITEM", label = "KEY ITEMS" },
    { id = "TM_HM", label = "TM/HM" },
  }

  function displayRuntime.bagWords(source, limit, maximum)
    source = tostring(source or ""):gsub("<NEXT>", " ")
      :gsub("<[^>]+>", " "):gsub("\n", " "):gsub("%s+", " ")
      :gsub("^%s+", ""):gsub("%s+$", "")
    local lines, current = {}, ""
    for word in source:gmatch("%S+") do
      local joined = current == "" and word or current .. " " .. word
      if #joined <= limit then
        current = joined
      else
        if current ~= "" then lines[#lines + 1] = fit(current, limit) end
        current = word
        if #lines >= maximum then break end
      end
    end
    if #lines < maximum and current ~= "" then
      lines[#lines + 1] = fit(current, limit)
    end
    return lines
  end

  function displayRuntime.bagItemKind(id, def)
    local upper = tostring(id or ""):upper()
    if def and def.ball then return "ball" end
    if upper:match("^TM_?%d") or upper:match("^HM_?%d")
        or def and (def.machine or def.teaches) then return "machine" end
    if upper:find("HEAL", 1, true) or upper == "ANTIDOTE"
        or upper == "AWAKENING" then return "status" end
    if def and def.needsTarget then return "medicine" end
    if upper:find("POTION", 1, true) or upper:find("ETHER", 1, true)
        or upper:find("ELIX", 1, true) or upper == "REVIVE"
        or upper == "MAX_REVIVE" then return "medicine" end
    return "item"
  end

  function displayRuntime.bagDescription(id, def)
    local moveId = def and (def.teaches
      or def.machine and def.machine.move)
    local move = moveId and game.data.moves and game.data.moves[moveId]
    local source = move and move.description or def and def.description
    if source and source ~= "" then
      return displayRuntime.bagWords(source, 31, 3)
    end
    if moveId then
      return displayRuntime.bagWords(THEME:format(
        "TEACHES %s TO A COMPATIBLE POKEMON.",
        move and move.name or tostring(moveId):gsub("_", " ")), 31, 3)
    end
    if def and def.ball then
      return displayRuntime.bagWords(
        THEME:translate("A BALL USED TO CATCH WILD POKEMON."), 31, 3)
    end
    if def and def.needsTarget then
      return displayRuntime.bagWords(
        THEME:translate("USE IT ON A POKEMON IN YOUR PARTY."), 31, 3)
    end
    if def and def.keyItem then
      return displayRuntime.bagWords(
        THEME:translate("AN IMPORTANT ITEM FOR YOUR ADVENTURE."), 31, 3)
    end
    return displayRuntime.bagWords(
      THEME:translate("AN ITEM WITH A SPECIAL FIELD EFFECT."), 31, 3)
  end

  function displayRuntime.bagModel()
    local state, save, data = displayRuntime.bag, game.save or {}, game.data or {}
    local gen2 = compat.isGen2()
    local pockets = gen2 and displayRuntime.bagPockets
      or { displayRuntime.bagPockets[1] }
    state.pocket = math.max(1, math.min(state.pocket or 1, #pockets))
    local pocket = pockets[state.pocket]
    local ok, Bag = pcall(require, "src.inventory.Bag")
    local order = ok and Bag.order and Bag.order(save) or {}
    local entries = {}
    for _, id in ipairs(order) do
      local count = tonumber((save.inventory or {})[id]) or 0
      local def = data.items and data.items[id] or {}
      local itemPocket = def.pocket or "ITEM"
      if count > 0 and (not gen2 or itemPocket == pocket.id) then
        local moveId = def.teaches or def.machine and def.machine.move
        local move = moveId and data.moves and data.moves[moveId]
        entries[#entries + 1] = {
          id = id, count = count, label = def.name
            or tostring(id):gsub("_", " "),
          icon = displayRuntime.bagItemKind(id, def),
          detail = move and move.name,
          lines = displayRuntime.bagDescription(id, def),
        }
      end
    end
    if gen2 then
      table.sort(entries, function(a, b)
        local ad = data.items and data.items[a.id] or {}
        local bd = data.items and data.items[b.id] or {}
        local ai, bi = tonumber(ad.index) or math.huge,
          tonumber(bd.index) or math.huge
        if ai ~= bi then return ai < bi end
        return tostring(a.id) < tostring(b.id)
      end)
    end
    local pages = math.max(1, math.ceil(#entries / 6))
    state.page = math.max(1, math.min(state.page or 1, pages))
    local visible, first = {}, (state.page - 1) * 6 + 1
    for index = first, math.min(#entries, first + 5) do
      visible[#visible + 1] = entries[index]
    end
    local detail
    if state.detail then
      for _, entry in ipairs(entries) do
        if entry.id == state.detail then detail = entry break end
      end
      if not detail then state.detail = nil end
    end
    return {
      pocket = THEME:translate(pocket.label), pocketIndex = state.pocket,
      pockets = #pockets, page = state.page, pages = pages,
      entries = visible, total = #entries, detail = detail,
      message = state.message, canUse = screenState() == "active" and not battle,
      money = tonumber(save.money) or 0,
    }
  end

  function displayRuntime.cycleBagPage(direction)
    local model = displayRuntime.bagModel()
    displayRuntime.bag.page = (model.page - 1 + direction) % model.pages + 1
    displayRuntime.bag.message, dirty = nil, true
  end

  function displayRuntime.cycleBagPocket(direction)
    local model = displayRuntime.bagModel()
    if model.pockets <= 1 then return displayRuntime.cycleBagPage(direction) end
    displayRuntime.bag.pocket = (model.pocketIndex - 1 + direction)
      % model.pockets + 1
    displayRuntime.bag.page, displayRuntime.bag.detail = 1, nil
    displayRuntime.bag.message, dirty = nil, true
  end

  function displayRuntime.bagMessage(lines)
    local out = {}
    for _, line in ipairs(lines or {}) do
      out[#out + 1] = tostring(line):gsub("{PLAYER}",
        game.save and game.save.player and game.save.player.name or "PLAYER")
    end
    return out
  end

  function displayRuntime.useBagItem(itemId)
    if screenState() ~= "active" or battle or not itemId then return false end
    local state = displayRuntime.bag
    state.message = nil
    if compat.isGen2() then
      local def = game.data and game.data.items and game.data.items[itemId]
      state.pending = { itemId = itemId, moveId = def and def.teaches }
      local ok, PackMenu = pcall(require, "src.ui.gen2.PackMenu")
      if not ok or type(PackMenu) ~= "table" or type(PackMenu.new) ~= "function" then
        state.pending = nil
        return false
      end
      local backend = PackMenu.new(game, {
        pocket = displayRuntime.bagPockets[state.pocket].id,
        onChoose = function(id)
          if type(game.useFieldItem) == "function" then game:useFieldItem(id) end
        end,
      })
      for index, row in ipairs(backend.rows or {}) do
        if row.id == itemId then backend.index = index break end
      end
      local row = backend.rows and backend.rows[backend.index]
      if not row or row.id ~= itemId then state.pending = nil; return false end
      local used, err = pcall(backend.useSelected, backend)
      if not used then
        state.pending = nil
        mod.log:warn("HGSS bag item %s rejected: %s", tostring(itemId), tostring(err))
        return false
      end
      if backend.message then
        state.message = displayRuntime.bagMessage(backend.message)
      end
      state.detail = state.message and itemId or nil
      dirty = true
      return true
    end

    local ok, BagMenu = pcall(require, "src.ui.BagMenu")
    local menuOk, Menu = pcall(require, "src.ui.Menu")
    if not ok or not menuOk or type(BagMenu) ~= "table"
        or type(BagMenu.new) ~= "function" then return false end
    local backend = BagMenu.new(game)
    local item
    for _, row in ipairs(backend.items or {}) do
      if row.value == itemId then item = row break end
    end
    if not item or type(backend.onChoose) ~= "function" then return false end
    local stack, before = game.stack, game.stack:top()
    local count = #(stack.states or {})
    local opened, err = pcall(backend.onChoose, item, backend)
    local useMenu = stack:top()
    if not opened or #(stack.states or {}) ~= count + 1
        or getmetatable(useMenu) ~= Menu
        or type(useMenu.items) ~= "table"
        or not useMenu.items[1]
        or type(useMenu.items[1].onSelect) ~= "function" then
      if stack:top() ~= before and #(stack.states or {}) == count + 1 then
        stack:pop()
      end
      mod.log:warn("HGSS bag could not open original USE action for %s: %s",
        tostring(itemId), tostring(err or "unexpected menu"))
      return false
    end
    local action = useMenu.items[1].onSelect
    stack:pop()
    local used, useErr = pcall(action)
    if not used then
      mod.log:warn("HGSS bag item %s failed: %s",
        tostring(itemId), tostring(useErr))
      return false
    end
    state.detail, dirty = nil, true
    return true
  end

  function displayRuntime.drawBag()
    local model = displayRuntime.bagModel()
    header(THEME:translate("BAG"), true)
    G.push()
    G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    THEME.hgss:bag(model)
    G.pop()
  end

  function displayRuntime.drawPokedex()
    local model = displayRuntime.pokedexModel()
    local title = model.view == "index" and "POKEDEX"
      or model.view == "profile" and THEME:format("NO.%03d",
        tonumber(model.pokemon and model.pokemon.dex) or 0)
      or model.view == "habitat" and THEME:format("HABITAT %d/%d",
        model.page or 1, model.pages or 1)
      or model.view == "moves" and THEME:format("MOVES %d/%d",
        model.page or 1, model.pages or 1)
      or "STATS"
    header(title, true, model.view ~= "index")
    G.push()
    G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    THEME.hgss:pokedex(model)
    G.pop()
  end

  assert(compat.typeEffectiveness("FIRE", { "GRASS", "BUG" }, { matchups = {
    { attacker = "FIRE", defender = "GRASS", multiplier = 20 },
    { attacker = "FIRE", defender = "BUG", multiplier = 20 },
  } }) == 40, "type effectiveness preview")

  function compat.moveInfoLines(move, def, ruleset)
    if compat.isGen2() and type(def.description) == "string"
        and #def.description > 0 then
      local source = def.description:gsub("<NEXT>", " "):gsub("\n", " ")
        :gsub("%s+", " ")
      local lines, current = {}, ""
      for word in source:gmatch("%S+") do
        local joined = current == "" and word or current .. " " .. word
        if #joined <= 21 then
          current = joined
        elseif current == "" then
          lines[#lines + 1] = fit(word, 21)
          if #lines == 2 then break end
        else
          lines[#lines + 1] = fit(current, 21)
          current = word
          if #lines == 2 then break end
        end
      end
      if #lines < 2 and current ~= "" then
        lines[#lines + 1] = fit(current, 21)
      end
      if #lines > 0 then return lines end
    end
    return THEME:moveDescription(move, def, ruleset)
  end

  function compat.moveInfoEntry(move)
    if type(move) ~= "table" then move = { id = move } end
    if not move.id then return nil end
    local entry = {}
    for key, value in pairs(move) do entry[key] = value end
    local def = game and game.data and game.data.moves
      and game.data.moves[entry.id] or {}
    if entry.pp == nil then entry.pp = def.pp or 0 end
    if entry.maxPp == nil then entry.maxPp = def.pp or entry.pp end
    return entry
  end

  function hgssRuntime.summaryMove(summary, index)
    local view = compat.summary.view(summary, game)
    local source = view and view.mon and view.mon.moves
      and view.mon.moves[index]
    local entry = compat.moveInfoEntry(source)
    if entry and view.moves and view.moves[index] then
      entry.maxPp = view.moves[index].maxPp or entry.maxPp
    end
    return entry, view
  end

  local function drawMoveInfo(move)
    if THEME.style == "hgss" and battle and battle.prompt == "moves" then
      local mon = hgssRuntime.battleMon()
      local playerTeam, enemyTeam = hgssRuntime.battleTeams()
      local progress = hgssRuntime.progress("battle_move_info")
      local closing = hgssRuntime.progress("battle_move_info_close")
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      if progress or closing then
        THEME.hgss:battleMoveInfoTransition(mon, playerTeam, enemyTeam,
          closing and 1 - closing or progress)
      else
        local selected = mon.moves[mon.moveIndex] or mon.moves[1] or {}
        THEME.hgss:battleMoveInfo(selected,
          THEME.hgss:moveHasStab(mon, selected), playerTeam, enemyTeam)
      end
      G.pop()
      return
    end
    local def = game and game.data and game.data.moves
      and game.data.moves[move.id] or {}
    local raw = battleState()
    local lines = compat.moveInfoLines(move, def, raw and raw.ruleset)
    local power = move.displayPower
    if power == nil then power = move.power or def.power end
    if power == 0 then power = nil end
    local accuracy = move.hitChance
    if accuracy == nil then accuracy = move.accuracy or def.accuracy end
    local summary = screenById("summary")
    if THEME.style == "hgss" and battle and summary
        and compat.summary.supports(summary, game) then
      local _, view = hgssRuntime.summaryMove(summary,
        summary.moveIndex or 1)
      local moveType = move.type or def.type
      local enemy = battle.enemy
      local enemyDef = enemy and game.data.pokemon
        and game.data.pokemon[enemy.species]
      local enemyTypes = enemy and enemy.types
        or enemyDef and enemyDef.types
      local info = {
        name = THEME:moveName(move, game and game.data),
        type = moveType,
        typeLabel = THEME:typeName(moveType, mod.content),
        ppLabel = THEME:translate("PP"),
        ppText = THEME:format("%d/%d", move.pp or 0, move.maxPp or 0),
        power = power or 0,
        powerLabel = THEME:translate("PWR"),
        powerText = power and tostring(power) or "--",
        accuracyLabel = THEME:translate("ACC"),
        accuracyText = accuracy and tostring(accuracy) or "--",
        stabLabel = "STAB",
        matchupLabel = THEME:translate("MATCHUP"),
        effectiveness = assist("type_hints") and compat.typeEffectiveness(
          moveType, enemyTypes, game.data.type_chart) or nil,
        descriptionLines = lines,
      }
      header(THEME:translate("MOVES"), true)
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:battleMoveInfoBody(info,
        THEME.hgss:moveHasStab({ types = view and view.types }, info))
      G.pop()
      return
    end
    if THEME.style == "hgss" then
      local learn = displayRuntime.moveLearnScreen()
      local owner = learn and learn.mon
        or raw and screenContract(raw, "forget")
      local ownerDef = owner and game.data.pokemon[owner.species] or {}
      local ownerTypes = owner and (owner.types or ownerDef.types) or {}
      local enemy = battle and battle.enemy
      local enemyDef = enemy and game.data.pokemon[enemy.species] or {}
      local enemyTypes = enemy and (enemy.types or enemyDef.types)
      local info = hgssRuntime.moveView(move, enemyTypes)
      header(info.name, true)
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:battleMoveInfoBody(info,
        THEME.hgss:moveHasStab({ types = ownerTypes }, info))
      G.pop()
      return
    end
    header(fit(THEME:moveName(move, game and game.data), 12), true)
    box("fill", 12, 25, 136, 112, MID)
    outline(12, 25, 136, 112, INK)
    centered(THEME:typeName(def.type or move.type, mod.content), 33, INK, 2)
    text("POWER", 20, 54, DARK)
    text(tostring(power or "--"), 20, 65, INK)
    text("HIT", 69, 54, DARK)
    text(chanceLabel(accuracy), 61, 65, INK)
    text("PP", 121, 54, DARK)
    text(("%d/%d"):format(move.pp or 0, move.maxPp or 0), 108, 65, INK)
    if assist("type_hints") then
      text("MATCHUP", 25, 83, DARK)
      text(effectLabel(move.effectiveness), 112, 83, INK)
    end
    box("fill", 19, 95, 122, 1, DARK)
    if lines[2] then
      centered(lines[1], 103, INK)
      centered(lines[2], 116, INK)
    else
      centered(lines[1], 110, INK)
    end
  end

  function compat.battlePartyTitle(menu, cancel)
    if cancel then return "CANCEL" end
    if menu and (menu.itemUse == true
        or menu.prompt == "Use on which <PK><MN>?") then
      return "USE ITEM ON"
    end
    return "PARTY"
  end
  assert(compat.battlePartyTitle({ itemUse = true }) == "USE ITEM ON"
      and compat.battlePartyTitle({ prompt = "Use on which <PK><MN>?" })
        == "USE ITEM ON"
      and compat.battlePartyTitle({ battle = true }) == "PARTY",
    "battle party title follows the native selection context")

  local function drawBattleParty(menu)
    if menu.submenu then
      if THEME.style == "hgss" then
        local mon = (battle.party or {})[menu.index]
        if not mon then return end
        local actions, submenu = hgssRuntime.partySubmenuActions(menu)
        local selected = menu.subIndex or (submenu and submenu.index)
          or (actions[1] and actions[1].index)
        header(THEME:translate("PARTY"), true, false, -1)
        G.push()
        G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        THEME.hgss:partyBackdrop()
        partyCard(mon, 64, THEME.hgss:partyActionHeroY(#actions), true, false,
          false)
        for row, action in ipairs(actions) do
          local x, y, w, h = THEME.hgss:partyActionRow(row, #actions)
          local label = action.item.label or tostring(action.index)
          THEME.hgss:actionRow(x, y, w, h, label,
            row == 1 and "switch" or "stats", 0,
            selected == action.index)
        end
        G.pop()
        return
      end
      header(fit(((battle.party or {})[menu.index] or {}).name or "POKEMON", 12), true)
      local submenu = type(menu.submenu) == "table" and menu.submenu or nil
      local items = menu.subItems or (submenu and submenu.items) or {}
      local index = menu.subIndex or (submenu and submenu.index)
      for i, item in ipairs(items) do
        button(14, 29 + (i - 1) * 35, 132, 30,
               item.label or tostring(i), index == i)
      end
      return
    end
    local cancel
    if menu.isCancel then
      local ok
      ok, cancel = pcall(menu.isCancel, menu)
      if not ok then return end
    end
    local selected = not cancel and menu.index or nil
    local title = THEME:translate(compat.battlePartyTitle(menu, cancel))
    if THEME.style == "hgss" then
      local list = battle.party or {}
      local progress = hgssRuntime.progress("battle_party")
      if progress then
        local mon = hgssRuntime.battleMon()
        local playerTeam, enemyTeam = hgssRuntime.battleTeams()
        local clock, period = hgssRuntime.clock()
        G.push()
        G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        THEME.hgss:battlePartyTransition(mon, hgssRuntime.battlePortrait,
          playerTeam, enemyTeam, function(slot, x, y, focused, details)
            partyCard(list[slot], x, y,
              selected and selected == slot or not selected and focused,
              details)
          end, progress, title, clock, period)
        G.pop()
        return
      end
    end
    drawParty(battle.party or {}, title, true, nil, selected)
  end

  function compat.battleBagMenu(menu)
    if not screenContract(menu, "bag") then return nil end
    -- Gen 3 UI 1.4 keeps its categorized cursor beside the native BagMenu.
    local rows = menu and menu.__gen3uiBagViewRows
    local viewIndex = menu and menu.__gen3uiBagViewIndex
    if menu and menu.screenId == "BagMenu" and type(rows) == "table"
        and type(viewIndex) == "number" then
      local nativeIndex = menu.index
      local previous = compat.bagViews[menu]
      local mode = previous and previous.mode or "view"
      if previous then
        local nativeMoved = nativeIndex ~= previous.native
        local viewMoved = viewIndex ~= previous.view
        local nativeRow = (menu.items or {})[nativeIndex]
        local viewRow = rows[viewIndex]
        local aligned = nativeRow and viewRow
          and nativeRow.value == viewRow.value
        if viewMoved and not nativeMoved then
          mode = "view"
        elseif nativeMoved and not viewMoved and not aligned then
          mode = "native"
        end
      end
      compat.bagViews[menu] = {
        native = nativeIndex, view = viewIndex, mode = mode,
      }
      if mode == "native" then return menu end

      local items = {}
      for i, row in ipairs(rows) do
        items[i] = { value = row.value, label = row.label, right = row.right }
      end
      local pocketIndex = menu.__gen3uiBagPocketIndex or 1
      return {
        screenId = menu.screenId,
        items = items,
        index = viewIndex,
        title = compat.bagLabels[pocketIndex] or "ITEMS",
        pocketIndex = pocketIndex,
      }
    end
    if not (menu and menu.screenId == "Gen2PackMenu") then return menu end
    local items = {}
    for i, row in ipairs(menu.rows or {}) do
      items[i] = {
        value = row.id,
        label = row.name or row.id,
        right = row.teaches or (row.showCount and ("x" .. tostring(row.count)))
          or "",
      }
    end
    items[#items + 1] = { label = "CANCEL", cancel = true }
    local ok, pocket = pcall(menu.pocket, menu)
    if not ok or type(pocket) ~= "table" then return nil end
    return {
      screenId = menu.screenId,
      items = items,
      index = menu.index or 1,
      title = pocket.label or "ITEMS",
      pocketIndex = menu.pocketIndex,
    }
  end

  function compat.selectBattleBagItem(menu, index)
    menu.index = index
    local rows = menu.__gen3uiBagViewRows
    local row = type(rows) == "table" and rows[index] or nil
    if not row then return end
    menu.__gen3uiBagViewIndex = index
    for nativeIndex, nativeRow in ipairs(menu.items or {}) do
      if nativeRow and nativeRow.value == row.value then
        menu.index = nativeIndex
        return
      end
    end
  end

  function compat.useBattleBagItemDirectly(menu, queue)
    if not (menu and menu.screenId == "Gen2PackMenu" and menu.battle
        and not menu.submenu and type(queue) == "table"
        and type(menu.hasSubmenu) == "function"
        and type(menu.submenuRows) == "function"
        and type(menu.useSelected) == "function") then return false end
    local row = menu.rows and menu.rows[menu.index]
    if not row then return false end
    local ok, hasSubmenu = pcall(menu.hasSubmenu, menu)
    if not ok or not hasSubmenu then return false end
    local rowsOk, rows = pcall(menu.submenuRows, menu, row.id)
    if not rowsOk or type(rows) ~= "table" or rows[1] ~= "use" then
      return false
    end
    for i, key in ipairs(queue) do
      if key == "a" then
        local used = pcall(menu.useSelected, menu)
        if not used then return false end
        table.remove(queue, i)
        return true
      end
    end
    return false
  end

  local function drawBattleItems(menu)
    if THEME.style == "hgss" then
      local view = hgssRuntime.bagView(menu)
      local mon = hgssRuntime.battleMon()
      local playerTeam, enemyTeam = hgssRuntime.battleTeams()
      hgssRuntime.lastBag = view
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      local progress = hgssRuntime.progress("battle_bag")
      if progress then
        THEME.hgss:battleBagTransition(mon, hgssRuntime.battlePortrait,
          playerTeam, enemyTeam, view, progress)
      else
        THEME.hgss:battleBag(view, playerTeam, enemyTeam)
      end
      G.pop()
      return
    end
    header(menu.title or "ITEMS", true, categorizedBag(menu))
    local odds = {}
    if assist("catch_odds")
        and (caughtWild(battle.kind, true) or battle.wild == true) then
      for _, item in ipairs(battle.items or {}) do
        odds[item.id] = item.catchChance
      end
    end
    local first, count = choiceWindow(menu.items or {}, menu.index)
    for row = 1, count do
      local index, item = first + row - 1, menu.items[first + row - 1]
      local right = item.right or ""
      if odds[item.value] ~= nil then
        right = right .. " " .. chanceLabel(odds[item.value])
      end
      button(8, 25 + (row - 1) * 28, 144, 25,
             THEME:format("%s %s", item.label or tostring(index), right),
             menu.index == index)
    end
  end

  local function drawPpItemMoves(menu)
    header(THEME.style == "hgss" and "RESTORE PP" or "CHOOSE MOVE", true)
    if THEME.style == "hgss" then
      local first, count = choiceWindow(menu.items or {}, menu.index)
      local entries = {}
      for row = 1, count do
        local index, item = first + row - 1, menu.items[first + row - 1]
        entries[row] = {
          kind = "move", label = item.label or tostring(index),
          right = THEME:format("PP %s", item.right or "--"),
          selected = menu.index == index,
        }
      end
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:pcList({ summary = THEME:translate("CHOOSE MOVE"),
        entries = entries })
      G.pop()
      return
    end
    for i, item in ipairs(menu.items or {}) do
      button(8, 25 + (i - 1) * 28, 144, 25,
             THEME:format("%s  PP %s", item.label or tostring(i),
                          item.right or "--"), menu.index == i)
    end
  end

  local function drawBattleSummary(summary)
    if THEME.style == "hgss" then
      local mon, view = hgssRuntime.summaryView(summary)
      if not mon then return end
      local pageLabels = { "STATS", "MOVES", "TRAINER" }
      header(THEME:format("%s %d/%d",
        THEME:translate(pageLabels[view.page] or "STATS"),
        view.page, view.pages), true, true, view.page == 1 and -1 or 0)
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      local open = hgssRuntime.progress("summary_open")
      local pageProgress = hgssRuntime.progress("summary_page")
      if open and view.page == 1 then
        THEME.hgss:summaryTransition(mon, hgssRuntime.summaryPortrait, open,
          hgssRuntime.animation.actionCount or 2,
          THEME:translate("STATS"), THEME:translate("SWAP"))
      elseif pageProgress and hgssRuntime.animation.from == 1
          and hgssRuntime.animation.to == 2 then
        THEME.hgss:summaryMovesTransition(mon, hgssRuntime.summaryPortrait,
          pageProgress)
      elseif pageProgress and hgssRuntime.animation.from == 2
          and hgssRuntime.animation.to == 1 then
        THEME.hgss:summaryMovesTransition(mon, hgssRuntime.summaryPortrait,
          1 - pageProgress)
      elseif pageProgress and hgssRuntime.animation.from == 2
          and hgssRuntime.animation.to == 3 then
        THEME.hgss:summaryMemoTransition(mon, hgssRuntime.summaryPortrait,
          pageProgress)
      elseif pageProgress and hgssRuntime.animation.from == 3
          and hgssRuntime.animation.to == 2 then
        THEME.hgss:summaryMemoTransition(mon, hgssRuntime.summaryPortrait,
          1 - pageProgress)
      elseif view.page == 1 then
        THEME.hgss:summaryPage(mon, hgssRuntime.summaryPortrait)
      elseif view.page == 2 then
        THEME.hgss:summaryMoves(mon, hgssRuntime.summaryPortrait)
      else
        THEME.hgss:summaryMemo(mon, hgssRuntime.summaryPortrait)
      end
      G.pop()
      return
    end
    local view = compat.summary.view(summary, game)
    local mon, def = view.mon, view.def
    local page, level = view.page, view.level
    header(THEME:format("STATS %d/%d", page, view.pages), true)
    if not view.gen2 and page == 1 then
      local stats = view.stats
      local function typeName(index)
        local id = view.types[index]
        return id and THEME:typeName(id, mod.content) or "--"
      end
      drawSprite(mon.species, "front", 4, 23, 43, 43,
                 nil, mon.source or mon)
      text(fit(view.name, 17), 51, 24, INK)
      text(THEME:format("NO.%03d LV.%d", view.dex, level),
           51, 36, DARK)
      text(THEME:format("HP %d/%d", view.hp, view.maxHp),
           51, 48, INK)
      hpBar(51, 59, 105, view.hp, view.maxHp)
      text(THEME:format("STATUS %s",
        THEME:statusName(view.status, mod.content)
          or THEME:translate("OK")), 51, 65, DARK)
      box("fill", 4, 76, 152, 1, DARK)
      text(THEME:format("ATK %d", stats.attack or 0), 5, 81, INK)
      text(THEME:format("DEF %d", stats.defense or 0), 5, 92, INK)
      text(THEME:format("SPD %d", stats.speed or 0), 5, 103, INK)
      text(THEME:format("SPC %d", stats.special or 0), 5, 114, INK)
      text(THEME:format("TYPE1 %s", typeName(1)), 77, 81, DARK)
      text(THEME:format("TYPE2 %s", typeName(2)), 77, 92, DARK)
      text(THEME:format("OT %s",
        fit(view.ot, 10)), 77, 103, DARK)
      text(THEME:format("ID %05d", view.otId),
           77, 114, DARK)
    elseif not view.gen2 then
      text(fit(view.name, 17), 5, 25, INK)
      text(THEME:format("LV.%d", level), 116, 25, DARK)
      text(THEME:format("EXP %d", view.experience), 5, 39, DARK)
      if level < 100 then
        local growth = def.growthRate
          and mod.content.growth_rates:get(def.growthRate)
          or mod.content.growth_rates:get("MEDIUM_FAST")
        local nextExp = math.max(0,
          (growth and growth.expForLevel
            and growth.expForLevel(level + 1) or 0) - view.experience)
        text(THEME:format("NEXT L.%d %d", level + 1, nextExp), 5, 51, DARK)
      else
        text("NEXT MAX", 5, 51, DARK)
      end
      box("fill", 4, 61, 152, 1, DARK)
      for i = 1, 4 do
        local move = view.moves[i]
        local y = 66 + (i - 1) * 14
        text(fit(move.name, 14), 6, y, INK)
        text(move.pp and THEME:format("PP %d/%d", move.pp, move.maxPp)
          or "PP --", 103, y, DARK)
      end
    elseif page == 1 then
      local status = THEME:statusName(view.status, mod.content)
        or THEME:translate("OK")
      if (tonumber(mon.pokerus) or 0) % 16 > 0 then status = "PKRS" end
      drawSprite(mon.species, "front", 4, 23, 43, 43,
                 nil, mon.source or mon)
      text(fit(view.name, 17), 51, 24, INK)
      text(THEME:format("NO.%03d LV.%d", view.dex, level), 51, 36, DARK)
      text(THEME:format("HP %d/%d", view.hp, view.maxHp), 51, 48, INK)
      hpBar(51, 59, 105, view.hp, view.maxHp)
      text(THEME:format("STATUS %s", status), 51, 65, DARK)
      box("fill", 4, 76, 152, 1, DARK)
      text(THEME:format("TYPE1 %s",
        THEME:typeName(view.types[1], mod.content)), 5, 82, DARK)
      text(THEME:format("TYPE2 %s", view.types[2]
        and THEME:typeName(view.types[2], mod.content) or "--"), 5, 94, DARK)
      text(THEME:format("EXP %d", view.experience), 77, 82, DARK)
      if level < 100 then
        text(THEME:format("NEXT L.%d", level + 1), 77, 94, DARK)
        text(tostring(view.nextExp or 0), 77, 105, DARK)
      else
        text("NEXT MAX", 77, 94, DARK)
      end
    elseif page == 2 then
      text(fit(view.name, 17), 5, 25, INK)
      text(THEME:format("LV.%d", level), 116, 25, DARK)
      text(THEME:format("ITEM %s", fit(view.item or "---", 18)), 5, 39, DARK)
      box("fill", 4, 51, 152, 1, DARK)
      for i = 1, 4 do
        local move = view.moves[i]
        local y = 57 + (i - 1) * 16
        text(fit(move.name, 14), 6, y, INK)
        text(move.pp and THEME:format("PP %d/%d", move.pp, move.maxPp)
          or "PP --", 103, y, DARK)
      end
    else
      local stats = view.stats
      text(fit(view.name, 17), 5, 25, INK)
      text(THEME:format("LV.%d", level), 116, 25, DARK)
      text(THEME:format("OT %s", fit(view.ot, 11)), 5, 39, DARK)
      text(THEME:format("ID %05d", view.otId), 96, 39, DARK)
      box("fill", 4, 51, 152, 1, DARK)
      local rows = { { "ATK", stats.attack }, { "DEF", stats.defense },
        { "SP.ATK", stats.specialAttack },
        { "SP.DEF", stats.specialDefense }, { "SPEED", stats.speed } }
      for i, row in ipairs(rows) do
        local y = 57 + (i - 1) * 13
        text(THEME:translate(row[1]), 16, y, DARK)
        text(("%3d"):format(row[2] or 0), 120, y, INK)
      end
    end
    button(103, 125, 53, 15, page < view.pages and "NEXT" or "CLOSE", false)
  end

  local function drawTopSummaryControls(_, generic)
    header(generic and "MENU ON TOP" or "STATS ON TOP", true)
    if THEME.style == "hgss" then
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:pcTopOnly({ kind = generic and "items" or "pokemon" })
      G.pop()
      return
    end
    centered("FOLLOW TOP SCREEN", 58, DARK)
    if generic then
      centered("INPUT STAYS ON TOP", 78, INK)
      return
    end
    button(14, 94, 132, 34, "BACK", false)
  end

  local function drawPcRoot(kind, root)
    local boxes = game.save.boxes or {}
    local current = game.save.currentBox or 1
    local items = root.items or root.entries or {}
    header(root.screenId == "Gen2CenterPcMenu" and "PC"
      or kind == "items" and "ITEM PC"
      or THEME:format("PC BOX %d %d/20", current, #(boxes[current] or {})))
    local count = #items
    if THEME.style == "hgss" then
      local entries = {}
      for index, item in ipairs(items) do
        entries[index] = {
          label = THEME:translate(item.label or tostring(index)),
          selected = root.index == index,
        }
      end
      local title = root.screenId == "Gen2CenterPcMenu" and "PC"
        or kind == "items" and "ITEM PC"
        or THEME:format("PC BOX %d", current)
      local status = kind == "items"
        and THEME:translate("READY")
        or THEME:format("BOX %d  %d/20", current, #(boxes[current] or {}))
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:pcRoot({ kind = kind, title = THEME:translate(title),
        status = THEME:translate(status), entries = entries })
      G.pop()
      return
    end
    if count == 0 then
      centered("NOTHING HERE", 61, INK)
      return
    end
    local rowHeight = math.floor(116 / count)
    for i, item in ipairs(items) do
      button(8, 23 + (i - 1) * rowHeight, 144, rowHeight - 3,
             item.label or tostring(i), root.index == i)
    end
  end

  local function pcMonCard(mon, x, y, selected)
    local pressed = THEME.style == "hgss"
      and THEME.hgss:beginPress(x, y, 144, 22, true, 1, 4 / 3)
    box("fill", x, y, 144, 22, selected and DARK or MID)
    outline(x, y, 144, 22, INK)
    if mon then
      local def = game.data.pokemon[mon.species] or {}
      if compat.partyEgg(mon) then
        compat.drawPokemonIcon(mon, x + 2, y + 1, 20)
      else
        drawSprite(mon.species, "front", x + 2, y + 1, 20, 20,
                   nil, mon.source or mon)
      end
      text(fit(mon.nickname or def.name or mon.species, 13), x + 26, y + 4,
           selected and PAPER or INK)
      text(THEME:format("LV.%d", mon.level or 0), x + 111, y + 4,
           selected and PAPER or DARK)
    end
    if pressed then THEME.hgss:endPress(pressed) end
  end

  local function drawPcBoxList(list)
    local boxes = game.save.boxes or {}
    local kind = pcListKind(list)
    local gen2 = kind and kind:find("^gen2_box_") ~= nil
    local current = gen2 and (list.boxIndex or game.save.currentBox or 1)
      or (game.save.currentBox or 1)
    local deposit = kind == "pc_box_deposit" or kind == "gen2_box_deposit"
    local mons = (deposit or (gen2 and current == 0))
      and (game.save.party or {}) or (boxes[current] or {})
    local inserting = gen2 and list.phase == "insert"
    local total = gen2 and (inserting and math.max(1, #mons) or #mons + 1)
      or #(list.items or {})
    local first, count = pageWindow(list.index, total)
    local action = ({ pc_box_withdraw = "WITHDRAW",
      pc_box_deposit = "DEPOSIT", pc_box_release = "RELEASE",
      gen2_box_withdraw = "WITHDRAW", gen2_box_deposit = "DEPOSIT",
      gen2_box_move = "MOVE" })[kind]
      or "POKEMON"
    header(action, true)
    local pages = math.max(1, math.ceil(total / 4))
    local page = math.floor((math.max(1, list.index) - 1) / 4) + 1
    local summary = (deposit or (gen2 and current == 0))
      and THEME:format("PARTY %d/6  %d/%d", #mons, page, pages)
      or THEME:format("BOX %d  %d/20  %d/%d",
                      current, #mons, page, pages)
    if THEME.style == "hgss" then
      local entries = {}
      for slot = 1, count do
        local index = first + slot - 1
        local item = list.items and list.items[index]
        if gen2 and not inserting and index > #mons then
          entries[slot] = { label = THEME:translate("BACK"), back = true,
            selected = list.index == index }
        else
          local mon = mons[item and item.value or index]
          local def = mon and game.data.pokemon[mon.species] or {}
          entries[slot] = {
            mon = mon,
            label = mon and (mon.nickname or def.name or mon.species)
              or THEME:translate("POKEMON"),
            right = mon and THEME:format("LV.%d", mon.level or 0) or "--",
            selected = list.index == index,
          }
        end
      end
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:pcList({ summary = THEME:translate(summary),
        entries = entries,
        drawPokemon = function(mon, x, y, size)
          if compat.partyEgg(mon) then
            compat.drawPokemonIcon(mon, x, y, size)
          else
            drawSprite(mon.species, "front", x, y, size, size,
              nil, mon.source or mon)
          end
        end,
      })
      G.pop()
      return
    end
    centered(summary, 22, DARK)
    if total == 0 then
      centered("NOTHING HERE", 61, INK)
      button(34, 101, 92, 28, "BACK", false)
      return
    end
    for slot = 1, count do
      local index = first + slot - 1
      local item = list.items and list.items[index]
      if gen2 and index > #mons then
        button(8, 38 + (slot - 1) * 24, 144, 22, "BACK",
               list.index == index)
      else
        pcMonCard(mons[item and item.value or index],
          8, 38 + (slot - 1) * 24, list.index == index)
      end
    end
  end

  local function drawPcBoxChange(list)
    local boxes = game.save.boxes or {}
    local gen2 = list.screenId == "Gen2PcMenu"
    local items = list.items or {}
    local selected = gen2 and list.pickIndex or list.index
    local total = gen2 and 14 or #items
    header(THEME.style == "hgss" and "BOX CHANGE" or "CHANGE BOX", true)
    local first, count = pageWindow(selected, total)
    if THEME.style == "hgss" then
      local entries = {}
      for row = 1, count do
        local index, item = first + row - 1, items[first + row - 1]
        entries[row] = {
          kind = "box",
          label = THEME:translate(item and item.label
            or ((game.save.boxNames or {})[index] or ("BOX" .. index))),
          right = item and item.right or (#(boxes[index] or {}) .. "/20"),
          selected = selected == index,
        }
      end
      local summary = THEME:format("PAGE %d/%d",
        math.floor((selected - 1) / 4) + 1,
        math.max(1, math.ceil(total / 4)))
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:pcList({ summary = THEME:translate(summary),
        entries = entries })
      G.pop()
      return
    end
    for row = 1, count do
      local index, item = first + row - 1, items[first + row - 1]
      local label = item and item.label
        or ((game.save.boxNames or {})[index] or ("BOX" .. index))
      button(8, 25 + (row - 1) * 25, 144, 22,
             THEME:format("%s %s", label,
                          item and item.right or (#(boxes[index] or {}) .. "/20")),
             selected == index)
    end
    centered(THEME:format("PAGE %d/%d",
      math.floor((selected - 1) / 4) + 1,
      math.max(1, math.ceil(total / 4))), 132, DARK)
  end

  local function drawPcItemList(list)
    local titles = { pc_item_withdraw = "WITHDRAW",
      pc_item_deposit = "DEPOSIT", pc_item_toss = "TOSS",
      gen2_item_withdraw = "WITHDRAW", gen2_item_toss = "TOSS" }
    local kind = pcListKind(list)
    local gen2 = kind and kind:find("^gen2_item_") ~= nil
    local items = gen2 and (list.rows or {}) or (list.items or {})
    local selected = gen2 and list.listIndex or list.index
    local total = #items + (gen2 and 1 or 0)
    header(titles[kind] or "ITEMS", true)
    if THEME.style == "hgss" then
      local first, count = pageWindow(selected, total)
      local entries = {}
      for row = 1, count do
        local index, item = first + row - 1, items[first + row - 1]
        entries[row] = item and {
          kind = "item", icon = "item",
          label = THEME:translate(item.label or item.name or tostring(index)),
          right = item.right or (gen2 and ("x" .. (item.count or 0)) or ""),
          selected = selected == index,
        } or { label = THEME:translate("BACK"), back = true,
          selected = selected == index }
      end
      local summary = THEME:format("PAGE %d/%d",
        math.floor((selected - 1) / 4) + 1,
        math.max(1, math.ceil(total / 4)))
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:pcList({ summary = THEME:translate(summary),
        entries = entries })
      G.pop()
      return
    end
    if total == 0 then
      centered("NOTHING HERE", 56, INK)
      button(34, 94, 92, 30, "BACK", false)
      return
    end
    local first, count = pageWindow(selected, total)
    for row = 1, count do
      local index, item = first + row - 1, items[first + row - 1]
      button(8, 25 + (row - 1) * 25, 144, 22,
             item and THEME:format("%s %s",
               item.label or item.name or tostring(index),
               item.right or (gen2 and ("x" .. (item.count or 0)) or ""))
               or "BACK",
             selected == index)
    end
    centered(THEME:format("PAGE %d/%d",
      math.floor((selected - 1) / 4) + 1,
      math.max(1, math.ceil(total / 4))), 132, DARK)
  end

  local function drawPcQuantity(quantity, list)
    local item = list and ((list.items and list.items[list.index])
      or (list.rows and list.rows[list.listIndex]))
    header("QUANTITY", true)
    if THEME.style == "hgss" then
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:pcQuantity({ label = THEME:translate(
        item and (item.label or item.name) or "ITEM"),
        qty = quantity.qty or 1, icon = "item" })
      G.pop()
      return
    end
    centered(fit(item and item.label or "ITEM", 20), 28, INK)
    button(8, 51, 43, 38, "-", false)
    box("fill", 55, 51, 50, 38, PAPER)
    outline(55, 51, 50, 38, INK)
    centered(tostring(quantity.qty or 1), 63, INK, 2)
    button(109, 51, 43, 38, "+", false)
    button(8, 104, 90, 29, "CONFIRM", false)
    button(102, 104, 50, 29, "CANCEL", false)
  end

  function displayRuntime.gen2BoxSubmenu(state)
    if not (state and state.screenId == "Gen2BoxMenu"
        and state.phase == "submenu"
        and type(state.submenuIndex) == "number") then return nil end
    if state.mode == "move" then return { "MOVE", "STATS", "CANCEL" } end
    if state.mode == "deposit" then
      return { "DEPOSIT", "STATS", "RELEASE", "CANCEL" }
    end
    return { "WITHDRAW", "STATS", "RELEASE", "CANCEL" }
  end

  function displayRuntime.drawPcBoxSubmenu(state)
    local rows = displayRuntime.gen2BoxSubmenu(state)
    header("POKEMON", true)
    local entries = {}
    for index, label in ipairs(rows) do
      entries[index] = { label = THEME:translate(label),
        selected = state.submenuIndex == index }
    end
    G.push()
    G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    THEME.hgss:pcList({ summary = THEME:translate("CHOOSE ACTION"),
      entries = entries })
    G.pop()
  end

  function displayRuntime.drawPcDeposit(root)
    local menu = compat.battleBagMenu(root.pack)
    if not menu then return drawTopSummaryControls(nil, true) end
    local first, count = choiceWindow(menu.items or {}, menu.index)
    local entries = {}
    for row = 1, count do
      local index, item = first + row - 1, menu.items[first + row - 1]
      entries[row] = {
        kind = item.cancel and nil or "item",
        icon = item.cancel and nil or "item",
        label = item.label or tostring(index), right = item.right,
        back = item.cancel, selected = menu.index == index,
      }
    end
    header("DEPOSIT ITEM", true)
    G.push()
    G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    THEME.hgss:pcList({ summary = THEME:translate(menu.title or "ITEMS"),
      entries = entries })
    G.pop()
  end

  function displayRuntime.pcNotice(kind, root, top)
    local source = top and top.screenId == "Gen2BoxMenu" and top.message
      or root and root.message
    if not source then return nil end
    local lines
    if type(source) == "table" and type(source.pages) == "table" then
      lines = source.pages[source.page or 1]
    elseif type(source) == "table" then
      lines = source
    else
      lines = THEME:messageLines({ tostring(source) }, 24, 4)
    end
    if type(lines) ~= "table" then lines = { tostring(lines or "...") } end
    return { kind = kind, lines = displayRuntime.bagMessage(lines) }
  end

  local function drawPc(kind, root, top)
    local list = pcList()
    local activeList = list and top == list and list or nil
    local activeKind = pcListKind(activeList)
    local nativeQuantity = root.screenId == "Gen2ItemPcMenu"
      and root.qtyState or nil
    local quantity = nativeQuantity or (kind == "items" and list and top
      and type(top.qty) == "number" and type(top.max) == "number"
      and type(top.onDone) == "function" and top)
    local notice = displayRuntime.pcNotice(kind, root, top)
    if notice then
      header(kind == "items" and "ITEM PC" or "PC", true)
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:pcNotice(notice)
      G.pop()
    elseif quantity then
      drawPcQuantity(quantity, nativeQuantity and root or list)
    elseif displayRuntime.gen2BoxSubmenu(top) then
      displayRuntime.drawPcBoxSubmenu(top)
    elseif root.screenId == "Gen2ItemPcMenu"
        and root.phase == "deposit" and root.pack then
      displayRuntime.drawPcDeposit(root)
    elseif activeList and (activeKind == "pc_box_change"
        or activeKind == "gen2_box_change") then
      drawPcBoxChange(activeList)
    elseif activeList and activeKind and activeKind:find("_box_") then
      drawPcBoxList(activeList)
    elseif activeList and activeKind and activeKind:find("_item_") then
      drawPcItemList(activeList)
    elseif root.screenId == "Gen2PcMenu"
        and (root.message or root.savePhase) then
      drawTopSummaryControls(nil, true)
    elseif root.screenId == "Gen2ItemPcMenu"
        and (root.phase ~= "menu" or root.message
          or root.qtyState or root.confirm) then
      drawTopSummaryControls(nil, true)
    elseif top ~= root then
      drawTopSummaryControls(nil, true)
    else
      drawPcRoot(kind, root)
    end
  end

  local function drawBattleLocked(title)
    if THEME.style == "hgss" then
      local playerTeam, enemyTeam = hgssRuntime.battleTeams()
      local lines = THEME:messageLines(battle.message or {}, 24, 4)
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:battleMessage(lines,
        battle.prompt == "advance" or nil,
        playerTeam, enemyTeam, title and THEME:translate(title) or nil,
        love.timer.getTime())
      G.pop()
      return
    end
    header(title or (battle.kind == "wild" and "Wild battle"
      or battle.kind == "trainer" and "Trainer battle" or "BATTLE"))
    if hideUpperBattleUI()
        and battle.message and #battle.message > 0 then
      box("fill", 6, 30, 148, 106, DARK)
      outline(6, 30, 148, 106, PAPER)
      local lines = THEME:messageLines(battle.message, 22, 4)
      local y = 65 - math.floor((#lines - 1) * 7.5)
      for _, line in ipairs(lines) do
        text(line, 14, y, PAPER)
        y = y + 15
      end
      if battle.prompt == "advance" then
        box("fill", 14, 96, 132, 1, MID)
        displayRuntime.drawContinueArrow(75, 105)
      end
      return
    end
    if battle.prompt == "advance" then
      displayRuntime.drawContinueArrow(75, 65)
    end
  end

  local function drawFullBattleHpBar(x, y, w, hp, maxHp)
    local ratio = math.max(0,
      math.min(1, (hp or 0) / math.max(1, maxHp or 1)))
    box("fill", x, y, w, 7, DARK)
    box("fill", x + 1, y + 1, w - 2, 5, PAPER)
    box("fill", x + 1, y + 1, math.floor((w - 2) * ratio), 5,
        ratio <= 0.2 and THEME.red or ratio <= 0.5 and DARK or INK)
  end

  local function drawFullBattleStatus(mon, y, player)
    if not mon then return end
    local owned = mod.options:get("caught_icon") ~= false
      and not player and caughtWild(battle.kind,
      compat.caughtDex(game.save)[mon.species])
    box("fill", 4, y, 152, 40, MID)
    outline(4, y, 152, 40, DARK)
    local name = fit(mon.name or mon.species or "-", owned and 10 or 11)
    text(name, 9, y + 5, INK)
    if owned then drawCaughtBall(11 + #name * 8, y + 5) end
    local status = (mon.hp or 0) <= 0 and "FNT"
      or THEME:statusName(mon.status, mod.content)
    if status then text(fit(status, 3), 100, y + 5, DARK) end
    text(fit(THEME:format("L%d", mon.level or 0), 4), 124, y + 5, DARK)
    text("HP", 9, y + 24, DARK)
    drawFullBattleHpBar(28, y + 24, 68, mon.hp, mon.maxHp)
    if player then
      text(fit(("%d/%d"):format(mon.hp or 0, mon.maxHp or 0), 7),
           100, y + 24, INK)
    end
  end

  local function drawFullBattleActions(labels)
    for i, label in ipairs(labels) do
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
      button(3 + col * 78, 94 + row * 24, 76, 22,
             label, battle.menuIndex == i)
    end
  end

  local function drawFullBattleStatuses()
    drawFullBattleStatus(battle.enemy, 3, false)
    drawFullBattleStatus(battle.player, 48, true)
  end

  local function drawFullBattleRoot()
    drawFullBattleStatuses()
    drawFullBattleActions({ "FIGHT", "PKMN", "ITEM", "RUN" })
  end

  local function drawFullSafari()
    drawFullBattleStatus(battle.enemy, 3, false)
    centered(THEME:format("SAFARI BALLS %d", battle.safariBalls or 0),
             64, DARK)
    drawFullBattleActions({ "BALL", "BAIT", "ROCK", "RUN" })
  end

  displayRuntime.drawForgetMoves = function()
    header("FORGET MOVE", true)
    if THEME.style == "hgss" then
      local raw = battleState()
      local mon = raw and screenContract(raw, "forget")
      local pending = raw and raw.pendingLearn
      local newMove = hgssRuntime.moveView(pending and pending.move)
      if battle.learningMove then newMove.name = battle.learningMove end
      local moves = {}
      for slot = 1, 4 do
        local source = mon and mon.moves and mon.moves[slot]
        moves[slot] = hgssRuntime.moveView(source)
        if not source and battle.forgetMoves and battle.forgetMoves[slot] then
          moves[slot].name = battle.forgetMoves[slot]
        end
      end
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:moveLearnList({ newMove = newMove, moves = moves,
        index = battle.forgetIndex or 1, details = assist("move_details") })
      G.pop()
      return
    end
    text(fit(THEME:format("NEW %s", battle.learningMove or "MOVE"), 18),
         8, 25, DARK)
    if assist("move_details") then displayRuntime.moveInfoBadge(139, 24, false) end
    for slot, name in ipairs(battle.forgetMoves or {}) do
      local selected = battle.forgetIndex == slot
      local y = 38 + (slot - 1) * 25
      button(8, y, 144, 22, "", selected)
      text(fit(name or "-", 17), 14, y + 8,
           selected and (THEME.style ~= "classic" and THEME.white or PAPER)
             or INK)
      if assist("move_details") then
        displayRuntime.moveInfoBadge(139, y + 2, selected)
      end
    end
  end

  displayRuntime.enemyInfo = function()
    local raw = battleState()
    local source = raw and (raw.enemy or (raw.battle and raw.battle.enemy))
    local mon = source and (source.mon or source)
    return compat.enemyInfo(battle and battle.enemy, game.data, game.save, mon)
  end

  local function drawBattle()
    if currentBattleUIMode() == "info" then
      local info = displayRuntime.enemyInfo()
      if THEME.style == "hgss" then
        local firstType = info.types[1]
        local secondType = info.types[2] or firstType
        info.type, info.type2 = firstType, secondType
        info.typeLabel = THEME:typeName(firstType, mod.content)
        info.type2Label = THEME:typeName(secondType, mod.content)
        info.levelText = info.level and THEME:format("L%d", info.level)
          or "L--"
        local model = {
          pokemon = info,
          drawPokemon = function(_, x, y, size)
            drawSprite(info.species, "front", x, y, size, size,
              nil, battle and battle.enemy)
          end,
        }
        local title = battleInfoDetail == "profile" and "POKEDEX"
          or battleInfoDetail == "dvs" and "ENEMY DVS"
          or battleInfoDetail == "weak" and "WEAK"
          or battleInfoDetail == "resist" and "RESIST"
          or "ENEMY INFO"
        header(title, battleInfoDetail ~= nil)
        G.push()
        G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        if battleInfoDetail == "profile" then
          THEME.hgss:enemyInfoProfile(model)
        elseif battleInfoDetail == "dvs" then
          local dvs = info.dvs
          model.rows = dvs and {
            { label = "HP", value = dvs.hp },
            { label = "ATTACK", value = dvs.attack },
            { label = "DEFENSE", value = dvs.defense },
            { label = "SPEED", value = dvs.speed },
            { label = "SPECIAL", value = dvs.special },
          } or {}
          THEME.hgss:enemyInfoDvs(model)
        elseif battleInfoDetail == "weak" or battleInfoDetail == "resist" then
          model.kind, model.rows = battleInfoDetail, {}
          for _, row in ipairs(info[battleInfoDetail] or {}) do
            model.rows[#model.rows + 1] = {
              type = row.type,
              typeLabel = THEME:typeName(row.type, mod.content),
              effectLabel = effectLabel(row.multiplier),
            }
          end
          THEME.hgss:enemyInfoMatchup(model)
        else
          THEME.hgss:enemyInfoOverview(model)
        end
        G.pop()
        return
      end
      if battleInfoDetail == "profile" then
        header("POKEDEX", true)
        centered(fit(info.name, 24), 25, INK)
        centered(fit(THEME:format("NO.%03d %s", info.dex or 0,
          info.kind or "--"), 24), 37, DARK)
        centered(fit(info.height or "--", 24), 50, INK)
        centered(fit(info.weight or "--", 24), 61, INK)
        box("fill", 4, 74, 152, 1, DARK)
        if #info.description == 0 then
          centered("NO DETAILS AVAILABLE", 103, DARK)
        else
          for i = 1, math.min(8, #info.description) do
            centered(info.description[i], 80 + (i - 1) * 8, INK)
          end
        end
        return
      elseif battleInfoDetail == "dvs" then
        header(THEME:translate("ENEMY DVS"), true)
        centered(fit(info.name, 24), 25, INK)
        box("fill", 4, 34, 152, 1, DARK)
        if not info.dvs then
          centered("NO DETAILS AVAILABLE", 80, DARK)
        else
          local rows = {
            { "HP", info.dvs.hp }, { "ATTACK", info.dvs.attack },
            { "DEFENSE", info.dvs.defense }, { "SPEED", info.dvs.speed },
            { "SPECIAL", info.dvs.special },
          }
          for i, row in ipairs(rows) do
            local y = 42 + (i - 1) * 17
            text(fit(THEME:translate(row[1]), 15), 18, y, INK)
            text(tostring(row[2]), 130, y, DARK)
          end
          centered(THEME:translate("RANGE 0-15"), 130, DARK)
        end
        return
      elseif battleInfoDetail == "weak" or battleInfoDetail == "resist" then
        local rows = info[battleInfoDetail]
        header(battleInfoDetail == "weak" and "WEAK" or "RESIST", true)
        centered("BASE MATCHUP", 23, DARK)
        box("fill", 4, 33, 152, 1, DARK)
        if #rows == 0 then
          centered("--", 76, INK)
        else
          for i, row in ipairs(rows) do
            local y = 37 + (i - 1) * 8
            text(fit(THEME:typeName(row.type, mod.content), 18), 8, y, INK)
            text(effectLabel(row.multiplier), 128, y, DARK)
          end
        end
        return
      end
      header(THEME:translate("ENEMY INFO"))
      drawSprite(info.species, "front", 4, 22, 44, 40, nil, battle.enemy)
      text(fit(info.name, 15) .. " >", 52, 24, INK)
      local identity = info.dex and info.level
        and THEME:format("NO.%03d LV.%d", info.dex, info.level)
        or info.level and THEME:format("LV.%d", info.level) or ""
      text(fit(identity, 17), 52, 35, DARK)
      local typeNames = {}
      for _, typeId in ipairs(info.types) do
        typeNames[#typeNames + 1] = THEME:typeName(typeId, mod.content)
      end
      text(fit(THEME:format("TYPE %s",
        #typeNames > 0 and table.concat(typeNames, "/") or "--"), 17),
        52, 46, DARK)
      text("CAUGHT", 52, 57, DARK)
      text(info.caught and "YES" or "NO", info.dvs and 96 or 112, 57, INK)
      if info.dvs then text("DVS >", 123, 57, DARK) end
      box("fill", 4, 78, 152, 1, DARK)
      centered("BASE MATCHUP", 81, DARK)
      box("fill", 79, 90, 1, 52, MID)
      text(fit("WEAK", 7), 5, 91, DARK)
      text(tostring(#info.weak), 57, 91, DARK)
      text(">", 71, 91, DARK)
      text(fit("RESIST", 7), 84, 91, DARK)
      text(tostring(#info.resist), 136, 91, DARK)
      text(">", 150, 91, DARK)
      for column, rows in ipairs({ info.weak, info.resist }) do
        local x = column == 1 and 5 or 84
        if #rows == 0 then text("--", x, 102, INK) end
        for i = 1, math.min(#rows, 4) do
          local row = rows[i]
          local label = fit(THEME:typeName(row.type, mod.content), 6)
            .. " " .. effectLabel(row.multiplier)
          text(fit(label, 11), x, 102 + (i - 1) * 10, INK)
        end
      end
      return
    end
    local top = game and game.stack and game.stack:top()
    local raw = battleState()
    local party = screenContract(top, "party")
    local bag = compat.battleBagMenu(top)
    local ppMoves = screenContract(top, "pp")
    local summary = compat.isScreen(top, "summary") and top
    if ppMoves then
      drawPpItemMoves(ppMoves)
    elseif party then
      drawBattleParty(party)
    elseif bag then
      drawBattleItems(bag)
    elseif summary and moveInfo then
      drawMoveInfo(moveInfo)
    elseif summary then
      if compat.summary.supports(summary, game) then drawBattleSummary(summary)
      else drawTopSummaryControls(summary) end
    elseif top and top ~= raw and not top.isTextBox then
      drawTopSummaryControls(nil, true)
    elseif battle.prompt == "safari" then
      if THEME.style == "hgss" then drawSafari()
      elseif fullBottomBattleUI() then drawFullSafari()
      else drawSafari() end
    elseif battle.prompt == "mimic" then
      drawMimic()
    elseif moveInfo then
      drawMoveInfo(moveInfo)
    elseif battle.prompt == "forget" then
      displayRuntime.drawForgetMoves()
    elseif battle.prompt == "moves" then
      drawMoves()
    elseif battle.prompt ~= "menu" then
      if THEME.style ~= "hgss" and fullBottomBattleUI()
          and raw and (raw.draining or raw.hpAnim) then
        drawFullBattleStatuses()
      else
        drawBattleLocked()
      end
    else
      if THEME.style == "hgss" then drawBattleRoot()
      elseif fullBottomBattleUI() then drawFullBattleRoot()
      else drawBattleRoot() end
    end
  end

  local function moveDef(id)
    return game and game.data and game.data.moves and game.data.moves[id]
  end

  displayRuntime.learningMoveInfo = function()
    local learn = displayRuntime.moveLearnScreen()
    if learn then
      local moves = learn.mon.moves or {}
      if learn.selecting and learn.index <= #moves then
        return compat.moveInfoEntry(moves[learn.index])
      end
      return compat.moveInfoEntry(learn.newMoveId)
    end

    local raw = battleState()
    local pending = raw and raw.pendingLearn
    if not pending then return nil end
    if raw.phase == "choose-forget" then
      local party = raw.battle and raw.battle.party
      local mon = party and party[pending.index]
      local moves = mon and mon.moves or {}
      return compat.moveInfoEntry(moves[raw.forgetIndex or 1])
    end
    return compat.moveInfoEntry(pending.move)
  end

  local function drawLearnMove(learn, top, choice, choiceField)
    local newDef = moveDef(learn.newMoveId) or {}
    local newName = newDef.name or learn.newMoveId or "MOVE"
    if battle and top and top.isTextBox and hideUpperBattleUI() then
      drawBattleLocked("NEW MOVE")
      return
    end
    if THEME.style == "hgss" then
      local newMove = hgssRuntime.moveView(learn.newMoveId)
      if learn.selecting and top == (learn.native or learn) then
        local moves = {}
        for slot = 1, 4 do
          moves[slot] = hgssRuntime.moveView(learn.mon.moves[slot])
        end
        header("FORGET MOVE", true)
        G.push()
        G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        THEME.hgss:moveLearnList({ newMove = newMove, moves = moves,
          index = learn.index, details = assist("move_details") })
        G.pop()
        return
      end

      local monDef = game.data.pokemon[learn.mon.species] or {}
      local types = learn.mon.types or monDef.types or {}
      local mon = {
        source = learn.mon, species = learn.mon.species,
        name = learn.mon.nickname or monDef.name or learn.mon.species,
        levelText = THEME:format("L%d", learn.mon.level or 0),
        type = types[1], type2 = types[2] or types[1],
        typeLabel = THEME:typeName(types[1], mod.content),
        type2Label = THEME:typeName(types[2] or types[1], mod.content),
      }
      header("NEW MOVE")
      G.push()
      G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:moveLearnPrompt({ mon = mon, newMove = newMove,
        details = assist("move_details"),
        choices = choice and { "YES", "NO" } or nil,
        choice = choice and compat.choiceIndex(choice, choiceField) or nil,
        drawPokemon = function(_, x, y, size)
          drawSprite(learn.mon.species, "front", x, y, size, size,
            nil, learn.mon.source or learn.mon)
        end,
      })
      G.pop()
      return
    end
    if learn.selecting and top == (learn.native or learn) then
      header("FORGET MOVE")
      text(fit(newName, 13), 5, 25, INK)
      text(fit(THEME:typeName(newDef.type, mod.content), 7), 95, 25, DARK)
      if assist("move_details") then
        displayRuntime.moveInfoBadge(139, 24, false)
      end
      for i = 1, 4 do
        local mv = learn.mon.moves[i]
        local def = mv and moveDef(mv.id) or {}
        local selected = learn.index == i
        local y = 38 + (i - 1) * 25
        button(8, y, 144, 22, "", selected)
        text(fit(def.name or (mv and mv.id) or "-", 17), 14, y + 8,
             selected and (THEME.style ~= "classic" and THEME.white or PAPER)
               or INK)
        if mv and assist("move_details") then
          displayRuntime.moveInfoBadge(139, y + 2, selected)
        end
      end
      return
    end

    header("NEW MOVE")
    drawSprite(learn.mon.species, "front", 5, 25, 42, 42,
               nil, learn.mon.source or learn.mon)
    local monDef = game.data.pokemon[learn.mon.species] or {}
    text(fit(learn.mon.nickname or monDef.name or learn.mon.species, 16),
         51, 27, DARK)
    text(fit(newName, 14), 51, 42, INK)
    if assist("move_details") then
      text(fit(THEME:typeName(newDef.type, mod.content), 9), 51, 56, DARK)
      text(THEME:format("PP %d", newDef.pp or 0), 112, 56, DARK)
      displayRuntime.moveInfoBadge(145, 41, false)
    end
    box("fill", 7, 75, 146, 1, DARK)
    centered("FOLLOW TOP SCREEN", 83, INK)
    if top and top.onChoose and (top.index == 1 or top.index == 2) then
      button(18, 106, 58, 27, "YES", top.index == 1)
      button(84, 106, 58, 27, "NO", top.index == 2)
    elseif top and top.isTextBox then
      drawDim(0.48, textPrompt(top))
    end
  end

  function displayRuntime.pressTouch(mode, choice, touch)
    if mode == "loading" or (mode == "textbox" and not choice) then
      return nil
    end
    return touch
  end
  assert(displayRuntime.pressTouch("textbox", nil, true) == nil
      and displayRuntime.pressTouch("loading", nil, true) == nil
      and displayRuntime.pressTouch("textbox", {}, true) == true
      and displayRuntime.pressTouch("active", nil, true) == true,
    "modal text and loading overlays capture HGSS press animation")

  displayRuntime.drawContents = function()
    G.setCanvas(canvas)
    G.origin()
    G.setScissor()
    G.setShader()
    G.setBlendMode("alpha")
    G.clear(PAPER[1], PAPER[2], PAPER[3], PAPER[4])
    G.setLineWidth(1)
    local highResolution = THEME.style == "hgss"
    if highResolution then
      G.push(); G.scale(THEME.hgssScale, THEME.hgssScale)
    end
    local mode, top, fade = screenState()
    local summary = compat.isScreen(top, "summary") and top or nil
    local hgssSummary = THEME.style == "hgss" and summary
      and compat.summary.supports(summary, game)
    local learnScreen = screenById("MoveLearnMenu")
      or screenById("Gen2MoveDeleter")
    local learn = displayRuntime.moveLearnScreen()
    local fieldParty, fieldPartyData, fieldPartyTitle =
      displayRuntime.fieldBagParty()
    local fieldPp = displayRuntime.fieldPpMoveScreen()
    local pcKind, pcRoot = pcSession()
    local choice, labels, choiceField = dialogueChoice()
    local namingKeys = screenContract(top, "naming")
    local naming = namingKeys and top or nil
    local unsupportedSpecial = (learnScreen and not learn and not fieldPp)
      or (compat.isScreen(top, "naming") and not naming)
    local levelStats = battle and compat.levelUpMon(top)
    if THEME.style == "hgss" then
      local pressTouch = displayRuntime.pressTouch(mode, choice, touchDown)
      THEME.hgss:setTouch(pressTouch and pressTouch.x,
        pressTouch and pressTouch.y)
      THEME.hgss:backdrop()
    end
    if moveInfo then
      drawMoveInfo(moveInfo)
    elseif learn and (not choice or learn.field) then
      drawLearnMove(learn, top, choice, choiceField)
    elseif naming then
      drawNaming(naming, namingKeys)
    elseif unsupportedSpecial then
      drawTopSummaryControls(nil, true)
    elseif levelStats then
      drawLevelUpStats(levelStats)
    elseif choice then
      drawDialogueChoice(choice, labels, battle and battle.message, choiceField)
    elseif battle then
      drawBattle()
    elseif fieldPp then
      drawPpItemMoves(fieldPp)
    elseif fieldParty then
      drawParty(fieldPartyData, fieldPartyTitle, true, nil,
        fieldParty.index, false)
    elseif hgssSummary then
      drawBattleSummary(summary)
    elseif pcKind then
      drawPc(pcKind, pcRoot, top)
    elseif fieldChoice then
      drawFieldChoice()
    elseif mode == "title" then
      drawTitle()
    elseif radarOpen then
      drawRadar()
    elseif THEME.style == "hgss" and page == "HOME" then
      displayRuntime.drawHome()
    elseif THEME.style == "hgss" and page == "STORE" then
      displayRuntime.drawStore()
    elseif THEME.style == "hgss" and page == "POKEDEX" then
      displayRuntime.drawPokedex()
    elseif THEME.style == "hgss" and page == "BAG" then
      displayRuntime.drawBag()
    elseif page == "MAP" then
      drawMap()
    elseif page == "LOCAL" then
      drawLocalMap()
    elseif page == "GUIDE" then
      if displayRuntime.guideDetail then
        displayRuntime.drawGuideDetail()
      else
        drawGuide()
      end
    elseif page == "AREA" then
      drawArea()
    elseif page == "TRAINER" then
      if trainerStepsOpen then drawStepsDetail() else drawTrainer() end
    elseif THEME.style == "hgss" and page == "STEPS" then
      drawStepsDetail()
    elseif page == "PARTY" then
      if partyActionSlot then drawPartyAction() else drawNormalParty() end
    else
      drawTools()
    end
    if not learn and not naming and not battle and not choice
        and not hgssSummary
        and not (pcKind and mode == "locked")
        and mode ~= "title" and mode ~= "active" then
      if THEME.style == "hgss" and mode == "loading" then
        G.push()
        G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        THEME.hgss:loadingOverlay("LOADING AREA", love.timer.getTime())
        G.pop()
      else
        drawDim(fade, mode == "textbox" and textPrompt(top))
        if mode == "loading" then
          box("fill", 27, 57, 106, 30, DARK)
          outline(27, 57, 106, 30, PAPER)
          centered(fit("LOADING AREA", 16), 69, PAPER)
        end
      end
    end
    if not learn and not battle and mode == "active" then
      if pendingFly then drawFlyPrompt()
      elseif pendingAction then drawActionPrompt() end
    end
    if THEME.style ~= "hgss" and THEME.style ~= "classic" then
      outline(1, 1, WIDTH - 2, HEIGHT - 2, THEME.blue)
      box("fill", 3, 1, 16, 1, THEME.red)
      box("fill", WIDTH - 19, HEIGHT - 2, 16, 1, THEME.red)
    elseif THEME.style == "classic" then
      outline(1, 1, WIDTH - 2, HEIGHT - 2, INK)
    end
    if highResolution then G.pop() end
    G.setCanvas()
  end

  local function draw()
    G.push("all")
    local ok, err = pcall(function()
      displayRuntime.prepareMotion()
      displayRuntime.drawContents()
      displayRuntime.applyMotion()
    end)
    G.pop()
    if not ok then error(err, 0) end
  end

  local function pumpDisplay()
    local shown = false
    if not canvas.requestImageData or not canvas.pollImageData then
      if dirty then
        draw()
        dirty = false
      end
      if not canvas.newImageData then return false end
      local ok, image = pcall(canvas.newImageData, canvas)
      if not ok or not image then return false end
      shown = companion.push(image, canvas:getWidth(), canvas:getHeight(),
        SECONDARY_BACKGROUND,
        displayPreference())
      displayReady = shown
      if not shown then
        dirty = true
        nextPresentAttempt = love.timer.getTime() + 0.25
      end
      return shown
    end
    if bottomOnHandheld() then
      if readbackPending and canvas:pollImageData() then
        readbackPending = false
      end
      if dirty then
        draw()
        dirty = false
      end
      return false
    end
    if readbackPending then
      local image = canvas:pollImageData()
      if image then
        shown = companion.push(image, canvas:getWidth(), canvas:getHeight(),
          SECONDARY_BACKGROUND,
          displayPreference())
        readbackPending = false
        displayReady = shown
        if not shown then
          dirty = true
          nextPresentAttempt = love.timer.getTime() + 0.25
        end
      end
    end
    if not readbackPending and dirty then
      draw()
      if canvas:requestImageData() then
        readbackPending = true
        dirty = false
      end
    end
    return shown
  end

  local function refreshBattle()
    local nextBattle = mod.battle and mod.battle:snapshot() or nil
    if nextBattle then
      local raw = battleState()
      local top = game and game.stack and game.stack:top()
      nextBattle.menuIndex = raw and raw.menuIndex
      nextBattle.moveIndex = raw and raw.moveIndex
      nextBattle.mimicIndex = raw and raw.mimicIndex
      local party = screenContract(top, "party")
      nextBattle.partyIndex = party and party.index or nil
      local submenu = party and type(party.submenu) == "table"
        and party.submenu or nil
      nextBattle.subIndex = party and party.submenu
        and (party.subIndex or (submenu and submenu.index)) or nil
      local bag = compat.battleBagMenu(top)
      nextBattle.itemIndex = bag and bag.index or nil
      nextBattle.itemPocket = bag
        and (bag.__pocketIndex or bag.pocketIndex) or nil
      nextBattle.itemTitle = bag and bag.title or nil
      nextBattle.summaryPage = compat.isScreen(top, "summary")
        and top.page or nil
      prepareBattleSnapshot(nil, nextBattle, raw, game.data,
        bottomOwnsBattleUI(hideUpperBattleUI(), active, hasDisplay(),
          displayReady, raw, nextBattle))
      if battleChoice(top) and not nextBattle.message
          and raw and type(raw.visibleText) == "function" then
        local ok, visible = pcall(raw.visibleText, raw)
        if ok and type(visible) == "table" then
          nextBattle.message = {}
          for i, line in ipairs(visible) do
            nextBattle.message[i] = tostring(line)
          end
        end
      end
      for _, side in ipairs({ "player", "enemy" }) do
        local source = raw and (raw[side] or (raw.battle and raw.battle[side]))
        local copy = nextBattle[side]
        if source and copy then
          local mon = source.mon or source
          local shown = raw.shownHp and raw.shownHp[side]
          copy.hp = math.max(0, math.floor(source.shownHP or shown
            or mon.hp or copy.hp or 0))
          copy.status = source.shownStatus or copy.status
        end
      end
      if compat.isGen2() and nextBattle.enemy then
        local enemy = game.data.pokemon
          and game.data.pokemon[nextBattle.enemy.species]
        for _, move in ipairs(nextBattle.moves or {}) do
          if move.effectiveness == nil then
            move.effectiveness = compat.typeEffectiveness(move.type,
              enemy and enemy.types, game.data.type_chart)
          end
        end
      end
    end
    local changed = (not battle) ~= (not nextBattle)
      or (battle and nextBattle and battle.revision ~= nextBattle.revision)
      or (battle and nextBattle and prepareBattleSnapshot(battle, nextBattle))
      or (battle and nextBattle and (
        (battle.player and battle.player.hp) ~= (nextBattle.player and nextBattle.player.hp)
        or (battle.enemy and battle.enemy.hp) ~= (nextBattle.enemy and nextBattle.enemy.hp)))
    if THEME.style == "hgss" and battle and nextBattle then
      local oldParty, newParty = battle.partyIndex ~= nil,
        nextBattle.partyIndex ~= nil
      local oldBag, newBag = battle.itemIndex ~= nil,
        nextBattle.itemIndex ~= nil
      if battle.prompt ~= "moves" and nextBattle.prompt == "moves" then
        if not (hgssRuntime.animation
            and hgssRuntime.animation.kind == "battle_moves") then
          hgssRuntime.beginAnimation("battle_moves")
        end
      elseif battle.prompt == "moves" and nextBattle.prompt == "menu" then
        if not (hgssRuntime.animation
            and hgssRuntime.animation.kind == "battle_moves_close") then
          hgssRuntime.beginAnimation("battle_moves_close")
        end
      elseif not oldParty and newParty then
        if not (hgssRuntime.animation
            and hgssRuntime.animation.kind == "battle_party") then
          hgssRuntime.beginAnimation("battle_party", { duration = 0.42 })
        end
      elseif oldParty and not newParty and nextBattle.prompt == "menu" then
        if not (hgssRuntime.animation
            and hgssRuntime.animation.kind == "battle_party_close") then
          hgssRuntime.beginAnimation("battle_party_close")
        end
      elseif not oldBag and newBag then
        if not (hgssRuntime.animation
            and hgssRuntime.animation.kind == "battle_bag") then
          hgssRuntime.beginAnimation("battle_bag")
        end
      elseif oldBag and not newBag and nextBattle.prompt == "menu" then
        if not (hgssRuntime.animation
            and hgssRuntime.animation.kind == "battle_bag_close") then
          hgssRuntime.beginAnimation("battle_bag_close")
        end
      elseif battle.summaryPage and nextBattle.summaryPage
          and battle.summaryPage ~= nextBattle.summaryPage then
        hgssRuntime.beginAnimation("summary_page", {
          from = battle.summaryPage, to = nextBattle.summaryPage,
        })
      end
    end
    battle = nextBattle
    if changed then
      if not battle then
        moveInfo = nil
        battleInfoDetail = nil
        hgssRuntime.animation = nil
      else
        radarOpen = false
      end
      dirty = true
    end
  end

  local function submit(kind, fields)
    if not (battle and mod.battle) then return end
    intentId = intentId + 1
    fields = fields or {}
    fields.id, fields.revision, fields.kind = intentId, battle.revision, kind
    local ok, err = mod.battle:submit(fields)
    if not ok then mod.log:warn("battle intent %s rejected: %s", kind, err) end
    refreshBattle()
  end

  local function back()
    if displayRuntime.guideDetail then
      displayRuntime.guideDetail = nil
    elseif battleInfoDetail then
      battleInfoDetail = nil
    elseif moveInfo then
      if battle and battle.prompt == "moves" then
        hgssRuntime.beginAnimation("battle_move_info_close")
      end
      moveInfo = nil
    elseif battle and battle.prompt == "moves" then
      submit("back")
    end
    dirty = true
  end

  local function press(key)
    mod.input:tap(game, key)
  end

  local function holdTextSpeed(held)
    if held == (textSpeedToken ~= nil) then return end
    if held then textSpeedToken = mod.input:press(game, "a")
    else mod.input:release(textSpeedToken); textSpeedToken = nil end
  end

  local function useTool(action, opts)
    local ok, err = mod.world:useFieldAction(action.id, opts)
    if not ok then mod.log:warn("field action %s rejected: %s",
      tostring(action.id), tostring(err)) end
    refreshTools()
    dirty = true
  end

  function displayRuntime.activateTool(action, rodId)
    if not action then return false end
    if rodId then
      useTool(action, { rod = rodId })
    elseif action.id == "dig" or action.id == "teleport" then
      pendingAction = action
    elseif action.id == "fish" and #(action.rods or {}) > 1 then
      fieldChoice = { kind = "fish", action = action }
    elseif action.id == "fish" then
      useTool(action, { rod = action.rods[1].id })
    elseif action.id == "softboiled" then
      if #(action.sources or {}) == 1 then
        fieldChoice = { kind = "soft_target", action = action,
          source = action.sources[1] }
      else
        fieldChoice = { kind = "soft_source", action = action }
      end
    else
      useTool(action)
    end
    dirty = true
    return true
  end

  function displayRuntime.openHomeApp(id)
    local home = displayRuntime.home
    home.editing, home.library, home.addSlot = false, false, nil
    home.swapSource = nil
    home.activeApp = id
    if id == "store" then
      home.storeView, home.storeDetail, page = "today", nil, "STORE"
      dirty = true
      return true
    end
    local app = displayRuntime.storeById[id]
    local package = displayRuntime.homeCatalog.packages[id]
    if not app or not app.target or not package or not package.installed then
      return false
    end
    if id == "pokedex" then
      displayRuntime.pokedex.view, displayRuntime.pokedex.page = "index", 1
      displayRuntime.pokedex.habitatPage = 1
      displayRuntime.pokedex.movePage = 1
      displayRuntime.pokedex.data = nil
    elseif id == "bag" then
      displayRuntime.bag.page, displayRuntime.bag.detail = 1, nil
      displayRuntime.bag.message = nil
    end
    page, dirty = app.target, true
    return true
  end
  function displayRuntime.homeTileAt(x, y)
    local tiles = displayRuntime.homePageElements()
    for _, tile in ipairs(tiles) do
      local left, top, width, height = THEME.hgss:homeRect(tile)
      if inside(x, y, left, top, width, height) then return tile end
    end
  end

  function displayRuntime.tapHome(x, y)
    local home, layout = displayRuntime.home, displayRuntime.home.layout
    if home.library then
      if y < 30 and x < 27 then
        home.library, home.addSlot, dirty = false, nil, true
        return
      end
      if inside(x, y, 10, 34, 108, 13) then
        home.libraryKind, home.libraryPage, dirty = "app", 1, true
        return
      elseif inside(x, y, 121, 34, 108, 13) then
        home.libraryKind, home.libraryPage, dirty = "widget", 1, true
        return
      end
      local items = displayRuntime.Home.library(layout,
        displayRuntime.homeCatalog, home.page,
        home.addSlot.column, home.addSlot.row, home.libraryKind)
      local first = ((home.libraryPage or 1) - 1) * 6 + 1
      for visible = 0, 5 do
        local item = items[first + visible]
        local column, row = visible % 2, math.floor(visible / 2)
        if item and item.available and inside(x, y,
            10 + column * 111, 49 + row * 48, 108, 46) then
          displayRuntime.Home.place(layout, displayRuntime.homeCatalog,
            item.id, home.page, home.addSlot.column, home.addSlot.row)
          displayRuntime.Home.compactRows(layout,
            displayRuntime.homeCatalog)
          home.library, home.addSlot = false, nil
          displayRuntime.saveHome()
          return
        end
      end
      return
    end
    if home.editing and inside(x, y, 139, 4, 95, 19) then
      home.editing, home.swapSource, dirty = false, nil, true
      displayRuntime.saveHome()
      return
    end
    local tile = displayRuntime.homeTileAt(x, y)
    if home.editing then
      if tile then
        local left, top = THEME.hgss:homeRect(tile)
        if (x - left - 6) ^ 2 + (y - top - 6) ^ 2 <= 36 then
          displayRuntime.Home.remove(layout, tile.id,
            displayRuntime.homeCatalog)
          if home.swapSource == tile.id then home.swapSource = nil end
          displayRuntime.saveHome()
        elseif not home.swapSource then
          home.swapSource, dirty = tile.id, true
        elseif home.swapSource == tile.id then
          home.swapSource, dirty = nil, true
        elseif displayRuntime.Home.swap(layout, displayRuntime.homeCatalog,
            home.swapSource, tile.id) then
          home.swapSource = nil
          displayRuntime.saveHome()
        end
        return
      end
      local _, slots = displayRuntime.homePageElements()
      for _, slot in ipairs(slots) do
        local left, top, width, height = THEME.hgss:homeRect(slot)
        if inside(x, y, left, top, width, height) then
          if home.swapSource then
            local column = slot.column + math.floor(slot.columns / 2)
            if displayRuntime.Home.drop(layout, displayRuntime.homeCatalog,
                home.swapSource, home.page, column, slot.row) then
              home.swapSource = nil
              displayRuntime.saveHome()
            end
          else
            home.library, home.addSlot = true, slot
            home.libraryKind, home.libraryPage = "app", 1
          end
          dirty = true
          return
        end
      end
      return
    end
    local surface = tile and displayRuntime.homeCatalog.surfaces[tile.id]
    if surface and surface.widget == "tool" then
      if not displayRuntime.activateTool(surface.action, surface.rodId) then
        displayRuntime.openHomeApp("tools")
      end
    elseif surface then displayRuntime.openHomeApp(surface.package) end
  end

  function displayRuntime.activateStoreEntry(entry)
    if not entry or entry.state == "soon" then return end
    if entry.state == "get" then
      displayRuntime.setPackageInstalled(entry.id, true)
    else displayRuntime.openHomeApp(entry.id) end
  end

  function displayRuntime.tapStore(x, y)
    local home = displayRuntime.home
    if y < 30 and x < 22 then
      if home.storeDetail then home.storeDetail = nil
      else page, home.activeApp = "HOME", nil end
      dirty = true
      return
    end
    local detail = home.storeDetail and displayRuntime.storeEntry(
      displayRuntime.storeById[home.storeDetail])
    local view = detail and "detail" or home.storeView
    local action, index = THEME.hgss:storeHit(x, y, view)
    if action == "prev" or action == "next" then
      displayRuntime.cycleStoreView(action == "next" and 1 or -1)
      dirty = true
      return
    end
    if action == "page_prev" or action == "page_next" then
      displayRuntime.cycleStorePage(view,
        action == "page_next" and 1 or -1)
      dirty = true
      return
    end
    if view == "detail" then
      if action == "remove" and detail.removable then
        displayRuntime.setPackageInstalled(detail.id, false)
      elseif action == "action" then
        displayRuntime.activateStoreEntry(detail)
      end
      return
    end
    if action == "tab" then
      home.storeView = ({ "today", "apps", "library" })[index]
    elseif view == "today" then
      local entries = displayRuntime.storeTodayEntries()
      if action == "featured_action" then
        displayRuntime.activateStoreEntry(entries[1])
      elseif action == "featured" then home.storeDetail = entries[1].id
      elseif action == "recommendation" then
        home.storeDetail = entries[index + 1].id
      end
    elseif view == "apps" then
      local entries = displayRuntime.storeEntries()
      local _, _, _, offset = displayRuntime.storePage(view, entries)
      local entry = index and entries[offset + index]
      if action == "app_action" then
        displayRuntime.activateStoreEntry(entry)
      elseif action == "app" and entry then home.storeDetail = entry.id end
    elseif view == "library" then
      local entries = displayRuntime.storeEntries(true)
      local _, _, _, offset = displayRuntime.storePage(view, entries)
      local entry = index and entries[offset + index]
      if action == "installed_action" then
        displayRuntime.activateStoreEntry(entry)
      elseif action == "installed" and entry then home.storeDetail = entry.id end
    end
    dirty = true
  end

  function displayRuntime.tapPokedex(x, y)
    local state = displayRuntime.pokedex
    if y < HEADER and x < 22 then
      if state.view == "index" then
        page, displayRuntime.home.activeApp = "HOME", nil
      elseif state.view == "profile" then
        state.view = "index"
      else
        state.view = "profile"
      end
      dirty = true
      return
    end
    local model = displayRuntime.pokedexModel()
    local action, index = THEME.hgss:pokedexHit(
      x * THEME.hgssScale, y * THEME.hgssScale, model)
    if action == "prev" or action == "next" then
      displayRuntime.cyclePokedex(action == "next" and 1 or -1)
    elseif action == "species" and model.entries[index] then
      displayRuntime.selectPokedexSpecies(model.entries[index].index)
    elseif action == "stats" or action == "habitat" or action == "moves" then
      state.view = action
      state.habitatPage, state.movePage = 1, 1
      dirty = true
    end
  end

  function displayRuntime.tapBag(x, y)
    local state = displayRuntime.bag
    if y < HEADER and x < 22 then
      if state.detail then
        state.detail, state.message = nil, nil
      else
        page, displayRuntime.home.activeApp = "HOME", nil
      end
      dirty = true
      return
    end
    local model = displayRuntime.bagModel()
    local action, value = THEME.hgss:bagHit(
      x * THEME.hgssScale, y * THEME.hgssScale, model)
    if action == "pocket" then
      displayRuntime.cycleBagPocket(value)
    elseif action == "page" then
      displayRuntime.cycleBagPage(value)
    elseif action == "item" and model.entries[value] then
      state.detail, state.message = model.entries[value].id, nil
      dirty = true
    elseif action == "use" and model.detail then
      displayRuntime.useBagItem(model.detail.id)
    end
  end

  local function tapFieldChoice(x, y)
    if y < HEADER and x < 24 then
      if fieldChoice.kind == "soft_target"
          and #(fieldChoice.action.sources or {}) > 1 then
        fieldChoice = { kind = "soft_source", action = fieldChoice.action }
      else
        fieldChoice = nil
      end
      dirty = true
      return
    end
    if fieldChoice.kind == "fish" then
      if THEME.style == "hgss" then
        local index = THEME.hgss:rodHit(x * THEME.hgssScale,
          y * THEME.hgssScale, fieldChoice.action.rods)
        local rod = index and fieldChoice.action.rods[index]
        if rod then
          local action = fieldChoice.action
          fieldChoice = nil
          useTool(action, { rod = rod.id })
        end
        return
      end
      for i, rod in ipairs(fieldChoice.action.rods or {}) do
        if inside(x, y, 14, 30 + (i - 1) * 37, 132, 32) then
          local action = fieldChoice.action
          fieldChoice = nil
          useTool(action, { rod = rod.id })
          return
        end
      end
      return
    end
    local choices = fieldChoice.kind == "soft_source"
      and fieldChoice.action.sources or fieldChoice.source.targets
    if y < 23 then return end
    local col, row = x >= 81 and 1 or 0, math.floor((y - 23) / 39)
    local selected = choices[row * 2 + col + 1]
    if not selected then return end
    if fieldChoice.kind == "soft_source" then
      fieldChoice = { kind = "soft_target", action = fieldChoice.action,
                      source = selected }
      dirty = true
    else
      local action, source = fieldChoice.action, fieldChoice.source
      fieldChoice = nil
      useTool(action, { sourceSlot = source.slot, targetSlot = selected.slot })
    end
  end

  local function tapLearn(learn, top, x, y)
    if THEME.style == "hgss" then
      local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
      if learn.selecting and hy < 30 and hx < 27 then
        press("b")
        return
      end
      local action, slot = THEME.hgss:moveLearnHit(
        hx, hy, learn.selecting)
      local details = assist("move_details")
      if action == "new" and details then
        moveInfo = compat.moveInfoEntry(learn.newMoveId)
        dirty = moveInfo ~= nil or dirty
        return
      elseif learn.selecting and action then
        if action == "info" and not details then action = "move" end
        local source = learn.mon.moves[slot]
        if not source then return end
        learn.index = slot
        if learn.native then learn.native.row = slot end
        if action == "info" then
          moveInfo = compat.moveInfoEntry(source)
          dirty = moveInfo ~= nil or dirty
        else
          press("a")
        end
        return
      elseif top and top.isTextBox then
        if top.waiting or (top.done and not top.choice) then press("a") end
        return
      end
      return
    end
    if assist("move_details") then
      if learn.selecting and inside(x, y, 137, 22, 17, 15) then
        moveInfo = compat.moveInfoEntry(learn.newMoveId)
        dirty = moveInfo ~= nil or dirty
        return
      elseif not learn.selecting and inside(x, y, 143, 39, 15, 15) then
        moveInfo = compat.moveInfoEntry(learn.newMoveId)
        dirty = moveInfo ~= nil or dirty
        return
      end
    end
    if top and top.isTextBox then
      if top.waiting or (top.done and not top.choice) then press("a") end
      return
    end
    if learn.selecting and top == (learn.native or learn) then
      if x >= 8 and x < 152 and y >= 38
          and y < 38 + #learn.mon.moves * 25 then
        local slot = math.floor((y - 38) / 25) + 1
        learn.index = slot
        if learn.native then learn.native.row = slot end
        if assist("move_details") and x >= 137 then
          moveInfo = compat.moveInfoEntry(learn.mon.moves[slot])
          dirty = moveInfo ~= nil or dirty
        else
          press("a")
        end
      end
      return
    end
    if top and top.onChoose and (top.index == 1 or top.index == 2) then
      if inside(x, y, 18, 106, 58, 27) then
        top.index = 1
        press("a")
      elseif inside(x, y, 84, 106, 58, 27) then
        top.index = 2
        press("a")
      end
    end
  end

  local function fullBattleChoice(x, y)
    for i = 1, 4 do
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
      if inside(x, y, 3 + col * 78, 94 + row * 24, 76, 22) then
        return i
      end
    end
  end

  local function tapBattle(x, y)
    if currentBattleUIMode() == "info" then
      if THEME.style == "hgss" then
        local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
        if battleInfoDetail then
          if hy < 30 and hx < 27 then battleInfoDetail, dirty = nil, true end
        else
          local info = displayRuntime.enemyInfo()
          local action = THEME.hgss:enemyInfoHit(hx, hy, info.dvs ~= nil)
          if action then battleInfoDetail, dirty = action, true end
        end
        return
      end
      if battleInfoDetail then
        if y < HEADER and x < 22 then battleInfoDetail, dirty = nil, true end
      elseif y >= 52 and y < 72 and x >= 118 and displayRuntime.enemyInfo().dvs then
        battleInfoDetail, dirty = "dvs", true
      elseif y >= HEADER and y < 79 then
        battleInfoDetail, dirty = "profile", true
      elseif y >= 90 then
        battleInfoDetail, dirty = x < 80 and "weak" or "resist", true
      end
      return
    end
    local top = game and game.stack and game.stack:top()
    local ppMoves = screenContract(top, "pp")
    if ppMoves then
      if THEME.style == "hgss" then
        local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
        if hy < 30 and hx < 27 then
          press("b")
        else
          local first, count = choiceWindow(ppMoves.items or {}, ppMoves.index)
          local row = THEME.hgss:pcListHit(hx, hy, count)
          if row then ppMoves.index = first + row - 1; press("a") end
        end
      elseif y < HEADER and x < 24 then
        press("b")
      else
        local row = math.floor((y - 25) / 28) + 1
        if x >= 8 and x < 152 and row >= 1
            and row <= #ppMoves.items then
          ppMoves.index = row
          press("a")
        end
      end
      return
    end
    if compat.isScreen(top, "summary") then
      if THEME.style == "hgss" then
        local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
        if hy < 30 and hx < 27 then
          press("b")
        elseif hy < 30 and hx < 82 then
          press("left")
        elseif hy < 30 and hx < 139 then
          press("right")
        end
      elseif y < HEADER and x < 24 then
        press("b")
      elseif compat.summary.supports(top, game)
          and inside(x, y, 103, 125, 53, 15) then
        press("a")
      elseif not compat.summary.supports(top, game)
          and inside(x, y, 14, 94, 132, 34) then
        press("b")
      end
      return
    end
    local party = screenContract(top, "party")
    if party then
      if y < HEADER and x < 24 then
        press("b")
      elseif party.submenu then
        if THEME.style == "hgss" then
          local actions, submenu = hgssRuntime.partySubmenuActions(party)
          local row = THEME.hgss:partyActionAt(
            x * THEME.hgssScale, y * THEME.hgssScale, #actions)
          local action = row and actions[row]
          if action then
            if submenu then submenu.index = action.index
            else party.subIndex = action.index end
            press("a")
          end
        else
          local submenu = type(party.submenu) == "table" and party.submenu or nil
          local items = party.subItems or (submenu and submenu.items) or {}
          local index = math.floor((y - 29) / 35) + 1
          if x >= 14 and x < 146 and index >= 1
              and index <= #items then
            if submenu then submenu.index = index else party.subIndex = index end
            press("a")
          end
        end
      elseif y >= 23 then
        local slot
        if THEME.style == "hgss" then
          slot = THEME.hgss:partySlot(x, y, #(battle.party or {}))
        else
          local col, row = x >= 81 and 1 or 0, math.floor((y - 23) / 39)
          slot = row * 2 + col + 1
        end
        if (battle.party or {})[slot] then
          party.index = slot
          press("a")
        end
      end
      return
    end
    local menu = compat.battleBagMenu(top)
    if menu then
      if THEME.style == "hgss" then
        local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
        local bagY = THEME.hgss.battleBagOffsetY or 0
        if hy < 63 + bagY then
          if hx < 29 then
            press("b")
          elseif categorizedBag(top) and hx >= 62 and hx < 92 then
            press("left")
          elseif categorizedBag(top) and hx >= 158 and hx < 187 then
            press("right")
          end
        elseif hx >= 7 and hx < 233
            and hy >= 66 + bagY and hy < 197 + bagY then
          local view = hgssRuntime.bagView(menu)
          local first, count = THEME.hgss:battleBagWindow(view)
          local row = math.floor((hy - 66 - bagY) / 33) + 1
          if row >= 1 and row <= count then
            compat.selectBattleBagItem(top, first + row - 1)
            press("a")
          end
        end
        return
      end
      if y < HEADER then
        if categorizedBag(top) then
          if x < 18 then
            press("b")
          elseif x < 40 then
            press("left")
          elseif x >= 86 and x < 108 then
            press("right")
          end
        elseif x < 24 then
          press("b")
        end
      else
        local first, count = choiceWindow(menu.items or {}, menu.index)
        local row = math.floor((y - 25) / 28) + 1
        if x >= 8 and x < 152 and row >= 1 and row <= count then
          compat.selectBattleBagItem(top, first + row - 1)
          press("a")
        end
      end
      return
    end
    local raw = battleState()
    if top and top ~= raw and not top.isTextBox then
      return
    end
    if battle.prompt == "safari" then
      local choice
      if THEME.style == "hgss" then
        choice = THEME.hgss:safariHit(
          x * THEME.hgssScale, y * THEME.hgssScale)
      elseif fullBottomBattleUI() then
        choice = fullBattleChoice(x, y)
      elseif y >= 24 then
        local col, row = x >= 81 and 1 or 0, y >= 81 and 1 or 0
        choice = row * 2 + col + 1
      end
      local action = ({ "ball", "bait", "rock", "run" })[choice]
      if not action then return end
      submit("safari", { action = action })
      return
    end
    if battle.prompt == "mimic" then
      local index
      if THEME.style == "hgss" then
        index = THEME.hgss:mimicHit(x * THEME.hgssScale,
          y * THEME.hgssScale, #(battle.mimicMoves or {}))
      elseif x >= 8 and x < 152 then
        index = math.floor((y - 25) / 28) + 1
      end
      if index and index >= 1 and index <= #(battle.mimicMoves or {}) then
        submit("mimic", { index = index })
      end
      return
    end
    if battle.prompt == "forget" then
      local mon = raw and screenContract(raw, "forget")
      if THEME.style == "hgss" then
        local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
        if hy < 30 and hx < 27 then
          press("b")
          return
        end
        local action, slot = THEME.hgss:moveLearnHit(hx, hy, true)
        local details = assist("move_details")
        if action == "new" and details then
          moveInfo = compat.moveInfoEntry(
            raw.pendingLearn and raw.pendingLearn.move)
        elseif action and mon and mon.moves[slot] then
          if action == "info" and not details then action = "move" end
          raw.forgetIndex, battle.forgetIndex = slot, slot
          if action == "info" then
            moveInfo = compat.moveInfoEntry(mon.moves[slot])
          else
            press("a")
          end
        end
        dirty = moveInfo ~= nil or dirty
        return
      end
      if y < HEADER and x < 24 then
        press("b")
      elseif raw and assist("move_details")
          and inside(x, y, 137, 22, 17, 15) then
        moveInfo = compat.moveInfoEntry(raw.pendingLearn and raw.pendingLearn.move)
      elseif mon and x >= 8 and x < 152 and y >= 38
          and y < 38 + #mon.moves * 25 then
        raw.forgetIndex = math.floor((y - 38) / 25) + 1
        if assist("move_details") and x >= 137 then
          moveInfo = compat.moveInfoEntry(mon.moves[raw.forgetIndex])
        else
          press("a")
        end
      end
      dirty = true
      return
    end
    if y < HEADER and x < 24
       and (moveInfo or battle.prompt == "moves") then
      back()
      return
    end
    if moveInfo or battle.prompt == "locked" then return end
    if battle.prompt == "advance" then
      press("a")
      return
    end
    if battle.prompt == "moves" then
      if THEME.style == "hgss" then
        local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
        if hy < 30 and hx < 28 then back(); return end
        if hy < 33 or hy >= 198 then return end
        local column = hx >= 120 and 1 or 0
        local row = hy >= 118 and 1 or 0
        local slot = row * 2 + column + 1
        local move = battle.moves[slot]
        if not move then return end
        local disabled = THEME:moveUnavailableReason(move) ~= nil
        local cardX, cardY = 6 + column * 116, 33 + row * 85
        if assist("move_details") and hx >= cardX + 94
            and hx < cardX + 112 and hy >= cardY
            and hy < cardY + 24 then
          local raw = battleState()
          if raw and not disabled then raw.moveIndex = slot end
          battle.moveIndex = slot
          moveInfo = move
          hgssRuntime.beginAnimation("battle_move_info")
          dirty = true
        elseif not disabled then
          submit("move", { slot = slot })
        end
        return
      end
      local grid = companionMoveGrid(battleState())
      local slot, cardX, cardY = moveSlotAt(
        x, y, #(battle.moves or {}), grid)
      local move = battle.moves[slot]
      if not move then return end
      local disabled = THEME:moveUnavailableReason(move) ~= nil
      if assist("move_details")
          and inside(x, y, cardX + (grid and 62 or 130),
                     cardY + (grid and 0 or 13), 14, 14) then
        local raw = battleState()
        if raw and not disabled then raw.moveIndex = slot end
        moveInfo = move
        hgssRuntime.beginAnimation("battle_move_info")
        dirty = true
      elseif not disabled then
        submit("move", { slot = slot })
      end
      return
    end
    if battle.prompt ~= "menu" then return end
    local choice
    if THEME.style == "hgss" then
      choice = THEME.hgss:battleChoice(
        x * THEME.hgssScale, y * THEME.hgssScale)
    elseif fullBottomBattleUI() then
      choice = fullBattleChoice(x, y)
    elseif y >= 24 then
      local col, row = x >= 81 and 1 or 0, y >= 81 and 1 or 0
      choice = row * 2 + col + 1
    end
    if not choice then return end
    local raw = battleState()
    if raw and game.stack:top() == raw then
      raw.menuIndex = choice
      press("a")
    end
    dirty = true
  end

  local function tapPc(kind, root, top, x, y)
    local list = pcList()
    local listKind = pcListKind(list)
    if displayRuntime.pcNotice(kind, root, top) then
      press("a")
      dirty = true
      return
    end
    local nativeQuantity = root.screenId == "Gen2ItemPcMenu"
      and root.qtyState or nil
    local quantity = nativeQuantity or (kind == "items" and list and top
      and type(top.qty) == "number" and type(top.max) == "number"
      and type(top.onDone) == "function" and top)
    if quantity then
      if THEME.style == "hgss" then
        local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
        local action = THEME.hgss:pcQuantityHit(hx, hy)
        if hy < 30 and hx < 27 then press("b")
        elseif action == "minus" then press("down")
        elseif action == "plus" then press("up")
        elseif action == "confirm" then press("a")
        elseif action == "cancel" then press("b") end
        dirty = true
        return
      end
      if y < HEADER and x < 24 then
        press("b")
      elseif inside(x, y, 8, 51, 43, 38) then
        press("down")
      elseif inside(x, y, 109, 51, 43, 38) then
        press("up")
      elseif inside(x, y, 8, 104, 90, 29) then
        press("a")
      elseif inside(x, y, 102, 104, 50, 29) then
        press("b")
      end
      dirty = true
      return
    end

    if list and top == list then
      if THEME.style == "hgss" then
        local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
        if hy < 30 and hx < 27 then
          press("b")
        else
          local selected, total
          if listKind == "gen2_box_change" then
            selected, total = list.pickIndex, 14
          elseif listKind and listKind:find("^gen2_box_") then
            local mons = (list.mode == "deposit" or list.boxIndex == 0)
              and (game.save.party or {})
              or ((game.save.boxes or {})[
                list.boxIndex or game.save.currentBox or 1] or {})
            selected = list.index
            total = list.phase == "insert" and math.max(1, #mons)
              or #mons + 1
          elseif listKind and listKind:find("^gen2_item_") then
            selected, total = list.listIndex, #(list.rows or {}) + 1
          else
            selected, total = list.index, #(list.items or {})
          end
          local first, count = pageWindow(selected, total)
          local row = THEME.hgss:pcListHit(hx, hy, count)
          if row then
            local index = first + row - 1
            if listKind == "gen2_box_change" then list.pickIndex = index
            elseif listKind and listKind:find("^gen2_item_") then
              list.listIndex = index
            else list.index = index end
            press("a")
          end
        end
        dirty = true
        return
      end
      if y < HEADER and x < 24 then
        press("b")
      elseif listKind == "gen2_box_change" then
        local first, count = pageWindow(list.pickIndex, 14)
        for row = 1, count do
          if inside(x, y, 8, 25 + (row - 1) * 25, 144, 22) then
            list.pickIndex = first + row - 1
            press("a")
            break
          end
        end
      elseif listKind and listKind:find("^gen2_box_") then
        local mons = (list.mode == "deposit" or list.boxIndex == 0)
          and (game.save.party or {})
          or ((game.save.boxes or {})[list.boxIndex or game.save.currentBox or 1]
            or {})
        local total = list.phase == "insert" and math.max(1, #mons)
          or #mons + 1
        local first, count = pageWindow(list.index, total)
        for row = 1, count do
          if inside(x, y, 8, 38 + (row - 1) * 24, 144, 22) then
            list.index = first + row - 1
            press("a")
            break
          end
        end
      elseif listKind and listKind:find("^gen2_item_") then
        local first, count = pageWindow(list.listIndex, #(list.rows or {}) + 1)
        for row = 1, count do
          if inside(x, y, 8, 25 + (row - 1) * 25, 144, 22) then
            list.listIndex = first + row - 1
            press("a")
            break
          end
        end
      elseif #(list.items or {}) == 0 then
        if inside(x, y, 34, kind == "items" and 94 or 101,
                  92, kind == "items" and 30 or 28) then press("b") end
      elseif listKind == "pc_box_withdraw"
          or listKind == "pc_box_deposit"
          or listKind == "pc_box_release" then
        local first, count = pageWindow(list.index, #list.items)
        for slot = 1, count do
          if inside(x, y, 8, 38 + (slot - 1) * 24, 144, 22) then
            list.index = first + slot - 1
            press("a")
            break
          end
        end
      elseif listKind == "pc_box_change" then
        local first, count = pageWindow(list.index, #list.items)
        for row = 1, count do
          if inside(x, y, 8, 25 + (row - 1) * 25, 144, 22) then
            list.index = first + row - 1
            press("a")
            break
          end
        end
      else
        local first, count = pageWindow(list.index, #list.items)
        for row = 1, count do
          if inside(x, y, 8, 25 + (row - 1) * 25, 144, 22) then
            list.index = first + row - 1
            press("a")
            break
          end
        end
      end
      dirty = true
      return
    end

    local submenu = displayRuntime.gen2BoxSubmenu(top)
    if submenu then
      local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
      if hy < 30 and hx < 27 then
        press("b")
      else
        local row = THEME.hgss:pcListHit(hx, hy, #submenu)
        if row then top.submenuIndex = row; press("a") end
      end
      dirty = true
      return
    end

    if root.screenId == "Gen2ItemPcMenu"
        and root.phase == "deposit" and root.pack then
      local menu = compat.battleBagMenu(root.pack)
      local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
      if hy < 30 and hx < 27 then
        press("b")
      elseif menu then
        local first, count = choiceWindow(menu.items or {}, menu.index)
        local row = THEME.hgss:pcListHit(hx, hy, count)
        if row then
          compat.selectBattleBagItem(root.pack, first + row - 1)
          press("a")
        end
      end
      dirty = true
      return
    end

    if top ~= root then return end
    if root.screenId == "Gen2PcMenu"
        and (root.message or root.savePhase or root.picking) then return end
    if root.screenId == "Gen2ItemPcMenu" and root.phase ~= "menu" then return end
    local items = root.items or root.entries or {}
    local count = #items
    if THEME.style == "hgss" then
      local row = THEME.hgss:pcRootHit(
        x * THEME.hgssScale, y * THEME.hgssScale, count)
      if row then root.index = row; press("a") end
      dirty = true
      return
    end
    if count > 0 then
      local rowHeight = math.floor(116 / count)
      local row = math.floor((y - 23) / rowHeight) + 1
      if x >= 8 and x < 152 and row >= 1 and row <= count
          and inside(x, y, 8, 23 + (row - 1) * rowHeight,
                     144, rowHeight - 3) then
        root.index = row
        press("a")
      end
    end
    dirty = true
  end

  function displayRuntime.commitDialogueChoice(top, field, selected)
    local now = love.timer.getTime()
    if trackChoice(top, now) then dirty = true end
    if choiceCommitted == top then return false end
    if not choiceReady(now, choiceReadyAt) then
      choiceReadyAt = now + CHOICE_QUIET
      choiceNudgeUntil = now + 0.55
      dirty = true
      return false
    end
    compat.choiceIndex(top, field, selected)
    if type(top.clampScroll) == "function" then
      pcall(top.clampScroll, top)
    end
    choiceCommitted = top
    press("a")
    return true
  end

  local function tapDialogueChoice(top, labels, x, y, field)
    local selected
    local rows, cols, left, topY, cellW, cellH, gap =
      compat.choiceGrid(top, field, #labels)
    if rows then
      for row = 1, rows do
        for col = 1, cols do
          if inside(x, y, left + (col - 1) * (cellW + gap),
              topY + (row - 1) * (cellH + gap), cellW, cellH) then
            selected = (row - 1) * cols + col
            break
          end
        end
        if selected then break end
      end
    elseif #labels == 2 then
      if inside(x, y, 24, 54, 112, 32) then selected = 1 end
      if inside(x, y, 24, 90, 112, 32) then selected = 2 end
    else
      local start, count = choiceWindow(labels,
        compat.choiceIndex(top, field))
      for row = 1, count do
        if inside(x, y, 8, 24 + (row - 1) * 27, 144, 24) then
          selected = start + row - 1
          break
        end
      end
    end
    if not selected then return end
    displayRuntime.commitDialogueChoice(top, field, selected)
  end

  local function tapNaming(top, grid, x, y)
    local row, col = namingCell(x, y, grid)
    if not row then return end
    if top.screenId == "Gen2NamingScreen" then
      top.row = row - 1
      top.col = row == #grid and (col - 1) * 3 or col - 1
    else
      top.row, top.col = row, col
    end
    press("a")
    dirty = true
  end

  local function changePage(direction)
    if pendingFly or pendingAction or fieldChoice or partyActionSlot
        or partyMoveFrom
        or displayRuntime.moveLearnScreen()
        or dialogueChoice() or radarOpen then return end
    if not pageSwipeAllowed(screenState(), battle) then return end
    if trainerStepsOpen then
      trainerStepsOpen, dirty = false, true
      return
    end
    if THEME.style == "hgss" and page == "HOME" then
      local home = displayRuntime.home
      if home.library and home.addSlot then
        local count = math.max(1, math.ceil(#displayRuntime.Home.library(
          home.layout, displayRuntime.homeCatalog, home.page,
          home.addSlot.column, home.addSlot.row, home.libraryKind) / 6))
        home.libraryPage = ((home.libraryPage or 1) - 1 + direction) % count + 1
      else
        local count = displayRuntime.Home.pageCount(home.layout)
          + (home.editing and 1 or 0)
        home.page = ((home.page or 1) - 1 + direction) % count + 1
      end
      dirty = true
      return
    elseif THEME.style == "hgss" and page == "STORE" then
      local home = displayRuntime.home
      if home.storeDetail then home.storeDetail = nil
      else displayRuntime.cycleStoreView(direction) end
      dirty = true
      return
    elseif THEME.style == "hgss" and page == "POKEDEX" then
      displayRuntime.cyclePokedex(direction)
      return
    elseif THEME.style == "hgss" and page == "BAG" then
      if displayRuntime.bag.detail then
        displayRuntime.bag.detail, displayRuntime.bag.message = nil, nil
        dirty = true
      else
        displayRuntime.cycleBagPage(direction)
      end
      return
    end
    if page == "LOCAL" and THEME.style == "hgss"
        and (displayRuntime.explorer.selected
          or displayRuntime.explorer.view
          or displayRuntime.explorer.mapFull) then
      local explorer = displayRuntime.explorer
      if explorer.mapFull then explorer.mapFull = false
      elseif explorer.selected then
        explorer.view, explorer.selected, explorer.detailPage = nil, nil, 1
      else explorer.view, explorer.page = nil, 1 end
      dirty = true
      return
    end
    if displayRuntime.guideDetail then
      local guide, row = guideData()
      for _, candidate in ipairs(guide.rows) do
        if candidate.species == displayRuntime.guideDetail.species then
          row = candidate break
        end
      end
      if row and row.detailPages > 1 then
        local nextPage = carouselSubpage(displayRuntime.guideDetail.page,
          row.detailPages, direction)
        if nextPage then
          displayRuntime.guideDetail.page, dirty = nextPage, true
        end
      end
      return
    end
    refreshTools()
    local current, count
    if page == "GUIDE" then
      current, count = guidePage, guideData().pages
    elseif page == "AREA" then
      current, count = areaPage, areaData().pages
    end
    local subpage = current and carouselSubpage(current, count, direction)
    if subpage then
      if page == "GUIDE" then guidePage = subpage else areaPage = subpage end
      mod.log:info("page %s %d/%d", page, subpage, count)
      dirty = true
      return
    end
    local names = pageNames()
    local index = 1
    for i, name in ipairs(names) do
      if name == page then index = i break end
    end
    index = ((index - 1 + direction) % #names) + 1
    page = names[index]
    if page == "GUIDE" then
      guidePage = direction < 0 and guideData().pages or 1
    elseif page == "AREA" then
      areaPage = direction < 0 and areaData().pages or 1
    end
    mod.log:info("page %s", page)
    dirty = true
  end

  local triggerHeld = { left = false, right = false, overlay = false }
  local screenSwapHeld = false
  local function triggerEdge(value, held)
    value = tonumber(value) or 0
    local down = held and value > 0.35 or value >= 0.65
    return down and not held, down
  end
  do
    local pressed, held = triggerEdge(0.7, false)
    local repeated = triggerEdge(0.7, held)
    local _, released = triggerEdge(0.2, held)
    assert(pressed and not repeated and not released,
      "trigger tab edge and hysteresis")
  end

  local function pollTriggerTabs()
    if mod.options:get("trigger_tabs") ~= true then
      triggerHeld.left, triggerHeld.right = false, false
      return
    end
    local js = love and love.joystick
    local left, right = 0, 0
    if js and js.getJoysticks then
      local ok, pads = pcall(js.getJoysticks)
      if ok then
        for _, pad in ipairs(pads or {}) do
          if pad.getGamepadAxis then
            local okLeft, value = pcall(pad.getGamepadAxis, pad, "triggerleft")
            if okLeft then left = math.max(left, tonumber(value) or 0) end
            local okRight, value2 = pcall(pad.getGamepadAxis, pad, "triggerright")
            if okRight then right = math.max(right, tonumber(value2) or 0) end
          end
        end
      end
    end
    local leftPressed, rightPressed
    leftPressed, triggerHeld.left = triggerEdge(left, triggerHeld.left)
    rightPressed, triggerHeld.right = triggerEdge(right, triggerHeld.right)
    if leftPressed then changePage(-1)
    elseif rightPressed then changePage(1) end
  end

  local function pollScreenSwap()
    local down, infoDown, overlayDown = false, false, false
    local swapEnabled = THEME:displayMode(mod.options) == "fullscreen"
      or mod.options:get("screen_swap") == true
    local overlayButton = mod.options:get("overlay_button") or "off"
    local overlayEnabled = THEME:displayMode(mod.options) == "combined"
      and THEME:windowMode(mod.options) == "overlay"
      and overlayButton ~= "off"
    local keyboard = love and love.keyboard
    if keyboard and keyboard.isDown then
      if swapEnabled then
        local ok, pressed = pcall(keyboard.isDown, "f6")
        down = ok and pressed or false
      end
      local okInfo, pressedInfo = pcall(keyboard.isDown, "x")
      infoDown = okInfo and pressedInfo or false
      if overlayEnabled and overlayButton == "f7" then
        local okOverlay, pressedOverlay = pcall(keyboard.isDown, "f7")
        overlayDown = okOverlay and pressedOverlay or false
      end
    end
    local js = love and love.joystick
    if js and js.getJoysticks then
      local ok, pads = pcall(js.getJoysticks)
      if ok then
        for _, pad in ipairs(pads or {}) do
          if pad.isGamepadDown then
            if swapEnabled then
              local okDown, pressed = pcall(pad.isGamepadDown, pad, "y")
              if okDown and pressed then down = true end
            end
            local okInfo, pressedInfo = pcall(pad.isGamepadDown, pad, "x")
            if okInfo and pressedInfo then infoDown = true end
            if overlayEnabled and overlayButton ~= "f7" then
              local okOverlay, pressedOverlay = pcall(
                pad.isGamepadDown, pad, overlayButton)
              if okOverlay and pressedOverlay then overlayDown = true end
            end
          end
        end
      end
    end
    local pressed = down and not screenSwapHeld
    local infoPressed = infoDown and not triggerHeld.info
    local overlayPressed = overlayDown and not triggerHeld.overlay
    screenSwapHeld = down
    triggerHeld.overlay = overlayDown
    triggerHeld.info = infoDown
    return pressed, infoPressed, overlayPressed
  end

  local function tap(x, y)
    if moveInfo then
      if y < HEADER and x < 24 then back() end
      return
    end
    local summary = screenById("summary")
    if summary and game.stack:top() == summary then
      if THEME.style == "hgss" and compat.summary.supports(summary, game) then
        local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
        if hy < 30 and hx < 27 then
          press("b")
        elseif hy < 30 and hx < 82 then
          press("left")
        elseif hy < 30 and hx < 139 then
          press("right")
        elseif battle and assist("move_details")
            and tonumber(summary.page) == 2 then
          for slot = 1, 4 do
            local rowY = 63 + (slot - 1) * 37
            if inside(hx, hy, 6, rowY, 228, 34) then
              local selected = hgssRuntime.summaryMove(summary, slot)
              if selected then
                summary.moveIndex, moveInfo = slot, selected
                dirty = true
              end
              break
            end
          end
        end
      elseif not battle then
        return
      elseif y < HEADER and x < 24 then
        press("b")
      elseif compat.summary.supports(summary, game)
          and inside(x, y, 103, 125, 53, 15) then
        press("a")
      elseif not compat.summary.supports(summary, game)
          and inside(x, y, 14, 94, 132, 34) then
        press("b")
      else
        return
      end
      if compat.summary.supports(summary, game) then
        dirty = true
      end
      return
    end
    local choice, labels, field = dialogueChoice()
    local learnScreen = screenById("MoveLearnMenu")
      or screenById("Gen2MoveDeleter")
    local learn = displayRuntime.moveLearnScreen()
    if learn and choice and learn.field and THEME.style == "hgss" then
      local selected = THEME.hgss:moveLearnChoiceHit(
        x * THEME.hgssScale, y * THEME.hgssScale)
      if selected then
        displayRuntime.commitDialogueChoice(choice, field, selected)
      end
      return
    elseif learn and not choice then
      tapLearn(learn, game.stack:top(), x, y)
      return
    end
    local fieldPp = displayRuntime.fieldPpMoveScreen()
    if fieldPp then
      local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
      if hy < 30 and hx < 27 then
        press("b")
      else
        local first, count = choiceWindow(fieldPp.items, fieldPp.index)
        local row = THEME.hgss:pcListHit(hx, hy, count)
        if row then
          fieldPp.native.row = first + row - 1
          press("a")
        end
      end
      dirty = true
      return
    elseif learnScreen and not choice then
      return
    end
    local fieldParty, fieldPartyData = displayRuntime.fieldBagParty()
    if fieldParty then
      if y < HEADER and x < 24 then
        press("b")
      else
        local slot = THEME.style == "hgss"
          and THEME.hgss:partySlot(x, y, #fieldPartyData)
          or partySlotAt(x, y, #fieldPartyData)
        if slot then
          fieldParty.index = slot
          displayRuntime.bag.pending.mon = fieldPartyData[slot]
          press("a")
        end
      end
      dirty = true
      return
    end
    local battleTop = game and game.stack and game.stack:top()
    local levelMon = battle and compat.levelUpMon(battleTop)
    if levelMon then
      if THEME.style == "hgss" then
        if THEME.hgss:levelUpHit(x * THEME.hgssScale,
            y * THEME.hgssScale) then press("a") end
      else
        local buttonY = levelMon.stats and (levelMon.stats.specialAttack ~= nil
          or levelMon.stats.specialDefense ~= nil) and 111 or 108
        if inside(x, y, 24, buttonY, 112, 27) then press("a") end
      end
      return
    end
    if choice then
      tapDialogueChoice(choice, labels, x, y, field)
      return
    end
    local mode, top = screenState()
    local namingKeys = screenContract(top, "naming")
    if namingKeys then
      tapNaming(top, namingKeys, x, y)
      return
    elseif compat.isScreen(top, "naming") then
      return
    end
    if mode == "title" then
      press("a")
      return
    end
    if battle then
      tapBattle(x, y)
      return
    end
    if mode == "textbox" then
      if textTouch(top) == "advance" then press("a") end
      return
    end
    local pcKind, pcRoot = pcSession()
    if pcKind then
      tapPc(pcKind, pcRoot, top, x, y)
      return
    end
    if mode ~= "active" then return end
    if THEME.style == "hgss" and page == "HOME" then
      displayRuntime.tapHome(x * THEME.hgssScale, y * THEME.hgssScale)
      return
    elseif THEME.style == "hgss" and page == "STORE" then
      displayRuntime.tapStore(x * THEME.hgssScale, y * THEME.hgssScale)
      return
    elseif THEME.style == "hgss" and page == "POKEDEX" then
      displayRuntime.tapPokedex(x, y)
      return
    elseif THEME.style == "hgss" and page == "BAG" then
      displayRuntime.tapBag(x, y)
      return
    end
    if partyActionSlot then
      local slot = partyActionSlot
      local mon = game.save.party and game.save.party[slot]
      local canSwap = mon and #(game.save.party or {}) > 1
        and mod.world and mod.world.canReorderParty
        and mod.world:canReorderParty()
      if THEME.style == "hgss" and THEME.hgss.partyActionClosing then return end
      local action = THEME.style == "hgss" and THEME.hgss:partyActionAt(
        x * THEME.hgssScale, y * THEME.hgssScale, canSwap and 2 or 1)
      if y < HEADER and x < 24 then
        if THEME.style == "hgss" then
          THEME.hgss:endPartyAction(love.timer.getTime())
        else
          partyActionSlot = nil
        end
      elseif mon and (action == 1
          or THEME.style ~= "hgss" and inside(x, y, 14, 37, 132, 38)) then
        if THEME.style == "hgss" then
          hgssRuntime.beginAnimation("summary_open", {
            actionCount = canSwap and 2 or 1,
          })
        end
        partyActionSlot = nil
        if compat.isGen2() then
          mod.ui.push(game, compat.screenName("summary", true), {
            mon = mon, party = game.save.party, index = slot,
            onClose = function() game.stack:pop() end,
          })
        else
          mod.ui.push(game, compat.screenName("summary", false), mon)
        end
      elseif canSwap and (action == 2
          or THEME.style ~= "hgss" and inside(x, y, 14, 84, 132, 38)) then
        if THEME.style == "hgss" then
          hgssRuntime.beginAnimation("party_swap", {
            source = slot, actionCount = 2,
          })
        end
        partyActionSlot, partyMoveFrom = nil, slot
      end
      dirty = true
      return
    end
    if radarOpen then
      if y < HEADER and x < 24 then
        radarOpen = false
      else
        radarFrame, radarStarted = 0, love.timer.getTime()
      end
      dirty = true
      return
    end
    if fieldChoice then
      tapFieldChoice(x, y)
      return
    end
    if pendingFly then
      local yes, no = inside(x, y, 18, 91, 58, 27),
        inside(x, y, 84, 91, 58, 27)
      if THEME.style == "hgss" then
        local choice = THEME.hgss:toolPromptHit(x * THEME.hgssScale,
          y * THEME.hgssScale)
        yes, no = choice == true, choice == false
      end
      if yes then
        local target = pendingFly
        pendingFly = nil
        if canFly() then
          local ok, err = mod.world:flyTo(target.id)
          if not ok then mod.log:warn("fly rejected: %s", tostring(err)) end
        end
        dirty = true
      elseif no then
        pendingFly, dirty = nil, true
      end
      return
    end
    if pendingAction then
      if THEME.style == "hgss" then
        local choice = THEME.hgss:toolPromptHit(x * THEME.hgssScale,
          y * THEME.hgssScale)
        if choice ~= nil then
          local action = pendingAction
          pendingAction = nil
          if choice then useTool(action) else dirty = true end
        end
        return
      end
      if inside(x, y, 18, 91, 58, 27) then
        local action = pendingAction
        pendingAction = nil
        useTool(action)
      elseif inside(x, y, 84, 91, 58, 27) then
        pendingAction, dirty = nil, true
      end
      return
    end
    if displayRuntime.guideDetail then
      if y < HEADER and x < 22 then
        displayRuntime.guideDetail = nil
      elseif y < HEADER and displayRuntime.guideDetail.page then
        local guide, row = guideData()
        for _, candidate in ipairs(guide.rows) do
          if candidate.species == displayRuntime.guideDetail.species then
            row = candidate break
          end
        end
        if row and row.detailPages > 1 then
          local nextPage
          if x >= 22 and x < 48 then
            nextPage = carouselSubpage(
              displayRuntime.guideDetail.page, row.detailPages, -1)
          elseif x >= 80 and x < 106 then
            nextPage = carouselSubpage(
              displayRuntime.guideDetail.page, row.detailPages, 1)
          end
          if nextPage then displayRuntime.guideDetail.page = nextPage end
        end
      end
      dirty = true
      return
    end
    if THEME.style == "hgss" and page == "STEPS" then
      if y < HEADER and x < 22 then
        page, displayRuntime.home.activeApp = "HOME", nil
        dirty = true
      elseif THEME.hgss:stepsHit(x, y) == "reset" then
        steps = 0
        mod.save:set("steps", steps)
        dirty = true
        mod.log:info("step counter reset")
      end
      return
    end
    if trainerStepsOpen then
      if y < HEADER and x < 22 then
        trainerStepsOpen, dirty = false, true
      elseif inside(x, y, 34, 105, 92, 28) then
        steps = 0
        mod.save:set("steps", steps)
        dirty = true
        mod.log:info("step counter reset")
      end
      return
    end
    if THEME.style == "hgss" and displayRuntime.home.activeApp
        and y < HEADER and x < 22
        and not (page == "LOCAL" and (displayRuntime.explorer.selected
          or displayRuntime.explorer.view
          or displayRuntime.explorer.mapFull)) then
      page, displayRuntime.home.activeApp, dirty = "HOME", nil, true
      return
    end
    if y < HEADER and not partyMoveFrom then
      if THEME.style == "hgss" and page == "TOOLS" then
        local actions = displayRuntime.toolModels()
        local pages = math.max(1, math.ceil(#actions / 4))
        local action = THEME.hgss:toolsHit(x * THEME.hgssScale,
          y * THEME.hgssScale, { actions = actions, page = tools.page })
        if action == "prev" or action == "next" then
          local direction = action == "next" and 1 or -1
          tools.page = ((tools.page or 1) - 1 + direction) % pages + 1
          dirty = true
        end
        return
      end
      if x < 22 then changePage(-1)
      elseif x >= 74 and x < 96 then changePage(1) end
      if page == "TOOLS" and x >= 22 and x < 74 and #tools > 6 then
        local pages = math.ceil(#tools / 6)
        tools.page = (tools.page or 1) % pages + 1
        dirty = true
      end
      return
    end
    if page == "LOCAL" and THEME.style == "hgss" then
      local overview = loadLocalMap()
      if not overview then return end
      local model = displayRuntime.explorerModel(overview)
      local action, slot = THEME.hgss:explorerHit(x, y, model)
      if action == "wild" or action == "items" or action == "trainers" then
        displayRuntime.explorer.view = action
        displayRuntime.explorer.selected, displayRuntime.explorer.page,
          displayRuntime.explorer.detailPage = nil, 1, 1
      elseif action == "map_toggle" then
        displayRuntime.explorer.mapFull = not displayRuntime.explorer.mapFull
      elseif action == "zoom_out" or action == "zoom_in" then
        displayRuntime.adjustExplorerZoom(action == "zoom_in" and 1 or -1)
      elseif action == "next" or action == "prev" then
        local direction = action == "next" and 1 or -1
        displayRuntime.explorer.page = ((displayRuntime.explorer.page - 1
          + direction) % model.pages) + 1
        displayRuntime.explorer.selected = nil
      elseif action == "detail_next" or action == "detail_prev" then
        local direction = action == "detail_next" and 1 or -1
        displayRuntime.explorer.detailPage =
          ((displayRuntime.explorer.detailPage - 1 + direction)
            % model.detailPages) + 1
      elseif action == "wild_here" or action == "wild_route" then
        model.filters.wildScope = action == "wild_here" and "HERE" or "ROUTE"
        displayRuntime.explorer.page, displayRuntime.explorer.selected = 1, nil
      elseif action == "player_scan" then
        displayRuntime.explorer.scanFrame = 0
        displayRuntime.explorer.scanStarted = love.timer.getTime()
        displayRuntime.explorer.scanHintSeen = true
      elseif action == "marker" and model.markers[slot]
          and model.markers[slot].source then
        displayRuntime.explorer.view = model.markers[slot].kind == "trainer"
          and "trainers" or "items"
        displayRuntime.explorer.selected = model.markers[slot].source.key
        displayRuntime.explorer.detailPage = 1
        displayRuntime.explorer.mapFull = false
      elseif action == "row" and model.rows[slot] then
        displayRuntime.explorer.view = "wild"
        displayRuntime.explorer.selected = model.rows[slot].key
        displayRuntime.explorer.detailPage = 1
      end
      dirty = true
      return
    end
    if page == "LOCAL" and inside(x, y, 126, 18, 34, 30) then
      localMapZoom = localMapZoom % 3 + 1
      dirty = true
      return
    end
    if page == "MAP" and canFly() then
      local best, distance
      local targets = THEME.style == "hgss"
        and displayRuntime.regionMapTargets or flyTargets()
      for _, target in ipairs(targets or {}) do
        local d = (x - target.x) ^ 2 + (y - target.y) ^ 2
        if d <= 144 and (not distance or d < distance) then
          best, distance = target, d
        end
      end
      if best then pendingFly, dirty = best, true end
      return
    end
    if page == "GUIDE" and y >= 48 and y < 141 then
      local guide = guideData()
      local slot = math.floor((y - 48) / 31) + 1
      local row = guide.rows[(guidePage - 1) * 3 + slot]
      if row then
        displayRuntime.guideDetail, dirty = { species = row.species, page = 1 }, true
      end
      return
    elseif page == "AREA" and assist("item_radar") then
      local area = areaData()
      local screen = area.screens[math.max(1, math.min(areaPage, area.pages))]
      if screen.name == "HIDDEN" and hasItemfinder()
          and inside(x, y, 20, 118, 120, 20) then
        radarOpen, radarFrame, radarStarted = true, 0, love.timer.getTime()
        dirty = true
      end
      return
    elseif page == "TRAINER" and THEME.style ~= "hgss"
        and inside(x, y, 82, 109, 74, 29) then
      trainerStepsOpen = true
      dirty = true
    elseif page == "PARTY" then
      if partyMoveFrom and y < HEADER and x < 24 then
        partyMoveFrom, dirty = nil, true
        return
      end
      local party = game.save.party or {}
      local slot = THEME.style == "hgss"
        and THEME.hgss:partySlot(x, y, #party)
        or partySlotAt(x, y, #party)
      local mon = slot and party[slot]
      if mon and partyMoveFrom then
        local from = partyMoveFrom
        if THEME.style == "hgss" and from ~= slot then
          hgssRuntime.beginAnimation("party_swap_commit", {
            source = from, target = slot, party = partyData(),
            duration = 0.30,
          })
        end
        partyMoveFrom = nil
        local ok, err = mod.world:reorderParty(from, slot)
        if not ok then
          mod.log:warn("party reorder rejected: %s", tostring(err))
        end
        dirty = true
      elseif mon then
        partyActionSlot, dirty = slot, true
        if THEME.style == "hgss" then
          THEME.hgss:beginPartyAction(love.timer.getTime())
        end
      end
    elseif page == "TOOLS" then
      if THEME.style == "hgss" then
        local actions = displayRuntime.toolModels()
        local pages = math.max(1, math.ceil(#actions / 4))
        local action, index = THEME.hgss:toolsHit(x * THEME.hgssScale,
          y * THEME.hgssScale, { actions = actions, page = tools.page })
        if action == "prev" or action == "next" then
          local direction = action == "next" and 1 or -1
          tools.page = ((tools.page or 1) - 1 + direction) % pages + 1
          dirty = true
        elseif action == "action" then
          displayRuntime.activateTool(actions[index].action)
        end
        return
      end
      local first = ((tools.page or 1) - 1) * 6 + 1
      local count = math.min(6, #tools - first + 1)
      for slot = 1, count do
        local action = tools[first + slot - 1]
        local col, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
        if inside(x, y, 3 + col * 78, 25 + row * 38, 76, 34) then
          displayRuntime.activateTool(action)
          break
        end
      end
    end
  end

  displayRuntime.explorerSwipeTarget = function(view, selected, y, pages)
    if not view then return end
    if selected then return y >= 99 and "detail" or nil end
    if view == "wild" then
      return y >= 140 and ((pages or 1) > 1 and "page" or "scope") or nil
    end
  end
  assert(displayRuntime.explorerSwipeTarget("wild", false, 160, 1) == "scope"
      and displayRuntime.explorerSwipeTarget("wild", false, 160, 2) == "page"
      and not displayRuntime.explorerSwipeTarget("wild", false, 139)
      and displayRuntime.explorerSwipeTarget("wild", true, 99) == "detail",
    "Explorer horizontal swipe regions")

  local function swipe(dx, down)
    if THEME.style == "hgss" and not moveInfo then
      local summary = screenById("summary")
      if summary and game.stack:top() == summary
          and compat.summary.supports(summary, game) then
        press(dx < 0 and "right" or "left")
        dirty = true
        return
      end
    end
    if THEME.style == "hgss" and page == "TOOLS" then
      local pages = math.max(1, math.ceil(#displayRuntime.toolModels() / 4))
      if pages > 1 then
        local direction = dx < 0 and 1 or -1
        tools.page = ((tools.page or 1) - 1 + direction) % pages + 1
        dirty = true
      end
      return
    end
    if THEME.style == "hgss" and page == "POKEDEX" then
      displayRuntime.cyclePokedex(dx < 0 and 1 or -1)
      return
    end
    if THEME.style == "hgss" and page == "BAG" then
      if displayRuntime.bag.detail then return end
      local y = (down.y or 0) * THEME.hgssScale
      if y < 70 and displayRuntime.bagModel().pockets > 1 then
        displayRuntime.cycleBagPocket(dx < 0 and 1 or -1)
      else
        displayRuntime.cycleBagPage(dx < 0 and 1 or -1)
      end
      return
    end
    if THEME.style == "hgss" and page == "STORE" then
      local home, direction = displayRuntime.home, dx < 0 and 1 or -1
      local view = home.storeView
      local entries = view == "library" and displayRuntime.storeEntries(true)
        or view == "apps" and displayRuntime.storeEntries()
      local pages = entries and select(3,
        displayRuntime.storePage(view, entries)) or 1
      if not home.storeDetail and displayRuntime.storeSwipeTarget(view,
          (down.y or 0) * THEME.hgssScale, pages) then
        displayRuntime.cycleStorePage(view, direction)
        dirty = true
      else
        changePage(direction)
      end
      return
    end
    if THEME.style == "hgss" and page ~= "HOME"
        and page ~= "STORE" and page ~= "LOCAL" then return end
    if page ~= "LOCAL" or THEME.style ~= "hgss" then
      changePage(dx < 0 and 1 or -1)
      return
    end
    local overview = loadLocalMap()
    local model = overview and displayRuntime.explorerModel(overview)
    if model and not model.mapFull then
      local target = displayRuntime.explorerSwipeTarget(model.view,
        model.selected, (down.y or 0) * 1.5, model.pages)
      local direction = dx < 0 and 1 or -1
      if target == "scope" then
        model.filters.wildScope = direction > 0 and "ROUTE" or "HERE"
        displayRuntime.explorer.page, displayRuntime.explorer.selected = 1, nil
        dirty = true
      elseif target == "page" and model.pages > 1 then
        displayRuntime.explorer.page = ((displayRuntime.explorer.page - 1
          + direction) % model.pages) + 1
        displayRuntime.explorer.selected = nil
        dirty = true
      elseif target == "detail" and model.detailPages > 1 then
        displayRuntime.explorer.detailPage =
          ((displayRuntime.explorer.detailPage - 1 + direction)
            % model.detailPages) + 1
        dirty = true
      end
    end
  end

  local function swipeVertical(dy)
    if radarOpen then return end
    if page == "LOCAL" and THEME.style == "hgss" then return end
    if THEME.style ~= "hgss" and page == "TOOLS" and #tools > 6 then
      local pages = math.ceil(#tools / 6)
      local direction = dy < 0 and 1 or -1
      tools.page = ((tools.page or 1) - 1 + direction) % pages + 1
      dirty = true
      return
    end
    local top = game and game.stack and game.stack:top()
    local pcKind = pcSession() and pcListKind(top)
    if pcKind then
      local count, field = #(top.items or {}), "index"
      if pcKind == "gen2_box_change" then
        count, field = 14, "pickIndex"
      elseif pcKind:find("^gen2_box_") then
        local mons = (top.mode == "deposit" or top.boxIndex == 0)
          and (game.save.party or {})
          or ((game.save.boxes or {})[top.boxIndex or game.save.currentBox or 1]
            or {})
        count = #mons + 1
      elseif pcKind:find("^gen2_item_") then
        count, field = #(top.rows or {}) + 1, "listIndex"
      end
      if count > 4 then
        top[field] = pagedIndex(top[field], count, dy < 0 and 1 or -1)
        dirty = true
        return
      end
    end
    if not compat.isGen2() and screenContract(top, "bag")
        and #top.items > 4 then
      top.index = pagedIndex(top.index, #top.items, dy < 0 and 1 or -1)
      dirty = true
      return
    end
    local choice, labels, field = dialogueChoice()
    if choice and #labels > 4 then
      local _, cols = compat.choiceGrid(choice, field, #labels)
      local current = compat.choiceIndex(choice, field)
      local nextIndex
      if cols then
        nextIndex = math.max(1, math.min(#labels,
          current + (dy < 0 and cols or -cols)))
      else
        nextIndex = pagedIndex(current, #labels, dy < 0 and 1 or -1)
      end
      compat.choiceIndex(choice, field, nextIndex)
      if type(choice.clampScroll) == "function" then
        pcall(choice.clampScroll, choice)
      end
      dirty = true
      return
    end
  end

  function displayRuntime.updateHomeLongPress(now)
    local down = touchDown
    if not down or down.blockedUntilRelease or not down.homeTile
        or THEME.style ~= "hgss" or page ~= "HOME"
        or displayRuntime.home.editing then return false end
    local dx = ((down.currentX or down.x) - down.x) * THEME.hgssScale
    local dy = ((down.currentY or down.y) - down.y) * THEME.hgssScale
    if not displayRuntime.Home.longPress(now - down.at, dx, dy) then
      return false
    end
    displayRuntime.home.editing = true
    displayRuntime.home.swapSource = nil
    down.blockedUntilRelease = true
    dirty = true
    return true
  end

  local function touchEvent(value, sourceWidth, sourceHeight)
    local action, sx, sy = value:match("^(%a+),(%d+),(%d+)$")
    local x, y = tonumber(sx), tonumber(sy)
    if not action then
      sx, sy = value:match("^(%d+),(%d+)$")
      x, y, action = tonumber(sx), tonumber(sy), "tap"
    end
    if x and sourceWidth and sourceHeight then
      x = math.max(0, math.min(WIDTH - 1,
        math.floor(x * WIDTH / sourceWidth)))
      y = math.max(0, math.min(HEIGHT - 1,
        math.floor(y * HEIGHT / sourceHeight)))
    end
    if touchDown and touchDown.blockedUntilRelease then
      if action == "up" or action == "cancel" then
        touchDown = nil
        dirty = true
      end
      return
    end
    if action == "down" and x then
      textSpeedReleasePending = false
      holdTextSpeed(false)
      local mode, top = screenState()
      local speed = textTouch(top) == "speed"
      touchDown = { x = x, y = y,
        at = love.timer.getTime(),
        pageSwipe = pageSwipeAllowed(mode, battle)
          or THEME.style == "hgss" and not moveInfo
            and compat.isScreen(top, "summary"),
        textSpeed = speed,
        input = mode == "title" or mode == "active" or mode == "textbox" or battle
          or screenContract(top, "naming")
          or dialogueChoice() or compat.isScreen(top, "summary")
          or displayRuntime.moveLearnScreen()
          or pcSession() }
      if THEME.style == "hgss" and page == "HOME"
          and not displayRuntime.home.library then
        local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
        local tile = displayRuntime.homeTileAt(hx, hy)
        touchDown.homeTile = tile and tile.id
      end
      if speed then holdTextSpeed(true) end
      dirty = true
    elseif (action == "move" or action == "moved") and x and touchDown then
      touchDown.currentX, touchDown.currentY = x, y
    elseif action == "cancel" then
      textSpeedReleasePending = false
      holdTextSpeed(false)
      touchDown = nil
      dirty = true
    elseif action == "tap" and x then
      local mode, top = screenState()
      if textTouch(top) == "speed" then
        holdTextSpeed(true)
        textSpeedReleasePending = true
      else
        tap(x, y)
      end
    elseif action == "up" and x and touchDown then
      local down = touchDown
      local dx, dy = x - down.x, y - down.y
      touchDown = nil
      dirty = true
      if down.textSpeed then
        textSpeedReleasePending = true
        return
      end
      if math.abs(dx) >= 24 and math.abs(dx) > math.abs(dy) * 1.25 then
        if down.pageSwipe then swipe(dx, down) end
      elseif math.abs(dy) >= 24 and math.abs(dy) > math.abs(dx) * 1.25 then
        swipeVertical(dy)
      elseif dialogueChoice() and (math.abs(dx) >= 12 or math.abs(dy) >= 12) then
        return
      elseif down.input then
        tap(x, y)
      end
      mod.log:info("touch up x=%d y=%d", x, y)
    end
  end

  local function resetSwapState()
    displayReady = false
    primaryBottomRect = nil
    nextGameCapture = 0
    nextPresentAttempt = 0
    touchDown = nil
    textSpeedReleasePending = false
    holdTextSpeed(false)
    dirty = true
  end

  mod.events:on("game.ready", function(payload)
    game = payload.game
    spriteCache.__badges = nil
    spriteCache.__gen2Badges = nil
    spriteCache.__caughtBall = nil
    displayRuntime.pokedex.data = nil
    displayRuntime.loadHome()
    refreshTheme(true)
    reloadSteps()
    local player = game.save and game.save.player
    mapId = player and player.map
    if not mapId and mod.world and mod.world.current then
      local position = mod.world:current()
      mapId = position and position.mapId
    end
    local voxel = mod.find("DRAMATIC_SHAPE")
    if voxel and voxel.exports.isLoading then
      externalLoading = voxel.exports.isLoading() == true
    end
    active, dirty = true, true
    mod.log:info("ready")
  end)

  function displayRuntime.reloadSavedUi()
    displayRuntime.pokedex.data = nil
    reloadSteps()
    displayRuntime.loadHome()
  end
  mod.events:on("save.created", displayRuntime.reloadSavedUi)
  mod.events:on("save.loaded", displayRuntime.reloadSavedUi)

  mod.events:on("map.entered", function(payload)
    mapId, pendingFly, pendingAction, fieldChoice, dirty =
      payload.mapId, nil, nil, nil, true
    invalidateLocalMap()
    displayRuntime.pokedex.data = nil
    guidePage, displayRuntime.guideDetail, areaPage = 1, nil, 1
    radarOpen = false
  end)

  mod.events:on("pokemon.caught", function()
    displayRuntime.pokedex.data = nil
    dirty = true
  end)

  mod.events:on("mod.DRAMATIC_SHAPE.loading_changed", function(payload)
    externalLoading = payload and payload.loading == true
    dirty = true
  end)

  mod.events:on("mod.options_changed", function(payload)
    if payload and payload.mod == "kanto_gear" then
      if payload.key == "theme" then refreshTheme(true) end
      if payload.key == "display_mode"
          or payload.key == "fullscreen_start"
          or payload.key == "combined_layout"
          or payload.key == "combined_primary"
          or payload.key == "secondary_size"
          or payload.key == "overlay_corner"
          or payload.key == "overlay_button"
          or payload.key == "display_target"
          or (payload.key == "screen_swap"
            and mod.options:get("screen_swap") ~= true) then
        displayRuntime.swapped = nil
        displayRuntime.overlayHidden = false
        resetSwapState()
      end
      if not assist("move_details")
          or (payload.key == "battle_view"
            and currentBattleUIMode() == "info") then moveInfo = nil end
      if payload.key == "battle_view" then battleInfoDetail = nil end
      if page == "GUIDE" and not assist("guide") then
        page, displayRuntime.guideDetail = "MAP", nil
      end
      if page == "AREA" and not assist("area") then page = "MAP" end
      if page == "LOCAL" and THEME.style == "hgss"
          and (displayRuntime.explorer.view == "wild" and not assist("guide")
            or (displayRuntime.explorer.view == "items"
                or displayRuntime.explorer.view == "trainers")
              and not assist("area")) then
        displayRuntime.explorer.view, displayRuntime.explorer.selected = nil, nil
      end
      if page == "LOCAL"
          and localMapMode(mod.options:get("local_map")) == "off" then
        page, displayRuntime.explorer.view,
          displayRuntime.explorer.selected = "MAP", nil, nil
      end
      if not assist("item_radar") then radarOpen = false end
      displayRuntime.explorer.data = nil
      dirty = true
    end
  end)

  function hgssRuntime.remapBattleRootInput(stepGame)
    if stepGame ~= game or THEME.style ~= "hgss"
        or not battle then return end
    local raw = battleState()
    local top = game.stack:top()
    local queue = stepGame and stepGame.input and stepGame.input.pressQueue
    if not raw or type(queue) ~= "table"
        or not bottomOwnsBattleUI(hideUpperBattleUI(), active,
          hasDisplay(), displayReady, raw, battle) then return end
    local party = screenContract(top, "party")
    if party and party.submenu then
      local actions, submenu = hgssRuntime.partySubmenuActions(party)
      if #actions < 2 then return end
      local current = party.subIndex or (submenu and submenu.index)
        or actions[1].index
      for i = 1, #queue do
        local target = queue[i] == "up" and actions[1]
          or queue[i] == "down" and actions[2] or nil
        if target then
          table.remove(queue, i)
          if submenu then submenu.index = target.index
          else party.subIndex = target.index end
          dirty = true
          return true
        end
      end
      return
    end
    if battle.prompt ~= "menu" or top ~= raw then return end
    for i = 1, #queue do
      local target = hgssRuntime.rootDirection(
        raw.menuIndex or battle.menuIndex or 1, queue[i])
      if target then
        table.remove(queue, i)
        raw.menuIndex, battle.menuIndex = target, target
        dirty = true
        return true
      end
    end
  end

  function hgssRuntime.remapSummaryMovesInput(stepGame)
    if stepGame ~= game or THEME.style ~= "hgss" or not battle
        or not assist("move_details") then return end
    local summary = screenById("summary")
    local raw, top = battleState(), game.stack:top()
    local queue = stepGame and stepGame.input and stepGame.input.pressQueue
    if not raw or top ~= summary or tonumber(summary and summary.page) ~= 2
        or type(queue) ~= "table" or not compat.summary.supports(summary, game)
        or not (active and hasDisplay() and displayReady) then return end
    local view = compat.summary.view(summary, game)
    local moves = view and view.mon and view.mon.moves or {}
    local current = tonumber(summary.moveIndex) or 1
    for i = 1, #queue do
      local direction = queue[i] == "up" and -1
        or queue[i] == "down" and 1 or nil
      if direction then
        for offset = 1, 4 do
          local target = (current - 1 + direction * offset) % 4 + 1
          if moves[target] and moves[target].id then
            summary.moveIndex = target
            table.remove(queue, i)
            dirty = true
            return true
          end
        end
      elseif queue[i] == "a" then
        local selected = hgssRuntime.summaryMove(summary, current)
        if selected then
          summary.moveIndex = current
          moveInfo = selected
          table.remove(queue, i)
          dirty = true
          return true
        end
      end
    end
  end

  function hgssRuntime.openingBattlePanel(stepGame)
    if stepGame ~= game or THEME.style ~= "hgss"
        or not battle or battle.prompt ~= "menu" then return false end
    local raw = battleState()
    local queue = stepGame and stepGame.input and stepGame.input.pressQueue
    if not raw or game.stack:top() ~= raw or type(queue) ~= "table"
        or not bottomOwnsBattleUI(hideUpperBattleUI(), active,
          hasDisplay(), displayReady, raw, battle) then return false end
    local index = raw.menuIndex or battle.menuIndex or 1
    local kind = index == 1 and "battle_moves"
      or index == 2 and "battle_party"
      or index == 3 and "battle_bag" or nil
    if not kind then return false end
    for i = 1, #queue do
      if queue[i] == "a" then return kind end
    end
    return false
  end

  function hgssRuntime.closingBattlePanel(stepGame)
    if stepGame ~= game or THEME.style ~= "hgss" or not battle then return end
    local raw, top = battleState(), game.stack:top()
    local queue = stepGame and stepGame.input and stepGame.input.pressQueue
    if not raw or type(queue) ~= "table"
        or not bottomOwnsBattleUI(hideUpperBattleUI(), active,
          hasDisplay(), displayReady, raw, battle) then return end
    local kind
    if compat.battleBagMenu(top) then kind = "battle_bag_close"
    else
      local party = screenContract(top, "party")
      if party and not party.submenu then kind = "battle_party_close"
      elseif top == raw and battle.prompt == "moves" then
        kind = "battle_moves_close"
      end
    end
    if not kind then return end
    for i = 1, #queue do
      if queue[i] == "b" then return kind end
    end
  end

  mod.hooks:wrap("input.step", function(next, stepGame, dt)
    local top = game and game.stack and game.stack:top()
    local queue = stepGame and stepGame.input and stepGame.input.pressQueue
    if stepGame == game and battle and compat.battleBagMenu(top)
        and bottomOwnsBattleUI(hideUpperBattleUI(), active,
          hasDisplay(), displayReady, battleState(), battle)
        and compat.useBattleBagItemDirectly(top, queue) then dirty = true end
    hgssRuntime.remapBattleRootInput(stepGame)
    hgssRuntime.remapSummaryMovesInput(stepGame)
    local modalMoveInfo = moveInfo ~= nil
    if modalMoveInfo or battleInfoDetail or displayRuntime.guideDetail then
      local queue = stepGame and stepGame.input
        and stepGame.input.pressQueue
      local consumed
      for i = #(queue or {}), 1, -1 do
        if queue[i] == "b" then consumed = true end
        if modalMoveInfo or queue[i] == "b" then
          table.remove(queue, i)
        end
      end
      if consumed then back() end
      if modalMoveInfo then return next(stepGame, dt) end
    end
    local openingPanel = hgssRuntime.openingBattlePanel(stepGame)
    local closingPanel = hgssRuntime.closingBattlePanel(stepGame)
    pollTriggerTabs()
    local swapPressed, infoPressed, overlayPressed = pollScreenSwap()
    if infoPressed and assist("move_details")
        and currentBattleUIMode() ~= "info" then
      moveInfo = displayRuntime.learningMoveInfo()
      if not moveInfo and battle and battle.prompt == "moves" then
        local raw = battleState()
        local index = raw and raw.moveIndex or battle.moveIndex or 1
        moveInfo = battle.moves and battle.moves[index]
      end
      if not moveInfo and battle then
        local summary = screenById("summary")
        if summary and game.stack:top() == summary
            and tonumber(summary.page) == 2
            and compat.summary.supports(summary, game) then
          moveInfo = hgssRuntime.summaryMove(summary,
            summary.moveIndex or 1)
        end
      end
      if moveInfo and battle and battle.prompt == "moves" then
        hgssRuntime.beginAnimation("battle_move_info")
      end
      dirty = moveInfo ~= nil or dirty
    end
    if active and (inlineDisplay() or hasDisplay()) and swapPressed then
      displayRuntime.swapped = not displayRuntime.swapped
      resetSwapState()
      mod.log:info("screen swap: gear=%s", inlineDisplay()
        and (THEME:gearPrimary(mod.options, displayRuntime.swapped)
            and "primary" or "secondary")
          or (bottomOnHandheld() and "handheld" or "external"))
    end
    if active and inlineDisplay() and overlayPressed then
      displayRuntime.overlayHidden = not displayRuntime.overlayHidden
      resetSwapState()
      mod.log:info("overlay %s",
        displayRuntime.overlayHidden and "hidden" or "shown")
    end
    if closingPanel then hgssRuntime.beginAnimation(closingPanel) end
    local result = next(stepGame, dt)
    if openingPanel then
      hgssRuntime.beginAnimation(openingPanel,
        openingPanel == "battle_party" and { duration = 0.42 } or nil)
    end
    return result
  end, 1000)

  mod.hooks:wrap("render.viewport", function(next, context)
    local available = next(context)
    THEME.nativeWindowLayout = nil
    if not (active and inlineDisplay() and context) then return available end
    local base = type(available) == "table" and available or {
      x = 0, y = 0, width = context.width, height = context.height,
    }
    local layout = THEME:windowLayout(THEME:windowMode(mod.options),
      base.width, base.height,
      THEME:gearPrimary(mod.options, displayRuntime.swapped),
      mod.options:get("overlay_corner"), displayRuntime.overlayHidden,
      mod.options:get("secondary_size"))
    if not layout then return available end
    for _, rect in ipairs({ layout.game, layout.gear }) do
      rect.x = rect.x + (base.x or 0)
      rect.y = rect.y + (base.y or 0)
    end
    THEME.nativeWindowLayout = layout
    return {
      x = layout.game.x, y = layout.game.y,
      width = layout.game.w, height = layout.game.h,
      capture = layout.showGear,
    }
  end, 1000)

  mod.hooks:wrap("render.output_enabled", function(next)
    if active and inlineDisplay() then
      return not THEME.nativeWindowLayout
    end
    if active and bottomOnHandheld() and hasDisplay() then return true end
    return next()
  end, 1000)

  mod.hooks:wrap("render.output", function(next, context)
    if active and inlineDisplay() and not THEME.nativeWindowLayout
        and context and context.canvas then
      if next(context) == true then
        primaryBottomRect = nil
        displayReady = false
        return true
      end
      local fallbackWidth, fallbackHeight = G.getDimensions()
      local ww = math.max(1, context.width or fallbackWidth)
      local wh = math.max(1, context.height or fallbackHeight)
      local layout = THEME:windowLayout(THEME:windowMode(mod.options), ww, wh,
        THEME:gearPrimary(mod.options, displayRuntime.swapped),
        mod.options:get("overlay_corner"), displayRuntime.overlayHidden,
        mod.options:get("secondary_size"))
      if not layout then return false end
      if layout.showGear and dirty then draw(); dirty = false end
      G.push("all")
      G.setCanvas()
      G.origin()
      G.setScissor()
      G.setShader()
      G.setBlendMode("alpha")
      G.clear(0, 0, 0, 1)
      G.setColor(1, 1, 1, 1)
      if layout.gameOnTop then
        primaryBottomRect = THEME:drawCanvas(canvas, layout.gear)
        THEME:drawCanvas(context.canvas, layout.game)
      else
        if layout.showGame then THEME:drawCanvas(context.canvas, layout.game) end
        primaryBottomRect = layout.showGear
          and THEME:drawCanvas(canvas, layout.gear) or nil
      end
      G.setScissor()
      G.pop()
      displayReady = layout.showGear
      return true
    end
    if active and inlineDisplay() then return next(context) end
    if not (active and bottomOnHandheld() and hasDisplay()
        and context and context.canvas) then
      primaryBottomRect = nil
      return next(context)
    end

    local now = love.timer.getTime()
    if gameReadbackPending and gameReadbackCanvas
        and now >= nextPresentAttempt then
      local image = gameReadbackCanvas:pollImageData()
      if image then
        local shown = companion.push(image, image:getWidth(), image:getHeight(),
          SECONDARY_BACKGROUND, "secondary:cover")
        gameReadbackPending = false
        gameReadbackCanvas = nil
        if shown == true and not displayReady then
          mod.log:info("screen swap: game frame submitted")
        end
        displayReady = shown == true
        if not displayReady then nextPresentAttempt = now + 0.25 end
      end
    end

    if not gameReadbackPending and now >= nextGameCapture then
      local ww = math.max(1, context.width or G.getWidth())
      local wh = math.max(1, context.height or G.getHeight())
      local captureScale = math.min(960 / ww, 540 / wh)
      local cw = math.max(1, math.floor(ww * captureScale + 0.5))
      local ch = math.max(1, math.floor(wh * captureScale + 0.5))
      if not gameCaptureCanvas or gameCaptureCanvas:getWidth() ~= cw
          or gameCaptureCanvas:getHeight() ~= ch then
        gameCaptureCanvas = G.newCanvas(cw, ch, { dpiscale = 1 })
        gameCaptureCanvas:setFilter("linear", "linear")
      end
      G.push("all")
      G.setCanvas(gameCaptureCanvas)
      G.origin()
      G.setScissor()
      G.setShader()
      G.setBlendMode("alpha")
      G.clear(0, 0, 0, 1)
      G.setColor(1, 1, 1, 1)
      G.draw(context.canvas, 0, 0, 0, cw / ww, ch / wh)
      G.pop()
      if gameCaptureCanvas.requestImageData
          and gameCaptureCanvas.pollImageData
          and gameCaptureCanvas:requestImageData() then
        gameReadbackPending = true
        gameReadbackCanvas = gameCaptureCanvas
        nextGameCapture = now + 1 / 60
      elseif gameCaptureCanvas.newImageData then
        local ok, image = pcall(gameCaptureCanvas.newImageData,
          gameCaptureCanvas)
        if ok and image then
          local shown = companion.push(image, image:getWidth(), image:getHeight(),
            SECONDARY_BACKGROUND, "secondary:cover")
          displayReady = shown == true
          if not displayReady then nextPresentAttempt = now + 0.25 end
        end
        nextGameCapture = now + 1 / 60
      end
    end

    if dirty then draw(); dirty = false end
    local ww = math.max(1, context.width or G.getWidth())
    local wh = math.max(1, context.height or G.getHeight())
    local scale = math.min(ww / canvas:getWidth(), wh / canvas:getHeight())
    local dw, dh = canvas:getWidth() * scale, canvas:getHeight() * scale
    local dx, dy = math.floor((ww - dw) / 2), math.floor((wh - dh) / 2)
    primaryBottomRect = { x = dx, y = dy, w = dw, h = dh }

    G.push("all")
    G.setCanvas()
    G.origin()
    G.setScissor()
    G.setShader()
    G.setBlendMode("alpha")
    G.clear(PAPER[1], PAPER[2], PAPER[3], 1)
    G.setColor(1, 1, 1, 1)
    G.draw(canvas, dx, dy, 0, scale, scale)
    G.pop()
    displayReady = true
    return true
  end, 1000)

  mod.hooks:wrap("render.window", function(next, windowGame, context)
    if not (active and inlineDisplay() and THEME.nativeWindowLayout
        and context and context.canvas) then
      return next(windowGame, context)
    end
    if THEME.nativeWindowLayout.showGame then next(windowGame, context) end
    if not THEME.nativeWindowLayout.showGear then
      primaryBottomRect = nil
      displayReady = false
      return true
    end
    if dirty then draw(); dirty = false end
    G.push("all")
    G.origin()
    G.setCanvas()
    G.setScissor()
    G.setShader()
    G.setBlendMode("alpha")
    G.setColor(1, 1, 1, 1)
    primaryBottomRect = THEME:drawCanvas(canvas, THEME.nativeWindowLayout.gear)
    if THEME.nativeWindowLayout.gameOnTop then
      THEME:drawCanvas(context.canvas, THEME.nativeWindowLayout.game)
    end
    G.setScissor()
    G.pop()
    displayReady = true
    return true
  end, 1000)

  local function primaryTouch(action, x, y)
    local inline = inlineDisplay()
    if not (active and hasDisplay()
        and (inline or bottomOnHandheld())) then return false end
    local layout = THEME.nativeWindowLayout
    if inline and layout and layout.gameOnTop then
      local gameRect = layout.game
      if x >= gameRect.x and x < gameRect.x + gameRect.w
          and y >= gameRect.y and y < gameRect.y + gameRect.h then
        touchDown = nil
        return false
      end
    end
    local rect = primaryBottomRect
    if not rect then return not inline end
    local insideRect = x >= rect.x and x < rect.x + rect.w
      and y >= rect.y and y < rect.y + rect.h
    if action == "down" and not insideRect then
      touchDown = nil
      return not inline
    end
    if inline and action ~= "down" and not touchDown then return false end
    local tx = math.max(0, math.min(WIDTH - 1,
      math.floor((x - rect.x) * WIDTH / rect.w)))
    local ty = math.max(0, math.min(HEIGHT - 1,
      math.floor((y - rect.y) * HEIGHT / rect.h)))
    if action == "down" or action == "up" or action == "move"
        or action == "cancel" then
      touchEvent(string.format("%s,%d,%d", action, tx, ty))
    end
    return true
  end

  mod.hooks:wrap("input.pointer", function(next, pointerGame, event)
    local action = ({ pressed = "down", released = "up", moved = "move",
                      cancelled = "cancel" })[event.phase]
    if action and primaryTouch(action, event.x, event.y) then return true end
    if event.phase == "moved" and active and hasDisplay()
        and ((inlineDisplay() and touchDown) or (not inlineDisplay()
          and bottomOnHandheld())) then return true end
    return next(pointerGame, event)
  end, 1000)

  mod.events:on("world.stepped", function(payload)
    steps = steps + 1
    mod.save:set("steps", steps)
    mapId = payload.mapId or mapId
    if radarOpen then radarOpen, dirty = false, true end
    if page == "TRAINER" or page == "STEPS" or page == "HOME"
        or page == "LOCAL" then dirty = true end
  end)

  for _, event in ipairs({ "world.block_replaced", "map.reloaded", "screen.pushed" }) do
    mod.events:on(event, function(payload)
      if not payload or not payload.mapId or payload.mapId == mapId then
        invalidateLocalMap()
        dirty = true
      end
    end)
  end

  mod.hooks:wrap("battle.bottom_ui_visible", function(next, state)
    if next(state) == false then return false end
    local raw = battleState()
    local top = game and game.stack and game.stack:top()
    local owned = bottomOwnsBattleUI(
      hideUpperBattleUI(), active,
      hasDisplay(), displayReady, raw, battle)
    return not (owned
      and (state == raw or (state == top and top.isTextBox)))
  end)

  mod.hooks:wrap("battle.move_grid_navigation", function(next, state)
    if next(state) == true then return true end
    return companionMoveGrid(state)
  end)

  mod.hooks:wrap("ui.party.grid_navigation", function(next, state)
    if next(state) == true then return true end
    return screenContract(state, "party") ~= nil and bottomOwnsBattleUI(
      hideUpperBattleUI(), active,
      hasDisplay(), displayReady, battleState(), battle)
  end)

  mod.hooks:wrap("battle.status_hud_visible", function(next, state)
    if next(state) == false then return false end
    return not bottomOwnsBattleUI(
      fullBottomBattleUI(), active, hasDisplay(),
      displayReady, state, battle)
  end)

  mod.hooks:wrap("battle.caught_marker_visible", function(next, state)
    if mod.options:get("caught_icon") ~= false and active then return true end
    return next(state)
  end)

  mod.hooks:wrap("screen.render_visible", function(next, state)
    if next(state) == false then return false end
    if compat.isScreen(state, "summary")
        and compat.summary.supports(state, game) then
      return not (active and hasDisplay() and displayReady
        and battleState() ~= nil and battle ~= nil)
    end
    local owned = bottomOwnsBattleUI(
      hideUpperBattleUI(), active,
      hasDisplay(), displayReady, battleState(), battle)
    return not (owned and screenContract(state))
  end)

  mod.events:on("battle.ended", function(payload)
    dirty = true
    battleInfoDetail = nil
    local state = payload and payload.battle
    local result = payload and payload.result
    if mapId == "OAKS_LAB" and state and state.oppClass == "OPP_RIVAL1"
        and (result == "win" or result == "lose") then
      mod.save:set("oak_lab_rival_result", result)
    end
  end)

  mod.events:on("screen.popped", function(payload)
    if compat.isBattleScreen(payload and payload.state) then
      battle = nil
      moveInfo = nil
      battleInfoDetail = nil
      dirty = true
    elseif payload and payload.state
        and (payload.state.screenId == "MoveLearnMenu"
          or payload.state.screenId == "Gen2MoveDeleter") then
      moveInfo = nil
      dirty = true
    end
  end)

  for _, event in ipairs({
    "battle.started", "battle.turn_started", "battle.move_used",
    "battle.damage_dealt", "battle.status_inflicted",
    "battle.battler_switched", "battle.turn_ended",
    "pokemon.caught",
  }) do
    mod.events:on(event, function() dirty = true end)
  end

  -- Upstream owns the display seam; this mod only supplies its companion frame.
  mod.hooks:wrap("render.compose", function(next, renderer, context)
    local inline = inlineDisplay()
    companion = context and context.secondScreen
    if companion and companion.setEnabled then
      companion.setEnabled(active and not inline)
    end
    -- The captured game frame is wider than some lower displays. Keep dynamic
    -- UI inside the central Game Boy viewport while that frame is cover-cropped;
    -- beginFrame rebuilds anchors on the next normal frame.
    if active and not inline and bottomOnHandheld()
        and hasDisplay() and renderer then
      renderer.uiAnchors = nil
    end
    local handled = next(renderer, context)
    if textSpeedReleasePending then
      textSpeedReleasePending = false
      holdTextSpeed(false)
    end
    if not inline and (not companion or not companion.detected
        or not companion.pollTouch) then
      if not bridgeWarned then
        bridgeWarned = true
        mod.log:warn("host SecondScreen bridge has no companion touch support")
      end
      return handled
    end
    if not active then return handled end
    if not loggedTick then
      loggedTick = true
      mod.log:info("display available=%s", tostring(hasDisplay()))
    end

    local now = love.timer.getTime()
    displayRuntime.updateHomeLongPress(now)
    if now >= nextPoll then
      nextPoll = now + 0.05
      refreshTheme()
      if not inline then
        for _ = 1, 32 do
          local event = companion.pollTouch()
          if not event then break end
          if not bottomOnHandheld() then
            touchEvent(event, canvas:getWidth(), canvas:getHeight())
          end
        end
      end
      refreshBattle()
      if page == "TOOLS" or page == "HOME" or pendingAction then refreshTools() end
      local mode, top = screenState()
      local currentSummary = compat.isScreen(top, "summary")
        and compat.summary.supports(top, game) and top or nil
      if THEME.style == "hgss" and currentSummary and not battle then
        local currentPage = tonumber(currentSummary.page) or 1
        if hgssRuntime.summaryState == currentSummary
            and hgssRuntime.summaryPage
            and hgssRuntime.summaryPage ~= currentPage then
          hgssRuntime.beginAnimation("summary_page", {
            from = hgssRuntime.summaryPage, to = currentPage,
          })
        end
        hgssRuntime.summaryState, hgssRuntime.summaryPage =
          currentSummary, currentPage
      else
        hgssRuntime.summaryState, hgssRuntime.summaryPage = nil, nil
      end
      if partyMoveFrom and (page ~= "PARTY" or not mod.world
          or not mod.world.canReorderParty or not mod.world:canReorderParty()) then
        partyMoveFrom, dirty = nil, true
      end
      if partyActionSlot and (page ~= "PARTY" or mode ~= "active"
          or not (game.save.party or {})[partyActionSlot]) then
        partyActionSlot, dirty = nil, true
      end
      if partyActionSlot and THEME.style == "hgss"
          and THEME.hgss:partyActionClosed(now) then
        partyActionSlot, dirty = nil, true
      end
      if displayRuntime.bag.pending and mode == "active" then
        displayRuntime.bag.pending, dirty = nil, true
      end
      local learn = displayRuntime.moveLearnScreen()
      local currentPcList = pcList()
      local currentChoice, _, currentChoiceField = dialogueChoice()
      if trackChoice(currentChoice, now) then dirty = true end
      if choiceNudgeUntil > 0 and now >= choiceNudgeUntil then
        choiceNudgeUntil = 0
        dirty = true
      end
      if radarOpen and radarFrame < RADAR_FRAMES then
        local frame = math.min(RADAR_FRAMES,
          math.floor(math.max(0, now - radarStarted) / 0.05))
        if frame ~= radarFrame then radarFrame, dirty = frame, true end
      end
      local explorer = displayRuntime.explorer
      if explorer.scanFrame and explorer.scanFrame < RADAR_FRAMES then
        local frame = math.min(RADAR_FRAMES,
          math.floor(math.max(0, now - explorer.scanStarted) / 0.05))
        if frame ~= explorer.scanFrame then
          explorer.scanFrame, dirty = frame, true
        end
      end
      local screenKey = table.concat({ mode, tostring(top),
        tostring(page), tostring(guidePage), tostring(areaPage),
         tostring(displayRuntime.explorer.view),
         tostring(displayRuntime.explorer.selected),
         tostring(displayRuntime.explorer.page),
         tostring(displayRuntime.explorer.detailPage),
         tostring(displayRuntime.explorer.mapFull),
         tostring(displayRuntime.explorer.mapZoom),
        tostring(displayRuntime.explorer.filters.wildScope),
        tostring(displayRuntime.explorer.scanFrame),
        tostring(displayRuntime.pokedex.view),
        tostring(displayRuntime.pokedex.selected),
        tostring(displayRuntime.pokedex.page),
        tostring(displayRuntime.pokedex.habitatPage),
        tostring(displayRuntime.pokedex.movePage),
        tostring(radarOpen),
         tostring(top and top.waiting), tostring(top and top.done),
         tostring(top and top.index), tostring(top and top.kind),
         tostring(currentChoice and compat.choiceIndex(
           currentChoice, currentChoiceField)),
         tostring(top and top.row), tostring(top and top.col), tostring(top and top.lower),
         tostring(top and type(top.glyphs) == "table"
           and table.concat(top.glyphs)),
         tostring(top and top.qty), tostring(top and top.page),
         tostring(top and top.moveDetail), tostring(top and top.moveIndex),
         tostring(top and top.mon),
        tostring(currentPcList), displayRuntime.pcStateKey(currentPcList),
        displayRuntime.pcStateKey(top),
        tostring(learn and learn.selecting),
        tostring(learn and learn.index), tostring(externalLoading),
        tostring(displayRuntime.bag.pending
          and displayRuntime.bag.pending.itemId),
        tostring(displayRuntime.bag.pending
          and displayRuntime.bag.pending.mon),
        tostring(pendingFly and pendingFly.id),
        tostring(pendingAction and pendingAction.id),
        tostring(partyActionSlot), tostring(partyMoveFrom),
        tostring(trainerStepsOpen), tostring(battleInfoDetail),
        tostring(displayRuntime.guideDetail
          and displayRuntime.guideDetail.species),
        tostring(displayRuntime.guideDetail and displayRuntime.guideDetail.page),
        tostring(game.world and (game.world.tod or game.world.daytime)),
        tostring(fieldChoice and fieldChoice.kind),
        tostring(fieldChoice and fieldChoice.source
          and fieldChoice.source.slot) }, ":")
      if THEME.style == "hgss" and battle and battle.prompt == "advance" then
        screenKey = screenKey .. ":" .. math.floor(now * 4)
      end
      if page == "LOCAL" and mod.world and mod.world.current then
        local pos = mod.world:current()
        screenKey = screenKey .. ":" .. tostring(pos and pos.x)
          .. ":" .. tostring(pos and pos.y)
          .. ":" .. tostring(pos and pos.facing)
      end
      if screenKey ~= lastScreenKey or mode == "transition" then
        lastScreenKey, dirty = screenKey, true
      end
    end
    if THEME.style == "hgss"
        and THEME.hgss:partyActionAnimating(now) then dirty = true end
    if hgssRuntime.animation then
      local started = hgssRuntime.animation.started
      local queued = hgssRuntime.animation.queued or now
      if started and now - started < hgssRuntime.animation.duration
          or not started and now - queued
            < hgssRuntime.animation.duration + 0.5 then
        dirty = true
      else
        hgssRuntime.animation, dirty = nil, true
      end
    end
    if displayRuntime.motion.started then dirty = true end
    if now >= nextClock then
      local title = screenState() == "title"
      nextClock = now + (title and 0.5
        or batteryAnimated and 1 or 5)
      dirty = true
    end
    local displayAvailable = hasDisplay()
    if not displayAvailable then
      if not inline and displayRuntime.swapped ~= nil then
        displayRuntime.swapped = nil
        resetSwapState()
        mod.log:info("screen disconnected: restored saved layout")
      end
      if gameReadbackPending and gameReadbackCanvas
          and gameReadbackCanvas:pollImageData() then
        gameReadbackPending = false
        gameReadbackCanvas = nil
      end
      displayReady = false
      touchDown = nil
      textSpeedReleasePending = false
      holdTextSpeed(false)
    end
    if displayAvailable and not displayReady then dirty = true end
    if not inline and bottomOnHandheld() then
      if dirty or readbackPending then pumpDisplay() end
    elseif not inline and (dirty or readbackPending)
        and (readbackPending or displayAvailable
        or now >= nextPresentAttempt) then
      local shown = pumpDisplay()
      if shown and not loggedPresent then
        loggedPresent = true
        mod.log:info("first frame submitted=true")
      end
    end
    return handled
  end, -1000)
end
