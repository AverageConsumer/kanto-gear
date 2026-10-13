local T = require("tests.modkit")
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local Presentation = assert(loadfile(path .. "/adapters/gen3/presentation.lua"))()
local modules, saved, calls = {}, {}, {}
for _, name in ipairs({ "src.core.game3.battle.ui", "src.core.game3.battle.healthbox",
    "src.ui.game3.battle_chrome", "src.ui.game3.frlg_font", "src.ui.game3.window",
    "src.ui.game3.message", "src.ui.game3.choice", "src.ui.game3.party_menu",
    "src.ui.game3.bag_menu", "src.ui.game3.tm_case", "src.ui.game3.berry_pouch",
    "src.ui.game3.summary_menu", "src.ui.game3.screens", "src.core.game3.oam" }) do
  saved[name] = package.loaded[name]
  local m = {}; modules[name], package.loaded[name] = m, m
  for _, method in ipairs({ "draw", "drawPanel", "drawMenuFrames", "drawTerrain", "cursorPx" }) do
    local key = name .. ":" .. method
    m[method] = function() calls[key] = (calls[key] or 0) + 1; return "native" end
  end
end
local skinDraws,skinInputs=0,0
local skin={draw=function() skinDraws=skinDraws+1 end,
  handleInput=function() skinInputs=skinInputs+1 end}
local Screens=modules["src.ui.game3.screens"]
local nativeSkin=function() return skin end
Screens.skin=nativeSkin
local U = modules["src.core.game3.battle.ui"]
local F = modules["src.ui.game3.frlg_font"]
local H = modules["src.core.game3.battle.healthbox"]
local C = modules["src.ui.game3.battle_chrome"]
local W = modules["src.ui.game3.window"]
local oldLove, bands, releases = love, {}, 0
love = { graphics = {
  newQuad = function(...) return { release = function() releases = releases + 1 end } end,
  draw = function(_, _, x, y) bands[#bands + 1] = y end,
} }
C.terrain = function() return { bgImage = {} } end
U.draw = function()
  C.drawTerrain("grass")
  C.drawPanel("menu"); C.drawMenuFrames("menu")
  F.draw("FIGHT", 136, 122); W.cursorPx(128, 122)
  F.draw("HP", 10, 20); H.draw("player", {})
end
local mode, errorNow = "standard", false
local nativeDraw = U.draw
U.draw = function(...) nativeDraw(...); if errorNow then error("draw failure") end end
local original = U.draw
local input = { wasPressed = function(_, key) return key == "right" or key == "a" end }
U.handleInput = function(i) return i:wasPressed("down"), i:wasPressed("right"), i:wasPressed("a") end
local O = modules["src.core.game3.oam"]
local P = modules["src.ui.game3.party_menu"]
local sprites = { { _id = 0 }, { _id = 1 }, { _id = 2 }, { _id = 3 } }
O.buildOamBuffer = function() O._buffer = sprites; return sprites end
local nativeBuffer = O.buildOamBuffer
P.open, P._oam, P._summaryIcon = true, { { mon = 0, ball = 1 } }, 2
local p = Presentation.new(function(kind) return mode ~= "standard" and ((kind ~= "hud" and kind ~= "navigation") or mode == "full") end)
local function count(name, method) return calls[name .. ":" .. method] or 0 end
T.eq(#O.buildOamBuffer(), 4, "Standard retains all native OBJ sprites")
U.draw()
Screens.skin("bag").draw({})
T.eq(skinDraws,1,"Companion retains direct profile skin rendering")
T.eq(#bands, 0, "standard leaves the native background unchanged")
T.eq(count("src.ui.game3.frlg_font", "draw"), 2, "standard preserves both command and HP printers")
mode = "gear"; U.draw()
Screens.skin("bag").draw({})
T.eq(skinDraws,1,"Gear hides a skin dispatched directly by UiPass")
local filtered = O.buildOamBuffer()
T.eq(#filtered, 1, "Gear removes menu icons including sprite ID zero")
T.eq(filtered[1], sprites[4], "unrelated sprite identity is retained")
T.eq(O._buffer, filtered, "both flush and priority flush see the filtered buffer")
T.eq(#sprites, 4, "native sprite records and original buffer are untouched")
P.open = false
T.eq(#O.buildOamBuffer(), 4, "closing the party releases the filter immediately")
P.open = true
T.eq(#bands, 6, "Gear continues six native ground bands under the removed panel")
T.eq(bands[1], 112, "ground starts exactly at the native panel boundary")
T.eq(bands[6], 152, "last eight-pixel band ends at the bottom edge")
C.drawTerrain("grass")
T.eq(#bands, 6, "terrain outside battle scope remains unchanged")
T.eq(count("src.ui.game3.frlg_font", "draw"), 3, "Gear removes only the command printer")
T.eq(count("src.ui.game3.window", "cursorPx"), 1, "Gear also removes its command cursor")
T.eq(count("src.ui.game3.battle_chrome", "drawPanel"), 1, "Gear removes command chrome")
T.eq(count("src.ui.game3.battle_chrome", "drawMenuFrames"), 1, "Gear removes Emerald's separate menu frame")
T.eq(count("src.core.game3.battle.healthbox", "draw"), 2, "Gear retains native healthboxes")
local down, right, confirm = U.handleInput(input)
T.check(not down and right and confirm, "presentation without a hero adapter retains native navigation")
mode = "full"; U.draw()
down, right, confirm = U.handleInput(input)
T.check(down and not right and confirm, "Full Gear transposes only directions")
T.eq(count("src.core.game3.battle.healthbox", "draw"), 2, "Full Gear relocates healthboxes")
T.eq(count("src.ui.game3.battle_chrome", "drawMenuFrames"), 1, "Full Gear removes Emerald's separate menu frame")
T.eq(C.drawMenuFrames("moves"), "native", "menu frames outside battle scope remain untouched")
T.eq(F.draw("FIELD TEXT", 10, 122), "native", "same coordinates outside battle rendering are untouched")
errorNow = true
T.check(not pcall(U.draw), "native render errors still propagate")
T.eq(F.draw("AFTER ERROR", 10, 122), "native", "failed draw restores printer scope")
T.eq(C.drawMenuFrames("menu"), "native", "failed draw restores menu-frame scope")
for _, name in ipairs({ "message", "choice", "bag_menu", "party_menu", "summary_menu" }) do
  modules["src.ui.game3." .. name].draw()
  T.eq(count("src.ui.game3." .. name, "draw"), 0, "owned " .. name .. " stays off the upper screen")
end
local wrapped = F.draw
F.draw = function(...) return wrapped(...) end
local wrappedInput = U.handleInput
U.handleInput = function(...) return wrappedInput(...) end
p:release()
T.eq(Screens.skin,nativeSkin,"release restores skin lookup")
skin.draw({})
T.eq(skinDraws,2,"release restores a previously borrowed skin draw")
T.eq(O.buildOamBuffer, nativeBuffer, "release restores the native OBJ builder")
T.eq(#O.buildOamBuffer(), 4, "release restores menu sprites without a state reset")
down, right, confirm = U.handleInput(input)
T.check(not down and right and confirm, "release leaves chained input as native passthrough")
T.eq(releases, 1, "owned quad is released without releasing the host texture")
T.eq(U.draw, original, "release restores native entry point")
T.eq(F.draw("CHAINED MOD", 10, 122), "native", "later mod wrapper survives release")
local allowed = true
U.tick = function() end
U.waitingForCommand = function() return true end
U._mode, U._menuIndex, U._active, U._actionCursor = "menu", 1, 2, {}
local hero = Presentation.new(function(kind)
  return allowed and (kind == "heroNavigation" or kind == "navigation")
end, function(_, direction) return direction == "down" and 4 or 2 end)
local moveAndConfirm = { wasPressed = function(_, key) return key == "down" or key == "a" end }
T.eq(U.handleInput(moveAndConfirm),true,"hero navigation consumes the directional press")
T.eq(U._menuIndex,4,"hero can cross the native grid diagonally")
T.eq(U._actionCursor[2],4,"hero updates the active battler cursor")
U._menuIndex=1
modules["src.ui.game3.choice"].active=true
local d, r, a = U.handleInput(moveAndConfirm)
T.check(d and a,"native choices keep direction and confirmation")
T.eq(U._menuIndex,1,"hero never moves under a choice")
modules["src.ui.game3.choice"].active=false
U._st={oldManTutorial=true}
U.handleInput(moveAndConfirm)
T.eq(U._menuIndex,1,"tutorial retains command authority")
U._st=nil
allowed=false
U.handleInput(moveAndConfirm)
T.eq(U._menuIndex,1,"lost presentation ownership restores native input")
hero:release()
local navigated=0
local menus=Presentation.new(function(kind) return kind=="menuNavigation" end,nil,nil,
  function(native,i) if i:wasPressed("right") then navigated=navigated+1;return true end end)
Screens.skin("bag").handleInput(input,{})
T.eq(navigated,1,"HUD skin input is intercepted before its original geometry rewrite")
T.eq(skinInputs,0,"handled lower navigation never reaches the original skin")
menus:release()
skin.handleInput(input,{})
T.eq(skinInputs,1,"release restores skin input")
for name in pairs(modules) do package.loaded[name] = saved[name] end
love = oldLove
T.finish("Native Gen3 presentation ownership")
