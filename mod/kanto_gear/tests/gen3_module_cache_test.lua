-- Retain live native state and replacement functions without per-frame requires.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local adapter, ui = display.gen3, display.gen3Ui
  local Map = require("src.core.game3.map")
  local Stack = require("src.ui.game3.stack")
  local Stats = require("src.ui.game3.stat_growth")
  local Message = require("src.ui.game3.message")
  local Choice = require("src.ui.game3.choice")
  local Battle = require("src.core.game3.battle")
  local Schema = require("src.core.game3.save_schema_firered")
  game.session = Schema.newGame({ version = os.getenv("POKEPORT_VERSION"), name = "LIVE", rngSeed = 1234 })
  game.phase = "field"
  adapter:refresh()
  Stack.clear(); Message.close(); Choice.active = false; Battle._active = false
  local env, reads = getfenv(adapter.refresh), 0
  local original = env.require
  env.require = function(name, ...)
    if name == "src.ui.game3.stack" or name == "src.core.game3.map"
        or name == "src.ui.game3.stat_growth" then reads = reads + 1 end
    return original(name, ...)
  end
  for i = 1, 200 do adapter.syncScreens(); display.startMenu() end
  env.require = original
  T.eq(reads, 0, "screen synchronization and menu polling reuse resolved module tables")

  local oldMap, oldLayers, oldTop, oldOpen = Map.current, Stack._layers, Stack.top, Stats.isOpen
  Map.current = "CACHE_TEST_MAP"
  local layer = { id = "cache_test", mod = { cursor = 3 } }
  Stack._layers = { layer }
  adapter.syncScreens()
  T.eq(adapter:gameView().world.map.id, "CACHE_TEST_MAP", "cached module observes live map changes")
  local state = adapter:gameView().stack:top()
  T.eq(state.screenId, "Gen3:cache_test", "cached module observes replaced layer array")
  T.eq(state.index, 3, "cursor remains live")
  layer.mod.cursor = 5
  adapter.syncScreens()
  T.eq(state.index, 5, "repeated sync observes input changes")

  Stack._layers = {}
  local tops, stats = 0, 0
  Stack.top = function() tops = tops + 1 end
  Stats.isOpen = function() stats = stats + 1; return false end
  display.startMenu()
  T.check(tops > 0 and stats > 0, "native function replacements remain visible through cached tables")
  Map.current, Stack._layers, Stack.top, Stats.isOpen = oldMap, oldLayers, oldTop, oldOpen
end
dofile(path .. "/tests/gen3_fixture.lua")
