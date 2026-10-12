local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local adapter = display.gen3
  local Schema = require("src.core.game3.save_schema_firered")
  local Json = require("src.import.canonical_json")
  local session = Schema.newGame({ version = os.getenv("POKEPORT_VERSION"), name = "BAG", rngSeed = 1234 })
  game.session = session
  local Items = adapter.Items
  session.bag.pockets = {}
  for _, pocket in ipairs(Items.POCKET_ORDER) do session.bag.pockets[pocket] = {} end
  session.bag.pockets[Items.POCKET_ORDER[1]] = {
    { id = 4, qty = 10 }, { id = "4", qty = "3" }, { id = "FRLG_4", qty = 2 },
    { id = 13, qty = 1 }, { id = "FRLG_13", qty = 0 }, { id = 14, qty = -2 },
    { id = "not-an-item", qty = 5 }, { id = 15, qty = "invalid" },
  }
  local function check()
    local before = Json.encode(session)
    adapter:refresh()
    T.eq(Json.encode(session), before, "inventory projection never sanitizes or mutates native data")
    local expected, order = {}, {}
    for _, pocket in ipairs(Items.POCKET_ORDER) do
      for _, slot in ipairs(session.bag and session.bag.pockets[pocket] or {}) do
        local id, qty = Items.toNumericId(slot.id), tonumber(slot.qty) or 0
        if id and qty > 0 then
          if expected[id] == nil then order[#order + 1] = id end
          expected[id] = (expected[id] or 0) + qty
        end
      end
    end
    T.eq(Json.encode(adapter.save.inventory), Json.encode(expected), "mixed aliases and duplicate stacks retain native totals")
    T.eq(Json.encode(adapter.save.bagOrder), Json.encode(order), "pocket order and first occurrence remain authoritative")
    T.eq(adapter.save.inventory.FRLG_4, expected[4], "public alias access remains available")
  end
  check()
  T.eq(adapter.save.inventory[4], 15, "numeric, string and prefixed IDs combine")
  session.bag.pockets[Items.POCKET_ORDER[1]][1].qty = 1
  check()
  session.bag.pockets[Items.POCKET_ORDER[1]] = { { id = 13, qty = 9 }, { id = 4, qty = 2 } }
  check()
  local normalize, calls = Items.toNumericId, 0
  Items.toNumericId = function(id) calls = calls + 1; return normalize(id) end
  adapter:refresh()
  T.eq(calls, 2, "each native stack is normalized exactly once")
  for _ = 1, 200 do adapter:refresh() end
  T.eq(calls, 2, "unchanged numeric pockets skip repeated normalization")
  session.bag.pockets[Items.POCKET_ORDER[1]][1].qty = 8
  adapter:refresh()
  T.eq(adapter.save.inventory[13], 8, "in-place consumption updates on the same poll")
  T.eq(calls, 4, "changed pockets rebuild through the native reader")
  session.bag.pockets[Items.POCKET_ORDER[1]][1].id = 14
  adapter:refresh()
  T.eq(adapter.save.inventory[13], nil, "same-size item replacement clears its old ID")
  T.eq(adapter.save.inventory[14], 8, "same-size replacement keeps its quantity")
  local slots = session.bag.pockets[Items.POCKET_ORDER[1]]
  slots[1], slots[2] = slots[2], slots[1]
  adapter:refresh()
  T.eq(adapter.save.bagOrder[1], 4, "in-place pocket reordering updates immediately")
  Items.toNumericId = normalize
  local mapped = 13
  slots[1].id = "CUSTOM_ALIAS"
  Items.toNumericId = function(id)
    return id == "CUSTOM_ALIAS" and mapped or normalize(id)
  end
  adapter:refresh()
  T.eq(adapter.save.inventory[13], 2, "named custom IDs use the native reader")
  mapped = 15
  adapter:refresh()
  T.eq(adapter.save.inventory[13], nil, "named aliases can change without replacing their reader")
  T.eq(adapter.save.inventory[15], 2, "remapped aliases are detected on the same poll")
  Items.toNumericId = normalize
  session.bag.pockets = {}
  check()
  T.eq(next(adapter.save.inventory), nil, "removed stacks clear immediately")
  T.eq(#adapter.save.bagOrder, 0, "empty bag clears the old order")
  session.bag = nil
  check()
  local replacement = Schema.newGame({ version = os.getenv("POKEPORT_VERSION"), name = "NEW", rngSeed = 987 })
  game.session = replacement
  adapter:refresh()
  T.eq(next(adapter.save.inventory), nil, "a new session never inherits the old bag")

  local party = require("src.core.game3.party")
  party.giveMon(replacement, 1, 10)
  local source = replacement.party[1]
  adapter:refresh()
  local view = adapter.save.party[1]
  local nativeTypes = adapter.Pokemon.types
  local oldNames = { adapter.typeNames[10], adapter.typeNames[11] }
  adapter.typeNames[10], adapter.typeNames[11] = "FIRE", "WATER"
  adapter.Pokemon.types = function() return { 10, 11 } end
  replacement.playtime = { hours = 1, minutes = 2, seconds = 3, extra = 4 }
  source.hp, source.status = 5, 0x08
  adapter:refresh()
  T.same(view.types, { "FIRE", "WATER" }, "type changes still read native data")
  T.eq(view.status, "PSN", "status remains live")
  local types, playTime = view.types, adapter.save.playTime
  T.eq(playTime.extra, 4, "playtime copies all native fields")
  adapter.Pokemon.types = function() return { 11, 11 } end
  replacement.playtime.extra = nil
  source.hp, source.status = 0, 0
  adapter:refresh()
  T.same(view.types, { "WATER" }, "single-type changes remove the previous second type")
  T.same(types, { "FIRE", "WATER" }, "earlier presentation snapshots retain their original types")
  T.eq(view.status, "FNT", "fainting overrides status on the same poll")
  T.eq(adapter.save.playTime.extra, nil, "removed native playtime fields do not remain cached")
  T.eq(playTime.extra, 4, "earlier playtime snapshots remain immutable")
  adapter.Pokemon.types = nativeTypes
  adapter.typeNames[10], adapter.typeNames[11] = unpack(oldNames)
end
dofile(path .. "/tests/gen3_fixture.lua")
