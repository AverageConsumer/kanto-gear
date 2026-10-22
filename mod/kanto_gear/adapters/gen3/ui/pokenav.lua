return function(UI)
  -- PokéNav (Ruby/Sapphire and Emerald): the device's own menus — main,
  -- Condition and Condition Search — become a touch list. The screens behind
  -- them (map, Match Call, graphs, ribbons) keep their native controls.
  local POKENAV_RSE = { [0] = "HOENN MAP", "CONDITION", "MATCH CALL", "RIBBONS", "SWITCH OFF",
    "PARTY", "SEARCH", "CANCEL", "COOL", "BEAUTY", "CUTE", "SMART", "TOUGH", "CANCEL" }
  local POKENAV_RSE_ICON = { [0] = "pn_map", "pn_condition", "pn_matchcall", "pn_ribbons", "pn_off",
    "pn_party", "pn_search", "pn_back", "pn_cool", "pn_beauty", "pn_cute", "pn_smart", "pn_tough", "pn_back" }
  local POKENAV_RS = {
    main = { { "HOENN MAP", "pn_map" }, { "CONDITION", "pn_condition" }, { "TRAINER'S EYES", "pn_eyes" },
      { "RIBBONS", "pn_ribbons" }, { "SWITCH OFF", "pn_off" } },
    condition = { { "PARTY", "pn_party" }, { "SEARCH", "pn_search" }, { "CANCEL", "pn_back" } },
    search = { { "COOL", "pn_cool" }, { "BEAUTY", "pn_beauty" }, { "CUTE", "pn_cute" },
      { "SMART", "pn_smart" }, { "TOUGH", "pn_tough" }, { "CANCEL", "pn_back" } },
  }
  -- Three choices stack as wide keys; four to six become a two-column grid
  -- of tiles (an odd last tile spans the row), like the DS touch menus.
  function UI.pokenavRect(index, count)
    if count <= 3 then
      local step = math.min(44, math.floor(130 / count))
      return { 7, 36 + (index - 1) * step, 226, step - 4 }
    end
    local rows = math.ceil(count / 2)
    local step = math.floor(132 / rows)
    local col, line = (index - 1) % 2, math.floor((index - 1) / 2)
    if count % 2 == 1 and index == count then return { 7, 36 + line * step, 226, step - 4 } end
    return { 7 + col * 116, 36 + line * step, 110, step - 4 }
  end
  function UI:pokenav(layer, appActive)
    -- Game path [Ruby/Sapphire vs Emerald]: Trainers Eyes uses shell menus; Match Call uses a MainMenu screen and task-based busy state.
    local rs = layer.id == "rs_pokenav"
    local ok, Nav = pcall(require, rs and "src.ui.game3.rs.pokenav.init" or "src.ui.game3.rse.pokenav.init")
    if not ok or type(Nav) ~= "table" or not Nav.active then return nil end
    local shell = Nav.active()
    if not shell then return nil end
    local items, key, menu, screen, help = {}, nil, nil, nil, nil
    if rs then
      if shell.phase ~= "active" or shell.feature or not POKENAV_RS[shell.menu] then return nil end
      menu = shell.menu
      for i, row in ipairs(POKENAV_RS[menu]) do
        if menu ~= "main" or shell.rows[i] then
          items[#items + 1] = { label = row[1], icon = row[2], nativeSlot = i - 1 }
        end
      end
      local nav = shell.nav and shell.nav.menus and shell.nav.menus[menu]
      help = nav and nav.help and nav.help[(shell.helpOverride or shell.cursor + 1)]
      key = "rs:" .. tostring(shell) .. ":" .. menu .. ":" .. #items
    else
      local MainMenu = require("src.ui.game3.rse.pokenav.main_menu")
      screen = shell.screen
      if shell.phase ~= "menu" or getmetatable(screen) ~= MainMenu then return nil end
      menu = screen.menuType
      for pos, id in ipairs(MainMenu.ITEMS[menu] or {}) do
        items[#items + 1] = { label = POKENAV_RSE[id] or "?", icon = POKENAV_RSE_ICON[id], nativeSlot = pos - 1, itemId = id }
      end
      local gotHelp, text = pcall(function()
        return screen.description and require("src.ui.game3.rse.pokenav.gfx").plain(screen.description)
      end)
      help = gotHelp and text or nil
      key = "rse:" .. tostring(shell) .. ":" .. tostring(screen) .. ":" .. tostring(menu)
    end
    if #items == 0 then return nil end
    -- Big touch keys above a message window: up to three rows, otherwise
    -- a two-column grid with a full-width final tile for odd counts.
    for i, row in ipairs(items) do
      row.value = row.icon
      row.rect = UI.pokenavRect(i, #items)
    end
    local function current()
      if rs then return shell.cursor end
      return screen.cursorPos
    end
    local function busy()
      if rs then return (shell.busy or 0) > 0 end
      return shell:busy(shell.screenTask) or shell:busy(shell.loopTask) or screen.targetMenuId ~= nil
    end
    for _, row in ipairs(items) do row.inert = busy() end
    local view = self.pokenavView
    if not view or view.nativeKey ~= key then
      local owner = self
      view = { screenId = "Gen3Menu", nativeKey = key, update = function() end, title = "POKéNAV",
        pokenav = true,
        valid = function(preview)
          if (appActive and not appActive() or not appActive and owner.Stack.top() ~= layer)
              or Nav.active() ~= shell then return false end
          if rs then
            if shell.phase ~= "active" or shell.feature or shell.menu ~= menu then return false end
          elseif shell.phase ~= "menu" or shell.screen ~= screen or screen.menuType ~= menu then return false end
          return preview or not busy()
        end }
      setmetatable(view, {
        __index = function(t, k)
          if k ~= "index" then return nil end
          local slot = current()
          for i, row in ipairs(t.items or {}) do if row.nativeSlot == slot then return i end end
          return 1
        end,
        __newindex = function(t, k, v)
          if k ~= "index" then rawset(t, k, v); return end
          local row = t.items and t.items[v]
          if not row or not t.valid() or current() == row.nativeSlot then return end
          if rs then
            shell.cursor, shell.helpOverride = row.nativeSlot, nil
          else
            if screen.handler == "cant_ribbons" and screen.setInputHandler then screen:setInputHandler() end
            screen.cursorPos = row.nativeSlot
            screen.currMenuItem = row.itemId
            if screen.cursorMovedAnimations then screen:cursorMovedAnimations() end
            if screen.printDescription then screen:printDescription() end
          end
        end,
      })
      self.pokenavView = view
    end
    view.items, view.pokenavHelp, view.fixedLayout = items, help, true
    view.pokenavRs = rs
    return view
  end
end
