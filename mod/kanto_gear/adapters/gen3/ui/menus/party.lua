return function(UI, labels)
  local partyModes = { list = true, switch = true, use = true, give = true,
    choose = true, choose_multi = true, move_tutor = true, softboiled = true,
    battle_switch = true, battle_faint = true }
  function UI:partyMenu(layer, projection, battle)
    local native = projection.native
    projection.title = "PARTY"
    if partyModes[native.mode] then
      projection.partyLayout = native.mode ~= "choose_multi"
      projection.items, projection.slots, projection.field = {}, {}, "cursor"
      for i, mon in ipairs(native._party or {}) do
        local view = self.adapter:mon(mon)
        local def = self.adapter.data.pokemon[view.species] or {}
        projection.items[#projection.items + 1] = { label = view.nickname or def.name or view.name or "POKEMON",
          mon = view, nativeSlot = i, right = "L" .. tostring(view.level or 0)
            .. " " .. tostring(view.hp or 0) .. "/" .. tostring(view.maxHp or 0) }
        projection.slots[#projection.slots + 1] = i
      end
      -- Native single/double layouts reserve slot 7 for CANCEL, even with
      -- fewer than six party members. Display order may also be battle-local.
      if native.mode == "choose_multi" then
        projection.items[#projection.items + 1], projection.slots[#projection.slots + 1] = { label = "CONFIRM" }, 7
      end
      projection.items[#projection.items + 1], projection.slots[#projection.slots + 1] = { label = "CANCEL" }, native.mode == "choose_multi" and 8 or 7
      if native.mode == "use" then projection.title = "USE ITEM ON" end
    elseif native.mode == "yesno" then
      projection.items, projection.field, projection.prompt = labels({ "YES", "NO" }), "_yesNoCursor", native._yesNoPrompt
    elseif native.mode == "forget" and type(native._forgetMoves) == "table" then
      projection.title, projection.items, projection.field = "CHOOSE MOVE", {}, "_forgetCursor"
      local raw = native._party and native._party[native.cursor]
      local mon = raw and self.adapter:mon(raw)
      local slot = 0
      for index, name in ipairs(native._forgetMoves) do
        repeat slot = slot + 1 until slot > 4 or (self.adapter.Pokemon.moveIdAt(raw, slot) or 0) > 0
        local row = raw and self:moveItem(raw, slot, name)
        if not row then return nil end
        projection.items[index] = row
      end
      projection.moveSelection = { mon = mon, items = projection.items, itemName = self.adapter.Items.displayName(native._item) }
    elseif native.mode == "action" then
      projection.items, projection.field = labels(native.ACTIONS), "actionCursor"
    elseif native.mode == "item_action" then
      projection.items, projection.field = labels(native.ITEM_ACTIONS), "itemActionCursor"
    end
    return true
  end
end
