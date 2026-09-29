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
      local Map = require("src.core.game3.map")
      local Player = require("src.core.game3.player")
      local Field = require("src.core.game3.field")
      require("src.core.game3.tileset_native").install(require("src.core.game3.dataset").cache())
      require("src.core.game3.ow_sprites").install(require("src.core.game3.dataset").cache())
      local emerald = os.getenv("POKEPORT_VERSION") == "emerald"
      game.session.map, game.session.x, game.session.y = emerald and "EM_ROUTE101" or "FR_ROUTE_1", 10, 15
      Map.current, Map._def = game.session.map, maps[game.session.map]
      Player.cellX, Player.cellY, Player.px, Player.py = 10, 15, 160, 240
      Field.running = true
      display.gen3:refresh()
      run.loader.events:emit("map.entered", { game = game, mapId = game.session.map })
      local outputCanvas = love.graphics.newCanvas(1440, 1080)
      love.graphics.setCanvas(outputCanvas); love.graphics.clear(0.08, 0.08, 0.1, 1)
      love.graphics.setCanvas()
      local labels = { "party", "bag", "pokedex", "trainer", "native-party", "native-bag", "summary", "summary-skills", "summary-moves", "explorer", "map", "notes", "battle", "battle-moves", "battle-targets" }
      local Battle = require("src.core.game3.battle")
      local Ui = require("src.core.game3.battle.ui")
      local refreshBattle
      for _, entry in ipairs(run.loader.hooks.chains["render.compose"] or {}) do
        if entry.owner == "kanto_gear" then refreshBattle = upvalue(entry.callback, "refreshBattle") end
      end
      run.loader.modOptions.kanto_gear = run.loader.modOptions.kanto_gear or {}
      for themeIndex, name in ipairs({ "hgss", "hgss_dark" }) do
        run.loader.modOptions.kanto_gear.theme_v3 = name
        run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = name })
        for i, app in ipairs(labels) do
          local Stack = require("src.ui.game3.stack")
          Stack.clear()
          Battle._active, Battle._st = false, nil
          Ui.reset({ headless = true })
          local Party = require("src.ui.game3.party_menu")
          local Bag = require("src.ui.game3.bag_menu")
          local Summary = require("src.ui.game3.summary_menu")
          if app:match("^battle") then
            local st = require("src.core.game3.battle.state").new({
              playerParty = game.session.party, foeParty = game.session.party,
              wild = app ~= "battle-targets", double = app == "battle-targets" })
            Battle._active, Battle._auto, Battle._phase, Battle._st = true, false, "command", st
            Ui.bindState(st, game.session); Ui.openMenu(app == "battle-targets" and 2 or 0)
            if app == "battle-moves" then Ui._mode = "moves"
            elseif app == "battle-targets" then assert(Ui.chooseTarget(st, 2, 1)) end
          elseif app == "native-party" then Party.show(game.session.party, { session = game.session })
          elseif app == "native-bag" then
            Bag.show(game.session.bag, { session = game.session, pocket = "POKE_BALLS" }); Bag.settle()
          elseif app:match("^summary") then
            Summary.openMenu(game.session.party, 1, { session = game.session,
              page = app == "summary-skills" and 1 or app == "summary-moves" and 2 or 0 })
          else
            assert(display.setPackageInstalled(app, true), app)
            assert(display.openHomeApp(app), app)
          end
          display.gen3.syncScreens()
          refreshBattle()
          if app == "battle-moves" then
            local runtime = upvalue(refreshBattle, "hgssRuntime")
            for _, move in ipairs(runtime.battleMon().moves) do
              assert(move.type == display.gen3.data.moves[move.id].type, "native battle type mismatch")
              assert(move.typeLabel == move.type, "native battle type label mismatch")
            end
          end
          local badge = theme.hgss.moveTypeBadge
          if app == "battle-moves" then
            theme.hgss.moveTypeBadge = function(self, move, ...)
              assert(move.type == display.gen3.data.moves[move.id].type, "drawn battle type mismatch")
              return badge(self, move, ...)
            end
          end
          display.drawContents()
          theme.hgss.moveTypeBadge = badge
          if app == "explorer" then
            assert(display.gen3Map and display.gen3Map.under, "Explorer must render native terrain")
            assert(display.explorer.renderModel and display.explorer.renderModel.player, "Explorer must locate the native player")
            assert(#display.explorer.renderModel.rows > 0, "Route 1 must show wild encounters")
            assert(display.explorer.renderModel.areaEnabled, "Native progress enables the Explorer checklist")
          elseif app == "map" then
            assert(display.homeRegionMap().drawMap, "Region map must use the native map")
          end
          local frame = upvalue(display.drawContents, "canvas")
          love.graphics.setCanvas(outputCanvas); love.graphics.origin(); love.graphics.setScissor()
          love.graphics.setShader(); love.graphics.setColor(1, 1, 1, 1)
          local column, row = (i - 1) % 3 + (themeIndex - 1) * 3, math.floor((i - 1) / 3)
          love.graphics.draw(frame, column * 240, row * 216, 0, 240 / frame:getWidth(), 216 / frame:getHeight())
          love.graphics.setCanvas()
          Party.close(); Bag.close(); Summary.close()
        end
      end
      Battle._active, Battle._st = false, nil
      Ui.reset({ headless = true })
      love.graphics.setCanvas()
      local pixels = outputCanvas:newImageData()
      local encoded = pixels:encode("png")
      local file = assert(io.open(output, "wb")); file:write(encoded:getString()); file:close()
      encoded:release(); pixels:release(); outputCanvas:release()
      print("Gear Light/Dark previews saved: " .. output)
    end
    local ran = false
    local function run()
      ran = true
      dofile(mod .. (os.getenv("POKEPORT_VERSION") == "emerald"
        and "/tests/emerald_runtime_test.lua" or "/tests/gen3_runtime_test.lua"))
    end
    if os.getenv("POKEPORT_VERSION") == "emerald" then
      local root = assert(os.getenv("POKEPORT_GBA_CACHE")):gsub("/data/generated/gba$", "")
      require("src.import.CacheFs").withMounted(root, "", run)
    else run() end
    assert(ran, "Preview cache mount unavailable")
  end, debug.traceback)
  love.graphics.setCanvas()
  if not ok then print(err) end
  love.event.quit(ok and 0 or 1)
end
