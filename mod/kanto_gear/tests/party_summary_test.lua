-- Run from the host SDK with argument 1 or 2. Exercise real screen factories.
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
local tapBattle=upvalue(tap,"tapBattle")
local function battleTap(x,y)
  for i=1,debug.getinfo(tapBattle,"u").nups do
    local name,value=debug.getupvalue(tapBattle,i)
    if name=="battle" then
      debug.setupvalue(tapBattle,i,{})
      tapBattle(x,y)
      debug.setupvalue(tapBattle,i,value)
      return
    end
  end
  error("missing battle state")
end
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
local expected=generation==2 and "Gen2SummaryMenu" or "SummaryMenu"
T.eq(compat.screenName("summary",generation==2),expected,"summary factory belongs to the requested generation")
-- Recognition of Gen 3's proxy must never make it a Gen 1 factory fallback.
local aliases=compat.screens.summary
compat.screens.summary={Gen3SummaryMenu=true}
T.eq(compat.screenName("summary",false),nil,"a Gen 3 proxy is not a native Gen 1 screen")
compat.screens.summary=aliases
for _,style in ipairs({"hgss","hgss_dark"}) do
  run.loader.modOptions.kanto_gear={theme_v3=style,ui_motion=false,battle_view="gear"}
  run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3"})
  for slot=1,2 do
    game.stack.states={world}
    T.check(display.openHomeApp("party"),"Party app opens")
    local x,y=theme.hgss:partyPosition(slot)
    tap((x+35)/theme.hgssScale,(y+25)/theme.hgssScale)
    T.eq(upvalue(tap,"partyActionSlot"),slot,"touch selects the intended partner")
    local canSwap=api.world and api.world.canReorderParty and api.world:canReorderParty()
    local rx,ry,rw,rh=theme.hgss:partyActionRow(1,canSwap and 2 or 1)
    local ok,err=pcall(tap,(rx+rw/2)/theme.hgssScale,(ry+rh/2)/theme.hgssScale)
    T.check(ok,"Stats tap does not fail: "..tostring(err))
    local summary=game.stack:top()
    T.eq(summary.screenId,expected,"Stats tap pushes the real native summary")
    if summary.screenId==expected then
      T.eq(summary.mon,game.save.party[slot],"native summary receives the selected Pokemon")
      T.check(compat.summary.supports(summary,game),"Gear can mirror the opened summary")
      T.eq(upvalue(tap,"partyActionSlot"),nil,"successful open dismisses party actions")
      summary.whiteHold=0
      local function step()
        summary:update(1/60)
        queued={}
      end
      local function arrow(x)
        tap(x/theme.hgssScale,15/theme.hgssScale)
        step()
      end
      arrow(110)
      T.eq(summary.page,2,"right arrow advances the actual native summary")
      arrow(55)
      T.eq(summary.page,1,"left arrow returns to the first page")
      swipe(-50,{x=100,y=70});step()
      T.eq(summary.page,2,"leftward swipe advances the native page")
      swipe(50,{x=40,y=70});step()
      T.eq(summary.page,1,"rightward swipe goes back")
      arrow(55)
      T.eq(summary.page,generation==1 and 2 or 3,"previous wraps to the last page")
      arrow(110)
      T.eq(summary.page,1,"next wraps to the first page without closing")
      battleTap(110/theme.hgssScale,15/theme.hgssScale);step()
      T.eq(summary.page,2,"battle summary uses the same page controls")
      if generation==1 then
        summary.page=1;summary.whiteHold=2
        arrow(110)
        T.eq(summary.page,1,"opening hold blocks page input")
        summary.whiteHold=0;summary.closing=true
        arrow(110)
        T.eq(summary.page,1,"closing summary rejects late touches")
        summary.closing=nil
        queued={"a"};step()
        T.eq(summary.page,2,"physical A retains native page advancement")
        summary.page=1;queued={"b"};step()
        T.eq(summary.page,2,"physical B retains native page advancement")
      end
      -- Close from both pages, exercising field and battle touch dispatch.
      summary.page=slot
      local closeTap=slot==1 and tap or battleTap
      closeTap(12/theme.hgssScale,15/theme.hgssScale);step()
      for _=1,30 do
        local top=game.stack:top()
        if top==world then break end
        top:update(1/60)
      end
      T.eq(game.stack:top(),world,"closing summary returns to the original game state")
      T.eq(upvalue(display.openHomeApp,"page"),"PARTY","companion returns to Party")
    end
  end
end
T.finish("Party Stats opening Gen "..generation)
