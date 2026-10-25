local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local up = assert(loadfile(root .. "/tests/support/runtime.lua"))().get
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local map = display.gen3.hoenn and display.gen3.profile.map.enginePrefix .. "ROUTE102" or "FR_ROUTE_1"
  game.session.map = map
  run.loader.events:emit("map.entered", {game=game,mapId=map})
  run.loader.modOptions.kanto_gear.info_level = "guide"
  run.loader.events:emit("mod.options_changed", {mod="kanto_gear",key="info_level",value="guide"})
  local calls = 0
  local P = display.gen3.Pokemon
  local lookup = P.speciesFromName
  P.speciesFromName = function(name) return name == "BULBASAUR" and 4 or lookup(name) end
  display.gen3:refreshDefinitions()
  T.eq(display.gen3.data.pokemon.BULBASAUR.index, 1, "canonical registry IDs beat ambiguous native display-name aliases")
  P.speciesFromName = lookup
  local originalContent, records = display.gen3.content, {}
  for id, row in originalContent.pokemon:each() do records[id] = row end
  records.CONTRACT_FORM = {id="CONTRACT_FORM",index=6000,dex=1,baseDex=1,
    baseSpecies="BULBASAUR",form="test",name="TEST FORM",types={"GRASS"},
    dexEntry={kind="TEST",height=4,weight=10}}
  records.CONTRACT_ADDITION = {id="CONTRACT_ADDITION",index=6001,dex=1200,
    name="TEST ADDITION",types={"WATER"},dexEntry={kind="TEST",height=5,weight=20}}
  local extended = {}; for name, registry in pairs(originalContent) do extended[name] = registry end
  extended.pokemon = {each=function() return pairs(records) end}
  display.gen3.content = extended
  display.gen3:refreshDefinitions()
  T.eq(display.gen3.data.pokemon.CONTRACT_FORM.index, 6000, "registered forms need no native National-number mapping")
  T.eq(display.gen3.data.pokemon.CONTRACT_ADDITION.dex, 1200, "registered species are not limited by the native Dex loop bound")
  T.eq(display.gen3:dexNumber(6000), nil, "forms do not inflate species catalogue totals")
  display.gen3.content = originalContent
  display.gen3:refreshDefinitions()
  local remove = run.loader.hooks:wrap("encounter.table", function(_, _, ctx)
    T.check(ctx.preview == true and ctx.rng == nil, "public query is a preview without a random stream")
    calls = calls + 1
    if ctx.terrain == "water" then return {} end
    return { BULBASAUR=1, CHARMANDER=2, SQUIRTLE=3 }
  end, 1000, "anonymous_encounter_provider")
  display.gen3:clearEncounterPreviews()
  local guideData = assert(up(display.explorerModel, "guideData"))
  local guide = guideData({map})
  local seen = {}
  for _, row in ipairs(guide.rows) do
    for _, a in ipairs(row.appearances) do
      if a.method == "WALK" then
        seen[row.species] = true
        T.eq(a.minLevel, nil, "Guide preserves unknown provider levels")
      end
    end
  end
  T.check(seen[1] and seen[4] and seen[7], "Guide reads all anonymous provider species through public IDs")
  local before = calls
  guideData({map})
  T.eq(calls, before, "guide refresh reuses the bounded query cache")
  display.setPackageInstalled("explorer", true)
  display.openHomeApp("explorer")
  display.explorer.data = nil
  local overview = {mapId=map,width=2,height=2,rows={"..",".."},markers={}}
  display.explorerModel(overview)
  T.check(#display.explorer.data.guide.rows >= 3, "Explorer consumes the public preview")
  run.loader.events:emit("mod.options_changed", {mod="anonymous_encounter_provider",key="roster",value="changed"})
  guideData({map})
  T.check(calls > before, "generic option events invalidate previews without knowing the provider")
  remove()
  display.gen3:clearEncounterPreviews()
  display.explorer.data = nil
end
dofile(root .. "/tests/gen3_fixture.lua")
