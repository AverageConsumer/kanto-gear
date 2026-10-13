package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))

-- A stand-in POKéGEAR: the real module as metatable, state and reads stubbed
-- on the instance, so the projection sees exactly what the device would.
local Pokegear = {}
Pokegear.__index = Pokegear
Pokegear.PHONE_SUBMENUS = { callDeleteCancel = { entries = { "CALL", "DELETE", "CANCEL" } },
  callCancel = { entries = { "CALL", "CANCEL" } } }
package.loaded["src.ui.gen2.Pokegear"] = Pokegear
package.loaded["src.core.Strings"] = setmetatable({}, { __call = function(_, v) return v end })
package.loaded["src.core.gen2.Clock"] = { weekdayName = function() return "SUNDAY" end }
package.loaded["src.core.gen2.Phone"] = { mapHasService = function() return true end }

local Page = assert(loadfile(root .. "/ui/pages/pokegear.lua"))()

local log = {}
local native = setmetatable({
  cards = { { id = "clock" }, { id = "map" }, { id = "phone" }, { id = "radio" } },
  cardIndex = 1, mode = "strip", phoneScroll = 0, phoneCursor = 0, tuningKnob = 28,
}, Pokegear)
function native:card() return self.cards[self.cardIndex] end
function native:cardLabel(card) return card.id:upper() end
function native:clockParts() return 20, 4, 1 end
function native:phoneList() return { 1, 2, 0, 5, 6, 7, 8, 9, 0, 10 } end
function native:contactRow(id) return "C" .. id .. ":", id > 2 and "CLASS" or nil end
function native:phoneContext() return {} end
function native:stations() return { { knob = 16, frequency = "4.5", station = "OAK", name = "OAK'S TALK" },
  { knob = 20, frequency = "5.5", station = nil }, { knob = 28, frequency = "7.5", station = "MUSIC", name = "MUSIC" } } end
function native:currentStation() return { knob = self.tuningKnob, frequency = "7.5", name = "MUSIC" } end
function native:mapLandmark() return { index = 3, name = "VIOLET CITY" } end
function native:playerLandmark() return { index = 3, name = "VIOLET CITY" } end
function native:region() return "johto" end
function native:switchCard(id)
  for i, c in ipairs(self.cards) do if c.id == id then self.cardIndex = i; log[#log + 1] = "switch:" .. id; return true end end
end
function native:stopRadio() log[#log + 1] = "stop" end
function native:tuneRadio() log[#log + 1] = "tune:" .. self.tuningKnob end

local top = native
local game = { stack = { top = function() return top end } }
local pressed = {}
local function press(key) pressed[#pressed + 1] = key end

local view = Page.project(native, game, nil)
T.check(view ~= nil, "the POKéGEAR is mirrored")
T.eq(view.screenId, "CompanionMenu", "companion projection")
T.eq(view.pokegearModel.mode, "strip", "card strip first")
T.eq(#view.pokegearModel.cards, 4, "every owned card")
T.check(view.valid(), "valid while on top")
T.eq(view.title, "POKéGEAR", "title from the native string")
local stripKey = view.items[1].right
native.cardIndex = 2
view = Page.project(native, game, view)
T.check(view.items[1].right ~= stripKey, "D-pad strip selection requests a repaint")
native.cardIndex = 1
for count = 1, 4 do
  local tabs = Page.tabs(count)
  T.check(math.abs(tabs[1][1] - (240 - tabs[count][1] - tabs[count][3])) <= 1,
    "the whole tab group has equal outer margins")
end

-- strip: a tile opens its card
local tiles = Page.tiles(4)
local r = tiles[4]
local action, arg = Page.hit(view.pokegearModel, r[1] + 5, r[2] + 5)
T.eq(action, "open", "tile opens a card")
T.eq(arg.id, "radio", "fourth tile is the radio")
Page.apply(view, action, arg, press)
T.eq(native.mode, "card", "device enters the card")
T.eq(native.cardIndex, 4, "device on the radio")

-- radio: stations with a show only, current lit
view = Page.project(native, game, view)
local m = view.pokegearModel
T.eq(m.card, "radio", "radio face")
T.eq(#m.radio.stations, 2, "dead air is not a station")
T.check(m.radio.stations[2].current, "tuned station lit")
local sx, sy = Page.stationRect(1)
action, arg = Page.hit(m, sx + 3, sy + 3)
T.eq(action, "station", "station tap")
Page.apply(view, action, arg, press)
T.eq(native.tuningKnob, 16, "knob moves to the station")
T.eq(log[#log], "tune:16", "device retunes like its dial")
action, arg = Page.hit(m, 210, 80)
T.eq(action, "tune", "fine tuning key")
Page.apply(view, action, arg, press)
T.eq(pressed[#pressed], "up", "right key tunes up")
native.tuningKnob = 80
view = Page.project(native, game, view)
T.eq(Page.hit(view.pokegearModel, 210, 80), nil, "upper radio boundary has no touch action")
native.tuningKnob = 0
view = Page.project(native, game, view)
T.eq(Page.hit(view.pokegearModel, 20, 80), nil, "lower radio boundary has no touch action")

-- tabs: leaving the radio stops the show first
local tabs = Page.tabs(4)
action, arg = Page.hit(m, tabs[3][1] + 4, tabs[3][2] + 4)
T.eq(action, "switch", "tab switches card")
Page.apply(view, action, arg, press)
T.eq(log[#log - 1], "stop", "radio stops before leaving")
T.eq(native.cardIndex, 3, "phone card")

-- phone: contacts only, page follows the cursor
native.phoneScroll, native.phoneCursor = 3, 2 -- slot 6
view = Page.project(native, game, view)
m = view.pokegearModel
T.eq(#m.phone.rows, 8, "empty slots are not rows")
T.eq(m.phone.rows[1].name, "C1", "colon stripped from names")
T.eq(m.phonePage, 2, "page holding the device cursor")
T.eq(m.phonePages, 2, "two pages")
local px, py = Page.phoneRow(4) -- page 2 row 4 = rows[8] = slot 10
action, arg = Page.hit(m, px + 10, py + 5)
T.eq(action, "contact", "contact tap")
T.eq(arg.slot, 10, "last contact")
Page.apply(view, action, arg, press)
T.eq(native.phoneScroll + native.phoneCursor + 1, 10, "device cursor on that slot")
T.check(native.phoneScroll <= 6 and native.phoneCursor <= 3, "scroll and cursor in range")
T.eq(pressed[#pressed], "a", "opens the contact menu")
view = Page.project(native, game, view) -- the poll sees the moved cursor
m = view.pokegearModel
action = Page.hit(m, 20, 190)
T.eq(action, "phone_prev", "page key")
Page.apply(view, action, nil, press)
view = Page.project(native, game, view)
T.eq(view.pokegearModel.phonePage, 1, "player paged back")

-- submenu and call own the face
native.phoneSubmenu, native.phoneSubmenuCursor = "callDeleteCancel", 0
view = Page.project(native, game, view)
m = view.pokegearModel
T.check(m.busy, "submenu blocks the tabs")
T.eq(Page.hit(m, tabs[1][1] + 4, tabs[1][2] + 4), nil, "no tab while busy")
action, arg = Page.hit(m, 120, 190)
T.eq(action, "submenu", "submenu key")
T.eq(arg, 2, "middle key is DELETE")
Page.apply(view, action, arg, press)
T.eq(native.phoneSubmenuCursor, 1, "device cursor on DELETE")
native.phoneSubmenu = nil
native.call = { name = "JOEY", text = "HI!" }
view = Page.project(native, game, view)
T.eq(Page.hit(view.pokegearModel, 120, 186), "hangup", "hang up key")
native.call = nil

-- map: keys walk the landmark cursor
native:switchCard("map")
view = Page.project(native, game, view)
m = view.pokegearModel
T.check(m.map.here, "cursor on the player's landmark")
action, arg = Page.hit(m, 180, 170)
T.eq(action, "map", "map key")
Page.apply(view, action, arg, press)
T.eq(pressed[#pressed], "up", "right key steps up")

-- back and ownership
T.eq(Page.hit(m, 5, 5), "back", "header back")
top = {}
T.check(not view.valid(), "a screen over the gear hands control back")
T.eq(Page.apply(view, "back", nil, press), false, "covered device rejects stale touch actions")
T.eq(Page.project(native, game, view), nil, "no projection under another screen")
top = native
native.fly = { {} }
T.eq(Page.project(native, game, view), nil, "fly picker keeps its own screen")
native.fly = nil

T.finish("POKéGEAR projection")
