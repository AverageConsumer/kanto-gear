return function(
  THEME, compat, displayRuntime, mod, savedSteps, session
)
  local function reloadSteps()
    session.steps = savedSteps(mod.save:get("steps", 0))
    session.dirty = true
  end

  function displayRuntime.updateStepRefresh(now)
    if not displayRuntime.lastStepAt
        or now - displayRuntime.lastStepAt
          < displayRuntime.stepRefreshDelay then return false end
    displayRuntime.lastStepAt = nil
    if session.page == "TRAINER" or session.page == "STEPS" or session.page == "HOME"
        or session.page == "LOCAL" and THEME.style ~= "hgss" then session.dirty = true; return true end
    return false
  end

  function displayRuntime.homeSnapshot()
    local installed = {}
    for id, package in pairs(displayRuntime.homeCatalog.packages) do
      installed[id] = package.installed == true
    end
    local layout = { tiles = {} }
    for _, tile in ipairs(displayRuntime.home.layout.tiles or {}) do
      layout.tiles[#layout.tiles + 1] = {
        id = tile.id, page = tile.page,
        column = tile.column, row = tile.row,
      }
    end
    return { format = 1, packages = installed, layout = layout,
      helpSeen = displayRuntime.home.helpSeen == true }
  end

  function displayRuntime.saveHome()
    local state = displayRuntime.homeSnapshot()
    -- Host path [all games]: retain the normal-save Home-layout copy for recovery and older releases alongside the per-playthrough storage copy.
    -- Keep the normal-save copy for backwards compatibility and recovery.
    mod.save:set("home_packages", state.packages)
    mod.save:set("home_layout", state.layout)
    mod.save:set("home_help_seen", state.helpSeen)
    -- Home customization is UI state: commit it immediately instead of
    -- requiring another in-game SAVE before the app may be restarted.
    if session.game and mod.storage and mod.storage.write then
      mod.storage:write(displayRuntime.sourceGame or session.game, "home/state", state)
    end
  end

  function displayRuntime.packageInstalled(package, saved)
    if package.fixed then return true end
    if package.available == false then return false end
    if type(saved) == "boolean" then return saved end
    return package.defaultInstalled == true
  end
  assert(displayRuntime.packageInstalled({ fixed = true }, false)
      and displayRuntime.packageInstalled({ defaultInstalled = true }, nil)
      and not displayRuntime.packageInstalled({}, nil)
      and not displayRuntime.packageInstalled({ available = false }, true),
    "Store packages require an explicit default or user installation")

  function displayRuntime.loadHome()
    local durable
    if session.game and mod.storage and mod.storage.read then
      durable = mod.storage:read(displayRuntime.sourceGame or session.game, "home/state")
      if type(durable) ~= "table" then durable = nil end
    end
    local installed = durable and durable.packages
      or mod.save:get("home_packages", {})
    if type(installed) ~= "table" then installed = {} end
    for id, package in pairs(displayRuntime.homeCatalog.packages) do
      package.installed = displayRuntime.packageInstalled(
        package, installed[id])
    end
    local saved = durable and durable.layout or mod.save:get("home_layout")
    local hasSaved = type(saved) == "table" and type(saved.tiles) == "table"
    local source = hasSaved and saved.tiles or displayRuntime.defaultHomeTiles
    local layout = { tiles = {} }
    for _, tile in ipairs(source) do
      if type(tile) == "table" then
        displayRuntime.Home.place(layout, displayRuntime.homeCatalog, tile.id,
          tonumber(tile.page), tonumber(tile.column), tonumber(tile.row))
      end
    end
    displayRuntime.Home.compactRows(layout, displayRuntime.homeCatalog)
    displayRuntime.home.layout = layout
    displayRuntime.home.page = math.max(1, math.min(
      displayRuntime.Home.pageCount(layout),
      tonumber(displayRuntime.home.page) or 1))
    displayRuntime.home.editing, displayRuntime.home.library = false, false
    displayRuntime.home.addSlot, displayRuntime.home.activeApp = nil, nil
    displayRuntime.home.swapSource = nil
    displayRuntime.home.helpSeen = durable and durable.helpSeen == true
      or mod.save:get("home_help_seen", false) == true
    displayRuntime.home.help = not displayRuntime.home.helpSeen
    if not durable and hasSaved and session.game and mod.storage
        and mod.storage.write then
      mod.storage:write(displayRuntime.sourceGame or session.game, "home/state", displayRuntime.homeSnapshot())
    end
    session.dirty = true
  end

  function displayRuntime.setPackageInstalled(id, installed)
    local package = displayRuntime.homeCatalog.packages[id]
    if not package or package.available == false
        or package.fixed and not installed then return false end
    package.installed = installed == true
    if not package.installed then
      if id == "pss" then displayRuntime.pss:close() end
      displayRuntime.Home.removePackage(displayRuntime.home.layout,
        displayRuntime.homeCatalog, id)
    end
    displayRuntime.saveHome()
    session.dirty = true
    return true
  end
  function displayRuntime.storeEntry(app)
    local package = app and displayRuntime.homeCatalog.packages[app.id]
    local installed = package and package.installed == true
    local state = app and app.available == false and "soon"
      or installed and "open" or "get"
    return app and {
      id = app.id, icon = app.icon, label = app.label,
      category = app.category, publisher = "SILPH CO.",
      new = app.new == true,
      reason = app.reason or app.category,
      target = app.target, state = state,
      action = state == "soon" and "SOON"
        or state == "open" and "OPEN APP" or "GET",
      removable = installed and not package.fixed,
      description = app.description,
    }
  end

  -- Game path [Gen 1/2/3]: badges live in inventory, regional player flag sets, or native Gen 3 flag definitions respectively.
  function displayRuntime.trainerSummary(shownRegion)
    local save, player = session.game.save or {}, session.game.save and session.game.save.player or {}
    local elapsed = math.max(0, math.floor(compat.playSeconds(save)))
    local dex = displayRuntime.pokedexData()
    local region = (shownRegion or compat.currentRegion() or "kanto"):upper()
    local held, badges = player.badges or {}, {}
    if displayRuntime.gen3 then
      for index = 1, 8 do badges[index] = displayRuntime.gen3:badge(index) end
    elseif compat.isGen2() then
      if region == "KANTO" then held = player.kantoBadges or {} end
      for index, id in ipairs(THEME.gen2Badges[region:lower()] or {}) do
        badges[index] = not not (held[id] or held[index])
      end
    else
      local inventory = save.inventory or {}
      for index, badge in ipairs(session.game.data.constants
          and session.game.data.constants.badges or {}) do
        badges[index] = not not inventory[badge.item or badge.id]
      end
    end
    local badgeCount = 0
    for _, owned in ipairs(badges) do
      if owned then badgeCount = badgeCount + 1 end
    end
    local totalCount, totalBadges = badgeCount, #badges
    -- Game path [Gen 2]: Home totals include Johto and Kanto (16 badges), even when its card shows only one region.
    if compat.isGen2() then
      totalCount, totalBadges = 0, 16
      for _, name in ipairs({ "johto", "kanto" }) do
        local flags = name == "kanto" and (player.kantoBadges or {}) or (player.badges or {})
        for index, id in ipairs(THEME.gen2Badges[name]) do
          if flags[id] or flags[index] then totalCount = totalCount + 1 end
        end
      end
    end
    local money = tonumber(player.money or save.money) or 0
    local moneyShort = money >= 1000000
      and THEME:format("¥%.1fM", money / 1000000)
      or money >= 1000 and THEME:format("¥%dK", math.floor(money / 1000))
      or THEME:format("¥%d", money)
    return {
      name = player.name or (compat.isGen2() and "GOLD" or "RED"),
      region = region,
      idText = THEME:format("ID %05d", player.id or 0),
      money = THEME:format("¥%d", money), moneyShort = moneyShort,
      time = ("%d:%02d"):format(math.floor(elapsed / 3600),
        math.floor(elapsed / 60) % 60),
      pokedex = THEME:format("%d/%d", dex.caught or 0, dex.total or 0),
      badgeOwned = badges, badgeCount = badgeCount,
      badgeTotal = #badges, badgeText = THEME:format("%d/%d", totalCount, totalBadges), badgeRegion = region,
    }
  end

  function displayRuntime.bagSummary()
    local counts = { item = 0, medicine = 0, ball = 0, machine = 0 }
    local inventory = session.game.save and session.game.save.inventory or {}
    -- Totals do not need acquisition order. Badges share inventory with items.
    for id, value in pairs(inventory) do
      local amount = tonumber(value) or 0
      if amount > 0 and not tostring(id):find("BADGE", 1, true) then
        local def = session.game.data.items and session.game.data.items[id] or {}
        local kind = displayRuntime.bagItemKind(id, def)
        if kind == "status" then kind = "medicine" end
        if counts[kind] ~= nil then counts[kind] = counts[kind] + amount
        else counts.item = counts.item + amount end
      end
    end
    return counts
  end

  return reloadSteps
end
