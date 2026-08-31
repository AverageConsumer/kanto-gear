local M = {
  columns = 12, rows = 2,
  holdSeconds = 0.45, dragSlop = 6, swipeDistance = 24,
}

local function integer(value)
  return type(value) == "number" and value == math.floor(value)
end

local function definition(catalog, id)
  local item = catalog and catalog[id]
  if type(item) ~= "table" or item.installed == false then return nil end
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

local function free(layout, catalog, page, column, row, columns, rows, ignoreId)
  local candidate = {
    page = page, column = column, row = row,
    columns = columns, rows = rows,
  }
  for _, tile in ipairs(layout.tiles or {}) do
    if tile.id ~= ignoreId and tile.page == page then
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

function M.canPlace(layout, catalog, id, page, column, row, ignoreId)
  local item, columns, rows = definition(catalog, id)
  if not item then return false, "not_installed" end
  if not integer(page) or page < 1
      or not integer(column) or not integer(row)
      or column < 1 or row < 1
      or column + columns - 1 > M.columns
      or row + rows - 1 > M.rows then return false, "outside" end
  return free(layout, catalog, page, column, row, columns, rows, ignoreId)
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

function M.remove(layout, id)
  local _, index = M.find(layout, id)
  if not index then return false end
  table.remove(layout.tiles, index)
  return true
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
          icon = item.icon, accent = item.accent, label = item.label,
          column = placed.column, row = placed.row,
          columns = columns, rows = rows,
        }
      end
    end
  end
  return result
end

function M.plusSlots(layout, catalog, page)
  local slots = {}
  for row = 1, M.rows do
    for column = 1, M.columns, 3 do
      if free(layout, catalog, page, column, row, 3, 1) then
        slots[#slots + 1] = { column = column, row = row, columns = 3, rows = 1 }
      end
    end
  end
  return slots
end

function M.library(layout, catalog, page, column, row)
  local result = {}
  for id, item in pairs(catalog or {}) do
    if item.installed ~= false then
      local placed = M.find(layout, id) ~= nil
      local fits, reason = M.canPlace(layout, catalog, id, page, column, row)
      result[#result + 1] = {
        id = id, label = item.label or id, kind = item.kind or "app",
        icon = item.icon, accent = item.accent,
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
