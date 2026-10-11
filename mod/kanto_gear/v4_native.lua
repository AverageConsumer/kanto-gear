-- Kanto Gear v4: native menu companions — start menu with real icons,
-- choice prompts as Gen 4 touch buttons. Loaded after v4_menus.
return function(H, ui, K)
  local floor, max, min = math.floor, math.max, math.min
  local R, P, RR, RRrows, CH, CHrows = K.R, K.P, K.RR, K.RRrows, K.CH, K.CHrows
  local CIRC, RING, ART = K.CIRC, K.RING, K.ART
  local mix, hex = K.mix, K.hex
  local cg, WHITE = K.cg, K.WHITE
  local translate = function(value) return ui.translate and ui.translate(value) or value end

  ---------------------------------------------------------------------------
  -- Start menu icons (≤ 15×13, o = outline)
  ---------------------------------------------------------------------------
  local ICONS = {
    pokedex = { art = {
      ".ooooooooooo.", "o###########o", "o#wwwwwwwww#o", "o#wbbbbbbbw#o", "o#wbbbbbbbw#o",
      "o#wwwwwwwww#o", "o###########o", "o#oo###ooo#o.", "o###########o", ".ooooooooooo." },
      pal = { ["#"] = "e04838", w = "f8f8f8", b = "58b8e8" }, tint = "e04838" },
    pokemon = { ball = true, tint = "e85848" },
    pack = { art = {
      "....ooooo....", "...o.....o...", ".ooooooooooo.", "o###########o", "o#ooooooooo#o",
      "o#o#######o#o", "o#ooooooooo#o", "o###########o", "o###########o", ".ooooooooooo." },
      pal = { ["#"] = "e8a030", }, tint = "e8a030" },
    pokegear = { art = {
      ".ooooooooo.", "o#########o", "o#wwwwwww#o", "o#wgggggw#o", "o#wgggggw#o", "o#wwwwwww#o",
      "o#########o", "o#o#o#o#o#o", "o#########o", ".ooooooooo." },
      pal = { ["#"] = "38a8a0", w = "f8f8f8", g = "88d8a8" }, tint = "38a8a0" },
    status = { art = {
      "ooooooooooooo", "o###########o", "o#ss#wwwwww#o", "o#ss#######o.", "o####wwww##o.",
      "o#ss#######o.", "o###########o", "ooooooooooooo" },
      pal = { ["#"] = "4878d0", s = "f8c8a0", w = "f8f8f8" }, tint = "4878d0" },
    save = { art = {
      "ooooooooooo", "o##wwwww##o", "o##wwwww##o", "o##wwwww##o", "o#########o", "o##ooooo##o",
      "o##o###o##o", "o##ooooo##o", "ooooooooooo" },
      pal = { ["#"] = "48a858", w = "f8f8f8" }, tint = "48a858" },
    option = { art = {
      "...o.o.o...", "..o#o#o#o..", ".o#######o.", "o###ooo###o", ".o##o.o##o.", "o###ooo###o",
      ".o#######o.", "..o#o#o#o..", "...o.o.o..." },
      pal = { ["#"] = "8890a0" }, tint = "8090a8" },
    mods = { art = {
      "..ooo......", ".o###o.....", "o#####ooo..", "o#########o", ".o########o", "..o#######o",
      ".o#######o.", "o#######o..", ".ooooooo..." },
      pal = { ["#"] = "a868c8" }, tint = "a868c8" },
    quit = { art = {
      "ooooooo....", "o#####o....", "o#####o..o.", "o###w#oooo#", "o#####o..o.", "o#####o....",
      "o#####o....", "ooooooo...." },
      pal = { ["#"] = "c87858", w = "f8e8a0" }, tint = "a07060" },
    map = { art = {
      "oooooooooooo", "o##ww##ww##o", "o#ww##ww##wo", "o##ww#r#ww#o", "o#ww##ww##wo", "oooooooooooo" },
      pal = { ["#"] = "68b858", w = "88c8e8", r = "e04838" }, tint = "58a858" },
  }
  local ALIAS = {
    ["POKéDEX"] = "pokedex", POKEDEX = "pokedex", ["POKéMON"] = "pokemon", POKEMON = "pokemon",
    PACK = "pack", BAG = "pack", ITEM = "pack", ITEMS = "pack", ["POKéGEAR"] = "pokegear",
    POKEGEAR = "pokegear", ["POKéNAV"] = "pokegear", POKENAV = "pokegear", SAVE = "save",
    REPORT = "save", OPTION = "option", OPTIONS = "option", MODS = "mods", QUIT = "quit",
    EXIT = "quit", RETIRE = "quit", quitContest = "quit", trainer = "status", card = "status",
  }
  local function iconFor(entry)
    local kind = entry.kind and tostring(entry.kind)
    if kind and ICONS[kind] then return kind end
    if kind and ALIAS[kind] then return ALIAS[kind] end
    local label = tostring(entry.label or ""):upper()
    if ALIAS[label] then return ALIAS[label] end
    return nil
  end
  K.startIconFor = iconFor

  function H:v4StartIcon(kind, cx, cy)
    local icon = ICONS[kind]
    if not icon then
      local c = self.colors
      CIRC(cx - 4, cy - 4, 9, c.outline); CIRC(cx - 3, cy - 3, 7, c.silver)
      return
    end
    if icon.ball then self:battleTeamBall(cx, cy, "ready"); return end
    local pal = { o = self.colors.outline }
    for k, v in pairs(icon.pal) do pal[k] = hex(v) end
    local w, h = #icon.art[1], #icon.art
    ART(icon.art, cx - floor(w / 2), cy - floor(h / 2), pal)
  end

  ---------------------------------------------------------------------------
  -- Start menu: lipped keys; focused key fills with the item's colour.
  ---------------------------------------------------------------------------
  local function entryKey(entries, extra)
    local parts = { tostring(extra or "") }
    for i, e in ipairs(entries or {}) do parts[#parts + 1] = tostring(e.label) end
    return table.concat(parts, "|")
  end

  function H:startMenu(model)
    local c = self.colors
    local G = ui.graphics
    -- a freshly opened menu deals its keys in from the side, top to bottom
    local enter = self:v4Enter("start_menu", entryKey(model.entries, model.page), 0.24)
    for index, entry in ipairs(model.entries) do
      local _, dx = self:v4Stagger(enter, index, 0.07, 16, #model.entries)
      if dx ~= 0 then G.push(); G.translate(dx, 0) end
      local x, y, w, h = entry.x, entry.y, entry.w, entry.h
      local pressed = self:beginPress(x, y, w, h, not entry.disabled)
      local focused = self.nativeFocus and entry.selected
      local target = entry.targetSide and (entry.targetSide == "player" and c.blue or c.red)
      local kind = not entry.itemSprite and iconFor(entry)
      local tint = target or (kind and hex(ICONS[kind].tint)) or self.tok.acc.M
      local disabled = entry.disabled
      if focused and not disabled then
        local a = K.rampOf(tint)
        self:v4Button(x, y, w, h, a, { radius = 5, lip = 3, chamfer = 5 })
      else
        self:v4Key(x, y, w, h, disabled and { cap = c.bandLight, lip = c.band, hi = c.bandLight } or nil)
      end
      -- icon badge
      local d = min(h - 6, 22)
      local sx, sy = x + 6, y + floor((h - 2 - d) / 2)
      CIRC(sx, sy, d, c.outline)
      CIRC(sx + 1, sy + 1, d - 2, focused and WHITE or mix(c.surface, tint, self.dark and 0.32 or 0.2))
      local cx, cy = sx + floor(d / 2), sy + floor(d / 2)
      if entry.itemSprite then
        self:battleItemIcon(entry, sx + floor((d - 17) / 2), sy + floor((d - 17) / 2), c.amberLight)
      elseif kind then
        self:v4StartIcon(kind, cx, cy)
      else
        self:startMenuIcon(entry.kind, sx + floor((d - 15) / 2), sy + floor((d - 15) / 2))
      end
      local ink = focused and not disabled and WHITE or disabled and c.mutedInk or c.ink
      local reserved = target and 94 or entry.right and 78 or 0
      local label = self:fitPartyInfo(entry.label, w - 46 - reserved)
      self:partyInfo(label, x + 36, y + floor((h - 2 - 9) / 2) - 1, ink)
      if target then
        local bx, by, bw, bh = x + w - 94, y + 5, 86, h - 12
        local fill = mix(c.surface, target, self.dark and 0.32 or 0.2)
        if cg(self) then CH(bx, by, bw, bh, 3, target); CH(bx + 1, by + 1, bw - 2, bh - 2, 2, fill)
        else RR(bx, by, bw, bh, 3, target); RR(bx + 1, by + 1, bw - 2, bh - 2, 2, fill) end
        self:partyInfoCentered(self:fitPartyInfo(translate(entry.right), bw - 8), bx, by, bw, bh, c.ink)
      elseif entry.right then
        local right = self:fitPartyInfo(entry.right, 72)
        self:partyInfo(right, x + w - 10 - self:partyInfoWidth(right), y + floor((h - 2 - 9) / 2) - 1, ink)
      elseif focused and not disabled then
        local b = floor(self:clock() / 0.3) % 2
        self:wantAmbient(0.3)
        ART(K.CHEV_R, x + w - 14 + b, y + floor((h - 2 - 5) / 2), { ["#"] = WHITE })
      end
      self:endPress(pressed)
      if dx ~= 0 then G.pop() end
    end
    if not model.fixedLayout and model.total > (model.visible or 5) then self:menuPager(model) end
  end

  ---------------------------------------------------------------------------
  -- Choice prompt: textbox + big touch buttons (YES/NO style)
  ---------------------------------------------------------------------------
  local POSITIVE = { YES = true, JA = true, ["SÍ"] = true, OUI = true, ["はい"] = true, OK = true }
  local NEGATIVE = { NO = true, NEIN = true, NON = true, ["いいえ"] = true, CANCEL = true, ["ABBRECHEN"] = true }

  function H:choiceScreen(model)
    local colors = self.colors
    if #(model.prompt or {}) > 0 then
      self:v4MessageWindow(7, 34, 226, 46)
      local lines = model.nudge and { translate("PAUSE THEN CHOOSE") } or model.prompt
      local firstY = 34 + floor((46 - (9 + (#lines - 1) * 12)) / 2) - 1
      -- the game is talking: its words keep the cartridge's capitals
      self:v4Caps(function()
        for index, line in ipairs(lines) do
          self:partyInfo(self:fitPartyInfo(line, 200), 15, firstY + (index - 1) * 12,
            model.nudge and colors.amber or colors.ink, 210, "center")
        end
      end)
    end
    local G = ui.graphics
    local enter = self:v4Enter("choice", entryKey(model.entries, table.concat(model.prompt or {}, " ")), 0.24)
    for index, entry in ipairs(model.entries or {}) do
      local _, dy = self:v4Stagger(enter, index, 0.08, 10, #(model.entries or {}))
      if dy ~= 0 then G.push(); G.translate(0, dy) end
      local x, y, w, h = entry.x, entry.y, entry.w, entry.h
      local pressed = self:beginPress(x, y, w, h)
      local focused = self.nativeFocus and entry.selected
      local label = tostring(entry.label or ""):upper()
      local tone = POSITIVE[label] and (cg(self) and hex("1ea5d8") or hex("3ea04c"))
        or NEGATIVE[label] and hex("5a6c88") or self.tok.acc.M
      if focused then
        self:v4Button(x, y, w, h, K.rampOf(tone), { radius = 6, lip = 4, chamfer = 6 })
      else
        self:v4Key(x, y, w, h)
      end
      local ink = focused and WHITE or colors.ink
      local glyph = POSITIVE[label] and { "......#", ".....##", "#...##.", "##.##..", ".###...", "..#...." }
        or NEGATIVE[label] and { "#...#", ".#.#.", "..#..", ".#.#.", "#...#" } or nil
      local text = self:fitPartyInfo(entry.label, w - 44)
      if glyph then
        local gw = #glyph[1] + 5
        local tw = self:partyInfoWidth(text)
        local gx = x + floor((w - gw - tw) / 2)
        ART(glyph, gx, y + floor((h - 3 - #glyph) / 2), { ["#"] = focused and WHITE or tone })
        self:partyInfo(text, gx + gw, y + floor((h - 3 - 9) / 2) - 1, ink)
      else
        self:partyInfo(text, x + 16, y + floor((h - 3 - 9) / 2) - 1, ink, w - 32, "center")
      end
      if focused then
        local b = floor(self:clock() / 0.3) % 2
        self:wantAmbient(0.3)
        ART(K.CHEV_R, x + 9 + b, y + floor((h - 3 - 5) / 2), { ["#"] = WHITE })
      end
      self:endPress(pressed)
      if dy ~= 0 then G.pop() end
    end
    if model.pages and model.pages > 1 then self:menuPager(model) end
  end

  ---------------------------------------------------------------------------
  -- Move selection / learning (move_page.lua geometry)
  ---------------------------------------------------------------------------
  local function newBadge(self, x, y, label)
    local t = self:clock()
    local c = hex("f0a020")
    local w = self:v4Pill(label or "NEW", x, y, c, { raw = label ~= nil })
    if self.motionEnabled ~= false and floor(t / 0.4) % 2 == 0 then
      local sx = x + w - 1
      P(sx, y - 2, WHITE); R(sx - 1, y - 1, 3, 1, WHITE); P(sx, y, WHITE)
    end
    self:wantAmbient(0.4)
  end

  function H:v4MovePage(model, Page)
    local c = self.colors
    if model.message then
      self:v4MessageWindow(6, 33, 228, 34)
      local first, second = self:splitPartyInfo(model.message:gsub("\n", " "), 206)
      self:partyInfoCentered(first, 14, second and 36 or 33, 212, second and 13 or 34, c.ink)
      if second then self:partyInfoCentered(second, 14, 49, 212, 13, c.ink) end
    elseif model.newMove then
      self:summaryMoveRow(model.newMove, 6, 33, false, model.enabled ~= false and model.details == true, model.details == true)
      newBadge(self, 3, 29, model.newLabel)
    else
      local paged = model.pages and model.pages > 1
      self:v4Window(6, 33, 228, 34)
      if not paged then
        -- seat with what this move list is for (PP item, or a generic move mark)
        CIRC(11, 36, 28, c.outline)
        CIRC(12, 37, 26, mix(c.surface, hex("48a8e8"), self.dark and 0.3 or 0.2))
        self:v4ItemInSeat({ icon = "medicine", label = "ETHER" }, 28, 50, 28, hex("48a8e8"))
      end
      local left, width = paged and 36 or 40, paged and 168 or 188
      self:partyInfoCentered(self:fitPartyInfo(model.name or "", width), left, 36, width, 13, c.ink)
      local sub = paged and model.page .. "/" .. model.pages or model.prompt or ""
      self:partyInfoCentered(self:fitPartyInfo(sub, width), left, 50, width, 13, c.green)
      if paged and model.page > 1 then self:pageChevron(20, 50, false, model.enabled ~= false) end
      if paged and model.page < model.pages then self:pageChevron(220, 50, true, model.enabled ~= false) end
    end
    for index = 1, 4 do
      local move = model.moves[index] or { available = false, name = "-" }
      local x, y = Page.rect(index)
      self:summaryMoveRow(move, x, y, self.nativeFocus and model.selection == index,
        model.enabled ~= false and move.available ~= false,
        model.details == true and move.available ~= false)
    end
  end

  function H:v4MovePrompt(model, Page)
    local c, mon = self.colors, model.mon or {}
    local enabled = model.enabled ~= false and model.choices ~= nil
    self.v4SummaryWindow(self, 6, 33, 228, 51, self:typeColor(mon.type))
    self:v4Seat(11, 36, 44)
    if model.drawPokemon then model.drawPokemon(14, 39, 38) end
    self:partyName(mon.name or "", 60, 40, c.ink, 120)
    self:partyInfo(mon.levelText or "", 186, 40, c.ink, 38, "right")
    self:typeBadges(mon, 60, 62, false)
    self:summaryMoveRow(model.newMove or {}, 6, 88, false, enabled and model.details == true, model.details == true)
    newBadge(self, 3, 84, model.newLabel)
    self:v4MessageWindow(6, 124, 228, 38)
    local lines = model.prompt or {}
    local n = min(3, #lines)
    local firstY = 124 + floor((38 - n * 11) / 2)
    self:v4Caps(function()
      for index = 1, n do
        self:partyInfoCentered(self:fitPartyInfo(lines[index], 208), 14, firstY + (index - 1) * 11, 212, 11, c.ink)
      end
    end)
    for index, label in ipairs(model.choices or {}) do
      local x, y, w, h = Page.promptRect(index)
      local pressed = self:beginPress(x, y, w, h, enabled)
      local up = tostring(label):upper()
      local tone = POSITIVE[up] and (cg(self) and hex("1ea5d8") or hex("3ea04c")) or hex("5a6c88")
      local off = self:v4Button(x, y, w, h, K.rampOf(tone), { radius = 6, lip = 4, chamfer = 6 })
      if self.nativeFocus and model.selection == index then self:focusFrame(x, y, w, h) end
      local glyph = POSITIVE[up] and { "......#", ".....##", "#...##.", "##.##..", ".###...", "..#...." }
        or NEGATIVE[up] and { "#...#", ".#.#.", "..#..", ".#.#.", "#...#" } or nil
      local text = self:fitPartyInfo(label, w - 30)
      if glyph then
        local G = ui.graphics
        local gw, tw = #glyph[1] * 2 + 6, self:partyInfoWidth(text)
        local gx = x + floor((w - gw - tw) / 2)
        G.push(); G.translate(gx, y + off + floor((h - 5 - #glyph * 2) / 2)); G.scale(2, 2)
        ART(glyph, 0, 0, { ["#"] = WHITE })
        G.pop()
        self:partyInfo(text, gx + gw, y + off + floor((h - 5 - 9) / 2) - 1, WHITE)
      else
        self:partyInfoCentered(text, x + 8, y + off, w - 16, h - 5, WHITE)
      end
      self:endPress(pressed)
    end
    if not enabled then self:systemOverlay(0.48) end
  end

  ---------------------------------------------------------------------------
  -- Small shared pieces for feature modules (Notes, Silph Connect)
  ---------------------------------------------------------------------------
  local TONES = { battle = "e05040", trade = "3878d0", negative = "5a6c88", amber = "e09a20" }
  function H:v4Choice(x, y, w, h, state, enabled)
    local c = self.colors
    if type(state) == "string" then
      local tone = state == "positive" and (cg(self) and hex("1ea5d8") or hex("3ea04c")) or hex(TONES[state] or "5a6c88")
      return self:v4Button(x, y, w, h, K.rampOf(tone), { radius = 5, lip = h >= 20 and 3 or 2, chamfer = 4 })
    end
    if state then
      return self:v4Button(x, y, w, h, K.rampOf(self.tok.acc.M), { radius = 4, lip = h >= 20 and 3 or 2, chamfer = 4 })
    end
    self:v4Key(x, y, w, h, enabled == false and { cap = c.bandLight, lip = c.band, hi = c.bandLight } or nil)
    return 0
  end

  function H:v4Paper(x, y, w, h, firstText)
    local c = self.colors
    local paper = self.dark and hex("2c3440") or hex("fffdf2")
    if cg(self) then CH(x, y, w, h, 4, c.outline); CH(x + 1, y + 1, w - 2, h - 2, 3, paper)
    else RR(x, y, w, h, 4, c.outline); RR(x + 1, y + 1, w - 2, h - 2, 3, paper) end
    local line = mix(paper, c.blue, self.dark and 0.3 or 0.18)
    for ly = (firstText or y + 4) + 10, y + h - 4, 12 do R(x + 4, ly, w - 8, 1, line) end
    R(x + 4, y + 2, 1, h - 4, mix(paper, c.red, self.dark and 0.4 or 0.3))
  end

  local NOTE = { "oooooo.", "o####oo", "o#..#o#", "o####oo", "o#..##o", "o#####o", "ooooooo" }
  function H:v4NoteCard(x, y, w, h, note)
    local c = self.colors
    self:v4Key(x, y, w, h)
    local amber = hex("e8a030")
    ART(NOTE, x + 7, y + floor((h - 2 - 7) / 2), { o = c.outline, ["#"] = amber, ["."] = WHITE })
    if note and note.tasks and #note.tasks > 0 then
      local done = 0
      for _, t in ipairs(note.tasks) do if t.done then done = done + 1 end end
      local text = done .. "/" .. #note.tasks
      self:partyInfo(text, x + w - 8 - self:partyInfoWidth(text), y + 8, done == #note.tasks and c.green or c.mutedInk)
    end
  end

  -- Notes list: a memo pad. Filter as one sliding switch, notes as sticky
  -- cards on ruled paper (title, place, what is inside), then a lipped
  -- NEW NOTE key with a pencil. Hit rectangles match notes_ui.lua.
  local PIN_G = { ".ooo.", "o###o", "o#w#o", "o###o", ".o#o.", "..o.." }
  local PENCIL = { "......oo", ".....o#o", "....o##o", "...o##o.", "..o##o..", ".o##o...", "ow#o....", "oo......" }
  local TASK_G = { "ooooo", "o...o", "o.#.o", "o...o", "ooooo" }
  local DRAW_G = { "....o", "...o.", ".oo..", "o.o..", "oo..." }
  function H:v4NotesList(state, hit)
    local c = self.colors
    local G = ui.graphics
    local amber = hex("e8a030")
    -- filter switch
    local here = state.filter == "here"
    local a = K.rampOf(cg(self) and self.tok.acc.M or hex("3ea04c"))
    if cg(self) then CH(7, 33, 226, 19, 3, c.outline); CH(8, 34, 224, 17, 2, self.dark and hex("141b22") or hex("e4ebf0"))
    else RR(7, 33, 226, 19, 4, c.outline); RR(8, 34, 224, 17, 3, self.dark and hex("1c2533") or hex("dfe8e1")) end
    local hx = self:v4Glide("notes_filter", here and 8 or 120)
    if cg(self) then CH(hx, 34, 112, 17, 2, a.M); CH(hx, 34, 112, 8, 2, a.L)
    else RR(hx, 34, 112, 17, 3, a.D); RR(hx, 34, 112, 15, 3, a.M); R(hx + 3, 34, 106, 1, a.Hi) end
    for i, f in ipairs({ { "HERE", "here", 7 }, { "ALL NOTES", "all", 123 } }) do
      local selected = state.filter == f[2]
      local enabled = not (selected and state.page == 1)
      local pressed = self:beginPress(f[3], 33, 110, 19, enabled)
      local lit = hx + 56 >= f[3] and hx + 56 < f[3] + 112
      local label = translate(f[1])
      local gw = i == 1 and 8 or 0
      local lw = self:partyInfoWidth(label)
      local lx = f[3] + floor((110 - lw - gw) / 2)
      if i == 1 then ART(PIN_G, lx, 39, { o = lit and WHITE or c.mutedInk, ["#"] = lit and a.M or c.mutedInk, w = WHITE }); lx = lx + 8 end
      self:partyInfo(label, lx, 36, lit and WHITE or c.mutedInk)
      self:endPress(pressed)
      if enabled then hit(f[3], 33, 110, 19, "filter", f[2]) end
    end
    -- memo pad behind the cards
    local paper = self.dark and hex("2c3440") or hex("fffdf2")
    if cg(self) then CH(7, 56, 226, 113, 4, c.outline); CH(8, 57, 224, 111, 3, paper)
    else RR(7, 56, 226, 113, 4, c.outline); RR(8, 57, 224, 111, 3, paper) end
    local rule = mix(paper, c.blue, self.dark and 0.3 or 0.16)
    for ly = 66, 164, 8 do R(12, ly, 216, 1, rule) end
    R(20, 58, 1, 109, mix(paper, c.red, self.dark and 0.4 or 0.28))
    local list = state:list()
    state.pages = math.max(1, math.ceil(#list / 3))
    state.page = math.max(1, math.min(state.page, state.pages))
    local enter = self:v4Enter("notes_list", tostring(state.filter) .. ":" .. state.page .. ":" .. #list, 0.24)
    for row = 1, 3 do
      local entry = list[(state.page - 1) * 3 + row]
      if entry then
        local y = 59 + (row - 1) * 31
        local n = entry.note
        local _, dx = self:v4Stagger(enter, row, 0.1, 14, 3)
        if dx ~= 0 then G.push(); G.translate(dx, 0) end
        local pressed = self:beginPress(7, y, 226, 26)
        local tint = n.tasks and #n.tasks > 0 and hex("4888e0")
          or n.strokes and #n.strokes > 0 and hex("d05878") or amber
        local sticky = mix(self.dark and hex("3a4250") or hex("fff6d0"), tint, self.dark and 0.18 or 0.12)
        if cg(self) then CH(11, y, 218, 26, 3, c.outline); CH(12, y + 1, 216, 24, 2, sticky)
        else RR(11, y, 218, 26, 3, c.outline); RR(12, y + 1, 216, 24, 2, sticky)
          R(15, y + 1, 210, 1, mix(sticky, WHITE, 0.6)) end
        -- folded corner
        R(220, y + 1, 8, 1, paper); R(222, y + 2, 6, 1, paper); R(224, y + 3, 4, 1, paper); R(226, y + 4, 2, 1, paper)
        for k = 0, 3 do R(220 + k * 2, y + 1 + k, 1, 1, c.outline) end
        R(12, y + 3, 3, 20, tint)
        ART(NOTE, 19, y + 9, { o = c.outline, ["#"] = tint, ["."] = WHITE })
        local title = n.title ~= "" and n.title or translate("UNTITLED")
        self:partyInfo(self:fitPartyInfo(title, 150), 31, y + 2, n.title ~= "" and c.ink or c.mutedInk)
        local place = n.area and n.areaName or translate("GENERAL")
        if n.area then ART(PIN_G, 31, y + 15, { o = c.outline, ["#"] = hex("e05848"), w = WHITE }) end
        self:partyInfo(self:fitPartyInfo(place, 140), n.area and 39 or 31, y + 12, c.mutedInk)
        -- what's inside: tasks progress, drawing mark
        local rx = 216
        if n.tasks and #n.tasks > 0 then
          local done = 0
          for _, t in ipairs(n.tasks) do if t.done then done = done + 1 end end
          local text = done .. "/" .. #n.tasks
          local pw = self:v4Pill(text, rx, y + 8, done == #n.tasks and c.hp or hex("4888e0"), { raw = true, right = true })
          rx = rx - pw - 4
        end
        if n.strokes and #n.strokes > 0 then
          ART(DRAW_G, rx - 6, y + 10, { o = hex("d05878") })
        end
        self:endPress(pressed)
        if dx ~= 0 then G.pop() end
        hit(7, y, 226, 26, "open", entry.index)
      end
    end
    if #list > 0 and #list < 3 and state.page == 1 then
      -- the next free line of the pad is a dashed sticky: tap it to write
      local y = 59 + #list * 31
      local ink = mix(paper, c.blue, self.dark and 0.5 or 0.38)
      local pressed = self:beginPress(11, y, 218, 26)
      for dx = 14, 224, 6 do R(dx, y, 3, 1, ink); R(dx, y + 25, 3, 1, ink) end
      for dy = y + 3, y + 22, 6 do R(11, dy, 1, 3, ink); R(228, dy, 1, 3, ink) end
      -- same language as an empty Home slot: a dashed outline and a plus
      CIRC(113, y + 6, 15, ink); CIRC(114, y + 7, 13, paper)
      R(117, y + 13, 7, 1, ink); R(120, y + 10, 1, 7, ink)
      self:endPress(pressed)
      hit(11, y, 218, 26, "new")
      if #list == 1 then
        -- a pencil doodle on the rest of the pad
        RING(188, 128, 30, 1, ink); R(189, 142, 28, 2, ink); CIRC(198, 138, 10, paper); RING(198, 138, 10, 1, ink)
      end
    end
    if #list == 0 then
      ART(PENCIL, 116, 88, { o = c.outline, ["#"] = amber, w = WHITE })
      self:partyInfo(translate("NO NOTES YET"), 7, 102, c.mutedInk, 226, "center")
    end
    -- pager on the pad's foot
    if state.pages > 1 then
      H.v4PagerKey(self, 66, 152, 36, 15, true, state.page > 1, true)
      H.v4PagerKey(self, 138, 152, 36, 15, false, state.page < state.pages, true)
      self:partyInfoCentered(state.page .. "/" .. state.pages, 102, 152, 36, 13, c.ink)
      if state.page > 1 then hit(66, 152, 36, 15, "page", -1) end
      if state.page < state.pages then hit(138, 152, 36, 15, "page", 1) end
    end
    if state.deleted then
      self:v4Window(7, 172, 226, 17, { radius = 3 })
      self:partyInfo(translate("NOTE DELETED"), 12, 174, c.green, 126, "center")
      local up = self:beginPress(141, 173, 90, 15)
      local off = self:v4Button(141, 173, 90, 15, K.rampOf(hex("5a6c88")), { radius = 3, lip = 2, chamfer = 3 })
      self:partyInfo(translate("UNDO"), 141, 174 + off, WHITE, 90, "center")
      self:endPress(up)
      hit(141, 172, 92, 17, "restore")
    end
    -- NEW NOTE: lipped key with a pencil
    local pressed = self:beginPress(7, 192, 226, 20)
    local off = self:v4Button(7, 192, 226, 20, K.rampOf(amber), { radius = 5, lip = 3, chamfer = 5 })
    local label = translate("NEW NOTE")
    local lw = self:partyInfoWidth(label)
    local gx = 120 - floor((lw + 12) / 2)
    ART(PENCIL, gx, 197 + off, { o = c.outline, ["#"] = WHITE, w = hex("f8e0b0") })
    self:partyInfo(label, gx + 12, 195 + off, WHITE)
    self:endPress(pressed)
    hit(7, 192, 226, 20, "new")
  end

  -- Note page header: sticky title card + TEXT | TASKS | DRAWING tabs with
  -- glyphs and a gliding lit tab (hits as in notes_ui.lua).
  local TEXT_G = { "#######", ".......", "#####..", ".......", "######." }
  function H:v4NoteHeader(n, state, hit)
    local c = self.colors
    local tint = hex("e8a030")
    local sticky = mix(self.dark and hex("3a4250") or hex("fff6d0"), tint, self.dark and 0.18 or 0.12)
    if cg(self) then CH(7, 33, 226, 27, 3, c.outline); CH(8, 34, 224, 25, 2, sticky)
    else RR(7, 33, 226, 27, 4, c.outline); RR(8, 34, 224, 25, 3, sticky); R(11, 34, 218, 1, mix(sticky, WHITE, 0.6)) end
    R(8, 37, 3, 19, tint)
    ART(NOTE, 15, 43, { o = c.outline, ["#"] = tint, ["."] = WHITE })
    local title = n.title ~= "" and n.title or translate("UNTITLED")
    self:partyInfo(self:fitPartyInfo(title, 190), 27, 34, n.title ~= "" and c.ink or c.mutedInk)
    if n.area then ART(PIN_G, 27, 50, { o = c.outline, ["#"] = hex("e05848"), w = WHITE }) end
    self:partyInfo(self:fitPartyInfo(n.area and n.areaName or translate("GENERAL"), 180), n.area and 35 or 27, 47, c.mutedInk)
    ART(PENCIL, 219, 47, { o = c.mutedInk, ["#"] = mix(sticky, c.mutedInk, 0.4), w = sticky })
    hit(7, 33, 226, 14, "edit", "title"); hit(7, 47, 226, 13, "area")
    local tabs = { { "TEXT", "text", TEXT_G, hex("e8a030") }, { "TASKS", "tasks", TASK_G, hex("4888e0") },
      { "DRAWING", "sketch", DRAW_G, hex("d05878") } }
    local active = 1
    for i, t in ipairs(tabs) do if state.view == t[2] then active = i end end
    local a = K.rampOf(tabs[active][4])
    if cg(self) then CH(7, 65, 226, 20, 3, c.outline); CH(8, 66, 224, 18, 2, self.dark and hex("141b22") or hex("e4ebf0"))
    else RR(7, 65, 226, 20, 4, c.outline); RR(8, 66, 224, 18, 3, self.dark and hex("1c2533") or hex("dfe8e1")) end
    local hx = self:v4Glide("note_tab", 8 + (active - 1) * 75)
    local hw = active == 3 and 74 or 75
    if cg(self) then CH(hx, 66, hw, 18, 2, a.M); CH(hx, 66, hw, 8, 2, a.L)
    else RR(hx, 66, hw, 18, 3, a.D); RR(hx, 66, hw, 16, 3, a.M); R(hx + 3, 66, hw - 6, 1, a.Hi) end
    for i, t in ipairs(tabs) do
      local x = 7 + (i - 1) * 77
      local selected = state.view == t[2]
      local enabled = not selected
      local pressed = self:beginPress(x, 65, 72, 20, enabled)
      local lit = hx + 37 >= x - 2 and hx + 37 < x + 75
      local label = translate(t[1])
      local gw = #t[3][1] + 4
      local lx = x + floor((72 - gw - self:partyInfoWidth(label)) / 2)
      ART(t[3], lx, 65 + floor((18 - #t[3]) / 2) + 1, { ["#"] = lit and WHITE or t[4], o = lit and WHITE or t[4], ["."] = nil })
      self:partyInfo(label, lx + gw, 68, lit and WHITE or c.mutedInk)
      self:endPress(pressed)
      if enabled then hit(x, 65, 72, 20, "view", t[2]) end
    end
  end

  -- Achievements: GOALS | STAMP BOOK as one switch with glyphs.
  local FLAG_G = { "o......", "o####..", "o#####.", "o####..", "o......", "o......" }
  local BOOK_G = { "ooo.ooo", "o#o.o#o", "o#o.o#o", "o#o.o#o", "ooooooo" }
  function H:v4AchievementTabs(view)
    local c = self.colors
    local a = K.rampOf(hex("c89a18"))
    if cg(self) then CH(6, 34, 228, 18, 3, c.outline); CH(7, 35, 226, 16, 2, self.dark and hex("141b22") or hex("e4ebf0"))
    else RR(6, 34, 228, 18, 4, c.outline); RR(7, 35, 226, 16, 3, self.dark and hex("1c2533") or hex("dfe8e1")) end
    local hx = self:v4Glide("ach_tab", view == "album" and 120 or 7)
    if cg(self) then CH(hx, 35, 113, 16, 2, a.M); CH(hx, 35, 113, 7, 2, a.L)
    else RR(hx, 35, 113, 16, 3, a.D); RR(hx, 35, 113, 14, 3, a.M); R(hx + 3, 35, 107, 1, a.Hi) end
    for i, t in ipairs({ { "GOALS", "goals", FLAG_G }, { "STAMP BOOK", "album", BOOK_G } }) do
      local x = 6 + (i - 1) * 117
      local lit = hx + 56 >= x and hx + 56 < x + 115
      local label = translate(t[1])
      local gw = #t[3][1] + 4
      local lx = x + floor((111 - gw - self:partyInfoWidth(label)) / 2)
      ART(t[3], lx, 40, { o = lit and WHITE or c.mutedInk, ["#"] = lit and hex("f8e070") or c.band })
      self:partyInfo(label, lx + gw, 37, lit and WHITE or c.mutedInk)
    end
  end

  function H:v4Person(cx, y, tint)
    local c = self.colors
    local skin = hex("f8c8a0")
    ART({ "..oooo..", ".o####o.", "o######o", "oo####oo", ".osssso.", ".osssso.", "..oooo..",
      ".oBBBBo.", "oBBBBBBo", "oBBBBBBo", "oooooooo" }, cx - 4, y - 1,
      { o = c.outline, ["#"] = mix(tint, { 0, 0, 0, 1 }, 0.25), s = skin, B = tint })
  end

  -- Silph Connect profile card: avatar seat, name, game chip, status pill,
  -- an animated link line while waiting.
  function H:v4PssCard(name, game, status, mode, note, height, waiting)
    local c = self.colors
    local accent = mode == "trade" and hex("3878d0") or mode == "battle" and hex("e05040")
      or mode == "ready" and c.hp or mode == "offline" and c.silverDark or (cg(self) and self.tok.acc.M or hex("3878d0"))
    self.v4SummaryWindow(self, 7, 33, 226, height, accent)
    -- avatar seat
    CIRC(14, 40, 44, c.outline)
    CIRC(15, 41, 42, mix(c.surface, accent, self.dark and 0.32 or 0.2))
    K.CIRCrows(15, 41, 42, 21, 42, mix(c.surface, accent, self.dark and 0.45 or 0.32))
    local G = ui.graphics
    G.push(); G.translate(36, 52); G.scale(2, 2)
    self:v4Person(0, 0, accent)
    G.pop()
    self:partyName(self:fitPartyInfo(name or "", 150), 66, 42, c.ink, 150)
    local x = 66
    if game then x = x + self:v4Pill(game, x, 58, hex("6a7a90"), { raw = true, maxW = 90 }) + 4 end
    if status then self:v4Pill(status, x, 58, accent, { raw = true, maxW = 220 - x }) end
    if waiting and self.motionEnabled ~= false then
      local t = self:clock()
      for k = 0, 5 do
        local on = (floor(t / 0.15) % 6) == k
        R(66 + k * 8, 76, 5, 3, on and accent or c.bandLight)
      end
      self:wantAmbient(0.3, 0.15)
    end
    local noteBottom
    if note then
      -- the reason sits right under the name so the link picture below
      -- gets the room to be drawn at full size
      local a, b = self:splitPartyInfo(note, 156)
      local ny = waiting and 84 or 76
      R(66, ny - 3, 158, 1, c.band)
      self:partyInfo(a, 66, ny, c.mutedInk, 156)
      if b then self:partyInfo(b, 66, ny + 11, c.mutedInk, 156) end
      noteBottom = ny + (b and 22 or 11)
    end
    -- link illustration: two DS-style devices, signal pips running between
    local top, bottom = note and noteBottom + 2 or 96, 33 + height - 5
    local room = bottom - top
    local scale = room >= 36 and 2 or 1
    local DEV = { ".oooooooo.", "o########o", "o#wwwwww#o", "o#wwwwww#o", "o########o",
      ".oooooooo.", "o########o", "o#o#oo#o#o", "o########o", ".oooooooo." }
    local devC = cg(self) and hex("40a8d8") or hex("58b078")
    local dw, dh = #DEV[1] * scale, #DEV * scale
    local ly = top + floor((room - dh) / 2)
    local gap = scale == 2 and 72 or 52
    local lx = 120 - floor((dw * 2 + gap) / 2)
    local rx = lx + dw + gap
    local G = ui.graphics
    for i, dx in ipairs({ lx, rx }) do
      G.push(); G.translate(dx, ly); G.scale(scale, scale)
      ART(DEV, 0, 0, { o = c.outline, ["#"] = i == 1 and devC or accent, w = hex("d8f0e0") })
      G.pop()
    end
    local t = self:clock()
    local on = mode == "ready" or mode == "trade" or mode == "battle"
    local n = floor(gap / 6)
    local cy = ly + floor(dh * 0.3)
    for k = 0, n - 1 do
      local lit = on and (not waiting or (floor(t / 0.08) % n) == k)
      R(lx + dw + 3 + k * 6, cy, 3, scale, lit and accent or c.band)
    end
    if waiting then self:wantAmbient(0.3, 0.08) end
  end

  -- Silph Connect keys that are not a toned action: disabled tones stay
  -- recognisable (greyed with a lock), BACK carries its arrow.
  local LOCK = { ".ooo.", "o...o", "ooooo", "o#o#o", "o###o", "ooooo" }
  local BACK_G = { "..o....", ".oo....", "ooooooo", ".oo...o", "..o...o", "......o", "..oooo." }
  function H:v4PssButton(text, x, y, w, h, enabled, tone)
    local c = self.colors
    local label = (ui.translate and ui.translate(text)) or text
    if tone and not enabled then
      self:v4Key(x, y, w, h, { cap = c.bandLight, lip = c.band, hi = c.bandLight })
      local tint = hex(TONES[tone] or "8890a0")
      R(x + 6, y + 2, w - 12, 2, mix(tint, c.bandLight, 0.4))
      local lw = self:partyInfoWidth(label)
      local gx = x + floor((w - lw - 9) / 2)
      ART(LOCK, gx, y + floor((h - 3 - 6) / 2), { o = c.disabledInk, ["#"] = c.bandLight })
      self:partyInfo(label, gx + 9, y + floor((h - 3 - 9) / 2) - 1, c.disabledInk)
      return
    end
    self:v4Key(x, y, w, h, not enabled and { cap = c.bandLight, lip = c.band, hi = c.bandLight } or nil)
    local upper = tostring(text):upper()
    local glyph = (upper == "BACK" or upper == "PREV") and BACK_G or nil
    local lw = self:partyInfoWidth(label)
    local gw = glyph and #glyph[1] + 4 or 0
    local gx = x + floor((w - lw - gw) / 2)
    if glyph then ART(glyph, gx, y + floor((h - 3 - #glyph) / 2), { o = enabled and c.ink or c.disabledInk }) end
    self:partyInfo(label, gx + gw, y + floor((h - 3 - 9) / 2) - 1, enabled and c.ink or c.disabledInk)
  end

  local TONE_G = {
    positive = { "......#", ".....##", "#...##.", "##.##..", ".###...", "..#...." },
    negative = { "#...#", ".#.#.", "..#..", ".#.#.", "#...#" },
    battle = { "#.....#", ".#...#.", "..#.#..", "...#...", "..#.#..", "##...##", "##...##" },
    trade = { "...#.....", "..##.....", ".########", "..##.....", ".....##..", "########.", ".....##..", ".....#..." },
  }
  function H:v4ToneLabel(text, x, y, w, h, tone)
    local glyph = TONE_G[tone]
    local text2 = self:fitPartyInfo(text, w - 24)
    local tw = self:partyInfoWidth(text2)
    if not glyph then
      self:partyInfoCentered(text2, x, y, w, h - 3, WHITE); return
    end
    local gw = #glyph[1] + 5
    local gx = x + floor((w - gw - tw) / 2)
    ART(glyph, gx, y + floor((h - 3 - #glyph) / 2), { ["#"] = WHITE })
    self:partyInfo(text2, gx + gw, y + floor((h - 3 - 9) / 2) - 1, WHITE)
  end

  -- Footer plate under link cards: Silph mark + a calm status line.
  function H:v4PssFooter(text)
    local c = self.colors
    local tw = self:partyInfoWidth(text)
    local w = tw + 30
    local x = 120 - floor(w / 2)
    if cg(self) then CH(x, 191, w, 18, 3, mix(c.surface, c.outline, 0.15)); CH(x + 1, 192, w - 2, 16, 2, c.surface)
    else RR(x, 191, w, 18, 5, mix(c.surface, c.outline, self.dark and 0.3 or 0.18)); RR(x + 1, 192, w - 2, 16, 4, c.surface) end
    local t = self.motionEnabled == false and 0 or floor(self:clock() / 0.5) % 3
    self:wantAmbient(0.5)
    for i = 0, 2 do
      R(x + 8 + i * 4, 202 - i * 2, 2, 2 + i * 2, i <= t and (cg(self) and self.tok.acc.M or c.green) or c.band)
    end
    self:partyInfo(text, x + 22, 194, c.mutedInk)
  end

  -- Silph Connect lobby: own trainer plate with link key, a ready switch,
  -- player cards with game chips, and a pager. Hits match pss_ui.lua.
  local GAME_TINT = { red = "e04838", blue = "3878d0", yellow = "e8c030", gold = "c89a30", silver = "8890a0",
    crystal = "7a68d0", firered = "e86030", leafgreen = "48a858", emerald = "30a878", ruby = "c03048", sapphire = "3060c8" }
  function H:v4PssLobby(state, hit, data)
    local c = self.colors
    local G = ui.graphics
    local tr = function(v) return ui.translate and ui.translate(v) or v end
    local online = state.state == "online"
    local pending = state.state == "connecting" or state.state == "reconnecting" or state.state == "ticket"
    local accent = state.ready and c.hp or online and (cg(self) and self.tok.acc.M or hex("3878d0")) or c.silverDark
    -- own plate
    self:v4Window(7, 33, 226, 32, { radius = 4 })
    R(8, 37, 2, 24, accent)
    CIRC(13, 36, 26, c.outline)
    CIRC(14, 37, 24, mix(c.surface, accent, self.dark and 0.32 or 0.2))
    self:v4Person(26, 41, accent)
    self:partyInfo(self:fitPartyInfo(state.name or tr("YOUR TRAINER"), 100), 43, 34, c.ink)
    local st = tr(state.ready and "READY" or data.states[state.state] or "OFFLINE")
    self:v4Pill(st, 43, 49, accent, { raw = true, maxW = 98 })
    local action
    if state.state ~= "unavailable" and not pending and not state.inUse then
      action = online and "disconnect" or "connect"
    end
    local keyLabel = state.inUse and "IN USE" or online and "DISCONNECT" or pending and "WAITING" or "CONNECT"
    local kp = self:beginPress(147, 37, 82, 24, action ~= nil)
    if action then
      local off = self:v4Choice(147, 37, 82, 24, online and "negative" or "positive", true)
      self:partyInfoCentered(self:fitPartyInfo(tr(keyLabel), 74), 147, 37 + off, 82, 21, WHITE)
    else
      self:v4Key(147, 37, 82, 24, { cap = c.bandLight, lip = c.band, hi = c.bandLight })
      self:partyInfoCentered(self:fitPartyInfo(tr(keyLabel), 74), 147, 37, 82, 21, c.disabledInk)
    end
    self:endPress(kp)
    if action then hit(147, 37, 82, 24, action) end
    -- ready strip
    local readyAction = online and state.session and not state.inUse and not state.onlineUnavailable and "ready" or nil
    local readyLabel = state.notice or state.enabled and (state.ready and "GO BUSY" or "FINISH YOUR CURRENT ACTION")
      or state.session and "GO READY" or "HOST UPDATE NEEDED"
    local rp = self:beginPress(7, 70, 226, 18, readyAction ~= nil)
    if readyAction then
      local tone = state.ready and "negative" or "positive"
      local off = self:v4Choice(7, 70, 226, 18, tone, true)
      CIRC(14, 74 + off, 9, WHITE); CIRC(15, 75 + off, 7, state.ready and c.hp or c.silverDark)
      self:partyInfoCentered(self:fitPartyInfo(tr(readyLabel), 200), 20, 70 + off, 206, 15, WHITE)
    else
      local fill = mix(c.surface, hex("e8a030"), self.dark and 0.2 or 0.14)
      if cg(self) then CH(7, 70, 226, 18, 3, mix(fill, c.outline, 0.35)); CH(8, 71, 224, 16, 2, fill)
      else RR(7, 70, 226, 18, 4, mix(fill, c.outline, 0.35)); RR(8, 71, 224, 16, 3, fill) end
      ART({ "..o..", ".....", ".ooo.", "..o..", "..o..", ".ooo." }, 14, 76, { o = hex("b07010") })
      self:partyInfoCentered(self:fitPartyInfo(tr(readyLabel), 200), 20, 70, 206, 17, c.ink)
    end
    self:endPress(rp)
    if readyAction then hit(7, 70, 226, 18, "ready") end
    -- players
    if #state.rows == 0 then
      self:v4Window(7, 94, 226, 93, { radius = 4 })
      -- sonar rings around a lone trainer
      local t = self.motionEnabled == false and 0 or self:clock()
      local k = (t % 1.6) / 1.6
      if self.motionEnabled ~= false then self:wantAmbient(0.1, 1 / 15) end
      local ring = mix(c.surface, accent, 0.35)
      for i = 0, 2 do
        local d = 14 + floor(((k + i / 3) % 1) * 40) * 2
        RING(120 - floor(d / 2), 118 - floor(d / 2), d, 1, ring)
      end
      self:v4Person(120, 112, c.silverDark)
      local message = state.error and "CONNECTION FAILED" or online and "NO PLAYERS VISIBLE"
        or pending and "CONNECTING" or state.state == "unavailable" and "HOST UPDATE NEEDED"
        or "CONNECT TO SEE PLAYERS"
      self:partyInfo(self:fitPartyInfo(tr(message), 210), 7, 154, c.mutedInk, 226, "center")
      self:partyInfo(tr("SILPH CONNECT"), 7, 168, c.green, 226, "center")
    end
    local enter = self:v4Enter("pss_lobby", tostring(state.page) .. ":" .. #state.rows, 0.26)
    for i = 1, 6 do
      local row = state.rows[(state.page - 1) * 6 + i]
      if row then
        local x, y = 7 + ((i - 1) % 3) * 77, 94 + floor((i - 1) / 3) * 47
        local _, dy = self:v4Stagger(enter, i, 0.06, 8, 6)
        if dy ~= 0 then G.push(); G.translate(0, dy) end
        local pressed = self:beginPress(x, y, 72, 44, true)
        local gt = hex(GAME_TINT[row.version] or "8890a0")
        local ready = row.ready
        self:v4Window(x, y, 72, 44, { radius = 4, fill = ready and mix(c.surface, c.hp, self.dark and 0.16 or 0.08) or nil })
        R(x + 4, y + 1, 64, 2, gt)
        CIRC(x + 4, y + 5, 22, c.outline)
        CIRC(x + 5, y + 6, 20, mix(c.surface, ready and c.hp or hex("3878d0"), self.dark and 0.3 or 0.2))
        self:v4Person(x + 15, y + 9, ready and c.hp or hex("3878d0"))
        -- game chip
        local short = data.short[row.version] or "?"
        local cw = max(18, self:partyInfoWidth(short) + 8)
        if cg(self) then CH(x + 66 - cw, y + 6, cw, 11, 2, mix(gt, c.outline, 0.4)); CH(x + 67 - cw, y + 7, cw - 2, 9, 1, gt)
        else RR(x + 66 - cw, y + 6, cw, 11, 3, mix(gt, c.outline, 0.4)); RR(x + 67 - cw, y + 7, cw - 2, 9, 2, gt) end
        self:withoutShadow(self.partyType, self, short, x + 66 - cw, y + 5, WHITE, cw)
        local stText = tr(ready and "READY" or row.where == "launcher" and "IN MENU" or "ONLINE")
        local dot = ready and c.hp or row.where == "launcher" and c.silverDark or hex("3878d0")
        local st = self:fitPartyInfo(stText, 40)
        local sw = self:partyInfoWidth(st)
        self:partyInfo(st, x + 68 - sw, y + 17, ready and c.green or c.mutedInk)
        if sw <= 34 then R(x + 64 - sw, y + 21, 3, 3, dot) end
        self:partyInfo(self:fitPartyInfo(row.name or "", 66), x + 3, y + 30, c.ink, 66, "center")
        self:endPress(pressed)
        if dy ~= 0 then G.pop() end
        hit(x, y, 72, 44, "player", row.id)
      end
    end
    -- pager
    local pages = state.pages or 1
    local canPrev, canNext = state.page > 1, state.page < pages
    for _, p in ipairs({ { 7, -1, canPrev, { "..#", ".##", "###", ".##", "..#" } }, { 175, 1, canNext, { "#..", "##.", "###", "##.", "#.." } } }) do
      H.v4PagerKey(self, p[1], 190, 58, 21, p[2] < 0, p[3], true)
      if p[3] then hit(p[1], 190, 58, 21, "page", p[2]) end
    end
    self:partyInfoCentered(state.page .. "/" .. pages, 65, 190, 110, 19, c.ink)
  end

  -- Stamp-book find rows: kind icon, name, status pill, chevron.
  function H:v4FindRow(row, top, status, actionable)
    local c = self.colors
    local done = row.state == "done"
    local x = 13
    CIRC(x, top + 5, 21, c.outline)
    CIRC(x + 1, top + 6, 19, mix(c.surface, done and c.hp or c.silverDark, self.dark and 0.3 or 0.2))
    if row.species or row.wild then self:battleTeamBall(x + 10, top + 15, done and "ready" or "empty")
    elseif row.kind == "trainer" or row.trainer then self:v4Person(x + 10, top + 9, done and c.hp or c.silverDark)
    elseif row.icon then self:battleItemIcon({ icon = row.icon }, x + 2, top + 7, c.amberLight)
    else
      ART({ "...ooo...", "..o...o..", ".ooooooo.", "o#######o", "o##ooo##o", "o##o#o##o", "o#######o", ".ooooooo." },
        x + 6, top + 12, { o = c.outline, ["#"] = row.kind == "hidden" and hex("58a8e8") or hex("e8a030") })
    end
    local label = row.isEgg and translate("EGG") or row.label or ""
    self:partyInfo(self:fitPartyInfo(label, 120), 40, top + 4, done and c.ink or c.mutedInk)
    local tint = done and c.hp or row.state == "unavailable" and hex("d05040")
      or row.state == "later" and c.silverDark or (cg(self) and self.tok.acc.M or hex("3878d0"))
    self:v4Pill(status, 40, top + 17, tint, { raw = true, maxW = 160 })
    if actionable then ART({ "#..", "##.", "###", "##.", "#.." }, 222, top + 12, { ["#"] = c.mutedInk }) end
  end

  ---------------------------------------------------------------------------
  -- Item icons: one pixel prop per item family (16×16 box at x, y).
  -- Real item sprites (Gen 3) still win; names refine the family.
  ---------------------------------------------------------------------------
  local ITEM_ART = {
    medicine = { art = { ".....oooo.....", "....o#ww#o....", "....oooooo....", "...o######o...", "..o##wwww##o..",
      "..o#rrrrrr#o..", "..o#rrwwrr#o..", "..o#rwwwwr#o..", "..o#rrwwrr#o..", "..o#rrrrrr#o..", "..o########o..",
      "...oooooooo..." }, pal = { ["#"] = "8a96a8", w = "f8f8f8", r = "8c58d8" } },
    potion = { art = { ".....oooo.....", "....o#ww#o....", "....oooooo....", "...o######o...", "..o##wwww##o..",
      "..o#rrrrrr#o..", "..o#rrwwrr#o..", "..o#rwwwwr#o..", "..o#rrwwrr#o..", "..o#rrrrrr#o..", "..o########o..",
      "...oooooooo..." }, pal = { ["#"] = "8a96a8", w = "f8f8f8", r = "e05070" } },
    status = { art = { "....oooooo....", "....o####o....", "...oooooooo...", "..o########o..", "..o###gg###o..",
      "..o###gg###o..", "..o#gggggg#o..", "..o#gggggg#o..", "..o###gg###o..", "..o###gg###o..", "..o########o..",
      "...oooooooo..." }, pal = { ["#"] = "f8f8f8", g = "48b858" } },
    ether = { art = { ".....ooo......", "....o#w#o.....", ".....ooo......", "....o###o.....", "...o#bbb#o....",
      "..o#bbwbb#o...", "..o#bwwwb#o...", "..o#bbwbb#o...", "...o#bbb#o....", "....ooooo....." },
      pal = { ["#"] = "8a96a8", w = "f8f8f8", b = "48a8e8" } },
    revive = { art = { "......o......", ".....o#o.....", "....o#w#o....", "...o#ww##o...", "..o#w####yo..",
      ".o#######yyo.", "..o#####yyo..", "...o###yyo...", "....o#yyo....", ".....oyo.....", "......o......" },
      pal = { ["#"] = "f8d840", w = "fff8c0", y = "d8a018" } },
    machine = { art = { "....oooooo....", "..oo######oo..", ".o##########o.", ".o####oo####o.", "o####owwo####o",
      "o###owwwwo###o", "o###owwwwo###o", "o####owwo####o", ".o####oo####o.", ".o##########o.", "..oo######oo..",
      "....oooooo...." }, pal = { w = "f8f8f8" } },
    key = { art = { "..oooo........", ".o####o.......", "o##oo##o......", "o#o..o#oooooo.", "o##oo##o####o",
      ".o####oo#o#o.", "..oooo..o.o..." }, pal = { ["#"] = "e8c040" } },
    rope = { art = { "...oooooo...", "..o######o..", ".o##oooo##o.", ".o#o....o#o.", ".o#o.oo.o#o.",
      ".o#o.o#oo#o.", ".o##o.o##o..", "..o##oo#o...", "...o####o...", "....oooo#o..", "........o#o.", ".........o.." },
      pal = { ["#"] = "c8985a" } },
    repel = { art = { "....ooo.......", "...o###oo.....", "...oooo#o.....", "..o#####o.....", "..o#wwww#o....",
      "..o#pppp#o....", "..o#pwwp#o....", "..o#pppp#o....", "..o#pppp#o....", "..o######o....", "...oooooo....." },
      pal = { ["#"] = "8a96a8", w = "f8f8f8", p = "c058c0" } },
    stone = { art = { "....ooooo....", "...o#####o...", "..o##ww###o..", ".o##w#####do.", ".o########do.",
      ".o#######ddo.", "..o#####ddo..", "...o##dddo...", "....ooooo...." }, pal = { ["#"] = "58c868", w = "c8f8c8", d = "309048" } },
    berry = { art = { ".....oo.....", "....oggo....", "...ooggoo...", "..o##oo##o..", ".o#w######o.",
      ".o#w######o.", ".o########o.", ".o#######do.", "..o#####do..", "...oooooo..." }, pal = { ["#"] = "e05050", w = "f8c0c0", g = "58b848", d = "a03030" } },
    mail = { art = { "oooooooooooo", "o##########o", "oo########oo", "o#o######o#o", "o##oo##oo##o",
      "o####oo####o", "o##########o", "oooooooooooo" }, pal = { ["#"] = "f8f0d8" } },
    candy = { art = { "oo...oooo...oo", "o#o.o#ww#o.o#o", "o##o#w####o##o", "o############o", "o##o######o##o",
      "o#o.o####o.o#o", "oo...oooo...oo" }, pal = { ["#"] = "9c78e0", w = "e0d4fa" } },
    leaf = { art = { ".......oooo", ".....oo###o", "...oo####wo", "..o####w##o", ".o###w####o", ".o##w####o.",
      "o##w####o..", "o#w###oo...", "ow#ooo.....", "oo........." }, pal = { ["#"] = "b8c8d0", w = "f8f8f8" } },
    bag = { art = { "....oooo....", "...o####o...", "..oooooooo..", ".o########o.", "o##########o",
      "o#oooooooo#o", "o#o######o#o", "o#oooooooo#o", "o##########o", ".oooooooooo." }, pal = { ["#"] = "d8a048" } },
  }
  local function itemFamily(item)
    local name = tostring(item.label or item.name or item.displayLabel or ""):upper()
    if item.icon == "machine" or name:match("^TM") or name:match("^HM") then return "machine", name:match("^HM") and "hm" end
    if name:find("ROPE") then return "rope" end
    if name:find("CANDY") then return "candy" end
    if name:find("LEAF") then return "leaf" end
    if name:find("REPEL") then return "repel" end
    if name:find("STONE") then return "stone" end
    if name:find("BERRY") or name:find("BERRIES") then return "berry" end
    if name:find("MAIL") then return "mail" end
    if name:find("REVIVE") then return "revive" end
    if name:find("ETHER") or name:find("ELIXIR") or name:match("^PP ") then return "ether" end
    if name:find("KEY") or name:find("CARD") or name:find("PASS") or name:find("TICKET") then return "key" end
    if name:find("POTION") or name:find("WATER") or name:find("SODA") or name:find("LEMONADE") or name:find("MILK") then return "potion" end
    if item.icon == "status" then return "status" end
    if item.icon == "medicine" then return "medicine" end
    return "bag"
  end
  -- Size of what battleItemIcon draws for this item, so seats can pick the
  -- largest whole-pixel scale that still fits.
  function H:v4ItemArtDims(item)
    if item.cancel or item.icon == "ball" then return 11, 11 end
    if item.itemSprite then return 17, 17 end
    local spec = ITEM_ART[(itemFamily(item))]
    if spec then return #spec.art[1], #spec.art end
    return 15, 15
  end
  local baseItemIcon = H.battleItemIcon
  function H:battleItemIcon(item, x, y, tint)
    if item.cancel or item.itemSprite or item.icon == "ball" then return baseItemIcon(self, item, x, y, tint) end
    local family, variant = itemFamily(item)
    local spec = ITEM_ART[family]
    if not spec then return baseItemIcon(self, item, x, y, tint) end
    local pal = { o = self.colors.outline }
    for k, v in pairs(spec.pal) do pal[k] = hex(v) end
    if family == "machine" then pal["#"] = variant == "hm" and hex("a058d8") or (tint or hex("e8b830")) end
    local w, h = #spec.art[1], #spec.art
    ART(spec.art, x + floor((17 - w) / 2), y + floor((17 - h) / 2), pal)
  end

  ---------------------------------------------------------------------------
  -- PokéNav: the device's menus as big touch keys with their own icons, and
  -- the PokéNav's description line in the message window underneath.
  ---------------------------------------------------------------------------
  local function wrapLabel(self, text, width, maxLines)
    local lines, current = {}, ""
    for word in tostring(text or ""):gsub("\n", " "):gmatch("%S+") do
      local try = current == "" and word or current .. " " .. word
      if self:labelWidth(try) <= width or current == "" then current = try
      else lines[#lines + 1] = current; current = word end
    end
    if current ~= "" then lines[#lines + 1] = current end
    while #lines > maxLines do table.remove(lines) end
    return lines
  end

  function H:pokenavMenu(model, help, rs)
    local c = self.colors
    local G = ui.graphics
    local accent = cg(self) and self.tok.acc.M or (rs and hex("3878d0") or hex("e86030"))
    local a = K.rampOf(accent)
    local entries = model and model.entries or {}
    local enter = self:v4Enter("pokenav", #entries .. ":" .. tostring(entries[1] and entries[1].label), 0.24)
    for index, e in ipairs(entries) do
      local _, dx = self:v4Stagger(enter, index, 0.06, 14, #entries)
      if dx ~= 0 then G.push(); G.translate(dx, 0) end
      local x, y, w, h = e.x, e.y, e.w, e.h
      local lit = e.selected
      local pressed = self:beginPress(x, y, w, h, not e.disabled)
      local off = 0
      if lit then off = self:v4Button(x, y, w, h, a, { radius = 6, lip = 3, chamfer = 5 })
      else self:v4Window(x, y, w, h, { radius = 5 }) end
      local icon = tostring(e.kind or "")
      local hasIcon = self.v4HasIcon and self:v4HasIcon(icon)
      local ink = lit and WHITE or c.ink
      local face = h - (lit and 3 or 0)
      local function seat(sx, sy, d)
        CIRC(sx, sy, d, c.outline)
        CIRC(sx + 1, sy + 1, d - 2, lit and mix(WHITE, accent, 0.18) or mix(c.surface, accent, self.dark and 0.3 or 0.16))
        K.CIRCrows(sx + 1, sy + 1, d - 2, floor((d - 2) / 2), d - 2,
          lit and mix(WHITE, accent, 0.3) or mix(c.surface, accent, self.dark and 0.42 or 0.26))
        if hasIcon then self:v4Icon(icon, sx + floor((d - 24) / 2), sy + floor((d - 24) / 2)) end
      end
      local function text(value, tx, ty, tw, align)
        local shown = self:fitPartyInfo(value, tw)
        if lit then self:withoutShadow(self.partyInfo, self, shown, tx, ty, ink, tw, align)
        else self:partyInfo(shown, tx, ty, ink, tw, align) end
      end
      if h >= 54 and w < 200 then
        -- tile: icon on top, name underneath, like a Home app
        local d = 32
        seat(x + floor((w - d) / 2), y + 5 + off, d)
        text(e.label, x + 4, y + face - 15 + off, w - 8, "center")
      else
        local d = min(face - 4, 30)
        local sx, sy = x + 5, y + floor((face - d) / 2) + off
        if d >= 26 then seat(sx, sy, d)
        elseif hasIcon then self:v4Icon(icon, sx, y + floor((face - 24) / 2) + off); d = 24 end
        local tx = sx + d + 6
        text(e.label, tx, y + floor((face - 11) / 2) + off, x + w - tx - (w >= 200 and 16 or 4))
        if lit and w >= 200 then
          local b = (self.motionEnabled ~= false and floor(self:clock() / 0.4) % 2 == 0) and 1 or 0
          self:wantAmbient(0.4)
          ART(K.CHEV_R, x + w - 12 + b, y + floor((face - 5) / 2) + off, { ["#"] = WHITE })
        end
      end
      if self.nativeFocus and e.selected then self:focusFrame(x, y, w, h) end
      self:endPress(pressed)
      if dx ~= 0 then G.pop() end
    end
    -- the device's own description of the highlighted feature
    self:v4MessageWindow(7, 170, 226, 41)
    if help and help ~= "" then
      local lines = wrapLabel(self, help, 204, 2)
      local top = 170 + floor((41 - 4 - #lines * 13) / 2)
      for i, line in ipairs(lines) do
        self:label(line, 18, top + (i - 1) * 13, c.ink, 204, "center")
      end
    end
  end


  ---------------------------------------------------------------------------
  -- Gen 2 POKéGEAR: the cards as Home-style tiles, then a tab rail and a
  -- touch face per card. Page (pokegear_page.lua) owns the shared geometry.
  ---------------------------------------------------------------------------
  local PG_TINT = { clock = "e05040", map = "48a858", phone = "5878c8", radio = "f0a030" }
  local UP = { ".....#.....", "....###....", "...#####...", "..#######..", ".#########.", "###########" }
  local DOWN = { "###########", ".#########.", "..#######..", "...#####...", "....###....", ".....#....." }
  local function pgAccent(self, id)
    if cg(self) then return self.tok.acc.M end
    return hex(PG_TINT[id] or "48a858")
  end
  local function lcdColors(self)
    local tok = self.tok
    if tok.lcd then return tok.lcdFrame, tok.lcd, tok.lcdOn, tok.lcdGhost end
    local bg = self.dark and hex("0b1620") or hex("12212e")
    local on = tok.acc.Hi or tok.acc.L
    return self.colors.outline, bg, on, mix(bg, on, 0.14)
  end
  local function lcdPanel(self, x, y, w, h)
    local frame, bg = lcdColors(self)
    if cg(self) then
      CH(x, y, w, h, 4, frame); CH(x + 1, y + 1, w - 2, h - 2, 3, bg)
    else
      RR(x, y, w, h, 4, frame); RR(x + 1, y + 1, w - 2, h - 2, 3, bg)
    end
    R(x + 3, y + 2, w - 6, 1, { 1, 1, 1, 0.07 })
  end
  -- big seven-segment readout, scaled from the header clock's digits
  local function bigLcd(self, value, cx, y, scale, colon)
    local _, _, on, ghost = lcdColors(self)
    local G = ui.graphics
    local w = K.lcdWidth(value) * scale
    G.push(); G.translate(cx - floor(w / 2), y); G.scale(scale, scale)
    K.lcd(value, 0, 0, on, ghost, colon)
    G.pop()
    return w
  end
  local pgIconBounds = {}
  local function pgIcon(self, icon, x, y, w, h)
    local bounds = pgIconBounds[icon]
    if not bounds then
      local spec = K.iconArt[icon]
      if not spec then return end
      local left, top, right, bottom = 24, 24, -1, -1
      for j, row in ipairs(spec.rows) do
        for i = 1, #row do
          if row:sub(i, i) ~= "." then
            left, top, right, bottom = min(left, i - 1), min(top, j - 1), max(right, i - 1), max(bottom, j - 1)
          end
        end
      end
      bounds = { left, top, right - left + 1, bottom - top + 1 }
      pgIconBounds[icon] = bounds
    end
    self:v4Icon(icon, x + floor((w - bounds[3]) / 2) - bounds[1], y + floor((h - bounds[4]) / 2) - bounds[2])
  end
  local function seatIcon(self, icon, x, y, d, accent, lit)
    local c = self.colors
    CIRC(x, y, d, c.outline)
    CIRC(x + 1, y + 1, d - 2, lit and mix(WHITE, accent, 0.18) or mix(c.surface, accent, self.dark and 0.3 or 0.16))
    K.CIRCrows(x + 1, y + 1, d - 2, floor((d - 2) / 2), d - 2,
      lit and mix(WHITE, accent, 0.3) or mix(c.surface, accent, self.dark and 0.42 or 0.26))
    pgIcon(self, icon, x, y, d, d)
  end
  local function litText(self, lit, value, x, y, ink, w, align)
    if lit then self:withoutShadow(self.partyInfo, self, value, x, y, WHITE, w, align)
    else self:partyInfo(value, x, y, ink, w, align) end
  end
  local function arrowKey(self, x, y, w, h, art, enabled)
    local pressed = self:beginPress(x, y, w, h, enabled ~= false)
    self:v4Key(x, y, w, h)
    ART(art, x + floor((w - 11) / 2), y + floor((h - 6) / 2) - 1, { ["#"] = self.tok.acc.M })
    self:endPress(pressed)
  end

  function H:pokegearScreen(m, Page)
    local c = self.colors
    local G = ui.graphics
    if m.mode == "strip" then
      local enter = self:v4Enter("pokegear", "strip:" .. #m.cards, 0.24)
      for i, r in ipairs(Page.tiles(#m.cards)) do
        local card = m.cards[i]
        local _, dy = self:v4Stagger(enter, i, 0.07, 10, #m.cards)
        if dy ~= 0 then G.push(); G.translate(0, dy) end
        local x, y, w, h = r[1], r[2], r[3], r[4]
        local accent = pgAccent(self, card.id)
        local lit = card.index == m.cardIndex
        local pressed = self:beginPress(x, y, w, h, true)
        local off = 0
        if lit then off = self:v4Button(x, y, w, h, K.rampOf(accent), { radius = 6, lip = 3, chamfer = 5 })
        else self:v4Window(x, y, w, h, { radius = 5 }) end
        local d = 34
        seatIcon(self, card.icon, x + floor((w - d) / 2), y + 5 + off, d, accent, lit)
        litText(self, lit, self:fitPartyInfo(card.label, w - 8), x + 4, y + h - 18 + off, c.ink, w - 8, "center")
        if self.nativeFocus and lit then self:focusFrame(x, y, w, h) end
        self:endPress(pressed)
        if dy ~= 0 then G.pop() end
      end
      -- the device's clock, always at hand under the cards
      local clock = m.clock
      if clock then
        lcdPanel(self, 7, 172, 226, 38)
        local _, _, on = lcdColors(self)
        local colon = floor(self:clock()) % 2 == 0
        self:wantAmbient(1)
        local time = string.format("%d:%02d", clock.h12, clock.minute)
        bigLcd(self, time, 120, 182, 2, colon)
        self:withoutShadow(function()
          self:partyInfo(clock.day, 16, 185, on, 70)
          self:partyInfo(clock.pm and "PM" or "AM", 196, 185, on, 30)
        end)
      end
      return
    end

    -- tab rail: switch cards in place
    local current = m.card
    for i, r in ipairs(Page.tabs(#m.cards)) do
      local card = m.cards[i]
      local x, y, w, h = r[1], r[2], r[3], r[4]
      local accent = pgAccent(self, card.id)
      local lit = card.id == current
      local pressed = self:beginPress(x, y, w, h, not lit and not m.busy)
      local off = 0
      if lit then off = self:v4Button(x, y, w, h, K.rampOf(accent), { radius = 5, lip = 3, chamfer = 4 })
      else self:v4Window(x, y, w, h, { radius = 4, fill = m.busy and c.bandLight or nil }) end
      local faceH = h - (lit and 3 or 0)
      if w >= 100 then
        pgIcon(self, card.icon, x + 6, y + off, 28, faceH)
        litText(self, lit, self:fitPartyInfo(card.label, w - 42), x + 36, y + 6 + off, c.ink, w - 42)
      else
        pgIcon(self, card.icon, x, y + off, w, faceH)
      end
      self:endPress(pressed)
    end

    local accent = pgAccent(self, current)
    local enter = self:v4Enter("pokegear_card", tostring(current), 0.18)
    local _, dy = self:v4Stagger(enter, 1, 0, 8, 1)
    if dy ~= 0 then G.push(); G.translate(0, dy) end
    if m.clock then
      local clock = m.clock
      lcdPanel(self, 7, 62, 226, 104)
      local _, _, on = lcdColors(self)
      self:withoutShadow(function() self:partyInfo(clock.day, 7, 72, on, 226, "center") end)
      local colon = floor(self:clock()) % 2 == 0
      self:wantAmbient(1)
      bigLcd(self, string.format("%d:%02d", clock.h12, clock.minute), 120, 94, 5, colon)
      self:withoutShadow(function() self:partyInfo(clock.pm and "PM" or "AM", 7, 146, on, 226, "center") end)
    elseif m.phone then
      local p = m.phone
      if p.call then
        self:v4MessageWindow(7, 62, 226, 104)
        seatIcon(self, "pg_phone", 104, 70, 32, accent, true)
        local lines = wrapLabel(self, p.call.text, 200, 4)
        for i, line in ipairs(lines) do self:label(line, 20, 106 + (i - 1) * 13, c.ink, 200, "center") end
        local pressed = self:beginPress(64, 172, 112, 32, true)
        local off = self:v4Button(64, 172, 112, 32, K.rampOf(hex("e05040")), { radius = 6, lip = 3, chamfer = 5 })
        self:withoutShadow(self.partyInfoCentered, self, translate("END"), 64, 172 + off, 112, 28, WHITE)
        self:endPress(pressed)
      else
        local page = m.phonePage or 1
        for i = 1, Page.PHONE_PAGE do
          local row = p.rows[(page - 1) * Page.PHONE_PAGE + i]
          if row then
            local x, y, w, h = Page.phoneRow(i)
            local lit = row.selected
            local pressed = self:beginPress(x, y, w, h, not p.submenu)
            local off = 0
            if lit then off = self:v4Button(x, y, w, h, K.rampOf(accent), { radius = 5, lip = 3, chamfer = 4 })
            else self:v4Window(x, y, w, h, { radius = 4 }) end
            pgIcon(self, "pg_phone", x + 2, y + off, 28, h - (lit and 3 or 0))
            local nameW = row.class and 104 or 186
            litText(self, lit, self:fitPartyInfo(row.name, nameW), x + 32, y + 6 + off, c.ink, nameW)
            if row.class then
              local ink = lit and WHITE or c.mutedInk
              self:withoutShadow(self.partyInfo, self, self:fitPartyInfo(row.class, 84), x + 138, y + 6 + off, ink, 84, "right")
            end
            self:endPress(pressed)
          end
        end
        if #p.rows == 0 then
          self:v4Window(7, 62, 226, 40, { radius = 4 })
          self:partyInfo("----------", 7, 76, c.mutedInk, 226, "center")
        end
        if (m.phonePages or 1) > 1 and not p.submenu then
          self:pageChevron(22, 193, false, true)
          self:partyInfoCentered(page .. "/" .. m.phonePages, 30, 186, 64, 14, c.ink)
          self:pageChevron(102, 193, true, true)
        end
        if not p.signal then
          self:v4Pill("NO SIGNAL", 233, 186, hex("e05040"), { right = true })
        end
        if p.submenu then
          self:systemOverlay(0.45)
          local n = #p.submenu.entries
          local w = floor((226 - (n - 1) * 6) / n)
          for i, label in ipairs(p.submenu.entries) do
            local x = 7 + (i - 1) * (w + 6)
            local lit = i == p.submenu.cursor
            local pressed = self:beginPress(x, 176, w, 30, true)
            local off = 0
            if lit then off = self:v4Button(x, 176, w, 30, K.rampOf(accent), { radius = 6, lip = 3, chamfer = 5 })
            else self:v4Key(x, 176, w, 30) end
            local shown = self:fitPartyInfo(label, w - 8)
            if lit then self:withoutShadow(self.partyInfoCentered, self, shown, x, 176 + off, w, 26, WHITE)
            else self:partyInfoCentered(shown, x, 176, w, 26, c.ink) end
            self:endPress(pressed)
          end
        end
      end
    elseif m.radio then
      local radio = m.radio
      lcdPanel(self, 45, 62, 150, 44)
      local _, _, on, ghost = lcdColors(self)
      local digits = radio.frequency:gsub("%.", "")
      local whole, frac = radio.frequency:match("^(%d+)%.(%d)$")
      if whole then
        -- whole and tenth apart, with the decimal point lit between them
        local ww, fw = K.lcdWidth(whole) * 2, K.lcdWidth(frac) * 2
        local x0 = 120 - floor((ww + 6 + fw) / 2)
        bigLcd(self, whole, x0 + floor(ww / 2), 68, 2, false)
        R(x0 + ww + 1, 84, 2, 2, on)
        bigLcd(self, frac, x0 + ww + 6 + floor(fw / 2), 68, 2, false)
      else
        bigLcd(self, digits, 120, 68, 2, false)
      end
      self:withoutShadow(function()
        self:partyInfo(self:fitPartyInfo(radio.name or "- - -", 140), 50, 89, radio.name and on or ghost, 140, "center")
      end)
      arrowKey(self, 7, 62, 34, 44, DOWN, radio.canTuneDown)
      arrowKey(self, 199, 62, 34, 44, UP, radio.canTuneUp)
      for i, row in ipairs(radio.stations) do
        local x, y, w, h = Page.stationRect(i)
        if y + h <= 214 then
          local lit = row.current
          local pressed = self:beginPress(x, y, w, h, true)
          local off = 0
          if lit then off = self:v4Button(x, y, w, h, K.rampOf(accent), { radius = 4, lip = 2, chamfer = 3 })
          else self:v4Window(x, y, w, h, { radius = 3 }) end
          local ink = lit and WHITE or c.mutedInk
          self:withoutShadow(self.partyInfo, self, row.frequency, x + 5, y + 4 + off, ink, 28)
          litText(self, lit, self:fitPartyInfo(row.name, w - 40), x + 35, y + 4 + off, c.ink, w - 40)
          self:endPress(pressed)
        end
      end
    elseif m.map then
      local map = m.map
      self:v4Window(7, 62, 226, 82, { radius = 5 })
      self:v4Pill(map.region, 15, 70, accent)
      if map.here then self:v4Pill("HERE", 225, 70, hex("e05040"), { right = true }) end
      self:partyName(self:fitPartyInfo(map.landmark, 200), 20, 96, c.ink, 200)
      if not map.here and map.player ~= "" then
        self:v4Icon("map", 18, 116)
        self:partyInfo(self:fitPartyInfo(map.player, 170), 46, 122, c.mutedInk, 170)
      end
      arrowKey(self, 7, 150, 110, 40, DOWN)
      arrowKey(self, 123, 150, 110, 40, UP)
    end
    if dy ~= 0 then G.pop() end
  end

end
