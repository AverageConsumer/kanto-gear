-- Shared team page: six fixed slots for browsing, switching and item targets.
-- Native menus supply facts and actions, never the lower screen's geometry.
local Page = {}

function Page.rect(H, slot, count, cancel)
  if cancel and slot == count + 1 then return 0, 0, 27, 28 end
  local x, y = H:partyPosition(slot)
  return x, y, 112, 56
end

function Page.hit(H, x, y, count, cancel)
  if cancel and x >= 0 and x < 27 and y >= 0 and y < 28 then return count + 1 end
  for slot = 1, math.min(6, count) do
    local left, top, width, height = Page.rect(H, slot)
    if x >= left and x < left + width and y >= top and y < top + height then return slot end
  end
end

function Page.draw(H, model, drawCard)
  for slot = 1, 6 do
    local x, y = Page.rect(H, slot)
    local mon = model.party[slot]
    local selected = model.selection == slot
    drawCard(slot, x, y, selected or mon and mon.active,
      model.details, selected)
  end
end

return Page
