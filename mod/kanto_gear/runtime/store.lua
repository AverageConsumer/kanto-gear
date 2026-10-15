return function(
  THEME, areaName, assist, compactSteps, compat, displayRuntime,
  drawSprite, header, loadLocalMap, partyData, render, session
)
  function displayRuntime.storeEntries(installedOnly)
    local apps = {}
    for _, app in ipairs(displayRuntime.storeCatalog) do
      local entry = displayRuntime.storeEntry(app)
      if not app.hidden and (not installedOnly or entry.state == "open") then
        apps[#apps + 1] = entry
      end
    end
    return apps
  end

  displayRuntime.storePageSizes = { apps = 4, library = 12 }
  function displayRuntime.storePageSlice(entries, page, size)
    local pages = math.max(1, math.ceil(#entries / size))
    page = math.max(1, math.min(pages, tonumber(page) or 1))
    local first, shown = (page - 1) * size + 1, {}
    for index = first, math.min(#entries, first + size - 1) do
      shown[#shown + 1] = entries[index]
    end
    return shown, page, pages, first - 1
  end
  do
    local shown, page, pages, offset = displayRuntime.storePageSlice(
      { "A", "B", "C", "D", "E", "F", "G" }, 2, 4)
    assert(#shown == 3 and shown[1] == "E" and shown[3] == "G"
        and page == 2 and pages == 2 and offset == 4,
      "Silph Store pagination exposes every catalog entry")
  end

  function displayRuntime.storePage(view, entries)
    local home = displayRuntime.home
    home.storePages = home.storePages or {}
    local shown, page, pages, offset = displayRuntime.storePageSlice(entries,
      home.storePages[view], displayRuntime.storePageSizes[view])
    home.storePages[view] = page
    return shown, page, pages, offset
  end

  function displayRuntime.cycleStorePage(view, direction)
    displayRuntime.requestPageMotion(direction)
    local entries = displayRuntime.storeEntries(view == "library")
    local _, page, pages = displayRuntime.storePage(view, entries)
    displayRuntime.home.storePages[view] =
      (page - 1 + direction) % pages + 1
  end

  function displayRuntime.setStorePage(view, target)
    local _, _, current, pages = displayRuntime.storeSelection(view)
    target = math.max(1, math.min(pages, target))
    if target == current then return false end
    displayRuntime.home.storePages[view] = target
    displayRuntime.home[view == "library" and "storeGearSel" or "storeSel"] = nil
    session.dirty = true
    return true
  end

  function displayRuntime.dragStoreScroll(down, y)
    local home = displayRuntime.home
    if session.page ~= "STORE" or home.storeView ~= down.storeView
        or home.storeConfirm or home.storeReceived then return false end
    return displayRuntime.setStorePage(down.storeView,
      THEME.hgss:storeScrollPage(y, down.storePages, down.storeGrab))
  end

  function displayRuntime.storeSwipeTarget(view, y, pages)
    return (view == "apps" or view == "library")
      and (pages or 1) > 1 and y >= 58 and y < 170
  end
  assert(displayRuntime.storeSwipeTarget("apps", 58, 2)
      and displayRuntime.storeSwipeTarget("library", 169, 3)
      and not displayRuntime.storeSwipeTarget("apps", 57, 2)
      and not displayRuntime.storeSwipeTarget("apps", 170, 2)
      and not displayRuntime.storeSwipeTarget("apps", 100, 1)
      and not displayRuntime.storeSwipeTarget("today", 100, 2),
    "Silph Store app-grid swipes target paginated app lists")

  function displayRuntime.storeTodayEntries()
    local featured
    for _, app in ipairs(displayRuntime.storeCatalog) do
      if app.featured and app.available ~= false then
        featured = app
        break
      end
    end
    return {
      displayRuntime.storeEntry(featured or displayRuntime.storeById.tools),
      displayRuntime.storeEntry(displayRuntime.storeById.party),
      displayRuntime.storeEntry(displayRuntime.storeById.bag),
    }
  end

  function displayRuntime.storeWidgetSummary()
    local installed, available, promo = 0, 0, nil
    for _, app in ipairs(displayRuntime.storeCatalog) do
      local package = displayRuntime.homeCatalog.packages[app.id]
      if app.available ~= false and not app.hidden then
        available = available + 1
        if package and package.installed then installed = installed + 1 end
        if not promo and app.new and package and not package.installed then
          promo = app
        end
      end
    end
    if promo then
      return { icon = promo.icon, label = promo.label,
        category = promo.category, new = true }
    end
    return { icon = "store", label = "APPS",
      installed = installed, available = available }
  end

  function displayRuntime.cycleStoreView(direction)
    local home = displayRuntime.home
    local views = { "apps", "library", "today" }
    local current = 1
    for index, view in ipairs(views) do
      if view == home.storeView then current = index break end
    end
    home.storeView = views[(current - 1 + direction) % #views + 1]
  end

  function displayRuntime.enrichStorePreview(entry)
    if not entry then return entry end
    if entry.id == "explorer" then
      local overview = loadLocalMap()
      if overview then entry.preview = displayRuntime.explorerModel(overview) end
    elseif entry.id == "map" then
      entry.preview = {
        region = (compat.currentRegion() or "kanto"):upper(),
        location = areaName(session.mapId),
      }
    elseif entry.id == "party" then
      local party = partyData()
      entry.preview = { party = party,
        drawPokemon = function(mon, x, y, size)
          local source = mon.source or mon
          if not drawSprite(mon.species, "front", x, y, size, size,
              nil, source, true) then
            compat.drawPokemonIcon(source, x, y, size)
          end
        end }
    elseif entry.id == "pokedex" then
      local dex, entries = displayRuntime.pokedexData(), {}
      for index = 1, math.min(6, #(dex.entries or {})) do
        entries[index] = dex.entries[index]
      end
      entry.preview = { entries = entries,
        page = 1,
        pages = math.max(1, math.ceil(#(dex.entries or {}) / 9)),
        progress = (tonumber(dex.caught) or 0)
          / math.max(1, tonumber(dex.total) or 1),
        drawPokemon = function(row, x, y, size)
          local tint = not row.caught and (row.seen
              and THEME.hgss.colors.silver or THEME.hgss.colors.shadow)
            or nil
          drawSprite(row.species, "front", x, y, size, size,
            tint, nil, true)
        end }
    elseif entry.id == "bag" then
      entry.preview = displayRuntime.bagModel()
    elseif entry.id == "trainer" then
      entry.preview = displayRuntime.trainerSummary()
    elseif entry.id == "steps" then
      entry.preview = { steps = assist("journey_stats") and compactSteps(session.steps) or "--" }
    end
    return entry
  end

  -- The store's picked app per tab, kept on the page being shown.
  function displayRuntime.storeSelection(view)
    local home = displayRuntime.home
    local entries = displayRuntime.storeEntries(view == "library")
    local shown, page, pages, offset = displayRuntime.storePage(view, entries)
    local key = view == "library" and "storeGearSel" or "storeSel"
    local selected
    for _, entry in ipairs(shown) do
      if entry.id == home[key] then selected = entry end
    end
    selected = selected or shown[1]
    home[key] = selected and selected.id or nil
    return selected, shown, page, pages, offset, entries
  end
  -- Jump BUY to an app: its page, its row.
  function displayRuntime.storeShow(id)
    local home = displayRuntime.home
    home.storeView, home.storeSel = "apps", id
    for index, entry in ipairs(displayRuntime.storeEntries()) do
      if entry.id == id then
        home.storePages = home.storePages or {}
        home.storePages.apps = math.ceil(index / displayRuntime.storePageSizes.apps)
      end
    end
  end
  function displayRuntime.storeOnHome(id)
    for _, tile in ipairs(displayRuntime.home.layout.tiles or {}) do
      local surface = displayRuntime.homeCatalog.surfaces[tile.id]
      if surface and surface.package == id then return true end
    end
    return false
  end
  -- First free spot for the app's home key: existing pages, then a new one.
  function displayRuntime.storeHomeSpot(id)
    local Home, layout = displayRuntime.Home, displayRuntime.home.layout
    local surface = id .. "_app"
    if not displayRuntime.homeCatalog.surfaces[surface] then return nil end
    for homePage = 1, Home.pageCount(layout) + 1 do
      for row = 1, Home.rows do
        for column = 1, Home.columns do
          if Home.canPlace(layout, displayRuntime.homeCatalog, surface, homePage, column, row) then
            return surface, homePage, column, row
          end
        end
      end
    end
  end
  -- NEWS: the featured app, then the two apps you don't have yet.
  function displayRuntime.storeNewsEntries()
    local today = displayRuntime.storeTodayEntries()
    local featured, picks = today[1], {}
    for _, entry in ipairs(displayRuntime.storeEntries()) do
      if #picks < 2 and entry.id ~= featured.id and entry.state == "get" then picks[#picks + 1] = entry end
    end
    picks[1] = picks[1] or today[2]
    picks[2] = picks[2] or today[3]
    return featured, picks[1], picks[2]
  end

  function displayRuntime.drawStore()
    local home, view = displayRuntime.home, displayRuntime.home.storeView
    header(THEME:translate("SILPH STORE"), true, not home.storeConfirm and not home.storeReceived)
    render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    if home.storeReceived then
      THEME.hgss:storeReceived({ app = displayRuntime.storeEntry(displayRuntime.storeById[home.storeReceived]) })
    elseif view == "library" then
      local selected, apps, pagesShown, pages = displayRuntime.storeSelection(view)
      THEME.hgss:storeGear({ apps = apps, selected = selected, page = pagesShown, pages = pages,
        confirm = home.storeConfirm, onHome = selected and displayRuntime.storeOnHome(selected.id),
        canPlace = selected and displayRuntime.storeHomeSpot(selected.id) ~= nil })
    elseif view == "today" then
      local featured, pick, second = displayRuntime.storeNewsEntries()
      THEME.hgss:storeNews({ featured = featured, pick = pick, second = second })
    else
      local selected, apps, pagesShown, pages = displayRuntime.storeSelection("apps")
      THEME.hgss:storeBuy({ apps = apps, selected = selected, page = pagesShown, pages = pages,
        confirm = home.storeConfirm, confirmKind = home.storeConfirmKind })
    end
    render.G.pop()
  end

end
