-- The Moments tab of the Stamp Book: a chronicle of earned moments (newest
-- first, nothing shown before it happens) and one page per moment. Also the
-- moment seal used on Gear notices.
return function(H, G, translate)
  local floor, max, min = math.floor, math.max, math.min
  local TONE = {
    gold = { { .83, .57, .18, 1 }, { 1, .85, .44, 1 }, { .55, .33, .06, 1 } },
    red = { { .80, .27, .22, 1 }, { .98, .62, .52, 1 }, { .52, .12, .10, 1 } },
    green = { { .24, .60, .30, 1 }, { .62, .88, .58, 1 }, { .10, .36, .16, 1 } },
    blue = { { .22, .47, .82, 1 }, { .58, .78, .98, 1 }, { .10, .26, .52, 1 } },
    purple = { { .55, .36, .78, 1 }, { .82, .70, .95, 1 }, { .30, .15, .48, 1 } },
  }
  local PAPER, INK = { .97, .97, .92, 1 }, { .08, .21, .20, 1 }

  -- 9 px wide marks: # tone, w paper.
  local GLYPH = {
    heart = { ".##...##.", "####.####", "##w######", "#########", ".#######.", "..#####..", "...###...", "....#...." },
    ball = { "..#####..", ".#.....#.", "#.......#", "#..###..#", "####.####", "#..###..#", "#.......#", ".#.....#.",
      "..#####.." },
    sparkle = { "....#....", "....#....", "...###...", "..#####..", "#########", "..#####..", "...###...", "....#....",
      "....#...." },
    star = { "....#....", "...###...", "...###...", "#########", ".#######.", "..#####..", ".###.###.", ".##...##.",
      "#.......#" },
    one = { "....##...", "...###...", "..####...", "....##...", "....##...", "....##...", "....##...", "..######." },
    target = { "..#####..", ".#.....#.", "#..###..#", "#.#...#.#", "#.#.#.#.#", "#.#...#.#", "#..###..#",
      ".#.....#.", "..#####.." },
    shield = { "#########", "####w####", "####w####", "#########", ".#######.", ".#######.", "..#####..",
      "...###...", "....#...." },
    arrow = { "....#....", "...###...", "..#####..", ".#######.", "#########", "...###...", "...###...",
      "...###...", "...###..." },
    swap = { "..####.#.", ".#....##.", "#....###.", "#........", "........#", ".###....#", ".##....#.",
      ".#.####.." },
    hourglass = { "#########", ".#######.", "..#####..", "...###...", "....#....", "...#.#...", "..#.#.#..",
      ".#.###.#.", "#########" },
    dice = { ".#######.", "#w#####w#", "#########", "####w####", "#########", "#w#####w#", ".#######." },
    crown = { "#...#...#", "##.###.##", "#########", "#########", "#w##w##w#", "#########" },
    zzz = { "#####....", "...#.....", "..#......", ".#...###.", "#####..#.", "......#..", ".....###." },
    wave = { "..##.....", ".#..#...#", "#....#.#.", "......#..", ".........", "..##.....", ".#..#...#",
      "#....#.#.", "......#.." },
    ghost = { "..#####..", ".#######.", "##w###w##", "##w###w##", "#########", "#########", "#.##.##.#" },
    tree = { "...###...", "..#####..", ".#######.", "#########", ".#######.", "..#####..", "....#....",
      "....#....", "..#####.." },
    trophy = { "#########", "#.#####.#", ".#.###.#.", "..#####..", "...###...", "....#....", "....#....",
      "..#####.." },
    letter = { "...###...", "..##.##..", ".##...##.", ".##...##.", ".#######.", ".##...##.", ".##...##." },
    bolt = { ".....###.", "....###..", "...###...", "..######.", "....###..", "...###...", "..##.....",
      ".#......." },
    egg = { "....#....", "...###...", "..#####..", "..##w##..", ".#######.", ".#w###w#.", ".#######.",
      "..#####..", "...###..." },
    virus = { "#...#...#", ".#.###.#.", "..#####..", ".###w###.", "..#####..", ".#.###.#.", "#...#...#" },
    fish = { "...###...", ".######.#", "#w#######", ".######.#", "...###..." },
  }

  local function rect(x, y, w, h, tint)
    G.setColor(tint); G.rectangle("fill", x, y, w, h)
  end
  local function disc(x, y, r, tint)
    for dy = -r, r do
      local half = floor(math.sqrt(r * r - dy * dy))
      rect(x - half, y + dy, half * 2 + 1, 1, tint)
    end
  end

  -- A round seal: ink rim, tone ring, paper face, the moment's mark.
  function H:momentSeal(cx, cy, r, glyph, tone)
    local c = self.colors
    local t = TONE[tone] or TONE.gold
    disc(cx + 1, cy + 2, r, c.shadow)
    disc(cx, cy, r, c.outline)
    disc(cx, cy, r - 1, t[1])
    disc(cx, cy, r - 3, c.outline)
    disc(cx, cy, r - 4, PAPER)
    local art = GLYPH[glyph] or GLYPH.star
    -- Whole-pixel scale that keeps the mark inside the paper face.
    local k = max(1, floor(2 * (r - 4) / 11))
    local h = #art
    local left, top = cx - floor(9 * k / 2), cy - floor(h * k / 2)
    for row, line in ipairs(art) do
      for col = 1, #line do
        local p = line:sub(col, col)
        if p == "#" then rect(left + (col - 1) * k, top + (row - 1) * k, k, k, t[3])
        elseif p == "w" then rect(left + (col - 1) * k, top + (row - 1) * k, k, k, PAPER) end
      end
    end
  end

  -- "ROUTE 29  12 OCT 2026": as much of where and when as the width allows.
  local function whereWhen(self, entry, width)
    local parts = {}
    if entry.place then parts[#parts + 1] = entry.place end
    if entry.date then parts[#parts + 1] = entry.date end
    local value = table.concat(parts, "  ")
    if value ~= "" and self:partyInfoWidth(value) <= width then return value end
    return entry.place or entry.date or ""
  end

  -- ctx = { hit, card, label, name } from the Stamp Book renderer.
  function H:momentsView(model, ctx)
    local c = self.colors
    local accent, quiet = self.dark and c.greenLight or c.green, c.mutedInk
    if model.view == "moment" and model.moment then return self:momentPage(model, ctx) end
    local list = model.moments or {}
    if #list == 0 then
      self:panel(6, 58, 228, 152, false)
      self:momentSeal(120, 104, 22, "star", "gold")
      ctx.name(translate("MOMENTS FIND YOU ALONG THE WAY"), 18, 134, 204, 24, c.ink)
      ctx.name(translate("EVERY STORY IS KEPT HERE"), 18, 162, 204, 24, quiet)
      return
    end
    -- Pager: page dots, never a count of moments.
    local pages = model.pages or 1
    if pages > 1 then
      ctx.hit(6, 54, 30, 19, "moment_page", -1); ctx.hit(204, 54, 30, 19, "moment_page", 1)
      G.push(); G.translate(25, 0); G.scale(-1, 1)
      self:detailChevron(3, 58, accent, true); G.pop()
      self:detailChevron(215, 58, accent, true)
      local shown = min(pages, 12)
      local width = shown * 7 - 3
      local x = 120 - floor(width / 2)
      for index = 1, shown do
        local on = index == min(model.page or 1, shown)
        rect(x + (index - 1) * 7, 61, 4, 4, on and accent or quiet)
      end
    else
      ctx.label(translate("YOUR MOMENTS"), 6, 56, 228, 14, quiet, true)
    end
    for index, entry in ipairs(list) do
      local top = 76 + (index - 1) * 45
      ctx.card(6, top, 228, 42, "moment", entry.id, function()
        self:momentSeal(25, top + 21, 15, entry.glyph, entry.tone)
        local right = 214
        if entry.species ~= nil and model.drawPokemon then
          pcall(model.drawPokemon, entry.species, 172, top + 5, 32, entry.shiny, false)
          right = 170
        end
        local width = right - 46
        self:partyInfo(self:fitPartyInfo(entry.title, width), 46, top + 4, c.ink)
        if entry.name then self:partyInfo(self:fitPartyInfo(entry.name, width), 46, top + 16, accent) end
        self:partyInfo(self:fitPartyInfo(whereWhen(self, entry, width), width), 46, top + 28, quiet)
        self:detailChevron(216, top + 17, accent, true)
      end)
    end
  end

  function H:momentPage(model, ctx)
    local c = self.colors
    local accent, quiet = self.dark and c.greenLight or c.green, c.mutedInk
    local m = model.moment
    self:panel(6, 34, 228, 88, false)
    self:momentSeal(36, 77, 24, m.glyph, m.tone)
    local right = 226
    if m.species ~= nil and model.drawPokemon then
      pcall(model.drawPokemon, m.species, 188, 60, 36, m.shiny, true)
      right = 186
    end
    -- Title and story as one block, centred beside the seal.
    local width = right - 66
    local lines = {}
    local a, b = self:splitPartyInfo(m.title, width)
    lines[#lines + 1] = { a, accent }; if b then lines[#lines + 1] = { b, accent } end
    local gapAt = #lines
    a, b = self:splitPartyInfo(m.line, width)
    lines[#lines + 1] = { a, quiet }; if b then lines[#lines + 1] = { b, quiet } end
    local y = 34 + floor((88 - (#lines * 11 + 5)) / 2)
    for index, line in ipairs(lines) do
      ctx.label(line[1], 66, y, width, 10, line[2])
      y = y + 11 + (index == gapAt and 5 or 0)
    end
    local rows = {}
    local function add(key, value) if value and value ~= "" then rows[#rows + 1] = { key, value } end end
    add("POKEMON", m.name)
    add("OPPONENT", m.foe ~= m.name and m.foe or nil)
    add("PLACE", m.place)
    add("DATE", m.date)
    add("PLAY TIME", m.play)
    while #rows > 4 do table.remove(rows) end
    if #rows == 0 then return end
    self:panel(6, 126, 228, 84, false)
    local step = 20
    local top = 128 + floor((80 - #rows * step) / 2)
    for index, row in ipairs(rows) do
      local y = top + (index - 1) * step
      if index > 1 then rect(14, y - 1, 212, 1, c.band) end
      self:partyInfo(self:fitPartyInfo(translate(row[1]), 80), 14, y + 3, quiet)
      self:partyInfo(self:fitPartyInfo(row[2], 128), 96, y + 3, c.ink, 128, "right")
    end
  end
end
