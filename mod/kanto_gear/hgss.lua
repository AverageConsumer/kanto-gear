return function(ui)
  local lightPalette = {
    { 244, 248, 242 }, { 213, 231, 220 },
    { 75, 112, 94 }, { 25, 43, 36 },
  }
  local darkPalette = {
    { 14, 22, 23 }, { 31, 48, 45 },
    { 170, 195, 186 }, { 239, 246, 241 },
  }
  local lightColors = {
    bg = { 0.94, 0.97, 0.93, 1 },
    band = { 0.66, 0.82, 0.72, 1 },
    bandLight = { 0.84, 0.91, 0.86, 1 },
    ink = { 0.08, 0.14, 0.12, 1 },
    outline = { 0.08, 0.14, 0.12, 1 },
    statusInk = { 0.08, 0.14, 0.12, 1 },
    shadow = { 0.08, 0.14, 0.12, 0.28 },
    highlight = { 0.97, 0.99, 0.99, 1 },
    white = { 0.97, 0.99, 0.99, 1 },
    silver = { 0.82, 0.86, 0.83, 1 },
    silverDark = { 0.40, 0.48, 0.43, 1 },
    surface = { 0.95, 0.97, 0.94, 1 },
    red = { 0.72, 0.15, 0.14, 1 },
    redLight = { 0.94, 0.42, 0.34, 1 },
    green = { 0.16, 0.42, 0.23, 1 },
    greenLight = { 0.37, 0.67, 0.42, 1 },
    amber = { 0.76, 0.48, 0.08, 1 },
    amberLight = { 0.96, 0.70, 0.25, 1 },
    focus = { 1.00, 0.91, 0.68, 1 },
    blue = { 0.14, 0.37, 0.62, 1 },
    blueLight = { 0.39, 0.62, 0.82, 1 },
    hp = { 0.15, 0.77, 0.29, 1 },
    hpMid = { 0.96, 0.68, 0.10, 1 },
    hpLow = { 0.91, 0.20, 0.20, 1 },
    exp = { 0.24, 0.69, 0.92, 1 },
    party = { 0.10, 0.54, 0.26, 1 },
    partyLight = { 0.19, 0.70, 0.36, 1 },
    partyDark = { 0.05, 0.31, 0.17, 1 },
    male = { 0.15, 0.55, 0.91, 1 },
    female = { 0.94, 0.35, 0.57, 1 },
    selected = { 0.91, 0.31, 0.25, 1 },
    selectedDark = { 0.59, 0.12, 0.11, 1 },
    fainted = { 0.25, 0.33, 0.28, 1 },
    partyBg = { 0.90, 0.95, 0.91, 1 },
    partyBand = { 0.86, 0.93, 0.88, 1 },
    partyEmboss = { 0.73, 0.85, 0.78, 1 },
  }
  local darkColors = {
    bg = { 0.055, 0.085, 0.09, 1 },
    band = { 0.14, 0.27, 0.23, 1 },
    bandLight = { 0.09, 0.16, 0.15, 1 },
    ink = { 0.91, 0.96, 0.93, 1 },
    outline = { 0.02, 0.035, 0.03, 1 },
    statusInk = { 0.04, 0.07, 0.06, 1 },
    shadow = { 0.00, 0.01, 0.01, 0.50 },
    highlight = { 0.18, 0.30, 0.25, 1 },
    white = { 0.96, 0.99, 0.98, 1 },
    silver = { 0.68, 0.76, 0.72, 1 },
    silverDark = { 0.20, 0.27, 0.25, 1 },
    surface = { 0.07, 0.115, 0.105, 1 },
    red = { 0.68, 0.13, 0.15, 1 },
    redLight = { 0.96, 0.39, 0.34, 1 },
    green = { 0.25, 0.73, 0.45, 1 },
    greenLight = { 0.38, 0.82, 0.54, 1 },
    amber = { 0.83, 0.55, 0.10, 1 },
    amberLight = { 0.98, 0.72, 0.24, 1 },
    focus = { 0.24, 0.16, 0.055, 1 },
    blue = { 0.20, 0.48, 0.78, 1 },
    blueLight = { 0.40, 0.68, 0.94, 1 },
    hp = { 0.13, 0.82, 0.34, 1 },
    hpMid = { 0.98, 0.68, 0.10, 1 },
    hpLow = { 0.96, 0.24, 0.25, 1 },
    exp = { 0.25, 0.72, 0.96, 1 },
    party = { 0.045, 0.30, 0.20, 1 },
    partyLight = { 0.12, 0.48, 0.30, 1 },
    partyDark = { 0.015, 0.095, 0.07, 1 },
    male = { 0.30, 0.67, 1.00, 1 },
    female = { 1.00, 0.42, 0.67, 1 },
    selected = { 0.73, 0.20, 0.18, 1 },
    selectedDark = { 0.31, 0.045, 0.05, 1 },
    fainted = { 0.105, 0.15, 0.135, 1 },
    partyBg = { 0.035, 0.06, 0.06, 1 },
    partyBand = { 0.055, 0.105, 0.095, 1 },
    partyEmboss = { 0.10, 0.19, 0.16, 1 },
  }
  local H = {
    palette = lightPalette,
    colors = lightColors,
    battleActions = {
      [1] = { x = 22, y = 32, w = 196, h = 112, color = "red" },
      [2] = { x = 166, y = 149, w = 68, h = 52, color = "green" },
      [3] = { x = 6, y = 149, w = 68, h = 52, color = "amber" },
      [4] = { x = 86, y = 149, w = 68, h = 52, color = "blue" },
    },
  }

  function H:setVariant(dark)
    self.palette = dark and darkPalette or lightPalette
    self.colors = dark and darkColors or lightColors
  end

  local box, text, fit, glyphs, color =
    ui.box, ui.text, ui.fit, ui.glyphs, ui.color
  local runnerParts = {
    { 118, 155, 5, 5 }, { 118, 162, 4, 8 },
    { 114, 163, 4, 2 }, { 113, 165, 2, 6 },
    { 121, 163, 3, 3 }, { 123, 164, 6, 2 },
    { 116, 169, 3, 4 },
    { 114, 172, 3, 4 }, { 108, 175, 7, 2 },
    { 119, 169, 3, 4 }, { 121, 172, 4, 2 },
    { 123, 173, 3, 7 },
  }
  local runnerOutline = {
    { -1, -1 }, { 0, -1 }, { 1, -1 }, { -1, 0 },
    { 1, 0 }, { -1, 1 }, { 0, 1 }, { 1, 1 },
  }
  local partyFont = ui.font and ui.graphics.newFont(ui.font, 11)
    or ui.graphics.newFont(11)
  local partyNameFont = ui.font and ui.graphics.newFont(ui.font, 9)
    or ui.graphics.newFont(9)
  local partyInfoFont = ui.font and ui.graphics.newFont(ui.font, 9)
    or ui.graphics.newFont(9)
  local partyTypeFont = ui.font and ui.graphics.newFont(ui.font, 8)
    or ui.graphics.newFont(8)
  partyFont:setFilter("linear", "linear")
  partyNameFont:setFilter("linear", "linear")
  partyInfoFont:setFilter("linear", "linear")
  partyTypeFont:setFilter("linear", "linear")

  function H:label(value, x, y, tint, width, align)
    local G, previous = ui.graphics, ui.graphics.getFont()
    ui.color(tint)
    G.setFont(partyFont)
    if width then G.printf(tostring(value), x, y, width, align or "left")
    else G.print(tostring(value), x, y) end
    if previous then G.setFont(previous) end
  end

  function H:labelWidth(value)
    return partyFont:getWidth(tostring(value))
  end

  function H:periodIcon(period, x, y)
    local colors = self.colors
    period = tostring(period or ""):upper()
    if period ~= "DAY" and period ~= "MORN" and period ~= "NITE" then
      return false
    end
    if period == "MORN" or period == "NITE" then y = y + 1 end
    local function paint(dx, dy, outlined)
      local dark = outlined and colors.outline or colors.amber
      local light = outlined and colors.outline or colors.amberLight
      if period == "DAY" then
        box("fill", x + 3 + dx, y + 3 + dy, 3, 3, light)
        box("fill", x + 4 + dx, y + dy, 1, 2, dark)
        box("fill", x + 4 + dx, y + 7 + dy, 1, 2, dark)
        box("fill", x + dx, y + 4 + dy, 2, 1, dark)
        box("fill", x + 7 + dx, y + 4 + dy, 2, 1, dark)
        box("fill", x + 1 + dx, y + 1 + dy, 1, 1, dark)
        box("fill", x + 7 + dx, y + 1 + dy, 1, 1, dark)
        box("fill", x + 1 + dx, y + 7 + dy, 1, 1, dark)
        box("fill", x + 7 + dx, y + 7 + dy, 1, 1, dark)
      elseif period == "MORN" then
        box("fill", x + 3 + dx, y + 3 + dy, 3, 1, light)
        box("fill", x + 2 + dx, y + 4 + dy, 5, 2, light)
        box("fill", x + dx, y + 6 + dy, 9, 1, dark)
        box("fill", x + 4 + dx, y + dy, 1, 2, dark)
        box("fill", x + 1 + dx, y + 2 + dy, 1, 1, dark)
        box("fill", x + 7 + dx, y + 2 + dy, 1, 1, dark)
      else
        light = outlined and colors.outline or colors.blueLight
        box("fill", x + 3 + dx, y + dy, 2, 1, light)
        box("fill", x + 1 + dx, y + 1 + dy, 3, 1, light)
        box("fill", x + dx, y + 2 + dy, 3, 4, light)
        box("fill", x + 1 + dx, y + 6 + dy, 3, 1, light)
        box("fill", x + 3 + dx, y + 7 + dy, 2, 1, light)
        box("fill", x + 7 + dx, y + 1 + dy, 1, 3, light)
        box("fill", x + 6 + dx, y + 2 + dy, 3, 1, light)
      end
    end
    paint(-1, 0, true); paint(1, 0, true)
    paint(0, -1, true); paint(0, 1, true); paint(0, 0, false)
    return true
  end

  function H:headerClock(value, period, left, width, y)
    local textWidth = self:labelWidth(value)
    if not period then
      local x = left + math.floor((width - textWidth) / 2)
      self:label(value, x, y, self.colors.ink)
      return x
    end
    local iconWidth = 11
    local free = math.max(0, width - textWidth - iconWidth)
    local leftGap = math.floor(free / 3)
    local middleGap = math.floor((free - leftGap) / 2)
    local x = left + leftGap
    self:label(value, x, y, self.colors.ink)
    local iconX = x + textWidth + middleGap + 1
    self:periodIcon(period, iconX, y + 3)
    return x, iconX
  end

  function H:battery(x, y, segments, blink, blinkVisible, tint, fill)
    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    tint = tint or self.colors.ink
    fill = fill or tint
    box("fill", x + 2, y, 13, 1, tint)
    box("fill", x + 2, y + 10, 13, 1, tint)
    box("fill", x, y + 2, 1, 7, tint)
    box("fill", x + 16, y + 2, 1, 7, tint)
    box("fill", x + 1, y + 1, 1, 1, tint)
    box("fill", x + 15, y + 1, 1, 1, tint)
    box("fill", x + 1, y + 9, 1, 1, tint)
    box("fill", x + 15, y + 9, 1, 1, tint)
    box("fill", x + 17, y + 4, 2, 3, tint)
    for segment = 1, 4 do
      if segment <= segments or segment == blink and blinkVisible then
        box("fill", x + 3 + (segment - 1) * 3, y + 3, 2, 5, fill)
      end
    end
  end

  function H:fitLabel(value, width)
    local chars = glyphs(tostring(value or ""))
    if partyFont:getWidth(table.concat(chars)) <= width then
      return table.concat(chars)
    end
    repeat table.remove(chars) until #chars == 0
      or partyFont:getWidth(table.concat(chars) .. "…") <= width
    return table.concat(chars) .. "…"
  end

  function H:partyName(value, x, y, tint, width)
    local G, previous = ui.graphics, ui.graphics.getFont()
    local chars = glyphs(tostring(value or ""))
    while partyNameFont:getWidth(table.concat(chars)) > width
        and #chars > 0 do table.remove(chars) end
    local shown = table.concat(chars)
    if shown ~= tostring(value or "") then
      while partyNameFont:getWidth(shown .. "…") > width
          and #chars > 0 do
        table.remove(chars)
        shown = table.concat(chars)
      end
      shown = shown .. "…"
    end
    color(tint)
    G.setFont(partyNameFont)
    G.print(shown, x, y)
    if previous then G.setFont(previous) end
  end

  function H:partyInfo(value, x, y, tint, width, align)
    local G, previous = ui.graphics, ui.graphics.getFont()
    ui.color(tint)
    G.setFont(partyInfoFont)
    if width then G.printf(tostring(value), x, y, width, align or "left")
    else G.print(tostring(value), x, y) end
    if previous then G.setFont(previous) end
  end

  function H:partyInfoWidth(value)
    return partyInfoFont:getWidth(tostring(value or ""))
  end

  function H:fitPartyInfo(value, width)
    local chars = glyphs(tostring(value or ""))
    if partyInfoFont:getWidth(table.concat(chars)) <= width then
      return table.concat(chars)
    end
    repeat table.remove(chars) until #chars == 0
      or partyInfoFont:getWidth(table.concat(chars) .. "…") <= width
    return table.concat(chars) .. "…"
  end

  function H:partyType(value, x, y, tint, width)
    local G, previous = ui.graphics, ui.graphics.getFont()
    ui.color(tint)
    G.setFont(partyTypeFont)
    G.printf(tostring(value), x, y, width, "center")
    if previous then G.setFont(previous) end
  end

  function H:genderIcon(gender, x, y)
    local G = ui.graphics
    local function paint(tint, width, offset)
      offset = offset or 0
      color(tint)
      G.setLineWidth(width)
      if gender == "male" then
        G.circle("line", x + 2.5 + offset, y + 4.5 + offset, 2)
        G.line(x + 4 + offset, y + 3 + offset,
          x + 7 + offset, y + offset)
        G.line(x + 5 + offset, y + offset, x + 7 + offset, y + offset,
          x + 7 + offset, y + 2 + offset)
      elseif gender == "female" then
        G.circle("line", x + 3.5 + offset, y + 2.5 + offset, 2)
        G.line(x + 3.5 + offset, y + 4.5 + offset,
          x + 3.5 + offset, y + 8 + offset)
        G.line(x + 1.5 + offset, y + 6.5 + offset,
          x + 5.5 + offset, y + 6.5 + offset)
      end
    end
    paint(self.colors.outline, 2, 1)
    paint(self.colors.outline, 2)
    paint(gender == "male" and self.colors.male or self.colors.female, 1)
    G.setLineWidth(1)
  end

  local function clipped(x, y, w, h, fill)
    box("fill", x + 2, y, w - 4, h, fill)
    box("fill", x, y + 2, w, h - 4, fill)
    box("fill", x + 1, y + 1, w - 2, h - 2, fill)
  end

  local function battleButtonShape(x, y, w, h, fill)
    box("fill", x + 4, y, w - 8, h, fill)
    box("fill", x + 2, y + 2, w - 4, h - 4, fill)
    box("fill", x, y + 4, w, h - 8, fill)
  end

  local function border(x, y, w, h, color)
    box("fill", x + 2, y, w - 4, 1, color)
    box("fill", x + 2, y + h - 1, w - 4, 1, color)
    box("fill", x, y + 2, 1, h - 4, color)
    box("fill", x + w - 1, y + 2, 1, h - 4, color)
    box("fill", x + 1, y + 1, 1, 1, color)
    box("fill", x + w - 2, y + 1, 1, 1, color)
    box("fill", x + 1, y + h - 2, 1, 1, color)
    box("fill", x + w - 2, y + h - 2, 1, 1, color)
  end

  function H:chevron(x, y, right)
    local G = ui.graphics
    color(self.colors.green)
    G.setLineWidth(2)
    if right then G.line(x - 2, y - 4, x + 2, y, x - 2, y + 4)
    else G.line(x + 2, y - 4, x - 2, y, x + 2, y + 4) end
    G.setLineWidth(1)
  end

  function H:pageChevron(x, y, right)
    local G = ui.graphics
    color(self.colors.amberLight)
    G.setLineWidth(1)
    if right then G.line(x - 2, y - 3, x + 1, y, x - 2, y + 3)
    else G.line(x + 2, y - 3, x - 1, y, x + 2, y + 3) end
  end

  function H:detailChevron(x, y, tint, large)
    local G = ui.graphics
    color(tint)
    G.setLineWidth(large and 2 or 1)
    if large then G.line(x, y, x + 5, y + 4, x, y + 8)
    else G.line(x, y, x + 3, y + 2, x, y + 4) end
    G.setLineWidth(1)
  end

  function H:headerBar(title, back, paged)
    local colors = self.colors
    box("fill", 0, 0, 240, 30, colors.bandLight)
    box("fill", 0, 0, 240, 2, colors.highlight)
    clipped(5, 4, 232, 21, colors.shadow)
    clipped(4, 3, 232, 21, colors.surface)
    box("fill", 6, 5, 228, 2, colors.highlight)
    border(4, 3, 232, 21, colors.green)
    box("fill", 138, 4, 1, 19, colors.band)
    box("fill", 211, 4, 1, 19, colors.band)

    local left, right, center = 15, 127, 71
    if back then
      self:chevron(14, 13, false)
      box("fill", 25, 6, 1, 15, colors.band)
      left, center = 36, 82
    end
    if paged then
      if back then
        self:pageChevron(left + 5, 13, false)
        self:pageChevron(right, 13, true)
      else
        self:chevron(left, 13, false)
        self:chevron(right, 13, true)
      end
    end
    local width = paged and (back and 76 or 88) or (back and 100 or 124)
    local shown = self:fitLabel(title, width)
    local x = (paged or back)
      and center - math.floor(self:labelWidth(shown) / 2)
      or 71 - math.floor(self:labelWidth(shown) / 2)
    self:label(shown, x, 6, colors.ink)
    return x, self:labelWidth(shown)
  end

  function H:backdrop(top)
    top = top or 0
    box("fill", 0, top, 160, 144 - top, self.colors.bg)
    box("fill", 0, top, 160, 2, self.colors.band)
    box("fill", 0, 132, 160, 12, self.colors.bandLight)
    box("fill", 0, 132, 51, 2, self.colors.band)
    box("fill", 109, 140, 51, 2, self.colors.band)
  end

  function H:panel(x, y, w, h, selected, accent)
    local colors = self.colors
    clipped(x + 1, y + 1, w, h, colors.shadow)
    clipped(x, y, w, h, selected and colors.focus or colors.surface)
    box("fill", x + 2, y + 2, w - 4, 2, colors.highlight)
    border(x, y, w, h, colors.ink)
    if selected then
      box("fill", x, y + 4, 2, math.max(1, h - 8), accent)
      self:focusFrame(x, y, w, h)
    end
  end

  function H:button(x, y, w, h, label, selected)
    self:panel(x, y, w, h, selected, self.colors.blue)
    local shown = fit(label, math.floor((w - 8) / 6))
    text(shown, x + math.floor((w - #glyphs(shown) * 6) / 2),
      y + math.floor((h - 7) / 2), self.colors.ink)
  end

  function H:partyActionRow(index, count)
    return 18, count == 1 and 139 or 112 + (index - 1) * 49, 204, 40
  end

  function H:partyActionHeroY(count)
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
    self.partyActionStarted = now
    self.partyActionClosing = false
    self.partyActionCloseFrom = nil
  end

  function H:endPartyAction(now)
    self.partyActionCloseFrom = self:partyActionOffset(now)
    self.partyActionStarted = now
    self.partyActionClosing = true
  end

  function H:partyActionAnimating(now)
    return self.partyActionStarted
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
      and now - self.partyActionStarted >= 0.14
  end

  function H:focusFrame(x, y, w, h)
    local colors = self.colors
    border(x, y, w, h, colors.outline)
    border(x + 1, y + 1, w - 2, h - 2, colors.amberLight)
    border(x + 2, y + 2, w - 4, h - 4, colors.white)
  end

  function H:roundedFocusFrame(x, y, w, h, radius)
    local G, colors = ui.graphics, self.colors
    color(colors.outline)
    G.setLineWidth(1)
    G.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1,
      radius, radius)
    color(colors.amberLight)
    G.setLineWidth(2)
    G.rectangle("line", x + 2, y + 2, w - 4, h - 4,
      math.max(1, radius - 1), math.max(1, radius - 1))
    color(colors.white)
    G.setLineWidth(1)
    G.rectangle("line", x + 3.5, y + 3.5, w - 7, h - 7,
      math.max(1, radius - 2), math.max(1, radius - 2))
    G.setLineWidth(1)
  end

  function H:actionRow(x, y, w, h, label, kind, offset, selected)
    local G, colors = ui.graphics, self.colors
    local accent = (kind == "swap" or kind == "switch")
      and colors.amberLight or colors.blueLight
    y = y + (offset or 0)
    clipped(x + 1, y + 2, w, h, colors.shadow)
    clipped(x, y, w, h, selected and colors.focus or colors.surface)
    box("fill", x + 2, y + 2, w - 4, 2, colors.highlight)
    border(x, y, w, h, colors.outline)
    box("fill", x + 1, y + 2, 4, h - 4, accent)
    box("fill", x + 2, y + 1, 3, 1, accent)
    box("fill", x + 2, y + h - 2, 3, 1, accent)
    if kind == "swap" or kind == "switch" then
      color(accent)
      G.setLineWidth(2)
      G.line(x + 15, y + 17, x + 29, y + 17, x + 25, y + 13)
      G.line(x + 29, y + 23, x + 15, y + 23, x + 19, y + 27)
      G.setLineWidth(1)
    else
      box("fill", x + 15, y + 22, 3, 7, accent)
      box("fill", x + 21, y + 17, 3, 12, accent)
      box("fill", x + 27, y + 12, 3, 17, accent)
      box("fill", x + 13, y + 29, 19, 1, colors.outline)
    end
    local shown = self:fitLabel(label, w - 69)
    self:label(shown, x + 43, y + 13, colors.ink)
    self:detailChevron(x + w - 16, y + 16, colors.ink, true)
    if selected then self:focusFrame(x, y, w, h) end
  end

  function H:action(index, label, selected)
    local action = self.battleActions[index]
    local dark = self.colors[action.color]
    local light = self.colors[action.color .. "Light"]
    clipped(action.x + 1, action.y + 1, action.w, action.h, self.colors.shadow)
    clipped(action.x, action.y, action.w, action.h, dark)
    box("fill", action.x + 2, action.y + 2, action.w - 4,
      math.max(2, math.floor(action.h * 0.34)), light)
    border(action.x, action.y, action.w, action.h, self.colors.ink)
    if selected then self:focusFrame(action.x, action.y, action.w, action.h) end
    if index ~= 1 then
      local shown = fit(label, math.floor((action.w - 5) / 6))
      text(shown, action.x + math.floor((action.w - #glyphs(shown) * 6) / 2),
        action.y + math.floor((action.h - 7) / 2), self.colors.white)
    end
  end

  function H:battleChoice(x, y)
    for index, action in ipairs(self.battleActions) do
      if x >= action.x and x < action.x + action.w
          and y >= action.y and y < action.y + action.h then return index end
    end
  end

  function H:battleTeamBall(x, y, state)
    local colors, G = self.colors, ui.graphics
    local alive = state
    if type(state) == "table" then alive = state.alive end
    local statusId = type(state) == "table"
      and tostring(state.status or ""):upper() or ""
    local statusTint = alive
      and (statusId == "PAR" or statusId == "PSN" or statusId == "TOX"
        or statusId == "SLP" or statusId == "BRN" or statusId == "FRZ")
      and self:statusColor(statusId) or nil
    local left, top = x - 4, y - 4
    local upper = alive and colors.redLight or colors.fainted
    local lower = alive and colors.white or colors.silverDark
    box("fill", left + 2, top, 5, 1, colors.outline)
    box("fill", left + 1, top + 1, 7, 1, colors.outline)
    box("fill", left, top + 2, 9, 5, colors.outline)
    box("fill", left + 1, top + 7, 7, 1, colors.outline)
    box("fill", left + 2, top + 8, 5, 1, colors.outline)
    box("fill", left + 2, top + 1, 5, 1, upper)
    box("fill", left + 1, top + 2, 7, 2, upper)
    box("fill", left + 1, top + 5, 7, 2, lower)
    box("fill", left + 2, top + 7, 5, 1, lower)
    if statusTint then
      G.setColor(statusTint[1], statusTint[2], statusTint[3], 0.86)
      G.rectangle("fill", left + 2, top + 1, 5, 1)
      G.rectangle("fill", left + 1, top + 2, 7, 5)
      G.rectangle("fill", left + 2, top + 7, 5, 1)
    end
    box("fill", left + 1, top + 4, 7, 1, colors.outline)
    box("fill", left + 3, top + 3, 3, 3, colors.outline)
    box("fill", left + 4, top + 4, 1, 1,
      statusTint or alive and colors.white or colors.silverDark)
  end

  function H:battleActionPanel(x, y, w, h, colorName, selected)
    local colors = self.colors
    local fill = colors[colorName]
    local light = colors[colorName .. "Light"]
    battleButtonShape(x + 2, y + 3, w, h, colors.outline)
    battleButtonShape(x, y, w, h, colors.outline)
    battleButtonShape(x + 1, y + 1, w - 2, h - 2, fill)
    box("fill", x + 5, y + 2, w - 10, 2, light)
    box("fill", x + 3, y + 4, 2, 2, light)
    box("fill", x + w - 5, y + 4, 2, 2, light)
    box("fill", x + 3, y + h - 7, w - 6, 3, colors.shadow)
    box("fill", x + 5, y + h - 4, w - 10, 2, colors.shadow)
    if selected then self:focusFrame(x, y, w, h) end
  end

  local PLAYER_CENTER, VS_CENTER, FOE_CENTER = 60, 120, 180
  local TEAM_WIDTH, VS_WIDTH, WILD_WIDTH = 64, 16, 88
  local TEAM_LEFT = PLAYER_CENTER - TEAM_WIDTH / 2
  local VS_LEFT = VS_CENTER - VS_WIDTH / 2
  local FOE_LEFT = FOE_CENTER - TEAM_WIDTH / 2
  local WILD_LEFT = FOE_CENTER - WILD_WIDTH / 2
  assert(TEAM_LEFT - 8 == VS_LEFT - (TEAM_LEFT + TEAM_WIDTH)
      and FOE_LEFT - (VS_LEFT + VS_WIDTH)
        == 232 - (FOE_LEFT + TEAM_WIDTH)
      and VS_CENTER - PLAYER_CENTER == FOE_CENTER - VS_CENTER
      and WILD_LEFT + WILD_WIDTH / 2 == FOE_CENTER,
    "HGSS trainer and wild battle strips share centered spacing")

  function H:battleTeamStrip(playerTeam, enemyTeam)
    local colors = self.colors
    self:panel(5, 3, 230, 25, false)
    for slot = 1, 6 do
      self:battleTeamBall(TEAM_LEFT + 4 + (slot - 1) * 11, 20,
        playerTeam and playerTeam[slot])
    end
    self:partyInfo("YOU", TEAM_LEFT, 3, colors.green, TEAM_WIDTH, "center")
    self:partyInfo("VS", VS_LEFT, 9, colors.ink, VS_WIDTH, "center")
    if enemyTeam and enemyTeam.wild then
      self:partyInfo("WILD", WILD_LEFT, 3, colors.green,
        WILD_WIDTH, "center")
      local detail = tostring(enemyTeam.name or "POKEMON")
      if enemyTeam.level then detail = detail .. " L" .. enemyTeam.level end
      self:partyInfo(self:fitPartyInfo(detail, WILD_WIDTH),
        WILD_LEFT, 15, colors.ink, WILD_WIDTH, "center")
    else
      for slot = 1, 6 do
        self:battleTeamBall(FOE_LEFT + 4 + (slot - 1) * 11, 20,
          enemyTeam and enemyTeam[slot])
      end
      self:partyInfo("FOE", FOE_LEFT, 3, colors.green, TEAM_WIDTH, "center")
    end
  end

  function H:battleFightAction(mon, drawPortrait, selected, offsetX, offsetY)
    local G, colors = ui.graphics, self.colors
    offsetX, offsetY = offsetX or 0, offsetY or 0
    G.push()
    G.translate(offsetX, offsetY)
    self:battleActionPanel(22, 32, 196, 112, "red", selected)
    color(colors.selectedDark)
    G.circle("fill", 120, 78, 36)
    color(colors.surface)
    G.circle("fill", 120, 78, 33)
    box("fill", 87, 77, 66, 2, colors.selectedDark)
    color(colors.surface)
    G.circle("fill", 120, 78, 7)
    color(colors.selectedDark)
    G.circle("line", 120, 78, 7)
    drawPortrait(mon, 91, 45, 58, false)
    local fight = self:fitLabel(mon.fightLabel or "FIGHT", 96)
    self:label(fight, 120 - math.floor(self:labelWidth(fight) / 2),
      121, colors.white)
    G.pop()
  end

  function H:battleBagIcon(x, y)
    color({ 1, 1, 1, 1 })
    ui.graphics.draw(ui.bagIcon, x, y)
  end

  function H:battleBagAction(mon, selected, offsetX, offsetY)
    local G, colors = ui.graphics, self.colors
    offsetX, offsetY = offsetX or 0, offsetY or 0
    G.push()
    G.translate(offsetX, offsetY)
    self:battleActionPanel(6, 149, 68, 52, "amber", selected)
    self:battleBagIcon(27, 154)
    self:label(mon.bagLabel or "BAG", 6, 183, colors.white, 68, "center")
    G.pop()
  end

  function H:battlePartyAction(mon, selected, offsetX, offsetY)
    local G, colors = ui.graphics, self.colors
    offsetX, offsetY = offsetX or 0, offsetY or 0
    G.push()
    G.translate(offsetX, offsetY)
    self:battleActionPanel(166, 149, 68, 52, "green", selected)
    self:battleTeamBall(185, 169, true)
    self:battleTeamBall(200, 164, true)
    self:battleTeamBall(215, 169, true)
    self:label(mon.partyLabel or "POKEMON", 166, 183,
      colors.white, 68, "center")
    G.pop()
  end

  function H:battleRunAction(mon, selected, offsetX, offsetY)
    local G, colors = ui.graphics, self.colors
    offsetX, offsetY = offsetX or 0, offsetY or 0
    G.push()
    G.translate(offsetX, offsetY)
    self:battleActionPanel(86, 149, 68, 52, "blue", selected)
    for _, offset in ipairs(runnerOutline) do
      for _, part in ipairs(runnerParts) do
        box("fill", part[1] + offset[1], part[2] + offset[2],
          part[3], part[4], colors.outline)
      end
    end
    for _, part in ipairs(runnerParts) do
      box("fill", part[1], part[2], part[3], part[4], colors.white)
    end
    self:label(mon.runLabel or "RUN", 86, 183, colors.white, 68, "center")
    G.pop()
  end

  function H:battleRoot(mon, drawPortrait, playerTeam, enemyTeam, selected)
    selected = selected or 1
    self:battleTeamStrip(playerTeam, enemyTeam)
    self:battleFightAction(mon, drawPortrait, selected == 1)
    self:battleBagAction(mon, selected == 3)
    self:battlePartyAction(mon, selected == 2)
    self:battleRunAction(mon, selected == 4)
  end

  function H:battleBagWindow(bag)
    local items = bag.items or {}
    local count = math.min(4, #items)
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
    elseif item.icon == "ball" then
      self:battleTeamBall(x + 8, y + 8, true)
    elseif item.icon == "medicine" then
      box("fill", x + 5, y + 1, 6, 2, colors.outline)
      box("fill", x + 3, y + 3, 10, 12, colors.outline)
      box("fill", x + 4, y + 4, 8, 10, colors.white)
      box("fill", x + 4, y + 6, 8, 5, colors.redLight)
      box("fill", x + 7, y + 7, 2, 3, colors.white)
    elseif item.icon == "status" then
      clipped(x + 1, y + 1, 14, 14, colors.white)
      border(x + 1, y + 1, 14, 14, colors.outline)
      box("fill", x + 7, y + 4, 3, 8, tint)
      box("fill", x + 4, y + 7, 9, 3, tint)
    else
      clipped(x + 2, y + 2, 12, 12, colors.white)
      border(x + 2, y + 2, 12, 12, colors.outline)
      box("fill", x + 5, y + 5, 6, 6, tint)
    end
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
    self:partyInfo(self:fitPartyInfo(bag.title or "BAG",
      bag.categorized and 96 or 112), bag.categorized and 74 or 65,
      43, colors.ink, bag.categorized and 99 or 114, "center")
    clipped(187, 40, 40, 16, colors.bandLight)
    border(187, 40, 40, 16, colors.outline)
    self:partyInfo(("%d/%d"):format(bag.index or 1, #(bag.items or {})),
      187, 43, colors.ink, 40, "center")
    G.pop()
  end

  function H:battleBagRow(item, index, y, selected, offsetX)
    local G, colors = ui.graphics, self.colors
    local disabled = item.disabled
    local accent = disabled and colors.silverDark or colors.amberLight
    local ink = disabled and colors.silverDark or colors.ink
    G.push()
    G.translate(offsetX or 0, 0)
    self:panel(7, y, 226, 31, false, accent)
    if selected and not disabled then
      clipped(12, y + 3, 216, 25, colors.amberLight)
      box("fill", 12, y + 3, 216, 2, colors.white)
    end
    box("fill", 8, y + 3, 4, 25, accent)
    box("fill", 9, y + 2, 3, 1, accent)
    box("fill", 9, y + 28, 3, 1, accent)
    self:battleItemIcon(item, 17, y + 7, accent)
    box("fill", 39, y + 4, 1, 23, colors.band)

    local chance = self:battleCatchLabel(item.catchChance)
    local labelY = (chance or disabled) and y + 4 or y + 9
    local right = item.right and tostring(item.right) or ""
    local rightWidth = right ~= ""
      and math.min(110, math.max(12, self:partyInfoWidth(right))) or 0
    local labelWidth = 178 - rightWidth - (rightWidth > 0 and 6 or 0)
    self:partyName(item.label or tostring(index), 46, labelY, ink, labelWidth)
    if item.right and item.right ~= "" then
      self:partyInfo(self:fitPartyInfo(right, rightWidth),
        224 - rightWidth, labelY, ink, rightWidth, "right")
    end
    if chance then
      self:partyInfo(item.catchLabel or "CATCH", 46, y + 17,
        colors.green, 37)
      clipped(84, y + 16, 42, 12, colors.greenLight)
      border(84, y + 16, 42, 12, colors.outline)
      self:partyType(chance, 86, y + 16, colors.white, 38)
    elseif disabled then
      self:partyInfo(item.disabledLabel or "UNUSABLE", 46, y + 17,
        colors.silverDark)
    end
    if selected and not disabled then self:focusFrame(7, y, 226, 31) end
    G.pop()
  end

  function H:battleBagRows(bag, rowOffset)
    local first, count = self:battleBagWindow(bag)
    for row = 1, count do
      local index = first + row - 1
      self:battleBagRow(bag.items[index], index,
        66 + (row - 1) * 33, bag.index == index,
        type(rowOffset) == "function" and rowOffset(row) or rowOffset)
    end
  end

  function H:battleBag(bag, playerTeam, enemyTeam)
    self:battleBagHeader(bag)
    self:battleBagRows(bag)
    self:battleTeamStrip(playerTeam, enemyTeam)
  end

  function H:battleBackdrop()
    local G, colors = ui.graphics, self.colors
    color(colors.partyBg)
    G.rectangle("fill", 0, 0, 240, 216)
    color(colors.partyEmboss)
    G.setLineWidth(2)
    G.circle("line", 120, 108, 94)
    G.line(26, 108, 104, 108)
    G.line(136, 108, 214, 108)
    G.circle("line", 120, 108, 16)
    G.circle("line", 120, 108, 7)
    G.setLineWidth(1)
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
    self:battleBackdrop()
    self:battleBag(bag, playerTeam, enemyTeam)
    G.pop()
  end

  function H:battleEffectLabel(move)
    local effectiveness = move.effectiveness
    if move.power == 0 or move.powerText == "--" then effectiveness = nil end
    local effectLabel = effectiveness == nil and "--"
      or effectiveness == 0 and "0X"
      or effectiveness >= 40 and "4X"
      or effectiveness > 10 and "2X"
      or effectiveness <= 2 and "1/4"
      or effectiveness < 10 and "1/2"
      or "1X"
    return effectLabel, effectiveness
  end

  function H:moveHasStab(mon, move)
    if not (mon and move and move.type)
        or move.power == 0 or move.powerText == "--" then return false end
    local moveType = tostring(move.type):upper()
    for _, monType in ipairs(mon.types or { mon.type, mon.type2 }) do
      if tostring(monType):upper() == moveType then return true end
    end
    return false
  end

  function H:battleMoveCard(move, x, y, selected, stab)
    local colors = self.colors
    local disabled = move.disabled
    local accent = disabled and colors.silverDark or self:typeColor(move.type)
    self:panel(x, y, 112, 80, selected and not disabled, accent)
    box("fill", x + 1, y + 2, 4, 76, accent)
    box("fill", x + 2, y + 1, 3, 1, accent)
    box("fill", x + 2, y + 78, 3, 1, accent)

    local ink = disabled and colors.silverDark or colors.ink
    self:partyName(self:fitLabel(move.name or "-", 88),
      x + 9, y + 7, ink, 88)
    self:detailChevron(x + 99, y + 8, ink)
    self:moveTypeBadge(move, x + 9, y + 25)
    self:partyInfo(move.ppLabel or "PP", x + 61, y + 25, colors.green)
    self:partyInfo(move.ppText or "--", x + 76, y + 25,
      ink, 29, "right")
    box("fill", x + 9, y + 42, 94, 1, colors.band)
    self:partyInfo(move.powerLabel or "PWR", x + 9, y + 51, colors.green)
    self:partyInfo(move.powerText or "--", x + 35, y + 51,
      ink, 22, "right")
    self:partyInfo(move.accuracyLabel or "ACC", x + 62, y + 51,
      colors.green)
    self:partyInfo(move.accuracyText or "--", x + 84, y + 51,
      ink, 19, "right")

    local effectLabel, effectiveness = self:battleEffectLabel(move)
    local effectFill = effectiveness == 0 and colors.red
      or effectiveness and effectiveness > 10 and colors.greenLight
      or effectiveness and effectiveness < 10 and colors.amber
      or colors.silverDark
    local effectX = stab and x + 59 or x + 43
    if stab then
      clipped(x + 26, y + 66, 34, 10, self:typeColor(move.type))
      border(x + 26, y + 66, 34, 10, colors.outline)
      self:partyType("STAB", x + 28, y + 65, colors.white, 30)
    end
    clipped(effectX, y + 66, 27, 10, effectFill)
    border(effectX, y + 66, 27, 10, colors.outline)
    self:partyType(effectLabel, effectX + 2, y + 65, colors.white, 23)
  end

  function H:battleMoves(mon, playerTeam, enemyTeam)
    self:battleTeamStrip(playerTeam, enemyTeam)
    for slot = 1, 4 do
      local column, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
      local move = mon.moves[slot] or {}
      self:battleMoveCard(move, 6 + column * 116,
        33 + row * 85, mon.moveIndex == slot, self:moveHasStab(mon, move))
    end
  end

  function H:battleMoveInfoStat(x, label, value)
    local colors = self.colors
    self:panel(x, 70, 66, 41, false)
    self:partyInfo(label, x, 76, colors.green, 66, "center")
    self:partyInfo(value, x, 91, colors.ink, 66, "center")
  end

  function H:battleMoveInfoBody(move, stab)
    local colors = self.colors
    local accent = self:typeColor(move.type)
    self:panel(6, 33, 228, 169, false)
    box("fill", 7, 35, 5, 165, accent)
    box("fill", 8, 34, 4, 1, accent)
    box("fill", 8, 200, 4, 1, accent)
    self:chevron(20, 51, false)
    self:partyName(self:fitLabel(move.name or "-", 128),
      36, 42, colors.ink, 128)
    self:moveTypeBadge(move, 176, 43)
    box("fill", 16, 63, 208, 1, colors.band)

    local accuracy = tostring(move.accuracyText or "--")
    if accuracy ~= "--" and not accuracy:find("%%") then
      accuracy = accuracy .. "%"
    end
    self:battleMoveInfoStat(14, move.powerLabel or "PWR",
      tostring(move.powerText or "--"))
    self:battleMoveInfoStat(87, move.accuracyLabel or "ACC", accuracy)
    self:battleMoveInfoStat(160, move.ppLabel or "PP",
      tostring(move.ppText or "--"))

    self:panel(14, 117, 103, 36, false)
    self:partyInfo(move.stabLabel or "STAB", 14, 122,
      colors.green, 103, "center")
    local stabFill = stab and accent or colors.silverDark
    clipped(48, 137, 35, 11, stabFill)
    border(48, 137, 35, 11, colors.outline)
    self:partyType(stab and "1.5X" or "--", 50, 136,
      colors.white, 31)

    self:panel(123, 117, 103, 36, false)
    self:partyInfo(move.matchupLabel or "MATCHUP", 123, 122,
      colors.green, 103, "center")
    local effectLabel, effectiveness = self:battleEffectLabel(move)
    local effectFill = effectiveness == 0 and colors.red
      or effectiveness and effectiveness > 10 and colors.greenLight
      or effectiveness and effectiveness < 10 and colors.amber
      or colors.silverDark
    clipped(161, 137, 27, 11, effectFill)
    border(161, 137, 27, 11, colors.outline)
    self:partyType(effectLabel, 163, 136, colors.white, 23)

    self:panel(14, 158, 212, 36, false)
    local lines = move.descriptionLines or { move.description or "--" }
    if lines[2] then
      self:partyInfo(self:fitPartyInfo(lines[1], 196),
        22, 165, colors.ink, 196, "center")
      self:partyInfo(self:fitPartyInfo(lines[2], 196),
        22, 177, colors.ink, 196, "center")
    else
      self:partyInfo(self:fitPartyInfo(lines[1], 196),
        22, 171, colors.ink, 196, "center")
    end
  end

  function H:battleMoveInfo(move, stab, playerTeam, enemyTeam)
    self:battleMoveInfoBody(move, stab)
    self:battleTeamStrip(playerTeam, enemyTeam)
  end

  function H:battleMoveInfoTransition(mon, playerTeam, enemyTeam, progress)
    local G = ui.graphics
    progress = math.max(0, math.min(1, progress or 0))
    local cardsProgress = math.min(1, progress / 0.62)
    cardsProgress = cardsProgress * cardsProgress * (3 - 2 * cardsProgress)
    for slot = 1, 4 do
      local column, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
      local direction = column == 0 and -1 or 1
      local move = mon.moves[slot] or {}
      local x = 6 + column * 116
        + math.floor(direction * 122 * cardsProgress + 0.5)
      self:battleMoveCard(move, x, 33 + row * 85,
        mon.moveIndex == slot, self:moveHasStab(mon, move))
    end

    local infoProgress = math.max(0, math.min(1, (progress - 0.24) / 0.76))
    infoProgress = 1 - (1 - infoProgress) ^ 3
    local move = mon.moves[mon.moveIndex or 1] or {}
    G.push()
    G.translate(math.floor(240 * (1 - infoProgress) + 0.5), 0)
    self:battleMoveInfoBody(move, self:moveHasStab(mon, move))
    G.pop()
    self:battleTeamStrip(playerTeam, enemyTeam)
  end

  function H:battleMovesTransition(mon, drawPortrait, playerTeam, enemyTeam,
      progress)
    progress = math.max(0, math.min(1, progress or 0))
    local rootProgress = math.min(1, progress / 0.48)
    rootProgress = rootProgress * rootProgress * (3 - 2 * rootProgress)

    self:battleFightAction(mon, drawPortrait, true, 0,
      math.floor(-116 * rootProgress + 0.5))
    self:battleBagAction(mon, false,
      math.floor(-76 * rootProgress + 0.5), 0)
    self:battlePartyAction(mon, false,
      math.floor(76 * rootProgress + 0.5), 0)
    self:battleRunAction(mon, false, 0,
      math.floor(68 * rootProgress + 0.5))

    for slot = 1, 4 do
      local start = slot <= 2 and 0.32 or 0.40
      local cardProgress = math.max(0, math.min(1,
        (progress - start) / (1 - start)))
      cardProgress = 1 - (1 - cardProgress) ^ 3
      local column, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
      local direction = column == 0 and -1 or 1
      local x = 6 + column * 116
        + math.floor(direction * 122 * (1 - cardProgress) + 0.5)
      local move = mon.moves[slot] or {}
      self:battleMoveCard(move, x, 33 + row * 85,
        mon.moveIndex == slot, self:moveHasStab(mon, move))
    end
    self:battleTeamStrip(playerTeam, enemyTeam)
  end

  function H:battlePartyTransition(mon, drawPortrait, playerTeam, enemyTeam,
      drawPartyCard, progress, title, clock, period)
    local G = ui.graphics
    progress = math.max(0, math.min(1, progress or 0))
    local pageProgress = progress
    pageProgress = pageProgress * pageProgress * (3 - 2 * pageProgress)

    G.push()
    G.translate(math.floor(-240 * pageProgress + 0.5), 0)
      self:battleRoot(mon, drawPortrait, playerTeam, enemyTeam, 2)
    G.pop()

    G.push()
    G.translate(math.floor(240 * (1 - pageProgress) + 0.5), 0)
    self:partyBackdrop()
    self:headerBar(title or "PARTY", true, false)
    self:headerClock(clock or "20:04", period, 139, 72, 6)
    self:battery(214, 8, 4, nil, true, self.colors.ink,
      self.colors.greenLight)
    for slot = 1, 6 do
      local start = (slot - 1) * 0.025
      local cardProgress = math.max(0, math.min(1,
        (pageProgress - start) / (1 - start)))
      cardProgress = 1 - (1 - cardProgress) ^ 3
      local x, y = self:partyPosition(slot)
      drawPartyCard(slot, x + math.floor(14 * (1 - cardProgress) + 0.5),
        y, slot == 1, false)
    end
    G.pop()
  end

  function H:ball(x, y, selected)
    local G, colors = ui.graphics, self.colors
    ui.color(colors.outline)
    G.circle("fill", x, y, 8)
    ui.color(selected and colors.redLight or colors.silverDark)
    G.circle("fill", x, y, 7)
    box("fill", x - 7, y, 14, 6, colors.white)
    box("fill", x - 7, y - 1, 14, 2, colors.outline)
    ui.color(colors.white)
    G.circle("fill", x, y, 3)
    ui.color(colors.outline)
    G.circle("line", x, y, 3)
  end

  local typeColors = {
    NORMAL = { 0.61, 0.62, 0.54, 1 }, FIRE = { 0.92, 0.34, 0.22, 1 },
    WATER = { 0.23, 0.52, 0.89, 1 }, ELECTRIC = { 0.93, 0.72, 0.12, 1 },
    GRASS = { 0.34, 0.68, 0.28, 1 }, ICE = { 0.35, 0.75, 0.79, 1 },
    FIGHTING = { 0.72, 0.20, 0.18, 1 }, POISON = { 0.62, 0.31, 0.65, 1 },
    GROUND = { 0.74, 0.55, 0.24, 1 }, FLYING = { 0.46, 0.57, 0.83, 1 },
    PSYCHIC = { 0.90, 0.28, 0.52, 1 }, BUG = { 0.57, 0.65, 0.15, 1 },
    ROCK = { 0.64, 0.55, 0.27, 1 }, GHOST = { 0.42, 0.36, 0.66, 1 },
    DRAGON = { 0.42, 0.31, 0.87, 1 }, DARK = { 0.36, 0.29, 0.25, 1 },
    STEEL = { 0.57, 0.59, 0.66, 1 }, FAIRY = { 0.89, 0.50, 0.64, 1 },
  }

  function H:typeColor(typeId)
    return typeColors[tostring(typeId or "NORMAL"):upper()]
      or typeColors.NORMAL
  end

  function H:statusColor(statusId)
    statusId = tostring(statusId or ""):upper()
    return statusId == "FNT" and self.colors.silver
      or statusId == "SLP" and self.colors.blueLight
      or statusId == "PAR" and self.colors.amberLight
      or (statusId == "PSN" or statusId == "TOX")
        and self:typeColor("POISON")
      or statusId == "BRN" and self.colors.redLight
      or statusId == "FRZ" and self:typeColor("ICE")
      or self.colors.white
  end

  local statusPatterns = {
    PAR = { "...##..", "..##...", ".#####.", "...##..", "..##...",
      ".##....", "##....." },
    SLP = { ".......", "######.", "....##.", "...##..", "..##...",
      ".##....", "######." },
    PSN = { ".#...#.", ".......", "...#...", "..###..", ".#####.",
      "#######", ".#####." },
    TOX = { ".#...#.", ".......", "...#...", "..###..", ".#####.",
      "#######", ".#####." },
    BRN = { "...#...", "..##...", ".####..", ".#####.", "#######",
      ".#####.", "..###.." },
    FRZ = { "...#...", "#..#..#", ".#.#.#.", "..###..", ".#.#.#.",
      "#..#..#", "...#..." },
    FNT = { "#.....#", ".#...#.", "..#.#..", "...#...", "..#.#..",
      ".#...#.", "#.....#" },
  }

  function H:statusIcon(statusId, x, y)
    statusId = tostring(statusId or ""):upper()
    local pattern = statusPatterns[statusId]
    if not pattern then return end
    for row, pixels in ipairs(pattern) do
      for column = 1, #pixels do
        if pixels:sub(column, column) == "#" then
          local px, py = x + column - 1, y + row - 1
          box("fill", px + 1, py + 1, 1, 1, self.colors.outline)
        end
      end
    end
    for row, pixels in ipairs(pattern) do
      for column = 1, #pixels do
        if pixels:sub(column, column) == "#" then
          box("fill", x + column - 1, y + row - 1, 1, 1,
            self:statusColor(statusId))
        end
      end
    end
  end

  function H:partyBackdrop()
    local G, colors = ui.graphics, self.colors
    color(colors.partyBg)
    G.rectangle("fill", 0, 28, 240, 188)
    color(colors.partyBand)
    G.polygon("fill", 0, 42, 240, 28, 240, 39, 0, 53)
    G.polygon("fill", 0, 194, 240, 180, 240, 191, 0, 205)
    color(colors.partyEmboss)
    G.setLineWidth(2)
    G.circle("line", 120, 121, 94)
    G.line(26, 121, 104, 121)
    G.line(136, 121, 214, 121)
    G.circle("line", 120, 121, 16)
    G.circle("line", 120, 121, 7)
    G.setLineWidth(1)
  end

  function H:partyPanel(x, y, w, h, selected, fainted, focused)
    local G, colors = ui.graphics, self.colors
    color(colors.shadow)
    G.rectangle("fill", x + 1, y + 2, w, h, 6, 6)
    color(fainted and colors.fainted
      or selected and colors.selected or colors.party)
    G.rectangle("fill", x, y, w, h, 6, 6)
    color(selected and colors.selectedDark or colors.partyDark)
    G.setLineWidth(selected and 2 or 1)
    G.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 6, 6)
    G.setLineWidth(1)
    if focused == nil then focused = selected end
    if focused then self:roundedFocusFrame(x, y, w, h, 6) end
  end

  function H:partyPortrait(x, y, selected, fainted)
    local G, shade = ui.graphics, fainted and 0.45 or 1
    local function tint(value)
      G.setColor(value[1] * shade, value[2] * shade,
        value[3] * shade, value[4] or 1)
    end
    tint(self.colors.redLight)
    G.circle("fill", x + 17, y + 20, 17)
    tint(self.colors.white)
    G.arc("fill", x + 17, y + 20, 16, 0, math.pi)
    tint(selected and self.colors.selectedDark or self.colors.partyDark)
    G.line(x + 1, y + 20, x + 33, y + 20)
    tint(self.colors.white)
    G.circle("fill", x + 17, y + 20, 4)
    tint(selected and self.colors.selectedDark or self.colors.partyDark)
    G.circle("line", x + 17, y + 20, 4)
    G.circle("line", x + 17, y + 20, 17)
  end

  local function typeBadgeStyle(theme, typeId, label, fainted)
    local tint = theme:typeColor(typeId)
    local shade = fainted and 0.48 or 1
    local fill = { tint[1] * shade, tint[2] * shade, tint[3] * shade, 1 }
    local chars = glyphs(tostring(label or typeId or "---"))
    while #chars > 3 do table.remove(chars) end
    local labelColor = fainted and theme.colors.silver or theme.colors.white
    return fill, labelColor, table.concat(chars)
  end

  function H:typeBadges(mon, x, y, fainted)
    local left, leftInk, leftText = typeBadgeStyle(
      self, mon.type, mon.typeLabel, fainted)
    local edge = fainted and self.colors.silverDark or self.colors.outline
    local dual = mon.type2 and mon.type2 ~= mon.type
    if not dual then
      clipped(x + 10, y, 22, 10, left)
      border(x + 10, y, 22, 10, edge)
      self:partyType(leftText, x + 10, y - 1, leftInk, 22)
      return
    end
    local right, rightInk, rightText = typeBadgeStyle(
      self, mon.type2, mon.type2Label, fainted)
    clipped(x, y, 42, 10, left)
    box("fill", x + 21, y, 19, 10, right)
    box("fill", x + 21, y + 1, 20, 8, right)
    box("fill", x + 21, y + 2, 21, 6, right)
    border(x, y, 42, 10, edge)
    box("fill", x + 21, y + 1, 1, 8, edge)
    self:partyType(leftText, x + 1, y - 1, leftInk, 20)
    self:partyType(rightText, x + 22, y - 1, rightInk, 20)
  end

  function H:partyPosition(slot)
    local index = slot - 1
    local col, row = index % 2, math.floor(index / 2)
    return 5 + col * 118, 32 + row * 58 + (col == 1 and 4 or 0)
  end

  function H:swapSourceMarker(x, y)
    local G, colors = ui.graphics, self.colors
    color(colors.amberLight)
    G.setLineWidth(2)
    G.rectangle("line", x + 1, y + 1, 110, 54, 6, 6)
    G.setLineWidth(1)
  end

  function H:partyCard(mon, x, y, selected, details, drawPortrait, focused)
    local fainted = mon and (mon.statusId == "FNT"
      or mon.hp ~= nil and mon.hp <= 0)
    if focused == nil then focused = selected end
    self:partyPanel(x, y, 112, 56, selected, fainted, focused)
    if not mon then
      self:label("-", x, y + 18, self.colors.ink, 112, "center")
      return
    end
    self:partyPortrait(x + 5, y + 2, selected, fainted)
    drawPortrait(mon, x + 6, y + 4, 32, fainted)
    local ink = self.colors.white
    local quiet = selected and self.colors.white or self.colors.silver
    self:partyName(mon.name, x + 44, y + 4, ink,
      details == true and 61 or 67)
    if details == true then self:detailChevron(x + 105, y + 8, ink)
    elseif details == "swap" then self:swapSourceMarker(x, y) end
    if mon.egg then return end
    self:typeBadges(mon, x + 2, y + 42, fainted)
    if mon.gender == "male" then
      self:genderIcon("male", x + 99, y + 19)
    elseif mon.gender == "female" then
      self:genderIcon("female", x + 99, y + 19)
    end
    self:partyInfo(mon.levelText, x + 45, y + 17, quiet)
    if mon.statusId then
      self:statusIcon(mon.statusId, x + 70, y + 19)
    end
    self:partyInfo(mon.hpLabel or "HP", x + 45, y + 27, quiet)
    self:partyInfo(mon.hpText, x + 45, y + 27, quiet, 62, "right")
    self:hpBar(x + 45, y + 38, 62, mon.hp, mon.maxHp)
    self:partyInfo(mon.expLabel or "EXP", x + 45, y + 41, quiet)
    self:expBar(x + 65, y + 45, 42, mon.expProgress)
  end

  function H:partySwap(drawPartyCard, source, target)
    for slot = 1, 6 do
      local x, y = self:partyPosition(slot)
      drawPartyCard(slot, x, y, slot == target,
        slot == source and "swap" or false)
    end
  end

  function H:partySwapTransition(drawPartyCard, source, target, progress,
      actionCount, statsLabel, swapLabel)
    progress = math.max(0, math.min(1, progress or 0))
    local eased = 1 - (1 - progress) ^ 3
    local sourceX, sourceY = self:partyPosition(source)
    local heroY = self:partyActionHeroY(actionCount)
    drawPartyCard(source,
      64 + (sourceX - 64) * eased,
      heroY + (sourceY - heroY) * eased,
      progress < 0.45, progress >= 0.45 and "swap" or false)

    for slot = 1, 6 do
      if slot ~= source then
        local start = 0.18 + math.max(0, slot - 2) * 0.025
        local cardProgress = math.max(0, math.min(1,
          (progress - start) / (1 - start)))
        cardProgress = 1 - (1 - cardProgress) ^ 3
        local x, y = self:partyPosition(slot)
        local column = (slot - 1) % 2
        local direction = column == 0 and -1 or 1
        drawPartyCard(slot,
          x + direction * 122 * (1 - cardProgress), y,
          slot == target and cardProgress > 0.62, false)
      end
    end

    local actionOffset = math.floor(230 * eased + 0.5)
    local x, y, w, h = self:partyActionRow(1, actionCount)
    self:actionRow(x + actionOffset, y, w, h, statsLabel, "stats", 0)
    if actionCount > 1 then
      x, y, w, h = self:partyActionRow(2, actionCount)
      self:actionRow(x + actionOffset, y, w, h, swapLabel, "swap", 0)
    end
  end

  function H:partySwapCommitTransition(drawPartyCard, source, target,
      progress)
    local G = ui.graphics
    progress = math.max(0, math.min(1, progress or 0))
    local scale = math.abs(1 - progress * 2)
    for position = 1, 6 do
      local slot = position
      if progress >= 0.5 then
        if position == source then slot = target
        elseif position == target then slot = source end
      end
      local x, y = self:partyPosition(position)
      if position == source or position == target then
        G.push()
        G.translate(x + 56, 0)
        G.scale(math.max(0.03, scale), 1)
        G.translate(-(x + 56), 0)
        drawPartyCard(slot, x, y, progress < 0.5 and position == target,
          progress < 0.5 and position == source and "swap" or false)
        G.pop()
      else
        drawPartyCard(slot, x, y, false, false)
      end
    end
  end

  function H:summaryBall(cx, cy, radius)
    local G, colors = ui.graphics, self.colors
    color(colors.outline)
    G.circle("fill", cx, cy, radius)
    color(colors.redLight)
    G.circle("fill", cx, cy, radius - 1)
    color(colors.white)
    G.arc("fill", cx, cy, radius - 2, 0, math.pi)
    local line = math.max(1, math.floor(radius / 9))
    box("fill", cx - radius + 2, cy - math.floor(line / 2),
      radius * 2 - 4, line, colors.outline)
    local button = math.max(2, math.floor(radius / 5 + 0.5))
    color(colors.white)
    G.circle("fill", cx, cy, button)
    color(colors.outline)
    G.circle("line", cx, cy, button)
  end

  function H:summaryTop(mon, drawPortrait)
    local colors = self.colors
    self:panel(6, 34, 228, 80, false)
    self:summaryBall(38, 69, 29)
    drawPortrait(mon, 14, 44, 48, false)

    self:partyName(mon.name, 72, 39, colors.ink, 139)
    if mon.gender == "male" then
      self:genderIcon("male", 219, 42)
    elseif mon.gender == "female" then
      self:genderIcon("female", 219, 42)
    end
    self:partyInfo(mon.dexText, 72, 53, colors.green)
    self:partyInfo(mon.levelText, 132, 53, colors.ink)
    if mon.statusId then self:statusIcon(mon.statusId, 191, 55) end
    self:typeBadges(mon, 72, 66, false)
    if mon.info2Label then
      self:partyInfo(mon.infoLabel, 121, 66, colors.green)
      self:partyInfo(self:fitPartyInfo(mon.infoText, 27),
        139, 66, colors.ink, 27, "right")
      self:partyInfo(mon.info2Label, 171, 66, colors.green)
      self:partyInfo(self:fitPartyInfo(mon.info2Text, 37),
        190, 66, colors.ink, 37, "right")
    else
      self:partyInfo(mon.infoLabel or "ITEM", 121, 66, colors.green)
      self:partyInfo(self:fitPartyInfo(mon.infoText or "---", 76),
        151, 66, colors.ink, 76, "right")
    end
    self:partyInfo(mon.hpLabel or "HP", 72, 79, colors.green)
    self:partyInfo(mon.hpText, 72, 79, colors.ink, 155, "right")
    self:hpBar(72, 90, 155, mon.hp, mon.maxHp)
    self:partyInfo(mon.expLabel or "EXP", 72, 98, colors.green)
    if mon.expProgress then
      self:expBar(99, 103, mon.nextValue and 64 or 128, mon.expProgress)
    elseif mon.expText then
      self:partyInfo(mon.expText, 99, 98, colors.ink, 128, "right")
    end
    if mon.nextValue then
      self:partyInfo(mon.nextLabel or "NEXT", 168, 98, colors.green)
      self:partyInfo(mon.nextValue, 195, 98, colors.ink, 32, "right")
    end
  end

  function H:summaryStats(mon)
    local colors = self.colors
    self:panel(6, 118, 228, 92, false)
    self:label(mon.statsTitle or "BATTLE STATS", 12, 121, colors.ink)
    box("fill", 11, 137, 218, 1, colors.band)
    box("fill", 120, 138, 1, 66, colors.band)
    local rows = math.max(1, math.ceil(#mon.stats / 2))
    local firstY, step = rows == 2 and 151 or 143, rows == 2 and 29 or 21
    for row = 1, rows do
      local y = firstY + (row - 1) * step
      if row > 1 then
        box("fill", 11, y - math.floor(step / 2), 218, 1, colors.bandLight)
      end
      for column = 1, 2 do
        local entry = mon.stats[row + (column - 1) * rows]
        if entry then
          local x, width = column == 1 and 13 or 127, column == 1 and 99 or 100
          self:partyInfo(self:fitLabel(entry.label, 61), x, y,
            colors.green)
          self:partyInfo(tostring(entry.value), x, y, colors.ink,
            width, "right")
        end
      end
    end
  end

  function H:summaryPage(mon, drawPortrait)
    self:summaryTop(mon, drawPortrait)
    self:summaryStats(mon)
  end

  function H:summaryIdentity(mon, drawPortrait)
    local colors = self.colors
    self:panel(6, 34, 228, 25, false)
    self:summaryBall(20, 46, 10)
    drawPortrait(mon, 10, 36, 20, false)
    self:partyName(mon.name, 36, 37, colors.ink, 108)
    if mon.gender == "male" then
      self:genderIcon("male", 145, 40)
    elseif mon.gender == "female" then
      self:genderIcon("female", 145, 40)
    end
    self:partyInfo(mon.levelText, 158, 39, colors.ink)
    if mon.statusId then self:statusIcon(mon.statusId, 194, 40) end
    self:partyInfo(mon.hpLabel or "HP", 36, 47, colors.green)
    self:hpBar(55, 50, 96, mon.hp, mon.maxHp)
    self:partyInfo(mon.hpText, 158, 47, colors.ink, 69, "right")
  end

  function H:moveTypeBadge(move, x, y)
    local fill = self:typeColor(move.type)
    clipped(x, y, 48, 10, fill)
    border(x, y, 48, 10, self.colors.outline)
    self:partyType(self:fitPartyInfo(move.typeLabel or move.type, 44),
      x + 2, y - 1, self.colors.white, 44)
  end

  function H:summaryMoveRow(move, x, y, selected)
    local colors = self.colors
    self:panel(x, y, 228, 34, selected, colors.selected)
    local accent = self:typeColor(move.type)
    box("fill", x + 1, y + 2, 4, 30, accent)
    box("fill", x + 2, y + 1, 3, 1, accent)
    box("fill", x + 2, y + 32, 3, 1, accent)
    self:moveTypeBadge(move, x + 8, y + 12)
    self:partyName(move.name or "-", x + 64, y + 4, colors.ink, 88)
    self:partyInfo(move.ppLabel or "PP", x + 157, y + 4, colors.green)
    self:partyInfo(move.ppText or "--", x + 177, y + 4,
      colors.ink, 35, "right")
    self:detailChevron(x + 217, y + 6, colors.ink)
    self:partyInfo(move.powerLabel or "PWR", x + 64, y + 18,
      colors.green)
    local power = move.powerText
    if not power or power == "--" then
      box("fill", x + 101, y + 23, 7, 1, colors.ink)
    else
      self:partyInfo(power, x + 90, y + 18,
        colors.ink, 26, "right")
    end
    self:partyInfo(move.accuracyLabel or "ACC", x + 126, y + 18,
      colors.green)
    self:partyInfo(move.accuracyText or "--", x + 153, y + 18,
      colors.ink, 32, "right")
  end

  function H:summaryMoves(mon, drawPortrait)
    self:summaryIdentity(mon, drawPortrait)
    for slot = 1, 4 do
      self:summaryMoveRow(mon.moves[slot] or {}, 6,
        63 + (slot - 1) * 37, mon.moveIndex == slot)
    end
  end

  function H:summaryTrainerMemo(mon)
    local colors = self.colors
    self:panel(6, 63, 228, 62, false)
    box("fill", 7, 65, 4, 58, colors.blue)
    box("fill", 8, 64, 3, 1, colors.blue)
    box("fill", 8, 123, 3, 1, colors.blue)
    self:partyInfo(mon.memoTitle or "TRAINER MEMO", 17, 68, colors.green)
    box("fill", 16, 82, 208, 1, colors.band)
    self:partyInfo(mon.otLabel or "ORIGINAL TRAINER", 17, 88, colors.green)
    self:partyName(mon.otText or "---", 17, 101, colors.ink, 109)
    box("fill", 136, 86, 1, 31, colors.bandLight)
    self:partyInfo(mon.idLabel or "ID NO.", 146, 88, colors.green)
    self:partyName(mon.idText or "00000", 146, 101, colors.ink, 77)
  end

  function H:summaryGrowthMemo(mon)
    local colors = self.colors
    self:panel(6, 130, 228, 80, false)
    box("fill", 7, 132, 4, 76, colors.exp)
    box("fill", 8, 131, 3, 1, colors.exp)
    box("fill", 8, 208, 3, 1, colors.exp)
    self:partyInfo(mon.growthTitle or "GROWTH RECORD", 17, 135,
      colors.green)
    box("fill", 16, 149, 208, 1, colors.band)
    self:partyInfo(mon.totalExpLabel or "TOTAL EXP", 17, 156,
      colors.green)
    self:label(mon.experienceText or "0", 17, 169, colors.ink)
    box("fill", 124, 153, 1, 39, colors.bandLight)
    self:partyInfo(mon.nextLevelLabel or "NEXT LEVEL", 134, 156,
      colors.green)
    self:label(mon.nextLevelText or "MAX", 134, 169, colors.ink)
    self:partyInfo(mon.nextExpLabel or "TO NEXT", 17, 193, colors.green)
    self:partyInfo(mon.nextValue or "0", 66, 193, colors.ink,
      158, "right")
  end

  function H:summaryMemo(mon, drawPortrait)
    self:summaryIdentity(mon, drawPortrait)
    self:summaryTrainerMemo(mon)
    self:summaryGrowthMemo(mon)
  end

  function H:summaryMemoTransition(mon, drawPortrait, progress)
    local G = ui.graphics
    progress = math.max(0, math.min(1, progress or 0))
    self:summaryIdentity(mon, drawPortrait)

    for slot = 1, 4 do
      local start = (slot - 1) * 0.025
      local rowProgress = math.max(0, math.min(1,
        (progress - start) / 0.58))
      rowProgress = rowProgress * rowProgress * (3 - 2 * rowProgress)
      G.push()
      G.translate(math.floor(-240 * rowProgress + 0.5), 0)
      self:summaryMoveRow(mon.moves[slot] or {}, 6,
        63 + (slot - 1) * 37, mon.moveIndex == slot)
      G.pop()
    end

    local function enter(start, draw)
      local cardProgress = math.max(0, math.min(1,
        (progress - start) / (1 - start)))
      cardProgress = 1 - (1 - cardProgress) ^ 3
      G.push()
      G.translate(math.floor(240 * (1 - cardProgress) + 0.5), 0)
      draw(self, mon)
      G.pop()
    end
    enter(0.32, H.summaryTrainerMemo)
    enter(0.38, H.summaryGrowthMemo)
  end

  function H:summaryIdentityTransition(mon, drawPortrait, progress)
    local G, colors = ui.graphics, self.colors
    progress = math.max(0, math.min(1, progress or 0))
    progress = 1 - (1 - progress) ^ 3
    local function mix(first, last)
      return math.floor(first + (last - first) * progress + 0.5)
    end
    local height = mix(80, 25)
    self:panel(6, 34, 228, height, false)
    self:summaryBall(mix(38, 20), mix(69, 46), mix(29, 10))
    drawPortrait(mon, mix(14, 10), mix(44, 36), mix(48, 20), false)

    self:partyName(mon.name, mix(72, 36), mix(39, 37), colors.ink,
      mix(139, 108))
    if mon.gender == "male" then
      self:genderIcon("male", mix(219, 145), mix(42, 40))
    elseif mon.gender == "female" then
      self:genderIcon("female", mix(219, 145), mix(42, 40))
    end
    self:partyInfo(mon.levelText, mix(132, 158), mix(53, 39), colors.ink)
    if mon.statusId then
      self:statusIcon(mon.statusId, mix(191, 194), mix(55, 40))
    end
    self:partyInfo(mon.hpLabel or "HP", mix(72, 36), mix(79, 47),
      colors.green)
    self:partyInfo(mon.hpText, mix(72, 158), mix(79, 47), colors.ink,
      mix(155, 69), "right")
    self:hpBar(mix(72, 55), mix(90, 50), mix(155, 96), mon.hp, mon.maxHp)

    local clipX, clipY = G.transformPoint(6, 34)
    local clipRight, clipBottom = G.transformPoint(234, 34 + height)
    local oldX, oldY, oldWidth, oldHeight = G.getScissor()
    G.setScissor(clipX, clipY, clipRight - clipX, clipBottom - clipY)
    G.push()
    G.translate(math.floor(240 * progress + 0.5), 0)
    self:partyInfo(mon.dexText, 72, 53, colors.green)
    self:typeBadges(mon, 72, 66, false)
    if mon.info2Label then
      self:partyInfo(mon.infoLabel, 121, 66, colors.green)
      self:partyInfo(mon.infoText, 139, 66, colors.ink, 27, "right")
      self:partyInfo(mon.info2Label, 171, 66, colors.green)
      self:partyInfo(mon.info2Text, 190, 66, colors.ink, 37, "right")
    else
      self:partyInfo(mon.infoLabel or "ITEM", 121, 66, colors.green)
      self:partyInfo(mon.infoText or "---", 151, 66, colors.ink,
        76, "right")
    end
    self:partyInfo(mon.expLabel or "EXP", 72, 98, colors.green)
    if mon.expProgress then
      self:expBar(99, 103, mon.nextValue and 64 or 128, mon.expProgress)
    end
    if mon.nextValue then
      self:partyInfo(mon.nextLabel or "NEXT", 168, 98, colors.green)
      self:partyInfo(mon.nextValue, 195, 98, colors.ink, 32, "right")
    end
    G.pop()
    if oldX then G.setScissor(oldX, oldY, oldWidth, oldHeight)
    else G.setScissor() end
  end

  function H:summaryMovesTransition(mon, drawPortrait, progress)
    progress = math.max(0, math.min(1, progress or 0))
    local topProgress = math.min(1, progress / 0.40)
    self:summaryIdentityTransition(mon, drawPortrait, topProgress)

    local exitProgress = math.min(1, progress / 0.55)
    local slide = exitProgress * exitProgress * (3 - 2 * exitProgress)
    ui.graphics.push()
    ui.graphics.translate(math.floor(-240 * slide + 0.5), 0)
    self:summaryStats(mon)
    ui.graphics.pop()

    for slot = 1, 4 do
      local start = 0.28 + (slot - 1) * 0.04
      local rowProgress = math.max(0, math.min(1,
        (progress - start) / (1 - start)))
      rowProgress = 1 - (1 - rowProgress) ^ 3
      ui.graphics.push()
      ui.graphics.translate(math.floor(240 * (1 - rowProgress) + 0.5), 0)
      self:summaryMoveRow(mon.moves[slot] or {}, 6,
        63 + (slot - 1) * 37, mon.moveIndex == slot)
      ui.graphics.pop()
    end
  end

  function H:summaryTransition(mon, drawPortrait, progress, actionCount,
      statsLabel, swapLabel)
    local G = ui.graphics
    progress = math.max(0, math.min(1, progress or 0))
    local eased = 1 - (1 - progress) ^ 3
    local heroY = self:partyActionHeroY(actionCount)
    local actionOffset = math.floor(132 * eased + 0.5)

    local anchorProgress = math.min(1, progress / 0.20)
    local anchorX = 64 - 12 * anchorProgress
    local anchorY = heroY + (42 - heroY) * anchorProgress
    if progress < 0.20 then
      self:partyCard(mon, anchorX, anchorY, true, false, drawPortrait)
    else
      local panelProgress = (progress - 0.20) / 0.80
      panelProgress = 1 - (1 - panelProgress) ^ 3
      local x = 52 + (6 - 52) * panelProgress
      local y = 42 + (34 - 42) * panelProgress
      local width = 112 + (228 - 112) * panelProgress
      local height = 56 + (80 - 56) * panelProgress
      local clipX, clipY = G.transformPoint(x, y)
      local clipRight, clipBottom = G.transformPoint(x + width, y + height)
      local oldX, oldY, oldWidth, oldHeight = G.getScissor()
      G.setScissor(clipX, clipY, clipRight - clipX, clipBottom - clipY)
      G.push()
      G.translate(x - 6, y - 34)
      self:summaryTop(mon, drawPortrait)
      G.pop()
      if oldX then G.setScissor(oldX, oldY, oldWidth, oldHeight)
      else G.setScissor() end
    end

    local left, top, width, height = self:partyActionRow(1, actionCount)
    self:actionRow(left, top, width, height, statsLabel, "stats", actionOffset)
    if actionCount > 1 then
      left, top, width, height = self:partyActionRow(2, actionCount)
      self:actionRow(left, top, width, height, swapLabel, "swap", actionOffset)
    end

    local statsProgress = math.max(0, math.min(1,
      (progress - 0.28) / 0.72))
    statsProgress = 1 - (1 - statsProgress) ^ 3
    G.push()
    G.translate(0, math.floor(98 * (1 - statsProgress) + 0.5))
    self:summaryStats(mon)
    G.pop()
  end

  function H:partySlot(x, y, count)
    local hx, hy = x * 1.5, y * 1.5
    local col = hx >= 120 and 1 or 0
    for row = 0, 2 do
      local slot = row * 2 + col + 1
      local _, top = self:partyPosition(slot)
      if slot <= count and hy >= top and hy < top + 56 then return slot end
    end
  end

  function H:hpBar(x, y, w, hp, maxHp)
    local ratio = math.max(0, math.min(1, (hp or 0) / math.max(1, maxHp or 1)))
    box("fill", x, y, w, 5, self.colors.outline)
    box("fill", x + 1, y + 1, w - 2, 3, self.colors.silver)
    box("fill", x + 1, y + 1, math.floor((w - 2) * ratio), 3,
      ratio > 0.5 and self.colors.hp
        or ratio > 0.2 and self.colors.hpMid or self.colors.hpLow)
  end

  function H:expBar(x, y, w, ratio)
    ratio = math.max(0, math.min(1, ratio or 0))
    box("fill", x, y, w, 4, self.colors.outline)
    box("fill", x + 1, y + 1, w - 2, 2, self.colors.silverDark)
    box("fill", x + 1, y + 1, math.floor((w - 2) * ratio), 2,
      self.colors.exp)
  end

  return H
end
