return function(
  THEME, displayRuntime, inside, session
)
  function displayRuntime.tapHome(x, y)
    local home, layout = displayRuntime.home, displayRuntime.home.layout
    displayRuntime.refreshDeviceSurfaces()
    if displayRuntime.homeHelpActive() then
      displayRuntime.tapHomeHelp(x, y)
      return
    end
    if home.library then
      if y < 30 and x < 27 then
        home.library, home.addSlot, session.dirty = false, nil, true
        return
      end
      if inside(x, y, 10, 34, 108, 13) then
        home.libraryKind, home.libraryPage, session.dirty = "app", 1, true
        return
      elseif inside(x, y, 121, 34, 108, 13) then
        home.libraryKind, home.libraryPage, session.dirty = "widget", 1, true
        return
      end
      local items = displayRuntime.Home.library(layout,
        displayRuntime.homeCatalog, home.page,
        home.addSlot.column, home.addSlot.row, home.libraryKind)
      local first = ((home.libraryPage or 1) - 1) * 6 + 1
      for visible = 0, 5 do
        local item = items[first + visible]
        local column, row = visible % 2, math.floor(visible / 2)
        if item and item.available and inside(x, y,
            10 + column * 111, 49 + row * 48, 108, 46) then
          local placed = displayRuntime.Home.place(layout, displayRuntime.homeCatalog,
            item.id, home.page, home.addSlot.column, home.addSlot.row)
          displayRuntime.Home.compactRows(layout,
            displayRuntime.homeCatalog)
          home.library, home.addSlot = false, nil
          displayRuntime.saveHome()
          if placed then displayRuntime.haptic("snap") end
          return
        end
      end
      return
    elseif THEME.style == "hgss" and session.page == "SETTINGS" then
      local model = displayRuntime.settingsModel()
      if model.category and model.pages > 1 then
        displayRuntime.settings.page = ((model.page - 1 + direction)
          % model.pages) + 1
        displayRuntime.settings.confirm = nil
        session.dirty = true
      end
      return
    end
    if home.editing and inside(x, y, 139, 4, 95, 19) then
      home.editing, home.swapSource, session.dirty = false, nil, true
      displayRuntime.saveHome()
      return
    end
    local tile = displayRuntime.homeTileAt(x, y)
    if not home.editing and not tile and #(layout.tiles or {}) == 0 then
      local left, top, width, height = THEME.hgss:homeEmptyRect()
      if inside(x, y, left, top, width, height) then
        local slots = displayRuntime.Home.plusSlots(layout,
          displayRuntime.homeCatalog, home.page)
        if slots[1] then
          home.editing, home.library, home.addSlot = true, true, slots[1]
          home.libraryKind, home.libraryPage = "app", 1
          session.dirty = true
        end
      end
      return
    end
    if home.editing then
      if tile then
        local left, top = THEME.hgss:homeRect(tile)
        if (x - left - 6) ^ 2 + (y - top - 6) ^ 2 <= 36 then
          displayRuntime.Home.remove(layout, tile.id,
            displayRuntime.homeCatalog)
          if home.swapSource == tile.id then home.swapSource = nil end
          displayRuntime.saveHome()
        elseif not home.swapSource then
          home.swapSource, session.dirty = tile.id, true
        elseif home.swapSource == tile.id then
          home.swapSource, session.dirty = nil, true
        elseif displayRuntime.Home.swap(layout, displayRuntime.homeCatalog,
            home.swapSource, tile.id) then
          home.swapSource = nil
          displayRuntime.saveHome()
          displayRuntime.haptic("snap")
        end
        return
      end
      local _, slots = displayRuntime.homePageElements()
      for _, slot in ipairs(slots) do
        local left, top, width, height = THEME.hgss:homeRect(slot)
        if inside(x, y, left, top, width, height) then
          if home.swapSource then
            local column = slot.column + math.floor(slot.columns / 2)
            if displayRuntime.Home.drop(layout, displayRuntime.homeCatalog,
                home.swapSource, home.page, column, slot.row) then
              home.swapSource = nil
              displayRuntime.saveHome()
              displayRuntime.haptic("snap")
            end
          else
            home.library, home.addSlot = true, slot
            home.libraryKind, home.libraryPage = "app", 1
          end
          session.dirty = true
          return
        end
      end
      return
    end
    local surface = tile and displayRuntime.homeCatalog.surfaces[tile.id]
    local opened
    if surface and surface.widget == "device" then
      opened = displayRuntime.openHomeApp(surface.package, surface.deviceTarget)
    elseif surface and surface.widget == "tool" then
      if not displayRuntime.activateTool(surface.action, surface.rodId) then
        opened = displayRuntime.openHomeApp("tools")
      end
    elseif surface and surface.widget == "achievements" then
      local area = displayRuntime.currentAchievement().area
      opened = displayRuntime.openHomeApp("achievements")
      if opened and area then
        local state = displayRuntime.achievements
        state.view, state.selected, state.page, state.category = "detail", area.id, 1, nil
        state.parent, state.parentPage = "album", 1
      end
    elseif surface and surface.widget == "team" then
      local _, top = THEME.hgss:homeRect(tile)
      if y < top + 20 then
        opened = displayRuntime.openHomeApp("party")
      else
        local slot = THEME.hgss:homeTeamSlotAt(x, y, tile,
          #(session.game.save.party or {}))
        if slot and displayRuntime.openHomeApp("party") then
          opened = displayRuntime.openPartySummary(slot)
        end
      end
    elseif surface then opened = displayRuntime.openHomeApp(surface.package) end
    if opened then displayRuntime.haptic() end
  end

end
