-- Game path [Gen 2/3]: Shiny Hunt observes wild battles and hatches, reads
-- shininess the way each engine decides it (Gen 2 DVs or the host's own
-- flag, Gen 3 TID/SID/PID), and keeps its counters in playthrough storage
-- so a soft reset never rewinds a hunt. Read only: nothing here writes the
-- game, its save or its RNG. Gen 1 has no shiny Pokemon and hides the app.
return function(
  THEME, areaName, assist, battleState, compat, displayRuntime, drawSprite,
  guideData, header, mod, render, session
)
  local Hunt = displayRuntime.ShinyHunt
  local KEY = "shiny/state"
  local state = { data = Hunt.normalize(nil), page = 1, milestones = {} }
  displayRuntime.shinyHunt = state
  for _, share in ipairs(Hunt.MILESTONES) do
    state.milestones[#state.milestones + 1] = { share = share, need = Hunt.milestone(share) }
  end

  local function now() return os.time() end

  -- Gen 3 is known from the adapter before a save is loaded.
  function displayRuntime.shinyHuntSupported()
    if displayRuntime.gen3 then return true end
    return compat.isGen2() == true
  end

  function displayRuntime.applyShinyHuntSupport()
    local supported = displayRuntime.shinyHuntSupported()
    local entry = displayRuntime.storeById.shiny
    -- A new app: an unavailable one must not be promoted by the Store widget.
    if entry then entry.hidden, entry.available = not supported, supported end
    for _, id in ipairs({ "shiny_widget", "shiny_small_widget", "shiny_app" }) do
      local surface = displayRuntime.homeCatalog.surfaces[id]
      if surface then surface.hidden = not supported end
    end
  end

  ----------------------------------------------------------------------------
  -- Storage: independent of normal-save rollback (mod.storage), with the
  -- per-save bucket only as a fallback for hosts without durable storage.
  ----------------------------------------------------------------------------
  local function storageGame() return displayRuntime.sourceGame or session.game end

  function displayRuntime.bindShinyHunt()
    local game = storageGame()
    state.data, state.error, state.durable = Hunt.normalize(nil), nil, false
    state.view, state.page, state.pick, state.confirm = nil, 1, nil, nil
    state.pendingBattle, state.battleOpen, state.battleCounted, state.celebrate = nil, false, false, nil
    if not game then return end
    local storage = mod.storage
    if storage and type(storage.read) == "function" and type(storage.write) == "function" then
      state.durable = true
      local ok, value = pcall(storage.read, storage, game, KEY)
      if ok and type(value) == "table" then state.data = Hunt.normalize(value); return end
    end
    if mod.save and type(mod.save.get) == "function" then
      local ok, value = pcall(mod.save.get, mod.save, "shiny_hunt")
      if ok and type(value) == "table" then state.data = Hunt.normalize(value) end
    end
  end

  local function persist()
    local game, data = storageGame(), state.data
    if not game then return false end
    local written = false
    if state.durable then
      local ok, result = pcall(mod.storage.write, mod.storage, game, KEY, data)
      written = ok and result ~= nil and result ~= false
    end
    if not written and mod.save and type(mod.save.set) == "function" then
      local ok, result = pcall(mod.save.set, mod.save, "shiny_hunt", data)
      written = ok and result ~= false
    end
    state.error = not written and "HUNT NOT SAVED" or nil
    return written
  end
  displayRuntime.saveShinyHunt = persist

  local function changed()
    persist()
    if displayRuntime.home then displayRuntime.home.widgetCache = nil end
    if session.page == "SHINY" or session.page == "HOME" then session.dirty = true end
  end

  ----------------------------------------------------------------------------
  -- Reading a Pokemon: species, display name and shininess per engine.
  ----------------------------------------------------------------------------
  local function speciesName(species)
    local data = session.game and session.game.data
    local def = data and data.pokemon and data.pokemon[species]
    if def and def.name then return tostring(def.name) end
    if displayRuntime.gen3 and displayRuntime.gen3.Pokemon then
      local ok, name = pcall(displayRuntime.gen3.Pokemon.name, species)
      if ok and name then return tostring(name) end
    end
    return tostring(species or "?"):gsub("_", " ")
  end
  displayRuntime.shinySpeciesName = speciesName

  local function readMon(mon)
    if type(mon) ~= "table" then return nil end
    if displayRuntime.gen3 then
      -- The host's own readers: internal species, egg flag and TID/SID/PID
      -- shininess (which also honours shiny.roll mods).
      local P = displayRuntime.gen3.Pokemon
      local okSpecies, species = pcall(P.speciesOf, mon)
      local okEgg, egg = pcall(P.isEgg, mon)
      if not okSpecies or species == nil or species == 0 or okEgg and egg then return nil end
      local okShiny, shiny = pcall(P.isShiny, mon)
      return { species = species, name = speciesName(species), shiny = okShiny and shiny == true }
    end
    if mon.species == nil or compat.partyEgg(mon) then return nil end
    -- Gen 2 battle Pokemon carry the host's decision (it honours shiny.roll
    -- mods); stored records fall back to the native DV pattern.
    local shiny = mon.shiny == true or mon.shiny == nil and Hunt.gen2Shiny(mon.dvs)
    return { species = mon.species, name = speciesName(mon.species), shiny = shiny == true }
  end
  displayRuntime.shinyReadMon = readMon

  local function enemyMon(battle)
    if type(battle) ~= "table" then return nil end
    local source = battle.enemy or type(battle.battle) == "table" and battle.battle.enemy or nil
    if type(source) ~= "table" then return nil end
    return type(source.mon) == "table" and source.mon or source
  end

  local function record(event)
    if event.shiny and session.mapId then
      local ok, place = pcall(areaName, session.mapId)
      event.place = ok and type(place) == "string" and place or nil
    end
    local out = Hunt.observe(state.data, event, now())
    if out.shiny then
      state.celebrate = love and love.timer and love.timer.getTime() or 0
      mod.log:info("shiny %s met (%s)", tostring(event.species), out.shiny.kind)
      -- A shiny in battle chimes at once; its card follows when the screen is free.
      if displayRuntime.notify then
        local kind = out.shiny.kind
        displayRuntime.notify({ key = "shiny:" .. tostring(event.species), app = "shiny", page = "SHINY", area = "shiny",
          title = THEME:translate(kind == "target" and "SHINY FOUND!" or kind == "phase" and "SHINY PHASE!"
            or "LUCKY SHINY!"),
          detail = event.name or speciesName(event.species), species = event.species,
          tone = "special", urgent = true })
      end
      -- First shiny, first try, exactly 1 in 8192: kept in the Stamp Book.
      if displayRuntime.momentsFromShiny then displayRuntime.momentsFromShiny(out.shiny) end
    end
    changed()
    return out
  end

  local function observeWild(mon)
    if not displayRuntime.shinyHuntSupported() then return nil end
    -- A fight can be announced twice with detached records, and the host can
    -- reuse an enemy table next fight. Deduplicate by battle lifecycle.
    if state.battleCounted then return nil end
    local seen = readMon(mon)
    if not seen then return nil end
    state.battleCounted = true
    seen.via = "battle"
    return record(seen)
  end
  displayRuntime.shinyObserveWild = observeWild

  mod.events:on("battle.started", function(payload)
    if not displayRuntime.shinyHuntSupported() then return end
    if not payload or payload.kind ~= "wild" then return end
    if not state.battleOpen then state.battleOpen, state.battleCounted = true, false end
    if state.battleCounted then return end
    local mon = enemyMon(payload.battle)
    if mon and observeWild(mon) then state.pendingBattle = nil; return end
    state.pendingBattle = state.pendingBattle or { at = love.timer.getTime() }
  end)

  -- Fallback when the start payload had no enemy yet: the first battle
  -- snapshot that names one resolves the pending encounter.
  function displayRuntime.shinyObserveSnapshot(snapshot)
    local pending = state.pendingBattle
    if not pending then return end
    if not snapshot then
      if love.timer.getTime() - pending.at > 15 then state.pendingBattle = nil end
      return
    end
    local raw = battleState()
    local mon = enemyMon(raw) or snapshot.enemy and (snapshot.enemy.source or snapshot.enemy)
    if mon and observeWild(mon) then state.pendingBattle = nil end
  end

  mod.events:on("battle.ended", function(payload)
    if state.pendingBattle and payload then
      local mon = enemyMon(payload.battle)
      if mon then observeWild(mon) end
    end
    state.pendingBattle, state.battleOpen, state.battleCounted = nil, false, false
  end)

  -- Gen 2 eggs take Defense and Special from the parent of the other gender
  -- (always from Ditto): a shiny donor raises that egg to 1 in 64.
  local function gen2Boosted(hatchling)
    if displayRuntime.gen3 then return false end
    local save = storageGame() and storageGame().save
    local dc = save and type(save.dayCare) == "table" and save.dayCare or nil
    if not dc then return false end
    local man = type(dc.man) == "table" and dc.man.mon or nil
    local lady = type(dc.lady) == "table" and dc.lady.mon or nil
    local function shiny(mon)
      local seen = readMon(mon)
      return seen and seen.shiny or false
    end
    local function ditto(mon) return mon and tostring(mon.species):upper() == "DITTO" end
    if ditto(man) then return shiny(man) end
    if ditto(lady) then return shiny(lady) end
    local gender
    local ok, Breeding = pcall(require, "src.core.gen2.Breeding")
    if ok and type(Breeding) == "table" and Breeding.genderOf and hatchling then
      local okGender, value = pcall(Breeding.genderOf, session.game.data, hatchling)
      gender = okGender and tostring(value or ""):lower() or nil
    end
    if gender == "male" then return shiny(lady) end
    if gender == "female" then return shiny(man) end
    return false
  end

  -- What the Odds page says about the current Day-Care pair.
  function displayRuntime.shinyBreedingBoost()
    if displayRuntime.gen3 or not compat.isGen2() then return nil end
    local save = storageGame() and storageGame().save
    local dc = save and type(save.dayCare) == "table" and save.dayCare or nil
    if not dc then return nil end
    for _, side in ipairs({ "man", "lady" }) do
      local mon = type(dc[side]) == "table" and dc[side].mon or nil
      local seen = readMon(mon)
      if seen and seen.shiny then
        return { species = seen.species, name = seen.name, ditto = tostring(mon.species):upper() == "DITTO" }
      end
    end
  end

  mod.events:on("egg.hatched", function(payload)
    if not displayRuntime.shinyHuntSupported() or not payload then return end
    local slot = tonumber(payload.slot)
    local mon
    if displayRuntime.gen3 then
      local native = displayRuntime.gen3.session
      mon = slot and native and native.party and native.party[slot]
    else
      local game = storageGame()
      mon = slot and game and game.save and game.save.party and game.save.party[slot]
    end
    local seen = readMon(mon)
    if not seen then return end
    seen.via = "egg"
    seen.boosted = gen2Boosted(mon)
    record(seen)
  end)

  ----------------------------------------------------------------------------
  -- Screen model
  ----------------------------------------------------------------------------
  local function drawShiny(species, x, y, size, shiny, animate)
    if species == nil or species == Hunt.ANY then return false end
    return drawSprite(species, "front", x, y, size, size, nil,
      { species = species, shiny = shiny ~= false }, true, nil, animate == true)
  end
  displayRuntime.shinyDrawPokemon = drawShiny

  -- Where the target appears on this map right now, from the same encounter
  -- rows the Explorer lists (and the same Discovery switches).
  local function hereRows(species)
    if species == nil or species == Hunt.ANY or not assist("wild") then return nil end
    local ok, area = pcall(guideData)
    if not ok or type(area) ~= "table" then return nil end
    for _, row in ipairs(area.rows or {}) do
      if tostring(row.species) == tostring(species) then
        local methods = {}
        if assist("encounter_details") then
          for _, method in ipairs(row.currentMethods or {}) do
            methods[#methods + 1] = { name = method.name, chance = method.max or method.min }
          end
        end
        return { now = row.availability == "now", methods = methods, area = area.name }
      end
    end
    return { now = false, methods = {}, area = area.name }
  end

  function displayRuntime.shinyHuntModel()
    local view = Hunt.view(state.data)
    view.generation = displayRuntime.gen3 and 3 or compat.isGen2() and 2 or 1
    view.edition = displayRuntime.gen3 and displayRuntime.gen3.profile and displayRuntime.gen3.profile.id
    view.headline = Hunt.headline(view)
    view.drawPokemon = drawShiny
    view.group, view.percent, view.duration = Hunt.group, Hunt.percent, Hunt.duration
    view.milestones = state.milestones
    view.error = state.error
    view.celebrate = state.celebrate
    -- A lucky shiny met without a hunt stays on the idle widget for a day.
    local newest = view.log[1]
    if not view.hunt and newest and newest.kind == "lucky" and newest.at and now() - newest.at < 86400 then
      view.lucky = newest
    end
    if view.hunt then
      view.hunt.name = view.hunt.any and THEME:translate("ANY POKEMON")
        or view.hunt.name or speciesName(view.hunt.species)
    end
    if view.last then view.last.name = view.last.name or speciesName(view.last.species) end
    for _, entry in ipairs(view.log) do entry.name = entry.name or speciesName(entry.species) end
    for _, entry in ipairs(view.shelf) do
      entry.name = entry.any and THEME:translate("ANY POKEMON") or entry.name or speciesName(entry.species)
    end
    return view
  end

  -- Targets to pick from: anything, the last Pokemon met, this area's wild
  -- Pokemon and the party (gift and egg hunts).
  local function pickRows()
    local rows, seen = {}, {}
    local function add(row)
      local id = row.any and Hunt.ANY or tostring(row.species)
      if seen[id] then return end
      seen[id] = true
      local hunt = state.data.hunts[id]
      row.count = hunt and Hunt.count(hunt) or nil
      row.active = state.data.active == id
      rows[#rows + 1] = row
    end
    add({ any = true, species = Hunt.ANY, name = THEME:translate("ANY POKEMON"), section = "ANYTHING" })
    local last = state.data.last
    if last and last.species ~= nil then
      add({ species = last.species, name = last.name or speciesName(last.species), section = "LAST MET",
        note = last.via == "egg" and "EGG" or nil })
    end
    if assist("wild") then
      local ok, area = pcall(guideData)
      if ok and type(area) == "table" then
        for _, row in ipairs(area.rows or {}) do
          if row.availability == "now" or row.availability == "time" then
            local method = assist("encounter_details") and row.currentMethods and row.currentMethods[1] or nil
            add({ species = row.species, name = row.name or speciesName(row.species), section = "THIS AREA",
              method = method and method.name, chance = method and (method.max or method.min),
              later = row.availability ~= "now" })
          end
        end
      end
    end
    for _, mon in ipairs(session.game and session.game.save and session.game.save.party or {}) do
      if not compat.partyEgg(mon) and mon.species ~= nil then
        add({ species = mon.species, name = speciesName(mon.species), section = "YOUR PARTY" })
      end
    end
    return rows
  end

  function displayRuntime.shinyPickModel()
    if not state.pick then state.pick = { rows = pickRows(), page = 1 } end
    return state.pick
  end

  local function hereFor(view)
    if not view.hunt or view.hunt.any or view.hunt.found then return nil end
    local cache = state.here
    local stamp = math.floor(love.timer.getTime() / 30)
    if cache and cache.species == view.hunt.species and cache.map == session.mapId and cache.stamp == stamp then
      return cache.value
    end
    local value = hereRows(view.hunt.species)
    state.here = { species = view.hunt.species, map = session.mapId, stamp = stamp, value = value }
    return value
  end

  function displayRuntime.drawShinyHunt()
    local view = displayRuntime.shinyHuntModel()
    view.view = state.view
    view.confirm = state.confirm
    view.page = state.page
    if state.view == "pick" then
      view.pick = displayRuntime.shinyPickModel()
    elseif state.view == "odds" then
      view.here = hereFor(view)
      view.boost = displayRuntime.shinyBreedingBoost()
    elseif state.view == nil then
      view.here = hereFor(view)
    end
    header(THEME:translate(state.view == "pick" and "PICK A TARGET" or "SHINY HUNT"), true, false)
    render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    THEME.hgss:shinyHunt(view)
    render.G.pop()
  end

  local function setTarget(row)
    if not row then return false end
    Hunt.setTarget(state.data, row.any and Hunt.ANY or row.species, not row.any and row.name or nil, now())
    state.view, state.pick, state.confirm, state.here = nil, nil, nil, nil
    changed()
    return true
  end

  function displayRuntime.shinyHuntAction(action, value)
    local data = state.data
    if action == "view" then
      state.view = value ~= "hunt" and value or nil
      state.page, state.confirm = 1, nil
      if state.view == "pick" then state.pick = nil end
    elseif action == "pick" then
      state.view, state.pick, state.confirm = "pick", nil, nil
    elseif action == "target" then
      local pick = state.pick
      return setTarget(pick and pick.rows[value])
    elseif action == "resume" then
      local hunt = data.hunts[value]
      if not hunt then return false end
      data.active = value
      state.view, state.here = nil, nil
      changed()
      return true
    elseif action == "plus" or action == "minus" then
      if not Hunt.adjust(data, action == "plus" and 1 or -1, now()) then return false end
      changed()
      return true
    elseif action == "auto" then
      Hunt.setAuto(data, data.auto == false)
      changed()
      return true
    elseif action == "again" then
      if not Hunt.restart(data, now()) then return false end
      state.celebrate = nil
      changed()
      return true
    elseif action == "forget" then
      -- Two taps: the first arms, the second removes the shelved counter.
      if state.confirm ~= value then state.confirm = value; session.dirty = true; return true end
      state.confirm = nil
      Hunt.remove(data, value)
      changed()
      return true
    elseif action == "page" then
      if state.view == "pick" and state.pick then
        state.pick.page = math.max(1, (state.pick.page or 1) + value)
      else
        state.page = math.max(1, (state.page or 1) + value)
      end
    else
      return false
    end
    session.dirty = true
    return true
  end

  function displayRuntime.tapShinyHunt(x, y)
    if y < 30 and x < 35 then
      if state.view == "pick" then state.view, state.pick = nil, nil
      else session.page, displayRuntime.home.activeApp = "HOME", nil end
      state.confirm, session.dirty = nil, true
      return
    end
    local action, value = THEME.hgss:shinyHuntHit(x, y)
    if not action then
      if state.confirm then state.confirm, session.dirty = nil, true end
      return
    end
    if action ~= "forget" then state.confirm = nil end
    if displayRuntime.shinyHuntAction(action, value) then
      displayRuntime.haptic(action == "plus" and "confirm" or nil)
    end
    session.dirty = true
  end

  function displayRuntime.openShinyHunt()
    state.view, state.pick, state.confirm, state.page, state.here = nil, nil, nil, 1, nil
    if not Hunt.active(state.data) then state.view = "pick" end
  end
end
