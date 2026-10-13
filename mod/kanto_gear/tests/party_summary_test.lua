-- Shared companion pages must inspect real partners without native UI side effects.
local T = require("tests.modkit")
local generation = assert(tonumber(arg[1]), "choose generation 1 or 2")
local run = T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")), {
  generation = generation, data = T.fixtures.load(),
})
local upvalue = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local function hook(key)
  for _,entry in ipairs(run.loader.hooks.chains[key] or {}) do
    if entry.owner=="kanto_gear" then return entry.callback end
  end
end
local display=upvalue(hook("input.step"),"displayRuntime")
local compat=upvalue(display.openPartySummary,"compat")
local noon=os.time({year=2026,month=1,day=15,hour=12,min=0,sec=0})
for gen=1,3 do
  local stamp,period=compat.clockDisplay({save={generation=gen},world={
    hour=function() return 21 end,minute=function() return 5 end}},"system",noon)
  T.eq(stamp,noon,"system clock keeps its displayed time in every generation")
  T.eq(period,"DAY","every generation supplies the matching daytime icon")
  stamp,period=compat.clockDisplay({save={generation=gen},world={
    hour=function() return 21 end,minute=function() return 5 end}},"game",noon)
  T.eq(period,gen==1 and "DAY" or "NITE","game-clock icon follows the displayed time or its real-time fallback")
end
assert(loadfile(os.getenv("KANTO_GEAR_MOD_PATH").."/tests/summary_details_cases.lua"))()(T,compat.summary.details,generation)
local theme=upvalue(display.drawContents,"THEME")
local touchEvent=upvalue(hook("render.compose"),"touchEvent")
local tap=upvalue(touchEvent,"tap")
local swipe=upvalue(touchEvent,"swipe")
local api=upvalue(display.openPartySummary,"mod")
local queued={}
api.input.tap=function(_,target,key)
  queued[#queued+1]=key
end
local Stack=require("src.core.StateStack")
local world={map={id="FIX_TOWN",def={}}}
local game={generation=generation,data=run.data,world=world,overworld=world,
  stack=setmetatable({states={world}},{__index=Stack}),
  input={wasPressed=function(_,key)
    for i,value in ipairs(queued) do
      if value==key then table.remove(queued,i); return true end
    end
    return false
  end},
  save={generation=generation,player={name="RED",id=7},party={},inventory={},
    boxes={},pokedex={seen={},caught={}}}}
for slot=1,2 do
  game.save.party[slot]={species="FIXMON_A",nickname="PARTNER"..slot,level=10,
    hp=25,experience=1000,exp=1000,moves={{id="FIX_TACKLE",pp=10}},
    dvs={attack=8,defense=8,speed=8,special=8},statExp={},
    stats={hp=30,attack=15,defense=14,speed=12,special=13,specialAttack=13,specialDefense=13}}
end
run.loader.events:emit("game.ready",{game=game})

for slot=1,6 do
  local x,y,w,h=display.PartyPage.rect(theme.hgss,slot)
  T.eq(display.PartyPage.hit(theme.hgss,x+w/2,y+h/2,6),slot,"fixed team card hits its own slot")
  T.eq(display.PartyPage.hit(theme.hgss,x+w,y+h/2,6),nil,"card gaps do not select a neighbor")
end
T.eq(display.PartyPage.hit(theme.hgss,60,180,2),nil,"empty team slots stay inert")

for _,style in ipairs({"hgss","hgss_dark"}) do
  run.loader.modOptions.kanto_gear={theme_v3=style,ui_motion=false,info_level="enhanced"}
  run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3"})
  for slot=1,2 do
    game.stack.states={world}
    T.check(display.openHomeApp("party"),"Party app opens")
    local x,y=theme.hgss:partyPosition(slot)
    tap((x+35)/theme.hgssScale,(y+25)/theme.hgssScale)
    T.eq(upvalue(tap,"partyActionSlot"),slot,"touch selects the intended partner")
    local canSwap=api.world and api.world.canReorderParty and api.world:canReorderParty()
    local rows=display.partyActionRows(slot)
    if generation==2 then
      T.eq(rows[#rows].id,"item","Gen 2 party actions offer the held item")
      T.eq(#rows,canSwap and 3 or 2,"stats, swap when allowed, item")
    else
      T.eq(#rows,canSwap and 2 or 1,"Gen 1 has no held items")
    end
    local rx,ry,rw,rh=theme.hgss:partyActionRow(1,#rows)
    tap((rx+rw/2)/theme.hgssScale,(ry+rh/2)/theme.hgssScale)
    local summary=display.summaryContext()
    T.check(summary~=nil,"Stats opens a companion inspection")
    T.eq(game.stack:top(),world,"inspecting a partner never opens an original game menu")
    T.eq(summary.mon,game.save.party[slot],"inspection reads the selected partner")
    T.eq(summary.pages,3,"all generations share the three core pages")
    for index=1,3 do
      local tx,ty,tw,th=display.SummaryPage.tabRect(summary,index)
      tap((tx+tw/2)/theme.hgssScale,(ty+th/2)/theme.hgssScale)
      T.eq(summary.page,index,"touch selects the named shared tab")
      T.check(pcall(display.drawContents),"shared page renders in "..style)
      T.eq(#queued,0,"reading a tab sends no game inputs")
      T.eq(game.stack:top(),world,"game stays on its original screen")
    end
    swipe(-50,{x=100,y=70});T.eq(summary.page,1,"swipe wraps the common pages")
    swipe(50,{x=100,y=70});T.eq(summary.page,3,"reverse swipe wraps the common pages")
    local view=compat.summary.view(summary,game)
    T.eq(view.stats,game.save.party[slot].stats,"stats are the real partner's stats")
    T.eq(view.experience,1000,"experience retains the real generation value")
    local key=compat.summary.redrawKey(summary)
    summary.mon.hp=summary.mon.hp-1
    T.check(compat.summary.redrawKey(summary)~=key,"live HP changes invalidate the inspection")
    game.stack.states={world,{isTextBox=true}}
    T.eq(display.summaryContext(),nil,"a field dialogue keeps native touch priority")
    game.stack.states={world}
    T.eq(display.summaryContext(),summary,"inspection resumes after the dialogue")
    tap(12/theme.hgssScale,15/theme.hgssScale)
    T.eq(display.localSummary,nil,"Back closes only the companion inspection")
    T.eq(game.stack:top(),world,"closing does not change the game screen")
    if generation==2 then
      -- ITEM hands the partner to the game's own GIVE / TAKE menu
      local canOpen=display.canOpenHeldItem
      T.eq(canOpen(),false,"no overworld, no item menu")
      display.canOpenHeldItem=function() return true end
      T.check(display.openHomeApp("party"),"Party app reopens")
      tap((x+35)/theme.hgssScale,(y+25)/theme.hgssScale)
      rows=display.partyActionRows(slot)
      local ix,iy,iw,ih=theme.hgss:partyActionRow(#rows,#rows)
      tap((ix+iw/2)/theme.hgssScale,(iy+ih/2)/theme.hgssScale)
      if rows[#rows].enabled~=false then
        local top=game.stack:top()
        T.eq(getmetatable(top),require("src.ui.gen2.HeldItemMenu"),"Item opens the native GIVE / TAKE menu")
        T.eq(top.slot,slot,"for the chosen partner")
        T.eq(upvalue(tap,"partyActionSlot"),nil,"the companion action sheet closes")
        game.stack.states={world}
      end
      display.canOpenHeldItem=canOpen
    end
    T.eq(#queued,0,"closing a local inspection sends no B into gameplay")
  end
end
local runtime=upvalue(upvalue(display.drawContents,"drawBattleSummary"),"hgssRuntime")
game.stack.states={world}
run.loader.modOptions.kanto_gear.info_level="spoiler"
T.check(display.openPartySummary(1),"spoiler inspection opens")
local state=display.summaryContext()
state.page=state.hiddenPage
local model=runtime.summaryView(state)
T.eq(#model.details.rows,5,"Gen 1/2 use five DV and stat-EXP rows")
T.eq(state.hiddenPage,4,"Details follows the three ordinary pages")
T.eq(display.SummaryPage.hit(state,100,90),nil,"Details cannot accidentally open a contest move")
T.check(pcall(display.drawContents),"hidden detail table renders")
local key=compat.summary.redrawKey(state,game)
state.mon.dvs.attack=7
T.check(compat.summary.redrawKey(state,game)~=key,"live genes invalidate visible details")
run.loader.modOptions.kanto_gear.info_level="enhanced"
state=display.summaryContext()
T.eq(state.hiddenPage,nil,"leaving spoiler mode removes the hidden tab immediately")
T.eq(state.pages,3,"ordinary page count returns")
T.eq(runtime.summaryView(state).details,nil,"ordinary modes expose no hidden detail model")
if generation==2 then
  game.save.party[3]={species="FIXMON_A",isEgg=true,eggSteps=3,moves={},stats={}}
  T.check(display.openPartySummary(3),"touch inspection supports eggs")
  state=display.summaryContext()
  T.eq(state.pages,1,"eggs have a dedicated page without battle stats")
  model=runtime.summaryView(state)
  T.eq(model.hatchName,nil,"normal mode hides the hatchling")
  T.eq(model.egg.steps,nil,"normal mode hides the step counter")
  T.check(pcall(display.drawContents),"ordinary egg page renders")
  game.save.stepCount=127
  run.loader.modOptions.kanto_gear.info_level="spoiler"
  state=display.summaryContext()
  model=runtime.summaryView(state)
  T.eq(model.egg.steps,513,"spoiler egg page shows current remaining steps")
  T.check(model.hatchName~=nil,"spoiler mode reveals the hatchling")
  T.check(pcall(display.drawContents),"spoiler egg page renders")
  key=compat.summary.redrawKey(state,game)
  game.save.stepCount=128
  T.check(compat.summary.redrawKey(state,game)~=key,"walking invalidates the visible egg count")
end
display.openPartySummary(1)
assert(loadfile(os.getenv("KANTO_GEAR_MOD_PATH").."/tests/discovery_partner_cases.lua"))()(T, os.getenv("KANTO_GEAR_MOD_PATH"), compat.summary,
  display.summaryContext(), runtime.summaryView, theme.hgss, display.SummaryPage, game)
assert(loadfile(os.getenv("KANTO_GEAR_MOD_PATH").."/tests/explorer_items_cases.lua"))()(T,run,display)
T.finish("Unified Party Summary Gen "..generation)
