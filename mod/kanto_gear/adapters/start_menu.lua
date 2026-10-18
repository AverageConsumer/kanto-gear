-- The live native menu owns order, availability, focus and activation.
local Menu = { visible = 5, x = 7, y = 33, width = 226, height = 28, step = 31 }

local function rowGeometry(top)
  if top.battleTargets then return Menu.y, 43, 40 end
  return top.recentBag and 70 or Menu.y, top.recentBag and 30 or Menu.step, Menu.height
end

function Menu.cursor(top, preview)
  if type(top) ~= "table" or type(top.update) ~= "function"
      or type(top.items) ~= "table" or #top.items == 0 then return nil end
  local cursor
  -- Game path [Gen 1/2/3]: adapted menus validate their cursor, Gen 1 StartMenu owns index, Gen 2 StartMenu delegates to its nested list.
  if (top.screenId == "Gen3Menu" or top.screenId == "CompanionMenu")
      and type(top.valid) == "function" and top.valid(preview) then
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
  if top.touchWindow then return top.touchWindow.first, top.touchWindow.count, cursor.index end
  if top.fixedLayout then return 1, #top.items, cursor.index end
  local visible = top.recentBag and 4 or Menu.visible
  local first = math.floor((cursor.index - 1) / visible) * visible + 1
  return first, math.min(visible, #top.items - first + 1), cursor.index
end

-- Compare the visible menu, not the identity of a reused native screen.
-- This is sampled at the normal UI poll; unchanged menus keep their canvas.
function Menu.redrawKey(top)
  local first, count, selected = Menu.window(top, true)
  if not first then return "" end
  local quantity, stats = top.quantity, top.nativeStats
  local party = top.party
  local heal, result, anim = party and party.heal, party and party.itemResult, party and party._hpAnim
  local function hp(value) return type(value) == "number" and math.floor(value + 0.5) or "" end
  local parts = { tostring(top.nativeKey), tostring(selected), tostring(#top.items), tostring(first), tostring(count),
    tostring(Menu.cursor(top) ~= nil), tostring(top.title), tostring(top.name),
    tostring(top.itemActionId), tostring(top.itemActionCount),
    tostring(top.prompt), tostring(top.pokenavHelp), tostring(top.notice), tostring(top.canAdvance), tostring(top.recentBag and top.recentBag.id), tostring(top.recentBag and top.recentBag.count),
    tostring(quantity and quantity.label), tostring(quantity and quantity.qty),
    tostring(quantity and quantity.max), tostring(quantity and quantity.total), tostring(stats and stats._page),
    tostring(heal and heal.mon), hp(heal and heal.shown),
    tostring(result and result.slot), hp(result and result.shown),
    tostring(anim and anim.slot), hp(anim and anim.current) }
  for i = first, first + count - 1 do
    local item = top.items[i]
    parts[#parts + 1] = tostring(item.label)
    parts[#parts + 1] = tostring(item.right)
    parts[#parts + 1] = tostring(item.targetSide)
    parts[#parts + 1] = tostring(item.effectiveness)
    parts[#parts + 1] = tostring(item.catchChance)
    parts[#parts + 1] = tostring(item.disabled)
    parts[#parts + 1] = tostring(item.inert)
    parts[#parts + 1] = tostring(item.rawMon)
    local mon = item.mon or item.rawMon
    if mon then
      parts[#parts + 1] = tostring(mon.hp)
      parts[#parts + 1] = tostring(mon.status)
      parts[#parts + 1] = tostring(mon.pokerus)
    end
  end
  return table.concat(parts, "\31")
end

function Menu.select(top, index)
  local cursor = Menu.cursor(top)
  if not cursor or type(index) ~= "number" or index % 1 ~= 0
      or index < 1 or index > #top.items or top.items[index].inert then return false end
  cursor.index = index
  if type(cursor.clampScroll) == "function" then cursor:clampScroll() end
  if type(cursor.ensureVisible) == "function" then cursor:ensureVisible() end
  return true
end

function Menu.direction(top, key)
  local cursor = Menu.cursor(top)
  if not cursor or not ({up=true,down=true,left=true,right=true})[key] then return nil end
  local index, count = cursor.index, #top.items
  local rect = top.fixedLayout and top.items[index].rect
  if not rect then
    if key == "left" or key == "right" then
      if top.nativePocket then return nil end
      return index
    end
    local step = key == "up" and -1 or 1
    for offset = 1, count do
      local target = (index - 1 + step * offset) % count + 1
      if not top.items[target].inert then return target end
    end
    return index
  end
  -- Navigate the same rectangles used for drawing and touch, rather than
  -- inheriting the original game's different menu geometry.
  local cx, cy = rect[1] + rect[3] / 2, rect[2] + rect[4] / 2
  local best, score = index, math.huge
  for target, item in ipairs(top.items) do
    local r = item.rect
    if r and target ~= index and not item.inert
        and not (top.moveSelection and item.label == "CANCEL") then
      local dx, dy = r[1] + r[3] / 2 - cx, r[2] + r[4] / 2 - cy
      local along = key == "left" and -dx or key == "right" and dx
        or key == "up" and -dy or dy
      local across = (key == "left" or key == "right") and math.abs(dy) or math.abs(dx)
      local distance = along + across * 2
      if along > 0 and distance < score then best, score = target, distance end
    end
  end
  return best
end

function Menu.hit(top, x, y)
  local first, count = Menu.window(top)
  if not first then return nil end
  if x >= 0 and x < 27 and y >= 0 and y < 28 and top.back ~= false then return "back" end
  if top.fixedLayout then
    for index, item in ipairs(top.items) do
      local r = item.rect
      if r and not item.inert and x >= r[1] and x < r[1] + r[3] and y >= r[2] and y < r[2] + r[4] then return index end
    end
    return nil
  end
  if y >= 190 and y < 213 then
    if x >= 7 and x < 63 and first > 1 then return "previous" end
    if x >= 177 and x < 233 and first + count <= #top.items then return "next" end
  end
  if x < Menu.x or x >= Menu.x + Menu.width then return nil end
  local topY, step, height = rowGeometry(top)
  local row = math.floor((y - topY) / step)
  if row >= 0 and row < count and y < topY + row * step + height then
    local index = first + row
    if not top.items[index].inert then return index end
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
  local topY, step, height = rowGeometry(top)
  for row = 1, count do
    local index = first + row - 1
    local item = top.items[index]
    local r = item.rect or { Menu.x, topY + (row - 1) * step, Menu.width, height }
    entries[row] = { label = Menu.label(item), right = item.right, targetSide = item.targetSide,
      effectiveness = item.effectiveness,
      catchChance = item.catchChance, selected = index == selected,
      kind = item.value or item.id or kinds[item.label], itemId = item.itemId, itemSprite = item.itemSprite,
      rawMon = item.rawMon, disabled = item.inert or top.screenId == "Gen2StartMenu" and item.disabled,
      x = r[1], y = r[2], w = r[3], h = r[4] }
  end
  return { entries = entries, first = first, last = first + count - 1, total = #top.items,
    fixedLayout = top.fixedLayout, visible = top.recentBag and 4 or Menu.visible }
end

return Menu
