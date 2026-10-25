-- The notice card and the unread dot. The card slides out from under the
-- header bar. Runtime and drawing share the animated card position.
return function(H, G, translate)
  local floor, max = math.floor, math.max
  local WHITE = { 1, 1, 1, 1 }

  -- Scissor in canvas pixels for a rectangle given in the current transform.
  local function clip(x, y, w, h)
    if not (G.transformPoint and G.intersectScissor) then return end
    local left, top = G.transformPoint(x, y)
    local right, bottom = G.transformPoint(x + w, y + h)
    G.intersectScissor(floor(left), floor(top), max(0, floor(right - left)), max(0, floor(bottom - top)))
  end

  -- view = { title, detail, species, shiny, icon, drawIcon, tone, presence (0..1), drawPokemon }
  function H:noticeBanner(view, x, y, w, h)
    local c = self.colors
    local special = view.tone == "special"
    local accent = special and (self.dark and c.amberLight or c.amber) or (self.dark and c.greenLight or c.green)
    local stripe = special and c.amber or c.green
    local p = max(0, math.min(1, view.presence or 1))
    -- Eased slide from behind the header; nothing paints above y - 3.
    local offset = floor((1 - p) ^ 2 * (h + 4) + 0.5)
    G.push("all")
    clip(0, y - 3, 240, 216 - (y - 3))
    G.translate(floor((view.offsetX or 0) + 0.5),
      view.offsetY and floor(view.offsetY + 0.5) or -offset)
    local pressed = self:beginPress(x, y, w, h, p >= 0.5 and not view.closing)
    self:v4Window(x, y, w, h, { radius = self:isCGear() and 3 or 5 })
    G.setColor(stripe); G.rectangle("fill", x + 2, y + 3, 3, h - 6)
    -- Icon: the shiny Pokemon itself, or the app's own mark.
    local iconX, iconY = x + 9, y + floor((h - 24) / 2)
    if view.drawIcon then
      view.drawIcon(x + 7, y + 2, h - 4)
    elseif view.species ~= nil and view.drawPokemon then
      view.drawPokemon(view.species, x + 7, y + 2, h - 4, view.shiny ~= false, false)
    elseif view.icon and self:v4HasIcon(view.icon) then
      self:v4Icon(view.icon, iconX, iconY)
    end
    local left, width = x + 38, w - 46
    local title = self:fitPartyInfo(view.title or "", width)
    if view.detail and view.detail ~= "" then
      self:partyInfo(title, left, y + 4, accent)
      self:partyInfo(self:fitPartyInfo(view.detail, width), left, y + 16, c.ink)
    else
      self:partyInfo(title, left, y + floor((h - 10) / 2) - 1, accent)
    end
    if special and H.shinySparkle then H.shinySparkle(self, x + w - 10, y + 8, false, 0) end
    self:endPress(pressed)
    G.pop()
  end

  -- Something new inside: a small red dot on the tile's upper right corner.
  function H:homeUnreadDot(x, y, w)
    local c = self.colors
    local dx, dy = x + w - 9, y + 3
    G.setColor(c.outline); G.rectangle("fill", dx + 1, dy, 4, 6); G.rectangle("fill", dx, dy + 1, 6, 4)
    G.setColor(c.red); G.rectangle("fill", dx + 1, dy + 1, 4, 4)
    G.setColor(WHITE); G.rectangle("fill", dx + 1, dy + 1, 1, 1)
  end
end
