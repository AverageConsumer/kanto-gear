return function(UI, labels)
  local bit = require("bit")
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
  -- Fallback for hosts without extracted naming pages (FRLG). Newer hosts
  -- supply state.pages, including Emerald's extra blank cells. Those cells
  -- determine where the native three-button column starts.
  -- Host path [FRLG/Emerald]: older FRLG hosts lack extracted naming pages; prefer native pages (including Emerald blank cells) whenever supplied.
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
    local layout = self.keyboardLayout and self.keyboardLayout() or "qwerty"
    local key = tostring(layer) .. ":" .. tostring(state) .. ":" .. state.page .. ":" .. tostring(state.pcPage) .. ":" .. layout
    local view = self.namingView
    if not view or view.nativeKey ~= key then
      local pageIndex, pcPages, pcPage = state.page, state.pcPages, state.pcPage
      view = { screenId = "Gen3Menu", title = state.title, nativeKey = key, update = function() end,
        fixedLayout = true, nativeGrid = true, items = {} }
      function view.valid(preview)
        return self.Stack.top() == layer and native.openFlag and native._state == state
          and not state.finished and state.page == pageIndex
          and state.pcPages == pcPages and state.pcPage == pcPage
          and (not self.keyboardLayout or self.keyboardLayout() == layout)
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
      view.namingModel = self.namingPage.model("", view.items, nil, nil, layout)
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
  function UI:stats()
    local stats = self.Stats
    local mon, page, oldStats, newStats, callback = stats._mon, stats._page, stats._oldStats, stats._newStats, stats._onDone
    local key = tostring(mon) .. ":stats:" .. page .. ":" .. tostring(oldStats) .. ":" .. tostring(newStats) .. ":" .. tostring(callback)
    if not self.statsView or self.statsView.nativeKey ~= key then
      local normalized = self.adapter:mon(mon)
      local sequence = self.adapter.ExpSeq
      local step = sequence and sequence._steps and sequence._steps[sequence._i]
      local growth = step and step.kind == "level" and step.data
      -- The live mon has already gained every level. Bind the heading to the
      -- same queued step that owns these exact native stat snapshots.
      local level = growth and growth.mon == mon and growth.oldStats == oldStats
        and growth.newStats == newStats and tonumber(growth.level) or nil
      self.statsView = { screenId = "Gen3Menu", title = "LEVEL UP", nativeKey = key,
        nativeStats = stats, items = labels({ "CONTINUE" }), index = 1, update = function() end,
        levelStats = { mon = { species = normalized.species, level = level or normalized.level, types = normalized.types,
          name = self.adapter.Pokemon.displayMonName(mon) }, source = mon,
          stats = { splitSpecial = true }, gain = { from = level and level - 1, deltas = {} } },
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
  function UI:choice()
    local Choice = self.Choice
    local key = Choice.options
    local learning = Choice.kind == "yesno" and self:learningPrompt() or nil
    local owner, move = learning and learning.rawMon, learning and learning.newMoveId
    local view = self.choiceView
    if not view or view.options ~= key or view.learningOwner ~= owner or view.learningMove ~= move then
      view = { screenId = "Gen3Menu", title = "CHOOSE ACTION", options = key, native = self.adapter.BattleUI,
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
  function UI:target(battle)
    local U = self.adapter.BattleUI
    local target = U and U._target
    if not target then return nil end
    local items, ids, selected = {}, {}, 1
    local owner = self.adapter:battleState()
    local active = owner and owner.battle and (target.battler == 2
      and owner.battle.battlers[2] or owner.battle.player)
    local move = active and active.mon.moves and active.mon.moves[target.slot]
    local def = move and self.adapter.Moves.get(move)
    local moveName = move and self.adapter.Moves.constName(move)
    local selfTarget = math.floor((tonumber(def and def.target) or 0) / 2) % 2 == 1
    local allowed = {}
    for _, id in ipairs(battle.targets or {}) do allowed[id] = true end
    -- The native target cursor cycles by battlefield identity, not API order.
    for _, id in ipairs({ 0, 2, 3, 1 }) do
      for _, mon in ipairs(battle.battlers or {}) do
        if allowed[id] and mon.id == id and (id ~= target.battler or selfTarget) then
          local defender = owner and owner.battle and owner.battle.battlers[id]
          -- Match the move cards: preview the current defensive types, not
          -- species defaults or the opponent last highlighted by the cursor.
          local effectiveness
          if defender and def and (def.power or 0) > 0
              and moveName ~= "HIDDEN_POWER" and moveName ~= "WEATHER_BALL" then
            effectiveness = self.adapter.Types.effectiveness(def.type, defender.type1, defender.type2) * 10
          end
          items[#items + 1], ids[#ids + 1] = { label = mon.name or "POKEMON",
            targetSide = mon.side, value = "pokemon", effectiveness = effectiveness,
            right = (mon.side == "player" and "YOUR SIDE" or "FOE") }, id
          if target.cursor == id then selected = #items end
        end
      end
    end
    local view = self.targetView
    if not view or view.target ~= target then
      view = { screenId = "Gen3Menu", title = "CHOOSE TARGET", target = target, native = U,
        nativeKey = tostring(target), update = function() end,
        valid = function() return self.Stack.top() == nil and U._mode == "target" and U._target == target end }
      self.targetView = view
    end
    view.items, view.battleTargets, view.index = items, ids, selected
    return view
  end
end
