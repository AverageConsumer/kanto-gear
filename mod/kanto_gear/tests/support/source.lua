return function(root)
  local parts, visited = {}, {}
  local function append(path)
    if visited[path] then return end
    visited[path] = true
    local file = assert(io.open(root .. "/" .. path, "rb"))
    local source = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    parts[#parts + 1] = source
    for name in source:gmatch('install%("([^"]+)"') do append(name .. ".lua") end
    for name in source:gmatch('loadModule%("([^"]+)"') do append(name .. ".lua") end
  end
  append("main.lua")
  return table.concat(parts, "\n")
end
