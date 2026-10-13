local T = require("tests.modkit")
love.graphics.arc = love.graphics.arc or function() end
local root = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local Gifts = dofile(root .. "/features/gen2_gifts.lua")
local Progress = dofile(root .. "/features/achievements.lua")
local up = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get
local function gift(event, op, species)
  return { { op = "checkevent", event = event }, { op = "iftrue", script = "END" },
    { op = "readvar", var = 1 }, { op = "ifequal", value = 6, script = "END" },
    { op = op, species = species, level = 20 }, { op = "setevent", event = event }, { op = "end" } }
end
local data = { gen2Scripts = { END = { { op = "end" } }, GIFT = gift(40, "givepoke", 133) },
  gen2Maps = {}, gen2InitialEvents = { flags = {} }, pokemon = {
    EEVEE = { index = 133, name = "EEVEE", type = "NORMAL" }, TOGEPI = { index = 175, name = "TOGEPI" },
    DODRIO = { index = 85, name = "DODRIO" }, DRAGONAIR = { index = 148, name = "DRAGONAIR" } },
  gen2EventTables = { trades = { { give = "DRAGONAIR", get = "DODRIO", gender = "TRADE_GENDER_FEMALE" } } } }
local policy = Gifts.new(data)
T.eq(#policy:catalog("GIFT"), 1, "party-room guard and receipt prove a literal Pokémon gift")
T.eq(policy:catalog("GIFT")[1].speciesIndex, 133, "gift preserves the actual species operand")
T.eq(policy:catalog("GIFT")[1].level, 20, "gift preserves its level")
data.gen2Scripts.UNGUARDED = { { op = "checkevent", event = 41 }, { op = "iftrue", script = "END" },
  { op = "givepoke", species = 133, level = 20 }, { op = "setevent", event = 41 }, { op = "end" } }
T.eq(#policy:catalog("UNGUARDED"), 0, "unconditional receipt after a full-party failure is rejected")
data.gen2Scripts.UNCHECKED = { { op = "readvar", var = 1 }, { op = "ifequal", value = 6, script = "END" },
  { op = "givepoke", species = 133, level = 20 }, { op = "setevent", event = 46 }, { op = "end" } }
T.eq(policy:catalog("UNCHECKED")[1].event, 46, "NPC visibility can gate a gift whose receipt is not checked locally")
data.gen2Scripts.STORY = { { op = "setevent", event = 47 }, { op = "readvar", var = 1 },
  { op = "ifequal", value = 6, script = "END" }, { op = "givepoke", species = 133, level = 20 }, { op = "end" } }
T.eq(#policy:catalog("STORY"), 0, "story flag written before a gift cannot prove acquisition")
data.gen2Scripts.EGG = { { op = "checkevent", event = 42 }, { op = "iftrue", script = "END" },
  { op = "giveegg", args = { 175, 5 } }, { op = "iffalse", script = "END" },
  { op = "setevent", event = 42 }, { op = "end" } }
T.eq(policy:catalog("EGG")[1].isEgg, true, "giveegg's success result can prove receipt")
data.gen2Scripts.BAD_EGG = { { op = "checkevent", event = 43 }, { op = "iftrue", script = "END" },
  { op = "giveegg", args = { 175, 5 } }, { op = "setevent", event = 43 }, { op = "end" } }
T.eq(#policy:catalog("BAD_EGG"), 0, "failed egg delivery cannot become a receipt")
data.gen2Scripts.TRADE = { { op = "trade", trade = 0 }, { op = "end" } }
T.eq(policy:catalog("TRADE")[1].tradeId, 0, "zero-based trade ID is valid")
data.gen2Scripts.BAD_TRADE = { { op = "sjump", script = "END" }, { op = "trade", trade = 0 } }
T.eq(#policy:catalog("BAD_TRADE"), 0, "unreachable trades do not create objectives")
data.gen2Scripts.INVALID = gift(44, "givepoke", 255)
T.eq(#policy:catalog("INVALID"), 0, "memory/sentinel species cannot invent a gift")
data.gen2Scripts.WRONG_LEVEL = gift(45, "givepoke", 133)
data.gen2Scripts.WRONG_LEVEL[5].level = 101
T.eq(#policy:catalog("WRONG_LEVEL"), 0, "invalid gift level is rejected")

data.gen2Constants = { specialOrder = { "GiveShuckle", "GiveOddEgg", "UnrelatedSpecial" } }
data.pokemon.SHUCKLE = { index = 213, name = "SHUCKLE" }
data.gen2Scripts.SHUCKLE = { { op = "checkevent", event = 69 }, { op = "iftrue", script = "END" },
  { op = "special", id = 0 }, { op = "iffalse", script = "END" }, { op = "setevent", event = 69 }, { op = "end" } }
local shuckle = policy:catalog("SHUCKLE")[1]
T.eq(shuckle.speciesIndex, 213, "named Shuckle special resolves its fixed species")
T.eq(shuckle.loan, true, "Shuckle is a loan rather than a permanent ownership requirement")
T.eq(shuckle.event, 69, "Shuckle receipt is independent of its later return")
data.gen2Scripts.ODD_EGG = { { op = "readvar", var = 1 }, { op = "ifequal", value = 6, script = "END" },
  { op = "special", id = 1 }, { op = "setevent", event = 830 }, { op = "end" } }
local odd = policy:catalog("ODD_EGG")[1]
T.eq(odd.isEgg, true, "Odd Egg is catalogued without rolling its contents")
T.eq(odd.speciesIndex, nil, "Odd Egg never invents one fixed species")
T.eq(policy:available(odd, { party = { {}, {}, {}, {}, {}, {} } }, {}), false, "full party blocks the random egg")
data.gen2Scripts.BAD_SPECIAL = { { op = "special", id = 2 }, { op = "setevent", event = 831 }, { op = "end" } }
T.eq(#policy:catalog("BAD_SPECIAL"), 0, "unrelated specials cannot invent Pokemon")
data.gen2Scripts.BAD_SHUCKLE = { { op = "special", id = 0 }, { op = "setevent", event = 832 }, { op = "end" } }
T.eq(#policy:catalog("BAD_SHUCKLE"), 0, "failed Shuckle receipt is rejected without its success branch")
T.eq(#Gifts.new({ gen2Scripts = data.gen2Scripts }):catalog("SHUCKLE"), 0,
  "numeric special IDs alone cannot identify a gift without the active name table")

local run = T.sdk.loadMod(root, { generation = 2, data = T.fixtures.fresh() })
T.eq(run.mod and run.mod.state, "loaded", "Gen2 companion loads Pokémon reward integration")
local input
for _, entry in ipairs(run.loader.hooks.chains["input.step"]) do
  if entry.owner == "kanto_gear" then input = entry.callback end
end
local display = up(input, "displayRuntime")
local Area = up(up(display.achievementData, "areaData"), "Area")
local flags, save = {}, { party = {}, tradeFlags = {}, pokedex = { caught = { EEVEE = true } } }
local world = { getFlag = function(_, event) return flags[event] == true end }
data.gen2Maps.TEST = { objects = { { index = 1, x = 2, y = 3, scriptKey = "GIFT", eventFlag = 65535 },
  { index = 2, x = 4, y = 5, scriptKey = "TRADE", eventFlag = 65535 },
  { index = 3, x = 6, y = 7, scriptKey = "EGG", eventFlag = 65535 } } }
local function rows() return Area.gen2Rows(data, save, world, { "TEST" }) end
T.eq(#rows()[2], 0, "Pokémon rewards do not inflate item totals")
T.eq(#rows()[4], 3, "gift, trade and egg belong to the Pokémon section")
T.eq(rows()[4][1].done, false, "caught elsewhere is not proof of this gift")
T.eq(rows()[4][1].trade, false, "ordinary gift is never labeled as a trade")
T.eq(rows()[4][1].available, true, "gift with free party space is available")
T.eq(rows()[4][3].label, "EGG", "egg contents are concealed in the shared source model")
T.eq(rows()[4][3].isEgg, true, "egg portrait carries its actual kind")
for i = 1, 6 do save.party[i] = {} end
T.eq(rows()[4][1].noRoom, true, "full party blocks a Pokémon gift even with empty PC boxes")
T.eq(rows()[4][1].available, false, "full-party gift is absent from HERE NOW")
T.eq(rows()[4][3].available, false, "full-party egg is also unavailable")
save.party = { { species = "DRAGONAIR", gender = "male" } }
T.eq(rows()[4][2].available, false, "wrong gender does not unlock a trade")
save.party[1].gender = "female"
T.eq(rows()[4][2].available, true, "matching species and gender unlock the trade")
save.party[1].isEgg = true
T.eq(rows()[4][2].available, false, "an egg cannot satisfy the requested trade partner")
save.party = {}
flags[40], save.tradeFlags[0] = true, true
T.eq(rows()[4][1].done, true, "released Pokémon remains received via its event")
T.eq(rows()[4][2].done, true, "released trade remains complete via native tradeFlags")
T.eq(save.party[1], nil, "read-only catalogue never gives or trades Pokémon")
local function album()
  return Progress.build({ { id = "TEST", maps = { "TEST" } } }, function()
    local r = rows()
    return { sections = { { rows = r[1] }, { rows = r[2] }, { rows = r[3] } }, pokemon = r[4] }
  end, { gen2 = true, save = save, mapId = "TEST", flag = function(event) return world:getFlag(event) end }).byId.TEST
end
T.eq(album().sections[4].untracked, 0, "native trade flags are durable without an event flag")
T.eq(album().sections[4].done, 2, "gift event and trade flag count separately")
T.eq(album().tier, "silver", "unreceived egg prevents gold")
flags[42] = true
T.eq(album().tier, "gold", "receiving every NPC offer completes the Pokémon section")
save.tradeFlags[0] = nil
T.eq(album().tier, "silver", "older save restores the uncompleted trade")
flags[40], flags[42] = nil, nil
world.getFlag = function() return nil end
T.eq(rows()[4][1].untracked, true, "unreadable gift event cannot establish collection")
T.eq(rows()[4][1].available, false, "unreadable receipt is not advertised as immediately obtainable")
world.getFlag = function(_, event) return flags[event] == true end
data.gen2EventTables.trades[1] = { give = "EEVEE", get = "TOGEPI" }
T.eq(rows()[4][2].species, "TOGEPI", "edition/mod trade data replaces cached species")
T.eq(rows()[4][2].needsSpecies, "EEVEE", "requested species follows the active trade table")

local game = { data = run.data, save = { generation = 2, version = require("src.core.GameVersion").get(), player = {},
  party = {}, inventory = {}, pokedex = {}, flags = {} } }
game.data.pokemon.DRAGONAIR, game.data.pokemon.DODRIO = data.pokemon.DRAGONAIR, data.pokemon.DODRIO
run.loader.events:emit("game.ready", { game = game })
run.loader.modOptions.kanto_gear = { info_level = "spoiler", theme_v3 = "hgss" }
local api = up(display.saveHome, "mod")
api.world = { current = function() return { mapId = "TEST", x = 1, y = 1 } end,
  mapActors = function() return { { id = "TEST_obj_2", x = 7, y = 8, visible = true } } end }
display.knownMap = function() return true end
display.explorerMethods = function() return {} end
display.explorerWildRows = function() return {} end
local explorer, assist = display.explorer, up(display.explorerModel, "assist")
local trade = { id = "TEST_trade", actorId = "TEST_obj_2", mapId = "TEST", index = 2, x = 4, y = 5,
  label = "DODRIO", species = "DODRIO", kind = "pokemon", gift = true, trade = true,
  needsSpecies = "DRAGONAIR", needsGender = "TRADE_GENDER_FEMALE", available = true }
explorer.data = { mapId = "TEST", at = love.timer.getTime(), guideEnabled = assist("guide"),
  areaEnabled = assist("area"), fruits = {}, guide = { rows = {}, caught = 0 },
  area = { pokemon = { trade }, sections = { { rows = {} }, { rows = {} }, { rows = {} } } } }
local overview = { mapId = "TEST", width = 12, height = 12, rows = {}, markers = {} }
for i = 1, 12 do overview.rows[i] = string.rep(".", 12) end
local function model() explorer.renderModel = nil; return display.explorerModel(overview) end
T.eq(model().rows[1].needsSpeciesName, "DRAGONAIR", "trade detail resolves the requested species")
T.eq(model().rows[1].needsGender, "TRADE_GENDER_FEMALE", "trade detail retains its separate gender icon")
T.eq(model().markers[1].kind, "pokemon", "Gen2 NPC marker opens Pokémon details")
T.eq(model().markers[1].x, 7, "trade marker follows the current NPC position")
trade.available = false
T.eq(#model().rows, 0, "HERE NOW hides unavailable Gen2 trades")
explorer.filters.wildScope = "ROUTE"
T.eq(#model().rows, 1, "WHOLE ROUTE retains future trade information in Spoiler mode")

game.data.gen2Maps, game.data.gen2Scripts = data.gen2Maps, data.gen2Scripts
game.data.gen2EventTables, game.data.gen2InitialEvents = data.gen2EventTables, data.gen2InitialEvents
game.data.pokemon.EEVEE, game.data.pokemon.TOGEPI = data.pokemon.EEVEE, data.pokemon.TOGEPI
api.world.getFlag = world.getFlag
local area = up(display.achievementData, "areaData")({ "TEST" }, true)
T.eq(#(area.pokemon or {}), 3, "shared area data forwards all Gen2 rewards to Explorer and Stamps")
data.gen2Maps.TEST.objects[4] = { index = 4, x = 8, y = 9, scriptKey = "ODD_EGG", eventFlag = 65535 }
data.gen2Maps.TEST.objects[5] = { index = 5, x = 9, y = 9, scriptKey = "SHUCKLE", eventFlag = 65535 }
game.data.gen2Constants, game.data.pokemon.SHUCKLE = data.gen2Constants, data.pokemon.SHUCKLE
area = up(display.achievementData, "areaData")({ "TEST" }, true)
T.eq(#area.pokemon, 5, "species-free egg is included in the shared Pokemon section")
T.eq(area.pokemon[4].species, nil, "shared egg model still conceals the random species")
T.eq(area.pokemon[4].kind, "pokemon", "random egg uses the Pokemon marker and details")
explorer.data.area = area
local eggModel
for _, row in ipairs(model().rows) do if row.isEgg and row.species == nil then eggModel = row end end
T.eq(eggModel and eggModel.name, "EGG", "Explorer presents the random egg without a species")
T.eq(eggModel and eggModel.method, "NPC GIFT", "random egg opens Pokemon gift details rather than item details")
flags[69], flags[70], flags[830] = true, true, true
T.eq(rows()[4][5].done, true, "returning Shuckle does not undo its acquisition")
T.eq(rows()[4][4].done, true, "Odd Egg acquisition is independent of hatching or release")
flags[69], flags[70], flags[830] = nil, nil, nil

local native = os.getenv("KANTO_GEAR_NATIVE_GEN2")
if native then
  local imported = { gen2Scripts = dofile(native .. "/scripts.lua"), gen2Maps = dofile(native .. "/maps.lua"),
    gen2InitialEvents = dofile(native .. "/initial_events.lua"), pokemon = dofile(native .. "/pokemon.lua"),
    items = dofile(native .. "/items.lua"), gen2EventTables = dofile(native .. "/events.lua"),
    gen2Constants = dofile(native .. "/constants.lua") }
  local function trainers(id) return Area.gen2Rows(imported, {}, world, { id })[1] end
  local tower = trainers("RADIO_TOWER_2F")[1]
  T.eq(tower.missable, true, "native Rocket population is a bonus before disappearing")
  flags[1742] = true
  T.eq(Progress.rowState(tower, 1, { gen2 = true, save = {}, flag = function(id) return flags[id] == true end }),
    "later", "initially hidden Radio Tower population is not prematurely called missed")
  flags[1393] = true
  T.eq(Progress.rowState(tower, 1, { gen2 = true, save = {}, flag = function(id) return flags[id] == true end }),
    "unavailable", "cleared takeover plus hidden population proves a missed encounter")
  flags[1742], flags[1393] = nil, nil
  local ship = trainers("FAST_SHIP_CABINS_SE_SSE_CAPTAINS_CABIN")
  local first, weekly = 0, 0
  for _, row in ipairs(ship) do
    if row.hideEvent == 1849 then T.eq(row.missable, true, "first-voyage trainer is a bonus"); first = first + 1 end
    if row.hideEvent == 1850 or row.hideEvent == 1851 then
      T.eq(row.repeatable, true, "weekly trainer's actual flag reset cannot create a permanent goal")
      weekly = weekly + 1
    end
  end
  T.check(first > 0 and weekly > 0, "native ship exercises both one-time and resettable populations")
  for _, row in ipairs(trainers("CERULEAN_GYM")) do
    T.eq(row.missable, nil, "initially closed Gym is required rather than a missable population")
  end
  local count, trades, entries = 0, 0, {}
  for id in pairs(imported.gen2Maps) do
    for _, row in ipairs(Area.gen2Rows(imported, {}, world, { id })[4]) do
      if row.trade then trades = trades + 1 else count = count + 1 end
      entries[id .. ":" .. (row.species or "EGG")] = row
    end
  end
  T.eq(entries["BILLS_FAMILYS_HOUSE:EEVEE"].event, 79, "native Bill gift uses its receipt event")
  T.eq(entries["MOUNT_MORTAR_B1F:TYROGUE"].event, 97, "native Kiyo reward is tracked after battle")
  T.eq(entries["MOUNT_MORTAR_B1F:TYROGUE"].available, false, "Kiyo's undefeated battle is not an immediate gift")
  flags[1193] = true
  local kiyo = Area.gen2Rows(imported, {}, world, { "MOUNT_MORTAR_B1F" })[4][1]
  T.eq(kiyo.available, true, "Kiyo's defeated battle unlocks the pending gift")
  T.eq(entries["MANIAS_HOUSE:SHUCKLE"].event, 69, "native Shuckle uses its original receipt flag")
  T.eq(entries["MANIAS_HOUSE:SHUCKLE"].loan, true, "native Shuckle is identified as a loan")
  if require("src.core.GameVersion").get() == "crystal" then
  T.eq(entries["VIOLET_POKECENTER_1F:TOGEPI"].event, 45, "egg uses its received flag rather than the separate refusal flag")
  T.eq(entries["VIOLET_POKECENTER_1F:TOGEPI"].label, "EGG", "native Togepi egg does not leak its contents")
  T.eq(entries["DRAGON_SHRINE:DRATINI"].event, 189, "native shrine reward uses a durable receipt")
  T.eq(entries["ROUTE_35_GOLDENROD_GATE:SPEAROW"].loan, true, "Kenya is identified as a loan")
  T.eq(entries["BLACKTHORN_EMYS_HOUSE:DODRIO"].needsGender, "TRADE_GENDER_FEMALE", "native gender restriction is preserved")
  T.eq(entries["DAY_CARE:EGG"].event, 830, "random Odd Egg uses its actual receipt flag")
  T.eq(entries["DAY_CARE:EGG"].species, nil, "native Odd Egg does not invent a fixed species")
  T.eq(count, 13, "Crystal includes seven gifts/loans and six prize species")
  T.eq(trades, 7, "Crystal uses all seven actual trade rows rather than an old six-trade constant")
  else
    T.eq(entries["DAY_CARE:EGG"], nil, "Gold and Silver do not invent Crystal's Odd Egg")
    T.eq(count, 11, "Gold and Silver include five gifts/loans and six prize species")
    T.eq(trades, 6, "Gold and Silver use their actual six NPC trades")
  end
  local edition = require("src.core.GameVersion").get()
  local oracle = edition == "crystal" and { ABRA = {100,5}, CUBONE = {800,15}, WOBBUFFET = {1500,15} }
    or { ABRA = {200,10}, [edition == "silver" and "SANDSHREW" or "EKANS"] = {700,10}, DRATINI = {2100,10} }
  local Vm, Events = require("src.script.gen2.Vm"), require("src.world.gen2.Events")
  for _, mapId in ipairs({ "GOLDENROD_GAME_CORNER", "CELADON_GAME_CORNER_PRIZE_ROOM" }) do
    local nativeSave = { party = {}, inventory = { COIN_CASE = 1 }, player = { coins = 9999 }, pokedex = { caught = {} } }
    local function prizeRows() return Area.gen2Rows(imported, nativeSave, world, { mapId })[4] end
    T.eq(#prizeRows(), 3, "each native Gen2 counter has three actual prize species")
    for _, offer in ipairs(prizeRows()) do
      T.eq(offer.catchGoal, true, "repeatable casino reward uses a caught goal")
      T.eq(offer.event, nil, "repeatable casino reward never invents a receipt")
      T.eq(offer.available, true, "native prize is immediately affordable with space")
      if mapId == "GOLDENROD_GAME_CORNER" then
        local expected = assert(oracle[offer.species], "wrong edition's prize species")
        T.eq(offer.coinCost, expected[1], "Goldenrod prize price follows edition")
        T.eq(offer.level, expected[2], "Goldenrod prize level follows edition")
      else T.eq(offer.index, nil, "background counter cannot follow an unrelated NPC actor") end
      nativeSave.player.coins = offer.coinCost - 1
      for _, r in ipairs(prizeRows()) do if r.id == offer.id then T.eq(r.available, false, "one coin short hides the prize") end end
      nativeSave.player.coins = offer.coinCost
      for _, r in ipairs(prizeRows()) do if r.id == offer.id then T.eq(r.available, true, "exact coin price allows the prize") end end
      nativeSave.inventory = {}
      for _, r in ipairs(prizeRows()) do T.eq(r.available, false, "missing Coin Case hides every immediate prize") end
      nativeSave.inventory = { COIN_CASE = 1 }
      nativeSave.party = { {}, {}, {}, {}, {}, {} }
      for _, r in ipairs(prizeRows()) do T.eq(r.available, false, "full party blocks Gen2 prize even with PC space") end
      nativeSave.party = {}
      nativeSave.pokedex.caught[offer.species] = true
      for _, r in ipairs(prizeRows()) do if r.id == offer.id then
        T.eq(r.done, true, "prize goal survives release via native caught dex")
        T.eq(r.status, "CAUGHT", "prize completion describes catching rather than unique receipt")
      end end
      nativeSave.pokedex.caught[offer.species] = nil
      local source
      local candidates = mapId == "GOLDENROD_GAME_CORNER" and imported.gen2Maps[mapId].objects or imported.gen2Maps[mapId].bgEvents
      for _, obj in ipairs(candidates) do if obj.x == offer.x and obj.y == offer.y then source = obj.scriptKey end end
      T.check(source ~= nil, "prize is attached to actual NPC or background script")
      -- Drive the original bytecode and vary its menu choice; only presentation
      -- and the World delivery hook are substituted in this headless test.
      local matched = false
      for choice = 1, 3 do
        local coins, delivered, menus, questions = 9999, nil, 0, 0
        local vm = Vm.new(imported.gen2Scripts, {}, Events.new(), {
          showText = function(_, done) if done then done() end end,
          openMenu = function(_, _, done) menus = menus + 1; done(menus == 1 and choice or 0) end,
          yesorno = function(done) questions = questions + 1; done(questions == 1) end,
          hasItem = function(id) return id == 54 end,
          readVar = function(id) return id == 1 and 0 or 0 end,
          gsVersion = function() return edition == "silver" and 1 or 0 end,
          getCoins = function() return coins end, setCoins = function(n) coins = n end,
          givePoke = function(sp, lv) delivered = { species = sp, level = lv }; return delivered end,
          getMonName = function(id) for name, def in pairs(imported.pokemon) do if type(def) == "table" and def.index == id then return name end end end,
          specialOrder = imported.gen2Constants.specialOrder,
        })
        vm:start(source)
        for _ = 1, 100 do if not vm:running() then break end; vm:update() end
        T.eq(vm:running(), false, "native prize transaction finishes")
        if delivered and delivered.species == imported.pokemon[offer.species].index then
          matched = true
          T.eq(delivered.level, offer.level, "native VM gives projected prize level")
          T.eq(9999 - coins, offer.coinCost, "native VM charges projected coin price")
        end
      end
      T.eq(matched, true, "each catalogue offer is reachable through native vendor menu")
      nativeSave.player.coins = 9999
    end
  end
  print("GEN2_NATIVE_REWARDS", count, trades)
end
T.finish("Kanto Gear Gen2 Pokémon gifts and trades")
