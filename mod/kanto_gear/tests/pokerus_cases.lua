return function(T, display, summaryView, game, generation)
  local S = assert(loadfile(os.getenv("KANTO_GEAR_MOD_PATH") .. "/models/summary.lua"))()
  local raw = generation == 3 and game.session.party[1] or game.save.party[1]
  local old = { pokerus = raw.pokerus, hp = raw.hp, status = raw.status, isEgg = raw.isEgg }
  local function mon() return generation == 3 and display.gen3:mon(raw) or raw end
  local function state() return S.inspection(mon(), generation == 3 and display.gen3:gameView() or game, generation) end
  for _, case in ipairs({ { 0 }, { 1, "active" }, { 0x34, "active" }, { 0x30, "cured" }, { 0xF0, "cured" } }) do
    raw.pokerus, raw.hp, raw.status, raw.isEgg = case[1], 10, generation == 3 and 8 or "PSN", false
    local expected = generation > 1 and case[2] or nil
    T.eq(display.partyView(mon()).pokerus, expected, "party shows active/cured Pokérus only in Gen 2/3")
    local page = state()
    T.eq(summaryView(page).pokerus, expected, "summary retains the same independent Pokérus marker")
    T.eq(summaryView(page).statusId, "PSN", "summary retains a simultaneous ailment")
    T.eq(display.partyView(mon()).statusId, "PSN", "Pokérus does not hide a simultaneous ailment")
    T.eq(raw.pokerus, case[1], "inspecting Pokérus never changes the native byte")
    local key = S.redrawKey(page)
    raw.pokerus = case[1] == 0x30 and 0x34 or 0x30
    mon()
    T.check(S.redrawKey(page) ~= key, "Pokérus changes invalidate a retained summary")
  end
  raw.pokerus, raw.hp, raw.status = 0x34, 0, generation == 3 and 0 or nil
  T.eq(display.partyView(mon()).statusId, "FNT", "a fainted carrier retains the fainted indicator")
  T.eq(display.partyView(mon()).pokerus, generation > 1 and "active" or nil, "fainting does not hide Pokérus")
  raw.hp = 10
  T.eq(display.partyView(mon()).statusId, nil, "Pokérus alone is not a battle ailment")
  T.eq(summaryView(state()).statusId, nil, "summary does not treat Pokérus as a battle ailment")
  raw.isEgg = true
  T.eq(display.partyView(mon()).pokerus, nil, "eggs never display Pokérus")
  T.eq(summaryView(state()).pokerus, nil, "egg summaries never display Pokérus")
  raw.pokerus, raw.hp, raw.status, raw.isEgg = old.pokerus, old.hp, old.status, old.isEgg
  mon()
end
