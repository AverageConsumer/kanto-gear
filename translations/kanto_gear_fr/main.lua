return function(mod)
  local body = assert(mod:read("i18n/catalogs/fr.lua"), "i18n/catalogs/fr.lua introuvable")
  local chunk = assert(loadstring(body, "i18n/catalogs/fr.lua"))
  local translations = assert(chunk())
  local count = 0
  for source, translated in pairs(translations) do
    mod.content.strings:override("kanto_gear|" .. source, translated)
    count = count + 1
  end
  mod.log:info("Kanto Gear Français : %d textes chargés", count)
end
