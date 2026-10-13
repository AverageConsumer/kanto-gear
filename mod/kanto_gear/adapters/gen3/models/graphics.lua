return function(Gen3)
  function Gen3:drawPlayer(g, x, y, scale, feet, facing)
    local sprites = require("src.core.game3.ow_sprites")
    local spr = sprites.getDraw(sprites.playerGraphicsId(self.game))
    if not spr then return false end
    local frame, flip = sprites.pose(spr, facing or "down", false, false)
    local quad = spr.quads[frame]
    if not quad then return false end
    scale = scale or 1
    g.setColor(1, 1, 1, 1)
    g.draw(spr.image, quad, x + (flip and 0.5 or -0.5) * spr.width * scale,
      y - (feet and spr.height or spr.height / 2) * scale,
      0, flip and -scale or scale, scale)
    return true
  end
  -- Native object graphics use numeric IDs, not the Gen 1/2 SPRITE_* registry.
  function Gen3:mapActor(row)
    local objects = require("src.core.game3.objects")
    local live = objects._mapId == row.mapId and row.index ~= nil
      and objects.find(row.index) or nil
    if live and live.foreignMap then live = nil end
    local flag = tonumber(row.hideEvent)
    local visible = not (flag and flag ~= 0 and flag ~= 0xFFFF
      and self.Flags.getFlag(self:flagStore(), nil, flag))
    if live then visible = live.visible ~= false and not live.hidden and not live.invisible end
    return { id = row.id, mapId = row.mapId, index = row.index,
      x = live and live.cellX or row.x, y = live and live.cellY or row.y,
      graphicsId = live and live.graphicsId or self.Space.resolveObjectGraphicsId(row),
      facing = live and live.facing or row.facing or "down", visible = visible }
  end
  function Gen3:drawActor(g, actor, x, y, scale, feet, tint, maxSize)
    local sprites = require("src.core.game3.ow_sprites")
    local spr = actor.graphicsId ~= nil and sprites.getDraw(actor.graphicsId)
    if not spr then return false end
    local frame, flip = sprites.pose(spr, actor.facing or "down", false, false)
    local quad = spr.quads[frame]
    if not quad then return false end
    scale = scale or 1
    -- UI portrait seats have a fixed size; map actors keep their native scale.
    if maxSize then scale = math.min(scale, maxSize / math.max(spr.width, spr.height)) end
    if tint then g.setColor(unpack(tint)) else g.setColor(1, 1, 1, 1) end
    g.draw(spr.image, quad, x + (flip and 0.5 or -0.5) * spr.width * scale,
      y - (feet and spr.height or spr.height / 2) * scale,
      0, flip and -scale or scale, scale)
    return true
  end
  function Gen3:itemIcon(id)
    id = self.Items.toNumericId(id)
    if not id then return nil end
    local image, quad
    self.itemIcons = self.itemIcons or {}
    local cached = self.itemIcons[id]
    -- Game path [Ruby/Sapphire/Emerald]: bag icons come from the imported Hoenn RGBA atlas; FireRed/LeafGreen uses item icon assets below.
    if self.hoenn then
      local chrome = require("src.ui.game3.rse.bag_chrome")
      local manifest = chrome.manifest()
      local icons = manifest and manifest.icons
      if not icons or id < 0 or id >= icons.count then return nil end
      image = require("src.ui.game3.rse.scene_kit").rgbaImage(icons.rgba, icons.w, icons.h)
      if not image then return nil end
      if cached and cached.image == image then return cached end
      quad = love.graphics.newQuad(0, id * 24, 24, 24, icons.w, icons.h)
    else
      image = require("src.ui.game3.bag_chrome").iconImage(id)
      if not image then return nil end
      if cached and cached.image == image then return cached end
    end
    cached = { image = image, quad = quad, width = 24, height = 24 }
    self.itemIcons[id] = cached
    return cached
  end
  function Gen3:drawBadge(g, index, cx, cy, owned)
    local Kit = require("src.ui.game3.rse.scene_kit")
    local image
    -- Game path [Ruby/Sapphire/Emerald]: badges use the Hoenn trainer-card atlas instead of the Kanto badge strip.
    if self.hoenn then
      local m = Kit.manifest("rse/trainer_card")
      image = m and m.badges and Kit.image(m.badges.png)
    else
      local root = require("src.import.gba.extract_island1").CACHE_ROOT
      local folder = require("src.import.gba.trainer_card_extract").CACHE_SUB
      image = Kit.rgbaImage(root .. "/" .. folder .. "/badges.rgba", 128, 16)
    end
    if not image then return false end
    if not self.badgeAtlas or self.badgeAtlas.image ~= image then
      local w, h = image:getDimensions()
      local quads = {}
      for i = 1, 8 do quads[i] = love.graphics.newQuad((i - 1) * 16, 0, 16, 16, w, h) end
      self.badgeAtlas = { image = image, quads = quads }
    end
    g.setColor(1, 1, 1, owned and 1 or 0.25)
    g.draw(image, self.badgeAtlas.quads[index], cx - 7, cy - 7, 0, 0.875, 0.875)
    return true
  end
  function Gen3:trainerCardData(native)
    local session = self.session
    -- Game path [Ruby/Sapphire]: its card policy computes native stars/records; FireRed/LeafGreen and Emerald expose gatherers below.
    if self.rs then return require("src.ui.game3.rs.trainer_card_policy").generate(session) end
    -- Emerald scores its stars on Hoenn feats (pokeemerald trainer_card.c:679),
    -- not on the FRLG rules the shared gatherer applies.
    -- Game path [Emerald]: Hoenn achievements determine card stars; the shared FireRed/LeafGreen gatherer applies Kanto rules.
    local gather = self.profile.id == "emerald" and native.rseCardData or native.cardData
    local card = gather(session)
    if self.profile.id == "emerald" and native.backTextsRse then
      -- Keep the extra RSE record counters aligned with the session.
      local function stat(id, key, cap)
        local stats = session.gameStats
        local value = type(stats) == "table" and (stats[id] or stats[key]) or session[key]
        return math.min(cap, math.max(0, math.floor(tonumber(value) or 0)))
      end
      card.pokeblocksWithFriends = stat(34, "pokeblocksWithFriends", 65535)
      card.contestsWithFriends = stat(35, "contestsWithFriends", 999)
      card.frontierBP = tonumber((session.frontier or {}).cardBattlePoints) or 0
    end
    return card
  end
  -- Game path [Ruby/Sapphire]: the separate card renderer exposes records through extracted captions and policy values.
  function Gen3:trainerRecords(card)
    -- RS exports a different card renderer. Read its extracted captions and
    -- policy values without opening the native screen or changing its state.
    local manifest = require("src.ui.game3.rse.scene_kit").manifest("rse/trainer_card")
    local rows, labels = {}, manifest.strings
    local function add(key, value) rows[#rows + 1] = { label = labels[key], value = tostring(value) } end
    if card.hofDebutHours ~= 0 or card.hofDebutMinutes ~= 0 or card.hofDebutSeconds ~= 0 then
      add("hof", string.format("%d:%02d:%02d", card.hofDebutHours, card.hofDebutMinutes, card.hofDebutSeconds))
    end
    if card.linkBattleWins ~= 0 or card.linkBattleLosses ~= 0 then
      add("link", card.linkBattleWins .. " / " .. card.linkBattleLosses)
    end
    for _, row in ipairs({ { "trade", "pokemonTrades" }, { "blender", "pokeblocksWithFriends" },
        { "contest", "contestsWithFriends" } }) do
      if card[row[2]] ~= 0 then add(row[1], card[row[2]]) end
    end
    if card.battleTowerWins ~= 0 or card.battleTowerLosses ~= 0 then
      add("tower", card.battleTowerWins .. " / " .. card.battleTowerLosses)
    end
    return rows
  end
end
