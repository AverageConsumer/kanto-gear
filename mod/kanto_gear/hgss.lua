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
      [1] = { x = 22, y = 25, w = 116, h = 62, color = "red" },
      [2] = { x = 107, y = 92, w = 49, h = 38, color = "green" },
      [3] = { x = 4, y = 92, w = 49, h = 38, color = "amber" },
      [4] = { x = 57, y = 104, w = 46, h = 28, color = "blue" },
    },
  }

  function H:setVariant(dark)
    self.palette = dark and darkPalette or lightPalette
    self.colors = dark and darkColors or lightColors
  end

  local box, text, fit, glyphs, color =
    ui.box, ui.text, ui.fit, ui.glyphs, ui.color
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

  function H:detailChevron(x, y, tint)
    local G = ui.graphics
    color(tint)
    G.setLineWidth(2)
    G.line(x, y, x + 5, y + 4, x, y + 8)
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
      self:chevron(left, 13, false)
      self:chevron(right, 13, true)
    end
    local width = paged and (back and 76 or 88) or (back and 100 or 124)
    local shown = self:fitLabel(title, width)
    local x = paged and center - math.floor(self:labelWidth(shown) / 2)
      or back and 31 or 71 - math.floor(self:labelWidth(shown) / 2)
    self:label(shown, x, 6, colors.ink)
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
    clipped(x, y, w, h, colors.surface)
    box("fill", x + 2, y + 2, w - 4, 2, colors.highlight)
    border(x, y, w, h, selected and accent or colors.ink)
    if selected then box("fill", x, y + 4, 2, math.max(1, h - 8), accent) end
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
  end

  function H:partyActionAnimating(now)
    return self.partyActionStarted
      and now - self.partyActionStarted < 0.14
  end

  function H:partyActionOffset(now)
    if not self:partyActionAnimating(now) then return 0 end
    local remaining = 1 - (now - self.partyActionStarted) / 0.14
    return math.floor(6 * remaining * remaining + 0.5)
  end

  function H:actionRow(x, y, w, h, label, kind, offset)
    local G, colors = ui.graphics, self.colors
    local accent = kind == "swap" and colors.amberLight or colors.blueLight
    y = y + (offset or 0)
    clipped(x + 1, y + 2, w, h, colors.shadow)
    clipped(x, y, w, h, colors.surface)
    box("fill", x + 2, y + 2, w - 4, 2, colors.highlight)
    border(x, y, w, h, colors.outline)
    box("fill", x + 2, y + 5, 4, h - 10, accent)
    if kind == "swap" then
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
    self:detailChevron(x + w - 16, y + 16, colors.ink)
  end

  function H:action(index, label, selected)
    local action = self.battleActions[index]
    local dark = self.colors[action.color]
    local light = self.colors[action.color .. "Light"]
    clipped(action.x + 1, action.y + 1, action.w, action.h, self.colors.shadow)
    clipped(action.x, action.y, action.w, action.h, dark)
    box("fill", action.x + 2, action.y + 2, action.w - 4,
      math.max(2, math.floor(action.h * 0.34)), light)
    border(action.x, action.y, action.w, action.h,
      selected and self.colors.white or self.colors.ink)
    if selected then
      box("fill", action.x, action.y + 5, 2, math.max(1, action.h - 10),
        self.colors.white)
    end
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

  function H:partyPanel(x, y, w, h, selected, fainted)
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

  function H:partyCard(mon, x, y, selected, details, drawPortrait)
    local fainted = mon and (mon.statusId == "FNT"
      or mon.hp ~= nil and mon.hp <= 0)
    self:partyPanel(x, y, 112, 56, selected, fainted)
    if not mon then
      self:label("-", x, y + 18, self.colors.ink, 112, "center")
      return
    end
    self:partyPortrait(x + 5, y + 2, selected, fainted)
    drawPortrait(mon, x + 6, y + 4, 32, fainted)
    local ink = self.colors.white
    local quiet = selected and self.colors.white or self.colors.silver
    self:partyName(mon.name, x + 44, y + 4, ink, details and 61 or 67)
    if details then self:detailChevron(x + 102, y + 6, ink) end
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
