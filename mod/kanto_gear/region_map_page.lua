-- One touch contract for every region atlas. Coordinates stay in atlas pixels;
-- the widget and the native map cursor are independent of this page.
local Page = {}
Page.viewport = { x = 14, y = 39, w = 212, h = 112 }

function Page.transform(model)
  local r = Page.viewport
  local scale = math.min(r.w / model.width, r.h / model.height)
  return math.floor(r.x + (r.w - model.width * scale) / 2 + 0.5),
    math.floor(r.y + (r.h - model.height * scale) / 2 + 0.5), scale
end

function Page.bind(state, model)
  if state.key ~= model.key then
    state.key, state.x, state.y = model.key, model.playerX, model.playerY
    state.armed = nil
  end
  state.x = math.max(0, math.min(model.width - 1, state.x or model.width / 2))
  state.y = math.max(0, math.min(model.height - 1, state.y or model.height / 2))
end

function Page.inside(model, x, y)
  if not model or not model.width or not model.height then return false end
  local left, top, scale = Page.transform(model)
  return x >= left and x < left + model.width * scale
    and y >= top and y < top + model.height * scale
end

function Page.select(state, model, x, y)
  local left, top, scale = Page.transform(model)
  state.x = math.max(0, math.min(model.width - 1, (x - left) / scale))
  state.y = math.max(0, math.min(model.height - 1, (y - top) / scale))
  return model.pick(state.x, state.y, state.fly == true)
end

function Page.target(state, model)
  return model.pick(state.x, state.y, state.fly == true)
end

function Page.targetKey(target)
  return target and table.concat({ tostring(target.region), tostring(target.id),
    tostring(target.pos or 0) }, ":") or nil
end

function Page.tap(state, model, x, y, canFly)
  if y >= 190 and y < 208 and x >= 12 and x < 228 then
    if x < 116 then state.fly = false elseif x >= 124 then state.fly = true else return end
    state.armed = nil
    return "mode"
  end
  if not Page.inside(model, x, y) then state.armed = nil; return end
  local target = Page.select(state, model, x, y)
  local key = Page.targetKey(target)
  if state.fly and target and target.flyable and canFly then
    if state.armed == key then state.armed = nil; return "fly", target end
    state.armed = key
  else state.armed = nil end
  return "select"
end

function Page.status(state, target, canFly)
  if not state.fly then return "DRAG TO EXPLORE" end
  if not target or not target.flyPoint then return "NOT A FLY DESTINATION" end
  if not target.flyable then return "NOT VISITED" end
  if not canFly then return "FLY UNAVAILABLE HERE" end
  return "TAP AGAIN TO FLY"
end

return Page
