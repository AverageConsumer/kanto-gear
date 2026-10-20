return function(
  THEME, assist, compat, displayRuntime, localMapMode, mod,
  session
)
  local function pageNames()
    if THEME.style == "hgss" then return { "HOME" } end
    local out = { "MAP" }
    if localMapMode(mod.options:get("local_map")) ~= "off" then
      out[#out + 1] = "LOCAL"
    end
    if THEME.style ~= "hgss" then
      if assist("guide") then out[#out + 1] = "GUIDE" end
      if assist("area") then out[#out + 1] = "AREA" end
    end
    out[#out + 1] = "TRAINER"
    out[#out + 1] = "PARTY"
    out[#out + 1] = "TOOLS"
    return out
  end

  function displayRuntime.toolName(def)
    local source = session.game and session.game.data
      and (def.item and session.game.data.items or session.game.data.moves)
    local entry = source and source[def.item or def.move]
    local name = entry and entry.name
      or def.item and def.item:gsub("_", " ")
      or def.move and def.move:gsub("_", " ")
      or def.key:upper():gsub("_", " ")
    if name == "SOFTBOILED" then return "SOFT BOILED" end
    if name == "SQUIRTBOTTLE" then return "SQUIRT BOTTLE" end
    return name
  end

  function displayRuntime.availableTool(actions, actionId, rodId)
    for _, action in ipairs(actions or session.tools) do
      if action.id == actionId then
        if not rodId then return action end
        for _, rod in ipairs(action.rods or {}) do
          if rod.id == rodId then return action end
        end
      end
    end
  end

  -- Game path [Gen 1/2/3]: shared widgets use legacy badge/item checks for Gen 1/2 and the native field-move adapter for Gen 3.
  function displayRuntime.refreshToolSurfaces(actions)
    local save, gen2 = session.game and session.game.save, compat.isGen2()
    for _, def in ipairs(THEME.fieldTools.widgets) do
      local surface = displayRuntime.homeCatalog.surfaces[
        "tool_widget_" .. def.key]
      local unlocked = displayRuntime.gen3 and displayRuntime.gen3:toolUnlocked(def)
        or not displayRuntime.gen3 and THEME.fieldTools.unlocked(def, save, gen2)
      local action = unlocked and displayRuntime.availableTool(
        actions, def.action, def.rod)
      local label = displayRuntime.toolName(def)
      local hidden, ready = not unlocked, action ~= nil
      if surface.hidden ~= hidden or surface.ready ~= ready
          or surface.label ~= label then session.dirty = true end
      surface.hidden, surface.ready = hidden, ready
      surface.label = label
      surface.action = action
    end
  end

  function displayRuntime.toolModels()
    local result, fishing
      = {}, nil
    local save, gen2 = session.game and session.game.save, compat.isGen2()
    for _, def in ipairs(THEME.fieldTools.widgets) do
      if displayRuntime.gen3 and displayRuntime.gen3:toolUnlocked(def)
          or not displayRuntime.gen3 and THEME.fieldTools.unlocked(def, save, gen2) then
        if def.action == "fish" then
          if not fishing then
            local action = displayRuntime.availableTool(nil, "fish")
            fishing = {
              id = "fish", icon = "fish", label = THEME:translate("FISH"),
              ready = action ~= nil, action = action, rods = action and action.rods,
            }
            result[#result + 1] = fishing
          end
        else
          local action = displayRuntime.availableTool(nil, def.action)
          result[#result + 1] = {
            id = def.action, icon = def.icon, label = displayRuntime.toolName(def),
            ready = action ~= nil, action = action,
          }
        end
      end
    end
    -- The Itemfinder lives in the Field Kit too: its card opens the radar.
    if assist("item_radar") and not assist("hidden_items")
        and ((save and save.inventory or {}).ITEMFINDER or 0) > 0 then
      result[#result + 1] = {
        id = "itemfinder", icon = "itemfinder", radar = true, ready = true,
        label = THEME:translate("ITEM RADAR"),
      }
    end
    -- Keep the familiar order within each group, and use the same model for
    -- drawing and touch resolution as availability changes with the context.
    local ordered = {}
    for _, ready in ipairs({ true, false }) do
      for _, action in ipairs(result) do
        if action.ready == ready then ordered[#ordered + 1] = action end
      end
    end
    return ordered
  end

  -- The Pokegear Field Kit draws and resolves touch from one layout, so the
  -- page count follows the cards that actually fit instead of a fixed size.
  function displayRuntime.toolsView()
    local actions = displayRuntime.toolModels()
    local layout = THEME.hgss:toolsLayout(actions)
    session.tools.page = math.max(1, math.min(layout.pages, session.tools.page or 1))
    local armed = session.toolArmed
    if armed and armed.key ~= session.toolsKey then armed, session.toolArmed = nil, nil end
    return { actions = actions, layout = layout, page = session.tools.page,
      pages = layout.pages, armed = armed and armed.id }
  end

  function displayRuntime.needsTools()
    if session.page == "TOOLS" or session.pendingAction or session.fieldChoice then return true end
    if session.page ~= "HOME" then return false end
    local home = displayRuntime.home
    if home.editing or home.library then return true end
    for _, tile in ipairs(home.layout and home.layout.tiles or {}) do
      local surface = displayRuntime.homeCatalog.surfaces[tile.id]
      if tile.page == home.page and surface and surface.widget == "tool" then
        return true
      end
    end
    return false
  end

  local function refreshTools()
    local nextTools, unavailable = {}, nil
    local world = displayRuntime.gen3Field or mod.world
    if world and world.availableFieldActions then
      nextTools, unavailable = world:availableFieldActions()
    end
    -- API 3 returns nil plus a reason when no live world is available.
    nextTools = nextTools or {}
    if unavailable == "world is busy" then
      if session.toolArmed then session.toolArmed, session.dirty = nil, true end
      return
    end
    local keys = {}
    for i, action in ipairs(nextTools) do
      local key = action.id == "bicycle" and "BICYCLE"
        or tostring(action.id):upper()
      local defs = session.game and session.game.data
        and (action.id == "bicycle" and session.game.data.items or session.game.data.moves)
      local def = defs and defs[key]
      if action.label == key and def and def.name then action.label = def.name end
      local context = {}
      for _, rod in ipairs(action.rods or {}) do context[#context + 1] = rod.id end
      for _, source in ipairs(action.sources or {}) do
        context[#context + 1] = "s" .. source.slot
        for _, target in ipairs(source.targets or {}) do
          context[#context + 1] = "t" .. target.slot
        end
      end
      keys[i] = tostring(action.id) .. ":" .. tostring(action.label)
        .. ":" .. table.concat(context, ",")
    end
    local nextKey = table.concat(keys, "|")
    nextTools.page = session.tools.page or 1
    session.tools = nextTools
    displayRuntime.refreshToolSurfaces(session.tools)
    local pages = THEME.style == "hgss" and THEME.hgss:toolsLayout(displayRuntime.toolModels()).pages
      or math.max(1, math.ceil(#session.tools / 6))
    session.tools.page = math.max(1, math.min(pages, session.tools.page or 1))
    if nextKey ~= session.toolsKey then
      session.toolsKey = nextKey
      session.pendingAction = nil
      session.fieldChoice = nil
      session.toolArmed = nil
      session.dirty = true
    end
  end

  return pageNames, refreshTools
end
