return function(
  THEME, button, displayRuntime, fit, header, hgssRuntime,
  partyCard, partyData, render, session
)
  local function drawParty(list, title, back, activeSpecies, selectedSlot,
                           paged)
    header(THEME:translate(title or "PARTY"),
      back or displayRuntime.home.activeApp ~= nil,
      paged and displayRuntime.home.activeApp == nil)
    if THEME.style == "hgss" then
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:partyBackdrop()
      displayRuntime.PartyPage.draw(THEME.hgss, {
        party = list, selection = session.partyMoveFrom and selectedSlot
          or THEME.hgss.nativeFocus and (selectedSlot or 0) or nil,
        details = paged and not back,
      }, function(slot, x, y, selected, details, focused)
        local mon = list[slot]
        partyCard(mon, x, y, selected or mon and activeSpecies and mon.species == activeSpecies,
          details, focused)
      end)
      render.G.pop()
      return
    end
    for i = 1, 6 do
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
      local mon = list[i]
      partyCard(mon, 3 + col * 78, 23 + row * 39,
                selectedSlot and selectedSlot == i
                  or (not selectedSlot and mon and (mon.active
                    or (activeSpecies and mon.species == activeSpecies))),
                paged and not back)
    end
  end

  local function drawNormalParty()
    local swapCommit = THEME.style == "hgss"
      and hgssRuntime.animation
      and hgssRuntime.animation.kind == "party_swap_commit"
      and hgssRuntime.progress("party_swap_commit")
    if THEME.style == "hgss" and (session.partyMoveFrom or swapCommit) then
      local source = session.partyMoveFrom or hgssRuntime.animation.source
      local list = swapCommit and hgssRuntime.animation.party or partyData()
      header(THEME:translate("SWAP WITH?"), true)
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:partyBackdrop()
      local function drawSwapCard(slot, x, y, selected, details)
        partyCard(list[slot], x, y, selected, details)
      end
      local entering = hgssRuntime.progress("party_swap")
      if entering then
        THEME.hgss:partySwapTransition(drawSwapCard, source, source,
          entering, hgssRuntime.animation.actionCount or 2,
          THEME:translate("STATS"), THEME:translate("SWAP"))
      elseif swapCommit then
        THEME.hgss:partySwapCommitTransition(drawSwapCard,
          hgssRuntime.animation.source, hgssRuntime.animation.target, swapCommit)
      else
        THEME.hgss:partySwap(drawSwapCard, source, source)
      end
      render.G.pop()
      return
    end
    drawParty(partyData(), session.partyMoveFrom and "MOVE WHERE?" or "PARTY",
              session.partyMoveFrom ~= nil,
              nil, session.partyMoveFrom, session.partyMoveFrom == nil)
  end

  local function drawPartyAction()
    local mon = partyData()[session.partyActionSlot]
    if not mon then drawNormalParty(); return end
    if THEME.style == "hgss" then
      local rows = displayRuntime.partyActionRows(session.partyActionSlot)
      local count = #rows
      local offset = THEME.hgss:partyActionOffset(love.timer.getTime())
      header(THEME:translate("PARTY"), true)
      render.G.push()
      render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:partyBackdrop()
      partyCard(mon, 64, THEME.hgss:partyActionHeroY(count)
        + math.floor(offset / 2), true, false, false, false)
      for index, row in ipairs(rows) do
        local x, y, w, h = THEME.hgss:partyActionRow(index, count)
        THEME.hgss:actionRow(x, y, w, h, row.label, row.kind, offset, false, row.sub, row.enabled)
      end
      render.G.pop()
      return
    end
    header(fit(mon.name, 18), true)
    button(14, 37, 132, 38, THEME:translate("STATS"), false)
    if #(session.game.save.party or {}) > 1 then
      button(14, 84, 132, 38, THEME:translate("SWAP"), false)
    end
  end

  local function drawFieldChoice()
    if session.fieldChoice.kind == "fish" then
      header(THEME:translate("CHOOSE ROD"), true)
      if THEME.style == "hgss" then
        render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
        THEME.hgss:rodPicker(session.fieldChoice.action.rods)
        render.G.pop()
        return
      end
      for i, rod in ipairs(session.fieldChoice.action.rods or {}) do
        button(14, 30 + (i - 1) * 37, 132, 32, rod.label, false)
      end
      return
    end
    local choices = session.fieldChoice.kind == "soft_source"
      and session.fieldChoice.action.sources or session.fieldChoice.source.targets
    drawParty(choices, session.fieldChoice.kind == "soft_source"
      and "HEAL WITH" or "HEAL TARGET", true)
  end

  return drawFieldChoice, drawNormalParty, drawParty, drawPartyAction
end
