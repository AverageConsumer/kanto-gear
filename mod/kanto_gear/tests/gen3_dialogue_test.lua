-- Native field dialogue must receive the same A input from Gear as from a
-- controller, without forwarding taps through choices or script-only waits.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local function upvalue(fn, key)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, i)
    if name == key then return value end
  end
  error("missing upvalue " .. key)
end
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local function hook(name)
    for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
      if entry.owner == "kanto_gear" then return entry.callback end
    end
  end
  local touch = upvalue(hook("render.compose"), "touchEvent")
  local refreshBattle = upvalue(hook("render.compose"), "refreshBattle")
  local inputStep = hook("input.step")
  local api = upvalue(display.saveHome, "mod")
  local Message = require("src.ui.game3.message")
  local Hud = require("src.ui.game3.hud")
  local Stack = require("src.ui.game3.stack")
  local Choice = require("src.ui.game3.choice")
  local Field = require("src.core.game3.field")
  local queued, sent, held, released, now = false, 0, 0, 0, 100
  love.timer.getTime = function() return now end
  api.input.tap = function(_, target, key)
    T.eq(target, game, "dialogue uses original host game")
    T.eq(key, "a", "dialogue forwards A")
    queued, sent = true, sent + 1
  end
  api.input.press = function(_, target, key)
    T.eq(target, game, "text speed uses original host game")
    T.eq(key, "a", "text speed holds A")
    held = held + 1
    return "dialogue-speed"
  end
  api.input.release = function(_, token)
    T.eq(token, "dialogue-speed", "release only the owned text hold")
    released = released + 1
  end
  local oldInput, oldLock = game.input, Field.locked
  game.input = { wasPressed = function(_, key) return queued and key == "a" end,
    isDown = function() return false end }
  Stack.clear(); Message.reset(); Hud.clearWaitButton(); Choice.active = false
  Field.locked = true
  local function sync()
    display.gen3.syncScreens()
    refreshBattle()
    display.syncTouchGuard()
  end
  local function settle()
    sync(); now = now + 1
  end
  local function step()
    inputStep(function()
      Hud.update(game, 1 / 60)
      queued = false
      display.gen3.syncScreens()
    end, game, 1 / 60)
  end
  -- Scripted messages stay open until the VM runs closemessage. Intermediate
  -- pages still advance; only the final page delegates to waitbuttonpress.
  Hud.openMessageStay(game, "First page.\fLast page.", { speed = 0 })
  settle(); display.drawContents()
  T.check(display.backgroundDim > 0, "field dialogue dims the companion")
  touch("tap,80,90"); step()
  T.eq(Message._page, 2, "tap advances an intermediate stay page")
  Message.skipReveal(); settle()
  local count, resumed = sent, 0
  touch("tap,80,90"); step()
  T.eq(sent, count, "unarmed final stay page does not invent A input")
  Hud.armWaitButton(function() resumed = resumed + 1; Message.close() end)
  settle()
  touch("down,80,90"); touch("up,80,90")
  touch("tap,80,90")
  step()
  T.eq(resumed, 1, "tap resumes native waitbuttonpress exactly once")
  T.check(not Message.isOpen(), "native callback closes the dialogue")
  count = sent; settle(); touch("tap,80,90"); step()
  T.eq(sent, count, "script lock without text does not forward A")
  Message.show("Ordinary dialogue.", { speed = 0 }); settle()
  touch("tap,80,90"); step()
  T.check(not Message.isOpen(), "ordinary dialogue still dismisses")
  Message.show("Held dialogue.", { speed = 0, hold = true })
  Message.advance(); settle(); count = sent
  touch("tap,80,90"); step()
  T.eq(sent, count, "script-held text does not forward A")
  Message.showStay("Typing text.", { speed = 1 }); settle()
  touch("down,80,90")
  T.eq(held, 1, "typing text retains hold-to-speed-up")
  Message.reset(); sync(); touch("up,80,90")
  T.eq(released, 1, "closing text releases speed input")
  T.eq(sent, count, "old finger release cannot activate the screen underneath")
  Message.showStay("A choice follows.", { speed = 0 })
  Choice.yesNo(function() error("background tap must not choose") end)
  settle(); count = sent; touch("tap,155,140"); step()
  T.eq(sent, count, "background tap does not confirm a choice")
  Choice.active = false; Message.reset(); Hud.clearWaitButton(); Stack.clear()
  game.input, Field.locked = oldInput, oldLock
end
dofile(path .. (os.getenv("POKEPORT_VERSION") == "emerald"
  and "/tests/emerald_runtime_test.lua" or "/tests/gen3_runtime_test.lua"))
