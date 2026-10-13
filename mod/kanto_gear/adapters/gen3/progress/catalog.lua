return function(M, sortedKeys, Rules)
  function M:bundle()
    -- The field engine owns/loads the bundle. Boot and missing extraction must
    -- yield unknown objectives, not a permanently cached empty catalogue.
    local bundle = self.adapter.Space.bundle
    if bundle ~= self.source then
      self.maps, self.source = {}, bundle
      self.unusedHideout = nil
      -- Game path [Ruby/Sapphire/Emerald]: ResetAllMapFlags supplies initial object visibility; FRLG has a native initial-hide table.
      if self.hoenn and bundle then
        self.initiallyHidden = {}
        for _, row in ipairs(M.scan(bundle.scripts, "EventScript_ResetAllMapFlags")) do
          if row.op == "setflag" then self.initiallyHidden[row.flag or row[1]] = true end
        end
      end
      -- Game path [Ruby vs Sapphire]: both hideouts are imported, but the opposing teams entrance is blocked; require native terrain/script proof.
      if self.rs and bundle then
        -- RS ships both Lilycove hideouts. Terrain/load scripts wall off the
        -- unused entrance. Require that native proof so a custom map which
        -- opens it can still supply objectives instead of being filtered by ID.
        local prefix = self.adapter.profile.map.enginePrefix
        local unused = prefix .. (self.adapter.profile.id == "ruby" and "AQUA" or "MAGMA") .. "_HIDEOUT_"
        local city = self.adapter.data.maps[prefix .. "LILYCOVE_CITY"]
        local event = bundle.events[prefix .. "LILYCOVE_CITY"]
        local key = event and event.mapScripts and event.mapScripts.onLoad
        for _, warp in ipairs(city and city.warps or {}) do
          if warp.destMap == unused .. "1F" then
            local layout = city.midLayout
            local blocked = layout and layout:collAt(warp.x, warp.y) ~= 0 or false
            local opened = false
            for _, row in ipairs(bundle.scripts[key] or {}) do
              if row.op ~= "setmetatile" then break end
              if row[1] == warp.x and row[2] == warp.y and row[4] == 1 then blocked = true end
            end
            for _, row in ipairs(M.scan(bundle.scripts, key)) do
              if row.op == "setmetatile" and row[1] == warp.x and row[2] == warp.y and row[4] == 0 then opened = true end
            end
            if blocked and not opened then self.unusedHideout = unused end
          end
        end
      end
    end
    return bundle
  end
  function M:catalog(mapId, checkpoint)
    local bundle = self:bundle()
    if self.maps[mapId] then return self.maps[mapId] end
    if self.unusedHideout and mapId:sub(1, #self.unusedHideout) == self.unusedHideout then
      self.maps[mapId] = { {}, {}, {}, {} }
      return self.maps[mapId]
    end
    local event = bundle and bundle.events and bundle.events[mapId]
    if not event or not bundle.scripts then
      return { { { label = "NOT TRACKED", mapId = mapId, untracked = true } }, {}, {}, {} }
    end
    local out, trainers, pokemon, gifts = { {}, {}, {}, {} }, {}, {}, {}
    local function base(obj)
      return { mapId = mapId, x = obj.x, y = obj.y, index = obj.localId,
        id = mapId .. "_obj_" .. tostring(obj.localId), spriteId = obj.sprite,
        graphicsId = obj.graphicsId or obj.graphics, graphicsVar = obj.graphicsVar,
        facing = obj.facing, hideEvent = obj.flag }
    end
    local function mon(species, obj, giftCommand, missable)
      if Rules.uncatchable(mapId, species) then return end
      if not self.adapter.data.pokemon[species] then
        out[1][#out[1] + 1] = { label = "POKEMON", mapId = mapId, untracked = true }
        return
      end
      if pokemon[species] then
        if not giftCommand then pokemon[species].giftCommand = nil end
        return
      end
      local row = base(obj)
      row.species, row.giftCommand = species, giftCommand
      row.missable = missable or nil
      pokemon[species], out[4][#out[4] + 1] = row, row
    end
    local function scan(obj, objectSource)
      if checkpoint then checkpoint() end
      local rows, vars, missing = M.scan(bundle.scripts, obj.scriptKey, checkpoint)
      local hasTrainer, hasMon, hasItem = false, false, false
      local proven = {}
      for _, offer in ipairs(objectSource and self:pokemonGifts(bundle.scripts, obj.scriptKey, rows, vars, obj, checkpoint, mapId) or {}) do
        local receipt = offer.catchGoal and "caught" or offer.event or ("var:" .. offer.receiptVar .. ":" .. offer.receiptValue)
        local key = tostring(receipt) .. ":pokemon:" .. offer.species
        proven[offer.command] = true
        if not gifts[key] then
          local row = base(obj)
          for k, v in pairs(offer) do row[k] = v end
          row.id, row.kind, row.gift = mapId .. "_gift_" .. key, "pokemon", true
          Rules.revivedFossil(mapId, row)
          gifts[key], out[4][#out[4] + 1] = row, row
        end
      end
      if objectSource then
        local offers, unknown = self:trades(bundle.scripts, obj.scriptKey, rows, vars, checkpoint)
        missing = missing or unknown
        for _, offer in ipairs(offers) do
          local row = base(obj)
          for k, v in pairs(offer) do row[k] = v end
          row.id = mapId .. "_trade_" .. offer.tradeId
          row.kind, row.gift, row.trade = "pokemon", true, true
          out[4][#out[4] + 1] = row
        end
      end
      for _, gift in ipairs(objectSource
          and M.gifts(bundle.scripts, obj.scriptKey, rows, self.initiallyHidden, checkpoint) or {}) do
        local key = tostring(gift.event) .. ":" .. gift.itemId
        if not gifts[key] and self.adapter.data.items[gift.itemId] then
          local row = base(obj)
          row.kind, row.gift, row.itemId, row.event = "item", true, gift.itemId, gift.event
          -- This shared Pokemon Center reward needs an external event/record mix.
          -- Game path [Ruby/Sapphire/Emerald]: Eon Ticket depends on an external event/record mix; daily flags mark repeatable rather than permanent gifts.
          row.optional = self.hoenn and gift.itemId == self.constants:id("items", "ITEM_EON_TICKET") or nil
          local daily = self.hoenn and self.constants:flag("DAILY_FLAGS_START")
          row.repeatable = daily and gift.event >= daily
            and gift.event <= (self.constants:flag("DAILY_FLAGS_END") or daily + 63) or nil
          row.id = mapId .. "_gift_" .. key
          gifts[key], out[2][#out[2] + 1] = row, row
        end
      end
      for _, command in ipairs(rows) do
        if command.op == "trainerbattle" then
          hasTrainer = true
          local id, typ = command.trainer or command[1], command.type
          local def = self.Trainers.get(id)
          -- Game path [Gen 3]: rematch opcodes differ in Emerald; rival/leader classes and League maps differ between Hoenn and FRLG.
          if typ ~= 5 and typ ~= 7 and not (self.emerald and (typ == 9 or typ == 12)) then -- rematch op points at the same base trainer
            local rival = def and (self.hoenn and def.class == self.constants:id("trainer_classes",
                self.rs and "TRAINER_CLASS_POKEMON_TRAINER_3" or "TRAINER_CLASS_RIVAL")
              or not self.hoenn and (def.class == 81 or def.class == 89 or def.class == 90))
            local league = mapId:match("^FR_POKEMON_LEAGUE_") ~= nil
              or self.hoenn and mapId:match("_EVER_GRANDE_CITY_.*ROOM$") ~= nil
            local key = rival and ("rival:" .. tostring(def.class) .. ":" .. tostring(typ == 9))
              or league and def and ("league:" .. def.class .. ":" .. def.name) or tostring(id)
            local row = trainers[key]
            if not row then
              row = base(obj)
              row.id = mapId .. "_trainer_" .. key
              row.label = def and ((def.className or "") .. " " .. (def.name or "")):gsub("^%s+", "") or "TRAINERS"
              row.rival, row.league, row.optional = rival, league, not self.hoenn and typ == 9
              row.required = not row.optional and (rival or league or def and (not self.hoenn and def.class == 83
                or self.hoenn and (def.class == self.constants:id("trainer_classes", "TRAINER_CLASS_AQUA_LEADER")
                  or def.class == self.constants:id("trainer_classes", "TRAINER_CLASS_MAGMA_LEADER")))) or nil
              row.flags, row.untracked = {}, not def or type(id) ~= "number"
              trainers[key], out[1][#out[1] + 1] = row, row
            end
            if type(id) == "number" then row.flags[self.adapter.Flags.trainerFlagId(id)] = true end
          end
        elseif command.op == "setwildbattle" or command.op == "givemon" or command.op == "giveegg" then
          hasMon = true
          local species = command[1]
          if proven[command] then -- receipt-based objective above
          elseif type(species) == "number" and species < 0x4000 then
            mon(species, obj, command.op ~= "setwildbattle" and command or nil, command.op == "setwildbattle")
          elseif vars[species] then
            for _, candidate in ipairs(sortedKeys(vars[species])) do
              mon(candidate, obj, command.op ~= "setwildbattle" and command or nil, command.op == "setwildbattle")
            end
          else
            out[1][#out[1] + 1] = { label = "POKEMON", mapId = mapId, untracked = true }
          end
        -- Game path [FireRed/LeafGreen]: special 443 creates an event-legal encounter from preceding variables instead of setwildbattle.
        elseif not self.hoenn and command.op == "special" and command.id == 443 then
          -- CreateEventLegalEnemyMon uses the immediately preceding three vars.
          local species
          for _, r in ipairs(rows) do
            if r == command then break end
            if r.op == "setvar" and (r.var or r[1]) == 0x8004 then species = r.value or r[2] end
          end
          hasMon = true
          mon(species, obj, nil, true)
        -- Game path [Ruby/Sapphire/Emerald]: the starter chooser is a ROM-specific special, so record Treecko/Torchic/Mudkip as one choice.
        elseif self.hoenn and command.op == "special" and command.id == self.constants:special(
            self.rs and "ScrSpecial_ChooseStarter" or "ChooseStarter") then
          hasMon = true
          for _, nat in ipairs({ 252, 255, 258 }) do mon(self.adapter.Pokemon.speciesFromNational(nat), obj) end
        -- Game path [FireRed/LeafGreen vs Hoenn]: trade-species queries have different special IDs; the receipt-based offer supplies the objective.
        elseif command.op == "specialvar" and command[2] == (self.hoenn
            and self.constants:special("GetInGameTradeSpeciesInfo") or 252) then
          hasMon = true -- The proven offer is a separate receipt-based objective above.
        end
      end
      -- Ground pickups use Std_FindItem and their object's durable flag.
      if objectSource then
        local value
        for _, command in ipairs(bundle.scripts[obj.scriptKey] or {}) do
          if (command.op == "setvar" or command.op == "setorcopyvar") and (command.var or command[1]) == 0x8000 then
            value = command.value or command[2]
          elseif (command.op == "callstd" or command.op == "gotostd") and command.std == 1 then
            local row = base(obj)
            row.kind, row.itemId, row.event = "item", value, obj.flag
            row.unknown = not self.adapter.data.items[value]
            row.untracked = row.unknown or not obj.flag or obj.flag < 0x20 or obj.flag == 65535
            -- Game path [Emerald]: Battle Pyramid items are randomized per challenge and have no permanent route collection receipt.
            if self.emerald and mapId:match("^EM_BATTLE_PYRAMID_SQUARE") then
              -- These templates receive random items for each challenge and have
              -- no permanent collection flag. Never count them as route pickups.
              row.itemId, row.event, row.untracked, row.repeatable = nil, nil, nil, true
              row.label = "ITEMS"
            end
            out[2][#out[2] + 1], hasItem = row, true
          end
        end
        hasItem = Rules.items(self, mapId, obj, vars, value, out, base) or hasItem
        local decorativeBall = Rules.decorativeBall(self, obj)
        if not hasTrainer and (obj.trainerType == 1 or obj.trainerType == 3)
            or obj.graphicsId == (self.hoenn and self.constants:id("event_objects", "OBJ_EVENT_GFX_ITEM_BALL") or 92)
              and not hasItem and not hasMon and not decorativeBall then
          local row = base(obj)
          row.label, row.untracked = "NOT TRACKED", true
          out[1][#out[1] + 1] = row
        end
      end
      if missing then
        local row = base(obj)
        row.label, row.untracked = "NOT TRACKED", true
        out[1][#out[1] + 1] = row
      end
    end
    for _, obj in ipairs(event.objects or {}) do
      if not obj.cloneTarget then scan(obj, true) end
    end
    for _, obj in ipairs(event.coordEvents or {}) do scan(obj) end
    for _, key in ipairs(sortedKeys(event.mapScripts)) do
      local entry = event.mapScripts[key]
      if type(entry) == "string" then scan({ scriptKey = entry })
      elseif type(entry) == "table" then
        for _, trigger in ipairs(entry) do scan({ scriptKey = trigger.script }) end
      end
    end
    for _, bg in ipairs(event.bgEvents or {}) do
      if bg.type == "hidden_item" then
        local row = base(bg)
        row.kind, row.itemId, row.event = "hidden", bg.item, bg.flag
        row.underfoot = bg.underfoot
        row.repeatable = self.renewable[bg.flag] == true
        row.unknown = not self.adapter.data.items[bg.item]
        row.untracked = row.unknown or not bg.flag or bg.flag < 0x20
        out[3][#out[3] + 1] = row
      elseif bg.scriptKey then scan(bg) end
    end
    -- Game path [Ruby/Sapphire/Emerald]: optional Aqua/Magma opponents can disappear after story progress and must remain marked missable.
    if self.hoenn then
      for _, row in ipairs(out[1]) do
        local name = (self.constants.flags.byId.FLAG_ or {})[row.hideEvent] or ""
        if row.flags and not row.required and (name:find("AQUA") or name:find("MAGMA")) then row.missable = true end
      end
    end
    -- Game path [FRLG/Emerald]: Trainer Tower, Trainer Hill and Frontier opponents are generated per challenge, not permanent route defeats.
    if mapId:match("^FR_TRAINER_TOWER_%dF$") or mapId:match("^EM_TRAINER_HILL_")
        or mapId:match("^EM_BATTLE_FRONTIER_BATTLE_") or mapId:match("^EM_BATTLE_PYRAMID_SQUARE") then
      -- Tower opponents are generated per challenge, without route defeat flags.
      out[1][#out[1] + 1] = { label = "TRAINERS", mapId = mapId, repeatable = true }
    end
    -- A battle callback and its retry NPC can reference the same gift command.
    for i = #out[4], 1, -1 do
      local row = out[4][i]
      if row.giftCommand then
        for _, reward in ipairs(out[4]) do
          if reward.command == row.giftCommand then table.remove(out[4], i); break end
        end
      end
    end
    table.sort(out[4], function(a, b) return a.species < b.species end)
    self.maps[mapId], self.builds = out, self.builds + 1
    return out
  end
end
