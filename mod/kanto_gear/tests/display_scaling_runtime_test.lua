local T=require("tests.modkit")
local run=T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")),{generation=1,data=T.fixtures.load()})
local up=assert(loadfile(os.getenv("KANTO_GEAR_MOD_PATH").."/tests/support/runtime.lua"))().get
local function hook(name)
  for _,entry in ipairs(run.loader.hooks.chains[name] or {}) do if entry.owner=="kanto_gear" then return entry.callback end end
end
local output=hook("render.output")
local display=up(hook("input.step"),"displayRuntime")
local theme=up(output,"THEME")
local schema
for _,row in ipairs(theme.optionSchema) do if row.key=="integer_scaling" then schema=row end end
T.check(schema and schema.default==false,"proportional fit is the explicit default")
local source=love.graphics.newCanvas(240,216)
up(output,"canvas",source);up(output,"active",true);up(output,"dirty",false)
up(output,"hasDisplay",function() return true end)
local options={display_mode="fullscreen",integer_scaling=false,fullscreen_start="gear"}
run.loader.modOptions.kanto_gear=options
-- Use the fallback compositor without invoking any game screen.
theme.windowMode=function() return "fullscreen" end
local dpi=1
love.graphics.getDPIScale=function() return dpi end
love.graphics.getDimensions=function() return 640,480 end
love.graphics.getPixelDimensions=function() return 640*dpi,480*dpi end
local touched
up(display.primaryTouch,"touchEvent",function(value) touched=value end)
for _,density in ipairs({1,1.25,2,3}) do
  dpi=density
  for _,enabled in ipairs({false,true}) do
    options.integer_scaling=enabled
    theme.nativeWindowLayout=nil
    T.check(output(function() return false end,{canvas=source,width=640,height=480}),"fallback output handles Gear")
    local rect=up(output,"primaryBottomRect")
    local expected=theme:fitRect({x=0,y=0,w=640,h=480},240,216,enabled,dpi)
    T.eq(rect.x,expected.x,"output uses the physical placement helper")
    T.eq(rect.w,expected.w,"integer selection reaches the compositor")
    display.primaryTouch("down",rect.x+rect.w/2,rect.y+rect.h/2)
    T.eq(touched,"down,80,72","touches map through the actual drawn rectangle")
  end
end
love.graphics.getDimensions=function() return 640,480 end
love.graphics.getPixelDimensions=function() return 1536,960 end
options.integer_scaling=true;theme.nativeWindowLayout=nil
output(function() return false end,{canvas=source,width=640,height=480})
local asymmetric=up(output,"primaryBottomRect")
T.eq(asymmetric.w*2.4/240,asymmetric.h*2/216,"asymmetric host DPI still produces square physical pixels")
display.primaryTouch("down",asymmetric.x+asymmetric.w/2,asymmetric.y+asymmetric.h/2)
T.eq(touched,"down,80,72","asymmetric DPI preserves source touch coordinates")
local preference=up(up(hook("render.compose"),"pumpDisplay"),"displayPreference")
options.display_mode="separate";options.display_target="secondary"
up(output,"companion",{scalingAvailable=function() return true end})
options.integer_scaling=false;T.eq(preference(),"secondary:fit","fit reaches a capable second display")
options.integer_scaling=true;T.eq(preference(),"secondary:integer","integer reaches a capable second display")
up(output,"companion",{})
T.eq(preference(),"secondary","older hosts keep their supported routing token")
T.check(not display.integerScalingAvailable(),"an older native host is not reported as supporting the new mode")
display.settings.category=2
for _,row in ipairs(display.settingsModel().rows) do
  if row.key=="integer_scaling" then
    T.eq(row.value,"HOST UPDATE REQUIRED","the unsupported row explains why it is disabled")
    T.eq(row.choices,nil,"unsupported choices cannot hide the host requirement behind a switch")
    T.eq(row.enabled,false,"an older host keeps the scaling control inactive")
  end
end
T.check(not display.cycleSetting({key="integer_scaling",source={type="toggle"}},1),"an unsupported output cannot animate or apply an integer choice")
run.release();T.finish("Gear scaling output and touch")
