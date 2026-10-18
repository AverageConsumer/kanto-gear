-- Third-party Silph Store modules. Another mod adds its own app to the store with
--
--   local gear = mod.find("kanto_gear")
--   local modules = gear and gear.exports and gear.exports.modules
--   if modules and modules.api == 1 then modules.register({ ... }) end
-- The template is in DEVELOPMENT.md.
--
-- The Gear ships no knowledge of any third-party mod: only a mod that calls the
-- hook appears in the store, and everything it shows is its own - the engine-drawn
-- icon (the Gear's 24x24 pal/rows pixel format, or a draw(x, y) function), the
-- label, the description and the open callback. Installed tiles place and move
-- like every built-in app. While a registered module reports its own surface up
-- (`shown`), the Gear stands down entirely (runtime/hooks.lua).
return function(THEME, displayRuntime, mod, session)
  local M = { specs = {}, order = {}, lastContext = nil }
  displayRuntime.gearModules = M

  local ACCENTS = { blue = true, amber = true, red = true, green = true, slate = true }

  local function refuse(why)
    mod.log:warn("store module refused: %s", why)
    return nil, why
  end

  local function validIcon(icon)
    if type(icon) == "function" then return true end
    if type(icon) ~= "table" or type(icon.pal) ~= "table" or type(icon.rows) ~= "table" then return false end
    if #icon.rows ~= 24 then return false end
    for _, row in ipairs(icon.rows) do
      if type(row) ~= "string" or #row ~= 24 then return false end
      for ch in row:gmatch("[^.o]") do
        if type(icon.pal[ch]) ~= "string" or not icon.pal[ch]:match("^%x%x%x%x%x%x$") then return false end
      end
    end
    return true
  end

  -- the icon lives on the skin (THEME.hgss, built at the Gear's load); a register
  -- that somehow runs earlier is retried at the next availability pass
  local pendingIcons = {}
  function M.addIcon(id, icon, accent)
    local skin = THEME.hgss
    if skin and skin.v4AddAppIcon then
      skin:v4AddAppIcon(id, icon, accent)
    else
      pendingIcons[#pendingIcons + 1] = { id, icon, accent }
    end
  end
  local function flushIcons()
    if #pendingIcons == 0 then return end
    local skin = THEME.hgss
    if not (skin and skin.v4AddAppIcon) then return end
    local queued = pendingIcons
    pendingIcons = {}
    for _, item in ipairs(queued) do skin:v4AddAppIcon(item[1], item[2], item[3]) end
  end

  local function applyEntry(spec, context)
    local supported = true
    if type(spec.available) == "function" then
      local ok, value = pcall(spec.available, context)
      supported = ok and value == true
    end
    local entry = displayRuntime.storeById[spec.id]
    if entry then entry.hidden = not supported end
    local surface = displayRuntime.homeCatalog.surfaces[spec.id .. "_app"]
    if surface then surface.hidden = not supported end
    local package = displayRuntime.homeCatalog.packages[spec.id]
    if package then package.available = supported end
  end

  -- the hook other mods call (exported as mod.exports.modules.register)
  function M.register(spec)
    if type(spec) ~= "table" then return refuse("spec is not a table") end
    local id = spec.id
    if type(id) ~= "string" or not id:match("^[a-z][a-z0-9_]*$") then
      return refuse("id must be a lowercase [a-z0-9_] string")
    end
    if M.specs[id] then return refuse(id .. " is already registered") end
    if displayRuntime.homeCatalog.packages[id] or displayRuntime.storeById[id] then
      return refuse(id .. " collides with a built-in app")
    end
    if type(spec.label) ~= "string" or spec.label == "" or #spec.label > 20 then
      return refuse("label must be a string of at most 20 characters")
    end
    if type(spec.category) ~= "string" or spec.category == "" then return refuse("category required") end
    if type(spec.description) ~= "table" or #spec.description < 1 or #spec.description > 3 then
      return refuse("description must hold 1 to 3 lines")
    end
    for _, line in ipairs(spec.description) do
      if type(line) ~= "string" then return refuse("description lines must be strings") end
    end
    if not validIcon(spec.icon) then
      return refuse("icon must be a draw(x, y) function or { pal, rows } 24x24 art")
    end
    if spec.accent ~= nil and not ACCENTS[spec.accent] then
      return refuse("accent must be blue, amber, red, green or slate")
    end
    if type(spec.open) ~= "function" then return refuse("open callback required") end
    for _, name in ipairs({ "available", "shown" }) do
      if spec[name] ~= nil and type(spec[name]) ~= "function" then return refuse(name .. " must be a function") end
    end

    local iconId = "module/" .. id
    local function text(value) return value ~= "" and ("@app/" .. id .. ":" .. value) or "" end
    THEME.i18n:extend("en", {}, id)

    -- the rows: hidden and unavailable until availability says otherwise
    displayRuntime.homeCatalog.packages[id] = {
      installed = false, available = false, thirdParty = true,
    }
    displayRuntime.homeCatalog.surfaces[id .. "_app"] = {
      package = id, kind = "app", columns = 3, icon = iconId,
      accent = spec.accent or "slate", label = text(spec.label), sortLabel = spec.label,
      hidden = true, thirdParty = true,
    }
    local entry = {
      id = id, icon = iconId, label = text(spec.label), category = text(spec.category),
      description = { text(spec.description[1]), text(spec.description[2] or ""), text(spec.description[3] or "") },
      hidden = true, thirdParty = true,
    }
    displayRuntime.storeCatalog[#displayRuntime.storeCatalog + 1] = entry
    displayRuntime.storeById[id] = entry
    M.addIcon(iconId, spec.icon, spec.accent or "slate")
    if type(spec.translations) == "table" and THEME.i18n and THEME.i18n.extend then
      for language, entries in pairs(spec.translations) do
        THEME.i18n:extend(language, entries, id)
      end
    end
    M.specs[id] = spec
    M.order[#M.order + 1] = id
    if M.lastContext then
      applyEntry(spec, M.lastContext)
      displayRuntime.restoreModuleHome(id)
    end
    session.dirty = true
    displayRuntime.home.widgetCache = nil
    mod.log:info("store module registered: %s (%s)", id, spec.label)
    return true
  end

  -- at game bind: each module decides its availability for this game
  function M.applyAvailability(context)
    M.lastContext = context
    flushIcons()
    for _, id in ipairs(M.order) do applyEntry(M.specs[id], context) end
  end

  -- true while any registered module's own surface is up: the Gear stands down
  function M.anyShown()
    for _, id in ipairs(M.order) do
      local shown = M.specs[id].shown
      if type(shown) == "function" then
        local ok, up = pcall(shown)
        if ok and up == true then return true end
      end
    end
    return false
  end

  -- a press on the module's tile or the store's OPEN APP
  function M.open(id)
    local spec = M.specs[id]
    if spec and M.lastContext then applyEntry(spec, M.lastContext) end
    local package = displayRuntime.homeCatalog.packages[id]
    if not spec or not session.active or not package or not package.installed or package.available == false
        or M.anyShown() then return false end
    local ok, opened = pcall(spec.open)
    if not ok then
      mod.log:warn("store module %s open: %s", id, tostring(opened))
      return false
    end
    return opened == true
  end

  M.exports = { api = 1, register = M.register }
  return M
end
