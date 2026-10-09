-- Gen 3 catalogues retain internal species IDs and the native discovery rules.
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
    local s = native._s
    if not s then return end
    dex, session = s.dex, s.session
    if s.fn == "startMenu" then
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
    elseif s.page == Native.PAGE.INFO and s.info and s.info.dexNum or s.page == Native.PAGE.CAUGHT and s.caught then
      local caught = s.page == Native.PAGE.CAUGHT
      local info = caught and s.caught or s.info
      local text = info.text or {}
      local description = ""
      for _, part in ipairs(text) do if part.y == 95 then description = part.text end end
      state = { kind = "profile", species = Native.speciesOf(info.dexNum), owned = caught or info.owned,
        page = s.page, signature = tostring(s) .. ":" .. s.fn, description = description,
        waiting = s.fn ~= (caught and "caughtInput" or "infoInput"),
        actions = caught and { { label = "CONTINUE" } } or {
          { label = "AREA" }, { label = "CRY" }, { label = "SIZE", inert = not info.owned }, { label = "CANCEL" } },
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
    local pic = Pokemon.frontPic(Pokemon.picSpecies(sp, personality), nil, false, personality, "dex")
    return pic and pic.image
  end
  return state
end
return describe
