-- Day-Care app and Home widgets. Every hit region is emitted by the same
-- layout that paints it; nothing here reads or writes game state.
return function(H, G, translate, format)
  local floor = math.floor
  local function rect(x, y, w, h, tint)
    G.setColor(tint); G.rectangle("fill", x, y, w, h)
  end
  local HEART = { ".##.##.", "#######", "#######", ".#####.", "..###..", "...#..." }
  local BROKEN = { ".##.##.", "###.###", "##.####", ".##.##.", "..#.#..", "...#..." }
  local EGG = {
    "....oooo....", "...oaaaao...", "..oaaaaaao..", "..oahaaado..", ".oahaaaaado.",
    ".oaaaaaddao.", "oaddaaaaaabo", "oaddaaaaabbo", "oaaaaaadabbo", "oaaaaaaabbbo",
    ".oaaaabbbbo.", ".oobbbbbboo.", "...oooooo...",
  }
  local function art(rows, x, y, palette)
    for row, line in ipairs(rows) do
      local runX, runTint, runW
      for column = 1, #line + 1 do
        local tint = palette[line:sub(column, column)]
        if tint ~= runTint or tint == nil then
          if runTint then rect(x + runX - 1, y + row - 1, runW, 1, runTint) end
          runX, runTint, runW = column, tint, 1
        else
          runW = runW + 1
        end
      end
    end
  end
  local function eggArt(self, x, y, wobble, scale)
    local c = self.colors
    local spot = self.dark and { .42, .78, .52, 1 } or { .36, .74, .45, 1 }
    local palette = { o = c.outline, a = { 1, .98, .94, 1 }, b = { .9, .86, .76, 1 },
      h = { 1, 1, 1, 1 }, d = spot }
    if wobble and self.motionEnabled ~= false then
      -- A waiting egg rocks once a second; still otherwise.
      local phase = floor(self:clock() * 4) % 8
      local dx = ({ 0, -1, 0, 1, 0, 0, 0, 0 })[phase + 1]
      self:wantAmbient(0.3)
      x = x + dx * (scale or 1)
    end
    if scale and scale ~= 1 then
      G.push(); G.translate(x, y); G.scale(scale, scale)
      art(EGG, 0, 0, palette); G.pop()
    else art(EGG, x, y, palette) end
  end
  H.daycareEggArt = eggArt
  local function heart(self, x, y, tier)
    local c = self.colors
    local tint = tier == 3 and { .9, .27, .42, 1 } or tier == 2 and { .95, .5, .62, 1 }
      or tier == 1 and { .78, .62, .68, 1 } or c.silverDark
    art(tier == 0 and BROKEN or HEART, x, y, { ["#"] = tint })
  end
  H.daycareHeart = heart

  local function fitted(self, value, width) return self:fitPartyInfo(value, width) end
  local function small(self, value, x, y, width, tint, align)
    local label = self:fitPartyInfo(value, width)
    if align == "center" then self:partyInfoCentered(label, x - 4, y, width + 8, 10, tint)
    else self:partyInfo(label, x, y, tint, width, align) end
  end
  -- Two lines when one does not fit; never cut a word the player needs. A
  -- sentence is cased as one block of prose across both lines.
  local function wrapped(self, value, x, y, width, tint, align)
    local lines = 1
    local function draw()
      local a, b = self:splitPartyInfo(value, width)
      if b then
        small(self, a, x, y, width, tint, align)
        small(self, b, x, y + 10, width, tint, align)
        lines = 2
      else
        small(self, a, x, y + 5, width, tint, align)
      end
    end
    if self.v4Prose and tostring(value):find("[%.!?]$") then self:v4Prose(draw) else draw() end
    return lines
  end
  H.v4Wrapped = wrapped

  local function levelLine(self, parent, x, y, width)
    local c = self.colors
    local from, now = format("L%d", parent.levelFrom), format("L%d", parent.levelNow)
    local fromW = self:partyInfoWidth(from)
    if parent.grown <= 0 then
      self:partyInfo(now, x, y, c.ink)
      return
    end
    self:partyInfo(from, x, y, c.mutedInk)
    self:detailChevron(x + fromW + 3, y + 4, c.mutedInk, false)
    local nowX = x + fromW + 9
    self:partyInfo(now, nowX, y, c.ink)
    local pillX = nowX + self:partyInfoWidth(now) + 4
    if pillX + 20 <= x + width then
      self:v4Pill(format("+%d", parent.grown), pillX, y + 1,
        self.dark and c.greenLight or c.green, { raw = true })
    end
  end

  function H:daycareHit(x, y)
    for _, hit in ipairs(self.daycareHits or {}) do
      if x >= hit.x and x < hit.x + hit.w and y >= hit.y and y < hit.y + hit.h then
        return hit.action, hit.value
      end
    end
  end

  -- Tabs a model offers, in order: the pair, its eggs, and FireRed/LeafGreen's
  -- Route 5 boarder. Gen 1 has only its one boarder and no tabs.
  function H:daycareTabs(model)
    if model.generation == 1 then return {} end
    local tabs = { { "DAY-CARE", "main" }, { "EGGS", "eggs" } }
    if model.boarder then tabs[#tabs + 1] = { model.boarder.place or "ROUTE 5", "boarder" } end
    return tabs
  end

  function H:daycare(model)
    local c = self.colors
    local accent = self.dark and c.greenLight or c.green
    local quiet = c.mutedInk
    self.daycareHits = {}
    local function hit(x, y, w, h, action, value)
      self.daycareHits[#self.daycareHits + 1] = { x = x, y = y, w = w, h = h, action = action, value = value }
    end
    local function card(x, y, w, h, action, value, draw)
      if action then hit(x, y, w, h, action, value) end
      local pressed = self:beginPress(x, y, w, h, action ~= nil)
      self:panel(x, y, w, h, false)
      draw()
      self:endPress(pressed)
    end
    local tabs = self:daycareTabs(model)
    local view = model.view or (model.generation == 1 and "boarder" or "main")
    local top = 34
    if #tabs > 0 then
      local choices = {}
      for index, tab in ipairs(tabs) do choices[index] = { tab[1], tab[2] } end
      self:v4Segments(6, 34, 228, choices, view, true, accent)
      local width = floor(228 / #tabs)
      for index, tab in ipairs(tabs) do
        if tab[2] ~= view then hit(6 + (index - 1) * width, 32, width, 21, "view", tab[2]) end
      end
      top = 56
    end

    local function boarderCard(parent, y, place)
      self:panel(6, y, 228, 60, false)
      if model.drawPokemon then model.drawPokemon(parent.mon, 12, y + 6, 48) end
      local name = fitted(self, parent.name or "", 150)
      self:partyInfo(name, 68, y + 4, c.ink)
      if parent.gender then self:genderIcon(parent.gender, 70 + self:partyInfoWidth(name), y + 6) end
      levelLine(self, parent, 68, y + 18, 158)
      small(self, format("FEE ¥%d", parent.fee), 68, y + 33, 158, quiet)
      if place then small(self, place, 68, y + 45, 158, quiet) end
    end
    -- The moveset the Pokemon comes back with: new moves lit, and the ones
    -- the Day-Care will overwrite named, because the game never asks.
    local function moveLists(parent, y, h)
      self:panel(6, y, 228, h, false)
      local learned = {}
      for _, move in ipairs(parent.learned) do learned[move] = true end
      small(self, translate("MOVES AT PICKUP"), 12, y + 3, 216, quiet)
      for index = 1, 4 do
        local move = parent.after[index]
        local x, top = 12 + (index - 1) % 2 * 110, y + 17 + math.floor((index - 1) / 2) * 15
        if move then
          local fresh = learned[move]
          local pill = fresh and translate("NEW") or nil
          local pillW = pill and math.min(40, self:partyInfoWidth(pill) + 9) or 0
          local label = fitted(self, move, fresh and 104 - pillW - 3 or 104)
          self:partyInfo(label, x, top, fresh and accent or c.ink)
          if fresh then
            self:v4Pill(pill, x + self:partyInfoWidth(label) + 3, top + 1,
              self.dark and c.greenLight or c.green, { raw = true, maxW = pillW })
          end
        else
          self:partyInfo("-", x, top, quiet)
        end
      end
      local forgotten = parent.forgotten or {}
      local row = y + 52
      if #forgotten > 0 then
        local label = translate("WILL FORGET")
        small(self, label, 12, row, 216, c.red)
        wrapped(self, table.concat(forgotten, ", "), 12, row + 6, 216, c.ink)
      elseif #parent.learned == 0 then
        wrapped(self, translate("NO NEW MOVES YET"), 12, row - 2, 216, quiet)
      end
    end

    if view == "boarder" or view == "parent" then
      local parent = view == "boarder" and (model.generation == 1 and model.parents[1] or model.boarder)
      if view == "parent" then
        for _, row in ipairs(model.parents) do if row.key == model.selected then parent = row end end
      end
      if not parent then
        self:panel(6, top + 20, 228, 80, false)
        eggArt(self, 108, top + 28, false, 2)
        wrapped(self, translate("NO POKEMON AT THE DAY-CARE"), 14, top + 62, 212, quiet, "center")
        return
      end
      boarderCard(parent, top, view == "boarder" and (model.boarder and model.boarder.place or model.place) or nil)
      moveLists(parent, top + 64, 76)
      if top + 144 <= 182 then
        -- How the stay works, once, below the facts it explains.
        self:panel(6, top + 144, 228, 210 - top - 144, false)
        wrapped(self, translate("GAINS 1 EXP PER STEP. THE FEE GROWS BY ¥100 PER LEVEL."),
          12, top + 147 + math.floor((210 - top - 150 - 20) / 2), 216, quiet, "center")
      end
      return
    end

    if view == "eggs" then
      local eggs = model.eggs or {}
      if #eggs == 0 then
        self:panel(6, 76, 228, 80, false)
        eggArt(self, 108, 84, false, 2)
        wrapped(self, translate("NO EGGS IN YOUR PARTY"), 14, 118, 212, quiet, "center")
        return
      end
      local stride, height = #eggs > 5 and 25 or 31, #eggs > 5 and 23 or 28
      for index, egg in ipairs(eggs) do
        if index <= 6 then
          local y = top + (index - 1) * stride
          self:panel(6, y, 228, height, false)
          local size = #eggs > 5 and 20 or 24
          if model.drawPokemon then model.drawPokemon(egg.mon, 9 + floor((24 - size) / 2), y + 1, size) end
          local title = egg.speciesName or translate("EGG")
          self:partyInfo(fitted(self, title, 96), 38, y + 2, c.ink)
          local right = egg.steps and format("~%d STEPS", egg.steps) or translate(egg.stageLabel or "")
          self:partyInfo(fitted(self, right, 92), 136, y + 2, egg.stage == 1 and accent or quiet, 92, "right")
          rect(38, y + 18, 190, 4, c.band)
          if egg.stage then
            local share = ({ 1, .72, .42, .16 })[egg.stage]
            if egg.steps and egg.total and egg.total > 0 then share = 1 - egg.steps / egg.total end
            rect(38, y + 18, floor(190 * math.max(0.04, math.min(1, share))), 4,
              egg.stage == 1 and (self.dark and c.amberLight or c.amber) or accent)
          end
        end
      end
      if model.hatchBoost and #eggs <= 4 then
        small(self, translate("HATCHING BOOST ACTIVE"), 6, top + #eggs * 31 + 2, 228, accent)
      end
      return
    end

    -- Pair view: the two boarders, how they get along, and the next egg.
    local parents = model.parents or {}
    if #parents == 0 then
      self:panel(6, 76, 228, 80, false)
      eggArt(self, 108, 84, false, 2)
      wrapped(self, translate("NO POKEMON AT THE DAY-CARE"), 14, 112, 212, quiet, "center")
      small(self, model.place or "", 14, 138, 212, quiet, "center")
      return
    end
    for index = 1, 2 do
      local parent, x = parents[index], index == 1 and 6 or 125
      if parent then
        card(x, 55, 109, 54, "parent", parent.key, function()
          if model.drawPokemon then model.drawPokemon(parent.mon, x + 3, 66, 32) end
          local name = fitted(self, parent.name or "", 64)
          self:partyInfo(name, x + 38, 58, c.ink)
          if parent.gender and self:partyInfoWidth(name) + 8 <= 68 then
            self:genderIcon(parent.gender, x + 40 + self:partyInfoWidth(name), 60)
          end
          levelLine(self, parent, x + 38, 71, 68)
          small(self, format("¥%d", parent.fee), x + 38, 85, 68, quiet)
          if #parent.learned > 0 then
            small(self, #parent.learned == 1 and translate("1 NEW MOVE")
              or format("%d NEW MOVES", #parent.learned), x + 38, 96, 68,
              self.dark and c.amberLight or c.amber)
          end
        end)
      else
        self:panel(x, 55, 109, 54, false)
        wrapped(self, translate("EMPTY SPOT"), x + 4, 70, 101, quiet, "center")
      end
    end
    local compat = model.compatibility
    if compat then
      heart(self, 116, 79, compat.tier)
      self:panel(6, 113, 228, 34, false)
      local label = translate(compat.label)
      local chance = compat.chance and format("%d%% PER CHECK", compat.chance) or nil
      local chanceW = chance and self:partyInfoWidth(chance) or 0
      self:partyInfo(fitted(self, label, 216 - chanceW - 6), 12, 116, c.ink)
      if chance then self:partyInfo(chance, 12, 116, quiet, 216, "right") end
      for segment = 1, 3 do
        local lit = segment <= compat.tier
        rect(12 + (segment - 1) * 73, 130, 70, 4, lit and (compat.tier == 3 and accent
          or self.dark and c.amberLight or c.amber) or c.band)
      end
      if compat.tip then
        small(self, translate("BEST: SAME SPECIES, OTHER TRAINER"), 12, 136, 216, quiet)
      end
    else
      self:panel(6, 113, 228, 34, false)
      wrapped(self, translate("LEAVE A SECOND POKEMON FOR EGGS"), 12, 115, 216, quiet, "center")
    end
    local egg = model.egg
    self:panel(6, 151, 228, 59, false)
    eggArt(self, 13, 166, egg and egg.waiting, 2)
    local x, w = 44, 184
    if egg and egg.waiting then
      self:partyInfo(fitted(self, translate("EGG WAITING!"), w), x, 156, accent)
      wrapped(self, translate("PICK IT UP FROM THE DAY-CARE MAN"), x, 166, w, quiet)
      if model.partyFull then
        self:v4Pill(translate("PARTY FULL"), x, 192, c.red, { raw = true, maxW = 120 })
      end
    elseif egg then
      local title = egg.stepsToCheck and format("NEXT EGG CHECK IN %d STEPS", egg.stepsToCheck)
        or translate("AN EGG CAN APPEAR")
      wrapped(self, title, x, 153, w, c.ink)
      if egg.speciesName then
        local prefix = translate("HATCHES INTO")
        local prefixW = self:partyInfoWidth(prefix)
        if prefixW + 6 + self:partyInfoWidth(egg.speciesName) <= w then
          self:partyInfo(prefix, x, 176, quiet)
          self:partyInfo(egg.speciesName, x + prefixW + 5, 176, c.ink)
        else
          self:partyInfo(fitted(self, egg.speciesName, w), x, 176, c.ink)
        end
        local pillX = x
        for _, move in ipairs(egg.moves or {}) do
          local label = self:fitPartyType(move, 80)
          local width = self:partyInfoWidth(label) + 9
          if pillX + width > x + w then break end
          self:v4Pill(label, pillX, 193, c.blue, { raw = true })
          pillX = pillX + width + 3
        end
      else
        wrapped(self, translate("WALK TO GIVE THEM TIME"), x, 172, w, quiet)
      end
    else
      wrapped(self, translate(#parents == 2 and "NO EGGS FROM THIS PAIR" or "ONE POKEMON CANNOT MAKE EGGS"),
        x, 165, w, quiet)
    end
  end

  -- Home widgets: the wide card shows both boarders and the headline, the
  -- small one only the headline.
  local function headline(self, model)
    local h = model.headline or { kind = "empty" }
    if h.kind == "egg_waiting" then return translate("EGG WAITING!"), model.place, 1 end
    if h.kind == "hatching" then
      local egg = h.egg
      return translate(egg.stage == 1 and "HATCHING SOON" or "EGG IN PARTY"),
        egg.steps and format("~%d STEPS", egg.steps) or translate(egg.stageLabel or ""),
        ({ 1, .72, .42, .16 })[egg.stage or 4]
    end
    if h.kind == "egg_check" then
      return translate("NEXT EGG CHECK"), format("%d STEPS", h.steps), 1 - h.steps / 256
    end
    if h.kind == "boarding" then
      local compat = model.compatibility
      if compat then return translate(compat.label), model.fees and format("FEE ¥%d", model.fees) or "", nil end
      local parent = model.parents[1] or model.boarder or { learned = {}, forgotten = {} }
      local moves = #parent.forgotten > 0 and (#parent.forgotten == 1 and translate("FORGETS 1 MOVE")
        or format("FORGETS %d MOVES", #parent.forgotten))
        or #parent.learned > 0 and (#parent.learned == 1 and translate("1 NEW MOVE")
        or format("%d NEW MOVES", #parent.learned)) or ""
      local fee = model.fees or parent.fee
      return fee and format("FEE ¥%d", fee) or translate("BOARDING"), moves, nil
    end
    return translate("NO POKEMON BOARDING"), model.place, nil
  end

  function H:homeDaycare(model, tile, selected)
    local c = self.colors
    local data = model.daycare or {}
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, c.red, selected)
    self:homeWidgetHeader(x, y, w, "DAY-CARE", c.green, c.greenLight, model.editing)
    local accent = self.dark and c.greenLight or c.green
    local parents = data.parents or {}
    if #parents == 0 and data.boarder then parents = { data.boarder } end
    if data.generation == 1 and data.parents[1] then parents = { data.parents[1] } end
    -- Left: the boarders with their grown levels; right: what happens next.
    local blockW = 92
    if #parents > 0 then
      local count = math.min(2, #parents)
      local slotW = count == 2 and 44 or blockW
      for index = 1, count do
        local parent = parents[index]
        local sx = x + 4 + (index - 1) * (slotW + 4)
        if data.drawPokemon then data.drawPokemon(parent.mon, sx + floor((slotW - 32) / 2), y + 19, 32) end
        local level = format("L%d", parent.levelNow)
        small(self, level, sx, y + 52, slotW, c.ink, "center")
        if parent.grown > 0 then
          small(self, format("+%d", parent.grown), sx, y + 63, slotW, accent, "center")
        end
      end
      if count == 2 and data.compatibility then heart(self, x + 46, y + 31, data.compatibility.tier) end
    else
      eggArt(self, x + floor((blockW - 24) / 2) + 4, y + 30, false, 2)
    end
    rect(x + blockW + 6, y + 21, 1, h - 28, c.band)
    local left = x + blockW + 13
    local width = x + w - 8 - left
    local first, second, share = headline(self, data)
    local lines = wrapped(self, first, left, y + 21, width, c.ink)
    if second and second ~= "" then
      small(self, second, left, y + 26 + lines * 10, width, c.mutedInk)
    end
    if share then
      rect(left, y + 69, width, 4, c.band)
      rect(left, y + 69, floor(width * math.max(0.04, math.min(1, share))), 4, accent)
    end
  end

  function H:homeDaycareSmall(model, tile, selected)
    local c = self.colors
    local data = model.daycare or {}
    local x, y, w, h = self:homeRect(tile)
    self:homeTile(x, y, w, h, c.red, selected)
    self:homeWidgetHeader(x, y, w, "EGGS", c.green, c.greenLight, model.editing)
    local first, second, share = headline(self, data)
    local kind = data.headline and data.headline.kind
    local lively = kind == "egg_waiting" or kind == "hatching" and data.headline.egg
      and data.headline.egg.stage == 1
    eggArt(self, x + floor((w - 24) / 2), y + 18, lively, 2)
    local lines = wrapped(self, first, x + 4, y + 45, w - 8, c.ink, "center")
    if lines == 1 and second and second ~= "" then
      small(self, second, x + 4, y + 60, w - 8, c.mutedInk, "center")
    end
    if share then
      local accent = self.dark and c.greenLight or c.green
      rect(x + 8, y + 71, w - 16, 4, c.band)
      rect(x + 8, y + 71, floor((w - 16) * math.max(0.04, math.min(1, share))), 4, accent)
    end
  end
end
