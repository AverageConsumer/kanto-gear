-- Exercise the real touch stream, including Home hit testing, over-game
-- pointer routing and interrupted gestures. Shared by GB/GBC and native GBA.
return function(T, run, display)
  local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
  local up = assert(loadfile(path .. "/tests/support/runtime.lua"))().get
  local hook, pointer
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"] or {}) do
    if entry.owner == "kanto_gear" then hook = entry.callback end
  end
  for _, entry in ipairs(run.loader.hooks.chains["input.pointer"] or {}) do
    if entry.owner == "kanto_gear" then pointer = entry.callback end
  end
  local touch = up(hook, "touchEvent")
  local theme = up(display.drawShinyHunt, "THEME")
  local mod = up(display.bindShinyHunt, "mod")
  local N, session = display.Notices, display.session
  local oldClock, now = love.timer.getTime, 1000
  love.timer.getTime = function() return now end
  mod.options:set("notifications", true)
  mod.options:set("notification_sound", false)
  mod.options:set("ui_motion", true)
  session.battle = nil
  session.pendingFly, session.pendingAction, session.fieldChoice = nil, nil, nil
  display.displaySetupModal = false
  local function ready()
    display.resetNotices()
    session.page, session.touchDown = "HOME", nil
    display.home.editing, display.home.library = false, false
    display.home.help, display.home.helpSeen = nil, true
    display.notify({key="gesture-test",title="TOUCH TEST",app="calendar",page="CALENDAR"})
    now = now + 10
    local card = display.noticeCard(now)
    T.check(card ~= nil, "a notice is ready in the native idle field")
    now = now + 0.3
    return card
  end
  local homeHit, hits = display.homeTileAt, 0
  display.homeTileAt = function(...) hits = hits + 1; return homeHit(...) end
  for _, delta in ipairs({{-60,0},{60,0},{0,-25},{0,60}}) do
    local card = ready()
    local before = hits
    touch("down,120,48",240,216)
    T.check(session.touchDown and session.touchDown.notice, "the card captures from finger down")
    T.eq(hits,before,"the widget underneath receives no hit test")
    T.eq(display.pressTouch("active",nil,session.touchDown),nil,"covered widgets have no press feedback")
    now = now + 8
    T.check(not display.updateHomeLongPress(now) and not display.home.editing,"holding a card cannot edit Home")
    T.eq(display.noticeCard(now),card,"a held card cannot time out under its finger")
    local x,y = 120+delta[1],48+delta[2]
    touch(("move,%d,%d"):format(x,y),240,216)
    local dx,dy = N.offset(card,now,228,32,191,true)
    T.eq(dx,delta[1],"the card follows the finger horizontally")
    T.eq(dy,delta[2],"the card follows the finger vertically")
    touch(("up,%d,%d"):format(x,y),240,216)
    T.check(card.closing and session.touchDown==nil,"release dismisses and relinquishes capture")
    T.eq(session.page,"HOME","releasing over another control cannot open an app")
    local rx,ry = N.offset(card,now,228,32,191,true)
    T.eq(rx,dx,"release has no horizontal jump")
    T.eq(ry,dy,"release has no vertical jump")
    rx,ry = N.offset(card,now+0.09,228,32,191,true)
    T.check(delta[1]~=0 and rx*delta[1]>dx*delta[1] or delta[2]~=0 and ry*delta[2]>dy*delta[2],
      "the card exits in the swipe direction")
  end
  local card = ready()
  touch("down,120,48",240,216)
  touch("move,128,48",240,216)
  touch("up,128,48",240,216)
  T.check(not card.closing and session.page=="HOME","a short drag returns without opening the app")
  T.eq(N.offset(card,now,228,32,191,true),8,"return starts at the finger, without a jump")
  T.eq(N.offset(card,now+0.13,228,32,191,true),0,"the card settles back in place")
  now = now + 0.2
  touch("down,120,48",240,216)
  session.battle = {kind="wild"}
  touch("up,120,48",240,216)
  T.eq(session.page,"HOME","a battle beginning during the gesture cancels its action")
  T.eq(session.touchDown,nil,"the interrupted finger is consumed through release")
  session.battle = nil
  card = ready()
  touch("down,120,48",240,216)
  touch("cancel,0,0",240,216)
  T.check(not card.closing and session.touchDown==nil,"cancellation neither opens nor dismisses")
  touch("down,120,48",240,216)
  display.resetNotices()
  touch("up,120,48",240,216)
  T.eq(session.page,"HOME","save replacement cannot leak the old release to Home")
  card = ready()
  touch("down,120,48",240,216)
  display.resetNotices()
  session.touchDown, session.primaryBottomRect = nil, nil
  local native = 0
  pointer(function() native=native+1 end, display.sourceGame or session.game,
    {phase="released",x=2000,y=2000})
  T.eq(native,0,"a captured release never leaks after output and session reset")
  T.check(not display.noticeOwnsTouch("canvas"),"reset capture ends with its original finger")
  card = ready()
  display.drawNoticeOverGame({x=0,y=0,w=960,h=864})
  local r=display.notices.overRect
  T.check(r~=nil,"the hidden-Gear notice has a pointer transform")
  if r then
    local x,y=r.x+r.w/2,r.y+r.h/2
    T.check(display.noticePointer({phase="pressed",x=x,y=y}),"over-game press is captured")
    T.check(display.noticePointer({phase="moved",x=x-60*r.scale,y=y}),"over-game motion remains captured")
    T.eq(N.offset(card,now,228,32,191,true),-60,"over-game card follows the same native drag distance")
    display.notices.overRect=nil
    T.check(display.noticePointer({phase="cancelled"}),"cancellation stays captured without a painted rectangle")
    T.eq(session.page,"HOME","over-game cancellation does not open the app")
  end
  display.homeTileAt = homeHit
  display.resetNotices()
  love.timer.getTime = oldClock
end
