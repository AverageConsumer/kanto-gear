-- Shared four-move selection page. Native menus own effects and cancellation.
local Page = {}

function Page.rect(index)
  return 6, 70 + (index - 1) * 35, 228, 34
end

function Page.layout(items)
  for index, item in ipairs(items) do item.rect = { Page.rect(index) } end
end

function Page.hit(model, x, y)
  if model.enabled == false then return end
  if x >= 0 and x < 27 and y >= 0 and y < 28 then return "back" end
  for index, move in ipairs(model.moves) do
    local ax, ay, w, h = Page.rect(index)
    if move.available ~= false and x >= ax and x < ax + w and y >= ay and y < ay + h then return index end
  end
end

function Page.draw(H, model)
  H:panel(6, 33, 228, 34, false, nil, H.colors.greenLight)
  H:partyInfoCentered(H:fitPartyInfo(model.name or "", 212), 14, 36, 212, 13, H.colors.ink)
  H:partyInfoCentered(H:fitPartyInfo(model.prompt or "", 212), 14, 50, 212, 13, H.colors.green)
  for index = 1, 4 do
    local move = model.moves[index] or { available = false, name = "-" }
    local x, y = Page.rect(index)
    H:summaryMoveRow(move, x, y, false, model.enabled ~= false and move.available ~= false, false)
  end
end

return Page
