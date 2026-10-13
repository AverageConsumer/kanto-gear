return function(
  PaletteFX, THEME, areaName, box, centered, color,
  compat, displayRuntime, header, loadMap, locationEntries, locationEntry,
  mod, render, session
)
  local function drawMapFallback()
    local townMap = session.game.data.field and session.game.data.field.townMap
    local locations = townMap and (townMap.locations or townMap) or {}
    local playerX, playerY
    for id, entry in pairs(locations) do
      local c = entry.coords or entry
      local x, y = tonumber(c.x or c.col), tonumber(c.y or c.row)
      if x and y then
        local px, py = 22 + x * 7, 24 + y * 6
        box("fill", px, py, 4, 4, render.DARK)
        if id == session.mapId then playerX, playerY = px + 2, py + 2 end
      end
    end
    if playerX then compat.drawMapMarker(playerX, playerY) end
  end

  -- Game path [Gen 2 vs Gen 1]: imported landmark coordinates are pixels; Gen 1 TownMap entries use tile coordinates and a header offset.
  local function entryCoords(entry)
    local c = entry and (entry.coords or entry)
    local x, y = c and tonumber(c.x or c.col), c and tonumber(c.y or c.row)
    if compat.isGen2() and entry and entry.index ~= nil then
      return x and x / 8, y and y / 8
    end
    return x, y
  end

  local function mapPoint(entry)
    if compat.isGen2() then
      local x, y = entry and tonumber(entry.x), entry and tonumber(entry.y)
      if not (x and y) then return nil end
      return 20 + x * 0.75, 20 + y * 0.75
    end
    local x, y = entryCoords(entry)
    if not (x and y) then return nil end
    return 20 + (x * 8 + 20) * 0.75,
           22 + (y * 8 + 4) * 0.75
  end

  -- Game path [Gen 1/2/3]: Gen 3 delegates to native regional maps; Gen 2 selects Johto/Kanto sheets, Gen 1 crops the TownMap header row.
  function displayRuntime.homeRegionMap(full, regionOverride)
    if displayRuntime.gen3 then
      if not displayRuntime.gen3Region then
        displayRuntime.gen3Region = assert(load(mod:read("adapters/gen3/region.lua"),
          "@kanto_gear/adapters/gen3/region.lua"))().new(displayRuntime.gen3, render.G)
      end
      return displayRuntime.gen3Region:model(areaName(session.mapId), compat.drawMapMarker)
    end
    local asset = loadMap()
    local region = regionOverride or compat.currentRegion() or "kanto"
    local cells = asset and (asset.gen2 and asset.maps[region] or asset.map)
    if not (asset and cells) then
      return { region = region:upper(), area = areaName(session.mapId) }
    end
    local rows = math.max(1, math.ceil(#cells / 20) - (asset.gen2 and 0 or 1))
    local playerX, playerY = mapPoint(locationEntry(session.mapId))
    if regionOverride and regionOverride ~= (compat.currentRegion() or "kanto") then playerX, playerY = nil, nil end
    return {
      width = 160, height = rows * 8, key = "legacy:" .. region,
      playerX = playerX and (playerX - 20) / 0.75,
      playerY = playerY and (playerY - (asset.gen2 and 20 or 22)) / 0.75,
      region = region:upper(), area = areaName(session.mapId),
      drawMap = function(x, y, w, h)
        local rows = math.max(1, math.ceil(#cells / 20)
          - (asset.gen2 and 0 or 1))
        local scale = full and math.min(w / 160, h / (rows * 8)) or w / 160
        local left = full and math.floor(x + (w - 160 * scale) / 2 + 0.5) or x
        local mapHeight = rows * 8 * scale
        local px, py = playerX, playerY
        local oldTop = asset.gen2 and 20 or 22
        local sourceY = py and (py - oldTop) / 0.75 or rows * 4
        local top = y + math.floor((h - mapHeight) / 2 + 0.5)
        if mapHeight > h then
          top = math.floor(y + h / 2 - sourceY * scale + 0.5)
          top = math.max(math.floor(y + h - mapHeight), math.min(y, top))
        end
        local gbc = require("src.render.GbcPalette")
        local mapColors = not asset.gen2
          and PaletteFX.pal(session.game.data, "TOWNMAP") or nil
        for index, tile in ipairs(cells) do
          local quad = asset.quads[tile]
          if quad then
            local column, row = (index - 1) % 20,
              math.floor((index - 1) / 20)
            local visibleRow = asset.gen2 and row or row - 1
            if asset.gen2 or row > 0 then
              local palette = asset.gen2 and asset.palettes
                and asset.palettes[(asset.palMap
                  and asset.palMap[tile + 1]) or 1] or mapColors
              local function paint()
                render.G.setColor(1, 1, 1, 1)
                render.G.draw(asset.image, quad, left + column * 8 * scale,
                  top + visibleRow * 8 * scale, 0, scale, scale)
              end
              if palette and gbc.available() then gbc.with(palette, paint)
              else paint() end
            end
          end
        end
        if px then
          compat.drawMapMarker(left + (px - 20) / 0.75 * scale,
            top + sourceY * scale, 1)
        end
      end,
    }
  end

  function displayRuntime.hgssMapPoint(x, y, left, top, scale, oldTop)
    return (left + (x - 20) / 0.75 * scale) / THEME.hgssScale,
      (top + (y - oldTop) / 0.75 * scale) / THEME.hgssScale
  end
  do
    local x, y = displayRuntime.hgssMapPoint(20, 20, 30, 39, 1, 20)
    assert(x == 20 and y == 26,
      "HGSS region map touch targets follow the rendered map transform")
  end

  -- Game path [Gen 2 vs Gen 1]: eligible destinations are visited spawn/landmark pairs in Gen 2 and visited map IDs with fly warps in Gen 1.
  local function flyTargets()
    local out, field = {}, session.game.data.field or {}
    if compat.isGen2() then
      local points, region = displayRuntime.regionFlight():points(compat.currentRegion())
      local landmarks = (session.game.data.gen2Landmarks or {}).landmarks or {}
      for _, row in ipairs(points) do
        local x, y = mapPoint(landmarks[row.landmark])
        if x and y then out[#out + 1] = { id = row.spawn, region = region, name = row.name, x = x, y = y } end
      end
      return out
    end
    for _, id in ipairs(field.flyOrder or {}) do
      local def = session.game.data.maps and session.game.data.maps[id]
      local x, y = mapPoint(locationEntry(id))
      if x and session.game.save.visited and session.game.save.visited[id]
          and field.flyWarps and field.flyWarps[id] and def and require("src.world.Map").isFlyTown(def) then
        out[#out + 1] = { id = id, name = areaName(id), x = x, y = y }
      end
    end
    return out
  end

  local function canFly()
    if displayRuntime.gen3Field then
      return not displayRuntime.gen3Field:busy() and displayRuntime.gen3Field:result("FLY") ~= nil
    end
    if compat.isGen2() then return displayRuntime.regionFlight():canFly() end
    return mod.world and mod.world.canFly and mod.world:canFly()
      and #flyTargets() > 0
  end

  function displayRuntime.regionFlight()
    if not displayRuntime.legacyRegion then
      displayRuntime.legacyRegion = displayRuntime.LegacyRegion.new(session.game, mod.world, compat.isGen2() and 2 or 1)
    end
    return displayRuntime.legacyRegion
  end

  function displayRuntime.regionMapModel()
    local state, region = displayRuntime.regionCursor, compat.currentRegion() or "kanto"
    if displayRuntime.gen3 then
      local model = displayRuntime.homeRegionMap(true)
      if model.width then
        displayRuntime.RegionPage.bind(state, model)
        if state.fly then model.flyPoints = displayRuntime.gen3Region:points(model) end
      end
      return model
    end
    local flight, eligible = displayRuntime.regionFlight(), {}
    if compat.isGen2() then
      local points, shown = flight:points(region)
      if state.fly then region = shown end
      for _, row in ipairs(points) do eligible[row.landmark] = row.spawn end
    else
      for _, row in ipairs(flyTargets()) do eligible[row.id] = row.id end
    end
    local model, points = displayRuntime.homeRegionMap(true, region), {}
    if not model.width then return model end
    local records = compat.isGen2() and (session.game.data.gen2Landmarks or {}).landmarks or locationEntries()
    local flyIds = {}
    if compat.isGen2() then
      for _, row in ipairs(flight.Moves.FLYPOINTS) do flyIds[row.landmark] = row.spawn end
    else
      for _, id in ipairs((session.game.data.field or {}).flyOrder or {}) do
        local def = session.game.data.maps and session.game.data.maps[id]
        if (session.game.data.field.flyWarps or {})[id] and def and require("src.world.Map").isFlyTown(def) then flyIds[id] = id end
      end
    end
    -- Game path [Gen 2]: landmark indices 0-45 are Johto and 46-93 Kanto; do not mix destinations from the other map sheet.
    for id, entry in pairs(records or {}) do
      local index = tonumber(entry.index) or 0
      local sameRegion = not compat.isGen2() or (index < 46 and region == "johto")
        or (index >= 46 and index < 94 and region == "kanto")
      local x, y = mapPoint(entry)
      if sameRegion and x and y then
        points[#points + 1] = { id = flyIds[id] or id, region = region,
          name = tostring(entry.name or entry.label or id):gsub("<LF>", " "):gsub("\n", " "),
          x = (x - 20) / 0.75, y = (y - (compat.isGen2() and 20 or 22)) / 0.75,
          flyPoint = flyIds[id] ~= nil, flyable = eligible[id] ~= nil }
      end
    end
    model.pick = function(x, y) return displayRuntime.LegacyRegion.pick(points, x, y) end
    model.flyPoints = {}
    for _, point in ipairs(points) do
      if point.flyPoint then model.flyPoints[#model.flyPoints + 1] = point end
    end
    displayRuntime.RegionPage.bind(state, model)
    return model
  end

  function displayRuntime.flyRegionTarget(target)
    if not canFly() then return false end
    local ok, err
    if displayRuntime.gen3Field then
      ok, err = displayRuntime.gen3Field:flyTo(target, displayRuntime.gen3Region)
    elseif THEME.style == "hgss" or compat.isGen2() then ok, err = displayRuntime.regionFlight():fly(target)
    else ok, err = mod.world:flyTo(target.id) end
    if not ok then mod.log:warn("fly rejected: %s", tostring(err)) end
    if ok then displayRuntime.regionCursor.fly, displayRuntime.regionCursor.selected = false, false end
    return ok
  end

  function displayRuntime.tapRegionMap(x, y)
    local model = displayRuntime.regionMapModel()
    if not model.pick then return end
    local action, target = displayRuntime.RegionPage.tap(displayRuntime.regionCursor, model,
      x * THEME.hgssScale, y * THEME.hgssScale, canFly())
    if action == "fly" then displayRuntime.flyRegionTarget(target) end
    session.dirty = true
  end

  -- Game path [Gen 2]: landmark 94 is the Johto special case; Gen 3 uses the edition family and Gen 1 has a single Kanto region.
  function compat.currentRegion()
    if displayRuntime.gen3 then return displayRuntime.gen3.hoenn and "hoenn" or "kanto" end
    if not compat.isGen2() then return nil end
    local entry = locationEntry(session.mapId)
    local index = tonumber(entry and entry.index) or 0
    return (index == 94 or index < 46) and "johto" or "kanto"
  end

  local function drawMap()
    if THEME.style == "hgss" then
      local model = displayRuntime.regionMapModel()
      local state, Page = displayRuntime.regionCursor, displayRuntime.RegionPage
      header(THEME:translate("MAP"), true, false)
      if model.pick then
        local target = Page.target(state, model)
        model.area = target and target.name or THEME:translate("UNKNOWN AREA")
        local available = canFly()
        model.status = Page.status(state, target, available)
        model.interactive, model.fly = true, state.fly == true
        model.canFly = Page.ready(state, target, available)
        if session.touchDown and session.touchDown.mapModel and displayRuntime.touchGuard:allow(love.timer.getTime(), session.touchDown.epoch) then
          model.preview = { Page.preview(session.touchDown.mapPointerX or session.touchDown.mapX,
            session.touchDown.mapPointerY or session.touchDown.mapY) }
        end
        local left, top, scale = Page.transform(model)
        model.cursorX, model.cursorY = left + state.x * scale, top + state.y * scale
      end
      render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:regionMap(model)
      render.G.pop()
      return
    end
    if displayRuntime.gen3 then
      local model = displayRuntime.homeRegionMap()
      header(THEME:translate("MAP"), THEME.style == "hgss", THEME.style ~= "hgss")
      if model.drawMap then model.drawMap(4, 24, 152, 116) end
      return
    end
    local region = compat.currentRegion()
    local mapTitle = region and (region:upper() .. (canFly() and " FLY" or " MAP"))
      or (canFly() and "MAP + FLY" or "MAP")
    header(THEME:translate(mapTitle), THEME.style == "hgss",
      THEME.style ~= "hgss")
    local asset = loadMap()
    if asset then
      local cells = asset.map
      local gbc = require("src.render.GbcPalette")
      local mapColors = not asset.gen2
        and PaletteFX.pal(session.game.data, "TOWNMAP") or nil
      if asset.gen2 then
        cells = asset.maps[region]
      end
      local function paintMap(left, top, tileScale, markerScale)
        for i, tile in ipairs(cells or {}) do
          local quad = asset.quads[tile]
          if quad then
            local col, row = (i - 1) % 20, math.floor((i - 1) / 20)
            local visibleRow = asset.gen2 and row or row - 1
            local colors = asset.gen2 and asset.palettes
              and asset.palettes[(asset.palMap and asset.palMap[tile + 1]) or 1]
              or mapColors
            local function paint()
              color(colors and { 1, 1, 1, 1 }
                or asset.gen2 and (THEME.style == "modern_dark" and render.INK or render.PAPER)
                or { 1, 1, 1, 1 })
              render.G.draw(asset.image, quad, left + col * 8 * tileScale,
                top + visibleRow * 8 * tileScale, 0, tileScale, tileScale)
            end
            if asset.gen2 or row > 0 then
              if colors and gbc.available() then gbc.with(colors, paint)
              else paint() end
            end
          end
        end
        local px, py = mapPoint(locationEntry(session.mapId))
        if px then
          local oldTop = asset.gen2 and 20 or 22
          compat.drawMapMarker(left + (px - 20) / 0.75 * tileScale,
            top + (py - oldTop) / 0.75 * tileScale, markerScale)
        end
      end
      paintMap(20, asset.gen2 and 20 or 22, 0.75)
    else
      drawMapFallback()
    end
    box("fill", 4, 128, 152, 14, render.DARK)
    centered(areaName(session.mapId), 130, render.PAPER, nil, true)
  end

  return canFly, drawMap, flyTargets
end
