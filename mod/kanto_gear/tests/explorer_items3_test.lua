local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  require("src.ui.game3.screens").get("party",game.session).close()
  require("src.ui.game3.bag_menu").close()
  require("src.ui.game3.stack").clear()
  require("src.ui.game3.message").reset()
  require("src.ui.game3.choice").reset()
  game.phase = "field"
  display.gen3.syncScreens()
  for _, hook in ipairs(run.loader.hooks.chains["render.compose"]) do
    if hook.owner == "kanto_gear" then
      for index=1,debug.getinfo(hook.callback,"u").nups do
        local name,value=debug.getupvalue(hook.callback,index)
        if name=="refreshBattle" then value() end
      end
    end
  end
  if os.getenv("POKEPORT_VERSION") == "emerald" then
    local id = "EM_MOSSDEEP_CITY"
    local groups = display.gen3:areaMaps(id)
    local rows = display.gen3Progress:rows(groups)
    local names, required, bonus = {}, 0, 0
    for category = 2,3 do for _, row in ipairs(rows[category]) do
      names[row.label] = true
      if row.optional then bonus = bonus + 1
      else
        required = required + 1
        display.gen3.Flags.setFlag(game.session,nil,row.event,true)
      end
    end end
    T.eq(required,4,"native Mossdeep has four required items across city and buildings")
    T.eq(bonus,1,"native Eon Ticket is the one separate bonus")
    for _, name in ipairs({"NET BALL","KING'S ROCK","SUPER ROD","SUN STONE","EON TICKET"}) do
      T.check(names[name],"native Mossdeep catalogue includes "..name)
    end
    game.session.map = id
    run.loader.events:emit("map.entered",{game=game,mapId=id})
    run.loader.modOptions.kanto_gear.info_level = "spoiler"
    display.setPackageInstalled("explorer",true)
    display.openHomeApp("explorer")
    display.explorer.view = "items"
    display.gen3:refresh()
    local overview = {mapId=id,width=80,height=80,markers={},rows={}}
    for i=1,80 do overview.rows[i]=string.rep(".",80) end
    local model = display.explorerModel(overview)
    T.eq(model.total,5,"native city, indoor rewards and bonus all appear in Explorer")
    T.eq(model.itemsText,"4/4","native Explorer matches the reported completed stamp")
    T.eq(model.itemProgress.optional,1,"native missing event ticket never inflates required total")
    local indoors=0
    for _, marker in ipairs(model.markers) do
      if marker.entrance then
        indoors=indoors+1
        T.check(marker.source.mapId~=id,"indoor finds retain their actual map ID")
      end
    end
    T.eq(indoors,3,"all three indoor reward maps resolve through native building warps")
  end
  dofile(path.."/tests/explorer_items_cases.lua")(T,run,display)
end
dofile(path.."/tests/gen3_fixture.lua")
