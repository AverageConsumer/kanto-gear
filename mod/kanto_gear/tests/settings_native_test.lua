local T = require("tests.modkit")
local Loader = require("src.mods.Loader")
local Manager = require("src.mods.ManagerState")
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local function copy(t)
  local result = {}
  for key, value in pairs(t or {}) do result[key] = value end
  return result
end
local function load(cache, stored, generation)
  local original, cacheWrites = Loader._api, 0
  Loader._api = function(self, mod)
    self.modOptions.kanto_gear = copy(stored)
    local api = original(self, mod)
    api.options.set = nil
    api.cache = { read = function(_, key) return cache[key] end,
      write = function(_, key, value) cacheWrites = cacheWrites + 1; cache[key] = value; return true end }
    return api
  end
  local ok, run = pcall(T.sdk.loadMod, root,
    { generation = generation, data = T.fixtures.fresh() })
  Loader._api = original
  assert(ok, run)
  T.eq(run.mod.state, "loaded", "stock-host mod loads")
  local callback
  for _, hook in ipairs(run.loader.hooks.chains["input.step"]) do
    if hook.owner == "kanto_gear" then callback = hook.callback end
  end
  local display = up(callback, "displayRuntime")
  local api = up(display.saveHome, "mod")
  local schema = up(display.drawContents, "THEME").optionSchema
  local writes, persisted = 0
  local options = { volume = 7, modOptions = {
    kanto_gear = copy(stored), other_mod = { enabled = false } } }
  local game = { mods = run.loader, save = { options = options },
    writeOptions = function(self)
      writes = writes + 1
      persisted = copy((self.options or self.save.options).modOptions.kanto_gear)
    end }
  -- Gen 3's real manager uses a proxy with save.options = Game3.options.
  if generation == 3 then game.options, game.save = options, nil end
  api.options:bindGame(game, schema)
  local beforeCache, beforeWrites = cacheWrites, writes
  api.options:bindGame(game, schema)
  T.eq(cacheWrites, beforeCache, "rebinding unchanged options does not rewrite cache files")
  T.eq(writes, beforeWrites, "rebinding unchanged options does not rewrite host settings")
  local proxy = generation == 3 and setmetatable({ save = { options = options } },
    { __index = game }) or game
  local manager = Manager.new(proxy)
  manager.notify = function() end
  local native = run.loader.optionSchemas.kanto_gear
  local function rows() manager.optionRows = manager:buildOptionRows({ id = "kanto_gear" }, native) end
  local function find(key)
    rows()
    for _, row in ipairs(manager.optionRows) do if row.id == key then return row end end
  end
  return run, api, schema, native, manager, find, function() return persisted, writes end, options
end

for generation = 1, 3 do
  local cache = { ["options/display_mode"] = "sphone",
    ["options/combined_layout"] = "soverlay", ["options/theme_v3"] = "shgss_dark" }
  local run, api, schema, native, manager, find, saved, options = load(cache, {}, generation)
  T.eq(native[1].key, "display_mode", "display recovery is the first native option")
  T.eq(find("display_mode").value(), "PHONE / BROWSER", "native menu reflects cached phone mode")
  api.options:set("info_level", "custom")
  local found = {}
  for _, mode in ipairs({ "phone", "separate", "combined", "fullscreen" }) do
    api.options:set("display_mode", mode)
    for _, row in ipairs(schema) do
      local nativeRow = find(row.key)
      if nativeRow then found[row.key] = true end
    end
  end
  for _, row in ipairs(schema) do
    T.check(found[row.key], "native menu exposes setting " .. row.key)
    local matching
    for _, n in ipairs(native) do if n.key == row.key then matching = n end end
    T.check(matching and matching ~= row, "native metadata cannot alter Gear's contextual row")
    T.eq(matching.default, row.reset_default ~= nil and row.reset_default or row.default,
      "both menus reset " .. row.key .. " consistently")
  end
  T.check(find("ui_motion") and find("map_motion") and find("ui_haptics"),
    "stock visibility rules no longer hide presentation and controls")
  api.options:set("display_mode", "combined")
  T.check(find("auto_battle_screen") and find("screen_swap"), "native swap options are reachable")
  api.options:set("keyboard_layout", "qwertz")
  T.eq(find("keyboard_layout").value(), "QWERTZ", "Gear changes immediately reach the native menu")
  T.eq(saved().keyboard_layout, "qwertz", "Gear changes also reach host persistence")
  T.eq(options.volume, 7, "publishing a mod option preserves game settings")
  T.eq(options.modOptions.other_mod.enabled, false, "other mods retain their settings")
  manager:setOption("kanto_gear", "keyboard_layout", "qwerty")
  T.eq(api.options:get("keyboard_layout"), "qwerty", "native changes immediately reach Gear")
  T.eq(cache["options/keyboard_layout"], "sqwerty", "native changes replace stale fallback cache")
  api.options:set("display_mode", "phone")
  find("display_mode").step(nil, -1)
  T.eq(api.options:get("display_mode"), "separate", "one native left press exits phone mode")
  T.eq(saved().display_mode, "separate", "recovery survives restart")
  api.options:set("display_mode", "phone")
  find("__reset").activate()
  T.eq(api.options:get("display_mode"), "separate", "reset never restores phone mode")
  T.eq(api.options:get("combined_layout"), "auto", "reset does not reuse a cached overlay default")
  T.eq(saved().display_mode, "separate", "native reset persists the safe local output")
  local launcherRows = up(require("src.import.LauncherSettings").open, "modRows")
  local launcherOptions = { modOptions = { kanto_gear = { display_mode = "phone" } } }
  local launcher = launcherRows(launcherOptions, { id = "kanto_gear", schema = native })
  T.eq(launcher[1].value(), "PHONE / BROWSER", "launcher shows the current wireless output first")
  launcher[1].step(-1)
  T.eq(launcherOptions.modOptions.kanto_gear.display_mode, "separate", "launcher can exit phone mode too")
  launcherOptions.modOptions.kanto_gear.display_mode = "phone"
  launcher[#launcher].step()
  T.eq(launcherOptions.modOptions.kanto_gear.display_mode, "separate", "launcher reset uses the same safe default")
  T.eq(#launcher, #schema + 1, "launcher exposes every option plus reset")
  T.eq(#run.errors, 0, "native options leave no loader errors")
  local persisted = saved()
  run.release()
  cache["options/display_mode"] = "sphone"
  -- A launcher edit while Gear is not running must beat the old cache.
  persisted.display_mode = "fullscreen"
  local restarted, restartedApi, _, _, _, restartedFind = load(cache, persisted, generation)
  T.eq(restartedApi.options:get("display_mode"), "fullscreen", "launcher recovery beats stale phone cache")
  T.eq(restartedFind("display_mode").value(), "FULLSCREEN SWAP", "both surfaces agree after restart")
  restarted.release()
  local legacy, migrated, _, _, _, _, legacySaved = load({},
    { info_level = "enhanced", type_hints = false }, generation)
  T.eq(migrated.options:get("info_level"), "custom", "legacy native helper differences migrate to Custom")
  T.eq(migrated.options:get("type_hints"), false, "migration preserves the disabled native helper")
  T.eq(legacySaved().info_level, "custom", "migrated preset reaches host persistence")
  legacy.release()
end
T.finish("Kanto Gear native options parity and recovery")
