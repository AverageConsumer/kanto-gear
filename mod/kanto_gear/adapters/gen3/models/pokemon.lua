return function(Gen3, copy)
  local pockets = { ITEMS = "ITEM", KEY_ITEMS = "KEY_ITEM",
    POKE_BALLS = "BALL", TM_CASE = "TM_HM", BERRY_POUCH = "BERRY" }
  local statFields = { hp = "maxHp", attack = "attack", defense = "defense",
    speed = "speed", specialAttack = "spAtk", specialDefense = "spDef" }
  local geneticFields = { "hp", "atk", "def", "spe", "spa", "spd" }
  local statusNames = { "PSN", "PAR", "SLP", "FRZ", "BRN", [7] = "FNT" }
  function Gen3:types(source)
    local out = {}
    for _, id in ipairs(source or {}) do
      local name = type(id) == "number" and self.typeNames[id] or id
      if name and name ~= out[1] then out[#out + 1] = name end
    end
    return out
  end
  function Gen3:refreshDefinitions()
    local source, speciesById = nil, {}
    if self.content then
      -- API 3 owns the merged definitions and their symbolic IDs. Keep native
      -- indices only at this presentation adapter's storage/sprite boundary.
      source = { pokemon = {}, moves = {}, items = {} }
      for _, name in ipairs({ "pokemon", "moves", "items" }) do
        for id, row in self.content[name]:each() do
          if row.index then source[name][row.index] = row end
          if name == "pokemon" and row.index then
            speciesById[id] = row.index
            if row.id then speciesById[row.id] = row.index end
          end
        end
      end
    else
      -- Standalone native data readers have no loaded mod/registry service.
      source = require("src.mods.Gen3Compat").dataView(self.game.data or {})
    end
    local P, M, I = self.Pokemon, self.Moves, self.Items
    local dexData = require("src.core.game3.pokedex_data")
    -- Game path [Ruby/Sapphire/Emerald]: read Hoenn Dex entries and numbering; FireRed/LeafGreen uses its own Dex data reader.
    local hoennEntries = self.hoenn and
      assert(require("src.ui.game3.rse.mapsec").readLua("pokemon/pokedex/entries.lua"))
    local data = { pokemon = {}, moves = {}, items = {}, maps = self.game.data and self.game.data.maps or {} }
    local function addPokemon(id, dex, registered)
        local row = copy(source.pokemon[id])
        row.index, row.dex, row.national = id, dex, dex
        row.regionalDex = self.Dex.regionalNumber and self.Dex.regionalNumber(id, self.profile.id)
          or (not self.hoenn and dex <= 151 and dex or nil)
        local declared = registered and row.dexEntry
        local entry = declared and { category = declared.kind, height = declared.height,
          weight = declared.weight, description = declared.text }
          or hoennEntries and hoennEntries[id] or not self.hoenn and dexData.getEntry(id)
          or {}
        row.dexEntry = { kind = entry.category or "", heightM = (entry.heightDm or entry.height or 0) / 10,
          weightKg = (entry.weightHg or entry.weight or 0) / 10,
          -- Game path [Ruby/Sapphire]: native descriptions span two text fields, which must be joined for the common Dex page.
          text = self.rs and entry.description2 and (entry.description or "") .. "\n" .. entry.description2 or entry.description or "" }
        row.types = self:types(row.types)
        if self.content then
          local learnset = {}
          for _, move in ipairs(row.level1Moves or {}) do
            learnset[#learnset + 1] = { level = 1, move = move }
          end
          for _, learn in ipairs(row.learnset or {}) do learnset[#learnset + 1] = learn end
          row.learnset = learnset
        else
          row.learnset = {}
          for _, learn in ipairs(P.learnset(id) or {}) do
            row.learnset[#row.learnset + 1] = {
              level = learn.level or learn[1], move = M.constName(learn.move or learn.id or learn[2]),
            }
          end
          row.tmhm = {}
          for itemId = I.FIRST_TM, I.LAST_HM do
            if P.canLearnTmItem(id, itemId) then
              row.tmhm[#row.tmhm + 1] = M.constName(P.moveFromTmItem(itemId))
            end
          end
        end
        data.pokemon[id] = row
    end
    -- Native holes/egg sprites are not species. Registered additions and forms
    -- are authoritative even when they have no canonical National-number slot.
    for dex = 1, self.Dex.NATIONAL_MAX do
      local id = P.speciesFromNational(dex)
      if id then addPokemon(id, dex) end
    end
    if self.content then
      for id, row in pairs(source.pokemon) do
        local dex = tonumber(row.baseDex or row.dex or row.national)
        if not data.pokemon[id] and dex and dex > 0 then addPokemon(id, dex, true) end
      end
    end
    for id = 1, require("src.import.gba.versions").MOVES_COUNT - 1 do
      local row = copy(source.moves[id])
      row.index, row.id = id, M.constName(id)
      row.type = self.typeNames[row.type] or row.type
      row.name = row.name or M.displayName(id)
      row.nativeGen3 = true
      row.description = self.Summary.moveDescription(id, row.name)
      data.moves[row.id] = row
    end
    setmetatable(data.moves, { __index = function(t, id)
      if type(id) == "number" and id > 0 then return rawget(t, M.constName(id)) end
    end })
    I.ensureLoaded()
    for id in pairs(I._byId or {}) do
      local row = copy(source.items[id])
      row.index, row.nativePocket = id, I.PACK_POCKET[row.pocket] or row.pocket
      row.pocket = pockets[row.nativePocket]
      row.kind = I.medicineKind(id)
      row.ball = row.pocket == "BALL"
      local taught = P.moveFromTmItem(id)
      row.teaches = taught and M.constName(taught)
      data.items[id] = row
    end
    setmetatable(data.items, { __index = function(t, id)
      local num = I.toNumericId(id)
      return num and rawget(t, num)
    end })
    data.type_chart = { matchups = {} }
    for name, id in pairs(self.Types.ID) do
      for other, target in pairs(self.Types.ID) do
        local multiplier = self.Types.effectiveness(id, target) * 10
        if multiplier ~= 10 then
          data.type_chart.matchups[#data.type_chart.matchups + 1] = {
            attacker = name, defender = other, multiplier = multiplier,
          }
        end
      end
    end
    self.data = data
    setmetatable(data.pokemon, { __index = function(t, id)
      if type(id) == "string" then
        local numeric = speciesById[id] or P.speciesFromName(id)
        return numeric and rawget(t, numeric)
      end
    end })
    setmetatable(data, { __index = self.game.data })
  end
  function Gen3:mon(source)
    if type(source) ~= "table" then return nil end
    local out = self.mons[source]
    if not out then
      out = { moves = {}, stats = {}, ivs = {}, evs = {} }
      self.mons[source] = out
    end
    local P = self.Pokemon
    out.species, out.level = P.speciesOf(source), source.level
    out.speciesNumbering = P.NUMBERING_INTERNAL
    out.nickname = source.nickname ~= "" and source.nickname or nil
    -- Forms can have native species slots without a National Dex definition.
    out.name = P.name(out.species)
    out.hp, out.maxHp = source.hp, source.maxHp
    out.status = statusNames[self.Summary.statusAilment(source)]
    out.pokerus = source.pokerus
    out.isEgg = P.isEgg(source)
    out.friendship, out.happiness = source.friendship, source.happiness
    out.eggCycles, out.isBadEgg = source.eggCycles, source.isBadEgg
    out.personality = source.personality
    out.gender = self.Summary.gender(source)
    out.shiny = P.isShiny(source)
    out.nature = P.natureId(source.personality)
    out.ability = source.ability or source.abilityId or P.abilityId(out.species, source.personality)
    out.types = self:types(P.types(out.species))
    out.ot, out.otId, out.otSecretId = source.otName or source.ot, source.otId, source.otSecretId
    out.exp, out.experience = source.exp or source.experience, source.exp or source.experience
    out.item = source.heldItem or source.item
    for key, field in pairs(statFields) do out.stats[key] = source[field] end
    for _, key in ipairs(geneticFields) do
      out.ivs[key] = source.ivs and source.ivs[key]
      out.evs[key] = source.evs and source.evs[key]
    end
    for slot = 1, 4 do
      local id = source.moves and source.moves[slot]
      if id and id ~= 0 then
        local move = out.moves[slot] or {}
        move.id, move.index = self.Moves.constName(id), id
        move.pp = source.pp and source.pp[slot]
        move.maxPp = source.maxPp and source.maxPp[slot]
        move.ppUps = source.ppUps and source.ppUps[slot] or 0
        out.moves[slot] = move
      else out.moves[slot] = nil end
    end
    return out
  end
end
