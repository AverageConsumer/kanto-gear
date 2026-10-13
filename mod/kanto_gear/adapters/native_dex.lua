-- Native menus own catalogue order, discovery, description pages and actions.
local Dex = {}

local function describe(top, game, generation, previous)
  if type(top) ~= "table" then return end
  -- Game path [Gen 1/2/3]: each native Dex owns its own catalogue and pages; Gen 3 delegates to native_dex3.
  if generation == 3 then return Dex.describe3(top, game, previous) end
  if generation == 2 then
    if getmetatable(top) ~= require("src.ui.gen2.PokedexMenu") then return end
    if top.view == "list" then
      return { kind = "index", rows = top.rows, field = "index",
        region = top:mode(), tools = { { label = "OPTION", key = "select" }, { label = "SEARCH", key = "start" } } }
    elseif top.view == "entry" then
      local row = top:current()
      if not row then return end
      local entry = top.dex.entries[row.species] or {}
      return { kind = "profile", species = row.species, owned = row.caught, page = top.page,
        description = row.caught and ({ entry.text or "", entry.text2 or "" })[top.page] or "",
        field = top.newEntry and nil or "entryAction",
        actions = top.newEntry and { { label = "CONTINUE" } } or {
          { label = "PAGE" }, { label = "AREA" }, { label = "CRY" }, { label = "PRNT" } } }
    elseif top.view == "area" then
      local row = top:current()
      if not row then return end
      local region = top:areaRegionName()
      -- Game path [Gen 2]: Kanto area navigation is gated by Hall of Fame; roamers also change the native area markers.
      local unlocked = require("src.core.gen2.HallOfFame").hasEntered(game.save)
      local identity = { region, row.species, tostring(top.mapSheet), tostring(game.data.gen2Encounters),
        tostring(game.data.gen2Landmarks), tostring(game.data.gen2Maps) }
      for _, roamer in ipairs(game.save.roamers or {}) do
        identity[#identity + 1] = tostring(roamer.species) .. ":" .. tostring(roamer.map)
      end
      local areaKey = table.concat(identity, ":")
      local area = previous and previous.dex.areaKey == areaKey and previous.dex.area
      if not area then
        local Nests = require("src.core.gen2.Nests")
        local markers = {}
        for _, index in ipairs(Nests.find(game.data, row.species, region, game.save)) do
          local mark = Nests.landmark(game.data, index)
          if mark and mark.x and mark.y then markers[#markers + 1] = { x = mark.x, y = mark.y } end
        end
        local cells = top.mapGfx and top.mapGfx.maps and top.mapGfx.maps[region]
        area = { x = 0, y = 16, width = 160, height = 128, markers = markers,
          available = cells ~= nil and top.mapSheet ~= nil, unknown = #markers == 0,
          draw = function() top:drawTilemap(cells) end }
      end
      return { kind = "area", species = row.species, owned = row.caught, area = area, areaKey = areaKey,
        signature = areaKey .. ":" .. tostring(unlocked), region = region:upper(), compactActions = true,
        actions = { { label = "JOHTO", key = "left", inert = region == "johto" },
          { label = "KANTO", key = "right", inert = region == "kanto" or not unlocked }, { label = "ENTRY", key = "b" } } }
    -- Game path [Gen 2]: the Unown Dex records letters and form sprites separately from the ordinary species list.
    elseif top.view == "unown" then
      local Unown = require("src.core.gen2.Unown")
      local forms = top:unownDex()
      return { kind = "forms", rows = forms, signature = table.concat(forms, ","),
        region = require("src.core.Strings")(top.OPTION_MODES[4].label), caught = #forms,
        cursor = function() return (top.unownIndex or 0) + 1 end,
        select = function(index) top.unownIndex = index - 1 end,
        portrait = function(_, letter)
          local path = Unown.formSprite(top.pokemon, letter, false)
          if not path then return end
          local trueColor
          path, trueColor = require("src.pokemon.Sprites").pic(path,
            { species = Unown.SPECIES, side = "front", kind = "dex", letter = letter, data = game.data })
          if top.picCache[path] == nil then
            local ok, image = pcall(require("src.render.Assets").image, path)
            top.picCache[path] = ok and image or false
          end
          return top.picCache[path] or nil, trueColor
        end }
    elseif top.view == "option" then
      local rows = {}
      for _, row in ipairs(top:optionRows()) do rows[#rows + 1] = { label = require("src.core.Strings")(row.label) } end
      return { kind = "option", rows = rows, field = "optionIndex" }
    elseif top.view == "search" then
      return { kind = "search", field = "searchIndex", notice = top.searchMessage and require("src.core.Strings")(top.searchMessage),
        rows = { { label = "TYPE1", right = top:searchTypeName(1) },
          { label = "TYPE2", right = top:searchTypeName(2) },
          { label = "BEGIN SEARCH!!" }, { label = "CANCEL" } },
        search1 = top.searchType[1], search2 = top.searchType[2] }
    end
    return
  end
  -- Game path [Gen 1]: entries use owned flags, native cry/picture waits and TownMap nests rather than Gen 2 page state.
  if getmetatable(top) == require("src.ui.PokedexMenu") then
    return { kind = "index", rows = top.items, field = "index", caught = top.ownedCount, region = "KANTO DEX" }
  elseif getmetatable(top) == require("src.ui.DexEntryMenu") then
    local waiting = (top.picDelay or 0) > 0
    local crying = not waiting and top:crying()
    local owned = top.forceOwned or (game.save.pokedex.owned or {})[top.species]
    local source = owned and top.def.dexEntry and game.data.text[top.def.dexEntry.text] or ""
    local pages = {}
    for chunk in (tostring(source or "") .. "\f"):gmatch("(.-)\f") do
      if chunk:find("%S") then pages[#pages + 1] = chunk end
    end
    if #pages > 0 then pages[#pages] = pages[#pages] .. "." end
    return { kind = "profile", species = top.species, owned = owned and not waiting and not crying,
      page = top.page, description = pages[top.page] or "", waiting = waiting, crying = crying,
      actions = { { label = "CONTINUE" } } }
  elseif getmetatable(top) == require("src.ui.TownMap") and top.nestSpecies then
    local areaKey = tostring(top) .. ":" .. tostring(top.bg) .. ":" .. tostring(top.nests)
    local area = previous and previous.dex.areaKey == areaKey and previous.dex.area
    if not area then
      local markers = {}
      for _, loc in ipairs(top.nests or {}) do
        if loc.x and loc.y then markers[#markers + 1] = { x = loc.x * 8 + 20, y = loc.y * 8 + 12 } end
      end
      local bg = top.bg
      area = { x = 0, y = 8, width = 160, height = 136, markers = markers,
        available = top.mode == "grid" and bg ~= nil, unknown = #markers == 0,
        draw = function()
          love.graphics.setColor(1, 1, 1, 1)
          for i, tile in ipairs(bg.map) do
            love.graphics.draw(bg.img, bg.quads[tile], (i - 1) % 20 * 8, math.floor((i - 1) / 20) * 8)
          end
        end }
      local loc = top.playerLoc
      if #markers > 0 and loc and loc.x and loc.y then area.player = { x = loc.x * 8 + 20, y = loc.y * 8 + 12 } end
    end
    return { kind = "area", species = top.nestSpecies, owned = (game.save.pokedex.owned or {})[top.nestSpecies],
      area = area, areaKey = areaKey, signature = areaKey, region = "KANTO", compactActions = true,
      actions = { { label = "ENTRY", key = "b" } } }
  elseif getmetatable(top) == require("src.ui.Menu") then
    local parent = game.stack.states[#game.stack.states - 1]
    if parent and getmetatable(parent) == require("src.ui.PokedexMenu") and parent.hollowIndex then
      local row = parent.items[parent.hollowIndex]
      if row and row.value then
        return { kind = "profile", species = row.value, owned = (game.save.pokedex.owned or {})[row.value],
          field = "index", actions = top.items }
      end
    end
  end
end

local function key(top, state)
  return table.concat({ tostring(top), state.kind, tostring(state.species), tostring(state.page),
    tostring(state.owned), tostring(state.waiting), tostring(state.crying), tostring(state.description),
    tostring(state.search1), tostring(state.search2), tostring(state.notice), tostring(state.signature),
    (state.kind == "index" or state.kind == "forms") and tostring(state.rows) or "",
    (state.kind == "index" or state.kind == "forms") and tostring(math.floor(((state.cursor and state.cursor() or top[state.field]) - 1) / 9)) or "" }, ":")
end

function Dex.project(top, game, generation, previous)
  local state = describe(top, game, generation, previous)
  if not state then return end
  local nativeKey = key(top, state)
  local view = previous
  if not view or view.nativeKey ~= nativeKey then
    view = { screenId = "CompanionMenu", title = state.title or "POKEDEX", nativeKey = nativeKey,
      owner = top, fixedLayout = state.fixedLayout or state.actions ~= nil or state.kind == "index" or state.kind == "forms", back = state.back, update = function() end }
    view.valid = function(preview)
      -- Game path [Gen 3]: native menus use their global UI stack; the projected legacy stack cannot prove layer ownership.
      if generation == 3 then
        if require("src.ui.game3.stack").top() ~= top then return false end
      elseif game.stack:top() ~= top then return false end
      local current = describe(top, game, generation, view)
      return current and key(top, current) == nativeKey
        and (preview or not current.waiting and not current.crying)
        and (not current.valid or current.valid(preview))
    end
    setmetatable(view, { __index = function(_, name)
      if name == "index" then return state.cursor and state.cursor() or state.field and top[state.field] or 1 end
    end, __newindex = function(t, name, value)
      if name == "index" then
        if not t.valid() then return end
        if state.select then state.select(value); return end
        if not state.field then return end
        top[state.field] = value
        if top.ensureVisible then top:ensureVisible() elseif top.syncScroll then top:syncScroll() end
      else rawset(t, name, value) end
    end })
  end
  if state.kind == "forms" then
    local Unown = require("src.core.gen2.Unown")
    state.entries, view.items = {}, {}
    for i, letter in ipairs(state.rows) do
      state.entries[i] = { index = i, species = Unown.SPECIES, letter = letter,
        name = Unown.word(letter), seen = true, caught = true, revealed = true, selected = view.index == i }
      view.items[i] = { label = Unown.name(letter) or "?" }
    end
  elseif state.kind == "index" and view.dex then
    state.entries, state.caught = view.dex.entries, view.dex.caught
  elseif state.kind == "index" then
    if generation == 2 then local _, caught = top:totals(); state.caught = caught end
    state.entries = {}
    view.items = {}
    for i, row in ipairs(state.rows) do
      -- Game path [Gen 1/2/3]: Gen 1 rows encode species/seen state in value; later catalogues provide explicit species and seen fields.
      local species = generation >= 2 and row.species or row.value
      local def = species and game.data.pokemon[species] or {}
      local seen = generation >= 2 and row.seen or row.value ~= nil
      local entry = { index = i, species = species, dex = generation >= 2 and row.dex or tonumber(row.num),
        name = def.name or row.name, seen = seen, caught = generation >= 2 and row.caught or row.ball, revealed = seen }
      state.entries[i] = entry
      view.items[i] = { label = entry.name or "???", inert = not seen }
    end
  elseif state.actions then
    view.items = {}
    for i, row in ipairs(state.actions) do view.items[i] = { label = row.label, inert = row.inert } end
  else
    view.items = state.rows
    view.prompt = state.notice
  end
  view.actionKey = function(index) return state.actions[index].key or "a" end
  view.dex = state
  if #view.items == 0 then view.items[1] = { label = "NO DETAILS AVAILABLE", inert = true } end
  return view
end

function Dex.model(view, Page, pokemon, drawPokemon, lines)
  local state = view.dex
  if state.kind == "index" or state.kind == "forms" then
    local number = math.max(1, math.ceil(view.index / 9))
    local entries, page, pages = Page.window(state.entries, number, 9)
    if state.number then page, pages = state.number, state.pages end
    return { view = "index", forms = state.kind == "forms", entries = entries, page = page, pages = pages, canCycle = pages > 1,
      total = state.kind == "forms" and 26 or #state.entries, caught = state.caught, region = state.region, tools = state.tools,
      drawPokemon = drawPokemon, canUse = view.valid() }
  elseif state.kind == "profile" or state.kind == "cry" or state.kind == "size" or state.kind == "area" then
    local info = pokemon(state.species)
    info.revealed, info.caught = true, not not state.owned
    if state.hideKind then info.kind = "?????" end
    if not state.owned then info.height, info.weight = "--", "--" end
    if state.description ~= nil then info.descriptionText = state.description end
    info.description = state.owned and lines(info.descriptionText or "") or {}
    local model = { view = state.kind, pokemon = info, actions = view.items,
      drawPokemon = state.waiting and function() return false end or drawPokemon, canUse = view.valid(),
      -- cry and size use the slim key row too, so every research page shares
      -- one control bar and the instrument gets the room
      compactActions = state.compactActions or state.kind == "cry" or state.kind == "size" }
    if state.kind == "area" then
      model.area, model.region = state.area, state.region
      if state.comparison then
        model.combined = true
        model.areaViewport = { x = 14, y = 94, width = 96, height = 80 }
        model.comparison = Page.comparison(state.comparison, 130, 98, 96, 58)
      end
      return model
    elseif state.kind == "cry" then
      model.playing, model.wave = state.playing, state.wave
      return model
    elseif state.kind == "size" then
      model.caption, model.comparison = state.caption, Page.comparison(state.comparison, 15, 81, 210, 78)
      return model
    end
    return Page.description(view, model)
  end
end

function Dex.page(view, direction)
  if not view.valid() or view.dex.kind ~= "index" and view.dex.kind ~= "forms" or direction ~= 1 and direction ~= -1 then return false end
  if view.dex.cycle then
    if view.dex.pages <= 1 then return false end
    view.dex.cycle(direction); return true
  end
  local pages = math.ceil(#view.dex.entries / 9)
  if pages <= 1 then return false end
  local current = math.ceil(view.index / 9)
  view.index = ((current - 1 + direction) % pages) * 9 + 1
  return true
end

function Dex.redrawKey(model)
  local mon = model.pokemon or {}
  local parts = { tostring(model.page), tostring(model.caught), tostring(model.total),
    tostring(model.descriptionPage), tostring(mon.name), tostring(mon.height), tostring(mon.weight), tostring(mon.caught),
    tostring(model.playing), tostring(model.caption) }
  if model.area then
    parts[#parts + 1] = tostring(model.area) .. ":" .. tostring(model.region)
  end
  if model.wave then for i = 0, 15 do parts[#parts + 1] = tostring(model.wave[i] or 0) end end
  for _, row in ipairs(model.comparison or {}) do
    parts[#parts + 1] = tostring(row.image) .. ":" .. row.x .. ":" .. row.y .. ":" .. row.scale
  end
  for _, line in ipairs(mon.description or {}) do parts[#parts + 1] = line end
  for _, row in ipairs(model.entries or {}) do
    parts[#parts + 1] = tostring(row.species) .. tostring(row.name) .. tostring(row.revealed) .. tostring(row.caught)
      .. tostring(row.letter) .. tostring(row.selected)
  end
  return table.concat(parts, "\31")
end

return Dex
