local root=os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local Setup=assert(loadfile(root.."/core/display_setup.lua"))()
local function eq(a,b,message) assert(a==b,message..": "..tostring(a).." ~= "..tostring(b)) end
local fresh=Setup.new(true)
fresh:bind(0,"combined"); fresh:tick(0,"combined",false,false)
eq(fresh.stage,nil,"scripts and busy states defer first use")
fresh:tick(1,"combined",false,true)
eq(fresh.stage,"welcome","first use opens at a safe boundary")
eq(fresh:override(),"combined","setup always stays on the main window")
fresh:test(2)
eq(fresh.selected,2,"test defaults to the safe return action")
fresh:tick(16.9,"combined",false,true); eq(fresh.stage,"test","test stays open before expiry")
fresh:tick(17,"combined",false,true); eq(fresh.stage,"welcome","timeout returns to the safe choice")
eq(fresh.armed,false,"timeout cannot reuse a held confirmation")
fresh:close(); eq(fresh.pending,false,"completed setup does not repeat for another save")
eq(fresh.draining,true,"closing consumes held inputs before resuming")
local existing=Setup.new(false)
existing:bind(0,"separate")
existing:tick(0,"separate",false,false)
existing:tick(1.9,"separate",false,false); eq(existing.fallback,false,"startup allows the native display to initialize")
existing:tick(2,"separate",false,false)
eq(existing.fallback,true,"missing output falls back even in a battle")
eq(existing.stage,nil,"recovery never interrupts a battle or script")
eq(existing.mode,"separate","fallback keeps the saved preference")
existing:tick(3,"separate",true,false); eq(existing.fallback,true,"a late display cannot flip the layout without consent")
existing:tick(4,"separate",true,true); eq(existing.stage,"recovery","recovery opens after the busy state ends")
existing:test(5); existing:tick(20,"separate",false,true)
eq(existing.stage,"recovery","failed retry retains a visible recovery route")
local stable=Setup.new(false)
stable:bind(0,"separate")
stable:tick(0,"separate",false,true); stable:tick(1,"separate",true,true)
stable:tick(2,"separate",false,true); stable:tick(3.9,"separate",false,true)
eq(stable.fallback,false,"a successful frame resets the outage grace period")
stable:tick(4,"separate",false,true); eq(stable.fallback,true,"a sustained outage eventually recovers")
local phone=Setup.new(false); phone:bind(0,"phone")
phone:tick(0,"phone",false,true); phone:tick(100,"phone",false,true)
eq(phone.fallback,false,"intentional browser pairing is not treated as a missing physical display")
local View=assert(loadfile(root.."/ui/display_setup.lua"))()
local font={getWidth=function(_,s) return #s*5 end,getHeight=function() return 7 end}
local G={getFont=function() return font end,push=function() end,pop=function() end,origin=function() end,
  setShader=function() end,setScissor=function() end,setColor=function() end,rectangle=function() end,setFont=function() end,print=function() end}
for _,size in ipairs({{320,288},{393,852},{402,874},{874,402},{1920,1080}}) do
  for _,stage in ipairs({"welcome","test","recovery"}) do
    local layout=View.draw(G,{width=size[1],height=size[2]},
      {stage=stage,selected=1,remaining=15,healthy=false},{font=font,small=font})
    for _,b in ipairs(layout.buttons) do
      assert(b.x>=0 and b.x+b.w<=size[1] and b.y>=0 and b.y+b.h<=size[2]*.72,"choices fit above the lower touch controls")
    end
    if stage=="test" then eq(layout.buttons[1].enabled,false,"unseen test output cannot be accepted") end
  end
end
print("PASS display setup safe boundaries, outage recovery, timeout and window geometry")
