local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local function hook(run,name)
  for _,entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner=="kanto_gear" then return entry.callback end
  end
end
local function interaction(run, display)
  local compose=hook(run,"render.compose")
  local touch=up(compose,"touchEvent")
  local tap=up(touch,"tap")
  local now=100
  love.timer.getTime=function() return now end
  display.home.help=false
  run.loader.modOptions.kanto_gear={theme_v3="hgss",ui_motion=false}
  run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3"})
  up(tap,"page","MAP",true)
  local Page=display.RegionPage
  local target={id="TEST",region="test",name="TOWN",flyPoint=true,flyable=true}
  local model={key="test",width=160,height=128,playerX=30,playerY=40,
    pick=function() return target end,drawMap=function() end}
  local originalModel=display.regionMapModel
  display.regionMapModel=function() Page.bind(display.regionCursor,model); return model end
  local canFly=up(display.tapRegionMap,"canFly")
  up(display.tapRegionMap,"canFly",function() return true end,true)
  local function input(action,x,y)
    touch(("%s,%d,%d"):format(action,x,y),240,216)
  end
  local function settle() display.syncTouchGuard(); now=now+1 end
  local fly,calls,received=display.flyRegionTarget,0
  display.flyRegionTarget=function(selected)
    calls=calls+1;received=selected
    display.regionCursor.fly,display.regionCursor.selected=false,false
    return true
  end
  display.regionCursor.fly=true; settle()
  input("down",70,70); input("move",110,95); input("move",70,70); input("up",70,70)
  T.eq(calls,0,"drag returning to its origin never flies")
  T.check(display.regionCursor.selected,"released drag retains the selected destination")
  settle(); input("tap",70,70); input("tap",70,70)
  T.eq(calls,0,"repeated map taps only select")
  input("down",120,154); input("up",120,170)
  T.eq(calls,0,"a gesture starting outside confirmation cannot activate it")
  input("down",120,170); input("up",120,170)
  T.eq(calls,1,"the separate button starts one flight")
  T.eq(received,target,"the button preserves the selected destination")
  T.eq(up(tap,"pendingFly"),nil,"the explicit button needs no second confirmation dialog")
  T.check(not display.touchGuard:allow(now),"flight transition rejects an immediate stray tap")
  display.regionCursor.fly=true; settle()
  input("down",70,70); input("move",120,170); input("up",120,170)
  T.eq(calls,1,"dragging off the map onto the button cannot fly")
  settle(); input("down",70,70); input("move",110,95); input("cancel",110,95)
  T.eq(display.regionCursor.selected,false,"cancel clears the tentative selection")
  settle(); input("tap",120,170)
  T.eq(calls,1,"cancelled selection cannot confirm")
  settle(); input("down",70,70)
  up(tap,"page","HOME",true); display.syncTouchGuard(); now=now+1
  input("up",70,70)
  T.eq(calls,1,"changing pages during a gesture cannot fly")
  up(tap,"page","MAP",true); settle(); display.regionCursor.fly=false
  settle(); input("tap",70,70); input("tap",120,170)
  T.eq(calls,1,"browse taps cannot fly")
  display.regionCursor.fly=true; settle(); input("tap",70,70)
  target.flyable=false; input("tap",120,170)
  T.eq(calls,1,"a revoked visit disables the button before dispatch")
  target.flyable=true
  for _,style in ipairs({"hgss","hgss_dark"}) do
    run.loader.modOptions.kanto_gear.theme_v3=style
    run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3"})
    settle(); input("down",70,70); input("move",110,110)
    local theme=up(display.drawContents,"THEME").hgss
    local original,shown=theme.regionMap
    theme.regionMap=function(self,view) shown=view;return original(self,view) end
    local ok,err=pcall(display.drawContents)
    theme.regionMap=original
    T.check(ok,"common region page and magnifier render in "..style..": "..tostring(err))
    T.check(shown and shown.preview,"held map pointer supplies its unobscured magnifier")
    input("up",110,110)
  end
  display.flyRegionTarget=fly
  display.regionMapModel=originalModel
  up(display.tapRegionMap,"canFly",canFly,true)
  up(tap,"page","HOME",true)
end
if tonumber(os.getenv("KANTO_GEAR_TEST_GEN"))==3 then
  _G.KANTO_GEAR_RENDER_CAPTURE=function(run,display)
    local a,bridge=display.gen3,display.gen3Field
    require("src.ui.game3.stack").clear();a.Message.reset();a.syncScreens()
    up(hook(run,"render.compose"),"refreshBattle")()
    local Kit = require("src.ui.game3.rse.scene_kit")
    local readKit, imageKit = Kit.loadLua, Kit.image
    Kit.loadLua = function(path)
      local cached = path:match("^data/generated/gba/(.*)")
      local chunk = cached and loadfile(os.getenv("POKEPORT_GBA_CACHE").."/"..cached)
      return chunk and chunk() or readKit(path)
    end
    Kit.image = function(path) return imageKit(path) or love.graphics.newImage(path) end
    local model=display.regionMapModel()
    T.check(model.width and model.pick,"native ROM atlas supplies an interactive map")
    local region=display.gen3Region
    local targets,seen={},{}
    for y=0,model.height-1,4 do for x=0,model.width-1,4 do
      local target=model.pick(x,y,true)
      if target and target.flyPoint then
        local key=display.RegionPage.targetKey(target)
        if not seen[key] then targets[#targets+1]=target;seen[key]=true end
      end
    end end
    T.check(#targets>1,"all native landing points can be discovered without opening the map UI")
    local points=region:points(model)
    local cells=region.pointCells[model.key]
    local covered={}
    for _,point in ipairs(points) do
      T.check(point.x>=0 and point.x<model.width and point.y>=0 and point.y<model.height,
        "generous target centers remain inside the real native atlas")
      covered[display.RegionPage.targetKey(point)]=true
    end
    for _,target in ipairs(targets) do
      T.check(covered[display.RegionPage.targetKey(target)],"snapping retains every distinct native landing cell")
    end
    region:points(model)
    T.eq(region.pointCells[model.key],cells,"pointer input reuses region geometry instead of rescanning the atlas")
    local oldBusy,oldMap,oldFly=bridge.Compat.worldBusy,bridge.Map.currentDef,a.Field.flyTo
    local oldMoves=a.session.party[1].moves
    local oldFlags={};for key,value in pairs(a:flagStore().flags) do oldFlags[key]=value end
    local outdoors
    for _,map in pairs(a.data.maps) do if a.FieldMoves.isOutdoors(map.mapType) then outdoors=map;break end end
    bridge.Compat.worldBusy=function() return false end
    bridge.Map.currentDef=function() return outdoors end
    a.session.party[1].moves={a.FieldMoves.MOVES.FLY}
    a.Flags.setFlag(a:flagStore(),nil,a.FieldMoves.badgeFlag("FLY"),true)
    local calls,payload=0
    a.Field.flyTo=function(section,mon,info)
      calls=calls+1;payload={section=section,mon=mon,info=info}
    end
    for _,target in ipairs(targets) do
      if region.Hoenn then
        local r=region.Hoenn
        local first=r.mapsec("LITTLEROOT_TOWN")
        if target.id>=first and target.id<=r.mapsec("EVER_GRANDE_CITY") then
          local C=require("src.core.game3.constants").of(a.profile.id)
          a.Flags.setFlag(a:flagStore(),nil,C:flag("FLAG_VISITED_LITTLEROOT_TOWN")+target.id-first,true)
        else a.Flags.setFlag(a:flagStore(),nil,a.Flags.IDS.FLAG_LANDMARK_BATTLE_FRONTIER,true) end
      else
        -- Set only real world-map flags, never a fabricated visited-map table.
        for name,id in pairs(a.Flags.IDS) do
          if name:match("^FLAG_WORLD_MAP_") then a.Flags.setFlag(a:flagStore(),nil,id,true) end
        end
      end
      local fresh=region:resolve(target)
      T.check(fresh and fresh.dest and fresh.name~="","native visited flags unlock a real named landing point")
      local before=calls
      T.check(bridge:flyTo(target,region),"flight uses validated native destination")
      T.eq(calls,before+1,"validated flight dispatches exactly once")
      T.eq(payload.section,fresh.id,"native section ID is retained")
      T.eq(payload.mon,a.session.party[1],"native flight uses the current Fly user")
      T.eq(payload.info.dest.map,fresh.dest.map,"landing map is the native version-specific destination")
      T.eq(payload.info.dest.x,fresh.dest.x,"landing X is retained")
      T.eq(payload.info.dest.y,fresh.dest.y,"landing Y is retained")
    end
    local before=calls
    a.Flags.setFlag(a:flagStore(),nil,a.FieldMoves.badgeFlag("FLY"),false)
    T.check(not bridge:flyTo(targets[1],region),"native badge is rechecked at final confirmation")
    a.Flags.setFlag(a:flagStore(),nil,a.FieldMoves.badgeFlag("FLY"),true)
    bridge.Compat.worldBusy=function() return true end
    T.check(not bridge:flyTo(targets[1],region),"busy native state cannot start a flight")
    bridge.Compat.worldBusy=function() return false end
    local other={};for k,v in pairs(targets[1]) do other[k]=v end;other.region="other"
    T.check(not bridge:flyTo(other,region),"stale region cannot redirect a flight")
    T.eq(region:pick(region.Hoenn and "hoenn" or select(1,region:position()),-100,-100,true),nil,
      "outside the actual region grid has no destination")
    if region.Hoenn then
      local r=region.Hoenn
      local C=require("src.core.game3.constants").of(a.profile.id)
      local league=C:flag("FLAG_LANDMARK_POKEMON_LEAGUE")
      a.Flags.setFlag(a:flagStore(),nil,league,true)
      local landings,names={},{ }
      for _,target in ipairs(targets) do
        if target.id==r.mapsec("EVER_GRANDE_CITY") then
          local fresh=region:resolve(target)
          landings[fresh.dest.map..":"..fresh.dest.x..":"..fresh.dest.y]=true;names[fresh.name]=true
        end
      end
      local count=0;for _ in pairs(landings) do count=count+1 end
      T.eq(count,2,"Ever Grande has two distinct native landing points after the League unlock")
      count=0;for _ in pairs(names) do count=count+1 end
      T.eq(count,2,"Ever Grande landing choices use the native distinct names")
      -- A visited flag being revoked invalidates a destination independently of Fly.
      local id=C:flag("FLAG_VISITED_LITTLEROOT_TOWN")+targets[1].id-r.mapsec("LITTLEROOT_TOWN")
      a.Flags.setFlag(a:flagStore(),nil,id,false)
      T.check(not bridge:flyTo(targets[1],region),"revoked destination flag invalidates pending flight")
    end
    a.session.party[1].moves={}
    T.check(not bridge:flyTo(targets[1],region),"removing Fly invalidates a pending native flight")
    T.eq(calls,before,"stale flight starts no animation or warp")
    a.session.party[1].moves=oldMoves;a:flagStore().flags=oldFlags
    bridge.Compat.worldBusy,bridge.Map.currentDef,a.Field.flyTo=oldBusy,oldMap,oldFly
    interaction(run,display)
  end
  dofile(root..(os.getenv("POKEPORT_VERSION")=="emerald" and "/tests/emerald_runtime_test.lua" or "/tests/gen3_runtime_test.lua"))
else
  local gen=tonumber(os.getenv("KANTO_GEAR_TEST_GEN")) or 2
  local run=T.sdk.loadMod(root,{generation=gen,data=T.fixtures.load()})
  local display=up(hook(run,"input.step"),"displayRuntime")
  local world={isOverworld=true,map={id="PALLET_TOWN",def={}}}
  local game={data=run.data,world=world,overworld=world,
    stack={states={world},top=function(self) return self.states[#self.states] end},
    save={generation=gen,player={name="RED"},party={},inventory={},visited={},pokedex={seen={},caught={}},boxes={},options={}}}
  run.loader.events:emit("game.ready",{game=game})
  -- Exercise the real Gear atlas/landmark adapter as well as generic gestures.
  local cells={};for i=1,320 do cells[i]=0 end
  if gen==2 then
    game.data.gen2MenuGfx={pokegear={tiles="region-test.png",maps={johto=cells,kanto=cells}}}
    game.data.gen2Landmarks={landmarks={LANDMARK_NEW_BARK_TOWN={index=1,name="NEW BARK TOWN",x=40,y=56}},
      order={[2]="LANDMARK_NEW_BARK_TOWN"}}
    game.data.gen2Maps={PALLET_TOWN={landmark=1}}
    game.save.visitedSpawns={SPAWN_NEW_BARK=true}
  else
    game.data.field=game.data.field or {}
    game.data.field.townMap={locations={PALLET_TOWN={name="PALLET TOWN",coords={x=3,y=4}}},
      background={map=cells,tiles={path="region-test.png"}}}
    game.data.field.flyOrder={"PALLET_TOWN"};game.data.field.flyWarps={PALLET_TOWN={x=1,y=1}}
    game.data.field.outsideTilesets={"OVERWORLD"};game.data.maps.PALLET_TOWN={tileset="OVERWORLD"}
    game.save.visited.PALLET_TOWN=true
  end
  up(display.homeRegionMap,"mapId","PALLET_TOWN",true)
  local model=display.regionMapModel()
  T.check(model.width==160 and model.pick,"legacy atlas exposes the same interactive contract")
  local picked=model.pick(model.playerX,model.playerY,true)
  T.check(picked and picked.flyable,"native visited town/spawn becomes selectable at its rendered position")
  T.eq(picked.id,gen==2 and "SPAWN_NEW_BARK" or "PALLET_TOWN","generation-specific target ID survives shared map presentation")
  local ok,err=pcall(model.drawMap,14,39,212,112)
  T.check(ok,"whole legacy region renders: "..tostring(err))
  interaction(run,display)
  T.finish("Shared region map gestures")
end
