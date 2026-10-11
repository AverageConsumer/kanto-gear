-- Shared team page: six fixed slots for browsing, switching and item targets.
-- Native menus supply facts and actions, never the lower screen's geometry.
local Page = {}

function Page.direction(slot, count, direction, cancel)
  count = math.min(6, count)
  if count < 1 then return cancel end
  if slot == cancel then return direction == "up" and count or 1 end
  slot = math.max(1, math.min(count, slot or 1))
  if direction == "left" or direction == "right" then
    local other = slot % 2 == 1 and slot + 1 or slot - 1
    return other <= count and other or slot
  elseif direction == "up" then
    return slot > 2 and slot - 2 or cancel or slot
  elseif direction == "down" then
    return slot + 2 <= count and slot + 2 or cancel or slot
  end
  return slot
end

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
    drawCard(slot, x, y, selected or model.selection == nil and mon and mon.active,
      model.details, selected)
  end
end

return Page
