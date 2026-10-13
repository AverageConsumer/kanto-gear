-- Actual native commands and Pokeblock Case input/consumption, through common touch pages.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local a = display.gen3
  local Battle, U = a.Battle, a.BattleUI
  local Stack, Message = require("src.ui.game3.stack"), require("src.ui.game3.message")
  local compose
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
    if entry.owner == "kanto_gear" then compose = entry.callback end
  end
  local refresh = up(compose, "refreshBattle")
  local tap = up(up(up(compose, "touchEvent"), "tap"), "tapBattle")
  local H = up(display.drawContents, "THEME").hgss
  local session = game.session
  local state = require("src.core.game3.battle.state").new({ playerParty = session.party,
    foeParty = session.party, wild = true, session = session })
  state.session, state.safari, state.safariState = session, true, { balls = 23 }
  Battle._active, Battle._st, Battle._phase = true, state, "command"
  local ids = a.hoenn and { "ball", "pokeblock", "go_near", "run" }
    or { "ball", "bait", "rock", "run" }
  for _, style in ipairs({ "hgss", "hgss_dark" }) do
    run.loader.modOptions.kanto_gear.theme_v3 = style
    run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = style })
    for _, mode in ipairs({ "standard", "gear", "full" }) do
      run.loader.modOptions.kanto_gear.battle_view = mode
      for index, id in ipairs(ids) do
        Message.reset(); Stack.clear(); U.reset({ headless = true }); U.bindState(state, session); U.openMenu(0)
        a.syncScreens(); refresh()
        local snapshot = up(refresh, "battle")
        local model = display.SafariPage.model(snapshot)
        T.eq(snapshot.prompt, "safari", "native Safari owns this command page")
        T.eq(display.SafariPage.action(model, index), id, "normalized action matches the edition")
        if a.hoenn then
          T.eq(model.actions[2].label, "POKéBLOCK", "Emerald shows its actual Pokeblock command")
          T.eq(model.actions[3].label, "GO NEAR", "Emerald shows its actual approach command")
        end
        local renderer = mode == "full" and "battleFullSafari" or "battleSafari"
        local captured, draw = nil, H[renderer]
        H[renderer] = function(self, value, ...) captured = value; return draw(self, value, ...) end
        display.drawContents(); H[renderer] = draw
        T.eq(captured.actions[index].kind, id, "rendering and touch use the same shared model")
        local x, y, w, h = display.SafariPage.rect(index)
        if mode == "full" then
          local r=H.fullBattleActions[index]; x,y,w,h=r.x,r.y,r.w,r.h
        end
        tap((x + w / 2) / 1.5, (y + h / 2) / 1.5)
        local command = U._pendingCommand
        T.check(command and (id == "run" and command.safariRun
          or command.kind == "safari" and command.action == id), "touch submits actual native " .. id)
      end
    end
  end
  if a.hoenn then
    local Blocks = require("src.core.game3.rse.pokeblock")
    local Case = require("src.ui.game3.rse.pokeblock_case")
    local before = session.pokeblocks
    local queued, callbacks, result = nil, 0, nil
    local api = up(display.saveHome, "mod")
    local oldTap = api.input.tap
    api.input.tap = function(_, target, key) T.eq(target, game, "case input targets the real game"); queued = key end
    local function tick(key)
      Case.handleInput({ wasPressed = function(_, k) return k == key end, isDown = function() return false end })
      Case.update()
    end
    local function settle() for _ = 1, 12 do tick() end; a.syncScreens(); refresh() end
    local function click(view, index)
      local model = display.StartMenu.model(view)
      local entry
      for _, row in ipairs(model.entries) do if row.label == view.items[index].label then entry = row end end
      assert(entry, "touch row is visible")
      queued = nil; display.tapStartMenu(view, (entry.x + entry.w / 2) / 1.5, (entry.y + entry.h / 2) / 1.5)
      if queued then tick(queued) end
    end
    for _, style in ipairs({ "hgss", "hgss_dark" }) do
      run.loader.modOptions.kanto_gear.theme_v3 = style
      run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = style })
      for _, cancel in ipairs({ true, false }) do
        Stack.clear(); Message.reset(); U.reset({ headless = true })
        Battle._phase = "safari_pokeblock"
        Blocks.clearAll(session)
        for i = 1, 12 do Blocks.add(session, { color = i, spicy = i + 10, feel = 20 }) end
        Blocks.chooseForBattle(session, function(value) callbacks = callbacks + 1; result = value end)
        local locked = assert(display.startMenu())
        T.eq(display.StartMenu.cursor(locked), nil, "native entry fade blocks touch")
        settle()
        local list = assert(display.startMenu())
        T.eq(list.title, "POKéBLOCK CASE", "case title uses Emerald's real item ID")
        T.eq(#list.items, 13, "all native blocks and the real stow action are available")
        T.eq(list.items[1].label, a:plainText(Blocks.name(Blocks.get(session, 0))), "block names come from the game")
        T.eq(list.items[1].right, a.rs and "11" or "Lv11", "block levels come from native flavor data")
        T.check(pcall(display.drawContents), "native block list renders")
        T.check(display.StartMenu.select(list, 10), "common paging can select later native blocks")
        T.eq(Case.saved.scroll + Case.saved.row, 9, "later touch row updates the actual native scrolled cursor")
        T.eq(Case._st.feel, 20, "native flavor/feel display is updated through normal cursor input")
        click(list, 10)
        local actions = assert(display.startMenu())
        T.check(not list.valid(), "old block list cannot activate an action in the next page")
        T.eq(#actions.items, 2, "battle case uses the native Use/Cancel menu")
        T.check(pcall(display.drawContents), "block actions use the common choice page")
        click(actions, cancel and 2 or 1)
        if cancel then
          T.eq(Blocks.count(session), 12, "cancelled block action preserves every block")
          local reopened = assert(display.startMenu())
          queued = nil; display.tapStartMenu(reopened, 12 / 1.5, 12 / 1.5)
          T.eq(queued, "b", "common back closes the native case")
          tick(queued)
        else
          T.eq(Blocks.count(session), 11, "native Use consumes exactly the selected block")
          T.eq(result, nil, "native fade completes before the battle callback")
        end
        T.check(not actions.valid(), "completed action cannot be submitted twice")
        settle()
        T.check(not Case.open, "native case closes after its own fade")
        if cancel then T.eq(result, nil, "native cancellation returns no block")
        else T.eq(result.color, 10, "native callback carries the exact chosen block") end
        result = nil
      end
    end
    T.eq(callbacks, 4, "each native case returns to the battle exactly once")
    local headless, auto = Battle._headless, Battle._auto
    Battle._headless, Battle._auto = true, false
    require("src.ui.game3.party_menu").close()
    require("src.ui.game3.bag_menu").close()
    Blocks.clearAll(session)
    U.reset({ headless = true }); U.bindState(state, session); U.openMenu(0)
    Battle._phase = "command"; a.syncScreens(); refresh()
    local r=H.fullBattleActions[2]
    local x,y,w,h=r.x,r.y,r.w,r.h
    tap((x + w / 2) / 1.5, (y + h / 2) / 1.5)
    Battle.update(1 / 60, {})
    T.eq(Battle._phase, "safari_pokeblock", "actual battle dispatcher opens the native case")
    T.check(Case.open, "native Safari command reaches a live case")
    settle()
    local empty = assert(display.startMenu())
    T.eq(#empty.items, 1, "an empty case offers only the actual Stow option")
    click(empty, 1); settle()
    T.eq(Battle._phase, "command", "native case cancellation returns to the same Safari turn")
    T.eq(U._mode, "menu", "native cancellation restores the real Safari command menu")
    T.eq(Blocks.count(session), 0, "opening and closing an empty case cannot create blocks")
    Battle._headless, Battle._auto = headless, auto
    api.input.tap, session.pokeblocks = oldTap, before
    Case.reset()
  end
  Battle._active, Battle._st = false, nil
  U.reset({ headless = true }); Stack.clear(); Message.reset(); a.syncScreens(); refresh()
end
dofile(path .. "/tests/gen3_fixture.lua")
