return function(UI, labels)
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
  -- Game path [Ruby/Sapphire/Emerald]: contest treats use a native case and feeding flow; FireRed/LeafGreen has no Pokeblock case.
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
        -- Game path [Ruby/Sapphire vs Emerald]: RS displays a plain numeric level; Emerald wraps it in the native Lv text template.
        itemSprite = self:pokeblockIcon(Blocks.data(block, 0)), right = self.adapter.rs
          and tostring(Blocks.highestFlavorLevel(block)) or self.adapter:plainText(
        require("src.core.game3.rom_text").plain("gText_LvVar1", {
          stringVars = { tostring(Blocks.highestFlavorLevel(block)) } })) }
    end
    items[#items + 1] = { label = self.adapter:plainText(require("src.core.game3.rom_text").plain(
      self.adapter.rs and "gContestStatsText_StowCase" or "gText_StowCase")) }
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
end
