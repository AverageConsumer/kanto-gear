return function(
  THEME, assist, box, compactSteps, compat, displayRuntime,
  drawSprite, expBar, fit, guideData, header, hpBar,
  loadLocalMap, mod, outline, progressRatio, render, screenState,
  session, text
)
  -- Game path [Gen 1/2/3]: EXP is exp in Gen 1, experience in Gen 2 and a native species-growth projection in Gen 3.
  function displayRuntime.partyExpProgress(mon)
    local source = mon.source or mon
    local level = source.level or mon.level or 1
    if compat.partyEgg(source) then return 0 end
    if level >= 100 then return 1 end
    if displayRuntime.gen3 then
      return displayRuntime.gen3.Summary.expProgress(source,
        displayRuntime.gen3.Pokemon.growthRate(source.species)).progressPercent
    end
    local experience = compat.isGen2() and source.experience or source.exp
    if experience == nil then return mon.expProgress or 0 end
    local def = session.game.data.pokemon[source.species] or {}
    local growth = mod.content.growth_rates:get(def.growthRate or "MEDIUM_FAST")
    if not (growth and growth.expForLevel) then return 0 end
    return progressRatio(experience, math.max(0, growth.expForLevel(level)),
      math.max(0, growth.expForLevel(level + 1)))
  end

  local function partyData()
    local out = {}
    for i, mon in ipairs(session.game and session.game.save and session.game.save.party or {}) do
      local def = session.game.data.pokemon[mon.species] or {}
      local level = mon.level or 1
      out[i] = {
        slot = i, species = mon.species, source = mon,
        name = mon.nickname or (def and def.name) or mon.species,
        level = level, hp = mon.hp,
        maxHp = mon.stats and mon.stats.hp or mon.hp,
        status = mon.status, gender = mon.gender,
        expProgress = displayRuntime.partyExpProgress(mon),
      }
    end
    return out
  end

  function displayRuntime.drawSettings()
    local model = displayRuntime.settingsModel()
    header(THEME:translate(model.label or "SETTINGS"), true, false)
    render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    THEME.hgss:settings(model)
    render.G.pop()
  end

  function displayRuntime.partyView(mon)
    if not mon then return nil end
    local source = mon.source or mon
    local isEgg = compat.partyEgg(mon)
    local def = session.game.data.pokemon[mon.species] or {}
    local maxHp = mon.maxHp or source.stats and source.stats.hp
    -- Imported Gen 1 box records contain current HP but no party stat block.
    -- Read the native calculation without changing the stored Pokemon.
    -- Game path [Gen 1]: boxed records omit party stats; calculate display HP read-only from native DVs/stat EXP.
    if not maxHp and not displayRuntime.gen3 and not compat.isGen2() and def.baseStats then
      maxHp = require("src.pokemon.Stats").calc(def, source.level or 1,
        source.dvs or {}, source.statExp).hp
    end
    maxHp = maxHp or mon.hp or 0
    local type1 = mon.types and mon.types[1] or def.types and def.types[1]
    local type2 = mon.types and (mon.types[2] or mon.types[1])
      or def.types and (def.types[2] or def.types[1])
    return {
      slot = mon.slot, name = isEgg and THEME:translate("EGG")
        or mon.name or source.nickname or def.name,
      egg = isEgg,
      gender = mon.gender == "M" and "male" or mon.gender == "F" and "female" or mon.gender,
      hp = mon.hp, maxHp = maxHp,
      expProgress = mon.expProgress or displayRuntime.partyExpProgress(mon),
      statusId = not isEgg and ((mon.hp or 0) <= 0 and "FNT"
        or THEME:statusName(mon.status, mod.content)) or nil,
      type = type1, type2 = type2,
      typeLabel = THEME:typeName(type1, mod.content),
      type2Label = THEME:typeName(type2, mod.content),
      levelText = THEME:format("L%d", mon.level or 0),
      hpText = THEME:format("%d/%d", mon.hp or 0, maxHp),
      hpLabel = THEME:translate("HP"), expLabel = THEME:translate("EXP"),
      heldItem = not isEgg and displayRuntime.heldItem(mon) or nil,
    }
  end

  local function partyCard(mon, x, y, selected, details, focused, interactive)
    if THEME.style == "hgss" then
      local source = mon and (mon.source or mon)
      local view = displayRuntime.partyView(mon)
      THEME.hgss:partyCard(view, x, y, selected, details,
        function(_, portraitX, portraitY, size, fainted)
          if compat.partyEgg(source) then
            compat.drawPokemonIcon(source, portraitX, portraitY, size,
              fainted and 0.48 or nil)
          elseif not drawSprite(mon.species, "front", portraitX, portraitY,
              size, size, nil, mon, true, fainted and 0.48 or nil,
              selected == true and not fainted and view.statusId ~= "SLP",
              session.battle and "battle" or "summary") then
            compat.drawPokemonIcon(source, portraitX, portraitY, size,
              fainted and 0.48 or nil)
          end
        end, focused, nil, interactive)
      return
    end
    box("fill", x, y, 75, 36, selected and render.DARK or render.MID)
    outline(x, y, 75, 36, render.INK)
    if not mon then
      text("-", x + 35, y + 14, render.DARK)
      return
    end
    local source = mon.source or mon
    local name = fit(mon.name, details and 6 or 7) .. (details and ">" or "")
    if compat.partyEgg(source) then
      compat.drawPokemonIcon(source, x + 2, y + 2)
      text(name, x + 29, y + 9, selected and render.PAPER or render.INK)
      return
    end
    if not drawSprite(mon.species, "front", x + 2, y + 4, 27, 27,
                      nil, mon, true, nil, nil, session.battle and "battle" or "summary") then
      compat.drawPokemonIcon(source, x + 2, y + 2)
    end
    text(name, x + 29, y + 4, selected and render.PAPER or render.INK)
    text(THEME:format("L%d", mon.level or 0), x + 29, y + 14,
         selected and render.PAPER or render.DARK)
    hpBar(x + 29, y + 25, 41, mon.hp, mon.maxHp)
    expBar(x + 29, y + 30, 41, mon.expProgress or 0, selected)
    if (mon.hp or 0) <= 0 then
      text(THEME:translate("FNT"), x + 52, y + 14,
        selected and render.PAPER or render.INK)
    elseif mon.status then
      text(fit(THEME:statusName(mon.status, mod.content), 3),
           x + 52, y + 14, selected and render.PAPER or render.INK)
    end
  end

  function displayRuntime.homeHelpActive()
    local home = displayRuntime.home
    return THEME.style == "hgss" and session.page == "HOME" and home.help == true
      and not home.editing and not home.library and not session.battle
      and not session.pendingFly and not session.pendingAction and not session.fieldChoice
      and not displayRuntime.localSummary and not session.moveInfo
      and screenState() == "active"
  end

  function displayRuntime.showHomeHelp()
    local home = displayRuntime.home
    home.editing, home.library, home.addSlot, home.swapSource = false, false, nil, nil
    home.help, home.activeApp, session.page, session.touchDown, session.dirty = true, nil, "HOME", nil, true
  end

  function displayRuntime.tapHomeHelp(x, y)
    if THEME.hgss:homeHelpHit(x, y, displayRuntime.homePageElements()) then
      displayRuntime.home.help, displayRuntime.home.helpSeen = false, true
      displayRuntime.saveHome()
      session.dirty = true
    end
  end

  function displayRuntime.homePageElements()
    local home = displayRuntime.home
    local tiles = displayRuntime.Home.tiles(home.layout,
      displayRuntime.homeCatalog, home.page)
    local slots = home.editing and displayRuntime.Home.plusSlots(
      home.layout, displayRuntime.homeCatalog, home.page, home.swapSource)
      or nil
    if slots then
      local rowItems = {}
      for _, tile in ipairs(tiles) do rowItems[#rowItems + 1] = tile end
      for _, slot in ipairs(slots) do rowItems[#rowItems + 1] = slot end
      displayRuntime.Home.spaceRows(rowItems)
    end
    return tiles, slots
  end

  function displayRuntime.homeWidgetData(needed)
    local home, now = displayRuntime.home, love.timer.getTime()
    if needed.pss then displayRuntime.pss:open() end
    local keys = {}
    for key in pairs(needed) do keys[#keys + 1] = key end
    table.sort(keys)
    local key = table.concat(keys, ":")
    local cache = home.widgetCache
    if cache and cache.key == key and cache.save == session.game.save
        and now - cache.at < 0.5 then return cache.model end
    local party = (needed.party or needed.team) and partyData() or {}
    local lead = party[1]
    local leadView = lead and displayRuntime.partyView(lead) or nil
    local team = {}
    if needed.team then
      for index, mon in ipairs(party) do
        team[index] = displayRuntime.partyView(mon)
      end
    end
    local dex = (needed.pokedex or needed.trainer)
      and displayRuntime.pokedexData() or { entries = {}, caught = 0, total = 0 }
    local dexSeen, dexLatest = 0, nil
    for _, entry in ipairs(dex.entries or {}) do
      if entry.seen then dexSeen = dexSeen + 1 end
      if entry.caught then dexLatest = entry end
    end
    local trainer = needed.trainer and displayRuntime.trainerSummary() or nil
    local model = {
      lead = leadView, team = team,
      dexCaught = dex.caught, dexSeen = dexSeen, dexTotal = dex.total,
      dexLatest = dexLatest,
      trainer = trainer,
      stamps = needed.achievements and displayRuntime.currentAchievement() or nil,
      bag = needed.bag and displayRuntime.bagSummary() or nil,
      regionMap = needed.map and displayRuntime.homeRegionMap() or nil,
      storePromo = needed.store and displayRuntime.storeWidgetSummary() or nil,
      pss = needed.pss and displayRuntime.pss or nil,
      daycare = (needed.daycare or needed.daycare_small) and displayRuntime.daycareModel() or nil,
      calendar = (needed.calendar or needed.calendar_small) and displayRuntime.calendarModel
        and displayRuntime.calendarModel() or nil,
      drawPokemon = function(view, x, y, size, fainted)
        local mon = party[view and view.slot or 1]
        if not mon then return end
        local source = mon.source or mon
        if compat.partyEgg(source) then
          compat.drawPokemonIcon(source, x, y, size)
        elseif not drawSprite(mon.species, "front", x, y, size, size,
            nil, source, true, fainted and 0.48 or nil,
            view == leadView and not fainted and view.statusId ~= "SLP") then
          compat.drawPokemonIcon(source, x, y, size, fainted and 0.48 or nil)
        end
      end,
      drawDexPokemon = function(entry, x, y, size)
        if not entry then return end
        drawSprite(entry.species, "front", x, y, size, size,
          nil, nil, true)
      end,
    }
    home.widgetCache = { key = key, at = now, save = session.game.save, model = model,
      stepSensitive = needed.party or needed.team or needed.steps
        or needed.trainer or needed.achievements or needed.tool
        or needed.daycare or needed.daycare_small or needed.calendar or needed.calendar_small }
    return model
  end

  -- Home's Explorer widget lists what can appear right now. Encounter tables
  -- are rebuilt only on a map change or every thirty seconds (time of day).
  displayRuntime.homeNow = { rows = {} }
  function displayRuntime.homeNowRows(overview)
    local now, id = love.timer.getTime(), overview and overview.mapId or session.mapId
    local cache = displayRuntime.homeNow
    if not id or not assist("guide") or THEME.style ~= "hgss" then return nil end
    if cache.mapId == id and now - (cache.at or 0) < 30 then return cache.rows end
    local ok, guide = pcall(guideData)
    local rows = {}
    if ok and guide then
      for _, row in ipairs(displayRuntime.explorerWildRows(guide, id, "HERE",
          displayRuntime.explorerMethods())) do
        if #rows >= 4 then break end
        if row.best and row.best.current and displayRuntime.knownSpecies(row.species) then
          rows[#rows + 1] = { species = row.species, caught = row.caught }
        end
      end
    end
    cache.mapId, cache.at, cache.rows = id, now, rows
    return rows
  end

  function displayRuntime.drawHome()
    local home = displayRuntime.home
    local layout = home.layout or { tiles = {} }
    local pages = displayRuntime.Home.pageCount(layout)
      + (home.editing and 1 or 0)
    home.page = math.max(1, math.min(pages, home.page or 1))
    header(THEME:translate(home.library and "ADD TO HOME"
      or home.editing and "EDIT HOME" or "SILPH LINK"), home.library == true)
    local tiles, slots = displayRuntime.homePageElements()
    local needed = {}
    for _, tile in ipairs(tiles or {}) do
      if tile.widget then needed[tile.widget] = true end
    end
    local overview = needed.explorer
      and displayRuntime.perf:call("home_map", loadLocalMap) or nil
    local explorer = overview
      and displayRuntime.perf:call("home_explorer", displayRuntime.explorerModel, overview, true) or {}
    local model = {
      page = home.page, pages = pages, tiles = tiles, slots = slots,
      help = displayRuntime.homeHelpActive(), editing = home.editing,
      dragging = home.swapSource, steps = assist("journey_stats") and compactSteps(session.steps) or "--",
      route = explorer.route or "UNKNOWN AREA",
      overview = overview, image = explorer.image,
      player = explorer.player, markers = explorer.markers,
      drawPlayer = explorer.drawPlayer, drawTrainer = explorer.drawTrainer,
      mapDisabled = not assist("area_map"),
      nowRows = overview and assist("wild") and displayRuntime.homeNowRows(overview) or nil,
      -- Gen 3 menu icons are 32px boxes and draw 1:1; older games pass sprites
      nowIconBox = displayRuntime.gen3 ~= nil,
      drawNowIcon = function(row, x, y, size, dim)
        if not displayRuntime.gen3 then
          -- Gen 1/2 party icons are shared silhouettes; the rail needs the
          -- species, so it uses the same front sprite as the Explorer app
          return drawSprite(row.species, "front", x, y, size, size, dim and { 0.55, 0.55, 0.55, 1 } or nil)
        end
        local icon = displayRuntime.gen3.Pokemon.monIcon({ species = row.species })
        if icon and icon.image then
          local quad, shade = icon.quads and icon.quads[0], dim and 0.55 or 1
          render.G.setColor(shade, shade, shade, 1)
          if quad then render.G.draw(icon.image, quad, x, y, 0, size / 32, size / 32)
          else render.G.draw(icon.image, x, y, 0, size / 32, size / 32) end
          render.G.setColor(1, 1, 1, 1)
        end
      end,
    }
    for key, entry in pairs(displayRuntime.perf:call("home_data", displayRuntime.homeWidgetData, needed)) do model[key] = entry end
    if home.library and home.addSlot then
      model.tiles, model.slots = nil, nil
      model.libraryKind = home.libraryKind
      model.library = displayRuntime.Home.library(layout,
        displayRuntime.homeCatalog, home.page,
        home.addSlot.column, home.addSlot.row, home.libraryKind)
      model.libraryPages = math.max(1, math.ceil(#model.library / 6))
      model.libraryPage = math.max(1, math.min(model.libraryPages,
        home.libraryPage or 1))
    end
    render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    displayRuntime.perf:call("home_paint", THEME.hgss.home, THEME.hgss, model)
    if home.editing and not home.library then THEME.hgss:homeEditDone() end
    render.G.pop()
    displayRuntime.mapRefresh.homeModel = model
    displayRuntime.mapRefresh.paintedPage = session.page
    displayRuntime.mapRefresh.paintedAt = love.timer.getTime()
    displayRuntime.mapRefresh.key = THEME.hgss:homeMotionKey(model, model.player)
    displayRuntime.mapRefresh.terrainRevision = model.overview and model.overview.drawTerrain
      and displayRuntime.nativeMap and displayRuntime.nativeMap:revision() or ""
  end

  return partyCard, partyData
end
