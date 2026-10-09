-- Shared touch choices. Paging never changes the original game's cursor.
local Page = {}
function Page.window(state, total)
  local visible = total > 4 and 3 or math.max(1, total)
  local pages = math.max(1, math.ceil(total / visible))
  state.page = math.max(1, math.min(pages, state.page or 1))
  local first = (state.page - 1) * visible + 1
  return first, math.min(visible, total - first + 1), pages
end
function Page.step(state, direction, total)
  local _, _, pages = Page.window(state, total)
  state.page = math.max(1, math.min(pages, state.page + direction))
end
function Page.model(state, labels, prompt, selected)
  local total = #labels
  local first, count, pages = Page.window(state, total)
  local step = total <= 2 and 47 or total <= 4 and math.floor(124 / math.max(1, total)) or 31
  local height = count * step - 3
  local top = 86 + math.floor(((pages > 1 and 98 or 127) - height) / 2)
  local model = { entries = {}, prompt = prompt,
    first = first, last = first + count - 1, total = total, pages = pages }
  for row = 1, count do
    local index = first + row - 1
    model.entries[row] = { index = index, label = labels[index], selected = index == selected,
      x = 7, y = top + (row - 1) * step, w = 226, h = step - 3 }
  end
  return model
end
function Page.hit(model, x, y)
  if model.pages > 1 and y >= 190 and y < 213 then
    if x >= 7 and x < 63 and model.first > 1 then return "previous" end
    if x >= 177 and x < 233 and model.last < model.total then return "next" end
  end
  for _, entry in ipairs(model.entries) do
    if x >= entry.x and x < entry.x + entry.w and y >= entry.y and y < entry.y + entry.h then return entry.index end
  end
end
return Page
