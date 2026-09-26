-- Native FRLG does not call the legacy battle visibility hooks yet. Bridge
-- its presentation functions and Full Gear's owned command-grid navigation.
local Presentation = {}
Presentation.__index = Presentation

function Presentation.new(owns)
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
  wrap(require("src.core.game3.battle.ui"), "handleInput", function(next, input, ...)
    if hidden("navigation") then
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
  wrap(require("src.ui.game3.battle_chrome"), "drawPanel", function(next, ...)
    if not self.drawing then return next(...) end
  end)
  local chrome = require("src.ui.game3.battle_chrome")
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
  for _, name in ipairs({ "message", "choice", "party_menu", "bag_menu",
      "tm_case", "berry_pouch", "summary_menu" }) do
    wrap(require("src.ui.game3." .. name), "draw", function(next, ...)
      if not hidden("menu") then return next(...) end
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
