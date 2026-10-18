return function(
  THEME, attachBattleArtSprites, battleChoice, battleState, bottomOnHandheld, compat,
  displayPreference, displayRuntime, hgssRuntime, mod, prepareBattleSnapshot, render,
  screenContract, session
)
  local function draw()
    local measured = displayRuntime.perf:start()
    local stackDepth = render.G.getStackDepth and render.G.getStackDepth()
    render.G.push("all")
    local ok, err = pcall(function()
      displayRuntime.prepareMotion()
      local motion = displayRuntime.motion
      local cached = motion.direction and motion.cached and motion.started
        and love.timer.getTime() - motion.started < motion.duration
      if not cached and not displayRuntime.drawMapRefresh() then displayRuntime.drawContents() end
      displayRuntime.applyMotion()
    end)
    -- A failed nested draw skips its own pops. Restore our entire scope before
    -- the host catches the error and continues rendering the next frame.
    if stackDepth then
      while render.G.getStackDepth() > stackDepth do render.G.pop() end
    else
      render.G.pop()
    end
    displayRuntime.perf:finish("gear_draw", measured)
    if not ok then
      -- A hidden native menu is safe only while the lower view can be drawn.
      session.displayReady = false
      if THEME.hgss then THEME.hgss.nativeFocus = false end
      THEME.nativeFocus = nil
      displayRuntime.mapRefresh.paintedPage = nil
      error(err, 0)
    end
  end

  local function pumpDisplay()
    if displayRuntime.moduleReadbackPending then
      if session.canvas.pollImageData and not session.canvas:pollImageData() then return false end
      displayRuntime.moduleReadbackPending, session.readbackPending = nil, false
      displayRuntime.readbackStarted = nil
      session.dirty = true
    end
    local captureAt = love.timer.getTime()
    if THEME:displayMode(mod.options) == "phone" and not session.readbackPending
        and not (displayRuntime.phone and displayRuntime.phone:canCapture()) then return false end
    local shown = false
    if not session.canvas.requestImageData or not session.canvas.pollImageData then
      if session.dirty then
        draw()
        session.dirty = false
      end
      if not session.canvas.newImageData then return false end
      local ok, image = pcall(displayRuntime.perf.call, displayRuntime.perf,
        "readback_sync", session.canvas.newImageData, session.canvas)
      if not ok or not image then return false end
      if THEME:displayMode(mod.options) == "phone" then displayRuntime.phone:reserveCapture(captureAt) end
      shown = displayRuntime.perf:present(session.companion.push, image, session.canvas:getWidth(), session.canvas:getHeight(),
        displayRuntime.backgroundColor(),
        displayPreference())
      session.displayReady = shown
      if not shown then
        session.dirty = true
        session.nextPresentAttempt = love.timer.getTime() + 0.25
      end
      return shown
    end
    if bottomOnHandheld() then
      if session.readbackPending and displayRuntime.perf:call("readback_poll", session.canvas.pollImageData, session.canvas) then
        session.readbackPending = false
      end
      if session.dirty then
        draw()
        session.dirty = false
      end
      return false
    end
    if session.readbackPending then
      local image = displayRuntime.perf:call("readback_poll", session.canvas.pollImageData, session.canvas)
      if image then
        displayRuntime.perf:finish("readback_age", displayRuntime.readbackStarted)
        displayRuntime.readbackStarted = nil
        shown = displayRuntime.perf:present(session.companion.push, image, session.canvas:getWidth(), session.canvas:getHeight(),
          displayRuntime.readbackBackground,
          displayPreference())
        session.readbackPending = false
        session.displayReady = shown
        if not shown then
          session.dirty = true
          session.nextPresentAttempt = love.timer.getTime() + 0.25
        end
      end
    end
    if not session.readbackPending and session.dirty and (THEME:displayMode(mod.options) ~= "phone"
        or displayRuntime.phone and displayRuntime.phone:canCapture()) then
      draw()
      if displayRuntime.perf:call("readback_request", session.canvas.requestImageData, session.canvas) then
        if THEME:displayMode(mod.options) == "phone" then displayRuntime.phone:reserveCapture(captureAt) end
        -- Keep the border paired with this captured frame during async readback.
        displayRuntime.readbackBackground = displayRuntime.backgroundColor()
        session.readbackPending = true
        displayRuntime.readbackStarted = displayRuntime.perf:start()
        session.dirty = false
      end
    end
    return shown
  end

  function displayRuntime.syncCompanionDetails()
    if displayRuntime.gen3 then displayRuntime.gen3.syncScreens() end
    local top = session.game and session.game.stack and session.game.stack:top()
    local prompt = session.battle and session.battle.prompt
    local previous = displayRuntime.detailContext
    if not session.moveInfo then
      displayRuntime.detailContext = nil
    elseif not previous or previous.info ~= session.moveInfo then
      displayRuntime.detailContext = { info = session.moveInfo, top = top,
        prompt = prompt, page = top and top.page, index = top and top.index }
    elseif previous.top ~= top or previous.prompt ~= prompt
        or previous.page ~= (top and top.page) or previous.index ~= (top and top.index) then
      -- Game buttons remain live while Gear shows details. Drop stale details
      -- when that native context changes instead of trapping the game input.
      session.moveInfo, displayRuntime.detailContext, session.dirty = nil, nil, true
      hgssRuntime.animation = nil
    end
  end

  local function refreshBattle()
    local nextBattle = mod.battle and mod.battle:snapshot() or nil
    if displayRuntime.gen3 then nextBattle = displayRuntime.gen3:battleSnapshot(nextBattle) end
    if nextBattle then
      local raw = battleState()
      local top = session.game and session.game.stack and session.game.stack:top()
      nextBattle.menuIndex = raw and raw.menuIndex
      nextBattle.moveIndex = raw and raw.moveIndex
      nextBattle.mimicIndex = raw and raw.mimicIndex
      local party = screenContract(top, "party")
      nextBattle.partyIndex = party and party.index or nil
      local submenu = party and type(party.submenu) == "table"
        and party.submenu or nil
      nextBattle.subIndex = party and party.submenu
        and (party.subIndex or (submenu and submenu.index)) or nil
      local bag = compat.battleBagMenu(top)
      nextBattle.itemIndex = bag and bag.index or nil
      nextBattle.itemPocket = bag
        and (bag.__pocketIndex or bag.pocketIndex) or nil
      nextBattle.itemTitle = bag and bag.title or nil
      nextBattle.summaryPage = compat.isScreen(top, "summary")
        and top.page or nil
      -- Snapshot reads never redirect the original game cursor.
      prepareBattleSnapshot(nil, nextBattle, raw, session.game.data, false)
      for index, mon in ipairs(nextBattle.party or {}) do
        local source = (session.game.save.party or {})[mon.slot or index]
        if not mon.source and source and source.species == mon.species then mon.source = source end
        mon.expProgress = displayRuntime.partyExpProgress(mon)
      end
      attachBattleArtSprites(raw, nextBattle)
      if battleChoice(top) and not nextBattle.message
          and raw and type(raw.visibleText) == "function" then
        local ok, visible = pcall(raw.visibleText, raw)
        if ok and type(visible) == "table" then
          nextBattle.message = {}
          for i, line in ipairs(visible) do
            nextBattle.message[i] = tostring(line)
          end
        end
      end
      for _, side in ipairs({ "player", "enemy" }) do
        local source = raw and (raw[side] or (raw.battle and raw.battle[side]))
        local copy = nextBattle[side]
        if source and copy then
          local mon = source.mon or source
          local shown = raw.shownHp and raw.shownHp[side]
          copy.hp = math.max(0, math.floor(copy.nativeShownHp or source.shownHP or shown
            or mon.hp or copy.hp or 0))
          if source.shownStatus ~= nil then copy.status = source.shownStatus end
          if raw.shownStatus and raw.shownStatus[side] ~= nil then
            copy.status = raw.shownStatus[side]
          end
          -- Game path [Gen 2]: displayed level and eight-cell EXP crawl lag final Pokemon data during level-up animation.
          if side == "player" and compat.isGen2() then
            copy.level = raw.shownLevel or copy.level
            -- Gold/Silver/Crystal expose the native eight-cell EXP crawl.
            if raw.shownExp ~= nil then copy.expProgress = raw.shownExp / 64 end
          end
        end
      end
      -- Game path [Gen 2]: fill absent matchup hints from the native type chart; do not replace an effectiveness value already supplied by the host.
      if compat.isGen2() and nextBattle.enemy then
        local enemy = session.game.data.pokemon
          and session.game.data.pokemon[nextBattle.enemy.species]
        for _, move in ipairs(nextBattle.moves or {}) do
          if move.effectiveness == nil then
            move.effectiveness = compat.typeEffectiveness(move.type,
              enemy and enemy.types, session.game.data.type_chart)
          end
        end
      end
    end
    local changed = (not session.battle) ~= (not nextBattle)
      or (session.battle and nextBattle and session.battle.revision ~= nextBattle.revision)
      or (session.battle and nextBattle and prepareBattleSnapshot(session.battle, nextBattle))
      or (session.battle and nextBattle and (
        (session.battle.player and session.battle.player.hp) ~= (nextBattle.player and nextBattle.player.hp)
        or (session.battle.player and session.battle.player.expProgress) ~= (nextBattle.player and nextBattle.player.expProgress)
        or (session.battle.player and session.battle.player.level) ~= (nextBattle.player and nextBattle.player.level)
        or (session.battle.player and session.battle.player.maxHp) ~= (nextBattle.player and nextBattle.player.maxHp)
        or (session.battle.player and session.battle.player.status) ~= (nextBattle.player and nextBattle.player.status)
        or (session.battle.enemy and session.battle.enemy.status) ~= (nextBattle.enemy and nextBattle.enemy.status)
        or (session.battle.enemy and session.battle.enemy.hp) ~= (nextBattle.enemy and nextBattle.enemy.hp)
        or (session.battle.enemy and session.battle.enemy.level) ~= (nextBattle.enemy and nextBattle.enemy.level)
        or (session.battle.enemy and session.battle.enemy.maxHp) ~= (nextBattle.enemy and nextBattle.enemy.maxHp)
        or (session.battle.player and session.battle.player.presentationSprite)
          ~= (nextBattle.player and nextBattle.player.presentationSprite)
        or (session.battle.enemy and session.battle.enemy.presentationSprite)
          ~= (nextBattle.enemy and nextBattle.enemy.presentationSprite)))
    if session.battle and nextBattle then
      for index, mon in ipairs(nextBattle.party or {}) do
        local before = session.battle.party and session.battle.party[index]
        if not before or before.expProgress ~= mon.expProgress then changed = true end
      end
    end
    if session.battle and nextBattle and nextBattle.double then
      for i, mon in ipairs(nextBattle.battlers or {}) do
        local before = session.battle.battlers and session.battle.battlers[i]
        if not before or before.id ~= mon.id or before.hp ~= mon.hp
            or before.maxHp ~= mon.maxHp or before.species ~= mon.species
            or before.name ~= mon.name or before.status ~= mon.status or before.absent ~= mon.absent
            or before.level ~= mon.level or before.expProgress ~= mon.expProgress
            or session.battle.active ~= nextBattle.active then changed = true end
      end
    end
    if THEME.style == "hgss" and session.battle and nextBattle then
      local oldParty, newParty = session.battle.partyIndex ~= nil,
        nextBattle.partyIndex ~= nil
      local oldBag, newBag = session.battle.itemIndex ~= nil,
        nextBattle.itemIndex ~= nil
      if session.battle.prompt ~= "moves" and nextBattle.prompt == "moves" then
        if not (hgssRuntime.animation
            and hgssRuntime.animation.kind == "battle_moves") then
          hgssRuntime.beginAnimation("battle_moves")
        end
      elseif session.battle.prompt == "moves" and nextBattle.prompt == "menu" then
        if not (hgssRuntime.animation
            and hgssRuntime.animation.kind == "battle_moves_close") then
          hgssRuntime.beginAnimation("battle_moves_close")
        end
      elseif not oldParty and newParty then
        if not (hgssRuntime.animation
            and hgssRuntime.animation.kind == "battle_party") then
          hgssRuntime.beginAnimation("battle_party", { duration = 0.28 })
        end
      elseif oldParty and not newParty and nextBattle.prompt == "menu" then
        if not (hgssRuntime.animation
            and hgssRuntime.animation.kind == "battle_party_close") then
          hgssRuntime.beginAnimation("battle_party_close")
        end
      elseif not oldBag and newBag then
        if not (hgssRuntime.animation
            and hgssRuntime.animation.kind == "battle_bag") then
          hgssRuntime.beginAnimation("battle_bag")
        end
      elseif oldBag and not newBag and nextBattle.prompt == "menu" then
        if not (hgssRuntime.animation
            and hgssRuntime.animation.kind == "battle_bag_close") then
          hgssRuntime.beginAnimation("battle_bag_close")
        end

      end
    end
    session.battle = nextBattle
    if displayRuntime.enemyInfoSelection ~= nil then
      local present = false
      for _, mon in ipairs(session.battle and session.battle.battlers or {}) do
        if mon.id == displayRuntime.enemyInfoSelection and mon.side == "enemy" and not mon.absent then
          present = true
          break
        end
      end
      if not present then session.battleInfoDetail, displayRuntime.enemyInfoSelection = nil, nil end
    end
    displayRuntime.syncCompanionDetails()
    if changed then
      if not session.battle then
        session.moveInfo = nil
        session.battleInfoDetail = nil; displayRuntime.enemyInfoSelection = nil
        hgssRuntime.animation = nil
      else
        session.radarOpen = false
      end
      session.dirty = true
    end
  end

  return draw, pumpDisplay, refreshBattle
end
