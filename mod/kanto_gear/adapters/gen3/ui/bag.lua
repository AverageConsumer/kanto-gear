return function(UI)
  function UI:selectBagAction(native, index)
    native.actionCursor = index
    -- Game path [Ruby/Sapphire vs Emerald]: RS stores a sparse grid position on the bag; Emerald stores a zero-based cursor in _st.
    if self.adapter.rs then
      local skin = require("src.ui.game3.rs.bag_menu")
      local count = 0
      for i, cell in ipairs(skin.grid(native, native.list()[native.cursor]).cells) do
        if cell then count = count + 1 end
        if cell and count == index then
          native._rsBag.gridPos = i
          native._rsBag.lastMode = "action"
          break
        end
      end
    elseif self.adapter.hoenn then
      local st = require("src.ui.game3.rse.bag_menu")._st
      for i, cell in ipairs(st.grid and st.grid.cells or {}) do
        if cell and cell.idx == index then st.gridPos = i - 1; break end
      end
    end
  end
  function UI:bagActions(id)
    local a = self.adapter
    local def = a.data.items[id]
    if not def then return {} end
    local pocket, info = def.nativePocket, a.Items.info(id) or {}
    if pocket == "KEY_ITEMS" then
      local actions = { "USE" }
      if (tonumber(info.registrability) or 0) > 0 then actions[#actions + 1] = "SET" end
      return actions
    elseif pocket == "POKE_BALLS" then return { "GIVE", "TOSS" }
    -- Game path [Gen 3]: RS allows giving ordinary TMs; the other supported host paths only teach, and HMs remain non-giveable.
    elseif pocket == "TM_CASE" then
      if a.rs and not a.Items.isHm(id) then return { "USE", "GIVE" } end
      -- The host currently supports teaching here; its GIVE path refuses TMs/HMs.
      return { "USE" }
    -- Game path [Ruby/Sapphire/Emerald]: berries expose CHECK_TAG for contests; FireRed/LeafGreen uses its separate Berry Pouch.
    elseif pocket == "BERRY_POUCH" and a.hoenn then
      return { "CHECK_TAG", "USE", "GIVE", "TOSS" }
    end
    return { "USE", "GIVE", "TOSS" }
  end
  function UI:openBagItem(id, action)
    local a, session = self.adapter, self.adapter.session
    if not session or not a.save or (a.save.inventory[id] or 0) <= 0
        or self.Stack.top() or self.Message.isOpen() or self.Choice.active then return false end
    local def = a.data.items[id]
    local pocket = def and def.nativePocket
    local menu
    -- Game path [FireRed/LeafGreen]: TM Case and Berry Pouch are separate native menus; Hoenn keeps these items in bag pockets.
    if pocket == "TM_CASE" and not a.hoenn then
      menu = require("src.ui.game3.tm_case")
      menu.show(session, session.bag)
    elseif pocket == "BERRY_POUCH" and not a.hoenn then
      menu = require("src.ui.game3.berry_pouch")
      menu.show(session, session.bag)
    else
      menu = require("src.ui.game3.bag_menu")
      menu.show(session.bag, { session = session, pocket = pocket })
    end
    for i, row in ipairs(menu.list()) do
      if row.id == id then
        menu.cursor, menu.scroll = i, math.max(0, i - 1)
        if not action then return true end
        -- One explicit companion action enters the native item action directly.
        -- Native handlers still own party/mail, quantity, confirmation and effects.
        if menu.settle then menu.settle() end
        local confirm = { wasPressed = function(_, key) return key == "a" end,
          isDown = function() return false end }
        menu.handleInput(confirm)
        -- The host refreshes pocket-specific ACTIONS on the first action tick.
        menu.handleInput({ wasPressed = function() return false end, isDown = function() return false end })
        local actions = menu.ACTIONS or (pocket == "TM_CASE" and { "USE", "GIVE", "EXIT" }
          or { "USE", "GIVE", "TOSS", "EXIT" })
        if menu.mode == "action" then
          for index, name in ipairs(actions) do
            if name == action then
              self:selectBagAction(menu, index)
              menu.handleInput(confirm)
              return true
            end
          end
        end
        menu.close()
        return false
      end
    end
    menu.close()
    return false
  end
end
