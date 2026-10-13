return function(H, ui, draw)
  local PC_LIST_TOP, PC_LIST_HEIGHT, PC_LIST_GAP = 63, 33, 3

  function H:pcNoticeRows(count)
    local visible = math.max(1, math.min(4, count or 0))
    local lineHeight = visible == 4 and 13 or visible == 3 and 16 or 18
    local blockHeight = 9 + (visible - 1) * lineHeight
    return 105 + math.floor((53 - blockHeight) / 2), lineHeight, visible
  end

  function H:pcListHit(x, y, count)
    if x < 7 or x >= 233 then return nil end
    local row = math.floor((y - PC_LIST_TOP) / (PC_LIST_HEIGHT + PC_LIST_GAP)) + 1
    local top = PC_LIST_TOP + (row - 1) * (PC_LIST_HEIGHT + PC_LIST_GAP)
    if row >= 1 and row <= math.min(4, count or 0)
        and y >= top and y < top + PC_LIST_HEIGHT then return row end
  end

  function H:pcQuantityEnabled(model, action)
    if not model or action ~= "minus" and action ~= "plus" then return true end
    local qty, minimum, maximum = model.qty or 1, model.min or 1, model.max
    if model.wrap and maximum then return maximum > minimum end
    if action == "minus" then return qty > minimum end
    return not maximum or qty < maximum
  end

  function H:pcQuantityHit(x, y, model)
    if y >= 91 and y < 139 then
      if x >= 7 and x < 81 and self:pcQuantityEnabled(model, "minus") then return "minus" end
      if x >= 159 and x < 233 and self:pcQuantityEnabled(model, "plus") then return "plus" end
    elseif y >= 146 and y < 210 then
      if x >= 7 and x < 117 then return "confirm" end
      if x >= 123 and x < 233 then return "cancel" end
    end
  end

end
