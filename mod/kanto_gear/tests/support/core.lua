local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local function loadModule(name, ...)
  return assert(loadfile(root .. "/" .. name .. ".lua"))()(...)
end
return loadModule("core/init", loadModule)
