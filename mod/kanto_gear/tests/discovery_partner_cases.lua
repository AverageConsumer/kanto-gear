-- Exercise separately disclosed partner facts through the actual shared model.
return function(T, path, Summary, state, model, H, Page, game)
  local Policy = assert(loadfile(path .. "/core/discovery.lua"))()
  local oldMon, oldPage = state.mon, state.page
  for _, flag in ipairs({ "friendship", "genes", "training" }) do
    local policy = Policy.resolve(function(k)
      if k == "info_level" then return "custom" end
      return k == Policy.key(flag)
    end)
    Summary.configure(state, policy)
    if flag == "friendship" and state.generation == 1 then
      T.eq(state.hiddenPage, nil, "Gen 1 has no friendship page")
    else
      state.page = state.hiddenPage
      local mon = model(state)
      local details = mon.details
      T.eq(details.showFriendship, flag == "friendship", "friendship permission is independent")
      T.eq(details.showGenes, flag == "genes", "genes permission is independent")
      T.eq(details.showTraining, flag == "training", "training permission is independent")
      if flag ~= "friendship" then T.eq(details.friendship, nil, "friendship values are redacted") end
      if flag ~= "genes" then T.eq(details.power, nil, "Hidden Power needs gene permission") end
      if flag ~= "training" then T.eq(details.total, nil, "EV totals need training permission") end
      for _, row in ipairs(details.rows) do
        if flag ~= "genes" then T.eq(row.gene, nil, "individual gene values are redacted") end
        if flag ~= "training" then T.eq(row.effort, nil, "individual training values are redacted") end
      end
      T.check(pcall(Page.draw, H, state, mon, function() end, function(v) return v end), "partial details render")
    end
  end
  if state.generation > 1 then
    state.mon = { species = oldMon.species, isEgg = true, eggSteps = 3, friendship = 3 }
    for _, flag in ipairs({ "egg_progress", "egg_species" }) do
      local policy = Policy.resolve(function(k)
        if k == "info_level" then return "custom" end
        return k == Policy.key(flag)
      end)
      Summary.configure(state, policy)
      local mon = model(state)
      T.eq(mon.eggProgress, flag == "egg_progress", "egg progress is independent")
      T.eq(mon.eggContents, flag == "egg_species", "egg contents are independent")
      if flag == "egg_species" then T.eq(next(mon.egg), nil, "egg identity does not disclose hatch cycles")
      else T.eq(mon.hatchName, nil, "egg progress does not disclose the hatchling") end
      T.check(pcall(Page.draw, H, state, mon, function() end, function(v) return v end), "partial egg details render")
    end
  end
  state.mon, state.page = oldMon, oldPage
end
