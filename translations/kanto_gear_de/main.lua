return function(mod)
  local body = assert(mod:read("i18n/catalogs/de.lua"), "i18n/catalogs/de.lua fehlt")
  local chunk = assert(loadstring(body, "i18n/catalogs/de.lua"))
  local translations = assert(chunk())
  local count = 0
  for source, translated in pairs(translations) do
    mod.content.strings:override("kanto_gear|" .. source, translated)
    count = count + 1
  end
  mod.log:info("Kanto Gear Deutsch: %d Texte geladen", count)
end
