-- Format one Pokemon read model for the common companion page.
-- Generation-specific extraction stays in models/summary.lua and the native adapters.
return function(services)
  return function(summary)
    local game, native = services.game(), services.native()
    local view = services.summary.view(summary, game)
    if not view then return nil end
    local mon, def = view.mon, view.def
    if view.egg then
      local policy = view.disclosure
      local progress = policy and policy.egg_progress or not policy and view.spoilers
      local contents = policy and policy.egg_species or not policy and view.spoilers
      local egg = progress and services.summary.details.egg(mon, view.generation, game.save, native) or {}
      return { source = mon, isEgg = true, name = services.theme:translate("EGG"),
        egg = egg, spoilers = progress or contents, eggProgress = progress, eggContents = contents,
        hatchName = contents and (def.name or mon.species) or nil }, view
    end
    local types = view.types or {}
    local level = view.level or 0
    local growth = def.growthRate
      and services.content.growth_rates:get(def.growthRate)
      or services.content.growth_rates:get("MEDIUM_FAST")
    local currentLevelExp = growth and growth.expForLevel
      and growth.expForLevel(level) or view.experience
    local nextLevelExp = level < 100 and growth and growth.expForLevel
      and growth.expForLevel(level + 1) or currentLevelExp
    -- Game path [Gen 3]: use the native species growth curve and EXP thresholds rather than the older content growth-rate table.
    if native ~= nil then
      local nativeExp = native.Summary.expProgress(mon,
        native.Pokemon.growthRate(mon.species))
      currentLevelExp, nextLevelExp = nativeExp.curLevelExp, nativeExp.nextLevelExp
    end
    local nextValue = level < 100 and (view.nextExp
      or math.max(0, nextLevelExp - view.experience)) or nil
    local itemText = view.item
    if not itemText or itemText == "" or itemText == "---" then
      itemText = services.theme:translate("NO ITEM")
    end
    local out = {
      source = mon, species = mon.species, name = view.name,
      gender = ({ M = "male", F = "female" })[mon.gender] or mon.gender,
      statusId = services.theme:statusName(view.status, services.content),
      pokerus = view.pokerus,
      type = types[1], type2 = types[2] or types[1],
      typeLabel = services.theme:typeName(types[1], services.content),
      type2Label = services.theme:typeName(types[2] or types[1], services.content),
      dexText = services.theme:format("NO.%03d", view.dex or 0),
      levelText = services.theme:format("L%d", level),
      hp = view.hp, maxHp = view.maxHp,
      hpLabel = services.theme:translate("HP"),
      hpText = services.theme:format("%d/%d", view.hp, view.maxHp),
      expLabel = services.theme:translate("EXP"),
      expProgress = level >= 100 and 1
        or services.progress(view.experience, currentLevelExp, nextLevelExp),
      nextLabel = services.theme:translate("TO NEXT"),
      nextValue = nextValue and tostring(nextValue) or nil,
      infoLabel = services.theme:translate(view.capabilities.heldItems and "ITEM" or "OT"),
      infoText = view.capabilities.heldItems and itemText or view.ot,
      info2Label = view.capabilities.heldItems and nil or services.theme:translate("ID"),
      info2Text = view.capabilities.heldItems and nil or ("%05d"):format(view.otId or 0),
      statsTitle = services.theme:translate("BATTLE STATS"),
      moves = {}, stats = {},
      memoTitle = services.theme:translate("TRAINER MEMO"),
      otLabel = services.theme:translate("ORIGINAL TRAINER"),
      otText = view.ot,
      idLabel = services.theme:translate("ID NO."),
      idText = ("%05d"):format(view.otId or 0),
      growthTitle = services.theme:translate("GROWTH RECORD"),
      totalExpLabel = services.theme:translate("TOTAL EXP"),
      experienceText = tostring(view.experience or 0),
      nextLevelLabel = services.theme:translate("NEXT LEVEL"),
      nextLevelText = level < 100 and services.theme:format("L%d", level + 1)
        or services.theme:translate("MAX"),
      nextExpLabel = services.theme:translate("TO NEXT"),
      moveDetails = services.assist("move_details"),
    }
    if summary.page == summary.hiddenPage then
      out.details = services.summary.details.read(mon, summary.generation)
      local policy = summary.disclosure
      if policy then
        out.details.showFriendship, out.details.showGenes, out.details.showTraining =
          policy.friendship, policy.genes, policy.training
        if not policy.friendship then out.details.friendship = nil end
        if not policy.genes then out.details.power, out.details.type = nil, nil end
        if not policy.training then out.details.total = nil end
        for _, row in ipairs(out.details.rows) do
          if not policy.genes then row.gene = nil end
          if not policy.training then row.effort = nil end
        end
      end
      for _, row in ipairs(out.details.rows) do row.label = services.theme:translate(row.label) end
      out.details.typeLabel = out.details.type and services.theme:typeName(out.details.type, services.content)
    end
    if native ~= nil then
      out.natureLabel, out.natureText = services.theme:translate("NATURE"), native:plainText(view.nature)
      out.abilityLabel, out.abilityText = services.theme:translate("ABILITY"), native:plainText(view.ability)
      out.abilityLines = services.theme:wrapText(native:plainText(view.abilityDescription), 204, 3,
        function(value) return services.theme.hgss:partyInfoWidth(value) end)
    end
    local stats = view.stats or {}
    -- Game path [Gen 1 vs Gen 2/3]: Gen 1 has one Special stat; later games expose separate Special Attack and Defense.
    local rows = view.capabilities.splitSpecial and {
      { "ATTACK", stats.attack }, { "DEFENSE", stats.defense },
      { "SPEED", stats.speed }, { "SP. ATK", stats.specialAttack },
      { "SP. DEF", stats.specialDefense }, { "MAX HP", view.maxHp },
    } or {
      { "ATTACK", stats.attack }, { "SPEED", stats.speed },
      { "DEFENSE", stats.defense }, { "SPECIAL", stats.special },
    }
    for _, row in ipairs(rows) do
      out.stats[#out.stats + 1] = {
        label = services.theme:translate(row[1]), value = row[2],
      }
    end
    for slot = 1, 4 do
      local source = mon.moves and mon.moves[slot] or {}
      local move = game.data.moves[source.id] or {}
      out.moves[slot] = {
        available = source.id ~= nil,
        name = move.name or source.id or "-", type = move.type,
        typeLabel = services.theme:typeName(move.type, services.content),
        ppLabel = services.theme:translate("PP"),
        ppText = source.id and services.theme:format("%d/%d",
          source.pp or 0, view.moves[slot].maxPp or move.pp or 0) or "--",
        powerLabel = services.theme:translate("PWR"),
        powerText = (summary.generation > 1 or out.moveDetails) and move.power and move.power > 0 and tostring(move.power) or "--",
        accuracyLabel = services.theme:translate("ACC"),
        accuracyText = (summary.generation > 1 or out.moveDetails) and move.accuracy and tostring(move.accuracy) or "--",
      }
    end
    if view.contest then
      out.moveDetails = true
      for slot, move in ipairs(out.moves) do
        local contest = view.contest[slot]
        move.available = contest ~= nil
        move.type = contest and ({ COOL = "FIRE", BEAUTY = "WATER", CUTE = "PSYCHIC",
          SMART = "GRASS", TOUGH = "ELECTRIC" })[contest.category] or "NORMAL"
        move.typeLabel = contest and services.theme:translate(contest.category) or "--"
        move.powerLabel, move.accuracyLabel = services.theme:translate("APPEAL"), services.theme:translate("JAM")
        move.powerText, move.accuracyText = contest and contest.appeal or "--", contest and contest.jam or "--"
        move.descriptionLines = contest and services.theme:wrapText(native:plainText(contest.description), 200, 6,
          function(value) return services.theme.hgss:partyInfoWidth(value) end) or {}
      end
    end
    out.moveIndex = nil
    return out, view
  end
end
