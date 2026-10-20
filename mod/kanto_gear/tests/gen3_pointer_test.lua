-- API 3 delivers window pointers through the native hook without replacing
-- Game3 handlers. Exercise the engine's real dispatch and cancellation path.
local T = require("tests.modkit")
local Game3 = require("src.core.Game3")
local Runtime = require("src.mods.Runtime")
local Hooks = require("src.mods.Hooks")
local previous = Runtime.hooks
local hooks, events = Hooks.new(), {}
Runtime.hooks = hooks
local game = setmetatable({}, { __index = Game3 })
hooks:wrap("input.pointer", function(next, owner, event)
  T.eq(owner, game, "native dispatch retains the original game identity")
  events[#events + 1] = event
  return true
end, 0, "pointer_probe")
game:mousepressed(300, 100, 1, false)
game:mousemoved(310, 110, 10, 10, false)
game:mousereleased(310, 110, 1, false)
T.eq(#events, 3, "native mouse dispatch delivers one complete gesture")
T.eq(events[1].phase, "pressed", "mouse press starts the contact")
T.eq(events[2].phase, "moved", "native dragging stays continuous")
T.eq(events[3].phase, "released", "native release ends the contact")
T.eq(events[2].x, 310, "window coordinates remain in host units")
game:mousepressed(300, 100, 1, true)
T.eq(#events, 3, "synthetic touch mouse twin is ignored")
game:touchpressed("finger", 300, 100, 0, 0, .7)
game:touchmoved("finger", 315, 110, 15, 10, .7)
game:touchreleased("finger", 315, 110, 0, 0, .7)
T.eq(#events, 6, "physical touch uses the same native hook")
T.eq(events[4].id, "finger", "touch identity is preserved")
game:touchpressed("held", 300, 100)
game:cancelPointers()
T.eq(events[#events].phase, "cancelled", "native lifecycle cancellation releases contacts")
local count = #events
game:touchreleased("held", 300, 100)
T.eq(#events, count, "late release cannot reactivate a cancelled contact")
T.eq(rawget(game, "mousepressed"), nil, "mouse handlers remain inherited")
T.eq(rawget(game, "touchpressed"), nil, "touch handlers remain inherited")
Runtime.hooks = previous
T.finish("Gen3 API 3 pointer dispatch")
