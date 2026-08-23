package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local sourceFile = assert(io.open(path .. "/main.lua", "rb"))
local source = sourceFile:read("*a")
sourceFile:close()
local Summary = assert(loadfile(path .. "/summary.lua"))()
local gen1Summary = Summary.view({ screenId = "SummaryMenu", page = 2,
  mon = { species = "MON", level = 5, hp = 18, exp = 125,
    stats = { hp = 20, attack = 10, defense = 11, speed = 12, special = 13 },
    moves = {} } }, { data = { pokemon = { MON = { dex = 1, types = {
      "NORMAL" } } }, moves = {} }, save = { player = {} } })
T.eq(gen1Summary.pages, 2, "Gen 1 summaries keep their native two pages")
T.eq(gen1Summary.experience, 125, "Gen 1 summaries read Gen 1 experience")
local gen2State = { screenId = "Gen2SummaryMenu", page = 3,
  mon = { species = "MON", level = 5, hp = 20, maxHp = 21,
    experience = 140, item = "BERRY", moves = {}, stats = {
      hp = 21, attack = 11, defense = 12, specialAttack = 13,
      specialDefense = 14, speed = 15 } },
  itemName = function() return "BERRY" end,
  expToNext = function() return 60 end,
  otName = function() return "GOLD" end,
  otId = function() return 25 end }
local gen2Summary = Summary.view(gen2State, { data = { pokemon = {
  MON = { dex = 152, types = { "WATER" } } }, moves = {} },
  save = { player = {} } })
T.eq(gen2Summary.pages, 3, "Gen 2 summaries expose all three native pages")
T.eq(gen2Summary.stats.specialDefense, 14,
  "Gen 2 summaries retain split special stats")
T.eq(gen2Summary.item, "BERRY", "Gen 2 summaries retain held items")
gen2State.moveDetail = true
T.check(not Summary.supports(gen2State),
  "unknown summary subviews safely remain on the native screen")
T.check(not source:find("bottomSummary", 1, true),
  "summary ownership no longer depends on where it was opened")
T.check(not source:find("idleSummary", 1, true),
  "field summaries leave the companion page in place")
for _, module in ipairs({
  "src.core.Strings", "src.world.FieldDefaults", "src.inventory.Badges",
  "src.pokemon.Growth", "src.battle.TypeChart",
}) do
  T.check(not source:find(module, 1, true),
    "Kanto Gear no longer imports " .. module)
end
local Strings = require("src.core.Strings")
Strings.load({ strings = { ["POKé BALL"] = "POKEBALL" } })
local entry = assert(loadfile(path .. "/main.lua"))()
Strings.load({})
T.check(type(entry) == "function",
  "Kanto Gear loads while a translation catalog is already active")
T.check(not source:find("+%d MORE", 1, true),
  "INFO previews link to complete tables instead of hiding +more rows")
T.check(source:find("data.icons.icons.BALL", 1, true),
  "Gen 1 GUIDE uses its canonical ROM-provided Pokeball icon")
T.check(source:find("game.data.gen2MenuGfx", 1, true)
    and source:find("hud and hud.balls", 1, true),
  "Gen 2 GUIDE uses its canonical battle HUD Pokeball asset")
T.check(not source:find('box("fill", x + 2, y, 4, 1, INK)', 1, true),
  "GUIDE no longer draws a handmade Pokeball substitute")
T.check(source:find("row.caught and not caughtBall", 1, true),
  "GUIDE falls back to its CAUGHT label when the asset is unavailable")
local upvalues = debug.getinfo(entry, "u").nups
local firstUpvalue = debug.getupvalue(entry, 1)
if firstUpvalue == "_ENV" then upvalues = upvalues - 1 end
T.check(upvalues <= 60,
  "Kanto Gear stays within LuaJIT's 60-upvalue function limit")
local fit
for index = 1, debug.getinfo(entry, "u").nups do
  local name, value = debug.getupvalue(entry, index)
  if name == "fit" then fit = value break end
end
T.check(type(fit) == "function", "Kanto Gear text fitter is available")
T.eq(fit("¿ÁÉÍÓÚÜ Ñ¡", 20), "¿ÁÉÍÓÚÜ Ñ¡",
  "Spanish punctuation and accented letters survive text fitting")
T.eq(fit("MORN", 1, false), "M",
  "compact labels keep their first glyph instead of an ellipsis")
local methodLines
for index = 1, debug.getinfo(entry, "u").nups do
  local name, value = debug.getupvalue(entry, index)
  if name == "methodLines" then methodLines = value break end
end
T.check(not source:find("love.system", 1, true),
  "Kanto Gear uses sandbox-safe device and date/time facades")
T.check(type(methodLines) == "function",
  "Kanto Gear encounter method layout is available")
local method1, method2 = methodLines({
  { name = "CAMINANDO", min = 14, max = 29 },
})
T.eq(method1, "CAMINANDO", "long translated encounter methods stay intact")
T.eq(method2, "14-29%", "long encounter odds move to their own line")
local theme
for index = 1, debug.getinfo(entry, "u").nups do
  local name, value = debug.getupvalue(entry, index)
  if name == "THEME" then
    theme = value
    break
  end
end
T.check(theme ~= nil,
  "Kanto Gear owns a public translation-registry reference")
T.eq(#theme.gen2Badges.johto + #theme.gen2Badges.kanto, 16,
  "Gold trainer view accounts for all sixteen badges")
T.eq(theme:moveName({ id = "TACKLE", name = "TACKLE" }, {
  moves = { TACKLE = { name = "TACKLE-DE" } },
}), "TACKLE-DE", "move cards use the live translated move name")
T.eq(theme:typeName("POISON", { type_chart = {
  get = function(_, id) return id == "POISON" and { name = "GIFT" } end,
} }), "GIFT", "move details use the translated type registry")
T.eq(theme:typeName("CUSTOM", {}), "CUSTOM",
  "unknown move types keep their stable id")
T.eq(theme:statusName("PSN", { statuses = {
  get = function(_, id)
    return id == "PSN" and { label = "GIFT", hudLabel = "GIF" }
  end,
} }), "GIF", "party cards use the translated status registry")
local function displayDefaults(values)
  return theme:displayDefaults(function(key) return values[key] end)
end
local migratedMode, migratedLayout = displayDefaults({ window_layout = "large" })
T.eq(migratedMode, "combined", "legacy one-window users keep combined mode")
T.eq(migratedLayout, "overlay", "legacy large layout migrates to overlay")
local freshMode, freshLayout = displayDefaults({})
T.eq(freshMode, "separate", "existing device output remains the fresh default")
T.eq(freshLayout, "auto", "combined mode starts orientation-aware")
local fakeOptions = { values = {
  display_mode = "fullscreen", fullscreen_start = "game",
} }
function fakeOptions:get(key) return self.values[key] end
theme.displayModeDefault, theme.combinedLayoutDefault = "separate", "auto"
T.check(not theme:gearPrimary(fakeOptions, false)
    and theme:gearPrimary(fakeOptions, true),
  "fullscreen swap always has a route between Game and Gear")
T.eq(theme:windowLayout("off", 1280, 720), nil,
  "disabled window layout leaves native output untouched")
local stacked = theme:windowLayout("stacked", 1280, 720)
T.check(stacked.game.y + stacked.game.h < stacked.gear.y,
  "stacked layout keeps Game and Gear in separate rows")
local side = theme:windowLayout("side", 1280, 720)
T.check(side.game.x + side.game.w < side.gear.x,
  "side layout keeps Game and Gear in separate columns")
local autoSizedSide = theme:windowLayout(
  "side", 1280, 720, false, nil, false, "auto")
T.eq(autoSizedSide.gear.w, side.gear.w,
  "automatic secondary sizing preserves the established layout")
local balancedSide = theme:windowLayout(
  "side", 1280, 720, false, nil, false, 50)
T.check(math.abs(balancedSide.game.w - balancedSide.gear.w) <= 1,
  "50 percent gives split views equal layout space")
local gearHeavyStack = theme:windowLayout(
  "stacked", 1280, 720, false, nil, false, 65)
T.check(gearHeavyStack.gear.h > gearHeavyStack.game.h,
  "split layouts allow the secondary view to become larger")
local autoLandscape = theme:windowLayout("auto", 1280, 720)
local autoPortrait = theme:windowLayout("auto", 720, 1280)
T.check(autoLandscape.game.x + autoLandscape.game.w < autoLandscape.gear.x,
  "automatic landscape layout uses columns")
T.check(autoPortrait.game.y + autoPortrait.game.h < autoPortrait.gear.y,
  "automatic portrait layout uses rows")
local overlay = theme:windowLayout("overlay", 1280, 720)
T.eq(overlay.game.w, 1280, "overlay leaves the full width to the game")
T.eq(overlay.game.h, 720, "overlay leaves the full height to the game")
T.check(overlay.gear.w < overlay.game.w and overlay.gear.h < overlay.game.h,
  "overlay keeps Gear as the smaller surface")
local smallOverlay = theme:windowLayout(
  "overlay", 1280, 720, false, nil, false, 25)
local largeOverlay = theme:windowLayout(
  "overlay", 1280, 720, false, nil, false, 60)
T.check(smallOverlay.gear.w < largeOverlay.gear.w
    and smallOverlay.gear.h < largeOverlay.gear.h,
  "overlay size follows the shared secondary-size control")
local legacyLarge = theme:windowLayout("large", 1280, 720)
T.eq(legacyLarge.game.w, overlay.game.w,
  "the legacy large preset migrates to overlay")
local fullscreenGame = theme:windowLayout("fullscreen", 1280, 720)
local fullscreenGear = theme:windowLayout("fullscreen", 1280, 720, true)
T.check(fullscreenGame.showGame and not fullscreenGame.showGear
    and fullscreenGear.showGear and not fullscreenGear.showGame,
  "fullscreen swap draws only the selected surface")
local swapped = theme:windowLayout("side", 1280, 720, true)
T.eq(swapped.game.x, side.gear.x, "screen swap exchanges the Game slot")
T.eq(swapped.gear.x, side.game.x, "screen swap exchanges the Gear slot")
local swappedOverlay = theme:windowLayout("overlay", 1280, 720, true)
T.check(swappedOverlay.gameOnTop,
  "swapped overlay keeps the smaller Game surface visible above Gear")
local hiddenGame = theme:windowLayout(
  "overlay", 1280, 720, true, "bottom_right", true)
T.check(hiddenGame.showGear and not hiddenGame.showGame
    and not hiddenGame.gameOnTop,
  "hidden Gear-first overlay keeps Gear full and omits the smaller Game")
for _, layout in ipairs({ stacked, side, overlay, swapped, swappedOverlay }) do
  for _, rect in ipairs({ layout.game, layout.gear }) do
    T.check(rect.x >= 0 and rect.y >= 0
      and rect.x + rect.w <= 1280 and rect.y + rect.h <= 720,
      "window presets stay inside the output surface")
  end
end
local toxicDetails, toxicKnown = theme:moveDescription(
  { id = "TOXIC" }, { effect = "POISON_EFFECT" }, {})
T.check(toxicKnown and toxicDetails[1] == "BADLY POISONS TARGET",
  "move details describe move-specific Gen 1 behavior")
local unknownDetails, unknownKnown = theme:moveDescription(
  { id = "CUSTOM_MOVE" }, { effect = "CUSTOM_EFFECT" }, {})
T.check(not unknownKnown and unknownDetails[1] == "NO DETAILS AVAILABLE",
  "unknown mod effects are reported honestly")
local movesPath = os.getenv("KANTO_GEAR_MOVES_PATH")
if movesPath then
  local moves = assert(loadfile(movesPath))()
  local total, known = 0, 0
  for id, def in pairs(moves) do
    total = total + 1
    local lines, covered = theme:moveDescription({ id = id }, def, {
      focusEnergyBug = true,
      hyperBeamSkipRechargeOnKO = true,
    })
    if covered then known = known + 1 end
    for _, line in ipairs(lines) do
      T.check(#line <= 21, id .. " move detail fits the info panel")
    end
  end
  T.eq(known, total, "all imported Gen 1 moves have known details")
end
theme.strings = {
  get = function(_, source)
    return ({
      ["LEVEL UP"] = "LEVEL AUF",
      ["Trainer battle"] = "TRAINER-KAMPF",
      ["BADGES"] = "ORDEN",
      ["PP %d"] = "AP",
      ["TO LOWER"] = "KLEIN",
    })[source]
  end,
}
T.eq(fit("LEVEL UP", 20), "LEVEL AUF",
  "Kanto Gear reads the public Recomp strings registry")
T.eq(fit("Trainer battle", 20), "TRAINER-KAMPF",
  "battle headers use the catalog's canonical source spelling")
T.eq(fit("KANTO GEAR", 20), "KANTO GEAR",
  "untranslated Kanto Gear text keeps its English fallback")
T.eq(theme:format("%s %d/%d", theme:translate("BADGES"), 3, 8),
  "ORDEN 3/8", "dynamic UI text reuses translated labels")
T.eq(theme:format("PP %d", 12), "PP 12",
  "malformed dynamic translations fall back without losing values")
T.eq(theme:translate("TO LOWER"), "KLEIN",
  "non-tile-font controls use the same translation source")
theme.strings = nil
for _, stale in ipairs({
  'newDef.type or "STATUS"',
  'fit(mon.status, 3)',
  '("BADGES %d/%d"):format',
  '("GUIDE %d/%d"):format',
  '"SAFARI BALLS " ..',
}) do
  T.check(not source:find(stale, 1, true),
    "Kanto Gear avoids untranslated dynamic UI path " .. stale)
end
local newCanvas = T.love.graphics.newCanvas
local modCanvas
T.love.graphics.newCanvas = function(...)
  local canvas = newCanvas(...)
  function canvas:requestImageData() return true end
  function canvas:pollImageData() return nil end
  modCanvas = modCanvas or canvas
  return canvas
end
local run = T.sdk.loadMod(path, { data = T.fixtures.load() })
T.love.graphics.newCanvas = newCanvas
T.love.system.getPowerInfo = function() return "battery", 80 end

T.eq(#run.errors, 0,
  "Kanto Gear loads clean: " .. table.concat(run.errors, "; "))
T.check(run.loader.exports.kanto_gear ~= nil, "Kanto Gear registers")
local options = run.loader.optionSchemas.kanto_gear
T.eq(#options, 16, "Kanto Gear keeps one compact display hierarchy")
T.eq(options[1].label, "THEME", "theme setting is device-neutral")
T.eq(#options[1].choices, 9, "classic and modern themes share one setting")
T.eq(options[1].choices[3][2], "modern_light", "modern light theme is available")
T.eq(options[1].choices[4][2], "modern_dark", "modern dark theme is available")
T.eq(options[2].label, "CLOCK", "clock source is one compact choice")
T.eq(options[2].default, "game", "Gen 2 follows its encounter clock by default")
T.eq(options[3].label, "INFO", "assist features use one preset")
T.eq(options[5].label, "DISPLAY MODE", "display modes share one entry point")
T.eq(#options[5].choices, 3, "display mode exposes three clear families")
T.eq(options[6].label, "START SCREEN", "fullscreen owns its start surface")
T.eq(options[6].visible_if.equals, "fullscreen",
  "fullscreen settings stay inside fullscreen mode")
T.eq(options[7].label, "LAYOUT", "combined mode owns its layout")
T.eq(options[7].default, "auto", "combined layout adapts by default")
T.eq(#options[7].choices, 4, "combined mode exposes four compact presets")
T.eq(options[8].label, "PRIMARY VIEW", "combined mode can invert its priority")
T.eq(options[9].label, "SECONDARY SIZE", "combined layouts share one size control")
T.eq(options[9].default, "auto", "existing layout sizes remain the default")
T.eq(#options[9].choices, 14, "secondary sizing offers granular safe presets")
T.eq(options[10].label, "OVERLAY CORNER", "overlay owns one position setting")
T.eq(options[10].default, "bottom_right", "overlay keeps its familiar corner")
T.eq(#options[10].choices, 4, "overlay supports every screen corner")
T.eq(options[11].label, "OVERLAY BUTTON", "overlay owns one visibility shortcut")
T.eq(options[11].default, "off", "overlay cannot claim a button by default")
T.eq(options[12].label, "GEAR OUTPUT", "separate mode owns its output target")
T.eq(options[12].visible_if.equals, "separate",
  "separate output stays inside separate mode")
T.eq(options[13].label, "QUICK SWAP (Y)", "live swapping names its control")
T.eq(options[13].default, false, "screen swap cannot claim Y by default")
T.eq(options[13].visible_if.not_equals, "fullscreen",
  "fullscreen swap claims Y explicitly through its selected mode")
T.eq(options[14].label, "BATTLE VIEW", "battle layout uses one setting")
T.eq(#options[14].choices, 4, "battle view exposes four clear layouts")
T.eq(options[14].choices[4][2], "info",
  "battle view offers a read-only enemy information layout")
T.eq(options[15].label, "CAUGHT ICON", "caught marker has one clear toggle")
T.eq(options[16].label, "TRIGGER TABS", "trigger navigation is opt-in")
T.eq(options[16].default, false, "trigger navigation cannot claim controls by default")
local hooks = T.record.hooks(run.loader)
T.eq(hooks:depth("render.compose"), 1,
  "Kanto Gear uses the upstream composition seam")
T.eq(hooks:depth("render.output"), 1,
  "Kanto Gear owns final output only for a live screen swap")
T.eq(hooks:depth("render.viewport"), 1,
  "Kanto Gear can reserve a native game viewport")
T.eq(hooks:depth("render.window"), 1,
  "Kanto Gear decorates the remaining host window")
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
local swapPressed, infoPressed, overlayPressed, swapPolls = true, false, false, 0
local trigger = { left = 0, right = 0 }
T.love.joystick = { getJoysticks = function()
  return { {
    isGamepadDown = function(_, button)
      if button == "y" then swapPolls = swapPolls + 1 end
      return button == "y" and swapPressed
        or button == "x" and infoPressed
        or button == "rightstick" and overlayPressed
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
game.stack = { states = { world }, top = function(self)
  return self.states[#self.states]
end }
run.loader.events:emit("game.ready", { game = game })
T.eq(run.loader.hooks:call("render.output_enabled",
  function() return false end), false,
  "Y screen swapping is disabled by default")
run.loader.modOptions.kanto_gear = {
  display_mode = "combined", combined_layout = "stacked",
}
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "display_mode" })
local companionDisables = 0
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = { setEnabled = function(on)
    if on == false then companionDisables = companionDisables + 1 end
  end },
})
T.check(companionDisables > 0,
  "one-window layout dismisses a stale physical companion surface")
T.eq(run.loader.hooks:call("render.output_enabled",
  function() return false end), true,
  "one-window layout does not require a physical companion display")
local outputCanvas = T.love.graphics.newCanvas(640, 576)
T.eq(run.loader.hooks:call("render.output", function() return false end, {
  canvas = outputCanvas, width = 1280, height = 720,
}), true, "one-window layout owns the enabled final output")
local outputDraws = {}
local outputDraw = T.love.graphics.draw
T.love.graphics.draw = function(image, ...)
  outputDraws[#outputDraws + 1] = { image = image, args = { ... } }
  return outputDraw(image, ...)
end
run.loader.hooks:call("render.output", function() return false end, {
  canvas = outputCanvas, width = 1280, height = 720,
  gameX = 80, gameY = 72, gameWidth = 480, gameHeight = 432,
})
T.love.graphics.draw = outputDraw
T.eq(#outputDraws, 2,
  "one-window output draws exactly the Game and Gear surfaces")
T.eq(outputDraws[1].image, outputCanvas, "one-window output draws Game first")
local gameFit = theme:fitRect(
  theme:windowLayout("stacked", 1280, 720).game, 640, 576)
T.eq(outputDraws[1].args[1], gameFit.x,
  "one-window output preserves the complete composed Game frame")
local nativeGameRect = run.loader.hooks:call("render.viewport", function(ctx)
  return { x = 0, y = 0, width = ctx.width, height = ctx.height }
end, { width = 1280, height = 720, generation = 1 })
local nativeLayout = theme:windowLayout("stacked", 1280, 720)
T.eq(nativeGameRect.width, nativeLayout.game.w,
  "native viewport gives the Game its real layout width")
T.eq(nativeGameRect.height, nativeLayout.game.h,
  "native viewport gives the Game its real layout height")
T.eq(run.loader.hooks:call("render.output_enabled",
  function() return false end), false,
  "native viewport avoids rescaling the finished Game frame")
local nativeDraws = {}
T.love.graphics.draw = function(image, ...)
  nativeDraws[#nativeDraws + 1] = { image = image, args = { ... } }
end
local nativeCanvas = T.love.graphics.newCanvas(
  nativeGameRect.width, nativeGameRect.height)
T.eq(run.loader.hooks:call("render.window", function(_, context)
  T.love.graphics.draw(context.canvas, context.x, context.y)
end, game, {
  canvas = nativeCanvas,
  x = nativeGameRect.x, y = nativeGameRect.y,
  width = nativeGameRect.width, height = nativeGameRect.height,
  windowWidth = 1280, windowHeight = 720, generation = 1,
}), true, "native window layout owns its companion region")
T.love.graphics.draw = outputDraw
T.eq(#nativeDraws, 2,
  "native window draws the reflowed Game once and Gear once")
T.eq(nativeDraws[1].image, nativeCanvas,
  "native window presents the host-rendered Game without scaling")
local pointerPasses = 0
local gearRect = theme:fitRect(
  theme:windowLayout("stacked", 1280, 720).gear, 160, 144)
run.loader.hooks:call("input.pointer", function()
  pointerPasses = pointerPasses + 1
  return false
end, game, { phase = "pressed", x = 100, y = 100 })
T.eq(pointerPasses, 1, "touch outside Gear remains native game input")
run.loader.hooks:call("input.pointer", function()
  pointerPasses = pointerPasses + 1
  return false
end, game, { phase = "pressed",
  x = gearRect.x + gearRect.w / 2, y = gearRect.y + gearRect.h / 2 })
T.eq(pointerPasses, 1, "touch inside Gear is consumed by Kanto Gear")
run.loader.hooks:call("input.pointer", function() return false end, game, {
  phase = "cancelled", x = gearRect.x, y = gearRect.y,
})
run.loader.modOptions.kanto_gear = {
  display_mode = "combined", combined_layout = "overlay",
  combined_primary = "game",
}
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "combined_primary" })
local overlayPrimaryRect = run.loader.hooks:call("render.viewport", function(ctx)
  return { x = 0, y = 0, width = ctx.width, height = ctx.height }
end, { width = 1280, height = 720, generation = 1 })
T.check(overlayPrimaryRect.capture,
  "Game-first overlay requests final window composition")
local topLeft = theme:windowLayout("overlay", 1280, 720, false, "top_left")
T.check(topLeft.gear.x < 20 and topLeft.gear.y < 20,
  "overlay corner moves the smaller surface without changing its layout")
run.loader.modOptions.kanto_gear.overlay_button = "rightstick"
overlayPressed = true
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
local hiddenOverlayRect = run.loader.hooks:call("render.viewport", function(ctx)
  return { x = 0, y = 0, width = ctx.width, height = ctx.height }
end, { width = 1280, height = 720, generation = 1 })
T.check(not hiddenOverlayRect.capture,
  "overlay button hides the smaller Gear surface")
overlayPressed = false
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
overlayPressed = true
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
overlayPressed = false
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
local shownOverlayRect = run.loader.hooks:call("render.viewport", function(ctx)
  return { x = 0, y = 0, width = ctx.width, height = ctx.height }
end, { width = 1280, height = 720, generation = 1 })
T.check(shownOverlayRect.capture,
  "overlay button restores the smaller Gear surface")
run.loader.modOptions.kanto_gear.combined_primary = "gear"
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "combined_primary" })
local overlayGameRect = run.loader.hooks:call("render.viewport", function(ctx)
  return { x = 0, y = 0, width = ctx.width, height = ctx.height }
end, { width = 1280, height = 720, generation = 1 })
local overlayDraws = {}
T.love.graphics.draw = function(image, ...)
  overlayDraws[#overlayDraws + 1] = image
end
local overlayCanvas = T.love.graphics.newCanvas(
  overlayGameRect.width, overlayGameRect.height)
run.loader.hooks:call("render.window", function(_, context)
  T.love.graphics.draw(context.canvas, context.x, context.y)
end, game, {
  canvas = overlayCanvas,
  x = overlayGameRect.x, y = overlayGameRect.y,
  width = overlayGameRect.width, height = overlayGameRect.height,
  windowWidth = 1280, windowHeight = 720, generation = 1,
})
T.love.graphics.draw = outputDraw
T.eq(#overlayDraws, 3,
  "Gear-first overlay redraws the smaller Game surface on top")
T.eq(overlayDraws[3], overlayCanvas,
  "swapped overlay keeps the Game surface visible")
run.loader.hooks:call("input.pointer", function()
  pointerPasses = pointerPasses + 1
  return false
end, game, { phase = "pressed",
  x = overlayGameRect.x + overlayGameRect.width / 2,
  y = overlayGameRect.y + overlayGameRect.height / 2 })
T.eq(pointerPasses, 2,
  "the smaller Game overlay keeps native pointer input")
overlayPressed = true
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
local hiddenGameRect = run.loader.hooks:call("render.viewport", function(ctx)
  return { x = 0, y = 0, width = ctx.width, height = ctx.height }
end, { width = 1280, height = 720, generation = 1 })
local hiddenGameDraws = {}
T.love.graphics.draw = function(image, ...)
  hiddenGameDraws[#hiddenGameDraws + 1] = image
end
run.loader.hooks:call("render.window", function(_, context)
  T.love.graphics.draw(context.canvas, context.x, context.y)
end, game, {
  canvas = T.love.graphics.newCanvas(hiddenGameRect.width, hiddenGameRect.height),
  x = hiddenGameRect.x, y = hiddenGameRect.y,
  width = hiddenGameRect.width, height = hiddenGameRect.height,
  windowWidth = 1280, windowHeight = 720, generation = 1,
})
T.love.graphics.draw = outputDraw
T.eq(#hiddenGameDraws, 1,
  "hidden Gear-first overlay never presents the captured Game frame")
overlayPressed = false
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
run.loader.modOptions.kanto_gear = {
  display_mode = "fullscreen", fullscreen_start = "game",
  screen_swap = false,
}
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "display_mode" })
local fullscreenRect = run.loader.hooks:call("render.viewport", function(ctx)
  return { x = 0, y = 0, width = ctx.width, height = ctx.height }
end, { width = 1280, height = 720, generation = 1 })
T.check(not fullscreenRect.capture,
  "fullscreen Game does not pay for a final capture")
local fullscreenDraws = {}
T.love.graphics.draw = function(image, ...)
  fullscreenDraws[#fullscreenDraws + 1] = image
end
local fullscreenCanvas = T.love.graphics.newCanvas(
  fullscreenRect.width, fullscreenRect.height)
local fullscreenContext = {
  canvas = fullscreenCanvas, x = fullscreenRect.x, y = fullscreenRect.y,
  width = fullscreenRect.width, height = fullscreenRect.height,
  windowWidth = 1280, windowHeight = 720, generation = 1,
}
run.loader.hooks:call("render.window", function(_, context)
  T.love.graphics.draw(context.canvas, context.x, context.y)
end, game, fullscreenContext)
T.eq(#fullscreenDraws, 1,
  "fullscreen Game does not paint a hidden Gear surface")
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
fullscreenDraws = {}
local fullscreenGearRect = run.loader.hooks:call("render.viewport", function(ctx)
  return { x = 0, y = 0, width = ctx.width, height = ctx.height }
end, { width = 1280, height = 720, generation = 1 })
T.check(fullscreenGearRect.capture,
  "fullscreen Gear requests final window composition")
run.loader.hooks:call("render.window", function(_, context)
  T.love.graphics.draw(context.canvas, context.x, context.y)
end, game, fullscreenContext)
T.love.graphics.draw = outputDraw
T.eq(#fullscreenDraws, 1,
  "fullscreen Gear omits the hidden Game surface after a Y swap")
swapPressed = false
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
swapPressed, swapPolls = true, 0
local ownedDraws = 0
T.love.graphics.draw = function(...)
  ownedDraws = ownedDraws + 1
  return outputDraw(...)
end
T.eq(run.loader.hooks:call("render.output", function() return true end, {
  canvas = outputCanvas, width = 1280, height = 720,
}), true, "an earlier final-output owner remains authoritative")
T.love.graphics.draw = outputDraw
T.eq(ownedDraws, 0, "Kanto Gear does not paint over another output owner")
run.loader.modOptions.kanto_gear = { display_mode = "separate" }
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "display_mode" })
local separateEnabled = false
local desktopFrames = 0
local requestImageData, pollImageData = modCanvas.requestImageData,
  modCanvas.pollImageData
modCanvas.requestImageData, modCanvas.pollImageData = nil, nil
function modCanvas:newImageData() return {} end
run.loader.hooks:call("render.compose", function() return false end, {}, {
  secondScreen = { detected = function() return displayDetected end,
                   pollTouch = function() return nil end,
                   push = function() desktopFrames = desktopFrames + 1 return true end,
                   setEnabled = function(on) separateEnabled = on end },
})
modCanvas.requestImageData, modCanvas.pollImageData = requestImageData,
  pollImageData
modCanvas.newImageData = nil
T.eq(separateEnabled, true,
  "separate mode enables the host's companion display")
T.eq(desktopFrames, 1,
  "desktop hosts submit a synchronous fallback frame")
do
  local previousStates = game.stack.states
  function modCanvas:newImageData() return {} end
  local composeHook
  for _, hook in ipairs(run.loader.hooks.chains["render.compose"] or {}) do
    if hook.owner == "kanto_gear" then composeHook = hook.callback end
  end
  local root = { screenId = "BoxMenu", items = {}, index = 1 }
  local replacements = {
    { { world, { screenId = "BoxMenu", holdsUIAnchors = true } },
      "replacement PC root" },
    { { world, { screenId = "NamingScreen", glyphs = {}, row = 1, col = 1 } },
      "replacement naming screen" },
    { { world, { screenId = "MoveLearnMenu" } },
      "replacement move-learning screen" },
    { { world, root, { kind = "pc_box_withdraw" } },
      "replacement PC sublist" },
  }
  local ok, err = true
  for _, case in ipairs(replacements) do
    game.stack.states = case[1]
    local rendered, renderErr = pcall(function()
      composeHook(function() return false end, {}, {
        secondScreen = {
          detected = function() return true end,
          pollTouch = function() return nil end,
          push = function() return true end,
        },
      })
    end)
    if not rendered then
      ok, err = false, case[2] .. ": " .. tostring(renderErr)
      break
    end
  end
  modCanvas.newImageData = nil
  game.stack.states = previousStates
  T.check(ok,
    "replacement menu screens fall back safely: " .. tostring(err))
end
T.eq(run.loader.hooks:call("render.output_enabled",
  function() return false end), false,
  "disabling one-window layout restores native output")
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
T.eq(swapPolls, 0, "disabled screen swapping never polls Y")
run.loader.modOptions.kanto_gear = { screen_swap = true }
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "screen_swap" })
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
T.check(swapPolls > 0, "enabled screen swapping polls Y")
do
  local summary = { screenId = "SummaryMenu", page = 1,
    mon = game.save.party[1] }
  local previousStates = game.stack.states
  local summaryHook
  for _, entry in ipairs(run.loader.hooks.chains["screen.render_visible"] or {}) do
    if entry.owner == "kanto_gear" then summaryHook = entry.callback end
  end
  local readyUpvalue
  local battleUpvalue
  for i = 1, debug.getinfo(summaryHook, "u").nups do
    local name = debug.getupvalue(summaryHook, i)
    if name == "displayReady" then
      readyUpvalue = i
    elseif name == "battle" then
      battleUpvalue = i
    end
  end
  T.check(readyUpvalue ~= nil, "summary hook tracks companion readiness")
  T.check(battleUpvalue ~= nil, "summary hook tracks its battle snapshot")
  local _, previousReady = debug.getupvalue(summaryHook, readyUpvalue)
  local _, previousBattle = debug.getupvalue(summaryHook, battleUpvalue)
  debug.setupvalue(summaryHook, readyUpvalue, true)
  game.stack.states = { world, summary }
  T.eq(run.loader.hooks:call("screen.render_visible",
    function() return true end, summary), true,
    "Gen 1 field summaries keep their native top-screen rendering")
  game.stack.states = { world, { isBattleState = true }, summary }
  T.eq(run.loader.hooks:call("screen.render_visible",
    function() return true end, summary), true,
    "missing battle snapshots leave the native summary visible")
  debug.setupvalue(summaryHook, battleUpvalue, {})
  T.eq(run.loader.hooks:call("screen.render_visible",
    function() return true end, summary), false,
    "Gen 1 battle summaries render only on the companion screen")
  local raw = { isBattleState = true, kind = "wild" }
  local invalidParty = { screenId = "PartyMenu" }
  local throwingParty = { screenId = "PartyMenu", index = 1,
    isCancel = function() error("replacement contract") end }
  local validParty = { screenId = "PartyMenu", index = 1 }
  local invalidBag = { screenId = "BagMenu" }
  local validBag = { screenId = "BagMenu", items = {}, index = 1 }
  run.loader.modOptions.kanto_gear.battle_view = "gear"
  game.stack.states = { world, raw, invalidParty }
  T.eq(run.loader.hooks:call("screen.render_visible",
    function() return true end, invalidParty), true,
    "replacement battle party menus remain visible on the top screen")
  game.stack.states = { world, raw, throwingParty }
  T.eq(run.loader.hooks:call("screen.render_visible",
    function() return true end, throwingParty), true,
    "throwing replacement party contracts fail closed")
  game.stack.states = { world, raw, validParty }
  T.eq(run.loader.hooks:call("screen.render_visible",
    function() return true end, validParty), false,
    "native-contract battle party menus can move to the companion screen")
  game.stack.states = { world, raw, invalidBag }
  T.eq(run.loader.hooks:call("screen.render_visible",
    function() return true end, invalidBag), true,
    "replacement battle bag menus remain visible on the top screen")
  game.stack.states = { world, raw, validBag }
  T.eq(run.loader.hooks:call("screen.render_visible",
    function() return true end, validBag), false,
    "native-contract battle bag menus can move to the companion screen")
  T.eq(run.loader.hooks:call("ui.party.grid_navigation",
    function() return false end, invalidParty), false,
    "replacement battle party menus retain native navigation")
  T.eq(run.loader.hooks:call("ui.party.grid_navigation",
    function() return false end, validParty), true,
    "native-contract battle party menus opt into companion navigation")
  run.loader.modOptions.kanto_gear.battle_view = nil
  debug.setupvalue(summaryHook, battleUpvalue, previousBattle)
  debug.setupvalue(summaryHook, readyUpvalue, previousReady)
  game.stack.states = previousStates
end
do
  local inputHook
  for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
    if entry.owner == "kanto_gear" then inputHook = entry.callback end
  end
  local moveInfoUpvalue
  for i = 1, debug.getinfo(inputHook, "u").nups do
    if debug.getupvalue(inputHook, i) == "moveInfo" then
      moveInfoUpvalue = i
      break
    end
  end
  T.check(moveInfoUpvalue ~= nil,
    "input hook owns the move-info overlay state")
  debug.setupvalue(inputHook, moveInfoUpvalue, { name = "TACKLE" })
  game.input = { pressQueue = { "b", "a", "b" } }
  local previousSwapPressed = swapPressed
  swapPressed = false
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  swapPressed = previousSwapPressed
  T.eq(table.concat(game.input.pressQueue, ","), "a",
    "B closes move info without leaking into the battle menu")
  local _, openMoveInfo = debug.getupvalue(inputHook, moveInfoUpvalue)
  T.eq(openMoveInfo, nil, "B closes the move-info overlay")

  local battleUpvalue
  for i = 1, debug.getinfo(inputHook, "u").nups do
    if debug.getupvalue(inputHook, i) == "battle" then
      battleUpvalue = i
      break
    end
  end
  T.check(battleUpvalue ~= nil, "input hook owns the battle snapshot")
  local _, previousBattle = debug.getupvalue(inputHook, battleUpvalue)
  debug.setupvalue(inputHook, battleUpvalue, {
    prompt = "moves", moveIndex = 1,
    moves = { { id = "TACKLE", name = "TACKLE" } },
  })
  game.input = { pressQueue = {} }
  swapPressed, infoPressed = false, true
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  _, openMoveInfo = debug.getupvalue(inputHook, moveInfoUpvalue)
  T.eq(openMoveInfo.id, "TACKLE", "X opens the selected move details")
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  _, openMoveInfo = debug.getupvalue(inputHook, moveInfoUpvalue)
  T.eq(openMoveInfo.id, "TACKLE", "holding X does not toggle move details")
  infoPressed = false
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  infoPressed = true
  run.loader.hooks:call("input.step", function() end, game, 1 / 60)
  _, openMoveInfo = debug.getupvalue(inputHook, moveInfoUpvalue)
  T.eq(openMoveInfo, nil, "pressing X again closes move details")
  infoPressed = false
  swapPressed = previousSwapPressed
  debug.setupvalue(inputHook, battleUpvalue, previousBattle)

  local function upvalue(fn, target)
    for i = 1, debug.getinfo(fn, "u").nups do
      local name, value = debug.getupvalue(fn, i)
      if name == target then return value end
    end
  end
  local pollTriggerTabs = upvalue(inputHook, "pollTriggerTabs")
  local changePage = upvalue(pollTriggerTabs, "changePage")
  local refreshTools = upvalue(changePage, "refreshTools")
  local api = upvalue(refreshTools, "mod")
  local composeHook
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"] or {}) do
    if entry.owner == "kanto_gear" then composeHook = entry.callback end
  end
  local refreshBattle = upvalue(composeHook, "refreshBattle")
  local compat = upvalue(refreshBattle, "compat")
  local enemyInfo = compat.enemyInfo({
    species = "FIXMON_B", name = "FIXMON B", level = 9,
  }, game.data, { pokedex = {
    seen = { FIXMON_B = true }, owned = { FIXMON_B = true },
  } })
  T.eq(enemyInfo.dex, 2, "enemy info reads the species Pokédex number")
  T.eq(enemyInfo.types[1], "FIRE", "enemy info reads the species base type")
  T.check(enemyInfo.seen and enemyInfo.caught,
    "enemy info reports existing Pokédex flags without inventing counts")
  T.eq(enemyInfo.weak[1].type, "WATER",
    "enemy info derives weaknesses from the active type chart")
  T.eq(enemyInfo.resist[1].type, "GRASS",
    "enemy info derives resistances from the active type chart")
  local originalTypes = game.data.pokemon.FIXMON_B.types
  game.data.pokemon.FIXMON_B.types = { "NORMAL", "NORMAL" }
  local monoInfo = compat.enemyInfo({ species = "FIXMON_B" }, game.data, {})
  T.eq(#monoInfo.types, 1,
    "enemy info collapses duplicated Gen 2 monotype slots")
  game.data.pokemon.FIXMON_B.types = originalTypes
  local virtualBag = {
    screenId = "BagMenu", index = 1,
    items = {
      { value = "POTION", label = "POTION", right = "x2" },
      { value = "ANTIDOTE", label = "ANTIDOTE", right = "x1" },
    },
    __gen3uiBagPocketIndex = 1,
    __gen3uiBagViewIndex = 1,
    __gen3uiBagViewRows = {
      { value = "POTION", label = "POTION", right = "x2" },
      { value = "ANTIDOTE", label = "ANTIDOTE", right = "x1" },
    },
  }
  T.eq(compat.battleBagMenu({ screenId = "BagMenu" }), nil,
    "replacement battle bags without the native list contract are ignored")
  T.eq(compat.battleBagMenu({ screenId = "Gen2PackMenu", rows = {}, index = 1,
    pocket = function() error("replacement contract") end }), nil,
    "throwing replacement Gen 2 pack contracts fail closed")
  T.eq(compat.battleBagMenu(virtualBag).index, 1,
    "virtual categorized bags start on their visible selection")
  virtualBag.__gen3uiBagViewIndex = 2
  T.eq(compat.battleBagMenu(virtualBag).index, 2,
    "virtual bag controller movement refreshes the companion cursor")
  virtualBag.index = 2
  T.eq(compat.battleBagMenu(virtualBag).index, 2,
    "native action synchronization keeps the virtual bag authoritative")
  local nativeBag = {
    screenId = "BagMenu", index = 1,
    items = virtualBag.items,
    __gen3uiBagPocketIndex = 1,
    __gen3uiBagViewIndex = 1,
    __gen3uiBagViewRows = virtualBag.__gen3uiBagViewRows,
  }
  compat.battleBagMenu(nativeBag)
  nativeBag.index = 2
  T.eq(compat.battleBagMenu(nativeBag), nativeBag,
    "disabled virtual bag rendering keeps native controller movement")
  compat.selectBattleBagItem(virtualBag, 1)
  T.eq(virtualBag.index, 1,
    "companion touch resolves a virtual row to the native bag item")
  T.eq(virtualBag.__gen3uiBagViewIndex, 1,
    "companion touch also updates the virtual bag selection")
  local oldWorld = rawget(api, "world")
  local oldBicycle = game.data.items.BICYCLE
  local oldCut = game.data.moves.CUT
  game.data.items.BICYCLE = { name = "FAHRRAD" }
  game.data.moves.CUT = { name = "ZERSCHNEIDER" }
  api.world = { availableFieldActions = function()
    return {
      { id = "bicycle", label = "BICYCLE" },
      { id = "cut", label = "CUT" },
      { id = "bicycle", label = "BIKE OFF" },
    }
  end }
  refreshTools()
  local actions = upvalue(refreshTools, "tools")
  T.eq(actions[1].label, "FAHRRAD",
    "Tools use the translated item name")
  T.eq(actions[2].label, "ZERSCHNEIDER",
    "Tools use the translated move name")
  T.eq(actions[3].label, "BIKE OFF",
    "contextual tool labels keep their specific meaning")
  api.world = { availableFieldActions = function()
    return {}, "world is busy"
  end }
  refreshTools()
  T.eq(upvalue(refreshTools, "tools"), actions,
    "Tools keep their stable list during a walking frame")
  api.world = oldWorld
  game.data.items.BICYCLE = oldBicycle
  game.data.moves.CUT = oldCut
  game.input = nil
end
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

do
  local previousStates = game.stack.states
  local previousOptions = run.loader.modOptions.kanto_gear
  local getTime = T.love.timer.getTime
  local PromptSprites = require("src.pokemon.Sprites")
  local promptSpritePath = PromptSprites.path
  local promptSprites = 0
  game.stack.states = { world, {
    screenId = "MoveLearnMenu", mon = game.save.party[1],
    newMoveId = "FIX_EMBERISH", selecting = false, index = 1,
  }, { isTextBox = true, waiting = true } }
  T.love.timer.getTime = function() return 1 end
  PromptSprites.path = function(...)
    promptSprites = promptSprites + 1
    return promptSpritePath(...)
  end
  run.loader.modOptions.kanto_gear = { battle_view = "gear" }
  run.loader.events:emit("mod.options_changed",
    { mod = "kanto_gear", key = "battle_view" })
  run.loader.hooks:call("render.compose", function() return false end, {}, {
    secondScreen = { detected = function() return displayDetected end,
                     pollTouch = function() return nil end },
  })
  PromptSprites.path = promptSpritePath
  T.love.timer.getTime = getTime
  game.stack.states = previousStates
  run.loader.modOptions.kanto_gear = previousOptions
  run.loader.events:emit("mod.options_changed",
    { mod = "kanto_gear", key = "battle_view" })
  T.check(promptSprites > 0,
    "full-moveset TM prompt is safe outside battle")
end

run.loader.events:emit("world.stepped", { mapId = "FIX_ROUTE" })

-- An animated sprite mod may resolve a menu front pic to a format LÖVE cannot
-- decode directly. Use the shared image-data loader before the icon fallback.
local Sprites = require("src.pokemon.Sprites")
local Assets = require("src.render.Assets")
local spritePath = Sprites.path
local imageData = Assets.imageData
local newImage = T.love.graphics.newImage
local drawImage = T.love.graphics.draw
local fallbackIcons = 0
local fallbackIsWhite = false
local fallbackPhase = false
local fallbackImage
local decodedFrames = 0
local genericSprites, ownedSprites = 0, 0
local PaletteFX = require("src.render.PaletteFX")
local GbcPalette = require("src.render.GbcPalette")
local monPal = PaletteFX.monPal
local paletteWith = GbcPalette.with
local paletteAvailable = GbcPalette.available
local nativeMonColors = {
  { 255, 255, 255 }, { 248, 184, 112 }, { 152, 80, 136 }, { 0, 0, 0 },
}
local nativeMonPaletteUses = 0
local trueColorMonPalCalls = 0
local originalIcons = game.data.icons
game.data.icons = {
  bySpecies = { PIKACHU = "TEST_ICON" },
  icons = { TEST_ICON = "official-icon.png" },
}
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
T.love.graphics.draw = function(image, quad, x, y, rotation, sx, sy, ...)
  if fallbackPhase and image == fallbackImage then
    fallbackIcons = fallbackIcons + 1
    local r, g, b, a = T.love.graphics.getColor()
    fallbackIsWhite = r == 1 and g == 1 and b == 1 and a == 1
  end
  return drawImage(image, quad, x, y, rotation, sx, sy, ...)
end
T.love.graphics.newImage = function(path, ...)
  if path == "unsupported.gif" or path == "unavailable.gif" then
    error("unsupported image format")
  end
  local image = newImage(path, ...)
  if path == "official-icon.png" then fallbackImage = image end
  return image
end
PaletteFX.monPal = function(...)
  trueColorMonPalCalls = trueColorMonPalCalls + 1
  return monPal(...)
end
GbcPalette.available = function() return true end
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
T.eq(trueColorMonPalCalls, 0,
  "full-color mod sprites bypass native palette remapping")
PaletteFX.monPal = function() return nativeMonColors end
GbcPalette.with = function(colors, body)
  if colors == nativeMonColors then
    nativeMonPaletteUses = nativeMonPaletteUses + 1
  end
  return body()
end
Sprites.path = function(_, _, _, opts)
  if opts and opts.mon then ownedSprites = ownedSprites + 1
  else genericSprites = genericSprites + 1 end
  return "decoded-frame.png", false
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
  if nativeMonPaletteUses > 0 then break end
end
T.check(nativeMonPaletteUses > 0,
  "Gen 1 Pokemon sprites use their native species palette")
Sprites.path = function() return "unavailable.gif", true end
fallbackPhase = true
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
Sprites.path, Assets.imageData = spritePath, imageData
PaletteFX.monPal, GbcPalette.with = monPal, paletteWith
GbcPalette.available = paletteAvailable
T.love.graphics.newImage = newImage
T.love.graphics.draw = drawImage
game.data.icons = originalIcons
T.check(fallbackIcons > 0,
  "unsupported Party sprites fall back to official Pokemon icons")
T.check(fallbackIsWhite, "fallback Party icons keep their original colors")

do
  local badgeLoads, badgeAlphas = 0, {}
  local badgePaletteUses = 0
  local palette = PaletteFX.pal
  local draw = T.love.graphics.draw
  local TrainerCard = require("src.ui.TrainerCard")
  local trainerCardNew = TrainerCard.new
  local dataBadges = game.data.constants.badges
  game.data.constants.badges = {
    { id = "BOULDERBADGE", item = "TEST_BADGE" },
    { id = "CASCADEBADGE" },
    { id = "THUNDERBADGE" }, { id = "RAINBOWBADGE" },
    { id = "SOULBADGE" }, { id = "MARSHBADGE" },
    { id = "VOLCANOBADGE" }, { id = "EARTHBADGE" },
  }
  game.save.inventory.TEST_BADGE = true
  local badgeColors = {
    { 255, 255, 255 }, { 248, 184, 112 }, { 152, 80, 136 }, { 0, 0, 0 },
  }
  PaletteFX.pal = function(data, name)
    if name == "MEWMON" then return badgeColors end
    return palette(data, name)
  end
  GbcPalette.available = function() return true end
  GbcPalette.with = function(colors, body)
    if colors == badgeColors then badgePaletteUses = badgePaletteUses + 1 end
    return body()
  end
  TrainerCard.new = function()
    badgeLoads = badgeLoads + 1
    local badges = { img = T.love.graphics.newImage({}), quads = {} }
    for i = 0, 7 do
      badges.quads[i] = T.love.graphics.newQuad(0, i * 32 + 16,
        16, 16, 16, 256)
    end
    return { badges = badges }
  end
  T.love.graphics.draw = function(image, quad, x, y, ...)
    if type(quad) == "table" and quad.w == 16 and quad.h == 16
        and y == 56 then
      assert(image ~= nil, "Trainer badge draw requires Recomp's texture")
      local _, _, _, alpha = T.love.graphics.getColor()
      badgeAlphas[#badgeAlphas + 1] = alpha
    end
    return draw(image, quad, x, y, ...)
  end
  run.loader.events:emit("game.ready", { game = game })
  for _ = 1, 32 do
    trigger.right = 0.8
    run.loader.hooks:call("input.step", function() end, game, 1 / 60)
    trigger.right = 0
    run.loader.hooks:call("input.step", function() end, game, 1 / 60)
    run.loader.hooks:call("render.compose", function() return false end, {}, {
      secondScreen = { detected = function() return displayDetected end,
                       pollTouch = function() return nil end },
    })
    if #badgeAlphas >= 8 then break end
  end
  TrainerCard.new, T.love.graphics.draw = trainerCardNew, draw
  PaletteFX.pal = palette
  GbcPalette.with = paletteWith
  GbcPalette.available = paletteAvailable
  game.data.constants.badges = dataBadges
  game.save.inventory.TEST_BADGE = nil
  T.eq(badgeLoads, 1, "Trainer badges reuse Recomp's Trainer Card sprites")
  T.eq(#badgeAlphas, 8, "Trainer draws all eight real badge silhouettes")
  local solid, faded = 0, 0
  for _, alpha in ipairs(badgeAlphas) do
    if alpha == 1 then solid = solid + 1
    elseif alpha == 0.25 then faded = faded + 1 end
  end
  T.eq(solid, 1, "owned badges draw at full strength")
  T.eq(faded, 7, "unearned badges remain visible as faded silhouettes")
  T.eq(badgePaletteUses, 1,
    "owned Gen 1 badges use the native Trainer Card palette")
end

T.eq(run.loader.hooks:call("render.output_enabled",
  function() return false end), true,
  "the screen-swap action enables swapped output while connected")
local swappedRenderer = { uiAnchors = { { anchor = "topright" } } }
run.loader.hooks:call("render.compose", function() return false end,
  swappedRenderer, {
    secondScreen = { detected = function() return displayDetected end,
                     pollTouch = function() return nil end },
  })
T.eq(swappedRenderer.uiAnchors, nil,
  "screen swap keeps dynamic menus inside the uncropped game viewport")
displayDetected = false
T.eq(run.loader.hooks:call("render.output_enabled",
  function() return false end), false,
  "disconnect bypasses swapped output immediately")
displayDetected = true
run.loader.modOptions.kanto_gear.screen_swap = false
run.loader.events:emit("mod.options_changed",
  { mod = "kanto_gear", key = "screen_swap" })
T.eq(run.loader.hooks:call("render.output_enabled",
  function() return false end), false,
  "disabling screen swap restores the configured display target")

run.release()
T.finish("Kanto Gear compatibility")
