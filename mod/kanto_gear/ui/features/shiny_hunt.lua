-- Shiny Hunt app and Home widgets. The runtime hands over a finished view
-- model; every hit region is emitted by the same layout that paints it.
return function(H, G, translate, format)
  local floor, max, min = math.floor, math.max, math.min
  local WHITE = { 1, 1, 1, 1 }
  local function rect(x, y, w, h, tint)
    G.setColor(tint); G.rectangle("fill", x, y, w, h)
  end
  local function art(rows, x, y, palette)
    for row, line in ipairs(rows) do
      for column = 1, #line do
        local tint = palette[line:sub(column, column)]
        if tint then rect(x + column - 1, y + row - 1, 1, 1, tint) end
      end
    end
  end
  local SPARK = { "...#...", "...#...", "..#h#..", "##hhh##", "..#h#..", "...#...", "...#..." }
  local SPARK_S = { ".#.", "#h#", ".#." }

  -- Gold ink reads on either surface; keys keep the deeper gold under white text.
  local function gold(self) return self.dark and self.colors.amberLight or self.colors.amber end
  local function key(self) return self.colors.amber end
  local function small(self, value, x, y, width, tint, align)
    local label = self:fitPartyInfo(value, width)
    if align == "center" then self:partyInfoCentered(label, x, y, width, 10, tint)
    else self:partyInfo(label, x, y, tint, width, align) end
  end
  local function wrapped(self, value, x, y, width, tint, align)
    if self.v4Wrapped then return self.v4Wrapped(self, value, x, y, width, tint, align) end
    small(self, value, x, y + 5, width, tint, align)
    return 1
  end

  -- Twinkling sparkles; still when motion is off.
  local function sparkle(self, x, y, big, phase)
    local c = self.colors
    local lit = true
    if phase and self.motionEnabled ~= false then
      self:wantAmbient(0.25)
      lit = floor(self:clock() * 4 + phase) % 4 ~= 0
    end
    if not lit then return end
    local palette = { ["#"] = self.dark and c.amberLight or { 0.97, 0.76, 0.2, 1 }, h = WHITE }
    if big then art(SPARK, x - 3, y - 3, palette) else art(SPARK_S, x - 1, y - 1, palette) end
  end
  H.shinySparkle = sparkle

  -- The target portrait: the shiny sprite, or the Shiny Hunt mark for "any".
  local function portrait(self, view, species, x, y, size, animate)
    if species == "*" or species == nil then
      local scale = max(1, floor(size / 24))
      local offset = floor((size - 24 * scale) / 2)
      G.push(); G.translate(x + offset, y + offset); G.scale(scale, scale)
      self:v4Icon("shiny", 0, 0); G.pop()
      return
    end
    if view.drawPokemon then view.drawPokemon(species, x, y, size, true, animate) end
  end
  H.shinyPortrait = portrait

  function H:shinyHuntHit(x, y)
    for index = #(self.shinyHits or {}), 1, -1 do
      local hit = self.shinyHits[index]
      if x >= hit.x and x < hit.x + hit.w and y >= hit.y and y < hit.y + hit.h then
        return hit.action, hit.value
      end
    end
  end

  -- How long a find took. Two quiet surprises: the very first roll, and a
  -- find on exactly the 8192nd.
  local function tookLine(view, hunt, count)
    if count == 1 then return translate("ON THE FIRST TRY") end
    if count == 8192 and hunt.method ~= "EGGS" then return translate("EXACTLY 1 IN 8192!") end
    return format(hunt.method == "EGGS" and "AFTER %s EGGS" or "AFTER %s ENCOUNTERS", view.group(count))
  end

  local TABS = { { "HUNT", "hunt" }, { "ODDS", "odds" }, { "LOG", "log" } }

  function H:shinyHunt(view)
    local c = self.colors
    self.shinyHits = {}
    local hits = self.shinyHits
    local function hit(x, y, w, h, action, value)
      hits[#hits + 1] = { x = x, y = y, w = w, h = h, action = action, value = value }
    end
    if view.view == "pick" then return self:shinyHuntPick(view, hit) end
    local current = view.view or "hunt"
    self:v4Segments(6, 34, 228, TABS, current, true, key(self))
    local segment = floor(228 / #TABS)
    for index, tab in ipairs(TABS) do
      if tab[2] ~= current then
        hit(6 + (index - 1) * segment, 32, index == #TABS and 228 - segment * (#TABS - 1) or segment, 21,
          "view", tab[2])
      end
    end
    if current == "odds" then return self:shinyHuntOdds(view, hit) end
    if current == "log" then return self:shinyHuntLog(view, hit) end
    return self:shinyHuntMain(view, hit)
  end

  local function button(self, x, y, w, h, tint, label, enabled, action, hit, large)
    if enabled then hit(x, y, w, h, action) end
    local pressed = self:beginPress(x, y, w, h, enabled)
    local ramp = self.v4ramp(enabled and tint or self.colors.silverDark)
    local off = self:v4Button(x, y, w, h, ramp, { radius = 5, lip = 4, chamfer = 5 }) or 0
    local ink = enabled and WHITE or self.colors.band
    if large and self.v4LargeFits and self:v4LargeFits(label, w - 8) then
      local height = self:v4LargeHeight()
      self:v4Large(label, x, y + floor((h - 4 - height) / 2) + off, ink, w, "center")
    else
      self:partyInfoCentered(self:fitPartyInfo(label, w - 8), x, y - 2 + off, w, h, ink)
    end
    self:endPress(pressed)
  end

  -- Main page: the target, its counter and the odds it has bought.
  function H:shinyHuntMain(view, hit)
    local c = self.colors
    local quiet, accent = c.mutedInk, gold(self)
    local hunt = view.hunt
    if not hunt then
      self:panel(6, 56, 228, 108, false)
      portrait(self, view, "*", 96, 66, 48)
      sparkle(self, 150, 70, true, 0)
      sparkle(self, 88, 108, false, 2)
      small(self, translate("NO HUNT YET"), 14, 120, 212, c.ink, "center")
      wrapped(self, translate("PICK A POKEMON TO COUNT ITS ENCOUNTERS."), 14, 130, 212, quiet, "center")
      button(self, 42, 170, 156, 34, key(self), translate("PICK A TARGET"), true, "pick", hit)
      return
    end
    if hunt.found then
      self:panel(6, 56, 228, 108, false)
      portrait(self, view, hunt.found.species or hunt.species, 88, 59, 64, true)
      sparkle(self, 84, 66, true, 0)
      sparkle(self, 158, 74, true, 1.5)
      sparkle(self, 150, 116, false, 3)
      sparkle(self, 92, 112, false, 2.5)
      small(self, translate("SHINY FOUND!"), 14, 125, 212, accent, "center")
      small(self, hunt.found.name or hunt.name or "", 14, 137, 212, c.ink, "center")
      local count = hunt.found.count or hunt.count
      small(self, tookLine(view, hunt, count), 14, 149, 212, quiet, "center")
      button(self, 6, 170, 111, 34, key(self), translate("HUNT AGAIN"), true, "again", hit)
      button(self, 123, 170, 111, 34, c.green, translate("NEW TARGET"), true, "pick", hit)
      return
    end

    -- Target card: tap to change the target.
    hit(6, 56, 228, 76, "pick")
    local pressed = self:beginPress(6, 56, 228, 76, true)
    self:panel(6, 56, 228, 76, false)
    portrait(self, view, hunt.any and "*" or hunt.species, 10, 62, 64)
    local left, width = 80, 138
    self:partyInfo(self:fitPartyInfo(hunt.name or "", width), left, 59, c.ink)
    if self:v4LargeFits(hunt.countText, width) then
      self:v4Large(hunt.countText, left, 66, c.ink)
    else
      self:partyInfo(self:fitPartyInfo(hunt.countText, width), left, 78, c.ink)
    end
    local unit = translate(hunt.method == "EGGS" and "EGGS" or hunt.method == "MANUAL" and "RESETS" or "ENCOUNTERS")
    local pillW = 0
    if hunt.phases > 0 then
      local label = hunt.phases == 1 and translate("1 PHASE") or format("%d PHASES", hunt.phases)
      pillW = self:v4Pill(self:fitPartyType(label, 60), left + width, 97, c.blue, { raw = true, right = true }) + 4
    end
    small(self, unit, left, 96, width - pillW, quiet)
    local status = view.auto and translate("AUTO COUNT ON") or translate("AUTO COUNT PAUSED")
    if view.error then status = translate(view.error) end
    local last = view.last and format("LAST: %s", view.last.name or "") or status
    local lastTint = view.error and c.red or view.last and view.last.shiny and accent or quiet
    local pausedW = 0
    if not view.error and not view.auto then
      pausedW = self:v4Pill(translate("PAUSED"), left + width, 112, c.silverDark, { right = true, maxW = 56 }) + 4
    end
    small(self, view.error and status or last, left, 111, width - pausedW, lastTint)
    self:detailChevron(223, 90, quiet, false)
    self:endPress(pressed)

    -- Counter keys: -1 for a miscount, +1 for what Gear cannot see (gift
    -- Pokemon, resets before a battle), and the automatic count switch.
    button(self, 6, 136, 44, 32, c.silverDark, "-1", hunt.count > 0, "minus", hit)
    button(self, 54, 136, 132, 32, key(self), "+1", true, "plus", hit, true)
    button(self, 190, 136, 44, 32, view.auto and c.green or c.silverDark,
      translate("AUTO"), true, "auto", hit)

    -- The odds strip.
    self:panel(6, 172, 228, 38, false)
    small(self, translate("CHANCE SO FAR"), 12, 174, 140, quiet)
    self:partyInfo(hunt.chanceText, 12, 174, c.ink, 216, "right")
    rect(12, 188, 216, 4, c.band)
    rect(12, 188, max(hunt.chance > 0 and 1 or 0, floor(216 * min(1, hunt.chance) + 0.5)), 4, accent)
    local multiple = hunt.multipleText .. "× " .. translate("ODDS")
    self:partyInfo(multiple, 12, 195, quiet)
    local right
    if view.here and view.here.methods and view.here.methods[1] then
      local method = view.here.methods[1]
      right = format("HERE: %s", method.chance and format("%s %d%%", translate(method.name), method.chance)
        or translate(method.name))
    elseif hunt.pace then
      right = format("%s/H", view.group(hunt.pace))
    end
    if right then
      local room = 216 - self:partyInfoWidth(multiple) - 8
      self:partyInfo(self:fitPartyInfo(right, room), 12, 195, quiet, 216, "right")
    end
  end

  local function row(self, x, y, w, label, value, tint)
    local c = self.colors
    local valueW = min(120, self:partyInfoWidth(value))
    small(self, label, x, y, w - valueW - 6, c.mutedInk)
    self:partyInfo(self:fitPartyInfo(value, valueW), x, y, tint or c.ink, w, "right")
  end

  -- Odds page: what the count means, the milestones and the game's rules.
  function H:shinyHuntOdds(view, hit)
    local c = self.colors
    local quiet, accent = c.mutedInk, gold(self)
    local hunt = view.hunt
    if not hunt then
      self:panel(6, 56, 228, 72, false)
      wrapped(self, translate("BASE SHINY ODDS: 1 IN 8192."), 14, 64, 212, c.ink, "center")
      wrapped(self, translate("PICK A TARGET TO TRACK YOUR ODDS."), 14, 92, 212, quiet, "center")
      button(self, 42, 170, 156, 34, key(self), translate("PICK A TARGET"), true, "pick", hit)
      return
    end
    self:panel(6, 56, 228, 64, false)
    row(self, 12, 59, 216, translate("CHANCE SO FAR"), hunt.chanceText, accent)
    row(self, 12, 74, 216, translate("EXPECTED SHINIES"), hunt.multipleText)
    local base = "1/" .. view.group(view.fullOdds)
    if hunt.boosted > 0 or view.boost then base = base .. "  " .. format("EGGS 1/%d", view.boostedOdds) end
    row(self, 12, 89, 216, translate("BASE ODDS"), base)
    local hours, minutes = view.duration(hunt.time)
    local spent = hours > 0 and format("%d H %d MIN", hours, minutes) or format("%d MIN", minutes)
    if hunt.pace then spent = spent .. "  " .. format("%s/H", view.group(hunt.pace)) end
    row(self, 12, 104, 216, translate("TIME HUNTING"), spent)

    -- Milestones on one track: 50 / 75 / 90 / 95 / 99 percent.
    self:panel(6, 124, 228, 44, false)
    local top = view.milestones[#view.milestones].need
    local next = translate("PAST EVERY MILESTONE")
    if hunt.nextShare and hunt.boosted > 0 then next = format("NEXT: %s", view.percent(hunt.nextShare))
    elseif hunt.nextShare then next = format("NEXT: %s AT %s", view.percent(hunt.nextShare), view.group(hunt.nextNeed)) end
    small(self, translate("MILESTONES"), 12, 126, 90, quiet)
    self:partyInfo(self:fitPartyInfo(next, 126), 12, 126, c.ink, 216, "right")
    local trackX, trackW = 12, 216
    rect(trackX, 142, trackW, 4, c.band)
    -- Boosted eggs move the marker by the full-odds rolls they are worth.
    local rolls = hunt.equivalent or max(0, hunt.count - hunt.boosted)
    rect(trackX, 142, floor(trackW * min(1, rolls / top) + 0.5), 4, accent)
    for _, stone in ipairs(view.milestones) do
      local x = trackX + floor(trackW * stone.need / top + 0.5) - 1
      local reached = rolls >= stone.need
      rect(min(x, trackX + trackW - 1), 140, 1, 8, reached and accent or c.mutedInk)
      local label = tostring(floor(stone.share * 100 + 0.5))
      local labelW = self:partyInfoWidth(label)
      local lx = max(trackX, min(trackX + trackW - labelW, x - floor(labelW / 2)))
      self:partyInfo(label, lx, 151, reached and accent or quiet)
    end

    -- Where it lives and the rule of this generation.
    self:panel(6, 172, 228, 38, false)
    local here
    if hunt.any then here = translate("EVERY WILD POKEMON COUNTS")
    elseif view.here and view.here.methods and #view.here.methods > 0 then
      local parts = {}
      for index, method in ipairs(view.here.methods) do
        if index <= 3 then
          parts[#parts + 1] = method.chance and format("%s %d%%", translate(method.name), method.chance)
            or translate(method.name)
        end
      end
      here = format("HERE: %s", table.concat(parts, "  "))
    elseif view.here and view.here.now then here = translate("FOUND IN THIS AREA")
    elseif view.here then here = translate("NOT IN THIS AREA RIGHT NOW") end
    local tip
    if view.boost then
      tip = format(view.boost.ditto and "SHINY DITTO BOARDING: EGGS 1/%d" or "SHINY PARENT BOARDING: EGGS 1/%d",
        view.boostedOdds)
    elseif view.generation == 2 then tip = translate("A SHINY PARENT MAKES EGGS 1 IN 64")
    else tip = translate("SOFT RESETS KEEP YOUR COUNT.") end
    if here then
      small(self, here, 12, 175, 216, c.ink)
      small(self, tip, 12, 190, 216, view.boost and accent or quiet)
    else
      small(self, tip, 12, 182, 216, view.boost and accent or quiet, "center")
    end
  end

  -- Lay out section labels and rows; spill onto pages when they do not fit.
  local function pages(items, top, rowH)
    local function place(bottom)
      local placed, page, y = {}, 1, top
      for _, item in ipairs(items) do
        local need = rowH + (item.label and 12 or 0)
        if y + need > bottom then page, y = page + 1, top end
        if item.label then placed[#placed + 1] = { label = item.label, y = y, page = page }; y = y + 12 end
        placed[#placed + 1] = { item = item, y = y, page = page }
        y = y + rowH
      end
      return placed, page
    end
    local placed, count = place(212)
    if count > 1 then placed, count = place(194) end
    return placed, count
  end

  local function pager(self, current, count, hit)
    if count <= 1 then return end
    local accent = gold(self)
    self:partyInfoCentered(format("%d/%d", current, count), 100, 198, 40, 12, self.colors.mutedInk)
    if current > 1 then
      hit(60, 194, 40, 20, "page", -1)
      G.push(); G.translate(87, 0); G.scale(-1, 1); self:detailChevron(3, 201, accent, true); G.pop()
    end
    if current < count then
      hit(140, 194, 40, 20, "page", 1)
      self:detailChevron(151, 201, accent, true)
    end
  end

  local KIND = { target = "TARGET", phase = "PHASE", lucky = "LUCKY" }

  -- Log page: every shiny met, then the counters waiting to be resumed.
  function H:shinyHuntLog(view, hit)
    local c = self.colors
    local quiet, accent = c.mutedInk, gold(self)
    local items = {}
    for index, entry in ipairs(view.log or {}) do
      items[#items + 1] = { entry = entry, label = index == 1 and format("SHINIES MET: %d", #view.log) or nil }
    end
    for index, entry in ipairs(view.shelf or {}) do
      items[#items + 1] = { shelf = entry, label = index == 1 and translate("OTHER HUNTS") or nil }
    end
    if #items == 0 then
      self:panel(6, 60, 228, 104, false)
      portrait(self, view, "*", 108, 68, 24)
      small(self, translate("NO SHINIES YET"), 14, 98, 212, c.ink, "center")
      wrapped(self, translate("EVERY SHINY YOU MEET IS SAVED HERE."), 14, 108, 212, quiet, "center")
      small(self, format("%s WILD ENCOUNTERS SEEN", view.group(view.encounters or 0)), 14, 144, 212, quiet, "center")
      return
    end
    local placed, count = pages(items, 56, 26)
    local current = max(1, min(count, view.page or 1))
    for _, slot in ipairs(placed) do
      if slot.page == current then
        if slot.label then
          small(self, slot.label, 8, slot.y, 224, quiet)
        else
          local y, item = slot.y, slot.item
          local entry = item.entry or item.shelf
          local pressed
          if item.shelf then
            hit(6, y, 228, 24, "resume", entry.any and "*" or tostring(entry.species))
            pressed = self:beginPress(6, y, 228, 24, true)
          end
          self:panel(6, y, 228, 24, false)
          portrait(self, view, entry.any and "*" or entry.species, 9, y + 1, 22)
          local name = entry.name or ""
          if item.entry then
            -- Name and how it was met on the left; kind and count on the right.
            local kind = translate(KIND[entry.kind] or "LUCKY")
            local countText = entry.kind ~= "lucky" and view.group(entry.count or 0) or ""
            local lone = countText == ""
            local pillW = self:v4Pill(self:fitPartyType(kind, 56), 226, lone and y + 6 or y + 2,
              entry.kind == "target" and accent or entry.kind == "phase" and c.blue or c.green,
              { raw = true, right = true })
            local countW = lone and 0 or self:partyInfoWidth(countText)
            -- The first shiny of the playthrough says so; others remember where.
            local detail = entry.first and translate("YOUR FIRST SHINY!")
              or entry.kind == "phase" and entry.targetName and format("WHILE HUNTING %s", entry.targetName)
              or entry.via == "egg" and translate("HATCHED FROM AN EGG")
              or entry.place and format("MET AT %s", entry.place) or nil
            local shownName = self:fitPartyInfo(name, 190 - pillW - (entry.first and 14 or 6))
            self:partyInfo(shownName, 36, detail and y + 1 or y + 6, c.ink)
            if entry.first then sparkle(self, 36 + self:partyInfoWidth(shownName) + 5, detail and y + 5 or y + 10, false) end
            if detail then
              small(self, detail, 36, y + 12, 190 - max(countW, 0) - 8, entry.first and accent or quiet)
            end
            if not lone then self:partyInfo(countText, 36, y + 12, quiet, 190, "right") end
          else
            self:partyInfo(self:fitPartyInfo(name, 120), 36, y + 1, c.ink)
            small(self, entry.found and translate("SHINY FOUND!") or format("%s CHANCE", entry.chanceText),
              36, y + 12, 120, entry.found and accent or quiet)
            self:partyInfo(entry.countText, 36, y + 6, c.ink, 180, "right")
            self:detailChevron(223, y + 9, quiet, false)
          end
          if pressed then self:endPress(pressed) end
        end
      end
    end
    pager(self, current, count, hit)
  end

  -- Picker: anything, the last Pokemon met, this area and the party.
  function H:shinyHuntPick(view, hit)
    local c = self.colors
    local quiet, accent = c.mutedInk, gold(self)
    local pick = view.pick or { rows = {} }
    local items = {}
    local section
    for index, entry in ipairs(pick.rows) do
      local label = entry.section ~= section and translate(entry.section) or nil
      section = entry.section
      items[#items + 1] = { row = entry, index = index, label = label }
    end
    local placed, count = pages(items, 34, 24)
    local current = max(1, min(count, pick.page or 1))
    pick.page = current
    for _, slot in ipairs(placed) do
      if slot.page == current then
        if slot.label then
          small(self, slot.label, 8, slot.y, 224, quiet)
        else
          local y, entry = slot.y, slot.item.row
          hit(6, y, 228, 22, "target", slot.item.index)
          local pressed = self:beginPress(6, y, 228, 22, true)
          self:panel(6, y, 228, 22, entry.active, accent)
          if entry.any then
            G.push(); G.translate(10, y + 2); G.scale(0.75, 0.75); self:v4Icon("shiny", 0, 0); G.pop()
          else
            portrait(self, view, entry.species, 9, y + 1, 20)
          end
          local right = entry.count and entry.count > 0 and view.group(entry.count)
            or entry.chance and format("%s %d%%", translate(entry.method or ""), entry.chance)
            or entry.method and translate(entry.method)
            or entry.note and translate(entry.note) or ""
          local rightW = right ~= "" and min(90, self:partyInfoWidth(right)) or 0
          self:partyInfo(self:fitPartyInfo(entry.name or "", 186 - rightW), 34, y + 5, c.ink)
          if right ~= "" then
            self:partyInfo(self:fitPartyInfo(right, rightW), 34, y + 5,
              entry.active and c.ink or entry.count and entry.count > 0 and accent or quiet, 192, "right")
          end
          self:endPress(pressed)
        end
      end
    end
    pager(self, current, count, hit)
  end

  ----------------------------------------------------------------------------
  -- Home widgets: the wide card shows the target and its odds, the small
  -- one the count alone.
  ----------------------------------------------------------------------------
  function H:homeShinyHunt(model, tile, selected)
    local c = self.colors
    local view = model.shiny or {}
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, c.amber, selected)
    self:homeWidgetHeader(x, y, w, "SHINY HUNT", c.amber, c.amberLight, model.editing)
    local accent, quiet = gold(self), c.mutedInk
    local hunt = view.hunt
    if not hunt and view.lucky then
      local lucky = view.lucky
      portrait(self, view, lucky.species, x + 6, y + 21, 48)
      sparkle(self, x + 10, y + 26, true, 0)
      sparkle(self, x + 48, y + 60, false, 2)
      small(self, translate("LUCKY SHINY!"), x + 60, y + 22, w - 68, accent)
      small(self, lucky.name or "", x + 60, y + 36, w - 68, c.ink)
      if lucky.place then small(self, format("MET AT %s", lucky.place), x + 60, y + 50, w - 68, quiet) end
      return
    end
    if not hunt then
      portrait(self, view, "*", x + 14, y + 36, 24)
      small(self, translate("NO HUNT YET"), x + 48, y + 37, w - 56, c.ink)
      small(self, translate("TAP TO PICK A TARGET"), x + 48, y + 49, w - 56, quiet)
      return
    end
    local found = hunt.found
    portrait(self, view, hunt.any and "*" or (found and found.species or hunt.species), x + 6, y + 21, 48)
    if found then
      sparkle(self, x + 10, y + 26, true, 0)
      sparkle(self, x + 48, y + 60, false, 2)
    end
    local left, width = x + 60, w - 68
    if found then
      small(self, translate("SHINY FOUND!"), left, y + 22, width, accent)
      small(self, found.name or hunt.name or "", left, y + 36, width, c.ink)
      small(self, tookLine(view, hunt, found.count or hunt.count), left, y + 50, width, quiet)
      return
    end
    local chanceW = self:partyInfoWidth(hunt.chanceText)
    self:partyInfo(self:fitPartyInfo(hunt.name or "", width - chanceW - 6), left, y + 19, c.ink)
    self:partyInfo(hunt.chanceText, left, y + 19, accent, width, "right")
    -- The count with its unit beside it; the pause pill takes the unit's place.
    local countW
    if self:v4LargeFits(hunt.countText, width) then
      countW = self:v4Large(hunt.countText, left, y + 27, c.ink)
    else
      self:partyInfo(self:fitPartyInfo(hunt.countText, width), left, y + 38, c.ink)
      countW = min(width, self:partyInfoWidth(hunt.countText))
    end
    local room = width - countW - 6
    if not view.auto then
      self:v4Pill(translate("PAUSED"), left + width, y + 43, c.silverDark, { right = true, maxW = min(56, room) })
    elseif room >= 30 then
      small(self, translate(hunt.method == "EGGS" and "EGGS" or hunt.method == "MANUAL" and "RESETS" or "ENCOUNTERS"),
        left + countW + 6, y + 43, room, quiet)
    end
    rect(left, y + 66, width, 4, c.band)
    rect(left, y + 66, max(hunt.chance > 0 and 1 or 0, floor(width * min(1, hunt.chance) + 0.5)), 4, accent)
  end

  function H:homeShinyHuntSmall(model, tile, selected)
    local c = self.colors
    local view = model.shiny or {}
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, c.amber, selected)
    self:homeWidgetHeader(x, y, w, "SHINY", c.amber, c.amberLight, model.editing)
    local accent, quiet = gold(self), c.mutedInk
    local hunt = view.hunt
    if not hunt and view.lucky then
      portrait(self, view, view.lucky.species, x + floor((w - 40) / 2), y + 17, 40)
      sparkle(self, x + floor((w - 40) / 2) + 2, y + 22, true, 0)
      sparkle(self, x + floor((w + 40) / 2) - 2, y + 50, false, 2)
      small(self, translate("LUCKY SHINY!"), x + 4, y + 60, w - 8, accent, "center")
      return
    end
    if not hunt then
      portrait(self, view, "*", x + floor((w - 24) / 2), y + 24, 24)
      small(self, translate("NO HUNT YET"), x + 4, y + 54, w - 8, quiet, "center")
      return
    end
    if hunt.found then
      portrait(self, view, hunt.any and "*" or hunt.found.species or hunt.species, x + floor((w - 40) / 2), y + 17, 40)
      sparkle(self, x + floor((w - 40) / 2) + 2, y + 22, true, 0)
      sparkle(self, x + floor((w + 40) / 2) - 2, y + 50, false, 2)
      small(self, translate("SHINY FOUND!"), x + 4, y + 60, w - 8, accent, "center")
      return
    end
    portrait(self, view, hunt.any and "*" or hunt.species, x + 5, y + 21, 32)
    local left, width = x + 40, w - 46
    if self:v4LargeFits(hunt.countText, width) then
      self:v4Large(hunt.countText, left, y + 24, c.ink, width, "right")
    else
      self:partyInfo(self:fitPartyInfo(hunt.countText, width), left, y + 28, c.ink, width, "right")
    end
    small(self, hunt.chanceText, left, y + 43, width, quiet, "right")
    small(self, translate(view.auto and "AUTO COUNT" or "PAUSED"), x + 4, y + 56, w - 8,
      view.auto and quiet or c.red, "center")
    rect(x + 8, y + 71, w - 16, 4, c.band)
    rect(x + 8, y + 71, max(hunt.chance > 0 and 1 or 0, floor((w - 16) * min(1, hunt.chance) + 0.5)), 4, accent)
  end
end
