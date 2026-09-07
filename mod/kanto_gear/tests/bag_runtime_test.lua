package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local run = T.sdk.loadMod(path, {
  generation = generation,
  data = T.fixtures.load(),
})

T.eq(run.mod and run.mod.state, "loaded", "Kanto Gear loads")
T.eq(#run.errors, 0, "Kanto Gear boots without errors")

local worldUses = 0
local world = {
  map = { id = "PALLET_TOWN", def = {} },
  useFieldItem = function()
    worldUses = worldUses + 1
    return "nowhere"
  end,
}
local stack = { states = {} }
function stack:top() return self.states[#self.states] end
function stack:push(state) self.states[#self.states + 1] = state end
function stack:pop() return table.remove(self.states) end
function stack:clear() self.states = {} end

local itemId = generation == 1 and "FIX_BALL" or "FIX_POTION"
local save = {
  generation = generation,
  player = { name = "RED", id = 7, map = "PALLET_TOWN" },
  party = {}, inventory = { [itemId] = 2 }, boxes = {}, currentBox = 1,
  pokedex = { seen = {}, caught = {} }, money = 3000,
}
local game = {
  data = run.data, save = save, world = world, overworld = world, stack = stack,
}
if generation == 1 then stack:push(world) end
run.loader.events:emit("game.ready", { game = game })
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss" }
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "theme_v3" })

local function upvalue(fn, target)
  for index = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, index)
    if name == target then return value end
  end
end
local inputHook
for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
  if entry.owner == "kanto_gear" then inputHook = entry.callback end
end
local display = upvalue(inputHook, "displayRuntime")
T.check(type(display) == "table", "Bag runtime is reachable")
local rawPartyView = display.partyView({ species = "FIXMON_A", hp = 5,
  stats = { hp = 12 } })
T.eq(rawPartyView.maxHp, 12,
  "native party records expose their calculated maximum HP")
T.eq(rawPartyView.hpText, "5/12",
  "contextual party screens never render current HP over zero")
T.eq(display.storeEntry(display.storeById.bag).state, "get",
  "the optional Bag app is available from Silph Store")
T.check(display.setPackageInstalled("bag", false),
  "Bag can be removed from the customizable Home")
T.check(display.setPackageInstalled("bag", true), "Bag installs from the Store")
T.eq(display.storeEntry(display.storeById.bag).state, "open",
  "the installed Bag app is ready to open")
T.check(display.openHomeApp("bag"), "Bag opens from Home")
local model = display.bagModel()
T.eq(model.total, 1, "Bag reads the live inventory")
T.eq(model.entries[1].id, itemId, "Bag preserves the real item id")
T.check(model.canUse, "Bag enables USE only on the idle overworld")
local summary = display.bagSummary()
T.eq(summary.item + summary.medicine + summary.ball + summary.machine, 2,
  "Bag widget counts only the real ordered Bag contents")

local before = #stack.states
T.check(display.useBagItem(itemId),
  "Bag delegates USE to the original generation path")
if generation == 1 then
  T.check(#stack.states == before + 1 and stack:top().isTextBox,
    "Gen 1 skips the native Bag submenu and opens only the official result")
else
  T.eq(worldUses, 1, "Gen 2 runs the original field-item dispatch exactly once")
  T.eq(#stack.states, before, "Gen 2 does not push a mirrored Pack screen")
end
T.eq(save.inventory[itemId], 2,
  "a refused field use does not consume the item")

if generation == 1 then
  stack:clear()
  stack:push(world)
  run.data.items.FIX_POTION.needsTarget = true
  save.inventory.FIX_POTION = 1
  save.party = { { species = "FIXMON_A", nickname = "TESTMON",
    hp = 5, moves = { { id = "FIX_MOVE_A", pp = 4 } } } }
  T.check(display.useBagItem("FIX_POTION"),
    "Gen 1 field medicine opens through the original Bag path")
  local picker, party, title = display.fieldBagParty()
  T.check(picker and picker.screenId == "PartyMenu",
    "Gen 1 field medicine gives the bottom screen its native party picker")
  T.eq(party[1], save.party[1], "Gen 1 field picker keeps live party data")
  T.eq(title, "USE ITEM ON", "Gen 1 field picker explains its action below")

  display.bag.pending = { itemId = "ETHER", mon = save.party[1] }
  local ppPicker = { kind = "Which move?", title = "Which move?", index = 1,
    items = { { label = "FIX CUT", right = "4" } } }
  stack:push(ppPicker)
  local pp = display.fieldPpMoveScreen()
  T.check(pp and pp.native == ppPicker and pp.cursor == "index",
    "Gen 1 PP items give the bottom screen their native move picker")
  T.check(pp.items[1].right:find("/", 1, true),
    "Gen 1 PP item rows include current and maximum PP")
end

-- ROM item definitions do not carry the BattleAPI's synthetic `ball` flag.
local cases = {
  { "POKE_BALL", 20, "BALL" }, { "GREAT_BALL", 11, "BALL" }, { "ULTRA_BALL", 5, "BALL" },
  { "POTION", 3, "ITEM" }, { "FULL_RESTORE", 2, "ITEM" }, { "FRESH_WATER", 4, "ITEM" },
  { "ETHER", 2, "ITEM" }, { "FULL_HEAL", 1, "ITEM" },
  { "ESCAPE_ROPE", 5, "ITEM" }, { "RARE_CANDY", 2, "ITEM" }, { "PROTEIN", 1, "ITEM" },
  { "PP_UP", 1, "ITEM" }, { "BICYCLE", 1, "KEY_ITEM" },
  { "TM01", 3, "TM_HM" }, { "HM03", 1, "TM_HM" },
}
save.inventory, save.bagOrder = { FIX_BADGE_1 = 1, EMPTY = 0 }, { "FIX_BADGE_1", "POKE_BALL", "POKE_BALL", "STALE" }
save.pcItems = { POKE_BALL = 99 }
for _, row in ipairs(cases) do
  save.inventory[row[1]] = row[2]
  run.data.items[row[1]] = { name = "Translated item", pocket = generation == 2 and row[3] or nil }
end
T.same(display.bagSummary(), { item = 10, medicine = 12, ball = 36, machine = 4 },
  "widget counts quantities by actual item type, excluding badges, stale rows and PC storage")
T.eq(#save.bagOrder, 4, "reading widget totals never edits the save's acquisition order")
for _, id in ipairs({ "RARE_CANDY", "PROTEIN", "PP_UP" }) do
  run.data.items[id].needsTarget = true
  T.eq(display.bagItemKind(id, run.data.items[id]), "item", "target selection does not make " .. id .. " a healing item")
end
if generation == 2 then
  local balls = { "MASTER_BALL", "LURE_BALL", "FAST_BALL", "LEVEL_BALL", "HEAVY_BALL", "LOVE_BALL", "FRIEND_BALL", "MOON_BALL", "PARK_BALL" }
  for _, id in ipairs(balls) do
    run.data.items[id] = { name = "Translated ball", pocket = "BALL" }
    save.inventory[id] = 2
    T.eq(display.bagItemKind(id, run.data.items[id]), "ball", id .. " uses its native pocket")
  end
  T.eq(display.bagSummary().ball, 54, "all Gen 2 ball stacks count toward the same total")
  local effects = require("src.core.gen2.ItemEffects")
  for _, family in ipairs({ "HEAL_HP", "HEAL_STATUS", "REVIVE", "RESTORE_PP" }) do
    for id in pairs(effects[family]) do
      local kind = display.bagItemKind(id, { pocket = "ITEM" })
      T.check(kind == "medicine" or kind == "status", id .. " follows its healing effect")
    end
  end
  run.data.gen2ItemEffects = { CUSTOM_CURE = { action = "heal" } }
  T.eq(display.bagItemKind("CUSTOM_CURE", { pocket = "ITEM" }), "medicine", "registered custom healing effects count too")
end
local previous = display.bagSummary().ball
save.inventory.POKE_BALL = save.inventory.POKE_BALL - 1
T.eq(display.bagSummary().ball, previous - 1, "using one ball updates the next widget snapshot")
save.inventory.GREAT_BALL = nil
T.eq(display.bagSummary().ball, previous - 12, "depositing or removing a stack removes its full quantity")
T.eq(display.bagItemKind("CUSTOM_ORB", { ball = true }), "ball", "explicit mod ball metadata remains supported")
T.eq(display.bagItemKind("LIGHT_BALL", { pocket = "ITEM" }), "item", "a held Light Ball is not a capture ball")
T.finish("Kanto Gear HGSS Bag runtime")
