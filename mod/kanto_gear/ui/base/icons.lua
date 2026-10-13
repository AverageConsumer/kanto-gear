return function(H, ui, draw)
  local box, clipped, color, fontWidth =
    draw.box, draw.clipped, draw.color, draw.fontWidth
  local glyphs, printFont, trainerValueFont, translate =
    draw.glyphs, draw.printFont, draw.trainerValueFont, draw.translate
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

  local function fontText(font, value, x, y, tint, width, align)
    color(tint)
    printFont(font, value, x, y, width, align)
  end

  local function trainerFit(font, value, width)
    local chars = glyphs(tostring(value or ""))
    while #chars > 1 and fontWidth(font, table.concat(chars)) > width do
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

  function H:trainerStat(x, label, value, kind, accent, width)
    local colors = self.colors
    local quiet = colors.mutedInk
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

  return {
    fontText = fontText,
    homeIconColors = homeIconColors,
    trainerFit = trainerFit,
    trainerStatIcon = trainerStatIcon,
  }
end
