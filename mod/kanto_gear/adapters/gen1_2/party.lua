-- Native party selectors, submenus and held-item actions share the same team
-- and action pages as Gen 3. Native update handlers still own every effect.
local Party = {}

local function describe(top, game, isGen2)
  if type(top) ~= "table" or type(top.update) ~= "function" then return end
  -- Game path [Gen 1/2]: native party classes and submenu cursors differ; retain the active menu as input owner.
  local gen2 = isGen2 and getmetatable(top) == require("src.ui.gen2.PartyMenu")
  local gen1 = not isGen2 and getmetatable(top) == require("src.ui.PartyMenu")
  if gen1 or gen2 then
    if top.battle then return end
    local mons = top.party or game.save.party
    if top.heal or top.swapAnim or top.itemResult then
      return { kind = "notice", source = top, field = "index", mons = mons,
        record = top.heal or top.swapAnim or top.itemResult,
        waiting = top.heal ~= nil or top.swapAnim ~= nil or gen2 and top:itemResultClimbing(), title = "PARTY" }
    elseif top.submenu then
      return { kind = "actions", source = gen2 and top.submenu or top,
        field = gen2 and "index" or "subIndex", rows = gen2 and top.submenu.items or top.subItems,
        mon = mons[top.index], mons = mons, title = "PARTY" }
    end
    local title = top.tmhm and "TEACH MOVE TO" or top.itemUse and "USE ITEM ON" or "PARTY"
    if gen2 then
      local prompts = require("src.ui.gen2.PartyMenu").PROMPTS
      if top.prompt == prompts.useItem then title = "USE ITEM ON"
      elseif top.prompt == prompts.teach then title = "TEACH MOVE TO"
      elseif top.prompt == prompts.toWhich or top.prompt == "Give to which <PK><MN>?" then title = "GIVE ITEM TO" end
    end
    if top.switchFrom or top.swapFrom then title = "SWAP WITH?" end
    return { kind = "team", source = top, field = "index", mons = mons, title = title,
      from = top.switchFrom or top.swapFrom, soft = top.softboiledFrom }
  -- Game path [Gen 2]: held items have a separate message/confirmation menu; Gen 1 has no held-item system.
  elseif isGen2 and getmetatable(top) == require("src.ui.gen2.HeldItemMenu") and not top.busy then
    local confirm = top.confirm
    if top.message or confirm then
      local ready = confirm and confirm.page == #confirm.pages and not require("src.ui.gen2.Typer").typing(top)
      return { kind = ready and "choice" or "notice", source = ready and confirm or top,
        field = ready and "choice" or "index", record = top.message or confirm,
        page = (top.message or confirm).page, title = "ITEM" }
    end
    return { kind = "actions", source = top, field = "index", rows = top.ENTRIES,
      mon = top:mon(), title = "ITEM" }
  end
end

local function keyFor(top, state)
  local parts = { tostring(top), state.kind, tostring(state.source), tostring(state.rows),
    tostring(state.record), tostring(state.page), tostring(state.waiting), tostring(state.mon),
    tostring(state.mons), tostring(state.from), tostring(state.soft), tostring(state.pocketIndex) }
  for _, mon in ipairs(state.mons or {}) do parts[#parts + 1] = tostring(mon) end
  for _, row in ipairs(state.rows or {}) do
    parts[#parts + 1] = tostring(row)
    parts[#parts + 1] = tostring(row.label)
    parts[#parts + 1] = tostring(row.count)
  end
  return table.concat(parts, ":")
end

function Party.project(top, game, isGen2, page, layout, previous)
  local state = describe(top, game, isGen2)
  if not state or type(state.source[state.field]) ~= "number" then return end
  local key = keyFor(top, state)
  local view = previous
  if not view or view.nativeKey ~= key then
    view = { screenId = "CompanionMenu", nativeKey = key, owner = top, update = function() end }
    view.valid = function(preview)
      if game.stack:top() ~= top then return false end
      local current = describe(top, game, isGen2)
      return current ~= nil and keyFor(top, current) == key
        and (preview or not state.waiting and not top.repeatSfx)
    end
    setmetatable(view, { __index = function(t, name)
      if name ~= "index" then return end
      if state.kind == "notice" then return 1 end
      local value = state.source[state.field]
      if not t.nativeSlots then return value end
      for i, slot in ipairs(t.nativeSlots) do if slot == value and not t.items[i].inert then return i end end
    end, __newindex = function(t, name, value)
      if name ~= "index" then rawset(t, name, value); return end
      if not t.valid() or state.kind == "notice" or t.items[value].inputKey then return end
      state.source[state.field] = t.nativeSlots and t.nativeSlots[value] or value
      if state.source.ensureVisible then state.source:ensureVisible() end
    end })
  end
  local items, slots
  if state.kind == "team" then
    items, slots = page.party(layout, { monAt = function(slot) return state.mons[slot] end,
      monView = function(mon) return mon end, enabled = function(slot) return state.mons[slot] ~= nil end,
      cancelValue = #state.mons + 1, cancelKey = "b" })
  elseif state.kind == "actions" then
    items = {}
    for i, row in ipairs(state.rows or {}) do items[i] = { label = row.label } end
    if #items <= 3 then page.actions(layout, items) end
  elseif state.kind == "choice" then items = { { label = "YES" }, { label = "NO" } }
  else items = { { label = "CONTINUE" } } end
  if #items == 0 then return end
  view.items, view.nativeSlots, view.title = items, slots, state.title
  view.partyMons = state.mons
  view.party = (state.kind == "team" or state.kind == "notice") and state.mons and top or nil
  view.fixedLayout = state.kind == "team" or state.kind == "actions" and #items <= 3
  view.partyActions = state.kind == "actions" and #items <= 3 and state.mon or nil
  view.notice = state.kind == "notice" and state.record or nil
  view.prompt = state.kind == "choice" and state.record.pages[state.page] or nil
  view.choiceState = state.kind == "choice" and (view.choiceState or { page = 1 }) or nil
  return view
end

return Party
