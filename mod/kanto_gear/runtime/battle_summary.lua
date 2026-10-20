return function(
  Discovery, THEME, battleState, bottomOwnsBattleUI, box, button,
  centered, compat, customBattleLayout, displayRuntime, drawSprite, fit,
  hasDisplay, header, hgssRuntime, hpBar, mod, render,
  screenById, session, text
)
  function displayRuntime.summaryContext(native)
    if THEME.style ~= "hgss" or not session.game then return native end
    local localState = displayRuntime.localSummary
    if localState then
      if session.battle or (session.game.save.party or {})[localState.slot] ~= localState.mon then
        displayRuntime.localSummary, session.moveInfo, session.dirty = nil, nil, true
      elseif session.game.stack:top() == session.game.world or session.game.stack:top() == session.game.overworld then
        return compat.summary.configure(localState, Discovery.current())
      end
    end
    if native and native.screenId == "GearSummaryMenu" then native = native.owner end
    native = native or screenById("summary")
    if not native or session.game.stack:top() ~= native or not (compat.summary.supports(native)
        or compat.summary.details.isEgg(native.mon) and not native.moveDetail) then
      displayRuntime.nativeSummary = nil
      return nil
    end
    local state = displayRuntime.nativeSummary
    if not state or state.owner ~= native or state.mon ~= native.mon then
      state = compat.summary.inspection(native.mon, session.game, displayRuntime.gen3 and 3
        or compat.isGen2() and 2 or 1, native.pages == 4)
      state.owner = native
      displayRuntime.nativeSummary = state
    end
    state.hardwareFocus = session.battle and not session.battle.nativeInputLocked and
      (displayRuntime.gen3 and displayRuntime.gen3Presentation
        and displayRuntime.gen3Presentation.owns("menu")
        or bottomOwnsBattleUI(customBattleLayout(), session.active,
          hasDisplay(), session.displayReady, battleState(), session.battle)) or false
    return compat.summary.configure(state, Discovery.current())
  end

  local function drawBattleSummary(summary)
    if THEME.style == "hgss" then
      summary = displayRuntime.summaryContext(summary)
      if not summary then return end
      local mon, view = hgssRuntime.summaryView(summary)
      if not mon then return end
      header(THEME:translate("POKEMON"), true)
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      displayRuntime.SummaryPage.draw(THEME.hgss, summary, mon,
        hgssRuntime.summaryPortrait, function(value) return THEME:translate(value) end)
      render.G.pop()
      return
    end
    local view = compat.summary.view(summary, session.game)
    local mon, def = view.mon, view.def
    local page, level = view.page, view.level
    header(THEME:format("STATS %d/%d", page, view.pages), true)
    if view.contest then
      for slot = 1, 4 do
        local row, contest = view.moves[slot], view.contest[slot]
        local y = 25 + (slot - 1) * 24
        text(fit(row.name, 22), 7, y, render.INK)
        if contest then text(fit(THEME:translate(contest.category) .. " " .. contest.appeal .. "/" .. contest.jam, 24), 7, y + 11, render.DARK) end
      end
    -- Game path [Gen 1/2/3]: native Summary order and available fields differ; view.gen2 includes Gen 3 split-Special/held-item capability.
    elseif view.gen3 and page == 1 then
      centered(view.name, 25, render.INK)
      centered(THEME:translate("NATURE") .. ": " .. displayRuntime.gen3:plainText(view.nature), 41, render.INK)
      centered(THEME:translate("ABILITY") .. ": " .. displayRuntime.gen3:plainText(view.ability), 55, render.INK)
      local lines = THEME:wrapText(displayRuntime.gen3:plainText(view.abilityDescription), 146, 3)
      for i, line in ipairs(lines) do centered(line, 70 + (i - 1) * 11, render.DARK) end
      text(THEME:format("OT %s", fit(view.ot, 12)), 7, 112, render.DARK)
      text(THEME:format("EXP %d", view.experience), 7, 126, render.DARK)
    elseif not view.gen2 and page == 1 then
      local stats = view.stats
      local function typeName(index)
        local id = view.types[index]
        return id and THEME:typeName(id, mod.content) or "--"
      end
      drawSprite(mon.species, "front", 4, 23, 43, 43,
                 nil, mon.source or mon)
      text(fit(view.name, 17), 51, 24, render.INK)
      text(THEME:format("NO.%03d LV.%d", view.dex, level),
           51, 36, render.DARK)
      text(THEME:format("HP %d/%d", view.hp, view.maxHp),
           51, 48, render.INK)
      hpBar(51, 59, 105, view.hp, view.maxHp)
      text(THEME:format("STATUS %s",
        THEME:statusName(view.status, mod.content)
          or THEME:translate("OK")), 51, 65, render.DARK)
      box("fill", 4, 76, 152, 1, render.DARK)
      text(THEME:format("ATK %d", stats.attack or 0), 5, 81, render.INK)
      text(THEME:format("DEF %d", stats.defense or 0), 5, 92, render.INK)
      text(THEME:format("SPD %d", stats.speed or 0), 5, 103, render.INK)
      text(THEME:format("SPC %d", stats.special or 0), 5, 114, render.INK)
      text(THEME:format("TYPE1 %s", typeName(1)), 77, 81, render.DARK)
      text(THEME:format("TYPE2 %s", typeName(2)), 77, 92, render.DARK)
      text(THEME:format("OT %s",
        fit(view.ot, 10)), 77, 103, render.DARK)
      text(THEME:format("ID %05d", view.otId),
           77, 114, render.DARK)
    elseif not view.gen2 then
      text(fit(view.name, 17), 5, 25, render.INK)
      text(THEME:format("LV.%d", level), 116, 25, render.DARK)
      text(THEME:format("EXP %d", view.experience), 5, 39, render.DARK)
      if level < 100 then
        local growth = def.growthRate
          and type(def.growthRate) == "string" and mod.content.growth_rates:get(def.growthRate)
          or mod.content.growth_rates:get("MEDIUM_FAST")
        local nextExp = math.max(0,
          (growth and growth.expForLevel
            and growth.expForLevel(level + 1) or 0) - view.experience)
        text(THEME:format("NEXT L.%d %d", level + 1, nextExp), 5, 51, render.DARK)
      else
        text(THEME:translate("NEXT MAX"), 5, 51, render.DARK)
      end
      box("fill", 4, 61, 152, 1, render.DARK)
      for i = 1, 4 do
        local move = view.moves[i]
        local y = 66 + (i - 1) * 14
        text(fit(move.name, 14), 6, y, render.INK)
        text(move.pp and THEME:format("PP %d/%d", move.pp, move.maxPp)
          or "PP --", 103, y, render.DARK)
      end
    elseif page == 1 then
      local status = THEME:statusName(view.status, mod.content)
        or THEME:translate("OK")
      if (tonumber(mon.pokerus) or 0) % 16 > 0 then status = "PKRS" end
      drawSprite(mon.species, "front", 4, 23, 43, 43,
                 nil, mon.source or mon)
      text(fit(view.name, 17), 51, 24, render.INK)
      text(THEME:format("NO.%03d LV.%d", view.dex, level), 51, 36, render.DARK)
      text(THEME:format("HP %d/%d", view.hp, view.maxHp), 51, 48, render.INK)
      hpBar(51, 59, 105, view.hp, view.maxHp)
      text(THEME:format("STATUS %s", status), 51, 65, render.DARK)
      box("fill", 4, 76, 152, 1, render.DARK)
      text(THEME:format("TYPE1 %s",
        THEME:typeName(view.types[1], mod.content)), 5, 82, render.DARK)
      text(THEME:format("TYPE2 %s", view.types[2]
        and THEME:typeName(view.types[2], mod.content) or "--"), 5, 94, render.DARK)
      text(THEME:format("EXP %d", view.experience), 77, 82, render.DARK)
      if level < 100 then
        text(THEME:format("NEXT L.%d", level + 1), 77, 94, render.DARK)
        text(tostring(view.nextExp or 0), 77, 105, render.DARK)
      else
        text(THEME:translate("NEXT MAX"), 77, 94, render.DARK)
      end
    elseif view.gen3 and page == 3 or not view.gen3 and page == 2 then
      text(fit(view.name, 17), 5, 25, render.INK)
      text(THEME:format("LV.%d", level), 116, 25, render.DARK)
      text(THEME:format("ITEM %s", fit(view.item or "---", 18)), 5, 39, render.DARK)
      box("fill", 4, 51, 152, 1, render.DARK)
      for i = 1, 4 do
        local move = view.moves[i]
        local y = 57 + (i - 1) * 16
        text(fit(move.name, 14), 6, y, render.INK)
        text(move.pp and THEME:format("PP %d/%d", move.pp, move.maxPp)
          or "PP --", 103, y, render.DARK)
      end
    else
      local stats = view.stats
      text(fit(view.name, 17), 5, 25, render.INK)
      text(THEME:format("LV.%d", level), 116, 25, render.DARK)
      text(THEME:format("OT %s", fit(view.ot, 11)), 5, 39, render.DARK)
      text(THEME:format("ID %05d", view.otId), 96, 39, render.DARK)
      box("fill", 4, 51, 152, 1, render.DARK)
      local rows = { { "ATK", stats.attack }, { "DEF", stats.defense },
        { "SP.ATK", stats.specialAttack },
        { "SP.DEF", stats.specialDefense }, { "SPEED", stats.speed } }
      for i, row in ipairs(rows) do
        local y = 57 + (i - 1) * 13
        text(THEME:translate(row[1]), 16, y, render.DARK)
        text(("%3d"):format(row[2] or 0), 120, y, render.INK)
      end
    end
    button(103, 125, 53, 15,
      THEME:translate(page < view.pages and "NEXT" or "CLOSE"), false)
  end

  return drawBattleSummary
end
