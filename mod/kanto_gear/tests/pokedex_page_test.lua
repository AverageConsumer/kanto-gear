local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local generation = tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
local function up(fn, key)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, i)
    if name == key then return value end
  end
end
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local Page = display.PokedexPage
  local theme = up(display.drawContents, "THEME")
  T.eq(table.concat(theme:descriptionLines("FIRST\fSECOND\vTHIRD\nFOURTH",24,nil,210)," "),
    "FIRST SECOND THIRD FOURTH", "native page and line controls preserve word boundaries")
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
    end
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
  local rows = { { species = "A", revealed = true, index = 1 } }
  local dex = { entries = rows, bySpecies = { A = rows[1] }, caught = 0, total = 1 }
  local state = { view = "index", page = 9 }
  local model = Page.index(state, dex, "KANTO DEX")
  T.eq(state.page, 1, "smaller catalogue clamps stale page state")
  T.eq(model.canCycle, false, "one-page catalogue has no arrows")
  T.eq(Page.hit(model,130,13), nil, "one-page header arrow is inert")
  T.eq(Page.hit(model,149,205), nil, "one-page footer arrow is inert")
  T.eq(Page.cycle(state,dex,model,1), false, "one-page swipe is inert")
  for _, kind in ipairs({ "moves", "habitat" }) do
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
  local text = { "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN" }
  state = { view = "profile", descriptionPage = 99 }
  model = Page.description(state, { view = "profile", pokemon = { description = text } })
  T.same(model.pokemon.description,{"SEVEN"},"long descriptions clamp to their exact last text page")
  T.eq(model.descriptionPages,3,"all description lines remain accessible")
  T.eq(#text,7,"paging never truncates the original description")
  T.check(Page.cycleDescription(state,model,1),"description wraps forward")
  T.eq(state.descriptionPage,1,"description wraps to page one")
  model = Page.description(state, { view = "profile", pokemon = { description = text } })
  T.same(model.pokemon.description,{"ONE","TWO","THREE"},"first page retains exact source order")
  T.check(Page.cycleDescription(state,model,-1),"description wraps backward")
  T.eq(state.descriptionPage,3,"description wraps to its last page")
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
  T.eq(presses,0,"static and disabled pager regions never animate")
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
  dofile(path .. (os.getenv("POKEPORT_VERSION") == "emerald" and "/tests/emerald_runtime_test.lua" or "/tests/gen3_runtime_test.lua"))
else dofile(path .. "/tests/legacy_bag_test.lua") end
