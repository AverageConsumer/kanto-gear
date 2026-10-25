return function(H, ui, draw, icons)
  local border, box, clipped, color =
    draw.border, draw.box, draw.clipped, draw.color
  local displayText, fontText, fontWidth = draw.displayText, icons.fontText, draw.fontWidth
  local mixed, partyTypeFont, trainerFit, trainerValueFont =
    draw.mixed, draw.partyTypeFont, icons.trainerFit, draw.trainerValueFont
  local translate =
    draw.translate

  function H:toolAccent(kind)
    local colors = self.colors
    if kind == "fish" or kind == "surf" or kind == "whirlpool"
        or kind == "waterfall" then return colors.blueLight end
    if kind == "bicycle" or kind == "dig" or kind == "teleport"
        or kind == "softboiled" then
      return colors.amberLight
    end
    if kind == "sweet_scent" then return colors.redLight end
    if kind == "squirtbottle" then return colors.blueLight end
    return colors.greenLight
  end

  function H:toolIcon(kind, x, y, tint)
    local G, colors = ui.graphics, self.colors
    tint = tint or self:toolAccent(kind)
    local function line(...)
      color(colors.outline); G.setLineWidth(4); G.line(...)
      color(tint); G.setLineWidth(2); G.line(...)
      G.setLineWidth(1)
    end
    local function ring(cx, cy, radius)
      color(colors.outline); G.setLineWidth(4); G.circle("line", cx, cy, radius)
      color(tint); G.setLineWidth(2); G.circle("line", cx, cy, radius)
      G.setLineWidth(1)
    end
    if kind == "bicycle" then
      ring(x + 7, y + 19, 5); ring(x + 21, y + 19, 5)
      line(x + 7, y + 19, x + 12, y + 10, x + 17, y + 19,
        x + 7, y + 19, x + 14, y + 19, x + 12, y + 10)
      line(x + 11, y + 8, x + 15, y + 8)
      line(x + 17, y + 19, x + 20, y + 10, x + 23, y + 9)
    elseif kind == "fish" then
      line(x + 5, y + 23, x + 9, y + 18, x + 16, y + 7, x + 22, y + 4)
      ring(x + 9, y + 18, 2)
      line(x + 22, y + 4, x + 24, y + 8, x + 24, y + 19,
        x + 21, y + 22, x + 19, y + 20)
    elseif kind == "cut" then
      ring(x + 7, y + 20, 4); ring(x + 19, y + 20, 4)
      line(x + 10, y + 17, x + 22, y + 4)
      line(x + 16, y + 17, x + 5, y + 5)
    elseif kind == "surf" then
      line(x + 3, y + 11, x + 7, y + 8, x + 11, y + 11,
        x + 15, y + 8, x + 19, y + 11, x + 23, y + 8)
      line(x + 3, y + 19, x + 7, y + 16, x + 11, y + 19,
        x + 15, y + 16, x + 19, y + 19, x + 23, y + 16)
    elseif kind == "strength" then
      color(colors.outline)
      G.polygon("fill", x + 4, y + 20, x + 6, y + 8, x + 12, y + 3,
        x + 21, y + 7, x + 24, y + 18, x + 19, y + 24, x + 9, y + 24)
      color(tint)
      G.polygon("fill", x + 6, y + 19, x + 8, y + 9, x + 13, y + 5,
        x + 19, y + 8, x + 22, y + 18, x + 18, y + 22, x + 10, y + 22)
      line(x + 9, y + 14, x + 16, y + 9, x + 20, y + 14)
    elseif kind == "flash" then
      ring(x + 14, y + 14, 5)
      for _, ray in ipairs({ {14,2,14,6}, {14,22,14,26}, {2,14,6,14},
          {22,14,26,14}, {5,5,8,8}, {20,20,23,23}, {5,23,8,20},
          {20,8,23,5} }) do line(x + ray[1], y + ray[2], x + ray[3], y + ray[4]) end
    elseif kind == "headbutt" then
      line(x + 14, y + 12, x + 14, y + 25)
      color(colors.outline); G.circle("fill", x + 14, y + 9, 9)
      color(tint); G.circle("fill", x + 14, y + 9, 7)
      box("fill", x + 12, y + 16, 4, 9, colors.outline)
      box("fill", x + 13, y + 16, 2, 9, tint)
    elseif kind == "whirlpool" then
      ring(x + 14, y + 14, 10); ring(x + 14, y + 14, 5)
      color(colors.surface); box("fill", x + 2, y + 10, 9, 7, colors.surface)
      line(x + 4, y + 14, x + 14, y + 14, x + 18, y + 10)
    elseif kind == "teleport" then
      line(x + 14, y + 3, x + 24, y + 14, x + 14, y + 25,
        x + 4, y + 14, x + 14, y + 3)
      line(x + 14, y + 8, x + 19, y + 14, x + 14, y + 20,
        x + 9, y + 14, x + 14, y + 8)
    elseif kind == "waterfall" then
      line(x + 7, y + 4, x + 7, y + 19)
      line(x + 14, y + 4, x + 14, y + 19)
      line(x + 21, y + 4, x + 21, y + 19)
      line(x + 3, y + 23, x + 7, y + 20, x + 11, y + 23,
        x + 15, y + 20, x + 19, y + 23, x + 24, y + 20)
    elseif kind == "sweet_scent" then
      for _, point in ipairs({ {14,6}, {21,11}, {18,20}, {10,20}, {7,11} }) do
        color(colors.outline); G.circle("fill", x + point[1], y + point[2], 5)
        color(tint); G.circle("fill", x + point[1], y + point[2], 3)
      end
      color(colors.outline); G.circle("fill", x + 14, y + 14, 5)
      color(colors.amberLight); G.circle("fill", x + 14, y + 14, 3)
    elseif kind == "dig" then
      line(x + 7, y + 4, x + 20, y + 18)
      color(colors.outline); G.polygon("fill", x + 16, y + 16, x + 24, y + 19,
        x + 20, y + 25, x + 14, y + 20)
      color(tint); G.polygon("fill", x + 17, y + 18, x + 22, y + 20,
        x + 20, y + 23, x + 16, y + 20)
      line(x + 4, y + 5, x + 8, y + 2, x + 11, y + 5)
    elseif kind == "softboiled" then
      color(colors.outline); G.ellipse("fill", x + 14, y + 15, 9, 12)
      color(tint); G.ellipse("fill", x + 14, y + 15, 7, 10)
      line(x + 10, y + 11, x + 14, y + 14, x + 11, y + 18)
    elseif kind == "squirtbottle" then
      clipped(x + 7, y + 9, 14, 16, colors.outline)
      clipped(x + 9, y + 11, 10, 12, tint)
      box("fill", x + 11, y + 4, 7, 7, colors.outline)
      box("fill", x + 12, y + 5, 5, 5, tint)
      line(x + 15, y + 4, x + 22, y + 4, x + 24, y + 7)
    else
      self:homeToolsIcon(x, y)
    end
    G.setLineWidth(1)
  end

  local function homeIcons(theme)
    if theme.v4HomeIcons then return theme:v4HomeIcons() end
    return {
      bag = {
        left = 1, top = 1, right = 24, bottom = 25,
        draw = function(x, y) theme:battleBagIcon(x, y) end,
      },
      pokedex = {
        left = 2, top = 1, right = 24, bottom = 25,
        draw = function(x, y) theme:homePokedexIcon(x, y) end,
      },
      trainer = {
        left = 1, top = 3, right = 25, bottom = 24,
        draw = function(x, y) theme:homeTrainerIcon(x, y) end,
      },
      steps = {
        left = 2, top = 3, right = 25, bottom = 24,
        draw = function(x, y) theme:homeStepsIcon(x, y) end,
      },
      achievements = {
        left = 1, top = 1, right = 26, bottom = 27,
        draw = function(x, y) theme:achievementSeal(x + 13, y + 13, 12, "forest", true) end,
      },
      party = {
        left = 2, top = 3, right = 26, bottom = 22,
        draw = function(x, y) theme:homePartyIcon(x, y) end,
      },
      tools = {
        left = 1, top = 1, right = 26, bottom = 26,
        draw = function(x, y) theme:homeToolsIcon(x, y) end,
      },
      explorer = {
        left = 1, top = 1, right = 25, bottom = 25,
        draw = function(x, y) theme:homeExplorerIcon(x, y) end,
      },
      map = {
        left = 2, top = 2, right = 24, bottom = 25,
        draw = function(x, y) theme:homeMapIcon(x, y) end,
      },
      store = {
        left = 1, top = 5, right = 25, bottom = 24,
        draw = function(x, y) theme:homeStoreIcon(x, y) end,
      },
      notes = {
        left = 2, top = 1, right = 23, bottom = 26,
        draw = function(x, y) theme:homeNotesIcon(x, y) end,
      },
      pss = {
        left = 2, top = 2, right = 24, bottom = 24,
        draw = function(x, y)
          box("fill", x + 12, y + 7, 3, 14, theme.colors.blue)
          box("fill", x + 5, y + 14, 17, 3, theme.colors.blue)
          for _, p in ipairs({ { 10, 2 }, { 2, 18 }, { 18, 18 } }) do
            box("fill", x + p[1], y + p[2], 7, 7, theme.colors.outline)
            box("fill", x + p[1] + 1, y + p[2] + 1, 5, 5, theme.colors.blueLight)
          end
        end,
      },
      settings = {
        left = 2, top = 1, right = 26, bottom = 26,
        draw = function(x, y) theme:homeSettingsIcon(x, y) end,
      },
    }
  end

  local function drawHomeIcon(icon, x, y, size)
    local width = icon.right - icon.left + 1
    local height = icon.bottom - icon.top + 1
    icon.draw(x + math.floor((size - width) / 2) - icon.left,
      y + math.floor((size - height) / 2) - icon.top)
  end

  function H:homeRect(tile)
    local column, row = tonumber(tile.column) or 1, tonumber(tile.row) or 1
    local columns = tonumber(tile.visualColumns)
      or tonumber(tile.columns) or 3
    local rows = tonumber(tile.rows) or 1
    return tonumber(tile.visualX) or 7 + (column - 1) * 19,
      32 + (row - 1) * 85,
      tonumber(tile.visualWidth) or columns * 17 + (columns - 1) * 2,
      rows * 82 + (rows - 1) * 3
  end

  function H:homeEmptyRect()
    return 31, 75, 178, 82
  end

  -- v4 skins reuse the same icon table for their own catalog layouts.
  function H:homeIconTable() return homeIcons(self) end

  function H:homeWidgetLibraryIcon(kind, x, y, item)
    local G, colors = ui.graphics, self.colors
    if kind == "explorer" then
      clipped(x + 2, y + 5, 25, 19, colors.outline)
      box("fill", x + 3, y + 6, 23, 17, colors.amberLight)
      box("fill", x + 3, y + 16, 9, 7, colors.greenLight)
      box("fill", x + 18, y + 6, 8, 6, colors.blueLight)
      box("fill", x + 13, y + 12, 3, 5, colors.red)
    elseif kind == "steps" then
      self:homeStepsIcon(x + 1, y + 1)
    elseif kind == "team" then
      for row = 0, 1 do
        for column = 0, 2 do
          local cx, cy = x + 6 + column * 8, y + 9 + row * 10
          color(colors.outline); G.circle("fill", cx, cy, 4)
          color(colors.redLight); G.circle("fill", cx, cy, 3)
          box("fill", cx - 2, cy + 1, 5, 2, colors.white)
          box("fill", cx - 3, cy, 7, 1, colors.outline)
          box("fill", cx, cy, 1, 1, colors.white)
        end
      end
    elseif kind == "pokedex" then
      self:homePokedexIcon(x + 1, y + 1)
    elseif kind == "trainer" then
      self:homeTrainerIcon(x + 1, y + 1)
    elseif kind == "map" then
      self:homeMapIcon(x + 1, y + 1)
    elseif kind == "bag" then
      ui.graphics.push()
      ui.graphics.translate(x + 2, y + 2)
      ui.graphics.scale(0.92, 0.92)
      self:battleBagIcon(0, 0)
      ui.graphics.pop()
    elseif kind == "store" then
      self:homeStoreIcon(x + 1, y + 1)
    elseif kind == "pss" then
      drawHomeIcon(homeIcons(self).pss, x + 1, y + 1, 27)
    elseif kind == "tool" then
      self:toolIcon(item and item.icon or "tools", x + 1, y + 1)
    else
      color(colors.outline); G.circle("fill", x + 14, y + 14, 12)
      color(colors.surface); G.circle("fill", x + 14, y + 14, 10)
      box("fill", x + 4, y + 13, 20, 2, colors.outline)
      color(colors.red); G.circle("fill", x + 14, y + 9, 4)
      color(colors.outline); G.circle("fill", x + 14, y + 14, 3)
      color(colors.white); G.circle("fill", x + 14, y + 14, 1)
    end
  end

  function H:homeTeamSlotRect(tile, slot)
    local x, y, w = self:homeRect(tile)
    return x + math.floor((w - 214) / 2) + (slot - 1) * 36,
      y + 22, 34, 56
  end

  function H:homeTeamSlotAt(x, y, tile, count)
    for slot = 1, math.min(6, count or 0) do
      local left, top, w, h = self:homeTeamSlotRect(tile, slot)
      if x >= left and x < left + w and y >= top and y < top + h then
        return slot
      end
    end
  end

  function H:homeTeam(model, tile, selected)
    local G, colors = ui.graphics, self.colors
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, colors.partyLight, selected)
    self:homeWidgetHeader(x, y, w, "TEAM VIEW", colors.party,
      colors.partyLight, model.editing)
    for slot = 1, 6 do
      local left, top, width, height = self:homeTeamSlotRect(tile, slot)
      local mon = model.team and model.team[slot]
      local pressed = self:beginPress(left, top, width, height,
        mon ~= nil and not model.editing)
      if mon then
        local fainted = not mon.egg and (mon.hp or 0) <= 0
        self:partyPortrait(left, top - 1, false, fainted)
        if model.drawPokemon then
          model.drawPokemon(mon, left + 1, top + 3, 32, fainted)
        end
        if mon.pokerus then
          box("fill", left + 25, top + 28, 9, 9, colors.surface)
          self:pokerusMark(mon.pokerus, left + 26, top + 29)
        end
        if mon.egg then
          self:partyType(translate("EGG"), left, top + 43, colors.green, width)
        else
          local label = displayText(mon.levelText or "--")
          local labelWidth = fontWidth(partyTypeFont, label)
          local statusWidth = mon.statusId and 11 or 0
          local labelLeft = left + math.floor((width - labelWidth - statusWidth) / 2)
          self:partyType(label, labelLeft, top + 39, colors.ink, labelWidth)
          if mon.statusId then
            self:statusIcon(mon.statusId, labelLeft + labelWidth + 3, top + 40)
          end
          self:hpBar(left + 2, top + 50, width - 4, mon.hp, mon.maxHp)
        end
      else
        color(colors.band)
        G.circle("line", left + 17, top + 19, 12)
        G.line(left + 5, top + 19, left + 29, top + 19)
        color(colors.surface); G.circle("fill", left + 17, top + 19, 3)
        color(colors.band); G.circle("line", left + 17, top + 19, 3)
      end
      self:endPress(pressed)
    end
  end

  function H:homePokedex(model, tile, selected)
    local colors = self.colors
    local quiet = colors.mutedInk
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, colors.redLight, selected)
    self:homeWidgetHeader(x, y, w, "POKEDEX", colors.red,
      colors.redLight, model.editing)
    local portraitX = x + 6
    self:partyPortrait(portraitX, y + 23, false, false)
    if model.drawDexPokemon and model.dexLatest then
      model.drawDexPokemon(model.dexLatest, portraitX + 2, y + 26, 30)
    else
      self:homePokedexIcon(portraitX + 4, y + 26)
    end
    local infoX, infoW = x + 43, w - 49
    self:partyType(self:fitPartyType(translate("CAUGHT"), infoW),
      infoX, y + 24, quiet, infoW)
    self:partyInfo((model.dexCaught or 0) .. "/" .. (model.dexTotal or 0),
      infoX, y + 34, colors.ink, infoW, "center")
    self:partyType(self:fitPartyType(translate("SEEN"), infoW - 20),
      infoX, y + 47, quiet, infoW - 20)
    self:partyInfo(tostring(model.dexSeen or 0), infoX + infoW - 20,
      y + 46, colors.green, 20, "right")
    self:expBar(infoX, y + 58, infoW,
      (model.dexCaught or 0) / math.max(1, model.dexTotal or 0))
    local latest = model.dexLatest and model.dexLatest.name or "---"
    self:partyType(self:fitPartyType(latest, w - 10),
      x + 5, y + 67, colors.ink, w - 10)
  end

  function H:homeMap(model, tile, selected)
    local colors = self.colors
    local map = model.regionMap or {}
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, colors.blueLight, selected)
    self:homeWidgetHeader(x, y, w, "MAP", colors.blue,
      colors.blueLight, model.editing)
    clipped(x + 5, y + 22, w - 10, h - 27,
      mixed(colors.surface, colors.blueLight, self.dark and 0.20 or 0.14))
    border(x + 5, y + 22, w - 10, h - 27, colors.outline)
    ui.graphics.setScissor(x + 6, y + 23, w - 12, h - 29)
    if map.drawMap then map.drawMap(x + 6, y + 23, w - 12, h - 29) end
    ui.graphics.setScissor()
    local area = self:fitPartyType(map.area or translate("UNKNOWN AREA"),
      w - 32)
    local areaWidth = math.max(44, fontWidth(partyTypeFont, area) + 8)
    clipped(x + 7, y + h - 19, areaWidth, 12, colors.surface)
    border(x + 7, y + h - 19, areaWidth, 12, colors.outline)
    self:partyType(area, x + 7, y + h - 19, colors.ink, areaWidth)
    local region = self:fitPartyType(map.region or "KANTO", 38)
    clipped(x + w - 45, y + 25, 38, 12, colors.bandLight)
    border(x + w - 45, y + 25, 38, 12, colors.outline)
    self:partyType(region, x + w - 45, y + 25, colors.blue, 38)
  end

  function H:homeBag(model, tile, selected)
    local colors = self.colors
    local counts = model.bag or {}
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, colors.amberLight, selected)
    self:homeWidgetHeader(x, y, w, "BAG", colors.amber,
      colors.amberLight, model.editing)
    local kinds = {
      { "item", counts.item or 0 },
      { "medicine", counts.medicine or 0 },
      { "ball", counts.ball or 0 },
      { "machine", counts.machine or 0 },
    }
    local gap, cardW, cardH = 5, math.floor((w - 15) / 2), 24
    for index, entry in ipairs(kinds) do
      local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
      local left = x + 5 + column * (cardW + gap)
      local top = y + 24 + row * 28
      local accent = self:itemAccent(entry[1])
      clipped(left, top, cardW, cardH,
        mixed(colors.surface, accent, self.dark and 0.24 or 0.16))
      border(left, top, cardW, cardH, colors.outline)
      self:battleItemIcon({ icon = entry[1] }, left + 2, top + 3, accent)
      box("fill", left + 20, top + 4, 1, cardH - 8, colors.band)
      local amount = entry[2] > 999 and "999+" or tostring(entry[2])
      self:partyInfo(self:fitPartyInfo(amount, cardW - 24),
        left + 22, top + 7, colors.ink, cardW - 24, "center")
    end
  end

  function H:homeStore(model, tile, selected)
    local colors = self.colors
    local promo = model.storePromo or {}
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, colors.greenLight, selected)
    self:homeWidgetHeader(x, y, w, "STORE", colors.green,
      colors.greenLight, model.editing)
    local wellX, wellY = x + 6, y + 30
    clipped(wellX, wellY, 31, 31,
      mixed(colors.surface, colors.white, self.dark and 0.08 or 0.24))
    border(wellX, wellY, 31, 31, colors.outline)
    local icons = homeIcons(self)
    local icon = icons[promo.icon or "store"] or icons.store
    drawHomeIcon(icon, wellX + 2, wellY + 2, 27)
    local infoX, infoW = x + 42, w - 48
    if promo.new then
      local badgeW = math.min(infoW, 36)
      clipped(infoX + math.floor((infoW - badgeW) / 2), y + 25,
        badgeW, 11, colors.red)
      border(infoX + math.floor((infoW - badgeW) / 2), y + 25,
        badgeW, 11, colors.outline)
      self:partyType(self:fitPartyType(translate("NEW"), badgeW - 4),
        infoX + math.floor((infoW - badgeW) / 2) + 2, y + 25,
        colors.white, badgeW - 4)
    end
    self:partyType(self:fitPartyType(translate(promo.label or "MY APPS"),
      infoW), infoX, y + (promo.new and 40 or 33), colors.ink, infoW)
    local category = promo.new and translate(promo.category or "APPS")
      or (promo.installed or 0) .. "/" .. (promo.available or 0)
    self:partyInfo(self:fitPartyInfo(category,
      infoW), infoX, y + (promo.new and 52 or 46), colors.green, infoW,
      "center")
    if not promo.new then
      clipped(infoX, y + 61, infoW, 12, colors.bandLight)
      border(infoX, y + 61, infoW, 12, colors.outline)
      self:partyType(translate("READY"), infoX, y + 61,
        colors.green, infoW)
    end
  end

  function H:homeSteps(model, tile, selected)
    local colors = self.colors
    local quiet = colors.mutedInk
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, colors.greenLight, selected)
    self:homeWidgetHeader(x, y, w, "STEPS", colors.green,
      colors.greenLight, model.editing)
    self:homeStepsIcon(x + 7, y + 33)
    local value = trainerFit(trainerValueFont, model.steps or "0", w - 44)
    fontText(trainerValueFont, value, x + 38, y + 36, colors.ink,
      w - 43, "center")
    self:partyType(self:fitPartyType(translate("TOTAL"), w - 44),
      x + 38, y + 54, quiet, w - 43)
  end

  function H:homePager(page, pages)
    pages = math.max(1, tonumber(pages) or 1)
    if pages < 2 then return end
    page = math.max(1, math.min(pages, tonumber(page) or 1))
    local G, colors = ui.graphics, self.colors
    if pages > 7 then
      local label = page .. "/" .. pages
      local width = math.max(24, fontWidth(partyTypeFont, label) + 8)
      local left = 120 - math.floor(width / 2)
      self:pageChevron(left - 10, 207, false, false)
      self:partyType(label, left, 202, colors.green, width)
      self:pageChevron(left + width + 10, 207, true, false)
      return
    end
    local gap, center = 9, 120
    local left = center - math.floor((pages - 1) * gap / 2)
    self:pageChevron(left - 13, 207, false, false)
    self:pageChevron(left + (pages - 1) * gap + 13, 207, true, false)
    for index = 1, pages do
      color(index == page and colors.greenLight or colors.silverDark)
      G.circle(index == page and "fill" or "line",
        left + (index - 1) * gap, 207, 2)
    end
  end

  function H:homeHelpLayout(tiles)
    local target = tiles and tiles[1]
    for _, tile in ipairs(tiles or {}) do
      if tile.kind == "widget" then target = tile; break end
    end
    local _, top = self:homeRect(target or {})
    return target, target and (top < 115 and 123 or 29) or 66
  end

  function H:homeHelpHit(x, y, tiles)
    local _, top = self:homeHelpLayout(tiles)
    return x >= 70 and x < 170 and y >= top + 62 and y < top + 79
  end

  function H:home(model)
    local colors = self.colors
    model = model or {}
    if model.library then self:homeCatalog(model); return end
    local touchX, touchY = self.touchX, self.touchY
    if model.help then self:setTouch() end
    local icon = homeIcons(self)
    if not model.editing and #(model.tiles or {}) == 0 then self:homeEmpty() end
    for _, slot in ipairs(model.slots or {}) do self:homePlus(slot) end
    for index, tile in ipairs(model.tiles or {}) do
      local selected = model.selected == index or model.selected == tile.id
      local x, y, w, h = self:homeRect(tile)
      local pressed = self:beginPress(x, y, w,
        tile.widget == "team" and not model.editing and 20 or h,
        model.editing or not tile.disabled)
      if tile.kind == "widget" and tile.widget == "explorer" then
        self:homeExplorer(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "achievements" then
        self:homeAchievements(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "party" then
        self:homeParty(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "team" then
        self:homeTeam(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "pokedex" then
        self:homePokedex(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "trainer" then
        self:homeTrainer(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "map" then
        self:homeMap(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "bag" then
        self:homeBag(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "store" then
        self:homeStore(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "pss" then
        self:homePss(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "daycare" and self.homeDaycare then
        self:homeDaycare(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "daycare_small" and self.homeDaycareSmall then
        self:homeDaycareSmall(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "calendar" and self.homeCalendar then
        self:homeCalendar(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "calendar_small" and self.homeCalendarSmall then
        self:homeCalendarSmall(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "shiny" and self.homeShinyHunt then
        self:homeShinyHunt(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "shiny_small" and self.homeShinyHuntSmall then
        self:homeShinyHuntSmall(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "steps" then
        self:homeSteps(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "tool" then
        self:homeTool(model, tile, selected)
      elseif tile.kind == "app" or tile.widget == "device" then
        self:homeAppButton(x, y, w, h,
          colors[tile.accent or "green"] or colors.green,
          tile.label or tile.id or "APP",
          tile.widget == "device" and self:v4ShortcutIcon(tile.icon) or icon[tile.icon or tile.id]
            or icon.tools, selected)
      end
      if not model.editing and model.unreadTiles and model.unreadTiles[tile.id] and self.homeUnreadDot then
        self:homeUnreadDot(x, y, w)
      end
      if model.editing then
        self:homeEditOverlay(tile, model.dragging == tile.id)
      end
      self:endPress(pressed)
    end
    self:homePager(model.page, model.pages)
    if model.help then
      self:setTouch(touchX, touchY)
      self:homeHelp(model.tiles)
    end
  end

  return {
    drawHomeIcon = drawHomeIcon,
    homeIcons = homeIcons,
  }
end
