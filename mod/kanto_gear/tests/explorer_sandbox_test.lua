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
local ui = { graphics = love.graphics, glyphs = function(value)
  local glyphs = {}
  for glyph in tostring(value):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    glyphs[#glyphs + 1] = glyph
  end
  return glyphs
end }
local theme = module("hgss.lua")(ui)
module("v4_skin.lua")(theme, ui, read)
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
    T.eq(hit(50, 128), "wild_route", "Wild folder switches scope in the sandbox")
    T.eq(hit(120, 128), "trainers", "Trainers folder uses the new map frame")
    T.eq(hit(210, 128), "items", "Items folder uses the new map frame")
    local action, index = hit(210, 196)
    T.eq(action, "row", "fourth card remains interactive without debug")
    T.eq(index, 4, "fourth card opens the matching encounter")
    local key = theme:explorerMotionKey(model, model.player)
    T.check(key ~= nil, "map motion uses the shared layout in the sandbox")
    local moved = { mapId = "TEST", x = 1, y = 0 }
    T.check(theme:explorerMotionKey(model, moved) ~= key,
      "player movement changes the retained map key")
  end
end
T.finish("Explorer in the production sandbox")
