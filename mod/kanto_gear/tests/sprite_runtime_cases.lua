return function(T, display, runtime, gen, up)
  local draw = up(runtime.battlePortrait, "drawSprite")
  local sprite = up(draw, "sprite")
  local compat = up(draw, "compat")
  T.check(compat.partyEgg({ source = { isEgg = true } }), "wrapped eggs retain their identity")
  T.check(compat.partyEgg({ egg = true }), "native egg flags are recognized")
  T.eq(compat.partyEgg({ egg = {} }), false, "an egg-details table is not an egg flag")
  local view = display.partyView({ species = gen == 3 and 1 or "FIXMON_A",
    source = { isEgg = true }, hp = 0, name = "HIDDEN HATCHLING", expProgress = 0 })
  T.eq(view.name, up(display.drawContents, "THEME"):translate("EGG"), "party eggs do not reveal the hatchling's name")
  T.eq(view.statusId, nil, "party egg model has no fainted status")
  if gen == 3 then
    local P = display.gen3.Pokemon
    local front, back, captured = P.frontPic, P.backPic
    P.frontPic = function(id, form, shiny, personality)
      captured = { shiny = shiny, personality = personality, id = id }
    end
    P.backPic = function(id, form, shiny) captured = { shiny = shiny } end
    local native = { species = 1, otId = 123, otSecretId = 321, personality = require("bit").bxor(123,321) }
    sprite(1, "front", { source = native })
    T.eq(captured.shiny, true, "raw native Pokemon derives shininess from its real IDs")
    T.eq(captured.personality, native.personality, "individual patterns keep the personality")
    sprite(1, "back", native)
    T.eq(captured.shiny, true, "back portrait also derives real shininess")
    native.shiny = false
    sprite(1, "front", native)
    T.eq(captured.shiny, false, "an explicit projected normal flag remains normal")
    sprite(1, "front", nil)
    T.eq(captured.shiny, false, "species-only previews are not invented shinies")
    sprite(1, "front", { species = 1, personality = 0 })
    T.eq(captured.shiny, false, "display-only records without trainer IDs do not invent shininess")
    native.shiny = nil; native.personality = native.personality + 32
    sprite(1, "front", native)
    T.eq(captured.shiny, false, "a real normal Pokemon stays normal")
    P.frontPic, P.backPic = front, back
    local egg = { species = 1, isEgg = true, personality = 0 }
    T.check(compat.partyEgg({ species = 412 }), "Gen3's egg species is recognized")
    local eggPic = assert(P.frontPic(412, nil, false, 0))
    local G = up(draw, "G")
    local paint, received = G.draw
    G.draw = function(...) received = { ... } end
    T.check(compat.drawPokemonIcon({ source = egg }, 10, 20, 32), "Gen3 egg portrait draws")
    T.eq(received[1], eggPic.image, "egg uses the actual ROM-derived egg, not its hatchling")
    T.eq(received[3], 10, "egg front picture is centered in its portrait")
    T.eq(received[6], 64 / eggPic.w, "transparent padding does not shrink the egg to half size")
    P.frontPic = function() return nil end
    local icon = assert(P.monIcon(egg))
    T.check(compat.drawPokemonIcon(egg, 10, 20, 32), "native egg icon is a fallback")
    T.eq(received[1], icon.image, "fallback retains the egg image")
    T.eq(received[2], icon.quads[0], "fallback crops one full native 32px icon frame")
    P.frontPic, G.draw = front, paint
  else
    local Sprites = require("src.pokemon.Sprites")
    local path, received = Sprites.path
    Sprites.path = function(_, species, side, opts)
      received = opts.mon
      return "sprite-shiny-fixture.png", false
    end
    local mon = { species = "FIXMON_A", shiny = true }
    local compat = up(draw, "compat")
    local palettes, monColors, captured
    if gen == 2 then
      local _; _, palettes = compat.gen2PaletteModules()
      monColors = palettes.monColors
      palettes.monColors = function(_, species, shiny) captured = shiny end
    end
    draw(mon.species, "front", 0, 0, 24, 24, nil, { source = mon }, true)
    T.eq(received, mon, "sprite mods receive the real individual Pokemon")
    if gen == 2 then
      T.eq(captured, true, "nested party portraits retain the shiny palette")
      mon.shiny = false
      draw(mon.species, "front", 0, 0, 24, 24, nil, { source = mon }, true)
      T.eq(captured, false, "normal portrait never reuses a previous shiny palette")
      palettes.monColors = monColors
    end
    Sprites.path = path
  end

  local theme = up(display.drawContents, "THEME")
  if gen ~= 3 then
    local G = up(draw, "G")
    local paint, originalProvider = G.draw, display.frontArt
    local custom = G.newImage("g9-memory-portrait.png")
    local received, painted, requests = nil, nil, 0
    local mon = { species = "FIXMON_A", shiny = true, gender = "female" }
    display.frontArt = function(source)
      received, requests = source, requests + 1
      return custom, custom:getWidth(), custom:getHeight()
    end
    G.draw = function(image, ...) painted = image; return paint(image, ...) end
    local oldAnimation = up(draw, "picAnimFrame")
    local animations = 0
    up(draw, "picAnimFrame", function() animations = animations + 1 end, true)
    for _, kind in ipairs({ "summary", "battle", "dex" }) do
      draw(mon.species, "front", 0, 0, 32, 32, nil, { source = mon }, true, nil, true, kind)
      T.eq(painted, custom, kind .. " portrait uses the provider's in-memory image")
      T.eq(received, mon, "provider receives the live mon with form/shiny/gender data")
    end
    T.eq(animations, 0, "ROM animation cannot overwrite provider art")
    draw(mon.species, "front", 0, 0, 32, 32, nil, nil, true)
    T.eq(received.species, mon.species, "species-only dex/encounter previews also resolve provider art")
    draw(mon.species, "front", 0, 0, 32, 32, nil, { spriteKind = "dex" }, true)
    T.eq(received.species, mon.species, "display-only dex records retain their requested species")
    local before = requests
    draw(mon.species, "back", 0, 0, 32, 32, nil, mon, true)
    T.eq(requests, before, "front-art provider never substitutes a back picture")
    local staged = G.newImage("staged-battle-art.png")
    draw(mon.species, "front", 0, 0, 32, 32, nil,
      { source = mon, presentationSprite = staged }, true)
    T.eq(painted, staged, "explicit battle presentation keeps precedence")
    T.eq(requests, before, "already presented pictures never request provider art")
    display.frontArt = function() return nil, true end
    display.frontArtRetryAt = nil
    local oldMotion = theme.hgss.motionEnabled
    theme.hgss.motionEnabled = false
    draw(mon.species, "front", 0, 0, 32, 32, nil, mon, true)
    T.check(painted ~= custom, "unfinished bake retains the normal fallback")
    T.check(display.frontArtRetryAt ~= nil, "pending art schedules a repaint even in performance mode")
    display.frontArt = function() return custom end
    draw(mon.species, "front", 0, 0, 32, 32, nil, mon, true)
    T.eq(painted, custom, "a completed bake replaces the fallback without reopening the page")
    for _, provider in ipairs({ function() return nil end,
        function() return 42 end, function() error("unavailable") end }) do
      display.frontArt = provider
      T.check(pcall(draw, mon.species, "front", 0, 0, 32, 32, nil, mon, true),
        "missing, incompatible or failing provider retains the normal portrait")
    end
    theme.hgss.motionEnabled = oldMotion
    display.frontArt, display.frontArtRetryAt, G.draw = originalProvider, nil, paint
    up(draw, "picAnimFrame", oldAnimation, true)
  end
  -- Battle-only sprite hooks must reach both the fight button and team cards,
  -- without changing ordinary party portraits or replacing custom art by ROM frames.
  do
    local G = up(draw, "G")
    local Sprites = require("src.pokemon.Sprites")
    local P = gen == 3 and display.gen3.Pokemon
    local originalPath, originalFront, paint = Sprites.path, P and P.frontPic, G.draw
    local replacement = G.newImage("battle-only-replacement.png")
    local received, painted
    local mon = { species = gen == 3 and 1 or "FIXMON_A", name = "CUSTOM",
      level = 5, hp = 10, maxHp = 20, expProgress = 0, shiny = true }
    if P then
      P.frontPic = function(id, form, shiny, personality, kind)
        received = { kind = kind, shiny = shiny }
        if kind == "battle" then return { image = replacement, path = "battle-only-replacement.png" } end
        return originalFront(id, form, shiny, personality, kind)
      end
    else
      Sprites.path = function(data, species, side, opts)
        received = opts
        if opts.kind == "battle" then return "battle-only-replacement.png", true end
        return originalPath(data, species, side, opts)
      end
    end
    G.draw = function(image, ...) painted = image; return paint(image, ...) end
    local originalAnim = up(draw, "picAnimFrame")
    local originalAnim3 = display.gen3PicAnim
    local animationCalls = 0
    up(draw, "picAnimFrame", function(...) animationCalls = animationCalls + 1; return originalAnim(...) end, true)
    display.gen3PicAnim = function(...) animationCalls = animationCalls + 1; return originalAnim3(...) end
    runtime.battlePortrait({ species = mon.species, source = mon }, 0, 0, 56, false)
    T.eq(received.kind, "battle", "fight portrait requests battle art")
    if not P then T.eq(received.mon, mon, "battle hook receives the individual Pokemon")
    else T.eq(received.shiny, true, "battle hook preserves the shiny flag") end
    T.eq(painted.__path, replacement.__path, "fight portrait paints the battle-only replacement")
    T.eq(animationCalls, 0, "native animation cannot overwrite a replaced fight portrait")
    local partyCard = up(up(up(display.drawCompanionPage, "drawNormalParty"), "drawParty"), "partyCard")
    local oldBattle = up(partyCard, "battle", {}, true)
    partyCard(mon, 6, 32, true, true)
    T.eq(received.kind, "battle", "in-battle team card requests battle art")
    T.eq(animationCalls, 0, "selected team card cannot animate ROM art over its replacement")
    up(partyCard, "battle", nil, true)
    partyCard(mon, 6, 32, false, true)
    T.eq(received.kind, "summary", "ordinary party cards keep the summary context")
    up(partyCard, "battle", oldBattle, true)
    up(draw, "picAnimFrame", originalAnim, true)
    display.gen3PicAnim, Sprites.path, G.draw = originalAnim3, originalPath, paint
    if P then P.frontPic = originalFront end
  end
  if gen == 3 then
    local P, G = display.gen3.Pokemon, up(draw, "G")
    local originalFront, originalAnim, paint = P.frontPic, display.gen3PicAnim, G.draw
    local image = G.newImage("generated-front-frame.png")
    local received, animations = nil, 0
    -- G9 Gen3 returns live Canvas pictures without a file path. They must not
    -- acquire ROM animation transforms or switch to ROM front-sheet frames.
    P.frontPic = function() return { image = image, w = 64, h = 64 } end
    display.gen3PicAnim = function() animations = animations + 1 end
    G.draw = function(pic, ...) received = pic; return paint(pic, ...) end
    for _, size in ipairs({ 32, 48, 56 }) do
      for _, kind in ipairs({ "summary", "battle", "dex" }) do
        draw(1, "front", 0, 0, size, size, nil, { species = 1 }, true, nil, true, kind)
        T.eq(received, image, "generated portrait keeps the provider frame in " .. kind)
      end
    end
    T.eq(animations, 0, "generated pictures without paths never acquire ROM animations")
    P.frontPic = function(...) return originalFront(...) end
    local _, _, replaced = sprite(1, "front", { species = 1 })
    T.eq(replaced, false, "a wrapped native picture remains eligible for ROM animation")
    P.frontPic, display.gen3PicAnim, G.draw = originalFront, originalAnim, paint
  end
  local eggFainted
  theme.hgss:partyCard({ name = "EGG", egg = true, hp = 0 }, 6, 32, false, true,
    function(_, _, _, _, fainted) eggFainted = fainted end)
  T.eq(eggFainted, false, "an egg without battle HP is never painted as fainted")
  local oldMotion = display.motionEnabled
  display.motionEnabled = function() return true end
  local anim = gen == 3 and display.gen3PicAnim or up(draw, "picAnimFrame")
  local clock = getfenv(anim).love.timer
  local oldTime, now = clock.getTime, 0
  clock.getTime = function() return now end
  local mon = { species = gen == 3 and 25 or "FIXMON_A", shiny = false }
  local oldBattle
  if gen == 3 then oldBattle = up(anim, "battle", nil, true) end
  local oldCache = gen == 3 and display.gen3Anims or up(anim, "picAnims", {}, true)
  if gen == 3 then display.gen3Anims = { seed = 0 } end
  local data, savedAnim, oldView, calls
  if gen == 2 then
    data = up(anim, "game").data.pokemon[mon.species]
    savedAnim, data.anim = data.anim, true
    oldView, calls = package.loaded["src.render.MonAnimView"], 0
    package.loaded["src.render.MonAnimView"] = {
      replaced = function() return false end,
      start = function()
        calls = calls + 1
        return { step = function() end, frame = function() return {}, {}, 56 end }
      end,
    }
  end
  local G = up(draw, "G")
  local replacement = gen == 3 and display.gen3.Pokemon.frontPic(mon.species).image
    or G.newImage("replacement-portrait.png")
  T.check(draw(mon.species, "front", 0, 0, 32, 32, nil,
    { source = mon, presentationSprite = replacement }, true, nil, true),
    "a replaced portrait still draws")
  T.check(next(gen == 3 and display.gen3Anims or up(anim, "picAnims")) == (gen == 3 and "seed" or nil),
    "replacement portraits never acquire a native animation state")
  draw(mon.species, "front", 0, 0, 32, 32, nil, mon, true, nil, false)
  T.check(next(gen == 3 and display.gen3Anims or up(anim, "picAnims")) == (gen == 3 and "seed" or nil),
    "explicitly inactive party portraits do not start native animations")
  T.eq(anim(mon.species, mon, 32), nil, "unselected small portraits do not start native animations")
  anim(mon.species, mon, 32, nil, true)
  now = 4
  local active = anim(mon.species, mon, 32, nil, true)
  if gen == 2 then
    T.eq(calls, 1, "selected small Crystal portrait starts the native animation view")
    T.check(active ~= nil, "small Crystal portrait receives native animation frames")
  elseif gen == 3 then
    local MonAnim = require("src.core.game3.mon_anim")
    if os.getenv("POKEPORT_VERSION") == "emerald" then
      T.check(MonAnim.enabled(), "Emerald test uses its actual ROM-derived animation data")
    end
    T.eq(active ~= nil, MonAnim.enabled(), "selected small portrait animates only when native data exists")
    if active then
      T.eq(active.sprite.affineMode, "normal", "native rotations and scaling are preserved")
      local changed = false
      for frame = 1, 120 do
        now = 4 + frame / 60
        local result = anim(mon.species, mon, 32, nil, true)
        if result then
          local t = MonAnim.transform(result.sprite)
          changed = changed or result.pic ~= nil or t.x2 ~= 0 or t.y2 ~= 0
            or t.rotation ~= 0 or t.sx ~= 1 or t.sy ~= 1
        end
      end
      T.check(changed, "real Emerald animation advances beyond a static portrait")
    end
  else
    T.eq(active, nil, "Gen1 has no invented native sprite animation")
  end
  T.eq(anim(mon.species, { isEgg = true }, 32, nil, true), nil, "eggs never animate their hidden hatchling")
  display.motionEnabled = function() return false end
  T.eq(anim(mon.species, mon, 48, nil, true), nil, "performance mode disables native sprite animation")
  display.motionEnabled, clock.getTime = oldMotion, oldTime
  if gen == 3 then
    up(anim, "battle", oldBattle, true)
    display.gen3Anims = oldCache
  else
    up(anim, "picAnims", oldCache, true)
    if gen == 2 then
      data.anim, package.loaded["src.render.MonAnimView"] = savedAnim, oldView
    end
  end
end
