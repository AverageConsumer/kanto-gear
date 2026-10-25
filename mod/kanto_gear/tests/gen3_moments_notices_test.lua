local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local Json = require("src.link.Json")
  local before = Json.encode(game.session)
  local events = run.loader.events
  events:emit("egg.hatched", {slot=1,species=1})
  events:emit("pokemon.evolved", {fromSpecies=129,toSpecies=130})
  local earned = {}
  for _, record in ipairs(display.moments.data.earned) do earned[record.id] = record end
  T.check(earned.first_hatch ~= nil, "native Gen 3 hatch events award the first-hatch moment")
  T.check(earned.gyarados_rise ~= nil, "canonical Gen 3 evolution IDs award the evolution moment")
  local count = #display.moments.data.earned
  events:emit("pokemon.evolved", {fromSpecies=129,toSpecies=130})
  T.eq(#display.moments.data.earned, count, "repeated native events cannot duplicate moments")
  display.notify({key="integration",app="shiny",page="SHINY",title="TEST"})
  T.check(display.noticeUnread("shiny") or display.session.page=="SHINY", "Gen 3 notices mark their destination")
  events:emit("save.loaded", {game=game})
  T.eq(#display.notices.queue, 0, "reloading cannot carry old notification cards into the rebound session")
  T.eq(display.notices.current, nil, "reloading drops a previously showing notification")
  T.check(not display.noticeUnread("shiny"), "reloading resets transient unread markers")
  local up = assert(loadfile(path .. "/tests/support/runtime.lua"))().get
  local mod = up(display.saveShinyHunt, "mod")
  local storage, save = mod.storage, mod.save
  mod.storage, mod.save = {write=function() return false end}, {set=function() return false end}
  T.check(not display.saveShinyHunt(), "an explicit write failure cannot report hunt persistence success")
  T.check(not display.saveMoments(), "an explicit write failure cannot report album persistence success")
  mod.storage, mod.save = storage, save
  display.saveShinyHunt()
  T.eq(Json.encode(game.session), before, "moments and notices leave the native save unchanged")
  assert(loadfile(path .. "/tests/support/notice_gestures.lua"))()(T,run,display)
end
dofile(path .. "/tests/gen3_fixture.lua")
