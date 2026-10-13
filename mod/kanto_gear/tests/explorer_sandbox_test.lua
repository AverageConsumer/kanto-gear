package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Sandbox = require("src.mods.Sandbox")
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local env = Sandbox.envFor({ modId = "kanto_gear", permissions = { engine_internals = true } })
local function read(name)
  local file = assert(io.open(root .. "/" .. name, "rb"))
  local source = file:read("*a"); file:close()
  return source
end
local function module(name)
  return assert(Sandbox.compile(read(name), "@" .. name, env))()
end
-- The headless graphics stub does not implement LÖVE's table colour overload.
local setColor = love.graphics.setColor
love.graphics.setColor = function(r, ...)
  if type(r) == "table" then return setColor(unpack(r)) end
  return setColor(r, ...)
end
local ui = { graphics = love.graphics, color = love.graphics.setColor, glyphs = function(value)
  local glyphs = {}
  for glyph in tostring(value):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    glyphs[#glyphs + 1] = glyph
  end
  return glyphs
end }
local theme = module("ui/base/init.lua")(ui, read)
module("ui/skins/init.lua")(theme, ui, read)
T.eq(env.debug, nil, "the production sandbox has no debug library")
T.eq(env.getfenv, nil, "the theme cannot escape its sandbox")

local model = { view = "wild", wildScope = "HERE", rows = { {}, {}, {}, {} },
  page = 1, pages = 1, mapZoom = 1, markers = {},
  overview = { width = 2, height = 2, rows = { { 1, 1 }, { 1, 1 } } },
  player = { mapId = "TEST", x = 0, y = 0 } }
for _, skin in ipairs({ "pokegear", "cgear" }) do
  theme:setSkin(skin)
  for _, dark in ipairs({ false, true }) do
    theme:setVariant(dark)
    local function hit(x, y) return theme:explorerHit(x / 1.5, y / 1.5, model) end
    T.eq(hit(70, 146), "wild_route", "HERE / ALL switch changes scope in the sandbox")
    T.eq(hit(120, 128), "trainers", "Trainers folder uses the new map frame")
    T.eq(hit(210, 128), "items", "Items folder uses the new map frame")
    local action, index = hit(210, 196)
    T.eq(action, "row", "fourth card remains interactive without debug")
    T.eq(index, 4, "fourth card opens the matching encounter")
    model.pages = 7
    T.eq(hit(30,146), nil, "selected HERE scope is inert")
    T.eq(hit(50,128), nil, "selected Wild tab no longer changes the filter")
    T.eq(hit(164,146), "prev", "separate left page key remains reachable")
    T.eq(hit(219,146), "next", "separate right page key remains reachable")
    action,index = hit(210,196)
    T.eq(action,"row","paging never replaces the fourth encounter")
    T.eq(index,4,"fourth encounter keeps its identity on a long list")
    T.eq(theme:explorerPerPage("wild",28),4,"long lists retain four entries per page")
    model.pages = 1
    local key = theme:explorerMotionKey(model, model.player)
    T.check(key ~= nil, "map motion uses the shared layout in the sandbox")
    local moved = { mapId = "TEST", x = 1, y = 0 }
    T.check(theme:explorerMotionKey(model, moved) ~= key,
      "player movement changes the retained map key")
    local print, printf = ui.graphics.print, ui.graphics.printf
    local shown = {}
    ui.graphics.print = function(value) shown[tostring(value)] = true end
    ui.graphics.printf = function(value) shown[tostring(value)] = true end
    theme:v4ExplorerDetail({ player = { x = 1.25, y = 2.5 } },
      { label = "POTION", x = 5, y = 6 }, "items")
    T.check(shown["7 Steps"] or shown["7 STEPS"],
      "smooth fractional player positions display a whole-step distance")
    ui.graphics.print, ui.graphics.printf = print, printf
    local portraits = {}
    local trainers = { view = "trainers", rows = { { label = "TRAINER" } },
      page = 1, pages = 1, markers = {},
      overview = { width = 2, height = 2, rows = { "..", ".." } },
      drawActor = function(_, x, y, scale, feet, limit)
        portraits[#portraits + 1] = { x, y, scale, feet, limit }
      end }
    local drawMap = theme.explorerMap
    theme.explorerMap = function() end -- Only the portrait cards are under test.
    theme:explorer(trainers)
    theme.explorerMap = drawMap
    T.eq(portraits[1][1], 23, "trainer list portrait uses the circle's horizontal center")
    T.eq(portraits[1][2], 170, "trainer list portrait uses the circle's vertical center")
    T.eq(portraits[1][4], false, "list portraits use center anchoring")
    T.eq(portraits[1][5], 20, "list portraits fit the circle's inner diameter")
    theme:v4ExplorerDetail(trainers, trainers.rows[1], "trainers")
    T.eq(portraits[2][1], 36, "trainer detail portrait uses the circle's horizontal center")
    T.eq(portraits[2][2], 126, "trainer detail portrait uses the circle's vertical center")
    T.eq(portraits[2][5], 40, "detail portraits leave breathing room inside the circle")
  end
end
love.graphics.setColor = setColor
T.finish("Explorer in the production sandbox")
