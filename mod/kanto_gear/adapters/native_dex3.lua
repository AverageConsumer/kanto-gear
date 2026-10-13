-- Gen 3 catalogues retain internal species IDs and the native discovery rules.
-- Search choices and movement come from the edition's imported native menu.
local imageBounds = setmetatable({}, { __mode = "k" })
local function bounds(image, path, Pokemon)
  if not image then return { 0, 0, 64, 64 } end
  if imageBounds[image] then return imageBounds[image] end
  local cache = Pokemon._cache or require("src.core.game3.dataset").cache()
  local bytes = cache and cache:read(path) or nil
  local b = { 64, 64, 0, 0 }
  if type(bytes) == "string" and #bytes == 64 * 64 * 4 then
    for y = 0, 63 do for x = 0, 63 do
      if bytes:byte((y * 64 + x) * 4 + 4) > 0 then
        b[1], b[2], b[3], b[4] = math.min(b[1], x), math.min(b[2], y), math.max(b[3], x + 1), math.max(b[4], y + 1)
      end
    end end
  end
  if b[3] <= b[1] then b = { 0, 0, 64, 64 } end
  imageBounds[image] = b
  return b
end

-- Game path [Ruby/Sapphire/Emerald]: size comparison uses Hoenn trainer art and saved Unown/Spinda personalities.
local function comparison(s, Pokemon)
  local sp = require("src.ui.game3.rse.pokedex").speciesOf(s.list.items[s.selected].dexNum)
  local C = require("src.core.game3.constants").of(require("src.core.game3.profile").forSession(s.session).id)
  local personality = sp == C.species.byName.SPECIES_UNOWN and (tonumber(s.dex.unownPersonality) or 0)
    or sp == C.species.byName.SPECIES_SPINDA and (tonumber(s.dex.spindaPersonality) or 0) or 0
  local gender = s.session.gender or s.session.playerGender
  local trainer = C:id("trainer_classes", (gender == 1 or gender == "female" or gender == "girl") and "TRAINER_PIC_MAY" or "TRAINER_PIC_BRENDAN")
  -- The host owns the active import root, including alternate datasets.
  local root = require("src.core.game3.cache_paths").CACHE_ROOT
  local rows = {}
  for i, row in ipairs({ s.sizeMon, s.sizeTrainer }) do
    local path = root .. "/" .. (i == 1 and "pokemon/front/" .. Pokemon.picSpecies(sp, personality)
      or "trainers/front/" .. trainer) .. ".rgba"
    rows[i] = { img = row.img, x = row.x, y = row.y, y2 = row.y2, scale = row.scale, bounds = bounds(row.img, path, Pokemon) }
  end
  return rows
end

-- Game path [Ruby/Sapphire/Emerald]: imported search movement tables decide reachable fields and native refresh actions.
local function searchPage(s, Native)
  local q = s.searchState
  if not q then return end
  local sm = require("src.ui.game3.rse.pokedex_gfx").manifest().search
  local SEARCH, TOPBAR = Native.SEARCH, Native.TOPBAR
  local labels = { "NAME", "COLOR", "TYPE1", "TYPE2", "ORDER", "MODE",
    q.topBar == TOPBAR.SEARCH and "BEGIN SEARCH!!" or "APPLY" }
  local lists = { [SEARCH.NAME] = sm.names, [SEARCH.COLOR] = sm.colors,
    [SEARCH.TYPE_LEFT] = sm.types, [SEARCH.TYPE_RIGHT] = sm.types, [SEARCH.ORDER] = sm.orders, [SEARCH.MODE] = sm.modes }
  local function options(which)
    return Native.searchOptionTexts and Native.searchOptionTexts(which) or lists[which] or {}
  end
  local function selected(which) return (q.cursor[which] or 0) + (q.scroll[which] or 0) end
  local signature = { tostring(q), s.fn, tostring(q.topBar), tostring(q.menuItem), tostring(s.nationalEnabled) }
  for i = 0, 5 do signature[#signature + 1] = tostring(selected(i)) end
  local state = { kind = "search", uiLabels = s.fn ~= "searchParam", signature = table.concat(signature, ":"),
    title = s.fn == "searchParam" and labels[q.menuItem + 1] or q.topBar == TOPBAR.SEARCH and "SEARCH" or "OPTION" }
  if s.fn == "searchTopBar" then
    state.rows = { { label = "SEARCH" }, { label = "OPTION" }, { label = "CANCEL" } }
    state.cursor = function() return q.topBar + 1 end
    state.select = function(i)
      local target = i - 1
      if target == q.topBar then return end
      local direction = target > q.topBar and "right" or "left"
      q.topBar = target + (direction == "right" and -1 or 1)
      Native.tasks.searchTopBar(s, { new = { [direction] = true } })
    end
  elseif s.fn == "searchMenu" then
    local searching = q.topBar == TOPBAR.SEARCH
    local map = sm.movement[(searching and "Search" or "Shift") .. (s.nationalEnabled and "NatDex" or "HoennDex")]
    local reachable, queue, edges = {}, { searching and SEARCH.NAME or SEARCH.ORDER }, {}
    reachable[queue[1]] = true
    local directions, pos = { "left", "right", "up", "down" }, 1
    while queue[pos] do
      local from = queue[pos]
      for col, target in ipairs(map[from + 1]) do
        if target ~= 0xFF then
          edges[target] = edges[target] or { from, directions[col] }
          if not reachable[target] then
            reachable[target] = true
            queue[#queue + 1] = target
          end
        end
      end
      pos = pos + 1
    end
    local ids, indices = {}, {}
    state.rows = {}
    for which = 0, SEARCH.OK do
      if reachable[which] then
        local option = options(which)[selected(which) + 1]
        ids[#ids + 1] = which
        indices[which] = #ids
        state.rows[#state.rows + 1] = { label = labels[which + 1], right = option and option.title }
      end
    end
    state.cursor = function() return indices[q.menuItem] end
    state.select = function(i)
      local target = ids[i]
      if target == q.menuItem then return end
      local edge = edges[target]
      q.menuItem = edge[1]
      Native.tasks.searchMenu(s, { new = { [edge[2]] = true } })
    end
  elseif s.fn == "searchParam" then
    state.rows = {}
    for i, option in ipairs(options(q.menuItem)) do state.rows[i] = { label = option.title } end
    state.cursor = function() return selected(q.menuItem) + 1 end
    state.select = function(i)
      local target = i - 1
      if target == selected(q.menuItem) then return end
      -- One native movement refreshes the upper highlight, text and description.
      local before, direction = target == 0 and 1 or target - 1, target == 0 and "up" or "down"
      q.cursor[q.menuItem], q.scroll[q.menuItem] = math.min(before, 5), math.max(0, before - 5)
      Native.tasks.searchParam(s, { rep = { [direction] = true } })
    end
  else
    state.rows = { { label = "CONTINUE", rect = { 7, 150, 226, 28 } } }
    state.fixedLayout, state.back, state.notice = true, false, q.message
    state.waiting = s.fn ~= "searchDone"
  end
  return state
end

local function describe(layer, game, previous)
  if not layer or not layer.mod or layer.id ~= "pokedex" and layer.id ~= "rse_pokedex" then return end
  if require("src.ui.game3.message").isOpen() or require("src.ui.game3.choice").active then return end
  local native = layer.mod
  local Pokemon, Dex = require("src.core.game3.pokemon"), require("src.core.game3.dex")
  local state, dex, session
  local function rows(list, caught)
    local out = {}
    local owned = 0
    for i, sp in ipairs(list) do
      if Dex.isCaught(dex, sp) then owned = owned + 1 end
      out[i] = { species = sp, dex = Pokemon.national(sp), name = Pokemon.name(sp),
        seen = Dex.isSeen(dex, sp), caught = Dex.isCaught(dex, sp) }
    end
    state.rows, state.caught = out, caught or owned
  end
  if layer.id == "pokedex" then
    if not native.open then return end
    dex, session = native._dex, native._session
    local Data = require("src.core.game3.pokedex_data")
    if native.screen == "mode_select" then
      local items = {}
      for i, row in ipairs(native.MODES) do
        items[i] = { label = row.label, inert = row.isHeader or row.unlocked == false }
      end
      state = { kind = "option", rows = items, signature = tostring(native.MODES),
        cursor = function() return native.modeCursor end,
        select = function(i) native.modeCursor, native.modeScroll = i, math.max(0, i - 9) end }
    elseif native.screen == "ordered_list" or native.screen == "category_grid" then
      local category = native.screen == "category_grid"
      local catalogKey = table.concat({ tostring(layer), tostring(dex), native.screen,
        native.currentOrder, native.currentCategory, tostring(native.categoryPage) }, ":")
      state = { kind = "index", signature = catalogKey, catalogKey = catalogKey,
        region = native.mode == "national" and "NATIONAL DEX" or "KANTO DEX",
        cursor = function() return category and native.categorySlot or native.listCursor end,
        select = function(i)
          if category then native.categorySlot = i
          else native.listCursor, native.cursor, native.listScroll = i, i, math.max(0, i - 9) end
        end }
      local cached = previous and previous.dex
      if cached and cached.catalogKey == catalogKey then
        state.rows, state.caught, state.number, state.pages = cached.rows, cached.caught, cached.number, cached.pages
      elseif category then
        local pages = Data.getUnlockedCategoryPages(native.currentCategory, dex)
        local list = pages[native.categoryPage] and pages[native.categoryPage].mons or {}
        rows(list)
        state.number, state.pages = native.categoryPage, math.max(1, #pages)
      else
        local _, caught = Data.countOrder(dex, native.currentOrder)
        rows(Data.getOrderList(native.currentOrder, dex), caught)
      end
      if category then
        for _, row in ipairs(native.MODES) do if row.id == native.currentCategory then state.region = row.label; break end end
        state.cycle = function(direction)
          native.categoryPage, native.categorySlot = (native.categoryPage - 1 + direction) % state.pages + 1, 1
        end
      end
    elseif native.screen == "data" and native.dataPage == 2 then
      local sp = native.selectedSpecies
      local owned, gender = Dex.isCaught(dex, sp), native.playerGender()
      local personality = Dex.defaultPersonality(dex, sp)
      Data.init()
      local areaKey = table.concat({ tostring(dex), sp, tostring(owned), gender, tostring(personality), tostring(Data._speciesWildAreas) }, ":")
      local cached = previous and previous.dex.areaKey == areaKey and previous.dex
      local area, silhouettes = cached and cached.area, cached and cached.comparison
      if not area then
        local Chrome = require("src.ui.game3.pokedex_chrome")
        local markers = {}
        for _, key in ipairs(Data.getWildAreasForSpecies(sp)) do
          if Data.getAreaMapKey(key) == "kanto" then
            local marker = Data.getAreaMarker(key)
            if marker then markers[#markers + 1] = marker end
          end
        end
        area = { x = 0, y = 0, width = 96, height = 72, unknown = #markers == 0,
          available = Chrome.getImage("map_kanto") ~= nil,
          draw = function()
            Chrome.drawMap("kanto", 0, 0)
            for _, marker in ipairs(markers) do Chrome.drawAreaMarker(marker.shape, marker.x - 32, marker.y) end
          end }
        silhouettes = {}
        if owned then
          local entry = Data.getEntry(sp)
          local pic, trainer = Pokemon.dexFrontPic(sp, personality), Chrome.getTrainerPic(gender)
          local root = require("src.core.game3.cache_paths").CACHE_ROOT
          for i, row in ipairs({ { img = pic and pic.image, x = 40, y = 104, y2 = entry.pokemonOffset or 0,
              scale = 256 / native.silhouetteScale(entry.pokemonScale) },
            { img = trainer, x = 80, y = 104, y2 = entry.trainerOffset or 0,
              scale = 256 / native.silhouetteScale(entry.trainerScale) } }) do
            local path = root .. "/" .. (i == 1 and "pokemon/front/" .. Pokemon.picSpecies(sp, personality)
              or "trainers/front/" .. (gender == "female" and 136 or 135)) .. ".rgba"
            row.bounds = bounds(row.img, path, Pokemon)
            silhouettes[i] = row
          end
        end
      end
      state = { kind = "area", species = sp, owned = owned, area = area, areaKey = areaKey,
        comparison = silhouettes, region = "KANTO", page = 2, compactActions = true,
        signature = areaKey, actions = { { label = "CRY", key = "start" },
          { label = "ENTRY", key = "b" }, { label = "CANCEL", key = "a" } } }
    elseif native.screen == "registration" or native.screen == "data" and native.dataPage == 1 then
      local sp = native._regSpecies or native.selectedSpecies
      local registration = native.screen == "registration"
      state = { kind = "profile", species = sp, owned = Dex.isCaught(dex, sp), page = native.dataPage,
        description = Data.getEntry(sp).description,
        actions = registration and { { label = "CONTINUE" } } or {
          { label = "NEXT DATA", key = "a" }, { label = "CRY", key = "start" } } }
    end
  else
    local Native = require("src.ui.game3.rse.pokedex")
    -- Game path [Ruby/Sapphire vs Emerald]: the imported asset layout selects different list/header offsets and entry action order.
    local rs = require("src.ui.game3.rse.pokedex_gfx").manifest().assetLayout == "rs"
    local s = native._s
    if not s then return end
    dex, session = s.dex, s.session
    if s.page == Native.PAGE.SEARCH and s.searchState then
      state = searchPage(s, Native)
    elseif s.fn == "startMenu" then
      local labels = { "CANCEL", "FIRST", "LAST" }
      if s.isSearchResults then labels[#labels + 1] = "BACK" end
      labels[#labels + 1] = "CLOSE"
      local items = {}; for i, label in ipairs(labels) do items[i] = { label = label, inert = s.list.count == 0 and (i == 2 or i == 3) } end
      state = { kind = "option", rows = items, signature = tostring(s), waiting = s.menuY ~= (s.isSearchResults and 96 or 80),
        cursor = function() return s.menuCursorPos + 1 end, select = function(i) s.menuCursorPos = i - 1 end }
    elseif (s.page == Native.PAGE.MAIN or s.page == Native.PAGE.SEARCH_RESULTS) and s.list then
      state = { kind = "index", signature = tostring(s) .. ":" .. s.fn, waiting = s.fn ~= "mainInput" or s.menuY ~= 0,
        catalogKey = s.list, region = s.dexMode == 0 and "HOENN DEX" or "NATIONAL DEX", caught = s.ownCount,
        tools = { { label = "SEARCH", key = "select" }, { label = "OPTION", key = "start" } },
        cursor = function() return s.selected + 1 end,
        select = function(i)
          s.selected = i - 1
          -- The native list's load phase synchronizes its row buffer and form-aware sprites without a fade.
          local phase, fn = s.state, s.fn
          s.state = 3
          if s.isSearchResults then Native.tasks.openSearchResults(s) else Native.tasks.openMain(s) end
          s.state, s.fn = phase, fn
        end }
      local cached = previous and previous.dex
      if cached and cached.catalogKey == s.list then state.rows = cached.rows
      else
        state.rows = {}
        for i = 0, s.list.count - 1 do
          local row = s.list.items[i]
          local sp = Native.speciesOf(row.dexNum)
          state.rows[i + 1] = { species = sp, dex = s.dexMode == 0 and Native.hoennNumber(row.dexNum) or row.dexNum,
            name = Pokemon.name(sp), seen = row.seen, caught = row.owned }
        end
      end
    elseif s.page == Native.PAGE.AREA and s.area then
      local row, a = s.list.items[s.selected], s.area
      local area = previous and previous.dex.areaKey == a and previous.dex.area
      if not area then
        -- Read the native finder once per open area. Merge adjacent atlas cells;
        -- the companion needs neither a second glow texture nor animated highlights.
        local Region = require("src.ui.game3.rse.region_map")
        local sections, coverage = {}, {}
        for _, found in ipairs(a.found.overworld) do sections[found.sec] = true end
        for y = 0, 19 do
          local first
          for x = 0, 32 do
            local occupied = x < 32 and sections[Region.mapSecAt(x, y)]
            if occupied and not first then first = x end
            if first and not occupied then
              coverage[#coverage + 1] = { x = first * 8, y = y * 8 + 8, width = (x - first) * 8, height = 8 }
              first = nil
            end
          end
        end
        area = { x = 8, y = 24, width = 224, height = 128, markers = a.markers, player = a.player,
          coverage = coverage, available = a.map ~= nil, unknown = a.unknown,
          draw = function() love.graphics.setColor(1, 1, 1, 1); love.graphics.draw(a.map, 0, 8) end }
      end
      state = { kind = "area", species = Native.speciesOf(row.dexNum), owned = row.owned,
        area = area, areaKey = a, region = "HOENN", compactActions = true,
        signature = tostring(s) .. ":" .. s.fn .. ":" .. tostring(a) .. ":" .. tostring(a.inputState),
        waiting = s.fn ~= "areaInput" or a.inputState ~= 1 or s.pal:fadeActive(),
        actions = { { label = "CRY", key = "right" }, { label = "ENTRY", key = "b" } } }
    elseif s.page == Native.PAGE.CRY and s.cry then
      local row, cry = s.list.items[s.selected], s.cry
      local ready = cry.cryRepeatDelay == 0 and cry.cryOverrideCountdown == 0
      state = { kind = "cry", species = Native.speciesOf(row.dexNum), owned = row.owned,
        signature = tostring(s) .. ":" .. s.fn .. ":" .. tostring(ready), waiting = s.fn ~= "cryInput" or s.pal:fadeActive(),
        playing = s.cryPlaying == true, wave = s.cryPlaying and cry.pcm and cry.buffer or nil,
        actions = { { label = "AREA", key = "left" }, { label = "PLAY", key = "a", inert = not ready },
          { label = "SIZE", key = "right", inert = not row.owned } } }
    elseif s.page == Native.PAGE.SIZE and s.sizeMon and s.sizeTrainer then
      local row = s.list.items[s.selected]
      state = { kind = "size", species = Native.speciesOf(row.dexNum), owned = row.owned,
        signature = tostring(s) .. ":" .. s.fn, waiting = s.fn ~= "sizeInput" or s.pal:fadeActive(),
        caption = s.sizeText and s.sizeText.text,
        comparison = comparison(s, Pokemon),
        actions = { { label = "CRY", key = "left" }, { label = "ENTRY", key = "b" } } }
    elseif s.page == Native.PAGE.INFO and s.info and s.info.dexNum or s.page == Native.PAGE.CAUGHT and s.caught then
      local caught = s.page == Native.PAGE.CAUGHT
      local info = caught and s.caught or s.info
      local text = info.text or {}
      local description = ""
      for _, part in ipairs(text) do if part.y == (rs and 104 or 95) then description = part.text end end
      local actions = caught and { { label = "CONTINUE" } } or {
        { label = "AREA" }, { label = "CRY" }, { label = "SIZE", inert = not info.owned }, { label = "CANCEL" } }
      if rs and not caught then table.insert(actions, 1, { label = "NEXT DATA", inert = not info.owned }) end
      state = { kind = "profile", species = Native.speciesOf(info.dexNum), owned = caught or info.owned,
        page = s.page, signature = tostring(s) .. ":" .. s.fn .. ":" .. tostring(s.descriptionPage), description = description,
        waiting = s.fn ~= (caught and "caughtInput" or "infoInput"),
        actions = actions,
        cursor = not caught and function() return s.selectedScreen + 1 end or nil,
        select = not caught and function(i) s.selectedScreen = i - 1 end or nil }
    end
    if state then state.signature = tostring(state.signature) .. ":" .. tostring(s.page) end
  end
  if not state or session ~= game.session then return end
  state.hideKind = state.kind == "profile" and not state.owned
  state.portrait = function(sp)
    local personality = Dex.defaultPersonality and Dex.defaultPersonality(dex, sp) or 0
    if layer.id == "rse_pokedex" then
      local s = native._s
      if s and s.caught then personality = s.caught.personality or 0 end
    end
    local pic = layer.id == "pokedex" and Pokemon.dexFrontPic(sp, personality)
      or Pokemon.frontPic(Pokemon.picSpecies(sp, personality), nil, false, personality, "dex")
    return pic and pic.image
  end
  return state
end
return describe
