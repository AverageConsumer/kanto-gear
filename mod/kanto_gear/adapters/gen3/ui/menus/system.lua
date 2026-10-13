return function(UI, labels)
  function UI:saveMenu(layer, projection, battle)
    local RomText = projection.RomText
    local mode = projection.mode
    local native = projection.native
    projection.title, projection.items, projection.field = "SAVE", labels({ "YES", "NO" }), "cursor"
    local key = native._rse and (mode == "confirm" and "gText_ConfirmSave" or "gText_AlreadySavedFile")
      or (mode == "confirm" and "gText_WouldYouLikeToSaveTheGame" or "gText_AlreadySaveFile_WouldLikeToOverwrite")
    -- Game path [Emerald]: Battle Pyramid saving is a rest/suspend prompt; use its native text instead of the ordinary save question.
    local pyramid = native._rse and mode == "confirm" and require("src.core.game3.rse.init").system("pyramid")
    projection.prompt = pyramid and pyramid.inPyramid(native._session)
      and require("src.core.game3.scripting.text_ir").toPlain(pyramid.manifest().confirmRest.ir)
      or RomText.plain(key)
    return true
  end
  function UI:startMenu(layer, projection, battle)
    local native = projection.native
    projection.title = "CHOOSE ACTION"
    if native._confirmExit then
      projection.items, projection.field, projection.prompt = labels({ "YES", "NO" }), "_confirmCursor", require("src.core.Strings")("RETURN TO MAIN\nMENU?")
    else projection.items, projection.field = labels(native.ENTRIES), "cursor" end
    return true
  end
end
