return function(
  HEADER, THEME, WIDTH, assist, box, clockText,
  compat, displayRuntime, fit, glyphList, hasItemfinder, mod,
  pcListKind, radarSignals, render, screenContract, session, text,
  textTouch
)
  local function battery(x, foreground)
    foreground = foreground or render.PAPER
    local state, percent = mod.device:powerInfo()
    local tick = math.floor(love.timer.getTime())
    local segments, blink, blinkVisible, tone, animated =
      THEME:batteryState(state, percent, tick)
    if animated ~= session.batteryAnimated then session.nextClock = 0 end
    session.batteryAnimated = animated
    if THEME.style == "hgss" then
      local colors = THEME.hgss.colors
      local fill = tone == "green" and colors.greenLight
        or tone == "amber" and colors.amberLight or colors.redLight
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:battery(214, 8, segments, blink, blinkVisible,
        foreground, fill)
      render.G.pop()
      return
    end
    local fill = tone == "green" and THEME.batteryGreen
      or tone == "amber" and THEME.batteryAmber or THEME.red
    box("line", x + 0.5, 6.5, 14, 7, foreground)
    box("fill", x + 14, 9, 2, 3, foreground)
    for segment = 1, 4 do
      if segment <= segments or segment == blink and blinkVisible then
        box("fill", x + 2 + (segment - 1) * 3, 8, 2, 4, fill)
      end
    end
  end

  local function header(title, back, paged, hgssContentOffsetY)
    title = tostring(title or "")
    local modern = THEME.style ~= "classic"
    local hgss = THEME.style == "hgss"
    local background = hgss and THEME.hgss.colors.surface
      or modern and (THEME.style == "modern_dark" and render.MID or render.DARK)
      or render.DARK
    local foreground = hgss and THEME.hgss.colors.ink
      or modern and THEME.white or render.PAPER
    local function put(value, x, y)
      if hgss then
        render.G.push()
        render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        THEME.hgss:label(value, x * THEME.hgssScale,
          (y - 2) * THEME.hgssScale, foreground)
        render.G.pop()
      else
        text(value, x, y, foreground)
      end
    end
    local function halfWidth(value)
      return hgss and math.floor(THEME.hgss:labelWidth(value)
        / THEME.hgssScale / 2)
        or math.floor(#glyphList(value) * 3)
    end
    if hgss then
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:headerBar(title, back, paged, hgssContentOffsetY)
      render.G.pop()
    else
      box("fill", 0, 0, WIDTH, HEADER, background)
    end
    if modern and not hgss then
      box("fill", 0, HEADER - 2, WIDTH, 2, THEME.blue)
      box("fill", 0, HEADER - 2, 42, 2, THEME.red)
    end
    if back and not hgss then
      put("<", 4, 6)
      box("fill", 16, 4, 1, 12, foreground)
    end
    if paged and not hgss then
      local label = fit(title, back and 8 or 10)
      local left, center = back and 22 or 4, back and 57 or 48
      put("<", left, 6)
      put(label, center - halfWidth(label), 6)
      put(">", 85, 6)
    elseif back and not hgss then
      put(fit(title, 11), 22, 6)
    elseif not hgss then
      put(fit(title, 14), 5, 6)
    end
    local now = os.time()
    local timestamp, period = compat.clockDisplay(session.game,
      mod.options:get("clock_source"), now)
    local clock = clockText(timestamp, mod.options:get("clock_format"),
      mod.datetime:time(session.game, timestamp))
    if hgss then
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:headerClock(clock, period, 139, 72, 6)
      render.G.pop()
    else
      if period and compat.isGen2() then clock = clock .. " " .. period:sub(1, 1) end
      put(clock, 117 - halfWidth(clock), 6)
    end
    battery(143, foreground)
  end

  local function stackHas(target)
    for _, state in ipairs(session.game and session.game.stack and session.game.stack.states or {}) do
      if state == target then return true end
    end
    return false
  end

  local function screenById(id)
    local ids = compat.screens[id]
    local states = session.game and session.game.stack and session.game.stack.states or {}
    for i = #states, 1, -1 do
      if (ids and ids[states[i].screenId])
          or (not ids and states[i].screenId == id) then return states[i] end
    end
  end

  -- Game path [Gen 1/2]: MoveLearnMenu and Gen2MoveDeleter/PackMenu expose different pending move and cursor fields.
  function displayRuntime.moveLearnScreen()
    local learn = screenContract(screenById("MoveLearnMenu"), "moveLearn")
    if learn then return learn end

    local picker = screenById("Gen2MoveDeleter")
    local pack = screenById("Gen2PackMenu")
    local pending = displayRuntime.bag.pending
    if picker and type(picker.mon) == "table"
        and type(picker.list) == "table" and picker.list == picker.mon.moves
        and type(picker.row) == "number" then
      local moveId = pending and pending.moveId
      if not moveId and pack and type(pack.rows) == "table"
          and type(pack.index) == "number" then
        local row = pack.rows[pack.index]
        local item = row and session.game and session.game.data and session.game.data.items
          and session.game.data.items[row.id]
        moveId = item and item.teaches
      end
      if moveId then
        return { native = picker, mon = picker.mon, newMoveId = moveId,
                 selecting = true, index = picker.row, field = pending ~= nil }
      end
    end

    local top = session.game and session.game.stack and session.game.stack:top()
    local textFlow = top and top.isTextBox
    for _, state in ipairs(session.game and session.game.stack and session.game.stack.states or {}) do
      if state.isTextBox then textFlow = true break end
    end
    if pending and pending.moveId and type(pending.mon) == "table"
        and textFlow and not screenContract(top, "party") then
      return { mon = pending.mon, newMoveId = pending.moveId,
               selecting = false, field = true }
    end
  end

  function displayRuntime.fieldBagParty()
    local pending = displayRuntime.bag.pending
    local top = session.game and session.game.stack and session.game.stack:top()
    local menu = not session.battle and pending and screenContract(top, "party")
    if not menu then return nil end
    local party = menu.party or (session.game.save and session.game.save.party) or {}
    if menu.index >= 1 and menu.index <= #party then
      pending.mon = party[menu.index]
    end
    local title = pending.moveId and "TEACH MOVE TO"
      or menu.prompt == "Give to which <PK><MN>?" and "GIVE ITEM TO"
      or "USE ITEM ON"
    return menu, party, title
  end

  -- Game path [Gen 2 vs Gen 1]: PP-Up limits use Gen 2s maxPp reader rather than the Gen 1 base-PP formula.
  function displayRuntime.moveChoiceRow(move, label)
    local def = session.game.data.moves[move.id]
    local base = def and def.pp or move.maxPp or move.pp or 0
    local maxPp = compat.isGen2() and require("src.battle.gen2.Mon").maxPpOf(move, session.game.data)
      or def and def.pp and base + (move.ppUps or 0) * math.floor(base / 5)
      or move.maxPp or base
    return { label = label or def and def.name or move.id or "MOVE", move = move,
      right = THEME:format("%d/%d", move.pp or 0, maxPp) }
  end

  -- Game path [Gen 1/2]: Gen 2 reuses MoveDeleter for PP targets; Gen 1 has MoveSelectMenu or an older Which move? list.
  function displayRuntime.fieldPpMoveScreen()
    local pending = displayRuntime.bag.pending
    local top = session.game and session.game.stack and session.game.stack:top()
    local picker = screenById("Gen2MoveDeleter")
    local mon, index, cursor = picker and picker.mon, picker and picker.row, "row"
    if picker and (picker.forget or pending and pending.moveId) then return nil end
    if not picker and not compat.isGen2() then
      if top and top.screenId == "MoveSelectMenu" and type(top.mon) == "table" then
        picker, mon, index, cursor = top, top.mon, top.index, "index"
      elseif pending and not pending.moveId and top
          and (top.kind == "Which move?" or top.title == "Which move?")
          and type(top.items) == "table" and type(top.index) == "number" then
        picker, mon, index, cursor = top, pending.mon, top.index, "index"
      end
    end
    if not (picker and top == picker and type(mon) == "table"
        and type(index) == "number" and type(mon.moves) == "table") then return nil end
    local selectedMoves = cursor == "row" and picker.list or mon.moves
    if type(selectedMoves) ~= "table" then return nil end
    local items = {}
    for slot, move in ipairs(selectedMoves) do
      items[slot] = displayRuntime.moveChoiceRow(move)
    end
    return { native = picker, items = items, index = index, cursor = cursor, mon = mon, itemId = pending and pending.itemId,
      enabled = picker.ready ~= false and not picker.done,
      valid = function() return session.game.stack:top() == picker and not picker.done and picker.ready ~= false end }
  end

  local function pcSession()
    local root = screenById("itemPc")
    if root and type(root.items or root.entries) == "table"
        and type(root.index) == "number" then return "items", root end
    root = screenById("pokemonPc")
    if root and type(root.items or root.entries) == "table"
        and type(root.index) == "number" then return "pokemon", root end
  end

  local function pcList()
    local states = session.game and session.game.stack and session.game.stack.states or {}
    for i = #states, 1, -1 do
      if pcListKind(states[i]) then return states[i] end
    end
  end

  local function battleState()
    local states = session.game and session.game.stack and session.game.stack.states or {}
    for i = #states, 1, -1 do
      if compat.isBattleScreen(states[i]) then return states[i] end
    end
  end

  -- Game path [Gen 2 vs Gen 1/3 projection]: Gen 2 keeps the world outside the menu stack; idle means no top menu rather than top==world.
  local function screenState()
    local top = session.game and session.game.stack and session.game.stack:top()
    local world = session.game and (session.game.overworld or session.game.world)
    if not (world and (compat.isGen2() and world.map or stackHas(world))) then
      session.worldStarted = false
      return "title", top, 0
    end
    if not session.worldStarted then
      if not compat.isGen2() and not displayRuntime.gen3 and top ~= world then return "title", top, 0 end
      session.worldStarted = true
    end
    if not compat.isGen2() and world.transitioning then
      local alpha = math.min(1, (top and top.t or 0)
        / math.max(1, top and top.frames or 1))
      if top and top.phase == "in" then alpha = 1 - alpha end
      return "transition", top, alpha
    end
    if session.externalLoading then return "loading", top, 0.72 end
    if top and (top.isTextBox or textTouch(top) ~= nil) then return "textbox", top, 0.58 end
    if world.flyAnim or world.teleportOut then return "locked", top, 0.58 end
    if (compat.isGen2() and not top) or top == world then return "active", top, 0 end
    return "locked", top, 0.58
  end

  function displayRuntime.finishScanFeedback()
    if mod.options:get("ui_haptics") ~= true
        or not session.active or THEME.style ~= "hgss" or session.page ~= "LOCAL" or session.battle
        or displayRuntime.overlayHidden or screenState() ~= "active"
        or displayRuntime.explorer.scanMapId ~= session.mapId
        or assist("hidden_items") or not assist("item_radar")
        or not hasItemfinder() then return end
    if #radarSignals() > 0 then displayRuntime.haptic("discover") end
  end

  -- Mod path [Gen 1/3]: Battle Art sprites are optional and require explicit battler ownership; Gen 2 deliberately keeps native art.
  local function attachBattleArtSprites(raw, snapshot)
    if compat.isGen2() or not (raw and snapshot) then return end
    local provider = mod.find("BATTLE_ART_VOXEL_FORK")
    local stage = provider and provider.exports
      and provider.exports.battleStage
    if not (stage and type(stage.state) == "function") then return end
    local ok, state = pcall(stage.state, raw)
    if not (ok and type(state) == "table" and state.staged == true
        and state.ownership and state.ownership.battlers == true) then
      return
    end
    for _, side in ipairs({ "player", "enemy" }) do
      local source = raw[side] or (raw.battle and raw.battle[side])
      local copy = snapshot[side]
      local image = source and source.sprite
      if copy and image and type(image.getDimensions) == "function" then
        copy.presentationSprite = image
      end
    end
  end

  return attachBattleArtSprites, battleState, header, pcList, pcSession, screenById, screenState
end
