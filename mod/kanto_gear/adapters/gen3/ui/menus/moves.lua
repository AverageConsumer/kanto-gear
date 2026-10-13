return function(UI, labels)
  function UI:relearnerMenu(layer, projection, battle)
    local mode = projection.mode
    local native = projection.native
    projection.title = "MOVES"
    if mode == "list" then
      projection.items, projection.field = {}, "cursor"
      projection.relearnMoves, projection.relearnMon = native.moves(), native._mon
      projection.relearnKey = table.concat(projection.relearnMoves, "\31")
      projection.relearnFirst = self.movePage.window(#projection.relearnMoves, native.cursor)
      for _, id in ipairs(projection.relearnMoves) do
        local pp = self.adapter.Pokemon.movePp(id)
        projection.items[#projection.items + 1] = { label = self.adapter.Pokemon.moveName(id),
          move = { id = self.adapter.Moves.constName(id), pp = pp, maxPp = pp }, right = pp .. "/" .. pp }
      end
      projection.items[#projection.items + 1] = { label = "CANCEL" }
      projection.moveSelection = { mon = self.adapter:mon(projection.relearnMon), items = projection.items, catalogue = true, cursor = native.cursor }
    elseif mode == "yesno" then
      projection.items, projection.field, projection.prompt = labels({ "YES", "NO" }), "yesNoCursor", native.prompt
    end
    return true
  end
  function UI:forgetMenu(layer, projection, battle)
    local RomText = projection.RomText
    local mode = projection.mode
    local native = projection.native
    local rsSummaryState = projection.rsSummaryState
    projection.title, projection.items, projection.slots, projection.field = "FORGET MOVE", {}, {}, "_moveCursor"
    local raw = native._party and native._party[native._cursor]
    local mon = raw and self.adapter:mon(raw)
    -- Game path [Ruby/Sapphire]: the forget-move cursor is _selected and zero-based; the shared projection converts it at the boundary.
    projection.field = self.adapter.rs and "_selected" or projection.field
    for slot = 1, 4 do
      local row = raw and self:moveItem(raw, slot)
      if row then projection.items[#projection.items + 1], projection.slots[#projection.slots + 1] = row, slot end
    end
    projection.items[#projection.items + 1], projection.slots[#projection.slots + 1] = { label = "CANCEL" }, 5
    projection.moveSelection = { mon = mon, items = projection.items, slots = projection.slots,
      newMoveId = (tonumber(native._moveToLearn) or 0) > 0 and self.adapter.Moves.constName(native._moveToLearn) or nil,
      learning = true }
    if native._hmNotice or rsSummaryState == "notice" then
      projection.prompt = RomText.plain(require("src.core.game3.battle.profile").get(self.adapter.session).strings.hmCantForget)
    end
    return true
  end
end
