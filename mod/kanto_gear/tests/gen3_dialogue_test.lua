-- Native field dialogue must receive the same A input from Gear as from a
-- controller, without forwarding taps through choices or script-only waits.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local upvalue = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
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
  if os.getenv("POKEPORT_VERSION") == "emerald" then
    -- Match Call owns a separate native printer, including paragraph, wait,
    -- scroll and hang-up prompts; it never opens the ordinary Message module.
    local Call = require("src.ui.game3.rse.pokenav.call_window")
    local Kit = require("src.ui.game3.rse.scene_kit")
    local TextIR = require("src.core.game3.scripting.text_ir")
    local playSe = Kit.playSe
    Kit.playSe = function() end -- The headless fixture has no sound bank.
    local finished = 0
    local call = Call.start({ onDone = function() finished = finished + 1 end })
    local function printer(bytes)
      return Kit.printer(TextIR.decode(bytes, { dialect = "rse" }), { speed = 0 })
    end
    local function callTap()
      settle(); touch("tap,80,90"); step(); step()
    end
    -- An ordinary message underneath must not steal call input, including
    -- during slide-in/out when neither printer accepts another advance.
    Message.show("Underlying dialogue.", { speed = 0 })
    call.state, call.printer = 4, printer(string.char(0xBB, 0xFF))
    settle(); count = sent; touch("tap,80,90")
    T.eq(sent, count, "call slide-in cannot forward A to underlying text")
    Message.reset()
    call.state, call.offset = 6, 0
    for _, prompt in ipairs({ { 0xFB, "clear" }, { 0xFA, "scroll_start" } }) do
      call.printer = printer(string.char(0xBB, prompt[1], 0xBC, 0xFF))
      T.eq(call.printer.state, prompt[2], "native call reaches its page prompt")
      count = sent; callTap()
      T.eq(sent, count + 1, "bottom tap advances native call page")
      T.check(call.printer.state ~= prompt[2], "native call consumes page advance")
    end
    call.printer = printer(string.char(0xBB, 0xFC, 0x09, 0xBC, 0xFF))
    T.eq(call.printer.state, "wait", "native call reaches wait prompt")
    count = sent; callTap()
    T.eq(sent, count + 1, "bottom tap advances native call wait")
    T.check(call.printer.state ~= "wait", "native call consumes wait advance")
    call.printer = Kit.printer(TextIR.decode(string.rep(string.char(0xBB), 40)
      .. string.char(0xFF), { dialect = "rse" }), { speed = 1 })
    settle(); count = held; touch("down,80,90")
    T.eq(held, count + 1, "call typing retains hold-to-speed-up")
    call.printer = printer(string.char(0xBB, 0xFF))
    sync(); touch("up,80,90")
    T.eq(released, held, "changing call page releases held A")
    T.check(not call.printer:isActive(), "native call text has finished")
    count = sent; callTap()
    T.eq(sent, count + 1, "bottom tap hangs up after the final call page")
    T.eq(call.state, 7, "native call enters slide-out")
    count = sent; callTap()
    T.eq(sent, count, "call slide-out cannot forward another A")
    for _ = 1, 12 do step() end
    T.eq(finished, 1, "native call closes and resumes its owner exactly once")
    T.check(not Call.isOpen(), "native call leaves no modal behind")
    Call.reset(); Stack.clear(); Kit.playSe = playSe
  end
  game.input, Field.locked = oldInput, oldLock
end
dofile(path .. "/tests/gen3_fixture.lua")
