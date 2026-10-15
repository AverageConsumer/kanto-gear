package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Loader = require("src.mods.Loader")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"

local function loadWithoutNativeSetter(cache)
  local original = Loader._api
  cache = cache or {}
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
    data = T.fixtures.fresh(),
  })
  Loader._api = original
  if not ok then error(run, 0) end
  return run, cache
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

local upvalue = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get

local function runtime(run)
  local inputHook
  for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
    if entry.owner == "kanto_gear" then inputHook = entry.callback end
  end
  return upvalue(inputHook, "displayRuntime")
end

local run, persistedCache = loadWithoutNativeSetter()
T.eq(run.mod and run.mod.state, "loaded", "Kanto Gear loads on the stock host")
run.loader.events:emit("game.ready", { game = gameFor(run) })
local display = runtime(run)
display.settings.category, display.settings.page = 1, 1
local model = display.settingsModel()
local function rowFor(key)
  for _, row in ipairs(display.settingsModel().rows) do
    if row.key == key then return row end
  end
end
T.eq(rowFor("theme_v3").value, "POKEGEAR LIGHT", "the fallback reads the 3.0 default")
T.eq(rowFor("theme_v3").enabled, true, "touch settings stay enabled without host setter")
T.check(display.cycleSetting(rowFor("theme_v3"), 1), "touch can change the theme")
T.eq(rowFor("theme_v3").value, "POKEGEAR DARK",
  "the changed theme is visible immediately")
local api = upvalue(display.saveHome, "mod")
T.eq(api.cache:read("options/theme_v3"), "shgss_dark",
  "the fallback persists the theme outside the game save")
T.check(api.options:set("ui_motion", false), "the fallback accepts toggles")
T.eq(api.cache:read("options/ui_motion"), "b0", "toggle values persist losslessly")
T.check(api.options:set("ui_haptics", true), "haptics can be enabled independently")
T.eq(api.cache:read("options/ui_haptics"), "b1", "haptics persist outside the game save")
T.eq(api.options:get("keyboard_layout"), "qwerty", "missing saved layout uses QWERTY")
T.check(api.options:set("keyboard_layout", "qwertz"), "the German layout can be selected")
T.eq(api.cache:read("options/keyboard_layout"), "sqwertz", "layout persists outside the game save")
T.check(api.options:set("secondary_size", 20), "the fallback accepts numbers")
T.eq(api.cache:read("options/secondary_size"), "n20",
  "numeric values persist losslessly")
run.loader.modOptions.kanto_gear = run.loader.modOptions.kanto_gear or {}
run.loader.modOptions.kanto_gear.theme_v3 = "hgss"
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "theme_v3", value = "hgss" })
T.eq(api.options:get("theme_v3"), "hgss",
  "the native mod menu replaces a cached touch setting")
T.eq(rowFor("theme_v3").value, "POKEGEAR LIGHT",
  "the touch menu immediately follows the native mod menu")
T.eq(api.cache:read("options/theme_v3"), "shgss",
  "the synchronized native value survives the next restart")

T.check(display.cycleSetting(rowFor("language"), 1), "touch changes language")
T.eq(api.options:get("language"), "de", "touch selected German")
T.eq(api.cache:read("options/language"), "sde", "language persists independently of saves")
run.loader.modOptions.kanto_gear.language = "fr"
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "language", value = "fr" })
T.eq(api.options:get("language"), "fr", "native language selection replaces touch choice")
T.eq(api.cache:read("options/language"), "sfr", "native language selection also persists")

T.check(display.cycleSetting(rowFor("clock_format"), 1),
  "touch selects the explicit 12-hour clock")
T.eq(api.options:get("clock_format"), "12", "touch clock format is applied")
T.eq(api.cache:read("options/clock_format"), "s12",
  "touch clock format persists independently of saves")
run.loader.modOptions.kanto_gear.clock_format = "24"
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "clock_format", value = "24" })
T.eq(api.options:get("clock_format"), "24",
  "native clock format replaces the touch choice")
T.eq(api.cache:read("options/clock_format"), "s24",
  "native clock format also persists")

-- Audit all dynamic metadata, not only the currently visible settings page.
local theme = upvalue(display.drawContents, "THEME")
for _, language in ipairs({ "de", "es", "fr", "it" }) do
  api.options:set("language", language)
  for _, row in ipairs(run.loader.optionSchemas.kanto_gear) do
    theme:translate(row.label)
    for _, choice in ipairs(row.choices or {}) do theme:translate(choice[1]) end
  end
  for _, category in ipairs(display.settingsCategories) do
    theme:translate(category.label)
    theme:translate(category.detail)
  end
  for _, surface in pairs(display.homeCatalog.surfaces) do
    if surface.widget ~= "tool" then theme:translate(surface.label) end
  end
  for _, app in ipairs(display.storeCatalog) do
    theme:translate(app.label)
    theme:translate(app.category)
    if app.reason then theme:translate(app.reason) end
    for _, line in ipairs(app.description) do theme:translate(line) end
  end
  local missing = theme.i18n:coverage(language)
  T.eq(#missing, 0, language .. " runtime metadata covered: " .. table.concat(missing, "; "))
end

api.options:set("language", "fr")
T.check(display.cycleSetting(rowFor("language"), 1), "touch selects Japanese after French")
T.eq(api.options:get("language"), "ja", "Japanese uses the standard locale code")
T.eq(api.cache:read("options/language"), "sja", "Japanese selection persists")
T.eq(theme:translate("JAPANESE"), "にほんご", "Japanese language label renders immediately")
T.eq(theme:translate("NOTES"), "ノート", "new Japanese translations render immediately")
T.eq(theme:translate("UNTRANSLATED TEST LABEL"), "UNTRANSLATED TEST LABEL", "unknown Japanese entries fall back to English")

T.eq(api.options:get("type_hints"), true, "old Enhanced choice starts with type hints")
T.check(api.options:set("info_level", "purist"), "discovery changes independently before restart")
run.release()
local restarted = loadWithoutNativeSetter(persistedCache)
restarted.loader.events:emit("game.ready", { game = gameFor(restarted) })
local restartedTheme = upvalue(runtime(restarted).drawContents, "THEME")
local restartedApi = upvalue(runtime(restarted).saveHome, "mod")
T.eq(restartedApi.options:get("ui_haptics"), true, "haptics survive a new mod instance")
T.eq(restartedApi.options:get("keyboard_layout"), "qwertz", "keyboard layout survives restarting")
T.eq(restartedApi.options:get("info_level"), "purist", "discovery choice survives restarting")
T.eq(restartedApi.options:get("type_hints"), false, "strict Vanilla disables battle hints across restart")
T.eq(restartedTheme.i18n:language(), "ja", "Japanese survives loading a new mod instance")
T.eq(restartedTheme:translate("JAPANESE"), "にほんご", "new instance immediately renders the saved language")
T.eq(restartedTheme:translate("NOTES"), "ノート", "new Japanese translations survive restarting")
T.eq(restartedTheme:translate("UNTRANSLATED TEST LABEL"), "UNTRANSLATED TEST LABEL", "English fallback survives restarting")
T.check(restartedApi.options:set("language", "de"), "Japanese can be switched back to German")
T.eq(restartedTheme:translate("JAPANESE"), "JAPANISCH", "language switch clears Japanese rendering")
T.check(restartedApi.options:set("language", "it"), "Italian can be selected in the native options")
T.eq(restartedTheme:translate("ABILITY"), "ABILITÀ", "Italian accents render immediately")
T.eq(restartedApi.cache:read("options/language"), "sit", "Italian selection is persisted")
restarted.release()
local italianRestart = loadWithoutNativeSetter(persistedCache)
italianRestart.loader.events:emit("game.ready", { game = gameFor(italianRestart) })
local italianDisplay = runtime(italianRestart)
local italianTheme = upvalue(italianDisplay.drawContents, "THEME")
T.eq(italianTheme.i18n:language(), "it", "Italian survives a new mod instance")
T.eq(italianTheme:translate("HP"), "PS", "restarted Italian UI uses the Italian catalog")
italianRestart.release()

for _, case in ipairs({
  { cache = { ["options/info_level"] = "senhanced", ["options/type_hints"] = "b0" },
      mode = "custom", hint = false, map = true },
  { cache = { ["options/profile"] = "spurist" }, mode = "purist", hint = false },
  { cache = { ["options/info_level"] = "slegacy", ["options/local_map"] = "senhanced",
      ["options/type_hints"] = "b1" }, mode = "spoiler", hint = true },
  { cache = { ["options/info_level"] = "slegacy", ["options/local_map"] = "b1" },
      mode = "purist", hint = false },
  { cache = { ["options/profile"] = "scustom", ["options/local_map"] = "senhanced" },
      mode = "spoiler", hint = true },
}) do
  local legacy = loadWithoutNativeSetter(case.cache)
  legacy.loader.events:emit("game.ready", { game = gameFor(legacy) })
  local migrated = upvalue(runtime(legacy).saveHome, "mod")
  T.eq(migrated.options:get("info_level"), case.mode, "old custom/purist mode has one documented replacement")
  T.eq(migrated.options:get("type_hints"), case.hint, "old helper preference survives migration independently")
  if case.map then T.eq(runtime(legacy).discoveryPolicy().area_map, true, "migration preserves the former Guide map") end
  if case.cache["options/local_map"] then
    T.eq(migrated.options:get("local_map"), true, "old map toggle no longer carries a hidden spoiler override")
  end
  legacy.release()
  local again = loadWithoutNativeSetter(case.cache)
  local reloaded = upvalue(runtime(again).saveHome, "mod")
  T.eq(reloaded.options:get("info_level"), case.mode, "migrated discovery survives normalizing the old map setting")
  T.eq(reloaded.options:get("type_hints"), case.hint, "independent battle preference survives restart")
  if case.map then T.eq(runtime(again).discoveryPolicy().area_map, true, "migrated Custom map survives restart") end
  again.release()
end

T.finish("Kanto Gear settings fallback")
