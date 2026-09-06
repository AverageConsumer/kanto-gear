local Guard = {}
Guard.__index = Guard

function Guard.new()
  return setmetatable({ quiet = 0.25, readyAt = 0, epoch = 0 }, Guard)
end

function Guard:sync(key, text, now)
  if self.key ~= key then
    if self.key ~= nil and not text then self.readyAt = now + self.quiet end
    if text then self.readyAt = 0 end
    self.key, self.epoch = key, self.epoch + 1
  end
  self.text = text
end

function Guard:allow(now, epoch)
  if epoch and epoch ~= self.epoch or self.pending or now < self.readyAt then
    -- A burst belongs to the old screen until the user pauses briefly.
    if not self.text then self.readyAt = now + self.quiet end
    return false
  end
  return true
end

return Guard
