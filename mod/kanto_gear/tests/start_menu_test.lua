local Menu = dofile("mod/kanto_gear/start_menu.lua")
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
print("start menu: " .. n .. " checks passed")
