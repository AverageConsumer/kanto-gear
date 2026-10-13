return function(H, ui, draw)
  local border, clipped, displayText = draw.border, draw.clipped, draw.displayText
  local fontWidth, glyphs, mixed, partyTypeFont =
    draw.fontWidth, draw.glyphs, draw.mixed, draw.partyTypeFont
  local translate = draw.translate

  function H:toolCardRect(visible, count)
    if count == 1 then return 66, 74 end
    if count == 2 then return 7 + visible * 117, 74 end
    if count == 3 and visible == 2 then return 66, 115 end
    return 7 + visible % 2 * 117, 33 + math.floor(visible / 2) * 82
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
    local page = math.max(1, tonumber(model.page) or 1)
    local first = (page - 1) * 4 + 1
    local count = math.min(4, math.max(0, #actions - first + 1))
    for index = first, math.min(first + 3, #actions) do
      local visible = index - first
      local x, y = self:toolCardRect(visible, count)
      self:toolCard(actions[index], x, y)
    end
    self:homePager(page, model.pages)
  end

  function H:toolsHit(x, y, model)
    local page = math.max(1, tonumber(model and model.page) or 1)
    local actions = model and model.actions or {}
    if y < 29 and x >= 27 and x < 50 then return "prev" end
    if y < 29 and x >= 116 and x < 139 then return "next" end
    local first = (page - 1) * 4 + 1
    local count = math.min(4, math.max(0, #actions - first + 1))
    for visible = 0, count - 1 do
      local index = (page - 1) * 4 + visible + 1
      local action = actions[index]
      local left, top = self:toolCardRect(visible, count)
      if action and action.ready and x >= left and x < left + 109
          and y >= top and y < top + 76 then return "action", index end
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
