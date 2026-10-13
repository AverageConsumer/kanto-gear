-- Native field bags project their live rows and actions onto the common list.
-- Cursor selection and A/B remain the only writes; the host owns item effects.
local Bag = {}

local function describe(top, game, isGen2)
  if type(top) ~= "table" or type(top.update) ~= "function" then return end
  -- Game path [Gen 2]: PackMenu owns pockets and nested prompts; Gen 1 below uses ListMenu plus a separate action menu.
  if isGen2 then
    if getmetatable(top) ~= require("src.ui.gen2.PackMenu") or top:inBattle() or top.tutorial then return end
    if top.qtyState then return end -- the common quantity page already owns this
    local title = top.give and "GIVE" or "BAG"
    if top.message and not top.switching then
      return { kind = "notice", source = top, field = "index", record = top.message,
        page = top.messagePage, title = title }
    elseif top.confirm then
      return { kind = "choice", source = top.confirm, field = "choice", record = top.confirm,
        prompt = top.confirm.prompt, title = title }
    elseif top.submenu then
      return { kind = "actions", source = top.submenu, field = "index", rows = top.submenu.rows,
        item = top.submenu.row, title = top.submenu.row.name }
    end
    return { kind = "items", source = top, field = "index", rows = top.rows, cancel = true,
      pocket = not top.switching and top:pocket().label or nil,
      pocketIndex = top.pocketIndex, switching = top.switching, title = title }
  end
  local function isBag(candidate)
    return candidate and getmetatable(candidate) == require("src.ui.ListMenu")
      and candidate.kind == "bag" and candidate.itemBox and not candidate.script
  end
  if isBag(top) then
    return { kind = "items", source = top, field = "index", rows = top.items,
      switching = top.swapIndex, title = "BAG" }
  end
  local states = game.stack.states or {}
  local parent = states[#states - 1]
  if isBag(parent) and parent.hollowIndex == parent.index
      and getmetatable(top) == require("src.ui.Menu") then
    return { kind = "actions", source = top, field = "index", rows = top.items,
      parent = parent, item = parent.items[parent.index], title = parent.items[parent.index].label }
  end
end

local function keyFor(top, state)
  local parts = { tostring(top), state.kind, tostring(state.source), tostring(state.rows),
    tostring(state.record), tostring(state.page), tostring(state.item), tostring(state.parent),
    tostring(state.pocketIndex), tostring(state.switching) }
  for _, row in ipairs(state.rows or {}) do
    parts[#parts + 1] = tostring(row)
    if type(row) == "table" then
      parts[#parts + 1] = tostring(row.label or row.name)
      parts[#parts + 1] = tostring(row.count or row.right)
    end
  end
  return table.concat(parts, ":")
end

function Bag.project(top, game, isGen2, previous)
  local state = describe(top, game, isGen2)
  if not state or type(state.source[state.field]) ~= "number" then return end
  for _, row in ipairs(state.rows or {}) do
    if type(row) ~= "string" and (type(row) ~= "table" or type(row.label or row.name) ~= "string") then return end
  end
  local key = keyFor(top, state)
  local view = previous
  if not view or view.nativeKey ~= key then
    view = { screenId = "CompanionMenu", nativeKey = key, owner = top, update = function() end }
    view.valid = function(preview)
      if game.stack:top() ~= top then return false end
      local current = describe(top, game, isGen2)
      return current ~= nil and keyFor(top, current) == key
        and (preview or not top.repeatSfx and not top.frozen)
    end
    setmetatable(view, { __index = function(_, name)
      if name == "index" then return state.kind == "notice" and 1 or state.source[state.field] end
    end, __newindex = function(t, name, value)
      if name ~= "index" then rawset(t, name, value); return end
      if not t.valid() or state.kind == "notice" then return end
      state.source[state.field] = value
      if state.source.ensureVisible then state.source:ensureVisible()
      elseif state.source.itemBox then
        state.source.scroll = math.max(0, value - (state.source.cursorRows or 4))
      elseif state.source.clampScroll then state.source:clampScroll() end
    end })
  end
  local items = {}
  if state.kind == "notice" then items = { { label = "CONTINUE" } }
  elseif state.kind == "choice" then items = { { label = "YES" }, { label = "NO" } }
  else
    for i, row in ipairs(state.rows) do
      if type(row) == "string" then
        items[i] = { label = row == "sel" and "REGISTER" or row == "quit" and "CANCEL" or row:upper() }
      else
        items[i] = { label = row.label or row.name,
          itemId = state.kind == "items" and (row.id or row.value) or nil,
          right = row.right or row.count ~= nil and row.showCount ~= false and "x" .. row.count or nil }
      end
    end
    if state.cancel then items[#items + 1] = { label = "CANCEL" } end
  end
  view.items, view.title, view.nativePocket = items, state.title, state.pocket
  view.itemActionId = state.kind == "actions" and (state.item.id or state.item.value) or nil
  view.itemActionCount = state.kind == "actions" and state.item.count or nil
  view.fixedLayout = view.itemActionId ~= nil
  view.bagList = state.kind == "items" and not state.switching and not top.give
  view.notice = state.kind == "notice" and state.record or nil
  view.choiceState = state.kind == "choice" and (view.choiceState or { page = 1 }) or nil
  view.prompt = state.prompt
  return view
end

return Bag
