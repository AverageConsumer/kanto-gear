# Phone display prototype

Select **DISPLAY MODE → PHONE / BROWSER** in Kanto Gear's settings or the native
mod options. Open the address shown over the game on a phone in the same private
Wi-Fi network, then enter the eight-digit pairing code. Keep the game open.
Only one browser may connect. Switch to another display mode to stop the server.
Return to a normal Kanto Gear package to remove the experimental option.

The game stays on its own display. Y swapping is unavailable in phone mode.
The phone reuses Gear's existing touch handling, including swipes and Notes.
Closing or hiding the browser cancels touch input and restores native game UI.
A stalled connection loses display ownership within approximately 1.5 seconds
while the game runs. The browser also hides stale content when the game pauses.

## Transport

The local IPv4 HTTP/WebSocket server uses port 8765. It starts only in phone
mode, accepts one paired viewer and limits failed pairing attempts globally.
The page and socket require a numeric IPv4 Host header; WebSocket Origin must
match it. HTTP is unencrypted: the pairing code is an online access check for a
private network, not protection against someone monitoring that network.
If the displayed address belongs to a VPN, use the game device's Wi-Fi IPv4
address with port 8765 instead. Desktop firewalls may need to allow the host on
the private network.

Each binary WebSocket message contains `KG01`, big-endian uint16 width/height,
a big-endian uint32 frame ID and tightly packed RGBA8 pixels. The browser
acknowledges a frame after presenting it. Only one image may be in flight;
capture is limited to 30 Hz and unchanged Gear screens do not require new
images. Socket reads/writes and input queues have fixed per-update limits.
Touches reference the acknowledged frame and use its pixel coordinates.
Heartbeat messages keep idle displays connected without repeated images.

At 240×216 and 30 Hz, raw pixel traffic is about 6.2 MB/s before network
overhead. GPU readback, allocation, Wi-Fi traffic and browser drawing still
cost resources. The existing asynchronous readback is used when the host
provides it; ordinary LÖVE builds use the synchronous fallback.

## Checks

`luajit mod/kanto_gear/tests/phone_display_test.lua` exercises the bounded
protocol and pairing logic without a ROM. `tests/phone_runtime_test.lua` runs
in the host modkit harness and checks display routing, readiness, readback
backpressure and cleanup. The `settings_option` preview accepts
`KANTO_GEAR_PREVIEW_OPTION=display_mode`.

Device validation must cover a moving map, touch actions, browser disconnect,
and gameplay frame pacing with the same scene and the phone mode switched off.
