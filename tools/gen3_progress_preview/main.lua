local host = assert(os.getenv("KANTO_GEAR_HOST_PATH"))
local mod = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local output = assert(os.getenv("KANTO_GEAR_PREVIEW_OUTPUT"))
package.path = host .. "/?.lua;" .. host .. "/?/init.lua;" .. package.path
local function upvalue(fn, key)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, i)
    if name == key then return value end
  end
end
function love.load()
  local ok, err = xpcall(function()
    love.window.setMode(960, 864, { vsync = 0 }); love.window.minimize()
    love.filesystem.setSymlinksEnabled(true)
    _G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game, maps)
      local G, theme = love.graphics, upvalue(display.drawContents, "THEME")
      require("src.core.game3.tileset_native").install(require("src.core.game3.dataset").cache())
      require("src.core.game3.ow_sprites").install(require("src.core.game3.dataset").cache())
      local Map, Player, Field = require("src.core.game3.map"), require("src.core.game3.player"), require("src.core.game3.field")
      local atlas = G.newCanvas(1440, 1728); atlas:setFilter("nearest", "nearest")
      G.setCanvas(atlas); G.clear(.08, .08, .1, 1); G.setCanvas()
      local scenes = {
        { "FR_ROUTE_2", "album" }, { "FR_ROUTE_2", "detail" },
        { "FR_MT_MOON_B2F", "finds", 2 }, { "SEVII_ONE_ISLAND_TREASURE_BEACH", "finds", 3 },
        { "FR_ROUTE_2", "location", 2 }, { "FR_ROUTE_2", "widget" },
      }
      run.loader.modOptions.kanto_gear.info_level = "spoiler"
      for variant, name in ipairs({ "hgss", "hgss_dark" }) do
        run.loader.modOptions.kanto_gear.theme_v3 = name
        run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = name })
        for i, scene in ipairs(scenes) do
          game.session.map, game.session.x, game.session.y = scene[1], 10, 25
          Map.current, Map._def = scene[1], maps[scene[1]]
          Player.cellX, Player.cellY, Player.px, Player.py = 10, 25, 160, 400
          Field.running = true
          display.gen3:refresh()
          run.loader.events:emit("map.entered", { game = game, mapId = scene[1] })
          display.openHomeApp("achievements")
          local result
          for _ = 1, 2000 do result = display.achievementData(false, true); if result then break end end
          assert(result, "album did not finish")
          local area = assert(display.currentAchievement().area)
          local state = display.achievements
          state.view, state.selected, state.category, state.page = scene[2], area.id, scene[3] or 1, 1
          if state.view == "album" then
            local areas = display.Achievements.visible(result, "spoiler")
            for index, entry in ipairs(areas) do
              if entry.id == area.id then state.page = math.ceil(index / 6) end
            end
          elseif state.view == "location" then
            state.location = assert(area.sections[2].rows[1])
          end
          local model = display.achievementModel()
          if state.view == "location" then assert(model.drawLocation, "native map preview missing") end
          local frame = G.newCanvas(240, 216); frame:setFilter("nearest", "nearest")
          G.push("all"); G.setCanvas(frame); G.origin(); G.setScissor(); G.clear(theme.hgss.colors.surface)
          theme.hgss:headerBar(area.name, true, false)
          if state.view == "widget" then
            theme.hgss:homeAchievements({ stamps = { area = area, mode = "spoiler" } },
              { column = 1, row = 1, columns = 12, rows = 1 }, false)
          else theme.hgss:achievements(model) end
          G.pop()
          G.push("all"); G.setCanvas(atlas); G.origin(); G.setScissor(); G.setColor(1, 1, 1, 1)
          local column, row = (i - 1) % 3, math.floor((i - 1) / 3) + (variant - 1) * 2
          G.draw(frame, column * 480, row * 432, 0, 2, 2)
          G.pop(); frame:release()
        end
      end
      local pixels = atlas:newImageData(); local encoded = pixels:encode("png")
      local file = assert(io.open(output, "wb")); file:write(encoded:getString()); file:close()
      encoded:release(); pixels:release(); atlas:release()
      print("Native progress preview saved: " .. output)
    end
    dofile(mod .. "/tests/gen3_runtime_test.lua")
  end, debug.traceback)
  if not ok then print(err) end
  love.event.quit(ok and 0 or 1)
end
