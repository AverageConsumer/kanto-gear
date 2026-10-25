return function(THEME, displayRuntime, mod, render, resetSwapState, session)
  local Model = assert(load(mod:read("core/display_setup.lua"), "@kanto_gear/core/display_setup.lua"))()
  local View = assert(load(mod:read("ui/display_setup.lua"), "@kanto_gear/ui/display_setup.lua"))()
  local state = Model.new(THEME.displaySetupFresh)
  displayRuntime.displaySetup = state
  local buttons = { "up", "down", "left", "right", "a", "b", "start", "select", "l", "r" }
  local bridge, layout, pointers, testImage, nextProbe, nextPush = nil, nil, {}, nil, 0, 0
  local nextSafety = 0
  local function now() return love.timer.getTime() end
  local function requested() return state.sessionMode or mod.options:get("display_mode") or THEME.displayModeDefault end
  local function held(input)
    for _, key in ipairs(buttons) do if input:isDown(key) then return true end end
    return false
  end
  local function online(game)
    return game and (game.phase == "arena" or game.linkSession or game.linkNet and not game.linkNet.closed)
  end
  local function safe(game)
    if online(game) or displayRuntime.gearModules.anyShown() then return false end
    local top = game.stack and game.stack:top()
    if top and (top.screenId == "TitleState" or top.screenId == "Gen2TitleState") then return true end
    -- Host path [Gen 3]: boot has no GB state stack. Its settled title/menu
    -- phases are safe; copyright, opening cinema and Oak remain uninterrupted.
    if game.generation == 3 and game.phase == "boot" and game.boot and not game.boot.custom then
      return game.boot.phase == "title" or game.boot.phase == "menu"
    end
    -- Public eligibility includes menus, moving players, scripts, warps and
    -- battles in all generations. Unknown/busy states defer the modal.
    if not (mod.world and mod.world.availableFieldActions) then return false end
    local ok, actions, reason = pcall(mod.world.availableFieldActions, mod.world)
    return ok and type(actions) == "table" and reason == nil
  end
  local function look()
    return { font=THEME.hgssFont, small=THEME.hgssSmallFont,
      fontMetrics=THEME.hgssFontMetrics, smallMetrics=THEME.hgssSmallMetrics,
      skin=THEME.style=="hgss" and THEME.hgss.skinName or "pokegear",
      dark=THEME.style=="hgss" and THEME.hgss.dark==true or THEME.style=="modern_dark" }
  end
  local function applyOverride()
    local override = state:override()
    if override ~= THEME.displayModeOverride then
      THEME.displayModeOverride = override
      resetSwapState()
    end
    displayRuntime.displaySetupModal = state.stage ~= nil or state.draining
  end
  local function finish(mode)
    if mode == "combined" then
      mod.options:set("combined_layout", "auto")
      mod.options:set("combined_primary", "game")
    elseif mode == "fullscreen" then mod.options:set("fullscreen_start", "game")
    elseif mode == "separate" then mod.options:set("display_target", "auto") end
    local saved = mod.options:set("display_mode", mode) ~= false
    -- A read-only options file must not turn setup into another softlock.
    -- Keep this session visible and retry first-use persistence next launch.
    if not saved then mode, state.sessionMode = "combined", "combined"
    else
      state.sessionMode = nil
      if mod.cache and mod.cache.write then mod.cache:write(Model.MARKER, "done") end
      THEME.displaySetupFresh = false
    end
    state.mode, state.fallback, state.missingSince = mode, false, nil
    state:close()
    layout, pointers = nil, {}
    applyOverride()
    resetSwapState()
  end
  local function action(index)
    if state.stage == "test" then
      if index == 1 and state.healthy then finish("separate")
      elseif index == 2 then finish("combined") end
    elseif state.stage == "recovery" then
      if index == 1 then finish("combined")
      elseif index == 2 then state:test(now()); nextPush = 0 end
    elseif state.stage == "welcome" then
      local mode = Model.choices[index]
      if mode == "separate" then state:test(now()); nextPush = 0
      elseif mode then finish(mode) end
    end
    pointers, layout = {}, nil
    applyOverride()
  end

  function displayRuntime.updateDisplaySetup(game)
    if game ~= displayRuntime.sourceGame or not session.active then return false end
    if online(game) or displayRuntime.gearModules.anyShown() then
      state.stage, state.draining, layout, pointers = nil, false, nil, {}
      state.missingSince, state.healthy = nil, false
      applyOverride()
      return false
    end
    local input = game.input
    if not (input and input.step and input.isDown and input.wasPressed) then return false end
    local time = now()
    state:tick(time, requested(), state.healthy == true, false)
    -- Eligibility builds native field-action records. Query it only while a
    -- choice is waiting, at a bounded rate, never throughout normal gameplay.
    if not state.stage and not state.draining and (state.pending or state.recoveryPending)
        and time >= nextSafety then
      nextSafety = time + .1
      if not held(input) and safe(game) then state:tick(time, requested(), state.healthy == true, true) end
    end
    applyOverride()
    if not (state.stage or state.draining) then return false end
    -- core.update owns the pause: no native fixed step, movement, script,
    -- battle timer or play-time update runs while this modal owns input.
    input:step()
    if state.draining then
      if not held(input) then state.draining = false; applyOverride() end
      return true
    end
    if not state.armed then
      if not held(input) then state.armed = true end
      return true
    end
    local count = state.stage == "welcome" and 4 or 2
    if input:wasPressed("b") then
      if state.stage == "test" then
        state.stage, state.selected, state.armed = state.fallback and "recovery" or "welcome", 1, false
        layout, pointers = nil, {}
      else finish("combined") end
    elseif input:wasPressed("up") or input:wasPressed("left") then
      state.selected = (state.selected - 2) % count + 1
      if state.stage == "test" and not state.healthy then state.selected = 2 end
    elseif input:wasPressed("down") or input:wasPressed("right") then
      state.selected = state.selected % count + 1
      if state.stage == "test" and not state.healthy then state.selected = 2 end
    elseif input:wasPressed("a") then action(state.selected) end
    applyOverride()
    return true
  end

  function displayRuntime.displaySetupPointer(event)
    if not displayRuntime.displaySetupModal then return false end
    local id = event.id or "mouse"
    local function at()
      if not (state.stage and state.armed and layout and layout.stage == state.stage) then return end
      for index, b in ipairs(layout.buttons) do
        if b.enabled and (event.x or -1) >= b.x and event.x < b.x+b.w
            and (event.y or -1) >= b.y and event.y < b.y+b.h then return index end
      end
    end
    if event.phase == "pressed" then
      pointers[id] = { index=(event.button==nil or event.button==1) and at() or nil, layout=layout }
    elseif event.phase == "moved" then
      if pointers[id] and pointers[id].index ~= at() then pointers[id].index = nil end
    elseif event.phase == "released" or event.phase == "cancelled" then
      local pressed = pointers[id]; pointers[id] = nil
      if event.phase == "released" and pressed and pressed.index and pressed.index == at() and pressed.layout == layout then
        action(pressed.index)
      end
    end
    return true
  end

  function displayRuntime.drawDisplaySetup(game, viewport)
    if game ~= displayRuntime.sourceGame or not state.stage then layout = nil; return end
    local stage = state.stage
    state.remaining = stage == "test" and state.deadline - now() or 0
    local previous = layout
    layout = View.draw(render.G, viewport, state, look())
    if previous and previous.width == layout.width and previous.height == layout.height and previous.stage == stage then
      -- Paint frames do not invalidate a held touch; resize/stage changes do.
      for _, pointer in pairs(pointers) do if pointer.layout == previous then pointer.layout = layout end end
    end
    return layout
  end

  function displayRuntime.setupWantsSecond()
    return state.stage == "test" or state.fallback and requested() == "separate"
  end

  function displayRuntime.requestDisplaySetup()
    if state.pending or state.stage or state.draining then return false end
    -- Use the engine's scoped writer: Android file managers cannot always
    -- access this cache. Queue the same safe boundary as first use.
    if mod.cache and mod.cache.write then mod.cache:write(Model.MARKER, "pending") end
    state.pending, nextSafety = true, 0
    return true
  end

  function displayRuntime.observeSetupDisplay(native)
    if native ~= bridge then bridge, nextProbe, nextPush, state.healthy = native, 0, 0, false end
    local time = now()
    if requested() ~= "separate" and state.stage ~= "test" and state.stage ~= "welcome" then
      state.healthy = false
      return
    end
    if time < nextProbe then return end
    nextProbe = time + .25
    local ok, detected = false, false
    if bridge and bridge.detected then
      ok, detected = pcall(displayRuntime.detectNativeDisplay, bridge, time)
    end
    state.candidate = ok and detected == true
    local ready = ok and detected == true
    if ready and bridge.available then local success, value = pcall(bridge.available); ready = success and value == true end
    if state.stage == "test" then
      state.healthy = false
      if bridge and bridge.setEnabled then pcall(bridge.setEnabled, true) end
      if ready and bridge.push and time >= nextPush then
        nextPush = time + .25
        if not testImage then
          local G = render.G
          local canvas = G.newCanvas(240,216,{dpiscale=1})
          local previousCanvas = G.getCanvas and G.getCanvas()
          G.push("all"); G.setCanvas(canvas); G.setScissor(); G.clear(0,0,0,1)
          View.test(G,look()); G.pop()
          G.setCanvas(previousCanvas)
          testImage = canvas:newImageData(); canvas:release()
        end
        local success, shown = pcall(bridge.push,testImage,240,216,displayRuntime.backgroundColor(),"auto")
        state.healthy = success and shown == true
      end
    else
      -- Availability belongs to the physical output, not whether Gear has
      -- already painted a frame (boot, loading and modal ownership can defer it).
      state.healthy = ready and requested()=="separate" and not state.fallback
    end
  end

  mod.events:on("game.ready", function()
    if testImage then testImage:release(); testImage = nil end
    state:bind(now(),requested())
    bridge, layout, pointers, nextProbe, nextPush, nextSafety = nil, nil, {}, 0, 0, 0
    applyOverride()
  end)
  function displayRuntime.clearDisplaySetup()
    if testImage then testImage:release(); testImage=nil end
    state.stage, state.draining, state.fallback, layout, pointers = nil, false, false, nil, {}
    applyOverride()
  end
  return state
end
