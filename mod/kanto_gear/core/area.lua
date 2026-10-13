return function()
local Area = {}

function Area.pickupBounds(row, map)
  -- Imported dimensions are 32px blocks, positions are 16px cells.
  -- Preserve custom maps: only the actual current dimensions decide this.
  if map and type(map.width) == "number" and type(map.height) == "number"
      and type(row.x) == "number" and type(row.y) == "number"
      and (row.x < 0 or row.y < 0 or row.x >= map.width * 2 or row.y >= map.height * 2) then
    row.outsideMap, row.untracked, row.done, row.available = true, true, false, false
    row.status = "NOT TRACKED"
  end
  return row
end

-- Game path [Gen 1]: scripted story battles lack ordinary trainer headers; match imported map/object names to their durable result flags.
local GEN1_SCRIPT_TRAINERS = {
  ROUTE_22 = {
    ROUTE22_RIVAL1 = { class = "OPP_RIVAL1",
      optional = true,
      event = "EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE",
      requires = { "EVENT_GOT_POKEDEX" }, missedAfter = "EVENT_BEAT_BROCK" },
    ROUTE22_RIVAL2 = { class = "OPP_RIVAL2",
      event = "EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE",
      requires = { "EVENT_BEAT_GIOVANNI" } },
  },
  CERULEAN_CITY = {
    CERULEANCITY_RIVAL = { class = "OPP_RIVAL1",
      event = "EVENT_BEAT_CERULEAN_RIVAL" },
    CERULEANCITY_ROCKET = { class = "OPP_ROCKET",
      event = "EVENT_BEAT_CERULEAN_ROCKET_THIEF" },
  },
  SS_ANNE_2F = {
    SSANNE2F_RIVAL = { class = "OPP_RIVAL2",
      event = "EVENT_BEAT_SS_ANNE_RIVAL" },
  },
  POKEMON_TOWER_2F = {
    POKEMONTOWER2F_RIVAL = { class = "OPP_RIVAL2",
      event = "EVENT_BEAT_POKEMON_TOWER_RIVAL" },
  },
  SILPH_CO_7F = {
    SILPHCO7F_RIVAL = { class = "OPP_RIVAL2",
      event = "EVENT_BEAT_SILPH_CO_RIVAL" },
  },
  CHAMPIONS_ROOM = {
    CHAMPIONSROOM_RIVAL = { class = "OPP_RIVAL3",
      event = "EVENT_BEAT_CHAMPION_RIVAL" },
  },
  -- Game path [Yellow]: Jessie/James story battles are paired encounters; these rows apply only when the corresponding imported objects exist.
  MT_MOON_B2F = {
    MTMOONB2F_JESSIE = { class = "OPP_ROCKET", label = "JESSIE & JAMES",
      event = "EVENT_BEAT_MT_MOON_3_JESSIE_JAMES",
      requiresAny = { "EVENT_GOT_DOME_FOSSIL", "EVENT_GOT_HELIX_FOSSIL" } },
  },
  ROCKET_HIDEOUT_B4F = {
    ROCKETHIDEOUTB4F_JESSIE = { class = "OPP_ROCKET",
      label = "JESSIE & JAMES",
      event = "EVENT_BEAT_ROCKET_HIDEOUT_4_JESSIE_JAMES" },
  },
  POKEMON_TOWER_7F = {
    POKEMONTOWER7F_JESSIE = { class = "OPP_ROCKET",
      label = "JESSIE & JAMES",
      event = "EVENT_BEAT_POKEMONTOWER_7_JESSIE_JAMES" },
  },
  SILPH_CO_11F = {
    SILPHCO11F_JESSIE = { class = "OPP_ROCKET", label = "JESSIE & JAMES",
      event = "EVENT_BEAT_SILPH_CO_11F_JESSIE_JAMES" },
  },
  -- Game path [Gen 1 imported/custom content]: only an existing chief object activates this post-Champion objective.
  CELADON_CHIEF_HOUSE = {
    CELADONCHIEFHOUSE_CHIEF = { class = "OPP_CHIEF",
      event = "EVENT_BEAT_CELADON_CHIEF",
      requires = { "EVENT_BEAT_CHAMPION_RIVAL" } },
  },
}

function Area.gen1ScriptTrainer(mapId, obj)
  local map = GEN1_SCRIPT_TRAINERS[mapId]
  return map and obj and map[obj.name] or nil
end

function Area.gen1TrainerState(save, trainer)
  local flags = save and save.flags or {}
  local beaten = trainer and trainer.event and flags[trainer.event] == true
  local missed = not beaten and trainer and trainer.missedAfter
    and flags[trainer.missedAfter] == true or false
  local available = not beaten and not missed
  for _, event in ipairs(trainer and trainer.requires or {}) do
    available = available and flags[event] == true
  end
  if trainer and trainer.requiresAny then
    local any = false
    for _, event in ipairs(trainer.requiresAny) do
      any = any or flags[event] == true
    end
    available = available and any
  end
  return {
    beaten = beaten, missed = missed, done = beaten or missed,
    available = available,
    status = missed and "MISSED" or not available and not beaten and "LATER"
      or nil,
  }
end

-- Game path [Gen 1]: SS Anne departure and Silph liberation remove remaining story opponents without proving victory.
function Area.gen1TrainerMissed(save, mapId, done)
  if done then return false end
  local event = tostring(mapId):match("^SS_ANNE_") and "EVENT_SS_ANNE_LEFT"
    or tostring(mapId):match("^SILPH_CO_")
      and "EVENT_BEAT_SILPH_CO_GIOVANNI"
  return event ~= nil and save and save.flags
    and save.flags[event] == true or false
end

function Area.gen1Gifts(data, save, mapId, map, checkpoint)
  if not Area.Gifts1 then return {} end
  if Area.gift1Data ~= data then
    Area.gift1Policy, Area.gift1Data = Area.Gifts1.new(), data
  end
  return Area.gift1Policy:rows(data, save, mapId, map, checkpoint)
end

-- Game path [Gen 1/2]: the native Itemfinder rectangle is asymmetric (five cells across, four below); Gen 3 uses its native scanner.
function Area.itemfinderNear(px, py, x, y)
  local function near(origin, value, high)
    return value > math.max(origin - 5, 0) and value <= origin + high
  end
  return near(px, x, 5) and near(py, y, 4)
end

function Area.itemfinderScanReached(px, py, x, y, progress)
  if not Area.itemfinderNear(px, py, x, y) then return false end
  local dx, dy = x - px, y - py
  return math.sqrt(dx * dx + dy * dy) <= math.sqrt(41) * progress
end

local function gen2Definition(definitions, index)
  local direct = definitions and definitions[index]
  if type(direct) == "table" then return direct, direct.id or index end
  for id, def in pairs(definitions or {}) do
    if type(def) == "table" and def.index == index then return def, id end
  end
end

local function gen2FlagSet(world, event)
  return event ~= nil and world and world.getFlag
    and world:getFlag(event) == true or false
end

local function gen2PickupUnknown(world, event)
  return type(event) == "number" and event >= 8 and event ~= 65535
    and (not world or not world.getFlag or world:getFlag(event) == nil) or false
end

local function gen2ItemName(data, index)
  local def, id = gen2Definition(data and data.items, index)
  return def and def.name or id or tostring(index)
end

local function gen2TrainerName(data, save, trainer)
  local class, classId = gen2Definition(
    data and data.gen2Trainers and data.gen2Trainers.classes,
    trainer and trainer.class)
  if not class then return "TRAINER" end
  classId = class.id or classId
  if tostring(classId):match("^RIVAL") then
    return save and save.rival and save.rival.name or class.name or classId
  end
  local member = class.trainers and class.trainers[trainer.member]
  return member and member.name
    and tostring(class.name or classId) .. " " .. tostring(member.name)
    or class.name or classId
end

function Area.gen2PickupState(data, world, event)
  if not Area.Pickups then
    local done = gen2FlagSet(world, event)
    return done, not done
  end
  if Area.pickupData ~= data or Area.pickupScripts ~= data.gen2Scripts
      or Area.pickupInitial ~= data.gen2InitialEvents or Area.pickupMaps ~= data.gen2Maps then
    Area.pickupPolicy = Area.Pickups.new(data)
    Area.pickupData, Area.pickupScripts = data, data.gen2Scripts
    Area.pickupInitial, Area.pickupMaps = data.gen2InitialEvents, data.gen2Maps
  end
  return Area.pickupPolicy:state(world, event)
end

function Area.gen2Hidden(data, world, mapId)
  local map = data and data.gen2Maps and data.gen2Maps[mapId]
  local out = {}
  for _, event in ipairs(map and map.bgEvents or {}) do
    local hidden = event.hiddenItem
    if hidden then
      local done, available, status = Area.gen2PickupState(data, world, hidden.event)
      out[#out + 1] = {
        label = gen2ItemName(data, hidden.item),
        done = done, available = available, status = status,
        untracked = status == "NOT TRACKED",
        unknown = gen2PickupUnknown(world, hidden.event),
        x = event.x, y = event.y, event = hidden.event,
      }
    end
  end
  return out
end

function Area.gen2ScriptTrainer(data, obj)
  local scripts = data and data.gen2Scripts
  local commands = obj and obj.scriptKey
  commands = type(commands) == "table" and commands
    or scripts and scripts[commands]
  local trainer, started, canLose
  for _, command in ipairs(commands or {}) do
    if command.op == "loadtrainer" then
      trainer = { class = command.class, member = command.member }
    elseif command.op == "loadvar" and command.args
        and command.args[1] == 3 then
      canLose = command.args[2] == 1 -- VAR_BATTLETYPE / BATTLETYPE_CANLOSE
    elseif command.op == "startbattle" and trainer then
      started = true
      trainer.optional = canLose == true
    elseif command.op == "setevent" and started and trainer.event == nil then
      trainer.event = command.event
    end
  end
  return started and trainer or nil
end

function Area.gen2Rows(data, save, world, mapIds, checkpoint)
  local rows = { {}, {}, {}, {} }
  local Trades = data.gen2EventTables and require("src.core.gen2.NpcTrade")
  if Area.Gifts and (Area.giftData ~= data or Area.giftScripts ~= data.gen2Scripts
      or Area.giftInitial ~= data.gen2InitialEvents or Area.giftMaps ~= data.gen2Maps
      or Area.giftConstants ~= data.gen2Constants) then
    Area.giftPolicy = Area.Gifts.new(data, checkpoint)
    Area.giftData, Area.giftScripts = data, data.gen2Scripts
    Area.giftInitial, Area.giftMaps = data.gen2InitialEvents, data.gen2Maps
    Area.giftConstants = data.gen2Constants
  end
  for _, mapId in ipairs(mapIds) do
    if checkpoint then checkpoint() end
    local map = data and data.gen2Maps and data.gen2Maps[mapId]
    if not map then
      rows[1][#rows[1] + 1] = { mapId = mapId, label = "NOT TRACKED", untracked = true, unknown = true }
    end
    local gifts = {}
    local objects = {}
    for _, obj in ipairs(map and map.objects or {}) do objects[#objects + 1] = obj end
    -- Celadon's prize counters are background events rather than NPC actors.
    -- Game path [Gen 2]: Celadon prize counters are background scripts, so NPC-only scanning would lose their rewards.
    if mapId == "CELADON_GAME_CORNER_PRIZE_ROOM" then
      for _, bg in ipairs(map and map.bgEvents or {}) do
        objects[#objects + 1] = { scriptKey = bg.scriptKey, x = bg.x, y = bg.y, eventFlag = 65535 }
      end
    end
    for _, obj in ipairs(objects) do
      local trainer = obj.trainer or Area.gen2ScriptTrainer(data, obj)
      if trainer then
        -- Story populations disappear; weekday/ship variants and a closed Gym
        -- can return. Radio Tower is also hidden before the takeover begins.
        -- Game path [Gen 2]: Rocket takeovers, Wise Trio and first-trip ship populations disappear; weekday/resettable ship opponents can return.
        local missable = obj.eventFlag == 1742 and (mapId:match("^RADIO_TOWER_")
            or mapId:match("^GOLDENROD_UNDERGROUND_"))
          or obj.eventFlag == 1754 and mapId:match("^TEAM_ROCKET_BASE_")
          or obj.eventFlag == 1788 and mapId == "SLOWPOKE_WELL_B1F"
          or obj.eventFlag == 1964 and mapId == "WISE_TRIOS_ROOM"
          or obj.eventFlag == 1849 and mapId:match("^FAST_SHIP_")
        local repeatable
        if mapId:match("^FAST_SHIP_") then
          Area.gen2PickupState(data, world, trainer.event)
          repeatable = Area.pickupPolicy and Area.pickupPolicy.resettable[trainer.event] or nil
        end
        rows[1][#rows[1] + 1] = {
          label = gen2TrainerName(data, save, trainer),
          done = gen2FlagSet(world, trainer.event),
          id = string.format("%s_obj_%d", mapId, obj.index or 0),
          mapId = mapId, index = obj.index or 0, x = obj.x, y = obj.y,
          spriteId = obj.sprite, palette = obj.palette,
          event = trainer.event, hideEvent = obj.eventFlag,
          scripted = obj.trainer == nil,
          optional = trainer.optional,
          repeatable = repeatable,
          missable = missable and (obj.trainer ~= nil or trainer.optional) and true or nil,
          missedAfter = missable and (obj.eventFlag == 1742 and 1393 or obj.eventFlag == 1964 and 821) or nil,
        }
      elseif obj.itemball and obj.itemball.item ~= 0 then
        local done, available, status = Area.gen2PickupState(data, world, obj.eventFlag)
        rows[2][#rows[2] + 1] = {
          label = gen2ItemName(data, obj.itemball.item),
          done = done, available = available, status = status,
          untracked = status == "NOT TRACKED",
          unknown = gen2PickupUnknown(world, obj.eventFlag),
          mapId = mapId, x = obj.x, y = obj.y, kind = "item", event = obj.eventFlag,
        }
      end
      for _, gift in ipairs(Area.Gifts and not obj.itemball
          and Area.giftPolicy:catalog(obj.scriptKey, checkpoint, mapId) or {}) do
        local trade = gift.tradeId ~= nil and Trades and Trades.row(data.gen2EventTables, gift.tradeId) or nil
        local def, species
        if gift.speciesIndex then def, species = gen2Definition(data.pokemon, gift.speciesIndex) end
        if trade then species, def = trade.get, data.pokemon and data.pokemon[trade.get] end
        local pokemon = species ~= nil or gift.isEgg
        if gift.itemId or def or gift.isEgg then
          local key = gift.tradeId ~= nil and "trade:" .. gift.tradeId
            or (gift.event or "caught") .. ":" .. tostring(species or gift.itemId or "egg")
          local hidden = obj.eventFlag ~= 65535 and gen2FlagSet(world, obj.eventFlag)
          if not gifts[key] or gifts[key].mapVisible == false and not hidden then
            local done = trade and Trades.done(save, gift.tradeId) or gen2FlagSet(world, gift.event)
            if gift.catchGoal then done = ((save.pokedex or {}).caught or {})[species] == true end
            local available = not done and not hidden
            if pokemon and available then
              available = Area.giftPolicy:available(gift, save, world, checkpoint)
              if trade then
                local partner = false
                for _, mon in ipairs(save.party or {}) do
                  if not mon.isEgg and Trades.check(trade, mon) == nil then partner = true; break end
                end
                available = available and partner
              end
            end
            local row = {
              id = mapId .. "_gift_" .. key,
              actorId = obj.index and string.format("%s_obj_%d", mapId, obj.index) or nil,
              mapId = mapId, index = obj.index, x = obj.x, y = obj.y,
              spriteId = obj.sprite, palette = obj.palette, hideEvent = obj.eventFlag,
              kind = pokemon and "pokemon" or "item", gift = true, itemId = gift.itemId, event = gift.event,
              label = gift.isEgg and "EGG" or def and (def.name or species) or gen2ItemName(data, gift.itemId), done = done,
              species = species, level = gift.level, order = def and def.index or 0, isEgg = gift.isEgg,
              -- Game path [Gen 2]: Route 35s mail-carrying Spearow is a loan, as is Shuckle; neither is an ordinary permanent gift contract.
              loan = gift.loan or mapId == "ROUTE_35_GOLDENROD_GATE" and species == "SPEAROW"
                and gift.command and (gift.command.trainer or (gift.command.args or {})[4]) == 1 or nil,
              trade = trade ~= nil, tradeId = gift.tradeId, needsSpecies = trade and trade.give,
              needsGender = trade and trade.gender, noRoom = pokemon and not trade and not done and not hidden and #(save.party or {}) >= 6,
              repeatable = gift.repeatable, available = available, coinCost = gift.coinCost, catchGoal = gift.catchGoal,
              mapVisible = not hidden, unknown = gen2PickupUnknown(world, gift.event),
              status = gift.catchGoal and done and "CAUGHT" or not done and not available and "LATER" or nil,
            }
            if row.unknown then
              row.untracked, row.status = true, "NOT TRACKED"
              if pokemon then row.available = false end
            end
            local list = pokemon and rows[4] or rows[2]
            if gifts[key] then
              for i, previous in ipairs(list) do
                if previous == gifts[key] then list[i] = row; break end
              end
            else list[#list + 1] = row end
            gifts[key] = row
          end
        end
      end
    end
    for _, hidden in ipairs(Area.gen2Hidden(data, world, mapId)) do
      hidden.mapId, hidden.kind = mapId, "hidden"
      rows[3][#rows[3] + 1] = hidden
    end
  end
  return rows
end

function Area.remaining(sections)
  local out = {}
  for index, section in ipairs(sections) do
    local remaining = 0
    for _, row in ipairs(section.rows) do
      if not row.done then remaining = remaining + 1 end
    end
    out[index] = remaining
  end
  return out
end
  return Area
end
