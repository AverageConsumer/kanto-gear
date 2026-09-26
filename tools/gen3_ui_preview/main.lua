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
      local theme = upvalue(display.drawContents, "THEME")
      local outputCanvas = love.graphics.newCanvas(1440, 648)
      love.graphics.setCanvas(outputCanvas); love.graphics.clear(0.08, 0.08, 0.1, 1)
      love.graphics.setCanvas()
      local labels = { "party", "bag", "pokedex", "trainer", "native-party", "native-bag", "summary", "summary-skills", "summary-moves" }
      run.loader.modOptions.kanto_gear = run.loader.modOptions.kanto_gear or {}
      for themeIndex, name in ipairs({ "hgss", "hgss_dark" }) do
        run.loader.modOptions.kanto_gear.theme_v3 = name
        run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = name })
        for i, app in ipairs(labels) do
          local Stack = require("src.ui.game3.stack")
          Stack.clear()
          local Party = require("src.ui.game3.party_menu")
          local Bag = require("src.ui.game3.bag_menu")
          local Summary = require("src.ui.game3.summary_menu")
          if app == "native-party" then Party.show(game.session.party, { session = game.session })
          elseif app == "native-bag" then
            Bag.show(game.session.bag, { session = game.session, pocket = "POKE_BALLS" }); Bag.settle()
          elseif app:match("^summary") then
            Summary.openMenu(game.session.party, 1, { session = game.session,
              page = app == "summary-skills" and 1 or app == "summary-moves" and 2 or 0 })
          else display.openHomeApp(app) end
          display.gen3.syncScreens()
          display.drawContents()
          local frame = upvalue(display.drawContents, "canvas")
          love.graphics.setCanvas(outputCanvas); love.graphics.origin(); love.graphics.setScissor()
          love.graphics.setShader(); love.graphics.setColor(1, 1, 1, 1)
          local column, row = (i - 1) % 3 + (themeIndex - 1) * 3, math.floor((i - 1) / 3)
          love.graphics.draw(frame, column * 240, row * 216, 0, 240 / frame:getWidth(), 216 / frame:getHeight())
          love.graphics.setCanvas()
          Party.close(); Bag.close(); Summary.close()
        end
      end
      love.graphics.setCanvas()
      local pixels = outputCanvas:newImageData()
      local encoded = pixels:encode("png")
      local file = assert(io.open(output, "wb")); file:write(encoded:getString()); file:close()
      encoded:release(); pixels:release(); outputCanvas:release()
      print("Gear Light/Dark previews saved: " .. output)
    end
    dofile(mod .. "/tests/gen3_runtime_test.lua")
  end, debug.traceback)
  if not ok then print(err) end
  love.event.quit(ok and 0 or 1)
end
