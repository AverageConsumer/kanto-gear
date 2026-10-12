-- Exercise the adapter inside the real mod sandbox, with the native Dex readers.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local adapter = display.gen3
  local Schema = require("src.core.game3.save_schema_firered")
  local Json = require("src.import.canonical_json")
  local session = Schema.newGame({ version = os.getenv("POKEPORT_VERSION"), name = "CACHE", rngSeed = 456 })
  game.session = session
  require("src.core.game3.runtime").session = session
  local Dex = adapter.Dex
  local isSeen, isCaught = Dex.isSeen, Dex.isCaught
  local reads = 0
  Dex.isSeen = function(...) reads = reads + 1; return isSeen(...) end
  Dex.isCaught = function(...) reads = reads + 1; return isCaught(...) end
  local function refresh()
    local before = Json.encode(session)
    adapter:refresh()
    T.eq(Json.encode(session), before, "projection never changes the native session")
    for id in pairs(adapter.data.pokemon) do
      T.eq(adapter.save.pokedex.seen[id], isSeen(session.dex, id) or nil, "cached seen matches native reader")
      T.eq(adapter.save.pokedex.caught[id], isCaught(session.dex, id) or nil, "cached caught matches native reader")
    end
  end
  refresh()
  local revision = adapter.dexRevision
  reads = 0
  for i = 1, 200 do adapter:refresh() end
  T.eq(reads, 0, "unchanged polls skip all 772 native Dex queries")
  T.eq(adapter.dexRevision, revision, "unchanged state preserves downstream caches")

  Dex.setSeen(session.dex, 1); refresh()
  T.eq(adapter.dexRevision, revision + 1, "in-place encounter invalidates immediately")
  Dex.setCaught(session.dex, 410); refresh()
  T.check(adapter.save.pokedex.caught[410] and not adapter.save.pokedex.caught[386],
    "capture preserves native internal species IDs")
  session.dex.seen[1], session.dex.seen[2] = nil, true
  refresh()
  T.check(not adapter.save.pokedex.seen[1] and adapter.save.pokedex.seen[2],
    "same-size flag replacement cannot hide a change")
  session.dex.caught[410], session.dex.owned[410], session.dex.seen[410] = nil, nil, nil
  refresh()
  T.check(not adapter.save.pokedex.caught[410], "removed flags clear stale catches")

  session.dex.seen = { [3] = 1, [4] = 0, [5] = false, [6] = "yes" }
  session.dex.caught, session.dex.owned = { [7] = false, [8] = 0 }, { [7] = 1 }
  refresh()
  T.check(adapter.save.pokedex.seen[3] and not adapter.save.pokedex.seen[4]
    and adapter.save.pokedex.seen[6] and adapter.save.pokedex.caught[7],
    "native truthy/zero flags and separate owned table stay authoritative")
  session.dex.owned[7] = nil; refresh()
  T.check(not adapter.save.pokedex.caught[7], "owned-only removal is detected")
  session.dex.owned = session.dex.caught
  session.dex.owned[9] = true; refresh()
  T.check(adapter.save.pokedex.caught[9], "caught/owned aliases remain supported")
  revision, reads = adapter.dexRevision, 0
  session.dex.national = true; refresh()
  T.eq(reads, 0, "National unlock does not reread unchanged flags")
  T.eq(adapter.dexRevision, revision + 1, "National unlock still invalidates catalogue")
  T.eq(adapter.save.pokedex.limit, Dex.NATIONAL_MAX, "National catalogue expands on the same poll")

  local virtual = false
  session.dex.seen = setmetatable({}, { __index = function(_, id) return id == 10 and virtual or nil end })
  refresh(); virtual = true; refresh()
  T.check(adapter.save.pokedex.seen[10], "virtual flag tables retain native live reads")
  virtual = false; refresh()
  T.check(not adapter.save.pokedex.seen[10], "virtual flags can disappear without raw mutations")
  session.dex.seen = {}
  refresh()
  local previousSeen = Dex.isSeen
  Dex.isSeen = function(dex, id) return id == 11 or previousSeen(dex, id) end
  adapter:refresh()
  T.check(adapter.save.pokedex.seen[11], "replacing the native reader invalidates the projection")
  Dex.isSeen = previousSeen; refresh()
  T.check(not adapter.save.pokedex.seen[11], "restoring the reader removes its previous result")

  session.dex = { seen = { [12] = true }, caught = {}, owned = {} }; refresh()
  T.check(adapter.save.pokedex.seen[12] and not adapter.save.pokedex.caught[9],
    "replacing the full dex cannot retain previous catches")
  game.session = nil
  T.eq(adapter:refresh(), nil, "return to title releases the projection")
  session = Schema.newGame({ version = os.getenv("POKEPORT_VERSION"), name = "NEW", rngSeed = 789 })
  game.session = session
  require("src.core.game3.runtime").session = session
  refresh()
  T.check(not adapter.save.pokedex.seen[12], "new playthrough cannot inherit old flags")
  Dex.isSeen, Dex.isCaught = isSeen, isCaught
end
dofile(path .. "/tests/gen3_fixture.lua")
