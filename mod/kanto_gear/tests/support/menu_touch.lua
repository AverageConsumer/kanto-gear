-- Tap the rendered target for a native slot, including sparse storage grids.
return function(display, gesture)
  return function(slot)
    local view = assert(display.startMenu(), "native menu has a common projection")
    local model = assert(display.startMenuModel(view))
    for row, entry in ipairs(model.entries) do
      local index = model.first + row - 1
      local native = view.nativeSlots and view.nativeSlots[index] or index
      if native == slot and not entry.disabled then
        local x, y = math.floor((entry.x + entry.w / 2) / 1.5), math.floor((entry.y + entry.h / 2) / 1.5)
        gesture(("tap,%d,%d"):format(x, y))
        return
      end
    end
    error("native slot is not visible and active: " .. tostring(slot))
  end
end
