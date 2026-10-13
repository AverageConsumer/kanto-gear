-- Native Gen 3 route objectives. Read the imported event graph, never execute
-- scripts or infer victory/collection from an NPC simply being hidden.
return function(read)
  local M = {}
  M.__index = M
  local function copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
  end
  local function sortedKeys(t)
    local out = {}
    for k in pairs(t or {}) do out[#out + 1] = k end
    table.sort(out)
    return out
  end
  function M.new(adapter)
    local renewable, initiallyHidden = {}, {}
    local emerald = adapter.profile.id == "emerald"
    local hoenn = adapter.hoenn
    -- Game path [FireRed/LeafGreen]: initial hide flags and renewable hidden-item zones are Kanto data; Hoenn derives its initial flags from scripts.
    if not hoenn then
      for _, flag in ipairs(adapter.Flags.NEW_GAME_HIDE_FLAGS or {}) do initiallyHidden[flag] = true end
    end
    for _, zone in ipairs(not hoenn and require("src.core.game3.renewable_hidden_items").ZONES or {}) do
      for _, tier in ipairs({ "rare", "uncommon", "common" }) do
        for _, flag in ipairs(zone[tier]) do renewable[flag] = true end
      end
    end
    return setmetatable({ adapter = adapter, maps = {}, renewable = renewable, initiallyHidden = initiallyHidden,
      emerald = emerald, hoenn = hoenn, rs = adapter.rs,
      constants = hoenn and require("src.core.game3.constants").of(adapter.profile.id),
      Trainers = require("src.core.game3.scripting.trainers"), builds = 0 }, M)
  end
  -- A read-only path check for native Pokemon rewards. VAR_RESULT matters: a full
  -- party may send a gift to the PC, while a failed delivery must never earn a stamp.
  local giftPresentation = {}
  for op in ("lock lockall release releaseall faceplayer showmonpic hidemonpic applymovement waitmovement "
      .. "removeobject showmoneybox hidemoneybox updatemoneybox showcoinsbox hidecoinsbox updatecoinsbox playfanfare waitfanfare message "
      .. "waitmessage loadword fadescreen waitstate textcolor bufferspeciesname bufferboxname"):gmatch("%S+") do
    giftPresentation[op] = true
  end
  local function install(name, ...)
    local path = "adapters/gen3/progress/" .. name .. ".lua"
    return assert(load(assert(read(path)), "@kanto_gear/" .. path))()(...)
  end
  local reaches = install("rewards", M, sortedKeys)
  local pokemonPath = install("pokemon", M, copy, giftPresentation, reaches, sortedKeys)
  local rules = install("policies")
  install("catalog", M, sortedKeys, rules)
  install("completion", M, copy, pokemonPath, reaches, sortedKeys)
  return M
end
