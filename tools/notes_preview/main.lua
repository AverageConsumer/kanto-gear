local root=assert(os.getenv("KANTO_GEAR_ROOT"))
local output=assert(os.getenv("KANTO_NOTES_PREVIEW_OUT"))
local function write(path,bytes)local f=assert(io.open(path,"wb"));f:write(bytes);f:close() end
function love.errorhandler(message)
  write(output.."/error.txt",debug.traceback(tostring(message),2))
  love.event.quit(1);return function()return 1 end
end
function love.load()
  local G=love.graphics
  local function file(name)local f=assert(io.open(root.."/mod/kanto_gear/"..name,"rb"));local bytes=f:read("*a");f:close();return love.filesystem.newFileData(bytes,name) end
  local glyphs=assert(loadfile(root.."/mod/kanto_gear/hgss_font_glyphs.lua"))()
  local function font(name)local f=G.newImageFont(love.image.newImageData(file(name)),glyphs);f:setFilter("nearest","nearest");return f end
  local utf8=require("utf8")
  local function chars(value)local out={};for _,c in utf8.codes(value)do out[#out+1]=utf8.char(c)end;return out end
  local catalog=assert(loadfile(root.."/mod/kanto_gear/lang/de.lua"))()
  local function tr(v)return catalog[v] or v end
  local H=assert(loadfile(root.."/mod/kanto_gear/hgss.lua"))()({graphics=G,
    bagIcon=G.newImage(file("kanto_bag.png")),
    box=function(mode,x,y,w,h,c)G.setColor(c);G.rectangle(mode,x,y,w,h)end,
    color=function(c)G.setColor(c)end,glyphs=chars,translate=tr,format=string.format,
    font=font("hgss_font.png"),smallFont=font("hgss_small_font.png"),largeFont=font("hgss_large_font.png")})
  local Notes=assert(loadfile(root.."/mod/kanto_gear/notes.lua"))()
  assert(loadfile(root.."/mod/kanto_gear/achievements_ui.lua"))()(H,G,tr,string.format)
  local sourceFile=assert(io.open(root.."/mod/kanto_gear/main.lua","rb"))
  local source=sourceFile:read("*a");sourceFile:close()
  local store=assert(loadstring("return "..assert(source:match("displayRuntime.storeCatalog = (%b{})"))))()
  for _,app in ipairs(store)do app.state="get";app.action="GET";app.reason=app.reason or app.category end
  assert(loadfile(root.."/mod/kanto_gear/notes_ui.lua"))()(H,G,tr)
  local S=Notes.new({time=function()return 0 end,measure=function(v)return H:partyInfoWidth(v)end,
    area=function()return "ROUTE_2","ROUTE 2"end,translate=tr,leave=function()end})
  S.records={{id=1,title="Später mit Zerschneider",text="Hier später mit Zerschneider zurückkommen. Den Weg hinter dem Baum prüfen.",area="ROUTE_2",areaName="ROUTE 2",tasks={{text="Weg hinter dem Baum prüfen",done=false},{text="Pokébälle kaufen",done=true}},strokes={{color=1,width=2,points={25,100,65,100,65,40,140,40}},{color=4,width=2,points={160,40,180,12,202,40,160,40}},{color=4,width=2,points={180,40,180,70}}},pointCount=12}}
  S.selected=1
  local c=G.newCanvas(240,216,{dpiscale=1});c:setFilter("nearest","nearest")
  local export=G.newCanvas(960,864,{dpiscale=1})
  for _,gen in ipairs({1,2})do for _,variant in ipairs({"light","dark"})do
    H:setVariant(variant=="dark")
    S.records[1].areaName=gen==1 and "ROUTE 2" or "ROUTE 32"
    for _,view in ipairs({"text","tasks","sketch","edit","draw","colors","list","store_today","store_apps"})do
      S.view=view=="colors" and "draw" or view;S.page=1;S.colorOpen=view=="colors"
      S.draft=S.records[1].text;S.cursor=#chars(S.draft);S.editTarget="text"
      G.push("all");G.setCanvas(c);G.origin();G.clear();G.scale(1.5);H:backdrop();G.origin()
      H:headerBar(tr(view=="edit" and "WRITE" or (view=="draw" or view=="colors") and "DRAW" or "NOTES"),true,false)
      H:headerClock("20:04","NITE",142,66,6);H:battery(214,8,4,false,true,H.colors.ink,H.colors.greenLight)
      if view=="store_today" or view=="store_apps" then
        H:headerBar(tr("SILPH STORE"),true,false)
        H:headerClock("20:04","NITE",142,66,6);H:battery(214,8,4,false,true,H.colors.ink,H.colors.greenLight)
        if view=="store_today" then H:storeToday({featured=store[1],recommended={store[5],store[7]}})
        else H:storeApps({apps={unpack(store,1,6)},page=1,pages=math.ceil(#store/6)})end
      else H:notes(S)end
      G.setCanvas(export);G.origin();G.clear();G.setColor(1,1,1,1);G.draw(c,0,0,0,4,4);G.setCanvas();G.pop()
      local data=export:newImageData();write(output.."/gen"..gen.."-"..variant.."-"..view..".png",data:encode("png"):getString());data:release()
    end
  end end
  -- Readback is included so the report does not mistake queued GPU work for
  -- completed rendering. This measures this desktop, not Thor frame latency.
  S.view="draw";S.colorOpen=false;S.records[1].strokes={};S.records[1].pointCount=0;S.inkRevision=S.inkRevision+1
  local samples={};S:pointer("down",20,80)
  for i=1,180 do
    S:pointer("move",20+(i%200),90+math.sin(i/12)*30)
    local t=love.timer.getTime();G.push("all");G.setCanvas(c);G.origin();H:notes(S);G.setCanvas();G.pop()
    local pixels=c:newImageData();pixels:release();samples[#samples+1]=(love.timer.getTime()-t)*1000
  end
  S:pointer("up",200,90);table.sort(samples)
  write(output.."/render-benchmark.txt",string.format("180 incremental ink frames including synchronous readback on desktop: median %.3f ms, p95 %.3f ms, max %.3f ms\n",samples[90],samples[171],samples[180]))
  love.event.quit(0)
end
