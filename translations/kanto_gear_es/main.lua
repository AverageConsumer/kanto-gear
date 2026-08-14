return function(mod)
  local body = assert(mod:read("lang/es.lua"), "lang/es.lua no encontrado")
  local chunk = assert(loadstring(body, "lang/es.lua"))
  local translations = assert(chunk())
  local count = 0
  for source, translated in pairs(translations) do
    mod.content.strings:override(source, translated)
    count = count + 1
  end
  mod.log:info("Kanto Gear Español (España): %d textos cargados", count)
end
