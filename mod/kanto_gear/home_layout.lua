local M = {
  columns = 12, rows = 2,
  holdSeconds = 0.45, dragSlop = 6, swipeDistance = 24,
}

local function integer(value)
  return type(value) == "number" and value == math.floor(value)
end

local function definition(catalog, id)
  local item = catalog and catalog.surfaces and catalog.surfaces[id]
  local package = item and catalog.packages and catalog.packages[item.package]
  if type(item) ~= "table" or type(package) ~= "table"
      or package.installed == false then return nil end
  local columns, rows = item.columns or 3, item.rows or 1
  if not integer(columns) or not integer(rows)
      or columns < 1 or rows < 1
      or columns > M.columns or rows > M.rows then return nil end
  return item, columns, rows
end

local function overlaps(a, b)
  return a.column < b.column + b.columns
    and b.column < a.column + a.columns
    and a.row < b.row + b.rows
    and b.row < a.row + a.rows
end

local function baseVisualWidth(tile)
  local columns = tonumber(tile.visualColumns)
    or tonumber(tile.columns) or 3
  return columns * 17 + (columns - 1) * 2
end

local function visualWidth(tile)
  return tonumber(tile.visualWidth) or baseVisualWidth(tile)
end

-- Home rows behave like one centered strip, not twelve visible columns.
-- Columns remain the storage/order model; the renderer receives the
-- pixel position produced by equal outer and inner gaps.
function M.spaceRows(items)
  local rows = {}
  for _, item in ipairs(items or {}) do
    local row = tonumber(item.row) or 1
    rows[row] = rows[row] or {}
    rows[row][#rows[row] + 1] = item
  end
  for _, row in pairs(rows) do
    table.sort(row, function(a, b)
      return (tonumber(a.column) or 1) < (tonumber(b.column) or 1)
    end)
    local total, sameWidth = 0, true
    local firstWidth
    for _, item in ipairs(row) do
      item.visualWidth = nil
      local width = baseVisualWidth(item)
      firstWidth = firstWidth or width
      sameWidth = sameWidth and width == firstWidth
      total = total + width
    end
    local gap
    if sameWidth then
      for magnitude = 0, 3 do
        for _, delta in ipairs(magnitude == 0 and { 0 }
            or { magnitude, -magnitude }) do
          local freePixels = 226 - #row * (firstWidth + delta)
          if freePixels >= #row + 1
              and freePixels % (#row + 1) == 0 then
            gap = freePixels / (#row + 1)
            for _, item in ipairs(row) do
              item.visualWidth = firstWidth + delta
            end
            break
          end
        end
        if gap then break end
      end
    end
    if not gap then
      gap = math.max(1, math.floor(
        (226 - total) / (#row + 1) + 0.5))
      local widthDelta = 226 - gap * (#row + 1) - total
      local direction = widthDelta < 0 and -1 or 1
      for index = 1, math.abs(widthDelta) do
        local item = row[(index - 1) % #row + 1]
        item.visualWidth = visualWidth(item) + direction
      end
    end
    local x = 7 + gap
    for _, item in ipairs(row) do
      item.visualX = x
      x = x + visualWidth(item) + gap
    end
  end
  return items
end

local function free(layout, catalog, page, column, row, columns, rows,
                    ignoreId, ignoreOtherId)
  local candidate = {
    page = page, column = column, row = row,
    columns = columns, rows = rows,
  }
  for _, tile in ipairs(layout.tiles or {}) do
    if tile.id ~= ignoreId and tile.id ~= ignoreOtherId
        and tile.page == page then
      local _, tileColumns, tileRows = definition(catalog, tile.id)
      if tileColumns and overlaps(candidate, {
          column = tile.column, row = tile.row,
          columns = tileColumns, rows = tileRows,
        }) then return false, "occupied" end
    end
  end
  return true
end

function M.find(layout, id)
  for index, tile in ipairs(layout.tiles or {}) do
    if tile.id == id then return tile, index end
  end
end

function M.longPress(elapsed, dx, dy)
  dx, dy = tonumber(dx) or 0, tonumber(dy) or 0
  return (tonumber(elapsed) or 0) >= M.holdSeconds
    and dx * dx + dy * dy <= M.dragSlop * M.dragSlop
end

function M.swipeDirection(dx, dy)
  dx, dy = tonumber(dx) or 0, tonumber(dy) or 0
  if math.abs(dx) < M.swipeDistance
      or math.abs(dx) <= math.abs(dy) * 1.25 then return nil end
  return dx < 0 and 1 or -1
end

function M.canPlace(layout, catalog, id, page, column, row,
                    ignoreId, ignoreOtherId)
  local item, columns, rows = definition(catalog, id)
  if not item then return false, "not_installed" end
  if not integer(page) or page < 1
      or not integer(column) or not integer(row)
      or column < 1 or row < 1
      or column + columns - 1 > M.columns
      or row + rows - 1 > M.rows then return false, "outside" end
  return free(layout, catalog, page, column, row, columns, rows,
    ignoreId, ignoreOtherId)
end

function M.place(layout, catalog, id, page, column, row)
  local existing = M.find(layout, id)
  local ok, reason = M.canPlace(layout, catalog, id, page, column, row,
    existing and id or nil)
  if not ok then return false, reason end
  local tile = existing or { id = id }
  tile.page, tile.column, tile.row = page, column, row
  if not existing then
    layout.tiles = layout.tiles or {}
    layout.tiles[#layout.tiles + 1] = tile
  end
  return true
end

function M.compactRows(layout, catalog)
  local groups = {}
  for _, tile in ipairs(layout.tiles or {}) do
    local _, columns = definition(catalog, tile.id)
    if columns then
      local key = tostring(tile.page) .. ":" .. tostring(tile.row)
      groups[key] = groups[key] or {}
      groups[key][#groups[key] + 1] = { tile = tile, columns = columns }
    end
  end
  for _, group in pairs(groups) do
    table.sort(group, function(a, b)
      return (tonumber(a.tile.column) or 1)
        < (tonumber(b.tile.column) or 1)
    end)
    local column = 1
    for _, entry in ipairs(group) do
      entry.tile.column = column
      column = column + entry.columns
    end
  end
  return layout
end

function M.swap(layout, catalog, firstId, secondId)
  local first, second = M.find(layout, firstId), M.find(layout, secondId)
  local _, firstColumns, firstRows = definition(catalog, firstId)
  local _, secondColumns, secondRows = definition(catalog, secondId)
  if not first or not second or first == second
      or not firstColumns or not secondColumns then return false, "missing" end
  local firstTarget = { page = second.page, column = second.column,
    row = second.row, columns = firstColumns, rows = firstRows }
  local secondTarget = { page = first.page, column = first.column,
    row = first.row, columns = secondColumns, rows = secondRows }
  if first.page == second.page and first.row == second.row
      and firstRows == secondRows then
    if first.column + firstColumns == second.column then
      firstTarget.column = first.column + secondColumns
      secondTarget.column = first.column
    elseif second.column + secondColumns == first.column then
      secondTarget.column = second.column + firstColumns
      firstTarget.column = second.column
    end
  end
  if firstTarget.page == secondTarget.page
      and overlaps(firstTarget, secondTarget) then return false, "incompatible" end
  local firstFits = M.canPlace(layout, catalog, firstId,
    firstTarget.page, firstTarget.column, firstTarget.row, firstId, secondId)
  local secondFits = M.canPlace(layout, catalog, secondId,
    secondTarget.page, secondTarget.column, secondTarget.row, secondId, firstId)
  if not firstFits or not secondFits then return false, "incompatible" end
  first.page, first.column, first.row =
    firstTarget.page, firstTarget.column, firstTarget.row
  second.page, second.column, second.row =
    secondTarget.page, secondTarget.column, secondTarget.row
  M.compactRows(layout, catalog)
  return true, "swap"
end

function M.remove(layout, id, catalog)
  local _, index = M.find(layout, id)
  if not index then return false end
  table.remove(layout.tiles, index)
  if catalog then M.compactRows(layout, catalog) end
  return true
end

function M.removePackage(layout, catalog, packageId)
  local removed = 0
  for index = #(layout.tiles or {}), 1, -1 do
    local item = catalog.surfaces[layout.tiles[index].id]
    if item and item.package == packageId then
      table.remove(layout.tiles, index)
      removed = removed + 1
    end
  end
  M.compactRows(layout, catalog)
  return removed
end

function M.pageCount(layout)
  local pages = 1
  for _, tile in ipairs(layout.tiles or {}) do
    pages = math.max(pages, tonumber(tile.page) or 1)
  end
  return pages
end

function M.tiles(layout, catalog, page)
  local result = {}
  for _, placed in ipairs(layout.tiles or {}) do
    if placed.page == page then
      local item, columns, rows = definition(catalog, placed.id)
      if item then
        result[#result + 1] = {
          id = placed.id, kind = item.kind or "app",
          widget = item.widget, icon = item.icon,
          accent = item.accent, label = item.label,
          actionId = item.actionId, rodId = item.rodId,
          toolKey = item.toolKey, ready = item.ready,
          column = placed.column, row = placed.row,
          columns = columns, rows = rows,
        }
      end
    end
  end
  return M.spaceRows(result)
end

function M.plusSlots(layout, catalog, page, ignoreId)
  local slots = {}
  local _, movingColumns, movingRows = definition(catalog, ignoreId)
  local source = ignoreId and M.find(layout, ignoreId)
  for row = 1, M.rows do
    if not (source and source.page == page and source.row == row) then
      local column = 1
      local best
      while column <= M.columns do
        if free(layout, catalog, page, column, row, 1, 1, ignoreId) then
          local first = column
          repeat column = column + 1
          until column > M.columns
            or not free(layout, catalog, page, column, row, 1, 1, ignoreId)
          local columns = column - first
          local needed = movingColumns or 3
          if columns >= needed and (not best or columns > best.columns) then
            best = { column = first, row = row, columns = columns,
              rows = movingRows or 1, visualColumns = needed }
          end
        else
          column = column + 1
        end
      end
      if best then slots[#slots + 1] = best end
    end
  end
  return slots
end

function M.drop(layout, catalog, id, page, column, row)
  local source = M.find(layout, id)
  local _, columns, rows = definition(catalog, id)
  if not source or not columns or not integer(page) or page < 1
      or not integer(column) or not integer(row) then return false, "outside" end
  for _, tile in ipairs(layout.tiles or {}) do
    local _, tileColumns, tileRows = definition(catalog, tile.id)
    if tile.id ~= id and tile.page == page and tileColumns
        and column >= tile.column and column < tile.column + tileColumns
        and row >= tile.row and row < tile.row + tileRows then
      return M.swap(layout, catalog, id, tile.id)
    end
  end
  for _, slot in ipairs(M.plusSlots(layout, catalog, page, id)) do
    if column >= slot.column and column < slot.column + slot.columns
        and row >= slot.row and row < slot.row + slot.rows
        and columns <= slot.columns and rows <= slot.rows then
      local targetColumn = slot.column
        + math.floor((slot.columns - columns) / 2)
      local targetRow = slot.row + math.floor((slot.rows - rows) / 2)
      local moved = M.place(layout, catalog, id, page, targetColumn, targetRow)
      if moved then M.compactRows(layout, catalog) end
      return moved, moved and "move" or "incompatible"
    end
  end
  return false, "no_target"
end

function M.library(layout, catalog, page, column, row, kind)
  local result = {}
  for id, item in pairs(catalog.surfaces or {}) do
    if not item.hidden and definition(catalog, id)
        and (not kind or item.kind == kind) then
      local placed = M.find(layout, id) ~= nil
      local fits, reason = M.canPlace(layout, catalog, id, page, column, row)
      result[#result + 1] = {
        id = id, label = item.label or id, kind = item.kind or "app",
        widget = item.widget, icon = item.icon, accent = item.accent,
        columns = item.columns or 3, rows = item.rows or 1,
        available = not placed and fits,
        reason = placed and "on_home" or (fits and nil or reason),
      }
    end
  end
  table.sort(result, function(a, b)
    return a.label == b.label and a.id < b.id or a.label < b.label
  end)
  return result
end

return M
