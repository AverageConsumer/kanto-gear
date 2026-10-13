return function(
  THEME, areaName, color, compat, displayRuntime, header,
  mod, render, screenState, session
)
  function displayRuntime.drawAchievements()
    local model = displayRuntime.achievementModel()
    header(model.area and model.area.name or THEME:translate("ACHIEVEMENTS"), true, false)
    render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    THEME.hgss:achievements(model)
    render.G.pop()
  end

  displayRuntime.notes = displayRuntime.Notes.new({
    time = function() return love.timer.getTime() end,
    keyboardLayout = function() return mod.options:get("keyboard_layout") end,
    measure = function(value) return THEME.hgss:partyInfoWidth(value) end,
    translate = function(value) return THEME:translate(value) end,
    area = function() return session.mapId, areaName(session.mapId) end,
    pageMotion = displayRuntime.requestPageMotion,
    leave = function() session.page, displayRuntime.home.activeApp, session.dirty = "HOME", nil, true end,
  })
  displayRuntime.pss = displayRuntime.Pss.new({
    session = function(client)
      local Session = assert(load(mod:read("features/pss_session.lua"), "@kanto_gear/features/pss_session.lua"))()
      return Session.new(displayRuntime.sourceGame or session.game, function()
        return displayRuntime.pss.ctx.identity()
      end, client)
    end,
    resolve = function()
      return require("src.online.Client"), require("src.online.Connect")
    end,
    identity = function()
      local raw = displayRuntime.sourceGame or session.game
      local player = raw and (raw.session or raw.save and raw.save.player) or {}
      return { name = player.name or "TRAINER",
        version = require("src.core.GameVersion").get(),
        generation = raw and raw.generation or (compat.isGen2() and 2 or 1) }
    end,
  })
  do
  -- Own trainer follows the active game. Peers use Recomp's version-scoped
  -- imported avatars; missing imports fall back to the skin's person glyph.
  -- Game path [Gen 1/2/3]: remote edition selects Kanto, Johto, FRLG or Hoenn avatar assets; never reinterpret another familys IDs locally.
  local PSS_FAMILY = { red = "kanto", blue = "kanto", yellow = "kanto", green = "kanto",
    gold = "johto", silver = "johto", crystal = "johto",
    firered = "frlg", leafgreen = "frlg", ruby = "rse", sapphire = "rse", emerald = "rse" }
  -- Fit the visible pixels, not the padded overworld frame. Keep integer
  -- scaling; crop a bust only when the visible trainer is taller than the seat.
  -- Cache each sprite frame's bounds from existing CPU data, never a GPU readback.
  local pssQuads = setmetatable({}, { __mode = "k" })
  local function drawCropped(spr, quad, x, y, maxH, flip)
    local bounds = pssQuads[quad]
    if bounds == nil then
      local data = spr.imageData
      if not data then return false end
      local qx, qy, qw, qh = quad:getViewport()
      local left, top, right, bottom = qw, qh, -1, -1
      for py = 0, qh - 1 do
        for px = 0, qw - 1 do
          local _, _, _, alpha = data:getPixel(qx + px, qy + py)
          if alpha > 0 then
            left, top = math.min(left, px), math.min(top, py)
            right, bottom = math.max(right, px), math.max(bottom, py)
          end
        end
      end
      bounds = right >= left and { x = qx + left, y = qy + top,
        w = right - left + 1, h = bottom - top + 1, quads = {} } or false
      pssQuads[quad] = bounds
    end
    if not bounds then return false end
    local k = math.max(1, math.floor(maxH / math.max(bounds.w, bounds.h)))
    local rows = math.min(bounds.h, math.floor(maxH / k))
    bounds.quads[rows] = bounds.quads[rows] or render.G.newQuad(bounds.x, bounds.y,
      bounds.w, rows, spr.image:getDimensions())
    local left = math.floor(x - bounds.w * k / 2)
    local top = math.floor(y - (maxH + rows * k) / 2)
    color({ 1, 1, 1, 1 })
    render.G.draw(spr.image, bounds.quads[rows], flip and left + bounds.w * k or left, top,
      0, flip and -k or k, k)
    return true
  end
  local avatarsOk, avatars = pcall(require, "src.online.union.Avatars")
  local importedTrainers = {}
  local function drawImported(row, x, y, maxH, facing)
    local gender = (row.gender == 1 or row.gender == "female" or row.gender == "F") and 1 or 0
    local peer = { game = tostring(row.version or ""):lower(), gender = gender }
    local key = avatars.key(peer)
    local spr = importedTrainers[key]
    if spr == nil then
      local ok, result = pcall(function()
        local entry = avatars.resolve(peer, peer.game)
        if not entry or entry.standin or entry.hostStandin then return nil end
        local image, quads, data = avatars.image(entry), avatars.quads(entry), avatars.imageData(entry)
        if not image or not quads or not data then return nil end
        if entry.layout == "gb" then
          -- The raw GB sheet is opaque; match Recomp's OBJ colour-zero key
          -- for visible bounds without changing the shared source ImageData.
          data = data:clone()
          data:mapPixel(function(_, _, r, g, b, a)
            return r, g, b, r > 0.83 and 0 or a
          end)
        end
        return { image = image, quads = quads, imageData = data, entry = entry }
      end)
      spr = ok and result or false
      importedTrainers[key] = spr
    end
    if not spr then return false end
    local frame, flip = avatars.pose(spr.entry, facing, false, false)
    local quad = spr.quads[frame]
    return quad and drawCropped(spr, quad, x, y, maxH, flip) or false
  end
  displayRuntime.pss.drawTrainer = function(row, x, y, maxH, facing)
    facing, maxH = facing or "down", maxH or 16
    local family = row and PSS_FAMILY[tostring(row.version or ""):lower()]
    if row and not family then return false end
    if row and avatarsOk then return drawImported(row, x, y, maxH, facing) end
    if displayRuntime.gen3 then
      local ok, sprites = pcall(require, "src.core.game3.ow_sprites")
      if not ok then return false end
      local id
      if not row then
        id = sprites.playerGraphicsId and sprites.playerGraphicsId(displayRuntime.sourceGame or session.game)
      elseif family == (displayRuntime.gen3.hoenn and "rse" or "frlg") then
        id = sprites.avatarGraphicsId and sprites.avatarGraphicsId("NORMAL", false)
      end
      local spr = id and sprites.getDraw(id)
      if not spr then return false end
      local frame, flip = sprites.pose(spr, facing, false, false)
      local quad = spr.quads and spr.quads[frame]
      if not quad then return false end
      return drawCropped(spr, quad, x, y, maxH, flip)
    end
    local spriteId
    if not row then
      local playerSprites = (session.game and session.game.data and session.game.data.field or {}).playerSprites or {}
      spriteId = compat.isGen2() and "SPRITE_CHRIS" or playerSprites.walk or "SPRITE_RED"
    else
      spriteId = (family == "kanto" or family == "frlg") and "SPRITE_RED"
        or family == "johto" and "SPRITE_CHRIS" or nil
    end
    if not spriteId then return false end
    local k = math.max(1, math.floor(maxH / 16))
    return compat.drawMapSprite(spriteId, "pss:" .. spriteId, nil, x, y, k, true, facing)
  end
  end
  -- Host session teardown also drops subscriptions when returning to the launcher.
  -- A weak reference keeps its process-wide release registry from retaining Gear.
  do
    local weak = setmetatable({ displayRuntime.pss, displayRuntime }, { __mode = "v" })
    require("src.render.Assets").register({ release = function()
      if weak[1] then weak[1]:close() end
      if weak[2] then weak[2].clearExplorerSnapshot() end
    end })
  end
  function displayRuntime.drawPss()
    header(THEME:translate("SILPH CONNECT"), true, false)
    render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    THEME.hgss:pss(displayRuntime.pss)
    render.G.pop()
  end
  function displayRuntime.notesShown()
    return session.page == "NOTES" and THEME.style == "hgss" and screenState() == "active"
      and not session.battle and not session.moveInfo and not session.fieldChoice and not session.radarOpen
  end
  function displayRuntime.notesPointer(action, x, y)
    -- Interaction always replaces presentation, particularly ink and typing.
    displayRuntime.motion.started, displayRuntime.motion.cached = nil, nil
    displayRuntime.notes:pointer(action, x, y)
    if displayRuntime.notes:takeChanged() then session.dirty = true end
  end
  function displayRuntime.drawNotes()
    local state = displayRuntime.notes
    local title = state.view == "edit" and (state.editTarget == "task" and "TASK"
      or state.editTarget == "title" and "TITLE" or "WRITE")
      or state.view == "draw" and "DRAW" or "NOTES"
    header(THEME:translate(title), true, false)
    render.G.push(); render.G.scale(1 / THEME.hgssScale, 1 / THEME.hgssScale)
    THEME.hgss:notes(state)
    render.G.pop()
  end

end
