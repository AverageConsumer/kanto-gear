package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
T.love.graphics = nil
local run = T.sdk.loadMod(assert(os.getenv("KANTO_GEAR_MOD_PATH")), { data = T.fixtures.load() })
T.eq(run.mod and run.mod.state, "loaded", "headless host safely leaves Gear inactive")
T.eq(#run.errors, 0, "missing graphics does not initialize later runtime modules")
run.release()
T.finish("Kanto Gear headless compatibility")
