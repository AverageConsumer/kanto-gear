return function(ART, BOOK_G, CH, CIRC, FLAG_G, H, K, R, RING, RR, TONES, WHITE, cg, floor, hex, max, min, mix, translate, ui)
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

  -- A trainer in a seat or on the link stage: the real overworld sprite when
  -- the game has it (main.lua picks a whole-pixel scale, or a bust when the
  -- sprite is taller than the room), else the Silph person glyph. row = nil
  -- is you; row = false forces the glyph.
  local function trainerSprite(self, row, cx, bottom, maxH, facing)
    local draw = self.pssDrawTrainer
    if row == false or not draw then return false end
    local ok, drawn = pcall(draw, row, cx, bottom, maxH, facing)
    return ok and drawn and true or false
  end
  local function trainerFigure(self, row, cx, bottom, maxH, facing, tint)
    if trainerSprite(self, row, cx, bottom, maxH, facing) then return true end
    local k = maxH >= 24 and 2 or 1
    local G = ui.graphics
    G.push(); G.translate(cx, bottom - 11 * k); G.scale(k, k)
    self:v4Person(0, 1, tint)
    G.pop()
    return false
  end
  -- soft floor shadow a figure stands on
  local function floorShadow(self, cx, y, w)
    local s = { 0, 0, 0, self.dark and 0.32 or 0.16 }
    local half = floor(w / 2)
    R(cx - half + 2, y, w - 4, 1, s); R(cx - half, y + 1, w, 1, s); R(cx - half + 2, y + 2, w - 4, 1, s)
  end
  H.v4TrainerFigure = trainerFigure

  -- Silph Connect profile card: avatar seat, name, game chip, status pill,
  -- an animated link line while waiting.
  function H:v4PssCard(name, game, status, mode, note, height, waiting, peer)
    local c = self.colors
    local accent = mode == "trade" and hex("3878d0") or mode == "battle" and hex("e05040")
      or mode == "ready" and c.hp or mode == "offline" and c.silverDark or (cg(self) and self.tok.acc.M or hex("3878d0"))
    self.v4SummaryWindow(self, 7, 33, 226, height, accent)
    -- avatar seat
    CIRC(14, 40, 44, c.outline)
    CIRC(15, 41, 42, mix(c.surface, accent, self.dark and 0.32 or 0.2))
    K.CIRCrows(15, 41, 42, 21, 42, mix(c.surface, accent, self.dark and 0.45 or 0.32))
    -- the peer in the seat; with no peer (left, unknown) the plain glyph
    trainerFigure(self, peer or false, 36, 80, 38, "down", accent)
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
    -- you on the left facing right, the peer on the right facing left; a
    -- trainer whose sprite this game lacks keeps the DS-device stand-in
    for i, dx in ipairs({ lx, rx }) do
      local cx, foot = dx + floor(dw / 2), ly + dh
      local who
      if i ~= 1 then who = peer or false end
      if room >= 34 then floorShadow(self, cx, foot - 1, 22) end
      if not (room >= 34 and trainerSprite(self, who, cx, foot, min(32, room - 2), i == 1 and "right" or "left")) then
        G.push(); G.translate(dx, ly); G.scale(scale, scale)
        ART(DEV, 0, 0, { o = c.outline, ["#"] = i == 1 and devC or accent, w = hex("d8f0e0") })
        G.pop()
      end
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
  -- player cards with game chips, and a pager. Hits match ui/features/pss.lua.
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
    trainerFigure(self, nil, 26, 59, 21, "down", accent)
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
      -- sonar rings around you, kept inside the box: they grow from the
      -- trainer and fade before they could reach its edge
      local t = self.motionEnabled == false and 0 or self:clock()
      local k = (t % 1.8) / 1.8
      if self.motionEnabled ~= false then self:wantAmbient(0.1, 1 / 15) end
      local cx, cy = 120, 124
      for i = 0, 2 do
        local p = (k + i / 3) % 1
        local d = 16 + floor(p * 18) * 2
        local fade = 1 - p
        RING(cx - floor(d / 2), cy - floor(d / 2), d, 1, mix(c.surface, accent, 0.15 + 0.35 * fade))
      end
      floorShadow(self, cx, cy + 9, 18)
      trainerFigure(self, nil, cx, cy + 10, 21, "down", c.silverDark)
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
        trainerFigure(self, row, x + 15, y + 25, 19, "down", ready and c.hp or hex("3878d0"))
        -- game chip
        local short = data.short[row.version] or "?"
        local cw = max(18, self:partyInfoWidth(short) + 8)
        if cg(self) then CH(x + 66 - cw, y + 6, cw, 11, 2, mix(gt, c.outline, 0.4)); CH(x + 67 - cw, y + 7, cw - 2, 9, 1, gt)
        else RR(x + 66 - cw, y + 6, cw, 11, 3, mix(gt, c.outline, 0.4)); RR(x + 67 - cw, y + 7, cw - 2, 9, 2, gt) end
        self:withoutShadow(self.partyType, self, short, x + 66 - cw, y + 5, WHITE, cw)
        local stText = tr(ready and "READY" or row.where == "launcher" and "IN MENU" or "ONLINE")
        local dot = ready and c.hp or row.where == "launcher" and c.silverDark or hex("3878d0")
        -- keep both lines inside the card's 2px inner margin
        local st = self:fitPartyInfo(stText, 38)
        local sw = self:partyInfoWidth(st)
        self:partyInfo(st, x + 67 - sw, y + 17, ready and c.green or c.mutedInk)
        if sw <= 32 then R(x + 62 - sw, y + 21, 3, 3, dot) end
        self:partyInfo(self:fitPartyInfo(row.name or "", 62), x + 5, y + 30, c.ink, 62, "center")
        self:endPress(pressed)
        if dy ~= 0 then G.pop() end
        hit(x, y, 72, 44, "player", row.id)
      end
    end
    -- pager, only when there is a second page
    local pages = state.pages or 1
    if pages <= 1 then return end
    local canPrev, canNext = state.page > 1, state.page < pages
    for _, p in ipairs({ { 7, -1, canPrev, { "..#", ".##", "###", ".##", "..#" } }, { 175, 1, canNext, { "#..", "##.", "###", "##.", "#.." } } }) do
      H.v4PagerKey(self, p[1], 190, 58, 21, p[2] < 0, p[3], true)
      if p[3] then hit(p[1], 190, 58, 21, "page", p[2]) end
    end
    self:partyInfoCentered(state.page .. "/" .. pages, 65, 190, 110, 19, c.ink)
  end

  -- Stamp-book find rows: kind icon, name, status pill, chevron.
end
