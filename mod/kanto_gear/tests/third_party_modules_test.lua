-- Third-party Silph Store modules (runtime/modules.lua): a mod registers its own
-- app through the exported hook; the Gear ships no knowledge of any of them.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"

local run = T.sdk.loadMod(path, { generation = tonumber(arg[1]) or 2, data = T.fixtures.fresh() })
T.eq(run.mod and run.mod.state, "loaded", "Kanto Gear loads")

local upvalue = assert(loadfile(path .. "/tests/support/runtime.lua"))().get
local function runtime()
  for _, entry in ipairs(run.loader.hooks.chains["input.step"] or {}) do
    if entry.owner == "kanto_gear" then return upvalue(entry.callback, "displayRuntime") end
  end
end
local display = assert(runtime(), "display runtime reachable")
local M = assert(display.gearModules, "the module registry exists")
T.eq(M.exports.api, 1, "the exported hook carries an api version")

-- ------- a well-formed registration, the template's shape

local rows = {}
for i = 1, 24 do rows[i] = string.rep(i % 2 == 0 and "a" or ".", 24) end
local opens, shownNow = {}, false
local spec = {
  id = "fake_gym", label = "FAKE GYM", category = "TESTING",
  description = { "A TEST MODULE.", "IT IS NOT REAL." },
  icon = { pal = { a = "e04838" }, rows = rows },
  accent = "green",
  available = function(ctx) return ctx.gen3 == true end,
  shown = function() return shownNow end,
  open = function()
    local r = table.remove(opens, 1) or { true }
    if r.err then error(r.err) end
    return r[1], r[2]
  end,
  translations = { de = { ["FAKE GYM"] = "TESTHALLE" } },
}
T.eq(M.exports.register(spec), true, "a well-formed spec registers")

local entry = display.storeById.fake_gym
T.check(entry ~= nil and entry.thirdParty == true, "the store entry exists, marked third party")
T.eq(entry.hidden, true, "...hidden until availability says otherwise")
T.eq(entry.target, nil, "...no Gear page: the press goes to the module")
local surface = display.homeCatalog.surfaces.fake_gym_app
T.check(surface ~= nil and surface.kind == "app" and surface.columns == 3,
  "the home surface exists as a movable app tile")
T.eq(surface.accent, "green", "...with the spec's accent")
local package_ = display.homeCatalog.packages.fake_gym
T.check(package_ ~= nil and package_.available == false, "the package starts unavailable")
local THEME = upvalue(display.homeTileAt, "THEME")
local skin = THEME and THEME.hgss
if skin and skin.v4HasIcon then   -- the skins load only with a display
  T.eq(skin:v4HasIcon("module/fake_gym"), true, "the pal/rows icon is in the icon set")
end

-- ------- availability follows the module's own answer at bind

M.applyAvailability({ gen3 = true })
T.eq(entry.hidden, false, "supported: the store entry shows")
T.eq(surface.hidden, false, "...the tile can go to the home screen")
T.eq(package_.available, true, "...and installs are taken")
M.applyAvailability({ gen3 = false })
T.eq(entry.hidden, true, "unsupported: hidden again")
T.eq(package_.available, false, "...and unavailable")
M.applyAvailability({ gen3 = true })

-- a module registered after the bind picks up the last context at once
local late = { id = "late_mod", label = "LATE", category = "TESTING",
  description = { "LATE." }, icon = function() end,
  available = function(ctx) return ctx.gen3 == true end, open = function() return true end }
T.eq(M.exports.register(late), true, "a custom-draw module registers after the bind")
T.eq(display.storeById.late_mod.hidden, false, "...and is applied against the last context")

-- ------- the press: home falls back, the module's open decides

local session = upvalue(display.openHomeApp, "session")
local generation = tonumber(arg[1]) or 2
local world = { map = { id = "PALLET_TOWN", def = {} } }
local game = { generation = generation, data = run.data, world = world, overworld = world,
  save = { generation = generation, player = { name = "GOLD", id = 7 }, party = {}, inventory = {},
    boxes = {}, pokedex = { seen = {}, caught = {} } },
  stack = { top = function() return world end } }
run.loader.events:emit("game.ready", { game = game })
local boundContext = M.lastContext
T.eq(M.lastContext.generation, generation, "availability receives the actual bound generation")
M.applyAvailability({ generation = 3, gen3 = true })
T.check(display.setPackageInstalled("fake_gym", true), "user enables the registered app")
if session then session.page = "STORE" end
opens = { { true } }
T.eq(display.openHomeApp("fake_gym"), true, "a press opens the module")
T.eq(display.home.activeApp, nil, "...no Gear app stays active")
if session then T.eq(session.page, "HOME", "...and the Gear falls back to its home screen") end
opens = { { false, "not now" } }
T.eq(display.openHomeApp("fake_gym"), false, "a refusal is a no")
opens = { { err = "boom" } }
T.eq(display.openHomeApp("fake_gym"), false, "an open error is caught")

-- ------- the stand-down signal

T.eq(M.anyShown(), false, "no module surface up: the Gear presents")
shownNow = true
T.eq(M.anyShown(), true, "a module surface up: the Gear stands down")
shownNow = false

-- ------- refusals keep the catalog clean

local function reject(why, bad)
  local ok, reason = M.exports.register(bad)
  T.eq(ok, nil, "refused: " .. why .. " (" .. tostring(reason) .. ")")
end
reject("duplicate id", spec)
reject("a built-in id", { id = "calendar", label = "X", category = "X",
  description = { "X" }, icon = function() end, open = function() end })
reject("bad id", { id = "Bad-Id", label = "X", category = "X",
  description = { "X" }, icon = function() end, open = function() end })
reject("bad icon rows", { id = "short_icon", label = "X", category = "X",
  description = { "X" }, icon = { pal = {}, rows = { "..." } }, open = function() end })
reject("bad accent", { id = "loud_mod", label = "X", category = "X",
  description = { "X" }, icon = function() end, accent = "neon", open = function() end })
reject("no open", { id = "inert_mod", label = "X", category = "X",
  description = { "X" }, icon = function() end })
reject("label too long", { id = "wordy_mod", label = string.rep("A", 21), category = "X",
  description = { "X" }, icon = function() end, open = function() end })
T.eq(display.storeById.short_icon, nil, "a refused spec leaves no store row")
T.eq(display.homeCatalog.packages.loud_mod, nil, "...and no package")

-- ------- the i18n extend used for a module's translations

local I18N = assert(loadfile(path .. "/i18n/init.lua"))()
local i18n = I18N.new(function() return {} end, function() return "de" end)
T.eq(i18n:extend("de", { ["FAKE GYM"] = "TESTHALLE" }, "fake_gym"), true, "a translation table merges")
T.eq(i18n:text("@app/fake_gym:FAKE GYM"), "TESTHALLE", "...and translates")
T.eq(i18n:text("@app/fake_gym:UNSEEN"), "UNSEEN", "...missing entries fall back to the module's English")
T.eq(i18n:extend("xx", { A = "B" }), false, "an unsupported language is refused")

M.applyAvailability(boundContext)
dofile(path .. "/tests/third_party_modules_cases.lua")(T, run, display, game, generation)
T.finish("Kanto Gear third-party modules")
