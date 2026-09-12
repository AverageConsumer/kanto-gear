-- The live native menu owns order, availability, focus and activation.
local Menu = { visible = 5, x = 7, y = 33, width = 226, height = 28, step = 31 }

function Menu.cursor(top)
  if type(top) ~= "table" or type(top.update) ~= "function"
      or type(top.items) ~= "table" or #top.items == 0 then return nil end
  local cursor
  if top.screenId == "StartMenu" and top.startCloses and top.phase == nil then
    cursor = top
  elseif top.screenId == "Gen2StartMenu" and top.phase == nil then
    cursor = top.list
  end
  if type(cursor) ~= "table" or type(cursor.index) ~= "number"
      or cursor.index % 1 ~= 0 or cursor.index < 1
      or cursor.index > #top.items then return nil end
  for _, item in ipairs(top.items) do
    if type(item) ~= "table" or type(item.label) ~= "string" then return nil end
  end
  return cursor
end

function Menu.window(top)
  local cursor = Menu.cursor(top)
  if not cursor then return nil end
  local first = math.floor((cursor.index - 1) / Menu.visible) * Menu.visible + 1
  return first, math.min(Menu.visible, #top.items - first + 1), cursor.index
end

function Menu.select(top, index)
  local cursor = Menu.cursor(top)
  if not cursor or type(index) ~= "number" or index % 1 ~= 0
      or index < 1 or index > #top.items then return false end
  cursor.index = index
  if type(cursor.clampScroll) == "function" then cursor:clampScroll() end
  if type(cursor.ensureVisible) == "function" then cursor:ensureVisible() end
  return true
end

function Menu.hit(top, x, y)
  local first, count = Menu.window(top)
  if not first then return nil end
  if x >= 0 and x < 27 and y >= 0 and y < 28 then return "back" end
  if y >= 190 and y < 213 then
    if x >= 7 and x < 63 and first > 1 then return "previous" end
    if x >= 177 and x < 233 and first + count <= #top.items then return "next" end
  end
  if x < Menu.x or x >= Menu.x + Menu.width then return nil end
  local row = math.floor((y - Menu.y) / Menu.step)
  if row >= 0 and row < count and y < Menu.y + row * Menu.step + Menu.height then
    return first + row
  end
end

function Menu.label(item)
  return item.label:gsub("<PO><KE>", "POKé"):gsub("<PK><MN>", "PKMN")
end

local kinds = { ["POKéDEX"] = "pokedex", POKEDEX = "pokedex",
  ["POKéMON"] = "pokemon", POKEMON = "pokemon", ITEM = "pack", PACK = "pack",
  SAVE = "save", OPTION = "option", QUIT = "quit" }

function Menu.model(top)
  local first, count, selected = Menu.window(top)
  if not first then return nil end
  local entries = {}
  for row = 1, count do
    local index = first + row - 1
    local item = top.items[index]
    entries[row] = { label = Menu.label(item), selected = index == selected,
      kind = item.value or item.id or kinds[item.label],
      disabled = top.screenId == "Gen2StartMenu" and item.disabled,
      x = Menu.x, y = Menu.y + (row - 1) * Menu.step, w = Menu.width, h = Menu.height }
  end
  return { entries = entries, first = first, last = first + count - 1, total = #top.items }
end

return Menu
