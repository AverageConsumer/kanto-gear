local host, mod = assert(os.getenv("KANTO_GEAR_HOST_PATH")), assert(os.getenv("KANTO_GEAR_MOD_PATH"))
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
    _G.KANTO_GEAR_CONTROLS_CAPTURE = function(run, display, game)
      local G, session = love.graphics, game.session
      local Naming, Box = require("src.ui.game3.naming"), require("src.ui.game3.box_storage_ui")
      local Summary, Pc = require("src.ui.game3.summary_menu"), require("src.ui.game3.item_pc")
      local Growth, Release = require("src.ui.game3.stat_growth"), require("src.ui.game3.release_seq")
      local Stack = require("src.ui.game3.stack")
      local theme = upvalue(display.drawContents, "THEME")
      local atlas = G.newCanvas(1920, 1728); atlas:setFilter("nearest", "nearest")
      G.setCanvas(atlas); G.clear(.08,.08,.1,1); G.setCanvas()
      for variant, name in ipairs({"hgss", "hgss_dark"}) do
        run.loader.modOptions.kanto_gear.theme_v3 = name
        run.loader.events:emit("mod.options_changed", { mod="kanto_gear", key="theme_v3", value=name })
        for i = 1, 8 do
          Stack.clear(); Naming.openFlag = false; Box.open = false; Pc.open = false; Summary.open = false
          Growth.close({silent=true}); Release.close(false)
          local mon = session.party[1]
          if i <= 2 then
            Naming.open({ title="NAME", name="TEST", maxLen=7 }); Naming._state.name = "TEST"
            Naming._state.page = i == 1 and 1 or 3
          elseif i <= 4 then
            Box.show({ session=session, subMode="move" })
            session.storage.boxes[session.storage.currentBox].mons[8] = mon
            Box.cursorSlot = 8
            if i == 4 then Box.mode = "party_drawer"; Box.partyCursor = 1 end
          elseif i == 5 then
            Pc.show({ session=session }); Pc._fx = nil; Pc.mode="qty"
            session.storage.items={{id=13,qty=5}}; Pc.row=0; Pc.scroll=0; Pc.qty=3
          elseif i == 6 then
            Summary.openMenu({mon},1,{ session=session,mode="select_move",moveToLearn=22 })
            Summary._slide.active=false; Summary._hmNotice=true
          elseif i == 7 then
            Box.show({session=session}); Release.start({session=session,mon=mon})
          else
            Growth.open(mon,{maxHp=20,atk=10,def=10,spa=10,spd=10,spe=10},
              {maxHp=22,atk=11,def=12,spa=10,spd=11,spe=11})
          end
          display.gen3:refresh(); display.gen3.syncScreens()
          local view=assert(display.startMenu()); assert(display.StartMenu.cursor(view,true))
          local frame=G.newCanvas(240,216); frame:setFilter("nearest","nearest")
          G.push("all"); G.setCanvas(frame); G.origin(); G.setScissor(); G.clear(theme.hgss.colors.surface)
          G.scale(theme.hgssScale,theme.hgssScale)
          display.drawStartMenu(view)
          G.pop()
          G.push("all"); G.setCanvas(atlas); G.origin(); G.setScissor(); G.setShader(); G.setColor(1,1,1,1)
          G.draw(frame, ((i-1)%4)*480, (math.floor((i-1)/4)+(variant-1)*2)*432,0,2,2)
          G.pop(); frame:release()
        end
      end
      local pixels=atlas:newImageData(); local encoded=pixels:encode("png")
      local file=assert(io.open(assert(os.getenv("KANTO_GEAR_PREVIEW_OUTPUT")),"wb"))
      file:write(encoded:getString());file:close();encoded:release();pixels:release();atlas:release()
      print("Native controls preview saved")
    end
    dofile(mod .. "/tests/gen3_controls_test.lua")
  end, debug.traceback)
  if not ok then print(err) end
  love.event.quit(ok and 0 or 1)
end
