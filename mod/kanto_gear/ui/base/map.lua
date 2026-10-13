return function(H, ui, draw)
  local border, box, clipped, color =
    draw.border, draw.box, draw.clipped, draw.color
  local fontWidth = draw.fontWidth
  local partyInfoFont, partyTypeFont, translate =
    draw.partyInfoFont, draw.partyTypeFont, draw.translate
  local mapRamps = {
    light = {
      [" "] = {
        { 0.72, 0.82, 0.75, 1 }, { 0.45, 0.66, 0.50, 1 },
        { 0.22, 0.45, 0.29, 1 }, { 0.10, 0.27, 0.18, 1 },
      },
      ["."] = {
        { 0.96, 0.86, 0.55, 1 }, { 0.88, 0.68, 0.29, 1 },
        { 0.68, 0.46, 0.17, 1 }, { 0.42, 0.29, 0.13, 1 },
      },
      ["~"] = {
        { 0.78, 0.92, 0.94, 1 }, { 0.45, 0.75, 0.84, 1 },
        { 0.22, 0.51, 0.70, 1 }, { 0.10, 0.29, 0.49, 1 },
      },
      ["+"] = {
        { 0.99, 0.94, 0.72, 1 }, { 0.98, 0.76, 0.30, 1 },
        { 0.79, 0.48, 0.10, 1 }, { 0.47, 0.27, 0.08, 1 },
      },
    },
    dark = {
      [" "] = {
        { 0.20, 0.33, 0.27, 1 }, { 0.12, 0.25, 0.19, 1 },
        { 0.065, 0.16, 0.12, 1 }, { 0.025, 0.08, 0.065, 1 },
      },
      ["."] = {
        { 0.55, 0.43, 0.20, 1 }, { 0.40, 0.30, 0.13, 1 },
        { 0.27, 0.19, 0.08, 1 }, { 0.15, 0.105, 0.05, 1 },
      },
      ["~"] = {
        { 0.25, 0.53, 0.64, 1 }, { 0.14, 0.39, 0.53, 1 },
        { 0.075, 0.27, 0.42, 1 }, { 0.035, 0.15, 0.27, 1 },
      },
      ["+"] = {
        { 0.66, 0.49, 0.18, 1 }, { 0.49, 0.34, 0.10, 1 },
        { 0.33, 0.21, 0.055, 1 }, { 0.19, 0.12, 0.035, 1 },
      },
    },
  }

  function H:mapColor(overview, x, y, density, shade)
    density = math.max(1, tonumber(density) or 1)
    local cellX = math.floor((x - 1) / density) + 1
    local cellY = math.floor((y - 1) / density) + 1
    local row = overview and overview.rows and overview.rows[cellY] or ""
    local ramps = mapRamps[self.dark and "dark" or "light"]
    local ramp = ramps[row:sub(cellX, cellX)] or ramps[" "]
    return ramp[math.max(1, math.min(4, (tonumber(shade) or 1) + 1))]
  end

  local function mapGrid(overview)
    if overview.tileDetailRows then
      return overview.tileDetailRows, overview.tileDetailWidth,
        overview.tileDetailHeight, 4
    end
    if overview.tileRows then
      return overview.tileRows, overview.tileWidth, overview.tileHeight, 2
    end
    return overview.rows or {}, overview.width or 0, overview.height or 0, 1
  end

  local function mapMarkerVisible(marker, visible)
    return not visible or visible[marker.kind] ~= false
  end

  local function mapTileSize(baseWidth, baseHeight, innerW, innerH, opts)
    if not opts.full then return 8 end
    local zoom = math.max(1, math.min(3, tonumber(opts.zoom) or 1))
    local fit = math.min(innerW / baseWidth, innerH / baseHeight)
    if zoom == 1 then return fit end
    local detail = math.max(12, fit * 1.5)
    -- Split the useful range evenly, while keeping overview markers readable.
    return zoom == 2 and math.max(6, math.sqrt(fit * detail)) or detail
  end

  local function explorerMapFocus(model)
    local marker = model.selectedMarker
    return marker and (marker.kind == "trainer" or marker.kind == "fruit" or marker.gift)
      and marker or model.player
  end
  do
    local player, trainer = { x = 1, y = 2 },
      { kind = "trainer", x = 9, y = 8 }
    assert(explorerMapFocus({ player = player, selectedMarker = trainer })
        == trainer
      and explorerMapFocus({ player = player,
        selectedMarker = { kind = "item", x = 7, y = 6 } }) == player
      and explorerMapFocus({ player = player }) == player,
      "Explorer camera follows only a selected NPC")
  end

  local function mapLayout(overview, x, y, w, h, opts)
    if not overview or not overview.rows then return nil end
    local rows, width, height, density = mapGrid(overview)
    width, height = tonumber(width) or 0, tonumber(height) or 0
    if width < 1 or height < 1 then return nil end
    local innerX, innerY, innerW, innerH = x + 2, y + 2, w - 4, h - 4
    local baseWidth = math.max(1, tonumber(overview.width) or width / density)
    local baseHeight = math.max(1,
      tonumber(overview.height) or height / density)
    local tileSize = mapTileSize(baseWidth, baseHeight, innerW, innerH, opts)
    local scale = tileSize / density
    local focus = opts.focus or opts.player or {}
    local focusX = (tonumber(focus.x) or (overview.width or 1) / 2) * density
      + density / 2
    local focusY = (tonumber(focus.y) or (overview.height or 1) / 2) * density
      + density / 2
    local left = math.floor(innerX + (innerW - width * scale) / 2 + 0.5)
    local top = math.floor(innerY + (innerH - height * scale) / 2 + 0.5)
    if width * scale > innerW then
      left = math.floor(innerX + innerW / 2 - focusX * scale + 0.5)
      left = math.max(innerX + innerW - width * scale, math.min(innerX, left))
    end
    if height * scale > innerH then
      top = math.floor(innerY + innerH / 2 - focusY * scale + 0.5)
      top = math.max(innerY + innerH - height * scale, math.min(innerY, top))
    end
    return { rows = rows, width = width, height = height, density = density,
      innerX = innerX, innerY = innerY, innerW = innerW, innerH = innerH,
      scale = scale, left = left, top = top, tileSize = density * scale }
  end

  local function mapMotionKey(layout, player)
    if not layout or not player or player.x == nil or player.y == nil then return nil end
    return table.concat({ tostring(player.mapId), layout.left, layout.top,
      math.floor(layout.left + player.x * layout.tileSize + 0.5),
      math.floor(layout.top + player.y * layout.tileSize + 0.5),
      player.facing or "down" }, ":")
  end

  -- Shared with skins so map drawing, marker hits and motion use one geometry.
  H.mapLayout, H.mapMotionKey = mapLayout, mapMotionKey

  function H:explorerMotionKey(model, player)
    local layout = mapLayout(model.overview, 7, model.mapFull and 72 or 53,
      226, model.mapFull and 138
        or model.view == "wild" and model.selected and 42 or 84, {
        player = player, focus = model.selectedMarker
          and model.selectedMarker.kind == "trainer" and model.selectedMarker or player,
        full = model.mapFull, zoom = model.mapZoom,
      })
    return mapMotionKey(layout, player)
  end

  function H:homeMotionKey(model, player)
    local keys = {}
    for _, tile in ipairs(model.tiles or {}) do
      if tile.widget == "explorer" then
        local x, y, w, h = self:homeExplorerRect(model, tile)
        local key = mapMotionKey(mapLayout(model.overview,
          x, y, w, h, { player = player }), player)
        if key then keys[#keys + 1] = key end
      end
    end
    return #keys > 0 and "HOME:" .. table.concat(keys, "/") or nil
  end

  function H:mapOverview(overview, x, y, w, h, opts)
    opts = opts or {}
    local G, colors = ui.graphics, self.colors
    if overview and overview.disabled then
      self:panel(x, y, w, h, false)
      self:partyInfoCentered(self:fitPartyInfo(translate("LIVE MAP DISABLED"), w - 8), x + 4, y, w - 8, h, colors.mutedInk)
      return nil
    end
    local snapshot = opts.snapshot
    if snapshot then
      local layout = mapLayout(overview, x, y, w, h, opts)
      if not layout then return nil end
      local key = table.concat({ tostring(opts.cacheKey), x, y, w, h,
        layout.left, layout.top, layout.tileSize }, ":")
      if not snapshot.canvas or snapshot.canvasKey ~= key then
        if not snapshot.canvas or snapshot.canvas:getWidth() ~= w + 1
            or snapshot.canvas:getHeight() ~= h + 1 then
          if snapshot.canvas then snapshot.canvas:release() end
          -- Keep the panel's one-pixel shadow inside the cached viewport.
          snapshot.canvas = G.newCanvas(w + 1, h + 1)
          snapshot.canvas:setFilter("nearest", "nearest")
        end
        local previous = G.getCanvas()
        G.push("all")
        G.setCanvas(snapshot.canvas)
        G.origin(); G.setScissor(); G.setShader()
        G.setBlendMode("alpha"); G.clear(0, 0, 0, 0)
        local live = {}
        for k, v in pairs(opts) do if k ~= "snapshot" then live[k] = v end end
        -- Player motion must not rebake a stationary camera's terrain/NPC layer.
        live.drawPlayer = nil
        live.retainFrame = nil
        local ok, err = pcall(self.mapOverview, self, overview, 0, 0, w, h, live)
        G.setCanvas(previous)
        G.pop()
        if not ok then error(err) end
        snapshot.canvasKey = key
      end
      G.push("all")
      if opts.retainFrame then
        G.setScissor(layout.innerX, layout.innerY, layout.innerW, layout.innerH)
      end
      G.setBlendMode("alpha", "premultiplied")
      color({ 1, 1, 1, 1 })
      G.draw(snapshot.canvas, x, y)
      local player = opts.player
      if opts.drawPlayer and player and player.x ~= nil and player.y ~= nil then
        G.setBlendMode("alpha")
        G.setScissor(layout.innerX, layout.innerY, layout.innerW, layout.innerH)
        opts.drawPlayer(player,
          math.floor(layout.left + (player.x + 0.5) * layout.tileSize + 0.5),
          math.floor(layout.top + player.y * layout.tileSize + 0.5) + layout.tileSize,
          layout.tileSize)
      end
      G.pop()
      return layout
    end
    if not opts.retainFrame then self:panel(x, y, w, h, false) end
    local layout = mapLayout(overview, x, y, w, h, opts)
    if not layout then return nil end
    local rows, width, height, density = layout.rows, layout.width,
      layout.height, layout.density
    local innerX, innerY, innerW, innerH = layout.innerX, layout.innerY,
      layout.innerW, layout.innerH
    local scale, left, top = layout.scale, layout.left, layout.top
    local focus = opts.player or {}

    G.setScissor(innerX, innerY, innerW, innerH)
    box("fill", innerX, innerY, innerW, innerH,
      self:mapColor(overview, 1, 1, density, 1))
    if overview.drawTerrain then
      color({ 1, 1, 1, 1 })
      overview.drawTerrain(left, top, layout.tileSize)
    elseif opts.image then
      color({ 1, 1, 1, 1 })
      G.draw(opts.image, left, top, 0, scale, scale)
    else
      for rowIndex, row in ipairs(rows) do
        for column = 1, #row do
          box("fill", left + (column - 1) * scale,
            top + (rowIndex - 1) * scale, scale, scale,
            self:mapColor(overview, column, rowIndex, density,
              row:sub(column, column)))
        end
      end
    end

    local tileSize = layout.tileSize
    local function tile(marker)
      return math.floor(left + marker.x * tileSize + 0.5),
        math.floor(top + marker.y * tileSize + 0.5),
        math.floor(left + (marker.x + 0.5) * tileSize + 0.5),
        math.floor(top + (marker.y + 0.5) * tileSize + 0.5)
    end
    local function tileFrame(tx, ty, tint)
      box("fill", tx - 1, ty - 1, tileSize + 2, 1, tint)
      box("fill", tx - 1, ty + tileSize, tileSize + 2, 1, tint)
      box("fill", tx - 1, ty, 1, tileSize, tint)
      box("fill", tx + tileSize, ty, 1, tileSize, tint)
    end
    local markers = opts.markers or overview.markers or {}
    for index, marker in ipairs(markers) do
      if mapMarkerVisible(marker, opts.visible) then
        local mx, my, anchorX, anchorY = tile(marker)
        if opts.selected == marker or opts.selected == index then
          tileFrame(mx, my, marker.kind == "trainer" and colors.blueLight
            or colors.amberLight)
        end
        if marker.kind == "trainer" or marker.gift then
          if opts.drawTrainer then
            opts.drawTrainer(marker, anchorX, my + tileSize, tileSize)
          end
        elseif marker.kind == "fruit" then
          local unit = math.max(1, math.floor(tileSize / 9))
          self:fruitIcon(anchorX - math.floor(7 * unit / 2),
            anchorY - math.floor(9 * unit / 2), unit, marker.picked)
        elseif marker.kind == "hidden" then
          local tint = marker.found and colors.silverDark or colors.blueLight
          local shine = marker.found and colors.silver or colors.white
          if tileSize < 9 then
            box("fill", anchorX - 1, anchorY - 3, 3, 7, colors.outline)
            box("fill", anchorX - 3, anchorY - 1, 7, 3, colors.outline)
            box("fill", anchorX, anchorY - 2, 1, 5, tint)
            box("fill", anchorX - 2, anchorY, 5, 1, tint)
            box("fill", anchorX, anchorY, 1, 1, shine)
          else
            local unit = math.floor(tileSize / 9)
            box("fill", anchorX - unit - 1, anchorY - 3 * unit - 1,
              3 * unit + 2, 7 * unit + 2, colors.outline)
            box("fill", anchorX - 4 * unit - 1, anchorY - unit - 1,
              9 * unit + 2, 3 * unit + 2, colors.outline)
            box("fill", anchorX - unit, anchorY - 3 * unit,
              3 * unit, 7 * unit, tint)
            box("fill", anchorX - 4 * unit, anchorY - unit,
              9 * unit, 3 * unit, tint)
            box("fill", anchorX - unit, anchorY - unit,
              3 * unit, 3 * unit, shine)
          end
        elseif marker.kind == "item" then
          local tint = marker.found and colors.silverDark or colors.redLight
          local shine = marker.found and colors.silver or colors.white
          if tileSize < 7 then
            local ballX, ballY = anchorX - 2, my + tileSize - 5
            box("fill", ballX + 1, ballY, 3, 1, colors.outline)
            box("fill", ballX, ballY + 1, 5, 3, colors.outline)
            box("fill", ballX + 1, ballY + 4, 3, 1, colors.outline)
            box("fill", ballX + 1, ballY + 1, 3, 1, tint)
            box("fill", ballX + 1, ballY + 3, 3, 1, shine)
            box("fill", ballX + 2, ballY + 2, 1, 1, shine)
          else
            local unit = math.floor(tileSize / 7)
            local ballX = anchorX - math.floor(7 * unit / 2)
            local ballY = my + tileSize - 7 * unit
            box("fill", ballX + 2 * unit, ballY, 3 * unit, unit,
              colors.outline)
            box("fill", ballX + unit, ballY + unit, 5 * unit, unit,
              colors.outline)
            box("fill", ballX, ballY + 2 * unit, 7 * unit, 3 * unit,
              colors.outline)
            box("fill", ballX + unit, ballY + 5 * unit, 5 * unit, unit,
              colors.outline)
            box("fill", ballX + 2 * unit, ballY + 6 * unit, 3 * unit, unit,
              colors.outline)
            box("fill", ballX + 2 * unit, ballY + unit, 3 * unit, unit, tint)
            box("fill", ballX + unit, ballY + 2 * unit, 5 * unit, unit, tint)
            box("fill", ballX + unit, ballY + 4 * unit, 5 * unit, unit,
              shine)
            box("fill", ballX + 2 * unit, ballY + 5 * unit, 3 * unit, unit,
              shine)
            box("fill", ballX + 3 * unit, ballY + 3 * unit, unit, unit,
              shine)
          end
        elseif marker.kind == "warp" then
          box("fill", mx, my, tileSize, tileSize, colors.outline)
          local inset = math.max(1, math.floor(tileSize / 4))
          local inner = math.max(1, tileSize - inset * 2)
          box("fill", mx + inset, my + inset, inner, inner, colors.blueLight)
        end
      end
    end

    if focus.x ~= nil and focus.y ~= nil then
      local _, py, anchorX = tile(focus)
      if opts.drawPlayer then
        opts.drawPlayer(focus, anchorX, py + tileSize, tileSize)
      end
    end
    G.setScissor()
    return layout
  end

  function H:mapMarkerAt(x, y, overview, frame, opts)
    local layout = mapLayout(overview, frame.x, frame.y, frame.w, frame.h,
      opts or {})
    if not layout or x < layout.innerX or x >= layout.innerX + layout.innerW
        or y < layout.innerY or y >= layout.innerY + layout.innerH then
      return nil
    end
    local best, distance
    for index, marker in ipairs((opts and opts.markers)
        or overview.markers or {}) do
      if mapMarkerVisible(marker, opts and opts.visible) then
        local mx = layout.left + (marker.x + 0.5) * layout.tileSize
        local my = layout.top + (marker.y + 0.5) * layout.tileSize
        local d = (x - mx) ^ 2 + (y - my) ^ 2
        local radius = math.max(12, layout.tileSize)
        if d <= radius ^ 2 and (not distance or d < distance) then
          best, distance = index, d
        end
      end
    end
    return best
  end

  local fruitShape = { { 3, 1 }, { 3, 3 }, { 2, 3 }, { 1, 5 },
    { 0, 7 }, { 0, 7 }, { 0, 7 }, { 1, 5 }, { 2, 3 } }
  function H:fruitIcon(x, y, unit, picked)
    local colors = self.colors
    local tint = picked and (self.dark and colors.silver or colors.silverDark)
      or colors.redLight
    for row, span in ipairs(fruitShape) do
      box("fill", x + span[1] * unit, y + (row - 1) * unit,
        span[2] * unit, unit, row <= 3 and colors.green or tint)
    end
    local inset = picked and 3 * unit or unit
    box("fill", x + 2 * unit, y + 4 * unit, inset, inset,
      picked and colors.surface or colors.white)
  end

  -- Movement repaints only the opaque map panel on the retained page canvas.
  function H:explorerMap(model, retained)
    local colors, mapFocus = self.colors, explorerMapFocus(model)
    local mapX, mapW = 7, 226
    local mapY = model.mapFull and 72 or 53
    local mapH = model.mapFull and 138
      or model.view == "wild" and model.selected and 42 or 84
    self:mapOverview(model.overview, mapX, mapY, mapW, mapH, {
      retainFrame = retained,
      snapshot = model.mapSnapshot, cacheKey = model.mapCacheKey,
      image = model.image, player = model.player, markers = model.markers,
      focus = mapFocus,
      selected = model.selectedMarker, drawPlayer = model.drawPlayer,
      drawTrainer = model.drawTrainer, full = model.mapFull,
      zoom = model.mapZoom,
    })
    if model.canScan and model.player and mapFocus == model.player then
      local layout = mapLayout(model.overview, mapX, mapY, mapW, mapH, {
        full = model.mapFull, player = model.player, focus = mapFocus,
        zoom = model.mapZoom,
      })
      if layout then
        local G = ui.graphics
        local px = layout.left + (model.player.x + 0.5) * layout.tileSize
        local py = layout.top + (model.player.y + 0.5) * layout.tileSize
        local cue = math.max(6, math.floor(layout.tileSize * 0.75))
        G.setScissor(layout.innerX, layout.innerY, layout.innerW, layout.innerH)
        color(colors.greenLight)
        G.circle("line", px, py, cue)
        if model.scanProgress and model.scanProgress < 1 then
          G.circle("line", px, py,
            math.max(cue + 2, layout.tileSize * math.sqrt(41)
              * model.scanProgress))
        elseif model.scanHint then
          local label = translate("SCAN")
          local width = math.max(24, fontWidth(partyTypeFont, label) + 8)
          local left = math.max(layout.innerX + 2,
            math.min(layout.innerX + layout.innerW - width - 2,
              math.floor(px - width / 2)))
          local top = math.max(layout.innerY + 2, math.floor(py - cue - 13))
          clipped(left, top, width, 10, colors.surface)
          border(left, top, width, 10, colors.outline)
          self:partyType(label, left, top - 1, colors.ink, width)
          box("fill", math.floor(px) - 1, top + 10, 3, 2, colors.outline)
        end
        G.setScissor()
      end
    end
  end

  function H:explorer(model)
    local colors, view, selected = self.colors, model.view, model.selected
    local function mapToggle(x, y, collapse)
      local pressed = self:beginPress(x, y, 19, 14, not (model.overview and model.overview.disabled))
      self:panel(x, y, 19, 14, false)
      if collapse then
        box("fill", x + 5, y + 3, 4, 1, colors.ink)
        box("fill", x + 8, y + 3, 1, 3, colors.ink)
        box("fill", x + 10, y + 3, 4, 1, colors.ink)
        box("fill", x + 10, y + 3, 1, 3, colors.ink)
        box("fill", x + 5, y + 10, 4, 1, colors.ink)
        box("fill", x + 8, y + 8, 1, 3, colors.ink)
        box("fill", x + 10, y + 10, 4, 1, colors.ink)
        box("fill", x + 10, y + 8, 1, 3, colors.ink)
      else
        local left, right, top, bottom = x + 4, x + 14, y + 3, y + 10
        box("fill", left, top, 3, 1, colors.ink)
        box("fill", left, top, 1, 3, colors.ink)
        box("fill", right - 2, top, 3, 1, colors.ink)
        box("fill", right, top, 1, 3, colors.ink)
        box("fill", left, bottom, 3, 1, colors.ink)
        box("fill", left, bottom - 2, 1, 3, colors.ink)
        box("fill", right - 2, bottom, 3, 1, colors.ink)
        box("fill", right, bottom - 2, 1, 3, colors.ink)
      end
      self:endPress(pressed)
    end
    local function zoomControls(y, zoom)
      box("fill", 29, y + 2, 1, 12, colors.band)
      box("fill", 63, y + 2, 1, 12, colors.band)
      box("fill", 83, y + 2, 1, 12, colors.band)
      local minusPressed = self:beginPress(11, y, 18, 16, zoom > 1)
      box("fill", 17, y + 7, 6, 2, zoom > 1 and colors.green or colors.mutedInk)
      self:endPress(minusPressed)
      self:partyType(zoom .. "/3", 31, y + 2, colors.green, 31)
      local plusPressed = self:beginPress(64, y, 18, 16, zoom < 3)
      box("fill", 70, y + 7, 6, 2, zoom < 3 and colors.green or colors.mutedInk)
      box("fill", 72, y + 5, 2, 6, zoom < 3 and colors.green or colors.mutedInk)
      self:endPress(plusPressed)
    end
    local function mapProgress(y)
      if not model.showMapStats then return end
      local width = 144
      local half = math.floor(width / 2)
      local function itemGlyph(x)
        box("fill", x + 2, y + 3, 5, 1, colors.outline)
        box("fill", x + 1, y + 4, 7, 1, colors.outline)
        box("fill", x, y + 5, 9, 7, colors.outline)
        box("fill", x + 1, y + 6, 7, 5, colors.white)
        box("fill", x + 1, y + 6, 7, 2, colors.amberLight)
        box("fill", x + 4, y + 8, 1, 1, colors.outline)
      end
      box("fill", 85 + half, y + 2, 1, 12, colors.band)
      local itemWidth = fontWidth(partyInfoFont, model.itemsText)
      local itemLeft = 85 + math.floor((half - 9 - 3 - itemWidth) / 2)
      itemGlyph(itemLeft)
      self:partyInfo(model.itemsText, itemLeft + 12, y + 2, colors.ink)
      local trainerWidth = fontWidth(partyInfoFont, model.trainersText)
      local hasTrainer = model.drawActor and model.trainerIcon
      local iconWidth, gap = hasTrainer and 8 or 0, hasTrainer and 3 or 0
      local trainerLeft = 86 + half
        + math.floor((width - half - 1 - iconWidth - gap - trainerWidth) / 2)
      if hasTrainer then
        model.drawActor(model.trainerIcon, trainerLeft + 4, y + 8,
          0.5, false)
      end
      self:partyInfo(model.trainersText,
        trainerLeft + iconWidth + gap, y + 2, colors.ink)
    end
    self:panel(7, 32, 226, 18, false, nil, colors.greenLight)
    self:partyInfo(self:fitPartyInfo(model.route or translate("UNKNOWN AREA"),
      56), 12, 35, colors.ink, 56, "center")
    self:partyType(self:fitPartyType(model.subarea or translate("OUTDOORS"),
      82), 72, 36, colors.green, 82)
    self:partyInfo(self:fitPartyInfo(model.region or "KANTO", 36),
      160, 35, colors.green, 36, "center")
    mapToggle(207, 34, model.mapFull)

    if model.mapFull then
      self:panel(7, 53, 226, 16, false, nil, colors.greenLight)
      zoomControls(53, model.mapZoom or 1)
      mapProgress(53)
    end
    self:explorerMap(model)
    if model.mapFull then return end

    local function chip(x, y, width, label, active, arrow, translated)
      if not translated then label = translate(label) end
      self:tab(x, y, width, 16, label, active, arrow,
        not active or (model.page or 1) > 1)
    end
    local function pager(x, y, width, page, pages)
      local pressed = self:beginPress(x, y, width, 16, pages > 1)
      self:panel(x, y, width, 16, false)
      local label = page .. "/" .. pages
      if pages > 1 then label = "< " .. label .. " >" end
      self:partyType(label, x, y + 2, colors.green, width)
      self:endPress(pressed)
    end
    if selected and view == "wild" then
      local wildAccent = self:typeColor(selected.type)
      self:panel(7, 99, 226, 111, false, nil, wildAccent)
      local status = selected.gift and (selected.excluded and "ALTERNATIVE CHOICE"
        or selected.done and (selected.catchGoal and "CAUGHT" or "RECORDED")
        or selected.noRoom and "NEED SPACE" or selected.status or "OPEN")
        or selected.caught and "CAUGHT" or "NOT CAUGHT"
      local name = self:fitPartyInfo(selected.name, selected.gift and 140 or 100)
      status = self:fitPartyInfo(translate(status), selected.gift and 140 or 100)
      local portraitX, textX, textWidth, badgeX = 16, 58, 100, 58
      if selected.gift then
        local dual = selected.type2 and selected.type2 ~= selected.type
        textWidth = math.max(self:partyInfoWidth(name), self:partyInfoWidth(status), dual and 43 or 23)
        portraitX = 7 + math.floor((226 - 42 - textWidth) / 2)
        textX = portraitX + 42
        badgeX = textX + math.floor((textWidth - (dual and 43 or 23)) / 2) - (dual and 0 or 10)
      end
      self:partyPortrait(portraitX, 106, false, false)
      if model.drawPokemon then model.drawPokemon(selected, portraitX, 109, 34) end
      self:partyInfo(name, textX, 107, colors.ink,
        selected.gift and textWidth or nil, selected.gift and "center" or nil)
      self:partyInfo(status, textX, 122, colors.green,
        selected.gift and textWidth or nil, selected.gift and "center" or nil)
      if not selected.isEgg then self:typeBadges(selected, badgeX, 136, false) end
      if selected.gift then
        self:panel(12, 150, 216, 53, false, nil, wildAccent)
        self:partyType(self:fitPartyType(translate(selected.method), 202), 19, 155, colors.green, 202)
        local requirement = selected.needsSpeciesName and string.format(translate("BRING %s"), selected.needsSpeciesName)
          or selected.coinCost and string.format(translate("%d COINS"), selected.coinCost)
          or selected.cost and "$" .. tostring(selected.cost) or translate("TALK TO NPC")
        local gender = selected.needsGender == "TRADE_GENDER_FEMALE" and "female"
          or selected.needsGender == "TRADE_GENDER_MALE" and "male"
        requirement = self:fitPartyInfo(requirement, gender and 188 or 202)
        local width = gender and self:partyInfoWidth(requirement) or 202
        local left = gender and 19 + math.floor((202 - width - 14) / 2) or 19
        self:partyInfo(requirement, left, 169, colors.ink, width, "center")
        if gender then self:genderIcon(gender, left + width + 4, 169) end
        self:partyType(selected.isEgg and translate("EGG") or selected.level and "L" .. tostring(selected.level) or translate("TALK TO NPC"),
          19, 190, colors.green, 202)
        return
      end
      if model.encounterDetails == false then return end
      if model.detailPages > 1 then
        pager(166, 106, 58, model.detailPage, model.detailPages)
      else
        self:partyType(translate("HABITAT"), 166, 111,
          colors.green, 58)
      end
      local detailRows = model.detailRows or {}
      local function levels(appearance)
        return appearance.minLevel == appearance.maxLevel
          and "L" .. tostring(appearance.minLevel)
          or "L" .. tostring(appearance.minLevel) .. "-"
            .. tostring(appearance.maxLevel)
      end
      if #detailRows == 1 then
        local appearance = detailRows[1]
        local status = appearance.blocked and "NEEDS TOOL" or appearance.current and "HERE NOW"
        self:panel(12, 150, 216, 53, false, nil,
          appearance.current and colors.greenLight or wildAccent)
        if appearance.current then
          box("fill", 14, 152, 212, 49, colors.bandLight)
        end
        self:partyInfo(self:fitPartyInfo(appearance.section or model.route,
          status and 132 or 202), 19, 156, colors.ink)
        if status then
          self:partyType(self:fitPartyType(translate(status), 66), 154, 157,
            colors.green, 66)
        end
        local stats = {
          { translate("TIME"), translate(appearance.time or "ANY TIME") },
          { translate("METHOD"), translate(appearance.method or "--") },
          { translate("CHANCE"), tostring(appearance.chance or "--") .. "%" },
          { translate("LEVEL"), levels(appearance) },
        }
        for index, stat in ipairs(stats) do
          local x = 15 + (index - 1) * 53
          self:partyType(self:fitPartyType(stat[1], 47), x + 2, 174,
            colors.green, 47)
          self:partyInfo(self:fitPartyInfo(stat[2], 47), x + 2, 188,
            colors.ink, 47, "center")
        end
      else
        for index, appearance in ipairs(detailRows) do
          local y = 149 + (index - 1) * 27
          local status = appearance.blocked and "NEEDS TOOL" or appearance.current and "HERE NOW"
          self:panel(12, y, 216, 24, false, nil,
            appearance.current and colors.greenLight or wildAccent)
          if appearance.current then
            box("fill", 14, y + 2, 212, 20, colors.bandLight)
          end
          self:partyInfo(self:fitPartyInfo(appearance.section or model.route,
            status and 105 or 140), 17, y + 3, colors.ink)
          if status then
            self:partyType(self:fitPartyType(translate(status), 96), 125, y + 3,
              colors.green, 96)
          end
          local detail = translate(appearance.time or "ANY TIME") .. " "
            .. "· " .. translate(tostring(appearance.method or "--")) .. " · "
            .. tostring(appearance.chance or "--") .. "%"
          self:partyType(self:fitPartyType(detail, 116), 17, y + 13,
            colors.green, 116)
          self:partyInfo(levels(appearance), 166, y + 13,
            colors.ink, 55, "center")
        end
      end
      return
    elseif selected and view == "fruit" then
      local tint = selected.picked and colors.mutedInk or colors.green
      self:panel(7, 140, 226, 70, false, nil, tint)
      local name = self:fitPartyInfo(selected.label, 190)
      local width = self:partyInfoWidth(name)
      local left = 7 + math.floor((226 - 14 - 6 - width) / 2)
      self:fruitIcon(left, 149, 2, selected.picked)
      self:partyInfo(name, left + 20, 152, colors.ink)
      self:partyInfo(self:fitPartyInfo(translate(selected.picked
        and "PICKED TODAY" or "READY TO PICK"), 210),
        15, 176, tint, 210, "center")
      self:partyType(self:fitPartyType(translate("REGROWS DAILY"), 210),
        15, 194, colors.green, 210)
      return
    elseif selected and view == "items" then
      self:panel(7, 140, 226, 70, false, nil, colors.amberLight)
      self:battleItemIcon({ icon = selected.kind == "hidden" and "item"
        or selected.icon or "item" }, 15, 166, colors.amberLight)
      self:partyInfo(self:fitPartyInfo(selected.displayLabel or selected.label,
        75), 38, 157, colors.ink)
      self:partyType(self:fitPartyType(translate(selected.done and "FOUND"
        or selected.status == "NOT TRACKED" and "UNKNOWN"
        or selected.status or "OPEN"), 72), 38, 181, colors.green, 72)
      box("fill", 120, 147, 1, 56, colors.band)
      self:partyType(self:fitPartyType(translate(selected.gift and "NPC GIFT"
        or selected.kind == "hidden" and "HIDDEN" or "VISIBLE"), 100), 126, 158, colors.green, 100)
      self:partyInfo(self:fitPartyInfo(translate(selected.location
        or "ON THIS MAP"), 100), 126, 180, colors.ink, 100, "center")
      return
    elseif selected and view == "trainers" then
      self:panel(7, 140, 226, 70, false, nil, colors.blueLight)
      if model.drawActor then model.drawActor(selected, 23, 180, 1, false) end
      local trainerLine1, trainerLine2 = self:splitPartyInfo(
        selected.label, 75)
      local trainerNameY = trainerLine2 and 151 or 157
      self:partyInfo(trainerLine1,
        39 + math.floor((75 - self:partyInfoWidth(trainerLine1)) / 2),
        trainerNameY, colors.ink)
      if trainerLine2 then
        self:partyInfo(trainerLine2,
          39 + math.floor((75 - self:partyInfoWidth(trainerLine2)) / 2),
          trainerNameY + 12, colors.ink)
      end
      local trainerState = selected.missed and "MISSED"
        or selected.done and "BEATEN" or selected.status or "OPEN"
      self:partyType(self:fitPartyType(translate(trainerState), 75),
        39, 181, colors.green, 75)
      box("fill", 120, 147, 1, 56, colors.band)
      self:partyType(self:fitPartyType(translate("TRAINER"), 100),
        126, 158, colors.green, 100)
      local trainerDetail = selected.missed and "UNAVAILABLE"
        or selected.status == "LATER" and "STORY EVENT"
        or selected.status or "ON THIS MAP"
      self:partyInfo(self:fitPartyInfo(translate(trainerDetail), 100),
        126, 180, colors.ink, 100, "center")
      return
    end

    if view == "wild" then
      self:panel(7, 140, 226, 20, false)
      chip(12, 142, 74, "HERE NOW", model.wildScope ~= "ROUTE")
      chip(89, 142, 76, "WHOLE ROUTE", model.wildScope == "ROUTE")
      if model.pages > 1 then
        pager(168, 142, 58, model.page, model.pages)
      else
        chip(168, 142, 58, tostring(model.total) .. " " .. translate("PKMN"),
          false, false, true)
      end
      local baseY = 166
      for index, row in ipairs(model.rows) do
        local lineCount = #model.rows
        local groupWidth = lineCount * 56 - 22
        local x = math.floor((240 - groupWidth) / 2) + (index - 1) * 56
        local uncaught = not row.caught
        local pressed = self:beginPress(x - 11, baseY, 56, 44)
        self:partyPortrait(x, baseY, false, uncaught)
        if model.drawPokemon then
          model.drawPokemon(row, x + 1, baseY + 4, 32, uncaught)
        end
        if row.gift then
          self:partyType(translate(row.trade and "TRADE" or row.loan and "LOAN" or (row.cost or row.coinCost) and "OFFER" or "GIFT"),
            x - 9, baseY + 36, row.available and colors.ink or colors.mutedInk, 52)
        elseif row.best and model.encounterDetails ~= false then
          local odds = tostring(row.best.chance or 0) .. "%"
          local method = self:fitPartyType(translate(row.best.method),
            52 - fontWidth(partyTypeFont, odds) - 4)
          self:partyType(method .. " " .. odds, x - 9, baseY + 36,
            row.best.current and colors.ink or colors.mutedInk, 52)
        end
        self:endPress(pressed)
      end
      if #model.rows == 0 then
        self:partyInfo(translate(model.emptyHint or (model.wildScope == "ROUTE"
          and "NO WILD ENCOUNTERS" or "NOTHING HERE NOW")), 7, 180,
          colors.green, 226, "center")
      end
      return
    end
  end

  function H:explorerHit(x, y, model)
    x, y = x * 1.5, y * 1.5
    local view, selected = model.view, model.selected
    local mapFocus = explorerMapFocus(model)
    local mapX, mapW = 7, 226
    local mapY = model.mapFull and 72 or 53
    local mapH = model.mapFull and 138
      or view == "wild" and (selected and 42 or 84)
      or 84
    if not (model.overview and model.overview.disabled) and x >= 202 and x < 232 and y >= 32 and y < 50 then
      return "map_toggle"
    end
    if model.mapFull and y >= 53 and y < 69 then
      if x >= 11 and x < 29 and (model.mapZoom or 1) > 1 then return "zoom_out" end
      if x >= 64 and x < 82 and (model.mapZoom or 1) < 3 then return "zoom_in" end
      return nil
    end
    if model.canScan and model.player and mapFocus == model.player then
      local layout = mapLayout(model.overview, mapX, mapY, mapW, mapH, {
        full = model.mapFull, player = model.player, focus = mapFocus,
        zoom = model.mapZoom,
      })
      if layout then
        local px = layout.left + (model.player.x + 0.5) * layout.tileSize
        local py = layout.top + (model.player.y + 0.5) * layout.tileSize
        local radius = math.max(12, layout.tileSize)
        if (x - px) ^ 2 + (y - py) ^ 2 <= radius ^ 2 then
          return "player_scan"
        end
      end
    end
    local marker = self:mapMarkerAt(x, y, model.overview,
      { x = mapX, y = mapY, w = mapW, h = mapH }, {
        player = model.player, focus = mapFocus, markers = model.markers,
        full = model.mapFull, zoom = model.mapZoom,
      })
    if marker then return "marker", marker end
    if model.mapFull then return nil end
    if model.selected then
      if model.view == "wild" and x >= 166 and x < 224
          and y >= 106 and y < 122 and model.detailPages > 1 then
        return x < 195 and "detail_prev" or "detail_next"
      end
      return nil
    end
    if model.view == "wild" then
      if y >= 142 and y < 158 then
        if x >= 12 and x < 86 then return "wild_here" end
        if x >= 89 and x < 165 then return "wild_route" end
        if x >= 168 and x < 226 and model.pages > 1 then
          return x < 197 and "prev" or "next"
        end
      end
      if y < 166 or y >= 210 then return nil end
      local lineCount = #model.rows
      local groupWidth = lineCount * 56 - 22
      local left = math.floor((240 - groupWidth) / 2)
      for column = 0, lineCount - 1 do
        local portraitX = left + column * 56
        if x >= portraitX - 11 and x < portraitX + 45 then
          return "row", column + 1
        end
      end
      return nil
    end
  end

end
