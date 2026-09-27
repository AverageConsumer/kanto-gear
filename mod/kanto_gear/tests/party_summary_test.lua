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
local tap=upvalue(upvalue(hook("render.compose"),"touchEvent"),"tap")
local Stack=require("src.core.StateStack")
local world={map={id="FIX_TOWN",def={}}}
local game={generation=generation,data=run.data,world=world,overworld=world,
  stack=setmetatable({states={world}},{__index=Stack}),
  input={wasPressed=function() return false end},
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
  run.loader.modOptions.kanto_gear={theme_v3=style,ui_motion=false}
  run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3"})
  for slot=1,2 do
    game.stack.states={world}
    T.check(display.openHomeApp("party"),"Party app opens")
    local x,y=theme.hgss:partyPosition(slot)
    tap((x+35)/theme.hgssScale,(y+25)/theme.hgssScale)
    T.eq(upvalue(tap,"partyActionSlot"),slot,"touch selects the intended partner")
    local api=upvalue(display.openPartySummary,"mod")
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
      if generation==2 then summary:close() else game.stack:pop() end
      T.eq(game.stack:top(),world,"closing summary returns to the original game state")
      T.eq(upvalue(display.openHomeApp,"page"),"PARTY","companion returns to Party")
    end
  end
end
T.finish("Party Stats opening Gen "..generation)
