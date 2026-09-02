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
  local BACKDROP_CENTER_Y = 121
  local H = {
    palette = lightPalette,
    colors = lightColors,
    backdropCenterY = BACKDROP_CENTER_Y,
    battleBagOffsetY = 8,
    battleActions = {
      [1] = { x = 22, y = 32, w = 196, h = 122, color = "red" },
      [2] = { x = 166, y = 159, w = 68, h = 52, color = "green" },
      [3] = { x = 6, y = 159, w = 68, h = 52, color = "amber" },
      [4] = { x = 86, y = 159, w = 68, h = 52, color = "blue" },
    },
    fullBattleActions = {
      [1] = { x = 6, y = 117, w = 112, h = 44, color = "red" },
      [2] = { x = 122, y = 117, w = 112, h = 44, color = "green" },
      [3] = { x = 6, y = 166, w = 112, h = 44, color = "amber" },
      [4] = { x = 122, y = 166, w = 112, h = 44, color = "blue" },
    },
  }

  function H:setVariant(dark)
    self.palette = dark and darkPalette or lightPalette
    self.colors = dark and darkColors or lightColors
    self.dark = dark
  end

  function H:setTouch(x, y)
    self.touchX, self.touchY = tonumber(x), tonumber(y)
  end

  function H:isPressed(x, y, w, h, enabled, scale)
    if enabled == false or self.pressActive
        or not self.touchX or not self.touchY then return false end
    scale = scale or 1.5
    local tx, ty = self.touchX * scale, self.touchY * scale
    x = x + (self.pressOffsetX or 0)
    y = y + (self.pressOffsetY or 0)
    return tx >= x and tx < x + w and ty >= y and ty < y + h
  end

  function H:beginPress(x, y, w, h, enabled, scale, offset)
    local pressed = self:isPressed(x, y, w, h, enabled, scale)
    if pressed then
      self.pressActive = true
      ui.graphics.push()
      ui.graphics.translate(0, offset or 2)
    end
    return pressed
  end

  function H:endPress(pressed)
    if not pressed then return end
    ui.graphics.pop()
    self.pressActive = false
  end

  function H:shadowVisible()
    return not self.pressActive
  end

  local box, text, fit, glyphs, color =
    ui.box, ui.text, ui.fit, ui.glyphs, ui.color
  local translate = ui.translate or function(value) return value end
  local format = ui.format or function(value, ...)
    return string.format(translate(value), ...)
  end
  local runnerParts = {
    { 119, 155, 3, 5 }, { 118, 156, 5, 3 },
    { 118, 163, 4, 7 },
    { 114, 163, 4, 2 }, { 113, 165, 2, 6 },
    { 121, 163, 2, 2 }, { 122, 164, 3, 2 },
    { 124, 165, 5, 2 },
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
  local trainerNameFont = ui.font and ui.graphics.newFont(ui.font, 14)
    or ui.graphics.newFont(14)
  local trainerValueFont = ui.font and ui.graphics.newFont(ui.font, 12)
    or ui.graphics.newFont(12)
  local trainerNumberFont = ui.font and ui.graphics.newFont(ui.font, 22)
    or ui.graphics.newFont(22)
  partyFont:setFilter("linear", "linear")
  partyNameFont:setFilter("linear", "linear")
  partyInfoFont:setFilter("linear", "linear")
  partyTypeFont:setFilter("linear", "linear")
  trainerNameFont:setFilter("linear", "linear")
  trainerValueFont:setFilter("linear", "linear")
  trainerNumberFont:setFilter("linear", "linear")

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

  local function displayText(value)
    return tostring(value or ""):gsub("<PK><MN>", "PKMN")
  end

  local function fitFont(value, width, font)
    local chars = glyphs(displayText(value))
    if font:getWidth(table.concat(chars)) <= width then
      return table.concat(chars)
    end
    repeat table.remove(chars) until #chars == 0
      or font:getWidth(table.concat(chars) .. "…") <= width
    return table.concat(chars) .. "…"
  end

  local function splitFont(value, width, font)
    local chars = glyphs(displayText(value))
    local middle = math.floor(#chars / 2)
    for distance = 0, #chars do
      for _, cut in ipairs({ middle - distance, middle + distance }) do
        if cut > 0 and cut < #chars then
          local first = table.concat(chars, "", 1, cut):gsub("%s+$", "")
          local second = table.concat(chars, "", cut + 1):gsub("^%s+", "")
          if font:getWidth(first) <= width and font:getWidth(second) <= width then
            return first, second
          end
        end
      end
    end
  end

  function H:fitLabel(value, width)
    return fitFont(value, width, partyFont)
  end

  function H:partyName(value, x, y, tint, width)
    local G, previous = ui.graphics, ui.graphics.getFont()
    value = displayText(value)
    local chars = glyphs(value)
    while partyNameFont:getWidth(table.concat(chars)) > width
        and #chars > 0 do table.remove(chars) end
    local shown = table.concat(chars)
    if shown ~= value then
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
    value = displayText(value)
    ui.color(tint)
    G.setFont(partyInfoFont)
    if width then G.printf(value, x, y, width, align or "left")
    else G.print(value, x, y) end
    if previous then G.setFont(previous) end
  end

  function H:partyInfoWidth(value)
    return partyInfoFont:getWidth(displayText(value))
  end

  function H:fitPartyInfo(value, width)
    return fitFont(value, width, partyInfoFont)
  end

  function H:splitPartyInfo(value, width)
    value = displayText(value)
    if partyInfoFont:getWidth(value) <= width then return value end
    local bestFirst, bestSecond, bestBalance
    for cut = 1, #value do
      if value:sub(cut, cut):match("%s") then
        local first = value:sub(1, cut - 1):gsub("%s+$", "")
        local second = value:sub(cut + 1):gsub("^%s+", "")
        if first ~= "" and second ~= ""
            and partyInfoFont:getWidth(first) <= width
            and partyInfoFont:getWidth(second) <= width then
          local balance = math.abs(partyInfoFont:getWidth(first)
            - partyInfoFont:getWidth(second))
          if not bestBalance or balance < bestBalance then
            bestFirst, bestSecond, bestBalance = first, second, balance
          end
        end
      end
    end
    if bestFirst then return bestFirst, bestSecond end
    local first, second = splitFont(value, width, partyInfoFont)
    if first then return first, second end
    return fitFont(value, width, partyInfoFont)
  end

  function H:fitPartyType(value, width)
    return fitFont(value, width, partyTypeFont)
  end

  function H:partyType(value, x, y, tint, width)
    local G, previous = ui.graphics, ui.graphics.getFont()
    local shown = displayText(value)
    ui.color(tint)
    G.setFont(partyTypeFont)
    G.print(shown, x + math.floor((width - partyTypeFont:getWidth(shown))
      / 2 + 0.5), y)
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
    local pressed = self:beginPress(x - 9, y - 10, 18, 20)
    color(self.colors.green)
    G.setLineWidth(2)
    if right then G.line(x - 2, y - 4, x + 2, y, x - 2, y + 4)
    else G.line(x + 2, y - 4, x - 2, y, x + 2, y + 4) end
    G.setLineWidth(1)
    self:endPress(pressed)
  end

  function H:pageChevron(x, y, right, interactive)
    local G = ui.graphics
    local pressed = self:beginPress(x - 8, y - 9, 16, 18,
      interactive ~= false)
    color(self.colors.amberLight)
    G.setLineWidth(1)
    if right then G.line(x - 2, y - 3, x + 1, y, x - 2, y + 3)
    else G.line(x + 2, y - 3, x - 1, y, x + 2, y + 3) end
    self:endPress(pressed)
  end

  function H:detailChevron(x, y, tint, large)
    local G = ui.graphics
    color(tint)
    G.setLineWidth(large and 2 or 1)
    if large then G.line(x, y, x + 5, y + 4, x, y + 8)
    else G.line(x, y, x + 3, y + 2, x, y + 4) end
    G.setLineWidth(1)
  end

  function H:headerBar(title, back, paged, contentOffsetY)
    local colors = self.colors
    contentOffsetY = contentOffsetY or 0
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
      self:chevron(14, 13 + contentOffsetY, false)
      box("fill", 25, 6, 1, 15, colors.band)
      left, center = 36, 82
    end
    if paged then
      if back then
        self:pageChevron(34, 13 + contentOffsetY, false)
        self:pageChevron(130, 13 + contentOffsetY, true)
      else
        self:chevron(left, 13 + contentOffsetY, false)
        self:chevron(right, 13 + contentOffsetY, true)
      end
    end
    local width = paged and (back and 80 or 88) or (back and 100 or 124)
    local shown = self:fitLabel(title, width)
    local x = (paged or back)
      and center - math.floor(self:labelWidth(shown) / 2)
      or 71 - math.floor(self:labelWidth(shown) / 2)
    self:label(shown, x, 6 + contentOffsetY, colors.ink)
    return x, self:labelWidth(shown)
  end

  local function pokeballEmboss(colors, width, centerY, lineWidth)
    local G, scale = ui.graphics, width / 240
    color(colors.partyEmboss)
    G.setLineWidth(lineWidth)
    G.circle("line", width / 2, centerY, 94 * scale)
    G.line(26 * scale, centerY, 104 * scale, centerY)
    G.line(136 * scale, centerY, 214 * scale, centerY)
    G.circle("line", width / 2, centerY, 16 * scale)
    G.circle("line", width / 2, centerY, 7 * scale)
    G.setLineWidth(1)
  end

  local function pokeballBackdrop(colors, width, height, lineWidth)
    color(colors.partyBg)
    ui.graphics.rectangle("fill", 0, 0, width, height)
    pokeballEmboss(colors, width, BACKDROP_CENTER_Y * width / 240,
      lineWidth)
  end

  function H:backdrop()
    -- This base is rendered at 1.5x by the app. Keep it geometrically
    -- identical to battleBackdrop so every HGSS screen starts from the same
    -- Poké Ball visual language.
    pokeballBackdrop(self.colors, 160, 144, 4 / 3)
  end

  function H:focusSurface(selected, base, accent)
    if not selected then return base end
    if not accent then return self.colors.focus end
    local amount = 0.65
    return {
      base[1] + (accent[1] - base[1]) * amount,
      base[2] + (accent[2] - base[2]) * amount,
      base[3] + (accent[3] - base[3]) * amount,
      base[4] or 1,
    }
  end

  function H:itemAccent(icon)
    local colors = self.colors
    return icon == "ball" and colors.redLight
      or icon == "medicine" and colors.blueLight
      or icon == "status" and colors.greenLight
      or icon == "machine" and colors.amberLight
      or colors.blueLight
  end

  local function mixed(a, b, amount)
    return {
      a[1] + (b[1] - a[1]) * amount,
      a[2] + (b[2] - a[2]) * amount,
      a[3] + (b[3] - a[3]) * amount,
      a[4] or 1,
    }
  end

  function H:panel(x, y, w, h, selected, focusAccent, baseAccent)
    local colors = self.colors
    if self:shadowVisible() then
      clipped(x + 1, y + 1, w, h, colors.shadow)
    end
    local base = baseAccent and mixed(colors.surface, baseAccent,
      self.dark and 0.15 or 0.10) or colors.surface
    clipped(x, y, w, h,
      self:focusSurface(selected, base, focusAccent))
    border(x, y, w, h, colors.ink)
    if baseAccent then
      box("fill", x + 5, y + 2, w - 10, 1,
        mixed(colors.highlight, baseAccent, 0.20))
    end
    if selected then self:focusFrame(x, y, w, h) end
  end

  function H:homeTile(x, y, w, h, accent, selected)
    local G, colors = ui.graphics, self.colors
    if self:shadowVisible() then
      color(colors.shadow)
      G.rectangle("fill", x + 1, y + 2, w, h, 5, 5)
    end
    color(mixed(colors.surface, accent, self.dark and 0.13 or 0.08))
    G.rectangle("fill", x, y, w, h, 5, 5)
    color(colors.outline)
    G.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 5, 5)
    box("fill", x + 5, y + 2, w - 10, 1,
      mixed(colors.highlight, accent, 0.18))
    if selected then self:roundedFocusFrame(x, y, w, h, 5) end
  end

  function H:homeWidgetHeader(x, y, w, label, accent, accentLight, editing)
    box("fill", x + 2, y + 2, w - 4, 17, accent)
    box("fill", x + 2, y + 2, w - 4, 2, accentLight)
    local shown = self:fitPartyInfo(translate(label), w - 28)
    local width = self:partyInfoWidth(shown)
    self:partyInfo(shown, x + math.floor((w - width) / 2), y + 3,
      self.colors.white)
    if not editing then
      self:detailChevron(x + w - 10, y + 7, self.colors.white)
    end
  end

  local homeIconColors = {
    ink = { 0.09, 0.11, 0.10, 1 },
    deep = { 0.16, 0.20, 0.19, 1 },
    paper = { 0.91, 0.93, 0.86, 1 },
    white = { 0.98, 0.98, 0.94, 1 },
    silver = { 0.66, 0.72, 0.69, 1 },
    silverLight = { 0.86, 0.90, 0.86, 1 },
    red = { 0.84, 0.20, 0.16, 1 },
    redLight = { 1.00, 0.38, 0.27, 1 },
    redDark = { 0.48, 0.10, 0.09, 1 },
    blue = { 0.20, 0.49, 0.72, 1 },
    blueLight = { 0.42, 0.72, 0.88, 1 },
    blueDark = { 0.08, 0.26, 0.40, 1 },
    green = { 0.23, 0.62, 0.35, 1 },
    greenLight = { 0.48, 0.80, 0.48, 1 },
    greenDark = { 0.09, 0.34, 0.20, 1 },
    amber = { 0.91, 0.57, 0.10, 1 },
    amberLight = { 1.00, 0.77, 0.25, 1 },
    amberDark = { 0.51, 0.28, 0.06, 1 },
    skin = { 0.92, 0.63, 0.43, 1 },
  }

  function H:homePokedexIcon(x, y)
    local c = homeIconColors
    clipped(x + 2, y + 1, 23, 25, c.ink)
    clipped(x + 3, y + 2, 21, 23, c.redDark)
    box("fill", x + 4, y + 3, 17, 19, c.red)
    box("fill", x + 5, y + 3, 15, 2, c.redLight)
    box("fill", x + 4, y + 5, 3, 18, c.redDark)
    box("fill", x + 7, y + 5, 1, 18, c.ink)
    box("fill", x + 10, y + 6, 10, 9, c.ink)
    box("fill", x + 11, y + 7, 8, 7, c.blue)
    box("fill", x + 12, y + 8, 6, 2, c.blueLight)
    box("fill", x + 10, y + 18, 3, 3, c.deep)
    box("fill", x + 16, y + 18, 2, 2, c.white)
    box("fill", x + 20, y + 17, 2, 4, c.amberLight)
    box("fill", x + 20, y + 22, 2, 1, c.redLight)
    box("fill", x + 8, y + 23, 13, 1, c.redLight)
  end

  function H:homeTrainerIcon(x, y)
    local G, c = ui.graphics, homeIconColors
    clipped(x + 1, y + 3, 25, 22, c.ink)
    clipped(x + 2, y + 4, 23, 20, c.blueDark)
    clipped(x + 3, y + 5, 21, 17, c.paper)
    box("fill", x + 4, y + 6, 19, 2, c.blue)
    box("fill", x + 4, y + 20, 19, 2, c.amber)
    color(c.skin)
    G.circle("fill", x + 9, y + 13, 4)
    box("fill", x + 5, y + 17, 9, 3, c.blue)
    box("fill", x + 5, y + 10, 8, 2, c.red)
    box("fill", x + 7, y + 9, 5, 1, c.redLight)
    box("fill", x + 12, y + 11, 2, 2, c.ink)
    box("fill", x + 16, y + 10, 6, 2, c.blue)
    box("fill", x + 16, y + 14, 6, 1, c.deep)
    box("fill", x + 16, y + 17, 4, 1, c.deep)
    box("fill", x + 22, y + 6, 1, 2, c.blueLight)
  end

  local function fontText(font, value, x, y, tint, width, align)
    local G, previous = ui.graphics, ui.graphics.getFont()
    color(tint)
    G.setFont(font)
    if width then G.printf(tostring(value), x, y, width, align or "left")
    else G.print(tostring(value), x, y) end
    if previous then G.setFont(previous) end
  end

  local function trainerFit(font, value, width)
    local chars = glyphs(tostring(value or ""))
    while #chars > 1 and font:getWidth(table.concat(chars)) > width do
      table.remove(chars)
    end
    return table.concat(chars)
  end

  local function trainerStatIcon(theme, kind, cx, y, tint)
    local G, colors = ui.graphics, theme.colors
    color(colors.outline)
    if kind == "money" then
      G.circle("fill", cx, y + 6, 7)
      color(tint); G.circle("fill", cx, y + 6, 5)
      box("fill", cx - 1, y + 2, 2, 8, colors.white)
      box("fill", cx - 4, y + 4, 8, 2, colors.white)
    elseif kind == "time" then
      G.circle("fill", cx, y + 6, 7)
      color(theme.dark and colors.surface or colors.white)
      G.circle("fill", cx, y + 6, 5)
      color(tint); G.setLineWidth(2)
      G.line(cx, y + 6, cx, y + 3, cx + 3, y + 7)
      G.setLineWidth(1)
    elseif kind == "pokedex" then
      clipped(cx - 7, y, 14, 13, colors.outline)
      clipped(cx - 6, y + 1, 12, 11, tint)
      box("fill", cx - 3, y + 3, 7, 5, colors.outline)
      box("fill", cx - 2, y + 4, 5, 3, colors.blueLight)
      box("fill", cx - 4, y + 10, 8, 1, colors.white)
    else
      box("fill", cx - 2, y, 4, 7, colors.outline)
      box("fill", cx - 4, y + 5, 6, 4, colors.outline)
      box("fill", cx - 6, y + 8, 8, 5, colors.outline)
      box("fill", cx - 1, y + 1, 2, 5, tint)
      box("fill", cx - 3, y + 6, 4, 2, tint)
      box("fill", cx - 5, y + 9, 6, 2, tint)
    end
  end

  function H:homeStepsIcon(x, y)
    local G, c = ui.graphics, homeIconColors
    color(c.ink)
    G.polygon("fill", x + 5, y + 3, x + 13, y + 3,
      x + 13, y + 9, x + 16, y + 9, x + 16, y + 12,
      x + 20, y + 12, x + 20, y + 14, x + 23, y + 14,
      x + 25, y + 17, x + 25, y + 24, x + 2, y + 24,
      x + 2, y + 18, x + 4, y + 18, x + 4, y + 6,
      x + 5, y + 6)
    color(c.green)
    G.polygon("fill", x + 6, y + 5, x + 11, y + 5,
      x + 11, y + 11, x + 15, y + 11, x + 15, y + 14,
      x + 19, y + 14, x + 19, y + 16, x + 22, y + 16,
      x + 23, y + 18, x + 23, y + 20, x + 4, y + 20,
      x + 4, y + 19, x + 6, y + 17)
    box("fill", x + 5, y + 19, 18, 2, c.greenLight)
    box("fill", x + 3, y + 21, 21, 2, c.white)
    box("fill", x + 7, y + 6, 3, 4, c.greenLight)
    box("fill", x + 8, y + 11, 7, 1, c.white)
    box("fill", x + 10, y + 13, 6, 1, c.white)
    box("fill", x + 20, y + 17, 3, 2, c.greenLight)
  end

  function H:trainerStat(x, label, value, kind, accent, width)
    local colors = self.colors
    local quiet = self.dark and colors.silver or colors.silverDark
    width = width or 72
    self:homeTile(x, 151, width, 60, accent, false)
    box("fill", x + 5, 153, width - 10, 2, accent)
    trainerStatIcon(self, kind, x + math.floor(width / 2), 158, accent)
    local shown = self:fitPartyType(translate(label), width - 6)
    self:partyType(shown, x + 3, 174, quiet, width - 6)
    local valueText = trainerFit(trainerValueFont, value, width - 8)
    fontText(trainerValueFont, valueText, x + 4, 187, colors.ink,
      width - 8, "center")
  end

  function H:trainer(model)
    local G, colors = ui.graphics, self.colors
    local quiet = self.dark and colors.silver or colors.silverDark
    local blue = self.dark and colors.blueLight or colors.blue
    local amber = self.dark and colors.amberLight or colors.amber
    self:homeTile(7, 33, 226, 55, colors.blue, false)
    box("fill", 9, 35, 222, 3, colors.blueLight)
    clipped(13, 39, 42, 42, colors.outline)
    clipped(14, 40, 40, 40,
      mixed(colors.surface, colors.blueLight, self.dark and 0.25 or 0.16))
    color(colors.band)
    G.circle("fill", 34, 60, 15)
    if model.drawPlayer then model.drawPlayer(34, 63, 2) end

    local name = trainerFit(trainerNameFont, model.name, 158)
    fontText(trainerNameFont, name, 64, 38, colors.ink)
    local region = self:fitPartyType(model.region or "KANTO", 72)
    self:partyType(region, 65, 56, blue, 72)
    clipped(64, 68, 76, 13, colors.bandLight)
    border(64, 68, 76, 13, colors.blue)
    self:partyType(self:fitPartyType(model.idText or "ID -----", 72),
      66, 69, colors.ink, 72)
    clipped(145, 68, 76, 13,
      mixed(colors.surface, colors.amberLight, self.dark and 0.20 or 0.12))
    border(145, 68, 76, 13, colors.amber)
    self:partyType(self:fitPartyType(model.badgeText or "0/8", 72),
      147, 69, colors.ink, 72)

    self:homeTile(7, 92, 226, 54, colors.amber, false)
    self:partyType(self:fitPartyType(translate("BADGES"), 100),
      11, 97, quiet, 100)
    self:partyType(self:fitPartyType(model.badgeRegion or model.region, 100),
      129, 97, amber, 100)
    for index = 1, 8 do
      local cx = 26 + (index - 1) * 27
      color(model.badgeOwned[index] and colors.bandLight or colors.silverDark)
      G.circle("fill", cx, 128, 10)
      color(colors.outline); G.circle("line", cx, 128, 10)
      local drawn = model.drawBadge and model.drawBadge(index, cx, 128,
        model.badgeOwned[index])
      if not drawn then
        color(model.badgeOwned[index] and colors.amberLight or colors.silver)
        G.circle("fill", cx, 128, 4)
        color(colors.outline); G.circle("line", cx, 128, 4)
      end
    end

    self:trainerStat(7, "MONEY", model.money, "money", colors.amber)
    self:trainerStat(84, "TIME", model.time, "time", colors.blue)
    self:trainerStat(161, "POKEDEX", model.pokedex, "pokedex", colors.red)
  end

  function H:steps(model)
    local G, colors = ui.graphics, self.colors
    local quiet = self.dark and colors.silver or colors.silverDark
    self:homeTile(12, 42, 216, 101, colors.green, false)
    box("fill", 14, 44, 212, 18, colors.green)
    box("fill", 19, 44, 202, 2, colors.greenLight)
    self:partyType(translate("STEP COUNTER"), 20, 48,
      colors.white, 200)
    clipped(24, 70, 52, 52,
      mixed(colors.surface, colors.greenLight, self.dark and 0.20 or 0.28))
    border(24, 70, 52, 52, colors.outline)
    G.push(); G.translate(23, 69); G.scale(2, 2)
    self:homeStepsIcon(0, 0); G.pop()
    local exact = trainerFit(trainerNumberFont, model.steps, 132)
    fontText(trainerNumberFont, exact, 84, 73, colors.ink, 132, "center")
    self:partyInfo(self:fitPartyInfo(translate("TOTAL STEPS"), 132),
      84, 105, quiet, 132, "center")
    box("fill", 84, 119, 132, 3, colors.greenLight)

    local pressed = self:beginPress(54, 165, 132, 38, true)
    self:homeTile(54, 165, 132, 38, colors.red, false)
    box("fill", 59, 167, 122, 2, colors.redLight)
    self:label(self:fitLabel(translate("RESET"), 112), 64, 176,
      colors.ink, 112, "center")
    self:endPress(pressed)
  end

  function H:stepsHit(x, y)
    local hx, hy = x * 1.5, y * 1.5
    return hx >= 54 and hx < 186 and hy >= 165 and hy < 203
      and "reset" or nil
  end

  local function dexPager(self, page, pages)
    local colors = self.colors
    self:panel(82, 199, 76, 12, false)
    self:pageChevron(91, 205, false, pages > 1)
    self:partyType(tostring(page) .. "/" .. tostring(pages),
      99, 199, colors.green, 42)
    self:pageChevron(149, 205, true, pages > 1)
  end

  function H:pokedexIndex(model)
    local G, colors = ui.graphics, self.colors
    local quiet = self.dark and colors.silver or colors.silverDark
    self:homeTile(7, 34, 226, 30, colors.red, false)
    self:partyType(translate(model.region or "NATIONAL DEX"),
      12, 39, quiet, 92)
    self:partyInfo(tostring(model.caught or 0) .. " / "
      .. tostring(model.total or 0), 112, 37, colors.ink, 112, "right")
    local fraction = math.max(0, math.min(1,
      (tonumber(model.caught) or 0) / math.max(1, tonumber(model.total) or 1)))
    border(12, 53, 212, 5, colors.outline)
    box("fill", 13, 54, 210, 3, colors.silverDark)
    box("fill", 13, 54, math.floor(210 * fraction + 0.5), 3,
      colors.redLight)

    for index, entry in ipairs(model.entries or {}) do
      local column, row = (index - 1) % 3, math.floor((index - 1) / 3)
      local left, top = 7 + column * 77, 68 + row * 43
      local pressed = self:beginPress(left, top, 72, 41)
      local entryAccent = entry.caught and colors.greenLight
        or entry.seen and colors.blueLight or colors.silverDark
      self:panel(left, top, 72, 41, entry.selected, colors.redLight,
        entryAccent)
      self:partyType(("%03d"):format(tonumber(entry.dex) or 0),
        left + 3, top + 2, quiet, 22)
      color(entry.caught and colors.bandLight
        or mixed(colors.surface, colors.redLight, self.dark and 0.18 or 0.10))
      G.circle("fill", left + 36, top + 18, 11)
      color(colors.outline); G.circle("line", left + 36, top + 18, 11)
      if model.drawPokemon then
        model.drawPokemon(entry, left + 26, top + 8, 20, not entry.caught)
      end
      if entry.caught then self:battleTeamBall(left + 63, top + 8, true) end
      self:partyType(self:fitPartyType(entry.name or "---", 66),
        left + 3, top + 29, entry.caught and colors.ink or quiet, 66)
      self:endPress(pressed)
    end
    dexPager(self, model.page or 1, model.pages or 1)
  end

  function H:pokedexProfile(model)
    local G, colors = ui.graphics, self.colors
    local quiet = self.dark and colors.silver or colors.silverDark
    local mon = model.pokemon or {}
    self:homeTile(7, 34, 226, 70, colors.red, false)
    color(mixed(colors.surface, colors.redLight, self.dark and 0.22 or 0.12))
    G.circle("fill", 45, 69, 27)
    color(colors.outline); G.circle("line", 45, 69, 27)
    if model.drawPokemon then model.drawPokemon(mon, 18, 42, 54, false) end
    self:partyInfo(self:fitPartyInfo(mon.name or translate("POKEMON"), 142),
      80, 39, colors.ink)
    self:typeBadges(mon, 80, 56, false)
    self:partyType(self:fitPartyType(mon.kind or translate("UNKNOWN"), 67),
      155, 57, quiet, 67)
    self:partyType(self:fitPartyType(mon.height or translate("HEIGHT --"), 67),
      80, 76, colors.green, 67)
    self:partyType(self:fitPartyType(mon.weight or translate("WEIGHT --"), 67),
      155, 76, colors.green, 67)
    if mon.caught then
      self:battleTeamBall(214, 44, true)
    else
      self:partyType(translate("NOT CAUGHT"), 152, 40, colors.red, 70)
    end

    self:panel(7, 108, 226, 43, false, nil,
      self:typeColor(mon.types and mon.types[1]))
    local lines = mon.description or { translate("NO DETAILS AVAILABLE") }
    local visible = math.min(3, #lines)
    local firstY = 115 + math.floor((29 - visible * 9) / 2)
    for index = 1, visible do
      self:partyInfo(self:fitPartyInfo(lines[index], 210),
        15, firstY + (index - 1) * 9, colors.ink, 210, "center")
    end

    local cards = {
      { "STATS", model.statsText or translate("BASE POWER"), colors.blue },
      { "HABITAT", model.habitatText or translate("WHERE TO FIND"), colors.green },
      { "MOVES", model.movesText or translate("LEARNSET"), colors.amber },
    }
    for index, card in ipairs(cards) do
      local left = 7 + (index - 1) * 77
      local pressed = self:beginPress(left, 156, 72, 54)
      self:homeTile(left, 156, 72, 54, card[3], false)
      self:partyType(translate(card[1]), left + 5, 164, colors.ink, 62)
      self:partyInfo(self:fitPartyInfo(card[2], 58),
        left + 7, 183, quiet, 58, "center")
      self:detailChevron(left + 62, 201, colors.green)
      self:endPress(pressed)
    end
  end

  local function dexResearchHero(self, model, accent, summary, facts)
    local colors = self.colors
    local mon = model.pokemon or {}
    self:homeTile(7, 34, 226, 37, accent, false)
    if model.drawPokemon then model.drawPokemon(mon, 13, 37, 31, false) end
    self:partyInfo(self:fitPartyInfo(mon.name or translate("POKEMON"), 108),
      50, 39, colors.ink)
    self:typeBadges(mon, 50, 55, false)
    self:partyInfo(self:fitPartyInfo(summary or "", 69),
      157, 39, colors.ink, 69, "center")
    self:partyType(self:fitPartyType(facts or "", 69),
      157, 56, colors.green, 69)
  end

  function H:pokedexStats(model)
    local colors = self.colors
    dexResearchHero(self, model, colors.blue,
      model.summary or translate("BASE STATS"), "")
    self:partyType(model.catchText or translate("CATCH --"), 105, 56,
      colors.green, 59)
    self:partyType(model.expText or translate("XP --"), 167, 56,
      colors.green, 59)
    local rows = model.stats or {}
    local gap = #rows > 5 and 1 or 3
    local height = #rows > 5 and 20 or 22
    for index, row in ipairs(rows) do
      local top = 76 + (index - 1) * (height + gap)
      self:panel(7, top, 226, height, false, nil, colors.blueLight)
      self:partyType(translate(row.label or "STAT"), 13, top + 6, colors.green, 54)
      border(72, top + 7, 119, 6, colors.outline)
      box("fill", 73, top + 8, 117, 4, colors.silverDark)
      box("fill", 73, top + 8,
        math.floor(117 * math.min(255, tonumber(row.value) or 0) / 255 + 0.5),
        4, colors.blueLight)
      self:partyInfo(tostring(row.value or 0), 196, top + 5,
        colors.ink, 27, "center")
    end
  end

  function H:pokedexMoves(model)
    local colors = self.colors
    dexResearchHero(self, model, colors.amber,
      translate("LEARNSET"), translate("LEVEL + TM/HM"))
    for index, row in ipairs(model.rows or {}) do
      local top = 76 + (index - 1) * 28
      self:panel(7, top, 226, 25, false, nil,
        self:typeColor(row.type or row.types and row.types[1]))
      self:partyType(row.method or "--", 13, top + 8, colors.green, 36)
      self:partyInfo(self:fitPartyInfo(row.name or translate("MOVE"), 101),
        53, top + 7, colors.ink, 101)
      self:typeBadges(row, 178, top + 7, false)
    end
    dexPager(self, model.page or 1, model.pages or 1)
  end

  function H:pokedexHabitat(model)
    local colors = self.colors
    local quiet = self.dark and colors.silver or colors.silverDark
    local mon = model.pokemon or {}
    dexResearchHero(self, model, colors.green,
      translate(model.status or ""), model.summary or translate("NO WILD HABITAT"))

    for index, row in ipairs(model.rows or {}) do
      local top = 76 + (index - 1) * 39
      self:panel(7, top, 226, 35, row.current, colors.greenLight,
        colors.greenLight)
      self:partyInfo(self:fitPartyInfo(row.area or translate("UNKNOWN AREA"), 136),
        14, top + 4, colors.ink)
      if row.current then
        self:partyType(translate("HERE NOW"), 158, top + 4,
          colors.green, 66)
      end
      local condition = table.concat({ translate(row.time or "ANY TIME"),
        translate(row.method or "WILD"), tostring(row.chance or "--") .. "%" },
        " · ")
      self:partyType(self:fitPartyType(condition, 150),
        14, top + 20, colors.green, 150)
      self:partyInfo(row.levels or "L--", 171, top + 17,
        colors.ink, 48, "center")
    end
    if #(model.rows or {}) == 0 then
      self:partyInfo(translate("NO WILD ENCOUNTERS"),
        14, 124, quiet, 212, "center")
    end
    dexPager(self, model.page or 1, model.pages or 1)
  end

  function H:pokedex(model)
    if model.view == "profile" then return self:pokedexProfile(model) end
    if model.view == "stats" then return self:pokedexStats(model) end
    if model.view == "moves" then return self:pokedexMoves(model) end
    if model.view == "habitat" then return self:pokedexHabitat(model) end
    return self:pokedexIndex(model)
  end

  function H:pokedexHit(x, y, model)
    if y < 29 and x >= 33 and x < 50 then return "prev" end
    if y < 29 and x >= 116 and x < 139 then return "next" end
    if model.view == "profile" then
      if x >= 7 and x < 233 and y >= 156 and y < 210 then
        local index = math.floor((x - 7) / 77) + 1
        return ({ "stats", "habitat", "moves" })[index]
      end
    else
      if model.view == "index" then
        for index = 1, #(model.entries or {}) do
          local column, row = (index - 1) % 3, math.floor((index - 1) / 3)
          if x >= 7 + column * 77 and x < 79 + column * 77
              and y >= 68 + row * 43 and y < 109 + row * 43 then
            return "species", index
          end
        end
      end
    end
    if y >= 197 and y < 214 then
      if x >= 82 and x < 119 then return "prev" end
      if x >= 121 and x < 159 then return "next" end
    end
  end

  function H:homePartyIcon(x, y)
    local c = homeIconColors
    local function ball(left, top)
      clipped(left, top, 11, 11, c.ink)
      clipped(left + 1, top + 1, 9, 9, c.white)
      box("fill", left + 2, top + 2, 7, 4, c.red)
      box("fill", left + 1, top + 5, 9, 2, c.ink)
      box("fill", left + 4, top + 4, 3, 4, c.ink)
      box("fill", left + 5, top + 5, 1, 2, c.white)
    end
    ball(x + 9, y + 3)
    ball(x + 2, y + 12)
    ball(x + 16, y + 12)
  end

  function H:homeToolsIcon(x, y)
    local G, c = ui.graphics, homeIconColors
    local function cog(tint, ox, oy)
      color(tint)
      G.circle("fill", x + 13 + ox, y + 13 + oy, 8)
      for _, tooth in ipairs({
          { 11, 1, 5, 4 }, { 11, 22, 5, 4 },
          { 1, 11, 4, 5 }, { 22, 11, 4, 5 },
          { 4, 4, 4, 4 }, { 18, 4, 4, 4 },
          { 4, 18, 4, 4 }, { 18, 18, 4, 4 },
        }) do
        box("fill", x + tooth[1] + ox, y + tooth[2] + oy,
          tooth[3], tooth[4], tint)
      end
    end
    cog(c.ink, 1, 1)
    cog(c.silver, 0, 0)
    box("fill", x + 7, y + 5, 7, 2, c.silverLight)
    box("fill", x + 5, y + 8, 3, 5, c.silverLight)
    box("fill", x + 18, y + 17, 3, 3, c.deep)
    color(c.ink)
    G.circle("fill", x + 13, y + 13, 4)
    color(c.blue)
    G.circle("fill", x + 13, y + 13, 2.5)
    box("fill", x + 12, y + 11, 2, 2, c.blueLight)
  end

  function H:homeExplorerIcon(x, y)
    local G, c = ui.graphics, homeIconColors
    color(c.ink); G.circle("fill", x + 13, y + 13, 12)
    color(c.greenDark); G.circle("fill", x + 13, y + 13, 10)
    color(c.green); G.circle("line", x + 13, y + 13, 7)
    box("fill", x + 3, y + 13, 20, 1, c.green)
    box("fill", x + 13, y + 3, 1, 20, c.green)
    color(c.greenLight)
    G.polygon("fill", x + 13, y + 13, x + 13, y + 4,
      x + 21, y + 9)
    color(c.paper); G.circle("fill", x + 13, y + 13, 2)
    color(c.amberLight); G.circle("fill", x + 19, y + 17, 2)
    color(c.red); G.circle("fill", x + 8, y + 9, 2)
  end

  function H:homeMapIcon(x, y)
    local G, c = ui.graphics, homeIconColors
    color(c.ink)
    G.polygon("fill", x + 2, y + 5, x + 9, y + 2,
      x + 17, y + 5, x + 24, y + 2, x + 24, y + 22,
      x + 17, y + 25, x + 9, y + 22, x + 2, y + 25)
    color(c.greenLight)
    G.polygon("fill", x + 3, y + 6, x + 8, y + 4,
      x + 8, y + 21, x + 3, y + 23)
    color(c.paper)
    G.polygon("fill", x + 10, y + 4, x + 16, y + 6,
      x + 16, y + 23, x + 10, y + 21)
    color(c.blueLight)
    G.polygon("fill", x + 18, y + 6, x + 23, y + 4,
      x + 23, y + 21, x + 18, y + 23)
    box("fill", x + 4, y + 16, 5, 2, c.blueDark)
    box("fill", x + 8, y + 14, 5, 2, c.blueDark)
    box("fill", x + 12, y + 12, 5, 2, c.blueDark)
    box("fill", x + 16, y + 10, 5, 2, c.blueDark)
    color(c.ink); G.circle("fill", x + 17, y + 9, 5)
    color(c.red); G.circle("fill", x + 17, y + 9, 3)
    box("fill", x + 15, y + 12, 4, 4, c.ink)
    box("fill", x + 16, y + 12, 2, 3, c.red)
    color(c.white); G.circle("fill", x + 17, y + 9, 1)
  end

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

  function H:homeStoreIcon(x, y)
    local c = homeIconColors
    clipped(x + 1, y + 5, 25, 20, c.ink)
    clipped(x + 2, y + 6, 23, 18, c.greenDark)
    box("fill", x + 3, y + 11, 21, 11, c.green)
    box("fill", x + 4, y + 12, 19, 2, c.greenLight)
    box("fill", x + 3, y + 6, 21, 4, c.paper)
    box("fill", x + 4, y + 6, 4, 5, c.red)
    box("fill", x + 12, y + 6, 4, 5, c.red)
    box("fill", x + 20, y + 6, 3, 5, c.red)
    box("fill", x + 8, y + 15, 7, 7, c.blueDark)
    box("fill", x + 9, y + 16, 5, 5, c.blueLight)
    box("fill", x + 17, y + 15, 4, 7, c.paper)
    box("fill", x + 18, y + 16, 2, 5, c.amberLight)
    box("fill", x + 5, y + 23, 17, 1, c.greenLight)
  end

  function H:homeNotesIcon(x, y)
    local c = homeIconColors
    clipped(x + 3, y + 1, 21, 26, c.ink)
    clipped(x + 4, y + 2, 19, 24, c.blueDark)
    clipped(x + 7, y + 3, 15, 21, c.paper)
    box("fill", x + 8, y + 4, 13, 2, c.white)
    for ringY = 5, 20, 5 do
      box("fill", x + 2, y + ringY, 6, 2, c.ink)
      box("fill", x + 3, y + ringY, 4, 1, c.amberLight)
    end
    box("fill", x + 9, y + 9, 10, 2, c.blue)
    box("fill", x + 9, y + 14, 10, 1, c.silver)
    box("fill", x + 9, y + 18, 7, 1, c.silver)
    box("fill", x + 17, y + 17, 2, 7, c.amberDark)
    box("fill", x + 18, y + 16, 2, 7, c.amber)
    box("fill", x + 19, y + 16, 1, 2, c.amberLight)
    box("fill", x + 17, y + 24, 2, 1, c.ink)
  end

  function H:homeSettingsIcon(x, y)
    local G, c = ui.graphics, homeIconColors
    local knobs = { 5, 13, 8 }
    for index, knob in ipairs(knobs) do
      local top = 3 + (index - 1) * 9
      box("fill", x + 2, y + top + 1, 24, 3, c.ink)
      box("fill", x + 3, y + top + 2, 22, 1, c.silverLight)
      color(c.ink); G.circle("fill", x + knob, y + top + 2, 5)
      color(index == 2 and c.blue or c.green)
      G.circle("fill", x + knob, y + top + 2, 3)
      box("fill", x + knob - 1, y + top, 2, 2,
        index == 2 and c.blueLight or c.greenLight)
    end
  end

  local function homeIcons(theme)
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

  function H:homeAppButton(x, y, w, h, accent, label, icon, selected)
    local G, colors = ui.graphics, self.colors
    if self:shadowVisible() then
      color(colors.shadow)
      G.rectangle("fill", x + 1, y + 3, w, h, 5, 5)
    end
    local base = mixed(colors.surface, accent, self.dark and 0.22 or 0.13)
    color(self:focusSurface(selected, base,
      mixed(accent, colors.white, 0.38)))
    G.rectangle("fill", x, y, w, h, 5, 5)
    color(colors.outline)
    G.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 5, 5)
    box("fill", x + 5, y + 2, w - 10, 2,
      mixed(colors.highlight, accent, 0.22))
    local captionY = y + h - 30
    box("fill", x + 1, captionY, w - 2, 28, accent)
    box("fill", x + 3, captionY + 1, w - 6, 1,
      mixed(accent, colors.white, 0.42))
    box("fill", x + 5, y + h - 5, w - 10, 3,
      mixed(accent, colors.outline, 0.45))
    local wellX = x + math.floor((w - 29) / 2)
    color(mixed(colors.surface, colors.white, self.dark and 0.08 or 0.22))
    G.rectangle("fill", wellX, y + 8, 29, 29, 5, 5)
    color(colors.outline)
    G.rectangle("line", wellX + 0.5, y + 8.5, 28, 28, 5, 5)
    drawHomeIcon(icon, wellX, y + 8, 29)
    local shown = self:fitPartyType(translate(label), w - 6)
    self:partyType(shown, x + 3, captionY + 5, colors.white, w - 6)
    if selected then self:roundedFocusFrame(x, y, w, h, 5) end
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

  function H:homeEmpty()
    local G, colors = ui.graphics, self.colors
    local x, y, w, h = self:homeEmptyRect()
    local pressed = self:beginPress(x, y, w, h)
    if self:shadowVisible() then
      color(colors.shadow); G.rectangle("fill", x + 1, y + 3, w, h, 5, 5)
    end
    color(mixed(colors.surface, colors.greenLight,
      self.dark and 0.10 or 0.05))
    G.rectangle("fill", x, y, w, h, 5, 5)
    color(colors.outline)
    G.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 5, 5)
    box("fill", x + 6, y + 3, w - 12, 2,
      mixed(colors.greenLight, colors.white, 0.24))

    local wellX, wellY, wellSize = x + 14, y + 21, 40
    clipped(wellX, wellY, wellSize, wellSize,
      mixed(colors.surface, colors.greenLight, self.dark and 0.18 or 0.12))
    border(wellX, wellY, wellSize, wellSize, colors.outline)
    local cx, cy = wellX + math.floor(wellSize / 2),
      wellY + math.floor(wellSize / 2)
    color(colors.greenLight); G.setLineWidth(2)
    G.line(cx - 7, cy, cx + 7, cy)
    G.line(cx, cy - 7, cx, cy + 7)
    G.setLineWidth(1)

    local textX, textW = x + 64, 96
    self:partyType(self:fitPartyType(translate("ADD TO HOME"), textW),
      textX, y + 25, colors.ink, textW)
    self:partyType(self:fitPartyType(
      translate("APPS") .. " + " .. translate("WIDGETS"), textW),
      textX, y + 42, colors.green, textW)
    self:detailChevron(x + w - 13, y + 39, colors.green)
    self:endPress(pressed)
  end

  function H:homePlus(tile)
    local G, colors = ui.graphics, self.colors
    local x, y, w, h = self:homeRect(tile)
    local pressed = self:beginPress(x, y, w, h)
    color(mixed(colors.surface, colors.greenLight, self.dark and 0.08 or 0.04))
    G.rectangle("fill", x, y, w, h, 5, 5)
    color(mixed(colors.green, colors.surface, 0.30))
    for px = x + 5, x + w - 7, 7 do
      G.line(px, y + 1, math.min(px + 3, x + w - 5), y + 1)
      G.line(px, y + h - 2, math.min(px + 3, x + w - 5), y + h - 2)
    end
    for py = y + 6, y + h - 8, 7 do
      G.line(x + 1, py, x + 1, math.min(py + 3, y + h - 6))
      G.line(x + w - 2, py, x + w - 2, math.min(py + 3, y + h - 6))
    end
    local cx, cy = x + math.floor(w / 2), y + math.floor(h / 2)
    color(colors.greenLight)
    G.setLineWidth(2)
    G.line(cx - 5, cy, cx + 5, cy)
    G.line(cx, cy - 5, cx, cy + 5)
    G.setLineWidth(1)
    self:endPress(pressed)
  end

  function H:homeEditOverlay(tile, dragging)
    local G, colors = ui.graphics, self.colors
    local x, y, w, h = self:homeRect(tile)
    color(colors.outline); G.circle("fill", x + 6, y + 6, 6)
    color(colors.red); G.circle("fill", x + 6, y + 6, 5)
    box("fill", x + 3, y + 5, 7, 2, colors.white)
    for row = 0, 2 do
      box("fill", x + w - 11, y + 4 + row * 3, 2, 2, colors.outline)
      box("fill", x + w - 7, y + 4 + row * 3, 2, 2, colors.outline)
    end
    if dragging then self:roundedFocusFrame(x, y, w, h, 5) end
  end

  function H:homeEditDone()
    local colors = self.colors
    local pressed = self:beginPress(158, 6, 57, 15)
    box("fill", 139, 4, 95, 19, colors.surface)
    box("fill", 140, 5, 93, 2, colors.highlight)
    clipped(158, 6, 57, 15, colors.green)
    border(158, 6, 57, 15, colors.outline)
    self:partyType(translate("DONE"), 161, 8, colors.white, 51)
    self:endPress(pressed)
  end

  function H:homeAddHeader(title)
    local colors = self.colors
    box("fill", 26, 4, 208, 19, colors.surface)
    box("fill", 27, 5, 206, 2, colors.highlight)
    local shown = self:fitLabel(translate(title), 190)
    self:label(shown, 130 - math.floor(self:labelWidth(shown) / 2),
      6, colors.ink)
  end

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

  function H:homeLibraryCard(x, y, w, item, icons)
    local G, colors = ui.graphics, self.colors
    local pressed = self:beginPress(x, y, w, 46, item.available)
    if self:shadowVisible() then
      color(colors.shadow); G.rectangle("fill", x + 1, y + 2, w, 46, 4, 4)
    end
    local base = item.available and colors.surface
      or mixed(colors.surface, colors.silverDark, self.dark and 0.36 or 0.22)
    color(base); G.rectangle("fill", x, y, w, 46, 4, 4)
    color(colors.outline)
    G.rectangle("line", x + 0.5, y + 0.5, w - 1, 45, 4, 4)
    local icon = icons[item.icon or item.id]
    if item.kind == "app" and icon then drawHomeIcon(icon, x + 4, y + 5, 29)
    else self:homeWidgetLibraryIcon(item.widget, x + 4, y + 5, item) end
    local label = self:fitPartyType(item.widget == "tool" and item.label
      or translate(item.label), w - 39)
    self:partyType(label, x + 36, y + 6, colors.ink, w - 39)
    local kind = item.kind == "app" and translate("APP")
      or translate("WIDGET") .. " " .. item.columns .. "x" .. item.rows
    self:partyType(kind, x + 36, y + 18, colors.green, w - 39)
    local status = item.available and translate("ADD")
      or translate(item.reason == "on_home" and "ON HOME" or "NO SPACE")
    local tint = item.available and colors.greenLight or colors.silverDark
    box("fill", x + 36, y + 31, w - 40, 11, tint)
    self:partyType(status, x + 37, y + 31,
      item.available and colors.outline or colors.surface, w - 42)
    self:endPress(pressed)
  end

  function H:homeCatalog(model)
    local colors, icons = self.colors, homeIcons(self)
    clipped(7, 32, 226, 167, colors.shadow)
    clipped(6, 31, 226, 167, colors.surface)
    border(6, 31, 226, 167, colors.outline)
    for index, tab in ipairs({ "app", "widget" }) do
      local x = index == 1 and 10 or 121
      local active = model.libraryKind == tab
      local pressed = self:beginPress(x, 34, 108, 13)
      clipped(x, 34, 108, 13, active and colors.green or colors.band)
      border(x, 34, 108, 13, colors.outline)
      self:partyType(translate(tab == "app" and "APPS" or "WIDGETS"),
        x + 2, 35, active and colors.white or colors.ink, 104)
      self:endPress(pressed)
    end
    local page = math.max(1, tonumber(model.libraryPage) or 1)
    local first = (page - 1) * 6 + 1
    for index = first, math.min(first + 5, #(model.library or {})) do
      local item = model.library[index]
      local visible = index - first
      local column, row = visible % 2, math.floor(visible / 2)
      self:homeLibraryCard(10 + column * 111, 49 + row * 48, 108,
        item, icons)
    end
    self:homePager(page, model.libraryPages)
  end

  function H:homeExplorer(model, tile, selected)
    local colors = self.colors
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, colors.greenLight, selected)
    local explorerAccent = mixed(colors.party, colors.greenLight, 0.45)
    self:homeWidgetHeader(x, y, w, "EXPLORER", explorerAccent,
      mixed(explorerAccent, colors.white, 0.30), model.editing)
    self:mapOverview(model.overview, x + 5, y + 22, w - 10, h - 27, {
      image = model.image, player = model.player, markers = model.markers,
      drawPlayer = model.drawPlayer, drawTrainer = model.drawTrainer,
    })
    local route = self:fitPartyType(model.route or translate("UNKNOWN AREA"), 76)
    local routeWidth = math.max(48, partyTypeFont:getWidth(route) + 10)
    clipped(x + 7, y + h - 20, routeWidth, 12, colors.surface)
    border(x + 7, y + h - 20, routeWidth, 12, colors.outline)
    self:partyType(route, x + 7, y + h - 20, colors.ink, routeWidth)
  end

  function H:homeParty(model, tile, selected)
    local colors = self.colors
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, colors.partyLight, selected)
    self:homeWidgetHeader(x, y, w, "PARTY", colors.party,
      colors.partyLight, model.editing)
    local portraitX = x + math.floor((w - 34) / 2)
    self:partyPortrait(portraitX, y + 17, false, false)
    if model.drawPokemon and model.lead then
      model.drawPokemon(model.lead, portraitX + 1, y + 20, 32, false)
    end
    local leadName = self:fitPartyType(model.lead and model.lead.name or "---",
      w - 10)
    self:partyType(leadName, x + 5, y + 56, colors.ink, w - 10)
    self:partyType(model.lead and model.lead.levelText or "--",
      x + 6, y + 65, colors.green, 26)
    if model.lead and model.lead.statusId then
      self:statusIcon(model.lead.statusId, x + 34, y + 66)
    end
    self:partyType(model.lead and model.lead.hpText or "--/--",
      x + w - 45, y + 65, colors.ink, 39)
    self:hpBar(x + 6, y + 74, w - 12, model.lead and model.lead.hp or 0,
      model.lead and model.lead.maxHp or 1)
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
        if mon.egg then
          self:partyType(translate("EGG"), left, top + 43, colors.green, width)
        else
          local label = displayText(mon.levelText or "--")
          local labelWidth = partyTypeFont:getWidth(label)
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
    local quiet = self.dark and colors.silver or colors.silverDark
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

  function H:homeTrainer(model, tile, selected)
    local colors = self.colors
    local trainer = model.trainer or {}
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, colors.blueLight, selected)
    self:homeWidgetHeader(x, y, w, "TRAINER", colors.blue,
      colors.blueLight, model.editing)
    ui.graphics.push()
    ui.graphics.translate(x + 6, y + 23)
    ui.graphics.scale(0.76, 0.76)
    self:homeTrainerIcon(0, 0)
    ui.graphics.pop()
    local infoX, infoW = x + 31, w - 37
    self:partyType(self:fitPartyType(trainer.name or "---", infoW),
      infoX, y + 23, colors.ink, infoW)
    local badgeText = (trainer.region or "KANTO") .. " "
      .. (trainer.badgeCount or 0) .. "/" .. (trainer.badgeTotal or 0)
    self:partyType(self:fitPartyType(badgeText, infoW),
      infoX, y + 34, colors.blue, infoW)
    local badgeLeft, badgeWidth = x + 6, w - 12
    for index = 1, math.max(1, trainer.badgeTotal or 8) do
      local cx = badgeLeft + math.floor((index - 0.5) * badgeWidth
        / math.max(1, trainer.badgeTotal or 8))
      color(trainer.badgeOwned and trainer.badgeOwned[index]
        and colors.amberLight or colors.silverDark)
      ui.graphics.circle("fill", cx, y + 52, 3)
      color(colors.outline); ui.graphics.circle("line", cx, y + 52, 3)
    end
    local half = math.floor((w - 13) / 2)
    clipped(x + 5, y + 61, half, 15,
      mixed(colors.surface, colors.amberLight, self.dark and 0.22 or 0.14))
    border(x + 5, y + 61, half, 15, colors.outline)
    self:partyInfo(self:fitPartyInfo(trainer.moneyShort or trainer.money
      or "¥0", half - 6), x + 8, y + 64, colors.ink, half - 6,
      "center")
    local right = x + w - 5 - half
    clipped(right, y + 61, half, 15,
      mixed(colors.surface, colors.blueLight, self.dark and 0.22 or 0.14))
    border(right, y + 61, half, 15, colors.outline)
    self:partyInfo(self:fitPartyInfo(trainer.time or "0:00", half - 6),
      right + 3, y + 64, colors.ink, half - 6, "center")
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
    local areaWidth = math.max(44, partyTypeFont:getWidth(area) + 8)
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
    local quiet = self.dark and colors.silver or colors.silverDark
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

  function H:homeTool(model, tile, selected)
    local colors = self.colors
    local quiet = self.dark and colors.silver or colors.silverDark
    local x, y, w, h = self:homeRect(tile)
    local accent = self:toolAccent(tile.icon)
    local ready = tile.ready == true
    self:homeTile(x, y, w, h, ready and accent or colors.silverDark, selected)
    box("fill", x + 2, y + 2, w - 4, 17,
      ready and accent or colors.silverDark)
    box("fill", x + 4, y + 2, w - 8, 2,
      ready and mixed(accent, colors.white, 0.36) or colors.silver)
    self:partyType(self:fitPartyType(tile.label, w - 6),
      x + 3, y + 4, ready and colors.outline or colors.white, w - 6)
    local iconLeft = x + math.floor((w - 28) / 2)
    clipped(iconLeft, y + 24, 28, 28,
      mixed(colors.surface, colors.white, self.dark and 0.07 or 0.24))
    border(iconLeft, y + 24, 28, 28, colors.outline)
    self:toolIcon(tile.icon, iconLeft, y + 24,
      ready and accent or colors.silver)
    local status = translate(ready and "READY" or "NOT HERE")
    self:partyType(self:fitPartyType(status, w - 8), x + 4, y + 62,
      ready and self.colors.green or quiet, w - 8)
  end

  function H:homePager(page, pages)
    pages = math.max(1, tonumber(pages) or 1)
    if pages < 2 then return end
    page = math.max(1, math.min(pages, tonumber(page) or 1))
    local G, colors = ui.graphics, self.colors
    if pages > 7 then
      local label = page .. "/" .. pages
      local width = math.max(24, partyTypeFont:getWidth(label) + 8)
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

  function H:homeHelp(tiles)
    local colors = self.colors
    local target, top = self:homeHelpLayout(tiles)
    local dim = { 0, 0, 0, 0.55 }
    if target then
      local x, y, w, h = self:homeRect(target)
      box("fill", 0, 0, 240, y, dim)
      box("fill", 0, y + h, 240, 216 - y - h, dim)
      box("fill", 0, y, x, h, dim)
      box("fill", x + w, y, 240 - x - w, h, dim)
      border(x - 1, y - 1, w + 2, h + 2, colors.greenLight)
    else
      box("fill", 0, 0, 240, 216, dim)
    end
    self:homeTile(7, top, 226, 84, colors.greenLight, false)
    self:partyInfo(translate("YOUR SILPH LINK."), 17, top + 4,
      colors.ink, 206, "center")
    self:partyInfo(translate("YOUR HOME SCREEN."), 17, top + 15,
      self.dark and colors.greenLight or colors.green, 206, "center")
    for line, value in ipairs({ translate("HOLD AN APP OR WIDGET"),
        translate("TO CUSTOMIZE YOUR"), translate("HOME SCREEN.") }) do
      self:partyType(value, 17, top + 20 + line * 9, colors.ink, 206)
    end
    local pressed = self:beginPress(70, top + 62, 100, 17)
    if self:shadowVisible() then
      clipped(71, top + 64, 100, 17, colors.shadow)
    end
    clipped(70, top + 62, 100, 17, colors.green)
    border(70, top + 62, 100, 17, colors.outline)
    self:partyType(translate("GOT IT"), 70, top + 65, colors.white, 100)
    self:endPress(pressed)
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
        tile.widget == "team" and not model.editing and 20 or h)
      if tile.kind == "widget" and tile.widget == "explorer" then
        self:homeExplorer(model, tile, selected)
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
      elseif tile.kind == "widget" and tile.widget == "steps" then
        self:homeSteps(model, tile, selected)
      elseif tile.kind == "widget" and tile.widget == "tool" then
        self:homeTool(model, tile, selected)
      elseif tile.kind == "app" then
        self:homeAppButton(x, y, w, h,
          colors[tile.accent or "green"] or colors.green,
          tile.label or tile.id or "APP", icon[tile.icon or tile.id]
            or icon.tools, selected)
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

  function H:toolCard(action, x, y)
    local colors = self.colors
    local quiet = self.dark and colors.silver or colors.silverDark
    local accent = self:toolAccent(action.icon)
    local pressed = self:beginPress(x, y, 109, 76, action.ready)
    self:homeTile(x, y, 109, 76,
      action.ready and accent or colors.silverDark, false)
    local infoLeft, iconLeft, iconTop = x + 47, x + 9, y + 11
    clipped(iconLeft, iconTop, 34, 34,
      mixed(colors.surface, colors.white, self.dark and 0.06 or 0.24))
    border(iconLeft, iconTop, 34, 34, colors.outline)
    self:toolIcon(action.icon, iconLeft + 3, iconTop + 3,
      action.ready and accent or colors.silver)

    local label = tostring(action.label or "")
    if self:partyInfoWidth(label) <= 53 then
      self:partyInfo(label, infoLeft, y + 10, colors.ink, 53, "center")
    else
      local first, second = splitFont(label, 53, partyTypeFont)
      if first then
        self:partyType(first, infoLeft, y + 7, colors.ink, 53)
        self:partyType(second, infoLeft, y + 17, colors.ink, 53)
      else
        self:partyType(self:fitPartyType(label, 53),
          infoLeft, y + 12, colors.ink, 53)
      end
    end
    local status = translate(action.ready and "READY" or "NOT HERE")
    local statusTint = action.ready and colors.greenLight or colors.silverDark
    clipped(infoLeft, y + 29, 53, 13, statusTint)
    border(infoLeft, y + 29, 53, 13, colors.outline)
    self:partyType(self:fitPartyType(status, 49), infoLeft + 2, y + 31,
      action.ready and colors.statusInk or colors.white, 49)
    self:partyType(self:fitPartyType(translate(action.ready
        and "TAP TO USE" or "CONTEXT REQUIRED"), 93),
      x + 8, y + 57, action.ready and colors.green or quiet, 93)
    self:endPress(pressed)
  end

  function H:toolCardRect(visible, count)
    if count == 1 then return 66, 74 end
    if count == 2 then return 7 + visible * 117, 74 end
    if count == 3 and visible == 2 then return 66, 115 end
    return 7 + visible % 2 * 117, 33 + math.floor(visible / 2) * 82
  end

  function H:tools(model)
    local colors = self.colors
    model = model or {}
    local actions = model.actions or {}
    if #actions == 0 then
      self:homeTile(25, 55, 190, 103, colors.greenLight, false)
      clipped(103, 69, 34, 34,
        mixed(colors.surface, colors.white, self.dark and 0.06 or 0.24))
      border(103, 69, 34, 34, colors.outline)
      self:homeToolsIcon(107, 73)
      self:partyInfo(translate("NO TOOLS UNLOCKED"), 34, 113,
        colors.ink, 172, "center")
      self:partyType(translate("KEEP EXPLORING"), 34, 134,
        colors.green, 172)
      return
    end
    local page = math.max(1, tonumber(model.page) or 1)
    local first = (page - 1) * 4 + 1
    local count = math.min(4, math.max(0, #actions - first + 1))
    for index = first, math.min(first + 3, #actions) do
      local visible = index - first
      local x, y = self:toolCardRect(visible, count)
      self:toolCard(actions[index], x, y)
    end
    self:homePager(page, model.pages)
  end

  function H:toolsHit(x, y, model)
    local page = math.max(1, tonumber(model and model.page) or 1)
    local actions = model and model.actions or {}
    if y < 29 and x >= 27 and x < 50 then return "prev" end
    if y < 29 and x >= 116 and x < 139 then return "next" end
    local first = (page - 1) * 4 + 1
    local count = math.min(4, math.max(0, #actions - first + 1))
    for visible = 0, count - 1 do
      local index = (page - 1) * 4 + visible + 1
      local action = actions[index]
      local left, top = self:toolCardRect(visible, count)
      if action and action.ready and x >= left and x < left + 109
          and y >= top and y < top + 76 then return "action", index end
    end
  end

  function H:settings(model)
    local colors = self.colors
    model = model or {}
    if not model.category then
      for index, category in ipairs(model.categories or {}) do
        local y = 34 + (index - 1) * 30
        local pressed = self:beginPress(7, y, 226, 26)
        self:homeTile(7, y, 226, 26,
          colors[category.accent .. "Light"] or colors.greenLight, false)
        box("fill", 11, y + 5, 4, 16,
          colors[category.accent] or colors.green)
        self:partyInfo(translate(category.label), 22, y + 4,
          colors.ink, 180)
        self:partyType(translate(category.detail), 22, y + 13,
          colors.green, 180)
        self:detailChevron(221, y + 10, colors.ink, true)
        self:endPress(pressed)
      end
      return
    end

    local first = (model.page - 1) * 4 + 1
    for visible = 0, 3 do
      local row = model.rows[first + visible]
      if row then
        local y = 36 + visible * 40
        local pressed = self:beginPress(7, y, 226, 35, row.enabled ~= false)
        self:homeTile(7, y, 226, 35,
          colors[model.accent .. "Light"] or colors.greenLight, false)
        self:partyInfo(translate(row.label), 15, y + 5, colors.ink, 135)
        if row.action then
          local value = translate(row.value)
          local firstLine, secondLine
          if partyTypeFont:getWidth(value) > 63 then
            firstLine, secondLine = splitFont(value, 63, partyTypeFont)
          end
          if secondLine then
            self:partyType(firstLine, 151, y + 8, colors.green, 63)
            self:partyType(secondLine, 151, y + 18, colors.green, 63)
          else
            self:partyType(self:fitPartyType(value, 63),
              151, y + 13, colors.green, 63)
          end
          self:detailChevron(222, y + 13, colors.ink, true)
        else
          local value = translate(row.value)
          local firstLine, secondLine
          if partyTypeFont:getWidth(value) > 84 then
            firstLine, secondLine = splitFont(value, 84, partyTypeFont)
          end
          self:pageChevron(130, y + 24, false, false)
          if secondLine then
            self:partyType(firstLine, 135, y + 13, colors.green, 84)
            self:partyType(secondLine, 135, y + 21, colors.green, 84)
          else
            self:partyType(self:fitPartyType(value, 84),
              135, y + 18, colors.green, 84)
          end
          self:pageChevron(224, y + 24, true, false)
        end
        self:endPress(pressed)
      end
    end
    self:homePager(model.page, model.pages)
  end

  function H:settingsHit(x, y, model)
    if y < 29 and x < 27 then return "back" end
    if not model.category then
      local index = math.floor((y - 34) / 30) + 1
      local top = 34 + (index - 1) * 30
      if x >= 7 and x < 233 and index >= 1
          and index <= #(model.categories or {}) and y >= top and y < top + 26
          then return "category", index end
      return
    end
    if y < 29 and x >= 27 and x < 50 then return "prev" end
    if y < 29 and x >= 116 and x < 139 then return "next" end
    local visible = math.floor((y - 36) / 40)
    local index = (model.page - 1) * 4 + visible + 1
    local row = model.rows and model.rows[index]
    if x >= 7 and x < 233 and visible >= 0 and visible < 4 and row then
      if y < 36 + visible * 40 or y >= 71 + visible * 40 then return end
      if row.action then return "row", index, 1 end
      return "row", index, x < 120 and -1 or 1
    end
  end

  function H:toolPrompt(action)
    local G, colors = ui.graphics, self.colors
    color({ 0, 0, 0, self.dark and 0.62 or 0.48 })
    G.rectangle("fill", 0, 0, 240, 216)
    local accent = self:toolAccent(action.icon)
    self:homeTile(25, 52, 190, 112, accent, false)
    box("fill", 28, 55, 4, 106, accent)
    clipped(39, 70, 40, 40,
      mixed(colors.surface, colors.white, self.dark and 0.06 or 0.24))
    border(39, 70, 40, 40, colors.outline)
    self:toolIcon(action.icon, 45, 76, accent)
    self:partyInfo(self:fitPartyInfo(action.label, 116),
      86, 72, colors.ink, 116, "center")
    self:partyType(translate("USE NOW?"), 86, 94, colors.green, 116)
    for index, option in ipairs({ "YES", "NO" }) do
      local x = index == 1 and 39 or 126
      local pressed = self:beginPress(x, 124, 75, 27)
      clipped(x, 124, 75, 27, index == 1 and accent or colors.surface)
      border(x, 124, 75, 27, colors.outline)
      self:partyInfo(translate(option), x + 4, 130,
        index == 1 and colors.statusInk or colors.ink, 67, "center")
      self:endPress(pressed)
    end
  end

  function H:toolPromptHit(x, y)
    if x >= 39 and x < 114 and y >= 124 and y < 151 then return true end
    if x >= 126 and x < 201 and y >= 124 and y < 151 then return false end
  end

  function H:rodPicker(rods)
    local colors = self.colors
    for index, rod in ipairs(rods or {}) do
      local y = 38 + (index - 1) * 54
      local pressed = self:beginPress(16, y, 208, 44)
      self:homeTile(16, y, 208, 44, colors.blueLight, false)
      clipped(23, y + 7, 30, 30,
        mixed(colors.surface, colors.white, self.dark and 0.06 or 0.24))
      border(23, y + 7, 30, 30, colors.outline)
      self:toolIcon("fish", 25, y + 9, colors.blueLight)
      self:partyInfo(self:fitPartyInfo(rod.label, 132),
        65, y + 8, colors.ink, 132, "center")
      self:partyType(translate("TAP TO USE"), 65, y + 26,
        colors.green, 132)
      self:detailChevron(211, y + 18, colors.ink, true)
      self:endPress(pressed)
    end
  end

  function H:rodHit(x, y, rods)
    for index = 1, #(rods or {}) do
      local top = 38 + (index - 1) * 54
      if x >= 16 and x < 224 and y >= top and y < top + 44 then return index end
    end
  end

  function H:storeAction(x, y, w, label, state)
    local colors = self.colors
    local pressed = self:beginPress(x, y, w, 15, state ~= "soon")
    local tint = state == "soon" and colors.silverDark
      or state == "open" and colors.blue or colors.green
    clipped(x, y, w, 15, tint)
    border(x, y, w, 15, colors.outline)
    self:partyType(translate(label), x + 2, y + 2, colors.white, w - 4)
    self:endPress(pressed)
  end

  function H:storePreview(app, x, y, w, h)
    local G, colors = ui.graphics, self.colors
    local quiet = self.dark and colors.silver or colors.silverDark
    app = type(app) == "table" and app or { id = app }
    local id, preview = app.id, app.preview or {}
    local pressed = self:beginPress(x, y, w, h)
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
    if id == "explorer" then
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
        local label = translate(noteLabels[row + 1])
        local labelWidth = partyTypeFont:getWidth(label)
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
      box("fill", x + w - 14, top + 16, 3, height - 23, colors.amber)
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
      and "OPEN" or "VIEW")), x + 36, y + 31, colors.blueLight, w - 39)
    self:endPress(pressed)
  end

  function H:storeMiniAction(x, y, w, label, state, enabled)
    local colors = self.colors
    local pressed = self:beginPress(x, y, w, 11,
      enabled == true or state ~= "soon")
    local tint = state == "soon" and colors.silverDark
      or state == "open" and colors.blue or colors.green
    clipped(x, y, w, 11, tint)
    border(x, y, w, 11, colors.outline)
    self:partyType(translate(label), x + 1, y, colors.white, w - 2)
    self:endPress(pressed)
  end

  function H:storeNewBadge(x, y, w)
    local colors = self.colors
    clipped(x, y, w, 10, colors.red)
    border(x, y, w, 10, colors.outline)
    self:partyType(translate("NEW"), x + 1, y, colors.white, w - 2)
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
    local textW = partyTypeFont:getWidth(shown)
    local groupW = textW + gap + badgeW
    local left = x + math.floor((w - groupW) / 2)
    self:partyType(shown, left, y, colors.ink, textW)
    self:storeNewBadge(left + textW + gap, y - 1, badgeW)
  end

  function H:storeAppCard(x, y, w, app, icons)
    local G, colors = ui.graphics, self.colors
    local pressed = self:beginPress(x, y, w, 42)
    if self:shadowVisible() then
      color(colors.shadow); G.rectangle("fill", x + 1, y + 2, w, 42, 4, 4)
    end
    color(colors.surface); G.rectangle("fill", x, y, w, 42, 4, 4)
    color(colors.outline)
    G.rectangle("line", x + 0.5, y + 0.5, w - 1, 41, 4, 4)
    color(mixed(colors.surface, colors.white, self.dark and 0.08 or 0.22))
    G.rectangle("fill", x + 4, y + 6, 29, 29, 4, 4)
    border(x + 4, y + 6, 29, 29, colors.outline)
    local icon = icons[app.icon or app.id]
    if icon then drawHomeIcon(icon, x + 4, y + 6, 29) end
    self:storeTitle(app.label, x + 36, y + 4, w - 39, app.new)
    self:partyType(self:fitPartyType(translate(app.category), w - 39),
      x + 36, y + 16, colors.green, w - 39)
    self:storeMiniAction(x + 36, y + 28, 43,
      app.action or (app.state == "open" and "OPEN" or "GET"), app.state)
    self:detailChevron(x + w - 9, y + 30, colors.green)
    self:endPress(pressed)
  end

  function H:storeInstalledRow(x, y, w, app, icons)
    local G, colors = ui.graphics, self.colors
    local pressed = self:beginPress(x, y, w, 30)
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
      app.action or "OPEN",
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
      local pressed = self:beginPress(x, 195, 73, 18)
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
    local pressed = self:beginPress(7, 32, 226, 89)
    if self:shadowVisible() then
      color(colors.shadow); G.rectangle("fill", 8, 35, 226, 89, 5, 5)
    end
    color(colors.surface); G.rectangle("fill", 7, 32, 226, 89, 5, 5)
    color(colors.outline); G.rectangle("line", 7.5, 32.5, 225, 88, 5, 5)
    box("fill", 9, 34, 222, 15, colors.blue)
    local title = translate("APP OF THE DAY")
    if featured.new then
      local badgeW, gap = 25, 5
      local titleW = partyTypeFont:getWidth(title)
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

  function H:storeDetail(model)
    local G, colors, icons = ui.graphics, self.colors, homeIcons(self)
    local quiet = self.dark and colors.silver or colors.silverDark
    local app = model.app or {}
    color(colors.shadow); G.rectangle("fill", 8, 35, 226, 52, 5, 5)
    color(colors.surface); G.rectangle("fill", 7, 32, 226, 52, 5, 5)
    color(colors.outline); G.rectangle("line", 7.5, 32.5, 225, 51, 5, 5)
    color(mixed(colors.surface, colors.white, self.dark and 0.08 or 0.22))
    G.rectangle("fill", 13, 39, 39, 39, 5, 5)
    border(13, 39, 39, 39, colors.outline)
    drawHomeIcon(icons[app.icon or app.id] or icons.tools, 18, 44, 29)
    self:storeTitle(app.label or "APP", 55, 39, 104, app.new)
    self:partyType(self:fitPartyType(translate(app.category or "UTILITY"),
      104), 55, 53, colors.green, 104)
    self:partyType(self:fitPartyType(translate(app.publisher or "SILPH CO."),
      104), 55, 66, quiet, 104)
    self:storeAction(171, 41, 51, app.action or "GET", app.state)
    if app.removable then
      self:storeMiniAction(175, 61, 43, "REMOVE", "soon", true)
    end
    self:storePreview(app, 7, 90, 226, 73)
    clipped(7, 168, 226, 39, colors.surface)
    border(7, 168, 226, 39, colors.outline)
    local lines = app.description or {}
    for index = 1, math.min(3, #lines) do
      self:partyType(self:fitPartyType(translate(lines[index]), 214),
        13, 171 + (index - 1) * 11, colors.ink, 214)
    end
  end

  function H:storeHit(x, y, page)
    local function inside(left, top, width, height)
      return x >= left and x < left + width
        and y >= top and y < top + height
    end
    if page == "detail" then
      if inside(175, 61, 43, 11) then return "remove" end
      if inside(171, 41, 51, 15) then return "action" end
      if inside(7, 90, 226, 73) then return "preview" end
      return nil
    end
    if y < 29 and x >= 27 and x < 50 then return "prev" end
    if y < 29 and x >= 116 and x < 139 then return "next" end
    if (page == "apps" or page == "library") and y >= 32 and y < 53 then
      if x >= 149 and x < 183 then return "page_prev" end
      if x >= 207 and x < 233 then return "page_next" end
    end
    for index = 1, 3 do
      if inside(7 + (index - 1) * 76, 195, 73, 18) then
        return "tab", index
      end
    end
    if page == "apps" then
      for index = 1, 6 do
        local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
        local left, top = 7 + column * 115, 53 + row * 44
        if inside(left + 36, top + 28, 43, 11) then
          return "app_action", index
        end
        if inside(left, top, 111, 42) then
          return "app", index
        end
      end
      return nil
    end
    if page == "library" then
      for index = 1, 4 do
        local top = 57 + (index - 1) * 33
        if inside(179, top + 9, 44, 11) then
          return "installed_action", index
        end
        if inside(7, top, 226, 30) then
          return "installed", index
        end
      end
      return nil
    end
    if inside(57, 83, 56, 15) then return "featured_action" end
    if inside(7, 32, 226, 89) then return "featured" end
    if inside(7, 142, 111, 47) then return "recommendation", 1 end
    if inside(122, 142, 111, 47) then return "recommendation", 2 end
  end

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
    if not opts.full then
      return math.max(8, math.ceil(math.max(
        innerW / baseWidth, innerH / baseHeight)))
    end
    local fit = math.min(innerW / baseWidth, innerH / baseHeight)
    local zoom = math.max(1, math.min(3, tonumber(opts.zoom) or 1))
    return math.max(1, math.floor(fit)) * zoom
  end
  assert(mapTileSize(42, 18, 222, 87, {}) == 8
      and mapTileSize(10, 8, 222, 87, {}) == 23
      and mapTileSize(42, 18, 222, 147, { full = true }) == 5
      and mapTileSize(42, 18, 222, 147, { full = true, zoom = 3 }) == 15,
    "Explorer normal and fullscreen zoom scales stay independent")

  local function explorerMapFocus(model)
    local marker = model.selectedMarker
    return marker and marker.kind == "trainer" and marker or model.player
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

  function H:mapOverview(overview, x, y, w, h, opts)
    opts = opts or {}
    local G, colors = ui.graphics, self.colors
    self:panel(x, y, w, h, false)
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
    if opts.image then
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
        math.floor(top + marker.y * tileSize + 0.5)
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
        local mx, my = tile(marker)
        local anchorX = mx + math.floor(tileSize / 2)
        local anchorY = my + math.floor(tileSize / 2)
        if opts.selected == marker or opts.selected == index then
          tileFrame(mx, my, marker.kind == "trainer" and colors.blueLight
            or colors.amberLight)
        end
        if marker.kind == "trainer" then
          if opts.drawTrainer then
            opts.drawTrainer(marker, anchorX, my + tileSize, tileSize)
          end
        elseif marker.kind == "hidden" then
          local tint = marker.found and colors.silverDark or colors.blueLight
          local shine = marker.found and colors.silver or colors.white
          if tileSize < 9 then
            box("fill", anchorX, anchorY - 2, 1, 5, tint)
            box("fill", anchorX - 2, anchorY, 5, 1, tint)
            box("fill", anchorX, anchorY, 1, 1, shine)
          else
            local unit = math.floor(tileSize / 9)
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
      local px, py = tile(focus)
      local anchorX = px + math.floor(tileSize / 2)
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

  function H:regionMap(model)
    local G, colors = ui.graphics, self.colors
    self:panel(7, 32, 226, 178, false, nil, colors.blueLight)
    clipped(12, 37, 216, 142,
      mixed(colors.surface, colors.blueLight, self.dark and 0.18 or 0.12))
    border(12, 37, 216, 142, colors.outline)
    G.setScissor(14, 39, 212, 138)
    if model.drawMap then model.drawMap(14, 39, 212, 138) end
    G.setScissor()

    self:panel(12, 184, 216, 20, false, nil, colors.greenLight)
    self:partyType(self:fitPartyType(translate("AREA"), 66),
      17, 189, colors.green, 66)
    box("fill", 86, 188, 1, 12, colors.band)
    self:partyInfo(self:fitPartyInfo(model.area or translate("UNKNOWN AREA"),
      132), 91, 187, colors.ink, 132, "center")
  end

  function H:explorer(model)
    local colors, view, selected = self.colors, model.view, model.selected
    local mapFocus = explorerMapFocus(model)
    local function mapToggle(x, y, collapse)
      local pressed = self:beginPress(x, y, 19, 14)
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
      local minusPressed = self:beginPress(11, y, 18, 16)
      box("fill", 17, y + 7, 6, 2, colors.green)
      self:endPress(minusPressed)
      self:partyType(zoom .. "/3", 31, y + 2, colors.green, 31)
      local plusPressed = self:beginPress(64, y, 18, 16)
      box("fill", 70, y + 7, 6, 2, colors.green)
      box("fill", 72, y + 5, 2, 6, colors.green)
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
      local itemWidth = partyInfoFont:getWidth(model.itemsText)
      local itemLeft = 85 + math.floor((half - 9 - 3 - itemWidth) / 2)
      itemGlyph(itemLeft)
      self:partyInfo(model.itemsText, itemLeft + 12, y + 2, colors.ink)
      local trainerWidth = partyInfoFont:getWidth(model.trainersText)
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

    local mapX, mapW = 7, 226
    local mapY = model.mapFull and 72 or 53
    local mapH = model.mapFull and 138
      or view == "wild" and (selected and 42 or 84)
      or 84
    if model.mapFull then
      self:panel(7, 53, 226, 16, false, nil, colors.greenLight)
      zoomControls(53, model.mapZoom or 1)
      mapProgress(53)
    end
    self:mapOverview(model.overview, mapX, mapY, mapW, mapH, {
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
          local width = math.max(24, partyTypeFont:getWidth(label) + 8)
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
    if model.mapFull then return end

    local function chip(x, y, width, label, active, arrow)
      local pressed = self:beginPress(x, y, width, 16)
      self:panel(x, y, width, 16, false)
      if active then box("fill", x + 2, y + 2, width - 4, 12, colors.band) end
      label = translate(label)
      local arrowWidth, gap = arrow and 4 or 0, arrow and 3 or 0
      local shown = self:fitPartyType(label, width - 8 - arrowWidth - gap)
      local textWidth = partyTypeFont:getWidth(shown)
      local groupWidth = textWidth + gap + arrowWidth
      local left = x + math.floor((width - groupWidth) / 2)
      local tint = active and colors.ink or colors.green
      self:partyType(shown, left, y + 2, tint, textWidth)
      if arrow then self:detailChevron(left + textWidth + gap, y + 6, tint) end
      self:endPress(pressed)
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
      self:partyPortrait(16, 106, false, false)
      if model.drawPokemon then model.drawPokemon(selected, 16, 109, 34) end
      self:partyInfo(self:fitPartyInfo(selected.name, 100),
        58, 107, colors.ink)
      self:partyInfo(self:fitPartyInfo(translate(selected.caught and "CAUGHT"
        or "NOT CAUGHT"), 100), 58, 122, colors.green)
      self:typeBadges(selected, 58, 136, false)
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
        self:panel(12, 150, 216, 53, false, nil,
          appearance.current and colors.greenLight or wildAccent)
        if appearance.current then
          box("fill", 14, 152, 212, 49, colors.bandLight)
        end
        self:partyInfo(self:fitPartyInfo(appearance.section or model.route,
          appearance.current and 132 or 202), 19, 156, colors.ink)
        if appearance.current then
          self:partyType(translate("HERE NOW"), 154, 157,
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
          self:panel(12, y, 216, 24, false, nil,
            appearance.current and colors.greenLight or wildAccent)
          if appearance.current then
            box("fill", 14, y + 2, 212, 20, colors.bandLight)
          end
          self:partyInfo(self:fitPartyInfo(appearance.section or model.route,
            appearance.current and 105 or 140), 17, y + 3, colors.ink)
          if appearance.current then
            self:partyType(translate("HERE NOW"), 125, y + 3,
              colors.green, 68)
          end
          local detail = translate(appearance.time or "ANY TIME") .. " "
            .. "· " .. translate(tostring(appearance.method or "--")) .. " · "
            .. tostring(appearance.chance or "--") .. "%"
          self:partyType(self:fitPartyType(detail, 116), 17, y + 13,
            colors.green, 116)
          self:partyInfo(levels(appearance), 166, y + 10,
            colors.ink, 55, "center")
        end
      end
      return
    elseif selected and view == "items" then
      self:panel(7, 140, 226, 70, false, nil, colors.amberLight)
      self:battleItemIcon({ icon = selected.kind == "hidden" and "item"
        or selected.icon or "item" }, 15, 166, colors.amberLight)
      self:partyInfo(self:fitPartyInfo(selected.displayLabel or selected.label,
        75), 38, 157, colors.ink)
      self:partyType(self:fitPartyType(translate(selected.done and "FOUND"
        or "OPEN"), 72), 38, 181, colors.green, 72)
      box("fill", 120, 147, 1, 56, colors.band)
      self:partyType(self:fitPartyType(translate(selected.kind == "hidden"
        and "HIDDEN" or "VISIBLE"), 100), 126, 158, colors.green, 100)
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
        chip(168, 142, 58, tostring(model.total) .. " PKMN", false)
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
        self:endPress(pressed)
      end
      if #model.rows == 0 then
        self:partyInfo(translate(model.wildScope == "ROUTE"
          and "NO WILD ENCOUNTERS" or "NOTHING HERE NOW"), 7, 180,
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
    if x >= 202 and x < 232 and y >= 32 and y < 50 then
      return "map_toggle"
    end
    if model.mapFull and y >= 53 and y < 69 then
      if x >= 11 and x < 29 then return "zoom_out" end
      if x >= 64 and x < 82 then return "zoom_in" end
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

  function H:explorerRadar(model)
    local G, colors = ui.graphics, self.colors
    local pressed = self:beginPress(7, 32, 226, 178)
    self:panel(7, 32, 226, 178, false, nil, colors.blueLight)
    self:partyInfo(self:fitPartyInfo(model.route or translate("UNKNOWN AREA"),
      108), 13, 38, colors.ink)
    self:partyType(self:fitPartyType(translate(model.ready and "SCAN COMPLETE"
      or "SCANNING"), 90), 132, 40, colors.green, 90)
    self:panel(18, 58, 204, 116, false, nil, colors.blueLight)
    for x = 42, 198, 24 do box("fill", x, 61, 1, 110, colors.band) end
    for y = 82, 154, 24 do box("fill", 21, y, 198, 1, colors.band) end
    local cx, cy = 120, 116
    local radius = math.floor(70 * math.max(0, math.min(1,
      model.progress or 0)))
    G.setScissor(21, 61, 198, 110)
    color(colors.blueLight)
    if radius > 0 then G.circle("line", cx, cy, radius) end
    for _, signal in ipairs(model.signals or {}) do
      local sx = cx + math.max(-7, math.min(7, signal.dx or 0)) * 11
      local sy = cy + math.max(-4, math.min(4, signal.dy or 0)) * 11
      local distance = math.sqrt((sx - cx) ^ 2 + (sy - cy) ^ 2)
      if distance <= radius then
        box("fill", sx - 4, sy - 4, 9, 9, colors.outline)
        box("fill", sx - 2, sy - 2, 5, 5, colors.amberLight)
      end
    end
    G.setScissor()
    box("fill", cx - 5, cy - 5, 11, 11, colors.outline)
    box("fill", cx - 3, cy - 3, 7, 7, colors.greenLight)
    local count = #(model.signals or {})
    local status = not model.ready and translate("SEARCHING...")
      or count == 0 and translate("NO SIGNAL") or format("SIGNALS %d", count)
    self:partyInfo(self:fitPartyInfo(status, 200),
      20, 185, colors.ink, 200, "center")
    self:partyType(self:fitPartyType(translate("TAP TO SCAN AGAIN"), 200),
      20, 198, colors.green, 200)
    self:endPress(pressed)
  end

  function H:button(x, y, w, h, label, selected, pressScale, pressOffset)
    local pressed = self:beginPress(x, y, w, h, true, pressScale, pressOffset)
    self:panel(x, y, w, h, selected, self.colors.blueLight)
    local shown = fit(label, math.floor((w - 8) / 6))
    text(shown, x + math.floor((w - #glyphs(shown) * 6) / 2),
      y + math.floor((h - 7) / 2), self.colors.ink)
    self:endPress(pressed)
  end

  local function legacyRect(entry)
    return math.floor(entry.x * 1.5 + 0.5),
      math.floor(entry.y * 1.5 + 0.5),
      math.floor(entry.w * 1.5 + 0.5),
      math.floor(entry.h * 1.5 + 0.5)
  end

  function H:choiceScreen(model)
    local colors = self.colors
    if #(model.prompt or {}) > 0 then
      self:panel(20, 35, 200, 42, false, nil, colors.greenLight)
      local firstY = 43 + math.floor((24 - #model.prompt * 10) / 2)
      for index, line in ipairs(model.prompt) do
        self:partyInfo(self:fitPartyInfo(line, 184), 28,
          firstY + (index - 1) * 10, colors.ink, 184, "center")
      end
    end
    for _, entry in ipairs(model.entries or {}) do
      local x, y, w, h = legacyRect(entry)
      local pressed = self:beginPress(x, y, w, h)
      self:homeTile(x, y, w, h,
        entry.selected and colors.green or colors.blue, entry.selected)
      self:partyInfo(self:fitPartyInfo(entry.label, w - 16),
        x + 8, y + math.floor((h - 9) / 2), colors.ink,
        w - 16, "center")
      self:endPress(pressed)
    end
    if model.nudge then
      self:partyType(translate("PAUSE THEN CHOOSE"), 20, 201,
        colors.amber, 200)
    end
  end

  function H:naming(model)
    local colors = self.colors
    self:panel(28, 33, 184, 18, false, nil, colors.greenLight)
    local shown = fitFont(model.name or "-", 168, partyNameFont)
    self:partyName(shown,
      36 + math.floor((168 - partyNameFont:getWidth(shown)) / 2 + 0.5),
      38, colors.ink, 168)
    for _, entry in ipairs(model.entries or {}) do
      local x, y, w, h = legacyRect(entry)
      local pressed = self:beginPress(x, y, w, h)
      self:panel(x, y, w, h, entry.selected, colors.greenLight,
        entry.action and colors.amberLight or colors.blueLight)
      local label = tostring(entry.label or "")
      self:partyInfo(self:fitPartyInfo(label, w - 8), x + 4,
        y + math.floor((h - 9) / 2), colors.ink, w - 8, "center")
      self:endPress(pressed)
    end
  end

  function H:levelUp(model)
    local colors = self.colors
    self:panel(7, 33, 226, 44, false, nil,
      self:typeColor(model.type))
    self:partyPortrait(14, 37, false, false)
    if model.drawPokemon then model.drawPokemon(14, 39, 34) end
    self:partyName(model.name or translate("POKEMON"), 57, 42, colors.ink, 124)
    self:partyType(translate("NEW LEVEL"), 57, 58, colors.green, 72)
    self:partyInfo(model.level or "L--", 133, 55,
      colors.ink, 48, "right")

    local rows = model.rows or {}
    for index, row in ipairs(rows) do
      local line = math.floor((index - 1) / 3)
      local columns = math.min(3, #rows - line * 3)
      local width, gap = 68, 5
      local group = columns * width + (columns - 1) * gap
      local column = (index - 1) % 3
      local x = math.floor((240 - group) / 2) + column * (width + gap)
      local y = 83 + line * 40
      self:panel(x, y, width, 34, false, nil, colors.blueLight)
      self:partyType(self:fitPartyType(translate(row.label), width - 8),
        x + 4, y + 5, colors.green, width - 8)
      self:partyInfo(tostring(row.value or 0), x + 4, y + 19,
        colors.ink, width - 8, "center")
    end

    local pressed = self:beginPress(42, 170, 156, 34)
    self:homeTile(42, 170, 156, 34, colors.green, false)
    self:partyInfo(translate("CONTINUE"), 50, 181,
      colors.ink, 140, "center")
    self:endPress(pressed)
  end

  function H:levelUpHit(x, y)
    return x >= 42 and x < 198 and y >= 170 and y < 204
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
    G.setLineWidth(1)
  end

  function H:actionRow(x, y, w, h, label, kind, offset, selected)
    local G, colors = ui.graphics, self.colors
    local accent = (kind == "swap" or kind == "switch")
      and colors.amberLight or colors.blueLight
    y = y + (offset or 0)
    local pressed = self:beginPress(x, y, w, h)
    if self:shadowVisible() then
      clipped(x + 1, y + 2, w, h, colors.shadow)
    end
    clipped(x, y, w, h,
      self:focusSurface(selected, colors.surface, accent))
    border(x, y, w, h, colors.outline)
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

  function H:battleChoice(x, y)
    for index, action in ipairs(self.battleActions) do
      if x >= action.x and x < action.x + action.w
          and y >= action.y and y < action.y + action.h then return index end
    end
  end

  function H:fullBattleChoice(x, y)
    for index, action in ipairs(self.fullBattleActions) do
      if x >= action.x and x < action.x + action.w
          and y >= action.y and y < action.y + action.h then return index end
    end
  end

  assert(H:fullBattleChoice(62, 139) == 1
      and H:fullBattleChoice(178, 139) == 2
      and H:fullBattleChoice(62, 188) == 3
      and H:fullBattleChoice(178, 188) == 4
      and H:fullBattleChoice(120, 139) == nil,
    "HGSS Full Gear hitboxes follow the visible two-by-two action grid")

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
    local light = colors[colorName .. "Light"]
    local fill = self:focusSurface(selected, colors[colorName], light)
    if self:shadowVisible() then
      battleButtonShape(x + 2, y + 3, w, h, colors.outline)
    end
    battleButtonShape(x, y, w, h, colors.outline)
    battleButtonShape(x + 1, y + 1, w - 2, h - 2, fill)
    box("fill", x + 5, y + 2, w - 10, 2, light)
    box("fill", x + 3, y + 4, 2, 2, light)
    box("fill", x + w - 5, y + 4, 2, 2, light)
    if self:shadowVisible() then
      box("fill", x + 3, y + h - 7, w - 6, 3, colors.shadow)
      box("fill", x + 5, y + h - 4, w - 10, 2, colors.shadow)
    end
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

  function H:battleTeamStrip(playerTeam, enemyTeam, canGoBack)
    local colors = self.colors
    self:panel(5, 3, 230, 25, false)
    if canGoBack then self:chevron(15, 15, false) end
    for slot = 1, 6 do
      self:battleTeamBall(TEAM_LEFT + 4 + (slot - 1) * 11, 20,
        playerTeam and playerTeam[slot])
    end
    self:partyInfo(translate("YOU"), TEAM_LEFT, 3, colors.green, TEAM_WIDTH, "center")
    self:partyInfo(translate("VS"), VS_LEFT, 9, colors.ink, VS_WIDTH, "center")
    if enemyTeam and enemyTeam.wild then
      self:partyInfo(translate("WILD"), WILD_LEFT, 3, colors.green,
        WILD_WIDTH, "center")
      local detail = tostring(enemyTeam.name or translate("POKEMON"))
      if enemyTeam.level then detail = detail .. " L" .. enemyTeam.level end
      self:partyInfo(self:fitPartyInfo(detail, WILD_WIDTH),
        WILD_LEFT, 15, colors.ink, WILD_WIDTH, "center")
    else
      for slot = 1, 6 do
        self:battleTeamBall(FOE_LEFT + 4 + (slot - 1) * 11, 20,
          enemyTeam and enemyTeam[slot])
      end
      self:partyInfo(translate("FOE"), FOE_LEFT, 3, colors.green, TEAM_WIDTH, "center")
    end
  end

  local MESSAGE_X, MESSAGE_WIDTH = 10, 220
  assert(MESSAGE_X + MESSAGE_WIDTH / 2 == 120,
    "HGSS battle message shares the screen center")

  function H:battleContinueMotion(now)
    local phase = (1 - math.cos((tonumber(now) or 0) * math.pi)) / 2
    local bob = math.floor(phase + 0.5)
    return bob, bob == 0 and 5 or 9
  end

  function H:battleMessage(lines, canAdvance, playerTeam, enemyTeam, title, now)
    local colors = self.colors
    lines = lines or {}
    self:battleBackdrop()
    self:battleTeamStrip(playerTeam, enemyTeam)
    local pressed = self:beginPress(MESSAGE_X, 38, MESSAGE_WIDTH, 165,
      canAdvance)
    self:panel(MESSAGE_X, 38, MESSAGE_WIDTH, 165, false, nil,
      colors.greenLight)
    clipped(16, 45, 208, 150, colors.bandLight)
    border(16, 45, 208, 150, colors.band)
    local contentTop, contentHeight = 53, 105
    if title then
      local shown = self:fitPartyInfo(title, 190)
      self:partyInfo(shown, 25, 53, colors.green, 190, "center")
      box("fill", 25, 68, 190, 1, colors.band)
      contentTop, contentHeight = 76, 82
    end
    if #lines == 0 then lines = { "..." } end
    local lineHeight = 18
    local blockHeight = 11 + (#lines - 1) * lineHeight
    local y = contentTop + math.floor((contentHeight - blockHeight) / 2)
    for _, line in ipairs(lines) do
      local shown = self:fitLabel(line, 192)
      self:label(shown, 24, y, colors.ink, 192, "center")
      y = y + lineHeight
    end

    box("fill", 25, 166, 190, 1, colors.band)
    if canAdvance then
      local x = 115
      local bob, shadowWidth = self:battleContinueMotion(now)
      local y = 179 + bob
      local shadowX = x + 5 - math.floor(shadowWidth / 2)
      if self:shadowVisible() then
        box("fill", shadowX + 2, 190,
          math.max(1, shadowWidth - 4), 1, colors.shadow)
        box("fill", shadowX, 191, shadowWidth, 1, colors.shadow)
        box("fill", shadowX + 1, 192, shadowWidth - 2, 1, colors.shadow)
      end
      box("fill", x, y, 10, 2, colors.outline)
      box("fill", x + 1, y + 2, 8, 2, colors.outline)
      box("fill", x + 2, y + 4, 6, 2, colors.outline)
      box("fill", x + 3, y + 6, 4, 2, colors.outline)
      box("fill", x + 4, y + 8, 2, 1, colors.outline)
      box("fill", x + 1, y + 1, 8, 1, colors.greenLight)
      box("fill", x + 2, y + 2, 6, 2, colors.green)
      box("fill", x + 3, y + 4, 4, 2, colors.green)
      box("fill", x + 4, y + 6, 2, 2, colors.green)
    end
    self:endPress(pressed)
  end

  function H:battleFightAction(mon, drawPortrait, selected, offsetX, offsetY)
    local G, colors = ui.graphics, self.colors
    offsetX, offsetY = offsetX or 0, offsetY or 0
    local pressed = self:beginPress(22 + offsetX, 32 + offsetY, 196, 122)
    G.push()
    G.translate(offsetX, offsetY)
    self:battleActionPanel(22, 32, 196, 122, "red", selected)
    color(colors.selectedDark)
    G.circle("fill", 120, 83, 36)
    color(colors.surface)
    G.circle("fill", 120, 83, 33)
    box("fill", 87, 82, 66, 2, colors.selectedDark)
    color(colors.surface)
    G.circle("fill", 120, 83, 7)
    color(colors.selectedDark)
    G.circle("line", 120, 83, 7)
    drawPortrait(mon, 91, 50, 58, false)
    local fight = self:fitLabel(mon.fightLabel or translate("FIGHT"), 96)
    self:label(fight, 120 - math.floor(self:labelWidth(fight) / 2),
      126, colors.white)
    G.pop()
    self:endPress(pressed)
  end

  function H:battleBagIcon(x, y)
    color({ 1, 1, 1, 1 })
    ui.graphics.draw(ui.bagIcon, x, y)
  end

  local BATTLE_ACTION_CONTENT_RISE = 2

  function H:battleBagAction(mon, selected, offsetX, offsetY)
    local G, colors = ui.graphics, self.colors
    offsetX, offsetY = offsetX or 0, offsetY or 0
    local pressed = self:beginPress(6 + offsetX, 159 + offsetY, 68, 52)
    G.push()
    G.translate(offsetX, offsetY + 10)
    self:battleActionPanel(6, 149, 68, 52, "amber", selected)
    G.translate(0, -BATTLE_ACTION_CONTENT_RISE)
    self:battleBagIcon(27, 154)
    self:label(mon.bagLabel or translate("BAG"), 6, 183, colors.white, 68, "center")
    G.pop()
    self:endPress(pressed)
  end

  function H:battlePartyAction(mon, selected, offsetX, offsetY)
    local G, colors = ui.graphics, self.colors
    offsetX, offsetY = offsetX or 0, offsetY or 0
    local pressed = self:beginPress(166 + offsetX, 159 + offsetY, 68, 52)
    G.push()
    G.translate(offsetX, offsetY + 10)
    self:battleActionPanel(166, 149, 68, 52, "green", selected)
    G.translate(0, -BATTLE_ACTION_CONTENT_RISE)
    self:battleTeamBall(185, 169, true)
    self:battleTeamBall(200, 164, true)
    self:battleTeamBall(215, 169, true)
    self:label(mon.partyLabel or translate("POKEMON"), 166, 183,
      colors.white, 68, "center")
    G.pop()
    self:endPress(pressed)
  end

  function H:battleRunnerIcon(x, y)
    local colors = self.colors
    for _, offset in ipairs(runnerOutline) do
      for _, part in ipairs(runnerParts) do
        box("fill", x + part[1] - 119 + offset[1],
          y + part[2] - 167 + offset[2], part[3], part[4], colors.outline)
      end
    end
    for _, part in ipairs(runnerParts) do
      box("fill", x + part[1] - 119, y + part[2] - 167,
        part[3], part[4], colors.white)
    end
  end

  function H:battleRunAction(mon, selected, offsetX, offsetY)
    local G, colors = ui.graphics, self.colors
    offsetX, offsetY = offsetX or 0, offsetY or 0
    local pressed = self:beginPress(86 + offsetX, 159 + offsetY, 68, 52)
    G.push()
    G.translate(offsetX, offsetY + 10)
    self:battleActionPanel(86, 149, 68, 52, "blue", selected)
    G.translate(0, -BATTLE_ACTION_CONTENT_RISE)
    self:battleRunnerIcon(119, 168)
    self:label(mon.runLabel or translate("RUN"), 86, 183, colors.white, 68, "center")
    G.pop()
    self:endPress(pressed)
  end

  function H:battleRoot(mon, drawPortrait, playerTeam, enemyTeam, selected)
    selected = selected or 1
    self:battleTeamStrip(playerTeam, enemyTeam)
    self:battleFightAction(mon, drawPortrait, selected == 1)
    self:battleBagAction(mon, selected == 3)
    self:battlePartyAction(mon, selected == 2)
    self:battleRunAction(mon, selected == 4)
  end

  function H:battleStatusCard(mon, x, y, w, player, drawPortrait)
    if not mon then return end
    local colors = self.colors
    local accent = player and colors.green or colors.red
    local accentLight = player and colors.greenLight or colors.redLight
    local fainted = mon.statusId == "FNT" or (mon.hp or 0) <= 0
    self:panel(x, y, w, 78, false, nil, accent)
    box("fill", x + 2, y + 2, w - 4, 16, accent)
    box("fill", x + 5, y + 2, w - 10, 2, accentLight)
    local level = mon.levelText or "L--"
    local levelWidth = self:partyInfoWidth(level)
    local nameWidth = w - levelWidth - 19 - (mon.caught and 10 or 0)
    self:partyName(mon.name or translate("POKEMON"), x + 7, y + 5,
      colors.white, nameWidth)
    if mon.caught then self:battleTeamBall(x + w - levelWidth - 14, y + 10, true) end
    self:partyInfo(level, x + w - levelWidth - 7, y + 5, colors.white)

    drawPortrait(mon, x + 5, y + 21, 50, fainted)
    local infoX, infoW = x + 60, w - 67
    if mon.statusId then self:statusIcon(mon.statusId, infoX, y + 24) end
    self:partyInfo(mon.hpLabel or translate("HP"), infoX, y + 39, colors.green)
    self:hpBar(infoX, y + 51, infoW, mon.hp, mon.maxHp)
    if player then
      self:partyInfo(mon.hpText or "--/--", infoX, y + 59,
        colors.ink, infoW, "right")
    else
      self:partyInfo(mon.statusLabel or "", infoX + 10, y + 23,
        colors.ink, math.max(0, infoW - 10), "right")
    end
  end

  function H:battleFullAction(mon, index, selected, labels)
    local G, colors = ui.graphics, self.colors
    local action = self.fullBattleActions[index]
    local pressed = self:beginPress(action.x, action.y, action.w, action.h)
    self:battleActionPanel(action.x, action.y, action.w, action.h,
      action.color, selected)
    local iconX, iconY = action.x + 22, action.y + 22
    if index == 1 then
      G.push()
      G.translate(iconX - 10, iconY - 10)
      G.scale(2, 2)
      self:battleTeamBall(5, 5, true)
      G.pop()
    elseif index == 2 then
      self:battleTeamBall(iconX - 8, iconY + 2, true)
      self:battleTeamBall(iconX, iconY - 3, true)
      self:battleTeamBall(iconX + 8, iconY + 2, true)
    elseif index == 3 then
      self:battleBagIcon(action.x + 6, action.y + 6)
    else
      self:battleRunnerIcon(iconX, iconY)
    end
    local label = self:fitLabel(labels[index], action.w - 43)
    self:label(label, action.x + 39, action.y + 15, colors.white,
      action.w - 43, "center")
    self:endPress(pressed)
  end

  function H:battleFullStatuses(player, enemy, drawPortrait,
      playerTeam, enemyTeam)
    self:battleTeamStrip(playerTeam, enemyTeam)
    self:battleStatusCard(player, 6, 33, 112, true, drawPortrait)
    self:battleStatusCard(enemy, 122, 33, 112, false, drawPortrait)
  end

  function H:battleFullRoot(mon, player, enemy, drawPortrait,
      playerTeam, enemyTeam, selected)
    self:battleFullStatuses(player, enemy, drawPortrait,
      playerTeam, enemyTeam)
    local labels = { mon.fightLabel or translate("FIGHT"), mon.partyLabel or translate("POKEMON"),
      mon.bagLabel or translate("BAG"), mon.runLabel or translate("RUN") }
    for index = 1, 4 do
      self:battleFullAction(mon, index, selected == index, labels)
    end
  end

  function H:battleFullSafari(model, enemy, drawPortrait,
      playerTeam, enemyTeam)
    self:battleTeamStrip(playerTeam, enemyTeam)
    self:battleStatusCard(enemy, 6, 33, 228, false, drawPortrait)
    local labels = { format("BALL x%d", model.balls or 0),
      translate("BAIT"), translate("ROCK"), translate("RUN") }
    for index = 1, 4 do
      self:battleFullAction(model, index, model.index == index, labels)
    end
  end

  function H:battleSafariAction(action, index, selected)
    local G, colors = ui.graphics, self.colors
    local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
    local x, y = 6 + column * 116, 33 + row * 91
    local pressed = self:beginPress(x, y, 112, 86)
    self:battleActionPanel(x, y, 112, 86, action.color, selected)
    self:label(self:fitLabel(translate(action.label), 96),
      x + 8, y + (action.detail and 7 or 16),
      colors.white, 96, "center")
    local iconY = y + (action.detail and 46 or 55)
    if action.kind == "ball" then
      G.push()
      G.translate(x + 47, iconY - 10)
      G.scale(2, 2)
      self:battleTeamBall(5, 5, true)
      G.pop()
    elseif action.kind == "bait" then
      box("fill", x + 48, iconY - 5, 17, 13, colors.outline)
      box("fill", x + 50, iconY - 7, 13, 2, colors.outline)
      box("fill", x + 51, iconY - 4, 11, 10, colors.amberLight)
      box("fill", x + 54, iconY - 9, 5, 3, colors.greenLight)
      box("fill", x + 56, iconY - 2, 4, 4, colors.redLight)
    elseif action.kind == "rock" then
      box("fill", x + 48, iconY - 3, 4, 8, colors.outline)
      box("fill", x + 52, iconY - 7, 10, 14, colors.outline)
      box("fill", x + 62, iconY - 2, 4, 9, colors.outline)
      box("fill", x + 50, iconY - 2, 4, 6, colors.silverDark)
      box("fill", x + 53, iconY - 5, 8, 10, colors.silver)
      box("fill", x + 61, iconY - 1, 3, 6, colors.silverDark)
      box("fill", x + 55, iconY - 4, 4, 2, colors.white)
    else
      self:battleRunnerIcon(x + 56, iconY)
    end
    if action.detail then
      self:partyInfo(action.detail, x + 8, y + 67,
        colors.white, 96, "center")
    end
    self:endPress(pressed)
  end

  function H:battleSafari(model, playerTeam, enemyTeam)
    self:battleTeamStrip(playerTeam, enemyTeam)
    local actions = {
      { kind = "ball", label = "BALL", color = "red",
        detail = format("x%d", model.balls or 0) },
      { kind = "bait", label = "BAIT", color = "green" },
      { kind = "rock", label = "ROCK", color = "amber" },
      { kind = "run", label = "RUN", color = "blue" },
    }
    for index, action in ipairs(actions) do
      self:battleSafariAction(action, index, model.index == index)
    end
  end

  function H:safariHit(x, y)
    if y < 33 or y >= 210 then return nil end
    local column = x >= 122 and 1 or x >= 6 and 0 or nil
    if column == nil or x >= (column == 0 and 118 or 234) then return nil end
    local row = y >= 124 and 1 or y < 119 and 0 or nil
    if row == nil then return nil end
    return row * 2 + column + 1
  end

  function H:battleMimic(model, playerTeam, enemyTeam)
    local colors = self.colors
    self:battleTeamStrip(playerTeam, enemyTeam)
    self:panel(6, 33, 228, 24, false, nil, colors.blueLight)
    self:partyInfo(model.title or "MIMIC", 14, 41,
      colors.green, 212, "center")
    for slot = 1, math.min(4, #(model.moves or {})) do
      local move = model.moves[slot]
      self:summaryMoveRow(move, 6, 61 + (slot - 1) * 35,
        model.index == slot, move.available ~= false, false)
    end
  end

  function H:mimicHit(x, y, count)
    if x < 6 or x >= 234 or y < 61 then return nil end
    local slot = math.floor((y - 61) / 35) + 1
    local top = 61 + (slot - 1) * 35
    if slot >= 1 and slot <= math.min(4, count or 0)
        and y < top + 34 then return slot end
  end

  function H:enemyInfoHero(model, height)
    local G, colors = ui.graphics, self.colors
    local mon = model.pokemon or {}
    height = height or 66
    self:homeTile(7, 34, 226, height, colors.red, false)
    color(mixed(colors.surface, colors.redLight,
      self.dark and 0.22 or 0.12))
    G.circle("fill", 41, 34 + math.floor(height / 2), 25)
    color(colors.outline)
    G.circle("line", 41, 34 + math.floor(height / 2), 25)
    if model.drawPokemon then
      model.drawPokemon(mon, 16, 34 + math.floor((height - 50) / 2), 50, false)
    end
    self:partyName(self:fitPartyInfo(mon.name or translate("POKEMON"), 104),
      73, 40, colors.ink, 104)
    self:partyInfo(mon.levelText or "L--", 181, 40,
      colors.ink, 38, "right")
    self:typeBadges(mon, 73, 57, false)
    if mon.caught then
      self:battleTeamBall(218, 61, true)
    else
      self:partyType(translate("NOT CAUGHT"), 153, 58,
        colors.red, 70)
    end
  end

  function H:enemyInfoOverview(model)
    local colors = self.colors
    local mon = model.pokemon or {}
    self:enemyInfoHero(model, 66)

    local dvsPressed = self:beginPress(151, 72, 73, 21, mon.dvs ~= nil)
    self:panel(151, 72, 73, 21, false, nil,
      mon.dvs and colors.blueLight or colors.silverDark)
    self:partyType(mon.dvs and translate("DVS >") or "DVS --",
      155, 78, mon.dvs and colors.green or colors.silverDark, 65)
    self:endPress(dvsPressed)

    local profilePressed = self:beginPress(7, 105, 226, 39)
    self:homeTile(7, 105, 226, 39, colors.blue, false)
    self:partyInfo(translate("POKEDEX"), 17, 112,
      colors.ink, 130, "center")
    local dex = mon.dex and format("NO.%03d", mon.dex) or "NO.---"
    self:partyType(dex, 153, 116, colors.green, 56)
    self:detailChevron(216, 120, colors.green)
    self:endPress(profilePressed)

    local cards = {
      { key = "WEAK", rows = mon.weak or {}, x = 7,
        accent = colors.red },
      { key = "RESIST", rows = mon.resist or {}, x = 123,
        accent = colors.green },
    }
    for _, card in ipairs(cards) do
      local pressed = self:beginPress(card.x, 149, 110, 61)
      self:homeTile(card.x, 149, 110, 61, card.accent, false)
      self:partyType(translate(card.key), card.x + 7, 158,
        colors.ink, 96)
      self:partyInfo(tostring(#card.rows), card.x + 7, 176,
        colors.ink, 96, "center")
      self:partyType(translate("MATCHUP"), card.x + 7, 192,
        colors.green, 80)
      self:detailChevron(card.x + 96, 198, colors.green)
      self:endPress(pressed)
    end
  end

  function H:enemyInfoProfile(model)
    local colors = self.colors
    local mon = model.pokemon or {}
    self:enemyInfoHero(model, 66)
    self:partyType(self:fitPartyType(mon.kind or translate("UNKNOWN"), 71),
      73, 76, colors.green, 71)
    self:partyType(self:fitPartyType(mon.height or translate("HEIGHT --"), 71),
      146, 76, colors.green, 71)
    self:panel(7, 105, 226, 105, false, nil,
      self:typeColor(mon.type))
    self:partyType(translate("POKEDEX"), 15, 112,
      colors.green, 210)
    box("fill", 15, 126, 210, 1, colors.band)
    local lines = mon.description or {}
    if #lines == 0 then lines = { translate("NO DETAILS AVAILABLE") } end
    local visible = math.min(8, #lines)
    local blockHeight = visible * 10 - 1
    local top = 132 + math.floor((70 - blockHeight) / 2)
    for index = 1, visible do
      self:partyInfo(self:fitPartyInfo(lines[index], 206),
        17, top + (index - 1) * 10, colors.ink, 206, "center")
    end
    self:partyType(self:fitPartyType(mon.weight or translate("WEIGHT --"), 84),
      141, 193, colors.green, 84)
  end

  function H:enemyInfoDvs(model)
    local colors = self.colors
    local mon, rows = model.pokemon or {}, model.rows or {}
    self:homeTile(7, 34, 226, 37, colors.blue, false)
    if model.drawPokemon then model.drawPokemon(mon, 13, 37, 31, false) end
    self:partyInfo(self:fitPartyInfo(mon.name or translate("POKEMON"), 112),
      50, 40, colors.ink)
    self:partyType(translate("ENEMY DVS"), 157, 44,
      colors.green, 68)
    if #rows == 0 then
      self:panel(24, 82, 192, 90, false, nil, colors.silverDark)
      self:partyInfo(translate("NO DETAILS AVAILABLE"), 32, 121,
        colors.silverDark, 176, "center")
    else
      for index, row in ipairs(rows) do
        local line = math.floor((index - 1) / 3)
        local columns = math.min(3, #rows - line * 3)
        local width, gap = 68, 5
        local group = columns * width + (columns - 1) * gap
        local column = (index - 1) % 3
        local x = math.floor((240 - group) / 2) + column * (width + gap)
        local y = 78 + line * 47
        self:panel(x, y, width, 42, false, nil, colors.blueLight)
        self:partyType(self:fitPartyType(translate(row.label), width - 8),
          x + 4, y + 7, colors.green, width - 8)
        self:partyInfo(tostring(row.value or 0), x + 4, y + 24,
          colors.ink, width - 8, "center")
      end
    end
    self:panel(42, 172, 156, 38, false, nil, colors.blueLight)
    self:partyInfo(translate("RANGE 0-15"), 50, 185,
      colors.green, 140, "center")
  end

  function H:enemyInfoMatchup(model)
    local colors = self.colors
    local mon, rows = model.pokemon or {}, model.rows or {}
    self:homeTile(7, 34, 226, 37,
      model.kind == "weak" and colors.red or colors.green, false)
    if model.drawPokemon then model.drawPokemon(mon, 13, 37, 31, false) end
    self:partyInfo(self:fitPartyInfo(mon.name or translate("POKEMON"), 101),
      50, 40, colors.ink)
    self:partyType(translate("BASE MATCHUP"), 151, 44,
      colors.green, 74)
    if #rows == 0 then
      self:panel(24, 92, 192, 70, false, nil, colors.silverDark)
      self:partyInfo("--", 32, 122, colors.silverDark, 176, "center")
      return
    end
    local columns = #rows > 7 and 2 or 1
    local rowsPerColumn = math.ceil(#rows / columns)
    local gap = 2
    local height = math.min(24, math.floor(
      (133 - (rowsPerColumn - 1) * gap) / rowsPerColumn))
    local groupWidth = columns * 110 + (columns - 1) * 6
    local left = math.floor((240 - groupWidth) / 2)
    local totalHeight = rowsPerColumn * height
      + (rowsPerColumn - 1) * gap
    local top = 77 + math.floor((133 - totalHeight) / 2)
    for index, row in ipairs(rows) do
      local column = math.floor((index - 1) / rowsPerColumn)
      local line = (index - 1) % rowsPerColumn
      local x, y = left + column * 116, top + line * (height + gap)
      self:panel(x, y, 110, height, false, nil,
        self:typeColor(row.type))
      local badgeY = y + math.floor((height - 10) / 2)
      clipped(x + 5, badgeY, 63, 10, self:typeColor(row.type))
      border(x + 5, badgeY, 63, 10, colors.outline)
      self:partyType(self:fitPartyType(row.typeLabel or row.type, 59),
        x + 7, badgeY - 1, colors.white, 59)
      self:partyInfo(row.effectLabel or "--", x + 73,
        y + math.floor((height - 9) / 2), colors.ink, 30, "center")
    end
  end

  function H:enemyInfoHit(x, y, hasDvs)
    if hasDvs and x >= 151 and x < 224 and y >= 72 and y < 93 then
      return "dvs"
    end
    if x >= 7 and x < 233 and y >= 105 and y < 144 then return "profile" end
    if y >= 149 and y < 210 then
      if x >= 7 and x < 117 then return "weak" end
      if x >= 123 and x < 233 then return "resist" end
    end
  end

  local PC_LIST_TOP, PC_LIST_HEIGHT, PC_LIST_GAP = 63, 33, 3

  function H:pcStorageIcon(x, y, kind)
    local colors = self.colors
    local accent = kind == "items" and colors.amberLight or colors.blueLight
    clipped(x + 2, y + 1, 27, 20, colors.outline)
    clipped(x + 4, y + 3, 23, 16,
      mixed(colors.surface, accent, self.dark and 0.32 or 0.22))
    box("fill", x + 7, y + 6, 17, 8, accent)
    box("fill", x + 13, y + 21, 5, 3, colors.outline)
    box("fill", x + 8, y + 24, 15, 2, colors.outline)
    if kind == "items" then
      box("fill", x + 12, y + 8, 7, 5, colors.white)
      box("fill", x + 10, y + 10, 11, 2, colors.white)
    else
      self:battleTeamBall(x + 15, y + 10, true)
    end
  end

  function H:pcRootRows(count)
    count = math.max(1, math.min(6, count or 0))
    local height = math.floor((124 - (count - 1) * 3) / count)
    return 86, height
  end

  function H:pcRoot(model)
    local colors = self.colors
    local entries = model.entries or {}
    self:panel(7, 34, 226, 46, false, nil,
      model.kind == "items" and colors.amberLight or colors.blueLight)
    self:pcStorageIcon(16, 43, model.kind)
    box("fill", 53, 40, 1, 34, colors.band)
    self:partyInfo(self:fitPartyInfo(model.title or translate("PC"), 160),
      62, 45, colors.ink, 160, "center")
    self:partyType(self:fitPartyType(model.status or translate("READY"), 160),
      62, 61, colors.green, 160)
    if #entries == 0 then
      self:panel(24, 105, 192, 70, false, nil, colors.silverDark)
      self:partyInfo(translate("NOTHING HERE"), 32, 134,
        colors.silverDark, 176, "center")
      return
    end
    local top, height = self:pcRootRows(#entries)
    for index = 1, math.min(6, #entries) do
      local entry = entries[index]
      local y = top + (index - 1) * (height + 3)
      local pressed = self:beginPress(7, y, 226, height)
      self:panel(7, y, 226, height, false, nil,
        index % 2 == 0 and colors.blueLight or colors.greenLight)
      if entry.selected then
        clipped(9, y + 2, 222, height - 4,
          self:focusSurface(true, colors.surface, colors.blueLight))
      end
      self:partyName(self:fitPartyInfo(entry.label or tostring(index), 184),
        19, y + math.floor((height - 10) / 2), colors.ink, 184)
      self:detailChevron(216, y + math.floor(height / 2), colors.green)
      if entry.selected then self:focusFrame(7, y, 226, height) end
      self:endPress(pressed)
    end
  end

  function H:pcList(model)
    local colors = self.colors
    local entries = model.entries or {}
    self:panel(7, 34, 226, 24, false, nil, colors.blueLight)
    self:partyInfo(self:fitPartyInfo(model.summary or translate("PC"), 210),
      15, 41, colors.green, 210, "center")
    if #entries == 0 then
      self:panel(24, 91, 192, 70, false, nil, colors.silverDark)
      self:partyInfo(translate("NOTHING HERE"), 32, 120,
        colors.silverDark, 176, "center")
      return
    end
    for index, entry in ipairs(entries) do
      local y = PC_LIST_TOP + (index - 1) * (PC_LIST_HEIGHT + PC_LIST_GAP)
      local accent = entry.back and colors.silverDark
        or entry.kind == "item" and colors.amberLight
        or entry.kind == "box" and colors.greenLight or colors.blueLight
      local pressed = self:beginPress(7, y, 226, PC_LIST_HEIGHT)
      self:panel(7, y, 226, PC_LIST_HEIGHT, false, nil, accent)
      if entry.selected then
        clipped(9, y + 2, 222, PC_LIST_HEIGHT - 4,
          self:focusSurface(true, colors.surface, accent))
      end
      if entry.mon and model.drawPokemon then
        model.drawPokemon(entry.mon, 12, y + 3, 27)
        box("fill", 46, y + 4, 1, 25, colors.band)
      elseif entry.kind == "item" then
        clipped(13, y + 6, 21, 21, colors.bandLight)
        border(13, y + 6, 21, 21, colors.band)
        self:battleItemIcon(entry, 15, y + 8, accent)
        box("fill", 42, y + 4, 1, 25, colors.band)
      end
      local left = (entry.mon and 53) or (entry.kind == "item" and 49) or 17
      local right = entry.right and tostring(entry.right) or nil
      local rightWidth = right and math.max(26,
        math.min(72, self:partyInfoWidth(right))) or 0
      self:partyName(self:fitPartyInfo(entry.label or tostring(index),
        199 - left - rightWidth), left, y + 6, colors.ink,
        199 - left - rightWidth)
      if right then
        self:partyInfo(right, 199 - rightWidth, y + 7,
          colors.green, rightWidth, "right")
      end
      self:detailChevron(216, y + 16, colors.green)
      if entry.selected then self:focusFrame(7, y, 226, PC_LIST_HEIGHT) end
      self:endPress(pressed)
    end
  end

  function H:pcQuantity(model)
    local colors = self.colors
    self:panel(7, 34, 226, 50, false, nil, colors.amberLight)
    clipped(17, 44, 30, 30, colors.bandLight)
    border(17, 44, 30, 30, colors.outline)
    self:battleItemIcon({ icon = model.icon or "item" }, 24, 51,
      colors.amberLight)
    box("fill", 55, 41, 1, 36, colors.band)
    self:partyName(self:fitPartyInfo(model.label or translate("ITEM"), 161),
      64, 47, colors.ink, 161)
    self:partyType(translate("QUANTITY"), 64, 64,
      colors.green, 161)

    local controls = {
      { x = 7, label = "-" }, { x = 83, value = tostring(model.qty or 1) },
      { x = 159, label = "+" },
    }
    for _, control in ipairs(controls) do
      local interactive = control.label ~= nil
      local pressed = interactive and self:beginPress(control.x, 91, 74, 48)
      self:panel(control.x, 91, 74, 48, false, nil,
        interactive and colors.blueLight or colors.greenLight)
      self:partyInfo(control.label or control.value, control.x, 108,
        colors.ink, 74, "center")
      if pressed then self:endPress(pressed) end
    end
    local buttons = {
      { x = 7, label = translate("CONFIRM"), accent = colors.greenLight },
      { x = 123, label = translate("CANCEL"), accent = colors.redLight },
    }
    for _, action in ipairs(buttons) do
      local pressed = self:beginPress(action.x, 146, 110, 64)
      self:panel(action.x, 146, 110, 64, false, nil, action.accent)
      self:partyInfo(action.label, action.x, 171,
        colors.ink, 110, "center")
      self:endPress(pressed)
    end
  end

  function H:pcTopOnly(model)
    local colors = self.colors
    self:panel(18, 48, 204, 132, false, nil, colors.blueLight)
    self:pcStorageIcon(104, 62, model and model.kind)
    box("fill", 34, 101, 172, 1, colors.band)
    self:partyInfo(translate("FOLLOW TOP SCREEN"), 28, 116,
      colors.green, 184, "center")
    self:partyInfo(translate("INPUT STAYS ON TOP"), 28, 137,
      colors.ink, 184, "center")
  end

  function H:pcNoticeRows(count)
    local visible = math.max(1, math.min(4, count or 0))
    local lineHeight = visible == 4 and 13 or visible == 3 and 16 or 18
    local blockHeight = 9 + (visible - 1) * lineHeight
    return 105 + math.floor((53 - blockHeight) / 2), lineHeight, visible
  end

  function H:pcNotice(model)
    local colors = self.colors
    local pressed = self:beginPress(12, 48, 216, 132)
    self:panel(12, 48, 216, 132, false, nil, colors.blueLight)
    self:pcStorageIcon(104, 58, model and model.kind)
    box("fill", 28, 99, 184, 1, colors.band)
    local lines = model and model.lines or { "..." }
    if #lines == 0 then lines = { "..." } end
    local y, lineHeight, visible = self:pcNoticeRows(#lines)
    for index = 1, visible do
      self:partyInfo(self:fitPartyInfo(lines[index], 184), 28, y,
        colors.ink, 184, "center")
      y = y + lineHeight
    end
    local bob = self:battleContinueMotion(model and model.now)
    local arrowY = 163 + bob
    box("fill", 115, arrowY, 10, 2, colors.outline)
    box("fill", 117, arrowY + 2, 6, 2, colors.outline)
    box("fill", 119, arrowY + 4, 2, 2, colors.outline)
    self:endPress(pressed)
  end

  function H:pcRootHit(x, y, count)
    if x < 7 or x >= 233 or count < 1 then return nil end
    local top, height = self:pcRootRows(count)
    for index = 1, math.min(6, count) do
      local rowTop = top + (index - 1) * (height + 3)
      if y >= rowTop and y < rowTop + height then return index end
    end
  end

  function H:pcListHit(x, y, count)
    if x < 7 or x >= 233 then return nil end
    local row = math.floor((y - PC_LIST_TOP) / (PC_LIST_HEIGHT + PC_LIST_GAP)) + 1
    local top = PC_LIST_TOP + (row - 1) * (PC_LIST_HEIGHT + PC_LIST_GAP)
    if row >= 1 and row <= math.min(4, count or 0)
        and y >= top and y < top + PC_LIST_HEIGHT then return row end
  end

  function H:pcQuantityHit(x, y)
    if y >= 91 and y < 139 then
      if x >= 7 and x < 81 then return "minus" end
      if x >= 159 and x < 233 then return "plus" end
    elseif y >= 146 and y < 210 then
      if x >= 7 and x < 117 then return "confirm" end
      if x >= 123 and x < 233 then return "cancel" end
    end
  end

  function H:silphLinkIcon(cx, cy, phase)
    local G, colors = ui.graphics, self.colors
    phase = phase or 0

    color(colors.outline)
    G.circle("fill", cx, cy, 29)
    color(self.dark and colors.bandLight or colors.white)
    G.circle("fill", cx, cy, 26)
    color(colors.redLight)
    G.arc("fill", cx, cy, 24, math.pi, math.pi * 2)
    box("fill", cx - 24, cy - 1, 48, 3, colors.outline)
    color(colors.white)
    G.circle("fill", cx, cy, 8)
    color(colors.outline)
    G.circle("line", cx, cy, 8)
    G.circle("fill", cx, cy, 3)

    G.setLineWidth(3)
    color(colors.blueLight)
    G.arc("line", "open", cx, cy, 36, math.pi, math.pi * 5 / 3)
    color(colors.greenLight)
    G.arc("line", "open", cx, cy, 36, -math.pi / 3, math.pi / 3)
    color(colors.amberLight)
    G.arc("line", "open", cx, cy, 36, math.pi / 3, math.pi)
    G.setLineWidth(1)
    for index, node in ipairs({ { -35, 0 }, { 18, -31 }, { 18, 31 } }) do
      local active = index - 1 == phase
      color(colors.outline)
      G.circle("fill", cx + node[1], cy + node[2], 5)
      color(active and colors.amberLight or colors.greenLight)
      G.circle("fill", cx + node[1], cy + node[2], active and 3 or 2)
    end
  end

  function H:titleBoot(model, now)
    local G, colors = ui.graphics, self.colors
    local phase = math.floor((tonumber(now) or 0) * 2) % 3

    self:panel(10, 9, 220, 153, false, nil, colors.blueLight)
    box("fill", 15, 14, 70, 3, colors.redLight)
    box("fill", 85, 14, 70, 3, colors.blueLight)
    box("fill", 155, 14, 70, 3, colors.greenLight)
    self:partyType(translate("SILPH CO."), 15, 22, colors.green, 105)
    self:partyType("KANTO GEAR 3.0", 120, 22, colors.ink, 105)

    self:silphLinkIcon(120, 70, phase)
    fontText(trainerNameFont, translate("SILPH LINK"), 28, 109,
      colors.ink, 184, "center")
    self:partyInfo(self:fitPartyInfo(model.systemId or "SLS-DEV", 102),
      69, 128, self.dark and colors.silver or colors.silverDark,
      102, "center")

    clipped(57, 141, 126, 15, colors.bandLight)
    border(57, 141, 126, 15, colors.green)
    local status = self:fitPartyType(translate("LINK ONLINE"), 104)
    local statusWidth = partyTypeFont:getWidth(status)
    local statusLeft = 120 - math.floor((statusWidth + 12) / 2 + 0.5)
    color(colors.greenLight)
    G.circle("fill", statusLeft + 3, 148, 3)
    fontText(partyTypeFont, status, statusLeft + 12, 144, colors.green)

    local pressed = self:beginPress(0, 0, 240, 216)
    if self:shadowVisible() then
      clipped(26, 175, 188, 36, colors.shadow)
    end
    clipped(26, 171, 188, 36,
      self:focusSurface(pressed, colors.green, colors.greenLight))
    border(26, 171, 188, 36, colors.outline)
    box("fill", 32, 173, 176, 2,
      mixed(colors.greenLight, colors.white, 0.28))
    box("fill", 32, 202, 176, 2, mixed(colors.green, colors.outline, 0.34))
    fontText(trainerValueFont, translate("START GAME"), 40, 181,
      colors.white, 160, "center")
    self:detailChevron(195, 185, colors.white, true)
    self:endPress(pressed)
  end

  function H:systemOverlay(alpha, prompt, now)
    local colors = self.colors
    color({ 0, 0, 0, alpha or 0.5 })
    ui.graphics.rectangle("fill", 0, 0, 240, 216)
    if not prompt then return end
    local bob, shadowWidth = self:battleContinueMotion(now)
    local x, y = 115, 179 + bob
    local shadowX = x + 5 - math.floor(shadowWidth / 2)
    if self:shadowVisible() then
      box("fill", shadowX, 192, shadowWidth, 2, colors.shadow)
    end
    box("fill", x, y, 10, 2, colors.outline)
    box("fill", x + 1, y + 2, 8, 2, colors.outline)
    box("fill", x + 2, y + 4, 6, 2, colors.outline)
    box("fill", x + 3, y + 6, 4, 2, colors.outline)
    box("fill", x + 4, y + 8, 2, 1, colors.outline)
    box("fill", x + 1, y + 1, 8, 1, colors.greenLight)
    box("fill", x + 2, y + 2, 6, 2, colors.green)
    box("fill", x + 3, y + 4, 4, 2, colors.green)
    box("fill", x + 4, y + 6, 2, 2, colors.green)
  end

  function H:loadingOverlay(label, now)
    local colors = self.colors
    self:systemOverlay(0.58, false)
    self:panel(45, 72, 150, 72, false, nil, colors.blueLight)
    self:partyInfo(translate(label or "LOADING AREA"), 55, 91,
      colors.ink, 130, "center")
    local phase = math.floor((tonumber(now) or 0) * 3) % 3
    local groupLeft = 107
    for index = 0, 2 do
      local tint = index == phase and colors.greenLight or colors.band
      clipped(groupLeft + index * 9, 116, 6, 6, tint)
      border(groupLeft + index * 9, 116, 6, 6, colors.outline)
    end
  end

  do
    local rootTop5, rootHeight5 = H:pcRootRows(5)
    local rootTop6, rootHeight6 = H:pcRootRows(6)
    local noticeTop, noticeStep, noticeCount = H:pcNoticeRows(4)
    assert(H:pcRootHit(120, 90, 4) == 1
        and H:pcRootHit(120, 207, 5) == 5
        and H:pcRootHit(120, 208, 6) == 6
        and rootTop5 + 5 * rootHeight5 + 4 * 3 <= 210
        and rootTop6 + 6 * rootHeight6 + 5 * 3 <= 210
        and H:fitPartyInfo("WITHDRAW <PK><MN>", 220)
          == "WITHDRAW PKMN"
        and noticeTop + (noticeCount - 1) * noticeStep + 9 <= 158
        and H:pcListHit(120, 100, 4) == 2
        and H:pcListHit(120, 96, 4) == nil
        and H:pcQuantityHit(30, 110) == "minus"
        and H:pcQuantityHit(200, 180) == "cancel",
      "HGSS PC hitboxes match visible storage controls")
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

  function H:bagCard(item, x, y)
    local colors = self.colors
    local accent = self:itemAccent(item.icon)
    local pressed = self:beginPress(x, y, 112, 43)
    self:panel(x, y, 112, 43, false, nil, accent)
    clipped(x + 5, y + 7, 29, 29,
      mixed(colors.surface, accent, self.dark and 0.24 or 0.18))
    border(x + 5, y + 7, 29, 29, colors.outline)
    self:battleItemIcon(item, x + 11, y + 13, accent)
    box("fill", x + 39, y + 5, 1, 33, colors.band)
    self:partyName(item.label or translate("ITEM"), x + 45, y + 7,
      colors.ink, 58)
    local second = item.detail and self:fitPartyInfo(item.detail, 43)
      or ("x%d"):format(tonumber(item.count) or 0)
    self:partyInfo(second, x + 45, y + 24,
      item.detail and colors.green or colors.silverDark, 44)
    if item.detail then
      self:partyInfo(("x%d"):format(tonumber(item.count) or 0),
        x + 88, y + 24, colors.silverDark, 15, "right")
    end
    self:detailChevron(x + 104, y + 19, colors.green, false)
    self:endPress(pressed)
  end

  function H:bagOverview(model)
    local colors = self.colors
    self:panel(6, 34, 228, 34, false, nil, colors.amberLight)
    self:battleBagIcon(14, 37)
    box("fill", 46, 38, 1, 26, colors.band)
    if (model.pockets or 1) > 1 then
      self:pageChevron(58, 51, false)
      self:pageChevron(166, 51, true)
    end
    local labelX, labelW = (model.pockets or 1) > 1 and 68 or 53,
      (model.pockets or 1) > 1 and 88 or 118
    self:partyInfo(self:fitPartyInfo(model.pocket or translate("ITEMS"), labelW),
      labelX, 44, colors.ink, labelW, "center")
    box("fill", 177, 38, 1, 26, colors.band)
    local page = ("%d/%d"):format(model.page or 1, model.pages or 1)
    clipped(184, 42, 43, 18, colors.bandLight)
    border(184, 42, 43, 18, colors.outline)
    self:pageChevron(190, 51, false, (model.pages or 1) > 1)
    self:partyInfo(page, 197, 45, colors.ink, 23, "center")
    self:pageChevron(222, 51, true, (model.pages or 1) > 1)

    if #(model.entries or {}) == 0 then
      self:panel(24, 91, 192, 70, false)
      self:partyInfo(translate("THIS POCKET IS EMPTY."), 24, 116,
        colors.silverDark, 192, "center")
      return
    end
    for index, item in ipairs(model.entries or {}) do
      local col, row = (index - 1) % 2, math.floor((index - 1) / 2)
      self:bagCard(item, 6 + col * 116, 72 + row * 47)
    end
  end

  function H:bagDetail(model)
    local item, colors = model.detail, self.colors
    local accent = self:itemAccent(item.icon)
    self:panel(6, 34, 228, 124, false, nil, accent)
    clipped(16, 44, 45, 45,
      mixed(colors.surface, accent, self.dark and 0.24 or 0.18))
    border(16, 44, 45, 45, colors.outline)
    ui.graphics.push()
    ui.graphics.translate(20, 48)
    ui.graphics.scale(2, 2)
    self:battleItemIcon(item, 0, 0, accent)
    ui.graphics.pop()
    box("fill", 68, 42, 1, 51, colors.band)
    self:partyName(item.label or translate("ITEM"), 77, 47, colors.ink, 140)
    self:partyInfo(("x%d"):format(tonumber(item.count) or 0),
      77, 67, colors.silverDark)
    local lines = model.message or item.lines or {}
    box("fill", 16, 99, 208, 1, colors.band)
    for index = 1, math.min(3, #lines) do
      self:partyInfo(self:fitPartyInfo(lines[index], 200),
        20, 103 + (index - 1) * 14, colors.ink, 200, "center")
    end

    local enabled = model.canUse ~= false
    local pressed = self:beginPress(54, 166, 132, 40, enabled)
    self:panel(54, 166, 132, 40, false, nil, colors.amberLight)
    clipped(57, 169, 126, 34,
      enabled and self:focusSurface(true, colors.surface, colors.amberLight)
        or colors.bandLight)
    local label = translate(model.message and "USE AGAIN" or "USE")
    self:partyInfo(label, 54, 180,
      enabled and colors.ink or colors.silverDark, 132, "center")
    self:endPress(pressed)
  end

  function H:bag(model)
    if model.detail then self:bagDetail(model) else self:bagOverview(model) end
  end

  function H:bagHit(x, y, model)
    if model.detail then
      if x >= 54 and x < 186 and y >= 166 and y < 206
          and model.canUse ~= false then return "use" end
      return nil
    end
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
      local left, top = 6 + col * 116, 72 + row * 47
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

  function H:battleBagRow(item, index, y, selected, offsetX)
    local G, colors = ui.graphics, self.colors
    local disabled = item.disabled
    local ink = disabled and colors.silverDark or colors.ink
    local iconTint = disabled and colors.silverDark
      or item.icon == "ball" and colors.redLight
      or item.icon == "medicine" and colors.blueLight
      or item.icon == "status" and colors.greenLight
      or item.icon == "machine" and colors.amberLight
      or colors.blueLight
    local pressed = self:beginPress(7 + (offsetX or 0), y, 226, 31,
      not disabled)
    G.push()
    G.translate(offsetX or 0, 0)
    self:panel(7, y, 226, 31, false, nil, iconTint)
    if selected and not disabled then
      clipped(9, y + 2, 222, 27,
        self:focusSurface(true, colors.surface, iconTint))
    end
    clipped(14, y + 5, 21, 21, colors.bandLight)
    border(14, y + 5, 21, 21, colors.band)
    self:battleItemIcon(item, 16, y + 7, iconTint)
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
      self:partyInfo(item.catchLabel or translate("CATCH"), 46, y + 17,
        colors.green, 37)
      clipped(84, y + 16, 42, 12, colors.greenLight)
      border(84, y + 16, 42, 12, colors.outline)
      self:partyType(chance, 86, y + 16, colors.white, 38)
    elseif disabled then
      self:partyInfo(item.disabledLabel or translate("UNUSABLE"), 46, y + 17,
        colors.silverDark)
    end
    if selected and not disabled then self:focusFrame(7, y, 226, 31) end
    G.pop()
    self:endPress(pressed)
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

  function H:battleBackdrop()
    pokeballBackdrop(self.colors, 240, 216, 2)
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
    local pressed = self:beginPress(x, y, 112, 80, not disabled)
    self:panel(x, y, 112, 80, selected and not disabled,
      self:typeColor(move.type), self:typeColor(move.type))

    local ink = disabled and colors.silverDark or colors.ink
    self:partyName(move.name or "-", x + 9, y + 7, ink, 88)
    self:detailChevron(x + 99, y + 11, ink)
    self:moveTypeBadge(move, x + 9, y + 26)
    self:partyInfo(move.ppLabel or translate("PP"), x + 61, y + 25, colors.green)
    self:partyInfo(move.ppText or "--", x + 76, y + 25,
      ink, 29, "right")
    box("fill", x + 9, y + 42, 94, 1, colors.band)
    self:partyInfo(move.powerLabel or translate("PWR"), x + 9, y + 51, colors.green)
    self:partyInfo(move.powerText or "--", x + 35, y + 51,
      ink, 22, "right")
    self:partyInfo(move.accuracyLabel or translate("ACC"), x + 62, y + 51,
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
      self:partyType(translate("STAB"), x + 28, y + 65, colors.white, 30)
    end
    clipped(effectX, y + 66, 27, 10, effectFill)
    border(effectX, y + 66, 27, 10, colors.outline)
    self:partyType(effectLabel, effectX + 2, y + 65, colors.white, 23)
    self:endPress(pressed)
  end

  function H:battleMoves(mon, playerTeam, enemyTeam)
    self:battleTeamStrip(playerTeam, enemyTeam, true)
    for slot = 1, 4 do
      local column, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
      local move = mon.moves[slot] or {}
      self:battleMoveCard(move, 6 + column * 116,
        33 + row * 85, mon.moveIndex == slot, self:moveHasStab(mon, move))
    end
  end

  function H:battleMoveInfoStat(x, label, value, accent)
    local colors = self.colors
    self:panel(x, 70, 66, 41, false, nil, accent)
    self:partyInfo(label, x, 76, colors.green, 66, "center")
    self:partyInfo(value, x, 91, colors.ink, 66, "center")
  end

  function H:battleMoveInfoBody(move, stab)
    local colors = self.colors
    local accent = self:typeColor(move.type)
    self:panel(6, 33, 228, 169, false, nil, accent)
    self:partyName(move.name or "-", 20, 42, colors.ink, 144)
    self:moveTypeBadge(move, 176, 43)
    box("fill", 16, 63, 208, 1, colors.band)

    local accuracy = tostring(move.accuracyText or "--")
    if accuracy ~= "--" and not accuracy:find("%%") then
      accuracy = accuracy .. "%"
    end
    self:battleMoveInfoStat(14, move.powerLabel or translate("PWR"),
      tostring(move.powerText or "--"), colors.redLight)
    self:battleMoveInfoStat(87, move.accuracyLabel or translate("ACC"), accuracy,
      colors.blueLight)
    self:battleMoveInfoStat(160, move.ppLabel or translate("PP"),
      tostring(move.ppText or "--"), colors.greenLight)

    self:panel(14, 117, 103, 36, false, nil, accent)
    self:partyInfo(move.stabLabel or translate("STAB"), 14, 122,
      colors.green, 103, "center")
    local stabFill = stab and accent or colors.silverDark
    clipped(48, 137, 35, 11, stabFill)
    border(48, 137, 35, 11, colors.outline)
    self:partyType(stab and "1.5X" or "--", 50, 136,
      colors.white, 31)

    self:panel(123, 117, 103, 36, false, nil, colors.greenLight)
    self:partyInfo(move.matchupLabel or translate("MATCHUP"), 123, 122,
      colors.green, 103, "center")
    local effectLabel, effectiveness = self:battleEffectLabel(move)
    local effectFill = effectiveness == 0 and colors.red
      or effectiveness and effectiveness > 10 and colors.greenLight
      or effectiveness and effectiveness < 10 and colors.amber
      or colors.silverDark
    clipped(161, 137, 27, 11, effectFill)
    border(161, 137, 27, 11, colors.outline)
    self:partyType(effectLabel, 163, 136, colors.white, 23)

    self:panel(14, 158, 212, 36, false, nil, accent)
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
    self:battleTeamStrip(playerTeam, enemyTeam, true)
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
    self:battleTeamStrip(playerTeam, enemyTeam, true)
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
    self:battleTeamStrip(playerTeam, enemyTeam, true)
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
    self:headerBar(title or translate("PARTY"), true, false)
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
    pokeballEmboss(colors, 240, BACKDROP_CENTER_Y, 2)
  end

  function H:partyPanel(x, y, w, h, selected, fainted, focused)
    local G, colors = ui.graphics, self.colors
    if self:shadowVisible() then
      color(colors.shadow)
      G.rectangle("fill", x + 1, y + 2, w, h, 6, 6)
    end
    local fill = fainted and colors.fainted
      or selected and colors.selected or colors.party
    if focused and not fainted then
      fill = self:focusSurface(true, colors.party, colors.partyLight)
    end
    color(fill)
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
      clipped(x + 10, y, 23, 10, left)
      border(x + 10, y, 23, 10, edge)
      self:partyType(leftText, x + 10, y - 1, leftInk, 23)
      return
    end
    local right, rightInk, rightText = typeBadgeStyle(
      self, mon.type2, mon.type2Label, fainted)
    clipped(x, y, 43, 10, left)
    box("fill", x + 21, y, 20, 10, right)
    box("fill", x + 21, y + 1, 21, 8, right)
    box("fill", x + 21, y + 2, 22, 6, right)
    border(x, y, 43, 10, edge)
    box("fill", x + 21, y + 1, 1, 8, edge)
    self:partyType(leftText, x + 1, y - 1, leftInk, 20)
    self:partyType(rightText, x + 22, y - 1, rightInk, 20)
  end

  function H:partyPosition(slot)
    local index = slot - 1
    local col, row = index % 2, math.floor(index / 2)
    return 5 + col * 118, 32 + row * 58 + (col == 1 and 4 or 0)
  end

  function H:partyCard(mon, x, y, selected, details, drawPortrait, focused)
    local fainted = mon and (mon.statusId == "FNT"
      or mon.hp ~= nil and mon.hp <= 0)
    local pressed = self:beginPress(x, y, 112, 56, mon ~= nil)
    if focused == nil then focused = selected end
    self:partyPanel(x, y, 112, 56, selected, fainted, focused)
    if not mon then
      self:label("-", x, y + 18, self.colors.ink, 112, "center")
      self:endPress(pressed)
      return
    end
    self:partyPortrait(x + 5, y + 2, selected, fainted)
    drawPortrait(mon, x + 6, y + 4, 32, fainted)
    local ink = self.colors.white
    local quiet = selected and self.colors.white or self.colors.silver
    self:partyName(mon.name, x + 44, y + 4, ink,
      details == true and 61 or 67)
    if details == true then self:detailChevron(x + 105, y + 8, ink) end
    if mon.egg then self:endPress(pressed); return end
    self:typeBadges(mon, x + 1, y + 42, fainted)
    if mon.gender == "male" then
      self:genderIcon("male", x + 99, y + 19)
    elseif mon.gender == "female" then
      self:genderIcon("female", x + 99, y + 19)
    end
    self:partyInfo(mon.levelText, x + 45, y + 17, quiet)
    if mon.statusId then
      self:statusIcon(mon.statusId, x + 70, y + 19)
    end
    self:partyInfo(mon.hpLabel or translate("HP"), x + 45, y + 27, quiet)
    self:partyInfo(mon.hpText, x + 45, y + 27, quiet, 62, "right")
    self:hpBar(x + 45, y + 38, 62, mon.hp, mon.maxHp)
    self:partyInfo(mon.expLabel or translate("EXP"), x + 45, y + 41, quiet)
    self:expBar(x + 65, y + 45, 42, mon.expProgress)
    self:endPress(pressed)
  end

  function H:partySwap(drawPartyCard, source, target)
    for slot = 1, 6 do
      local x, y = self:partyPosition(slot)
      drawPartyCard(slot, x, y, slot == target, false)
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
      progress < 0.45, false)

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
          false)
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
    self:panel(6, 34, 228, 80, false, nil,
      self:typeColor(mon.types and mon.types[1]))
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
      self:partyInfo(mon.infoLabel or translate("ITEM"), 121, 66, colors.green)
      self:partyInfo(self:fitPartyInfo(mon.infoText or "---", 76),
        151, 66, colors.ink, 76, "right")
    end
    self:partyInfo(mon.hpLabel or translate("HP"), 72, 79, colors.green)
    self:partyInfo(mon.hpText, 72, 79, colors.ink, 155, "right")
    self:hpBar(72, 90, 155, mon.hp, mon.maxHp)
    self:summaryExperience(mon)
  end

  function H:summaryExperience(mon)
    local colors, barWidth = self.colors, 128
    self:partyInfo(mon.expLabel or translate("EXP"), 72, 98, colors.green)
    if mon.nextValue then
      local valueWidth = self:partyInfoWidth(mon.nextValue)
      local label = self:fitPartyInfo(mon.nextLabel or translate("NEXT"),
        95 - valueWidth)
      local groupWidth = self:partyInfoWidth(label) + 4 + valueWidth
      local left = 227 - groupWidth
      barWidth = left - 104
      self:partyInfo(label, left, 98, colors.green)
      self:partyInfo(mon.nextValue, 227 - valueWidth, 98, colors.ink)
    end
    if mon.expProgress then
      self:expBar(99, 103, barWidth, mon.expProgress)
    elseif mon.expText then
      self:partyInfo(mon.expText, 99, 98, colors.ink, barWidth, "right")
    end
  end

  function H:summaryStats(mon)
    local colors = self.colors
    self:panel(6, 118, 228, 92, false, nil, colors.blueLight)
    self:label(mon.statsTitle or translate("BATTLE STATS"), 12, 121, colors.ink)
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
          self:partyInfo(self:fitPartyInfo(entry.label, 61), x, y,
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
    self:panel(6, 34, 228, 25, false, nil,
      self:typeColor(mon.types and mon.types[1]))
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
    self:partyInfo(mon.hpLabel or translate("HP"), 36, 47, colors.green)
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

  function H:summaryMoveRow(move, x, y, selected, interactive, showChevron)
    local colors = self.colors
    if showChevron == nil then showChevron = interactive end
    local pressed = self:beginPress(x, y, 228, 34, interactive)
    self:panel(x, y, 228, 34, interactive and selected,
      self:typeColor(move.type), self:typeColor(move.type))
    self:moveTypeBadge(move, x + 8, y + 12)
    self:partyName(move.name or "-", x + 64, y + 4, colors.ink, 88)
    self:partyInfo(move.ppLabel or translate("PP"), x + 157, y + 4, colors.green)
    self:partyInfo(move.ppText or "--", x + 177, y + 4,
      colors.ink, 35, "right")
    if showChevron then self:detailChevron(x + 217, y + 6, colors.ink) end
    self:partyInfo(move.powerLabel or translate("PWR"), x + 64, y + 18,
      colors.green)
    local power = move.powerText
    if not power or power == "--" then
      box("fill", x + 101, y + 23, 7, 1, colors.ink)
    else
      self:partyInfo(power, x + 90, y + 18,
        colors.ink, 26, "right")
    end
    self:partyInfo(move.accuracyLabel or translate("ACC"), x + 126, y + 18,
      colors.green)
    self:partyInfo(move.accuracyText or "--", x + 153, y + 18,
      colors.ink, 32, "right")
    self:endPress(pressed)
  end

  function H:moveLearnList(model)
    local colors = self.colors
    local details = model.details == true
    self:summaryMoveRow(model.newMove or {}, 6, 33, false,
      details, details)
    self:partyType(self:fitPartyType(translate("NEW"), 48),
      14, 35, colors.amber, 48)
    for slot = 1, 4 do
      local move = model.moves and model.moves[slot] or {}
      self:summaryMoveRow(move, 6, 70 + (slot - 1) * 35,
        model.index == slot, move.available ~= false,
        details and move.available ~= false)
    end
  end

  function H:moveLearnPrompt(model)
    local colors = self.colors
    local mon = model.mon or {}
    self:panel(6, 33, 228, 55, false, nil, self:typeColor(mon.type))
    self:partyPortrait(13, 36, false, false)
    if model.drawPokemon then model.drawPokemon(mon, 14, 39, 34) end
    self:partyName(mon.name or translate("POKEMON"), 57, 41, colors.ink, 122)
    self:partyInfo(mon.levelText or "L--", 186, 41,
      colors.ink, 38, "right")
    self:typeBadges(mon, 57, 64, false)

    self:summaryMoveRow(model.newMove or {}, 6, 94, false,
      model.details == true, model.details == true)
    self:partyType(self:fitPartyType(translate("NEW"), 48),
      14, 96, colors.amber, 48)
    if model.choices then
      for index, label in ipairs(model.choices) do
        local x = index == 1 and 27 or 123
        local selected = model.choice == index
        local pressed = self:beginPress(x, 145, 90, 40)
        self:panel(x, 145, 90, 40, selected, nil, colors.greenLight)
        self:partyInfo(translate(label), x + 7, 160,
          selected and colors.ink or colors.green, 76, "center")
        self:endPress(pressed)
      end
    else
      self:panel(27, 145, 186, 40, false, nil, colors.greenLight)
      self:partyInfo(self:fitPartyInfo(translate("FOLLOW TOP SCREEN"), 170),
        35, 160, colors.green, 170, "center")
    end
  end

  function H:moveLearnChoiceHit(x, y)
    if y < 145 or y >= 185 then return nil end
    if x >= 27 and x < 117 then return 1 end
    if x >= 123 and x < 213 then return 2 end
  end

  function H:moveLearnHit(x, y, selecting)
    if x < 6 or x >= 234 then return nil end
    if not selecting then
      if y >= 94 and y < 128 then return "new", 0 end
      return nil
    end
    if y >= 33 and y < 67 then return "new", 0 end
    for slot = 1, 4 do
      local top = 70 + (slot - 1) * 35
      if y >= top and y < top + 34 then
        return x >= 210 and "info" or "move", slot
      end
    end
  end

  function H:summaryMoves(mon, drawPortrait)
    self:summaryIdentity(mon, drawPortrait)
    for slot = 1, 4 do
      local move = mon.moves[slot] or {}
      local interactive = mon.moveDetails and move.available
      self:summaryMoveRow(move, 6, 63 + (slot - 1) * 37,
        interactive and mon.moveIndex == slot, interactive)
    end
  end

  function H:summaryTrainerMemo(mon)
    local colors = self.colors
    self:panel(6, 63, 228, 62, false, nil, colors.blueLight)
    self:partyInfo(mon.memoTitle or translate("TRAINER MEMO"), 17, 68, colors.green)
    box("fill", 16, 82, 208, 1, colors.band)
    self:partyInfo(mon.otLabel or translate("ORIGINAL TRAINER"), 17, 88, colors.green)
    self:partyName(mon.otText or "---", 17, 101, colors.ink, 109)
    box("fill", 136, 86, 1, 31, colors.bandLight)
    self:partyInfo(mon.idLabel or translate("ID NO."), 146, 88, colors.green)
    self:partyName(mon.idText or "00000", 146, 101, colors.ink, 77)
  end

  function H:summaryGrowthMemo(mon)
    local colors = self.colors
    self:panel(6, 130, 228, 80, false, nil, colors.exp)
    self:partyInfo(mon.growthTitle or translate("GROWTH RECORD"), 17, 135,
      colors.green)
    box("fill", 16, 149, 208, 1, colors.band)
    self:partyInfo(mon.totalExpLabel or translate("TOTAL EXP"), 17, 156,
      colors.green)
    self:label(mon.experienceText or "0", 17, 169, colors.ink)
    box("fill", 124, 153, 1, 39, colors.bandLight)
    self:partyInfo(mon.nextLevelLabel or translate("NEXT LEVEL"), 134, 156,
      colors.green)
    self:label(mon.nextLevelText or "MAX", 134, 169, colors.ink)
    self:partyInfo(mon.nextExpLabel or translate("TO NEXT"), 17, 193, colors.green)
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
      local move = mon.moves[slot] or {}
      local interactive = mon.moveDetails and move.available
      self:summaryMoveRow(move, 6, 63 + (slot - 1) * 37,
        interactive and mon.moveIndex == slot, interactive)
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
    self:partyInfo(mon.hpLabel or translate("HP"), mix(72, 36), mix(79, 47),
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
      self:partyInfo(mon.infoLabel or translate("ITEM"), 121, 66, colors.green)
      self:partyInfo(mon.infoText or "---", 151, 66, colors.ink,
        76, "right")
    end
    self:summaryExperience(mon)
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
      local move = mon.moves[slot] or {}
      local interactive = mon.moveDetails and move.available
      self:summaryMoveRow(move, 6, 63 + (slot - 1) * 37,
        interactive and mon.moveIndex == slot, interactive)
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
