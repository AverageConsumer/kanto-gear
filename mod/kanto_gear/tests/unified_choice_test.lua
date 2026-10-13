-- Common choice pages keep touch browsing separate from native selection.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local gen = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local function hook(run, name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local function check(run, display, game)
  local theme = up(display.drawContents, "THEME")
  local touch = up(hook(run, "render.compose"), "touchEvent")
  local api = up(display.saveHome, "mod")
  local inputStep = hook(run, "input.step")
  run.loader.modOptions.kanto_gear = run.loader.modOptions.kanto_gear or {}
  local Page = display.ChoicePage
  local keys, now = {}, 100
  love.timer.getTime = function() return now end
  api.input.tap = function(_, target, key)
    T.eq(target, game, "touch queues input for the original game")
    keys[#keys + 1] = key
  end
  local Choice, Message, Stack
  if gen == 3 then
    Choice = require("src.ui.game3.choice")
    Message = require("src.ui.game3.message")
    Stack = require("src.ui.game3.stack")
    Stack.clear(); Message.reset()
  end
  local top, labels, field, result
  local function current()
    if gen == 3 then top = assert(display.startMenu()) end
    return display.choiceModel(top, labels, "Which place would you like to visit?", field)
  end
  local function settle()
    if gen == 3 then display.gen3.syncScreens() end
    display.syncTouchGuard(); now = now + 1
  end
  local function open(count)
    result, labels = nil, {}
    for i = 1, count do labels[i] = "PLACE " .. i end
    if gen == 3 then
      Choice.multi(labels, count - 1, function(index) result = index end, { cols = 2 })
      settle(); top = assert(display.startMenu())
    elseif gen == 2 then
      top = require("src.ui.gen2.ScriptMenu").new(game, {
        style = "2d", header = { grid = { rows = math.ceil(count / 2), cols = 2 },
          gridItems = labels, cursor = count }, onChoose = function(index) result = index end })
      top.screenId, field = "Gen2ScriptMenu", "script"
      game.stack.states = { game.world, top }
    else
      local items = {}
      for i, label in ipairs(labels) do items[i] = { label = label,
        onSelect = function() result = i end } end
      top = require("src.ui.Menu").new(game, items, { noSound = true })
      top.index, field = count, "index"
      game.stack.states = { game.world, top }
    end
    current(); settle()
  end
  local function nativeIndex()
    if gen == 3 then return Choice.cursor end
    return field == "script" and (top.row - 1) * top.cols + top.col or top.index
  end
  local function hit(x, y) touch(("tap,%d,%d"):format(x, y), 240, 216) end
  local function swipe(x, y, nx, ny)
    settle(); touch(("down,%d,%d"):format(x, y), 240, 216)
    touch(("up,%d,%d"):format(nx, ny), 240, 216)
  end
  local function finishNative()
    inputStep(function()
      if gen == 3 then
        if keys[#keys] == "a" then Choice.confirm() else Choice.cancel() end
      else
        game.input = { wasPressed = function(_, key) return key == keys[#keys] end }
        top:update(1 / 60)
      end
    end, game, 1 / 60)
  end
  for _, style in ipairs({ "hgss", "hgss_dark" }) do
    run.loader.modOptions.kanto_gear.theme_v3 = style
    run.loader.modOptions.kanto_gear.ui_motion = false
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
    for _, count in ipairs({ 1, 2, 3, 4, 5, 8, 12 }) do
      open(count)
      local m = current()
      T.eq(m.first, 1, "bottom starts at its own first choice, independent of the native default")
      T.eq(nativeIndex(), count, "opening bottom choices preserves the native default")
      local ok, err = pcall(display.drawContents)
      T.check(ok, "common choice page renders: " .. tostring(err))
      T.check(#m.prompt > 0, "plain native text produces a wrapped prompt")
      for row, entry in ipairs(m.entries) do
        T.eq(Page.hit(m, entry.x + entry.w / 2, entry.y + entry.h / 2), row, "common draw/hit geometry retains choice identity")
        T.eq(entry.x, 7, "choice has equal left and right outer gaps")
        T.eq(entry.w, 226, "choice uses the common full width")
        T.check(entry.y >= 86 and entry.y + entry.h <= (m.pages > 1 and 190 or 213), "choice never covers prompt or footer")
      end
      if count > 4 then
        local queued = #keys
        swipe(190, 100, 50, 100)
        T.eq(current().first, 4, "horizontal swipe pages only the choices")
        T.eq(nativeIndex(), count, "horizontal swipe preserves native selection")
        T.eq(#keys, queued, "paging never queues confirmation or D-pad input")
        swipe(100, 150, 100, 80)
        local last = current()
        T.eq(last.last, math.min(count, 9), "vertical swipe reaches the next common choice page")
        swipe(50, 100, 190, 100)
        -- Five choices have only two pages, so this returns to page one.
        if count == 5 then swipe(190, 100, 50, 100) end
        settle(); hit(200, 200); m = current()
        T.eq(m.last, math.min(count, 9), "footer navigation uses the same touch-owned pages")
        T.eq(nativeIndex(), count, "footer paging preserves original selection")
        T.eq(#keys, queued, "all browsing is input-free")
      end
      local entry = current().entries[#current().entries]
      local before = #keys
      settle(); hit(entry.x + 80, entry.y + 10)
      if gen ~= 3 and #keys == before then
        T.eq(nativeIndex(), count, "opening quiet guard does not change original selection")
        settle(); hit(entry.x + 80, entry.y + 10)
      end
      T.eq(keys[#keys], "a", "explicit choice queues native A")
      T.eq(#keys, before + 1, "one touch confirms exactly once")
      T.eq(nativeIndex(), entry.index, "native cursor changes only to the explicitly touched choice")
      finishNative()
      T.eq(result, gen == 3 and entry.index - 1 or entry.index, "real native callback receives the selected result")
      if gen == 3 then Choice.reset(); Message.reset(); Stack.clear() end
    end
    if gen == 3 then
      open(8); local m = current()
      local before = display.StartMenu.redrawKey(top)
      display.pageChoice(1); current()
      T.check(display.StartMenu.redrawKey(top) ~= before, "own page invalidates native menu canvas")
      T.eq(display.StartMenu.hit(top, m.entries[1].x + 50, m.entries[1].y + 10), 4, "cached native projection refreshes visible hit identities")
      settle(); hit(10, 12); finishNative()
      T.eq(result, 127, "header Back retains native cancellation result")
      open(2); Choice.ignoreBPress = true
      settle(); hit(10, 12); finishNative()
      T.check(Choice.active, "native unskippable choices still reject cancellation")
      Choice.reset(); Message.reset(); Stack.clear()
    end
  end
  -- Sparse final pages and repeated labels cannot leave the wrong cached page.
  local state = { page = 4 }
  local model = Page.model(state, { "A", "B" })
  T.eq(state.page, 1, "shrinking choice sets clamp their owned page")
  T.eq(Page.hit(model, 6, 116), nil, "outside edge never chooses")
end
if gen == 3 then
  _G.KANTO_GEAR_RENDER_CAPTURE = check
  dofile(path .. (os.getenv("POKEPORT_VERSION") == "emerald" and "/tests/emerald_runtime_test.lua" or "/tests/gen3_runtime_test.lua"))
else
  local run = T.sdk.loadMod(path, { generation = gen, data = T.fixtures.load() })
  assert(run.mod, run.error or run.reason)
  love.graphics.arc = love.graphics.arc or function() end
  love.graphics.polygon = love.graphics.polygon or function() end
  local display = up(hook(run, "input.step"), "displayRuntime")
  local world = { map = { id = "PALLET_TOWN", def = {} } }
  local game = { data = run.data, world = world, overworld = world,
    stack = { states = { world }, top = function(self) return self.states[#self.states] end,
      pop = function(self) return table.remove(self.states) end },
    input = { wasPressed = function() return false end },
    save = { generation = gen, player = { name = "RED" }, party = {}, inventory = {},
      pokedex = { seen = {}, caught = {} }, boxes = {}, options = {} } }
  run.loader.events:emit("game.ready", { game = game })
  check(run, display, game)
  T.finish()
end
