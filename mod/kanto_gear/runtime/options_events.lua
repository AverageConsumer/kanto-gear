return function(
  Area, Discovery, THEME, assist, compat, displayRuntime,
  hgssRuntime, invalidateLocalMap, localMapMode, mod, refreshTheme, reloadSteps,
  resetSwapState, session
)
  -- Game path [Gen 3 / FRLG]: save.created precedes field entry, and FRLG Continue may replay Quest Log before the session is ready for tool storage.
  function displayRuntime.reloadSavedUi()
    if displayRuntime.resetNotices then displayRuntime.resetNotices() end
    if displayRuntime.gen3 then displayRuntime.gen3:clearEncounterPreviews() end
    session.toolArmed = nil
    -- Gen 3's created event precedes _enterField; Continue can first replay
    -- the quest log. Bind tool storage only once the new field/save is live.
    if displayRuntime.gen3 and displayRuntime.sourceGame.phase ~= "field" then return end
    if displayRuntime.gen3 then
      displayRuntime.gen3:refresh()
      displayRuntime.gen3.syncScreens()
    end
    Area.pickupData = nil
    invalidateLocalMap()
    session.dirty = true
    displayRuntime.levelUp = displayRuntime.LevelUp.new()
    displayRuntime.levelUp:scan(session.game and session.game.save)
    displayRuntime.home.widgetCache = nil
    displayRuntime.notes:bind(displayRuntime.sourceGame or session.game, mod.storage)
    if displayRuntime.gen3 then
      displayRuntime.gen3:syncStorageIdentity()
      displayRuntime.gen3BoundSession = displayRuntime.gen3.session
    end
    displayRuntime.bindShinyHunt()
    if displayRuntime.bindMoments then displayRuntime.bindMoments() end
    displayRuntime.recentItem:bind(session.game.save)
    displayRuntime.resetAchievements()
    displayRuntime.pokedex.data = nil
    reloadSteps()
    displayRuntime.loadHome()
  end
  mod.events:on("save.created", function(payload)
    if displayRuntime.gen3 and payload and payload.save then
      displayRuntime.gen3:newPlaythrough(payload.save)
      if payload.save ~= displayRuntime.sourceGame.session then return end
    end
    displayRuntime.reloadSavedUi()
  end)
  mod.events:on("save.loaded", displayRuntime.reloadSavedUi)

  mod.events:on("map.entered", function(payload)
    if displayRuntime.gen3 then displayRuntime.gen3:clearEncounterPreviews() end
    session.toolArmed = nil
    if displayRuntime.gen3 and displayRuntime.gen3BoundSession ~= displayRuntime.sourceGame.session then
      displayRuntime.reloadSavedUi()
    end
    session.mapId, session.pendingFly, session.pendingAction, session.fieldChoice, session.dirty =
      payload.mapId, nil, nil, nil, true
    displayRuntime.lastStepAt = nil
    invalidateLocalMap()
    displayRuntime.pokedex.data = nil
    session.guidePage, displayRuntime.guideDetail, session.areaPage = 1, nil, 1
    session.radarOpen = false
    local stamps = displayRuntime.achievements
    stamps.currentData, stamps.contextDirty = nil, true
    local visited = mod.save:get("achievement_visits", {})
    if type(visited) ~= "table" then visited = {} end
    if type(session.mapId) == "string" and not visited[session.mapId] then
      visited[session.mapId] = true
      mod.save:set("achievement_visits", visited)
    end
  end)

  mod.events:on("pokemon.caught", function()
    displayRuntime.home.widgetCache = nil
    displayRuntime.pokedex.data = nil
    session.dirty = true
  end)

  mod.events:on("mod.DRAMATIC_SHAPE.loading_changed", function(payload)
    session.externalLoading = payload and payload.loading == true
    session.dirty = true
  end)

  function displayRuntime.optionsChanged(payload)
    if payload and payload.mod == "kanto_gear" then
      if Discovery.updating then return end
      local discoveryChanged = Discovery.changed(payload.key, payload.value)
      displayRuntime.home.widgetCache = nil
      if payload.key == "map_motion" then displayRuntime.mapRefresh.nextAt = 0 end
      if payload.key == "ui_haptics" and payload.value == true then
        displayRuntime.haptic()
      end
      if payload.key == "theme_v3" then
        THEME.storedTheme = payload.value
        refreshTheme(true)
        if session.page == "SETTINGS" and THEME.style ~= "hgss" then
          session.page, displayRuntime.home.activeApp = "MAP", nil
        end
      end
      if payload.key == "ui_motion" or payload.key == "map_motion" then
        hgssRuntime.animation = nil
        displayRuntime.motion.key, displayRuntime.motion.started, displayRuntime.motion.cached = nil, nil, nil
        if THEME.hgss then
          THEME.hgss.motionEnabled = displayRuntime.motionEnabled()
        end
      end
      if payload.key == "display_mode"
          or payload.key == "fullscreen_start"
          or payload.key == "combined_layout"
          or payload.key == "combined_primary"
          or payload.key == "secondary_size"
          or payload.key == "bottom_safe_area"
          or payload.key == "overlay_corner"
          or payload.key == "overlay_button"
          or payload.key == "display_target"
          or (payload.key == "screen_swap"
            and mod.options:get("screen_swap") ~= true) then
        displayRuntime.swapped = nil
        displayRuntime.overlayHidden = false
        resetSwapState()
      end
      if not assist("move_details") then session.moveInfo = nil end
      if payload.key == "battle_view" then
        session.battleInfoDetail, displayRuntime.enemyInfoSelection, session.moveInfo = nil, nil, nil
        hgssRuntime.animation = nil
        displayRuntime.motion.key, displayRuntime.motion.started = nil, nil
        session.nextPoll = 0
      end
      if payload.key == "battle_view" or payload.key == "auto_battle_screen"
          or payload.key == "display_mode" or payload.key == "fullscreen_start" then
        displayRuntime.updateAutoBattleScreen()
      end
      if session.page == "GUIDE" and not assist("guide") then
        session.page, displayRuntime.guideDetail = "MAP", nil
      end
      if session.page == "AREA" and not assist("area") then session.page = "MAP" end
      if session.page == "LOCAL" and THEME.style == "hgss"
          and (displayRuntime.explorer.view == "wild" and not assist("guide")
            or (displayRuntime.explorer.view == "items"
                or displayRuntime.explorer.view == "trainers")
              and not assist("area")) then
        displayRuntime.explorer.view, displayRuntime.explorer.selected = nil, nil
      end
      if session.page == "LOCAL" and THEME.style ~= "hgss"
          and localMapMode(mod.options:get("local_map")) == "off" then
        session.page, displayRuntime.explorer.view,
          displayRuntime.explorer.selected = "MAP", nil, nil
      end
      if not assist("item_radar") then session.radarOpen = false end
      displayRuntime.explorer.data = nil
      if discoveryChanged then
        displayRuntime.pokedex.data, displayRuntime.pokedex.habitatPlan = nil, nil
        displayRuntime.pokedex.view = "index"
        displayRuntime.explorer.selected, displayRuntime.explorer.scanRevealed = nil, {}
        displayRuntime.achievements.selected, displayRuntime.achievements.location = nil, nil
        displayRuntime.achievements.view = "album"
        displayRuntime.guideDetail = nil
        session.radarOpen = false
        displayRuntime.achievements.presentSource = nil
        displayRuntime.explorer.renderModel, displayRuntime.mapRefresh.homeModel = nil, nil
        displayRuntime.mapRefresh.paintedPage = nil
        session.battleInfoDetail = nil
        if displayRuntime.localSummary then compat.summary.configure(displayRuntime.localSummary, session.discoveryPolicy) end
      end
      session.dirty = true
    end
  end
  mod.events:on("mod.options_changed", function(payload)
    if displayRuntime.gen3 then displayRuntime.gen3:clearEncounterPreviews() end
    if payload and payload.mod == "kanto_gear"
        and payload.value ~= nil and mod.options.syncExternal then
      mod.options:syncExternal(payload.key, payload.value)
    end
    displayRuntime.optionsChanged(payload)
  end)
  mod.events:on("mod.kanto_gear.options_changed", displayRuntime.optionsChanged)

  -- Input.step polls controllers after the mod input hook. Remap after that
  -- poll, before queued edges become pressed buttons, so every device agrees.
end
