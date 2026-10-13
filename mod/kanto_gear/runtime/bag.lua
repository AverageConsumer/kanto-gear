return function(
  THEME, assist, compat, displayRuntime, header, mod,
  render, screenState, session
)
  function displayRuntime.bagWords(source, limit, maximum)
    return THEME:descriptionLines(source, limit, maximum, 200)
  end

  -- Game path [Gen 1/2/3]: native item definitions/effect readers encode medicine and pockets differently; classification is presentation-only.
  function displayRuntime.bagItemKind(id, def)
    local upper = tostring(id or ""):upper()
    if def and (def.ball or def.pocket == "BALL") then return "ball" end
    if upper:match("^TM_?%d") or upper:match("^HM_?%d")
        or def and (def.machine or def.teaches or def.pocket == "TM_HM") then return "machine" end
    if displayRuntime.gen3 then
      local kind = def and def.kind
      return kind == "status" and "status"
        or (kind == "heal" or kind == "full_restore" or kind == "revive" or kind == "pp") and "medicine"
        or "item"
    end
    local gen2 = compat.isGen2()
    local ok, Effects = pcall(require, gen2 and "src.core.gen2.ItemEffects"
      or "src.inventory.ItemEffects")
    local medicine = false
    if ok then
      if Effects.isBall and Effects.isBall(id) then return "ball" end
      if gen2 and Effects.partyAction then
        local action = Effects.partyAction(id, session.game.data)
        if action == "status" then return "status" end
        if action == "heal" or action == "revive"
            or action == "pp" and upper ~= "PP_UP" then return "medicine" end
        if action then return "item" end
      elseif Effects.isBattleMedicine and Effects.isBattleMedicine(id) then
        medicine = true
      end
    end
    if upper:find("HEAL", 1, true) or upper == "ANTIDOTE"
        or upper == "AWAKENING" then return "status" end
    if medicine or upper:find("POTION", 1, true) or upper:find("ETHER", 1, true)
        or upper:find("ELIX", 1, true) or upper == "REVIVE"
        or upper == "MAX_REVIVE" then return "medicine" end
    return "item"
  end

  -- Game path [Gen 1 vs Gen 2/3]: descriptions are native in later games; Gen 1 inferred details require the item_details setting.
  function displayRuntime.bagDescription(id, def)
    if not assist("item_details") and not compat.isGen2() and not displayRuntime.gen3 then return {} end
    local moveId = def and (def.teaches
      or def.machine and def.machine.move)
    local move = moveId and session.game.data.moves and session.game.data.moves[moveId]
    local source = move and move.description or def and def.description
    if source and source ~= "" then
      return displayRuntime.bagWords(source, 31, 3)
    end
    if moveId then
      return displayRuntime.bagWords(THEME:format(
        "TEACHES %s TO A COMPATIBLE POKEMON.",
        move and move.name or tostring(moveId):gsub("_", " ")), 31, 3)
    end
    if displayRuntime.bagItemKind(id, def) == "ball" then
      return displayRuntime.bagWords(
        THEME:translate("A BALL USED TO CATCH WILD POKEMON."), 31, 3)
    end
    if def and def.needsTarget then
      return displayRuntime.bagWords(
        THEME:translate("USE IT ON A POKEMON IN YOUR PARTY."), 31, 3)
    end
    if def and def.keyItem then
      return displayRuntime.bagWords(
        THEME:translate("AN IMPORTANT ITEM FOR YOUR ADVENTURE."), 31, 3)
    end
    return displayRuntime.bagWords(
      THEME:translate("AN ITEM WITH A SPECIAL FIELD EFFECT."), 31, 3)
  end

  function displayRuntime.bagItem(id, count, name)
    local def = session.game.data.items and session.game.data.items[id] or {}
    local moveId = def.teaches or def.machine and def.machine.move
    local move = moveId and session.game.data.moves and session.game.data.moves[moveId]
    return { id = id, count = count or tonumber((session.game.save.inventory or {})[id]) or 0,
      label = name or def.name or tostring(id):gsub("_", " "),
      icon = displayRuntime.bagItemKind(id, def), detail = move and move.name,
      lines = displayRuntime.bagDescription(id, def) }
  end

  -- Game path [Gen 1/2/3]: Gen 1 has one bag list, Gen 2 four pockets and Gen 3 an additional berry pocket.
  function displayRuntime.bagModel()
    local state, save, data = displayRuntime.bag, session.game.save or {}, session.game.data or {}
    local gen2 = compat.isGen2()
    local pockets = gen2 and displayRuntime.bagPockets
      or { displayRuntime.bagPockets[1] }
    if displayRuntime.gen3 then
      pockets = { displayRuntime.bagPockets[1], displayRuntime.bagPockets[2],
        displayRuntime.bagPockets[3], displayRuntime.bagPockets[4], { id = "BERRY", label = "BERRIES" } }
    end
    state.pocket = math.max(1, math.min(state.pocket or 1, #pockets))
    local pocket = pockets[state.pocket]
    local order = save.bagOrder or {}
    if not displayRuntime.gen3 then
      -- Bag.order can be filtered to another mod's currently open pocket.
      -- Read our independent view without changing its filter or the save.
      local ordered, seen, missing = {}, {}, {}
      local inventory = save.inventory or {}
      for _, id in ipairs(order) do
        if not seen[id] and (tonumber(inventory[id]) or 0) > 0
            and not tostring(id):find("BADGE", 1, true) then
          ordered[#ordered + 1], seen[id] = id, true
        end
      end
      for id, count in pairs(inventory) do
        if not seen[id] and (tonumber(count) or 0) > 0
            and not tostring(id):find("BADGE", 1, true) then
          missing[#missing + 1] = id
        end
      end
      table.sort(missing, function(a, b)
        local ad, bd = (data.items or {})[a] or {}, (data.items or {})[b] or {}
        local ai, bi = ad.index or ad.itemId or math.huge,
          bd.index or bd.itemId or math.huge
        if ai ~= bi then
          if type(ai) == type(bi) then return ai < bi end
          return tostring(ai) < tostring(bi)
        end
        return tostring(a) < tostring(b)
      end)
      for _, id in ipairs(missing) do ordered[#ordered + 1] = id end
      order = ordered
    end
    local entries = {}
    for _, id in ipairs(order) do
      local count = tonumber((save.inventory or {})[id]) or 0
      local def = data.items and data.items[id] or {}
      local itemPocket = def.pocket or "ITEM"
      if count > 0 and (not gen2 and not displayRuntime.gen3 or itemPocket == pocket.id) then
        entries[#entries + 1] = displayRuntime.bagItem(id, count)
      end
    end
    -- Game path [Gen 2]: native item index determines display order; do not reuse Gen 1 insertion order or Gen 3 native pocket order.
    if gen2 then
      table.sort(entries, function(a, b)
        local ad = data.items and data.items[a.id] or {}
        local bd = data.items and data.items[b.id] or {}
        local ai, bi = tonumber(ad.index) or math.huge,
          tonumber(bd.index) or math.huge
        if ai ~= bi then return ai < bi end
        return tostring(a.id) < tostring(b.id)
      end)
    end
    local recent = displayRuntime.lastBagItem()
    local perPage = recent and 4 or 6
    local pages = math.max(1, math.ceil(#entries / perPage))
    state.page = math.max(1, math.min(state.page or 1, pages))
    local visible, first = {}, (state.page - 1) * perPage + 1
    for index = first, math.min(#entries, first + perPage - 1) do
      visible[#visible + 1] = entries[index]
    end
    local detail
    if state.detail then
      for _, entry in ipairs(entries) do
        if entry.id == state.detail then detail = entry break end
      end
      if not detail then state.detail = nil end
    end
    -- Load art for the visible page/detail only; the host caches images/quads.
    if displayRuntime.gen3 then
      for _, entry in ipairs(visible) do entry.itemSprite = displayRuntime.gen3:itemIcon(entry.id) end
      if detail then detail.itemSprite = displayRuntime.gen3:itemIcon(detail.id) end
    end
    local model = displayRuntime.ItemPage.model(detail, detail and displayRuntime.bagActions(detail.id),
      screenState() == "active" and not session.battle, state.message, function(label) return THEME:translate(label) end)
    model.pocket, model.pocketIndex, model.pockets = THEME:translate(pocket.label), state.pocket, #pockets
    model.page, model.pages, model.entries, model.total = state.page, pages, visible, #entries
    model.recent, model.money = recent, tonumber(save.money) or 0
    return model
  end

  function displayRuntime.cycleBagPage(direction)
    displayRuntime.requestPageMotion(direction)
    local model = displayRuntime.bagModel()
    displayRuntime.bag.page = (model.page - 1 + direction) % model.pages + 1
    displayRuntime.bag.message, session.dirty = nil, true
  end

  function displayRuntime.cycleBagPocket(direction)
    local model = displayRuntime.bagModel()
    if model.pockets <= 1 then return displayRuntime.cycleBagPage(direction) end
    displayRuntime.bag.pocket = (model.pocketIndex - 1 + direction)
      % model.pockets + 1
    displayRuntime.bag.page, displayRuntime.bag.detail = 1, nil
    displayRuntime.bag.message, session.dirty = nil, true
  end

  function displayRuntime.bagMessage(lines)
    local out = {}
    for _, line in ipairs(lines or {}) do
      out[#out + 1] = tostring(line):gsub("{PLAYER}",
        session.game.save and session.game.save.player and session.game.save.player.name or "PLAYER")
    end
    return out
  end

  -- Game path [Gen 1/2/3]: use the active native action catalogue; only Gen 2/3 support held-item and registration workflows.
  function displayRuntime.bagActions(itemId)
    local def = session.game.data and session.game.data.items and session.game.data.items[itemId] or {}
    local source
    if displayRuntime.gen3 then source = displayRuntime.gen3Ui:bagActions(itemId)
    elseif compat.isGen2() then
      local Pack = require("src.ui.gen2.PackMenu")
      source = type(Pack.submenuRows) == "function" and Pack.submenuRows({ items = session.game.data.items,
        inBattle = function() return false end,
        pocket = function() return { id = def.pocket or "ITEM" } end }, itemId) or { "use" }
    else
      source = { "use" }
      if not def.keyItem and not tostring(itemId):match("^HM_?") then source[2] = "toss" end
    end
    local actions = {}
    for _, name in ipairs(source or {}) do
      local id = name:lower()
      if id == "sel" or id == "set" then id = "register" end
      if id ~= "quit" and id ~= "cancel" and id ~= "exit" then
        local label = id == "check_tag" and "CHECK TAG" or id:upper()
        if id == "register" and displayRuntime.gen3
            and displayRuntime.gen3.session.registeredItem == itemId then label = "UNREGISTER" end
        local enabled = true
        if id == "give" then
          enabled = false
          for _, mon in ipairs(session.game.save.party or {}) do
            if not mon.isEgg and not mon.egg then enabled = true break end
          end
        end
        actions[#actions + 1] = { id = id, label = THEME:translate(label), enabled = enabled }
      end
    end
    return actions
  end

  -- Game path [Gen 1/2/3]: effects must enter the matching native bag/submenu; Gen 3 delegates, Gen 2 builds PackMenu, Gen 1 uses its list.
  function displayRuntime.performBagAction(itemId, action)
    if screenState() ~= "active" or session.battle or not itemId
        or (tonumber(session.game.save.inventory[itemId]) or 0) <= 0 then return false end
    local allowed = false
    for _, row in ipairs(displayRuntime.bagActions(itemId)) do
      if row.id == action and row.enabled ~= false then allowed = true break end
    end
    if not allowed then return false end
    if action == "use" then return displayRuntime.useBagItem(itemId) end
    -- Giving/discarding must never become the last successfully used item.
    displayRuntime.recentItem.pending, displayRuntime.bag.pending = nil, nil
    if displayRuntime.gen3 then
      return displayRuntime.gen3Ui:openBagItem(itemId,
        action == "register" and "SET" or action:upper())
    end
    local stack, backend = session.game.stack
    if compat.isGen2() then
      backend = require("src.ui.gen2.PackMenu").new(session.game, {
        pocket = (session.game.data.items[itemId] or {}).pocket or "ITEM",
        onChoose = function(id) if session.game.useFieldItem then session.game:useFieldItem(id) end end })
      for index, row in ipairs(backend.rows or {}) do
        if row.id == itemId then backend.index = index break end
      end
      if not backend.rows[backend.index] or backend.rows[backend.index].id ~= itemId then return false end
      stack:push(backend)
      backend:openSubmenu()
      for index, name in ipairs(backend.submenu.rows) do
        if name == action or name == "sel" and action == "register" then
          backend.submenu.index = index
          backend:chooseSubmenu()
          session.dirty = true
          return true
        end
      end
      stack:pop()
      return false
    end
    backend = require("src.ui.BagMenu").new(session.game)
    for index, row in ipairs(backend.items or {}) do
      if row.value == itemId then
        backend.index = index
        stack:push(backend)
        backend.onChoose(row, backend)
        local menu = stack:top()
        local label = require("src.core.Strings")("TOSS")
        if menu ~= backend then
          for actionIndex, entry in ipairs(menu.items or {}) do
            if entry.label == label and type(entry.onSelect) == "function" then
              menu.index = actionIndex
              entry.onSelect()
              session.dirty = true
              return true
            end
          end
        end
        if stack:top() ~= backend then stack:pop() end
        stack:pop()
        return false
      end
    end
    return false
  end

  -- Game path [Gen 1/2/3]: teaching/target prompts belong to the native engine; Gen 3 opens its bag action, Gen 2 uses PackMenu callbacks.
  function displayRuntime.useBagItem(itemId)
    if screenState() ~= "active" or session.battle or not itemId then return false end
    displayRuntime.recentItem:watch(session.game.save, itemId)
    if displayRuntime.gen3 then return displayRuntime.gen3Ui:openBagItem(itemId, "USE") end
    local state = displayRuntime.bag
    state.message = nil
    local def = session.game.data and session.game.data.items and session.game.data.items[itemId]
    state.pending = { itemId = itemId,
      moveId = def and (def.teaches or def.machine and def.machine.move) }
    if compat.isGen2() then
      local ok, PackMenu = pcall(require, "src.ui.gen2.PackMenu")
      if not ok or type(PackMenu) ~= "table" or type(PackMenu.new) ~= "function" then
        state.pending = nil
        return false
      end
      local backend = PackMenu.new(session.game, {
        pocket = def and def.pocket or displayRuntime.bagPockets[state.pocket].id,
        onChoose = function(id)
          if type(session.game.useFieldItem) == "function" then session.game:useFieldItem(id) end
        end,
      })
      for index, row in ipairs(backend.rows or {}) do
        if row.id == itemId then backend.index = index break end
      end
      local row = backend.rows and backend.rows[backend.index]
      if not row or row.id ~= itemId then state.pending = nil; return false end
      local used, err = pcall(backend.useSelected, backend)
      if not used then
        state.pending = nil
        mod.log:warn("HGSS bag item %s rejected: %s", tostring(itemId), tostring(err))
        return false
      end
      if backend.message then
        state.message = displayRuntime.bagMessage(backend.message)
      end
      state.detail = state.message and itemId or nil
      session.dirty = true
      return true
    end

    local ok, BagMenu = pcall(require, "src.ui.BagMenu")
    local menuOk, Menu = pcall(require, "src.ui.Menu")
    if not ok or not menuOk or type(BagMenu) ~= "table"
        or type(BagMenu.new) ~= "function" then
      state.pending = nil
      return false
    end
    local backend = BagMenu.new(session.game)
    local item
    for _, row in ipairs(backend.items or {}) do
      if row.value == itemId then item = row break end
    end
    if not item or type(backend.onChoose) ~= "function" then
      state.pending = nil
      return false
    end
    local stack, before = session.game.stack, session.game.stack:top()
    local count = #(stack.states or {})
    local opened, err = pcall(backend.onChoose, item, backend)
    local useMenu = stack:top()
    if not opened or #(stack.states or {}) ~= count + 1
        or getmetatable(useMenu) ~= Menu
        or type(useMenu.items) ~= "table"
        or not useMenu.items[1]
        or type(useMenu.items[1].onSelect) ~= "function" then
      if stack:top() ~= before and #(stack.states or {}) == count + 1 then
        stack:pop()
      end
      mod.log:warn("HGSS bag could not open original USE action for %s: %s",
        tostring(itemId), tostring(err or "unexpected menu"))
      state.pending = nil
      return false
    end
    local action = useMenu.items[1].onSelect
    stack:pop()
    local used, useErr = pcall(action)
    if not used then
      mod.log:warn("HGSS bag item %s failed: %s",
        tostring(itemId), tostring(useErr))
      state.pending = nil
      return false
    end
    state.detail, session.dirty = nil, true
    return true
  end

  function displayRuntime.drawBag()
    local model = displayRuntime.bagModel()
    header(THEME:translate("BAG"), true)
    render.G.push()
    render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    THEME.hgss:bag(model)
    render.G.pop()
  end

  function displayRuntime.drawPokedex()
    local model = displayRuntime.pokedexModel()
    local title = model.view == "index" and THEME:translate("POKEDEX")
      or model.view == "profile" and THEME:format("NO.%03d",
        tonumber(model.pokemon and model.pokemon.dex) or 0)
      or model.view == "habitat" and THEME:format("HABITAT %d/%d",
        model.page or 1, model.pages or 1)
      or model.view == "moves" and THEME:format("MOVES %d/%d",
        model.page or 1, model.pages or 1)
      or model.view == "evolutions" and THEME:translate("EVOLUTION")
      or THEME:translate("STATS")
    header(title, true, model.canCycle)
    render.G.push()
    render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    THEME.hgss:pokedex(model)
    render.G.pop()
  end

  assert(compat.typeEffectiveness("FIRE", { "GRASS", "BUG" }, { matchups = {
    { attacker = "FIRE", defender = "GRASS", multiplier = 20 },
    { attacker = "FIRE", defender = "BUG", multiplier = 20 },
  } }) == 40, "type effectiveness preview")

end
