-- Project the live clerk's cursor and overlays; native handlers own money,
-- inventory limits, special-shop rules and every transaction.
local Shop = {}

function Shop.quantityTitle(game)
  local states = game.stack.states or {}
  for i = #states - 1, 1, -1 do
    if states[i].screenId == "ShopMenu" then return states[i].index == 1 and "BUY" or "SELL" end
  end
end

local function describe(top, game)
  if type(top) ~= "table" or type(top.update) ~= "function" then return end
  -- Game path [Gen 1/2]: Gen 2 owns quantity/confirmation phases in MartMenu; Gen 1 uses clerk dialogue lists below.
  if top.screenId == "Gen2MartMenu" and type(top.ensureVisible) == "function" then
    local phase = top.phase
    if top.message then
      return { kind = "notice", record = top.message, page = top.message.page, title = "SHOP" }
    elseif top.confirm then
      local record = top.confirm
      return { kind = top:yesNoVisible() and "choice" or "notice", record = record,
        page = record.page, source = record, field = "choice", title = "CONFIRM" }
    elseif phase == "buyQuantity" or phase == "sellQuantity" then
      return { kind = "quantity", source = top, field = "qty", title = phase == "buyQuantity" and "BUY" or "SELL" }
    elseif phase == "top" then
      return { kind = "root", source = top, field = "topIndex", title = "SHOP" }
    elseif phase == "buy" then
      return { kind = "buy", source = top, rows = top.entries, field = "index", title = "BUY", cancel = true }
    elseif phase == "sell" and top.pack then
      local pack = top.pack
      if pack.message and not pack.switching then
        return { kind = "notice", record = pack.message, page = pack.messagePage, title = "SELL" }
      elseif not pack.submenu and not pack.qtyState and not pack.confirm then
        return { kind = "sell", source = pack, rows = pack.rows, field = "index", title = "SELL",
          pocket = pack:pocket().label, pocketIndex = pack.pocketIndex, switching = pack.switching, cancel = true }
      end
    end
    return
  end
  if top.screenId == "ShopMenu" and not top.hidden and type(top.items) == "table" then
    return { kind = "root", source = top, rows = top.items, field = "index", title = "SHOP" }
  end
  -- Only a clerk's own dialogue list is eligible, never an unrelated ListMenu.
  if getmetatable(top) ~= require("src.ui.ListMenu") or not top.dialogue or type(top.money) ~= "function" then return end
  local states = game.stack.states or {}
  for i = #states - 1, 1, -1 do
    local parent = states[i]
    if parent.screenId == "ShopMenu" then
      return { kind = parent.index == 1 and "buy" or "sell", source = top, rows = top.items,
        field = "index", title = parent.index == 1 and "BUY" or "SELL", switching = top.swapIndex }
    end
  end
end

local function keyFor(top, state)
  local parts = { tostring(top), tostring(top.phase), state.kind, tostring(state.source),
    tostring(state.rows), tostring(state.record), tostring(state.page), tostring(state.pocketIndex),
    tostring(state.switching), tostring(top.qtyItem) }
  -- Host path [Gen 1/2]: in-place stock updates must invalidate the projection even when the list identity is unchanged.
  -- Older hosts update stock/count rows in place instead of replacing the list.
  for _, row in ipairs(state.rows or {}) do
    parts[#parts + 1] = tostring(row.id or row.value)
    parts[#parts + 1] = tostring(row.count)
    parts[#parts + 1] = tostring(row.soldOut)
    parts[#parts + 1] = tostring(row.price)
  end
  return table.concat(parts, ":")
end

function Shop.project(top, game, translate, previous)
  local state = describe(top, game)
  if not state then return end
  local key = keyFor(top, state)
  local view = previous
  if not view or view.nativeKey ~= key then
    view = { screenId = "CompanionMenu", nativeKey = key, owner = top, update = function() end }
    view.valid = function(preview)
      if game.stack:top() ~= top then return false end
      local current = describe(top, game)
      return current ~= nil and keyFor(top, current) == key
        and (preview or not top.repeatSfx and not (state.source and state.source.repeatSfx))
    end
    setmetatable(view, { __index = function(_, name)
      if name == "index" then return (state.kind == "notice" or state.kind == "quantity") and 1
        or state.source[state.field] end
    end, __newindex = function(t, name, value)
      if name ~= "index" then rawset(t, name, value); return end
      if not t.valid() or state.kind == "notice" or state.kind == "quantity" then return end
      state.source[state.field] = value
      if state.source.ensureVisible then state.source:ensureVisible()
      elseif state.source.itemBox then state.source.scroll = math.max(0, value - (state.source.cursorRows or 4)) end
    end })
  end
  local items = {}
  if state.kind == "notice" or state.kind == "quantity" then
    items = { { label = "CONTINUE" } }
  elseif state.kind == "choice" then
    items = { { label = "YES" }, { label = "NO" } }
  elseif state.kind == "root" and not state.rows then
    items = { { label = "BUY" }, { label = "SELL" }, { label = "QUIT" } }
  else
    for i, row in ipairs(state.rows) do
      items[i] = { label = row.name or row.label, itemId = row.id or row.value,
        right = row.soldOut and translate("SOLD OUT")
          or row.price ~= nil and (type(row.price) == "number" and "¥" .. row.price or row.price)
          or row.right or row.count and "x" .. row.count,
        inert = row.soldOut == true }
    end
    if state.cancel then items[#items + 1] = { label = "CANCEL" } end
  end
  view.items, view.title, view.nativePocket = items, state.title, state.pocket
  view.notice = state.kind == "notice" and state.record or nil
  view.quantity, view.prompt = nil, nil
  if state.kind == "quantity" then
    local item = top.qtyItem
    local native = require("src.ui.gen2.MartMenu")
    local price = state.title == "BUY" and native.buyPrice or native.sellPrice
    view.quantity = { label = item.name, qty = top.qty, max = top.qtyMax, wrap = true,
      total = price(item.price, top.qty) }
  elseif state.kind == "choice" then
    view.choiceState = view.choiceState or { page = 1 }
    view.prompt = state.record.pages[state.page]
  else view.choiceState = nil end
  return view
end

return Shop
