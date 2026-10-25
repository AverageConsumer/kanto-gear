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
  -- Four-part progress ring: trainers, items, hidden finds, Pokemon (clockwise
  -- from the top). Pixel spans are cached per size; the same disc rounding as
  -- the seal keeps both edges on the pixel grid.
  local SEGMENT = { { .88, .28, .22, 1 }, { .88, .6, .13, 1 }, { .22, .47, .82, 1 }, { .24, .63, .3, 1 } }
  local METAL = { gold = { .83, .57, .18, 1 }, silver = { .49, .61, .65, 1 }, bronze = { .66, .36, .19, 1 } }
  local ringCache = {}
  local function ringPixels(outer, inner)
    local key = outer * 64 + inner
    if ringCache[key] then return ringCache[key] end
    local rows, quarter, gap = {}, math.pi / 2, 1.2 / outer
    for dy = -outer, outer do
      local half = math.floor(math.sqrt(outer * outer - dy * dy))
      local hole = math.abs(dy) <= inner and math.floor(math.sqrt(inner * inner - dy * dy)) or -1
      local row = { dy = dy }
      for dx = -half, half do
        if math.abs(dx) > hole then
          local angle = math.atan2(dx, -dy) % (2 * math.pi)
          local segment = math.floor(angle / quarter) % 4 + 1
          local within = angle - (segment - 1) * quarter
          if within >= gap and within <= quarter - gap then
            row[#row + 1] = { dx = dx, segment = segment, at = (within - gap) / (quarter - 2 * gap) }
          end
        end
      end
      rows[#rows + 1] = row
    end
    ringCache[key] = rows
    return rows
  end
  function H:achievementRing(cx, cy, outer, inner, sections, hiddenKnown)
    local track = self.colors.band
    for _, row in ipairs(ringPixels(outer, inner)) do
      local runX, runW, runTint
      for _, pixel in ipairs(row) do
        local section = sections and sections[pixel.segment] or {}
        local known = pixel.segment ~= 3 or hiddenKnown
        local total, done = section.total or 0, section.done or 0
        local share = total > 0 and done / total or 1
        local tint = known and (share >= 1 or pixel.at < share) and SEGMENT[pixel.segment] or track
        local x = cx + pixel.dx
        if tint == runTint and runX + runW == x then runW = runW + 1
        else
          if runTint then rect(runX, cy + row.dy, runW, 1, runTint) end
          runX, runW, runTint = x, 1, tint
        end
      end
      if runTint then rect(runX, cy + row.dy, runW, 1, runTint) end
    end
  end
  function H:achievementSeal(cx, cy, r, kind, tier)
    tier = tier == true and "gold" or tier or "none"
    local complete = tier ~= "none" and tier ~= false
    local metal, shine = gold, goldLight
    if tier == "bronze" then metal, shine = { .66, .36, .19, 1 }, { .92, .66, .42, 1 }
    elseif tier == "silver" then metal, shine = { .49, .61, .65, 1 }, { .83, .91, .93, 1 } end
    local c, quiet = self.colors, self.dark and self.colors.silver or self.colors.silverDark
    disc(cx + 1, cy + 2, r, c.shadow)
    disc(cx, cy, r, complete and ink or quiet)
    disc(cx, cy, r - 1, complete and metal or c.band)
    disc(cx, cy, r - 3, complete and shine or c.surface)
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
      rect(cx - 25, cy + 12, 51, 1, shine)
      self:partyType(self:fitPartyType(translate(tier:upper()), 49),
        cx - 25, cy + 12, paper, 51)
    end
  end

  function H:homeAchievements(model, tile, selected)
    local c, stamp = self.colors, model.stamps or {}
    local area, mode = stamp.area, stamp.mode
    local x, y, w, h = self:homeRect(tile)
    local accent = self.dark and c.greenLight or c.green
    self:homeTile(x, y, w, h, c.amber, selected)
    self:homeWidgetHeader(x, y, w, area and area.name or "STAMPS",
      c.green, c.greenLight, model.editing, area ~= nil)
    local step = stamp.step
    local ringed = area and mode ~= "vanilla" and area.tier and area.tier ~= "none"
    if ringed then
      -- Same four-part ring as the Stamp Book: trainers, items, hidden, Pokemon.
      self:achievementRing(x + 31, y + 48, 21, 18, area.sections, mode == "spoiler")
      self:achievementSeal(x + 31, y + 48, 15, area.kind, area.tier)
    else
      self:achievementSeal(x + 31, y + 48, 20, area and area.kind, area and area.tier)
    end
    local left, width = x + 64, w - 70
    local function small(value, top, tint)
      self:partyType(self:fitPartyType(value, width), left, top, tint, width)
    end
    if not area then
      small(translate("UNKNOWN AREA"), y + 34, c.ink)
      small(translate("KEEP EXPLORING"), y + 49, c.mutedInk)
      return
    end
    local status = translate(area.complete and "AREA COMPLETE" or "KEEP EXPLORING")
    if not area.complete and mode == "spoiler"
        and (area.total > 0 or (area.untracked or 0) > 0) then
      status = area.remaining == 0 and (area.unknown or 0) > 0
        and translate("NOT TRACKED")
        or area.remaining > 0 and area.availableRemaining == 0 and translate("MISSED GOALS")
        or format("%d LEFT", area.remaining)
    end
    if step and step.count > 0 then
      -- Next tier first, then how much is left; NOW when a missing Pokemon is out.
      local function pill(value, px, tint)
        if self.v4Pill then return self:v4Pill(value, px, y + 20, tint, { raw = true, maxW = 60 }) end
        local pw = math.min(60, self:partyInfoWidth(value) + 9)
        rect(px, y + 20, pw, 11, tint)
        self:partyType(self:fitPartyType(value, pw - 4), px + 2, y + 22, c.white or c.ink, pw - 4)
        return pw
      end
      local target, now = translate(step.target:upper()), stamp.now and translate("NOW")
      local function pillWidth(value)
        return self:partyInfoWidth(self:fitPartyType(value, 52)) + 9
      end
      local badgesWidth = pillWidth(target) + 4 + (now and pillWidth(now) + 4 or 0)
      local remaining = self:fitPartyInfo(format("%d LEFT", step.count), width - badgesWidth)
      local remainingWidth = self:partyInfoWidth(remaining)
      local px = left + math.floor((width - badgesWidth - remainingWidth) / 2)
      px = px + pill(target, px, METAL[step.target]) + 4
      if now then px = px + pill(now, px, SEGMENT[4]) + 4 end
      self:partyInfoCentered(remaining, px - 4, y + 19, remainingWidth + 8, 13, c.ink)
    else
      small(status, y + 21, area.complete and accent or c.ink)
    end
    local cellWidth = math.floor((width - 4) / 2)
    local gridLeft = left + math.floor((width - cellWidth * 2 - 4) / 2)
    for category, title in ipairs({ "TRAINERS", "ITEMS", "HIDDEN", "POKEMON" }) do
      local section = area.sections[category]
      local known = mode ~= "vanilla" and (category ~= 3 or mode == "spoiler")
      local complete = known and section.total > 0 and section.done == section.total
        and (section.unknown or 0) == 0
      -- Rows the next stamp does not depend on step back; the rest stay ink.
      local relevant = not step or (step.target == "gold") == (category == 4)
      local cx = gridLeft + (category - 1) % 2 * (cellWidth + 4)
      local cy = y + 35 + math.floor((category - 1) / 2) * 22
      rect(cx, cy, cellWidth, 21, c.surface)
      local count = known and (section.total == 0 and "-"
        or tostring(section.done) .. "/" .. tostring(section.total))
        or format("%d RECORDED", section.done)
      if known and (section.untracked or 0) > 0 then count = count .. " +?" end
      local name = translate(title)
      local barY = cy + 18
      if self:partyInfoWidth(name) + self:partyInfoWidth(count) + 6 <= cellWidth - 4 then
        -- one calm row: label left, count right, the bar underneath
        self:partyInfo(name, cx + 2, cy + 2, c.mutedInk)
        self:partyInfo(count, cx + 2, cy + 2, complete and accent or relevant and c.ink or c.mutedInk, cellWidth - 4, "right")
        barY = cy + 15
      else
        self:partyType(self:fitPartyType(name, cellWidth - 4),
          cx + 2, cy - 3, c.mutedInk, cellWidth - 4)
        self:partyType(self:fitPartyType(count, cellWidth - 4),
          cx + 2, cy + 7, complete and accent or c.ink, cellWidth - 4)
      end
      rect(cx + 2, barY, cellWidth - 4, 3, c.band)
      if known and section.total > 0 then
        rect(cx + 2, barY, math.floor((cellWidth - 4) * section.done / section.total),
          3, SEGMENT[category])
      end
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
      c.mutedInk
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
    local function pill(value, x, y, tint)
      if self.v4Pill then return self:v4Pill(value, x, y, tint, { raw = true, maxW = 96 }) end
      local w = math.min(96, self:partyInfoWidth(value) + 9)
      rect(x, y, w, 11, tint)
      self:partyType(self:fitPartyType(value, w - 4), x + 2, y + 2, c.white or c.ink, w - 4)
      return w
    end
    -- "TRAINERS 2  ITEMS 1": only what the next stamp needs, in game order.
    local function stepText(step, width)
      if not step then return translate("KEEP EXPLORING") end
      local parts = {}
      for _, part in ipairs({ { "TRAINERS", step.trainers }, { "ITEMS", step.items },
          { "HIDDEN", step.hidden }, { "POKEMON", step.pokemon } }) do
        if part[2] > 0 then parts[#parts + 1] = translate(part[1]) .. " " .. tostring(part[2]) end
      end
      if #parts == 0 then return translate(step.untracked and "NOT TRACKED" or "KEEP EXPLORING") end
      if width and #parts > 1 and self:partyInfoWidth(table.concat(parts, "  ")) > width then
        local first = table.remove(parts, 1)
        return first, table.concat(parts, "  ")
      end
      return table.concat(parts, "  ")
    end
    local function ringedSeal(cx, cy, entry, outer)
      self:achievementRing(cx, cy, outer, outer - 3, entry.sections, model.mode == "spoiler")
      self:achievementSeal(cx, cy, outer - 6, entry.kind, entry.tier)
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
    if model.loading then
      self:panel(6, 76, 228, 68, false)
      label(translate("LOADING AREA"), 12, 90, 216, 18, quiet)
      label("...", 12, 115, 216, 12, accent, true)
      return
    end
    local view, area = model.view, model.area
    if view == "goals" or view == "album" or view == "moments" then
      for i, tab in ipairs({ { "GOALS", "goals" }, { "STAMP BOOK", "album" }, { "MOMENTS", "moments" } }) do
        local x = 6 + (i - 1) * 77
        local seat = self.v4AchievementTabLayout and self:v4AchievementTabLayout()[i]
        hit(seat and seat.x or x, 34, seat and seat.w or 74, 18, "view", tab[2])
        if not self.v4AchievementTabs then
          if view == tab[2] then
            self:panel(x, 34, 74, 18, false); rect(x + 5, 49, 64, 2, accent)
          end
          label(translate(tab[1]), x, 35, 74, 12, view == tab[2] and accent or quiet, true)
          if tab[2] == "moments" and model.momentsUnseen and view ~= "moments" and self.homeUnreadDot then
            self:homeUnreadDot(x, 34, 74)
          end
        end
      end
      if self.v4AchievementTabs then self:v4AchievementTabs(view, model.momentsUnseen) end
    end
    if (view == "moments" or view == "moment") and self.momentsView then
      return self:momentsView(model, { hit = hit, card = card, label = label, name = name })
    end
    if view == "goals" and #(model.goals or {}) > 0 then
      for i, goal in ipairs(model.goals) do
        local top, entry, step = 58 + (i - 1) * 52, goal.area, goal.step
        card(6, top, 228, 48, "area", entry.id, function()
          ringedSeal(30, top + 24, entry, 19)
          self:partyInfo(self:fitPartyInfo(entry.name, 150), 54, top + 1, c.ink)
          local x = 54 + pill(translate(step.target:upper()), 54, top + 13, METAL[step.target]) + 4
          if goal.now then pill(translate("NOW"), x, top + 13, SEGMENT[4]) end
          local first, second = stepText(step, 150)
          self:partyType(first, 54, top + (second and 25 or 31), quiet, 150)
          if second then self:partyType(second, 54, top + 35, quiet, 150) end
          self:detailChevron(214, top + 20, accent, true)
        end)
      end
    elseif view == "goals" then
      local goal = model.goal
      card(6, 61, 228, 91, goal and "area" or "view", goal and goal.id or "album", function()
        self:achievementSeal(49, 102, 27, goal and goal.kind or "route", goal and goal.tier)
        label(translate(goal and "ALMOST THERE" or "YOUR JOURNEY"), 92, 67, 133, 11, accent, true)
        name(goal and goal.name or translate("COLLECT AREA STAMPS"), 92, 81, 133, 23)
        label(goal and (model.mode == "spoiler" and format("%d LEFT", goal.remaining)
          or translate("KEEP EXPLORING")) or translate("EXPLORE AT YOUR PACE"),
          92, 106, 133, 10, quiet, true)
        if self.v4ActionPanel then self:v4ActionPanel(95, 124, 127, 20) else self:panel(95, 124, 127, 20, false) end
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
            self:achievementSeal(x + 18, 192, 12, earned.kind, earned.tier or "gold")
            name(earned.name, x + 35, 181, 70, 23)
          else label(translate("NEXT STAMP"), x + 5, 181, 101, 25, quiet, true) end
        end)
      end
    elseif view == "album" then
      local ringed = model.mode ~= "vanilla" and model.summary ~= nil
      if ringed then
        -- Medal tally in the left half of the pager row, the page in the right half.
        local s, parts, width = model.summary, {}, 0
        for _, tier in ipairs({ "gold", "silver", "bronze" }) do
          local value = tostring(s[tier])
          parts[#parts + 1] = { tier, value, self:partyInfoWidth(value) }
          width = width + 9 + parts[#parts][3]
        end
        width = width + 6 * (#parts - 1)
        local x = 40 + math.floor((80 - width) / 2)
        for _, part in ipairs(parts) do
          disc(x + 3, 62, 3, METAL[part[1]])
          self:partyInfoCentered(part[2], x + 9, 54, part[3], 17, c.ink)
          x = x + 9 + part[3] + 6
        end
        self:partyInfoCentered(tostring(model.page or 1) .. " / " .. tostring(model.pages or 1), 124, 54, 76, 17, quiet)
        if (model.pages or 1) > 1 then
          hit(6, 54, 30, 19, "page", -1); hit(204, 54, 30, 19, "page", 1)
          G.push(); G.translate(25, 0); G.scale(-1, 1)
          self:detailChevron(3, 58, accent, true); G.pop()
          self:detailChevron(215, 58, accent, true)
        end
      else pager(56) end
      self:panel(6, 76, 228, 134, false)
      for i, entry in ipairs(model.entries or {}) do
        local x, y = 8 + (i - 1) % 3 * 76, 78 + math.floor((i - 1) / 3) * 65
        hit(x, y, 72, 63, "area", entry.id)
        local pressed = self:beginPress(x, y, 72, 63, true)
        if entry.current then
          rect(x + 2, y, 68, 1, accent); rect(x + 2, y + 62, 68, 1, accent)
          rect(x, y + 2, 1, 59, accent); rect(x + 71, y + 2, 1, 59, accent)
        end
        if ringed and entry.tier and entry.tier ~= "none" then
          ringedSeal(x + 35, y + 23, entry, 21)
          name(entry.name, x + 1, y + 44, 70, 20, entry.complete and c.ink or quiet)
        else
          self:achievementSeal(x + 35, y + 21, 21, entry.kind, entry.tier or entry.complete)
          name(entry.name, x + 1, y + 46, 70, 19, entry.complete and c.ink or quiet)
        end
        self:endPress(pressed)
      end
      if #(model.entries or {}) == 0 then
        name(translate("EXPLORE TO START YOUR STAMP BOOK"), 22, 102, 196, 70, quiet)
      end
    elseif view == "detail" and area then
      self:panel(6, 34, 228, 55, false)
      self:achievementSeal(37, 61, 22, area.kind, area.tier or area.complete)
      local unvisited = area.evidence == false
      local nextGoal = unvisited and "NOT VISITED" or area.tier == "gold" and "AREA COMPLETE"
        or area.tier == "silver" and "COMPLETE LOCAL POKEDEX"
        or area.tier == "bronze" and "FINISH AREA TASKS" or "KEEP EXPLORING"
      name(translate(nextGoal), 70, 40, 150, 20, accent)
      local step = model.step
      if step and not unvisited then
        -- What the next stamp needs, and how far along that tier is.
        local x = 72 + pill(translate(step.target:upper()), 72, 63, METAL[step.target]) + 4
        local remaining = step.count > 0 and format("%d LEFT", step.count) or stepText(step)
        self:partyInfo(self:fitPartyInfo(remaining, 220 - x), x, 62, quiet)
        local done, total = 0, 0
        for category = 1, 4 do
          local section = area.sections[category]
          local counts = step.target == "gold" and category == 4
            or step.target == "silver" and category < 4 and (category ~= 3 or model.mode == "spoiler")
          if counts and section then done, total = done + (section.done or 0), total + (section.total or 0) end
        end
        rect(72, 79, 148, 3, c.band)
        if total > 0 then rect(72, 79, math.floor(148 * done / total), 3, METAL[step.target]) end
      else
        label(unvisited and translate("VISIT AREA TO EXPLORE")
          or model.mode == "spoiler" and (area.remaining == 0 and (area.unknown or 0) > 0
            and translate("NOT TRACKED") or format("%d LEFT", area.remaining))
          or translate("YOUR JOURNEY"), 70, 65, 150, 12, quiet, true)
      end
      local titles = { "TRAINERS", "ITEMS", "HIDDEN FINDS", "POKEMON" }
      for category = 1, 4 do
        local section, top = area.sections[category], 94 + (category - 1) * 30
        card(6, top, 228, 27, "category", category, function()
          if category == 1 then self:homeTrainerIcon(13, top - 1)
          elseif category == 2 then
            rect(18, top + 6, 17, 16, ink); rect(19, top + 7, 15, 14, paper)
            rect(24, top + 9, 5, 10, c.green); rect(21, top + 12, 11, 4, c.green)
          elseif category == 4 then
            G.push(); G.translate(26, top + 13); G.scale(2, 2)
            self:battleTeamBall(0, 0, true); G.pop()
          else
            for i = 0, 4 do rect(29 + i, top + 16 + i, 3, 3, ink) end
            disc(25, top + 11, 8, ink); disc(25, top + 11, 6, c.blueLight)
            disc(25, top + 11, 4, paper)
          end
          label(translate(titles[category]), 49, top + 1, 155, 12, c.ink, false, "left")
          local counts = model.mode == "vanilla" or category == 3 and model.mode ~= "spoiler"
          counts = counts and format("%d RECORDED", section.done)
            or tostring(section.done) .. " / " .. tostring(section.total)
          if model.mode == "spoiler" then
            if (section.untracked or 0) > 0 then counts = counts .. "  +" .. format("%d UNTRACKED", section.untracked)
            elseif (section.optional or 0) > 0 then counts = counts .. "  +" .. format("%d/%d BONUS", section.bonusDone or 0, section.optional)
            elseif (section.unavailable or 0) > 0 then counts = counts .. "  " .. tostring(section.unavailable) .. " " .. translate("MISSED") end
          end
          label(counts, 49, top + 14, 153, 10, accent, false, "left")
          self:detailChevron(214, top + 9, accent, true)
        end)
      end
    elseif view == "finds" then
      pager(34)
      for i, row in ipairs(model.entries or {}) do
        local top = 58 + (i - 1) * 36
        local canLocate = (model.canLocate == true or model.canLocate == nil and model.mode == "spoiler") and row.mapId ~= nil
          and row.x ~= nil and row.y ~= nil
        local action = canLocate and "locate"
          or row.wild and model.canHabitat ~= false and "habitat" or nil
        card(6, top, 228, 32, action, row, function()
          if not self.v4FindRow then name(row.isEgg and translate("EGG") or row.label, 13, top + 2, 171, 19) end
          local status = translate(row.state == "unavailable" and "NO LONGER AVAILABLE"
            or row.species and (not row.gift or row.catchGoal) and (row.state == "done" and "CAUGHT" or "NOT CAUGHT")
            or ({ done = "RECORDED", open = row.trade and "NPC TRADE" or row.loan and "NPC LOAN" or (row.cost or row.coinCost) and "NPC OFFER" or row.gift and "NPC GIFT" or "NOT YET", later = "LATER",
            optional = "OPTIONAL", unavailable = "NO LONGER AVAILABLE",
            untracked = "NOT TRACKED", excluded = "ALTERNATIVE CHOICE",
            repeatable = row.kind == "hidden" and "RENEWABLE" or "REPEATABLE" })[row.state])
          if row.bonus then status = translate("BONUS") .. ": " .. status end
          local hints = model.category == 4 and row.wild and row.state ~= "done"
            and model.canHabitat ~= false and model.canEncounterDetails ~= false
            and row.appearances and self.v4MethodGlyph
          if self.v4FindRow then
            local icons = {}
            if hints then
              -- Where and when the missing Pokemon appears in this area.
              local inArea, times, methods, order, allTimes = {}, {}, {}, {}, false
              for _, id in ipairs(model.areaMaps or {}) do inArea[id] = true end
              for _, appearance in ipairs(row.appearances) do
                if inArea[appearance.mapId] then
                  if appearance.time then times[appearance.time] = true else allTimes = true end
                  local method = appearance.method or "WALK"
                  if method ~= "WALK" and not methods[method] then methods[method] = true; order[#order + 1] = method end
                end
              end
              for i = 1, 3 do
                local period = ({ "MORN", "DAY", "NITE" })[i]
                if times[period] and not allTimes and not (times.MORN and times.DAY and times.NITE) and self.v4PeriodIcon then
                  icons[#icons + 1] = { "period", period }
                end
              end
              for i = 1, math.min(3, #order) do icons[#icons + 1] = { "method", order[i] } end
            end
            local left = 208 - #icons * 10
            self:v4FindRow(row, top, status, action ~= nil, #icons > 0 and left or nil)
            for i, icon in ipairs(icons) do
              local x = left + (i - 1) * 10
              if icon[1] == "period" then self:v4PeriodIcon(icon[2], x, top + 6)
              else self:v4MethodGlyph(icon[2], x, top + 5) end
            end
          else
          label(status,
            13, top + 20, 195, 9, row.state == "done" and accent or quiet, true)
          if action then self:detailChevron(214, top + 12, accent, true) end
          end
        end)
      end
      if model.category == 4 and #(model.entries or {}) > 0 then
        card(6, 190, 228, 20, model.canExplore and "explore" or nil, nil, function()
          label(translate(model.canExplore and "OPEN EXPLORER" or "VISIT AREA TO EXPLORE"),
            12, 193, 216, 13, model.canExplore and accent or quiet, true)
        end)
      end
      if #(model.entries or {}) == 0 then
        self:panel(6, 61, 228, 149, false)
        name(translate(model.mode == "spoiler" and "NOTHING HERE"
          or "ONLY RECORDED FINDS ARE SHOWN"), 22, 91, 196, 44, quiet)
        name(translate("REVEAL MORE IN EXPLORATION SETTINGS"), 22, 143, 196, 38, quiet)
      end
    elseif view == "habitat" and model.habitat then
      self:pokedexHabitat(model.habitat)
    elseif view == "location" and model.location then
      local row, point = model.location, model.locationPoint or model.location
      local height = model.entrance and 105 or 129
      self:panel(6, 34, 228, height, false)
      if model.drawLocation then model.drawLocation(10, 38, 220, height - 8)
      else name(translate("MAP PREVIEW UNAVAILABLE"), 16, 65, 208, 60, quiet) end
      if model.entrance then
        card(6, 145, 228, 21, "location_scope", nil, function()
          self:partyInfoCentered(self:fitPartyInfo(
            translate(model.inside and "SHOW ENTRANCE" or "SHOW INSIDE"), 216),
            12, 145, 216, 21, accent)
        end)
      end
      self:panel(6, 172, 228, 38, false)
      name(row.label, 12, 175, 216, 17)
      local status = row.state == "later" and "LATER"
        or row.state == "unavailable" and "NO LONGER AVAILABLE"
      local floor = model.locationFloor == "ROOF" and translate("ROOF") or model.locationFloor
      label(model.section .. (floor and "  " .. floor or "")
        .. "  " .. (model.entrance and not model.inside and translate("ENTRANCE")
        or status and translate(status) or format("TILE %d, %d", point.x, point.y)),
        12, 196, 216, 10, quiet, true)
    end
  end
end
