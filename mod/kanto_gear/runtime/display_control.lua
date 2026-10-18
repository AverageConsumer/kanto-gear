return function(
  Discovery, THEME, battleState, compat, currentBattleUIMode, customBattleLayout,
  dialogueChoice, displayRuntime, fullBottomBattleUI, hasDisplay, hgssRuntime, holdTextSpeed,
  mod, refreshBattle, refreshTheme, reloadSteps, render, screenContract,
  session, touchEvent
)
  local function resetSwapState()
    displayRuntime.notes:suspend()
    displayRuntime.perf:call("notes_flush", displayRuntime.notes.flush, displayRuntime.notes, true)
    session.displayReady = false
    session.primaryBottomRect = nil
    session.nextGameCapture = 0
    session.nextPresentAttempt = 0
    session.touchDown = nil
    session.textSpeedReleasePending = false
    holdTextSpeed(false)
    session.dirty = true
  end

  function displayRuntime.updatePhone()
    if session.active and THEME:displayMode(mod.options) == "phone" then
      displayRuntime.Phone = displayRuntime.Phone or assert(load(mod:read("phone/display.lua"),
        "@kanto_gear/phone/display.lua"))()
      if not displayRuntime.phone and not displayRuntime.phoneStatus then
        local ok, phone, err = pcall(displayRuntime.Phone.new, mod, love, nil, nil, nil, displayRuntime.perf)
        displayRuntime.phone = ok and phone or nil
        displayRuntime.phoneStatus = displayRuntime.phone
          or { error = tostring(ok and err or phone):sub(1, 100) }
        if not displayRuntime.phone then mod.log:warn("phone display: %s", displayRuntime.phoneStatus.error) end
      end
      if displayRuntime.phone then
        displayRuntime.phone:setGame(displayRuntime.sourceGame)
        displayRuntime.phone:poll()
        session.displayReady = not displayRuntime.gearModules.anyShown() and displayRuntime.phone:ready()
        if displayRuntime.phoneConnected ~= displayRuntime.phone:detected() then
          touchEvent("cancel,0,0", session.canvas:getWidth(), session.canvas:getHeight())
          resetSwapState()
          displayRuntime.phoneConnected = displayRuntime.phone:detected()
          displayRuntime.displayBridge.checkedAt = nil
        end
      end
    elseif displayRuntime.phoneStatus then
      if displayRuntime.phone then displayRuntime.phone:stop() end
      displayRuntime.phone, displayRuntime.phoneStatus, displayRuntime.phoneConnected = nil, nil, nil
      displayRuntime.nativePhoneOwner = nil
      resetSwapState()
    end
  end

  mod.hooks:wrap("core.update", function(next, updateGame, dt)
    displayRuntime.updatePhone()
    return next(updateGame, dt)
  end, 1000)

  mod.hooks:wrap("core.quit_to_launcher", function(next)
    if displayRuntime.phone then displayRuntime.phone:stop() end
    displayRuntime.phone, displayRuntime.phoneStatus, displayRuntime.phoneConnected = nil, nil, nil
    displayRuntime.nativePhoneOwner = nil
    resetSwapState()
    return next()
  end, 1000)

  mod.hooks:wrap("render.hud", function(next, hudGame, viewport)
    local result = next(hudGame, viewport)
    if displayRuntime.gearModules.anyShown() then return result end
    if session.active and THEME:displayMode(mod.options) == "phone" and displayRuntime.phoneStatus then
      local look = displayRuntime.phoneLook or {}
      displayRuntime.phoneLook = look
      -- The pairing card follows the Gear skin; non-Gear themes use the dark Pokégear look.
      look.skin = THEME.style == "hgss" and THEME.hgss.skinName or "pokegear"
      if THEME.style == "hgss" then look.dark = THEME.hgss.dark == true else look.dark = THEME.style ~= "modern_light" end
      look.font, look.small, look.large = THEME.hgssFont, THEME.hgssSmallFont, THEME.hgssLargeFont
      displayRuntime.Phone.drawStatus(displayRuntime.phoneStatus, render.G, viewport, look)
    end
    return result
  end, -1000)

  function displayRuntime.autoBattleSelection(raw, top)
    if top == raw then
      local phase = raw.phase
      return phase == "menu" or phase == "moves" or phase == "moveSelect"
        or phase == "mimicSelect" or phase == "choose-forget"
        or dialogueChoice() ~= nil
    end
    -- Only switch to screens Gear can actually operate. Unknown mod screens,
    -- battle messages and animations stay on the game view.
    if dialogueChoice() then return true end
    if top and (top.isTextBox or top.message and not top.qtyState) then return false end
    return not not (screenContract(top, "party")
      or screenContract(top, "bag")
      or (compat.isScreen(top, "summary") and compat.summary.supports(top, session.game))
      or screenContract(top, "naming")
      or displayRuntime.moveLearnScreen()
      or displayRuntime.fieldPpMoveScreen())
  end

  function displayRuntime.updateAutoBattleScreen()
    local auto, raw, wanted = displayRuntime.autoBattle
    local mode = THEME:displayMode(mod.options)
    if session.active and mod.options:get("auto_battle_screen") == true
        and (mode == "fullscreen" or mode == "combined")
        and currentBattleUIMode() ~= "info" then
      raw = battleState()
      if raw and THEME.supportedBattleUI(raw) and not raw.tutorial and not raw.demo then
        wanted = displayRuntime.autoBattleSelection(raw, session.game.stack:top()) == true
      else raw = nil end
    end
    if auto.raw == raw and auto.wanted == wanted then return end
    local previous = displayRuntime.gearPrimary()
    auto.raw, auto.wanted, auto.shown = raw, wanted, wanted
    if displayRuntime.gearPrimary() ~= previous then
      resetSwapState()
      -- Fetch the destination snapshot before showing its first frame.
      -- This runs only at view changes, not on every input tick.
      session.nextPoll = 0
      if displayRuntime.gearPrimary() then
        displayRuntime.perf:call("battle_snapshot", refreshBattle)
        session.nextPoll = love.timer.getTime() + 0.05
        hgssRuntime.animation = nil
        displayRuntime.motion.started, displayRuntime.motion.cached = nil, nil
      end
      displayRuntime.syncTouchGuard()
      displayRuntime.touchGuard.readyAt = love.timer.getTime() + displayRuntime.touchGuard.quiet
    end
  end

  mod.events:on("game.ready", function(payload)
    session.toolArmed = nil
    displayRuntime.clearExplorerSnapshot()
    displayRuntime.pss:close()
    displayRuntime.localSummary, displayRuntime.nativeSummary = nil, nil
    displayRuntime.touchChoice = nil
    if displayRuntime.gen3Pointer then
      displayRuntime.gen3Pointer:release(); displayRuntime.gen3Pointer = nil
    end
    if displayRuntime.gen3Presentation then
      displayRuntime.gen3Presentation:release(); displayRuntime.gen3Presentation = nil
    end
    if displayRuntime.nativeMap then displayRuntime.nativeMap:release(); displayRuntime.nativeMap = nil end
    if displayRuntime.gen3Map then displayRuntime.gen3Map:release(); displayRuntime.gen3Map = nil end
    if displayRuntime.gen3Region then displayRuntime.gen3Region:release(); displayRuntime.gen3Region = nil end
    displayRuntime.legacyRegion, displayRuntime.regionCursor = nil, {}
    session.game = payload.game
    if mod.options.bindGame then mod.options:bindGame(session.game, THEME.optionSchema) end
    session.discoveryPolicy = Discovery.resolve(function(key) return mod.options:get(key) end)
    displayRuntime.sourceGame = session.game
    if displayRuntime.phone then displayRuntime.phone:setGame(session.game) end
    -- Mod path [Gen 1/2]: g9-battle-sprites may provide front art; native Gen 3 uses its own source-aware sprite readers.
    local spriteProvider = session.game.generation ~= 3 and mod.find("g9-battle-sprites")
    local frontArt = spriteProvider and spriteProvider.exports and spriteProvider.exports.frontArt
    displayRuntime.frontArt = type(frontArt) == "function" and frontArt or nil
    displayRuntime.frontArtRetryAt = nil
    displayRuntime.gen3 = nil
    displayRuntime.bindBattleInput(session.game)
    displayRuntime.gen3Field = nil
    displayRuntime.gen3Progress = nil
    displayRuntime.gen3Ui = nil
    displayRuntime.gen3PollAt = nil
    displayRuntime.gen3BoundSession = nil
    -- Game path [Gen 3]: adapt the native session/global layers to shared views while retaining the real host game for commands and storage.
    if session.game.generation == 3 then
      local function loadAdapter(name)
        local path = "adapters/gen3/" .. name .. ".lua"
        return assert(load(mod:read(path), "@kanto_gear/" .. path))()(function(name) return mod:read(name) end)
      end
      displayRuntime.gen3Pointer = assert(load(mod:read("adapters/gen3/pointer.lua"),
        "@kanto_gear/adapters/gen3/pointer.lua"))().new(session.game, function(action, x, y)
        return displayRuntime.primaryTouch(action, x, y)
      end)
      displayRuntime.gen3 = loadAdapter("init").new(session.game)
      displayRuntime.gen3Field = assert(load(mod:read("adapters/gen3/field.lua"), "@kanto_gear/adapters/gen3/field.lua"))().new(displayRuntime.gen3, mod.world)
      displayRuntime.gen3Progress = loadAdapter("progress").new(displayRuntime.gen3)
      displayRuntime.gen3Ui = loadAdapter("ui").new(displayRuntime.gen3, THEME.hgss, displayRuntime.ChoicePage, displayRuntime.NamingPage, displayRuntime.StoragePage, displayRuntime.ItemPage, displayRuntime.MovePage,
        function() return mod.options:get("keyboard_layout") end, function(view, key)
          if view.party then
            return displayRuntime.PartyPage.direction(view.index, #view.items - 1, key, #view.items)
          end
          return displayRuntime.StartMenu.direction(view, key)
        end)
      session.game = displayRuntime.gen3:gameView()
      displayRuntime.gen3Presentation = assert(load(mod:read("adapters/gen3/presentation.lua"),
        "@kanto_gear/adapters/gen3/presentation.lua"))().new(function(kind)
        local adapter = displayRuntime.gen3
        local raw = adapter and adapter:battleState()
        if not (customBattleLayout() and session.active and session.displayReady and hasDisplay()
            and raw and session.battle and not session.battle.nativeUnsupported) then return false end
        adapter.syncScreens()
        -- Unsupported windows retain every original control. Only take the
        -- doubles HUD when the snapshot contains every battlefield slot.
        local top = session.game.stack:top()
        local menu = displayRuntime.gen3Ui:list(session.battle)
        local summary = compat.isScreen(top, "summary") and compat.summary.supports(top, session.game)
        if top ~= raw and not (top and top.isTextBox) and not menu and not summary then return false end
        if displayRuntime.gen3Ui.Stats.isOpen() and not (menu and menu.nativeStats) then return false end
        if kind:sub(1, 7) == "screen:" then
          local layer = displayRuntime.gen3Ui.Stack.top()
          return layer and layer.id == kind:sub(8) and (menu ~= nil or summary ~= nil) or false
        end
        if kind == "partyNavigation" or kind == "menuNavigation" then
          return not session.battle.nativeInputLocked and THEME.style == "hgss" and menu and menu.valid() or false
        end
        if kind == "navigation" or kind == "heroNavigation" then
          return (fullBottomBattleUI() or THEME.style == "hgss")
            and (kind ~= "heroNavigation" or currentBattleUIMode() == "gear")
            and top == raw and session.battle.prompt == "menu"
            and not raw.battle.safari and not adapter.Message.isOpen()
        end
        if kind == "hud" then
          return fullBottomBattleUI() and (not raw.battle.double
              or session.battle.battlers and #session.battle.battlers == 4)
        end
        return true
      end, hgssRuntime.rootDirection, displayRuntime.PartyPage.direction, function(native, input)
        return displayRuntime.gen3Ui:navigate(native, session.battle, input)
      end)
    end
    displayRuntime.homeCatalog.packages.achievements.available = true
    displayRuntime.storeById.achievements.available = true
    -- Game path [Gen 1]: the Route 5 Day-Care boards one Pokemon and makes no eggs.
    local gen1 = not displayRuntime.gen3 and not (session.game.save and session.game.save.generation == 2)
    displayRuntime.homeCatalog.surfaces.daycare_small_widget.hidden = gen1
    if displayRuntime.applyCalendarSupport then displayRuntime.applyCalendarSupport() end
    -- third-party store modules decide their availability for this game
    displayRuntime.gearModules.applyAvailability({
      edition = require("src.core.GameVersion").get(),
      generation = displayRuntime.gen3 and 3 or compat.isGen2() and 2 or 1,
      gen3 = displayRuntime.gen3 ~= nil,
    })
    displayRuntime.autoBattle = {}
    displayRuntime.touchGuard.key, displayRuntime.touchGuard.pending = nil, false
    displayRuntime.touchGuard.readyAt = 0
    displayRuntime.levelUp = displayRuntime.LevelUp.new()
    displayRuntime.levelUp:scan(session.game.save)
    displayRuntime.notes:bind(displayRuntime.sourceGame or session.game, mod.storage)
    if displayRuntime.gen3 then
      displayRuntime.gen3:syncStorageIdentity()
      displayRuntime.gen3BoundSession = displayRuntime.gen3.session
    end
    displayRuntime.recentItem:bind(session.game.save)
    displayRuntime.resetAchievements()
    THEME.storedTheme = mod.options:get("theme_v3")
    session.spriteCache.__badges = nil
    session.spriteCache.__gen2Badges = nil
    session.spriteCache.__caughtBall = nil
    displayRuntime.pokedex.data = nil
    displayRuntime.loadHome()
    refreshTheme(true)
    reloadSteps()
    local player = session.game.save and session.game.save.player
    session.mapId = player and player.map
    if not session.mapId and mod.world and mod.world.current then
      local position = mod.world:current()
      session.mapId = position and position.mapId
    end
    local voxel = mod.find("DRAMATIC_SHAPE")
    if voxel and voxel.exports.isLoading then
      session.externalLoading = voxel.exports.isLoading() == true
    end
    session.active, session.dirty, displayRuntime.lastStepAt = true, true, nil
    mod.log:info("ready")
  end)

  return resetSwapState
end
