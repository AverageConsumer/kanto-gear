return function(
  THEME, assist, battleState, box, centered, chanceLabel,
  compat, displayRuntime, effectLabel, fit, header, hgssRuntime,
  mod, outline, render, screenContract, session, text
)
  -- Game path [Gen 2/3 vs Gen 1]: prefer native move descriptions; unknown Gen 3 effects stay unknown rather than using Gen 1 inference.
  function compat.moveInfoLines(move, def, ruleset)
    if (compat.isGen2() or def.nativeGen3) and type(def.description) == "string"
        and #def.description > 0 then
      local lines = THEME:descriptionLines(def.description, 21, 2, 196)
      if #lines > 0 then return lines end
    end
    if def.nativeGen3 then return { THEME:translate("NO DETAILS AVAILABLE") }, false end
    return THEME:moveDescription(move, def, ruleset)
  end

  function compat.moveInfoEntry(move)
    if type(move) ~= "table" then move = { id = move } end
    if not move.id then return nil end
    local entry = {}
    for key, value in pairs(move) do entry[key] = value end
    local def = session.game and session.game.data and session.game.data.moves
      and session.game.data.moves[entry.id] or {}
    if entry.pp == nil then entry.pp = def.pp or 0 end
    if entry.maxPp == nil then entry.maxPp = def.pp or entry.pp end
    return entry
  end

  function hgssRuntime.summaryMove(summary, index)
    local view = compat.summary.view(summary, session.game)
    local source = view and view.mon and view.mon.moves
      and view.mon.moves[index]
    local entry = compat.moveInfoEntry(source)
    if entry and view.moves and view.moves[index] then
      entry.maxPp = view.moves[index].maxPp or entry.maxPp
      entry.summarySlot = index
    end
    return entry, view
  end

  local function drawMoveInfo(move)
    if THEME.style == "hgss" and session.battle and session.battle.prompt == "moves" then
      local mon = hgssRuntime.battleMon(move)
      local playerTeam, enemyTeam = hgssRuntime.battleTeams()
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      local selected = mon.moves[mon.moveIndex] or mon.moves[1] or {}
      THEME.hgss:battleMoveInfo(selected,
        THEME.hgss:moveHasStab(mon, selected), playerTeam, enemyTeam)
      render.G.pop()
      return
    end
    local def = session.game and session.game.data and session.game.data.moves
      and session.game.data.moves[move.id] or {}
    local raw = battleState()
    local lines = compat.moveInfoLines(move, def, raw and raw.ruleset)
    local power = move.displayPower
    if power == nil then power = move.power or def.power end
    if power == 0 then power = nil end
    local accuracy = move.hitChance
    if accuracy == nil then accuracy = move.accuracy or def.accuracy end
    local summary = displayRuntime.summaryContext()
    if THEME.style == "hgss" and summary then
      if summary.page == 4 then
        local mon = hgssRuntime.summaryView(summary)
        header(THEME:translate("CONTEST MOVES"), true)
        render.G.push()
        render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        THEME.hgss:summaryContestInfo(mon.moves[move.summarySlot or 1])
        render.G.pop()
        return
      end
      local _, view = hgssRuntime.summaryMove(summary,
        summary.moveIndex or 1)
      local moveType = move.type or def.type
      local enemy = session.battle and session.battle.enemy
      local enemyDef = enemy and session.game.data.pokemon
        and session.game.data.pokemon[enemy.species]
      local enemyTypes = enemy and enemy.types
        or enemyDef and enemyDef.types
      local info = {
        name = THEME:moveName(move, session.game and session.game.data),
        type = moveType,
        typeLabel = THEME:typeName(moveType, mod.content),
        ppLabel = THEME:translate("PP"),
        ppText = THEME:format("%d/%d", move.pp or 0, move.maxPp or 0),
        power = power or 0,
        powerLabel = THEME:translate("PWR"),
        powerText = power and tostring(power) or "--",
        accuracyLabel = THEME:translate("ACC"),
        accuracyText = accuracy and tostring(accuracy) or "--",
        stabLabel = "STAB",
        matchupLabel = THEME:translate("MATCHUP"),
        effectiveness = assist("type_hints") and compat.typeEffectiveness(
          moveType, enemyTypes, session.game.data.type_chart) or nil,
        descriptionLines = lines,
      }
      header(THEME:translate("MOVES"), true)
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:battleMoveInfoBody(info,
        assist("type_hints") and THEME.hgss:moveHasStab({ types = view and view.types }, info))
      render.G.pop()
      return
    end
    if THEME.style == "hgss" then
      local learn = displayRuntime.moveLearnScreen()
      local owner = learn and learn.mon
        or raw and screenContract(raw, "forget")
      local ownerDef = owner and session.game.data.pokemon[owner.species] or {}
      local ownerTypes = owner and (owner.types or ownerDef.types) or {}
      local enemy = session.battle and session.battle.enemy
      local enemyDef = enemy and session.game.data.pokemon[enemy.species] or {}
      local enemyTypes = enemy and (enemy.types or enemyDef.types)
      local info = hgssRuntime.moveView(move, enemyTypes)
      header(info.name, true)
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:battleMoveInfoBody(info,
        assist("type_hints") and THEME.hgss:moveHasStab({ types = ownerTypes }, info))
      render.G.pop()
      return
    end
    header(fit(THEME:moveName(move, session.game and session.game.data), 12), true)
    box("fill", 12, 25, 136, 112, render.MID)
    outline(12, 25, 136, 112, render.INK)
    centered(THEME:typeName(def.type or move.type, mod.content), 33, render.INK, 2,
      true)
    text(THEME:translate("POWER"), 20, 54, render.DARK)
    text(tostring(power or "--"), 20, 65, render.INK)
    text(THEME:translate("HIT"), 69, 54, render.DARK)
    text(chanceLabel(accuracy), 61, 65, render.INK)
    text(THEME:translate("PP"), 121, 54, render.DARK)
    text(("%d/%d"):format(move.pp or 0, move.maxPp or 0), 108, 65, render.INK)
    if assist("type_hints") then
      text(THEME:translate("MATCHUP"), 25, 83, render.DARK)
      text(effectLabel(move.effectiveness), 112, 83, render.INK)
    end
    box("fill", 19, 95, 122, 1, render.DARK)
    if lines[2] then
      centered(lines[1], 103, render.INK)
      centered(lines[2], 116, render.INK)
    else
      centered(lines[1], 110, render.INK)
    end
  end

  return drawMoveInfo
end
