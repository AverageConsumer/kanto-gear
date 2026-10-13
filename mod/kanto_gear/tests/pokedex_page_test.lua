local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local Page = display.PokedexPage
  local theme = up(display.drawContents, "THEME")
  assert(loadfile(path.."/tests/evolutions_cases.lua"))()(T,display,game,theme)
  T.eq(table.concat(theme:descriptionLines("FIRST\fSECOND\vTHIRD\nFOURTH",24,nil,210)," "),
    "FIRST SECOND THIRD FOURTH", "native page and line controls preserve word boundaries")
  for _, source in ipairs({
    "IN THE JUNGLE, ITS POWER IS WITHOUT EQUAL. THIS POKEMON CAREFULLY GROWS TREES AND PLANTS. IT REGULATES ITS BODY TEMPERATURE BY BASKING IN SUNLIGHT.",
    "A SHORT DESCRIPTION.",
    "FIRST\fSECOND\vTHIRD\nFOURTH",
  }) do
    local lines = theme:pokedexDescriptionLines(source)
    T.eq(table.concat(lines," "),source:gsub("%s+"," "),"description wrapping retains every word and punctuation")
    theme.hgss:v4Prose(function()
      for _, line in ipairs(lines) do
        T.eq(theme.hgss:fitPartyInfo(line,204),line,"description lines fit their actual prose lettering without ellipses")
      end
    end)
    local textState, reconstructed = { descriptionPage = 1 }, {}
    for page = 1, math.max(1,math.ceil(#lines/2)) do
      textState.descriptionPage = page
      local part = Page.description(textState,{pokemon={description=lines}})
      T.check(#part.pokemon.description <= 2,"description leaves breathing room above its page controls")
      for _, line in ipairs(part.pokemon.description) do reconstructed[#reconstructed+1] = line end
    end
    T.same(reconstructed,lines,"paging reaches the complete description in its original order")
  end
  local compose
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner == "kanto_gear" then compose = entry.callback end
  end
  local event = up(compose, "touchEvent")
  local tap, swipe = up(event, "tap"), up(event, "swipe")
  if generation == 3 then
    require("src.ui.game3.party_menu").close()
    require("src.ui.game3.bag_menu").close()
    require("src.ui.game3.stack").clear()
    require("src.ui.game3.message").reset()
    require("src.ui.game3.choice").reset()
    display.gen3.syncScreens(); up(compose, "refreshBattle")()
  else game.stack.states = { game.world } end
  display.setPackageInstalled("pokedex", true)
  local oldMotion, requests = display.requestPageMotion, 0
  display.requestPageMotion = function() requests = requests + 1 end
  for _, style in ipairs({ "hgss", "hgss_dark" }) do
    run.loader.modOptions.kanto_gear.theme_v3 = style
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = style })
    T.check(display.openHomeApp("pokedex"), "common Pokedex app opens")
    local state, dex = display.pokedex, display.pokedexData()
    local original = {}
    for _, entry in ipairs(dex.entries) do original[entry] = entry.revealed; entry.revealed = true end
    local model = display.pokedexModel()
    local function click(x,y) tap(x / 1.5, y / 1.5) end
    T.eq(model.pages, math.max(1, math.ceil(dex.total / 9)), "edition catalogue uses the common nine-card window")
    T.eq(model.total, #dex.entries, "catalogue size still comes from the live generation data")
    T.check(pcall(display.drawContents), "index renders in both themes")
    if model.pages > 1 then
      click(28, 13)
      T.eq(display.home.activeApp, "pokedex", "left-arrow edge never closes the app")
      T.eq(state.page, model.pages, "left-arrow edge wraps to the real last page")
      click(130, 13)
      T.eq(state.page, 1, "forward wraps from last page to first")
      swipe(-30, { y = 90 })
      T.eq(state.page, 2, "actual swipe advances the common catalogue window")
      swipe(30, { y = 90 })
      T.eq(state.page, 1, "reverse swipe restores the first window")
    end
    -- Hidden entries remain inert, including their visual press feedback.
    dex.entries[1].revealed = false
    local before = requests
    click(43, 88)
    T.eq(state.view, "index", "unknown Pokemon never open through the actual dispatcher")
    T.eq(requests, before, "unknown Pokemon do not request navigation")
    for _,area in ipairs({{x=0,y=16,width=160,height=128},{x=8,y=24,width=224,height=128}}) do
    local t=Page.areaTransform(area)
    T.check(math.abs(t.x+(area.x+area.width/2)*t.scale-120)<1e-10,
      "complete habitat atlas is centered horizontally including its source crop")
    T.check(math.abs(t.y+(area.y+area.height/2)*t.scale-128)<1e-10,
      "complete habitat atlas is centered vertically including its source crop")
    T.check(area.width*t.scale<=212 and area.height*t.scale<=90,"habitat fit preserves every edge without clipping routes")
    for _,edge in ipairs({t.x+area.x*t.scale,t.y+area.y*t.scale,area.width*t.scale,area.height*t.scale}) do
      T.eq(edge*1.5,math.floor(edge*1.5),"atlas crop edges land on exact pixels in the 1.5x Gear canvas")
    end
  end
  local atlas={x=0,y=0,width=96,height=72}
  local t=Page.areaTransform(atlas,{x=14,y=94,width=96,height=80})
  T.eq(t.scale,1,"small native FRLG atlas retains its original pixels")
  T.eq(t.x,14,"FRLG atlas fits its column with equal visible side gaps")
  T.eq(t.y,98,"FRLG atlas is centered below its label with equal top and bottom gaps")
  local area={view="area",compactActions=true,actions={{label="JOHTO",inert=true},{label="KANTO"},{label="ENTRY"}}}
  local x,y,w,h=Page.actionRect(2,3,true)
  T.eq(y,185,"habitat buttons leave the atlas's full content height")
  T.eq(h,25,"compact habitat row uses the shared small button height")
  T.eq(Page.hit(area,x+w/2,y+h/2),"action","compact touch target matches its visible action")
  T.eq(Page.hit(area,x+w/2,170),nil,"old tall button region is now static map space")
  x,y,w,h=Page.actionRect(1,3,true)
  T.eq(Page.hit(area,x+w/2,y+h/2),nil,"already selected region is inert")
  local H, presses = theme.hgss, 0
    local begin = H.beginPress
    H.beginPress = function(self, ...)
      local result = begin(self, ...)
      if result then presses = presses + 1 end
      return result
    end
    H:setTouch(43 / 1.5, 88 / 1.5, true); H:pokedex(display.pokedexModel())
    H:setTouch(nil, nil, true); H.beginPress = begin
    T.eq(presses, 0, "unknown Pokemon cards never animate themselves or a parent")
    dex.entries[1].revealed = true
    click(43, 88)
    T.eq(state.selected, dex.entries[1].species, "touch opens the exact real species")
    T.eq(state.view, "profile", "known entry opens its common profile")
    local species = state.selected
    local profile = display.pokedexModel()
    if profile.descriptionPages > 1 then
      before = requests
      click(149,145)
      T.eq(state.descriptionPage,2,"long native description remains readable on the next local text page")
      T.eq(state.selected,species,"description paging keeps the same Pokemon")
      T.eq(requests,before,"description paging does not slide unrelated content")
      click(91,145)
      T.eq(state.descriptionPage,1,"reverse description paging restores page one")
      swipe(-30,{x=100/1.5,y=120/1.5})
      T.eq(state.descriptionPage,2,"swiping inside the description advances only its text")
      T.eq(state.selected,species,"description swipe keeps the selected Pokemon")
      T.eq(requests,before,"description swipe leaves the surrounding profile still")
      swipe(30,{x=100/1.5,y=120/1.5})
      T.eq(state.descriptionPage,1,"reverse description swipe restores the text page")
      T.eq(state.selected,species,"reverse text swipe never changes Pokemon")
    end
    local describe = theme.pokedexDescriptionLines
    theme.pokedexDescriptionLines = function() return { "SHORT DESCRIPTION" } end
    before = requests
    swipe(-30,{x=100/1.5,y=120/1.5})
    T.eq(state.selected,species,"a single-page description never switches Pokemon on swipe")
    T.eq(requests,before,"a single-page description has no swipe animation")
    theme.pokedexDescriptionLines = describe
    swipe(-30,{x=100/1.5,y=107/1.5})
    T.eq(state.selected,dex.entries[2].species,"swiping above the description switches Pokemon")
    swipe(30,{x=100/1.5,y=152/1.5})
    T.eq(state.selected,species,"swiping below the description switches back")
    click(81, 183)
    T.eq(state.view, "profile", "research-card breathing room has no action")
    for index, action in ipairs(Page.cards) do
      local x,y,w,h = Page.cardRect(index)
      click(x+w/2,y+h/2)
      T.eq(state.view, action, "research cards use the shared geometry: " .. action)
      T.eq(state.selected, species, "research retains the selected species")
      local detail = display.pokedexModel()
      T.check(pcall(display.drawContents), "research view renders: " .. action)
      if action == "stats" then T.eq(#detail.stats, generation == 1 and 5 or 6, "Special follows the actual generation") end
      click(14,13)
      T.eq(state.view, "profile", "actual header back returns from research to the profile")
      T.eq(display.home.activeApp, "pokedex", "research back keeps the app open")
    end
    local def=(display.gen3 and display.gen3.data or game.data).pokemon[state.selected]
    local evolutions=def.evolutions
    local into=dex.entries[2].species
    def.evolutions={}
    for level=1,3 do
      def.evolutions[level]=generation==3 and {method=4,param=level,target=into}
        or {method=generation==2 and "EVOLVE_LEVEL" or "LEVEL",level=level,into=into,species=into}
    end
    local x,y,w,h=Page.cardRect(4);click(x+w/2,y+h/2)
    local detail=display.pokedexModel()
    T.eq(detail.pages,3,"all evolution branches are reachable")
    T.eq(detail.rows[1].species,into,"evolution page uses the active definition")
    T.eq(detail.rows[1].lines[1],"LEVEL UP: LV.1+","evolution conditions are visible in the actual model")
    click(149,205)
    T.eq(state.evolutionPage,2,"touch pager advances evolution choices")
    swipe(-30,{y=90})
    T.eq(state.evolutionPage,3,"swipe advances to the final evolution choice")
    click(149,205)
    T.eq(state.evolutionPage,1,"evolution choices wrap forward")
    click(91,205)
    T.eq(state.evolutionPage,3,"evolution choices wrap backward")
    local known=display.knownSpecies;display.knownSpecies=function() return false end
    detail=display.pokedexModel()
    T.eq(detail.rows[1].name,"???","hidden target names never leak through the actual model")
    T.eq(detail.rows[1].revealed,false,"hidden target sprites stay hidden")
    display.knownSpecies=known
    def.evolutions={};detail=display.pokedexModel()
    T.eq(detail.emptyText,"NO FURTHER EVOLUTION","final forms have an explicit empty state")
    T.eq(detail.canCycle,false,"final forms do not animate an inert pager")
    T.check(pcall(display.drawContents),"final-form state renders")
    def.evolutions=nil;detail=display.pokedexModel()
    T.eq(detail.emptyText,"NO EVOLUTION DATA AVAILABLE","missing native data has a different empty state")
    def.evolutions=evolutions;click(14,13)
    -- Forward/reverse species navigation preserves the research view and skips unknown rows.
    for i, entry in ipairs(dex.entries) do entry.revealed = i == 1 or i == #dex.entries end
    state.view = "stats"
    T.check(display.cyclePokedex(1), "known species navigation advances")
    T.eq(state.selected, dex.entries[#dex.entries].species, "unknown rows are skipped")
    T.eq(state.view, "stats", "species navigation preserves the research page")
    T.check(display.cyclePokedex(-1), "reverse species navigation advances")
    T.eq(state.selected, species, "reverse restores the same real species")
    dex.entries[#dex.entries].revealed = false
    before = requests
    T.eq(display.cyclePokedex(1), false, "one known species has no forward navigation")
    T.eq(display.cyclePokedex(-1), false, "one known species has no reverse navigation")
    T.eq(requests, before, "unchanged species never starts a page animation")
    click(14,13); click(14,13)
    T.eq(state.view, "index", "profile back returns to the catalogue")
    click(14,13)
    T.eq(display.home.activeApp, nil, "catalogue back returns Home")
    for entry, revealed in pairs(original) do entry.revealed = revealed end
  end
  -- Boundary cases independent of the size of any particular ROM catalogue.
  for count = 0, 4 do
    local cards = {}; for i = 1, count do cards[i] = Page.cards[i] end
    local profile = { view = "profile", cards = cards }
    for i, action in ipairs(cards) do
      local x,y,w,h = Page.cardRect(i,count)
      T.eq(Page.hit(profile,x+w/2,y+h/2),action,"custom research door uses its visible touch geometry")
      T.check(x>=7 and x+w<=233 and y>=156 and y+h<=210,"custom research door fits its available region")
    end
    if count == 0 then T.eq(Page.hit(profile,120,180),nil,"disabled research creates no hidden touch door") end
    if count == 3 then
      local x,_,w = Page.cardRect(3,count)
      T.eq(x,math.floor((240-w)/2),"last research door centers independently in an incomplete row")
    end
  end
  for _, point in ipairs({{7,108},{232,151},{120,140}}) do
    T.eq(Page.inDescription({view="profile"},point[1],point[2]),true,
      "description swipe zone includes the complete text frame and its pager")
  end
  for _, point in ipairs({{6,120},{233,120},{120,107},{120,152}}) do
    T.eq(Page.inDescription({view="profile"},point[1],point[2]),false,
      "outside the text frame swipes retain species navigation")
  end
  T.eq(Page.inDescription({view="stats"},120,120),false,"other research pages retain their own swipe navigation")
  local rows = { { species = "A", revealed = true, index = 1 } }
  local dex = { entries = rows, bySpecies = { A = rows[1] }, caught = 0, total = 1 }
  local state = { view = "index", page = 9 }
  local model = Page.index(state, dex, "KANTO DEX")
  T.eq(state.page, 1, "smaller catalogue clamps stale page state")
  T.eq(model.canCycle, false, "one-page catalogue has no arrows")
  T.eq(Page.hit(model,130,13), nil, "one-page header arrow is inert")
  T.eq(Page.hit(model,149,205), nil, "one-page footer arrow is inert")
  T.eq(Page.cycle(state,dex,model,1), false, "one-page swipe is inert")
  for _, kind in ipairs({ "moves", "habitat", "evolutions" }) do
    state.view = kind
    model = Page.controls({ view = kind, page = 1, pages = 1 }, dex)
    T.eq(Page.hit(model,91,205), nil, "one-page research pager is inert: " .. kind)
    T.eq(Page.cycle(state,dex,model,1), false, "one-page research does not animate: " .. kind)
  end
  local visible, number, pages = Page.window({}, 99, 9)
  T.eq(#visible, 0, "empty catalogue invents no species")
  T.eq(number, 1, "empty catalogue keeps a valid page number")
  T.eq(pages, 1, "empty catalogue has one empty page")
  T.eq(Page.select(state, { entries = {} }, 1), false, "empty catalogue cannot be selected")
  for count = 1, 9 do
    local rows = {}; for i = 1, count do rows[i] = {revealed=true} end
    local grid = {view="index",entries=rows}
    for i = 1, count do
      local x,y,w,h = Page.entryRect(i,count)
      local action,index = Page.hit(grid,x+w/2,y+h/2)
      T.eq(action,"species","centered card remains touchable")
      T.eq(index,i,"centered card retains native index")
    end
    local first = math.floor((count-1)/3)*3+1
    local left = Page.entryRect(first,count)
    local right,_,width = Page.entryRect(count,count)
    T.eq(left+right+width,240,"incomplete last row has equal visible edge gaps")
  end
  local text = { "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN" }
  state = { view = "profile", descriptionPage = 99 }
  model = Page.description(state, { view = "profile", pokemon = { description = text } })
  T.same(model.pokemon.description,{"SEVEN"},"long descriptions clamp to their exact last text page")
  T.eq(model.descriptionPages,4,"all description lines remain accessible above the pager")
  T.eq(#text,7,"paging never truncates the original description")
  T.check(Page.cycleDescription(state,model,1),"description wraps forward")
  T.eq(state.descriptionPage,1,"description wraps to page one")
  model = Page.description(state, { view = "profile", pokemon = { description = text } })
  T.same(model.pokemon.description,{"ONE","TWO"},"first page retains exact source order without overlapping the frame")
  T.check(Page.cycleDescription(state,model,-1),"description wraps backward")
  T.eq(state.descriptionPage,4,"description wraps to its last page")
  model = Page.description(state, { view = "profile", pokemon = { description = { "SHORT" } } })
  T.eq(Page.cycleDescription(state,model,1),false,"short descriptions never animate or page")
  T.eq(Page.hit(model,149,145),nil,"short description has no stray pager target")
  model = Page.description(state, { view = "profile", pokemon = { description = text } })
  for _, direction in ipairs({-1,1}) do
    local x,y,w,h = Page.pagerRect(direction,true)
    T.eq(Page.hit(model,x,y),direction<0 and "description_prev" or "description_next","description pager includes its drawn top-left boundary")
    T.eq(Page.hit(model,x+w,y),nil,"description pager excludes its outside right boundary")
    T.eq(Page.hit(model,x,y-1),nil,"description pager excludes empty space above it")
  end
  T.eq(Page.hit(model,110,145),nil,"description counter remains static")
  for _,scale in ipairs({64,256,2048}) do
    local rows = {
      {img={},x=88,y=56,y2=-12,scale=scale,bounds={7,17,53,59}},
      {img={},x=152,y=56,y2=8,scale=256,bounds={20,6,44,62}},
    }
    local fitted=Page.comparison(rows,15,82,210,53)
    local l,t,r,b=math.huge,math.huge,-math.huge,-math.huge
    for i,row in ipairs(fitted) do
      local bounds=rows[i].bounds
      l,t=math.min(l,row.x+(bounds[1]-32)*row.scale),math.min(t,row.y+(bounds[2]-32)*row.scale)
      r,b=math.max(r,row.x+(bounds[3]-32)*row.scale),math.max(b,row.y+(bounds[4]-32)*row.scale)
    end
    T.check(math.abs((l+r)/2-120)<1e-10 and math.abs((t+b)/2-108.5)<1e-10,
      "comparison centers the visible compound group rather than transparent image boxes")
    T.check(l>=15-1e-10 and r<=225+1e-10 and t>=82-1e-10 and b<=135+1e-10,
      "both extreme and small native silhouettes fit the same comparison card")
    T.check(math.abs(fitted[1].scale/fitted[2].scale-256/scale)<1e-10,
      "fitting never changes the native relative size")
  end
  T.eq(#Page.comparison({},15,82,210,53),0,"missing silhouettes invent no comparison")
  for _,kind in ipairs({"cry","size"}) do
    local special={view=kind,actions={{label="CRY"},{label="SIZE",inert=true}}}
    local x,y,w,h=Page.actionRect(1,2)
    T.eq(Page.hit(special,x+w/2,y+h/2),"action","special pages reuse the common action geometry")
    x,y,w,h=Page.actionRect(2,2)
    T.eq(Page.hit(special,x+w/2,y+h/2),nil,"inert special actions have no touch target")
    special.canUse=false
    T.eq(Page.hit(special,14,13),nil,"transition locks also cover the special page header")
  end
  local H, presses = theme.hgss, 0
  local begin = H.beginPress
  H.beginPress = function(self,...)
    local result=begin(self,...)
    if result then presses=presses+1 end
    return result
  end
  for _, point in ipairs({ {110,205}, {149,195} }) do
    local blocked = { view="index", entries={}, page=1, pages=2, canCycle=true }
    H:setTouch(point[1]/1.5,point[2]/1.5,true);H:pokedex(blocked)
    T.eq(Page.hit(blocked,point[1],point[2]),nil,"pager counter and surrounding space have no action")
  end
  local blocked = { view="index", entries={}, page=1, pages=2, canCycle=true, canUse=false }
  H:setTouch(149/1.5,205/1.5,true);H:pokedex(blocked)
  T.eq(Page.hit(blocked,149,205),nil,"disabled pager has no input target")
  local x,y,w,h=Page.actionRect(2,2)
  H:setTouch((x+w/2)/1.5,(y+h/2)/1.5,true)
  H:pokedexActions({actions={{label="CRY"},{label="SIZE",inert=true}}})
  T.eq(presses,0,"static and disabled pager regions never animate")
  local forms={view="index",forms=true,caught=1,total=26,entries={
    {species="UNOWN",name="ANGRY",letter=1,revealed=true,caught=true,selected=true} }}
  local x,y,w,h=Page.entryRect(1,1)
  H:setTouch((x+w/2)/1.5,(y+h/2)/1.5,true)
  H:pokedex(forms)
  T.eq(Page.hit(forms,x+w/2,y+h/2),nil,"selected Unown form has no redundant touch action")
  T.eq(presses,0,"selected Unown form never animates")
  forms.entries[1].selected=false
  H:pokedex(forms)
  T.eq(Page.hit(forms,x+w/2,y+h/2),"species","another Unown form is selectable")
  T.eq(presses,1,"another Unown form keeps touch feedback")
  H.beginPress=begin;H:setTouch(nil,nil,true)
  local stats, bst = Page.stats({ hp=10, attack=20, defense=30, special=40, speed=50 }, false)
  T.eq(#stats, 5, "Gen1 has one Special stat")
  T.eq(bst, 150, "Gen1 BST does not double-count Special")
  stats, bst = Page.stats({ hp=10, attack=20, defense=30, specialAttack=40, specialDefense=60, speed=50 }, true)
  T.eq(#stats, 6, "later generations split Special")
  T.eq(bst, 210, "later BST uses both actual Special values")
  display.requestPageMotion = oldMotion
end
if generation == 3 then
  local version = os.getenv("POKEPORT_VERSION")
  dofile(path .. (version == "emerald" and "/tests/emerald_runtime_test.lua"
    or (version == "ruby" or version == "sapphire") and "/tests/rs_runtime_test.lua"
    or "/tests/gen3_runtime_test.lua"))
else dofile(path .. "/tests/legacy_bag_test.lua") end
