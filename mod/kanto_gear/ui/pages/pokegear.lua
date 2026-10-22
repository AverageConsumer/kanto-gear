-- The Gen 2 POKéGEAR on the touch screen. The native device keeps owning its
-- cards, radio shows, calls and map cursor; this page mirrors what it shows and
-- turns taps into the same moves its buttons make.
-- Game path [Gen 2]: this mirrors the games Pokegear clock/map/phone/radio, including owned cards; other games have no native Pokegear.
local Page = {}

local PHONE_ROWS, CONTACTS = 4, 10
local ORDER = { "clock", "map", "phone", "radio" }
local ICON = { clock = "pg_clock", map = "map", phone = "pg_phone", radio = "pg_radio" }

local function strings(value)
  local ok, Strings = pcall(require, "src.core.Strings")
  if ok and Strings and value then return tostring(Strings(value)) end
  return tostring(value or "")
end

-- Card ids the player owns, in the device's own order.
local function owned(native)
  local out, have = {}, {}
  for index, card in ipairs(native.cards or {}) do have[card.id] = index end
  for _, id in ipairs(ORDER) do
    if have[id] then out[#out + 1] = { id = id, index = have[id], icon = ICON[id],
      label = native.cardLabel and native:cardLabel(native.cards[have[id]]) or id:upper() } end
  end
  return out
end

local function clockModel(native)
  local hour, minute, weekday = native:clockParts()
  local ok, Clock = pcall(require, "src.core.gen2.Clock")
  local day = ok and Clock.weekdayName and Clock.weekdayName(weekday) or ""
  local h12 = hour % 12
  if h12 == 0 then h12 = 12 end
  return { hour = hour, minute = minute, h12 = h12, pm = hour >= 12, day = strings(day) }
end

local function phoneModel(native)
  local list = native:phoneList() or {}
  local selected = (native.phoneScroll or 0) + (native.phoneCursor or 0) + 1
  local rows = {}
  for slot = 1, CONTACTS do
    local id = list[slot] or 0
    if id ~= 0 then
      local name, className = native:contactRow(id)
      rows[#rows + 1] = { slot = slot, name = tostring(name or ""):gsub(":%s*$", ""),
        class = className and tostring(className) or nil, selected = slot == selected }
    end
  end
  local submenu
  if native.phoneSubmenu then
    local menus = getmetatable(native).PHONE_SUBMENUS or {}
    local menu = menus[native.phoneSubmenu]
    if menu then
      submenu = { cursor = (native.phoneSubmenuCursor or 0) + 1, entries = {} }
      for i, entry in ipairs(menu.entries) do submenu.entries[i] = entry end
    end
  end
  local call = native.call and { name = native.call.name and tostring(native.call.name) or nil,
    text = tostring(native.call.text or "") } or nil
  local ok, Phone = pcall(require, "src.core.gen2.Phone")
  local signal = not ok or not Phone.mapHasService or Phone.mapHasService(native:phoneContext())
  return { rows = rows, submenu = submenu, call = call, signal = signal }
end

local function mhz(value)
  local n = tonumber(value)
  return n and string.format("%.1f", n) or tostring(value or "")
end

local function radioModel(native)
  local stations, current = {}, native.tuningKnob or 0
  for _, row in ipairs(native:stations() or {}) do
    if row.station and row.name then
      stations[#stations + 1] = { knob = row.knob, frequency = mhz(row.frequency),
        name = strings(row.name), current = row.knob == current }
    end
  end
  local now = native:currentStation() or {}
  local radio = native.radio
  return { stations = stations, frequency = mhz(now.frequency),
    canTuneDown = current > 0, canTuneUp = current < 80,
    name = radio and radio.stationName and strings(radio.stationName) or now.name and strings(now.name) or nil,
    top = radio and radio.top or "", bottom = radio and radio.bottom or "" }
end

local function mapModel(native)
  local landmark, player = native:mapLandmark(), native:playerLandmark()
  local function name(entry) return entry and strings(entry.name or entry.label or entry.id) or "" end
  return { region = native:region() == "kanto" and "KANTO" or "JOHTO",
    landmark = name(landmark), player = name(player),
    here = landmark ~= nil and player ~= nil and landmark.index == player.index }
end

-- What changes the picture; sampled by the 50ms poll through items[1].right.
local function key(m)
  local parts = { m.mode, tostring(m.card), tostring(m.cardIndex), tostring(m.phonePage) }
  for _, card in ipairs(m.cards) do parts[#parts + 1] = card.id end
  if m.clock then parts[#parts + 1] = m.clock.hour .. ":" .. m.clock.minute .. m.clock.day end
  if m.phone then
    for _, row in ipairs(m.phone.rows) do parts[#parts + 1] = row.slot .. tostring(row.selected) .. row.name end
    parts[#parts + 1] = tostring(m.phone.submenu and m.phone.submenu.cursor)
    parts[#parts + 1] = tostring(m.phone.call and m.phone.call.text)
    parts[#parts + 1] = tostring(m.phone.signal)
  end
  if m.radio then
    -- the show's scrolling lines stay on the top screen; only the dial redraws here
    parts[#parts + 1] = m.radio.frequency .. tostring(m.radio.name)
  end
  if m.map then parts[#parts + 1] = m.map.landmark .. m.map.player end
  return table.concat(parts, "\31")
end

function Page.project(top, game, previous, appActive)
  local ok, Pokegear = pcall(require, "src.ui.gen2.Pokegear")
  if not ok or not top or getmetatable(top) ~= Pokegear then return end
  -- the fly picker and the wall map are their own screens
  if top.fly or top.townMap then return end
  local active = appActive or function() return game.stack:top() == top end
  if not active() then return end
  local view = previous
  local nativeKey = tostring(top) .. ":pokegear"
  if not view or view.nativeKey ~= nativeKey then
    local title = strings("<PO><KE>GEAR"):gsub("<PO><KE>", "POKé")
    view = { screenId = "CompanionMenu", nativeKey = nativeKey, title = title, fixedLayout = true,
      index = 1, update = function() end, valid = active, native = top }
  end
  local cards = owned(top)
  local current = top:card()
  local m = { mode = top.mode == "card" and "card" or "strip", cards = cards,
    card = current and current.id or nil, cardIndex = top.cardIndex }
  if m.mode == "card" and m.card then
    m.busy = m.card == "phone" and (top.call ~= nil or top.phoneSubmenu ~= nil)
    if m.card == "clock" then m.clock = clockModel(top)
    elseif m.card == "phone" then
      m.phone = phoneModel(top)
      -- the visible page follows the device's cursor until the player pages
      local selected = (top.phoneScroll or 0) + (top.phoneCursor or 0)
      if view.phoneSelected ~= selected then
        view.phoneSelected = selected
        for i, row in ipairs(m.phone.rows) do
          if row.selected then view.phonePage = math.floor((i - 1) / Page.PHONE_PAGE) + 1 end
        end
      end
      local pages = math.max(1, math.ceil(#m.phone.rows / Page.PHONE_PAGE))
      m.phonePage, m.phonePages = math.min(view.phonePage or 1, pages), pages
    elseif m.card == "radio" then m.radio = radioModel(top)
    elseif m.card == "map" then m.map = mapModel(top) end
  else
    m.clock = clockModel(top)
  end
  view.pokegearModel = m
  view.items = { { label = "POKEGEAR", right = key(m) } }
  return view
end

-- Layout, shared by draw and hit (240x216 Gear pixels).
Page.TOP = 34
function Page.tiles(count)
  local out = {}
  if count <= 1 then out[1] = { 7, 40, 226, 124 } return out end
  for i = 1, count do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local rows = math.ceil(count / 2)
    local h = rows == 1 and 124 or 60
    local w = (i == count and count % 2 == 1) and 226 or 110
    out[i] = { 7 + col * 116, 40 + row * (h + 4), w, h }
  end
  return out
end
function Page.tabs(count)
  local out, w = {}, math.floor((226 - (count - 1) * 4) / math.max(1, count))
  local left = math.floor((240 - (count * w + (count - 1) * 4)) / 2)
  for i = 1, count do out[i] = { left + (i - 1) * (w + 4), 32, w, 28 } end
  return out
end
Page.BODY = 60
function Page.phoneRow(i) return 7, Page.BODY + 2 + (i - 1) * 30, 226, 28 end
Page.PHONE_PAGE = 4
-- CALL / DELETE / CANCEL keys, clear of the fourth contact row (ends at 180)
Page.SUBMENU_Y, Page.SUBMENU_H = 183, 28
function Page.stationRect(i)
  local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
  return 7 + col * 116, 112 + row * 25, 110, 22
end

local function inside(x, y, rx, ry, rw, rh) return x >= rx and x < rx + rw and y >= ry and y < ry + rh end

function Page.hit(m, x, y)
  if y < 30 and x < 27 then return "back" end
  if m.mode == "strip" then
    for i, r in ipairs(Page.tiles(#m.cards)) do
      if inside(x, y, r[1], r[2], r[3], r[4]) then return "open", m.cards[i] end
    end
    return
  end
  if not m.busy then
    for i, r in ipairs(Page.tabs(#m.cards)) do
      if inside(x, y, r[1], r[2], r[3], r[4]) then
        if m.cards[i].id ~= m.card then return "switch", m.cards[i] end
        return
      end
    end
  end
  if m.phone then
    local p = m.phone
    if p.call then
      if inside(x, y, 64, 172, 112, 32) then return "hangup" end
      return
    end
    if p.submenu then
      local n = #p.submenu.entries
      local w = math.floor((226 - (n - 1) * 6) / n)
      for i = 1, n do
        if inside(x, y, 7 + (i - 1) * (w + 6), Page.SUBMENU_Y, w, Page.SUBMENU_H) then return "submenu", i end
      end
      return
    end
    local page = m.phonePage or 1
    for i = 1, Page.PHONE_PAGE do
      local row = p.rows[(page - 1) * Page.PHONE_PAGE + i]
      if row then
        local rx, ry, rw, rh = Page.phoneRow(i)
        if inside(x, y, rx, ry, rw, rh) then return "contact", row end
      end
    end
    if #p.rows > Page.PHONE_PAGE and y >= 182 then
      if x >= 10 and x < 34 then return "phone_prev" end
      if x >= 90 and x < 114 then return "phone_next" end
    end
  elseif m.radio then
    if m.radio.canTuneDown ~= false and inside(x, y, 7, 62, 34, 44) then return "tune", "down" end
    if m.radio.canTuneUp ~= false and inside(x, y, 199, 62, 34, 44) then return "tune", "up" end
    for i, row in ipairs(m.radio.stations) do
      local rx, ry, rw, rh = Page.stationRect(i)
      if ry + rh <= 214 and inside(x, y, rx, ry, rw, rh) then return "station", row end
    end
  elseif m.map then
    if inside(x, y, 7, 150, 110, 40) then return "map", "down" end
    if inside(x, y, 123, 150, 110, 40) then return "map", "up" end
  end
end

-- Moves the device the way its own buttons would. `press` queues a button.
function Page.apply(view, action, arg, press)
  local native = view.native
  if not native or not view.valid() then return false end
  if action == "back" then press("b")
  elseif action == "open" then
    native.cardIndex, native.mode = arg.index, "card"
  elseif action == "switch" then
    local card = native:card()
    if card and card.id == "radio" then native:stopRadio() end
    native:switchCard(arg.id)
  elseif action == "contact" then
    local slot = arg.slot - 1
    local scroll = native.phoneScroll or 0
    if slot < scroll then scroll = slot
    elseif slot > scroll + PHONE_ROWS - 1 then scroll = slot - PHONE_ROWS + 1 end
    scroll = math.max(0, math.min(CONTACTS - PHONE_ROWS, scroll))
    native.phoneScroll, native.phoneCursor = scroll, slot - scroll
    press("a")
  elseif action == "submenu" then
    native.phoneSubmenuCursor = arg - 1
    press("a")
  elseif action == "hangup" then press("a")
  elseif action == "station" then
    native.tuningKnob = arg.knob
    native:tuneRadio()
  elseif action == "tune" or action == "map" then press(arg)
  elseif action == "phone_prev" or action == "phone_next" then
    local pages = math.max(1, math.ceil(#view.pokegearModel.phone.rows / Page.PHONE_PAGE))
    local page = (view.phonePage or 1) + (action == "phone_next" and 1 or -1)
    view.phonePage = (page - 1) % pages + 1
  else return false end
  return true
end

return Page
