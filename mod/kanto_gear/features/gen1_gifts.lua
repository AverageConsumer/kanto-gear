-- NPC rewards belong to the live save, never to remembered bag contents.
local M = {}
local commands = {}
for op in ("ask check_dex_owned check_flag check_item clear_flag dex_rating face_object face_player "
    .. "fade give_item hide_object jump jump_if_false jump_if_true label move_npc_to no_npc_face_player "
    .. "open_mart place_npc play_music save_end_battle_text set_flag show_object show_text start_battle "
    .. "stop_music take_item text_opts text_sound give_pokemon trade check_money take_money"):gmatch("%S+") do commands[op] = true end

local function reaches(rows, labels, gift, event, value, proof, save, checkpoint, failed)
  local pending, seen, count = { { pc = 1, value = value } }, {}, 0
  while #pending > 0 do
    local at = table.remove(pending)
    local key = at.pc .. ":" .. tostring(at.value) .. ":" .. tostring(at.given)
    if not seen[key] then
      seen[key], count = true, count + 1
      if count > 4096 then return nil end
      if checkpoint and count % 32 == 0 then checkpoint() end
      local row = rows[at.pc]
      if row then
        if row == gift then
          if not proof then return true end
          at.given = true
        end
        local op, valueNow = row[1], at.value
        if (op == "set_flag" or op == "clear_flag") and row[2] == event then
          if proof and op == "set_flag" and not at.given then return nil end
          valueNow = op == "set_flag"
          if op == "set_flag" and at.given then return true end
        end
        local function push(pc)
          if pc == "end" then return end
          if type(pc) == "string" then pc = labels[pc] end
          if type(pc) ~= "number" or pc < 1 or pc % 1 ~= 0 then return false end
          pending[#pending + 1] = { pc = pc, value = valueNow, given = at.given }
          return true
        end
        if op == "jump" then
          if push(row[2]) == false then return nil end
        elseif op == "jump_if_true" or op == "jump_if_false" then
          local result, previous = nil, rows[at.pc - 1]
          if previous and previous[1] == "check_flag" then
            if previous[2] == event then result = valueNow
            elseif save then result = (save.flags or {})[previous[2]] == true end
          elseif save and previous and previous[1] == "check_item" then
            result = ((save.inventory or {})[previous[2]] or 0) > 0
          elseif save and previous and previous[1] == "check_money" then
            result = (save.money or 0) >= previous[2]
          elseif previous == gift and gift[1] == "give_pokemon" and failed ~= nil then
            result = not failed
          elseif save and previous and previous[1] == "check_dex_owned" then
            local owned = 0
            for _, caught in pairs((save.pokedex or {}).owned or {}) do if caught then owned = owned + 1 end end
            result = owned >= previous[2]
          end
          local take = result
          if op == "jump_if_false" and result ~= nil then take = not result end
          if take ~= false and push(row[2]) == false then return nil end
          if take ~= true then push(at.pc + 1) end
        else push(at.pc + 1) end
      end
    end
  end
  return false
end

local function analyze(rows, checkpoint)
  local labels, checked, written, cleared, gifts, trades, out = {}, {}, {}, {}, {}, {}, {}
  for i, row in ipairs(rows) do
    if type(row) ~= "table" or not commands[row[1]] then return {} end
    if (row[1] == "label" or row[1] == "check_flag" or row[1] == "set_flag"
        or row[1] == "clear_flag" or row[1] == "check_item" or row[1] == "give_item" or row[1] == "give_pokemon")
        and type(row[2]) ~= "string" then return {} end
    if (row[1] == "check_dex_owned" or row[1] == "check_money") and type(row[2]) ~= "number" then return {} end
    if (row[1] == "give_item" or row[1] == "give_pokemon") and row[3] ~= nil
        and (type(row[3]) ~= "number" or row[3] < 1) then return {} end
    if row[1] == "give_pokemon" and row[3] == nil then return {} end
    if row[1] == "label" and labels[row[2]] == nil then labels[row[2]] = i
    elseif row[1] == "check_flag" then checked[row[2]] = true
    elseif row[1] == "set_flag" then written[row[2]] = true
    elseif row[1] == "clear_flag" then cleared[row[2]] = true
    elseif row[1] == "give_item" or row[1] == "give_pokemon" then gifts[#gifts + 1] = row
    elseif row[1] == "trade" and type(row[2]) == "number" and type(row[3]) == "string" then
      trades[#trades + 1] = row
    end
  end
  local events = {}
  for event in pairs(checked) do
    if type(event) == "string" and written[event] and not cleared[event] then events[#events + 1] = event end
  end
  table.sort(events)
  local added = {}
  for _, gift in ipairs(gifts) do
    if type(gift[2]) == "string" then
      for _, event in ipairs(events) do
        local id = event .. ":" .. gift[2]
        if not added[id] and reaches(rows, labels, gift, event, true, false, nil, checkpoint) == false
            and reaches(rows, labels, gift, event, false, true, nil, checkpoint, false) == true
            and (gift[1] ~= "give_pokemon"
              or reaches(rows, labels, gift, event, false, true, nil, checkpoint, true) == false) then
          local pokemon = gift[1] == "give_pokemon"
          local cost
          for _, row in ipairs(rows) do if row[1] == "check_money" then cost = row[2] end end
          out[#out + 1] = { itemId = not pokemon and gift[2] or nil,
            species = pokemon and gift[2] or nil, level = pokemon and gift[3] or nil,
            event = event, command = gift, labels = labels, cost = cost }
          added[id] = true
          break
        end
      end
    end
  end
  for _, trade in ipairs(trades) do
    if not written[trade[3]] and not cleared[trade[3]]
        and reaches(rows, labels, trade, trade[3], false, false, nil, checkpoint) == true then
      out[#out + 1] = { tradeIndex = trade[2], event = trade[3], command = trade, labels = labels }
    end
  end
  return out
end

-- These native Lua handlers are opaque to a script reader. Use their audited
-- receipt metadata only while the active handler is that exact built-in function.
-- Game path [Gen 1]: built-in Lua NPC handlers are opaque; receipt metadata is trusted only for the exact loaded handler.
local native = {
  story5 = {
    { "CELADON_DINER", "TEXT_CELADONDINER_GYM_GUIDE", "COIN_CASE", "EVENT_GOT_COIN_CASE" },
    { "CELADON_MART_3F", "TEXT_CELADONMART3F_CLERK", "TM_COUNTER", "EVENT_GOT_TM18" },
    { "ROUTE_12_GATE_2F", "TEXT_ROUTE12GATE2F_BRUNETTE_GIRL", "TM_SWIFT", "EVENT_GOT_TM39" },
    { "CELADON_CITY", "TEXT_CELADONCITY_GRAMPS3", "TM_SOFTBOILED", "EVENT_GOT_TM41" },
    { "CINNABAR_LAB_METRONOME_ROOM", "TEXT_CINNABARLABMETRONOMEROOM_SCIENTIST1", "TM_METRONOME", "EVENT_GOT_TM35" },
    { "VIRIDIAN_CITY", "TEXT_VIRIDIANCITY_FISHER", "TM_DREAM_EATER", "EVENT_GOT_TM42" },
    { "SILPH_CO_2F", "TEXT_SILPHCO2F_SILPH_WORKER_F", "TM_SELFDESTRUCT", "EVENT_GOT_TM36" },
    { "ROUTE_1", "TEXT_ROUTE1_YOUNGSTER1", "POTION", "EVENT_GOT_POTION_SAMPLE" },
  },
  story4 = {
    { "ROUTE_2_GATE", "TEXT_ROUTE2GATE_OAKS_AIDE", "HM_FLASH", "EVENT_GOT_HM05", dex = 10, alias = "EVENT_GOT_HM_FLASH" },
    { "ROUTE_11_GATE_2F", "TEXT_ROUTE11GATE2F_OAKS_AIDE", "ITEMFINDER", "EVENT_GOT_ITEMFINDER", dex = 30 },
    { "ROUTE_15_GATE_2F", "TEXT_ROUTE15GATE2F_OAKS_AIDE", "EXP_ALL", "EVENT_GOT_EXP_ALL", dex = 50 },
    { "COPYCATS_HOUSE_2F", "TEXT_COPYCATSHOUSE2F_COPYCAT", "TM_MIMIC", "EVENT_GOT_TM31", needsItem = "POKE_DOLL" },
    { "MR_PSYCHICS_HOUSE", "TEXT_MRPSYCHICSHOUSE_MR_PSYCHIC", "TM_PSYCHIC_M", "EVENT_GOT_TM29" },
    { "ROUTE_16_FLY_HOUSE", "TEXT_ROUTE16FLYHOUSE_BRUNETTE_GIRL", "HM_FLY", "EVENT_GOT_HM02" },
    { "CELADON_MART_ROOF", "TEXT_CELADONMARTROOF_LITTLE_GIRL", "TM_ICE_BEAM", "EVENT_GOT_TM13", needsItem = "FRESH_WATER" },
    { "CELADON_MART_ROOF", "TEXT_CELADONMARTROOF_LITTLE_GIRL", "TM_ROCK_SLIDE", "EVENT_GOT_TM48", needsItem = "SODA_POP" },
    { "CELADON_MART_ROOF", "TEXT_CELADONMARTROOF_LITTLE_GIRL", "TM_TRI_ATTACK", "EVENT_GOT_TM49", needsItem = "LEMONADE" },
    { "ROUTE_24", "TEXT_ROUTE24_COOLTRAINER_M1", "NUGGET", "EVENT_GOT_NUGGET" },
    { "FIGHTING_DOJO", "TEXT_FIGHTINGDOJO_HITMONLEE_POKE_BALL", "HITMONLEE", "EVENT_GOT_HITMONLEE",
      pokemon = true, level = 30, requires = "EVENT_BEAT_KARATE_MASTER", alternative = "EVENT_GOT_HITMONCHAN" },
    { "FIGHTING_DOJO", "TEXT_FIGHTINGDOJO_HITMONCHAN_POKE_BALL", "HITMONCHAN", "EVENT_GOT_HITMONCHAN",
      pokemon = true, level = 30, requires = "EVENT_BEAT_KARATE_MASTER", alternative = "EVENT_GOT_HITMONLEE" },
  },
  -- Game path [Yellow]: Melanie and Officer Jenny have happiness/badge-gated starter gifts absent from Red/Blue.
  yellow_gifts = {
    { "CERULEAN_MELANIES_HOUSE", "TEXT_CERULEANMELANIESHOUSE_MELANIE", "BULBASAUR", "EVENT_GOT_BULBASAUR_IN_CERULEAN",
      pokemon = true, level = 10, happiness = 147 },
    { "VERMILION_CITY", "TEXT_VERMILIONCITY_OFFICER_JENNY", "SQUIRTLE", "EVENT_GOT_SQUIRTLE_FROM_OFFICER_JENNY",
      pokemon = true, level = 10, needsItem = "THUNDERBADGE" },
  },
  story2 = { { "BIKE_SHOP", "TEXT_BIKESHOP_CLERK", "BICYCLE", "EVENT_GOT_BICYCLE", needsItem = "BIKE_VOUCHER" } },
  ["flavor.museum_1f"] = { { "MUSEUM_1F", "TEXT_MUSEUM1F_SCIENTIST2", "OLD_AMBER", "EVENT_GOT_OLD_AMBER" } },
}

-- Game path [Red/Blue/Yellow]: Game Corner species, levels and coin prices differ by edition; repeatable prizes use caught goals.
local casinoPrizes = {
  red = { { "ABRA",9,180 }, { "CLEFAIRY",8,500 }, { "NIDORINA",17,1200 },
    { "DRATINI",18,2800 }, { "SCYTHER",25,5500 }, { "PORYGON",26,9999 } },
  blue = { { "ABRA",6,120 }, { "CLEFAIRY",12,750 }, { "NIDORINO",17,1200 },
    { "PINSIR",20,2500 }, { "DRATINI",24,4600 }, { "PORYGON",18,6500 } },
  yellow = { { "ABRA",15,230 }, { "VULPIX",18,1000 }, { "WIGGLYTUFF",22,2680 },
    { "SCYTHER",30,6500 }, { "PINSIR",30,6500 }, { "PORYGON",26,9999 } },
}

function M.new()
  local scripts, handlers, cache = require("src.script.MapScripts"), {}, setmetatable({}, { __mode = "k" })
  local Party, Boxes = require("src.pokemon.Party"), require("src.pokemon.Boxes")
  local function add(module, def)
    local map = module and module[def[1]]
    local handler = map and map.talk and map.talk[def[2]]
    if type(handler) ~= "function" then return end
    handlers[handler] = handlers[handler] or {}
    handlers[handler][#handlers[handler] + 1] = {
      itemId = not def.pokemon and def[3] or nil, species = def.pokemon and def[3] or nil,
      event = def[4], dex = def.dex, alias = def.alias, level = def.level,
      coinCost = def.coinCost, catchGoal = def.catchGoal,
      needsItem = def.needsItem, requires = def.requires, alternative = def.alternative, happiness = def.happiness,
    }
  end
  for name, definitions in pairs(native) do
    local ok, module = pcall(require, "data.scripts." .. name)
    if ok then for _, def in ipairs(definitions) do add(module, def) end end
  end
  local found, story3 = pcall(require, "data.scripts.story3")
  if found then
    local version = require("src.core.GameVersion").get()
    for i, prize in ipairs(casinoPrizes[version] or {}) do
      add(story3, { "GAME_CORNER_PRIZE_ROOM", "TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_" .. math.ceil(i / 3),
        prize[1], nil, pokemon = true, level = prize[2], coinCost = prize[3], catchGoal = true, needsItem = "COIN_CASE" })
    end
  end
  local ok, gyms = pcall(require, "data.scripts.gyms")
  local found, victories = pcall(require, "data.scripts.victories")
  if ok and found then
    for mapId, map in pairs(gyms) do
      for text in pairs(map.talk or {}) do
        for _, reward in pairs(victories) do
          if type(reward) == "table" and reward.badge == map.badge and reward.item and reward.gotFlag then
            add(gyms, { mapId, text, reward.item, reward.gotFlag, requires = reward.flag })
          end
        end
      end
    end
  end
  return { rows = function(_, data, save, mapId, map, checkpoint)
    local out, added = {}, {}
    local objects = {}
    for _, obj in ipairs(map and map.objects or {}) do objects[#objects + 1] = obj end
    if mapId == "GAME_CORNER_PRIZE_ROOM" then
      for _, sign in ipairs(map and map.signs or {}) do objects[#objects + 1] = sign end
    end
    for _, obj in ipairs(objects) do
      if checkpoint then checkpoint() end
      local handler = obj.text and scripts.talkScript(mapId, obj.text)
      local rewards = handlers[handler]
      if type(handler) == "table" then
        rewards = cache[handler]
        if not rewards then rewards = analyze(handler, checkpoint); cache[handler] = rewards end
      end
      for _, gift in ipairs(rewards or {}) do
        local trade = gift.tradeIndex and data.field and data.field.trades and data.field.trades[gift.tradeIndex]
        local species = gift.species or trade and trade.get
        local item = species and data.pokemon and data.pokemon[species]
          or gift.itemId and data.items and data.items[gift.itemId]
        local id = (gift.event or "caught") .. ":" .. tostring(species or gift.itemId)
        local visible = not obj.hidden
        local toggles = save.objectToggles and save.objectToggles[mapId] or {}
        if toggles[obj.name] ~= nil then visible = toggles[obj.name] == true end
        if item and (not added[id] or not added[id].mapVisible and visible) then
          local flags = save.flags or {}
          local done = flags[gift.event] == true or gift.alias and flags[gift.alias] == true or false
          if gift.catchGoal then done = ((save.pokedex or {}).caught or {})[species] == true end
          local excluded = not done and gift.alternative and flags[gift.alternative] == true or false
          local available = visible and not done and not excluded
          if gift.command and available then
            available = reaches(handler, gift.labels, gift.command, gift.event, false, false, save, checkpoint) == true
          end
          if gift.requires then available = available and flags[gift.requires] == true end
          if gift.needsItem then available = available and ((save.inventory or {})[gift.needsItem] or 0) > 0 end
          if gift.coinCost then available = available and (save.coins or 0) >= gift.coinCost end
          if gift.happiness then available = available and (save.pikachuHappiness or 90) >= gift.happiness end
          if trade then
            local partner = false
            for _, mon in ipairs(save.party or {}) do if mon.species == trade.give then partner = true; break end end
            available = available and partner
          end
          if gift.dex then
            local owned = 0
            for _, caught in pairs((save.pokedex or {}).owned or {}) do if caught then owned = owned + 1 end end
            available = available and owned >= gift.dex
          end
          local noRoom = false
          if available and species and not trade and #(save.party or {}) >= Party.MAX then
            noRoom = true
            for i = 1, Boxes.COUNT do
              local box = save.boxes and save.boxes[i] or i == 1 and save.box or {}
              if #(box or {}) < Boxes.CAPACITY then noRoom = false; break end
            end
            available = not noRoom
          end
          local row = { id = mapId .. "_gift_" .. id, actorId = obj.index and mapId .. "_obj_" .. obj.index or nil,
            mapId = mapId, index = obj.index, x = obj.x, y = obj.y, spriteId = obj.sprite,
            kind = species and "pokemon" or "item", gift = true, itemId = gift.itemId, event = gift.event,
            label = item.name or species or gift.itemId, species = species, level = gift.level,
            order = item.index or 0, trade = trade ~= nil, needsSpecies = trade and trade.give, cost = gift.cost, coinCost = gift.coinCost, catchGoal = gift.catchGoal,
            done = done, excluded = excluded, noRoom = noRoom, available = available, mapVisible = visible,
            alternative = gift.alternative,
            required = gift.itemId == "HM_CUT" or nil,
            status = gift.catchGoal and done and "CAUGHT" or not done and not available and "LATER" or nil }
          if added[id] then
            for i, old in ipairs(out) do if old == added[id] then out[i] = row; break end end
          else out[#out + 1] = row end
          added[id] = row
        end
      end
    end
    return out
  end }
end

return M
