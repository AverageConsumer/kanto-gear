return function(T, display, tap)
  local Client = require("src.online.Client")
  local before = Client.state()
  T.eq(display.storeEntry(display.storeById.pss).state, "get", "PSS starts in Silph Store")
  T.check(display.setPackageInstalled("pss", true), "PSS installs through the existing Store")
  T.check(display.openHomeApp("pss"), "installed PSS opens")
  T.eq(Client.state(), before, "opening app does not establish a network connection")
  local model=display.pss
  T.check(model.listener~=nil, "open app subscribes to the host")
  for _, state in ipairs({"offline","connecting","reconnecting","online","error","unavailable"}) do
    model.state,model.inUse,model.rows,model.selected=state,false,{},nil
    local ok,err=pcall(display.drawPss)
    T.check(ok,"PSS renders "..state..": "..tostring(err))
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
  model.selected,model.selectedRow="sample",model.rows[1]
  T.check(pcall(display.drawPss),"player detail renders")
  if tap then
    tap(5,5)
    T.check(not model.selected and model.listener~=nil,"header Back first closes the detail")
    tap(5,5)
    T.check(model.listener==nil,"second Back closes PSS subscription")
  else model:close() end
  T.eq(Client.state(),before,"viewing and closing never modifies the host connection")
  display.openHomeApp("party")
  display.setPackageInstalled("pss", false)
end
