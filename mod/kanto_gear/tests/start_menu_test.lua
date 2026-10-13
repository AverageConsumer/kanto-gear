local Menu = dofile("mod/kanto_gear/adapters/start_menu.lua")
local n = 0
local function eq(a, b, label)
  assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b)); n = n + 1
end
for _, gen in ipairs({ 1, 2 }) do
  for count = 1, 19 do
    local top = { screenId = gen == 1 and "StartMenu" or "Gen2StartMenu",
      startCloses = true, update = function() end, items = {}, index = 1, list = { index = 1 } }
    for i = 1, count do top.items[i] = { label = "ROW " .. i } end
    for i = 1, count do
      eq(Menu.select(top, i), true, "native selection accepted")
      local first, visible, selected = Menu.window(top)
      eq(selected, i, "D-pad focus is native")
      eq(i >= first and i < first + visible, true, "focus always visible")
      eq(Menu.hit(top, 100, 33 + (i - first) * 31 + 10), i, "touch maps to same row")
      eq(Menu.hit(top, 100, 61), nil, "row gaps cannot select")
      eq(Menu.hit(top, 234, 40), nil, "right margin cannot select")
      eq(Menu.hit(top, 20, 10), "back", "close is separate from quit")
      eq(Menu.hit(top, 20, 200), first > 1 and "previous" or nil, "previous boundary")
      eq(Menu.hit(top, 200, 200), first + visible <= count and "next" or nil, "next boundary")
    end
    eq(Menu.select(top, 0), false, "invalid index rejected")
    eq(Menu.select(top, count + 1), false, "past-end index rejected")
    if gen == 2 then
      for _, phase in ipairs({ "confirm", "confirmContest", "unknown" }) do
        top.phase = phase
        eq(Menu.cursor(top), nil, "confirmations and unknown phases own their input")
      end
    end
    top.screenId = "OtherModMenu"
    eq(Menu.cursor(top), nil, "unrelated menus not inferred from row shape")
  end
end
eq(Menu.label({ label = "<PO><KE>GEAR" }), "POKéGEAR", "native font tokens expanded")
eq(Menu.label({ label = "図鑑 漢字" }), "図鑑 漢字", "translated labels preserved")
local lockedBack = { screenId = "CompanionMenu", valid = function() return true end,
  update = function() end, index = 1, items = { { label = "CONTINUE" } }, back = false }
eq(Menu.hit(lockedBack, 14, 13), nil, "native results with no back action expose no inert target")
local target = { screenId = "Gen3Menu", valid = function() return true end,
  update = function() end, index = 1, items = { { label = "SAME NAME", right = "YOUR SIDE", targetSide = "player" } } }
eq(Menu.model(target).entries[1].targetSide, "player", "target allegiance reaches the renderer")
eq(Menu.hit(target, 100, 45), 1, "own-side targets remain selectable")
local beforeSide = Menu.redrawKey(target)
target.items[1].targetSide = "enemy"
eq(Menu.redrawKey(target) ~= beforeSide, true, "allegiance changes invalidate a cached target row")
eq(Menu.model(lockedBack).entries[1].targetSide, nil, "ordinary menus have no target styling")
target.battleTargets={0,2,3,1}
for i=2,4 do target.items[i]={label="TARGET "..i,targetSide="enemy",right="FOE"} end
for i,row in ipairs(Menu.model(target).entries) do
  eq(row.y+row.h<=216,true,"all four taller target rows fit below the header")
  eq(Menu.hit(target,row.x+row.w-1,row.y+row.h-1),i,"right edge of each target badge selects its own row")
  eq(Menu.hit(target,row.x+10,row.y+row.h),nil,"taller target rows retain an inactive gap")
end
local ItemPage=dofile("mod/kanto_gear/ui/pages/item.lua")
local actions={screenId="CompanionMenu",update=function() end,valid=function() return true end,index=1,
  fixedLayout=true,items={{label="USE"},{label="GIVE"},{label="TOSS"},{label="CANCEL"}}}
ItemPage.layout(actions.items)
eq(Menu.direction(actions,"right"),2,"item actions navigate to the visible right button")
eq(Menu.direction(actions,"down"),3,"item actions navigate to the visible next row")
actions.index=4
eq(Menu.direction(actions,"up"),2,"return navigation keeps the right column")
eq(Menu.direction(actions,"left"),3,"return navigation keeps the lower row")
actions.fixedLayout=false;actions.nativePocket=true
eq(Menu.direction(actions,"left"),nil,"native pocket changes retain their handler")
actions.items[1].inert=true;actions.index=4
eq(Menu.direction(actions,"down"),2,"inert list entries are skipped")
print("start menu: " .. n .. " checks passed")
