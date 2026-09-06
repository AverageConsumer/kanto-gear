-- Run from the host SDK checkout, with argument 1 or 2. No ROM/device needed.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local generation = assert(tonumber(arg[1]), "choose generation 1 or 2")
local run = T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")), {
  generation = generation, data = T.fixtures.load(),
})
T.eq(run.mod.state, "loaded", "complete mod loads within LuaJIT's upvalue limit")
local function upvalue(fn, target, replacement, set)
  for i = 1, debug.getinfo(fn, "u").nups do
    local key, value = debug.getupvalue(fn, i)
    if key == target then
      if set then debug.setupvalue(fn, i, replacement) end
      return value
    end
  end
  error("missing upvalue " .. target)
end
local function hook(name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local input = hook("input.step")
local display, runtime = upvalue(input, "displayRuntime"), upvalue(input, "hgssRuntime")
local theme = upvalue(display.drawContents, "THEME")
local H = theme.hgss
local drawBattle = upvalue(display.drawContents, "drawBattle")
local refreshBattle = upvalue(hook("render.compose"), "refreshBattle")
local attachBattleArtSprites = upvalue(refreshBattle, "attachBattleArtSprites")
local tap = upvalue(upvalue(hook("render.compose"), "touchEvent"), "tap")
local tapBattle = upvalue(tap, "tapBattle")
local api = upvalue(display.saveHome, "mod")
local world = { map = { id = "PALLET_TOWN", def = {} } }
local raw = { isBattleState = true, screenId = generation == 2 and "Gen2BattleState" or "BattleState",
  menuIndex = 1, moveIndex = 1 }
local stack = { states = { world, raw } }
function stack:top() return self.states[#self.states] end
local party = {}
for slot = 1, 6 do
  party[slot] = { slot = slot, species = "FIXMON_A", name = "PARTNER" .. slot,
    hp = slot == 5 and 0 or 30, maxHp = 50, level = 30, expProgress = 0.4,
    gender = generation == 2 and "male" or nil,
    status = slot == 6 and "SLP" or slot == 1 and "PAR" or nil,
    stats = { hp = 50 }, moves = {} }
end
local game = { data = run.data, world = world, overworld = world, stack = stack,
  input = { pressQueue = {} }, save = { generation = generation,
    player = { name = "RED", id = 7 }, party = party,
    inventory = {}, pokedex = { seen = {}, caught = {} }, boxes = {} } }
run.loader.events:emit("game.ready", { game = game })
local options = { theme_v3 = "hgss", battle_view = "standard", move_details = true }
run.loader.modOptions.kanto_gear = options
run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
local battle = { prompt = "menu", menuIndex = 1, moveIndex = 1, revision = 1,
  party = party, player = party[1], enemy = party[2], kind = "trainer", moves = {} }
for slot = 1, 4 do
  battle.moves[slot] = { id = "FIX_MOVE_A", name = "MOVE " .. slot, pp = 10,
    maxPp = 15, type = "NORMAL", power = 35, accuracy = 95 }
end
local function snapshot()
  upvalue(input, "battle", battle, true)
end
snapshot()
local keys, intents = {}, {}
api.input.tap = function(_, received, key)
  T.eq(received, game, "touch delegates to the current native game")
  keys[#keys + 1] = key
end
api.battle = api.battle or {}
api.battle.submit = function(_, intent) intents[#intents + 1] = intent; return true end
api.battle.snapshot = function() return battle end
local function hit(x, y) tapBattle(x / 1.5, y / 1.5) end
love.graphics.arc = love.graphics.arc or function() end
love.graphics.polygon = love.graphics.polygon or function() end
love.graphics.transformPoint = love.graphics.transformPoint or function(x, y) return x, y end


local touch = upvalue(hook("render.compose"), "touchEvent")
local now = 1
love.timer.getTime = function() return now end
local function sync() display.syncTouchGuard() end
local function step(fn)
  input(function() if fn then fn() end end, game, 1/60)
end
local function phase(name)
  raw.phase = name == "advance" and "messages" or name == "moves"
    and (generation == 1 and "moveSelect" or "moves") or name
  raw.message = name == "advance" and {} or nil
  battle.prompt = name
end
local function clear()
  for i=#keys,1,-1 do keys[i]=nil end
  for i=#intents,1,-1 do intents[i]=nil end
end
stack.states = { world };sync() -- Gen 1 must have entered its overworld once.
stack.states = { world, raw }
phase("advance");sync()
touch("tap,100,110")
T.eq(#keys,1,"first text tap advances")
touch("tap,100,110")
T.eq(#keys,1,"a queued tap burst cannot submit a second native confirmation")
step(function() phase("menu") end)
clear()
now=1.02
touch("tap,100,110")
T.eq(#keys,0,"text-to-menu transition rejects the trailing tap")
now=1.2;touch("tap,100,110")
now=1.4;touch("tap,100,110")
T.eq(#keys,0,"continued rapid tapping cannot eventually choose a menu action")
now=1.7
touch("down,100,110");touch("up,100,110")
T.eq(#keys,1,"new gesture after a quiet interval is accepted")
T.eq(raw.menuIndex,4,"the intended Run button is selected instead of Fight")
step();clear()
-- The same screen object changes its controls while a finger is held.
now=2;phase("advance");sync();touch("down,40,60")
now=2.05;phase("menu");sync()
now=2.5;touch("up,40,60")
T.eq(#keys,0,"release from an old screen cannot activate the replacement controls")
-- Legacy hosts may send only tap, or down/tap/up for one gesture.
now=3;sync();touch("down,40,60");touch("tap,40,60")
T.eq(#keys,0,"synthetic tap inside an active gesture does not commit early")
touch("up,40,60")
T.eq(#keys,1,"down/tap/up commits exactly once")
step(function() phase("moves") end);clear()
now=3.02;touch("tap,30,65")
T.eq(#intents,0,"Fight-to-move-list transition cannot select a move from double tapping")
now=3.4;touch("tap,30,65")
T.eq(#intents,1,"move selection works after the transition settles")
step();clear()
-- A tap arriving between snapshots must dispatch against fresh battle state.
now=4;phase("menu");sync();now=4.4
local fresh = battle
local stale = {};for k,v in pairs(battle) do stale[k]=v end
stale.prompt="advance"
upvalue(input,"battle",stale,true)
api.battle.snapshot=function() return fresh end
touch("100,110")
T.eq(raw.menuIndex,4,"legacy coordinate-only input also uses the fresh battle state")
T.eq(#keys,1,"fresh battle action is sent once")
step();clear()
-- Fast text advancement stays responsive across native text boxes.
phase("advance");now=5;sync()
for i=1,4 do
  now=now+0.08;touch("tap,40,60");step()
end
T.eq(#keys,4,"consecutive text taps are not globally throttled")
clear()
phase("menu");now=6;sync()
runtime.animation = { started = 6, duration = 0.42 }
now=6.3;touch("tap,100,110")
T.eq(#keys,0,"buttons stay protected while a longer panel animation is running")
now=6.7;touch("tap,100,110")
T.eq(raw.menuIndex,4,"Run works once the animation and quiet interval finish")
step();clear();runtime.animation=nil
-- Held text acceleration must be released when buttons replace the text.
stack.states = { world, { isTextBox = true } }
api.battle.snapshot = function() return nil end
upvalue(input,"battle",nil,true)
local held,released=0,0
api.input.press=function() held=held+1;return "text-token" end
api.input.release=function(_,token)
  T.eq(token,"text-token","only Gear's own text hold is released")
  released=released+1
end
now=7;sync();touch("down,40,60")
T.eq(held,1,"holding text still accelerates its reveal")
stack.states = { world };sync()
T.eq(released,1,"text acceleration stops as soon as the text screen closes")
now=7.5;touch("up,40,60")
T.eq(#keys,0,"releasing the old text gesture cannot click the app beneath it")
T.eq(#run.errors,0,"guard produces no runtime errors")
T.finish("Touch transition guard Gen "..generation)
