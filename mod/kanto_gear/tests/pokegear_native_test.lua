package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Page = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/ui/pages/pokegear.lua"))()
local Pokegear = require("src.ui.gen2.Pokegear")
local Save = require("src.core.gen2.Save")
local Phone = require("src.core.gen2.Phone")
local save = Save.newGame()
save.version = os.getenv("POKEPORT_VERSION") or "crystal"
save.pokegearFlags = { map = true, phone = true, radio = true }
Phone.addContact(save, 1)
Phone.addContact(save, 15)
local input = { pressed = {} }
function input:wasPressed(key)
  local pressed = self.pressed[key]
  self.pressed[key] = nil
  return pressed == true
end
local top, closed
local game = { save = save, data = {}, input = input,
  stack = { top = function() return top end } }
local native = Pokegear.new(game, { clock = { hour = 20, minute = 4, weekday = 1 },
  onClose = function() closed = true end })
top = native
local view = Page.project(native, game)
T.eq(#view.pokegearModel.cards, 4, "actual host exposes all owned cards")
T.eq(view.pokegearModel.clock.day, "SUNDAY", "actual host weekday is projected")
local function action(kind, arg)
  T.check(Page.apply(view, kind, arg, function(key) input.pressed[key] = true end),
    "live device accepts " .. kind)
  native:update(0)
  view = Page.project(native, game, view)
end
action("open", view.pokegearModel.cards[3])
T.eq(view.pokegearModel.card, "phone", "touch enters the real phone")
local joey
for _, row in ipairs(view.pokegearModel.phone.rows) do
  if Phone.contacts(save)[row.slot] == 15 then joey = row end
end
T.check(joey ~= nil, "real contact list includes Joey")
action("contact", joey)
T.eq(native:phoneSelection(), 15, "touch addresses the actual contact slot")
T.eq(#view.pokegearModel.phone.submenu.entries, 3, "deletable contact exposes all native actions")
action("submenu", 3)
T.eq(native.phoneSubmenu, nil, "native cancel closes the submenu")
T.check(Phone.hasContact(save, 15), "cancel preserves the contact")
native.call = { kind = "nosignal", text = "NO SIGNAL" }
view = Page.project(native, game, view)
action("hangup")
T.eq(native.call, nil, "hangup uses the real phone handler")
action("switch", view.pokegearModel.cards[4])
T.eq(view.pokegearModel.card, "radio", "native radio opens and tunes")
T.check(#view.pokegearModel.radio.stations > 0, "actual host stations are projected")
local station = view.pokegearModel.radio.stations[1]
action("station", station)
T.eq(save.radioTuningKnob, station.knob, "native station selection is persisted")
action("switch", view.pokegearModel.cards[1])
T.eq(view.pokegearModel.card, "clock", "leaving the radio returns to the real clock")
action("back")
T.eq(native.mode, "strip", "native back returns to the card strip")
action("back")
T.check(closed, "native close callback remains intact")
T.finish("POKéGEAR actual host integration")
