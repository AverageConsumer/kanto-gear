-- One touch page for Pokemon from every generation. Only the model varies.
-- Navigation belongs to Gear; this module never reads or writes native input.
local Page = {}
local labels = { "STATS", "MOVES", "TRAINER", "CONTESTS" }

function Page.turn(state, direction)
  state.page = ((state.page or 1) - 1 + direction) % state.pages + 1
end

function Page.tabRect(state, index)
  if state.pages == 5 then
    local edges = { 6, 50, 86, 134, 184, 236 }
    return edges[index], 31, edges[index + 1] - edges[index] - 2, 19
  end
  local left = 6 + math.floor((index - 1) * 230 / state.pages)
  local right = 6 + math.floor(index * 230 / state.pages) - 2
  return left, 31, right - left, 19
end

function Page.hit(state, x, y)
  for index = 1, state.pages do
    local left, top, width, height = Page.tabRect(state, index)
    if x >= left and x < left + width and y >= top and y < top + height then
      return "page", index
    end
  end
  if state.page ~= state.hiddenPage and (state.page == 2 or state.page == 4) and x >= 6 and x < 234 then
    local slot = math.floor((y - 82) / 32) + 1
    if slot >= 1 and slot <= 4 and y < 82 + (slot - 1) * 32 + 29 then
      return "move", slot
    end
  end
end

function Page.draw(H, state, mon, portrait, translate)
  local c = H.colors
  for index = 1, state.pages do
    local left, top, width, height = Page.tabRect(state, index)
    local active = state.page == index
    local label = labels[index]
    if state.pages > 4 and index == 2 then label = "ATKS" end
    H:tab(left, top, width, height, translate(mon.isEgg and "EGG"
      or index == state.hiddenPage and "DETAILS" or label), active)
  end
  H:panel(6, 54, 228, 24, false, nil, H:typeColor(mon.type))
  portrait(mon, 11, 55, 20, false)
  H:partyName(mon.name, 36, 56, c.ink, 94)
  if mon.isEgg then
    H:panel(6, 82, 228, 128, false, nil, c.greenLight)
    H:partyInfo(translate("HATCHING"), 14, 91, c.green, 212, "center")
    if mon.spoilers then
      local both = mon.eggProgress ~= false and mon.eggContents ~= false
      if mon.eggProgress ~= false then
        local y = both and 111 or 130
        H:partyInfo(translate("ESTIMATED STEPS"), 14, y, c.green, 212, "center")
        H:partyInfo(mon.egg.steps and ("~%d"):format(mon.egg.steps) or "--", 14, y + 15, c.ink, 212, "center")
        H:partyType(translate("HATCH CYCLES") .. " " .. tostring(mon.egg.cycles or "--"), 14, both and 195 or 172, c.green, 212)
      end
      if mon.eggContents ~= false then
        local y = both and 155 or 130
        H:partyInfo(translate("HATCHES INTO"), 14, y, c.green, 212, "center")
        H:partyInfo(H:fitPartyInfo(mon.hatchName or "--", 212), 14, y + 15, c.ink, 212, "center")
      end
    else
      H:partyInfo(translate("KEEP THE EGG IN YOUR PARTY."), 14, 128, c.ink, 212, "center")
      H:partyInfo(translate("WALK TO HELP IT HATCH."), 14, 145, c.ink, 212, "center")
    end
    return
  end
  if mon.statusId then H:statusIcon(mon.statusId, 133, 59) end
  if mon.gender == "male" or mon.gender == "female" then H:genderIcon(mon.gender, 146, 58) end
  H:partyInfo(mon.levelText, 158, 57, c.ink, 68, "right")
  H:hpBar(36, 70, 114, mon.hp, mon.maxHp)
  H:partyType(mon.hpText, 157, 67, c.green, 69)

  if state.page == state.hiddenPage then
    local details = mon.details
    H:panel(6, 82, 228, 128, false, nil, c.blueLight)
    local genes, training = details.showGenes ~= false, details.showTraining ~= false
    -- Game path [Gen 2/3]: per-Pokemon friendship exists only after Gen 1; disclosure settings still control whether the value is shown.
    if state.generation > 1 and details.showFriendship ~= false then
      local value = details.friendship and ("%d/255"):format(details.friendship) or "--"
      if not genes and not training then
        H:partyInfo(translate("FRIENDSHIP"), 14, 130, c.green, 212, "center")
        H:partyInfo(value, 14, 150, c.ink, 212, "center")
      else
        local width = details.total and 132 or 212
        local label = translate("FRIENDSHIP")
        local labelWidth, valueWidth = H:partyInfoWidth(label), H:partyInfoWidth(value)
        local left = 14 + math.floor((width - labelWidth - 8 - valueWidth) / 2)
        H:partyInfo(label, left, 89, c.green)
        H:partyInfo(value, left + labelWidth + 8, 89, c.ink)
        if details.total then H:partyType(("EV %d/510"):format(details.total), 147, 91, c.green, 79) end
      end
    elseif genes or training then
      H:partyInfo(details.total and ("EV %d/510"):format(details.total) or translate("DETAILS"),
        14, 89, c.green, 212, "center")
    end
    if genes or training then
      local columns = { { label = "STAT", field = "label" } }
      if genes then columns[#columns + 1] = { label = details.geneLabel, field = "gene" } end
      if training then columns[#columns + 1] = { label = details.effortLabel, field = "effort" } end
      for index, column in ipairs(columns) do
        local left = 14 + math.floor((index - 1) * 212 / #columns)
        local width = 14 + math.floor(index * 212 / #columns) - left
        H:partyInfo(translate(column.label), left, 108, c.green, width, "center")
        for i, row in ipairs(details.rows) do
          local y = 121 + (6 - #details.rows) * 6 + (i - 1) * 12
          local value = row[column.field]
          H:partyInfo(H:fitPartyInfo(value == nil and "--" or tostring(value), width - 2),
            left + 1, y, c.ink, width - 2, "center")
        end
      end
    end
    -- Game path [Gen 2/3]: Hidden Power exists only after Gen 1 and follows the generation-specific formula in summary_details.
    if state.generation > 1 and details.showGenes ~= false then
      H:partyType(translate("HIDDEN POWER"), 14, 199, c.green, 96)
      H:partyType(details.power and ("%s / %d"):format(details.typeLabel, details.power) or "--", 114, 199, c.ink, 112)
    end
  elseif state.page == 2 or state.page == 4 then
    for slot = 1, 4 do
      local move = mon.moves[slot] or {}
      local y, interactive = 82 + (slot - 1) * 32, move.available and mon.moveDetails
      local pressed = H:beginPress(6, y, 228, 29, interactive)
      H:panel(6, y, 228, 29, state.hardwareFocus and (state.moveIndex or 1) == slot,
        H:typeColor(move.type), H:typeColor(move.type))
      H:moveTypeBadge(move, 14, y + 10)
      H:partyName(move.name or "-", 70, y + 3, c.ink, 88)
      H:partyInfo(move.ppLabel or translate("PP"), 157, y + 3, c.green)
      H:partyInfo(move.ppText or "--", 177, y + 3, c.ink, 35, "right")
      if interactive then H:detailChevron(223, y + 8, c.ink) end
      for col, pair in ipairs({ { move.powerLabel, move.powerText }, { move.accuracyLabel, move.accuracyText } }) do
        local x = 70 + (col - 1) * 77
        H:partyType(pair[1] or "", x, y + 17, c.green, 36)
        H:partyType(pair[2] or "--", x + 39, y + 17, c.ink, 30)
      end
      H:endPress(pressed)
    end
  elseif state.page == 1 then
    H:panel(6, 82, 228, 128, false, nil, c.blueLight)
    H:typeBadges(mon, 14, 89, false)
    H:partyInfo(mon.infoLabel, 72, 89, c.green)
    H:partyInfo(H:fitPartyInfo(mon.infoText or "---", 106), 120, 89, c.ink, 106, "right")
    H:partyInfo(mon.statsTitle, 14, 111, c.green, 212, "center")
    local rows = math.max(1, math.ceil(#mon.stats / 2))
    for index, entry in ipairs(mon.stats) do
      local col, row = math.floor((index - 1) / rows), (index - 1) % rows
      local x, y = 14 + col * 110, 126 + (3 - rows) * 9 + row * 19
      H:panel(x - 2, y - 3, 104, 17, false, nil, c.greenLight)
      H:partyInfo(H:fitPartyInfo(entry.label, 65), x + 2, y, c.green)
      H:partyInfo(entry.value == nil and "--" or tostring(entry.value), x + 68, y,
        c.ink, 30, "center")
    end
    H:partyInfo(mon.expLabel, 14, 187, c.green, 126, "center")
    H:expBar(14, 202, 126, mon.expProgress)
    H:partyInfo(mon.nextLabel, 150, 187, c.green, 76, "center")
    H:partyInfo(mon.nextValue or translate("MAX"), 150, 199, c.ink, 76, "center")
  else
    H:panel(6, 82, 228, 128, false, nil, c.blueLight)
    H:partyInfo(mon.otLabel, 14, 89, c.green, 126)
    H:partyInfo(mon.idLabel, 150, 89, c.green, 76, "center")
    H:partyName(mon.otText or "---", 14, 101, c.ink, 126)
    H:partyInfo(mon.idText, 150, 101, c.ink, 76, "center")
    if mon.natureText or mon.abilityText then
      H:partyInfo(mon.natureLabel, 14, 121, c.green, 83)
      H:partyInfo(H:fitPartyInfo(mon.natureText or "---", 124), 102, 121, c.ink, 124, "right")
      H:partyInfo(mon.abilityLabel, 14, 139, c.green, 83)
      H:partyInfo(H:fitPartyInfo(mon.abilityText or "---", 124), 102, 139, c.ink, 124, "right")
      for i, line in ipairs(mon.abilityLines or {}) do
        H:partyInfo(line, 14, 157 + (i - 1) * 11, c.ink, 212, "center")
      end
    else
      H:partyInfo(mon.growthTitle, 14, 125, c.green, 212, "center")
      H:partyInfo(mon.nextLevelLabel, 14, 147, c.green, 101, "center")
      H:partyInfo(mon.nextExpLabel, 125, 147, c.green, 101, "center")
      H:partyInfo(mon.nextLevelText, 14, 163, c.ink, 101, "center")
      H:partyInfo(mon.nextValue or "--", 125, 163, c.ink, 101, "center")
    end
    H:partyType(mon.totalExpLabel, 14, 194, c.green, 101)
    H:partyType(mon.experienceText, 125, 194, c.ink, 101)
  end
end

return Page
