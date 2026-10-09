-- Observe consumption without changing native inventory or item effects.
local Recent = {}
Recent.__index = Recent

function Recent.new(store)
  return setmetatable({ store = store }, Recent)
end

function Recent:bind(save)
  self.save, self.pending = save, nil
  self.id = self.store:get("last_used_item")
  if type(self.id) ~= "string" and type(self.id) ~= "number" then self.id = nil end
end

function Recent:remember(save, id)
  if save ~= self.save or (type(id) ~= "string" and type(id) ~= "number") then return false end
  if self.id == id then return false end
  self.id = id
  self.store:set("last_used_item", id)
  return true
end

function Recent:watch(save, id)
  if save ~= self.save or (type(id) ~= "string" and type(id) ~= "number") then return end
  local inventory = save.inventory or {}
  local count = tonumber(inventory[id]) or 0
  if count <= 0 then return end
  if self.pending and self.pending.id == id
      and self.pending.inventory == inventory then return end
  self.pending = { id = id, inventory = inventory, count = count }
end

function Recent:poll(save)
  local pending = self.pending
  if not pending then return false end
  if save ~= self.save or save.inventory ~= pending.inventory then
    self.pending = nil
    return false
  end
  if (tonumber(save.inventory[pending.id]) or 0) < pending.count then
    self.pending = nil
    self:remember(save, pending.id)
    return true
  end
  return false
end

function Recent:available(save)
  if save == self.save and self.id
      and (tonumber((save.inventory or {})[self.id]) or 0) > 0 then return self.id end
end

return Recent
