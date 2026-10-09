return function(T, display, H)
  local pressed, begin = 0, H.beginPress
  H.beginPress = function(self, ...)
    local result = begin(self, ...)
    if result then pressed = pressed + 1 end
    return result
  end
  local function at(x, y, draw, expected, label)
    H:setTouch(x / 1.5, y / 1.5)
    pressed = 0; draw()
    T.eq(pressed, expected, label)
    T.check(not H.pressActive, "press rendering balances its graphics stack")
  end
  at(30, 40, function() H:tab(7,33,70,18,"TAB",true) end, 0,
    "the current tab stays still")
  at(30, 40, function() H:tab(7,33,70,18,"TAB",false) end, 1,
    "another tab still responds")
  at(30, 40, function() H:tab(7,33,70,18,"TAB",true,nil,true) end, 1,
    "a current tab may respond when it resets a later page")
  local entry = {label="ITEM",x=7,y=33,w=226,h=28,disabled=true}
  local menu = {entries={entry},total=1,first=1,last=1}
  at(30, 40, function() H:startMenu(menu) end, 0, "inert menu entries stay still")
  entry.disabled=false
  at(30, 40, function() H:startMenu(menu) end, 1, "usable menu entries respond")
  entry.disabled=true
  at(30, 40, function() H:nativeGrid(menu) end, 0, "empty inert storage slots stay still")
  local quantity={label="POTION",qty=1,max=3}
  at(40,110,function() H:pcQuantity(quantity) end,0,"clamped minus stays still at one")
  T.eq(H:pcQuantityHit(40,110,quantity),nil,"clamped minus has no touch action at one")
  at(190,110,function() H:pcQuantity(quantity) end,1,"quantity plus responds below its maximum")
  quantity.qty=3
  at(190,110,function() H:pcQuantity(quantity) end,0,"clamped plus stays still at its maximum")
  T.eq(H:pcQuantityHit(190,110,quantity),nil,"clamped plus has no touch action at maximum")
  quantity.wrap=true
  at(190,110,function() H:pcQuantity(quantity) end,1,"native wrapping quantity still responds at maximum")
  T.eq(H:pcQuantityHit(190,110,quantity),"plus","native wrapping retains its touch action")
  quantity.qty,quantity.max=1,1
  at(40,110,function() H:pcQuantity(quantity) end,0,"single-item wrapping minus stays still")
  at(190,110,function() H:pcQuantity(quantity) end,0,"single-item wrapping plus stays still")
  at(40,170,function() H:pcQuantity(quantity) end,1,"quantity confirmation remains available")
  local app={id="notes",label="NOTES",icon="notes",category="UTILITY",state="soon"}
  at(60,85,function() H:storeAppCard(7,53,111,app,{}) end,0,
    "a disabled install action cannot bounce its containing card")
  at(20,65,function() H:storeAppCard(7,53,111,app,{}) end,1,
    "the same card still responds where it opens details")
  at(40,120,function() H:storePreview(app,7,90,226,73,false) end,0,
    "static store detail previews stay still")
  local keys={{label="A",row=1,col=1},{label="DEL",action="delete"},{label="OK",action="confirm"}}
  local naming=display.NamingPage.model("",keys,7,0)
  local delete=naming.entries[2]
  at(delete.x+10,delete.y+10,function() H:naming(naming) end,0,"empty-name DEL stays still")
  T.eq(display.NamingPage.hit(naming,delete.x+10,delete.y+10),nil,"empty-name DEL has no touch action")
  display.NamingPage.availability(naming,7,7)
  local letter=naming.entries[1]
  at(letter.x+10,letter.y+10,function() H:naming(naming) end,0,"full-name character keys stay still")
  display.NamingPage.availability(naming,1,7)
  at(delete.x+10,delete.y+10,function() H:naming(naming) end,1,"nonempty-name DEL responds")
  local note={title="NOTE",text="A",tasks={},strokes={}}
  local state={view="list",filter="here",page=1,ctx={},note=function() return note end,list=function() return {} end}
  at(30,40,function() H:notes(state) end,0,"the current Notes filter stays still")
  at(160,40,function() H:notes(state) end,1,"another Notes filter responds")
  state.view,state.draft,state.cursor,state.editTarget="edit","A",0,"text"
  state.wrapped=function() return {{text="A",first=0,last=1}} end
  at(20,78,function() H:notes(state) end,0,"the left text cursor stays still at its boundary")
  at(160,198,function() H:notes(state) end,0,"backspace stays still before the first character")
  state.cursor=1
  at(45,78,function() H:notes(state) end,0,"the right text cursor stays still at its boundary")
  at(160,198,function() H:notes(state) end,1,"backspace responds when it can delete")
  state.error="TEXT LIMIT REACHED"
  at(20,100,function() H:notes(state) end,0,"Notes errors block the covered keyboard's animation")
  at(100,180,function() H:notes(state) end,1,"the error dismiss button still responds")
  H:setTouch(20,25,false)
  T.eq(H:isPressed(0,0,100,100),false,"a covered screen suppresses press feedback centrally")
  T.eq(display.pressTouch("locked",nil,{},true,true),nil,"blocked owned panels suppress press feedback")
  H:setTouch(); H.beginPress=begin
end
