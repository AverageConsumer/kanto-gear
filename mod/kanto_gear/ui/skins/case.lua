-- Kanto Gear v4: DS-style lettering.
--
-- Gen 1/2 shout everything in capitals; the DS menus speak in title case and
-- keep capitals for headers, badges and abbreviations. Every Kanto Gear label
-- still travels as an all-caps key (that is what the language catalogs use),
-- so the case is changed where the text meets the font:
--   * a word that is entirely upper case becomes "Title" case;
--   * short connecting words ("of", "to", "und", "de" …) go lower case;
--   * abbreviations (HP, PP, TM, ID, PSS …) and letter+digit codes stay;
--   * words that already carry lower case (notes, nicknames, prose written
--     in sentence case) are left exactly as typed.
-- Header bars and type/status badges keep capitals on purpose, and long game
-- prose (Pokédex entries, battle text) stays as the cartridge prints it.
return function(H, ui, K)
  local unpack = table.unpack or unpack
  local base = {}
  for _, name in ipairs({ "partyInfo", "partyName", "partyInfoWidth", "fitPartyInfo",
      "splitPartyInfo", "fitLabel", "partyType", "fitPartyType", "partyInfoCentered", "headerBar" }) do
    base[name] = H[name]
  end

  local KEEP = {}
  for word in ([[HP PP TM HM ID OT EXP XP PKMN PKRS PSS PC OK BST DV DVS STAB EV IV KO NPC
      KP EP AP VM VS PV PS MO MT MS CT
      VS TV UI LCD GSC RBY SLS DS GB GBC GBA AM PM CPU USB]]):gmatch("%S+") do
    KEEP[word] = true
  end
  local MINOR = {}
  for word in ([[A AN THE OF ON IN AT TO AND OR FOR BY FROM AS INTO
      ZU ZUM ZUR UND ODER IM AM AN AUF FÜR VON VOM MIT DER DIE DAS DEM DES EIN EINE BEI NACH
      DE DU DES LA LE LES ET EN AU AUX POUR SUR UN UNE
      EL LOS LAS Y CON POR PARA AL DEL]]):gmatch("%S+") do
    MINOR[word] = true
  end
  local UNITS = { FT = "ft", IN = "in", LB = "lb", KG = "kg", CM = "cm", KM = "km" }
  -- Abbreviations that are also ordinary words elsewhere (German "AM",
  -- "MO" for Monday) stay capitals only beside a number or a slash:
  -- "9 AM", "MT / MO".
  local MARKED = { AM = true, PM = true, MO = true }

  local LOWER = { ["Ä"] = "ä", ["Ö"] = "ö", ["Ü"] = "ü", ["À"] = "à", ["Â"] = "â",
    ["Ç"] = "ç", ["Á"] = "á", ["È"] = "è", ["É"] = "é", ["Ê"] = "ê", ["Ë"] = "ë",
    ["Í"] = "í", ["Î"] = "î", ["Ï"] = "ï", ["Ó"] = "ó", ["Ô"] = "ô", ["Ú"] = "ú",
    ["Ù"] = "ù", ["Û"] = "û", ["Ÿ"] = "ÿ", ["Ñ"] = "ñ", ["Ì"] = "ì", ["Ò"] = "ò" }
  local UPPER_SET, LOWER_SET = {}, {}
  for up, low in pairs(LOWER) do UPPER_SET[up] = true; LOWER_SET[low] = true end
  LOWER_SET["é"] = nil -- POKéMON / POKéDEX spell é inside capitals

  local function chars(word)
    local list = {}
    for ch in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do list[#list + 1] = ch end
    return list
  end

  local function isLetter(ch)
    return ch:match("^%a$") ~= nil or UPPER_SET[ch] or LOWER_SET[ch] or ch == "é" or ch == "ß"
  end

  local function shouting(list)
    local letters = 0
    for _, ch in ipairs(list) do
      if ch:match("^%l$") or LOWER_SET[ch] then return false end
      if isLetter(ch) then letters = letters + 1 end
    end
    return letters > 0
  end

  local function lowerChar(ch)
    return LOWER[ch] or ch:lower()
  end

  -- One run of letters (apostrophes allowed inside: FARFETCH'D).
  local function caseRun(run, first, nearDigit, last, nearSlash)
    local list = chars(run)
    if not shouting(list) then return run end
    if KEEP[run] and not (MARKED[run] and not nearDigit and not nearSlash) then return run end
    if nearDigit and #list <= 2 then return run end
    if UNITS[run] and not first then return UNITS[run] end
    if MINOR[run] and not first and not last then
      local out = {}
      for i, ch in ipairs(list) do out[i] = lowerChar(ch) end
      return table.concat(out)
    end
    local out = { list[1] }
    for i = 2, #list do out[i] = lowerChar(list[i]) end
    return table.concat(out)
  end

  local cache, cached = {}, 0
  local function title(value)
    if type(value) ~= "string" then value = tostring(value or "") end
    if value == "" or not value:find("%u") then return value end
    local hit = cache[value]
    if hit then return hit end
    local list = chars(value)
    local out, run, first = {}, {}, true
    local before = ""
    local function flush(nextCh, at)
      if #run == 0 then return end
      local word = table.concat(run)
      local nearDigit = before:match("%d") or (nextCh and nextCh:match("^%d$"))
      local nearSlash = false
      local stop = at or #list + 1
      for j = stop - #run - 1, 1, -1 do
        if list[j] == "/" then nearSlash = true end
        if list[j] ~= " " then break end
      end
      for j = stop, #list do
        if list[j] == "/" then nearSlash = true end
        if list[j] ~= " " then break end
      end
      local last = true
      for j = (at or #list) + 1, #list do
        if isLetter(list[j]) then last = false; break end
      end
      out[#out + 1] = caseRun(word, first, nearDigit, last, nearSlash)
      first = false
      run = {}
    end
    for i, ch in ipairs(list) do
      if isLetter(ch) or ((ch == "'" or ch == "’") and #run > 0 and list[i + 1] and isLetter(list[i + 1])) then
        run[#run + 1] = ch
      else
        flush(ch, i)
        out[#out + 1] = ch
        before = ch
        -- a colon or a dash starts a fresh phrase ("Route 43 - Lake Gate")
        if ch == ":" or ch == "-" or ch == "/" then first = true
        elseif ch:match("^%d$") then first = false end
      end
    end
    flush(nil)
    local result = table.concat(out)
    if cached > 4096 then cache, cached = {}, 0 end
    cache[value], cached = result, cached + 1
    return result
  end
  H.v4Title = title

  -- Prose (Pokédex entries, move and item descriptions, help text) reads in
  -- sentence case across the lines of one block: only the first word of a
  -- sentence, proper nouns and abbreviations keep their capital.
  local PROPER = {}
  for word in ([[KANTO JOHTO HOENN SILPH LABS CO POKEMON POKéMON POKEDEX POKéDEX
      POKEGEAR POKéGEAR BILL BILL'S OAK ELM]]):gmatch("%S+") do
    PROPER[word] = true
  end
  -- type names are capitalised only as "Water-type"
  local TYPED = {}
  for word in ([[NORMAL FIRE WATER GRASS ELECTRIC ICE FIGHTING POISON GROUND FLYING
      PSYCHIC BUG ROCK GHOST DRAGON DARK STEEL FAIRY]]):gmatch("%S+") do
    TYPED[word] = true
  end
  local extra = {}
  local function sentence(value, atStart)
    local list = chars(value)
    local out, run = {}, {}
    local nextCh
    local function flush()
      if #run == 0 then return end
      local word = table.concat(run)
      local letters = chars(word)
      local prev = out[#out] == " " and out[#out - 1] or out[#out] or ""
      if not shouting(letters) or KEEP[word] and not (MARKED[word] and not tostring(prev):match("[%d/]$")) then
        out[#out + 1] = word
      elseif UNITS[word] then
        out[#out + 1] = UNITS[word]
      elseif PROPER[word] or extra[word] or atStart or (TYPED[word] and nextCh == "-") then
        out[#out + 1] = caseRun(word, true, false)
      else
        local low = {}
        for i, ch in ipairs(letters) do low[i] = lowerChar(ch) end
        out[#out + 1] = table.concat(low)
      end
      atStart = false
      run = {}
    end
    for i, ch in ipairs(list) do
      if isLetter(ch) or ((ch == "'" or ch == "’") and #run > 0 and list[i + 1] and isLetter(list[i + 1])) then
        run[#run + 1] = ch
      else
        nextCh = ch
        flush()
        out[#out + 1] = ch
        if ch == "." or ch == "!" or ch == "?" then atStart = true end
      end
    end
    nextCh = nil
    flush()
    return table.concat(out), atStart
  end
  H.v4Sentence = sentence

  -- Badges (types, status, pills) and header bars keep their capitals.
  local WHOLE = {}
  for word in ([[NOR FIR FIRE WAT WATER GRA GRASS ELE ELEC ELECT ELECTRIC ICE FIG FIGHT FIGHTING
      POI POISON GRO GROUND FLY FLYING PSY PSYCHIC BUG ROC GHO GHOST DRA DRAGON
      DAR DARK STE STEEL FAI FAIRY NORMAL PAR PSN SLP BRN FRZ FNT TOX OK EGG ???]]):gmatch("%S+") do
    WHOLE[word] = true
  end

  -- Words the player typed (notes, a name being entered) are shown exactly
  -- as typed; only Silph's own labels around them change case.
  local typed = nil
  local function isTyped(value)
    if not typed then return false end
    local bare = value:gsub("…$", "")
    if bare == "" then return false end
    for _, text in ipairs(typed) do
      if text:find(bare, 1, true) then return true end
    end
    return false
  end

  local mode, proseStart = nil, true
  local function shown(value, commit)
    if mode == "caps" or H.v4Lettering == "caps" then return value end
    if type(value) ~= "string" then value = tostring(value or "") end
    if typed and isTyped(value) then return value end
    if mode == "prose" then
      -- Sentence case needs the language's own rules (German nouns keep
      -- their capital), so outside English the message box keeps capitals.
      if ui.translate and ui.translate("BACK") ~= "BACK" then return value end
      local text, nextStart = sentence(value, proseStart)
      if commit then proseStart = nextStart end
      return text
    end
    if WHOLE[value] then return value end
    -- a whole question or sentence ("Use now?") reads in sentence case
    if value:find("[%.%?!]%s*$") and value:find("%s") and not value:find("%.%a")
        and not (ui.translate and ui.translate("BACK") ~= "BACK") then
      return (sentence(value, true))
    end
    return title(value)
  end
  local function scoped(kind, fn, names)
    local previous, previousStart, previousExtra = mode, proseStart, extra
    mode = kind
    if kind == "prose" then
      proseStart = true
      extra = {}
      -- names shown above a description (the TM's move, the item) keep
      -- their capitals inside it
      for _, name in ipairs(names or {}) do
        for word in tostring(name or ""):gmatch("[^%s%.,!?]+") do extra[word] = true end
      end
    end
    local ok, a = pcall(fn)
    mode, proseStart, extra = previous, previousStart, previousExtra
    if not ok then error(a, 0) end
    return a
  end
  function H:v4Caps(fn) return scoped("caps", fn) end
  -- The lettering a label would get, for callers that cut it up themselves.
  function H:v4Cased(value) return shown(value) end
  function H:v4Prose(fn, names) return scoped("prose", fn, names) end

  function H:partyInfo(value, ...) return base.partyInfo(self, shown(value, true), ...) end
  function H:partyName(value, ...) return base.partyName(self, shown(value, true), ...) end
  function H:partyType(value, ...) return base.partyType(self, shown(value, true), ...) end
  function H:partyInfoWidth(value, ...) return base.partyInfoWidth(self, shown(value), ...) end
  -- Fitting measures the lettering that will be drawn, but hands back the
  -- caller's own spelling (same glyph count) so callers that compare the
  -- result with their input, or draw it later, keep working.
  local function back(original, fitted)
    if fitted == nil then return nil end
    local shownText = shown(original)
    if fitted == shownText then return original end
    local o, f = chars(tostring(original or "")), chars(fitted)
    local ellipsis = f[#f] == "…"
    local keep = ellipsis and #f - 1 or #f
    -- a split half: find it inside the shown text and map it back by position
    local s = chars(shownText)
    local at = 1
    if not ellipsis then
      local joined = table.concat(f)
      for i = 1, #s - #f + 1 do
        if table.concat(s, "", i, i + #f - 1) == joined then at = i; break end
      end
    end
    return table.concat(o, "", at, at + keep - 1) .. (ellipsis and "…" or "")
  end
  function H:fitPartyInfo(value, ...)
    return back(value, base.fitPartyInfo(self, shown(value), ...))
  end
  function H:splitPartyInfo(value, ...)
    local a, b = base.splitPartyInfo(self, shown(value), ...)
    return back(value, a), back(value, b)
  end
  function H:fitPartyType(value, ...)
    return back(value, base.fitPartyType(self, shown(value), ...))
  end
  function H:fitLabel(value, ...) return back(value, base.fitLabel(self, shown(value), ...)) end
  function H:partyInfoCentered(value, ...) return base.partyInfoCentered(self, shown(value), ...) end
  local function capsWrap(name)
    local fn = H[name]
    if not fn then return end
    H[name] = function(self, ...)
      local n, args = select("#", ...), { ... }
      local results
      scoped("caps", function() results = { fn(self, unpack(args, 1, n)) } end)
      return unpack(results)
    end
  end
  -- header bars, pills and badges keep capitals; so does the name entry,
  -- whose letters are the game's own
  for _, name in ipairs({ "headerBar", "v4Pill", "storeNewBadge", "naming" }) do capsWrap(name) end

  local USER_KEYS = { title = true, text = true, draft = true }
  local function collect(list, value, depth, seen)
    if depth > 4 or seen[value] then return end
    seen[value] = true
    for key, item in pairs(value) do
      local kind = type(item)
      if kind == "string" and USER_KEYS[key] and item ~= "" then
        list[#list + 1] = item
      elseif kind == "table" and key ~= "colors" and key ~= "hits" and key ~= "undo"
          and key ~= "ctx" and key ~= "symbols" then
        collect(list, item, depth + 1, seen)
      end
    end
  end
  local function typedWrap(name)
    local fn = H[name]
    if not fn then return end
    H[name] = function(self, state, ...)
      local previous = typed
      local list = {}
      if type(state) == "table" then collect(list, state, 1, {}) end
      typed = list
      local n, args = select("#", ...), { ... }
      local ok, a, b, c = pcall(fn, self, state, unpack(args, 1, n))
      typed = previous
      if not ok then error(a, 0) end
      return a, b, c
    end
  end
  -- Notes installs its renderer after the theme extensions have loaded.
  H.v4WrapTyped = typedWrap
  for _, name in ipairs({ "notes", "v4NotesList", "v4NoteHeader" }) do typedWrap(name) end
end
