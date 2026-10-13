return function(ui, read)
  local function module(path)
    return assert(load(assert(read(path)), "@kanto_gear/" .. path))()
  end
  local H = module("ui/base/init.lua")(ui, read)
  local skin = module("ui/skins/init.lua")(H, ui, read)
  return H, skin
end
