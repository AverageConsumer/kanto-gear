-- Moments model: catalog, storage, battle bookkeeping and shiny moments.
local root = os.getenv("KANTO_GEAR_MOD_PATH") or "mod/kanto_gear"
local M = assert(loadfile(root .. "/features/moments.lua"))()
local passed, failed = 0, 0
local function check(condition, label)
  if condition then passed = passed + 1 else failed = failed + 1; io.stderr:write("FAIL " .. label .. "\n") end
end
local function ids(list)
  local out = {}
  for _, row in ipairs(list) do out[#out + 1] = type(row) == "table" and row.id or row end
  table.sort(out)
  return table.concat(out, ",")
end

-- Catalog
for _, entry in ipairs(M.CATALOG) do
  check(entry.title and entry.line and entry.glyph and entry.tone, "complete catalog entry: " .. entry.id)
end
check(M.available("first_shiny", true) and not M.available("first_shiny", false), "shiny moments need a shiny engine")
check(M.available("last_hp", false), "battle moments exist in every generation")
check(M.legendary("HO-OH") and M.legendary("Mewtwo") and not M.legendary("PIDGEY"), "legendary names normalize")

-- Storage: earned once, newest first, junk dropped, losses kept.
local s = M.normalize(nil)
check(#s.earned == 0 and not s.retro, "a new playthrough has no moments")
local a = M.award(s, "last_hp", { species = "CYNDAQUIL", name = "EMBER", place = "ROUTE 29" }, 100)
check(a and a.at == 100 and a.name == "EMBER", "a moment keeps who and where")
check(M.award(s, "last_hp", {}, 200) == nil, "each moment is earned once")
M.award(s, "marathon", {}, 300)
M.award(s, "rematch", {}, 300)
local list = M.list(s)
check(list[1].id == "rematch" and list[2].id == "marathon" and list[3].id == "last_hp", "newest first, ties by order")
check(M.award(s, "no_such", {}, 1) == nil, "unknown moments are refused")
s.lost["R:1:JOEY"] = true
local copy = M.normalize({ earned = { s.earned[1], { id = "bogus" }, s.earned[1], "x" }, lost = s.lost, retro = true,
  seq = 9 })
check(#copy.earned == 1 and copy.lost["R:1:JOEY"] and copy.retro and copy.seq == 9, "normalize drops junk and duplicates")

-- Battles
local function snap(player, enemy, extra)
  local out = { player = player, enemy = enemy }
  for k, v in pairs(extra or {}) do out[k] = v end
  return out
end
s = M.normalize(nil)
local f = M.newFight({ kind = "trainer", trainer = "R:1:JOEY", foe = "JOEY" })
M.fightSnapshot(f, snap({ species = "A", name = "ACE", level = 10, hp = 20 }, { species = "B", level = 30, hp = 40 },
  { turn = 3, party = { { species = "A", hp = 20 }, { species = "C", hp = 0 }, { species = "D", hp = 0 },
    { species = "E", isEgg = true, hp = 0 } } }))
check(f.underdog == nil, "no knock-out yet")
M.fightSnapshot(f, snap({ species = "A", name = "ACE", level = 10, hp = 1 }, { species = "B", level = 30, hp = 0 },
  { turn = 21 }))
check(f.underdog and f.underdog.gap == 20 and f.underdog.name == "ACE", "a knock-out 20 levels up is remembered")
local found = M.fightEnd(s, f, "win")
check(ids(found) == "last_hp,last_standing,marathon,underdog", "one battle can make several moments: " .. ids(found))
local standing
for _, row in ipairs(found) do if row.id == "last_standing" then standing = row end end
check(standing and standing.species == "A", "eggs do not count toward the party")

-- A loss is remembered; beating the same trainer later is a rematch.
s = M.normalize(nil)
f = M.newFight({ kind = "trainer", trainer = "R:2:FALKNER" })
check(#M.fightEnd(s, f, "whiteout") == 0 and s.lost["R:2:FALKNER"], "a loss is remembered")
f = M.newFight({ kind = "trainer", trainer = "R:2:FALKNER" })
M.fightSnapshot(f, snap({ species = "A", level = 20, hp = 30 }, { species = "B", level = 20, hp = 0 }))
check(ids(M.fightEnd(s, f, "win")) == "rematch" and not s.lost["R:2:FALKNER"], "the rematch is won once")
f = M.newFight({ kind = "wild" })
M.fightSnapshot(f, snap({ species = "A", level = 5, hp = 20 }, { species = "B", level = 40, hp = 10 }))
check(#M.fightEnd(s, f, "lose") == 0, "a lost battle makes no moment")
f = M.newFight({ kind = "wild" })
M.fightSnapshot(f, snap({ species = "A", level = 5, hp = 20 }, { species = "B", level = 40, hp = 10 }))
check(ids(M.fightEnd(s, f, "win")) == "underdog", "the last knock-out ends the battle before a snapshot shows it")
f = M.newFight({ kind = "wild" })
M.fightSnapshot(f, snap({ species = "A", level = 5, hp = 20 }, { species = "B", level = 40, hp = 10 }))
check(#M.fightEnd(s, f, "run") == 0, "running from a strong Pokemon is no underdog win")

-- Catches
f = M.newFight({ kind = "wild" })
M.fightSnapshot(f, { items = { { id = "POKE_BALL", ball = true, count = 1 }, { id = "POTION", count = 3 } } })
M.fightThrow(f)
M.fightSnapshot(f, { items = {} })
check(ids(M.caught(f, { species = "SUICUNE", name = "SUICUNE", ballsLeft = f.balls })) == "last_ball,legend_first_ball",
  "the last ball, and a legend with the first ball")
f = M.newFight({ kind = "wild" })
for _ = 1, 10 do M.fightThrow(f) end
check(ids(M.caught(f, { species = "ABRA", ballsLeft = 4 })) == "stubborn", "ten balls for one catch")
f = M.newFight({ kind = "wild" })
M.fightThrow(f)
check(#M.caught(f, { species = "ABRA", ballsLeft = 0 }) == 0, "no last ball without having seen the bag")
check(M.result("blackout") == "lose" and M.result("catch") == "caught" and M.result("win") == "win", "results normalize")

-- Shiny moments, live and from the log.
check(ids(M.fromShiny({ kind = "target", count = 1, first = true }, false)) == "first_shiny,shiny_first_try",
  "a first shiny on the first encounter")
check(ids(M.fromShiny({ kind = "target", count = 8192 }, false)) == "shiny_exact_odds", "exactly 1 in 8192")
check(#M.fromShiny({ kind = "lucky", count = 0 }, false) == 0, "a later lucky shiny is no new moment")
local retro = M.retroShiny({ { kind = "target", count = 8192, at = 50 }, { kind = "lucky", count = 0, at = 10 } })
check(#retro == 2 and retro[1].id == "first_shiny" and retro[1].entry.at == 10 and retro[2].id == "shiny_exact_odds",
  "the shiny log proves moments retroactively, oldest first")

-- Game packs
check(M.family(1, "yellow") == "kanto" and M.family(2, "crystal") == "johto" and M.family(3, "leafgreen") == "frlg"
  and M.family(3, "emerald") == "hoenn", "editions map to their family of games")
check(M.available("unown_alphabet", true, "johto") and not M.available("unown_alphabet", true, "kanto"),
  "a game pack stays in its own games")
check(M.available("gyarados_rise", false, "hoenn"), "some stories happen everywhere")
check(M.is("SPECIES_HO_OH", "HO-OH") and M.is("Snorlax", "SNORLAX"), "species names compare across engines")
f = M.newFight({ kind = "wild", species = "SNORLAX", foe = "SNORLAX" })
check(ids(M.fightEnd(M.normalize(nil), f, "win")) == "snorlax_awake", "the road-blocking Snorlax")
f = M.newFight({ kind = "wild" })
M.fightSnapshot(f, { enemy = { species = "SUDOWOODO", level = 20, hp = 5 }, player = { species = "A", level = 20, hp = 9 } })
check(ids(M.fightEnd(M.normalize(nil), f, "caught")) == "odd_tree", "the odd tree, from the snapshot")
f = M.newFight({ kind = "wild", species = "SNORLAX" })
check(#M.fightEnd(M.normalize(nil), f, "run") == 0, "running from Snorlax is no moment")
f = M.newFight({ kind = "wild", roamer = true })
M.fightSnapshot(f, { safariBalls = 20 })
check(ids(M.caught(f, { species = "FEEBAS", ballsLeft = 3 })) == "rarest_fish,roamer_caught,safari_catch",
  "safari, roamer and Feebas catches")
check(ids(M.evolved("MAGIKARP", "GYARADOS")) == "gyarados_rise", "Magikarp into Gyarados")
check(ids(M.evolved("SPECIES_NINCADA", "SPECIES_NINJASK", function(name) return name == "SHEDINJA" end))
  == "hollow_shell", "Nincada leaves a Shedinja behind")
check(#M.evolved("NINCADA", "NINJASK", function() return false end) == 0, "no Shedinja without room for it")
check(M.pokerus("contracted") and not M.pokerus("spread"), "only Pokerus from nowhere is a moment")

io.write(string.format("%d/%d checks passed  (Moments model)\n", passed, passed + failed))
if failed > 0 then os.exit(1) end
