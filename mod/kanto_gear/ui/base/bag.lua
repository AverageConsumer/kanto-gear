return function(H, ui, draw)
  local border, box, clipped = draw.border, draw.box, draw.clipped
  local translate = draw.translate
  function H:battleBagWindow(bag)
    local items = bag.items or {}
    local count = math.min(bag.recent and 3 or 4, #items)
    local first = math.max(1, math.min((bag.index or 1) - 1,
      #items - count + 1))
    return first, count
  end

  function H:battleCatchLabel(chance)
    if chance == nil then return nil end
    if chance == math.floor(chance) then return ("%d%%"):format(chance) end
    return ("%.1f%%"):format(chance)
  end

  function H:battleItemIcon(item, x, y, tint)
    local colors = self.colors
    if item.cancel then
      self:chevron(x + 8, y + 8, false)
    elseif item.itemSprite then
      local sprite, G = item.itemSprite, ui.graphics
      local scale = 17 / math.max(sprite.width, sprite.height)
      G.setColor(1, 1, 1, 1)
      if sprite.quad then G.draw(sprite.image, sprite.quad, x, y, 0, scale, scale)
      else G.draw(sprite.image, x, y, 0, scale, scale) end
    elseif item.icon == "ball" then
      self:battleTeamBall(x + 8, y + 8, true)
    elseif item.icon == "medicine" then
      box("fill", x + 5, y + 1, 6, 2, colors.outline)
      box("fill", x + 3, y + 3, 10, 12, colors.outline)
      box("fill", x + 4, y + 4, 8, 10, colors.white)
      box("fill", x + 4, y + 6, 8, 5, colors.redLight)
      box("fill", x + 7, y + 7, 2, 3, colors.white)
    elseif item.icon == "status" then
      clipped(x + 1, y + 1, 15, 15, colors.white)
      border(x + 1, y + 1, 15, 15, colors.outline)
      box("fill", x + 7, y + 4, 3, 9, tint)
      box("fill", x + 4, y + 7, 9, 3, tint)
    elseif item.icon == "machine" then
      box("fill", x + 7, y + 2, 3, 1, colors.outline)
      box("fill", x + 5, y + 3, 7, 1, colors.outline)
      box("fill", x + 4, y + 4, 9, 1, colors.outline)
      box("fill", x + 3, y + 5, 11, 1, colors.outline)
      box("fill", x + 2, y + 6, 13, 5, colors.outline)
      box("fill", x + 3, y + 11, 11, 1, colors.outline)
      box("fill", x + 4, y + 12, 9, 1, colors.outline)
      box("fill", x + 5, y + 13, 7, 1, colors.outline)
      box("fill", x + 7, y + 14, 3, 1, colors.outline)
      box("fill", x + 7, y + 3, 3, 1, tint)
      box("fill", x + 5, y + 4, 7, 1, tint)
      box("fill", x + 4, y + 5, 9, 1, tint)
      box("fill", x + 3, y + 6, 11, 5, tint)
      box("fill", x + 4, y + 11, 9, 1, tint)
      box("fill", x + 5, y + 12, 7, 1, tint)
      box("fill", x + 7, y + 13, 3, 1, tint)
      box("fill", x + 7, y + 6, 3, 5, colors.outline)
      box("fill", x + 6, y + 7, 5, 3, colors.outline)
      box("fill", x + 7, y + 7, 3, 3, colors.bandLight)
    else
      box("fill", x + 5, y + 2, 6, 1, colors.outline)
      box("fill", x + 4, y + 3, 8, 4, colors.outline)
      box("fill", x + 6, y + 4, 4, 3, colors.white)
      box("fill", x + 2, y + 6, 12, 9, colors.outline)
      box("fill", x + 3, y + 7, 10, 7, colors.white)
      box("fill", x + 3, y + 7, 10, 3, tint)
      box("fill", x + 7, y + 10, 2, 2, colors.outline)
    end
  end

  function H:recentBagItem(item, y, enabled)
    local colors = self.colors
    local pressed = self:beginPress(6, y, 228, 33, enabled ~= false)
    self:panel(6, y, 228, 33, false, nil, colors.amberLight)
    self:battleItemIcon(item, 14, y + 8, self:itemAccent(item.icon))
    box("fill", 38, y + 5, 1, 23, colors.band)
    self:partyType(translate("LAST USED"), 45, y + 4, colors.mutedInk, 158)
    self:partyInfo(self:fitPartyInfo(item.label, 158), 45, y + 17,
      enabled ~= false and colors.ink or colors.disabledInk, 158, "center")
    self:partyInfo("x" .. tostring(item.count), 204, y + 12, colors.mutedInk, 24, "center")
    self:endPress(pressed)
  end

  function H:bagActionRect(index, count)
    return ui.itemPage.rect(index, count)
  end

  function H:bag(model)
    if model.detail then self:bagDetail(model) else self:bagOverview(model) end
  end

  function H:bagHit(x, y, model)
    if model.detail then
      local index = ui.itemPage.hit(model, x, y)
      if index then return "action", index end
      return nil
    end
    if model.recent and model.canUse ~= false and x >= 6 and x < 234
        and y >= 72 and y < 105 then return "recent" end
    if y >= 34 and y < 68 then
      if (model.pockets or 1) > 1 and x >= 48 and x < 69 then
        return "pocket", -1
      elseif (model.pockets or 1) > 1 and x >= 155 and x < 176 then
        return "pocket", 1
      elseif (model.pages or 1) > 1 and x >= 180 and x < 204 then
        return "page", -1
      elseif (model.pages or 1) > 1 and x >= 204 and x < 232 then
        return "page", 1
      end
    end
    for index = 1, #(model.entries or {}) do
      local col, row = (index - 1) % 2, math.floor((index - 1) / 2)
      local left, top = 6 + col * 116, (model.recent and 109 or 72) + row * 47
      if x >= left and x < left + 112 and y >= top and y < top + 43 then
        return "item", index
      end
    end
  end

  do
    local hitModel = { pockets = 4, pages = 2,
      entries = { {}, {}, {}, {}, {}, {} } }
    local action, delta = H:bagHit(58, 51, hitModel)
    assert(action == "pocket" and delta == -1
        and H:bagHit(10, 76, hitModel) == "item"
        and H:bagHit(220, 51, hitModel) == "page",
      "HGSS bag hitboxes match visible controls")
  end

  function H:battleBagHeader(bag, offsetX)
    local G, colors = ui.graphics, self.colors
    G.push()
    G.translate(offsetX or 0, 0)
    self:panel(5, 33, 230, 30, false)
    self:chevron(15, 48, false)
    box("fill", 27, 36, 1, 24, colors.band)
    self:battleBagIcon(32, 35)
    box("fill", 61, 36, 1, 24, colors.band)
    if bag.categorized then
      self:pageChevron(69, 48, false)
      self:pageChevron(178, 48, true)
    end
    self:partyInfo(self:fitPartyInfo(bag.title or translate("BAG"),
      bag.categorized and 96 or 112), bag.categorized and 74 or 65,
      42, colors.ink, bag.categorized and 99 or 114, "center")
    local pageX, pageWidth = 185, 44
    local pageText = ("%d/%d"):format(bag.index or 1, #(bag.items or {}))
    clipped(pageX, 39, pageWidth, 18, colors.bandLight)
    border(pageX, 39, pageWidth, 18, colors.outline)
    self:partyInfo(pageText, pageX
      + math.floor((pageWidth - self:partyInfoWidth(pageText)) / 2) + 1,
      42, colors.ink)
    G.pop()
  end

  function H:battleBagRows(bag, rowOffset)
    local first, count = self:battleBagWindow(bag)
    if bag.recent then self:recentBagItem(bag.recent, 66) end
    for row = 1, count do
      local index = first + row - 1
      self:battleBagRow(bag.items[index], index,
        (bag.recent and 103 or 66) + (row - 1) * 33, self.nativeFocus and bag.index == index,
        type(rowOffset) == "function" and rowOffset(row) or rowOffset)
    end
  end

  function H:battleBagHit(x, y, bag)
    y = y - self.battleBagOffsetY
    if bag.recent and x >= 6 and x < 234 and y >= 66 and y < 99 then return "recent" end
    local first, count = self:battleBagWindow(bag)
    local top = bag.recent and 103 or 66
    local row = math.floor((y - top) / 33)
    if x >= 7 and x < 233 and row >= 0 and row < count
        and y < top + row * 33 + 31 then return first + row end
  end

  function H:battleBag(bag, playerTeam, enemyTeam)
    local previousPressOffsetY = self.pressOffsetY
    self.pressOffsetY = (previousPressOffsetY or 0) + self.battleBagOffsetY
    ui.graphics.push()
    ui.graphics.translate(0, self.battleBagOffsetY)
    self:battleBagHeader(bag)
    self:battleBagRows(bag)
    ui.graphics.pop()
    self.pressOffsetY = previousPressOffsetY
    self:battleTeamStrip(playerTeam, enemyTeam)
  end

  function H:battleBagTransition(mon, drawPortrait, playerTeam, enemyTeam,
      bag, progress)
    local G = ui.graphics
    progress = math.max(0, math.min(1, progress or 0))
    local pageProgress = progress * progress * (3 - 2 * progress)

    G.push()
    G.translate(math.floor(240 * pageProgress + 0.5), 0)
    self:battleRoot(mon, drawPortrait, playerTeam, enemyTeam, 3)
    G.pop()

    G.push()
    G.translate(math.floor(-240 * (1 - pageProgress) + 0.5), 0)
    box("fill", 0, 0, 240, 216, self.colors.partyBg)
    self:battleBackdrop()
    self:battleBag(bag, playerTeam, enemyTeam)
    G.pop()
  end

end
