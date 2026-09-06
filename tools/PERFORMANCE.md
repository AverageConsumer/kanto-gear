# Performance diagnostics

`3.2.3-test.3` is an instrumented build, with the recorder enabled in
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
