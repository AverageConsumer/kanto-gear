local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local Page = assert(loadfile(root .. "/region_map_page.lua"))()
local Legacy = assert(loadfile(root .. "/legacy_region.lua"))()
for _, size in ipairs({ {160,128}, {160,144}, {192,144}, {224,120} }) do
  local target = { id = "town", region = "test", name = "TOWN", flyPoint = true, flyable = true }
  local model = { key = "test", width = size[1], height = size[2], playerX = 30, playerY = 40,
    pick = function(x) return x < 50 and target or nil end }
  local state = {}
  Page.bind(state, model)
  local left, top, scale = Page.transform(model)
  T.check(left >= 14 and top >= 39, "atlas is centered within the viewport")
  T.check(left + size[1]*scale <= 226.5 and top + size[2]*scale <= 151.5, "whole atlas fits without cropping")
  local x,y = left + 30*scale, top + 40*scale
  T.check(Page.inside(model,x,y), "rendered coordinate is touchable")
  Page.select(state,model,x,y)
  T.check(math.abs(state.x - 30) < .001 and math.abs(state.y - 40) < .001, "touch inverts the actual draw transform")
  Page.tap(state,model,170,198,true)
  T.check(state.fly, "explicit mode switch enters Fly")
  T.eq(Page.tap(state,model,x,y,true), "select", "first tap only selects a destination")
  local action, selected = Page.tap(state,model,x,y,true)
  T.eq(action,"fly", "second tap requests confirmation")
  T.eq(selected,target,"confirmation retains destination identity")
  T.eq(Page.tap(state,model,x,y,false),"select","unavailable move cannot confirm")
  T.eq(state.armed,nil,"unavailable move clears old confirmation state")
  target.flyable=false
  Page.tap(state,model,x,y,true); Page.tap(state,model,x,y,true)
  T.eq(state.armed,nil,"unvisited city never arms")
  T.eq(Page.status(state,target,true),"NOT VISITED","unvisited city has a specific explanation")
  target.flyable=true
  Page.tap(state,model,x,y,true)
  Page.tap(state,model,left + 100*scale,y,true)
  T.eq(state.armed,nil,"leaving a valid destination disarms it")
  Page.tap(state,model,50,198,true)
  T.eq(state.fly,false,"map browsing is an explicit separate mode")
  Page.tap(state,model,x,y,true); Page.tap(state,model,x,y,true)
  T.eq(state.armed,nil,"browsing cannot initiate flight")
  Page.select(state,model,-100,1000)
  T.eq(state.x,0,"drag clamps at the left edge")
  T.eq(state.y,model.height-1,"drag clamps at the bottom edge")
end
local FM = require("src.world.gen2.FieldMoves")
local badge = FM.BADGE.FLY
local save = { player = { badges = {} }, party = { { species = "PIDGEY", moves = { {id="FLY"} } } },
  engineFlags = {}, visitedSpawns = { SPAWN_NEW_BARK = true } }
local w = { map = { def = { environment = "TOWN" } }, acceptsMenuInput = function() return true end,
  region = function() return "johto" end }
local game = { save = save, world = w, data = { gen2Landmarks = { landmarks = {} } },
  stack = { top = function() return w end } }
local flight, count, seen = Legacy.new(game,nil,2), 0
w.flyTo = function(_,spawn,mon) count=count+1; seen=spawn; T.eq(mon,save.party[1],"Gen2 flight retains its real party member"); return true end
T.eq(flight:canFly(),false,"Gen2 native badge is required")
save.player.badges[badge]=true
T.check(flight:canFly(),"Gen2 Fly is available outdoors with the badge and move")
T.check(flight:fly({id="SPAWN_NEW_BARK",region="johto"}),"visited spawn uses the native flight endpoint")
T.eq(seen,"SPAWN_NEW_BARK","Gen2 receives a spawn ID, not a Gen1 map ID")
T.check(not flight:fly({id="SPAWN_GOLDENROD",region="johto"}),"unvisited spawn is rejected")
T.check(not flight:fly({id="SPAWN_NEW_BARK",region="kanto"}),"other region is rejected")
save.party[1].moves={}
T.check(not flight:fly({id="SPAWN_NEW_BARK",region="johto"}),"move removal revalidates pending flight")
T.eq(count,1,"stale or invalid requests never execute")
T.eq(Legacy.pick({{id="town",x=10,y=10}},100,100),nil,"open sea is not labeled as a distant town")
T.finish("Shared region map interaction and Gen2 native flight")
