return function(T, run, display)
  local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
  local game = up(display.explorerModel, "game")
  local compat = up(display.explorerModel, "compat")
  local definitions = compat.isGen2() and game.data.gen2Maps or game.data.maps
  local city, house = "KG_ITEM_CITY", "KG_ITEM_HOUSE"
  definitions[city] = { outdoor = true, width = 20, height = 20,
    warps = { { x = 7, y = 9, destMap = house } } }
  definitions[house] = { outdoor = false, width = 10, height = 10 }
  local originals = {}
  local requested
  originals.areaMaps = up(display.explorerModel, "areaMaps", function() return {city, house} end, true)
  originals.areaData = up(display.explorerModel, "areaData", function(ids)
    requested = ids
    local rows = {}
    for _, id in ipairs(ids) do
      for index = 1, id == house and 3 or 2 do
        rows[#rows + 1] = { mapId = id, id = id .. index, kind = "item",
          x = index + 1, y = 4, label = id .. index, event = 100 + index,
          done = index ~= 3, optional = index == 3 or nil }
      end
    end
    return { sections = { { rows = {} }, { rows = rows }, { rows = {} } }, pokemon = {} }
  end, true)
  originals.knownMap, originals.position = display.knownMap, display.localMapPosition
  display.knownMap = function() return true end
  display.localMapPosition = function() return { mapId = city, x = 1, y = 1 } end
  local oldMode = run.loader.modOptions.kanto_gear.info_level
  run.loader.modOptions.kanto_gear.info_level = "spoiler"
  display.setPackageInstalled("explorer", true)
  display.openHomeApp("explorer")
  display.explorer.view = "items"
  local overview = { mapId = city, width = 20, height = 20, rows = {}, markers = {} }
  for i = 1,20 do overview.rows[i] = string.rep(".",20) end
  local model = display.explorerModel(overview)
  T.eq(#requested, 2, "Explorer reads the entire progress location")
  T.eq(model.total, 5, "both outdoor finds, both indoor finds and the bonus are listed")
  T.eq(model.itemsText, "4/4", "required counter agrees with Stamps")
  T.eq(model.itemProgress.optional, 1, "event rewards stay a separate bonus")
  T.eq(model.itemProgress.bonusDone, 0, "a missing bonus never looks collected")
  local remote
  for _, marker in ipairs(model.markers) do
    if marker.source.remote then
      remote = marker.source
      T.eq(marker.x,7,"indoor finds mark the building entrance")
      T.eq(marker.y,9,"door y is independent of indoor NPC coordinates")
      T.eq(marker.source.y,4,"the actual indoor position stays intact")
    end
  end
  T.check(remote ~= nil, "indoor finds have an entrance on the city map")
  local resolver = display.explorer.entrances
  display.explorer.data = nil
  model = display.explorerModel(overview)
  T.eq(display.explorer.entrances,resolver,"progress refresh reuses the entrance graph")
  local keys = {}
  for _, marker in ipairs(model.markers) do
    T.check(not keys[marker.source.key],"matching coordinates in separate maps keep distinct identities")
    keys[marker.source.key] = true
  end
  run.loader.modOptions.kanto_gear.info_level = "enhanced"
  display.knownMap = function(id) return id == city end
  display.explorer.data = nil
  model = display.explorerModel(overview)
  T.eq(model.total,4,"undiscovered indoor rewards stay hidden while recorded finds remain visible")
  T.eq(model.itemProgress.optional,0,"bonus counter does not reveal an undiscovered reward")
  run.loader.modOptions.kanto_gear.info_level = "spoiler"
  display.knownMap = function() return true end
  display.explorer.data = nil
  display.explorer.selected = remote.key
  model = display.explorerModel(overview)
  local theme = up(display.drawContents,"THEME").hgss
  T.eq(theme:explorerHit(175/1.5,180/1.5,model),"locate","the indoor preview button is touchable")
  T.check(pcall(theme.explorer,theme,model),"indoor item detail renders")
  T.check(display.openExplorerLocation(model.selected),"opens the detached indoor preview")
  T.eq(display.explorer.locationPreview.locationPoint,model.selected,"preview starts at exact indoor coordinates")
  T.eq(display.updateMapRefresh(love.timer.getTime()),false,"live map repaint cannot cover the preview")
  local input
  for _, hook in ipairs(run.loader.hooks.chains["render.compose"]) do
    if hook.owner == "kanto_gear" then input = up(up(hook.callback,"touchEvent"),"tap") end
  end
  theme:achievements({ view="location", location=model.selected,
    entrance=model.selected.entrance, inside=true, section="CITY" })
  input(120/1.5,155/1.5)
  T.eq(display.explorer.locationPreview.locationPoint,model.selected.entrance,"scope button returns to the outdoor entrance")
  input(120/1.5,155/1.5)
  T.eq(display.explorer.locationPreview.locationPoint,model.selected,"scope button restores the exact indoor find")
  local back = up(input,"changePage")
  back(-1)
  T.eq(display.explorer.locationPreview,nil,"back returns from the indoor preview")
  T.eq(display.explorer.selected,remote.key,"back retains the selected item detail")
  T.check(display.openExplorerLocation(model.selected),"preview can reopen after returning")
  display.clearExplorerSnapshot()
  T.eq(display.explorer.locationPreview,nil,"leaving Explorer closes its private preview")
  T.eq(display.explorer.entrances,nil,"reopening rebuilds current mod map definitions")
  display.explorer.data, display.explorer.renderModel = nil,nil
  display.explorerModel(overview,true)
  T.eq(#requested,1,"home widget keeps its inexpensive current-map query")
  up(display.explorerModel,"areaData",originals.areaData,true)
  up(display.explorerModel,"areaMaps",originals.areaMaps,true)
  display.knownMap,display.localMapPosition = originals.knownMap,originals.position
  definitions[city],definitions[house] = nil,nil
  run.loader.modOptions.kanto_gear.info_level = oldMode
  display.explorer.data,display.explorer.renderModel = nil,nil
  display.clearExplorerSnapshot()
end
