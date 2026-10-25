-- Moments: the Stamp Book's third tab. Watches battles, catches and shinies
-- for small stories worth remembering, keeps them per playthrough in mod
-- storage (a soft reset never takes one back) and announces each new one
-- with a Gear notice. Read only: nothing here writes the game or its save.
return function(THEME, areaName, compat, displayRuntime, mod, render, session)
  local Moments = displayRuntime.Moments
  local KEY = "moments/state"
  local state = { data = Moments.normalize(nil), page = 1 }
  displayRuntime.moments = state

  local function now() return os.time() end
  local function clock() return love.timer.getTime() end
  local function storageGame() return displayRuntime.sourceGame or session.game end
  local function shinyGame()
    return displayRuntime.shinyHuntSupported and displayRuntime.shinyHuntSupported() or false
  end
  local function family()
    local generation = displayRuntime.gen3 and 3 or compat.isGen2() and 2 or 1
    local ok, edition = pcall(function() return require("src.core.GameVersion").get() end)
    return Moments.family(generation, ok and edition or nil)
  end
  local function speciesName(species)
    if species == nil then return nil end
    if displayRuntime.shinySpeciesName then return displayRuntime.shinySpeciesName(species) end
    return tostring(species)
  end

  ----------------------------------------------------------------------------
  -- Storage
  ----------------------------------------------------------------------------
  local function persist()
    local game = storageGame()
    if not game then return false end
    local written = false
    if state.durable then
      local ok, result = pcall(mod.storage.write, mod.storage, game, KEY, state.data)
      written = ok and result ~= nil and result ~= false
    end
    if not written and mod.save and type(mod.save.set) == "function" then
      local ok, result = pcall(mod.save.set, mod.save, "moments", state.data)
      written = ok and result ~= false
    end
    return written
  end
  displayRuntime.saveMoments = persist

  local function place()
    if not session.mapId then return nil end
    local ok, name = pcall(areaName, session.mapId)
    return ok and type(name) == "string" and name ~= "" and name or nil
  end

  local function playSeconds()
    local game = storageGame()
    local ok, value = pcall(compat.playSeconds, game and game.save)
    return ok and tonumber(value) or nil
  end

  ----------------------------------------------------------------------------
  -- Announcing
  ----------------------------------------------------------------------------
  local function openMoments(id)
    return function()
      local view = displayRuntime.achievements
      if not view then return end
      if id and Moments.has(state.data, id) then
        view.view, view.moment = "moment", id
      else
        view.view, view.moment = "moments", nil
      end
      state.page = 1
      session.dirty = true
    end
  end

  local function sealIcon(glyph, tone)
    return function(x, y, size)
      THEME.hgss:momentSeal(x + math.floor(size / 2), y + math.floor(size / 2), math.floor(size / 2) - 1, glyph, tone)
    end
  end

  local function announce(record)
    if not displayRuntime.notify then return end
    local entry = Moments.byId[record.id]
    displayRuntime.notify({ key = "moment:" .. record.id, app = "achievements", page = "ACHIEVEMENTS", area = "moments",
      title = THEME:translate("NEW MOMENT"), detail = THEME:translate(entry.title),
      drawIcon = sealIcon(entry.glyph, entry.tone), tone = "special", onOpen = openMoments(record.id) })
  end

  local function announceMany(count)
    if not displayRuntime.notify or count <= 0 then return end
    displayRuntime.notify({ key = "moments:retro", app = "achievements", page = "ACHIEVEMENTS", area = "moments",
      title = THEME:translate("NEW MOMENTS"), detail = THEME:translate("FROM YOUR JOURNEY SO FAR"),
      drawIcon = sealIcon("star", "gold"), tone = "special", onOpen = openMoments(nil) })
  end

  -- found = { { id, species, name, shiny, foe }, ... }
  local function award(found, quiet)
    local fresh = {}
    for _, info in ipairs(found or {}) do
      local entry = Moments.byId[info.id]
      if entry and Moments.available(entry, shinyGame(), family()) then
        info.name = info.name or speciesName(info.species)
        if not info.retro then
          info.place = info.place or place()
          info.play = info.play or playSeconds()
        end
        local record = Moments.award(state.data, info.id, info, now())
        if record then fresh[#fresh + 1] = record end
      end
    end
    if #fresh == 0 then return fresh end
    state.unseen = true
    persist()
    for _, record in ipairs(fresh) do
      mod.log:info("moment %s", record.id)
      if not quiet then announce(record) end
    end
    if displayRuntime.home then displayRuntime.home.widgetCache = nil end
    session.dirty = true
    return fresh
  end
  displayRuntime.awardMoments = award

  ----------------------------------------------------------------------------
  -- Binding: load, then award what the playthrough already proves.
  ----------------------------------------------------------------------------
  local function retro()
    if state.data.retro then return end
    state.data.retro = true
    local found = {}
    local shiny = displayRuntime.shinyHunt and displayRuntime.shinyHunt.data
    if shinyGame() and shiny then
      for _, hit in ipairs(Moments.retroShiny(shiny.log)) do
        local e = hit.entry
        found[#found + 1] = { id = hit.id, species = e.species, name = e.name, shiny = true,
          place = e.place, at = e.at, retro = true }
      end
    end
    local fresh = award(found, true)
    if #fresh == 1 then announce(fresh[1])
    elseif #fresh > 1 then announceMany(#fresh) end
    if #fresh == 0 then persist() end
  end

  function displayRuntime.bindMoments()
    local game = storageGame()
    state.data, state.durable, state.fight, state.page, state.unseen = Moments.normalize(nil), false, nil, 1, nil
    state.endedAt, state.roamer = nil, nil
    if not game then return end
    local loaded = false
    local storage = mod.storage
    if storage and type(storage.read) == "function" and type(storage.write) == "function" then
      state.durable = true
      local ok, value = pcall(storage.read, storage, game, KEY)
      if ok and type(value) == "table" then state.data, loaded = Moments.normalize(value), true end
    end
    if not loaded and mod.save and type(mod.save.get) == "function" then
      local ok, value = pcall(mod.save.get, mod.save, "moments")
      if ok and type(value) == "table" then state.data = Moments.normalize(value) end
    end
    retro()
  end

  -- From Shiny Hunt, the moment a shiny is met.
  function displayRuntime.momentsFromShiny(entry)
    if type(entry) ~= "table" then return end
    local found = {}
    local first = not Moments.has(state.data, "first_shiny")
    for _, id in ipairs(Moments.fromShiny(entry, first)) do
      found[#found + 1] = { id = id, species = entry.species, name = entry.name, shiny = true, place = entry.place }
    end
    award(found)
  end

  ----------------------------------------------------------------------------
  -- Battles
  ----------------------------------------------------------------------------
  local function snapshot()
    if not mod.battle or type(mod.battle.snapshot) ~= "function" then return nil end
    local ok, snap = pcall(mod.battle.snapshot, mod.battle)
    if not ok then return nil end
    if displayRuntime.gen3 and snap then
      local okGen3, value = pcall(displayRuntime.gen3.battleSnapshot, displayRuntime.gen3, snap)
      if okGen3 and value then snap = value end
    end
    return type(snap) == "table" and snap or nil
  end

  local function trainerOf(battle)
    if type(battle) ~= "table" then return nil end
    local trainer = battle.trainer
    if type(trainer) ~= "table" and type(battle.battle) == "table" then trainer = battle.battle.trainer end
    return type(trainer) == "table" and trainer or nil
  end

  local function startFight(payload)
    payload = payload or {}
    local kind = payload.kind == "trainer" and "trainer" or payload.kind == "wild" and "wild" or payload.kind
    local trainer = trainerOf(payload.battle)
    local foeName = trainer and type(trainer.name) == "string" and trainer.name or nil
    local member = trainer and (trainer.memberId or trainer.id)
    local class = payload.trainerClass or trainer and (trainer.classId or trainer.class) or payload.trainerId
    local id = member and (tostring(class or "?") .. ":" .. tostring(member)) or payload.trainerId
    -- Gen 2's trainerId is a class, not a trainer. A member ID is required
    -- before a loss can prove a later rematch with that same person.
    if not displayRuntime.gen3 and compat.isGen2() and member == nil then id = nil end
    local key
    if kind == "trainer" and id ~= nil then
      key = table.concat({ tostring(session.mapId or "?"), tostring(id or "?"), tostring(foeName or "?") }, ":")
    end
    local fight = state.fight
    -- Gen 2 raises battle.started from both its engine and its screen.
    if fight and not fight.done and clock() - (fight.startedAt or 0) < 1.5 then
      fight.trainer = fight.trainer or key
      fight.foe = fight.foe or foeName
      if fight.kind == "wild" and kind ~= "wild" then fight.kind = kind end
      return fight
    end
    -- A roaming Pokemon announces itself just before its battle starts.
    local roamer = state.roamer and clock() - state.roamer.at < 10 or nil
    state.roamer = nil
    fight = Moments.newFight({ kind = kind or "wild", trainer = key, foe = foeName,
      species = kind ~= "trainer" and payload.species or nil, roamer = roamer })
    fight.startedAt = clock()
    if kind ~= "trainer" and payload.species ~= nil then fight.foe = speciesName(payload.species) end
    state.fight = fight
    return fight
  end

  local function enemyMon(battle)
    if type(battle) ~= "table" then return nil end
    local source = battle.enemy or type(battle.battle) == "table" and battle.battle.enemy or nil
    if type(source) ~= "table" then return nil end
    return type(source.mon) == "table" and source.mon or source
  end

  mod.events:on("battle.started", function(payload)
    if not session.active then return end
    local fight = startFight(payload)
    payload = payload or {}
    -- Game packs met at the start of a battle.
    if payload.kind == "ghost" then award({ { id = "tower_ghost" } }) end
    if payload.kind == "wild" and not displayRuntime.gen3 and compat.isGen2() then
      local mon = enemyMon(payload.battle)
      local seen = mon and displayRuntime.shinyReadMon and displayRuntime.shinyReadMon(mon)
      if seen and seen.shiny and Moments.is(seen.species, "GYARADOS") then
        award({ { id = "red_gyarados", species = seen.species, name = seen.name, shiny = true } })
      end
    end
    return fight
  end)

  mod.events:on("roamer.encountered", function(payload)
    state.roamer = { at = clock(), species = payload and payload.species }
  end)

  mod.events:on("pokemon.evolved", function(payload)
    if type(payload) ~= "table" then return end
    local function partyHas(species)
      local party
      if displayRuntime.gen3 then
        party = displayRuntime.gen3.session and displayRuntime.gen3.session.party
      else
        local game = storageGame()
        party = game and game.save and game.save.party
      end
      for _, mon in ipairs(type(party) == "table" and party or {}) do
        local seen = displayRuntime.shinyReadMon and displayRuntime.shinyReadMon(mon)
        if seen and (Moments.is(seen.species, species) or Moments.is(seen.name, species)) then return true end
      end
      return false
    end
    local found = Moments.evolved(payload.fromSpecies, payload.toSpecies, partyHas)
    local mon = payload.mon
    local name = type(mon) == "table" and type(mon.nickname) == "string" and mon.nickname ~= "" and mon.nickname or nil
    for _, row in ipairs(found) do
      if row.id == "gyarados_rise" then row.name = name end
    end
    award(found)
  end)

  mod.events:on("egg.hatched", function(payload)
    if type(payload) ~= "table" then return end
    award({ { id = "first_hatch", species = payload.species,
      name = type(payload.nickname) == "string" and payload.nickname or nil } })
  end)

  mod.events:on("pokerus.infected", function(payload)
    if type(payload) ~= "table" or not Moments.pokerus(payload.source) then return end
    local seen = displayRuntime.shinyReadMon and displayRuntime.shinyReadMon(payload.mon)
    award({ { id = "pokerus", species = seen and seen.species, name = seen and seen.name } })
  end)

  mod.events:on("bug_contest.scored", function(payload)
    if type(payload) ~= "table" or payload.place ~= 1 then return end
    local seen = displayRuntime.shinyReadMon and displayRuntime.shinyReadMon(payload.mon)
    award({ { id = "bug_champion", species = seen and seen.species, name = seen and seen.name,
      shiny = seen and seen.shiny or nil } })
  end)

  mod.events:on("unown.unlocked", function(payload)
    if type(payload) ~= "table" or (tonumber(payload.count) or 0) < 26 then return end
    award({ { id = "unown_alphabet", species = "UNOWN" } })
  end)

  mod.events:on("battle.turn_started", function()
    local fight = state.fight
    if fight and not fight.done then fight.eventTurns = (fight.eventTurns or 0) + 1 end
  end)

  mod.events:on("battle.ball_thrown", function()
    local fight = state.fight
    if fight and not fight.done then Moments.fightThrow(fight) end
  end)

  mod.events:on("pokemon.caught", function(payload)
    local fight = state.fight
    if not fight or fight.done or type(payload) ~= "table" then return end
    if fight.caught then return end
    fight.caught = true
    local snap = snapshot()
    local left
    if snap then
      Moments.fightSnapshot(fight, snap)
      left = fight.balls
    end
    local species = payload.species
    local seen = displayRuntime.shinyReadMon and displayRuntime.shinyReadMon(payload.mon) or nil
    award(Moments.caught(fight, { species = species, name = speciesName(species),
      shiny = seen and seen.shiny or nil, ballsLeft = left }))
  end)

  mod.events:on("battle.ended", function(payload)
    local fight = state.fight
    if not fight or fight.done then return end
    fight.done = true
    state.fight, state.endedAt = nil, clock()
    local snap = snapshot()
    if snap then Moments.fightSnapshot(fight, snap) end
    -- Snapshot turns first; the event count only when the engine reports none.
    if fight.turns == 0 then fight.turns = fight.eventTurns or 0 end
    local found = Moments.fightEnd(state.data, fight, payload and payload.result)
    if #found == 0 then persist(); return end
    award(found)
  end)

  -- Every refreshed battle snapshot (frame.lua).
  function displayRuntime.momentsObserveSnapshot(snap)
    if not snap then return end
    local fight = state.fight
    if not fight then
      -- Loaded mid-battle: follow it from here. The screen of a battle that
      -- just ended is not a new one.
      if state.endedAt and clock() - state.endedAt < 30 then return end
      fight = startFight({ kind = snap.kind })
    end
    Moments.fightSnapshot(fight, snap)
  end

  ----------------------------------------------------------------------------
  -- The Moments tab inside the Stamp Book
  ----------------------------------------------------------------------------
  local PER_PAGE = 3

  local function dateText(at)
    if not at or at <= 0 then return nil end
    local t = os.date("*t", at)
    if not t then return nil end
    local month = THEME:translate(({ "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT",
      "NOV", "DEC" })[t.month])
    local pattern = THEME:translate("DD MON YYYY")
    local out = pattern:gsub("YYYY", tostring(t.year)):gsub("MON", month)
      :gsub("MM", tostring(t.month)):gsub("DD", tostring(t.day))
    return out
  end

  local function playText(seconds)
    if not seconds then return nil end
    seconds = math.max(0, math.floor(seconds))
    return THEME:format("%d:%02d", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
  end

  local function present(record)
    local entry = Moments.byId[record.id]
    return { id = record.id, title = THEME:translate(entry.title), line = THEME:translate(entry.line),
      glyph = entry.glyph, tone = entry.tone, species = record.species, shiny = record.shiny == true,
      name = record.name or speciesName(record.species), place = record.place, foe = record.foe,
      date = dateText(record.at), play = playText(record.play) }
  end

  function displayRuntime.momentsModel(view)
    local list = Moments.list(state.data)
    local pages = math.max(1, math.ceil(#list / PER_PAGE))
    state.page = math.max(1, math.min(state.page or 1, pages))
    local shown = {}
    for index = (state.page - 1) * PER_PAGE + 1, math.min(#list, state.page * PER_PAGE) do
      shown[#shown + 1] = present(list[index])
    end
    local model = { view = view, page = state.page, pages = pages, moments = shown,
      area = { name = THEME:translate("MOMENTS") }, momentsUnseen = state.unseen,
      drawPokemon = displayRuntime.shinyDrawPokemon }
    if view == "moment" then
      local selected = displayRuntime.achievements.moment
      local record = selected and Moments.has(state.data, selected)
      if not record then
        displayRuntime.achievements.view, model.view = "moments", "moments"
      else model.moment = present(record) end
    end
    if model.view == "moments" then state.unseen = nil end
    return model
  end

  local baseModel = displayRuntime.achievementModel
  function displayRuntime.achievementModel()
    local view = displayRuntime.achievements and displayRuntime.achievements.view
    if view == "moments" or view == "moment" then return displayRuntime.momentsModel(view) end
    local model = baseModel()
    model.momentsUnseen = state.unseen
    return model
  end

  local baseCycle = displayRuntime.cycleAchievements
  function displayRuntime.cycleAchievements(direction)
    local view = displayRuntime.achievements.view
    if view == "moment" then return end
    if view ~= "moments" then return baseCycle(direction) end
    local pages = math.max(1, math.ceil(#state.data.earned / PER_PAGE))
    if pages <= 1 then return end
    displayRuntime.requestPageMotion(direction)
    state.page = ((state.page or 1) - 1 + direction) % pages + 1
    session.dirty = true
  end

  -- Swipes along the tab row walk Goals, Stamp Book and Moments.
  local TABS = { "goals", "album", "moments" }
  function displayRuntime.cycleAchievementTabs(direction)
    local view = displayRuntime.achievements
    for index, id in ipairs(TABS) do
      if id == view.view then
        local nextIndex = math.max(1, math.min(#TABS, index + direction))
        if nextIndex == index then return false end
        view.view, view.page, view.selected = TABS[nextIndex], 1, nil
        if TABS[nextIndex] == "moments" then state.page = 1 end
        displayRuntime.requestPageMotion(direction)
        session.dirty = true
        return true
      end
    end
    return false
  end

  local baseTap = displayRuntime.tapAchievements
  function displayRuntime.tapAchievements(x, y)
    local view = displayRuntime.achievements
    if view.view == "moment" and y < 30 and x < 35 then
      view.view, view.moment = "moments", nil
      session.dirty = true
      return
    end
    if view.view == "moments" or view.view == "moment" then
      local action, value = THEME.hgss:achievementsHit(x, y)
      if action == "moment" then
        view.view, view.moment = "moment", value
        session.dirty = true
        return
      elseif action == "moment_page" then
        displayRuntime.cycleAchievements(value)
        return
      elseif action == "view" then
        view.view, view.page, view.selected, view.moment = value, 1, nil, nil
        if value == "moments" then state.page = 1 end
        session.dirty = true
        return
      end
      if y >= 30 or x >= 35 then return end
    end
    local action, value = THEME.hgss:achievementsHit(x, y)
    if action == "view" and value == "moments" and (y >= 30 or x >= 35) then
      view.view, view.page, view.selected, view.moment = "moments", 1, nil, nil
      state.page = 1
      session.dirty = true
      return
    end
    return baseTap(x, y)
  end
end
