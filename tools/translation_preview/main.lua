-- Offscreen checks against an unpacked, generated translation package.
local root = assert(os.getenv("KANTO_GEAR_ROOT"))
local pack = assert(os.getenv("KANTO_TRANSLATION_MOD"))
local output = assert(os.getenv("KANTO_TRANSLATION_OUT"))
local utf8 = require("utf8")
local function read(path)
  local f = assert(io.open(path, "rb")); local bytes = f:read("*a"); f:close(); return bytes
end
local function write(path, bytes)
  local f = assert(io.open(path, "wb")); f:write(bytes); f:close()
end
function love.errorhandler(message)
  write(output .. "/error.txt", debug.traceback(tostring(message), 2))
  love.event.quit(1); return function() return 1 end
end
local function glyphs(value)
  local out = {}; for _, c in utf8.codes(value) do out[#out + 1] = utf8.char(c) end; return out
end
function love.load()
  local G = love.graphics
  local fontGlyphs = assert(loadfile(root .. "/mod/kanto_gear/hgss_font_glyphs.lua"))()
  local function imageFont(name)
    local data = love.filesystem.newFileData(read(root .. "/mod/kanto_gear/" .. name), name)
    local font = G.newImageFont(love.image.newImageData(data), fontGlyphs)
    font:setFilter("nearest", "nearest"); return font
  end
  local Fonts = assert(loadfile(root .. "/mod/kanto_gear/translation_fonts.lua"))()
  local fonts = Fonts.new(setmetatable({ newFont = function(path, ...)
    return G.newFont(love.filesystem.newFileData(read(path), path), ...)
  end }, { __index = G }), error)
  local source = read(pack .. "/main.lua")
  local file, size = source:match('mod.content.font:register%("ttf", { file = mod.assets:path%("([^"]+)"%), size = (%d+)')
  assert(file and size, "generated package declares its font")
  fonts:bind({ file = pack .. "/" .. file, size = tonumber(size) })
  local base, small, large = imageFont("hgss_font.png"), imageFont("hgss_small_font.png"), imageFont("hgss_large_font.png")
  assert(fonts:select(base, "Lestat") == base, "Latin nickname keeps its original font")
  local H = assert(loadfile(root .. "/mod/kanto_gear/hgss.lua"))()({
    graphics = G, font = base, smallFont = small, largeFont = large,
    bagIcon = G.newImage(love.filesystem.newFileData(read(root .. "/mod/kanto_gear/kanto_bag.png"), "bag.png")),
    translationFonts = fonts, glyphs = glyphs,
    color = function(c) G.setColor(c) end,
    box = function(mode, x, y, w, h, c) G.setColor(c); G.rectangle(mode, x, y, w, h) end,
  })
  local catalogs = {}
  for _, name in ipairs({ "species_names", "item_names", "move_names", "landmarks",
      "species_kinds", "trainer_names", "trainer_class_names", "type_names", "status_labels",
      "crystal_item_names", "crystal_landmarks", "crystal_trainer_class_names" }) do
    local chunk = loadfile(pack .. "/lang/" .. name .. ".lua")
    catalogs[name] = chunk and chunk() or {}
  end
  local canvas = G.newCanvas(240, 216, { dpiscale = 1 }); canvas:setFilter("nearest", "nearest")
  -- Exercise the real bitmap helpers as well: locations pass through these
  -- before reaching HGSS, and classic themes use their drawing path directly.
  local main = read(root .. "/mod/kanto_gear/main.lua")
  local helpers = assert(main:match('(local FONT = {.-)local function outline'))
  local legacyTheme = {}
  local legacy = assert(loadstring('local G, THEME, WIDTH = ...\n' .. helpers
    .. '\nreturn {text=text, centered=centered, fit=fit, clean=clean}'))(G, legacyTheme, 160)
  legacyTheme.translationFonts = fonts
  legacyTheme.style, legacyTheme.hgss = "hgss", H
  local translatedName = assert(catalogs.species_names.PIKACHU)
  assert(legacy.clean(translatedName) ~= "", "bitmap normalization preserves translated names")
  local fitted = legacy.fit(string.rep(translatedName, 12), 22)
  assert(legacyTheme:textWidth(fitted) <= 132, "bitmap truncation uses translation font width")
  G.setCanvas(canvas)
  local checked, fallback, maxWidth, geometry, descriptions = 0, 0, 0, 0, 0
  local originalPrint, printLimit = G.print, 58
  G.print = function(value, ...)
    local font = G.getFont()
    assert(font:hasGlyphs(value), "missing glyph in " .. value)
    assert(font:getWidth(value) <= printLimit, "text exceeds field width: " .. value)
    maxWidth = math.max(maxWidth, font:getWidth(value))
    return originalPrint(value, ...)
  end
  for _, catalog in pairs(catalogs) do for _, value in pairs(catalog) do
    if type(value) == "string" and value ~= "" then
      value = value:gsub("<PK><MN>", "PKMN")
      local font = fonts:select(base, value)
      assert(font:hasGlyphs(value), "package font does not cover " .. value)
      if font ~= base then fallback = fallback + 1 end
      H:partyName(value, 0, 0, H.colors.ink, 58)
      for _, width in ipairs({ 23, 40, 58, 61, 67, 96, 140, 196, 210 }) do
        for _, face in ipairs({
          { font = base, fit = function(v) return H:fitLabel(v, width) end },
          { font = small, fit = function(v) return H:fitPartyInfo(v, width) end },
          { font = small, fit = function(v) return H:fitPartyType(v, width) end },
        }) do
          local fitted = face.fit(value)
          local selected = fonts:select(face.font, fitted)
          assert(selected:hasGlyphs(fitted), "fitting produces an unsupported glyph")
          assert(selected:getWidth(fitted) <= width, "fitted text exceeds field width: " .. value)
          geometry = geometry + 1
        end
      end
      checked = checked + 1
    end
  end end
  printLimit = 20
  local badges = next(catalogs.type_names or {}) and catalogs.type_names or { NORMAL = translatedName }
  for id, label in pairs(badges) do
    H:typeBadges({ type = id, type2 = id == "FIRE" and "NORMAL" or "FIRE", typeLabel = label, type2Label = label }, 0, 0, false)
  end
  G.print = originalPrint
  local function compact(value) return value:gsub("%s", ""):gsub("　", "") end
  local longest = ""
  for _, catalog in ipairs({ "species_dex_text", "species_dex_text2", "species_dex_text_silver",
      "species_dex_text2_silver", "species_dex_text_crystal", "species_dex_text2_crystal",
      "dialogue", "dialogue_yellow" }) do
    local chunk = loadfile(pack .. "/lang/" .. catalog .. ".lua")
    for key, source in pairs(chunk and chunk() or {}) do
      if type(source) == "string" and source ~= ""
          and (not catalog:find("dialogue") or key:find("DexEntry")) then
        local normalized = legacy.clean(source:gsub("<PK><MN>", "PKMN"):gsub("<[^>]+>", " "):gsub("[\r\n@]+", " "))
        if #glyphs(normalized) > #glyphs(longest) then longest = normalized end
        for _, budget in ipairs({ {126,2}, {196,2}, {200,3}, {206,6}, {210,3} }) do
          local measure = function(v) return H:partyInfoWidth(v) end
          local lines = legacyTheme:wrapText(normalized, budget[1], nil, measure)
          assert(compact(table.concat(lines)) == compact(normalized), "description loses text during wrapping")
          for _, line in ipairs(lines) do
            assert(measure(line) <= budget[1], "description exceeds field width")
            assert(select(1, fonts:select(small, line)):hasGlyphs(line), "description has a missing glyph")
          end
          local bounded = legacyTheme:wrapText(normalized, budget[1], budget[2], measure)
          assert(#bounded <= budget[2], "description exceeds its line count")
          if #lines > budget[2] then assert(bounded[#bounded]:sub(-1) == ".", "overflow is not indicated") end
          descriptions = descriptions + 1
        end
      end
    end
  end
  local Notes = assert(loadfile(root .. "/mod/kanto_gear/notes.lua"))()
  local notes = Notes.new({ measure = function(v) return H:partyInfoWidth(v) end })
  for _, value in ipairs({ "Lestat / " .. translatedName, string.rep("W", 20) .. translatedName,
      translatedName .. string.rep("i", 60), string.rep(translatedName, 15) }) do
    for _, width in ipairs({ 40, 100, 210 }) do
      local rows, joined = notes:wrapped(value, width), {}
      for _, row in ipairs(rows) do
        assert(H:partyInfoWidth(row.text) <= width, "mixed-script Notes row exceeds width")
        joined[#joined + 1] = row.text
        local font = fonts:select(small, row.text)
        local prefix = table.concat(glyphs(row.text), "", 1, math.floor(#glyphs(row.text) / 2))
        assert(H:partyInfoWidth(prefix, row.text) == font:getWidth(prefix), "caret measures a different font")
      end
      assert(table.concat(joined) == value, "Notes wrapping loses text")
    end
  end
  local names = catalogs.species_names
  local party = {}
  local partyTypes = { {"GHOST", "POISON"}, {"FIRE"}, {"GRASS", "POISON"},
    {"NORMAL", "FLYING"}, {"POISON", "FLYING"}, {"PSYCHIC_TYPE"} }
  for i, id in ipairs({ "GASTLY", "CHARMANDER", "BULBASAUR", "PIDGEY", "ZUBAT", "ABRA" }) do
    local first, second = partyTypes[i][1], partyTypes[i][2] or partyTypes[i][1]
    party[i] = { name = i == 5 and "Lestat" or names[id] or id, hp = 21, maxHp = 30,
      levelText = "L16", hpText = "21/30", type = first, type2 = second,
      typeLabel = catalogs.type_names[first], type2Label = catalogs.type_names[second], expProgress = 0.4 }
  end
  local entries = {}
  for i, id in ipairs({ "POTION", "ANTIDOTE", "FULL_HEAL", "SUPER_POTION", "PARLYZ_HEAL", "POKE_BALL" }) do
    entries[i] = { label = catalogs.item_names[id] or id, count = i, icon = "medicine" }
  end
  local enlarged = G.newCanvas(960, 864, { dpiscale = 1 })
  for _, dark in ipairs({ false, true }) do for _, screen in ipairs({ "party", "bag", "text", "classic", "description" }) do
    H:setVariant(dark)
    G.setCanvas(canvas); G.origin(); G.clear(); G.scale(1.5); H:backdrop(); G.origin()
    H:headerBar(screen == "party" and "PARTY" or screen == "bag" and "BAG" or "TEXT", true, false)
    if screen == "classic" then
      G.clear(H.colors.surface); G.scale(1.5)
      legacy.centered(translatedName, 28, H.colors.ink)
      legacy.centered(legacy.fit(string.rep(translatedName, 5), 22), 48, H.colors.ink)
      legacy.centered("POKé BALL", 68, H.colors.ink)
    elseif screen == "party" then
      for i, mon in ipairs(party) do local x, y = H:partyPosition(i)
        H:partyCard(mon, x, y, i == 1, false, function() end)
      end
    elseif screen == "bag" then H:bagOverview({ entries = entries, page = 1, pages = 3 })
    elseif screen == "description" then
      local measure = function(v) return H:partyInfoWidth(v) end
      local mon = { name = translatedName, description = legacyTheme:wrapText(longest, 206, 6, measure),
        weight = "WEIGHT 100 KG", height = "HEIGHT 1 M", type = "NORMAL", kind = "POKEMON" }
      H:enemyInfoProfile({ pokemon = mon })
    else
      for i, value in ipairs({ names.PIKACHU or "PIKACHU", catalogs.item_names.POTION or "POTION",
          catalogs.move_names.THUNDERBOLT or "THUNDERBOLT", (names.PIKACHU or "PIKACHU") .. " / Lestat" }) do
        H:panel(10, 35 + (i - 1) * 42, 220, 36, false)
        H:partyInfo(H:fitPartyInfo(value, 208), 16, 45 + (i - 1) * 42, H.colors.ink, 208, "center")
      end
    end
    G.setCanvas(enlarged); G.origin(); G.clear(); G.setColor(1, 1, 1, 1); G.draw(canvas, 0, 0, 0, 4, 4)
    G.setCanvas()
    local pixels = enlarged:newImageData()
    write(output .. "/" .. (dark and "dark" or "light") .. "-" .. screen .. ".png", pixels:encode("png"):getString())
    pixels:release()
  end end
  write(output .. "/checks.txt", string.format("%d translated labels; %d use translation font; max fitted width %d/58 px\n%d field/font width checks; %d description/field cases; 12 mixed-script Notes cases\n",
    checked, fallback, maxWidth, geometry, descriptions))
  love.event.quit(0)
end
