# Performance diagnostics

`3.2.3-test.5` is an instrumented build, with the recorder enabled in
`main.lua`. Disable the recorder before a public release. It sends `KGPROF`
records to the existing host log; it does not upload data or write recordings
into the save. Context contains generation, Gear page, native screen kind,
theme, output path, map motion setting, and map ID. No note text or player names
are recorded.

Capture the host's log with `adb logcat`, then run:

```sh
python tools/performance_report.py capture.log --json report.json
```

Reports cover approximately ten seconds. A report is drained one line per
rendered frame and carries an end marker; truncated reports stay marked
incomplete. Histograms have fixed storage. `p95le` and `p99le` are bucket upper
bounds; maximum and mean are unbucketed. Windows spanning different contexts
are marked mixed, and each metric retains the context of its maximum.

## Interpretation

- All stage times are elapsed wall time in calls on the game thread. They can
  include driver waits. They do **not** measure GPU execution time.
- `frame_interval` measures time between `render.compose` calls, including
  pacing and application suspension. It is **not** the physical display's
  presentation cadence. Long pauses remain counted (`over250`) instead of
  being silently removed. Counts above 20/33.4 ms are not automatically missed
  display-frame counts, particularly at other refresh rates.
- `gear_compose` excludes its downstream host/mod hook chain but includes
  nested Gear scopes. `gear_draw` includes any data work it triggers. Never
  sum overlapping scope means to estimate frame cost.
- `readback_request`, `readback_poll`, `readback_sync`, and `present` separate
  transfer submission, readback completion/copy, the legacy blocking fallback,
  and the secondary-display bridge. Successful `present` calls count RGBA
  bytes submitted, not physical bus traffic or confirmed visible frames.
- `game_capture` is the additional capture/downscale in swapped output mode.
- `notes_flush` includes idle checks as well as actual serialization/writes;
  its maximum is more informative than its mean during mostly idle play.
- `profile_log` records individual log-call overhead. Report construction and
  the recorder's remaining overhead are included in `gear_compose`.

## Device comparison

Keep game, save, game-speed setting, display refresh, theme, thermal state and
route comparable. Start with 30 seconds of walking on Home, then open the
Stamps album and leave it open for 15 seconds. Do not change graphics options
during that first recording. Inspect the hottest scopes before requesting
additional scenarios (battle, Notes, alternate output paths).

A Gear-disabled baseline needs host/system tracing because disabling the mod
also removes its recorder. Likewise, use Android frame timelines or GPU traces
to confirm physical presentation misses and GPU stalls. Lua measurements alone
cannot certify uninterrupted gameplay or a GPU performance improvement.

## Staged Stamps album

The first Thor recording on test.2 measured a 164.94 ms synchronous album
build inside a 177.48 ms frame interval. Test.3 schedules the same calculation
across visible, active Stamps frames with a 1 ms cooperative budget. Checkpoints
sit between groups, between task and encounter reads, and between encounter maps.
One operation can exceed the budget; this is not a hard frame-time guarantee.
`stamps_album` now measures each update slice, including cheap cache checks.
Partial or invalidated results are never shown. Flag/map/save changes abandon
the old job; leaving the app pauses its work. Home's single-area widget keeps
its independent cache and does not start a whole-album job.

Compare the first album open after game load, then reopen without changing
progress. Also walk across a map boundary or collect something while it builds:
only the completed snapshot for the latest state should appear. A new on-device
recording is required before claiming the observed pause is eliminated.

## Gen 2 location lookup

The test.3 Thor recording split the first album over 330 compose calls:
`stamps_album` mean 2.2426 ms, maximum 6.8765 ms. The corresponding frame
interval maximum was 20.0676 ms, versus 177.4841 ms on test.2. Reopening the
unchanged album required no further build slices. Home drawing still had
20–21 ms peaks. These observations apply to the recorded Route 31 workload.

Test.4 removes repeated construction of the entire Gen 2 map-to-landmark table
from individual location lookups. It uses the generated landmark order with
index validation, reads current translation records directly, and falls back
to searching records for newly registered/moved landmarks or older datasets.
Full area grouping uses the same canonical record when indices overlap.

A synthetic Windows LuaJIT benchmark (600 maps, 100 landmarks, seven-run median,
6000 lookups) measured 93.855 ms before and 0.045 ms after; the fallback without
an order list took 1.327 ms. With GC paused for 600 lookups, allocation fell
from 15080.770 KiB to 1.484 KiB. These isolate the lookup and are not a prediction
of total album speed or on-device frame times. Repeat the same device scenario.

Test.4 also separates Home map preparation (`home_map`), Explorer model work
(`home_explorer`), and widget painting (`home_paint`). These are nested inside
`gear_draw`; the same device pass can identify the remaining Home drawing
peaks without changing its layout or refresh settings.

## Screen transitions and terrain caching

In test.4's Thor quality-mode walk, unmixed Home windows averaged 3.2852 ms
per draw (maximum 7.8509 ms); the local map averaged 2.3356 ms (maximum
10.5340 ms). Mixed dialogue/hatching/return windows still contained Gear draw
peaks of 23–30 ms. Separate 141/219 ms frame-interval gaps were not explained
by the measured Gear scopes and cannot be attributed to the mod from this log.

Test.5 removes terrain-cache invalidation from `screen.pushed`. Native menus,
text boxes and egg-hatching screens now refresh live models while preserving
terrain overview/image and map selection/zoom. `map.entered`, current-map
`world.block_replaced` and `map.reloaded` still invalidate terrain. Save loading
and creation explicitly invalidate it as well, so replacing a save never relies
on a later screen push to discard an old map. `map_overview` and `map_image`
measure actual overview/image construction, with no samples for cache hits.

Validate by opening and closing ordinary native game menus while Gear shows
the local map; real terrain mutation and save-reset behavior are covered by
runtime tests. A new device recording is needed to quantify the transition gain;
the existing log alone does not prove every observed peak came from this cache.
