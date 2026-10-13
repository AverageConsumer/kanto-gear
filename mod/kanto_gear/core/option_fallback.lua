return function(THEME)
-- Host path [all games]: absent options:set requires the cache-backed writer to keep touch settings, launcher choices and save options in sync.
function THEME:installOptionFallback(mod)
  if type(mod.options.set) ~= "function" and mod.cache
      and type(mod.cache.read) == "function"
      and type(mod.cache.write) == "function" then
    local nativeGet, loaded, values = mod.options.get, {}, {}
    local boundGame
    local function nativeValues()
      local loader = boundGame and boundGame.mods
      return loader and loader.modOptions and loader.modOptions.kanto_gear
    end
    local function publish(key, value)
      if not boundGame then return end
      local loader = boundGame.mods
      local options = boundGame.options or (boundGame.save and boundGame.save.options)
      if loader then
        loader.modOptions = loader.modOptions or {}
        loader.modOptions.kanto_gear = loader.modOptions.kanto_gear or {}
        loader.modOptions.kanto_gear[key] = value
      end
      if options then
        options.modOptions = options.modOptions or {}
        options.modOptions.kanto_gear = options.modOptions.kanto_gear or {}
        options.modOptions.kanto_gear[key] = value
      end
    end
    local function store(key, value)
      if loaded[key] and values[key] == value then return true end
      local kind, encoded = type(value)
      if kind == "boolean" then encoded = value and "b1" or "b0"
      elseif kind == "number" then encoded = "n" .. tostring(value)
      elseif kind == "string" then encoded = "s" .. value
      else return false end
      if not mod.cache:write("options/" .. key, encoded) then return false end
      loaded[key], values[key] = true, value
      return true
    end
    function mod.options:get(key)
      local native = nativeValues()
      if native and native[key] ~= nil then return native[key] end
      if not loaded[key] then
        local raw = mod.cache:read("options/" .. key)
        if raw == "b1" or raw == "b0" then
          values[key] = raw == "b1"
        elseif type(raw) == "string" and raw:sub(1, 1) == "n" then
          values[key] = tonumber(raw:sub(2))
        elseif type(raw) == "string" and raw:sub(1, 1) == "s" then
          values[key] = raw:sub(2)
        end
        loaded[key] = true
      end
      if values[key] ~= nil then return values[key] end
      return nativeGet(self, key)
    end
    function mod.options:set(key, value)
      if not store(key, value) then return false end
      publish(key, value)
      if boundGame and boundGame.writeOptions then boundGame:writeOptions() end
      mod.events:emit("mod.kanto_gear.options_changed",
        { mod = "kanto_gear", key = key, value = value })
      return true
    end
    function mod.options:bindGame(source, schema)
      -- The stock host has no options:set. Keep its menu/profile values and
      -- global options file in sync with touch settings, without polling.
      boundGame = nil
      for _, row in ipairs(schema) do self:get(row.key) end
      boundGame = source
      local changed = false
      for _, row in ipairs(schema) do
        local native = nativeValues()
        local value = native and native[row.key]
        if value ~= nil then
          if row.migrate_from ~= nil and value == row.migrate_from then
            value, changed = row.default, true
          end
          -- Explicit launcher/menu choices override the older fallback cache.
          if values[row.key] ~= nil then self:syncExternal(row.key, value) end
        else
          value = self:get(row.key)
          changed = true
        end
        publish(row.key, value)
      end
      if changed and source.writeOptions then source:writeOptions() end
    end
    function mod.options:syncExternal(key, value)
      if type(key) ~= "string" or value == nil then return false end
      if not store(key, value) then
        loaded[key], values[key] = true, value
      end
      return true
    end
  end
end
end
