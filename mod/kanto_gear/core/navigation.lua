return function(PC_LIST_KINDS, rowsContract)
local function choiceReady(now, readyAt)
  return now >= readyAt
end

local function textTouch(top)
  -- Game path [Gen 2]: SaveMenu owns its printer; only question pages accept touch, while writing/completion phases remain timed.
  if top and top.screenId == "Gen2SaveMenu" then
    -- Save owns its printer instead of pushing a TextBox. Only its question
    -- pages accept A; the write and completion messages are timed sequences.
    if (top.phase ~= "confirm" and top.phase ~= "overwrite")
        or top.typedPhase ~= top.phase or not top.typer or not top.pages then return nil end
    if not top.typer:done() then return "speed" end
    if top.page < #top.pages then return "advance" end
    return nil
  end
  if not (top and top.isTextBox) then return nil end
  if top.waiting then return "advance" end
  if not top.done then return "speed" end
  if not top.choice then return "advance" end
end

local function textPrompt(top)
  return textTouch(top) == "advance"
end

local function namingCell(x, y, grid)
  if not grid or x < 3 or x >= 157 or y < 36 then return end
  local offset = y - 36
  local row = math.floor(offset / 17) + 1
  if offset % 17 >= 15 or not grid[row] or #grid[row] == 0 then return end
  local col = math.floor((x - 3) * #grid[row] / 154) + 1
  return row, col
end

local function pageSwipeAllowed(mode, battle)
  return mode == "active" and not battle
end

local function carouselSubpage(current, count, direction)
  local nextPage = math.max(1, math.min(count, current or 1)) + direction
  if nextPage >= 1 and nextPage <= count then return nextPage end
end

local function pagedIndex(index, count, direction)
  return math.max(1, math.min(count, index + direction * 4))
end

local function pageWindow(index, count)
  local first = math.floor((math.max(1, index or 1) - 1) / 4) * 4 + 1
  return first, math.min(4, math.max(0, count - first + 1))
end

local function partySlotAt(x, y, count)
  if y < 23 or y >= 140 then return nil end
  local col = x >= 81 and x < 156 and 1 or x >= 3 and x < 78 and 0 or nil
  if col == nil then return nil end
  local row = math.floor((y - 23) / 39)
  local slot = row * 2 + col + 1
  return slot <= (count or 0) and slot or nil
end

local function moveGridLayout(state, owned)
  if owned then return true end
  if not (state and type(state.wideLayout) == "function") then return false end
  local ok, wide = pcall(state.wideLayout, state)
  return ok and wide == true or false
end

local function moveSlotAt(x, y, count, grid)
  local col, row, left, top
  if grid then
    col = x >= 81 and x < 157 and 1 or x >= 3 and x < 79 and 0 or nil
    row = y >= 80 and y < 136 and 1 or y >= 24 and y < 78 and 0 or nil
    if col == nil or row == nil then return nil end
    left, top = 3 + col * 78, 24 + row * 56
  else
    if x < 8 or x >= 152 or y < 24 or y >= 135 then return nil end
    row = math.floor((y - 24) / 28)
    if (y - 24) % 28 >= 27 then return nil end
    left, top = 8, 24 + row * 28
  end
  local slot = row * (grid and 2 or 1) + (col or 0) + 1
  if slot > (count or 0) then return nil end
  return slot, left, top
end

local function progressRatio(value, first, last)
  if last <= first then return 1 end
  return math.max(0, math.min(1, ((value or first) - first) / (last - first)))
end

local function pcListKind(state)
  if not state then return nil end
  if PC_LIST_KINDS[state.kind] and rowsContract(state.items)
      and type(state.index) == "number" then return state.kind end
  -- Game path [Gen 2]: box selection is a PC/BoxMenu phase rather than a Gen 1 pc_box_change list.
  if state.screenId == "Gen2PcMenu" and state.picking
      and not state.savePhase and type(state.pickIndex) == "number" then
    return "gen2_box_change"
  end
  if state.screenId == "Gen2BoxMenu"
      and (not state.phase or state.phase == "insert")
      and not state.message and type(state.index) == "number"
      and (state.mode == "withdraw" or state.mode == "deposit"
        or state.mode == "move") then
    return "gen2_box_" .. state.mode
  end
  if state.screenId == "Gen2ItemPcMenu" and not state.message
      and not state.qtyState and not state.confirm
      and (state.phase == "withdraw" or state.phase == "toss")
      and rowsContract(state.rows) and type(state.listIndex) == "number" then
    return "gen2_item_" .. state.phase
  end
end

local function savedSteps(value)
  return math.max(0, math.floor(tonumber(value) or 0))
end
  return carouselSubpage, choiceReady, moveGridLayout, moveSlotAt, namingCell, pageSwipeAllowed, pageWindow, pagedIndex, partySlotAt, pcListKind, progressRatio, savedSteps, textPrompt, textTouch
end
