-- Kanto Gear v4: PC — storage notice, box grid (nativeGrid) and the PC
-- terminal icon. Geometry comes from storage_page.lua / legacy views.
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
    local pressed = self:beginPress(12, 48, 216, 132)
    self:v4Window(12, 48, 216, 132)
    -- screen header band
    local accent = model and model.kind == "items" and hex("d89848") or (cg(self) and self.tok.acc.M or hex("3878d0"))
    if cg(self) then R(13, 52, 2, 124, accent) else RR(14, 50, 212, 46, 3, mix(colors.surface, accent, self.dark and 0.18 or 0.1)) end
    self:pcStorageIcon(104, 58, model and model.kind)
    R(28, 99, 184, 1, colors.band)
    local lines = model and model.lines or { "..." }
    if #lines == 0 then lines = { "..." } end
    local y, lineHeight, visible = self:pcNoticeRows(#lines)
    for index = 1, visible do
      self:partyInfo(self:fitPartyInfo(lines[index], 184), 28, y, colors.ink, 184, "center")
      y = y + lineHeight
    end
    self:v4AdvanceArrow(116, 163)
    self:endPress(pressed)
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
    if e.disabled and not e.rawMon then
      R(x + floor(w / 2) - 3, y + floor(h / 2), 6, 1, colors.band)
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
          local wall = cg(self) and self.tok.acc.M or hex("58a868")
          if cg(self) then CH(x, y, w, h, 3, c.outline); CH(x + 1, y + 1, w - 2, h - 2, 2, wall)
          else RR(x, y, w, h, 3, c.outline); RR(x + 1, y + 1, w - 2, h - 2, 2, wall)
            for k = 0, floor(w / 8) do R(x + 2 + k * 8, y + 2, 4, h - 4, mix(wall, WHITE, 0.12)) end end
          if focused then self:focusFrame(x, y, w, h) end
          self:withoutShadow(self.partyInfoCentered, self, self:fitPartyInfo(e.label, w - 24), x, y, w, h, WHITE)
          ART({ "..#", ".##", "###", ".##", "..#" }, x + 6, y + floor(h / 2) - 2, { ["#"] = WHITE })
          ART({ "#..", "##.", "###", "##.", "#.." }, x + w - 9, y + floor(h / 2) - 2, { ["#"] = WHITE })
        else
          if focused then self:v4Button(x, y, w, h, K.rampOf(self.tok.acc.M), { radius = 4, lip = 3, chamfer = 4 })
          else self:v4Key(x, y, w, h, e.disabled and { cap = c.bandLight, lip = c.band, hi = c.bandLight } or nil) end
          self:partyInfoCentered(self:fitPartyInfo(e.label, w - 8), x, y, w, h - 3,
            focused and WHITE or e.disabled and c.mutedInk or c.ink)
        end
      end
      self:endPress(pressed)
    end
  end
end
