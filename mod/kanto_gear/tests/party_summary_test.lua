-- Shared companion pages must inspect real partners without native UI side effects.
local T = require("tests.modkit")
local generation = assert(tonumber(arg[1]), "choose generation 1 or 2")
local run = T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")), {
  generation = generation, data = T.fixtures.load(),
})
local function upvalue(fn, key)
  for i=1,debug.getinfo(fn,"u").nups do
    local name,value=debug.getupvalue(fn,i)
    if name==key then return value end
  end
  error("missing upvalue "..key)
end
local function hook(key)
  for _,entry in ipairs(run.loader.hooks.chains[key] or {}) do
    if entry.owner=="kanto_gear" then return entry.callback end
  end
end
local display=upvalue(hook("input.step"),"displayRuntime")
local compat=upvalue(display.openPartySummary,"compat")
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
    local rx,ry,rw,rh=theme.hgss:partyActionRow(1,canSwap and 2 or 1)
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
    T.eq(#queued,0,"closing a local inspection sends no B into gameplay")
  end
end
T.finish("Unified Party Summary Gen "..generation)
