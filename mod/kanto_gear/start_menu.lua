-- The live native menu owns order, availability, focus and activation.
local Menu = { visible = 5, x = 7, y = 33, width = 226, height = 28, step = 31 }

function Menu.cursor(top, preview)
  if type(top) ~= "table" or type(top.update) ~= "function"
      or type(top.items) ~= "table" or #top.items == 0 then return nil end
  local cursor
  if top.screenId == "Gen3Menu" and type(top.valid) == "function" and top.valid(preview) then
    cursor = top
  elseif top.screenId == "StartMenu" and top.startCloses and top.phase == nil then
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

function Menu.window(top, preview)
  local cursor = Menu.cursor(top, preview)
  if not cursor then return nil end
  if top.fixedLayout then return 1, #top.items, cursor.index end
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
  if top.fixedLayout then
    for index, item in ipairs(top.items) do
      local r = item.rect
      if r and x >= r[1] and x < r[1] + r[3] and y >= r[2] and y < r[2] + r[4] then return index end
    end
    return nil
  end
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
  -- Native opening/closing animations may already have displayable rows,
  -- while hit testing and selection must wait for the host to accept input.
  local first, count, selected = Menu.window(top, true)
  if not first then return nil end
  local entries = {}
  for row = 1, count do
    local index = first + row - 1
    local item = top.items[index]
    local r = item.rect or { Menu.x, Menu.y + (row - 1) * Menu.step, Menu.width, Menu.height }
    entries[row] = { label = Menu.label(item), right = item.right, selected = index == selected,
      mon = item.mon, compact = top.fixedLayout,
      kind = item.value or item.id or kinds[item.label],
      disabled = top.screenId == "Gen2StartMenu" and item.disabled,
      x = r[1], y = r[2], w = r[3], h = r[4] }
  end
  return { entries = entries, first = first, last = first + count - 1, total = #top.items,
    fixedLayout = top.fixedLayout }
end

return Menu
