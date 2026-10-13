return function(
  CHOICE_QUIET, EngineFont, HEIGHT, THEME, WIDTH, assist,
  battleState, box, button, centered, color, compat,
  displayRuntime, drawSprite, fit, glyphList, header, hgssRuntime,
  loadMap, mod, outline, render, session, text
)
  local function trackChoice(top, now)
    if not session.choiceTop and not top then return false end
    if session.choiceTop and session.choiceTop[1] == top
        and session.choiceTop[2] == (top and top.phase) then return false end
    session.choiceTop = top and { top, top.phase } or nil
    session.choiceCommitted = nil
    session.choiceNudgeUntil = 0
    session.choiceReadyAt = top and now + CHOICE_QUIET or 0
    return true
  end

  local function choiceWindow(labels, index)
    local count = math.min(4, #labels)
    local start = math.max(1, math.min((index or 1) - 1,
                                      #labels - count + 1))
    return start, count
  end

  -- Boot warm-up. While the title owns the screen, build the caches the
  -- first Gear frames would otherwise stall on: the skin's backdrop images
  -- (both variants, so Auto never hitches), the region map tiles and the
  -- host modules the explorer and portraits pull in lazily. One step per
  -- tick; the title's boot log reports each group as it really finishes.
  displayRuntime.bootWarm = { group = 1, step = 1, groups = {
    { label = "THEME", steps = {
      function()
        if THEME.hgss and THEME.hgss.v4PrewarmBackdrop then
          THEME.hgss:v4PrewarmBackdrop(THEME.hgss.dark == true)
        end
      end,
      function()
        if THEME.hgss and THEME.hgss.v4PrewarmBackdrop then
          THEME.hgss:v4PrewarmBackdrop(THEME.hgss.dark ~= true)
        end
      end,
    } },
    { label = "MAP", steps = {
      function()
        if displayRuntime.gen3 or not (session.game and session.game.data) then return end
        local ready = compat.isGen2()
          and session.game.data.gen2MenuGfx and session.game.data.gen2MenuGfx.pokegear
          or not compat.isGen2() and session.game.data.field and session.game.data.field.townMap
        -- Never cache a miss before the host finished loading its data.
        if ready then loadMap() end
      end,
      function()
        if compat.isGen2() and session.game and session.game.data and session.game.data.gen2MenuGfx then
          compat.gen2BadgeAsset()
        end
      end,
    } },
    { label = "SYSTEM", steps = {
      function()
        if displayRuntime.gen3 then return end
        for _, name in ipairs({ "src.render.Assets", "src.render.GbcPalette",
            "src.world.MapOverview",
            compat.isGen2() and "src.world.gen2.Map" or "src.world.Map" }) do
          pcall(require, name)
        end
      end,
    } },
  } }

  function displayRuntime.bootWarmStep()
    local warm = displayRuntime.bootWarm
    local group = warm.groups[warm.group]
    if not group then warm.finished = true; return false end
    local fn = group.steps[warm.step]
    if fn then pcall(fn) end
    warm.step = warm.step + 1
    if warm.step > #group.steps then
      group.done = true
      warm.group, warm.step = warm.group + 1, 1
      if not warm.groups[warm.group] then warm.finished = true end
      return true
    end
    return false
  end

  local function drawTitle()
    if THEME.style == "hgss" then
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:titleBoot({ systemId = compat.systemId(),
        version = tostring(mod.version or "4.0"):match("^(%d+%.%d+)") or "4.0",
        warm = displayRuntime.bootWarm.groups },
        love.timer.getTime())
      render.G.pop()
      return
    end
    local modern = THEME.style ~= "classic"
    local foreground = modern and render.INK or render.PAPER
    local primary = modern and THEME.blue or render.PAPER
    local secondary = modern and THEME.red or render.MID
    local phase = math.floor(love.timer.getTime() * 2) % 3
    box("fill", 0, 0, WIDTH, HEIGHT, modern and render.PAPER or render.DARK)
    outline(3, 3, 154, 138, primary)
    box("fill", 3, 3, 28, 2, secondary)
    box("fill", 129, 139, 28, 2, secondary)

    centered(THEME:translate("SILPH CO."), 9, secondary)
    outline(47, 24, 22, 18, foreground)
    outline(91, 24, 22, 18, foreground)
    box("fill", 51, 28, 14, 10, modern and render.MID or render.INK)
    box("fill", 95, 28, 14, 10, modern and render.MID or render.INK)
    box("fill", 69, 32, 22, 2, foreground)
    for i = 0, 2 do
      box("fill", 73 + i * 7, 31, 4, 4,
        i == phase and secondary or foreground)
    end

    centered(THEME:translate("SILPH LINK"), 50, foreground, 2)
    box("fill", 24, 67, 36, 1, secondary)
    box("fill", 100, 67, 36, 1, secondary)
    centered(THEME:translate("SYSTEM"), 65, primary)

    box("fill", 15, 81, 130, 21, modern and render.MID or render.INK)
    outline(15, 81, 130, 21, primary)
    centered(compat.systemId(), 88, foreground, nil, true)

    local linkStatus = fit("LINK ONLINE", 18)
    local linkWidth = #glyphList(linkStatus) * 6
    local linkX = math.floor((WIDTH - linkWidth) / 2)
    box("fill", linkX - 12, 114, 4, 4, secondary)
    box("fill", linkX + linkWidth + 8, 114, 4, 4, secondary)
    text(linkStatus, linkX, 112, primary)
    if math.floor(love.timer.getTime() * 2) % 2 == 0 then
      centered(THEME:translate("START GAME"), 128, foreground)
    end
  end

  function displayRuntime.drawContinueArrow(x, y)
    box("fill", x + 2, y + 12, 6, 1, { 0, 0, 0, 0.38 })
    box("fill", x, y, 10, 2, render.PAPER)
    box("fill", x + 1, y + 2, 8, 2, render.PAPER)
    box("fill", x + 2, y + 4, 6, 2, render.PAPER)
    box("fill", x + 3, y + 6, 4, 2, render.PAPER)
    box("fill", x + 4, y + 8, 2, 2, render.PAPER)
    box("fill", x + 1, y + 1, 8, 1, render.MID)
    box("fill", x + 2, y + 2, 6, 2, render.MID)
    box("fill", x + 3, y + 4, 4, 2, render.MID)
    box("fill", x + 4, y + 6, 2, 2, render.MID)
  end

  local function drawDim(alpha, prompt)
    if THEME.style == "hgss" then
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:systemOverlay(alpha, prompt, love.timer.getTime())
      render.G.pop()
      return
    end
    displayRuntime.dimBackground(alpha)
    color({ 0, 0, 0, alpha })
    render.G.rectangle("fill", 0, 0, WIDTH, HEIGHT)
    if prompt then displayRuntime.drawContinueArrow(75, 122) end
  end

  local function namingKey(x, y, w, label, selected, raw)
    local pressed = THEME.style == "hgss"
      and THEME.hgss:beginPress(x, y, w, 15, true, 1, 4 / 3)
    label = tostring(label or "")
    local paperLuma = render.PAPER[1] * 0.2126
      + render.PAPER[2] * 0.7152 + render.PAPER[3] * 0.0722
    local inkLuma = render.INK[1] * 0.2126
      + render.INK[2] * 0.7152 + render.INK[3] * 0.0722
    local midLuma = render.MID[1] * 0.2126
      + render.MID[2] * 0.7152 + render.MID[3] * 0.0722
    local darkLuma = render.DARK[1] * 0.2126
      + render.DARK[2] * 0.7152 + render.DARK[3] * 0.0722
    local background = selected
      and (midLuma >= darkLuma and render.MID or render.DARK)
      or (paperLuma >= inkLuma and render.PAPER or render.INK)
    local foreground = paperLuma < inkLuma and render.PAPER or render.INK
    box("fill", x, y, w, 15, background)
    outline(x, y, w, 15, foreground)
    color(foreground)
    EngineFont.draw(label, x + math.floor((w - EngineFont.width(label)) / 2),
                    y + 3)
    if pressed then THEME.hgss:endPress(pressed) end
  end

  -- Game path [Gen 1/2]: Gen 2 stores text and zero-based keyboard coordinates; Gen 1 stores glyph arrays and an ED/end cell.
  function displayRuntime.namingModel(top, grid)
    local gen2 = top.screenId == "Gen2NamingScreen"
    local name = gen2 and top.text or table.concat(top.glyphs or {})
    local items = {}
    local caseRow = #grid
    if not gen2 then
      for row, cells in ipairs(grid) do
        if #cells == 1 and (cells[1] == "lower case" or cells[1] == "UPPER CASE"
            or cells[1] == "lower" or cells[1] == "UPPER") then caseRow = row end
      end
    end
    local displayRow = 0
    for row, cells in ipairs(grid) do
      if row ~= caseRow then
        displayRow = displayRow + 1
        for col, char in ipairs(cells) do
          if gen2 or char ~= "ED" then
            items[#items + 1] = { label = char == " " and "_" or char:gsub("<PK>", "PK"):gsub("<MN>", "MN"),
              row = displayRow, col = col, nativeRow = row }
          end
        end
      end
    end
    items[#items + 1] = { label = top.lower and "ABC" or "abc", action = "case" }
    items[#items + 1] = { label = "DEL", action = "delete" }
    items[#items + 1] = { label = "OK", action = "confirm" }
    return displayRuntime.NamingPage.model(name, items, top.maxLen or top.maxLength,
      gen2 and #name or #(top.glyphs or {}), mod.options:get("keyboard_layout")), items
  end

  local function drawNaming(top, grid)
    header(THEME:translate("NAME INPUT"))
    local gen2 = top.screenId == "Gen2NamingScreen"
    local name = gen2 and top.text or table.concat(top.glyphs or {})
    name = name == "" and "-" or name
    if THEME.style == "hgss" then
      render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:naming(displayRuntime.namingModel(top, grid))
      render.G.pop()
      return
    end
    local nameWidth = math.max(24, EngineFont.width(name) + 8)
    namingKey(math.floor((WIDTH - nameWidth) / 2), 20, nameWidth,
      name, false, true)
    for row, cells in ipairs(grid) do
      local y = 36 + (row - 1) * 17
      for col, label in ipairs(cells) do
        local left = 3 + math.floor((col - 1) * 154 / #cells)
        local right = 3 + math.floor(col * 154 / #cells)
        local shown = label == "lower case" and THEME:translate("LOWER")
          or label == "UPPER CASE" and THEME:translate("UPPER") or label
        local selected
        if gen2 then
          selected = top.row == row - 1
            and (row < #grid and top.col == col - 1
              or row == #grid and math.floor(top.col / 3) + 1 == col)
        else
          selected = top.row == row and top.col == col
        end
        namingKey(left, y, right - left, shown, selected)
      end
    end
  end

  function displayRuntime.choiceState(top, field, labels)
    local state = displayRuntime.touchChoice
    local key = tostring(field) .. ":" .. table.concat(labels, "\31")
    if not state or state.owner ~= top or state.key ~= key then
      state = { owner = top, key = key, page = 1 }
      displayRuntime.touchChoice = state
    end
    return state
  end

  function displayRuntime.choiceModel(top, labels, prompt, field)
    local state = top.choiceState or displayRuntime.choiceState(top, field, labels)
    -- Game path [Gen 2]: the save printer owns its question text; ordinary stacked TextBox lookup cannot supply that prompt.
    if not prompt and top.screenId == "Gen2SaveMenu" and type(top.promptText) == "function" then
      prompt = top:promptText():gsub("[\v\f]", "\n")
    end
    if not prompt and not displayRuntime.gen3 and session.game.stack:top() == top then
      local states = session.game.stack.states or {}
      local text = states[#states - 1]
      if text and text.isTextBox then
        prompt = type(text.visibleText) == "function" and text:visibleText()
          or text.pages and text.pages[text.pageIndex or 1]
      end
    end
    if type(prompt) == "string" then prompt = { prompt } end
    if not prompt or #prompt == 0 then prompt = { THEME:translate("MAKE A CHOICE") } end
    local lines = THEME:messageLines(prompt, 34, 3)
    return displayRuntime.ChoicePage.model(state, labels, lines,
      top.choiceState and top.index or compat.choiceIndex(top, field))
  end

  function displayRuntime.learningChoiceContext(top)
    local learn = displayRuntime.moveLearnScreen()
    if learn and not learn.selecting then return learn end
    local raw = battleState()
    local pending = raw and raw.pendingLearn
    if top == raw and pending and (raw.phase == "ask-forget" or raw.phase == "stop-learning") then
      local mon = raw.battle and raw.battle.party and raw.battle.party[pending.index]
      if mon then return { mon = mon, newMoveId = pending.move } end
    end
  end

  function displayRuntime.learningPromptModel(learn, choice, labels, prompt, field)
    local mon = learn.mon
    local def = session.game.data.pokemon[mon.species] or {}
    local types = mon.types or def.types or {}
    local choices = {}
    for index, label in ipairs(labels or {}) do choices[index] = THEME:menuActionLabel(label) end
    local question = choice and displayRuntime.choiceModel(choice, choices, prompt, field)
    return { mon = { name = mon.nickname or mon.name or def.name or mon.species,
        levelText = THEME:format("L%d", mon.level or 0), type = types[1], type2 = types[2] or types[1],
        typeLabel = THEME:typeName(types[1], mod.content), type2Label = THEME:typeName(types[2] or types[1], mod.content) },
      newMove = hgssRuntime.moveView(learn.newMoveId), newLabel = THEME:translate("NEW"),
      details = assist("move_details"), choices = question and choices,
      selection = question and compat.choiceIndex(choice, field or "index"),
      enabled = choice ~= nil, prompt = question and question.prompt,
      drawPokemon = function(x, y, size)
        drawSprite(mon.species, "front", x, y, size, size, nil, learn.rawMon or mon.source or mon)
      end }
  end

  function displayRuntime.tapLearningPrompt(learn, choice, labels, prompt, field, x, y)
    local model = displayRuntime.learningPromptModel(learn, choice, labels, prompt, field)
    local action = displayRuntime.MovePage.promptHit(model, x * THEME.hgssScale, y * THEME.hgssScale)
    if action == "new" then session.moveInfo, session.dirty = compat.moveInfoEntry(learn.newMoveId), true
    elseif type(action) == "number" then displayRuntime.commitDialogueChoice(choice, field, action) end
  end

  local function drawDialogueChoice(top, labels, prompt, field)
    header(THEME:translate("CHOOSE"))
    local selected = compat.choiceIndex(top, field)
    local rows, cols, left, topY, cellW, cellH, gap =
      compat.choiceGrid(top, field, #labels)
    if THEME.style == "hgss" then
      local learn = displayRuntime.learningChoiceContext(top)
      if learn then
        header(THEME:translate("NEW MOVE"))
        render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        displayRuntime.MovePage.drawPrompt(THEME.hgss,
          displayRuntime.learningPromptModel(learn, top, labels, prompt, field))
        render.G.pop()
        return
      end
      local model = displayRuntime.choiceModel(top, labels, prompt, field)
      model.nudge = session.choiceNudgeUntil > love.timer.getTime()
      render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:choiceScreen(model)
      render.G.pop()
      return
    end
    if rows then
      for row = 1, rows do
        for col = 1, cols do
          local index = (row - 1) * cols + col
          button(left + (col - 1) * (cellW + gap),
                 topY + (row - 1) * (cellH + gap), cellW, cellH,
                 labels[index], selected == index, true)
        end
      end
    elseif #labels == 2 then
      local lines = THEME:messageLines(prompt, 24, 3)
      if #lines > 0 then
        local y = 35 - (#lines - 1) * 6
        for _, line in ipairs(lines) do
          centered(line, y, render.DARK, nil, true)
          y = y + 12
        end
      else
        centered(THEME:translate("MAKE A CHOICE"), 37, render.DARK)
      end
      button(24, 58, 112, 28, labels[1], selected == 1, true)
      button(24, 91, 112, 28, labels[2], selected == 2, true)
    else
      local start, count = choiceWindow(labels, selected)
      for row = 1, count do
        local index = start + row - 1
        button(8, 24 + (row - 1) * 27, 144, 24,
               labels[index], selected == index, true)
      end
    end
    if session.choiceNudgeUntil > love.timer.getTime() then
      centered(THEME:translate("PAUSE THEN CHOOSE"), 134, render.DARK)
    end
  end

  function displayRuntime.levelUpModel(mon, gain, stats, source)
    local model = displayRuntime.LevelUp.model(mon, session.game.data, gain or displayRuntime.levelUp:get(mon), stats)
    model.level = THEME:format("L%d", model.level or 0)
    if model.from then model.level = THEME:format("L%d", model.from) .. " → " .. model.level end
    model.drawPokemon = function(x, y, size)
      drawSprite(mon.species, "front", x, y, size, size, nil, source or mon.source or mon)
    end
    return model
  end

  local function drawLevelUpStats(mon)
    local model = displayRuntime.levelUpModel(mon)
    header(THEME:translate("LEVEL UP"))
    if THEME.style == "hgss" then
      render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:levelUp(model)
      render.G.pop()
      return
    end
    centered(fit(model.name .. "  " .. model.level, 24), 27, render.DARK, nil, true)
    local splitSpecial = #model.rows == 6
    local firstY, step = 38, splitSpecial and 11 or 13
    for i, row in ipairs(model.rows) do
      local y = firstY + (i - 1) * step
      text(THEME:translate(row.label), 24, y, render.INK)
      local value = row.value == nil and "--" or tostring(row.value)
      if row.delta ~= nil then value = value .. " " .. string.format("%+d", row.delta) end
      text(value, 154 - THEME:textWidth(value), y, render.DARK)
    end
    button(24, splitSpecial and 111 or 108, 112, 27,
      THEME:translate("CONTINUE"), false)
  end

  return choiceWindow, drawDialogueChoice, drawDim, drawLevelUpStats, drawNaming, drawTitle, trackChoice
end
