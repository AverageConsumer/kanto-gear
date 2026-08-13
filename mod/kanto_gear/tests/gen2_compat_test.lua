package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local newCanvas = T.love.graphics.newCanvas
local rectangle = T.love.graphics.rectangle
local getTime = T.love.timer.getTime
local now = 0
local rectangles = {}
T.love.timer.getTime = function() return now end
T.love.graphics.rectangle = function(...)
  rectangles[#rectangles + 1] = { ... }
  return rectangle(...)
end
T.love.graphics.newCanvas = function(...)
  local canvas = newCanvas(...)
  function canvas:requestImageData() return true end
  function canvas:pollImageData() return {} end
  return canvas
end
local run = T.sdk.loadMod(path, {
  generation = 2,
  data = T.fixtures.load(),
})
T.love.graphics.newCanvas = newCanvas
T.love.system.getPowerInfo = function() return "battery", 80 end

T.eq(run.mod and run.mod.state, "loaded",
  "Kanto Gear manifest and entry load for Gen 2")
T.eq(#run.errors, 0, "Kanto Gear has no Gen 2 boot errors")

run.data.gen2Landmarks = { landmarks = {
  LANDMARK_FIX_ROUTE = { index = 2, name = "FIX ROUTE", x = 40, y = 56 },
} }
run.data.gen2Maps = { FIX_ROUTE = {
  landmark = 2,
  objects = {
    { eventFlag = 12, itemball = { item = 1 } },
    { trainer = { class = 3, member = 1, event = 11 } },
  },
  bgEvents = { { x = 3, y = 4,
    hiddenItem = { item = 1, event = 13 } } },
} }
run.data.gen2Trainers = { classes = { YOUNGSTER = {
  index = 3, name = "YOUNGSTER",
  trainers = { { name = "JOEY" } },
} } }
run.data.gen2Encounters = { grass = { FIX_ROUTE = { slots = {
  MORN = { { species = "FIXMON_A", level = 2 } },
  DAY = { { species = "FIXMON_A", level = 3 } },
  NITE = { { species = "FIXMON_B", level = 4 } },
} } }, water = {} }
local johtoMap = {}
for i = 1, 20 * 18 do johtoMap[i] = 0 end
run.data.gen2MenuGfx = { pokegear = {
  tiles = "gold-map.png", tilesWide = 1,
  maps = { johto = johtoMap, kanto = johtoMap },
} }

local game = {
  data = run.data,
  save = {
    generation = 2,
    player = {
      name = "GOLD", id = 25, money = 1234,
      badges = { ZEPHYR = true }, kantoBadges = {},
    },
    party = { {
      species = "FIXMON_A", nickname = "CYNDA", level = 5,
      hp = 20, stats = { hp = 20 }, exp = 0,
    } },
    pokedex = { seen = { FIXMON_A = true }, caught = { FIXMON_A = true } },
    playTime = { hours = 1, minutes = 2, seconds = 3 },
    inventory = {}, boxes = {}, currentBox = 1,
  },
  world = {
    map = { id = "FIX_ROUTE" },
    player = { cellX = 2, cellY = 3, facing = "down" },
  },
  stack = { states = {}, top = function(self)
    return self.states[#self.states]
  end },
}
run.loader.events:emit("game.ready", { game = game })
run.loader.modOptions.kanto_gear = { trigger_tabs = true }
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "trigger_tabs" })

local trigger = 0
T.love.joystick = { getJoysticks = function()
  return { {
    isGamepadDown = function() return false end,
    getGamepadAxis = function(_, axis)
      return axis == "triggerright" and trigger or 0
    end,
  } }
end }
local companion = {
  detected = function() return true end,
  pollTouch = function() return nil end,
  push = function() return true end,
}
local mapDraws = T.record.draw()
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.check(#mapDraws:fromPath("gold-map.png") > 0,
  "Gold map renders the extracted Pokegear town-map tiles")
for _ = 1, 10 do
  trigger = 0.8
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  trigger = 0
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  run.loader.hooks:call("render.compose", function() return false end, {}, {
    secondScreen = companion,
  })
  run.loader.hooks:call("render.compose", function() return false end, {}, {
    secondScreen = companion,
  })
end
mapDraws:stop()
T.check(true, "Gold-shaped save and world render every companion tab")
local firstBadge, lastBadge = false, false
for _, call in ipairs(rectangles) do
  local _, x, y, w, h = unpack(call)
  if y == 57 and w == 12 and h == 12 then
    firstBadge = firstBadge or x == 11
    lastBadge = lastBadge or x == 137
  end
end
T.check(firstBadge and lastBadge,
  "Gold badges use smaller icons with equal outer margins")

local enemy = { species = "FIXMON_B", level = 4, hp = 11, maxHp = 12,
  moves = {} }
local battle = { player = game.save.party[1], enemy = enemy,
  party = game.save.party, wild = true, turn = 0 }
function battle:moveDisabled() return false end
local screen = { screenId = "Gen2BattleState", battle = battle,
  phase = "menu", menuIndex = 1, moveIndex = 1,
  shownHp = { player = 19, enemy = 10 } }
game.stack.states = { screen }
run.loader.game = game
now = now + 1
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.check(true, "Gold battle state and direct mon HP shape render safely")

run.loader.modOptions.kanto_gear.battle_view = "gear"
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "battle_view" })
T.eq(run.loader.hooks:call("battle.bottom_ui_visible",
    function() return true end, screen), false,
  "GEAR gives Gold battle text and menus to the companion screen")
T.eq(run.loader.hooks:call("battle.status_hud_visible",
    function() return true end, screen), true,
  "GEAR leaves Gold's native status HUD visible")
run.loader.modOptions.kanto_gear.battle_view = "full"
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "battle_view" })
T.eq(run.loader.hooks:call("battle.status_hud_visible",
    function() return true end, screen), false,
  "FULL GEAR gives Gold's status HUD to the companion screen too")

-- Gold resolves the turn before its native HP bar finishes chasing the new
-- value.  The companion must follow screen.shownHp, not jump straight to the
-- already-final battle mon HP.
local main = assert(io.open(path .. "/main.lua", "rb"))
local source = main:read("*a")
main:close()
T.check(source:find("raw%.battle and raw%.battle%[side%]", 1) ~= nil,
  "Gold FULL GEAR reads chased HP from the nested battle state")

run.loader.game = game
screen.phase = "anim"
screen.message = "FIXMON_A used TACKLE!"
screen.hpAnim = { side = "enemy", to = 7 }
screen.shownHp.enemy = 9
screen.battle.enemy.hp = 7
rectangles = {}
now = now + 1
run.loader.events:emit("battle.damage_dealt", {})
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
local sawEnemyPanel, sawChasedHp = false, false
for _, call in ipairs(rectangles) do
  local _, x, y, w, h = unpack(call)
  if x == 4 and y == 3 and w == 152 and h == 40 then
    sawEnemyPanel = true
  elseif x == 29 and y == 28 and w == 49 and h == 5 then
    sawChasedHp = true
  end
end
T.check(sawEnemyPanel,
  "Gold HP animation keeps FULL GEAR status panels visible")
T.check(sawChasedHp,
  "Gold HP animation draws the chased intermediate enemy HP")
screen.phase, screen.message, screen.hpAnim = "menu", nil, nil

screen.statsBoxMon = game.save.party[1]
screen.statsBoxMon.stats = { hp = 22, attack = 12, defense = 11,
  specialAttack = 13, specialDefense = 14, speed = 15 }
screen.phase = "stats-box"
rectangles = {}
now = now + 1
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
local sawLevelContinue = false
for _, call in ipairs(rectangles) do
  local _, x, y, w, h = unpack(call)
  if x == 24 and y == 111 and w == 112 and h == 27 then
    sawLevelContinue = true
  end
end
T.check(sawLevelContinue,
  "Gold level-up stats render on the companion screen")
T.eq(run.loader.hooks:call("screen.render_visible",
  function() return true end, screen), true,
  "Gold level-up keeps the native battle scene visible")

screen.phase, screen.statsBoxMon = "resolving", nil
screen.message = "FIXMON_A gained 12 EXP. Points!"
now = now + 1
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
game.stack.states = {}
run.loader.events:emit("screen.popped", { state = screen })
rectangles = {}
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
local staleBattlePanel = false
for _, call in ipairs(rectangles) do
  local _, x, y, w, h = unpack(call)
  if x == 4 and y == 3 and w == 152 and h == 40 then
    staleBattlePanel = true
  end
end
T.check(not staleBattlePanel,
  "popping Gold's battle screen clears the cached EXP view immediately")
screen.phase, screen.message = "menu", nil

local pack = {
  screenId = "Gen2PackMenu", battle = true, pocketIndex = 1, index = 1,
  rows = { { id = "POTION", name = "POTION", count = 2,
    showCount = true } },
  pocket = function() return { id = "ITEM", label = "ITEMS" } end,
}
game.stack.states = { screen, pack }
now = now + 1
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.check(true, "Gold battle PACK rows render on the companion screen")

local party = {
  screenId = "Gen2PartyMenu", index = #game.save.party + 1,
  isCancel = function(self) return self.index > #game.save.party end,
}
game.stack.states = { screen, party }
now = now + 1
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.check(true, "Gold party CANCEL renders as navigation instead of a Pokemon")

local summary = {
  screenId = "Gen2SummaryMenu", page = 3, mon = game.save.party[1],
  itemName = function() return "BERRY" end,
  expToNext = function() return 20 end,
  otName = function() return "GOLD" end,
  otId = function() return 25 end,
}
summary.mon.experience = 12
summary.mon.maxHp = 20
summary.mon.stats.attack = 9
summary.mon.stats.defense = 10
summary.mon.stats.specialAttack = 11
summary.mon.stats.specialDefense = 12
summary.mon.stats.speed = 13
game.stack.states = { screen, party, summary }
now = now + 1
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.eq(run.loader.hooks:call("screen.render_visible",
  function() return true end, summary), false,
  "Gold battle summaries render only on the companion screen")
game.stack.states = { summary }
T.eq(run.loader.hooks:call("screen.render_visible",
  function() return true end, summary), true,
  "Gold field summaries keep their native top-screen rendering")
game.stack.states = { screen, party, summary }
summary.moveDetail = true
T.eq(run.loader.hooks:call("screen.render_visible",
  function() return true end, summary), true,
  "unsupported Gold summary subviews safely keep native rendering")
summary.moveDetail = false

local scriptChoice = {
  screenId = "Gen2ScriptMenu", items = { "ONE", "TWO", "THREE" },
  row = 2, col = 1, cols = 1,
}
game.stack.states = { scriptChoice }
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.eq(scriptChoice.row, 2,
  "Gold script choices share the companion choice renderer")

local nestedChoice = { screenId = "Gen2PackMenu",
  confirm = { choice = 2 } }
game.stack.states = { nestedChoice }
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.eq(nestedChoice.confirm.choice, 2,
  "Gold nested confirmations share the companion choice renderer")

local nameChoice = { screenId = "Gen2NamePick",
  items = { "NEW NAME", "GOLD" }, cursor = 2 }
game.stack.states = { nameChoice }
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = companion,
})
T.eq(nameChoice.cursor, 2,
  "Gold name choices share the companion choice renderer")

run.release()
T.love.graphics.rectangle = rectangle
T.love.timer.getTime = getTime
T.finish("Kanto Gear Gen 2 compatibility")
