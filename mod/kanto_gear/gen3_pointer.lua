-- FRLG hosts through 0.3.22 omit input.pointer in their window handlers.
-- Route only Gear-owned contacts until the host provides the native bridge.
local Pointer = {}
function Pointer.new(game, route)
  local self = { patches = {}, enabled = true, release = function() end }
  if type(game.pointerEvent) == "function" then return self end
  local contact
  local function cancel()
    local old = contact
    contact = nil
    if old then route("cancel", old.x, old.y) end
  end
  local function handle(action, id, x, y)
    if not self.enabled or type(game.pointerEvent) == "function" then return false end
    if action == "down" then
      if contact then return contact.id == id end
      if not route(action, x, y) then return false end
      contact = { id = id, x = x, y = y }
      return true
    end
    if not contact or contact.id ~= id then return false end
    contact.x, contact.y = x, y
    if action == "up" then contact = nil end
    route(action, x, y)
    return true
  end
  local function wrap(name, callback)
    local original, own = game[name], rawget(game, name)
    if type(original) ~= "function" then return end
    local fn = function(...)
      if not self.enabled then return original(...) end
      return callback(original, ...)
    end
    game[name] = fn
    self.patches[#self.patches + 1] = { name = name, fn = fn, own = own }
  end
  for name, action in pairs({ mousepressed = "down", mousemoved = "move", mousereleased = "up" }) do
    if action == "move" then
      wrap(name, function(next, owner, x, y, dx, dy, istouch, ...)
        if not istouch and handle(action, "mouse", x, y) then return true end
        return next(owner, x, y, dx, dy, istouch, ...)
      end)
    else
      wrap(name, function(next, owner, x, y, button, istouch, ...)
        if not istouch and button == 1 and handle(action, "mouse", x, y) then return true end
        return next(owner, x, y, button, istouch, ...)
      end)
    end
  end
  for name, action in pairs({ touchpressed = "down", touchmoved = "move", touchreleased = "up" }) do
    wrap(name, function(next, owner, id, x, y, ...)
      if handle(action, id, x, y) then return true end
      return next(owner, id, x, y, ...)
    end)
  end
  -- Focus loss, lifecycle changes and input resets must not leave a held pen.
  for _, name in ipairs({ "focus", "visible", "onResume", "returnToTitle", "quit", "_releaseModInput" }) do
    wrap(name, function(next, ...)
      cancel()
      return next(...)
    end)
  end
  function self:release()
    cancel()
    self.enabled = false
    for _, patch in ipairs(self.patches) do
      if game[patch.name] == patch.fn then game[patch.name] = patch.own end
    end
    self.patches = {}
  end
  return self
end
return Pointer
