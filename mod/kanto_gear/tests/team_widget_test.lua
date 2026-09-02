-- Run in the host modkit checkout, once with argument 1 and once with 2.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local generation = assert(tonumber(arg[1]), "choose generation 1 or 2")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local run = T.sdk.loadMod(path, { generation = generation, data = T.fixtures.load() })
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
  party[index] = { species = "BULBASAUR", nickname = "PARTNER" .. index,
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
T.eq(#run.errors, 0, "no runtime errors")
run.release()
T.finish("Team View widget Gen " .. generation)
