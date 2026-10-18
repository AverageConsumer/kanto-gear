-- Exercise real legacy party update handlers through the shared touch page.
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
    pokerus = generation == 2 and 0x34 or nil,
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
  local page = assert(display.startMenu(), "native party has a common page")
  T.eq(page.screenId, "CompanionMenu", "legacy party uses the shared page")
  local ok, err = pcall(display.drawContents)
  T.check(ok, "shared party renders: " .. tostring(err))
  T.eq(display.nativeHandoff, false, "party stays usable below")
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
local function open(opts)
  stack.states = { world }
  save.party = { mon("TEAM A"), mon("TEAM B"), mon("TEAM C") }
  game.partyMenuCursor, game.partyMenuSavedIndex = 3, 3
  opts = opts or {}
  if generation == 2 then
    if opts.submenu == nil then opts.submenu = true end
    opts.onCancel = function() stack:pop() end
  end
  return require("src.ui.Screens").push(game, generation == 1 and "PartyMenu" or "Gen2PartyMenu", opts)
end
local function action(label)
  for i, row in ipairs(view().items) do if row.label == label then return i end end
  error("missing native party action " .. label)
end
for _, style in ipairs({"hgss", "hgss_dark"}) do
  run.loader.modOptions.kanto_gear.theme_v3 = style
  run.loader.events:emit("mod.options_changed", {mod="kanto_gear",key="theme_v3"})
  local native = open()
  local team = view()
  T.eq(native.index, 3, "opening companion preserves native remembered selection")
  T.eq(#team.items, 7, "shared party reserves six cards and the header cancel target")
  T.eq(display.StartMenu.select(team, 4), false, "empty team cards cannot animate or act")
  T.eq(display.StartMenu.hit(team, 190, 170), nil, "empty team card has no touch target")
  choose(2)
  local actions = view()
  T.check(not team.valid(), "opening native submenu expires old team touches")
  T.eq(native.index, 2, "touch selects the exact native Pokemon")
  choose(action("STATS"))
  T.check(not actions.valid(), "opening actual stats expires old action touches")
  T.check(stack:top() ~= native, "stats opens the real native screen")
  T.check(pcall(display.drawContents), "native stats still renders through shared summary")
  stack:pop()
  if native.submenu then step("b") end
  choose(1)
  choose(action("SWITCH"))
  T.eq(view().title, "SWAP WITH?", "native party reorder reuses the common team page")
  local first, second = save.party[1], save.party[2]
  choose(2)
  for _=1,40 do step() end
  T.eq(save.party[1], second, "native reorder moves the chosen Pokemon")
  T.eq(save.party[2], first, "native reorder preserves its counterpart")
  choose(7)
  T.eq(stack:top(), world, "header back delegates to native cancellation without a fake seventh Pokemon")

  local picked
  display.bag.pending={itemId="ETHER"}
  native = open(generation == 1 and {pickOnly=true, onSwitch=function(m) picked=m end}
    or {submenu=false, onChoose=function(_,m) picked=m;stack:pop() end})
  team = view(); choose(2)
  T.eq(picked, save.party[2], "target picker answers its original callback once")
  T.eq(display.bag.pending.mon,save.party[2],"target touch updates PP/TM context before native input runs")
  display.bag.pending=nil
  T.eq(stack:top(), world, "target selection obeys native picker closure")
  T.check(not team.valid(), "old picker cannot answer another target")

  native = open()
  save.party[1].moves = {{id="CUT",pp=4},{id="FLY",pp=4},{id="SURF",pp=4},{id="STRENGTH",pp=4}}
  choose(1)
  actions = view()
  T.check(#actions.items > 5, "field moves retain every native action rather than truncating")
  T.check(display.StartMenu.select(actions, #actions.items), "last paged action remains selectable")
  local m = display.startMenuModel(actions)
  T.check(m.first > 1, "long action menu uses shared paging")
  T.eq(m.last, #actions.items, "final action page includes native cancel")

  native = open()
  if generation == 1 then
    native:setMessage("Use item on which POKEMON?")
    T.check(not view().notice, "Gen1 footer text never blocks a live target picker")
    native:animateTo(save.party[1], 4)
  else
    native:showItemResult(1,{fromHp=4,toHp=save.party[1].hp})
  end
  local waiting = display.startMenu()
  T.check(waiting.notice, "native HP animation owns input while running")
  T.eq(display.StartMenu.cursor(waiting), nil, "healing cannot accept premature target touches")
  T.check(pcall(display.drawContents), "blocked party preserves its visible cards")
  local shown = display.startMenuPartyViews(waiting)
  T.eq(shown[1].hp, 4, "lower HP bar follows native displayed HP instead of jumping to final HP")
  local before=display.StartMenu.redrawKey(waiting)
  for _=1,30 do
    step()
    if display.startMenuPartyViews(display.startMenu())[1].hp~=4 then break end
  end
  local after=display.StartMenu.redrawKey(display.startMenu())
  T.check(after~=before,"native HP progress invalidates the cached lower-screen canvas")
  T.eq(display.StartMenu.redrawKey(display.startMenu()),after,"unchanged displayed HP preserves the canvas")
end
if generation == 2 then
  local native = open()
  save.inventory = {POTION=2}
  run.data.items.POTION = {name="POTION",pocket="ITEM",canToss=true}
  choose(1); choose(action("ITEM"))
  local held = stack:top()
  T.eq(held.screenId,"Gen2HeldItemMenu","ITEM opens the original held-item handler")
  local actions = view()
  T.eq(actions.partyActions,save.party[1],"held-item actions keep the selected partner hero")
  choose(action("GIVE"))
  local pack = stack:top()
  T.check(pack.give,"GIVE opens native item-selection mode")
  local list = view()
  for _=1,4 do if pack:pocket().id=="ITEM" then break end; step("left") end
  list=view()
  T.eq(list.items[1].itemId,"POTION","giving lists the actual native item identity")
  choose(1)
  T.check(not list.valid(),"item selection expires its old list")
  T.eq(save.party[1].item,"POTION","native give attaches the exact selected item")
  T.eq(save.inventory.POTION,1,"native give removes exactly one item")
  for _=1,180 do if stack:top() ~= held then break end;step("a") end
  T.eq(stack:top(),native,"acknowledged give returns to the original party")
  choose(1);choose(action("ITEM"));choose(action("TAKE"))
  T.eq(save.party[1].item,nil,"native TAKE clears the held item")
  T.eq(save.inventory.POTION,2,"native TAKE returns the item to the bag")
  for _=1,180 do if stack:top() == native then break end;step("a") end
  choose(1);choose(action("ITEM"));choose(action("GIVE"))
  list=view();choose(#list.items)
  T.eq(stack:top(),native,"cancelling native give closes its entire held-item flow")
  T.eq(save.inventory.POTION,2,"cancelled give preserves inventory")

  stack.states={world}
  T.check(display.performBagAction("POTION","give"),"Bag app opens the actual native give picker")
  local targets=view()
  T.eq(targets.title,"GIVE ITEM TO","Bag give picker describes its purpose")
  choose(2)
  T.eq(save.party[2].item,"POTION","Bag touch gives to the chosen Pokemon, not the remembered slot")
  T.eq(save.inventory.POTION,1,"Bag give consumes exactly one item through native handling")
  T.check(not targets.valid(),"answered Bag give picker rejects stale touches")
end
if _G.KANTO_GEAR_RENDER_CAPTURE then _G.KANTO_GEAR_RENDER_CAPTURE(run,display,game) end
T.finish("Kanto Gear shared legacy party flows")
