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
  function H:startMenu(model)
    local c = self.colors
    for _, entry in ipairs(model.entries) do
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
      for index, line in ipairs(lines) do
        self:partyInfo(self:fitPartyInfo(line, 200), 15, firstY + (index - 1) * 12,
          model.nudge and colors.amber or colors.ink, 210, "center")
      end
    end
    for _, entry in ipairs(model.entries or {}) do
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
        if cg(self) then R(x + 3, y + 4, 2, h - 10, tone) else R(x + 6, y + 2, w - 12, 2, tone) end
      end
      local ink = focused and WHITE or colors.ink
      self:partyInfo(self:fitPartyInfo(entry.label, w - 32), x + 16, y + floor((h - 3 - 9) / 2) - 1, ink, w - 32, "center")
      if focused then
        local b = floor(self:clock() / 0.3) % 2
        self:wantAmbient(0.3)
        ART(K.CHEV_R, x + 9 + b, y + floor((h - 3 - 5) / 2), { ["#"] = WHITE })
      end
      self:endPress(pressed)
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
      local left, width = paged and 36 or 14, paged and 168 or 212
      self:partyInfoCentered(self:fitPartyInfo(model.name or "", width), left, 36, width, 13, c.ink)
      local sub = paged and model.page .. "/" .. model.pages or model.prompt or ""
      self:partyInfoCentered(self:fitPartyInfo(sub, width), left, 50, width, 13, c.green)
      if paged and model.page > 1 then self:pageChevron(20, 50, false, model.enabled ~= false) end
      if paged and model.page < model.pages then self:pageChevron(220, 50, true, model.enabled ~= false) end
    end
    for index = 1, 4 do
      local move = model.moves[index] or { available = false, name = "-" }
      local x, y = Page.rect(index)
      self:summaryMoveRow(move, x, y, false, model.enabled ~= false and move.available ~= false,
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
    for index = 1, n do
      self:partyInfoCentered(self:fitPartyInfo(lines[index], 208), 14, firstY + (index - 1) * 11, 212, 11, c.ink)
    end
    for index, label in ipairs(model.choices or {}) do
      local x, y, w, h = Page.promptRect(index)
      local pressed = self:beginPress(x, y, w, h, enabled)
      local up = tostring(label):upper()
      local tone = POSITIVE[up] and (cg(self) and hex("1ea5d8") or hex("3ea04c")) or hex("5a6c88")
      local off = self:v4Button(x, y, w, h, K.rampOf(tone), { radius = 6, lip = 4, chamfer = 6 })
      self:partyInfoCentered(self:fitPartyInfo(label, w - 16), x + 8, y + off, w - 16, h - 5, WHITE)
      self:endPress(pressed)
    end
    if not enabled then self:systemOverlay(0.48) end
  end

  ---------------------------------------------------------------------------
  -- Small shared pieces for feature modules (Notes, Silph Connect)
  ---------------------------------------------------------------------------
  local TONES = { battle = "e05040", trade = "3878d0", negative = "5a6c88" }
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
    -- link illustration: two devices and a cable that pulses while waiting
    local ly = 33 + height - 22
    local DEV = { "oooooooo", "o######o", "o#wwww#o", "o#wwww#o", "o######o", "o#o##o#o", "oooooooo" }
    local devC = cg(self) and hex("40a8d8") or hex("58b078")
    ART(DEV, 82, ly, { o = c.outline, ["#"] = devC, w = hex("d8f0e0") })
    ART(DEV, 150, ly, { o = c.outline, ["#"] = accent, w = hex("d8f0e0") })
    local t = self:clock()
    for k = 0, 9 do
      local on = mode == "ready" or mode == "trade" or mode == "battle"
      local lit = on and (not waiting or (floor(t / 0.1) % 10) == k)
      R(93 + k * 5, ly + 3, 3, 1, lit and accent or c.band)
    end
    if note then
      R(15, 92, 210, 1, c.band)
      local a, b = self:splitPartyInfo(note, 204)
      self:partyInfo(a, 18, 98, c.mutedInk, 204, "center")
      if b then self:partyInfo(b, 18, 110, c.mutedInk, 204, "center") end
    end
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
    bag = { art = { "....oooo....", "...o####o...", "..oooooooo..", ".o########o.", "o##########o",
      "o#oooooooo#o", "o#o######o#o", "o#oooooooo#o", "o##########o", ".oooooooooo." }, pal = { ["#"] = "d8a048" } },
  }
  local function itemFamily(item)
    local name = tostring(item.label or item.name or item.displayLabel or ""):upper()
    if item.icon == "machine" or name:match("^TM") or name:match("^HM") then return "machine", name:match("^HM") and "hm" end
    if name:find("ROPE") then return "rope" end
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
end
