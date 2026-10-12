# Phone display prototype

Select **DISPLAY MODE → PHONE / BROWSER** in Kanto Gear's settings or the native
mod options. Scan the displayed QR with a phone in the same private Wi-Fi network,
or open the address shown over the game and enter the code. In either case,
tap Connect. Keep the game open.
Only one browser may connect. Switch to another display mode to stop the server.
Return to a normal Kanto Gear package to remove the experimental option.

The game stays on its own display. Y swapping is unavailable in phone mode.
The phone reuses Gear's existing touch handling, including swipes and Notes.
Optional browser controls add a Dpad, A/B, Start/Select, plus L/R in Gen 3.
Hold several fingers at once to run while steering or touch Gear independently.
Slide the Dpad thumb between direction keys without lifting it.
Browser Settings can hide the controls, place them beside/below Gear, change
button size, disable press animations or the frame, choose light/dark Pokégear or C-Gear colors, and request fullscreen.
Preferences stay in memory by default. Enable **Remember settings** to store
only these choices in this browser; **Forget saved settings** removes them
and restores defaults. Game/Gear settings and pairing keys are never stored there.
The page uses locally bundled Pokégear and C-Gear controller designs.
**Custom → Arrange** moves and resizes Gear and each control independently.
Choose Classic, Left-handed, One hand · right or One hand · left as the base;
portrait and landscape have separate presets and overrides. Drag a module to
select it, adjust Size (0.7–1.6×), then Back for the global tools. Snap aligns
visible edges/centers and shows guides. Overlaps and the reserved settings corner
turn red; releasing an invalid drag restores its starting position. Reset removes
only the current orientation's overrides; Cancel restores the entire edit session.
The ⇅ button docks the toolbar at the other edge. Editing sends no game/Gear
input or haptic feedback. All modules, including GBA shoulders, can be arranged
in GB games too; shoulders remain hidden during normal GB play. In Custom mode,
individual module sizes replace the general Button size setting.
Done applies the layout in memory. Remember settings is required to keep it across
reloads, only in this browser. Rotation restores the matching orientation; an
unfinished drag is cancelled on rotation, focus loss or connection/game changes.
Where the browser exposes `navigator.vibrate`, Settings also offers Haptics.
An active controller button produces one short eight-millisecond pulse on press
or when sliding to a new Dpad direction. Holds, disabled buttons and Gear's
bitmap surface do not trigger extra pulses. Opening Settings, disconnecting or
leaving the page cancels phone vibration. Unsupported browsers hide the option;
a browser/OS refusal never blocks game input. Hardware support, silent mode and
browser restrictions can still prevent vibration even when the API exists.
Closing or hiding the browser releases game buttons, cancels touch input and restores native game UI.
A stalled connection loses display ownership within approximately 1.5 seconds
while the game runs. The browser also hides stale content when the game pauses.

## Transport

The local IPv4 HTTP/WebSocket server uses port 8765. It starts only in phone
mode and accepts one authenticated viewer. Both a private/loopback/link-local
IPv4 peer and numeric local Host are required; WebSocket Origin must match Host.
No external QR service, font CDN, account, relay, analytics, cookies, HTTP access
log, screen recording or router/UPnP setup is used. The browser receives Gear
pixels (including visible names/Notes), and sends buttons, touch coordinates,
frame acknowledgements and heartbeats. ROM/save files are not sent.

Pairing keys use 128 bits from the OS CSPRNG; manual codes have eight uniform
random decimal digits. The mod's **compute** permission starts a bundled worker
solely for OS entropy and local QR encoding, outside the frame-rendering thread.
Windows uses BCryptGenRandom; Linux/macOS/Android use getentropy. An unavailable
OS entropy source fails closed; there is no gameplay-RNG fallback.
The QR key is in the URL fragment, never an HTTP query/path. The page removes
it from its address immediately and waits for Connect. A browser/QR scanner may
keep its own history; Kanto Gear cannot control that. The first WebSocket message
is `auth,<key-or-code>` on `/gear`, before any image, capability or input access.
Both credentials expire after five minutes and are consumed together on success.
Unauthenticated sockets expire after three seconds; six failed authentications
block further attempts globally for one minute. Restarting/changing mode clears
credentials and sessions. No pairing key is put in local/session storage.

**HTTP is unencrypted.** Pairing controls access on a trusted private network;
it cannot prevent a network observer from seeing or modifying traffic. It is
not secure for public/shared untrusted Wi-Fi or internet exposure. No end-to-end
encryption or legal certification is claimed. HTTPS with a trusted host identity
would need a separate supported transport. The pairing page explains this and
its local data use before Connect. User settings storage is optional and removable.
If the displayed address belongs to a VPN, use the game device's private Wi-Fi
IPv4 address with port 8765 instead. Firewalls may need to allow the host on the
private network only. Do not forward this port on a router.

QR encoding uses luaqrcode, pinned BSD-3-Clause source in `vendor/qrencode.lua`;
see its retained license, `vendor/README.txt` and `ASSET_CREDITS.txt`.

Each binary WebSocket message contains `KG02`, big-endian uint16 width/height,
a big-endian uint32 frame ID and zlib-compressed RGBA8 pixels (compression
level 1). Incompressible images use `KG01` with raw RGBA8 instead. Frames are
independent and lossless. A current browser with `DecompressionStream` support
is required for compressed frames. A trusted private network is required even
when the browser supports WebCrypto; this transport is still HTTP.

The browser acknowledges the latest frame after presenting it. At most two
images may be in flight, allowing 60 Hz without a stop-and-wait round trip
for every image. The browser keeps only the latest packet and decoded image
instead of building a playback queue. Capture and moving maps run at up to
60 Hz; unchanged Gear screens do not require new images. GPU capture slots
are reserved when readback starts so completion can request the next capture
on the same host frame. Socket reads/writes and input queues have fixed limits.
Touches reference the acknowledged frame and use its pixel coordinates.
Phone touches are drained every host frame, independently of game snapshots.
Heartbeat messages keep idle displays connected without repeated images.
Game button messages `b,<button>,1` / `b,<button>,0` are independent of video
acknowledgements. `release` clears all phone holds and cancels Gear touch.
The host advertises `c,gb`, `c,gba` or `c,none` after pairing/game changes.
Eight standard buttons use `mod.input` tokens; GBA shoulders currently use
`Input:sourcePress/sourceRelease` because the public mod API whitelist only
accepts GB buttons. Physical keyboard/controller holds retain their own sources.
Disconnect, heartbeat expiry, mode changes, game replacement and server restart
release phone-owned holds. Browser blur, page hiding, resizing and settings also
reset them. The browser's controls do not require extra image captures.
The browser footer reports measured presentation FPS during continuous motion
and shows `idle` when the image is unchanged. It does not count unchanged
screens as sixty newly rendered images.

At 240×216 and 60 Hz, uncompressed traffic would be about 12.4 MB/s before
network overhead. Actual compression depends on the visible pixels. The
existing asynchronous readback is used when the host provides it; ordinary
LÖVE builds use the synchronous fallback. A full transport window stops new
GPU requests and compression work until the viewer makes progress. A stalled
viewer loses ownership rather than accumulating old frames. Compression,
GPU readback, Wi-Fi and browser timing still need measurement on the device.

## Checks

`luajit mod/kanto_gear/tests/phone_display_test.lua` exercises the bounded
protocol and pairing logic without a ROM, including one-use/expired keys,
authentication gating, origin/peer checks, rate limits and entropy failures.
`tests/phone_pairing_test.lua` exercises the real OS entropy worker and exports
a QR fixture for independent decoding (OpenCV was used for the current build). `tests/phone_runtime_test.lua` runs
in the host modkit harness and checks display routing, readiness, readback
backpressure and cleanup. `tests/phone_input_test.lua` additionally checks the
actual Recomp Input/source bookkeeping for all three generations, including
simultaneous holds, fast taps, keyboard coexistence and GBA shoulders.
`node mod/kanto_gear/tests/phone_browser_test.cjs` uses Playwright with a mocked
host to test pairing, real multitouch events, Dpad sliding, settings persistence,
capability changes, connection loss and responsive geometry. The layout cases
cover touch/mouse dragging, snapping, rejected collisions/sizes, reset/cancel,
orientation changes, opt-in storage and all four themes/presets from 320×568 to
1280×800. Set
`KANTO_GEAR_NODE_MODULES` to a Node modules directory containing Playwright and
optionally `KANTO_GEAR_CHROMIUM` to the test Chromium executable.
The `settings_option` preview accepts
`KANTO_GEAR_PREVIEW_OPTION=display_mode`.

Device validation must cover a moving map, touch actions, browser disconnect,
and gameplay frame pacing with the same scene and the phone mode switched off.

For the controller check: on a phone connected to a desktop host, walk while
holding B, slide to another direction, release both fingers, then hold a
button while opening browser Settings or switching away from the browser.
Movement must stop; Gear touch must remain independent; hiding the controls
must enlarge the available Gear area. Real Wi-Fi latency still needs this check.

## Security and privacy references

- OWASP WebSocket Security Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/WebSocket_Security_Cheat_Sheet.html
- W3C Referrer Policy: https://www.w3.org/TR/referrer-policy/
- DSK, Orientierungshilfe Digitale Dienste (November 2024): https://www.datenschutzkonferenz-online.de/orientierungshilfen.html

These inform the implementation; automated tests cannot certify legal compliance.
The integration check used an actual LÖVE 11.5 local server and Chromium (no ROM):
authentication, CSP, compressed frames, input capability and disconnect passed.
Real phone scanning and Wi-Fi gameplay latency still need the user's device check.
