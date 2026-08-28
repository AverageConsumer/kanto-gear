return function(ui)
  local H = {
    palette = {
      { 244, 248, 242 }, { 213, 231, 220 },
      { 75, 112, 94 }, { 25, 43, 36 },
    },
    colors = {
      bg = { 0.94, 0.97, 0.93, 1 },
      band = { 0.66, 0.82, 0.72, 1 },
      bandLight = { 0.84, 0.91, 0.86, 1 },
      ink = { 0.08, 0.14, 0.12, 1 },
      shadow = { 0.08, 0.14, 0.12, 0.28 },
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
    },
    battleActions = {
      [1] = { x = 22, y = 25, w = 116, h = 62, color = "red" },
      [2] = { x = 107, y = 92, w = 49, h = 38, color = "green" },
      [3] = { x = 4, y = 92, w = 49, h = 38, color = "amber" },
      [4] = { x = 57, y = 104, w = 46, h = 28, color = "blue" },
    },
  }

  local box, text, fit, glyphs = ui.box, ui.text, ui.fit, ui.glyphs
  local partyFont = ui.graphics.newFont(11)
  partyFont:setFilter("nearest", "nearest")

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
    box("fill", x + 2, y + 2, w - 4, 2, colors.white)
    border(x, y, w, h, selected and accent or colors.ink)
    if selected then box("fill", x, y + 4, 2, math.max(1, h - 8), accent) end
  end

  function H:button(x, y, w, h, label, selected)
    self:panel(x, y, w, h, selected, self.colors.blue)
    local shown = fit(label, math.floor((w - 8) / 6))
    text(shown, x + math.floor((w - #glyphs(shown) * 6) / 2),
      y + math.floor((h - 7) / 2), self.colors.ink)
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
    ui.color(colors.ink)
    G.circle("fill", x, y, 8)
    ui.color(selected and colors.redLight or colors.silverDark)
    G.circle("fill", x, y, 7)
    box("fill", x - 7, y, 14, 6, colors.white)
    box("fill", x - 7, y - 1, 14, 2, colors.ink)
    ui.color(colors.white)
    G.circle("fill", x, y, 3)
    ui.color(colors.ink)
    G.circle("line", x, y, 3)
  end

  function H:partyPanel(x, y, w, h, selected)
    local fill = selected and self.colors.bandLight or self.colors.surface
    clipped(x + 1, y + 1, w, h, self.colors.shadow)
    clipped(x, y, w, h, fill)
    box("fill", x + 38, y + 3, w - 41, 15,
      selected and self.colors.red or self.colors.green)
    box("fill", x + 38, y + 18, w - 41, 2,
      selected and self.colors.redLight or self.colors.greenLight)
    border(x, y, w, h, selected and self.colors.red or self.colors.silverDark)
    if selected then
      box("fill", x + 2, y + 4, 2, h - 8, self.colors.redLight)
    end
  end

  function H:partyPortrait(x, y, selected)
    clipped(x, y, 33, 39, self.colors.white)
    box("fill", x + 2, y + 2, 29, 3,
      selected and self.colors.redLight or self.colors.band)
    border(x, y, 33, 39, self.colors.silverDark)
  end

  function H:partySlot(x, y, count)
    local hx, hy = x * 1.5, y * 1.5
    local col = hx >= 120 and 1 or 0
    for row = 0, 2 do
      local top = 30 + row * 52 + (col == 1 and 7 or 0)
      local slot = row * 2 + col + 1
      if slot <= count and hy >= top and hy < top + 47 then return slot end
    end
  end

  function H:hpBar(x, y, w, hp, maxHp)
    local ratio = math.max(0, math.min(1, (hp or 0) / math.max(1, maxHp or 1)))
    box("fill", x, y, w, 5, self.colors.ink)
    box("fill", x + 1, y + 1, w - 2, 3, self.colors.silver)
    box("fill", x + 1, y + 1, math.floor((w - 2) * ratio), 3,
      ratio > 0.5 and self.colors.hp
        or ratio > 0.2 and self.colors.hpMid or self.colors.hpLow)
  end

  function H:expBar(x, y, w, ratio)
    ratio = math.max(0, math.min(1, ratio or 0))
    box("fill", x, y, w, 2, self.colors.ink)
    box("fill", x + 1, y, math.floor((w - 1) * ratio), 1, self.colors.exp)
  end

  return H
end
