return function(mod)
  local body = assert(mod:read("lang/de.lua"), "lang/de.lua fehlt")
  local chunk = assert(loadstring(body, "lang/de.lua"))
  local translations = assert(chunk())
  local count = 0
  for source, translated in pairs(translations) do
    mod.content.strings:override(source, translated)
    count = count + 1
  end
  mod.log:info("Kanto Gear Deutsch: %d Texte geladen", count)
end
