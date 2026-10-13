local core = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/core.lua"))()
local Area = core.Area
local THEME = core.THEME
local addEncounters = core.addEncounters
local battleUIMode = core.battleUIMode
local bottomOwnsBattleUI = core.bottomOwnsBattleUI
local carouselSubpage = core.carouselSubpage
local categorizedBag = core.categorizedBag
local caughtWild = core.caughtWild
local checklistPages = core.checklistPages
local choiceReady = core.choiceReady
local clockText = core.clockText
local compactClock = core.compactClock
local fillerColor = core.fillerColor
local hasUnlockedTool = core.hasUnlockedTool
local inverted = core.inverted
local localMapGrid = core.localMapGrid
local localMapLayout = core.localMapLayout
local localMapMode = core.localMapMode
local moveGridLayout = core.moveGridLayout
local moveSlotAt = core.moveSlotAt
local namingCell = core.namingCell
local normalize = core.normalize
local oneShotTrainerStatus = core.oneShotTrainerStatus
local pageSwipeAllowed = core.pageSwipeAllowed
local pageWindow = core.pageWindow
local pagedIndex = core.pagedIndex
local partySlotAt = core.partySlotAt
local pcListKind = core.pcListKind
local prepareBattleSnapshot = core.prepareBattleSnapshot
local progressRatio = core.progressRatio
local render = core.render
local rgb24 = core.rgb24
local savedSteps = core.savedSteps
local screenContract = core.screenContract
local supportedBattleUI = core.supportedBattleUI
local textTouch = core.textTouch
local validPalette = core.validPalette
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
       and render.SECONDARY_BACKGROUND == 0x0F380F, "theme palette helpers")

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
  local timestamp = os.time({ year = 2026, month = 1, day = 15,
    hour = 21, min = 5, sec = 0 })
  assert(compactClock("21:05") == "21:05"
    and clockText(timestamp, "system", "09:05 PM") == "9:05PM"
    and clockText(timestamp, "12", "ignored") == "9:05PM"
    and clockText(timestamp, "24", "ignored") == "21:05",
    "selectable system, 12-hour, and 24-hour clock format")
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
       and supportedBattleUI({ battleKind = function() return "oldman" end }),
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
print("Core contracts passed")
