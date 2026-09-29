local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
-- LÖVE provides this primitive; the SDK's lightweight stub predates its use.
love.graphics.arc = love.graphics.arc or function() end
-- Reuse the real-ROM fixture setup and invariants in a separate Lua process.
dofile(path .. "/tests/emerald_native_test.lua")
local Dataset = require("src.core.game3.dataset")
local Schema = require("src.core.game3.save_schema_firered")
local maps = Dataset.buildMaps()
Dataset.attachMidLayouts(maps, Dataset.cache())
local data = { maps = maps,
  gen3Encounters = assert(loadfile(os.getenv("POKEPORT_GBA_CACHE") .. "/encounters.lua"))() }
-- Isolate tool storage while loading the actual packaged manifest.
local Fs = require("tests.fs_io").new(path)
local fs, writes = {}, {}
local function resolve(file)
  return file:gsub("^mods/kanto_gear/?", "")
end
function fs.read(file)
  local bytes = writes[file] or Fs.read(resolve(file))
  return bytes
end
function fs.load(file)
  local bytes = fs.read(file)
  return bytes and load(bytes, "@" .. file)
end
function fs.write(file, bytes) writes[file] = bytes; return true end
function fs.createDirectory() return true end
function fs.remove(file) writes[file] = nil; return true end
function fs.rename(a, b) writes[b], writes[a] = writes[a], nil; return true end
function fs.getInfo(file)
  if writes[file] then return { type = "file", size = #writes[file] } end
  if file == "mods" then return { type = "directory" } end
  return Fs.getInfo(resolve(file))
end
function fs.getDirectoryItems(file)
  if file == "mods" then return { "kanto_gear" } end
  return Fs.getDirectoryItems(resolve(file))
end
local run = T.sdk.loadMod(path, { generation = 3, data = data, fs = fs })
T.eq(run.mod and run.mod.state, "loaded", "native Gen3 test build loads")
for _, err in ipairs(run.errors) do print(err.message or err.error or tostring(err)) end
local raw = setmetatable({ generation = 3, data = data, phase = "boot" },
  { __index = require("src.core.Game3") })
run.loader.game = raw
run.loader.events:emit("game.ready", { game = raw })
local function upvalue(fn, target)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, i)
    if name == target then return value end
  end
end
local hook
for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
  if entry.owner == "kanto_gear" then hook = entry.callback end
end
local display = assert(upvalue(hook, "displayRuntime"))
T.check(display.gen3 ~= nil, "native adapter selected")
T.check(display.sourceGame == raw, "host input keeps original identity")
local titleCompat = assert(upvalue(assert(upvalue(display.drawContents, "drawTitle")), "compat"))
local editionCode = "EM"
T.eq(titleCompat.systemId(nil, "3.3.0"), "SLS-" .. editionCode .. "-3.3.0",
  "title identifier works before a save exists")
local session = Schema.newGame({ version = os.getenv("POKEPORT_VERSION"), name = "RUNTIME", rngSeed = 2000 })
require("src.core.game3.party").giveMon(session, 277, 15)
local Bag = require("src.core.game3.bag")
Bag.add(session.bag, 4, 35)
run.loader.events:emit("save.created", { save = session })
T.eq(display.gen3.session, nil, "created event does not adopt the old host session")
raw.session, raw.save, raw.phase = session, Schema.toSaveTable(session), "field"
require("src.core.game3.runtime").session = session
run.loader.events:emit("map.entered", { mapId = session.map, game = raw })
T.eq(display.gen3.save.player.name, "RUNTIME", "new-game event refreshes live projection")

local P = require("src.core.game3.pokemon")
local C = require("src.core.game3.constants").of("emerald")
local Stack = require("src.ui.game3.stack")
local Screens = require("src.ui.game3.screens")
local function input(key) return { wasPressed=function(_,k) return key==k end, isDown=function() return false end } end
T.eq(display.pokedexData().total, 202, "Hoenn catalogue")
T.eq(display.pokedexData().entries[1].species, P.speciesFromNational(252), "Treecko first")
T.eq(display.trainerSummary().region,"HOENN","trainer region")
T.eq(display.bagSummary().ball,35,"ball totals")
session.flags[C:flag("FLAG_BADGE01_GET")]=true
display.gen3:refresh()
T.eq(display.trainerSummary().badgeCount,1,"Stone Badge counts")
local NativeBag=require("src.ui.game3.bag_menu")
local RseBag=require("src.ui.game3.rse.bag_menu")
for _,name in ipairs({"ITEM_POTION","ITEM_POKE_BALL","ITEM_TM01","ITEM_CHERI_BERRY","ITEM_OLD_ROD"}) do
 local id=C:require("items",name)
 Bag.add(session.bag,id,2);display.gen3:refresh()
 T.check(display.useBagItem(id),"open "..name)
 NativeBag.settle()
 T.eq(Stack.top().id,"bag","Emerald uses pockets, not FRLG containers")
 Screens.handleInput("bag",NativeBag,input("a"),session)
 local menu=display.startMenu()
 T.check(menu~=nil,"project actions "..name)
 T.check(menu.nativeGrid,"native action grid mirrored "..name)
 for i,item in ipairs(menu.items) do
  T.check(item.rect~=nil,"all actions have native grid position")
  T.check(display.StartMenu.select(menu,i),"select action "..i)
  local cell=RseBag._st.grid.cells[RseBag._st.gridPos+1]
  T.eq(cell.idx,NativeBag.actionCursor,"touch and native spatial cursor agree")
 end
 for i,item in ipairs(menu.items) do
  if item.label=="CANCEL" then
   display.StartMenu.select(menu,i)
   Screens.handleInput("bag",NativeBag,input("a"),session)
   T.eq(NativeBag.mode,"list","touch-selected cancel runs native cancel")
   break
  end
 end
 NativeBag.close();Stack.clear();RseBag.reset()
end
-- Emerald has its own toss texts and a fourth bedroom-PC action.
T.check(display.useBagItem(C:require("items","ITEM_POTION")),"open potion for toss")
NativeBag.settle();Screens.handleInput("bag",NativeBag,input("a"),session)
local menu=display.startMenu()
for i,item in ipairs(menu.items) do if item.label=="TOSS" then display.StartMenu.select(menu,i) end end
Screens.handleInput("bag",NativeBag,input("a"),session)
T.eq(display.startMenu().quantity.qty,1,"toss quantity projected")
Screens.handleInput("bag",NativeBag,input("a"),session)
T.check(display.startMenu().prompt~=nil,"Emerald toss confirmation text")
Screens.handleInput("bag",NativeBag,input("a"),session)
T.check(display.startMenu().notice~=nil,"Emerald toss result text")
Screens.handleInput("bag",NativeBag,input("a"),session)
T.eq(Bag.get(session.bag,13),1,"exactly one potion removed")
NativeBag.close();Stack.clear();RseBag.reset()
local Pc=require("src.ui.game3.pc_menu")
Pc.show({session=session,startMode="player_pc",bedroom=true})
menu=display.startMenu()
T.eq(#menu.items,4,"bedroom PC includes decoration")
display.StartMenu.select(menu,1);Pc.handleInput(input("a"))
T.eq(#display.startMenu().items,4,"Emerald PC storage includes toss")
Pc.close();Stack.clear()
T.check(display.openPartySummary(1),"open native summary")
local Summary=require("src.ui.game3.summary_menu")
for page=0,2 do
 Summary._page=page;Summary._slide.active=false
 display.gen3.syncScreens()
 local view=display.gen3:gameView().stack:top()
 T.eq(view.page,page+1,"summary page "..page)
 T.check(pcall(display.drawContents),"summary renders")
end
Screens.handleInput("summary",Summary,input("right"),session)
display.gen3.syncScreens()
local view=display.gen3:gameView().stack:top()
T.eq(view.page,4,"contest page recognized")
T.check(view.moveDetail,"contest stays on native display")
Screens.handleInput("summary",Summary,input("left"),session)
display.gen3.syncScreens()
T.eq(display.gen3:gameView().stack:top().page,3,"back from contest")
Summary.close();Stack.clear()
for _,layer in ipairs({"pokenav","rse_contest","pyramid_bag","frontier_pass"}) do
 Stack.push(layer,{})
 T.check(display.startMenu()==nil,"specialty screens retain native controls")
 Stack.clear()
end
local Battle = require("src.core.game3.battle")
local Ui = require("src.core.game3.battle.ui")
local State = require("src.core.game3.battle.state")
local Party = require("src.core.game3.party")
Party.giveMon(session, P.speciesFromNational(258), 12)
local foes = Schema.newGame({version="emerald",name="FOE",rngSeed=3000})
Party.giveMon(foes, P.speciesFromNational(261), 12)
local st=State.new({playerParty=session.party,foeParty=foes.party,wild=true})
Battle._active,Battle._auto,Battle._phase,Battle._st=true,false,"command",st
Ui.reset({headless=true});Ui.bindState(st,session);Ui.openMenu(0)
local refreshBattle
for _,entry in ipairs(run.loader.hooks.chains["render.compose"] or {}) do
 if entry.owner=="kanto_gear" then refreshBattle=upvalue(entry.callback,"refreshBattle") end
end
local owns=display.gen3Presentation.owns
for i=1,debug.getinfo(owns,"u").nups do
 local name=debug.getupvalue(owns,i)
 if name=="active" or name=="displayReady" or name=="hasDisplay" then
  debug.setupvalue(owns,i,name=="hasDisplay" and function() return true end or true)
 end
end
local skin=Screens.skin("bag",session)
local skinDraw,skinCalls=skin.draw,0
skin.draw=function() skinCalls=skinCalls+1 end
run.loader.modOptions.kanto_gear = run.loader.modOptions.kanto_gear or {}
for _,variant in ipairs({"hgss","hgss_dark"}) do
 run.loader.modOptions.kanto_gear.theme_v3=variant
 run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3"})
 for i=1,debug.getinfo(owns,"u").nups do
  if debug.getupvalue(owns,i)=="displayReady" then debug.setupvalue(owns,i,true) end
 end
 for _,mode in ipairs({"standard","info","gear","full"}) do
  run.loader.modOptions.kanto_gear.battle_view=mode
  for _,scene in ipairs({"root","moves","party","bag"}) do
   Stack.clear();Ui.openMenu(0)
   if scene=="moves" then Ui._mode="moves"
   elseif scene=="party" then require("src.ui.game3.party_menu").show(session.party,{session=session,battle=st})
   elseif scene=="bag" then NativeBag.show(session.bag,{session=session,battle=st});NativeBag.settle() end
   display.gen3.syncScreens();refreshBattle()
   local ok,err=pcall(display.drawContents)
   T.check(ok,variant.." "..mode.." "..scene.." renders: "..tostring(err))
   if scene=="bag" then
    T.check(display.startMenu()~=nil,"battle bag mirrored")
    local before=skinCalls;Screens.draw("bag",NativeBag,session)
    T.eq(skinCalls-before,(mode=="gear" or mode=="full") and 0 or 1,"Emerald skin follows battle ownership")
   end
   require("src.ui.game3.party_menu").close();NativeBag.close();Stack.clear()
  end
 end
end
skin.draw=skinDraw
Battle._active,Battle._st=false,nil;Ui.reset({headless=true})
local rtc=require("src.core.game3.rtc")
rtc.setFixed("2026-09-29T15:35:00")
session.localTimeOffset={days=0,hours=2,minutes=5,seconds=0}
T.eq(display.gen3:gameView().world:hour(),13,"Emerald game clock offset")
T.eq(display.gen3:gameView().world:minute(),30,"Emerald game clock minutes")
rtc.reset()
if _G.KANTO_GEAR_RENDER_CAPTURE then _G.KANTO_GEAR_RENDER_CAPTURE(run,display,raw,maps) end
T.finish("Emerald runtime")
