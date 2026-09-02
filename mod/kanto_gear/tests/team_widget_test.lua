-- Run in the host modkit checkout, once with argument 1 and once with 2.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local generation = assert(tonumber(arg[1]), "choose generation 1 or 2")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local data = T.fixtures.load()
-- The headless image stub supplies pixels; the normal asset resolver stays live.
data.pokemon.FIXMON_A.spriteFront = "team-widget-fixture.png"
local run = T.sdk.loadMod(path, { generation = generation, data = data })
T.eq(run.mod.state, "loaded", "mod loads")
local function upvalue(fn, target)
  for index = 1, debug.getinfo(fn, "u").nups do
    local name, value = debug.getupvalue(fn, index)
    if name == target then return value end
  end
end
local function hook(name)
  for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
    if entry.owner == "kanto_gear" then return entry.callback end
  end
end
local display = upvalue(hook("input.step"), "displayRuntime")
local api = upvalue(display.saveHome, "mod")
local theme = upvalue(display.drawContents, "THEME")
local renderer = theme.hgss
local touchEvent = upvalue(hook("render.compose"), "touchEvent")
local tap = upvalue(touchEvent, "tap")
local world = { map = { id = "PALLET_TOWN" } }
local party = {}
for index = 1, 6 do
  party[index] = { species = "FIXMON_A", nickname = "PARTNER" .. index,
    level = index * 10, hp = index == 5 and 0 or 30, stats = { hp = 50 },
    status = index == 6 and "SLP" or index == 1 and "PAR" or nil,
    exp = 1000, moves = {}, isEgg = generation == 2 and index == 4 }
end
local game = { data = run.data, world = world,
  save = { generation = generation, player = { name = "RED", id = 7 },
    party = party, inventory = {}, boxes = {}, currentBox = 1,
    pokedex = { seen = {}, caught = {} } },
  stack = { states = { world }, top = function(self) return self.states[#self.states] end,
    pop = function(self) self.popped = true end },
}
run.loader.modOptions.kanto_gear = { theme_v3 = "hgss" }
run.loader.events:emit("game.ready", { game = game })
local home, catalog = display.home, display.homeCatalog
home.help, home.helpSeen = false, true
T.eq(display.Home.find(home.layout, "party_team_widget"), nil,
  "new widget does not alter existing or default Home")
local library = display.Home.library(home.layout, catalog, 2, 1, 1, "widget")
local teamEntry
for _, entry in ipairs(library) do
  if entry.id == "party_team_widget" then teamEntry = entry end
end
T.check(teamEntry and teamEntry.available and teamEntry.columns == 12,
  "installed Party app offers a full-width Team View widget")
T.check(not display.Home.canPlace(home.layout, catalog, "party_team_widget", 1, 1, 1),
  "Team View cannot overlap existing widgets")
T.check(display.Home.place(home.layout, catalog, "party_team_widget", 2, 1, 1),
  "Team View fits a free row")
T.check(display.Home.find(home.layout, "party_widget") ~= nil,
  "old Party widget can coexist with Team View")
display.saveHome()
home.layout = { tiles = {} }
display.loadHome()
T.eq(display.Home.find(home.layout, "party_team_widget").page, 2,
  "Team View survives Home persistence on its chosen page")
home.page = 2
local tile = display.homePageElements()[1]
local tx, ty, tw = renderer:homeRect(tile)
local firstX = renderer:homeTeamSlotRect(tile, 1)
local lastX, _, lastW = renderer:homeTeamSlotRect(tile, 6)
T.eq(firstX - tx, tx + tw - lastX - lastW, "portrait strip has equal outside gaps")
local captured
local renderHome = renderer.home
renderer.home = function(_, model) captured = model end
display.drawHome()
renderer.home = renderHome
T.eq(#captured.team, 6, "runtime supplies all six live party members")
T.eq(captured.team[5].hp, 0, "fainted HP stays zero")
T.eq(captured.team[5].statusId, "FNT", "fainted status is explicit")
T.eq(captured.team[6].statusId, "SLP", "sleep reaches the widget")
T.eq(captured.team[4].egg, generation == 2, "Gen 2 egg is not an ordinary party member")
T.eq(captured.overview, nil, "Team View alone does not query the Explorer map")
for index, mon in ipairs(captured.team) do
  T.eq(mon.slot, index, "member view retains its exact party index")
  T.eq(mon.maxHp, 50, "member view retains maximum HP")
end

-- Exercise the real Home -> drawSprite -> graphics path, including KO tint.
-- The host's permissive setColor stub otherwise accepts invalid booleans.
love.graphics.arc = love.graphics.arc or function() end
local graphics = love.graphics
local setColor, draw, push, pop = graphics.setColor, graphics.draw,
  graphics.push, graphics.pop
local spritePath = require("src.pokemon.Sprites").path(run.data, "FIXMON_A", "front")
T.check(spritePath ~= nil, "render fixture resolves a Pokemon image path")
local dimmed, normal, depth = 0, 0, 0
graphics.setColor = function(r, g, b, a)
  if type(r) == "table" then r, g, b, a = unpack(r) end
  assert(type(r) == "number" and type(g) == "number" and type(b) == "number"
    and (a == nil or type(a) == "number"), "setColor requires numeric channels")
  return setColor(r, g, b, a)
end
graphics.draw = function(image, ...)
  if image.path == spritePath then
    local r, g, b = graphics.getColor()
    if r == 0.48 and g == 0.48 and b == 0.48 then dimmed = dimmed + 1 end
    if r == 1 and g == 1 and b == 1 then normal = normal + 1 end
  end
  return draw(image, ...)
end
graphics.push = function(...) depth = depth + 1; return push(...) end
graphics.pop = function(...) depth = depth - 1; return pop(...) end
local rendered, renderError = pcall(function()
  for frame = 1, 120 do
    display.drawContents()
    assert(depth == 0, "Home frame leaked graphics pushes")
  end
end)
graphics.setColor, graphics.draw, graphics.push, graphics.pop = setColor, draw, push, pop
while depth > 0 do pop(); depth = depth - 1 end
T.check(rendered, "120 real Home frames render without errors: " .. tostring(renderError))
T.eq(dimmed, 120, "KO portrait uses numeric dimming in every frame")
T.eq(normal, 120 * (generation == 2 and 4 or 5),
  "healthy portraits stay bright and Gen 2 eggs bypass Pokemon art")

local opened, opens = nil, 0
api.ui.push = function(receivedGame, screen, payload)
  T.eq(receivedGame, game, "summary uses the current game")
  opened, opens = { screen = screen, payload = payload }, opens + 1
end
local function currentPage() return upvalue(display.openHomeApp, "page") end
local function goHome()
  display.openHomeApp("party")
  tap(5, 5)
  T.eq(currentPage(), "HOME", "return to Home")
end
for index = 1, 6 do
  goHome()
  local x, y, w, h = renderer:homeTeamSlotRect(tile, index)
  tap((x + w / 2) / 1.5, (y + h / 2) / 1.5)
  T.eq(currentPage(), "PARTY", "member tap enters the Party app")
  T.eq(opened.screen, generation == 2 and "Gen2SummaryMenu" or "SummaryMenu",
    "member tap uses the correct native summary")
  T.eq(generation == 2 and opened.payload.mon or opened.payload, party[index],
    "member tap opens exactly the touched Pokemon")
  if generation == 2 then
    T.eq(opened.payload.index, index, "Gen 2 summary retains native party navigation")
    T.eq(opened.payload.party, party, "Gen 2 summary shares the real party")
    opened.payload.onClose()
    T.eq(game.stack.popped, true, "Gen 2 summary retains native close behavior")
  end
end
goHome()
local previousOpens = opens
tap((tx + tw / 2) / 1.5, (ty + 10) / 1.5)
T.eq(currentPage(), "PARTY", "widget header opens the Party overview")
T.eq(opens, previousOpens, "header does not open an arbitrary Pokemon")
goHome()
for index = 6, 3, -1 do party[index] = nil end
local emptyX, emptyY = renderer:homeTeamSlotRect(tile, 3)
tap((emptyX + 17) / 1.5, (emptyY + 20) / 1.5)
T.eq(currentPage(), "HOME", "empty member slots do nothing")
T.eq(opens, previousOpens, "empty slots cannot open stale party data")
tap((firstX + 35) / 1.5, (emptyY + 20) / 1.5)
T.eq(currentPage(), "HOME", "gap between members does not open either Pokemon")
home.editing = true
tap((firstX + 17) / 1.5, (emptyY + 20) / 1.5)
T.eq(home.swapSource, tile.id, "editing selects the whole widget for swapping")
T.eq(opens, previousOpens, "editing never opens a member summary")
T.check(display.Home.drop(home.layout, catalog, tile.id, 3, 6, 2),
  "full Team View can move to an empty row on another page")
T.eq(display.Home.find(home.layout, tile.id).page, 3, "move persists the target page")

-- A touch depresses only the occupied member, not the entire widget.
love.graphics.arc = love.graphics.arc or function() end
local pressedCount, pressedX = 0, nil
local beginPress = renderer.beginPress
renderer.beginPress = function(self, x, y, w, h, ...)
  local pressed = beginPress(self, x, y, w, h, ...)
  if pressed then pressedCount, pressedX = pressedCount + 1, x end
  return pressed
end
captured.drawPokemon = function() end
local secondX, secondY = renderer:homeTeamSlotRect(tile, 2)
renderer:setTouch((secondX + 17) / 1.5, (secondY + 20) / 1.5)
renderer:home(captured)
T.eq(pressedCount, 1, "exactly one member reacts to touch")
T.eq(pressedX, secondX, "pressed feedback belongs to the touched member")
renderer:setTouch()
renderer.beginPress = beginPress

-- Team summaries outside battle use the same touch detail screen, respecting
-- research mode, without taking over the native D-pad or changing party data.
local summaryMon = party[1]
summaryMon.moves = {
  { id = "FIX_TACKLE", pp = 7, ppUps = 2,
    maxPp = generation == 2 and 42 or nil },
  { id = "FIX_EMBERISH", pp = 3 },
}
summaryMon.types = { run.data.moves.FIX_TACKLE.type }
local summary = { screenId = generation == 2 and "Gen2SummaryMenu" or "SummaryMenu",
  page = 2, moveIndex = 1, mon = summaryMon,
  itemName = function() return "---" end, expToNext = function() return 20 end,
  otName = function() return "RED" end, otId = function() return 7 end }
game.stack.states = { world, summary }
game.input = { pressQueue = {}, sourcePress = function() end, sourceRelease = function() end }
local summaryModel, detailModel, detailStab
local summaryMoves, detailBody = renderer.summaryMoves, renderer.battleMoveInfoBody
renderer.summaryMoves = function(self, model, ...)
  summaryModel = model
  return summaryMoves(self, model, ...)
end
renderer.battleMoveInfoBody = function(self, model, stab)
  detailModel, detailStab = model, stab
  return detailBody(self, model, stab)
end
local function tapMove(slot)
  local position = "80," .. math.floor((63 + (slot - 1) * 37 + 17) / theme.hgssScale)
  touchEvent("down," .. position)
  touchEvent("up," .. position)
end
for _, mode in ipairs({ "purist", "enhanced", "spoiler" }) do
  run.loader.modOptions.kanto_gear.info_level = mode
  display.drawContents()
  T.eq(summaryModel.moveDetails, mode ~= "purist", mode .. " controls detail affordances")
  T.eq(summaryModel.moveIndex, nil, "field summary has no controller focus")
  for slot = 1, 2 do
    tapMove(slot)
    local selected = upvalue(tap, "moveInfo")
    if mode == "purist" then
      T.eq(selected, nil, "Vanilla does not open assisted move details")
    else
      T.eq(selected and selected.id, summaryMon.moves[slot].id,
        mode .. " touch opens the exact team move outside battle")
      display.drawContents()
      T.eq(detailModel and detailModel.name, run.data.moves[summaryMon.moves[slot].id].name,
        "existing detail screen renders the selected move")
      T.eq(detailStab, slot == 1, "STAB uses the viewed team member, not a battle owner")
      T.eq(detailModel and detailModel.effectiveness, nil,
        "no opponent means no invented matchup multiplier")
      if slot == 1 then
        local basePp = run.data.moves.FIX_TACKLE.pp
        local maxPp = generation == 2 and 42 or basePp + 2 * math.floor(basePp / 5)
        T.eq(detailModel and detailModel.ppText, "7/" .. maxPp, "details retain PP bonuses")
      end
      tap(3, 3)
      T.eq(upvalue(tap, "moveInfo"), nil, "touch back closes only the move overlay")
      T.eq(game.stack:top(), summary, "return keeps the same summary")
      T.eq(summary.page, 2, "return keeps the Moves page")
    end
  end
  tapMove(3)
  T.eq(upvalue(tap, "moveInfo"), nil, "empty move slot is inert")
end
local inputHook = hook("input.step")
local hgss = upvalue(inputHook, "hgssRuntime")
game.input.pressQueue = { "down" }
local selectedSlot = summary.moveIndex
hgss.remapSummaryMovesInput(game)
T.eq(game.input.pressQueue[1], "down", "field summary leaves D-pad input native")
T.eq(summary.moveIndex, selectedSlot, "field summary adds no D-pad move selection")
tapMove(1)
game.input.pressQueue = { "b" }
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
T.eq(upvalue(tap, "moveInfo"), nil, "B also closes the field move overlay")
T.eq(#game.input.pressQueue, 0, "closing details does not send B into the summary")
T.eq(summaryMon.moves[1].pp, 7, "browsing does not spend PP")
renderer.summaryMoves, renderer.battleMoveInfoBody = summaryMoves, detailBody
T.eq(#run.errors, 0, "no runtime errors")
run.release()
T.finish("Team View widget Gen " .. generation)
