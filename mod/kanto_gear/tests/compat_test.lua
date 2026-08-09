package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local entry = assert(loadfile(path .. "/main.lua"))()
local upvalues = debug.getinfo(entry, "u").nups
local firstUpvalue = debug.getupvalue(entry, 1)
if firstUpvalue == "_ENV" then upvalues = upvalues - 1 end
T.check(upvalues <= 60,
  "Kanto Gear stays within LuaJIT's 60-upvalue function limit")
local newCanvas = T.love.graphics.newCanvas
T.love.graphics.newCanvas = function(...)
  local canvas = newCanvas(...)
  function canvas:requestImageData() return true end
  function canvas:pollImageData() return nil end
  return canvas
end
local run = T.sdk.loadMod(path, { data = T.fixtures.load() })
T.love.graphics.newCanvas = newCanvas
T.love.system.getPowerInfo = function() return "battery", 80 end

T.eq(#run.errors, 0,
  "Kanto Gear loads clean: " .. table.concat(run.errors, "; "))
T.check(run.loader.exports.kanto_gear ~= nil, "Kanto Gear registers")
local options = run.loader.optionSchemas.kanto_gear
T.eq(#options, 7, "Kanto Gear keeps its settings compact")
T.eq(options[1].label, "THEME", "theme setting is device-neutral")
T.eq(#options[1].choices, 9, "classic and modern themes share one setting")
T.eq(options[1].choices[3][2], "modern_light", "modern light theme is available")
T.eq(options[1].choices[4][2], "modern_dark", "modern dark theme is available")
T.eq(options[2].label, "INFO", "assist features use one preset")
T.eq(options[4].label, "GEAR SCREEN", "display setting is device-neutral")
T.eq(options[5].label, "BATTLE VIEW", "battle layout uses one setting")
T.eq(#options[5].choices, 3, "battle view exposes three clear layouts")
T.eq(options[6].label, "CAUGHT ICON", "caught marker has one clear toggle")
T.eq(options[7].label, "TRIGGER TABS", "trigger navigation is opt-in")
T.eq(options[7].default, false, "trigger navigation cannot claim controls by default")
local hooks = T.record.hooks(run.loader)
T.eq(hooks:depth("render.compose"), 1,
  "Kanto Gear uses the upstream composition seam")
T.eq(hooks:depth("render.output"), 1,
  "Kanto Gear owns final output only for a live screen swap")
T.eq(hooks:depth("input.pointer"), 1,
  "Kanto Gear uses the upstream pointer seam while swapped")
T.eq(hooks:depth("input.touchpressed"), 0,
  "Kanto Gear no longer needs private touch hooks")
T.eq(hooks:depth("ui.start_menu.items"), 1,
  "Kanto Gear publishes one conditional menu shortcut")
T.eq(hooks:depth("render.letterbox"), 0,
  "Kanto Gear no longer borrows the letterbox hook as a frame tick")
local standaloneMenu = run.loader.hooks:call("ui.start_menu.items",
  function(_, items) return items end, {}, {
    { label = "OPTION" }, { label = "MODS" },
  })
T.eq(#standaloneMenu, 2,
  "Kanto Gear leaves the Start menu unchanged without Modern UI")
run.loader.mods.gen1_modern_ui = {
  enabled = true, manifest = { version = "0.8.2" },
}
run.loader.exports.gen1_modern_ui = {}
local modernMenu = run.loader.hooks:call("ui.start_menu.items",
  function(_, items) return items end, {}, {
    { label = "OPTION" }, { label = "MODS" },
  })
T.eq(#modernMenu, 3, "Modern UI receives one Kanto Gear menu row")
T.eq(modernMenu[2].id, "kanto_gear.options",
  "Kanto Gear menu row is stable and anchored before MODS")
T.check(type(modernMenu[2].onSelect) == "function",
  "Kanto Gear menu row opens its existing options")
local composed = run.loader.hooks:call("render.compose",
  function() return "upstream" end, {}, {
    secondScreen = { detected = function() return false end,
                     pollTouch = function() return nil end },
  })
T.eq(composed, "upstream", "Kanto Gear preserves the upstream compositor result")

local displayDetected = true
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = { detected = function() return displayDetected end,
                   pollTouch = function() return nil end },
})
local swapPressed = true
local trigger = { left = 0, right = 0 }
T.love.joystick = { getJoysticks = function()
  return { {
    isGamepadDown = function(_, button)
      return button == "y" and swapPressed
    end,
    getGamepadAxis = function(_, axis)
      return axis == "triggerleft" and trigger.left or trigger.right
    end,
  } }
end }
local game = {
  data = run.data,
  save = {
    player = { name = "RED", id = 7, map = "PALLET_TOWN" },
    party = { {
      species = "PIKACHU", nickname = "PIKA", level = 5,
      hp = 20, stats = { hp = 20 }, exp = 0,
    } },
    money = 1234, playTime = 3661,
    inventory = { BOULDERBADGE = true },
    pokedex = { seen = {}, owned = {} },
  },
}
local world = { map = { id = "PALLET_TOWN" } }
game.overworld = world
game.stack = { states = { world }, top = function() return world end }
run.loader.events:emit("game.ready", { game = game })
T.eq(run.loader.hooks:call("battle.caught_marker_visible",
  function() return false end, {}), true,
  "Kanto Gear shows its caught icon by default")
run.loader.modOptions.kanto_gear = { caught_icon = false }
T.eq(run.loader.hooks:call("battle.caught_marker_visible",
  function() return true end, {}), true,
  "disabling Kanto's icon preserves another mod's marker")
T.eq(run.loader.hooks:call("battle.caught_marker_visible",
  function() return false end, {}), false,
  "disabling Kanto's icon does not force the native marker")
run.loader.modOptions.kanto_gear.caught_icon = true
for _, theme in ipairs({ "modern_light", "modern_dark", "kanto" }) do
  run.loader.modOptions.kanto_gear.theme = theme
  run.loader.events:emit("mod.options_changed",
    { mod = "kanto_gear", key = "theme" })
end
T.eq(#run.errors, 0, "theme changes apply live without mod errors")
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
swapPressed = false
run.loader.modOptions.kanto_gear.trigger_tabs = true
for i = 1, 3 do
  trigger.right = 0.8
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  if i == 1 then
    run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  end
  trigger.right = 0
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
end
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = { detected = function() return displayDetected end,
                   pollTouch = function() return nil end },
})
T.eq(#run.errors, 0, "trigger polling is safe and edge-triggered")
run.loader.events:emit("world.stepped", { mapId = "FIX_ROUTE" })

-- An animated sprite mod may resolve a menu front pic to a format LÖVE cannot
-- decode directly. Use the shared image-data loader before the icon fallback.
local Sprites = require("src.pokemon.Sprites")
local Assets = require("src.render.Assets")
local PartyMenu = require("src.ui.PartyMenu")
local spritePath, drawIcon = Sprites.path, PartyMenu.drawIcon
local imageData = Assets.imageData
local newImage = T.love.graphics.newImage
local fallbackIcons = 0
local fallbackIsWhite = false
local decodedFrames = 0
local genericSprites, ownedSprites = 0, 0
Sprites.path = function(_, _, _, opts)
  if opts and opts.mon then ownedSprites = ownedSprites + 1
  else genericSprites = genericSprites + 1 end
  return "unsupported.gif", true
end
Assets.imageData = function(path)
  if path == "unsupported.gif" then
    decodedFrames = decodedFrames + 1
    return "decoded-frame.png"
  end
  return imageData(path)
end
PartyMenu.drawIcon = function()
  fallbackIcons = fallbackIcons + 1
  local r, g, b, a = T.love.graphics.getColor()
  fallbackIsWhite = r == 1 and g == 1 and b == 1 and a == 1
end
T.love.graphics.newImage = function(path, ...)
  if path == "unsupported.gif" or path == "unavailable.gif" then
    error("unsupported image format")
  end
  return newImage(path, ...)
end
for _ = 1, 32 do
  trigger.right = 0.8
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  trigger.right = 0
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  run.loader.hooks:call("render.compose", function() return false end, {}, {
    secondScreen = { detected = function() return displayDetected end,
                     pollTouch = function() return nil end },
  })
  if decodedFrames > 0 and genericSprites > 0 and ownedSprites > 0 then break end
end
T.check(decodedFrames > 0,
  "unsupported hooked sprites use the shared image-data loader")
T.check(genericSprites > 0,
  "Guide sprites use the live sprite resolver")
T.check(ownedSprites > 0,
  "owned Pokemon screens pass their live Pokemon to the sprite resolver")
T.eq(fallbackIcons, 0,
  "decoded Party sprite frames do not use placeholder icons")
Sprites.path = function() return "unavailable.gif", true end
Assets.imageData = function(path)
  if path == "unavailable.gif" then error("unavailable image data") end
  return imageData(path)
end
for _ = 1, 32 do
  trigger.right = 0.8
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  trigger.right = 0
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  run.loader.hooks:call("render.compose", function() return false end, {}, {
    secondScreen = { detected = function() return displayDetected end,
                     pollTouch = function() return nil end },
  })
  if fallbackIcons > 0 then break end
end
Sprites.path, Assets.imageData, PartyMenu.drawIcon =
  spritePath, imageData, drawIcon
T.love.graphics.newImage = newImage
T.check(fallbackIcons > 0,
  "unsupported Party sprites fall back to official Pokemon icons")
T.check(fallbackIsWhite, "fallback Party icons keep their original colors")

T.eq(run.loader.hooks:call("render.output_enabled",
  function() return false end), true,
  "the screen-swap action enables swapped output while connected")
displayDetected = false
T.eq(run.loader.hooks:call("render.output_enabled",
  function() return false end), false,
  "disconnect bypasses swapped output immediately")

run.release()
T.finish("Kanto Gear compatibility")
