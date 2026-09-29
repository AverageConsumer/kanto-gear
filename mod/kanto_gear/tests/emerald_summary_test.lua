-- Exercise Gear touch/swipe navigation against Emerald's real summary skin.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local function up(fn, key)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, i)
    if name == key then return value end
  end
  error("missing upvalue " .. key)
end
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local compose
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner == "kanto_gear" then compose = entry.callback end
  end
  local touch = up(compose, "touchEvent")
  local tap, swipe = up(touch, "tap"), up(touch, "swipe")
  local theme = up(display.drawContents, "THEME")
  local compat = up(display.openPartySummary, "compat")
  local api = up(display.openPartySummary, "mod")
  local Summary = require("src.ui.game3.summary_menu")
  local Screens = require("src.ui.game3.screens")
  local Skin = require("src.ui.game3.rse.summary_menu")
  local Stack = require("src.ui.game3.stack")
  local nativeData = assert(loadfile(os.getenv("POKEPORT_GBA_CACHE") .. "/pokemon/contest_moves.lua"))()
  local queued
  api.input.tap = function(_, target, key)
    T.eq(target, game, "summary uses original host input identity")
    queued = key
  end
  local function settle()
    for _ = 1, 40 do Summary.update(1 / 60) end
    display.gen3.syncScreens()
    up(compose, "refreshBattle")()
  end
  local function step()
    if queued then
      Screens.handleInput("summary", Summary, { wasPressed=function(_, key) return key==queued end,
        isDown=function() return false end }, game.session)
      queued = nil
    end
    settle()
  end
  local function state() return display.gen3:gameView().stack:top() end
  local function arrow(x)
    tap(x / theme.hgssScale, 15 / theme.hgssScale); step()
  end
  Stack.clear(); require("src.ui.game3.message").reset()
  for _, style in ipairs({"hgss", "hgss_dark"}) do
    run.loader.modOptions.kanto_gear.theme_v3 = style
    run.loader.modOptions.kanto_gear.ui_motion = false
    run.loader.events:emit("mod.options_changed", {mod="kanto_gear",key="theme_v3"})
    Summary.openMenu(game.session.party, 1, {session=game.session,page=2})
    Skin.reset(); settle()
    T.eq(state().page, 3, "start on battle moves")
    arrow(110)
    T.eq(state().page, 4, "right arrow enters contest page")
    T.check(compat.summary.supports(state()), "contest list is supported")
    T.check(pcall(display.drawContents), style .. " contest list renders")
    local view = compat.summary.view(state(), display.gen3:gameView())
    T.eq(view.pages, 4, "pagination includes contest page")
    local first
    for slot, move in pairs(view.mon.moves) do
      first = first or slot
      local source = nativeData.moves[move.index]
      local effect = nativeData.effects[source.effect]
      T.eq(view.contest[slot].category, nativeData.categories[source.category], "category matches extracted ROM")
      T.eq(view.contest[slot].description, effect.description, "description matches extracted ROM")
      T.eq(view.contest[slot].appeal, effect.appeal==255 and "--" or tostring(math.floor(effect.appeal/10)), "appeal matches ROM")
      T.eq(view.contest[slot].jam, effect.jam==255 and "--" or tostring(math.floor(effect.jam/10)), "jam matches ROM")
    end
    T.check(first~=nil, "test Pokemon has contest moves")
    tap(100 / theme.hgssScale, (80+(first-1)*37) / theme.hgssScale)
    T.check(up(tap,"moveInfo")~=nil, "tap opens contest description")
    T.check(pcall(display.drawContents), style .. " contest description renders")
    T.eq(queued,nil,"reading a contest move does not activate native swap")
    tap(12 / theme.hgssScale, 15 / theme.hgssScale)
    T.eq(up(tap,"moveInfo"),nil,"back closes description")
    T.eq(state().page,4,"back from description stays on contest list")
    arrow(55); T.eq(state().page,3,"left arrow returns from contest")
    swipe(-50,{x=100,y=70}); step(); T.eq(state().page,4,"swipe reaches contest")
    swipe(50,{x=40,y=70}); step(); T.eq(state().page,3,"reverse swipe leaves contest")
    arrow(110); arrow(110); T.eq(state().page,4,"right at last page follows native boundary")
    arrow(12); T.check(not Summary.open,"back closes native summary")
    Stack.clear()
  end
end
dofile(path .. "/tests/emerald_runtime_test.lua")
