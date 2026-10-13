return function(
  Discovery, THEME, compat, currentBattleUIMode, displayRuntime, hgssRuntime,
  mod, session
)
  function displayRuntime.discoveryMode()
    Discovery.current()
    return session.discoveryPolicy.stamp_totals and (session.discoveryPolicy.hidden_items and "spoiler" or "enhanced") or "vanilla"
  end
  function displayRuntime.discoveryPolicy() return Discovery.current() end
  function displayRuntime.knownMap(id)
    Discovery.current()
    return Discovery.map(session.discoveryPolicy, id, session.mapId,
      mod.save:get("achievement_visits", {}), session.game and session.game.save)
  end
  function displayRuntime.knownSpecies(species)
    Discovery.current()
    local save = session.game and session.game.save or {}
    return Discovery.species(session.discoveryPolicy, species,
      save.pokedex and save.pokedex.seen, compat.caughtDex(save))
  end
  function displayRuntime.visibleAreaSections(sections)
    for category, section in ipairs(sections) do
      section.rows = Discovery.filter(section.rows, function(row)
        return Discovery.row(session.discoveryPolicy, row, category,
          displayRuntime.knownMap(row.mapId or session.mapId))
      end)
    end
    return sections
  end

  -- Feedback belongs to accepted actions, never drawing, pointer-down or focus.
  -- Use the host's device vibration path without changing its touchpad settings.
  displayRuntime.hapticDurations = {
    open = 0.012,
    snap = 0.018,
    confirm = 0.020,
    discover = 0.025,
    hold = 0.035,
  }
  function displayRuntime.haptic(cue)
    if THEME.style ~= "hgss" or mod.options:get("ui_haptics") ~= true then
      return false
    end
    local now = love.timer.getTime()
    if now < (displayRuntime.nextHaptic or 0) then return false end
    displayRuntime.nextHaptic = now + 0.25
    local ok, result = pcall(function()
      local system = love.system
      if not system or type(system.vibrate) ~= "function" then return false end
      return system.vibrate(displayRuntime.hapticDurations[cue or "open"]
        or displayRuntime.hapticDurations.open)
    end)
    return ok and result ~= false
  end

  function displayRuntime.motionEnabled()
    return mod.options:get("ui_motion") ~= false and mod.options:get("map_motion") ~= "performance"
  end

  function hgssRuntime.beginAnimation(kind, data)
    if THEME.style ~= "hgss" or not displayRuntime.motionEnabled()
        or session.battle and currentBattleUIMode() == "info" then
      hgssRuntime.animation = nil
      return
    end
    data = data or {}
    data.kind, data.queued = kind, love.timer.getTime()
    data.started, data.lastProgress = nil, 0
    data.duration = data.duration or 0.24
    hgssRuntime.animation, session.dirty = data, true
  end

  function hgssRuntime.progress(kind)
    local animation = hgssRuntime.animation
    if not (animation and animation.kind == kind) then return nil end
    if not animation.started then
      animation.started = love.timer.getTime()
      animation.lastProgress = 0
      return 0
    end
    animation.lastProgress = math.max(0, math.min(1,
      (love.timer.getTime() - animation.started) / animation.duration))
    return animation.lastProgress
  end

  function hgssRuntime.partySubmenuActions(menu)
    local submenu = type(menu and menu.submenu) == "table" and menu.submenu
      or nil
    local items = menu and (menu.subItems or (submenu and submenu.items)) or {}
    local actions = {}
    for index = 1, #items do
      actions[#actions + 1] = { index = index, item = items[index] }
    end
    return actions, submenu
  end

  function hgssRuntime.rootDirection(index, direction)
    local targets = {
      [1] = { left = 3, right = 2, up = 1, down = 4 },
      [2] = { left = 4, right = 2, up = 1, down = 2 },
      [3] = { left = 3, right = 4, up = 1, down = 3 },
      [4] = { left = 3, right = 2, up = 1, down = 4 },
    }
    return (targets[index] or targets[1])[direction]
  end

  assert(hgssRuntime.rootDirection(1, "left") == 3
      and hgssRuntime.rootDirection(1, "down") == 4
      and hgssRuntime.rootDirection(3, "right") == 4
      and hgssRuntime.rootDirection(4, "right") == 2
      and hgssRuntime.rootDirection(2, "up") == 1,
    "HGSS battle root navigation follows its visible geometry")

  function hgssRuntime.fullRootDirection(index, direction)
    index = math.max(1, math.min(4, tonumber(index) or 1))
    if direction == "left" or direction == "right" then
      return index % 2 == 1 and index + 1 or index - 1
    elseif direction == "up" or direction == "down" then
      return index <= 2 and index + 2 or index - 2
    end
  end

  assert(hgssRuntime.fullRootDirection(1, "right") == 2
      and hgssRuntime.fullRootDirection(2, "left") == 1
      and hgssRuntime.fullRootDirection(1, "down") == 3
      and hgssRuntime.fullRootDirection(4, "up") == 2,
    "HGSS Full Gear navigation follows its visible two-by-two action grid")

end
