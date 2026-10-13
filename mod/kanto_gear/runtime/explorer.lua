return function(
  Area, Discovery, RADAR_FRAMES, THEME, areaData, areaMaps,
  areaName, assist, compat, displayRuntime, drawSprite, guideData,
  hasItemfinder, hgssRuntime, localMapGrid, mod, render, screenState,
  session
)
  -- Game path [Gen 1/2/3]: terrain comes from Gen 1 tile atlases, Gen 2 native colored canvases or Gen 3 native tilesets; never rebuild the games camera.
  local function loadLocalMap()
    if not assist("area_map") then
      if not Discovery.emptyMap or Discovery.emptyMap.mapId ~= session.mapId then
        Discovery.emptyMap = { mapId = session.mapId, width = 1, height = 1, rows = { " " }, markers = {}, disabled = true }
      end
      return Discovery.emptyMap
    end
    if displayRuntime.gen3 then
      if not displayRuntime.gen3Map then
        displayRuntime.gen3Map = assert(load(mod:read("adapters/gen3/map.lua"),
          "@kanto_gear/adapters/gen3/map.lua"))().new(render.G, require("src.core.game3.tileset_native"))
      end
      local renderer = displayRuntime.gen3Map
      local def = session.game.data.maps[session.mapId]
      local ready = renderer:prepare(def)
      if not ready then return nil end
      if type(session.localMap) ~= "table" or session.localMap.mapId ~= session.mapId
          or session.localMap.width ~= renderer.width or session.localMap.height ~= renderer.height then
        local rows = {}
        for y = 1, renderer.height do rows[y] = string.rep(" ", renderer.width) end
        local markers = {}
        for _, warp in ipairs(def.warps or {}) do
          markers[#markers + 1] = { kind = "warp", x = warp.x, y = warp.y }
        end
        session.localMap = { mapId = session.mapId, width = renderer.width, height = renderer.height,
          rows = rows, markers = markers, drawTerrain = function(x, y, cellSize)
            renderer:draw(x, y, cellSize)
          end }
      end
      return session.localMap
    end
    if not displayRuntime.nativeMap then
      displayRuntime.nativeMap = assert(load(mod:read("adapters/native_map.lua"),
        "@kanto_gear/adapters/native_map.lua"))().new(render.G)
    end
    local native = displayRuntime.nativeMap
    local detailed = native:prepare(session.game and (session.game.overworld or session.game.world),
      session.game and session.game.data, compat.isGen2())
    if type(session.localMap) == "table" then
      if detailed then
        session.localMap.drawTerrain = session.localMap.drawTerrain or function(x, y, size) native:draw(x, y, size) end
      else session.localMap.drawTerrain = nil end
      return session.localMap
    end
    if session.localMap ~= nil then return session.localMap or nil end
    if not (mod.world and mod.world.mapOverview) then
      session.localMap = false
      return nil
    end
    local overview = displayRuntime.perf:call("map_overview", mod.world.mapOverview, mod.world)
    session.localMap = overview and overview.rows and overview or false
    if session.localMap and detailed then
      session.localMap.drawTerrain = function(x, y, size) native:draw(x, y, size) end
    end
    return session.localMap or nil
  end

  session.loadLocalMapImage = nil

  function displayRuntime.explorerMethods()
    if displayRuntime.gen3 then return displayRuntime.gen3:methods() end
    local methods = { WALK = true, CONTEST = true, ROAMING = true }
    local names = { old_rod = "OLD", good_rod = "GOOD", super_rod = "SUPER",
      surf = "SURF", headbutt = "HEADBUTT" }
    for _, def in ipairs(THEME.fieldTools.widgets) do
      if names[def.key] then
        methods[names[def.key]] = THEME.fieldTools.unlocked(def, session.game.save, compat.isGen2())
      end
    end
    methods["RARE TREE"] = methods.HEADBUTT
    methods["ROCK SMASH"] = THEME.fieldTools.partyKnows(session.game.save, "ROCK_SMASH")
    return methods
  end

  function displayRuntime.explorerWildRows(guide, currentMapId, scope, methods)
    local out, hereOnly = {}, scope ~= "ROUTE"
    local effort = { WALK = 1, CONTEST = 1, SURF = 2, OLD = 3, GOOD = 3,
      SUPER = 3, HEADBUTT = 4, ["RARE TREE"] = 5, ["ROCK SMASH"] = 5, ROAMING = 6 }
    local function easier(a, b)
      if a.rank ~= b.rank then return a.rank < b.rank end
      local ae, be = effort[a.method] or 7, effort[b.method] or 7
      if ae ~= be then return ae < be end
      if a.chance ~= b.chance then return (a.chance or 0) > (b.chance or 0) end
      return false
    end
    for _, species in ipairs(guide.rows or {}) do
      local matches, availableHere = {}, false
      for _, appearance in ipairs(species.appearances or {}) do
        local sameArea = appearance.mapId == currentMapId
        local currentTime = not appearance.time
          or appearance.time == guide.time
        local blocked = methods and methods[appearance.method] == false or false
        local current = sameArea and currentTime and not blocked
        availableHere = availableHere or current
        matches[#matches + 1] = {
          method = appearance.method, chance = appearance.chance,
          time = appearance.time, mapId = appearance.mapId,
          section = appearance.section, minLevel = appearance.minLevel,
          maxLevel = appearance.maxLevel, current = current,
          blocked = blocked,
          rank = blocked and 5 or current and 1 or currentTime and 2 or sameArea and 3 or 4,
        }
      end
      table.sort(matches, function(a, b)
        if easier(a, b) then return true end
        if easier(b, a) then return false end
        return table.concat({ tostring(a.mapId), a.time or "", a.method or "" }, ":")
          < table.concat({ tostring(b.mapId), b.time or "", b.method or "" }, ":")
      end)
      if #matches > 0 and (availableHere or not hereOnly) then
        out[#out + 1] = {
          species = species.species, name = species.name,
          caught = species.caught, types = species.types,
          matches = matches,
          best = matches[1],
          detailPages = math.max(1, math.ceil(#matches / 2)),
          key = table.concat({ "wild", scope, tostring(species.species) }, ":"),
        }
      end
    end
    table.sort(out, function(a, b)
      if a.best.rank ~= b.best.rank then return a.best.rank < b.best.rank end
      if (a.caught == true) ~= (b.caught == true) then return b.caught == true end
      if easier(a.best, b.best) then return true end
      if easier(b.best, a.best) then return false end
      return tostring(a.species) < tostring(b.species)
    end)
    return out
  end
  do
    local fixture = { time = "DAY", rows = { { species = 129,
      name = "MAGIKARP", appearances = {
        { mapId = 1, method = "OLD", chance = 85, minLevel = 10,
          maxLevel = 10 },
        { mapId = 1, method = "GOOD", chance = 35, minLevel = 20,
          maxLevel = 20 },
        { mapId = 2, section = "POND", time = "NITE", method = "SUPER",
          chance = 40, minLevel = 30, maxLevel = 30 },
      } }, { species = 163, name = "HOOTHOOT", appearances = {
        { mapId = 2, section = "NORTH FIELD", time = "NITE",
          method = "WALK", chance = 30, minLevel = 15, maxLevel = 15 },
      } } } }
    local here = displayRuntime.explorerWildRows(fixture, 1, "HERE")
    local route = displayRuntime.explorerWildRows(fixture, 1, "ROUTE")
    assert(#here == 1 and here[1].name == "MAGIKARP"
        and #here[1].matches == 3 and here[1].matches[1].current
        and not here[1].matches[3].current and #route == 2
        and route[2].name == "HOOTHOOT",
      "Explorer gallery groups species and retains exact habitat details")
  end

  function displayRuntime.localMapPosition(expectedMap)
    local pos = mod.world and mod.world:current()
    if pos and expectedMap and pos.mapId ~= expectedMap then return nil end
    local world = session.game and (session.game.overworld or session.game.world)
    local player = world and world.player
    -- Host path [all games]: rendered player pixels allow smooth map tracking; older hosts exposing only cells retain their cell-based position.
    -- Public current() exposes cells. Use the engine's rendered position only
    -- for the same live map; older hosts retain their cell-based fallback.
    if pos and world and world.map and world.map.id == pos.mapId
        and player and type(player.px) == "number" and type(player.py) == "number" then
      pos.x, pos.y = player.px / 16, player.py / 16
    end
    return pos
  end

  function displayRuntime.updateMapRefresh(now)
    if not assist("area_map") then return false end
    local state = displayRuntime.mapRefresh
    if (session.page ~= "LOCAL" and session.page ~= "HOME") or THEME.style ~= "hgss"
        or displayRuntime.overlayHidden then return false end
    local home = session.page == "HOME"
    if not home and displayRuntime.explorer.locationPreview then return false end
    if home and (displayRuntime.home.editing or displayRuntime.home.library) then return false end
    local phoneMode = THEME:displayMode(mod.options) == "phone"
    if phoneMode and displayRuntime.phone and displayRuntime.phone.sourceFrame then
      local frame = displayRuntime.phone.sourceFrame
      if state.phoneFrame == frame then return false end
      state.phoneFrame = frame
    else
      local tolerance = phoneMode and .003 or .000001
      if now + tolerance < state.nextAt or session.readbackPending and not phoneMode then return false end
      local rate = phoneMode and 60 or 30
      state.nextAt = state.nextAt
        + (math.floor(math.max(0, now - state.nextAt) * rate) + 1) / rate
    end
    if screenState() ~= "active" or session.battle or session.moveInfo or session.fieldChoice or session.radarOpen then
      return false
    end
    local model = home and state.homeModel or displayRuntime.explorer.renderModel
    if not model or home and (not state.homeModel or model.page ~= displayRuntime.home.page) then return false end
    local pos = displayRuntime.localMapPosition()
    if not model.overview or not pos or pos.mapId ~= model.overview.mapId then return false end
    local key = home and THEME.hgss:homeMotionKey(model, pos)
      or not home and THEME.hgss:explorerMotionKey(model, pos)
    local terrain = model.overview.drawTerrain and displayRuntime.nativeMap
    local revision = terrain and terrain:revision() or ""
    if not key or (key == state.key and revision == (state.terrainRevision or "")) then return false end
    session.dirty = true
    return true
  end

  function displayRuntime.drawMapRefresh()
    local state, now = displayRuntime.mapRefresh, love.timer.getTime()
    local only = state.only
    state.only = false
    -- Only a movement-only invalidation may reuse the existing page pixels.
    -- Periodic data updates, input, overlays and transitions still paint fully.
    if not only or state.paintedPage ~= session.page or THEME.style ~= "hgss"
        or not state.paintedAt or now - state.paintedAt >= 0.5
        or session.touchDown or hgssRuntime.animation or displayRuntime.motion.started
        or session.pendingFly or session.pendingAction or session.moveInfo or session.fieldChoice or session.radarOpen
        or (displayRuntime.backgroundDim or 0) > 0 or displayRuntime.nativeHandoff
        or screenState() ~= "active" then return false end
    if displayRuntime.explorer.locationPreview then return false end
    local home = session.page == "HOME"
    local model = home and state.homeModel or displayRuntime.explorer.renderModel
    local data = displayRuntime.explorer.data
    if not model or not data or now - data.at >= 0.5 then return false end
    if home and (displayRuntime.home.editing or displayRuntime.home.library
        or model.help or not displayRuntime.home.widgetCache) then return false end
    local pos = displayRuntime.localMapPosition(model.overview.mapId)
    if not pos then return false end
    model.player = pos
    render.G.setCanvas(session.canvas)
    render.G.origin(); render.G.setScissor(); render.G.setShader()
    render.G.setBlendMode("alpha"); render.G.setLineWidth(1)
    if home then
      for _, tile in ipairs(model.tiles or {}) do
        if tile.widget == "explorer" then THEME.hgss:homeExplorerMap(model, tile, true) end
      end
    else
      THEME.hgss:explorerMap(model, true)
    end
    render.G.setCanvas()
    state.key = home and THEME.hgss:homeMotionKey(model, pos)
      or THEME.hgss:explorerMotionKey(model, pos)
    state.terrainRevision = model.overview.drawTerrain
      and displayRuntime.nativeMap and displayRuntime.nativeMap:revision() or ""
    return true
  end

  function displayRuntime.explorerModel(overview, mapOnly)
    local explorer = displayRuntime.explorer
    local now, id = love.timer.getTime(), overview.mapId or session.mapId
    local snapshot
    if session.page == "LOCAL" then
      snapshot = explorer.mapSnapshot
      if not snapshot or snapshot.mapId ~= id then
        displayRuntime.clearExplorerSnapshot()
        snapshot = { mapId = id, actors = {} }
        explorer.mapSnapshot = snapshot
      end
    end
    local player = displayRuntime.localMapPosition(id)
    local guideEnabled, areaEnabled = assist("guide"), assist("area")
    local cached = explorer.data
    -- ponytail: a half-second snapshot avoids rebuilding encounter tables on
    -- every player step; invalidate immediately if live mutation needs it.
    if not cached or cached.mapId ~= id or now - cached.at >= 0.5
        or cached.guideEnabled ~= guideEnabled
        or cached.areaEnabled ~= areaEnabled
        or (cached.mapOnly == true) ~= (mapOnly == true) then
      cached = { mapId = id, at = now,
        mapOnly = mapOnly == true,
        guideEnabled = guideEnabled, areaEnabled = areaEnabled,
        fruits = assist("berries") and compat.isGen2()
          and displayRuntime.fruitTrees.rows(session.game.data, id) or {},
        guide = guideEnabled and not mapOnly and guideData()
          or { rows = {}, caught = 0, time = "DAY", timed = false },
        area = (areaEnabled or guideEnabled or assist("gifts")) and areaData(mapOnly and { id } or areaMaps(id), true)
          or { sections = { { rows = {} }, { rows = {} }, { rows = {} } } },
      }
      explorer.data = cached
    end
    local guide, area = cached.guide, cached.area
    -- Movement only changes the player/camera. Reuse list sorting, markers,
    -- labels and progress until the snapshot or visible controls change.
    local renderKey = table.concat({ tostring(explorer.view), tostring(explorer.selected),
      tostring(explorer.page), tostring(explorer.detailPage or 1), tostring(explorer.mapFull),
      tostring(explorer.mapZoom), tostring(explorer.filters.wildScope), tostring(explorer.scanFrame),
      session.discoveryPolicy.signature, tostring(assist("item_radar")), tostring(session.themeKey), tostring(mapOnly == true),
      displayRuntime.fruitTrees.stateKey(session.game.save, cached.fruits) }, ":")
    if explorer.renderModel and explorer.renderData == cached
        and explorer.renderOverview == overview and explorer.renderKey == renderKey
        and (not explorer.scanFrame or explorer.scanFrame >= RADAR_FRAMES) then
      explorer.renderModel.player = player
      explorer.renderModel.mapSnapshot = snapshot
      return explorer.renderModel
    end
    local sections = area.sections or { { rows = {} }, { rows = {} },
      { rows = {} } }
    local allTrainers, allItems, wild = Discovery.filter(areaEnabled and sections[1].rows or {}, function(row)
      return (row.mapId == nil or row.mapId == id)
        and Discovery.row(session.discoveryPolicy, row, 1, displayRuntime.knownMap(row.mapId or id))
    end), {}, {}
    for _, row in ipairs(areaEnabled and sections[2].rows or {}) do allItems[#allItems + 1] = row end
    for _, row in ipairs(areaEnabled and sections[3].rows or {}) do allItems[#allItems + 1] = row end
    for _, row in ipairs(assist("gifts") and area.pokemon or {}) do allItems[#allItems + 1] = row end

    local filters = explorer.filters
    filters.wildScope = filters.wildScope == "ROUTE" and "ROUTE" or "HERE"
    -- Home needs terrain and discovery markers, never the encounter list or
    -- its field-tool checks, sorting and translated type labels.
    if not mapOnly then
      wild = displayRuntime.explorerWildRows(guide, id, filters.wildScope,
        displayRuntime.explorerMethods())
    end

    local actors = (not snapshot or not snapshot.actorById) and mod.world and mod.world.mapActors
      and mod.world:mapActors() or {}
    local actorById = snapshot and snapshot.actorById or {}
    for _, actor in ipairs(actors or {}) do
      local copy = actor
      if snapshot then
        copy = {}
        for k, v in pairs(actor) do copy[k] = v end
      end
      actorById[actor.id] = copy
    end
    if snapshot then snapshot.actorById = actorById end
    local function mapActor(row, actorId, kind)
      local key = table.concat({ kind, tostring(row.id), tostring(row.index),
        tostring(actorId), tostring(row.label) }, ":")
      if snapshot and snapshot.actors[key] then return snapshot.actors[key] end
      local actor = displayRuntime.gen3 and displayRuntime.gen3:mapActor(row)
        or actorById[actorId]
      if actor and not snapshot then return actor end
      local captured = {}
      for k, v in pairs(actor or row) do
        if type(v) ~= "table" and type(v) ~= "function" and type(v) ~= "userdata" then captured[k] = v end
      end
      if not actor and mod.world and mod.world.npc and row.index ~= nil
          and not displayRuntime.gen3 then
        local handle = mod.world:npc(row.mapId, row.index)
        if handle and type(handle.position) == "function" then
          local x, y = handle:position()
          if x ~= nil and y ~= nil then captured.x, captured.y = x, y end
        end
      end
      if snapshot then snapshot.actors[key] = captured end
      return captured
    end
    if snapshot then
      for _, row in ipairs(allTrainers) do mapActor(row, row.id, "trainer") end
    end
    for _, row in ipairs(allTrainers) do
      local actor = mapActor(row, row.id, "trainer")
      row.mapVisible = not actor or actor.visible ~= false
      if actor then
        row.actor = actor
        row.x, row.y, row.facing = actor.x, actor.y, actor.facing
        row.spriteId, row.palette = actor.spriteId, actor.palette
      end
      row.key = "trainer:" .. tostring(row.id or row.label)
    end
    local enhanced = assist("hidden_items")
    local canScan = not enhanced and assist("item_radar") and hasItemfinder()
    if explorer.scanMapId ~= id then
      explorer.scanMapId, explorer.scanFrame, explorer.scanRevealed =
        id, nil, {}
    end
    local pos = player
    local scanProgress = explorer.scanFrame
      and math.min(1, explorer.scanFrame / RADAR_FRAMES) or nil
    for _, row in ipairs(allItems) do
      if row.gift and (row.mapId == nil or row.mapId == id) then
        row.actor = mapActor(row, row.actorId, "gift")
        if row.actor then
          row.mapVisible = row.actor.visible ~= false
          row.x, row.y = row.actor.x, row.actor.y
        end
      end
      row.key = table.concat({ "item", tostring(row.mapId or id), tostring(row.id), tostring(row.kind), tostring(row.x),
        tostring(row.y), tostring(row.label) }, ":")
      if canScan and scanProgress and row.kind == "hidden" and not row.done
          and row.available ~= false
          and row.x and row.y and pos and pos.mapId == id and (row.mapId == nil or row.mapId == id)
          and (displayRuntime.gen3 and displayRuntime.gen3:itemfinderReached(pos.x, pos.y, row, scanProgress)
            or not displayRuntime.gen3 and Area.itemfinderScanReached(pos.x, pos.y, row.x, row.y, scanProgress)) then
        explorer.scanRevealed[row.key] = true
      end
      row.scanned = canScan and row.available ~= false
        and explorer.scanRevealed[row.key] == true
      local upper = tostring(row.label or ""):upper()
      row.icon = (upper:match("^TM%d") or upper:match("^HM%d"))
        and "machine" or "item"
      row.displayLabel = row.kind == "hidden" and not enhanced and not row.done
          and not row.scanned
        and THEME:translate("HIDDEN SIGNAL") or row.label
      row.location = row.repeatable and "RENEWABLE" or row.status == "LATER" and "STORY EVENT"
        or row.status == "NOT TRACKED" and "NOT TRACKED"
        or (row.kind == "hidden" and not enhanced and not row.done
          and not row.scanned
        and "USE ITEMFINDER" or row.gift and "TALK TO NPC" or "MARKED ON MAP")
    end
    allItems = Discovery.filter(allItems, function(row)
      return Discovery.row(session.discoveryPolicy, row, (row.species or row.isEgg) and 4 or row.kind == "hidden" and 3 or 2,
        displayRuntime.knownMap(row.mapId or id))
    end)
    local gifts, items = {}, {}
    for _, row in ipairs(allItems) do
      if row.species or row.isEgg then
        if filters.wildScope == "ROUTE" or (row.mapId == nil or row.mapId == id) and row.available and row.mapVisible ~= false
            and not row.outsideMap and not row.done and not row.excluded then
          row.key, row.name, row.caught = row.id, row.isEgg and THEME:translate("EGG") or row.label, row.done
          row.method = row.trade and "NPC TRADE" or row.loan and "NPC LOAN" or (row.cost or row.coinCost) and "NPC OFFER" or "NPC GIFT"
          row.needsSpeciesName = row.needsSpecies and ((session.game.data.pokemon[row.needsSpecies] or {}).name or row.needsSpecies)
          row.best, row.matches, row.detailPages = nil, {}, 1
          gifts[#gifts + 1] = row
        end
      else items[#items + 1] = row end
    end
    allItems = items
    local itemProgress = displayRuntime.Achievements.section(allItems, 2, {
      gen2 = compat.isGen2(), gen3 = displayRuntime.gen3 ~= nil, save = session.game.save,
      flag = function(event) return mod.world and mod.world.getFlag and mod.world:getFlag(event) end,
    })
    allItems = itemProgress.rows
    local entrances = explorer.entrances
    local definitions = compat.isGen2() and session.game.data.gen2Maps or session.game.data.maps
    if not mapOnly and (not entrances or entrances.mapId ~= id or entrances.definitions ~= definitions) then
      entrances = { mapId = id, definitions = definitions, byMap = {},
        resolve = displayRuntime.LocationPreview.resolver(definitions, displayRuntime.gen3 and 3 or compat.isGen2() and 2 or 1) }
      explorer.entrances = entrances
    end
    for _, row in ipairs(allItems) do
      row.remote = row.mapId ~= nil and row.mapId ~= id
      if row.remote and entrances then
        row.indoor = definitions[row.mapId] and not displayRuntime.LocationPreview.outdoor(definitions[row.mapId],
          displayRuntime.gen3 and 3 or compat.isGen2() and 2 or 1) or false
        if entrances.byMap[row.mapId] == nil then
          entrances.byMap[row.mapId] = entrances.resolve(row, id) or false
        end
        local door = entrances.byMap[row.mapId]
        row.entrance = door and door.mapId == id and door or nil
        row.location = displayRuntime.sectionName(row.mapId)
      end
    end
    for i = #gifts, 1, -1 do
      if gifts[i].available then table.insert(wild, 1, gifts[i]) else wild[#wild + 1] = gifts[i] end
    end
    local mapItems = Discovery.filter(allItems, function(row) return not row.outsideMap and (not row.remote or row.entrance) end)
    for _, row in ipairs(wild) do
      local def = session.game.data.pokemon and session.game.data.pokemon[row.species] or {}
      local types = (assist("dex_types") or row.caught) and (row.types or def.types or {}) or {}
      local type1 = types[1] or (assist("dex_types") or row.caught) and def.type1 or nil
      local type2 = types[2] or (assist("dex_types") or row.caught) and def.type2 or type1
      row.type, row.type2 = type1, type2
      row.typeLabel = THEME:typeName(type1, mod.content)
      row.type2Label = THEME:typeName(type2, mod.content)
    end

    local view = explorer.view or "wild"
    local source = view == "wild" and wild
      or view == "items" and allItems
      or view == "fruit" and cached.fruits
      or view == "trainers" and allTrainers or {}
    local perPage = THEME.style == "hgss" and THEME.hgss.explorerPerPage
      and THEME.hgss:explorerPerPage(view, #source) or (view == "wild" and 4 or math.max(1, #source))
    local pages = math.max(1, math.ceil(#source / perPage))
    explorer.page = math.max(1, math.min(explorer.page, pages))
    local first, rows = (explorer.page - 1) * perPage + 1, {}
    for index = first, math.min(#source, first + perPage - 1) do
      rows[#rows + 1] = source[index]
    end
    local selected
    for _, row in ipairs(source) do
      if row.key == explorer.selected then selected = row break end
    end
    if not mapOnly and explorer.selected and not selected then explorer.selected = nil end

    local markers, selectedMarker = {}, nil
    for _, marker in ipairs(overview.markers or {}) do
      if marker.kind == "warp" then markers[#markers + 1] = marker end
    end
    for _, row in ipairs(cached.fruits) do
      row.picked = displayRuntime.fruitTrees.picked(session.game.save, row.tree)
      local marker = { kind = "fruit", x = row.x, y = row.y,
        picked = row.picked, source = row }
      markers[#markers + 1] = marker
      if row == selected then selectedMarker = marker end
    end
    for _, row in ipairs(mapItems) do
      local point = row.entrance or row
      if (row.remote or row.mapVisible ~= false) and point.x ~= nil and point.y ~= nil then
        local marker = { kind = row.kind, x = point.x, y = point.y, entrance = row.entrance ~= nil,
          found = row.done, scanned = row.scanned, source = row,
          gift = not row.remote and row.gift, actor = not row.remote and (row.actor or row), state = row.done and "beaten" or "open" }
        markers[#markers + 1] = marker
        if row == selected then selectedMarker = marker end
      end
    end
    for _, row in ipairs(gifts) do
      if (row.mapId == nil or row.mapId == id) and row.mapVisible ~= false and not row.excluded and not row.outsideMap and row.x ~= nil and row.y ~= nil then
        local marker = { kind = "pokemon", gift = true, x = row.x, y = row.y, source = row,
          actor = row.actor or row, state = row.done and "beaten" or "open" }
        markers[#markers + 1] = marker
        if row == selected then selectedMarker = marker end
      end
    end
    for _, row in ipairs(allTrainers) do
      if row.mapVisible ~= false and row.x ~= nil and row.y ~= nil then
        local marker = { kind = "trainer", x = row.x, y = row.y,
          actor = row.actor or row,
          state = row.missed and "missed" or row.done and "beaten" or "open",
          source = row }
        markers[#markers + 1] = marker
        if row == selected then selectedMarker = marker end
      end
    end

    local function progress(rows_)
      local done = 0
      for _, row in ipairs(rows_) do if row.done then done = done + 1 end end
      if displayRuntime.discoveryMode() == "vanilla" then return tostring(done) end
      return THEME:format("%d/%d", done, #rows_)
    end
    local rows_, width, height, density = localMapGrid(overview)
    explorer.detailPage = math.max(1, math.min(explorer.detailPage or 1,
      selected and selected.detailPages or 1))
    local detailRows = {}
    if selected and view == "wild" then
      local firstDetail = (explorer.detailPage - 1) * 2 + 1
      for index = firstDetail,
          math.min(#selected.matches, firstDetail + 1) do
        detailRows[#detailRows + 1] = selected.matches[index]
      end
    end
    if not assist("encounter_details") then detailRows = {} end
    local mapCacheKeys
    if snapshot then
      mapCacheKeys = { tostring(session.themeKey), tostring(explorer.mapFull),
        tostring(explorer.mapZoom), tostring(selectedMarker and selectedMarker.source.key) }
      for _, marker in ipairs(markers) do
        mapCacheKeys[#mapCacheKeys + 1] = table.concat({ marker.kind, tostring(marker.x),
          tostring(marker.y), tostring(marker.state), tostring(marker.found),
          tostring(marker.scanned), tostring(marker.picked) }, ":")
      end
    end
    local model = {
      view = view, selected = selected, rows = rows,
      total = #source, page = explorer.page, pages = pages, perPage = perPage,
      route = areaName(overview.mapId or session.mapId),
      subarea = displayRuntime.sectionName(overview.mapId or session.mapId,
        THEME:translate("OUTDOORS")),
      region = (compat.currentRegion() or "kanto"):upper(),
      overview = overview,
      image = session.loadLocalMapImage(overview, rows_, width, height, density),
      player = player, mapSnapshot = snapshot, mapCacheKey = mapCacheKeys and table.concat(mapCacheKeys, "/"),
      markers = markers, selectedMarker = selectedMarker,
      mapFull = explorer.mapFull == true,
      mapZoom = explorer.mapZoom or 1,
      filters = filters,
      detailPage = explorer.detailPage, detailRows = detailRows,
      detailPages = assist("encounter_details") and selected and selected.detailPages or 1,
      enhanced = enhanced,
      canScan = canScan and assist("area_map"), encounterDetails = assist("encounter_details"),
      scanHint = canScan and not explorer.scanHintSeen,
      scanProgress = scanProgress,
      showMapStats = areaEnabled,
      guideEnabled = guideEnabled, areaEnabled = areaEnabled,
      emptyHint = displayRuntime.discoveryMode() == "vanilla" and "NO KNOWN POKEMON HERE" or nil,
      itemsText = (displayRuntime.discoveryMode() == "vanilla" and tostring(itemProgress.done)
        or THEME:format("%d/%d", itemProgress.done, itemProgress.total)),
      itemProgress = itemProgress,
      trainersText = progress(allTrainers),
      wildText = (function()
        local caught = 0
        for _, row in ipairs(wild) do if row.caught then caught = caught + 1 end end
        if displayRuntime.discoveryMode() == "vanilla" then return tostring(caught) end
        return THEME:format("%d/%d", caught, #wild)
      end)(),
      wildScope = filters.wildScope,
      period = guide.timed ~= false and guide.time or nil,
      trainerIcon = allTrainers[1],
      drawPlayer = function(player, x, y, tileSize)
        compat.drawMapMarker(x, y, tileSize / 16, true, player.facing)
      end,
      drawTrainer = function(marker, x, y, tileSize)
        return compat.drawMapActor(marker.actor, x, y, tileSize / 16, true,
          marker.state ~= "open" and { 0.45, 0.45, 0.45, 1 } or nil)
      end,
      drawActor = function(row, x, y, scale, feet, maxSize)
        return compat.drawMapActor(row.actor or row, x, y, scale, feet, nil, maxSize)
      end,
      drawPokemon = function(row, x, y, size, uncaught)
        if row.isEgg then
          if displayRuntime.gen3 then return drawSprite(row.species, "front", x, y, size, size, nil, row, true) end
          return compat.drawPokemonIcon(row, x, y, size)
        end
        drawSprite(row.species, "front", x, y, size, size,
          uncaught and { 0.52, 0.52, 0.52, 1 } or nil)
      end,
    }
    explorer.renderModel, explorer.renderData = model, cached
    explorer.renderOverview, explorer.renderKey = overview, renderKey
    return model
  end

  function session.loadLocalMapImage(overview, rows, width, height, density)
    if overview.disabled or overview.drawTerrain then return nil end
    if session.localMapImage ~= nil then return session.localMapImage or nil end
    if not (love.image and love.image.newImageData) then
      session.localMapImage = false
      return nil
    end
    local measured = displayRuntime.perf:start()
    local ok, image = pcall(function()
      local pixels = love.image.newImageData(width, height)
      for y, row in ipairs(rows) do
        for x = 1, #row do
          local c = THEME.style == "hgss"
            and THEME.hgss:mapColor(
              overview, x, y, density, row:sub(x, x))
            or THEME:localMapColor(
              overview, x, y, density, row:sub(x, x))
          pixels:setPixel(x - 1, y - 1, c[1], c[2], c[3], c[4])
        end
      end
      local result = render.G.newImage(pixels)
      result:setFilter("nearest", "nearest")
      if pixels.release then pixels:release() end
      return result
    end)
    displayRuntime.perf:finish("map_image", measured)
    session.localMapImage = ok and image or false
    return session.localMapImage or nil
  end

  return loadLocalMap
end
