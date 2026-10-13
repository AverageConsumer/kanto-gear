-- Common PC party layout, with real native pickup/place/cancel handlers.
local path=assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T=require("tests.modkit")
_G.KANTO_GEAR_RENDER_CAPTURE=function(run,display,raw)
  local session=raw.session
  local Box=require("src.ui.game3.box_storage_ui")
  local Stack=require("src.ui.game3.stack")
  local P=require("src.core.game3.pokemon")
  local Schema=require("src.core.game3.save_schema_firered")
  local scratch=Schema.newGame({version=os.getenv("POKEPORT_VERSION"),name="TEST",rngSeed=481})
  require("src.core.game3.party").giveMon(scratch,P.speciesFromNational(25),10)
  local incoming=scratch.party[1]
  local savedParty,savedBox,savedCurrent=session.party,session.storage.boxes[1].mons,session.storage.currentBox
  local function input(key) return {wasPressed=function(_,k) return key==k end,isDown=function() return false end} end
  local function menu()
    for _=1,120 do
      if not Box.isPresentationBusy or not Box.isPresentationBusy() then break end
      Box.update(1/60)
    end
    T.check(not Box.isPresentationBusy or not Box.isPresentationBusy(),"native PC transition reaches its input-ready state")
    display.gen3.syncScreens()
    local m=assert(display.startMenu())
    local ok,err=pcall(display.drawContents);T.check(ok,"common PC team renders: "..tostring(err))
    return m
  end
  local function select(index)
    T.check(display.StartMenu.select(menu(),index),"explicit native slot is selectable")
    Box.handleInput(input("a"))
  end
  for _,style in ipairs({"hgss","hgss_dark"}) do
    run.loader.modOptions.kanto_gear.theme_v3=style
    run.loader.modOptions.kanto_gear.ui_motion=false
    run.loader.events:emit("mod.options_changed",{mod="kanto_gear",key="theme_v3"})
    session.party={savedParty[1]};session.storage.boxes[1].mons={[8]=incoming};session.storage.currentBox=1
    Box.show({session=session,subMode="move"})
    if Box.isPresentationBusy and Box.isPresentationBusy() then
      local opening=assert(display.startMenu())
      T.check(display.StartMenu.model(opening)~=nil,"opening PC still supplies a visible page")
      T.eq(display.StartMenu.cursor(opening),nil,"PC opening blocks touch until the native animation accepts input")
    end
    select(1)
    local m=menu()
    T.check(m.boxParty,"PC uses the shared team presentation")
    for slot=1,6 do
      local x,y=display.gen3Ui.layout:partyPosition(slot)
      T.same(m.items[slot].rect,{x,y,112,56},"all PC cards use the common team geometry")
      T.eq(display.StartMenu.hit(m,x+56,y+28),slot==1 and 1 or nil,"unoccupied slots are inert while browsing")
    end
    T.eq(display.StartMenu.hit(m,12,12),"back","header cancels the team drawer")
    Box.handleInput(input("b"));T.eq(Box.mode,"browse","native Back returns to the box")
    m=menu()
    T.eq(#m.items,33,"Gen 3 retains all thirty native box slots")
    T.eq(m.items[3].label,session.storage.boxes[1].name.."  1/30","sparse native storage counts occupied slots")
    session.storage.currentBox=2
    T.eq(m.valid(),false,"a different native box expires touch targets from the previous box")
    session.storage.currentBox=1
    for slot=1,30 do
      local r=m.items[slot+3].rect
      T.same(r,{7+(slot-1)%6*38,85+math.floor((slot-1)/6)*24,36,22},"common box builder preserves native Gen 3 geometry")
      T.eq(display.StartMenu.hit(m,r[1]+r[3]/2,r[2]+r[4]/2),slot==8 and slot+3 or nil,"empty box cells have no action while browsing")
    end
    select(11);select(1)
    T.eq(Box.holdingMon,incoming,"native handler picks up the actual boxed partner")
    select(1);m=menu()
    T.check(m.emptyTargets,"held partner exposes empty destinations")
    for slot=2,6 do
      local rect=m.items[slot].rect
      T.eq(display.StartMenu.hit(m,rect[1]+56,rect[2]+28),slot,"empty common card preserves native target identity")
    end
    select(2)
    T.eq(session.party[2],incoming,"native handler places the actual partner in the selected slot")
    T.eq(#session.party,2,"native placement changes the party exactly once")
    T.eq(session.storage.boxes[1].mons[8],nil,"native pickup removes the original box entry")
    T.eq(Box.holdingMon,nil,"native placement ends the held state")
    m=menu();T.check(not m.emptyTargets,"completed placement restores normal empty cards")
    select(7);T.eq(Box.mode,"browse","native cancel entry still returns to the box")
    Box.close();Stack.clear()
  end
  session.party,session.storage.boxes[1].mons,session.storage.currentBox=savedParty,savedBox,savedCurrent
end
dofile(path .. "/tests/gen3_fixture.lua")
