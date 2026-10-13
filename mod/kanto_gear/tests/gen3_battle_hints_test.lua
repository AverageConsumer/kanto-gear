-- Read-only Gen 3 hints must describe the native battle, not a parallel simulation.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local compose
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner == "kanto_gear" then compose = entry.callback end
  end
  local refresh = up(compose, "refreshBattle")
  local hgss = up(refresh, "hgssRuntime")
  local theme = up(display.drawContents, "THEME")
  local Battle = require("src.core.game3.battle")
  local State = require("src.core.game3.battle.state")
  local Ui = require("src.core.game3.battle.ui")
  local Schema = require("src.core.game3.save_schema_firered")
  local Party = require("src.core.game3.party")
  local Bag = require("src.core.game3.bag")
  local NativeBag = require("src.ui.game3.bag_menu")
  local Stack = require("src.ui.game3.stack")
  local Message = require("src.ui.game3.message")
  local Pokemon = require("src.core.game3.pokemon")
  local Catching = require("src.core.game3.battle.catching")
  local ModRuntime = require("src.mods.Runtime")
  local foes = Schema.newGame({ version = os.getenv("POKEPORT_VERSION"), rngSeed = 4080 })
  for _, dex in ipairs({ 130, 19, 16, 43, 41, 25 }) do Party.giveMon(foes, Pokemon.speciesFromNational(dex), 20) end
  local mon = game.session.party[1]
  mon.moves, mon.pp = { 85, 53, 89, 237 }, { 15, 15, 10, 15 }
  local api = up(display.saveHome, "mod")
  local options = run.loader.modOptions.kanto_gear
  options.info_level, options.ui_motion, options.battle_view = "enhanced", false, "gear"
  Stack.clear(); Message.reset()
  local st = State.new({ playerParty = game.session.party, foeParty = foes.party, wild = true })
  Battle._active, Battle._auto, Battle._phase, Battle._st = true, false, "command", st
  Ui.reset({ headless = true }); Ui.bindState(st, game.session); Ui.openMenu(0)
  local function sync() display.gen3.syncScreens(); refresh() end
  sync()
  local moves = hgss.battleMon().moves
  T.eq(moves[1].effectiveness, 40, "Electric has 4x base matchup against Water/Flying")
  T.eq(moves[2].effectiveness, 5, "Fire has 1/2 base matchup against Water/Flying")
  T.eq(moves[3].effectiveness, 0, "Ground has zero base matchup against Flying")
  T.eq(moves[4].effectiveness, nil, "variable-type move does not advertise its placeholder type matchup")
  api.options:set("type_hints", false)
  T.eq(hgss.battleMon().moves[1].effectiveness, nil, "Independent type helper can be disabled")
  api.options:set("type_hints", true)
  local Commands = require("src.core.game3.battle.commands")
  local actor, turn = st.player, st.turn
  local oldMove = mon.moves[4]
  mon.moves[4] = 45
  local attempts, submit = 0, api.battle.submit
  api.battle.submit = function(...) attempts=attempts+1; return submit(...) end
  local tap = up(up(up(compose,"touchEvent"),"tap"),"tapBattle")
  local function blocked(slot, label)
    Ui._mode="moves";sync()
    local source=up(refresh,"battle").moves[slot]
    local view=hgss.battleMon().moves[slot]
    T.check(view.disabled,label.." disables the displayed card")
    T.eq(source.disabledReason,display.gen3:plainText((Commands.selectionError(st,slot,0):gsub("\\[pl]"," "))),
      label.." uses the native reason")
    T.check(not source.disabledReason:find("\\[pl]"),label.." strips native page commands from the explanation")
    T.eq(view.disabledLabel,theme:translate(mon.pp[slot]==0 and "NO PP" or "DISABLED"),
      label.." has a short card status")
    T.check(#view.disabledLines>=1 and #view.disabledLines<=3,label.." details fit the status panel")
    local before=attempts
    local x=6+(slot-1)%2*116;local y=33+math.floor((slot-1)/2)*85
    tap((x+35)/1.5,(y+35)/1.5)
    T.eq(attempts,before,label.." cannot submit a move by touch")
    tap((x+104)/1.5,(y+11)/1.5)
    sync()
    T.eq(hgss.battleMon(up(display.syncCompanionDetails,"moveInfo")).moveIndex,slot,
      label.." details retain the inspected slot after a new native snapshot")
    T.check(pcall(display.drawContents),label.." renders")
    tap(10/1.5,10/1.5)
  end
  mon.pp[1]=0;blocked(1,"empty PP");mon.pp[1]=15
  actor.expDisabledMove=85;blocked(1,"Disable");actor.expDisabledMove=nil
  actor.expTauntedTurns=2;blocked(4,"Taunt");actor.expTauntedTurns=nil
  actor.torment,actor.lastMoveId=true,85;blocked(1,"Torment");actor.torment,actor.lastMoveId=nil,nil
  local oldFoeMove=st.enemy.mon.moves[1]
  st.enemy.expImprison,st.enemy.mon.moves[1]=true,85
  blocked(1,"Imprison");st.enemy.expImprison=nil;st.enemy.mon.moves[1]=oldFoeMove
  local oldItem=actor.item
  actor.item,actor.choicedMove=186,85;blocked(2,"Choice Band");actor.item,actor.choicedMove=oldItem,nil
  sync();T.check(not hgss.battleMon().moves[1].disabled,"cleared locks re-enable the card")
  T.eq(st.turn,turn,"availability reads never advance the battle")
  api.battle.submit=submit;mon.moves[4]=oldMove;Ui.openMenu(0)
  st.double, st.battlers = true, { [0] = st.player, [1] = st.enemy,
    [2] = State.makeBattler(game.session.party[2], "player", { id = 2, partyIndex = 2 }),
    [3] = State.makeBattler(foes.party[4], "enemy", { id = 3, partyIndex = 4 }) }
  local partner=st.battlers[2]
  local partnerMove=partner.mon.moves[1]
  partner.expDisabledMove=partnerMove;Ui.openMenu(2);Ui._mode="moves";sync()
  T.check(hgss.battleMon().moves[1].disabled,"doubles reads the active partner's lock")
  partner.expDisabledMove=nil;Ui.openMenu(0)
  sync()
  T.eq(hgss.battleMon().moves[1].effectiveness, nil, "double battle does not guess an unselected target")
  Ui._mode, Ui._target = "target", { cursor = 3 }
  sync()
  T.eq(hgss.battleMon().moves[1].effectiveness, 5, "double battle hint follows selected Grass/Poison target")
  st.double, Ui._target = false, nil
  st.wild = false; Ui.openMenu(0); sync()
  local _, team = hgss.battleTeams()
  T.eq(#team, 6, "trainer strip includes the whole native team")
  foes.party[2].hp, foes.party[5].hp = 0, 0
  sync(); _, team = hgss.battleTeams()
  T.check(not team[2].alive and not team[5].alive and team[6].alive, "trainer strip tracks fainted and remaining slots")
  T.eq(display.gen3:catchChance(4, st), nil, "trainer battle has no catch preview")
  st.wild = true; sync()
  local vanillaCatch = up(Catching.tryCatch, "vanilla_catch")
  for _, status in ipairs({ false, "SLP", "PAR" }) do
    st.enemy.status, st.enemy.mon.status = status or nil, status or nil
    for _, hp in ipairs({ st.enemy.mon.maxHp, 1 }) do
      st.enemy.mon.hp = hp
      for ball = 1, 12 do
        -- Find the native success threshold without using or advancing any RNG.
        local lo, hi = 0, 65536
        while lo < hi do
          local mid = math.floor((lo + hi) / 2)
          local caught = vanillaCatch(ball, st.enemy, st, game.session, function() return mid end)
          if caught then lo = mid + 1 else hi = mid end
        end
        local expected = 100 * (lo / 65536) ^ 4
        T.check(math.abs(display.gen3:catchChance(ball, st) - expected) < 1e-8,
          "ball " .. ball .. " preview agrees with native shake checks")
      end
    end
  end
  T.eq(st.battleResults, nil, "previews never record a catch attempt")
  local wantsHook = ModRuntime.wantsHook
  ModRuntime.wantsHook = function(name) return name == "catch.rate" or wantsHook(name) end
  T.eq(display.gen3:catchChance(4, st), nil, "custom catch hook hides unknown probability")
  ModRuntime.wantsHook = wantsHook
  st.noCatch = true
  T.eq(display.gen3:catchChance(1, st), nil, "uncatchable battles hide even Master Ball probability")
  st.noCatch = nil
  Bag.add(game.session.bag, 2, 2)
  for _, style in ipairs({ "hgss", "hgss_dark" }) do
    options.theme_v3 = style
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3" })
    for _, mode in ipairs({ "standard", "info", "gear", "full" }) do
      options.battle_view = mode
      NativeBag.show(game.session.bag, { session = game.session, battle = st, pocket = "POKE_BALLS" })
      NativeBag.settle(); sync()
      local menu = display.startMenu()
      T.check(menu and menu.items[1].catchChance > 0, "mirrored native bag carries catch probability")
      local model = display.startMenuModel(menu)
      T.check(model.entries[1].catchChance > 0, "ball presentation exposes the native catch probability")
      api.options:set("catch_odds", false)
      model = display.startMenuModel(menu)
      T.eq(model.entries[1].catchChance, nil, "Independent catch helper hides catch probability")
      api.options:set("catch_odds", true)
      T.check(pcall(display.drawContents), "native ball menu renders in every battle view")
      NativeBag.close(); Stack.clear()
    end
  end
  Message.reset(); Battle._active, Battle._st = false, nil; Ui.reset({ headless = true })
end
dofile(path .. "/tests/gen3_fixture.lua")
