-- Edition rules that cannot be inferred from an object's hide flag alone.
return function()
  local Rules = {}
  -- Game path [FireRed/LeafGreen]: separate revival receipts must retain the earlier Mt Moon fossil choice and its excluded alternative.
  local revived = {
    [138] = { receipt = 749, chosen = 626, other = 627 },
    [140] = { receipt = 748, chosen = 627, other = 626 },
  }
  function Rules.revivedFossil(mapId, row)
    local rule = revived[row.species]
    if mapId == "FR_CINNABAR_ISLAND_POKEMON_LAB_EXPERIMENT_ROOM"
        and rule and row.event == rule.receipt then
      row.alternative, row.choiceEvent = rule.chosen, rule.other
    end
  end
  -- Game path [FireRed/LeafGreen]: the scripted Pokemon Tower Marowak ghost is not a catchable species objective.
  function Rules.uncatchable(mapId, species)
    return mapId == "FR_POKEMON_TOWER_6F" and species == 105
  end
  -- Game path [RS/Emerald]: contest display balls and Emerald bedroom balls are scenery, not missing item objectives.
  function Rules.decorativeBall(self, obj)
    return self.rs and obj.flag == self.constants:flag("FLAG_LINK_CONTEST_ROOM_POKEBALL")
      or self.emerald and (
      obj.flag == self.constants:flag("FLAG_HIDE_CONTEST_POKE_BALL")
      or obj.flag == self.constants:flag("FLAG_HIDE_LITTLEROOT_TOWN_BRENDANS_HOUSE_2F_POKE_BALL")
      or obj.flag == self.constants:flag("FLAG_HIDE_LITTLEROOT_TOWN_MAYS_HOUSE_2F_POKE_BALL"))
  end
  function Rules.items(self, mapId, obj, vars, value, out, base)
    local hasItem = false
    -- These balls start hidden. Ownership of a non-consumable key item is
    -- evidence; the initial hide flag on its own is not.
    -- Game path [FireRed/LeafGreen]: Rocket keys start hidden, while Mt Moon hide flags cover an exclusive fossil choice; neither proves receipt alone.
    if mapId == "FR_ROCKET_HIDEOUT_B4F" and (obj.flag == 54 or obj.flag == 55) then
      local row = base(obj)
      row.kind, row.itemId, row.ownedKey = "item", value, true
      out[2][#out[2] + 1], hasItem = row, true
    elseif mapId == "FR_MT_MOON_B2F" and (obj.flag == 47 or obj.flag == 48) then
      local row = base(obj)
      row.kind, row.itemId = "item", obj.flag == 47 and 358 or 357
      row.event, row.alternative = obj.flag == 47 and 626 or 627, obj.flag == 47 and 627 or 626
      out[2][#out[2] + 1], hasItem = row, true
    end
    -- Game path [Ruby/Sapphire]: taking either Route 111 fossil hides both; count one durable choice without inventing which fossil was received.
    if self.rs and mapId:match("_ROUTE111$") and (obj.flag == self.constants:flag("FLAG_HIDE_ROOT_FOSSIL")
        or obj.flag == self.constants:flag("FLAG_HIDE_CLAW_FOSSIL")) then
      -- RS hides both fossils after either choice, without recording which one.
      -- Represent the single durable choice, never claim both items were received.
      if obj.flag == self.constants:flag("FLAG_HIDE_ROOT_FOSSIL") then
        local row = base(obj)
        row.kind, row.event = "item", obj.flag
        row.label = self.adapter.data.items[286].name .. " / " .. self.adapter.data.items[287].name
        out[2][#out[2] + 1] = row
      end
      hasItem = true
    end
    -- Game path [Emerald]: Mirage Tower choice flags identify the selected fossil; Desert Underpass later offers the other after the collapse unlock.
    if self.emerald then
      local C = self.constants
      local root, claw = C:flag("FLAG_CHOSE_ROOT_FOSSIL"), C:flag("FLAG_CHOSE_CLAW_FOSSIL")
      local items = vars[0x8000] or {}
      -- The collapse hides both fossils. Their individual choice flags,
      -- rather than the hide flags, prove which reward was selected.
      if mapId == "EM_MIRAGE_TOWER_4F" and (
          obj.flag == C:flag("FLAG_HIDE_MIRAGE_TOWER_ROOT_FOSSIL") and items[286]
          or obj.flag == C:flag("FLAG_HIDE_MIRAGE_TOWER_CLAW_FOSSIL") and items[287]) then
        local isRoot = items[286] == true
        local row = base(obj)
        row.kind, row.itemId = "item", isRoot and 286 or 287
        row.event, row.alternative = isRoot and root or claw, isRoot and claw or root
        out[2][#out[2] + 1], hasItem = row, true
      elseif mapId == "EM_DESERT_UNDERPASS" and obj.flag == C:flag("FLAG_HIDE_DESERT_UNDERPASS_FOSSIL")
          and items[286] and items[287] then
        for _, item in ipairs({ 286, 287 }) do
          local row = base(obj)
          row.id, row.kind, row.itemId, row.event = row.id .. "_" .. item, "item", item, obj.flag
          row.needsChoice, row.otherChoice = item == 286 and claw or root, item == 286 and root or claw
          row.unlockVar, row.unlockValue = C:var("VAR_MIRAGE_TOWER_STATE"), 2
          row.choiceGroup = mapId .. ":remaining-fossil"
          out[2][#out[2] + 1] = row
        end
        hasItem = true
      end
    end
    return hasItem
  end
  return Rules
end
