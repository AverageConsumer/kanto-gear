-- One item card and action geometry for native bags and the companion app.
-- Row indices stay native: presentation never reorders or invokes an action.
local Page = {}
local labels = { EXIT = "CANCEL", QUIT = "CANCEL", SET = "REGISTER", CHECK_TAG = "CHECK TAG" }

function Page.rect(index, count)
  local rows = math.ceil(count / 2)
  local h = rows == 1 and 40 or rows == 2 and 22 or 18
  local top = 210 - rows * h - (rows - 1) * 4
  local row, col = math.floor((index - 1) / 2), (index - 1) % 2
  if index == count and count % 2 == 1 then return 54, top + row * (h + 4), 132, h end
  return 6 + col * 118, top + row * (h + 4), 110, h
end

function Page.layout(items)
  for index, item in ipairs(items) do item.rect = { Page.rect(index, #items) } end
end

function Page.model(detail, rows, enabled, message, translate)
  local actions = {}
  for index, row in ipairs(rows or {}) do
    local label = labels[row.label] or row.label
    actions[index] = { id = row.id, label = translate(label), enabled = row.enabled ~= false and not row.inert }
  end
  return { detail = detail, actions = actions, canUse = enabled, message = message }
end

function Page.hit(model, x, y)
  if model.canUse == false then return end
  for index, row in ipairs(model.actions or {}) do
    local ax, ay, w, h = Page.rect(index, #model.actions)
    if row.enabled ~= false and x >= ax and x < ax + w and y >= ay and y < ay + h then return index end
  end
end

return Page
