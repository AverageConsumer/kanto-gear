-- Kanto Gear v4: one icon family for every app, field tool and battle key.
-- The art (ui/skins/icon_art.lua) is 24×24, outlined and shaded top-left like the
-- DS menus; it replaces the line-drawn v3 icons everywhere Pokégear shows them.
return function(H, ui, K)
  local floor = math.floor
  local hex, mix, ART = K.hex, K.mix, K.ART
  local ART_SET = K.iconArt or {}
  local OUT = hex("202830")

  -- Each icon becomes one nearest-filtered image per variant (colour/grey),
  -- so drawing an app grid costs one draw call per icon.
  local images = {}
  local function build(name, grey)
    local spec = ART_SET[name]
    if not spec then return nil end
    local key = name .. (grey and ":g" or "")
    if images[key] ~= nil then return images[key] end
    local ok, img = pcall(function()
      local data = love.image.newImageData(#spec.rows[1], #spec.rows)
      for j, row in ipairs(spec.rows) do
        for i = 1, #row do
          local ch = row:sub(i, i)
          if ch ~= "." then
            local c = ch == "o" and OUT or hex(spec.pal[ch])
            if grey then
              local l = c[1] * 0.3 + c[2] * 0.59 + c[3] * 0.11
              l = 0.35 + l * 0.55
              if ch == "o" then l = 0.32 end
              c = { l, l, l }
            end
            data:setPixel(i - 1, j - 1, c[1], c[2], c[3], 1)
          end
        end
      end
      local image = love.graphics.newImage(data)
      image:setFilter("nearest", "nearest")
      return image
    end)
    images[key] = ok and img or false
    return images[key]
  end

  -- Draws icon `name` with its top-left at x, y (24×24, or 16×16 for s_/c_). Falls back to run
  -- drawing when images cannot be created (headless tests).
  local palCache = {}
  -- third-party store modules (runtime/modules.lua) add their icon here: the same
  -- pal/rows art, or their own draw(x, y) when the mod draws the button itself
  local customIcons, extraApps = {}, {}
  function H:v4AddAppIcon(name, art, accent)
    self.v4ModuleAccents = self.v4ModuleAccents or {}
    self.v4ModuleAccents[name] = accent
    if type(art) == "function" then
      customIcons[name] = art
    else
      ART_SET[name] = art
      images[name], images[name .. ":g"] = nil, nil
      palCache[name] = nil
    end
    extraApps[#extraApps + 1] = name
    self.v4HomeIconCache = nil
  end
  function H:v4Icon(name, x, y, grey)
    local custom = customIcons[name]
    if custom then
      local G = ui.graphics
      local depth = G.getStackDepth and G.getStackDepth()
      G.push("all")
      local ok = pcall(custom, floor(x), floor(y), grey == true)
      if depth then
        while G.getStackDepth() > depth do G.pop() end
      else
        G.pop()
      end
      return ok
    end
    local img = build(name, grey)
    local G = ui.graphics
    if img then
      G.setColor(1, 1, 1, 1)
      G.draw(img, floor(x), floor(y))
      return true
    end
    local spec = ART_SET[name]
    if not spec then return false end
    local pal = palCache[name]
    if not pal then
      pal = { o = OUT }
      for k, v in pairs(spec.pal) do pal[k] = hex(v) end
      palCache[name] = pal
    end
    ART(spec.rows, floor(x), floor(y), pal)
    return true
  end
  K.icon = function(self, name, x, y, grey) return self:v4Icon(name, x, y, grey) end

  -- Start menu keys (16px set) — the native menu keeps its seats.
  local baseStart = H.v4StartIcon
  function H:v4StartIcon(kind, cx, cy)
    local name = "s_" .. tostring(kind)
    if ART_SET[name] then return self:v4Icon(name, cx - 8, cy - 8) end
    return baseStart(self, kind, cx, cy)
  end
  function H:v4HasIcon(name) return ART_SET[name] ~= nil or customIcons[name] ~= nil end

  ---------------------------------------------------------------------------
  -- Home apps: one table, uniform 24×24 bounds, ids carried explicitly.
  ---------------------------------------------------------------------------
  local APPS = { "bag", "pokedex", "trainer", "steps", "achievements", "party", "tools",
    "explorer", "map", "store", "notes", "pss", "settings", "daycare", "calendar" }
  function H:v4HomeIcons()
    if self.v4HomeIconCache then return self.v4HomeIconCache end
    local out = {}
    local function seat(id)
      out[id] = { id = id, left = 0, top = 0, right = 23, bottom = 23,
        draw = function(x, y) self:v4Icon(id, x, y) end }
    end
    for _, id in ipairs(APPS) do seat(id) end
    for _, id in ipairs(extraApps) do seat(id) end
    self.v4HomeIconCache = out
    return out
  end

  function H:battleBagIcon(x, y) self:v4Icon("bag", x, y) end
  function H:battleRunnerIcon(x, y) self:v4Icon("runner", x - 12, y - 12) end
  function H:homeStepsIcon(x, y) self:v4Icon("steps", x, y) end
  function H:homePokedexIcon(x, y) self:v4Icon("pokedex", x, y) end
  function H:homeTrainerIcon(x, y) self:v4Icon("trainer", x, y) end
  function H:homePartyIcon(x, y) self:v4Icon("party", x, y) end
  function H:homeToolsIcon(x, y) self:v4Icon("tools", x, y) end
  function H:homeExplorerIcon(x, y) self:v4Icon("explorer", x, y) end
  function H:homeMapIcon(x, y) self:v4Icon("map", x, y) end
  function H:homeStoreIcon(x, y) self:v4Icon("store", x, y) end
  function H:homeNotesIcon(x, y) self:v4Icon("notes", x, y) end
  function H:homeSettingsIcon(x, y) self:v4Icon("settings", x, y) end

  ---------------------------------------------------------------------------
  -- Field tools: the 28px tool box keeps its geometry; disabled tools (the
  -- silver tint callers pass) are drawn in grey.
  ---------------------------------------------------------------------------
  local TOOL_ALIAS = { fly = "teleport", rock_smash = "strength", tools = "tools" }
  local baseTool = H.toolIcon
  function H:toolIcon(kind, x, y, tint)
    local name = ART_SET[kind] and kind or TOOL_ALIAS[kind]
    if not name or not ART_SET[name] then return baseTool(self, kind, x, y, tint) end
    local s = self.colors.silver
    local grey = tint ~= nil and s ~= nil and tint[1] == s[1] and tint[2] == s[2] and tint[3] == s[3]
    self:v4Icon(name, x + 2, y + 2, grey)
  end

  -- Widget library thumbnails use the same family.
  local LIB = { explorer = "explorer", steps = "steps", team = "party", pokedex = "pokedex",
    trainer = "trainer", map = "map", bag = "bag", store = "store", pss = "pss",
    achievements = "achievements", party = "party", notes = "notes",
    daycare = "daycare", calendar = "calendar" }
  local baseLib = H.homeWidgetLibraryIcon
  function H:homeWidgetLibraryIcon(kind, x, y, item)
    if kind == "tool" then return self:toolIcon(item and item.icon or "tools", x + 1, y + 1) end
    local name = LIB[kind or ""]
    if name then return self:v4Icon(name, x + 3, y + 3) end
    return baseLib(self, kind, x, y, item)
  end
end
