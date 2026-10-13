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
    mutedInk = { 0.30, 0.39, 0.33, 1 },
    disabledInk = { 0.38, 0.45, 0.40, 1 },
    outline = { 0.08, 0.14, 0.12, 1 },
    statusInk = { 0.08, 0.14, 0.12, 1 },
    shadow = { 0.08, 0.14, 0.12, 0.18 },
    frame = { 0.30, 0.44, 0.37, 1 },
    highlight = { 0.97, 0.99, 0.99, 1 },
    white = { 0.97, 0.99, 0.99, 1 },
    silver = { 0.82, 0.86, 0.83, 1 },
    silverDark = { 0.40, 0.48, 0.43, 1 },
    surface = { 0.97, 0.985, 0.96, 1 },
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
    partyBg = { 0.925, 0.955, 0.94, 1 },
    partyBand = { 0.86, 0.93, 0.88, 1 },
    partyEmboss = { 0.82, 0.90, 0.85, 1 },
  }
  local darkColors = {
    bg = { 0.055, 0.085, 0.09, 1 },
    band = { 0.14, 0.27, 0.23, 1 },
    bandLight = { 0.09, 0.16, 0.15, 1 },
    ink = { 0.91, 0.96, 0.93, 1 },
    mutedInk = { 0.68, 0.76, 0.72, 1 },
    disabledInk = { 0.52, 0.61, 0.56, 1 },
    outline = { 0.02, 0.035, 0.03, 1 },
    statusInk = { 0.04, 0.07, 0.06, 1 },
    shadow = { 0.00, 0.01, 0.01, 0.36 },
    frame = { 0.27, 0.43, 0.37, 1 },
    highlight = { 0.18, 0.30, 0.25, 1 },
    white = { 0.96, 0.99, 0.98, 1 },
    silver = { 0.68, 0.76, 0.72, 1 },
    silverDark = { 0.20, 0.27, 0.25, 1 },
    surface = { 0.075, 0.13, 0.115, 1 },
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
    partyEmboss = { 0.075, 0.145, 0.125, 1 },
  }
  local BACKDROP_CENTER_Y = 121
  local H = {
    palette = lightPalette,
    colors = lightColors,
    nativeFocus = ui.nativeFocus ~= false,
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

  function H:setTouch(x, y, enabled)
    self.touchX, self.touchY = tonumber(x), tonumber(y)
    self.touchEnabled = enabled ~= false
  end

  function H:isPressed(x, y, w, h, enabled, scale)
    if enabled == false or self.touchEnabled == false or self.pressActive
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
  local function hgssFont(source, size)
    -- Production fonts are pre-rasterized image fonts, so every backend gets
    -- the same source pixels. Headless test hosts fall back to a system font.
    local font = source or ui.graphics.newFont(size, "mono")
    font:setFilter("nearest", "nearest")
    return font
  end
  local partyFont = hgssFont(ui.font, 10)
  local partyNameFont = hgssFont(ui.smallFont or ui.font, 11)
  local partyInfoFont = partyNameFont
  local partyTypeFont = partyInfoFont
  local trainerNameFont = partyFont
  local trainerValueFont = partyInfoFont
  local trainerNumberFont = hgssFont(ui.largeFont, 20)

  local function fontWidth(font, value)
    if ui.translationFonts then return ui.translationFonts:width(font, value) end
    return font:getWidth(tostring(value or ""))
  end
  local function printFont(font, value, x, y, width, align)
    if ui.translationFonts then return ui.translationFonts:print(font, value, x, y, width, align) end
    local G, previous = ui.graphics, ui.graphics.getFont()
    G.setFont(font)
    if width then G.printf(tostring(value or ""), x, y, width, align or "left")
    else G.print(tostring(value or ""), x, y) end
    if previous then G.setFont(previous) end
  end

  function H:label(value, x, y, tint, width, align)
    ui.color(tint)
    printFont(partyFont, value, x, y, width, align)
  end

  function H:labelWidth(value)
    return fontWidth(partyFont, tostring(value))
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

  local function displayText(value)
    return tostring(value or ""):gsub("<PK><MN>", "PKMN")
  end

  local function fitFont(value, width, font)
    local chars = glyphs(displayText(value))
    if fontWidth(font, table.concat(chars)) <= width then
      return table.concat(chars)
    end
    repeat table.remove(chars) until #chars == 0
      or fontWidth(font, table.concat(chars) .. "…") <= width
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
          if fontWidth(font, first) <= width and fontWidth(font, second) <= width then
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
    value = displayText(value)
    local chars = glyphs(value)
    while fontWidth(partyNameFont, table.concat(chars)) > width
        and #chars > 0 do table.remove(chars) end
    local shown = table.concat(chars)
    if shown ~= value then
      while fontWidth(partyNameFont, shown .. "…") > width
          and #chars > 0 do
        table.remove(chars)
        shown = table.concat(chars)
      end
      shown = shown .. "…"
    end
    color(tint)
    printFont(partyNameFont, shown, x, y)
  end

  function H:partyInfo(value, x, y, tint, width, align)
    value = displayText(value)
    ui.color(tint)
    printFont(partyInfoFont, value, x, y, width, align)
  end

  function H:partyInfoWidth(value, context)
    if context and ui.translationFonts then
      local font = ui.translationFonts:select(partyInfoFont, displayText(context))
      return font:getWidth(displayText(value))
    end
    return fontWidth(partyInfoFont, displayText(value))
  end

  function H:fitPartyInfo(value, width)
    return fitFont(value, width, partyInfoFont)
  end

  function H:splitPartyInfo(value, width)
    value = displayText(value)
    if fontWidth(partyInfoFont, value) <= width then return value end
    local bestFirst, bestSecond, bestBalance
    for cut = 1, #value do
      if value:sub(cut, cut):match("%s") then
        local first = value:sub(1, cut - 1):gsub("%s+$", "")
        local second = value:sub(cut + 1):gsub("^%s+", "")
        if first ~= "" and second ~= ""
            and fontWidth(partyInfoFont, first) <= width
            and fontWidth(partyInfoFont, second) <= width then
          local balance = math.abs(fontWidth(partyInfoFont, first)
            - fontWidth(partyInfoFont, second))
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
    local shown = displayText(value)
    ui.color(tint)
    printFont(partyTypeFont, shown, x + math.floor((width - fontWidth(partyTypeFont, shown))
      / 2 + 0.5), y)
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

  -- A selected tab describes the open page, independently of native focus.
  -- Center the label and optional detail arrow together, with the same inset
  -- above the active rail in both themes.

  return H, {
    BACKDROP_CENTER_Y = BACKDROP_CENTER_Y,
    battleButtonShape = battleButtonShape,
    border = border,
    box = box,
    clipped = clipped,
    color = color,
    displayText = displayText,
    fit = fit,
    fitFont = fitFont,
    fontWidth = fontWidth,
    format = format,
    glyphs = glyphs,
    mixed = mixed,
    partyInfoFont = partyInfoFont,
    partyNameFont = partyNameFont,
    partyTypeFont = partyTypeFont,
    pokeballBackdrop = pokeballBackdrop,
    pokeballEmboss = pokeballEmboss,
    printFont = printFont,
    runnerOutline = runnerOutline,
    runnerParts = runnerParts,
    splitFont = splitFont,
    text = text,
    trainerNameFont = trainerNameFont,
    trainerNumberFont = trainerNumberFont,
    trainerValueFont = trainerValueFont,
    translate = translate,
  }
end
