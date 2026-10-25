-- Moments: small stories from a playthrough, kept in the Stamp Book. Each
-- moment is earned once, remembers who, where and when, and is invisible
-- until then (no totals, nothing to grind). Pure catalog, storage shape and
-- battle bookkeeping; the runtime feeds it events and draws the result.
local M = {}

M.VERSION = 1
M.LIMIT = 240

-- glyph names are drawn by the Moments UI; tone picks the seal colour.
-- gens = nil means every generation; shiny moments need a shiny engine.
M.CATALOG = {
  { id = "first_shiny", title = "FIRST SHINY", line = "YOUR VERY FIRST SHINY POKEMON",
    glyph = "sparkle", tone = "gold", shiny = true },
  { id = "shiny_first_try", title = "FIRST TRY", line = "A SHINY ON THE FIRST ENCOUNTER OF A HUNT",
    glyph = "one", tone = "gold", shiny = true },
  { id = "shiny_exact_odds", title = "EXACTLY 1 IN 8192", line = "THE SHINY CAME ON ENCOUNTER 8192",
    glyph = "target", tone = "gold", shiny = true },
  { id = "last_hp", title = "HANGING BY A THREAD", line = "WON A BATTLE WITH 1 HP LEFT",
    glyph = "heart", tone = "red" },
  { id = "last_standing", title = "LAST ONE STANDING", line = "WON A TRAINER BATTLE WITH ONE POKEMON LEFT",
    glyph = "shield", tone = "red" },
  { id = "underdog", title = "UNDERDOG", line = "KNOCKED OUT A POKEMON 10 LEVELS ABOVE YOURS",
    glyph = "arrow", tone = "green" },
  { id = "rematch", title = "REMATCH WON", line = "BEAT A TRAINER WHO ONCE BEAT YOU",
    glyph = "swap", tone = "green" },
  { id = "marathon", title = "MARATHON BATTLE", line = "WON A BATTLE THAT LASTED 20 TURNS",
    glyph = "hourglass", tone = "green" },
  { id = "last_ball", title = "THE LAST BALL", line = "CAUGHT A POKEMON WITH YOUR LAST BALL",
    glyph = "ball", tone = "blue" },
  { id = "legend_first_ball", title = "LEGEND IN ONE", line = "CAUGHT A LEGENDARY POKEMON WITH THE FIRST BALL",
    glyph = "crown", tone = "gold" },
  { id = "stubborn", title = "STUBBORN ONE", line = "NEEDED 10 BALLS OR MORE FOR ONE CATCH",
    glyph = "dice", tone = "blue" },
  -- Game packs: each family of games has its own small stories. games lists
  -- the families (kanto: Red/Blue/Yellow, johto: Gold/Silver/Crystal,
  -- frlg: FireRed/LeafGreen, hoenn: Ruby/Sapphire/Emerald).
  { id = "gyarados_rise", title = "FROM CARP TO DRAGON", line = "A MAGIKARP EVOLVED INTO GYARADOS",
    glyph = "wave", tone = "blue" },
  { id = "snorlax_awake", title = "THE SLEEPER WAKES", line = "FACED THE SNORLAX THAT BLOCKED THE ROAD",
    glyph = "zzz", tone = "blue", games = { kanto = true, johto = true, frlg = true } },
  { id = "safari_catch", title = "SAFARI CATCH", line = "CAUGHT A POKEMON IN THE SAFARI ZONE",
    glyph = "ball", tone = "green", games = { kanto = true, frlg = true, hoenn = true } },
  { id = "tower_ghost", title = "THE TOWER GHOST", line = "MET THE GHOST OF POKEMON TOWER",
    glyph = "ghost", tone = "purple", games = { kanto = true } },
  { id = "red_gyarados", title = "THE RED GYARADOS", line = "MET THE RED GYARADOS OF THE LAKE",
    glyph = "sparkle", tone = "red", games = { johto = true } },
  { id = "odd_tree", title = "THE ODD TREE", line = "THE TREE IN YOUR WAY WAS A POKEMON",
    glyph = "tree", tone = "green", games = { johto = true, hoenn = true } },
  { id = "bug_champion", title = "BUG-CATCHING CHAMPION", line = "WON THE BUG-CATCHING CONTEST",
    glyph = "trophy", tone = "gold", games = { johto = true } },
  { id = "unown_alphabet", title = "THE WHOLE ALPHABET", line = "FOUND ALL 26 UNOWN FORMS",
    glyph = "letter", tone = "gold", games = { johto = true } },
  { id = "roamer_caught", title = "CAUGHT AT LAST", line = "CAUGHT A ROAMING POKEMON",
    glyph = "bolt", tone = "gold", games = { johto = true, frlg = true, hoenn = true } },
  { id = "first_hatch", title = "FIRST HATCH", line = "AN EGG HATCHED IN YOUR HANDS",
    glyph = "egg", tone = "green", games = { johto = true, frlg = true, hoenn = true } },
  { id = "pokerus", title = "A LUCKY VIRUS", line = "YOUR POKEMON CAUGHT POKERUS",
    glyph = "virus", tone = "purple", games = { johto = true, frlg = true, hoenn = true } },
  { id = "hollow_shell", title = "THE HOLLOW SHELL", line = "A SHEDINJA APPEARED AS NINCADA EVOLVED",
    glyph = "ghost", tone = "purple", games = { hoenn = true } },
  { id = "rarest_fish", title = "THE RAREST FISH", line = "CAUGHT A FEEBAS",
    glyph = "fish", tone = "blue", games = { hoenn = true } },
}
M.byId = {}
for index, entry in ipairs(M.CATALOG) do entry.order = index; M.byId[entry.id] = entry end

M.THRESHOLDS = { gap = 10, turns = 20, throws = 10, party = 3 }

local LEGENDS = {}
for name in ([[ARTICUNO ZAPDOS MOLTRES MEWTWO MEW RAIKOU ENTEI SUICUNE LUGIA HOOH CELEBI
    REGIROCK REGICE REGISTEEL LATIAS LATIOS KYOGRE GROUDON RAYQUAZA JIRACHI DEOXYS]]):gmatch("%S+") do
  LEGENDS[name] = true
end

-- Species names from every engine ("HO-OH", "SPECIES_HO_OH", "Ho-Oh").
local function key(value)
  return (tostring(value or ""):upper():gsub("^SPECIES_", ""):gsub("[^%w]", ""))
end
M.key = key
function M.legendary(name) return LEGENDS[key(name)] == true end
function M.is(name, species) return name ~= nil and key(name) == key(species) end

-- The family of games a version belongs to.
function M.family(generation, edition)
  edition = tostring(edition or ""):lower()
  if generation == 3 then
    return (edition == "firered" or edition == "leafgreen") and "frlg" or "hoenn"
  end
  return generation == 2 and "johto" or "kanto"
end

-- Whether a moment can happen in this game at all.
function M.available(entry, shiny, family)
  entry = type(entry) == "table" and entry or M.byId[entry]
  if not entry then return false end
  if entry.shiny and not shiny then return false end
  if entry.games and family and not entry.games[family] then return false end
  return true
end

------------------------------------------------------------------------------
-- Storage
------------------------------------------------------------------------------
local function int(value, fallback)
  value = tonumber(value)
  if not value or value ~= value then return fallback end
  return math.floor(value)
end

local function text(value)
  return type(value) == "string" and value ~= "" and value or nil
end

local function cleanRecord(raw)
  if type(raw) ~= "table" or not M.byId[raw.id] then return nil end
  local species = raw.species
  if type(species) ~= "string" and type(species) ~= "number" then species = nil end
  return { id = raw.id, at = int(raw.at, 0), play = int(raw.play, nil), seq = int(raw.seq, 0),
    place = text(raw.place), species = species, name = text(raw.name), shiny = raw.shiny == true or nil,
    foe = text(raw.foe), retro = raw.retro == true or nil }
end

function M.normalize(value)
  local state = { version = M.VERSION, earned = {}, lost = {}, retro = false, seq = 0 }
  if type(value) ~= "table" then return state end
  local seen = {}
  for _, raw in ipairs(type(value.earned) == "table" and value.earned or {}) do
    local record = cleanRecord(raw)
    if record and not seen[record.id] then
      seen[record.id] = true
      state.earned[#state.earned + 1] = record
      state.seq = math.max(state.seq, record.seq)
    end
  end
  local count = 0
  for trainer, flag in pairs(type(value.lost) == "table" and value.lost or {}) do
    if type(trainer) == "string" and flag == true and count < M.LIMIT then
      state.lost[trainer], count = true, count + 1
    end
  end
  state.retro = value.retro == true
  state.seq = math.max(state.seq, int(value.seq, 0))
  return state
end

function M.has(state, id)
  for _, record in ipairs(state.earned) do if record.id == id then return record end end
  return nil
end

-- Returns the new record, or nil when the moment was already earned.
function M.award(state, id, info, now)
  if not M.byId[id] or M.has(state, id) then return nil end
  info = info or {}
  state.seq = (state.seq or 0) + 1
  local record = cleanRecord({ id = id, at = info.at or now, play = info.play, seq = state.seq,
    place = info.place, species = info.species, name = info.name, shiny = info.shiny,
    foe = info.foe, retro = info.retro })
  state.earned[#state.earned + 1] = record
  return record
end

-- Newest first: the chronicle of a playthrough.
function M.list(state)
  local out = {}
  for _, record in ipairs(state.earned) do out[#out + 1] = record end
  table.sort(out, function(a, b)
    if a.at ~= b.at then return a.at > b.at end
    return a.seq > b.seq
  end)
  return out
end

function M.loss(state, trainer)
  if not trainer then return end
  local count = 0
  for _ in pairs(state.lost) do count = count + 1 end
  if count < M.LIMIT then state.lost[trainer] = true end
end

------------------------------------------------------------------------------
-- Shiny moments: from one shiny log entry, or retroactively from the log.
------------------------------------------------------------------------------
function M.fromShiny(entry, first)
  local out = {}
  if type(entry) ~= "table" then return out end
  if first or entry.first then out[#out + 1] = "first_shiny" end
  if entry.kind == "target" and entry.count == 1 then out[#out + 1] = "shiny_first_try" end
  if entry.kind == "target" and entry.count == 8192 then out[#out + 1] = "shiny_exact_odds" end
  return out
end

-- Every moment the shiny log still proves, oldest first, with its own date.
function M.retroShiny(log)
  local entries = {}
  for _, entry in ipairs(type(log) == "table" and log or {}) do
    if type(entry) == "table" then entries[#entries + 1] = entry end
  end
  table.sort(entries, function(a, b) return (a.at or 0) < (b.at or 0) end)
  local out = {}
  for index, entry in ipairs(entries) do
    for _, id in ipairs(M.fromShiny(entry, index == 1)) do
      out[#out + 1] = { id = id, entry = entry }
    end
  end
  return out
end

------------------------------------------------------------------------------
-- Battle bookkeeping
------------------------------------------------------------------------------
function M.result(value)
  value = tostring(value or ""):lower()
  if value == "win" or value == "won" then return "win" end
  if value == "lose" or value == "lost" or value == "whiteout" or value == "blackout" then return "lose" end
  if value == "caught" or value == "catch" then return "caught" end
  return value
end

-- info = { kind, trainer (key), foe }
function M.newFight(info)
  info = info or {}
  return { kind = info.kind or "wild", trainer = info.trainer, foe = info.foe, species = info.species,
    roamer = info.roamer, safari = info.kind == "safari" or nil,
    turns = 0, throws = 0, balls = nil, sawBalls = false, underdog = nil }
end

local function alive(mon) return type(mon) == "table" and (tonumber(mon.hp) or 0) > 0 end
local function egg(mon) return type(mon) == "table" and (mon.isEgg == true or mon.egg == true) end

local function copyMon(mon)
  if type(mon) ~= "table" then return nil end
  return { species = mon.species, name = mon.nickname or mon.name, hp = tonumber(mon.hp),
    level = tonumber(mon.level), shiny = mon.shiny == true or nil }
end

-- A battle snapshot: turns, balls in the bag, the party and knock-outs.
function M.fightSnapshot(fight, snap)
  if not fight or type(snap) ~= "table" then return end
  fight.turns = math.max(fight.turns, int(snap.turn, 0) or 0)
  if snap.kind == "safari" or snap.safariBalls ~= nil then fight.safari = true end
  if fight.species == nil and fight.kind ~= "trainer" and type(snap.enemy) == "table" then
    fight.species = snap.enemy.species
  end
  if type(snap.items) == "table" then
    local balls, any = 0, false
    for _, item in ipairs(snap.items) do
      if type(item) == "table" and item.ball then
        any = true
        balls = balls + math.max(0, int(item.count, 0) or 0)
      end
    end
    if any and balls > 0 then fight.sawBalls = true end
    fight.balls = balls
  end
  local player, enemy = copyMon(snap.player), copyMon(snap.enemy)
  local before = fight.enemy
  -- The foe was standing in the last snapshot and is down now, while the
  -- Pokemon that did it is still up: who knocked out whom, and the levels.
  if before and enemy and before.species == enemy.species and before.level == enemy.level
      and (before.hp or 0) > 0 and (enemy.hp or 1) <= 0 and player and (player.hp or 0) > 0
      and player.level and enemy.level and enemy.level - player.level >= M.THRESHOLDS.gap then
    if not fight.underdog or enemy.level - player.level > fight.underdog.gap then
      fight.underdog = { gap = enemy.level - player.level, species = player.species, name = player.name,
        foe = enemy.name or enemy.species, shiny = player.shiny }
    end
  end
  if player then fight.player = player end
  if enemy then fight.enemy = enemy end
  if type(snap.party) == "table" then
    local party = {}
    for _, mon in ipairs(snap.party) do
      if type(mon) == "table" and not egg(mon) then party[#party + 1] = copyMon(mon) end
    end
    fight.party = party
  end
end

function M.fightThrow(fight)
  if fight then fight.throws = fight.throws + 1 end
end

local function hero(fight)
  local mon = fight.player
  if not mon then return {} end
  return { species = mon.species, name = mon.name, shiny = mon.shiny }
end

-- The end of a battle: which moments it made. Losses are remembered so a
-- later win against the same trainer reads as a rematch.
function M.fightEnd(state, fight, result)
  local out = {}
  if not fight then return out end
  result = M.result(result)
  local trainer = fight.kind == "trainer" and fight.trainer or nil
  if result == "lose" then
    M.loss(state, trainer)
    return out
  end
  -- The last knock-out ends the battle before a snapshot can show it.
  local player, enemy = fight.player, fight.enemy
  if not fight.underdog and result == "win" and player and enemy and player.level and enemy.level
      and (player.hp or 0) > 0 and enemy.level - player.level >= M.THRESHOLDS.gap then
    fight.underdog = { gap = enemy.level - player.level, species = player.species, name = player.name,
      foe = enemy.name or enemy.species, shiny = player.shiny }
  end
  if fight.underdog and (result == "win" or result == "caught" or result == "run") then
    local u = fight.underdog
    out[#out + 1] = { id = "underdog", species = u.species, name = u.name, shiny = u.shiny, foe = u.foe }
  end
  -- Game packs: the famous wild Pokemon that stand in the way.
  if fight.kind ~= "trainer" and (result == "win" or result == "caught") then
    local foe = { species = fight.species, name = fight.foe }
    if M.is(fight.species, "SNORLAX") then
      out[#out + 1] = { id = "snorlax_awake", species = foe.species, name = foe.name }
    elseif M.is(fight.species, "SUDOWOODO") then
      out[#out + 1] = { id = "odd_tree", species = foe.species, name = foe.name }
    end
  end
  if result ~= "win" then return out end
  local me = hero(fight)
  if fight.player and fight.player.hp == 1 then
    out[#out + 1] = { id = "last_hp", species = me.species, name = me.name, shiny = me.shiny, foe = fight.foe }
  end
  if fight.kind == "trainer" and fight.party and #fight.party >= M.THRESHOLDS.party then
    local standing, survivor = 0, nil
    for _, mon in ipairs(fight.party) do
      if alive(mon) then standing, survivor = standing + 1, mon end
    end
    if standing == 1 then
      out[#out + 1] = { id = "last_standing", species = survivor.species, name = survivor.name,
        shiny = survivor.shiny, foe = fight.foe }
    end
  end
  if trainer and state.lost[trainer] then
    state.lost[trainer] = nil
    out[#out + 1] = { id = "rematch", species = me.species, name = me.name, shiny = me.shiny, foe = fight.foe }
  end
  if fight.turns >= M.THRESHOLDS.turns then
    out[#out + 1] = { id = "marathon", species = me.species, name = me.name, shiny = me.shiny, foe = fight.foe }
  end
  return out
end

-- A catch: ballsLeft is what the bag holds after it (nil when unknown).
function M.caught(fight, catch)
  local out = {}
  if not fight or type(catch) ~= "table" then return out end
  local who = { species = catch.species, name = catch.name, shiny = catch.shiny }
  local function add(id)
    out[#out + 1] = { id = id, species = who.species, name = who.name, shiny = who.shiny }
  end
  local throws = math.max(fight.throws, 1)
  if fight.kind == "wild" and fight.sawBalls and catch.ballsLeft == 0 then add("last_ball") end
  if throws == 1 and M.legendary(catch.name or catch.species) then add("legend_first_ball") end
  if throws >= M.THRESHOLDS.throws then add("stubborn") end
  if fight.safari then add("safari_catch") end
  if fight.roamer then add("roamer_caught") end
  if M.is(catch.species, "FEEBAS") or M.is(catch.name, "FEEBAS") then add("rarest_fish") end
  return out
end

------------------------------------------------------------------------------
-- Game-pack events outside battle
------------------------------------------------------------------------------
-- An evolution: Magikarp into Gyarados; Nincada leaving a Shedinja behind
-- (partyHas tells whether the party holds one).
function M.evolved(from, to, partyHas)
  local out = {}
  if M.is(from, "MAGIKARP") and M.is(to, "GYARADOS") then
    out[#out + 1] = { id = "gyarados_rise", species = to }
  end
  if M.is(from, "NINCADA") and partyHas and partyHas("SHEDINJA") then
    out[#out + 1] = { id = "hollow_shell", species = "SHEDINJA" }
  end
  return out
end

-- Pokerus from nowhere (3 in 65536), not passed along by a party neighbour.
function M.pokerus(source) return source ~= "spread" end

return M
