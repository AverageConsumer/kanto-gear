return function(M, copy, pokemonPath, reaches, sortedKeys)
  function M:ownsKey(id)
    local session = self.adapter.session
    for _, pocket in pairs(session and session.bag and session.bag.pockets or {}) do
      for _, item in ipairs(pocket) do
        if item.id == id and (item.qty or 0) > 0 then return true end
      end
    end
    for _, item in ipairs(session and session.storage and session.storage.items or {}) do
      if item.id == id and (item.qty or 0) > 0 then return true end
    end
    return false
  end
  function M:completionKey()
    -- Native variable and Bag/PC writes need not emit flag.changed.
    -- Game path [Emerald]: Johto-starter and Mirage Tower variables change completion without flag.changed; RS has no equivalent cache inputs.
    if self.emerald then
      local function reached(name, value)
        return self.adapter.Flags.getVar(self.adapter:flagStore(), nil, self.constants:var(name)) >= value
      end
      return (reached("VAR_DEX_UPGRADE_JOHTO_STARTER_STATE", 6) and 1 or 0)
        + (reached("VAR_MIRAGE_TOWER_STATE", 2) and 2 or 0)
    end
    if self.rs then return 0 end
    -- These hidden, non-consumable keys require actual ownership.
    -- Game path [FireRed/LeafGreen]: Rocket keys require actual Bag/PC ownership because their objects start hidden.
    return (self:ownsKey(356) and 1 or 0) + (self:ownsKey(359) and 2 or 0)
  end
  function M:rows(mapIds, checkpoint)
    local out, adapter = { {}, {}, {}, {} }, self.adapter
    local store, Flags = adapter:flagStore(), adapter.Flags
    local function flag(id)
      if self.hoenn and type(id) == "string" then id = self.constants:flag(id) end
      return id ~= nil and Flags.getFlag(store, nil, id) == true
    end
    for _, id in ipairs(mapIds) do
      local catalog = self:catalog(id, checkpoint)
      for category = 1, 4 do
        for _, source in ipairs(catalog[category]) do
          if category ~= 4 or source.gift then
            local row = copy(source)
            -- Game path [FireRed/LeafGreen]: SS Anne departure and Silph story progress can remove objectives; HM01 remains required before departure.
            if id:match("^FR_SSANNE_") and row.itemId == 339 then row.required = true end -- HM01 is needed before departure.
            if not row.required and (id:match("^FR_SSANNE_")
                or category == 1 and id:match("^FR_SILPH_CO_")) then row.missable = true end
            row.done = row.event and flag(row.event) or false
            if row.receiptVar then row.done = Flags.getVar(store, nil, row.receiptVar) >= row.receiptValue end
            if row.catchGoal then row.done = adapter.save.pokedex.caught[row.species] == true end
            if row.flags then
              for event in pairs(row.flags) do row.done = row.done or flag(event) end
              if row.league then row.done = row.done or flag("FLAG_SYS_GAME_CLEAR") end
              if row.rival then row.label = adapter.session and adapter.session.rivalName or row.label end
            elseif row.ownedKey then
              row.done = self:ownsKey(row.itemId)
            end
            if row.itemId then row.label = (adapter.data.items[row.itemId] or {}).name or "ITEMS" end
            row.excluded = row.alternative and not row.done and flag(row.alternative)
              and not (row.choiceEvent and flag(row.choiceEvent)) or nil
            if row.needsChoice then
              local unlocked = Flags.getVar(store, nil, row.unlockVar) >= row.unlockValue
              row.done = row.done and unlocked and flag(row.needsChoice)
              row.excluded = flag(row.otherChoice)
              if not unlocked or not flag(row.needsChoice) then row.available, row.status = false, "LATER" end
            end
            if row.repeatable then
              row.available, row.done = not flag(row.event), false
              row.status = (category == 1 or not row.event) and "REPEATABLE" or row.available and "READY" or "RENEWABLE"
            elseif row.untracked then row.status = "NOT TRACKED"
            elseif row.excluded then row.status = "ALTERNATIVE CHOICE"
            elseif not row.done and id:match("^FR_SSANNE_") and flag("FLAG_HIDE_SS_ANNE") then
              row.missed, row.available, row.status = true, false, "MISSED"
            elseif not row.done and row.hideEvent and row.hideEvent >= 0x20 and flag(row.hideEvent) then
              row.available = false
              if row.flags and not self.initiallyHidden[row.hideEvent] then
                row.missed, row.status = true, "MISSED"
              else row.status = "LATER" end
            end
            if row.trade then
              row.label = adapter.data.pokemon[row.species].name
              row.order = adapter.data.pokemon[row.species].dex
              local partner
              for _, mon in ipairs(adapter.session and adapter.session.party or {}) do
                if not adapter.Pokemon.isEgg(mon) and adapter.Pokemon.speciesOf(mon) == row.needsSpecies then
                  partner = mon; break
                end
              end
              row.available = not row.done and row.available ~= false and partner ~= nil
                and reaches(self.source.scripts, row.scriptKey, row.command, row.event, 0, false, checkpoint, flag) == true
              row.status = row.done and "RECORDED" or row.available and "READY" or "LATER"
            end
            if category == 4 and row.gift and not row.trade then
              local session = adapter.session or {}
              local party = #(session.party or {})
              row.label = row.isEgg and "EGG" or adapter.data.pokemon[row.species].name
              row.order = row.isEgg and 0 or adapter.data.pokemon[row.species].dex
              row.noRoom = party >= 6 and (not row.toPC
                or not require("src.core.game3.storage").findOpenSlot(session.storage)) or nil
              local lead
              for _, mon in ipairs(session.party or {}) do if not adapter.Pokemon.isEgg(mon) then lead = mon; break end end
              local friendship = lead and adapter.Pokemon.friendshipOf(lead) or 0
              local score = friendship == 255 and 6 or friendship >= 200 and 5 or friendship >= 150 and 4
                or friendship >= 100 and 3 or friendship >= 50 and 2 or friendship > 0 and 1 or 0
              row.available = not row.done and not row.excluded and row.available ~= false and not row.noRoom
                and pokemonPath(self.source.scripts, row.scriptKey, row.command,
                  row.event or row.deliveryFlag or (row.receiptVar and { var = row.receiptVar, value = row.receiptValue }) or 0,
                  { live = true, party = party, money = session.money or 0, gender = session.gender,
                    choice = row.choice, coins = session.coins or 0, species = row.species,
                    friendship = score, flag = flag, var = function(v) return Flags.getVar(store, nil, v) end,
                    firered = not self.hoenn, rs = self.rs }, checkpoint) == true
              row.status = row.done and (row.catchGoal and "CAUGHT" or "RECORDED") or row.available and "READY" or "LATER"
            end
            out[category][#out[category] + 1] = row
          end
        end
      end
    end
    return out
  end
  function M:pokemon(mapIds, checkpoint, rewards)
    local adapter, bySpecies = self.adapter, {}
    rewards = rewards or self:rows(mapIds, checkpoint)[4]
    for _, id in ipairs(mapIds) do
      for _, row in ipairs(adapter:encounters(id)) do
        bySpecies[row.species] = { species = row.species, mapId = id, wild = true }
      end
      for _, row in ipairs(self:catalog(id, checkpoint)[4]) do
        if not row.gift and not (bySpecies[row.species] and bySpecies[row.species].wild) then bySpecies[row.species] = row end
      end
    end
    for _, row in ipairs(rewards) do if row.catchGoal then bySpecies[row.species] = row end end
    local caught, out = adapter.save and adapter.save.pokedex.caught or {}, {}
    local function goal(ids)
      local row, names, done = nil, {}, false
      for _, species in ipairs(ids) do
        if bySpecies[species] then
          row = row or copy(bySpecies[species])
          names[#names + 1] = adapter.data.pokemon[species].name
          if caught[species] then row.species, done = species, true end
          bySpecies[species] = nil
        end
      end
      if row then
        row.label, row.done = table.concat(names, " / "), done
        row.order = adapter.data.pokemon[row.species].dex
        out[#out + 1] = row
      end
    end
    for _, id in ipairs(mapIds) do
      -- Game path [Ruby/Sapphire/Emerald]: Route 101 starters form one choice; RS also collapses the two Devon fossil rewards into one choice.
      if self.hoenn and id:match("_ROUTE101$") then
        goal({ adapter.Pokemon.speciesFromNational(252), adapter.Pokemon.speciesFromNational(255),
          adapter.Pokemon.speciesFromNational(258) })
      elseif self.rs and id:match("_RUSTBORO_CITY_DEVON_CORP_2F$") then
        goal({ adapter.Pokemon.speciesFromNational(345), adapter.Pokemon.speciesFromNational(347) })
      -- Game path [FireRed/LeafGreen]: Oak starters, Dojo fighters and selected fossil revivals are exclusive choices, not three/two required captures.
      elseif id == "FR_OAKS_LAB" then
        -- One starter is obtainable, even before the player chooses it.
        local starter = adapter.Flags.getVar(adapter:flagStore(), nil, "VAR_STARTER_MON")
        if adapter.Flags.getFlag(adapter:flagStore(), nil, "FLAG_SYS_POKEMON_GET") then
          local selected = ({ [0] = 1, [1] = 7, [2] = 4 })[starter]
          for _, sp in ipairs({ 1, 4, 7 }) do if sp ~= selected then bySpecies[sp] = nil end end
        end
        goal({ 1, 4, 7 })
      elseif id == "FR_SAFFRON_CITY_DOJO" then goal({ 106, 107 })
      elseif id == "FR_CINNABAR_ISLAND_POKEMON_LAB_EXPERIMENT_ROOM" then
        if adapter.Flags.getFlag(adapter:flagStore(), nil, "FLAG_GOT_DOME_FOSSIL") then bySpecies[138] = nil
        elseif adapter.Flags.getFlag(adapter:flagStore(), nil, "FLAG_GOT_HELIX_FOSSIL") then bySpecies[140] = nil end
        goal({ 138, 140 })
      end
    end
    for _, species in ipairs(sortedKeys(bySpecies)) do goal({ species }) end
    local choices = {}
    for _, row in ipairs(rewards) do
      local receipt = row.event or (row.receiptVar and "var:" .. row.receiptVar .. ":" .. row.receiptValue)
      if row.alternative and not (adapter.Flags.getFlag(adapter:flagStore(), nil, 626)
          and adapter.Flags.getFlag(adapter:flagStore(), nil, 627)) then receipt = "fossil-choice" end
      local existing = not row.trade and choices[receipt]
      if row.catchGoal or row.excluded then -- Caught goals are already included above; unchosen fossils are unobtainable.
      elseif existing then
        existing.label = existing.label .. " / " .. row.label
        existing.done = existing.done or row.done
      else
        out[#out + 1] = row
        if not row.trade then choices[receipt] = row end
      end
    end
    table.sort(out, function(a, b) return a.order < b.order end)
    return out
  end
end
