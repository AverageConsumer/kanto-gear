-- Asynchronous OS entropy and local QR generation, isolated from frame rendering.
local Pairing = {}
function Pairing.new(mod, runtime)
  local api = runtime.thread
  local requests, results = api.newChannel(), api.newChannel()
  local thread = api.newThread(assert(mod:read("phone/pairing_worker.lua")))
  thread:start(requests, results, assert(mod:read("vendor/qrencode.lua")))
  return {
    request = function(_, url) requests:clear(); results:clear(); requests:push(url) end,
    pop = function()
      local result = results:pop()
      if result then return result end
      if thread:getError() then return { error = "Secure pairing is unavailable on this host." } end
    end,
    stop = function() requests:clear(); requests:push(false); results:clear() end,
  }
end
return Pairing
