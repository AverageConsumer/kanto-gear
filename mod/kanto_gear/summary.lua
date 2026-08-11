local Summary = {}

local function invoke(state, name)
  local fn = state and state[name]
  if type(fn) ~= "function" then return nil end
  local ok, first, second = pcall(fn, state)
  if ok then return first, second end
end

local function definition(game, kind, id)
  local rows = game and game.data and game.data[kind]
  return rows and id and rows[id] or nil
end

local function moveRows(game, mon, gen2)
  local rows = {}
  for slot = 1, 4 do
    local move = mon.moves and mon.moves[slot]
    local def = move and definition(game, "moves", move.id)
    local maxPp = 0
    if move then
      maxPp = move.maxPp or (def and def.pp) or move.pp or 0
      if not gen2 and def and tonumber(def.pp) then
        maxPp = maxPp + (move.ppUps or 0) * math.floor(def.pp / 5)
      end
    end
    rows[slot] = {
      name = def and def.name or move and (move.name or move.id) or "-",
      pp = move and move.pp,
      maxPp = maxPp,
    }
  end
  return rows
end

function Summary.supports(state)
  local id = state and state.screenId
  local gen2 = id == "Gen2SummaryMenu"
  local mon = state and state.mon
  if type(mon) ~= "table" or mon.isEgg or (gen2 and state.moveDetail) then
    return false
  end
  if gen2 and (type(state.expToNext) ~= "function"
      or type(state.itemName) ~= "function"
      or type(state.otName) ~= "function"
      or type(state.otId) ~= "function") then return false end
  local pages = gen2 and 3 or 2
  local page = tonumber(state.page) or 1
  return page >= 1 and page <= pages
end

function Summary.view(state, game)
  if not Summary.supports(state) then return nil end
  local gen2 = state.screenId == "Gen2SummaryMenu"
  local mon = state.mon
  local pages = gen2 and 3 or 2
  local page = tonumber(state.page) or 1

  local def = definition(game, "pokemon", mon.species) or {}
  local save = game and game.save or {}
  local player = save.player or {}
  local stats = mon.stats or {}
  local item = gen2 and invoke(state, "itemName") or nil
  local nextExp = gen2 and invoke(state, "expToNext") or nil
  local ot = gen2 and invoke(state, "otName") or mon.ot
  local otId = gen2 and invoke(state, "otId") or mon.otId

  return {
    gen2 = gen2,
    page = page,
    pages = pages,
    mon = mon,
    def = def,
    name = mon.nickname or def.name or mon.species or "POKEMON",
    dex = def.dex or 0,
    level = mon.level or 0,
    hp = mon.hp or 0,
    maxHp = mon.maxHp or stats.hp or mon.hp or 0,
    status = mon.status,
    types = mon.types or def.types or {},
    experience = gen2 and (mon.experience or 0) or (mon.exp or 0),
    nextExp = nextExp,
    item = item,
    ot = ot or player.name or (gen2 and "GOLD" or "RED"),
    otId = otId or player.id or 0,
    stats = stats,
    moves = moveRows(game, mon, gen2),
  }
end

return Summary
