return function(Gen3, copy)
  local pockets = { ITEMS = "ITEM", KEY_ITEMS = "KEY_ITEM",
    POKE_BALLS = "BALL", TM_CASE = "TM_HM", BERRY_POUCH = "BERRY" }
  local statFields = { hp = "maxHp", attack = "attack", defense = "defense",
    speed = "speed", specialAttack = "spAtk", specialDefense = "spDef" }
  local geneticFields = { "hp", "atk", "def", "spe", "spa", "spd" }
  local statusNames = { "PSN", "PAR", "SLP", "FRZ", "BRN", "PKRS", "FNT" }
  function Gen3:types(source)
    local out = {}
    for _, id in ipairs(source or {}) do
      local name = type(id) == "number" and self.typeNames[id] or id
      if name and name ~= out[1] then out[#out + 1] = name end
    end
    return out
  end
  function Gen3:refreshDefinitions()
    local Compat = require("src.mods.Gen3Compat")
    local source = Compat.dataView(self.game.data or {})
    local P, M, I = self.Pokemon, self.Moves, self.Items
    local dexData = require("src.core.game3.pokedex_data")
    -- Game path [Ruby/Sapphire/Emerald]: read Hoenn Dex entries and numbering; FireRed/LeafGreen uses its own Dex data reader.
    local hoennEntries = self.hoenn and
      assert(require("src.ui.game3.rse.mapsec").readLua("pokemon/pokedex/entries.lua"))
    local data = { pokemon = {}, moves = {}, items = {}, maps = self.game.data and self.game.data.maps or {} }
    -- Iterate National IDs, not the native table length (which includes holes
    -- and special sprite IDs). Keep internal IDs as keys everywhere else.
    for dex = 1, self.Dex.NATIONAL_MAX do
      local id = P.speciesFromNational(dex)
      if id then
        local row = copy(source.pokemon[id])
        row.index, row.dex, row.national = id, dex, dex
        row.regionalDex = self.Dex.regionalNumber and self.Dex.regionalNumber(id, self.profile.id)
          or (not self.hoenn and dex <= 151 and dex or nil)
        local entry = hoennEntries and assert(hoennEntries[id]) or dexData.getEntry(id)
        row.dexEntry = { kind = entry.category, heightM = (entry.heightDm or entry.height) / 10,
          weightKg = (entry.weightHg or entry.weight) / 10,
          -- Game path [Ruby/Sapphire]: native descriptions span two text fields, which must be joined for the common Dex page.
          text = self.rs and entry.description2 and entry.description .. "\n" .. entry.description2 or entry.description }
        row.types = self:types(row.types)
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
        data.pokemon[id] = row
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
      row.index, row.nativePocket = id, row.pocket
      row.pocket = pockets[row.pocket]
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
        local numeric = P.speciesFromName(id)
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
    out.hp, out.maxHp = source.hp, source.maxHp
    out.status = statusNames[self.Summary.statusAilment(source)]
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
