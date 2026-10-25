return function()
local WIDTH, HEIGHT = 160, 144

local HEADER = 20

local render = {}

render.INK, render.DARK, render.MID, render.PAPER = nil

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
  if not move or (move.pp or 0) <= 0 then return "NO PP" end
  if move.disabled then return "DISABLED" end
end

function THEME:translate(source)
  if not self.i18n then return tostring(source or "") end
  return self.i18n:text(source)
end

local MENU_ACTION_LABELS = {
  ["WITHDRAW <PK><MN>"] = "WITHDRAW",
  ["DEPOSIT <PK><MN>"] = "DEPOSIT",
  ["RELEASE <PK><MN>"] = "RELEASE",
  ["MOVE <PK><MN> W/O MAIL"] = "MOVE WITHOUT MAIL",
  ["PRINT BOX"] = "PRINT",
  ["SEE YA!"] = "BACK",
  ["WITHDRAW"] = "WITHDRAW", ["DEPOSIT"] = "DEPOSIT",
  ["RELEASE"] = "RELEASE", ["CHANGE BOX"] = "CHANGE BOX",
  ["STATS"] = "STATS", ["SWITCH"] = "SWITCH",
  ["MOVE"] = "MOVE", ["CANCEL"] = "CANCEL", ["BACK"] = "BACK",
}

function THEME:menuActionLabel(value)
  value = tostring(value or "")
  local key = MENU_ACTION_LABELS[value]
  return key and self:translate(key) or value
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

function THEME:format(source, ...)
  if self.i18n then return self.i18n:format(source, ...) end
  local ok, value = pcall(string.format, source, ...)
  return ok and value or tostring(source or "")
end

function THEME:typeName(id, content)
  local registry = content and content.type_chart
  local record = id and registry and registry:get(id)
  local name = record and record.name or id or "STATUS"
  -- Translation mods can publish contextual display strings while keeping
  -- canonical type records intact for mechanics and other mods.
  local strings = content and content.strings
  local translated = strings and strings:get("type|" .. name)
  return type(translated) == "string" and translated ~= "" and translated or name
end

function THEME:statusName(id, content)
  local registry = content and content.statuses
  local record = id and registry and registry:get(id)
  return record and (record.hudLabel or record.label) or id
end

-- Host path [all games]: old window_layout values seed display_mode/combined_layout only when the new settings are absent.
function THEME:displayDefaults(get, existing)
  local legacy = get("window_layout")
  local mode = get("display_mode")
  if mode == nil then
    mode = legacy and legacy ~= "off" and "combined"
      or (legacy == "off" or existing) and "separate" or "combined"
  end
  local layout = get("combined_layout")
  if layout == nil then
    layout = legacy == "large" and "overlay"
      or (legacy ~= "off" and legacy) or "auto"
  end
  return mode, layout
end

function THEME:displayMode(options)
  return self.displayModeOverride or options:get("display_mode") or self.displayModeDefault
end

function THEME:windowMode(options)
  local mode = self:displayMode(options)
  if mode == "fullscreen" then return "fullscreen" end
  if mode == "combined" then
    if self.displayModeOverride then return "auto" end
    return options:get("combined_layout") or self.combinedLayoutDefault
  end
  return "off"
end

function THEME:gearPrimary(options, swapped)
  if self.displayModeOverride then return false end
  local primary = self:displayMode(options) == "fullscreen"
    and (options:get("fullscreen_start") or "game")
    or (options:get("combined_primary") or "game")
  local gear = primary == "gear"
  if swapped then return not gear end
  return gear
end

function THEME:fitRect(rect, width, height)
  local scale = math.min(rect.w / width, rect.h / height)
  -- Keep one scale on both axes. Flooring each dimension independently
  -- subtly stretches nearest-filtered pixels whenever the fit is fractional.
  local w, h = width * scale, height * scale
  return {
    x = math.floor(rect.x + (rect.w - w) / 2),
    y = math.floor(rect.y + (rect.h - h) / 2),
    w = w, h = h,
  }
end

function THEME:windowLayout(mode, width, height, swapped, overlayCorner,
    overlayHidden, secondarySize, bottomSafeArea)
  if not mode or mode == "off" then return nil end
  if mode == "auto" then
    mode = width >= height and "side" or "stacked"
  elseif mode == "large" then
    mode = "overlay"
  end
  if mode ~= "fullscreen" then
    local safePercent = math.max(0, math.min(50,
      tonumber(bottomSafeArea) or 0))
    height = math.max(1, height - math.floor(height * safePercent / 100))
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
  render.G.setScissor(rect.x, rect.y, rect.w, rect.h)
  render.G.draw(canvas, fitted.x, fitted.y, 0,
    fitted.w / canvas:getWidth(), fitted.h / canvas:getHeight())
  return fitted
end

function THEME:moveDescription(move, def, ruleset)
  local function lines(keys)
    local translated = {}
    for index, key in ipairs(keys) do translated[index] = self:translate(key) end
    return translated
  end
  def = def or {}
  local id = move and move.id or def.id
  local fixed = def.fixedDamage
  if type(fixed) == "number" then
    return { self:format("DEALS %d FIXED DAMAGE", fixed) }, true
  elseif fixed == "level" then
    return lines({ "DAMAGE EQUALS", "USER LEVEL" }), true
  elseif type(fixed) == "function" then
    return lines({ "DEALS CUSTOM", "FIXED DAMAGE" }), true
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
  if special then return lines(special), true end
  if def.highCrit or self.highCritMoves[id] then
    return lines({ "HIGH CRITICAL-HIT", "RATE" }), true
  end
  local effect = def.effect
  if effect == "FOCUS_ENERGY_EFFECT" then
    return lines(ruleset and ruleset.focusEnergyBug == false
      and { "RAISES CRITICAL-HIT", "RATE" }
      or { "LOWERS CRITICAL-HIT", "RATE DUE TO GEN 1 BUG" }), true
  elseif effect == "HYPER_BEAM_EFFECT" then
    return lines(ruleset and ruleset.hyperBeamSkipRechargeOnKO == false
      and { "USER MUST RECHARGE", "NEXT TURN" }
      or { "RECHARGES NEXT TURN", "UNLESS TARGET FAINTS" }), true
  elseif effect == "SPECIAL_DAMAGE_EFFECT" then
    return lines({ "SPECIAL DAMAGE", "NO DETAILS AVAILABLE" }), false
  end
  local stat, stages = effect and effect:match("^([A-Z]+)_UP([12])_EFFECT$")
  if stat then
    return { self:format("RAISES USER %s", self:translate(stat)),
             self:translate(stages == "2" and "BY TWO STAGES" or "BY ONE STAGE") }, true
  end
  stat, stages = effect and effect:match("^([A-Z]+)_DOWN([12])_EFFECT$")
  if stat then
    local amount = stages == "2" and "BY TWO STAGES" or "BY ONE STAGE"
    stat = self:translate(stat)
    local first = self:format("LOWERS TARGET %s", stat)
    return #first <= 21 and { first, self:translate(amount) }
      or { self:translate("LOWERS TARGET"), self:format("%s %s", stat,
                                         self:translate(amount)) }, true
  end
  stat = effect and effect:match("^([A-Z]+)_DOWN_SIDE_EFFECT$")
  if stat then
    return { self:translate("33.2% CHANCE TO LOWER"),
             self:format("TARGET %s", self:translate(stat)) }, true
  end
  local description = self.moveEffects[effect]
  if description then return lines(description), true end
  if effect == "NO_ADDITIONAL_EFFECT" then
    return lines({ "DEALS DAMAGE" }), true
  end
  return lines({ "NO DETAILS AVAILABLE" }), false
end
  return HEADER, HEIGHT, THEME, WIDTH, render
end
