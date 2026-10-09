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

function Page.hit(model, x, y)
  if model.enabled == false then return end
  if x >= 0 and x < 27 and y >= 0 and y < 28 then return "back" end
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
    H:partyInfoCentered(H:fitPartyInfo(model.name or "", 212), 14, 36, 212, 13, H.colors.ink)
    H:partyInfoCentered(H:fitPartyInfo(model.prompt or "", 212), 14, 50, 212, 13, H.colors.green)
  end
  for index = 1, 4 do
    local move = model.moves[index] or { available = false, name = "-" }
    local x, y = Page.rect(index)
    H:summaryMoveRow(move, x, y, false, model.enabled ~= false and move.available ~= false, model.details == true and move.available ~= false)
  end
end

return Page
