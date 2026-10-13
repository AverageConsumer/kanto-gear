return function(ART, CH, CIRC, H, K, R, RING, RR, TONES, WHITE, cg, floor, hex, mix, translate, ui)
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
  -- NEW NOTE key with a pencil. Hit rectangles match ui/features/notes.lua.
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
  -- glyphs and a gliding lit tab (hits as in ui/features/notes.lua).
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
  return BOOK_G, FLAG_G
end
