return function(
  Area, PaletteFX, PokemonSprites, THEME, box, color,
  compat, displayRuntime, mod, render, session
)
  local function hasItemfinder()
    return ((session.game.save.inventory or {}).ITEMFINDER or 0) > 0
  end

  -- Game path [Gen 1/2/3]: hidden-item sources differ; Gen 3 uses its native scanner, Gen 2 event proofs, Gen 1 hiddenTaken records.
  local function radarSignals()
    if displayRuntime.gen3 then return displayRuntime.gen3:itemfinderSignals() end
    local world = session.game and (session.game.overworld or session.game.world)
    local player = world and world.player
    if not player then return {} end
    if compat.isGen2() then
      local out = {}
      for _, item in ipairs(Area.gen2Hidden(session.game.data, mod.world, session.mapId)) do
        if item.available and item.x and item.y
            and Area.itemfinderNear(
              player.cellX, player.cellY, item.x, item.y) then
          out[#out + 1] = {
            dx = item.x - player.cellX, dy = item.y - player.cellY,
          }
        end
      end
      return out
    end
    local field = session.game.data.field or {}
    local hidden = field.hiddenItems and field.hiddenItems[session.mapId] or {}
    local taken, out = session.game.save.hiddenTaken or {}, {}
    for _, item in ipairs(hidden) do
      local key = session.mapId .. "_" .. item.x .. "_" .. item.y
      if not taken[key]
          and not Area.pickupBounds({ x = item.x, y = item.y }, session.game.data.maps[session.mapId]).outsideMap
          and Area.itemfinderNear(
            player.cellX, player.cellY, item.x, item.y) then
        out[#out + 1] = {
          dx = item.x - player.cellX, dy = item.y - player.cellY,
        }
      end
    end
    return out
  end

  -- Game path [Gen 2 vs Gen 1]: Pokegear supplies colored regional sheets; Gen 1 supplies one TownMap tilemap.
  local function loadMap()
    if session.mapAsset ~= nil then return session.mapAsset or nil end
    if compat.isGen2() then
      local gfx = session.game and session.game.data and session.game.data.gen2MenuGfx
        and session.game.data.gen2MenuGfx.pokegear
      if not (gfx and gfx.tiles and gfx.maps) then
        session.mapAsset = false
        return nil
      end
      local ok, image = pcall(render.G.newImage, gfx.tiles)
      if not ok then
        session.mapAsset = false
        return nil
      end
      image:setFilter("nearest", "nearest")
      local iw, ih = image:getDimensions()
      local across = gfx.tilesWide or math.floor(iw / 8)
      local quads = {}
      for i = 0, across * math.floor(ih / 8) - 1 do
        quads[i] = render.G.newQuad((i % across) * 8, math.floor(i / across) * 8,
                             8, 8, iw, ih)
      end
      session.mapAsset = { image = image, quads = quads, maps = gfx.maps,
        palettes = gfx.palettes, palMap = gfx.palMap, gen2 = true }
      return session.mapAsset
    end
    local townMap = session.game and session.game.data and session.game.data.field
      and session.game.data.field.townMap
    local bg = townMap and townMap.background
    if not (bg and bg.map and bg.tiles and bg.tiles.path) then
      session.mapAsset = false
      return nil
    end
    local ok, image = pcall(render.G.newImage, bg.tiles.path)
    if not ok then
      session.mapAsset = false
      return nil
    end
    image:setFilter("nearest", "nearest")
    local iw, ih = image:getDimensions()
    local across = math.floor(iw / 8)
    local quads = {}
    for i = 0, across * math.floor(ih / 8) - 1 do
      quads[i] = render.G.newQuad((i % across) * 8, math.floor(i / across) * 8,
                           8, 8, iw, ih)
    end
    session.mapAsset = { image = image, quads = quads, map = bg.map }
    return session.mapAsset
  end

  -- Game path [Gen 3]: native sprite readers preserve internal species IDs, personality forms, eggs and shininess from the source Pokemon.
  local function sprite(species, side, mon, kind)
    kind = kind or mon and mon.spriteKind or "summary"
    if displayRuntime.gen3 then
      local P = displayRuntime.gen3.Pokemon
      local def = session.game.data.pokemon[species]
      local id = def and def.index
      if not id then return nil end
      -- Battle snapshots wrap the projected Pokemon. Never derive shininess
      -- from a display-only record whose trainer/personality fields are absent.
      mon = mon and (mon.source or mon)
      local picId = mon and P.monPicSpecies(mon) or id
      local shiny = false
      if mon then
        if mon.shiny ~= nil then shiny = mon.shiny == true
        elseif mon.isShiny ~= nil or mon.personality ~= nil
            and (mon.otId ~= nil or mon.trainerId ~= nil) then
          shiny = P.isShiny(mon)
        end
      end
      local pic = side == "back" and P.backPic(picId, nil, shiny, kind)
        or P.frontPic(picId, nil, shiny, mon and mon.personality, kind)
      -- Native ROM pictures carry the host's cache marker. Generated mod
      -- canvases can have no path; never mix their art with ROM animation frames.
      return pic and pic.image, true, pic and (pic.path ~= nil or pic.lru ~= true)
    end
    local path, trueColor = PokemonSprites.path(
      session.game and session.game.data, species, side,
      { kind = kind, mon = mon })
    if not path then return nil end
    local Assets = require("src.render.Assets")
    local resolved = Assets.resolve(path)
    local def = session.game.data.pokemon[species]
    local original = side == "back" and def.spriteBack or def.spriteFront
    local replaced = path ~= original or resolved ~= path
    path = resolved
    local key = side .. ":" .. path
    if session.spriteCache[key] == nil then
      local ok, image = pcall(render.G.newImage, path)
      if not (ok and image) then
        local dataOk, data = pcall(
          require("src.render.Assets").imageData, path)
        if dataOk and data then ok, image = pcall(render.G.newImage, data) end
      end
      if ok and image then image:setFilter("nearest", "nearest") end
      session.spriteCache[key] = ok and image or false
    end
    return session.spriteCache[key] or nil, trueColor, replaced
  end

  -- Crystal front-pic animations come from the host's ROM-derived MonAnim
  -- data. Detail portraits and the selected party member replay the menu scene; Gold,
  -- Silver, older hosts and replaced sprites keep the static picture.
  session.picAnims, session.picAnimSeed = {}, 0
  -- Game path [Crystal]: ROM front-pic menu animations require extracted anim data; Gold/Silver and replaced sprites stay static.
  local function picAnimFrame(species, mon, maxW, tint, animate)
    if tint or (maxW < 48 and animate ~= true) or compat.partyEgg(mon)
        or not compat.isGen2() or displayRuntime.gen3
        or THEME.style ~= "hgss" or not displayRuntime.motionEnabled() then return nil end
    local def = session.game and session.game.data and session.game.data.pokemon and session.game.data.pokemon[species]
    if not (def and def.anim) then return nil end
    local okView, MonAnimView = pcall(require, "src.render.MonAnimView")
    if not okView or type(MonAnimView) ~= "table" or not MonAnimView.start then return nil end
    local key = tostring(species) .. ":" .. tostring(mon and mon.shiny)
    local now = love.timer.getTime()
    local state = session.picAnims[key]
    if not state then
      session.picAnimSeed = session.picAnimSeed + 1
      state = { next = now + 0.4 + (session.picAnimSeed % 5) * 0.7 }
      session.picAnims[key] = state
    end
    if not state.view and now >= state.next then
      local path = PokemonSprites.path(session.game.data, species, "front",
        { kind = "summary", mon = mon })
      local ok, view = pcall(MonAnimView.start, def, mon, "menu", function(p)
        local loaded, image = pcall(require("src.render.Assets").image, p)
        if loaded and image then image:setFilter("nearest", "nearest") end
        return loaded and image or nil
      end, nil, { staticReplaced = MonAnimView.replaced(def.spriteFront, path) })
      state.view, state.last = ok and view or nil, now
      if not state.view then state.next = now + 30 end
    end
    THEME.hgss:wantAmbient(0.3, state.view and 1 / 20 or nil)
    if not state.view then return nil end
    local steps = math.min(30, math.floor((now - state.last) * 60))
    state.last = state.last + steps / 60
    for _ = 1, steps do
      local ok, done = pcall(state.view.step, state.view)
      if not ok or done then
        state.view, state.next = nil, now + 5 + (session.picAnimSeed % 3)
        return nil
      end
    end
    local ok, sheet, quad, size = pcall(state.view.frame, state.view)
    if ok and sheet and quad then return sheet, quad, size end
    return nil
  end

  -- Gen 3 front pics replay their summary-screen animation from the host's
  -- pokeemerald MonAnim port (same data the native summary uses). Battles
  -- are left alone so the companion never shares animation slots with them.
  displayRuntime.gen3Anims = { seed = 0 }
  -- Host path [Gen 3]: summary animations use the optional native MonAnim port and separate slots; battle animation ownership remains native.
  function displayRuntime.gen3PicAnim(species, mon, maxW, tint, animate)
    local gen3Anims = displayRuntime.gen3Anims
    if tint or (maxW < 48 and animate ~= true) or compat.partyEgg(mon)
        or not displayRuntime.gen3 or session.battle
        or THEME.style ~= "hgss" or not displayRuntime.motionEnabled() then return nil end
    local okAnim, MonAnim = pcall(require, "src.core.game3.mon_anim")
    if not okAnim or type(MonAnim) ~= "table" or not MonAnim.newSprite then return nil end
    local okEnabled, enabled = pcall(MonAnim.enabled)
    if not (okEnabled and enabled) then return nil end
    local P = displayRuntime.gen3.Pokemon
    local def = session.game.data.pokemon[species]
    local source = mon and (mon.source or mon)
    local picId = source and P.monPicSpecies and select(2, pcall(P.monPicSpecies, source))
    picId = tonumber(picId) or def and def.index
    if not picId then return nil end
    local shiny = false
    if source then
      if source.shiny ~= nil then shiny = source.shiny == true
      elseif source.personality ~= nil and (source.otId ~= nil or source.trainerId ~= nil) then
        local okShiny, value = pcall(P.isShiny, source)
        shiny = okShiny and value == true
      end
    end
    local key = tostring(picId) .. ":" .. tostring(shiny)
    local now = love.timer.getTime()
    local state = gen3Anims[key]
    if not state then
      gen3Anims.seed = gen3Anims.seed + 1
      state = { next = now + 0.4 + (gen3Anims.seed % 5) * 0.7 }
      gen3Anims[key] = state
    end
    if not state.sprite and now >= state.next then
      local ok, sprite = pcall(MonAnim.newSprite, picId, { hFlip = false })
      if ok and sprite then
        sprite.data[0], sprite.data[1] = picId, 1
        sprite.callback = function(s) MonAnim.summary(s, picId, false) end
        state.sprite, state.last = sprite, now
      else
        state.next = now + 30
      end
    end
    THEME.hgss:wantAmbient(0.3, state.sprite and 1 / 30 or nil)
    if not state.sprite then return nil end
    local steps = math.min(30, math.floor((now - state.last) * 60))
    state.last = state.last + steps / 60
    for _ = 1, steps do
      local ok = pcall(MonAnim.step, state.sprite, true)
      if not ok or (state.sprite.frames or 0) > 600 or MonAnim.done(state.sprite)
          and (state.sprite.frames or 0) > 2 then
        state.sprite, state.next = nil, now + 5 + (gen3Anims.seed % 3)
        return nil
      end
    end
    local frame = state.sprite.frame
    local pic = (tonumber(frame) or 0) > 0 and select(2, pcall(MonAnim.framePic, picId, frame, shiny)) or nil
    return { MonAnim = MonAnim, sprite = state.sprite, pic = type(pic) == "table" and pic or nil }
  end

  local function drawSprite(species, side, x, y, maxW, maxH, tint,
                            mon, quiet, brightness, animate, kind)
    local image = mon and mon.presentationSprite
    local presented = image ~= nil
    local trueColor = image ~= nil and mon.presentationTrueColor ~= false
    mon = mon and (mon.source or mon)
    -- G9 publishes in-memory portraits rather than pokemon.sprite paths.
    -- Its budgeted baker owns the images; do not decode or cache another copy.
    if not image and side == "front" and displayRuntime.frontArt then
      local ok, art, pending = pcall(displayRuntime.frontArt,
        mon and mon.species and mon or { species = species })
      if ok and (type(art) == "userdata" or type(art) == "table")
          and type(art.getDimensions) == "function" then
        image, trueColor, presented = art, true, true
      elseif ok and pending and not displayRuntime.frontArtRetryAt then
        displayRuntime.frontArtRetryAt = love.timer.getTime() + 0.1
      end
    end
    local replaced
    if not image then image, trueColor, replaced = sprite(species, side, mon, kind) end
    if not image then
      if not quiet then box("fill", x + 4, y + 4, maxW - 8, maxH - 8, render.DARK) end
      return false
    end
    local iw, ih = image:getDimensions()
    local scale = math.min(maxW / iw, maxH / ih)
    local sheet, quad, size, anim3
    if side == "front" and not presented and not replaced and animate ~= false
        and (not brightness or brightness >= 1) then
      sheet, quad, size = picAnimFrame(species, mon, maxW, tint, animate)
      if not quad then anim3 = displayRuntime.gen3PicAnim(species, mon, maxW, tint, animate) end
    end
    local function paint()
      color(tint or { brightness or 1, brightness or 1, brightness or 1, 1 })
      if anim3 then
        local pic = anim3.pic and anim3.pic.image or image
        local pw, ph = pic:getDimensions()
        local s = math.min(maxW / pw, maxH / ph)
        render.G.push("all")
        if render.G.transformPoint and render.G.intersectScissor then
          local left, top = render.G.transformPoint(x - 2, y - 2)
          local right, bottom = render.G.transformPoint(x + maxW + 2, y + maxH + 2)
          render.G.intersectScissor(left, top, right - left, bottom - top)
        end
        local ok = pcall(anim3.MonAnim.draw, anim3.sprite, pic,
          x + maxW / 2, y + maxH / 2, { scale = s })
        render.G.pop()
        if ok then return end
      end
      if quad then
        local s = math.min(maxW / size, maxH / size)
        render.G.draw(sheet, quad, x + (maxW - size * s) / 2,
               y + (maxH - size * s) / 2, 0, s, s)
        return
      end
      render.G.draw(image, x + (maxW - iw * scale) / 2,
             y + (maxH - ih * scale) / 2, 0, scale, scale)
    end
    local gbc = require("src.render.GbcPalette")
    local colors
    if not (tint or trueColor) then
      -- Game path [Gen 2 vs Gen 1]: shiny/daytime-aware GBC palettes differ from Gen 1 PaletteFX; true-color art bypasses remapping.
      if compat.isGen2() then
        local _, palettes = compat.gen2PaletteModules()
        colors = palettes and palettes.monColors
          and palettes.monColors(session.game.data.gen2Palettes, species,
                                 mon and mon.shiny)
      else
        colors = PaletteFX.monPal(session.game.data, species,
          mon and mon.transformed)
      end
    end
    color(tint or { brightness or 1, brightness or 1, brightness or 1, 1 })
    local resolved = colors and gbc.remap(gbc.resolve(colors), gbc.bgp)
    if quad or anim3 or not displayRuntime.spriteFilter:draw(image, x + (maxW - iw * scale) / 2,
        y + (maxH - ih * scale) / 2, scale, resolved) then
      if colors and gbc.available() then gbc.with(colors, paint)
      else paint() end
    end
    return true
  end

  function compat.partyEgg(mon)
    if not mon then return false end
    mon = mon.source or mon
    if mon.isEgg == true or mon.egg == true then return true end
    if displayRuntime.gen3 and displayRuntime.gen3.Pokemon.isEgg(mon) then return true end
    local live = mon.slot and session.game and session.game.save and session.game.save.party
      and session.game.save.party[mon.slot]
    return live and live.isEgg == true or false
  end

  -- Game path [Gen 1/2/3]: Gen 3 has native icon/front-pic readers, Gen 2 has category/egg icons, Gen 1 has its own silhouette table.
  function compat.drawPokemonIcon(mon, x, y, size, brightness)
    mon = mon and (mon.source or mon)
    if not mon then return false end
    local data = session.game and session.game.data or {}
    local name, path, isEgg = nil, nil, compat.partyEgg(mon)
    size = size or 27
    if displayRuntime.gen3 then
      local P = displayRuntime.gen3.Pokemon
      -- Eggs use their ROM-derived front picture, never the hatchling's portrait.
      local pic = isEgg and P.frontPic(P.monPicSpecies(mon), nil, false, mon.personality)
        or nil
      pic = pic or P.monIcon(mon)
      if not (pic and pic.image) then return false end
      local fw, fh = pic.w, pic.h
      local quad = pic.quads and pic.quads[0]
      if isEgg and not pic.quads then
        -- The 24px EggPic sits inside a padded 64px front-pic canvas.
        local frame = session.spriteCache.nativeEggFrame
        if not frame or frame.image ~= pic.image then
          frame = { image = pic.image,
            quad = render.G.newQuad(fw / 4, fh / 4, fw / 2, fh / 2, fw, fh) }
          session.spriteCache.nativeEggFrame = frame
        end
        quad, fw, fh = frame.quad, fw / 2, fh / 2
      end
      local scale = math.min(size / fw, size / fh)
      color({ brightness or 1, brightness or 1, brightness or 1, 1 })
      if quad then
        render.G.draw(pic.image, quad, x + (size - fw * scale) / 2,
          y + (size - fh * scale) / 2, 0, scale, scale)
      else
        render.G.draw(pic.image, x + (size - fw * scale) / 2,
          y + (size - fh * scale) / 2, 0, scale, scale)
      end
      return true
    end
    if data.gen2Icons then
      name = isEgg and "ICON_EGG"
        or data.gen2Icons.species and data.gen2Icons.species[mon.species]
      local entry = name and data.gen2Icons.icons
        and data.gen2Icons.icons[name]
      path = entry and entry.image
    else
      local icons = data.icons or {}
      local def = data.pokemon and data.pokemon[mon.species]
      local entry = (icons.bySpecies and icons.bySpecies[mon.species])
        or (def and def.icon)
      if type(entry) == "string" then
        name, path = entry, icons.icons and icons.icons[entry]
      elseif type(entry) == "table" then
        path = entry.image
      end
      if not path then
        name = def and def.dex and icons.byDex and icons.byDex[def.dex]
        path = name and icons.icons and icons.icons[name]
      end
    end
    if not isEgg then
      path = PokemonSprites.iconPath(data, mon, path, { name = name })
    end
    if not path then return false end
    local key = "icon:" .. path
    if session.spriteCache[key] == nil then
      local ok, image = pcall(render.G.newImage, path)
      if not (ok and image) then
        local dataOk, imageData = pcall(
          require("src.render.Assets").imageData, path)
        if dataOk and imageData then ok, image = pcall(render.G.newImage, imageData) end
      end
      if ok and image then image:setFilter("nearest", "nearest") end
      session.spriteCache[key] = ok and image or false
    end
    local image = session.spriteCache[key]
    if not image then return false end
    local iw, ih = image:getDimensions()
    local fw, fh = math.min(16, iw), math.min(16, ih)
    local quad = render.G.newQuad(0, 0, fw, fh, iw, ih)
    local scale = math.min(size / fw, size / fh)
    local function paint()
      color({ brightness or 1, brightness or 1, brightness or 1, 1 })
      render.G.draw(image, quad, x + (size - fw * scale) / 2,
        y + (size - fh * scale) / 2, 0, scale, scale)
    end
    local gbc = compat.gen2PaletteModules()
    local colors = data.gen2Palettes and data.gen2Palettes.partyMenu
      and data.gen2Palettes.partyMenu[1]
    if colors and gbc and gbc.available() then gbc.with(colors, paint)
    else paint() end
    return true
  end

  return drawSprite, hasItemfinder, loadMap, radarSignals
end
