-- Native Gen 3 menu projections. All activation is routed through the host's
-- normal input handler; Gear never invokes item/switch callbacks itself.
local UI = {}
UI.__index = UI

function UI.new(adapter, layout)
  return setmetatable({ adapter = adapter, layout = layout, Stack = require("src.ui.game3.stack"),
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

-- Fallback for hosts without extracted naming pages (FRLG). Newer hosts
-- supply state.pages, including Emerald's extra blank cells. Those cells
-- determine where the native three-button column starts.
local keyboard = {
  { { "A", "B", "C", "D", "E", "F", " ", "." }, { "G", "H", "I", "J", "K", "L", " ", "," },
    { "M", "N", "O", "P", "Q", "R", "S" }, { "T", "U", "V", "W", "X", "Y", "Z" } },
  { { "a", "b", "c", "d", "e", "f", " ", "." }, { "g", "h", "i", "j", "k", "l", " ", "," },
    { "m", "n", "o", "p", "q", "r", "s" }, { "t", "u", "v", "w", "x", "y", "z" } },
  { { "0", "1", "2", "3", "4" }, { "5", "6", "7", "8", "9" },
    { "!", "?", "♂", "♀", "/", "-" }, { "…", "“", "”", "‘", "'" } },
}

function UI:naming(layer)
  local native, state = layer.mod, layer.mod._state
  if not native.openFlag or not state or state.finished then return nil end
  local page = state.pages and state.pages[state.page] and state.pages[state.page].rows
    or keyboard[state.page]
  if not page then return nil end
  local key = tostring(layer) .. ":" .. tostring(state) .. ":" .. state.page .. ":" .. tostring(state.pcPage)
  local view = self.namingView
  if not view or view.nativeKey ~= key then
    local columns, pageIndex, pcPages, pcPage = math.max(#page[1], #page[3]), state.page, state.pcPages, state.pcPage
    view = { screenId = "Gen3Menu", title = state.title, nativeKey = key, update = function() end,
      fixedLayout = true, nativeGrid = true, items = {} }
    function view.valid(preview)
      return self.Stack.top() == layer and native.openFlag and native._state == state
        and not state.finished and state.page == pageIndex
        and state.pcPages == pcPages and state.pcPage == pcPage
        and (preview or state.swapT == nil)
    end
    for row, chars in ipairs(page) do
      for col, char in ipairs(chars) do
        local left, right = 7 + math.floor((col - 1) * 176 / columns), 7 + math.floor(col * 176 / columns)
        view.items[#view.items + 1] = { label = char == " " and "_" or char, row = row, col = col,
          rect = { left, 75 + (row - 1) * 32, right - left - 2, 29 } }
      end
    end
    for i, label in ipairs({ ({ "abc", "123", "ABC" })[state.page], "BACK", "OK" }) do
      view.items[#view.items + 1] = { label = label, btn = i,
        rect = { 190, 75 + (i - 1) * 47, 43, 44 } }
    end
    setmetatable(view, {
      __index = function(t, k)
        if k == "index" then
          if state.pcPages then return 1 end
          for i, item in ipairs(t.items) do
            if state.col > #page[state.row] and item.btn == state.btn
                or state.col <= #page[state.row] and item.row == state.row and item.col == state.col then return i end
          end
        end
      end,
      __newindex = function(t, k, v)
        if k ~= "index" then rawset(t, k, v); return end
        if not t.valid() or state.pcPages then return end
        local item = t.items[v]
        if item.btn then
          state.row, state.btn = ({ 1, 2, 4 })[item.btn], item.btn
          state.col = #page[state.row] + 1
        else state.row, state.col = item.row, item.col end
      end,
    })
    self.namingView = view
  end
  view.name = state.name == "" and "-" or state.name
  view.notice, view.canAdvance = state.pcPages and state.pcPages[state.pcPage], true
  return view
end

function UI:release(layer)
  local native = require("src.ui.game3.release_seq")
  if not native.isActive() then return nil end
  local state, mon = native.state, native.mon
  local key = tostring(layer) .. ":release:" .. state .. ":" .. tostring(mon)
  local view = self.releaseView
  if not view or view.nativeKey ~= key then
    local text = require("src.core.game3.rom_text")
    view = { screenId = "Gen3Menu", title = "RELEASE", nativeKey = key, update = function() end,
      valid = function(preview) return self.Stack.top() == layer and native.isActive()
        and native.state == state and native.mon == mon and (preview or state ~= "anim") end }
    if state == "confirm" then
      view.items, view.fixedLayout, view.prompt = labels({ "YES", "NO" }), true,
        self.adapter.Pokemon.displayMonName(mon) .. "\n" .. text.plain("gText_ReleaseThisPokemon")
      for i, item in ipairs(view.items) do item.rect = { 7, 116 + (i - 1) * 47, 226, 44 } end
    else
      view.items, view.canAdvance = labels({ "CONTINUE" }), state ~= "anim"
      view.notice = state == "anim" and "..." or text.plain(state == "released"
        and "gText_PkmnWasReleased" or "gText_ByeByePkmn",
        { dynamic = { [0] = self.adapter.Pokemon.displayMonName(mon) } })
    end
    setmetatable(view, {
      __index = function(_, k) if k == "index" then return state == "confirm" and native.yesNoCursor or 1 end end,
      __newindex = function(t, k, v)
        if k == "index" then if t.valid() and state == "confirm" then native.yesNoCursor = v end
        else rawset(t, k, v) end
      end,
    })
    self.releaseView = view
  end
  return view
end

function UI:list(battle)
  local stats = require("src.ui.game3.stat_growth")
  if stats.isOpen() then
    local mon, page = stats._mon, stats._page
    local key = tostring(mon) .. ":stats:" .. page
    if not self.statsView or self.statsView.nativeKey ~= key then
      self.statsView = { screenId = "Gen3Menu", title = "BATTLE STATS", nativeKey = key,
        nativeStats = stats, items = labels({ "CONTINUE" }), index = 1, update = function() end,
        valid = function() return stats.isOpen() and stats._mon == mon and stats._page == page end }
    end
    return self.statsView
  end
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
    view.prompt = #key <= 5 and self.adapter:messageText() or nil
    view.fixedLayout = view.prompt ~= nil or (Choice.cols or 1) > 1
    if view.fixedLayout then
      local cols = Choice.cols or 1
      local rows = math.ceil(#key / cols)
      if rows > 6 or cols > 4 then return nil end
      local top = view.prompt and (#key <= 2 and 116 or 86) or 34
      local step = math.floor((210 - top) / rows)
      for i, item in ipairs(view.items) do
        local col = (i - 1) % cols
        local left, right = 7 + math.floor(col * 228 / cols), 7 + math.floor((col + 1) * 228 / cols)
        item.rect = { left, top + math.floor((i - 1) / cols) * step, right - left - 2, step - 3 }
      end
    end
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
  if layer and layer.id == "naming" then return self:naming(layer) end
  if layer and layer.id == "box_storage" then
    local release = self:release(layer)
    if release then return release end
  end
  if not layer or not layer.mod or layer.mod.open ~= true then return nil end
  if layer.id == "summary" and self.adapter.profile.id == "emerald"
      and require("src.ui.game3.rse.summary_menu").page(layer.mod) == 3 then return nil end
  local native, items, field, title, slots = layer.mod
  local quantity, prompt, grid, boxParty
  local mode = native.mode or native.state or native._mode
  local sale = mode == "sell" and native._sell
  local saleState = sale and sale.state
  local RomText = require("src.core.game3.rom_text")
  -- Party/Bag notices and Oak's party tutorial have their own printers.
  local function noticeText()
    if sale and (sale.state == "cant" or sale.state == "done") then return sale.text end
    if native.mode == "oak" and layer.id == "party" then
      return native._oakPages and native._oakPages[native._oakPage]
    end
    if native.mode == "message" and layer.id == "party" then return native._messageText end
    if native.mode == "message" and native.messageText then return native.messageText end
    if layer.id == "pc_menu" and mode == "msg" then return native._status end
    if layer.id == "shop" and mode == "buy_msg" then return native._status end
    if layer.id == "box_storage" and mode == "message" then return native._status end
    if layer.id == "item_pc" then
      if mode == "result" then return native.resultText end
      if mode == "msg" then return native.msgText end
    end
    if layer.id == "move_relearner" and mode == "message" then return native.prompt end
    if layer.id == "bag" and mode == "deposit_done" then return native._depositText end
    if layer.id == "bag" and mode == "toss_done" then
      local row = native.list()[native.cursor]
      return row and RomText.box(self.adapter.profile.id == "emerald"
        and "gText_ThrewAwayVar2Var1s" or "gText_ThrewAwayStrVar2StrVar1s",
        { stringVars = { self.adapter.Items.displayName(row.id), tostring(native.tossQty) } })
    end
  end
  local notice = not native._pokedude and not native._statBoost and noticeText()
  if notice then
    local noticeMode = mode
    local function ready()
      return not native._hpAnim and (mode ~= "oak" or native._oakFx and native._oakFx.phase == "text")
    end
    local key = tostring(layer) .. ":" .. mode .. ":" .. tostring(ready()) .. ":" .. notice
    local view = self.noticeView
    if not view or view.nativeKey ~= key then
      view = { screenId = "Gen3Menu", nativeKey = key, notice = notice, canAdvance = ready(),
        title = ({ party = "PARTY", pc_menu = "PC", box_storage = "PC",
          item_pc = "ITEMS", shop = "BUY", move_relearner = "MOVES" })[layer.id] or "BAG", index = 1,
        items = { { label = "CONTINUE" } }, update = function() end,
        valid = function(preview) return self.Stack.top() == layer and native.open
          and (native.mode or native.state or native._mode) == noticeMode
          and (not sale or native._sell == sale and sale.state == saleState)
          and (preview or ready()) and noticeText() == notice end }
      self.noticeView = view
    end
    return view
  end
  local pocket, partyLayout = false, false
  if sale then
    title = "SELL"
    if sale.state == "qty" then quantity = { label = sale.name, qty = sale.qty }
    elseif sale.state == "confirm" then
      items, field, prompt = labels({ "YES", "NO" }), "yesNo", sale.name .. "\n" .. sale.text
    end
  elseif layer.id == "box_storage" then
    title = "PC"
    -- The release overlay temporarily owns input, even while the box says browse.
    if require("src.ui.game3.release_seq").isActive() then return nil end
    local storage = native._session.storage
    local box = storage.boxes[storage.currentBox]
    if mode == "browse" then
      items, slots, field, grid = {}, {}, "cursorSlot", true
      local function entry(label, value, rect, mon)
        items[#items + 1], slots[#slots + 1] = { label = label, rect = rect, rawMon = mon }, value
      end
      entry("PARTY", -10, { 7, 33, 110, 22 })
      entry("CLOSE", -20, { 123, 33, 110, 22 })
      entry(box.name, 0, { 7, 59, 226, 22 })
      for slot = 1, 30 do
        local picked = native.holdingSource and native.holdingSource.loc == "box"
          and native.holdingSource.boxId == storage.currentBox and native.holdingSource.slot == slot
        entry("", slot, { 7 + (slot - 1) % 6 * 38, 85 + math.floor((slot - 1) / 6) * 24, 36, 22 },
          not picked and box.mons[slot] or nil)
      end
      local selected = native.holdingMon or box.mons[native.cursorSlot]
      title = selected and self.adapter.Pokemon.displayMonName(selected) or box.name
    elseif mode == "party_drawer" then
      items, slots, field, grid, boxParty = {}, {}, "partyCursor", true, true
      -- Empty party slots are real destinations while holding a boxed Pokémon.
      for slot = 1, 6 do
        local mon = self.adapter:mon(native._session.party[slot])
        items[#items + 1], slots[#slots + 1] = { label = mon and (mon.nickname
          or self.adapter.Pokemon.displayMonName(native._session.party[slot])) or "-",
          rawMon = native._session.party[slot],
          rect = slot == 1 and { 7, 34, 72, 151 } or { 85, 34 + (slot - 2) * 31, 148, 27 } }, slot
      end
      items[7], slots[7] = { label = "CANCEL", rect = { 7, 191, 226, 22 } }, 7
    elseif mode == "action_menu" then items, field = labels(native._activeActions), "actionCursor"
    elseif mode == "box_menu" then items, field = labels({ "SWITCH BOX", "WALLPAPER", "CANCEL" }), "boxMenuCursor"
    elseif mode == "pick_box" then
      items, field = {}, "cursorSlot"
      for _, b in ipairs(storage.boxes) do items[#items + 1] = { label = b.name } end
    elseif mode == "pick_wallpaper" then
      items, field = {}, "wallpaperCursor"
      for i = 1, 16 do items[i] = { label = RomText.at("sMenuTexts", 21 + i) } end
    end
  elseif layer.id == "shop" then
    title = "BUY"
    if mode == "root" then
      items, field = {}, "cursor"
      for i in ipairs(native.ROOT) do items[i] = { label = RomText.at("sShopMenuActions_BuySellQuit", i - 1) } end
    elseif mode == "buy" then
      items, field = {}, "cursor"
      for _, id in ipairs(native._items) do
        items[#items + 1] = { label = self.adapter.Items.displayName(id), right = "¥" .. self.adapter.Items.info(id).price }
      end
      items[#items + 1] = { label = "CANCEL" }
    elseif mode == "buy_qty" then quantity = { label = native._pending.name, qty = native.qty }
    elseif mode == "buy_confirm" then items, field, prompt = labels({ "YES", "NO" }), "yesNoCursor", native._status end
  elseif layer.id == "pc_menu" then
    title, field = "PC", "cursor"
    if mode == "root" then items = labels(native._rootEntries())
    elseif mode == "storage_menu" then items = labels(native._storageOptions())
    elseif self.adapter.profile.id == "emerald" and (mode == "player_pc" or mode == "item_storage") then
      local rows = mode == "player_pc" and require("src.ui.game3.rse.player_pc").topOrder(native)
        or { "withdraw", "deposit", "toss", "exit" }
      local keys = { item_storage = "gText_ItemStorage", mailbox = "gText_Mailbox",
        decoration = "gText_Decoration", turn_off = "gText_TurnOff",
        withdraw = "gText_WithdrawItem", deposit = "gText_DepositItem",
        toss = "gText_TossItem", exit = "gText_Cancel" }
      items = {}
      for _, id in ipairs(rows) do items[#items + 1] = { label = RomText.plain(keys[id]) } end
    elseif mode == "player_pc" then items = labels(native.TOP_ACTIONS)
    elseif mode == "item_storage" then items = labels(native.ITEM_STORAGE_ACTIONS) end
  elseif layer.id == "item_pc" then
    title = "ITEMS"
    if mode == "list" or mode == "move" then
      items, field = {}, "row"
      for _, row in ipairs(native._session.storage.items) do
        items[#items + 1] = { label = self.adapter.Items.displayName(row.id), right = "x" .. row.qty }
      end
      items[#items + 1] = { label = "CANCEL" }
    elseif mode == "submenu" then
      items, field = labels({ RomText.plain("gText_Withdraw"), RomText.plain("gOtherText_Give"),
        RomText.plain("gFameCheckerText_Cancel") }), "subCursor"
    elseif mode == "qty" then
      local row = native._session.storage.items[native.scroll + native.row + 1]
      quantity = row and { label = self.adapter.Items.displayName(row.id), qty = native.qty }
    end
  elseif layer.id == "move_relearner" then
    title = "MOVES"
    if mode == "list" then
      items, field = {}, "cursor"
      for _, id in ipairs(native.moves()) do items[#items + 1] = { label = self.adapter.Pokemon.moveName(id) } end
      items[#items + 1] = { label = "CANCEL" }
    elseif mode == "yesno" then
      items, field, prompt = labels({ "YES", "NO" }), "yesNoCursor", native.prompt
    end
  elseif layer.id == "summary" and native._mode == "select_move" then
    title, items, slots, field = "FORGET MOVE", {}, {}, "_moveCursor"
    local mon = native._party and native._party[native._cursor]
    for slot = 1, 4 do
      local id = mon and mon.moves and mon.moves[slot]
      if id and id ~= 0 then
        items[#items + 1], slots[#slots + 1] = { label = self.adapter.Pokemon.moveName(id) }, slot
      end
    end
    items[#items + 1], slots[#slots + 1] = { label = "CANCEL", right = native._moveToLearn
      and self.adapter.Pokemon.moveName(native._moveToLearn) or nil }, 5
    if native._hmNotice then prompt = RomText.plain("gText_PokeSum_HmMovesCantBeForgotten") end
  elseif (layer.id == "bag" or layer.id == "berry_pouch") and
      (mode == "toss" or mode == "toss_select" or mode == "deposit" or mode == "toss_confirm") then
    title = mode == "deposit" and "DEPOSIT" or "TOSS"
    local row = native.list()[native.cursor]
    if mode == "toss_confirm" then
      items, field = labels({ "YES", "NO" }), "yesNoCursor"
      prompt = row and self.adapter.Items.displayName(row.id) .. "\n" ..
        RomText.box(self.adapter.profile.id == "emerald" and "gText_ConfirmTossItems"
          or "gText_ThrowAwayStrVar2OfThisItemQM", {
          stringVars = { self.adapter.Items.displayName(row.id), tostring(native.tossQty) } })
    else quantity = row and { label = self.adapter.Items.displayName(row.id), qty = native.tossQty } end
  elseif layer.id == "start" then
    title = "CHOOSE ACTION"
    if native._confirmExit then
      items, field, prompt = labels({ "YES", "NO" }), "_confirmCursor", require("src.core.Strings")("RETURN TO MAIN\nMENU?")
    else items, field = labels(native.ENTRIES), "cursor" end
  elseif layer.id == "party" and not native._pokedude then
    title = "PARTY"
    if partyModes[native.mode] then
      partyLayout = native.mode ~= "choose_multi"
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
      title = ({ ITEMS = "ITEMS", KEY_ITEMS = "KEY ITEMS", POKE_BALLS = "BALLS",
        TM_CASE = "TM/HM", BERRY_POUCH = "BERRIES" })[id] or "BAG"
      for _, item in ipairs(native.list()) do
        items[#items + 1] = { label = item.name or self.adapter.Items.displayName(item.id),
          right = "x" .. tostring(item.qty or 0), itemId = item.id }
      end
      items[#items + 1] = { label = "CANCEL" }
    elseif native.mode == "action" then
      items, field = labels(native.ACTIONS), "actionCursor"
    end
  end
  if layer.id == "bag" and native.mode == "action" and self.adapter.profile.id == "emerald" then
    local st = require("src.ui.game3.rse.bag_menu")._st
    if not st.grid then return nil end
    grid = true
    for i, cell in ipairs(st.grid.cells) do
      if cell then
        local col, row = (i - 1) % st.grid.cols, math.floor((i - 1) / st.grid.cols)
        local width = math.floor(228 / st.grid.cols)
        items[cell.idx].rect = { 7 + col * width, 86 + row * 40, width - 2, 37 }
      end
    end
  end
  if quantity then items, field = { { label = "CONFIRM" } }, nil end
  if not items or #items == 0 or not quantity and type((sale or native)[field]) ~= "number" then return nil end
  local key = tostring(layer) .. ":" .. tostring(mode) .. ":" .. tostring(native.pocketIdx)
    .. ":" .. tostring(native.holdingMon)
    .. ":" .. tostring(saleState)
    .. ":" .. tostring(native._hmNotice) .. ":" .. tostring(native._confirmExit)
    .. ":" .. tostring(layer.id == "box_storage" and native._session.storage.currentBox)
  local view = self.view
  if not view or view.nativeKey ~= key then
    local owner = self
    view = { screenId = "Gen3Menu", nativeKey = key, update = function() end }
    local pocketIdx = native.pocketIdx
    local holding = native.holdingMon
    local hmNotice, confirmExit = native._hmNotice, native._confirmExit
    function view.valid(preview)
      return owner.Stack.top() == layer and native.open == true
        and (native.mode or native.state or native._mode) == mode and native.pocketIdx == pocketIdx
        and native.holdingMon == holding
        and native._hmNotice == hmNotice and native._confirmExit == confirmExit
        and (not sale or native._sell == sale and sale.state == saleState)
        and (layer.id ~= "box_storage" or not require("src.ui.game3.release_seq").isActive())
        and (preview or not native._hpAnim) and not native._pokedude and not native._statBoost
        and (preview or not native._fx and not (native._slide and native._slide.active))
        and (preview or not native._fading)
        and (preview or not native._switch and not native._exit and not native._open)
    end
    setmetatable(view, {
      __index = function(t, k)
        if k ~= "index" then return nil end
        if quantity then return 1 end
        if sale then return sale[field] end
        if layer.id == "box_storage" and mode == "pick_box" then return native._session.storage.currentBox end
        if layer.id == "item_pc" and field == "row" then return native.scroll + native.row + 1 end
        local value = native[field]
        if not t.nativeSlots then return value end
        for i, slot in ipairs(t.nativeSlots) do if slot == value then return i end end
      end,
      __newindex = function(t, k, v)
        if k == "index" then
          if t.valid() and field then
            if sale then sale[field] = v
            elseif layer.id == "box_storage" and mode == "pick_box" then native._session.storage.currentBox = v
            elseif layer.id == "item_pc" and field == "row" then
              native.scroll = math.max(0, math.min(v - 1, #t.items - 6))
              native.row = v - 1 - native.scroll
            else
              native[field] = t.nativeSlots and t.nativeSlots[v] or v
              if layer.id == "bag" and mode == "action" and owner.adapter.profile.id == "emerald" then
                local st = require("src.ui.game3.rse.bag_menu")._st
                for i, cell in ipairs(st.grid and st.grid.cells or {}) do
                  if cell and cell.idx == native[field] then st.gridPos = i - 1; break end
                end
              end
            end
          end
        else rawset(t, k, v) end
      end,
    })
    self.view = view
  end
  view.items, view.nativeSlots, view.title, view.nativePocket = items, slots, title, pocket
  view.quantity = quantity
  view.prompt = prompt
  view.nativeGrid, view.boxParty = grid, boxParty
  view.partyActions = layer.id == "party" and (native.mode == "action" or native.mode == "item_action")
    and #items <= 3 and self.adapter:mon(native._party and native._party[native.cursor]) or nil
  view.fixedLayout, view.party = grid or prompt ~= nil or partyLayout or view.partyActions ~= nil, partyLayout and native or nil
  -- Every projection (including upper-screen ownership checks) retains the
  -- exact same draw/hit geometry; never leave a cached view with fresh bare rows.
  if prompt then
    local start, step, height = 116, 47, 44
    if #items > 2 then start, step, height = 86, 24, 22 end
    for slot, item in ipairs(items) do item.rect = { 7, start + (slot - 1) * step, 226, height } end
  elseif partyLayout then
    for slot, item in ipairs(items) do
      item.rect = { self.layout:battleStandardPartyRect(slot, #items - 1, true) }
    end
  elseif view.partyActions then
    for slot, item in ipairs(items) do
      item.rect = { self.layout:partyActionRow(slot, #items) }
    end
  end
  return view
end

function UI:openBagItem(id)
  local a, session = self.adapter, self.adapter.session
  if not session or not a.save or (a.save.inventory[id] or 0) <= 0
      or self.Stack.top() or self.Message.isOpen() or self.Choice.active then return false end
  local def = a.data.items[id]
  local pocket = def and def.nativePocket
  local menu
  if pocket == "TM_CASE" and a.profile.id ~= "emerald" then
    menu = require("src.ui.game3.tm_case")
    menu.show(session, session.bag)
  elseif pocket == "BERRY_POUCH" and a.profile.id ~= "emerald" then
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
