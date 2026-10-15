-- Calendar app and Home widgets. Rows arrive named by the runtime; this
-- file only lays them out and emits the hit regions it paints.
return function(H, G, translate, format)
  local floor = math.floor
  local function rect(x, y, w, h, tint)
    G.setColor(tint); G.rectangle("fill", x, y, w, h)
  end
  local TAG_TINT = {
    BATTLE = { .86, .29, .25, 1 }, GIFT = { .85, .55, .1, 1 }, CALL = { .22, .47, .82, 1 },
    EVENT = { .18, .6, .45, 1 }, WILD = { .55, .36, .78, 1 }, RADIO = { .22, .47, .82, 1 },
    BERRIES = { .27, .62, .3, 1 }, BALLS = { .85, .55, .1, 1 }, SHOP = { .36, .42, .53, 1 },
    SERVICE = { .36, .42, .53, 1 }, TUTOR = { .36, .42, .53, 1 }, TIDE = { .16, .55, .72, 1 },
  }
  H.calendarTagTint = TAG_TINT
  local PERIOD = { MORN = "MORNING", DAY = "DAY", NITE = "NIGHT" }

  -- White on a dark key, ink on a light one (C-Gear's dark accents are pale).
  local function onKey(self, tint)
    local light = (tint[1] or 0) * 0.3 + (tint[2] or 0) * 0.59 + (tint[3] or 0) * 0.11
    return light > 0.62 and self.colors.outline or self.colors.white
  end
  H.calendarOnKey = onKey
  local function wrapped(self, value, x, y, width, tint, align)
    if self.v4Wrapped then return self.v4Wrapped(self, value, x, y, width, tint, align) end
    self:partyInfo(self:fitPartyInfo(value, width), x, y + 5, tint, width, align)
    return 1
  end
  local function small(self, value, x, y, width, tint, align)
    local label = self:fitPartyInfo(value, width)
    if align == "center" then self:partyInfoCentered(label, x - 4, y, width + 8, 10, tint)
    else self:partyInfo(label, x, y, tint, width, align) end
  end

  -- Pills share one width per screen so titles line up in a column.
  local function tagWidth(self, rows)
    local width = 0
    for _, row in ipairs(rows) do
      width = math.max(width, self:partyInfoWidth(self:fitPartyType(translate(row.tag or "EVENT"), 52)) + 9)
    end
    return math.max(30, width)
  end
  local function tag(self, row, x, y, width)
    local label = self:fitPartyType(translate(row.tag or "EVENT"), width - 8)
    local tint = TAG_TINT[row.tag] or TAG_TINT.EVENT
    if row.state == "done" then tint = self.colors.silverDark end
    self:v4Pill(label, x, y, tint, { raw = true, w = width })
  end
  local function stateText(row, weekday)
    if row.state == "done" then return translate("DONE") end
    if row.right then return row.right end
    if row.state == "missed" then return translate("NEXT WEEK") end
    if row.when and #row.when > 0 then return translate(row.when[1]) end
    if row.kind == "buena" then return translate(row.state == "open" and "UNTIL MIDNIGHT" or "FROM 6 PM") end
    if row.state == "later" then return translate("LATER") end
    if row.place then return row.place end
    return ""
  end

  function H:calendarHit(x, y)
    for _, hit in ipairs(self.calendarHits or {}) do
      if x >= hit.x and x < hit.x + hit.w and y >= hit.y and y < hit.y + hit.h then
        return hit.action, hit.value
      end
    end
  end

  -- Rows for the open day: "now" then the rest of today, or one weekday.
  function H:calendarRows(model)
    local rows, labels = {}, {}
    local day = model.day or model.weekday
    if day == model.weekday then
      local seen = {}
      if #model.now > 0 then
        labels[#rows + 1] = model.noWeek and translate("RIGHT NOW")
          or format("NOW: %s", translate(PERIOD[model.period] or "DAY"))
        for _, row in ipairs(model.now) do rows[#rows + 1] = row; seen[row] = true end
      end
      local first, group = true, nil
      for _, row in ipairs(model.today) do
        if not seen[row] then
          if model.noWeek then
            local heading = row.state == "done" and "DONE FOR TODAY" or "COMING UP"
            if heading ~= group then labels[#rows + 1], group = translate(heading), heading end
          elseif first then
            labels[#rows + 1] = model.comingUp and translate("COMING UP")
              or translate(#model.now > 0 and "ALSO TODAY" or "TODAY")
            first = false
          end
          rows[#rows + 1] = row
        end
      end
    else
      for _, row in ipairs(model.days[day] or {}) do rows[#rows + 1] = row end
      if #rows > 0 then labels[1] = translate((model.dayNames or {})[day + 1] or "") end
    end
    return rows, labels
  end

  function H:calendar(model)
    local c = self.colors
    local accent = self.dark and c.greenLight or c.green
    local quiet = c.mutedInk
    self.calendarHits = {}
    local function hit(x, y, w, h, action, value)
      self.calendarHits[#self.calendarHits + 1] = { x = x, y = y, w = w, h = h, action = action, value = value }
    end
    if model.unsupported then
      self:panel(6, 76, 228, 70, false)
      wrapped(self, translate("NO CALENDAR IN THIS GAME"), 14, 100, 212, quiet, "center")
      return
    end
    if model.view == "detail" and model.entry then return self:calendarDetail(model) end
    local pageTop = 63
    if model.noWeek then
      pageTop = 34
      if model.hero then self:calendarHero(model.hero); pageTop = 82 end
    else
    -- Week strip: today framed, the open day lit, dots for how much is on.
    local open = model.day or model.weekday
    for day = 0, 6 do
      local x = 6 + day * 33
      local lit = day == open
      local pressed = self:beginPress(x, 34, 30, 25, not lit)
      if lit then
        self:v4Button(x, 34, 30, 25, self.v4ramp(accent), { radius = 4, lip = 3, chamfer = 3 })
      else
        self:panel(x, 34, 30, 25, false)
      end
      local keyInk = onKey(self, self.v4ramp(accent).M or accent)
      local label = self:fitPartyType(translate((model.shortNames or {})[day + 1] or ""), 28)
      self:partyInfoCentered(label, x - 4, 34, 38, 14,
        lit and keyInk or (day == model.weekday and accent or c.ink))
      local count = math.min(3, #(model.days[day] or {}))
      local dotsX = x + 15 - floor((count * 4 - 2) / 2)
      for dot = 1, count do
        rect(dotsX + (dot - 1) * 4, 50, 2, 2, lit and keyInk or quiet)
      end
      if day == model.weekday and not lit then rect(x + 4, 55, 22, 1, accent) end
      self:endPress(pressed)
      if not lit then hit(x, 34, 30, 25, "day", day) end
    end
    end
    local rows, labels = self:calendarRows(model)
    if #rows == 0 then
      self:panel(6, pageTop + 7, 228, 64, false)
      wrapped(self, translate(model.noWeek and "NOTHING TO DO RIGHT NOW" or "NOTHING ELSE TODAY"),
        14, pageTop + 24, 212, quiet, "center")
      return
    end
    -- Lay out labels and rows; spill onto pages when they do not fit.
    local function place(bottom)
      local placed, page, y = {}, 1, pageTop
      for index, row in ipairs(rows) do
        local need = 21 + (labels[index] and 12 or 0)
        if y + need > bottom then page, y = page + 1, pageTop end
        if labels[index] then placed[#placed + 1] = { label = labels[index], y = y, page = page }; y = y + 12 end
        placed[#placed + 1] = { row = row, y = y, page = page }
        y = y + 21
      end
      return placed, page
    end
    local placed, pages = place(212)
    if pages > 1 then placed, pages = place(192) end
    local current = math.max(1, math.min(pages, model.page or 1))
    model.page, model.pages = current, pages
    local width = tagWidth(self, rows)
    for _, item in ipairs(placed) do
      if item.page == current then
        if item.label then
          small(self, item.label, 8, item.y, 224, quiet)
        else
          local row, ry = item.row, item.y
          hit(6, ry, 228, 19, "entry", row.key)
          local pressed = self:beginPress(6, ry, 228, 19, true)
          self:panel(6, ry, 228, 19, false)
          tag(self, row, 10, ry + 4, width)
          local titleX = 14 + width
          local right = stateText(row, model.weekday)
          -- The title is the entry; the place or time on the right yields
          -- its space first and is shown in full on the detail page.
          local room = 226 - titleX - 8
          local titleNeed = self:partyInfoWidth(row.title or "")
          local rightW = right ~= "" and math.min(self:partyInfoWidth(right), 84) or 0
          if titleNeed + rightW > room then rightW = math.max(math.min(rightW, 40), room - titleNeed) end
          local titleW = room - rightW
          self:partyInfo(self:fitPartyInfo(row.title or "", titleW), titleX, ry + 2,
            row.state == "done" and quiet or c.ink)
          if right ~= "" and rightW > 0 then
            self:partyInfo(self:fitPartyInfo(right, rightW), 226 - rightW, ry + 2,
              row.state == "open" and row.kind == "call" and accent or quiet, rightW, "right")
          end
          self:endPress(pressed)
        end
      end
    end
    if pages > 1 then
      self:partyInfoCentered(format("%d/%d", current, pages), 100, 200, 40, 12, quiet)
      if current > 1 then
        hit(60, 196, 40, 18, "page", -1)
        G.push(); G.translate(87, 0); G.scale(-1, 1); self:detailChevron(3, 203, accent, true); G.pop()
      end
      if current < pages then
        hit(140, 196, 40, 18, "page", 1)
        self:detailChevron(151, 203, accent, true)
      end
    end
  end

  -- Gen 3 has no weekdays. In their place: Hoenn's day as one 24-hour bar
  -- (clock, Shoal Cave's low tides, the next harvest) or the VS Seeker's
  -- battery in FireRed/LeafGreen. Display only; nothing here is tappable.
  function H:calendarHero(hero)
    local c = self.colors
    local accent = self.dark and c.greenLight or c.green
    local quiet = c.mutedInk
    local track = self.dark and { 1, 1, 1, 0.12 } or { 0, 0, 0, 0.1 }
    self:panel(6, 34, 228, 44, false)
    if hero.kind == "seeker" then
      local full = hero.charge >= hero.max
      local count = math.floor(hero.charge * 10 / hero.max)
      local fill = full and accent or TAG_TINT.GIFT
      small(self, hero.title or "", 12, 37, 120, c.ink)
      small(self, format("%d/%d", hero.charge, hero.max), 132, 37, 96, quiet, "right")
      -- Ten cells of ten steps, centred in the card: 10 x 20 + 9 x 2 = 218.
      for cell = 0, 9 do
        rect(11 + cell * 22, 51, 20, 9, cell < count and fill or track)
      end
      small(self, hero.status or "", 12, 63, 216, full and accent or quiet)
      return
    end
    -- 24 hours over 216 px: 9 px an hour, from x 12.
    local x0, y0, perHour = 12, 52, 9
    local function at(minutes) return x0 + math.floor(minutes * perHour / 60) end
    small(self, hero.clock or "", 12, 37, 60, c.ink)
    local tide = TAG_TINT.TIDE
    small(self, hero.status or "", 72, 37, 156, hero.low and tide or quiet, "right")
    rect(x0, y0, 216, 7, track)
    if hero.tide then
      for _, window in ipairs({ { 3, 9 }, { 15, 21 } }) do
        rect(at(window[1] * 60), y0, (window[2] - window[1]) * perHour, 7, { tide[1], tide[2], tide[3], 0.55 })
      end
    end
    local now = at(hero.minutes or 0)
    rect(x0, y0, now - x0, 7, { accent[1], accent[2], accent[3], 0.35 })
    for hour = 6, 18, 6 do rect(at(hour * 60), y0, 1, 7, track) end
    for _, mark in ipairs(hero.marks or {}) do
      local x, tint = at(mark.at), TAG_TINT[mark.tag] or accent
      rect(x - 1, y0 - 4, 3, 1, tint); rect(x - 2, y0 - 3, 5, 2, tint); rect(x, y0 - 1, 1, 1, tint)
    end
    rect(now - 1, y0 - 3, 2, 13, c.ink)
    -- Ends sit flush with the bar; the inner hours centre on their ticks.
    small(self, "0", x0, 63, 20, quiet)
    for hour = 6, 18, 6 do self:partyInfoCentered(tostring(hour), at(hour * 60) - 10, 63, 20, 10, quiet) end
    small(self, "24", x0 + 216 - 20, 63, 20, quiet, "right")
  end

  function H:calendarDetail(model)
    local c, row = self.colors, model.entry
    local accent = self.dark and c.greenLight or c.green
    local quiet = c.mutedInk
    self:panel(6, 34, 228, 46, false)
    local width = tagWidth(self, { row })
    tag(self, row, 12, 39, width)
    local trainer = row.trainerClass
    if row.trainer and row.kind == "phone_gift" then
      trainer = row.trainer .. (trainer and " / " .. trainer or "")
    end
    if trainer then small(self, trainer, 18 + width, 38, 206 - width, quiet) end
    wrapped(self, row.title or "", 12, 49, 216, c.ink)
    -- Facts as label/value lines: where, when, how it stands.
    local facts = {}
    if row.place then facts[#facts + 1] = { "PLACE", row.place } end
    for _, fact in ipairs(row.facts or {}) do facts[#facts + 1] = fact end
    if row.facts or model.noWeek then
      -- Gen 3 rows carry their own timing.
    elseif row.kind == "call" and row.day then
      local when = translate((model.dayNames or {})[row.day + 1] or "")
      for _, slot in ipairs(row.when or {}) do when = when .. ", " .. translate(slot) end
      facts[#facts + 1] = { "CALL ON", when }
    elseif row.kind == "buena" then
      facts[#facts + 1] = { "ON AIR", translate("6 PM TO MIDNIGHT") }
    elseif row.day ~= nil and row.kind ~= "rematch" and row.kind ~= "phone_gift" then
      local when = translate((model.dayNames or {})[row.day + 1] or "")
      for _, slot in ipairs(row.when or {}) do when = when .. ", " .. translate(slot) end
      facts[#facts + 1] = { "WHEN", when }
    end
    local status = row.status and row.state ~= "done" and row.status or row.state == "done" and "DONE FOR TODAY"
      or row.kind == "rematch" and "WANTS A REMATCH"
      or row.kind == "phone_gift" and "HAS A GIFT FOR YOU"
      or row.kind == "call" and (row.state == "open" and "CALL NOW FOR A REMATCH"
        or row.state == "missed" and "MISSED THIS WEEK" or "CALL THEN FOR A REMATCH")
      or row.kind == "kurt" and (row.state == "later" and "COME BACK TOMORROW" or "PICK THEM UP")
      or row.state == "later" and "LATER TODAY"
      or (row.day == nil or row.day == model.weekday) and row.state == "open" and "AVAILABLE NOW"
      or "ON ITS DAY"
    facts[#facts + 1] = { "STATUS", status == row.status and status or translate(status) }
    self:panel(6, 84, 228, 12 + #facts * 22, false)
    for index, fact in ipairs(facts) do
      local y = 88 + (index - 1) * 22
      small(self, translate(fact[1]), 12, y, 216, quiet)
      small(self, fact[2], 12, y + 10, 216, fact[1] == "STATUS" and row.state ~= "done" and accent or c.ink)
    end
    local top = 88 + #facts * 22 + 4
    -- What else belongs to the entry: its weekdays, places or items.
    local list = row.placeList or row.detailItems
    if list and #list > 0 then
      self:panel(6, top, 228, 210 - top, false)
      for index, value in ipairs(list) do
        if top + 4 + index * 11 <= 206 then small(self, value, 12, top + 4 + (index - 1) * 11, 216, c.ink) end
      end
    elseif not model.noWeek and row.kind ~= "rematch" and row.kind ~= "phone_gift" and row.kind ~= "berries"
        and row.kind ~= "kurt" and row.kind ~= "buena" and top + 30 <= 210 then
      self:panel(6, top, 228, 30, false)
      for day = 0, 6 do
        local on = false
        for _, other in ipairs(model.days[day] or {}) do
          if other.key == row.key or row.kind == "call" and other.key == row.key then on = true end
        end
        local x = 10 + day * 32
        local label = self:fitPartyType(translate((model.shortNames or {})[day + 1] or ""), 28)
        if on then self:v4Pill(label, x, top + 9, accent, { raw = true, w = 28 })
        else self:partyInfo(label, x, top + 8, quiet, 28, "center") end
      end
    end
  end

  -- Home widgets.
  local function badge(self, model, x, y, w, h)
    local c = self.colors
    local accent = self.dark and c.greenLight or c.green
    local ramp = self.v4ramp(accent)
    self:v4Button(x, y, w, h, ramp, { radius = 4, lip = 3, chamfer = 3 })
    local ink = onKey(self, ramp.M or accent)
    local top = model.badge and model.badge[1] or translate((model.shortNames or {})[(model.weekday or 0) + 1] or "")
    local bottom = model.badge and model.badge[2] or translate(PERIOD[model.period] or "DAY")
    self:partyInfoCentered(self:fitPartyInfo(top, w - 4), x - 4, y + floor(h / 2) - 11, w + 8, 10, ink)
    self:partyInfoCentered(self:fitPartyInfo(bottom, w - 4), x - 4, y + floor(h / 2) - 1, w + 8, 10, ink)
  end
  local function nextUp(model)
    if model.noWeek then
      for _, row in ipairs(model.today or {}) do if row.state ~= "done" then return row, nil end end
      return
    end
    for offset = 1, 6 do
      local day = ((model.weekday or 0) + offset) % 7
      local row = (model.days[day] or {})[1]
      if row then return row, day end
    end
  end

  function H:homeCalendar(model, tile, selected)
    local c = self.colors
    local data = model.calendar or { now = {}, today = {}, days = {} }
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, c.blue, selected)
    self:homeWidgetHeader(x, y, w, "CALENDAR", c.green, c.greenLight, model.editing)
    if data.unsupported then
      wrapped(self, translate("NO CALENDAR IN THIS GAME"), x + 8, y + 32, w - 16, c.mutedInk, "center")
      return
    end
    badge(self, data, x + 6, y + 20, 44, 54)
    local left, width = x + 56, w - 62
    local rows = {}
    for _, row in ipairs(data.now or {}) do rows[#rows + 1] = row end
    if #rows == 0 and data.hero and data.hero.kind == "seeker" then
      rows[1] = { title = data.hero.title, tag = "BATTLE", place = data.hero.status }
    end
    if #rows == 0 then
      local row, day = nextUp(data)
      small(self, translate(data.noWeek and "NOTHING TO DO RIGHT NOW" or "NOTHING ELSE TODAY"), left, y + 22, width,
        c.ink)
      if row then
        local when = day and translate((data.shortNames or {})[day + 1] or "") or row.right
        small(self, (when and when ~= "" and when .. ": " or "") .. tostring(row.title or ""), left, y + 36, width,
          c.mutedInk)
      end
      return
    end
    local tagW = tagWidth(self, { rows[1], rows[2] })
    for index = 1, math.min(2, #rows) do
      local row, ry = rows[index], y + 20 + (index - 1) * 17
      tag(self, row, left, ry + 3, tagW)
      small(self, row.title or "", left + tagW + 4, ry + 1, width - tagW - 4, c.ink)
    end
    if #rows > 2 then
      small(self, format("+%d MORE NOW", #rows - 2), left, y + 56, width, c.mutedInk)
    elseif rows[1].place then
      small(self, rows[1].place, left, y + 56, width, c.mutedInk)
    end
  end

  function H:homeCalendarSmall(model, tile, selected)
    local c = self.colors
    local data = model.calendar or { now = {}, today = {}, days = {} }
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, c.blue, selected)
    self:homeWidgetHeader(x, y, w, "TODAY", c.green, c.greenLight, model.editing)
    if data.unsupported then
      wrapped(self, translate("NO CALENDAR IN THIS GAME"), x + 4, y + 30, w - 8, c.mutedInk, "center")
      return
    end
    badge(self, data, x + floor((w - 60) / 2), y + 19, 60, 28)
    local count = #(data.now or {})
    local first = data.now and data.now[1]
    if not first and data.hero and data.hero.kind == "seeker" then first = { title = data.hero.status } end
    if first then
      wrapped(self, first.title or "", x + 4, y + 49, w - 8, c.ink, "center")
      if count > 1 then small(self, format("+%d MORE", count - 1), x + 4, y + 69, w - 8, c.mutedInk, "center") end
    else
      wrapped(self, translate(data.noWeek and "NOTHING TO DO RIGHT NOW" or "NOTHING ELSE TODAY"), x + 4, y + 49,
        w - 8, c.mutedInk, "center")
    end
  end
end
