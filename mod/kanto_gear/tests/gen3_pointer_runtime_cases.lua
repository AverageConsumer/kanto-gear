return function(T, run, display, raw)
  local function value(fn, key)
    for i=1,debug.getinfo(fn,"u").nups do
      local name,v=debug.getupvalue(fn,i)
      if name==key then return v end
    end
    error("missing upvalue "..key)
  end
  local function hook(name)
    for _,e in ipairs(run.loader.hooks.chains[name] or {}) do
      if e.owner=="kanto_gear" then return e.callback end
    end
  end
  local theme=value(display.drawContents,"THEME")
  local refresh=value(hook("render.compose"),"refreshBattle")
  local tap=value(value(hook("render.compose"),"touchEvent"),"tap")
  require("src.core.game3.battle").reset()
  require("src.ui.game3.stack").clear()
  require("src.ui.game3.message").reset()
  display.gen3:refresh();display.gen3.syncScreens();refresh()
  local oldTime,now=love.timer.getTime,1000
  love.timer.getTime=function() return now end
  local options=run.loader.modOptions.kanto_gear
  options.theme_v3,options.ui_motion,options.display_mode="hgss",false,"combined"
  for _,layout in ipairs({"stacked","side","overlay"}) do
    for _,source in ipairs({"mouse","touch"}) do
      options.combined_layout=layout
      run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3"})
      local rect=run.loader.hooks:call("render.viewport",function(ctx) return {x=0,y=0,width=ctx.width,height=ctx.height} end,
        {width=1280,height=720,generation=3})
      T.check(display.openHomeApp("party"),"FRLG Party opens for "..layout)
      local function paint()
        run.loader.hooks:call("render.window",function() end,raw,{
          canvas=love.graphics.newCanvas(rect.width,rect.height),x=rect.x,y=rect.y,
          width=rect.width,height=rect.height,windowWidth=1280,windowHeight=720,generation=3})
      end
      paint()
      local bottom=value(display.primaryTouch,"primaryBottomRect")
      T.check(bottom and bottom.w>0,"combined mode exposes a real Gear hit region")
      local function click(hx,hy)
        display.syncTouchGuard();now=now+1
        local x,y=bottom.x+hx*bottom.w/240,bottom.y+hy*bottom.h/216
        if source=="mouse" then raw:mousepressed(x,y,1,false);raw:mousereleased(x,y,1,false)
        else raw:touchpressed("finger",x,y,0,0,1);raw:touchreleased("finger",x,y,0,0,1) end
      end
      local x,y=theme.hgss:partyPosition(1)
      click(x+35,y+25)
      T.eq(value(tap,"partyActionSlot"),1,source.." reaches Party through real FRLG handlers in "..layout)
      local api=value(display.openPartySummary,"mod")
      local count=api.world:canReorderParty() and 2 or 1
      local ax,ay,aw,ah=theme.hgss:partyActionRow(1,count)
      click(ax+aw/2,ay+ah/2)
      display.gen3.syncScreens()
      T.eq(display.gen3:gameView().stack:top().screenId,"Gen3SummaryMenu",
        source.." opens Stats in "..layout.." without bypassing the pointer path")
      require("src.ui.game3.summary_menu").close();display.gen3.syncScreens()
    end
  end
  love.timer.getTime=oldTime
end
