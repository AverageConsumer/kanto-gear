local root = os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local Notes = assert(loadfile(root .. "/notes.lua"))()
local count, clock, writes, area = 0, 0, 0, "ROUTE_2"
local function check(value, label) assert(value, label); count = count + 1 end
local function clone(v) if type(v)~="table" then return v end;local out={};for k,item in pairs(v) do out[k]=clone(item) end;return out end
local values,failWrites={},false
local storage={
 read=function(_,game,key)local v=values[game.save.version..game.save.meta.playthroughId..key];return clone(v),v and nil or "not_found" end,
 write=function(_,game,key,v)writes=writes+1;if failWrites then return false end;values[game.save.version..game.save.meta.playthroughId..key]=clone(v);return true end,
}
local function state()
 return Notes.new({time=function()return clock end,measure=function(s)return #s*5 end,
   area=function()return area,area:gsub("_"," ") end,translate=function(s)return s end,leave=function()end})
end
local game={save={version="red",meta={playthroughId="one"}}}
local a=state();a:bind(game,storage);a:action("new");a:type("Remember äöü");a:action("finish")
check(a:note().title=="Remember äöü","Unicode title")
a:action("edit","text");a:type("Return with Cut.");a:action("finish")
check(a:note().area=="ROUTE_2","current-route note")
a:action("view","tasks");a:action("addTask");a:type("Catch Abra");a:action("finish");a:action("check",1)
check(a:note().tasks[1].done,"task check")
a:action("task",1);a:type("! ");a:type("",true);a:action("finish")
check(a:note().tasks[1].text=="Catch Abra!","task edit preserves note text")
check(a:note().text=="Return with Cut.","independent text and task")
a:action("addTask");a:action("finish");check(#a:note().tasks==1,"empty task discarded")
a:action("view","draw");a:takeChanged();local before=writes
a:pointer("down",20.25,50.5);for i=1,80 do a:pointer("move",20.25+i*1.5,50.5+math.sin(i/10)*8) end
clock=3;a:flush();check(writes==before,"no disk writes during stroke")
check(#a:note().strokes[1].points==162,"all movement samples retained")
check(a:note().strokes[1].points[1]==10.25,"subpixel coordinate retained")
a:takeChanged();a:pointer("move",140.25,50.5+math.sin(8)*8);check(not a:takeChanged(),"stationary stroke schedules no redraw")
a:pointer("up",141,51);check(not a.stroke,"release commits stroke")
clock=4;a:flush();check(writes==before+1,"only changed note is saved once after release")
a:action("color",2);a:pointer("down",30,70);a:pointer("move",140,70);a:pointer("up",150,70)
check(a:note().strokes[2].color==2,"per-stroke color")
a:action("pen","eraser");a:pointer("down",80,70);a:pointer("up",80,70)
check(#a:note().strokes==1,"eraser hits between sparse samples")
a:action("undo");check(#a:note().strokes==2,"erase undo restores stroke")
a:action("undo");check(#a:note().strokes==1,"draw undo removes the last stroke")
a:action("pen","pen");a:pointer("down",20,80);a:pointer("move",90,90);a:pointer("cancel",0,0)
check(not a.stroke and #a:note().strokes==2,"cancel preserves the partial drawing")
clock=6;a:flush(true)
local b=state();b:bind(game,storage)
check(#b.records==1 and #b.records[1].strokes==2,"drawing reloads from durable storage")
b:action("open",1);check(b:note().tasks[1].done,"task state survives reload")
b:action("delete");check(#b.records==0,"delete removes catalog entry")
b:action("restore");check(#b.records==1 and #b:note().strokes==2,"restore includes drawing")
local second=state();second:bind({save={version="red",meta={playthroughId="two"}}},storage)
check(#second.records==0,"new playthrough is isolated")
local gold=state();gold:bind({save={version="gold",meta={playthroughId="one"}}},storage)
check(#gold.records==0,"different game is isolated")
area="ROUTE_3";check(#b:list()==0,"here tracks current area")
b.filter="all";check(#b:list()==1,"all includes other routes")
b:action("area");check(not b:note().area,"route binding can be removed")
b:action("area");check(b:note().area=="ROUTE_3","route binding uses current area")
failWrites=true;clock=8;b:flush(true);check(b.saveAt~=nil and b.error=="NOT SAVED - TRY AGAIN","write failure retains dirty data")
failWrites=false;clock=12;b:flush();check(not b.saveAt and not b.error,"failed save retries successfully")
local rows=b:wrapped(string.rep("one two three ",80),100)
check(#rows>6,"long text creates pages")
local idle=writes;b:takeChanged();for i=1,10000 do b:flush() end
check(writes==idle and not b:takeChanged(),"idle loop does no writes or redraws")
local started=os.clock();b:action("view","draw");b:pointer("down",20,60)
for i=1,10000 do b:pointer("move",20+(i%200),70+math.sin(i)*12) end
b:pointer("up",30,60)
print(string.format("Notes input benchmark: 10000 points %.2f ms (CPU, no device/render timing)",(os.clock()-started)*1000))
local strokes, points = #b:note().strokes, b:note().pointCount
b:pointer("down",20,80); b:pointer("up",180,90)
check(b.error=="HOST MISSING LIVE DRAWING INPUT", "down/up-only hosts report missing motion")
check(#b:note().strokes==strokes and b:note().pointCount==points,"missing motion never invents a straight line")
b:action("dismiss"); b:pointer("down",50,70); b:pointer("up",50,70)
check(#b:note().strokes==strokes+1,"a deliberate tap still draws a dot")
failWrites=true; b:bind({save={version="gold",meta={playthroughId="three"}}},storage)
check(b.pendingBind and b.saveAt,"save failure on playthrough switch keeps pending data")
local oldCount=#b.records; b:action("new")
check(#b.records==oldCount,"new playthrough cannot edit the failed old save")
failWrites=false;clock=20;b:flush()
check(not b.pendingBind and #b.records==0,"successful retry completes the playthrough switch")
local old=state();old:bind(game,storage)
check(#old.records[1].strokes==strokes+1,"retry writes to the original playthrough")
local unavailable=state();unavailable:bind(game,nil);unavailable:action("new")
check(unavailable.readFailed and #unavailable.records==0,"unavailable storage does not accept unsavable notes")
print(count.." Notes checks passed")
