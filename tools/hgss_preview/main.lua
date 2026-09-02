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
  local characters = glyphs(value)
  if #characters <= limit then return value end
  return table.concat(characters, "", 1, math.max(1, limit - 1)) .. "~"
end
local function wrap(value, limit, maximum)
  local lines, current = {}, ""
  for word in tostring(value or ""):gmatch("%S+") do
    local joined = current == "" and word or current .. " " .. word
    if #glyphs(joined) <= limit then current = joined
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
local function text(value, x, y, tint)
  color(tint)
  love.graphics.print(value, x, y)
end

local languages = {
  en = {
    title = "PARTY", hp = "HP", exp = "EXP", stats = "STATS", swap = "SWAP",
    swapWith = "SWAP WITH?", useItemOn = "USE ITEM ON",
    homeTrainer = "TRAINER", homeStore = "STORE", homeNotes = "NOTES",
    names = { "FERALIGATR", "JUMPLUFF", "PIDGEOTTO", "SANDSLASH",
      "DROWZEE", "TAUROS" },
    types = {},
  },
}
local languageCode = os.getenv("KANTO_GEAR_PREVIEW_LANGUAGE") or "en"
-- Game fixtures stay in their original language; only Kanto Gear labels vary.
local language = languages.en
local I18N = assert(loadfile(root .. "/mod/kanto_gear/i18n.lua"))()
local i18n = I18N.new(function(code)
  return assert(loadfile(root .. "/mod/kanto_gear/lang/" .. code .. ".lua"))()
end, function() return languageCode end)
local function translate(value)
  return i18n:text(value)
end
local function format(value, ...)
  return i18n:format(value, ...)
end

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
  mon.hpLabel = translate(language.hp)
  mon.expLabel = translate(language.exp)
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
  local screen = os.getenv("KANTO_GEAR_PREVIEW_SCREEN") or "party"
  local homePreview = screen:sub(1, 4) == "home"
  local storeExplorerPreview = screen == "store-detail"
    and os.getenv("KANTO_GEAR_PREVIEW_STORE_APP") == "explorer"
  local chunk = assert(loadfile(root .. "/mod/kanto_gear/hgss.lua"))
  local Home = assert(loadfile(root .. "/mod/kanto_gear/home_layout.lua"))()
  local fontPath = os.getenv("KANTO_GEAR_PREVIEW_FONT")
    or root .. "/mod/kanto_gear/rounded_mplus.ttf"
  local font = fileData(fontPath, "preview.ttf")
  local bagIcon = love.graphics.newImage(fileData(
    root .. "/mod/kanto_gear/kanto_bag.png", "kanto_bag.png"))
  bagIcon:setFilter("nearest", "nearest")
  local theme = chunk()({
    graphics = love.graphics, box = box, text = text,
    fit = fit, glyphs = glyphs, color = color, font = font,
    bagIcon = bagIcon, translate = translate, format = format,
  })
  theme:setVariant(os.getenv("KANTO_GEAR_PREVIEW_VARIANT") == "dark")
  theme:setTouch(20, 20)
  assert(theme:isPressed(29, 29, 3, 3)
      and not theme:isPressed(29, 29, 3, 3, false),
    "HGSS pressed hit testing respects touch scale and disabled controls")
  theme:setTouch(nil)
  local pressX, pressY = tostring(
    os.getenv("KANTO_GEAR_PREVIEW_PRESS") or ""):match("^(%d+),(%d+)$")
  if pressX then theme:setTouch(tonumber(pressX), tonumber(pressY)) end
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
  assert(theme:stepsHit(80, 120) == "reset"
      and theme:stepsHit(20, 80) == nil,
    "Step Counter reset hitbox matches its visible button")
  if screen:sub(1, 8) == "explorer" or homePreview or storeExplorerPreview
      or screen:sub(1, 7) == "trainer" then
    local typeLabels = {
      { "HERE NOW", 66 }, { "WHOLE ROUTE", 68 }, { "HABITAT", 50 },
      { "FOUND", 74 },
      { "BEATEN", 74 }, { "MISSED", 74 }, { "LATER", 74 },
      { "NEED FINDER", 63 },
      { "TAP TO SCAN AGAIN", 200 },
      { "WILD", 60 }, { "ITEMS", 60 }, { "TRAINER", 60 },
      { "CAUGHT", 60 }, { "FOUND", 60 }, { "BEATEN", 60 },
    }
    for _, check in ipairs(typeLabels) do
      local label = translate(check[1])
      assert(theme:fitPartyType(label, check[2]) == label,
        check[1] .. " translation fits its Explorer container")
    end
    assert(theme:fitPartyInfo(translate("NOT CAUGHT"), 100)
        == translate("NOT CAUGHT"),
      "caught state fits its Explorer detail container")
    assert(theme:fitPartyInfo(translate("UNAVAILABLE"), 100)
        == translate("UNAVAILABLE")
      and theme:fitPartyInfo(translate("STORY EVENT"), 100)
        == translate("STORY EVENT"),
      "trainer lifecycle states fit their Explorer detail container")
    for _, label in ipairs({ "COOLTRAINERF BETH", "POKEMANIAC BRENT",
        "SUPER POTION", "PARLYZ HEAL" }) do
      assert(theme:fitPartyType(label, 96) == label,
        label .. " fits an Explorer list card without truncation")
    end
    assert(theme:fitPartyInfo("COOLTRAINERF BETH", 105)
        == "COOLTRAINERF BETH",
      "long trainer names fit the Explorer detail card")
  end
  if homePreview then
    for _, label in ipairs({ "BAG", "POKEDEX", language.homeTrainer,
        translate("TOOLS"), language.homeStore, language.homeNotes }) do
      assert(theme:fitPartyType(label, 49) == label,
        label .. " fits its Home app caption")
    end
    local ex, ey, ew, eh = theme:homeRect({ column = 1, row = 1,
      columns = 7 })
    local px, py, pw, ph = theme:homeRect({ column = 8, row = 1,
      columns = 5 })
    local ax, ay, aw, ah = theme:homeRect({ column = 10, row = 2,
      columns = 3 })
    assert(ex == 7 and ey == 32 and ew == 131 and eh == 82
        and px == 140 and py == 32 and pw == 93 and ph == 82
        and ax == 178 and ay == 117 and aw == 55 and ah == 82,
      "Home widgets and apps resolve onto the shared 12-column grid")
    for _, label in ipairs({ "POKEDEX", "TRAINER", "MAP", "BAG", "STORE" }) do
      local translated = translate(label)
      assert(theme:fitPartyInfo(translated, 65) == translated,
        label .. " translation fits a five-column widget header")
    end
    assert(theme:fitPartyType(translate("NEW"), 32) == translate("NEW")
        and theme:fitPartyInfo(translate("RESEARCH"), 47)
          == translate("RESEARCH"),
      "Store promotion labels fit without automatic truncation")
  end
  if screen:sub(1, 5) == "tools" then
    local singleX, singleY = theme:toolCardRect(0, 1)
    local thirdX, thirdY = theme:toolCardRect(2, 3)
    local action, index = theme:toolsHit(80, 90, {
      page = 1, actions = { { ready = true } },
    })
    assert(singleX == 66 and singleY == 74
        and thirdX == 66 and thirdY == 115
        and action == "action" and index == 1
        and theme:toolsHit(135, 90, { page = 1,
          actions = { { ready = true }, { ready = false } } }) == nil
        and theme:rodHit(30, 100, { {}, {} }) == 2,
      "Field Kit touch targets follow visible ready cards and rod rows")
  end
  if screen:sub(1, 5) == "store" then
    local action = theme:storeHit(180, 55, "detail")
    local remove = theme:storeHit(180, 65, "detail")
    local featured = theme:storeHit(20, 60, "today")
    local featuredAction = theme:storeHit(70, 90, "today")
    local recommendation, index = theme:storeHit(150, 160, "today")
    local app, appIndex = theme:storeHit(150, 110, "apps")
    local installed, installedIndex = theme:storeHit(20, 135, "library")
    local storePagePrevious = theme:storeHit(160, 42, "apps")
    local storePageNext = theme:storeHit(220, 42, "library")
    local tab, tabIndex = theme:storeHit(170, 202, "today")
    local previous = theme:storeHit(34, 13, "today")
    local nextPage = theme:storeHit(130, 13, "today")
    assert(action == "action" and remove == "remove"
        and featured == "featured" and featuredAction == "featured_action"
        and recommendation == "recommendation" and index == 2
        and app == "app" and appIndex == 4
        and installed == "installed" and installedIndex == 3
        and storePagePrevious == "page_prev"
        and storePageNext == "page_next"
        and tab == "tab" and tabIndex == 3
        and previous == "prev" and nextPage == "next"
        and theme:storeHit(34, 13, "detail") == nil,
      "Silph Store touch targets match every visible control")
  end
  assert(theme:battleEffectLabel({ powerText = "95", effectiveness = 20 })
      == "2X" and theme:battleEffectLabel({ powerText = "--",
        effectiveness = 20 }) == "--",
    "battle effectiveness labels distinguish damage and status moves")
  assert(theme:levelUpHit(42, 170) and theme:levelUpHit(197, 203)
      and not theme:levelUpHit(41, 170)
      and not theme:levelUpHit(198, 203),
    "level-up continue hitbox follows its visible HGSS button")
  local learnAction, learnSlot = theme:moveLearnHit(20, 70, true)
  local infoAction, infoSlot = theme:moveLearnHit(220, 105, true)
  assert(learnAction == "move" and learnSlot == 1
      and infoAction == "info" and infoSlot == 2
      and theme:moveLearnHit(20, 33, true) == "new"
      and theme:moveLearnHit(20, 94, false) == "new"
      and theme:moveLearnHit(20, 68, true) == nil,
    "move-learning touch targets follow every visible card")
  assert(theme:safariHit(20, 40) == 1
      and theme:safariHit(220, 40) == 2
      and theme:safariHit(20, 200) == 3
      and theme:safariHit(220, 200) == 4
      and theme:safariHit(120, 80) == nil
      and theme:safariHit(20, 121) == nil,
    "Safari touch targets follow the visible two-by-two action grid")
  assert(theme:mimicHit(20, 61, 4) == 1
      and theme:mimicHit(220, 166, 4) == 4
      and theme:mimicHit(20, 95, 4) == nil
      and theme:mimicHit(20, 166, 3) == nil,
    "Mimic touch targets follow only populated move cards")
  assert(theme:enemyInfoHit(190, 80, true) == "dvs"
      and theme:enemyInfoHit(120, 120, true) == "profile"
      and theme:enemyInfoHit(60, 180, true) == "weak"
      and theme:enemyInfoHit(180, 180, true) == "resist"
      and theme:enemyInfoHit(190, 80, false) == nil
      and theme:enemyInfoHit(120, 146, true) == nil,
    "enemy-info touch targets follow only the visible research cards")
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
  local dexSprites = {}
  if screen:sub(1, 7) == "pokedex" then
    for _, id in ipairs({ "bulbasaur", "ivysaur", "venusaur", "charmander",
        "charmeleon", "charizard", "squirtle", "wartortle", "blastoise",
        "caterpie", "metapod", "butterfree", "gyarados" }) do
      local data = love.image.newImageData("local/dex/" .. id .. ".png")
      local image = love.graphics.newImage(data)
      image:setFilter("nearest", "nearest")
      local quad, width, height = spriteView(data)
      dexSprites[id] = { image = image, quad = quad,
        width = width, height = height }
    end
  end
  local overworld = {}
  if screen:sub(1, 8) == "explorer" or homePreview or storeExplorerPreview
      or screen:sub(1, 7) == "trainer" then
    for _, name in ipairs({ "player", "trainer1", "trainer2", "trainer3" }) do
      local image = love.graphics.newImage(
        "local/overworld/" .. name .. ".png")
      image:setFilter("nearest", "nearest")
      local width, height = image:getDimensions()
      overworld[name] = {
        image = image,
        quad = love.graphics.newQuad(0, 0, 16, 16, width, height),
      }
    end
  end
  local canvas = love.graphics.newCanvas(240, 216, { dpiscale = 1 })
  canvas:setFilter("nearest", "nearest")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(theme.colors.bg)
  local gen1 = os.getenv("KANTO_GEAR_PREVIEW_GEN") == "1"
  if gen1 and screen:sub(1, 9) == "home-team" then
    for slot, name in ipairs({ "venusaur", "charizard" }) do
      local data = love.image.newImageData("local/dex/" .. name .. ".png")
      local image = love.graphics.newImage(data)
      image:setFilter("nearest", "nearest")
      local quad, width, height = spriteView(data)
      sprites[slot] = { image = image, quad = quad, width = width, height = height }
    end
  end
  local battleRoot = screen == "battle_root"
  local battleFull = screen == "battle_full"
  local battleMessage = screen == "battle_message"
  local battlePartyTransition = screen == "battle_party_transition"
  local battlePartyMenu = screen == "battle_party_menu"
  local battleMoves = screen == "battle_moves"
  local battleMovesTransition = screen == "battle_moves_transition"
  local battleMoveInfo = screen == "battle_move_info"
  local battleMoveInfoTransition = screen == "battle_move_info_transition"
  local battleBag = screen == "battle_bag"
  local battleBagTransition = screen == "battle_bag_transition"
  local legacySafari = screen == "legacy_safari"
  local legacyMimic = screen == "legacy_mimic"
  local battleSpecial = legacySafari or legacyMimic
  local explorerOverview = screen == "explorer"
  local explorerMap = screen == "explorer_map"
  local explorerLayer = screen == "explorer_layer"
  local explorerDetail = screen == "explorer_detail"
  local explorerItems = screen == "explorer_items"
  local explorerItemDetail = screen == "explorer_item_detail"
  local explorerTrainers = screen == "explorer_trainers"
  local explorerTrainerDetail = screen == "explorer_trainer_detail"
  local explorerRadar = screen == "explorer_radar"
  local regionMapFly = screen == "region_map_fly"
  local regionMap = screen == "region_map" or regionMapFly
  local legacyChoice = screen == "legacy_choice"
  local legacyChoiceGrid = screen == "legacy_choice_grid"
  local legacyNaming = screen == "legacy_naming"
  local legacyLevelUp = screen == "legacy_level_up"
  local legacyMoveNew = screen == "legacy_move_new"
  local legacyMoveForget = screen == "legacy_move_forget"
  local legacyMoveInfo = screen == "legacy_move_info"
  local legacyEnemyInfo = screen == "legacy_enemy_info"
  local legacyEnemyProfile = screen == "legacy_enemy_profile"
  local legacyEnemyDvs = screen == "legacy_enemy_dvs"
  local legacyEnemyWeak = screen == "legacy_enemy_weak"
  local legacyEnemyResist = screen == "legacy_enemy_resist"
  local legacyEnemy = legacyEnemyInfo or legacyEnemyProfile
    or legacyEnemyDvs or legacyEnemyWeak or legacyEnemyResist
  local legacyPcRoot = screen == "legacy_pc_root"
  local legacyPcBox = screen == "legacy_pc_box"
  local legacyPcChange = screen == "legacy_pc_change"
  local legacyPcItems = screen == "legacy_pc_items"
  local legacyPcDeposit = screen == "legacy_pc_deposit"
  local legacyPcQuantity = screen == "legacy_pc_quantity"
  local legacyPcSubmenu = screen == "legacy_pc_submenu"
  local legacyPcNotice = screen == "legacy_pc_notice"
  local legacyPcTop = screen == "legacy_pc_top"
  local legacyPc = legacyPcRoot or legacyPcBox or legacyPcChange
    or legacyPcItems or legacyPcDeposit or legacyPcQuantity or legacyPcSubmenu
    or legacyPcNotice or legacyPcTop
  local legacyTitle = screen == "legacy_title"
  local legacyLoading = screen == "legacy_loading"
  local legacyOverlay = screen == "legacy_overlay"
  local legacyPpMoves = screen == "legacy_pp_moves"
  local legacy = legacyChoice or legacyChoiceGrid or legacyNaming
    or legacyLevelUp or legacyMoveNew or legacyMoveForget or legacyMoveInfo
    or legacyEnemy or legacyPc or legacyPpMoves
  local legacyBack = legacyMoveForget or legacyMoveInfo
    or legacyEnemy and not legacyEnemyInfo or legacyPc and not legacyPcRoot
    or legacyPpMoves
  local pokedexIndex = screen == "pokedex"
  local pokedexProfile = screen == "pokedex_profile"
  local pokedexHabitat = screen == "pokedex_habitat"
  local pokedexStats = screen == "pokedex_stats"
  local pokedexMoves = screen == "pokedex_moves"
  local pokedex = pokedexIndex or pokedexProfile or pokedexHabitat
    or pokedexStats or pokedexMoves
  local bagOverview, bagDetail = screen == "bag", screen == "bag_detail"
  local bag = bagOverview or bagDetail
  local home = homePreview
  local homeEdit, homeAdd = screen == "home-edit", screen == "home-add"
  local storeToday, storeApps = screen == "store", screen == "store-apps"
  local storeLibrary, storeDetail = screen == "store-library",
    screen == "store-detail"
  local trainerScreen, trainerSteps = screen == "trainer",
    screen == "trainer_steps"
  local toolsScreen = screen == "tools"
  local toolsPrompt = screen == "tools_prompt"
  local toolsRods = screen == "tools_rods"
  local tools = toolsScreen or toolsPrompt or toolsRods
  local settingsRoot, settingsDisplay = screen == "settings",
    screen == "settings_display"
  local settingsAppearance, settingsSystem = screen == "settings_appearance",
    screen == "settings_system"
  local settings = settingsRoot or settingsDisplay
    or settingsAppearance or settingsSystem
  local store = storeToday or storeApps or storeLibrary or storeDetail
  local explorer = explorerOverview or explorerMap or explorerLayer
    or explorerDetail
    or explorerItems or explorerItemDetail
    or explorerTrainers or explorerTrainerDetail or explorerRadar
  local partySwap = screen == "party_swap"
  local partySwapTransition = screen == "party_swap_transition"
  local partySwapCommit = screen == "party_swap_commit"
  local swapMode = partySwap or partySwapTransition or partySwapCommit
  local context, summary = screen == "context", screen == "summary"
  local moves = screen == "summary_moves"
  local summaryMoveInfo = screen == "summary_move_info"
  local memo = screen == "summary_memo"
  local memoTransition = screen == "summary_memo_transition"
  local transition = screen == "summary_transition"
  local movesTransition = screen == "summary_moves_transition"
  local transitionProgress = math.max(0, math.min(1,
    tonumber(os.getenv("KANTO_GEAR_PREVIEW_PROGRESS")) or 0))
  local statsTitle = format("STATS %d/%d", 1, gen1 and 2 or 3)
  local movesTitle = format("MOVES %d/%d", 2, gen1 and 2 or 3)
  local title = storeDetail and
      (os.getenv("KANTO_GEAR_PREVIEW_STORE_APP") or "NOTES"):upper()
    or store and "SILPH STORE"
    or homeAdd and "ADD TO HOME"
    or homeEdit and "EDIT HOME"
    or home and "SILPH LINK"
    or explorerRadar and "ITEM RADAR"
    or explorer and "EXPLORER"
    or regionMap and (gen1 and "KANTO MAP" or "JOHTO MAP")
    or legacyNaming and "NAME INPUT"
    or legacyLevelUp and "LEVEL UP"
    or legacyMoveNew and "NEW MOVE"
    or legacyMoveForget and "FORGET MOVE"
    or legacyMoveInfo and (gen1 and "THUNDERBOLT" or "ICE PUNCH")
    or legacyEnemyProfile and "POKEDEX"
    or legacyEnemyDvs and "ENEMY DVS"
    or legacyEnemyWeak and "WEAK"
    or legacyEnemyResist and "RESIST"
    or legacyEnemyInfo and "ENEMY INFO"
    or legacyPcRoot and format("PC BOX %d %d/20", 3, 12)
    or legacyPcBox and "WITHDRAW"
    or legacyPcChange and "BOX CHANGE"
    or legacyPcItems and "WITHDRAW"
    or legacyPcDeposit and "DEPOSIT ITEM"
    or legacyPcQuantity and "QUANTITY"
    or legacyPcSubmenu and "POKEMON"
    or legacyPcNotice and "ITEM PC"
    or legacyPcTop and "MENU ON TOP"
    or legacyPpMoves and "RESTORE PP"
    or legacy and "CHOOSE"
    or pokedexHabitat and format("HABITAT %d/%d", 1, 4)
    or pokedexStats and "STATS"
    or pokedexMoves and format("MOVES %d/%d", 1, 7)
    or pokedexProfile and format("NO.%03d", 130)
    or pokedex and "POKEDEX"
    or bag and "BAG"
    or trainerSteps and "STEPS"
    or trainerScreen and "TRAINER"
    or toolsRods and "CHOOSE ROD"
    or tools and "FIELD KIT"
    or settingsDisplay and "DISPLAY"
    or settingsAppearance and "APPEARANCE"
    or settingsSystem and "SYSTEM"
    or settings and "SETTINGS"
    or os.getenv("KANTO_GEAR_PREVIEW_CONTEXT") == "item"
      and language.useItemOn
    or partySwap and language.swapWith
    or partySwapTransition
      and (transitionProgress >= 0.45 and language.swapWith or language.title)
    or partySwapCommit
      and (transitionProgress >= 0.72 and language.title or language.swapWith)
    or memo and format("%s %d/%d", translate("TRAINER"), 3, 3)
    or memoTransition
      and (transitionProgress >= 0.5 and format("%s %d/%d", translate("TRAINER"), 3, 3) or movesTitle)
    or moves and movesTitle
    or summaryMoveInfo and "MOVES"
    or movesTransition
      and (transitionProgress >= 0.5 and movesTitle or statsTitle)
    or (summary or transition and transitionProgress >= 0.42) and statsTitle
    or language.title
  if not legacyTitle
      and not battleRoot and not battleFull and not battleMessage and not battlePartyTransition
      and not battlePartyMenu
      and not battleMoves and not battleMovesTransition
      and not battleMoveInfo and not battleMoveInfoTransition
      and not battleBag and not battleBagTransition
      and not battleSpecial then
    local headerOffset = summary and -1 or 0
    if not (legacyMoveInfo or legacyPcRoot or pokedexHabitat
        or pokedexMoves or pokedexProfile or memo or memoTransition
        or moves or movesTransition or summary
        or transition and transitionProgress >= 0.42) then
      title = translate(title)
    end
    local titleX, titleWidth = theme:headerBar(title,
      homeAdd or store or explorer and not explorerOverview
        or pokedex or bag or regionMap or legacyBack
        or trainerScreen or trainerSteps
        or tools or settings or swapMode
        or context or summary
        or moves or memo or memoTransition or summaryMoveInfo
        or transition or movesTransition,
      store and not storeDetail
        or pokedexProfile or pokedexHabitat or pokedexStats or pokedexMoves
        or not home and not store and not explorer and not regionMap
        and not legacy and not summaryMoveInfo
        and not pokedex and not bag
        and not trainerScreen
        and not trainerSteps and not tools and not settings and not swapMode and (summary or moves or memo or memoTransition
        or movesTransition or transition and transitionProgress >= 0.42
        or not context) or toolsScreen or settingsDisplay, headerOffset)
    if context then
      local left, width = 26, 112
      assert(math.abs(titleX - left - (width - titleWidth - (titleX - left)))
        <= 1, "context title stays centered between dividers")
    end
    if toolsScreen then
      assert(titleX >= 42 and titleX + titleWidth <= 122,
        "paged Field Kit titles preserve space beside both arrows")
    end
    if homeAdd then
      theme:homeAddHeader("ADD TO HOME")
    elseif homeEdit then
      theme:homeEditDone()
    else
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
  end
  if battleRoot or battleFull or battleMessage or battlePartyTransition or battlePartyMenu
      or battleMoves or battleMovesTransition or battleMoveInfo
      or battleMoveInfoTransition or battleBag or battleBagTransition
      or battleSpecial then
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
  local galleryGray = love.graphics.newShader([[
    vec4 effect(vec4 color, Image texture, vec2 uv, vec2 px) {
      vec4 source = Texel(texture, uv) * color;
      float gray = dot(source.rgb, vec3(0.299, 0.587, 0.114));
      return vec4(vec3(gray * 0.72), source.a);
    }
  ]])
  local function drawMon(slot, x, y, selected, details, focused)
    theme:partyCard(party[slot], x, y, selected, details,
      function(_, portraitX, portraitY, size, fainted)
        drawPortrait(slot, portraitX, portraitY, size, fainted)
      end, focused)
  end
  local function drawOverworld(name, x, y, scale, tint, centered)
    local sprite = assert(overworld[name], "missing overworld sprite " .. name)
    scale = scale or 1
    color(tint or { 1, 1, 1, 1 })
    love.graphics.draw(sprite.image, sprite.quad, x - 8 * scale,
      y - (centered and 8 or 16) * scale, 0, scale, scale)
  end
  local function drawExplorer()
    local colors = theme.colors
    if explorerRadar then
      theme:explorerRadar({ route = gen1 and "ROUTE 15" or "ROUTE 37",
        progress = 1, ready = true,
        signals = { { dx = -3, dy = 2 }, { dx = 5, dy = -2 } } })
      return
    end
    local data = gen1 and {
      route = "ROUTE 15", subarea = "OUTDOORS", region = "KANTO",
      caught = "4/9",
      items = "2/3", beaten = "1/3",
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
      route = "ROUTE 37", subarea = "FARMHOUSE", region = "JOHTO",
      caught = "3/9",
      items = "1/2", beaten = "1/3",
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
    data.subarea = os.getenv("KANTO_GEAR_PREVIEW_SUBAREA") or data.subarea
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
      { "BIKER", "OPEN", "BIKER", 10, 8, "open", "trainer1" },
      { "BEAUTY", "BEATEN", "BEAUTY", 27, 11, "beaten", "trainer2" },
      { "JR.TRAINER", "OPEN", "JR.TRAINER", 36, 7, "open",
        "trainer3" },
    } or {
      { "DANA", "REMATCH", "LASS", 10, 8, "rematch", "trainer1" },
      { "GREG", "BEATEN", "PSYCHIC", 27, 11, "beaten", "trainer2" },
      { "ANN & ANNE", "OPEN", "TWINS", 36, 7, "open",
        "trainer3" },
    }
    if explorerTrainerDetail then
      trainers[1][1] = "COOLTRAINERF BETH"
    end
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
        local function walkable(x, y)
          if x < 1 or x > width or y < 1 or y > height then return false end
          local kind = rows[y]:sub(x, x)
          return kind == "." or kind == "+"
        end
        for py = 1, height * density do
          local values, cellY = {}, math.floor((py - 1) / density) + 1
          for px = 1, width * density do
            local cellX = math.floor((px - 1) / density) + 1
            local kind = rows[cellY]:sub(cellX, cellX)
            local subX, subY = (px - 1) % density, (py - 1) % density
            local shade
            if kind == "~" then
              shade = subY == 0 and 0
                or subY == density - 1 and 2 or 1
            elseif kind == "." or kind == "+" then
              local edge = subX == 0 and not walkable(cellX - 1, cellY)
                or subX == density - 1 and not walkable(cellX + 1, cellY)
                or subY == 0 and not walkable(cellX, cellY - 1)
                or subY == density - 1 and not walkable(cellX, cellY + 1)
              shade = edge and 2
                or (cellX * 7 + cellY * 11 + subX * 3 + subY) % 29 == 0
                  and 1 or 0
            else
              local seed = (cellX * 5 + cellY * 3) % 7
              shade = seed < 2 and subX == 1 and subY == 1 and 0
                or seed < 2 and subX == density - 1
                  and subY == density - 1 and 2 or 1
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
    local function trainerIcon(x, y, state, spriteName)
      local tint = state == "beaten" and (theme.dark
          and colors.silver or colors.silverDark)
        or state == "rematch" and colors.blueLight or colors.redLight
      drawOverworld(spriteName or "trainer3", x, y, 1, tint, true)
    end
    local mapX, mapY = 7, 59
    local compactMap = explorerLayer or explorerDetail
    local itemMap = explorerItems or explorerItemDetail
    local trainerMap = explorerTrainers or explorerTrainerDetail
    local fullMap = itemMap or trainerMap
    local mapW = 226
    local mapH = explorerDetail and 44 or explorerLayer and 38
      or (explorerItemDetail or explorerTrainerDetail) and 103
      or fullMap and 84 or 91
    local foundTint = theme.dark and colors.silver or colors.silverDark
    assert(mapX + 226 == 233 and mapX + 72 * 3 + 5 * 2 == 233,
      "Explorer map and three app cards share one content grid")

    theme:panel(7, 32, 226, 23, false)
    theme:partyInfo(theme:fitPartyInfo(data.route, 64),
      13, 38, colors.ink, 64, "center")
    theme:partyType(theme:fitPartyType(data.subarea, 92),
      81, 39, colors.green, 92)
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
          sprite = trainer[7],
        }
      end
    end
    if os.getenv("KANTO_GEAR_PREVIEW_CONNECTED") == "1" then
      local view = (explorerLayer or explorerDetail) and "wild"
        or itemMap and "items" or trainerMap and "trainers" or "wild"
      local enhanced = os.getenv("KANTO_GEAR_PREVIEW_ENHANCED") == "1"
      local wildScope = os.getenv("KANTO_GEAR_PREVIEW_WILD_SCOPE") == "ROUTE"
        and "ROUTE" or "HERE"
      local wildRows, itemRows, trainerRows = {}, {}, {}
      for index, encounter in ipairs(data.encounters) do
        local appearance = { section = data.subarea,
          time = not gen1 and data.period or nil,
          method = "WALK", chance = tonumber(encounter[2]:match("%d+")),
          minLevel = tonumber(encounter[3]:match("%d+")),
          maxLevel = tonumber(encounter[3]:match("%d+%-(%d+)"))
            or tonumber(encounter[3]:match("%d+")), current = index <= 4 }
        local alternate = { section = index % 2 == 0 and "POND"
            or "NORTH FIELD", time = not gen1 and "NITE" or nil,
          method = index % 2 == 0 and "GOOD" or "WALK",
          chance = math.max(5, appearance.chance - 5),
          minLevel = appearance.minLevel + 2,
          maxLevel = appearance.maxLevel + 2, current = false }
        local matches = { appearance, alternate }
        if index == 1 then
          matches[3] = { section = "SOUTH FIELD", time = not gen1 and "MORN"
              or nil, method = "SURF", chance = 10,
            minLevel = 15, maxLevel = 17, current = false }
        end
        wildRows[index] = {
          name = encounter[1], species = species[math.min(index + 2, #species)],
          chance = encounter[2], levels = encounter[3],
          type = encounter[4], type2 = encounter[4],
          typeLabel = encounter[5], type2Label = encounter[5],
          caught = encounter[6], method = "WALK", period = data.period,
          matches = matches, detailPages = math.ceil(#matches / 2),
          previewSlot = math.min(index, #sprites),
        }
      end
      for index, item in ipairs(items) do
        itemRows[index] = { label = item[1], kind = item[3],
          displayLabel = item[3] == "hidden" and "HIDDEN SIGNAL" or item[1],
          location = item[3] == "hidden" and "USE ITEMFINDER"
            or "MARKED ON MAP",
          x = item[4], y = item[5], done = item[6], icon = item[3],
          key = "item:" .. index }
      end
      for index, trainer in ipairs(trainers) do
        trainerRows[index] = { label = trainer[1], x = trainer[4],
          y = trainer[5], done = trainer[6] == "beaten",
          state = trainer[6], sprite = trainer[7],
          spriteId = trainer[7], status = trainer[2],
          key = "trainer:" .. index }
      end
      markers = {}
      for _, marker in ipairs(overview.markers or {}) do
        if marker.kind == "warp" then markers[#markers + 1] = marker end
      end
      for _, row in ipairs(itemRows) do
        if enhanced or row.kind ~= "hidden" or row.done then
          markers[#markers + 1] = { kind = row.kind == "hidden"
              and "hidden" or "item", x = row.x, y = row.y,
            found = row.done, source = row }
        end
      end
      for _, row in ipairs(trainerRows) do
        markers[#markers + 1] = { kind = "trainer", x = row.x, y = row.y,
          actor = row, state = row.state, source = row }
      end
      local sourceRows = view == "wild" and wildRows
        or view == "items" and itemRows
        or view == "trainers" and trainerRows or {}
      if view == "wild" and wildScope == "HERE" then
        sourceRows = { wildRows[1], wildRows[2], wildRows[3], wildRows[4] }
      end
      local rows, perPage = {}, view == "wild" and 4
        or math.max(1, #sourceRows)
      for index = 1, math.min(#sourceRows, perPage) do
        rows[#rows + 1] = sourceRows[index]
      end
      local selected = (explorerDetail or explorerItems or explorerItemDetail
        or explorerTrainers or explorerTrainerDetail) and sourceRows[1] or nil
      if selected and view == "wild"
          and os.getenv("KANTO_GEAR_PREVIEW_SINGLE_HABITAT") == "1" then
        selected.matches = { selected.matches[1] }
        selected.detailPages = 1
      end
      local selectedMarker
      for _, marker in ipairs(markers) do
        if marker.source == selected then selectedMarker = marker break end
      end
      local canScan = not enhanced
        and os.getenv("KANTO_GEAR_PREVIEW_NO_FINDER") ~= "1"
      local scanActive = os.getenv("KANTO_GEAR_PREVIEW_SCAN") == "1"
      local explorerModel = {
        view = view, selected = selected, rows = rows, total = #sourceRows,
        page = 1, pages = math.max(1, math.ceil(#sourceRows / perPage)),
        perPage = perPage,
        route = data.route,
        subarea = data.subarea,
        region = data.region, overview = overview,
        player = { x = 20, y = 8, facing = "down" }, markers = markers,
        selectedMarker = selectedMarker,
        filters = { wildScope = wildScope },
        detailPage = 1,
        detailRows = view == "wild" and selected
          and { selected.matches[1], selected.matches[2] } or {},
        detailPages = view == "wild" and selected
          and selected.detailPages or 1,
        enhanced = enhanced,
        canScan = canScan,
        scanHint = canScan and not scanActive,
        scanProgress = scanActive and 0.55 or nil,
        showMapStats = true,
        guideEnabled = true, areaEnabled = true,
        itemsText = data.items, trainersText = data.beaten,
        mapFull = explorerMap,
        mapZoom = tonumber(os.getenv("KANTO_GEAR_PREVIEW_MAP_ZOOM")) or 1,
        wildScope = wildScope, trainerIcon = trainerRows[1],
        drawPlayer = function(_, x, y, tileSize)
          drawOverworld("player", x, y, tileSize / 16, colors.redLight)
        end,
        drawTrainer = function(marker, x, y, tileSize)
          local tint = marker.state == "beaten" and (theme.dark
              and colors.silver or colors.silverDark) or colors.redLight
          drawOverworld(marker.actor.sprite, x, y, tileSize / 16, tint)
        end,
        drawActor = function(row, x, y, scale, feet)
          drawOverworld(row.sprite, x, y, scale, colors.redLight, not feet)
        end,
        drawPokemon = function(row, x, y, size, uncaught)
          if uncaught then love.graphics.setShader(galleryGray) end
          drawPortrait(row.previewSlot, x, y, size, false)
          if uncaught then love.graphics.setShader() end
        end,
      }
      theme:explorer(explorerModel)
      if explorerTrainerDetail then
        local first, second = theme:splitPartyInfo(selected.label, 75)
        assert(first == "COOLTRAINERF" and second == "BETH"
            and not first:find("…", 1, true) and not second:find("…", 1, true),
          "Explorer trainer detail uses its two-line name region")
      end
      local sx = 1 / 1.5
      local function mapMarkerIsReachable(kind)
        for y = 60, 142, 4 do
          for x = 8, 232, 4 do
            local action, slot = theme:explorerHit(
              x * sx, y * sx, explorerModel)
            local marker = slot and explorerModel.markers[slot]
            if action == "marker" and marker and marker.source
                and (not kind or marker.kind == kind) then
              return true
            end
          end
        end
        return false
      end
      local function actionIsReachable(expected)
        for y = 53, 210, 3 do
          for x = 7, 233, 3 do
            if theme:explorerHit(x * sx, y * sx, explorerModel) == expected then
              return true
            end
          end
        end
        return false
      end
      assert(theme:explorerHit(211 * sx, 40 * sx,
        explorerModel) == "map_toggle",
        "Explorer map expand control is always interactive")
      local visibleItems = 0
      for _, row in ipairs(itemRows) do
        if enhanced or row.kind ~= "hidden" or row.done then
          visibleItems = visibleItems + 1
        end
      end
      assert(#explorerModel.markers
          == #(overview.markers or {}) + visibleItems + #trainerRows,
        "Explorer only reveals hidden-item markers in spoiler mode")
      if explorerMap then
        assert(theme:explorerHit(20 * sx, 61 * sx,
            explorerModel) == "zoom_out"
          and theme:explorerHit(73 * sx, 61 * sx,
            explorerModel) == "zoom_in"
          and theme:explorerHit(120 * sx, 61 * sx,
            explorerModel) == nil
          and theme:explorerHit(210 * sx, 61 * sx,
            explorerModel) == nil
          and (not explorerModel.canScan
            or actionIsReachable("player_scan")),
          "Explorer fullscreen tools are interactive without map click-through")
        return
      end
      if view == "wild" and not selected then
        assert(theme:explorerHit(50 * sx, 150 * sx, explorerModel)
            == "wild_here"
          and theme:explorerHit(125 * sx, 150 * sx, explorerModel)
            == "wild_route"
          and theme:explorerHit(50 * sx, 185 * sx, explorerModel) == "row"
          and theme:explorerHit(210 * sx, 150 * sx, explorerModel)
            == (explorerModel.pages > 1 and "next" or nil)
          and mapMarkerIsReachable("item")
          and mapMarkerIsReachable("trainer")
          and (not explorerModel.canScan
            or actionIsReachable("player_scan")),
          "Explorer gallery and map markers are interactive")
      elseif view == "wild" then
        assert(theme:explorerHit(210 * sx, 114 * sx, explorerModel)
            == (explorerModel.detailPages > 1 and "detail_next" or nil),
          "habitat details expose every exact encounter condition")
      elseif selected then
        assert(mapMarkerIsReachable(),
          "Explorer item and trainer details remain connected to map markers")
      end
      return
    end
    theme:mapOverview(overview, mapX, mapY, mapW, mapH, {
      player = { x = 20, y = 8, facing = "down" },
      markers = markers,
      selected = (explorerItemDetail or explorerTrainerDetail) and 1 or nil,
      drawPlayer = function(_, x, y)
        drawOverworld("player", x, y, 0.75, colors.redLight)
      end,
      drawTrainer = function(marker, x, y)
        local tint = marker.state == "beaten" and foundTint
          or marker.state == "rematch" and colors.blueLight or colors.redLight
        drawOverworld(marker.sprite, x, y, 0.75, tint)
      end,
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
      trainerIcon(23, 186, trainer[6], trainer[7])
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
        trainerIcon(x + 13, 187, trainer[6], trainer[7])
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
      { "WILD", "wild", data.caught, "CAUGHT" },
      { "ITEMS", "item", data.items, "FOUND" },
      { "TRAINER", "trainer", data.beaten, "BEATEN" },
    }
    for index, layer in ipairs(layers) do
      local x, value = 7 + (index - 1) * 77, layer[3]
      theme:panel(x, 154, 72, 56, false)
      theme:partyType(theme:fitPartyType(translate(layer[1]), 60),
        x + 6, 159, colors.ink, 60)
      local valueWidth = theme:partyInfoWidth(value)
      if layer[2] == "wild" then
        local left = x + math.floor((72 - 9 - 4 - valueWidth) / 2)
        theme:battleTeamBall(left + 4, 181, true)
        theme:partyInfo(value, left + 13, 176, colors.ink)
      elseif layer[2] == "item" then
        local left = x + math.floor((72 - 16 - 4 - valueWidth) / 2)
        theme:battleItemIcon({}, left, 173, colors.amberLight)
        theme:partyInfo(value, left + 20, 176, colors.ink)
      else
        local left = x + math.floor((72 - 12 - 4 - valueWidth) / 2)
        trainerIcon(left + 6, 181, "rematch", "trainer3")
        theme:partyInfo(value, left + 16, 176, colors.ink)
      end
      theme:partyType(theme:fitPartyType(translate(layer[4]), 60),
        x + 6, 195, colors.green, 60)
      theme:detailChevron(x + 65, 179, colors.ink)
    end
  end
  local function battleMon()
    local mon = party[gen1 and 6 or 1]
    mon.fightLabel, mon.bagLabel = translate("FIGHT"), translate("BAG")
    mon.partyLabel, mon.runLabel = translate("POKEMON"), translate("RUN")
    mon.moveIndex = 1
    if gen1 then
      mon.moves = {
        { name = "BODY SLAM", type = "NORMAL", typeLabel = "NORMAL",
          ppText = "15/15", powerText = "85", accuracyText = "100",
          effectiveness = 10, descriptionLines = {
            translate("30.1% CHANCE"), translate("TO PARALYZE TARGET") } },
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
        title = translate("BAG"), index = 2,
        items = {
          { label = "POKE BALL", right = "x12", icon = "ball",
            catchChance = wild and 64.8 or nil },
          { label = "SUPER POTION", right = "x3", icon = "medicine" },
          { label = "ANTIDOTE", right = "x2", icon = "status" },
          { label = "ESCAPE ROPE", right = "x1" },
          { label = translate("CANCEL"), cancel = true },
        },
      }
    end
    return {
      title = translate("ITEM POCKET"), categorized = true, index = 2,
      items = {
        { label = "TM02", right = "DYNAMIC PUNCH", icon = "machine" },
        { label = "HM03", right = "WHIRLPOOL", icon = "machine" },
        { label = "GREAT BALL", right = "x8", icon = "ball",
          catchChance = wild and 79.7 or nil },
        { label = "PARLYZ HEAL", right = "x2", icon = "status" },
        { label = translate("CANCEL"), cancel = true },
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
  local storeCatalog = {
    { id = "explorer", icon = "explorer", label = "EXPLORER",
      category = "ADVENTURE", action = "OPEN", state = "open",
      description = { "EXPLORE THE AREA AROUND YOU.",
        "FIND POKEMON, ITEMS AND TRAINERS.", "YOUR ROUTE, IN ONE PLACE." } },
    { id = "map", icon = "map", label = "MAP",
      category = "NAVIGATION", action = "OPEN", state = "open",
      description = { "VIEW THE REGION MAP.",
        "SEE WHERE YOUR JOURNEY HAS LED.", "YOUR POSITION, AT A GLANCE." } },
    { id = "party", icon = "party", label = "PARTY",
      category = "TEAM", action = "OPEN", state = "open",
      description = { "CHECK YOUR TEAM AT A GLANCE.",
        "VIEW STATS, MOVES AND STATUS.", "KEEP EVERY PARTNER READY." } },
    { id = "pokedex", icon = "pokedex", label = "POKEDEX",
      category = "RESEARCH", action = "GET", state = "get", new = true,
      description = { "RESEARCH EVERY SPECIES.",
        "CHECK STATS, MOVES AND HABITATS.", "YOUR FIELD ENCYCLOPEDIA." } },
    { id = "bag", icon = "bag", label = "BAG",
      category = "ITEMS", action = "OPEN", state = "open",
      description = { "BROWSE EVERY ITEM BELOW.",
        "USE THE ORIGINAL GAME EFFECTS.", "NO MIRRORED BAG REQUIRED." } },
    { id = "trainer", icon = "trainer", label = "TRAINER CARD",
      category = "PROFILE", action = "OPEN", state = "open",
      description = { "REVIEW YOUR TRAINER JOURNEY.",
        "BADGES, PLAY TIME AND PROGRESS.", "YOUR ADVENTURE, AT A GLANCE." } },
    { id = "steps", icon = "steps", label = "STEP COUNTER",
      category = "TRAINER TOOL", action = "OPEN", state = "open",
      description = { "COUNT EVERY STEP OF YOUR JOURNEY.",
        "KEEP THE TOTAL ON YOUR HOME SCREEN.", "ONE SMALL STEP AT A TIME." } },
    { id = "tools", icon = "tools", label = "TOOLS",
      category = "FIELD KIT", action = "OPEN", state = "open",
      description = { "USE FIELD MOVES AND GEAR.",
        "KEEP UNLOCKED TOOLS CLOSE.", "READY WHEN THE ROUTE NEEDS IT." } },
    { id = "notes", icon = "notes", label = "NOTES",
      category = "TRAINER TOOL", action = "GET", state = "get",
      description = { "PLAN ROUTES AND REMINDERS.",
        "KEEP CLUES CLOSE AT HAND.", "COMING SOON FROM SILPH LABS." } },
  }
  for _, app in ipairs(storeCatalog) do
    if app.id == "party" then
      app.preview = { party = {}, drawPokemon = function(row, x, y, size)
        drawPortrait(row.previewSlot, x, y, size, false)
      end }
      for index = 1, 6 do
        app.preview.party[index] = {
          previewSlot = index,
          name = ({ "FERALIGATR", "JUMPLUFF", "PIDGEOTTO", "SANDSLASH",
            "DROWZEE", "TAUROS" })[index],
          hpRatio = ({ 0.79, 1, 1, 1, 0, 0.33 })[index],
        }
      end
    elseif app.id == "pokedex" then
      app.preview = { entries = {}, page = 1, pages = 28, progress = 0.47,
        drawPokemon = function(row, x, y, size)
        drawPortrait(row.previewSlot, x, y, size, false)
      end }
      for index = 1, 6 do
        app.preview.entries[index] = {
          previewSlot = index, caught = index == 1 or index >= 5,
          name = ({ "BULBASAUR", "IVYSAUR", "VENUSAUR", "CHARMANDER",
            "CHARMELEON", "CHARIZARD" })[index],
        }
      end
    elseif app.id == "explorer" then
      local mapRows = {}
      for y = 1, 18 do
        local row = {}
        for x = 1, 42 do
          row[x] = x >= 30 and y <= 7 and "~"
            or x >= 18 and x <= 23 and "." or " "
        end
        mapRows[y] = table.concat(row)
      end
      local detailRows = {}
      for y = 1, 72 do
        local row = {}
        for x = 1, 168 do
          local value = (x * 17 + y * 31 + x * y * 7) % 29
          row[x] = value < 3 and "1" or value == 3 and "2" or "0"
        end
        detailRows[y] = table.concat(row)
      end
      app.preview = { rows = {},
        overview = { width = 42, height = 18, rows = mapRows,
          tileDetailRows = detailRows, tileDetailWidth = 168,
          tileDetailHeight = 72 },
        player = { x = 20, y = 9, facing = "down" },
        markers = {
          { kind = "item", x = 22, y = 8 },
          { kind = "trainer", x = 18, y = 10,
            actor = { sprite = "trainer1" } },
        },
        drawPlayer = function(_, x, y, tileSize)
          drawOverworld("player", x, y, tileSize / 16,
            theme.colors.redLight)
        end,
        drawTrainer = function(marker, x, y, tileSize)
          drawOverworld(marker.actor.sprite, x, y,
            tileSize / 16, theme.colors.redLight)
        end,
        drawPokemon = function(row, x, y, size)
        drawPortrait(row.previewSlot, x, y, size, false)
      end }
      for index = 1, 3 do
        app.preview.rows[index] = { previewSlot = index, caught = index < 3 }
      end
    elseif app.id == "bag" then
      app.preview = { entries = {
        { icon = "medicine", label = "POTION", count = 12 },
        { icon = "ball", label = "GREAT BALL", count = 8 },
        { icon = "status", label = "ANTIDOTE", count = 3 },
        { icon = "machine", label = "TM24", count = 1 },
        { icon = "key", label = "ESCAPE ROPE", count = 2 },
        { icon = "medicine", label = "SUPER POTION", count = 4 },
      } }
    end
  end
  local toolActions = gen1 and {
    { id = "bicycle", icon = "bicycle", label = "BICYCLE", ready = true },
    { id = "fish", icon = "fish", label = "FISH", ready = true },
    { id = "cut", icon = "cut", label = "CUT", ready = false },
    { id = "surf", icon = "surf", label = "SURF", ready = true },
    { id = "dig", icon = "dig", label = "DIG", ready = false },
    { id = "teleport", icon = "teleport", label = "TELEPORT", ready = true },
    { id = "softboiled", icon = "softboiled", label = "SOFT BOILED",
      ready = true },
  } or {
    { id = "bicycle", icon = "bicycle", label = "BICYCLE", ready = true },
    { id = "fish", icon = "fish", label = "FISH", ready = true },
    { id = "cut", icon = "cut", label = "CUT", ready = false },
    { id = "surf", icon = "surf", label = "SURF", ready = true },
    { id = "headbutt", icon = "headbutt", label = "HEADBUTT", ready = false },
    { id = "whirlpool", icon = "whirlpool", label = "WHIRLPOOL", ready = true },
    { id = "strength", icon = "strength", label = "STRENGTH", ready = true },
    { id = "flash", icon = "flash", label = "FLASH", ready = false },
    { id = "waterfall", icon = "waterfall", label = "WATERFALL", ready = true },
    { id = "sweet_scent", icon = "sweet_scent", label = "SWEET SCENT",
      ready = true },
    { id = "dig", icon = "dig", label = "DIG", ready = false },
    { id = "teleport", icon = "teleport", label = "TELEPORT", ready = true },
    { id = "squirtbottle", icon = "squirtbottle", label = "SQUIRT BOTTLE",
      ready = false },
  }
  local toolPage = math.max(1, math.floor(
    tonumber(os.getenv("KANTO_GEAR_PREVIEW_PAGE")) or 1))
  local toolPages = math.max(1, math.ceil(#toolActions / 4))
  if legacyPpMoves then
    theme:pcList({ summary = translate("CHOOSE MOVE"), entries = {
      { kind = "move", label = "SURF", right = "PP 12/15", selected = true },
      { kind = "move", label = "ICE PUNCH", right = "PP 8/15" },
      { kind = "move", label = "BITE", right = "PP 20/25" },
      { kind = "move", label = "SCARY FACE", right = "PP 10/10" },
    } })
  elseif legacyTitle then
    theme:titleBoot({ systemId = gen1 and "SLS-RBY-3.0" or "SLS-GSC-3.0" }, 1)
  elseif legacyLoading then
    theme:loadingOverlay("LOADING AREA", 1)
  elseif legacyOverlay then
    theme:systemOverlay(0.48, true, 1)
  elseif legacyPc then
    if legacyPcRoot then
      local entries = gen1 and {
        { label = translate("WITHDRAW"), selected = true },
        { label = translate("DEPOSIT") },
        { label = translate("RELEASE") },
        { label = translate("CHANGE BOX") },
        { label = translate("PRINT") },
        { label = translate("BACK") },
      } or {
        { label = translate("WITHDRAW"), selected = true },
        { label = translate("DEPOSIT") },
        { label = translate("CHANGE BOX") },
        { label = translate("MOVE WITHOUT MAIL") },
        { label = translate("BACK") },
      }
      theme:pcRoot({ kind = "pokemon", title = translate("POKEMON PC"),
        status = format("%s  %d/20", format("BOX %d", 3), 12),
        entries = entries })
    elseif legacyPcQuantity then
      theme:pcQuantity({ label = "RARE CANDY", qty = 99, icon = "item" })
    elseif legacyPcSubmenu then
      theme:pcList({ summary = translate("CHOOSE ACTION"), entries = {
        { label = translate("WITHDRAW"), selected = true },
        { label = translate("STATS") },
        { label = translate("RELEASE") },
        { label = translate("CANCEL") },
      } })
    elseif legacyPcNotice then
      theme:pcNotice({ kind = "items",
        lines = { "THE ITEM STORAGE", "IS COMPLETELY FULL.",
          "CHOOSE ANOTHER ITEM", "OR GO BACK." } })
    elseif legacyPcTop then
      theme:pcTopOnly({ kind = "items" })
    else
      local entries
      if legacyPcBox then
        entries = {
          { mon = party[1], label = party[1].name, right = "LV.35",
            selected = true },
          { mon = party[2], label = party[2].name, right = "LV.28" },
          { mon = party[3], label = party[3].name, right = "LV.28" },
          { label = translate("BACK"), back = true },
        }
      elseif legacyPcChange then
        entries = {
          { kind = "box", label = format("BOX %d", 1), right = "20/20" },
          { kind = "box", label = format("BOX %d", 2), right = "08/20" },
          { kind = "box", label = "WATERMON", right = "12/20",
            selected = true },
          { kind = "box", label = format("BOX %d", 4), right = "00/20" },
        }
      elseif legacyPcDeposit then
        entries = {
          { kind = "item", icon = "item", label = "MAX POTION",
            right = "x99", selected = true },
          { kind = "item", icon = "item", label = "SILVER LEAF",
            right = "x1" },
          { kind = "item", icon = "item", label = "ESCAPE ROPE",
            right = "x12" },
          { label = translate("CANCEL"), back = true },
        }
      else
        entries = {
          { kind = "item", icon = "item", label = "POTION", right = "x12",
            selected = true },
          { kind = "item", icon = "item", label = "RARE CANDY", right = "x3" },
          { kind = "item", icon = "item", label = "ESCAPE ROPE", right = "x2" },
          { label = translate("BACK"), back = true },
        }
      end
      theme:pcList({ summary = legacyPcChange and format("PAGE %d/%d", 1, 4)
          or legacyPcDeposit and translate("ITEMS")
          or legacyPcItems and format("%s %d/%d", translate("ITEM PC"), 1, 3)
          or format("BOX %d  %d/20  %d/%d", 3, 12, 1, 3),
        entries = entries,
        drawPokemon = function(mon, x, y, size, fainted)
          local slot = mon == party[1] and 1 or mon == party[2] and 2 or 3
          drawPortrait(slot, x, y, size, fainted)
        end,
      })
    end
  elseif legacyEnemy then
    local source = party[gen1 and 6 or 1]
    local mon = {
      name = source.name, levelText = gen1 and "L30" or "L35",
      dex = gen1 and 128 or 160,
      type = source.type, type2 = source.type2,
      typeLabel = source.typeLabel, type2Label = source.type2Label,
      types = { source.type, source.type2 }, caught = true,
      kind = gen1 and "WILD BULL" or "BIG JAW",
      height = gen1 and "HEIGHT 4 FT 7 IN" or "HEIGHT 7 FT 7 IN",
      weight = gen1 and "WEIGHT 194.9 LB" or "WEIGHT 195.8 LB",
      description = gen1 and {
        "WHEN IT TARGETS AN ENEMY,", "IT CHARGES FURIOUSLY WHILE",
        "WHIPPING ITS BODY WITH", "ITS LONG TAILS.",
      } or {
        "WHEN IT BITES WITH ITS", "MASSIVE JAWS, IT SHAKES ITS",
        "HEAD AND SAVAGELY TEARS", "ITS VICTIM UP.",
      },
      dvs = { hp = 14, attack = 15, defense = 12, speed = 11,
        special = 13 },
      weak = {
        { type = "ELECTRIC", typeLabel = "ELECTRIC", effectLabel = "2X" },
        { type = "GRASS", typeLabel = language.types.GRASS or "GRASS",
          effectLabel = "2X" },
      },
      resist = {
        { type = "FIRE", typeLabel = "FIRE", effectLabel = "1/2" },
        { type = "WATER", typeLabel = language.types.WATER or "WATER",
          effectLabel = "1/2" },
        { type = "ICE", typeLabel = "ICE", effectLabel = "1/2" },
      },
    }
    local model = { pokemon = mon,
      drawPokemon = function(_, x, y, size, fainted)
        drawPortrait(gen1 and 6 or 1, x, y, size, fainted)
      end,
    }
    if legacyEnemyProfile then
      theme:enemyInfoProfile(model)
    elseif legacyEnemyDvs then
      model.rows = {
        { label = "HP", value = mon.dvs.hp },
        { label = "ATTACK", value = mon.dvs.attack },
        { label = "DEFENSE", value = mon.dvs.defense },
        { label = "SPEED", value = mon.dvs.speed },
        { label = "SPECIAL", value = mon.dvs.special },
      }
      theme:enemyInfoDvs(model)
    elseif legacyEnemyWeak or legacyEnemyResist then
      model.kind = legacyEnemyWeak and "weak" or "resist"
      model.rows = mon[model.kind]
      theme:enemyInfoMatchup(model)
    else
      theme:enemyInfoOverview(model)
    end
  elseif legacyMoveNew or legacyMoveForget or legacyMoveInfo then
    local mon = battleMon()
    local slot = gen1 and 6 or 1
    local newMove = gen1 and {
      name = "THUNDERBOLT", type = "ELECTRIC", typeLabel = "ELECTRIC",
      ppText = "15/15", powerText = "95", accuracyText = "100",
      power = 95, available = true, descriptionLines = {
        translate("10.2% CHANCE"), translate("TO PARALYZE TARGET") },
    } or {
      name = "ICE PUNCH", type = "ICE", typeLabel = "ICE",
      ppText = "15/15", powerText = "75", accuracyText = "100",
      power = 75, available = true, descriptionLines = {
        "AN ICY PUNCH.", "MAY FREEZE THE TARGET." },
    }
    if legacyMoveNew then
      theme:moveLearnPrompt({ mon = mon, newMove = newMove, details = true,
        choices = os.getenv("KANTO_GEAR_PREVIEW_CHOICE") == "1"
          and { "YES", "NO" } or nil,
        choice = os.getenv("KANTO_GEAR_PREVIEW_CHOICE") == "1" and 1 or nil,
        drawPokemon = function(_, x, y, size, fainted)
          drawPortrait(slot, x, y, size, fainted)
        end,
      })
    elseif legacyMoveForget then
      for _, move in ipairs(mon.moves) do move.available = true end
      theme:moveLearnList({ newMove = newMove, moves = mon.moves,
        index = 2, details = true })
    else
      theme:battleMoveInfoBody(newMove,
        theme:moveHasStab(mon, newMove))
    end
  elseif legacyChoice then
    theme:choiceScreen({
      prompt = { "WOULD YOU LIKE TO GIVE", "THIS POKEMON A NICKNAME?" },
      entries = {
        { x = 24, y = 54, w = 112, h = 32, label = "YES", selected = true },
        { x = 24, y = 90, w = 112, h = 32, label = "NO" },
      },
    })
  elseif legacyChoiceGrid then
    local labels = { "HEAL", "MOVE", "ITEM", "CANCEL" }
    local entries = {}
    for index, label in ipairs(labels) do
      entries[index] = { x = 8 + ((index - 1) % 2) * 74,
        y = 38 + math.floor((index - 1) / 2) * 39,
        w = 70, h = 34, label = label, selected = index == 2 }
    end
    theme:choiceScreen({ entries = entries })
  elseif legacyNaming then
    local rows = {
      { "A", "B", "C", "D", "E", "F", "G", "H", "I" },
      { "J", "K", "L", "M", "N", "O", "P", "Q", "R" },
      { "S", "T", "U", "V", "W", "X", "Y", "Z", "-" },
      { "LOWER", "DEL", "END" },
    }
    local entries = {}
    for row, cells in ipairs(rows) do
      for col, label in ipairs(cells) do
        local left = 3 + math.floor((col - 1) * 154 / #cells)
        local right = 3 + math.floor(col * 154 / #cells)
        entries[#entries + 1] = { x = left, y = 36 + (row - 1) * 17,
          w = right - left, h = 15, label = label,
          selected = row == 1 and col == 4, action = row == #rows }
      end
    end
    theme:naming({ name = "GOLD", entries = entries })
  elseif legacyLevelUp then
    theme:levelUp({ name = gen1 and "TAUROS" or "FERALIGATR",
      level = "L36", type = gen1 and "NORMAL" or "WATER",
      rows = gen1 and {
        { label = "ATTACK", value = 84 },
        { label = "DEFENSE", value = 78 },
        { label = "SPEED", value = 91 },
        { label = "SPECIAL", value = 58 },
      } or {
        { label = "ATTACK", value = 92 },
        { label = "DEFENSE", value = 83 },
        { label = "SPCL.ATK", value = 70 },
        { label = "SPCL.DEF", value = 75 },
        { label = "SPEED", value = 66 },
      },
      drawPokemon = function(x, y, size)
        drawPortrait(gen1 and 6 or 1, x, y, size, false)
      end,
    })
  elseif regionMap then
    theme:regionMap({ area = gen1 and "ROUTE 15" or "ROUTE 37",
      drawMap = function(x, y, w, h)
        local coast = theme.dark and { 0.08, 0.20, 0.27, 1 }
          or { 0.60, 0.82, 0.88, 1 }
        local land = theme.dark and { 0.22, 0.38, 0.20, 1 }
          or { 0.67, 0.82, 0.54, 1 }
        local road = theme.dark and { 0.50, 0.39, 0.18, 1 }
          or { 0.91, 0.73, 0.34, 1 }
        box("fill", x, y, w, h, coast)
        local tile = 9
        for row = 1, 13 do
          for col = 1, 18 do
            local shore = (row <= 2 and col > 4)
              or (row >= 10 and col < 15)
              or (col <= 2 and row > 5)
            if not shore then
              box("fill", x + 17 + (col - 1) * tile,
                y + 10 + (row - 1) * tile, tile, tile,
                (row == 7 or col == 9 and row > 3 and row < 11)
                  and road or land)
            end
          end
        end
        box("fill", x + 17 + 8 * tile, y + 10 + 6 * tile,
          tile, tile, theme.colors.redLight)
        box("fill", x + 20 + 8 * tile, y + 13 + 6 * tile,
          3, 3, theme.colors.white)
      end })
    if regionMapFly then
      theme:toolPrompt({ icon = "teleport",
        label = gen1 and "FUCHSIA CITY" or "GOLDENROD CITY" })
    end
  elseif storeToday then
    theme:storeToday({
      featured = storeCatalog[4],
      recommended = {
        { id = "party", icon = "party", label = "PARTY",
          reason = "TEAM STATUS", state = "open" },
        { id = "bag", icon = "bag", label = "BAG",
          reason = "ITEM POCKETS", action = "GET", state = "get" },
      },
    })
  elseif storeApps then
    local page, size = tonumber(os.getenv("KANTO_GEAR_PREVIEW_PAGE")) or 1, 6
    local pages, apps = math.ceil(#storeCatalog / size), {}
    page = math.max(1, math.min(pages, page))
    for index = (page - 1) * size + 1,
        math.min(#storeCatalog, page * size) do
      apps[#apps + 1] = storeCatalog[index]
    end
    theme:storeApps({ apps = apps, page = page, pages = pages })
  elseif storeLibrary then
    local installed = {
      storeCatalog[1], storeCatalog[2], storeCatalog[3], storeCatalog[5],
      storeCatalog[6], storeCatalog[7], storeCatalog[8],
    }
    local page, size = tonumber(os.getenv("KANTO_GEAR_PREVIEW_PAGE")) or 1, 4
    local pages, apps = math.ceil(#installed / size), {}
    page = math.max(1, math.min(pages, page))
    for index = (page - 1) * size + 1, math.min(#installed, page * size) do
      apps[#apps + 1] = installed[index]
    end
    theme:storeMyApps({
      summary = format("%d APPS READY", #installed), apps = apps,
      page = page, pages = pages,
    })
  elseif storeDetail then
    local detailId = os.getenv("KANTO_GEAR_PREVIEW_STORE_APP") or "notes"
    local detail
    for _, app in ipairs(storeCatalog) do
      if app.id == detailId then detail = app break end
    end
    detail = detail or storeCatalog[#storeCatalog]
    detail.publisher = "SILPH CO."
    detail.description = detail.description or {
      "A REAL LOOK INSIDE THE APP.", "BUILT FOR THE TOUCH SCREEN.",
      "EVERYTHING CLOSE AT HAND.",
    }
    theme:storeDetail({ app = detail })
  elseif settingsRoot then
    theme:settings({ categories = {
      { label = "APPEARANCE", detail = "THEME AND TRANSITIONS",
        accent = "blue" },
      { label = "DISPLAY", detail = "SCREENS AND LAYOUT", accent = "green" },
      { label = "BATTLE", detail = "HUD AND BATTLE INFO", accent = "red" },
      { label = "RESEARCH", detail = "VANILLA TO SPOILERS", accent = "amber" },
      { label = "CONTROLS", detail = "OPTIONAL SHORTCUTS", accent = "blue" },
      { label = "SYSTEM", detail = "HELP AND RESET", accent = "green" },
    } })
  elseif settingsDisplay then
    theme:settings({ category = "display", accent = "green", page = 1,
      pages = 2, rows = {
        { label = "DISPLAY MODE", value = "COMBINED SCREEN" },
        { label = "LAYOUT", value = "SIDE BY SIDE" },
        { label = "PRIMARY VIEW", value = "GAME" },
        { label = "SECONDARY SIZE", value = "40%" },
        { label = "BOTTOM SAFE AREA", value = "30%" },
        { label = "OVERLAY CORNER", value = "BOTTOM RIGHT" },
      } })
  elseif settingsAppearance then
    theme:settings({ category = "appearance", accent = "blue", page = 1,
      pages = 1, rows = {
        { label = "LANGUAGE", value = ({ en = "ENGLISH", de = "DEUTSCH",
          es = "ESPANOL", fr = "FRANCAIS" })[languageCode] or "ENGLISH" },
        { label = "THEME", value = "HGSS AUTO" },
        { label = "CLOCK SOURCE", value = "GAME (GEN 2)" },
        { label = "TRANSITIONS", value = "ON" },
      } })
  elseif settingsSystem then
    theme:settings({ category = "system", accent = "green", page = 1,
      pages = 1, rows = {
        { label = "CUSTOMIZE HOME", value = "SHOW ME", action = "home_help" },
        { label = "RESET HOME", value = "RESET", action = "reset_home" },
        { label = "RESET OPTIONS", value = "TAP AGAIN",
          action = "reset_options" },
      } })
  elseif toolsPrompt then
    theme:tools({ actions = toolActions, page = toolPage, pages = toolPages })
    theme:toolPrompt({ icon = "teleport", label = "TELEPORT" })
  elseif toolsRods then
    theme:rodPicker({
      { id = "OLD_ROD", label = "OLD ROD" },
      { id = "GOOD_ROD", label = "GOOD ROD" },
      { id = "SUPER_ROD", label = "SUPER ROD" },
    })
  elseif toolsScreen then
    theme:tools({ actions = toolActions, page = toolPage, pages = toolPages })
  elseif home then
    local catalog = {
      packages = {
        explorer = { installed = true }, map = { installed = true },
        party = { installed = true },
        bag = { installed = true }, pokedex = { installed = true },
        trainer = { installed = true }, tools = { installed = true },
        steps = { installed = true },
        store = { installed = true }, settings = { installed = true },
        notes = { installed = true },
      },
      surfaces = {
        explorer_widget = { package = "explorer", kind = "widget",
          widget = "explorer", columns = 7, label = "EXPLORER" },
        explorer_app = { package = "explorer", kind = "app", columns = 3,
          icon = "explorer", accent = "green", label = "EXPLORER" },
        map_app = { package = "map", kind = "app", columns = 3,
          icon = "map", accent = "blue", label = "MAP" },
        party_widget = { package = "party", kind = "widget",
          widget = "party", columns = 5, label = "PARTY" },
        party_team_widget = { package = "party", kind = "widget",
          widget = "team", columns = 12, label = "TEAM VIEW" },
        pokedex_widget = { package = "pokedex", kind = "widget",
          widget = "pokedex", columns = 5, label = "POKEDEX" },
        trainer_widget = { package = "trainer", kind = "widget",
          widget = "trainer", columns = 5, label = language.homeTrainer },
        map_widget = { package = "map", kind = "widget",
          widget = "map", columns = 7, label = "MAP" },
        bag_widget = { package = "bag", kind = "widget",
          widget = "bag", columns = 5, label = "BAG" },
        store_widget = { package = "store", kind = "widget",
          widget = "store", columns = 5, label = language.homeStore },
        party_app = { package = "party", kind = "app", columns = 3,
          icon = "party", accent = "green", label = "PARTY" },
        bag_app = { package = "bag", kind = "app", columns = 3,
          icon = "bag", accent = "amber", label = "BAG" },
        pokedex_app = { package = "pokedex", kind = "app", columns = 3,
          icon = "pokedex", accent = "red", label = "POKEDEX" },
        trainer_app = { package = "trainer", kind = "app", columns = 3,
          icon = "trainer", accent = "blue", label = language.homeTrainer },
        steps_widget = { package = "steps", kind = "widget",
          widget = "steps", columns = 5, label = "STEPS" },
        steps_app = { package = "steps", kind = "app", columns = 3,
          icon = "steps", accent = "green", label = "STEPS" },
        tools_app = { package = "tools", kind = "app", columns = 3,
          icon = "tools", accent = "green", label = "TOOLS" },
        tool_widget_bicycle = { package = "tools", kind = "widget",
          widget = "tool", columns = 3, icon = "bicycle", label = "BICYCLE",
          actionId = "bicycle", ready = true },
        tool_widget_old_rod = { package = "tools", kind = "widget",
          widget = "tool", columns = 3, icon = "fish", label = "OLD ROD",
          actionId = "fish", rodId = "OLD_ROD", ready = true },
        tool_widget_surf = { package = "tools", kind = "widget",
          widget = "tool", columns = 3, icon = "surf", label = "SURF",
          actionId = "surf", ready = false },
        tool_widget_cut = { package = "tools", kind = "widget",
          widget = "tool", columns = 3, icon = "cut", label = "CUT",
          actionId = "cut", ready = true },
        store_app = { package = "store", kind = "app", columns = 3,
          icon = "store", accent = "green", label = language.homeStore },
        settings_app = { package = "settings", kind = "app", columns = 3,
          icon = "settings", accent = "blue", label = "OPTIONS" },
        notes_app = { package = "notes", kind = "app", columns = 3,
          icon = "notes", accent = "amber", label = language.homeNotes },
      },
    }
    local layout = { tiles = {
      { id = "explorer_widget", page = 1, column = 1, row = 1 },
      { id = "party_widget", page = 1, column = 8, row = 1 },
      { id = "map_app", page = 1, column = 1, row = 2 },
      { id = "tools_app", page = 1, column = 4, row = 2 },
      { id = "store_app", page = 1, column = 7, row = 2 },
      { id = "settings_app", page = 1, column = 10, row = 2 },
    } }
    if screen:sub(1, 9) == "home-team" then
      layout.tiles = {
        { id = "party_team_widget", page = 1, column = 1, row = 1 },
        { id = "explorer_widget", page = 1, column = 1, row = 2 },
        { id = "party_widget", page = 1, column = 8, row = 2 },
      }
    elseif screen == "home-empty" or screen == "home-help-empty" then
      layout.tiles = {}
    elseif screen == "home-help-bottom" then
      layout.tiles = { { id = "party_widget", page = 1, column = 1, row = 2 } }
    elseif screen == "home-help-icon" then
      layout.tiles = { { id = "map_app", page = 1, column = 1, row = 1 } }
    elseif screen == "home-tools" then
      layout.tiles = {
        { id = "tool_widget_bicycle", page = 1, column = 1, row = 1 },
        { id = "tool_widget_old_rod", page = 1, column = 4, row = 1 },
        { id = "tool_widget_surf", page = 1, column = 7, row = 1 },
        { id = "tool_widget_cut", page = 1, column = 10, row = 1 },
        { id = "explorer_widget", page = 1, column = 1, row = 2 },
        { id = "party_widget", page = 1, column = 8, row = 2 },
      }
    elseif screen == "home-pair" then
      layout.tiles = {
        { id = "store_app", page = 1, column = 1, row = 1 },
        { id = "notes_app", page = 1, column = 4, row = 1 },
      }
    elseif screen == "home-icon-pair" then
      layout.tiles = {
        { id = "explorer_app", page = 1, column = 1, row = 1 },
        { id = "map_app", page = 1, column = 5, row = 1 },
        { id = "tools_app", page = 1, column = 9, row = 1 },
      }
    elseif screen == "home-widgets-dex" then
      layout.tiles = {
        { id = "pokedex_widget", page = 1, column = 1, row = 1 },
        { id = "trainer_widget", page = 1, column = 6, row = 1 },
        { id = "explorer_widget", page = 1, column = 1, row = 2 },
        { id = "party_widget", page = 1, column = 8, row = 2 },
      }
    elseif screen == "home-widgets-map-bag" then
      layout.tiles = {
        { id = "map_widget", page = 1, column = 1, row = 1 },
        { id = "bag_widget", page = 1, column = 8, row = 1 },
        { id = "explorer_widget", page = 1, column = 1, row = 2 },
        { id = "party_widget", page = 1, column = 8, row = 2 },
      }
    elseif screen == "home-widget-store" then
      layout.tiles = {
        { id = "explorer_widget", page = 1, column = 1, row = 1 },
        { id = "store_widget", page = 1, column = 8, row = 1 },
        { id = "map_widget", page = 1, column = 1, row = 2 },
        { id = "bag_widget", page = 1, column = 8, row = 2 },
      }
    end
    if homeAdd then
      Home.remove(layout, "party_widget")
      Home.remove(layout, "notes_app")
    end
    local homePages = Home.pageCount(layout) + (homeEdit and 1 or 0)
    local homePage = math.max(1, math.min(homePages,
      math.floor(tonumber(os.getenv("KANTO_GEAR_PREVIEW_PAGE"))
        or (homeEdit and 2 or 1))))
    local overview = {
      width = 24, height = 12,
      rows = {
        "                        ",
        "    ++++      ~~~~      ",
        "  ++++++++++  ~~~~      ",
        "  +.........++++++      ",
        "+++..................+++",
        "........................",
        "........................",
        "+++.......++++.......+++",
        "   +++++++    +++++++   ",
        "      ~~          ~~    ",
        "      ~~~~      ~~~~    ",
        "                        ",
      },
    }
    local team = {}
    for slot, mon in ipairs(party) do
      if screen ~= "home-team-small" or slot <= 2 then
        team[slot] = {}
        for key, value in pairs(mon) do team[slot][key] = value end
        team[slot].slot = slot
      end
    end
    if screen == "home-team-small" then team[2].levelText = "L100" end
    local model = {
      page = homePage, pages = homePages,
      help = screen == "home-help" or screen == "home-help-bottom"
        or screen == "home-help-empty" or screen == "home-help-icon",
      tiles = Home.tiles(layout, catalog, homePage),
      editing = homeEdit,
      route = gen1 and "ROUTE 15" or "ROUTE 37",
      overview = overview,
      player = { x = 12, y = 6, facing = "down" },
      markers = {
        { kind = "warp", x = 1, y = 6 },
        { kind = "item", x = 18, y = 6 },
      },
      lead = party[gen1 and 6 or 1], team = team,
      steps = "184K",
      dexCaught = gen1 and 83 or 146,
      dexSeen = gen1 and 112 or 201,
      dexTotal = gen1 and 151 or 251,
      dexLatest = { name = gen1 and "TAUROS" or "JUMPLUFF" },
      trainer = {
        name = gen1 and "RED" or "GOLD",
        region = gen1 and "KANTO" or "JOHTO",
        badgeCount = gen1 and 5 or 6, badgeTotal = 8,
        money = gen1 and "¥34820" or "¥67240",
        moneyShort = gen1 and "¥34K" or "¥67K",
        time = gen1 and "18:42" or "42:17",
        badgeOwned = { true, true, true, true, true,
          not gen1, not gen1, false },
      },
      bag = { item = 18, medicine = 9, ball = 24, machine = 7 },
      regionMap = {
        region = gen1 and "KANTO" or "JOHTO",
        area = gen1 and "ROUTE 15" or "ROUTE 37",
        drawMap = function(x, y, w, h)
          box("fill", x, y, w, h, theme.colors.blueLight)
          color(theme.colors.band)
          love.graphics.setLineWidth(3)
          love.graphics.line(x + 7, y + h - 8, x + 27, y + h - 8,
            x + 27, y + 10, x + 58, y + 10, x + 58, y + h - 15,
            x + 88, y + h - 15, x + 88, y + 8, x + w - 8, y + 8)
          love.graphics.setLineWidth(1)
          for _, point in ipairs({ {7,h-8}, {27,10}, {58,h-15},
              {88,8}, {w-8,8} }) do
            color(theme.colors.surface)
            love.graphics.circle("fill", x + point[1], y + point[2], 4)
            color(theme.colors.outline)
            love.graphics.circle("line", x + point[1], y + point[2], 4)
          end
          color(theme.colors.red)
          love.graphics.circle("fill", x + 58, y + h - 15, 4)
          color(theme.colors.white)
          love.graphics.circle("fill", x + 58, y + h - 15, 1)
        end,
      },
      storePromo = os.getenv("KANTO_GEAR_PREVIEW_STORE_QUIET") == "1"
        and { icon = "store", label = "APPS", installed = 8, available = 8 }
        or { icon = "pokedex", label = "POKEDEX",
          category = "RESEARCH", new = true },
      drawPlayer = function(_, x, y, tileSize)
        drawOverworld("player", x, y, tileSize / 16, theme.colors.redLight)
      end,
      drawPokemon = function(mon, x, y, size, fainted)
        drawPortrait(mon.slot or (gen1 and 6 or 1), x, y, size, fainted)
      end,
      drawDexPokemon = function(_, x, y, size)
        drawPortrait(gen1 and 6 or 2, x, y, size, false)
      end,
    }
    if homeEdit then
      if os.getenv("KANTO_GEAR_PREVIEW_HOME_FOCUS") == "1"
          and model.tiles[1] then
        model.dragging = model.tiles[1].id
      end
      model.slots = Home.plusSlots(layout, catalog, homePage, model.dragging)
      local rowItems = {}
      for _, tile in ipairs(model.tiles) do rowItems[#rowItems + 1] = tile end
      for _, slot in ipairs(model.slots) do rowItems[#rowItems + 1] = slot end
      Home.spaceRows(rowItems)
    end
    if homeAdd then
      model.tiles = nil
      model.libraryKind = os.getenv("KANTO_GEAR_PREVIEW_LIBRARY") == "widget"
        and "widget" or "app"
      model.library = Home.library(layout, catalog, 2, 10, 2,
        model.libraryKind)
      model.libraryPages = math.max(1, math.ceil(#model.library / 6))
      model.libraryPage = math.max(1, math.min(model.libraryPages,
        math.floor(tonumber(os.getenv("KANTO_GEAR_PREVIEW_PAGE")) or 1)))
    end
    if screen:sub(1, 9) == "home-team" then
      local tile = model.tiles[1]
      local tx, _, tw = theme:homeRect(tile)
      local firstX = theme:homeTeamSlotRect(tile, 1)
      local lastX, _, lastW = theme:homeTeamSlotRect(tile, 6)
      assert(firstX - tx == tx + tw - lastX - lastW,
        "team portrait group has equal outer margins")
      for slot = 1, 6 do
        local x, y, w, h = theme:homeTeamSlotRect(tile, slot)
        assert(theme:homeTeamSlotAt(x + w / 2, y + h / 2, tile, #team)
            == (slot <= #team and slot or nil), "team touch follows each occupied slot")
      end
      assert(theme:homeTeamSlotAt(tx + tw / 2, 42, tile, #team) == nil,
        "team header is separate from member touches")
      if screen == "home-team-pressed" then
        local x, y = theme:homeTeamSlotRect(tile, 2)
        theme:setTouch((x + 17) / 1.5, (y + 20) / 1.5)
      end
    end
    theme:home(model)
  elseif bag then
    local entries = {
      { id = "POTION", label = "POTION", count = 12,
        icon = "medicine", lines = {
          "RESTORES 20 HP TO ONE POKEMON.",
        } },
      { id = "GREAT_BALL", label = "GREAT BALL", count = 8,
        icon = "ball", lines = {
          "A GOOD BALL WITH A HIGHER", "CATCH RATE THAN A POKE BALL.",
        } },
      { id = "ANTIDOTE", label = "ANTIDOTE", count = 3,
        icon = "status", lines = { "CURES A POISONED POKEMON." } },
      { id = "TM_24", label = "TM24", count = 1, icon = "machine",
        detail = "THUNDERBOLT", lines = wrap(format(
          "TEACHES %s TO A COMPATIBLE POKEMON.", "THUNDERBOLT"), 31, 3) },
      { id = "ESCAPE_ROPE", label = "ESCAPE ROPE", count = 2,
        icon = "item", lines = {
          "ESCAPE FROM A CAVE OR DUNGEON.",
        } },
      { id = "SUPER_POTION", label = "SUPER POTION", count = 4,
        icon = "medicine", lines = {
          "RESTORES 50 HP TO ONE POKEMON.",
        } },
    }
    local model = {
      pocket = translate("ITEMS"), pocketIndex = 1,
      pockets = gen1 and 1 or 4, page = 1, pages = 2,
      entries = entries, total = 12, canUse = true, money = 34820,
      detail = bagDetail and entries[4] or nil,
    }
    theme:bag(model)
    if bagOverview then
      local action, index = theme:bagHit(130, 80, model)
      assert(action == "item" and index == 2,
        "Bag cards are touch reachable")
    else
      assert(theme:bagHit(120, 185, model) == "use",
        "Bag USE action is touch reachable")
    end
  elseif pokedex then
    local names = { "BULBASAUR", "IVYSAUR", "VENUSAUR", "CHARMANDER",
      "CHARMELEON", "CHARIZARD", "SQUIRTLE", "WARTORTLE", "BLASTOISE" }
    local assets = { "bulbasaur", "ivysaur", "venusaur", "charmander",
      "charmeleon", "charizard", "squirtle", "wartortle", "blastoise" }
    local tints = { theme.colors.greenLight, theme.colors.greenLight,
      theme.colors.green, theme.colors.redLight, theme.colors.red,
      theme.colors.amberLight, theme.colors.blueLight,
      theme.colors.blueLight, theme.colors.blue }
    local entries = {}
    for index, name in ipairs(names) do
      entries[index] = {
        dex = index, name = name, asset = assets[index], tint = tints[index],
        caught = index == 1 or index == 3 or index == 6
          or index == 8 or index == 9,
      }
    end
    local gyarados = {
      dex = 130, name = "GYARADOS", caught = true, asset = "gyarados",
      tint = theme.colors.blueLight,
      type = "WATER", type2 = "FLYING",
      typeLabel = "WAT", type2Label = "FLY",
      kind = "ATROCIOUS",
      height = gen1 and "21 FT 04 IN" or "21 FT 04 IN",
      weight = "518.1 LB",
      description = {
        "BRUTALLY VICIOUS AND ENORMOUSLY",
        "DESTRUCTIVE. KNOWN FOR RAZING",
        "ENTIRE CITIES IN ANCIENT TIMES.",
      },
    }
    local function drawDexPokemon(row, x, y, size, uncaught)
      local sprite = dexSprites[row.asset]
      if not sprite then return end
      if uncaught then love.graphics.setShader(galleryGray) end
      local scale = size / math.max(sprite.width, sprite.height)
      love.graphics.setColor(unpack(not uncaught and row.tint or { 1, 1, 1, 1 }))
      love.graphics.draw(sprite.image, sprite.quad,
        x + (size - sprite.width * scale) / 2,
        y + (size - sprite.height * scale) / 2, 0, scale, scale)
      if uncaught then love.graphics.setShader() end
    end
    local model = {
      view = pokedexProfile and "profile"
        or pokedexHabitat and "habitat"
        or pokedexStats and "stats"
        or pokedexMoves and "moves" or "index",
      region = gen1 and "KANTO DEX" or "NATIONAL DEX",
      caught = gen1 and 72 or 118, total = gen1 and 151 or 251,
      page = 1,
      pages = pokedexHabitat and 4 or pokedexMoves and 7
        or (gen1 and 17 or 28),
      entries = entries,
      pokemon = gyarados, drawPokemon = drawDexPokemon,
      statsText = format("BST %d", gen1 and 480 or 540),
      habitatText = format("%d AREAS", gen1 and 12 or 17),
      movesText = format("%d MOVES", gen1 and 34 or 48),
      summary = format("%d AREAS", gen1 and 12 or 17),
      status = "NOT HERE", current = false,
      catchText = format("CATCH %d", 45),
      expText = format("XP %d", gen1 and 214 or 216),
      stats = gen1 and {
        { label = "HP", value = 95 }, { label = "ATK", value = 125 },
        { label = "DEF", value = 79 }, { label = "SPECIAL", value = 100 },
        { label = "SPEED", value = 81 },
      } or {
        { label = "HP", value = 95 }, { label = "ATK", value = 125 },
        { label = "DEF", value = 79 }, { label = "SP.ATK", value = 60 },
        { label = "SP.DEF", value = 100 }, { label = "SPEED", value = 81 },
      },
      rows = {
        { area = gen1 and "SAFARI ZONE - CENTER" or "LAKE OF RAGE",
          time = "ANY TIME", method = "SURF", chance = 10,
          levels = gen1 and "L15" or "L15-20" },
        { area = gen1 and "FUCHSIA CITY" or "ROUTE 43 - LAKE GATE",
          time = gen1 and "ANY TIME" or "NITE", method = "SUPER",
          chance = gen1 and 15 or 10, levels = gen1 and "L15" or "L40" },
        { area = gen1 and "SEAFOAM ISLANDS B4F" or "DRAGON'S DEN",
          time = "ANY TIME", method = "SUPER", chance = 10,
          levels = gen1 and "L15" or "L40" },
      },
    }
    if pokedexStats then model.summary = model.statsText end
    if pokedexMoves then
      model.rows = {
        { method = translate("START"), name = "THRASH", type = "NORMAL",
          type2 = "NORMAL", typeLabel = "NOR", type2Label = "NOR" },
        { method = "L20", name = "BITE", type = "DARK",
          type2 = "DARK", typeLabel = "DAR", type2Label = "DAR" },
        { method = "L30", name = "DRAGON RAGE", type = "DRAGON",
          type2 = "DRAGON", typeLabel = "DRA", type2Label = "DRA" },
        { method = translate("TM/HM"), name = "SURF", type = "WATER",
          type2 = "WATER", typeLabel = "WAT", type2Label = "WAT" },
      }
    end
    theme:pokedex(model)
    if pokedexIndex then
      assert(theme:pokedexHit(18, 78, model) == "species",
        "Pokedex gallery portraits are touch reachable")
    elseif pokedexProfile then
      assert(theme:pokedexHit(120, 180, model) == "habitat",
        "Pokedex research cards are touch reachable")
    elseif pokedexHabitat or pokedexMoves then
      assert(theme:pokedexHit(90, 205, model) == "prev",
        "Pokedex pagers are touch reachable")
    end
  elseif trainerSteps then
    theme:steps({ steps = "184392" })
  elseif trainerScreen then
    local owned = gen1 and 5 or 11
    local badgeOwned = {}
    for index = 1, 8 do badgeOwned[index] = index <= (gen1 and 5 or 6) end
    local badgeTints = {
      theme.colors.redLight, theme.colors.blueLight, theme.colors.amberLight,
      theme.colors.greenLight,
    }
    theme:trainer({
      name = gen1 and "RED" or "GOLD",
      region = gen1 and "KANTO" or "JOHTO",
      idText = "ID 12345",
      badgeText = owned .. "/" .. (gen1 and 8 or 16),
      badgeRegion = gen1 and "KANTO" or "JOHTO",
      badgeOwned = badgeOwned,
      money = gen1 and "¥34820" or "¥67240",
      time = "42:17",
      pokedex = gen1 and "72/151" or "118/251",
      drawPlayer = function(x, y, scale)
        drawOverworld("player", x, y, scale, nil, true)
      end,
      drawBadge = function(index, cx, cy, isOwned)
        local tint = isOwned and badgeTints[(index - 1) % 4 + 1]
          or theme.colors.silver
        color(theme.colors.outline)
        love.graphics.circle("fill", cx, cy, 6)
        color(tint)
        love.graphics.circle("fill", cx, cy, 4)
        if index % 2 == 0 then
          box("fill", cx - 1, cy - 5, 2, 10, tint)
        else
          box("fill", cx - 5, cy - 1, 10, 2, tint)
        end
        return true
      end,
    })
  elseif explorer then
    drawExplorer()
  elseif legacySafari then
    enemyTeam.wild, enemyTeam.name, enemyTeam.level = true, "RHYHORN", 25
    theme:battleSafari({ balls = 23,
      index = tonumber(os.getenv("KANTO_GEAR_PREVIEW_INDEX")) or 1 },
      playerTeam, enemyTeam)
  elseif legacyMimic then
    local mon = battleMon()
    theme:battleMimic({ moves = mon.moves,
      index = tonumber(os.getenv("KANTO_GEAR_PREVIEW_INDEX")) or 2 },
      playerTeam, enemyTeam)
  elseif battleMessage then
    local wild = os.getenv("KANTO_GEAR_PREVIEW_BATTLE") == "wild"
    if wild then
      enemyTeam.name, enemyTeam.level = "RATTATA", 3
    end
    theme:battleMessage(wild and { "WILD RATTATA APPEARED!" }
        or { "LEADER WHITNEY SENT OUT", "MILTANK!" },
      os.getenv("KANTO_GEAR_PREVIEW_PROMPT") ~= "0",
      playerTeam, enemyTeam, nil,
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
  elseif summaryMoveInfo then
    local mon = battleMon()
    local move = mon.moves[mon.moveIndex] or {}
    move.effectiveness = nil
    theme:battleMoveInfoBody(move, theme:moveHasStab(mon, move))
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
  elseif battleFull then
    local mon = battleMon()
    local slot = gen1 and 6 or 1
    local player = party[slot]
    player.statusId = gen1 and "SLP" or nil
    player.hpText = string.format("%d/%d", player.hp, player.maxHp)
    player.levelText = player.levelText or "L" .. tostring(player.level or 0)
    local enemy = {
      species = gen1 and "RHYDON" or "RATICATE",
      name = gen1 and "RHYDON" or "RATICATE",
      level = gen1 and 42 or 16,
      levelText = gen1 and "L42" or "L16",
      hp = gen1 and 88 or 31,
      maxHp = gen1 and 126 or 45,
      statusId = "PAR",
      statusLabel = "PAR",
      caught = true,
    }
    theme:battleFullRoot(mon, player, enemy,
      function(subject, x, y, size, fainted)
        if subject == player then drawPortrait(slot, x, y, size, fainted)
        else drawPortrait(gen1 and 4 or 2, x, y, size, fainted) end
      end, playerTeam, enemyTeam,
      tonumber(os.getenv("KANTO_GEAR_PREVIEW_INDEX")) or 1)
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
    end, 1, 2, transitionProgress, 2, translate(language.stats), translate(language.swap))
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
    mon.statsTitle = translate("BATTLE STATS")
    if gen1 then
      mon.dexText, mon.levelText = "NO.128", "L35"
      mon.gender, mon.statusId = nil, nil
      mon.hp, mon.maxHp, mon.hpText = 96, 108, "96/108"
      mon.expProgress, mon.expText = 0.46, nil
      mon.nextLabel, mon.nextValue = translate("NEXT"), "2415"
      mon.infoLabel, mon.infoText = translate("OT"), "RED"
      mon.info2Label, mon.info2Text = translate("ID"), "12345"
      mon.stats = {
        { label = "ATTACK", value = 84 },
        { label = "SPEED", value = 91 },
        { label = "DEFENSE", value = 78 },
        { label = "SPECIAL", value = 58 },
      }
    else
      mon.dexText = "NO.160"
      mon.infoLabel, mon.infoText = translate("ITEM"), "MYSTIC WATER"
      mon.nextLabel, mon.nextValue = translate("NEXT"), "4218"
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
    for _, stat in ipairs(mon.stats) do stat.label = translate(stat.label) end
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
      mon.moveIndex = os.getenv("KANTO_GEAR_PREVIEW_CONTEXT") ~= "field" and 1 or nil
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
        translate(language.stats), translate(language.swap))
    else
      theme:summaryPage(mon, summaryPortrait)
    end
  elseif context then
    local actionCount = tonumber(os.getenv("KANTO_GEAR_PREVIEW_ACTIONS")) or 2
    drawMon(1, 64, theme:partyActionHeroY(actionCount), true, false, false)
    local x, y, w, h = theme:partyActionRow(1, actionCount)
    theme:actionRow(x, y, w, h, translate(language.stats), "stats", 0, true)
    if actionCount > 1 then
      x, y, w, h = theme:partyActionRow(2, actionCount)
      theme:actionRow(x, y, w, h, translate(language.swap), "swap", 0)
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
  local missing = i18n:coverage(languageCode)
  assert(#missing == 0, "missing " .. languageCode
    .. " translations: " .. table.concat(missing, ", "))
  local file = assert(io.open(output, "wb"))
  file:write(data:getString())
  file:close()
  love.event.quit()
end
