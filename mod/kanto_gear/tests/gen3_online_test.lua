-- Real imported data + actual Gear loader. No public-server connection.
-- The current host blocks mods with permissions/hooks even when their link
-- fingerprint is unchanged. Never manufacture a vanilla online profile.
local path = assert(os.getenv("KANTO_GEAR_MOD_PATH"))
local T = require("tests.modkit")
local Handshake = require("src.link.Handshake")
local Fingerprint = require("src.link.Fingerprint")
local ArenaData = require("src.online.ArenaData")
local originalLoad = T.sdk.loadMod
local baseline, baselineSurface
T.sdk.loadMod = function(modPath, opts)
  T.sdk.loadMod = originalLoad
  Fingerprint.forget(opts.data)
  baselineSurface = Fingerprint.surface(opts.data, {}, 3)
  baseline = assert(ArenaData.liveProfile3({ data = opts.data,
    version = os.getenv("POKEPORT_VERSION") }, "g3_link"))
  return originalLoad(modPath, opts)
end

local upvalue = assert(loadfile(assert(os.getenv("KANTO_GEAR_MOD_PATH")) .. "/tests/support/runtime.lua"))().get

_G.KANTO_GEAR_RENDER_CAPTURE = function(run, display, raw)
  raw.mods, raw.version = run.loader, os.getenv("POKEPORT_VERSION")
  local mods = Handshake.mods(raw)
  T.eq(#mods, 1, "online check actually sees the loaded Gear mod")
  T.eq(mods[1].id, "kanto_gear", "online check sees Gear's real manifest")
  local function compatible(label)
    T.eq(Handshake.linkModified(raw), false, label .. " does not change link play")
    Fingerprint.forget(raw.data)
    T.eq(Fingerprint.surface(raw.data, Handshake.mods(raw), 3), baselineSurface,
      label .. " full uncached link surface equals vanilla")
    for _, ruleset in ipairs({ "g3_link", "g3_single", "g3_double", "g3_multi" }) do
      local profile, reason = ArenaData.liveProfile3(raw, ruleset)
      T.eq(profile, nil, label .. " respects native mod gate for " .. ruleset)
      T.eq(reason, "mods", label .. " " .. ruleset .. " explains the host restriction")
    end
  end
  for _, language in ipairs({ "en", "de", "es", "fr", "ja", "it" }) do
    run.loader.modOptions.kanto_gear.language = language
    run.loader.events:emit("mod.options_changed", {
      mod = "kanto_gear", key = "language", value = language })
    display.drawContents()
    compatible(language)
  end

  -- Negative controls: this must exercise the real host gate, not a stub.
  local status = run.loader.status
  run.loader.status = function()
    return { loaded = { { id = "negative_control", version = "1", affects_link = true } } }
  end
  local denied, why = ArenaData.liveProfile3(raw, "g3_link")
  T.eq(denied, nil, "link-changing manifest is refused")
  T.eq(why, "mods", "refusal names the mod restriction")
  run.loader.status = status
  local registry = run.loader.content.growth_rates
  run.loader.content.growth_rates = { ops = { probe = { { owner = "negative_control" } } } }
  denied, why = ArenaData.liveProfile3(raw, "g3_link")
  T.eq(denied, nil, "link registry write is refused even without affects_link")
  T.eq(why, "mods", "registry refusal names the mod restriction")
  run.loader.content.growth_rates = registry
  compatible("restored Gear")

  local Client = require("src.online.Client")
  local Session = assert(loadfile(path .. "/features/pss_session.lua"))()
  local service = Session.new(raw, function() return display.pss.ctx.identity() end, Client)
  T.eq(service:profileValid(), false, "Silph Connect preserves the real permission gate")
  T.eq(service.notice, "RECOMP BLOCKS UI MODS", "gate is explained in the app")
  T.eq(require("src.online.union.Caps").empty(require("src.online.union.Caps").compute(service:context())),
    true, "restricted UI mod never advertises battle/trade capabilities")

  local B = require("src.core.game3.battle")
  local Ui = require("src.core.game3.battle.ui")
  local State = require("src.core.game3.battle.state")
  local Stack = require("src.ui.game3.stack")
  local Message = require("src.ui.game3.message")
  local st = State.new({ playerParty = raw.session.party,
    foeParty = raw.session.party, wild = false })
  st.link = true
  B._active, B._auto, B._phase, B._st = true, false, "command", st
  Stack.clear(); Message.reset()
  Ui.reset({ headless = true }); Ui.bindState(st, raw.session); Ui.openMenu(0)
  local refresh
  for _, entry in ipairs(run.loader.hooks.chains["render.compose"] or {}) do
    if entry.owner == "kanto_gear" then refresh = upvalue(entry.callback, "refreshBattle") end
  end
  assert(refresh)
  for _, mode in ipairs({ "standard", "info", "gear", "full" }) do
    run.loader.modOptions.kanto_gear.battle_view = mode
    display.gen3.syncScreens(); refresh()
    T.check(upvalue(refresh, "battle").nativeUnsupported, mode .. " recognizes a link battle")
    Ui._mode, Ui._menuIndex = "menu", 1
    Ui.handleInput({ wasPressed = function(_, key) return key == "right" end })
    T.eq(Ui._menuIndex, 2, mode .. " preserves native online D-pad order")
    T.check(pcall(display.drawContents), mode .. " renders native online handoff")
  end
  B._active, B._st = false, nil
  Stack.clear()
end
dofile(path .. "/tests/gen3_fixture.lua")
