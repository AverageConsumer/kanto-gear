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
      for _, slot in ipairs(session.bag.pockets[pocket] or {}) do
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
  Items.toNumericId = normalize
  T.eq(calls, 2, "each native stack is normalized exactly once")
  session.bag.pockets = {}
  check()
  T.eq(next(adapter.save.inventory), nil, "removed stacks clear immediately")
  T.eq(#adapter.save.bagOrder, 0, "empty bag clears the old order")
end
dofile(path .. "/tests/gen3_fixture.lua")
