package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local newCanvas = T.love.graphics.newCanvas
T.love.graphics.newCanvas = function(...)
  local canvas = newCanvas(...)
  function canvas:requestImageData() return true end
  function canvas:pollImageData() return nil end
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
run.data.gen2Maps = { FIX_ROUTE = { landmark = 2 } }
run.data.gen2Encounters = { grass = { FIX_ROUTE = { slots = {
  MORN = { { species = "FIXMON_A", level = 2 } },
  DAY = { { species = "FIXMON_A", level = 3 } },
  NITE = { { species = "FIXMON_B", level = 4 } },
} } }, water = {} }

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
}
for _ = 1, 10 do
  trigger = 0.8
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  trigger = 0
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  run.loader.hooks:call("render.compose", function() return false end, {}, {
    secondScreen = companion,
  })
end
T.check(true, "Gold-shaped save and world render every companion tab")

run.release()
T.finish("Kanto Gear Gen 2 compatibility")
