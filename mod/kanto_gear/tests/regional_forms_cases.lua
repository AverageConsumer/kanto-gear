-- Native slots without National numbers must remain usable outside the Dex.
return function(T, path, display, game, compat, up)
  local adapter, original = display.gen3, game.session.party[1]
  local P = adapter.Pokemon
  local partyData = up(display.homeWidgetData, "partyData")
  local UI = { adapter = adapter }
  assert(loadfile(path .. "/adapters/gen3/ui/menus/party.lua"))()(UI, function() return {} end)
  for _, case in ipairs({
    { id = 1180, name = "Alolan Vulpix", types = { 15, 15 }, expected = { "ICE" } },
    { id = 1183, name = "Regional Jynx", types = { 4, 14 }, expected = { "GROUND", "PSYCHIC" } },
    { id = 1184, name = "Fairy Form", types = { 15, "FAIRY" }, expected = { "ICE", "FAIRY" } },
  }) do
    local id = case.id
    local oldName, oldTypes = P._names[id], P._types[id]
    P._names[id], P._types[id] = case.name, case.types
    T.eq(P.national(id), nil, "fixture form has no National number")
    T.eq(adapter.data.pokemon[id], nil, "fixture form has no Gear Dex row")
    local raw = {}
    for key, value in pairs(original) do raw[key] = value end
    raw.species, raw.speciesNumbering, raw.nickname = id, P.NUMBERING_INTERNAL, ""
    game.session.party[1] = raw
    adapter:refresh()
    local projected = adapter.save.party[1]
    T.eq(projected.name, case.name, "adapter reads native form name")
    T.same(projected.types, case.expected, "adapter reads native form types")
    for _, nickname in ipairs({ "", "FROSTY" }) do
      raw.nickname = nickname
      adapter:refresh()
      local expectedName = nickname ~= "" and nickname or case.name
      local party = partyData()
      T.eq(party[1].species, id, "party preserves native form slot")
      T.eq(party[1].source, projected, "party retains projected source identity")
      T.eq(party[1].name, expectedName, "party resolves name and nickname without Dex row")
      T.same(party[1].types, case.expected, "party retains live types")
      local card = display.partyView(party[1])
      T.eq(card.type, case.expected[1], "party card resolves primary type")
      T.eq(card.type2, case.expected[2] or case.expected[1], "party card resolves secondary type")
      T.eq(display.partyView(projected).name, expectedName, "direct native party card resolves name")
      display.home.widgetCache = nil
      local widgets = display.homeWidgetData({ party = true, team = true })
      T.eq(widgets.lead.name, expectedName, "lead widget resolves form name")
      T.eq(widgets.team[1].type, case.expected[1], "team widget resolves form type")
      local summary = compat.summary.view(compat.summary.inspection(projected, adapter:gameView(), 3), adapter:gameView())
      T.eq(summary.name, expectedName, "summary resolves form name")
      T.same(summary.types, case.expected, "summary retains form types")
      local menu = { native = { mode = "list", _party = { raw } } }
      UI:partyMenu(nil, menu)
      T.eq(menu.items[1].label, expectedName, "native party projection resolves form label")
      T.eq(raw.species, id, "readers leave native species unchanged")
      T.eq(raw.nickname, nickname, "readers leave native nickname unchanged")
      T.eq(adapter.data.pokemon[id], nil, "forms do not add synthetic National entries")
    end
    P._names[id], P._types[id] = oldName, oldTypes
  end
  game.session.party[1] = original
  adapter:refresh()
  display.home.widgetCache = nil
end
