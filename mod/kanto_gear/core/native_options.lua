-- Shared touch presentation; the native menu still changes and persists options.
local Page = {}

function Page.window(total, selected)
  local page = math.floor((math.max(1, math.min(total, selected or 1)) - 1) / 4) + 1
  local first = (page - 1) * 4 + 1
  return first, math.max(0, math.min(4, total - first + 1)), page, math.max(1, math.ceil(total / 4))
end

local function signature(rows)
  local parts = {}
  for _, row in ipairs(rows) do
    parts[#parts + 1] = tostring(row) .. tostring(row.label) .. tostring(row.step)
      .. tostring(row.activate) .. tostring(row.cart) .. tostring(row.enabled)
  end
  return table.concat(parts, "\31")
end

function Page.project(top, game, generation, previous)
  local native, page, rows, context, current, select, isTop
  -- Game path [Gen 3 vs Gen 1/2]: options live in a native global layer/page stack; earlier engines keep an OptionsMenu on game.stack.
  if generation == 3 then
    if not top or top.id ~= "option" or not top.mod then return end
    native = top.mod
    local function activePage()
      local pages = native._pages or native._st and native._st.pages
      return pages and pages[#pages]
    end
    page = activePage()
    if not page then return end
    rows, context = page.rows, native._ctx or native._st.ctx
    current = function() return page.index end
    select = function(value) page.index, native.cursor = value, value end
    local hasShader, shader = pcall(require, "src.ui.game3.shaderfx_menu")
    isTop = function()
      return require("src.ui.game3.stack").top() == top and activePage() == page
        and not require("src.ui.game3.message").isOpen() and not require("src.ui.game3.choice").active
        and not (hasShader and shader.isOpen())
    end
  else
    if not top or getmetatable(top) ~= require(generation == 2 and "src.ui.gen2.OptionsMenu" or "src.ui.OptionsMenu") then return end
    native, rows, context = top, top.view or top.rows, game
    current = function() return native.index end
    select = function(value) native.index = value; if native.ensureVisible then native:ensureVisible() end end
    isTop = function() return game.stack:top() == top and (native.view or native.rows) == rows end
  end
  if not isTop() or type(rows) ~= "table" then return end
  local total = #rows - (rows[#rows] and rows[#rows].cancel and 1 or 0)
  local first, count, number, pages = Page.window(total, current())
  local key = tostring(top) .. ":options:" .. tostring(page or rows) .. ":" .. first .. ":" .. signature(rows)
  local view = previous
  if not view or view.nativeKey ~= key then
    view = { screenId = "CompanionMenu", nativeKey = key, title = "OPTIONS", fixedLayout = true, update = function() end }
    local order = signature(rows)
    view.valid = function() return isTop() and signature(rows) == order and Page.window(total, current()) == first end
    setmetatable(view, { __index = function(_, name) if name == "index" then return current() end end,
      __newindex = function(self, name, value) if name == "index" then select(value) else rawset(self, name, value) end end })
  end
  local Strings = require("src.core.Strings")
  local items, visible = {}, {}
  for index = 1, total do
    local row, value = rows[index], ""
    local label = Strings(row.label or "")
    -- Game path [Gen 3 vs Gen 2]: cart options use zero-based ROM choice tables; Gen 2 frame/text/value descriptors read native.options.
    if generation == 3 and row.cart then
      local cart, RomText = require("src.core.game3.options").block(context.options), require("src.core.game3.rom_text")
      label = RomText.plain(row.cart.label)
      value = row.cart.frame and tostring((cart[row.cart.key] or 0) + 1)
        or RomText.plain(row.cart.choices[(cart[row.cart.key] or 0) + 1])
    elseif generation == 2 and row.frame then value = tostring(native.options.frame or 1)
    elseif generation == 2 and row.text then value = row.text(native.options)
    elseif generation == 2 and row.values then
      local v = native.options[row.key]
      value = row.display and Strings(row.display[v]) or tostring(v)
    elseif row.value then
      local ok, result = pcall(row.value, context)
      value = ok and tostring(result or "") or "?"
    end
    items[index] = { label = tostring(label), right = tostring(value) }
    if index >= first and index < first + count then
      visible[#visible + 1] = { index = index, label = tostring(label), value = tostring(value),
        enabled = row.enabled ~= false, action = type(row.activate) == "function",
        adjustable = not row.activate and (row.step or row.cycle or row.values or row.frame or row.cart) and true or false }
    end
  end
  items[total + 1] = { label = "CANCEL" }
  view.items, view.touchWindow = items, { first = first, count = count }
  view.optionsModel = { rows = visible, first = first, page = number, pages = pages, enabled = view.valid() }
  return view
end

function Page.hit(model, x, y)
  if model.enabled == false then return end
  if x >= 0 and x < 27 and y >= 0 and y < 28 then return "back" end
  if y >= 194 and y < 212 then
    if x >= 72 and x < 104 and model.page > 1 then return "previous" end
    if x >= 136 and x < 168 and model.page < model.pages then return "next" end
  end
  for slot, row in ipairs(model.rows) do
    local top = 36 + (slot - 1) * 39
    if row.enabled and y >= top and y < top + 35 then
      if row.action and x >= 6 and x < 234 then return row.index, "a" end
      if row.adjustable and y >= top + 16 and y < top + 34 then
        if x >= 12 and x < 36 then return row.index, "left" end
        if x >= 204 and x < 228 then return row.index, "right" end
      end
    end
  end
end

function Page.draw(H, model)
  local c = H.colors
  for slot, row in ipairs(model.rows) do
    local y = 36 + (slot - 1) * 39
    local pressed = H:beginPress(6, y, 228, 35, model.enabled ~= false and row.enabled and row.action)
    H:panel(6, y, 228, 35, false, nil, c.greenLight)
    local ink = row.enabled and c.ink or c.disabledInk
    H:partyInfoCentered(H:fitPartyInfo(row.label, 208), 16, row.action and y or y + 3, 208, row.action and 35 or 13, ink)
    if not row.action then
      H:partyInfoCentered(H:fitPartyInfo(row.value, 152), 44, y + 19, 152, 13, row.enabled and c.green or c.disabledInk)
      if row.adjustable then
        -- Native descriptors do not expose clamp limits; arrows never animate a no-op.
        H:pageChevron(24, y + 25, false, false)
        H:pageChevron(216, y + 25, true, false)
      end
    end
    H:endPress(pressed)
  end
  if model.pages > 1 then
    H:panel(72, 194, 96, 17, false, nil, c.greenLight)
    if model.page > 1 then H:pageChevron(88, 202, false, model.enabled ~= false) end
    H:partyInfoCentered(model.page .. "/" .. model.pages, 104, 196, 32, 13, c.ink)
    if model.page < model.pages then H:pageChevron(152, 202, true, model.enabled ~= false) end
  end
end

return Page
