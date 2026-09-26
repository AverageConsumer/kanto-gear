-- Native FRLG menu projections. All activation is routed through the host's
-- normal input handler; Gear never invokes item/switch callbacks itself.
local UI = {}
UI.__index = UI

function UI.new(adapter)
  return setmetatable({ adapter = adapter, Stack = require("src.ui.game3.stack"),
    Message = require("src.ui.game3.message"), Choice = require("src.ui.game3.choice") }, UI)
end

local partyModes = { list = true, switch = true, use = true, give = true,
  choose = true, choose_multi = true, move_tutor = true, softboiled = true,
  battle_switch = true, battle_faint = true }

local function labels(items)
  local out = {}
  for _, item in ipairs(items or {}) do
    out[#out + 1] = { label = type(item) == "table" and item.label or tostring(item) }
  end
  return out
end

function UI:list(battle)
  local Message, Choice = self.Message, self.Choice
  if Choice.active and Choice.options then
    local key = Choice.options
    local view = self.choiceView
    if not view or view.options ~= key then
      view = { screenId = "Gen3Menu", title = "CHOOSE ACTION", options = key,
        nativeKey = tostring(key), update = function() end,
        valid = function() return Choice.active and Choice.options == key end }
      setmetatable(view, {
        __index = function(_, k) if k == "index" then return Choice.cursor end end,
        __newindex = function(t, k, v)
          if k == "index" then if t.valid() then Choice.cursor = v end
          else rawset(t, k, v) end
        end,
      })
      self.choiceView = view
    end
    view.items = labels(key)
    return view
  end
  if Message.isOpen() then return nil end
  local layer = self.Stack.top()
  if not layer and battle and battle.prompt == "target" then
    local U = self.adapter.BattleUI
    local target = U and U._target
    if not target then return nil end
    local items, ids, selected = {}, {}, 1
    local owner = self.adapter:battleState()
    local active = owner and owner.battle and (target.battler == 2
      and owner.battle.battlers[2] or owner.battle.player)
    local move = active and active.mon.moves and active.mon.moves[target.slot]
    local def = move and self.adapter.Moves.get(move)
    local selfTarget = math.floor((tonumber(def and def.target) or 0) / 2) % 2 == 1
    local allowed = {}
    for _, id in ipairs(battle.targets or {}) do allowed[id] = true end
    -- The native target cursor cycles by battlefield identity, not API order.
    for _, id in ipairs({ 0, 2, 3, 1 }) do
      for _, mon in ipairs(battle.battlers or {}) do
        if allowed[id] and mon.id == id and (id ~= target.battler or selfTarget) then
          items[#items + 1], ids[#ids + 1] = { label = mon.name or "POKEMON",
            right = (mon.side == "player" and "ALLY" or "FOE") }, id
          if target.cursor == id then selected = #items end
        end
      end
    end
    local view = self.targetView
    if not view or view.target ~= target then
      view = { screenId = "Gen3Menu", title = "CHOOSE TARGET", target = target,
        nativeKey = tostring(target), update = function() end,
        valid = function() return self.Stack.top() == nil and U._mode == "target" and U._target == target end }
      self.targetView = view
    end
    view.items, view.battleTargets, view.index = items, ids, selected
    return view
  end
  if not layer or not layer.mod or layer.mod.open ~= true then return nil end
  local native, items, field, title, slots = layer.mod
  local pocket, partyLayout = false, false
  if layer.id == "start" and not native._confirmExit then
    items, field, title = labels(native.ENTRIES), "cursor", "CHOOSE ACTION"
  elseif layer.id == "party" and not native._hpAnim and not native._pokedude then
    title = "PARTY"
    if partyModes[native.mode] then
      partyLayout = true
      items, slots, field = {}, {}, "cursor"
      for i, mon in ipairs(native._party or {}) do
        local view = self.adapter:mon(mon)
        local def = self.adapter.data.pokemon[view.species] or {}
        items[#items + 1] = { label = view.nickname or def.name or "POKEMON",
          mon = view, nativeSlot = i, right = "L" .. tostring(view.level or 0)
            .. " " .. tostring(view.hp or 0) .. "/" .. tostring(view.maxHp or 0) }
        slots[#slots + 1] = i
      end
      -- Native single/double layouts reserve slot 7 for CANCEL, even with
      -- fewer than six party members. Display order may also be battle-local.
      if native.mode == "choose_multi" then
        items[#items + 1], slots[#slots + 1] = { label = "CONFIRM" }, 7
      end
      items[#items + 1], slots[#slots + 1] = { label = "CANCEL" }, native.mode == "choose_multi" and 8 or 7
      -- Match FRLG's lead slot on the left and remaining party on the right.
      -- Keep all slots visible: native Left/Right jumps between these columns.
      for i, slot in ipairs(slots) do
        items[i].rect = slot == 1 and { 6, 50, 91, 109 }
          or slot <= 6 and { 103, 33 + (slot - 2) * 29, 131, 27 }
          or slot == 7 and native.mode == "choose_multi" and { 6, 183, 91, 27 }
          or { 103, 183, 131, 27 }
      end
      if native.mode == "use" then title = "USE ITEM ON" end
    elseif native.mode == "action" then
      items, field = labels(native.ACTIONS), "actionCursor"
    elseif native.mode == "item_action" then
      items, field = labels(native.ITEM_ACTIONS), "itemActionCursor"
    end
  elseif (layer.id == "tm_case" or layer.id == "berry_pouch")
      and not native._fromBerryCrush then
    title = layer.id == "tm_case" and "TM/HM" or "BERRIES"
    if native.mode == "list" then
      items, field = {}, "cursor"
      for _, row in ipairs(native.list()) do
        items[#items + 1] = { label = row.name or self.adapter.Items.displayName(row.id),
          right = "x" .. tostring(row.qty or 0) }
      end
      items[#items + 1] = { label = "CANCEL" }
    elseif native.mode == "action" and not native._sellMode then
      -- Native subcontainers use these fixed action orders (not Bag ACTIONS).
      items = labels(layer.id == "tm_case" and { "USE", "GIVE", "EXIT" }
        or { "USE", "GIVE", "TOSS", "EXIT" })
      field = "actionCursor"
    end
  elseif layer.id == "bag" and not native._pokedude and not native._statBoost then
    title = "BAG"
    if native.mode == "list" then
      items, field, pocket = {}, "cursor", true
      local id = native.currentPocket()
      title = ({ ITEMS = "ITEMS", KEY_ITEMS = "KEY ITEMS", POKE_BALLS = "BALLS" })[id] or "BAG"
      for _, item in ipairs(native.list()) do
        items[#items + 1] = { label = item.name or self.adapter.Items.displayName(item.id),
          right = "x" .. tostring(item.qty or 0), itemId = item.id }
      end
      items[#items + 1] = { label = "CANCEL" }
    elseif native.mode == "action" then
      items, field = labels(native.ACTIONS), "actionCursor"
    end
  end
  if not items or #items == 0 or type(native[field]) ~= "number" then return nil end
  local key = tostring(layer) .. ":" .. tostring(native.mode) .. ":" .. tostring(native.pocketIdx)
  local view = self.view
  if not view or view.nativeKey ~= key then
    local owner = self
    view = { screenId = "Gen3Menu", nativeKey = key, update = function() end }
    local mode, pocketIdx = native.mode, native.pocketIdx
    function view.valid(preview)
      return owner.Stack.top() == layer and native.open == true
        and native.mode == mode and native.pocketIdx == pocketIdx
        and not native._hpAnim and not native._pokedude and not native._statBoost
        and (preview or not native._switch and not native._exit and not native._open)
    end
    setmetatable(view, {
      __index = function(t, k)
        if k ~= "index" then return nil end
        local value = native[field]
        if not t.nativeSlots then return value end
        for i, slot in ipairs(t.nativeSlots) do if slot == value then return i end end
      end,
      __newindex = function(t, k, v)
        if k == "index" then
          if t.valid() then native[field] = t.nativeSlots and t.nativeSlots[v] or v end
        else rawset(t, k, v) end
      end,
    })
    self.view = view
  end
  view.items, view.nativeSlots, view.title, view.nativePocket = items, slots, title, pocket
  view.fixedLayout = partyLayout
  return view
end

function UI:openBagItem(id)
  local a, session = self.adapter, self.adapter.session
  if not session or not a.save or (a.save.inventory[id] or 0) <= 0
      or self.Stack.top() or self.Message.isOpen() or self.Choice.active then return false end
  local def = a.data.items[id]
  local pocket = def and def.nativePocket
  local menu
  if pocket == "TM_CASE" then
    menu = require("src.ui.game3.tm_case")
    menu.show(session, session.bag)
  elseif pocket == "BERRY_POUCH" then
    menu = require("src.ui.game3.berry_pouch")
    menu.show(session, session.bag)
  else
    menu = require("src.ui.game3.bag_menu")
    menu.show(session.bag, { session = session, pocket = pocket })
  end
  for i, row in ipairs(menu.list()) do
    if row.id == id then
      menu.cursor, menu.scroll = i, math.max(0, i - 1)
      return true
    end
  end
  menu.close()
  return false
end

return UI
