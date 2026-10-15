return function(H, ui, draw)
  local border, clipped, displayText = draw.border, draw.clipped, draw.displayText
  local fontWidth, glyphs, mixed, partyTypeFont =
    draw.fontWidth, draw.glyphs, draw.mixed, draw.partyTypeFont
  local translate = draw.translate

  -- Field Kit layout: lit cards for what works here (fishing carries its
  -- rods inline), then one compact grid of unlocked tools that do not.
  -- Drawing and touch share these rects; only an overflow spills onto pages.
  local KIT_TOP, KIT_BOTTOM, KIT_PAGED_BOTTOM = 34, 213, 199
  H.kitCard = { w = 111, h = 32, step = 35, columns = { 7, 122 } }
  H.kitChip = { w = 74, h = 26, step = 29, columns = { 7, 83, 159 } }
  H.kitLabel = 12

  local function kitRows(self, actions)
    local rows, ready, other = {}, {}, {}
    for index, action in ipairs(actions) do
      if action.ready then ready[#ready + 1] = index else other[#other + 1] = index end
    end
    local card, chip = self.kitCard, self.kitChip
    -- Fishing leads the list: it is the one card that carries a choice.
    for _, index in ipairs(ready) do
      if #(actions[index].rods or {}) > 1 then
        rows[#rows + 1] = { kind = "rods", h = card.h, step = card.step,
          cells = { { index = index, x = 7, w = 226 } } }
      end
    end
    local pair
    for _, index in ipairs(ready) do
      if #(actions[index].rods or {}) <= 1 then
        if not pair or #pair.cells == 2 then
          pair = { kind = "card", h = card.h, step = card.step, cells = {} }
          rows[#rows + 1] = pair
        end
        pair.cells[#pair.cells + 1] = { index = index, x = card.columns[#pair.cells + 1], w = card.w }
      end
    end
    for first = 1, #other, 3 do
      local row = { kind = "chip", h = chip.h, step = chip.step, cells = {} }
      for column = 1, 3 do
        local index = other[first + column - 1]
        if index then row.cells[column] = { index = index, x = chip.columns[column], w = chip.w } end
      end
      rows[#rows + 1] = row
    end
    return rows
  end

  function H:toolsLayout(actions)
    local rows = kitRows(self, actions or {})
    local function build(limit)
      local out, page, y, labelPage = { items = {}, labels = {} }, 1, KIT_TOP, nil
      for _, row in ipairs(rows) do
        local label = row.kind == "chip" and labelPage ~= page
        local need = row.h + (label and self.kitLabel or 0)
        if y + need > limit and y > KIT_TOP then
          page, y = page + 1, KIT_TOP
          label = row.kind == "chip"
        end
        if label then
          out.labels[#out.labels + 1] = { page = page, y = y }
          labelPage, y = page, y + self.kitLabel
        end
        for _, cell in ipairs(row.cells) do
          out.items[#out.items + 1] = { index = cell.index, kind = row.kind, page = page,
            x = cell.x, y = y, w = cell.w, h = row.h }
        end
        y = y + row.step
      end
      out.pages = page
      return out
    end
    local layout = build(KIT_BOTTOM)
    if layout.pages > 1 then layout = build(KIT_PAGED_BOTTOM) end
    return layout
  end

  -- Rod keys fill the right part of the fishing card, strongest last.
  function H:toolRodRect(item, rodIndex, count)
    local left, gap = item.x + 76, 4
    local w = math.floor((item.x + item.w - 4 - left - gap * (count - 1)) / count)
    return left + (rodIndex - 1) * (w + gap), item.y + 4, w, item.h - 8
  end

  function H:tools(model)
    local colors = self.colors
    model = model or {}
    local actions = model.actions or {}
    if #actions == 0 then
      self:homeTile(25, 55, 190, 103, colors.greenLight, false)
      clipped(103, 69, 34, 34,
        mixed(colors.surface, colors.white, self.dark and 0.06 or 0.24))
      border(103, 69, 34, 34, colors.outline)
      self:homeToolsIcon(107, 73)
      self:partyInfo(translate("NO TOOLS UNLOCKED"), 34, 113,
        colors.ink, 172, "center")
      self:partyType(translate("KEEP EXPLORING"), 34, 134,
        colors.green, 172)
      return
    end
    local layout = model.layout or self:toolsLayout(actions)
    local page = math.max(1, math.min(layout.pages, tonumber(model.page) or 1))
    for _, label in ipairs(layout.labels) do
      if label.page == page then self:toolSectionLabel(translate("NOT HERE"), label.y) end
    end
    for _, item in ipairs(layout.items) do
      if item.page == page then
        local action = actions[item.index]
        if item.kind == "chip" then self:toolChip(action, item)
        elseif item.kind == "rods" then self:toolRodCard(action, item)
        else self:toolCard(action, item, model.armed == action.id) end
      end
    end
    if layout.pages > 1 then self:homePager(page, layout.pages) end
  end

  function H:toolsHit(x, y, model)
    local actions = model and model.actions or {}
    local layout = model and model.layout or self:toolsLayout(actions)
    local page = math.max(1, math.min(layout.pages, tonumber(model and model.page) or 1))
    if layout.pages > 1 and y < 29 then
      if x >= 27 and x < 50 then return "prev" end
      if x >= 116 and x < 139 then return "next" end
    end
    for _, item in ipairs(layout.items) do
      local action = actions[item.index]
      if item.page == page and action and action.ready and x >= item.x and x < item.x + item.w
          and y >= item.y and y < item.y + item.h then
        if item.kind == "rods" then
          for rod = 1, #action.rods do
            local rx, ry, rw, rh = self:toolRodRect(item, rod, #action.rods)
            if x >= rx - 2 and x < rx + rw + 2 and y >= item.y and y < item.y + item.h then
              return "rod", item.index, rod
            end
          end
          return
        end
        return "action", item.index
      end
    end
  end

  function H:settingsHelpLines(value)
    local lines, buffer, space = {}, {}, nil
    local function emit(chars)
      local line = table.concat(chars):gsub("^%s+", ""):gsub("%s+$", "")
      if line ~= "" then lines[#lines + 1] = line end
    end
    for _, char in ipairs(glyphs(displayText(value))) do
      if char == "\n" then emit(buffer); buffer, space = {}, nil
      else
        while #buffer > 0 and fontWidth(partyTypeFont, table.concat(buffer) .. char) > 210 do
          if space then
            local tail, head = {}, {}
            for index, glyph in ipairs(buffer) do
              if index < space then head[#head + 1] = glyph
              elseif index > space then tail[#tail + 1] = glyph end
            end
            emit(head); buffer = tail
          else emit(buffer); buffer = {} end
          space = nil
        end
        buffer[#buffer + 1] = char
        if char == " " then space = #buffer end
      end
    end
    emit(buffer)
    return lines
  end

  function H:settingsHit(x, y, model)
    if y < 29 and x < 27 then return "back" end
    if not model.category then
      local index = math.floor((y - 34) / 30) + 1
      local top = 34 + (index - 1) * 30
      if x >= 7 and x < 233 and index >= 1
          and index <= #(model.categories or {}) and y >= top and y < top + 26
          then return "category", index end
      return
    end
    if model.option then
      if model.pages > 1 and y >= 202 and y < 214 then
        if x >= 72 and x < 104 then return "prev" end
        if x >= 136 and x < 168 then return "next" end
      end
      local top = self:settingsChoiceTop(model)
      local perPage = model.perPage or 4
      local visible = math.floor((y - top) / 25)
      local index = (model.page - 1) * perPage + visible + 1
      if x >= 7 and x < 233 and visible >= 0 and visible < perPage
          and y < top + 22 + visible * 25 and model.choices[index] then return "choice", index end
      return
    end
    if (model.pages or 1) > 1 and y >= 194 and y < 211 then
      if x >= 72 and x < 104 then return "prev" end
      if x >= 136 and x < 168 then return "next" end
    end
    local visible = math.floor((y - 36) / 40)
    local index = (model.page - 1) * 4 + visible + 1
    local row = model.rows and model.rows[index]
    if x >= 7 and x < 233 and visible >= 0 and visible < 4 and row and row.enabled ~= false then
      if y < 36 + visible * 40 or y >= 71 + visible * 40 then return end
      if row.action then return "row", index, 1 end
      return "row", index, x < 120 and -1 or 1
    end
  end

  function H:toolPromptHit(x, y)
    if x >= 39 and x < 114 and y >= 124 and y < 151 then return true end
    if x >= 126 and x < 201 and y >= 124 and y < 151 then return false end
  end

end
