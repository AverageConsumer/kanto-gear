-- Native FRLG does not call the legacy battle visibility hooks yet. Bridge
-- its presentation functions and Gear's owned command navigation.
local Presentation = {}
Presentation.__index = Presentation

function Presentation.new(owns, heroDirection)
  local self = setmetatable({ owns = owns, patches = {} }, Presentation)
  local function wrap(module, name, callback)
    local original = module[name]
    if type(original) ~= "function" then return end
    local fn = function(...) return callback(original, ...) end
    module[name] = fn
    self.patches[#self.patches + 1] = { module, name, original, fn }
  end
  local function hidden(kind)
    return self.owns and self.owns(kind) or false
  end
  local ui = require("src.core.game3.battle.ui")
  wrap(ui, "handleInput", function(next, input, ...)
    if input and heroDirection and hidden("heroNavigation") then
      -- Gear's large FIGHT button and lower three buttons are not a 2x2
      -- grid. Keep native semantic indices and the doubles cursor in sync.
      local pressed
      for _, direction in ipairs({ "left", "right", "up", "down" }) do
        if input:wasPressed(direction) then pressed = direction; break end
      end
      if pressed then
        ui.tick()
        if hidden("heroNavigation") and ui._mode == "menu" and ui.waitingForCommand()
            and not require("src.ui.game3.choice").active
            and not (ui._st and ui._st.oldManTutorial) then
          local order = { 1, 3, 2, 4 }
          local target = order[heroDirection(order[ui._menuIndex or 1], pressed)]
          if target ~= ui._menuIndex then
            ui._menuIndex = target
            ui._actionCursor[ui._active or 0] = target
            pcall(function()
              require("src.core.game3.audio").playSe(require("src.core.game3.se_ids").SE_SELECT)
            end)
          end
          -- Consume this press even at an edge; never also confirm a command.
          return true
        end
      end
      return next(input, ...)
    end
    if input and hidden("navigation") then
      -- FRLG: FIGHT/BAG above PARTY/RUN. Full Gear: FIGHT/PARTY above
      -- BAG/RUN. Transpose directions at the native handler, after Input.step,
      -- so keyboard, held controls and gamepads all keep the same authority.
      local directions = { left = "up", right = "down", up = "left", down = "right" }
      local source = input
      input = setmetatable({ wasPressed = function(_, key)
        return source:wasPressed(directions[key] or key)
      end }, { __index = source })
    end
    return next(input, ...)
  end)
  wrap(require("src.core.game3.battle.ui"), "draw", function(next, ...)
    local previous = self.drawing
    self.drawing = hidden("panel")
    local ok, err = pcall(next, ...)
    self.drawing = previous
    if not ok then error(err, 0) end
  end)
  local chrome = require("src.ui.game3.battle_chrome")
  -- Emerald draws user-selected menu borders separately from its textbox.
  -- Both belong to the relocated command panel, within the same draw scope.
  for _, name in ipairs({ "drawPanel", "drawMenuFrames" }) do
    wrap(chrome, name, function(next, ...)
      if not self.drawing then return next(...) end
    end)
  end
  wrap(chrome, "drawTerrain", function(next, key, ...)
    local drawn = next(key, ...)
    if self.drawing and drawn then
      local terrain = chrome.terrain(key or "building") or chrome.terrain("building")
        or chrome.terrain("grass")
      if terrain and terrain.bgImage then
        -- The ROM's lower 48 pixels are black beneath the original textbox.
        -- Continue the existing clean ground bands, before any actors/effects.
        -- Borrow the host texture; no readback, extraction or extra canvas.
        local G = love.graphics
        self.groundQuad = self.groundQuad or G.newQuad(0, 104, 240, 8, 256, 160)
        for y = 112, 152, 8 do G.draw(terrain.bgImage, self.groundQuad, 0, y) end
      end
    end
    return drawn
  end)
  -- These are the native action/move printers, below the battlefield. The
  -- scope ends before field, menu and Gear text is drawn, including on error.
  wrap(require("src.ui.game3.frlg_font"), "draw", function(next, text, x, y, ...)
    if self.drawing and y >= 112 then return 0, x, y end
    return next(text, x, y, ...)
  end)
  wrap(require("src.ui.game3.window"), "cursorPx", function(next, x, y, ...)
    if not self.drawing or y < 112 then return next(x, y, ...) end
  end)
  wrap(require("src.core.game3.battle.healthbox"), "draw", function(next, ...)
    if not hidden("hud") then return next(...) end
  end)
  -- Party.show creates OBJ sprites before Party.draw. They are flushed again
  -- by Display.present, so hiding the menu draw alone leaves floating icons.
  -- Filter only this menu's IDs; keep animation/state and unrelated sprites intact.
  local oam = require("src.core.game3.oam")
  local party = require("src.ui.game3.party_menu")
  wrap(party, "handleInput", function(next, input, ...)
    if hidden("partyNavigation") then
      -- Gear's uniform vertical list has no native left-column shortcut.
      local source = input
      input = setmetatable({ wasPressed = function(_, key)
        return key ~= "left" and key ~= "right" and source:wasPressed(key)
      end }, { __index = source })
    end
    return next(input, ...)
  end)
  wrap(oam, "buildOamBuffer", function(next, ...)
    local buffer = next(...)
    if not (party.open and hidden("menu")) then return buffer end
    local owned = {}
    for _, slot in pairs(party._oam or {}) do
      for _, key in ipairs({ "mon", "ball", "status", "item" }) do
        if slot[key] ~= nil then owned[slot[key]] = true end
      end
    end
    if party._summaryIcon ~= nil then owned[party._summaryIcon] = true end
    local filtered = {}
    for _, sprite in ipairs(buffer) do
      if not owned[sprite._id] then filtered[#filtered + 1] = sprite end
    end
    oam._buffer = filtered
    return filtered
  end)
  for _, name in ipairs({ "message", "choice", "party_menu", "bag_menu",
      "tm_case", "berry_pouch", "summary_menu", "stat_growth" }) do
    wrap(require("src.ui.game3." .. name), "draw", function(next, ...)
      if not hidden("menu") then return next(...) end
    end)
  end
  -- Newer hosts dispatch Emerald skins without calling the base menu draw.
  local okScreens, screens = pcall(require, "src.ui.game3.screens")
  if okScreens and type(screens.draw) == "function" then
    wrap(screens, "draw", function(next, id, ...)
      if (id ~= "bag" and id ~= "summary") or not hidden("menu") then return next(id, ...) end
    end)
  end
  return self
end

function Presentation:release()
  self.owns, self.drawing = nil, false
  if self.groundQuad then self.groundQuad:release(); self.groundQuad = nil end
  for _, patch in ipairs(self.patches) do
    -- Respect another mod wrapping us after installation. Our retained link
    -- becomes a pass-through instead of removing that mod's wrapper.
    if patch[1][patch[2]] == patch[4] then patch[1][patch[2]] = patch[3] end
  end
  self.patches = {}
end

return Presentation
