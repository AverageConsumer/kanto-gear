return function(Gen3)
  function Gen3:itemfinderSignals()
    if not self.session or (self.save.inventory.ITEMFINDER or 0) < 1 then return {} end
    local Map = require("src.core.game3.map")
    local Player = require("src.core.game3.player")
    local id, store = self.session.map, self:flagStore()
    local function events(map)
      local def = self.data.maps[map]
      local bundle = self.Space.bundle and self.Space.bundle.events and self.Space.bundle.events[map]
      return def and def.bgEvents or bundle and bundle.bgEvents or {}
    end
    local current = Map.current == id
    local layout = self.data.maps[id] and self.data.maps[id].midLayout
    local result = require("src.core.game3.itemfinder").scan({
      px = current and Player.cellX or self.session.x,
      py = current and Player.cellY or self.session.y,
      events = events(id), width = layout and layout.width, height = layout and layout.height,
      neighborList = current and Map.neighborList or {},
      neighbors = current and Map.neighbors or {}, eventsFor = events,
      flagSet = function(ev)
        local flag = ev.flag or ev.hiddenItemId and ((self.flagDefinitions.IDS.FLAG_HIDDEN_ITEMS_START or 0x3E8) + ev.hiddenItemId)
        return not flag or self.Flags.getFlag(store, nil, flag)
      end,
    })
    -- A read-only scan: no native animation, flag writes or underfoot pickup.
    return result and { { dx = result.itemX, dy = result.itemY } } or {}
  end
  function Gen3:itemfinderReached(px, py, row, progress)
    if row.done or row.available == false or row.untracked then return false end
    local result = require("src.core.game3.itemfinder").scan({ px = px, py = py,
      events = { { type = "hidden_item", x = row.x, y = row.y, underfoot = row.underfoot } },
      flagSet = function() return false end })
    if not result then return false end
    return (row.x - px)^2 + (row.y - py)^2 <= 74 * math.max(0, math.min(1, progress or 0))^2
  end
  function Gen3:locations()
    if self.locationCache then return self.locationCache end
    local sections = require("src.import.gba.map_sections_extract")
    local out = {}
    for id, def in pairs(self.data.maps) do
      local info
      -- Game path [Ruby/Sapphire/Emerald]: native map-section names come from Hoenn mapsec; FireRed/LeafGreen resolves Kanto sections/floors.
      if self.hoenn then
        local entry = require("src.ui.game3.rse.mapsec").entry(def.regionMapSectionId)
        info = entry and { resolved = true, rawName = entry.name }
      else info = sections.getInfo(def.regionMapSectionId, id, def.floorNum) end
      local name = info and info.resolved and info.rawName
      local named = type(name) == "string" and name:find("%S") ~= nil
      out[id] = { name = named and name
        or id:gsub("^%u%u_", ""):gsub("_", " "), section = def.regionMapSectionId }
      -- Localized names are labels, never progress identity. Keep gyms/dojo
      -- separate from city houses; combine dungeon floors and route segments.
      local facility = id:match("_GYM$") and "GYM" or id:match("_DOJO$") and "DOJO"
      -- The unnamed map section is shared by unrelated ships, link rooms and facilities.
      out[id].progressGroup = facility and id or named and "gen3:" .. tostring(def.regionMapSectionId or id) or id
      out[id].progressKind = id:match("FOREST$") and "forest"
        or def.mapType == 4 and "cave" or "route"
      if facility and named then out[id].name = out[id].name .. " " .. facility end
    end
    self.locationCache = out
    return out
  end
  function Gen3:areaMaps(id)
    local locations = self:locations()
    local group = locations[id] and locations[id].progressGroup
    if not group then return { id } end
    local out = {}
    for other, location in pairs(locations) do
      if location.progressGroup == group then out[#out + 1] = other end
    end
    table.sort(out)
    return out
  end
  function Gen3:toolUnlocked(def)
    if def.item then return (self.save and self.save.inventory[def.item] or 0) > 0 end
    if def.move == "HEADBUTT" or def.move == "WHIRLPOOL" then return false end
    if not self.FieldMoves.MOVES[def.move] then return false end
    return self.FieldMoves.partyMoveUser(self.session and self.session.party, def.move) ~= nil
      and self.FieldMoves.hasBadge(self:flagStore(), def.move) == true
  end
  function Gen3:methods()
    local session, inventory = self.session, self.save and self.save.inventory or {}
    local out = { WALK = true }
    for _, rod in ipairs({ "OLD", "GOOD", "SUPER" }) do
      out[rod] = (inventory[rod .. "_ROD"] or 0) > 0
    end
    for method, move in pairs({ SURF = "SURF", ["ROCK SMASH"] = "ROCK_SMASH" }) do
      local mon = self.FieldMoves.partyMoveUser(session and session.party or {}, move)
      out[method] = mon ~= nil and self.FieldMoves.hasBadge(self:flagStore(), move) == true
    end
    return out
  end
  function Gen3:habitatMethods()
    local methods = self:methods()
    local available = {}
    local function learn(mon)
      if not mon or self.Pokemon.isEgg(mon) then return end
      for _, id in ipairs(mon.moves or {}) do available[id] = true end
    end
    for _, mon in ipairs(self.session and self.session.party or {}) do learn(mon) end
    for _, box in ipairs(self.session and self.session.storage and self.session.storage.boxes or {}) do
      for slot = 1, 30 do learn(box.mons and box.mons[slot]) end
    end
    for id, count in pairs(self.save and self.save.inventory or {}) do
      local move = self.Pokemon.moveFromTmItem(id)
      if move and count > 0 then available[move] = true end
    end
    local reasons = {}
    for _, rod in ipairs({ "OLD", "GOOD", "SUPER" }) do
      if not methods[rod] then reasons[rod] = "NEED " .. rod .. " ROD" end
    end
    for method, move in pairs({ SURF = "SURF", ["ROCK SMASH"] = "ROCK_SMASH" }) do
      if not available[self.FieldMoves.MOVES[move]] then
        reasons[method] = "NEED " .. method
      elseif not self.FieldMoves.hasBadge(self:flagStore(), move) then
        reasons[method] = "NEED BADGE"
      end
    end
    return reasons
  end
  -- Slot odds are conditional on this encounter method, not the step encounter
  -- rate. Each rod has its own 100% pool; map aliases must not duplicate areas.
  local pools = {
    { key = "land", method = "WALK", first = 1, weights = { 20,20,10,10,10,10,5,5,4,4,1,1 } },
    { key = "water", method = "SURF", first = 1, weights = { 60,30,5,4,1 } },
    { key = "rocks", method = "ROCK SMASH", first = 1, weights = { 60,30,5,4,1 } },
    { key = "fishing", method = "OLD", first = 1, weights = { 70,30 } },
    { key = "fishing", method = "GOOD", first = 3, weights = { 60,20,20 } },
    { key = "fishing", method = "SUPER", first = 6, weights = { 40,40,15,4,1 } },
  }
  function Gen3:encounters(mapId)
    local source = self.game.data and self.game.data.gen3Encounters or {}
    local area, rows = source[mapId], {}
    if not self.data.maps[mapId] then return rows end
    for _, pool in ipairs(pools) do
      local encounter = area and area[pool.key]
      if encounter and (pool.key == "fishing" or (tonumber(encounter.rate) or 0) > 0) then
        local slots, count, total = encounter.slots or {}, #pool.weights, 100
        -- Host path [FRLG]: the native picker walks the actual slot list and
        -- gives added slots weight 1. Hoenn and rod windows use fixed indices.
        local variable = not self.hoenn and pool.key ~= "fishing"
        if variable then
          count, total = #slots, 0
          for index = 1, count do total = total + (pool.weights[index] or 1) end
        end
        local bySpecies = {}
        for index = 1, count do
          local chance = variable and (pool.weights[index] or 1) * 100 / total or pool.weights[index]
          local slot = slots[pool.first + index - 1]
          if slot and self.data.pokemon[slot.species] then
            local row = bySpecies[slot.species]
            if not row then
              row = { species = slot.species, mapId = mapId, method = pool.method,
                chance = 0, minLevel = slot.minLevel, maxLevel = slot.maxLevel }
              bySpecies[slot.species] = row
              rows[#rows + 1] = row
            end
            row.chance = row.chance + chance
            row.minLevel = math.min(row.minLevel, slot.minLevel)
            row.maxLevel = math.max(row.maxLevel, slot.maxLevel)
          end
        end
      end
    end
    return self.previewEncounters and self:previewEncounters(mapId, rows) or rows
  end
end
