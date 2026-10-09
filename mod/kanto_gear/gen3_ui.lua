-- Native Gen 3 menu projections. All activation is routed through the host's
-- normal input handler; Gear never invokes item/switch callbacks itself.
local bit = require("bit")
local UI = {}
UI.__index = UI

function UI.new(adapter, layout, choicePage, namingPage, storagePage, itemPage, movePage)
  return setmetatable({ adapter = adapter, layout = layout, choicePage = choicePage, namingPage = namingPage, storagePage = storagePage, itemPage = itemPage, movePage = movePage, Stack = require("src.ui.game3.stack"),
    Message = require("src.ui.game3.message"), Choice = require("src.ui.game3.choice") }, UI)
end

function UI:moveItem(raw, slot, name)
  local id = self.adapter.Pokemon.moveIdAt(raw, slot)
  if not id or id <= 0 then return nil end
  local mon = self.adapter:mon(raw)
  local move = mon.moves[slot]
  if not move then return nil end
  local base = self.adapter.Pokemon.movePp(id)
  local bonus = type(raw.ppBonusesPacked) == "number" and bit.band(bit.rshift(raw.ppBonusesPacked, (slot - 1) * 2), 3)
  local maxPp = bonus and base + math.floor(base * bonus / 5) or move.maxPp or base
  return { label = name or self.adapter.Pokemon.moveName(id),
    move = { id = move.id, index = id, pp = move.pp, maxPp = maxPp, ppUps = bonus or move.ppUps },
    right = tostring(move.pp or 0) .. "/" .. maxPp }
end

function UI:learningPrompt()
  local learn = require("src.core.game3.battle.learn_move")
  if learn and learn.busy() and learn.waitingChoice() and learn._mon and learn._moveId then
    local mon, move = learn._mon, learn._moveId
    return { mon = self.adapter:mon(mon), rawMon = mon,
      newMoveId = self.adapter.Moves.constName(move),
      valid = function() return learn.busy() and learn.waitingChoice()
        and learn._mon == mon and learn._moveId == move end }
  end
end

function UI:panel()
  local layer = self.Stack.top()
  return layer and layer.id
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

local function nativeMode(layer)
  local native = layer.mod
  -- Emerald retains mode=buy throughout list, quantity, confirmation and receipt.
  if layer.id == "shop" and native._rse then return native.state end
  if layer.id == "save" then return native._phase end
  return native.mode or native.state or native._mode
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
    local pageIndex, pcPages, pcPage = state.page, state.pcPages, state.pcPage
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
        view.items[#view.items + 1] = { label = char == " " and "_" or char, row = row, col = col }
      end
    end
    for i, label in ipairs({ ({ "abc", "123", "ABC" })[state.page], "DEL", "OK" }) do
      view.items[#view.items + 1] = { label = label, btn = i, action = ({ "case", "delete", "confirm" })[i] }
    end
    view.namingModel = self.namingPage.model("", view.items)
    for _, entry in ipairs(view.namingModel.entries) do
      view.items[entry.index].rect = { entry.x, entry.y, entry.w, entry.h }
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
  view.namingModel.name = view.name
  self.namingPage.availability(view.namingModel, #state.name, state.maxLen)
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
      view.choiceState = { page = 1 }
      local model = self.choicePage.model(view.choiceState, { "YES", "NO" })
      for _, entry in ipairs(model.entries) do
        view.items[entry.index].rect = { entry.x, entry.y, entry.w, entry.h }
      end
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

function UI:pokeblockIcon(color)
  self.blockIcons = self.blockIcons or {}
  if self.blockIcons[color] == nil then
    local ok, image = pcall(function()
      local gfx = require("src.ui.game3.rse.pokeblock_gfx").of("rse/pokeblock")
      local palettes = gfx:manifest().colors
      return gfx:sprite("pokeblock", 0, 8, 8, palettes[color] or palettes[1])
    end)
    self.blockIcons[color] = ok and { image = image, width = 8, height = 8 } or false
  end
  return self.blockIcons[color] or nil
end

function UI:pokeblocks(layer)
  local native = layer.mod
  local state = native._st
  local Blocks = require("src.core.game3.rse.pokeblock")
  if not native.open or not state then return nil end
  local phase, opts, itemId, map = state.phase, state.opts, state.itemId, state.map
  local printer, yesNo, swap = state.printer, state.yesNo, state.toSwap
  local notice = phase == "toss" or phase == "tossed"
  if phase ~= "list" and phase ~= "swap" and phase ~= "actions" and phase ~= "toss_yesno" and not notice then return nil end
  local function ready()
    if state.fadeDir ~= 0 or self.Message.isOpen() or self.Choice.active then return false end
    if not notice then return true end
    if not printer or not printer:isActive() then return phase == "tossed" end
    return printer.state == "wait" or printer.state == "clear" or printer.state == "scroll_start"
      or printer.state == "char" and printer.canSpeedUp and not printer.spedUp
  end
  local actions = opts.actions and (opts.actions[state.caseId] or opts.actions[Blocks.CASE.FIELD])
    or native.ACTIONS[state.caseId] or native.ACTIONS[Blocks.CASE.FIELD]
  local items, blocks = {}, {}
  local Constants = require("src.core.game3.constants")
  local caseItem = Constants.of(Constants.versionOf(state.session)):require("items", "ITEM_POKEBLOCK_CASE")
  for id = 0, Blocks.count(state.session) - 1 do
    local block = Blocks.get(state.session, id)
    blocks[#blocks + 1] = block
    items[#items + 1] = { label = self.adapter:plainText(Blocks.name(block)),
      itemSprite = self:pokeblockIcon(Blocks.data(block, 0)), right = self.adapter:plainText(
      require("src.core.game3.rom_text").plain("gText_LvVar1", {
        stringVars = { tostring(Blocks.highestFlavorLevel(block)) } })) }
  end
  items[#items + 1] = { label = self.adapter:plainText(require("src.core.game3.rom_text").plain("gText_StowCase")) }
  local key = tostring(opts) .. ":" .. tostring(map) .. ":" .. phase .. ":" .. tostring(itemId)
    .. ":" .. tostring(printer) .. ":" .. tostring(yesNo) .. ":" .. tostring(swap)
  for _, block in ipairs(blocks) do key = key .. ":" .. tostring(block) end
  local view = self.pokeblockView
  if not view or view.nativeKey ~= key then
    view = { screenId = "Gen3Menu", nativeKey = key, update = function() end,
      title = self.adapter:plainText(self.adapter.Items.displayName(caseItem)),
      valid = function(preview)
        if self.Stack.top() ~= layer or not native.open or native._st ~= state
            or state.opts ~= opts or state.map ~= map or state.phase ~= phase or state.itemId ~= itemId
            or state.printer ~= printer or state.yesNo ~= yesNo or state.toSwap ~= swap
            or (not preview and not ready()) or Blocks.count(state.session) ~= #blocks then return false end
        for index, block in ipairs(blocks) do
          if Blocks.get(state.session, index - 1) ~= block then return false end
        end
        return true
      end }
    setmetatable(view, {
      __index = function(_, k)
        if k == "index" then
          if notice then return 1 end
          if yesNo then return yesNo.cursor + 1 end
          return phase == "actions" and state.actionCursor + 1 or native.saved.scroll + native.saved.row + 1
        end
      end,
      __newindex = function(t, k, value)
        if k ~= "index" then rawset(t, k, value); return end
        if not t.valid() then return end
        if yesNo then yesNo.cursor = value - 1; return end
        if notice then return end
        if phase == "actions" then state.actionCursor = value - 1; return end
        -- Let the native cursor update its scroll, highlight and flavor display.
        for _ = 1, #items do
          local current = native.saved.scroll + native.saved.row + 1
          if current == value then break end
          local direction = current < value and "down" or "up"
          native.handleInput({ wasPressed = function(_, key) return key == direction end,
            isDown = function() return false end })
          native.update()
        end
      end,
    })
    self.pokeblockView = view
  end
  if notice then
    view.items, view.notice, view.canAdvance = labels({ "CONTINUE" }),
      self.adapter:plainText(table.concat(printer and printer.lines or {}, "\n")), ready()
  elseif phase == "actions" or yesNo then
    view.items = {}
    if yesNo then view.items = labels({ "YES", "NO" })
    else
      for _, action in ipairs(actions) do
        view.items[#view.items + 1] = { label = self.adapter:plainText(require("src.core.game3.rom_text").plain(action.text)) }
      end
    end
    view.prompt = self.adapter:plainText(yesNo and table.concat(printer.lines, "\n")
      or Blocks.name(Blocks.get(state.session, itemId)))
    view.choiceState = view.choiceState or { page = 1 }
    local model = self.choicePage.model(view.choiceState, view.items, nil, view.index)
    view.fixedLayout, view.touchWindow = true, { first = model.first, count = #model.entries }
    for _, entry in ipairs(model.entries) do view.items[entry.index].rect = { entry.x, entry.y, entry.w, entry.h } end
  else view.items = items end
  return view
end

function UI:pumpPokeblockSelection()
  local selection = self.pokeblockSelection
  if not selection then return end
  local native, state = selection.layer.mod, selection.state
  if self.Stack.top() ~= selection.layer or not native.open or native._st ~= state
      or state.opts ~= selection.opts or self.Message.isOpen() or self.Choice.active
      or state.sel ~= selection.expected or state.party ~= selection.party
      or state.session.party[state.party[selection.target + 1]] ~= selection.mon
      or state.fadeDir ~= 0 or state.state ~= "input" and state.state ~= "loading" then
    self.pokeblockSelection = nil
    return
  end
  if state.state == "loading" then return end
  if state.sel == selection.target then
    self.pokeblockSelection = nil
    if selection.confirm then selection.confirm() end
    return
  end
  local down = (selection.target - state.sel) % state.numSelections
  local key = down <= state.numSelections - down and "down" or "up"
  native.handleInput({ wasPressed = function(_, k) return k == key end,
    isDown = function(_, k) return k == key end })
  native.update()
  selection.expected = state.sel
end

function UI:usePokeblock(layer)
  local native, state = layer.mod, layer.mod._st
  if not native.open or not state or not state.party then return nil end
  local mode, opts, party, selected, yesNo = state.state, state.opts, state.party, state.sel, state.yesNo
  local textIndex = state.textIdx
  local ready = mode == "input" or mode == "confirm" or mode == "wont_eat"
    or mode == "results_wait" or mode == "results_text"
  local key = tostring(opts) .. ":" .. tostring(party) .. ":" .. mode .. ":" .. selected
    .. ":" .. tostring(yesNo) .. ":" .. tostring(textIndex)
  local view = self.feedView
  if not view or view.nativeKey ~= key then
    view = { screenId = "Gen3Menu", nativeKey = key, update = function() end, title = "USE ITEM ON",
      valid = function(preview)
        return self.Stack.top() == layer and native.open and native._st == state
          and state.opts == opts and state.party == party and state.state == mode
          and state.sel == selected and state.yesNo == yesNo and state.textIdx == textIndex
          and (preview or ready and state.fadeDir == 0 and not self.pokeblockSelection
            and not self.Message.isOpen() and not self.Choice.active)
      end }
    setmetatable(view, {
      __index = function(_, k)
        if k == "index" then return yesNo and yesNo.cursor + 1 or mode == "input" and state.sel + 1 or 1 end
      end,
      __newindex = function(t, k, value)
        if k ~= "index" then rawset(t, k, value); return end
        if not t.valid() then return end
        if yesNo then yesNo.cursor = value - 1
        elseif mode == "input" then
          self.pokeblockSelection = { layer = layer, state = state, opts = opts, party = party,
            target = value - 1, expected = selected, mon = state.session.party[party[value]], view = t }
        end
      end,
    })
    if mode == "input" then
      view.confirmSelection = function(confirm)
        local pending = self.pokeblockSelection
        if pending and pending.view == view then pending.confirm = confirm; self:pumpPokeblockSelection() end
      end
    end
    self.feedView = view
  end
  view.partyMons = {}
  for _, slot in ipairs(party) do view.partyMons[#view.partyMons + 1] = self.adapter:mon(state.session.party[slot]) end
  if mode == "confirm" then
    view.items, view.prompt, view.choiceState = labels({ "YES", "NO" }), self.adapter:plainText(state.message), { page = 1 }
    view.fixedLayout = true
    local model = self.choicePage.model(view.choiceState, view.items, nil, view.index)
    for _, entry in ipairs(model.entries) do view.items[entry.index].rect = { entry.x, entry.y, entry.w, entry.h } end
  elseif mode == "input" then
    view.items, view.party, view.fixedLayout = {}, native, true
    for slot, mon in ipairs(view.partyMons) do
      view.items[slot] = { label = mon.nickname or "POKEMON", mon = mon,
        rect = { self.layout:partySelectionRect(slot, #party, true) } }
    end
    view.items[#party + 1] = { label = "CANCEL", rect = { self.layout:partySelectionRect(#party + 1, #party, true) } }
  else
    view.items, view.party, view.notice, view.canAdvance = labels({ "CONTINUE" }), native,
      self.adapter:plainText(state.message or "..."), ready and state.fadeDir == 0
  end
  return view
end

function UI:list(battle)
  self:pumpPokeblockSelection()
  local stats = require("src.ui.game3.stat_growth")
  if stats.isOpen() then
    local mon, page, oldStats, newStats, callback = stats._mon, stats._page, stats._oldStats, stats._newStats, stats._onDone
    local key = tostring(mon) .. ":stats:" .. page .. ":" .. tostring(oldStats) .. ":" .. tostring(newStats) .. ":" .. tostring(callback)
    if not self.statsView or self.statsView.nativeKey ~= key then
      local normalized = self.adapter:mon(mon)
      self.statsView = { screenId = "Gen3Menu", title = "LEVEL UP", nativeKey = key,
        nativeStats = stats, items = labels({ "CONTINUE" }), index = 1, update = function() end,
        levelStats = { mon = { species = normalized.species, level = normalized.level, types = normalized.types,
          name = self.adapter.Pokemon.displayMonName(mon) }, source = mon,
          stats = { splitSpecial = true }, gain = { deltas = {} } },
        valid = function() return stats.isOpen() and stats._mon == mon and stats._page == page
          and stats._oldStats == oldStats and stats._newStats == newStats and stats._onDone == callback end }
    end
    local result = self.statsView.levelStats
    local fields = { hp = "maxHp", attack = "atk", defense = "def", speed = "spe", specialAttack = "spa", specialDefense = "spd" }
    for field, native in pairs(fields) do
      local value, old = newStats and newStats[native], oldStats and oldStats[native]
      result.stats[field] = value
      result.gain.deltas[field] = type(value) == "number" and type(old) == "number" and value - old or nil
    end
    return self.statsView
  end
  local Message, Choice = self.Message, self.Choice
  if Choice.active and Choice.options then
    local key = Choice.options
    local learning = Choice.kind == "yesno" and self:learningPrompt() or nil
    local owner, move = learning and learning.rawMon, learning and learning.newMoveId
    local view = self.choiceView
    if not view or view.options ~= key or view.learningOwner ~= owner or view.learningMove ~= move then
      view = { screenId = "Gen3Menu", title = "CHOOSE ACTION", options = key,
        learningOwner = owner, learningMove = move,
        nativeKey = tostring(key), choiceState = { page = 1 }, update = function() end,
        valid = function() return Choice.active and Choice.options == key
          and (not learning or learning.valid()) end }
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
    view.prompt = self.adapter:messageText()
    local model = self.choicePage.model(view.choiceState, key, nil, Choice.cursor)
    view.learningPrompt = learning
    view.title = view.learningPrompt and "NEW MOVE" or "CHOOSE ACTION"
    view.fixedLayout, view.touchWindow = true, { first = model.first, count = #model.entries }
    if view.learningPrompt then self.movePage.promptLayout(view.items)
    else
      for _, entry in ipairs(model.entries) do
        view.items[entry.index].rect = { entry.x, entry.y, entry.w, entry.h }
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
            targetSide = mon.side, value = "pokemon",
            right = (mon.side == "player" and "YOUR SIDE" or "FOE") }, id
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
  if layer and layer.id == "rse_pokeblock_case" then return self:pokeblocks(layer) end
  if layer and layer.id == "rse_use_pokeblock" then return self:usePokeblock(layer) end
  if layer and layer.id == "box_storage" then
    local release = self:release(layer)
    if release then return release end
  end
  if not layer or not layer.mod or layer.mod.open ~= true then return nil end
  -- The contest summary has its own view, but move replacement still needs its touch list.
  if layer.id == "summary" and layer.mod._mode ~= "select_move" and self.adapter.profile.id == "emerald"
      and require("src.ui.game3.rse.summary_menu").page(layer.mod) == 3 then return nil end
  local native, items, field, title, slots = layer.mod
  local quantity, prompt, grid, boxParty, moveSelection
  local relearnMoves, relearnKey, relearnMon, relearnFirst
  local mode = nativeMode(layer)
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
    if layer.id == "pc_menu" and (mode == "msg" or mode == "rse_msg") then return native._status end
    if layer.id == "rse_item_storage" and (mode == "remove" or mode == "error") then return native._message end
    if layer.id == "shop" and (mode == "buy_msg" or mode == "msg") then return native._status end
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
          item_pc = "ITEMS", rse_item_storage = "ITEMS", shop = "BUY", move_relearner = "MOVES" })[layer.id] or "BAG", index = 1,
        items = { { label = "CONTINUE" } }, update = function() end,
        valid = function(preview) return self.Stack.top() == layer and native.open
          and nativeMode(layer) == noticeMode
          and (not sale or native._sell == sale and sale.state == saleState)
          and (preview or ready()) and noticeText() == notice end }
      self.noticeView = view
    end
    return view
  end
  local pocket, partyLayout = false, false
  if sale then
    title = "SELL"
    if sale.state == "qty" then quantity = { label = sale.name, qty = sale.qty,
        itemId = sale.itemId, max = sale.owned, wrap = true, total = sale:total() }
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
      field, grid = "cursorSlot", true
      local function monAt(slot)
        local picked = native.holdingSource and native.holdingSource.loc == "box"
          and native.holdingSource.boxId == storage.currentBox and native.holdingSource.slot == slot
        return not picked and box.mons[slot] or nil
      end
      items, slots = self.storagePage.box({ capacity = 30, name = box.name,
        primary = { label = "PARTY", value = -10 }, cancel = { label = "CLOSE", value = -20 },
        monAt = monAt, enabled = function(slot) return native.holdingMon ~= nil or monAt(slot) ~= nil end })
      local selected = native.holdingMon or box.mons[native.cursorSlot]
      title = selected and self.adapter.Pokemon.displayMonName(selected) or box.name
    elseif mode == "party_drawer" then
      field, grid, boxParty = "partyCursor", true, true
      -- The common team page keeps native slot identity, including empty targets.
      local function monAt(slot)
        local source = native._session.party[slot]
        local picked = source and source == native.holdingMon and native.holdingSource
          and native.holdingSource.loc == "party" and native.holdingSource.slot == slot
        return not picked and source or nil
      end
      items, slots = self.storagePage.party(self.layout, { monAt = monAt,
        monView = function(mon) return self.adapter:mon(mon) end,
        enabled = function(slot) return monAt(slot) ~= nil or native.holdingMon ~= nil end })
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
    local rse = native._rse
    local decoration = rse and native._martType ~= rse.MART_NORMAL
    if mode == "root" then
      items, field = {}, "cursor"
      if rse then
        local keys = decoration and { "gText_ShopBuy", "gText_ShopQuit" }
          or { "gText_ShopBuy", "gText_ShopSell", "gText_ShopQuit" }
        for i, key in ipairs(keys) do items[i] = { label = RomText.plain(key) } end
      else
        for i in ipairs(native.ROOT) do items[i] = { label = RomText.at("sShopMenuActions_BuySellQuit", i - 1) } end
      end
    elseif mode == "buy" or rse and mode == "list" then
      items, field = {}, rse and "row" or "cursor"
      local discounted = false
      if rse and not decoration then
        local Tv, Rse = require("src.core.game3.rse.tv"), require("src.core.game3.rse.init")
        -- The native mart applies Slateport's TV sale only when its hook permits it.
        discounted = Tv.isPokeNewsActive(native._session, 1, function(kind)
          return Rse.call("tv", "shouldApplyPokeNews", "ShouldApplyPokeNewsEffect", nil, kind) == true
        end)
      end
      for _, id in ipairs(native._items) do
        if decoration then
          local info = require("src.core.game3.rse.decoration_inventory").info(id)
          items[#items + 1] = { label = info and info.name or tostring(id), right = "¥" .. (info and info.price or 0) }
        else
          local price = math.max(0, math.floor(tonumber(self.adapter.Items.info(id).price) or 0))
          items[#items + 1] = { label = self.adapter.Items.displayName(id),
            right = "¥" .. (discounted and math.floor(price / 2) or price), itemId = id }
        end
      end
      items[#items + 1] = { label = "CANCEL" }
    elseif rse and mode == "qty" then
      quantity = { label = self.adapter.Items.displayName(native._itemId), qty = native.qty,
        itemId = native._itemId, max = math.max(1, native._maxQty or 1), wrap = true, total = native._totalCost }
    elseif rse and mode == "confirm" then
      items, field, prompt = labels({ "YES", "NO" }), "yesCursor", native._status
    elseif mode == "buy_qty" then
      local pending = native._pending
      quantity = { label = pending.name, qty = native.qty, itemId = pending.id,
        total = (pending.price or 0) * native.qty,
        max = math.max(1, math.min(99, math.floor((tonumber(native._session.money) or 0)
          / math.max(1, pending.price or 0)))) }
    elseif mode == "buy_confirm" then items, field, prompt = labels({ "YES", "NO" }), "yesNoCursor", native._status end
  elseif layer.id == "save" and (mode == "confirm" or mode == "overwrite") then
    title, items, field = "SAVE", labels({ "YES", "NO" }), "cursor"
    local key = native._rse and (mode == "confirm" and "gText_ConfirmSave" or "gText_AlreadySavedFile")
      or (mode == "confirm" and "gText_WouldYouLikeToSaveTheGame" or "gText_AlreadySaveFile_WouldLikeToOverwrite")
    local pyramid = native._rse and mode == "confirm" and require("src.core.game3.rse.init").system("pyramid")
    prompt = pyramid and pyramid.inPyramid(native._session)
      and require("src.core.game3.scripting.text_ir").toPlain(pyramid.manifest().confirmRest.ir)
      or RomText.plain(key)
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
  elseif layer.id == "item_pc" or layer.id == "rse_item_storage" then
    local rse = layer.id == "rse_item_storage"
    title = (mode == "swap" or mode == "move") and "MOVE"
      or rse and (native._toss and "TOSS" or "WITHDRAW") or "ITEMS"
    local rows = native._session.storage.items
    if mode == "list" or mode == "move" or mode == "swap" then
      items, field = {}, "row"
      for _, row in ipairs(rows) do
        items[#items + 1] = { label = self.adapter.Items.displayName(row.id),
          right = "x" .. row.qty, itemId = row.id }
      end
      items[#items + 1] = { label = "CANCEL" }
    elseif mode == "qty" or mode == "quantity" then
      local row = rows[native.scroll + native.row + 1]
      quantity = row and { label = self.adapter.Items.displayName(row.id), qty = rse and native.quantity or native.qty,
        itemId = row.id, max = row.qty, wrap = true }
    elseif mode == "yesno" then
      items, field, prompt = labels({ "YES", "NO" }), "yesCursor", native._message
    elseif mode == "submenu" then
      items, field = labels({ RomText.plain("gText_Withdraw"), RomText.plain("gOtherText_Give"),
        RomText.plain("gFameCheckerText_Cancel") }), "subCursor"
    end
  elseif layer.id == "move_relearner" then
    title = "MOVES"
    if mode == "list" then
      items, field = {}, "cursor"
      relearnMoves, relearnMon = native.moves(), native._mon
      relearnKey = table.concat(relearnMoves, "\31")
      relearnFirst = self.movePage.window(#relearnMoves, native.cursor)
      for _, id in ipairs(relearnMoves) do
        local pp = self.adapter.Pokemon.movePp(id)
        items[#items + 1] = { label = self.adapter.Pokemon.moveName(id),
          move = { id = self.adapter.Moves.constName(id), pp = pp, maxPp = pp }, right = pp .. "/" .. pp }
      end
      items[#items + 1] = { label = "CANCEL" }
      moveSelection = { mon = self.adapter:mon(relearnMon), items = items, catalogue = true, cursor = native.cursor }
    elseif mode == "yesno" then
      items, field, prompt = labels({ "YES", "NO" }), "yesNoCursor", native.prompt
    end
  elseif layer.id == "summary" and native._mode == "select_move" then
    title, items, slots, field = "FORGET MOVE", {}, {}, "_moveCursor"
    local raw = native._party and native._party[native._cursor]
    local mon = raw and self.adapter:mon(raw)
    for slot = 1, 4 do
      local row = raw and self:moveItem(raw, slot)
      if row then items[#items + 1], slots[#slots + 1] = row, slot end
    end
    items[#items + 1], slots[#slots + 1] = { label = "CANCEL" }, 5
    moveSelection = { mon = mon, items = items, slots = slots,
      newMoveId = native._moveToLearn and self.adapter.Moves.constName(native._moveToLearn), learning = true }
    if native._hmNotice then
      prompt = RomText.plain(require("src.core.game3.battle.profile").get(self.adapter.session).strings.hmCantForget)
    end
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
    else quantity = row and { label = self.adapter.Items.displayName(row.id), qty = native.tossQty,
      itemId = row.id, max = mode == "deposit" and math.min(999, row.qty or 1) or row.qty,
      wrap = mode == "deposit" or layer.id == "berry_pouch" } end
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
    elseif native.mode == "yesno" then
      items, field, prompt = labels({ "YES", "NO" }), "_yesNoCursor", native._yesNoPrompt
    elseif native.mode == "forget" and type(native._forgetMoves) == "table" then
      title, items, field = "CHOOSE MOVE", {}, "_forgetCursor"
      local raw = native._party and native._party[native.cursor]
      local mon = raw and self.adapter:mon(raw)
      local slot = 0
      for index, name in ipairs(native._forgetMoves) do
        repeat slot = slot + 1 until slot > 4 or (self.adapter.Pokemon.moveIdAt(raw, slot) or 0) > 0
        local row = raw and self:moveItem(raw, slot, name)
        if not row then return nil end
        items[index] = row
      end
      moveSelection = { mon = mon, items = items, itemName = self.adapter.Items.displayName(native._item) }
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
          right = "x" .. tostring(row.qty or 0), itemId = self.adapter.Items.toNumericId(row.id) }
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
          right = "x" .. tostring(item.qty or 0), itemId = item.id,
          catchChance = battle and self.adapter:catchChance(item.id, self.adapter.Battle.getState()) }
      end
      items[#items + 1] = { label = "CANCEL" }
    elseif native.mode == "action" then
      items, field = labels(native.ACTIONS), "actionCursor"
    end
  end
  local itemActionId, itemActionCount, actionOrder
  if items and mode == "action" and (layer.id == "bag" or layer.id == "tm_case" or layer.id == "berry_pouch") then
    local row = native.list()[native.cursor]
    itemActionId = row and self.adapter.Items.toNumericId(row.id)
    if not itemActionId then return nil end
    itemActionCount, title = row.qty, self.adapter.Items.displayName(itemActionId)
    if layer.id == "bag" then actionOrder = table.concat(native.ACTIONS, "\31") end
    if layer.id == "bag" and self.adapter.profile.id == "emerald"
        and not require("src.ui.game3.rse.bag_menu")._st.grid then return nil end
  end
  if quantity then items, field = { { label = "CONFIRM" } }, nil end
  if not items or #items == 0 or not quantity and type((sale or native)[field]) ~= "number" then return nil end
  local yesNoCallback = mode == "yesno" and (native._yesNoCallback or native._yesNoCb)
  local yesNoPrompt = mode == "yesno" and (native._yesNoPrompt or native.prompt)
  local key = tostring(layer) .. ":" .. tostring(mode) .. ":" .. tostring(native.pocketIdx)
    .. ":" .. tostring(native.holdingMon)
    .. ":" .. tostring(saleState) .. ":" .. tostring(itemActionId) .. ":" .. tostring(actionOrder)
    .. ":" .. tostring(native._forgetMoves) .. ":" .. tostring(native._forgetCallback)
    .. ":" .. tostring(yesNoCallback) .. ":" .. tostring(yesNoPrompt)
    .. ":" .. tostring(native._hmNotice) .. ":" .. tostring(native._confirmExit)
    .. ":" .. tostring(layer.id == "box_storage" and native._session.storage.currentBox)
    .. ":" .. tostring(relearnKey) .. ":" .. tostring(relearnMon) .. ":" .. tostring(relearnFirst)
  local learningPrompt = (layer.id == "party" or layer.id == "move_relearner") and mode == "yesno"
    and self:learningPrompt() or nil
  local view = self.view
  if not view or view.nativeKey ~= key then
    local owner = self
    view = { screenId = "Gen3Menu", nativeKey = key, update = function() end }
    local pocketIdx = native.pocketIdx
    local holding = native.holdingMon
    local storageBox = layer.id == "box_storage" and native._session.storage.currentBox
    local hmNotice, confirmExit = native._hmNotice, native._confirmExit
    local forgetMoves, forgetCallback, forgetMon = native._forgetMoves, native._forgetCallback,
      moveSelection and not relearnMoves and native._party[native.cursor or native._cursor]
    function view.valid(preview)
      return owner.Stack.top() == layer and native.open == true
        and nativeMode(layer) == mode and native.pocketIdx == pocketIdx
        and (not itemActionId or native.list()[native.cursor]
          and owner.adapter.Items.toNumericId(native.list()[native.cursor].id) == itemActionId)
        and (not actionOrder or table.concat(native.ACTIONS, "\31") == actionOrder)
        and native.holdingMon == holding
        and (not storageBox or mode == "pick_box" or native._session.storage.currentBox == storageBox)
        and native._forgetMoves == forgetMoves and native._forgetCallback == forgetCallback
        and (not forgetMon or native._party[native.cursor or native._cursor] == forgetMon)
        and (not relearnMoves or native._mon == relearnMon and table.concat(native.moves(), "\31") == relearnKey
          and owner.movePage.window(#native.moves(), native.cursor) == relearnFirst)
        and native._hmNotice == hmNotice and native._confirmExit == confirmExit
        and (mode ~= "yesno" or (native._yesNoCallback or native._yesNoCb) == yesNoCallback
          and (native._yesNoPrompt or native.prompt) == yesNoPrompt)
        and (not learningPrompt or learningPrompt.valid())
        and (not sale or native._sell == sale and sale.state == saleState)
        and (layer.id ~= "box_storage" or not require("src.ui.game3.release_seq").isActive())
        and (preview or not native._hpAnim) and not native._pokedude and not native._statBoost
        and (preview or not owner.Message.isOpen() and not owner.Choice.active)
        and (preview or not native._fx and not (native._slide and native._slide.active))
        and (preview or not native._fading)
        and (preview or not native.isPresentationBusy or not native.isPresentationBusy())
        and (preview or not native._switch and not native._exit and not native._open)
    end
    setmetatable(view, {
      __index = function(t, k)
        if k ~= "index" then return nil end
        if quantity then return 1 end
        if sale then return sale[field] end
        if layer.id == "box_storage" and mode == "pick_box" then return native._session.storage.currentBox end
        if field == "row" then return native.scroll + native.row + 1 end
        local value = native[field]
        if not t.nativeSlots then return value end
        for i, slot in ipairs(t.nativeSlots) do if slot == value then return i end end
      end,
      __newindex = function(t, k, v)
        if k == "index" then
          if t.valid() and field then
            if sale then sale[field] = v
            elseif layer.id == "box_storage" and mode == "pick_box" then native._session.storage.currentBox = v
            elseif field == "row" then
              local visible = (layer.id == "shop" or layer.id == "rse_item_storage") and 8 or 6
              native.scroll = math.max(0, math.min(v - 1, #t.items - visible))
              native.row = v - 1 - native.scroll
            else
              native[field] = t.nativeSlots and t.nativeSlots[v] or v
              if relearnMoves then native.scroll = math.max(0, v - 1) end
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
  view.bagContainer, view.itemActionId, view.itemActionCount = layer.id, itemActionId, itemActionCount
  view.bagList = not quantity and mode == "list" and not native._sellMode
    and (layer.id == "bag" or layer.id == "berry_pouch" or layer.id == "tm_case")
    and not native._fromBerryCrush and not native.holdingMon
    and native._location ~= "shop" and native._location ~= "itempc"
    and native._location ~= "berry_tree" and native._location ~= "blender"
  if quantity and quantity.itemId then quantity.itemSprite = self.adapter:itemIcon(quantity.itemId) end
  view.moveSelection = moveSelection
  if moveSelection then moveSelection.valid, moveSelection.message = view.valid, prompt end
  view.quantity = quantity
  view.prompt = prompt
  view.learningPrompt = learningPrompt
  if view.learningPrompt then view.title = "NEW MOVE" end
  view.nativeGrid, view.boxParty = grid, boxParty
  view.emptyTargets = boxParty and native.holdingMon ~= nil
  view.partyActions = layer.id == "party" and (native.mode == "action" or native.mode == "item_action")
    and #items <= 3 and self.adapter:mon(native._party and native._party[native.cursor]) or nil
  if layer.id == "box_storage" and mode == "action_menu" then
    view.partyActions = self.adapter:mon(native._actionTarget and native._actionTarget.mon)
  end
  view.fixedLayout, view.party = grid or moveSelection ~= nil or itemActionId ~= nil or prompt ~= nil or partyLayout or view.partyActions ~= nil, partyLayout and native or nil
  -- Every projection (including upper-screen ownership checks) retains the
  -- exact same draw/hit geometry; never leave a cached view with fresh bare rows.
  if not prompt or moveSelection then view.choiceState, view.touchWindow = nil, nil end
  if view.learningPrompt then
    self.movePage.promptLayout(items)
  elseif moveSelection then
    if moveSelection.catalogue then
      local first, count = self.movePage.listLayout(items, native.cursor)
      view.touchWindow = { first = first, count = count }
    else self.movePage.layout(items, slots) end
  elseif prompt then
    view.choiceState = view.choiceState or { page = 1 }
    local names = {}
    for index, item in ipairs(items) do names[index] = item.label end
    local model = self.choicePage.model(view.choiceState, names, nil, view.index)
    view.touchWindow = { first = model.first, count = #model.entries }
    for _, entry in ipairs(model.entries) do
      items[entry.index].rect = { entry.x, entry.y, entry.w, entry.h }
    end
  elseif itemActionId then
    self.itemPage.layout(items)
  elseif partyLayout then
    for slot, item in ipairs(items) do
      item.rect = { self.layout:partySelectionRect(slot, #items - 1, true) }
    end
  elseif view.partyActions then
    self.storagePage.actions(self.layout, items)
  end
  return view
end

function UI:bagActions(id)
  local a = self.adapter
  local def = a.data.items[id]
  if not def then return {} end
  local pocket, info = def.nativePocket, a.Items.info(id) or {}
  if pocket == "KEY_ITEMS" then
    local actions = { "USE" }
    if (tonumber(info.registrability) or 0) > 0 then actions[#actions + 1] = "SET" end
    return actions
  elseif pocket == "POKE_BALLS" then return { "GIVE", "TOSS" }
  elseif pocket == "TM_CASE" then
    -- The host currently supports teaching here; its GIVE path refuses TMs/HMs.
    return { "USE" }
  elseif pocket == "BERRY_POUCH" and a.profile.id == "emerald" then
    return { "CHECK_TAG", "USE", "GIVE", "TOSS" }
  end
  return { "USE", "GIVE", "TOSS" }
end

function UI:openBagItem(id, action)
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
      if not action then return true end
      -- One explicit companion action enters the native item action directly.
      -- Native handlers still own party/mail, quantity, confirmation and effects.
      if menu.settle then menu.settle() end
      local confirm = { wasPressed = function(_, key) return key == "a" end,
        isDown = function() return false end }
      menu.handleInput(confirm)
      -- The host refreshes pocket-specific ACTIONS on the first action tick.
      menu.handleInput({ wasPressed = function() return false end, isDown = function() return false end })
      local actions = menu.ACTIONS or (pocket == "TM_CASE" and { "USE", "GIVE", "EXIT" }
        or { "USE", "GIVE", "TOSS", "EXIT" })
      if menu.mode == "action" then
        for index, name in ipairs(actions) do
          if name == action then
            menu.actionCursor = index
            menu.handleInput(confirm)
            return true
          end
        end
      end
      menu.close()
      return false
    end
  end
  menu.close()
  return false
end

return UI
