return function(THEME, rowsContract)
local function localMapLayout(width, height, zoom, focusX, focusY, density)
  width, height = math.max(1, width or 1), math.max(1, height or 1)
  zoom = tonumber(zoom) or 1
  density = math.max(1, tonumber(density) or 4)
  local scale = math.min(3, 148 / width, 98 / height)
  if scale >= 1 then scale = math.floor(scale) end
  local zoomScale = zoom == 2 and 1.5 or zoom == 3 and 2
  if zoom > 1 then
    scale = math.max(scale * zoomScale, zoomScale * 4 / density)
  end
  local left = 4 + (152 - width * scale) / 2
  local top = 22 + (102 - height * scale) / 2
  if zoom > 1 and focusX and focusY then
    left = 80 - focusX * scale
    top = 73 - focusY * scale
    if width * scale > 152 then
      left = math.max(156 - width * scale, math.min(4, left))
    end
    if height * scale > 102 then
      top = math.max(124 - height * scale, math.min(22, top))
    end
  end
  return scale, left, top
end

local function localMapMode(value)
  if value == "enhanced" then return "enhanced" end
  if value == true or value == "map" then return "map" end
  return "off"
end

local function localMapGrid(overview)
  if overview.tileDetailRows then
    return overview.tileDetailRows, overview.tileDetailWidth,
      overview.tileDetailHeight, 4
  end
  if overview.tileRows then
    return overview.tileRows, overview.tileWidth, overview.tileHeight, 2
  end
  return overview.rows, overview.width, overview.height, 1
end

function THEME:localMapColor(overview, x, y, density, shade)
  density = math.max(1, tonumber(density) or 1)
  local cellX = math.floor((x - 1) / density) + 1
  local cellY = math.floor((y - 1) / density) + 1
  local row = overview and overview.rows and overview.rows[cellY] or ""
  local ramp = self.localMap[row:sub(cellX, cellX)] or self.localMap[" "]
  local index = math.max(1, math.min(4, (tonumber(shade) or 3) + 1))
  return ramp[index]
end

local function prepareBattleSnapshot(a, b, state, data, ownsMoveFocus)
  if ownsMoveFocus and b and state and b.prompt == "moves" then
    local moves = b.moves or {}
    local current = math.max(1, math.min(#moves,
      tonumber(state.moveIndex) or 1))
    local move = moves[current]
    if THEME:moveUnavailableReason(move) then
      for offset = 1, #moves - 1 do
        local index = (current + offset - 1) % #moves + 1
        move = moves[index]
        if move and not THEME:moveUnavailableReason(move) then
          state.moveIndex, b.moveIndex = index, index
          break
        end
      end
    end
  end
  if b and state and state.phase == "choose-forget"
      and (state.messageTimer or 0) <= 0 then
    local pending = state.pendingLearn
    local party = state.battle and state.battle.party
    local mon = pending and party and party[pending.index]
    if mon and type(mon.moves) == "table" and #mon.moves > 0 then
      b.prompt = "forget"
      b.forgetIndex = math.max(1, math.min(#mon.moves,
        tonumber(state.forgetIndex) or 1))
      b.forgetMoves = {}
      for slot, move in ipairs(mon.moves) do
        local def = (data.moves or {})[move.id] or {}
        b.forgetMoves[slot] = def.name or move.id
      end
      local move = pending.move or {}
      local def = (data.moves or {})[move.id] or {}
      b.learningMove = pending.moveName or def.name or move.id
    end
  end
  if a and b then
    for slot = 1, 4 do
      local before, after = (a.moves or {})[slot] or {}, (b.moves or {})[slot] or {}
      if before.pp ~= after.pp or before.disabled ~= after.disabled
          or before.disabledReason ~= after.disabledReason then return true end
    end
  end
  return (a and a.menuIndex) ~= (b and b.menuIndex)
    or (a and a.prompt) ~= (b and b.prompt)
    or (a and a.nativeMessage) ~= (b and b.nativeMessage)
    or (a and a.nativeCanReveal) ~= (b and b.nativeCanReveal)
    or (a and a.moveIndex) ~= (b and b.moveIndex)
    or (a and a.partyIndex) ~= (b and b.partyIndex)
    or (a and a.subIndex) ~= (b and b.subIndex)
    or (a and a.itemIndex) ~= (b and b.itemIndex)
    or (a and a.itemPocket) ~= (b and b.itemPocket)
    or (a and a.itemTitle) ~= (b and b.itemTitle)
    or (a and a.summaryPage) ~= (b and b.summaryPage)
    or (a and a.mimicIndex) ~= (b and b.mimicIndex)
    or (a and a.forgetIndex) ~= (b and b.forgetIndex)
end

-- Game path [Gen 1/2 vs Gen 3]: legacy visibility ownership excludes link battles and native Gen 3, whose presentation adapter owns the seam.
local function supportedBattleUI(state)
  if not state or state.nativeGen3 then return false end
  local kind = state.kind
  if state.battleKind ~= nil then
    if type(state.battleKind) ~= "function" then return false end
    local ok, value = pcall(state.battleKind, state)
    if not ok then return false end
    kind = value
  end
  return kind ~= "link"
end

THEME.supportedBattleUI = supportedBattleUI

local function caughtWild(kind, owned)
  return (kind == "wild" or kind == "safari") and owned == true
end

local function bottomOwnsBattleUI(enabled, active, available, ready,
                                 battleState, snapshot)
  return enabled and active and available and ready
    and snapshot ~= nil and supportedBattleUI(battleState) or false
end

local function battleChoice(state)
  -- Native party pickers also expose onChoose; they are not Yes/No prompts.
  return state and type(state.onChoose) == "function"
    and state.screenId ~= "PartyMenu" and state.screenId ~= "Gen2PartyMenu"
    and not state.isPartyMenu
    and type(state.index) == "number" and state.items == nil and state.pending == nil or false
end

local function categorizedBag(state)
  return state and (state.__pocketIndex ~= nil or state.pocketIndex ~= nil
    or state.modernBag ~= nil or state.__gen3uiBagPocketIndex ~= nil)
    or false
end

local function levelUpStatBox(state)
  return state and type(state.mon) == "table"
    and type(state.mon.stats) == "table" and not state.screenId or false
end

local PARTY_MENU_IDS = { PartyMenu = true, Gen2PartyMenu = true }

local BAG_MENU_IDS = { BagMenu = true, Gen2PackMenu = true }

local function battlePartyMenu(state)
  if not (state and (PARTY_MENU_IDS[state.screenId]
      or state.isPartyMenu == true))
      or type(state.index) ~= "number" then return nil end
  if state.isCancel ~= nil and type(state.isCancel) ~= "function" then
    return nil
  end
  if type(state.isCancel) == "function" then
    local ok = pcall(state.isCancel, state)
    if not ok then return nil end
  end
  if state.submenu then
    local submenu = type(state.submenu) == "table" and state.submenu or nil
    local items = state.subItems or (submenu and submenu.items)
    local index = state.subIndex or (submenu and submenu.index)
    if not rowsContract(items) or type(index) ~= "number" then return nil end
  end
  return state
end

-- Game path [Gen 1/2]: BagMenu uses items; PackMenu uses rows/pocket and message gates, so validate each native shape before taking input.
local function battleBagContract(state)
  if not (state and BAG_MENU_IDS[state.screenId]) then return false end
  if state.screenId == "Gen2PackMenu" then
    if state.message ~= nil or not rowsContract(state.rows)
        or type(state.index) ~= "number"
        or type(state.pocket) ~= "function" then return false end
    local ok, pocket = pcall(state.pocket, state)
    return ok and type(pocket) == "table"
  end
  if not rowsContract(state.items) or type(state.index) ~= "number" then
    return false
  end
  -- Mod path [Gen 1 + Gen3 UI]: extra categorized bag rows must satisfy their own cursor contract before accepting touches.
  if state.__gen3uiBagViewRows ~= nil then
    return rowsContract(state.__gen3uiBagViewRows)
      and type(state.__gen3uiBagViewIndex) == "number"
  end
  return true
end

local function ppItemMoveMenu(state)
  return state and state.kind == "pp_item_move"
    and rowsContract(state.items) and type(state.index) == "number"
    and state or nil
end

-- Game path [Gen 1/2]: Gen 1 supplies a glyph grid; Gen 2 supplies nine-column rows plus a three-button bottom row.
local function namingGrid(state)
  if not state or type(state.row) ~= "number"
      or type(state.col) ~= "number" then return nil end
  local grid
  if state.screenId == "NamingScreen" then
    if type(state.glyphs) ~= "table" or type(state.grid) ~= "function" then
      return nil
    end
    local ok
    ok, grid = pcall(state.grid, state)
    if not ok then return nil end
  elseif state.screenId == "Gen2NamingScreen" then
    if type(state.text) ~= "string" or type(state.rows) ~= "function" then
      return nil
    end
    local ok, rows = pcall(state.rows, state)
    if not ok or not rowsContract(rows) or #rows == 0 then return nil end
    grid = {}
    for index, row in ipairs(rows) do
      if #row ~= 9 then return nil end
      grid[index] = row
    end
    grid[#grid + 1] = {
      state.lower and "UPPER CASE" or "lower case", "DEL", "END",
    }
  else
    return nil
  end
  if not rowsContract(grid) or #grid == 0 then return nil end
  for _, row in ipairs(grid) do
    if #row == 0 then return nil end
  end
  return grid
end

local function moveLearnMenu(state)
  if not (state and state.screenId == "MoveLearnMenu")
      or type(state.mon) ~= "table"
      or type(state.mon.species) ~= "string" or state.newMoveId == nil
      or type(state.index) ~= "number" then return nil end
  if state.selecting and type(state.mon.moves) ~= "table" then return nil end
  return state
end

local function screenContract(state, kind)
  if kind == "party" then return battlePartyMenu(state) end
  if kind == "bag" then return battleBagContract(state) and state or nil end
  if kind == "pp" then return ppItemMoveMenu(state) end
  if kind == "naming" then return namingGrid(state) end
  if kind == "moveLearn" then return moveLearnMenu(state) end
  if kind == "forget" then
    local pending = state and state.phase == "choose-forget"
      and (state.messageTimer or 0) <= 0 and state.pendingLearn
    local party = state and state.battle and state.battle.party
    local mon = pending and party and party[pending.index]
    return mon and type(mon.moves) == "table" and #mon.moves > 0 and mon or nil
  end
  return state and (battlePartyMenu(state) or battleBagContract(state)
    or ppItemMoveMenu(state) or battleChoice(state) or levelUpStatBox(state))
    or false
end
  return battleChoice, bottomOwnsBattleUI, categorizedBag, caughtWild, localMapGrid, localMapLayout, localMapMode, prepareBattleSnapshot, screenContract, supportedBattleUI
end
