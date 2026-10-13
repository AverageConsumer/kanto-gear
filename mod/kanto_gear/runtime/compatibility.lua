return function(
  THEME, color, compat, displayRuntime, mod, render,
  session
)
  do local initial = { screens = {
    party = { PartyMenu = true, Gen2PartyMenu = true },
    summary = { SummaryMenu = true, Gen2SummaryMenu = true, Gen3SummaryMenu = true },
    bag = { BagMenu = true, Gen2PackMenu = true },
    naming = { NamingScreen = true, Gen2NamingScreen = true },
    pokemonPc = { BoxMenu = true, Gen2CenterPcMenu = true, Gen2PcMenu = true },
    itemPc = { PlayerPC = true, Gen2ItemPcMenu = true },
    trainerCard = { TrainerCard = true, Gen2TrainerCard = true },
  } }; for key, value in pairs(initial) do compat[key] = value end end
  compat.bagViews = setmetatable({}, { __mode = "k" })
  compat.bagLabels = { "ITEMS", "BALLS", "KEY", "TM/HM" }

  -- Game path [Gen 1/2]: level-up stats are an anonymous mon state in Gen 1 and a stats-box phase on Gen2BattleState in Gen 2.
  function compat.levelUpMon(state)
    if state and type(state.mon) == "table"
        and type(state.mon.stats) == "table" and not state.screenId then
      return state.mon
    end
    if state and state.screenId == "Gen2BattleState"
        and state.phase == "stats-box" then
      local mon = state.statsBoxMon
      return type(mon) == "table" and type(mon.stats) == "table" and mon or nil
    end
  end

  function compat.isBattleScreen(state)
    return state and (state.isBattleState
      or state.screenId == "Gen2BattleState") or false
  end

  do
    local mon = { stats = {} }
    assert(compat.levelUpMon({ screenId = "Gen2BattleState",
                              phase = "stats-box", statsBoxMon = mon }) == mon
           and not compat.levelUpMon({ screenId = "Gen2BattleState",
                                       phase = "menu", statsBoxMon = mon })
           and compat.isBattleScreen({ screenId = "Gen2BattleState" }),
           "shared level-up and battle-screen detection")
  end
  compat.summary = assert(load(mod:read("models/summary.lua"),
    "@kanto_gear/models/summary.lua"))()
  compat.summary.details = assert(load(mod:read("models/summary_details.lua"),
    "@kanto_gear/models/summary_details.lua"))()
  displayRuntime.SummaryPage = assert(load(mod:read("ui/pages/summary.lua"),
    "@kanto_gear/ui/pages/summary.lua"))()


  function compat.isGen2()
    return session.game and session.game.save and session.game.save.generation == 2
  end

  -- Host path [Gen 2]: hosts expose tod or daytime and DARK or NITE; normalize labels without changing the native clock.
  function compat.timePeriod(world)
    local period = world and tostring(world.tod or world.daytime or ""):upper()
    if period == "DARK" then period = "NITE" end
    return (period == "MORN" or period == "DAY" or period == "NITE")
      and period or nil
  end
  assert(compat.timePeriod({ daytime = "day" }) == "DAY"
    and compat.timePeriod({ tod = "DARK" }) == "NITE"
    and compat.timePeriod({}) == nil, "Gen 2 time period labels")

  function compat.clockTimestamp(currentGame, source, now)
    if source ~= "game" or not (currentGame and currentGame.save
        and (currentGame.save.generation == 2 or currentGame.save.generation == 3)) then return now, false end
    local world = currentGame.world
    if not (world and type(world.hour) == "function"
        and type(world.minute) == "function") then return now, false end
    local okHour, hour = pcall(world.hour, world)
    local okMinute, minute = pcall(world.minute, world)
    local current = os.date("*t", now)
    if not (okHour and okMinute and type(hour) == "number"
        and type(minute) == "number" and type(current) == "table") then
      return now, false
    end
    current.hour, current.min, current.sec = hour % 24, minute % 60, 0
    local ok, timestamp = pcall(os.time, current)
    return ok and timestamp or now, ok
  end
  assert(os.date("%H:%M", compat.clockTimestamp({
      save = { generation = 2 }, world = {
        hour = function() return 21 end,
        minute = function() return 5 end,
      } }, "game", os.time({ year = 2026, month = 1, day = 15,
        hour = 12, min = 34, sec = 56 }))) == "21:05"
    and compat.clockTimestamp({ save = { generation = 1 } }, "game", 123) == 123
    and compat.clockTimestamp({ save = { generation = 2 } }, "game", 123) == 123,
    "game clock source with safe fallback")

  function compat.systemTimePeriod(timestamp)
    local current = os.date("*t", timestamp)
    local hour = current and tonumber(current.hour)
    if not hour then return nil end
    return hour >= 4 and hour < 10 and "MORN"
      or hour >= 10 and hour < 18 and "DAY" or "NITE"
  end

  function compat.clockDisplay(currentGame, source, now)
    local timestamp, gameClock = compat.clockTimestamp(currentGame, source, now)
    local period
    if currentGame and currentGame.save
        and currentGame.save.generation == 2 then
      period = gameClock and compat.timePeriod(currentGame.world) or nil
    end
    -- Every game shows the period of the time it displays: Gen 2's own
    -- MORN/DAY/NITE, otherwise the same boundaries applied to the clock shown.
    period = period or compat.systemTimePeriod(timestamp)
    return timestamp, period
  end

  function compat.autoThemeDark(currentGame, source, now)
    local timestamp, period = compat.clockDisplay(currentGame, source, now)
    return (period or compat.systemTimePeriod(timestamp)) == "NITE"
  end
  do
    local noon = os.time({ year = 2026, month = 1, day = 15,
      hour = 12, min = 0, sec = 0 })
    local night = os.time({ year = 2026, month = 1, day = 15,
      hour = 21, min = 0, sec = 0 })
    local timestamp, period = compat.clockDisplay({
      save = { generation = 2 }, world = {
        hour = function() return 21 end,
        minute = function() return 5 end,
        tod = "dark",
      } }, "game", noon)
    local systemTimestamp, systemPeriod = compat.clockDisplay({
      save = { generation = 2 }, world = { tod = "dark" } },
      "system", noon)
    assert(os.date("%H:%M", timestamp) == "21:05" and period == "NITE"
        and systemTimestamp == noon and systemPeriod == "DAY",
      "clock text and period icon always use the same time source")
    assert(compat.autoThemeDark({ save = { generation = 2 }, world = {
          hour = function() return 21 end, minute = function() return 5 end,
          tod = "dark",
        } }, "game", noon)
        and compat.autoThemeDark({ save = { generation = 1 } }, "game", night)
        and not compat.autoThemeDark({ save = { generation = 1 } },
          "game", noon),
      "automatic HGSS theme shares the Gen 2 night boundary in both games")
  end

  compat.romCodes = {
    red = "RD", blue = "BL", yellow = "YL", gold = "GD", silver = "SV",
    crystal = "CR", firered = "FR", leafgreen = "LG", emerald = "EM", ruby = "RU", sapphire = "SA",
  }

  function compat.systemId(version, release)
    version = version or (session.game and session.game.save and session.game.save.version)
      or (displayRuntime.gen3 and require("src.core.GameVersion").get())
    local code = compat.romCodes[version]
      or (displayRuntime.gen3 and "G3" or compat.isGen2() and "G2" or "G1")
    release = tostring(release or mod.version or "DEV")
      :gsub("%-rc%.", "-RC")
    return ("SLS-%s-%s"):format(code, release:upper())
  end
  assert(compat.systemId("gold", "1.8.0-rc.8") == "SLS-GD-1.8.0-RC8",
    "Silph Link system identifier")
  assert(compat.systemId("silver", "2.2.0") == "SLS-SV-2.2.0",
    "Silver Silph Link system identifier")
  assert(compat.systemId("crystal", "2.5.0") == "SLS-CR-2.5.0",
    "Crystal Silph Link system identifier")
  assert(compat.systemId("firered", "3.3.0") == "SLS-FR-3.3.0"
    and compat.systemId("leafgreen", "3.3.0") == "SLS-LG-3.3.0",
    "FRLG Silph Link system identifiers")

  -- Game path [Gen 2]: the title menu exposes its list only during menu phase, not save confirmation.
  function compat.titleChoice(top)
    return top and top.screenId == "Gen2MainMenu" and top.phase == "menu"
      and top.list or nil
  end
  assert(compat.titleChoice({ screenId = "Gen2MainMenu", phase = "menu",
      list = {} })
    and not compat.titleChoice({ screenId = "Gen2MainMenu", phase = "confirm",
      list = {} }), "Gold title choice adapter")

  -- Game path [Gen 2]: save/start/battle prompts store choice cursors in phase-specific fields rather than a shared Menu.index.
  compat.yesNoFields = {
    Gen2SaveMenu = { confirm = "choice", overwrite = "choice" },
    Gen2StartMenu = { confirm = "confirmChoice", confirmContest = "confirmChoice" },
    Gen2BattleState = { ["ask-nickname"] = "nicknameIndex",
      ["ask-shift"] = "shiftIndex", ["ask-forget"] = "forgetChoice",
      ["stop-learning"] = "forgetChoice" },
  }

  function compat.yesNoField(top)
    if not top or (top.messageTimer or 0) > 0 then return nil end
    if top.screenId == "Gen2SaveMenu" and top.yesNoVisible and not top:yesNoVisible() then return nil end
    local phases = compat.yesNoFields[top.screenId]
    return phases and phases[top.phase] or nil
  end

  -- Game path [Gen 1/2]: script lists, name pickers and nested confirmations expose different cursors; only the final printed page can accept a choice.
  function compat.choiceView(top)
    local title = compat.titleChoice(top)
    if title then return title, "index" end
    if top and top.screenId == "Gen2ScriptMenu" then return top, "script" end
    if top and top.screenId == "Gen2NamePick" and not top.slide then
      return top, "cursor"
    end
    local confirm = top and top.confirm
    if type(confirm) == "table" and confirm.choice
        and (not confirm.pages or confirm.page >= #confirm.pages) then
      return confirm, "choice"
    end
    local field = compat.yesNoField(top)
    return top, field or "index"
  end

  function compat.choiceIndex(top, field, value)
    if field == "script" then
      if value then
        top.row = math.floor((value - 1) / top.cols) + 1
        top.col = (value - 1) % top.cols + 1
      end
      return (top.row - 1) * top.cols + top.col
    end
    if value then top[field] = value end
    return top[field]
  end
  assert(compat.choiceIndex({ row = 2, col = 1, cols = 1 }, "script") == 2,
    "Gold choice index adapter")

  function compat.choiceGrid(top, field, count)
    if field ~= "script" or top.style ~= "2d"
        or type(top.rows) ~= "number" or type(top.cols) ~= "number"
        or top.rows < 1 or top.cols < 2
        or top.rows * top.cols ~= count then return end
    local gap, left, topY, width, height = 4, 6, 28, 148, 104
    local cellW = math.floor((width - (top.cols - 1) * gap) / top.cols)
    local cellH = math.floor((height - (top.rows - 1) * gap) / top.rows)
    if cellW < 36 or cellH < 20 then return end
    return top.rows, top.cols, left, topY, cellW, cellH, gap
  end
  assert(compat.choiceGrid({ style = "2d", rows = 3, cols = 2 },
      "script", 6) == 3
    and not compat.choiceGrid({ style = "vertical", rows = 6, cols = 1 },
      "script", 6), "Gold 2D choice layout adapter")

  -- Host path [Gen 2]: palette APIs are optional on older hosts; unavailable modules leave the existing monochrome rendering intact.
  function compat.gen2PaletteModules()
    if not compat.isGen2() then return nil end
    if compat.gen2GbcPalette == nil then
      local okGbc, gbc = pcall(require, "src.render.GbcPalette")
      local okPal, palettes = pcall(require, "src.world.gen2.Palettes")
      compat.gen2GbcPalette = okGbc and gbc or false
      compat.gen2Palettes = okPal and palettes or false
    end
    return compat.gen2GbcPalette or nil, compat.gen2Palettes or nil
  end

  -- Game path [Gen 2 vs Gen 1]: overworld sprites use daytime/object palettes from gen2Sprites; Gen 1 uses the ordinary sprites table.
  function compat.mapSprite(spriteId, seed, objDef)
    local data = session.game and session.game.data or {}
    local sprites = compat.isGen2() and data.gen2Sprites or data.sprites
    local def = sprites and sprites[spriteId]
    local daytime, colors
    if def and compat.isGen2() then
      local _, palettes = compat.gen2PaletteModules()
      local world = session.game and session.game.world
      daytime = world and world.daytime
      if not daytime and palettes and type(palettes.clockDaytime) == "function" then
        daytime = palettes.clockDaytime(world and world.hour)
      end
      colors = palettes and type(palettes.spritePalette) == "function"
        and palettes.spritePalette(data.gen2Palettes, daytime, def, objDef)
    end
    local key = def and table.concat({ tostring(seed), tostring(spriteId),
      tostring(def.image), tostring(daytime), tostring(objDef and objDef.palette) }, ":")
    compat.mapSprites = compat.mapSprites or {}
    if key and compat.mapSprites[key] == nil then
      local ok, renderer = pcall(function()
        local value = require("src.render.SpriteRenderer").new(def, seed)
        if colors and type(value.setObjPalette) == "function" then
          local _, palettes = compat.gen2PaletteModules()
          local paletteId = palettes and palettes.objectPaletteId
            and palettes.objectPaletteId(objDef) or def.paletteId or 0
          value:setObjPalette(colors, ("gen2:%s:%d"):format(
            tostring(daytime), paletteId))
        end
        return value
      end)
      compat.mapSprites[key] = ok and renderer or false
    end
    return key and compat.mapSprites[key] or nil
  end

  function compat.drawMapSprite(spriteId, seed, objDef, x, y, scale,
      feetAnchored, facing, tint)
    local renderer = compat.mapSprite(spriteId, seed, objDef)
    if not renderer then return false end
    local ok = pcall(function()
      local pose = renderer:getPoseGeometry(facing or "down", 0, false)
      -- Sheet pixels are not map pixels: fit HD replacement frames into the
      -- same 16px marker, preserving aspect ratio and the authored anchor.
      scale = (scale or 0.75) * 16 / math.max(16, pose.width, pose.height)
      local drawX = x - pose.anchorX * scale
      if pose.mirror then drawX = drawX + pose.width * scale end
      color(tint or { 1, 1, 1, 1 })
      render.G.draw(renderer:resolveImage(), pose.quad, drawX,
        y - (feetAnchored and pose.anchorY or pose.height / 2) * scale,
        0, pose.mirror and -scale or scale, scale)
    end)
    return ok
  end

  function compat.drawMapMarker(x, y, scale, feetAnchored, facing)
    if displayRuntime.gen3 then
      if displayRuntime.gen3:drawPlayer(render.G, x, y, scale, feetAnchored, facing) then return end
      THEME:drawMapMarker(x, y)
      return
    end
    local data = session.game and session.game.data or {}
    local playerSprites = data.field and data.field.playerSprites or {}
    -- Game path [Gen 1/2]: Gen 2 imports SPRITE_CHRIS; Gen 1 honors the active walking sprite and falls back to SPRITE_RED.
    local id = compat.isGen2() and "SPRITE_CHRIS"
      or playerSprites.walk or "SPRITE_RED"
    if compat.drawMapSprite(id, "kanto-gear-map", nil, x, y, scale,
        feetAnchored, facing or "down") then return end
    THEME:drawMapMarker(x, y)
  end

  function compat.drawMapActor(actor, x, y, scale, feetAnchored, tint, maxSize)
    if not actor then return false end
    if displayRuntime.gen3 then
      return displayRuntime.gen3:drawActor(render.G, actor, x, y, scale, feetAnchored, tint, maxSize)
    end
    return compat.drawMapSprite(actor.spriteId,
      actor.id or "kanto-gear-actor", { palette = actor.palette },
      x, y, scale, feetAnchored, actor.facing, tint)
  end

  function compat.isScreen(state, kind)
    return state and compat.screens[kind]
      and compat.screens[kind][state.screenId] == true or false
  end

  function compat.screenName(kind, gen2)
    local wanted = gen2 and 2 or 1
    for id in pairs(compat.screens[kind] or {}) do
      local generation = tonumber(id:match("^Gen(%d+)")) or 1
      if generation == wanted then return id end
    end
  end

  function compat.caughtDex(save)
    local dex = save and save.pokedex or {}
    return dex.owned or dex.caught or {}
  end

  function compat.playSeconds(save)
    local value = save and save.playTime
    if type(value) ~= "table" then return tonumber(value) or 0 end
    return (tonumber(value.hours) or 0) * 3600
      + (tonumber(value.minutes) or 0) * 60
      + (tonumber(value.seconds) or 0)
  end

end
