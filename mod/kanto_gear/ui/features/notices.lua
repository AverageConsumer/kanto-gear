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

  -- The same three row rectangles and pager bounds drive drawing and input.
  function H:noticeHistoryRowAt(x, y, model)
    if x < 6 or x >= 234 then return end
    for index in ipairs(model.rows) do
      local top = (model.shade and 45 or 50) + (index - 1) * (model.shade and 46 or 48)
      if y >= top and y < top + (model.shade and 41 or 43) then return index end
    end
  end

  function H:noticeHistoryHit(x, y, model)
    local pagerY = model.shade and 188 or 196
    if y < 29 and x < 27 then return "back" end
    if y >= pagerY and y < pagerY + 17 then
      if x >= 6 and x < 34 and model.page > 1 then return "prev" end
      if x >= 206 and x < 234 and model.page < model.pages then return "next" end
    end
    local index = self:noticeHistoryRowAt(x, y, model)
    if index and model.rows[index].enabled then return "row", index end
  end

  function H:noticeHistory(model)
    local c = self.colors
    local top, step, height, pagerY = model.shade and 45 or 50, model.shade and 46 or 48,
      model.shade and 41 or 43, model.shade and 188 or 196
    self:partyInfoCentered(translate("OLDEST FIRST"), 6, model.shade and 28 or 33, 228, 14, c.mutedInk)
    if #model.rows == 0 then
      local h = model.shade and 133 or 139
      self:v4MessageWindow(6, top, 228, h)
      self:partyInfoCentered(translate("NO NOTIFICATIONS YET"), 12, top, 216, h, c.mutedInk)
    end
    for index, row in ipairs(model.rows) do
      local entry, y = row.entry, top + (index - 1) * step
      local offset = model.rowOffsets and model.rowOffsets[index] or 0
      if offset ~= 0 then
        self:partyInfoCentered(translate("READ"), 6, y, 228, height, c.green)
        G.push("all"); G.translate(math.floor(offset + 0.5), 0)
      end
      local pressed = self:beginPress(6, y, 228, height, row.enabled)
      self:v4Window(6, y, 228, height, { radius = self:isCGear() and 3 or 5 })
      local icon = entry.icon or "c_notifications"
      if self:v4HasIcon(icon) then self:v4Icon(icon, 13, y + math.floor((height - 24) / 2)) end
      self:partyInfo(row.timestamp, 44, y + 3, c.mutedInk)
      self:partyInfo(self:fitPartyInfo(entry.title, 182), 44, y + 15,
        entry.tone == "special" and c.amber or c.ink)
      self:partyInfo(self:fitPartyInfo(entry.detail or "", 182), 44, y + 27, c.mutedInk)
      self:endPress(pressed)
      if offset ~= 0 then G.pop() end
    end
    for _, button in ipairs({ { x = 6, label = "<", enabled = model.page > 1 },
        { x = 206, label = ">", enabled = model.page < model.pages } }) do
      local pressed = self:beginPress(button.x, pagerY, 28, 17, button.enabled)
      self:v4Window(button.x, pagerY, 28, 17, { shadow = false })
      self:partyInfoCentered(button.label, button.x, pagerY, 28, 17,
        button.enabled and c.ink or c.disabledInk)
      self:endPress(pressed)
    end
    self:partyInfoCentered(model.page .. "/" .. model.pages, 40, pagerY, 160, 17, c.ink)
  end

  function H:noticeShadeHandle(y, open)
    G.setColor(self.colors.mutedInk)
    G.rectangle("fill", open and 104 or 111, y, open and 32 or 18, open and 3 or 2)
  end
end
