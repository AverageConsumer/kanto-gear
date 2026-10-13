-- Shared four-move selection page. Native menus own effects and cancellation.
local Page = {}

function Page.rect(index)
  return 6, 70 + (index - 1) * 35, 228, 34
end

function Page.layout(items, slots)
  for index, item in ipairs(items) do
    local slot = slots and slots[index] or index
    item.rect = slot == 5 and { 0, 0, 27, 28 } or { Page.rect(slot) }
  end
end

function Page.window(total, selected)
  local page = math.floor((math.max(1, math.min(total, selected or 1)) - 1) / 4) + 1
  local first = (page - 1) * 4 + 1
  return first, math.max(0, math.min(4, total - first + 1)), page, math.max(1, math.ceil(total / 4))
end

function Page.listLayout(items, selected)
  local first, count = Page.window(#items - 1, selected)
  for _, item in ipairs(items) do item.rect = nil end
  for row = 1, count do items[first + row - 1].rect = { Page.rect(row) } end
  items[#items].rect = { 0, 0, 27, 28 }
  return first, count
end

function Page.hit(model, x, y)
  if model.enabled == false then return end
  if x >= 0 and x < 27 and y >= 0 and y < 28 then return "back" end
  if model.pages and model.pages > 1 and y >= 41 and y < 59 then
    if x >= 12 and x < 28 and model.page > 1 then return "previous" end
    if x >= 212 and x < 228 and model.page < model.pages then return "next" end
  end
  if not model.message and model.newMove and model.details and x >= 6 and x < 234 and y >= 33 and y < 67 then return "new" end
  for index = 1, 4 do
    local move = model.moves[index]
    local ax, ay, w, h = Page.rect(index)
    if move and move.available ~= false and x >= ax and x < ax + w and y >= ay and y < ay + h then
      if model.details and x >= 210 then return "info", index end
      return index
    end
  end
end

function Page.draw(H, model)
  if H.v4MovePage then return H:v4MovePage(model, Page) end
  if model.message then
    H:panel(6, 33, 228, 34, false, nil, H.colors.amberLight)
    local first, second = H:splitPartyInfo(model.message:gsub("\n", " "), 212)
    H:partyInfoCentered(first, 14, second and 36 or 33, 212, second and 13 or 34, H.colors.ink)
    if second then H:partyInfoCentered(second, 14, 50, 212, 13, H.colors.ink) end
  elseif model.newMove then
    H:summaryMoveRow(model.newMove, 6, 33, false, model.enabled ~= false and model.details == true, model.details == true)
    H:partyType(model.newLabel or "NEW", 14, 35, H.colors.amber, 48)
  else
    H:panel(6, 33, 228, 34, false, nil, H.colors.greenLight)
    local paged = model.pages and model.pages > 1
    local left, width = paged and 36 or 14, paged and 168 or 212
    H:partyInfoCentered(H:fitPartyInfo(model.name or "", width), left, 36, width, 13, H.colors.ink)
    H:partyInfoCentered(H:fitPartyInfo(paged and model.page .. "/" .. model.pages or model.prompt or "", width),
      left, 50, width, 13, H.colors.green)
    if paged and model.page > 1 then H:pageChevron(20, 50, false, model.enabled ~= false) end
    if paged and model.page < model.pages then H:pageChevron(220, 50, true, model.enabled ~= false) end
  end
  for index = 1, 4 do
    local move = model.moves[index] or { available = false, name = "-" }
    local x, y = Page.rect(index)
    H:summaryMoveRow(move, x, y, H.nativeFocus and model.selection == index,
      model.enabled ~= false and move.available ~= false, model.details == true and move.available ~= false)
  end
end

function Page.promptRect(index)
  return 6 + (index - 1) * 118, 164, 110, 46
end

function Page.promptLayout(items)
  for index, item in ipairs(items) do item.rect = { Page.promptRect(index) } end
end

function Page.promptHit(model, x, y)
  if model.enabled == false or not model.choices then return end
  if model.details and x >= 6 and x < 234 and y >= 88 and y < 122 then return "new" end
  for index in ipairs(model.choices) do
    local ax, ay, w, h = Page.promptRect(index)
    if x >= ax and x < ax + w and y >= ay and y < ay + h then return index end
  end
end

function Page.drawPrompt(H, model)
  if H.v4MovePrompt then return H:v4MovePrompt(model, Page) end
  local c, mon = H.colors, model.mon or {}
  local enabled = model.enabled ~= false and model.choices ~= nil
  H:panel(6, 33, 228, 51, false, nil, H:typeColor(mon.type))
  H:partyPortrait(13, 36, false, false)
  if model.drawPokemon then model.drawPokemon(14, 39, 34) end
  H:partyName(mon.name or "", 57, 41, c.ink, 122)
  H:partyInfo(mon.levelText or "", 186, 41, c.ink, 38, "right")
  H:typeBadges(mon, 57, 64, false)
  H:summaryMoveRow(model.newMove or {}, 6, 88, false, enabled and model.details == true, model.details == true)
  H:partyType(H:fitPartyType(model.newLabel or "NEW", 48), 14, 90, c.amber, 48)
  H:panel(6, 126, 228, 34, false, nil, c.greenLight)
  local lines = model.prompt or {}
  local firstY = 126 + math.floor((34 - math.min(3, #lines) * 10) / 2)
  for index = 1, math.min(3, #lines) do
    H:partyInfoCentered(H:fitPartyInfo(lines[index], 212), 14, firstY + (index - 1) * 10, 212, 10, c.ink)
  end
  for index, label in ipairs(model.choices or {}) do
    local x, y, w, h = Page.promptRect(index)
    local pressed = H:beginPress(x, y, w, h, enabled)
    H:panel(x, y, w, h, H.nativeFocus and model.selection == index, nil, c.greenLight)
    H:partyInfoCentered(H:fitPartyInfo(label, w - 16), x + 8, y, w - 16, h, c.ink)
    H:endPress(pressed)
  end
  if not enabled then H:systemOverlay(0.48) end
end

return Page
