package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local originalFont = T.love.graphics.newFont
T.love.graphics.newFont = function(...)
  local font = originalFont(...)
  function font:hasGlyphs() return true end
  return font
end
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local run = T.sdk.loadMod(path, { generation = generation, data = T.fixtures.fresh() })
T.eq(run.mod and run.mod.state, "loaded", "Gear loads with level-up tracking")
T.eq(#run.errors, 0, "no boot errors")
local mon = { species = "FIXMON_A", nickname = "TESTMON", level = 5, hp = 1,
  stats = { hp = 20, attack = 11, defense = 12, speed = 13 }, moves = {} }
if generation == 1 then mon.stats.special = 14
else mon.stats.specialAttack, mon.stats.specialDefense = 14, 15 end
local world = { isOverworld = true, map = { id = "FIX_ROUTE", def = {} },
  player = { cellX = 2, cellY = 3 } }
local game = { data = run.data, world = world, overworld = world,
  save = { generation = generation, version = generation == 1 and "red" or "crystal",
    player = { name = "RED", id = 1, map = "FIX_ROUTE", badges = {} },
    party = { mon }, inventory = {}, boxes = {},
    pokedex = { seen = {}, caught = {} } },
  stack = { states = { world }, top = function(self) return self.states[#self.states] end },
  input = { pressQueue = {} } }
run.loader.game = game
run.loader.events:emit("game.ready", { game = game })
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss" }
run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
local function upvalue(fn, target)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, i)
    if name == target then return value end
  end
end
local hook
for _, entry in ipairs(run.loader.hooks.chains["input.step"]) do
  if entry.owner == "kanto_gear" then hook = entry.callback end
end
local display = upvalue(hook, "displayRuntime")
local theme = upvalue(display.drawContents, "THEME")
local model
theme.hgss.levelUp = function(_, value) model = value end
T.eq(display.levelUp:get(mon), nil, "game.ready seeds a baseline")
mon.level, mon.stats.hp, mon.stats.attack = 6, 23, 13
run.loader.events:emit("pokemon.level_up", { mon = mon, level = 6, prevLevel = 5 })
T.eq(display.levelUp:get(mon).deltas.attack, 2, "the live event handler captures a gain")
game.stack.states[2] = generation == 1 and { mon = mon }
  or { screenId = "Gen2BattleState", phase = "stats-box", statsBoxMon = mon }
display.drawContents()
T.check(model ~= nil, "native level-up state renders without waiting for a battle snapshot")
T.eq(#model.rows, generation == 1 and 5 or 6, "all generation-specific stats are included")
T.eq(model.rows[1].label, "MAX HP", "maximum HP has its own row")
T.eq(model.rows[1].value, 23, "maximum HP is not current damaged HP")
T.eq(model.rows[1].delta, 3, "the view receives the exact HP gain")
T.eq(model.rows[2].delta, 2, "the view receives the exact attack gain")
T.eq(model.rows[3].delta, 0, "zero gains reach the renderer")
T.check(model.level:find("5", 1, true) and model.level:find("6", 1, true),
  "the view identifies both levels")

-- Rare Candy has no level_up event in either generation. Use the real Gen 2
-- party-result state and its A-button handler; Gear must not pick another mon.
local resultScreen, finished = nil, false
function game.stack:pop() return table.remove(self.states) end
if generation == 2 then
  local PartyMenu = require("src.ui.gen2.PartyMenu")
  resultScreen = setmetatable({ screenId = "Gen2PartyMenu", party = game.save.party,
    index = 1, game = game, clock = 0 }, { __index = PartyMenu })
  resultScreen:showItemResult(1, { text = "Candy", delay = 0 })
else
  resultScreen = require("src.battle.BattleState").StatBox.new(game, mon,
    function() finished = true end)
end
game.stack.states[2] = resultScreen
mon.level, mon.stats.hp, mon.stats.attack = 7, 26, 14
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
T.eq(display.levelUp:get(mon).deltas.attack, 1, "input hook captures event-free Candy")
display.drawContents()
T.eq(model.rows[1].delta, 3, "Candy renders the new maximum-HP gain")
if generation == 2 then
  T.eq(display.levelUp:fieldMon(resultScreen), mon, "only the active Candy result owns the panel")
  resultScreen.itemResult.onDone = function() finished = true end
end
local pressed
game.input.wasPressed = function(_, key) return key == pressed end
local compose
for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
  if entry.owner == "kanto_gear" then compose = entry.callback end
end
local touchEvent = upvalue(compose, "touchEvent")
local api = upvalue(upvalue(upvalue(touchEvent, "tap"), "press"), "mod")
T.check(api ~= nil, "touch input API is reachable")
api.input.tap = function(_, _, key) pressed = key end
display.bag.pending = { itemId = "RARE_CANDY", mon = mon }
touchEvent("tap,10,90", 240, 216)
T.eq(pressed, nil, "tapping stats does not advance or choose a team member")
touchEvent("down,120,185", 240, 216)
touchEvent("up,120,185", 240, 216)
T.eq(pressed, "a", "Continue touch sends normal A before the field party handler")
if generation == 2 then
  resultScreen:updateItemResult(game.input)
  T.eq(display.levelUp:fieldMon(resultScreen), nil, "panel disappears with native result")
else resultScreen:update() end
T.check(finished, "native Candy continuation still runs")
-- A no-event change that happens between input and drawing must be caught in
-- render.compose too, including when the companion is temporarily absent.
mon.level, mon.stats.hp = 8, 28
run.loader.hooks:call("render.compose", function() return false end, {}, {})
T.eq(display.levelUp:get(mon).deltas.hp, 2, "render hook captures changes after the input tick")
run.loader.events:emit("save.loaded", {})
T.eq(display.levelUp:get(mon), nil, "loading a save clears gains even with a reused save table")
T.eq(#run.errors, 0, "no runtime errors")
T.finish("Kanto Gear level-up runtime Gen " .. generation)
