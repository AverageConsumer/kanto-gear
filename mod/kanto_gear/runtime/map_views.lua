return function(
  MAP_EXIT, MAP_HIDDEN, MAP_ITEM, THEME, areaData, areaName,
  assist, box, button, centered, compat, displayRuntime,
  drawDim, fit, header, loadLocalMap, localMapGrid, localMapLayout,
  mod, outline, render, session, text
)
  function displayRuntime.openExplorerLocation(row)
    if not row.remote or not row.mapId or not row.x or not row.y or row.outsideMap then return false end
    displayRuntime.explorer.locationPreview = { location = row, locationPoint = row,
      locationEntrance = row.entrance }
    session.dirty = true
    return true
  end

  function displayRuntime.explorerLocationModel()
    local state = displayRuntime.explorer.locationPreview
    local point = state.locationPoint
    displayRuntime.loadAchievementLocation(point, state)
    return { view = "location", location = state.location, locationPoint = point,
      entrance = state.locationEntrance, inside = point == state.location,
      locationFloor = displayRuntime.LocationPreview.floor(point.mapId),
      section = displayRuntime.sectionName(point.mapId),
      drawLocation = (state.locationImage or state.locationRenderer)
        and function(x, y, w, h) displayRuntime.drawAchievementLocation(x, y, w, h, state) end }
  end

  function displayRuntime.loadAchievementLocation(row, preview)
    local state = preview or displayRuntime.achievements
    if state.locationMap == row.mapId and state.locationDark == THEME.hgss.dark then return end
    if state.locationImage and state.locationImage.release then state.locationImage:release() end
    if state.locationRenderer then state.locationRenderer:release(); state.locationRenderer = nil end
    state.locationMap, state.locationImage = row.mapId, nil
    state.locationDark = THEME.hgss.dark
    -- Build a detached, read-only map. Never enter/warp the live world or touch
    -- its MapLoader cache just because the user browses a different area.
    -- Game path [Gen 1/2/3]: remote map previews use each native tileset/map reader; all builds stay detached from the live world.
    local ok, result, density = pcall(function()
      if displayRuntime.gen3 then
        local renderer = assert(load(mod:read("adapters/gen3/map.lua"), "@kanto_gear/adapters/gen3/map.lua"))().new(
          render.G, require("src.core.game3.tileset_native"))
        if renderer:prepare(session.game.data.maps[row.mapId]) then state.locationRenderer = renderer
        else renderer:release() end
        return nil, 1
      end
      local gen2 = compat.isGen2()
      local def = (gen2 and session.game.data.gen2Maps or session.game.data.maps)[row.mapId]
      local tilesets = gen2 and session.game.data.gen2Tilesets or session.game.data.tilesets
      local tileset = def and tilesets and tilesets[def.tileset]
      if not def or not tileset then return nil end
      local copy = {}
      for key, value in pairs(def) do copy[key] = value end
      copy.id, copy.connections = row.mapId, {}
      local Map = require(gen2 and "src.world.gen2.Map" or "src.world.Map")
      local overview = require("src.world.MapOverview").build(Map.new(copy, tileset), {})
      local rows = overview.tileDetailRows or overview.tileRows
      if not rows or #rows == 0 then return nil end
      local d = overview.tileDetailRows and 4 or 2
      local pixels = love.image.newImageData(#rows[1], #rows)
      for y, line in ipairs(rows) do for x = 1, #line do
        local color = THEME.hgss:mapColor(overview, x, y, d, line:sub(x, x))
        pixels:setPixel(x - 1, y - 1, unpack(color))
      end end
      local image = render.G.newImage(pixels); image:setFilter("nearest", "nearest")
      if pixels.release then pixels:release() end
      return image, d
    end)
    if ok then state.locationImage, state.locationDensity = result, density
    else mod.log:warn("achievement map preview unavailable: %s", tostring(result)) end
  end

  function displayRuntime.drawAchievementLocation(x, y, w, h, preview)
    local state = preview or displayRuntime.achievements
    local image, row, renderer = state.locationImage, state.locationPoint or state.location, state.locationRenderer
    if not (image or renderer) or not row then return end
    local iw, ih
    if renderer then iw, ih = renderer.width, renderer.height else iw, ih = image:getDimensions() end
    local scale = math.max(1, w / iw, h / ih)
    local px, py = (row.x + .5) * state.locationDensity, (row.y + .5) * state.locationDensity
    local left = math.floor(math.max(x + w - iw * scale, math.min(x, x + w / 2 - px * scale)))
    local top = math.floor(math.max(y + h - ih * scale, math.min(y, y + h / 2 - py * scale)))
    render.G.push("all")
    local sx, sy = render.G.transformPoint(x, y)
    local right, bottom = render.G.transformPoint(x + w, y + h)
    render.G.setScissor(sx, sy, right - sx, bottom - sy)
    render.G.setColor(1, 1, 1, 1)
    if renderer then renderer:draw(left, top, scale) else render.G.draw(image, left, top, 0, scale, scale) end
    for _, point in ipairs(row.points or { row }) do
      local mx = math.floor(left + (point.x + .5) * state.locationDensity * scale)
      local my = math.floor(top + (point.y + .5) * state.locationDensity * scale)
      render.G.setColor(.08, .14, .12, 1); render.G.rectangle("fill", mx - 4, my - 4, 9, 9)
      render.G.setColor(1, .77, .21, 1); render.G.rectangle("fill", mx - 3, my - 3, 7, 7)
      render.G.setColor(.08, .14, .12, 1); render.G.rectangle("fill", mx - 1, my - 1, 3, 3)
    end
    render.G.pop()
  end

  local function drawLocalMap()
    local enhanced = assist("hidden_items")
    local overview = loadLocalMap()
    if THEME.style == "hgss" then
      header(THEME:translate("EXPLORER"),
        displayRuntime.explorer.selected ~= nil
          or displayRuntime.explorer.mapFull
          or displayRuntime.home.activeApp ~= nil, false)
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      if displayRuntime.explorer.locationPreview then
        THEME.hgss:achievements(displayRuntime.explorerLocationModel())
      elseif not overview then
        THEME.hgss:panel(7, 32, 226, 178, false)
        THEME.hgss:partyInfo(THEME:translate(not assist("area_map") and "LIVE MAP DISABLED" or "HOST UPDATE REQUIRED"), 31, 112,
          THEME.hgss.colors.ink, 178, "center")
      else
        local model = displayRuntime.explorerModel(overview)
        THEME.hgss:explorer(model)
        displayRuntime.mapRefresh.paintedPage = session.page
        displayRuntime.mapRefresh.paintedAt = love.timer.getTime()
        displayRuntime.mapRefresh.key = THEME.hgss:explorerMotionKey(model, model.player)
        displayRuntime.mapRefresh.terrainRevision = model.overview.drawTerrain
          and displayRuntime.nativeMap and displayRuntime.nativeMap:revision() or ""
      end
      render.G.pop()
      return
    end
    header(THEME:translate("LOCAL"), false, true)
    if not overview or overview.disabled then
      centered(THEME:translate(not assist("area_map") and "LIVE MAP DISABLED" or "HOST UPDATE REQUIRED"), 62, render.DARK)
    else
      local rows, width, height, density = localMapGrid(overview)
      local pos = mod.world:current()
      local focusX = pos and pos.mapId == overview.mapId and pos.x
        and (pos.x + 0.5) * density
      local focusY = pos and pos.mapId == overview.mapId and pos.y
        and (pos.y + 0.5) * density
      local scale, left, top = localMapLayout(
        width, height, session.localMapZoom, focusX, focusY, density)
      render.G.setScissor(2, 20, 156, 106)
      box("fill", left - 2, top - 2, width * scale + 4,
          height * scale + 4, THEME.localMap.border)
      local image = density > 1
        and session.loadLocalMapImage(overview, rows, width, height, density)
      if overview.drawTerrain then
        render.G.setColor(1, 1, 1, 1)
        overview.drawTerrain(left, top, density * scale)
      elseif image then
        render.G.setColor(1, 1, 1, 1)
        render.G.draw(image, left, top, 0, scale, scale)
      else
        for y, row in ipairs(rows) do
          for x = 1, #row do
            local cell = row:sub(x, x)
            local shade = density > 1 and cell or cell == " " and 2 or 1
            local c = THEME:localMapColor(
              overview, x, y, density, shade)
            box("fill", left + (x - 1) * scale, top + (y - 1) * scale,
                scale, scale, c)
            if cell == "+" then
              box("fill", left + (x - 0.75) * scale,
                  top + (y - 0.75) * scale,
                  math.max(1, scale / 2), math.max(1, scale / 2),
                  THEME.localMap.playerCore)
            end
          end
        end
      end
      if enhanced then
        for _, marker in ipairs(overview.markers or {}) do
          local x = math.floor(left + (marker.x + 0.5) * density * scale + 0.5)
          local y = math.floor(top + (marker.y + 0.5) * density * scale + 0.5)
          local c = marker.kind == "warp" and MAP_EXIT
            or marker.kind == "item" and MAP_ITEM or MAP_HIDDEN
          local size = density * scale
          box("fill", x - size / 2, y - size / 2, size, size, c)
        end
      end
      if pos and pos.mapId == overview.mapId and pos.x and pos.y then
        local px = left + (pos.x + 0.5) * density * scale
        local py = top + (pos.y + 0.5) * density * scale
        local direction = ({ up = { 0, -1 }, down = { 0, 1 },
          left = { -1, 0 }, right = { 1, 0 } })[pos.facing] or { 0, 1 }
        box("fill", px - 1, py - 1, 3, 3, THEME.localMap.player)
        box("fill", px, py, 1, 1, THEME.localMap.playerCore)
        box("fill", px + direction[1] * 2,
            py + direction[2] * 2, 1, 1, THEME.localMap.player)
      end
      render.G.setScissor()
      button(134, 22, 22, 16, session.localMapZoom .. "x", false)
    end
    box("fill", 4, 126, 152, 14, render.DARK)
    if enhanced then
      local remaining = areaData({ overview and overview.mapId or session.mapId }).remaining
      box("fill", 8, 132, 3, 3, MAP_EXIT)
      text(fit(THEME:translate("EXIT"), 7), 14, 130, render.PAPER)
      box("fill", 60, 132, 3, 3, MAP_ITEM)
      text(THEME:format("ITM%d", remaining[2] or 0), 66, 130, render.PAPER)
      box("fill", 111, 132, 3, 3, MAP_HIDDEN)
      text(THEME:format("HID%d", remaining[3] or 0), 117, 130, render.PAPER)
    else
      centered(areaName(session.mapId), 130, render.PAPER, nil, true)
    end
  end

  local function drawFlyPrompt()
    if THEME.style == "hgss" then
      render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:toolPrompt({ icon = "teleport", label = session.pendingFly.name, prompt = "FLY TO" })
      render.G.pop()
      return
    end
    drawDim(0.54, false)
    box("fill", 10, 38, 140, 91, render.MID)
    outline(10, 38, 140, 91, render.PAPER)
    centered(THEME:translate("FLY TO"), 49, render.DARK)
    centered(fit(session.pendingFly.name, 20), 66, render.INK, nil, true)
    button(18, 91, 58, 27, THEME:translate("YES"), true)
    button(84, 91, 58, 27, THEME:translate("NO"), false)
  end

  return drawFlyPrompt, drawLocalMap
end
