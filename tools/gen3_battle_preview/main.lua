local host, root, output = assert(os.getenv("KANTO_GEAR_HOST_PATH")),
  assert(os.getenv("KANTO_GEAR_MOD_PATH")), assert(os.getenv("KANTO_GEAR_PREVIEW_OUTPUT"))
package.path = host .. "/?.lua;" .. host .. "/?/init.lua;" .. package.path
local function value(fn, key, replacement, set)
  for i = 1, debug.getinfo(fn, "u").nups do
    local name, old = debug.getupvalue(fn, i)
    if name == key then if set then debug.setupvalue(fn, i, replacement) end; return old end
  end
end
function love.load()
  local ok, err = xpcall(function()
    love.window.setMode(960, 864, { vsync = 0 }); love.window.minimize()
    local CacheFs = require("src.import.CacheFs")
    local oldRead = CacheFs.read
    CacheFs.read = function(path, ...)
      local f = io.open(os.getenv("POKEPORT_GBA_CACHE") .. "/" .. path:gsub("^data/generated/gba/", ""), "rb")
      if f then local b = f:read("*a"); f:close(); return b end
      return oldRead(path, ...)
    end
    CacheFs.readActive = CacheFs.read
    _G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
      local G = love.graphics
      local theme = value(display.drawContents, "THEME")
      local B, U, M = require("src.core.game3.battle"), require("src.core.game3.battle.ui"), require("src.ui.game3.message")
      local refresh
      for _, entry in ipairs(run.loader.hooks.chains["render.compose"]) do
        if entry.owner == "kanto_gear" then refresh = value(entry.callback, "refreshBattle") end
      end
      local owns = display.gen3Presentation.owns
      value(owns, "active", true, true); value(owns, "displayReady", true, true)
      value(owns, "hasDisplay", function() return true end, true)
      local sheet, upper = G.newCanvas(960, 1080), G.newCanvas(240, 160)
      local cases = { "standard", "gear", "full", "oak", "damage" }
      local Anim = require("src.core.game3.battle.anim")
      local busy = Anim.busy
      for variant, style in ipairs({ "hgss", "hgss_dark" }) do
        run.loader.modOptions.kanto_gear.theme_v3 = style
        run.loader.events:emit("mod.options_changed", { mod = "kanto_gear", key = "theme_v3", value = style })
        for row, mode in ipairs(cases) do
          Anim.busy = mode == "damage" and function() return true end or busy
          M.reset(); require("src.ui.game3.stack").clear()
          local st = require("src.core.game3.battle.state").new({ playerParty = game.session.party,
            foeParty = { game.session.party[2] }, wild = true })
          B._active, B._auto, B._phase, B._st = true, false, "command", st
          U.reset({ headless = true }); U.bindState(st, game.session); U.openMenu(0)
          run.loader.modOptions.kanto_gear.battle_view = mode == "oak" and "gear"
            or mode == "damage" and "full" or mode
          if mode == "oak" then
            local pages = require("src.core.game3.battle.oak_advice").pages({ playerName = "RED" }, "forPetesSake")
            M.show(pages[2], { frame = "voiceover", speed = 0 })
          elseif mode == "damage" then
            B._phase, U._mode = "turn", "text"
            require("src.core.game3.battle.anim").present("player").displayHp = 9
            M.show("CHARMANDER used\nSCRATCH!", { frame = "battle", speed = 0, stay = true })
          end
          display.gen3.syncScreens(); refresh()
          value(owns, "displayReady", true, true)
          assert(owns("panel") == (mode ~= "standard"), "native panel ownership: " .. mode)
          G.setCanvas(upper); G.origin(); G.setScissor(); G.setShader(); G.clear(0, 0, 0, 1)
          U.draw(240, 160); M.draw()
          G.setCanvas(); display.drawContents()
          local lower = value(display.drawContents, "canvas")
          G.setCanvas(sheet); G.origin(); G.setScissor(); G.setShader(); G.setColor(1, 1, 1, 1)
          G.draw(upper, (variant - 1) * 480, (row - 1) * 216 + 28)
          G.draw(lower, (variant - 1) * 480 + 240, (row - 1) * 216, 0,
            240 / lower:getWidth(), 216 / lower:getHeight())
          G.setCanvas()
        end
      end
      Anim.busy = busy
      local pixels = sheet:newImageData(); local png = pixels:encode("png")
      local f = assert(io.open(output, "wb")); f:write(png:getString()); f:close()
      print("Native upper/Gear lower battle comparison: " .. output)
    end
    dofile(root .. "/tests/gen3_runtime_test.lua")
  end, debug.traceback)
  if not ok then print(err) end
  love.event.quit(ok and 0 or 1)
end
