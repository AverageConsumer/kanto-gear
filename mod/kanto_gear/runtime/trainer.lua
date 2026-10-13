return function(
  PaletteFX, THEME, assist, box, color, compactSteps,
  compat, displayRuntime, fit, header, outline, render,
  session, text
)
  -- Game path [Gen 2]: badge art uses native OAM tiles, flips and a dedicated palette rather than Gen 1 card quads.
  function compat.gen2BadgeAsset()
    if session.spriteCache.__gen2Badges ~= nil then
      return session.spriteCache.__gen2Badges or nil
    end
    local gfx = session.game.data.gen2MenuGfx and session.game.data.gen2MenuGfx.trainerCard
    if not (gfx and gfx.badges and gfx.badgeOam) then
      session.spriteCache.__gen2Badges = false
      return nil
    end
    local ok, image = pcall(render.G.newImage, gfx.badges)
    if not (ok and image) then
      session.spriteCache.__gen2Badges = false
      return nil
    end
    image:setFilter("nearest", "nearest")
    local iw, ih = image:getDimensions()
    local wide = gfx.badgesWide or 2
    local quads = {}
    for tile = 0, wide * math.floor(ih / 8) - 1 do
      quads[tile] = render.G.newQuad((tile % wide) * 8,
        math.floor(tile / wide) * 8, 8, 8, iw, ih)
    end
    session.spriteCache.__gen2Badges = {
      image = image, quads = quads, oam = gfx.badgeOam,
      palette = gfx.badgePalette,
    }
    return session.spriteCache.__gen2Badges
  end

  function compat.drawGen2Badge(name, x, y, owned, scale)
    local asset = compat.gen2BadgeAsset()
    local obj = asset and asset.oam[THEME.gen2Badges.oam[name] or 0]
    local tile = obj and obj.frames and obj.frames[1]
    if tile == nil then return false end
    scale = scale or 1
    local flip = tile >= 0x80
    local base, sx = flip and tile - 0x80 or tile, flip and -1 or 1
    local function paint()
      color(owned and { 1, 1, 1, 1 } or { 0.35, 0.35, 0.35, 0.32 })
      for _, cell in ipairs({ { 0, 0, 0 }, { 1, 0, 1 },
          { 0, 1, 2 }, { 1, 1, 3 } }) do
        local quad = asset.quads[base + cell[3]]
        if quad then
          local px = (flip and (1 - cell[1]) or cell[1]) * 8 * scale
          render.G.draw(asset.image, quad, x + px + (flip and 8 * scale or 0),
            y + cell[2] * 8 * scale, 0, sx * scale, scale)
        end
      end
    end
    local gbc = compat.gen2PaletteModules()
    if asset.palette and gbc and gbc.available() then
      gbc.with(asset.palette, paint)
    else
      paint()
    end
    return true
  end

  -- Game path [Gen 1/2/3]: badge names/art come from Kanto card assets, Johto/Kanto badge sets, or Gen 3 edition-specific definitions.
  function displayRuntime.trainerModel(context)
    context = context or {}
    local model = displayRuntime.trainerSummary(context.region)
    model.kind = context.kind or "front"
    model.drawPlayer = function(x, y, scale)
      compat.drawMapMarker(x, displayRuntime.gen3 and y - 3 or y,
        displayRuntime.gen3 and 1 or scale, false, "down")
    end
    local badgeIds = compat.isGen2() and THEME.gen2Badges[model.badgeRegion:lower()]
      or session.game.data.constants and session.game.data.constants.badges or {}
    model.badgeNames = {}
    for index = 1, 8 do
      local badge = displayRuntime.gen3 and displayRuntime.gen3.flagDefinitions.BADGES[index] or badgeIds[index]
      model.badgeNames[index] = THEME:translate(type(badge) == "table" and (badge.name or badge.id) or badge or "--")
    end
    if session.spriteCache.__badges == nil then
      local ok, card = false, nil
      if not compat.isGen2() and not displayRuntime.gen3 then
        ok, card = pcall(require("src.ui.Screens").build, session.game, compat.screenName("trainerCard", false))
      end
      session.spriteCache.__badges = ok and card and card.badges or false
    end
    model.drawBadge = function(index, cx, cy, owned)
      if displayRuntime.gen3 then return displayRuntime.gen3:drawBadge(render.G, index, cx, cy, owned) end
      if compat.isGen2() then return compat.drawGen2Badge(badgeIds[index], cx - 6, cy - 6, owned, 0.75) end
      local asset = session.spriteCache.__badges
      local quad = asset and asset.quads and asset.quads[index - 1]
      if not quad then return false end
      local _, _, w, h = quad:getViewport()
      local scale = math.min(1, 14 / math.max(w, h))
      local palette = PaletteFX.pal(session.game.data, "MEWMON")
      local function paint()
        local tint = palette and { 1, 1, 1 } or owned and render.INK or render.DARK
        render.G.setColor(tint[1], tint[2], tint[3], owned and 1 or 0.28)
        render.G.draw(asset.img, quad, cx - w * scale / 2, cy - h * scale / 2, 0, scale, scale)
      end
      local gbc = require("src.render.GbcPalette")
      if palette and gbc.available() then gbc.with(palette, paint) else paint() end
      return true
    end
    -- Game path [Gen 3]: stars/card colors and record text use each editions native policy, including RS and Emerald-specific gatherers.
    if displayRuntime.gen3 then
      -- Gen 3 cards earn stars and change colour; mirror the game's own count.
      local native = context.native or require("src.ui.game3.trainer_card")
      local ok, card = pcall(function() return context.card or displayRuntime.gen3:trainerCardData(native) end)
      card = ok and card or nil
      if card then
        model.stars = math.max(0, math.min(4, math.floor(tonumber(card.stars) or 0)))
        model.cardFamily = displayRuntime.gen3.hoenn and "hoenn" or "kanto"
      end
      if card and model.kind == "records" then
        model.records = displayRuntime.gen3.rs and displayRuntime.gen3:trainerRecords(card)
          or displayRuntime.TrainerPage.records(native, card,
            displayRuntime.gen3.profile.id == "emerald" and native.backTextsRse ~= nil)
      end
    end
    return model
  end

  -- Game path [Gen 1/2/3]: front-only, regional badge pages, and two-sided records have different native page counts.
  function displayRuntime.trainerContext()
    local number, pages = displayRuntime.trainerPage or 1, 1
    if displayRuntime.gen3 then pages = 2
    elseif compat.isGen2() then pages = next(session.game.save.player.kantoBadges or {}) and 3 or 2 end
    number = math.max(1, math.min(number, pages))
    return displayRuntime.TrainerPage.context(displayRuntime.gen3 and 3 or compat.isGen2() and 2 or 1, number, pages)
  end

  function displayRuntime.cycleTrainer(direction)
    local context = displayRuntime.trainerContext()
    displayRuntime.trainerPage = (context.number - 1 + direction) % context.pages + 1
    session.dirty = true
  end

  local function drawTrainer()
    if THEME.style == "hgss" then
      local context = displayRuntime.trainerContext()
      header(THEME:translate("TRAINER"), true, context.pages > 1)
      render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
      THEME.hgss:trainer(displayRuntime.trainerModel(context))
      render.G.pop()
      return
    end
    local save = session.game.save or {}
    local player = save.player or {}
    local ownedDex = compat.caughtDex(save)
    local owned = 0
    local dexTotal = 0
    for species, def in pairs(session.game.data.pokemon or {}) do
      if def.dex and (not displayRuntime.gen3 or displayRuntime.gen3:dexNumber(species) ~= nil) then
        dexTotal = dexTotal + 1
        if ownedDex[species] then owned = owned + 1 end
      end
    end
    local badges = session.game.data.constants and session.game.data.constants.badges or {}
    if displayRuntime.gen3 then
      badges = {}
      for _, badge in ipairs(displayRuntime.gen3.flagDefinitions.BADGES) do
        badges[#badges + 1] = { id = badge.name }
      end
    end
    -- Game path [Gen 2]: count all 16 owned badges but draw the currently selected regional set; Gen 1 stores badges as inventory items.
    local shownBadges = badges
    if compat.isGen2() then
      badges = {}
      for _, id in ipairs(THEME.gen2Badges.johto) do
        badges[#badges + 1] = { id = id, region = "johto" }
      end
      for _, id in ipairs(THEME.gen2Badges.kanto) do
        badges[#badges + 1] = { id = id, region = "kanto" }
      end
      shownBadges = {}
      local region = compat.currentRegion()
      for _, id in ipairs(THEME.gen2Badges[region] or THEME.gen2Badges.johto) do
        shownBadges[#shownBadges + 1] = { id = id, region = region or "johto" }
      end
    end
    local inventory = save.inventory or {}
    local playerBadges = player.badges or {}
    local function ownsBadge(badge, index)
      if displayRuntime.gen3 then return displayRuntime.gen3:badge(index) end
      if compat.isGen2() then
        local held = badge.region == "kanto" and (player.kantoBadges or {})
          or playerBadges
        return held[badge.id] or held[index]
      end
      return inventory[badge.item or badge.id]
    end
    local badgeCount = 0
    if compat.isGen2() then
      for _, region in ipairs({ "johto", "kanto" }) do
        for i, id in ipairs(THEME.gen2Badges[region]) do
          if ownsBadge({ id = id, region = region }, i) then
            badgeCount = badgeCount + 1
          end
        end
      end
    else
      for i, badge in ipairs(badges) do
        if ownsBadge(badge, i) then badgeCount = badgeCount + 1 end
      end
    end
    local elapsed = math.max(0, math.floor(compat.playSeconds(save)))

    if session.spriteCache.__badges == nil then
      local ok, card = false, nil
      if not compat.isGen2() and not displayRuntime.gen3 then
        local screens = require("src.ui.Screens")
        ok, card = pcall(screens.build, session.game,
          compat.screenName("trainerCard", false))
      end
      session.spriteCache.__badges = ok and card and card.badges or false
    end
    local badgeAsset = session.spriteCache.__badges
    local gen1BadgeColors = not compat.isGen2()
      and PaletteFX.pal(session.game.data, "MEWMON") or nil

    header(THEME:translate("TRAINER"), THEME.style == "hgss"
      and displayRuntime.home.activeApp ~= nil,
      THEME.style ~= "hgss")
    box("fill", 4, 22, 152, 50, render.MID)
    outline(4, 22, 152, 50, render.INK)
    text(fit(player.name or "RED", 12), 8, 27, render.INK)
    text(THEME:format("ID %05d", player.id or 0), 89, 27, render.DARK)
    box("fill", 8, 43, 144, 1, render.DARK)
    text(THEME:format("%s %d/%d", THEME:translate("BADGES"),
      badgeCount, #badges), 8, 48, render.DARK)
    for i, badge in ipairs(shownBadges) do
      local badgeOwned = ownsBadge(badge, i)
      local quad = badgeAsset and badgeAsset.quads and badgeAsset.quads[i - 1]
      if compat.isGen2() then
        local x, y = 11 + (i - 1) * 18, 57
        if not compat.drawGen2Badge(badge.id, x, y, badgeOwned, 0.75) then
          box("fill", x, y, 12, 12, badgeOwned and render.DARK or render.MID)
          outline(x, y, 12, 12, render.INK)
          text(badge.id:sub(1, 1), x + 2, y + 2,
            badgeOwned and render.PAPER or render.DARK)
        end
      elseif quad then
        local x = math.floor(5 + (i - 1) * 134
          / math.max(1, #badges - 1))
        local colors = badgeOwned and gen1BadgeColors
        local function paint()
          local tint = badgeOwned and render.INK or render.DARK
          if colors then render.G.setColor(1, 1, 1, 1)
          else render.G.setColor(tint[1], tint[2], tint[3], badgeOwned and 1 or 0.25) end
          render.G.draw(badgeAsset.img, quad, x, 56)
        end
        local gbc = require("src.render.GbcPalette")
        if colors and gbc.available() then gbc.with(colors, paint)
        else paint() end
      else
        local badgeGap = 152 / math.max(1, #badges)
        local x = math.floor(4 + (i - 1) * badgeGap)
        local nextX = math.floor(4 + i * badgeGap)
        box("fill", x + 4, 61, math.max(2, nextX - x - 7), 7,
          badgeOwned and render.DARK or render.MID)
        outline(x + 4, 61, math.max(2, nextX - x - 7), 7, render.INK)
      end
    end
    box("fill", 4, 76, 74, 29, render.PAPER)
    outline(4, 76, 74, 29, render.INK)
    text(THEME:translate("MONEY"), 8, 80, render.DARK)
    text(fit(THEME:format("¥%d", player.money or save.money or 0), 11), 8, 92, render.INK)
    box("fill", 82, 76, 74, 29, render.PAPER)
    outline(82, 76, 74, 29, render.INK)
    text(THEME:translate("TIME"), 86, 80, render.DARK)
    text(("%d:%02d"):format(math.floor(elapsed / 3600),
      math.floor(elapsed / 60) % 60), 86, 92, render.INK)
    box("fill", 4, 109, 74, 29, render.PAPER)
    outline(4, 109, 74, 29, render.INK)
    text(THEME:translate("POKEDEX"), 8, 113, render.DARK)
    text(("%d/%d"):format(owned,
      session.game.data.constants and session.game.data.constants.dexSize or dexTotal), 8, 125, render.INK)
    box("fill", 82, 109, 74, 29, render.PAPER)
    outline(82, 109, 74, 29, render.INK)
    text(THEME:translate("STEPS"), 86, 113, render.DARK)
    text(fit(assist("journey_stats") and compactSteps(session.steps) or "--", 8), 86, 125, render.INK)
    text(">", 146, 120, render.DARK)
  end

  return drawTrainer
end
