-- Actual ROM catalogues and native handlers behind the shared Gen 3 Dex pages.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local function up(fn, key)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, i)
    if name == key then return value end
  end
end
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local emerald = os.getenv("POKEPORT_VERSION") == "emerald"
  -- Native RSE scenes read LÖVE's mounted cache; the headless SDK needs the same files exposed.
  local fs = love.filesystem
  local read, load, getInfo = fs.read, fs.load, fs.getInfo
  local function rawCache(file)
    if not file:match("^data/generated/gba/") then return end
    local f = io.open(os.getenv("POKEPORT_GBA_CACHE") .. "/" .. file:gsub("^data/generated/gba/", ""), "rb")
    if not f then return end
    local bytes = f:read("*a"); f:close(); return bytes
  end
  fs.read = function(file) return rawCache(file) or read(file) end
  fs.load = function(file)
    local bytes = rawCache(file)
    if bytes then
      local ok, Blob = pcall(require, "src.import.CacheBlob")
      return assert(loadstring(ok and Blob.decode(file, bytes) or bytes, "@" .. file))
    end
    return load(file)
  end
  fs.getInfo = function(file)
    local bytes = rawCache(file)
    if bytes then return { type = "file", size = #bytes } end
    return getInfo(file)
  end
  local Native = require(emerald and "src.ui.game3.rse.pokedex" or "src.ui.game3.pokedex")
  local Stack, Hud = require("src.ui.game3.stack"), require("src.ui.game3.hud")
  local Pokemon, Dex = display.gen3.Pokemon, display.gen3.Dex
  local api = up(display.saveHome, "mod")
  local oldTap, oldInput, oldDex = api.input.tap, game.input, game.session.dex
  local newQuad = love.graphics.newQuad
  love.graphics.newQuad = function(x, y, w, h, ...)
    local quad = newQuad(x, y, w, h, ...)
    if not quad.getViewport then quad.getViewport = function() return x, y, w, h end end
    return quad
  end
  local queued, closed = nil, 0
  api.input.tap = function(_, target, key) T.eq(target, game, "Dex input targets the actual game"); queued = key end
  local function tick(key)
    game.input = { wasPressed = function(_, k) return k == key end, isDown = function() return false end }
    require("src.core.game3.audio").tickCry(1 / 60)
    Hud.update(game, 1 / 60)
  end
  local function waitFor(fn)
    for _ = 1, 300 do
      if fn() then return end
      tick()
    end
    error("native Dex did not reach the expected input phase")
  end
  local function view()
    display.gen3:refresh(); display.gen3.syncScreens()
    return assert(display.startMenu(), "native Gen3 Dex has a shared page")
  end
  local function click(x, y)
    queued = nil
    display.tapStartMenu(view(), x / 1.5, y / 1.5)
    if queued then tick(queued) end
    return queued
  end
  local function action(index)
    local current = view()
    local x, y, w, h = display.PokedexPage.actionRect(index, #current.items)
    return click(x + w / 2, y + h / 2)
  end
  local function menuRow(index)
    local current = view()
    local first, count = display.StartMenu.window(current)
    while index < first or index >= first + count do
      display.pageChoice(index < first and -1 or 1)
      current = view(); first, count = display.StartMenu.window(current)
    end
    local rect = current.items[index].rect
    if rect then return click(rect[1] + rect[3] / 2, rect[2] + rect[4] / 2) end
    return click(120, display.StartMenu.y + (index - first) * display.StartMenu.step + 14)
  end
  local function phase(name) waitFor(function() return Native.active().fn == name end) end
  local function ready()
    if emerald then waitFor(function() local s = Native.active(); return s and s.fn == "infoInput" end) end
  end
  local function render(name)
    local ok, err = xpcall(display.drawContents, debug.traceback)
    T.check(ok, "shared Dex renders " .. name .. ": " .. tostring(err))
    if _G.KANTO_GEAR_NATIVE_DEX3_RENDER then _G.KANTO_GEAR_NATIVE_DEX3_RENDER(display, name) end
  end
  local dex, first, third
  local function open()
    if emerald then Native.reset() else Native.close() end
    Stack.clear(); require("src.ui.game3.message").reset(); require("src.ui.game3.choice").reset()
    dex = Dex.new(); game.session.dex = dex
    first, third = Pokemon.speciesFromNational(emerald and 252 or 1), Pokemon.speciesFromNational(emerald and 254 or 3)
    Dex.setCaught(dex, first); Dex.setSeen(dex, third)
    Dex.setSeen(dex, Pokemon.speciesFromNational(emerald and 386 or 25))
    Native.show(dex, { session = game.session, mode = "kanto", onClose = function() closed = closed + 1 end })
    if emerald then waitFor(function() return Native.active().fn == "mainInput" and Native.active().menuY == 0 end) end
    return view()
  end
  for _, style in ipairs({ "hgss", "hgss_dark" }) do
    run.loader.modOptions.kanto_gear.theme_v3 = style
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = style })
    local list = open()
    T.eq(list.dexModel.view, "index", "native list uses the common nine-card index")
    T.eq(#list.dexModel.entries, 9, "native list exposes nine real rows")
    T.eq(list.dexModel.entries[1].species, first, "native regional order uses internal species IDs")
    T.eq(list.dexModel.entries[2].revealed, false, "unseen species remains hidden")
    T.eq(view().dex.rows, list.dex.rows, "unchanged native list reuses catalogue projection")
    local key = display.StartMenu.redrawKey(view())
    T.eq(display.StartMenu.redrawKey(view()), key, "unchanged native list preserves its canvas")
    render("index")
    local Choice = require("src.ui.game3.choice")
    Choice.yesNo(function() end)
    T.check(display.startMenu().choiceState ~= nil,"independent choice overlay retains priority over Dex")
    T.check(not list.valid(),"background Dex rejects touch while a choice is open")
    Choice.reset()
    T.eq(click(120, 88), nil, "unknown entry rejects touch")
    click(130, 13)
    T.eq(view().dexModel.page, 2, "touch pagination reaches the next native window")
    T.check(not list.valid(), "previous native window rejects stale touches")
    if emerald then
      local s = Native.active()
      T.eq(s.selected, 9, "Emerald pagination updates its zero-based cursor")
      T.eq(s.fn, "mainInput", "pagination does not restart a loading fade")
      T.eq(s.rows[10].num, string.format("%03d",Native.hoennNumber(s.list.items[9].dexNum)), "native top-screen row buffer follows touch pagination")
    end
    display.pageChoice(-1)
    T.eq(view().dexModel.page, 1, "reverse pagination restores first native window")
    click(43,88); ready()
    local profile = view()
    T.eq(profile.dexModel.view,"profile","native entry uses common profile")
    T.eq(profile.dexModel.pokemon.species,first,"entry retains selected native identity")
    T.check(profile.dexModel.pokemon.height ~= "--", "caught entry exposes measurements")
    T.check(#profile.dexModel.pokemon.description > 0,"caught entry exposes real native description")
    render("profile")
    if emerald then
      T.eq(#profile.items,4,"Emerald keeps AREA CRY SIZE CANCEL actions")
      action(4)
      waitFor(function() return Native.active().fn == "mainInput" and Native.active().menuY == 0 end)
    else
      T.eq(action(2),"start","cry dispatches the actual native cry key")
      T.eq(Native.dataPage,1,"cry never switches to the next data page")
      action(1)
      T.eq(Native.dataPage,2,"next data retains native area/size page")
      T.check(not profile.valid(),"old profile cannot activate after native data page changes")
      tick("b"); tick("b")
    end
    click(197,88); ready()
    local unknown = view()
    T.eq(unknown.dexModel.pokemon.species,third,"seen-only species can be inspected")
    T.eq(unknown.dexModel.pokemon.height,"--","seen-only entry hides height")
    T.eq(unknown.dexModel.pokemon.weight,"--","seen-only entry hides weight")
    T.eq(#unknown.dexModel.pokemon.description,0,"seen-only entry hides owned description")
    T.eq(unknown.dexModel.pokemon.kind,"?????","seen-only Gen3 category remains hidden")
    if emerald then
      T.eq(unknown.items[3].inert,true,"unowned size comparison is inert")
      T.eq(action(3),nil,"disabled size control sends no input")
      action(4); waitFor(function() return Native.active().fn == "mainInput" and Native.active().menuY == 0 end)
      T.eq(click(60,56),"select","search tool dispatches the native select key")
      waitFor(function() return Native.active().fn ~= "mainInput" end)
      T.check(Native.active().search ~= nil,"search tool opens the original native search")
      phase("searchTopBar")
      local search = view()
      T.eq(search.dex.kind,"search","search opens on shared action rows")
      T.same({search.items[1].label,search.items[2].label,search.items[3].label},
        {"SEARCH","OPTION","CANCEL"},"native search and listing options stay distinct")
      render("search")
      menuRow(1); phase("searchMenu")
      local s = Native.active()
      T.check(not s.nationalEnabled,"fixture starts without National Dex access")
      local criteria = view()
      T.eq(#criteria.items,6,"locked National Dex mode is absent from search criteria")
      T.eq(criteria.items[6].label,"BEGIN SEARCH!!","execute retains its real native row")
      render("criteria")
      menuRow(2); phase("searchParam")
      local before = s.searchState.cursor[Native.SEARCH.COLOR]
      render("colors")
      T.eq(view().title,"COLOR","parameter title identifies the actual filter")
      menuRow(7); phase("searchMenu")
      local colorOptions = Native.searchOptionTexts and Native.searchOptionTexts(Native.SEARCH.COLOR)
        or require("src.ui.game3.rse.pokedex_gfx").manifest().search.colors
      local topUpdated=false
      for _,part in ipairs(s.searchText) do if part.text==colorOptions[7].title then topUpdated=true end end
      T.check(topUpdated,"touch selection updates the original upper-screen option text")
      T.eq(s.searchState.cursor[Native.SEARCH.COLOR]+s.searchState.scroll[Native.SEARCH.COLOR],6,
        "second option page confirms the exact native color")
      T.check(not criteria.valid(),"changed filters invalidate old criterion rows")
      menuRow(2); phase("searchParam")
      display.pageChoice(-1)
      T.eq(s.searchState.cursor[Native.SEARCH.COLOR]+s.searchState.scroll[Native.SEARCH.COLOR],0,
        "reverse touch pagination reaches the first native option")
      click(14,13); phase("searchMenu")
      T.eq(s.searchState.cursor[Native.SEARCH.COLOR]+s.searchState.scroll[Native.SEARCH.COLOR],6,
        "cancel restores the previously confirmed option across native scroll offsets")
      menuRow(1); phase("searchParam")
      menuRow(1); phase("searchMenu")
      menuRow(2); phase("searchParam")
      menuRow(3); phase("searchMenu") -- Blue: none of the fixture's seen species.
      menuRow(6); phase("searchDone")
      T.eq(s.list.count,0,"native search genuinely reports no blue matches")
      local none = view()
      T.eq(none.prompt,s.searchState.message,"no-match message comes from native search")
      T.eq(click(14,13),nil,"result message exposes no ineffective back action")
      render("no_matches")
      menuRow(1); phase("searchMenu")
      T.check(not none.valid(),"dismissed result message rejects stale continuation")
      menuRow(2); phase("searchParam")
      menuRow(1); phase("searchMenu") -- Clear the color filter.
      menuRow(3); phase("searchParam")
      local sm = require("src.ui.game3.rse.pokedex_gfx").manifest().search
      local grass
      for i, id in ipairs(sm.typeIds) do if id == display.gen3.Types.ID.GRASS then grass = i end end
      T.check(grass and grass > 5,"fixture exercises a later page of real native types")
      menuRow(grass); phase("searchMenu")
      render("type_criteria")
      menuRow(6); phase("waitSearch")
      local busy = view()
      T.check(not busy.valid(),"search processing never accepts a premature touch")
      phase("searchDone")
      T.eq(s.list.count,1,"type filter obeys native owned-only rule")
      T.eq(Native.speciesOf(s.list.items[0].dexNum),first,"search matches the actual caught grass species")
      menuRow(1); phase("mainInput")
      T.check(s.isSearchResults,"continue opens the actual native search-results list")
      T.eq(view().dexModel.total,1,"shared results contain only the real matches")
      T.eq(view().dexModel.entries[1].species,first,"result card retains internal species identity")
      render("results")
      click(14,13); phase("returnFromResults"); phase("mainInput")
      T.check(not s.isSearchResults,"back from results restores the original catalogue")
      click(60,56); phase("searchTopBar")
      menuRow(2); phase("searchMenu")
      T.eq(#view().items,2,"listing options expose only reachable order and apply when locked")
      menuRow(1); phase("searchParam")
      menuRow(2); phase("searchMenu")
      menuRow(2); phase("mainInput")
      T.eq(game.session.pokedex.order,sm.orderIds[2],"apply writes the native selected listing order")
      T.eq(view().dexModel.total,3,"alphabetical listing retains all and only seen native species")
      render("sorted")
      -- Reopening and cancelling a pending order must retain the committed order.
      click(60,56); phase("searchTopBar")
      menuRow(2); phase("searchMenu")
      menuRow(1); phase("searchParam")
      menuRow(1); phase("searchMenu")
      click(14,13); phase("searchTopBar")
      menuRow(3); phase("mainInput")
      T.eq(game.session.pokedex.order,sm.orderIds[2],"cancel never applies an uncommitted native order")
      game.session.pokedex.order=0
    else
      tick("b"); tick("b")
      local modes = view()
      T.eq(modes.dex.kind,"option","native table of contents uses common action rows")
      for i, row in ipairs(Native.MODES) do
        T.eq(modes.items[i].inert,row.isHeader or row.unlocked == false,"headers and locked categories are inert")
      end
      local Data = require("src.core.game3.pokedex_data")
      for i, row in ipairs(Native.MODES) do
        if row.type == "habitat" and row.unlocked then
          T.check(display.StartMenu.select(modes,i),"touch selects original habitat index")
          tick("a")
          local category = view()
          local pages = Data.getUnlockedCategoryPages(row.id,dex)
          T.eq(category.dexModel.total,#pages[Native.categoryPage].mons,"category shows exactly native unlocked page members")
          T.eq(category.dexModel.pages,#pages,"habitat page count is native")
          render("category")
          if #pages == 1 then
            T.eq(display.NativeDex.page(category,1),false,"single native habitat page has no navigation")
          end
          tick("b"); break
        end
      end
    end
    if emerald then Native.reset() else Native.close() end
    Stack.clear()
    local done = closed
    if emerald then
      Native.showCaughtMon(first,{session=game.session,personality=123,onDone=function() closed=closed+1 end})
      waitFor(function() return Native.active().fn == "caughtInput" end)
    else Native.showRegistration(first,{session=game.session,onDone=function() closed=closed+1 end}) end
    local registration = view()
    T.eq(#registration.items,1,"registration offers only the genuine continue action")
    render("registration")
    action(1)
    if emerald then waitFor(function() return Native.active() == nil end) end
    T.eq(closed,done+1,"registration invokes original callback exactly once")
    T.check(not registration.valid(),"closed registration rejects delayed touches")
  end
  if emerald then
    open()
    local session, flags, vars = game.session, game.session.flags, game.session.vars
    game.session.flags, game.session.vars = {}, {}
    Dex.enableNational(session)
    local kanto = Pokemon.speciesFromNational(1)
    Dex.setCaught(dex,kanto)
    Native.reset(); Stack.clear()
    Native.show(dex,{session=session})
    phase("mainInput")
    click(60,56); phase("searchTopBar")
    menuRow(1); phase("searchMenu")
    T.eq(#view().items,7,"native National unlock exposes its real mode criterion")
    menuRow(6); phase("searchParam")
    T.eq(#view().items,2,"unlocked mode exposes actual Hoenn and National choices")
    menuRow(2); phase("searchMenu")
    menuRow(7); phase("searchDone")
    menuRow(1); phase("mainInput")
    T.eq(Native.active().dexMode,1,"native search applies National mode after unlocking")
    local found=false
    for _,entry in ipairs(view().dexModel.entries) do if entry.species==kanto then found=true end end
    T.check(found,"National results include caught species outside the Hoenn catalogue")
    render("national_results")
    Native.reset(); Stack.clear()
    session.flags, session.vars = flags, vars
    session.pokedex.mode,session.pokedex.order=0,0
  end
  open()
  local oldSession = game.session
  if emerald then Native.active().session = {} else Native._session = {} end
  T.eq(display.startMenu(),nil,"foreign session Dex cannot claim the lower screen")
  if emerald then Native.active().session = oldSession; Native.reset() else Native._session = oldSession; Native.close() end
  Stack.clear()
  dex = Dex.new(); game.session.dex = dex
  Native.show(dex,{session=game.session,mode="kanto"})
  if emerald then waitFor(function() return Native.active().fn == "mainInput" end) end
  local empty = view()
  T.eq(empty.dexModel.total,0,"empty native Dex invents no species")
  T.eq(#empty.dexModel.entries,0,"empty native Dex has no fake card")
  T.eq(display.NativeDex.page(empty,1),false,"empty native Dex has no pagination")
  if emerald then Native.reset() else Native.close() end
  Stack.clear()
  game.session.dex, api.input.tap, game.input = oldDex, oldTap, oldInput
  love.graphics.newQuad = newQuad
  fs.read, fs.load, fs.getInfo = read, load, getInfo
  print("NATIVE_DEX3_CHECKED", os.getenv("POKEPORT_VERSION"))
end
dofile(path .. (os.getenv("POKEPORT_VERSION") == "emerald" and "/tests/emerald_runtime_test.lua" or "/tests/gen3_runtime_test.lua"))
