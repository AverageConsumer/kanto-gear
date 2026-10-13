-- Exercise real legacy storage update handlers through the shared touch page.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
love.graphics.arc = love.graphics.arc or function() end
local generation = assert(tonumber(arg[1]))
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local run = T.sdk.loadMod(path, { generation = generation, data = T.fixtures.load() })
assert(run.mod, run.error or run.reason or "mod load failed")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local input
for _, entry in ipairs(run.loader.hooks.chains["input.step"]) do
  if entry.owner == "kanto_gear" then input = entry.callback end
end
local display = up(input, "displayRuntime")
local world = { map = { id = "PALLET_TOWN", def = {} } }
local stack = { states = { world } }
function stack:top() return self.states[#self.states] end
function stack:push(state) self.states[#self.states + 1] = state end
function stack:pop() return table.remove(self.states) end
local pressed, queued, writes = {}, {}, 0
local save = { generation = generation, player = { name = "RED", id = 7 }, party = {},
  inventory = {}, boxes = {}, currentBox = 1, pokedex = { seen = {}, caught = {} },
  options = { textSpeed = "FAST" } }
local game = { data = run.data, save = save, world = world, overworld = world, stack = stack,
  writeSave = function() writes = writes + 1; return true end,
  input = { wasPressed = function(_, key) return pressed[key] end, isDown = function() return false end } }
run.loader.events:emit("game.ready", { game = game })
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", ui_motion = false }
run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
local theme = up(display.drawContents, "THEME")
up(display.saveHome, "mod").input.tap = function(_, target, key)
  T.eq(target, game, "touch targets the actual game")
  queued[#queued + 1] = key
end
local function mon(name)
  return { species = "FIXMON_A", nickname = name, level = 10, hp = 25, maxHp = 30,
    experience = 1000, exp = 1000, moves = { { id = "FIX_MOVE_A", pp = 4 } },
    dvs = { attack = 8, defense = 8, speed = 8, special = 8 }, statExp = {},
    stats = { hp = 30, attack = 15, defense = 14, speed = 12, special = 13, specialAttack = 13, specialDefense = 13 } }
end
local function step(key)
  pressed = { [key or "none"] = true }
  stack:top():update(1 / 60)
  pressed = {}
end
local function view()
  local page = assert(display.startMenu(), "native storage has a common page")
  T.eq(page.screenId, "CompanionMenu", "legacy storage uses the shared page")
  local ok, err = pcall(display.drawContents)
  T.check(ok, "shared storage renders: " .. tostring(err))
  T.eq(display.nativeHandoff, false, "storage stays usable below")
  return page
end
local function choose(index)
  local page = view()
  T.check(display.StartMenu.select(page, index), "shared page accepts the native target")
  local model = display.startMenuModel(page)
  local entry = assert(model.entries[index - model.first + 1])
  local before = #queued
  display.tapStartMenu(page, (entry.x + entry.w / 2) / 1.5, (entry.y + entry.h / 2) / 1.5)
  T.eq(#queued, before + 1, "one touch queues exactly one native key")
  step(queued[#queued])
  return page
end
local function slot(index)
  local page = view()
  return page.boxParty and index or index + 3
end
local function reset()
  stack.states = { world }
  save.party, save.boxes, save.currentBox = { mon("TEAM A"), mon("TEAM B"), mon("TEAM C") }, {}, 1
  save.boxes[1] = { mon("BOX A"), mon("BOX B"), mon("BOX C") }
end
local function open()
  require("src.ui.Screens").push(game, generation == 1 and "BoxMenu" or "Gen2PcMenu",
    generation == 2 and { bills = true, saveExists = function() return false end,
      onClose = function() stack:pop() end } or nil)
  return stack:top()
end
local function rootMode(mode)
  reset(); open(); choose(mode)
  return stack:top()
end
local function acknowledge()
  for _ = 1, 180 do
    local top = stack:top()
    if not top.message and not top.cryWait and not top.messageFrames and not top.isTextBox then return end
    step("a")
  end
  error("native receipt did not finish")
end
if generation == 1 then
  local imported = mon("IMPORTED")
  imported.stats, imported.maxHp, imported.hp = nil, nil, 7
  local expected = require("src.pokemon.Stats").calc(game.data.pokemon[imported.species],
    imported.level, imported.dvs, imported.statExp).hp
  local card = display.partyView(imported)
  T.eq(card.maxHp, expected, "imported box hero derives the native maximum HP")
  T.eq(card.hp, 7, "imported box hero preserves current HP")
  T.eq(imported.stats, nil, "preview never writes a stat block into the save")
  T.eq(imported.hp, 7, "preview never heals the stored partner")
end
for _, dark in ipairs({ false, true }) do
  theme.hgss:setVariant(dark)
  rootMode(1)
  local grid = view()
  T.check(grid.nativeGrid, "withdraw uses the shared box grid")
  T.eq(#grid.items, 23, "twenty native slots plus common chrome")
  T.eq(grid.items[3].label, (generation == 1 and "BOX 1" or "BOX1") .. "  3/20", "box caption exposes actual occupancy")
  for i = 1, 20 do
    local r = grid.items[i + 3].rect
    T.check(r[1] >= 7 and r[1] + r[3] <= 233 and r[2] >= 85 and r[2] + r[4] <= 203,
      "every box slot stays inside the common region")
    T.eq(display.StartMenu.hit(grid, r[1] + r[3] / 2, r[2] + r[4] / 2),
      i <= 3 and i + 3 or nil, "only real stored partners are touch targets")
  end
  T.eq(display.StartMenu.hit(grid, 60, 44), nil, "action caption is static")
  T.eq(display.StartMenu.hit(grid, 120, 70), nil, "legacy box label is static")
  T.eq(display.StartMenu.select(grid, 7), false, "empty slot cannot move the native cursor")
  local native = stack:top()
  step("down")
  T.eq(view().index, 5, "native D-pad and lower grid agree on slot two")
  local partner = save.boxes[1][2]
  choose(slot(2))
  T.check(not grid.valid(), "box touch expires when its action page opens")
  local actions = view()
  T.eq(actions.partyActions, partner, "action hero is the exact selected partner")
  T.eq(#actions.items, generation == 1 and 3 or 4, "all native partner actions are retained")
  choose(2)
  T.check(stack:top() ~= native, "Stats enters the native summary")
  for _ = 1, 240 do
    if stack:top() == actions.owner then break end
    step("b")
  end
  T.eq(view().partyActions, partner, "Stats back returns to the same partner actions")
  choose(1)
  T.eq(save.party[4], partner, "native withdraw moves the selected partner into the team")
  T.eq(#save.boxes[1], 2, "native withdraw removes precisely one box entry")
  T.check(not actions.valid(), "successful transfer expires the old action page")
  acknowledge()
  rootMode(2)
  local party = view()
  T.check(party.boxParty, "deposit uses the common six-card team page")
  for i = 1, 6 do
    local r = party.items[i].rect
    T.same(r, { theme.hgss:partySelectionRect(i, 6, true) }, "deposit uses shared team geometry")
    T.eq(display.StartMenu.hit(party, r[1] + r[3] / 2, r[2] + r[4] / 2),
      i <= 3 and i or nil, "empty team cards remain inert")
  end
  partner = save.party[2]
  choose(2); choose(1)
  T.eq(save.boxes[1][4], partner, "native deposit preserves partner identity")
  T.eq(#save.party, 2, "native deposit removes one team member")
  acknowledge()
  rootMode(1)
  local closing = view()
  choose(2)
  T.check(not closing.valid(), "Cancel expires the box page")
  T.check(not view().nativeGrid, "Cancel returns to the PC root")
end

-- Full party/box refusals remain native; Gear never mutates around them.
reset(); save.party = {}; for i = 1, 6 do save.party[i] = mon("FULL " .. i) end
open(); choose(1)
if generation == 2 then choose(slot(1)); choose(1) end
T.eq(#save.party, 6, "full party cannot accept another partner")
T.eq(#save.boxes[1], 3, "full-party refusal preserves storage")
reset(); save.boxes[1] = {}; for i = 1, 20 do save.boxes[1][i] = mon("FULL " .. i) end
open(); choose(2)
if generation == 2 then choose(1); choose(1) end
T.eq(#save.boxes[1], 20, "full box does not overflow")
T.eq(#save.party, 3, "full-box refusal preserves the party")

if generation == 2 then
  rootMode(4)
  local native = stack:top()
  choose(slot(2)); choose(1)
  local inserting = view()
  T.check(native.phase == "insert", "Move enters native destination selection")
  T.eq(native.moveFrom.slot, 2, "held source retains its original slot")
  step("right")
  T.check(not inserting.valid(), "changing destination expires the previous grid")
  local destination = view()
  T.eq(native.boxIndex, 2, "native Right selects the next box")
  T.eq(destination.items[3].label, "BOX2  0/20", "destination shows its own name and count")
  T.check(not destination.items[4].inert, "empty destination exposes its native first insert slot")
  T.check(destination.items[5].inert, "unavailable insert positions stay inert")
  local partner = save.boxes[1][2]
  choose(4)
  T.eq(save.boxes[2][1], partner, "native insert moves the held partner into the selected box")
  T.eq(#save.boxes[1], 2, "source loses exactly one partner")
  acknowledge()
  rootMode(4); native = stack:top()
  choose(slot(2)); choose(1); step("right"); step("b")
  T.eq(native.boxIndex, 1, "cancel restores the native source box")
  T.eq(native.index, 2, "cancel restores the native source cursor")
  T.eq(#save.boxes[1], 3, "cancel never removes the source partner")
  step("left")
  T.check(view().boxParty, "move into box zero uses the shared team page")
  choose(1); choose(1)
  T.check(view().emptyTargets[3], "party insertion keeps its real native targets")
  T.eq(view().emptyTargets[4], false, "party insertion does not invent a fourth native target")
  step("b")
  -- Release is still an explicit, default-No native confirmation.
  rootMode(1); choose(slot(1)); choose(3)
  T.eq(stack:top().index, 2, "release confirmation defaults to No")
  step("a"); for _ = 1, 20 do step() end
  T.eq(#save.boxes[1], 3, "default No preserves every boxed partner")
  -- Changing boxes must still pass through the native save flow.
  reset(); open(); choose(3)
  local picker = view()
  T.eq(#picker.items, 14, "all fourteen native boxes are selectable")
  T.eq(picker.items[1].right, "3/20", "box picker shows actual occupancy")
  choose(2)
  T.check(not picker.valid(), "save confirmation expires box-picker touches")
  T.eq(save.currentBox, 1, "selecting a box alone does not bypass saving")
  local pc = stack:top()
  for _ = 1, 600 do
    step("a")
    if not pc.savePhase then break end
  end
  T.eq(save.currentBox, 2, "native confirmation changes the saved current box")
  T.eq(writes, 1, "native save writer runs exactly once")
else
  rootMode(3); choose(slot(1))
  T.check(stack:top().isTextBox, "Gen 1 release opens its native warning")
  T.eq(#save.boxes[1], 3, "release warning alone cannot remove a partner")
  reset(); open(); choose(4)
  T.eq(display.startMenu(), nil, "Gen 1 save warning cannot be mistaken for a box list")
  for _ = 1, 300 do
    if stack:top().kind == "pc_box_change" and stack:top().items then break end
    step("a")
  end
  local picker = view()
  T.eq(#picker.items, 12, "all twelve native Gen 1 boxes are selectable")
  T.eq(picker.items[1].right, "3/20", "Gen 1 box picker shows native occupancy")
  choose(12)
  T.eq(save.currentBox, 12, "native Gen 1 box selection retains exact identity across pages")
  T.eq(writes, 1, "native Gen 1 box change saves exactly once")
  T.check(not picker.valid(), "closed native Gen 1 picker rejects stale touches")
end
if _G.KANTO_GEAR_RENDER_CAPTURE then _G.KANTO_GEAR_RENDER_CAPTURE(run, display, game) end
T.finish("Kanto Gear shared legacy Pokemon storage")
