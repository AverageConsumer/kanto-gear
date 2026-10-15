return function(
  RADAR_FRAMES, RADAR_RED, THEME, areaData, areaName, assist,
  box, button, centered, color, compat, displayRuntime,
  drawDim, drawSprite, fit, glyphList, guideData, hasItemfinder,
  hasUnlockedTool, header, methodLines, outline, radarSignals, render,
  session, text
)
  local function drawStepsDetail()
    local exact = assist("journey_stats") and ("%.0f"):format(session.steps) or "--"
    header(THEME:translate("STEPS"), true)
    if THEME.style == "hgss" then
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:steps({ steps = exact })
      render.G.pop()
      return
    end
    box("fill", 76, 29, 7, 11, render.DARK)
    box("fill", 71, 37, 11, 9, render.DARK)
    box("fill", 69, 33, 3, 4, render.DARK)
    box("fill", 73, 30, 3, 4, render.DARK)
    centered(exact, 55, render.INK, #exact <= 12 and 2 or 1, true)
    centered(THEME:translate("TOTAL"), 82, render.DARK)
    button(34, 105, 92, 28, THEME:translate("RESET"), false)
  end

  -- Game path [Gen 2 vs Gen 1]: caught markers use 8px battle-HUD art in Gen 2 and the 16px BALL icon in Gen 1.
  local function drawCaughtBall(x, y)
    if session.spriteCache.__caughtBall == nil then
      local data = session.game and session.game.data or {}
      local path, size
      if compat.isGen2() then
        local hud = data.gen2MenuGfx and data.gen2MenuGfx.battleHud
        path = hud and hud.balls
        size = 8
      else
        path = data.icons and data.icons.icons and data.icons.icons.BALL
        size = 16
      end
      local ok, asset = false, nil
      if path then
        ok, asset = pcall(function()
          local image = require("src.render.Assets").image(path)
          local width, height = image:getDimensions()
          size = math.min(size, width, height)
          return { image = image,
            quad = render.G.newQuad(0, 0, size, size, width, height), scale = 8 / size }
        end)
      end
      session.spriteCache.__caughtBall = ok and asset or false
    end
    local asset = session.spriteCache.__caughtBall
    if not asset then return false end
    render.G.setColor(1, 1, 1, 1)
    render.G.draw(asset.image, asset.quad, x, y, 0, asset.scale, asset.scale)
    return true
  end

  local function drawGuide()
    local guide = guideData()
    session.guidePage = math.max(1, math.min(session.guidePage, guide.pages))
    header(THEME:format("GUIDE %d/%d", session.guidePage, guide.pages), false, true)
    text(fit(guide.name, 15), 4, 23, render.DARK)
    local progress = THEME:format("%d/%d", guide.caught, #guide.rows)
    text(progress, 156 - #glyphList(progress) * 6, 23, render.INK)

    box("fill", 4, 34, 152, 12, guide.complete and render.DARK or render.MID)
    local status = #guide.rows > 0 and guide.section
      or THEME:translate("NO WILD ENCOUNTERS")
    centered(fit(status, 25), 37, guide.complete and render.PAPER or render.INK)

    for slot = 1, 3 do
      local row = guide.rows[(session.guidePage - 1) * 3 + slot]
      if row then
        local y = 48 + (slot - 1) * 31
        box("fill", 3, y, 154, 29, row.caught and render.MID or render.PAPER)
        outline(3, y, 154, 29, render.INK)
        local tint = not row.caught and render.DARK or nil
        drawSprite(row.species, "front", 5, y + 1, 27, 27, tint)
        text(fit(row.name, 11) .. ">", 35, y + 3, render.INK)
        local caughtBall = row.caught and drawCaughtBall(147, y + 2)
        if assist("encounter_details") and guide.timed and (not row.caught or caughtBall) then
          local times = {}
          for _, time in ipairs({ "MORN", "DAY", "NITE" }) do
            times[#times + 1] = (row.mapAllTimes or row.mapTimes[time])
              and fit(THEME:translate(time), 1, false) or "-"
          end
          text(table.concat(times, " "), 112, y + 3, render.DARK)
        end
        if row.caught and not caughtBall then
          text(fit(THEME:translate("CAUGHT"), 7), 113, y + 3, render.DARK)
        end
        if assist("encounter_details") then
        local minLevel = row.currentMinLevel or row.minLevel
        local maxLevel = row.currentMaxLevel or row.maxLevel
        local levels = minLevel == maxLevel and THEME:format("L%d", minLevel)
          or THEME:format("L%d-%d", minLevel, maxLevel)
        local methods1, methods2
        if row.availability == "now" then
          methods1, methods2 = methodLines(row.currentMethods)
        elseif row.availability == "time" then
          local shown, seen = {}, {}
          for _, appearance in ipairs(row.appearances) do
            if appearance.rank == 2 then
              local label = THEME:format("%s %d%%",
                THEME:translate(appearance.time or "ALL"), appearance.chance)
              if not seen[label] then shown[#shown + 1], seen[label] = label, true end
            end
          end
          methods1 = fit(shown[1] or THEME:translate("NOT NOW"), 14)
          methods2 = fit(shown[2] or "", 14)
        else
          methods1, methods2 = fit(THEME:translate("OTHER AREA"), 14), ""
        end
        text(methods1, 35, y + 13, render.DARK)
        text(methods2, 35, y + 21, render.DARK)
        text(levels, 156 - #glyphList(levels) * 6, y + 15, render.DARK)
        end
      end
    end
  end

  displayRuntime.drawGuideDetail = function()
    local guide, row = guideData()
    for _, candidate in ipairs(guide.rows) do
      if candidate.species == displayRuntime.guideDetail.species then
        row = candidate break
      end
    end
    if not row then displayRuntime.guideDetail = nil; drawGuide(); return end
    local pages = math.max(1, tonumber(row.detailPages) or 1)
    local current = tonumber(displayRuntime.guideDetail.page) or 1
    displayRuntime.guideDetail.page = math.max(1, math.min(current, pages))
    header(THEME:format("WHERE %d/%d", displayRuntime.guideDetail.page,
      pages), true, pages > 1)
    text(fit(row.name, 17), 5, 24, render.INK)
    text(row.availability == "now" and THEME:translate("NOW")
      or row.availability == "time" and guide.time
      or THEME:translate("AREA"), 124, 24, render.DARK)
    for slot = 1, 3 do
      local appearance = row.appearances[
        (displayRuntime.guideDetail.page - 1) * 3 + slot]
      if appearance then
        local y = 36 + (slot - 1) * 33
        box("fill", 3, y, 154, 31, appearance.rank == 1 and render.MID or render.PAPER)
        outline(3, y, 154, 31, render.INK)
        text(fit(appearance.section, 23), 7, y + 4, render.INK)
        if assist("encounter_details") then
        local time = THEME:translate(appearance.time or "ALL")
        local method = THEME:translate(appearance.method)
        text(fit(THEME:format("%s %s %d%%", time, method,
          appearance.chance), 18), 7, y + 15, render.DARK)
        local levels = appearance.minLevel == appearance.maxLevel
          and THEME:format("L%d", appearance.minLevel)
          or THEME:format("L%d-%d", appearance.minLevel, appearance.maxLevel)
        text(levels, 156 - #glyphList(levels) * 6, y + 15, render.DARK)
        end
      end
    end
  end

  local function drawArea()
    local area = areaData()
    session.areaPage = math.max(1, math.min(session.areaPage, area.pages))
    local screen = area.screens[session.areaPage]
    header(THEME:format("AREA %d/%d", session.areaPage, area.pages), false, true)
    text(fit(area.name, 23), 5, 23, render.DARK)
    local complete = screen.total > 0 and screen.done == screen.total
    box("fill", 4, 34, 152, 12, complete and render.DARK or render.MID)
    local name = THEME:translate(screen.name)
    local emptySource = "NO " .. screen.name
    local empty = THEME:translate(emptySource)
    if empty == emptySource then empty = THEME:format("NO %s", name) end
    local status = screen.total == 0 and empty
      or complete and THEME:format("+ %s CLEARED +", name)
      or THEME:format("%s %d/%d", name, screen.done, screen.total)
    centered(status, 37, complete and render.PAPER or render.INK)

    for slot = 1, screen.perPage do
      local row = screen.rows[(screen.page - 1) * screen.perPage + slot]
      if row then
        local y = 49 + (slot - 1) * 22
        box("fill", 3, y, 154, 20, row.done and render.MID or render.PAPER)
        outline(3, y, 154, 20, render.INK)
        text(fit(row.label, 18), 8, y + 7, render.INK)
        local status = fit(THEME:translate(
          row.status or (row.done and "DONE" or "OPEN")), 5)
        text(status, 156 - #glyphList(status) * 6, y + 7, render.DARK)
      end
    end
    if screen.name == "HIDDEN" and assist("item_radar") then
      button(20, 118, 120, 20,
        THEME:translate(hasItemfinder() and "SCAN" or "NEED ITEMFINDER"), false)
    end
  end

  local function drawRadar()
    header(THEME:translate("ITEM RADAR"), true)
    if THEME.style == "hgss" then
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:explorerRadar({
        route = areaName(session.mapId),
        progress = math.min(1, session.radarFrame / RADAR_FRAMES),
        ready = session.radarFrame >= RADAR_FRAMES,
        signals = radarSignals(),
        gen3 = displayRuntime.gen3 ~= nil,
      })
      render.G.pop()
      return
    end
    text(fit(areaName(session.mapId), 23), 5, 22, render.DARK)
    local gx, gy, cell, cols, rows = 25, 34, 10, 11, 9
    -- Game path [Gen 3]: radar scan covers the native 15x11 viewport; Gen 1/2 use the narrower asymmetric Itemfinder region.
    if displayRuntime.gen3 then gx, gy, cell, cols, rows = 20, 34, 8, 15, 11 end
    box("fill", gx, gy, cols * cell, rows * cell, render.PAPER)
    for col = 0, cols do
      box("fill", gx + col * cell, gy, 1, rows * cell, render.DARK)
    end
    for row = 0, rows do
      box("fill", gx, gy + row * cell, cols * cell, 1, render.DARK)
    end

    local reachX, reachY = math.floor(cols / 2), math.floor(rows / 2)
    local cx, cy = gx + reachX * cell + cell / 2, gy + reachY * cell + cell / 2
    local progress = math.min(1, session.radarFrame / RADAR_FRAMES)
    local radius = math.sqrt((reachX * cell) ^ 2 + (reachY * cell) ^ 2) * progress
    if radius > 0 then
      render.G.setScissor(gx, gy, cols * cell, rows * cell)
      color(render.DARK)
      render.G.circle("line", cx, cy, radius)
      render.G.setScissor()
    end
    local signals = radarSignals()
    for _, signal in ipairs(signals) do
      local distance = math.sqrt((signal.dx * cell) ^ 2
        + (signal.dy * cell) ^ 2)
      if distance <= radius then
        box("fill", cx + signal.dx * cell - 2,
          cy + signal.dy * cell - 2, 5, 5, RADAR_RED)
      end
    end
    box("fill", cx - 3, cy - 3, 6, 6, render.INK)
    centered(session.radarFrame < RADAR_FRAMES and THEME:translate("SCANNING")
      or #signals == 0 and THEME:translate("NO SIGNAL")
      or THEME:format("SIGNALS %d", #signals), 132, render.DARK)
  end

  local function drawTools()
    if THEME.style == "hgss" then
      local view = displayRuntime.toolsView()
      header(THEME:translate("FIELD KIT"), true, view.pages > 1)
      render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:tools(view)
      render.G.pop()
      return
    end
    local pages = math.max(1, math.ceil(#session.tools / 6))
    local current = math.max(1, math.min(pages, session.tools.page or 1))
    local first = (current - 1) * 6 + 1
    local count = math.min(6, math.max(0, #session.tools - first + 1))
    header(pages > 1 and THEME:format("TOOLS %d/%d", current, pages)
      or THEME:translate("TOOLS"), THEME.style == "hgss"
        and displayRuntime.home.activeApp ~= nil,
      THEME.style ~= "hgss")
    if #session.tools == 0 then
      box("fill", 12, 42, 136, 58, render.MID)
      outline(12, 42, 136, 58, render.INK)
      if hasUnlockedTool(session.game and session.game.save) then
        centered(THEME:translate("NO ACTION HERE"), 59, render.INK)
        centered(THEME:translate("CONTEXT REQUIRED"), 76, render.DARK)
      else
        centered(THEME:translate("NO TOOLS UNLOCKED"), 59, render.INK)
        centered(THEME:translate("KEEP EXPLORING"), 76, render.DARK)
      end
      return
    end
    for slot = 1, count do
      local action = session.tools[first + slot - 1]
      local col, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
      button(3 + col * 78, 25 + row * 38, 76, 34, action.label, false)
    end
  end

  local function drawActionPrompt()
    if THEME.style == "hgss" then
      local icon = "tools"
      for _, model in ipairs(displayRuntime.toolModels()) do
        if model.id == session.pendingAction.id then icon = model.icon break end
      end
      render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:toolPrompt({ label = session.pendingAction.label, icon = icon })
      render.G.pop()
      return
    end
    drawDim(0.54, false)
    box("fill", 10, 38, 140, 91, render.MID)
    outline(10, 38, 140, 91, render.PAPER)
    centered(THEME:translate("USE"), 49, render.DARK)
    centered(fit(session.pendingAction.label, 20), 66, render.INK)
    button(18, 91, 58, 27, THEME:translate("YES"), true)
    button(84, 91, 58, 27, THEME:translate("NO"), false)
  end

  return drawActionPrompt, drawArea, drawCaughtBall, drawGuide, drawRadar, drawStepsDetail, drawTools
end
