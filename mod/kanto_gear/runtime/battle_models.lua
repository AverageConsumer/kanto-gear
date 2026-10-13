return function(
  THEME, assist, battleState, categorizedBag, caughtWild, clockText,
  compat, customBattleLayout, displayRuntime, drawSprite, hgssRuntime, mod,
  progressRatio, session
)
  function hgssRuntime.numberLabel(value)
    value = tonumber(value)
    if not value then return "--" end
    if value == math.floor(value) then return tostring(value) end
    return ("%.1f"):format(value)
  end

  function hgssRuntime.moveView(move, enemyTypes)
    local source = compat.moveInfoEntry(move)
      or type(move) == "table" and move or {}
    local def = session.game.data.moves[source.id] or {}
    local moveType = source.type or def.type
    local details = assist("move_details")
    local power = details and source.displayPower or nil
    if power == nil then power = source.power or def.power end
    if power == 0 then power = nil end
    local accuracy = details and source.hitChance or nil
    if accuracy == nil then accuracy = source.accuracy or def.accuracy end
    local maxPp = source.maxPp or def.pp or source.pp or 0
    local unavailable = THEME:moveUnavailableReason(source)
    return {
      id = source.id,
      available = source.id ~= nil,
      name = THEME:moveName(source, session.game.data),
      type = moveType,
      typeLabel = THEME:typeName(moveType, mod.content),
      ppLabel = THEME:translate("PP"),
      ppText = THEME:format("%d/%d", source.pp or maxPp, maxPp),
      powerLabel = THEME:translate("PWR"),
      power = power or 0,
      powerText = (details or compat.isGen2() or displayRuntime.gen3) and hgssRuntime.numberLabel(power) or "--",
      accuracyLabel = THEME:translate("ACC"),
      accuracyText = (details or compat.isGen2() or displayRuntime.gen3) and hgssRuntime.numberLabel(accuracy) or "--",
      stabLabel = "STAB",
      matchupLabel = THEME:translate("MATCHUP"),
      effectiveness = assist("type_hints") and (source.effectiveness or enemyTypes
        and compat.typeEffectiveness(moveType, enemyTypes, session.game.data.type_chart)) or nil,
      disabled = unavailable ~= nil,
      disabledLabel = unavailable and THEME:translate(unavailable),
      disabledLines = unavailable and THEME:descriptionLines(
        source.disabledReason or THEME:translate(unavailable), 34, 3, 196),
      descriptionLines = details and compat.moveInfoLines(source, def,
        battleState() and battleState().ruleset) or {},
    }
  end

  function hgssRuntime.battleMon(detailMove)
    local player = session.battle and session.battle.player or {}
    local def = session.game.data.pokemon[player.species] or {}
    local view = {
      species = player.species, source = player,
      name = player.name or def.name or player.species or "POKEMON",
      types = def.types or {},
      fightLabel = THEME:translate("FIGHT"),
      bagLabel = THEME:translate("BAG"),
      partyLabel = THEME:translate("POKEMON"),
      runLabel = THEME:translate("RUN"),
      moveIndex = customBattleLayout() and session.battle.moveIndex or nil,
      details = assist("move_details"), typeHints = assist("type_hints"),
      moves = {},
    }
    for slot = 1, 4 do
      local move = (session.battle.moves or {})[slot] or {}
      view.moves[slot] = hgssRuntime.moveView(move)
      if detailMove == move or detailMove and detailMove.battleSlot == slot then view.moveIndex = slot end
    end
    return view
  end

  function hgssRuntime.battleStatus(side, source)
    source = source or session.battle and session.battle[side] or nil
    if not source then return nil end
    local def = session.game.data.pokemon[source.species] or {}
    local hp = math.max(0, source.hp or 0)
    local maxHp = source.maxHp or source.stats and source.stats.hp or hp
    local statusId = hp <= 0 and "FNT"
      or THEME:statusName(source.status, mod.content)
    return {
      expProgress = side == "player" and source.expProgress or nil,
      species = source.species,
      id = source.id, absent = source.absent, side = side,
      active = session.battle and session.battle.double and (session.battle.prompt == "menu" or session.battle.prompt == "moves")
        and source.id == session.battle.active,
      source = source,
      name = source.name or def.name or source.species or "POKEMON",
      levelText = THEME:format("L%d", source.level or 0),
      hpLabel = THEME:translate("HP"),
      hp = hp,
      maxHp = math.max(1, maxHp or 1),
      hpText = THEME:format("%d/%d", hp, maxHp or 0),
      statusId = statusId,
      statusLabel = statusId or "",
      caught = side == "enemy" and mod.options:get("caught_icon") ~= false
        and caughtWild(session.battle.kind,
          compat.caughtDex(session.game.save)[source.species]),
    }
  end

  function hgssRuntime.battleStatuses()
    if not (session.battle and session.battle.double) then return nil end
    local rows = {}
    for _, source in ipairs(session.battle.battlers or {}) do
      rows[#rows + 1] = hgssRuntime.battleStatus(source.side, source)
    end
    return rows
  end

  function hgssRuntime.battlePortrait(mon, x, y, size, fainted)
    if not drawSprite(mon.species, "front", x, y, size, size,
        nil, mon.source or mon, true, fainted and 0.48 or nil, nil, "battle") then
      compat.drawPokemonIcon(mon.source or mon, x, y, size,
        fainted and 0.48 or nil)
    end
  end

  function hgssRuntime.battleTeams()
    local playerTeam, enemyTeam = {}, {}
    local function teamState(source)
      source = source or {}
      local mon = source.mon or source
      return {
        alive = (source.shownHP or mon.hp or 0) > 0,
        status = THEME:statusName(source.shownStatus or mon.status, mod.content),
      }
    end
    for slot, mon in ipairs(session.battle.party or {}) do
      playerTeam[slot] = teamState(mon)
    end
    local raw = battleState()
    local enemies = raw and (raw.enemyParty
      or raw.battle and raw.battle.enemyParty) or nil
    if enemies then
      for slot, mon in ipairs(enemies) do
        enemyTeam[slot] = teamState(mon)
      end
    elseif session.battle.enemy then
      enemyTeam[1] = teamState(session.battle.enemy)
    end
    -- The engine computes damage before its HP drain. Team balls must follow
    -- the same displayed battler as the HUD, including both doubles partners.
    local function shownTeam(side, team, party)
      local native = raw and (raw[side] or raw.battle and raw.battle[side])
      for _, shown in ipairs(session.battle.double and session.battle.battlers or { session.battle[side] }) do
        if not session.battle.double or shown.side == side then
          local slot = shown.partyIndex
          if not slot and native then
            for index, mon in ipairs(party or {}) do
              if mon == (native.mon or native) then slot = index; break end
            end
          end
          if slot and team[slot] then team[slot] = teamState(shown) end
        end
      end
    end
    shownTeam("player", playerTeam, session.game.save.party)
    shownTeam("enemy", enemyTeam, enemies)
    if session.battle.kind == "wild" or session.battle.wild then
      local enemy = session.battle.enemy or {}
      local def = session.game.data.pokemon[enemy.species] or {}
      enemyTeam.wild = true
      enemyTeam.name = enemy.name or def.name or enemy.species or "POKEMON"
      enemyTeam.level = enemy.level
    end
    return playerTeam, enemyTeam
  end

  function hgssRuntime.clock()
    local now = os.time()
    local timestamp, period = compat.clockDisplay(session.game,
      mod.options:get("clock_source"), now)
    return clockText(timestamp, mod.options:get("clock_format"),
      mod.datetime:time(session.game, timestamp)), period
  end

  function hgssRuntime.bagView(menu)
    local odds, kinds = {}, {}
    local showCatchOdds = assist("catch_odds")
      and (caughtWild(session.battle.kind, true) or session.battle.wild == true)
    for _, item in ipairs(session.battle.items or {}) do
      local id = tostring(item.id or ""):upper()
      local kind = item.ball and "ball"
        or (id:match("^TM%d") or id:match("^HM%d")) and "machine"
        or (id:find("HEAL", 1, true) or id == "ANTIDOTE"
          or id == "AWAKENING") and "status"
        or item.needsTarget and "medicine" or "item"
      odds[item.id], kinds[item.id] = item.catchChance, kind
    end
    local items = {}
    for index, item in ipairs(menu.items or {}) do
      local label = item.cancel and THEME:translate("CANCEL")
        or item.label or tostring(index)
      local icon = kinds[item.value]
      local upper = tostring(label):upper()
      if upper:match("^TM%d") or upper:match("^HM%d") then
        icon = "machine"
      end
      items[index] = {
        value = item.value, label = label,
        right = item.right, cancel = item.cancel,
        catchChance = showCatchOdds and odds[item.value] or nil,
        catchLabel = THEME:translate("CATCH"), icon = icon or "item",
      }
    end
    return {
      title = menu.title or THEME:translate("BAG"), items = items,
      index = menu.index or 1, categorized = categorizedBag(menu),
      recent = displayRuntime.lastBagItem(),
    }
  end

  hgssRuntime.summaryView = assert(load(mod:read("models/summary_model.lua"),
    "@kanto_gear/models/summary_model.lua"))()({
      summary = compat.summary, theme = THEME, content = mod.content,
      game = function() return session.game end,
      native = function() return displayRuntime.gen3 end,
      progress = progressRatio, assist = assist,
    })

  function hgssRuntime.summaryPortrait(mon, x, y, size, fainted)
    if mon.isEgg then
      compat.drawPokemonIcon(mon.source or mon, x, y, size)
      return
    end
    if not drawSprite(mon.species, "front", x, y, size, size,
        nil, mon.source or mon, true, fainted and 0.48 or nil) then
      compat.drawPokemonIcon(mon.source or mon, x, y, size,
        fainted and 0.48 or nil)
    end
  end

end
