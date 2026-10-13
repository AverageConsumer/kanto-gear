-- Adapter factories receive the same file reader as the packaged mod.
return function(root, name)
  local function read(path)
    local file = assert(io.open(root .. "/" .. path, "rb"))
    local source = file:read("*a")
    file:close()
    return source
  end
  return assert(loadfile(root .. "/" .. name .. ".lua"))()(read)
end
