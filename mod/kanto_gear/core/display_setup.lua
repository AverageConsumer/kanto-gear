-- Display preference and temporary recovery are independent. A missing output
-- never rewrites the user's saved two-screen preference.
local Setup = {}
Setup.__index = Setup
Setup.MARKER = "display/setup-v1"
Setup.choices = { "combined", "separate", "fullscreen", "phone" }

function Setup.new(fresh)
  return setmetatable({ pending = fresh == true, selected = 1 }, Setup)
end

function Setup:bind(now, mode)
  self.mode, self.started = mode, now
  self.stage, self.fallback, self.missingSince, self.recoveryPending = nil, false, nil, false
  self.selected, self.armed, self.draining = 1, false, false
end

function Setup:tick(now, mode, healthy, safe)
  if mode ~= self.mode then
    self.mode, self.missingSince = mode, nil
    self.fallback, self.recoveryPending = false, false
  end
  if mode == "separate" and not self.fallback and not self.stage and not self.draining then
    if healthy then self.missingSince = nil
    else self.missingSince = self.missingSince or now end
    if self.missingSince and now - self.missingSince >= 2 then
      self.fallback, self.recoveryPending = true, true
    end
  end
  if self.stage == "test" and now >= self.deadline then
    self.stage = self.fallback and "recovery" or "welcome"
    self.selected, self.armed = 1, false
  end
  if not self.stage and not self.draining and safe and (self.pending or self.recoveryPending) then
    self.stage = self.recoveryPending and "recovery" or "welcome"
    self.selected, self.armed = 1, false
  end
end

function Setup:test(now)
  self.stage, self.deadline, self.selected, self.armed = "test", now + 15, 2, false
end

function Setup:close()
  self.stage, self.pending, self.recoveryPending = nil, false, false
  self.draining, self.armed = true, false
end

function Setup:override()
  if self.sessionMode then return self.sessionMode end
  if self.stage or self.fallback then return "combined" end
end

return Setup
