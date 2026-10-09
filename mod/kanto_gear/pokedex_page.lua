-- Shared encyclopedia pagination, research navigation and touch geometry.
local Page = {}
Page.cards = { "stats", "habitat", "moves" }

function Page.entryRect(index)
  return 7 + (index - 1) % 3 * 77, 68 + math.floor((index - 1) / 3) * 43, 72, 41
end

function Page.cardRect(index)
  return 7 + (index - 1) * 77, 156, 72, 54
end

function Page.pagerRect(direction, description)
  return direction < 0 and 82 or 140, description and 140 or 199, 18, description and 11 or 12
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
    Page.window(model.pokemon.description, state.descriptionPage, 3)
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
  state.selected, state.view, state.habitatPage, state.movePage, state.descriptionPage = entry.species, "profile", 1, 1, 1
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
        state.selected, state.habitatPage, state.movePage, state.descriptionPage = entry.species, 1, 1, 1
        return true
      end
    end
    return false
  end
  local key = state.view == "index" and "page" or state.view == "moves" and "movePage" or "habitatPage"
  state[key] = (model.page - 1 + direction) % model.pages + 1
  return true
end

local function inside(x, y, left, top, width, height)
  return x >= left and x < left + width and y >= top and y < top + height
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
  if model.view == "profile" then
    if (model.descriptionPages or 1) > 1 then
      if inside(x, y, Page.pagerRect(-1, true)) then return "description_prev" end
      if inside(x, y, Page.pagerRect(1, true)) then return "description_next" end
    end
    for index, action in ipairs(Page.cards) do
      if inside(x, y, Page.cardRect(index)) then return action end
    end
  elseif model.view == "index" then
    for index, entry in ipairs(model.entries) do
      if entry.revealed ~= false and inside(x, y, Page.entryRect(index)) then return "species", index end
    end
  end
  if model.canCycle and (model.view == "index" or model.view == "moves" or model.view == "habitat") then
    if inside(x, y, Page.pagerRect(-1)) then return "prev" end
    if inside(x, y, Page.pagerRect(1)) then return "next" end
  end
end

return Page
