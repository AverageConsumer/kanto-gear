local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local function up(fn, key)
  for i=1,debug.getinfo(fn,"u").nups do
    local name,value=debug.getupvalue(fn,i); if name==key then return value end
  end
  error("missing upvalue "..key)
end
_G.KANTO_GEAR_RENDER_CAPTURE=function(run,display,game)
  local Stack=require("src.ui.game3.stack")
  local Native=require("src.ui.game3.summary_menu")
  local Message=require("src.ui.game3.message")
  local theme=up(display.drawContents,"THEME")
  local summaryView=up(up(display.drawContents,"drawBattleSummary"),"hgssRuntime").summaryView
  local compat=up(display.openPartySummary,"compat")
  local api=up(display.openPartySummary,"mod")
  local tap,swipe,refresh
  for _,entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner=="kanto_gear" then
      local touch=up(entry.callback,"touchEvent");tap,swipe=up(touch,"tap"),up(touch,"swipe")
      refresh=up(entry.callback,"refreshBattle")
    end
  end
  Native.close();Stack.clear();Message.reset();display.gen3.syncScreens();refresh()
  local queued={}
  api.input.tap=function(_,target,key) T.eq(target,game,"explicit native action keeps source game identity");queued[#queued+1]=key end
  local function tab(state,index)
    local x,y,w,h=display.SummaryPage.tabRect(state,index)
    tap((x+w/2)/theme.hgssScale,(y+h/2)/theme.hgssScale)
  end
  for _,style in ipairs({"hgss","hgss_dark"}) do
    run.loader.modOptions.kanto_gear.theme_v3=style
    run.loader.modOptions.kanto_gear.ui_motion=false
    run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3"})
    T.check(display.openPartySummary(1),"open independent companion summary")
    T.check(not Native.open,"local Stats does not open the original summary")
    local state=display.summaryContext()
    local model=summaryView(state)
    T.check(model.infoText~=nil and model.infoText~="","missing held items have a visible placeholder")
    local gender=state.mon.gender
    state.mon.gender="M";T.eq(summaryView(state).gender,"male","native male code becomes the common icon")
    state.mon.gender="F";T.eq(summaryView(state).gender,"female","native female code becomes the common icon")
    state.mon.gender=gender
    T.eq(state.pages,os.getenv("POKEPORT_VERSION")=="emerald" and 4 or 3,"capabilities add only supported tabs")
    local raw=game.session.party[1]
    for page=1,state.pages do
      tab(state,page)
      T.eq(state.page,page,"named tab selection")
      local ok,err=pcall(display.drawContents)
      T.check(ok,"shared page renders with extracted game data: "..tostring(err))
      local view=compat.summary.view(state,display.gen3:gameView())
      T.eq(view.hp,raw.hp,"HP comes from the real current partner")
      T.eq(view.stats.attack,raw.attack,"Attack retains the real Gen3 stat")
      T.eq(view.experience,raw.exp,"experience retains native Gen3 value")
      T.check(type(view.ability)=="string" and #view.ability>0,"ability uses native data")
      if page==4 then
        local data=require("src.core.game3.rse.contest").data()
        for slot,move in pairs(view.mon.moves) do
          local source=data.moves[move.index]
          local effect=data.effects[source.effect]
          T.eq(view.contest[slot].description,effect.description,"contest description matches native data")
          T.eq(view.contest[slot].appeal,effect.appeal==255 and "--" or tostring(math.floor(effect.appeal/10)),"appeal matches extracted ROM")
          T.eq(view.contest[slot].jam,effect.jam==255 and "--" or tostring(math.floor(effect.jam/10)),"jam matches extracted ROM")
        end
      end
      T.eq(#queued,0,"inspection never queues original-game input")
    end
    swipe(-50,{x=100,y=70});T.eq(state.page,1,"common swipe wraps every supported page")
    tap(12/theme.hgssScale,15/theme.hgssScale)
    T.eq(display.localSummary,nil,"touch Back closes local inspection")
    T.eq(#queued,0,"Back never leaks into the overworld")

    Native.openMenu(game.session.party,1,{session=game.session})
    for _=1,40 do Native.update(1/60) end
    display.gen3.syncScreens()
    local native=display.gen3:gameView().stack:top()
    local originalPage=native.page
    state=display.summaryContext(native)
    tab(state,2)
    T.eq(state.page,2,"original summaries use the same common companion tabs")
    display.gen3.syncScreens()
    T.eq(native.page,originalPage,"Gear tab changes never move the original summary")
    local slot=next(state.mon.moves)
    T.check(slot~=nil,"fixture has a real attack")
    tap(100/theme.hgssScale,(96+(slot-1)*32)/theme.hgssScale)
    T.check(up(tap,"moveInfo")~=nil,"shared move card opens read-only details")
    T.check(pcall(display.drawContents),"read-only move details render")
    T.eq(#queued,0,"move details send no game input")
    tap(12/theme.hgssScale,15/theme.hgssScale)
    T.eq(up(tap,"moveInfo"),nil,"Back closes only move details")
    T.eq(state.page,2,"detail return retains the selected shared tab")
    Native.close();Stack.clear();display.gen3.syncScreens()
    T.eq(display.summaryContext(),nil,"native closing invalidates its projection")
  end
end
dofile(path..(os.getenv("POKEPORT_VERSION")=="emerald" and "/tests/emerald_runtime_test.lua" or "/tests/gen3_runtime_test.lua"))
