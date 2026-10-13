return function(H, ui, draw, icons)
  local border, box, clipped, color =
    draw.border, draw.box, draw.clipped, draw.color
  local fontText, mixed, trainerFit, trainerNameFont =
    icons.fontText, draw.mixed, icons.trainerFit, draw.trainerNameFont
  local translate = draw.translate
  function H:trainer(model)
    local G, colors = ui.graphics, self.colors
    local quiet = colors.mutedInk
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
    fontText(trainerNameFont, name, 64, 38, colors.ink, 158, "center")
    local region = self:fitPartyType(model.region or "KANTO", 158)
    self:partyType(region, 64, 56, blue, 158)
    clipped(64, 68, 76, 13, colors.bandLight)
    border(64, 68, 76, 13, colors.blue)
    self:partyInfoCentered(self:fitPartyInfo(model.idText or "ID -----", 72),
      64, 68, 76, 13, colors.ink)
    clipped(145, 68, 76, 13,
      mixed(colors.surface, colors.amberLight, self.dark and 0.20 or 0.12))
    border(145, 68, 76, 13, colors.amber)
    self:partyInfoCentered(model.badgeText or "0/8", 145, 68, 76, 13, colors.ink)

    if model.kind == "records" then
      self:homeTile(7, 92, 226, 119, colors.blue, false)
      if #model.records == 0 then
        self:partyInfoCentered(self:fitPartyInfo(translate("NO RECORDS YET"), 208), 13, 92, 214, 119, quiet)
      end
      local top = 92 + math.floor((119 - (#model.records * 19 - 2)) / 2)
      for index, row in ipairs(model.records) do
        local y = top + (index - 1) * 19
        if index > 1 then box("fill", 13, y - 2, 214, 1, colors.band) end
        self:partyType(self:fitPartyType(row.label, 119), 13, y + 4, quiet, 119)
        self:partyInfoCentered(self:fitPartyInfo(row.value, 95), 132, y, 95, 17, colors.ink)
      end
      return
    end
    if model.kind == "badges" then
      for index = 1, 8 do
        local x, y = 7 + ((index - 1) % 4) * 58, 92 + math.floor((index - 1) / 4) * 62
        self:homeTile(x, y, 52, 57, colors.amber, false)
        local cx, cy = x + 26, y + 21
        color(model.badgeOwned[index] and colors.bandLight or colors.silverDark)
        G.circle("fill", cx, cy, 14)
        color(colors.outline); G.circle("line", cx, cy, 14)
        local drawn = model.drawBadge and model.drawBadge(index, cx, cy, model.badgeOwned[index])
        if not drawn then
          color(model.badgeOwned[index] and colors.amberLight or colors.silver)
          G.circle("fill", cx, cy, 4)
          color(colors.outline); G.circle("line", cx, cy, 4)
        end
        self:partyType(self:fitPartyType(model.badgeNames[index], 46), x + 3, y + 41,
          model.badgeOwned[index] and amber or quiet, 46)
      end
      return
    end

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

  function H:stepsHit(x, y)
    local hx, hy = x * 1.5, y * 1.5
    return hx >= 54 and hx < 186 and hy >= 165 and hy < 203
      and "reset" or nil
  end

end
