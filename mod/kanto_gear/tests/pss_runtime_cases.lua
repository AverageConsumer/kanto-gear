return function(T, display, tap)
  assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/pss_trainer_cases.lua"))()(T, display)
  local Client = require("src.online.Client")
  local before = Client.state()
  T.eq(display.storeEntry(display.storeById.pss).state, "get", "PSS starts in Silph Store")
  T.check(display.setPackageInstalled("pss", true), "PSS installs through the existing Store")
  T.check(display.homeCatalog.surfaces.pss_widget.columns==12,
    "Silph Connect offers a full-width Home widget")
  local widget=display.homeWidgetData({pss=true})
  T.eq(widget.pss,display.pss,"Home widget shares the live app model")
  T.check(widget.pss.listener~=nil,"widget observes without opening app or connecting")
  T.check(display.openHomeApp("pss"), "installed PSS opens")
  T.eq(Client.state(), before, "opening app does not establish a network connection")
  local model=display.pss
  T.check(model.listener~=nil, "open app subscribes to the host")
  local home=display.home
  local layout,page,editing,help,library=home.layout,home.page,home.editing,home.help,home.library
  home.layout,home.page,home.editing,home.help,home.library={tiles={}},1,false,false,false
  T.check(display.Home.place(home.layout,display.homeCatalog,"pss_widget",1,1,1),
    "installed Silph Connect widget can be placed on Home")
  for _, state in ipairs({"offline","connecting","reconnecting","online","error","unavailable"}) do
    model.state,model.inUse,model.rows,model.selected=state,false,{},nil
    local ok,err=pcall(display.drawPss)
    T.check(ok,"PSS renders "..state..": "..tostring(err))
    T.check(pcall(display.drawHome),"Home widget renders "..state)
    local actions={}
    for _,hit in ipairs(model.hits) do actions[hit.action]=true end
    T.eq(actions.connect==true,state=="offline" or state=="error","connect availability matches "..state)
  end
  model.state,model.inUse="online",true
  display.drawPss()
  local disconnect=false
  for _,hit in ipairs(model.hits) do if hit.action=="disconnect" then disconnect=true end end
  T.check(not disconnect,"active host activity has no disconnect hit target")
  model.rows={{id="sample",name="TRAINER",version="crystal",where="game",status="busy"}}
  T.check(pcall(display.drawHome),"populated online widget renders")
  display.tapHome(120,65)
  T.eq(display.home.activeApp,"pss","tapping widget opens Silph Connect")
  model.selected,model.selectedRow="sample",model.rows[1]
  T.check(pcall(display.drawPss),"player detail renders")
  local function actions()
    local result={};for _,hit in ipairs(model.hits) do result[hit.action]=true end
    return result
  end
  T.check(not actions().battle and not actions().trade,"unavailable player exposes no battle/trade action")
  local theme
  for i=1,debug.getinfo(display.drawPss,"u").nups do
    local name,value=debug.getupvalue(display.drawPss,i)
    if name=="THEME" then theme=value end
  end
  local H=assert(theme).hgss
  local begin,pressed=H.beginPress,0
  H.beginPress=function(self,...)
    local value=begin(self,...);if value then pressed=pressed+1 end;return value
  end
  H:setTouch(40/1.5,168/1.5);display.drawPss()
  T.eq(pressed,0,"disabled invitation button never animates")
  model.rows[1].canInvite,model.ready=true,true
  pressed=0;display.drawPss()
  T.eq(pressed,1,"available invitation button responds")
  T.check(actions().battle and actions().trade,"ready player offers native battle and trade")
  model.incoming={id="preview-invite",mode="trade",from=model.rows[1]}
  model.canAccept=false;pressed=0;H:setTouch(170/1.5,168/1.5);display.drawPss()
  T.eq(pressed,0,"unsafe accept stays still")
  T.check(actions().decline and not actions().accept and not actions().battle,"incoming modal blocks all underlying actions")
  model.canAccept=true;pressed=0;display.drawPss()
  T.eq(pressed,1,"safe acceptance responds")
  model.incoming,model.canAccept=nil,nil
  H:setTouch();H.beginPress=begin
  model.rows[1].canInvite,model.ready=false,false
  if tap then
    tap(5,5)
    T.check(not model.selected and model.listener~=nil,"header Back first closes the detail")
    tap(5,5)
    T.check(model.listener~=nil,"second Back keeps background presence subscription")
  else model:close() end
  T.eq(Client.state(),before,"viewing and closing never modifies the host connection")
  display.openHomeApp("party")
  display.setPackageInstalled("pss", false)
  T.check(model.listener==nil,"removing the app releases presence subscription")
  T.eq(#home.layout.tiles,0,"uninstall removes the online widget")
  home.layout,home.page,home.editing,home.help,home.library=layout,page,editing,help,library
  home.widgetCache=nil
end
