-- Native alphabets supply the keys; every generation shares their touch layout.
local Page = {}

function Page.availability(model, count, limit)
  for _, entry in ipairs(model.entries) do
    entry.disabled = entry.action == "delete" and count == 0
      or not entry.action and limit ~= nil and count >= limit
  end
end

function Page.model(name, items, limit, count)
  local rows, columns, lastRow = {}, 1, 0
  for index, item in ipairs(items) do
    if not item.action then
      rows[item.row] = rows[item.row] or {}
      rows[item.row][#rows[item.row] + 1] = index
      columns = math.max(columns, #rows[item.row])
      lastRow = math.max(lastRow, item.row)
    end
  end
  local model = { name = name == "" and "-" or name, entries = {} }
  local keyWidth = math.max(1, math.floor((226 - (columns - 1) * 2) / columns))
  local step = math.floor(108 / math.max(1, lastRow))
  local top = 70 + math.floor((108 - (lastRow * step - 2)) / 2)
  for row, indices in pairs(rows) do
    local left = math.floor((240 - (#indices * (keyWidth + 2) - 2)) / 2)
    for col, index in ipairs(indices) do
      model.entries[index] = { index = index, label = items[index].label,
        x = left + (col - 1) * (keyWidth + 2), y = top + (row - 1) * step,
        w = keyWidth, h = step - 2 }
    end
  end
  local action = 0
  for index, item in ipairs(items) do
    if item.action then
      action = action + 1
      model.entries[index] = { index = index, label = item.label, action = item.action,
        x = 7 + (action - 1) * 77, y = 184, w = 72, h = 29 }
    end
  end
  Page.availability(model, count or #tostring(name or ""), limit)
  return model
end

function Page.hit(model, x, y)
  for _, entry in ipairs(model.entries) do
    if not entry.disabled and x >= entry.x and x < entry.x + entry.w
        and y >= entry.y and y < entry.y + entry.h then return entry.index end
  end
end

return Page
