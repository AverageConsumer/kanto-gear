return function(H, G, translate, format)
  local gold, goldLight, paper, ink = { .83, .57, .18, 1 },
    { 1, .85, .44, 1 }, { .92, .96, .85, 1 }, { .08, .21, .20, 1 }
  local function rect(x, y, w, h, tint)
    G.setColor(tint); G.rectangle("fill", x, y, w, h)
  end
  local function disc(x, y, r, tint)
    for dy = -r, r do
      local half = math.floor(math.sqrt(r * r - dy * dy))
      rect(x - half, y + dy, half * 2 + 1, 1, tint)
    end
  end
  function H:achievementSeal(cx, cy, r, kind, complete)
    local c, quiet = self.colors, self.dark and self.colors.silver or self.colors.silverDark
    disc(cx + 1, cy + 2, r, c.shadow)
    disc(cx, cy, r, complete and ink or quiet)
    disc(cx, cy, r - 1, complete and gold or c.band)
    disc(cx, cy, r - 3, complete and goldLight or c.surface)
    disc(cx, cy, r - 4, complete and ink or c.band)
    disc(cx, cy, r - 5, complete and paper or c.surface)
    G.push(); G.translate(cx, cy); G.scale(r / 24, r / 24)
    local tint = complete and ink or quiet
    if kind == "forest" then
      for _, tree in ipairs({ { -8, 1 }, { 8, 1 }, { 0, -7 } }) do
        local x, y = tree[1], tree[2]
        rect(x - 1, y + 5, 3, 6, tint)
        for row = 0, 4 do rect(x - row - 1, y + row * 2 - 5, row * 2 + 3, 2, tint) end
      end
    elseif kind == "cave" then
      for row = 0, 10 do rect(-row - 2, row - 8, row * 2 + 5, 2, tint) end
      rect(-4, -1, 9, 8, complete and paper or c.surface)
    else
      for row = -12, 10 do
        local x = row < -6 and 4 or row > 4 and -4 or 4 - math.floor((row + 6) * .8)
        rect(x - 4, row, 9, 1, tint)
        if (row + 12) % 6 < 3 then rect(x, row, 1, 1, complete and paper or c.surface) end
      end
      rect(-11, -6, 4, 5, tint); rect(-12, -4, 6, 1, tint)
      rect(9, 6, 4, 5, tint); rect(8, 8, 6, 1, tint)
    end
    G.pop()
    if complete and r >= 20 then
      rect(cx - 26, cy + 11, 53, 12, ink)
      rect(cx - 25, cy + 12, 51, 1, goldLight)
      self:partyType(self:fitPartyType(translate("EXPLORED"), 49),
        cx - 25, cy + 12, paper, 51)
    end
  end

  -- All hit regions are emitted by the same layout that paints them.
  function H:achievementsHit(x, y)
    for _, hit in ipairs(self.achievementHits or {}) do
      if x >= hit.x and x < hit.x + hit.w and y >= hit.y and y < hit.y + hit.h then
        return hit.action, hit.value
      end
    end
  end

  function H:achievements(model)
    local c = self.colors
    local accent, quiet = self.dark and c.greenLight or c.green,
      self.dark and c.silver or c.silverDark
    self.achievementHits = {}
    local function hit(x, y, w, h, action, value)
      self.achievementHits[#self.achievementHits + 1] = {
        x = x, y = y, w = w, h = h, action = action, value = value }
    end
    local function label(value, x, y, w, h, tint, small, align)
      if small then
        self:partyType(self:fitPartyType(value, w), x,
          y + math.floor((h - 7) / 2) - 1, tint or c.ink, w)
      else
        self:partyInfo(self:fitPartyInfo(value, w), x,
          y + math.floor((h - 8) / 2) - 2, tint or c.ink, w, align or "center")
      end
    end
    local function name(value, x, y, w, h, tint)
      local a, b = self:splitPartyInfo(value, w)
      local top = y + math.floor((h - (b and 20 or 10)) / 2)
      label(a, x, top, w, 10, tint)
      if b then label(b, x, top + 10, w, 10, tint) end
    end
    local function card(x, y, w, h, action, value, draw)
      if action then hit(x, y, w, h, action, value) end
      local pressed = self:beginPress(x, y, w, h, action ~= nil)
      self:panel(x, y, w, h, false)
      draw()
      self:endPress(pressed)
    end
    local function pager(y)
      label(tostring(model.page or 1) .. " / " .. tostring(model.pages or 1),
        46, y, 148, 14, quiet, true)
      if (model.pages or 1) > 1 then
        hit(6, y - 2, 30, 19, "page", -1); hit(204, y - 2, 30, 19, "page", 1)
        -- The left chevron is mirrored as a group, not a different glyph.
        G.push(); G.translate(25, 0); G.scale(-1, 1)
        self:detailChevron(3, y + 2, accent, true); G.pop()
        self:detailChevron(215, y + 2, accent, true)
      end
    end
    local view, area = model.view, model.area
    if view == "goals" or view == "album" then
      for i, tab in ipairs({ { "GOALS", "goals" }, { "STAMP BOOK", "album" } }) do
        local x = 6 + (i - 1) * 117
        hit(x, 34, 111, 18, "view", tab[2])
        if view == tab[2] then
          self:panel(x, 34, 111, 18, false); rect(x + 5, 49, 101, 2, accent)
        end
        label(translate(tab[1]), x, 35, 111, 12, view == tab[2] and accent or quiet, true)
      end
    end
    if view == "goals" then
      local goal = model.goal
      card(6, 61, 228, 91, goal and "area" or "view", goal and goal.id or "album", function()
        self:achievementSeal(49, 102, 27, goal and goal.kind or "route", false)
        label(translate(goal and "ALMOST THERE" or "YOUR JOURNEY"), 92, 67, 133, 11, accent, true)
        name(goal and goal.name or translate("COLLECT AREA STAMPS"), 92, 81, 133, 23)
        label(goal and (model.mode == "spoiler" and format("%d LEFT", goal.remaining)
          or translate("KEEP EXPLORING")) or translate("EXPLORE AT YOUR PACE"),
          92, 106, 133, 10, quiet, true)
        self:panel(95, 124, 127, 20, false)
        local title = self:fitPartyInfo(translate(goal and "VIEW AREA" or "STAMP BOOK"), 105)
        local width = self:partyInfoWidth(title)
        local left = 95 + math.floor((127 - width - 13) / 2)
        label(title, left, 126, width, 14, accent)
        self:detailChevron(left + width + 8, 130, accent, true)
      end)
      label(translate("YOUR STAMP BOOK"), 6, 158, 228, 12, accent)
      for i = 1, 2 do
        local earned, x = (model.earned or {})[i], i == 1 and 6 or 123
        card(x, 177, 111, 33, earned and "area" or "view", earned and earned.id or "album", function()
          if earned then
            self:achievementSeal(x + 18, 192, 12, earned.kind, true)
            name(earned.name, x + 35, 181, 70, 23)
          else label(translate("NEXT STAMP"), x + 5, 181, 101, 25, quiet, true) end
        end)
      end
    elseif view == "album" then
      pager(56)
      self:panel(6, 76, 228, 134, false)
      for i, entry in ipairs(model.entries or {}) do
        local x, y = 8 + (i - 1) % 3 * 76, 78 + math.floor((i - 1) / 3) * 65
        hit(x, y, 72, 63, "area", entry.id)
        local pressed = self:beginPress(x, y, 72, 63, true)
        self:achievementSeal(x + 35, y + 21, 21, entry.kind, entry.complete)
        name(entry.name, x + 1, y + 46, 70, 19, entry.complete and c.ink or quiet)
        self:endPress(pressed)
      end
      if #(model.entries or {}) == 0 then
        name(translate("EXPLORE TO START YOUR STAMP BOOK"), 22, 102, 196, 70, quiet)
      end
    elseif view == "detail" and area then
      self:panel(6, 34, 228, 55, false)
      self:achievementSeal(37, 61, 22, area.kind, area.complete)
      name(translate(area.complete and "EXPLORED" or "KEEP EXPLORING"), 70, 40, 150, 20, accent)
      label(model.mode == "spoiler" and format("%d LEFT", area.remaining)
        or translate("YOUR JOURNEY"), 70, 65, 150, 12, quiet, true)
      local titles = { "TRAINERS", "ITEMS", "HIDDEN FINDS" }
      for category = 1, 3 do
        local section, top = area.sections[category], 98 + (category - 1) * 39
        card(6, top, 228, category == 3 and 34 or 31, "category", category, function()
          if category == 1 then self:homeTrainerIcon(13, top + 2)
          elseif category == 2 then self:battleTeamBall(26, top + 15, true)
          else
            for i = 0, 5 do rect(29 + i, top + 18 + i, 4, 4, ink) end
            disc(25, top + 13, 9, ink); disc(25, top + 13, 7, c.blueLight)
            disc(25, top + 13, 5, paper)
          end
          label(translate(titles[category]), 49, top + 3, 155, 12, c.ink, false, "left")
          local counts = model.mode == "vanilla" or category == 3 and model.mode ~= "spoiler"
          counts = counts and format("%d RECORDED", section.done)
            or tostring(section.done) .. " / " .. tostring(section.total)
          if model.mode == "spoiler" then
            if (section.optional or 0) > 0 then counts = counts .. "  +" .. format("%d OPTIONAL", section.optional)
            elseif (section.unavailable or 0) > 0 then counts = counts .. "  +" .. format("%d ARCHIVED", section.unavailable) end
          end
          label(counts, 49, top + 17, 153, 10, accent, false, "left")
          self:detailChevron(214, top + 11, accent, true)
        end)
      end
    elseif view == "finds" then
      pager(34)
      for i, row in ipairs(model.entries or {}) do
        local top = 58 + (i - 1) * 36
        local canLocate = model.mode == "spoiler" and row.x ~= nil and row.y ~= nil
          and row.state ~= "unavailable" and row.state ~= "later"
        card(6, top, 228, 32, canLocate and "locate" or nil, row, function()
          name(row.label, 13, top + 2, 171, 19)
          label(translate(({ done = "RECORDED", open = "NOT YET", later = "LATER",
            optional = "OPTIONAL", unavailable = "NO LONGER AVAILABLE" })[row.state]),
            13, top + 20, 195, 9, row.state == "done" and accent or quiet, true)
          if canLocate then self:detailChevron(214, top + 12, accent, true) end
        end)
      end
      if #(model.entries or {}) == 0 then
        self:panel(6, 61, 228, 149, false)
        name(translate(model.mode == "spoiler" and "NOTHING HERE"
          or "ONLY RECORDED FINDS ARE SHOWN"), 22, 91, 196, 44, quiet)
        name(translate("SPOILER MODE SHOWS OPEN LOCATIONS"), 22, 143, 196, 38, quiet)
      end
    elseif view == "location" and model.location then
      local row = model.location
      self:panel(6, 34, 228, 129, false)
      if model.drawLocation then model.drawLocation(10, 38, 220, 121)
      else name(translate("MAP PREVIEW UNAVAILABLE"), 16, 65, 208, 60, quiet) end
      self:panel(6, 172, 228, 38, false)
      name(row.label, 12, 175, 216, 17)
      label(model.section .. "  " .. format("TILE %d, %d", row.x, row.y),
        12, 196, 216, 10, quiet, true)
    end
  end
end
