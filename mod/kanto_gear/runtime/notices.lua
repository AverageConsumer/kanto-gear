-- Gear notices: a short card under the header when something happened, a
-- chime that follows the game's sound-effect volume, and a dot on the app
-- until it is opened. In single-screen layouts whose Gear is hidden, the
-- card shows over the top of the game picture and a tap brings the Gear up.
-- Cards wait while a battle, dialogue or menu owns the screen. Read only:
-- nothing here writes the game or takes game buttons.
return function(
  THEME, compat, displayRuntime, mod, render, screenState, session
)
  local Notices = displayRuntime.Notices
  local state = Notices.new()
  displayRuntime.notices = state
  local BANNER = { x = 6, y = 33, w = 228, h = 32 }
  displayRuntime.noticeRect = BANNER
  function displayRuntime.resetNotices()
    for key in pairs(state) do state[key] = nil end
    for key, value in pairs(Notices.new()) do state[key] = value end
  end

  local function enabled() return mod.options:get("notifications") ~= false end
  local function chimeOn() return mod.options:get("notification_sound") ~= false end

  -- What each area may do: "full" (card and chime), "silent" (card only),
  -- "dot" (only the app's dot) or "off" (nothing at all).
  local AREAS = { shiny = "notice_shiny", moments = "notice_moments", daycare = "notice_daycare",
    calendar = "notice_calendar", stamps = "notice_stamps" }
  function displayRuntime.noticeLevel(area)
    local key = AREAS[area or ""]
    local value = key and mod.options:get(key) or "full"
    if value ~= "silent" and value ~= "dot" and value ~= "off" then value = "full" end
    return value
  end
  local DURATION = { short = 2, normal = 3.5, long = 6 }
  local function showTime() return DURATION[mod.options:get("notice_duration") or "normal"] or DURATION.normal end
  -- Cards over a hidden Gear, or kept until the Gear is in view again.
  local function overGame() return mod.options:get("notice_where") ~= "wait" end
  local function clock() return love.timer.getTime() end

  ----------------------------------------------------------------------------
  -- Chimes: generated once, Game Boy pulse tones, no sound files.
  ----------------------------------------------------------------------------
  local TONES = {
    notice = { { 988, 0.06 }, { 1319, 0.11 } },
    special = { { 1047, 0.06 }, { 1319, 0.06 }, { 1568, 0.06 }, { 2093, 0.2 } },
  }
  local sources = {}
  local function source(kind)
    if sources[kind] ~= nil then return sources[kind] or nil end
    local ok, result = pcall(function()
      local notes, rate = TONES[kind] or TONES.notice, 22050
      local total = 0
      for _, note in ipairs(notes) do total = total + math.floor(note[2] * rate) end
      local data = love.sound.newSoundData(total, rate, 16, 1)
      local index = 0
      for _, note in ipairs(notes) do
        local length = math.floor(note[2] * rate)
        local period = rate / note[1]
        for i = 0, length - 1 do
          -- 25% pulse with a short attack and a soft tail
          local level = math.min(1, i / 200) * math.min(1, (length - i) / (length * 0.6))
          local value = (i % period) < period * 0.25 and 1 or -1
          data:setSample(index, value * level * 0.22)
          index = index + 1
        end
      end
      return love.audio.newSource(data, "static")
    end)
    sources[kind] = ok and result or false
    return sources[kind] or nil
  end

  -- The game's own sound-effect level: Gen 1/2 SFX VOL in the save options
  -- (0..7), Gen 3 the native mixer's level. Muted effects mute the chime.
  local function effectsGain()
    if displayRuntime.gen3 then
      local ok, Audio = pcall(require, "src.core.game3.audio")
      local level = ok and type(Audio) == "table" and tonumber(Audio._sfxVolume) or nil
      return level or 1
    end
    local options = session.game and session.game.save and session.game.save.options
    local level = type(options) == "table" and tonumber(options.sfxVol) or nil
    if not level then return 1 end
    return math.max(0, math.min(7, level)) / 7
  end

  function displayRuntime.playNoticeChime(kind)
    if not chimeOn() then return false end
    local gain = effectsGain()
    if gain <= 0 then return false end
    local tone = source(kind)
    if not tone then return false end
    return pcall(function()
      tone:stop(); tone:setVolume(gain); tone:play()
    end)
  end

  local function announce(card)
    if card.chimed then return end
    card.chimed = true
    if card.silent then return end
    displayRuntime.playNoticeChime(card.tone or "notice")
    if displayRuntime.haptic then displayRuntime.haptic("confirm") end
  end

  ----------------------------------------------------------------------------
  -- Posting and pacing
  ----------------------------------------------------------------------------
  -- notice = { key, app, page, title, detail, species, shiny, icon, drawIcon, tone, urgent, onOpen }
  -- notice.area picks the per-area switch (shiny, moments, daycare, calendar,
  -- stamps); without one the card follows the main switches only.
  function displayRuntime.notify(notice)
    if type(notice) ~= "table" or not session.active then return nil end
    local level = displayRuntime.noticeLevel(notice.area)
    if level == "off" then return nil end
    -- A dot on the app unless its page is already in front of the player.
    if notice.app and session.page ~= notice.page then Notices.markUnread(state, notice.app) end
    displayRuntime.home.widgetCache = nil
    displayRuntime.mapRefresh.paintedPage = nil
    session.dirty = true
    if not enabled() or level == "dot" then return nil end
    notice.silent = level == "silent" or nil
    notice.show = notice.show or showTime()
    local card = Notices.post(state, notice, clock())
    -- Urgent news (a shiny in battle) chimes at once unless the player wants
    -- it with the card; the card itself waits for a free screen.
    if card and notice.urgent and mod.options:get("notice_shiny_timing") ~= "after" then announce(card) end
    return card
  end

  local function free()
    if not session.active or not session.game or session.battle then return false end
    if displayRuntime.displaySetupModal then return false end
    if displayRuntime.gearModules and displayRuntime.gearModules.anyShown() then return false end
    if session.pendingFly or session.pendingAction or session.fieldChoice then return false end
    if displayRuntime.notesShown and displayRuntime.notesShown() then return false end
    -- "Wait for the Gear": nothing shows while the Gear is out of view.
    if not overGame() and state.hiddenAt and clock() - state.hiddenAt < 0.25 then return false end
    local mode = screenState()
    return mode == "active"
  end

  function displayRuntime.noticeCard(now)
    now = now or clock()
    if not enabled() or not free() then
      state.pausedAt = state.pausedAt or now
      state.overRect = nil
      return nil
    end
    if state.pausedAt then
      if state.current then state.current.shownAt = state.current.shownAt + now - state.pausedAt end
      state.pausedAt = nil
    end
    local card = Notices.advance(state, now, true)
    if card and card.fresh then
      card.fresh = nil
      announce(card)
      session.dirty = true
    end
    return card
  end

  -- Called every composed frame: repaint while a card is moving or showing.
  function displayRuntime.tickNotices(now)
    if free() and displayRuntime.pollNoticeSources then displayRuntime.pollNoticeSources(now or clock()) end
    local card = Notices.pending(state) and displayRuntime.noticeCard(now) or nil
    if not card then
      -- One more whole repaint wipes the card that just left.
      if state.wasShowing then state.wasShowing, state.clearPending = false, true; return true end
      return false
    end
    state.wasShowing = true
    -- Without motion a card needs only its first and last frame.
    if displayRuntime.motionEnabled and not displayRuntime.motionEnabled() then
      local shown = Notices.presence(card, now) > 0
      if card.paintedShown == shown then return false end
      card.paintedShown = shown
    end
    return true
  end

  -- Whole repaints (not the map-only refresh) while a card shows or leaves.
  function displayRuntime.noticeShowing()
    if state.current then return true end
    if state.clearPending then state.clearPending = nil; return true end
    return false
  end

  function displayRuntime.markNoticeRead(app)
    if Notices.markRead(state, app) then
      displayRuntime.home.widgetCache = nil
      displayRuntime.mapRefresh.paintedPage = nil
      session.dirty = true
    end
  end

  function displayRuntime.noticeUnread(app) return state.unread[app] == true end

  local function open(card)
    Notices.dismiss(state, clock())
    if card.app then
      displayRuntime.markNoticeRead(card.app)
      local package = displayRuntime.homeCatalog.packages[card.app]
      if package and package.installed then
        displayRuntime.openHomeApp(card.app)
        -- A notice may lead to one page inside its app.
        if card.onOpen then pcall(card.onOpen) end
      end
    end
    session.dirty = true
  end

  ----------------------------------------------------------------------------
  -- Drawing: on the Gear canvas, or over the game when the Gear is hidden
  ----------------------------------------------------------------------------
  local function presence(card, now)
    local value = Notices.presence(card, now)
    if displayRuntime.motionEnabled and not displayRuntime.motionEnabled() then
      return value > 0 and 1 or 0
    end
    return value
  end

  local function paint(card, now)
    local view = { title = card.title, detail = card.detail, species = card.species, icon = card.icon,
      shiny = card.shiny, drawIcon = card.drawIcon,
      tone = card.tone, presence = presence(card, now), closing = card.closing,
      drawPokemon = displayRuntime.shinyDrawPokemon }
    if view.presence <= 0 then return false end
    THEME.hgss:noticeBanner(view, BANNER.x, BANNER.y, BANNER.w, BANNER.h)
    return true
  end

  -- Inside drawContents, in the canvas's 240x216 space.
  function displayRuntime.drawNoticeLayer()
    if THEME.style ~= "hgss" or not enabled() or not free() then return end
    local card = state.current
    if not card then return end
    paint(card, clock())
  end

  -- Single-screen layouts with the Gear hidden: the same card at the top of
  -- the game picture, scaled like the Gear would be, never wider than half.
  function displayRuntime.drawNoticeOverGame(rect)
    state.overRect = nil
    if THEME.style ~= "hgss" or not rect then return end
    local now = clock()
    state.hiddenAt = now
    if not overGame() then return end
    local card = displayRuntime.noticeCard(now)
    if not card then return end
    local scale = math.min(rect.w / 240, rect.h / 216, rect.w * 0.5 / BANNER.w)
    if scale >= 2 then scale = math.floor(scale) end
    scale = math.max(1, scale)
    local w, h = BANNER.w * scale, BANNER.h * scale
    local x = math.floor(rect.x + (rect.w - w) / 2)
    local y = math.floor(rect.y + 6 * scale)
    render.G.push("all")
    render.G.setScissor(rect.x, rect.y, rect.w, rect.h)
    render.G.translate(x - BANNER.x * scale, y - BANNER.y * scale)
    render.G.scale(scale, scale)
    -- Canvas touches never press the card drawn over the game.
    local touchX, touchY, touchOn = THEME.hgss.touchX, THEME.hgss.touchY, THEME.hgss.touchEnabled
    THEME.hgss:setTouch(nil)
    local ok = pcall(paint, card, now)
    THEME.hgss:setTouch(touchX, touchY, touchOn)
    render.G.pop()
    if ok then state.overRect = { x = x, y = y, w = w, h = h, card = card } end
  end

  ----------------------------------------------------------------------------
  -- Touch
  ----------------------------------------------------------------------------
  -- A tap on the canvas card (base 160x144 coordinates).
  function displayRuntime.noticeTap(x, y)
    if not enabled() or not free() then return false end
    local card = state.current
    if not card or card.closing or presence(card, clock()) < 0.5 then return false end
    local hx, hy = x * THEME.hgssScale, y * THEME.hgssScale
    if hx < BANNER.x or hx >= BANNER.x + BANNER.w or hy < BANNER.y or hy >= BANNER.y + BANNER.h then
      return false
    end
    open(card)
    if displayRuntime.haptic then displayRuntime.haptic("open") end
    return true
  end

  -- A swipe that starts on the canvas card sends it away (base 160x144).
  function displayRuntime.noticeSwipe(down)
    if not enabled() or not free() then return false end
    local card = state.current
    if not card or card.closing or not down or presence(card, clock()) < 0.5 then return false end
    local hx, hy = (down.x or -1) * THEME.hgssScale, (down.y or -1) * THEME.hgssScale
    if hx < BANNER.x or hx >= BANNER.x + BANNER.w or hy < BANNER.y or hy >= BANNER.y + BANNER.h then
      return false
    end
    Notices.dismiss(state, clock())
    session.dirty = true
    return true
  end

  -- A pointer on the card drawn over the game: a tap brings the Gear up
  -- there, a drag sends the card away.
  function displayRuntime.noticePointer(event)
    if not enabled() or not free() then
      local captured = state.overDown ~= nil
      if event and (event.phase == "released" or event.phase == "cancelled") then state.overDown = nil end
      state.overRect = nil
      return captured
    end
    local rect = state.overRect
    if not (rect and event and event.x and event.y) then return false end
    local inside = event.x >= rect.x and event.x < rect.x + rect.w
      and event.y >= rect.y and event.y < rect.y + rect.h
    if event.phase == "pressed" then
      state.overDown = inside and { x = event.x, y = event.y } or nil
      return inside
    end
    local down = state.overDown
    if not down then return false end
    if event.phase == "released" or event.phase == "cancelled" then
      state.overDown = nil
      local card = rect.card
      if event.phase ~= "released" or state.current ~= card or card.closing then return true end
      -- A quarter of the card's height counts as a drag.
      local limit = math.max(6, rect.h / 4)
      if math.abs(event.x - down.x) > limit or math.abs(event.y - down.y) > limit then
        Notices.dismiss(state, clock())
        session.dirty = true
      elseif inside then
        if displayRuntime.revealGear then displayRuntime.revealGear() end
        open(card)
      end
    end
    return true
  end
end
