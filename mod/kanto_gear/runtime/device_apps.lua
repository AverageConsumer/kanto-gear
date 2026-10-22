return function(THEME, compat, displayRuntime, header, render, screenState, session)
  local keys = { "left", "up", "down", "right", "a", "b" }
  local labels = { "<", "^", "v", ">", "A", "B" }
  local navSlots = { map = 0, condition = 1, contacts = 2, ribbons = 3 }
  local function keyRect(index) return 8 + (index - 1) * 38, 192, 34, 23 end

  -- Read the device's own unlock inventory without constructing or opening it.
  function displayRuntime.deviceTargetUnlocked(id, target)
    if not target then return true end
    if id == "pokegear" then
      if displayRuntime.gen3 or not compat.isGen2() then return false end
      local Pokegear = require("src.ui.gen2.Pokegear")
      local reader = setmetatable({ save = session.game.save }, Pokegear)
      for _, card in ipairs(reader:visibleCards()) do
        if card.id == target then return true end
      end
    elseif id == "pokenav" then
      local a, slot = displayRuntime.gen3, navSlots[target]
      if not a or not a.hoenn or not a.session or not slot then return false end
      if a.rs then return require("src.ui.game3.rs.pokenav.data").mainRows(a.session)[slot + 1] == true end
      local Menu = require("src.ui.game3.rse.pokenav.main_menu")
      for _, item in ipairs(Menu.ITEMS[Menu.mainMenuType(a.session)]) do
        if item == slot then return true end
      end
    end
    return false
  end

  function displayRuntime.refreshDeviceSurfaces()
    local a = displayRuntime.gen3
    for _, def in ipairs(displayRuntime.deviceShortcuts) do
      local surface = displayRuntime.homeCatalog.surfaces[def.package .. "_" .. def.target .. "_widget"]
      local supported = displayRuntime.homeCatalog.packages[def.package].available ~= false
      surface.hidden = not supported or not displayRuntime.deviceTargetUnlocked(def.package, def.target)
      surface.label, surface.icon = def.label, def.icon
      if def.target == "contacts" and a and a.rs then
        surface.label, surface.icon = "TRAINER'S EYES", "pn_eyes"
      end
    end
  end

  function displayRuntime.closeDeviceApp()
    local app = displayRuntime.deviceApp
    displayRuntime.deviceApp, displayRuntime.pendingDeviceApp = nil, nil
    if app then
      if app.id == "pokegear" and app.native then app.native:stopRadio()
      elseif app.nav and app.nav.active() == app.native then
        if not app.rs and app.native.screen and app.native.screen.free then app.native.screen:free() end
        app.nav.reset()
      end
    end
    displayRuntime.home.activeApp = nil
    if session.page == "POKEGEAR" or session.page == "POKENAV" then session.page = "HOME" end
    session.dirty = true
  end

  function displayRuntime.applyDeviceSupport()
    displayRuntime.closeDeviceApp()
    local gen3 = displayRuntime.gen3
    local supported = { pokegear = compat.isGen2() and not gen3,
      pokenav = gen3 and gen3.hoenn or false }
    for id, value in pairs(supported) do
      displayRuntime.storeById[id].hidden = not value
      displayRuntime.homeCatalog.packages[id].available = not not value
      displayRuntime.homeCatalog.surfaces[id .. "_app"].hidden = not value
    end
    displayRuntime.refreshDeviceSurfaces()
  end

  function displayRuntime.canOpenDeviceApp(id, target)
    if not session.active or THEME.style ~= "hgss" or screenState() ~= "active"
        or displayRuntime.pendingDeviceApp then return false end
    if not displayRuntime.deviceTargetUnlocked(id, target) then return false end
    if id == "pokegear" then
      if displayRuntime.gen3 or not compat.isGen2() then return false end
      return require("src.ui.gen2.StartMenu").availability({ game = session.game, save = session.game.save }).pokegear == true
    elseif id == "pokenav" then
      local a = displayRuntime.gen3
      if not a or not a.hoenn or not a.session or a.game.phase ~= "field" then return false end
      local defs = a.flagDefinitions.IDS
      local id = defs and defs.FLAG_SYS_POKENAV_GET
      return id ~= nil and a.Flags.getFlag(a:flagStore(), nil, id) == true
    end
    return false
  end

  function displayRuntime.queueDeviceApp(id, target)
    if not displayRuntime.canOpenDeviceApp(id, target) then return false end
    local game = displayRuntime.sourceGame
    displayRuntime.pendingDeviceApp = { id = id, game = game, save = game.save,
      nativeSession = displayRuntime.gen3 and displayRuntime.gen3.session,
      top = session.game.stack:top(), target = target }
    return true
  end

  local function exists(app)
    return displayRuntime.deviceApp == app and session.active and THEME.style == "hgss"
      and session.page == app.id:upper()
      and displayRuntime.sourceGame == app.game and (app.nav or app.game.save == app.save)
      and (not app.nav or displayRuntime.gen3 and displayRuntime.gen3.session == app.nativeSession
        and app.nav.active() == app.native)
  end

  local function active(app) return exists(app) and screenState() == "active" end

  local function ready(app)
    if not active(app) then return false end
    if not app.nav then return true end
    local n = app.native
    if app.rs then return n.phase == "active" and (n.busy or 0) == 0 end
    return n.phase == "menu" and not n:busy(n.screenTask) and not n:busy(n.loopTask)
      and not (n.screen and n.screen.targetMenuId)
  end

  local function refresh(app)
    local live = function() return active(app) end
    if app.id == "pokegear" then
      app.view = displayRuntime.PokegearPage.project(app.native, session.game, app.view, live)
    else
      app.view = displayRuntime.gen3Ui:pokenav(app.layer, live)
    end
  end

  -- Private device input never reads, consumes or queues a game button. The
  -- original overworld remains the only state on the native input stack.
  function displayRuntime.stepDeviceApps(game, dt)
    if game ~= displayRuntime.sourceGame then return end
    if displayRuntime.gen3 then displayRuntime.gen3.syncScreens() end
    local pending = displayRuntime.pendingDeviceApp
    if pending then
      displayRuntime.pendingDeviceApp = nil
      if game == pending.game and game.save == pending.save
          and session.game.stack:top() == pending.top
          and displayRuntime.canOpenDeviceApp(pending.id, pending.target) then
        displayRuntime.closeDeviceApp()
        local app = pending
        app.pressed = {}
        app.input = { wasPressed = function(_, key)
          local value = app.pressed[key]; app.pressed[key] = nil; return value == true
        end, isDown = function() return false end }
        app.proxy = setmetatable({ input = app.input }, { __index = game, __newindex = game })
        displayRuntime.deviceApp = app
        session.page, displayRuntime.home.activeApp = app.id:upper(), app.id
        if app.id == "pokegear" then
          app.native = require("src.ui.gen2.Pokegear").new(app.proxy, {
            onClose = displayRuntime.closeDeviceApp,
            onCall = function(call)
              if active(app) and game.runPokegearCall then return game:runPokegearCall(call) end
              return false
            end,
          })
          if app.target then
            for index, card in ipairs(app.native.cards) do
              if card.id == app.target then app.native.cardIndex, app.native.mode = index, "card"; break end
            end
            app.target = nil
          end
        else
          local a = displayRuntime.gen3
          app.rs = a.rs
          app.nav = require("src.ui.game3.screens").get("pokenav", a.session)
          app.native = app.nav.show({ session = a.session, game = app.proxy })
          app.layer = displayRuntime.gen3Ui.Stack.top()
          -- The native shell keeps its own animations and features, but its
          -- modal layer must never pause or receive controls from the field.
          displayRuntime.gen3Ui.Stack.pop(app.layer.id)
          app.native.close = function() displayRuntime.closeDeviceApp() end
        end
      end
    end
    local app = displayRuntime.deviceApp
    if not app then return end
    if not exists(app) then displayRuntime.closeDeviceApp(); return end
    if not active(app) then
      app.pressed = {}
      -- Pause behind field dialogue, map transitions and battles. The native
      -- start menu may open the same PokéNav singleton, so release ours first.
      local layer = app.nav and displayRuntime.gen3Ui.Stack.top()
      if layer and layer.id == "start_menu" then displayRuntime.closeDeviceApp() end
      return
    end
    if app.nav then
      -- Wait for the native opening animation, select its real main-menu row,
      -- then confirm through private input exactly once. Hardware stays above.
      if app.target and ready(app) then
        refresh(app)
        for index, row in ipairs(app.view and app.view.items or {}) do
          if row.nativeSlot == navSlots[app.target] then
            app.view.index, app.pressed.a = index, true
            break
          end
        end
        app.target = nil
      end
      app.nav.Host.handleInput(app.input)
      app.nav.Host.update(dt or 1 / 60)
    else
      if game.currentLandmark then app.native.currentLandmark = game:currentLandmark() end
      app.native:update(dt or 1 / 60)
    end
    app.pressed = {}
    if displayRuntime.deviceApp == app then refresh(app) end
    session.dirty = true
  end

  function displayRuntime.drawDeviceApp()
    local app = displayRuntime.deviceApp
    if not app or not active(app) then return end
    refresh(app)
    if app.view then displayRuntime.drawStartMenu(app.view); return end
    header("POKéNAV", true)
    local G, H = render.G, THEME.hgss
    G.push("all"); G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    G.push("all"); G.setScissor(0, 31, 240, 160)
    G.translate(0, 31); app.native:draw(); G.pop()
    -- Feature screens without a Gear projection retain their native 240x160
    -- pixels and get touch-only controls. Unknown native key boundaries have
    -- no speculative press animation; the device itself shows the result.
    for index, label in ipairs(labels) do
      local x, y, w, h = keyRect(index)
      H:v4Key(x, y, w, h)
      H:partyInfoCentered(label, x, y - 1, w, h - 2, H.colors.ink)
    end
    G.pop()
  end

  function displayRuntime.tapDeviceApp(x, y)
    local app = displayRuntime.deviceApp
    if not app or app.target or not ready(app) then return end
    refresh(app)
    local press = function(key) app.pressed[key] = true end
    if app.id == "pokegear" then
      local action, arg = displayRuntime.PokegearPage.hit(app.view.pokegearModel, x, y)
      if action then displayRuntime.PokegearPage.apply(app.view, action, arg, press) end
    elseif app.view then
      if y < 30 and x < 27 then press("b")
      else
        local index = displayRuntime.StartMenu.hit(app.view, x, y)
        if type(index) == "number" and displayRuntime.StartMenu.select(app.view, index) then press("a") end
      end
    elseif y < 30 and x < 27 then press("b")
    else
      for index, key in ipairs(keys) do
        local rx, ry, rw, rh = keyRect(index)
        if x >= rx and x < rx + rw and y >= ry and y < ry + rh then press(key); break end
      end
    end
    session.dirty = true
  end
end
