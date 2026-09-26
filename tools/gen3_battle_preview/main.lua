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
      local sheet, upper = G.newCanvas(960, 2808), G.newCanvas(240, 160)
      local cases = { "standard", "gear", "full", "oak", "damage", "moves", "party", "party-one", "party-action", "party-message", "party-heal", "bag-message", "summary-slide" }
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
          run.loader.modOptions.kanto_gear.battle_view = mode == "standard" and "standard"
            or (mode == "gear" or mode == "oak") and "gear" or "full"
          if mode == "oak" then
            local pages = require("src.core.game3.battle.oak_advice").pages({ playerName = "RED" }, "forPetesSake")
            M.show(pages[2], { frame = "voiceover", speed = 0 })
          elseif mode == "damage" then
            B._phase, U._mode = "turn", "text"
            require("src.core.game3.battle.anim").present("player").displayHp = 9
            M.show("CHARMANDER used\nSCRATCH!", { frame = "battle", speed = 0, stay = true })
          end
          local Party = require("src.ui.game3.party_menu")
          local Bag = require("src.ui.game3.bag_menu")
          local Summary = require("src.ui.game3.summary_menu")
          if mode == "moves" then U._mode = "moves"
          elseif mode:match("^party") then
            local party = {}
            for i = 1, mode == "party-one" and 1 or 6 do
              party[i] = game.session.party[(i - 1) % #game.session.party + 1]
            end
            Party.show(party, { session = game.session, mode = "battle_switch" })
            if mode == "party-action" then
              Party.mode, Party.ACTIONS = "action", { "SHIFT", "SUMMARY", "CANCEL" }
            elseif mode == "party-message" then Party.showMessage("CHARMANDER is already in battle!")
            elseif mode == "party-heal" then Party.startHpAnim(1, 12, 20, 39, function() end) end
          elseif mode == "bag-message" then
            Bag.show(game.session.bag, { session = game.session }); Bag.settle()
            Bag.showMessage("It won't have any effect.")
          elseif mode == "summary-slide" then
            Summary.openMenu(game.session.party, 1, { session = game.session })
            Summary.handleInput({ wasPressed = function(_, key) return key == "right" end })
          end
          display.gen3.syncScreens(); refresh()
          value(owns, "displayReady", true, true)
          if row <= 7 then assert(owns("panel") == (mode ~= "standard"), "native panel ownership: " .. mode) end
          G.setCanvas(upper); G.origin(); G.setScissor(); G.setShader(); G.clear(0, 0, 0, 1)
          U.draw(240, 160)
          require("src.ui.game3.ui_pass").drawUi()
          local Oam = require("src.core.game3.oam")
          Oam.animateSprites(); Oam.buildOamBuffer(); Oam.flush()
          G.setCanvas(); display.drawContents()
          local lower = value(display.drawContents, "canvas")
          G.setCanvas(sheet); G.origin(); G.setScissor(); G.setShader(); G.setColor(1, 1, 1, 1)
          G.draw(upper, (variant - 1) * 480, (row - 1) * 216 + 28)
          G.draw(lower, (variant - 1) * 480 + 240, (row - 1) * 216, 0,
            240 / lower:getWidth(), 216 / lower:getHeight())
          G.setCanvas()
          Party._hpAnim = nil; Summary.close(); Party.close(); Bag.close()
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
