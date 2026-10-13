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
  if H.v4SettingsTabs then
    local model = { category = "battle", tabs = { { id = "battle", label = "BATTLE" } }, tab = 1,
      label = "BATTLE", accent = "red", page = 1, pages = 1, selected = "caught_icon",
      rows = { { key = "caught_icon", label = "CAUGHT ICON", raw = true,
        choices = { { "OFF", false }, { "ON", true } }, info = "TEST" } } }
    at(200, 80, function() H:settings(model) end, 0,
      "the selected inline option cannot animate its containing switch")
    at(140, 80, function() H:settings(model) end, 1,
      "an inline option that changes the value responds")
    local partyInfo, helpLines, clock = H.partyInfo, H.settingsHelpLines, H.clock
    local frozen, motion, now, rendered = H.frozenTime, H.motionEnabled, 0
    H.frozenTime, H.motionEnabled, H.v4HelpKey = nil, true, nil
    H.clock = function() return now end
    H.settingsHelpLines = function() return { "日本語" } end
    H.partyInfo = function(self, text, x, y, ...)
      -- the help panel rises to meet short categories; its text starts at x 16
      if x == 16 then rendered = text end
      return partyInfo(self, text, x, y, ...)
    end
    H:setTouch()
    H:settings(model)
    now = 0.02
    H:settings(model)
    T.eq(rendered, "日", "typewriter reveals whole Japanese glyphs")
    H.partyInfo, H.settingsHelpLines, H.clock = partyInfo, helpLines, clock
    H.frozenTime, H.motionEnabled = frozen, motion
  end
  local region = { interactive=true,fly=true,width=160,height=128,cursorX=100,cursorY=90,
    area="TOWN",status="NOT VISITED",drawMap=function() end }
  at(120,170,function() H:regionMap(region) end,0,"unavailable Fly confirmation stays still")
  region.canFly,region.status=true,"FLY"
  at(120,170,function() H:regionMap(region) end,1,"available Fly button responds across its full card")
  at(120,90,function() H:regionMap(region) end,0,"map dragging has no decorative button animation")
  local entry = {label="ITEM",x=7,y=33,w=226,h=28,disabled=true}
  local menu = {entries={entry},total=1,first=1,last=1}
  at(30, 40, function() H:startMenu(menu) end, 0, "inert menu entries stay still")
  entry.disabled=false
  at(30, 40, function() H:startMenu(menu) end, 1, "usable menu entries respond")
  entry.disabled=true
  at(30, 40, function() H:nativeGrid(menu) end, 0, "empty inert storage slots stay still")
  local move={available=true,name="TACKLE",type="NORMAL",disabled=true,disabledLabel="NO PP",ppText="0/35"}
  at(40,60,function() H:battleMoveCard(move,6,33,true,false) end,0,"empty-PP grid card stays still")
  at(40,145,function() H:battleFullMoves({moves={move},details=true}) end,0,"blocked Full Gear move stays still")
  at(108,125,function() H:battleFullMoves({moves={move},details=true}) end,1,"blocked move may still open its own details")
  at(108,125,function() H:battleFullMoves({moves={move},details=false}) end,0,"missing move details do not animate the disabled parent")
  at(40,145,function() H:battleFullMoves({moves={},details=true}) end,0,"empty Full Gear move slots stay still")
  for _, point in ipairs({ {120,80}, {40,170}, {120,170}, {200,170} }) do
    for _, enabled in ipairs({ false, true }) do
      at(point[1],point[2],function() H:battleRoot({},function() end,nil,nil,nil,enabled) end,
        enabled and 1 or 0,"only usable Companion commands respond across their visible buttons")
    end
  end
  at(120,156,function() H:battleRoot({},function() end,nil,nil,nil,true) end,0,
    "the gap between Companion commands stays still")
  at(120,70,function() H:enemyInfoOpponents({{id=1,side="enemy",absent=true}},function() end) end,0,
    "an absent opponent has no press animation")
  move.disabled,move.disabledLabel=false,nil
  at(40,60,function() H:battleMoveCard(move,6,33,false,false) end,1,"usable grid card still responds")
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
  local item = display.ItemPage.model({label="POTION",count=2,icon="medicine",lines={"RESTORES HP."}},
    {{label="USE"},{label="TOSS",enabled=false}},true,nil,function(label) return label end)
  local x,y,w,h=display.ItemPage.rect(1,2)
  at(x+w/2,y+h/2,function() H:bagDetail(item) end,1,"available shared item action responds")
  x,y,w,h=display.ItemPage.rect(2,2)
  at(x+w/2,y+h/2,function() H:bagDetail(item) end,0,"disabled shared item action stays still")
  item.canUse=false
  x,y,w,h=display.ItemPage.rect(1,2)
  at(x+w/2,y+h/2,function() H:bagDetail(item) end,0,"locked item card cannot animate an action")
  at(120,80,function() H:bagDetail(item) end,0,"item information never bounces as a control")
  local moves = { name="TESTMON", prompt="CHOOSE MOVE", moves={{name="TACKLE",type="NORMAL",typeLabel="NORMAL",available=true}} }
  at(120,80,function() display.MovePage.draw(H,moves) end,1,"usable move selection responds")
  at(120,120,function() display.MovePage.draw(H,moves) end,0,"empty move slot never responds")
  at(120,40,function() display.MovePage.draw(H,moves) end,0,"move context stays still")
  moves.newMove,moves.details=moves.moves[1],true
  at(120,40,function() display.MovePage.draw(H,moves) end,1,"new move responds when its details are available")
  moves.details=false
  at(120,40,function() display.MovePage.draw(H,moves) end,0,"new move stays still when details are unavailable")
  moves.message="HM moves cannot be forgotten!"
  at(120,40,function() display.MovePage.draw(H,moves) end,0,"native refusal never animates")
  moves.message=nil
  moves.enabled=false
  at(120,80,function() display.MovePage.draw(H,moves) end,0,"locked move chooser stays still")
  local learn={mon={},newMove=moves.moves[1],details=true,choices={"YES","NO"},prompt={"Stop learning?"}}
  at(60,187,function() display.MovePage.drawPrompt(H,learn) end,1,"learning answers respond")
  at(120,105,function() display.MovePage.drawPrompt(H,learn) end,1,"learning move details respond")
  at(120,140,function() display.MovePage.drawPrompt(H,learn) end,0,"learning question stays still")
  at(120,50,function() display.MovePage.drawPrompt(H,learn) end,0,"learning Pokemon stays still")
  learn.enabled=false
  at(60,187,function() display.MovePage.drawPrompt(H,learn) end,0,"locked learning answers stay still")
  at(120,105,function() display.MovePage.drawPrompt(H,learn) end,0,"covered learning details stay still")
  local growth={name="TESTMON",level="L5",rows={{label="MAX HP",value=20,delta=2}}}
  at(120,187,function() H:levelUp(growth) end,1,"level-up continuation responds")
  at(120,100,function() H:levelUp(growth) end,0,"level-up values stay still")
  at(120,50,function() H:levelUp(growth) end,0,"level-up Pokemon stays still")
  growth.enabled=false
  at(120,187,function() H:levelUp(growth) end,0,"locked level-up continuation stays still")
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
  local PG = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/ui/pages/pokegear.lua"))()
  local pg = { mode="card", card="radio", cards={}, radio={frequency="20.5",canTuneUp=false,stations={}} }
  at(210,80,function() H:pokegearScreen(pg,PG) end,0,"radio tuning stays still at its upper boundary")
  pg.radio.canTuneUp=true
  at(210,80,function() H:pokegearScreen(pg,PG) end,1,"radio tuning responds when it can move")
  state.error="TEXT LIMIT REACHED"
  at(20,100,function() H:notes(state) end,0,"Notes errors block the covered keyboard's animation")
  at(100,180,function() H:notes(state) end,1,"the error dismiss button still responds")
  H:setTouch(20,25,false)
  T.eq(H:isPressed(0,0,100,100),false,"a covered screen suppresses press feedback centrally")
  T.eq(display.pressTouch("locked",nil,{},true,true),nil,"blocked owned panels suppress press feedback")
  H:setTouch(); H.beginPress=begin
end
