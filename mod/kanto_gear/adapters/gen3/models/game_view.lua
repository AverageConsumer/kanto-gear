return function(Gen3, clear)
  -- Legacy renderers receive a projection, while input hooks, storage and all
  -- commands retain self.game. Unknown native modal screens deliberately do not
  -- claim a legacy screenId: only explicitly adapted screens may own input.
  function Gen3:gameView()
    if self.view then return self.view end
    local maps = require("src.core.game3.map")
    local nativeStack = require("src.ui.game3.stack")
    local summarySkin
    local world = { player = require("src.core.game3.player"), map = {} }
    -- Game path [Ruby/Sapphire/Emerald]: use the native RTC and save offset; FireRed/LeafGreen has no day/night clock.
    if self.profile.clock and self.profile.clock.rtc then
      local rtc = require("src.core.game3.rtc")
      local function time()
        return rtc.calcTimeDifferenceRtc(rtc.getInfo(self.session), self.session and self.session.localTimeOffset)
      end
      function world:hour() return time().hours end
      function world:minute() return time().minutes end
    end
    local methods = {}
    local stack = { states = {} }
    local layers = setmetatable({}, { __mode = "k" })
    local locked = { screenId = "Gen3:busy" }
    local text = { screenId = "Gen3:message", isTextBox = true }
    function stack:top() return self.states[#self.states] end
    self.syncScreens = function()
      clear(stack.states)
      if self.session and self.game.phase == "field" then
        world.map.id = maps.current or self.session.map
        stack.states[1] = world
        local battle = self:battleState()
        if battle then stack.states[#stack.states + 1] = battle end
        local callOpen = false
        for _, layer in ipairs(nativeStack._layers) do
          local state = layers[layer]
          if not state then
            state = { screenId = "Gen3:" .. tostring(layer.id), nativeModal = true }
            layers[layer] = state
          end
          if layer.id == "summary" and layer.mod then
            local native = layer.mod
            state.screenId, state.native = "Gen3SummaryMenu", native
            state.mon = self:mon(native._party and native._party[native._cursor])
            state.page = (native._page or 0) + 1
            state.moveDetail = native._mode == "select_move" or state.page > 3 or false
            -- Game path [Ruby/Sapphire vs Emerald]: both add contest pages, but RS _state and Emerald skin helpers expose different detail states.
            if self.rs then
              state.pages = 4
              state.moveDetail = native._state ~= "normal"
            elseif self.profile.id == "emerald" then
              summarySkin = summarySkin or require("src.ui.game3.rse.summary_menu")
              state.page, state.pages = summarySkin.page(native) + 1, 4
              state.moveDetail = summarySkin.detail(native)
            end
          end
          state.phase = layer.mod and layer.mod.mode
          state.index = layer.mod and (layer.mod.mode == "action" and layer.mod.actionCursor
            or layer.mod.mode == "item_action" and layer.mod.itemActionCursor
            or layer.mod.cursor or layer.mod._cursor)
          state.pocketIndex = layer.mod and layer.mod.pocketIdx
          -- Game path [Emerald]: Match Call owns a separate printer; its page waits and hang-up cannot use the shared Message state.
          if layer.id == "rse_match_call_window" then
            -- Match Call owns its printer instead of using Message. Keep native
            -- page waits and hang-up input, without advancing through its slides.
            callOpen = true
            local call = layer.mod and layer.mod._s
            local printer = call and call.printer
            state.phase, state.page = call and call.state, printer
            state.isTextBox = printer ~= nil and (state.phase == 5 or state.phase == 6)
            state.done = not printer or not printer:isActive()
            state.waiting = state.isTextBox and (printer.state == "wait"
              or printer.state == "clear" or printer.state == "scroll_start"
              or state.phase == 6 and state.done)
            state.choice = state.done and not state.waiting
          end
          stack.states[#stack.states + 1] = state
        end
        if self.Message.isOpen() and not self.Choice.active and not callOpen then
          text.page = self.Message._page
          -- Script messages stay visible until closemessage, but their earlier
          -- pages and an armed waitbuttonpress still accept native A input.
          local lastPage = self.Message._page >= #(self.Message._pages or {})
          text.choice = self.Message._choice or self.Message._held
            or (self.Message._stay and lastPage and not self.Hud._waitButton)
          text.waiting = self.Message.isWaiting() and not text.choice
          text.done = not self.Message.isTyping()
          stack.states[#stack.states + 1] = text
        end
        -- Native scripts, transitions and battles need not push a UI layer.
        -- Walking alone is not a modal state and must not dim the live map.
        local Field, Warp, Runtime, Battle = self.Field, self.Warp, self.Runtime, self.Battle
        if #stack.states == 1 and (Field and Field.locked
            or Warp and Warp.isBusy() or Runtime and Runtime.uiBusy()
            or Battle and Battle.isActive()) then
          stack.states[2] = locked
        end
      end
    end
    self.view = setmetatable({}, { __index = function(_, key)
      if key == "save" then return self.save end
      if key == "data" then return self.data end
      if key == "stack" then return stack end
      if key == "world" or key == "overworld" then
        return self.session and self.game.phase == "field" and world or nil
      end
      local value = self.game[key]
      if type(value) == "function" then
        if not methods[key] then methods[key] = function(_, ...) return value(self.game, ...) end end
        return methods[key]
      end
      return value
    end })
    self.syncScreens()
    return self.view
  end
end
