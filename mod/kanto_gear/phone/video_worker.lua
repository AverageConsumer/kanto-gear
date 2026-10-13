local requests, results, source = ...
require("love.data")
require("love.timer")
local Video = assert(loadstring(source))()
local previous, epoch
while true do
  local job = requests:demand()
  if job == false then break end
  if job.epoch ~= epoch then previous, epoch = nil, job.epoch end
  local profile = job.profile and { clock = love.timer.getTime }
  local started = profile and profile.clock()
  local ok, body, nextImage = pcall(Video.encode, job.rgba, job.w, job.h, job.id, previous,
    function(bytes) return love.data.compress("string", "zlib", bytes, 1) end, job.at, profile)
  if profile then
    profile.encode, profile.wait = (profile.clock() - started) * 1000, (started - job.queuedAt) * 1000
    profile.clock = nil -- Channels carry measurements, never functions.
  end
  if ok then previous = nextImage end
  results:push({ epoch = job.epoch, id = job.id, body = ok and body or nil, profile = profile,
    error = not ok and "Phone video encoding failed." or nil })
end
