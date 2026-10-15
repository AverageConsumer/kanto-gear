return function(
  HEIGHT, PaletteFX, THEME, WIDTH, bottomOwnsBattleUI, compat,
  customBattleLayout, displayRuntime, hgssRuntime, inlineDisplay, inverted, mod,
  moveGridLayout, render, session, usePalette
)
  function displayRuntime.clearExplorerSnapshot()
    local preview = displayRuntime.explorer.locationPreview
    if preview and preview.locationImage then preview.locationImage:release() end
    if preview and preview.locationRenderer then preview.locationRenderer:release() end
    displayRuntime.explorer.locationPreview, displayRuntime.explorer.entrances = nil, nil
    local snapshot = displayRuntime.explorer.mapSnapshot
    if not snapshot then return end
    if snapshot.canvas then snapshot.canvas:release() end
    displayRuntime.explorer.mapSnapshot = nil
    displayRuntime.explorer.renderModel = nil
  end

  local function invalidateLocalMap(preserveSnapshot)
    if not preserveSnapshot then displayRuntime.clearExplorerSnapshot() end
    if displayRuntime.nativeMap then displayRuntime.nativeMap:release() end
    if session.localMapImage and session.localMapImage.release then session.localMapImage:release() end
    session.localMap, session.localMapImage = nil, nil
    displayRuntime.explorer.renderModel = nil
    displayRuntime.mapRefresh.homeModel = nil
    displayRuntime.home.widgetCache = nil
    displayRuntime.explorer.selected, displayRuntime.explorer.page,
      displayRuntime.explorer.data, displayRuntime.explorer.mapFull,
      displayRuntime.explorer.mapZoom = nil, 1, nil, false, 1
  end

  displayRuntime.displayBridge = {}
  local function hasDisplay()
    if THEME:displayMode(mod.options) == "phone" then
      return displayRuntime.phone ~= nil and displayRuntime.phone:detected()
    end
    if inlineDisplay() then
      return THEME:displayMode(mod.options) ~= "fullscreen"
        or displayRuntime.gearPrimary()
    end
    if not (session.companion and session.companion.detected) then return false end
    local state, now = displayRuntime.displayBridge, love.timer.getTime()
    -- Discovery crosses JNI and reads Android system settings. Share one
    -- result across input/draw hooks; this never throttles image submissions.
    if state.owner ~= session.companion or state.probe ~= session.companion.detected
        or not state.checkedAt or now < state.checkedAt or now >= state.checkAt then
      state.owner, state.probe = session.companion, session.companion.detected
      state.detected = not not displayRuntime.perf:call("display_detect", session.companion.detected)
      state.checkedAt, state.checkAt = now, now + 0.05
    end
    return state.detected
  end

  function displayRuntime.syncDisplayBridge(now, inline)
    if not (session.companion and session.companion.setEnabled) then return end
    local state, enabled = displayRuntime.displayBridge, session.active and not inline
    if state.enabledOwner ~= session.companion or state.enable ~= session.companion.setEnabled
        or state.enabled ~= enabled
        or enabled and (state.detected == false or not session.displayReady)
          and now >= (state.retryAt or 0) then
      -- Android posts UI-thread work for every enable call, even unchanged ones.
      -- Host path [all games]: older or temporarily unavailable companion presentations need a bounded retry after enabling the display.
      -- Keep a slow recovery attempt for older hosts/missing presentations.
      displayRuntime.perf:call("display_enable", session.companion.setEnabled, enabled)
      state.enabledOwner, state.enable, state.enabled = session.companion, session.companion.setEnabled, enabled
      state.retryAt, state.checkedAt = now + 1, nil
    end
  end

  -- Game path [Gen 3]: the companion uses its native move grid; Gen 1/2 also consult native wideLayout and bottom-screen ownership.
  local function companionMoveGrid(state)
    return displayRuntime.gen3 ~= nil or moveGridLayout(state, bottomOwnsBattleUI(
      customBattleLayout(), session.active, hasDisplay(), session.displayReady, state, session.battle))
  end

  local function romThemePalette(name)
    local palettes = session.game and session.game.data and session.game.data.palettes
    return palettes and ((palettes.cgbBase and palettes.cgbBase[name])
      or (palettes.palettes and palettes.palettes[name]))
  end

  local function themePalette(theme)
    if theme == "match" then
      theme = ({
        ogred = "version", gbc = "sgb", redpp = "advanced",
        og = "og", og_inv = "og_inv", gbc_inv = "sgb_inv",
        classic = "kanto",
      })[PaletteFX.mode] or "kanto"
    end
    if theme == "hgss" or theme == "hgss_dark" or theme == "hgss_auto"
        or theme == "cgear" or theme == "cgear_dark" or theme == "cgear_auto" then
      return THEME.hgss.palette
    end
    if theme == "og" then return PaletteFX.GRAYS end
    if theme == "modern_light" then return THEME.light end
    if theme == "modern_dark" then return THEME.dark end
    if theme == "og_inv" then return inverted(PaletteFX.GRAYS) end
    if theme == "version" then return PaletteFX.ogBg() end
    if theme == "sgb" or theme == "sgb_inv" then
      local palette = romThemePalette("MEWMON")
      return theme == "sgb_inv" and palette and inverted(palette) or palette
    end
    if theme == "advanced" then
      local palettes = session.game and session.game.data and session.game.data.palettes
      local yellow = palettes and palettes.cgbBase
        and palettes.cgbBase.MEWMON
      local pack = PaletteFX.gbcPack()
      return yellow or (pack and pack.palettes and pack.palettes.MEWMON)
    end
    return THEME.classic
  end

  local function refreshTheme(force)
    if THEME.translationFonts:bind(session.game and session.game.data and session.game.data.font and session.game.data.font.ttf) then
      session.dirty = true
    end
    local theme = mod.options:get("theme_v3") or "hgss"
    local auto = theme == "hgss_auto" or theme == "cgear_auto"
    local autoDark = auto and compat.autoThemeDark(session.game,
      mod.options:get("clock_source"), os.time())
    local key = theme .. (theme == "match" and (":" .. PaletteFX.mode) or "")
      .. (auto and (autoDark and ":dark" or ":light") or "")
    if not force and key == session.themeKey then return end
    local wasHgss = THEME.style == "hgss"
    local cgear = theme == "cgear" or theme == "cgear_dark"
      or theme == "cgear_auto"
    local hgss = theme == "hgss" or theme == "hgss_dark"
      or theme == "hgss_auto" or cgear
    THEME.style = hgss and "hgss"
      or theme == "modern_light" and "modern_light"
      or theme == "modern_dark" and "modern_dark" or "classic"
    if hgss and not wasHgss then
      session.page, displayRuntime.home.activeApp = "HOME", nil
    elseif not hgss and (session.page == "HOME" or session.page == "STORE"
        or session.page == "STEPS" or session.page == "POKEDEX" or session.page == "BAG"
        or session.page == "ACHIEVEMENTS" or session.page == "NOTES" or session.page == "PSS"
        or session.page == "DAYCARE" or session.page == "CALENDAR") then
      session.page = "MAP"
    elseif hgss and (session.page == "GUIDE" or session.page == "AREA") then
      session.page = "LOCAL"
    end
    THEME.hgss.skinName = cgear and "cgear" or "pokegear"
    THEME.hgss:setVariant(theme == "hgss_dark" or theme == "cgear_dark" or autoDark)
    THEME.hgss.motionEnabled = displayRuntime.motionEnabled()
    if not hgss then hgssRuntime.animation = nil end
    local scale = THEME.style == "hgss" and THEME.hgssScale or 1
    local width, height = WIDTH * scale, HEIGHT * scale
    -- Never repaint a canvas while Android may still be reading it for the
    -- physical second screen. A fresh surface also recovers an in-app restart
    -- from a stalled readback without requiring an application force-close.
    session.canvas = render.G.newCanvas(width, height, { dpiscale = 1 })
    session.canvas:setFilter("nearest", "nearest")
    if displayRuntime.motion then
      displayRuntime.motion.key, displayRuntime.motion.started = nil, nil
      displayRuntime.motion.navigation, displayRuntime.motion.cached = nil, nil
    end
    session.readbackPending, session.displayReady = false, false
    usePalette(themePalette(theme), hgss and THEME.hgss.colors.partyBg)
    invalidateLocalMap(true)
    session.themeKey, session.dirty = key, true
  end

  return companionMoveGrid, hasDisplay, invalidateLocalMap, refreshTheme
end
