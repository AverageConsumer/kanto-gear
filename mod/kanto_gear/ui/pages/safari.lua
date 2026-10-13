-- Safari actions keep native order; the same cards serve every edition.
local Page = {}
local defaults = { "ball", "bait", "rock", "run" }
local colors = { "red", "green", "amber", "blue" }

function Page.model(battle)
  local actions = {}
  for index, id in ipairs(battle.safariActions or defaults) do
    actions[index] = { kind = id, label = battle.safariLabels and battle.safariLabels[index]
      or id:upper():gsub("_", " "), color = colors[index],
      detail = id == "ball" and "x" .. tostring(battle.safariBalls or 0) or nil,
      enabled = id ~= "ball" or (battle.safariBalls or 0) > 0 }
  end
  return { actions = actions, balls = battle.safariBalls, index = nil }
end

function Page.rect(index)
  return 6 + (index - 1) % 2 * 116, 33 + math.floor((index - 1) / 2) * 91, 112, 86
end

function Page.action(model, index)
  local action = index and model.actions[index]
  return action and action.enabled ~= false and action.kind or nil
end

function Page.hit(x, y)
  for index = 1, 4 do
    local left, top, w, h = Page.rect(index)
    if x >= left and x < left + w and y >= top and y < top + h then return index end
  end
end

return Page
