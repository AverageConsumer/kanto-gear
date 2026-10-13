local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local Gifts = assert(loadfile(root .. "/features/gen2_gifts.lua"))()
local Progress = assert(loadfile(root .. "/features/achievements.lua"))()
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local function reward(event, item)
  return { { op = "checkevent", event = event }, { op = "iftrue", script = "DONE" },
    { op = "verbosegiveitem", item = item }, { op = "iffalse", script = "DONE" },
    { op = "setevent", event = event }, { op = "end" } }
end
local data = { gen2Scripts = { DONE = { { op = "end" } }, GIFT = reward(40, 1) },
  gen2Maps = {}, gen2InitialEvents = { flags = {} }, items = { POTION = { index = 1, name = "POTION" } } }
local policy = Gifts.new(data)
T.eq(#policy:catalog("GIFT"), 1, "checked receipt event identifies a literal gift")
T.eq(policy:catalog("GIFT")[1].event, 40, "receipt event is distinct from NPC visibility")
T.eq(policy:catalog("GIFT"), policy:catalog("GIFT"), "idle frames reuse script analysis")
T.eq(#policy:catalog(nil), 0, "NPC without a script has no inferred gifts")
data.gen2Scripts.UNRELATED = { { op = "checkevent", event = 41 }, { op = "iftrue", script = "FLAG" },
  { op = "giveitem", item = 1 }, { op = "end" } }
data.gen2Scripts.FLAG = { { op = "setevent", event = 41 }, { op = "end" } }
T.eq(#policy:catalog("UNRELATED"), 0, "another branch's story flag cannot prove receipt")
data.gen2Scripts.TEMP = reward(7, 1)
T.eq(#policy:catalog("TEMP"), 0, "temporary events never count toward stamps")
data.gen2Scripts.SENTINEL = reward(65535, 1)
T.eq(#policy:catalog("SENTINEL"), 0, "no-event sentinel cannot prove receipt")
data.gen2Scripts.SYMBOL = reward("MOD_EVENT", 1)
T.eq(#policy:catalog("SYMBOL"), 0, "symbolic mod events are conservatively excluded")
data.gen2Scripts.MEMORY = reward(42, 255)
T.eq(#policy:catalog("MEMORY"), 0, "ITEM_FROM_MEM is not a literal reward")
data.gen2Scripts.OPAQUE = reward(43, 1)
table.insert(data.gen2Scripts.OPAQUE, 3, { op = "unknown" })
T.eq(#policy:catalog("OPAQUE"), 0, "unknown mod control flow cannot establish a receipt")
data.gen2Scripts.MISSING = reward(44, 1)
data.gen2Scripts.MISSING[2].script = "ABSENT"
T.eq(#policy:catalog("MISSING"), 0, "missing branch cannot be treated as proof of completion")
data.gen2Scripts.RECURSIVE = reward(45, 1)
data.gen2Scripts.RECURSIVE[2].script = "RECURSIVE"
T.eq(#policy:catalog("RECURSIVE"), 1, "bounded tail-jump cycle keeps the guarded gift provable")
data.gen2Scripts.CALL = { { op = "scall", script = "GIFT" }, { op = "end" } }
T.eq(#policy:catalog("CALL"), 1, "subroutine gift is reached through native calls")
data.gen2Scripts.RETURN = { { op = "checkevent", event = 46 }, { op = "iftrue", script = "DONE" },
  { op = "farscall", script = "GIVE" }, { op = "iffalse", script = "DONE" },
  { op = "setevent", event = 46 }, { op = "end" } }
data.gen2Scripts.GIVE = { { op = "giveitem", item = 1 }, { op = "end" } }
T.eq(#policy:catalog("RETURN"), 1, "Gen2 end returns to the caller's receipt write")
data.gen2Scripts.TAIL = { { op = "checkevent", event = 47 }, { op = "iftrue", script = "DONE" },
  { op = "sjump", script = "GIVE" }, { op = "setevent", event = 47 } }
T.eq(#policy:catalog("TAIL"), 0, "tail jump never resumes at a phantom receipt write")
data.gen2Scripts.RESET = reward(48, 1)
table.insert(data.gen2Scripts.RESET, 5, { op = "clearevent", event = 48 })
T.eq(#policy:catalog("RESET"), 0, "reset within the NPC graph is not a one-time receipt")
data.gen2Scripts.INITIAL = reward(49, 1)
data.gen2InitialEvents.flags = { 49 }
T.eq(#Gifts.new(data):catalog("INITIAL"), 0, "seeded visibility flags are not received gifts")
data.gen2Scripts.RENEWABLE = reward(50, 1)
data.gen2Scripts.DAILY_RESET = { { op = "clearevent", event = 50 } }
T.eq(Gifts.new(data):catalog("RENEWABLE")[1].repeatable, true, "external reset makes the gift informational")

local run = T.sdk.loadMod(root, { generation = 2, data = T.fixtures.fresh() })
T.eq(run.mod and run.mod.state, "loaded", "Gen2 loads the gift reader")
local input
for _, entry in ipairs(run.loader.hooks.chains["input.step"]) do
  if entry.owner == "kanto_gear" then input = entry.callback end
end
local display = up(input, "displayRuntime")
local Area = up(up(display.achievementData, "areaData"), "Area")
local flags = { [90] = true }
local world = { getFlag = function(_, event) return flags[event] == true end }
data.gen2Maps = { TEST = { objects = {
  { index = 1, x = 2, y = 3, sprite = "FISHER", eventFlag = 90, scriptKey = "GIFT" },
  { index = 2, x = 4, y = 5, sprite = "FISHER", eventFlag = 91, scriptKey = "GIFT" },
} } }
local function rows() return Area.gen2Rows(data, {}, world, { "TEST" }) end
local gift = rows()[2][1]
T.eq(#rows()[2], 1, "alternate NPC objects share one receipt objective")
T.eq(gift.index, 2, "visible NPC wins over a hidden alternate")
T.eq(gift.actorId, "TEST_obj_2", "marker points at the source NPC rather than the gift ID")
T.eq(gift.available, true, "unreceived gift stays available, including after a full-bag refusal")
local groups = { { id = "TEST", maps = { "TEST" } } }
local context = { gen2 = true, save = {}, mapId = "TEST", flag = function(event) return world:getFlag(event) end }
local function album()
  return Progress.build(groups, function()
    local list = rows()
    return { sections = { { rows = list[1] }, { rows = list[2] }, { rows = list[3] } } }
  end, context).byId.TEST
end
T.eq(album().sections[2].total, 1, "gift contributes once to item completion")
T.eq(album().complete, false, "unreceived gift blocks gold")
flags[40] = true
T.eq(rows()[2][1].done, true, "live receipt flag marks the gift done without bag ownership")
T.eq(album().complete, true, "received and subsequently consumed gift completes the area")
flags[40] = false
T.eq(album().complete, false, "loading an older save restores the unreceived objective")
flags[91] = true
T.eq(rows()[2][1].status, "LATER", "hidden giver is a future objective, never a ground pickup")
world.getFlag = function() return nil end
T.eq(rows()[2][1].untracked, true, "unreadable save event cannot establish collection")
world.getFlag = function(_, event) return flags[event] == true end
data.gen2Maps.TEST.objects = { { index = 3, scriptKey = "RENEWABLE", eventFlag = 65535 } }
T.eq(album().sections[2].total, 0, "repeatable gift does not block gold")
data.gen2Maps.TEST.objects = { { index = 3, scriptKey = "GIFT", eventFlag = 65535,
  trainer = { class = 3, member = 1, event = 80 } } }
T.eq(#rows()[1], 1, "trainer retains its battle objective")
T.eq(#rows()[2], 1, "same trainer also supplies its gift objective")

local game = { data = run.data, save = { generation = 2, version = "crystal", player = {},
  party = {}, inventory = {}, pokedex = {}, flags = {} } }
run.loader.events:emit("game.ready", { game = game })
run.loader.modOptions.kanto_gear = { info_level = "spoiler", theme_v3 = "hgss" }
local api = up(display.saveHome, "mod")
local live = { id = "TEST_obj_3", x = 7, y = 8, visible = true, spriteId = "FISHER" }
api.world = { current = function() return { mapId = "TEST", x = 1, y = 1 } end,
  mapActors = function() return { live } end }
display.knownMap = function() return true end
display.explorerMethods = function() return {} end
display.explorerWildRows = function() return {} end
local explorer = display.explorer
local assist = up(display.explorerModel, "assist")
local overview = { mapId = "TEST", width = 12, height = 12, rows = {}, markers = {} }
for i = 1, 12 do overview.rows[i] = string.rep(".", 12) end
explorer.data = { mapId = "TEST", at = love.timer.getTime(),
  guideEnabled = assist("guide"), areaEnabled = assist("area"), fruits = {},
  guide = { rows = {}, caught = 0 }, area = { sections = {
    { rows = {} }, { rows = rows()[2] }, { rows = {} } } } }
local function model() explorer.renderModel = nil; return display.explorerModel(overview) end
T.eq(model().markers[1].x, 7, "Explorer resolves source NPC ID to its live position")
T.eq(model().markers[1].gift, true, "widget and Explorer share the NPC gift marker")
T.eq(model().markers[1].source.location, "TALK TO NPC", "detail explains the NPC interaction")
live.visible = false
T.eq(#model().markers, 0, "invisible gift NPC has neither a marker nor a touch target")
api.world.mapActors = nil
api.world.npc = function(_, id, index)
  T.eq(id, "TEST", "legacy NPC fallback uses the correct map")
  T.eq(index, 3, "legacy NPC fallback uses source object index")
  return { position = function() return 9, 6 end }
end
explorer.data.area.sections[2].rows = rows()[2]
T.eq(model().markers[1].x, 9, "older host NPC handle updates gift coordinates")
T.eq(model().markers[1].y, 6, "older host updates both gift coordinates")

local native = os.getenv("KANTO_GEAR_NATIVE_GEN2")
if native then
  local imported = { gen2Scripts = dofile(native .. "/scripts.lua"),
    gen2Maps = dofile(native .. "/maps.lua"), gen2InitialEvents = dofile(native .. "/initial_events.lua"),
    items = dofile(native .. "/items.lua") }
  local counts, events = 0, {}
  for id in pairs(imported.gen2Maps) do
    for _, row in ipairs(Area.gen2Rows(imported, {}, world, { id })[2]) do
      if row.gift then counts = counts + 1; events[id .. ":" .. row.itemId] = row.event end
    end
  end
  T.eq(events["VIOLET_GYM:223"], 8, "native Falkner TM receipt is separate from the badge")
  T.eq(events["GOLDENROD_GYM:237"], 11, "native Whitney branches deduplicate one TM gift")
  T.eq(events["ROUTE_32_POKECENTER_1F:58"], 23, "native Old Rod uses its own received event")
  T.eq(events["ROUTE_30_BERRY_HOUSE:173"], 39, "native Berry gift remains received after consumption")
  T.eq(events["GOLDENROD_GAME_CORNER:216"], nil, "repeatable purchased prizes are not NPC gifts")
  local expected = require("src.core.GameVersion").get() == "crystal" and 80 or 74
  T.eq(counts, expected, "complete native edition catalogue has its deduplicated NPC gifts")
  print("GEN2_NATIVE_GIFTS", counts)
end
T.finish("Kanto Gear Gen2 NPC gifts")
