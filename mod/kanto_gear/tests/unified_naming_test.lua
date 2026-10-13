-- Shared naming geometry drives the real legacy naming handlers.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local gen = assert(tonumber(os.getenv("KANTO_GEAR_TEST_GEN") or arg[1]))
local run = T.sdk.loadMod(path, { generation = gen, data = T.fixtures.load() })
assert(run.mod, run.error or run.reason)
love.graphics.arc = love.graphics.arc or function() end
love.graphics.polygon = love.graphics.polygon or function() end
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local function hook(name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local display = up(hook("input.step"), "displayRuntime")
local api = up(display.saveHome, "mod")
local touch = up(hook("render.compose"), "touchEvent")
local world = { map = { id = "PALLET_TOWN", def = {} } }
local game = { data = run.data, world = world, overworld = world,
  stack = { states = { world }, top = function(self) return self.states[#self.states] end,
    pop = function(self) return table.remove(self.states) end },
  input = { wasPressed = function() return false end },
  save = { generation = gen, player = { name = "RED" }, party = {}, inventory = {},
    pokedex = { seen = {}, caught = {} }, boxes = {}, options = {} } }
run.loader.events:emit("game.ready", { game = game })
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss", ui_motion = false }
local now, key, top, result = 100
love.timer.getTime = function() return now end
api.input.tap = function(_, target, value) T.eq(target, game, "naming targets original game"); key = value end
local Naming = require(gen == 2 and "src.ui.gen2.NamingScreen" or "src.ui.NamingScreen")
local function open(kind)
  result = nil
  top = Naming.new(game, { type = kind, default = "DEFAULT", onDone = function(value) result = value end })
  top.screenId = gen == 2 and "Gen2NamingScreen" or "NamingScreen"
  game.stack.states = { world, top }
  display.syncTouchGuard(); now = now + 1
end
local function model()
  local grid
  if gen == 2 then
    grid = {}; for i, row in ipairs(top:rows()) do grid[i] = row end
    grid[#grid + 1] = { top.lower and "UPPER CASE" or "lower case", "DEL", "END" }
  else grid = top:grid() end
  return display.namingModel(top, grid)
end
local function name() return gen == 2 and top.text or table.concat(top.glyphs) end
local function input(value)
  game.input = { wasPressed = function(_, wanted) return wanted == value end }
  hook("input.step")(function() top:update(1 / 60) end, game, 1 / 60)
end
local function hit(entry)
  key = nil; display.syncTouchGuard(); now = now + 1
  touch(("tap,%d,%d"):format(entry.x + math.floor(entry.w / 2), entry.y + math.floor(entry.h / 2)), 240, 216)
  T.check(key ~= nil, "displayed key queues an original input")
  input(key)
end
local function find(wanted, action)
  for _, entry in ipairs(model().entries) do
    if action and entry.action == wanted or not action and entry.label == wanted then return entry end
  end
  error("missing naming key " .. wanted)
end
for _, style in ipairs({ "hgss", "hgss_dark" }) do
  run.loader.modOptions.kanto_gear.theme_v3 = style
  run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
  for _, layout in ipairs({ "qwerty", "qwertz" }) do
  run.loader.modOptions.kanto_gear.keyboard_layout = layout
  for _, kind in ipairs({ "player", "rival", "nickname", "box" }) do
    open(kind)
    local m = model()
    local ok, err = pcall(display.drawContents)
    T.check(ok, "common naming renders: " .. tostring(err))
    local row = {}
    for _, entry in ipairs(m.entries) do
      if not entry.action and entry.label:match("^[A-Z]$") and entry.y == find("Q").y then
        row[#row + 1] = entry
      end
    end
    table.sort(row, function(a, b) return a.x < b.x end)
    local text = ""; for _, entry in ipairs(row) do text = text .. entry.label end
    T.eq(text, layout == "qwertz" and "QWERTZUIOP" or "QWERTYUIOP", "setting orders the displayed top row")
    for letter in ("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):gmatch(".") do
      top.text, top.glyphs = "", {}
      hit(find(letter)); T.eq(name(), letter, "reordered touch types native " .. letter)
    end
    top.text, top.glyphs = "", {}
    for _, entry in ipairs(m.entries) do
      local expected = not entry.disabled and entry.index or nil
      T.eq(display.NamingPage.hit(m, entry.x + entry.w / 2, entry.y + entry.h / 2), expected,
        "naming hit geometry respects current key availability")
      T.check(entry.y >= 70 and entry.y + entry.h <= 213, "keys fit below the name and within the screen")
      if entry.action then
        T.eq(entry.y, 184, "all generations put actions on the same row")
        T.eq(entry.w, 72, "actions have common touch widths")
      end
    end
    local before = #m.entries
    hit(find("A")); T.eq(name(), "A", "native character entry types exactly A")
    hit(find("case", true)); T.check(top.lower, "case button uses the native alphabet switch")
    T.eq(#model().entries, before, "case switch retains all native keys")
    for letter in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
      top.text, top.glyphs = "", {}
      hit(find(letter)); T.eq(name(), letter, "reordered touch types lowercase " .. letter)
    end
    top.text, top.glyphs = "A", { "A" }
    hit(find("b")); T.eq(name(), "Ab", "native lowercase character retains its case")
    hit(find("delete", true)); T.eq(name(), "A", "DEL removes exactly one character")
    hit(find("_")); T.eq(name(), "A ", "space key still sends a real native blank")
    hit(find("delete", true)); T.eq(name(), "A", "space can be removed normally")
    -- A hardware alphabet change while a finger is held cannot type a new key on release.
    local letter = find("b")
    display.syncTouchGuard(); now = now + 1
    touch(("down,%d,%d"):format(letter.x + 8, letter.y + 8), 240, 216)
    input("select"); display.syncTouchGuard(); now = now + 1; key = nil
    touch(("up,%d,%d"):format(letter.x + 8, letter.y + 8), 240, 216)
    T.eq(key, nil, "held touch cannot activate a replaced alphabet")
    letter = find("B")
    display.syncTouchGuard(); now = now + 1
    touch(("down,%d,%d"):format(letter.x + 8, letter.y + 8), 240, 216)
    run.loader.modOptions.kanto_gear.keyboard_layout = layout == "qwerty" and "qwertz" or "qwerty"
    display.syncTouchGuard(); now = now + 1; key = nil
    touch(("up,%d,%d"):format(letter.x + 8, letter.y + 8), 240, 216)
    T.eq(key, nil, "held touch cannot activate a changed keyboard layout")
    run.loader.modOptions.kanto_gear.keyboard_layout = layout
    hit(find("confirm", true)); T.eq(result, "A", "OK finishes through the native name callback")
    open(kind); hit(find("confirm", true))
    T.check(result ~= nil, "empty names retain native default-name handling")
  end
  end
end
local custom = { { label = "あ", row = 1 }, { label = "い", row = 1 },
  { label = "A", row = 2 }, { label = "OK", action = "confirm" } }
local a = display.NamingPage.model("", custom, 7, 0, "qwerty")
local b = display.NamingPage.model("", custom, 7, 0, "qwertz")
for i, entry in ipairs(a.entries) do
  T.eq(b.entries[i].label, entry.label, "custom alphabets retain every original character")
  T.eq(b.entries[i].x, entry.x, "custom alphabet ordering stays intact")
  T.eq(b.entries[i].y, entry.y, "custom alphabet rows stay intact")
end
T.finish()
