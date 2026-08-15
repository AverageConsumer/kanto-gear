package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local path = os.getenv("KANTO_GEAR_MOD_PATH") or "mods/kanto_gear"
local run = T.sdk.loadMod(path, { data = T.fixtures.load() })

T.eq(#run.errors, 0,
  "desktop host loads without Android's asynchronous display readback")
T.check(run.loader.exports.kanto_gear ~= nil,
  "one-window support remains available on desktop hosts")

run.release()
T.finish("Kanto Gear desktop compatibility")
