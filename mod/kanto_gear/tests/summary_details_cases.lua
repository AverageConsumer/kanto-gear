return function(T, Details, generation, native)
  local mon = { happiness = 0, friendship = 0, dvs = { attack = 15, defense = 14, speed = 13, special = 12 },
    statExp = { hp = 65535, attack = 0, defense = 100, speed = 200, special = 300 },
    ivs = { hp = 31, atk = 31, def = 31, spe = 31, spa = 31, spd = 31 },
    evs = { hp = 252, atk = 252, def = 0, spe = 6, spa = 0, spd = 0 } }
  local result = Details.read(mon, generation)
  if generation == 1 then T.eq(result.friendship,nil,"Gen 1 has no per-partner friendship")
  else T.eq(result.friendship,0,"zero friendship is retained") end
  T.eq(result.total, generation == 3 and 510 or nil, "only Gen 3 has the EV total")
  T.eq(result.rows[1].gene, generation == 3 and 31 or 10, "HP DV is derived from its actual low bits")
  T.eq(result.rows[1].effort, generation == 3 and 252 or 65535, "training is raw EV or stat EXP, never confused")
  T.eq(Details.read({}, generation).power, nil, "missing genes never invent a Hidden Power")
  T.eq(Details.read({}, generation).rows[1].effort, nil, "missing training is unknown, not zero")
  if generation == 2 then
    local Battle = require("src.battle.gen2.Battle")
    for a = 0, 15 do for d = 0, 15 do for s = 0, 15 do for p = 0, 15 do
      local source = { dvs = { attack = a, defense = d, speed = s, special = p } }
      local expectedPower, expectedType = Battle.hiddenPower(nil, source)
      local got = Details.read(source, 2)
      T.eq(got.power, expectedPower, "all Gen 2 DV combinations match battle power")
      T.eq(got.type, expectedType, "all Gen 2 DV combinations match battle type")
    end end end end
    local Breeding = require("src.core.gen2.Breeding")
    for _, cycles in ipairs({ 1, 2, 20 }) do
      for _, phase in ipairs({ 0, 127, 128, 254, 255 }) do
        local egg = { species = "FIXMON_A", isEgg = true, eggSteps = cycles }
        local save = { party = { egg }, stepCount = phase }
        local estimate = Details.egg(egg, 2, save)
        T.eq(save.stepCount, phase, "inspection never advances the step counter")
        T.eq(egg.eggSteps, cycles, "inspection never consumes hatch cycles")
        local steps = 0
        repeat steps = steps + 1 until Breeding.step({}, save) == "hatch"
        T.eq(estimate.steps, steps, "Gen 2 estimate matches actual hatching at each step phase")
      end
    end
    T.eq(Details.egg({ isEgg = true, eggSteps = 0 }, 2, {}).steps, 0, "ready Gen 2 egg needs no more steps")
  elseif generation == 3 then
    local Damage = require("src.core.game3.battle.damage")
    local types = { [1] = "FIGHTING", [2] = "FLYING", [3] = "POISON", [4] = "GROUND", [5] = "ROCK",
      [6] = "BUG", [7] = "GHOST", [8] = "STEEL", [10] = "FIRE", [11] = "WATER", [12] = "GRASS",
      [13] = "ELECTRIC", [14] = "PSYCHIC_TYPE", [15] = "ICE", [16] = "DRAGON", [17] = "DARK" }
    for low = 0, 63 do for high = 0, 63 do
      local source = { ivs = {} }
      for i, key in ipairs({ "hp", "atk", "def", "spe", "spa", "spd" }) do
        source.ivs[key] = 28 + math.floor(low / 2 ^ (i - 1)) % 2 + 2 * (math.floor(high / 2 ^ (i - 1)) % 2)
      end
      local expectedPower, expectedType = Damage.hiddenPower(source)
      local got = Details.read(source, 3)
      T.eq(got.power, expectedPower, "all Hidden Power bit patterns match Gen 3 battle power")
      T.eq(got.type, types[expectedType], "all Hidden Power bit patterns match Gen 3 battle type")
    end end
    local context = { profile = native.profile, session = { version = native.session.version, party = {}, daycare = { stepCounter = 254 } } }
    local egg = { isEgg = true, friendship = 3, eggCycles = 20 }
    T.eq(Details.egg(egg, 3, {}, context).steps, 769, "live friendship counter wins over stale eggCycles")
    T.eq(Details.egg({ isEgg = true, friendship = 0 }, 3, {}, context).steps, 1,
      "Gen 3 hatches on the tick after its cycles reach zero")
    context.session.daycare.stepCounter = 255
    T.eq(Details.egg(egg, 3, {}, context).steps, 1024, "a completed tick waits for the next cycle")
    context.session.daycare.stepCounter = 254
    if native.profile.id == "emerald" then
      local Constants = require("src.core.game3.constants")
      local C = Constants.of(Constants.versionOf(context.session))
      context.session.party = { { species = 1, ability = C:require("abilities", "ABILITY_FLAME_BODY") } }
      T.eq(Details.egg(egg, 3, {}, context).steps, 513, "Emerald Flame Body shortens the estimate")
      context.session.party[1].isEgg = true
      T.eq(Details.egg(egg, 3, {}, context).steps, 769, "an egg cannot supply a hatching ability")
    end
    T.eq(context.session.daycare.stepCounter, 254, "Gen 3 inspection never advances the native counter")
    T.eq(egg.friendship, 3, "Gen 3 inspection never modifies the egg")
    T.eq(Details.egg({ isEgg = true, isBadEgg = true, friendship = 3 }, 3, {}, context).steps, nil,
      "Bad Eggs do not get a false hatching promise")
  end
  T.eq(Details.egg({ isEgg = true }, generation, {}).steps, nil, "missing hatch data stays unknown")
  T.eq(Details.egg(mon, generation, {}), nil, "ordinary friendship is never treated as hatch cycles")
end
