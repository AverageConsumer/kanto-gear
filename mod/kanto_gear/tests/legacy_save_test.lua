local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local function up(fn, key)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, i)
    if name == key then return value end
  end
end
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local choice = assert(up(display.drawContents, "dialogueChoice"))
  local THEME = assert(up(display.drawContents, "THEME"))
  local function checkPrompt(native)
    local top, labels, field = choice()
    local model = display.choiceModel(top, labels, nil, field)
    T.same(model.prompt, THEME:messageLines({(native:promptText():gsub("[\v\f]", "\n"))}, 34, 3),
      "Gen2 save uses its actual complete native prompt")
  end
  local tap
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner == "kanto_gear" then tap = up(up(entry.callback, "touchEvent"), "tap") end
  end
  local api = up(display.saveHome, "mod")
  local originalTap, originalInput = api.input.tap, game.input
  local queued, key, writes, done = nil, nil, 0, nil
  api.input.tap = function(_, target, k) T.eq(target, game, "native save touch targets game"); queued = k end
  game.input = { wasPressed = function(_, k) return k == key end, isDown = function() return false end }
  local now = 100
  local originalTime = love.timer.getTime
  love.timer.getTime = function() return now end
  local function tick(k)
    key = k; game.stack:top():update(1 / 60); key = nil; now = now + 1 / 60
  end
  local function settle(predicate)
    for _ = 1, 1000 do if predicate() then return end; tick() end
    error("native save did not settle")
  end
  local function click(index)
    local top, labels, field = choice()
    assert(top, "native save choice is live")
    local row = display.choiceModel(top, labels, nil, field).entries[index]
    display.syncTouchGuard(); now = now + 1
    queued = nil; tap((row.x + row.w / 2) / 1.5, (row.y + row.h / 2) / 1.5)
    if not queued then now = now + 1; tap((row.x + row.w / 2) / 1.5, (row.y + row.h / 2) / 1.5) end
    T.eq(queued, "a", "common choice submits one native confirmation")
    if queued then tick(queued) end
  end
  for _, style in ipairs({ "hgss", "hgss_dark" }) do
    run.loader.modOptions.kanto_gear.theme_v3 = style
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = style })
    local world = game.world
    if tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) == 2 then
      local Save = require("src.ui.gen2.SaveMenu")
      local function open()
        done = nil
        local native = Save.new(game, { existed = true, writer = function() writes = writes + 1; return true end,
          onDone = function(saved) done = saved; game.stack:pop() end })
        native.screenId = "Gen2SaveMenu"; game.stack.states = { world, native }
        return native
      end
      local native = open()
      T.eq(choice(), nil, "Gen2 save choices wait for actual native typing")
      settle(function() return native:yesNoVisible() end)
      T.check(choice() ~= nil, "ready Gen2 save uses common choices")
      checkPrompt(native)
      T.check(pcall(display.drawContents), "Gen2 save common choices render")
      click(2); T.eq(done, false, "Gen2 No cancels native save")
      T.eq(writes, 0, "cancel never writes")
      native = open(); settle(function() return native:yesNoVisible() end); click(1)
      T.eq(native.phase, "overwrite", "Gen2 existing save retains overwrite warning")
      T.eq(choice(), nil, "new overwrite prompt cannot be confirmed before typing")
      settle(function() return not require("src.ui.gen2.Typer").typing(native) end)
      if not native:yesNoVisible() then tick("a") end
      settle(function() return native:yesNoVisible() end)
      checkPrompt(native)
      click(2); T.eq(done, false, "Gen2 overwrite No cancels")
      T.eq(writes, 0, "overwrite cancellation preserves save")
    else
      local menu = require("src.ui.StartMenu").new(game)
      game.stack.states = { world, menu }
      for _, item in ipairs(menu.items) do if item.label == require("src.core.Strings")("SAVE") then item.onSelect() end end
      T.eq(choice(), nil, "Gen1 save panel has no premature choices")
      settle(function() return choice() ~= nil end)
      T.check(pcall(display.drawContents), "Gen1 save uses common choices")
      click(2)
      T.eq(choice(), nil, "answered Gen1 choice is inactive during native closing delay")
      settle(function() return game.stack:top() == world end)
      T.eq(game.stack:top(), world, "Gen1 No closes native save and start menu")
    end
    game.stack.states = { world }
  end
  api.input.tap, game.input, love.timer.getTime = originalTap, originalInput, originalTime
end
dofile(path .. "/tests/legacy_bag_test.lua")
