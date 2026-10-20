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
-- Native Gen 3 fonts/text read the active version's mounted cache, while the
-- headless filesystem has no PhysFS mounts. Serve the explicitly configured
-- local cache through that same read seam; never fabricate missing assets.
local cacheRoot = os.getenv("POKEPORT_GBA_CACHE")
if cacheRoot then
  local cache = FsIo.new(cacheRoot)
  local CacheFs = require("src.import.CacheFs")
  local nativeRead = CacheFs.readActive
  CacheFs.readActive = function(path, ...)
    local relative = path:match("^data/generated/gba/(.*)$")
      or path:match("^[^/]+/data/generated/gba/(.*)$")
    local bytes = relative and cache.read(relative)
    if type(bytes) == "string" then return bytes end
    return nativeRead(path, ...)
  end
end
local test = assert(arg[1])
arg[1] = os.getenv("KANTO_GEAR_TEST_GEN")
dofile(test)
