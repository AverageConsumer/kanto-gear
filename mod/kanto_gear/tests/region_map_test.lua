local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local Page = assert(loadfile(root .. "/ui/pages/region_map.lua"))()
local Legacy = assert(loadfile(root .. "/adapters/gen1_2/region.lua"))()
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
  T.eq(Page.status(state,target,true),"SELECT A DESTINATION","entering Fly asks for an explicit selection")
  T.eq(Page.tap(state,model,120,170,true),nil,"the initial player location cannot confirm itself")
  T.eq(Page.tap(state,model,x,y,true), "select", "first tap only selects a destination")
  T.eq(Page.tap(state,model,x,y,true), "select", "repeated map taps never request flight")
  T.eq(Page.tap(state,model,170,198,true),nil,"the current Fly tab is inert")
  T.check(state.selected,"the current mode tab keeps the selected destination")
  local action, selected = Page.tap(state,model,120,170,true)
  T.eq(action,"fly", "the separate large button confirms")
  T.eq(selected,target,"confirmation retains destination identity")
  T.eq(Page.tap(state,model,120,170,false),nil,"unavailable move cannot confirm")
  target.flyable=false
  T.eq(Page.tap(state,model,120,170,true),nil,"revoked visit status disables the selected destination")
  T.eq(Page.status(state,target,true),"NOT VISITED","unvisited city has a specific explanation")
  target.flyable=true
  target.x,target.y=30,40
  model.flyPoints={target}
  Page.select(state,model,x+10,y)
  T.eq(state.x,30,"Fly gives small destinations a generous touch radius")
  T.eq(state.y,40,"snapping preserves the exact landing cell")
  Page.select(state,model,left+100*scale,y)
  T.eq(Page.target(state,model),nil,"distant empty map space does not become a town")
  T.eq(Page.tap(state,model,120,170,true),nil,"empty map space cannot confirm")
  Page.tap(state,model,50,198,true)
  T.eq(state.fly,false,"map browsing is an explicit separate mode")
  Page.select(state,model,x+10,y)
  T.check(state.x>30,"browsing retains precise positions without Fly snapping")
  T.eq(Page.tap(state,model,120,170,true),nil,"browsing cannot initiate flight")
  Page.select(state,model,-100,1000)
  T.eq(state.x,0,"drag clamps at the left edge")
  T.eq(state.y,model.height-1,"drag clamps at the bottom edge")
end
for _, pointer in ipairs({{14,39},{120,39},{226,151},{100,110}}) do
  local x,y,w,h=Page.preview(pointer[1],pointer[2])
  T.check(x>=14 and x+w<=226 and y>=30 and y+h<=151,"magnifier stays in the map region")
  T.check(pointer[1]<x or pointer[1]>=x+w or pointer[2]<y or pointer[2]>=y+h,
    "finger position never covers the magnifier center")
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
