return function(T, display, H)
  local Page = display.ItemPage
  for count = 1, 6 do
    local rows = {}
    for i = 1, count do rows[i] = { label = i == count and "EXIT" or "USE", id = i } end
    Page.layout(rows)
    local model = Page.model({ label = "POTION", count = 3, icon = "medicine", lines = { "RESTORES HP." } },
      rows, true, nil, function(label) return label end)
    T.eq(model.actions[count].label, "CANCEL", "native EXIT shares the companion cancel wording")
    T.check(pcall(H.bagDetail, H, model), "the shared item card renders " .. count .. " native actions")
    for i, row in ipairs(rows) do
      local x,y,w,h = unpack(row.rect)
      T.same(row.rect, { H:bagActionRect(i,count) }, "native draw and app taps use one item action rectangle")
      T.eq(Page.hit(model,x+w/2,y+h/2),i,"common item target preserves its original native index")
      T.eq(Page.hit(model,x-1,y+h/2),nil,"item action breathing room is not clickable")
      T.check(y>=148 and y+h<=210,"every action stays below the description and above the footer")
      model.actions[i].enabled=false
      T.eq(Page.hit(model,x+w/2,y+h/2),nil,"unavailable item action has no hit target")
      model.actions[i].enabled=true
      model.canUse=false
      T.eq(Page.hit(model,x+w/2,y+h/2),nil,"native presentation lock disables the whole action page")
      model.canUse=true
    end
    T.eq(Page.hit(model,120,100),nil,"touching the item description never invokes an action")
  end
end
