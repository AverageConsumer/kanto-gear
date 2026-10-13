-- Actual ROM catalogues and native handlers behind the shared Gen 3 Dex pages.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  -- The headless SDK omits this standard LÖVE primitive used by the trace.
  love.graphics.setLineStyle = love.graphics.setLineStyle or function() end
  local hoenn = display.gen3.hoenn
  local rs = display.gen3.rs
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
  local Native = require(hoenn and "src.ui.game3.rse.pokedex" or "src.ui.game3.pokedex")
  local Stack, Hud = require("src.ui.game3.stack"), require("src.ui.game3.hud")
  local Pokemon, Dex = display.gen3.Pokemon, display.gen3.Dex
  local api = up(display.saveHome, "mod")
  local compose
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner == "kanto_gear" then compose = entry.callback end
  end
  local swipe = up(up(compose, "touchEvent"), "swipe")
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
    if queued then tick(queued); tick() end
    return queued
  end
  local function action(index)
    local current = view()
    if rs and current.dexModel.view == "profile" and #current.items == 5 then index = index + 1 end
    local x, y, w, h = display.PokedexPage.actionRect(index, #current.items, current.dexModel.compactActions)
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
    if hoenn then waitFor(function() local s = Native.active(); return s and s.fn == "infoInput" end) end
  end
  local function render(name)
    local ok, err = xpcall(display.drawContents, debug.traceback)
    T.check(ok, "shared Dex renders " .. name .. ": " .. tostring(err))
    if _G.KANTO_GEAR_NATIVE_DEX3_RENDER then _G.KANTO_GEAR_NATIVE_DEX3_RENDER(display, name) end
  end
  local dex, first, third
  local function open()
    if hoenn then Native.reset() else Native.close() end
    Stack.clear(); require("src.ui.game3.message").reset(); require("src.ui.game3.choice").reset()
    dex = Dex.new(); game.session.dex = dex
    first, third = Pokemon.speciesFromNational(hoenn and 252 or 1), Pokemon.speciesFromNational(hoenn and 254 or 3)
    Dex.setCaught(dex, first); Dex.setSeen(dex, third)
    Dex.setSeen(dex, Pokemon.speciesFromNational(hoenn and 386 or 25))
    Native.show(dex, { session = game.session, mode = "kanto", onClose = function() closed = closed + 1 end })
    if hoenn then waitFor(function() return Native.active().fn == "mainInput" and Native.active().menuY == 0 end) end
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
    if list.dexModel.tools then
      T.eq(click(20, 56), nil, "the Dex lens is static and cannot trigger Search or Option")
      local x, y, w, h = display.PokedexPage.toolRect(1)
      T.check(x >= 58 and y >= 49 and y + h <= 64 and x + w < 144,
        "native Dex controls leave the device lens and status line unobstructed")
    end
    local Choice = require("src.ui.game3.choice")
    Choice.yesNo(function() end)
    T.check(display.startMenu().choiceState ~= nil,"independent choice overlay retains priority over Dex")
    T.check(not list.valid(),"background Dex rejects touch while a choice is open")
    Choice.reset()
    T.eq(click(120, 88), nil, "unknown entry rejects touch")
    click(130, 13)
    T.eq(view().dexModel.page, 2, "touch pagination reaches the next native window")
    T.check(not list.valid(), "previous native window rejects stale touches")
    if hoenn then
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
    if hoenn then
      T.eq(#profile.items,rs and 5 or 4,"native entry action count")
      if rs then
        local description, redraw = table.concat(profile.dexModel.pokemon.description,"\n"), display.StartMenu.redrawKey(profile)
        action(0)
        T.eq(Native.active().descriptionPage,1,"NEXT DATA selects the native second text page")
        T.check(table.concat(view().dexModel.pokemon.description,"\n") ~= description,"second description is mirrored")
        T.check(display.StartMenu.redrawKey(view()) ~= redraw,"text-page change invalidates the companion canvas")
        action(0)
        T.eq(table.concat(view().dexModel.pokemon.description,"\n"),description,"reverse text-page change restores the first description")
      end
      action(1); phase("areaInput")
      waitFor(function() local s=Native.active();return s.area.inputState==1 and not s.pal:fadeActive() end)
      local area=view()
      T.eq(area.dexModel.view,"area","Emerald habitat has a companion map page")
      T.eq(area.dex.areaKey,Native.active().area,"habitat retains the exact native area instance")
      T.eq(area.dexModel.area.markers,Native.active().area.markers,"special locations use the native marker positions")
      T.eq(area.dexModel.area.player,Native.active().area.player,"player position uses the native atlas coordinates")
      T.eq(area.dexModel.area.unknown,Native.active().area.unknown,"unknown-area rule is inherited from native data")
      T.eq(view().dexModel.area,area.dexModel.area,"unchanged habitat reuses its map projection")
      T.check(not profile.valid(),"entry actions expire when the area page opens")
      local stableArea=display.StartMenu.redrawKey(area)
      for _=1,40 do tick() end
      T.eq(display.StartMenu.redrawKey(view()),stableArea,"native glow animation does not repaint the steady companion atlas")
      T.eq(click(120,128),nil,"atlas artwork is static and never dispatches an action")
      render("area_unknown")
      -- Contrast test uses real imported area coverage; the native finder remains the oracle.
      local Area=require("src.ui.game3.rse.pokedex_area")
      local wild=Area.findMapsWithMon(Pokemon.speciesFromNational(263),Native.areaContext(Native.active()))
      T.check(#wild.overworld>0,"imported Zigzagoon habitat includes actual wild routes")
      T.eq(action(1),"right","habitat cry button dispatches native navigation")
      phase("cryInput");waitFor(function() return not Native.active().pal:fadeActive() end)
      T.check(not area.valid(),"leaving habitat expires its compact touch targets")
      click(14,13);phase("infoInput")
      local sWild=Native.active()
      local oldItem=sWild.list.items[sWild.selected]
      sWild.list.items[sWild.selected]={dexNum=263,seen=true,owned=false}
      action(1);phase("areaInput")
      waitFor(function() return sWild.area.inputState==1 and not sWild.pal:fadeActive() end)
      T.eq(view().dexModel.pokemon.species,Pokemon.speciesFromNational(263),"wild area retains its internal species identity")
      T.check(not view().dexModel.area.unknown,"actual wild habitat displays coverage instead of unknown")
      local sections,actual,expected={},{},{}
      local Region=require("src.ui.game3.rse.region_map")
      for _,found in ipairs(sWild.area.found.overworld) do sections[found.sec]=true end
      for y=0,19 do for x=0,31 do if sections[Region.mapSecAt(x,y)] then expected[y*32+x]=true end end end
      for _,cell in ipairs(view().dexModel.area.coverage) do
        for x=cell.x/8,(cell.x+cell.width)/8-1 do actual[(cell.y-8)/8*32+x]=true end
      end
      T.same(actual,expected,"merged companion coverage matches every native habitat atlas cell exactly")
      render("area_wild")
      click(14,13);phase("infoInput")
      sWild.list.items[sWild.selected]=oldItem
      -- Reload info for the restored species rather than leaving a mismatched fixture page.
      sWild.fn,sWild.state="loadInfo",0;phase("infoInput")
      action(2); phase("cryInput")
      waitFor(function() return not Native.active().pal:fadeActive() end)
      local s = Native.active()
      local cry = view()
      T.eq(cry.dexModel.view,"cry","native cry uses the common research hero and actions")
      T.eq(cry.dexModel.pokemon.species,first,"cry retains the actual selected species")
      T.check(not profile.valid(),"entry touch targets expire when cry opens")
      render("cry")
      local stable = display.StartMenu.redrawKey(view())
      T.eq(display.StartMenu.redrawKey(view()),stable,"idle cry preserves the companion canvas")
      local Audio = require("src.core.game3.audio")
      local play, played, species = Audio.playCry, 0
      Audio.playCry = function(sp,...)
        played, species = played + 1, sp
        return play(sp,...)
      end
      T.eq(action(2),"a","play dispatches the genuine native cry action")
      waitFor(function() return played > 0 end)
      T.eq(played,1,"one accepted touch plays the cry exactly once")
      T.eq(species,first,"the native audio handler receives the internal species ID")
      Audio.playCry = play
      T.check(view().items[2].inert,"native repeat cooldown disables the play tile")
      T.eq(action(2),nil,"cooldown rejects a second touch rather than animating an ineffective action")
      waitFor(function() return s.cry.cryRepeatDelay == 0 and s.cry.cryOverrideCountdown == 0 end)
      local pcm, playing, buffer = s.cry.pcm, s.cryPlaying, s.cry.buffer
      s.cryPlaying, s.cry.pcm = true, nil
      T.eq(view().dexModel.wave,nil,"missing PCM never invents waveform data")
      s.cry.pcm, s.cry.buffer = { data = string.rep("\127",64), rate = 13379 }, {}
      for i=0,15 do s.cry.buffer[i] = i%2==0 and 40 or 216 end
      cry = view()
      local oldKey, changed = cry.nativeKey, display.StartMenu.redrawKey(cry)
      T.eq(cry.dexModel.wave,s.cry.buffer,"waveform uses the native signed sample buffer without a copied image")
      s.cry.buffer[3] = 0
      T.check(display.StartMenu.redrawKey(view())~=changed,"actual sample changes invalidate the cry canvas")
      T.eq(view().nativeKey,oldKey,"sample changes do not invalidate accepted navigation targets")
      render("cry_signal_fixture")
      s.cry.pcm, s.cryPlaying, s.cry.buffer = pcm, playing, buffer
      T.eq(action(3),"right","size uses the native right action from cry")
      phase("sizeInput")
      local size = view()
      T.eq(size.dexModel.view,"size","native size uses the common comparison page")
      T.eq(#size.dexModel.comparison,2,"comparison contains the real Pokemon and trainer silhouettes")
      T.eq(size.dex.comparison[1].img,s.sizeMon.img,"comparison keeps the native form-aware Pokemon artwork")
      T.eq(size.dex.comparison[2].img,s.sizeTrainer.img,"comparison keeps the trainer selected by the native player gender")
      T.check(math.abs(size.dexModel.comparison[1].scale/size.dexModel.comparison[2].scale
        - s.sizeTrainer.scale/s.sizeMon.scale)<1e-10,"one shared fit preserves the exact ROM size ratio")
      local rows = size.dex.comparison
      T.eq(view().dex.comparison[1].bounds,rows[1].bounds,"visible bounds are cached instead of scanning pixels every poll")
      T.check(rows[1].bounds[1]>0 or rows[1].bounds[2]>0,"real imported Pokemon alpha bounds exclude transparent padding")
      local Paths = require("src.core.game3.cache_paths")
      local cache = Pokemon._cache or require("src.core.game3.dataset").cache()
      local root, readBytes, monImage, trainerImage = Paths.CACHE_ROOT, cache.read, s.sizeMon.img, s.sizeTrainer.img
      local reads = 0
      Paths.CACHE_ROOT = "fixture-active-import"
      cache.read = function(self,path)
        T.check(path:match("^fixture%-active%-import/")~=nil,"bounds follow the host's active dataset root")
        reads = reads + 1
        return readBytes(self,root..path:sub(#Paths.CACHE_ROOT+1))
      end
      s.sizeMon.img, s.sizeTrainer.img = {}, {}
      view();view()
      T.eq(reads,2,"each new image reads its active dataset once and then reuses bounds")
      s.sizeMon.img, s.sizeTrainer.img = monImage, trainerImage
      Paths.CACHE_ROOT, cache.read = root, readBytes
      T.eq(click(120,110),nil,"comparison artwork is static and has no hidden action")
      render("size")
      T.eq(action(1),"left","cry button returns through the native size handler")
      phase("cryInput");waitFor(function() return not s.pal:fadeActive() end)
      T.check(not size.valid(),"old comparison rejects taps after leaving")
      click(14,13);phase("infoInput")
      action(3);phase("sizeInput")
      T.eq(action(2),"b","entry button returns through the native size back action")
      phase("infoInput")
      T.eq(view().dexModel.pokemon.species,first,"return from size preserves the selected species")
      action(4)
      waitFor(function() return Native.active().fn == "mainInput" and Native.active().menuY == 0 end)
    else
      T.eq(action(2),"start","cry dispatches the actual native cry key")
      T.eq(Native.dataPage,1,"cry never switches to the next data page")
      action(1)
      T.eq(Native.dataPage,2,"next data retains native area/size page")
      T.check(not profile.valid(),"old profile cannot activate after native data page changes")
      local combined=view()
      T.eq(combined.dexModel.view,"area","FRLG second data page has a common habitat layout")
      T.check(combined.dexModel.combined,"native area and size remain available together")
      T.eq(#combined.dexModel.comparison,2,"caught FRLG entry includes both genuine silhouettes")
      T.eq(combined.dex.portrait(first),Pokemon.dexFrontPic(first,Dex.defaultPersonality(dex,first)).image,
        "FRLG portrait uses the native Dex form and color resolver")
      local entry=require("src.core.game3.pokedex_data").getEntry(first)
      T.check(math.abs(combined.dexModel.comparison[1].scale/combined.dexModel.comparison[2].scale
        - Native.silhouetteScale(entry.pokemonScale)/Native.silhouetteScale(entry.trainerScale))<1e-10,
        "FRLG comparison preserves the actual ROM ratio and offsets")
      T.eq(view().dex.area,combined.dex.area,"FRLG habitat metadata is reused while unchanged")
      T.eq(view().dex.comparison,combined.dex.comparison,"FRLG does not rebuild silhouette metadata each poll")
      T.eq(click(178,130),nil,"combined size artwork is static")
      render("area_size")
      T.eq(action(1),"start","combined cry uses the original FRLG audio handler")
      T.eq(Native.dataPage,2,"cry retains the combined native page")
      local gender=game.session.gender
      game.session.gender="female"
      local female=view()
      T.eq(female.dex.comparison[2].img,require("src.ui.game3.pokedex_chrome").getTrainerPic("female"),
        "FRLG size page follows the current player's actual trainer gender")
      T.check(not combined.valid(),"changed trainer context invalidates stale combined targets")
      render("area_size_female")
      game.session.gender=gender
      local pidgey=Pokemon.speciesFromNational(16)
      Dex.setCaught(dex,pidgey);Native.selectedSpecies=pidgey
      T.check(not view().dexModel.area.unknown,"actual FRLG wild species has native Kanto markers")
      render("area_size_wild")
      Native.selectedSpecies=first
      T.eq(action(2),"b","Entry returns through native previous-data input")
      T.eq(Native.dataPage,1,"Entry restores native FRLG data page one")
      action(1)
      T.eq(action(3),"a","Cancel closes through the native data-page action")
      T.eq(Native.screen,"ordered_list","combined cancel restores the original native catalogue")
    end
    click(197,88); ready()
    local unknown = view()
    T.eq(unknown.dexModel.pokemon.species,third,"seen-only species can be inspected")
    T.eq(unknown.dexModel.pokemon.height,"--","seen-only entry hides height")
    T.eq(unknown.dexModel.pokemon.weight,"--","seen-only entry hides weight")
    T.eq(#unknown.dexModel.pokemon.description,0,"seen-only entry hides owned description")
    T.eq(unknown.dexModel.pokemon.kind,"?????","seen-only Gen3 category remains hidden")
    if not hoenn then
      action(1)
      local hiddenArea=view()
      T.eq(#hiddenArea.dexModel.comparison,0,"seen-only FRLG entry never reveals size silhouettes")
      T.eq(hiddenArea.dexModel.pokemon.height,"--","combined page retains the native measurement restriction")
      render("area_size_seen_only")
      action(2)
    end
    if hoenn then
      T.eq(unknown.items[rs and 4 or 3].inert,true,"unowned size comparison is inert")
      T.eq(action(3),nil,"disabled size control sends no input")
      action(2);phase("cryInput")
      waitFor(function() return not Native.active().pal:fadeActive() end)
      T.eq(view().items[3].inert,true,"seen-only cry retains the native size restriction")
      T.eq(action(3),nil,"seen-only size cannot be opened from cry")
      click(14,13);phase("infoInput")
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
      local originalColor = criteria.items[2].right
      local language = run.loader.modOptions.kanto_gear.language
      run.loader.modOptions.kanto_gear.language = "de"
      T.eq(view().items[2].label,"FARBE","companion filter labels follow the Gear language")
      T.eq(view().items[2].right,originalColor,"native option values retain the game's text")
      render("criteria_de")
      run.loader.modOptions.kanto_gear.language = language
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
    if hoenn then Native.reset() else Native.close() end
    Stack.clear()
    local done = closed
    if hoenn then
      Native.showCaughtMon(first,{session=game.session,personality=123,onDone=function() closed=closed+1 end})
      waitFor(function() return Native.active().fn == "caughtInput" end)
    else Native.showRegistration(first,{session=game.session,onDone=function() closed=closed+1 end}) end
    local registration = view()
    T.eq(#registration.items,1,"registration offers only the genuine continue action")
    local nativePage = hoenn and Native.active().descriptionPage or Native.dataPage
    local pages = registration.dexModel.descriptionPages
    queued = nil
    display.pageChoice()
    T.eq(view().dexModel.descriptionPage,1,"gesture capability probe leaves registration text unchanged")
    swipe(-40,{x=80,y=85})
    T.eq(view().dexModel.descriptionPage,pages > 1 and 2 or 1,"registration swipe follows its local description pager")
    swipe(40,{x=80,y=85})
    T.eq(view().dexModel.descriptionPage,1,"reverse registration swipe restores the first description")
    T.eq(hoenn and Native.active().descriptionPage or Native.dataPage,nativePage,"swiping never advances native registration")
    T.eq(queued,nil,"swiping never queues a native confirm key")
    T.eq(closed,done,"swiping never runs the registration completion callback")
    render("registration")
    action(1)
    if rs then
      T.eq(Native.active().descriptionPage,1,"caught registration first reveals its second page")
      action(1)
    end
    if hoenn then waitFor(function() return Native.active() == nil end) end
    T.eq(closed,done+1,"registration invokes original callback exactly once")
    T.check(not registration.valid(),"closed registration rejects delayed touches")
  end
  if hoenn then
    local gender, playerGender = game.session.gender, game.session.playerGender
    local trainerImages = {}
    for _, test in ipairs({{321,"male","size_large"},{298,"female","size_small"},{327,"female","size_spinda"}}) do
      Native.reset();Stack.clear()
      local sp = Pokemon.speciesFromNational(test[1])
      dex = Dex.new();Dex.setCaught(dex,sp);dex.spindaPersonality=0x12345678
      game.session.dex,game.session.gender=dex,test[2]
      Native.show(dex,{session=game.session})
      phase("mainInput")
      local list=view()
      local found
      for i,row in ipairs(list.dex.rows) do if row.species==sp then found=i break end end
      T.check(found~=nil,"comparison fixture species exists in the real regional catalogue")
      T.check(display.StartMenu.select(list,found),"select the native comparison species")
      tick("a");phase("infoInput")
      action(3);phase("sizeInput")
      local size=view()
      T.eq(size.dexModel.pokemon.species,sp,"size resolves the correct internal ID for each ROM fixture")
      local s=Native.active()
      T.check(math.abs(size.dexModel.comparison[1].scale/size.dexModel.comparison[2].scale
        - s.sizeTrainer.scale/s.sizeMon.scale)<1e-10,"extreme native species preserve their calibrated size ratio")
      trainerImages[test[2]]=s.sizeTrainer.img
      if test[1]==327 then
        local pic=Pokemon.frontPic(Pokemon.picSpecies(sp,dex.spindaPersonality),nil,false,dex.spindaPersonality,"dex")
        T.eq(size.dex.comparison[1].img,pic.image,"Spinda comparison keeps the caught personality's spots")
      end
      render(test[3])
      action(2);phase("infoInput")
    end
    T.check(trainerImages.male~=trainerImages.female,"male and female comparisons retain distinct native trainer artwork")
    game.session.gender,game.session.playerGender=gender,playerGender
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
  if hoenn then Native.active().session = {} else Native._session = {} end
  T.eq(display.startMenu(),nil,"foreign session Dex cannot claim the lower screen")
  if hoenn then Native.active().session = oldSession; Native.reset() else Native._session = oldSession; Native.close() end
  Stack.clear()
  dex = Dex.new(); game.session.dex = dex
  Native.show(dex,{session=game.session,mode="kanto"})
  if hoenn then waitFor(function() return Native.active().fn == "mainInput" end) end
  local empty = view()
  T.eq(empty.dexModel.total,0,"empty native Dex invents no species")
  T.eq(#empty.dexModel.entries,0,"empty native Dex has no fake card")
  T.eq(display.NativeDex.page(empty,1),false,"empty native Dex has no pagination")
  if hoenn then Native.reset() else Native.close() end
  Stack.clear()
  game.session.dex, api.input.tap, game.input = oldDex, oldTap, oldInput
  love.graphics.newQuad = newQuad
  fs.read, fs.load, fs.getInfo = read, load, getInfo
  print("NATIVE_DEX3_CHECKED", os.getenv("POKEPORT_VERSION"))
end
dofile(path .. "/tests/gen3_fixture.lua")
