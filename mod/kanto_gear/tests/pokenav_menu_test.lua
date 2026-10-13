package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))

-- A small stand-in for the host's layer stack and PokéNav modules, so the
-- projection can be checked without a ROM cache.
local top
package.loaded["src.ui.game3.stack"] = { top = function() return top end }
package.loaded["src.ui.game3.message"] = { isOpen = function() return false end }
package.loaded["src.ui.game3.choice"] = { active = false }

local MainMenu = {}
MainMenu.__index = MainMenu
MainMenu.ITEMS = { [2] = { 0, 1, 2, 3, 4 }, [3] = { 5, 6, 7 }, [4] = { 8, 9, 10, 11, 12, 13 } }
function MainMenu:cursorMovedAnimations() self.animated = (self.animated or 0) + 1 end
function MainMenu:printDescription() self.description = "desc" .. self.currMenuItem end
function MainMenu:setInputHandler() self.handler = "main" end
package.loaded["src.ui.game3.rse.pokenav.main_menu"] = MainMenu
package.loaded["src.ui.game3.rse.pokenav.gfx"] = { plain = function(key) return "TEXT:" .. key end }

local rseShell
package.loaded["src.ui.game3.rse.pokenav.init"] = { active = function() return rseShell end }
local rsShell
package.loaded["src.ui.game3.rs.pokenav.init"] = { active = function() return rsShell end }

local UI = assert(loadfile(root .. "/tests/support/module.lua"))()(root, "adapters/gen3/ui")
local Menu = assert(loadfile(root .. "/adapters/start_menu.lua"))()
local ui = UI.new({ hoenn = true }, {})

-- Emerald main menu with Match Call and Ribbons
local screen = setmetatable({ menuType = 2, cursorPos = 0, currMenuItem = 0, description = "desc0" }, MainMenu)
rseShell = { phase = "menu", screen = screen, busy = function(_, co) return co == "busy" end }
top = { id = "rse_pokenav", mod = {} }
local view = ui:list(nil)
T.check(view ~= nil, "Emerald PokéNav main menu is mirrored")
T.eq(view.title, "POKéNAV", "PokéNav title")
T.eq(#view.items, 5, "five main menu features")
T.eq(view.items[1].label, "HOENN MAP", "map first")
T.eq(view.items[5].label, "SWITCH OFF", "switch off last")
T.eq(view.items[3].value, "pn_matchcall", "Match Call icon")
T.eq(view.index, 1, "cursor mirrors the device")
T.check(view.fixedLayout, "touch keys use fixed rectangles")
T.eq(view.items[5].rect[3], 226, "odd last tile spans the row")
T.eq(view.items[1].rect[3], 110, "grid tiles are half width")
T.eq(view.pokenavHelp, "TEXT:desc0", "description line follows the device")
T.check(view.valid(), "idle menu accepts touch")
view.index = 4
T.eq(screen.cursorPos, 3, "touch moves the native cursor")
T.eq(screen.currMenuItem, 3, "touch selects the native item")
T.eq(screen.animated, 1, "the device animates its cursor")
T.eq(view.index, 4, "view follows the device")
rseShell.loopTask = "busy"
T.check(not view.valid(), "busy device ignores touch")
T.check(view.valid(true), "busy device still previews")
view = ui:list(nil)
T.check(Menu.model(view).entries[1].disabled, "busy keys cannot animate touch feedback")
T.eq(Menu.hit(view, 12, 40), nil, "busy keys cannot be touched")
view.index = 1
T.eq(screen.cursorPos, 3, "busy touch cannot move the native cursor")
rseShell.loopTask = nil
view = ui:list(nil)
T.check(not Menu.model(view).entries[1].disabled, "idle keys become actionable again")
screen.targetMenuId = "region_map"
T.check(not view.valid(), "opening a feature hands control back")
screen.targetMenuId = nil
rseShell.phase = "field_fade"
T.eq(ui:list(nil), nil, "fading in shows nothing")
rseShell.phase = "menu"
rseShell.screen = {}
T.eq(ui:list(nil), nil, "feature screens keep native controls")

-- Condition search grid
rseShell.screen = setmetatable({ menuType = 4, cursorPos = 2, currMenuItem = 10 }, MainMenu)
view = ui:list(nil)
T.eq(#view.items, 6, "six searches")
T.eq(view.index, 3, "search cursor")
T.eq(view.items[6].label, "CANCEL", "cancel last")
T.eq(view.items[6].rect[3], 110, "even grid has no wide tile")

-- Ruby/Sapphire main menu without ribbons
rsShell = { phase = "active", menu = "main", cursor = 0, rows = { true, true, true, false, true }, busy = 0,
  nav = { menus = { main = { help = { "MAP HELP", "CONDITION HELP", "EYES HELP", "RIBBON HELP", "OFF HELP" } } } } }
top = { id = "rs_pokenav", mod = {} }
view = ui:list(nil)
T.check(view ~= nil, "Ruby/Sapphire PokéNav is mirrored")
T.eq(#view.items, 4, "locked ribbons stay hidden")
T.eq(view.items[3].label, "TRAINER'S EYES", "Trainer's Eyes")
T.eq(view.items[4].label, "SWITCH OFF", "switch off")
T.eq(view.pokenavHelp, "MAP HELP", "help line")
view.index = 4
T.eq(rsShell.cursor, 4, "touch maps to the native row, skipping hidden ones")
rsShell.busy = 3
T.check(not view.valid(), "sliding menu ignores touch")
view = ui:list(nil)
T.check(Menu.model(view).entries[1].disabled, "sliding Ruby/Sapphire keys stay still")
rsShell.busy = 0
rsShell.feature = {}
T.eq(ui:list(nil), nil, "map and graphs keep native controls")

T.finish("PokéNav menu projection")
