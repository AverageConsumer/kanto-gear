-- Native legacy storage owns every transfer, safety check and confirmation.
-- Only its cursor is projected onto the shared box/team/action pages.
local Storage = {}
local modes = { pc_box_withdraw = "WITHDRAW", pc_box_deposit = "DEPOSIT", pc_box_release = "RELEASE" }

local function describe(top, game)
  if type(top) ~= "table" or type(top.update) ~= "function" then return end
  -- Game path [Gen 1/2]: Gen 2 has move/insert phases; Gen 1 below uses separate withdraw/deposit/release lists.
  if top.screenId == "Gen2BoxMenu" and type(top.list) == "function" then
    if top.message or top.cryWait or top.messageFrames then
      return { kind = "notice", field = "index", title = top.mode:upper(),
        notice = top.message or true, waiting = top.cryWait ~= nil or top.messageFrames ~= nil }
    end
    local mons = top:list()
    if top.phase == "submenu" then
      return { kind = "actions", rows = top:submenuRows(), mons = mons,
        field = "submenuIndex", mon = mons[top.index], title = top.mode:upper() }
    elseif not top.phase or top.phase == "insert" then
      return { kind = "box", mons = mons, field = "index", title = top.mode:upper(),
        name = top:title(), party = top.mode == "deposit" or top:isParty(),
        inserting = top.phase == "insert", positions = top.phase == "insert" and top:insertPositions(),
        cancel = top.phase == "insert" and 0 or #mons + 1, move = top.mode == "move" }
    end
  elseif modes[top.kind] and type(top.items) == "table" then
    local party = top.kind == "pc_box_deposit"
    local mons = party and game.save.party or game.save.boxes[game.save.currentBox or 1]
    return { kind = "box", rows = top.items, mons = mons or {}, field = "index",
      title = modes[top.kind], party = party, cancel = #top.items,
      name = party and "PARTY" or "BOX " .. (game.save.currentBox or 1) }
  elseif top.kind == "pc_box_change" and type(top.items) == "table" then
    return { kind = "change", rows = top.items, field = "index", title = "CHANGE BOX" }
  elseif top.screenId == "Gen2PcMenu" and not top.message and not top.savePhase then
    return { kind = top.picking and "change" or "root", rows = top.entries,
      field = top.picking and "pickIndex" or "index", title = top.picking and "CHANGE BOX" or "PC" }
  elseif top.screenId == "BoxMenu" or top.screenId == "Gen2CenterPcMenu" and not top.message and not top.confirm then
    return { kind = "root", rows = top.items or top.entries, field = "index", title = "PC" }
  elseif getmetatable(top) == require("src.ui.Menu") then
    local states = game.stack.states or {}
    local parent = states[#states - 1]
    if parent and (parent.kind == "pc_box_withdraw" or parent.kind == "pc_box_deposit")
        and type(top.items) == "table" and #top.items == 3 then
      local row = parent.items[parent.index]
      local mons = parent.kind == "pc_box_deposit" and game.save.party
        or game.save.boxes[game.save.currentBox or 1]
      return { kind = "actions", rows = top.items, mons = mons, field = "index",
        mon = row and mons and mons[row.value], title = modes[parent.kind] }
    end
  end
end

local function keyFor(top, state, game)
  local parts = { tostring(top), state.kind, tostring(state.rows), tostring(state.mons),
    tostring(top.phase), tostring(top.mode), tostring(top.boxIndex), tostring(top.picking),
    tostring(top.moveFrom), tostring(state.mon), tostring(game.save.currentBox), tostring(state.cancel) }
  parts[#parts + 1] = tostring(state.notice)
  parts[#parts + 1] = tostring(state.waiting)
  parts[#parts + 1] = tostring(top.messagePage)
  for _, mon in ipairs(state.mons or {}) do parts[#parts + 1] = tostring(mon) end
  return table.concat(parts, ":")
end

function Storage.project(top, game, page, layout, previous)
  local state = describe(top, game)
  if not state or type(top[state.field]) ~= "number" then return end
  local key = keyFor(top, state, game)
  local view = previous
  if not view or view.nativeKey ~= key then
    view = { screenId = "CompanionMenu", nativeKey = key, owner = top, update = function() end }
    view.valid = function(preview)
      if game.stack:top() ~= top then return false end
      local current = describe(top, game)
      return current ~= nil and keyFor(top, current, game) == key
        and (preview or not state.waiting and not top.frozen and not top.repeatSfx)
    end
    setmetatable(view, { __index = function(t, name)
      if name ~= "index" then return end
      if state.kind == "notice" then return 1 end
      local value = top[state.field]
      if not t.nativeSlots then return value end
      for i, slot in ipairs(t.nativeSlots) do
        if slot == value and not t.items[i].inert then return i end
      end
    end, __newindex = function(t, name, value)
      if name ~= "index" then rawset(t, name, value); return end
      if not t.valid() or state.kind == "notice" or t.items[value].inputKey then return end
      top[state.field] = t.nativeSlots and t.nativeSlots[value] or value
      if top.ensureVisible then top:ensureVisible()
      elseif top.clampScroll then top:clampScroll()
      elseif top.itemBox then top.scroll = math.max(0, top.index - (top.cursorRows or top.rows or 4)) end
    end })
  end
  local items, slots = {}, nil
  if state.kind == "box" then
    local function monAt(slot)
      local row = state.rows and state.rows[slot]
      return state.mons[row and not row.cancel and row.value or slot]
    end
    local function enabled(slot)
      return state.inserting and slot <= state.positions or not state.inserting and monAt(slot) ~= nil
    end
    if state.party then
      items, slots = page.party(layout, { monAt = monAt, monView = function(mon) return mon end,
        enabled = enabled, cancelValue = state.cancel, cancelKey = "b" })
    else
      -- Game path [Gen 1/2]: boxes hold 20 Pokemon; Gen 3 uses 30, so native slot identities cannot share a fixed capacity.
      items, slots = page.box({ capacity = 20, name = state.name, nameInert = true,
        primary = { label = state.title, value = -10, inert = true },
        cancel = { label = "CANCEL", value = state.cancel, key = "b" },
        monAt = monAt, enabled = enabled })
    end
  elseif state.kind == "notice" then
    items = { { label = "CONTINUE" } }
  elseif state.kind == "change" then
    local count = top.screenId == "Gen2PcMenu" and 14 or #state.rows
    for i = 1, count do
      items[i] = { label = state.rows[i] and top.screenId ~= "Gen2PcMenu" and state.rows[i].label
          or game.save.boxNames and game.save.boxNames[i] or "BOX " .. i,
        right = #(game.save.boxes[i] or {}) .. "/20" }
    end
  else
    for i, row in ipairs(state.rows or {}) do
      items[i] = { label = type(row) == "table" and row.label or row }
    end
    if state.kind == "actions" then page.actions(layout, items) end
  end
  if #items == 0 then return end
  view.items, view.nativeSlots, view.title = items, slots, state.title
  view.notice = state.notice
  view.nativeGrid = state.kind == "box" and not state.party
  view.boxParty = state.kind == "box" and state.party
  view.emptyTargets = nil
  if state.inserting then
    view.emptyTargets = {}
    for slot = 1, 6 do view.emptyTargets[slot] = slot <= state.positions end
  end
  view.partyActions = state.kind == "actions" and state.mon or nil
  view.fixedLayout = state.kind == "box" or state.kind == "actions"
  view.nativePocket = state.move and state.name or nil
  return view
end

return Storage
