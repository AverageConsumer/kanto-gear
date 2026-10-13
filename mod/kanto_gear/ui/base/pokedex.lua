return function(H, ui, draw)
  local border, box = draw.border, draw.box
  local translate = draw.translate
  local PokedexPage = ui.pokedexPage

  local function dexResearchHero(self, model, accent, summary, facts)
    local colors = self.colors
    local mon = model.pokemon or {}
    self:homeTile(7, 34, 226, 37, accent, false)
    if model.drawPokemon then model.drawPokemon(mon, 13, 37, 31, false) end
    self:partyInfo(self:fitPartyInfo(mon.name or translate("POKEMON"), 108),
      50, 39, colors.ink)
    self:typeBadges(mon, 50, 55, false)
    self:partyInfo(self:fitPartyInfo(summary or "", 69),
      157, 39, colors.ink, 69, "center")
    self:partyType(self:fitPartyType(facts or "", 69),
      157, 56, colors.green, 69)
  end

  function H:pokedexComparison(model)
    local colors, G = self.colors, ui.graphics
    if self.dexSilhouetteShader == nil then
      local ok, shader = pcall(G.newShader, [[vec4 effect(vec4 tint, Image image, vec2 uv, vec2 screen) {
        return vec4(tint.rgb, Texel(image, uv).a * tint.a);
      }]])
      self.dexSilhouetteShader = ok and shader or false
    end
    local previous = G.getShader()
    if self.dexSilhouetteShader then G.setShader(self.dexSilhouetteShader) end
    G.setColor(unpack(colors.ink))
    for _, row in ipairs(model.comparison or {}) do
      if row.image then G.draw(row.image, row.x, row.y, 0, row.scale, row.scale, 32, 32) end
    end
    G.setShader(previous)
  end

  function H:pokedexStats(model)
    local colors = self.colors
    dexResearchHero(self, model, colors.blue,
      model.summary or translate("BASE STATS"), "")
    self:partyType(model.catchText or translate("CATCH --"), 105, 56,
      colors.green, 59)
    self:partyType(model.expText or translate("XP --"), 167, 56,
      colors.green, 59)
    local rows = model.stats or {}
    local gap = #rows > 5 and 1 or 3
    local height = #rows > 5 and 20 or 22
    for index, row in ipairs(rows) do
      local top = 76 + (index - 1) * (height + gap)
      self:panel(7, top, 226, height, false, nil, colors.blueLight)
      self:partyType(translate(row.label or "STAT"), 13, top + 6, colors.green, 54)
      border(72, top + 7, 119, 6, colors.outline)
      box("fill", 73, top + 8, 117, 4, colors.silverDark)
      box("fill", 73, top + 8,
        math.floor(117 * math.min(255, tonumber(row.value) or 0) / 255 + 0.5),
        4, colors.blueLight)
      self:partyInfo(tostring(row.value or 0), 196, top + 5,
        colors.ink, 27, "center")
    end
  end

  function H:pokedex(model)
    if model.view == "profile" then return self:pokedexProfile(model) end
    if model.view == "area" then return self:pokedexArea(model) end
    if model.view == "cry" then return self:pokedexCry(model) end
    if model.view == "size" then return self:pokedexSize(model) end
    if model.view == "stats" then return self:pokedexStats(model) end
    if model.view == "moves" then return self:pokedexMoves(model) end
    if model.view == "evolutions" then return self:pokedexEvolutions(model) end
    if model.view == "habitat" then return self:pokedexHabitat(model) end
    return self:pokedexIndex(model)
  end

  function H:pokedexHit(x, y, model)
    return PokedexPage.hit(model, x, y)
  end

end
