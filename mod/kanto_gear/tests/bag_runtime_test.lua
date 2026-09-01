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

T.finish("Kanto Gear HGSS Bag runtime")
