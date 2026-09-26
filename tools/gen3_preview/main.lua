-- Offscreen renderer verification against the user's imported cache.
local host = assert(os.getenv("KANTO_GEAR_HOST_PATH"))
local mod = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local output = assert(os.getenv("KANTO_GEAR_PREVIEW_OUTPUT"))
package.path = host .. "/?.lua;" .. host .. "/?/init.lua;" .. package.path

function love.load()
  local ok, err = xpcall(function()
    love.window.setMode(960, 640, { vsync = 0 })
    love.window.minimize()
    local edition = assert(os.getenv("POKEPORT_VERSION"))
    require("src.core.GameVersion").set(edition)
    require("src.import.gba.versions").select(edition)
    local Dataset = require("src.core.game3.dataset")
    Dataset.cacheRootOverride = assert(os.getenv("POKEPORT_GBA_CACHE"))
    Dataset.mountExtractRoots()
    local maps = Dataset.buildMaps()
    Dataset.attachMidLayouts(maps, Dataset.cache())
    local Map = assert(loadfile(mod .. "/gen3_map.lua"))()
    local Tilesets = require("src.core.game3.tileset_native")
    Tilesets.install(Dataset.cache())
    local renderer = Map.new(love.graphics, Tilesets)
    local ids, count = {}, 0
    for id in pairs(maps) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
      local ready, reason = renderer:prepare(maps[id])
      assert(ready, id .. ": " .. tostring(reason))
      count = count + 1
    end
    local selected = { "FR_PALLET_TOWN", "FR_ROUTE_1", "FR_VIRIDIAN_CITY",
      "FR_ROUTE_24", "FR_VIRIDIAN_FOREST", "FR_MT_MOON_1F" }
    -- Compare actual GPU output to direct metatile draws, including fractional
    -- scale and clipping, rather than trusting batch construction alone.
    local actual = love.graphics.newCanvas(240, 216)
    local expected = love.graphics.newCanvas(240, 216)
    for _, id in ipairs(selected) do
      assert(renderer:prepare(maps[id]))
      for _, cellSize in ipairs({ 4, 7.5, 16 }) do
        love.graphics.setCanvas(actual)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setColor(1, 1, 1, 1)
        renderer:draw(-7, 13, cellSize)
        love.graphics.setCanvas(expected)
        love.graphics.clear(0, 0, 0, 0)
        local layout, atlas = maps[id].midLayout, renderer.atlas
        for _, upper in ipairs({ false, true }) do
          local texture = upper and atlas.overImage or atlas.image
          if texture then
            for y = 0, renderer.height - 1 do for x = 0, renderer.width - 1 do
              local slot = Tilesets.slotFor(atlas, layout:midAt(x, y))
              local quad = upper and Tilesets.overQuad(atlas, slot) or Tilesets.quad(atlas, slot)
              love.graphics.draw(texture, quad, -7 + x * cellSize, 13 + y * cellSize,
                0, cellSize / 16, cellSize / 16)
            end end
          end
        end
        love.graphics.setCanvas()
        local a, b = actual:newImageData(), expected:newImageData()
        assert(a:getString() == b:getString(), id .. " pixels differ at scale " .. cellSize)
        a:release(); b:release()
      end
    end
    actual:release(); expected:release()
    local canvas = love.graphics.newCanvas(960, 640)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.06, 0.08, 0.11, 1)
    for i, id in ipairs(selected) do
      assert(renderer:prepare(assert(maps[id], id)))
      local x, y = ((i - 1) % 3) * 320, math.floor((i - 1) / 3) * 320
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print(id, x + 8, y + 6)
      local scale = math.min(304 / renderer.width, 282 / renderer.height)
      renderer:draw(x + (320 - renderer.width * scale) / 2,
        y + 30 + (282 - renderer.height * scale) / 2, scale)
    end
    love.graphics.setCanvas()
    local pixels = canvas:newImageData()
    local bytes = pixels:encode("png")
    local file = assert(io.open(output, "wb"))
    file:write(bytes:getString())
    file:close()
    bytes:release(); pixels:release(); canvas:release(); renderer:release()
    print(string.format("Gen3 render %s: %d native map geometries and 18 pixel comparisons passed; saved %s", edition, count, output))
  end, debug.traceback)
  if not ok then print(err) end
  love.event.quit(ok and 0 or 1)
end
