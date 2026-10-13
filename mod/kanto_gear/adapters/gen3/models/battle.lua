return function(Gen3)
  -- A presentation state for native battles, which do not live on Game.stack.
  -- It deliberately cannot claim the legacy upper-screen visibility contract.
  -- Game path [Gen 3]: project the native battle state for shared views; legacy upper-screen visibility hooks do not describe this engine.
  function Gen3:battleState()
    local B = self.Battle
    if not B or not B.isActive() then return nil end
    local st, U = B.getState(), self.BattleUI
    if not st then return nil end
    if not self.battleView or self.battleSource ~= st then
      self.battleSource = st
      self.battleView = { isBattleState = true, nativeGen3 = true }
      -- Game path [Gen 3]: Safari retains native action order; ordinary battles swap the bag/party indices for the shared view.
      local order = st.safari and { 1, 2, 3, 4 } or { 1, 3, 2, 4 }
      setmetatable(self.battleView, {
        __index = function(_, key)
          if key == "menuIndex" then return U and order[U._menuIndex] end
          if key == "moveIndex" then return U and U._moveIndex end
        end,
        __newindex = function(t, key, value)
          if key == "menuIndex" then if U then U._menuIndex = order[value] end
          elseif key == "moveIndex" then if U then U._moveIndex = value end
          else rawset(t, key, value) end
        end,
      })
    end
    local view = self.battleView
    view.phase = B._phase == "command" and U and U._mode or B._phase
    view.kind, view.battle = st.kind or (st.wild and "wild" or "trainer"), st
    view.player, view.enemy = st.player, st.enemy
    view.enemyParty = st.foeParty
    view.tutorial, view.demo = st.oldManTutorial or B._auto, st.pokedude
    view.activeBattler = U and U._active
    view.draining = self.Anim.busy() and (not self.Message.isOpen()
      or self.Message._held or self.Message._stay) or false
    return view
  end
  -- Message.currentPage is a single visible page, not a history of messages.
  -- Read the native printer's tokens so color/spacing codes never become text.
  function Gen3:messageText()
    if not self.Message.isOpen() then return nil end
    return self:plainText(self.Message.currentPage())
  end
  function Gen3:plainText(text)
    local out = {}
    local glyphs = { [0x53] = "PK", [0x54] = "MN", [0x34] = "Lv",
      [0x55] = "POKéBLOCK", [0x56] = "", [0x57] = "", [0x58] = "", [0x59] = "",
      [0x2C] = "er", [0x84] = "e", [0xA0] = "re" }
    for kind, value in self.Font.scanTokens(text) do
      if kind == "char" or kind == "nl" then out[#out + 1] = value
      elseif kind == "glyph" then
        out[#out + 1] = glyphs[value] or self.TextIR.CHARMAP[value]
          or self.TextIR.EXTRA_SYMBOL[value - 0x100] or "?"
      elseif kind == "icon" then
        out[#out + 1] = ({ "A", "B", "L", "R", "START", "SELECT",
          "UP", "DOWN", "LEFT", "RIGHT", "UP/DOWN", "LEFT/RIGHT", "DPAD" })[value + 1] or "?"
      end
    end
    return table.concat(out)
  end
  function Gen3:battleSnapshot(snapshot)
    if not snapshot then return nil end
    local state = self:battleState()
    local st = state and state.battle
    if not st then return nil end
    snapshot.menuIndex, snapshot.moveIndex = state.menuIndex, state.moveIndex
    snapshot.nativeUnsupported = not not st.link
    snapshot.nativeInputLocked = state.tutorial or state.demo or false
    snapshot.nativeMessage = self:messageText()
    if snapshot.nativeMessage then
      snapshot.message = { snapshot.nativeMessage }
      -- An Oak voiceover or an item notice can cover a still-open command menu.
      -- Held/timed pages must not advertise a continue action they cannot take.
      local M = self.Message
      snapshot.nativeCanReveal = M.isTyping() and not M._choice
      snapshot.prompt = M.isWaiting() and not M._stay and not M._held
        and not M._choice and "advance" or "locked"
    end
    if snapshot.nativeInputLocked then
      snapshot.prompt, snapshot.nativeCanReveal = "locked", false
    end
    if st.safari and snapshot.prompt == "menu" then
      snapshot.prompt, snapshot.safariBalls = "safari", st.safariState and st.safariState.balls or 0
      snapshot.safariActions = (require("src.core.game3.battle.profile").of(st).safari or {}).actions
      local Text = require("src.core.game3.rom_text")
      local ir = Text.ir("gText_SafariZoneMenu")
      if self.safariMenuIr ~= ir then
        local labels, buffer = {}, {}
        local function flush()
          if #buffer > 0 then labels[#labels + 1], buffer = table.concat(buffer), {} end
        end
        for _, segment in ipairs(ir) do
          if segment.t == "text" then buffer[#buffer + 1] = segment.s
          elseif segment.t == "tag" then buffer[#buffer + 1] = segment.tag
          elseif segment.t == "nl" or segment.t == "ext" and segment.cmd == 19 then flush() end
        end
        flush()
        self.safariMenuIr, self.safariMenuLabels = ir, labels
      end
      snapshot.safariLabels = {}
      for index, label in ipairs(self.safariMenuLabels) do
        snapshot.safariLabels[index] = self:plainText(require("src.core.Strings")(label, "gText_SafariZoneMenu"))
      end
    end
    local function enrich(out, source)
      if not out or not source then return end
      local view = self:mon(source)
      out.source, out.species, out.types = view, view.species, view.types
      out.gender, out.shiny, out.isEgg = view.gender, view.shiny, view.isEgg
      out.name = view.nickname or self.Pokemon.name(view.species)
      out.level, out.status = view.level, view.status
    end
    for i, mon in ipairs(st.playerParty or {}) do enrich(snapshot.party[i], mon) end
    local owner = snapshot.active == 2 and st.battlers and st.battlers[2] or st.player
    enrich(snapshot.player, owner and owner.mon)
    enrich(snapshot.enemy, st.enemy and st.enemy.mon)
    for _, side in ipairs({ "player", "enemy" }) do
      local out, source = snapshot[side], side == "player" and owner or st.enemy
      if out and source then
        local key = st.double and (side == "player" and snapshot.active or 1) or side
        local shown = self.Anim.shownBattler(key, source)
        enrich(out, shown and shown.mon)
        local _, hp, maxHp = self.Anim.displayHpRatio(key, shown)
        local exp, level = self.Anim.displayExpRatio(key, shown)
        out.hp, out.maxHp = math.floor(hp), maxHp
        out.level = level or out.level
        out.expProgress = exp
        out.nativeShownHp = out.hp
        out.partyIndex = nil
        for index, mon in ipairs(side == "player" and st.playerParty or st.foeParty or {}) do
          if shown and shown.mon == mon then out.partyIndex = index; break end
        end
        if out.hp > 0 and out.status == "FNT" then out.status = nil end
      end
    end
    -- The four slots keep battlefield identity even when the active command
    -- switches to the partner. Reuse the host's displayed HP during animations.
    for _, out in ipairs(snapshot.battlers or {}) do
      local source = st.battlers and st.battlers[out.id]
        or (out.id == 0 and st.player or out.id == 1 and st.enemy)
      if source then
        local key = st.double and out.id or out.side
        local shown = self.Anim.shownBattler(key, source)
        enrich(out, shown and shown.mon)
        local _, hp, maxHp = self.Anim.displayHpRatio(key, shown)
        local exp, level = self.Anim.displayExpRatio(key, shown)
        out.hp, out.maxHp = math.floor(hp), maxHp
        out.level = level or out.level
        out.expProgress = exp
        out.partyIndex = nil
        for index, mon in ipairs(out.side == "player" and st.playerParty or st.foeParty or {}) do
          if shown and shown.mon == mon then out.partyIndex = index; break end
        end
        if out.hp > 0 and out.status == "FNT" then out.status = nil end
      end
    end
    -- A double battle can finish as one versus one. Use the sole living foe
    -- only when no ally or second opponent remains as another possible target.
    local target = st.double and snapshot.target ~= nil and st.battlers[snapshot.target]
      or not st.double and st.enemy
    if st.double and not target then
      local players, enemies = 0, 0
      for id = 0, 3 do
        local candidate = st.battlers and st.battlers[id]
        if candidate and not (st.absent and st.absent[id]) and not candidate.fainted
            and (tonumber(candidate.mon and candidate.mon.hp) or 0) > 0 then
          if id % 2 == 0 then players = players + 1
          else enemies, target = enemies + 1, candidate end
        end
      end
      if players ~= 1 or enemies ~= 1 then target = nil end
    end
    for index, move in ipairs(snapshot.moves or {}) do
      if snapshot.prompt == "moves" then
        local reason = require("src.core.game3.battle.commands").selectionError(st, move.slot or index, snapshot.active)
        move.disabled, move.disabledReason = reason ~= nil, reason and self:plainText((reason:gsub("\\[pl]", " ")))
      end
      move.id = self.Moves.constName(move.id)
      -- Base type matchup, as in the other editions.
      if target and move.id ~= "HIDDEN_POWER" and move.id ~= "WEATHER_BALL" then
        move.effectiveness = self.Types.effectiveness(move.type, target.type1, target.type2) * 10
      end
      move.type = self.typeNames[move.type] or move.type
    end
    return snapshot
  end
  function Gen3:catchChance(itemId, st)
    if not st or not st.wild or st.ghost or st.noCatch or st.double
        or require("src.mods.Runtime").wantsHook("catch.rate") then return nil end
    local catching = require("src.core.game3.battle.catching")
    if not catching.isBall(itemId) then return nil end
    local odds = catching.catchOdds(itemId, st.enemy, st, self.session)
    if odds >= 255 then return 100 end
    -- Native catching uses four independent draws from 0..65535; no RNG is consumed here.
    local threshold = math.floor(1048560 / math.sqrt(math.sqrt(16711680 / odds)))
    return 100 * (threshold / 65536) ^ 4
  end
end
