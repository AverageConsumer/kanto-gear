local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local generation = assert(tonumber(arg[1]))
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local Native = require(generation == 2 and "src.ui.gen2.PokedexMenu" or "src.ui.PokedexMenu")
  local api, theme = up(display.saveHome, "mod"), up(display.drawContents, "THEME")
  local originalTap, oldInput = api.input.tap, game.input
  local compose
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner == "kanto_gear" then compose = entry.callback end
  end
  local touchEvent = up(compose, "touchEvent")
  local tap, swipe = up(touchEvent, "tap"), up(touchEvent, "swipe")
  local queued, closed = nil, 0
  api.input.tap = function(_, target, key) T.eq(target, game, "Dex input retains its game identity"); queued = key end
  local function tick(key)
    game.input = { wasPressed = function(_, k) return k == key end, isDown = function() return false end }
    game.stack:top():update(1 / 60)
  end
  local function view()
    return assert(display.startMenu(), "native Dex has a companion projection")
  end
  local function click(x, y)
    queued = nil; tap(x / 1.5, y / 1.5)
    if queued then tick(queued) end
    return queued
  end
  local oldPokemon, oldDex, oldGen2 = game.data.pokemon, game.save.pokedex, game.data.gen2Pokedex
  local oldSize, oldText = game.data.constants.dexSize, game.data.text.DEX_TEXT
  local pokemon, entries, order = {}, {}, {}
  for i = 1, 14 do
    local id = "DEX_FIX_" .. i
    order[i] = id
    pokemon[id] = { id = id, dex = i, name = "MON " .. i, types = { "NORMAL" },
      baseStats = { hp = 20, attack = 30, defense = 40, special = 50, speed = 60 },
      dexEntry = { kind = "TEST", heightFt = 1, heightIn = 2, weight = 120, text = "DEX_TEXT" } }
    entries[id] = { dex = i, kind = "TEST", height = 102, weight = 120,
      text = "FIRST<NEXT>NATIVE<NEXT>PAGE", text2 = "SECOND<NEXT>NATIVE<NEXT>PAGE" }
  end
  game.data.pokemon = pokemon
  game.data.text.DEX_TEXT = "FIRST\nNATIVE\nPAGE\fSECOND\nNATIVE\nPAGE"
  game.data.gen2Pokedex = { entries = entries, newOrder = order, alphabeticalOrder = order }
  game.save.pokedex = { seen = {}, owned = {}, caught = {} }
  for i, id in ipairs(order) do
    game.save.pokedex.seen[id] = i ~= 2
    game.save.pokedex.owned[id], game.save.pokedex.caught[id] = i == 1, i == 1
  end
  game.data.constants.dexSize = 14
  for _, style in ipairs({ "hgss", "hgss_dark" }) do
    run.loader.modOptions.kanto_gear.theme_v3 = style
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = style })
    game.stack.states = { game.world }
    local native = Native.new(game, { onClose = function() game.stack:pop(); closed = closed + 1 end,
      onCancel = function() closed = closed + 1 end })
    game.stack:push(native)
    local list = view()
    T.eq(list.dexModel.view, "index", "native catalogue uses the shared nine-card page")
    T.eq(#list.dexModel.entries, 9, "first native window has nine actual rows")
    T.eq(list.dexModel.total, 14, "native catalogue boundary is preserved")
    T.eq(list.dexModel.caught, 1, "native ownership count is preserved")
    T.eq(list.dexModel.entries[2].revealed, false, "unknown entries remain hidden")
    if list.dexModel.tools then
      T.eq(click(20, 56), nil, "the Dex lens is static and cannot trigger Search or Option")
    end
    local key = display.StartMenu.redrawKey(list)
    T.eq(display.StartMenu.redrawKey(view()), key, "unchanged native Dex reuses its canvas")
    T.eq(view().dex.entries,list.dex.entries,"unchanged catalogue reuses its projected rows")
    T.check(pcall(display.drawContents), "native index renders in " .. style)
    if generation == 2 then
      local original, species = native.picFor, {}
      native.picFor = function(self,id) species[#species+1]=id; return original(self,id) end
      display.drawContents()
      native.picFor = original
      T.eq(species[1],order[1],"native Dex art resolver retains first-seen Unown/form hooks")
      T.eq(#species,8,"unknown entries never ask the native art resolver for a portrait")
    end
    if _G.KANTO_GEAR_NATIVE_DEX_RENDER then _G.KANTO_GEAR_NATIVE_DEX_RENDER(display, style, "index") end
    T.eq(click(120, 88), nil, "unknown native Pokemon cannot activate")
    T.eq(native.index, 1, "unknown touch cannot move native focus")
    T.eq(click(130, 13), nil, "touch pagination does not queue hardware input")
    T.eq(native.index, 10, "forward pagination synchronizes the actual native cursor")
    T.check(not list.valid(), "old list page rejects delayed touches")
    T.eq(view().dexModel.page, 2, "second window follows native focus")
    display.pageChoice(-1)
    T.eq(native.index, 1, "reverse swipe restores the actual first native row")
    click(43, 88)
    local profile = view()
    T.eq(profile.dexModel.pokemon.species, order[1], "native selection preserves the exact species")
    T.eq(profile.dexModel.view, "profile", "native profile uses the shared renderer")
    local actions = {}
    for _, row in ipairs(profile.items) do actions[#actions + 1] = row.label end
    if generation == 1 then
      T.eq(#actions, #game.stack:top().items, "Gen1 retains its native side actions")
      T.eq(table.concat(profile.dexModel.pokemon.description," "),"FIRST NATIVE PAGE SECOND NATIVE PAGE",
        "Gen1 native form-feed separates words in the common profile")
      local oldTownMap, oldEncounters = game.data.field.townMap, game.data.encounters
      game.data.field.townMap = { background = oldTownMap and oldTownMap.background, locations = {
        AREA_FIX_1 = { name = "ROUTE 1", x = 3, y = 4 },
        AREA_FIX_2 = { name = "ROUTE 1", x = 3, y = 4 },
        AREA_FIX_3 = { name = "ROUTE 2", x = 5, y = 8 },
        AREA_FIX_SKIP = { name = "UNKNOWN", x = 9, y = 1 } } }
      game.data.encounters = {}
      for _, id in ipairs({ "AREA_FIX_1", "AREA_FIX_2", "AREA_FIX_3", "AREA_FIX_SKIP" }) do
        game.data.encounters[id] = { grass = { slots = { { species = order[1] } } } }
      end
      local x,y,w,h = display.PokedexPage.actionRect(3,#actions)
      click(x+w/2,y+h/2)
      local area, atlas = view(), game.stack:top()
      T.eq(area.dexModel.view,"area","Gen1 native nests use the shared habitat page")
      T.eq(#area.dexModel.area.markers,2,"native nests retain deduplication and excluded map cells")
      local coords = {}
      for _, mark in ipairs(area.dexModel.area.markers) do coords[mark.x..":"..mark.y] = true end
      T.check(coords["44:44"] and coords["60:76"],"Gen1 markers use the center of the native nest icon")
      T.eq(view().dexModel.area,area.dexModel.area,"unchanged native nest data reuses its projection")
      local stable = display.StartMenu.redrawKey(area)
      for _=1,40 do tick() end
      T.eq(display.StartMenu.redrawKey(view()),stable,"native nest blinking does not redraw the companion atlas")
      T.eq(click(120,128),nil,"Gen1 habitat artwork has no hidden action")
      T.check(pcall(display.drawContents),"Gen1 native habitat renders in "..style)
      if _G.KANTO_GEAR_NATIVE_DEX_RENDER then _G.KANTO_GEAR_NATIVE_DEX_RENDER(display,style,"area") end
      local oldBg, drawn = atlas.bg, 0
      atlas.bg = { img = {}, quads = { [0] = {} }, map = {} }
      for i=1,360 do atlas.bg.map[i] = 0 end
      local oldDraw = love.graphics.draw
      love.graphics.draw = function(img,quad,tx,ty)
        T.eq(img,atlas.bg.img,"native habitat retains its original texture")
        T.eq(quad,atlas.bg.quads[0],"native habitat retains its original tile")
        T.eq(tx,(drawn%20)*8,"native habitat tile column is unchanged")
        T.eq(ty,math.floor(drawn/20)*8,"native habitat tile row is unchanged")
        drawn=drawn+1
      end
      view().dexModel.area.draw()
      love.graphics.draw, atlas.bg = oldDraw, oldBg
      T.eq(drawn,360,"Gen1 atlas draws the complete native tilemap")
      atlas.nests={}
      T.eq(view().dexModel.area.unknown,true,"empty native nests show unknown instead of inventing locations")
      atlas.bg=nil
      T.eq(view().dexModel.area.available,false,"missing native artwork stays unavailable")
      x,y,w,h=display.PokedexPage.actionRect(1,1,true)
      T.eq(click(x+w/2,y+h/2),"b","Gen1 Entry follows the native map close handler")
      T.eq(game.stack:top(),native,"Gen1 habitat returns to its catalogue")
      T.check(not area.valid(),"closed native area rejects delayed touch input")
      game.data.field.townMap,game.data.encounters=oldTownMap,oldEncounters
      local plain = require("src.ui.TownMap").new(game)
      T.eq(display.NativeDex.project(plain,game,1),nil,"normal and Fly maps are not mistaken for Dex nests")
      click(43,88)
      local x, y, w, h = display.PokedexPage.actionRect(1, #actions)
      click(x + w / 2, y + h / 2)
      local pending = view()
      T.eq(display.StartMenu.cursor(pending), nil, "entry input waits for native portrait/cry")
      T.check(display.StartMenu.cursor(pending, true), "waiting entry remains drawable")
      T.eq(click(120, 182), nil, "waiting entry cannot queue a confirmation")
      for _ = 1, 40 do tick() end
      profile = view()
      T.check(not pending.valid(), "waiting view cannot activate after readiness changes")
      T.eq(#profile.items, 1, "Gen1 entry exposes only its native Continue action")
    else
      T.same(actions, { "PAGE", "AREA", "CRY", "PRNT" }, "Gen2 retains all four native profile actions")
      T.eq(native.page, 1, "Gen2 starts on native description page one")
      local x,y,w,h = display.PokedexPage.actionRect(1,4)
      click(x+w/2,y+h/2)
      T.eq(native.page, 2, "Page action changes the actual cart description page")
      T.check(not profile.valid(), "old profile page rejects delayed touches")
      T.eq(table.concat(view().dexModel.pokemon.description, " "), "SECOND NATIVE PAGE", "page two displays its own native text")
      click(x+w/2,y+h/2)
      T.eq(native.page, 1, "Page action returns to the first native page")
      x,y,w,h = display.PokedexPage.actionRect(3,4)
      click(x+w/2,y+h/2)
      T.eq(native.view, "entry", "Cry stays on the original entry")
      local oldEnc,oldMaps,oldLandmarks,oldHof,oldRoamers=game.data.gen2Encounters,game.data.gen2Maps,
        game.data.gen2Landmarks,game.save.hallOfFame,game.save.roamers
      game.data.gen2Maps={ AREA_FIX_J={landmark=1},AREA_FIX_K={landmark=46},AREA_FIX_R={landmark=2} }
      game.data.gen2Landmarks={order={[2]="LANDMARK_FIX_J",[3]="LANDMARK_FIX_R",[47]="LANDMARK_PALLET_TOWN"},
        landmarks={LANDMARK_FIX_J={index=1,x=48,y=40},LANDMARK_FIX_R={index=2,x=80,y=72},
          LANDMARK_PALLET_TOWN={index=46,x=48,y=112}}}
      game.data.gen2Encounters={grass={AREA_FIX_J={slots={night={{species=order[1]}}}},
        AREA_FIX_K={slots={day={{species=order[1]}}}}},water={}}
      game.save.hallOfFame={count=0};game.save.roamers={{species=order[1],map="AREA_FIX_R",hp=0}}
      x,y,w,h=display.PokedexPage.actionRect(2,4);click(x+w/2,y+h/2)
      local area=view()
      T.eq(area.dexModel.view,"area","Gen2 nest page uses the common habitat atlas")
      T.eq(#area.dexModel.area.markers,2,"all-day native nests include a never-met active roamer")
      T.eq(area.dexModel.area.markers[1].x,48,"native landmark coordinates are preserved")
      T.eq(area.dexModel.region,"JOHTO","native habitat starts in Johto")
      T.eq(view().dexModel.area,area.dexModel.area,"unchanged nest data reuses the projection")
      local oldGfx,oldSheet=native.mapGfx,native.mapSheet
      local tiles,drawn={},0
      for i=1,360 do tiles[i]=i%8 end
      native.mapGfx={maps={johto=tiles,kanto=tiles}}
      native.mapSheet={draw=function(_,id,tx,ty)
        T.eq(id,tiles[ty*20+tx+1],"companion atlas draws the native row-major tile value")
        drawn=drawn+1
      end}
      local withMap=view()
      T.check(withMap.dexModel.area.available,"native map metadata enables the atlas renderer")
      withMap.dexModel.area.draw()
      T.eq(drawn,360,"companion uses the full native tilemap without its old title or blinking markers")
      native.mapGfx,native.mapSheet=oldGfx,oldSheet
      area=view()

      local stable=display.StartMenu.redrawKey(area)
      for _=1,40 do tick() end
      T.eq(display.StartMenu.redrawKey(view()),stable,"native nest blink does not redraw the companion atlas")
      x,y,w,h=display.PokedexPage.actionRect(2,3,true)
      T.eq(click(x+w/2,y+h/2),nil,"Kanto is inert before native Hall of Fame unlock")
      T.eq(native:areaRegionName(),"johto","locked region cannot move native focus")
      T.eq(click(120,128),nil,"habitat artwork has no hidden touch action")
      if _G.KANTO_GEAR_NATIVE_DEX_RENDER then _G.KANTO_GEAR_NATIVE_DEX_RENDER(display,style,"area_locked") end
      game.save.hallOfFame.count=1
      T.check(not area.valid(),"unlock changes invalidate old area touch targets")
      T.eq(click(x+w/2,y+h/2),"right","unlocked Kanto follows the native right handler")
      local kanto=view()
      T.eq(kanto.dexModel.region,"KANTO","native region selection updates the companion")
      T.eq(#kanto.dexModel.area.markers,1,"Kanto map contains only its own native nests")
      T.eq(kanto.dexModel.area.markers[1].y,112,"Kanto marker retains its original position")
      x,y,w,h=display.PokedexPage.actionRect(1,3,true)
      T.eq(click(x+w/2,y+h/2),"left","Johto button returns via native input")
      T.check(not kanto.valid(),"previous region rejects delayed touches")
      game.save.roamers[1].species=nil
      T.eq(#view().dexModel.area.markers,1,"caught roamer disappears from the nest projection")
      x,y,w,h=display.PokedexPage.actionRect(3,3,true)
      T.eq(click(x+w/2,y+h/2),"b","Entry returns through the native area handler")
      T.eq(native.view,"entry","habitat returns to the original entry")
      game.data.gen2Encounters,game.data.gen2Maps,game.data.gen2Landmarks=oldEnc,oldMaps,oldLandmarks
      game.save.hallOfFame,game.save.roamers=oldHof,oldRoamers

    end
    profile = view()
    T.check(pcall(display.drawContents), "native profile renders in " .. style)
    if _G.KANTO_GEAR_NATIVE_DEX_RENDER then _G.KANTO_GEAR_NATIVE_DEX_RENDER(display, style, "profile") end
    T.check(profile.dexModel.pokemon.height ~= "--", "owned entry retains its actual measurement")
    if generation == 1 then
      click(120, 183)
      T.eq(game.stack:top().page, 2, "Continue advances the actual native Gen1 page")
      T.eq(table.concat(view().dexModel.pokemon.description, " "), "SECOND NATIVE PAGE.", "Gen1 page two retains native text and terminator")
      click(120, 183)
      T.eq(game.stack:top(), native, "Continue closes the final native entry page")
    else
      click(10,13)
      T.eq(native.view, "list", "Back returns to the native catalogue")
      click(43,88)
      click(10,13)
      click(60,56)
      T.eq(native.view, "option", "visible Option action opens native sort choices")
      T.eq(#view().items, #native:optionRows(), "locked Unown option is not fabricated")
      click(120,77)
      T.eq(native:mode(), "OLD", "sort choice executes the actual native option")
      T.eq(native.view, "list", "native sort returns to its catalogue")
      click(170,56)
      T.eq(native.view, "search", "visible Search action opens the native filter")
      local search = view()
      if _G.KANTO_GEAR_NATIVE_DEX_RENDER then _G.KANTO_GEAR_NATIVE_DEX_RENDER(display, style, "search") end
      T.eq(search.items[1].right, native:searchTypeName(1), "search displays the actual selected type")
      local before = native.searchType[1]
      click(120,45)
      T.check(native.searchType[1] ~= before, "touch cycles the native type criterion")
      T.check(not search.valid(), "old search criterion rejects delayed touches")
      click(10,13)
      T.eq(native.view, "list", "search cancel returns to the original catalogue")
      local Unown = require("src.core.gen2.Unown")
      local oldFlags,oldForms = game.save.engineFlags,game.save.unownDex
      game.save.engineFlags = { [Unown.ENGINE_UNOWN_DEX] = true }
      game.save.unownDex = { 26,1,3,7,9,11,15,17,19,21,23,25 }
      pokemon.UNOWN = oldPokemon.UNOWN or { id="UNOWN",name="UNOWN",types={"PSYCHIC"} }
      click(60,56)
      click(120,139)
      local forms=view()
      T.eq(native.view,"unown","unlocked native option opens actual Unown mode")
      T.eq(forms.dexModel.forms,true,"Unown forms use the common touch grid")
      T.eq(forms.dexModel.entries[1].letter,26,"form catalogue retains catching order, not alphabet order")
      T.eq(forms.dexModel.entries[1].name,Unown.word(26),"form cards retain their native words")
      T.eq(forms.dexModel.caught,12,"Unown counter counts caught forms")
      T.eq(forms.dexModel.total,26,"Unown counter uses the full Gen2 alphabet")
      local Sprites,Assets=require("src.pokemon.Sprites"),require("src.render.Assets")
      local oldPic,oldImage=Sprites.pic,Assets.image
      local oldArt=pokemon.UNOWN.letters
      pokemon.UNOWN.letters={ Z={spriteFront="test-unown-z.png"}, A={spriteFront="test-unown-a.png"} }
      local requested={}
      Sprites.pic=function(path,ctx)
        requested[#requested+1]={path=path,letter=ctx.letter,kind=ctx.kind}
        return path..".hooked",true
      end
      Assets.image=function(path) return {path=path} end
      local z,tc=forms.dex.portrait("UNOWN",26)
      local a=forms.dex.portrait("UNOWN",1)
      T.eq(z.path,"test-unown-z.png.hooked","form portrait uses the exact form and preserves sprite mod hooks")
      T.eq(a.path,"test-unown-a.png.hooked","different forms cannot share the species portrait")
      T.eq(requested[1].letter,26,"sprite hook receives the actual letter")
      T.eq(requested[1].kind,"dex","form portrait retains its native sprite context")
      T.eq(tc,true,"true-color form hook retains its palette contract")
      Sprites.pic,Assets.image=oldPic,oldImage
      native.picCache["test-unown-z.png.hooked"],native.picCache["test-unown-a.png.hooked"]=nil,nil
      pokemon.UNOWN.letters=oldArt
      local stable=display.StartMenu.redrawKey(forms)
      T.eq(display.StartMenu.redrawKey(view()),stable,"unchanged forms keep their canvas")
      T.eq(click(43,88),nil,"current form is inert")
      T.eq(click(120,88),nil,"form selection does not send A, which would exit Unown mode")
      T.eq(native.unownIndex,1,"form touch synchronizes the zero-based native cursor")
      T.eq(native.view,"unown","selecting a form leaves the native form page open")
      T.check(display.StartMenu.redrawKey(view())~=stable,"selected form refreshes the selected border")
      T.check(pcall(display.drawContents),"Unown forms render in "..style)
      if _G.KANTO_GEAR_NATIVE_DEX_RENDER then _G.KANTO_GEAR_NATIVE_DEX_RENDER(display,style,"forms") end
      display.pageChoice(1)
      T.eq(native.unownIndex,9,"pagination keeps the actual native form cursor in its visible page")
      T.eq(#view().dexModel.entries,3,"last form page has only the caught entries")
      T.check(not forms.valid(),"old form page rejects delayed touches")
      tick("right")
      T.eq(view().dexModel.entries[2].selected,true,"hardware input and companion highlight stay synchronized")
      game.save.unownDex={}
      native.unownIndex=0
      local empty=view()
      T.eq(#empty.dexModel.entries,0,"empty unlocked form mode invents no caught form")
      T.eq(empty.dexModel.canCycle,false,"empty form mode has no pagination")
      T.check(pcall(display.drawContents),"empty form mode stays drawable")
      click(10,13)
      T.eq(native.view,"option","Back uses the actual native form return route")
      click(10,13)
      game.save.engineFlags,game.save.unownDex=oldFlags,oldForms
      pokemon.UNOWN=nil
    end
    -- Uncaught information stays hidden even when Gear's spoiler option is enabled.
    native.index = 3
    if native.ensureVisible then native:ensureVisible() else native:syncScroll() end
    tick("a")
    local hidden = view().dexModel.pokemon
    T.eq(hidden.height, "--", "native seen-only entry hides measurements")
    T.eq(#hidden.description, 0, "native seen-only entry hides description")
    T.eq(game.save.pokedex.owned[order[3]], false, "projection never grants ownership")
  end
  for count = 1, 5 do
    local model = { view = "profile", actions = {} }
    for i = 1, count do model.actions[i] = { label = "ACTION" } end
    for i = 1, count do
      local x,y,w,h = display.PokedexPage.actionRect(i,count)
      local hit, index = display.PokedexPage.hit(model,x+w/2,y+h/2)
      T.eq(hit,"action","native action geometry accepts the visible button")
      T.eq(index,i,"native action geometry identifies its exact slot")
      T.eq(display.PokedexPage.hit(model,x-1,y+h/2),nil,"native action gap stays inert")
    end
  end
  game.stack.states = { game.world }
  local done = 0
  if generation == 1 then
    local Entry = require("src.ui.DexEntryMenu")
    game.data.text.DEX_TEXT = string.rep("REGISTRATION TEXT ", 8) .. "\fSECOND PAGE"
    local entry = Entry.new(game, { species = order[3], forceOwned = true }, function() done = done + 1 end)
    game.stack:push(entry)
    for _ = 1, 40 do tick() end
    T.check(view().dexModel.pokemon.height ~= "--", "scripted preview honors native forceOwned")
    T.check(#view().dexModel.pokemon.description > 0, "scripted preview keeps its native description")
    local nativePage = entry.page
    queued = nil
    swipe(-40,{x=80,y=85})
    T.eq(view().dexModel.descriptionPage,2,"Gen1 registration swipe advances local text")
    swipe(40,{x=80,y=85})
    T.eq(view().dexModel.descriptionPage,1,"Gen1 registration reverse swipe restores local text")
    T.eq(entry.page,nativePage,"Gen1 swipes never advance native registration")
    T.eq(queued,nil,"Gen1 swipes never queue confirmation")
    T.eq(done,0,"Gen1 swipes never close registration")
    click(120,183);click(120,183)
  else
    entries[order[1]].text = string.rep("REGISTRATION TEXT ", 8)
    local entry = Native.new(game,{ entrySpecies = order[1], newEntry = true,
      onClose = function() game.stack:pop(); done = done + 1 end })
    game.stack:push(entry)
    T.eq(#view().items,1,"new registration only offers its native Continue action")
    local registration = view()
    T.eq(registration.dexModel.descriptionPages,2,"registration fixture has two local text pages")
    local nativePage = entry.page
    queued = nil
    display.pageChoice()
    T.eq(view().dexModel.descriptionPage,1,"gesture capability probe does not advance text")
    swipe(-40,{x=80,y=85})
    T.eq(view().dexModel.descriptionPage,2,"registration swipe shows the next local text page")
    swipe(40,{x=80,y=85})
    T.eq(view().dexModel.descriptionPage,1,"reverse registration swipe restores the first text page")
    T.eq(entry.page,nativePage,"description swipes leave the native registration page intact")
    T.eq(queued,nil,"description swipes never queue native confirmation")
    T.eq(done,0,"description swipes do not close registration")
    click(120,183)
    T.eq(entry.page,2,"registration advances its actual second description page")
    click(120,183)
  end
  T.eq(done,1,"final registration/preview page runs the original completion callback once")
  T.eq(game.stack:top(),game.world,"completed entry restores the native world")
  T.eq(game.save.pokedex.owned[order[3]],false,"scripted preview does not mutate ownership")
  game.data.pokemon, game.save.pokedex, game.data.gen2Pokedex = oldPokemon, oldDex, oldGen2
  game.data.constants.dexSize, game.data.text.DEX_TEXT = oldSize, oldText
  game.input, api.input.tap = oldInput, originalTap
end
dofile(path .. "/tests/legacy_bag_test.lua")
T.finish("Native Dex Gen " .. generation)
