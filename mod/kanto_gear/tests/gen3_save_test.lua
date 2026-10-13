-- Native SaveMenu/HUD controls; isolated writers never touch a real save.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local Save = require("src.ui.game3.save_menu")
  local Hud, Stack = require("src.ui.game3.hud"), require("src.ui.game3.stack")
  local Message, Choice = require("src.ui.game3.message"), require("src.ui.game3.choice")
  local Runtime, Bridge = require("src.core.game3.runtime"), require("src.core.game3.bridge")
  local SaveData = require("src.core.SaveData")
  local api = up(display.saveHome, "mod")
  local original = { game = Runtime._game, mod = Runtime._mod, load = SaveData.load,
    persist = Bridge.persistSessionOnly, tap = api.input.tap, input = game.input }
  local queued, writes, persisted, closes, exists, success = nil, 0, 0, 0, true, true
  Runtime._game = { saveGame = function() writes = writes + 1; return success end }
  Runtime._mod = {}
  Bridge.persistSessionOnly = function() persisted = persisted + 1 end
  SaveData.load = function() return exists and {} or nil end
  api.input.tap = function(_, target, key) T.eq(target, game, "save input targets actual game"); queued = key end
  local function tick(key)
    game.input = { wasPressed = function(_, k) return k == key end, isDown = function() return false end }
    Hud.update(game, 1 / 60)
  end
  local function open()
    Save.close(); Stack.clear(); Message.reset(); Choice.reset(); queued = nil
    Save.show({ session = game.session, game = game, onClose = function() closes = closes + 1 end })
    display.gen3.syncScreens()
    return assert(display.startMenu())
  end
  local function click(view, index)
    local row = assert(display.StartMenu.model(view)).entries[index]
    queued = nil
    display.tapStartMenu(view, (row.x + row.w / 2) / 1.5, (row.y + row.h / 2) / 1.5)
    if queued then local key = queued; queued = nil; tick(key) end
  end
  local function nativePrompt(view)
    local Font = require("src.ui.game3.frlg_font")
    local Chrome = require("src.ui.game3.chrome")
    local Window = require("src.ui.game3.window")
    local draw, found = Font.draw, false
    local frame, panel = Chrome.dialogueFrame, Window.stdFrame
    -- Capture native text without requiring imported user-frame artwork.
    Chrome.dialogueFrame = function() end
    Window.stdFrame = function() end
    Font.draw = function(text)
      if display.gen3:plainText(text):gsub("%s+", " ") == view.prompt:gsub("%s+", " ") then found = true end
    end
    local ok, err = pcall(Save.draw)
    Font.draw, Chrome.dialogueFrame, Window.stdFrame = draw, frame, panel
    T.check(ok, "native save prompt capture runs: " .. tostring(err))
    T.check(found, "lower confirmation matches the actual native upper prompt")
  end
  for _, style in ipairs({ "hgss", "hgss_dark" }) do
    run.loader.modOptions.kanto_gear.theme_v3 = style
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = style })
    local view = open()
    T.eq(view.title, "SAVE", "save uses common choice page")
    T.eq(#view.items, 2, "only actual native Yes/No choices are offered")
    nativePrompt(view)
    T.check(pcall(display.drawContents), "save confirmation renders")
    local before, closed = writes, closes
    click(view, 2)
    T.check(not Save.open, "No closes actual save menu")
    T.eq(writes, before, "No never writes")
    T.eq(closes, closed + 1, "No runs native close callback once")
    T.check(not view.valid(), "closed save view is invalid")
    view = open(); click(view, 1)
    T.eq(Save._phase, "overwrite", "existing slot always receives separate overwrite confirmation")
    T.eq(writes, before, "first Yes never overwrites an existing slot")
    T.check(not view.valid(), "first confirmation cannot accept overwrite")
    local overwrite = assert(display.startMenu())
    nativePrompt(overwrite)
    T.check(overwrite.prompt ~= view.prompt, "overwrite retains distinct native warning")
    click(overwrite, 2)
    T.eq(writes, before, "No on overwrite preserves save")
    T.check(not Save.open, "overwrite cancellation returns normally")
    view = open(); click(view, 1); overwrite = assert(display.startMenu())
    Choice.active = true
    T.check(not overwrite.valid(), "covered save choices cannot perform or animate a touch")
    Choice.active = false
    click(overwrite, 1)
    if Save._rse then
      T.eq(Save._phase, "saving_msg", "Emerald keeps native asynchronous saving message")
      T.eq(writes, before, "touch never replaces native timed write")
      T.eq(display.startMenu(), nil, "writing phase has no fake clickable choices")
      tick()
    end
    T.eq(writes, before + 1, "confirmed native save writes once")
    T.eq(Save._phase, "saved", "native success owns completion")
    T.eq(display.startMenu(), nil, "success remains native status, not another choice page")
    if Save._rse then for _ = 1, 61 do if Save.open then tick() end end
    else tick("a") end
    T.check(not Save.open, "native completion returns to the game")
    T.eq(writes, before + 1, "completion cannot write twice")
    success = false
    view = open(); click(view, 1); click(assert(display.startMenu()), 1)
    if Save._rse then tick() end
    T.eq(Save._phase, "save_failed", "failed native write is never claimed as success")
    T.eq(display.startMenu(), nil, "failure stays readable in native status display")
    tick("a"); T.check(not Save.open, "native failure acknowledgement closes once")
    success = true
    exists = false; view = open(); click(view, 1)
    if Save._rse then
      T.eq(Save._phase, "saving_msg", "new Emerald slot does not invent an overwrite question")
      tick()
    else
      T.eq(Save._phase, "overwrite", "FRLG retains its actual host confirmation sequence")
      click(assert(display.startMenu()), 1)
    end
    T.eq(Save._phase, "saved", "new-slot native save completes")
    Save.close(); exists = true
    view = open()
    Save.show({ session = game.session, game = game })
    T.check(not view.valid(), "reopening singleton native module invalidates old save view")
    queued = nil; display.tapStartMenu(view, 100, 100)
    T.eq(queued, nil, "stale save view cannot submit a confirmation")
    Save.close()
  end
  T.eq(persisted, writes, "native sidecar and native write stay paired")
  Runtime._game, Runtime._mod, SaveData.load = original.game, original.mod, original.load
  Bridge.persistSessionOnly, api.input.tap, game.input = original.persist, original.tap, original.input
  Save.close(); Stack.clear(); Message.reset(); Choice.reset(); display.gen3.syncScreens()
end
dofile(path .. "/tests/gen3_fixture.lua")
