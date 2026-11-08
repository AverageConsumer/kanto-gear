local root = os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local _, _, theme = assert(loadfile(root .. "/core/theme.lua"))()()
local checks = 0
local function near(a,b) assert(math.abs(a-b)<1e-6,tostring(a).." ~= "..tostring(b));checks=checks+1 end
local region = {x=0,y=0,w=640,h=480}
local fit, integer = theme:fitRect(region,240,216,false), theme:fitRect(region,240,216,true)
near(fit.w,1600/3); near(fit.h,480); near(integer.w,480); near(integer.h,432)
near(integer.x,80); near(integer.y,24)
local small = theme:fitRect({x=0,y=0,w=480,h=320},240,216,true)
near(small.w,240); near(small.h,216)
for _, dpi in ipairs({1,1.25,1.5,2,3}) do
  for _, size in ipairs({{240,216},{320,200},{480,320},{480,432},{640,480},{721,649},{960,640}}) do
    for _, source in ipairs({{160,144},{240,216}}) do
      for _, enabled in ipairs({false,true}) do
        local rect={x=.3,y=.7,w=size[1],h=size[2]}
        local r=theme:fitRect(rect,source[1],source[2],enabled,dpi)
        near(r.w/source[1],r.h/source[2])
        near(r.x*dpi,math.floor(r.x*dpi+.5));near(r.y*dpi,math.floor(r.y*dpi+.5))
        assert(r.x>=rect.x-1e-6 and r.y>=rect.y-1e-6)
        assert(r.x+r.w<=rect.x+rect.w+1e-6 and r.y+r.h<=rect.y+rect.h+1e-6)
        local available=math.min((math.floor((rect.x+rect.w)*dpi)-math.ceil(rect.x*dpi))/source[1],
          (math.floor((rect.y+rect.h)*dpi)-math.ceil(rect.y*dpi))/source[2])
        if enabled and available>=1 then near(r.w*dpi/source[1],math.floor(available+1e-7))
        else near(r.w*dpi/source[1],available) end
      end
    end
  end
end
for _, enabled in ipairs({false,true}) do
  local r=theme:fitRect({x=0,y=0,w=320,h=240},240,216,enabled,2.4,2)
  near(r.w*2.4/240,r.h*2/216)
  near(r.x*2.4,math.floor(r.x*2.4+.5));near(r.y*2,math.floor(r.y*2+.5))
  if enabled then near(r.w*2.4,480);near(r.h*2,432) end
end
print(checks.." scaling geometry checks passed")
