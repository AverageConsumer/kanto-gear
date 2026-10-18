return function(T, run, display, game, generation)
  local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
  local up = dofile(path .. "/tests/support/runtime.lua").get
  local function hook(name)
    for _, entry in ipairs(run.loader.hooks.chains[name] or {}) do
      if entry.owner == "kanto_gear" then return entry.callback end
    end
    error("missing hook " .. name)
  end
  local M, session = display.gearModules, display.session
  run.loader.modOptions.kanto_gear = run.loader.modOptions.kanto_gear or {}
  local theme = up(display.drawContents, "THEME")
  local supported, shown, opens, throws = true, false, 0, false
  local edition = assert(os.getenv("POKEPORT_VERSION"))
  local context = M.lastContext
  T.eq(context.edition, edition, "availability receives the actual bound edition")
  T.eq(context.generation, generation, "availability receives the actual bound generation")
  T.eq(context.gen3, generation == 3, "edition context preserves the Gen 3 flag")
  local editionOpens = 0
  for _, target in ipairs({ "red", "blue", "yellow", "gold", "silver", "crystal",
      "firered", "leafgreen", "emerald", "ruby", "sapphire" }) do
    local id, matches = "edition_" .. target, target == edition
    T.check(M.exports.register({
      id = id, label = target, category = "TOOLS", description = { "EDITION ONLY" },
      icon = function() end, available = function(ctx) return ctx.edition == target end,
      open = function() editionOpens = editionOpens + 1; return true end,
    }), "edition-specific app registers after binding: " .. target)
    T.eq(display.storeById[id].hidden, not matches, target .. " Store visibility follows the exact edition")
    T.eq(display.homeCatalog.surfaces[id .. "_app"].hidden, not matches, target .. " Home visibility follows the exact edition")
    T.eq(not not display.setPackageInstalled(id, true), matches, target .. " can only be enabled in its edition")
    T.eq(display.openHomeApp(id), matches, target .. " can only open in its edition")
    T.eq(M.open(id), matches, target .. " direct opening also obeys edition availability")
  end
  T.eq(editionOpens, 2, "only the matching edition's app callbacks ran")
  local id = "edition_" .. edition
  display.home.layout = { tiles = {} }
  T.check(display.Home.place(display.home.layout, display.homeCatalog, "settings_app", 2, 1, 2), "place left shortcut neighbor")
  T.check(display.Home.place(display.home.layout, display.homeCatalog, id .. "_app", 2, 4, 2), "place edition-specific shortcut")
  T.check(display.Home.place(display.home.layout, display.homeCatalog, "store_app", 2, 7, 2), "place right shortcut neighbor")
  display.saveHome()
  local other = generation == 1 and (edition == "red" and "blue" or "red")
    or generation == 2 and (edition == "crystal" and "gold" or "crystal")
    or (edition == "firered" and "leafgreen" or "firered")
  M.applyAvailability({ edition = other, generation = generation, gen3 = generation == 3 })
  display.loadHome(); display.saveHome(); display.loadHome()
  T.eq(display.storeById[id].hidden, true, "same-generation edition change hides the Store entry")
  T.eq(display.Home.find(display.home.layout, id .. "_app"), nil, "unsupported edition has no visible shortcut")
  T.eq(display.homeSnapshot().packages[id], true, "unsupported edition preserves saved enablement")
  T.eq(display.openHomeApp(id), false, "saved shortcut cannot open in a sibling edition")
  T.eq(M.open(id), false, "direct opening cannot bypass the edition restriction")
  T.eq(editionOpens, 2, "unsupported edition never invokes the app")
  M.applyAvailability(context); display.loadHome()
  local restored = display.Home.find(display.home.layout, id .. "_app")
  T.check(display.homeCatalog.packages[id].installed, "returning to the supported edition restores enablement")
  T.check(restored and restored.page == 2 and restored.column == 4 and restored.row == 2,
    "returning to the supported edition restores the exact saved shortcut")
  T.check(display.openHomeApp(id), "restored edition-specific app opens again")
  T.eq(editionOpens, 3, "restored app invokes its callback once")
  T.check(display.setPackageInstalled(id, false), "remove edition fixture before the remaining module checks")
  local function spec(id, translation)
    return { id = id, label = "STATUS", category = "TOOLS", description = { "STATUS", "UNSEEN" },
      icon = function() end, available = function() return supported end,
      shown = function() return shown end,
      open = function() opens = opens + 1; if throws then error("app failed") end; return true end,
      translations = { de = { STATUS = translation } } }
  end
  local invalid = spec("invalid_callback", "X")
  invalid.shown = true
  T.eq(M.register(invalid), nil, "invalid callbacks are refused before catalog changes")
  T.eq(display.storeById.invalid_callback, nil, "refused callback leaves no Store entry")
  invalid = spec("invalid_palette", "X")
  invalid.icon = { pal = { a = "nothex" }, rows = {} }
  for index = 1, 24 do invalid.icon.rows[index] = string.rep("a", 24) end
  T.eq(M.register(invalid), nil, "invalid pixel-art colors are refused")
  T.eq(M.exports.register(spec("contract", "ERSTE APP")), true, "external app registers after game bind")
  T.eq(M.exports.register(spec("contract_two", "ZWEITE APP")), true, "second app may reuse English strings")
  local oldLanguage = theme.i18n.selectedLanguage
  theme.i18n.selectedLanguage = function() return "de" end
  local builtIn = theme:translate("STATUS")
  T.eq(theme:translate(display.storeById.contract.label), "ERSTE APP", "first app uses its own translation")
  T.eq(theme:translate(display.storeById.contract_two.label), "ZWEITE APP", "second app has a separate translation")
  T.eq(theme:translate(display.storeById.contract.description[2]), "UNSEEN", "missing app translations use English")
  T.eq(theme:translate("STATUS"), builtIn, "apps never change built-in translations")
  T.eq(theme.i18n:extend("de", { STATUS = "OVERWRITE" }), false, "unscoped extension is refused")
  theme.i18n.selectedLanguage = oldLanguage
  T.eq(display.openHomeApp("contract"), false, "uninstalled app cannot open through the public path")
  T.eq(opens, 0, "uninstalled callback is never invoked")
  T.check(display.setPackageInstalled("contract", true), "user can enable a supported app")
  supported = false
  T.eq(M.open("contract"), false, "opening rechecks availability even without a game rebind")
  T.eq(opens, 0, "newly unavailable callback is never invoked")
  supported = false; M.applyAvailability({ generation = generation, gen3 = generation == 3 })
  T.eq(M.open("contract"), false, "unavailable app cannot open directly")
  T.eq(opens, 0, "unavailable callback is never invoked")
  supported = true; M.applyAvailability({ generation = generation, gen3 = generation == 3 })
  session.page, display.home.activeApp = "STORE", "store"
  throws = true
  T.eq(display.openHomeApp("contract"), false, "failing callback is contained")
  T.eq(session.page, "STORE", "failed opening preserves the current page")
  T.eq(display.home.activeApp, "store", "failed opening preserves the active app")
  throws = false
  T.check(display.openHomeApp("contract"), "enabled app opens")
  T.eq(session.page, "HOME", "closing the external surface returns to Home")

  display.home.layout = { tiles = {} }
  for _, item in ipairs({ { "settings_app", 1 }, { "contract_app", 4 }, { "store_app", 7 } }) do
    T.check(display.Home.place(display.home.layout, display.homeCatalog, item[1], 1, item[2], 1), "place persistence fixture")
  end
  display.saveHome()
  local saved = display.homeSnapshot()
  saved.layout.tiles[#saved.layout.tiles + 1] = { id = "settings_app", page = 1, column = 4, row = 1 }
  local api = up(display.saveHome, "mod")
  api.storage:write(display.sourceGame or game, "home/state", saved)
  display.loadHome()
  T.eq(#display.home.dormantTiles, 0, "an invalid built-in placement does not become a dormant module")
  saved.layout.tiles[#saved.layout.tiles] = nil
  api.storage:write(display.sourceGame or game, "home/state", saved)
  display.loadHome()
  local package, surface, entry = display.homeCatalog.packages.contract,
    display.homeCatalog.surfaces.contract_app, display.storeById.contract
  display.homeCatalog.packages.contract, display.homeCatalog.surfaces.contract_app = nil, nil
  display.loadHome(); display.saveHome(); display.loadHome(); display.saveHome()
  T.eq(display.Home.find(display.home.layout, "contract_app"), nil, "absent mod has no visible ghost tile")
  T.eq(display.Home.find(display.home.layout, "store_app").column, 7, "neighbor storage positions survive an absent mod")
  display.homeCatalog.packages.contract, display.homeCatalog.surfaces.contract_app = package, surface
  display.loadHome()
  T.check(package.installed, "re-enabled mod retains its Store setting")
  T.eq(display.Home.find(display.home.layout, "contract_app").column, 4, "re-enabled mod returns to its saved slot")
  supported = false; M.applyAvailability({ generation = generation, gen3 = generation == 3 })
  display.loadHome(); display.saveHome()
  T.eq(#display.Home.tiles(display.home.layout, display.homeCatalog, 1), 2, "unsupported app is hidden from Home")
  supported = true; M.applyAvailability({ generation = generation, gen3 = generation == 3 }); display.loadHome()
  T.check(package.installed and display.Home.find(display.home.layout, "contract_app"), "temporary unavailability preserves layout and enablement")
  T.check(display.setPackageInstalled("contract", false), "explicit Store removal is supported")
  display.loadHome()
  T.check(not package.installed and not display.Home.find(display.home.layout, "contract_app"), "explicit removal stays removed")
  display.home.savedPackages.late_contract = true
  display.home.dormantTiles[#display.home.dormantTiles + 1] = { id = "late_contract_app", page = 3, column = 4, row = 2 }
  T.check(M.register(spec("late_contract", "SPÄTE APP")), "late registration succeeds")
  T.eq(display.Home.find(display.home.layout, "late_contract_app").page, 3, "late registration restores saved placement without reloading the game")
  T.check(display.setPackageInstalled("contract", true), "reinstall for rendering contract checks")

  local offsets, stack = { x = 7, color = "original", shader = "original" }, {}
  local G = {
    getStackDepth = function() return #stack end,
    push = function(mode) T.eq(mode, "all", "custom icon isolates the complete graphics state"); stack[#stack + 1] = { x = offsets.x, color = offsets.color, shader = offsets.shader } end,
    pop = function() offsets = table.remove(stack) end,
  }
  local H, art = {}, { runner = { pal = {}, rows = {} } }
  dofile(path .. "/ui/skins/icons.lua")(H, { graphics = G }, {
    hex = function() return { 0, 0, 0 } end, ART = function() end, iconArt = art,
  })
  for _, fail in ipairs({ false, true }) do
    H:v4AddAppIcon("module/runner", function()
      offsets.x, offsets.color, offsets.shader = 12, "changed", "changed"
      G.push("all")
      offsets.x = 99
      if fail then error("icon failed") end
      G.pop()
    end)
    T.eq(H:v4Icon("module/runner", 0, 0), not fail, "custom icon errors are contained")
    T.eq(offsets.x, 7, "icon restores transforms even after nested push and failure")
    T.eq(offsets.color, "original", "icon restores colors")
    T.eq(offsets.shader, "original", "icon restores shaders")
    T.eq(#stack, 0, "icon leaves the caller's stack balanced")
  end
  T.check(art.runner ~= nil and art["module/runner"] == nil, "custom drawing never replaces built-in art")
  T.check(M.register(spec("runner", "RUNNER")), "module may use a built-in icon name as its app ID")
  T.eq(display.storeById.runner.icon, "module/runner", "registry namespaces the icon ID")

  local compose, originalDraw = hook("render.compose"), display.drawContents
  local draws, pushes, polls, now = 0, 0, 0, 100
  love.timer.getTime = function() return now end
  display.drawContents = function() draws = draws + 1 end
  display.updateMapRefresh = function() return false end
  local canvas = up(up(compose, "pumpDisplay"), "canvas")
  canvas.requestImageData, canvas.pollImageData = nil, nil
  canvas.newImageData = function() return {} end
  local nativeEnabled
  local bridge = { detected = function() return true end,
    setEnabled = function(value) nativeEnabled = value end,
    pollTouch = function() polls = polls + 1 end,
    push = function() pushes = pushes + 1; return true end }
  local downstream = function() return "downstream" end
  for _, mode in ipairs({ "separate", "fullscreen", "combined", "phone" }) do
    run.loader.modOptions.kanto_gear.display_mode = mode
    session.active, session.dirty, session.touchDown = true, true, { x = 1, y = 1 }
    shown = true
    local rect = { x = 0, y = 0, width = 640, height = 480 }
    T.eq(hook("render.viewport")(function() return rect end, rect), rect, mode .. " preserves the host viewport")
    T.eq(session.touchDown, nil, mode .. " drops the old Gear gesture")
    T.eq(hook("render.output_enabled")(downstream), "downstream", mode .. " delegates output selection")
    T.eq(hook("render.output")(downstream, {}), "downstream", mode .. " delegates combined output")
    T.eq(hook("render.window")(downstream, game, {}), "downstream", mode .. " delegates native-window output")
    T.eq(display.primaryTouch("down", 20, 20), false, mode .. " does not capture the app's pointer")
    session.touchDown = { x = 1, y = 1 }
    T.eq(hook("input.pointer")(downstream, game, { phase = "moved", x = 20, y = 20 }), "downstream", mode .. " delegates movement too")
    T.eq(hook("input.step")(downstream, display.sourceGame, 1/60), "downstream", mode .. " leaves game controls to the app")
    T.eq(compose(downstream, {}, { secondScreen = bridge }), "downstream", mode .. " delegates composition")
    T.eq(draws + pushes + polls, 0, mode .. " never renders, presents or consumes bridge touches while shown")
    T.eq(up(compose, "hasDisplay")(), false, mode .. " releases native UI suppression")
    shown = false
    hook("render.output_enabled")(downstream)
  end
  display.nativePhoneOwner = bridge
  display.phone = { touches = { "down,10,10" } }
  shown = false; hook("render.viewport")(downstream, {})
  shown = true; hook("render.viewport")(downstream, {})
  T.eq(nativeEnabled, true, "external app recovers the native bridge from Phone mode")
  T.eq(display.nativePhoneOwner, nil, "Gear relinquishes Phone's native-display ownership")
  T.eq(#display.phone.touches, 0, "old phone touches are discarded on handoff")
  display.phone.touches = { "up,10,10" }
  shown = false
  run.loader.modOptions.kanto_gear.display_mode = "separate"
  hook("render.output_enabled")(downstream)
  T.eq(#display.phone.touches, 0, "phone touches from the external session cannot activate Home")
  display.phone, display.phoneStatus = nil, nil
  up(compose, "inlineDisplay", function() return false end)
  up(compose, "bottomOnHandheld", function() return false end)
  up(compose, "hasDisplay", function() return true end)
  local beforePolls = polls
  compose(function() shown = true end, {}, { secondScreen = bridge })
  T.eq(polls, beforePolls, "app opened by a downstream renderer keeps the touch queue")
  T.eq(draws + pushes, 0, "app opened during composition is not overwritten by Gear")
  shown = false
  hook("render.output_enabled")(downstream)
  local touch = up(compose, "touchEvent")
  up(compose, "touchEvent", function() shown = true end)
  local first = true
  bridge.pollTouch = function()
    polls = polls + 1
    if first then first = false; return "tap,20,20" end
    return "up,20,20"
  end
  session.nextPoll, session.dirty = 0, true
  compose(function() end, {}, { secondScreen = bridge })
  T.eq(polls, beforePolls + 1, "launching from a touch hands off the remaining events immediately")
  T.eq(draws + pushes, 0, "launching from a touch never submits an old Gear frame")
  up(compose, "touchEvent", touch)
  shown = false
  hook("render.output_enabled")(downstream)
  bridge.pollTouch = function() polls = polls + 1 end
  local pump = up(compose, "pumpDisplay")
  local finished = false
  canvas.pollImageData = function() return finished and { stale = true } or nil end
  display.moduleReadbackPending, session.readbackPending = true, true
  T.eq(pump(), false, "unfinished old readback waits without presenting")
  T.eq(pushes, 0, "unfinished old readback cannot overwrite the external screen")
  finished = true
  pump()
  T.eq(display.moduleReadbackPending, nil, "old readback is discarded before a fresh capture")
  T.eq(pushes, 1, "only a fresh synchronous Gear frame is presented after handoff")
  canvas.pollImageData = nil
  session.nextPoll, session.dirty = 0, true
  display.home.help, display.home.helpSeen = false, true
  compose(function() end, {}, { secondScreen = bridge })
  T.check(draws > 0 and pushes > 0, "Gear resumes drawing and presenting after the external app closes")
  display.drawContents = originalDraw
end
