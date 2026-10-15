return function(
  THEME, mod
)
  THEME:installOptionFallback(mod)
  local Discovery = assert(load(mod:read("core/discovery.lua"), "@kanto_gear/core/discovery.lua"))()
  local SettingsInfo = assert(load(mod:read("core/settings_info.lua"), "@kanto_gear/core/settings_info.lua"))()

  THEME.i18n = assert(load(mod:read("i18n/init.lua"),
    "@kanto_gear/i18n/init.lua"))().new(function(language)
    local body = assert(mod:read("i18n/catalogs/" .. language .. ".lua"),
      "missing built-in language: " .. language)
    return assert(load(body, "@kanto_gear/i18n/catalogs/" .. language .. ".lua"))()
  end, function() return mod.options:get("language") or "en" end)

  local RADAR_FRAMES = 16
  local function compactSteps(value)
    if value < 100000 then return tostring(value) end
    if value < 10000000 then
      return THEME:format("%dK", math.floor(value / 1000))
    end
    return THEME:format("%dM", math.floor(value / 1000000))
  end
  assert(compactSteps(99999) == "99999"
    and compactSteps(100000) == "100K"
    and compactSteps(10000000) == "10M", "compact step count")

  THEME.storedTheme = mod.options:get("theme_v3")
  local infoDefault = mod.options:get("info_level")
  -- Host path [all games]: preserve disclosure intent from older profile/info_level/local_map settings rather than resetting saved preferences.
  local migrateInfo = infoDefault == "legacy" or infoDefault == "vanilla"
    or infoDefault == nil and mod.options:get("profile") == "custom"
  if infoDefault == nil then
    local legacyProfile = mod.options:get("profile")
    infoDefault = legacyProfile == "custom" and "legacy"
      or legacyProfile == "purist" and "purist" or "enhanced"
  end
  infoDefault = Discovery.mode(infoDefault, mod.options:get("local_map"))
  if infoDefault == "vanilla" then infoDefault = "purist" end
  local infoChoices = {
    { "VANILLA", "purist" }, { "GUIDE", "enhanced" },
    { "EVERYTHING", "spoiler" }, { "CUSTOM", "custom" },
  }
  if mod.options:get("info_level") == "custom" then infoDefault = "custom" end
  Discovery.initialPolicy = Discovery.resolve(function(key)
    if key == "info_level" then return infoDefault end
    return mod.options:get(key)
  end)
  -- Older releases stored battle helpers separately. Preserve explicit differences
  -- as Custom instead of discarding a user's choices during the upgrade.
  Discovery.migrateHelpers = false
  Discovery.previousPreset = mod.options:get("info_level")
  if mod.options:get("reveal_area_map") == nil and infoDefault ~= "custom" then
    for _, key in ipairs({ "type_hints", "move_details", "catch_odds" }) do
      local saved = mod.options:get(key)
      if saved ~= nil and saved ~= Discovery.initialPolicy[key] then Discovery.migrateHelpers = true end
    end
    if Discovery.migrateHelpers then
      for _, key in ipairs({ "type_hints", "move_details", "catch_odds" }) do
        local saved = mod.options:get(key)
        if saved ~= nil then Discovery.initialPolicy[key] = saved == true end
      end
      infoDefault, migrateInfo = "custom", true
    end
  end
  for _, row in ipairs(Discovery.options) do SettingsInfo.help[Discovery.key(row[1])] = row[5] end
  SettingsInfo.help.discovery_section = "Choose an information category to customize. Changes apply across Gear."

  THEME.displayModeDefault, THEME.combinedLayoutDefault = THEME:displayDefaults(
    function(key) return mod.options:get(key) end)

  THEME.optionSchema = Discovery.define({
    { key = "language", label = "LANGUAGE", type = "choice",
      default = "en", choices = {
        { "ENGLISH", "en" }, { "DEUTSCH", "de" },
        { "ESPANOL", "es" }, { "FRANCAIS", "fr" }, { "JAPANESE", "ja" },
        { "ITALIANO", "it" },
      } },
    { key = "theme_v3", label = "THEME", type = "choice", default = "hgss",
      choices = {
        { "KANTO GREEN", "kanto" }, { "MATCH GAME", "match" },
        { "POKEGEAR LIGHT", "hgss" }, { "POKEGEAR DARK", "hgss_dark" },
        { "POKEGEAR AUTO", "hgss_auto" },
        { "C-GEAR LIGHT", "cgear" }, { "C-GEAR DARK", "cgear_dark" },
        { "C-GEAR AUTO", "cgear_auto" },
        { "MODERN LIGHT", "modern_light" },
        { "MODERN DARK", "modern_dark" },
        { "OG", "og" }, { "OG INVERTED", "og_inv" },
        { "SGB", "sgb" }, { "ADVANCED", "advanced" },
        { "VERSION COLOR", "version" },
      } },
    { key = "clock_source", label = "CLOCK SOURCE", type = "choice",
      default = "game", choices = {
        { "GAME CLOCK", "game" }, { "DEVICE", "system" },
      } },
    { key = "clock_format", label = "CLOCK FORMAT", type = "choice",
      default = "system", choices = {
        { "SYSTEM", "system" }, { "12 HOUR", "12" }, { "24 HOUR", "24" },
      } },
    { key = "ui_motion", label = "TRANSITIONS",
      type = "toggle", default = true, visible_if = {
        key = "theme_v3", one_of = { "hgss", "hgss_dark", "hgss_auto", "cgear", "cgear_dark", "cgear_auto" },
      } },
    { key = "map_motion", label = "PRESENTATION", type = "choice",
      default = "quality", choices = {
        { "QUALITY", "quality" }, { "PERFORMANCE", "performance" },
      }, visible_if = {
        key = "theme_v3", one_of = { "hgss", "hgss_dark", "hgss_auto", "cgear", "cgear_dark", "cgear_auto" },
      } },
    { key = "info_level", label = "DISCOVERY", type = "choice",
      default = infoDefault, reset_default = "enhanced", choices = infoChoices,
      migrate_from = Discovery.migrateHelpers and Discovery.previousPreset or nil },
    { key = "local_map", label = "AREA MAP",
      type = "choice", default = false, choices = {
        { "OFF", false }, { "MAP", true },
      }, visible_if = {
        key = "theme_v3", not_one_of = { "hgss", "hgss_dark", "hgss_auto", "cgear", "cgear_dark", "cgear_auto" },
      } },
    { key = "display_mode", label = "DISPLAY MODE", type = "choice",
      default = THEME.displayModeDefault, reset_default = "separate", choices = {
        { "FULLSCREEN SWAP", "fullscreen" },
        { "COMBINED SCREEN", "combined" },
        { "SEPARATE SCREENS", "separate" },
        { "PHONE / BROWSER", "phone" },
      } },
    { key = "fullscreen_start", label = "START SCREEN", type = "choice",
      default = "game", visible_if = {
        key = "display_mode", equals = "fullscreen",
      }, choices = {
        { "GAME", "game" }, { "GEAR", "gear" },
      } },
    { key = "auto_battle_screen", label = "AUTO BATTLE SCREEN",
      type = "toggle", default = false, visible_if = {
        key = "display_mode", one_of = { "fullscreen", "combined" },
      } },
    { key = "combined_layout", label = "LAYOUT", type = "choice",
      default = THEME.combinedLayoutDefault, reset_default = "auto", visible_if = {
        key = "display_mode", equals = "combined",
      }, choices = {
        { "AUTO", "auto" }, { "STACKED", "stacked" },
        { "SIDE BY SIDE", "side" }, { "OVERLAY", "overlay" },
      } },
    { key = "combined_primary", label = "PRIMARY VIEW", type = "choice",
      default = "game", visible_if = {
        key = "display_mode", equals = "combined",
      }, choices = {
        { "GAME", "game" }, { "GEAR", "gear" },
      } },
    { key = "secondary_size", label = "SECONDARY SIZE", type = "choice",
      default = "auto", visible_if = {
        key = "display_mode", equals = "combined",
      }, choices = {
        { "AUTO", "auto" }, { "20%", 20 }, { "25%", 25 },
        { "30%", 30 }, { "35%", 35 }, { "40%", 40 },
        { "45%", 45 }, { "50%", 50 }, { "55%", 55 },
        { "60%", 60 }, { "65%", 65 }, { "70%", 70 },
        { "75%", 75 }, { "80%", 80 },
      } },
    { key = "bottom_safe_area", label = "BOTTOM SAFE AREA", type = "choice",
      default = 0, visible_if = {
        key = "display_mode", equals = "combined",
      }, choices = {
        { "OFF", 0 }, { "10%", 10 }, { "15%", 15 }, { "20%", 20 },
        { "25%", 25 }, { "30%", 30 }, { "35%", 35 }, { "40%", 40 },
      } },
    { key = "overlay_corner", label = "OVERLAY CORNER", type = "choice",
      default = "bottom_right", visible_if = {
        key = "display_mode", equals = "combined",
      }, choices = {
        { "TOP LEFT", "top_left" }, { "TOP RIGHT", "top_right" },
        { "BOTTOM LEFT", "bottom_left" },
        { "BOTTOM RIGHT", "bottom_right" },
      } },
    { key = "overlay_button", label = "OVERLAY BUTTON", type = "choice",
      default = "off", visible_if = {
        key = "display_mode", equals = "combined",
      }, choices = {
        { "OFF", "off" }, { "R3", "rightstick" },
        { "L3", "leftstick" }, { "F7", "f7" },
      } },
    { key = "display_target", label = "GEAR OUTPUT", type = "choice",
      default = "auto", choices = {
        { "AUTO", "auto" }, { "MAIN SCREEN", "handheld" },
        { "SECOND SCREEN", "secondary" },
      }, visible_if = {
        key = "display_mode", equals = "separate",
      } },
    { key = "screen_swap", label = "QUICK SWAP (Y)",
      type = "toggle", default = false, visible_if = {
        key = "display_mode", one_of = { "separate", "combined" },
      } },
    { key = "battle_view", label = "BATTLE VIEW", type = "choice",
      default = "standard", choices = {
        { "COMPANION", "standard" }, { "INFO", "info" },
        { "GEAR", "gear" }, { "FULL GEAR", "full" },
      } },
    { key = "caught_icon", label = "CAUGHT ICON",
      type = "toggle", default = true },
    { key = "keyboard_layout", label = "KEYBOARD", type = "choice",
      default = "qwerty", choices = {
        { "QWERTY", "qwerty" }, { "QWERTZ", "qwertz" },
      } },
    { key = "ui_haptics", label = "GEAR HAPTICS",
      type = "toggle", default = false, visible_if = {
        key = "theme_v3", one_of = { "hgss", "hgss_dark", "hgss_auto", "cgear", "cgear_dark", "cgear_auto" },
      } },
  }, Discovery.initialPolicy)

  -- Host path [all games]: stock option menus lack Gear visibility/reset descriptors; publish a compatible copy while preserving the richer Gear schema.
  -- Recomp's stock menu only understands equals/not_equals visibility and
  -- resets to default (not reset_default). Give it a compatible copy; keep
  -- the richer contextual schema for Gear's own Options app.
  do
    local nativeSchema = {}
    for _, row in ipairs(THEME.optionSchema) do
      local native = {}
      for key, value in pairs(row) do native[key] = value end
      native.description = SettingsInfo.help[row.key]
      if row.reset_default ~= nil then native.default = row.reset_default end
      if native.visible_if and (native.visible_if.one_of or native.visible_if.not_one_of) then
        native.visible_if = nil
      end
      if row.key == "display_mode" then
        table.insert(nativeSchema, 1, native) -- recovery must not require a phone
      else
        nativeSchema[#nativeSchema + 1] = native
      end
    end
    mod.options:define(nativeSchema)
  end

  for _, row in ipairs(THEME.optionSchema) do
    row.description = SettingsInfo.help[row.key]
    if mod.options.set and row.reset_default ~= nil and row.default ~= row.reset_default then
      -- Keep migrated/current values separate from the native reset defaults.
      -- Discovery's preset controls the information toggles independently.
      mod.options:set(row.key, row.default)
    end
  end
  if migrateInfo and mod.options.set then
    if Discovery.migrateHelpers then
      for _, row in ipairs(Discovery.options) do
        mod.options:set(Discovery.key(row[1]), Discovery.initialPolicy[row[1]])
      end
    end
    mod.options:set("info_level", infoDefault)
  end
  -- Host path [all games]: migrate the former enhanced local-map value to the current boolean setting without losing the chosen discovery profile.
  if mod.options:get("local_map") == "enhanced" and mod.options.set then
    mod.options:set("local_map", true)
  end

  -- Mod path [Gen 1 + gen1_modern_ui]: insert the Gear options entry into that external start menu only when its provider is present.
  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" or not mod.find("gen1_modern_ui") then return out end
    return mod.ui.insertBefore(out, "MODS", {
      id = mod.id .. ".options",
      label = "KANTO GEAR",
      onSelect = function()
        local manager = mod.ui.push(game, "ManagerState")
        local own = manager.byId and manager.byId[mod.id]
        if own and manager.openOptions then manager:openOptions(own) end
      end,
    })
  end)

  return Discovery, RADAR_FRAMES, SettingsInfo, compactSteps
end
