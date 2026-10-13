return function(H, ui, draw)

  function H:enemyInfoOpponentHit(x, y)
    if x < 6 or x >= 234 then return end
    if y >= 40 and y < 118 then return 1 end
    if y >= 125 and y < 203 then return 3 end
  end

  function H:enemyInfoHit(x, y, hasDvs, info)
    if hasDvs and x >= 151 and x < 224 and y >= 72 and y < 93 then
      return "dvs"
    end
    if (not info or info.profileAvailable ~= false) and x >= 7 and x < 233 and y >= 105 and y < 144 then return "profile" end
    if (not info or info.matchupsAvailable ~= false) and y >= 149 and y < 210 then
      if x >= 7 and x < 117 then return "weak" end
      if x >= 123 and x < 233 then return "resist" end
    end
  end

end
