return function(H, ui, draw, icons)
  local box = draw.box
  local color = draw.color
  local translate =
    draw.translate
  function H:battleChoice(x, y)
    for index, action in ipairs(self.battleActions) do
      if x >= action.x and x < action.x + action.w
          and y >= action.y and y < action.y + action.h then return index end
    end
  end

  function H:fullBattleChoice(x, y)
    for index, action in ipairs(self.fullBattleActions) do
      if x >= action.x and x < action.x + action.w
          and y >= action.y and y < action.y + action.h then return index end
    end
  end

  assert(H:fullBattleChoice(62, 139) == 1
      and H:fullBattleChoice(178, 139) == 2
      and H:fullBattleChoice(62, 188) == 3
      and H:fullBattleChoice(178, 188) == 4
      and H:fullBattleChoice(120, 139) == nil,
    "HGSS Full Gear hitboxes follow the visible two-by-two action grid")

  local PLAYER_CENTER, VS_CENTER, FOE_CENTER = 60, 120, 180
  local TEAM_WIDTH, VS_WIDTH, WILD_WIDTH = 64, 16, 88
  local TEAM_LEFT = PLAYER_CENTER - TEAM_WIDTH / 2
  local VS_LEFT = VS_CENTER - VS_WIDTH / 2
  local FOE_LEFT = FOE_CENTER - TEAM_WIDTH / 2
  local WILD_LEFT = FOE_CENTER - WILD_WIDTH / 2
  assert(TEAM_LEFT - 8 == VS_LEFT - (TEAM_LEFT + TEAM_WIDTH)
      and FOE_LEFT - (VS_LEFT + VS_WIDTH)
        == 232 - (FOE_LEFT + TEAM_WIDTH)
      and VS_CENTER - PLAYER_CENTER == FOE_CENTER - VS_CENTER
      and WILD_LEFT + WILD_WIDTH / 2 == FOE_CENTER,
    "HGSS trainer and wild battle strips share centered spacing")

  function H:battleTeamStrip(playerTeam, enemyTeam, canGoBack)
    local colors = self.colors
    self:panel(5, 3, 230, 25, false)
    if canGoBack then self:chevron(15, 15, false) end
    for slot = 1, 6 do
      self:battleTeamBall(TEAM_LEFT + 4 + (slot - 1) * 11, 20,
        playerTeam and playerTeam[slot])
    end
    self:partyInfo(translate("YOU"), TEAM_LEFT, 3, colors.green, TEAM_WIDTH, "center")
    self:partyInfo(translate("VS"), VS_LEFT, 9, colors.ink, VS_WIDTH, "center")
    if enemyTeam and enemyTeam.wild then
      self:partyInfo(translate("WILD"), WILD_LEFT, 3, colors.green,
        WILD_WIDTH, "center")
      local detail = tostring(enemyTeam.name or translate("POKEMON"))
      if enemyTeam.level then detail = detail .. " L" .. enemyTeam.level end
      self:partyInfo(self:fitPartyInfo(detail, WILD_WIDTH),
        WILD_LEFT, 15, colors.ink, WILD_WIDTH, "center")
    else
      for slot = 1, 6 do
        self:battleTeamBall(FOE_LEFT + 4 + (slot - 1) * 11, 20,
          enemyTeam and enemyTeam[slot])
      end
      self:partyInfo(translate("FOE"), FOE_LEFT, 3, colors.green, TEAM_WIDTH, "center")
    end
  end

  local MESSAGE_X, MESSAGE_WIDTH = 10, 220
  assert(MESSAGE_X + MESSAGE_WIDTH / 2 == 120,
    "HGSS battle message shares the screen center")

  function H:battleContinueMotion(now)
    if self.motionEnabled == false then return 0, 5 end
    local phase = (1 - math.cos((tonumber(now) or 0) * math.pi)) / 2
    local bob = math.floor(phase + 0.5)
    return bob, bob == 0 and 5 or 9
  end

  local BATTLE_ACTION_CONTENT_RISE = 2

  function H:battleBagAction(mon, selected, offsetX, offsetY, enabled)
    local G, colors = ui.graphics, self.colors
    offsetX, offsetY = offsetX or 0, offsetY or 0
    local pressed = self:beginPress(6 + offsetX, 159 + offsetY, 68, 52, enabled)
    G.push()
    G.translate(offsetX, offsetY + 10)
    self:battleActionPanel(6, 149, 68, 52, "amber", selected)
    G.translate(0, -BATTLE_ACTION_CONTENT_RISE)
    self:battleBagIcon(27, 154)
    self:label(mon.bagLabel or translate("BAG"), 6, 183, colors.white, 68, "center")
    G.pop()
    self:endPress(pressed)
  end

  function H:battlePartyAction(mon, selected, offsetX, offsetY, enabled)
    local G, colors = ui.graphics, self.colors
    offsetX, offsetY = offsetX or 0, offsetY or 0
    local pressed = self:beginPress(166 + offsetX, 159 + offsetY, 68, 52, enabled)
    G.push()
    G.translate(offsetX, offsetY + 10)
    self:battleActionPanel(166, 149, 68, 52, "green", selected)
    G.translate(0, -BATTLE_ACTION_CONTENT_RISE)
    self:battleTeamBall(185, 169, true)
    self:battleTeamBall(200, 164, true)
    self:battleTeamBall(215, 169, true)
    self:label(mon.partyLabel or translate("POKEMON"), 166, 183,
      colors.white, 68, "center")
    G.pop()
    self:endPress(pressed)
  end

  function H:battleRunAction(mon, selected, offsetX, offsetY, enabled)
    local G, colors = ui.graphics, self.colors
    offsetX, offsetY = offsetX or 0, offsetY or 0
    local pressed = self:beginPress(86 + offsetX, 159 + offsetY, 68, 52, enabled)
    G.push()
    G.translate(offsetX, offsetY + 10)
    self:battleActionPanel(86, 149, 68, 52, "blue", selected)
    G.translate(0, -BATTLE_ACTION_CONTENT_RISE)
    self:battleRunnerIcon(119, 168)
    self:label(mon.runLabel or translate("RUN"), 86, 183, colors.white, 68, "center")
    G.pop()
    self:endPress(pressed)
  end

  function H:battleRoot(mon, drawPortrait, playerTeam, enemyTeam, selected, enabled)
    selected = self.nativeFocus and selected or nil
    self:battleTeamStrip(playerTeam, enemyTeam)
    self:battleFightAction(mon, drawPortrait, selected == 1, 0, 0, enabled)
    self:battleBagAction(mon, selected == 3, 0, 0, enabled)
    self:battlePartyAction(mon, selected == 2, 0, 0, enabled)
    self:battleRunAction(mon, selected == 4, 0, 0, enabled)
  end

  function H:battleFullAction(mon, index, selected, labels)
    local G, colors = ui.graphics, self.colors
    local action = self.fullBattleActions[index]
    local pressed = self:beginPress(action.x, action.y, action.w, action.h)
    self:battleActionPanel(action.x, action.y, action.w, action.h,
      action.color, selected)
    local iconX, iconY = action.x + 22, action.y + 22
    if index == 1 then
      G.push()
      G.translate(iconX - 10, iconY - 10)
      G.scale(2, 2)
      self:battleTeamBall(5, 5, true)
      G.pop()
    elseif index == 2 then
      self:battleTeamBall(iconX - 8, iconY + 2, true)
      self:battleTeamBall(iconX, iconY - 3, true)
      self:battleTeamBall(iconX + 8, iconY + 2, true)
    elseif index == 3 then
      self:battleBagIcon(action.x + 6, action.y + 6)
    else
      self:battleRunnerIcon(iconX, iconY)
    end
    local label = self:fitLabel(labels[index], action.w - 43)
    self:label(label, action.x + 39, action.y + 15, colors.white,
      action.w - 43, "center")
    self:endPress(pressed)
  end

  function H:battleFullStatuses(player, enemy, drawPortrait,
      playerTeam, enemyTeam, lines, battlers)
    self:battleTeamStrip(playerTeam, enemyTeam)
    if battlers then
      for _, mon in ipairs(battlers) do
        self:battleCompactStatus(mon, 6 + mon.id % 2 * 116,
          33 + math.floor(mon.id / 2) * 41, drawPortrait)
      end
    else
      self:battleStatusCard(player, 6, 33, 112, true, drawPortrait)
      self:battleStatusCard(enemy, 122, 33, 112, false, drawPortrait)
    end
    if lines and #lines > 0 then self:battleFullMessage(lines) end
  end

  function H:battleFullRoot(mon, player, enemy, drawPortrait,
      playerTeam, enemyTeam, selected, battlers)
    selected = self.nativeFocus and selected or nil
    self:battleFullStatuses(player, enemy, drawPortrait,
      playerTeam, enemyTeam, nil, battlers)
    local labels = { mon.fightLabel or translate("FIGHT"), mon.partyLabel or translate("POKEMON"),
      mon.bagLabel or translate("BAG"), mon.runLabel or translate("RUN") }
    for index = 1, 4 do
      self:battleFullAction(mon, index, selected == index, labels)
    end
  end

  local safariIconBounds = { ball = { -8, 10 }, bait = { -9, 8 }, rock = { -7, 7 },
    pokeblock = { -10, 10 }, go_near = { -13, 14 }, run = { -13, 14 } }

  function H:battleSafariAction(action, index, selected)
    local G, colors = ui.graphics, self.colors
    local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
    local x, y = 6 + column * 116, 33 + row * 91
    if ui.safariPage then x, y = ui.safariPage.rect(index) end
    local pressed = self:beginPress(x, y, 112, 86, action.enabled ~= false)
    self:battleActionPanel(x, y, 112, 86, action.color, selected)
    local bounds = safariIconBounds[action.kind] or safariIconBounds.run
    -- Center the complete label/icon/count group using the icon's visible pixels.
    local height = 24 + bounds[2] - bounds[1] + (action.detail and 24 or 0)
    local titleY = y + math.floor((86 - height) / 2)
    self:partyInfoCentered(self:fitPartyInfo(translate(action.label), 96),
      x + 8, titleY, 96, 12, colors.white)
    local iconY = titleY + 24 - bounds[1]
    if action.kind == "ball" then
      G.push()
      G.translate(x + 45, iconY - 10)
      G.scale(2, 2)
      self:battleTeamBall(5, 5, true)
      G.pop()
    elseif action.kind == "bait" then
      box("fill", x + 48, iconY - 5, 17, 13, colors.outline)
      box("fill", x + 50, iconY - 7, 13, 2, colors.outline)
      box("fill", x + 51, iconY - 4, 11, 10, colors.amberLight)
      box("fill", x + 54, iconY - 9, 5, 3, colors.greenLight)
      box("fill", x + 56, iconY - 2, 4, 4, colors.redLight)
    elseif action.kind == "pokeblock" then
      box("fill", x + 47, iconY - 10, 18, 20, colors.outline)
      box("fill", x + 49, iconY - 8, 14, 16, colors.redLight)
      box("fill", x + 49, iconY - 8, 14, 4, colors.amberLight)
      box("fill", x + 59, iconY - 4, 4, 12, colors.red)
      box("fill", x + 51, iconY - 2, 3, 3, colors.white)
    elseif action.kind == "go_near" then
      self:battleRunnerIcon(x + 51, iconY)
      self:detailChevron(x + 69, iconY - 2, colors.white)
    elseif action.kind == "rock" then
      box("fill", x + 47, iconY - 3, 4, 8, colors.outline)
      box("fill", x + 51, iconY - 7, 10, 14, colors.outline)
      box("fill", x + 61, iconY - 2, 4, 9, colors.outline)
      box("fill", x + 49, iconY - 2, 4, 6, colors.silverDark)
      box("fill", x + 52, iconY - 5, 8, 10, colors.silver)
      box("fill", x + 60, iconY - 1, 3, 6, colors.silverDark)
      box("fill", x + 54, iconY - 4, 4, 2, colors.white)
    else
      self:battleRunnerIcon(x + 56, iconY)
    end
    if action.detail then
      self:partyInfoCentered(action.detail, x + 8, iconY + bounds[2] + 12,
        96, 12, colors.white)
    end
    self:endPress(pressed)
  end

  function H:battleSafari(model, playerTeam, enemyTeam)
    self:battleTeamStrip(playerTeam, enemyTeam)
    for index, action in ipairs(model.actions) do
      self:battleSafariAction(action, index, self.nativeFocus and model.index == index)
    end
  end

  function H:safariHit(x, y)
    if ui.safariPage then return ui.safariPage.hit(x, y) end
    if y < 33 or y >= 210 then return nil end
    local column = x >= 122 and 1 or x >= 6 and 0 or nil
    if column == nil or x >= (column == 0 and 118 or 234) then return nil end
    local row = y >= 124 and 1 or y < 119 and 0 or nil
    if row == nil then return nil end
    return row * 2 + column + 1
  end

  function H:partySelectionRect(slot, count, cancel)
    return ui.partyPage.rect(self, slot, count, cancel)
  end

  function H:partySelectionHit(x, y, count, cancel)
    return ui.partyPage.hit(self, x, y, count, cancel)
  end

  function H:partySelection(party, drawPortrait, emptyTargets, selection)
    ui.partyPage.draw(self, { party = party, selection = self.nativeFocus and selection or nil }, function(slot, x, y, selected, details, focused)
      local target = type(emptyTargets) == "table" and emptyTargets[slot] or emptyTargets == true
      self:partyCard(party[slot], x, y, selected, details, drawPortrait, focused, target)
    end)
  end

  function H:battleMimic(model, playerTeam, enemyTeam)
    local colors = self.colors
    self:battleTeamStrip(playerTeam, enemyTeam)
    self:panel(6, 33, 228, 24, false, nil, colors.blueLight)
    self:partyInfo(model.title or "MIMIC", 14, 41,
      colors.green, 212, "center")
    for slot = 1, math.min(4, #(model.moves or {})) do
      local move = model.moves[slot]
      self:summaryMoveRow(move, 6, 61 + (slot - 1) * 35,
        self.nativeFocus and model.index == slot, move.available ~= false, false)
    end
  end

  function H:mimicHit(x, y, count)
    if x < 6 or x >= 234 or y < 61 then return nil end
    local slot = math.floor((y - 61) / 35) + 1
    local top = 61 + (slot - 1) * 35
    if slot >= 1 and slot <= math.min(4, count or 0)
        and y < top + 34 then return slot end
  end

end
