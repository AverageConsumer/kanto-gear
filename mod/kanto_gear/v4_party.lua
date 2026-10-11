-- Kanto Gear v4: party cards, summary seat and team motion.
return function(H, ui, K)
  local floor, max, min = math.floor, math.max, math.min
  local R, P, RR, RRrows, CH, CHrows = K.R, K.P, K.RR, K.RRrows, K.CH, K.CHrows
  local CIRC, RING, ART = K.CIRC, K.RING, K.ART
  local mix, hex = K.mix, K.hex
  local cg, WHITE = K.cg, K.WHITE
  local translate = function(value) return ui.translate and ui.translate(value) or value end

  -- Two even columns, three rows; same 112×56 card contract as before.
  function H:partyPosition(slot)
    local index = slot - 1
    local col, row = index % 2, floor(index / 2)
    return 6 + col * 116, 32 + row * 58
  end

  local function hpRatio(mon)
    if not mon or not mon.maxHp then return 1 end
    return max(0, min(1, (mon.hp or 0) / max(1, mon.maxHp)))
  end

  -- Gen 4/5 party icons hop; faster at full health, slower when hurt,
  -- still when fainted or asleep.
  function H:v4Hop(mon, seed)
    if not mon or self.motionEnabled == false then return 0 end
    local ratio = hpRatio(mon)
    if ratio <= 0 or mon.statusId == "SLP" or mon.statusId == "FNT" or mon.egg then return 0 end
    local period = ratio > 0.5 and 0.28 or ratio > 0.2 and 0.5 or 0.8
    self:wantAmbient(period)
    return floor(self:clock() / period + (seed or 0)) % 2
  end

  local function slotColors(self, selected, fainted)
    if cg(self) then return nil end
    if fainted then
      return { L = hex("c88078"), M = hex("a85e58"), D = hex("6a3430"), Hi = hex("e8b0a8"), low = hex("985050") }
    end
    if selected then
      return { L = hex("f8b858"), M = hex("f09838"), D = hex("985010"), Hi = hex("f8e0a0"), low = hex("e08428") }
    end
    local s = self.tok.slot
    return { L = s.L, M = s.M, D = s.D, Hi = s.Hi, low = self.tok.slotLow }
  end

  function H:partyPanel(x, y, w, h, selected, fainted, focused)
    local colors = self.colors
    if cg(self) then
      if self:shadowVisible() then CH(x + 2, y + 2, w, h, 5, colors.shadow) end
      CH(x, y, w, h, 5, selected and self.tok.acc.M or self.tok.border)
      local fill = fainted and colors.fainted or selected and colors.focus or colors.surface
      CH(x + 1, y + 1, w - 2, h - 2, 4, fill)
      local stripe = fainted and hex("c05050") or selected and self.tok.acc.M or self.tok.line
      for j = 0, 8 do R(x + w - 22 + j, y + 1 + j, 18 - j, 1, stripe) end
      if focused == nil then focused = selected end
      if focused then self:focusFrame(x, y, w, h) end
      return
    end
    local c = slotColors(self, selected, fainted)
    if self:shadowVisible() then RR(x + 2, y + 2, w, h, 5, colors.shadow) end
    RR(x, y, w, h, 5, colors.outline)
    RR(x + 1, y + 1, w - 2, h - 2, 4, c.D)
    RRrows(x + 1, y + 1, w - 2, h - 2, 4, 0, 26, c.L)
    RRrows(x + 1, y + 1, w - 2, h - 2, 4, 26, h - 4, c.low)
    R(x + 4, y + 1, w - 8, 1, c.Hi)
    R(x + 45, y + 27, w - 48, 1, c.D)
    local G = ui.graphics
    K.setc({ 1, 1, 1, 0.10 })
    for k = 0, 3 do
      local sx = x + 58 + k * 14
      for j = 0, 23 do
        local px = sx - j
        if px > x + 44 and px < x + w - 2 then G.rectangle("fill", px, y + 2 + j, 1, 1) end
      end
    end
    if focused == nil then focused = selected end
    if focused then self:focusFrame(x, y, w, h) end
  end

  function H:partyCard(mon, x, y, selected, details, drawPortrait, focused, emptyTarget, interactive)
    local colors = self.colors
    local fainted = mon and not mon.egg and (mon.statusId == "FNT" or mon.hp ~= nil and mon.hp <= 0)
    local pressed = self:beginPress(x, y, 112, 56,
      interactive ~= false and (mon ~= nil or emptyTarget))
    if focused == nil then focused = selected end
    if not mon then
      local c = cg(self) and self.tok.border or colors.silverDark
      if cg(self) then CH(x, y, 112, 56, 5, c); CH(x + 1, y + 1, 110, 54, 4, colors.bandLight)
      else RR(x, y, 112, 56, 5, c); RR(x + 1, y + 1, 110, 54, 4, colors.bandLight) end
      if emptyTarget then
        R(x + 51, y + 26, 11, 3, c); R(x + 55, y + 22, 3, 11, c)
      else
        R(x + 51, y + 27, 11, 1, c)
      end
      if focused then self:focusFrame(x, y, 112, 56) end
      self:endPress(pressed)
      return
    end
    self:partyPanel(x, y, 112, 56, selected, fainted, focused)
    local ink = cg(self) and colors.ink or WHITE
    local quiet = cg(self) and colors.mutedInk or WHITE
    -- portrait
    self:v4Seat(x + 4, y + 4, 38, fainted, selected)
    local hop = self:v4Hop(mon, (mon.slot or 0) * 0.37)
    drawPortrait(mon, x + 7, y + 7 - hop, 32, fainted)
    -- held item / mail marker on the seat, like the DS party screen
    if mon.heldItem then
      local art = mon.heldItem.mail
        and { "oooooooo", "owwwwwwo", "oowwwwoo", "owowwowo", "owwoowwo", "oooooooo" }
        or { "..oooo..", ".oyyyyo.", "oywyyyyo", "oyyyyyyo", "oyyyyddo", ".oyyddo.", "..oooo.." }
      ART(art, x + 33, y + 34 - #art + 7, { o = colors.outline, w = WHITE, y = hex("f8d048"), d = hex("d09820") })
    end
    if mon.statusId == "SLP" then
      local t = self:clock()
      self:wantAmbient(0.12)
      for k = 0, 2 do
        local p = (t / 1.4 + k / 3) % 1
        if p < 0.9 then
          ART({ "###", "..#", ".#.", "#..", "###" }, x + 32 + k,
            y + 18 - floor(p * 16), { ["#"] = p < 0.6 and WHITE or colors.silver })
        end
      end
    elseif mon.statusId == "PAR" and (self:clock() % 1.7) < 0.14 then
      ART({ ".#.", "###", ".#." }, x + 34, y + 9, { ["#"] = hex("f8e070") })
      self:wantAmbient(0.2)
    end
    -- name row
    self:partyName(mon.name, x + 46, y + 2, ink, details == true and 56 or 62)
    if details == true then
      -- Centre the glyph in the C-Gear corner stripe, including its sloped edge.
      self:detailChevron(x + (cg(self) and 100 or 105), y + (cg(self) and 3 or 6), ink)
    end
    if mon.egg then self:endPress(pressed); return end
    self:typeBadges(mon, x + 1, y + 45, fainted)
    -- level / status / gender
    self:partyInfo(mon.levelText, x + 46, y + 13, quiet)
    if mon.statusId then self:v4StatusPill(mon.statusId, x + 69, y + 16) end
    if mon.gender == "male" or mon.gender == "female" then
      self:genderIcon(mon.gender, x + 100, y + 16)
    end
    -- HP block
    self:v4HpBar(x + 46, y + 29, 61, mon.hp, mon.maxHp)
    self:partyInfo(mon.hpText, x + 46, y + 35, ink, 61, "right")
    self:expBar(x + 46, y + 49, 61, mon.expProgress)
    self:endPress(pressed)
  end
end
