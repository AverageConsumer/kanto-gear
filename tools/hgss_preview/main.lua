local root = assert(os.getenv("KANTO_GEAR_ROOT"), "KANTO_GEAR_ROOT is missing")
local output = assert(os.getenv("KANTO_GEAR_PREVIEW_OUT"),
  "KANTO_GEAR_PREVIEW_OUT is missing")
local utf8 = require("utf8")

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
  for _, code in utf8.codes(tostring(value)) do
    out[#out + 1] = utf8.char(code)
  end
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

local languages = {
  en = {
    title = "PARTY", hp = "HP", exp = "EXP", stats = "STATS", swap = "SWAP",
    swapWith = "SWAP WITH?", useItemOn = "USE ITEM ON",
    names = { "FERALIGATR", "JUMPLUFF", "PIDGEOTTO", "SANDSLASH",
      "DROWZEE", "TAUROS" },
    types = {},
  },
  de = {
    title = "TEAM", hp = "KP", exp = "EP", stats = "WERTE", swap = "TAUSCHEN",
    swapWith = "TAUSCHEN MIT?", useItemOn = "ITEM NUTZEN",
    names = { "IMPERGATOR", "PAPUNGHA", "TAUBOGA", "SANDAMER",
      "TRAUMATO", "TAUROS" },
    types = { WATER = "WASSER", GRASS = "PFLANZE", FLYING = "FLUG",
      NORMAL = "NORMAL", GROUND = "BODEN", PSYCHIC = "PSYCHO" },
  },
  es = {
    title = "EQUIPO", hp = "PS", exp = "EXP",
    stats = "ESTADÍSTICAS", swap = "CAMBIAR", swapWith = "¿CAMBIAR POR?",
    useItemOn = "USAR OBJETO",
    names = { "FERALIGATR", "JUMPLUFF", "PIDGEOTTO", "SANDSLASH",
      "DROWZEE", "TAUROS" },
    types = { WATER = "AGUA", GRASS = "PLANTA", FLYING = "VOLADOR",
      NORMAL = "NORMAL", GROUND = "TIERRA", PSYCHIC = "PSÍQUICO" },
  },
  fr = {
    title = "ÉQUIPE", hp = "PV", exp = "EXP", stats = "STATS", swap = "ÉCHANGER",
    swapWith = "ÉCHANGER AVEC?", useItemOn = "UTILISER SUR",
    names = { "ALIGATUEUR", "COTOVOL", "ROUCOUPS", "SABLAIREAU",
      "SOPORIFIK", "TAUROS" },
    types = { WATER = "EAU", GRASS = "PLANTE", FLYING = "VOL",
      NORMAL = "NORMAL", GROUND = "SOL", PSYCHIC = "PSY" },
  },
}
local language = languages[os.getenv("KANTO_GEAR_PREVIEW_LANGUAGE") or "en"]
  or languages.en

local party = {
  { levelText = "L35", hp = 92, maxHp = 117,
    hpText = "92/117", statusId = "PAR", gender = "male", type = "WATER",
    type2 = "WATER",
    expProgress = 0.72 },
  { levelText = "L28", hp = 90, maxHp = 90,
    hpText = "90/90", gender = "female", type = "GRASS", type2 = "FLYING",
    expProgress = 0.18 },
  { levelText = "L28", hp = 81, maxHp = 81,
    hpText = "81/81", gender = "male", type = "NORMAL", type2 = "FLYING",
    expProgress = 0.91 },
  { levelText = "L25", hp = 67, maxHp = 80,
    hpText = "67/80", gender = "male", type = "GROUND", type2 = "GROUND",
    expProgress = 0.47 },
  { levelText = "L16", hp = 0, maxHp = 49,
    hpText = "0/49", statusId = "FNT",
    gender = "female", type = "PSYCHIC",
    type2 = "PSYCHIC",
    expProgress = 0.33 },
  { levelText = "L16", hp = 17, maxHp = 51,
    hpText = "17/51", statusId = "SLP", gender = "male", type = "NORMAL",
    type2 = "NORMAL",
    expProgress = 0.62 },
}

for slot, mon in ipairs(party) do
  mon.name = language.names[slot]
  mon.hpLabel = language.hp
  mon.expLabel = language.exp
  mon.typeLabel = language.types[mon.type] or mon.type
  mon.type2Label = language.types[mon.type2] or mon.type2
end
if os.getenv("KANTO_GEAR_PREVIEW_STATUSES") == "all" then
  for slot, status in ipairs({ "PAR", "SLP", "PSN", "BRN", "FRZ", "FNT" }) do
    party[slot].statusId = status
    if status == "FNT" then
      party[slot].hp, party[slot].hpText = 0, "0/51"
    elseif party[slot].hp == 0 then
      party[slot].hp, party[slot].hpText = 31, "31/49"
    end
  end
end

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
  local bagIcon = love.graphics.newImage(fileData(
    root .. "/mod/kanto_gear/kanto_bag.png", "kanto_bag.png"))
  bagIcon:setFilter("nearest", "nearest")
  local theme = chunk()({
    graphics = love.graphics, box = box, text = text,
    fit = fit, glyphs = glyphs, color = color, font = font,
    bagIcon = bagIcon,
  })
  theme:setVariant(os.getenv("KANTO_GEAR_PREVIEW_VARIANT") == "dark")
  assert(theme.backdropCenterY == 121,
    "every HGSS Pokeball backdrop shares the Party screen center")
  local blueFocus = theme:focusSurface(true, theme.colors.surface,
    theme.colors.blueLight)
  local redFocus = theme:focusSurface(true, theme.colors.red,
    theme.colors.redLight)
  local partyFocus = theme:focusSurface(true, theme.colors.party,
    theme.colors.partyLight)
  assert(blueFocus ~= theme.colors.focus and blueFocus[3] > blueFocus[1]
      and redFocus[1] > theme.colors.red[1]
      and partyFocus[2] > theme.colors.party[2]
      and theme:focusSurface(false, theme.colors.red,
        theme.colors.redLight) == theme.colors.red,
    "HGSS focus surfaces brighten their semantic color")
  assert(theme:partySlot(4, 22, 6) == 1
      and theme:partySlot(82, 25, 6) == 2
      and theme:partySlot(4, 60, 6) == 3
      and theme:partySlot(82, 101, 5) == nil,
    "party touch hitboxes follow the 240x216 card positions")
  assert(theme:battleEffectLabel({ powerText = "95", effectiveness = 20 })
      == "2X" and theme:battleEffectLabel({ powerText = "--",
        effectiveness = 20 }) == "--",
    "battle effectiveness labels distinguish damage and status moves")
  assert(theme:moveHasStab({ type = "WATER" },
      { type = "WATER", powerText = "95" })
      and not theme:moveHasStab({ type = "WATER" },
        { type = "WATER", powerText = "--" }),
    "STAB only marks matching damage moves")
  local bobUp, shadowSmall = theme:battleContinueMotion(0)
  local bobDown, shadowLarge = theme:battleContinueMotion(1)
  assert(bobUp == 0 and shadowSmall == 5
      and bobDown == 1 and shadowLarge == 9,
    "battle continue arrow and shadow animate together")
  assert(theme:statusColor("FNT") ~= theme:statusColor("SLP"),
    "fainted and sleep status colors must stay distinct")
  local first, count = theme:battleBagWindow({ index = 4,
    items = { {}, {}, {}, {}, {} } })
  assert(first == 2 and count == 4
      and theme:battleCatchLabel(80) == "80%"
      and theme:battleCatchLabel(79.7) == "79.7%",
    "battle bag window and catch labels stay deterministic")
  local bagTop = 33 + theme.battleBagOffsetY
  local bagBottom = 66 + 3 * 33 + 31 + theme.battleBagOffsetY
  assert(math.abs((bagTop - 28) - (216 - bagBottom)) <= 1,
    "battle bag content keeps equal visible top and bottom spacing")
  local actionX, actionY, actionW, actionH = theme:partyActionRow(1, 2)
  assert(theme:partyActionAt(actionX + actionW / 2,
    actionY + actionH / 2, 2) == 1, "first party action hitbox")
  theme:beginPartyAction(1)
  assert(theme:partyActionOffset(1) == 6
    and theme:partyActionOffset(1.14) == 0, "party action animation bounds")
  theme:endPartyAction(2)
  assert(theme:partyActionOffset(2) == 0
    and theme:partyActionOffset(2.139) == 6
    and theme:partyActionOffset(2.14) == 0
    and theme:partyActionClosed(2.14), "party action close animation bounds")
  theme:beginPartyAction(3)
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
  local screen = os.getenv("KANTO_GEAR_PREVIEW_SCREEN") or "party"
  local gen1 = os.getenv("KANTO_GEAR_PREVIEW_GEN") == "1"
  local battleRoot = screen == "battle_root"
  local battleMessage = screen == "battle_message"
  local battlePartyTransition = screen == "battle_party_transition"
  local battlePartyMenu = screen == "battle_party_menu"
  local battleMoves = screen == "battle_moves"
  local battleMovesTransition = screen == "battle_moves_transition"
  local battleMoveInfo = screen == "battle_move_info"
  local battleMoveInfoTransition = screen == "battle_move_info_transition"
  local battleBag = screen == "battle_bag"
  local battleBagTransition = screen == "battle_bag_transition"
  local explorerOverview = screen == "explorer"
  local explorerLayer = screen == "explorer_layer"
  local explorerDetail = screen == "explorer_detail"
  local explorerItems = screen == "explorer_items"
  local explorerItemDetail = screen == "explorer_item_detail"
  local explorerTrainers = screen == "explorer_trainers"
  local explorerTrainerDetail = screen == "explorer_trainer_detail"
  local explorer = explorerOverview or explorerLayer or explorerDetail
    or explorerItems or explorerItemDetail
    or explorerTrainers or explorerTrainerDetail
  local partySwap = screen == "party_swap"
  local partySwapTransition = screen == "party_swap_transition"
  local partySwapCommit = screen == "party_swap_commit"
  local swapMode = partySwap or partySwapTransition or partySwapCommit
  local context, summary = screen == "context", screen == "summary"
  local moves = screen == "summary_moves"
  local memo = screen == "summary_memo"
  local memoTransition = screen == "summary_memo_transition"
  local transition = screen == "summary_transition"
  local movesTransition = screen == "summary_moves_transition"
  local transitionProgress = math.max(0, math.min(1,
    tonumber(os.getenv("KANTO_GEAR_PREVIEW_PROGRESS")) or 0))
  local statsTitle = gen1 and "STATS 1/2" or "STATS 1/3"
  local movesTitle = gen1 and "MOVES 2/2" or "MOVES 2/3"
  local title = explorer and "EXPLORER"
    or os.getenv("KANTO_GEAR_PREVIEW_CONTEXT") == "item"
      and language.useItemOn
    or partySwap and language.swapWith
    or partySwapTransition
      and (transitionProgress >= 0.45 and language.swapWith or language.title)
    or partySwapCommit
      and (transitionProgress >= 0.72 and language.title or language.swapWith)
    or memo and "TRAINER 3/3"
    or memoTransition
      and (transitionProgress >= 0.5 and "TRAINER 3/3" or movesTitle)
    or moves and movesTitle
    or movesTransition
      and (transitionProgress >= 0.5 and movesTitle or statsTitle)
    or (summary or transition and transitionProgress >= 0.42) and statsTitle
    or language.title
  if not battleRoot and not battleMessage and not battlePartyTransition
      and not battlePartyMenu
      and not battleMoves and not battleMovesTransition
      and not battleMoveInfo and not battleMoveInfoTransition
      and not battleBag and not battleBagTransition then
    local headerOffset = summary and -1 or 0
    local titleX, titleWidth = theme:headerBar(title,
      explorer and not explorerOverview
        or swapMode or context or summary or moves or memo or memoTransition
        or transition or movesTransition,
      not explorer and not swapMode and (summary or moves or memo or memoTransition
        or movesTransition or transition and transitionProgress >= 0.42
        or not context), headerOffset)
    if context then
      local left, width = 26, 112
      assert(math.abs(titleX - left - (width - titleWidth - (titleX - left)))
        <= 1, "context title stays centered between dividers")
    end
    local clockLeft, clockWidth = 139, 72
    local clockX, periodX = theme:headerClock("20:04",
      os.getenv("KANTO_GEAR_PREVIEW_PERIOD") or "NITE",
      clockLeft, clockWidth, 6)
    local textWidth, iconWidth = theme:labelWidth("20:04"), 11
    local gaps = { clockX - clockLeft,
      periodX - 1 - (clockX + textWidth),
      clockLeft + clockWidth - (periodX - 1 + iconWidth) }
    table.sort(gaps)
    assert(gaps[3] - gaps[1] <= 1,
      "clock, period icon, and dividers keep equal spacing")
    theme:battery(214, 8, 4, nil, true, theme.colors.ink,
      theme.colors.greenLight)
  end
  if battleRoot or battleMessage or battlePartyTransition or battlePartyMenu
      or battleMoves or battleMovesTransition or battleMoveInfo
      or battleMoveInfoTransition or battleBag or battleBagTransition then
    -- Match the real app's 160x144 base rendered at the HGSS 1.5x scale.
    -- Individual screens may deliberately paint a foreground backdrop over it.
    love.graphics.push()
    love.graphics.scale(1.5, 1.5)
    theme:backdrop()
    love.graphics.pop()
  else
    theme:partyBackdrop()
  end
  local function drawPortrait(slot, portraitX, portraitY, size, fainted)
    local sprite = sprites[slot]
    local scale = size / math.max(sprite.width, sprite.height)
    local brightness = fainted and 0.48 or 1
    love.graphics.setColor(brightness, brightness, brightness, 1)
    love.graphics.draw(sprite.image, sprite.quad,
      portraitX + (size - sprite.width * scale) / 2,
      portraitY + (size - sprite.height * scale) / 2, 0, scale, scale)
  end
  local function drawMon(slot, x, y, selected, details, focused)
    theme:partyCard(party[slot], x, y, selected, details,
      function(_, portraitX, portraitY, size, fainted)
        drawPortrait(slot, portraitX, portraitY, size, fainted)
      end, focused)
  end
  local function drawExplorer()
    local colors = theme.colors
    local data = gen1 and {
      route = "ROUTE 15", region = "KANTO", caught = "4/9",
      items = "2/3", hidden = "0/1",
      encounters = {
        { "PIDGEOTTO", "20%", "L24-26", "NORMAL", "NOR", true },
        { "VENONAT", "30%", "L22-26", "POISON", "POI", true },
        { "DITTO", "10%", "L23", "NORMAL", "NOR" },
        { "GLOOM", "10%", "L22", "GRASS", "GRA", true },
        { "PIDGEY", "20%", "L22-26", "FLYING", "FLY" },
        { "ODDISH", "10%", "L24", "GRASS", "GRA", true },
      },
      chance = "20%", levels = "L24-26", period = "DAY",
    } or {
      route = "ROUTE 37", region = "JOHTO", caught = "3/9",
      items = "1/2", hidden = "0/1",
      encounters = {
        { "PIDGEOTTO", "30%", "L13-15", "NORMAL", "NOR", true },
        { "GROWLITHE", "20%", "L14", "FIRE", "FIR", true },
        { "STANTLER", "30%", "L15", "NORMAL", "NOR" },
        { "PIDGEY", "10%", "L13", "FLYING", "FLY", true },
        { "SPINARAK", "5%", "L13", "BUG", "BUG" },
        { "HOOTHOOT", "5%", "L14", "FLYING", "FLY" },
      },
      chance = "30%", levels = "L13-15", period = "DAY",
    }
    local items = gen1 and {
      { "SUPER POTION", "OPEN", "medicine", 7, 9, nil, "RESTORES 50 HP" },
      { "TM20", "FOUND", "machine", 30, 8, true },
      { "HIDDEN ITEM", "UNFOUND", "hidden", 38, 10 },
    } or {
      { "POTION", "OPEN", "medicine", 7, 9, nil, "RESTORES 20 HP" },
      { "TM11", "FOUND", "machine", 30, 8, true },
      { "HIDDEN ITEM", "UNFOUND", "hidden", 38, 10 },
    }
    local trainers = gen1 and {
      { "BIKER", "OPEN", "BIKER", 10, 8, "open" },
      { "BEAUTY", "BEATEN", "BEAUTY", 27, 11, "beaten" },
      { "JR.TRAINER", "OPEN", "JR.TRAINER", 36, 7, "open" },
    } or {
      { "DANA", "REMATCH", "LASS", 10, 8, "rematch" },
      { "GREG", "BEATEN", "PSYCHIC", 27, 11, "beaten" },
      { "ANN & ANNE", "OPEN", "TWINS", 36, 7, "open" },
    }
    local function routeOverview()
      local width, height = 42, 18
      local rows = {}
      for y = 1, height do
        local row = {}
        for x = 1, width do
          local path = y >= 6 and y <= 12
            or x >= 18 and x <= 24 and y >= 2 and y <= 17
            or x >= 7 and x <= 12 and y >= 4 and y <= 14
            or x >= 31 and x <= 37 and y >= 4 and y <= 14
          local water = x >= 26 and x <= 29 and y <= 5
            or x <= 5 and y >= 14
          row[x] = water and "~" or path and "." or " "
        end
        rows[y] = table.concat(row)
      end
      local function replace(row, column, value)
        rows[row] = rows[row]:sub(1, column - 1) .. value
          .. rows[row]:sub(column + 1)
      end
      replace(9, 1, "+")
      replace(9, width, "+")
      replace(height, 21, "+")

      local function detailedRows(density)
        local result = {}
        for py = 1, height * density do
          local values, cellY = {}, math.floor((py - 1) / density) + 1
          for px = 1, width * density do
            local cellX = math.floor((px - 1) / density) + 1
            local kind = rows[cellY]:sub(cellX, cellX)
            local subX, subY = (px - 1) % density, (py - 1) % density
            local shade
            if kind == "~" then
              shade = (subY + cellY) % 3 == 0 and 0 or 1
            elseif kind == "." then
              shade = (subX == 0 or subY == density - 1) and 1
                or (cellX * 3 + cellY + subX) % 11 == 0 and 2 or 0
            elseif kind == "+" then
              shade = (subX == 0 or subY == 0) and 2 or 1
            else
              shade = (cellX * 5 + cellY * 3 + subX + subY) % 4
            end
            values[#values + 1] = tostring(shade)
          end
          result[py] = table.concat(values)
        end
        return result
      end
      return {
        mapId = gen1 and 15 or 37, width = width, height = height, rows = rows,
        tileWidth = width * 2, tileHeight = height * 2,
        tileRows = detailedRows(2),
        tileDetailWidth = width * 4, tileDetailHeight = height * 4,
        tileDetailRows = detailedRows(4),
        markers = {
          { kind = "warp", x = 0, y = 8 },
          { kind = "warp", x = width - 1, y = 8 },
          { kind = "warp", x = 20, y = height - 1 },
        },
      }
    end
    local function trainerIcon(x, y, state)
      local tint = state == "beaten" and (theme.dark
          and colors.silver or colors.silverDark)
        or state == "rematch" and colors.blueLight or colors.redLight
      box("fill", x - 2, y - 9, 5, 1, colors.outline)
      box("fill", x - 4, y - 8, 9, 6, colors.outline)
      box("fill", x - 3, y - 2, 7, 3, colors.outline)
      box("fill", x - 6, y + 1, 13, 3, colors.outline)
      box("fill", x - 5, y + 4, 11, 5, colors.outline)
      box("fill", x - 2, y - 8, 5, 2, tint)
      box("fill", x - 3, y - 6, 7, 3, colors.amberLight)
      box("fill", x - 1, y - 2, 3, 3, colors.amberLight)
      box("fill", x - 4, y + 2, 9, 6, tint)
      if state == "beaten" then
        box("fill", x - 2, y + 4, 2, 2, colors.partyBg)
        box("fill", x, y + 6, 4, 2, colors.partyBg)
      elseif state == "rematch" then
        box("fill", x + 3, y - 4, 4, 1, colors.amberLight)
        box("fill", x + 5, y - 6, 1, 5, colors.amberLight)
      end
    end
    local mapX, mapY = 7, 59
    local compactMap = explorerLayer or explorerDetail
    local itemMap = explorerItems or explorerItemDetail
    local trainerMap = explorerTrainers or explorerTrainerDetail
    local fullMap = itemMap or trainerMap
    local mapW = (compactMap or fullMap) and 226 or 154
    local mapH = explorerDetail and 44 or explorerLayer and 38 or 103
    local foundTint = theme.dark and colors.silver or colors.silverDark
    assert(mapX + 154 + 5 + 67 == 233 and mapX + 226 == 233,
      "Explorer map, layer rail, and detail map share one content grid")

    theme:panel(7, 32, 226, 23, false)
    theme:partyInfo(data.route, 13, 38, colors.ink)
    theme:partyInfo(data.region, 177, 38, colors.green, 42, "center")
    theme:detailChevron(222, 41, colors.green)

    local overview, markers = routeOverview(), nil
    if itemMap then
      markers = {}
      for _, item in ipairs(items) do
        markers[#markers + 1] = {
          kind = item[3] == "hidden" and "hidden" or "item",
          x = item[4], y = item[5], found = item[6],
        }
      end
    elseif trainerMap then
      markers = {}
      for _, trainer in ipairs(trainers) do
        markers[#markers + 1] = {
          kind = "trainer", x = trainer[4], y = trainer[5], state = trainer[6],
        }
      end
    end
    theme:mapOverview(overview, mapX, mapY, mapW, mapH, {
      player = { x = 20, y = 8, facing = "down" },
      markers = markers,
      selected = (explorerItemDetail or explorerTrainerDetail) and 1 or nil,
      zoom = 1,
    })

    local function chip(x, y, width, label, active)
      theme:panel(x, y, width, 16, false)
      if active then box("fill", x + 2, y + 2, width - 4, 12, colors.band) end
      theme:partyType(label, x, y + 2, active and colors.ink or colors.green,
        width)
    end

    if explorerDetail then
      theme:panel(7, 107, 226, 103, false)
      theme:partyPortrait(16, 114, false, false)
      drawPortrait(3, 16, 117, 34, false)
      theme:partyInfo("PIDGEOTTO", 58, 115, colors.ink)
      theme:partyInfo("CAUGHT", 58, 130, colors.green)
      theme:typeBadges(party[3], 58, 144, false)
      theme:panel(157, 116, 68, 29, false)
      box("fill", 159, 118, 64, 25, colors.blueLight)
      theme:partyInfo("POKEDEX", 160, 125, colors.ink, 51, "center")
      theme:detailChevron(216, 126, colors.ink)
      local stats = {
        { "METHOD", "GRASS" }, { "CHANCE", data.chance },
        { "LEVEL", data.levels }, { "TIME", data.period },
      }
      for index, stat in ipairs(stats) do
        local x = 12 + (index - 1) * 54
        theme:panel(x, 163, 50, 39, false)
        theme:partyType(stat[1], x, 168, colors.green, 50)
        theme:partyInfo(stat[2], x, 183, colors.ink, 50, "center")
      end
      return
    end

    if explorerItemDetail then
      theme:panel(7, 166, 226, 44, false)
      theme:battleItemIcon({ icon = items[1][3] }, 14, 178,
        colors.amberLight)
      theme:partyInfo(items[1][1], 38, 172, colors.ink)
      theme:partyType(items[1][7], 38, 190, colors.green, 72)
      box("fill", 118, 171, 1, 34, colors.band)
      theme:partyType("OPEN", 124, 172, colors.green, 104)
      theme:partyInfo("NEAR LEDGE", 124, 188, colors.ink, 104, "center")
      return
    end

    if explorerTrainerDetail then
      local trainer = trainers[1]
      theme:panel(7, 166, 226, 44, false)
      trainerIcon(23, 186, trainer[6])
      theme:partyInfo(trainer[1], 39, 172, colors.ink)
      theme:partyType(trainer[3] .. (gen1 and "" or " / PHONE"),
        39, 190, colors.green, 72)
      box("fill", 118, 171, 1, 34, colors.band)
      theme:partyType(gen1 and "OPEN" or "REMATCH READY",
        124, 172, colors.green, 104)
      if gen1 then
        theme:partyInfo("TEAM UNKNOWN", 124, 188,
          colors.ink, 104, "center")
      else
        theme:partyInfo("LAST TEAM", 135, 187, colors.ink)
        for slot = 1, 3 do
          theme:battleTeamBall(189 + (slot - 1) * 12, 194, true)
        end
      end
      return
    end

    if explorerItems then
      chip(12, 64, 36, "ALL", true)
      chip(51, 64, 57, "HIDDEN", false)
      chip(111, 64, 54, "FOUND", false)
      theme:panel(174, 64, 52, 16, false)
      theme:partyType("1-3/4", 174, 66, colors.green, 42)
      theme:detailChevron(218, 69, colors.green)
      for index, item in ipairs(items) do
        local x = 7 + (index - 1) * 77
        theme:panel(x, 166, 72, 44, false)
        if item[3] == "hidden" then
          box("fill", x + 11, 174, 3, 13, colors.blueLight)
          box("fill", x + 6, 179, 13, 3, colors.blueLight)
          box("fill", x + 9, 177, 7, 7, colors.white)
          box("fill", x + 11, 179, 3, 3, colors.blue)
        else
          theme:battleItemIcon({ icon = item[3] }, x + 4, 174,
            item[6] and foundTint or colors.amberLight)
        end
        local cardName = item[3] == "hidden" and "HIDDEN"
          or item[1] == "SUPER POTION" and "S.POTION" or item[1]
        theme:partyType(cardName,
          x + 22, 173, colors.ink, 45)
        theme:partyType(item[2], x + 22, 191,
          item[6] and foundTint or colors.green, 42)
        theme:detailChevron(x + 64, 184, colors.ink)
      end
      return
    end

    if explorerTrainers then
      chip(12, 64, 53, "KNOWN", true)
      chip(68, 64, 48, "OPEN", false)
      chip(119, 64, 59, "BEATEN", false)
      theme:panel(181, 64, 45, 16, false)
      theme:partyType("MAP", 181, 66, colors.green, 35)
      theme:detailChevron(218, 69, colors.green)
      for index, trainer in ipairs(trainers) do
        local x = 7 + (index - 1) * 77
        theme:panel(x, 166, 72, 44, false)
        trainerIcon(x + 13, 187, trainer[6])
        local name = trainer[1] == "JR.TRAINER" and "JR.TRAINER"
          or trainer[1] == "ANN & ANNE" and "ANN&ANNE" or trainer[1]
        theme:partyType(name, x + 24, 173, colors.ink, 42)
        theme:partyType(trainer[2], x + 24, 191,
          trainer[6] == "beaten" and foundTint
            or trainer[6] == "rematch" and colors.blueLight or colors.green,
          39)
        theme:detailChevron(x + 64, 184, colors.ink)
      end
      return
    end

    if explorerLayer then
      theme:panel(7, 100, 226, 20, false)
      theme:partyInfo("WILD", 12, 105, colors.ink)
      chip(57, 102, 39, "DAY", true)
      chip(99, 102, 54, "GRASS", true)
      theme:partyType("1-6/9", 158, 104, colors.green, 55)
      color(colors.green)
      love.graphics.polygon("fill", 218, 107, 226, 107, 222, 112)
      for index, encounter in ipairs(data.encounters) do
        local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
        local x, y = 7 + column * 114, 123 + row * 29
        theme:panel(x, y, 112, 27, false)
        theme:partyInfo(theme:fitPartyInfo(encounter[1], 78),
          x + 5, y + 3, colors.ink)
        theme:typeBadges({ type = encounter[4], type2 = encounter[4],
          typeLabel = encounter[5], type2Label = encounter[5] },
          x + 1, y + 15, false)
        theme:partyType(encounter[2] .. " " .. encounter[3],
          x + 40, y + 16, colors.green, 65)
        if encounter[6] then theme:battleTeamBall(x + 94, y + 8, true) end
        theme:detailChevron(x + 105, y + 19, colors.ink)
      end
      return
    end

    local layers = {
      { "WILD", "6 NOW", "wild" }, { "ITEMS", "3 + 1", "item" },
      { "TRAINER", "VIEW", "trainer" },
    }
    for index, layer in ipairs(layers) do
      local y = 59 + (index - 1) * 35
      theme:panel(166, y, 67, 33, false)
      if layer[3] == "wild" then
        theme:battleTeamBall(178, y + 16, true)
      elseif layer[3] == "item" then
        theme:battleItemIcon({}, 170, y + 8, colors.amberLight)
      else
        trainerIcon(178, y + 16, "rematch")
      end
      theme:partyInfo(layer[1], 187, y + 6, colors.ink, 41, "center")
      theme:partyType(layer[2], 185, y + 19, colors.green, 38)
      theme:detailChevron(226, y + 14, colors.ink)
    end

    theme:panel(7, 166, 226, 44, false)
    local progress = {
      { "CAUGHT", data.caught }, { "ITEMS", data.items },
      { "HIDDEN", data.hidden },
    }
    for index, item in ipairs(progress) do
      local x = 10 + (index - 1) * 75
      if index > 1 then box("fill", x - 2, 171, 1, 34, colors.band) end
      theme:partyType(item[1], x, 174, colors.green, 71)
      theme:partyInfo(item[2], x, 190, colors.ink, 71, "center")
    end
  end
  local function battleMon()
    local mon = party[gen1 and 6 or 1]
    mon.fightLabel, mon.bagLabel = "FIGHT", "BAG"
    mon.partyLabel, mon.runLabel = "POKEMON", "RUN"
    mon.moveIndex = 1
    if gen1 then
      mon.moves = {
        { name = "BODY SLAM", type = "NORMAL", typeLabel = "NORMAL",
          ppText = "15/15", powerText = "85", accuracyText = "100",
          effectiveness = 10, descriptionLines = {
            "MAY PARALYZE THE TARGET.", "A RELIABLE PHYSICAL ATTACK." } },
        { name = "EARTHQUAKE", type = "GROUND", typeLabel = "GROUND",
          ppText = "10/10", powerText = "100", accuracyText = "100",
          effectiveness = 20 },
        { name = "BLIZZARD", type = "ICE", typeLabel = "ICE",
          ppText = "5/5", powerText = "120", accuracyText = "90",
          effectiveness = 20 },
        { name = "HYPER BEAM", type = "NORMAL", typeLabel = "NORMAL",
          ppText = "5/5", powerText = "150", accuracyText = "90",
          effectiveness = 10 },
      }
    else
      mon.moves = {
        { name = "SURF", type = "WATER", typeLabel = "WATER",
          ppText = "15/15", powerText = "95", accuracyText = "100",
          effectiveness = 20, descriptionLines = {
            "A STRONG WATER-TYPE ATTACK.", "CAN ALSO CROSS WATER." } },
        { name = "ICE PUNCH", type = "ICE", typeLabel = "ICE",
          ppText = "15/15", powerText = "75", accuracyText = "100",
          effectiveness = 10 },
        { name = "BITE", type = "DARK", typeLabel = "DARK",
          ppText = "25/25", powerText = "60", accuracyText = "100",
          effectiveness = 5 },
        { name = "SCARY FACE", type = "NORMAL", typeLabel = "NORMAL",
          ppText = "10/10", powerText = "--", accuracyText = "90",
          effectiveness = 20 },
      }
    end
    return mon
  end
  local function battleBagData()
    local wild = os.getenv("KANTO_GEAR_PREVIEW_BATTLE") == "wild"
    if gen1 then
      return {
        title = "BAG", index = 2,
        items = {
          { label = "POKE BALL", right = "x12", icon = "ball",
            catchChance = wild and 64.8 or nil },
          { label = "SUPER POTION", right = "x3", icon = "medicine" },
          { label = "ANTIDOTE", right = "x2", icon = "status" },
          { label = "ESCAPE ROPE", right = "x1" },
          { label = "CANCEL", cancel = true },
        },
      }
    end
    return {
      title = "ITEM POCKET", categorized = true, index = 2,
      items = {
        { label = "TM02", right = "DYNAMIC PUNCH", icon = "machine" },
        { label = "HM03", right = "WHIRLPOOL", icon = "machine" },
        { label = "GREAT BALL", right = "x8", icon = "ball",
          catchChance = wild and 79.7 or nil },
        { label = "PARLYZ HEAL", right = "x2", icon = "status" },
        { label = "CANCEL", cancel = true },
      },
    }
  end
  local playerTeam = { true, true, true, true, true, false }
  local enemyTeam = { true, true, true, false, false, false }
  if os.getenv("KANTO_GEAR_PREVIEW_TEAM_STATUSES") == "1" then
    playerTeam = {
      { alive = true }, { alive = true, status = "PAR" },
      { alive = true, status = "PSN" }, { alive = true, status = "SLP" },
      { alive = true, status = "BRN" }, { alive = false },
    }
    enemyTeam = {
      { alive = true, status = "FRZ" }, { alive = true },
      { alive = true, status = "TOX" }, false, false, false,
    }
  end
  if os.getenv("KANTO_GEAR_PREVIEW_BATTLE") == "wild" then
    enemyTeam.wild, enemyTeam.name, enemyTeam.level = true, "PIDGEY", 4
  end
  if explorer then
    drawExplorer()
  elseif battleMessage then
    local wild = os.getenv("KANTO_GEAR_PREVIEW_BATTLE") == "wild"
    if wild then
      enemyTeam.name, enemyTeam.level = "RATTATA", 3
    end
    theme:battleMessage(wild and { "WILD RATTATA APPEARED!" }
        or { "LEADER WHITNEY SENT OUT", "MILTANK!" },
      "TAP ANYWHERE / A", playerTeam, enemyTeam, nil,
      tonumber(os.getenv("KANTO_GEAR_PREVIEW_TIME")) or 0)
  elseif battleBagTransition then
    local mon = battleMon()
    local slot = gen1 and 6 or 1
    theme:battleBagTransition(mon, function(_, x, y, size, fainted)
      drawPortrait(slot, x, y, size, fainted)
    end, playerTeam, enemyTeam, battleBagData(), transitionProgress)
  elseif battleBag then
    theme:battleBag(battleBagData(), playerTeam, enemyTeam)
  elseif battleMoveInfoTransition then
    theme:battleMoveInfoTransition(battleMon(), playerTeam, enemyTeam,
      transitionProgress)
  elseif battleMoveInfo then
    local mon = battleMon()
    local move = mon.moves[mon.moveIndex] or {}
    theme:battleMoveInfo(move, theme:moveHasStab(mon, move),
      playerTeam, enemyTeam)
  elseif battleMovesTransition then
    local mon = battleMon()
    local slot = gen1 and 6 or 1
    theme:battleMovesTransition(mon, function(_, x, y, size, fainted)
      drawPortrait(slot, x, y, size, fainted)
    end, playerTeam, enemyTeam, transitionProgress)
  elseif battleMoves then
    theme:battleMoves(battleMon(), playerTeam, enemyTeam)
  elseif battlePartyTransition then
    local mon = battleMon()
    local slot = gen1 and 6 or 1
    theme:battlePartyTransition(mon, function(_, x, y, size, fainted)
      drawPortrait(slot, x, y, size, fainted)
    end, playerTeam, enemyTeam,
      function(slot, x, y, selected, details)
        drawMon(slot, x, y, selected, details)
      end, transitionProgress, "PARTY", "20:04", "NITE")
  elseif battlePartyMenu then
    theme:headerBar("PARTY", true, false, -1)
    local actionCount = 2
    drawMon(1, 64, theme:partyActionHeroY(actionCount), true, false, false)
    local x, y, w, h = theme:partyActionRow(1, actionCount)
    theme:actionRow(x, y, w, h, "SWITCH", "switch", 0, true)
    x, y, w, h = theme:partyActionRow(2, actionCount)
    theme:actionRow(x, y, w, h, "STATS", "stats", 0, false)
  elseif battleRoot then
    local mon = battleMon()
    local slot = gen1 and 6 or 1
    theme:battleRoot(mon, function(_, x, y, size, fainted)
      drawPortrait(slot, x, y, size, fainted)
    end, playerTeam, enemyTeam,
      tonumber(os.getenv("KANTO_GEAR_PREVIEW_INDEX")) or 1)
  elseif partySwapTransition then
    theme:partySwapTransition(function(slot, x, y, selected, details)
      drawMon(slot, x, y, selected, details)
    end, 1, 2, transitionProgress, 2, language.stats, language.swap)
  elseif partySwapCommit then
    theme:partySwapCommitTransition(function(slot, x, y, selected, details)
      drawMon(slot, x, y, selected, details)
    end, 1, 2, transitionProgress)
  elseif partySwap then
    theme:partySwap(function(slot, x, y, selected, details)
      drawMon(slot, x, y, selected, details)
    end, 1, 2)
  elseif summary or moves or memo or memoTransition
      or transition or movesTransition then
    local slot = gen1 and 6 or 1
    local mon = party[slot]
    mon.statsTitle = "BATTLE STATS"
    if gen1 then
      mon.dexText, mon.levelText = "NO.128", "L35"
      mon.gender, mon.statusId = nil, nil
      mon.hp, mon.maxHp, mon.hpText = 96, 108, "96/108"
      mon.expProgress, mon.expText = 0.46, nil
      mon.nextLabel, mon.nextValue = "NEXT", "2415"
      mon.infoLabel, mon.infoText = "OT", "RED"
      mon.info2Label, mon.info2Text = "ID", "12345"
      mon.stats = {
        { label = "ATTACK", value = 84 },
        { label = "SPEED", value = 91 },
        { label = "DEFENSE", value = 78 },
        { label = "SPECIAL", value = 58 },
      }
    else
      mon.dexText = "NO.160"
      mon.infoLabel, mon.infoText = "ITEM", "MYSTIC WATER"
      mon.nextLabel, mon.nextValue = "NEXT", "4218"
      mon.otText, mon.idText = "GOLD", "12345"
      mon.experienceText, mon.nextLevelText = "125682", "L36"
      mon.stats = {
        { label = "ATTACK", value = 92 },
        { label = "DEFENSE", value = 83 },
        { label = "SPEED", value = 66 },
        { label = "SP. ATK", value = 70 },
        { label = "SP. DEF", value = 75 },
        { label = "MAX HP", value = 117 },
      }
    end
    local function summaryPortrait(_, x, y, size, fainted)
      drawPortrait(slot, x, y, size, fainted)
    end
    if memo then
      assert(not gen1, "Gen 1 summaries only have two pages")
      theme:summaryMemo(mon, summaryPortrait)
    elseif moves or movesTransition or memoTransition then
      if gen1 then
        mon.moves = {
          { name = "BODY SLAM", type = "NORMAL", typeLabel = "NORMAL",
            ppText = "15/15", powerText = "85", accuracyText = "100" },
          { name = "EARTHQUAKE", type = "GROUND", typeLabel = "GROUND",
            ppText = "10/10", powerText = "100", accuracyText = "100" },
          { name = "BLIZZARD", type = "ICE", typeLabel = "ICE",
            ppText = "5/5", powerText = "120", accuracyText = "90" },
          { name = "HYPER BEAM", type = "NORMAL", typeLabel = "NORMAL",
            ppText = "5/5", powerText = "150", accuracyText = "90" },
        }
      else
        mon.moves = {
          { name = "SURF", type = "WATER", typeLabel = "WATER",
            ppText = "15/15", powerText = "95", accuracyText = "100" },
          { name = "ICE PUNCH", type = "ICE", typeLabel = "ICE",
            ppText = "15/15", powerText = "75", accuracyText = "100" },
          { name = "BITE", type = "DARK", typeLabel = "DARK",
            ppText = "25/25", powerText = "60", accuracyText = "100" },
          { name = "SCARY FACE", type = "NORMAL", typeLabel = "NORMAL",
            ppText = "10/10", powerText = "--", accuracyText = "90" },
        }
      end
      mon.moveIndex = 1
      mon.moveDetails = true
      for _, move in ipairs(mon.moves) do move.available = true end
      if memoTransition then
        assert(not gen1, "Gen 1 summaries only have two pages")
        theme:summaryMemoTransition(mon, summaryPortrait, transitionProgress)
      elseif movesTransition then
        theme:summaryMovesTransition(mon, summaryPortrait, transitionProgress)
      else
        theme:summaryMoves(mon, summaryPortrait)
      end
    elseif transition then
      theme:summaryTransition(mon, summaryPortrait, transitionProgress, 2,
        language.stats, language.swap)
    else
      theme:summaryPage(mon, summaryPortrait)
    end
  elseif context then
    local actionCount = tonumber(os.getenv("KANTO_GEAR_PREVIEW_ACTIONS")) or 2
    drawMon(1, 64, theme:partyActionHeroY(actionCount), true, false, false)
    local x, y, w, h = theme:partyActionRow(1, actionCount)
    theme:actionRow(x, y, w, h, language.stats, "stats", 0, true)
    if actionCount > 1 then
      x, y, w, h = theme:partyActionRow(2, actionCount)
      theme:actionRow(x, y, w, h, language.swap, "swap", 0)
    end
  else
    for slot = 1, #party do
      local x, y = theme:partyPosition(slot)
      drawMon(slot, x, y, slot == 1, true)
    end
  end
  love.graphics.setCanvas()
  local preview = love.graphics.newCanvas(960, 864, { dpiscale = 1 })
  preview:setFilter("nearest", "nearest")
  love.graphics.setCanvas(preview)
  love.graphics.origin()
  love.graphics.setScissor()
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
