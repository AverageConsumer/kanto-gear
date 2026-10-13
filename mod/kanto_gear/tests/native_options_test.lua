local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local Stack = generation == 3 and require("src.ui.game3.stack") or game.stack
  local Native = generation == 3 and require("src.ui.game3.screens").get("option", game.session)
    or require(generation == 2 and "src.ui.gen2.OptionsMenu" or "src.ui.OptionsMenu")
  local api, theme = up(display.saveHome, "mod"), up(display.drawContents, "THEME")
  local oldTap, oldInput, oldWrite, oldOptions = api.input.tap, game.input, game.writeOptions, game.options
  local queued, writes, done, owner = nil, 0, 0, nil
  game.options = game.options or {}
  game.writeOptions = function() writes = writes + 1 end
  api.input.tap = function(_, target, key) T.eq(target, game, "options input targets the real game"); queued = key end
  local function tick(key)
    game.input = { wasPressed = function(_, k) return k == key end, isDown = function() return false end }
    if generation == 3 then Native.handleInput(game.input) else game.stack:top():update(1 / 60) end
  end
  local function view()
    if generation == 3 then display.gen3.syncScreens() end
    return assert(display.startMenu(), "native options have a common page")
  end
  local function click(x, y)
    queued = nil
    display.tapStartMenu(view(), x / 1.5, y / 1.5)
    if queued then tick(queued) end
    return queued
  end
  local function rows()
    if generation ~= 3 then return owner.view or owner.rows end
    local pages = Native._pages or Native._st.pages
    return pages[#pages].rows
  end
  local function select(id)
    for index, row in ipairs(rows()) do
      if row.id == id then
        T.check(display.StartMenu.select(view(), index), "touch selects the actual option row")
        return index
      end
    end
    error("missing native option " .. id)
  end
  local function clickRow(id, side)
    local index = select(id)
    local model = view().optionsModel
    local slot = index - model.first + 1
    return click(side == "left" and 24 or side == "right" and 216 or 120, 36 + (slot - 1) * 39 + 25)
  end
  local function open()
    if generation == 3 then
      Native.close(); Stack.clear(); require("src.ui.game3.message").reset(); require("src.ui.game3.choice").reset()
      Native.show({ session = game.session, game = game, onClose = function() done = done + 1 end })
      owner = Native
    else
      game.stack.states = { game.world }
      owner = Native.new(game, { options = game.save.options, onCancel = function() done = done + 1 end,
        onDone = function() done = done + 1 end })
      game.stack:push(owner)
    end
    return view()
  end
  for _, style in ipairs({ "hgss", "hgss_dark" }) do
    run.loader.modOptions.kanto_gear.theme_v3 = style
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = style })
    local initial = open()
    local beforeDone = done
    T.check(initial.optionsModel and initial.fixedLayout, "all generations share the same option component")
    T.check(pcall(display.drawContents), "options render without native handoff")
    T.eq(display.NativeOptions.hit(initial.optionsModel, 88, 202), nil, "first page has no previous target")
    if initial.optionsModel.pages > 1 then
      T.eq(click(152, 202), nil, "paging sends no native activation")
      T.eq(view().optionsModel.page, 2, "next arrow advances exactly four settings")
      T.check(not initial.valid(), "previous page rejects delayed taps")
      T.check(display.pageChoice(-1), "swipe belongs to the native options page")
      T.eq(view().optionsModel.page, 1, "reverse swipe restores page one")
    end
    local root = view()
    T.eq(clickRow("group.audio"), "a", "opening a group uses native A")
    if generation ~= 3 then owner = game.stack:top() end
    T.check(not root.valid(), "opening native subgroup invalidates parent controls")
    local optionTable = generation == 2 and owner.options or generation == 1 and game.save.options
      or (Native._ctx or Native._st.ctx).options
    optionTable.musicVol = 5
    local beforeKey = display.StartMenu.redrawKey(view())
    T.eq(clickRow("musicVol", "left"), "left", "decrement uses native Left")
    T.eq(optionTable.musicVol, 4, "native decrement changes the actual volume")
    local nextKey = display.StartMenu.redrawKey(view())
    T.check(nextKey ~= beforeKey, "changed native values invalidate the cached canvas")
    T.eq(display.StartMenu.redrawKey(view()), nextKey, "unchanged native values reuse the cached canvas")
    T.eq(clickRow("musicVol", "right"), "right", "increment uses native Right")
    T.eq(optionTable.musicVol, 5, "native increment restores the actual volume")
    local index = select("musicVol")
    local model = view().optionsModel
    local slot = index - model.first + 1
    T.eq(click(120, 36 + (slot - 1) * 39 + 25), nil, "value label is static, never an accidental extra increment")
    T.eq(optionTable.musicVol, 5, "static value leaves settings untouched")
    optionTable.musicVol = 0
    clickRow("musicVol", "left")
    T.eq(optionTable.musicVol, 0, "native lower clamp is preserved")
    local H, animations = theme.hgss, 0
    H:setTouch(24, 36 + (slot - 1) * 39 + 25, true)
    local begin = H.beginPress
    H.beginPress = function(self, x, y, w, h, enabled)
      local pressed = begin(self, x, y, w, h, enabled)
      if pressed then animations = animations + 1 end
      return pressed
    end
    display.NativeOptions.draw(H, view().optionsModel)
    H.beginPress = begin; H:setTouch(nil, nil, true)
    T.eq(animations, 0, "clamped option arrows and static parents never animate")
    local stale = view()
    rows()[1], rows()[2] = rows()[2], rows()[1]
    T.check(not stale.valid(), "native row reorder invalidates old touch indices")
    rows()[1], rows()[2] = rows()[2], rows()[1]
    local child = view()
    T.eq(click(15, 15), "b", "back uses the native submenu exit")
    if generation ~= 3 then owner = game.stack:top() end
    T.check(not child.valid(), "closed subgroup rejects delayed input")
    T.check(view().optionsModel ~= nil, "back restores the common parent page")
    T.eq(done, beforeDone, "leaving a subgroup does not close the root")
    if generation == 3 then
      clickRow("group.speed")
      local context = Native._ctx or Native._st.ctx
      local cart = require("src.core.game3.options").block(context.options)
      cart.textSpeed = 1
      T.eq(clickRow("textSpeed", "left"), "left", "cart option uses Left even when native A has no effect")
      T.eq(cart.textSpeed, 0, "actual cart text speed decreases")
      T.eq(clickRow("textSpeed", "right"), "right", "cart option uses Right")
      T.eq(cart.textSpeed, 1, "actual cart text speed increases")
      local current = view()
      local Message = require("src.ui.game3.message")
      Message.show("Covered options")
      T.check(not current.valid(), "native message prevents covered options from accepting input")
      Message.reset()
      local shader = package.loaded["src.ui.game3.shaderfx_menu"]
      if shader then
        current = view(); shader.show({game=game})
        T.check(not current.valid(), "embedded native shader picker owns input")
        T.eq(display.startMenu(), nil, "covered options do not leave hidden hit targets")
        shader.close()
      end
      click(15, 15)
    end
    click(15, 15)
    T.eq(display.startMenu(), nil, "root exit restores the prior companion")
    T.eq(done, beforeDone + 1, "native root close callback runs exactly once")
    local old = open()
    open()
    T.check(not old.valid(), "reopened options reject controls from an earlier opening")
    click(15, 15)
  end
  api.input.tap, game.input, game.writeOptions, game.options = oldTap, oldInput, oldWrite, oldOptions
end
if generation == 3 then
  dofile(path .. (os.getenv("POKEPORT_VERSION") == "emerald" and "/tests/emerald_runtime_test.lua" or "/tests/gen3_runtime_test.lua"))
else dofile(path .. "/tests/legacy_bag_test.lua") end
