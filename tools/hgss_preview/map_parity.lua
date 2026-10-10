-- Optional offscreen check: retained map updates must match full page pixels.
return function(theme)
  local G = love.graphics
  for _, kind in ipairs({ "explorer", "home" }) do
    local original = theme[kind]
    theme[kind] = function(self, model)
      if not model.overview or not model.player then return original(self, model) end
      if kind == "explorer" then model.mapSnapshot = model.mapSnapshot or {} end
      local tiles = {}
      if kind == "home" then
        if model.help or model.editing or model.library then return original(self, model) end
        for _, tile in ipairs(model.tiles or {}) do
          if tile.widget == "explorer" then tiles[#tiles + 1] = tile end
        end
        if #tiles == 0 then return original(self, model) end
      end
      local target, player = G.getCanvas(), model.player
      local width, height = target:getDimensions()
      local base, retained = G.newCanvas(width, height), G.newCanvas(width, height)
      local under = G.newCanvas(width, height)
      local function copy(from, to)
        G.setCanvas(to); G.origin(); G.setScissor(); G.setShader()
        G.clear(0, 0, 0, 0); G.setBlendMode("alpha", "premultiplied")
        G.setColor(1, 1, 1, 1); G.draw(from); G.setBlendMode("alpha")
      end
      G.push("all")
      copy(target, under)
      G.setCanvas(target)
      original(self, model)
      copy(target, base)
      for _, position in ipairs({ { .25, .25 }, { 2.5, 3.75 }, { 15, 12 },
          { model.overview.width - 1, model.overview.height - 1 } }) do
        model.player = { mapId = player.mapId, x = position[1], y = position[2], facing = "left" }
        copy(under, target)
        original(self, model)
        G.setCanvas()
        local expected = target:newImageData()
        copy(base, retained)
        if kind == "home" then
          for _, tile in ipairs(tiles) do self:homeExplorerMap(model, tile, true) end
        else self:explorerMap(model, true) end
        G.setCanvas()
        local actual = retained:newImageData()
        if expected:getString() ~= actual:getString() then
          local output = assert(os.getenv("KANTO_GEAR_PREVIEW_OUT"))
          for suffix, pixels in pairs({ expected = expected, retained = actual }) do
            local file = assert(io.open(output .. "." .. suffix .. ".png", "wb"))
            file:write(pixels:encode("png"):getString()); file:close()
          end
        end
        assert(expected:getString() == actual:getString(),
          kind .. " retained map pixels differ at " .. position[1] .. "," .. position[2])
        expected:release(); actual:release()
      end
      model.player = player
      copy(base, target)
      G.setCanvas(target); G.pop()
      base:release(); retained:release(); under:release()
    end
  end
end
