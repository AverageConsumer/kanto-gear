return function(H, ui, draw)
  local border, box, clipped, color =
    draw.border, draw.box, draw.clipped, draw.color
  local fit, glyphs = draw.fit, draw.glyphs
  local text = draw.text

  function H:startMenuIcon(kind, x, y)
    local c = self.colors
    if kind == "pokemon" then
      self:battleTeamBall(x + 8, y + 8, "ready")
    elseif kind == "save" then
      border(x + 1, y + 1, 14, 14, c.ink)
      box("fill", x + 3, y + 2, 9, 4, c.blueLight)
      box("fill", x + 4, y + 9, 8, 5, c.silver)
      box("fill", x + 9, y + 2, 2, 4, c.ink)
    elseif kind == "quit" or kind == "quitContest" then
      border(x + 2, y + 1, 11, 14, c.ink)
      box("fill", x + 4, y + 3, 7, 10, c.redLight)
      box("fill", x + 9, y + 8, 1, 1, c.ink)
    elseif kind == "pokedex" then
      clipped(x + 2, y + 1, 12, 14, c.red)
      border(x + 2, y + 1, 12, 14, c.ink)
      box("fill", x + 5, y + 3, 6, 5, c.blueLight)
      box("fill", x + 5, y + 10, 3, 2, c.white)
    elseif kind == "pack" then
      border(x + 5, y + 1, 6, 4, c.ink)
      clipped(x + 2, y + 4, 12, 11, c.amber)
      border(x + 2, y + 4, 12, 11, c.ink)
      box("fill", x + 5, y + 9, 6, 4, c.amberLight)
    elseif kind == "option" then
      for i, knob in ipairs({ 4, 10, 7 }) do
        local yy = y + 3 + (i - 1) * 5
        box("fill", x + 1, yy, 14, 1, c.ink)
        box("fill", x + knob, yy - 1, 3, 3, c.green)
      end
    else
      border(x + 1, y + 2, 14, 12, c.ink)
      for i = 0, 2 do box("fill", x + 4, y + 5 + i * 3, 8, 1, c.green) end
    end
  end

  function H:partyInfoCentered(value, x, y, w, h, tint)
    local advance, left, top, right, bottom = 0, math.huge, math.huge, -1, -1
    for _, char in ipairs(glyphs(value)) do
      local bounds = ui.smallFontMetrics and ui.smallFontMetrics[char]
      if not bounds then left = math.huge; break end
      if bounds.right >= 0 then
        left, right = math.min(left, advance + bounds.left), math.max(right, advance + bounds.right)
        top, bottom = math.min(top, bounds.top), math.max(bottom, bounds.bottom)
      end
      advance = advance + bounds.advance
    end
    if left < math.huge then
      self:partyInfo(value, x + math.floor((w - (right - left + 1)) / 2) - left,
        y + math.floor((h - (bottom - top + 1)) / 2) - top, tint or self.colors.ink)
    else
      self:partyInfo(value, x + 4, y + math.floor((h - 9) / 2) - 1, tint or self.colors.ink, w - 8, "center")
    end
  end

  function H:levelUpHit(x, y)
    return x >= 42 and x < 198 and y >= 170 and y < 204
  end

  function H:partyActionRow(index, count)
    if count > 2 then
      local step = math.floor(108 / count)
      return 18, 102 + (index - 1) * step, 204, step - 4
    end
    return 18, count == 1 and 139 or 112 + (index - 1) * 49, 204, 40
  end

  function H:partyActionHeroY(count)
    if count > 2 then return 35 end
    return count == 1 and 67 or 44
  end

  function H:partyActionAt(x, y, count)
    for index = 1, count do
      local left, top, width, height = self:partyActionRow(index, count)
      if x >= left and x < left + width and y >= top
          and y < top + height then return index end
    end
  end

  function H:beginPartyAction(now)
    if self.motionEnabled == false then
      self.partyActionStarted = nil
      self.partyActionClosing = false
      self.partyActionCloseFrom = nil
      return
    end
    self.partyActionStarted = now
    self.partyActionClosing = false
    self.partyActionCloseFrom = nil
  end

  function H:endPartyAction(now)
    if self.motionEnabled == false then
      self.partyActionStarted = now - 1
      self.partyActionClosing = true
      return
    end
    self.partyActionCloseFrom = self:partyActionOffset(now)
    self.partyActionStarted = now
    self.partyActionClosing = true
  end

  function H:partyActionAnimating(now)
    return self.motionEnabled ~= false and self.partyActionStarted
      and now - self.partyActionStarted < 0.14
  end

  function H:partyActionOffset(now)
    if not self:partyActionAnimating(now) then return 0 end
    local progress = (now - self.partyActionStarted) / 0.14
    if self.partyActionClosing then
      local first = self.partyActionCloseFrom or 0
      return math.floor(first + (6 - first) * progress * progress + 0.5)
    end
    local remaining = 1 - progress
    return math.floor(6 * remaining * remaining + 0.5)
  end

  function H:partyActionClosed(now)
    return self.partyActionClosing
      and (self.motionEnabled == false or now - self.partyActionStarted >= 0.14)
  end

  function H:actionRow(x, y, w, h, label, kind, offset, selected)
    local G, colors = ui.graphics, self.colors
    local accent = (kind == "swap" or kind == "switch")
      and colors.amberLight or kind == "release" and colors.redLight or colors.blueLight
    y = y + (offset or 0)
    local pressed = self:beginPress(x, y, w, h)
    if self:shadowVisible() then
      clipped(x + 1, y + 2, w, h, colors.shadow)
    end
    clipped(x, y, w, h,
      self:focusSurface(selected, colors.surface, accent))
    border(x, y, w, h, colors.outline)
    local contentY = y + math.floor((h - 40) / 2)
    G.push()
    G.translate(0, contentY - y)
    if kind == "swap" or kind == "switch" then
      color(accent)
      G.setLineWidth(2)
      G.line(x + 15, y + 17, x + 29, y + 17, x + 25, y + 13)
      G.line(x + 29, y + 23, x + 15, y + 23, x + 19, y + 27)
      G.setLineWidth(1)
    elseif kind == "cancel" then
      color(accent)
      G.setLineWidth(2)
      G.line(x + 17, y + 15, x + 27, y + 25)
      G.line(x + 27, y + 15, x + 17, y + 25)
      G.setLineWidth(1)
    elseif kind == "release" then
      box("fill", x + 20, y + 15, 5, 2, accent)
      box("fill", x + 14, y + 17, 17, 2, accent)
      border(x + 16, y + 19, 13, 8, accent)
      box("fill", x + 19, y + 21, 2, 4, accent)
      box("fill", x + 24, y + 21, 2, 4, accent)
    elseif h < 24 then
      box("fill", x + 15, y + 22, 3, 4, accent)
      box("fill", x + 21, y + 18, 3, 8, accent)
      box("fill", x + 27, y + 14, 3, 12, accent)
      box("fill", x + 13, y + 26, 19, 1, colors.outline)
    else
      box("fill", x + 15, y + 22, 3, 7, accent)
      box("fill", x + 21, y + 17, 3, 12, accent)
      box("fill", x + 27, y + 12, 3, 17, accent)
      box("fill", x + 13, y + 29, 19, 1, colors.outline)
    end
    G.pop()
    -- Equal icon/chevron containers flank the independently centered label.
    self:partyInfoCentered(self:fitPartyInfo(label, w - 86), x + 43, y, w - 86, h, colors.ink)
    self:detailChevron(x + w - 25, y + math.floor((h - 8) / 2), colors.ink, true)
    if selected then self:focusFrame(x, y, w, h) end
    self:endPress(pressed)
  end

  function H:action(index, label, selected)
    local action = self.battleActions[index]
    local colors = self.colors
    local light = colors[action.color .. "Light"]
    local dark = self:focusSurface(selected, colors[action.color], light)
    clipped(action.x + 1, action.y + 1, action.w, action.h, self.colors.shadow)
    clipped(action.x, action.y, action.w, action.h, dark)
    box("fill", action.x + 2, action.y + 2, action.w - 4,
      math.max(2, math.floor(action.h * 0.34)), light)
    border(action.x, action.y, action.w, action.h, colors.ink)
    if selected then self:focusFrame(action.x, action.y, action.w, action.h) end
    if index ~= 1 then
      local shown = fit(label, math.floor((action.w - 5) / 6))
      text(shown, action.x + math.floor((action.w - #glyphs(shown) * 6) / 2),
        action.y + math.floor((action.h - 7) / 2), colors.white)
    end
  end

end
