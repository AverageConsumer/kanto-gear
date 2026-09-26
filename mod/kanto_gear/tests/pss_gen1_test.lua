-- Run from the host root with a relative KANTO_GEAR_MOD_PATH (SDK FsIo contract).
local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local run = T.sdk.loadMod(path, { generation=1 })
T.eq(run.mod and run.mod.state,"loaded","Gen 1 loads PSS build")
local world={map={id="PALLET_TOWN"}}
local game={generation=1,data=run.data,world=world,
  save={generation=1,player={name="RED",id=7,map="PALLET_TOWN"},party={},inventory={},
    boxes={},pokedex={seen={},caught={}}},
  stack={states={world},top=function() return world end}}
run.loader.events:emit("game.ready",{game=game})
local display
for _,entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
  if entry.owner=="kanto_gear" then
    for i=1,debug.getinfo(entry.callback,"u").nups do
      local name,value=debug.getupvalue(entry.callback,i)
      if name=="displayRuntime" then display=value end
    end
  end
end
assert(loadfile(path .. "/tests/pss_runtime_cases.lua"))()(T,assert(display))
T.eq(display.pss.ctx.identity().generation,1,"Gen 1 identity stays Gen 1")
T.eq(display.pss.ctx.identity().name,"RED","Gen 1 uses the current trainer name")
display.pss:open()
require("src.render.Assets").releaseSession()
T.check(display.pss.listener==nil,"host session teardown removes PSS listeners")
T.eq(#run.errors,0,"Gen 1 runtime has no errors")
run.release()
T.finish("PSS Gen 1 runtime")
