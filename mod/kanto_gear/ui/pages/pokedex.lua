-- Shared encyclopedia pagination, research navigation and touch geometry.
local Page = {}
Page.cards = { "stats", "habitat", "moves", "evolutions" }

function Page.entryRect(index, count)
  local row = math.floor((index - 1) / 3)
  local visible = math.min(3, (count or 9) - row * 3)
  local gap = visible == 2 and 4 or 5
  local left = math.floor((240 - visible * 72 - (visible - 1) * gap) / 2)
  return left + (index - 1) % 3 * (72 + gap), 68 + row * 43, 72, 41
end

function Page.cardRect(index, count)
  count = count or #Page.cards
  if count == 3 then
    if index < 3 then return Page.actionRect(index, 4) end
    return 64, 185, 111, 25
  end
  return Page.actionRect(index, count)
end

function Page.actionRect(index, count, compact)
  local columns = count <= 3 and count or count == 4 and 2 or 3
  local rows = math.ceil(count / columns)
  local gap = columns == 2 and 4 or 5
  local width, height = math.floor((226 - (columns - 1) * gap) / columns), rows == 1 and 54 or 25
  local row = math.floor((index - 1) / columns)
  local visible = math.min(columns, count - row * columns)
  gap = visible == 2 and 4 or gap
  local left = math.floor((240 - (visible * width + (visible - 1) * gap)) / 2)
  return left + (index - 1) % columns * (width + gap), (compact and 185 or 156) + row * 29, width, compact and 25 or height
end

function Page.toolRect(index)
  return 7 + (index - 1) * 115, 49, 111, 15
end

-- Fit the visible silhouettes as one unit, preserving the ROM's affine ratio and offsets.
function Page.comparison(rows, x, y, width, height)
  local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
  for _, row in ipairs(rows) do
    local b, k = row.bounds, 256 / math.max(1, row.scale)
    left, top = math.min(left, row.x + (b[1] - 32) * k), math.min(top, row.y + row.y2 + (b[2] - 32) * k)
    right, bottom = math.max(right, row.x + (b[3] - 32) * k), math.max(bottom, row.y + row.y2 + (b[4] - 32) * k)
  end
  if #rows == 0 then return {} end
  local fit = math.min(1, width / math.max(1, right - left), height / math.max(1, bottom - top))
  local ox, oy = x + width / 2 - (left + right) * fit / 2, y + height / 2 - (top + bottom) * fit / 2
  local result = {}
  for i, row in ipairs(rows) do
    result[i] = { image = row.img, x = ox + row.x * fit, y = oy + (row.y + row.y2) * fit,
      scale = fit * 256 / math.max(1, row.scale) }
  end
  return result
end

-- Native habitat atlases use their own coordinate system; fit the full region,
-- never a viewport around the current Pokemon or a subset of its markers.
function Page.areaTransform(area, viewport)
  viewport = viewport or { x = 14, y = 83, width = 212, height = 90 }
  -- Quantize the tile atlas scale so the visible region keeps balanced
  -- edges on Gear's 1.5x canvas.
  local scale = math.floor(math.min(viewport.width / area.width, viewport.height / area.height) * 8) / 8
  return { x = viewport.x + viewport.width / 2 - (area.x + area.width / 2) * scale,
    y = viewport.y + viewport.height / 2 - (area.y + area.height / 2) * scale, scale = scale }
end

function Page.pagerRect(direction, description)
  -- the description pager sits inside its window's inset frame
  return direction < 0 and 82 or 140, description and 137 or 199, 18, description and 11 or 12
end

function Page.window(rows, number, count)
  local pages = math.max(1, math.ceil(#rows / count))
  number = math.max(1, math.min(number or 1, pages))
  local visible, first = {}, (number - 1) * count + 1
  for index = first, math.min(#rows, first + count - 1) do visible[#visible + 1] = rows[index] end
  return visible, number, pages
end

function Page.controls(model, dex)
  if model.view == "profile" or model.view == "stats" then
    model.canCycle = false
    for _, row in ipairs(dex.entries) do
      if row.revealed ~= false and row.species ~= model.pokemon.species then model.canCycle = true; break end
    end
  else model.canCycle = (model.pages or 1) > 1 end
  return model
end

function Page.index(state, dex, region, drawPokemon)
  local entries, number, pages = Page.window(dex.entries, state.page, 9)
  state.page = number
  return Page.controls({ view = "index", region = region, caught = dex.caught, total = dex.total,
    page = number, pages = pages, entries = entries, drawPokemon = drawPokemon }, dex)
end

function Page.description(state, model)
  model.pokemon.description, model.descriptionPage, model.descriptionPages =
    Page.window(model.pokemon.description, state.descriptionPage, 2)
  state.descriptionPage = model.descriptionPage
  return model
end

function Page.cycleDescription(state, model, direction)
  if model.view ~= "profile" or (model.descriptionPages or 1) <= 1 then return false end
  state.descriptionPage = (model.descriptionPage - 1 + direction) % model.descriptionPages + 1
  return true
end

function Page.stats(base, splitSpecial)
  local definitions = splitSpecial and {
    { "HP", "hp" }, { "ATK", "attack" }, { "DEF", "defense" },
    { "SP.ATK", "specialAttack", "spAttack", "special" },
    { "SP.DEF", "specialDefense", "spDefense", "special" }, { "SPEED", "speed" },
  } or {
    { "HP", "hp" }, { "ATK", "attack" }, { "DEF", "defense" },
    { "SPECIAL", "special" }, { "SPEED", "speed" },
  }
  local stats, total = {}, 0
  for _, keys in ipairs(definitions) do
    local value = 0
    for index = 2, #keys do
      local native = tonumber(base[keys[index]])
      if native then value = native; break end
    end
    stats[#stats + 1], total = { label = keys[1], value = value }, total + value
  end
  return stats, total
end

function Page.select(state, dex, index)
  if #dex.entries == 0 then return false end
  local entry = dex.entries[(index - 1) % #dex.entries + 1]
  if entry.revealed == false or state.view == "profile" and state.selected == entry.species then return false end
  state.selected, state.view, state.habitatPage, state.movePage, state.descriptionPage, state.evolutionPage = entry.species, "profile", 1, 1, 1, 1
  return true
end

function Page.cycle(state, dex, model, direction)
  if not model.canCycle or direction ~= 1 and direction ~= -1 then return false end
  if state.view == "profile" or state.view == "stats" then
    local selected = dex.bySpecies[state.selected]
    for offset = 1, #dex.entries - 1 do
      local index = ((selected and selected.index or 1) - 1 + direction * offset) % #dex.entries + 1
      local entry = dex.entries[index]
      if entry.revealed ~= false and entry.species ~= state.selected then
        state.selected, state.habitatPage, state.movePage, state.descriptionPage, state.evolutionPage = entry.species, 1, 1, 1, 1
        return true
      end
    end
    return false
  end
  local key = state.view == "index" and "page" or state.view == "moves" and "movePage"
    or state.view == "evolutions" and "evolutionPage" or "habitatPage"
  state[key] = (model.page - 1 + direction) % model.pages + 1
  return true
end

local function inside(x, y, left, top, width, height)
  return x >= left and x < left + width and y >= top and y < top + height
end

function Page.inDescription(model, x, y)
  return model.view == "profile" and inside(x, y, 7, 108, 226, 44)
end

function Page.hit(model, x, y)
  if model.canUse == false then return end
  if y >= 0 and y < 28 then
    if x >= 0 and x < 27 then return "back" end
    if model.canCycle then
      if x >= 27 and x < 45 then return "prev" end
      if x >= 120 and x < 138 then return "next" end
    end
  end
  if model.actions then
    for index, action in ipairs(model.actions) do
      if not action.inert and inside(x, y, Page.actionRect(index, #model.actions, model.compactActions)) then return "action", index end
    end
  end
  if model.view == "profile" then
    if (model.descriptionPages or 1) > 1 then
      if inside(x, y, Page.pagerRect(-1, true)) then return "description_prev" end
      if inside(x, y, Page.pagerRect(1, true)) then return "description_next" end
    end
    if not model.actions then
      for index, action in ipairs(model.cards or Page.cards) do
        if inside(x, y, Page.cardRect(index, #(model.cards or Page.cards))) then return action end
      end
    end
  elseif model.view == "index" then
    for index in ipairs(model.tools or {}) do
      if inside(x, y, Page.toolRect(index)) then return "tool", index end
    end
    for index, entry in ipairs(model.entries) do
      if entry.revealed ~= false and not (model.forms and entry.selected)
          and inside(x, y, Page.entryRect(index, #model.entries)) then return "species", index end
    end
  end
  if model.canCycle and (model.view == "index" or model.view == "moves" or model.view == "habitat" or model.view == "evolutions") then
    if inside(x, y, Page.pagerRect(-1)) then return "prev" end
    if inside(x, y, Page.pagerRect(1)) then return "next" end
  end
end

return Page
