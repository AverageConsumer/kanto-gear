-- Read models for the native Gen 3 engine. Never write presentation data back
-- to Game3.save: it is a serialization snapshot, not the running session.
return function(read)
  local Gen3 = {}
  Gen3.__index = Gen3
  local function copy(source)
    local out = {}
    for key, value in pairs(source or {}) do out[key] = value end
    return out
  end
  local function clear(t)
    for key in pairs(t) do t[key] = nil end
  end
  function Gen3.new(game)
    assert(game.generation == 3, "native Gen 3 game required")
    local self = setmetatable({ game = game, mons = setmetatable({}, { __mode = "k" }) }, Gen3)
    self.profile = require("src.core.game3.profile").forSession(game.session)
    -- Game path [Gen 3]: hoenn means Ruby/Sapphire/Emerald; rs excludes Emerald because its native menus differ.
    self.hoenn = self.profile.family == "rse"
    self.rs = self.profile.id == "ruby" or self.profile.id == "sapphire"
    local flags = require("src.core.game3.scripting.flags")
    -- Host path [Gen 3]: older flag APIs expose one table; newer hosts resolve the active edition explicitly.
    self.flagDefinitions = flags.forVersion and flags.forVersion(self.profile.id) or flags
    self.Pokemon = require("src.core.game3.pokemon")
    self.Moves = require("src.core.game3.battle.moves")
    self.Items = require("src.core.game3.items_data")
    self.Dex = require("src.core.game3.dex")
    self.Flags = require("src.core.game3.scripting.flags")
    self.Space = require("src.core.game3.scripting.space")
    self.FieldMoves = require("src.core.game3.field_moves")
    self.Summary = require("src.core.game3.summary_data")
    self.Types = require("src.core.game3.battle.types")
    self.Battle = require("src.core.game3.battle")
    self.BattleUI = require("src.core.game3.battle.ui")
    self.ExpSeq = require("src.core.game3.battle.exp_seq")
    self.Anim = require("src.core.game3.battle.anim")
    self.Field = require("src.core.game3.field")
    self.Warp = require("src.core.game3.warp")
    self.Runtime = require("src.core.game3.runtime")
    self.Message = require("src.ui.game3.message")
    self.Hud = require("src.ui.game3.hud")
    self.Font = require("src.ui.game3.frlg_font")
    self.TextIR = require("src.core.game3.scripting.text_ir")
    self.Choice = require("src.ui.game3.choice")
    self.typeNames = {}
    for name, id in pairs(self.Types.ID) do
      self.typeNames[id] = name
    end
    self:refreshDefinitions()
    self:refresh()
    return self
  end
  local function install(name, ...)
    local path = "adapters/gen3/models/" .. name .. ".lua"
    return assert(load(assert(read(path)), "@kanto_gear/" .. path))()(...)
  end
  install("graphics", Gen3)
  install("pokemon", Gen3, copy)
  install("state", Gen3, clear, copy)
  install("world", Gen3)
  install("game_view", Gen3, clear)
  install("battle", Gen3)
  return Gen3
end
