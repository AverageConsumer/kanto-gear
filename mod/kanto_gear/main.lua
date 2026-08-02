local WIDTH, HEIGHT = 160, 144
local HEADER = 20
local G

local KANTO_PALETTE = {
  { 155, 188, 15 }, { 139, 172, 15 }, { 48, 98, 48 }, { 15, 56, 15 },
}
local INK, DARK, MID, PAPER
local RADAR_RED = { 220 / 255, 38 / 255, 28 / 255, 1 }
local CHOICE_QUIET = 0.32
local SECONDARY_BACKGROUND
local RADAR_FRAMES = 16
local PC_LIST_KINDS = {
  pc_box_withdraw = true, pc_box_deposit = true,
  pc_box_release = true, pc_box_change = true,
  pc_item_withdraw = true, pc_item_deposit = true, pc_item_toss = true,
}

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
  palette = validPalette(palette) and palette or KANTO_PALETTE
  PAPER, MID, DARK, INK = rgba(palette[1]), rgba(palette[2]),
                           rgba(palette[3]), rgba(palette[4])
  SECONDARY_BACKGROUND = rgb24(fillerColor(palette))
end

usePalette(KANTO_PALETTE)
assert(validPalette(KANTO_PALETTE)
       and inverted(KANTO_PALETTE)[1] == KANTO_PALETTE[4]
       and fillerColor({ { 255, 255, 255 }, { 200, 100, 100 },
                         { 120, 20, 80 }, { 0, 0, 0 } })[1] == 120
       and SECONDARY_BACKGROUND == 0x0F380F, "theme palette helpers")

local function choiceReady(now, readyAt)
  return now >= readyAt
end

local function pageSwipeAllowed(mode, battle)
  return mode == "active" and not battle
end

local function pagedIndex(index, count, direction)
  return math.max(1, math.min(count, index + direction * 4))
end

local function pageWindow(index, count)
  local first = math.floor((math.max(1, index or 1) - 1) / 4) * 4 + 1
  return first, math.min(4, math.max(0, count - first + 1))
end

local function pcListKind(state)
  return state and PC_LIST_KINDS[state.kind] and state.kind or nil
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

local function addEncounters(rows, bySpecies, slots, method, buckets)
  slots = slots or {}
  local weights, previous = {}, 0
  for index, slot in ipairs(slots) do
    local threshold = buckets and buckets[index]
    local weight = threshold and threshold - previous or 1
    previous = threshold or previous
    weights[slot.species] = (weights[slot.species] or 0) + weight
    local row = bySpecies[slot.species]
    if not row then
      row = { species = slot.species, minLevel = slot.level,
              maxLevel = slot.level, methods = {}, methodSet = {} }
      rows[#rows + 1], bySpecies[slot.species] = row, row
    else
      row.minLevel = math.min(row.minLevel, slot.level)
      row.maxLevel = math.max(row.maxLevel, slot.level)
    end
  end
  local total, seen = buckets and buckets[#slots] or #slots, {}
  for _, slot in ipairs(slots) do
    if not seen[slot.species] then
      seen[slot.species] = true
      local chance = math.floor(weights[slot.species] * 100 / total + 0.5)
      local row, odds = bySpecies[slot.species]
      odds = row.methodSet[method]
      if odds then
        odds.min, odds.max = math.min(odds.min, chance), math.max(odds.max, chance)
      else
        odds = { name = method, min = chance, max = chance }
        row.methodSet[method] = odds
        row.methods[#row.methods + 1] = odds
      end
    end
  end
end

local function methodLines(methods)
  local lines = { "" }
  for _, odds in ipairs(methods) do
    local chance = odds.min == odds.max and tostring(odds.min)
      or (odds.min .. "-" .. odds.max)
    local method = odds.name .. " " .. chance .. "%"
    local joined = lines[#lines] == "" and method or lines[#lines] .. "/" .. method
    if #joined <= 14 then
      lines[#lines] = joined
    else
      lines[#lines + 1] = method
    end
  end
  return lines[1] or "", lines[2] or ""
end

local function profileFromAssists(get)
  local hints, details = get("type_hints"), get("move_details")
  local guide, area = get("guide"), get("area")
  local radar, catchOdds = get("item_radar"), get("catch_odds")
  if hints and details and guide and area and radar and catchOdds then
    return "enhanced"
  end
  if not hints and not details and not guide and not area and not radar
      and not catchOdds then
    return "purist"
  end
  return "custom"
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

local function itemfinderNear(px, py, x, y)
  local function near(origin, value, high)
    return value > math.max(origin - 5, 0) and value <= origin + high
  end
  return near(px, x, 5) and near(py, y, 4)
end

local function battleFocusChanged(a, b)
  return (a and a.menuIndex) ~= (b and b.menuIndex)
    or (a and a.moveIndex) ~= (b and b.moveIndex)
    or (a and a.partyIndex) ~= (b and b.partyIndex)
    or (a and a.subIndex) ~= (b and b.subIndex)
    or (a and a.itemIndex) ~= (b and b.itemIndex)
    or (a and a.summaryPage) ~= (b and b.summaryPage)
    or (a and a.mimicIndex) ~= (b and b.mimicIndex)
end

local function supportedBattleUI(state)
  if not state then return false end
  local kind = state.battleKind and state:battleKind() or state.kind
  return kind ~= "link" and kind ~= "oldman"
end

local function bottomOwnsBattleUI(enabled, active, available, ready,
                                 battleState)
  return enabled and active and available and ready
    and supportedBattleUI(battleState) or false
end

local function mirroredBattleMenu(state)
  return state and (state.isPartyMenu or state.screenId == "BagMenu"
    or state.screenId == "SummaryMenu" or state.kind == "pp_item_move") or false
end

assert(not choiceReady(0.31, 0.32) and choiceReady(0.32, 0.32),
       "choice quiet gate")
assert(pageSwipeAllowed("active", nil)
       and not pageSwipeAllowed("transition", nil)
       and not pageSwipeAllowed("loading", nil)
       and not pageSwipeAllowed("active", {}), "disabled screen swipe gate")
assert(pagedIndex(1, 9, 1) == 5 and pagedIndex(9, 9, 1) == 9
       and pagedIndex(5, 9, -1) == 1, "touch list paging")
do
  local first, count = pageWindow(6, 9)
  assert(first == 5 and count == 4
    and pcListKind({ kind = "pc_box_withdraw" }) == "pc_box_withdraw"
    and not pcListKind({ kind = "bag" }), "PC touch list identity")
end
assert(not assistEnabled("purist", true)
       and assistEnabled("enhanced", false)
       and assistEnabled("custom", true), "assist profiles")
do
  local values = { type_hints = true, move_details = true,
                   guide = true, area = true, item_radar = true,
                   catch_odds = true }
  local function get(key) return values[key] end
  assert(profileFromAssists(get) == "enhanced", "all assists enhanced")
  values.guide = false
  assert(profileFromAssists(get) == "custom", "mixed assists custom")
  values.type_hints, values.move_details, values.area, values.item_radar,
    values.catch_odds = false, false, false, false, false
  assert(profileFromAssists(get) == "purist", "all assists purist")
end
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
assert(itemfinderNear(10, 10, 15, 14)
       and not itemfinderNear(10, 10, 5, 10)
       and not itemfinderNear(10, 10, 10, 15), "native itemfinder radius")
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
assert(not battleFocusChanged({}, {})
       and battleFocusChanged({ moveIndex = 1 }, { moveIndex = 2 })
       and battleFocusChanged({ itemIndex = 1 }, { itemIndex = 2 }),
       "battle focus sync")
do
  local state = {}
  assert(bottomOwnsBattleUI(true, true, true, true, state)
    and not bottomOwnsBattleUI(true, true, true, false, state)
    and not bottomOwnsBattleUI(true, true, false, true, state)
    and mirroredBattleMenu({ isPartyMenu = true })
    and mirroredBattleMenu({ screenId = "BagMenu" })
    and mirroredBattleMenu({ screenId = "SummaryMenu" })
    and mirroredBattleMenu({ kind = "pp_item_move" })
    and not mirroredBattleMenu({ screenId = "TownMap" }),
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
  ["-"]="00000000000000011111000000000000000",
  ["/"]="00001000100010001000100001000000000",
  ["+"]="00000001000010011111001000010000000",
  ["%"]="11001110100010001000101101100100000",
  ["?"]="01110100010001000100001000000000100",
  ["<"]="00010001000100010000010000010000010",
  [">"]="01000001000001000001000100010001000",
  ["!"]="00100001000010000100001000000000100",
}

local function color(c) G.setColor(c[1], c[2], c[3], c[4]) end

local function box(mode, x, y, w, h, c)
  color(c)
  G.rectangle(mode, x, y, w, h)
end

local function clean(value)
  return tostring(value or ""):upper()
    :gsub("Ä", "AE"):gsub("Ö", "OE"):gsub("Ü", "UE")
    :gsub("É", "E"):gsub("_", " "):gsub("[^A-Z0-9 :%%%+%-%./%?!<>]", "")
end

assert(clean("40%") == "40%", "percent glyph whitelist")

local function fit(value, chars)
  local out = clean(value)
  if #out > chars then out = out:sub(1, math.max(1, chars - 1)) .. "." end
  return out
end

local function text(value, x, y, c, scale)
  value, scale = clean(value), scale or 1
  color(c)
  local cursor = x
  for index = 1, #value do
    local glyph = FONT[value:sub(index, index)]
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
  text(value, math.floor((WIDTH - #value * 6 * scale) / 2), y, c, scale)
end

local function outline(x, y, w, h, c)
  box("line", x + 0.5, y + 0.5, w - 1, h - 1, c or INK)
end

local function hpBar(x, y, w, hp, maxHp)
  local ratio = math.max(0, math.min(1, (hp or 0) / math.max(1, maxHp or 1)))
  box("fill", x, y, w, 4, DARK)
  box("fill", x + 1, y + 1, math.floor((w - 2) * ratio), 2,
      ratio > 0.5 and PAPER or ratio > 0.2 and MID or INK)
end

local function button(x, y, w, h, label, selected)
  box("fill", x, y, w, h, selected and DARK or MID)
  outline(x, y, w, h, INK)
  local c = selected and PAPER or INK
  text(fit(label, math.floor((w - 8) / 6)),
       x + math.max(4, math.floor((w - #fit(label, math.floor((w - 8) / 6)) * 6) / 2)),
       y + math.floor((h - 7) / 2), c)
end

local function inside(x, y, left, top, width, height)
  return x >= left and x < left + width and y >= top and y < top + height
end

return function(mod)
  mod.options:define({
    { key = "theme", label = "BOTTOM THEME", type = "choice",
      default = "kanto", choices = {
        { "KANTO GREEN", "kanto" }, { "MATCH GAME", "match" },
        { "OG", "og" }, { "OG INVERTED", "og_inv" },
        { "SGB", "sgb" }, { "ADVANCED", "advanced" },
        { "VERSION COLOR", "version" },
      } },
    { key = "profile", label = "PROFILE", type = "choice",
      default = "enhanced", choices = {
        { "PURIST", "purist" }, { "ENHANCED", "enhanced" },
        { "CUSTOM", "custom" },
      }, sync = true, sets = {
        purist = { type_hints = false, move_details = false,
                   guide = false, area = false, item_radar = false,
                   catch_odds = false },
        enhanced = { type_hints = true, move_details = true,
                     guide = true, area = true, item_radar = true,
                     catch_odds = true },
        custom = { profile = profileFromAssists },
      } },
    { key = "type_hints", label = "ASSIST TYPE HINTS",
      type = "toggle", default = true,
      sets = { [false] = { profile = profileFromAssists },
               [true] = { profile = profileFromAssists } } },
    { key = "move_details", label = "ASSIST MOVE INFO",
      type = "toggle", default = true,
      sets = { [false] = { profile = profileFromAssists },
               [true] = { profile = profileFromAssists } } },
    { key = "guide", label = "ASSIST GUIDE PAGE",
      type = "toggle", default = true,
      sets = { [false] = { profile = profileFromAssists },
               [true] = { profile = profileFromAssists } } },
    { key = "area", label = "ASSIST AREA PAGE",
      type = "toggle", default = true,
      sets = { [false] = { profile = profileFromAssists },
               [true] = { profile = profileFromAssists } } },
    { key = "item_radar", label = "ASSIST ITEM RADAR",
      type = "toggle", default = true,
      sets = { [false] = { profile = profileFromAssists },
               [true] = { profile = profileFromAssists } } },
    { key = "catch_odds", label = "ASSIST CATCH ODDS",
      type = "toggle", default = true,
      sets = { [false] = { profile = profileFromAssists },
               [true] = { profile = profileFromAssists } } },
    { key = "display_target", label = "BOTTOM SCREEN", type = "choice",
      default = "auto", choices = {
        { "AUTO", "auto" }, { "HANDHELD", "handheld" },
        { "EXTRA SCREEN", "secondary" },
      } },
    { key = "hide_upper_battle_ui", label = "HIDE UPPER BATTLE UI",
      type = "toggle", default = false },
  })
  local function assist(key)
    return assistEnabled(mod.options:get("profile"), mod.options:get(key))
  end

  local runtime = rawget(_G, "love")
  local system = runtime and runtime.system
  if not system or not system.hasSecondaryDisplay
      or not system.presentSecondaryDisplay
      or not system.pollSecondaryDisplayTouch then
    mod.log:warn("host has no secondary-display bridge; mod stays inactive")
    return
  end

  G = runtime.graphics
  if not G then
    mod.log:warn("host has no graphics runtime; mod stays inactive")
    return
  end

  local PaletteFX = require("src.render.PaletteFX")

  local canvas = G.newCanvas(WIDTH, HEIGHT, { dpiscale = 1 })
  canvas:setFilter("nearest", "nearest")
  if not canvas.requestImageData or not canvas.pollImageData then
    mod.log:warn("host has no asynchronous display readback; mod stays inactive")
    return
  end
  local game
  local active = false
  local dirty = true
  local readbackPending = false
  local page = "MAP"
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
  local spriteCache = {}
  local touchDown = nil
  local battle = nil
  local moveInfo = nil
  local intentId = 0
  local nextPoll = 0
  local nextClock = 0
  local lastScreenKey = nil
  local worldStarted = false
  local externalLoading = false
  local pendingFly = nil
  local pendingAction = nil
  local fieldChoice = nil
  local choiceTop = nil
  local choiceReadyAt = 0
  local choiceNudgeUntil = 0
  local choiceCommitted = nil
  local loggedTick = false
  local loggedPresent = false
  local displayReady = false
  local nextPresentAttempt = 0
  local themeKey = nil

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
    if theme == "og" then return PaletteFX.GRAYS end
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
    return KANTO_PALETTE
  end

  local function refreshTheme(force)
    local theme = mod.options:get("theme") or "kanto"
    local key = theme .. (theme == "match" and (":" .. PaletteFX.mode) or "")
    if not force and key == themeKey then return end
    usePalette(themePalette(theme))
    themeKey, dirty = key, true
  end

  local function reloadSteps()
    steps = savedSteps(mod.save:get("steps", 0))
    dirty = true
  end

  local function pageNames()
    local out = { "MAP" }
    if assist("guide") then out[#out + 1] = "GUIDE" end
    if assist("area") then out[#out + 1] = "AREA" end
    out[#out + 1] = "STEPS"
    out[#out + 1] = "PARTY"
    out[#out + 1] = "TOOLS"
    return out
  end

  local function refreshTools()
    local nextTools = mod.world and mod.world.availableFieldActions
      and mod.world:availableFieldActions() or {}
    local keys = {}
    for i, action in ipairs(nextTools) do
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
    tools = nextTools
    if nextKey ~= toolsKey then
      toolsKey = nextKey
      pendingAction = nil
      fieldChoice = nil
      dirty = true
    end
  end

  local function locationEntries()
    local townMap = game and game.data and game.data.field
      and game.data.field.townMap
    return townMap and (townMap.locations or townMap) or {}
  end

  local function locationEntry(id)
    return id and locationEntries()[id]
  end

  local function areaName(id)
    local entry = locationEntry(id)
    return fit((entry and (entry.name or entry.label)) or id or "KANTO", 23)
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
    local fishing = require("src.world.FieldDefaults").field(data, "fishing") or {}
    for _, id in ipairs(areaMaps(mapId)) do
      local encounter = data.encounters and data.encounters[id]
      local buckets = data.constants and data.constants.encounterBuckets
      addEncounters(rows, bySpecies,
        encounter and encounter.grass and encounter.grass.slots, "WALK",
        encounter and encounter.grass and (encounter.grass.buckets or buckets))
      addEncounters(rows, bySpecies,
        encounter and encounter.water and encounter.water.slots, "SURF",
        encounter and encounter.water and (encounter.water.buckets or buckets))
      local super = field.superRod and field.superRod[id]
      if (encounter and encounter.water) or super then
        for _, rod in ipairs({ "OLD_ROD", "GOOD_ROD", "SUPER_ROD" }) do
          local def = fishing[rod] or {}
          local slots = def.always and { def.always } or def.pool
          if def.perMap then slots = field[def.perMap] and field[def.perMap][id] end
          addEncounters(rows, bySpecies, slots,
            ({ OLD_ROD = "OLD", GOOD_ROD = "GOOD", SUPER_ROD = "SUPER" })[rod])
        end
      end
    end

    local dex = game.save.pokedex or {}
    local ownedDex = dex.owned or {}
    local owned, dexTotal = 0, (data.constants and data.constants.dexSize) or 151
    for species, def in pairs(data.pokemon or {}) do
      if def.dex and ownedDex[species] then owned = owned + 1 end
    end
    local areaCaught = 0
    for _, row in ipairs(rows) do
      local def = data.pokemon[row.species] or {}
      row.name, row.caught = def.name or row.species, ownedDex[row.species] == true
      if row.caught then areaCaught = areaCaught + 1 end
    end
    return { name = areaName(mapId), rows = rows, caught = areaCaught,
      complete = #rows > 0 and areaCaught == #rows,
      dexCaught = owned, dexTotal = dexTotal,
      pages = math.max(1, math.ceil(#rows / 3)) }
  end

  local function areaData()
    local sections = { { name = "TRAINERS", rows = {} },
      { name = "ITEMS", rows = {} }, { name = "HIDDEN", rows = {},
        perPage = assist("item_radar") and 3 or 4 } }
    local data, save = game.data, game.save
    local field = data.field or {}
    for _, id in ipairs(areaMaps(mapId)) do
      local map = data.maps and data.maps[id]
      for _, obj in ipairs(map and map.objects or {}) do
        local key = id .. "_obj_" .. tostring(obj.index)
        if obj.trainerClass then
          local trainer = data.trainers and data.trainers[obj.trainerClass]
          local label = trainer and trainer.name
            or tostring(obj.trainerClass):gsub("^OPP_", "")
          if tostring(obj.trainerClass):match("^OPP_RIVAL") then
            label = save.player.rival or label
          end
          local done = save.defeatedTrainers
            and save.defeatedTrainers[key] == true or false
          if not done and map.label and data.trainerHeader then
            local header_ = data:trainerHeader(map.label, obj.index)
            done = header_ and header_.event and save.flags
              and save.flags[header_.event] == true or false
          end
          sections[1].rows[#sections[1].rows + 1] = {
            label = label, done = done,
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
          label = tostring(hidden.coins) .. " COINS",
          done = save.hiddenTaken and save.hiddenTaken[key] == true or false,
        }
      end
    end
    local screens = checklistPages(sections)
    return { name = areaName(mapId), screens = screens, pages = #screens }
  end

  local function hasItemfinder()
    return ((game.save.inventory or {}).ITEMFINDER or 0) > 0
  end

  local function radarSignals()
    local world = game and game.overworld
    local player = world and world.player
    if not player then return {} end
    local field = game.data.field or {}
    local hidden = field.hiddenItems and field.hiddenItems[mapId] or {}
    local taken, out = game.save.hiddenTaken or {}, {}
    for _, item in ipairs(hidden) do
      local key = mapId .. "_" .. item.x .. "_" .. item.y
      if not taken[key]
          and itemfinderNear(player.cellX, player.cellY, item.x, item.y) then
        out[#out + 1] = {
          dx = item.x - player.cellX, dy = item.y - player.cellY,
        }
      end
    end
    return out
  end

  local function loadMap()
    if mapAsset ~= nil then return mapAsset or nil end
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

  local function sprite(species, side)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[species]
    local path = def and (side == "back" and def.spriteBack or def.spriteFront)
    if not path then return nil end
    local key = side .. ":" .. path
    if spriteCache[key] == nil then
      local ok, image = pcall(G.newImage, path)
      if ok then image:setFilter("nearest", "nearest") end
      spriteCache[key] = ok and image or false
    end
    return spriteCache[key] or nil
  end

  local function drawSprite(species, side, x, y, maxW, maxH, tint)
    local image = sprite(species, side)
    if not image then
      box("fill", x + 4, y + 4, maxW - 8, maxH - 8, DARK)
      return
    end
    local iw, ih = image:getDimensions()
    local scale = math.min(maxW / iw, maxH / ih)
    color(tint or { 1, 1, 1, 1 })
    G.draw(image, x + (maxW - iw * scale) / 2,
           y + (maxH - ih * scale) / 2, 0, scale, scale)
  end

  local function battery()
    local _, percent = system.getPowerInfo()
    percent = tonumber(percent)
    box("line", 143.5, 6.5, 12, 7, PAPER)
    box("fill", 155, 9, 2, 3, PAPER)
    if percent then
      box("fill", 145, 8, math.floor(9 * math.max(0, math.min(100, percent)) / 100),
          4, PAPER)
    end
  end

  local function header(title, back)
    box("fill", 0, 0, WIDTH, HEADER, DARK)
    if back then
      text("<", 4, 6, PAPER)
      text(fit(title, 12), 16, 6, PAPER)
    else
      text(fit(title, 14), 5, 6, PAPER)
    end
    text(os.date("%H:%M"), 106, 6, PAPER)
    battery()
  end

  local function stackHas(target)
    for _, state in ipairs(game and game.stack and game.stack.states or {}) do
      if state == target then return true end
    end
    return false
  end

  local function screenById(id)
    local states = game and game.stack and game.stack.states or {}
    for i = #states, 1, -1 do
      if states[i].screenId == id then return states[i] end
    end
  end

  local function pcSession()
    local root = screenById("BoxMenu")
    if root then return "pokemon", root end
    root = screenById("PlayerPC")
    if root then return "items", root end
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
      if states[i].isBattleState then return states[i] end
    end
  end

  local function screenState()
    local top = game and game.stack and game.stack:top()
    local world = game and game.overworld
    if not (world and stackHas(world)) then
      worldStarted = false
      return "title", top, 0
    end
    if not worldStarted then
      if top ~= world then return "title", top, 0 end
      worldStarted = true
    end
    if world.transitioning then
      local alpha = math.min(1, (top and top.t or 0)
        / math.max(1, top and top.frames or 1))
      if top and top.phase == "in" then alpha = 1 - alpha end
      return "transition", top, alpha
    end
    if externalLoading then return "loading", top, 0.72 end
    if top and top.isTextBox then return "textbox", top, 0.58 end
    if world.flyAnim or world.teleportOut then return "locked", top, 0.58 end
    if top == world then return "active", top, 0 end
    return "locked", top, 0.58
  end

  local function dialogueChoice()
    local top = game and game.stack and game.stack:top()
    if not top then return end
    if top.onChoose and top.index and not top.items then
      return top, { "YES", "NO" }
    end
    if top.items and not top.screenId and not pcListKind(top) then
      local labels = {}
      for i, item in ipairs(top.items) do
        labels[i] = item.label or tostring(i)
      end
      if #labels > 0 then return top, labels end
    end
  end

  local function trackChoice(top, now)
    if top == choiceTop then return false end
    choiceTop = top
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
    box("fill", 0, 0, WIDTH, HEIGHT, DARK)
    color(PAPER)
    G.circle("line", 80, 29, 15)
    G.circle("line", 80, 29, 6)
    for i = 0, 7 do
      local a = i * math.pi / 4
      box("fill", math.floor(78 + math.cos(a) * 17),
          math.floor(27 + math.sin(a) * 17), 4, 4, PAPER)
    end
    centered("KANTO GEAR", 56, PAPER, 2)
    box("fill", 28, 78, 104, 1, PAPER)
    centered("DUAL DISPLAY", 87, PAPER)
    centered("LINK READY", 104, MID)
    centered("START GAME ABOVE", 125, PAPER)
  end

  local function drawDim(alpha, canContinue)
    color({ 0, 0, 0, alpha })
    G.rectangle("fill", 0, 0, WIDTH, HEIGHT)
    if canContinue then
      box("fill", 22, 61, 116, 22, DARK)
      outline(22, 61, 116, 22, PAPER)
      centered("TAP TO CONTINUE", 69, PAPER)
    end
  end

  local function drawDialogueChoice(top, labels)
    header("CHOOSE")
    if #labels == 2 then
      centered("MAKE A CHOICE", 37, DARK)
      button(6, 62, 72, 44, labels[1], top.index == 1)
      button(82, 62, 72, 44, labels[2], top.index == 2)
    else
      local start, count = choiceWindow(labels, top.index)
      for row = 1, count do
        local index = start + row - 1
        button(8, 24 + (row - 1) * 27, 144, 24,
               labels[index], top.index == index)
      end
    end
    if choiceNudgeUntil > love.timer.getTime() then
      centered("PAUSE THEN CHOOSE", 134, DARK)
    end
  end

  local function drawMapFallback()
    local townMap = game.data.field and game.data.field.townMap
    local locations = townMap and (townMap.locations or townMap) or {}
    for id, entry in pairs(locations) do
      local c = entry.coords or entry
      local x, y = tonumber(c.x or c.col), tonumber(c.y or c.row)
      if x and y then
        local px, py = 22 + x * 7, 24 + y * 6
        box("fill", px, py, 4, 4, id == mapId and INK or DARK)
      end
    end
  end

  local function entryCoords(entry)
    local c = entry and (entry.coords or entry)
    return c and tonumber(c.x or c.col), c and tonumber(c.y or c.row)
  end

  local function mapPoint(entry)
    local x, y = entryCoords(entry)
    if not (x and y) then return nil end
    return 20 + (x * 8 + 16) * 0.75,
           22 + y * 8 * 0.75
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

  local function drawMap()
    header(canFly() and "MAP + FLY" or "MAP")
    local asset = loadMap()
    if asset then
      color({ 1, 1, 1, 1 })
      for i, tile in ipairs(asset.map) do
        local quad = asset.quads[tile]
        if quad then
          local col, row = (i - 1) % 20, math.floor((i - 1) / 20)
          if row > 0 then
            G.draw(asset.image, quad, 20 + col * 6, 22 + (row - 1) * 6, 0, 0.75, 0.75)
          end
        end
      end
      local px, py = mapPoint(locationEntry(mapId))
      if px then
        box("fill", px + 0.5, py + 0.5, 5, 5, PAPER)
        outline(px + 0.5, py + 0.5, 5, 5, INK)
      end
    else
      drawMapFallback()
    end
    box("fill", 4, 126, 152, 14, DARK)
    centered(areaName(mapId), 130, PAPER)
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

  local function foot(x, y)
    box("fill", x + 7, y, 7, 11, DARK)
    box("fill", x + 2, y + 8, 11, 9, DARK)
    box("fill", x, y + 4, 3, 4, DARK)
    box("fill", x + 4, y + 1, 3, 4, DARK)
  end

  local function drawSteps()
    header("STEPS")
    foot(69, 29)
    centered(tostring(steps), 55, INK, 2)
    centered("TOTAL", 82, DARK)
    button(34, 105, 92, 28, "RESET", false)
  end

  local function drawGuide()
    local guide = guideData()
    guidePage = math.max(1, math.min(guidePage, guide.pages))
    header(("GUIDE %d/%d"):format(guidePage, guide.pages))
    text(fit(guide.name, 15), 4, 23, DARK)
    text(("DEX %d/%d"):format(guide.dexCaught, guide.dexTotal), 94, 23, INK)

    box("fill", 4, 34, 152, 12, guide.complete and DARK or MID)
    local status = guide.complete and "+ AREA COMPLETE +"
      or #guide.rows > 0 and ("AREA " .. guide.caught .. "/" .. #guide.rows)
      or "NO WILD ENCOUNTERS"
    centered(status, 37, guide.complete and PAPER or INK)

    for slot = 1, 3 do
      local row = guide.rows[(guidePage - 1) * 3 + slot]
      if row then
        local y = 48 + (slot - 1) * 31
        box("fill", 3, y, 154, 29, row.caught and MID or PAPER)
        outline(3, y, 154, 29, INK)
        local tint = not row.caught and DARK or nil
        drawSprite(row.species, "front", 5, y + 1, 27, 27, tint)
        text(fit(row.name, 12), 35, y + 3, INK)
        if row.caught then text("CAUGHT", 113, y + 3, DARK) end
        local levels = row.minLevel == row.maxLevel
          and ("L" .. row.minLevel)
          or ("L" .. row.minLevel .. "-" .. row.maxLevel)
        local methods1, methods2 = methodLines(row.methods)
        text(methods1, 35, y + 13, DARK)
        text(methods2, 35, y + 21, DARK)
        text(levels, 122, y + 15, DARK)
      end
    end
  end

  local function drawArea()
    local area = areaData()
    areaPage = math.max(1, math.min(areaPage, area.pages))
    local screen = area.screens[areaPage]
    header(("AREA %d/%d"):format(areaPage, area.pages))
    text(fit(area.name, 23), 5, 23, DARK)
    local complete = screen.total > 0 and screen.done == screen.total
    box("fill", 4, 34, 152, 12, complete and DARK or MID)
    local status = screen.total == 0 and ("NO " .. screen.name)
      or complete and ("+ " .. screen.name .. " CLEARED +")
      or ("%s %d/%d"):format(screen.name, screen.done, screen.total)
    centered(status, 37, complete and PAPER or INK)

    for slot = 1, screen.perPage do
      local row = screen.rows[(screen.page - 1) * screen.perPage + slot]
      if row then
        local y = 49 + (slot - 1) * 22
        box("fill", 3, y, 154, 20, row.done and MID or PAPER)
        outline(3, y, 154, 20, INK)
        text(fit(row.label, 18), 8, y + 7, INK)
        text(row.done and "DONE" or "OPEN", 128, y + 7, DARK)
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
      or ("SIGNALS " .. #signals), 132, DARK)
  end

  local function drawTools()
    header("TOOLS")
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
    for i, action in ipairs(tools) do
      if i > 6 then break end
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
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
      local def = game.data.pokemon[mon.species]
      out[i] = {
        slot = i, species = mon.species,
        name = mon.nickname or (def and def.name) or mon.species,
        level = mon.level, hp = mon.hp,
        maxHp = mon.stats and mon.stats.hp or mon.hp,
        status = mon.status,
      }
    end
    return out
  end

  local function partyCard(mon, x, y, selected)
    box("fill", x, y, 75, 36, selected and DARK or MID)
    outline(x, y, 75, 36, INK)
    if not mon then
      text("-", x + 35, y + 14, DARK)
      return
    end
    drawSprite(mon.species, "front", x + 2, y + 2, 27, 27)
    text(fit(mon.name, 7), x + 29, y + 4, selected and PAPER or INK)
    text("L" .. tostring(mon.level or 0), x + 29, y + 14,
         selected and PAPER or DARK)
    hpBar(x + 29, y + 25, 41, mon.hp, mon.maxHp)
    if (mon.hp or 0) <= 0 then
      text("FNT", x + 52, y + 14, selected and PAPER or INK)
    elseif mon.status then
      text(fit(mon.status, 3), x + 52, y + 14, selected and PAPER or INK)
    end
  end

  local function drawParty(list, title, back, activeSpecies, selectedSlot)
    header(title or "PARTY", back)
    for i = 1, 6 do
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
      local mon = list[i]
      partyCard(mon, 3 + col * 78, 23 + row * 39,
                selectedSlot and selectedSlot == i
                  or (not selectedSlot and mon and (mon.active
                    or (activeSpecies and mon.species == activeSpecies))))
    end
  end

  local function drawNormalParty()
    drawParty(partyData(), "PARTY", false)
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

  local function drawBattleRoot()
    header("BATTLE")
    button(3, 24, 76, 54, "FIGHT", battle.menuIndex == 1)
    button(81, 24, 76, 54, "PKMN", battle.menuIndex == 2)
    button(3, 81, 76, 56, "ITEM", battle.menuIndex == 3)
    button(81, 81, 76, 56, "RUN", battle.menuIndex == 4)
  end

  local function drawSafari()
    header("SAFARI")
    button(3, 24, 76, 54, "BALL x" .. tostring(battle.safariBalls or 0),
           battle.menuIndex == 1)
    button(81, 24, 76, 54, "BAIT", battle.menuIndex == 2)
    button(3, 81, 76, 56, "THROW ROCK", battle.menuIndex == 3)
    button(81, 81, 76, 56, "RUN", battle.menuIndex == 4)
  end

  local function drawMimic()
    header("MIMIC")
    for i, move in ipairs(battle.mimicMoves or {}) do
      button(8, 25 + (i - 1) * 28, 144, 25,
             move.name or move.id or tostring(i), battle.mimicIndex == i)
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

  local function moveCard(move, x, y, selected)
    local disabled = move.disabled or move.pp <= 0
    local dark = disabled or selected
    box("fill", x, y, 76, 53, dark and DARK or MID)
    outline(x, y, 76, 53, INK)
    text(fit(move.name, 10), x + 4, y + 4, dark and PAPER or INK)
    text(("PP %d/%d"):format(move.pp or 0, move.maxPp or 0), x + 4, y + 19,
         dark and PAPER or DARK)
    text(fit(move.type or "STATUS", 7), x + 4, y + 34,
         dark and PAPER or DARK)
    if assist("type_hints") then
      text(effectLabel(move.effectiveness), x + 56, y + 34,
           dark and PAPER or INK)
    end
    if assist("move_details") then
      outline(x + 63, y + 2, 11, 11, dark and PAPER or INK)
      text("?", x + 66, y + 4, dark and PAPER or INK)
    end
  end

  local function drawMoves()
    header("MOVES", true)
    for i = 1, 4 do
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
      local move = battle.moves[i]
      if move then
        moveCard(move, 3 + col * 78, 24 + row * 56,
                 battle.moveIndex == i)
      end
    end
  end

  local function drawMoveInfo(move)
    header(fit(move.name, 12), true)
    box("fill", 12, 29, 136, 104, MID)
    outline(12, 29, 136, 104, INK)
    centered(move.type or "STATUS", 39, INK, 2)
    text("POWER", 25, 72, DARK)
    text(tostring(move.displayPower or "--"), 108, 72, INK)
    text("HIT CHANCE", 25, 86, DARK)
    text(chanceLabel(move.hitChance), 98, 86, INK)
    text("PP", 25, 100, DARK)
    text(("%d/%d"):format(move.pp or 0, move.maxPp or 0), 88, 100, INK)
    if assist("type_hints") then
      text("EFFECT", 25, 114, DARK)
      text(effectLabel(move.effectiveness), 108, 114, INK)
    end
  end

  local function drawBattleParty(menu)
    if menu.submenu then
      header(fit((battle.party[menu.index] or {}).name or "POKEMON", 12), true)
      for i, item in ipairs(menu.subItems or {}) do
        button(14, 29 + (i - 1) * 35, 132, 30,
               item.label or tostring(i), menu.subIndex == i)
      end
      return
    end
    drawParty(battle.party or {}, "PARTY", true, nil, menu.index)
  end

  local function drawBattleItems(menu)
    header("ITEMS", true)
    local odds = {}
    if assist("catch_odds") then
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
             (item.label or tostring(index)) .. " " .. right,
             menu.index == index)
    end
  end

  local function drawPpItemMoves(menu)
    header("CHOOSE MOVE", true)
    for i, item in ipairs(menu.items or {}) do
      button(8, 25 + (i - 1) * 28, 144, 25,
             (item.label or tostring(i)) .. "  PP " .. (item.right or "--"),
             menu.index == i)
    end
  end

  local function drawBattleSummary(summary)
    local mon, data = summary.mon, game.data
    local def = data.pokemon[mon.species] or {}
    local page, level = summary.page or 1, mon.level or 0
    header("STATS " .. page .. "/2")
    if page == 1 then
      local stats = mon.stats or {}
      local TypeChart = require("src.battle.TypeChart")
      local function typeName(index)
        local id = def.types and def.types[index]
        return id and TypeChart.displayName(id) or "--"
      end
      drawSprite(mon.species, "front", 4, 23, 43, 43)
      text(fit(mon.nickname or def.name or mon.species, 17), 51, 24, INK)
      text(("NO.%03d LV.%d"):format(def.dex or 0, level),
           51, 36, DARK)
      text(("HP %d/%d"):format(mon.hp or 0, stats.hp or 0), 51, 48, INK)
      hpBar(51, 59, 105, mon.hp, stats.hp)
      text("STATUS " .. (mon.status or "OK"), 51, 65, DARK)
      box("fill", 4, 76, 152, 1, DARK)
      text("ATK " .. tostring(stats.attack or 0), 5, 81, INK)
      text("DEF " .. tostring(stats.defense or 0), 5, 92, INK)
      text("SPD " .. tostring(stats.speed or 0), 5, 103, INK)
      text("SPC " .. tostring(stats.special or 0), 5, 114, INK)
      text("TYPE1 " .. typeName(1), 77, 81, DARK)
      text("TYPE2 " .. typeName(2), 77, 92, DARK)
      text("OT " .. fit(mon.ot or game.save.player.name or "RED", 10),
           77, 103, DARK)
      text(("ID %05d"):format(mon.otId or game.save.player.id or 0),
           77, 114, DARK)
    else
      text(fit(mon.nickname or def.name or mon.species, 17), 5, 25, INK)
      text("LV." .. tostring(level), 116, 25, DARK)
      text("EXP " .. tostring(mon.exp or 0), 5, 39, DARK)
      if level < 100 then
        local Growth = require("src.pokemon.Growth")
        local nextExp = math.max(0,
          Growth.expForLevel(def.growthRate, level + 1) - (mon.exp or 0))
        text(("NEXT L.%d %d"):format(level + 1, nextExp), 5, 51, DARK)
      else
        text("NEXT MAX", 5, 51, DARK)
      end
      box("fill", 4, 61, 152, 1, DARK)
      for i = 1, 4 do
        local move = mon.moves and mon.moves[i]
        local moveDef = move and data.moves[move.id]
        local maxPP = moveDef and (moveDef.pp
          + (move.ppUps or 0) * math.floor(moveDef.pp / 5)) or 0
        local y = 66 + (i - 1) * 14
        text(fit(moveDef and moveDef.name or move and move.id or "-", 14),
             6, y, INK)
        text(move and ("PP %d/%d"):format(move.pp or 0, maxPP)
          or "PP --", 103, y, DARK)
      end
    end
    button(103, 125, 53, 15, page == 1 and "NEXT" or "CLOSE", false)
  end

  local function drawPcRoot(kind, root)
    if kind == "items" then
      header("ITEM PC")
      local labels = { "WITHDRAW", "DEPOSIT", "TOSS", "LOG OFF" }
      for i, label in ipairs(labels) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        button(3 + col * 78, 24 + row * 57, 76, row == 0 and 54 or 56,
               label, root.index == i)
      end
      return
    end

    local boxes = game.save.boxes or {}
    local current = game.save.currentBox or 1
    header("POKEMON PC")
    centered(("BOX %d  %d/20"):format(current, #(boxes[current] or {})),
             22, DARK)
    local labels = { "WITHDRAW", "DEPOSIT", "RELEASE", "BOXES" }
    for i, label in ipairs(labels) do
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
      button(3 + col * 78, 34 + row * 40, 76, 36, label, root.index == i)
    end
    local extras = #root.items - 4
    if extras == 1 then
      button(18, 116, 124, 24, "LOG OFF", root.index == 5)
    else
      button(3, 116, 76, 24, "PRINT", root.index == 5)
      button(81, 116, 76, 24, "LOG OFF", root.index == 6)
    end
  end

  local function pcMonCard(mon, x, y, selected)
    box("fill", x, y, 76, 45, selected and DARK or MID)
    outline(x, y, 76, 45, INK)
    if not mon then return end
    local def = game.data.pokemon[mon.species] or {}
    drawSprite(mon.species, "front", x + 2, y + 3, 32, 32)
    text(fit(mon.nickname or def.name or mon.species, 6), x + 35, y + 9,
         selected and PAPER or INK)
    text("LV." .. tostring(mon.level or 0), x + 35, y + 25,
         selected and PAPER or DARK)
  end

  local function drawPcBoxList(list)
    local boxes = game.save.boxes or {}
    local current = game.save.currentBox or 1
    local mons = boxes[current] or {}
    local first, count = pageWindow(list.index, #list.items)
    local action = ({ pc_box_withdraw = "WITHDRAW",
      pc_box_release = "RELEASE" })[list.kind] or "POKEMON"
    header(action, true)
    local pages = math.max(1, math.ceil(#list.items / 4))
    centered(("BOX %d  %d/20  %d/%d"):format(current, #mons,
      math.floor((math.max(1, list.index) - 1) / 4) + 1, pages), 22, DARK)
    if #list.items == 0 then
      centered("NOTHING HERE", 61, INK)
      button(34, 101, 92, 28, "BACK", false)
      return
    end
    for slot = 1, count do
      local index = first + slot - 1
      local col, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
      local item = list.items[index]
      pcMonCard(mons[item and item.value or index],
        3 + col * 78, 38 + row * 49, list.index == index)
    end
  end

  local function drawPcBoxChange(list)
    local boxes = game.save.boxes or {}
    local current = game.save.currentBox or 1
    header("CHANGE BOX", true)
    centered("BOX  USED", 22, DARK)
    for i = 1, 12 do
      local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
      local label = (i == current and "*" or "")
        .. i .. " " .. #(boxes[i] or {})
      button(3 + col * 52, 33 + row * 27, 50, 24,
             label, list.index == i)
    end
  end

  local function drawPcItemList(list)
    local titles = { pc_item_withdraw = "WITHDRAW",
      pc_item_deposit = "DEPOSIT", pc_item_toss = "TOSS" }
    header(titles[list.kind] or "ITEMS", true)
    if #list.items == 0 then
      centered("NOTHING HERE", 56, INK)
      button(34, 94, 92, 30, "BACK", false)
      return
    end
    local first, count = pageWindow(list.index, #list.items)
    for row = 1, count do
      local index, item = first + row - 1, list.items[first + row - 1]
      button(8, 25 + (row - 1) * 28, 144, 25,
             (item.label or tostring(index)) .. " " .. (item.right or ""),
             list.index == index)
    end
    centered(("PAGE %d/%d"):format(math.floor((list.index - 1) / 4) + 1,
      math.max(1, math.ceil(#list.items / 4))), 136, DARK)
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
    if top and top.screenId == "SummaryMenu" then
      drawBattleSummary(top)
    elseif kind == "items" and top and top.qty and top.max and top.onDone then
      drawPcQuantity(top, list)
    elseif list and list.kind == "pc_box_deposit" then
      drawParty(partyData(), "DEPOSIT", true, nil, list.index)
    elseif list and (list.kind == "pc_box_withdraw"
        or list.kind == "pc_box_release") then
      drawPcBoxList(list)
    elseif list and list.kind == "pc_box_change" then
      drawPcBoxChange(list)
    elseif list and list.kind:find("^pc_item_") then
      drawPcItemList(list)
    else
      drawPcRoot(kind, root)
    end
  end

  local function drawBattleLocked()
    header("BATTLE")
    if mod.options:get("hide_upper_battle_ui")
        and battle.message and #battle.message > 0 then
      box("fill", 6, 30, 148, 106, DARK)
      outline(6, 30, 148, 106, PAPER)
      local first = math.max(1, #battle.message - 1)
      text(fit(battle.message[first], 22), 14, 51, PAPER)
      text(fit(battle.message[first + 1] or "", 22), 14, 72, PAPER)
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

  local function drawBattle()
    local top = game and game.stack and game.stack:top()
    local party = top and top.isPartyMenu and top
    local bag = top and top.screenId == "BagMenu" and top
    local ppMoves = top and top.kind == "pp_item_move" and top
    local summary = top and top.screenId == "SummaryMenu"
      and screenById("PartyMenu") and top
    if ppMoves then
      drawPpItemMoves(ppMoves)
    elseif party then
      drawBattleParty(party)
    elseif bag then
      drawBattleItems(bag)
    elseif summary then
      drawBattleSummary(summary)
    elseif battle.prompt == "safari" then
      drawSafari()
    elseif battle.prompt == "mimic" then
      drawMimic()
    elseif moveInfo then
      drawMoveInfo(moveInfo)
    elseif battle.prompt == "moves" then
      drawMoves()
    elseif battle.prompt ~= "menu" then
      drawBattleLocked()
    else
      drawBattleRoot()
    end
  end

  local function moveDef(id)
    return game and game.data and game.data.moves and game.data.moves[id]
  end

  local function drawLearnMove(learn, top)
    local newDef = moveDef(learn.newMoveId) or {}
    local newName = newDef.name or learn.newMoveId or "MOVE"
    if learn.selecting and top == learn then
      header("FORGET MOVE")
      text(fit(newName, 14), 5, 25, INK)
      text(fit(newDef.type or "STATUS", 8), 101, 25, DARK)
      for i = 1, 4 do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local mv = learn.mon.moves[i]
        local def = mv and moveDef(mv.id) or {}
        button(3 + col * 78, 43 + row * 33, 76, 29,
               def.name or (mv and mv.id) or "-", learn.index == i)
      end
      button(34, 112, 92, 25, "CANCEL", learn.index == 5)
      return
    end

    header("NEW MOVE")
    drawSprite(learn.mon.species, "front", 5, 25, 42, 42)
    local monDef = game.data.pokemon[learn.mon.species] or {}
    text(fit(learn.mon.nickname or monDef.name or learn.mon.species, 16),
         51, 27, DARK)
    text(fit(newName, 16), 51, 42, INK)
    if assist("move_details") then
      text(fit(newDef.type or "STATUS", 9), 51, 56, DARK)
      text("PP " .. tostring(newDef.pp or 0), 112, 56, DARK)
    end
    box("fill", 7, 75, 146, 1, DARK)
    centered("FOLLOW TOP SCREEN", 83, INK)
    if top and top.onChoose and (top.index == 1 or top.index == 2) then
      button(18, 106, 58, 27, "YES", top.index == 1)
      button(84, 106, 58, 27, "NO", top.index == 2)
    elseif top and top.isTextBox then
      drawDim(0.48, top.waiting or (top.done and not top.choice))
    end
  end

  local function draw()
    G.push("all")
    G.setCanvas(canvas)
    G.origin()
    G.setScissor()
    G.setShader()
    G.setBlendMode("alpha")
    G.clear(PAPER[1], PAPER[2], PAPER[3], PAPER[4])
    G.setLineWidth(1)
    local mode, top, fade = screenState()
    local learn = screenById("MoveLearnMenu")
    local pcKind, pcRoot = pcSession()
    local choice, labels = dialogueChoice()
    if learn then
      drawLearnMove(learn, top)
    elseif choice then
      drawDialogueChoice(choice, labels)
    elseif battle then
      drawBattle()
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
    elseif page == "GUIDE" then
      drawGuide()
    elseif page == "AREA" then
      drawArea()
    elseif page == "STEPS" then
      drawSteps()
    elseif page == "PARTY" then
      drawNormalParty()
    else
      drawTools()
    end
    if not learn and not battle and not choice
        and not (pcKind and mode == "locked")
        and mode ~= "title" and mode ~= "active" then
      drawDim(fade, mode == "textbox"
        and top and (top.waiting or top.done) and not top.choice)
      if mode == "loading" then
        box("fill", 27, 57, 106, 30, DARK)
        outline(27, 57, 106, 30, PAPER)
        centered("LOADING AREA", 69, PAPER)
      end
    end
    if not learn and not battle and mode == "active" then
      if pendingFly then drawFlyPrompt()
      elseif pendingAction then drawActionPrompt() end
    end
    outline(1, 1, WIDTH - 2, HEIGHT - 2, INK)
    G.setCanvas()
    G.pop()
  end

  local function pumpDisplay()
    local shown = false
    if readbackPending then
      local image = canvas:pollImageData()
      if image then
        shown = system.presentSecondaryDisplay(image, SECONDARY_BACKGROUND,
          mod.options:get("display_target"))
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
      nextBattle.partyIndex = top and top.isPartyMenu and top.index or nil
      nextBattle.subIndex = top and top.isPartyMenu and top.submenu
        and top.subIndex or nil
      nextBattle.itemIndex = top and top.screenId == "BagMenu"
        and top.index or nil
      nextBattle.summaryPage = top and top.screenId == "SummaryMenu"
        and top.page or nil
      for _, side in ipairs({ "player", "enemy" }) do
        local source, copy = raw and raw[side], nextBattle[side]
        if source and copy then
          copy.hp = math.max(0, math.floor(source.shownHP
            or source.mon.hp or copy.hp or 0))
          copy.status = source.shownStatus or copy.status
        end
      end
    end
    local changed = (not battle) ~= (not nextBattle)
      or (battle and nextBattle and battle.revision ~= nextBattle.revision)
      or (battle and nextBattle and battleFocusChanged(battle, nextBattle))
      or (battle and nextBattle and (
        (battle.player and battle.player.hp) ~= (nextBattle.player and nextBattle.player.hp)
        or (battle.enemy and battle.enemy.hp) ~= (nextBattle.enemy and nextBattle.enemy.hp)))
    battle = nextBattle
    if changed then
      if not battle then
        moveInfo = nil
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
    if moveInfo then
      moveInfo = nil
    elseif battle and battle.prompt == "moves" then
      submit("back")
    end
    dirty = true
  end

  local function press(key)
    game.input:overlayPressed(key)
    game.input:overlayReleased(key)
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
    if top and top.isTextBox then
      if top.waiting or (top.done and not top.choice) then press("a") end
      return
    end
    if learn.selecting and top == learn then
      local slot
      if inside(x, y, 34, 112, 92, 25) then
        slot = #learn.mon.moves + 1
      elseif y >= 43 and y < 109 then
        local col, row = x >= 81 and 1 or 0, math.floor((y - 43) / 33)
        slot = row * 2 + col + 1
      end
      if slot and slot <= #learn.mon.moves + 1 then
        learn.index = slot
        press("a")
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

  local function tapBattle(x, y)
    local top = game and game.stack and game.stack:top()
    if top and top.kind == "pp_item_move" then
      if y < HEADER and x < 24 then
        press("b")
      else
        local row = math.floor((y - 25) / 28) + 1
        if x >= 8 and x < 152 and row >= 1
            and row <= #(top.items or {}) then
          top.index = row
          press("a")
        end
      end
      return
    end
    if top and top.screenId == "SummaryMenu" and screenById("PartyMenu") then
      if inside(x, y, 103, 125, 53, 15) then press("a") end
      return
    end
    if top and top.isPartyMenu then
      if y < HEADER and x < 24 then
        press("b")
      elseif top.submenu then
        local index = math.floor((y - 29) / 35) + 1
        if x >= 14 and x < 146 and index >= 1
            and index <= #(top.subItems or {}) then
          top.subIndex = index
          press("a")
        end
      elseif y >= 23 then
        local col, row = x >= 81 and 1 or 0, math.floor((y - 23) / 39)
        local slot = row * 2 + col + 1
        if battle.party[slot] then
          top.index = slot
          press("a")
        end
      end
      return
    end
    if top and top.screenId == "BagMenu" then
      if y < HEADER and x < 24 then
        press("b")
      else
        local first, count = choiceWindow(top.items or {}, top.index)
        local row = math.floor((y - 25) / 28) + 1
        if x >= 8 and x < 152 and row >= 1 and row <= count then
          top.index = first + row - 1
          press("a")
        end
      end
      return
    end
    if battle.prompt == "safari" then
      if y < 24 then return end
      local col, row = x >= 81 and 1 or 0, y >= 81 and 1 or 0
      local action = ({ "ball", "bait", "rock", "run" })[row * 2 + col + 1]
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
    if y < HEADER and x < 24
       and (moveInfo or battle.prompt == "moves") then
      back()
      return
    end
    if moveInfo or battle.prompt == "locked" then return end
    if battle.prompt == "advance" then
      submit("advance")
      return
    end
    if battle.prompt == "moves" then
      if y < 24 or y >= 136 then return end
      local col, row = x >= 81 and 1 or 0, y >= 80 and 1 or 0
      local slot = row * 2 + col + 1
      local move = battle.moves[slot]
      if not move then return end
      local cardX, cardY = 3 + col * 78, 24 + row * 56
      if assist("move_details")
          and inside(x, y, cardX + 62, cardY, 14, 14) then
        local raw = battleState()
        if raw then raw.moveIndex = slot end
        moveInfo = move
        dirty = true
      else
        submit("move", { slot = slot })
      end
      return
    end
    if battle.prompt ~= "menu" or y < 24 then return end
    local col, row = x >= 81 and 1 or 0, y >= 81 and 1 or 0
    local choice = row * 2 + col + 1
    local raw = battleState()
    if raw and game.stack:top() == raw then
      raw.menuIndex = choice
      press("a")
    end
    dirty = true
  end

  local function tapPc(kind, root, top, x, y)
    if top and top.screenId == "SummaryMenu" then
      if inside(x, y, 103, 125, 53, 15) then press("a") end
      dirty = true
      return
    end

    local list = pcList()
    if kind == "items" and top and top.qty and top.max and top.onDone then
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
      elseif #list.items == 0 then
        if inside(x, y, 34, kind == "items" and 94 or 101,
                  92, kind == "items" and 30 or 28) then press("b") end
      elseif list.kind == "pc_box_deposit" and y >= 23 then
        local col, row = x >= 81 and 1 or 0, math.floor((y - 23) / 39)
        local index = row * 2 + col + 1
        if list.items[index] then list.index = index; press("a") end
      elseif list.kind == "pc_box_withdraw"
          or list.kind == "pc_box_release" then
        local first, count = pageWindow(list.index, #list.items)
        for slot = 1, count do
          local col, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
          if inside(x, y, 3 + col * 78, 38 + row * 49, 76, 45) then
            list.index = first + slot - 1
            press("a")
            break
          end
        end
      elseif list.kind == "pc_box_change" then
        for i = 1, math.min(12, #list.items) do
          local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
          if inside(x, y, 3 + col * 52, 33 + row * 27, 50, 24) then
            list.index = i
            press("a")
            break
          end
        end
      else
        local first, count = pageWindow(list.index, #list.items)
        local row = math.floor((y - 25) / 28) + 1
        if x >= 8 and x < 152 and row >= 1 and row <= count then
          list.index = first + row - 1
          press("a")
        end
      end
      dirty = true
      return
    end

    if top ~= root then return end
    if kind == "items" then
      for i = 1, 4 do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        if inside(x, y, 3 + col * 78, 24 + row * 57,
                  76, row == 0 and 54 or 56) then
          root.index = i
          press("a")
          break
        end
      end
    else
      for i = 1, 4 do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        if inside(x, y, 3 + col * 78, 34 + row * 40, 76, 36) then
          root.index = i
          press("a")
          dirty = true
          return
        end
      end
    end
    if kind == "pokemon" and y >= 116 then
      local extras = #root.items - 4
      local index = extras == 1 and 5 or (x >= 81 and 6 or 5)
      if root.items[index] then root.index = index; press("a") end
    end
    dirty = true
  end

  local function tapDialogueChoice(top, labels, x, y)
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
    if #labels == 2 then
      if inside(x, y, 6, 62, 72, 44) then selected = 1 end
      if inside(x, y, 82, 62, 72, 44) then selected = 2 end
    else
      local start, count = choiceWindow(labels, top.index)
      for row = 1, count do
        if inside(x, y, 8, 24 + (row - 1) * 27, 144, 24) then
          selected = start + row - 1
          break
        end
      end
    end
    if not selected then return end
    top.index = selected
    if top.clampScroll then top:clampScroll() end
    choiceCommitted = top
    press("a")
  end

  local function tap(x, y)
    local learn = screenById("MoveLearnMenu")
    if learn then
      tapLearn(learn, game.stack:top(), x, y)
      return
    end
    local choice, labels = dialogueChoice()
    if choice then
      tapDialogueChoice(choice, labels, x, y)
      return
    end
    local mode, top = screenState()
    if mode == "title" then
      press("a")
      return
    end
    if battle then
      tapBattle(x, y)
      return
    end
    if mode == "textbox" then
      if top and (top.waiting or top.done) and not top.choice then
        press("a")
      end
      return
    end
    local pcKind, pcRoot = pcSession()
    if pcKind then
      tapPc(pcKind, pcRoot, top, x, y)
      return
    end
    if mode ~= "active" then return end
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
    if page == "AREA" and assist("item_radar") then
      local area = areaData()
      local screen = area.screens[math.max(1, math.min(areaPage, area.pages))]
      if screen.name == "HIDDEN" and hasItemfinder()
          and inside(x, y, 20, 118, 120, 20) then
        radarOpen, radarFrame, radarStarted = true, 0, love.timer.getTime()
        dirty = true
      end
      return
    elseif page == "STEPS" and inside(x, y, 34, 105, 92, 28) then
      steps = 0
      mod.save:set("steps", steps)
      dirty = true
      mod.log:info("step counter reset")
    elseif page == "PARTY" and y >= 23 then
      local col, row = x >= 81 and 1 or 0, math.floor((y - 23) / 39)
      local mon = game.save.party[row * 2 + col + 1]
      if mon then
        local ok, err = pcall(function()
          require("src.core.Sound").playCry(game.data, mon.species)
        end)
        if not ok then mod.log:warn("cry failed: %s", tostring(err)) end
      end
    elseif page == "TOOLS" then
      for i, action in ipairs(tools) do
        if i > 6 then break end
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
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
    if pendingFly or pendingAction or fieldChoice or screenById("MoveLearnMenu")
        or dialogueChoice() or radarOpen then return end
    if not pageSwipeAllowed(screenState(), battle) then return end
    refreshTools()
    local names = pageNames()
    local index = 1
    for i, name in ipairs(names) do
      if name == page then index = i break end
    end
    index = ((index - 1 + (dx < 0 and 1 or -1)) % #names) + 1
    page = names[index]
    mod.log:info("page %s", page)
    dirty = true
  end

  local function swipeVertical(dy, allowPage)
    if radarOpen then return end
    local top = game and game.stack and game.stack:top()
    if pcSession() and pcListKind(top) and #(top.items or {}) > 4 then
      top.index = pagedIndex(top.index, #top.items, dy < 0 and 1 or -1)
      dirty = true
      return
    end
    if top and top.screenId == "BagMenu" and #(top.items or {}) > 4 then
      top.index = pagedIndex(top.index, #top.items, dy < 0 and 1 or -1)
      dirty = true
      return
    end
    local choice, labels = dialogueChoice()
    if choice and #labels > 4 then
      choice.index = pagedIndex(choice.index, #labels, dy < 0 and 1 or -1)
      if choice.clampScroll then choice:clampScroll() end
      dirty = true
      return
    end
    if allowPage and pageSwipeAllowed(screenState(), battle)
        and not fieldChoice and (page == "GUIDE" or page == "AREA") then
      local pages_ = page == "GUIDE" and guideData().pages or areaData().pages
      local current = page == "GUIDE" and guidePage or areaPage
      current = math.max(1, math.min(pages_,
        current + (dy < 0 and 1 or -1)))
      if page == "GUIDE" then guidePage = current else areaPage = current end
      dirty = true
    end
  end

  local function touchEvent(value)
    local action, sx, sy = value:match("^(%a+),(%d+),(%d+)$")
    local x, y = tonumber(sx), tonumber(sy)
    if not action then
      sx, sy = value:match("^(%d+),(%d+)$")
      x, y, action = tonumber(sx), tonumber(sy), "tap"
    end
    if action == "down" and x then
      local mode = screenState()
      touchDown = { x = x, y = y,
        pageSwipe = pageSwipeAllowed(mode, battle),
        input = mode == "title" or mode == "active" or mode == "textbox" or battle
          or dialogueChoice() or screenById("MoveLearnMenu") or pcSession() }
    elseif action == "cancel" then
      touchDown = nil
    elseif action == "tap" and x then
      tap(x, y)
    elseif action == "up" and x and touchDown then
      local down = touchDown
      local dx, dy = x - down.x, y - down.y
      touchDown = nil
      if math.abs(dx) >= 24 and math.abs(dx) > math.abs(dy) * 1.25 then
        if down.pageSwipe then swipe(dx) end
      elseif math.abs(dy) >= 24 and math.abs(dy) > math.abs(dx) * 1.25 then
        swipeVertical(dy, down.pageSwipe)
      elseif dialogueChoice() and (math.abs(dx) >= 12 or math.abs(dy) >= 12) then
        return
      elseif down.input then
        tap(x, y)
      end
      mod.log:info("touch up x=%d y=%d", x, y)
    end
  end

  mod.events:on("game.ready", function(payload)
    game = payload.game
    refreshTheme(true)
    reloadSteps()
    local player = game.save and game.save.player
    mapId = player and player.map
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
    guidePage, areaPage = 1, 1
    radarOpen = false
  end)

  mod.events:on("mod.DRAMATIC_SHAPE.loading_changed", function(payload)
    externalLoading = payload and payload.loading == true
    dirty = true
  end)

  mod.events:on("mod.options_changed", function(payload)
    if payload and payload.mod == "kanto_gear" then
      if payload.key == "theme" then refreshTheme(true) end
      if not assist("move_details") then moveInfo = nil end
      if page == "GUIDE" and not assist("guide") then
        page = "MAP"
      end
      if page == "AREA" and not assist("area") then page = "MAP" end
      if not assist("item_radar") then radarOpen = false end
      dirty = true
    end
  end)

  mod.events:on("world.stepped", function(payload)
    steps = steps + 1
    mod.save:set("steps", steps)
    mapId = payload.mapId or mapId
    if radarOpen then radarOpen, dirty = false, true end
    if page == "STEPS" then dirty = true end
  end)

  mod.hooks:wrap("battle.bottom_ui_visible", function(next, state)
    if next(state) == false then return false end
    local raw = battleState()
    local top = game and game.stack and game.stack:top()
    local owned = bottomOwnsBattleUI(
      mod.options:get("hide_upper_battle_ui"), active,
      system.hasSecondaryDisplay(), displayReady, raw)
    return not (owned
      and (state == raw or (state == top and top.isTextBox)))
  end)

  mod.hooks:wrap("battle.move_grid_navigation", function(next, state)
    if next(state) == true then return true end
    return bottomOwnsBattleUI(
      mod.options:get("hide_upper_battle_ui"), active,
      system.hasSecondaryDisplay(), displayReady, state)
  end)

  mod.hooks:wrap("screen.render_visible", function(next, state)
    if next(state) == false then return false end
    local owned = bottomOwnsBattleUI(
      mod.options:get("hide_upper_battle_ui"), active,
      system.hasSecondaryDisplay(), displayReady, battleState())
    return not (owned and mirroredBattleMenu(state))
  end)

  for _, event in ipairs({
    "battle.started", "battle.turn_started", "battle.move_used",
    "battle.damage_dealt", "battle.status_inflicted",
    "battle.battler_switched", "battle.turn_ended", "battle.ended",
    "pokemon.caught",
  }) do
    mod.events:on(event, function() dirty = true end)
  end

  -- Existing render hook provides a tick without another engine patch.
  mod.hooks:wrap("render.letterbox", function(next, context)
    next(context)
    if not active then return end
    if not loggedTick then
      loggedTick = true
      mod.log:info("display available=%s", tostring(system.hasSecondaryDisplay()))
    end

    local now = love.timer.getTime()
    if now >= nextPoll then
      nextPoll = now + 0.05
      refreshTheme()
      for _ = 1, 32 do
        local event = system.pollSecondaryDisplayTouch()
        if not event then break end
        touchEvent(event)
      end
      refreshBattle()
      if page == "TOOLS" or pendingAction then refreshTools() end
      local mode, top = screenState()
      local learn = screenById("MoveLearnMenu")
      local currentPcList = pcList()
      local currentChoice = dialogueChoice()
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
        tostring(top and top.qty), tostring(top and top.page),
        tostring(currentPcList), tostring(currentPcList and currentPcList.index),
        tostring(learn and learn.selecting),
        tostring(learn and learn.index), tostring(externalLoading),
        tostring(pendingFly and pendingFly.id),
        tostring(pendingAction and pendingAction.id),
        tostring(fieldChoice and fieldChoice.kind),
        tostring(fieldChoice and fieldChoice.source
          and fieldChoice.source.slot) }, ":")
      if screenKey ~= lastScreenKey or mode == "transition" then
        lastScreenKey, dirty = screenKey, true
      end
    end
    if now >= nextClock then
      nextClock = now + 60
      dirty = true
    end
    local displayAvailable = system.hasSecondaryDisplay()
    if not displayAvailable then displayReady = false end
    if displayAvailable and not displayReady then dirty = true end
    if (dirty or readbackPending) and (readbackPending or displayAvailable
        or now >= nextPresentAttempt) then
      local shown = pumpDisplay()
      if shown and not loggedPresent then
        loggedPresent = true
        mod.log:info("first frame submitted=true")
      end
    end
  end, -1000)
end
