-- Native-only screens dim the existing companion without adding dead controls.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local gen = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
love.graphics.arc = love.graphics.arc or function() end
love.graphics.polygon = love.graphics.polygon or function() end
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local function check(run, display, open, close)
  run.loader.modOptions.kanto_gear = run.loader.modOptions.kanto_gear or {}
  display.home.help = false
  local theme = up(display.drawContents, "THEME")
  local H = theme.hgss
  local drawPage, overlay, info = display.drawCompanionPage, H.systemOverlay, H.partyInfo
  local pages, overlays = 0, 0
  display.drawCompanionPage = function()
    pages = pages + 1
    return drawPage()
  end
  H.systemOverlay = function(self, alpha, prompt, now)
    overlays = overlays + 1
    T.check(not prompt, "native-only fallback adds no continue control")
    return overlay(self, alpha, prompt, now)
  end
  H.partyInfo = function(self, text, ...)
    T.check(text ~= "FOLLOW TOP SCREEN" and text ~= "INPUT STAYS ON TOP", "no handoff instruction")
    return info(self, text, ...)
  end
  for _, style in ipairs({ "hgss", "hgss_dark" }) do
    run.loader.modOptions.kanto_gear.theme_v3 = style
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
    close(); display.drawContents()
    T.eq(display.backgroundDim, 0, "ordinary companion is undimmed")
    local before = pages
    overlays = 0; open(); display.drawContents()
    T.eq(pages, before + 1, "native-only screen retains the current companion page")
    T.eq(overlays, 1, "handoff dims exactly once")
    T.check(display.backgroundDim > 0, "handoff also dims the surrounding display border")
    close(); display.drawContents()
    T.eq(display.backgroundDim, 0, "returning clears the dim without retaining a handoff card")
  end
  display.drawCompanionPage, H.systemOverlay, H.partyInfo = drawPage, overlay, info
end
if gen == 3 then
  _G.KANTO_GEAR_RENDER_CAPTURE = function(run, display)
    local Stack = require("src.ui.game3.stack")
    local Message = require("src.ui.game3.message")
    local refresh
    for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
      if entry.owner == "kanto_gear" then refresh = up(entry.callback, "refreshBattle") end
    end
    Message.reset(); Stack.clear()
    check(run, display, function()
      Stack.push("unadapted-test-menu", {})
      display.gen3.syncScreens(); refresh()
    end, function()
      Stack.clear(); display.gen3.syncScreens(); refresh()
    end)
  end
  dofile(path .. (os.getenv("POKEPORT_VERSION") == "emerald"
    and "/tests/emerald_runtime_test.lua" or "/tests/gen3_runtime_test.lua"))
else
  local run = T.sdk.loadMod(path, { generation = gen, data = T.fixtures.load() })
  assert(run.mod, run.error or run.reason)
  local display
  for _, entry in ipairs(run.loader.hooks.chains["input.step"]) do
    if entry.owner == "kanto_gear" then display = up(entry.callback, "displayRuntime") end
  end
  local world = { map = { id = "PALLET_TOWN", def = {} } }
  local game = { data = run.data, world = world, overworld = world,
    stack = { states = { world }, top = function(self) return self.states[#self.states] end },
    save = { generation = gen, player = { name = "RED" }, party = {}, inventory = {},
      pokedex = { seen = {}, caught = {} }, boxes = {}, options = {} } }
  run.loader.events:emit("game.ready", { game = game })
  check(run, display, function()
    game.stack.states[2] = { screenId = gen == 2 and "Gen2NamingScreen" or "NamingScreen" }
  end, function() game.stack.states[2] = nil end)
  T.finish()
end
