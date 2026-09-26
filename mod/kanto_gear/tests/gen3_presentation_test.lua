local T = require("tests.modkit")
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local Presentation = assert(loadfile(path .. "/gen3_presentation.lua"))()
local modules, saved, calls = {}, {}, {}
for _, name in ipairs({ "src.core.game3.battle.ui", "src.core.game3.battle.healthbox",
    "src.ui.game3.battle_chrome", "src.ui.game3.frlg_font", "src.ui.game3.window",
    "src.ui.game3.message", "src.ui.game3.choice", "src.ui.game3.party_menu",
    "src.ui.game3.bag_menu", "src.ui.game3.tm_case", "src.ui.game3.berry_pouch",
    "src.ui.game3.summary_menu" }) do
  saved[name] = package.loaded[name]
  local m = {}; modules[name], package.loaded[name] = m, m
  for _, method in ipairs({ "draw", "drawPanel", "cursorPx" }) do
    local key = name .. ":" .. method
    m[method] = function() calls[key] = (calls[key] or 0) + 1; return "native" end
  end
end
local U = modules["src.core.game3.battle.ui"]
local F = modules["src.ui.game3.frlg_font"]
local H = modules["src.core.game3.battle.healthbox"]
local C = modules["src.ui.game3.battle_chrome"]
local W = modules["src.ui.game3.window"]
U.draw = function()
  C.drawPanel("menu"); F.draw("FIGHT", 136, 122); W.cursorPx(128, 122)
  F.draw("HP", 10, 20); H.draw("player", {})
end
local mode, errorNow = "standard", false
local nativeDraw = U.draw
U.draw = function(...) nativeDraw(...); if errorNow then error("draw failure") end end
local original = U.draw
local p = Presentation.new(function(kind) return mode ~= "standard" and (kind ~= "hud" or mode == "full") end)
local function count(name, method) return calls[name .. ":" .. method] or 0 end
U.draw()
T.eq(count("src.ui.game3.frlg_font", "draw"), 2, "standard preserves both command and HP printers")
mode = "gear"; U.draw()
T.eq(count("src.ui.game3.frlg_font", "draw"), 3, "Gear removes only the command printer")
T.eq(count("src.ui.game3.window", "cursorPx"), 1, "Gear also removes its command cursor")
T.eq(count("src.ui.game3.battle_chrome", "drawPanel"), 1, "Gear removes command chrome")
T.eq(count("src.core.game3.battle.healthbox", "draw"), 2, "Gear retains native healthboxes")
mode = "full"; U.draw()
T.eq(count("src.core.game3.battle.healthbox", "draw"), 2, "Full Gear relocates healthboxes")
T.eq(F.draw("FIELD TEXT", 10, 122), "native", "same coordinates outside battle rendering are untouched")
errorNow = true
T.check(not pcall(U.draw), "native render errors still propagate")
T.eq(F.draw("AFTER ERROR", 10, 122), "native", "failed draw restores printer scope")
for _, name in ipairs({ "message", "choice", "bag_menu", "party_menu", "summary_menu" }) do
  modules["src.ui.game3." .. name].draw()
  T.eq(count("src.ui.game3." .. name, "draw"), 0, "owned " .. name .. " stays off the upper screen")
end
local wrapped = F.draw
F.draw = function(...) return wrapped(...) end
p:release()
T.eq(U.draw, original, "release restores native entry point")
T.eq(F.draw("CHAINED MOD", 10, 122), "native", "later mod wrapper survives release")
for name in pairs(modules) do package.loaded[name] = saved[name] end
T.finish("Native Gen3 presentation ownership")
