return function(THEME, compat, displayRuntime, hasDisplay, mod, screenState, session)
  function displayRuntime.applyPokegearSupport()
    local supported = compat.isGen2() and not displayRuntime.gen3
    displayRuntime.storeById.pokegear.hidden = not supported
    displayRuntime.homeCatalog.packages.pokegear.available = supported
    displayRuntime.homeCatalog.surfaces.pokegear_app.hidden = not supported
    displayRuntime.pendingPokegear, displayRuntime.appPokegear = nil, nil
  end

  function displayRuntime.canOpenPokegear()
    if not session.active or not compat.isGen2() or displayRuntime.gen3
        or THEME.style ~= "hgss" or screenState() ~= "active"
        or displayRuntime.pendingPokegear then return false end
    local StartMenu = require("src.ui.gen2.StartMenu")
    return StartMenu.availability({ game = session.game, save = session.game.save }).pokegear == true
  end

  function displayRuntime.queuePokegear()
    if not displayRuntime.canOpenPokegear() then return false end
    local game = session.game
    displayRuntime.pendingPokegear = { game = game, save = game.save, top = game.stack:top() }
    return true
  end

  -- Game path [Gold/Silver/Crystal]: use the native device and its real phone
  -- scripts. Push during input.step, just like other native action handoffs.
  function displayRuntime.stepPokegear(game)
    local pending = displayRuntime.pendingPokegear
    if pending and game == pending.game then
      displayRuntime.pendingPokegear = nil
      if session.game == game and game.save == pending.save
          and game.stack:top() == pending.top and displayRuntime.canOpenPokegear() then
        local native
        native = require("src.ui.Screens").push(game, "Gen2Pokegear", {
          currentLandmark = game.currentLandmark and game:currentLandmark(),
          onCall = function(call)
            if game.runPokegearCall then return game:runPokegearCall(call) end
            return false
          end,
          onClose = function()
            if game.stack:top() ~= native then return end
            native:stopRadio()
            game.stack:pop()
            displayRuntime.appPokegear = nil
            displayRuntime.home.activeApp = nil
            session.page, session.dirty = "HOME", true
          end,
        })
        native.kantoGearAppOwner = {}
        displayRuntime.appPokegear, session.dirty = native, true
      end
    end
  end

  -- Mod path [Pokégear app]: hide only this app-owned native instance, and only
  -- while its touch companion can actually be presented. Native-menu openings
  -- retain the original device on top, independently of the battle UI mode.
  mod.hooks:wrap("screen.render_visible", function(next, state)
    if next(state) == false then return false end
    local native = displayRuntime.appPokegear
    -- API 3 supplies a shallow screen context here; its identity/metatable is
    -- detached, but this private owner token still identifies the exact device.
    if not native or not state or state.kantoGearAppOwner ~= native.kantoGearAppOwner then return true end
    local game = session.game
    local view = displayRuntime.nativePokegearView
    local mirrored = session.active and THEME.style == "hgss" and hasDisplay()
      and session.displayReady and game and game.stack:top() == native
      and view and view.native == native and view.valid()
    return not mirrored
  end, 1100)
end
