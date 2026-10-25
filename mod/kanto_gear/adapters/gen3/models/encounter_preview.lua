-- Consume the host's encounter.table read contract. Providers own their roll
-- rules; Gear never samples encounters or discovers individual spawn mods.
return function(Gen3)
  local methods = { { "WALK", "grass" }, { "SURF", "water" } }
  local function finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
  end
  local function project(self, mapId, method, info, native)
    if type(info) ~= "table" or type(info.dist) ~= "table"
        or not finite(info.chance) or info.chance < 0 or info.chance > 1 then return nil end
    local weights, total = {}, 0
    for species, weight in pairs(info.dist) do
      if not finite(weight) or weight < 0 then return nil end
      if weight > 0 then
        local def = self.data.pokemon[species]
        local id = def and (def.index or type(species) == "number" and species)
        if not id then return nil end -- an unresolved provider ID is not a partial distribution
        weights[id], total = (weights[id] or 0) + weight, total + weight
      end
    end
    if not finite(total) then return nil end
    if info.chance == 0 or total == 0 then return {} end
    local bySpecies, unchanged = {}, true
    for _, row in ipairs(native) do
      if row.method == method then bySpecies[row.species] = row end
    end
    for id, weight in pairs(weights) do
      local row = bySpecies[id]
      if not row or math.abs(row.chance - weight * 100 / total) > 1e-8 then unchanged = false end
    end
    for id in pairs(bySpecies) do if not weights[id] then unchanged = false end end
    local out = {}
    for id, weight in pairs(weights) do
      local old = unchanged and bySpecies[id]
      out[#out + 1] = { species = id, mapId = mapId, method = method,
        chance = weight * 100 / total,
        -- RFC 0019 reports species weights, not levels. A changed distribution
        -- cannot tell us which old slot supplied a new species; show unknown.
        minLevel = old and old.minLevel or nil, maxLevel = old and old.maxLevel or nil }
    end
    table.sort(out, function(a, b) return a.species < b.species end)
    return out
  end

  function Gen3:clearEncounterPreviews()
    self.encounterPreviews = nil
  end

  function Gen3:previewEncounters(mapId, native)
    local world = self.encounterWorld
    if not world or type(world.effectiveEncounters) ~= "function" then return native end
    local now = self.encounterClock and self.encounterClock()
      or love and love.timer and love.timer.getTime and love.timer.getTime()
    local cache = self.encounterPreviews
    if not cache or cache.session ~= self.game.session or cache.world ~= world then
      cache = { session = self.game.session, world = world, maps = {} }
      self.encounterPreviews = cache
    end
    local entry = cache.maps[mapId]
    if not entry or not now or not entry.at or now < entry.at or now - entry.at >= 0.5 then
      entry = { at = now, results = {} }
      cache.maps[mapId] = entry
      for _, pair in ipairs(methods) do
        local ok, info = pcall(world.effectiveEncounters, world, mapId, pair[2])
        if ok then entry.results[pair[1]] = info end
      end
    end
    local replacements = {}
    for _, pair in ipairs(methods) do
      replacements[pair[1]] = project(self, mapId, pair[1], entry.results[pair[1]], native)
    end
    local out, added = {}, {}
    for _, row in ipairs(native) do
      local replacement = replacements[row.method]
      if replacement == nil then out[#out + 1] = row
      elseif not added[row.method] then
        for _, item in ipairs(replacement) do out[#out + 1] = item end
        added[row.method] = true
      end
    end
    for _, pair in ipairs(methods) do
      if not added[pair[1]] then
        for _, row in ipairs(replacements[pair[1]] or {}) do out[#out + 1] = row end
      end
    end
    return out
  end
end
