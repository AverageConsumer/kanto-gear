package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Loader = require("src.mods.Loader")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"

local function loadWithoutNativeSetter()
  local original = Loader._api
  local cache = {}
  Loader._api = function(self, loadedMod)
    local api = original(self, loadedMod)
    api.options.set = nil
    api.cache = {
      read = function(_, key) return cache[key] end,
      write = function(_, key, value) cache[key] = value return true end,
    }
    return api
  end
  local ok, run = pcall(T.sdk.loadMod, path, {
    generation = 2,
    data = T.fixtures.load(),
  })
  Loader._api = original
  if not ok then error(run, 0) end
  return run
end

local function gameFor(run)
  local world = { map = { id = "PALLET_TOWN" } }
  return {
    data = run.data,
    save = {
      generation = 2,
      player = { name = "RED", id = 7, map = "PALLET_TOWN" },
      party = {}, inventory = {}, boxes = {}, currentBox = 1,
      pokedex = { seen = {}, caught = {} },
    },
    world = world,
    stack = { states = { world }, top = function(self)
      return self.states[#self.states]
    end },
  }
end

local function upvalue(fn, target)
  for index = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, index)
    if name == target then return value end
  end
end

local function runtime(run)
  local inputHook
  for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
    if entry.owner == "kanto_gear" then inputHook = entry.callback end
  end
  return upvalue(inputHook, "displayRuntime")
end

local run = loadWithoutNativeSetter()
T.eq(run.mod and run.mod.state, "loaded", "Kanto Gear loads on the stock host")
run.loader.events:emit("game.ready", { game = gameFor(run) })
local display = runtime(run)
display.settings.category, display.settings.page = 1, 1
local model = display.settingsModel()
T.eq(model.rows[1].value, "HGSS LIGHT", "the fallback reads the 3.0 default")
T.eq(model.rows[1].enabled, true, "touch settings stay enabled without host setter")
T.check(display.cycleSetting(model.rows[1], 1), "touch can change the theme")
T.eq(display.settingsModel().rows[1].value, "HGSS DARK",
  "the changed theme is visible immediately")
local api = upvalue(display.saveHome, "mod")
T.eq(api.cache:read("options/theme_v3"), "shgss_dark",
  "the fallback persists the theme outside the game save")
T.check(api.options:set("ui_motion", false), "the fallback accepts toggles")
T.eq(api.cache:read("options/ui_motion"), "b0", "toggle values persist losslessly")
T.check(api.options:set("secondary_size", 20), "the fallback accepts numbers")
T.eq(api.cache:read("options/secondary_size"), "n20",
  "numeric values persist losslessly")
run.loader.modOptions.kanto_gear = run.loader.modOptions.kanto_gear or {}
run.loader.modOptions.kanto_gear.theme_v3 = "hgss"
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "theme_v3", value = "hgss" })
T.eq(api.options:get("theme_v3"), "hgss",
  "the native mod menu replaces a cached touch setting")
T.eq(display.settingsModel().rows[1].value, "HGSS LIGHT",
  "the touch menu immediately follows the native mod menu")
T.eq(api.cache:read("options/theme_v3"), "shgss",
  "the synchronized native value survives the next restart")

T.finish("Kanto Gear settings fallback")
