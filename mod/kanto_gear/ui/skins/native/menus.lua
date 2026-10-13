return function(ART, CH, CIRC, H, K, P, R, RR, WHITE, cg, floor, hex, min, mix, translate, ui)
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
        self:battleTargetLabels(entry, bx, by, bw, bh)
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
  -- Move selection / learning (ui/pages/move.lua geometry)
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
  return TONES
end
