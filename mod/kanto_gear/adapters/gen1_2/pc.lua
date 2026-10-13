-- Project native item-PC state onto the common companion list. Native A/B
-- handlers still own transfers, reordering, confirmations and result messages.
local PC = {}
local titles = { pc_item_withdraw = "WITHDRAW", pc_item_deposit = "DEPOSIT",
  pc_item_toss = "TOSS" }

local function describe(top)
  if type(top) ~= "table" or type(top.update) ~= "function" then return end
  -- Game path [Gen 1/2]: Gen 1 uses pc_item_* lists; Gen 2 uses phased ItemPcMenu and an embedded PackMenu.
  if titles[top.kind] and type(top.items) == "table" and not top.script then
    return { source = top, rows = top.items, field = "index", title = titles[top.kind],
      phase = top.kind, notice = top.pcCompletion and top.footer }
  elseif top.screenId == "PlayerPC" and type(top.items) == "table" then
    return { source = top, rows = top.items, field = "index", title = "ITEM PC" }
  elseif top.screenId == "Gen2ItemPcMenu" and not top.qtyState and not top.confirm then
    if top.message then
      return { source = top, rows = top.entries, field = "index", title = "ITEM PC",
        phase = top.phase, notice = top.message }
    elseif top.phase == "menu" then
      return { source = top, rows = top.entries, field = "index", title = "ITEM PC", phase = top.phase }
    elseif top.phase == "withdraw" or top.phase == "toss" then
      return { source = top, rows = top.rows, field = "listIndex", title = top.phase:upper(),
        phase = top.phase, cancel = true, switching = top.switching }
    elseif top.phase == "deposit" and top.pack then
      local pack = top.pack
      if pack.qtyState or pack.confirm or pack.submenu or pack.message and not pack.switching then return end
      return { source = pack, rows = pack.rows, field = "index", title = pack:pocket().label,
        phase = top.phase, cancel = true, switching = pack.switching,
        pocket = pack:pocket().label, pocketIndex = pack.pocketIndex }
    end
  end
end

function PC.quantityRow(top)
  if top and top.screenId == "Gen2ItemPcMenu" and top.phase == "deposit" and top.pack then
    return top.pack.rows[top.pack.index]
  end
end

function PC.project(top, isTop, translate, previous)
  local state = describe(top)
  if not state or type(state.rows) ~= "table" then return end
  local source, rows, field = state.source, state.rows, state.field
  if type(source[field]) ~= "number" then return end
  for _, row in ipairs(rows) do
    if type(row) ~= "table" or type(row.label or row.name) ~= "string" then return end
  end
  local key = table.concat({ tostring(top), tostring(source), tostring(rows), tostring(state.phase),
    tostring(state.notice), tostring(state.switching), tostring(state.pocketIndex) }, ":")
  local view = previous
  if not view or view.nativeKey ~= key then
    view = { screenId = "CompanionMenu", nativeKey = key, owner = top, update = function() end,
      items = {}, title = state.title, nativePocket = state.pocket, notice = state.notice }
    view.valid = function(preview)
      if not isTop(top) then return false end
      local current = describe(top)
      return current ~= nil and current.source == source and current.rows == rows
        and current.phase == state.phase and current.notice == state.notice
        and current.switching == state.switching and current.pocketIndex == state.pocketIndex
        and (preview or not top.repeatSfx and not source.repeatSfx)
    end
    -- Only the cursor is writable; no native inventory or callbacks are copied.
    setmetatable(view, { __index = function(_, name)
      if name == "index" then return state.notice and 1 or source[field] end
    end, __newindex = function(t, name, value)
      if name == "index" then
        source[field] = value
        if source.ensureVisible then source:ensureVisible()
        elseif source.itemBox then source.scroll = math.max(0, value - (source.cursorRows or source.rows or 4)) end
      else rawset(t, name, value) end
    end })
  end
  if state.notice then
    view.items = { { label = "CONTINUE" } }
  else
    for index, row in ipairs(rows) do
      local entry = view.items[index] or {}
      entry.label = row.label or row.name
      entry.value = row.cancel and "quit" or row.value or row.id or "item"
      entry.right = row.right or (row.count ~= nil and row.showCount ~= false and "x" .. row.count or nil)
      view.items[index] = entry
    end
    local total = #rows
    if state.cancel then total = total + 1; view.items[total] = { label = translate("CANCEL"), value = "quit" } end
    for index = #view.items, total + 1, -1 do view.items[index] = nil end
  end
  return view
end

return PC
