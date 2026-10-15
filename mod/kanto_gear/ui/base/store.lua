return function(H, ui, draw, home, icons)
  local border, box, clipped, color =
    draw.border, draw.box, draw.clipped, draw.color
  local drawHomeIcon, fontText, fontWidth = home.drawHomeIcon, icons.fontText, draw.fontWidth
  local homeIcons, mixed, partyTypeFont, trainerNumberFont =
    home.homeIcons, draw.mixed, draw.partyTypeFont, draw.trainerNumberFont
  local trainerStatIcon, translate =
    icons.trainerStatIcon, draw.translate

  function H:storePreview(app, x, y, w, h, interactive)
    local G, colors = ui.graphics, self.colors
    local quiet = colors.mutedInk
    app = type(app) == "table" and app or { id = app }
    local id, preview = app.id, app.preview or {}
    local pressed = self:beginPress(x, y, w, h, interactive ~= false)
    if self:shadowVisible() then
      clipped(x + 1, y + 2, w, h, colors.shadow)
    end
    clipped(x, y, w, h, mixed(colors.surface, colors.blueLight, 0.08))
    border(x, y, w, h, colors.outline)
    local detailed = w >= 180
    local top, height = y + 1, h - 2
    local accent = ({
      explorer = colors.green, map = colors.blue, party = colors.green,
      pokedex = colors.red, bag = colors.amber, trainer = colors.blue,
      steps = colors.green, tools = colors.green, notes = colors.amber,
    })[id] or colors.blue
    if detailed then
      box("fill", x + 6, top + 5, 76, 1, accent)
      self:partyType(translate("PREVIEW"), x + 86, top + 1,
        accent, 54)
      box("fill", x + 144, top + 5, 76, 1, accent)
      top, height = top + 10, height - 10
    end
    local function miniCard(left, cardTop, width, cardHeight, tint)
      clipped(left, cardTop, width, cardHeight,
        mixed(colors.surface, tint or colors.band, self.dark and 0.12 or 0.08))
      border(left, cardTop, width, cardHeight, colors.outline)
    end
    if id == "pss" then
      local gap, cardW = 4, math.floor((w - 16) / 3)
      local left = x + math.floor((w - (cardW * 3 + gap * 2)) / 2)
      for i = 0, 2 do
        local cx = left + i * (cardW + gap)
        local cy = top + math.floor((height - 34) / 2)
        miniCard(cx, cy, cardW, 34, colors.blue)
        local center = cx + math.floor(cardW / 2)
        box("fill", center - 3, cy + 6, 6, 6, colors.blue)
        box("fill", center - 5, cy + 14, 10, 6, colors.blue)
        box("fill", cx + 5, cy + 26, cardW - 10, 2, quiet)
      end
    elseif id == "explorer" then
      local mapW = detailed and 128 or w - 10
      local left, mapTop = x + 5, top + 4
      if preview.overview then
        self:mapOverview(preview.overview, left, mapTop, mapW, height - 8, {
          image = preview.image, player = preview.player,
          markers = preview.markers, drawPlayer = preview.drawPlayer,
          drawTrainer = preview.drawTrainer,
        })
      else
        clipped(left, mapTop, mapW, height - 8, colors.bandLight)
        border(left, mapTop, mapW, height - 8, colors.outline)
        box("fill", left + 1, mapTop + 9, mapW - 2, 17,
          colors.amberLight)
        box("fill", left + 16, mapTop + 6, 21, 4, colors.green)
        box("fill", left + mapW - 35, mapTop + 26, 25, 5,
          colors.blueLight)
        self:battleTeamBall(left + math.floor(mapW / 2), mapTop + 17, true)
      end
      if detailed then
        self:partyType(translate("HERE NOW"), x + 140, top + 5,
          colors.green, 76)
        for index = 1, 3 do
          local row = preview.rows and preview.rows[index]
          local left_ = x + 142 + (index - 1) * 29
          color(colors.outline); G.circle("fill", left_ + 7, top + 27, 8)
          color(colors.surface); G.circle("fill", left_ + 7, top + 27, 7)
          if row and preview.drawPokemon then
            preview.drawPokemon(row, left_ + 1, top + 21, 13,
              row.caught == false)
          else
            self:battleTeamBall(left_ + 7, top + 27, true)
          end
        end
        box("fill", x + 142, top + 43, 69, 2, quiet)
      end
    elseif id == "map" then
      local left, mapTop = x + 7, top + 5
      local mapW, mapH = w - 14, height - 10
      clipped(left, mapTop, mapW, mapH, colors.bandLight)
      border(left, mapTop, mapW, mapH, colors.outline)
      local points = {
        { 12, 10 }, { 32, 10 }, { 51, 18 }, { 72, 18 },
        { 91, 9 }, { 112, 9 }, { 131, 21 }, { 153, 21 },
        { 174, 12 }, { 195, 12 },
      }
      color(colors.blue); G.setLineWidth(3)
      for index = 1, #points - 1 do
        G.line(left + points[index][1], mapTop + points[index][2],
          left + points[index + 1][1], mapTop + points[index + 1][2])
      end
      G.setLineWidth(1)
      for index, point in ipairs(points) do
        color(colors.outline); G.circle("fill", left + point[1],
          mapTop + point[2], index == 6 and 5 or 3)
        color(index == 6 and colors.redLight or colors.surface)
        G.circle("fill", left + point[1], mapTop + point[2],
          index == 6 and 3 or 2)
      end
      self:partyType(self:fitPartyType(preview.region or "JOHTO", 48),
        left + 5, mapTop + mapH - 12, colors.green, 48)
      self:partyType(self:fitPartyType(preview.location or "ROUTE 39",
        mapW - 67), left + 59, mapTop + mapH - 12, colors.ink,
        mapW - 65)
    elseif id == "party" then
      local gap, cardW = 4, math.floor((w - 14) / 2)
      local tints = { colors.blueLight, colors.greenLight, colors.redLight,
        colors.amberLight, colors.silver, colors.greenLight }
      for index = 0, 5 do
        local column, row = index % 2, math.floor(index / 2)
        local left = x + 5 + column * (cardW + gap)
        local cardTop = top + 5 + row * 17
        clipped(left, cardTop, cardW, 15,
          mixed(colors.party, tints[index + 1], self.dark and 0.10 or 0.08))
        border(left, cardTop, cardW, 15, colors.partyDark)
        color(mixed(colors.surface, tints[index + 1],
          self.dark and 0.24 or 0.15))
        G.circle("fill", left + 10, cardTop + 7, 7)
        local mon = preview.party and preview.party[index + 1]
        if mon and preview.drawPokemon then
          preview.drawPokemon(mon, left + 3, cardTop, 14)
        else
          self:battleTeamBall(left + 10, cardTop + 7, mon ~= false)
        end
        local name = mon and self:fitPartyType(mon.name or translate("POKEMON"),
          cardW - 27) or "---"
        self:partyType(name, left + 20, cardTop - 2, colors.white,
          cardW - 24)
        border(left + 20, cardTop + 9, cardW - 26, 4, colors.outline)
        local ratio = mon and tonumber(mon.hpRatio)
          or mon and (tonumber(mon.hp) or 0)
            / math.max(1, tonumber(mon.maxHp) or 1)
          or index == 4 and 0 or index == 5 and 0.32 or 0.82
        ratio = math.max(0, math.min(1, ratio))
        box("fill", left + 21, cardTop + 10,
          math.floor((cardW - 28) * ratio), 2,
          ratio == 0 and quiet
            or ratio < 0.5 and colors.hpMid or colors.hp)
      end
    elseif id == "pokedex" then
      border(x + 7, top + 2, w - 14, 5, colors.outline)
      local dexProgress = tonumber(preview.progress) or 0.47
      box("fill", x + 8, top + 3,
        math.floor((w - 16) * math.max(0, math.min(1, dexProgress))), 3,
        colors.redLight)
      local gap, cardW = 4, math.floor((w - 18) / 3)
      local tints = { colors.greenLight, colors.silver, colors.green,
        colors.redLight, colors.amberLight, colors.blueLight }
      for index = 0, 5 do
        local column, row = index % 3, math.floor(index / 3)
        local left = x + 5 + column * (cardW + gap)
        local cardTop = top + 10 + row * 20
        miniCard(left, cardTop, cardW, 18,
          index == 0 and colors.redLight or colors.band)
        local row_ = preview.entries and preview.entries[index + 1]
        self:partyType(("%03d"):format(row_ and row_.dex or index + 1),
          left + 3, cardTop + 5, quiet, 25)
        color(colors.outline)
        G.circle("fill", left + cardW - 12, cardTop + 9, 8)
        color(colors.surface)
        G.circle("fill", left + cardW - 12, cardTop + 9, 7)
        if row_ and preview.drawPokemon then
          preview.drawPokemon(row_, left + cardW - 19, cardTop + 2, 14,
            row_.caught == false)
        else
          self:battleTeamBall(left + cardW - 12, cardTop + 9, true)
        end
      end
      self:partyType((preview.page or 1) .. "/" .. (preview.pages or 28),
        x + math.floor((w - 50) / 2), top + 50, colors.green, 50)
    elseif id == "bag" then
      local kinds = { "medicine", "ball", "status", "machine",
        "key", "medicine" }
      local gap, cardW = 4, math.floor((w - 14) / 2)
      for index = 0, 5 do
        local column, row = index % 2, math.floor(index / 2)
        local left = x + 5 + column * (cardW + gap)
        local cardTop = top + 5 + row * 17
        local item = preview.entries and preview.entries[index + 1]
        if item or not preview.entries then
          item = item or { icon = kinds[index + 1], label = "ITEM" }
          miniCard(left, cardTop, cardW, 15, self:itemAccent(item.icon))
          self:battleItemIcon(item, left + 2, cardTop - 1,
            self:itemAccent(item.icon))
          self:partyType(self:fitPartyType(item.label or translate("ITEM"), cardW - 49),
            left + 22, cardTop + 2, colors.ink, cardW - 46)
          self:partyType("x" .. tostring(item.count or 1),
            left + cardW - 23, cardTop + 2, quiet, 20)
        else
          miniCard(left, cardTop, cardW, 15, colors.band)
          self:partyType("---", left + 2, cardTop + 3,
            quiet, cardW - 4)
        end
      end
    elseif id == "trainer" then
      miniCard(x + 5, top + 4, 91, 26, colors.blueLight)
      G.push(); G.translate(x + 9, top + 7); G.scale(0.72, 0.72)
      self:homeTrainerIcon(0, 0); G.pop()
      self:partyType(self:fitPartyType(preview.name or "GOLD", 55),
        x + 34, top + 6, colors.ink, 57)
      self:partyType(self:fitPartyType(preview.region or "JOHTO", 55),
        x + 34, top + 15, colors.blue, 57)
      miniCard(x + 100, top + 4, 121, 26, colors.amberLight)
      for badge = 0, 7 do
        local owned = preview.badgeOwned and preview.badgeOwned[badge + 1]
        if owned == nil then owned = badge < 5 end
        color(owned and colors.amberLight or colors.silverDark)
        G.circle("fill", x + 111 + badge * 14, top + 17, 5)
        color(colors.outline); G.circle("line", x + 111 + badge * 14,
          top + 17, 5)
      end
      local statW = 69
      local statLabels = { "MONEY", "TIME", "POKEDEX" }
      local statValues = { preview.money or "¥67240",
        preview.time or "42:17", preview.pokedex or "118/251" }
      for stat = 0, 2 do
        local left = x + 5 + stat * 73
        miniCard(left, top + 34, statW, 21,
          ({ colors.amber, colors.blue, colors.red })[stat + 1])
        trainerStatIcon(self, ({ "money", "time", "pokedex" })[stat + 1],
          left + 12, top + 38,
          ({ colors.amber, colors.blue, colors.red })[stat + 1])
        self:partyType(self:fitPartyType(translate(statLabels[stat + 1]),
          statW - 25), left + 22, top + 35,
          quiet, statW - 25)
        self:partyType(self:fitPartyType(statValues[stat + 1], statW - 25),
          left + 22, top + 44, colors.ink, statW - 25)
      end
    elseif id == "achievements" then
      local radius = detailed and 21 or 17
      for index, kind in ipairs({ "route", "forest", "cave" }) do
        self:achievementSeal(x + math.floor(w * (index - .5) / 3),
          top + math.floor(height / 2) - 3, radius, kind, index ~= 3)
      end
    elseif id == "steps" then
      local iconX = x + (detailed and 15 or 7)
      self:homeStepsIcon(iconX, top + math.floor((height - 26) / 2))
      local valueX, valueW = x + (detailed and 54 or 38),
        w - (detailed and 62 or 44)
      fontText(trainerNumberFont, preview.steps or "12,846", valueX, top + 7,
        colors.ink, valueW, "center")
      self:partyType(translate("STEPS TODAY"), valueX, top + 34,
        colors.green, valueW)
      local buttonTop = top + height - 14
      clipped(valueX + 20, buttonTop, valueW - 40, 10, colors.red)
      border(valueX + 20, buttonTop, valueW - 40, 10,
        colors.outline)
      self:partyType(translate("RESET"), valueX + 22,
        buttonTop, colors.white, valueW - 44)
    elseif id == "tools" then
      local kinds = { "bicycle", "fish", "cut", "surf" }
      local gap, cardW = 4, math.floor((w - 14) / 2)
      local cardH = math.floor((height - 8) / 2)
      for index, kind in ipairs(kinds) do
        local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
        local left = x + 5 + column * (cardW + gap)
        local cardTop = top + 2 + row * (cardH + 4)
        miniCard(left, cardTop, cardW, cardH,
          self:toolAccent(kind))
        local iconX = detailed and 8 or math.floor((cardW - 20) / 2)
        G.push()
        G.translate(left + iconX, cardTop + math.floor((cardH - 20) / 2))
        G.scale(0.72, 0.72)
        self:toolIcon(kind, 0, 0, self:toolAccent(kind))
        G.pop()
        if detailed then
          local labels = { "BICYCLE", translate("FISH"), "CUT", "SURF" }
          self:partyType(self:fitPartyType(labels[index],
            cardW - 35), left + 31,
            cardTop + math.floor((cardH - 8) / 2), colors.ink,
            cardW - 35)
        end
      end
    elseif id == "notes" then
      clipped(x + 6, top + 4, w - 12, height - 8, colors.surface)
      border(x + 6, top + 4, w - 12, height - 8, colors.outline)
      box("fill", x + 7, top + 5, w - 14, 8, colors.blue)
      local noteLabels = { "CALL MOM", "BUY POTIONS", "CHECK ROUTE 39" }
      for row = 0, 2 do
        local rowTop = top + 18 + row * 11
        local label = self:fitPartyType(translate(noteLabels[row + 1]), w - 33)
        local labelWidth = fontWidth(partyTypeFont, label)
        local groupWidth = 6 + 7 + labelWidth
        local groupLeft = x + math.floor((w - groupWidth) / 2)
        clipped(groupLeft, rowTop, 6, 6,
          row == 0 and colors.greenLight or colors.surface)
        border(groupLeft, rowTop, 6, 6,
          row == 0 and colors.outline or quiet)
        if row == 0 then
          box("fill", groupLeft + 1, rowTop + 3, 2, 2, colors.outline)
          box("fill", groupLeft + 3, rowTop + 2, 2, 2, colors.outline)
        end
        self:partyType(label, groupLeft + 13, rowTop - 1,
          row == 0 and colors.ink or quiet, labelWidth)
      end
    else
      local icon = homeIcons(self)[id]
      if icon then drawHomeIcon(icon, x + math.floor((w - 29) / 2),
        top + math.floor((height - 29) / 2), 29) end
    end
    self:endPress(pressed)
  end

  function H:storeRecommendation(x, y, w, app, icons)
    local G, colors = ui.graphics, self.colors
    local pressed = self:beginPress(x, y, w, 47)
    if self:shadowVisible() then
      color(colors.shadow); G.rectangle("fill", x + 1, y + 2, w, 47, 4, 4)
    end
    color(colors.surface); G.rectangle("fill", x, y, w, 47, 4, 4)
    color(colors.outline)
    G.rectangle("line", x + 0.5, y + 0.5, w - 1, 46, 4, 4)
    local icon = icons[app.icon]
    if icon then drawHomeIcon(icon, x + 4, y + 8, 29) end
    self:storeTitle(app.label, x + 36, y + 5, w - 39, app.new)
    self:partyType(self:fitPartyType(translate(app.reason), w - 39),
      x + 36, y + 18, colors.green, w - 39)
    self:partyType(translate(app.action or (app.state == "open"
      and "OPEN APP" or "VIEW")), x + 36, y + 31, colors.blueLight, w - 39)
    self:endPress(pressed)
  end

  function H:storeTitle(label, x, y, w, isNew)
    local colors = self.colors
    label = translate(label)
    if not isNew then
      self:partyType(self:fitPartyType(label, w), x, y, colors.ink, w)
      return
    end
    local badgeW, gap = 25, 4
    local shown = self:fitPartyType(label, w - badgeW - gap)
    local textW = fontWidth(partyTypeFont, shown)
    local groupW = textW + gap + badgeW
    local left = x + math.floor((w - groupW) / 2)
    self:partyType(shown, left, y, colors.ink, textW)
    self:storeNewBadge(left + textW + gap, y - 1, badgeW)
  end

  function H:storeInstalledRow(x, y, w, app, icons)
    local G, colors = ui.graphics, self.colors
    local blocked = app.state == "soon" and self:isPressed(x + w - 54, y + 9, 44, 11)
    local pressed = self:beginPress(x, y, w, 30, not blocked)
    if self:shadowVisible() then
      color(colors.shadow); G.rectangle("fill", x + 1, y + 2, w, 30, 4, 4)
    end
    color(colors.surface); G.rectangle("fill", x, y, w, 30, 4, 4)
    color(colors.outline)
    G.rectangle("line", x + 0.5, y + 0.5, w - 1, 29, 4, 4)
    local icon = icons[app.icon or app.id]
    if icon then drawHomeIcon(icon, x + 4, y + 2, 27) end
    self:storeTitle(app.label, x + 34, y + 3, 91, app.new)
    self:partyType(self:fitPartyType(translate(app.category), 91),
      x + 34, y + 15, colors.green, 91)
    self:storeMiniAction(x + w - 54, y + 9, 44,
      app.action or "OPEN APP",
      app.state)
    self:endPress(pressed)
  end

  function H:storeNav(active)
    local colors = self.colors
    for index, item in ipairs({
        { "today", "TODAY" }, { "apps", "APPS" },
        { "library", "MY APPS" },
      }) do
      local x, selected = 7 + (index - 1) * 76, active == item[1]
      local pressed = self:beginPress(x, 195, 73, 18, not selected)
      clipped(x, 195, 73, 18, selected and colors.green or colors.surface)
      border(x, 195, 73, 18, colors.outline)
      self:partyType(translate(item[2]), x + 2, 199,
        selected and colors.white or colors.ink, 69)
      self:endPress(pressed)
    end
  end

  function H:storePager(page, pages)
    page, pages = tonumber(page) or 1, tonumber(pages) or 1
    if pages < 2 then return false end
    self:pageChevron(161, 42, false)
    self:partyType(page .. "/" .. pages, 170, 36,
      self.colors.green, 43)
    self:pageChevron(222, 42, true)
    return true
  end

  function H:storeToday(model)
    local G, colors, icons = ui.graphics, self.colors, homeIcons(self)
    local featured = model.featured or {}
    local blocked = featured.state == "soon" and self:isPressed(57, 83, 56, 15)
    local pressed = self:beginPress(7, 32, 226, 89, not blocked)
    if self:shadowVisible() then
      color(colors.shadow); G.rectangle("fill", 8, 35, 226, 89, 5, 5)
    end
    color(colors.surface); G.rectangle("fill", 7, 32, 226, 89, 5, 5)
    color(colors.outline); G.rectangle("line", 7.5, 32.5, 225, 88, 5, 5)
    box("fill", 9, 34, 222, 15, colors.blue)
    local title = translate("APP OF THE DAY")
    if featured.new then
      local badgeW, gap = 25, 5
      local titleW = fontWidth(partyTypeFont, title)
      local groupW = badgeW + gap + titleW
      local left = 9 + math.floor((222 - groupW) / 2)
      self:storeNewBadge(left, 36, badgeW)
      self:partyType(title, left + badgeW + gap, 36,
        colors.white, titleW)
    else
      self:partyType(title, 12, 36, colors.white, 216)
    end
    color(mixed(colors.surface, colors.white, self.dark and 0.08 or 0.22))
    G.rectangle("fill", 13, 56, 39, 39, 5, 5)
    border(13, 56, 39, 39, colors.outline)
    local icon = icons[featured.icon or featured.id] or icons.tools
    drawHomeIcon(icon, 18, 61, 29)
    self:partyType(self:fitPartyType(translate(featured.label or "APP"), 60),
      55, 55, colors.ink, 60)
    self:partyType(self:fitPartyType(translate(featured.category or "UTILITY"),
      60), 55, 68, colors.green, 60)
    self:storeAction(57, 83, 56, featured.action or "GET",
      featured.state)
    self:storePreview(featured, 119, 52, 106, 64)
    self:endPress(pressed)
    self:partyType(translate("RECOMMENDED FOR YOU"), 10, 126,
      colors.green, 220)
    for index, app in ipairs(model.recommended or {}) do
      if index > 2 then break end
      self:storeRecommendation(7 + (index - 1) * 115, 142, 111,
        app, icons)
    end
    self:storeNav("today")
  end

  function H:storeApps(model)
    local colors, icons = self.colors, homeIcons(self)
    clipped(7, 32, 226, 17, colors.surface)
    border(7, 32, 226, 17, colors.outline)
    self:partyType(translate("DISCOVER APPS"), 10, 36, colors.ink, 132)
    if not self:storePager(model.page, model.pages) then
      self:partyType(translate("SILPH VERIFIED"), 122, 36,
        colors.green, 108)
    end
    for index, app in ipairs(model.apps or {}) do
      local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
      self:storeAppCard(7 + column * 115, 53 + row * 44, 111,
        app, icons)
    end
    self:storeNav("apps")
  end

  function H:storeMyApps(model)
    local colors, icons = self.colors, homeIcons(self)
    clipped(7, 32, 226, 21, colors.surface)
    border(7, 32, 226, 21, colors.outline)
    local summaryWidth = (model.pages or 1) > 1 and 134 or 220
    self:partyType(self:fitPartyType(model.summary or translate("APPS READY"),
      summaryWidth), 10, 37, colors.ink, summaryWidth)
    self:storePager(model.page, model.pages)
    for index, app in ipairs(model.apps or {}) do
      self:storeInstalledRow(7, 57 + (index - 1) * 33, 226,
        app, icons)
    end
    self:storeNav("library")
  end

end
