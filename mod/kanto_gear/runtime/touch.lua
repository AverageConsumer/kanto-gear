return function(
  HEADER, THEME, areaData, assist, back, canFly,
  carouselSubpage, changePage, compat, currentBattleUIMode, dialogueChoice, displayRuntime,
  flyTargets, guideData, hasItemfinder, hgssRuntime, inside, loadLocalMap,
  mod, partyData, partySlotAt, pcSession, press, screenById,
  screenContract, screenState, session, tapBattle, tapDialogueChoice, tapFieldChoice,
  tapLearn, tapNaming, tapPc, textTouch, useTool
)
  function displayRuntime.tapSummary(summary, x, y)
    local state = displayRuntime.summaryContext(summary)
    if not state then return end
    local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
    if hy < 28 and hx < 27 then displayRuntime.summaryInput(state, "b"); return end
    local action, value = displayRuntime.SummaryPage.hit(state, hx, hy)
    if action == "page" then
      state.page, session.moveInfo, session.dirty = value, nil, true
    elseif action == "move" and (assist("move_details") or state.page == 4) then
      local selected = hgssRuntime.summaryMove(state, value)
      if selected then session.moveInfo, session.dirty = selected, true end
    end
  end

  local function tap(x, y)
    if displayRuntime.noticeTap and displayRuntime.noticeTap(x, y) then return end
    if session.battle and currentBattleUIMode() == "info" then
      tapBattle(x, y)
      return
    end
    if session.battle and session.battle.nativeInputLocked then return end
    if session.moveInfo then
      if y < HEADER and x < 24 then back() end
      return
    end
    local startMenu = displayRuntime.startMenu()
    if startMenu then
      displayRuntime.tapStartMenu(startMenu, x, y)
      return
    end
    if displayRuntime.homeHelpActive() then
      displayRuntime.tapHomeHelp(x * THEME.hgssScale, y * THEME.hgssScale)
      return
    end
    local summary = displayRuntime.summaryContext()
    if THEME.style == "hgss" and summary then
      displayRuntime.tapSummary(summary, x, y)
      return
    end
    local choice, labels, field = dialogueChoice()
    local learnScreen = screenById("MoveLearnMenu")
      or screenById("Gen2MoveDeleter")
    local learn = displayRuntime.moveLearnScreen()
    local learningChoice = choice and displayRuntime.learningChoiceContext(choice)
    if learningChoice and THEME.style == "hgss" then
      displayRuntime.tapLearningPrompt(learningChoice, choice, labels, nil, field, x, y)
      return
    elseif learn and not choice then
      tapLearn(learn, session.game.stack:top(), x, y)
      return
    end
    local fieldPp = displayRuntime.fieldPpMoveScreen()
    if fieldPp then
      displayRuntime.tapPpItemMoves(fieldPp, x, y)
      return
    elseif learnScreen and not choice then
      return
    end
    local battleTop = session.game and session.game.stack and session.game.stack:top()
    local levelMon = compat.levelUpMon(battleTop)
      or displayRuntime.levelUp:fieldMon(battleTop)
    if levelMon then
      if THEME.style == "hgss" then
        if THEME.hgss:levelUpHit(x * THEME.hgssScale,
            y * THEME.hgssScale) then press("a") end
      else
        local buttonY = levelMon.stats and (levelMon.stats.specialAttack ~= nil
          or levelMon.stats.specialDefense ~= nil) and 111 or 108
        if inside(x, y, 24, buttonY, 112, 27) then press("a") end
      end
      return
    end
    local fieldParty, fieldPartyData = displayRuntime.fieldBagParty()
    if fieldParty then
      if y < HEADER and x < 24 then
        press("b")
      else
        local slot = THEME.style == "hgss"
          and THEME.hgss:partySlot(x, y, #fieldPartyData)
          or partySlotAt(x, y, #fieldPartyData)
        if slot then
          fieldParty.index = slot
          displayRuntime.bag.pending.mon = fieldPartyData[slot]
          press("a")
        end
      end
      session.dirty = true
      return
    end
    if choice then
      tapDialogueChoice(choice, labels, x, y, field)
      return
    end
    local mode, top = screenState()
    local namingKeys = screenContract(top, "naming")
    if namingKeys then
      tapNaming(top, namingKeys, x, y)
      return
    elseif compat.isScreen(top, "naming") then
      return
    end
    if mode == "title" then
      press("a")
      return
    end
    if session.battle then
      tapBattle(x, y)
      return
    end
    if mode == "textbox" then
      if textTouch(top) == "advance" then press("a") end
      return
    end
    local pcKind, pcRoot = pcSession()
    if pcKind then
      tapPc(pcKind, pcRoot, top, x, y)
      return
    end
    if mode ~= "active" then return end
    if THEME.style == "hgss" and (session.page == "POKEGEAR" or session.page == "POKENAV") then
      displayRuntime.tapDeviceApp(x * THEME.hgssScale, y * THEME.hgssScale)
      return
    end
    if THEME.style == "hgss" and session.page == "HOME" then
      displayRuntime.tapHome(x * THEME.hgssScale, y * THEME.hgssScale)
      return
    elseif THEME.style == "hgss" and session.page == "STORE" then
      displayRuntime.tapStore(x * THEME.hgssScale, y * THEME.hgssScale)
      return
    elseif THEME.style == "hgss" and session.page == "POKEDEX" then
      displayRuntime.tapPokedex(x, y)
      return
    elseif THEME.style == "hgss" and session.page == "ACHIEVEMENTS" then
      displayRuntime.tapAchievements(x * THEME.hgssScale, y * THEME.hgssScale)
      return
    elseif THEME.style == "hgss" and session.page == "NOTES" then
      displayRuntime.notesPointer("tap", x * THEME.hgssScale, y * THEME.hgssScale)
      return
    elseif THEME.style == "hgss" and session.page == "DAYCARE" then
      displayRuntime.tapDaycare(x * THEME.hgssScale, y * THEME.hgssScale)
      return
    elseif THEME.style == "hgss" and session.page == "CALENDAR" and displayRuntime.tapCalendar then
      displayRuntime.tapCalendar(x * THEME.hgssScale, y * THEME.hgssScale)
      return
    elseif THEME.style == "hgss" and session.page == "SHINY" then
      displayRuntime.tapShinyHunt(x * THEME.hgssScale, y * THEME.hgssScale)
      return
    elseif THEME.style == "hgss" and session.page == "PSS" then
      if y * THEME.hgssScale < 30 and x * THEME.hgssScale < 27 then
        if displayRuntime.pss.selected then displayRuntime.pss:action("back")
        else
          session.page, displayRuntime.home.activeApp = "HOME", nil
        end
      else displayRuntime.pss:hit(x * THEME.hgssScale, y * THEME.hgssScale) end
      session.dirty = true
      return
    elseif THEME.style == "hgss" and session.page == "BAG" then
      displayRuntime.tapBag(x, y)
      return
    elseif THEME.style == "hgss" and session.page == "SETTINGS" then
      displayRuntime.tapSettings(x * THEME.hgssScale, y * THEME.hgssScale)
      return
    end
    if session.partyActionSlot then
      local slot = session.partyActionSlot
      local mon = session.game.save.party and session.game.save.party[slot]
      local canSwap = mon and #(session.game.save.party or {}) > 1
        and mod.world and mod.world.canReorderParty
        and mod.world:canReorderParty()
      if THEME.style == "hgss" and THEME.hgss.partyActionClosing then return end
      local rows = THEME.style == "hgss" and displayRuntime.partyActionRows(slot) or {}
      local index = THEME.style == "hgss" and THEME.hgss:partyActionAt(
        x * THEME.hgssScale, y * THEME.hgssScale, #rows)
      local row = index and rows[index]
      local action = row and (row.id == "stats" and 1 or row.id == "swap" and 2 or row.id)
      if y < HEADER and x < 24 then
        if THEME.style == "hgss" then
          THEME.hgss:endPartyAction(love.timer.getTime())
        else
          session.partyActionSlot = nil
        end
      elseif mon and (action == 1
          or THEME.style ~= "hgss" and inside(x, y, 14, 37, 132, 38)) then
        displayRuntime.openPartySummary(slot)
      elseif canSwap and (action == 2
          or THEME.style ~= "hgss" and inside(x, y, 14, 84, 132, 38)) then
        if THEME.style == "hgss" then
          hgssRuntime.beginAnimation("party_swap", {
            source = slot, actionCount = 2,
          })
        end
        session.partyActionSlot, session.partyMoveFrom = nil, slot
      elseif mon and action == "item" and row.enabled ~= false then
        if displayRuntime.openHeldItem(slot) then session.partyActionSlot = nil end
      end
      session.dirty = true
      return
    end
    if session.radarOpen then
      if y < HEADER and x < 24 then
        session.radarOpen = false
      else
        session.radarFrame, session.radarStarted = 0, love.timer.getTime()
      end
      session.dirty = true
      return
    end
    if session.fieldChoice then
      tapFieldChoice(x, y)
      return
    end
    if session.pendingFly then
      local yes, no = inside(x, y, 18, 91, 58, 27),
        inside(x, y, 84, 91, 58, 27)
      if THEME.style == "hgss" then
        local choice = THEME.hgss:toolPromptHit(x * THEME.hgssScale,
          y * THEME.hgssScale)
        yes, no = choice == true, choice == false
      end
      if yes then
        local target = session.pendingFly
        session.pendingFly = nil
        displayRuntime.flyRegionTarget(target)
        session.dirty = true
      elseif no then
        session.pendingFly, session.dirty = nil, true
      end
      return
    end
    if session.pendingAction then
      if THEME.style == "hgss" then
        local choice = THEME.hgss:toolPromptHit(x * THEME.hgssScale,
          y * THEME.hgssScale)
        if choice ~= nil then
          local action = session.pendingAction
          session.pendingAction = nil
          if choice then useTool(action) else session.dirty = true end
        end
        return
      end
      if inside(x, y, 18, 91, 58, 27) then
        local action = session.pendingAction
        session.pendingAction = nil
        useTool(action)
      elseif inside(x, y, 84, 91, 58, 27) then
        session.pendingAction, session.dirty = nil, true
      end
      return
    end
    if displayRuntime.guideDetail then
      if y < HEADER and x < 22 then
        displayRuntime.guideDetail = nil
      elseif y < HEADER and displayRuntime.guideDetail.page then
        local guide, row = guideData()
        for _, candidate in ipairs(guide.rows) do
          if candidate.species == displayRuntime.guideDetail.species then
            row = candidate break
          end
        end
        if row and row.detailPages > 1 then
          local nextPage
          if x >= 22 and x < 48 then
            nextPage = carouselSubpage(
              displayRuntime.guideDetail.page, row.detailPages, -1)
          elseif x >= 80 and x < 106 then
            nextPage = carouselSubpage(
              displayRuntime.guideDetail.page, row.detailPages, 1)
          end
          if nextPage then displayRuntime.guideDetail.page = nextPage end
        end
      end
      session.dirty = true
      return
    end
    if THEME.style == "hgss" and session.page == "STEPS" then
      if y < HEADER and x < 22 then
        session.page, displayRuntime.home.activeApp = "HOME", nil
        session.dirty = true
      elseif THEME.hgss:stepsHit(x, y) == "reset" then
        session.steps = 0
        mod.save:set("steps", session.steps)
        session.dirty = true
        mod.log:info("step counter reset")
      end
      return
    end
    if session.trainerStepsOpen then
      if y < HEADER and x < 22 then
        session.trainerStepsOpen, session.dirty = false, true
      elseif inside(x, y, 34, 105, 92, 28) then
        session.steps = 0
        mod.save:set("steps", session.steps)
        session.dirty = true
        mod.log:info("step counter reset")
      end
      return
    end
    if THEME.style == "hgss" and session.page == "TRAINER" then
      local context = displayRuntime.trainerContext()
      local action = displayRuntime.TrainerPage.hit(x * THEME.hgssScale, y * THEME.hgssScale, context.pages)
      if action == "back" then session.page, displayRuntime.home.activeApp, session.dirty = "HOME", nil, true
      elseif type(action) == "number" then displayRuntime.cycleTrainer(action) end
      return
    end
    if THEME.style == "hgss" and session.page == "POKEDEX" then
      displayRuntime.tapPokedex(x, y)
      return
    end
    if THEME.style == "hgss" and displayRuntime.home.activeApp
        and y < HEADER and x < 22
        and not (session.page == "LOCAL" and (displayRuntime.explorer.selected
          or displayRuntime.explorer.view
          or displayRuntime.explorer.mapFull)) then
      session.page, displayRuntime.home.activeApp, session.dirty = "HOME", nil, true
      return
    end
    if y < HEADER and not session.partyMoveFrom then
      if THEME.style == "hgss" and session.page == "TOOLS" then
        local view = displayRuntime.toolsView()
        local action = THEME.hgss:toolsHit(x * THEME.hgssScale, y * THEME.hgssScale, view)
        if action == "prev" or action == "next" then
          local direction = action == "next" and 1 or -1
          displayRuntime.requestPageMotion(direction)
          session.tools.page = ((session.tools.page or 1) - 1 + direction) % view.pages + 1
          session.toolArmed, session.dirty = nil, true
        end
        return
      end
      if x < 22 then changePage(-1)
      elseif x >= 74 and x < 96 then changePage(1) end
      if session.page == "TOOLS" and x >= 22 and x < 74 and #session.tools > 6 then
        local pages = math.ceil(#session.tools / 6)
        session.tools.page = (session.tools.page or 1) % pages + 1
        session.dirty = true
      end
      return
    end
    if session.page == "LOCAL" and THEME.style == "hgss" then
      if displayRuntime.explorer.locationPreview then
        local action = THEME.hgss:achievementsHit(x * 1.5, y * 1.5)
        if action == "location_scope" then
          local preview = displayRuntime.explorer.locationPreview
          preview.locationPoint = preview.locationPoint == preview.location and preview.locationEntrance or preview.location
          session.dirty = true
        end
        return
      end
      local overview = loadLocalMap()
      if not overview then return end
      local model = displayRuntime.explorerModel(overview)
      local action, slot = THEME.hgss:explorerHit(x, y, model)
      if action == "wild" or action == "items" or action == "trainers" then
        displayRuntime.explorer.view = action
        displayRuntime.explorer.selected, displayRuntime.explorer.page,
          displayRuntime.explorer.detailPage = nil, 1, 1
      elseif action == "map_toggle" then
        displayRuntime.explorer.mapFull = not displayRuntime.explorer.mapFull
      elseif action == "zoom_out" or action == "zoom_in" then
        displayRuntime.adjustExplorerZoom(action == "zoom_in" and 1 or -1)
      elseif action == "next" or action == "prev" then
        local direction = action == "next" and 1 or -1
        displayRuntime.requestPageMotion(direction)
        displayRuntime.explorer.page = ((displayRuntime.explorer.page - 1
          + direction) % model.pages) + 1
        displayRuntime.explorer.selected = nil
      elseif action == "detail_next" or action == "detail_prev" then
        local direction = action == "detail_next" and 1 or -1
        displayRuntime.requestPageMotion(direction)
        displayRuntime.explorer.detailPage =
          ((displayRuntime.explorer.detailPage - 1 + direction)
            % model.detailPages) + 1
      elseif action == "wild_here" or action == "wild_route" then
        model.filters.wildScope = action == "wild_here" and "HERE" or "ROUTE"
        displayRuntime.explorer.page, displayRuntime.explorer.selected = 1, nil
      elseif action == "player_scan" then
        displayRuntime.explorer.scanFrame = 0
        displayRuntime.explorer.scanStarted = love.timer.getTime()
        displayRuntime.explorer.scanHintSeen = true
      elseif action == "marker" and model.markers[slot]
          and model.markers[slot].source then
        displayRuntime.explorer.view = model.markers[slot].kind == "trainer"
          and "trainers" or model.markers[slot].kind == "fruit" and "fruit"
          or model.markers[slot].kind == "pokemon" and "wild" or "items"
        displayRuntime.explorer.selected = model.markers[slot].source.key
        displayRuntime.explorer.detailPage = 1
        displayRuntime.explorer.mapFull = false
      elseif action == "locate" and model.selected and model.selected.remote then
        displayRuntime.openExplorerLocation(model.selected)
      elseif action == "row" and model.rows[slot] then
        displayRuntime.explorer.view = model.view or "wild"
        displayRuntime.explorer.selected = model.rows[slot].key
        displayRuntime.explorer.detailPage = 1
      end
      session.dirty = true
      return
    end
    if session.page == "LOCAL" and assist("area_map") and inside(x, y, 126, 18, 34, 30) then
      session.localMapZoom = session.localMapZoom % 3 + 1
      session.dirty = true
      return
    end
    if session.page == "MAP" and THEME.style == "hgss" then
      displayRuntime.tapRegionMap(x, y)
      return
    end
    if session.page == "MAP" and canFly() then
      local best, distance
      local targets = flyTargets()
      for _, target in ipairs(targets or {}) do
        local d = (x - target.x) ^ 2 + (y - target.y) ^ 2
        if d <= 144 and (not distance or d < distance) then
          best, distance = target, d
        end
      end
      if best then session.pendingFly, session.dirty = best, true end
      return
    end
    if session.page == "GUIDE" and y >= 48 and y < 141 then
      local guide = guideData()
      local slot = math.floor((y - 48) / 31) + 1
      local row = guide.rows[(session.guidePage - 1) * 3 + slot]
      if row then
        displayRuntime.guideDetail, session.dirty = { species = row.species, page = 1 }, true
      end
      return
    elseif session.page == "AREA" and assist("item_radar") then
      local area = areaData()
      local screen = area.screens[math.max(1, math.min(session.areaPage, area.pages))]
      if screen.name == "HIDDEN" and hasItemfinder()
          and inside(x, y, 20, 118, 120, 20) then
        session.radarOpen, session.radarFrame, session.radarStarted = true, 0, love.timer.getTime()
        session.dirty = true
      end
      return
    elseif session.page == "TRAINER" and THEME.style ~= "hgss"
        and inside(x, y, 82, 109, 74, 29) then
      session.trainerStepsOpen = true
      session.dirty = true
    elseif session.page == "PARTY" then
      if session.partyMoveFrom and y < HEADER and x < 24 then
        session.partyMoveFrom, session.dirty = nil, true
        return
      end
      local party = session.game.save.party or {}
      local slot = THEME.style == "hgss"
        and THEME.hgss:partySlot(x, y, #party)
        or partySlotAt(x, y, #party)
      local mon = slot and party[slot]
      if mon and session.partyMoveFrom then
        local from = session.partyMoveFrom
        if THEME.style == "hgss" and from ~= slot then
          hgssRuntime.beginAnimation("party_swap_commit", {
            source = from, target = slot, party = partyData(),
            duration = 0.26,
          })
        end
        session.partyMoveFrom = nil
        local ok, err = mod.world:reorderParty(from, slot)
        if not ok then
          mod.log:warn("party reorder rejected: %s", tostring(err))
        end
        session.dirty = true
      elseif mon then
        session.partyActionSlot, session.dirty = slot, true
        if THEME.style == "hgss" then
          THEME.hgss:beginPartyAction(love.timer.getTime())
        end
      end
    elseif session.page == "TOOLS" then
      if THEME.style == "hgss" then
        local view = displayRuntime.toolsView()
        local actions = view.actions
        local action, index, rodIndex = THEME.hgss:toolsHit(x * THEME.hgssScale,
          y * THEME.hgssScale, view)
        local model = index and actions[index]
        local armed = view.armed
        -- Any other tap releases a waiting location move; it never fires late.
        if session.toolArmed then session.toolArmed, session.dirty = nil, true end
        if action == "prev" or action == "next" then
          local direction = action == "next" and 1 or -1
          displayRuntime.requestPageMotion(direction)
          session.tools.page = ((session.tools.page or 1) - 1 + direction) % view.pages + 1
          session.dirty = true
        elseif action == "rod" then
          local rod = model.rods[rodIndex]
          if rod then displayRuntime.activateTool(model.action, rod.id) end
        elseif action == "action" and model.radar then
          session.radarOpen, session.radarFrame, session.radarStarted = true, 0, love.timer.getTime()
          session.dirty = true
        elseif action == "action" and (model.id == "dig" or model.id == "teleport")
            and armed ~= model.id then
          -- Location moves leave the area, so they ask for a second tap in
          -- place instead of opening a dialog.
          session.toolArmed, session.dirty = { id = model.id, key = session.toolsKey }, true
        elseif action == "action" then
          displayRuntime.activateTool(model.action, nil, true)
        end
        return
      end
      local first = ((session.tools.page or 1) - 1) * 6 + 1
      local count = math.min(6, #session.tools - first + 1)
      for slot = 1, count do
        local action = session.tools[first + slot - 1]
        local col, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
        if inside(x, y, 3 + col * 78, 25 + row * 38, 76, 34) then
          displayRuntime.activateTool(action)
          break
        end
      end
    end
  end

  displayRuntime.explorerSwipeTarget = function(view, selected, y, pages)
    if not view then return end
    if selected then return y >= 99 and "detail" or nil end
    if view == "wild" then
      return y >= 140 and ((pages or 1) > 1 and "page" or "scope") or nil
    end
  end
  assert(displayRuntime.explorerSwipeTarget("wild", false, 160, 1) == "scope"
      and displayRuntime.explorerSwipeTarget("wild", false, 160, 2) == "page"
      and not displayRuntime.explorerSwipeTarget("wild", false, 139)
      and displayRuntime.explorerSwipeTarget("wild", true, 99) == "detail",
    "Explorer horizontal swipe regions")

  return tap
end
