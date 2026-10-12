local requests, results, source = ...
require("love.data")
local Video = assert(loadstring(source))()
local previous, epoch
while true do
  local job = requests:demand()
  if job == false then break end
  if job.epoch ~= epoch then previous, epoch = nil, job.epoch end
  local ok, body, nextImage = pcall(Video.encode, job.rgba, job.w, job.h, job.id, previous,
    function(bytes) return love.data.compress("string", "zlib", bytes, 1) end, job.at)
  if ok then previous = nextImage end
  results:push({ epoch = job.epoch, id = job.id, body = ok and body or nil,
    error = not ok and "Phone video encoding failed." or nil })
end
