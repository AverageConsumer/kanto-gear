-- Shared storage geometry. Adapters supply native slot identities and rules.
local Page = {}

function Page.box(options)
  local items, slots = {}, {}
  local function entry(label, value, rect, mon, inert, key)
    items[#items + 1] = { label = label, rect = rect, rawMon = mon, inert = inert, inputKey = key }
    slots[#slots + 1] = value
  end
  local primary, cancel = options.primary, options.cancel
  entry(primary.label, primary.value, { 7, 33, 110, 22 }, nil, primary.inert, primary.key)
  entry(cancel.label, cancel.value, { 123, 33, 110, 22 }, nil, cancel.inert, cancel.key)
  local capacity, count = options.capacity, 0
  for slot = 1, capacity do if options.monAt(slot) then count = count + 1 end end
  entry(options.name .. "  " .. count .. "/" .. capacity, options.nameValue or 0,
    { 7, 59, 226, 22 }, nil, options.nameInert)
  local columns = capacity == 20 and 5 or 6
  local rows = math.ceil(capacity / columns)
  for slot = 1, capacity do
    local col, row = (slot - 1) % columns, math.floor((slot - 1) / columns)
    local left, right = math.floor(col * 228 / columns), math.floor((col + 1) * 228 / columns)
    local top, bottom = math.floor(row * 120 / rows), math.floor((row + 1) * 120 / rows)
    entry("", slot, { 7 + left, 85 + top, right - left - 2, bottom - top - 2 },
      options.monAt(slot), not options.enabled(slot))
  end
  return items, slots
end

function Page.party(layout, options)
  local items, slots = {}, {}
  for slot = 1, 6 do
    local source = options.monAt(slot)
    local mon = source and options.monView(source)
    items[slot], slots[slot] = { label = mon and (mon.nickname or mon.name or "") or "-",
      rawMon = source, mon = mon, inert = not options.enabled(slot),
      rect = { layout:partySelectionRect(slot, 6, true) } }, slot
  end
  items[7], slots[7] = { label = "CANCEL", inputKey = options.cancelKey,
    rect = { layout:partySelectionRect(7, 6, true) } }, options.cancelValue or 7
  return items, slots
end

function Page.actions(layout, items)
  for slot, item in ipairs(items) do item.rect = { layout:partyActionRow(slot, #items) } end
end

return Page
