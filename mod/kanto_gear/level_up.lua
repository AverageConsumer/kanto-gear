local LevelUp = {}
LevelUp.__index = LevelUp

local keys = { "hp", "attack", "defense", "speed", "special",
  "specialAttack", "specialDefense" }

function LevelUp.new()
  return setmetatable({ snapshots = setmetatable({}, { __mode = "k" }) }, LevelUp)
end

function LevelUp:observe(mon, screen)
  if type(mon) ~= "table" then return false end
  if type(mon.stats) ~= "table" then
    self.snapshots[mon] = nil
    return false
  end
  local old, stats = self.snapshots[mon], mon.stats
  local changed = not old or old.level ~= mon.level or old.species ~= mon.species
  if not changed then
    for _, key in ipairs(keys) do
      if old[key] ~= stats[key] then changed = true; break end
    end
  end
  if not changed then return false end

  local snapshot = { level = mon.level, species = mon.species }
  for _, key in ipairs(keys) do snapshot[key] = stats[key] end
  -- Compare actual stored stats, including accumulated stat experience. Do not
  -- reconstruct the old level with today's stat experience or battle modifiers.
  if old and old.species == mon.species and type(old.level) == "number"
      and type(mon.level) == "number" and mon.level > old.level then
    local gain = { from = old.level, to = mon.level, deltas = {} }
    for _, key in ipairs(keys) do
      if type(old[key]) == "number" and type(stats[key]) == "number" then
        gain.deltas[key] = stats[key] - old[key]
      end
    end
    -- Gen 2's Rare Candy uses the party menu's result instead of a stats box.
    -- Bind to that exact result so a later potion/refusal cannot reuse it.
    local result = screen and screen.screenId == "Gen2PartyMenu" and screen.itemResult
    if result and screen.party and screen.party[result.slot] == mon then
      gain.result = result
    end
    snapshot.gain = gain
  end
  self.snapshots[mon] = snapshot
  return snapshot.gain ~= nil
end

function LevelUp:scan(save, screen)
  if self.save ~= save then
    self.save = save
    self.snapshots = setmetatable({}, { __mode = "k" })
  end
  local changed = false
  for _, mon in ipairs(save and save.party or {}) do
    if self:observe(mon, screen) then changed = true end
  end
  return changed
end

function LevelUp:get(mon)
  local snapshot = self.snapshots[mon]
  return snapshot and snapshot.gain
end

function LevelUp:fieldMon(screen)
  local result = screen and screen.screenId == "Gen2PartyMenu" and screen.itemResult
  local mon = result and screen.party and screen.party[result.slot]
  local gain = mon and self:get(mon)
  if gain and gain.result == result then return mon end
end

return LevelUp
