return function(CH, CIRC, H, K, R, RR, WHITE, cg, floor, hex, max, min, mix, translate, ui)
  local function qtyPill(self, text, x, y)
    local w = self:partyInfoWidth(text) + 8
    if cg(self) then CH(x - w, y, w, 11, 2, self.colors.outline); CH(x - w + 1, y + 1, w - 2, 9, 1, self.colors.bandLight)
    else RR(x - w, y, w, 11, 3, self.colors.outline); RR(x - w + 1, y + 1, w - 2, 9, 2, self.colors.bandLight) end
    self:partyInfo(text, x - w + 4, y - 1, self.colors.ink)
    return w
  end

  -- Item art fills its round seat: real item sprites keep their native
  -- pixels, the drawn pocket glyphs double up like the DS bag's big icons.
  function H:v4ItemInSeat(item, cx, cy, size, accent)
    local G = ui.graphics
    local sprite = item.itemSprite
    if sprite and not item.cancel then
      local big = math.max(sprite.width or 16, sprite.height or 16)
      local scale = big <= size and math.max(1, floor(size / big)) or size / big
      local w, h = (sprite.width or 16) * scale, (sprite.height or 16) * scale
      G.setColor(1, 1, 1, 1)
      local dx, dy = cx - floor(w / 2), cy - floor(h / 2)
      if sprite.quad then G.draw(sprite.image, sprite.quad, dx, dy, 0, scale, scale)
      else G.draw(sprite.image, dx, dy, 0, scale, scale) end
      return
    end
    local aw, ah = 15, 15
    if self.v4ItemArtDims then aw, ah = self:v4ItemArtDims(item) end
    local scale = max(1, min(3, floor((size + 2) / max(aw, ah))))
    G.push()
    G.translate(cx - floor(17 * scale / 2), cy - floor(17 * scale / 2))
    G.scale(scale, scale)
    self:battleItemIcon(item, 0, 0, accent)
    G.pop()
  end

  function H:bagCard(item, x, y)
    local colors = self.colors
    local accent = self:itemAccent(item.icon)
    local pressed = self:beginPress(x, y, 112, 43)
    self:v4Window(x, y, 112, 43, { radius = 4 })
    -- round item slot
    CIRC(x + 4, y + 4, 35, colors.outline)
    CIRC(x + 5, y + 5, 33, mix(colors.surface, accent, self.dark and 0.3 or 0.22))
    K.CIRCrows(x + 5, y + 5, 33, 17, 33, mix(colors.surface, accent, self.dark and 0.42 or 0.34))
    R(x + 13, y + 7, 6, 1, { 1, 1, 1, self.dark and 0.18 or 0.6 })
    self:v4ItemInSeat(item, x + 21, y + 21, 30, accent)
    self:partyName(item.label or translate("ITEM"), x + 41, y + 5, colors.ink, 62)
    local count = ("×%d"):format(tonumber(item.count) or 0)
    if item.detail then
      self:partyInfo(self:fitPartyInfo(item.detail, 62), x + 41, y + 17, colors.green, 62)
    end
    qtyPill(self, count, x + 106, y + 28)
    self:detailChevron(x + 104, y + 7, colors.mutedInk, false)
    self:endPress(pressed)
  end

  function H:bagOverview(model)
    local colors = self.colors
    local amber = hex("e0a020")
    self:v4Window(6, 34, 228, 34)
    R(8, 36, 224, 3, mix(colors.surface, amber, 0.5))
    self:battleBagIcon(13, 38)
    local pockets = model.pockets or 1
    if pockets > 1 then
      self:pageChevron(58, 51, false)
      self:pageChevron(166, 51, true)
    end
    -- pocket name on a tab
    local labelX, labelW = pockets > 1 and 68 or 53, pockets > 1 and 88 or 118
    local name = self:fitPartyInfo(model.pocket or translate("ITEMS"), labelW - 8)
    if cg(self) then CH(labelX, 41, labelW, 18, 4, self.tok.acc.M)
    else
      RR(labelX, 41, labelW, 18, 4, colors.outline)
      RR(labelX + 1, 42, labelW - 2, 16, 3, hex("c07a10"))
      RR(labelX + 1, 42, labelW - 2, 13, 3, amber)
      R(labelX + 4, 42, labelW - 8, 1, hex("f8d878"))
    end
    self:partyInfo(name, labelX, 43, WHITE, labelW, "center")
    -- pocket dots
    if pockets > 1 and pockets <= 8 then
      local current = model.pocketIndex or 1
      for i = 1, pockets do
        local dx = labelX + floor(labelW / 2) - floor((pockets * 6 - 2) / 2) + (i - 1) * 6
        R(dx, 61, 4, 2, i == current and amber or colors.band)
      end
    end
    local page = ("%d/%d"):format(model.page or 1, model.pages or 1)
    self:v4Window(184, 42, 43, 18, { radius = 3, fill = colors.bandLight, shadow = false })
    self:pageChevron(190, 51, false, (model.pages or 1) > 1)
    self:partyInfo(page, 197, 45, colors.ink, 23, "center")
    self:pageChevron(222, 51, true, (model.pages or 1) > 1)
    if model.recent then self:recentBagItem(model.recent, 72, model.canUse) end
    if #(model.entries or {}) == 0 then
      local top = model.recent and 115 or 91
      self:v4MessageWindow(24, top, 192, 70)
      self:partyInfo(translate("THIS POCKET IS EMPTY."), 24, top + 29, colors.mutedInk, 192, "center")
      return
    end
    -- a new pocket deals its cards in, left to right, row by row
    local enter = self:v4Enter("bag_cards", tostring(model.pocket) .. ":" .. tostring(model.page), 0.26)
    local G = ui.graphics
    for index, item in ipairs(model.entries or {}) do
      local col, row = (index - 1) % 2, floor((index - 1) / 2)
      local _, dy = self:v4Stagger(enter, index, 0.06, 8, 6)
      if dy ~= 0 then G.push(); G.translate(0, dy) end
      self:bagCard(item, 6 + col * 116, (model.recent and 109 or 72) + row * 47)
      if dy ~= 0 then G.pop() end
    end
  end

  function H:bagDetail(model)
    local item, colors = model.detail, self.colors
    local accent = self:itemAccent(item.icon)
    self:v4Window(6, 34, 228, 62)
    R(8, 36, 224, 3, accent)
    CIRC(14, 41, 50, colors.outline)
    CIRC(15, 42, 48, mix(colors.surface, accent, self.dark and 0.3 or 0.22))
    K.CIRCrows(15, 42, 48, 24, 48, mix(colors.surface, accent, self.dark and 0.42 or 0.34))
    self:v4ItemInSeat(item, 39, 66, 40, accent)
    self:partyName(item.label or translate("ITEM"), 72, 44, colors.ink, 150)
    if item.detail then
      self:partyInfo(self:fitPartyInfo(item.detail, 150), 72, 58, colors.green)
    end
    qtyPill(self, ("×%d"):format(tonumber(item.count) or 0), 226, 80)
    local kinds = { machine = "TM / HM", medicine = "MEDICINE", ball = "POKé BALL", status = "STATUS CURE",
      key = "KEY ITEM", berry = "BERRY" }
    local kind = kinds[item.icon or ""] or "ITEM"
    if tostring(item.label or ""):match("^HM") then kind = "TM / HM" end
    self:v4Pill(translate(kind), 72, 78, accent, { raw = true, maxW = 110 })
    local lines = model.message or item.lines or {}
    self:v4MessageWindow(6, 100, 228, 50)
    local n = min(3, #lines)
    local top = 100 + floor((50 - n * 13) / 2)
    self:v4Prose(function()
      for index = 1, n do
        self:partyInfo(self:fitPartyInfo(lines[index], 196), 22, top + (index - 1) * 13, colors.ink, 196, "center")
      end
    end, { item.detail, item.label })
    local a = K.rampOf(hex("e0a020"))
    for index, action in ipairs(model.actions or {}) do
      local enabled = model.canUse ~= false and action.enabled ~= false
      local x, y, w, h = self:bagActionRect(index, #model.actions)
      local pressed = self:beginPress(x, y, w, h, enabled)
      local cancel = action.label == translate("CANCEL")
      local ramp = not enabled and K.rampOf(colors.silverDark)
        or cancel and K.rampOf(hex("5a6c88")) or a
      local off = self:v4Button(x, y, w, h, ramp, { radius = 5, lip = 4, chamfer = 5 })
      self:partyInfoCentered(action.label, x, y + off - 2, w, h, WHITE)
      self:endPress(pressed)
    end
  end

  ---------------------------------------------------------------------------
  -- Silph Store as a Silph Co. counter, not a phone app store: a bulletin
  -- board for news, a catalog of Game Pak-style cards, the apps on your
  -- Gear. Keys are DS keys with a glyph (install / open / locked).
  ---------------------------------------------------------------------------
  local SILPH_RED = hex("d84860")
  local SILPH_LOGO = { "....o....", "...ooo...", "..oo#oo..", ".oo###oo.", "oo##w##oo",
    ".oo###oo.", "..oo#oo..", "...ooo...", "....o...." }
  local KEY_G = {
    get = { "..o..", "..o..", "ooooo", ".ooo.", "..o..", "ooooo" },
    open = { "o....", "oo...", "ooo..", "oo...", "o...." },
    soon = { ".ooo.", "o...o", "ooooo", "oo.oo", "ooooo" },
  }
  return KEY_G, SILPH_LOGO, SILPH_RED
end
