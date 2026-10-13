return function(ui, read)
  local function install(name, ...)
    local path = "ui/base/" .. name .. ".lua"
    return assert(load(assert(read(path)), "@kanto_gear/" .. path))()(...)
  end
  local H, draw = install("core", ui)
  local icons = install("icons", H, ui, draw)
  install("trainer", H, ui, draw, icons)
  install("pokedex", H, ui, draw)
  local home = install("home", H, ui, draw, icons)
  install("settings", H, ui, draw)
  install("store", H, ui, draw, home, icons)
  install("map", H, ui, draw)
  install("menus", H, ui, draw)
  install("battle", H, ui, draw, icons)
  install("enemy", H, ui, draw)
  install("storage", H, ui, draw)
  install("overlays", H, ui, draw, icons)
  install("bag", H, ui, draw)
  install("moves", H, ui, draw)
  install("party", H, ui, draw)
  return H
end
