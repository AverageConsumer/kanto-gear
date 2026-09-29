-- Drive the real compose/dirty path. Disabling the clock refresh makes missing
-- menu invalidations visible instead of hiding them behind its five-second tick.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local function up(fn, target, replacement)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, i)
    if name == target then
      if replacement ~= nil then debug.setupvalue(fn, i, replacement) end
      return value
    end
  end
  error("missing upvalue " .. target)
end
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local compose
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner == "kanto_gear" then compose = entry.callback end
  end
  local Stack = require("src.ui.game3.stack")
  local Bag = require("src.ui.game3.bag_menu")
  local Screens = require("src.ui.game3.screens")
  local Items = require("src.core.game3.bag")
  local now, draws = 100, 0
  love.timer.getTime = function() return now end
  run.loader.modOptions.kanto_gear.display_mode = "separate"
  run.loader.modOptions.kanto_gear.display_target = "secondary"
  run.loader.modOptions.kanto_gear.ui_motion = false
  run.loader.events:emit("mod.options_changed", { mod="kanto_gear", key="ui_motion" })
  up(compose, "nextClock", math.huge)
  local draw = display.drawContents
  display.drawContents = function(...) draws = draws + 1; return draw(...) end
  local canvas = up(up(compose, "pumpDisplay"), "canvas")
  canvas.requestImageData, canvas.pollImageData = nil, nil
  canvas.newImageData = function() return {} end
  local context = { secondScreen = { detected=function() return true end,
    pollTouch=function() end, push=function() return true end } }
  local function tick()
    now = now + 0.06
    compose(function() end, {}, context)
  end
  local function changed(label, action)
    local count = draws
    action(); tick()
    T.check(draws > count, label .. " redraws within one 50ms poll")
    count = draws
    tick(); tick()
    T.eq(draws, count, label .. " stays cached when unchanged")
  end
  local function input(key)
    return { wasPressed=function(_, k) return k==key end, isDown=function() return false end }
  end
  Stack.clear(); require("src.ui.game3.message").reset()
  Items.add(game.session.bag, 13, 10)
  Bag.show(game.session.bag, { session=game.session, pocket="ITEMS" }); Bag.settle()
  tick(); tick(); tick()
  changed("pocket switch at the same cursor", function()
    Screens.handleInput("bag", Bag, input("right"), game.session); Bag.settle()
  end)
  Bag.close(); Stack.clear()
  Bag.show(game.session.bag, { session=game.session, pocket="ITEMS" }); Bag.settle(); tick()
  changed("item actions", function()
    Screens.handleInput("bag", Bag, input("a"), game.session)
  end)
  local menu = assert(display.startMenu())
  for i, row in ipairs(menu.items) do if row.label=="TOSS" then display.StartMenu.select(menu,i) end end
  Screens.handleInput("bag", Bag, input("a"), game.session); tick()
  changed("toss quantity", function()
    Screens.handleInput("bag", Bag, input("up"), game.session)
  end)
  Bag.showMessage("First notice."); tick()
  changed("replacement notice", function() Bag.showMessage("Second notice.") end)
  Bag.close(); Stack.clear(); tick()
  local Naming = require("src.ui.game3.naming")
  Naming.open({ title="NAME", session=game.session }); tick()
  changed("name typed with native A", function() Naming.handleInput(input("a")) end)
  Naming.dismiss(); Stack.clear()
  display.drawContents = draw
end
dofile(path .. (os.getenv("POKEPORT_VERSION") == "emerald"
  and "/tests/emerald_runtime_test.lua" or "/tests/gen3_runtime_test.lua"))
