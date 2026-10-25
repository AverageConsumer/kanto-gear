local T=require("tests.modkit")
local generation=tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 1
local root=assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local run=T.sdk.loadMod(root,{generation=generation,data=T.fixtures.fresh()})
T.eq(run.mod and run.mod.state,"loaded","setup loads through the full mod")
local function hook(name)
  for _,entry in ipairs(run.loader.hooks.chains[name] or {}) do if entry.owner=="kanto_gear" then return entry.callback end end
end
local up=assert(loadfile(root.."/tests/support/runtime.lua"))().get
local display=up(hook("render.compose"),"displayRuntime")
local api=up(display.saveHome,"mod")
T.eq(api.cache:read("display/setup-v1"),"pending","unfinished first use is remembered across launches")
local Input=require("src.core.Input")
local input=setmetatable({},{__index=Input}); input:init(); input.pollPads=function() end
local font={getWidth=function(_,s) return #s*5 end,getHeight=function() return 7 end}
love.graphics.getFont=function() return font end
local idle,safetyQueries=false,0
api.world.availableFieldActions=function() safetyQueries=safetyQueries+1; if idle then return {} end return nil,"world is busy" end
local world={map={id="PALLET_TOWN"}}
local game={mods=run.loader,data=run.data,world=world,overworld=world,input=input,
  save={generation=generation,player={name="RED",id=7,map="PALLET_TOWN"},party={},inventory={},boxes={},pokedex={seen={},caught={}}},
  stack={states={world},top=function(self) return self.states[#self.states] end}}
run.loader.modOptions.kanto_gear={theme_v3="hgss",display_mode="combined",ui_motion=false}
local time=0; love.timer.getTime=function() return time end
run.loader.events:emit("game.ready",{game=game})
local state=display.displaySetup
T.eq(state.pending,true,"a new installation queues the one-time setup")
local updates,moves,actions=0,0,0
local function native(g)
  updates=updates+1; g.input:step()
  if g.input:isDown("right") then moves=moves+1 end
  if g.input:wasPressed("a") then actions=actions+1 end
end
local function frame() time=time+.11; hook("core.update")(native,game,1/60) end
frame(); T.eq(updates,1,"an ongoing script continues while setup waits")
T.eq(state.stage,nil,"first use cannot interrupt busy gameplay")
idle=true
input:sourcePress("right","test"); frame()
T.eq(state.stage,nil,"a held movement direction defers opening")
input:sourceRelease("right","test"); frame()
T.eq(state.stage,"welcome","the released idle boundary opens setup")
local before=updates
input:sourcePress("down","test"); frame()
T.eq(state.selected,2,"D-pad selects two screens")
input:sourceRelease("down","test"); frame()
api.options:set("display_target","handheld")
input:sourcePress("a","test"); frame()
T.eq(state.stage,"test","A begins the second-display test")
T.eq(api.options:get("display_mode"),"combined","testing does not persist Separate")
state.healthy=true
state.selected=1
frame(); T.eq(state.stage,"test","held A cannot confirm the next screen")
input:sourceRelease("a","test"); frame()
input:sourcePress("a","test"); frame()
T.eq(api.options:get("display_mode"),"separate","a fresh A press accepts the visible test")
T.eq(api.options:get("display_target"),"auto","confirmed routing matches the secondary output that was tested")
T.eq(api.cache:read("display/setup-v1"),"done","first-use completion is installation-scoped")
T.eq(state.draining,true,"closing waits for held controls")
frame(); T.eq(updates,before,"modal and held confirmation never update gameplay")
input:sourceRelease("a","test"); frame()
T.eq(updates,before,"release frame is also consumed")
frame(); T.eq(updates,before+1,"native gameplay resumes after release")
T.eq(actions,0,"A confirmation never reaches a native action")
T.eq(moves,1,"the dialog adds no movement beyond the intentional pre-dialog step")
local queries=safetyQueries
for _=1,5 do frame() end
T.eq(safetyQueries,queries,"normal gameplay does not poll field eligibility for a completed setup")
api.options:set("display_mode","combined"); state.pending=true; frame()
T.eq(state.stage,"welcome","setup can be reopened for the touch fixture")
frame()
local viewport={width=402,height=874}
local layout=display.drawDisplaySetup(game,viewport)
local b=layout.buttons[1]
local function pointer(phase,x,y,id)
  return hook("input.pointer")(function() error("modal pointer leaked") end,game,
    {phase=phase,x=x,y=y,id=id or 7,source="touch"})
end
pointer("pressed",b.x+2,b.y+2)
display.drawDisplaySetup(game,viewport)
pointer("released",b.x+2,b.y+2)
T.eq(state.stage,nil,"a touch remains valid across normal paint frames")
T.eq(api.options:get("display_mode"),"combined","touch chooses the safe combined view")
frame(); frame()
state.pending=true; frame(); frame()
layout=display.drawDisplaySetup(game,viewport); b=layout.buttons[1]
pointer("pressed",b.x+2,b.y+2)
display.drawDisplaySetup(game,{width=874,height=402})
pointer("released",b.x+2,b.y+2)
T.eq(state.stage,"welcome","rotation cancels the old touch target")
input:sourcePress("b","test"); frame(); input:sourceRelease("b","test"); frame(); frame()
T.eq(state.stage,nil,"B leaves a visible one-screen layout")
state.pending=true; game.linkSession={}; local onlineBefore=updates; frame()
T.eq(state.stage,nil,"online sessions never open or pause for setup")
T.eq(updates,onlineBefore+1,"network gameplay keeps its normal update")
game.linkSession=nil
idle=false
game.generation,game.phase,game.boot=3,"boot",{phase="oak"}
frame(); T.eq(state.stage,nil,"Gen 3 Oak speech remains uninterrupted")
game.boot.phase="title"; frame()
T.eq(state.stage,"welcome","the settled Gen 3 title is a safe first-use entry")
input:sourcePress("b","test"); frame(); input:sourceRelease("b","test"); frame(); frame()
game.generation,game.phase,game.boot=nil,nil,nil
idle=true
local set=api.options.set
api.options.set=function() return false end
state.pending=true; frame(); frame()
input:sourcePress("b","test"); frame(); input:sourceRelease("b","test"); frame(); frame()
T.eq(state.stage,nil,"a failed preference write cannot trap the user in setup")
T.eq(state:override(),"combined","read-only storage leaves a safe local session")
api.options.set=set; state.sessionMode=nil
api.options:set("display_mode","separate")
state:bind(time,"separate"); state.pending=false
idle=false; state.healthy=false
frame(); time=time+2.1; local busyBefore=updates; frame()
T.eq(state.fallback,true,"a sustained output failure activates local fallback")
T.eq(state.stage,nil,"fallback does not open a modal during a script")
T.eq(updates,busyBefore+1,"a running script continues through the visual fallback")
T.eq(api.options:get("display_mode"),"separate","recovery keeps the saved output preference")
idle=true; frame(); frame()
T.eq(state.stage,"recovery","recovery waits for the idle boundary")
input:sourcePress("down","test"); frame(); input:sourceRelease("down","test"); frame()
input:sourcePress("a","test"); frame(); input:sourceRelease("a","test"); frame()
T.eq(state.stage,"test","recovery offers a second-display retry")
up(display.observeSetupDisplay,"testImage",{},true)
local available,pushes=false,0
local bridge={detected=function() return true end,available=function() return available end,
  setEnabled=function() end,push=function(_,_,_,_,preference)
    T.eq(preference,"auto","test output cannot cover the game-window confirmation through stale targeting")
    pushes=pushes+1; return true
  end}
time=time+.3; display.observeSetupDisplay(bridge)
T.eq(state.healthy,false,"a detected display without a presentation cannot be accepted")
T.eq(pushes,0,"no test image is pushed into an unavailable presentation")
available=true; time=time+.3; display.observeSetupDisplay(bridge)
T.eq(state.healthy,true,"a successfully submitted test image enables confirmation")
T.eq(pushes,1,"retry submits a real secondary test frame")
T.eq(display.setupWantsSecond(),true,"local fallback keeps the native display retry enabled")
-- Availability must not depend on whether a first Gear frame has been drawn.
local oldStage, oldFallback = state.stage, state.fallback
state.stage, state.fallback = nil, false
display.session.displayReady = false
time=time+.3; display.observeSetupDisplay(bridge)
T.eq(state.healthy,true,"an available output cannot be mistaken for first-frame failure")
state.stage, state.fallback = oldStage, oldFallback
time=state.deadline; frame()
T.eq(state.stage,"recovery","expired retry returns to the visible recovery choices")
T.eq(api.options:get("display_mode"),"separate","timeout cannot overwrite the saved preference")
frame(); input:sourcePress("b","test"); frame(); input:sourceRelease("b","test"); frame(); frame()
T.eq(api.options:get("display_mode"),"combined","B can keep the safe one-screen fallback")
idle=false
display.settings.category,display.settings.option=#display.settingsCategories,nil
local reopen
for _,row in ipairs(display.settingsModel().rows) do if row.action=="display_setup" then reopen=row end end
T.check(reopen and reopen.label=="DISPLAY SETUP" and reopen.value=="OPEN","System exposes a non-destructive setup action")
local saveBefore=game.save
local modeBefore=api.options:get("display_mode")
display.tapSettings(30,104)
T.eq(display.settings.selected,"display_setup","the new System row can be selected by touch")
T.eq(state.pending,false,"selecting its label alone does not reopen setup")
display.tapSettings(170,104)
T.eq(state.pending,true,"the System action queues setup without a file manager")
local waiting
for _,row in ipairs(display.settingsModel().rows) do if row.action=="display_setup" then waiting=row end end
T.check(waiting and waiting.enabled==false and waiting.value=="WAIT","queued setup is visibly inactive while the game menu is busy")
T.eq(display.requestDisplaySetup(),false,"repeated queued requests cannot rewrite the marker")
T.eq(api.cache:read("display/setup-v1"),"pending","the app writes its own setup marker")
T.eq(api.options:get("display_mode"),modeBefore,"reopening does not reset the current display preference")
T.eq(game.save,saveBefore,"reopening keeps the same game save object")
frame(); T.eq(state.stage,nil,"manual reopening also waits for scripts to finish")
idle=true; frame()
T.eq(state.stage,"welcome","manual reopening reaches the same safe first-use dialog")
T.eq(display.requestDisplaySetup(),false,"a covered reopen control cannot restart an active dialog")
input:sourcePress("b","test"); frame(); input:sourceRelease("b","test"); frame(); frame()
display.settings.option="display_setup"
local detail=display.settingsModel()
T.eq(detail.label,"DISPLAY SETUP","the action detail has its own label")
T.eq(detail.choices[1][1],"OPEN","the detail action never appears as a destructive reset")
T.eq(#run.errors,0,"setup hooks leave no loader errors")
run.release()
T.finish("Display setup runtime Gen "..generation)
