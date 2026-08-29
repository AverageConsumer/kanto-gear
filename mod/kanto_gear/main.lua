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

local function usePalette(palette)
  palette = validPalette(palette) and palette or THEME.classic
  PAPER, MID, DARK, INK = rgba(palette[1]), rgba(palette[2]),
                           rgba(palette[3]), rgba(palette[4])
  SECONDARY_BACKGROUND = rgb24(fillerColor(palette))
end

usePalette(THEME.classic)
assert(validPalette(THEME.classic)
       and validPalette(THEME.light)
       and validPalette(THEME.dark)
       and inverted(THEME.classic)[1] == THEME.classic[4]
       and fillerColor({ { 255, 255, 255 }, { 200, 100, 100 },
                         { 120, 20, 80 }, { 0, 0, 0 } })[1] == 120
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
  return textTouch(top) == "advance" and "TAP TO CONTINUE" or nil
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
  if state.screenId == "Gen2BoxMenu" and not state.phase
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

function Area.itemfinderNear(px, py, x, y)
  local function near(origin, value, high)
    return value > math.max(origin - 5, 0) and value <= origin + high
  end
  return near(px, x, 5) and near(py, y, 4)
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

function Area.gen2Rows(data, save, world, mapIds)
  local rows = { {}, {}, {} }
  for _, mapId in ipairs(mapIds) do
    local map = data and data.gen2Maps and data.gen2Maps[mapId]
    for _, obj in ipairs(map and map.objects or {}) do
      if obj.trainer then
        rows[1][#rows[1] + 1] = {
          label = gen2TrainerName(data, save, obj.trainer),
          done = gen2FlagSet(world, obj.trainer.event),
        }
      elseif obj.itemball and obj.itemball.item ~= 0 then
        rows[2][#rows[2] + 1] = {
          label = gen2ItemName(data, obj.itemball.item),
          done = gen2FlagSet(world, obj.eventFlag),
        }
      end
    end
    for _, hidden in ipairs(Area.gen2Hidden(data, world, mapId)) do
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
  local flags = { [11] = true, [13] = true }
  local data = {
    items = {
      POTION = { index = 7, name = "POTION" },
      BERRY = { index = 8, name = "BERRY" },
    },
    gen2Trainers = { classes = { YOUNGSTER = {
      index = 3, name = "YOUNGSTER",
      trainers = { [2] = { name = "JOEY" } },
    } } },
    gen2Maps = { TEST = {
      objects = {
        { trainer = { class = 3, member = 2, event = 11 } },
        { eventFlag = 12, itemball = { item = 7 } },
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
    and rows[2][1].label == "POTION" and not rows[2][1].done
    and rows[3][1].label == "BERRY" and rows[3][1].done
    and remaining[1] == 0 and remaining[2] == 1 and remaining[3] == 0,
    "Gen 2 area checklist data")
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
    THEME.hgss:button(x, y, w, h, label, selected)
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
  local displayRuntime = {}
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

  function compat.drawMapMarker(x, y)
    local data = game and game.data or {}
    local playerSprites = data.field and data.field.playerSprites or {}
    local id = compat.isGen2() and "SPRITE_CHRIS"
      or playerSprites.walk or "SPRITE_RED"
    local sprites = compat.isGen2() and data.gen2Sprites or data.sprites
    local def = sprites and sprites[id]
    local daytime, colors
    if def and compat.isGen2() then
      local _, palettes = compat.gen2PaletteModules()
      local world = game and game.world
      daytime = world and world.daytime
      if not daytime and palettes and type(palettes.clockDaytime) == "function" then
        daytime = palettes.clockDaytime(world and world.hour)
      end
      colors = palettes and type(palettes.spritePalette) == "function"
        and palettes.spritePalette(data.gen2Palettes, daytime, def)
    end
    local key = def and table.concat({ id, tostring(def.image),
      tostring(daytime) }, ":")
    if key and (not compat.mapMarker or compat.mapMarker.key ~= key) then
      local ok, renderer = pcall(function()
        local value = require("src.render.SpriteRenderer").new(
          def, "kanto-gear-map")
        if colors and type(value.setObjPalette) == "function" then
          value:setObjPalette(colors, ("gen2:%s:%d"):format(
            tostring(daytime), def.paletteId or 0))
        end
        return value
      end)
      compat.mapMarker = { key = key, renderer = ok and renderer or false }
    end
    local renderer = compat.mapMarker and compat.mapMarker.renderer
    if renderer then
      local ok = pcall(function()
        local pose = renderer:getPoseGeometry("down", 0, false)
        local scale = 0.75
        color({ 1, 1, 1, 1 })
        G.draw(renderer:resolveImage(), pose.quad,
          x - pose.width * scale / 2, y - pose.height * scale / 2,
          0, scale, scale)
      end)
      if ok then return end
    end
    THEME:drawMapMarker(x, y)
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
    local hgss = theme == "hgss" or theme == "hgss_dark"
    THEME.style = hgss and "hgss"
      or theme == "modern_light" and "modern_light"
      or theme == "modern_dark" and "modern_dark" or "classic"
    THEME.hgss:setVariant(theme == "hgss_dark")
    if not hgss then hgssRuntime.animation = nil end
    local scale = THEME.style == "hgss" and THEME.hgssScale or 1
    local width, height = WIDTH * scale, HEIGHT * scale
    if canvas:getWidth() ~= width or canvas:getHeight() ~= height then
      canvas = G.newCanvas(width, height, { dpiscale = 1 })
      canvas:setFilter("nearest", "nearest")
      readbackPending, displayReady = false, false
    end
    usePalette(themePalette(theme))
    invalidateLocalMap()
    themeKey, dirty = key, true
  end

  local function reloadSteps()
    steps = savedSteps(mod.save:get("steps", 0))
    dirty = true
  end

  local function pageNames()
    local out = { "MAP" }
    if localMapMode(mod.options:get("local_map")) ~= "off" then
      out[#out + 1] = "LOCAL"
    end
    if assist("guide") then out[#out + 1] = "GUIDE" end
    if assist("area") then out[#out + 1] = "AREA" end
    out[#out + 1] = "TRAINER"
    out[#out + 1] = "PARTY"
    out[#out + 1] = "TOOLS"
    return out
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
    nextTools.page = math.max(1, math.min(
      math.max(1, math.ceil(#nextTools / 6)), tools.page or 1))
    tools = nextTools
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

  local function guideData()
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
    local function sectionName(id)
      local section = tostring(id or "OTHER AREA"):gsub("_", " ")
      local entry = locationEntry(id)
      local name = entry and tostring(entry.name or entry.label or "") or ""
      for word in name:upper():gmatch("[%w]+") do
        section = section:gsub("^" .. word .. " ?", "")
      end
      return section ~= "" and section or name ~= "" and name or "OTHER AREA"
    end
    for _, id in ipairs(areaMaps(mapId)) do
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
                { time = time, mapId = id, section = sectionName(id) })
            end
          else
            addEncounters(rows, bySpecies, slots, method, weights,
              { mapId = id, section = sectionName(id) })
          end
        end
        local contest = id == mapId and game.save.bugContest
          and game.save.bugContest.active == true
        if contest then
          addWeighted(encounters.bugContest or (BugContest and BugContest.MONS),
            "CONTEST",
            { mapId = id, section = sectionName(id) })
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
              { time = time or nil, mapId = id, section = sectionName(id) })
          end
        end
        local treeSet = encounters.treeSets
          and encounters.treeSets[encounters.trees and encounters.trees[id]]
        if treeSet then
          addWeighted(treeSet.common, "HEADBUTT",
            { mapId = id, section = sectionName(id) })
          addWeighted(treeSet.rare, "RARE TREE",
            { mapId = id, section = sectionName(id) })
        end
        local rockSet = encounters.treeSets
          and encounters.treeSets[encounters.rocks and encounters.rocks[id]]
        if rockSet then
          addWeighted(rockSet.common, "ROCK SMASH",
            { mapId = id, section = sectionName(id) })
        end
        for _, roamer in ipairs(game.save.roamers or {}) do
          if roamer.species and roamer.map == id then
            addEncounters(rows, bySpecies, {
              { species = roamer.species, level = roamer.level or 40 },
              { species = 0, level = roamer.level or 40 },
            }, "ROAMING", { 10, 100 },
              { mapId = id, section = sectionName(id) })
          end
        end
      else
        addEncounters(rows, bySpecies,
          encounter and encounter.grass and encounter.grass.slots, "WALK",
          encounter and encounter.grass and (encounter.grass.buckets or buckets),
          { mapId = id, section = sectionName(id) })
        addEncounters(rows, bySpecies,
          encounter and encounter.water and encounter.water.slots, "SURF",
          encounter and encounter.water and (encounter.water.buckets or buckets),
          { mapId = id, section = sectionName(id) })
      end
      local super = field.superRod and field.superRod[id]
      if not gen2 and ((encounter and encounter.water) or super) then
        for _, rod in ipairs({ "OLD_ROD", "GOOD_ROD", "SUPER_ROD" }) do
          local def = fishing[rod] or {}
          local slots = def.always and { def.always } or def.pool
          if def.perMap then slots = field[def.perMap] and field[def.perMap][id] end
          addEncounters(rows, bySpecies, slots,
            ({ OLD_ROD = "OLD", GOOD_ROD = "GOOD", SUPER_ROD = "SUPER" })[rod],
            nil, { mapId = id, section = sectionName(id) })
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
      time = currentTime, section = sectionName(mapId) }
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
        remaining = Area.remaining(sections) }
    end
    for _, id in ipairs(maps) do
      local map = data.maps and data.maps[id]
      for _, obj in ipairs(map and map.objects or {}) do
        local key = id .. "_obj_" .. tostring(obj.index)
        if obj.trainerClass then
          local trainer = data.trainers and data.trainers[obj.trainerClass]
          local label = trainer and trainer.name
            or tostring(obj.trainerClass):gsub("^OPP_", "")
          if tostring(obj.trainerClass):match("^OPP_RIVAL") then
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
          local status
          if id == "OAKS_LAB" and obj.index == 1
              and obj.trainerClass == "OPP_RIVAL1" then
            done, status = oneShotTrainerStatus(done,
              save.flags and save.flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB == true,
              mod.save:get("oak_lab_rival_result"))
          end
          sections[1].rows[#sections[1].rows + 1] = {
            label = label, done = done, status = status,
          }
        elseif obj.item and obj.item ~= "0" and obj.item ~= 0 then
          local item = data.items and data.items[obj.item]
          sections[2].rows[#sections[2].rows + 1] = {
            label = item and item.name or obj.item,
            done = save.itemsTaken and save.itemsTaken[key] == true or false,
          }
        end
      end
      for _, hidden in ipairs(field.hiddenItems and field.hiddenItems[id] or {}) do
        local item = data.items and data.items[hidden.item]
        local key = id .. "_" .. hidden.x .. "_" .. hidden.y
        sections[3].rows[#sections[3].rows + 1] = {
          label = item and item.name or hidden.item,
          done = save.hiddenTaken and save.hiddenTaken[key] == true or false,
        }
      end
      for _, hidden in ipairs(field.hiddenCoins and field.hiddenCoins[id] or {}) do
        local key = id .. "_" .. hidden.x .. "_" .. hidden.y
        sections[3].rows[#sections[3].rows + 1] = {
          label = THEME:format("%d COINS", hidden.coins),
          done = save.hiddenTaken and save.hiddenTaken[key] == true or false,
        }
      end
    end
    local screens = checklistPages(sections)
    return { name = areaName(mapId), screens = screens, pages = #screens,
      remaining = Area.remaining(sections) }
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

  local function header(title, back, paged)
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
      THEME.hgss:headerBar(title, back, paged)
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
    if not (picker and type(picker.mon) == "table"
        and type(picker.list) == "table" and picker.list == picker.mon.moves
        and type(picker.row) == "number" and pack
        and type(pack.rows) == "table" and type(pack.index) == "number") then
      return nil
    end
    local row = pack and pack.rows and pack.rows[pack.index]
    local items = game and game.data and game.data.items
    local item = row and items and items[row.id]
    if not (item and item.teaches) then return nil end
    return { native = picker, mon = picker.mon, newMoveId = item.teaches,
             selecting = true, index = picker.row }
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

  local function drawDim(alpha, prompt)
    color({ 0, 0, 0, alpha })
    G.rectangle("fill", 0, 0, WIDTH, HEIGHT)
    if prompt then
      box("fill", 22, 61, 116, 22, DARK)
      outline(22, 61, 116, 22, PAPER)
      centered(prompt, 69, PAPER)
    end
  end

  local function namingKey(x, y, w, label, selected, raw)
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
  end

  local function drawNaming(top, grid)
    header("NAME INPUT")
    local gen2 = top.screenId == "Gen2NamingScreen"
    local name = gen2 and top.text or table.concat(top.glyphs or {})
    name = name == "" and "-" or name
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
    header(mapTitle, false, true)
    local asset = loadMap()
    if asset then
      local cells = asset.map
      local gbc = require("src.render.GbcPalette")
      local mapColors = not asset.gen2
        and PaletteFX.pal(game.data, "TOWNMAP") or nil
      if asset.gen2 then
        cells = asset.maps[region]
      end
      for i, tile in ipairs(cells or {}) do
        local quad = asset.quads[tile]
        if quad then
          local col, row = (i - 1) % 20, math.floor((i - 1) / 20)
          local y = asset.gen2 and 20 + row * 6 or 22 + (row - 1) * 6
          local colors = asset.gen2 and asset.palettes
            and asset.palettes[(asset.palMap and asset.palMap[tile + 1]) or 1]
            or mapColors
          local function paint()
            color(colors and { 1, 1, 1, 1 }
              or asset.gen2 and (THEME.style == "modern_dark" and INK or PAPER)
              or { 1, 1, 1, 1 })
            G.draw(asset.image, quad, 20 + col * 6, y, 0, 0.75, 0.75)
          end
          if (asset.gen2 or row > 0) then
            if colors and gbc.available() then gbc.with(colors, paint)
            else paint() end
          end
        end
      end
      local px, py = mapPoint(locationEntry(mapId))
      if px then compat.drawMapMarker(px, py) end
    else
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

  local function loadLocalMapImage(overview, rows, width, height, density)
    if localMapImage ~= nil then return localMapImage or nil end
    if not (love.image and love.image.newImageData) then
      localMapImage = false
      return nil
    end
    local ok, image = pcall(function()
      local pixels = love.image.newImageData(width, height)
      for y, row in ipairs(rows) do
        for x = 1, #row do
          local c = THEME:localMapColor(
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
    header("LOCAL", false, true)
    local overview = loadLocalMap()
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

    header("TRAINER", false, true)
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
        local status = fit(row.status or (row.done and "DONE" or "OPEN"), 5)
        text(status, 156 - #glyphList(status) * 6, y + 7, DARK)
      end
    end
    if screen.name == "HIDDEN" and assist("item_radar") then
      button(20, 118, 120, 20,
        hasItemfinder() and "SCAN" or "NEED ITEMFINDER", false)
    end
  end

  local function drawRadar()
    header("ITEM RADAR", true)
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
    local pages = math.max(1, math.ceil(#tools / 6))
    local current = math.max(1, math.min(pages, tools.page or 1))
    local first = (current - 1) * 6 + 1
    local count = math.min(6, math.max(0, #tools - first + 1))
    header(pages > 1 and THEME:format("TOOLS %d/%d", current, pages)
      or "TOOLS", false, true)
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

  local function partyCard(mon, x, y, selected, details, focused)
    if THEME.style == "hgss" then
      local source = mon and (mon.source or mon)
      local def = mon and game.data.pokemon[mon.species] or {}
      local type1 = mon and (mon.types and mon.types[1]
        or def.types and def.types[1])
      local type2 = mon and (mon.types and (mon.types[2] or mon.types[1])
        or def.types and (def.types[2] or def.types[1]))
      local view = mon and {
        name = mon.name, egg = compat.partyEgg(source),
        gender = mon.gender, hp = mon.hp, maxHp = mon.maxHp,
        expProgress = mon.expProgress,
        statusId = (mon.hp or 0) <= 0 and "FNT" or mon.status,
        type = type1, type2 = type2,
        typeLabel = THEME:typeName(type1, mod.content),
        type2Label = THEME:typeName(type2, mod.content),
        levelText = THEME:format("L%d", mon.level or 0),
        hpText = THEME:format("%d/%d", mon.hp or 0, mon.maxHp or 0),
        hpLabel = THEME:translate("HP"),
        expLabel = THEME:translate("EXP"),
      }
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

  local function drawParty(list, title, back, activeSpecies, selectedSlot,
                           paged)
    header(title or "PARTY", back, paged)
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
      local moveDef = game.data.moves[move.id] or {}
      local power = move.displayPower
      if power == nil then power = move.power or moveDef.power end
      if power == 0 then power = nil end
      view.moves[slot] = {
        id = move.id,
        name = THEME:moveName(move, game.data),
        type = move.type,
        typeLabel = THEME:typeName(move.type, mod.content),
        ppLabel = THEME:translate("PP"),
        ppText = THEME:format("%d/%d", move.pp or 0, move.maxPp or 0),
        powerLabel = THEME:translate("PWR"),
        power = power,
        powerText = hgssRuntime.numberLabel(power),
        accuracyLabel = THEME:translate("ACC"),
        accuracyText = hgssRuntime.numberLabel(move.hitChance or move.accuracy),
        effectiveness = move.effectiveness,
        disabled = THEME:moveUnavailableReason(move) ~= nil,
        descriptionLines = compat.moveInfoLines(move,
          game.data.moves[move.id] or {}, battleState() and battleState().ruleset),
      }
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
    header("SAFARI")
    button(3, 24, 76, 54,
           THEME:format("BALL x%d", battle.safariBalls or 0),
           battle.menuIndex == 1)
    button(81, 24, 76, 54, "BAIT", battle.menuIndex == 2)
    button(3, 81, 76, 56, "THROW ROCK", battle.menuIndex == 3)
    button(81, 81, 76, 56, "RUN", battle.menuIndex == 4)
  end

  local function drawMimic()
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

  local function drawBattleParty(menu)
    if menu.submenu then
      if THEME.style == "hgss" then
        local mon = (battle.party or {})[menu.index]
        if not mon then return end
        local actions, submenu = hgssRuntime.partySubmenuActions(menu)
        local selected = menu.subIndex or (submenu and submenu.index)
          or (actions[1] and actions[1].index)
        header(THEME:translate("PARTY"), true)
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
          end, progress, cancel and THEME:translate("CANCEL")
            or THEME:translate("PARTY"), clock, period)
        G.pop()
        return
      end
    end
    drawParty(battle.party or {}, cancel and "CANCEL" or "PARTY", true, nil,
      selected)
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
    header("CHOOSE MOVE", true)
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
        view.page, view.pages), true, true)
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
    box("fill", x, y, 144, 22, selected and DARK or MID)
    outline(x, y, 144, 22, INK)
    if not mon then return end
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

  local function drawPcBoxList(list)
    local boxes = game.save.boxes or {}
    local kind = pcListKind(list)
    local gen2 = kind and kind:find("^gen2_box_") ~= nil
    local current = gen2 and (list.boxIndex or game.save.currentBox or 1)
      or (game.save.currentBox or 1)
    local deposit = kind == "pc_box_deposit" or kind == "gen2_box_deposit"
    local mons = (deposit or (gen2 and current == 0))
      and (game.save.party or {}) or (boxes[current] or {})
    local total = gen2 and (#mons + 1) or #(list.items or {})
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
    header("CHANGE BOX", true)
    local first, count = pageWindow(selected, total)
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
    local item = list and list.items and list.items[list.index]
    header("QUANTITY", true)
    centered(fit(item and item.label or "ITEM", 20), 28, INK)
    button(8, 51, 43, 38, "-", false)
    box("fill", 55, 51, 50, 38, PAPER)
    outline(55, 51, 50, 38, INK)
    centered(tostring(quantity.qty or 1), 63, INK, 2)
    button(109, 51, 43, 38, "+", false)
    button(8, 104, 90, 29, "CONFIRM", false)
    button(102, 104, 50, 29, "CANCEL", false)
  end

  local function drawPc(kind, root, top)
    local list = pcList()
    local activeList = list and top == list and list or nil
    local activeKind = pcListKind(activeList)
    local quantity = kind == "items" and list and top
      and type(top.qty) == "number" and type(top.max) == "number"
      and type(top.onDone) == "function"
    if quantity then
      drawPcQuantity(top, list)
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
        battle.prompt == "advance" and THEME:translate("TAP TO CONTINUE")
          or nil,
        playerTeam, enemyTeam, title and THEME:translate(title) or nil)
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
        centered("TAP TO CONTINUE", 110, MID)
      end
      return
    end
    if battle.prompt == "advance" then
      button(22, 58, 116, 32, "CONTINUE", false)
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
    elseif summary then
      if compat.summary.supports(summary, game) then drawBattleSummary(summary)
      else drawTopSummaryControls(summary) end
    elseif top and top ~= raw and not top.isTextBox then
      drawTopSummaryControls(nil, true)
    elseif battle.prompt == "safari" then
      if fullBottomBattleUI() then drawFullSafari() else drawSafari() end
    elseif battle.prompt == "mimic" then
      drawMimic()
    elseif moveInfo then
      drawMoveInfo(moveInfo)
    elseif battle.prompt == "forget" then
      displayRuntime.drawForgetMoves()
    elseif battle.prompt == "moves" then
      drawMoves()
    elseif battle.prompt ~= "menu" then
      if fullBottomBattleUI() and raw and (raw.draining or raw.hpAnim) then
        drawFullBattleStatuses()
      else
        drawBattleLocked()
      end
    else
      if fullBottomBattleUI() then drawFullBattleRoot()
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

  local function drawLearnMove(learn, top)
    local newDef = moveDef(learn.newMoveId) or {}
    local newName = newDef.name or learn.newMoveId or "MOVE"
    if battle and top and top.isTextBox and hideUpperBattleUI() then
      drawBattleLocked("NEW MOVE")
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
    if THEME.style == "hgss" then THEME.hgss:backdrop() end
    local mode, top, fade = screenState()
    local summary = compat.isScreen(top, "summary") and top or nil
    local hgssSummary = THEME.style == "hgss" and summary
      and compat.summary.supports(summary, game)
    local learnScreen = screenById("MoveLearnMenu")
      or screenById("Gen2MoveDeleter")
    local learn = displayRuntime.moveLearnScreen()
    local pcKind, pcRoot = pcSession()
    local choice, labels, choiceField = dialogueChoice()
    local namingKeys = screenContract(top, "naming")
    local naming = namingKeys and top or nil
    local unsupportedSpecial = (learnScreen and not learn)
      or (compat.isScreen(top, "naming") and not naming)
    local levelStats = battle and compat.levelUpMon(top)
    if moveInfo then
      drawMoveInfo(moveInfo)
    elseif learn and not choice then
      drawLearnMove(learn, top)
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
    elseif page == "PARTY" then
      if partyActionSlot then drawPartyAction() else drawNormalParty() end
    else
      drawTools()
    end
    if not learn and not naming and not battle and not choice
        and not hgssSummary
        and not (pcKind and mode == "locked")
        and mode ~= "title" and mode ~= "active" then
      drawDim(fade, mode == "textbox" and textPrompt(top))
      if mode == "loading" then
        box("fill", 27, 57, 106, 30, DARK)
        outline(27, 57, 106, 30, PAPER)
        centered(fit("LOADING AREA", 16), 69, PAPER)
      end
    end
    if not learn and not battle and mode == "active" then
      if pendingFly then drawFlyPrompt()
      elseif pendingAction then drawActionPrompt() end
    end
    if THEME.style == "hgss" then
      outline(1, 1, WIDTH - 2, HEIGHT - 2, THEME.hgss.colors.silverDark)
      box("fill", 4, 1, 20, 1, THEME.hgss.colors.redLight)
      box("fill", WIDTH - 24, HEIGHT - 2, 20, 1, THEME.hgss.colors.green)
    elseif THEME.style ~= "classic" then
      outline(1, 1, WIDTH - 2, HEIGHT - 2, THEME.blue)
      box("fill", 3, 1, 16, 1, THEME.red)
      box("fill", WIDTH - 19, HEIGHT - 2, 16, 1, THEME.red)
    else
      outline(1, 1, WIDTH - 2, HEIGHT - 2, INK)
    end
    if highResolution then G.pop() end
    G.setCanvas()
  end

  local function draw()
    G.push("all")
    local ok, err = pcall(displayRuntime.drawContents)
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
      if y < HEADER and x < 24 then
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
        if hy < 63 then
          if hx < 29 then
            press("b")
          elseif categorizedBag(top) and hx >= 62 and hx < 92 then
            press("left")
          elseif categorizedBag(top) and hx >= 158 and hx < 187 then
            press("right")
          end
        elseif hx >= 7 and hx < 233 and hy >= 66 and hy < 197 then
          local view = hgssRuntime.bagView(menu)
          local first, count = THEME.hgss:battleBagWindow(view)
          local row = math.floor((hy - 66) / 33) + 1
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
      if fullBottomBattleUI() then
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
      local index = math.floor((y - 25) / 28) + 1
      if x >= 8 and x < 152 and index >= 1
          and index <= #(battle.mimicMoves or {}) then
        submit("mimic", { index = index })
      end
      return
    end
    if battle.prompt == "forget" then
      local mon = raw and screenContract(raw, "forget")
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
    if fullBottomBattleUI() then
      choice = fullBattleChoice(x, y)
    elseif THEME.style == "hgss" then
      choice = THEME.hgss:battleChoice(
        x * THEME.hgssScale, y * THEME.hgssScale)
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
    if kind == "items" and list and top and type(top.qty) == "number"
        and type(top.max) == "number" and type(top.onDone) == "function" then
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
        local first, count = pageWindow(list.index, #mons + 1)
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

    if top ~= root then
      return
    end
    if root.screenId == "Gen2PcMenu"
        and (root.message or root.savePhase or root.picking) then return end
    if root.screenId == "Gen2ItemPcMenu" and root.phase ~= "menu" then return end
    local items = root.items or root.entries or {}
    local count = #items
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

  local function tapDialogueChoice(top, labels, x, y, field)
    local now = love.timer.getTime()
    if trackChoice(top, now) then dirty = true end
    if choiceCommitted == top then return end
    if not choiceReady(now, choiceReadyAt) then
      choiceReadyAt = now + CHOICE_QUIET
      choiceNudgeUntil = now + 0.55
      dirty = true
      return
    end

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
    compat.choiceIndex(top, field, selected)
    if type(top.clampScroll) == "function" then
      pcall(top.clampScroll, top)
    end
    choiceCommitted = top
    press("a")
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
    if learn and not choice then
      tapLearn(learn, game.stack:top(), x, y)
      return
    elseif learnScreen and not choice then
      return
    end
    local battleTop = game and game.stack and game.stack:top()
    local levelMon = battle and compat.levelUpMon(battleTop)
    if levelMon then
      local buttonY = levelMon.stats and (levelMon.stats.specialAttack ~= nil
        or levelMon.stats.specialDefense ~= nil) and 111 or 108
      if inside(x, y, 24, buttonY, 112, 27) then press("a") end
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
      if inside(x, y, 18, 91, 58, 27) then
        local target = pendingFly
        pendingFly = nil
        if canFly() then
          local ok, err = mod.world:flyTo(target.id)
          if not ok then mod.log:warn("fly rejected: %s", tostring(err)) end
        end
        dirty = true
      elseif inside(x, y, 84, 91, 58, 27) then
        pendingFly, dirty = nil, true
      end
      return
    end
    if pendingAction then
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
    if y < HEADER and not partyMoveFrom then
      if x < 22 then changePage(-1)
      elseif x >= 86 and x < 108 then changePage(1) end
      if page == "TOOLS" and x >= 22 and x < 86 and #tools > 6 then
        local pages = math.ceil(#tools / 6)
        tools.page = (tools.page or 1) % pages + 1
        dirty = true
      end
      return
    end
    if page == "LOCAL" and inside(x, y, 126, 18, 34, 30) then
      localMapZoom = localMapZoom % 3 + 1
      dirty = true
      return
    end
    if page == "MAP" and canFly() then
      local best, distance
      for _, target in ipairs(flyTargets()) do
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
    elseif page == "TRAINER" and inside(x, y, 82, 109, 74, 29) then
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
      local first = ((tools.page or 1) - 1) * 6 + 1
      local count = math.min(6, #tools - first + 1)
      for slot = 1, count do
        local action = tools[first + slot - 1]
        local col, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
        if inside(x, y, 3 + col * 78, 25 + row * 38, 76, 34) then
          if action.id == "dig" or action.id == "teleport" then
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
          break
        end
      end
    end
  end

  local function swipe(dx)
    changePage(dx < 0 and 1 or -1)
  end

  local function swipeVertical(dy)
    if radarOpen then return end
    if page == "TOOLS" and #tools > 6 then
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
    if action == "down" and x then
      textSpeedReleasePending = false
      holdTextSpeed(false)
      local mode, top = screenState()
      local speed = textTouch(top) == "speed"
      touchDown = { x = x, y = y,
        pageSwipe = pageSwipeAllowed(mode, battle),
        textSpeed = speed,
        input = mode == "title" or mode == "active" or mode == "textbox" or battle
          or screenContract(top, "naming")
          or dialogueChoice() or compat.isScreen(top, "summary")
          or displayRuntime.moveLearnScreen()
          or pcSession() }
      if speed then holdTextSpeed(true) end
    elseif action == "cancel" then
      textSpeedReleasePending = false
      holdTextSpeed(false)
      touchDown = nil
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
      if down.textSpeed then
        textSpeedReleasePending = true
        return
      end
      if math.abs(dx) >= 24 and math.abs(dx) > math.abs(dy) * 1.25 then
        if down.pageSwipe then swipe(dx) end
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

  mod.events:on("save.created", reloadSteps)
  mod.events:on("save.loaded", reloadSteps)

  mod.events:on("map.entered", function(payload)
    mapId, pendingFly, pendingAction, fieldChoice, dirty =
      payload.mapId, nil, nil, nil, true
    invalidateLocalMap()
    guidePage, displayRuntime.guideDetail, areaPage = 1, nil, 1
    radarOpen = false
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
      if page == "LOCAL"
          and localMapMode(mod.options:get("local_map")) == "off" then
        page = "MAP"
      end
      if not assist("item_radar") then radarOpen = false end
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
    hgssRuntime.remapBattleRootInput(stepGame)
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
    if action == "down" or action == "up" or action == "cancel" then
      touchEvent(string.format("%s,%d,%d", action, tx, ty))
    end
    return true
  end

  mod.hooks:wrap("input.pointer", function(next, pointerGame, event)
    local action = ({ pressed = "down", released = "up",
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
    if page == "TRAINER" or page == "LOCAL" then dirty = true end
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
      if page == "TOOLS" or pendingAction then refreshTools() end
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
      local screenKey = table.concat({ mode, tostring(top),
        tostring(page), tostring(guidePage), tostring(areaPage),
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
        tostring(currentPcList), tostring(currentPcList and currentPcList.index),
        tostring(learn and learn.selecting),
        tostring(learn and learn.index), tostring(externalLoading),
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
