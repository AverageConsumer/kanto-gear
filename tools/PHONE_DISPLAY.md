# Phone / Browser display

Select **DISPLAY MODE → PHONE / BROWSER** in Kanto Gear's settings or the native
mod options. Scan the displayed QR with a phone in the same private Wi-Fi network,
or open the address shown over the game and enter the code. In either case,
tap Connect. Keep the game open.
Only one browser may connect. Switch to another display mode to stop the server.
Without the phone, open Recomp's **Mods → Kanto Gear → Options**: **DISPLAY MODE**
is the first row. Change **PHONE / BROWSER** to **SEPARATE SCREENS**, **COMBINED SCREEN**
or **FULLSCREEN SWAP**. This stops the server, releases phone controls and restores
local Gear output. The launcher's mod options work too. **RESET DEFAULTS** always
selects Separate Screens, never the previously saved Phone mode.
Native mod options and Gear's Options app share persistent values. Recomp's older
in-game menu cannot interpret list-based visibility conditions, so those settings
remain available there; Gear keeps its contextual filtering. Existing explicit
launcher values take precedence over the older touch-only fallback cache.
Phone mode is optional and experimental; other display modes remain available.

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

Video remains pixel-exact and lossless, at up to 60 Hz. A background worker
compares the new RGBA8 image with its predecessor. Unchanged rows cost nothing;
changed rows send only their changed span. Exact matching spans from nearby
rows/columns reuse the preceding image, so moving maps mostly send new boundary
pixels rather than their entire contents. Scene changes use a full image, and
identical captures produce no video packet. The game thread never performs
compression or searches for reusable pixels.

Binary WebSocket messages start with four ASCII magic bytes, big-endian uint16
width/height and a uint32 frame ID. `KG11`/`KG12` carry a full raw/zlib image;
`KG13`/`KG14` carry compressed/raw row patches; `KG15`/`KG16` carry compressed/raw
patches with copy spans. A uint32 capture timestamp in milliseconds follows the
ID. Patches then carry the preceding frame ID and a uint16 command count.
Each row command contains uint16 y, x and pixel count followed by RGBA8 bytes.
Copy-capable commands add uint16 source y/x; source y 65535 denotes raw bytes,
otherwise pixels come from the untouched preceding image. Bounds, ordering,
non-overlap, exact decoded lengths and dependencies are checked before display.
Zlib uses level 1; larger compressed payloads fall back to raw bytes. The browser
also accepts the original untimed `KG01`–`KG06` equivalents for protocol tests.
A current browser with `DecompressionStream` support is required for compressed
frames. The transport is still unencrypted local HTTP/WebSocket.

The browser inflates and reconstructs dependencies in a dedicated Worker, in
WebSocket order, even when an intermediate presentation is skipped. Two decode
buffers and a pool of at most ten transferable presentation buffers are reused;
the canvas reuses one ImageData for each resolution. At most 32 packets may be
waiting for decode and eight images for presentation. A stable 60 ms playout
reserve absorbs short radio bursts; the initial clock estimate settles quickly,
then changes slowly. The frame nearest the current display slot is presented.
A long stall or full presentation queue rebases playback instead of indefinitely
replaying old movement. Display rates that are not multiples of the source rate
still repeat pictures unevenly; this does not interpolate new game frames.
The idle browser does not request animation frames with nothing to paint.

Capture and phone map invalidation follow Recomp's input.step fixed-step clock,
not an independent wall-clock gate on every monitor refresh. The captured source
clock is carried in the timed frame header. Hosts/previews without input.step
retain a clock fallback. Fast-forward is normalized by the game's frame speed;
only the latest visible game frame is captured after several catch-up steps.

Socket writes, background encoding and readback may overlap. There is one encode
job, one replaceable latest capture and at most three queued video packets, with
a 512 KiB queue budget (one completing result may exceed it). A partially written
packet is never replaced or interleaved. Decoder receipt `r,<id>` measures round
trip time; display receipt `a,<id>` selects the touch coordinate frame. Neither
receipt gates capture. A bounded 128-frame metadata history rejects unknown
receipts. Heartbeats still enforce disconnect cleanup. OS TCP buffers and actual
network congestion remain outside this Lua queue budget; the stream cannot
recover pixels that have not arrived. Native companion rendering is unchanged.
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

At 240×216 and 60 Hz, full raw RGBA traffic would be about 12.4 MB/s.
Actual savings depend on visible motion; unrelated full-screen changes still
need more bandwidth than a scrolling map. The existing asynchronous GPU
readback is used where supported; other LÖVE builds retain their synchronous
fallback. A viewer that stops sending valid heartbeats loses ownership and releases controls.

A local LÖVE/Chromium comparison used the same 180-image sequences derived from
repository screenshots, with deterministic simulated map/transition movement:

| Sequence | Full-frame bytes | Incremental bytes | Reduction |
| --- | ---: | ---: | ---: |
| Home map | 2,759,963 | 94,146 | 96.6% |
| Explorer map | 2,691,913 | 118,160 | 95.6% |
| Page transition | 3,053,139 | 333,638 | 89.1% |

The encoder's median CPU time for those sequences was 0.16–0.54 ms, versus
0.63–0.67 ms for the original full-image compression, on the test Windows host.
A local bandwidth/latency proxy with 0.5 Mbit/s, 80 ms RTT and 20 ms jitter
improved the moving Home fixture from about 4 to 53 presented FPS. These are
synthetic network tests of the actual server/browser path, not measurements
of a Thor game, GPU readback, physical Wi-Fi, or Brave's Android scheduler.
The fixed presentation reserve adds video latency to absorb jitter;
controller messages do not wait for it. No finite-bandwidth transport can
promise full-rate video through arbitrary congestion or an interrupted signal.

A timing comparison against phone.9 used eight-second measurements after one
second of warmup, the same 60 Hz moving screenshot fixture, a real LÖVE server
and Chromium, and a deterministic local TCP latency/bandwidth proxy:

| Scenario | phone.9 → phone.10 presented FPS | p95 image interval | Skipped source frames |
| --- | --- | --- | --- |
| Clean 60 Hz host | 59.8 → 60.0 | 19.5 → 16.8 ms | 2 → 0 |
| Clean 144 Hz host | 59.8 → 59.9 | 22.6 → 19.5 ms | 107 → 0 |
| 200 ms upstream acknowledgement spikes | 49.9 → 60.0 | 33.4 → 19.4 ms | 80 → 0 |
| 1 Mbit/s, 40 ms RTT, jitter and 50 ms downlink stalls | 54.0 → 58.9 | 44.4 → 24.5 ms | 48 → 9 |

The 144 Hz phone.9 run also displayed 105 repeated source states; phone.10
repeated none. The fixed reserve increases median frame age in these tests
(e.g. 39 → 75 ms on the clean 60 Hz link; 72 → 87 ms on the stalled link).
Controller delivery does not use this reserve. These results do not include GPU
readback or actual Thor/Brave Wi-Fi behavior, and do not promise zero hitches.

## Checks

`luajit mod/kanto_gear/tests/phone_display_test.lua` exercises the bounded
protocol and pairing logic without a ROM, including one-use/expired keys,
authentication gating, origin/peer checks, rate limits and entropy failures.
`tests/phone_video_test.lua` verifies pixel-exact patches, horizontal/vertical
copy spans, alpha, resolution changes, scene changes and duplicate suppression.
`tests/phone_pairing_test.lua` exercises the real OS entropy worker and exports
a QR fixture for independent decoding (OpenCV was used for the current build). `tests/phone_runtime_test.lua` runs
in the host modkit harness and checks display routing, readiness, readback
backpressure and cleanup. `tests/phone_input_test.lua` additionally checks the
actual Recomp Input/source bookkeeping for all three generations, including
simultaneous holds, fast taps, keyboard coexistence and GBA shoulders.
`node mod/kanto_gear/tests/phone_browser_test.cjs` uses Playwright with a mocked
host to test pairing, real multitouch events, Dpad sliding, settings persistence,
capability changes, connection loss and responsive geometry. Video cases cover
Worker-only inflation, transferable-buffer exhaustion/recovery, stable playout
under quantized arrivals, ImageData reuse, compressed/raw patches, unpainted dependencies, copy source bounds, oversized
inflation, queue limits and timestamp wrap. Set `KANTO_GEAR_VIDEO_FIXTURE` to a
local encoded-frame fixture to compare actual LÖVE output with every reconstructed
RGBA byte using SHA-256. The layout cases
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
