require("src.core.GameVersion").set(assert(os.getenv("POKEPORT_VERSION")))
local FsIo = require("tests.fs_io")
if FsIo.isWindows then
  local ffi = require("ffi")
  ffi.cdef[[unsigned long GetFileAttributesA(const char *path);]]
  FsIo.isDir = function(path)
    local attributes = ffi.C.GetFileAttributesA(tostring(path))
    return attributes ~= 0xFFFFFFFF and bit.band(attributes, 0x10) ~= 0
  end
end
local test = assert(arg[1])
arg[1] = os.getenv("KANTO_GEAR_TEST_GEN")
dofile(test)
