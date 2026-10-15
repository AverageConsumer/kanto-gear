return function(ART, CIRC, H, K, WHITE, cg, floor, hex, min, mix, translate, ui)
  function H:v4FindRow(row, top, status, actionable, infoRight)
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
    local labelWidth = infoRight and math.max(0, min(120, infoRight - 44)) or 120
    self:partyInfo(self:fitPartyInfo(label, labelWidth), 40, top + 4, done and c.ink or c.mutedInk)
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

  -- Game path [Ruby/Sapphire vs Emerald]: the native device uses blue vs orange accents; C-Gear retains its own selected skin palette.
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
  -- touch face per card. Page (ui/pages/pokegear.lua) owns the shared geometry.
  ---------------------------------------------------------------------------
  local PG_TINT = { clock = "e05040", map = "48a858", phone = "5878c8", radio = "f0a030" }
  local UP = { ".....#.....", "....###....", "...#####...", "..#######..", ".#########.", "###########" }
  local DOWN = { "###########", ".#########.", "..#######..", "...#####...", "....###....", ".....#....." }
  return DOWN, PG_TINT, UP, wrapLabel
end
