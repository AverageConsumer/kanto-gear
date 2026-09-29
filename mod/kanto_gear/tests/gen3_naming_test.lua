-- Exercise touch targets through the native naming handler, including the
-- extracted Emerald layout and the older FRLG keyboard fallback.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, game)
  local Stack = require("src.ui.game3.stack")
  local Naming = require("src.ui.game3.naming")
  local load = love.filesystem.load
  love.filesystem.load = function(file)
    if file == "data/generated/gba/naming/manifest.lua" then
      return loadfile(os.getenv("POKEPORT_GBA_CACHE") .. "/naming/manifest.lua")
    end
    return load(file)
  end
  Stack.clear()
  local function press(key)
    Naming.handleInput({ wasPressed = function(_, k) return k == key end })
  end
  local function settle()
    for _ = 1, 32 do Naming.update(1 / 60) end
  end
  for page = 1, 3 do
    local result
    local state = Naming.open({ title = "NAME", maxLen = 7, session = game.session,
      onDone = function(value) result = value end })
    for _ = 2, page do press("select"); settle() end
    local menu = assert(display.startMenu())
    if os.getenv("POKEPORT_VERSION") == "emerald" then
      T.check(state.pages ~= nil, "Emerald native keyboard loaded")
      local count = 3
      for row, chars in ipairs(state.pages[page].rows) do
        count = count + #chars
        for col, char in ipairs(chars) do
          local found
          for _, entry in ipairs(menu.items) do
            if entry.row == row and entry.col == col then found = entry.label end
          end
          T.eq(found, char == " " and "_" or char, "every native keyboard cell is mirrored")
        end
      end
      T.eq(#menu.items, count, "native keyboard cell count")
    end
    for i, entry in ipairs(menu.items) do
      local r = entry.rect
      T.eq(display.StartMenu.hit(menu, r[1] + r[3] / 2, r[2] + r[4] / 2), i,
        "touch hits the displayed key")
      state.name = "TEST"
      T.check(display.StartMenu.select(menu, i), "key selectable")
      T.eq(menu.index, i, "native focus matches selected key")
      if entry.row then
        state.name = ""
        press("a")
        T.eq(state.name, entry.label == "_" and " " or entry.label, "native character matches label")
      elseif entry.btn == 1 then
        press("a")
        T.eq(state.swapTo, page % 3 + 1, "page button selects next alphabet")
        T.eq(state.name, "TEST", "page button does not type a character")
        T.check(not display.StartMenu.select(menu, i), "touch locked during native page animation")
        settle()
        T.check(not display.StartMenu.select(menu, i), "old page rejects stale touch")
        -- Return through native page cycling to exercise BACK and OK on this page.
        press("select"); settle(); press("select"); settle()
        menu = assert(display.startMenu())
      elseif entry.btn == 2 then
        press("a")
        T.eq(state.name, "TES", "BACK deletes exactly one character")
      elseif entry.btn == 3 then
        press("a")
        T.eq(result, "TEST", "OK confirms the name")
        T.check(not display.StartMenu.select(menu, i), "closed naming rejects stale touch")
      end
    end
    Naming.dismiss(); Stack.clear()
  end
  love.filesystem.load = load
end
dofile(path .. (os.getenv("POKEPORT_VERSION") == "emerald"
  and "/tests/emerald_runtime_test.lua" or "/tests/gen3_runtime_test.lua"))
