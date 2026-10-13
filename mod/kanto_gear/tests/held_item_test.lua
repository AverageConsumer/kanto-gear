local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local Stack = require("src.ui.game3.stack")
  local Party = require("src.ui.game3.screens").get("party", game.session)
  local Bag = require("src.ui.game3.bag_menu")
  Party.close(); Bag.close(); Stack.clear()
  require("src.ui.game3.message").reset()
  require("src.ui.game3.choice").reset()
  display.gen3.syncScreens()
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner == "kanto_gear" then up(entry.callback, "refreshBattle")() end
  end
  T.check(display.canOpenHeldItem(), "idle overworld permits held-item management")
  T.eq(display.openHeldItem(99), false, "missing partners cannot open an item menu")
  local mon = game.session.party[1]
  local oldItem, oldHeld, oldEgg = mon.item, mon.heldItem, mon.isEgg
  mon.item, mon.heldItem = 0, 0
  display.gen3.syncScreens()
  T.eq(display.heldItem(display.gen3:mon(mon)), nil, "empty hands have no item marker")
  local Mail = require("src.core.game3.mail")
  local Items = require("src.core.game3.items_data")
  local displayName = Items.displayName
  Items.displayName = function() return "オレンジメール" end
  mon.item, mon.heldItem = 121, 121
  T.check(Mail.isMailItem(mon.item), "fixture is real mail")
  local held = display.heldItem(display.gen3:mon(mon))
  T.eq(held.mail, true, "mail marker uses the native item ID in translated games")
  T.eq(held.name, "オレンジメール", "mail retains its translated display name")
  Items.displayName = displayName
  mon.item, mon.heldItem = oldItem, oldHeld
  mon.isEgg = true; display.gen3:refresh(); display.gen3.syncScreens()
  T.eq(display.openHeldItem(1), false, "eggs cannot receive held items")
  mon.isEgg = oldEgg; display.gen3:refresh(); display.gen3.syncScreens()
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner == "kanto_gear" then up(entry.callback, "refreshBattle")() end
  end
  T.check(display.openHeldItem(1), "opens the edition's own party menu")
  for _ = 1, 40 do
    Party.update(1 / 20); display.stepPartyItem()
    if Party.mode == "item_action" then break end
  end
  T.eq(Party.mode, "item_action", "opening fades finish at the native Give/Take submenu")
  T.eq(Party.cursor, 1, "item menu keeps the intended partner")
  T.check(not display.canOpenHeldItem(), "an open native menu blocks another item action")
  display.gen3.syncScreens()
  local view = assert(display.startMenu())
  T.check(view.partyActions, "Give/Take has a touch projection")
  T.check(pcall(display.drawContents), "native item actions render on Gear")
  Party.close(); Stack.clear(); display.gen3.syncScreens()
  -- A native opening animation may also delay the second confirmation.
  T.check(display.openHeldItem(1), "reopen for delayed action confirmation")
  for _ = 1, 40 do Party.update(1 / 20) end
  Party.mode = "action"
  local input = Party.handleInput
  Party.handleInput = function() end
  display.stepPartyItem()
  T.check(display.pendingPartyItem ~= nil, "a temporarily blocked confirmation is retried")
  Party.handleInput = input
  display.stepPartyItem()
  T.eq(Party.mode, "item_action", "retry opens the native Item submenu")
  display.stepPartyItem()
  T.eq(display.pendingPartyItem, nil, "completed opening never sends another confirmation")
  Party.close(); Stack.clear(); display.gen3.syncScreens()
  T.check(display.openHeldItem(1), "reopen for stale-owner check")
  Stack.push("other", {})
  display.stepPartyItem()
  T.eq(display.pendingPartyItem, nil, "a different modal cancels automatic navigation")
  Party.close(); Stack.clear(); display.gen3.syncScreens()
end
dofile(path .. "/tests/gen3_fixture.lua")
