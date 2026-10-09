return function(T, display, runtime, gen, up)
  local draw = up(runtime.battlePortrait, "drawSprite")
  local sprite = up(draw, "sprite")
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
end
