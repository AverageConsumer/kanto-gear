-- Offscreen parity and same-viewport comparison; never starts gameplay.
local host = assert(os.getenv("KANTO_GEAR_HOST_PATH"))
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local cache = assert(os.getenv("KANTO_GEAR_LEGACY_CACHE"))
local output = assert(os.getenv("KANTO_GEAR_PREVIEW_OUTPUT"))
local gen2 = os.getenv("POKEPORT_VERSION") == "crystal"
package.path = host .. "/?.lua;" .. host .. "/?/init.lua;" .. package.path
local function bytes(path)
  local f = assert(io.open(path, "rb")); local b = f:read("*a"); f:close(); return b
end
local function file(path) return love.filesystem.newFileData(bytes(path), path) end
local function generated(name) return assert(loadfile(cache .. "/data/generated/" .. name .. ".lua"))() end
function love.load()
  local ok, err = xpcall(function()
    love.window.setMode(960, 648, { vsync = 0 }); love.window.minimize()
    local G = love.graphics
    G.setDefaultFilter("nearest", "nearest")
    require("src.core.GameVersion").set(gen2 and "crystal" or "red")
    local Assets, images = require("src.render.Assets"), {}
    Assets.imageData = function(path) return love.image.newImageData(file(cache .. "/" .. path)) end
    Assets.image = function(path)
      if not images[path] then images[path] = G.newImage(Assets.imageData(path)) end
      return images[path]
    end
    local data = { maps = generated("maps"), tilesets = generated("tilesets"), palettes = generated("palettes") }
    if gen2 then data.gen2Tilesets, data.gen2Palettes, data.gen2Roofs = data.tilesets, data.palettes, generated("roofs") end
    local Palette = require("src.render.PaletteFX")
    Palette.mode = "gbc"
    local Native = assert(loadfile(root .. "/native_map.lua"))()
    local glyphs = assert(loadfile(root .. "/hgss_font_glyphs.lua"))()
    local function font(name) return G.newImageFont(love.image.newImageData(file(root .. "/" .. name)), glyphs) end
    local H = assert(loadfile(root .. "/hgss.lua"))()({ graphics = G,
      color = function(c) G.setColor(c) end,
      box = function(mode, x, y, w, h, c) G.setColor(c); G.rectangle(mode, x, y, w, h) end,
      text = function(s, x, y, c) G.setColor(c); G.print(s, x, y) end,
      fit = function(s, n) return tostring(s):sub(1, n) end,
      glyphs = function(s) local t = {}; for c in tostring(s):gmatch(".") do t[#t + 1] = c end; return t end,
      font = font("hgss_font.png"), smallFont = font("hgss_small_font.png"), largeFont = font("hgss_large_font.png") })
    local ids = gen2 and { "NEW_BARK_TOWN", "GOLDENROD_CITY", "ROUTE_30" }
      or { "PALLET_TOWN", "VIRIDIAN_CITY", "VIRIDIAN_FOREST" }
    local sheet, frame = G.newCanvas(960, 648), G.newCanvas(240, 216)
    local MapType = require(gen2 and "src.world.gen2.Map" or "src.world.Map")
    local Preview = gen2 and require("src.world.gen2.MapPreview")
    local baker = gen2 and Preview.baker(data)
    -- Roof overlays resolve file paths themselves; supply the host's real
    -- ImageData via Assets rather than changing any live game's search paths.
    local originalImageData = love.image.newImageData
    love.image.newImageData = function(value, ...)
      if type(value) == "string" and value:match("^assets/generated/") then value = file(cache .. "/" .. value) end
      return originalImageData(value, ...)
    end
    for row, id in ipairs(ids) do
      local def = assert(data.maps[id], id)
      local map = MapType.new(def, assert(data.tilesets[def.tileset]))
      local world = { map = map, paletteNameFor = function() return "PALLET" end }
      if gen2 then world.mapImage = assert(Preview.bake(baker, map, row == 3 and "NITE" or "DAY"))
      else map.renderer = require("src.render.TileRenderer").new(map, data) end
      local native = Native.new(G)
      local start = love.timer.getTime()
      assert(native:prepare(world, data, gen2))
      local nativeBuild = (love.timer.getTime() - start) * 1000
      start = love.timer.getTime()
      local overview = require("src.world.MapOverview").build(map, {})
      local model = {}; for k, v in pairs(overview) do model[k] = v end
      model.drawTerrain = function(x, y, size) native:draw(x, y, size) end
      local oldImages = {}
      for variant = 1, 2 do
        H:setVariant(variant == 2)
        local rows = overview.tileDetailRows
        local pixels = love.image.newImageData(overview.tileDetailWidth, overview.tileDetailHeight)
        for y, line in ipairs(rows) do for x = 1, #line do
          local c = H:mapColor(overview, x, y, 4, line:sub(x, x))
          pixels:setPixel(x - 1, y - 1, unpack(c))
        end end
        oldImages[variant] = G.newImage(pixels); pixels:release()
      end
      local legacyBuild = (love.timer.getTime() - start) * 1000
      -- Independent original-tile reference, at three fractional/widget scales.
      local expected = G.newCanvas(240, 216)
      for _, size in ipairs({ 2, 5.5, 16 }) do
        G.setCanvas(frame); G.origin(); G.setScissor(); G.clear(0, 0, 0, 0)
        native:draw(-7, 13, size)
        G.setCanvas(expected); G.clear(0, 0, 0, 0); G.setColor(1, 1, 1, 1)
        if gen2 then G.draw(world.mapImage, -7, 13, 0, size / 16, size / 16)
        else
          require("src.render.GbcPalette").withRaw(Palette.effectiveColors(Palette.pal(data, "PALLET") or Palette.GRAYS), function()
            for ty = 0, map.heightCells * 2 - 1 do for tx = 0, map.widthCells * 2 - 1 do
              G.draw(map.renderer.image, map.renderer.quads[map:tileAt(tx, ty)],
                -7 + tx * size / 2, 13 + ty * size / 2, 0, size / 16, size / 16)
            end end
          end)
        end
        G.setCanvas()
        local a, b = frame:newImageData(), expected:newImageData()
        assert(a:getString() == b:getString(), id .. " GPU pixel mismatch at scale " .. size)
        a:release(); b:release()
      end
      expected:release()
      for col = 1, 4 do
        H:setVariant(col > 2)
        G.setCanvas(frame); G.origin(); G.setScissor(); G.setShader(); G.clear(0, 0, 0, 1)
        G.push(); G.scale(1.5, 1.5); H:backdrop(); G.pop()
        local detailed = col % 2 == 0
        H:partyName(detailed and "NATIVE TILES" or "PREVIOUS MAP", 8, 8, H.colors.ink, 224)
        H:partyInfo(id:gsub("_", " "), 8, 28, H.colors.green, 224, "center")
        H:mapOverview(detailed and model or overview, 7, 53, 226, 138,
          { image = oldImages[col > 2 and 2 or 1], player = { x = map.widthCells / 2, y = map.heightCells / 2 } })
        G.setScissor(); G.setCanvas(sheet); G.setColor(1, 1, 1, 1); G.draw(frame, (col - 1) * 240, (row - 1) * 216)
      end
      G.setCanvas()
      -- Same-size warmed redraws + final GPU completion, not a game-FPS claim.
      local function bench(detailed)
        local samples = {}
        for round = 1, 7 do
          G.setCanvas(frame); G.origin(); G.setShader(); G.setScissor(7, 53, 226, 138)
          local t = love.timer.getTime()
          for i = 1, 1000 do
            if detailed then native:draw(10 - i % 8, 53, 4)
            else G.draw(oldImages[1], 10 - i % 8, 53) end
          end
          G.setCanvas(); local pixels = frame:newImageData(); pixels:release()
          samples[#samples + 1] = (love.timer.getTime() - t) * 1000 / 1000
        end
        table.sort(samples); return samples[4]
      end
      local oldMs, newMs = bench(false), bench(true)
      G.setScissor()
      print(("%s: native prepare %.3fms; old overview + two theme rasters %.3fms; warm old %.4fms native %.4fms; builds=%d")
        :format(id, nativeBuild, legacyBuild, oldMs, newMs, native.builds))
      assert(native.builds == (gen2 and 0 or 1), "redraw unexpectedly rebuilt terrain")
      native:release(); for _, image in ipairs(oldImages) do image:release() end
      if gen2 then world.mapImage:release() else map.renderer:releaseBatches() end
    end
    G.setCanvas(); G.setScissor()
    local pixels = sheet:newImageData(); local encoded = pixels:encode("png")
    local f = assert(io.open(output, "wb")); f:write(encoded:getString()); f:close()
    print("Pixel parity passed; Light/Dark comparison saved: " .. output)
  end, debug.traceback)
  if not ok then print(err) end
  love.event.quit(ok and 0 or 1)
end
