local I18N = {}
I18N.__index = I18N

local SUPPORTED = { en = true, de = true, es = true, fr = true, ja = true, it = true }

local function languageCode(value)
  value = tostring(value or ""):lower():gsub("_", "-")
  return value:match("^([a-z][a-z])")
end

local function formatSignature(value)
  local signature = {}
  for spec in tostring(value):gsub("%%%%", ""):gmatch("%%[-+ #0]*%d*%.?%d*([cdiouxXeEfgGqs])") do
    signature[#signature + 1] = spec
  end
  return table.concat(signature)
end

function I18N.new(loadCatalog, selectedLanguage)
  assert(type(loadCatalog) == "function", "catalog loader required")
  local self = setmetatable({
    selectedLanguage = selectedLanguage or function() return "en" end,
    catalogs = { en = {} }, requested = {},
  }, I18N)
  for _, code in ipairs({ "de", "es", "fr", "ja", "it" }) do
    self.catalogs[code] = assert(loadCatalog(code),
      "missing Kanto Gear language catalog: " .. code)
  end
  return self
end

function I18N:language()
  local selected = languageCode(self.selectedLanguage())
  return selected and SUPPORTED[selected] and selected or "en"
end

-- Only Kanto Gear-owned strings may enter this function. Game/Recomp values
-- are rendered directly and never looked up in these catalogs.
function I18N:text(key)
  key = tostring(key or "")
  if key == "" then return "" end
  local scope, original = key:match("^@app/([a-z][a-z0-9_]*):(.*)$")
  if scope and self.modules and self.modules[scope] then
    local entries = self.modules[scope][self:language()] or {}
    local translated = entries[original]
    return type(translated) == "string" and translated ~= "" and translated or original
  end
  self.requested[key] = true
  local language = self:language()
  if language == "en" then return key end
  local translated = self.catalogs[language][key]
  if type(translated) ~= "string" or translated == "" then
    return key
  end
  return translated
end

function I18N:format(key, ...)
  local template = self:text(key)
  if formatSignature(template) ~= formatSignature(key) then
    template = key
  end
  local ok, value = pcall(string.format, template, ...)
  return ok and value or string.format(key, ...)
end

-- Third-party store modules may bring their own translations; missing entries
-- fall back to the module's English strings, never to an error.
function I18N:extend(language, entries, scope)
  language = languageCode(language)
  if not (language and SUPPORTED[language]) then return false end
  if type(scope) ~= "string" or not scope:match("^[a-z][a-z0-9_]*$") then return false end
  if type(entries) ~= "table" then return false end
  self.modules = self.modules or {}
  self.modules[scope] = self.modules[scope] or {}
  local catalog = {}
  for key, value in pairs(entries) do
    if type(key) == "string" and type(value) == "string" then
      catalog[key] = value
    end
  end
  self.modules[scope][language] = catalog
  return true
end

function I18N:coverage(language)
  language = languageCode(language) or "en"
  local missing = {}
  if language ~= "en" then
    local catalog = self.catalogs[language] or {}
    for key in pairs(self.requested) do
      if type(catalog[key]) ~= "string" or catalog[key] == "" then missing[#missing + 1] = key end
    end
  end
  table.sort(missing)
  return missing
end

return I18N
