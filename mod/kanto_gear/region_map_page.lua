-- One touch contract for every region atlas. Coordinates stay in atlas pixels;
-- the widget and the native map cursor are independent of this page.
local Page = {}
Page.viewport = { x = 14, y = 39, w = 212, h = 112 }
Page.confirm = { x = 12, y = 157, w = 216, h = 29 }

function Page.transform(model)
  local r = Page.viewport
  local scale = math.min(r.w / model.width, r.h / model.height)
  return math.floor(r.x + (r.w - model.width * scale) / 2 + 0.5),
    math.floor(r.y + (r.h - model.height * scale) / 2 + 0.5), scale
end

function Page.bind(state, model)
  if state.key ~= model.key then
    state.key, state.x, state.y = model.key, model.playerX, model.playerY
    state.selected = false
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
  if state.fly then
    local best, distance
    for _, point in ipairs(model.flyPoints or {}) do
      local d = ((state.x - point.x) * scale)^2 + ((state.y - point.y) * scale)^2
      if d <= 14^2 and (not distance or d < distance
          or d == distance and Page.targetKey(point) < Page.targetKey(best)) then best, distance = point, d end
    end
    if best then state.x, state.y = best.x, best.y end
  end
  state.selected = true
  return model.pick(state.x, state.y, state.fly == true)
end

function Page.target(state, model)
  return model.pick(state.x, state.y, state.fly == true)
end

function Page.targetKey(target)
  return target and table.concat({ tostring(target.region), tostring(target.id),
    tostring(target.pos or 0) }, ":") or nil
end

function Page.confirmHit(x, y)
  local r = Page.confirm
  return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

function Page.tap(state, model, x, y, canFly)
  if y >= 190 and y < 208 and x >= 12 and x < 228 then
    local fly
    if x < 116 then fly = false elseif x >= 124 then fly = true else return end
    if (state.fly == true) == fly then return end
    state.fly = fly
    state.selected = false
    return "mode"
  end
  if Page.confirmHit(x, y) then
    local target = Page.target(state, model)
    if Page.ready(state, target, canFly) then return "fly", target end
    return
  end
  if not Page.inside(model, x, y) then return end
  Page.select(state, model, x, y)
  return "select"
end

function Page.ready(state, target, canFly)
  return state.fly == true and state.selected == true and target ~= nil
    and target.flyPoint == true and target.flyable == true and canFly == true
end

function Page.preview(x, y)
  local left = math.max(14, math.min(162, math.floor(x - 32)))
  local top = math.floor(y - 58)
  if top < 30 then left, top = x < 120 and 162 or 14, 39 end
  return left, top, 64, 40
end

function Page.status(state, target, canFly)
  if not state.fly then return "DRAG TO EXPLORE" end
  if not state.selected then return "SELECT A DESTINATION" end
  if not target or not target.flyPoint then return "NOT A FLY DESTINATION" end
  if not target.flyable then return "NOT VISITED" end
  if not canFly then return "FLY UNAVAILABLE HERE" end
  return "FLY"
end

return Page
