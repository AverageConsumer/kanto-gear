-- Run shared behavior checks against the edition's real native menu fixture.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local edition = assert(os.getenv("POKEPORT_VERSION"))
local fixture = (edition == "ruby" or edition == "sapphire") and "rs_runtime_test"
  or edition == "emerald" and "emerald_runtime_test" or "gen3_runtime_test"
return dofile(path .. "/tests/" .. fixture .. ".lua")
