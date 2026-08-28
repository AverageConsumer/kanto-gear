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
      selected = { 0.91, 0.31, 0.25, 1 },
      selectedDark = { 0.59, 0.12, 0.11, 1 },
      fainted = { 0.25, 0.33, 0.28, 1 },
    },
    battleActions = {
      [1] = { x = 22, y = 25, w = 116, h = 62, color = "red" },
      [2] = { x = 107, y = 92, w = 49, h = 38, color = "green" },
      [3] = { x = 4, y = 92, w = 49, h = 38, color = "amber" },
      [4] = { x = 57, y = 104, w = 46, h = 28, color = "blue" },
    },
  }

  local box, text, fit, glyphs, color =
    ui.box, ui.text, ui.fit, ui.glyphs, ui.color
  local partyFont = ui.font and ui.graphics.newFont(ui.font, 11)
    or ui.graphics.newFont(11)
  local partyNameFont = ui.font and ui.graphics.newFont(ui.font, 9)
    or ui.graphics.newFont(9)
  local partyInfoFont = ui.font and ui.graphics.newFont(ui.font, 9)
    or ui.graphics.newFont(9)
  partyFont:setFilter("linear", "linear")
  partyNameFont:setFilter("linear", "linear")
  partyInfoFont:setFilter("linear", "linear")

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
      local dark = outlined and colors.ink or colors.amber
      local light = outlined and colors.ink or colors.amberLight
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
        light = outlined and colors.ink or colors.blueLight
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
    local iconWidth = period and 12 or 0
    local textWidth = self:labelWidth(value)
    local x = left + math.floor((width - textWidth - iconWidth) / 2)
    self:label(value, x, y, self.colors.ink)
    if iconWidth > 0 then
      self:periodIcon(period, x + textWidth + 3, y + 3)
    end
  end

  function H:battery(x, y, segments, visible, tint)
    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    tint = tint or self.colors.ink
    box("fill", x + 2, y, 14, 1, tint)
    box("fill", x + 2, y + 10, 14, 1, tint)
    box("fill", x, y + 2, 1, 7, tint)
    box("fill", x + 17, y + 2, 1, 7, tint)
    box("fill", x + 1, y + 1, 1, 1, tint)
    box("fill", x + 16, y + 1, 1, 1, tint)
    box("fill", x + 1, y + 9, 1, 1, tint)
    box("fill", x + 16, y + 9, 1, 1, tint)
    box("fill", x + 18, y + 4, 2, 3, tint)
    if visible then
      for segment = 0, segments - 1 do
        box("fill", x + 3 + segment * 4, y + 3, 3, 5, tint)
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

  function H:genderIcon(gender, x, y)
    local G = ui.graphics
    local function paint(tint, width)
      color(tint)
      G.setLineWidth(width)
      if gender == "male" then
        G.circle("line", x + 2.5, y + 4.5, 2)
        G.line(x + 4, y + 3, x + 7, y)
        G.line(x + 5, y, x + 7, y, x + 7, y + 2)
      elseif gender == "female" then
        G.circle("line", x + 3.5, y + 2.5, 2)
        G.line(x + 3.5, y + 4.5, x + 3.5, y + 8)
        G.line(x + 1.5, y + 6.5, x + 5.5, y + 6.5)
      end
    end
    paint(self.colors.ink, 2)
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

  function H:headerBar(title, back, paged)
    local colors = self.colors
    box("fill", 0, 0, 240, 30, colors.bandLight)
    box("fill", 0, 0, 240, 2, colors.white)
    clipped(5, 4, 232, 21, colors.shadow)
    clipped(4, 3, 232, 21, colors.surface)
    box("fill", 6, 5, 228, 2, colors.white)
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

  function H:partyBackdrop()
    local G = ui.graphics
    color({ 0.90, 0.95, 0.91, 1 })
    G.rectangle("fill", 0, 28, 240, 188)
    color({ 0.80, 0.90, 0.84, 1 })
    G.circle("fill", 232, 102, 72)
    G.circle("fill", 2, 202, 62)
    color({ 0.86, 0.93, 0.88, 1 })
    G.circle("fill", 232, 102, 54)
    G.circle("fill", 2, 202, 45)
  end

  function H:partyPanel(x, y, w, h, selected, typeId, type2, fainted)
    local G, colors = ui.graphics, self.colors
    local accent, secondary = self:typeColor(typeId), self:typeColor(type2 or typeId)
    color(colors.shadow)
    G.rectangle("fill", x + 1, y + 2, w, h, 6, 6)
    color(fainted and colors.fainted
      or selected and colors.selected or colors.party)
    G.rectangle("fill", x, y, w, h, 6, 6)
    color(selected and colors.selectedDark or colors.partyDark)
    G.setLineWidth(selected and 2 or 1)
    G.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 6, 6)
    G.setLineWidth(1)
    local shade = fainted and 0.55 or 1
    color(colors.ink)
    G.rectangle("fill", x + 4, y + 6, 2, 1)
    G.rectangle("fill", x + 3, y + 7, 4, 39)
    G.rectangle("fill", x + 4, y + 46, 2, 1)
    G.setColor(accent[1] * shade, accent[2] * shade,
      accent[3] * shade, 1)
    G.rectangle("fill", x + 4, y + 7, 2, 19)
    G.setColor((accent[1] + secondary[1]) / 2 * shade,
      (accent[2] + secondary[2]) / 2 * shade,
      (accent[3] + secondary[3]) / 2 * shade, 1)
    G.rectangle("fill", x + 4, y + 26, 2, 1)
    G.setColor(secondary[1] * shade, secondary[2] * shade,
      secondary[3] * shade, 1)
    G.rectangle("fill", x + 4, y + 27, 2, 19)
  end

  function H:partyPortrait(x, y, selected, typeId)
    local G, accent = ui.graphics, self:typeColor(typeId)
    color(self.colors.redLight)
    G.circle("fill", x + 17, y + 20, 17)
    color(self.colors.white)
    G.arc("fill", x + 17, y + 20, 16, 0, math.pi)
    color(selected and self.colors.selectedDark or self.colors.partyDark)
    G.line(x + 1, y + 20, x + 33, y + 20)
    color(self.colors.white)
    G.circle("fill", x + 17, y + 20, 4)
    color(selected and self.colors.selectedDark or self.colors.partyDark)
    G.circle("line", x + 17, y + 20, 4)
    G.circle("line", x + 17, y + 20, 17)
  end

  function H:partyPosition(slot)
    local index = slot - 1
    local col, row = index % 2, math.floor(index / 2)
    return 5 + col * 118, 32 + row * 58 + (col == 1 and 4 or 0)
  end

  function H:partyCard(mon, x, y, selected, details, drawPortrait)
    local fainted = mon and (mon.statusId == "FNT" or mon.status == "FNT"
      or mon.hp ~= nil and mon.hp <= 0)
    self:partyPanel(x, y, 112, 56, selected, mon and mon.type,
      mon and mon.type2, fainted)
    if not mon then
      self:label("-", x, y + 18, self.colors.ink, 112, "center")
      return
    end
    self:partyPortrait(x + 8, y + 6, selected, mon.type)
    drawPortrait(mon, x + 9, y + 10, 32, fainted)
    local ink = self.colors.white
    local quiet = selected and self.colors.white or self.colors.silver
    self:partyName(mon.name, x + 45, y + 4, ink, details and 57 or 64)
    if details then self:label(">", x + 102, y + 1, ink) end
    if mon.egg then return end
    if mon.gender == "male" then
      self:genderIcon("male", x + 99, y + 19)
    elseif mon.gender == "female" then
      self:genderIcon("female", x + 99, y + 19)
    end
    self:partyInfo(mon.levelText, x + 45, y + 17, quiet)
    if mon.status then
      self:partyInfo(fit(mon.status, 3), x + 69, y + 17,
        self:statusColor(mon.statusId or mon.status))
    end
    self:partyInfo("HP", x + 45, y + 27, quiet)
    self:partyInfo(mon.hpText, x + 45, y + 27, quiet, 62, "right")
    self:hpBar(x + 45, y + 38, 62, mon.hp, mon.maxHp)
    self:partyInfo("EXP", x + 45, y + 41, quiet)
    self:expBar(x + 65, y + 46, 42, mon.expProgress)
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
    box("fill", x, y, w, 5, self.colors.ink)
    box("fill", x + 1, y + 1, w - 2, 3, self.colors.silver)
    box("fill", x + 1, y + 1, math.floor((w - 2) * ratio), 3,
      ratio > 0.5 and self.colors.hp
        or ratio > 0.2 and self.colors.hpMid or self.colors.hpLow)
  end

  function H:expBar(x, y, w, ratio)
    ratio = math.max(0, math.min(1, ratio or 0))
    box("fill", x, y, w, 4, self.colors.ink)
    box("fill", x + 1, y + 1, w - 2, 2, self.colors.silverDark)
    box("fill", x + 1, y + 1, math.floor((w - 2) * ratio), 2,
      self.colors.exp)
  end

  return H
end
