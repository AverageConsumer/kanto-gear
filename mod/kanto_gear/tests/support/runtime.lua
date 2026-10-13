-- Test fixtures inspect closures to seed native menus without running a game.
-- Session and graphics state now live in explicit shared tables.
local Runtime = {}
local function binding(fn, target)
  for index = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, index)
    if name == target then return fn, index end
  end
  for index = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, index)
    local graphics = target == "G" or target == "INK" or target == "DARK"
      or target == "MID" or target == "PAPER" or target == "SECONDARY_BACKGROUND"
    if graphics and name == "render" or not graphics and name == "session" then
      return value, target
    end
  end
end
function Runtime.get(fn, target, replacement, set)
  local owner, key = binding(fn, target)
  if not owner then return end
  local write = set == true or set == nil and replacement ~= nil
  if type(owner) == "table" then
    local previous = owner[key]
    if write then owner[key] = replacement end
    return previous
  end
  local _, value = debug.getupvalue(owner, key)
  if write then debug.setupvalue(owner, key, replacement) end
  return value
end
function Runtime.set(fn, target, value)
  return Runtime.get(fn, target, value, true)
end
function Runtime.inspect(fn, key)
  if type(key) == "number" then return debug.getupvalue(fn, key) end
  return key, Runtime.get(fn, key)
end
function Runtime.assign(fn, key, value)
  if type(key) == "number" then return debug.setupvalue(fn, key, value) end
  return Runtime.set(fn, key, value)
end
return Runtime
