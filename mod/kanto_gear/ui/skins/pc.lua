-- Kanto Gear v4: PC — storage notice, box grid (nativeGrid) and the PC
-- terminal icon. Geometry comes from ui/pages/storage.lua / legacy views.
return function(H, ui, K)
  local floor, max, min = math.floor, math.max, math.min
  local R, P, RR, RRrows, CH, CHrows = K.R, K.P, K.RR, K.RRrows, K.CH, K.CHrows
  local CIRC, RING, ART = K.CIRC, K.RING, K.ART
  local mix, hex = K.mix, K.hex
  local cg, WHITE = K.cg, K.WHITE
  local translate = function(value) return ui.translate and ui.translate(value) or value end

  -- 31×26 PC terminal (pokemon) or item storage crate (items).
  function H:pcStorageIcon(x, y, kind)
    local colors = self.colors
    local t = self:clock()
    if kind == "items" then
      local wood, dark = hex("d89848"), hex("a06828")
      RR(x + 1, y + 4, 29, 20, 2, colors.outline)
      R(x + 2, y + 5, 27, 18, wood)
      R(x + 2, y + 5, 27, 2, mix(wood, WHITE, 0.35))
      for k = 0, 2 do R(x + 2, y + 10 + k * 5, 27, 1, dark) end
      R(x + 13, y + 9, 5, 5, colors.outline); R(x + 14, y + 10, 3, 3, hex("f8e070"))
      return
    end
    local case = self.dark and hex("9aa6b4") or hex("d8dee6")
    RR(x, y, 31, 21, 3, colors.outline)
    RR(x + 1, y + 1, 29, 19, 2, case)
    R(x + 3, y + 3, 25, 14, colors.outline)
    local glow = cg(self) and hex("40c8f0") or hex("58c890")
    R(x + 4, y + 4, 23, 12, mix(glow, { 0, 0, 0, 1 }, 0.55))
    -- scrolling text lines on the screen
    local s = self.motionEnabled == false and 0 or floor(t / 0.25) % 4
    for k = 0, 3 do
      local w = ({ 15, 9, 18, 12 })[((k + s) % 4) + 1]
      R(x + 6, y + 6 + k * 3, w, 1, glow)
    end
    self:wantAmbient(0.25)
    R(x + 12, y + 21, 7, 2, colors.outline)
    RR(x + 6, y + 23, 19, 3, 1, colors.outline)
    R(x + 7, y + 24, 17, 1, case)
    P(x + 26, y + 18, hex("e05040"))
  end

  function H:pcNotice(model)
    local colors = self.colors
    -- sit the terminal card on the screen's optical centre
    local G = ui.graphics
    G.push(); G.translate(0, 8)
    local offsetY = self.pressOffsetY
    self.pressOffsetY = (offsetY or 0) + 8
    local pressed = self:beginPress(12, 48, 216, 132)
    self:v4Window(12, 48, 216, 132)
    -- screen header band
    local accent = model and model.kind == "items" and hex("d89848") or (cg(self) and self.tok.acc.M or hex("3878d0"))
    local band = mix(colors.surface, accent, self.dark and 0.22 or 0.14)
    if cg(self) then CH(14, 50, 212, 46, 3, band) else RR(14, 50, 212, 46, 3, band) end
    -- data-stream stripes behind the terminal
    local s = self.motionEnabled == false and 0 or floor(self:clock() / 0.25) % 6
    for k = 0, 5 do
      local w = ({ 40, 22, 56, 30, 48, 18 })[((k + s) % 6) + 1]
      R(20, 54 + k * 7, w, 2, mix(band, accent, 0.35))
      R(220 - w, 57 + k * 7, w, 2, mix(band, accent, 0.35))
    end
    CIRC(98, 52, 44, colors.outline)
    CIRC(99, 53, 42, colors.surface)
    RING(99, 53, 42, 2, accent)
    self:pcStorageIcon(105, 61, model and model.kind)
    R(28, 99, 184, 1, colors.band)
    local lines = model and model.lines or { "..." }
    if #lines == 0 then lines = { "..." } end
    local y, lineHeight, visible = self:pcNoticeRows(#lines)
    -- the PC is talking: its words use the message-window face, like
    -- every other line the game says
    for index = 1, visible do
      self:label(self:fitLabel(lines[index], 184), 28, y - 1, colors.ink, 184, "center")
      y = y + lineHeight
    end
    self:v4AdvanceArrow(116, 163)
    self:endPress(pressed)
    self.pressOffsetY = offsetY
    G.pop()
  end

  ---------------------------------------------------------------------------
  -- PC lists: header plate with the terminal, then rows with a round seat —
  -- mon portrait, a big item prop, or an action glyph — like the DS PC menus.
  ---------------------------------------------------------------------------
  local LIST_TOP, LIST_H, LIST_GAP = 63, 33, 3
  local ACT = {
    withdraw = { tint = "3878d0", art = { "....o....", "...o#o...", "..o###o..", ".o#####o.", "...o#o...",
      "o..o#o..o", "o.......o", "ooooooooo" } },
    deposit = { tint = "48a858", art = { "...o#o...", "...o#o...", ".o#####o.", "..o###o..", "...o#o...",
      "o...o...o", "o.......o", "ooooooooo" } },
    stats = { tint = "4878d0", art = { "......oo.", "......##.", "...oo.##.", "...##.##.", "oo.##.##.",
      "##.##.##.", "##.##.##.", "ooooooooo" } },
    release = { tint = "d05878", art = { "..oo.oo..", ".o##o##o.", "o#######o", "o#######o", ".o#####o.",
      "..o###o..", "...o#o...", "....o...." } },
    box = { tint = "48a858", art = { "ooooooooo", "o#######o", "o#o###o#o", "o#######o", "ooooooooo",
      "o#######o", "o#######o", "ooooooooo" } },
    move = { tint = "e8a030", art = { "....o....", "...o#o...", "....#....", "o.o.#.o.o", "o#######o",
      "o.o.#.o.o", "....#....", "...o#o...", "....o...." } },
    print = { tint = "8890a0", art = { "..ooooo..", "..o###o..", "ooooooooo", "o#######o", "o###o#o#o",
      "ooooooooo", "..owwwo..", "..ooooo.." } },
    back = { art = { "..o......", ".oo......", "ooooooo..", ".oo....o.", "..o....o.", ".......o.", "..oooo..." } },
  }
  local function actionKind(entry)
    local l = tostring(entry.label or ""):upper()
    if entry.back or l:find("BACK") or l:find("CANCEL") or l:find("ZUR") or l:find("ABBR") then return "back" end
    if entry.kind == "box" or l:find("BOX") then return "box" end
    if l:find("WITHDRAW") or l:find("NEHMEN") or l:find("RETIRER") or l:find("SACAR") then return "withdraw" end
    if l:find("DEPOSIT") or l:find("ABLEGEN") or l:find("DÉPOSER") or l:find("DEJAR") then return "deposit" end
    if l:find("STAT") then return "stats" end
    if l:find("RELEASE") or l:find("FREI") or l:find("RELÂCH") or l:find("LIBER") then return "release" end
    if l:find("MOVE") then return "move" end
    if l:find("PRINT") then return "print" end
    return nil
  end

  function H:pcList(model)
    local colors = self.colors
    local entries = model.entries or {}
    local items = false
    for _, e in ipairs(entries) do if e.kind == "item" then items = true end end
    local accent = items and hex("d89848") or (cg(self) and self.tok.acc.M or hex("3878d0"))
    -- header plate: terminal glyph + summary
    self:v4Window(7, 34, 226, 24, { radius = 4 })
    R(9, 36, 222, 2, accent)
    local G = ui.graphics
    G.push(); G.translate(13, 38); G.scale(0.6, 0.6); self:pcStorageIcon(0, 0, items and "items" or "pokemon"); G.pop()
    self:partyInfo(self:fitPartyInfo(model.summary or translate("PC"), 180), 36, 40, colors.ink, 180, "center")
    if #entries == 0 then
      self:v4MessageWindow(24, 91, 192, 70)
      self:partyInfo(translate("NOTHING HERE"), 33, 120, colors.mutedInk, 176, "center")
      return
    end
    local enter = self:v4Enter("pc_list", tostring(model.summary) .. ":" .. #entries, 0.24)
    for index, entry in ipairs(entries) do
      local y = LIST_TOP + (index - 1) * (LIST_H + LIST_GAP)
      local _, dx = self:v4Stagger(enter, index, 0.08, 14, #entries)
      if dx ~= 0 then G.push(); G.translate(dx, 0) end
      local kind = not entry.mon and entry.kind ~= "item" and actionKind(entry)
      local back = kind == "back"
      local tint = back and colors.silverDark
        or entry.kind == "item" and hex("d89848")
        or kind and ACT[kind] and ACT[kind].tint and hex(ACT[kind].tint)
        or (cg(self) and self.tok.acc.M or hex("3878d0"))
      local focused = self.nativeFocus and entry.selected
      local pressed = self:beginPress(7, y, 226, LIST_H)
      if back then
        self:v4Key(7, y, 226, LIST_H)
      else
        self:v4Window(7, y, 226, LIST_H, { radius = 4,
          fill = focused and mix(colors.surface, tint, self.dark and 0.28 or 0.2) or nil })
        if focused then R(8, y + 4, 2, LIST_H - 8, tint) end
      end
      -- seat
      local sx, sy, d = 12, y + 2, 29
      if not back then
        CIRC(sx, sy, d, colors.outline)
        CIRC(sx + 1, sy + 1, d - 2, mix(colors.surface, tint, self.dark and 0.3 or 0.2))
        K.CIRCrows(sx + 1, sy + 1, d - 2, 14, d - 2, mix(colors.surface, tint, self.dark and 0.42 or 0.32))
      end
      if entry.mon and model.drawPokemon then
        model.drawPokemon(entry.mon, sx + 1, sy + 1, 27)
      elseif entry.kind == "item" then
        self:v4ItemInSeat(entry, sx + 14, sy + 14, 26, tint)
      elseif kind and ACT[kind] then
        local art = ACT[kind].art
        if back then
          ART(art, sx + floor((d - #art[1]) / 2), sy + floor((d - #art) / 2),
            { o = colors.mutedInk, ["#"] = tint, w = WHITE })
        else
          G.push(); G.translate(sx + floor((d - #art[1] * 2) / 2) + 1, sy + floor((d - #art * 2) / 2) + 1); G.scale(2, 2)
          ART(art, 0, 0, { o = colors.outline, ["#"] = tint, w = WHITE })
          G.pop()
        end
      end
      local left = 46
      local right = entry.right and tostring(entry.right) or nil
      local ink = back and colors.mutedInk or colors.ink
      if right then
        -- level / count in a quantity pill
        local rw = self:partyInfoWidth(right) + 8
        local rx = 210 - rw
        if cg(self) then CH(rx, y + 11, rw, 11, 2, colors.outline); CH(rx + 1, y + 12, rw - 2, 9, 1, colors.bandLight)
        else RR(rx, y + 11, rw, 11, 3, colors.outline); RR(rx + 1, y + 12, rw - 2, 9, 2, colors.bandLight) end
        self:partyInfo(right, rx + 4, y + 10, colors.ink)
        self:partyName(entry.label or tostring(index), left, y + 10, ink, rx - left - 6)
      else
        self:partyName(entry.label or tostring(index), left, y + 10, ink, 160)
      end
      if focused then
        local b = floor(self:clock() / 0.3) % 2
        self:wantAmbient(0.3)
        ART(K.CHEV_R, 219 + b, y + 14, { ["#"] = tint })
        self:focusFrame(7, y, 226, LIST_H)
      else
        ART(K.CHEV_R, 219, y + 14, { ["#"] = colors.mutedInk })
      end
      self:endPress(pressed)
      if dx ~= 0 then G.pop() end
    end
  end

  ---------------------------------------------------------------------------
  -- Native grids: PC box cells (mons) and action keys.
  ---------------------------------------------------------------------------
  local function boxCell(self, e, focused, drawIcon)
    local colors = self.colors
    local x, y, w, h = e.x, e.y, e.w, e.h
    local tile = cg(self) and (self.dark and hex("1d2a36") or hex("dcecf4"))
      or (self.dark and hex("2a4048") or hex("d8eccc"))
    local tile2 = mix(tile, colors.outline, 0.08)
    if cg(self) then CH(x, y, w, h, 3, colors.outline); CH(x + 1, y + 1, w - 2, h - 2, 2, tile)
    else RR(x, y, w, h, 3, colors.outline); RR(x + 1, y + 1, w - 2, h - 2, 2, tile) end
    -- soft floor shadow / checker
    R(x + 3, y + h - 6, w - 6, 3, tile2)
    if not e.rawMon then
      -- empty slot: faint ball watermark
      local m = mix(tile, colors.outline, 0.12)
      local d = min(w, h) - 14
      d = d - d % 2 + 1
      local cx, cy = x + floor(w / 2), y + floor(h / 2) - 1
      RING(cx - floor(d / 2), cy - floor(d / 2), d, 1, m)
      R(cx - floor(d / 2), cy, d, 1, m)
      CIRC(cx - 2, cy - 2, 5, tile); RING(cx - 2, cy - 2, 5, 1, m)
    end
    if e.rawMon and drawIcon then
      local size = min(h - 2, 32)
      local bob = 0
      if focused and self.motionEnabled ~= false then
        bob = floor(self:clock() / 0.25) % 2
        self:wantAmbient(0.25)
      end
      drawIcon(e.rawMon, x + floor((w - size) / 2), y + floor((h - size) / 2) - bob, size)
    end
    if focused then
      local hot = cg(self) and self.tok.acc.L or hex("f8b030")
      -- hand-cursor triangle above the cell
      ART({ "#####", ".###.", "..#.." }, x + floor(w / 2) - 2, y + 1, { ["#"] = hot })
      self:focusFrame(x, y, w, h)
    end
  end

  function H:nativeGrid(model, drawIcon)
    local c = self.colors
    if model.name then
      self:v4Window(7, 34, 226, 29)
      self:partyInfoCentered(self:fitPartyInfo(model.name, 210), 7, 34, 226, 29, c.ink)
    end
    for _, e in ipairs(model.entries) do
      local x, y, w, h = e.x, e.y, e.w, e.h
      local focused = self.nativeFocus and e.selected and not e.disabled
      local pressed = self:beginPress(x, y, w, h, not e.disabled)
      if e.label == "" or (e.rawMon and e.label == nil) then
        boxCell(self, e, focused, drawIcon)
      elseif e.rawMon and drawIcon then
        if focused then self:v4Button(x, y, w, h, K.rampOf(self.tok.acc.M), { radius = 4, lip = 3, chamfer = 4 })
        else self:v4Key(x, y, w, h) end
        local size = min(h - 4, 32)
        local ink = focused and WHITE or c.ink
        if h > 60 then
          drawIcon(e.rawMon, x + floor((w - size) / 2), y + floor((h - size - 18) / 2), size)
          self:partyInfo(self:fitPartyInfo(e.label, w - 8), x + 4, y + floor((h + size) / 2), ink, w - 8, "center")
        else
          drawIcon(e.rawMon, x + 3, y + floor((h - 2 - size) / 2), size)
          self:partyInfo(self:fitPartyInfo(e.label, w - size - 10), x + size + 6, y + floor((h - 3 - 9) / 2), ink, w - size - 10, "center")
        end
      else
        -- box title plate ("BOX 3  12/20") vs action keys
        local plate = tostring(e.label or ""):find("%d+/%d+") ~= nil
        if plate then
          -- box wallpaper: diamond lattice, a name tag in the middle, round arrow keys
          local wall = cg(self) and self.tok.acc.M or hex("58a868")
          if cg(self) then CH(x, y, w, h, 3, c.outline); CH(x + 1, y + 1, w - 2, h - 2, 2, wall)
          else RR(x, y, w, h, 3, c.outline); RR(x + 1, y + 1, w - 2, h - 2, 2, wall) end
          local lat = mix(wall, WHITE, 0.16)
          for gx = x + 4, x + w - 6, 8 do
            for gy = y + 3, y + h - 5, 6 do
              local o = ((gx - x) / 8 + (gy - y) / 6) % 2 == 0 and 0 or 4
              P(gx + o, gy, lat); P(gx + o - 1, gy + 1, lat); P(gx + o + 1, gy + 1, lat); P(gx + o, gy + 2, lat)
            end
          end
          local label = self:fitPartyInfo(e.label, w - 60)
          local tw = self:partyInfoWidth(label) + 16
          local tx = x + floor((w - tw) / 2)
          local tag = self.dark and hex("e8eef0") or WHITE
          if cg(self) then CH(tx, y + 3, tw, h - 6, 2, c.outline); CH(tx + 1, y + 4, tw - 2, h - 8, 1, tag)
          else RR(tx, y + 3, tw, h - 6, 3, c.outline); RR(tx + 1, y + 4, tw - 2, h - 8, 2, tag) end
          self:withoutShadow(self.partyInfoCentered, self, label, tx, y + 2, tw, h - 6, hex("283036"))
          for _, side in ipairs({ { x + 4, { "..#", ".##", "###", ".##", "..#" } }, { x + w - 19, { "#..", "##.", "###", "##.", "#.." } } }) do
            local bx, by = side[1], y + floor((h - 15) / 2)
            CIRC(bx, by, 15, c.outline); CIRC(bx + 1, by + 1, 13, WHITE)
            ART(side[2], bx + 6, by + 5, { ["#"] = wall })
          end
          if focused then self:focusFrame(x, y, w, h) end
        else
          local kind = actionKind(e)
          local spec = kind and ACT[kind]
          local tint = spec and spec.tint and hex(spec.tint) or self.tok.acc.M
          local off = 0
          if focused then off = self:v4Button(x, y, w, h, K.rampOf(tint), { radius = 4, lip = 3, chamfer = 4 }) or 0
          else self:v4Key(x, y, w, h, e.disabled and { cap = c.bandLight, lip = c.band, hi = c.bandLight } or nil) end
          local label = self:fitPartyInfo(e.label, w - 22)
          local ink = focused and WHITE or e.disabled and c.mutedInk or c.ink
          if spec then
            local lw = self:partyInfoWidth(label)
            local gw = #spec.art[1] + 4
            local gx = x + floor((w - gw - lw) / 2)
            ART(spec.art, gx, y + floor((h - 3 - #spec.art) / 2) + off,
              { o = focused and WHITE or c.outline, ["#"] = focused and WHITE or (spec.tint and tint or c.mutedInk), w = WHITE })
            self:partyInfo(label, gx + gw, y + floor((h - 3 - 9) / 2) - 1 + off, ink)
          else
            self:partyInfoCentered(label, x, y + off, w, h - 3, ink)
          end
        end
      end
      self:endPress(pressed)
    end
  end
end
