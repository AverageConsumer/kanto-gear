local I18N = {}
I18N.__index = I18N

local SUPPORTED = { en = true, de = true, es = true, fr = true }

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
  for _, code in ipairs({ "de", "es", "fr" }) do
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
  self.requested[key] = true
  local language = self:language()
  if language == "en" then return key end
  local translated = self.catalogs[language][key]
  if translated == nil then
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

function I18N:coverage(language)
  language = languageCode(language) or "en"
  local missing = {}
  if language ~= "en" then
    local catalog = self.catalogs[language] or {}
    for key in pairs(self.requested) do
      if catalog[key] == nil then missing[#missing + 1] = key end
    end
  end
  table.sort(missing)
  return missing
end

return I18N
