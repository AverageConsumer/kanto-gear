return function(H, ui, draw, icons)

  do
    local noticeTop, noticeStep, noticeCount = H:pcNoticeRows(4)
    assert(H:fitPartyInfo("WITHDRAW <PK><MN>", 220)
          == "WITHDRAW PKMN"
        and noticeTop + (noticeCount - 1) * noticeStep + 9 <= 158
        and H:pcListHit(120, 100, 4) == 2
        and H:pcListHit(120, 96, 4) == nil
        and H:pcQuantityHit(30, 110) == "minus"
        and H:pcQuantityHit(200, 180) == "cancel",
      "HGSS PC hitboxes match visible storage controls")
  end

end
